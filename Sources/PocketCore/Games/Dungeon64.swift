#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// DUNGEON 64: a first-person textured raycasting dungeon crawler.
/// DDA raycaster with 64x64 procedural wall textures, fogged floor/ceiling, billboard sprites with a per-column z-buffer,
/// three hand-made levels, fireballs, ghosts and skeletons.
final class Dungeon64: Game {
    // MARK: - Level data

    private static let levels: [[String]] = [
        [
            "################",
            "#P...#........g#",
            "#....#..####...#",
            "#..g.M..#..#.h.#",
            "##.###..#..#.###",
            "#....#..#..#...#",
            "#.S..#..M..#.k.#",
            "#....#..#S.#...#",
            "#..###..#..#####",
            "#....G.....g...#",
            "#.####..####.#.#",
            "#.#k...........#",
            "#.#..####.####.#",
            "#.#..#..G..#...#",
            "#...h#.....#...E",
            "################"
        ],
        [
            "################",
            "#P...#....M...g#",
            "#.##.#.##.#.##.#",
            "#.#..M.#..#..#.#",
            "#.#.##.#.##.#..#",
            "#...#..#....#.##",
            "###.#.##.####..#",
            "#k..#S.....#h..#",
            "#.###.####.#.###",
            "#.....#g.#.....#",
            "#.###.#..#.##.##",
            "#.#.S.##.#..#..#",
            "#.#.#..#.##.#.k#",
            "#...#G.#.S..#..#",
            "#.###..####.##E#",
            "################"
        ],
        [
            "################",
            "#P.....#.......#",
            "#.###.R#.#####.#",
            "#.#g#..#.....#.#",
            "#.#.####.###.#.#",
            "#.#..G...#h#.#.#",
            "#.######.#.#...#",
            "#......#.#.#####",
            "#.####.#.#..S..#",
            "#.#..#.R.#.###.#",
            "#.#g.#...#.#g#.#",
            "#.##.#####.#.#.#",
            "#...kS...G.#.#.#",
            "#.########.#...#",
            "#k....k...h...E#",
            "################"
        ]
    ]
    private static let levelNames: [String] = ["CRYPT GATE", "MOSSY CATACOMBS", "RUNE TEMPLE"]
    private static let tints: [[Int]] = [[256, 232, 200], [212, 256, 214], [232, 222, 256]]
    private static let floorBase: [[Int]] = [[104, 92, 80], [80, 102, 78], [98, 84, 126]]
    private static let ceilBase: [[Int]] = [[64, 58, 74], [44, 68, 62], [54, 44, 86]]

    // MARK: - Static helpers

    private static let cWhite: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    private static let cBlack: UInt32 = TrueColorBuffer.rgb(8, 8, 14)
    private static let cYellow: UInt32 = TrueColorBuffer.rgb(255, 226, 64)
    private static let cRed: UInt32 = TrueColorBuffer.rgb(236, 60, 52)
    private static let cGreen: UInt32 = TrueColorBuffer.rgb(90, 232, 110)
    private static let cCyan: UInt32 = TrueColorBuffer.rgb(100, 240, 255)
    private static let cPanel: UInt32 = TrueColorBuffer.rgb(16, 12, 30)

    static func hash2(_ x: Int, _ y: Int) -> Int {
        var h: Int = x &* 374761393 &+ y &* 668265263
        h = (h ^ (h >> 13)) &* 1274126177
        return (h ^ (h >> 16)) & 0xFFFF
    }

    static func lightFor(_ d: Float) -> Int {
        let v: Float = 256.0 / (1.0 + d * d * 0.05)
        if !v.isFinite { return 14 }
        return max(14, min(256, Int(v)))
    }

    static func wrapAngle(_ a: Float) -> Float {
        if !a.isFinite { return 0 }
        var d = a
        while d > Float.pi { d -= 2 * Float.pi }
        while d < -Float.pi { d += 2 * Float.pi }
        return d
    }

    static func brickRGB(_ x: Int, _ y: Int, _ kind: Int) -> (Int, Int, Int) {
        let row = y / 16
        let off = (row & 1) * 16
        let bx = (x + off) & 63
        let colI = bx / 32
        let lx = bx % 32
        let ly = y % 16
        let n = (hash2(x, y) & 15) - 8
        var r = 150
        var g = 142
        var b = 150
        if kind == 1 {
            r = 128
            g = 140
            b = 118
        }
        if kind == 2 {
            r = 66
            g = 66
            b = 96
        }
        let vary = (hash2(row * 3 + colI, 5 + kind) & 31) - 16
        r += vary + n
        g += vary + n
        b += vary + n
        let mortar = ly < 2 || lx < 2
        if mortar {
            r = 62 + n / 2
            g = 58 + n / 2
            b = 66 + n / 2
            if kind == 2 {
                r = 24
                g = 24
                b = 40
            }
        } else {
            if ly == 2 || lx == 2 {
                r += 18
                g += 18
                b += 18
            }
            if ly == 15 || lx == 31 {
                r -= 24
                g -= 24
                b -= 24
            }
        }
        if kind == 1 {
            let m = (hash2(x >> 2, y >> 2) & 15) + (hash2(x >> 3, (y >> 3) + 50) & 15)
            var thresh = 20
            if mortar { thresh = 12 }
            if m > thresh {
                r = 44 + n
                g = 116 + n * 2
                b = 42 + n
            }
        }
        return (r, g, b)
    }

    static func doorPixel(_ x: Int, _ y: Int) -> UInt32 {
        let plank = x / 16
        let px = x % 16
        let v0 = (hash2(plank, 7) & 15) - 8
        let grain = (hash2(x, 3) & 7) + (hash2(x >> 1, y >> 3) & 7)
        var r = 150 + v0 + grain
        var g = 98 + v0 + grain / 2
        var b = 50 + v0 / 2
        if px == 0 {
            r = 40
            g = 24
            b = 12
        } else if px == 15 {
            r -= 30
            g -= 22
            b -= 12
        }
        let band = (y >= 8 && y < 14) || (y >= 50 && y < 56)
        if band {
            r = 64
            g = 66
            b = 76
            if y == 8 || y == 50 {
                r = 112
                g = 114
                b = 126
            }
            if (px == 4 || px == 12) && (y == 11 || y == 53) {
                r = 182
                g = 184
                b = 198
            }
        }
        if x < 3 || x > 60 || y < 3 || y > 60 {
            r = 82 + v0
            g = 52 + v0 / 2
            b = 28
        }
        let dx = x - 50
        let dy = y - 34
        let d2 = dx * dx + dy * dy
        if d2 <= 25 && d2 >= 9 {
            r = 236
            g = 196
            b = 62
        }
        return TrueColorBuffer.rgb(r, g, b)
    }

    static func runePixel(_ x: Int, _ y: Int) -> UInt32 {
        let base = brickRGB(x, y, 2)
        var r = base.0
        var g = base.1
        var b = base.2
        let dx = x - 32
        let dy = y - 32
        let dist: Float = sqrt(Float(dx * dx + dy * dy))
        var glyph = false
        if abs(dist - 20) < 1.4 { glyph = true }
        if abs(dist - 10) < 1.2 { glyph = true }
        if abs(dx) < 2 && abs(dy) < 18 { glyph = true }
        if abs(dy) < 2 && abs(dx) < 18 { glyph = true }
        let diamond = abs(dx) + abs(dy)
        if diamond >= 25 && diamond <= 26 { glyph = true }
        if glyph {
            r = 90
            g = 240
            b = 255
        } else {
            let glow = max(0, 34 - Int(abs(dist - 20) * 4))
            r += glow / 4
            g += glow
            b += glow + glow / 2
        }
        return TrueColorBuffer.rgb(r, g, b)
    }

    static func inArch(_ dx: Int, _ y: Int, _ rad: Int) -> Bool {
        if y >= 30 { return abs(dx) <= rad }
        let dy = y - 30
        return dx * dx + dy * dy <= rad * rad
    }

    static func portalPixel(_ x: Int, _ y: Int) -> UInt32 {
        let base = brickRGB(x, y, 0)
        var r = base.0
        var g = base.1
        var b = base.2
        let dx = x - 32
        if inArch(dx, y, 17) {
            let t: Float = Float(y) / 63.0
            r = 255
            g = Int(250.0 - 70.0 * t)
            b = Int(215.0 - 130.0 * t)
            if abs(dx) < 4 {
                g = 255
                b = max(b, 235)
            }
        } else if inArch(dx, y, 20) {
            r = 36
            g = 28
            b = 20
        }
        return TrueColorBuffer.rgb(r, g, b)
    }

    private static let texPtr: UnsafeMutablePointer<UInt32> = Dungeon64.buildTextures()

    static func buildTextures() -> UnsafeMutablePointer<UInt32> {
        let ptr = UnsafeMutablePointer<UInt32>.allocate(capacity: 6 * 4096)
        ptr.initialize(repeating: 0xFF00_0000, count: 6 * 4096)
        for y in 0..<64 {
            for x in 0..<64 {
                let o = y * 64 + x
                let s = brickRGB(x, y, 0)
                ptr[1 * 4096 + o] = TrueColorBuffer.rgb(s.0, s.1, s.2)
                let m = brickRGB(x, y, 1)
                ptr[2 * 4096 + o] = TrueColorBuffer.rgb(m.0, m.1, m.2)
                ptr[3 * 4096 + o] = doorPixel(x, y)
                ptr[4 * 4096 + o] = runePixel(x, y)
                ptr[5 * 4096 + o] = portalPixel(x, y)
            }
        }
        return ptr
    }

    // MARK: - Nested types

    struct Pix {
        var w: Int
        var h: Int
        var d: [UInt32]

        init(_ w: Int, _ h: Int) {
            self.w = w
            self.h = h
            self.d = [UInt32](repeating: 0, count: w * h)
        }

        mutating func set(_ x: Int, _ y: Int, _ c: UInt32) {
            if x < 0 || y < 0 || x >= w || y >= h { return }
            d[y * w + x] = c
        }

        mutating func rect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: UInt32) {
            if rw <= 0 || rh <= 0 { return }
            for yy in y..<(y + rh) {
                for xx in x..<(x + rw) { set(xx, yy, c) }
            }
        }

        mutating func disc(_ cx: Int, _ cy: Int, _ r: Int, _ c: UInt32) {
            if r < 0 { return }
            for yy in (cy - r)...(cy + r) {
                for xx in (cx - r)...(cx + r) {
                    let dx = xx - cx
                    let dy = yy - cy
                    if dx * dx + dy * dy <= r * r + r / 2 { set(xx, yy, c) }
                }
            }
        }

        mutating func outline(_ c: UInt32) {
            let src = d
            for y in 0..<h {
                for x in 0..<w {
                    if src[y * w + x] != 0 { continue }
                    var near = false
                    if x > 0 && src[y * w + x - 1] != 0 { near = true }
                    if x < w - 1 && src[y * w + x + 1] != 0 { near = true }
                    if y > 0 && src[(y - 1) * w + x] != 0 { near = true }
                    if y < h - 1 && src[(y + 1) * w + x] != 0 { near = true }
                    if near { d[y * w + x] = c }
                }
            }
        }
    }

    struct Spr {
        var w: Int
        var h: Int
        var pix: [UInt32]
    }

    struct Enemy {
        var x: Float
        var y: Float
        var kind: Int
        var hp: Int
        var alert: Int = 0
        var cool: Int = 0
        var flash: Int = 0
        var dead: Bool = false
        var deathT: Int = 0
        var phase: Float = 0
    }

    struct Pickup {
        var x: Float
        var y: Float
        var kind: Int
        var taken: Bool = false
        var phase: Float = 0
    }

    struct Shot {
        var x: Float
        var y: Float
        var dx: Float
        var dy: Float
        var life: Int
    }

    struct Puff {
        var x: Float
        var y: Float
        var life: Int
    }

    struct SItem {
        var depth: Float
        var sx: Int
        var bottom: Int
        var sw: Int
        var sh: Int
        var spr: Int
        var light: Int
        var flash: Bool
    }

    enum Phase { case title, playing, dead, levelDone, won }

    // MARK: - Sprites

    static func col(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
        return TrueColorBuffer.rgb(r, g, b)
    }

    static func makeGhost() -> Spr {
        var p = Pix(24, 28)
        let body = col(208, 226, 255)
        let shade = col(140, 168, 236)
        let dark = col(18, 18, 44)
        p.disc(12, 10, 9, body)
        p.rect(3, 10, 19, 13, body)
        for x in 3..<22 {
            var bottom = 23
            if ((x / 3) & 1) == 0 { bottom = 26 }
            p.rect(x, 23, 1, bottom - 22, body)
        }
        p.rect(0, 14, 4, 6, body)
        p.rect(20, 14, 4, 6, body)
        for y in 0..<28 {
            for x in 16..<24 {
                if p.d[y * 24 + x] != 0 { p.d[y * 24 + x] = shade }
            }
        }
        p.rect(7, 8, 4, 5, dark)
        p.rect(14, 8, 4, 5, dark)
        p.rect(9, 16, 6, 4, dark)
        p.rect(8, 9, 1, 2, col(255, 255, 255))
        p.rect(15, 9, 1, 2, col(255, 255, 255))
        p.outline(col(30, 40, 110))
        return Spr(w: p.w, h: p.h, pix: p.d)
    }

    static func makeSkeleton() -> Spr {
        var p = Pix(24, 32)
        let bone = col(238, 232, 210)
        let boneDark = col(152, 144, 122)
        let dark = col(14, 10, 12)
        p.disc(12, 7, 6, bone)
        p.rect(8, 11, 9, 4, bone)
        p.rect(8, 6, 3, 3, dark)
        p.rect(14, 6, 3, 3, dark)
        p.set(9, 7, col(255, 70, 40))
        p.set(15, 7, col(255, 70, 40))
        p.rect(12, 9, 1, 2, dark)
        for x in stride(from: 9, through: 15, by: 2) { p.rect(x, 13, 1, 2, dark) }
        p.rect(11, 15, 3, 10, bone)
        for i in 0..<4 {
            p.rect(6, 16 + i * 2, 13, 1, bone)
            p.rect(6, 17 + i * 2, 13, 1, boneDark)
        }
        p.rect(3, 16, 3, 10, bone)
        p.rect(19, 16, 3, 10, bone)
        p.rect(2, 26, 4, 2, bone)
        p.rect(21, 26, 3, 2, bone)
        p.rect(22, 8, 2, 18, col(196, 206, 228))
        p.rect(8, 25, 9, 3, bone)
        p.rect(8, 28, 3, 4, bone)
        p.rect(14, 28, 3, 4, bone)
        p.outline(dark)
        return Spr(w: p.w, h: p.h, pix: p.d)
    }

    static func makeKey() -> Spr {
        var p = Pix(16, 16)
        let gold = col(255, 212, 48)
        p.disc(5, 5, 4, gold)
        p.disc(5, 5, 2, 0)
        p.rect(7, 4, 8, 3, gold)
        p.rect(12, 7, 2, 3, gold)
        p.rect(9, 7, 2, 2, gold)
        p.rect(7, 4, 8, 1, col(255, 246, 170))
        p.outline(col(90, 56, 8))
        return Spr(w: p.w, h: p.h, pix: p.d)
    }

    static func makePotion() -> Spr {
        var p = Pix(16, 16)
        p.disc(8, 10, 5, col(232, 48, 62))
        p.rect(6, 3, 4, 5, col(206, 224, 232))
        p.rect(6, 1, 4, 2, col(156, 104, 52))
        p.rect(5, 9, 2, 3, col(255, 170, 170))
        p.outline(col(60, 8, 16))
        return Spr(w: p.w, h: p.h, pix: p.d)
    }

    static func makeGem() -> Spr {
        var p = Pix(16, 16)
        let cyan = col(70, 232, 255)
        let facet = col(30, 150, 206)
        for dy in -6...6 {
            let hw = 6 - abs(dy)
            p.rect(8 - hw, 8 + dy, hw * 2 + 1, 1, cyan)
            if hw > 0 { p.rect(8 + hw / 2, 8 + dy, hw - hw / 2 + 1, 1, facet) }
        }
        p.rect(6, 5, 2, 2, col(255, 255, 255))
        p.outline(col(10, 40, 70))
        return Spr(w: p.w, h: p.h, pix: p.d)
    }

    static func makeFireball() -> Spr {
        var p = Pix(16, 16)
        p.disc(8, 8, 7, col(255, 110, 20))
        p.disc(8, 8, 5, col(255, 196, 60))
        p.disc(8, 8, 2, col(255, 255, 224))
        return Spr(w: p.w, h: p.h, pix: p.d)
    }

    private static let sprites: [Spr] = [
        Dungeon64.makeGhost(), Dungeon64.makeSkeleton(), Dungeon64.makeKey(),
        Dungeon64.makePotion(), Dungeon64.makeGem(), Dungeon64.makeFireball()
    ]
    private static let sprGhost = 0
    private static let sprSkel = 1
    private static let sprKey = 2
    private static let sprPotion = 3
    private static let sprGem = 4
    private static let sprFire = 5

    // MARK: - State

    private var phase: Phase = .title
    private var frame = 0
    private var level = 0
    private var cells: [UInt8] = [UInt8](repeating: 1, count: 256)
    private var enemies: [Enemy] = []
    private var pickups: [Pickup] = []
    private var shots: [Shot] = []
    private var puffs: [Puff] = []
    private var sitems: [SItem] = []
    private var zbuf: [Float] = [Float](repeating: 0, count: 320)
    private var rowFloor: [UInt32] = [UInt32](repeating: 0, count: 288)
    private var rowCeil: [UInt32] = [UInt32](repeating: 0, count: 288)
    private var posX: Float = 1.5
    private var posY: Float = 1.5
    private var angle: Float = 0
    private var health = 100
    private var keys = 0
    private var keysTotal = 0
    private var gems = 0
    private var gemsTotal = 0
    private var kills = 0
    private var killPoints = 0
    private var levelFrames = 0
    private var castCool = 0
    private var castAnim = 0
    private var hurtFlash = 0
    private var bobPhase: Float = 0
    private var stepTimer = 0
    private var msg = ""
    private var msgTimer = 0
    private var showMap = false
    private var banked = 0
    private var deadTimer = 0
    private var doneTimer = 0
    private var exitX: Float = 0
    private var exitY: Float = 0
    private var lastBonus = 0
    private var tintR = 256
    private var tintG = 256
    private var tintB = 256

    override var score: Int {
        if phase == .levelDone || phase == .won { return max(0, banked) }
        return max(0, banked + gems * 100 + killPoints)
    }

    override init() {
        super.init()
        loadLevel(0, resetHealth: true)
        phase = .title
    }

    override func start() {
        playMusic(Tunes.tense)
    }

    // MARK: - Level loading

    private func loadLevel(_ n: Int, resetHealth: Bool) {
        level = max(0, min(Dungeon64.levels.count - 1, n))
        let rows = Dungeon64.levels[level]
        cells = [UInt8](repeating: 1, count: 256)
        enemies = []
        pickups = []
        shots = []
        puffs = []
        keysTotal = 0
        gemsTotal = 0
        for r in 0..<16 {
            var chars: [Character] = []
            if r < rows.count { chars = Array(rows[r]) }
            for c in 0..<16 {
                var ch: Character = "#"
                if c < chars.count { ch = chars[c] }
                var v: UInt8 = 0
                let fx: Float = Float(c) + 0.5
                let fy: Float = Float(r) + 0.5
                switch ch {
                case "#": v = 1
                case "M": v = 2
                case "R": v = 4
                case "E":
                    v = 3
                    exitX = fx
                    exitY = fy
                case "P":
                    posX = fx
                    posY = fy
                case "G":
                    enemies.append(Enemy(x: fx, y: fy, kind: 0, hp: 2, phase: Float(r * 7 + c)))
                case "S":
                    enemies.append(Enemy(x: fx, y: fy, kind: 1, hp: 3, phase: Float(r * 5 + c)))
                case "k":
                    pickups.append(Pickup(x: fx, y: fy, kind: 1, phase: Float(r + c)))
                    keysTotal += 1
                case "h":
                    pickups.append(Pickup(x: fx, y: fy, kind: 2, phase: Float(r + c)))
                case "g":
                    pickups.append(Pickup(x: fx, y: fy, kind: 0, phase: Float(r + c)))
                    gemsTotal += 1
                default:
                    break
                }
                cells[r * 16 + c] = v
            }
        }
        // face the longest open corridor
        var bestAng: Float = 0
        var bestLen = -1
        for k in 0..<4 {
            let a: Float = Float(k) * Float.pi / 2
            let dxs = Int(round(cos(a)))
            let dys = Int(round(sin(a)))
            var len = 0
            var cx = Int(posX)
            var cy = Int(posY)
            while len < 16 {
                cx += dxs
                cy += dys
                if solidCell(cx, cy) { break }
                len += 1
            }
            if len > bestLen {
                bestLen = len
                bestAng = a
            }
        }
        angle = Dungeon64.wrapAngle(bestAng)
        keys = 0
        gems = 0
        kills = 0
        killPoints = 0
        levelFrames = 0
        castCool = 0
        castAnim = 0
        hurtFlash = 0
        bobPhase = 0
        stepTimer = 0
        msg = ""
        msgTimer = 0
        if resetHealth { health = 100 }
        let t = Dungeon64.tints[level]
        tintR = t[0]
        tintG = t[1]
        tintB = t[2]
        buildRows()
    }

    private func buildRows() {
        let half = 144
        let fb = Dungeon64.floorBase[level]
        let cb = Dungeon64.ceilBase[level]
        for y in 0..<288 {
            if y < half {
                let dy = max(1, half - y)
                let d: Float = Float(half) / Float(dy)
                let f = Dungeon64.lightFor(d)
                rowCeil[y] = TrueColorBuffer.rgb((cb[0] * f) >> 8, (cb[1] * f) >> 8, (cb[2] * f) >> 8)
            } else {
                let dy = max(1, y - half)
                let d: Float = Float(half) / Float(dy)
                let f = Dungeon64.lightFor(d)
                rowFloor[y] = TrueColorBuffer.rgb((fb[0] * f) >> 8, (fb[1] * f) >> 8, (fb[2] * f) >> 8)
            }
        }
    }

    // MARK: - Collision helpers

    private func solidCell(_ cx: Int, _ cy: Int) -> Bool {
        if cx < 0 || cy < 0 || cx >= 16 || cy >= 16 { return true }
        return cells[cy * 16 + cx] != 0
    }

    private func blockedAt(_ x: Float, _ y: Float, _ r: Float) -> Bool {
        let x0 = Int(floor(x - r))
        let x1 = Int(floor(x + r))
        let y0 = Int(floor(y - r))
        let y1 = Int(floor(y + r))
        return solidCell(x0, y0) || solidCell(x1, y0) || solidCell(x0, y1) || solidCell(x1, y1)
    }

    private func lineOfSight(_ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float) -> Bool {
        let dx: Float = x1 - x0
        let dy: Float = y1 - y0
        let dist: Float = sqrt(dx * dx + dy * dy)
        let steps = max(1, Int(dist / 0.25))
        if steps < 2 { return true }
        for i in 1..<steps {
            let t: Float = Float(i) / Float(steps)
            let cx = Int(floor(x0 + dx * t))
            let cy = Int(floor(y0 + dy * t))
            if solidCell(cx, cy) { return false }
        }
        return true
    }

    private func showMsg(_ s: String, _ frames: Int) {
        msg = s
        msgTimer = frames
    }

    // MARK: - Update

    private func hurtPlayer(_ amount: Int) {
        if phase != .playing { return }
        health -= amount
        hurtFlash = 20
        if health <= 0 {
            health = 0
            phase = .dead
            deadTimer = 0
            play(.death)
        } else {
            play(.hurt)
        }
    }

    private func castFireball() {
        let dx = cos(angle)
        let dy = sin(angle)
        shots.append(Shot(x: posX + dx * 0.3, y: posY + dy * 0.3, dx: dx * 0.17, dy: dy * 0.17, life: 90))
        castCool = 16
        castAnim = 8
        play(.shoot)
    }

    private func updateShots() {
        var keep: [Shot] = []
        for s in shots {
            var sh = s
            sh.x += sh.dx
            sh.y += sh.dy
            sh.life -= 1
            if sh.life <= 0 { continue }
            if solidCell(Int(floor(sh.x)), Int(floor(sh.y))) {
                puffs.append(Puff(x: sh.x - sh.dx, y: sh.y - sh.dy, life: 10))
                play(.thud)
                continue
            }
            var hitIndex = -1
            for i in 0..<enemies.count {
                if enemies[i].dead { continue }
                let ex: Float = enemies[i].x - sh.x
                let ey: Float = enemies[i].y - sh.y
                if ex * ex + ey * ey < 0.2 {
                    hitIndex = i
                    break
                }
            }
            if hitIndex >= 0 {
                enemies[hitIndex].hp -= 1
                enemies[hitIndex].flash = 8
                enemies[hitIndex].alert = 200
                puffs.append(Puff(x: sh.x, y: sh.y, life: 10))
                if enemies[hitIndex].hp <= 0 {
                    enemies[hitIndex].dead = true
                    enemies[hitIndex].deathT = 0
                    kills += 1
                    killPoints += enemies[hitIndex].kind == 0 ? 50 : 80
                    play(.stomp)
                } else {
                    play(.hit)
                }
                continue
            }
            keep.append(sh)
        }
        shots = keep
        var keepP: [Puff] = []
        for pf in puffs {
            var q = pf
            q.life -= 1
            if q.life > 0 { keepP.append(q) }
        }
        puffs = keepP
    }

    private func updateEnemies() {
        for i in 0..<enemies.count {
            var e = enemies[i]
            if e.dead {
                if e.deathT < 24 { e.deathT += 1 }
                enemies[i] = e
                continue
            }
            if e.flash > 0 { e.flash -= 1 }
            if e.cool > 0 { e.cool -= 1 }
            let dx: Float = posX - e.x
            let dy: Float = posY - e.y
            let dist: Float = sqrt(dx * dx + dy * dy)
            var sees = false
            if dist < 7.5 { sees = lineOfSight(e.x, e.y, posX, posY) }
            if sees {
                e.alert = 160
            } else if e.alert > 0 {
                e.alert -= 1
            }
            if e.alert > 0 && dist > 0.55 {
                let speed: Float = e.kind == 0 ? 0.028 : 0.021
                let vx: Float = dx / dist * speed
                let vy: Float = dy / dist * speed
                let r: Float = 0.22
                if !blockedAt(e.x + vx, e.y, r) { e.x += vx }
                if !blockedAt(e.x, e.y + vy, r) { e.y += vy }
            }
            if dist < 0.75 && e.cool <= 0 {
                e.cool = e.kind == 0 ? 50 : 60
                enemies[i] = e
                hurtPlayer(e.kind == 0 ? 8 : 14)
                if phase != .playing { return }
                continue
            }
            enemies[i] = e
        }
    }

    private func updatePickups() {
        for i in 0..<pickups.count {
            if pickups[i].taken { continue }
            let dx: Float = pickups[i].x - posX
            let dy: Float = pickups[i].y - posY
            if dx * dx + dy * dy > 0.25 { continue }
            let kind = pickups[i].kind
            if kind == 0 {
                pickups[i].taken = true
                gems += 1
                play(.coin)
                showMsg("GEM +100", 50)
            } else if kind == 1 {
                pickups[i].taken = true
                keys += 1
                play(.powerup)
                showMsg("KEY " + String(keys) + "/" + String(keysTotal), 70)
            } else {
                if health < 100 {
                    pickups[i].taken = true
                    health = min(100, health + 35)
                    play(.pickup)
                    showMsg("HEALTH +35", 50)
                }
            }
        }
    }

    private func updatePlaying(_ input: InputState) {
        levelFrames += 1
        if msgTimer > 0 { msgTimer -= 1 }
        if hurtFlash > 0 { hurtFlash -= 1 }
        if castCool > 0 { castCool -= 1 }
        if castAnim > 0 { castAnim -= 1 }
        if input.selectPressed {
            showMap = !showMap
            play(.blip)
        }
        var moveF: Float = 0
        var moveS: Float = 0
        if input.up { moveF += 1 }
        if input.down { moveF -= 1 }
        if input.b {
            moveS = Float(input.dx)
        } else {
            angle = Dungeon64.wrapAngle(angle + Float(input.dx) * 0.05)
        }
        let dirX: Float = cos(angle)
        let dirY: Float = sin(angle)
        var speed: Float = 0.055
        if moveF != 0 && moveS != 0 { speed = 0.04 }
        let vx: Float = (dirX * moveF - dirY * moveS) * speed
        let vy: Float = (dirY * moveF + dirX * moveS) * speed
        let r: Float = 0.22
        if !blockedAt(posX + vx, posY, r) { posX += vx }
        if !blockedAt(posX, posY + vy, r) { posY += vy }
        if moveF != 0 || moveS != 0 {
            bobPhase += 0.2
            stepTimer += 1
            if stepTimer >= 20 {
                stepTimer = 0
                play(.step)
            }
        }
        if input.a && castCool <= 0 { castFireball() }
        updateShots()
        updateEnemies()
        if phase != .playing { return }
        updatePickups()
        // exit door
        let ex: Float = exitX - posX
        let ey: Float = exitY - posY
        if ex * ex + ey * ey < 1.0 {
            if keys >= keysTotal {
                completeLevel()
            } else if msgTimer <= 0 {
                showMsg("NEED ALL KEYS", 60)
                play(.thud)
            }
        }
    }

    private func completeLevel() {
        let secs = levelFrames / 60
        var bonus = 500 + max(0, 1500 - secs * 10)
        if gems >= gemsTotal { bonus += 300 }
        lastBonus = bonus
        banked += gems * 100 + killPoints + bonus
        doneTimer = 0
        shots = []
        if level >= Dungeon64.levels.count - 1 {
            phase = .won
        } else {
            phase = .levelDone
        }
        play(.win)
    }

    override func update(_ input: InputState) {
        frame += 1
        switch phase {
        case .title:
            angle = Dungeon64.wrapAngle(angle + 0.006)
            if input.aPressed || input.startPressed {
                play(.confirm)
                banked = 0
                loadLevel(0, resetHealth: true)
                phase = .playing
            }
        case .playing:
            updatePlaying(input)
        case .dead:
            deadTimer += 1
            if hurtFlash > 0 { hurtFlash -= 1 }
            if deadTimer > 40 && (input.aPressed || input.startPressed) {
                play(.confirm)
                loadLevel(level, resetHealth: true)
                phase = .playing
            }
        case .levelDone:
            doneTimer += 1
            if doneTimer > 30 && (input.aPressed || input.startPressed) {
                play(.confirm)
                loadLevel(level + 1, resetHealth: false)
                health = max(health, 60)
                phase = .playing
            }
        case .won:
            doneTimer += 1
            if doneTimer > 60 && (input.aPressed || input.startPressed) {
                play(.confirm)
                banked = 0
                loadLevel(0, resetHealth: true)
                phase = .playing
            }
        }
    }

    // MARK: - Rendering: world

    private func renderWorld(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        let cols = min(w, 320)
        let rows = min(h, 288)
        let half = rows / 2
        for y in 0..<rows {
            let c: UInt32 = y < half ? rowCeil[y] : rowFloor[y]
            let base = y * w
            for x in 0..<w { p[base + x] = c }
        }
        let tp = Dungeon64.texPtr
        let dirX: Float = cos(angle)
        let dirY: Float = sin(angle)
        let planeX: Float = -dirY * 0.66
        let planeY: Float = dirX * 0.66
        let flick = 246 + ((frame * 5 + (frame >> 3) * 3) % 11) - 5
        let pulseF: Float = 236 + 20 * sin(Float(frame) * 0.1)
        let pulse = max(200, min(256, Int(pulseF)))
        let exitOpen = keys >= keysTotal
        for x in 0..<cols {
            let camX: Float = 2 * Float(x) / Float(cols) - 1
            let rdx: Float = dirX + planeX * camX
            let rdy: Float = dirY + planeY * camX
            var mapX = Int(floor(posX))
            var mapY = Int(floor(posY))
            var ddx: Float = 1e30
            var ddy: Float = 1e30
            if abs(rdx) > 0.00001 { ddx = abs(1 / rdx) }
            if abs(rdy) > 0.00001 { ddy = abs(1 / rdy) }
            var stepX = 1
            var stepY = 1
            var sideX: Float = 0
            var sideY: Float = 0
            if rdx < 0 {
                stepX = -1
                sideX = (posX - Float(mapX)) * ddx
            } else {
                sideX = (Float(mapX) + 1 - posX) * ddx
            }
            if rdy < 0 {
                stepY = -1
                sideY = (posY - Float(mapY)) * ddy
            } else {
                sideY = (Float(mapY) + 1 - posY) * ddy
            }
            var side = 0
            var hit = 0
            var guardN = 0
            while hit == 0 && guardN < 48 {
                if sideX < sideY {
                    sideX += ddx
                    mapX += stepX
                    side = 0
                } else {
                    sideY += ddy
                    mapY += stepY
                    side = 1
                }
                guardN += 1
                if mapX < 0 || mapY < 0 || mapX >= 16 || mapY >= 16 {
                    hit = 1
                } else {
                    hit = Int(cells[mapY * 16 + mapX])
                }
            }
            if hit == 0 { hit = 1 }
            var perp: Float = side == 0 ? (sideX - ddx) : (sideY - ddy)
            if !(perp >= 0.05) { perp = 0.05 }
            if perp > 1000 { perp = 1000 }
            zbuf[x] = perp
            var wx: Float = side == 0 ? (posY + perp * rdy) : (posX + perp * rdx)
            wx = wx - floor(wx)
            var texX = Int(wx * 64) & 63
            if side == 0 && rdx > 0 { texX = 63 - texX }
            if side == 1 && rdy < 0 { texX = 63 - texX }
            var texId = hit
            if hit == 3 { texId = exitOpen ? 5 : 3 }
            if texId < 1 || texId > 5 { texId = 1 }
            let lineHF: Float = Float(rows) / perp
            let lineH = Int(min(lineHF, 4000))
            let s0 = half - lineH / 2
            let y0 = max(0, s0)
            let y1 = min(rows, half + lineH / 2)
            if y0 >= y1 { continue }
            let texStep: Float = 64.0 / max(1, lineHF)
            var texPos: Float = Float(y0 - s0) * texStep
            var s = Dungeon64.lightFor(perp)
            s = (s * flick) >> 8
            if side == 1 { s = (s * 190) >> 8 }
            let sr = (s * tintR) >> 8
            let sg = (s * tintG) >> 8
            let sb = (s * tintB) >> 8
            let texBase = texId * 4096
            let glowTex = texId >= 4
            for y in y0..<y1 {
                let texY = Int(texPos) & 63
                texPos += texStep
                let c = tp[texBase + (texY << 6) + texX]
                let r = Int(c & 255)
                let g = Int((c >> 8) & 255)
                let bl = Int((c >> 16) & 255)
                if glowTex {
                    let emissive = (texId == 4 && bl > 200) || (texId == 5 && r > 215)
                    if emissive {
                        let er = UInt32((r * pulse) >> 8)
                        let eg = UInt32((g * pulse) >> 8)
                        let eb = UInt32((bl * pulse) >> 8)
                        p[y * w + x] = 0xFF00_0000 | er | (eg << 8) | (eb << 16)
                        continue
                    }
                }
                let rr = UInt32((r * sr) >> 8)
                let gg = UInt32((g * sg) >> 8)
                let bb = UInt32((bl * sb) >> 8)
                p[y * w + x] = 0xFF00_0000 | rr | (gg << 8) | (bb << 16)
            }
        }
        collectSprites(cols, rows, dirX, dirY, planeX, planeY)
        drawSprites(p, w, cols, rows)
    }

    private func addSprite(_ wx: Float, _ wy: Float, _ spr: Int, _ vOff: Float, _ ww: Float, _ wh: Float,
                           _ flash: Bool, _ minLight: Int, _ cols: Int, _ rows: Int,
                           _ dirX: Float, _ dirY: Float, _ planeX: Float, _ planeY: Float) {
        let sx: Float = wx - posX
        let sy: Float = wy - posY
        let invDet: Float = 1.0 / (planeX * dirY - dirX * planeY)
        let tX: Float = invDet * (dirY * sx - dirX * sy)
        let tY: Float = invDet * (-planeY * sx + planeX * sy)
        if !(tY >= 0.2) || tY > 24 { return }
        let ratio: Float = tX / tY
        if abs(ratio) > 3 { return }
        let scrX = Int(Float(cols) / 2 * (1 + ratio))
        let lineH: Float = Float(rows) / tY
        let pxPerUnit: Float = Float(cols) / (2 * 0.66)
        let sh = Int(wh * lineH)
        let sw = Int(ww * pxPerUnit / tY)
        if sh < 1 || sw < 1 || sh > 2400 || sw > 2400 { return }
        let floorY = rows / 2 + Int(lineH * 0.5)
        let bottom = floorY - Int(vOff * lineH)
        if scrX + sw / 2 < 0 || scrX - sw / 2 >= cols { return }
        let light = max(minLight, Dungeon64.lightFor(tY))
        sitems.append(SItem(depth: tY, sx: scrX, bottom: bottom, sw: sw, sh: sh, spr: spr, light: light, flash: flash))
    }

    private func collectSprites(_ cols: Int, _ rows: Int, _ dirX: Float, _ dirY: Float, _ planeX: Float, _ planeY: Float) {
        sitems.removeAll(keepingCapacity: true)
        let t: Float = Float(frame)
        for pk in pickups {
            if pk.taken { continue }
            let bob: Float = 0.04 * sin(t * 0.08 + pk.phase)
            if pk.kind == 0 {
                addSprite(pk.x, pk.y, Dungeon64.sprGem, 0.2 + bob, 0.3, 0.3, false, 150, cols, rows, dirX, dirY, planeX, planeY)
            } else if pk.kind == 1 {
                addSprite(pk.x, pk.y, Dungeon64.sprKey, 0.25 + bob, 0.34, 0.34, false, 150, cols, rows, dirX, dirY, planeX, planeY)
            } else {
                addSprite(pk.x, pk.y, Dungeon64.sprPotion, 0.1, 0.32, 0.36, false, 120, cols, rows, dirX, dirY, planeX, planeY)
            }
        }
        for e in enemies {
            if e.dead && e.deathT >= 24 { continue }
            var wh: Float = e.kind == 0 ? 0.8 : 0.95
            let ww: Float = e.kind == 0 ? 0.7 : 0.6
            var vOff: Float = 0
            if e.kind == 0 { vOff = 0.18 + 0.06 * sin(t * 0.07 + e.phase) }
            if e.dead {
                let k: Float = 1.0 - Float(e.deathT) / 24.0
                wh = wh * max(0.05, k)
            }
            let spr = e.kind == 0 ? Dungeon64.sprGhost : Dungeon64.sprSkel
            addSprite(e.x, e.y, spr, vOff, ww, wh, e.flash > 0, 18, cols, rows, dirX, dirY, planeX, planeY)
        }
        for s in shots {
            addSprite(s.x, s.y, Dungeon64.sprFire, 0.5, 0.3, 0.3, false, 256, cols, rows, dirX, dirY, planeX, planeY)
        }
        for pf in puffs {
            let sz: Float = 0.2 + 0.05 * Float(10 - pf.life)
            addSprite(pf.x, pf.y, Dungeon64.sprFire, 0.5, sz, sz, false, 256, cols, rows, dirX, dirY, planeX, planeY)
        }
        sitems.sort { $0.depth > $1.depth }
    }

    private func drawSprites(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ cols: Int, _ rows: Int) {
        let sprs = Dungeon64.sprites
        let zb = zbuf
        let items = sitems
        let white = UInt32(0xFFFF_FFFF)
        for it in items {
            if it.spr < 0 || it.spr >= sprs.count { continue }
            let spr = sprs[it.spr]
            let x0 = it.sx - it.sw / 2
            let y0 = it.bottom - it.sh
            let xs = max(0, x0)
            let xe = min(cols, x0 + it.sw)
            let ys = max(0, y0)
            let ye = min(rows, it.bottom)
            if xs >= xe || ys >= ye { continue }
            let stepX = (spr.w << 16) / it.sw
            let stepY = (spr.h << 16) / it.sh
            let sr = (it.light * tintR) >> 8
            let sg = (it.light * tintG) >> 8
            let sb = (it.light * tintB) >> 8
            let sprW = spr.w
            let sprH = spr.h
            let depth = it.depth
            let flash = it.flash
            spr.pix.withUnsafeBufferPointer { sp in
                for x in xs..<xe {
                    if depth >= zb[x] { continue }
                    let tx = max(0, min(sprW - 1, ((x - x0) * stepX) >> 16))
                    for y in ys..<ye {
                        let ty = max(0, min(sprH - 1, ((y - y0) * stepY) >> 16))
                        let c = sp[ty * sprW + tx]
                        if c == 0 { continue }
                        if flash {
                            p[y * w + x] = white
                        } else {
                            let r = Int(c & 255)
                            let g = Int((c >> 8) & 255)
                            let bl = Int((c >> 16) & 255)
                            let rr = UInt32((r * sr) >> 8)
                            let gg = UInt32((g * sg) >> 8)
                            let bb = UInt32((bl * sb) >> 8)
                            p[y * w + x] = 0xFF00_0000 | rr | (gg << 8) | (bb << 16)
                        }
                    }
                }
            }
        }
    }

    override func drawTrueColor(_ b: TrueColorBuffer) {
        b.withPixels { p, w, h in
            if w < 64 || h < 64 { return }
            self.renderWorld(p, w, h)
        }
        if phase != .title {
            drawWeapon(b)
            drawDamage(b)
            drawHUD(b)
            if showMap { drawMinimap(b) }
        }
        drawOverlay(b)
    }

    // MARK: - Rendering: HUD

    private func otext(_ b: TrueColorBuffer, _ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        let k = max(1, scale / 2)
        let o = Dungeon64.cBlack
        b.text(s, x - k, y, o, scale: scale)
        b.text(s, x + k, y, o, scale: scale)
        b.text(s, x, y - k, o, scale: scale)
        b.text(s, x, y + k, o, scale: scale)
        b.text(s, x - k, y - k, o, scale: scale)
        b.text(s, x + k, y + k, o, scale: scale)
        b.text(s, x - k, y + k, o, scale: scale)
        b.text(s, x + k, y - k, o, scale: scale)
        b.text(s, x, y, c, scale: scale)
    }

    private func ctext(_ b: TrueColorBuffer, _ s: String, _ y: Int, _ c: UInt32, _ scale: Int) {
        let tw = b.textWidth(s, scale: scale)
        otext(b, s, (b.width - tw) / 2, y, c, scale)
    }

    private func fillDisc(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int, _ r: Int, _ c: UInt32) {
        if r <= 0 { return }
        for dy in -r...r {
            let v = max(0, r * r - dy * dy)
            let hw = Int(sqrt(Float(v)))
            b.fillRect(cx - hw, cy + dy, hw * 2 + 1, 1, c)
        }
    }

    private func drawWeapon(_ b: TrueColorBuffer) {
        if phase == .levelDone || phase == .won { return }
        let bx = Int(sin(bobPhase) * 5)
        let by = Int(abs(cos(bobPhase)) * 4)
        let x = 232 + bx
        let kick = castAnim
        let orbY = 196 + by + kick
        let staff = TrueColorBuffer.rgb(122, 86, 42)
        let staffHi = TrueColorBuffer.rgb(176, 130, 70)
        let skin = TrueColorBuffer.rgb(222, 172, 132)
        let skinDark = TrueColorBuffer.rgb(120, 80, 56)
        b.fillRect(x - 4, orbY + 6, 8, 264 - (orbY + 6), Dungeon64.cBlack)
        b.fillRect(x - 3, orbY + 6, 6, 264 - (orbY + 6), staff)
        b.fillRect(x - 3, orbY + 6, 2, 264 - (orbY + 6), staffHi)
        b.fillRect(x - 11, 236 + by + kick, 22, 30, Dungeon64.cBlack)
        b.fillRect(x - 10, 237 + by + kick, 20, 29, skin)
        b.fillRect(x - 10, 237 + by + kick, 4, 29, skinDark)
        var r1 = 11
        var r2 = 8
        var r3 = 4
        if castAnim > 0 {
            r1 += castAnim / 2
            r2 += castAnim / 2
            r3 += castAnim / 3
        }
        fillDisc(b, x, orbY, r1 + 1, Dungeon64.cBlack)
        fillDisc(b, x, orbY, r1, TrueColorBuffer.rgb(255, 120, 24))
        fillDisc(b, x, orbY, r2, TrueColorBuffer.rgb(255, 204, 70))
        fillDisc(b, x, orbY, r3, TrueColorBuffer.rgb(255, 255, 230))
    }

    private func drawDamage(_ b: TrueColorBuffer) {
        var t = hurtFlash
        if phase == .dead { t = 20 }
        if t <= 0 { return }
        let th = min(40, t * 2)
        let red = TrueColorBuffer.rgb(206, 22, 22)
        b.fillRect(0, 0, b.width, th, red)
        b.fillRect(0, b.height - th, b.width, th, red)
        b.fillRect(0, 0, th, b.height, red)
        b.fillRect(b.width - th, 0, th, b.height, red)
    }

    private func drawHUD(_ b: TrueColorBuffer) {
        // crosshair
        let ch = TrueColorBuffer.rgb(255, 255, 255)
        b.fillRect(157, 144, 7, 1, ch)
        b.fillRect(160, 141, 1, 7, ch)
        // top-left score and level
        otext(b, "SCORE " + zeroPad(score, 5), 6, 5, Dungeon64.cWhite, 2)
        otext(b, "LV" + String(level + 1), 6, 22, Dungeon64.cYellow, 2)
        if msgTimer > 0 { ctext(b, msg, 60, Dungeon64.cYellow, 3) }
        // bottom bar
        let barY = 264
        b.fillRect(0, barY, b.width, b.height - barY, TrueColorBuffer.rgb(14, 12, 22))
        b.fillRect(0, barY, b.width, 2, TrueColorBuffer.rgb(120, 104, 150))
        otext(b, "HP", 6, barY + 6, Dungeon64.cWhite, 2)
        b.fillRect(30, barY + 5, 104, 14, Dungeon64.cBlack)
        b.fillRect(32, barY + 7, 100, 10, TrueColorBuffer.rgb(60, 28, 32))
        var hc = TrueColorBuffer.rgb(80, 230, 100)
        if health < 35 { hc = TrueColorBuffer.rgb(240, 60, 50) } else if health < 65 { hc = TrueColorBuffer.rgb(255, 210, 60) }
        let hw = max(0, min(100, health))
        if hw > 0 { b.fillRect(32, barY + 7, hw, 10, hc) }
        otext(b, "KEY " + String(keys) + "/" + String(keysTotal), 146, barY + 6, Dungeon64.cYellow, 2)
        otext(b, "GEM " + String(gems), 232, barY + 6, Dungeon64.cCyan, 2)
    }

    private func drawMinimap(_ b: TrueColorBuffer) {
        let mx = 248
        let my = 6
        b.fillRect(mx - 2, my - 2, 68, 68, Dungeon64.cBlack)
        b.fillRect(mx, my, 64, 64, TrueColorBuffer.rgb(34, 30, 48))
        let wall = TrueColorBuffer.rgb(196, 190, 204)
        let doorC = TrueColorBuffer.rgb(255, 210, 90)
        for r in 0..<16 {
            for c in 0..<16 {
                let v = cells[r * 16 + c]
                if v == 0 { continue }
                if v == 3 {
                    b.fillRect(mx + c * 4, my + r * 4, 4, 4, doorC)
                } else {
                    b.fillRect(mx + c * 4, my + r * 4, 4, 4, wall)
                }
            }
        }
        for pk in pickups {
            if pk.taken { continue }
            var colr = Dungeon64.cCyan
            if pk.kind == 1 { colr = Dungeon64.cYellow }
            if pk.kind == 2 { colr = TrueColorBuffer.rgb(255, 120, 200) }
            let px = max(0, min(62, Int(pk.x * 4)))
            let py = max(0, min(62, Int(pk.y * 4)))
            b.fillRect(mx + px, my + py, 2, 2, colr)
        }
        for e in enemies {
            if e.dead { continue }
            let px = max(0, min(61, Int(e.x * 4) - 1))
            let py = max(0, min(61, Int(e.y * 4) - 1))
            b.fillRect(mx + px, my + py, 3, 3, Dungeon64.cRed)
        }
        let ppx = max(2, min(61, Int(posX * 4)))
        let ppy = max(2, min(61, Int(posY * 4)))
        b.fillRect(mx + ppx - 2, my + ppy - 2, 5, 5, Dungeon64.cBlack)
        b.fillRect(mx + ppx - 1, my + ppy - 1, 3, 3, Dungeon64.cGreen)
        let fx = max(0, min(63, ppx + Int(cos(angle) * 5)))
        let fy = max(0, min(63, ppy + Int(sin(angle) * 5)))
        b.fillRect(mx + fx, my + fy, 2, 2, Dungeon64.cWhite)
    }

    private func timeString(_ f: Int) -> String {
        let sec = max(0, f) / 60
        return String(sec / 60) + ":" + zeroPad(sec % 60, 2)
    }

    private func drawPanel(_ b: TrueColorBuffer, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        b.fillRect(x - 2, y - 2, w + 4, h + 4, Dungeon64.cBlack)
        b.fillRect(x, y, w, h, Dungeon64.cPanel)
        b.fillRect(x, y, w, 3, Dungeon64.cYellow)
        b.fillRect(x, y + h - 3, w, 3, Dungeon64.cYellow)
    }

    private func drawOverlay(_ b: TrueColorBuffer) {
        let white = Dungeon64.cWhite
        let yellow = Dungeon64.cYellow
        switch phase {
        case .title:
            drawPanel(b, 30, 50, 260, 160)
            ctext(b, "DUNGEON", 66, yellow, 6)
            ctext(b, "64", 110, white, 8)
            ctext(b, "FIND ALL KEYS", 162, white, 2)
            ctext(b, "REACH THE EXIT DOOR", 180, white, 2)
            if (frame / 30) & 1 == 0 { ctext(b, "PRESS A", 226, yellow, 3) }
            ctext(b, "A FIRE  B+PAD STRAFE", 256, white, 1)
            ctext(b, "SELECT TOGGLES MAP", 268, white, 1)
        case .playing:
            break
        case .dead:
            drawPanel(b, 50, 80, 220, 110)
            ctext(b, "YOU DIED", 96, Dungeon64.cRed, 6)
            ctext(b, "SCORE " + zeroPad(score, 5), 146, white, 2)
            if deadTimer > 40 && (frame / 30) & 1 == 0 { ctext(b, "PRESS A TO RETRY", 166, yellow, 2) }
        case .levelDone:
            drawPanel(b, 36, 50, 248, 190)
            ctext(b, "LEVEL CLEAR", 62, yellow, 4)
            ctext(b, Dungeon64.levelNames[max(0, min(2, level))], 96, white, 2)
            ctext(b, "GEMS " + String(gems) + "/" + String(gemsTotal), 120, Dungeon64.cCyan, 2)
            ctext(b, "KILLS " + String(kills), 140, white, 2)
            ctext(b, "TIME " + timeString(levelFrames), 160, white, 2)
            ctext(b, "BONUS +" + String(lastBonus), 180, yellow, 2)
            ctext(b, "SCORE " + zeroPad(banked, 5), 200, white, 2)
            if doneTimer > 30 && (frame / 30) & 1 == 0 { ctext(b, "PRESS A", 220, yellow, 2) }
        case .won:
            drawPanel(b, 24, 56, 272, 180)
            ctext(b, "DUNGEON", 70, yellow, 4)
            ctext(b, "CLEARED!", 98, yellow, 4)
            ctext(b, "GEMS " + String(gems) + "/" + String(gemsTotal), 134, Dungeon64.cCyan, 2)
            ctext(b, "BONUS +" + String(lastBonus), 154, white, 2)
            ctext(b, "FINAL SCORE " + zeroPad(banked, 5), 178, yellow, 2)
            if doneTimer > 60 && (frame / 30) & 1 == 0 { ctext(b, "PRESS A TO PLAY AGAIN", 206, white, 2) }
        }
    }
}

extension Cartridge {
    static let dungeon64 = Cartridge(
        id: "dungeon64", title: "DUNGEON 64", genre: "Adventure",
        blurb: "Raycast your way through three haunted dungeons. Collect keys, burn ghosts and skeletons, and escape.",
        controls: "UP/DOWN walk, LEFT/RIGHT turn, hold B to strafe, A fireball, SELECT map.",
        era: .n64, labelTop: 0x7A4ACB, labelBottom: 0x1A1030, factory: { Dungeon64() })
}
