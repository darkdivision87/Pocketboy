import Foundation

/// Asteroids-style vector shooter: rotate, thrust, fire, wrap, split rocks, dodge UFOs, hyperspace.
final class RockBlaster: Game {
    private enum Phase { case title, play, over }

    private struct Rock {
        var x: Float
        var y: Float
        var vx: Float
        var vy: Float
        var size: Int      // 0 small, 1 medium, 2 large
        var shape: Int     // 0...2
        var angle: Float
        var spin: Float
    }

    private struct Shot {
        var x: Float
        var y: Float
        var vx: Float
        var vy: Float
        var life: Int
    }

    private struct Debris {
        var x: Float
        var y: Float
        var vx: Float
        var vy: Float
        var angle: Float
        var life: Int
        var color: Int
    }

    // Palette: 0 bg, 1 white, 2 ship, 3 big rock, 4 small rock, 5 flame, 6 ufo, 7 unused, 8 ufo shot, 9 dim hud, 10 stars
    private static let pal = Palette.make([
        0x080810, 0xF8F8F8, 0xA8F0F8, 0xB8C0D8, 0xE8C860, 0xF89030, 0xF86868,
        0x000000, 0xF8F080, 0x6878A0, 0x303858
    ])
    override var palette: [UInt16] { return RockBlaster.pal }

    // Ship outline (nose up), closed polygon.
    private static let shipPts: [Float] = [0, -6, -4, 5, 0, 3, 4, 5]
    private static let flamePts: [Float] = [-2, 4, 0, 9, 2, 4]
    private static let ufoHull: [Float] = [-9, 1, -5, 4, 5, 4, 9, 1, 5, -2, -5, -2]
    private static let ufoDome: [Float] = [-3, -2, -2, -5, 2, -5, 3, -2]
    private static let ufoBelt: [Float] = [-9, 1, 9, 1]
    private static let rockRadius: [Float] = [4, 7, 12]

    // Three unit-ish rock outlines of 10 vertices each.
    private static let rockBase: [[Float]] = {
        let mults: [[Float]] = [
            [1.0, 0.8, 1.1, 0.9, 1.0, 0.75, 1.05, 0.85, 1.1, 0.9],
            [0.9, 1.1, 0.8, 1.0, 1.1, 0.85, 0.95, 1.1, 0.75, 1.0],
            [1.1, 0.9, 1.0, 0.75, 0.95, 1.1, 0.85, 1.0, 1.1, 0.8]
        ]
        var out: [[Float]] = []
        for v in 0..<3 {
            var pts: [Float] = []
            for k in 0..<10 {
                let a = Float(k) * 2 * Float.pi / 10
                let m = mults[v][k]
                pts.append(sin(a) * m)
                pts.append(-cos(a) * m)
            }
            out.append(pts)
        }
        return out
    }()

    private var phase: Phase = .title
    private var tick = 0
    private var rng = Rng()
    private var points = 0
    private var lives = 3
    private var wave = 1
    private var nextLifeAt = 5000
    private var paused = false
    private var overTimer = 0

    private var shipX: Float = 80
    private var shipY: Float = 72
    private var shipVX: Float = 0
    private var shipVY: Float = 0
    private var shipA: Float = 0
    private var shipAlive = false
    private var thrusting = false
    private var invul = 0
    private var respawnTimer = 0
    private var fireCooldown = 0
    private var hyperCooldown = 0

    private var rocks: [Rock] = []
    private var shots: [Shot] = []
    private var ufoShots: [Shot] = []
    private var debris: [Debris] = []
    private var waveTimer = 0

    private var ufoOn = false
    private var ufoX: Float = 0
    private var ufoY: Float = 40
    private var ufoVX: Float = 0.6
    private var ufoVY: Float = 0
    private var ufoSmall = false
    private var ufoFire = 60
    private var ufoJog = 30
    private var ufoTimer = 700

    override var score: Int { return points }

    override func start() { playMusic(Tunes.tense) }

    // MARK: Helpers

    private func wrap(_ v: Float, _ m: Float) -> Float {
        var r = v
        if r < 0 { r += m }
        if r >= m { r -= m }
        if r < 0 { r = 0 }
        if r >= m { r = m - 0.01 }
        return r
    }

    private func wrapDelta(_ a: Float, _ b: Float, _ m: Float) -> Float {
        var d = a - b
        if d > m / 2 { d -= m } else if d < -m / 2 { d += m }
        return d
    }

    private func dist2(_ ax: Float, _ ay: Float, _ bx: Float, _ by: Float) -> Float {
        let dx = wrapDelta(ax, bx, 160)
        let dy = wrapDelta(ay, by, 144)
        return dx * dx + dy * dy
    }

    private func rotatedPoints(_ base: [Float], _ scale: Float, _ angle: Float) -> [Int] {
        let s = sin(angle)
        let co = cos(angle)
        var out: [Int] = []
        var i = 0
        while i + 1 < base.count {
            let px = base[i] * scale
            let py = base[i + 1] * scale
            let rx = px * co - py * s
            let ry = px * s + py * co
            out.append(Int(rx.rounded()))
            out.append(Int(ry.rounded()))
            i += 2
        }
        return out
    }

    private func strokePoly(_ c: Canvas, _ pts: [Int], _ cx: Int, _ cy: Int, _ reach: Int, _ closed: Bool, _ col: Int) {
        let n = pts.count / 2
        if n < 2 { return }
        let offsX: [Int] = [-160, 0, 160]
        let offsY: [Int] = [-144, 0, 144]
        for ox in offsX {
            for oy in offsY {
                let px = cx + ox
                let py = cy + oy
                if px + reach < 0 || px - reach >= 160 || py + reach < 0 || py - reach >= 144 { continue }
                var i = 0
                while i < n - 1 {
                    c.line(px + pts[i * 2], py + pts[i * 2 + 1], px + pts[i * 2 + 2], py + pts[i * 2 + 3], col)
                    i += 1
                }
                if closed {
                    c.line(px + pts[(n - 1) * 2], py + pts[(n - 1) * 2 + 1], px + pts[0], py + pts[1], col)
                }
            }
        }
    }

    // MARK: Setup

    private func newGame() {
        points = 0
        lives = 3
        wave = 1
        nextLifeAt = 5000
        paused = false
        shots = []
        ufoShots = []
        debris = []
        ufoOn = false
        shipAlive = false
        respawnTimer = 1
        spawnShip()
        spawnWave()
        phase = .play
    }

    private func spawnShip() {
        shipX = 80
        shipY = 72
        shipVX = 0
        shipVY = 0
        shipA = 0
        shipAlive = true
        invul = 120
        fireCooldown = 0
    }

    private func makeRock(_ size: Int, avoidShip: Bool) -> Rock {
        var x: Float = 0
        var y: Float = 0
        var tries = 0
        while tries < 10 {
            let side = rng.int(4)
            if side == 0 { x = 0; y = Float(rng.int(144)) }
            else if side == 1 { x = 159; y = Float(rng.int(144)) }
            else if side == 2 { x = Float(rng.int(160)); y = 0 }
            else { x = Float(rng.int(160)); y = 143 }
            if !avoidShip || !shipAlive || dist2(x, y, shipX, shipY) > 40 * 40 { break }
            tries += 1
        }
        let ang = Float(rng.int(628)) / 100
        var sp = Float(rng.range(30, 70)) / 100 * (1 + Float(wave) * 0.08)
        sp = min(sp, 1.4)
        let spin = Float(rng.range(-30, 30)) / 1000
        return Rock(x: x, y: y, vx: sin(ang) * sp, vy: -cos(ang) * sp,
                    size: clamp(size, 0, 2), shape: rng.int(3), angle: Float(rng.int(628)) / 100, spin: spin)
    }

    private func spawnWave() {
        rocks = []
        let n = min(8, 3 + wave)
        for _ in 0..<n { rocks.append(makeRock(2, avoidShip: true)) }
        ufoOn = false
        ufoShots = []
        ufoTimer = rng.range(500, 900)
        waveTimer = 0
    }

    // MARK: Update

    override func update(_ input: InputState) {
        tick += 1
        switch phase {
        case .title:
            moveRocks()
            if rocks.isEmpty {
                for _ in 0..<5 { rocks.append(makeRock(rng.range(1, 2), avoidShip: false)) }
            }
            if input.aPressed || input.startPressed {
                play(.confirm)
                newGame()
            }
        case .play:
            if input.startPressed {
                paused = !paused
                play(.pause)
            }
            if !paused { updatePlay(input) }
        case .over:
            moveRocks()
            updateDebris()
            if overTimer > 0 { overTimer -= 1 }
            if overTimer <= 0 && (input.aPressed || input.startPressed) {
                play(.confirm)
                newGame()
            }
        }
    }

    private func moveRocks() {
        for i in 0..<rocks.count {
            rocks[i].x = wrap(rocks[i].x + rocks[i].vx, 160)
            rocks[i].y = wrap(rocks[i].y + rocks[i].vy, 144)
            rocks[i].angle += rocks[i].spin
        }
    }

    private func updatePlay(_ input: InputState) {
        moveRocks()
        updateShots()
        updateUfo()
        updateDebris()
        if shipAlive {
            updateShip(input)
        } else {
            respawnTimer -= 1
            if respawnTimer <= 0 {
                if lives <= 0 {
                    phase = .over
                    overTimer = 60
                    play(.lose)
                } else {
                    var clear = true
                    for r in rocks where dist2(80, 72, r.x, r.y) < 30 * 30 { clear = false }
                    if ufoOn && dist2(80, 72, ufoX, ufoY) < 40 * 40 { clear = false }
                    if clear { spawnShip() } else { respawnTimer = 5 }
                }
            }
        }
        collideShots()
        if shipAlive { collideShip() }

        if rocks.isEmpty && phase == .play {
            waveTimer += 1
            if waveTimer > 80 {
                wave += 1
                spawnWave()
                play(.win)
            }
        }
        if points >= nextLifeAt {
            nextLifeAt += 5000
            lives = min(6, lives + 1)
            play(.powerup)
        }
    }

    private func updateShip(_ input: InputState) {
        shipA += Float(input.dx) * 0.075
        thrusting = input.a
        if thrusting {
            shipVX += sin(shipA) * 0.07
            shipVY -= cos(shipA) * 0.07
            if tick % 6 == 0 { play(.step) }
        }
        shipVX *= 0.995
        shipVY *= 0.995
        let sp = sqrt(shipVX * shipVX + shipVY * shipVY)
        if sp > 3.0 {
            shipVX = shipVX / sp * 3.0
            shipVY = shipVY / sp * 3.0
        }
        shipX = wrap(shipX + shipVX, 160)
        shipY = wrap(shipY + shipVY, 144)
        if invul > 0 { invul -= 1 }
        if fireCooldown > 0 { fireCooldown -= 1 }
        if hyperCooldown > 0 { hyperCooldown -= 1 }

        if input.b && fireCooldown <= 0 && shots.count < 4 {
            fireCooldown = 9
            let hx = sin(shipA)
            let hy = -cos(shipA)
            shots.append(Shot(x: shipX + hx * 6, y: shipY + hy * 6,
                              vx: hx * 3.6 + shipVX * 0.4, vy: hy * 3.6 + shipVY * 0.4, life: 44))
            play(.shoot)
        }

        if (input.selectPressed || input.upPressed) && hyperCooldown <= 0 {
            hyperCooldown = 40
            shipX = Float(rng.range(10, 149))
            shipY = Float(rng.range(14, 133))
            shipVX = 0
            shipVY = 0
            invul = 15
            if rng.chance(12) {
                killShip()
            } else {
                play(.jump)
            }
        }
    }

    private func killShip() {
        shipAlive = false
        thrusting = false
        lives -= 1
        respawnTimer = 110
        play(.explosion)
        spawnDebris(shipX, shipY, 9, 2, 40)
    }

    private func spawnDebris(_ x: Float, _ y: Float, _ count: Int, _ color: Int, _ life: Int) {
        if debris.count > 60 { return }
        for _ in 0..<count {
            let a = Float(rng.int(628)) / 100
            let s = Float(rng.range(20, 100)) / 100
            debris.append(Debris(x: x, y: y, vx: sin(a) * s, vy: -cos(a) * s,
                                 angle: Float(rng.int(628)) / 100, life: life - rng.int(12), color: color))
        }
    }

    private func updateDebris() {
        if debris.isEmpty { return }
        var keep: [Debris] = []
        for var d in debris {
            d.x = wrap(d.x + d.vx, 160)
            d.y = wrap(d.y + d.vy, 144)
            d.life -= 1
            if d.life > 0 { keep.append(d) }
        }
        debris = keep
    }

    private func updateShots() {
        var keep: [Shot] = []
        for var s in shots {
            s.x = wrap(s.x + s.vx, 160)
            s.y = wrap(s.y + s.vy, 144)
            s.life -= 1
            if s.life > 0 { keep.append(s) }
        }
        shots = keep
        var keepU: [Shot] = []
        for var s in ufoShots {
            s.x = wrap(s.x + s.vx, 160)
            s.y = wrap(s.y + s.vy, 144)
            s.life -= 1
            if s.life > 0 { keepU.append(s) }
        }
        ufoShots = keepU
    }

    private func updateUfo() {
        if !ufoOn {
            if rocks.isEmpty { return }
            ufoTimer -= 1
            if ufoTimer <= 0 {
                ufoOn = true
                ufoSmall = (wave >= 3 && rng.chance(50)) || (wave >= 2 && rng.chance(20))
                let fromLeft = rng.chance(50)
                ufoX = fromLeft ? -10 : 170
                let dirSign: Float = fromLeft ? 1 : -1
                let spd: Float = ufoSmall ? 0.85 : 0.6
                ufoVX = dirSign * spd
                ufoY = Float(rng.range(24, 120))
                ufoVY = 0
                ufoFire = 50
                ufoJog = 30
                ufoTimer = rng.range(800, 1500)
            }
            return
        }
        ufoX += ufoVX
        ufoY += ufoVY
        ufoY = clamp(ufoY, 18, 132)
        ufoJog -= 1
        if ufoJog <= 0 {
            ufoJog = rng.range(25, 60)
            let pick = rng.int(3)
            if pick == 0 { ufoVY = -0.5 } else if pick == 1 { ufoVY = 0 } else { ufoVY = 0.5 }
        }
        if tick % 16 == 0 {
            if ufoSmall { play(.blip) } else { play(.select) }
        }
        if ufoX < -14 || ufoX > 174 {
            ufoOn = false
            return
        }
        ufoFire -= 1
        if ufoFire <= 0 {
            ufoFire = rng.range(50, 100)
            var ang = Float(rng.int(628)) / 100
            if ufoSmall && shipAlive {
                let dx = wrapDelta(shipX, ufoX, 160)
                let dy = wrapDelta(shipY, ufoY, 144)
                ang = atan2(dx, -dy)
                let err = max(0.05, 0.3 - Float(wave) * 0.03)
                ang += Float(rng.range(-100, 100)) / 100 * err
            }
            ufoShots.append(Shot(x: ufoX, y: ufoY, vx: sin(ang) * 1.5, vy: -cos(ang) * 1.5, life: 90))
            play(.laser)
        }
    }

    private func splitRock(_ rock: Rock, _ out: inout [Rock]) {
        let values: [Int] = [100, 50, 20]
        let sz = clamp(rock.size, 0, 2)
        points += values[sz]
        if sz == 2 { play(.explosion) } else { play(.hit) }
        spawnDebris(rock.x, rock.y, sz + 2, sz == 0 ? 4 : 3, 18)
        if sz > 0 && rocks.count + out.count < 34 {
            for _ in 0..<2 {
                let ang = Float(rng.int(628)) / 100
                var sp = Float(rng.range(50, 90)) / 100 * (sz == 2 ? 1.0 : 1.5) * (1 + Float(wave) * 0.05)
                sp = min(sp, 2.2)
                out.append(Rock(x: rock.x, y: rock.y,
                                vx: rock.vx * 0.4 + sin(ang) * sp, vy: rock.vy * 0.4 - cos(ang) * sp,
                                size: sz - 1, shape: rng.int(3), angle: rock.angle,
                                spin: Float(rng.range(-40, 40)) / 1000))
            }
        }
    }

    private func collideShots() {
        if shots.isEmpty { return }
        var dead = [Bool](repeating: false, count: shots.count)
        var kept: [Rock] = []
        var born: [Rock] = []
        for rock in rocks {
            let r = RockBlaster.rockRadius[clamp(rock.size, 0, 2)] + 2
            var hit = false
            for i in 0..<shots.count {
                if dead[i] { continue }
                if dist2(shots[i].x, shots[i].y, rock.x, rock.y) <= r * r {
                    dead[i] = true
                    hit = true
                    break
                }
            }
            if hit { splitRock(rock, &born) } else { kept.append(rock) }
        }
        rocks = kept + born
        if ufoOn {
            let scale: Float = ufoSmall ? 0.6 : 1.0
            let r = 8 * scale + 2
            for i in 0..<shots.count {
                if dead[i] { continue }
                if dist2(shots[i].x, shots[i].y, ufoX, ufoY) <= r * r {
                    dead[i] = true
                    ufoOn = false
                    points += ufoSmall ? 1000 : 200
                    spawnDebris(ufoX, ufoY, 8, 6, 30)
                    play(.explosion)
                    break
                }
            }
        }
        var keep: [Shot] = []
        for i in 0..<shots.count where !dead[i] { keep.append(shots[i]) }
        shots = keep
    }

    private func collideShip() {
        if invul > 0 { return }
        for r in rocks {
            let rad = RockBlaster.rockRadius[clamp(r.size, 0, 2)] * 0.8 + 3
            if dist2(shipX, shipY, r.x, r.y) < rad * rad {
                killShip()
                return
            }
        }
        if ufoOn {
            let scale: Float = ufoSmall ? 0.6 : 1.0
            let rad = 8 * scale + 3
            if dist2(shipX, shipY, ufoX, ufoY) < rad * rad {
                ufoOn = false
                spawnDebris(ufoX, ufoY, 8, 6, 30)
                killShip()
                return
            }
        }
        for s in ufoShots where dist2(shipX, shipY, s.x, s.y) < 16 {
            killShip()
            return
        }
    }

    // MARK: Draw

    private func centered(_ c: Canvas, _ s: String, _ y: Int, _ col: Int) {
        let w = c.textWidth(s)
        c.text(s, (160 - w) / 2, y, col)
    }

    override func draw(_ c: Canvas) {
        c.clear(0)
        for i in 0..<20 {
            let sx = (i * 41 + 7) % 160
            let sy = (i * 59 + 13) % 144
            c.setPixel(sx, sy, 10)
        }

        for r in rocks {
            let sz = clamp(r.size, 0, 2)
            let rad = RockBlaster.rockRadius[sz]
            let pts = rotatedPoints(RockBlaster.rockBase[clamp(r.shape, 0, 2)], rad, r.angle)
            strokePoly(c, pts, Int(r.x), Int(r.y), Int(rad) + 2, true, sz == 0 ? 4 : 3)
        }

        if phase == .title {
            drawTitle(c)
            return
        }

        if shipAlive && (invul <= 0 || (invul / 4) % 2 == 0) {
            let pts = rotatedPoints(RockBlaster.shipPts, 1.0, shipA)
            strokePoly(c, pts, Int(shipX), Int(shipY), 10, true, 2)
            if thrusting && (tick / 2) % 2 == 0 {
                let fp = rotatedPoints(RockBlaster.flamePts, 1.0, shipA)
                strokePoly(c, fp, Int(shipX), Int(shipY), 10, false, 5)
            }
        }

        if ufoOn { drawUfo(c) }

        for s in shots {
            c.fillRect(Int(s.x), Int(s.y), 2, 2, 1)
        }
        for s in ufoShots {
            c.fillRect(Int(s.x), Int(s.y), 2, 2, 8)
        }
        for d in debris {
            let x0 = Int(d.x)
            let y0 = Int(d.y)
            let x1 = x0 + Int((sin(d.angle) * 3).rounded())
            let y1 = y0 + Int((cos(d.angle) * 3).rounded())
            c.line(x0, y0, x1, y1, d.color)
        }

        // HUD
        c.text("SCORE " + zeroPad(points, 5), 2, 2, 1)
        c.text("WAVE " + String(wave), 124, 2, 9)
        let shown = max(0, min(lives, 6))
        if shown > 0 {
            let mini = rotatedPoints(RockBlaster.shipPts, 0.7, 0)
            for i in 0..<shown {
                strokePoly(c, mini, 6 + i * 8, 15, 6, true, 2)
            }
        }

        if phase == .over {
            c.fillRect(30, 52, 100, 40, 0)
            c.strokeRect(30, 52, 100, 40, 9)
            centered(c, "GAME OVER", 58, 6)
            centered(c, "SCORE " + zeroPad(points, 5), 70, 1)
            if (tick / 25) % 2 == 0 && overTimer <= 0 { centered(c, "PRESS A", 80, 2) }
        } else if paused {
            centered(c, "PAUSED", 68, 1)
        }
        if rocks.isEmpty && phase == .play {
            centered(c, "WAVE CLEARED", 68, 4)
        }
    }

    private func drawUfo(_ c: Canvas) {
        let scale: Float = ufoSmall ? 0.6 : 1.0
        let cx = Int(ufoX)
        let cy = Int(ufoY)
        let hull = rotatedPoints(RockBlaster.ufoHull, scale, 0)
        let dome = rotatedPoints(RockBlaster.ufoDome, scale, 0)
        let belt = rotatedPoints(RockBlaster.ufoBelt, scale, 0)
        strokePoly(c, hull, cx, cy, 12, true, 6)
        strokePoly(c, dome, cx, cy, 12, false, 6)
        strokePoly(c, belt, cx, cy, 12, false, 6)
    }

    private func drawTitle(_ c: Canvas) {
        c.fillRect(18, 24, 124, 62, 0)
        c.strokeRect(18, 24, 124, 62, 9)
        c.textCentered("ROCK", y: 30, 4, scale: 3)
        c.textCentered("BLASTER", y: 50, 2, scale: 3)
        let pts = rotatedPoints(RockBlaster.shipPts, 1.4, Float(tick) * 0.04)
        strokePoly(c, pts, 80, 106, 12, true, 2)
        if (tick / 25) % 2 == 0 { centered(c, "PRESS A TO START", 124, 1) }
        centered(c, "A THRUST  B FIRE", 134, 9)
    }
}

extension Cartridge {
    static let rockBlaster = Cartridge(
        id: "rockblaster", title: "ROCK BLASTER", genre: "Shooter",
        blurb: "Pilot a drifting ship through an asteroid field, splitting rocks and dodging saucers. Hyperspace is a gamble.",
        controls: "LEFT / RIGHT rotate, A thrust, B fire, SELECT or UP hyperspace, START pauses.",
        era: .gb, labelTop: 0x7A88C8, labelBottom: 0x0C1028, factory: { RockBlaster() })
}
