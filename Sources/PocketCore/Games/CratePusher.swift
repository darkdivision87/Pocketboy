#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// Sokoban: push every crate onto a goal. B undoes, SELECT restarts the level.
final class CratePusher: Game {
    private enum Mode { case title, select, play, cleared, congrats }

    private struct Snapshot {
        var crates: [Bool]
        var px: Int
        var py: Int
        var moves: Int
    }

    // 0 bg, 1 floor, 2 wall light, 3 wall dark, 4 crate, 5 crate outline, 6 crate on goal,
    // 7 goal marker, 8 white, 9 player body, 10 text, 11 dim text, 12 gold, 13 floor dot
    private static let pal = Palette.make([
        0x0C1020, 0x1C2848, 0x9AA8C8, 0x5A6890, 0xD89040, 0x6A3A10, 0xB8FFB8,
        0xF8D848, 0xF8F8F8, 0xFF6060, 0xF8F8F8, 0x8090B0, 0xF8D848, 0x26345A
    ])
    override var palette: [UInt16] { return CratePusher.pal }

    private static let wallSprite = Sprite([
        "22222232",
        "22222232",
        "33333333",
        "22322222",
        "22322222",
        "33333333",
        "22222232",
        "22222232"
    ])
    private static let crateSprite = Sprite([
        "55555555",
        "54444445",
        "54544545",
        "54445445",
        "54445445",
        "54544545",
        "54444445",
        "55555555"
    ])
    private static let crateGoalSprite = CratePusher.crateSprite.recolored(4, 6)
    private static let goalSprite = Sprite([
        "........",
        "........",
        "...77...",
        "..7777..",
        "..7777..",
        "...77...",
        "........",
        "........"
    ])
    private static let playerSprite = Sprite([
        "..8888..",
        ".880088.",
        ".888888.",
        "..9999..",
        ".999999.",
        "8.9999.8",
        "..9..9..",
        ".99..99."
    ])

    private static let levels: [[String]] = [
        ["#######", "#     #", "# .$@ #", "#     #", "#######"],
        ["#####", "#   #", "#.$ #", "#.$@#", "#####"],
        ["#########", "#       #", "# $*  . #", "#   ##@ #", "#       #", "#########"],
        ["  ######", "###  @ #", "#      #", "#  . . #", "# ## # #", "# $.$$ #", "#      #", "########"],
        ["#########", "#   #   #", "# $ #.  #", "#   $   #", "#   #.  #", "#   # @ #", "#########"],
        ["#########", "#    @  #", "# ## ## #", "#  . .  #", "# $ . $ #", "# ##$## #", "#       #", "#########"],
        [" #########", "##@      #", "# $$. .  #", "# $  #   #", "# .$ #.  #", "#        #", "##########"],
        ["  ##########", "###       ##", "# $ #*##   #", "# #.$ .#   #", "#  ##*##@  #", "# .#       #", "#  $ # .   #", "#  # $ #   #", "#          #", "############"],
        ["##########", "#    #   #", "# $  .$. #", "##@#### ##", "# $  .   #", "#   #*#  #", "#        #", "##########"],
        ["###########", "#   ##    #", "# * #   . #", "#   #   $ #", "####   ####", "#    .#   #", "# $  ## *@#", "#         #", "###########"],
        ["  ########", "###      #", "#  . # $ #", "# #. .#  #", "#   . $$ #", "#  # # $ #", "#       @#", "##########"],
        ["#############", "#     ##    #", "# .$$ ##  * #", "#  #     #  #", "# .#  .$ #. #", "#  $  ##  $@#", "#  #.   #   #", "#  #     #  #", "#     ##    #", "#           #", "#############"],
        ["###########", "#    #    #", "# . $#$ . #", "#  # $ #@ #", "# .# $ #. #", "#    .    #", "#  ##$##  #", "#         #", "###########"],
    ]

    private var mode: Mode = .title
    private var levelIndex = 0
    private var gridW = 1
    private var gridH = 1
    private var walls: [Bool] = []
    private var goals: [Bool] = []
    private var crates: [Bool] = []
    private var floorTiles: [Bool] = []
    private var px = 0
    private var py = 0
    private var faceLeft = false
    private var moves = 0
    private var undoStack: [Snapshot] = []
    private var best = [Int](repeating: 0, count: 64)
    private var done = [Bool](repeating: false, count: 64)
    private var maxUnlocked = 0
    private var cursor = 0
    private var holdTimer = 0
    private var clearTimer = 0
    private var frame = 0

    private var levelCount: Int { return CratePusher.levels.count }

    override var score: Int {
        var cleared = 0
        var penaltyMoves = 0
        for i in 0..<min(levelCount, done.count) where done[i] {
            cleared += 1
            penaltyMoves += best[i]
        }
        if mode == .play { penaltyMoves += moves }
        let value = cleared * 100 - penaltyMoves / 5
        return max(0, value)
    }

    override func start() { playMusic(Tunes.puzzle) }

    // MARK: Level handling

    private func loadLevel(_ index: Int) {
        let count = max(1, levelCount)
        levelIndex = clamp(index, 0, count - 1)
        var rows: [String] = ["#@#"]
        if levelIndex < CratePusher.levels.count { rows = CratePusher.levels[levelIndex] }
        var w = 1
        for r in rows { w = max(w, r.count) }
        let h = max(1, rows.count)
        gridW = w
        gridH = h
        walls = [Bool](repeating: false, count: w * h)
        goals = [Bool](repeating: false, count: w * h)
        crates = [Bool](repeating: false, count: w * h)
        floorTiles = [Bool](repeating: false, count: w * h)
        var sx = 0
        var sy = 0
        var y = 0
        for row in rows {
            var x = 0
            for ch in row {
                let i = y * w + x
                if i >= 0 && i < w * h {
                    switch ch {
                    case "#": walls[i] = true
                    case ".": goals[i] = true
                    case "$": crates[i] = true
                    case "*":
                        goals[i] = true
                        crates[i] = true
                    case "@":
                        sx = x
                        sy = y
                    case "+":
                        goals[i] = true
                        sx = x
                        sy = y
                    default: break
                    }
                }
                x += 1
            }
            y += 1
        }
        px = sx
        py = sy
        faceLeft = false
        moves = 0
        undoStack = []
        holdTimer = 0
        // Flood fill the walkable interior from the player.
        var stack: [Int] = [sy * w + sx]
        if sy * w + sx >= 0 && sy * w + sx < w * h { floorTiles[sy * w + sx] = true }
        var guardCount = 0
        while let cur = stack.popLast() {
            guardCount += 1
            if guardCount > 10000 { break }
            let cx = cur % w
            let cy = cur / w
            let dirs: [(Int, Int)] = [(1, 0), (-1, 0), (0, 1), (0, -1)]
            for d in dirs {
                let nx = cx + d.0
                let ny = cy + d.1
                if nx < 0 || ny < 0 || nx >= w || ny >= h { continue }
                let ni = ny * w + nx
                if walls[ni] || floorTiles[ni] { continue }
                floorTiles[ni] = true
                stack.append(ni)
            }
        }
    }

    private func inBounds(_ x: Int, _ y: Int) -> Bool {
        return x >= 0 && y >= 0 && x < gridW && y < gridH
    }

    private func pushUndo() {
        undoStack.append(Snapshot(crates: crates, px: px, py: py, moves: moves))
        if undoStack.count > 1500 { undoStack.removeFirst() }
    }

    private func undo() {
        if let s = undoStack.popLast() {
            crates = s.crates
            px = s.px
            py = s.py
            moves = s.moves
            play(.pause)
        } else {
            play(.blip)
        }
    }

    private func tryMove(_ dx: Int, _ dy: Int) {
        if dx < 0 { faceLeft = true }
        if dx > 0 { faceLeft = false }
        let nx = px + dx
        let ny = py + dy
        if !inBounds(nx, ny) { return }
        let ni = ny * gridW + nx
        if walls[ni] { return }
        if crates[ni] {
            let cx = nx + dx
            let cy = ny + dy
            if !inBounds(cx, cy) { return }
            let ci = cy * gridW + cx
            if walls[ci] || crates[ci] { return }
            pushUndo()
            crates[ci] = true
            crates[ni] = false
            play(.drop)
        } else {
            pushUndo()
            play(.step)
        }
        px = nx
        py = ny
        moves += 1
        checkWin()
    }

    private func checkWin() {
        var count = 0
        for i in 0..<crates.count where crates[i] {
            count += 1
            if !goals[i] { return }
        }
        if count == 0 { return }
        mode = .cleared
        clearTimer = 0
        if levelIndex < done.count {
            if !done[levelIndex] || best[levelIndex] == 0 || moves < best[levelIndex] {
                best[levelIndex] = moves
            }
            done[levelIndex] = true
        }
        maxUnlocked = max(maxUnlocked, min(levelIndex + 1, levelCount - 1))
        play(.win)
    }

    // MARK: Update

    override func update(_ input: InputState) {
        frame += 1
        switch mode {
        case .title:
            if input.aPressed || input.startPressed {
                play(.confirm)
                mode = .select
            }
        case .select:
            updateSelect(input)
        case .play:
            updatePlay(input)
        case .cleared:
            clearTimer += 1
            if clearTimer > 30 && (input.aPressed || input.startPressed) {
                play(.confirm)
                if levelIndex + 1 >= levelCount {
                    mode = .congrats
                    play(.win)
                } else {
                    loadLevel(levelIndex + 1)
                    mode = .play
                }
            }
            if input.bPressed {
                undo()
                mode = .play
            }
        case .congrats:
            if input.aPressed || input.startPressed {
                play(.select)
                cursor = clamp(levelCount - 1, 0, max(0, levelCount - 1))
                mode = .select
            }
        }
    }

    private func updateSelect(_ input: InputState) {
        let count = max(1, levelCount)
        if input.rightPressed { cursor = min(count - 1, cursor + 1); play(.blip) }
        if input.leftPressed { cursor = max(0, cursor - 1); play(.blip) }
        if input.downPressed && cursor + 4 < count { cursor += 4; play(.blip) }
        if input.upPressed && cursor - 4 >= 0 { cursor -= 4; play(.blip) }
        if input.aPressed || input.startPressed {
            if cursor <= maxUnlocked {
                play(.confirm)
                loadLevel(cursor)
                mode = .play
            } else {
                play(.thud)
            }
        }
        if input.bPressed {
            mode = .title
            play(.pause)
        }
    }

    private func updatePlay(_ input: InputState) {
        if input.selectPressed {
            play(.select)
            loadLevel(levelIndex)
            return
        }
        if input.startPressed {
            play(.pause)
            mode = .select
            cursor = levelIndex
            return
        }
        if input.bPressed {
            undo()
            return
        }
        let dx = input.dx
        let dy = input.dy
        if dx != 0 || dy != 0 {
            let fresh = input.leftPressed || input.rightPressed || input.upPressed || input.downPressed
            var go = false
            if fresh {
                holdTimer = 12
                go = true
            } else {
                holdTimer -= 1
                if holdTimer <= 0 {
                    holdTimer = 6
                    go = true
                }
            }
            if go {
                if dx != 0 { tryMove(dx, 0) } else { tryMove(0, dy) }
            }
        } else {
            holdTimer = 0
        }
    }

    // MARK: Draw

    override func draw(_ c: Canvas) {
        c.clear(0)
        c.cameraX = 0
        c.cameraY = 0
        switch mode {
        case .title: drawTitle(c)
        case .select: drawSelect(c)
        case .play: drawPlay(c, banner: false)
        case .cleared: drawPlay(c, banner: true)
        case .congrats: drawCongrats(c)
        }
    }

    private func drawTitle(_ c: Canvas) {
        c.fillRect(0, 100, 160, 44, 1)
        for i in 0..<10 {
            c.draw(CratePusher.wallSprite, i * 8 + 40, 100)
        }
        c.textCentered("CRATE", y: 20, 12, scale: 3)
        c.textCentered("PUSHER", y: 40, 8, scale: 3)
        // little animation: the hero pushes a crate onto a goal
        let phase = (frame / 3) % 120
        var cx = 50 + phase
        if cx > 100 { cx = 100 }
        c.draw(CratePusher.goalSprite, 100, 92)
        c.draw(cx >= 100 ? CratePusher.crateGoalSprite : CratePusher.crateSprite, cx, 92)
        c.draw(CratePusher.playerSprite, cx - 8, 92)
        if (frame / 30) % 2 == 0 {
            c.textCentered("PRESS A", y: 118, 10)
        }
        c.textCentered("PUSH ALL CRATES TO GOALS", y: 130, 11)
    }

    private func drawSelect(_ c: Canvas) {
        c.textCentered("SELECT LEVEL", y: 5, 12)
        c.hline(20, 13, 120, 3)
        let count = max(1, levelCount)
        for i in 0..<count {
            let col = i % 4
            let row = i / 4
            let x = 14 + col * 34
            let y = 20 + row * 26
            let unlocked = i <= maxUnlocked
            c.fillRect(x, y, 30, 22, unlocked ? 1 : 0)
            c.strokeRect(x, y, 30, 22, unlocked ? 2 : 3)
            let label = String(i + 1)
            let tw = c.textWidth(label, scale: 2)
            c.text(label, x + (30 - tw) / 2, y + 3, unlocked ? 10 : 3, scale: 2)
            if i < done.count && done[i] {
                c.text(String(best[i]), x + 3, y + 15, 11)
                c.text("*", x + 23, y + 15, 12)
            } else if !unlocked {
                c.text("-", x + 13, y + 15, 3)
            }
            if i == cursor {
                c.strokeRect(x - 2, y - 2, 34, 26, 12)
                c.strokeRect(x - 1, y - 1, 32, 24, 12)
            }
        }
        c.textCentered("A PLAY  B BACK", y: 135, 11)
    }

    private func drawPlay(_ c: Canvas, banner: Bool) {
        let ox = (160 - gridW * 8) / 2
        let oy = 12 + (120 - gridH * 8) / 2
        for y in 0..<gridH {
            for x in 0..<gridW {
                let i = y * gridW + x
                let sx = ox + x * 8
                let sy = oy + y * 8
                if floorTiles[i] {
                    c.fillRect(sx, sy, 8, 8, 1)
                    c.setPixel(sx + 3, sy + 3, 13)
                    if goals[i] { c.draw(CratePusher.goalSprite, sx, sy) }
                    if crates[i] {
                        c.draw(goals[i] ? CratePusher.crateGoalSprite : CratePusher.crateSprite, sx, sy)
                    }
                } else if walls[i] && touchesFloor(x, y) {
                    c.draw(CratePusher.wallSprite, sx, sy)
                }
            }
        }
        c.draw(CratePusher.playerSprite, ox + px * 8, oy + py * 8, flipX: faceLeft)
        // HUD
        c.fillRect(0, 0, 160, 11, 0)
        c.hline(0, 11, 160, 3)
        c.text("LV " + String(levelIndex + 1), 3, 3, 12)
        c.text("MOVES " + String(moves), 52, 3, 10)
        let bestText = levelIndex < best.count && best[levelIndex] > 0 ? String(best[levelIndex]) : "--"
        c.text("BEST " + bestText, 112, 3, 11)
        c.text("B UNDO  SEL RESET  START MENU", 4, 136, 11)
        if banner {
            c.fillRect(24, 50, 112, 42, 0)
            c.strokeRect(24, 50, 112, 42, 12)
            c.strokeRect(26, 52, 108, 38, 3)
            c.textCentered("LEVEL CLEAR!", y: 58, 12, scale: 2)
            c.textCentered("MOVES " + String(moves), y: 74, 10)
            if clearTimer > 30 && (frame / 20) % 2 == 0 {
                c.textCentered("A: CONTINUE", y: 83, 11)
            }
        }
    }

    private func touchesFloor(_ x: Int, _ y: Int) -> Bool {
        for dy in -1...1 {
            for dx in -1...1 {
                let nx = x + dx
                let ny = y + dy
                if inBounds(nx, ny) && floorTiles[ny * gridW + nx] { return true }
            }
        }
        return false
    }

    private func drawCongrats(_ c: Canvas) {
        c.fillRect(0, 0, 160, 144, 1)
        // falling crates as confetti
        for i in 0..<14 {
            let x = (i * 37 + 11) % 152
            let speed = 1 + (i % 3)
            let y = ((frame * speed) / 2 + i * 23) % 160 - 12
            c.draw(i % 2 == 0 ? CratePusher.crateSprite : CratePusher.crateGoalSprite, x, y)
        }
        c.fillRect(14, 36, 132, 68, 0)
        c.strokeRect(14, 36, 132, 68, 12)
        c.strokeRect(16, 38, 128, 64, 3)
        c.textCentered("CONGRATULATIONS!", y: 44, 12)
        c.textCentered("ALL CRATES", y: 56, 10, scale: 2)
        c.textCentered("DELIVERED", y: 68, 8, scale: 2)
        c.textCentered("SCORE " + String(score), y: 84, 10)
        if (frame / 30) % 2 == 0 {
            c.textCentered("A: LEVEL SELECT", y: 94, 11)
        }
    }
}

extension Cartridge {
    static let cratePusher = Cartridge(
        id: "cratepusher", title: "CRATE PUSHER", genre: "Puzzle",
        blurb: "A warehouse puzzle: shove every crate onto a goal without trapping yourself. Thirteen levels from easy to brain-melting.",
        controls: "D-PAD move, B undo, SELECT restart, START menu.",
        era: .gb, labelTop: 0xE0A040, labelBottom: 0x5A3A18, factory: { CratePusher() })
}
