#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// Cursor-driven minesweeper: 18x14 board of 8px cells, safe first dig, flood fill, chording, three difficulties.
final class MineSweeper: Game {
    // MARK: Palette (dark frame, light board, dark numbers)
    private static let pal = Palette.make([
        0x283048, // 0 screen background (darkest)
        0xA0A8B8, // 1 hidden cell (light)
        0xD8DCE8, // 2 hidden highlight (lightest)
        0x606880, // 3 hidden shadow (dark)
        0xE4E6EE, // 4 revealed cell (lightest)
        0xC4C8D4, // 5 revealed grid line
        0x2030D0, // 6 number 1
        0x207828, // 7 number 2
        0xC02020, // 8 number 3
        0x101080, // 9 number 4
        0x801010, // 10 number 5
        0x108080, // 11 number 6
        0x181818, // 12 number 7 / mine black
        0x585858, // 13 number 8
        0xE02020, // 14 flag red
        0xF04040, // 15 exploded cell
        0xF8F8F8, // 16 white
        0xF8D030, // 17 gold
        0xB8BCC8, // 18 HUD panel (light)
        0xFF4040, // 19 LED red
        0xFFE040  // 20 face yellow
    ])
    override var palette: [UInt16] { return MineSweeper.pal }

    private static let flagSprite = Sprite([
        "...ceee.",
        "...ceee.",
        "...cee..",
        "...ce...",
        "...c....",
        "..ccc...",
        ".ccccc..",
        "........"
    ])
    private static let mineSprite = Sprite([
        "...cc...",
        ".c.cc.c.",
        "..cccc..",
        "cccgcccc",
        "cccccccc",
        "..cccc..",
        ".c.cc.c.",
        "...cc..."
    ])
    private static let numberColors: [Int] = [6, 7, 8, 9, 10, 11, 12, 13]
    private static let mineCounts: [Int] = [30, 43, 55]
    private static let diffNames: [String] = ["EASY", "NORMAL", "HARD"]

    private enum Mode { case title, playing, won, lost }

    private let cols = 18
    private let rows = 14
    private let x0 = 8
    private let y0 = 19

    // state: 0 hidden, 1 revealed, 2 flagged, 3 mine shown after a loss
    private var mine = [Bool](repeating: false, count: 252)
    private var adj = [Int](repeating: 0, count: 252)
    private var state = [UInt8](repeating: 0, count: 252)

    private var mode: Mode = .title
    private var diff = 0
    private var cx = 9
    private var cy = 7
    private var holdTimer = 14
    private var minesPlaced = false
    private var revealedSafe = 0
    private var flagsCount = 0
    private var timerFrames = 0
    private var winBonus = 0
    private var winTimer = 0
    private var explodedIdx = -1
    private var loseQueue: [Int] = []
    private var loseIdx = 0
    private var loseTimer = 0
    private var loseDone = false
    private var tick = 0
    private var rng = Rng()

    override var score: Int {
        return revealedSafe * 10 + winBonus
    }

    override func start() {
        playMusic(nil)
    }

    // MARK: Helpers

    private func mineCount() -> Int {
        let i = clamp(diff, 0, MineSweeper.mineCounts.count - 1)
        return MineSweeper.mineCounts[i]
    }

    private func inBounds(_ x: Int, _ y: Int) -> Bool {
        return x >= 0 && y >= 0 && x < cols && y < rows
    }

    private func seconds() -> Int {
        return min(999, timerFrames / 60)
    }

    private func newBoard() {
        for i in 0..<mine.count {
            mine[i] = false
            adj[i] = 0
            state[i] = 0
        }
        mode = .playing
        minesPlaced = false
        revealedSafe = 0
        flagsCount = 0
        timerFrames = 0
        winBonus = 0
        winTimer = 0
        explodedIdx = -1
        loseQueue = []
        loseIdx = 0
        loseTimer = 0
        loseDone = false
        cx = cols / 2
        cy = rows / 2
        holdTimer = 14
    }

    private func placeMines(_ fx: Int, _ fy: Int) {
        let total = cols * rows
        let want = mineCount()
        var placed = 0
        var guardN = 0
        while placed < want && guardN < 30000 {
            guardN += 1
            let i = rng.int(total)
            let mx = i % cols
            let my = i / cols
            if abs(mx - fx) <= 1 && abs(my - fy) <= 1 { continue }
            if mine[i] { continue }
            mine[i] = true
            placed += 1
        }
        for y in 0..<rows {
            for x in 0..<cols {
                var n = 0
                for dy in -1...1 {
                    for dx in -1...1 {
                        if dx == 0 && dy == 0 { continue }
                        let nx = x + dx
                        let ny = y + dy
                        if inBounds(nx, ny) && mine[ny * cols + nx] { n += 1 }
                    }
                }
                adj[y * cols + x] = n
            }
        }
        minesPlaced = true
    }

    private func reveal(_ x: Int, _ y: Int) {
        if !inBounds(x, y) { return }
        var stack: [Int] = [y * cols + x]
        while let idx = stack.popLast() {
            if idx < 0 || idx >= state.count { continue }
            if state[idx] != 0 { continue }
            state[idx] = 1
            if !mine[idx] { revealedSafe += 1 }
            if adj[idx] == 0 && !mine[idx] {
                let px = idx % cols
                let py = idx / cols
                for dy in -1...1 {
                    for dx in -1...1 {
                        if dx == 0 && dy == 0 { continue }
                        let nx = px + dx
                        let ny = py + dy
                        if inBounds(nx, ny) {
                            let ni = ny * cols + nx
                            if state[ni] == 0 { stack.append(ni) }
                        }
                    }
                }
            }
        }
    }

    private func lose(_ idx: Int) {
        if idx >= 0 && idx < state.count { state[idx] = 1 }
        explodedIdx = idx
        mode = .lost
        loseTimer = 0
        loseDone = false
        loseIdx = 0
        let ex = idx % cols
        let ey = idx / cols
        var arr: [(Int, Int)] = []
        for i in 0..<mine.count {
            if mine[i] && state[i] == 0 {
                let dx = (i % cols) - ex
                let dy = (i / cols) - ey
                arr.append((dx * dx + dy * dy, i))
            }
        }
        arr.sort { $0.0 < $1.0 }
        loseQueue = []
        for item in arr { loseQueue.append(item.1) }
        play(.explosion)
    }

    private func checkWin() {
        if mode != .playing { return }
        if revealedSafe >= cols * rows - mineCount() {
            mode = .won
            winTimer = 0
            for i in 0..<mine.count {
                if mine[i] { state[i] = 2 }
            }
            flagsCount = mineCount()
            var b = 1000 - seconds() * 3
            if b < 0 { b = 0 }
            winBonus = b * (diff + 1)
            play(.win)
        }
    }

    private func chord(_ x: Int, _ y: Int) {
        let idx = y * cols + x
        let n = adj[idx]
        if n <= 0 { return }
        var flags = 0
        for dy in -1...1 {
            for dx in -1...1 {
                if dx == 0 && dy == 0 { continue }
                let nx = x + dx
                let ny = y + dy
                if inBounds(nx, ny) && state[ny * cols + nx] == 2 { flags += 1 }
            }
        }
        if flags != n { return }
        var hit = -1
        for dy in -1...1 {
            for dx in -1...1 {
                if dx == 0 && dy == 0 { continue }
                let nx = x + dx
                let ny = y + dy
                if !inBounds(nx, ny) { continue }
                let ni = ny * cols + nx
                if state[ni] != 0 { continue }
                if mine[ni] {
                    if hit < 0 { hit = ni }
                } else {
                    reveal(nx, ny)
                }
            }
        }
        if hit >= 0 {
            lose(hit)
            return
        }
        play(.blip)
        checkWin()
    }

    // MARK: Update

    override func update(_ input: InputState) {
        tick = (tick + 1) % 1_000_000
        switch mode {
        case .title:
            if input.aPressed || input.startPressed {
                newBoard()
                play(.confirm)
            }
            if input.selectPressed { cycleDifficulty() }
        case .playing:
            updatePlaying(input)
        case .won:
            winTimer += 1
            moveCursor(input)
            if input.selectPressed {
                cycleDifficulty()
                newBoard()
            } else if (input.aPressed || input.startPressed) && winTimer > 30 {
                newBoard()
                play(.confirm)
            }
        case .lost:
            loseTimer += 1
            if loseTimer % 2 == 0 && loseIdx < loseQueue.count {
                let i = loseQueue[loseIdx]
                if i >= 0 && i < state.count { state[i] = 3 }
                loseIdx += 1
                if loseIdx % 4 == 1 { play(.hit) }
            }
            if loseIdx >= loseQueue.count { loseDone = true }
            moveCursor(input)
            if input.selectPressed {
                cycleDifficulty()
                newBoard()
            } else if (input.aPressed || input.startPressed) && (loseDone || loseTimer > 90) {
                newBoard()
                play(.confirm)
            }
        }
    }

    private func cycleDifficulty() {
        diff = (diff + 1) % MineSweeper.mineCounts.count
        play(.select)
    }

    private func moveCursor(_ input: InputState) {
        let dx = input.dx
        let dy = input.dy
        var moved = false
        if input.leftPressed || input.rightPressed || input.upPressed || input.downPressed {
            moved = true
            holdTimer = 14
        } else if dx != 0 || dy != 0 {
            holdTimer -= 1
            if holdTimer <= 0 {
                moved = true
                holdTimer = 4
            }
        } else {
            holdTimer = 14
        }
        if moved {
            cx = clamp(cx + dx, 0, cols - 1)
            cy = clamp(cy + dy, 0, rows - 1)
        }
    }

    private func updatePlaying(_ input: InputState) {
        moveCursor(input)
        if input.selectPressed {
            cycleDifficulty()
            newBoard()
            return
        }
        if input.startPressed {
            newBoard()
            play(.select)
            return
        }
        let idx = cy * cols + cx
        if idx < 0 || idx >= state.count { return }
        if input.bPressed {
            if state[idx] == 0 {
                state[idx] = 2
                flagsCount += 1
                play(.select)
            } else if state[idx] == 2 {
                state[idx] = 0
                flagsCount -= 1
                play(.blip)
            }
        }
        if input.aPressed {
            if state[idx] == 1 {
                chord(cx, cy)
            } else if state[idx] == 0 {
                if !minesPlaced { placeMines(cx, cy) }
                if mine[idx] {
                    lose(idx)
                    return
                }
                let before = revealedSafe
                reveal(cx, cy)
                if revealedSafe - before > 3 { play(.pickup) } else { play(.blip) }
                checkWin()
            }
        }
        if minesPlaced && mode == .playing { timerFrames += 1 }
    }

    // MARK: Draw

    override func draw(_ c: Canvas) {
        c.cameraX = 0
        c.cameraY = 0
        c.clear(0)
        drawHud(c)
        c.fillRect(x0 - 2, y0 - 2, cols * 8 + 4, rows * 8 + 4, 12)
        for y in 0..<rows {
            for x in 0..<cols {
                drawCell(c, x, y)
            }
        }
        if mode != .title { drawCursor(c) }
        drawFooter(c)
        if mode == .title { drawTitle(c) }
    }

    private func ledText(_ n: Int) -> String {
        if n < 0 { return "-" + zeroPad(min(99, -n), 2) }
        return zeroPad(min(999, n), 3)
    }

    private func drawHud(_ c: Canvas) {
        c.fillRect(4, 2, 152, 14, 18)
        c.strokeRect(4, 2, 152, 14, 2)
        // Mine counter
        c.fillRect(7, 4, 26, 10, 12)
        c.text(ledText(mineCount() - flagsCount), 9, 4, 19, scale: 2)
        // Timer
        c.fillRect(127, 4, 26, 10, 12)
        c.text(zeroPad(seconds(), 3), 129, 4, 19, scale: 2)
        // Face
        c.fillCircle(80, 9, 5, 20)
        c.strokeCircle(80, 9, 5, 12)
        if mode == .lost {
            c.setPixel(77, 7, 12); c.setPixel(79, 7, 12); c.setPixel(78, 8, 12); c.setPixel(77, 9, 12); c.setPixel(79, 9, 12)
            c.setPixel(81, 7, 12); c.setPixel(83, 7, 12); c.setPixel(82, 8, 12); c.setPixel(81, 9, 12); c.setPixel(83, 9, 12)
            c.setPixel(78, 12, 12); c.setPixel(79, 11, 12); c.setPixel(80, 11, 12); c.setPixel(81, 11, 12); c.setPixel(82, 12, 12)
        } else if mode == .won {
            c.fillRect(76, 7, 9, 2, 12)
            c.setPixel(77, 11, 12); c.setPixel(83, 11, 12)
            c.hline(78, 12, 5, 12)
        } else {
            c.setPixel(78, 7, 12); c.setPixel(82, 7, 12)
            c.setPixel(77, 10, 12); c.setPixel(83, 10, 12)
            c.hline(78, 11, 5, 12)
        }
    }

    private func drawCell(_ c: Canvas, _ x: Int, _ y: Int) {
        let idx = y * cols + x
        let px = x0 + x * 8
        let py = y0 + y * 8
        let st = state[idx]
        if st == 0 || st == 2 {
            if mode == .lost && st == 2 && !mine[idx] {
                // wrong flag: shown as revealed cell with crossed mine
                c.fillRect(px, py, 8, 8, 4)
                c.draw(MineSweeper.mineSprite, px, py)
                c.line(px, py, px + 7, py + 7, 14)
                c.line(px + 7, py, px, py + 7, 14)
                return
            }
            c.fillRect(px, py, 8, 8, 1)
            c.hline(px, py, 8, 2)
            c.vline(px, py, 8, 2)
            c.hline(px, py + 7, 8, 3)
            c.vline(px + 7, py, 8, 3)
            if st == 2 { c.draw(MineSweeper.flagSprite, px, py) }
            return
        }
        // revealed (1) or shown mine (3)
        if idx == explodedIdx {
            c.fillRect(px, py, 8, 8, 15)
        } else {
            c.fillRect(px, py, 8, 8, 4)
            c.hline(px, py, 8, 5)
            c.vline(px, py, 8, 5)
        }
        if mine[idx] {
            c.draw(MineSweeper.mineSprite, px, py)
        } else {
            let n = adj[idx]
            if n > 0 {
                let ci = clamp(n - 1, 0, MineSweeper.numberColors.count - 1)
                c.text(String(n), px + 3, py + 2, MineSweeper.numberColors[ci])
            }
            if mode == .won && ((x + y) * 3 + winTimer / 3) % 11 == 0 {
                c.setPixel(px + 2, py + 2, 17)
                c.setPixel(px + 1, py + 2, 16)
                c.setPixel(px + 3, py + 2, 16)
                c.setPixel(px + 2, py + 1, 16)
                c.setPixel(px + 2, py + 3, 16)
            }
        }
    }

    private func drawCursor(_ c: Canvas) {
        let px = x0 + cx * 8
        let py = y0 + cy * 8
        let blink = (tick / 15) % 2 == 0
        c.strokeRect(px - 1, py - 1, 10, 10, 12)
        c.strokeRect(px, py, 8, 8, blink ? 17 : 16)
    }

    private func drawFooter(_ c: Canvas) {
        let name = MineSweeper.diffNames[clamp(diff, 0, MineSweeper.diffNames.count - 1)]
        switch mode {
        case .won:
            c.textCentered("CLEARED IN " + String(seconds()) + "S! +" + String(winBonus), y: 133, 17)
            c.textCentered("A: NEW  SEL: LEVEL", y: 139, 16)
        case .lost:
            c.textCentered("BOOM! YOU HIT A MINE", y: 133, 17)
            c.textCentered("A: NEW  SEL: LEVEL", y: 139, 16)
        default:
            c.textCentered(name + " - " + String(mineCount()) + " MINES", y: 133, 17)
            c.textCentered("A DIG  B FLAG  SEL LEVEL", y: 139, 16)
        }
    }

    private func drawTitle(_ c: Canvas) {
        c.fillRect(10, 30, 140, 80, 0)
        c.strokeRect(10, 30, 140, 80, 17)
        c.strokeRect(12, 32, 136, 76, 3)
        c.textCentered("MINE", y: 38, 17, scale: 2)
        c.textCentered("SWEEPER", y: 50, 17, scale: 2)
        c.textCentered("A DIG   B FLAG", y: 68, 16)
        c.textCentered("A ON A NUMBER CLEARS AROUND", y: 76, 18)
        c.textCentered("SELECT: " + MineSweeper.diffNames[clamp(diff, 0, 2)], y: 86, 16)
        if (tick / 30) % 2 == 0 { c.textCentered("PRESS A", y: 98, 17) }
    }
}

extension Cartridge {
    static let mineSweeper = Cartridge(
        id: "minesweeper", title: "MINE SWEEPER", genre: "Puzzle",
        blurb: "Clear the field without touching a mine. Your first dig is always safe, and digging a number with enough flags clears its neighbours.",
        controls: "D-PAD moves, A digs, B flags, SELECT changes difficulty.",
        era: .gb, labelTop: 0xB8C0D8, labelBottom: 0x38405C, factory: { MineSweeper() })
}
