#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// STAR WING 64: an on-rails 3D space shooter. Pinhole-projected starfield, scrolling grid planet surface,
/// enemies / rocks / gates / bullets as 3D points drawn back to front as flat-shaded polygons and discs.
/// Three waves and a boss, shields, barrel-roll reflect, repair rings.
final class StarWing64: Game {
    // MARK: - Types

    private enum Phase { case title, play, over }

    private struct Ent {
        var kind = 0
        var x: Float = 0
        var y: Float = 0
        var z: Float = 0
        var dz: Float = 0
        var vx: Float = 0
        var vy: Float = 0
        var bx: Float = 0
        var by: Float = 0
        var amp: Float = 0
        var ph: Float = 0
        var r: Float = 16
        var hr: Float = 16
        var hp = 1
        var t = 0
        var fire = 0
        var flash = 0
        var used = false
        var dead = false
    }

    private struct Shot {
        var x: Float = 0
        var y: Float = 0
        var z: Float = 0
        var dz: Float = 34
        var dmg = 1
        var refl = false
        var dead = false
    }

    private struct Part {
        var x: Float = 0
        var y: Float = 0
        var z: Float = 0
        var vx: Float = 0
        var vy: Float = 0
        var dz: Float = 0
        var life = 1
        var maxLife = 1
        var cr = 255
        var cg = 255
        var cb = 255
        var size: Float = 3
        var dead = false
    }

    private struct FloorTab {
        var z = [Float](repeating: 1, count: 288)
        var k = [Float](repeating: 1, count: 288)
        var zt = [Float](repeating: 1, count: 288)
        var xt = [Int](repeating: 1, count: 288)
        var far = [Bool](repeating: true, count: 288)
        var baseA = [UInt32](repeating: 0, count: 288)
        var baseB = [UInt32](repeating: 0, count: 288)
        var lx = [UInt32](repeating: 0, count: 288)
        var lz = [UInt32](repeating: 0, count: 288)

        init() {
            let hz = StarWing64.hz
            let f: Float = StarWing64.focal
            let ch: Float = StarWing64.camH
            for r in (hz + 1)..<288 {
                let dr: Float = Float(r - hz)
                let zz: Float = ch * f / dr
                z[r] = zz
                k[r] = zz / f
                let th: Float = zz * zz / (ch * f) * 1.1
                zt[r] = max(1.2, th)
                let xw: Float = min(30, max(1, zz / f * 1.5))
                xt[r] = Int(xw)
                far[r] = zz > 2800
                var fogT: Float = (zz - 500) / 2300
                if fogT < 0 { fogT = 0 }
                if fogT > 1 { fogT = 1 }
                baseA[r] = FloorTab.fogMix(20, 52, 96, fogT)
                baseB[r] = FloorTab.fogMix(30, 70, 124, fogT)
                lx[r] = FloorTab.fogMix(70, 225, 255, fogT)
                lz[r] = FloorTab.fogMix(255, 90, 210, fogT)
            }
        }

        static func fogMix(_ r: Int, _ g: Int, _ b: Int, _ t: Float) -> UInt32 {
            let fr: Float = Float(r) + Float(130 - r) * t
            let fg: Float = Float(g) + Float(70 - g) * t
            let fb: Float = Float(b) + Float(180 - b) * t
            return TrueColorBuffer.rgb(Int(fr), Int(fg), Int(fb))
        }
    }

    // MARK: - Constants

    private static let focal: Float = 220
    private static let hz = 118
    private static let camH: Float = 90
    private static let shipZ: Float = 220
    private static let farZ: Float = 1500
    private static let xLim: Float = 105
    private static let yMin: Float = -65
    private static let yMax: Float = 38
    private static let rollLen = 34
    private static let rollCooldown = 130

    private static let kFighter = 0
    private static let kRock = 1
    private static let kGate = 2
    private static let kBullet = 3
    private static let kRing = 4
    private static let kBoss = 5

    private static let cWhite: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    private static let cBlack: UInt32 = TrueColorBuffer.rgb(8, 8, 18)
    private static let cYellow: UInt32 = TrueColorBuffer.rgb(255, 226, 64)
    private static let cRed: UInt32 = TrueColorBuffer.rgb(255, 80, 64)
    private static let cGreen: UInt32 = TrueColorBuffer.rgb(100, 255, 130)
    private static let cCyan: UInt32 = TrueColorBuffer.rgb(110, 240, 255)
    private static let cPanel: UInt32 = TrueColorBuffer.rgb(14, 16, 44)

    private static let ftab = FloorTab()

    private static let skyRows: [UInt32] = {
        var a = [UInt32](repeating: 0, count: 119)
        for y in 0..<119 {
            let t: Float = Float(y) / 118.0
            let r = Int(6 + (130 - 6) * t * t)
            let g = Int(6 + (70 - 6) * t * t)
            let b = Int(40 + (180 - 40) * t)
            a[y] = TrueColorBuffer.rgb(r, g, b)
        }
        return a
    }()

    private static let mtn: [Int] = {
        var a = [Int](repeating: 2, count: 512)
        for i in 0..<512 {
            let ang: Float = Float(i) / 512.0 * 2.0 * Float.pi
            let f: Float = 6 + 4 * sin(ang * 3) + 3 * sin(ang * 7 + 1) + 2 * sin(ang * 13)
            a[i] = max(1, Int(f))
        }
        return a
    }()

    // MARK: - State

    private var phase: Phase = .title
    private var frameN = 0
    private var rng = Rng()

    private var px: Float = 0
    private var py: Float = -15
    private var pvx: Float = 0
    private var pvy: Float = 0
    private var bank: Float = 0
    private var camX: Float = 0
    private var shx: Float = 0
    private var shy: Float = 0
    private var shake = 0

    private var shield = 100
    private var invuln = 0
    private var fireCd = 0
    private var fireToggle = false
    private var rollT = 0
    private var rollCd = 0
    private var rollDir: Float = 1

    private var speed: Float = 9
    private var trav: Float = 0

    private var ents: [Ent] = []
    private var newEnts: [Ent] = []
    private var shots: [Shot] = []
    private var parts: [Part] = []

    private var starX = [Float](repeating: 0, count: 90)
    private var starY = [Float](repeating: 0, count: 90)
    private var starZ = [Float](repeating: 100, count: 90)

    private var stage = 0
    private var spawned = 0
    private var spawnTimer = 60
    private var stageGate = 0
    private var bannerT = 0
    private var bannerText = ""
    private var bossActive = false
    private var bossHpMax = 100
    private var bossHp = 0
    private var bossDown = false
    private var bossDownT = 0
    private var bossX: Float = 0
    private var bossY: Float = 0
    private var bossZ: Float = 440

    private var scoreValue = 0
    private var kills = 0
    private var ringsGot = 0
    private var gatesGot = 0
    private var shotsFired = 0
    private var shotsHit = 0
    private var overT = 0
    private var victory = false
    private var shipDead = false

    override var score: Int { return max(0, scoreValue) }

    override init() {
        super.init()
        resetGame()
    }

    override func start() {
        playMusic(Tunes.space)
    }

    // MARK: - Setup

    private func resetGame() {
        phase = .title
        frameN = 0
        px = 0
        py = -15
        pvx = 0
        pvy = 0
        bank = 0
        camX = 0
        shake = 0
        shield = 100
        invuln = 0
        fireCd = 0
        rollT = 0
        rollCd = 0
        speed = 9
        trav = 0
        ents.removeAll()
        newEnts.removeAll()
        shots.removeAll()
        parts.removeAll()
        for i in 0..<90 {
            starX[i] = Float(rng.range(-900, 900))
            starY[i] = Float(rng.range(5, 900))
            starZ[i] = Float(rng.range(80, 2000))
        }
        stage = 0
        spawned = 0
        spawnTimer = 70
        stageGate = 0
        bannerT = 0
        bannerText = ""
        bossActive = false
        bossHp = 0
        bossDown = false
        bossDownT = 0
        scoreValue = 0
        kills = 0
        ringsGot = 0
        gatesGot = 0
        shotsFired = 0
        shotsHit = 0
        overT = 0
        victory = false
        shipDead = false
    }

    private func beginPlay() {
        resetGame()
        phase = .play
        bannerText = "WAVE 1"
        bannerT = 110
        playMusic(Tunes.space)
    }

    // MARK: - Update

    override func update(_ input: InputState) {
        frameN += 1
        shx = sin(Float(frameN) * 2.3) * Float(shake) * 0.6
        shy = cos(Float(frameN) * 1.9) * Float(shake) * 0.6
        if shake > 0 { shake -= 1 }
        switch phase {
        case .title:
            speed = 7
            advanceWorld()
            px = sin(Float(frameN) * 0.03) * 50
            py = -15 + sin(Float(frameN) * 0.05) * 15
            bank = -cos(Float(frameN) * 0.03) * 0.3
            camX += (px * 0.45 - camX) * 0.1
            if input.aPressed || input.startPressed {
                play(.confirm)
                beginPlay()
            }
        case .play:
            updatePlay(input)
        case .over:
            overT += 1
            speed *= 0.985
            advanceWorld()
            updateParts()
            parts.removeAll(where: { $0.dead })
            shots.removeAll()
            if overT > 70 && (input.aPressed || input.startPressed) {
                play(.confirm)
                beginPlay()
            }
        }
    }

    private func advanceWorld() {
        trav += speed
        if trav > 65536 { trav -= 65536 }
        for i in 0..<90 {
            starZ[i] -= speed * 1.6
            if starZ[i] < 70 {
                starZ[i] += 1900
                starX[i] = Float(rng.range(-900, 900))
                starY[i] = Float(rng.range(5, 900))
            }
        }
    }

    private func updatePlay(_ input: InputState) {
        speed = 9 + Float(min(stage, 2)) * 1.5
        if bossActive { speed = 8 }
        advanceWorld()

        // steering
        let tvx: Float = Float(input.dx) * 3.6
        let tvy: Float = Float(-input.dy) * 3.0
        pvx += (tvx - pvx) * 0.22
        pvy += (tvy - pvy) * 0.22
        if rollT > 0 { px += rollDir * 2.2 }
        px += pvx
        py += pvy
        px = StarWing64.cf(px, -StarWing64.xLim, StarWing64.xLim)
        py = StarWing64.cf(py, StarWing64.yMin, StarWing64.yMax)
        bank += (-pvx * 0.09 - bank) * 0.2
        camX += (px * 0.45 - camX) * 0.1
        if invuln > 0 { invuln -= 1 }
        if rollCd > 0 { rollCd -= 1 }

        // roll
        if input.bPressed && rollCd == 0 && rollT == 0 {
            rollT = StarWing64.rollLen
            rollCd = StarWing64.rollCooldown
            if input.dx != 0 { rollDir = Float(input.dx) } else { rollDir = (px > 0) ? -1 : 1 }
            play(.jump)
        }
        if rollT > 0 {
            rollT -= 1
            reflectBullets()
        }

        // fire
        if fireCd > 0 { fireCd -= 1 }
        if input.a && fireCd == 0 && rollT == 0 {
            fireCd = 7
            var s1 = Shot()
            s1.x = px - 11
            s1.y = py
            s1.z = StarWing64.shipZ
            var s2 = s1
            s2.x = px + 11
            shots.append(s1)
            shots.append(s2)
            shotsFired += 2
            fireToggle = !fireToggle
            if fireToggle { play(.laser) }
        }

        directorUpdate()
        updateEnts()
        updateShots()
        resolveShots()
        updateParts()

        ents.removeAll(where: { $0.dead })
        shots.removeAll(where: { $0.dead })
        parts.removeAll(where: { $0.dead })
        sortEnts()

        if bannerT > 0 { bannerT -= 1 }
        if bossDown {
            bossDownT += 1
            if bossDownT % 5 == 0 {
                let ox: Float = Float(rng.range(-60, 60))
                let oy: Float = Float(rng.range(-30, 30))
                explode(bossX + ox, bossY + oy, bossZ, 14, 1.4)
                if bossDownT % 10 == 0 { play(.explosion) }
            }
            if bossDownT > 150 { finish(true) }
        }
    }

    private func finish(_ won: Bool) {
        phase = .over
        overT = 0
        victory = won
        playMusic(nil)
        if won {
            scoreValue += max(0, shield) * 20
            play(.win)
        } else {
            play(.death)
        }
    }

    private func hurt(_ dmg: Int) {
        if invuln > 0 || rollT > 0 { return }
        shield -= dmg
        invuln = 70
        shake = 12
        play(.hurt)
        if shield <= 0 {
            shield = 0
            shipDead = true
            explode(px, py, StarWing64.shipZ, 40, 1.6)
            finish(false)
        }
    }

    private func reflectBullets() {
        for i in 0..<ents.count {
            if ents[i].kind != StarWing64.kBullet || ents[i].dead { continue }
            let e = ents[i]
            if e.z > StarWing64.shipZ + 320 || e.z < StarWing64.shipZ - 40 { continue }
            if abs(e.x - px) < 62 && abs(e.y - py) < 62 {
                ents[i].dead = true
                var s = Shot()
                s.x = e.x
                s.y = e.y
                s.z = e.z
                s.dz = 26
                s.dmg = 3
                s.refl = true
                shots.append(s)
                scoreValue += 10
                play(.bounce)
            }
        }
    }

    // MARK: - Director

    private static let quotas: [Int] = [14, 20, 26]
    private static let intervals: [Int] = [70, 56, 44]

    private func directorUpdate() {
        if stage > 2 { return }
        if stageGate > 0 {
            stageGate -= 1
            if stageGate == 0 { advanceStage() }
            return
        }
        let quota = StarWing64.quotas[stage]
        if spawned < quota {
            spawnTimer -= 1
            if spawnTimer <= 0 {
                spawnEvent()
                spawnTimer = StarWing64.intervals[stage]
            }
        } else if ents.isEmpty {
            stageGate = 130
            scoreValue += 500 + shield * 5
            bannerText = "WAVE " + String(stage + 1) + " CLEAR"
            bannerT = 120
            play(.powerup)
        }
    }

    private func advanceStage() {
        stage += 1
        spawned = 0
        spawnTimer = 50
        if stage >= 3 {
            bannerText = "WARNING"
            bannerT = 130
            spawnBoss()
        } else {
            bannerText = "WAVE " + String(stage + 1)
            bannerT = 110
        }
    }

    private func spawnEvent() {
        let roll = rng.int(100)
        let rx: Float = Float(rng.range(-90, 90))
        let ry: Float = Float(rng.range(-50, 25))
        switch stage {
        case 0:
            if roll < 40 {
                spawnRock(rx, ry)
                spawned += 1
            } else if roll < 72 {
                spawnFighter(rx, ry)
                spawned += 1
            } else if roll < 88 {
                spawnGate(rx * 0.6, ry * 0.6)
                spawned += 1
            } else if roll < 94 && shield < 90 {
                spawnRing(rx * 0.6, ry * 0.6)
                spawned += 1
            } else {
                spawnRock(rx, ry)
                spawned += 1
            }
        case 1:
            if roll < 15 {
                spawnRock(rx, ry)
                spawned += 1
            } else if roll < 55 {
                for i in -1...1 {
                    spawnFighter(rx * 0.5 + Float(i) * 45, ry + Float(abs(i)) * 14)
                }
                spawned += 3
            } else if roll < 75 {
                spawnFighter(rx, ry)
                spawned += 1
            } else if roll < 90 {
                spawnGate(rx * 0.6, ry * 0.6)
                spawned += 1
            } else if shield < 90 {
                spawnRing(rx * 0.6, ry * 0.6)
                spawned += 1
            } else {
                spawnRock(rx, ry)
                spawned += 1
            }
        default:
            if roll < 25 {
                for i in 0..<3 {
                    spawnRock(rx + Float(i) * 38 - 38, ry + Float(rng.range(-20, 20)))
                }
                spawned += 3
            } else if roll < 62 {
                for i in 0..<4 {
                    spawnFighter(-75 + Float(i) * 50, ry + Float(i % 2) * 18)
                }
                spawned += 4
            } else if roll < 78 {
                spawnFighter(rx, ry)
                spawned += 1
            } else if roll < 92 {
                spawnGate(rx * 0.6, ry * 0.6)
                spawned += 1
            } else if shield < 85 {
                spawnRing(rx * 0.6, ry * 0.6)
                spawned += 1
            } else {
                spawnRock(rx, ry)
                spawned += 1
            }
        }
    }

    private func spawnFighter(_ x: Float, _ y: Float) {
        var e = Ent()
        e.kind = StarWing64.kFighter
        e.bx = StarWing64.cf(x, -95, 95)
        e.by = StarWing64.cf(y, -55, 28)
        e.x = e.bx
        e.y = e.by
        e.z = StarWing64.farZ
        e.dz = -(speed + 2 + Float(stage) * 0.8)
        e.amp = Float(rng.range(8, 36))
        e.ph = Float(rng.int(628)) / 100
        e.hp = 2
        e.r = 17
        e.hr = 17
        e.fire = rng.range(50, 190)
        ents.append(e)
    }

    private func spawnRock(_ x: Float, _ y: Float) {
        var e = Ent()
        e.kind = StarWing64.kRock
        e.x = StarWing64.cf(x, -110, 110)
        e.y = StarWing64.cf(y, -60, 32)
        e.z = StarWing64.farZ
        e.dz = -speed
        let big = rng.chance(40)
        e.r = big ? 30 : 19
        e.hr = e.r
        e.hp = big ? 4 : 2
        e.ph = Float(rng.int(628)) / 100
        ents.append(e)
    }

    private func spawnGate(_ x: Float, _ y: Float) {
        var e = Ent()
        e.kind = StarWing64.kGate
        e.x = StarWing64.cf(x, -80, 80)
        e.y = StarWing64.cf(y, -45, 22)
        e.z = StarWing64.farZ
        e.dz = -speed
        e.r = 62
        e.hr = 62
        ents.append(e)
    }

    private func spawnRing(_ x: Float, _ y: Float) {
        var e = Ent()
        e.kind = StarWing64.kRing
        e.x = StarWing64.cf(x, -80, 80)
        e.y = StarWing64.cf(y, -45, 22)
        e.z = StarWing64.farZ
        e.dz = -speed
        e.r = 44
        e.hr = 44
        ents.append(e)
    }

    private func spawnBoss() {
        var e = Ent()
        e.kind = StarWing64.kBoss
        e.x = 0
        e.y = -10
        e.z = 1300
        e.r = 100
        e.hr = 72
        e.hp = bossHpMax
        e.fire = 90
        ents.append(e)
        bossActive = true
        bossHp = bossHpMax
        bossDown = false
    }

    private func fireAt(_ x: Float, _ y: Float, _ z: Float, _ tx: Float, _ ty: Float, _ spd: Float) {
        var b = Ent()
        b.kind = StarWing64.kBullet
        b.x = x
        b.y = y
        b.z = z
        b.dz = -spd
        let frames: Float = max(1, (z - StarWing64.shipZ) / spd)
        b.vx = (tx - x) / frames
        b.vy = (ty - y) / frames
        b.r = 6
        b.hr = 6
        newEnts.append(b)
    }

    // MARK: - Entities

    private func updateEnts() {
        newEnts.removeAll(keepingCapacity: true)
        let sz = StarWing64.shipZ
        for i in 0..<ents.count {
            var e = ents[i]
            if e.dead { continue }
            e.t += 1
            if e.flash > 0 { e.flash -= 1 }
            switch e.kind {
            case StarWing64.kFighter:
                e.z += e.dz
                let a: Float = e.ph + Float(e.t) * 0.04
                e.x = StarWing64.cf(e.bx + sin(a) * e.amp, -120, 120)
                e.y = StarWing64.cf(e.by + cos(a * 1.3) * e.amp * 0.5, -70, 40)
                e.fire -= 1
                if e.fire <= 0 && e.z > sz + 260 {
                    fireAt(e.x, e.y, e.z, px, py, 15)
                    e.fire = max(45, rng.range(80, 150) - stage * 18)
                }
                if e.z < 36 { e.dead = true }
                if abs(e.z - sz) < 26 && abs(e.x - px) < e.hr + 12 && abs(e.y - py) < e.hr + 10 {
                    e.dead = true
                    explode(e.x, e.y, e.z, 18, 1.0)
                    play(.explosion)
                    hurt(25)
                }
            case StarWing64.kRock:
                e.z += e.dz
                if e.z < 36 { e.dead = true }
                if abs(e.z - sz) < 26 && abs(e.x - px) < e.hr + 12 && abs(e.y - py) < e.hr + 10 {
                    e.dead = true
                    explode(e.x, e.y, e.z, 16, 1.0)
                    play(.thud)
                    hurt(20)
                }
            case StarWing64.kGate:
                e.z += e.dz
                if !e.used && e.z <= sz {
                    e.used = true
                    let dx: Float = e.x - px
                    let dy: Float = e.y - py
                    if dx * dx + dy * dy < 46 * 46 {
                        scoreValue += 500
                        gatesGot += 1
                        play(.coin)
                        explode(e.x, e.y, e.z, 12, 0.6)
                        bannerText = "GATE +500"
                        bannerT = 40
                    }
                }
                if e.z < 46 { e.dead = true }
            case StarWing64.kRing:
                e.z += e.dz
                if !e.used && e.z <= sz {
                    e.used = true
                    let dx: Float = e.x - px
                    let dy: Float = e.y - py
                    if dx * dx + dy * dy < 40 * 40 {
                        shield = min(100, shield + 30)
                        scoreValue += 200
                        ringsGot += 1
                        play(.powerup)
                        bannerText = "SHIELD REPAIRED"
                        bannerT = 50
                    }
                }
                if e.z < 46 { e.dead = true }
            case StarWing64.kBullet:
                e.x += e.vx
                e.y += e.vy
                e.z += e.dz
                if e.z < 30 { e.dead = true }
                if e.z < sz + 12 && e.z > sz - 34 {
                    let dx: Float = e.x - px
                    let dy: Float = e.y - py
                    if dx * dx + dy * dy < 22 * 22 {
                        e.dead = true
                        hurt(15)
                    }
                }
            default:
                updateBoss(&e)
            }
            ents[i] = e
        }
        if !newEnts.isEmpty { ents.append(contentsOf: newEnts) }
    }

    private func updateBoss(_ e: inout Ent) {
        if e.z > 440 {
            e.z -= 6
            if e.z < 440 { e.z = 440 }
            e.x = sin(Float(e.t) * 0.03) * 20
        } else {
            e.z = 440
            let tt: Float = Float(e.t)
            e.x = sin(tt * 0.022) * 72
            e.y = -10 + sin(tt * 0.031) * 26
            e.fire -= 1
            if e.fire <= 0 {
                let hp = e.hp
                if hp > 66 {
                    fireAt(e.x - 50, e.y, e.z, px, py, 9)
                    fireAt(e.x + 50, e.y, e.z, px, py, 9)
                    e.fire = 50
                } else if hp > 33 {
                    fireAt(e.x, e.y, e.z, px, py, 10)
                    fireAt(e.x - 50, e.y, e.z, px - 55, py, 10)
                    fireAt(e.x + 50, e.y, e.z, px + 55, py, 10)
                    e.fire = 44
                } else {
                    for i in 0..<8 {
                        let a: Float = Float(i) * 0.7854 + Float(e.t) * 0.05
                        fireAt(e.x, e.y, e.z, px + cos(a) * 55, py + sin(a) * 40, 9)
                    }
                    e.fire = 62
                }
                play(.shoot)
            }
        }
        bossX = e.x
        bossY = e.y
        bossZ = e.z
        bossHp = e.hp
    }

    private func updateShots() {
        for i in 0..<shots.count {
            shots[i].z += shots[i].dz
            if shots[i].z > StarWing64.farZ + 100 { shots[i].dead = true }
        }
    }

    private func resolveShots() {
        for si in 0..<shots.count {
            var s = shots[si]
            if s.dead { continue }
            for ei in 0..<ents.count {
                var e = ents[ei]
                if e.dead { continue }
                let k = e.kind
                if k == StarWing64.kGate || k == StarWing64.kRing || k == StarWing64.kBullet { continue }
                let rr: Float = e.hr + 5
                if abs(e.x - s.x) < rr && abs(e.y - s.y) < rr && abs(e.z - s.z) < 45 {
                    e.hp -= s.dmg
                    e.flash = 4
                    s.dead = true
                    shotsHit += 1
                    if e.hp <= 0 {
                        e.dead = true
                        destroyEnt(e)
                    } else if frameN % 3 == 0 {
                        play(.hit)
                    }
                    ents[ei] = e
                    break
                }
            }
            shots[si] = s
        }
    }

    private func destroyEnt(_ e: Ent) {
        kills += 1
        if e.kind == StarWing64.kBoss {
            scoreValue += 5000
            bossDown = true
            bossDownT = 0
            bossActive = false
            bossHp = 0
            bossX = e.x
            bossY = e.y
            bossZ = e.z
            explode(e.x, e.y, e.z, 50, 2.0)
            play(.explosion)
            for i in 0..<ents.count where ents[i].kind == StarWing64.kBullet { ents[i].dead = true }
            bannerText = "BOSS DESTROYED"
            bannerT = 140
        } else if e.kind == StarWing64.kFighter {
            scoreValue += 100
            explode(e.x, e.y, e.z, 20, 1.0)
            play(.explosion)
        } else {
            scoreValue += 50
            explode(e.x, e.y, e.z, 12, 0.7)
            play(.stomp)
        }
    }

    // MARK: - Particles

    private static let partCols: [Int] = [255, 160, 40, 255, 230, 90, 255, 255, 200, 255, 90, 60]

    private func explode(_ x: Float, _ y: Float, _ z: Float, _ n: Int, _ power: Float) {
        if parts.count > 240 { return }
        for _ in 0..<n {
            var p = Part()
            p.x = x
            p.y = y
            p.z = z
            let a: Float = Float(rng.int(628)) / 100
            let s: Float = (0.4 + Float(rng.int(100)) / 40) * power
            p.vx = cos(a) * s
            p.vy = sin(a) * s
            p.dz = -speed + (Float(rng.int(100)) - 50) / 12
            p.life = rng.range(18, 40)
            p.maxLife = p.life
            let ci = rng.int(4) * 3
            p.cr = StarWing64.partCols[ci]
            p.cg = StarWing64.partCols[ci + 1]
            p.cb = StarWing64.partCols[ci + 2]
            p.size = 2 + Float(rng.int(4)) * power
            parts.append(p)
        }
    }

    private func updateParts() {
        for i in 0..<parts.count {
            parts[i].x += parts[i].vx
            parts[i].y += parts[i].vy
            parts[i].z += parts[i].dz
            parts[i].life -= 1
            if parts[i].life <= 0 || parts[i].z < 40 { parts[i].dead = true }
        }
    }

    private func sortEnts() {
        let n = ents.count
        if n < 2 { return }
        for i in 1..<n {
            let key = ents[i]
            var j = i - 1
            while j >= 0 && ents[j].z < key.z {
                ents[j + 1] = ents[j]
                j -= 1
            }
            ents[j + 1] = key
        }
    }

    // MARK: - Pixel helpers

    private static func cf(_ v: Float, _ lo: Float, _ hi: Float) -> Float {
        if !v.isFinite { return 0 }
        return min(max(v, lo), hi)
    }

    private static func hspan(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ y: Int, _ x0: Int, _ x1: Int, _ c: UInt32) {
        if y < 0 || y >= h { return }
        let a = max(0, x0)
        let b = min(w - 1, x1)
        if a > b { return }
        let base = y * w
        var x = a
        while x <= b {
            p[base + x] = c
            x += 1
        }
    }

    private static func rectP(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: UInt32) {
        if rw <= 0 || rh <= 0 { return }
        let y0 = max(0, y)
        let y1 = min(h, y + rh)
        if y0 >= y1 { return }
        for yy in y0..<y1 {
            StarWing64.hspan(p, w, h, yy, x, x + rw - 1, c)
        }
    }

    private static func disc(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ cx: Float, _ cy: Float, _ r: Float, _ c: UInt32) {
        let rr: Float = StarWing64.cf(r, 0, 380)
        let ri = max(1, Int(rr + 0.5))
        let cxi = Int(StarWing64.cf(cx, -2000, 2000))
        let cyi = Int(StarWing64.cf(cy, -2000, 2000))
        let y0 = max(0, cyi - ri)
        let y1 = min(h - 1, cyi + ri)
        if y0 > y1 { return }
        for y in y0...y1 {
            let dy = y - cyi
            let q = ri * ri - dy * dy
            if q < 0 { continue }
            let half = Int(sqrt(Float(q)))
            StarWing64.hspan(p, w, h, y, cxi - half, cxi + half, c)
        }
    }

    private static func ringP(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ cx: Float, _ cy: Float, _ r: Float, _ th: Float, _ c: UInt32) {
        let rr: Float = StarWing64.cf(r, 0, 380)
        let ro = max(2, Int(rr + 0.5))
        let ri = max(0, ro - max(1, Int(th)))
        let cxi = Int(StarWing64.cf(cx, -2000, 2000))
        let cyi = Int(StarWing64.cf(cy, -2000, 2000))
        let y0 = max(0, cyi - ro)
        let y1 = min(h - 1, cyi + ro)
        if y0 > y1 { return }
        for y in y0...y1 {
            let dy = y - cyi
            let qo = ro * ro - dy * dy
            if qo < 0 { continue }
            let ho = Int(sqrt(Float(qo)))
            let qi = ri * ri - dy * dy
            if qi > 0 {
                let hi = Int(sqrt(Float(qi)))
                StarWing64.hspan(p, w, h, y, cxi - ho, cxi - hi, c)
                StarWing64.hspan(p, w, h, y, cxi + hi, cxi + ho, c)
            } else {
                StarWing64.hspan(p, w, h, y, cxi - ho, cxi + ho, c)
            }
        }
    }

    private static func edge(_ ax: Float, _ ay: Float, _ bx: Float, _ by: Float, _ fy: Float, _ lo: inout Float, _ hi: inout Float) {
        let mn: Float = min(ay, by)
        let mx: Float = max(ay, by)
        if fy >= mn && fy < mx {
            let t: Float = (fy - ay) / (by - ay)
            let x: Float = ax + t * (bx - ax)
            if x < lo { lo = x }
            if x > hi { hi = x }
        }
    }

    private static func tri(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int,
                            _ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float, _ c: UInt32) {
        let ax: Float = StarWing64.cf(x0, -2000, 2000)
        let ay: Float = StarWing64.cf(y0, -2000, 2000)
        let bx: Float = StarWing64.cf(x1, -2000, 2000)
        let by: Float = StarWing64.cf(y1, -2000, 2000)
        let cx: Float = StarWing64.cf(x2, -2000, 2000)
        let cy: Float = StarWing64.cf(y2, -2000, 2000)
        let ymin = max(0, Int(min(ay, min(by, cy))))
        let ymax = min(h - 1, Int(max(ay, max(by, cy))) + 1)
        if ymin > ymax { return }
        for y in ymin...ymax {
            let fy: Float = Float(y) + 0.5
            var lo: Float = 100000
            var hi: Float = -100000
            StarWing64.edge(ax, ay, bx, by, fy, &lo, &hi)
            StarWing64.edge(bx, by, cx, cy, fy, &lo, &hi)
            StarWing64.edge(cx, cy, ax, ay, fy, &lo, &hi)
            if lo <= hi {
                StarWing64.hspan(p, w, h, y, Int(lo + 0.5), Int(hi - 0.5), c)
            }
        }
    }

    private static func lineP(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int,
                              _ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float, _ th: Int, _ c: UInt32) {
        let ax: Float = StarWing64.cf(x0, -1500, 1500)
        let ay: Float = StarWing64.cf(y0, -1500, 1500)
        let bx: Float = StarWing64.cf(x1, -1500, 1500)
        let by: Float = StarWing64.cf(y1, -1500, 1500)
        let dx: Float = bx - ax
        let dy: Float = by - ay
        let steps = min(400, max(1, Int(max(abs(dx), abs(dy)))))
        let sx: Float = dx / Float(steps)
        let sy: Float = dy / Float(steps)
        var fx: Float = ax
        var fy: Float = ay
        for _ in 0...steps {
            StarWing64.rectP(p, w, h, Int(fx), Int(fy), th, th, c)
            fx += sx
            fy += sy
        }
    }

    // MARK: - Rendering

    override func drawTrueColor(_ b: TrueColorBuffer) {
        b.withPixels { p, w, h in
            if w < 320 || h < 288 { return }
            self.renderSky(p, w, h)
            self.renderFloor(p, w, h)
            self.renderWorld(p, w, h)
        }
        drawHUD(b)
        drawOverlays(b)
    }

    private func renderSky(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        let hz = StarWing64.hz
        for y in 0...hz {
            let c = StarWing64.skyRows[y]
            let base = y * w
            var x = 0
            while x < w {
                p[base + x] = c
                x += 1
            }
        }
        // planet with ring
        let pcx: Float = 236 - camX * 0.1
        let pcy: Float = 58
        let pr = 30
        for dy in -pr...pr {
            let q = pr * pr - dy * dy
            let half = Int(sqrt(Float(max(0, q))))
            if half <= 0 { continue }
            for dx in -half...half {
                let lit = 150 - dx * 3 - dy * 2
                let l = max(40, min(255, lit))
                let r = 255 * l / 255
                let g = 150 * l / 255
                let bl = 60 * l / 255
                let px = Int(pcx) + dx
                let py = Int(pcy) + dy
                if px >= 0 && px < w && py >= 0 && py < hz {
                    p[py * w + px] = TrueColorBuffer.rgb(r, g, bl)
                }
            }
        }
        let ringC = TrueColorBuffer.rgb(255, 220, 170)
        for dx in -48...48 {
            let t: Float = Float(dx) / 48
            let dyf: Float = sqrt(max(0, 1 - t * t)) * 7
            let px = Int(pcx) + dx
            let py = Int(pcy) + Int(dyf * 0.5) + 4
            if abs(dx) > 20 || dyf > 3 {
                if px >= 0 && px < w && py >= 0 && py < hz { p[py * w + px] = ringC }
            }
        }
        // stars
        let f = StarWing64.focal
        for i in 0..<90 {
            let z = starZ[i]
            if z < 60 { continue }
            let inv: Float = f / z
            let sx = Int(160 + (starX[i] - camX * 0.5) * inv)
            let sy = Int(Float(hz) - starY[i] * inv)
            if sx < 0 || sx >= w - 1 || sy < 0 || sy >= hz - 1 { continue }
            let bv = max(110, min(255, Int(300 - z / 8)))
            let c = TrueColorBuffer.rgb(bv, bv, 255)
            p[sy * w + sx] = c
            if z < 700 {
                p[sy * w + sx + 1] = c
                p[(sy + 1) * w + sx] = c
            }
        }
        // mountains
        let mc = TrueColorBuffer.rgb(58, 28, 104)
        let rim = TrueColorBuffer.rgb(150, 100, 210)
        let shift = Int(camX * 0.25) + 4096
        for x in 0..<w {
            let mi = (x + shift) & 511
            let mh = StarWing64.mtn[mi]
            var y = hz - mh
            if y < 0 { y = 0 }
            p[y * w + x] = rim
            if y + 1 <= hz {
                for yy in (y + 1)...hz { p[yy * w + x] = mc }
            }
        }
    }

    private func renderFloor(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        let t = StarWing64.ftab
        let hz = StarWing64.hz
        let off: Float = camX + 20000
        for r in (hz + 1)..<h {
            let base = r * w
            if t.far[r] {
                let c = t.baseA[r]
                var x = 0
                while x < w {
                    p[base + x] = c
                    x += 1
                }
                continue
            }
            let q: Float = t.z[r] + trav
            let qi = Int(q)
            let frac: Float = q - Float(qi)
            let zmf: Float = Float(qi & 63) + frac
            if zmf < t.zt[r] {
                let c = t.lz[r]
                var x = 0
                while x < w {
                    p[base + x] = c
                    x += 1
                }
                continue
            }
            let zpar = (qi >> 6) & 1
            let k = t.k[r]
            let xt = t.xt[r]
            let ca = t.baseA[r]
            let cb = t.baseB[r]
            let lx = t.lx[r]
            var x = 0
            while x < w {
                let wx: Float = Float(x - 160) * k + off
                let wi = Int(wx)
                let m = wi & 63
                if m < xt {
                    p[base + x] = lx
                } else if ((wi >> 6) & 1) == zpar {
                    p[base + x] = ca
                } else {
                    p[base + x] = cb
                }
                x += 1
            }
        }
    }

    private func renderWorld(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        var shipDrawn = false
        let sz = StarWing64.shipZ
        for e in ents {
            if !shipDrawn && e.z <= sz {
                drawShip(p, w, h)
                shipDrawn = true
            }
            drawEnt(p, w, h, e)
        }
        if !shipDrawn { drawShip(p, w, h) }
        drawShots(p, w, h)
        drawParts(p, w, h)
        drawReticle(p, w, h)
    }

    private func scrX(_ x: Float, _ z: Float) -> Float {
        return 160 + shx + (x - camX) * StarWing64.focal / z
    }

    private func scrY(_ y: Float, _ z: Float) -> Float {
        return Float(StarWing64.hz) + shy - y * StarWing64.focal / z
    }

    private func drawReticle(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        if phase != .play { return }
        let rz: Float = 650
        let sx = Int(scrX(px, rz))
        let sy = Int(scrY(py, rz))
        let c = StarWing64.cGreen
        StarWing64.rectP(p, w, h, sx - 9, sy, 5, 1, c)
        StarWing64.rectP(p, w, h, sx + 5, sy, 5, 1, c)
        StarWing64.rectP(p, w, h, sx, sy - 9, 1, 5, c)
        StarWing64.rectP(p, w, h, sx, sy + 5, 1, 5, c)
        StarWing64.rectP(p, w, h, sx - 1, sy - 1, 3, 3, c)
    }

    private func drawShip(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        if shipDead { return }
        let u: Float = StarWing64.focal / StarWing64.shipZ
        let sx: Float = 160 + shx + (px - camX) * u
        let sy: Float = Float(StarWing64.hz) + shy - py * u
        // ground shadow
        let gy = Int(Float(StarWing64.hz) + StarWing64.camH * u + shy)
        let shadow = TrueColorBuffer.rgb(6, 14, 34)
        for dy in -2...2 {
            let half = 18 - abs(dy) * 5
            StarWing64.hspan(p, w, h, gy + dy, Int(sx) - half, Int(sx) + half, shadow)
        }
        if invuln > 0 && rollT == 0 && (frameN / 3) % 2 == 0 { return }
        let ca: Float = cos(bank)
        let sa: Float = sin(bank)
        var k: Float = 1
        if rollT > 0 {
            let prog: Float = 1 - Float(rollT) / Float(StarWing64.rollLen)
            k = cos(prog * 2 * Float.pi * rollDir)
        }
        func ox(_ lx: Float, _ ly: Float) -> Float { return sx + lx * ca - ly * sa }
        func oy(_ lx: Float, _ ly: Float) -> Float { return sy - (lx * sa + ly * ca) }
        let body = TrueColorBuffer.rgb(236, 242, 255)
        let wingL = TrueColorBuffer.rgb(255, 110, 70)
        let wingR = TrueColorBuffer.rgb(255, 160, 80)
        let fin = TrueColorBuffer.rgb(255, 230, 90)
        let flameC = (frameN & 1) == 0 ? TrueColorBuffer.rgb(255, 200, 60) : TrueColorBuffer.rgb(255, 120, 40)
        // engine flame
        StarWing64.tri(p, w, h, ox(-4, -12), oy(-4, -12), ox(4, -12), oy(4, -12), ox(0, -26 - Float(frameN & 3) * 2), oy(0, -26 - Float(frameN & 3) * 2), flameC)
        // wings
        StarWing64.tri(p, w, h, ox(-5 * k, 6), oy(-5 * k, 6), ox(-32 * k, -14), oy(-32 * k, -14), ox(-5 * k, -12), oy(-5 * k, -12), wingL)
        StarWing64.tri(p, w, h, ox(5 * k, 6), oy(5 * k, 6), ox(32 * k, -14), oy(32 * k, -14), ox(5 * k, -12), oy(5 * k, -12), wingR)
        // fin
        StarWing64.tri(p, w, h, ox(-2, -2), oy(-2, -2), ox(2, -2), oy(2, -2), ox(0, -20), oy(0, -20), fin)
        // body
        StarWing64.tri(p, w, h, ox(0, 22), oy(0, 22), ox(-8, -12), oy(-8, -12), ox(8, -12), oy(8, -12), body)
        StarWing64.disc(p, w, h, ox(0, 6), oy(0, 6), 4, StarWing64.cCyan)
        if rollT > 0 {
            StarWing64.ringP(p, w, h, sx, sy, 40, 3, StarWing64.cCyan)
        }
    }

    private func drawEnt(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ e: Ent) {
        if e.z < 40 { return }
        let u: Float = StarWing64.focal / e.z
        let sx: Float = scrX(e.x, e.z)
        let sy: Float = scrY(e.y, e.z)
        if sx < -320 || sx > 640 || sy < -320 || sy > 620 { return }
        let rad: Float = e.r * u
        let flash = e.flash > 0
        switch e.kind {
        case StarWing64.kFighter:
            let bodyC = flash ? StarWing64.cWhite : TrueColorBuffer.rgb(236, 64, 64)
            let bodyD = flash ? StarWing64.cWhite : TrueColorBuffer.rgb(170, 30, 60)
            let wingC = flash ? StarWing64.cWhite : TrueColorBuffer.rgb(255, 170, 50)
            let dark = TrueColorBuffer.rgb(30, 10, 20)
            let R: Float = rad
            // outline
            StarWing64.tri(p, w, h, sx - R * 0.45 - 1, sy - R * 0.1 + 1, sx - R * 1.7 - 1, sy + R * 0.55 + 1, sx - R * 0.4, sy + R * 0.6 + 1, dark)
            StarWing64.tri(p, w, h, sx + R * 0.45 + 1, sy - R * 0.1 + 1, sx + R * 1.7 + 1, sy + R * 0.55 + 1, sx + R * 0.4, sy + R * 0.6 + 1, dark)
            StarWing64.tri(p, w, h, sx - R * 0.4, sy - R * 0.1, sx - R * 1.6, sy + R * 0.5, sx - R * 0.4, sy + R * 0.5, wingC)
            StarWing64.tri(p, w, h, sx + R * 0.4, sy - R * 0.1, sx + R * 1.6, sy + R * 0.5, sx + R * 0.4, sy + R * 0.5, wingC)
            StarWing64.tri(p, w, h, sx, sy - R * 0.95, sx - R * 0.5, sy, sx, sy + R * 0.85, bodyD)
            StarWing64.tri(p, w, h, sx, sy - R * 0.95, sx + R * 0.5, sy, sx, sy + R * 0.85, bodyC)
            StarWing64.disc(p, w, h, sx, sy - R * 0.1, R * 0.22, StarWing64.cYellow)
        case StarWing64.kRock:
            let dark = TrueColorBuffer.rgb(40, 30, 30)
            let base = flash ? StarWing64.cWhite : TrueColorBuffer.rgb(160, 138, 116)
            let hi = flash ? StarWing64.cWhite : TrueColorBuffer.rgb(206, 186, 158)
            let crater = TrueColorBuffer.rgb(112, 94, 80)
            StarWing64.disc(p, w, h, sx, sy, rad + 1.5, dark)
            StarWing64.disc(p, w, h, sx, sy, rad, base)
            StarWing64.disc(p, w, h, sx - rad * 0.28, sy - rad * 0.28, rad * 0.6, hi)
            let a: Float = e.ph + Float(e.t) * 0.03
            StarWing64.disc(p, w, h, sx + cos(a) * rad * 0.45, sy + sin(a) * rad * 0.4, rad * 0.22, crater)
            StarWing64.disc(p, w, h, sx + cos(a + 2.4) * rad * 0.5, sy + sin(a + 2.4) * rad * 0.45, rad * 0.16, crater)
        case StarWing64.kGate:
            let th: Float = max(3, rad * 0.12)
            StarWing64.ringP(p, w, h, sx, sy, rad + 1, th + 2, StarWing64.cBlack)
            StarWing64.ringP(p, w, h, sx, sy, rad, th, e.used ? TrueColorBuffer.rgb(150, 150, 120) : StarWing64.cYellow)
            StarWing64.ringP(p, w, h, sx, sy, rad - th, max(1, th * 0.4), StarWing64.cWhite)
        case StarWing64.kRing:
            let th: Float = max(3, rad * 0.16)
            let pulse: Float = 1 + sin(Float(e.t) * 0.2) * 0.08
            StarWing64.ringP(p, w, h, sx, sy, rad * pulse + 1, th + 2, StarWing64.cBlack)
            StarWing64.ringP(p, w, h, sx, sy, rad * pulse, th, StarWing64.cGreen)
            let arm = Int(max(2, rad * 0.4))
            let thk = max(1, Int(rad * 0.1))
            StarWing64.rectP(p, w, h, Int(sx) - arm, Int(sy) - thk / 2, arm * 2, thk, StarWing64.cGreen)
            StarWing64.rectP(p, w, h, Int(sx) - thk / 2, Int(sy) - arm, thk, arm * 2, StarWing64.cGreen)
        case StarWing64.kBullet:
            let r: Float = max(2.5, 6 * u)
            StarWing64.disc(p, w, h, sx, sy, r + 1.5, TrueColorBuffer.rgb(120, 20, 10))
            StarWing64.disc(p, w, h, sx, sy, r, TrueColorBuffer.rgb(255, 130, 40))
            StarWing64.disc(p, w, h, sx, sy, r * 0.5, TrueColorBuffer.rgb(255, 255, 210))
        default:
            // boss
            let R: Float = rad
            let dark = TrueColorBuffer.rgb(26, 24, 44)
            let metal = flash ? StarWing64.cWhite : TrueColorBuffer.rgb(176, 184, 214)
            let metalD = flash ? StarWing64.cWhite : TrueColorBuffer.rgb(110, 118, 160)
            let wingC = flash ? StarWing64.cWhite : TrueColorBuffer.rgb(220, 70, 110)
            StarWing64.tri(p, w, h, sx - R * 0.5, sy - R * 0.3, sx - R * 2.0, sy + R * 0.4, sx - R * 0.5, sy + R * 0.6, dark)
            StarWing64.tri(p, w, h, sx + R * 0.5, sy - R * 0.3, sx + R * 2.0, sy + R * 0.4, sx + R * 0.5, sy + R * 0.6, dark)
            StarWing64.tri(p, w, h, sx - R * 0.55, sy - R * 0.25, sx - R * 1.9, sy + R * 0.36, sx - R * 0.55, sy + R * 0.5, wingC)
            StarWing64.tri(p, w, h, sx + R * 0.55, sy - R * 0.25, sx + R * 1.9, sy + R * 0.36, sx + R * 0.55, sy + R * 0.5, wingC)
            StarWing64.disc(p, w, h, sx, sy, R + 2, dark)
            StarWing64.disc(p, w, h, sx, sy, R, metalD)
            StarWing64.disc(p, w, h, sx - R * 0.12, sy - R * 0.12, R * 0.85, metal)
            StarWing64.disc(p, w, h, sx - R * 0.95, sy + R * 0.2, R * 0.28, dark)
            StarWing64.disc(p, w, h, sx + R * 0.95, sy + R * 0.2, R * 0.28, dark)
            StarWing64.disc(p, w, h, sx - R * 0.95, sy + R * 0.2, R * 0.2, StarWing64.cRed)
            StarWing64.disc(p, w, h, sx + R * 0.95, sy + R * 0.2, R * 0.2, StarWing64.cRed)
            let corePulse: Float = (e.t / 8) % 2 == 0 ? 0.3 : 0.24
            StarWing64.disc(p, w, h, sx, sy, R * (corePulse + 0.08), dark)
            StarWing64.disc(p, w, h, sx, sy, R * corePulse, StarWing64.cYellow)
            StarWing64.disc(p, w, h, sx, sy, R * corePulse * 0.5, StarWing64.cWhite)
        }
    }

    private func drawShots(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        for s in shots {
            if s.z < 60 { continue }
            let z2: Float = max(60, s.z - 26)
            let x0 = scrX(s.x, s.z)
            let y0 = scrY(s.y, s.z)
            let x1 = scrX(s.x, z2)
            let y1 = scrY(s.y, z2)
            if s.refl {
                StarWing64.lineP(p, w, h, x0, y0, x1, y1, 3, StarWing64.cCyan)
                StarWing64.disc(p, w, h, x0, y0, 3, StarWing64.cWhite)
            } else {
                StarWing64.lineP(p, w, h, x0, y0, x1, y1, 2, StarWing64.cGreen)
                StarWing64.disc(p, w, h, x0, y0, 2, StarWing64.cWhite)
            }
        }
    }

    private func drawParts(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        for q in parts {
            if q.z < 50 || q.dead { continue }
            let u: Float = StarWing64.focal / q.z
            let sx = scrX(q.x, q.z)
            let sy = scrY(q.y, q.z)
            let t: Float = Float(q.life) / Float(max(1, q.maxLife))
            let sz = max(1, Int(q.size * u * (0.4 + t * 0.6)))
            let fk: Float = 0.35 + 0.65 * t
            let cr = Int(Float(q.cr) * fk)
            let cg = Int(Float(q.cg) * fk)
            let cb = Int(Float(q.cb) * fk)
            let c = TrueColorBuffer.rgb(cr, cg, cb)
            StarWing64.rectP(p, w, h, Int(StarWing64.cf(sx, -500, 900)) - sz / 2, Int(StarWing64.cf(sy, -500, 900)) - sz / 2, sz, sz, c)
        }
    }

    // MARK: - HUD

    private func txt(_ b: TrueColorBuffer, _ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        b.text(s, x + scale, y + scale, StarWing64.cBlack, scale: scale)
        b.text(s, x, y, c, scale: scale)
    }

    private func ctxt(_ b: TrueColorBuffer, _ s: String, _ y: Int, _ c: UInt32, _ scale: Int) {
        let tw = b.textWidth(s, scale: scale)
        txt(b, s, (b.width - tw) / 2, y, c, scale)
    }

    private func drawHUD(_ b: TrueColorBuffer) {
        if phase == .title { return }
        txt(b, "SCORE " + zeroPad(scoreValue, 6), 6, 6, StarWing64.cWhite, 2)
        let waveText = stage >= 3 ? "BOSS" : "WAVE " + String(stage + 1) + "/3"
        txt(b, waveText, 6, 24, StarWing64.cYellow, 1)
        // shield bar
        let bx = 214
        let by = 8
        b.fillRect(bx - 2, by - 2, 104, 14, StarWing64.cBlack)
        let frac = max(0, min(100, shield))
        var sc = StarWing64.cGreen
        if frac < 60 { sc = StarWing64.cYellow }
        if frac < 30 { sc = StarWing64.cRed }
        b.fillRect(bx, by, frac, 10, sc)
        b.text("SHIELD", bx + 2, by + 2, StarWing64.cBlack, scale: 1)
        // roll indicator
        let ready = rollCd == 0
        let rc = ready ? StarWing64.cCyan : TrueColorBuffer.rgb(90, 100, 130)
        b.fillRect(214, 24, 104, 8, StarWing64.cBlack)
        let rw = ready ? 100 : max(0, 100 - rollCd * 100 / StarWing64.rollCooldown)
        b.fillRect(216, 26, rw, 4, rc)
        txt(b, ready ? "B ROLL" : "ROLL", 214, 34, rc, 1)
        // boss bar
        if bossActive && bossHp > 0 {
            b.fillRect(58, 268, 204, 12, StarWing64.cBlack)
            let bw = max(0, min(200, bossHp * 200 / max(1, bossHpMax)))
            b.fillRect(60, 270, bw, 8, StarWing64.cRed)
            txt(b, "BOSS", 60, 258, StarWing64.cWhite, 1)
        }
        if bannerT > 0 && phase == .play {
            if (bannerT / 6) % 2 == 0 || bannerT < 90 {
                ctxt(b, bannerText, 88, bannerText == "WARNING" ? StarWing64.cRed : StarWing64.cWhite, 3)
            }
        }
    }

    private func drawOverlays(_ b: TrueColorBuffer) {
        if phase == .title {
            b.fillRect(28, 56, 264, 190, StarWing64.cBlack)
            b.fillRect(30, 58, 260, 186, StarWing64.cPanel)
            b.fillRect(30, 58, 260, 3, StarWing64.cYellow)
            ctxt(b, "STAR WING", 70, StarWing64.cYellow, 5)
            ctxt(b, "SIXTY FOUR", 108, StarWing64.cCyan, 3)
            ctxt(b, "D-PAD STEER   A FIRE", 150, StarWing64.cWhite, 1)
            ctxt(b, "B BARREL ROLL REFLECTS SHOTS", 164, StarWing64.cWhite, 1)
            ctxt(b, "FLY THROUGH GOLD GATES", 178, StarWing64.cYellow, 1)
            ctxt(b, "GREEN RINGS REPAIR SHIELD", 192, StarWing64.cGreen, 1)
            if (frameN / 30) % 2 == 0 { ctxt(b, "PRESS A", 214, StarWing64.cWhite, 2) }
        } else if phase == .over {
            b.fillRect(38, 58, 244, 186, StarWing64.cBlack)
            b.fillRect(40, 60, 240, 182, StarWing64.cPanel)
            b.fillRect(40, 60, 240, 3, victory ? StarWing64.cGreen : StarWing64.cRed)
            ctxt(b, victory ? "MISSION DONE" : "SHIP LOST", 72, victory ? StarWing64.cGreen : StarWing64.cRed, 4)
            ctxt(b, "SCORE " + zeroPad(scoreValue, 6), 112, StarWing64.cYellow, 2)
            let acc = shotsFired > 0 ? shotsHit * 100 / shotsFired : 0
            ctxt(b, "KILLS " + String(kills) + "  GATES " + String(gatesGot), 138, StarWing64.cWhite, 1)
            ctxt(b, "RINGS " + String(ringsGot) + "  ACCURACY " + String(acc) + "%", 154, StarWing64.cWhite, 1)
            ctxt(b, "WAVE REACHED " + String(min(stage + 1, 3)) + (stage >= 3 ? " BOSS" : ""), 170, StarWing64.cCyan, 1)
            if overT > 70 && (frameN / 30) % 2 == 0 { ctxt(b, "PRESS A", 202, StarWing64.cWhite, 2) }
        }
    }
}

extension Cartridge {
    static let starWing64 = Cartridge(
        id: "starwing64", title: "STAR WING 64", genre: "Shooter",
        blurb: "Fly an on-rails starfighter over a neon planet. Three waves, gold gates, repair rings and a giant boss, with a barrel roll that bounces enemy fire back.",
        controls: "D-PAD steer, A fire (hold), B barrel roll (reflects shots).",
        era: .n64, labelTop: 0x7A3CD8, labelBottom: 0x0E1A4A, factory: { StarWing64() })
}
