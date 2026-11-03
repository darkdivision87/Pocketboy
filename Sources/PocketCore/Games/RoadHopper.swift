#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// Frogger-style crossing: dodge traffic, ride logs and turtles, fill all five bays.
final class RoadHopper: Game {
    // MARK: Palette
    private static let pal = Palette.make([
        0x202028, // 0 road (darkest)
        0x2058A8, // 1 river
        0x3A78C8, // 2 river highlight
        0x206838, // 3 grass
        0x388850, // 4 grass tuft
        0x185028, // 5 hedge (darkest)
        0xB8F048, // 6 frog (lightest)
        0x103818, // 7 frog outline (darkest)
        0xF8F8F8, // 8 white
        0xC08848, // 9 log (light)
        0x805828, // 10 log dark
        0x58B868, // 11 turtle shell (light)
        0x286838, // 12 turtle dark
        0xE88830, // 13 orange (light)
        0xE04040, // 14 red (dark)
        0x58C0E8, // 15 cyan (light)
        0xA8A8B8, // 16 grey (light)
        0x101018, // 17 black
        0x606068, // 18 mid grey
        0xFFF8C0, // 19 headlight
        0xF8D030  // 20 gold
    ])
    override var palette: [UInt16] { return RoadHopper.pal }

    // MARK: Sprites
    private static let frogUp = Sprite([
        ".87..78.",
        "76666667",
        ".666666.",
        ".666666.",
        "76666667",
        "77666677",
        "7.7..7.7",
        "77....77"
    ])
    private static let frogUpHop = Sprite([
        ".87..78.",
        "76666667",
        ".666666.",
        ".666666.",
        "76666667",
        "76666667",
        "7.6666.7",
        "7......7"
    ])

    private static func rotCW(_ s: Sprite) -> Sprite {
        let w = s.width
        let h = s.height
        var d = [UInt8](repeating: Sprite.clear, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                d[x * h + (h - 1 - y)] = s.data[y * w + x]
            }
        }
        return Sprite(width: h, height: w, data: d)
    }

    private static func rotations(_ base: Sprite) -> [Sprite] {
        var out: [Sprite] = []
        var s = base
        for _ in 0..<4 {
            out.append(s)
            s = RoadHopper.rotCW(s)
        }
        return out
    }

    private static let frogIdle: [Sprite] = RoadHopper.rotations(RoadHopper.frogUp)
    private static let frogHop: [Sprite] = RoadHopper.rotations(RoadHopper.frogUpHop)

    private static let carBase = Sprite([
        "...dddddd...",
        "..dhhdhhhd..",
        "jdddddddddd.",
        "dddddddddddd",
        "dddddddddddd",
        "jdddddddddd.",
        ".ii......ii.",
        "............"
    ])
    private static let carSprites: [Sprite] = [
        RoadHopper.carBase,
        RoadHopper.carBase.recolored(13, 14),
        RoadHopper.carBase.recolored(13, 15)
    ]

    private static func makeTruck() -> Sprite {
        let g16 = String(repeating: "g", count: 16)
        let e16 = String(repeating: "i", count: 16)
        var rows: [String] = []
        rows.append(".eeee..." + g16)
        rows.append("ehhhhe.." + g16)
        rows.append("eeeeeee." + g16)
        rows.append("jeeeeeee" + g16)
        rows.append("eeeeeeee" + g16)
        rows.append("eeeeeeee" + e16)
        rows.append(".ii..ii." + "..ii..........ii")
        rows.append(String(repeating: ".", count: 24))
        return Sprite(rows)
    }
    private static let truckBase: Sprite = RoadHopper.makeTruck()
    private static let truckSprites: [Sprite] = [
        RoadHopper.truckBase,
        RoadHopper.truckBase.recolored(14, 13)
    ]

    private static let turtleSprite = Sprite([
        "..cccc..",
        ".cbbbbc.",
        "cbcbbcbc",
        "cbbccbbc",
        "cbcbbcbc",
        ".cbbbbc.",
        "..cccc..",
        "........"
    ])
    private static let flySprite = Sprite([
        "8.h.8",
        ".8h8.",
        "..h..",
        "..k.."
    ])

    // MARK: Types
    private enum Mode { case title, playing, paused, dying, clear, over }

    private struct Lane {
        var kind: Int       // 0 none, 1 car, 2 truck, 3 log, 4 turtles
        var variant: Int    // colour variant, or turtle count
        var speed: Float
        var w: Float
        var period: Float
        var count: Int
        var total: Float
        var phase: Float
    }

    // MARK: State
    private var mode: Mode = .title
    private var lanes: [Lane] = []
    private var frogX: Float = 76
    private var row = 15
    private var fromX: Float = 76
    private var fromRow = 15
    private var face = 0
    private var hopAnim = 0
    private var bestRow = 15
    private var filled: [Bool] = [false, false, false, false, false]
    private var filledCount = 0
    private var flyBay = -1
    private var flyTimer = 0
    private var flyCooldown = 200
    private var lives = 3
    private var level = 1
    private var points = 0
    private var best = 0
    private var nextLifeAt = 2000
    private var timeLeft = 1800
    private var timeMax = 1800
    private var deathKind = 0
    private var deathTimer = 0
    private var bannerTimer = 0
    private var overDelay = 0
    private var tick = 0
    private var rng = Rng()

    override var score: Int { return points }

    override func start() {
        playMusic(Tunes.race)
        level = 1
        buildLanes()
        respawn()
    }

    // MARK: Setup

    private func makeLane(_ kind: Int, _ variant: Int, _ speed: Float, _ w: Float, _ period: Float, _ phase: Float) -> Lane {
        var n = Int((160 + w) / period) + 1
        if n < 2 { n = 2 }
        return Lane(kind: kind, variant: variant, speed: speed, w: w, period: period,
                    count: n, total: Float(n) * period, phase: phase)
    }

    private func buildLanes() {
        var m: Float = 1 + 0.12 * Float(level - 1)
        if m > 2.0 { m = 2.0 }
        var l: [Lane] = []
        l.append(makeLane(3, 0, 0.35 * m, 48, 104, 0))     // row 2
        l.append(makeLane(4, 3, -0.45 * m, 24, 72, 20))    // row 3
        l.append(makeLane(3, 0, 0.6 * m, 32, 80, 5))       // row 4
        l.append(makeLane(3, 0, -0.3 * m, 64, 120, 40))    // row 5
        l.append(makeLane(4, 2, 0.5 * m, 16, 64, 11))      // row 6
        l.append(makeLane(3, 0, -0.5 * m, 40, 96, 33))     // row 7
        l.append(makeLane(0, 0, 0, 8, 8, 0))               // row 8 median
        l.append(makeLane(1, 0, -0.9 * m, 12, 58, 0))      // row 9
        l.append(makeLane(2, 0, 0.45 * m, 24, 92, 10))     // row 10
        l.append(makeLane(1, 1, -0.65 * m, 12, 52, 30))    // row 11
        l.append(makeLane(1, 2, 0.8 * m, 12, 66, 7))       // row 12
        l.append(makeLane(2, 1, -0.4 * m, 24, 100, 50))    // row 13
        l.append(makeLane(1, 0, 0.55 * m, 12, 54, 22))     // row 14
        lanes = l
        var tm = 1800 - (level - 1) * 120
        if tm < 900 { tm = 900 }
        timeMax = tm
    }

    private func newGame() {
        level = 1
        lives = 3
        points = 0
        nextLifeAt = 2000
        startLevel()
        mode = .playing
        playMusic(Tunes.race)
        play(.confirm)
    }

    private func startLevel() {
        buildLanes()
        for i in 0..<filled.count { filled[i] = false }
        filledCount = 0
        flyBay = -1
        flyCooldown = 200
        respawn()
    }

    private func respawn() {
        frogX = 76
        fromX = 76
        row = 15
        fromRow = 15
        bestRow = 15
        face = 0
        hopAnim = 0
        timeLeft = timeMax
    }

    private func addPoints(_ n: Int) {
        points += n
        if points >= nextLifeAt {
            nextLifeAt += 2500
            if lives < 6 { lives += 1 }
            play(.powerup)
        }
    }

    // MARK: Lane helpers

    private func objX(_ lane: Lane, _ i: Int) -> Float {
        if lane.total <= 0 { return -100 }
        var x = (lane.phase + Float(i) * lane.period).truncatingRemainder(dividingBy: lane.total)
        if x < 0 { x += lane.total }
        return x - lane.w
    }

    private func stepLanes() {
        for i in 0..<lanes.count {
            var l = lanes[i]
            l.phase += l.speed
            if l.total > 0 { l.phase = l.phase.truncatingRemainder(dividingBy: l.total) }
            lanes[i] = l
        }
    }

    /// 0 up, 1 sinking (still safe), 2 under water.
    private func turtleState(_ i: Int, _ r: Int) -> Int {
        if level < 2 { return 0 }
        let t = (tick + i * 83 + r * 47) % 480
        if t < 360 { return 0 }
        if t < 390 { return 1 }
        if t < 450 { return 2 }
        return 0
    }

    // MARK: Update

    override func update(_ input: InputState) {
        tick = (tick + 1) % 1_000_000
        switch mode {
        case .title:
            stepLanes()
            if input.aPressed || input.startPressed { newGame() }
        case .playing:
            updatePlaying(input)
        case .paused:
            if input.startPressed {
                mode = .playing
                play(.pause)
            }
        case .dying:
            stepLanes()
            deathTimer -= 1
            if deathTimer <= 0 { afterDeath() }
        case .clear:
            stepLanes()
            bannerTimer -= 1
            if bannerTimer <= 0 {
                level += 1
                startLevel()
                mode = .playing
            }
        case .over:
            stepLanes()
            if overDelay > 0 {
                overDelay -= 1
            } else if input.aPressed || input.startPressed {
                newGame()
            }
        }
    }

    private func updatePlaying(_ input: InputState) {
        if input.startPressed {
            mode = .paused
            play(.pause)
            return
        }
        stepLanes()
        updateFly()
        if hopAnim > 0 { hopAnim -= 1 }

        var ddx = 0
        var ddy = 0
        if input.upPressed { ddy = -1 }
        else if input.downPressed { ddy = 1 }
        else if input.leftPressed { ddx = -1 }
        else if input.rightPressed { ddx = 1 }
        if ddx != 0 || ddy != 0 { hop(ddx, ddy) }
        if mode != .playing { return }

        timeLeft -= 1
        if timeLeft <= 0 {
            kill(2)
            return
        }
        collisions()
    }

    private func updateFly() {
        if flyBay >= 0 {
            flyTimer -= 1
            if flyTimer <= 0 {
                flyBay = -1
                flyCooldown = 240
            }
        } else {
            flyCooldown -= 1
            if flyCooldown <= 0 {
                var cands: [Int] = []
                for i in 0..<filled.count {
                    if !filled[i] { cands.append(i) }
                }
                if cands.isEmpty {
                    flyCooldown = 120
                } else {
                    flyBay = cands[rng.int(cands.count)]
                    flyTimer = 300
                }
            }
        }
    }

    private func hop(_ ddx: Int, _ ddy: Int) {
        let nr = row + ddy
        if nr < 1 || nr > 15 { return }
        var nx = frogX + Float(ddx * 8)
        if nx < 0 { nx = 0 }
        if nx > 152 { nx = 152 }
        fromX = frogX
        fromRow = row
        hopAnim = 6
        if ddy < 0 { face = 0 }
        else if ddy > 0 { face = 2 }
        else if ddx > 0 { face = 1 }
        else { face = 3 }
        frogX = nx
        row = nr
        play(.step)
        if ddy < 0 && nr < bestRow {
            bestRow = nr
            addPoints(10)
        }
        if nr == 1 { reachGoal() }
    }

    private func reachGoal() {
        let cx = frogX + 4
        var bay = -1
        for i in 0..<5 {
            let bc = Float(16 + i * 32)
            if abs(cx - bc) <= 8 { bay = i }
        }
        if bay < 0 || filled[bay] {
            kill(0)
            return
        }
        filled[bay] = true
        filledCount += 1
        frogX = Float(16 + bay * 32 - 4)
        var pts = 50 + timeLeft / 20
        if flyBay == bay {
            pts += 200
            flyBay = -1
            flyCooldown = 300
            play(.powerup)
        } else {
            play(.coin)
        }
        addPoints(pts)
        if filledCount >= 5 {
            addPoints(500)
            mode = .clear
            bannerTimer = 110
            play(.win)
        } else {
            respawn()
        }
    }

    private func collisions() {
        let li = row - 2
        if li < 0 || li >= lanes.count { return }
        let lane = lanes[li]
        if row >= 9 && row <= 14 {
            let fl = frogX + 1
            let fr = frogX + 7
            for i in 0..<lane.count {
                let ox = objX(lane, i)
                if fr > ox + 1 && fl < ox + lane.w - 1 {
                    kill(0)
                    return
                }
            }
        } else if row >= 2 && row <= 7 {
            let cx = frogX + 4
            var onIt = false
            for i in 0..<lane.count {
                let ox = objX(lane, i)
                if cx >= ox + 1 && cx < ox + lane.w - 1 {
                    if lane.kind == 3 {
                        onIt = true
                    } else if lane.kind == 4 && turtleState(i, row) < 2 {
                        onIt = true
                    }
                }
            }
            if !onIt {
                kill(1)
                return
            }
            frogX += lane.speed
            if frogX < -4 || frogX > 156 { kill(1) }
        }
    }

    private func kill(_ kind: Int) {
        deathKind = kind
        deathTimer = 55
        lives -= 1
        mode = .dying
        if kind == 0 { play(.hurt) } else { play(.death) }
    }

    private func afterDeath() {
        if lives <= 0 {
            mode = .over
            overDelay = 40
            if points > best { best = points }
            playMusic(nil)
            play(.lose)
        } else {
            respawn()
            mode = .playing
        }
    }

    // MARK: Draw

    private func wrapMod(_ v: Int, _ m: Int) -> Int {
        if m <= 0 { return 0 }
        var r = v % m
        if r < 0 { r += m }
        return r
    }

    override func draw(_ c: Canvas) {
        c.clear(0)
        c.cameraX = 0
        c.cameraY = 0
        drawBackground(c)
        drawLanes(c)
        if mode == .playing || mode == .paused || mode == .dying {
            drawFrog(c)
        }
        drawHud(c)
        drawOverlay(c)
    }

    private func drawBackground(_ c: Canvas) {
        // Hedge with bays
        c.fillChecker(0, 8, 160, 8, 5, 3)
        for i in 0..<5 {
            let cx = 16 + i * 32
            c.fillRect(cx - 8, 8, 16, 8, 1)
            if filled[i] {
                c.draw(RoadHopper.frogIdle[0], cx - 4, 8)
            } else if flyBay == i {
                let bob = (tick / 10) % 2
                c.draw(RoadHopper.flySprite, cx - 2, 9 + bob)
            }
        }
        // River
        c.fillRect(0, 16, 160, 48, 1)
        for r in 2...7 {
            let y = r * 8
            let dirSign = (r % 2 == 0) ? 1 : -1
            for k in 0..<5 {
                let x = wrapMod(k * 36 + r * 13 + dirSign * (tick / 3), 160)
                c.hline(x, y + 3, 6, 2)
            }
        }
        // Median and start grass
        c.fillRect(0, 64, 160, 8, 3)
        c.fillRect(0, 120, 160, 8, 3)
        var gx = 0
        while gx < 160 {
            c.setPixel(gx + 2, 66, 4)
            c.setPixel(gx + 5, 69, 4)
            c.setPixel(gx + 4, 122, 4)
            c.setPixel(gx + 1, 125, 4)
            gx += 8
        }
        // Lane dashes on the road
        for r in 9...13 {
            var dx = 0
            while dx < 160 {
                c.hline(dx, r * 8 + 7, 6, 18)
                dx += 12
            }
        }
    }

    private func drawLog(_ c: Canvas, _ x: Int, _ y: Int, _ w: Int) {
        if w < 4 { return }
        c.fillRect(x + 1, y + 1, w - 2, 6, 10)
        c.fillRect(x + 1, y + 2, w - 2, 4, 9)
        c.fillRect(x, y + 2, 1, 4, 10)
        c.fillRect(x + w - 1, y + 2, 1, 4, 10)
        var k = 9
        while k < w - 4 {
            c.fillRect(x + k, y + 3, 2, 2, 10)
            k += 15
        }
    }

    private func drawLanes(_ c: Canvas) {
        for li in 0..<lanes.count {
            let lane = lanes[li]
            if lane.kind == 0 { continue }
            let r = li + 2
            let y = r * 8
            for i in 0..<lane.count {
                let ox = objX(lane, i)
                if ox > 160 || ox + lane.w < 0 { continue }
                let x = Int(ox)
                switch lane.kind {
                case 1:
                    let idx = clamp(lane.variant, 0, RoadHopper.carSprites.count - 1)
                    c.draw(RoadHopper.carSprites[idx], x, y, flipX: lane.speed > 0)
                case 2:
                    let idx = clamp(lane.variant, 0, RoadHopper.truckSprites.count - 1)
                    c.draw(RoadHopper.truckSprites[idx], x, y, flipX: lane.speed > 0)
                case 3:
                    drawLog(c, x, y, Int(lane.w))
                case 4:
                    let st = turtleState(i, r)
                    if st == 2 {
                        c.hline(x + 2, y + 4, 4, 2)
                    } else if st == 1 && (tick / 4) % 2 == 0 {
                        c.hline(x + 2, y + 4, 4, 2)
                    } else {
                        for t in 0..<lane.variant {
                            c.draw(RoadHopper.turtleSprite, x + t * 8, y)
                        }
                    }
                default:
                    break
                }
            }
        }
    }

    private func drawFrog(_ c: Canvas) {
        let t = Float(hopAnim) / 6
        let fx = frogX + (fromX - frogX) * t
        let fy = Float(row * 8) + Float((fromRow - row) * 8) * t
        let x = clamp(Int(fx), -20, 180)
        let y = clamp(Int(fy), -20, 160)
        let f = clamp(face, 0, 3)
        if mode == .dying {
            if deathKind == 0 {
                c.fillRect(x - 1, y + 2, 10, 5, 7)
                c.fillRect(x, y + 3, 8, 3, 6)
                c.setPixel(x + 2, y + 1, 8)
                c.setPixel(x + 6, y + 1, 8)
            } else if deathKind == 1 {
                let r = clamp((55 - deathTimer) / 5, 1, 10)
                c.strokeCircle(x + 4, y + 4, r, 8)
                if r > 3 { c.strokeCircle(x + 4, y + 4, r - 3, 2) }
            } else {
                if (deathTimer / 4) % 2 == 0 {
                    c.draw(RoadHopper.frogIdle[f], x, y, solid: 8)
                } else {
                    c.draw(RoadHopper.frogIdle[f], x, y)
                }
            }
            return
        }
        if hopAnim > 2 {
            c.draw(RoadHopper.frogHop[f], x, y)
        } else {
            c.draw(RoadHopper.frogIdle[f], x, y)
        }
    }

    private func drawHud(_ c: Canvas) {
        c.fillRect(0, 0, 160, 8, 17)
        c.text("SCORE " + zeroPad(points, 5), 2, 1, 8)
        c.text("HI " + zeroPad(best, 5), 62, 1, 20)
        let lv = "LV " + String(level)
        c.text(lv, 158 - c.textWidth(lv), 1, 8)

        c.fillRect(0, 128, 160, 16, 17)
        c.text("TIME", 2, 130, 8)
        c.strokeRect(21, 129, 122, 7, 8)
        var w = 0
        if timeMax > 0 { w = clamp(timeLeft * 120 / timeMax, 0, 120) }
        var barCol = 11
        if timeLeft * 4 < timeMax {
            barCol = ((tick / 8) % 2 == 0) ? 14 : 20
        }
        c.fillRect(22, 130, w, 5, barCol)
        let n = clamp(lives, 0, 6)
        for i in 0..<n {
            c.draw(RoadHopper.frogIdle[0], 2 + i * 10, 136)
        }
        let bays = "BAYS " + String(filledCount) + "/5"
        c.text(bays, 158 - c.textWidth(bays), 138, 20)
    }

    private func panel(_ c: Canvas, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        c.fillRect(x, y, w, h, 17)
        c.strokeRect(x, y, w, h, 8)
        c.strokeRect(x + 2, y + 2, w - 4, h - 4, 11)
    }

    private func drawOverlay(_ c: Canvas) {
        switch mode {
        case .title:
            panel(c, 14, 40, 132, 60)
            c.textCentered("ROAD HOPPER", y: 48, 20, scale: 2)
            c.textCentered("CROSS THE ROAD AND RIVER", y: 66, 8)
            c.textCentered("FILL ALL FIVE BAYS", y: 74, 11)
            if (tick / 30) % 2 == 0 { c.textCentered("PRESS A", y: 86, 8) }
        case .paused:
            panel(c, 40, 56, 80, 32)
            c.textCentered("PAUSED", y: 66, 20, scale: 2)
        case .clear:
            panel(c, 24, 56, 112, 36)
            c.textCentered("LEVEL CLEAR!", y: 62, 20, scale: 1)
            c.textCentered("BONUS +500", y: 74, 8)
        case .over:
            panel(c, 24, 44, 112, 64)
            c.textCentered("GAME OVER", y: 52, 20, scale: 2)
            c.textCentered("SCORE " + String(points), y: 72, 8)
            c.textCentered("BEST " + String(best), y: 82, 11)
            if overDelay <= 0 && (tick / 30) % 2 == 0 { c.textCentered("A: AGAIN", y: 94, 8) }
        case .playing, .dying:
            break
        }
    }
}

extension Cartridge {
    static let roadHopper = Cartridge(
        id: "roadhopper", title: "ROAD HOPPER", genre: "Arcade",
        blurb: "Dodge cars and trucks, then hop across a river on logs and diving turtles. Fill all five bays before the clock runs out.",
        controls: "D-PAD hops, START pauses.",
        era: .gbc, labelTop: 0x58C060, labelBottom: 0x1E4C8C, factory: { RoadHopper() })
}
