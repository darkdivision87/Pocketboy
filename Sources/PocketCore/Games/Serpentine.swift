import Foundation

/// Snake with buffered turns, bonus food, speed ramp and three obstacle stages.
final class Serpentine: Game {
    // MARK: Palette (light background, dark outlines; see GAME_AUTHORING.md)
    private static let pal = Palette.make([
        0xC8E8A0, // 0 grass
        0xB8DC90, // 1 grass checker
        0x183828, // 2 near black (outline, HUD)
        0x2C8040, // 3 snake body
        0x58C868, // 4 snake body light
        0xE03030, // 5 apple red
        0xF8D030, // 6 gold
        0x6A6A78, // 7 wall gray
        0x383848, // 8 wall dark
        0xF8F8F8  // 9 white
    ])
    override var palette: [UInt16] { return Serpentine.pal }

    private static let foodSprite = Sprite([
        "....32..",
        "..2222..",
        ".255552.",
        "25955552",
        "25555552",
        "25555552",
        ".255552.",
        "..2222.."
    ])
    private static let bonusSprite = Sprite([
        "...22...",
        "..2662..",
        ".266662.",
        "26666662",
        "26966662",
        ".266662.",
        "..2662..",
        "...22..."
    ])
    private static let wallSprite = Sprite([
        "77777778",
        "77777778",
        "77777778",
        "88888888",
        "77787777",
        "77787777",
        "77787777",
        "88888888"
    ])

    private enum Mode { case title, playing, paused, dying, over }
    private struct P {
        var x: Int
        var y: Int
    }

    private let cols = 20
    private let rows = 16
    private let originY = 16
    private let dxs: [Int] = [0, 1, 0, -1]
    private let dys: [Int] = [-1, 0, 1, 0]

    private var mode: Mode = .title
    private var body: [P] = []
    private var dir = 1
    private var queue: [Int] = []
    private var grow = 0
    private var moveTimer = 10
    private var walls = [Bool](repeating: false, count: 320)
    private var stage = 0
    private var eaten = 0
    private var points = 0
    private var best = 0
    private var foodX = 10
    private var foodY = 8
    private var bonusX = -1
    private var bonusY = -1
    private var bonusTimer = 0
    private var banner = 0
    private var deathTimer = 0
    private var overDelay = 0
    private var tick = 0
    private var rng = Rng()

    override var score: Int { return points }

    override func start() {
        playMusic(Tunes.desert)
        resetSnake()
        buildObstacles(0)
        placeFood()
    }

    // MARK: Setup

    private func beginGame() {
        stage = 0
        eaten = 0
        points = 0
        bonusTimer = 0
        bonusX = -1
        bonusY = -1
        banner = 0
        buildObstacles(0)
        resetSnake()
        placeFood()
        mode = .playing
        playMusic(Tunes.desert)
        play(.confirm)
    }

    private func resetSnake() {
        body = [P(x: 4, y: 8), P(x: 3, y: 8), P(x: 2, y: 8)]
        dir = 1
        queue = []
        grow = 0
        moveTimer = stepInterval()
    }

    private func setWall(_ x: Int, _ y: Int) {
        if x < 0 || y < 0 || x >= cols || y >= rows { return }
        walls[y * cols + x] = true
    }

    private func buildObstacles(_ s: Int) {
        for i in 0..<walls.count { walls[i] = false }
        if s >= 1 {
            for x in 0..<cols {
                setWall(x, 0)
                setWall(x, rows - 1)
            }
            for y in 0..<rows {
                setWall(0, y)
                setWall(cols - 1, y)
            }
        }
        if s >= 2 {
            for y in 2...13 {
                if y < 6 || y > 9 {
                    setWall(6, y)
                    setWall(13, y)
                }
            }
        }
        if s >= 3 {
            for x in 3...16 {
                if x < 8 || x > 11 {
                    setWall(x, 4)
                    setWall(x, 11)
                }
            }
        }
    }

    private func isWall(_ x: Int, _ y: Int) -> Bool {
        if x < 0 || y < 0 || x >= cols || y >= rows { return true }
        return walls[y * cols + x]
    }

    private func isFree(_ x: Int, _ y: Int) -> Bool {
        if isWall(x, y) { return false }
        for p in body {
            if p.x == x && p.y == y { return false }
        }
        if x == bonusX && y == bonusY && bonusTimer > 0 { return false }
        if x == foodX && y == foodY { return false }
        return true
    }

    private func placeFood() {
        foodX = -1
        foodY = -1
        var tries = 0
        while tries < 400 {
            let x = rng.int(cols)
            let y = rng.int(rows)
            if isFree(x, y) {
                foodX = x
                foodY = y
                return
            }
            tries += 1
        }
        for y in 0..<rows {
            for x in 0..<cols {
                if isFree(x, y) {
                    foodX = x
                    foodY = y
                    return
                }
            }
        }
    }

    private func spawnBonus() {
        var tries = 0
        while tries < 200 {
            let x = rng.int(cols)
            let y = rng.int(rows)
            if isFree(x, y) {
                bonusX = x
                bonusY = y
                bonusTimer = 300
                return
            }
            tries += 1
        }
    }

    private func stepInterval() -> Int {
        let v = 12 - eaten / 4
        return max(5, v)
    }

    // MARK: Update

    override func update(_ input: InputState) {
        tick = (tick + 1) % 1_000_000
        switch mode {
        case .title:
            if input.aPressed || input.startPressed { beginGame() }
        case .playing:
            updatePlaying(input)
        case .paused:
            if input.startPressed {
                mode = .playing
                play(.pause)
            }
        case .dying:
            deathTimer -= 1
            if deathTimer <= 0 {
                mode = .over
                overDelay = 40
            }
        case .over:
            if overDelay > 0 {
                overDelay -= 1
            } else if input.aPressed || input.startPressed {
                beginGame()
            }
        }
    }

    private func queueTurn(_ input: InputState) {
        var want = -1
        if input.upPressed { want = 0 }
        else if input.rightPressed { want = 1 }
        else if input.downPressed { want = 2 }
        else if input.leftPressed { want = 3 }
        if want < 0 { return }
        var last = dir
        if let q = queue.last { last = q }
        if want == last { return }
        if (want + 2) % 4 == last { return }
        if queue.count < 2 { queue.append(want) }
    }

    private func updatePlaying(_ input: InputState) {
        if input.startPressed {
            mode = .paused
            play(.pause)
            return
        }
        queueTurn(input)
        if banner > 0 {
            banner -= 1
            return
        }
        if bonusTimer > 0 { bonusTimer -= 1 }
        moveTimer -= 1
        if moveTimer > 0 { return }
        moveTimer = stepInterval()
        step()
    }

    private func die() {
        mode = .dying
        deathTimer = 55
        if points > best { best = points }
        playMusic(nil)
        play(.death)
    }

    private func step() {
        if body.isEmpty { return }
        if !queue.isEmpty {
            let d = queue.removeFirst()
            if d >= 0 && d < 4 && (d + 2) % 4 != dir { dir = d }
        }
        var nx = body[0].x + dxs[dir]
        var ny = body[0].y + dys[dir]
        if stage == 0 {
            if nx < 0 { nx = cols - 1 }
            if nx >= cols { nx = 0 }
            if ny < 0 { ny = rows - 1 }
            if ny >= rows { ny = 0 }
        }
        if isWall(nx, ny) {
            die()
            return
        }
        let limit = grow > 0 ? body.count : body.count - 1
        var i = 0
        while i < limit {
            if body[i].x == nx && body[i].y == ny {
                die()
                return
            }
            i += 1
        }
        body.insert(P(x: nx, y: ny), at: 0)
        if grow > 0 {
            grow -= 1
        } else {
            body.removeLast()
        }

        if bonusTimer > 0 && nx == bonusX && ny == bonusY {
            points += 30 + bonusTimer / 10
            bonusTimer = 0
            grow += 2
            play(.powerup)
        }
        if nx == foodX && ny == foodY {
            points += 10 + stage * 5
            eaten += 1
            grow += 1
            play(.pickup)
            var newStage = 0
            if eaten >= 24 { newStage = 3 }
            else if eaten >= 16 { newStage = 2 }
            else if eaten >= 8 { newStage = 1 }
            if newStage > stage {
                enterStage(newStage)
            } else {
                placeFood()
                if eaten % 5 == 0 { spawnBonus() }
            }
        }
    }

    private func enterStage(_ s: Int) {
        stage = s
        bonusTimer = 0
        bonusX = -1
        bonusY = -1
        buildObstacles(s)
        resetSnake()
        placeFood()
        banner = 90
        play(.lineClear)
    }

    // MARK: Draw

    override func draw(_ c: Canvas) {
        c.clear(0)
        c.cameraX = 0
        c.cameraY = 0
        for gy in 0..<rows {
            for gx in 0..<cols {
                if (gx + gy) % 2 == 1 { c.fillRect(gx * 8, originY + gy * 8, 8, 8, 1) }
            }
        }
        for gy in 0..<rows {
            for gx in 0..<cols {
                if walls[gy * cols + gx] { c.draw(Serpentine.wallSprite, gx * 8, originY + gy * 8) }
            }
        }
        if foodX >= 0 {
            c.draw(Serpentine.foodSprite, foodX * 8, originY + foodY * 8)
        }
        if bonusTimer > 0 {
            let show = bonusTimer > 90 || (bonusTimer / 6) % 2 == 0
            if show { c.draw(Serpentine.bonusSprite, bonusX * 8, originY + bonusY * 8) }
        }
        var showSnake = true
        if mode == .dying && (deathTimer / 5) % 2 == 1 { showSnake = false }
        if showSnake { drawSnake(c) }
        drawHud(c)
        drawOverlay(c)
    }

    private func drawSnake(_ c: Canvas) {
        if body.isEmpty { return }
        var i = 0
        while i < body.count {
            let p = body[i]
            c.fillRect(p.x * 8, originY + p.y * 8, 8, 8, 2)
            i += 1
        }
        i = body.count - 1
        while i >= 0 {
            let p = body[i]
            let px = p.x * 8
            let py = originY + p.y * 8
            let col = (i % 2 == 0) ? 3 : 4
            c.fillRect(px + 1, py + 1, 6, 6, col)
            if i + 1 < body.count {
                let q = body[i + 1]
                if abs(p.x - q.x) + abs(p.y - q.y) == 1 {
                    if p.x != q.x {
                        let bx = min(p.x, q.x) * 8 + 7
                        c.fillRect(bx, py + 1, 2, 6, col)
                    } else {
                        let by = originY + min(p.y, q.y) * 8 + 7
                        c.fillRect(px + 1, by, 6, 2, col)
                    }
                }
            }
            i -= 1
        }
        // Head with eyes
        let h = body[0]
        let hx = h.x * 8
        let hy = originY + h.y * 8
        var ax = 1
        var ay = 1
        var bx = 5
        var by = 1
        if dir == 1 { ax = 5; ay = 1; bx = 5; by = 5 }
        else if dir == 2 { ax = 1; ay = 5; bx = 5; by = 5 }
        else if dir == 3 { ax = 1; ay = 1; bx = 1; by = 5 }
        c.fillRect(hx + ax, hy + ay, 2, 2, 9)
        c.fillRect(hx + bx, hy + by, 2, 2, 9)
        let pdx = dxs[dir] > 0 ? 1 : 0
        let pdy = dys[dir] > 0 ? 1 : 0
        c.setPixel(hx + ax + pdx, hy + ay + pdy, 2)
        c.setPixel(hx + bx + pdx, hy + by + pdy, 2)
    }

    private func drawHud(_ c: Canvas) {
        c.fillRect(0, 0, 160, 16, 2)
        c.text("SCORE " + zeroPad(points, 4), 4, 2, 9)
        c.text("BEST " + zeroPad(best, 4), 4, 9, 4)
        let st = "STAGE " + String(stage + 1)
        c.text(st, 156 - c.textWidth(st), 2, 9)
        if bonusTimer > 0 {
            let w = clamp(bonusTimer * 40 / 300, 0, 40)
            c.fillRect(116, 10, w, 4, 6)
        } else {
            let ln = "LEN " + String(body.count)
            c.text(ln, 156 - c.textWidth(ln), 9, 4)
        }
    }

    private func panel(_ c: Canvas, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        c.fillRect(x, y, w, h, 2)
        c.strokeRect(x, y, w, h, 4)
        c.strokeRect(x + 2, y + 2, w - 4, h - 4, 3)
    }

    private func drawOverlay(_ c: Canvas) {
        switch mode {
        case .title:
            panel(c, 16, 36, 128, 76)
            c.textCentered("SERPENTINE", y: 44, 6, scale: 2)
            c.textCentered("EAT. GROW. DON'T BITE.", y: 62, 9)
            c.textCentered("D-PAD TURNS", y: 72, 4)
            if (tick / 30) % 2 == 0 { c.textCentered("PRESS A", y: 90, 9, scale: 1) }
            // Little marching snake
            let off = (tick / 4) % 40
            var k = 0
            while k < 6 {
                let sx = 20 + off + (5 - k) * 8
                if sx < 130 {
                    c.fillRect(sx, 100, 7, 7, k == 5 ? 3 : 4)
                }
                k += 1
            }
        case .paused:
            panel(c, 40, 56, 80, 32)
            c.textCentered("PAUSED", y: 66, 6, scale: 2)
        case .over:
            panel(c, 24, 40, 112, 68)
            c.textCentered("GAME OVER", y: 48, 6, scale: 2)
            c.textCentered("SCORE " + String(points), y: 68, 9)
            c.textCentered("BEST " + String(best), y: 78, 4)
            if overDelay <= 0 && (tick / 30) % 2 == 0 { c.textCentered("A: AGAIN", y: 92, 9) }
        case .playing:
            if banner > 0 {
                panel(c, 36, 60, 88, 26)
                c.textCentered("STAGE " + String(stage + 1), y: 68, 6, scale: 2)
            }
        case .dying:
            break
        }
    }
}

extension Cartridge {
    static let serpentine = Cartridge(
        id: "serpentine", title: "SERPENTINE", genre: "Arcade",
        blurb: "Eat apples, grab timed bonus gems and grow long without biting yourself. Walls and mazes appear as you score.",
        controls: "D-PAD turns, START pauses.",
        era: .gb, labelTop: 0x7CC070, labelBottom: 0x1F5A34, factory: { Serpentine() })
}
