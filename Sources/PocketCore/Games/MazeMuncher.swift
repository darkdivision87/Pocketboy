import Foundation

/// Pac-style maze chase: 19x15 tiles of 8px, four ghosts with different brains.
final class MazeMuncher: Game {
    // MARK: Palette (very dark background, light actors, mid-dark walls)
    private static let pal = Palette.make([
        0x080818, // 0 background
        0x3050D8, // 1 wall edge
        0x101050, // 2 wall fill
        0xFFE8B8, // 3 dot
        0xFFE040, // 4 muncher
        0xF080C0, // 5 ghost door
        0xFF6060, // 6 chaser (red)
        0xFFA0D8, // 7 ambusher (pink)
        0x60F0A0, // 8 wanderer (green)
        0xFFB040, // 9 patroller (orange)
        0x2850F0, // 10 frightened
        0xF8F8F8, // 11 white
        0x2040C0, // 12 pupil
        0xE02828, // 13 fruit red
        0x40C040, // 14 leaf
        0xF8D030  // 15 gold
    ])
    override var palette: [UInt16] { return MazeMuncher.pal }

    // # wall, . dot, o power pellet, - ghost door, H ghost house, space empty
    private static let layout: [String] = [
        "###################",
        "#o.......#.......o#",
        "#.##.###.#.###.##.#",
        "#.................#",
        "#.##.#.#####.#.##.#",
        "#....#.......#....#",
        "####.#.##-##.#.####",
        "      .#HHH#.      ",
        "####.#.#####.#.####",
        "#....#.......#....#",
        "#.##.#.##.##.#.##.#",
        "#o...............o#",
        "#.##.###.#.###.##.#",
        "#.................#",
        "###################"
    ]

    private static let ghostA = Sprite([
        "..6666..",
        ".666666.",
        "66666666",
        "66666666",
        "66666666",
        "66666666",
        "66666666",
        "6.66.66."
    ])
    private static let ghostB = Sprite([
        "..6666..",
        ".666666.",
        "66666666",
        "66666666",
        "66666666",
        "66666666",
        "66666666",
        ".66.66.6"
    ])
    private static let ghostSprites: [[Sprite]] = {
        var out: [[Sprite]] = []
        let colors: [Int] = [6, 7, 8, 9]
        for col in colors {
            out.append([MazeMuncher.ghostA.recolored(6, col), MazeMuncher.ghostB.recolored(6, col)])
        }
        return out
    }()
    private static let frightSprites: [[Sprite]] = {
        var out: [[Sprite]] = []
        let colors: [Int] = [10, 11]
        for col in colors {
            out.append([MazeMuncher.ghostA.recolored(6, col), MazeMuncher.ghostB.recolored(6, col)])
        }
        return out
    }()
    private static let waypoints: [(Int, Int)] = [(1, 13), (1, 3), (17, 3), (17, 13)]
    private static let fruitColors: [Int] = [13, 9, 8, 7, 15]

    // MARK: Types
    private enum Mode { case title, ready, playing, paused, freeze, dying, clear, over }
    private enum GState { case house, leaving, normal, frightened, eaten }

    private struct Actor {
        var x: Int
        var y: Int
        var dir: Int
        var acc: Int
    }

    private struct Ghost {
        var a: Actor
        var kind: Int
        var state: GState
        var release: Int
        var patrolIdx: Int
        var flip: Bool
    }

    // MARK: State
    private let cols = 19
    private let rows = 15
    private let dxs: [Int] = [0, 1, 0, -1]
    private let dys: [Int] = [-1, 0, 1, 0]

    private var mode: Mode = .title
    private var tiles = [UInt8](repeating: 1, count: 285)
    private var pac = Actor(x: 72, y: 88, dir: 3, acc: 0)
    private var want = 3
    private var pacAnim = 0
    private var ghosts: [Ghost] = []
    private var dotsLeft = 0
    private var dotsEaten = 0
    private var scatter = true
    private var modeTimer = 420
    private var frightTimer = 0
    private var chain = 0
    private var fruitActive = false
    private var fruitTimer = 0
    private var level = 1
    private var lives = 3
    private var points = 0
    private var best = 0
    private var nextLife = 5000
    private var readyTimer = 0
    private var freezeTimer = 0
    private var deathTimer = 0
    private var clearTimer = 0
    private var overDelay = 0
    private var popText = ""
    private var popX = 0
    private var popY = 0
    private var popTimer = 0
    private var tick = 0
    private var rng = Rng()

    override var score: Int { return points }

    override func start() {
        playMusic(Tunes.tense)
        buildMaze()
        resetActors()
    }

    // MARK: Setup

    private func buildMaze() {
        dotsLeft = 0
        dotsEaten = 0
        for y in 0..<rows {
            var rowChars: [Character] = []
            if y < MazeMuncher.layout.count { rowChars = Array(MazeMuncher.layout[y]) }
            for x in 0..<cols {
                var t: UInt8 = 1
                if x < rowChars.count {
                    switch rowChars[x] {
                    case "#": t = 1
                    case ".":
                        t = 2
                        dotsLeft += 1
                    case "o":
                        t = 3
                        dotsLeft += 1
                    case "-": t = 4
                    case "H": t = 5
                    default: t = 0
                    }
                }
                tiles[y * cols + x] = t
            }
        }
    }

    private func scatterLen() -> Int { return max(180, 420 - level * 40) }
    private func chaseLen() -> Int { return 1200 + level * 60 }

    private func resetActors() {
        pac = Actor(x: 72, y: 88, dir: 3, acc: 0)
        want = 3
        pacAnim = 0
        let lv = min(level, 6)
        ghosts = [
            Ghost(a: Actor(x: 72, y: 40, dir: 3, acc: 0), kind: 0, state: .normal, release: 0, patrolIdx: 0, flip: false),
            Ghost(a: Actor(x: 72, y: 56, dir: 0, acc: 0), kind: 1, state: .house, release: max(0, 70 - lv * 10), patrolIdx: 0, flip: false),
            Ghost(a: Actor(x: 64, y: 56, dir: 1, acc: 0), kind: 2, state: .house, release: max(0, 220 - lv * 25), patrolIdx: 0, flip: false),
            Ghost(a: Actor(x: 80, y: 56, dir: 3, acc: 0), kind: 3, state: .house, release: max(0, 380 - lv * 40), patrolIdx: 0, flip: false)
        ]
        scatter = true
        modeTimer = scatterLen()
        frightTimer = 0
        chain = 0
        fruitActive = false
        popTimer = 0
    }

    private func newGame() {
        level = 1
        lives = 3
        points = 0
        nextLife = 5000
        buildMaze()
        resetActors()
        mode = .ready
        readyTimer = 120
        playMusic(Tunes.tense)
        play(.confirm)
    }

    private func nextLevel() {
        level += 1
        buildMaze()
        resetActors()
        mode = .ready
        readyTimer = 100
    }

    private func addPoints(_ n: Int) {
        points += n
        if points >= nextLife {
            nextLife += 8000
            if lives < 6 { lives += 1 }
            play(.powerup)
        }
    }

    // MARK: Tile helpers

    private func tileAt(_ tx: Int, _ ty: Int) -> UInt8 {
        if ty < 0 || ty >= rows { return 1 }
        let x = ((tx % cols) + cols) % cols
        return tiles[ty * cols + x]
    }

    private func canWalk(_ tx: Int, _ ty: Int, _ passHouse: Bool) -> Bool {
        let t = tileAt(tx, ty)
        if t == 1 { return false }
        if t == 4 || t == 5 { return passHouse }
        return true
    }

    private func wallAt(_ tx: Int, _ ty: Int) -> Bool {
        if tx < 0 || ty < 0 || tx >= cols || ty >= rows { return true }
        return tiles[ty * cols + tx] == 1
    }

    // MARK: Update

    override func update(_ input: InputState) {
        tick = (tick + 1) % 1_000_000
        switch mode {
        case .title:
            if input.aPressed || input.startPressed { newGame() }
        case .ready:
            readyTimer -= 1
            if readyTimer <= 0 { mode = .playing }
        case .playing:
            updatePlaying(input)
        case .paused:
            if input.startPressed {
                mode = .playing
                play(.pause)
            }
        case .freeze:
            freezeTimer -= 1
            if popTimer > 0 { popTimer -= 1 }
            if freezeTimer <= 0 { mode = .playing }
        case .dying:
            deathTimer -= 1
            if deathTimer <= 0 { afterDeath() }
        case .clear:
            clearTimer -= 1
            if clearTimer <= 0 { nextLevel() }
        case .over:
            if overDelay > 0 {
                overDelay -= 1
            } else if input.aPressed || input.startPressed {
                newGame()
            }
        }
    }

    private func readInput(_ input: InputState) {
        if input.upPressed { want = 0 }
        else if input.rightPressed { want = 1 }
        else if input.downPressed { want = 2 }
        else if input.leftPressed { want = 3 }
        else if input.up { want = 0 }
        else if input.right { want = 1 }
        else if input.down { want = 2 }
        else if input.left { want = 3 }
    }

    private func updatePlaying(_ input: InputState) {
        if input.startPressed {
            mode = .paused
            play(.pause)
            return
        }
        readInput(input)

        if frightTimer > 0 {
            frightTimer -= 1
            if frightTimer == 0 { endFright() }
        } else {
            modeTimer -= 1
            if modeTimer <= 0 {
                scatter = !scatter
                modeTimer = scatter ? scatterLen() : chaseLen()
                for i in 0..<ghosts.count {
                    if ghosts[i].state == .normal { ghosts[i].flip = true }
                }
            }
        }
        if popTimer > 0 { popTimer -= 1 }
        if fruitActive {
            fruitTimer -= 1
            if fruitTimer <= 0 { fruitActive = false }
        }

        pacStep()
        if mode != .playing { return }
        moveGhosts()
        checkCollisions()
    }

    private func endFright() {
        for i in 0..<ghosts.count {
            if ghosts[i].state == .frightened { ghosts[i].state = .normal }
        }
    }

    private func powerUp() {
        var t = 480 - (level - 1) * 50
        if t < 150 { t = 150 }
        frightTimer = t
        chain = 0
        for i in 0..<ghosts.count {
            if ghosts[i].state == .normal {
                ghosts[i].state = .frightened
                ghosts[i].flip = true
            }
        }
        play(.powerup)
    }

    private func pacStep() {
        if want == (pac.dir + 2) % 4 { pac.dir = want }
        if pac.x % 8 == 0 && pac.y % 8 == 0 {
            let tx = pac.x / 8
            let ty = pac.y / 8
            if canWalk(tx + dxs[want], ty + dys[want], false) { pac.dir = want }
            if !canWalk(tx + dxs[pac.dir], ty + dys[pac.dir], false) { return }
        }
        pacAnim += 1
        pac.x += dxs[pac.dir]
        pac.y += dys[pac.dir]
        if pac.x <= -8 { pac.x += cols * 8 }
        if pac.x >= cols * 8 { pac.x -= cols * 8 }
        eatAt()
    }

    private func eatAt() {
        let cx = pac.x + 4
        if cx < 0 || cx >= cols * 8 { return }
        let tx = cx / 8
        let ty = (pac.y + 4) / 8
        if ty < 0 || ty >= rows { return }
        if abs(pac.x - tx * 8) > 3 || abs(pac.y - ty * 8) > 3 { return }
        let idx = ty * cols + tx
        let t = tiles[idx]
        if t != 2 && t != 3 { return }
        tiles[idx] = 0
        dotsLeft -= 1
        dotsEaten += 1
        if t == 2 {
            addPoints(10)
            play(.step)
        } else {
            addPoints(50)
            powerUp()
        }
        if (dotsEaten == 40 || dotsEaten == 90) && !fruitActive {
            fruitActive = true
            fruitTimer = 600
        }
        if dotsLeft <= 0 {
            mode = .clear
            clearTimer = 110
            play(.win)
        }
    }

    private func moveGhosts() {
        for i in 0..<ghosts.count {
            var spd = 0
            switch ghosts[i].state {
            case .house:
                ghosts[i].release -= 1
                if ghosts[i].release <= 0 { releaseGhost(i) }
                continue
            case .leaving:
                spd = 12
            case .normal:
                spd = min(18, 12 + level)
            case .frightened:
                spd = 8
            case .eaten:
                spd = 32
            }
            ghosts[i].a.acc += spd
            var n = 0
            while ghosts[i].a.acc >= 16 && n < 4 {
                ghosts[i].a.acc -= 16
                ghostStep(i)
                n += 1
            }
        }
    }

    private func releaseGhost(_ i: Int) {
        let tx = ghosts[i].a.x / 8
        ghosts[i].state = .leaving
        ghosts[i].a.acc = 0
        if tx < 9 { ghosts[i].a.dir = 1 }
        else if tx > 9 { ghosts[i].a.dir = 3 }
        else { ghosts[i].a.dir = 0 }
    }

    private func ghostStep(_ i: Int) {
        var g = ghosts[i]
        if g.a.x % 8 == 0 && g.a.y % 8 == 0 {
            let tx = g.a.x / 8
            let ty = g.a.y / 8
            var skip = false
            if g.state == .leaving && ty <= 5 { g.state = .normal }
            if g.state == .eaten && tx == 9 && ty == 7 {
                g.state = .leaving
                g.a.dir = 0
                skip = true
            }
            if (g.state == .normal || g.state == .frightened) && g.flip {
                g.flip = false
                let r = (g.a.dir + 2) % 4
                if canWalk(tx + dxs[r], ty + dys[r], false) {
                    g.a.dir = r
                    skip = true
                }
            }
            if !skip { chooseDir(&g, tx, ty) }
            let nd = clamp(g.a.dir, 0, 3)
            g.a.dir = nd
            let pass = (g.state == .leaving || g.state == .eaten)
            if !canWalk(tx + dxs[nd], ty + dys[nd], pass) {
                ghosts[i] = g
                return
            }
        }
        g.a.x += dxs[g.a.dir]
        g.a.y += dys[g.a.dir]
        if g.a.x <= -8 { g.a.x += cols * 8 }
        if g.a.x >= cols * 8 { g.a.x -= cols * 8 }
        ghosts[i] = g
    }

    private func chooseDir(_ g: inout Ghost, _ tx: Int, _ ty: Int) {
        let pass = (g.state == .leaving || g.state == .eaten)
        let rev = (g.a.dir + 2) % 4
        var cands: [Int] = []
        let order: [Int] = [0, 3, 2, 1]
        for d in order {
            if d == rev { continue }
            if canWalk(tx + dxs[d], ty + dys[d], pass) { cands.append(d) }
        }
        if cands.isEmpty {
            if canWalk(tx + dxs[rev], ty + dys[rev], pass) {
                cands.append(rev)
            } else {
                return
            }
        }
        if cands.count == 1 {
            g.a.dir = cands[0]
            return
        }
        var random = false
        if g.state == .frightened { random = true }
        else if g.state == .normal && g.kind == 2 && rng.chance(55) { random = true }
        if random {
            g.a.dir = cands[rng.int(cands.count)]
            return
        }
        let tgt = targetTile(&g, tx, ty)
        var bestD = Int.max
        var bestDir = cands[0]
        for d in cands {
            let nx = tx + dxs[d]
            let ny = ty + dys[d]
            let dd = (nx - tgt.0) * (nx - tgt.0) + (ny - tgt.1) * (ny - tgt.1)
            if dd < bestD {
                bestD = dd
                bestDir = d
            }
        }
        g.a.dir = bestDir
    }

    private func targetTile(_ g: inout Ghost, _ tx: Int, _ ty: Int) -> (Int, Int) {
        if g.state == .leaving { return (9, 3) }
        if g.state == .eaten { return (9, 7) }
        let ptx = clamp((pac.x + 4) / 8, 0, cols - 1)
        let pty = clamp((pac.y + 4) / 8, 0, rows - 1)
        switch g.kind {
        case 0:
            if scatter { return (17, 1) }
            return (ptx, pty)
        case 1:
            if scatter { return (1, 1) }
            let pd = clamp(pac.dir, 0, 3)
            return (ptx + dxs[pd] * 4, pty + dys[pd] * 4)
        case 2:
            if scatter { return (17, 13) }
            return (ptx, pty)
        default:
            let wps = MazeMuncher.waypoints
            var idx = clamp(g.patrolIdx, 0, wps.count - 1)
            let wp = wps[idx]
            if abs(tx - wp.0) + abs(ty - wp.1) <= 2 {
                idx = (idx + 1) % wps.count
                g.patrolIdx = idx
            }
            if abs(tx - ptx) + abs(ty - pty) < 6 { return (ptx, pty) }
            return wps[idx]
        }
    }

    private func checkCollisions() {
        for i in 0..<ghosts.count {
            let g = ghosts[i]
            if g.state == .house || g.state == .eaten { continue }
            if abs(g.a.x - pac.x) <= 5 && abs(g.a.y - pac.y) <= 5 {
                if g.state == .frightened {
                    eatGhost(i)
                } else {
                    killPac()
                }
                return
            }
        }
        if fruitActive && abs(pac.x - 72) <= 4 && abs(pac.y - 72) <= 4 {
            fruitActive = false
            let fp = fruitPoints()
            addPoints(fp)
            popText = String(fp)
            popX = 72
            popY = 72
            popTimer = 50
            play(.coin)
        }
    }

    private func fruitPoints() -> Int {
        let table: [Int] = [100, 300, 500, 700, 1000]
        let idx = clamp(level - 1, 0, table.count - 1)
        return table[idx]
    }

    private func eatGhost(_ i: Int) {
        ghosts[i].state = .eaten
        chain += 1
        let shift = min(chain, 4) - 1
        let pts = 200 * (1 << shift)
        addPoints(pts)
        popText = String(pts)
        popX = ghosts[i].a.x
        popY = ghosts[i].a.y
        popTimer = 40
        mode = .freeze
        freezeTimer = 30
        play(.stomp)
    }

    private func killPac() {
        mode = .dying
        deathTimer = 90
        lives -= 1
        playMusic(nil)
        play(.death)
    }

    private func afterDeath() {
        if lives <= 0 {
            mode = .over
            overDelay = 40
            if points > best { best = points }
            play(.lose)
        } else {
            resetActors()
            mode = .ready
            readyTimer = 90
            playMusic(Tunes.tense)
        }
    }

    // MARK: Draw

    override func draw(_ c: Canvas) {
        c.clear(0)
        c.cameraX = -4
        c.cameraY = -16
        drawMaze(c)
        if fruitActive { drawFruit(c, 72, 72, level) }
        if mode != .dying {
            for g in ghosts { drawGhost(c, g) }
        }
        drawPacman(c)
        if popTimer > 0 {
            let w = c.textWidth(popText)
            c.outlinedText(popText, popX + 4 - w / 2, popY + 1, 11, outline: 0)
        }
        c.cameraX = 0
        c.cameraY = 0
        drawHud(c)
        drawOverlay(c)
    }

    private func drawMaze(_ c: Canvas) {
        let flash = (mode == .clear) && ((clearTimer / 8) % 2 == 0)
        let edge = flash ? 11 : 1
        for ty in 0..<rows {
            for tx in 0..<cols {
                let t = tiles[ty * cols + tx]
                let x = tx * 8
                let y = ty * 8
                switch t {
                case 1:
                    c.fillRect(x, y, 8, 8, 2)
                    if !wallAt(tx, ty - 1) && ty > 0 { c.fillRect(x, y, 8, 1, edge) }
                    if !wallAt(tx, ty + 1) && ty < rows - 1 { c.fillRect(x, y + 7, 8, 1, edge) }
                    if !wallAt(tx - 1, ty) && tx > 0 { c.fillRect(x, y, 1, 8, edge) }
                    if !wallAt(tx + 1, ty) && tx < cols - 1 { c.fillRect(x + 7, y, 1, 8, edge) }
                case 2:
                    c.fillRect(x + 3, y + 3, 2, 2, 3)
                case 3:
                    if (tick / 12) % 2 == 0 { c.fillCircle(x + 4, y + 4, 2, 3) }
                case 4:
                    c.fillRect(x, y + 3, 8, 2, 5)
                default:
                    break
                }
            }
        }
    }

    private func drawEyes(_ c: Canvas, _ x: Int, _ y: Int, _ dir: Int) {
        let d = clamp(dir, 0, 3)
        c.fillRect(x + 1, y + 2, 2, 2, 11)
        c.fillRect(x + 5, y + 2, 2, 2, 11)
        let px = dxs[d] > 0 ? 1 : 0
        let py = dys[d] > 0 ? 1 : 0
        c.setPixel(x + 1 + px, y + 2 + py, 12)
        c.setPixel(x + 5 + px, y + 2 + py, 12)
    }

    private func drawNormalGhost(_ c: Canvas, _ kind: Int, _ x: Int, _ y: Int, _ dir: Int) {
        let k = clamp(kind, 0, 3)
        let frame = (tick / 8) % 2
        c.draw(MazeMuncher.ghostSprites[k][frame], x, y)
        drawEyes(c, x, y, dir)
    }

    private func drawGhost(_ c: Canvas, _ g: Ghost) {
        let x = g.a.x
        var y = g.a.y
        if g.state == .house { y += (tick / 12) % 2 }
        switch g.state {
        case .frightened:
            let flashing = frightTimer < 120 && (frightTimer / 8) % 2 == 0
            let body = flashing ? 1 : 0
            let face = flashing ? 10 : 11
            let frame = (tick / 8) % 2
            c.draw(MazeMuncher.frightSprites[body][frame], x, y)
            c.setPixel(x + 2, y + 3, face)
            c.setPixel(x + 5, y + 3, face)
            c.setPixel(x + 1, y + 5, face)
            c.setPixel(x + 3, y + 5, face)
            c.setPixel(x + 4, y + 5, face)
            c.setPixel(x + 6, y + 5, face)
        case .eaten:
            drawEyes(c, x, y, g.a.dir)
        case .house, .leaving, .normal:
            drawNormalGhost(c, g.kind, x, y, g.a.dir)
        }
    }

    private func drawPac(_ c: Canvas, _ x: Int, _ y: Int, _ dir: Int, _ mouth: Int) {
        let d = clamp(dir, 0, 3)
        let cx = x + 4
        let cy = y + 4
        c.fillCircle(cx, cy, 3, 4)
        if mouth <= 0 { return }
        let ddx = dxs[d]
        let ddy = dys[d]
        let perpX = abs(ddy)
        let perpY = abs(ddx)
        for k in 1...3 {
            let half = (k * mouth) / 3
            for w in -half...half {
                c.setPixel(cx + ddx * k + perpX * w, cy + ddy * k + perpY * w, 0)
            }
        }
    }

    private func drawPacman(_ c: Canvas) {
        if mode == .title || mode == .over { return }
        if mode == .dying {
            let t = clamp(deathTimer, 0, 90)
            let r = (3 * t) / 90
            if r >= 1 {
                c.fillCircle(pac.x + 4, pac.y + 4, r, 4)
            } else if t > 0 && (t / 4) % 2 == 0 {
                c.setPixel(pac.x + 4, pac.y + 4, 4)
            }
            return
        }
        let m = (pacAnim / 3) % 6
        let mouth = m <= 3 ? m : 6 - m
        drawPac(c, pac.x, pac.y, pac.dir, mouth)
    }

    private func drawFruit(_ c: Canvas, _ x: Int, _ y: Int, _ lv: Int) {
        let idx = clamp(lv - 1, 0, MazeMuncher.fruitColors.count - 1)
        let col = MazeMuncher.fruitColors[idx]
        c.fillCircle(x + 4, y + 5, 3, col)
        c.setPixel(x + 3, y + 4, 11)
        c.line(x + 4, y + 2, x + 6, y, 14)
        c.fillRect(x + 6, y, 2, 1, 14)
    }

    private func drawHud(_ c: Canvas) {
        c.text("SCORE " + zeroPad(points, 5), 4, 2, 11)
        let hi = "HI " + zeroPad(max(best, points), 5)
        c.text(hi, 156 - c.textWidth(hi), 2, 15)
        c.text("LEVEL " + String(level), 4, 9, 5)
        if mode != .title {
            let n = clamp(lives, 0, 6)
            for i in 0..<n {
                drawPac(c, 4 + i * 10, 136, 3, 2)
            }
            drawFruit(c, 148, 135, level)
        }
    }

    private func panel(_ c: Canvas, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        c.fillRect(x, y, w, h, 0)
        c.strokeRect(x, y, w, h, 1)
        c.strokeRect(x + 2, y + 2, w - 4, h - 4, 2)
    }

    private func drawOverlay(_ c: Canvas) {
        switch mode {
        case .title:
            panel(c, 14, 30, 132, 88)
            c.textCentered("MAZE", y: 38, 4, scale: 2)
            c.textCentered("MUNCHER", y: 50, 4, scale: 2)
            c.textCentered("EAT ALL THE DOTS", y: 68, 11)
            if (tick / 30) % 2 == 0 { c.textCentered("PRESS A", y: 80, 15) }
            // Parade: muncher chased by ghosts
            let off = (tick / 2) % 220
            let px = off - 40
            drawPac(c, px, 96, 1, ((tick / 4) % 4))
            for k in 0..<4 {
                drawNormalGhost(c, k, px - 14 - k * 11, 96, 1)
            }
        case .paused:
            panel(c, 40, 56, 80, 32)
            c.textCentered("PAUSED", y: 66, 15, scale: 2)
        case .ready:
            let s = "READY!"
            c.outlinedText(s, (160 - c.textWidth(s)) / 2, 90, 15, outline: 0)
        case .over:
            panel(c, 24, 44, 112, 64)
            c.textCentered("GAME OVER", y: 52, 6, scale: 2)
            c.textCentered("SCORE " + String(points), y: 72, 11)
            c.textCentered("BEST " + String(best), y: 82, 15)
            if overDelay <= 0 && (tick / 30) % 2 == 0 { c.textCentered("A: AGAIN", y: 94, 11) }
        case .playing, .freeze, .dying, .clear:
            break
        }
    }
}

extension Cartridge {
    static let mazeMuncher = Cartridge(
        id: "mazemuncher", title: "MAZE MUNCHER", genre: "Arcade",
        blurb: "Gobble every dot while four ghosts hunt you, each with a different brain. Grab a power pellet and turn the tables.",
        controls: "D-PAD steers, START pauses.",
        era: .gbc, labelTop: 0x4A5CE0, labelBottom: 0x14143C, factory: { MazeMuncher() })
}
