import Foundation

/// Falling-block puzzle: 7 tetrominoes, 7-bag, wall kicks, ghost piece, line-clear flash.
final class BlockDrop: Game {
    private enum Phase { case title, play, clearing, over }

    // Palette indices:
    // 0 bg, 1 white, 2..8 piece colours (I O T S Z J L), 9 grid dot, 10 wall, 11 panel line,
    // 12 unused, 13 cell shadow, 14 ghost / label (light)
    private static let pal = Palette.make([
        0x0C1020, 0xF8F8F8, 0x48D8F0, 0xF8E050, 0x9048D0, 0x50D060, 0xE04040,
        0x5070F0, 0xF8A030, 0x1C2848, 0x7080A8, 0x4A5880, 0x000000, 0x181820, 0xB0C0E0
    ])
    override var palette: [UInt16] { return BlockDrop.pal }

    // Shapes indexed [type][rotation] -> 8 ints (x0,y0,x1,y1,...). Types: I O T S Z J L.
    private static let shapes: [[[Int]]] = {
        let bases: [[Int]] = [
            [0, 1, 1, 1, 2, 1, 3, 1],
            [0, 0, 1, 0, 0, 1, 1, 1],
            [1, 0, 0, 1, 1, 1, 2, 1],
            [1, 0, 2, 0, 0, 1, 1, 1],
            [0, 0, 1, 0, 1, 1, 2, 1],
            [0, 0, 0, 1, 1, 1, 2, 1],
            [2, 0, 0, 1, 1, 1, 2, 1]
        ]
        let sizes: [Int] = [4, 2, 3, 3, 3, 3, 3]
        var out: [[[Int]]] = []
        for t in 0..<7 {
            var rots: [[Int]] = []
            var cur = bases[t]
            let n = sizes[t]
            for _ in 0..<4 {
                rots.append(cur)
                var nxt = [Int](repeating: 0, count: 8)
                for k in 0..<4 {
                    let x = cur[k * 2]
                    let y = cur[k * 2 + 1]
                    nxt[k * 2] = n - 1 - y
                    nxt[k * 2 + 1] = x
                }
                cur = nxt
            }
            out.append(rots)
        }
        return out
    }()

    private static let gravity: [Int] = [40, 35, 30, 26, 22, 18, 15, 12, 10, 8, 7, 6, 5, 4, 3, 2]

    private let cols = 10
    private let rows = 18
    private let wellX = 4

    private var phase: Phase = .title
    private var tick = 0
    private var rng = Rng()
    private var board = [Int](repeating: 0, count: 180)
    private var curType = 0
    private var curRot = 0
    private var curX = 3
    private var curY = 0
    private var nextType = 0
    private var bag: [Int] = []
    private var gravCounter = 0
    private var lockTimer = 0
    private var lockResets = 0
    private var dasDir = 0
    private var dasTimer = 0
    private var points = 0
    private var lines = 0
    private var level = 0
    private var paused = false
    private var clearRows: [Int] = []
    private var clearTimer = 0

    override var score: Int { return points }

    override func start() { playMusic(Tunes.puzzle) }

    // MARK: Game flow

    private func newGame() {
        for i in 0..<board.count { board[i] = 0 }
        bag = []
        points = 0
        lines = 0
        level = 0
        paused = false
        clearRows = []
        nextType = drawFromBag()
        spawn()
        if phase != .over { phase = .play }
    }

    private func drawFromBag() -> Int {
        if bag.isEmpty {
            var items: [Int] = [0, 1, 2, 3, 4, 5, 6]
            var i = items.count - 1
            while i > 0 {
                let j = rng.int(i + 1)
                let tmp = items[i]
                items[i] = items[j]
                items[j] = tmp
                i -= 1
            }
            bag = items
        }
        if let v = bag.popLast() { return v }
        return 0
    }

    private func spawn() {
        curType = nextType
        nextType = drawFromBag()
        curRot = 0
        curX = 3
        curY = 0
        gravCounter = 0
        lockTimer = 0
        lockResets = 0
        dasTimer = 0
        if collides(curType, curRot, curX, curY) {
            phase = .over
            play(.death)
        }
    }

    private func cellList(_ type: Int, _ rot: Int) -> [Int] {
        let t = clamp(type, 0, 6)
        return BlockDrop.shapes[t][rot & 3]
    }

    private func collides(_ type: Int, _ rot: Int, _ px: Int, _ py: Int) -> Bool {
        let s = cellList(type, rot)
        for k in 0..<4 {
            let x = px + s[k * 2]
            let y = py + s[k * 2 + 1]
            if x < 0 || x >= cols || y >= rows { return true }
            if y >= 0 {
                let idx = y * cols + x
                if idx < 0 || idx >= board.count { return true }
                if board[idx] != 0 { return true }
            }
        }
        return false
    }

    private func gravityInterval() -> Int {
        let idx = clamp(level, 0, BlockDrop.gravity.count - 1)
        return BlockDrop.gravity[idx]
    }

    private func tryMove(_ dx: Int) {
        if !collides(curType, curRot, curX + dx, curY) {
            curX += dx
            noteMoved()
            play(.step)
        }
    }

    private func noteMoved() {
        if lockResets < 12 {
            lockResets += 1
            lockTimer = 0
        }
    }

    private func tryRotate(_ dir: Int) {
        if curType == 1 { return }
        let newRot = (curRot + dir + 4) % 4
        let kicks: [Int] = [0, 0, -1, 0, 1, 0, 0, -1, -2, 0, 2, 0, -1, -1, 1, -1]
        var k = 0
        while k + 1 < kicks.count {
            let ox = kicks[k]
            let oy = kicks[k + 1]
            if !collides(curType, newRot, curX + ox, curY + oy) {
                curRot = newRot
                curX += ox
                curY += oy
                noteMoved()
                play(.blip)
                return
            }
            k += 2
        }
    }

    private func lockPiece() {
        let s = cellList(curType, curRot)
        var overTop = false
        for k in 0..<4 {
            let x = curX + s[k * 2]
            let y = curY + s[k * 2 + 1]
            if y < 0 { overTop = true; continue }
            if x < 0 || x >= cols || y >= rows { continue }
            board[y * cols + x] = curType + 1
        }
        if overTop {
            phase = .over
            play(.death)
            return
        }
        var full: [Int] = []
        for y in 0..<rows {
            var all = true
            for x in 0..<cols {
                if board[y * cols + x] == 0 { all = false; break }
            }
            if all { full.append(y) }
        }
        if full.isEmpty {
            play(.drop)
            spawn()
        } else {
            clearRows = full
            clearTimer = 26
            phase = .clearing
            if full.count >= 4 { play(.powerup) } else { play(.lineClear) }
        }
    }

    private func finishClear() {
        var newBoard = [Int](repeating: 0, count: cols * rows)
        var dst = rows - 1
        var src = rows - 1
        while src >= 0 {
            if clearRows.contains(src) {
                src -= 1
                continue
            }
            if dst >= 0 {
                for x in 0..<cols { newBoard[dst * cols + x] = board[src * cols + x] }
            }
            dst -= 1
            src -= 1
        }
        board = newBoard
        let n = clearRows.count
        let table: [Int] = [0, 40, 100, 300, 1200]
        points += table[clamp(n, 0, 4)] * (level + 1)
        lines += n
        level = lines / 10
        clearRows = []
        spawn()
        if phase == .clearing { phase = .play }
    }

    private func ghostY() -> Int {
        var y = curY
        var guardCount = 0
        while !collides(curType, curRot, curX, y + 1) && guardCount < 40 {
            y += 1
            guardCount += 1
        }
        return y
    }

    // MARK: Update

    override func update(_ input: InputState) {
        tick += 1
        switch phase {
        case .title:
            if input.aPressed || input.startPressed {
                play(.confirm)
                phase = .play
                newGame()
            }
        case .over:
            if input.aPressed || input.startPressed {
                play(.confirm)
                phase = .play
                newGame()
            }
        case .clearing:
            clearTimer -= 1
            if clearTimer <= 0 { finishClear() }
        case .play:
            updatePlay(input)
        }
    }

    private func updatePlay(_ input: InputState) {
        if input.startPressed {
            paused = !paused
            play(.pause)
        }
        if paused { return }

        if input.aPressed { tryRotate(1) }
        if input.bPressed { tryRotate(-1) }

        let dir = input.dx
        if dir == 0 {
            dasDir = 0
            dasTimer = 0
        } else if dir != dasDir {
            dasDir = dir
            dasTimer = 0
            tryMove(dir)
        } else {
            dasTimer += 1
            if dasTimer >= 12 && (dasTimer - 12) % 4 == 0 { tryMove(dir) }
        }

        if input.upPressed {
            var dropped = 0
            var guardCount = 0
            while !collides(curType, curRot, curX, curY + 1) && guardCount < 40 {
                curY += 1
                dropped += 1
                guardCount += 1
            }
            points += dropped * 2
            lockPiece()
            return
        }

        let grounded = collides(curType, curRot, curX, curY + 1)
        if grounded {
            lockTimer += input.down ? 6 : 1
            if lockTimer >= 30 {
                lockPiece()
                return
            }
        } else {
            gravCounter += 1
            var interval = gravityInterval()
            if input.down { interval = min(interval, 2) }
            if gravCounter >= interval {
                gravCounter = 0
                curY += 1
                if input.down { points += 1 }
            }
        }
    }

    // MARK: Draw

    private func drawCell(_ c: Canvas, _ x: Int, _ y: Int, _ type: Int, _ size: Int) {
        let t = clamp(type, 0, 6)
        c.fillRect(x, y, size, size, t + 2)
        c.hline(x, y, size, 1)
        c.vline(x, y, size, 1)
        c.hline(x, y + size - 1, size, 13)
        c.vline(x + size - 1, y, size, 13)
        if size >= 8 {
            if t == 3 || t == 4 {
                c.hline(x + 2, y + 3, 4, 13)
                c.hline(x + 2, y + 4, 4, 13)
            } else if t == 5 || t == 6 {
                c.fillRect(x + 3, y + 3, 2, 2, 13)
            }
        }
    }

    private func label(_ c: Canvas, _ s: String, _ y: Int, _ col: Int) {
        let w = c.textWidth(s)
        c.text(s, 124 - w / 2, y, col)
    }

    override func draw(_ c: Canvas) {
        c.clear(0)
        // Walls
        c.fillRect(0, 0, 4, 144, 10)
        c.vline(0, 0, 144, 1)
        c.fillRect(84, 0, 4, 144, 10)
        c.vline(87, 0, 144, 13)

        // Well background dots
        for y in 0..<rows {
            for x in 0..<cols {
                let v = board[y * cols + x]
                let px = wellX + x * 8
                let py = y * 8
                if v == 0 {
                    c.setPixel(px + 4, py + 4, 9)
                } else {
                    drawCell(c, px, py, v - 1, 8)
                }
            }
        }

        if phase == .play || phase == .clearing {
            if phase == .play { drawActive(c) }
            if phase == .clearing {
                let on = (clearTimer / 3) % 2 == 0
                for r in clearRows {
                    c.fillRect(wellX, r * 8, 80, 8, on ? 1 : 0)
                }
            }
        }

        drawPanel(c)

        switch phase {
        case .title:
            c.fillRect(wellX, 28, 80, 80, 0)
            c.strokeRect(wellX, 28, 80, 80, 11)
            c.text("GET READY", wellX + 20, 36, 3)
            c.text("UP HARD DROP", wellX + 16, 52, 14)
            c.text("DOWN SOFT", wellX + 20, 60, 14)
            c.text("A B ROTATE", wellX + 18, 68, 14)
            if (tick / 25) % 2 == 0 { c.text("PRESS A", wellX + 26, 88, 1) }
        case .over:
            c.fillRect(wellX + 4, 52, 72, 40, 0)
            c.strokeRect(wellX + 4, 52, 72, 40, 11)
            c.text("GAME OVER", wellX + 20, 58, 6)
            c.text(zeroPad(points, 6), wellX + 28, 70, 1)
            if (tick / 25) % 2 == 0 { c.text("PRESS A", wellX + 26, 80, 3) }
        case .play:
            if paused {
                c.fillRect(wellX + 10, 62, 60, 20, 0)
                c.strokeRect(wellX + 10, 62, 60, 20, 11)
                c.text("PAUSED", wellX + 28, 70, 1)
            }
        case .clearing:
            break
        }
    }

    private func drawActive(_ c: Canvas) {
        let s = cellList(curType, curRot)
        let gy = ghostY()
        if gy != curY {
            for k in 0..<4 {
                let x = curX + s[k * 2]
                let y = gy + s[k * 2 + 1]
                if y >= 0 {
                    c.strokeRect(wellX + x * 8, y * 8, 8, 8, 14)
                }
            }
        }
        for k in 0..<4 {
            let x = curX + s[k * 2]
            let y = curY + s[k * 2 + 1]
            if y >= 0 {
                drawCell(c, wellX + x * 8, y * 8, curType, 8)
            }
        }
    }

    private func drawPanel(_ c: Canvas) {
        let t1 = "BLOCK"
        c.text(t1, 124 - c.textWidth(t1, scale: 2) / 2, 4, 3, scale: 2)
        let t2 = "DROP"
        c.text(t2, 124 - c.textWidth(t2, scale: 2) / 2, 15, 2, scale: 2)

        label(c, "NEXT", 30, 14)
        c.strokeRect(104, 38, 40, 28, 11)
        if phase != .title {
            let s = cellList(nextType, 0)
            var minX = 9
            var maxX = 0
            var minY = 9
            var maxY = 0
            for k in 0..<4 {
                minX = min(minX, s[k * 2])
                maxX = max(maxX, s[k * 2])
                minY = min(minY, s[k * 2 + 1])
                maxY = max(maxY, s[k * 2 + 1])
            }
            let w = (maxX - minX + 1) * 6
            let h = (maxY - minY + 1) * 6
            let ox = 104 + (40 - w) / 2
            let oy = 38 + (28 - h) / 2
            for k in 0..<4 {
                drawCell(c, ox + (s[k * 2] - minX) * 6, oy + (s[k * 2 + 1] - minY) * 6, nextType, 6)
            }
        }

        label(c, "SCORE", 78, 14)
        label(c, zeroPad(points, 6), 85, 1)
        label(c, "LEVEL", 98, 14)
        label(c, String(level + 1), 105, 1)
        label(c, "LINES", 118, 14)
        label(c, String(lines), 125, 1)
    }
}

extension Cartridge {
    static let blockDrop = Cartridge(
        id: "blockdrop", title: "BLOCK DROP", genre: "Puzzle",
        blurb: "Stack the falling blocks into solid lines before the well overflows. Gravity speeds up every ten lines.",
        controls: "LEFT / RIGHT move, DOWN soft drop, UP hard drop, A / B rotate, START pauses.",
        era: .gb, labelTop: 0x48A8E8, labelBottom: 0x1C2A5A, factory: { BlockDrop() })
}
