#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// A side-scrolling platformer in the classic handheld mould: run, jump, stomp, bump blocks, grab the mushroom, reach the flag.
final class CappyLand: Game {
    // MARK: - Palette (shared layout, three themes)

    private static let base: [UInt32] = [
        0xA8E0F8, 0xFFFFFF, 0x8A5A2B, 0x58B030, 0xC87038, 0x602810, 0xF0B820, 0x884000,
        0x40D060, 0x108030, 0xE02020, 0xF8C898, 0x182890, 0x603010, 0xA05020, 0x401800,
        0x20B848, 0xF8E060, 0xFFFFFF, 0x101018, 0xE0A000, 0x905000, 0xD83030, 0xF8E8C8,
        0x30C050, 0x101018, 0x38A038, 0x78C8E8
    ]

    private static func makePalette(theme: Int) -> [UInt16] {
        var colors = base
        if theme == 1 {
            colors[0] = 0x101830; colors[1] = 0x203050; colors[2] = 0x405070; colors[3] = 0x8098B8
            colors[4] = 0x3858A0; colors[5] = 0x0C1028; colors[25] = 0xF8F8F8; colors[26] = 0x287070
            colors[27] = 0x182848
        } else if theme == 2 {
            colors[0] = 0x181018; colors[1] = 0x302030; colors[2] = 0x585860; colors[3] = 0x9898A8
            colors[4] = 0x884030; colors[5] = 0x200808; colors[25] = 0xF8F8F8; colors[26] = 0x703030
            colors[27] = 0x281828
        }
        return Palette.make(colors)
    }

    private static let palettes: [[UInt16]] = [makePalette(theme: 0), makePalette(theme: 1), makePalette(theme: 2)]

    override var palette: [UInt16] {
        return CappyLand.palettes[min(max(theme, 0), 2)]
    }

    // MARK: - Art

    private static let bodyRows: [String] = [
        "....aaaaa...",
        "...aaaaaaaaa",
        "...dddbbjb..",
        "..dbdbbbjbbb",
        "..dbddbbbjbb",
        "..ddbbbbjjjj",
        "....bbbbbbb.",
        "...aacaaa...",
        "..aaacaacaaa",
        ".aaaaccccaaa",
        ".bbaccicccbb",
        ".bbbcccccbbb",
        "..bcccccccb."
    ]
    private static let legsStand: [String] = ["...ccc..ccc.", "..ddd....ddd", ".dddd....dddd"]
    private static let legsRun1: [String] = ["....cccccc..", "...dddd.ddd.", "..dddd...ddd"]
    private static let legsRun2: [String] = ["...cc...ccc.", "..ddd..dddd.", ".ddd.....ddd"]
    private static let legsJump: [String] = ["..cccc.cccc.", ".dddd...dddd", ".ddd.....ddd"]

    private static let heroStand = Sprite(bodyRows + legsStand)
    private static let heroRun1 = Sprite(bodyRows + legsRun1)
    private static let heroRun2 = Sprite(bodyRows + legsRun2)
    private static let heroJump = Sprite(bodyRows + legsJump)

    private static let walker = Sprite([
        "....eeee....",
        "...eeeeee...",
        "..eeeeeeee..",
        ".eeeeeeeeee.",
        ".eiijeejiie.",
        ".eiijeejiie.",
        ".eeeeeeeeee.",
        "..eeiiiiee..",
        "...iiiiii...",
        "..ffffffff..",
        ".ffffffffff.",
        ".fff....fff."
    ])
    private static let walkerSquash = Sprite([
        "..eeeeeeee..",
        ".eiijeejiie.",
        "ffffffffffff"
    ])
    private static let turtle = Sprite([
        "....hhh.....",
        "...hhhhh....",
        "...hjihh....",
        "...hhhhhh...",
        "....hhh.....",
        "..ffgggggf..",
        ".fgggfgggff.",
        ".ggfgggfggg.",
        ".gggggggggg.",
        ".fggfggfggf.",
        "..ffggggff..",
        "...hh..hh...",
        "..hhh..hhh.."
    ])
    private static let shell = Sprite([
        "...ffffff...",
        "..fggggggf..",
        ".fgggfggggf.",
        ".ggfgggfggg.",
        ".gggggggggg.",
        ".fggfggfggf.",
        "..ffffffff.."
    ])
    private static let mushroom = Sprite([
        "....mmmm....",
        "..mmiimmmm..",
        ".mmiimmmiim.",
        ".mmmmmmmiim.",
        "mmmmiimmmmmm",
        "mmmiiimmmmmm",
        "jjnnnnnnnjjj",
        "..nnjnnjnn..",
        "..nnnnnnnn..",
        "...nnnnnn..."
    ])

    // MARK: - Level data

    private struct LevelData {
        var width: Int
        var grid: [[Character]]
        var theme: Int
        var name: String
    }

    private final class Builder {
        var w: Int
        var g: [[Character]]

        init(_ width: Int) {
            w = width
            g = [[Character]](repeating: [Character](repeating: " ", count: width), count: 9)
        }

        func set(_ c: Int, _ r: Int, _ ch: Character) {
            if c >= 0 && c < w && r >= 0 && r < 9 { g[r][c] = ch }
        }

        func ground(_ from: Int, _ to: Int) {
            if from > to { return }
            for c in from...to {
                set(c, 7, "#")
                set(c, 8, "#")
            }
        }

        func bricks(_ c: Int, _ r: Int, _ n: Int) {
            if n <= 0 { return }
            for i in 0..<n { set(c + i, r, "B") }
        }

        func pipe(_ c: Int, _ h: Int) {
            if h <= 0 { return }
            for i in 0..<h {
                let row = 6 - i
                let top = (i == h - 1)
                set(c, row, top ? "p" : "l")
                set(c + 1, row, top ? "q" : "r")
            }
        }

        func stairsUp(_ c: Int, _ n: Int) {
            if n <= 0 { return }
            for i in 0..<n {
                for j in 0...i { set(c + i, 6 - j, "H") }
            }
        }

        func stairsDown(_ c: Int, _ n: Int) {
            if n <= 0 { return }
            for i in 0..<n {
                let height = n - i
                for j in 0..<height { set(c + i, 6 - j, "H") }
            }
        }

        func coins(_ c: Int, _ r: Int, _ n: Int) {
            if n <= 0 { return }
            for i in 0..<n { set(c + i, r, "o") }
        }

        func enemy(_ c: Int, _ ch: Character, row: Int = 6) { set(c, row, ch) }

        func flag(_ c: Int) {
            for r in 1...5 { set(c, r, "F") }
            set(c, 6, "H")
        }

        func ceiling() {
            for c in 0..<w {
                set(c, 0, "#")
                set(c, 1, "#")
            }
        }

        func data(theme: Int, name: String) -> LevelData {
            return LevelData(width: w, grid: g, theme: theme, name: name)
        }
    }

    private static func level1() -> LevelData {
        let b = Builder(130)
        b.ground(0, 33); b.ground(36, 64); b.ground(67, 91); b.ground(95, 129)
        b.set(9, 4, "?"); b.set(12, 4, "B"); b.set(13, 4, "P"); b.set(14, 4, "B")
        b.pipe(19, 2); b.enemy(24, "e"); b.pipe(27, 3); b.enemy(31, "e")
        b.coins(33, 3, 4)
        b.bricks(40, 4, 3); b.set(41, 4, "?")
        b.enemy(44, "e"); b.enemy(47, "k"); b.pipe(52, 2)
        b.bricks(56, 3, 5); b.set(58, 3, "?"); b.coins(56, 2, 5)
        b.enemy(58, "e"); b.enemy(61, "e")
        b.stairsUp(70, 4); b.enemy(78, "e"); b.set(80, 4, "P"); b.bricks(83, 4, 3)
        b.enemy(82, "k"); b.enemy(86, "e"); b.coins(92, 4, 3)
        b.enemy(100, "e"); b.enemy(104, "e"); b.enemy(108, "k")
        b.set(100, 4, "?"); b.bricks(101, 4, 2)
        b.stairsUp(112, 6)
        b.flag(123)
        return b.data(theme: 0, name: "1-1")
    }

    private static func level2() -> LevelData {
        let b = Builder(140)
        b.ceiling()
        b.ground(0, 14); b.ground(18, 30); b.ground(34, 36); b.ground(39, 55); b.ground(58, 60)
        b.ground(63, 80); b.ground(83, 85); b.ground(88, 110); b.ground(113, 139)
        b.set(8, 4, "?"); b.enemy(11, "e"); b.pipe(22, 2); b.enemy(27, "e")
        b.coins(15, 4, 3); b.coins(31, 4, 3)
        b.bricks(42, 4, 4); b.set(43, 4, "P"); b.enemy(46, "k"); b.enemy(50, "e")
        b.coins(56, 4, 2); b.enemy(66, "e"); b.enemy(69, "k"); b.pipe(72, 3)
        b.bricks(74, 4, 3); b.set(75, 4, "?"); b.enemy(77, "e")
        b.coins(81, 4, 2); b.enemy(91, "e"); b.enemy(94, "e"); b.enemy(98, "k")
        b.set(100, 3, "P"); b.coins(103, 4, 4); b.enemy(106, "e")
        b.coins(111, 4, 2); b.enemy(118, "e"); b.enemy(122, "k"); b.enemy(125, "e")
        b.stairsUp(128, 5)
        b.flag(136)
        return b.data(theme: 1, name: "1-2")
    }

    private static func level3() -> LevelData {
        let b = Builder(150)
        b.ground(0, 12); b.ground(16, 24); b.ground(28, 30); b.ground(34, 44); b.ground(48, 50)
        b.ground(54, 66); b.ground(70, 72); b.ground(76, 95); b.ground(99, 101); b.ground(105, 125)
        b.ground(129, 149)
        b.set(6, 4, "?"); b.enemy(10, "e"); b.enemy(20, "e"); b.pipe(22, 2)
        b.coins(13, 4, 3); b.coins(25, 4, 3); b.coins(31, 4, 3)
        b.enemy(37, "k"); b.enemy(41, "e"); b.set(40, 4, "P"); b.coins(45, 4, 3)
        b.coins(51, 4, 3); b.enemy(57, "e"); b.enemy(60, "k"); b.enemy(63, "e")
        b.coins(67, 4, 3); b.coins(73, 4, 3); b.enemy(79, "e"); b.enemy(82, "e")
        b.bricks(84, 4, 4); b.set(85, 4, "?"); b.enemy(90, "k"); b.enemy(93, "e")
        b.coins(96, 4, 3); b.coins(102, 4, 3); b.enemy(108, "e"); b.enemy(111, "k")
        b.enemy(115, "e"); b.enemy(119, "e"); b.set(112, 3, "P")
        b.coins(126, 4, 3); b.stairsUp(132, 6); b.stairsDown(138, 0)
        b.flag(146)
        return b.data(theme: 2, name: "1-3")
    }

    private static let levels: [LevelData] = [level1(), level2(), level3()]

    // MARK: - State

    private enum Mode { case title, intro, play, dying, clear, over, win }

    private struct Body {
        var x: Float
        var y: Float
        var w: Float
        var h: Float
        var vx: Float = 0
        var vy: Float = 0
        var onGround: Bool = false
    }

    private struct YHit {
        var landed = false
        var hitHead = false
        var headCol = 0
        var headRow = 0
    }

    private struct Enemy {
        var kind: Int
        var state: Int
        var b: Body
        var dir: Float = -1
        var timer: Int = 0
        var grace: Int = 0
        var active: Bool = false
        var removed: Bool = false
    }

    private struct Item {
        var b: Body
        var emerge: Int
        var dir: Float = 1
        var removed: Bool = false
    }

    private struct Particle {
        var x: Float
        var y: Float
        var vx: Float
        var vy: Float
        var life: Int
        var color: Int
    }

    private struct Pop {
        var x: Float
        var y: Float
        var vy: Float
        var life: Int
        var text: String
    }

    private struct Bump {
        var col: Int
        var row: Int
        var t: Int
    }

    private var mode: Mode = .title
    private var levelIndex = 0
    private var theme = 0
    private var levelName = "1-1"
    private var grid: [[Character]] = []
    private var levelWidth = 0
    private var hero = Body(x: 24, y: 96, w: 10, h: 16)
    private var big = false
    private var facing: Float = 1
    private var invuln = 0
    private var coyote = 0
    private var jumpBuffer = 0
    private var anim = 0
    private var camX: Float = 0
    private var enemies: [Enemy] = []
    private var items: [Item] = []
    private var particles: [Particle] = []
    private var pops: [Pop] = []
    private var bumps: [Bump] = []
    private var tick = 0
    private var introTimer = 0
    private var dyingTimer = 0
    private var clearTimer = 0
    private var flagSlide = false
    private var points = 0
    private var coinCount = 0
    private var lives = 3
    private var timeLeft = 400
    private var timeTick = 0

    override var score: Int { return points }

    override func start() {
        playMusic(Tunes.adventure)
    }

    // MARK: - Setup

    private func startGame() {
        lives = 3
        points = 0
        coinCount = 0
        levelIndex = 0
        big = false
        loadLevel(levelIndex)
        mode = .intro
        introTimer = 100
        play(.confirm)
    }

    private func loadLevel(_ index: Int) {
        let data = CappyLand.levels[min(max(index, 0), CappyLand.levels.count - 1)]
        grid = data.grid
        levelWidth = data.width
        theme = data.theme
        levelName = data.name
        enemies = []
        items = []
        particles = []
        pops = []
        bumps = []
        for r in 0..<9 {
            for c in 0..<levelWidth {
                let ch = grid[r][c]
                if ch == "e" {
                    enemies.append(Enemy(kind: 0, state: 0, b: Body(x: Float(c * 16 + 2), y: Float(r * 16 + 4), w: 12, h: 12)))
                    grid[r][c] = " "
                } else if ch == "k" {
                    enemies.append(Enemy(kind: 1, state: 0, b: Body(x: Float(c * 16 + 2), y: Float(r * 16 + 2), w: 12, h: 14)))
                    grid[r][c] = " "
                }
            }
        }
        resetHero()
        timeLeft = 400
        timeTick = 0
        flagSlide = false
        playMusic(theme == 0 ? Tunes.adventure : Tunes.tense)
    }

    private func resetHero() {
        hero = Body(x: 24, y: 96, w: 10, h: big ? 24 : 16)
        if big { hero.y = 88 }
        hero.vx = 0
        hero.vy = 0
        facing = 1
        invuln = 0
        coyote = 0
        jumpBuffer = 0
        camX = 0
    }

    // MARK: - Tiles and collision

    private func tile(_ col: Int, _ row: Int) -> Character {
        if col < 0 { return "#" }
        if col >= levelWidth { return "#" }
        if row < 0 || row >= 9 { return " " }
        return grid[row][col]
    }

    private func solid(_ ch: Character) -> Bool {
        switch ch {
        case "#", "B", "H", "?", "P", "u", "p", "q", "l", "r": return true
        default: return false
        }
    }

    private func isSolid(_ col: Int, _ row: Int) -> Bool {
        return solid(tile(col, row))
    }

    private func moveX(_ b: inout Body) -> Bool {
        b.x += b.vx
        let rowTop = Int(floor(b.y / 16))
        let rowBot = Int(floor((b.y + b.h - 0.01) / 16))
        if rowBot < rowTop { return false }
        if b.vx > 0 {
            let col = Int(floor((b.x + b.w) / 16))
            for r in rowTop...rowBot where isSolid(col, r) {
                b.x = Float(col * 16) - b.w
                b.vx = 0
                return true
            }
        } else if b.vx < 0 {
            let col = Int(floor(b.x / 16))
            for r in rowTop...rowBot where isSolid(col, r) {
                b.x = Float((col + 1) * 16)
                b.vx = 0
                return true
            }
        }
        return false
    }

    private func moveY(_ b: inout Body) -> YHit {
        var hit = YHit()
        b.y += b.vy
        let colL = Int(floor(b.x / 16))
        let colR = Int(floor((b.x + b.w - 0.01) / 16))
        b.onGround = false
        if colR < colL { return hit }
        if b.vy > 0 {
            let row = Int(floor((b.y + b.h) / 16))
            for c in colL...colR where isSolid(c, row) {
                b.y = Float(row * 16) - b.h
                b.vy = 0
                b.onGround = true
                hit.landed = true
                break
            }
        } else if b.vy < 0 {
            let row = Int(floor(b.y / 16))
            var bestCol = -1
            var bestOverlap: Float = -1
            for c in colL...colR where isSolid(c, row) {
                let left = max(b.x, Float(c * 16))
                let right = min(b.x + b.w, Float((c + 1) * 16))
                let overlap = right - left
                if overlap > bestOverlap {
                    bestOverlap = overlap
                    bestCol = c
                }
            }
            if bestCol >= 0 {
                b.y = Float((row + 1) * 16)
                b.vy = 0
                hit.hitHead = true
                hit.headCol = bestCol
                hit.headRow = row
            }
        }
        return hit
    }

    // MARK: - Update

    override func update(_ input: InputState) {
        tick += 1
        switch mode {
        case .title:
            if input.aPressed || input.startPressed { startGame() }
        case .intro:
            introTimer -= 1
            if introTimer <= 0 { mode = .play }
        case .play:
            updatePlay(input)
        case .dying:
            updateDying()
        case .clear:
            updateClear()
        case .over, .win:
            if input.aPressed || input.startPressed {
                mode = .title
                playMusic(Tunes.adventure)
            }
        }
    }

    private func updatePlay(_ input: InputState) {
        anim += 1
        if invuln > 0 { invuln -= 1 }

        timeTick += 1
        if timeTick >= 30 {
            timeTick = 0
            timeLeft -= 1
            if timeLeft <= 0 { killHero(); return }
        }

        // Horizontal control
        let running = input.b
        let maxSpeed: Float = running ? 2.2 : 1.4
        let accel: Float = hero.onGround ? (running ? 0.15 : 0.12) : 0.09
        if input.dx != 0 {
            let dir = Float(input.dx)
            facing = dir
            hero.vx += dir * accel
            if hero.vx > maxSpeed { hero.vx = max(maxSpeed, hero.vx - 0.08) }
            if hero.vx < -maxSpeed { hero.vx = min(-maxSpeed, hero.vx + 0.08) }
        } else {
            let friction: Float = hero.onGround ? 0.1 : 0.02
            if hero.vx > friction { hero.vx -= friction } else if hero.vx < -friction { hero.vx += friction } else { hero.vx = 0 }
        }

        // Jumping with a little buffer and coyote time
        if hero.onGround { coyote = 5 } else if coyote > 0 { coyote -= 1 }
        if input.aPressed { jumpBuffer = 6 } else if jumpBuffer > 0 { jumpBuffer -= 1 }
        if jumpBuffer > 0 && coyote > 0 {
            hero.vy = abs(hero.vx) > 1.6 ? -5.4 : -5.0
            hero.onGround = false
            coyote = 0
            jumpBuffer = 0
            play(.jump)
        }
        let gravity: Float = (hero.vy < 0 && input.a) ? 0.26 : 0.55
        hero.vy = min(hero.vy + gravity, 6.5)

        _ = moveX(&hero)
        if hero.x < camX {
            hero.x = camX
            if hero.vx < 0 { hero.vx = 0 }
        }
        let hit = moveY(&hero)
        if hit.hitHead { bumpBlock(hit.headCol, hit.headRow) }

        // Falling into a pit
        if hero.y > 160 {
            killHero()
            return
        }

        updateEnemies()
        updateItems()
        updateEffects()
        checkCoins()
        checkFlag()

        // Camera only scrolls forward
        let target = hero.x - 56
        if target > camX { camX = target }
        let maxCam = Float(levelWidth * 16 - 160)
        camX = min(max(camX, 0), max(0, maxCam))
    }

    private func updateEffects() {
        var i = 0
        while i < particles.count {
            particles[i].vy += 0.3
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].life -= 1
            if particles[i].life <= 0 || particles[i].y > 200 {
                particles.remove(at: i)
            } else {
                i += 1
            }
        }
        i = 0
        while i < pops.count {
            pops[i].y += pops[i].vy
            pops[i].vy += 0.12
            pops[i].life -= 1
            if pops[i].life <= 0 { pops.remove(at: i) } else { i += 1 }
        }
        i = 0
        while i < bumps.count {
            bumps[i].t += 1
            if bumps[i].t >= 12 { bumps.remove(at: i) } else { i += 1 }
        }
    }

    private func addPop(_ x: Float, _ y: Float, _ text: String) {
        pops.append(Pop(x: x, y: y, vy: -1.6, life: 30, text: text))
    }

    private func addPoints(_ n: Int, _ x: Float, _ y: Float) {
        points += n
        addPop(x, y, String(n))
    }

    // MARK: Blocks

    private func bumpBlock(_ col: Int, _ row: Int) {
        let ch = tile(col, row)
        let tileX = Float(col * 16)
        let tileY = Float(row * 16)
        switch ch {
        case "?":
            grid[row][col] = "u"
            bumps.append(Bump(col: col, row: row, t: 0))
            coinCount += 1
            points += 100
            addPop(tileX + 4, tileY - 8, "100")
            play(.coin)
        case "P":
            grid[row][col] = "u"
            bumps.append(Bump(col: col, row: row, t: 0))
            items.append(Item(b: Body(x: tileX + 2, y: tileY, w: 12, h: 10), emerge: 16))
            play(.pickup)
        case "B":
            if big {
                grid[row][col] = " "
                points += 50
                for k in 0..<4 {
                    let sx: Float = (k % 2 == 0) ? -1.4 : 1.4
                    let sy: Float = k < 2 ? -4.5 : -3
                    particles.append(Particle(x: tileX + Float(4 + (k % 2) * 8), y: tileY + Float(4 + (k / 2) * 8), vx: sx, vy: sy, life: 40, color: 4))
                }
                play(.hit)
            } else {
                bumps.append(Bump(col: col, row: row, t: 0))
                play(.thud)
            }
        default:
            play(.thud)
        }
        // Anything standing on the block gets knocked off.
        for i in 0..<enemies.count {
            if enemies[i].state == 3 || enemies[i].removed { continue }
            let ex = enemies[i].b.x + enemies[i].b.w / 2
            let bottom = enemies[i].b.y + enemies[i].b.h
            if abs(ex - (tileX + 8)) < 14 && abs(bottom - tileY) < 5 {
                knockOut(i, 100)
            }
        }
    }

    private func knockOut(_ i: Int, _ pts: Int) {
        if i < 0 || i >= enemies.count { return }
        enemies[i].state = 3
        enemies[i].b.vy = -4
        enemies[i].b.vx = 0
        addPoints(pts, enemies[i].b.x, enemies[i].b.y - 8)
        play(.stomp)
    }

    // MARK: Enemies

    private func updateEnemies() {
        let viewLeft = camX - 32
        let viewRight = camX + 160 + 24
        var i = 0
        while i < enemies.count {
            var e = enemies[i]
            if e.removed || e.b.y > 220 {
                enemies.remove(at: i)
                continue
            }
            if e.state == 3 {
                e.b.vy += 0.4
                e.b.y += e.b.vy
                enemies[i] = e
                i += 1
                continue
            }
            if !e.active {
                if e.b.x < viewRight && e.b.x > viewLeft { e.active = true } else {
                    enemies[i] = e
                    i += 1
                    continue
                }
            }
            if e.grace > 0 { e.grace -= 1 }
            switch e.state {
            case 0:
                e.b.vx = e.dir * (e.kind == 0 ? 0.45 : 0.5)
                if moveX(&e.b) { e.dir = -e.dir }
                e.b.vy = min(e.b.vy + 0.4, 5)
                _ = moveY(&e.b)
            case 1:
                if e.kind == 0 {
                    e.timer -= 1
                    if e.timer <= 0 { e.removed = true }
                } else {
                    e.b.vx = 0
                    e.b.vy = min(e.b.vy + 0.4, 5)
                    _ = moveY(&e.b)
                }
            default:
                e.b.vx = e.dir * 3.4
                if moveX(&e.b) {
                    e.dir = -e.dir
                    play(.thud)
                }
                e.b.vy = min(e.b.vy + 0.4, 5)
                _ = moveY(&e.b)
            }
            if e.b.x < camX - 64 && e.state != 2 { e.removed = true }
            enemies[i] = e

            // A sliding shell flattens everything it touches.
            if e.state == 2 {
                for j in 0..<enemies.count where j != i {
                    if enemies[j].state == 3 || enemies[j].removed || !enemies[j].active { continue }
                    if overlap(e.b, enemies[j].b) { knockOut(j, 200) }
                }
            }
            if e.state != 3 && !e.removed { heroTouch(i) }
            i += 1
        }
    }

    private func overlap(_ a: Body, _ b: Body) -> Bool {
        return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
    }

    private func heroTouch(_ i: Int) {
        if i < 0 || i >= enemies.count { return }
        var e = enemies[i]
        if e.state == 3 || e.removed || !overlap(hero, e.b) { return }
        if e.kind == 0 && e.state == 1 { return }
        let heroCenter = hero.x + hero.w / 2
        let enemyCenter = e.b.x + e.b.w / 2
        let falling = hero.vy > 0 && (hero.y + hero.h) - e.b.y < 11
        if e.kind == 1 && e.state == 1 {
            // Idle shell: kick it away.
            e.dir = heroCenter < enemyCenter ? 1 : -1
            e.state = 2
            e.grace = 12
            enemies[i] = e
            if falling { hero.vy = -3.2 }
            addPoints(400, e.b.x, e.b.y - 8)
            play(.hit)
            return
        }
        if falling && e.grace == 0 {
            if e.kind == 0 {
                e.state = 1
                e.timer = 24
                e.b.y += 4
                e.b.h = 8
                e.b.vx = 0
                addPoints(100, e.b.x, e.b.y - 8)
            } else if e.state == 0 {
                e.state = 1
                e.b.vx = 0
                e.b.y += 6
                e.b.h = 8
                addPoints(100, e.b.x, e.b.y - 8)
            } else {
                e.state = 1
                e.b.vx = 0
                addPoints(100, e.b.x, e.b.y - 8)
            }
            enemies[i] = e
            hero.vy = -4.4
            play(.stomp)
            return
        }
        if e.grace > 0 { return }
        hurtHero()
    }

    private func hurtHero() {
        if invuln > 0 { return }
        if big {
            big = false
            hero.y += 8
            hero.h = 16
            invuln = 100
            play(.hurt)
        } else {
            killHero()
        }
    }

    private func killHero() {
        if mode != .play { return }
        mode = .dying
        dyingTimer = 0
        hero.vy = -6
        hero.vx = 0
        play(.death)
        playMusic(nil)
    }

    // MARK: Items, coins, flag

    private func updateItems() {
        var i = 0
        while i < items.count {
            var it = items[i]
            if it.removed {
                items.remove(at: i)
                continue
            }
            if it.emerge > 0 {
                it.emerge -= 1
                it.b.y -= 0.7
            } else {
                it.b.vx = it.dir * 0.7
                if moveX(&it.b) { it.dir = -it.dir }
                it.b.vy = min(it.b.vy + 0.4, 5)
                _ = moveY(&it.b)
                if overlap(hero, it.b) {
                    it.removed = true
                    collectMushroom()
                }
                if it.b.y > 200 { it.removed = true }
            }
            items[i] = it
            i += 1
        }
    }

    private func collectMushroom() {
        play(.powerup)
        addPoints(1000, hero.x, hero.y - 8)
        if big { return }
        // Only grow if there is headroom.
        let col = Int(floor((hero.x + hero.w / 2) / 16))
        let rowAbove = Int(floor((hero.y - 8) / 16))
        if !isSolid(col, rowAbove) {
            big = true
            hero.y -= 8
            hero.h = 24
            invuln = 30
        }
    }

    private func checkCoins() {
        let c0 = Int(floor(hero.x / 16))
        let c1 = Int(floor((hero.x + hero.w) / 16))
        let r0 = Int(floor(hero.y / 16))
        let r1 = Int(floor((hero.y + hero.h - 0.01) / 16))
        if c1 < c0 || r1 < r0 { return }
        for r in r0...r1 {
            for c in c0...c1 where tile(c, r) == "o" {
                grid[r][c] = " "
                coinCount += 1
                points += 50
                play(.coin)
            }
        }
    }

    private func checkFlag() {
        let c0 = Int(floor((hero.x) / 16))
        let c1 = Int(floor((hero.x + hero.w) / 16))
        let r0 = max(0, Int(floor(hero.y / 16)))
        let r1 = min(8, Int(floor((hero.y + hero.h - 0.01) / 16)))
        if c1 < c0 || r1 < r0 { return }
        for r in r0...r1 {
            for c in c0...c1 where tile(c, r) == "F" {
                let poleX = Float(c * 16 + 6)
                if hero.x + hero.w > poleX && hero.x < poleX + 4 {
                    startClear(poleCol: c)
                    return
                }
            }
        }
    }

    private func startClear(poleCol: Int) {
        mode = .clear
        clearTimer = 0
        flagSlide = true
        hero.x = Float(poleCol * 16 + 3)
        hero.vx = 0
        hero.vy = 0
        let heightBonus = max(0, Int(112 - hero.y)) * 10
        points += 500 + heightBonus + timeLeft * 5
        playMusic(nil)
        play(.win)
    }

    private func updateClear() {
        clearTimer += 1
        if flagSlide {
            if clearTimer < 70 && !hero.onGround {
                hero.vy = 1.6
                _ = moveY(&hero)
            } else {
                flagSlide = false
            }
        } else {
            hero.vx = 1.2
            _ = moveX(&hero)
            hero.vy = min(hero.vy + 0.4, 5)
            _ = moveY(&hero)
            anim += 1
        }
        if clearTimer > 190 {
            levelIndex += 1
            if levelIndex >= CappyLand.levels.count {
                mode = .win
                play(.win)
            } else {
                loadLevel(levelIndex)
                mode = .intro
                introTimer = 90
            }
        }
    }

    private func updateDying() {
        dyingTimer += 1
        if dyingTimer > 20 {
            hero.vy = min(hero.vy + 0.35, 7)
            hero.y += hero.vy
        }
        if dyingTimer > 110 {
            lives -= 1
            big = false
            if lives <= 0 {
                mode = .over
                play(.lose)
            } else {
                let keepCoins = coinCount
                loadLevel(levelIndex)
                coinCount = keepCoins
                mode = .intro
                introTimer = 80
            }
        }
    }

    // MARK: - Drawing

    override func draw(_ c: Canvas) {
        c.clear(0)
        switch mode {
        case .title:
            drawTitle(c)
            return
        case .intro:
            drawIntro(c)
            return
        default:
            break
        }
        c.cameraX = 0
        c.cameraY = 0
        drawBackground(c)
        c.cameraX = Int(camX)
        drawTiles(c)
        drawItems(c)
        drawEnemies(c)
        drawHero(c)
        drawEffects(c)
        c.cameraX = 0
        drawHUD(c)
        if mode == .over {
            c.fillRect(30, 56, 100, 32, 19)
            c.strokeRect(30, 56, 100, 32, 18)
            c.textCentered("GAME OVER", y: 62, 18, scale: 2)
            c.textCentered("PRESS A", y: 78, 18)
        } else if mode == .win {
            c.fillRect(14, 44, 132, 56, 19)
            c.strokeRect(14, 44, 132, 56, 18)
            c.textCentered("YOU WIN!", y: 50, 20, scale: 2)
            c.textCentered("CAPPY SAVED THE DAY", y: 68, 18)
            c.textCentered("SCORE " + zeroPad(points, 6), y: 78, 18)
            c.textCentered("PRESS A", y: 90, 18)
        } else if mode == .clear && !flagSlide {
            c.textCentered("COURSE CLEAR!", y: 40, 25, scale: 2)
        }
    }

    private func drawTitle(_ c: Canvas) {
        c.clear(0)
        // Rolling hills and clouds
        for i in 0..<3 {
            let cx = (i * 70 + 20 - tick / 3) % 210 - 20
            drawCloud(c, cx, 20 + (i % 2) * 14)
        }
        c.fillCircle(30, 124, 34, 27)
        c.fillCircle(120, 130, 40, 27)
        c.fillRect(0, 112, 160, 32, 2)
        c.fillRect(0, 112, 160, 5, 3)
        for x in stride(from: 0, to: 160, by: 16) {
            c.fillRect(x, 124, 1, 20, 5)
        }
        c.textCentered("SUPER", y: 22, 19, scale: 2)
        c.textCentered("SUPER", y: 21, 10, scale: 2)
        c.textCentered("CAPPY LAND", y: 40, 19, scale: 2)
        c.textCentered("CAPPY LAND", y: 39, 10, scale: 2)
        c.draw(CappyLand.heroStand, 74, 96)
        if (tick / 24) % 2 == 0 {
            c.textCentered("PRESS A", y: 70, 19)
        }
        c.textCentered("RUN WITH B, JUMP WITH A", y: 132, 18)
    }

    private func drawIntro(_ c: Canvas) {
        c.clear(19)
        c.textCentered("WORLD " + levelName, y: 50, 18, scale: 2)
        c.draw(CappyLand.heroStand, 62, 72)
        c.text("X " + String(lives), 80, 80, 18, scale: 2)
        c.textCentered("SCORE " + zeroPad(points, 6), y: 108, 18)
    }

    private func drawCloud(_ c: Canvas, _ x: Int, _ y: Int) {
        c.fillCircle(x + 8, y + 6, 6, 1)
        c.fillCircle(x + 18, y + 4, 8, 1)
        c.fillCircle(x + 28, y + 7, 6, 1)
        c.fillRect(x + 6, y + 6, 24, 7, 1)
    }

    private func drawBackground(_ c: Canvas) {
        let scroll = Int(camX)
        if theme == 0 {
            for i in 0..<4 {
                let cx = i * 90 + 10 - scroll / 4
                let wrapped = ((cx % 360) + 360) % 360 - 40
                drawCloud(c, wrapped, 14 + (i % 2) * 18)
            }
            for i in 0..<5 {
                let hx = i * 80 + 20 - scroll / 2
                let wrapped = ((hx % 400) + 400) % 400 - 50
                c.fillCircle(wrapped, 116, 24, 27)
                c.fillCircle(wrapped + 26, 120, 14, 26)
            }
        } else if theme == 1 {
            for i in 0..<8 {
                let sx = i * 48 + 8 - scroll / 2
                let wrapped = ((sx % 384) + 384) % 384 - 24
                let depth = 14 + (i * 7) % 20
                for k in 0..<depth {
                    let half = max(0, (depth - k) / 3)
                    c.fillRect(wrapped - half, 32 + k, half * 2 + 1, 1, 1)
                }
            }
            for i in 0..<6 {
                let mx = i * 70 + 30 - scroll / 3
                let wrapped = ((mx % 420) + 420) % 420 - 30
                c.fillCircle(wrapped, 122, 20, 27)
            }
        } else {
            for i in 0..<6 {
                let px = i * 64 + 10 - scroll / 2
                let wrapped = ((px % 384) + 384) % 384 - 20
                c.fillRect(wrapped, 32, 14, 96, 1)
                c.fillRect(wrapped + 2, 32, 2, 96, 27)
                c.fillRect(wrapped + 4, 50, 6, 12, 26)
            }
        }
        // Lava glow beneath pits in the castle
        if theme == 2 {
            let wave = (tick / 6) % 4
            c.fillRect(0, 134 + wave % 2, 160, 12, 22)
            for x in stride(from: 0, to: 160, by: 10) {
                c.fillRect(x, 132 + ((x / 10 + wave) % 3), 6, 3, 22)
            }
        }
    }

    private func bumpOffset(_ col: Int, _ row: Int) -> Int {
        for b in bumps where b.col == col && b.row == row {
            let table = [0, 3, 5, 6, 6, 5, 4, 3, 2, 1, 0, 0]
            return table[min(max(b.t, 0), table.count - 1)]
        }
        return 0
    }

    private func drawTiles(_ c: Canvas) {
        let firstCol = max(0, Int(camX) / 16 - 1)
        let lastCol = min(levelWidth - 1, (Int(camX) + 160) / 16 + 1)
        if lastCol < firstCol { return }
        for col in firstCol...lastCol {
            for row in 0..<9 {
                let ch = grid[row][col]
                if ch == " " { continue }
                let x = col * 16
                let y = row * 16 - bumpOffset(col, row)
                switch ch {
                case "#": drawGround(c, x, y, col, row)
                case "B": drawBrick(c, x, y)
                case "H": drawHard(c, x, y)
                case "?", "P": drawQuestion(c, x, y)
                case "u": drawUsed(c, x, y)
                case "p", "q", "l", "r": drawPipe(c, x, y, ch)
                case "o": drawCoin(c, x + 8, y + 8)
                case "F": drawPole(c, x, y, row)
                default: break
                }
            }
        }
    }

    private func drawGround(_ c: Canvas, _ x: Int, _ y: Int, _ col: Int, _ row: Int) {
        c.fillRect(x, y, 16, 16, 2)
        if !isSolid(col, row - 1) {
            c.fillRect(x, y, 16, 5, 3)
            c.fillRect(x, y + 5, 16, 1, 19)
            c.fillRect(x + 3, y + 1, 3, 1, 26)
            c.fillRect(x + 10, y + 2, 3, 1, 26)
        }
        c.fillRect(x + 2, y + 9, 4, 2, 5)
        c.fillRect(x + 9, y + 12, 5, 2, 5)
        c.fillRect(x + 15, y, 1, 16, 5)
    }

    private func drawBrick(_ c: Canvas, _ x: Int, _ y: Int) {
        c.fillRect(x, y, 16, 16, 4)
        for k in 0..<4 {
            c.hline(x, y + k * 4 + 3, 16, 5)
        }
        c.vline(x + 7, y, 4, 5)
        c.vline(x + 3, y + 4, 4, 5)
        c.vline(x + 11, y + 4, 4, 5)
        c.vline(x + 7, y + 8, 4, 5)
        c.vline(x + 3, y + 12, 4, 5)
        c.vline(x + 11, y + 12, 4, 5)
        c.strokeRect(x, y, 16, 16, 19)
    }

    private func drawHard(_ c: Canvas, _ x: Int, _ y: Int) {
        c.fillRect(x, y, 16, 16, 3)
        c.fillRect(x + 2, y + 2, 12, 12, 2)
        c.hline(x, y, 16, 18)
        c.vline(x, y, 16, 18)
        c.hline(x, y + 15, 16, 19)
        c.vline(x + 15, y, 16, 19)
    }

    private func drawQuestion(_ c: Canvas, _ x: Int, _ y: Int) {
        let flash = (tick / 12) % 4 == 0
        c.fillRect(x, y, 16, 16, flash ? 17 : 6)
        c.strokeRect(x, y, 16, 16, 7)
        c.setPixel(x + 2, y + 2, 7)
        c.setPixel(x + 13, y + 2, 7)
        c.setPixel(x + 2, y + 13, 7)
        c.setPixel(x + 13, y + 13, 7)
        c.text("?", x + 5, y + 3, 19, scale: 2)
    }

    private func drawUsed(_ c: Canvas, _ x: Int, _ y: Int) {
        c.fillRect(x, y, 16, 16, 7)
        c.strokeRect(x, y, 16, 16, 19)
        c.setPixel(x + 2, y + 2, 5)
        c.setPixel(x + 13, y + 2, 5)
        c.setPixel(x + 2, y + 13, 5)
        c.setPixel(x + 13, y + 13, 5)
    }

    private func drawPipe(_ c: Canvas, _ x: Int, _ y: Int, _ ch: Character) {
        let left = (ch == "p" || ch == "l")
        let top = (ch == "p" || ch == "q")
        c.fillRect(x, y, 16, 16, left ? 8 : 9)
        if top {
            c.fillRect(x, y, 16, 16, left ? 8 : 9)
            c.hline(x, y, 16, 19)
            c.hline(x, y + 15, 16, 19)
        } else {
            c.fillRect(x + (left ? 2 : 0), y, 14, 16, left ? 8 : 9)
        }
        if left {
            c.vline(x, y, 16, 19)
            c.vline(x + 3, top ? y + 2 : y, top ? 12 : 16, 18)
        } else {
            c.vline(x + 15, y, 16, 19)
            c.vline(x + 12, top ? y + 2 : y, top ? 12 : 16, 8)
        }
    }

    private func drawCoin(_ c: Canvas, _ cx: Int, _ cy: Int) {
        let phase = (tick / 6) % 4
        let widths = [3, 2, 1, 2]
        let w = widths[phase]
        c.fillRect(cx - w, cy - 5, w * 2 + 1, 10, 21)
        c.fillRect(cx - w + 1, cy - 4, max(1, w * 2 - 1), 8, 20)
    }

    private func drawPole(_ c: Canvas, _ x: Int, _ y: Int, _ row: Int) {
        c.fillRect(x + 6, y, 4, 16, 19)
        c.fillRect(x + 7, y, 2, 16, 18)
        if row == 1 {
            c.fillCircle(x + 8, y + 2, 3, 20)
            c.fillRect(x - 4, y + 4, 12, 8, 24)
            c.strokeRect(x - 4, y + 4, 12, 8, 19)
        }
    }

    private func drawItems(_ c: Canvas) {
        for it in items {
            let sy = Int(it.b.y)
            let sx = Int(it.b.x)
            if it.emerge > 0 {
                // Clip the item inside the block while it rises.
                let visible = 10 - Int(Float(it.emerge) * 0.7)
                if visible > 0 { c.draw(CappyLand.mushroom, sx, sy - 1) }
            } else {
                c.draw(CappyLand.mushroom, sx, sy - 1)
            }
        }
    }

    private func drawEnemies(_ c: Canvas) {
        for e in enemies {
            if e.removed { continue }
            let x = Int(e.b.x)
            let y = Int(e.b.y)
            let flip = ((tick / 10) % 2 == 0)
            if e.kind == 0 {
                if e.state == 1 {
                    c.draw(CappyLand.walkerSquash, x, y + 1)
                } else if e.state == 3 {
                    c.draw(CappyLand.walker, x, y, flipX: false, flipY: true)
                } else {
                    c.draw(CappyLand.walker, x, y, flipX: flip)
                }
            } else {
                if e.state == 0 {
                    c.draw(CappyLand.turtle, x, y, flipX: e.dir > 0)
                } else if e.state == 3 {
                    c.draw(CappyLand.shell, x, y, flipX: false, flipY: true)
                } else {
                    c.draw(CappyLand.shell, x, y + 1)
                }
            }
        }
    }

    private func heroSprite() -> Sprite {
        if mode == .dying { return CappyLand.heroJump }
        if !hero.onGround && !flagSlide { return CappyLand.heroJump }
        if abs(hero.vx) > 0.3 {
            let step = (anim / 5) % 4
            if step == 0 { return CappyLand.heroRun1 }
            if step == 2 { return CappyLand.heroRun2 }
            return CappyLand.heroStand
        }
        return CappyLand.heroStand
    }

    private func drawHero(_ c: Canvas) {
        if mode == .dying && dyingTimer < 0 { return }
        if invuln > 0 && (invuln / 3) % 2 == 0 && mode == .play { return }
        let sprite = heroSprite()
        let x = Int(hero.x) - 1
        let y = Int(hero.y)
        let flip = facing < 0
        if big {
            for dy in 0..<24 {
                let srcRow = min(15, dy * 16 / 24)
                for dx in 0..<12 {
                    let v = sprite.data[srcRow * 12 + dx]
                    if v == Sprite.clear { continue }
                    let px = flip ? 11 - dx : dx
                    c.setPixel(x + px, y + dy, Int(v))
                }
            }
        } else {
            c.draw(sprite, x, y, flipX: flip)
        }
    }

    private func drawEffects(_ c: Canvas) {
        for p in particles {
            c.fillRect(Int(p.x), Int(p.y), 4, 4, p.color)
            c.strokeRect(Int(p.x), Int(p.y), 4, 4, 19)
        }
        for p in pops {
            c.text(p.text, Int(p.x), Int(p.y), 25)
        }
    }

    private func drawHUD(_ c: Canvas) {
        c.text("SCORE " + zeroPad(points, 6) + "   COINS " + zeroPad(coinCount, 2), 3, 2, 25)
        c.text("WORLD " + levelName + "  LIVES " + String(max(0, lives)) + "  TIME " + String(max(0, timeLeft)), 3, 9, 25)
    }
}

extension Cartridge {
    static let cappyLand = Cartridge(
        id: "cappy", title: "SUPER CAPPY LAND", genre: "Platformer",
        blurb: "Run, jump and stomp through three worlds as Cappy the plumber. Bump blocks for coins and mushrooms, ride out the pits, and slide down the flagpole.",
        controls: "D-PAD move. A jump (hold for height). Hold B to run. Stomp critters, kick shells.",
        era: .gbc, labelTop: 0xE04A3A, labelBottom: 0x7A1F2A, factory: { CappyLand() })
}
