#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// One-button cave flyer: flap through stalactites and stalagmites, grab coins, earn medals.
final class CaveFlap: Game {
    // MARK: Palette (dark cave, light rock and bird)
    private static let pal = Palette.make([
        0x141028, // 0 cave background (darkest)
        0x4C4484, // 1 mid layer (dark)
        0x2A2250, // 2 far layer (darkest)
        0x9890B8, // 3 rock light
        0x6C6494, // 4 rock shade / floor (dark)
        0x1C1634, // 5 outline (darkest)
        0xFFE060, // 6 bird body (lightest)
        0xF08030, // 7 bird wing / beak (light)
        0xF8F8F8, // 8 white
        0xFFD020, // 9 coin gold (lightest)
        0xC08010, // 10 coin shade (light)
        0xC87838, // 11 bronze
        0xD0D8E8, // 12 silver
        0x80F0E0, // 13 platinum
        0xA8D8F0  // 14 crystal sparkle
    ])
    override var palette: [UInt16] { return CaveFlap.pal }

    private static let birdSprite = Sprite([
        "..555555..",
        ".566666885",
        "5666666655",
        "5666666775",
        ".566666655",
        "..55555..."
    ])

    private static func makeProfile(_ n: Int, _ k1: Double, _ k2: Double, _ base: Double, _ amp: Double) -> [Int] {
        var out: [Int] = []
        let nd = Double(n)
        for i in 0..<n {
            let t = Double(i)
            var v = base + amp * abs(sin(t * Double.pi * k1 / nd)) + amp * 0.4 * sin(t * 2 * Double.pi * k2 / nd)
            if v < 2 { v = 2 }
            if v > 60 { v = 60 }
            out.append(Int(v))
        }
        return out
    }
    private static let farProfile: [Int] = CaveFlap.makeProfile(40, 5, 3, 10, 22)
    private static let midProfile: [Int] = CaveFlap.makeProfile(48, 7, 5, 6, 16)
    private static let sparkles: [(Int, Int)] = [
        (12, 30), (40, 90), (66, 20), (88, 110), (101, 48), (130, 80), (150, 24),
        (24, 120), (74, 64), (118, 124), (140, 56), (52, 40)
    ]

    private enum Mode { case title, playing, paused, dying, over }

    private struct Obstacle {
        var x: Float
        var gapY: Int
        var gap: Int
        var passed: Bool
        var coin: Bool
        var coinTaken: Bool
    }

    private let birdX: Float = 40
    private let pillarW = 24
    private let bandWidths: [Int] = [24, 20, 16, 12, 8]

    private var mode: Mode = .title
    private var birdY: Float = 66
    private var vy: Float = 0
    private var flapTimer = 0
    private var scroll: Float = 0
    private var obstacles: [Obstacle] = []
    private var lastGapY = 60
    private var passedCount = 0
    private var coins = 0
    private var best = 0
    private var dyTimer = 0
    private var flash = 0
    private var overDelay = 0
    private var tick = 0
    private var rng = Rng()

    override var score: Int { return passedCount + coins * 2 }

    override func start() {
        playMusic(Tunes.space)
    }

    // MARK: Setup

    private func begin() {
        mode = .playing
        birdY = 66
        vy = -2.7
        flapTimer = 8
        scroll = 0
        obstacles = []
        passedCount = 0
        coins = 0
        lastGapY = 60
        flash = 0
        dyTimer = 0
        spawnObstacle(190)
        playMusic(Tunes.space)
        play(.bounce)
    }

    private func currentSpeed() -> Float {
        var s: Float = 1.2 + Float(score / 6) * 0.05
        if s > 2.1 { s = 2.1 }
        return s
    }

    private func currentGap() -> Int {
        return max(36, 48 - score / 8)
    }

    private func spawnObstacle(_ x: Float) {
        let gap = currentGap()
        let lo = 20
        let hi = 144 - 20 - gap
        var g = lastGapY + rng.range(-40, 40)
        g = clamp(g, lo, max(lo, hi))
        lastGapY = g
        let o = Obstacle(x: x, gapY: g, gap: gap, passed: false, coin: rng.chance(60), coinTaken: false)
        obstacles.append(o)
    }

    // MARK: Geometry

    /// Rock bands of a pillar: 5 stacked rectangles above the gap and 5 below it.
    private func pillarBoxes(_ o: Obstacle) -> [Box] {
        var out: [Box] = []
        let ox = Int(o.x)
        let topH = max(0, o.gapY)
        let botTop = o.gapY + o.gap
        let botH = max(0, 144 - botTop)
        for i in 0..<5 {
            let w = bandWidths[i]
            let bx = ox + (pillarW - w) / 2
            let y0 = i * topH / 5
            let y1 = (i + 1) * topH / 5
            if y1 > y0 { out.append(Box(bx, y0, w, y1 - y0)) }
            let b0 = (i + 1) * botH / 5
            let b1 = i * botH / 5
            if b0 > b1 { out.append(Box(bx, 144 - b0, w, b0 - b1)) }
        }
        return out
    }

    private func birdBox() -> Box {
        return Box(Int(birdX) + 2, Int(birdY) + 1, 6, 4)
    }

    private func coinBox(_ o: Obstacle) -> Box {
        return Box(Int(o.x) + 9, o.gapY + o.gap / 2 - 3, 6, 6)
    }

    // MARK: Update

    override func update(_ input: InputState) {
        tick = (tick + 1) % 1_000_000
        switch mode {
        case .title:
            scroll += 0.6
            birdY = 66 + sin(Float(tick) * 0.08) * 4
            if (tick / 10) % 2 == 0 { flapTimer = 6 } else { flapTimer = 0 }
            if input.aPressed || input.upPressed || input.startPressed { begin() }
        case .playing:
            updatePlaying(input)
        case .paused:
            if input.startPressed {
                mode = .playing
                play(.pause)
            }
        case .dying:
            updateDying()
        case .over:
            if overDelay > 0 {
                overDelay -= 1
            } else if input.aPressed || input.startPressed {
                begin()
            }
        }
    }

    private func updatePlaying(_ input: InputState) {
        if input.startPressed {
            mode = .paused
            play(.pause)
            return
        }
        if flapTimer > 0 { flapTimer -= 1 }
        if input.aPressed || input.upPressed {
            vy = -2.7
            flapTimer = 8
            play(.bounce)
        }
        vy += 0.17
        vy = clamp(vy, -4, 3.4)
        birdY += vy
        if birdY < 9 {
            birdY = 9
            if vy < 0 { vy = 0 }
        }

        let speed = currentSpeed()
        scroll += speed
        var i = 0
        while i < obstacles.count {
            obstacles[i].x -= speed
            i += 1
        }
        while let first = obstacles.first, first.x < -30 {
            obstacles.removeFirst()
        }
        var lastX: Float = -1000
        if let l = obstacles.last { lastX = l.x }
        var spacing: Float = 84 - Float(score / 8) * 2
        if spacing < 64 { spacing = 64 }
        if obstacles.isEmpty || lastX < 160 - spacing {
            spawnObstacle(max(165, lastX + spacing))
        }

        // Scoring and coins
        let bb = birdBox()
        for j in 0..<obstacles.count {
            if !obstacles[j].passed && obstacles[j].x + Float(pillarW) < birdX {
                obstacles[j].passed = true
                passedCount += 1
                play(.blip)
            }
            if obstacles[j].coin && !obstacles[j].coinTaken {
                if bb.intersects(coinBox(obstacles[j])) {
                    obstacles[j].coinTaken = true
                    coins += 1
                    play(.coin)
                }
            }
        }

        // Collisions
        if birdY + 7 >= 137 {
            die()
            return
        }
        for o in obstacles {
            if abs(o.x - birdX) > 40 { continue }
            for b in pillarBoxes(o) {
                if bb.intersects(b) {
                    die()
                    return
                }
            }
        }
    }

    private func die() {
        mode = .dying
        dyTimer = 0
        vy = -2
        flash = 6
        playMusic(nil)
        play(.hit)
    }

    private func updateDying() {
        dyTimer += 1
        if flash > 0 { flash -= 1 }
        vy += 0.2
        if vy > 4 { vy = 4 }
        birdY += vy
        if birdY >= 128 {
            birdY = 128
            if dyTimer > 25 { finishRun() }
        }
        if dyTimer > 90 { finishRun() }
    }

    private func finishRun() {
        mode = .over
        overDelay = 45
        if score > best { best = score }
        play(.lose)
    }

    private func medalTier() -> Int {
        let s = score
        if s >= 60 { return 4 }
        if s >= 40 { return 3 }
        if s >= 25 { return 2 }
        if s >= 10 { return 1 }
        return 0
    }

    // MARK: Draw

    private func drawBackground(_ c: Canvas) {
        c.clear(0)
        let far = CaveFlap.farProfile
        let mid = CaveFlap.midProfile
        let fs = Int(scroll * 0.2)
        let ms = Int(scroll * 0.5)
        var x = 0
        while x < 160 {
            let fi = ((((x + fs) / 4) % far.count) + far.count) % far.count
            let fh = far[fi]
            c.fillRect(x, 0, 4, fh, 2)
            let fi2 = (fi + 13) % far.count
            c.fillRect(x, 144 - far[fi2] / 2, 4, far[fi2] / 2, 2)
            let mi = ((((x + ms) / 4) % mid.count) + mid.count) % mid.count
            let mh = mid[mi]
            c.fillRect(x, 0, 4, mh, 1)
            let mi2 = (mi + 17) % mid.count
            c.fillRect(x, 144 - mid[mi2] / 2, 4, mid[mi2] / 2, 1)
            x += 4
        }
        let ss = Int(scroll * 0.35)
        for (sx, sy) in CaveFlap.sparkles {
            let px = (((sx - ss) % 160) + 160) % 160
            if (tick / 20 + sx) % 3 != 0 { c.setPixel(px, sy, 14) }
        }
    }

    private func drawPillar(_ c: Canvas, _ o: Obstacle) {
        let boxes = pillarBoxes(o)
        for b in boxes { c.fillRect(b.x - 1, b.y - 1, b.w + 2, b.h + 2, 5) }
        for b in boxes {
            c.fillRect(b.x, b.y, b.w, b.h, 3)
            c.fillRect(b.x + b.w - 3, b.y, 3, b.h, 4)
        }
    }

    private func drawCoin(_ c: Canvas, _ o: Obstacle) {
        let widths: [Int] = [6, 4, 2, 4]
        let w = widths[(tick / 6) % 4]
        let b = coinBox(o)
        let cx = b.x + 3
        c.fillRect(cx - w / 2 - 1, b.y, w + 2, 6, 10)
        c.fillRect(cx - w / 2, b.y + 1, w, 4, 9)
    }

    private func drawRockEdges(_ c: Canvas) {
        let off = Int(scroll)
        var x = 0
        while x < 160 {
            let idx = (x + off) / 8
            let jag = (idx * 37 + 11) % 4
            // ceiling
            c.fillRect(x, 0, 8, 7 + jag, 4)
            c.hline(x, 7 + jag, 8, 5)
            // floor
            c.fillRect(x, 137 + jag - 1, 8, 8, 4)
            c.hline(x, 137 + jag - 1, 8, 3)
            x += 8
        }
        c.fillRect(0, 141, 160, 3, 4)
    }

    private func drawBird(_ c: Canvas) {
        let x = Int(birdX)
        let y = clamp(Int(birdY), -20, 160)
        // wing: down right after a flap, up while falling, level in between
        if flapTimer > 0 {
            c.fillRect(x + 2, y + 5, 4, 2, 7)
            c.fillRect(x + 3, y + 7, 2, 1, 7)
        } else if vy > 1 {
            c.fillRect(x + 2, y - 2, 4, 3, 7)
            c.fillRect(x + 3, y - 3, 2, 1, 7)
        } else {
            c.fillRect(x + 1, y + 3, 5, 2, 7)
        }
        if mode == .dying && flash > 0 {
            c.draw(CaveFlap.birdSprite, x, y, solid: 8)
        } else {
            c.draw(CaveFlap.birdSprite, x, y)
        }
    }

    private func bigNumber(_ c: Canvas, _ s: String, _ y: Int) {
        let w = c.textWidth(s, scale: 2)
        let x = (160 - w) / 2
        c.text(s, x - 1, y, 5, scale: 2)
        c.text(s, x + 1, y, 5, scale: 2)
        c.text(s, x, y - 1, 5, scale: 2)
        c.text(s, x, y + 1, 5, scale: 2)
        c.text(s, x, y, 8, scale: 2)
    }

    override func draw(_ c: Canvas) {
        c.cameraX = 0
        c.cameraY = 0
        drawBackground(c)
        for o in obstacles {
            if o.x > 170 || o.x < -30 { continue }
            drawPillar(c, o)
            if o.coin && !o.coinTaken { drawCoin(c, o) }
        }
        drawRockEdges(c)
        drawBird(c)
        if mode == .playing || mode == .paused || mode == .dying {
            bigNumber(c, String(score), 12)
        }
        c.text("COINS " + String(coins), 3, 139, 8)
        let bs = "BEST " + String(max(best, score))
        c.text(bs, 157 - c.textWidth(bs), 139, 8)
        if mode == .dying && flash > 3 { c.fillRect(0, 0, 160, 144, 8) }
        drawOverlay(c)
    }

    private func panel(_ c: Canvas, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        c.fillRect(x, y, w, h, 5)
        c.strokeRect(x, y, w, h, 3)
        c.strokeRect(x + 2, y + 2, w - 4, h - 4, 4)
    }

    private func drawMedal(_ c: Canvas, _ cx: Int, _ cy: Int, _ tier: Int) {
        if tier <= 0 {
            c.strokeCircle(cx, cy, 8, 4)
            c.text("?", cx - 1, cy - 2, 4)
            return
        }
        var col = 11
        if tier == 2 { col = 12 }
        else if tier == 3 { col = 9 }
        else if tier == 4 { col = 13 }
        c.fillRect(cx - 6, cy - 16, 4, 9, 7)
        c.fillRect(cx + 2, cy - 16, 4, 9, 14)
        c.fillCircle(cx, cy, 9, 5)
        c.fillCircle(cx, cy, 8, col)
        c.strokeCircle(cx, cy, 5, 5)
        c.text(String(tier), cx - 1, cy - 2, 5)
    }

    private func drawOverlay(_ c: Canvas) {
        switch mode {
        case .title:
            panel(c, 20, 20, 120, 34)
            c.textCentered("CAVE FLAP", y: 28, 9, scale: 2)
            c.textCentered("A OR UP TO FLAP", y: 44, 8)
            if (tick / 30) % 2 == 0 { c.textCentered("PRESS A", y: 100, 8) }
        case .paused:
            panel(c, 40, 56, 80, 32)
            c.textCentered("PAUSED", y: 66, 9, scale: 2)
        case .over:
            panel(c, 16, 22, 128, 100)
            c.textCentered("GAME OVER", y: 28, 9, scale: 2)
            drawMedal(c, 44, 78, medalTier())
            c.text("SCORE " + String(score), 66, 56, 8)
            c.text("BEST " + String(best), 66, 66, 9)
            c.text("COINS " + String(coins), 66, 76, 9)
            let names: [String] = ["NO MEDAL", "BRONZE", "SILVER", "GOLD", "PLATINUM"]
            c.text(names[clamp(medalTier(), 0, 4)], 66, 88, 14)
            if overDelay <= 0 && (tick / 30) % 2 == 0 { c.textCentered("A: AGAIN", y: 108, 8) }
        case .playing, .dying:
            break
        }
    }
}

extension Cartridge {
    static let caveFlap = Cartridge(
        id: "caveflap", title: "CAVE FLAP", genre: "Arcade",
        blurb: "Flap through a crystal cave of stalactites and stalagmites, scoop up coins and chase the platinum medal.",
        controls: "A or UP flaps, START pauses.",
        era: .gb, labelTop: 0x8A6CD8, labelBottom: 0x1A1038, factory: { CaveFlap() })
}
