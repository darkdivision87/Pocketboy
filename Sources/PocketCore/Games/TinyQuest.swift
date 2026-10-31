import Foundation

/// Top-down action adventure. A swings the sword, B throws the boomerang.
/// Twelve hand-built screens: nine overworld rooms, two dungeon rooms and a boss lair.
final class TinyQuest: Game {
    private enum Mode { case title, play, scroll, dead, win }
    private enum EKind { case slime, charger, shooter, boss }

    private struct Enemy {
        var kind: EKind
        var x: Float
        var y: Float
        var dx: Float
        var dy: Float
        var hp: Int
        var timer: Int
        var state: Int
        var stun: Int
        var hurt: Int
        var anim: Int
    }

    private struct Proj {
        var x: Float
        var y: Float
        var dx: Float
        var dy: Float
        var life: Int
        var big: Bool
    }

    private struct Drop {
        var x: Float
        var y: Float
        var kind: Int   // 0 gem, 1 heart
        var life: Int
    }

    // MARK: Palette
    // 0 grass, 1 grass tuft, 2 path, 3 outline, 4 tree dark, 5 tree light, 6 brown, 7 stone light, 8 stone dark,
    // 9 water, 10 water light, 11 tunic, 12 skin, 13 steel, 14 red, 15 gold, 16 gem blue, 17 white,
    // 18 HUD bg, 19 dungeon floor, 20 dungeon floor alt, 21 dungeon wall light, 22 dungeon wall dark,
    // 23 purple, 24 orange, 25 slime green, 26 spare, 27 spare, 28 dim text, 29 door brown
    private static let pal = Palette.make([
        0xB8E890, 0x88C060, 0xD8C890, 0x101820, 0x207838, 0x40A850, 0x80502C, 0xB0B0C0,
        0x707088, 0x4890E0, 0xA0D0FF, 0x58E070, 0xF8C898, 0xE8F0FF, 0xE03030, 0xF8D030,
        0x30B8F8, 0xF8F8F8, 0x181828, 0x20203C, 0x2C2C50, 0x7078B0, 0x484C80, 0xA050E0,
        0xF08030, 0x60D860, 0xB0B0C0, 0x707088, 0x8890B0, 0xA06830
    ])
    override var palette: [UInt16] { return TinyQuest.pal }

    // MARK: Sprites

    private static let heroDown: [Sprite] = [
        Sprite([
            "....3333....",
            "...366663...",
            "..36cccc63..",
            "..3c3cc3c3..",
            "..3cccccc3..",
            "...3bbbb3...",
            "..3bbbbbb3..",
            ".3cbbbbbbc3.",
            "..3bbbbbb3..",
            "..3bb33bb3..",
            "..366..663..",
            "...33..33..."
        ]),
        Sprite([
            "....3333....",
            "...366663...",
            "..36cccc63..",
            "..3c3cc3c3..",
            "..3cccccc3..",
            "...3bbbb3...",
            "..3bbbbbb3..",
            ".3cbbbbbbc3.",
            "..3bbbbbb3..",
            "...3bbbb3...",
            "...366663...",
            "....3333...."
        ])
    ]
    private static let heroUp: [Sprite] = [
        Sprite([
            "....3333....",
            "...366663...",
            "..36666663..",
            "..36666663..",
            "..36666663..",
            "...3bbbb3...",
            "..3bbbbbb3..",
            ".3cbbbbbbc3.",
            "..3bbbbbb3..",
            "..3bb33bb3..",
            "..366..663..",
            "...33..33..."
        ]),
        Sprite([
            "....3333....",
            "...366663...",
            "..36666663..",
            "..36666663..",
            "..36666663..",
            "...3bbbb3...",
            "..3bbbbbb3..",
            ".3cbbbbbbc3.",
            "..3bbbbbb3..",
            "...3bbbb3...",
            "...366663...",
            "....3333...."
        ])
    ]
    // Facing left; flip for right.
    private static let heroSide: [Sprite] = [
        Sprite([
            "....3333....",
            "...366663...",
            "..3cc66663..",
            "..3c3c6663..",
            "..3cccc663..",
            "...3bbbb3...",
            "..3bbbbbb3..",
            "..3cbbbbb3..",
            "..3bbbbbb3..",
            "...3bb3b3...",
            "...36.663...",
            "...33..33..."
        ]),
        Sprite([
            "....3333....",
            "...366663...",
            "..3cc66663..",
            "..3c3c6663..",
            "..3cccc663..",
            "...3bbbb3...",
            "..3bbbbbb3..",
            "..3cbbbbb3..",
            "..3bbbbbb3..",
            "....3bb3....",
            "....3663....",
            ".....33....."
        ])
    ]
    private static let slimeSprites: [Sprite] = [
        Sprite([
            "............",
            "............",
            "....3333....",
            "...3pppp3...",
            "..3pppppp3..",
            ".3pp3pp3pp3.",
            ".3pppppppp3.",
            ".3pppppppp3.",
            "..3pppppp3..",
            "...333333...",
            "............",
            "............"
        ]),
        Sprite([
            "............",
            "............",
            "............",
            "............",
            "....3333....",
            "..33pppp33..",
            ".3pp3pp3pp3.",
            ".3pppppppp3.",
            ".3pppppppp3.",
            "..33333333..",
            "............",
            "............"
        ])
    ]
    private static let chargerSprites: [Sprite] = [
        Sprite([
            "............",
            "..3......3..",
            "...3....3...",
            "..33333333..",
            ".3eeeeeeee3.",
            ".3eheeeehe3.",
            ".3e3eeee3e3.",
            ".3eeeeeeee3.",
            "..3eeeeee3..",
            "..3.3..3.3..",
            ".3..3..3..3.",
            "............"
        ]),
        Sprite([
            "............",
            "..3......3..",
            "...3....3...",
            "..33333333..",
            ".3eeeeeeee3.",
            ".3eheeeehe3.",
            ".3e3eeee3e3.",
            ".3eeeeeeee3.",
            "..3eeeeee3..",
            ".3.3....3.3.",
            "3...3..3...3",
            "............"
        ])
    ]
    private static let shooterSprite = Sprite([
        "............",
        "....3333....",
        "..33nnnn33..",
        ".3nnnnnnnn3.",
        ".3nhnnnnhn3.",
        ".3n3nnnn3n3.",
        ".3nnn33nnn3.",
        ".3nnn33nnn3.",
        "..3nnnnnn3..",
        ".3n3n33n3n3.",
        ".3.3.33.3.3.",
        "............"
    ])
    private static let heartFull = Sprite([
        ".ee.ee.",
        "eheeeee",
        "eeeeeee",
        ".eeeee.",
        "..eee..",
        "...e..."
    ])
    private static let heartHalf = Sprite([
        ".ee.ss.",
        "ehee..s",
        "eeee..s",
        ".eee.s.",
        "..ee.s.",
        "...es.."
    ])
    private static let heartEmpty = Sprite([
        ".ss.ss.",
        "s..s..s",
        "s.....s",
        ".s...s.",
        "..s.s..",
        "...s..."
    ])
    private static let gemSprite = Sprite([
        "...g...",
        "..ggg..",
        ".ggdgg.",
        ".ggdgg.",
        "..ggg..",
        "...g..."
    ])
    private static let keySprite = Sprite([
        ".fff....",
        "f...f...",
        "f...f...",
        ".fff....",
        "..f.....",
        "..ff....",
        "..f.....",
        "..ff...."
    ])
    private static let containerSprite = Sprite([
        ".eee.eee.",
        "eheeeeeee",
        "eeeeeeeee",
        "eeeeeeeee",
        ".eeeeeee.",
        "..eeeee..",
        "...eee...",
        "....e...."
    ])
    private static let crystalSprite = Sprite([
        "....dd....",
        "...dggd...",
        "..dggggd..",
        ".dggggggd.",
        "dggggggggd",
        ".dggggggd.",
        "..dggggd..",
        "...dggd...",
        "....dd...."
    ])

    // MARK: World data (10 x 8 tiles of 16px per room)
    // Legend: . grass  , path  # stone  T tree  b bush  w water  B pushable block  D locked door
    // X dungeon wall  f dungeon floor  g gem  k key  h heart container  v small heart
    // H block hiding a heart container  K block hiding a key  C crystal
    // Room order: row-major on a 4x3 grid:  H G I D1 / A B C D2 / E Dd F Boss.

    private static let roomMaps: [[String]] = [
        // 0 northwest cliffs
        [
            "##########",
            "#........#",
            "#.TT..TT.#",
            "#.H.......",
            "#.........",
            "#.TT..TT.#",
            "#........#",
            "####..####"
        ],
        // 1 north hills
        [
            "##########",
            "#........#",
            "#.b....b.#",
            "..........",
            "..........",
            "#.b....b.#",
            "#........#",
            "####..####"
        ],
        // 2 northeast rocks, locked door to the dungeon
        [
            "##########",
            "#...g....#",
            "#.##..##.#",
            ".........D",
            ".........#",
            "#.##..##.#",
            "#........#",
            "####..####"
        ],
        // 3 dungeon one
        [
            "XXXXXXXXXX",
            "XffffffffX",
            "XfXXffXXfX",
            "ffffffffgX",
            "XffffffffX",
            "XfXXffXXfX",
            "XffKfffffX",
            "XXXXffXXXX"
        ],
        // 4 west meadow
        [
            "TTTT..TTTT",
            "T........T",
            "T..TT....T",
            "T.........",
            "T.........",
            "T..T.....T",
            "T........T",
            "TTTT..TTTT"
        ],
        // 5 village clearing (start)
        [
            "TTTT..TTTT",
            "T........T",
            "T.bb..bb.T",
            "..........",
            "..........",
            "T.bb..bb.T",
            "T........T",
            "TTTT..TTTT"
        ],
        // 6 east forest
        [
            "TTTT..TTTT",
            "T........T",
            "T.T.bb.T.T",
            ".........T",
            ".........T",
            "T.T.bb.T.T",
            "T........T",
            "TTTT..TTTT"
        ],
        // 7 dungeon two
        [
            "XXXXffXXXX",
            "XffffffffX",
            "XfXffffXfX",
            "XffffffffX",
            "XfffXXfffX",
            "XffffffffX",
            "XffgffffgX",
            "XXXXDXXXXX"
        ],
        // 8 southwest shore (key)
        [
            "TTTT..TTTT",
            "T........T",
            "T.wwww...T",
            "T.wwww....",
            "T.........",
            "T..k.....T",
            "T........T",
            "TTTTTTTTTT"
        ],
        // 9 south pond
        [
            "TTTT..TTTT",
            "T........T",
            "T..wwww..T",
            "...wwww...",
            "..........",
            "TgbT..TbgT",
            "T........T",
            "TTTTTTTTTT"
        ],
        // 10 southeast graveyard
        [
            "TTTT..TTTT",
            "T........T",
            "T.##..##.T",
            ".........T",
            ".........T",
            "T.##..##.T",
            "T..g..g..T",
            "TTTTTTTTTT"
        ],
        // 11 boss lair
        [
            "XXXXfXXXXX",
            "XffffffffX",
            "XffffffffX",
            "XffffffffX",
            "XffffffffX",
            "XffffffffX",
            "XffffffffX",
            "XXXXXXXXXX"
        ]
    ]

    // kind: 0 slime, 1 charger, 2 shooter, 3 boss;  [kind, tileX, tileY]
    private static let spawnData: [[[Int]]] = [
        [[0, 6, 1], [0, 6, 6]],                                  // 0
        [[0, 3, 1], [1, 7, 6]],                                  // 1
        [[1, 2, 4], [2, 6, 6]],                                  // 2
        [[0, 2, 4], [1, 7, 4], [2, 8, 1]],                       // 3
        [[0, 5, 2], [0, 7, 5]],                                  // 4
        [[0, 7, 1], [0, 2, 6]],                                  // 5
        [[1, 3, 2], [1, 6, 5], [0, 5, 3]],                       // 6
        [[2, 1, 1], [2, 8, 1], [1, 4, 3]],                       // 7
        [[2, 7, 5], [0, 5, 6]],                                  // 8
        [[0, 2, 2], [1, 6, 4]],                                  // 9
        [[2, 2, 1], [2, 7, 6], [0, 5, 3]],                       // 10
        [[3, 4, 2]]                                              // 11
    ]

    // MARK: State

    private var mode: Mode = .title
    private var frame = 0
    private var rng = Rng()

    private var maps: [[[Character]]] = []
    private var room = 5
    private var visited = [Bool](repeating: false, count: 12)
    private var enemies: [Enemy] = []
    private var incoming: [Enemy] = []
    private var projs: [Proj] = []
    private var drops: [Drop] = []

    private var px: Float = 66
    private var py: Float = 66
    private var facing = 0           // 0 down, 1 up, 2 left, 3 right
    private var walkTimer = 0
    private var swingT = 0
    private var swingCut = false
    private var invuln = 0
    private var kbX: Float = 0
    private var kbY: Float = 0
    private var kbTimer = 0
    private var pushTimer = 0
    private var pushing = false

    private var hp = 6
    private var maxHearts = 3
    private var keys = 0
    private var gems = 0
    private var kills = 0
    private var bossDead = false

    private var boomActive = false
    private var boomX: Float = 0
    private var boomY: Float = 0
    private var boomDX: Float = 0
    private var boomDY: Float = 0
    private var boomOut = true
    private var boomDist: Float = 0

    private var scrollDX = 0
    private var scrollDY = 0
    private var scrollT = 0
    private var scrollTo = 5
    private let scrollLen = 28

    private var paused = false
    private var deadTimer = 0
    private var winTimer = 0
    private var bannerTimer = 0
    private var bannerText = ""

    override var score: Int {
        var s = gems * 10 + kills * 25
        for v in visited where v { s += 20 }
        if mode == .win { s += 1000 + hp * 25 }
        return max(0, s)
    }

    override func start() {
        playMusic(Tunes.adventure)
    }

    // MARK: Setup

    private func newGame() {
        maps = []
        for rows in TinyQuest.roomMaps {
            var grid: [[Character]] = []
            for r in rows {
                var line = Array(r)
                while line.count < 10 { line.append("#") }
                grid.append(line)
            }
            while grid.count < 8 { grid.append([Character](repeating: "#", count: 10)) }
            maps.append(grid)
        }
        visited = [Bool](repeating: false, count: 12)
        room = 5
        visited[5] = true
        px = 66
        py = 66
        facing = 0
        swingT = 0
        invuln = 0
        kbTimer = 0
        hp = 6
        maxHearts = 3
        keys = 0
        gems = 0
        kills = 0
        bossDead = false
        boomActive = false
        projs = []
        drops = []
        paused = false
        enemies = spawnEnemies(5)
        bannerText = "ADVENTURE BEGINS"
        bannerTimer = 120
        playMusic(Tunes.adventure)
    }

    private func isDungeon(_ r: Int) -> Bool { return r == 3 || r == 7 || r == 11 }

    private func spawnEnemies(_ r: Int) -> [Enemy] {
        var out: [Enemy] = []
        if r < 0 || r >= TinyQuest.spawnData.count { return out }
        for s in TinyQuest.spawnData[r] {
            if s.count < 3 { continue }
            if s[0] == 3 && bossDead { continue }
            var kind = EKind.slime
            var hpv = 2
            switch s[0] {
            case 1:
                kind = .charger
                hpv = 3
            case 2:
                kind = .shooter
                hpv = 2
            case 3:
                kind = .boss
                hpv = 12
            default:
                kind = .slime
                hpv = 2
            }
            let sz: Float = kind == .boss ? 20 : 12
            let ex = Float(s[1] * 16) + (16 - sz) / 2
            let ey = Float(s[2] * 16) + (16 - sz) / 2
            var e = Enemy(kind: kind, x: ex, y: ey, dx: 0, dy: 0, hp: hpv, timer: rng.range(20, 80), state: 0, stun: 0, hurt: 0, anim: rng.int(60))
            if kind == .boss {
                e.dx = ex
                e.dy = ey
                e.timer = 90
            }
            out.append(e)
        }
        return out
    }

    // MARK: Tiles

    private func tileChar(_ r: Int, _ tx: Int, _ ty: Int) -> Character {
        if r < 0 || r >= maps.count || tx < 0 || tx > 9 || ty < 0 || ty > 7 { return "#" }
        return maps[r][ty][tx]
    }

    private func setTile(_ r: Int, _ tx: Int, _ ty: Int, _ ch: Character) {
        if r < 0 || r >= maps.count || tx < 0 || tx > 9 || ty < 0 || ty > 7 { return }
        maps[r][ty][tx] = ch
    }

    private func floorChar(_ r: Int) -> Character { return isDungeon(r) ? "f" : "." }

    private func isSolidChar(_ ch: Character) -> Bool {
        switch ch {
        case "#", "T", "w", "B", "H", "K", "D", "X", "b": return true
        default: return false
        }
    }

    private func neighbour(_ nx: Int, _ ny: Int) -> Int {
        if nx != 0 && ny != 0 { return -1 }
        let rx = room % 4 + nx
        let ry = room / 4 + ny
        if rx < 0 || rx > 3 || ry < 0 || ry > 2 { return -1 }
        return ry * 4 + rx
    }

    private func pointSolid(_ x: Int, _ y: Int, _ hero: Bool) -> Bool {
        var tx = x < 0 ? -1 : x / 16
        var ty = y < 0 ? -1 : y / 16
        if tx < 0 || tx > 9 || ty < 0 || ty > 7 {
            if !hero { return true }
            var nx = 0
            var ny = 0
            if tx < 0 { nx = -1 } else if tx > 9 { nx = 1 }
            if ty < 0 { ny = -1 } else if ty > 7 { ny = 1 }
            if neighbour(nx, ny) < 0 { return true }
            tx = clamp(tx, 0, 9)
            ty = clamp(ty, 0, 7)
        }
        return isSolidChar(tileChar(room, tx, ty))
    }

    private func rectSolid(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ hero: Bool) -> Bool {
        if pointSolid(x, y, hero) { return true }
        if pointSolid(x + w - 1, y, hero) { return true }
        if pointSolid(x, y + h - 1, hero) { return true }
        if pointSolid(x + w - 1, y + h - 1, hero) { return true }
        return false
    }

    private func heroBox() -> Box {
        return Box(Int(px.rounded(.down)) + 2, Int(py.rounded(.down)) + 4, 8, 8)
    }

    // MARK: Hero movement

    private func moveHero(_ dx: Float, _ dy: Float) {
        if dx != 0 {
            let nx = px + dx
            let bx = Int(nx.rounded(.down)) + 2
            let by = Int(py.rounded(.down)) + 4
            if !rectSolid(bx, by, 8, 8, true) {
                px = nx
            } else {
                let probeX = dx > 0 ? bx + 8 : bx - 1
                interact(probeX, by + 4, dx > 0 ? 1 : -1, 0)
            }
        }
        if dy != 0 {
            let ny = py + dy
            let bx = Int(px.rounded(.down)) + 2
            let by = Int(ny.rounded(.down)) + 4
            if !rectSolid(bx, by, 8, 8, true) {
                py = ny
            } else {
                let probeY = dy > 0 ? by + 8 : by - 1
                interact(bx + 4, probeY, 0, dy > 0 ? 1 : -1)
            }
        }
    }

    private func interact(_ x: Int, _ y: Int, _ ddx: Int, _ ddy: Int) {
        if x < 0 || y < 0 { return }
        let tx = x / 16
        let ty = y / 16
        let ch = tileChar(room, tx, ty)
        if ch == "D" {
            if keys > 0 {
                keys -= 1
                setTile(room, tx, ty, floorChar(room))
                play(.confirm)
            } else if frame % 40 == 0 {
                play(.thud)
                bannerText = "LOCKED"
                bannerTimer = 50
            }
            return
        }
        if ch == "B" || ch == "H" || ch == "K" {
            pushing = true
            pushTimer += 1
            if pushTimer >= 14 {
                let nx = tx + ddx
                let ny = ty + ddy
                let target = tileChar(room, nx, ny)
                var free = target == "." || target == "," || target == "f"
                if free {
                    for e in enemies where e.hp > 0 {
                        let ex = Int(e.x + 6) / 16
                        let ey = Int(e.y + 6) / 16
                        if ex == nx && ey == ny { free = false }
                    }
                }
                if free {
                    var under: Character = floorChar(room)
                    if ch == "H" { under = "h" }
                    if ch == "K" { under = "k" }
                    setTile(room, tx, ty, under)
                    setTile(room, nx, ny, "B")
                    play(.thud)
                }
                pushTimer = 0
            }
        }
    }

    private func unstick() {
        var guardCount = 0
        while guardCount < 40 {
            let b = heroBox()
            if !rectSolid(b.x, b.y, 8, 8, true) { return }
            let cx: Float = 76
            let cy: Float = 60
            if px + 6 < cx { px += 1 } else if px + 6 > cx { px -= 1 }
            if py + 6 < cy { py += 1 } else if py + 6 > cy { py -= 1 }
            guardCount += 1
        }
    }

    // MARK: Damage

    private func hurtPlayer(_ amount: Int, _ srcX: Float, _ srcY: Float) {
        if invuln > 0 || mode != .play { return }
        hp -= amount
        invuln = 70
        var vx = (px + 6) - srcX
        var vy = (py + 6) - srcY
        let len = sqrt(vx * vx + vy * vy)
        if len > 0.01 {
            vx /= len
            vy /= len
        } else {
            vx = 0
            vy = 1
        }
        kbX = vx * 2.5
        kbY = vy * 2.5
        kbTimer = 8
        play(.hurt)
        if hp <= 0 {
            hp = 0
            mode = .dead
            deadTimer = 0
            boomActive = false
            play(.death)
        }
    }

    private func damageEnemy(_ i: Int, _ amount: Int, _ kx: Float, _ ky: Float, _ stun: Int) {
        if i < 0 || i >= enemies.count { return }
        var e = enemies[i]
        if e.hp <= 0 || e.hurt > 0 { return }
        e.hp -= amount
        e.hurt = 20
        play(.hit)
        if e.hp <= 0 {
            enemies[i] = e
            killEnemy(e)
            return
        }
        if e.kind != .boss {
            _ = moveEnemy(&e, kx * 6, ky * 6)
            e.stun = max(e.stun, stun)
        }
        enemies[i] = e
    }

    private func killEnemy(_ e: Enemy) {
        kills += 1
        if e.kind == .boss {
            bossDead = true
            projs = []
            play(.explosion)
            setTile(room, 4, 3, "C")
            setTile(room, 6, 3, "h")
            bannerText = "THE GUARDIAN FALLS"
            bannerTimer = 120
            return
        }
        play(.stomp)
        let r = rng.int(100)
        if r < 40 {
            drops.append(Drop(x: e.x + 2, y: e.y + 2, kind: 0, life: 600))
        } else if r < 60 {
            drops.append(Drop(x: e.x + 2, y: e.y + 2, kind: 1, life: 600))
        }
    }

    // MARK: Enemy logic

    private func enemyBlocked(_ x: Float, _ y: Float, _ sz: Int) -> Bool {
        let ix = Int(x.rounded(.down)) + 1
        let iy = Int(y.rounded(.down)) + 1
        return rectSolid(ix, iy, sz - 2, sz - 2, false)
    }

    private func moveEnemy(_ e: inout Enemy, _ dx: Float, _ dy: Float) -> Bool {
        let sz = e.kind == .boss ? 20 : 12
        var blocked = false
        if dx != 0 {
            let nx = e.x + dx
            if enemyBlocked(nx, e.y, sz) { blocked = true } else { e.x = nx }
        }
        if dy != 0 {
            let ny = e.y + dy
            if enemyBlocked(e.x, ny, sz) { blocked = true } else { e.y = ny }
        }
        return blocked
    }

    private func wander(_ e: inout Enemy, _ speed: Float) {
        e.timer -= 1
        if e.timer <= 0 {
            let d = rng.int(5)
            switch d {
            case 0:
                e.dx = 1
                e.dy = 0
            case 1:
                e.dx = -1
                e.dy = 0
            case 2:
                e.dx = 0
                e.dy = 1
            case 3:
                e.dx = 0
                e.dy = -1
            default:
                e.dx = 0
                e.dy = 0
            }
            e.timer = rng.range(30, 80)
        }
        let mvx: Float = e.dx * speed
        let mvy: Float = e.dy * speed
        if moveEnemy(&e, mvx, mvy) { e.timer = 0 }
    }

    private func fire(_ x: Float, _ y: Float, _ vx: Float, _ vy: Float, _ big: Bool) {
        projs.append(Proj(x: x, y: y, dx: vx, dy: vy, life: 160, big: big))
    }

    private func updateEnemies() {
        let hx = px + 6
        let hy = py + 6
        for i in 0..<enemies.count {
            var e = enemies[i]
            if e.hp <= 0 { continue }
            if e.hurt > 0 { e.hurt -= 1 }
            if e.stun > 0 {
                e.stun -= 1
                enemies[i] = e
                continue
            }
            e.anim += 1
            let ex = e.x + 6
            let ey = e.y + 6
            switch e.kind {
            case .slime:
                wander(&e, 0.5)
            case .charger:
                switch e.state {
                case 0:
                    wander(&e, 0.4)
                    if abs(ey - hy) < 8 && abs(ex - hx) < 110 {
                        e.dx = ex < hx ? 1 : -1
                        e.dy = 0
                        e.state = 1
                        e.timer = 24
                    } else if abs(ex - hx) < 8 && abs(ey - hy) < 90 {
                        e.dy = ey < hy ? 1 : -1
                        e.dx = 0
                        e.state = 1
                        e.timer = 24
                    }
                case 1:
                    e.timer -= 1
                    if e.timer <= 0 {
                        e.state = 2
                        e.timer = 0
                    }
                case 2:
                    let dashX: Float = e.dx * 2.4
                    let dashY: Float = e.dy * 2.4
                    let blocked = moveEnemy(&e, dashX, dashY)
                    e.timer += 1
                    if blocked || e.timer > 80 {
                        e.state = 3
                        e.timer = 50
                        if blocked { play(.thud) }
                    }
                default:
                    e.timer -= 1
                    if e.timer <= 0 {
                        e.state = 0
                        e.timer = 30
                    }
                }
            case .shooter:
                e.timer -= 1
                if abs(hx - ex) > abs(hy - ey) {
                    e.dx = hx > ex ? 1 : -1
                    e.dy = 0
                } else {
                    e.dy = hy > ey ? 1 : -1
                    e.dx = 0
                }
                if e.timer <= 0 {
                    fire(ex - 2, ey - 2, e.dx * 1.7, e.dy * 1.7, false)
                    play(.shoot)
                    e.timer = rng.range(80, 130)
                }
            case .boss:
                let phase2 = e.hp <= 6
                let sp: Float = phase2 ? 1.1 : 0.7
                let tx = e.dx
                let ty = e.dy
                let vx = tx - e.x
                let vy = ty - e.y
                let d = sqrt(vx * vx + vy * vy)
                if d < 2 {
                    e.dx = Float(rng.range(16, 124))
                    e.dy = Float(rng.range(16, 92))
                } else {
                    e.x += vx / d * sp
                    e.y += vy / d * sp
                }
                e.timer -= 1
                if e.timer <= 0 {
                    let bx = e.x + 10
                    let by = e.y + 10
                    var ax = hx - bx
                    var ay = hy - by
                    let l = sqrt(ax * ax + ay * ay)
                    if l > 0.01 {
                        ax /= l
                        ay /= l
                    } else {
                        ax = 0
                        ay = 1
                    }
                    fire(bx - 3, by - 3, ax * 1.5, ay * 1.5, true)
                    if phase2 {
                        let ca: Float = cos(0.4)
                        let sa: Float = sin(0.4)
                        fire(bx - 3, by - 3, (ax * ca - ay * sa) * 1.5, (ax * sa + ay * ca) * 1.5, true)
                        fire(bx - 3, by - 3, (ax * ca + ay * sa) * 1.5, (-ax * sa + ay * ca) * 1.5, true)
                    }
                    play(.laser)
                    e.timer = phase2 ? 55 : 90
                }
            }
            enemies[i] = e
        }
        // Contact damage
        let hb = heroBox()
        for e in enemies where e.hp > 0 && e.stun == 0 {
            let size = e.kind == .boss ? 18 : 10
            let eb = Box(Int(e.x.rounded(.down)) + 1, Int(e.y.rounded(.down)) + 1, size, size)
            if eb.intersects(hb) {
                var dmg = 1
                if e.kind == .charger || e.kind == .boss { dmg = 2 }
                let half: Float = e.kind == .boss ? 10 : 6
                hurtPlayer(dmg, e.x + half, e.y + half)
            }
        }
        enemies.removeAll(where: { $0.hp <= 0 })
    }

    private func updateProjectiles() {
        let hb = heroBox()
        var keep: [Proj] = []
        for var p in projs {
            p.x += p.dx
            p.y += p.dy
            p.life -= 1
            let size = p.big ? 6 : 4
            let ix = Int(p.x.rounded(.down))
            let iy = Int(p.y.rounded(.down))
            var dead = p.life <= 0
            let cx = ix + size / 2
            let cy = iy + size / 2
            if cx < 0 || cy < 0 || cx >= 160 || cy >= 128 {
                dead = true
            } else {
                let ch = tileChar(room, cx / 16, cy / 16)
                if ch != "w" && ch != "." && ch != "," && ch != "f" && !isItemChar(ch) { dead = true }
            }
            if !dead && Box(ix, iy, size, size).intersects(hb) {
                hurtPlayer(1, p.x, p.y)
                dead = true
            }
            if !dead { keep.append(p) }
        }
        projs = keep
    }

    private func isItemChar(_ ch: Character) -> Bool {
        switch ch {
        case "g", "k", "h", "v", "C": return true
        default: return false
        }
    }

    // MARK: Items

    private func collectTile(_ tx: Int, _ ty: Int, _ byBoomerang: Bool) {
        let ch = tileChar(room, tx, ty)
        switch ch {
        case "g":
            gems += 1
            play(.coin)
            setTile(room, tx, ty, floorChar(room))
        case "k":
            keys += 1
            play(.pickup)
            bannerText = "GOT A KEY"
            bannerTimer = 70
            setTile(room, tx, ty, floorChar(room))
        case "v":
            hp = min(maxHearts * 2, hp + 2)
            play(.powerup)
            setTile(room, tx, ty, floorChar(room))
        case "h":
            if byBoomerang { return }
            maxHearts = min(8, maxHearts + 1)
            hp = maxHearts * 2
            play(.powerup)
            bannerText = "HEART CONTAINER"
            bannerTimer = 100
            setTile(room, tx, ty, floorChar(room))
        case "C":
            if byBoomerang { return }
            mode = .win
            winTimer = 0
            playMusic(Tunes.chill)
            play(.win)
        default:
            break
        }
    }

    private func updatePickups() {
        let hb = heroBox()
        collectTile((hb.x + 4) / 16, (hb.y + 4) / 16, false)
        var keep: [Drop] = []
        for var d in drops {
            d.life -= 1
            let db = Box(Int(d.x.rounded(.down)), Int(d.y.rounded(.down)), 8, 8)
            if db.intersects(hb) {
                if d.kind == 0 {
                    gems += 1
                    play(.coin)
                } else {
                    hp = min(maxHearts * 2, hp + 2)
                    play(.pickup)
                }
                continue
            }
            if d.life > 0 { keep.append(d) }
        }
        drops = keep
    }

    // MARK: Boomerang and sword

    private func throwBoomerang() {
        if boomActive { return }
        boomActive = true
        boomOut = true
        boomDist = 0
        boomX = px + 6
        boomY = py + 6
        boomDX = 0
        boomDY = 0
        switch facing {
        case 0: boomDY = 1
        case 1: boomDY = -1
        case 2: boomDX = -1
        default: boomDX = 1
        }
        play(.shoot)
    }

    private func updateBoomerang() {
        if !boomActive { return }
        if boomOut {
            boomX += boomDX * 3
            boomY += boomDY * 3
            boomDist += 3
            let ix = Int(boomX.rounded(.down))
            let iy = Int(boomY.rounded(.down))
            var turn = boomDist >= 64
            if ix < 0 || iy < 0 || ix >= 160 || iy >= 128 {
                turn = true
            } else {
                let ch = tileChar(room, ix / 16, iy / 16)
                if isSolidChar(ch) && ch != "w" { turn = true }
            }
            if turn { boomOut = false }
        } else {
            let tx = px + 6 - boomX
            let ty = py + 6 - boomY
            let d = sqrt(tx * tx + ty * ty)
            if d < 7 {
                boomActive = false
                return
            }
            boomX += tx / d * 3.5
            boomY += ty / d * 3.5
        }
        let bx = Int(boomX.rounded(.down))
        let by = Int(boomY.rounded(.down))
        // collect items on the way
        if bx >= 0 && by >= 0 && bx < 160 && by < 128 {
            collectTile(bx / 16, by / 16, true)
        }
        for i in 0..<drops.count {
            let db = Box(Int(drops[i].x.rounded(.down)), Int(drops[i].y.rounded(.down)), 8, 8)
            if db.contains(bx, by) {
                if drops[i].kind == 0 { gems += 1 } else { hp = min(maxHearts * 2, hp + 2) }
                drops[i].life = 0
                play(.coin)
            }
        }
        drops.removeAll(where: { $0.life <= 0 })
        let bb = Box(bx - 3, by - 3, 6, 6)
        for i in 0..<enemies.count {
            let e = enemies[i]
            if e.hp <= 0 { continue }
            let size = e.kind == .boss ? 20 : 12
            let eb = Box(Int(e.x.rounded(.down)), Int(e.y.rounded(.down)), size, size)
            if eb.intersects(bb) {
                damageEnemy(i, 1, boomDX, boomDY, 90)
                boomOut = false
            }
        }
        enemies.removeAll(where: { $0.hp <= 0 })
    }

    private func swordHitBox() -> Box {
        let hx = Int(px.rounded(.down)) + 6
        let hy = Int(py.rounded(.down)) + 6
        switch facing {
        case 0: return Box(hx - 9, hy + 3, 18, 14)
        case 1: return Box(hx - 9, hy - 17, 18, 14)
        case 2: return Box(hx - 17, hy - 9, 14, 18)
        default: return Box(hx + 3, hy - 9, 14, 18)
        }
    }

    private func updateSwing() {
        if swingT <= 0 { return }
        swingT += 1
        if swingT > 13 {
            swingT = 0
            return
        }
        if swingT < 3 || swingT > 11 { return }
        let hit = swordHitBox()
        for i in 0..<enemies.count {
            let e = enemies[i]
            if e.hp <= 0 { continue }
            let size = e.kind == .boss ? 20 : 12
            let eb = Box(Int(e.x.rounded(.down)), Int(e.y.rounded(.down)), size, size)
            if eb.intersects(hit) {
                var kx: Float = 0
                var ky: Float = 0
                switch facing {
                case 0: ky = 1
                case 1: ky = -1
                case 2: kx = -1
                default: kx = 1
                }
                damageEnemy(i, 1, kx, ky, 30)
            }
        }
        enemies.removeAll(where: { $0.hp <= 0 })
        if !swingCut {
            swingCut = true
            let hx = Int(px.rounded(.down)) + 6
            let hy = Int(py.rounded(.down)) + 6
            var fx = hx
            var fy = hy
            switch facing {
            case 0: fy += 12
            case 1: fy -= 12
            case 2: fx -= 12
            default: fx += 12
            }
            if fx >= 0 && fy >= 0 {
                let tx = fx / 16
                let ty = fy / 16
                if tileChar(room, tx, ty) == "b" {
                    setTile(room, tx, ty, floorChar(room))
                    play(.hit)
                    let r = rng.int(100)
                    if r < 40 {
                        drops.append(Drop(x: Float(tx * 16 + 4), y: Float(ty * 16 + 4), kind: 0, life: 500))
                    } else if r < 55 {
                        drops.append(Drop(x: Float(tx * 16 + 4), y: Float(ty * 16 + 4), kind: 1, life: 500))
                    }
                }
            }
        }
    }

    // MARK: Scrolling between rooms

    private func beginScroll(_ dx: Int, _ dy: Int) {
        let target = neighbour(dx, dy)
        if target < 0 { return }
        scrollDX = dx
        scrollDY = dy
        scrollT = 0
        scrollTo = target
        incoming = spawnEnemies(target)
        projs = []
        boomActive = false
        swingT = 0
        mode = .scroll
    }

    private func finishScroll() {
        if scrollDX > 0 || scrollDX < 0 { px -= Float(160 * scrollDX) }
        if scrollDY > 0 || scrollDY < 0 { py -= Float(128 * scrollDY) }
        px = clamp(px, 0, 148)
        py = clamp(py, 0, 116)
        room = scrollTo
        enemies = incoming
        incoming = []
        drops = []
        if !visited[room] {
            visited[room] = true
            scoreBump()
        }
        mode = .play
        unstick()
        if isDungeon(room) {
            playMusic(Tunes.tense)
        } else {
            playMusic(Tunes.adventure)
        }
        if room == 11 && !bossDead {
            bannerText = "BOSS"
            bannerTimer = 80
        }
    }

    private func scoreBump() {
        play(.select)
    }

    // MARK: Update

    override func update(_ input: InputState) {
        frame += 1
        if maps.isEmpty { newGame() }
        switch mode {
        case .title:
            if input.aPressed || input.startPressed {
                newGame()
                mode = .play
                play(.confirm)
            }
        case .play:
            updatePlay(input)
        case .scroll:
            scrollT += 1
            if scrollT >= scrollLen { finishScroll() }
        case .dead:
            deadTimer += 1
            if deadTimer > 50 && (input.aPressed || input.startPressed) {
                newGame()
                mode = .play
                play(.confirm)
            }
        case .win:
            winTimer += 1
            if winTimer > 90 && (input.aPressed || input.startPressed) {
                newGame()
                mode = .title
                play(.confirm)
            }
        }
    }

    private func updatePlay(_ input: InputState) {
        if input.startPressed {
            paused = !paused
            play(.pause)
        }
        if paused { return }
        if bannerTimer > 0 { bannerTimer -= 1 }
        if invuln > 0 { invuln -= 1 }

        // Knockback
        if kbTimer > 0 {
            kbTimer -= 1
            moveHero(kbX, 0)
            moveHero(0, kbY)
        }

        pushing = false
        if swingT == 0 && kbTimer == 0 {
            let dx = input.dx
            let dy = input.dy
            if dx != 0 || dy != 0 {
                let speed: Float = 1.4
                if dx != 0 && dy != 0 {
                    // diagonal: keep the last facing, move on both axes
                    moveHero(Float(dx) * speed * 0.75, 0)
                    moveHero(0, Float(dy) * speed * 0.75)
                } else {
                    moveHero(Float(dx) * speed, Float(dy) * speed)
                    if dx < 0 { facing = 2 }
                    if dx > 0 { facing = 3 }
                    if dy < 0 { facing = 1 }
                    if dy > 0 { facing = 0 }
                }
                walkTimer += 1
            } else {
                walkTimer = 0
            }
            if input.aPressed {
                swingT = 1
                swingCut = false
                play(.sword)
            } else if input.bPressed {
                throwBoomerang()
            }
        }
        if !pushing { pushTimer = 0 }

        updateSwing()
        updateBoomerang()
        updateEnemies()
        updateProjectiles()
        updatePickups()

        if mode != .play { return }

        // Edge scrolling
        let cx = px + 6
        let cy = py + 6
        if cx < 0 { beginScroll(-1, 0) }
        else if cx >= 160 { beginScroll(1, 0) }
        else if cy < 0 { beginScroll(0, -1) }
        else if cy >= 128 { beginScroll(0, 1) }
    }

    // MARK: Drawing

    override func draw(_ c: Canvas) {
        if maps.isEmpty { newGame() }
        c.clear(0)
        c.cameraX = 0
        c.cameraY = 0
        switch mode {
        case .title:
            drawTitle(c)
        case .play, .dead, .win:
            drawRoom(c, room, enemies, 0, 0, true)
            drawHUD(c)
            if mode == .dead { drawDead(c) }
            if mode == .win { drawWin(c) }
            if paused && mode == .play {
                c.fillRect(48, 64, 64, 20, 18)
                c.strokeRect(48, 64, 64, 20, 15)
                c.textCentered("PAUSED", y: 71, 17)
            }
        case .scroll:
            let horizontal = scrollDX != 0
            let size = horizontal ? 160 : 128
            let s = scrollT * size / max(1, scrollLen)
            let oox = -scrollDX * s
            let ooy = -scrollDY * s
            drawRoom(c, room, enemies, oox, ooy, true)
            let nox = scrollDX * (160 - (horizontal ? s : 0))
            let noy = scrollDY * (128 - (horizontal ? 0 : s))
            drawRoom(c, scrollTo, incoming, nox, noy, false)
            drawHUD(c)
        }
    }

    private func drawOutlined(_ c: Canvas, _ s: Sprite, _ x: Int, _ y: Int) {
        c.draw(s, x - 1, y, solid: 3)
        c.draw(s, x + 1, y, solid: 3)
        c.draw(s, x, y - 1, solid: 3)
        c.draw(s, x, y + 1, solid: 3)
        c.draw(s, x, y)
    }

    private func drawRoom(_ c: Canvas, _ r: Int, _ list: [Enemy], _ ox: Int, _ oy: Int, _ live: Bool) {
        c.cameraX = -ox
        c.cameraY = -(16 + oy)
        let dungeon = isDungeon(r)
        for ty in 0..<8 {
            for tx in 0..<10 {
                drawTile(c, tileChar(r, tx, ty), tx * 16, ty * 16, tx, ty, dungeon)
            }
        }
        if live {
            for d in drops {
                if d.life < 120 && (d.life / 4) % 2 == 0 { continue }
                let bob = (frame / 10) % 2
                if d.kind == 0 {
                    drawOutlined(c, TinyQuest.gemSprite, Int(d.x), Int(d.y) + bob)
                } else {
                    drawOutlined(c, TinyQuest.heartFull, Int(d.x), Int(d.y) + bob)
                }
            }
        }
        for e in list { drawEnemy(c, e) }
        if live {
            for p in projs {
                let size = p.big ? 6 : 4
                c.fillRect(Int(p.x) - 1, Int(p.y) - 1, size + 2, size + 2, 3)
                c.fillRect(Int(p.x), Int(p.y), size, size, p.big ? 24 : 6)
                c.fillRect(Int(p.x) + 1, Int(p.y) + 1, size - 2, size - 2, p.big ? 15 : 12)
            }
            drawHero(c)
            drawBoomerang(c)
        }
        c.cameraX = 0
        c.cameraY = 0
    }

    private func drawTile(_ c: Canvas, _ ch: Character, _ x: Int, _ y: Int, _ tx: Int, _ ty: Int, _ dungeon: Bool) {
        if dungeon {
            c.fillRect(x, y, 16, 16, ((tx + ty) % 2 == 0) ? 19 : 20)
        } else {
            c.fillRect(x, y, 16, 16, 0)
            if (tx * 7 + ty * 13) % 5 == 0 {
                c.setPixel(x + 4, y + 9, 1)
                c.setPixel(x + 5, y + 8, 1)
                c.setPixel(x + 6, y + 9, 1)
                c.setPixel(x + 11, y + 4, 1)
                c.setPixel(x + 12, y + 3, 1)
            }
        }
        switch ch {
        case ",":
            c.fillRect(x, y, 16, 16, 2)
            c.setPixel(x + 3, y + 4, 0)
            c.setPixel(x + 10, y + 11, 0)
        case "#":
            c.fillRect(x, y, 16, 16, 7)
            for row in 0..<3 {
                let yy = y + row * 5
                c.hline(x, yy + 4, 16, 8)
                let off = (row + ty) % 2 == 0 ? 4 : 10
                c.vline(x + off, yy, 4, 8)
                c.vline(x + (off + 8) % 16, yy, 4, 8)
            }
            c.hline(x, y + 15, 16, 8)
        case "X":
            c.fillRect(x, y, 16, 16, 21)
            for row in 0..<2 {
                let yy = y + row * 8
                c.hline(x, yy + 7, 16, 22)
                let off = (row + ty) % 2 == 0 ? 4 : 12
                c.vline(x + off, yy, 7, 22)
            }
            c.hline(x, y, 16, 22)
        case "T":
            c.fillRect(x + 6, y + 11, 4, 5, 6)
            c.fillCircle(x + 8, y + 7, 7, 3)
            c.fillCircle(x + 8, y + 7, 6, 4)
            c.fillCircle(x + 6, y + 5, 3, 5)
            c.setPixel(x + 10, y + 9, 5)
        case "b":
            c.fillCircle(x + 8, y + 9, 6, 3)
            c.fillCircle(x + 8, y + 9, 5, 5)
            c.fillCircle(x + 6, y + 7, 2, 1)
        case "w":
            c.fillRect(x, y, 16, 16, 9)
            let ph = (frame / 14 + tx) % 2
            c.hline(x + 2 + ph * 2, y + 5, 5, 10)
            c.hline(x + 8 - ph * 2, y + 11, 5, 10)
        case "B", "H", "K":
            c.fillRect(x + 1, y + 1, 14, 14, 3)
            c.fillRect(x + 2, y + 2, 12, 12, 7)
            c.fillRect(x + 4, y + 4, 8, 8, 8)
            c.hline(x + 2, y + 2, 12, 13)
        case "D":
            c.fillRect(x, y, 16, 16, 29)
            c.strokeRect(x, y, 16, 16, 3)
            c.fillCircle(x + 8, y + 6, 2, 15)
            c.fillRect(x + 7, y + 7, 2, 5, 15)
        case "g":
            drawOutlined(c, TinyQuest.gemSprite, x + 4, y + 5 + (frame / 15) % 2)
        case "k":
            drawOutlined(c, TinyQuest.keySprite, x + 4, y + 4 + (frame / 15) % 2)
        case "v":
            drawOutlined(c, TinyQuest.heartFull, x + 4, y + 5)
        case "h":
            drawOutlined(c, TinyQuest.containerSprite, x + 3, y + 4 + (frame / 12) % 2)
        case "C":
            drawOutlined(c, TinyQuest.crystalSprite, x + 3, y + 3 + (frame / 12) % 2)
        default:
            break
        }
    }

    private func drawEnemy(_ c: Canvas, _ e: Enemy) {
        let ix = Int(e.x.rounded(.down))
        let iy = Int(e.y.rounded(.down))
        let flash = e.hurt > 0 && (e.hurt / 2) % 2 == 0
        let frameIdx = (e.anim / 12) % 2
        switch e.kind {
        case .slime:
            c.draw(TinyQuest.slimeSprites[frameIdx], ix, iy, solid: flash ? 17 : nil)
        case .charger:
            var spr = TinyQuest.chargerSprites[frameIdx]
            if e.state == 1 && (e.timer / 3) % 2 == 0 { spr = spr.recolored(14, 15) }
            c.draw(spr, ix, iy, solid: flash ? 17 : nil)
        case .shooter:
            c.draw(TinyQuest.shooterSprite, ix, iy, flipX: frameIdx == 1, solid: flash ? 17 : nil)
            // snout marker shows aim direction
            let mx = ix + 6 + Int(e.dx) * 7
            let my = iy + 6 + Int(e.dy) * 7
            c.fillRect(mx - 1, my - 1, 3, 3, 3)
        case .boss:
            let cx = ix + 10
            let cy = iy + 10
            let body = flash ? 17 : 24
            c.fillCircle(cx, cy, 10, 3)
            c.fillCircle(cx, cy, 9, body)
            c.fillCircle(cx, cy + 3, 6, flash ? 17 : 15)
            c.fillRect(cx - 7, cy - 4, 5, 5, 17)
            c.fillRect(cx + 3, cy - 4, 5, 5, 17)
            let lookX = hasPlayerRight(Float(cx)) ? 1 : 0
            c.fillRect(cx - 6 + lookX * 2, cy - 3, 3, 3, 3)
            c.fillRect(cx + 4 + lookX * 2 - 1, cy - 3, 3, 3, 3)
            c.fillRect(cx - 6, iy - 2, 3, 3, 14)
            c.fillRect(cx + 3, iy - 2, 3, 3, 14)
            if e.hp <= 6 { c.hline(cx - 4, cy + 6, 8, 14) }
        }
    }

    private func hasPlayerRight(_ x: Float) -> Bool { return px + 6 > x }

    private func drawHero(_ c: Canvas) {
        if invuln > 0 && (invuln / 3) % 2 == 0 { return }
        let ix = Int(px.rounded(.down))
        let iy = Int(py.rounded(.down))
        let f = (walkTimer / 7) % 2
        switch facing {
        case 0: c.draw(TinyQuest.heroDown[f], ix, iy)
        case 1: c.draw(TinyQuest.heroUp[f], ix, iy)
        case 2: c.draw(TinyQuest.heroSide[f], ix, iy)
        default: c.draw(TinyQuest.heroSide[f], ix, iy, flipX: true)
        }
        if swingT > 0 {
            let hx = ix + 6
            let hy = iy + 6
            let phase = min(3, (swingT - 1) / 3)
            let offs: [Int] = [-6, -2, 2, 6]
            let o = offs[phase]
            var bx = 0
            var by = 0
            var bw = 3
            var bh = 11
            switch facing {
            case 0:
                bx = hx - 1 - o
                by = hy + 4
            case 1:
                bx = hx - 1 + o
                by = hy - 15
            case 2:
                bx = hx - 15
                by = hy - 1 + o
                bw = 11
                bh = 3
            default:
                bx = hx + 4
                by = hy - 1 - o
                bw = 11
                bh = 3
            }
            c.fillRect(bx - 1, by - 1, bw + 2, bh + 2, 3)
            c.fillRect(bx, by, bw, bh, 13)
            if facing == 0 || facing == 1 {
                c.fillRect(bx - 1, facing == 0 ? by : by + bh - 2, 5, 2, 15)
            } else {
                c.fillRect(facing == 2 ? bx + bw - 2 : bx, by - 1, 2, 5, 15)
            }
        }
    }

    private func drawBoomerang(_ c: Canvas) {
        if !boomActive { return }
        let bx = Int(boomX.rounded(.down))
        let by = Int(boomY.rounded(.down))
        c.fillRect(bx - 4, by - 4, 8, 8, 3)
        let t = (frame / 2) % 4
        switch t {
        case 0:
            c.fillRect(bx - 3, by - 3, 6, 2, 15)
            c.fillRect(bx - 3, by - 3, 2, 6, 15)
        case 1:
            c.fillRect(bx - 3, by - 3, 6, 2, 15)
            c.fillRect(bx + 1, by - 3, 2, 6, 15)
        case 2:
            c.fillRect(bx - 3, by + 1, 6, 2, 15)
            c.fillRect(bx + 1, by - 3, 2, 6, 15)
        default:
            c.fillRect(bx - 3, by + 1, 6, 2, 15)
            c.fillRect(bx - 3, by - 3, 2, 6, 15)
        }
    }

    private func drawHUD(_ c: Canvas) {
        c.cameraX = 0
        c.cameraY = 0
        c.fillRect(0, 0, 160, 16, 18)
        c.hline(0, 15, 160, 28)
        // hearts (two rows if needed)
        for i in 0..<maxHearts {
            let hx = 3 + (i % 5) * 8
            let hy = i < 5 ? 2 : 9
            let units = hp - i * 2
            if units >= 2 {
                c.draw(TinyQuest.heartFull, hx, hy)
            } else if units == 1 {
                c.draw(TinyQuest.heartHalf, hx, hy)
            } else {
                c.draw(TinyQuest.heartEmpty, hx, hy)
            }
        }
        c.draw(TinyQuest.keySprite, 48, 4)
        c.text("X" + String(keys), 57, 5, 17)
        c.draw(TinyQuest.gemSprite, 74, 4)
        c.text("X" + zeroPad(gems, 3), 83, 5, 17)
        // boomerang icon
        c.text("B", 106, 5, 28)
        if !boomActive {
            c.fillRect(114, 5, 6, 2, 15)
            c.fillRect(114, 5, 2, 6, 15)
        }
        // mini-map
        for ry in 0..<3 {
            for rx in 0..<4 {
                let idx = ry * 4 + rx
                var col = 28
                if visited[idx] { col = 17 }
                if idx == room && (frame / 15) % 2 == 0 { col = 15 }
                if idx != room && !visited[idx] { col = 22 }
                c.fillRect(131 + rx * 7, 2 + ry * 4, 6, 3, col)
            }
        }
        if bannerTimer > 0 && mode == .play {
            let w = c.textWidth(bannerText)
            let bx = (160 - w) / 2
            c.fillRect(bx - 3, 20, w + 6, 9, 18)
            c.strokeRect(bx - 3, 20, w + 6, 9, 28)
            c.text(bannerText, bx, 22, 15)
        }
    }

    private func drawTitle(_ c: Canvas) {
        c.fillRect(0, 0, 160, 144, 0)
        // scenery: a few trees and the hero
        for i in 0..<10 {
            drawTile(c, "T", i * 16, 0, i, 0, false)
            drawTile(c, "T", i * 16, 128, i, 8, false)
        }
        for i in 0..<10 {
            drawTile(c, i == 4 || i == 5 ? "," : ".", i * 16, 96, i, 6, false)
        }
        drawTile(c, "b", 20, 96, 1, 6, false)
        drawTile(c, "w", 120, 96, 7, 6, false)
        c.fillRect(14, 28, 132, 40, 18)
        c.strokeRect(14, 28, 132, 40, 15)
        c.strokeRect(16, 30, 128, 36, 28)
        c.textCentered("TINY", y: 34, 15, scale: 3)
        c.textCentered("QUEST", y: 50, 17, scale: 2)
        let f = (frame / 10) % 2
        c.draw(TinyQuest.heroDown[f], 74, 80)
        c.draw(TinyQuest.slimeSprites[f], 40, 84)
        c.draw(TinyQuest.chargerSprites[f], 108, 84)
        if (frame / 30) % 2 == 0 {
            c.fillRect(34, 112, 92, 11, 18)
            c.textCentered("PRESS A TO START", y: 115, 17)
        }
    }

    private func drawDead(_ c: Canvas) {
        c.fillRect(24, 44, 112, 56, 18)
        c.strokeRect(24, 44, 112, 56, 14)
        c.textCentered("GAME OVER", y: 52, 14, scale: 2)
        c.textCentered("SCORE " + String(score), y: 70, 17)
        c.textCentered("GEMS " + String(gems) + "  FOES " + String(kills), y: 79, 28)
        if deadTimer > 50 && (frame / 25) % 2 == 0 { c.textCentered("A: TRY AGAIN", y: 90, 15) }
    }

    private func drawWin(_ c: Canvas) {
        for i in 0..<16 {
            let sx = (i * 53 + frame * (1 + i % 3)) % 160
            let sy = (i * 29 + frame * (1 + i % 2)) % 128 + 16
            let col = (i % 2 == 0) ? 15 : 16
            c.fillRect(sx, sy, 2, 2, col)
            c.fillRect(sx - 1, sy, 4, 1, col)
        }
        c.fillRect(14, 40, 132, 62, 18)
        c.strokeRect(14, 40, 132, 62, 15)
        c.textCentered("YOU WIN!", y: 46, 15, scale: 2)
        c.textCentered("THE REALM IS SAFE", y: 62, 17)
        c.textCentered("SCORE " + String(score), y: 72, 17)
        c.textCentered("GEMS " + String(gems) + "  FOES " + String(kills), y: 81, 28)
        if winTimer > 90 && (frame / 25) % 2 == 0 { c.textCentered("A: TITLE", y: 91, 15) }
    }
}

extension Cartridge {
    static let tinyQuest = Cartridge(
        id: "tinyquest", title: "TINY QUEST", genre: "Adventure",
        blurb: "Explore a small realm of twelve screens, find keys, solve block puzzles and defeat the dungeon guardian. Swing your sword and throw your boomerang.",
        controls: "D-PAD move, A sword, B boomerang, START pause.",
        era: .gbc, labelTop: 0x58B848, labelBottom: 0x1C4A2C, factory: { TinyQuest() })
}
