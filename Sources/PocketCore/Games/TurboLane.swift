import Foundation

/// Top-down vertical racer. Hold A to accelerate, B to brake, steer with the D-pad.
/// Reach checkpoints for extra time, grab fuel, dodge rivals, oil, cones and trees.
final class TurboLane: Game {
    private enum Mode { case title, ready, play, over }
    private enum Kind { case rivalA, rivalB, cone, oil, fuel, boost, tree }

    private struct Obj {
        var kind: Kind
        var wy: Float      // world position along the road (same units as `dist`)
        var off: Float     // lateral offset from the road centre
        var vr: Float      // own forward speed (rivals)
        var phase: Float
        var weave: Float
        var passed: Bool
        var dead: Bool
    }

    // Palette slots (identical meaning in every time-of-day palette):
    // 0 grass, 1 grass stripe, 2 asphalt, 3 outline, 4 kerb red, 5 kerb white, 6 lane paint, 7 player body,
    // 8 window, 9 rival A, 10 rival B, 11 cone, 12 oil, 13 oil shine, 14 fuel, 15 text, 16 HUD bg,
    // 17 bolt / gold, 18 red, 19 black, 20 spare, 21 dim text, 22 tree, 23 trunk, 24 headlight
    private static let dayPal = Palette.make([
        0x88C060, 0x98D070, 0x303440, 0x101018, 0xE03838, 0xF0F0F0, 0xE8E8E8, 0xFFE040,
        0x2040C0, 0x40C0F0, 0xF07030, 0xFF8020, 0x8078D0, 0xF0F0FF, 0x40F060, 0xF8F8F8,
        0x10141C, 0xFFD020, 0xFF4040, 0x080808, 0x000000, 0x90A0B8, 0x207030, 0x6A4020, 0x303440
    ])
    private static let duskPal = Palette.make([
        0xC89060, 0xD8A070, 0x3A2C48, 0x100C18, 0xE03838, 0xF0F0F0, 0xF0E0D0, 0xFFE040,
        0x2040C0, 0x40C0F0, 0xF07030, 0xFF8020, 0x8078D0, 0xF0F0FF, 0x40F060, 0xF8F8F8,
        0x10141C, 0xFFD020, 0xFF4040, 0x080808, 0x000000, 0x90A0B8, 0x50602C, 0x6A4020, 0x3A2C48
    ])
    private static let nightPal = Palette.make([
        0x143020, 0x1A3A28, 0x40485C, 0x101018, 0xFF5050, 0xF0F0F0, 0xD8D8E8, 0xFFE040,
        0x2040C0, 0x70E0FF, 0xFF9060, 0xFFA040, 0x8078D0, 0xF0F0FF, 0x40F060, 0xF8F8F8,
        0x10141C, 0xFFD020, 0xFF4040, 0x080808, 0x000000, 0x90A0B8, 0x2C6A3C, 0x7A5030, 0x8890B0
    ])
    private static let pals: [[UInt16]] = [TurboLane.dayPal, TurboLane.duskPal, TurboLane.nightPal, TurboLane.duskPal]

    private var phaseIdx = 0
    override var palette: [UInt16] { return TurboLane.pals[phaseIdx & 3] }

    // MARK: Sprites

    private static let carSprite = Sprite([
        "...3333...",
        "..377773..",
        ".37777773.",
        ".37888873.",
        ".37888873.",
        ".37777773.",
        "3377777733",
        "3377777733",
        ".37777773.",
        ".37777773.",
        ".37888873.",
        ".37888873.",
        ".37777773.",
        "3377777733",
        ".33333333.",
        "..333333.."
    ])
    private static let rivalASprite = TurboLane.carSprite.recolored(7, 9)
    private static let rivalBSprite = TurboLane.carSprite.recolored(7, 10)
    private static let coneSprite = Sprite([
        "...bb...",
        "...bb...",
        "..b55b..",
        "..bbbb..",
        ".bb55bb.",
        ".bbbbbb.",
        "33333333",
        "33333333"
    ])
    private static let oilSprite = Sprite([
        "....cccccc....",
        "..cccccccccc..",
        ".ccdcccccccccc",
        ".cddccccccccc.",
        ".ccccccccdccc.",
        "..cccccccccc..",
        "...cccccccc..."
    ])
    private static let fuelSprite = Sprite([
        "..3333..",
        ".3eeee3.",
        "3eeeeee3",
        "3e5555e3",
        "3ee5eee3",
        "3e555ee3",
        "3ee5eee3",
        "3eeeeee3",
        ".333333."
    ])
    private static let boostSprite = Sprite([
        "...hhh..",
        "..hhh...",
        ".hhh....",
        ".hhhhhh.",
        "...hhh..",
        "..hh....",
        "..h.....",
        "........"
    ])
    private static let treeSprite = Sprite([
        "...mmmm...",
        "..mmmmmm..",
        ".mmmmmmmm.",
        ".mmmmmmmm.",
        "..mmmmmm..",
        ".mmmmmmmm.",
        "mmmmmmmmmm",
        ".mmmmmmmm.",
        "....nn....",
        "....nn....",
        "....nn....",
        "...nnnn..."
    ])

    // MARK: State

    private var mode: Mode = .title
    private var frame = 0
    private var rng = Rng()

    private var dist: Float = 0
    private var speed: Float = 0
    private var px: Float = 80
    private var fuel: Float = 100
    private var timeFrames = 2400
    private var lives = 3
    private var scoreF: Float = 0
    private var bestScore = 0
    private var objs: [Obj] = []

    private var treeGap: Float = 40
    private var obstGap: Float = 120
    private var fuelGap: Float = 500
    private var boostGap: Float = 1300
    private var nextCheckpoint: Float = 2500
    private var checkpointsHit = 0

    private var boostTimer = 0
    private var skidTimer = 0
    private var skidDir: Float = 1
    private var recover = 0
    private var shake = 0
    private var msgTimer = 0
    private var msgText = ""
    private var overReason = ""
    private var overTimer = 0
    private var readyTimer = 0

    override var score: Int {
        let v = clamp(scoreF, 0, 99_999_999)
        return max(0, Int(v))
    }

    override func start() { playMusic(Tunes.race) }

    private func reset() {
        dist = 0
        speed = 0
        px = 80
        fuel = 100
        timeFrames = 2400
        lives = 3
        scoreF = 0
        objs = []
        treeGap = 30
        obstGap = 150
        fuelGap = 500
        boostGap = 1300
        nextCheckpoint = 2500
        checkpointsHit = 0
        boostTimer = 0
        skidTimer = 0
        recover = 0
        shake = 0
        msgTimer = 0
        msgText = ""
        phaseIdx = 0
        overTimer = 0
    }

    // MARK: Road geometry

    private func halfWidth(_ wy: Float) -> Float {
        let w = max(0, wy)
        return max(25, 40 - w / 1000)
    }

    private func centre(_ wy: Float) -> Float {
        let w = max(0, wy)
        let ramp: Float = min(1, w / 500)
        let amp: Float = min(1, 0.4 + w / 18000) * ramp
        let a: Float = 26 * sin(w * 0.0062)
        let b: Float = 14 * sin(w * 0.0145 + 1.3)
        let raw: Float = 80 + amp * (a + b)
        let hw = halfWidth(w)
        return clamp(raw, hw + 6, 154 - hw)
    }

    private func objX(_ o: Obj) -> Float {
        let base = centre(o.wy) + o.off
        let sway: Float = sin(o.wy * 0.03 + o.phase) * o.weave
        return base + sway
    }

    private func isHazard(_ k: Kind) -> Bool {
        switch k {
        case .fuel, .boost: return false
        default: return true
        }
    }

    // MARK: Spawning

    private func makeObj(_ kind: Kind, _ wy: Float, _ off: Float) -> Obj {
        return Obj(kind: kind, wy: wy, off: off, vr: 0, phase: Float(rng.int(628)) / 100, weave: 0, passed: false, dead: false)
    }

    private func spawnRival(_ wy: Float, _ lane: Int) {
        let hw = halfWidth(wy)
        let kind: Kind = rng.chance(50) ? .rivalA : .rivalB
        var o = makeObj(kind, wy, Float(lane) * hw * 0.5)
        o.vr = Float(rng.range(10, 24)) / 10
        if rng.chance(35) { o.weave = 5 }
        objs.append(o)
    }

    private func spawnObstacle() {
        let level = checkpointsHit
        let wy = dist + 140
        let hw = halfWidth(wy)
        let r = rng.int(100)
        let rivalLimit = min(60, 36 + level * 3)
        if r < rivalLimit {
            spawnRival(wy, rng.int(3) - 1)
        } else if r < rivalLimit + 20 {
            let count = rng.range(1, 3)
            let limit = max(4, hw - 10)
            let startOff: Float = Float(rng.range(-100, 100)) / 100 * limit
            for i in 0..<count {
                let off = clamp(startOff + Float(i) * 9, -limit, limit)
                objs.append(makeObj(.cone, wy, off))
            }
        } else if r < rivalLimit + 40 {
            let limit = max(4, hw - 12)
            let off = Float(rng.range(-100, 100)) / 100 * limit
            objs.append(makeObj(.oil, wy, off))
        } else {
            let l1 = rng.int(3) - 1
            var l2 = l1 + 1 + rng.int(2)
            if l2 > 1 { l2 -= 3 }
            spawnRival(wy, l1)
            spawnRival(wy + 4, l2)
        }
    }

    private func spawnTree() {
        let wy = dist + 140
        let hw = halfWidth(wy)
        let side: Float = rng.chance(50) ? 1 : -1
        let off = side * (hw + 14 + Float(rng.int(24)))
        objs.append(makeObj(.tree, wy, off))
    }

    private func spawnPickup(_ kind: Kind) {
        let wy = dist + 140
        let hw = halfWidth(wy)
        let limit = max(4, hw - 12)
        let off = Float(rng.range(-100, 100)) / 100 * limit
        objs.append(makeObj(kind, wy, off))
    }

    // MARK: Update

    override func update(_ input: InputState) {
        frame += 1
        switch mode {
        case .title:
            dist += 2
            if input.aPressed || input.startPressed {
                reset()
                mode = .ready
                readyTimer = 180
                play(.confirm)
            }
        case .ready:
            readyTimer -= 1
            if readyTimer == 120 || readyTimer == 60 || readyTimer == 180 { play(.countdown) }
            if readyTimer <= 0 {
                mode = .play
                play(.confirm)
            }
        case .play:
            updateDriving(input)
        case .over:
            overTimer += 1
            if overTimer > 40 && (input.aPressed || input.startPressed) {
                reset()
                mode = .ready
                readyTimer = 180
                play(.confirm)
            }
        }
    }

    private func endRun(_ reason: String) {
        overReason = reason
        mode = .over
        overTimer = 0
        speed = 0
        bestScore = max(bestScore, score)
        play(.lose)
    }

    private func crash() {
        if recover > 0 { return }
        lives -= 1
        speed = 0
        shake = 20
        boostTimer = 0
        skidTimer = 0
        play(.explosion)
        if lives <= 0 {
            endRun("CRASHED")
            return
        }
        recover = 120
        px = centre(dist)
        for i in 0..<objs.count {
            if abs(objs[i].wy - dist) < 80 && isHazard(objs[i].kind) { objs[i].dead = true }
        }
    }

    private func updateDriving(_ input: InputState) {
        let level = checkpointsHit
        timeFrames -= 1
        if recover > 0 { recover -= 1 }
        if shake > 0 { shake -= 1 }
        if msgTimer > 0 { msgTimer -= 1 }

        // Speed
        let cxHere = centre(dist)
        let hwHere = halfWidth(dist)
        let offRoad = abs(px - cxHere) > hwHere - 2
        var maxSp: Float = 3.6 + Float(min(level, 10)) * 0.12
        if boostTimer > 0 {
            maxSp += 1.8
            boostTimer -= 1
        }
        if offRoad { maxSp = min(maxSp, 1.8) }
        if input.a {
            speed += boostTimer > 0 ? 0.08 : 0.045
        } else {
            speed -= 0.012
        }
        if input.b { speed -= 0.14 }
        if speed > maxSp {
            speed -= offRoad ? 0.12 : 0.05
            if speed < maxSp { speed = maxSp }
        }
        speed = clamp(speed, 0, 7)

        // Steering and curve drift
        let steer: Float = 1.0 + min(speed, 4) * 0.3
        var dxv: Float = Float(input.dx) * steer
        if skidTimer > 0 {
            skidTimer -= 1
            dxv += skidDir * 1.4
        }
        px += dxv
        let slope: Float = (centre(dist + 16) - cxHere) / 16
        px -= slope * speed * 0.5
        px = clamp(px, 6, 154)
        if offRoad && speed > 1 && frame % 4 == 0 { play(.step) }

        // Advance
        dist += speed
        let boostMul: Float = boostTimer > 0 ? 2 : 1
        scoreF += speed * speed * 0.012 * boostMul
        fuel -= 0.008 + speed * 0.0035
        phaseIdx = (Int(clamp(dist, 0, 100_000_000) / 4000)) & 3

        // Objects
        for i in 0..<objs.count {
            objs[i].wy += objs[i].vr
            if !objs[i].passed && objs[i].wy < dist - 12 {
                objs[i].passed = true
                if objs[i].kind == .rivalA || objs[i].kind == .rivalB { scoreF += 25 }
            }
        }

        // Spawning is distance based
        treeGap -= speed
        if treeGap <= 0 {
            spawnTree()
            treeGap = Float(rng.range(40, 70))
        }
        obstGap -= speed
        if obstGap <= 0 {
            spawnObstacle()
            let base = max(45, 110 - level * 6)
            obstGap = Float(rng.range(base, base + 50))
        }
        fuelGap -= speed
        if fuelGap <= 0 {
            spawnPickup(.fuel)
            fuelGap = Float(rng.range(500, 800))
        }
        boostGap -= speed
        if boostGap <= 0 {
            spawnPickup(.boost)
            boostGap = Float(rng.range(1300, 1900))
        }

        // Collisions
        for i in 0..<objs.count {
            if mode != .play { break }
            if objs[i].dead { continue }
            let dyw = objs[i].wy - dist
            if abs(dyw) > 16 { continue }
            let dxw = abs(objX(objs[i]) - px)
            var halfW: Float = 5
            var halfH: Float = 6
            switch objs[i].kind {
            case .rivalA, .rivalB:
                halfW = 5
                halfH = 7
            case .cone:
                halfW = 3
                halfH = 4
            case .oil:
                halfW = 7
                halfH = 3
            case .fuel, .boost:
                halfW = 4
                halfH = 4
            case .tree:
                halfW = 5
                halfH = 6
            }
            if dxw < halfW + 4 && abs(dyw) < halfH + 6 {
                switch objs[i].kind {
                case .rivalA, .rivalB, .tree:
                    crash()
                case .cone:
                    objs[i].dead = true
                    speed *= 0.6
                    shake = 6
                    play(.thud)
                case .oil:
                    if skidTimer <= 0 && recover <= 0 {
                        skidTimer = 45
                        skidDir = rng.chance(50) ? 1 : -1
                        play(.hit)
                    }
                case .fuel:
                    objs[i].dead = true
                    fuel = min(100, fuel + 35)
                    scoreF += 50
                    play(.pickup)
                case .boost:
                    objs[i].dead = true
                    boostTimer = 240
                    scoreF += 50
                    play(.powerup)
                }
            }
        }
        if mode != .play { return }
        let d = dist
        objs = objs.filter { $0.wy > d - 60 && !$0.dead }

        // Checkpoints
        if dist >= nextCheckpoint {
            checkpointsHit += 1
            let bonus = max(12, 22 - checkpointsHit)
            timeFrames = min(99 * 60, timeFrames + bonus * 60)
            scoreF += 300
            msgText = "CHECKPOINT +" + String(bonus) + "S"
            msgTimer = 120
            nextCheckpoint += 2500 + Float(checkpointsHit) * 250
            play(.win)
        }

        // End conditions
        if timeFrames <= 0 {
            timeFrames = 0
            endRun("TIME UP")
        } else if fuel <= 0 {
            fuel = 0
            endRun("OUT OF FUEL")
        }
    }

    // MARK: Drawing

    private func drawRoad(_ c: Canvas) {
        for sy in 12..<144 {
            let wy: Float = dist + Float(120 - sy)
            let hw = halfWidth(wy)
            let cxf = centre(wy)
            let l = Int(cxf - hw)
            let r = Int(cxf + hw)
            let wInt = Int(clamp(wy, -10000, 100_000_000))
            let stripe = (wInt / 12) & 1
            c.fillRect(-4, sy, 168, 1, stripe == 0 ? 0 : 1)
            let kerb = ((wInt / 6) & 1) == 0 ? 4 : 5
            c.fillRect(l - 3, sy, 3, 1, kerb)
            c.fillRect(r, sy, 3, 1, kerb)
            c.fillRect(l, sy, r - l, 1, 2)
            if ((wInt / 14) & 1) == 0 {
                let mid = Int(cxf)
                let q = Int(hw * 0.5)
                c.fillRect(mid - 1, sy, 2, 1, 6)
                c.setPixel(mid - q, sy, 6)
                c.setPixel(mid + q, sy, 6)
            }
        }
    }

    private func drawCheckpointLine(_ c: Canvas) {
        let sy = 120 - Int(clamp(nextCheckpoint - dist, -500, 500))
        if sy < 14 || sy > 140 { return }
        let wy = nextCheckpoint
        let hw = halfWidth(wy)
        let cxf = centre(wy)
        let l = Int(cxf - hw)
        let r = Int(cxf + hw)
        var x = l
        var toggle = 0
        while x < r {
            let w = min(4, r - x)
            c.fillRect(x, sy, w, 2, toggle == 0 ? 5 : 3)
            c.fillRect(x, sy + 2, w, 2, toggle == 0 ? 3 : 5)
            x += 4
            toggle = 1 - toggle
        }
        c.fillRect(l - 4, sy - 12, 3, 16, 17)
        c.fillRect(r + 2, sy - 12, 3, 16, 17)
        c.fillRect(l - 4, sy - 12, r - l + 10, 8, 17)
        let tx = Int(cxf) - c.textWidth("CHECKPOINT") / 2
        c.text("CHECKPOINT", tx, sy - 10, 19)
    }

    private func drawObjects(_ c: Canvas) {
        for o in objs {
            if o.dead { continue }
            let cy = 120 - Int(clamp(o.wy - dist, -500, 500))
            if cy < 4 || cy > 156 { continue }
            let x = Int(objX(o))
            switch o.kind {
            case .rivalA: c.draw(TurboLane.rivalASprite, x - 5, cy - 8)
            case .rivalB: c.draw(TurboLane.rivalBSprite, x - 5, cy - 8)
            case .cone: c.draw(TurboLane.coneSprite, x - 4, cy - 4)
            case .oil: c.draw(TurboLane.oilSprite, x - 7, cy - 3)
            case .fuel: c.draw(TurboLane.fuelSprite, x - 4, cy - 4)
            case .boost: c.draw(TurboLane.boostSprite, x - 4, cy - 4)
            case .tree: c.draw(TurboLane.treeSprite, x - 5, cy - 6)
            }
        }
    }

    private func drawPlayer(_ c: Canvas) {
        let x = Int(px)
        if recover > 0 && (recover / 4) % 2 == 0 { return }
        if headlightsOn() {
            for i in 0..<22 {
                let half = 3 + i / 2
                c.fillChecker(x - half, 111 - i, half * 2, 1, 2, 24)
            }
        }
        var wob = 0
        if skidTimer > 0 { wob = (skidTimer / 3) % 2 == 0 ? 1 : -1 }
        c.draw(TurboLane.carSprite, x - 5 + wob, 112)
        if boostTimer > 0 {
            let h = 3 + (frame % 3)
            c.fillRect(x - 3, 128, 2, h, 17)
            c.fillRect(x + 1, 128, 2, h, 17)
            c.fillRect(x - 3, 128, 2, 1, 18)
            c.fillRect(x + 1, 128, 2, 1, 18)
        }
    }

    private func headlightsOn() -> Bool { return phaseIdx == 2 }

    private func drawHUD(_ c: Canvas) {
        c.cameraX = 0
        c.cameraY = 0
        c.fillRect(0, 0, 160, 12, 16)
        c.hline(0, 11, 160, 21)
        c.text("SCORE " + zeroPad(score, 6), 2, 3, 15)
        let secs = (timeFrames + 59) / 60
        let low = secs <= 10 && (frame / 15) % 2 == 0
        c.text("TIME " + String(max(0, secs)), 54, 3, low ? 18 : 15)
        c.text("F", 88, 3, 21)
        c.strokeRect(94, 2, 32, 7, 21)
        let fw = Int(clamp(fuel, 0, 100) * 0.3)
        let fuelLow = fuel < 25 && (frame / 10) % 2 == 0
        c.fillRect(95, 3, fw, 5, fuelLow ? 18 : 14)
        for i in 0..<max(0, min(3, lives)) {
            let x = 131 + i * 9
            c.fillRect(x, 2, 6, 8, 7)
            c.fillRect(x + 1, 4, 4, 2, 8)
        }
        let kmh = Int(clamp(speed, 0, 9) * 30)
        c.outlinedText(String(kmh) + " KM/H", 3, 135, 15, outline: 19)
        if boostTimer > 0 { c.outlinedText("TURBO!", 62, 135, 17, outline: 19) }
        if msgTimer > 0 {
            let mx = (160 - c.textWidth(msgText)) / 2
            c.outlinedText(msgText, mx, 28, 17, outline: 19)
        }
    }

    private func bigText(_ c: Canvas, _ s: String, _ y: Int, _ col: Int) {
        let x = (160 - c.textWidth(s, scale: 2)) / 2
        c.text(s, x - 1, y, 19, scale: 2)
        c.text(s, x + 1, y, 19, scale: 2)
        c.text(s, x, y - 1, 19, scale: 2)
        c.text(s, x, y + 1, 19, scale: 2)
        c.text(s, x, y, col, scale: 2)
    }

    override func draw(_ c: Canvas) {
        c.clear(0)
        c.cameraX = 0
        c.cameraY = 0
        if shake > 0 && mode == .play {
            c.cameraX = (shake % 2 == 0) ? 2 : -2
        }
        drawRoad(c)
        if mode != .title { drawCheckpointLine(c) }
        if mode == .title {
            let cx = Int(centre(dist))
            c.draw(TurboLane.carSprite, cx - 5, 112)
        } else {
            drawObjects(c)
            drawPlayer(c)
        }
        c.cameraX = 0
        c.cameraY = 0
        switch mode {
        case .title:
            c.fillRect(0, 0, 160, 12, 16)
            bigText(c, "TURBO", 22, 17)
            bigText(c, "LANE", 40, 15)
            if (frame / 30) % 2 == 0 { c.outlinedText("PRESS A TO RACE", 38, 88, 15, outline: 19) }
            c.outlinedText("A GAS  B BRAKE", 40, 100, 21, outline: 19)
            if bestScore > 0 { c.outlinedText("BEST " + zeroPad(bestScore, 6), 52, 4, 17, outline: 16) }
        case .ready:
            drawHUD(c)
            let n = (readyTimer + 59) / 60
            let label = n <= 0 ? "GO!" : String(n)
            bigText(c, label, 50, 17)
        case .play:
            drawHUD(c)
        case .over:
            drawHUD(c)
            c.fillRect(22, 34, 116, 70, 16)
            c.strokeRect(22, 34, 116, 70, 21)
            c.strokeRect(24, 36, 112, 66, 3)
            c.textCentered("GAME OVER", y: 41, 18, scale: 2)
            c.textCentered(overReason, y: 56, 17)
            c.textCentered("SCORE " + String(score), y: 66, 15)
            c.textCentered("BEST " + String(bestScore), y: 74, 21)
            c.textCentered("DIST " + String(Int(clamp(dist, 0, 100_000_000)) / 10) + " M", y: 82, 21)
            if overTimer > 40 && (frame / 25) % 2 == 0 { c.textCentered("A: RETRY", y: 92, 15) }
        }
    }
}

extension Cartridge {
    static let turboLane = Cartridge(
        id: "turbolane", title: "TURBO LANE", genre: "Racing",
        blurb: "Race a winding road from dusk till dawn. Dodge rivals, oil and cones, grab fuel and boosts, and beat the clock at every checkpoint.",
        controls: "LEFT / RIGHT steer, A gas, B brake.",
        era: .gbc, labelTop: 0xF0B030, labelBottom: 0x783018, factory: { TurboLane() })
}
