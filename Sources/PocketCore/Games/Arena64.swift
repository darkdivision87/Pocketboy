#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// ARENA 64: first-person hover-tank laser tag. A DDA raycaster over an open arena (pillars, barriers, a central
/// pit and two coloured team bases) with textured walls, a lit grid floor, a gradient sky, distance fog, billboarded
/// bot tanks with a per-column z-buffer, plasma bolts with splash damage, a heat meter and three waves of bots.
final class Arena64: Game {
    // MARK: - Constants

    static let mapN = 24
    static let planeLen: Float = 0.66
    static let pxPerUnitX: Float = 242.0
    static let pxPerUnitY: Float = 288.0
    static let fogR = 22
    static let fogG = 14
    static let fogB = 46
    static let totalWaves = 3

    static let cWhite: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    static let cBlack: UInt32 = TrueColorBuffer.rgb(8, 8, 14)
    static let cYellow: UInt32 = TrueColorBuffer.rgb(255, 230, 70)
    static let cRed: UInt32 = TrueColorBuffer.rgb(255, 70, 60)
    static let cGreen: UInt32 = TrueColorBuffer.rgb(100, 255, 120)
    static let cCyan: UInt32 = TrueColorBuffer.rgb(90, 240, 255)
    static let cBlue: UInt32 = TrueColorBuffer.rgb(90, 150, 255)
    static let cOrange: UInt32 = TrueColorBuffer.rgb(255, 160, 40)
    static let cPanel: UInt32 = TrueColorBuffer.rgb(14, 16, 40)
    static let cFogColor: UInt32 = TrueColorBuffer.rgb(22, 14, 46)

    static let botNames: [String] = ["VIPER", "RAZOR", "NOVA", "GHOST", "HAWK", "BLITZ"]

    static let tune = Tune(bpm: 138, wave: .pulse25, volume: 0.12,
        "A3:0.5 A3:0.5 E4:0.5 A3:0.5 G3:0.5 G3:0.5 D4:0.5 G3:0.5 F3:0.5 F3:0.5 C4:0.5 F3:0.5 E3:0.5 E3:0.5 B3:0.5 E4:0.5")

    // MARK: - Nested types

    struct Pt {
        var x: Float
        var y: Float
    }

    struct Star {
        var ang: Float
        var y: Int
        var c: UInt32
    }

    struct Bot {
        var x: Float = 0
        var y: Float = 0
        var angle: Float = 0
        var hp: Int = 50
        var maxHp: Int = 50
        var state: Int = 0
        var timer: Int = 0
        var strafeDir: Float = 1
        var fireCD: Int = 90
        var flash: Int = 0
        var color: Int = 0
        var name: Int = 0
        var tx: Float = 0
        var ty: Float = 0
        var sight: Int = 999
        var alive: Bool = true
        var stuck: Int = 0
        var coverUsed: Bool = false
    }

    struct Bolt {
        var x: Float
        var y: Float
        var dx: Float
        var dy: Float
        var owner: Int
        var life: Int
    }

    struct Fx {
        var x: Float
        var y: Float
        var t: Int
        var maxT: Int
        var size: Float
    }

    struct Pickup {
        var x: Float
        var y: Float
        var kind: Int
        var active: Bool
        var timer: Int
        var perm: Bool
    }

    struct Feed {
        var text: String
        var timer: Int
        var color: UInt32
    }

    struct Bill {
        var depth: Float
        var sx: Int
        var bottom: Int
        var sw: Int
        var sh: Int
        var spr: Int
        var lit: Int
        var white: Int
    }

    struct SpriteImg {
        var w: Int
        var h: Int
        var pix: [UInt32]
    }

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

    enum Phase { case title, playing, clear, over }

    // MARK: - Static tables

    static func hash(_ x: Int, _ y: Int) -> Int {
        var h: Int = x &* 374761393 &+ y &* 668265263
        h = (h ^ (h >> 13)) &* 1274126177
        return (h ^ (h >> 16)) & 0xFFFF
    }

    static func wrapAngle(_ a: Float) -> Float {
        if !a.isFinite { return 0 }
        var d = a
        while d > Float.pi { d -= 2 * Float.pi }
        while d < -Float.pi { d += 2 * Float.pi }
        return d
    }

    static let map: [UInt8] = {
        let n = 24
        var m = [UInt8](repeating: 0, count: n * n)
        func put(_ x: Int, _ y: Int, _ v: UInt8) {
            if x >= 0 && y >= 0 && x < 24 && y < 24 { m[y * 24 + x] = v }
        }
        for i in 0..<n {
            put(i, 0, 1)
            put(i, n - 1, 1)
            put(0, i, 1)
            put(n - 1, i, 1)
        }
        // Central pit structure: a ring of neon barriers with four two-wide gates.
        for i in 9...14 {
            put(i, 9, 3)
            put(i, 14, 3)
            put(9, i, 3)
            put(14, i, 3)
        }
        put(11, 9, 0); put(12, 9, 0)
        put(11, 14, 0); put(12, 14, 0)
        put(9, 11, 0); put(9, 12, 0)
        put(14, 11, 0); put(14, 12, 0)
        // Pillars
        let pillars: [[Int]] = [[6, 6], [17, 6], [6, 17], [17, 17], [11, 5], [12, 18], [4, 11], [19, 12],
                                [8, 3], [15, 20], [3, 8], [20, 15]]
        for p in pillars { put(p[0], p[1], 2) }
        // Barriers
        for x in 14...16 { put(x, 7, 3) }
        for x in 7...9 { put(x, 16, 3) }
        for y in 9...11 { put(16, y, 3) }
        for y in 12...14 { put(7, y, 3) }
        // Team bases: red NW, blue SE
        for x in 1...4 { put(x, 5, 4) }
        for y in 1...3 { put(5, y, 4) }
        for x in 19...22 { put(x, 18, 5) }
        for y in 20...22 { put(18, y, 5) }
        return m
    }()

    static let zone: [UInt8] = {
        var z = [UInt8](repeating: 0, count: 576)
        for y in 0..<24 {
            for x in 0..<24 {
                var v: UInt8 = 0
                if x <= 5 && y <= 5 { v = 1 }
                if x >= 18 && y >= 18 { v = 2 }
                if x >= 10 && x <= 13 && y >= 10 && y <= 13 { v = 3 }
                z[y * 24 + x] = v
            }
        }
        return z
    }()

    static func isOpen(_ x: Int, _ y: Int) -> Bool {
        if x < 0 || y < 0 || x >= 24 || y >= 24 { return false }
        return Arena64.map[y * 24 + x] == 0
    }

    static let waypoints: [Pt] = {
        var list: [Pt] = []
        var y = 2
        while y < 22 {
            var x = 2
            while x < 22 {
                var ok = true
                for oy in -1...1 {
                    for ox in -1...1 {
                        if !Arena64.isOpen(x + ox, y + oy) { ok = false }
                    }
                }
                if ok { list.append(Pt(x: Float(x) + 0.5, y: Float(y) + 0.5)) }
                x += 2
            }
            y += 2
        }
        if list.isEmpty { list.append(Pt(x: 12.5, y: 7.5)) }
        return list
    }()

    static let coverPoints: [Pt] = {
        var list: [Pt] = []
        for y in 2..<22 {
            for x in 2..<22 {
                if !Arena64.isOpen(x, y) { continue }
                var near = false
                if !Arena64.isOpen(x + 1, y) { near = true }
                if !Arena64.isOpen(x - 1, y) { near = true }
                if !Arena64.isOpen(x, y + 1) { near = true }
                if !Arena64.isOpen(x, y - 1) { near = true }
                if near { list.append(Pt(x: Float(x) + 0.5, y: Float(y) + 0.5)) }
            }
        }
        if list.isEmpty { list.append(Pt(x: 12.5, y: 7.5)) }
        return list
    }()

    static let spawnPts: [Pt] = [
        Pt(x: 2.5, y: 2.5), Pt(x: 21.5, y: 2.5), Pt(x: 2.5, y: 21.5),
        Pt(x: 11.5, y: 1.5), Pt(x: 1.5, y: 11.5), Pt(x: 12.5, y: 22.5)
    ]

    static let rowDist: [Float] = {
        var a = [Float](repeating: 1000, count: 288)
        for y in 145..<288 { a[y] = 144.0 / Float(y - 144) }
        return a
    }()

    static let rowLit: [Int] = {
        var a = [Int](repeating: 70, count: 288)
        for y in 145..<288 {
            let d: Float = 144.0 / Float(y - 144)
            a[y] = max(60, min(256, 270 - Int(d * 22)))
        }
        return a
    }()

    static let skyRows: [UInt32] = {
        var a = [UInt32](repeating: 0, count: 144)
        for y in 0..<144 {
            let t: Float = Float(y) / 143.0
            let t2: Float = t * t
            let r = Int(18 + 230 * t2)
            let g = Int(14 + 120 * t2 + 20 * t)
            let b = Int(70 + 100 * t - 50 * t2)
            a[y] = TrueColorBuffer.rgb(r, g, b)
        }
        return a
    }()

    static let stars: [Star] = {
        var list: [Star] = []
        for i in 0..<48 {
            let h1 = Arena64.hash(i, 17)
            let h2 = Arena64.hash(i, 91)
            let ang: Float = Float(h1) / 65536.0 * 2.0 * Float.pi - Float.pi
            let y = 4 + (h2 % 92)
            let v = 170 + (h1 & 63)
            list.append(Star(ang: ang, y: y, c: TrueColorBuffer.rgb(v, v, 255)))
        }
        return list
    }()

    static let wallTex: UnsafeMutablePointer<UInt32> = Arena64.buildWallTex()
    static let floorTex: UnsafeMutablePointer<UInt32> = Arena64.buildFloorTex()
    static let sprites: [SpriteImg] = Arena64.makeSprites()

    @inline(__always) static func shade(_ c: UInt32, _ lit: Int) -> UInt32 {
        let r = Int(c & 255)
        let g = Int((c >> 8) & 255)
        let bl = Int((c >> 16) & 255)
        let inv = 256 - lit
        let r2 = (r * lit + Arena64.fogR * inv) >> 8
        let g2 = (g * lit + Arena64.fogG * inv) >> 8
        let b2 = (bl * lit + Arena64.fogB * inv) >> 8
        return 0xFF00_0000 | UInt32(r2 & 255) | (UInt32(g2 & 255) << 8) | (UInt32(b2 & 255) << 16)
    }

    @inline(__always) static func whiten(_ c: UInt32, _ amt: Int) -> UInt32 {
        let r = Int(c & 255)
        let g = Int((c >> 8) & 255)
        let bl = Int((c >> 16) & 255)
        let r2 = r + (((255 - r) * amt) >> 8)
        let g2 = g + (((255 - g) * amt) >> 8)
        let b2 = bl + (((255 - bl) * amt) >> 8)
        return 0xFF00_0000 | UInt32(r2 & 255) | (UInt32(g2 & 255) << 8) | (UInt32(b2 & 255) << 16)
    }

    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
        return TrueColorBuffer.rgb(r, g, b)
    }

    static func buildWallTex() -> UnsafeMutablePointer<UInt32> {
        let total = 5 * 4096
        let t = UnsafeMutablePointer<UInt32>.allocate(capacity: total)
        t.initialize(repeating: 0xFF00_0000, count: total)
        for ty in 0..<64 {
            for tx in 0..<64 {
                let n = Arena64.hash(tx, ty) & 7
                let px = tx & 31
                let py = ty & 31
                let i = ty * 64 + tx
                // 0: brushed metal panels with a neon strip
                var r = 150 + n * 2
                var g = 160 + n * 2
                var b = 182 + n * 2
                if (Arena64.hash(0, ty) & 3) == 0 { r += 8; g += 8; b += 8 }
                if px == 0 || py == 0 {
                    r -= 80; g -= 80; b -= 70
                } else if px == 1 || py == 1 {
                    r += 40; g += 40; b += 40
                } else if px >= 30 || py >= 30 {
                    r -= 30; g -= 30; b -= 28
                }
                if (px == 5 || px == 26) && (py == 5 || py == 26) {
                    r = 232; g = 236; b = 245
                }
                if ty == 15 || ty == 16 { r = 70; g = 230; b = 255 }
                t[i] = Arena64.rgb(r, g, b)
                // 1: hazard stripes
                var hr = 255
                var hg = 214
                var hb = 30
                if (((tx + ty) / 8) & 1) == 1 { hr = 30; hg = 30; hb = 34 }
                hr -= n; hg -= n; hb -= n
                if ty < 5 || ty >= 59 {
                    hr = 96 + n * 2; hg = 100 + n * 2; hb = 116 + n * 2
                    if ty == 5 || ty == 58 { hr = 230; hg = 230; hb = 240 }
                }
                t[4096 + i] = Arena64.rgb(hr, hg, hb)
                // 2: neon grid
                var nr = 30 + n
                var ng = 44 + n
                var nb = 104 + n * 2
                let gx = tx & 15
                let gy = ty & 15
                if gx == 0 || gy == 0 {
                    nr = 80; ng = 240; nb = 255
                    if gx == 0 && gy == 0 { nr = 255; ng = 90; nb = 230 }
                } else if gx == 1 || gx == 15 || gy == 1 || gy == 15 {
                    nr = 44; ng = 120; nb = 196
                }
                t[8192 + i] = Arena64.rgb(nr, ng, nb)
                // 3: red base wall, 4: blue base wall
                for k in 0..<2 {
                    var cr = 214
                    var cg = 62
                    var cb = 66
                    if k == 1 { cr = 56; cg = 108; cb = 240 }
                    cr += n; cg += n; cb += n
                    if px == 0 || py == 0 {
                        cr = cr / 3; cg = cg / 3; cb = cb / 3
                    } else if px == 1 {
                        cr += 30; cg += 30; cb += 30
                    }
                    if ty >= 26 && ty <= 37 {
                        cr = 244; cg = 244; cb = 244
                        if (((tx + ty) / 6) & 1) == 1 { cr = 30; cg = 30; cb = 36 }
                    }
                    if ty == 25 || ty == 38 { cr = 20; cg = 20; cb = 26 }
                    t[(3 + k) * 4096 + i] = Arena64.rgb(cr, cg, cb)
                }
            }
        }
        return t
    }

    static func buildFloorTex() -> UnsafeMutablePointer<UInt32> {
        let total = 4 * 4096
        let t = UnsafeMutablePointer<UInt32>.allocate(capacity: total)
        t.initialize(repeating: 0xFF00_0000, count: total)
        let base: [[Int]] = [[86, 94, 124], [128, 60, 66], [58, 84, 160], [128, 110, 48]]
        let grid: [[Int]] = [[160, 188, 240], [255, 124, 112], [120, 180, 255], [255, 228, 104]]
        for z in 0..<4 {
            for ty in 0..<64 {
                for tx in 0..<64 {
                    let n = Arena64.hash(tx + z * 7, ty) & 7
                    var r = base[z][0] + n
                    var g = base[z][1] + n
                    var b = base[z][2] + n
                    if (((tx >> 5) + (ty >> 5)) & 1) == 1 { r -= 14; g -= 14; b -= 14 }
                    let gx = tx & 31
                    let gy = ty & 31
                    if gx == 0 || gy == 0 {
                        r = grid[z][0]; g = grid[z][1]; b = grid[z][2]
                    } else if gx == 1 || gy == 1 {
                        r = (r + grid[z][0]) / 2
                        g = (g + grid[z][1]) / 2
                        b = (b + grid[z][2]) / 2
                    }
                    if z == 3 {
                        let d1 = abs(tx - 32)
                        let d2 = abs(ty - 32)
                        if (d1 + d2) % 16 < 2 { r = 255; g = 200; b = 40 }
                    }
                    t[z * 4096 + ty * 64 + tx] = Arena64.rgb(r, g, b)
                }
            }
        }
        return t
    }

    // MARK: - Sprites

    static func makeTank(_ r: Int, _ g: Int, _ bl: Int, _ ar: Int, _ ag: Int, _ ab: Int) -> SpriteImg {
        var p = Pix(40, 32)
        let body = Arena64.rgb(r, g, bl)
        let light = Arena64.rgb(r + 60, g + 60, bl + 60)
        let dark = Arena64.rgb(r / 2, g / 2, bl / 2)
        let accent = Arena64.rgb(ar, ag, ab)
        let metal = Arena64.rgb(150, 156, 172)
        p.rect(8, 28, 24, 3, Arena64.rgb(ar / 2, ag / 2, ab / 2))
        p.rect(11, 29, 18, 2, accent)
        p.rect(4, 12, 32, 4, body)
        p.rect(2, 16, 36, 11, body)
        p.rect(2, 24, 36, 4, dark)
        p.rect(2, 16, 36, 1, light)
        p.rect(0, 18, 4, 9, dark)
        p.rect(36, 18, 4, 9, dark)
        p.rect(0, 18, 4, 1, light)
        p.rect(36, 18, 4, 1, light)
        p.rect(6, 19, 6, 4, accent)
        p.rect(28, 19, 6, 4, accent)
        p.disc(20, 12, 8, body)
        p.disc(19, 10, 5, light)
        p.rect(13, 9, 14, 4, Arena64.rgb(20, 20, 40))
        p.rect(14, 10, 4, 2, accent)
        p.rect(22, 10, 4, 2, accent)
        p.rect(18, 1, 4, 9, metal)
        p.rect(19, 0, 2, 3, accent)
        p.outline(Arena64.rgb(8, 8, 14))
        return SpriteImg(w: p.w, h: p.h, pix: p.d)
    }

    static func makeHealth() -> SpriteImg {
        var p = Pix(24, 24)
        p.rect(1, 1, 22, 22, Arena64.rgb(250, 250, 250))
        p.rect(1, 18, 22, 5, Arena64.rgb(190, 196, 206))
        p.rect(9, 4, 6, 16, Arena64.rgb(224, 30, 44))
        p.rect(4, 9, 16, 6, Arena64.rgb(224, 30, 44))
        p.outline(Arena64.rgb(8, 8, 14))
        return SpriteImg(w: p.w, h: p.h, pix: p.d)
    }

    static func makeShield() -> SpriteImg {
        var p = Pix(24, 24)
        p.disc(12, 12, 11, Arena64.rgb(30, 90, 230))
        p.disc(12, 12, 8, Arena64.rgb(100, 200, 255))
        p.disc(12, 12, 4, Arena64.rgb(240, 250, 255))
        p.rect(11, 2, 2, 20, Arena64.rgb(30, 90, 230))
        p.rect(2, 11, 20, 2, Arena64.rgb(30, 90, 230))
        p.outline(Arena64.rgb(8, 8, 14))
        return SpriteImg(w: p.w, h: p.h, pix: p.d)
    }

    static func makeOrb(_ core: UInt32, _ mid: UInt32, _ outer: UInt32, _ ragged: Bool) -> SpriteImg {
        var p = Pix(32, 32)
        for y in 0..<32 {
            for x in 0..<32 {
                let dx: Float = Float(x) - 15.5
                let dy: Float = Float(y) - 15.5
                let d: Float = sqrt(dx * dx + dy * dy) / 15.5
                if d > 1.0 { continue }
                if ragged && d > 0.72 && (Arena64.hash(x, y) & 3) == 0 { continue }
                if d < 0.36 {
                    p.set(x, y, core)
                } else if d < 0.7 {
                    p.set(x, y, mid)
                } else {
                    p.set(x, y, outer)
                }
            }
        }
        return SpriteImg(w: p.w, h: p.h, pix: p.d)
    }

    static func makeSprites() -> [SpriteImg] {
        var list: [SpriteImg] = []
        list.append(Arena64.makeTank(236, 74, 56, 255, 240, 80))
        list.append(Arena64.makeTank(244, 176, 44, 255, 80, 60))
        list.append(Arena64.makeTank(214, 70, 226, 90, 255, 230))
        list.append(Arena64.makeHealth())
        list.append(Arena64.makeShield())
        list.append(Arena64.makeOrb(Arena64.rgb(255, 255, 255), Arena64.rgb(90, 250, 255), Arena64.rgb(20, 140, 255), false))
        list.append(Arena64.makeOrb(Arena64.rgb(255, 255, 220), Arena64.rgb(255, 170, 40), Arena64.rgb(230, 50, 30), false))
        list.append(Arena64.makeOrb(Arena64.rgb(255, 252, 210), Arena64.rgb(255, 160, 40), Arena64.rgb(235, 60, 24), true))
        return list
    }

    // MARK: - Game state

    private var phase: Phase = .title
    private var frame = 0
    private var rng = Rng()
    private let zbuf: UnsafeMutablePointer<Float>

    private var px: Float = 21.5
    private var py: Float = 21.5
    private var vx: Float = 0
    private var vy: Float = 0
    private var ang: Float = -2.35
    private var health: Int = 100
    private var shield: Int = 30
    private var heat: Float = 0
    private var overheated = false
    private var fireCD = 0
    private var recoil = 0
    private var muzzle = 0
    private var dmgFlash = 0
    private var invuln = 0
    private var hitMarker = 0
    private var aimed = false
    private var titleAng: Float = 0

    private var bots: [Bot] = []
    private var bolts: [Bolt] = []
    private var fxs: [Fx] = []
    private var pickups: [Pickup] = []
    private var feed: [Feed] = []
    private var bills: [Bill] = []

    private var wave = 0
    private var waveBanner = 0
    private var clearTimer = 0
    private var overTimer = 0
    private var victory = false
    private var kills = 0
    private var shots = 0
    private var hits = 0
    private var scoreValue = 0
    private var gameFrames = 0

    private var cDirX: Float = 1
    private var cDirY: Float = 0
    private var cPlaneX: Float = 0
    private var cPlaneY: Float = 0.66

    override var score: Int { return max(0, scoreValue) }

    override init() {
        let zb = UnsafeMutablePointer<Float>.allocate(capacity: 320)
        zb.initialize(repeating: 100, count: 320)
        zbuf = zb
        super.init()
        resetGame()
        phase = .title
    }

    deinit {
        zbuf.deallocate()
    }

    override func start() {
        playMusic(Arena64.tune)
    }

    // MARK: - Setup

    private func resetGame() {
        px = 21.5
        py = 21.5
        vx = 0
        vy = 0
        ang = -2.35
        health = 100
        shield = 30
        heat = 0
        overheated = false
        fireCD = 0
        recoil = 0
        muzzle = 0
        dmgFlash = 0
        invuln = 120
        hitMarker = 0
        aimed = false
        bots = []
        bolts = []
        fxs = []
        feed = []
        wave = 0
        waveBanner = 0
        clearTimer = 0
        overTimer = 0
        victory = false
        kills = 0
        shots = 0
        hits = 0
        scoreValue = 0
        gameFrames = 0
        pickups = []
        let spots: [[Float]] = [[11.5, 11.5, 1], [12.5, 12.5, 0], [6.5, 12.5, 0], [17.5, 11.5, 0],
                                [12.5, 16.5, 1], [20.5, 3.5, 1], [3.5, 20.5, 0]]
        for s in spots {
            pickups.append(Pickup(x: s[0], y: s[1], kind: Int(s[2]), active: true, timer: 0, perm: true))
        }
    }

    private func beginGame() {
        resetGame()
        startWave(1)
        phase = .playing
    }

    private func startWave(_ n: Int) {
        wave = n
        bots = []
        let count = min(6, 3 + n)
        for i in 0..<count {
            var b = Bot()
            let sp = Arena64.spawnPts[i % Arena64.spawnPts.count]
            b.x = sp.x
            b.y = sp.y
            b.angle = Float(rng.int(628)) / 100.0 - 3.14
            b.maxHp = 40 + 10 * n
            b.hp = b.maxHp
            b.color = i % 3
            b.name = i % Arena64.botNames.count
            b.fireCD = 100 + rng.int(60)
            b.strafeDir = rng.chance(50) ? 1 : -1
            pickWaypoint(&b)
            bots.append(b)
        }
        waveBanner = 150
        invuln = max(invuln, 90)
        addFeed("WAVE " + String(n) + " INCOMING", Arena64.cYellow)
        play(.countdown)
    }

    private func addFeed(_ s: String, _ c: UInt32) {
        feed.append(Feed(text: s, timer: 260, color: c))
        while feed.count > 4 { feed.removeFirst() }
    }

    // MARK: - World queries

    private func solid(_ x: Float, _ y: Float) -> Bool {
        if !(x >= 0 && y >= 0 && x < 24 && y < 24) { return true }
        return Arena64.map[Int(y) * 24 + Int(x)] != 0
    }

    private func blocked(_ x: Float, _ y: Float, _ r: Float) -> Bool {
        if solid(x - r, y - r) { return true }
        if solid(x + r, y - r) { return true }
        if solid(x - r, y + r) { return true }
        if solid(x + r, y + r) { return true }
        return false
    }

    private func tryMove(_ x: Float, _ y: Float, _ dx: Float, _ dy: Float, _ r: Float) -> Pt {
        var nx = x
        var ny = y
        if !blocked(x + dx, y, r) { nx = x + dx }
        if !blocked(nx, y + dy, r) { ny = y + dy }
        return Pt(x: nx, y: ny)
    }

    private func hasLOS(_ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float) -> Bool {
        let dx: Float = x1 - x0
        let dy: Float = y1 - y0
        let d: Float = sqrt(dx * dx + dy * dy)
        if d < 0.3 { return true }
        let n = min(90, Int(d / 0.25) + 1)
        for k in 1..<max(2, n) {
            let t: Float = Float(k) / Float(n)
            if solid(x0 + dx * t, y0 + dy * t) { return false }
        }
        return true
    }

    private func pickWaypoint(_ b: inout Bot) {
        let list = Arena64.waypoints
        let p = list[rng.int(list.count)]
        b.tx = p.x
        b.ty = p.y
        b.timer = 320
    }

    private func pickCover(_ b: inout Bot) {
        let list = Arena64.coverPoints
        var best = -1
        var bestD: Float = 100000
        for i in 0..<list.count {
            let c = list[i]
            let dxb: Float = c.x - b.x
            let dyb: Float = c.y - b.y
            let d: Float = dxb * dxb + dyb * dyb
            if d > 110 || d >= bestD { continue }
            if hasLOS(c.x, c.y, px, py) { continue }
            bestD = d
            best = i
        }
        if best >= 0 {
            b.tx = list[best].x
            b.ty = list[best].y
            b.state = 3
            b.timer = 260
            b.coverUsed = true
        } else {
            b.coverUsed = true
        }
    }

    // MARK: - Combat

    private func damagePlayer(_ n: Int, _ by: String) {
        if invuln > 0 || phase != .playing || n <= 0 { return }
        var left = n
        if shield > 0 {
            let s = min(shield, left)
            shield -= s
            left -= s
        }
        health -= left
        dmgFlash = 18
        play(.hurt)
        if health <= 0 {
            health = 0
            addFeed("DESTROYED BY " + by, Arena64.cRed)
            finishGame(false)
        } else {
            addFeed("HIT BY " + by, Arena64.cOrange)
        }
    }

    private func damageBot(_ i: Int, _ n: Int) {
        if i < 0 || i >= bots.count { return }
        var b = bots[i]
        if !b.alive { return }
        b.hp -= n
        b.flash = 7
        if b.state == 0 { b.state = 1 }
        if b.hp <= 0 {
            b.alive = false
            kills += 1
            scoreValue += 100 * wave
            fxs.append(Fx(x: b.x, y: b.y, t: 0, maxT: 30, size: 1.8))
            addFeed("YOU > " + Arena64.botNames[b.name], Arena64.cGreen)
            play(.explosion)
            if rng.chance(45) {
                pickups.append(Pickup(x: b.x, y: b.y, kind: rng.int(2), active: true, timer: 900, perm: false))
            }
        }
        bots[i] = b
    }

    private func impact(_ x: Float, _ y: Float, _ owner: Int) {
        fxs.append(Fx(x: x, y: y, t: 0, maxT: 16, size: 0.9))
        let rad: Float = 1.5
        if owner < 0 {
            for i in 0..<bots.count {
                if !bots[i].alive { continue }
                let dx: Float = bots[i].x - x
                let dy: Float = bots[i].y - y
                let d: Float = sqrt(dx * dx + dy * dy)
                if d < rad {
                    let f: Float = 1.0 - d / rad
                    let dmg = Int(26.0 * (0.4 + 0.6 * f))
                    damageBot(i, dmg)
                }
            }
        } else {
            let dx: Float = px - x
            let dy: Float = py - y
            let d: Float = sqrt(dx * dx + dy * dy)
            if d < 1.1 {
                let f: Float = 1.0 - d / 1.1
                let base: Float = Float(9 + wave * 3)
                let dmg = Int(base * (0.4 + 0.6 * f))
                let nm = owner < bots.count ? Arena64.botNames[bots[owner].name] : "BOT"
                damagePlayer(dmg, nm)
            }
        }
        play(.hit)
    }

    private func finishGame(_ won: Bool) {
        victory = won
        phase = .over
        overTimer = 0
        if won {
            scoreValue += health * 5 + shield * 3 + 500
            play(.win)
        } else {
            play(.death)
            fxs.append(Fx(x: px, y: py, t: 0, maxT: 40, size: 2.2))
        }
    }

    // MARK: - Update

    private func updatePlayer(_ input: InputState) {
        let turnSpd: Float = 0.052
        let fwd: Float = -Float(input.dy)
        var strafe: Float = 0
        if input.b {
            strafe = Float(input.dx)
        } else {
            ang = Arena64.wrapAngle(ang + Float(input.dx) * turnSpd)
        }
        let fx: Float = cos(ang)
        let fy: Float = sin(ang)
        let rx: Float = -fy
        let ry: Float = fx
        let fAcc: Float = fwd > 0 ? 0.0105 : 0.0075
        vx += (fx * fwd * fAcc + rx * strafe * 0.0085)
        vy += (fy * fwd * fAcc + ry * strafe * 0.0085)
        vx *= 0.88
        vy *= 0.88
        let np = tryMove(px, py, vx, vy, 0.26)
        if abs(np.x - px) < abs(vx) * 0.5 { vx *= 0.3 }
        if abs(np.y - py) < abs(vy) * 0.5 { vy *= 0.3 }
        px = np.x
        py = np.y
        // push out of bots
        for i in 0..<bots.count {
            if !bots[i].alive { continue }
            let dx: Float = px - bots[i].x
            let dy: Float = py - bots[i].y
            let d: Float = sqrt(dx * dx + dy * dy)
            if d < 0.55 && d > 0.001 {
                let push: Float = (0.55 - d) * 0.5
                let q = tryMove(px, py, dx / d * push, dy / d * push, 0.26)
                px = q.x
                py = q.y
            }
        }
        // weapon
        if fireCD > 0 { fireCD -= 1 }
        if recoil > 0 { recoil -= 1 }
        if muzzle > 0 { muzzle -= 1 }
        if overheated {
            heat -= 0.9
            if heat <= 38 { overheated = false }
        } else {
            heat -= 0.5
        }
        if heat < 0 { heat = 0 }
        if input.a {
            if overheated {
                if input.aPressed { play(.blip) }
            } else if fireCD <= 0 {
                let bx: Float = px + fx * 0.4
                let by: Float = py + fy * 0.4
                bolts.append(Bolt(x: bx, y: by, dx: fx * 0.36, dy: fy * 0.36, owner: -1, life: 80))
                fireCD = 11
                heat += 15
                shots += 1
                recoil = 6
                muzzle = 4
                play(.shoot)
                if heat >= 100 {
                    heat = 100
                    overheated = true
                    addFeed("WEAPON OVERHEAT", Arena64.cOrange)
                    play(.pause)
                }
            }
        }
        // aim assist info for the crosshair
        aimed = false
        for b in bots {
            if !b.alive { continue }
            let dx: Float = b.x - px
            let dy: Float = b.y - py
            let d: Float = sqrt(dx * dx + dy * dy)
            if d < 0.5 || d > 18 { continue }
            let da: Float = abs(Arena64.wrapAngle(atan2(dy, dx) - ang))
            if da < 0.09 && hasLOS(px, py, b.x, b.y) { aimed = true }
        }
    }

    private func updateBolts() {
        var keep: [Bolt] = []
        for var bl in bolts {
            let ox = bl.x
            let oy = bl.y
            bl.x += bl.dx
            bl.y += bl.dy
            bl.life -= 1
            if solid(bl.x, bl.y) {
                impact(ox, oy, bl.owner)
                continue
            }
            var done = false
            if bl.owner < 0 {
                for i in 0..<bots.count {
                    if !bots[i].alive { continue }
                    let dx: Float = bots[i].x - bl.x
                    let dy: Float = bots[i].y - bl.y
                    if dx * dx + dy * dy < 0.26 {
                        hits += 1
                        hitMarker = 10
                        impact(bl.x, bl.y, -1)
                        done = true
                        break
                    }
                }
            } else {
                let dx: Float = px - bl.x
                let dy: Float = py - bl.y
                if dx * dx + dy * dy < 0.22 {
                    impact(bl.x, bl.y, bl.owner)
                    done = true
                }
            }
            if done { continue }
            if bl.life <= 0 {
                fxs.append(Fx(x: bl.x, y: bl.y, t: 0, maxT: 8, size: 0.4))
                continue
            }
            keep.append(bl)
        }
        bolts = keep
    }

    private func updateBot(_ i: Int) {
        var b = bots[i]
        if !b.alive { return }
        if b.flash > 0 { b.flash -= 1 }
        if b.fireCD > 0 { b.fireCD -= 1 }
        let dxp: Float = px - b.x
        let dyp: Float = py - b.y
        let dist: Float = sqrt(dxp * dxp + dyp * dyp)
        let toP: Float = atan2(dyp, dxp)
        let seen: Bool = dist < 17 && hasLOS(b.x, b.y, px, py)
        if seen { b.sight = 0 } else if b.sight < 9999 { b.sight += 1 }
        let baseSpeed: Float = 0.026 + 0.004 * Float(wave)
        var desired: Float = b.angle
        var moveAng: Float = b.angle
        var speed: Float = 0
        let lowHp: Bool = b.hp * 3 < b.maxHp

        switch b.state {
        case 0:
            let dxt: Float = b.tx - b.x
            let dyt: Float = b.ty - b.y
            desired = atan2(dyt, dxt)
            speed = baseSpeed * 0.7
            b.timer -= 1
            if dxt * dxt + dyt * dyt < 0.4 || b.timer <= 0 { pickWaypoint(&b) }
            if seen { b.state = 1 }
        case 1:
            desired = toP
            speed = baseSpeed
            if seen && dist < 6.5 {
                b.state = 2
                b.timer = 50 + rng.int(70)
                b.strafeDir = rng.chance(50) ? 1 : -1
            }
            if seen && lowHp && !b.coverUsed { pickCover(&b) }
            if b.sight > 160 {
                b.state = 0
                pickWaypoint(&b)
            }
        case 2:
            desired = toP
            moveAng = b.angle + b.strafeDir * 1.5708
            speed = baseSpeed * 0.75
            b.timer -= 1
            if b.timer <= 0 {
                b.strafeDir = -b.strafeDir
                b.timer = 40 + rng.int(60)
            }
            if dist < 2.4 {
                moveAng = b.angle + 3.14159
                speed = baseSpeed * 0.8
            }
            if dist > 9.5 || (!seen && b.sight > 45) { b.state = 1 }
            if seen && lowHp && !b.coverUsed { pickCover(&b) }
        default:
            let dxt: Float = b.tx - b.x
            let dyt: Float = b.ty - b.y
            desired = atan2(dyt, dxt)
            let arrived: Bool = dxt * dxt + dyt * dyt < 0.3
            speed = arrived ? 0 : baseSpeed * 1.15
            b.timer -= 1
            if arrived && seen == false { desired = toP }
            if b.timer <= 0 || (arrived && b.timer < 150) {
                b.state = 1
                b.hp = min(b.maxHp, b.hp + 8)
            }
        }

        let diff: Float = Arena64.wrapAngle(desired - b.angle)
        b.angle = Arena64.wrapAngle(b.angle + clamp(diff, -0.05, 0.05))
        if speed > 0 && (b.state == 2 || abs(diff) < 1.1) {
            let mx: Float = cos(moveAng) * speed
            let my: Float = sin(moveAng) * speed
            var np = tryMove(b.x, b.y, mx, my, 0.3)
            var moved: Float = abs(np.x - b.x) + abs(np.y - b.y)
            if moved < speed * 0.3 {
                let alt: Float = moveAng + b.strafeDir * 1.0
                np = tryMove(b.x, b.y, cos(alt) * speed, sin(alt) * speed, 0.3)
                moved = abs(np.x - b.x) + abs(np.y - b.y)
            }
            if moved < speed * 0.3 {
                b.stuck += 1
                if b.stuck > 25 {
                    b.stuck = 0
                    b.strafeDir = -b.strafeDir
                    if b.state != 2 {
                        b.state = 0
                        pickWaypoint(&b)
                    }
                }
            } else {
                b.stuck = 0
            }
            b.x = np.x
            b.y = np.y
        }
        // keep bots apart from each other and from the player
        for j in 0..<bots.count {
            if j == i || !bots[j].alive { continue }
            let dx: Float = b.x - bots[j].x
            let dy: Float = b.y - bots[j].y
            let d: Float = sqrt(dx * dx + dy * dy)
            if d < 0.7 && d > 0.001 {
                let q = tryMove(b.x, b.y, dx / d * 0.02, dy / d * 0.02, 0.3)
                b.x = q.x
                b.y = q.y
            }
        }
        if dist < 0.7 && dist > 0.001 {
            let q = tryMove(b.x, b.y, -dxp / dist * 0.03, -dyp / dist * 0.03, 0.3)
            b.x = q.x
            b.y = q.y
        }
        // firing
        if (b.state == 1 || b.state == 2 || (b.state == 3 && seen)) && seen && b.fireCD <= 0 && dist > 1.5 {
            let aimErr: Float = abs(Arena64.wrapAngle(toP - b.angle))
            if aimErr < 0.22 {
                let inacc: Float = max(0.07, 0.30 - 0.07 * Float(wave))
                let err: Float = (Float(rng.unit()) - 0.5) * 2.0 * inacc
                let a: Float = b.angle + err
                bolts.append(Bolt(x: b.x + cos(a) * 0.45, y: b.y + sin(a) * 0.45,
                                  dx: cos(a) * 0.19, dy: sin(a) * 0.19, owner: i, life: 140))
                b.fireCD = max(34, 100 - 14 * wave) + rng.int(45)
                if dist < 12 { play(.laser) }
            }
        }
        bots[i] = b
    }

    private func updatePickups() {
        var i = 0
        while i < pickups.count {
            var p = pickups[i]
            if p.active {
                let dx: Float = px - p.x
                let dy: Float = py - p.y
                if dx * dx + dy * dy < 0.5 && phase == .playing {
                    var took = false
                    if p.kind == 0 && health < 100 {
                        health = min(100, health + 35)
                        addFeed("+35 HEALTH", Arena64.cGreen)
                        took = true
                    } else if p.kind == 1 && shield < 100 {
                        shield = min(100, shield + 40)
                        addFeed("+40 SHIELD", Arena64.cCyan)
                        took = true
                    }
                    if took {
                        play(.powerup)
                        p.active = false
                        p.timer = 1000
                    }
                }
                if !p.perm {
                    p.timer -= 1
                    if p.timer <= 0 { p.active = false }
                }
            } else if p.perm {
                p.timer -= 1
                if p.timer <= 0 { p.active = true }
            }
            pickups[i] = p
            i += 1
        }
        pickups = pickups.filter { $0.perm || $0.active }
    }

    private func updateWorldFx() {
        var keep: [Fx] = []
        for var f in fxs {
            f.t += 1
            if f.t < f.maxT { keep.append(f) }
        }
        fxs = keep
        var fk: [Feed] = []
        for var f in feed {
            f.timer -= 1
            if f.timer > 0 { fk.append(f) }
        }
        feed = fk
        if dmgFlash > 0 { dmgFlash -= 1 }
        if hitMarker > 0 { hitMarker -= 1 }
    }

    override func update(_ input: InputState) {
        frame += 1
        updateWorldFx()
        switch phase {
        case .title:
            titleAng = Arena64.wrapAngle(titleAng + 0.008)
            if input.aPressed || input.startPressed {
                play(.confirm)
                beginGame()
            }
        case .playing:
            gameFrames += 1
            if invuln > 0 { invuln -= 1 }
            if waveBanner > 0 { waveBanner -= 1 }
            updatePlayer(input)
            if waveBanner < 100 {
                for i in 0..<bots.count { updateBot(i) }
            }
            updateBolts()
            updatePickups()
            if phase == .playing {
                var alive = 0
                for b in bots where b.alive { alive += 1 }
                if alive == 0 && !bots.isEmpty {
                    scoreValue += 250 * wave
                    phase = .clear
                    clearTimer = 170
                    addFeed("WAVE " + String(wave) + " CLEAR", Arena64.cYellow)
                    play(.win)
                }
            }
        case .clear:
            clearTimer -= 1
            if invuln < 30 { invuln = 30 }
            updatePlayer(input)
            updateBolts()
            updatePickups()
            if clearTimer <= 0 {
                if wave >= Arena64.totalWaves {
                    finishGame(true)
                } else {
                    health = min(100, health + 20)
                    phase = .playing
                    startWave(wave + 1)
                }
            }
        case .over:
            overTimer += 1
            if overTimer > 60 && (input.aPressed || input.startPressed) {
                play(.confirm)
                beginGame()
            }
        }
    }

    // MARK: - Rendering

    private func renderBackdrop(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ camX: Float, _ camY: Float,
                                _ dirX: Float, _ dirY: Float, _ heading: Float) {
        let sky = Arena64.skyRows
        for y in 0..<144 {
            let c = sky[y]
            let base = y * w
            for x in 0..<w { p[base + x] = c }
        }
        let stars = Arena64.stars
        for s in stars {
            let d: Float = Arena64.wrapAngle(s.ang - heading)
            if abs(d) < 0.95 {
                let sx = 160 + Int(tan(d) * Arena64.pxPerUnitX)
                if sx >= 0 && sx < w - 1 && s.y >= 0 && s.y < 144 {
                    p[s.y * w + sx] = s.c
                    p[s.y * w + sx + 1] = s.c
                }
            }
        }
        // floor
        let planeX: Float = -dirY * Arena64.planeLen
        let planeY: Float = dirX * Arena64.planeLen
        let rowDist = Arena64.rowDist
        let rowLit = Arena64.rowLit
        let ftex = Arena64.floorTex
        let zone = Arena64.zone
        let fogC = Arena64.cFogColor
        let fw: Float = Float(w)
        for y in 144..<min(h, 288) {
            let base = y * w
            let rd: Float = rowDist[y]
            if rd > 36 {
                for x in 0..<w { p[base + x] = fogC }
                continue
            }
            let lit = rowLit[y]
            let stepX: Float = rd * 2 * planeX / fw
            let stepY: Float = rd * 2 * planeY / fw
            var fx: Float = camX + rd * (dirX - planeX)
            var fy: Float = camY + rd * (dirY - planeY)
            for x in 0..<w {
                var zi = 0
                if fx >= 0 && fy >= 0 && fx < 24 && fy < 24 {
                    zi = Int(zone[Int(fy) * 24 + Int(fx)])
                }
                let tx = Int(fx * 64) & 63
                let ty = Int(fy * 64) & 63
                let c = ftex[zi * 4096 + ty * 64 + tx]
                p[base + x] = Arena64.shade(c, lit)
                fx += stepX
                fy += stepY
            }
        }
    }

    private func castWalls(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ camPX: Float, _ camPY: Float,
                           _ dirX: Float, _ dirY: Float) {
        let planeX: Float = -dirY * Arena64.planeLen
        let planeY: Float = dirX * Arena64.planeLen
        let map = Arena64.map
        let tex = Arena64.wallTex
        let hh = h / 2
        let fh: Float = Float(h)
        for x in 0..<w {
            let cam: Float = 2.0 * Float(x) / Float(w) - 1.0
            let rdx: Float = dirX + planeX * cam
            let rdy: Float = dirY + planeY * cam
            var mapX = max(0, min(23, Int(camPX)))
            var mapY = max(0, min(23, Int(camPY)))
            let ddx: Float = abs(rdx) < 0.00001 ? 100000 : abs(1.0 / rdx)
            let ddy: Float = abs(rdy) < 0.00001 ? 100000 : abs(1.0 / rdy)
            var stepX = 1
            var stepY = 1
            var sideX: Float = 0
            var sideY: Float = 0
            if rdx < 0 {
                stepX = -1
                sideX = (camPX - Float(mapX)) * ddx
            } else {
                sideX = (Float(mapX) + 1.0 - camPX) * ddx
            }
            if rdy < 0 {
                stepY = -1
                sideY = (camPY - Float(mapY)) * ddy
            } else {
                sideY = (Float(mapY) + 1.0 - camPY) * ddy
            }
            var side = 0
            var hit = 0
            var steps = 0
            while hit == 0 && steps < 64 {
                if sideX < sideY {
                    sideX += ddx
                    mapX += stepX
                    side = 0
                } else {
                    sideY += ddy
                    mapY += stepY
                    side = 1
                }
                steps += 1
                if mapX < 0 || mapY < 0 || mapX >= 24 || mapY >= 24 {
                    hit = 1
                } else {
                    let v = Int(map[mapY * 24 + mapX])
                    if v != 0 { hit = v }
                }
            }
            if hit == 0 { hit = 1 }
            var perp: Float = side == 0 ? (sideX - ddx) : (sideY - ddy)
            if !(perp >= 0.05) { perp = 0.05 }
            zbuf[x] = perp
            var lineH = Int(fh / perp)
            if lineH < 1 { lineH = 1 }
            let drawStart = max(0, hh - lineH / 2)
            let drawEnd = min(h, hh + lineH / 2)
            if drawStart >= drawEnd { continue }
            var wallX: Float = side == 0 ? (camPY + perp * rdy) : (camPX + perp * rdx)
            wallX -= floor(wallX)
            if !(wallX >= 0 && wallX < 1) { wallX = 0 }
            var texX = Int(wallX * 64)
            if side == 0 && rdx > 0 { texX = 63 - texX }
            if side == 1 && rdy < 0 { texX = 63 - texX }
            texX = max(0, min(63, texX))
            let texBase = max(0, min(4, hit - 1)) * 4096 + texX
            let step: Float = 64.0 / Float(lineH)
            var texPos: Float = Float(drawStart - hh + lineH / 2) * step
            var lit = 256 - Int(perp * 13)
            if lit < 80 { lit = 80 }
            if side == 1 { lit = (lit * 3) / 4 }
            for y in drawStart..<drawEnd {
                let ty = Int(texPos) & 63
                texPos += step
                let c = tex[texBase + ty * 64]
                p[y * w + x] = Arena64.shade(c, lit)
            }
        }
    }

    private func addBill(_ ex: Float, _ ey: Float, _ spr: Int, _ ww: Float, _ wh: Float, _ lift: Float,
                         _ lit: Int, _ white: Int, _ camPX: Float, _ camPY: Float) {
        let rx: Float = ex - camPX
        let ry: Float = ey - camPY
        let invDet: Float = 1.0 / (cPlaneX * cDirY - cDirX * cPlaneY)
        let tx: Float = invDet * (cDirY * rx - cDirX * ry)
        let ty: Float = invDet * (-cPlaneY * rx + cPlaneX * ry)
        if !(ty > 0.2) || ty > 40 { return }
        let sxf: Float = 160.0 * (1.0 + tx / ty)
        if !(sxf > -2000 && sxf < 2300) { return }
        let sw = Int(ww * Arena64.pxPerUnitX / ty)
        let sh = Int(wh * Arena64.pxPerUnitY / ty)
        if sw < 1 || sh < 1 || sw > 1400 || sh > 1400 { return }
        let sx = Int(sxf)
        if sx + sw / 2 < 0 || sx - sw / 2 > 320 { return }
        let bottom = 144 + Int((144.0 - lift * 288.0) / ty)
        bills.append(Bill(depth: ty, sx: sx, bottom: bottom, sw: sw, sh: sh, spr: spr, lit: lit, white: white))
    }

    private func buildBills(_ camPX: Float, _ camPY: Float) {
        bills.removeAll(keepingCapacity: true)
        for b in bots {
            if !b.alive { continue }
            let d: Float = sqrt((b.x - camPX) * (b.x - camPX) + (b.y - camPY) * (b.y - camPY))
            let lit = max(110, 256 - Int(d * 9))
            addBill(b.x, b.y, b.color, 0.95, 0.72, 0.0, lit, b.flash > 0 ? 170 : 0, camPX, camPY)
        }
        let bob: Float = sin(Float(frame) * 0.08) * 0.04
        for pk in pickups {
            if !pk.active { continue }
            addBill(pk.x, pk.y, 3 + pk.kind, 0.32, 0.30, 0.14 + bob, 256, 0, camPX, camPY)
        }
        for bl in bolts {
            let spr = bl.owner < 0 ? 5 : 6
            addBill(bl.x, bl.y, spr, 0.26, 0.24, 0.28, 256, 0, camPX, camPY)
        }
        for f in fxs {
            let t: Float = Float(f.t) / Float(max(1, f.maxT))
            let sz: Float = f.size * (0.35 + 0.9 * t)
            addBill(f.x, f.y, 7, sz, sz * 0.9, 0.12, 256, f.t < 3 ? 120 : 0, camPX, camPY)
        }
        bills.sort { $0.depth > $1.depth }
    }

    private func blit(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ it: Bill) {
        let sprs = Arena64.sprites
        if it.spr < 0 || it.spr >= sprs.count { return }
        let spr = sprs[it.spr]
        let sw = it.sw
        let sh = it.sh
        if sw < 1 || sh < 1 { return }
        let x0 = it.sx - sw / 2
        let y0 = it.bottom - sh
        let xs = max(0, x0)
        let xe = min(w, x0 + sw)
        let ys = max(0, y0)
        let ye = min(h, it.bottom)
        if xs >= xe || ys >= ye { return }
        let stepY = (spr.h << 16) / sh
        let stepX = (spr.w << 16) / sw
        let sprW = spr.w
        let sprH = spr.h
        let lit = it.lit
        let white = it.white
        let depth = it.depth
        spr.pix.withUnsafeBufferPointer { sp in
            for x in xs..<xe {
                if x < 320 && depth > zbuf[x] { continue }
                let sxp = max(0, min(sprW - 1, ((x - x0) * stepX) >> 16))
                for y in ys..<ye {
                    let syp = max(0, min(sprH - 1, ((y - y0) * stepY) >> 16))
                    let c = sp[syp * sprW + sxp]
                    if c == 0 { continue }
                    var o = c
                    if lit < 256 { o = Arena64.shade(o, lit) }
                    if white > 0 { o = Arena64.whiten(o, white) }
                    p[y * w + x] = o
                }
            }
        }
    }

    private func tintRed(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ amt: Int) {
        let n = w * h
        for i in 0..<n {
            let c = p[i]
            let r = Int(c & 255)
            let g = Int((c >> 8) & 255)
            let bl = Int((c >> 16) & 255)
            let r2 = r + (((255 - r) * amt) >> 9)
            let g2 = g - ((g * amt) >> 8)
            let b2 = bl - ((bl * amt) >> 8)
            p[i] = 0xFF00_0000 | UInt32(r2 & 255) | (UInt32(g2 & 255) << 8) | (UInt32(b2 & 255) << 16)
        }
    }

    override func drawTrueColor(_ b: TrueColorBuffer) {
        var camPX = px
        var camPY = py
        var heading = ang
        if phase == .title {
            camPX = 12.5
            camPY = 7.5
            heading = titleAng
        }
        let dirX: Float = cos(heading)
        let dirY: Float = sin(heading)
        cDirX = dirX
        cDirY = dirY
        cPlaneX = -dirY * Arena64.planeLen
        cPlaneY = dirX * Arena64.planeLen
        buildBills(camPX, camPY)
        let list = bills
        var flash = 0
        if dmgFlash > 0 { flash = min(170, dmgFlash * 9) }
        if phase == .over && !victory { flash = 150 }
        let cpx = camPX
        let cpy = camPY
        let hd = heading
        b.withPixels { p, w, h in
            if w < 320 || h < 288 { return }
            self.renderBackdrop(p, w, h, cpx, cpy, dirX, dirY, hd)
            self.castWalls(p, w, h, cpx, cpy, dirX, dirY)
            for it in list { self.blit(p, w, h, it) }
            if flash > 0 { self.tintRed(p, w, h, flash) }
        }
        if phase != .title {
            drawWeapon(b)
            drawHUD(b)
        }
        drawOverlays(b)
    }

    // MARK: - HUD

    private func otext(_ b: TrueColorBuffer, _ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        let k = max(1, scale / 2)
        let o = Arena64.cBlack
        b.text(s, x - k, y, o, scale: scale)
        b.text(s, x + k, y, o, scale: scale)
        b.text(s, x, y - k, o, scale: scale)
        b.text(s, x, y + k, o, scale: scale)
        b.text(s, x, y, c, scale: scale)
    }

    private func ctext(_ b: TrueColorBuffer, _ s: String, _ y: Int, _ c: UInt32, _ scale: Int) {
        let tw = b.textWidth(s, scale: scale)
        otext(b, s, (b.width - tw) / 2, y, c, scale)
    }

    private func bar(_ b: TrueColorBuffer, _ x: Int, _ y: Int, _ w: Int, _ h: Int, _ frac: Float, _ c: UInt32) {
        b.fillRect(x - 1, y - 1, w + 2, h + 2, Arena64.cBlack)
        b.fillRect(x, y, w, h, TrueColorBuffer.rgb(52, 52, 70))
        let fw = Int(clamp(frac, 0, 1) * Float(w))
        if fw > 0 { b.fillRect(x, y, fw, h, c) }
    }

    private func drawWeapon(_ b: TrueColorBuffer) {
        let rec = recoil * 2
        let gy = 226 + rec
        let hot = Int(clamp(heat, 0, 100) * 1.5)
        let glow = TrueColorBuffer.rgb(90 + hot, 230 - hot, 255 - hot * 2)
        b.fillRect(146, gy + 8, 28, 40, TrueColorBuffer.rgb(52, 56, 76))
        b.fillRect(148, gy + 8, 4, 40, TrueColorBuffer.rgb(110, 118, 150))
        b.fillRect(150, gy, 20, 14, TrueColorBuffer.rgb(120, 128, 160))
        b.fillRect(152, gy, 4, 14, TrueColorBuffer.rgb(190, 200, 230))
        b.fillRect(156, gy - 6, 8, 8, TrueColorBuffer.rgb(70, 74, 98))
        b.fillRect(157, gy - 4, 6, 4, glow)
        if muzzle > 0 {
            b.fillRect(150, gy - 18, 20, 14, Arena64.cWhite)
            b.fillRect(154, gy - 26, 12, 10, Arena64.cCyan)
        }
        // crosshair
        let cc: UInt32 = aimed ? Arena64.cRed : Arena64.cWhite
        b.fillRect(155, 143, 4, 2, cc)
        b.fillRect(163, 143, 4, 2, cc)
        b.fillRect(160, 138, 2, 4, cc)
        b.fillRect(160, 147, 2, 4, cc)
        if hitMarker > 0 {
            b.fillRect(152, 135, 4, 1, Arena64.cYellow)
            b.fillRect(166, 135, 4, 1, Arena64.cYellow)
            b.fillRect(152, 153, 4, 1, Arena64.cYellow)
            b.fillRect(166, 153, 4, 1, Arena64.cYellow)
        }
    }

    private func drawRadar(_ b: TrueColorBuffer) {
        let mx = 266
        let my = 6
        b.fillRect(mx - 2, my - 2, 52, 52, Arena64.cBlack)
        b.fillRect(mx, my, 48, 48, TrueColorBuffer.rgb(20, 40, 56))
        let wallC = TrueColorBuffer.rgb(120, 140, 190)
        let map = Arena64.map
        for y in 0..<24 {
            for x in 0..<24 {
                let v = map[y * 24 + x]
                if v == 0 { continue }
                var c = wallC
                if v == 4 { c = TrueColorBuffer.rgb(230, 90, 90) }
                if v == 5 { c = TrueColorBuffer.rgb(90, 140, 255) }
                b.fillRect(mx + x * 2, my + y * 2, 2, 2, c)
            }
        }
        for pk in pickups {
            if !pk.active { continue }
            let c: UInt32 = pk.kind == 0 ? Arena64.cGreen : Arena64.cCyan
            b.fillRect(mx + Int(pk.x * 2) - 1, my + Int(pk.y * 2) - 1, 2, 2, c)
        }
        for bt in bots {
            if !bt.alive { continue }
            let bx = max(0, min(46, Int(bt.x * 2) - 1))
            let by = max(0, min(46, Int(bt.y * 2) - 1))
            b.fillRect(mx + bx, my + by, 3, 3, Arena64.cRed)
        }
        let ppx = max(1, min(45, Int(px * 2)))
        let ppy = max(1, min(45, Int(py * 2)))
        b.fillRect(mx + ppx - 1, my + ppy - 1, 3, 3, Arena64.cWhite)
        for k in 2..<5 {
            let lx = ppx + Int(cos(ang) * Float(k) * 1.6)
            let ly = ppy + Int(sin(ang) * Float(k) * 1.6)
            if lx >= 0 && lx < 48 && ly >= 0 && ly < 48 { b.fillRect(mx + lx, my + ly, 1, 1, Arena64.cYellow) }
        }
    }

    private func drawHUD(_ b: TrueColorBuffer) {
        otext(b, "SCORE " + zeroPad(scoreValue, 5), 6, 6, Arena64.cWhite, 2)
        var fy = 24
        for f in feed {
            let col: UInt32 = f.timer < 40 ? TrueColorBuffer.rgb(170, 170, 190) : f.color
            otext(b, f.text, 6, fy, col, 1)
            fy += 9
        }
        drawRadar(b)
        // bottom panel
        b.fillRect(0, 254, 320, 34, Arena64.cPanel)
        b.fillRect(0, 254, 320, 2, Arena64.cCyan)
        b.text("HP", 6, 260, Arena64.cWhite, scale: 2)
        bar(b, 26, 260, 84, 8, Float(health) / 100.0, health < 35 ? Arena64.cRed : Arena64.cGreen)
        b.text("SH", 6, 273, Arena64.cWhite, scale: 2)
        bar(b, 26, 274, 84, 8, Float(shield) / 100.0, Arena64.cCyan)
        let heatLabel = overheated ? "HOT!" : "HEAT"
        let blink = overheated && ((frame / 6) & 1) == 0
        b.text(heatLabel, 122, 260, blink ? Arena64.cRed : Arena64.cWhite, scale: 2)
        var hc = Arena64.cYellow
        if heat > 75 { hc = Arena64.cRed } else if heat < 40 { hc = Arena64.cOrange }
        if overheated { hc = blink ? Arena64.cRed : TrueColorBuffer.rgb(140, 40, 40) }
        bar(b, 122, 274, 80, 8, heat / 100.0, hc)
        b.text("WAVE " + String(max(1, wave)) + "/" + String(Arena64.totalWaves), 214, 260, Arena64.cYellow, scale: 2)
        var alive = 0
        for bt in bots where bt.alive { alive += 1 }
        b.text("FOES " + String(alive), 214, 273, Arena64.cWhite, scale: 2)
        if invuln > 0 && phase == .playing && (frame & 4) == 0 {
            ctext(b, "SHIELDS UP", 200, Arena64.cCyan, 1)
        }
    }

    private func drawOverlays(_ b: TrueColorBuffer) {
        let yellow = Arena64.cYellow
        let white = Arena64.cWhite
        switch phase {
        case .title:
            b.fillRect(22, 36, 276, 150, Arena64.cBlack)
            b.fillRect(24, 38, 272, 146, Arena64.cPanel)
            b.fillRect(24, 38, 272, 3, Arena64.cCyan)
            b.fillRect(24, 181, 272, 3, Arena64.cCyan)
            ctext(b, "ARENA", 52, Arena64.cCyan, 8)
            ctext(b, "64", 100, white, 8)
            ctext(b, "HOVER TANK LASER TAG", 150, yellow, 1)
            ctext(b, "3 WAVES  ELIMINATE ALL BOTS", 164, white, 1)
            if (frame / 30) & 1 == 0 { ctext(b, "PRESS A TO FIGHT", 200, yellow, 3) }
            ctext(b, "UP DOWN DRIVE  LEFT RIGHT TURN", 236, white, 1)
            ctext(b, "B+PAD STRAFE  A FIRE", 248, white, 1)
        case .playing:
            if waveBanner > 0 {
                ctext(b, "WAVE " + String(wave), 74, yellow, 6)
                ctext(b, String(bots.count) + " HOSTILES", 118, white, 2)
            }
        case .clear:
            ctext(b, "WAVE CLEAR", 80, Arena64.cGreen, 5)
            ctext(b, "BONUS +" + String(250 * wave), 124, yellow, 2)
        case .over:
            b.fillRect(40, 46, 240, 190, Arena64.cBlack)
            b.fillRect(42, 48, 236, 186, Arena64.cPanel)
            b.fillRect(42, 48, 236, 3, victory ? Arena64.cGreen : Arena64.cRed)
            ctext(b, victory ? "ARENA CLEARED" : "TANK DESTROYED", 60, victory ? Arena64.cGreen : Arena64.cRed, 3)
            ctext(b, "WAVE " + String(max(1, wave)) + " OF " + String(Arena64.totalWaves), 96, white, 2)
            ctext(b, "KILLS " + String(kills), 120, white, 2)
            var acc = 0
            if shots > 0 { acc = (hits * 100) / shots }
            ctext(b, "ACCURACY " + String(acc) + "%", 140, white, 2)
            ctext(b, "TIME " + String(gameFrames / 3600) + ":" + zeroPad((gameFrames / 60) % 60, 2), 160, white, 2)
            ctext(b, "SCORE " + zeroPad(scoreValue, 5), 186, yellow, 3)
            if overTimer > 60 && (frame / 30) & 1 == 0 { ctext(b, "PRESS A", 214, white, 2) }
        }
    }
}

extension Cartridge {
    static let arena64 = Cartridge(
        id: "arena64", title: "ARENA 64", genre: "Shooter",
        blurb: "Hover tank laser tag in a neon arena. Dodge plasma, watch your heat and clear three waves of bot tanks.",
        controls: "UP/DOWN drive, LEFT/RIGHT turn, B+LEFT/RIGHT strafe, A fire plasma (watch the heat).",
        era: .n64, labelTop: 0x28C8E8, labelBottom: 0x3A1068, factory: { Arena64() })
}
