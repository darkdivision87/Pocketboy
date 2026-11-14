#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// ROBOT RAID 64: a first-person toy-factory robot shooter. A DDA raycaster draws candy-stripe walls, toy-block
/// textures and a scrolling conveyor floor; cartoon robots (walkers, shielded tanks, propeller drones and a boss mech
/// every fifth wave) are procedural billboards with a z-buffer. Soft auto-aim steers the view and homes the shots,
/// B dashes, and three maps unlock as the waves go by.
final class RobotRaid64: Game {
    // MARK: - Constants

    static let mapN = 20
    static let planeLen: Float = 0.66
    static let pxX: Float = 242.0
    static let pxY: Float = 288.0
    static let maxWave = 15
    static let maxHearts = 5

    /// Highest map index unlocked so far (kept for the whole app session).
    static var unlocked = 0

    static let cWhite: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    static let cBlack: UInt32 = TrueColorBuffer.rgb(24, 14, 44)
    static let cYellow: UInt32 = TrueColorBuffer.rgb(255, 228, 70)
    static let cRed: UInt32 = TrueColorBuffer.rgb(255, 80, 96)
    static let cGreen: UInt32 = TrueColorBuffer.rgb(100, 240, 130)
    static let cCyan: UInt32 = TrueColorBuffer.rgb(90, 232, 255)
    static let cOrange: UInt32 = TrueColorBuffer.rgb(255, 154, 40)
    static let cPink: UInt32 = TrueColorBuffer.rgb(255, 120, 204)
    static let cPanel: UInt32 = TrueColorBuffer.rgb(44, 30, 96)
    static let cBarBack: UInt32 = TrueColorBuffer.rgb(70, 56, 120)

    static let mapNames: [String] = ["TOY FACTORY", "CANDY LINE", "BLOCK TOWER"]
    static let fogs: [[Int]] = [[96, 150, 232], [232, 116, 176], [132, 104, 222]]
    static let ceilTop: [[Int]] = [[190, 230, 255], [255, 220, 240], [226, 214, 255]]
    static let starts: [[Float]] = [[10.5, 8.5], [5.5, 8.5], [9.5, 9.5]]

    static let tune = Tune(bpm: 152, wave: .pulse25, volume: 0.12,
        "E5:0.5 G5:0.5 C6:0.5 G5:0.5 E5:0.5 G5:0.5 D6:1 B5:0.5 D6:0.5 G5:0.5 B5:0.5 A5:0.5 F5:0.5 A5:1 R:0.5 C5:0.5 E5:0.5 G5:0.5 E5:0.5 C6:1 B5:0.5 G5:0.5 A5:0.5 F5:0.5 D5:0.5 F5:0.5 G5:1.5 R:0.5")

    // sprite indices
    static let sprTank = 6
    static let sprTankOpen = 7
    static let sprDrone = 8
    static let sprBoss = 12
    static let sprHeart = 14
    static let sprAmmo = 15
    static let sprRapid = 16
    static let sprTriple = 17
    static let sprShield = 18
    static let sprBall = 19
    static let sprBigBall = 20
    static let sprBolt = 21
    static let sprSpark = 22
    static let sprCog = 23
    static let sprPuff = 24

    // MARK: - Nested types

    struct Pt {
        var x: Float
        var y: Float
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

    struct Robot {
        var kind: Int = 0
        var variant: Int = 0
        var x: Float = 0
        var y: Float = 0
        var hp: Float = 3
        var maxHp: Float = 3
        var alive: Bool = true
        var appear: Int = 40
        var state: Int = 0
        var timer: Int = 0
        var cd: Int = 100
        var flash: Int = 0
        var phase: Float = 0
        var strafe: Float = 1
        var stuck: Int = 0
        var summoned: Bool = false
        var shieldUp: Bool = false
    }

    struct Ball {
        var x: Float
        var y: Float
        var dx: Float
        var dy: Float
        var life: Int
        var big: Bool
    }

    struct Bolt {
        var x: Float
        var y: Float
        var dx: Float
        var dy: Float
        var life: Int
        var target: Int
    }

    struct Part {
        var x: Float
        var y: Float
        var z: Float
        var vx: Float
        var vy: Float
        var vz: Float
        var life: Int
        var spr: Int
        var size: Float
    }

    struct Pickup {
        var x: Float
        var y: Float
        var kind: Int
        var life: Int
    }

    struct Pop {
        var x: Float
        var y: Float
        var text: String
        var t: Int
        var color: UInt32
        var big: Bool
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
        var orange: Bool
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

    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
        return TrueColorBuffer.rgb(r, g, b)
    }

    static let mapRows: [[String]] = [
        [
            "11111111111111111111",
            "1..................1",
            "1.22....====....22.1",
            "1.2..............2.1",
            "1......3....3......1",
            "1......3....3......1",
            "1.===..........===.1",
            "1......33..33......1",
            "1..................1",
            "1.....=======......1",
            "1.....=======......1",
            "1..................1",
            "1......33..33......1",
            "1.===..........===.1",
            "1......3....3......1",
            "1......3....3......1",
            "1.2..............2.1",
            "1.22....====....22.1",
            "1..................1",
            "11111111111111111111"
        ],
        [
            "33333333333333333333",
            "3..................3",
            "3.11....====....11.3",
            "3.1..............1.3",
            "3....22......22....3",
            "3....2........2....3",
            "3..===........===..3",
            "3........33........3",
            "3........33........3",
            "3.==............==.3",
            "3.==............==.3",
            "3........33........3",
            "3........33........3",
            "3..===........===..3",
            "3....2........2....3",
            "3....22......22....3",
            "3.1..............1.3",
            "3.11....====....11.3",
            "3..................3",
            "33333333333333333333"
        ],
        [
            "22222222222222222222",
            "2..................2",
            "2.5..............6.2",
            "2.5..4444..4444..6.2",
            "2....4........4....2",
            "2....4........4....2",
            "2.==............==.2",
            "2.==...3....3...==.2",
            "2......3....3......2",
            "2..................2",
            "2..................2",
            "2......3....3......2",
            "2.==...3....3...==.2",
            "2.==............==.2",
            "2....4........4....2",
            "2....4........4....2",
            "2.5..4444..4444..6.2",
            "2.5..............6.2",
            "2..................2",
            "22222222222222222222"
        ]
    ]

    /// Wall values per map (0 = open, 1...6 = wall texture).
    static let mapWalls: [[UInt8]] = {
        var out: [[UInt8]] = []
        for rows in RobotRaid64.mapRows {
            var m = [UInt8](repeating: 1, count: 400)
            for y in 0..<20 {
                if y >= rows.count { continue }
                let chars = Array(rows[y])
                for x in 0..<20 {
                    if x >= chars.count { continue }
                    let ch = chars[x]
                    var v: UInt8 = 0
                    switch ch {
                    case "1": v = 1
                    case "2": v = 2
                    case "3": v = 3
                    case "4": v = 4
                    case "5": v = 5
                    case "6": v = 6
                    default: v = 0
                    }
                    m[y * 20 + x] = v
                }
            }
            out.append(m)
        }
        return out
    }()

    /// 1 = conveyor belt floor.
    static let mapZones: [[UInt8]] = {
        var out: [[UInt8]] = []
        for rows in RobotRaid64.mapRows {
            var z = [UInt8](repeating: 0, count: 400)
            for y in 0..<20 {
                if y >= rows.count { continue }
                let chars = Array(rows[y])
                for x in 0..<20 {
                    if x >= chars.count { continue }
                    if chars[x] == "=" { z[y * 20 + x] = 1 }
                }
            }
            out.append(z)
        }
        return out
    }()

    static let openCells: [[Pt]] = {
        var out: [[Pt]] = []
        for m in RobotRaid64.mapWalls {
            var list: [Pt] = []
            for y in 1..<19 {
                for x in 1..<19 {
                    if m[y * 20 + x] == 0 { list.append(Pt(x: Float(x) + 0.5, y: Float(y) + 0.5)) }
                }
            }
            if list.isEmpty { list.append(Pt(x: 2.5, y: 2.5)) }
            out.append(list)
        }
        return out
    }()

    static let rowDist: [Float] = {
        var a = [Float](repeating: 1000, count: 288)
        for y in 145..<288 { a[y] = 144.0 / Float(y - 144) }
        return a
    }()

    static let rowLit: [Int] = {
        var a = [Int](repeating: 90, count: 288)
        for y in 145..<288 {
            let d: Float = 144.0 / Float(y - 144)
            a[y] = max(90, min(256, 275 - Int(d * 18)))
        }
        return a
    }()

    static let wallTex: UnsafeMutablePointer<UInt32> = RobotRaid64.buildWallTex()
    static let floorTex: UnsafeMutablePointer<UInt32> = RobotRaid64.buildFloorTex()
    static let sprites: [SpriteImg] = RobotRaid64.makeSprites()

    static let heartCells: [[Int]] = {
        let rows: [String] = [".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]
        var out: [[Int]] = []
        for (ry, row) in rows.enumerated() {
            for (cx, ch) in Array(row).enumerated() {
                if ch == "X" { out.append([cx, ry]) }
            }
        }
        return out
    }()

    static let starCells: [[Int]] = {
        let rows: [String] = ["....X....", "....X....", "...XXX...", "XXXXXXXXX", ".XXXXXXX.", "..XXXXX..", "..XXXXX..", ".XXX.XXX.", ".XX...XX."]
        var out: [[Int]] = []
        for (ry, row) in rows.enumerated() {
            for (cx, ch) in Array(row).enumerated() {
                if ch == "X" { out.append([cx, ry]) }
            }
        }
        return out
    }()

    @inline(__always) static func shade(_ c: UInt32, _ lit: Int, _ fr: Int, _ fg: Int, _ fb: Int) -> UInt32 {
        let r = Int(c & 255)
        let g = Int((c >> 8) & 255)
        let bl = Int((c >> 16) & 255)
        let inv = 256 - lit
        let r2 = (r * lit + fr * inv) >> 8
        let g2 = (g * lit + fg * inv) >> 8
        let b2 = (bl * lit + fb * inv) >> 8
        return 0xFF00_0000 | UInt32(r2 & 255) | (UInt32(g2 & 255) << 8) | (UInt32(b2 & 255) << 16)
    }

    @inline(__always) static func tintTo(_ c: UInt32, _ amt: Int, _ tr: Int, _ tg: Int, _ tb: Int) -> UInt32 {
        let r = Int(c & 255)
        let g = Int((c >> 8) & 255)
        let bl = Int((c >> 16) & 255)
        let r2 = r + (((tr - r) * amt) >> 8)
        let g2 = g + (((tg - g) * amt) >> 8)
        let b2 = bl + (((tb - bl) * amt) >> 8)
        return 0xFF00_0000 | UInt32(r2 & 255) | (UInt32(g2 & 255) << 8) | (UInt32(b2 & 255) << 16)
    }

    // MARK: - Textures

    static func buildWallTex() -> UnsafeMutablePointer<UInt32> {
        let total = 6 * 4096
        let t = UnsafeMutablePointer<UInt32>.allocate(capacity: total)
        t.initialize(repeating: 0xFF00_0000, count: total)
        let brickCols: [[Int]] = [[240, 80, 84], [255, 204, 44], [64, 172, 250], [96, 214, 104]]
        for ty in 0..<64 {
            for tx in 0..<64 {
                let n = RobotRaid64.hash(tx, ty) & 7
                let i = ty * 64 + tx
                // 0: candy stripes
                var r = 255
                var g = 250
                var b = 250
                if (((tx + ty) / 8) & 1) == 1 {
                    r = 246; g = 74; b = 108
                }
                r -= n; g -= n; b -= n
                if ty < 4 || ty >= 60 {
                    r = 255; g = 214; b = 70
                }
                t[i] = RobotRaid64.rgb(r, g, b)
                // 1: toy blocks
                let row = ty / 16
                let offs = (row & 1) * 16
                let bxAbs = tx + offs
                let bx = bxAbs & 31
                let by = ty & 15
                let ci = RobotRaid64.hash(bxAbs / 32, row) & 3
                var br = brickCols[ci][0] + n
                var bg = brickCols[ci][1] + n
                var bb = brickCols[ci][2] + n
                if bx == 0 || by == 0 {
                    br = br / 2; bg = bg / 2; bb = bb / 2
                } else if bx == 1 || by == 1 {
                    br += 40; bg += 40; bb += 40
                }
                if bx >= 11 && bx <= 20 && by >= 4 && by <= 11 {
                    let sdx = bx - 15
                    let sdy = by - 8
                    if sdx * sdx + sdy * sdy <= 16 {
                        br += 34; bg += 34; bb += 34
                        if sdx * sdx + sdy * sdy > 10 {
                            br -= 60; bg -= 60; bb -= 60
                        }
                    }
                }
                t[4096 + i] = RobotRaid64.rgb(br, bg, bb)
                // 2: blue and cream checkers with a gold trim
                var cr = 70
                var cg = 124
                var cb = 244
                if (((tx / 16) + (ty / 16)) & 1) == 1 {
                    cr = 255; cg = 238; cb = 150
                }
                cr += n; cg += n; cb += n
                if (tx & 15) == 0 || (ty & 15) == 0 {
                    cr -= 40; cg -= 40; cb -= 40
                }
                t[8192 + i] = RobotRaid64.rgb(cr, cg, cb)
                // 3: mint polka dots
                var mr = 118
                var mg = 230
                var mb = 190
                let pdx = (tx & 31) - 16
                let pdy = (ty & 31) - 16
                if pdx * pdx + pdy * pdy < 40 {
                    mr = 255; mg = 150; mb = 204
                    if pdx * pdx + pdy * pdy < 12 {
                        mr = 255; mg = 220; mb = 236
                    }
                }
                mr += n; mg += n; mb += n
                if ty < 3 || ty >= 61 {
                    mr = 255; mg = 255; mb = 255
                }
                t[12288 + i] = RobotRaid64.rgb(mr, mg, mb)
                // 4 and 5: coloured doors
                for k in 0..<2 {
                    var dr = 255
                    var dg = 208
                    var db = 60
                    var kr = 235
                    var kg = 60
                    var kb = 70
                    if k == 1 {
                        dr = 255; dg = 112; db = 192
                        kr = 80; kg = 230; kb = 255
                    }
                    dr += n; dg += n; db += n
                    if tx < 4 || tx >= 60 || ty < 4 {
                        dr = dr * 6 / 10; dg = dg * 5 / 10; db = db * 5 / 10
                    } else if tx >= 10 && tx < 54 && ty >= 10 && ty < 60 {
                        dr += 14; dg += 14; db += 14
                        if tx < 12 || tx >= 52 || ty < 12 {
                            dr = dr * 7 / 10; dg = dg * 7 / 10; db = db * 7 / 10
                        }
                    }
                    if tx >= 46 && tx < 52 && ty >= 32 && ty < 38 {
                        dr = kr; dg = kg; db = kb
                    }
                    let inBand: Bool = ty >= 20 && ty < 26
                    let inSpan: Bool = tx >= 16 && tx < 48
                    let stripe: Int = (tx / 4) & 1
                    if inBand && inSpan && stripe == 0 {
                        dr = 250; dg = 250; db = 250
                    }
                    t[(4 + k) * 4096 + i] = RobotRaid64.rgb(dr, dg, db)
                }
            }
        }
        return t
    }

    static func buildFloorTex() -> UnsafeMutablePointer<UInt32> {
        let total = 6 * 4096
        let t = UnsafeMutablePointer<UInt32>.allocate(capacity: total)
        t.initialize(repeating: 0xFF00_0000, count: total)
        let pairs: [[Int]] = [
            [255, 240, 208, 110, 196, 232],
            [255, 196, 224, 255, 255, 255],
            [212, 196, 255, 255, 232, 130]
        ]
        for s in 0..<3 {
            for ty in 0..<64 {
                for tx in 0..<64 {
                    let n = RobotRaid64.hash(tx + s * 5, ty) & 7
                    var k = 0
                    if (((tx >> 5) + (ty >> 5)) & 1) == 1 { k = 3 }
                    var r = pairs[s][k] - n
                    var g = pairs[s][k + 1] - n
                    var b = pairs[s][k + 2] - n
                    if (tx & 31) == 0 || (ty & 31) == 0 {
                        r -= 50; g -= 50; b -= 50
                    }
                    t[(s * 2) * 4096 + ty * 64 + tx] = RobotRaid64.rgb(r, g, b)
                    // conveyor belt with chevrons
                    var cr = 62
                    var cg = 64
                    var cb = 92
                    let v = abs(tx - 32)
                    if (((ty + v) / 8) & 1) == 0 {
                        cr = 255; cg = 206; cb = 44
                    }
                    if tx < 3 || tx >= 61 {
                        cr = 190; cg = 192; cb = 206
                    }
                    cr -= n; cg -= n; cb -= n
                    t[(s * 2 + 1) * 4096 + ty * 64 + tx] = RobotRaid64.rgb(cr, cg, cb)
                }
            }
        }
        return t
    }

    // MARK: - Sprites

    static func makeWalker(_ r: Int, _ g: Int, _ bl: Int, _ frame: Int) -> SpriteImg {
        var p = Pix(32, 40)
        let body = rgb(r, g, bl)
        let light = rgb(r + 60, g + 60, bl + 60)
        let dark = rgb(r * 6 / 10, g * 6 / 10, bl * 6 / 10)
        let metal = rgb(196, 202, 216)
        let white = rgb(255, 255, 255)
        let ink = rgb(30, 20, 50)
        let leftH = frame == 0 ? 8 : 6
        let rightH = frame == 0 ? 6 : 8
        p.rect(9, 31, 5, leftH, dark)
        p.rect(7, 31 + leftH - 2, 9, 3, ink)
        p.rect(19, 31, 5, rightH, dark)
        p.rect(17, 31 + rightH - 2, 9, 3, ink)
        p.rect(6, 15, 20, 16, body)
        p.rect(6, 15, 20, 2, light)
        p.rect(6, 28, 20, 3, dark)
        p.rect(11, 19, 10, 7, rgb(255, 226, 90))
        p.rect(13, 21, 2, 2, rgb(230, 50, 70))
        p.rect(17, 21, 2, 2, rgb(60, 200, 90))
        p.rect(2, 17, 4, 10, dark)
        p.rect(26, 17, 4, 10, dark)
        p.disc(4, 28, 2, metal)
        p.disc(28, 28, 2, metal)
        p.rect(8, 3, 16, 12, light)
        p.rect(8, 12, 16, 3, body)
        p.rect(10, 6, 5, 5, white)
        p.rect(17, 6, 5, 5, white)
        p.rect(12, 8, 2, 3, ink)
        p.rect(19, 8, 2, 3, ink)
        p.rect(12, 13, 8, 1, ink)
        p.rect(15, 0, 2, 3, metal)
        p.disc(16, 1, 1, rgb(255, 80, 90))
        p.outline(ink)
        return SpriteImg(w: p.w, h: p.h, pix: p.d)
    }

    static func makeTank(_ shield: Bool) -> SpriteImg {
        var p = Pix(48, 40)
        let body = rgb(70, 140, 255)
        let light = rgb(140, 196, 255)
        let dark = rgb(40, 84, 190)
        let metal = rgb(196, 202, 216)
        let ink = rgb(30, 20, 50)
        p.rect(2, 30, 44, 8, rgb(70, 66, 96))
        p.disc(8, 34, 3, metal)
        p.disc(18, 34, 3, metal)
        p.disc(30, 34, 3, metal)
        p.disc(40, 34, 3, metal)
        p.rect(5, 17, 38, 14, body)
        p.rect(5, 17, 38, 2, light)
        p.rect(5, 28, 38, 3, dark)
        p.disc(24, 15, 10, body)
        p.disc(23, 12, 6, light)
        p.rect(15, 11, 18, 6, ink)
        p.rect(17, 12, 4, 3, rgb(255, 226, 90))
        p.rect(27, 12, 4, 3, rgb(255, 226, 90))
        p.rect(21, 0, 6, 8, metal)
        if shield {
            p.rect(4, 14, 40, 18, rgb(120, 214, 255))
            p.rect(4, 14, 40, 2, rgb(230, 250, 255))
            p.rect(4, 30, 40, 2, rgb(60, 130, 220))
            var x = 6
            while x < 42 {
                p.rect(x, 20, 4, 6, rgb(255, 214, 60))
                x += 8
            }
        } else {
            p.disc(24, 1, 3, rgb(255, 150, 40))
            p.rect(23, 0, 2, 2, rgb(255, 255, 200))
        }
        p.outline(ink)
        return SpriteImg(w: p.w, h: p.h, pix: p.d)
    }

    static func makeDrone(_ r: Int, _ g: Int, _ bl: Int, _ frame: Int) -> SpriteImg {
        var p = Pix(40, 30)
        let body = rgb(r, g, bl)
        let light = rgb(r + 60, g + 60, bl + 60)
        let dark = rgb(r * 6 / 10, g * 6 / 10, bl * 6 / 10)
        let metal = rgb(210, 214, 226)
        let ink = rgb(30, 20, 50)
        if frame == 0 {
            p.rect(2, 3, 36, 3, metal)
        } else {
            p.rect(9, 3, 22, 3, light)
            p.rect(4, 4, 32, 1, rgb(200, 210, 240))
        }
        p.rect(19, 6, 2, 5, dark)
        p.rect(5, 15, 4, 6, dark)
        p.rect(31, 15, 4, 6, dark)
        p.disc(20, 17, 10, body)
        p.disc(20, 13, 6, light)
        p.disc(20, 18, 5, rgb(255, 255, 255))
        p.disc(20, 19, 3, ink)
        p.set(19, 18, rgb(255, 255, 255))
        p.rect(10, 26, 3, 3, dark)
        p.rect(27, 26, 3, 3, dark)
        p.outline(ink)
        return SpriteImg(w: p.w, h: p.h, pix: p.d)
    }

    static func makeBoss(_ frame: Int) -> SpriteImg {
        var p = Pix(64, 72)
        let body = rgb(255, 120, 60)
        let light = rgb(255, 190, 120)
        let dark = rgb(190, 70, 40)
        let metal = rgb(196, 202, 216)
        let ink = rgb(30, 20, 50)
        let white = rgb(255, 255, 255)
        let off = frame == 0 ? 0 : 3
        p.rect(14, 56, 11, 12 - off, dark)
        p.rect(39, 56, 11, 9 + off, dark)
        p.rect(11, 64 - off, 17, 6, ink)
        p.rect(36, 61 + off, 17, 6, ink)
        p.rect(10, 22, 44, 36, body)
        p.rect(10, 22, 44, 3, light)
        p.rect(10, 52, 44, 6, dark)
        p.rect(22, 30, 20, 16, rgb(255, 232, 100))
        p.rect(30, 33, 4, 10, rgb(230, 50, 70))
        p.rect(27, 36, 10, 4, rgb(230, 50, 70))
        p.disc(8, 28, 8, dark)
        p.disc(56, 28, 8, dark)
        p.rect(0, 30, 8, 22, body)
        p.rect(56, 30, 8, 22, body)
        p.rect(1, 50, 6, 8, metal)
        p.rect(57, 50, 6, 8, metal)
        p.rect(2, 56, 4, 3, rgb(255, 150, 40))
        p.rect(58, 56, 4, 3, rgb(255, 150, 40))
        p.rect(18, 5, 28, 19, light)
        p.rect(18, 18, 28, 6, body)
        p.rect(21, 10, 22, 8, ink)
        let eye = frame == 0 ? rgb(255, 230, 70) : rgb(255, 110, 90)
        p.rect(24, 11, 5, 5, eye)
        p.rect(35, 11, 5, 5, eye)
        p.rect(24, 20, 16, 3, white)
        p.rect(28, 20, 1, 3, ink)
        p.rect(32, 20, 1, 3, ink)
        p.rect(36, 20, 1, 3, ink)
        p.rect(30, 0, 4, 5, metal)
        p.disc(32, 1, 3, rgb(255, 80, 90))
        p.outline(ink)
        return SpriteImg(w: p.w, h: p.h, pix: p.d)
    }

    static func makePickup(_ kind: Int) -> SpriteImg {
        var p = Pix(24, 24)
        let ink = rgb(30, 20, 50)
        let white = rgb(255, 255, 255)
        var bub = rgb(255, 150, 190)
        switch kind {
        case 0: bub = rgb(255, 150, 190)
        case 1: bub = rgb(255, 214, 80)
        case 2: bub = rgb(110, 230, 120)
        case 3: bub = rgb(110, 220, 255)
        default: bub = rgb(120, 150, 255)
        }
        p.disc(12, 12, 11, bub)
        p.disc(12, 12, 9, rgb(255, 255, 255))
        p.disc(12, 12, 8, bub)
        switch kind {
        case 0:
            let red = rgb(236, 40, 70)
            p.disc(8, 10, 4, red)
            p.disc(16, 10, 4, red)
            for i in 0..<9 { p.rect(4 + i, 11 + i, 17 - 2 * i, 1, red) }
            p.set(7, 8, white)
            p.set(8, 8, white)
        case 1:
            let org = rgb(255, 130, 30)
            for k in 0..<3 {
                p.rect(7 + k * 4, 9, 3, 9, org)
                p.rect(7 + k * 4, 7, 3, 3, rgb(255, 255, 200))
            }
        case 2:
            let yel = rgb(255, 238, 70)
            p.rect(11, 4, 5, 6, yel)
            p.rect(8, 9, 8, 4, yel)
            p.rect(8, 12, 5, 8, yel)
            p.rect(13, 11, 3, 3, yel)
        case 3:
            let c = rgb(255, 255, 255)
            p.disc(12, 7, 2, c)
            p.disc(7, 15, 2, c)
            p.disc(17, 15, 2, c)
            p.rect(11, 9, 2, 6, c)
        default:
            let c = rgb(255, 255, 255)
            p.rect(7, 6, 10, 7, c)
            p.rect(8, 13, 8, 3, c)
            p.rect(10, 16, 4, 3, c)
            p.rect(11, 8, 2, 9, rgb(60, 100, 230))
        }
        p.outline(ink)
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
                if ragged && d > 0.7 && (hash(x, y) & 3) == 0 { continue }
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

    static func makeSpark() -> SpriteImg {
        var p = Pix(16, 16)
        let y1 = rgb(255, 240, 90)
        let w1 = rgb(255, 255, 255)
        p.rect(7, 1, 2, 14, y1)
        p.rect(1, 7, 14, 2, y1)
        p.rect(4, 4, 8, 8, y1)
        p.rect(6, 6, 4, 4, w1)
        return SpriteImg(w: p.w, h: p.h, pix: p.d)
    }

    static func makeCog() -> SpriteImg {
        var p = Pix(16, 16)
        let g1 = rgb(190, 196, 214)
        let g2 = rgb(120, 126, 150)
        p.disc(8, 8, 5, g1)
        p.rect(7, 1, 2, 3, g1)
        p.rect(7, 12, 2, 3, g1)
        p.rect(1, 7, 3, 2, g1)
        p.rect(12, 7, 3, 2, g1)
        p.disc(8, 8, 2, g2)
        p.set(8, 8, 0)
        p.outline(rgb(30, 20, 50))
        return SpriteImg(w: p.w, h: p.h, pix: p.d)
    }

    static func makeSprites() -> [SpriteImg] {
        var list: [SpriteImg] = []
        // 0...5 walkers (3 colours x 2 frames)
        let wc: [[Int]] = [[246, 90, 96], [92, 210, 110], [190, 100, 240]]
        for c in wc {
            list.append(makeWalker(c[0], c[1], c[2], 0))
            list.append(makeWalker(c[0], c[1], c[2], 1))
        }
        list.append(makeTank(true))
        list.append(makeTank(false))
        // 8...11 drones (2 colours x 2 frames)
        list.append(makeDrone(255, 190, 50, 0))
        list.append(makeDrone(255, 190, 50, 1))
        list.append(makeDrone(80, 214, 230, 0))
        list.append(makeDrone(80, 214, 230, 1))
        list.append(makeBoss(0))
        list.append(makeBoss(1))
        for k in 0..<5 { list.append(makePickup(k)) }
        list.append(makeOrb(rgb(255, 255, 210), rgb(255, 160, 30), rgb(240, 70, 24), false))
        list.append(makeOrb(rgb(255, 255, 210), rgb(255, 130, 30), rgb(230, 40, 40), true))
        list.append(makeOrb(rgb(255, 255, 255), rgb(100, 244, 255), rgb(40, 150, 255), false))
        list.append(makeSpark())
        list.append(makeCog())
        list.append(makeOrb(rgb(255, 255, 230), rgb(255, 214, 90), rgb(255, 130, 60), true))
        return list
    }

    // MARK: - Game state

    private var phase: Phase = .title
    private var frame = 0
    private var rng = Rng()
    private let zbuf: UnsafeMutablePointer<Float>

    private var px: Float = 10.5
    private var py: Float = 8.5
    private var vx: Float = 0
    private var vy: Float = 0
    private var ang: Float = 0
    private var turnHold = 0
    private var hearts = 5
    private var ammo: Float = 100
    private var ammoLock = false
    private var fireCD = 0
    private var dashCD = 0
    private var dashT = 0
    private var dashVX: Float = 0
    private var dashVY: Float = 0
    private var rapidT = 0
    private var tripleT = 0
    private var shieldT = 0
    private var invuln = 0
    private var dmgFlash = 0
    private var pickFlash = 0
    private var shake = 0
    private var recoil = 0
    private var muzzle = 0
    private var hitMarker = 0
    private var lockedTarget = -1
    private var bobT: Float = 0

    private var robots: [Robot] = []
    private var balls: [Ball] = []
    private var bolts: [Bolt] = []
    private var parts: [Part] = []
    private var pickups: [Pickup] = []
    private var pops: [Pop] = []
    private var bills: [Bill] = []

    private var wave = 0
    private var mapIdx = 0
    private var titleMap = 0
    private var titleAng: Float = 0
    private var waveBanner = 0
    private var bannerText = ""
    private var clearTimer = 0
    private var overTimer = 0
    private var victory = false
    private var kills = 0
    private var scoreValue = 0
    private var combo = 0
    private var comboT = 0
    private var bestCombo = 0
    private var shots = 0
    private var hits = 0
    private var hintT = 0
    private var showMap = false
    private var newUnlock = false

    private var cX: Float = 0
    private var cY: Float = 0
    private var cDirX: Float = 1
    private var cDirY: Float = 0
    private var cPlaneX: Float = 0
    private var cPlaneY: Float = 0.66
    private var fogR = 96
    private var fogG = 150
    private var fogB = 232

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
        playMusic(RobotRaid64.tune)
    }

    // MARK: - Setup

    private func resetGame() {
        mapIdx = titleMap
        loadMap(mapIdx)
        hearts = RobotRaid64.maxHearts
        ammo = 100
        ammoLock = false
        fireCD = 0
        dashCD = 0
        dashT = 0
        rapidT = 0
        tripleT = 0
        shieldT = 0
        invuln = 0
        dmgFlash = 0
        pickFlash = 0
        shake = 0
        recoil = 0
        muzzle = 0
        hitMarker = 0
        lockedTarget = -1
        robots = []
        pops = []
        wave = 0
        waveBanner = 0
        clearTimer = 0
        overTimer = 0
        victory = false
        kills = 0
        scoreValue = 0
        combo = 0
        comboT = 0
        bestCombo = 0
        shots = 0
        hits = 0
        hintT = 0
        newUnlock = false
    }

    private func loadMap(_ m: Int) {
        let mi = max(0, min(2, m))
        mapIdx = mi
        px = RobotRaid64.starts[mi][0]
        py = RobotRaid64.starts[mi][1]
        vx = 0
        vy = 0
        ang = 0
        balls = []
        bolts = []
        parts = []
        pickups = []
        fogR = RobotRaid64.fogs[mi][0]
        fogG = RobotRaid64.fogs[mi][1]
        fogB = RobotRaid64.fogs[mi][2]
        if mi > RobotRaid64.unlocked { RobotRaid64.unlocked = mi }
    }

    private func beginGame() {
        resetGame()
        hintT = 720
        startWave(titleMap * 5 + 1)
        phase = .playing
    }

    private func randomSpawn() -> Pt {
        let list = RobotRaid64.openCells[mapIdx]
        var best = list[0]
        var bestD: Float = -1
        for _ in 0..<14 {
            let c = list[rng.int(list.count)]
            let dx: Float = c.x - px
            let dy: Float = c.y - py
            let d: Float = dx * dx + dy * dy
            if d > bestD {
                bestD = d
                best = c
            }
            if d > 49 { break }
        }
        return best
    }

    private func makeRobot(_ kind: Int, _ x: Float, _ y: Float, _ idx: Int) -> Robot {
        var r = Robot()
        r.kind = kind
        r.x = x
        r.y = y
        r.variant = rng.int(3)
        let bonus: Float = Float(wave / 8)
        switch kind {
        case 0: r.hp = 3 + bonus
        case 1: r.hp = 6 + bonus
        case 2:
            r.hp = 2 + bonus
            r.variant = rng.int(2)
        default:
            r.hp = Float(28 + 8 * max(0, wave / 5 - 1))
        }
        r.maxHp = r.hp
        r.appear = 34 + idx * 14
        r.cd = 100 + rng.int(60)
        r.strafe = rng.chance(50) ? 1 : -1
        r.phase = Float(rng.int(60))
        return r
    }

    private func startWave(_ n: Int) {
        wave = n
        robots = []
        balls = []
        var kinds: [Int] = []
        if n % 5 == 0 {
            kinds.append(3)
            let escorts = min(2, n / 5)
            for _ in 0..<escorts { kinds.append(0) }
            bannerText = "BOSS MECH!"
        } else {
            let walkers = min(5, 1 + (n + 1) / 2)
            let drones = n >= 2 ? min(3, (n + 1) / 3) : 0
            let tanks = n >= 4 ? min(2, (n - 1) / 3) : 0
            for _ in 0..<walkers { kinds.append(0) }
            for _ in 0..<tanks { kinds.append(1) }
            for _ in 0..<drones { kinds.append(2) }
            bannerText = ""
        }
        for (i, k) in kinds.enumerated() {
            let sp = randomSpawn()
            robots.append(makeRobot(k, sp.x, sp.y, i))
        }
        waveBanner = 130
        invuln = max(invuln, 100)
        play(.countdown)
    }

    // MARK: - World queries

    private func solid(_ x: Float, _ y: Float) -> Bool {
        if !(x >= 0 && y >= 0 && x < 20 && y < 20) { return true }
        return RobotRaid64.mapWalls[mapIdx][Int(y) * 20 + Int(x)] != 0
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
        let n = min(80, Int(d / 0.3) + 1)
        for k in 1..<max(2, n) {
            let t: Float = Float(k) / Float(n)
            if solid(x0 + dx * t, y0 + dy * t) { return false }
        }
        return true
    }

    // MARK: - Effects

    private func addPop(_ x: Float, _ y: Float, _ s: String, _ c: UInt32, _ big: Bool) {
        pops.append(Pop(x: x, y: y, text: s, t: 0, color: c, big: big))
        while pops.count > 14 { pops.removeFirst() }
    }

    private func burst(_ x: Float, _ y: Float, _ z: Float, _ count: Int, _ power: Float) {
        for _ in 0..<count {
            let a: Float = Float(rng.int(628)) / 100.0
            let sp: Float = (0.015 + Float(rng.int(50)) / 1000.0) * power
            let vz: Float = 0.02 + Float(rng.int(50)) / 1000.0
            let spr = rng.chance(50) ? RobotRaid64.sprSpark : RobotRaid64.sprCog
            let sz: Float = 0.12 + Float(rng.int(10)) / 100.0
            parts.append(Part(x: x, y: y, z: z, vx: cos(a) * sp, vy: sin(a) * sp, vz: vz,
                              life: 24 + rng.int(20), spr: spr, size: sz))
        }
        while parts.count > 90 { parts.removeFirst() }
    }

    // MARK: - Combat

    private func hurtPlayer() {
        if invuln > 0 || dashT > 0 || phase != .playing { return }
        if shieldT > 0 {
            shieldT = max(0, shieldT - 100)
            invuln = 24
            addPop(px + cos(ang) * 1.5, py + sin(ang) * 1.5, "BLOCKED", RobotRaid64.cCyan, false)
            play(.thud)
            return
        }
        hearts -= 1
        dmgFlash = 22
        invuln = 80
        shake = 12
        play(.hurt)
        if hearts <= 0 {
            hearts = 0
            finishGame(false)
        }
    }

    private func damageRobot(_ i: Int, _ dmg: Float) {
        if i < 0 || i >= robots.count { return }
        var r = robots[i]
        if !r.alive || r.appear > 0 { return }
        var d = dmg
        hits += 1
        hitMarker = 8
        if r.kind == 1 && r.shieldUp {
            d = dmg * 0.35
            if (frame & 3) == 0 { addPop(r.x, r.y, "CLANG", RobotRaid64.cCyan, false) }
            play(.thud)
        } else {
            play(.hit)
        }
        r.hp -= d
        r.flash = 5
        if r.kind == 3 && !r.summoned && r.hp < r.maxHp * 0.5 {
            r.summoned = true
            robots[i] = r
            for k in 0..<2 {
                let ang2: Float = Float(k) * 3.14159
                let sx: Float = r.x + cos(ang2) * 2.0
                let sy: Float = r.y + sin(ang2) * 2.0
                if !blocked(sx, sy, 0.3) {
                    robots.append(makeRobot(0, sx, sy, k))
                }
            }
            addPop(r.x, r.y, "REINFORCEMENTS", RobotRaid64.cOrange, true)
            r = robots[i]
        }
        if r.hp <= 0 {
            r.alive = false
            robots[i] = r
            robotDestroyed(r)
            return
        }
        robots[i] = r
    }

    private func robotDestroyed(_ r: Robot) {
        kills += 1
        if comboT > 0 { combo = min(8, combo + 1) } else { combo = 1 }
        comboT = 170
        bestCombo = max(bestCombo, combo)
        var base = 100
        switch r.kind {
        case 1: base = 250
        case 2: base = 150
        case 3: base = 1500
        default: base = 100
        }
        let pts = base * combo
        scoreValue += pts
        addPop(r.x, r.y, "+" + String(pts), RobotRaid64.cYellow, true)
        if combo >= 2 {
            addPop(r.x, r.y, "COMBO X" + String(combo), RobotRaid64.cPink, false)
            play(.coin)
        }
        let n = r.kind == 3 ? 40 : 14
        burst(r.x, r.y, 0.3, n, r.kind == 3 ? 2.0 : 1.2)
        parts.append(Part(x: r.x, y: r.y, z: 0.3, vx: 0, vy: 0, vz: 0.004, life: 18,
                          spr: RobotRaid64.sprPuff, size: r.kind == 3 ? 2.0 : 0.9))
        shake = max(shake, r.kind == 3 ? 20 : 5)
        if r.kind == 0 || r.kind == 2 {
            play(.stomp)
        } else {
            play(.explosion)
        }
        if r.kind == 3 {
            pickups.append(Pickup(x: r.x, y: r.y, kind: 0, life: 900))
            pickups.append(Pickup(x: r.x + 0.8, y: r.y, kind: 4, life: 900))
            pickups.append(Pickup(x: r.x - 0.8, y: r.y, kind: 1, life: 900))
        } else if rng.chance(34) {
            let roll = rng.int(100)
            var kind = 4
            if roll < 24 {
                kind = hearts < RobotRaid64.maxHearts ? 0 : 1
            } else if roll < 48 {
                kind = 1
            } else if roll < 66 {
                kind = 2
            } else if roll < 82 {
                kind = 3
            }
            pickups.append(Pickup(x: r.x, y: r.y, kind: kind, life: 700))
        }
    }

    private func enemyFire(_ r: Robot) {
        let a: Float = atan2(py - r.y, px - r.x)
        let spd: Float = min(0.085, 0.052 + 0.0022 * Float(wave))
        var angles: [Float] = [a]
        var big = false
        if r.kind == 1 {
            angles = [a - 0.12, a + 0.12]
            big = true
        } else if r.kind == 3 {
            big = true
            angles = [a - 0.26, a, a + 0.26]
            if r.hp < r.maxHp * 0.5 { angles = [a - 0.5, a - 0.25, a, a + 0.25, a + 0.5] }
        }
        for an in angles {
            balls.append(Ball(x: r.x + cos(an) * 0.5, y: r.y + sin(an) * 0.5,
                              dx: cos(an) * spd, dy: sin(an) * spd, life: 240, big: big))
        }
        play(.laser)
    }

    private func finishGame(_ won: Bool) {
        victory = won
        phase = .over
        overTimer = 0
        if won {
            scoreValue += hearts * 300 + 1000
            play(.win)
        } else {
            play(.lose)
        }
        if wave > 5 && RobotRaid64.unlocked < 1 { RobotRaid64.unlocked = 1 }
        if wave > 10 { RobotRaid64.unlocked = 2 }
    }

    // MARK: - Update

    private func findTarget() -> Int {
        var best = -1
        var bestScore: Float = 1000
        for i in 0..<robots.count {
            let r = robots[i]
            if !r.alive || r.appear > 0 { continue }
            let dx: Float = r.x - px
            let dy: Float = r.y - py
            let d: Float = sqrt(dx * dx + dy * dy)
            if d < 0.6 || d > 18 { continue }
            let da: Float = abs(RobotRaid64.wrapAngle(atan2(dy, dx) - ang))
            if da > 0.45 { continue }
            var sc: Float = da * 3.0 + d * 0.05
            if r.kind == 3 { sc -= 0.2 }
            if sc < bestScore && hasLOS(px, py, r.x, r.y) {
                bestScore = sc
                best = i
            }
        }
        return best
    }

    private func startDash(_ input: InputState) {
        let rx: Float = -sin(ang)
        let ry: Float = cos(ang)
        var side: Float = 1
        var dvx: Float = 0
        var dvy: Float = 0
        if input.dx != 0 {
            side = Float(input.dx)
            dvx = rx * side
            dvy = ry * side
        } else if input.dy > 0 {
            dvx = -cos(ang)
            dvy = -sin(ang)
        } else if input.dy < 0 {
            dvx = cos(ang)
            dvy = sin(ang)
        } else {
            var bestD: Float = 36
            for bl in balls {
                let ddx: Float = bl.x - px
                let ddy: Float = bl.y - py
                let d2: Float = ddx * ddx + ddy * ddy
                if d2 < bestD {
                    bestD = d2
                    let dot: Float = ddx * rx + ddy * ry
                    side = dot > 0 ? -1 : 1
                }
            }
            dvx = rx * side
            dvy = ry * side
        }
        dashVX = dvx * 0.17
        dashVY = dvy * 0.17
        dashT = 10
        dashCD = 55
        invuln = max(invuln, 16)
        play(.bounce)
        burst(px, py, 0.1, 6, 0.8)
    }

    private func shoot() {
        var dir: Float = ang
        if lockedTarget >= 0 && lockedTarget < robots.count {
            let t = robots[lockedTarget]
            dir = atan2(t.y - py, t.x - px)
        }
        let spd: Float = 0.42
        bolts.append(Bolt(x: px + cos(dir) * 0.3, y: py + sin(dir) * 0.3, dx: cos(dir) * spd, dy: sin(dir) * spd,
                          life: 60, target: lockedTarget))
        if tripleT > 0 {
            let a1: Float = dir + 0.17
            let a2: Float = dir - 0.17
            bolts.append(Bolt(x: px + cos(a1) * 0.3, y: py + sin(a1) * 0.3, dx: cos(a1) * spd, dy: sin(a1) * spd,
                              life: 60, target: -1))
            bolts.append(Bolt(x: px + cos(a2) * 0.3, y: py + sin(a2) * 0.3, dx: cos(a2) * spd, dy: sin(a2) * spd,
                              life: 60, target: -1))
        }
        fireCD = rapidT > 0 ? 5 : 9
        ammo -= rapidT > 0 ? 1.5 : 3.0
        recoil = 5
        muzzle = 3
        shots += 1
        play(.shoot)
    }

    private func updatePlayer(_ input: InputState) {
        if input.dx != 0 { turnHold = min(30, turnHold + 1) } else { turnHold = 0 }
        let ts: Float = 0.030 + 0.022 * Float(min(turnHold, 20)) / 20.0
        ang = RobotRaid64.wrapAngle(ang + Float(input.dx) * ts)
        let fwd: Float = -Float(input.dy)
        let fx: Float = cos(ang)
        let fy: Float = sin(ang)
        let acc: Float = fwd > 0 ? 0.0125 : 0.009
        vx += fx * fwd * acc
        vy += fy * fwd * acc
        vx *= 0.86
        vy *= 0.86
        if dashCD > 0 { dashCD -= 1 }
        if input.bPressed && dashCD <= 0 && phase != .over { startDash(input) }
        if dashT > 0 {
            dashT -= 1
            let q = tryMove(px, py, dashVX, dashVY, 0.25)
            px = q.x
            py = q.y
        }
        let np = tryMove(px, py, vx, vy, 0.25)
        if abs(np.x - px) < abs(vx) * 0.5 { vx *= 0.3 }
        if abs(np.y - py) < abs(vy) * 0.5 { vy *= 0.3 }
        px = np.x
        py = np.y
        for i in 0..<robots.count {
            let r = robots[i]
            if !r.alive || r.appear > 0 { continue }
            let dx: Float = px - r.x
            let dy: Float = py - r.y
            let d: Float = sqrt(dx * dx + dy * dy)
            let minD: Float = r.kind == 3 ? 1.0 : 0.6
            if d < minD && d > 0.001 {
                let push: Float = (minD - d) * 0.5
                let q = tryMove(px, py, dx / d * push, dy / d * push, 0.25)
                px = q.x
                py = q.y
            }
        }
        bobT += Float(abs(vx) + abs(vy)) * 6.0
        // weapon and auto-aim
        lockedTarget = findTarget()
        if recoil > 0 { recoil -= 1 }
        if muzzle > 0 { muzzle -= 1 }
        if fireCD > 0 { fireCD -= 1 }
        let firing = input.a && phase == .playing
        if firing { ammo += 0.15 } else { ammo += 0.55 }
        if ammo > 100 { ammo = 100 }
        if ammoLock && ammo >= 25 { ammoLock = false }
        if firing {
            if lockedTarget >= 0 && lockedTarget < robots.count {
                let t = robots[lockedTarget]
                let ta: Float = atan2(t.y - py, t.x - px)
                let diff: Float = RobotRaid64.wrapAngle(ta - ang)
                let maxS: Float = input.dx != 0 ? 0.012 : 0.03
                ang = RobotRaid64.wrapAngle(ang + clamp(diff, -maxS, maxS))
            }
            if fireCD <= 0 {
                let cost: Float = rapidT > 0 ? 1.5 : 3.0
                if ammoLock || ammo < cost {
                    ammoLock = true
                    if input.aPressed { play(.blip) }
                } else {
                    shoot()
                }
            }
        }
    }

    private func updateBolts() {
        var keep: [Bolt] = []
        for var bl in bolts {
            if bl.target >= 0 && bl.target < robots.count && robots[bl.target].alive {
                let t = robots[bl.target]
                let ta: Float = atan2(t.y - bl.y, t.x - bl.x)
                var a: Float = atan2(bl.dy, bl.dx)
                let diff: Float = RobotRaid64.wrapAngle(ta - a)
                a += clamp(diff, -0.14, 0.14)
                let spd: Float = 0.42
                bl.dx = cos(a) * spd
                bl.dy = sin(a) * spd
            }
            bl.x += bl.dx
            bl.y += bl.dy
            bl.life -= 1
            if solid(bl.x, bl.y) {
                burst(bl.x - bl.dx, bl.y - bl.dy, 0.3, 3, 0.5)
                continue
            }
            var done = false
            for i in 0..<robots.count {
                let r = robots[i]
                if !r.alive || r.appear > 0 { continue }
                let dx: Float = r.x - bl.x
                let dy: Float = r.y - bl.y
                var rad: Float = 0.5
                if r.kind == 1 { rad = 0.6 }
                if r.kind == 3 { rad = 1.0 }
                if dx * dx + dy * dy < rad * rad {
                    burst(bl.x, bl.y, 0.4, 3, 0.6)
                    damageRobot(i, 1.0)
                    done = true
                    break
                }
            }
            if done { continue }
            if bl.life <= 0 { continue }
            keep.append(bl)
        }
        bolts = keep
    }

    private func updateBalls() {
        var keep: [Ball] = []
        for var bl in balls {
            bl.x += bl.dx
            bl.y += bl.dy
            bl.life -= 1
            if solid(bl.x, bl.y) {
                burst(bl.x - bl.dx, bl.y - bl.dy, 0.3, 4, 0.6)
                continue
            }
            let dx: Float = px - bl.x
            let dy: Float = py - bl.y
            let rad2: Float = bl.big ? 0.26 : 0.2
            if dx * dx + dy * dy < rad2 {
                if phase == .playing { hurtPlayer() }
                burst(bl.x, bl.y, 0.3, 6, 0.8)
                continue
            }
            if bl.life <= 0 { continue }
            keep.append(bl)
        }
        balls = keep
    }

    private func updateRobot(_ i: Int) {
        var r = robots[i]
        if !r.alive { return }
        if r.flash > 0 { r.flash -= 1 }
        if r.appear > 0 {
            r.appear -= 1
            if r.appear == 30 { burst(r.x, r.y, 0.2, 8, 0.7) }
            robots[i] = r
            return
        }
        if r.cd > 0 { r.cd -= 1 }
        r.phase += 0.1
        r.shieldUp = (r.kind == 1 && r.state != 1)
        let dxp: Float = px - r.x
        let dyp: Float = py - r.y
        let dist: Float = sqrt(dxp * dxp + dyp * dyp)
        let toP: Float = atan2(dyp, dxp)
        let seen: Bool = dist < 15 && hasLOS(r.x, r.y, px, py)
        var desired: Float = 5.5
        var spd: Float = 0.022
        var windup = 36
        var cdBase = 130
        var rad: Float = 0.3
        switch r.kind {
        case 0:
            desired = 5.0
            spd = 0.022 + 0.0008 * Float(wave)
            windup = max(24, 38 - wave)
            cdBase = max(70, 140 - 4 * wave)
        case 1:
            desired = 7.0
            spd = 0.014
            windup = 46
            cdBase = max(100, 170 - 4 * wave)
        case 2:
            desired = 4.2
            spd = 0.03
            windup = 26
            cdBase = max(80, 150 - 4 * wave)
        default:
            desired = 7.5
            spd = 0.016
            windup = 42
            cdBase = 95
            rad = 0.55
        }
        if r.state == 0 {
            var moveAng: Float = toP
            var s2 = spd
            if !seen || dist > desired + 0.8 {
                if r.kind == 2 { moveAng = toP + r.strafe * 0.6 }
            } else if dist < desired - 1.8 {
                moveAng = toP + 3.14159
            } else {
                moveAng = toP + r.strafe * 1.5708
                s2 = spd * 0.7
            }
            if r.stuck > 6 { moveAng += r.strafe * 1.2 }
            let q = tryMove(r.x, r.y, cos(moveAng) * s2, sin(moveAng) * s2, rad)
            let moved: Float = abs(q.x - r.x) + abs(q.y - r.y)
            if moved < s2 * 0.3 {
                r.stuck += 1
                if r.stuck > 24 {
                    r.stuck = 0
                    r.strafe = -r.strafe
                }
            } else {
                r.stuck = max(0, r.stuck - 1)
            }
            r.x = q.x
            r.y = q.y
            if seen && r.cd <= 0 && dist < 13 && dist > 1.2 {
                r.state = 1
                r.timer = windup
                if dist < 11 { play(.blip) }
                addPop(r.x, r.y, "!", RobotRaid64.cOrange, true)
            }
        } else if r.state == 1 {
            r.timer -= 1
            if r.timer <= 0 {
                enemyFire(r)
                r.state = 2
                r.timer = 26
                r.cd = cdBase + rng.int(45)
            }
        } else {
            r.timer -= 1
            let ma: Float = toP + r.strafe * 1.5708
            let q = tryMove(r.x, r.y, cos(ma) * spd * 0.5, sin(ma) * spd * 0.5, rad)
            r.x = q.x
            r.y = q.y
            if r.timer <= 0 {
                r.state = 0
                if rng.chance(40) { r.strafe = -r.strafe }
            }
        }
        // keep robots apart
        for j in 0..<robots.count {
            if j == i || !robots[j].alive { continue }
            let dx: Float = r.x - robots[j].x
            let dy: Float = r.y - robots[j].y
            let d: Float = sqrt(dx * dx + dy * dy)
            if d < 0.8 && d > 0.001 {
                let q = tryMove(r.x, r.y, dx / d * 0.02, dy / d * 0.02, rad)
                r.x = q.x
                r.y = q.y
            }
        }
        if dist < 0.8 && dist > 0.001 {
            let q = tryMove(r.x, r.y, -dxp / dist * 0.03, -dyp / dist * 0.03, rad)
            r.x = q.x
            r.y = q.y
        }
        robots[i] = r
    }

    private func updatePickups() {
        var keep: [Pickup] = []
        for var p in pickups {
            p.life -= 1
            let dx: Float = px - p.x
            let dy: Float = py - p.y
            if dx * dx + dy * dy < 0.8 && phase != .over {
                switch p.kind {
                case 0:
                    if hearts < RobotRaid64.maxHearts {
                        hearts += 1
                        addPop(p.x, p.y, "+HEART", RobotRaid64.cPink, true)
                    } else {
                        scoreValue += 100
                        addPop(p.x, p.y, "+100", RobotRaid64.cYellow, true)
                    }
                case 1:
                    ammo = 100
                    ammoLock = false
                    addPop(p.x, p.y, "AMMO FULL", RobotRaid64.cYellow, true)
                case 2:
                    rapidT = 600
                    addPop(p.x, p.y, "RAPID FIRE", RobotRaid64.cGreen, true)
                case 3:
                    tripleT = 600
                    addPop(p.x, p.y, "TRIPLE SHOT", RobotRaid64.cCyan, true)
                default:
                    shieldT = 600
                    addPop(p.x, p.y, "SHIELD", RobotRaid64.cCyan, true)
                }
                pickFlash = 10
                play(.powerup)
                burst(p.x, p.y, 0.3, 8, 0.8)
                continue
            }
            if p.life <= 0 { continue }
            keep.append(p)
        }
        pickups = keep
    }

    private func updateFx() {
        var keepP: [Part] = []
        for var p in parts {
            p.life -= 1
            if p.life <= 0 { continue }
            let nx: Float = p.x + p.vx
            let ny: Float = p.y + p.vy
            if !solid(nx, ny) {
                p.x = nx
                p.y = ny
            } else {
                p.vx = 0
                p.vy = 0
            }
            p.z += p.vz
            p.vz -= 0.003
            if p.z < 0 {
                p.z = 0
                p.vz = -p.vz * 0.4
                p.vx *= 0.7
                p.vy *= 0.7
            }
            keepP.append(p)
        }
        parts = keepP
        var keepO: [Pop] = []
        for var o in pops {
            o.t += 1
            if o.t < 56 { keepO.append(o) }
        }
        pops = keepO
        if dmgFlash > 0 { dmgFlash -= 1 }
        if pickFlash > 0 { pickFlash -= 1 }
        if hitMarker > 0 { hitMarker -= 1 }
        if shake > 0 { shake -= 1 }
        if comboT > 0 {
            comboT -= 1
            if comboT == 0 { combo = 0 }
        }
        if rapidT > 0 { rapidT -= 1 }
        if tripleT > 0 { tripleT -= 1 }
        if shieldT > 0 { shieldT -= 1 }
        if invuln > 0 { invuln -= 1 }
        if hintT > 0 { hintT -= 1 }
    }

    private func updateWorld(_ input: InputState) {
        updatePlayer(input)
        for i in 0..<robots.count { updateRobot(i) }
        updateBolts()
        updateBalls()
        updatePickups()
    }

    override func update(_ input: InputState) {
        frame += 1
        updateFx()
        if input.selectPressed { showMap = !showMap }
        switch phase {
        case .title:
            titleAng = RobotRaid64.wrapAngle(titleAng + 0.01)
            if input.rightPressed && titleMap < RobotRaid64.unlocked {
                titleMap += 1
                play(.select)
            }
            if input.leftPressed && titleMap > 0 {
                titleMap -= 1
                play(.select)
            }
            if input.aPressed || input.startPressed {
                play(.confirm)
                beginGame()
            }
        case .playing:
            if waveBanner > 0 { waveBanner -= 1 }
            updateWorld(input)
            if phase == .playing {
                var alive = 0
                for r in robots where r.alive { alive += 1 }
                if alive == 0 && !robots.isEmpty {
                    let bonus = 200 * wave
                    scoreValue += bonus
                    phase = .clear
                    clearTimer = 150
                    waveBanner = 0
                    play(.win)
                    if wave % 5 == 0 && wave < RobotRaid64.maxWave {
                        newUnlock = RobotRaid64.unlocked < wave / 5
                        RobotRaid64.unlocked = max(RobotRaid64.unlocked, wave / 5)
                    }
                }
            }
        case .clear:
            clearTimer -= 1
            if invuln < 20 { invuln = 20 }
            updateWorld(input)
            if clearTimer <= 0 {
                if wave >= RobotRaid64.maxWave {
                    finishGame(true)
                } else {
                    if wave % 2 == 0 && hearts < RobotRaid64.maxHearts { hearts += 1 }
                    if wave % 5 == 0 {
                        loadMap(wave / 5)
                        hintT = 0
                    }
                    ammo = 100
                    ammoLock = false
                    phase = .playing
                    startWave(wave + 1)
                }
            }
        case .over:
            overTimer += 1
            if overTimer > 45 && (input.aPressed || input.startPressed) {
                play(.confirm)
                beginGame()
            }
        }
    }

    // MARK: - Rendering

    private func renderBackdrop(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ camX: Float, _ camY: Float,
                                _ dirX: Float, _ dirY: Float) {
        let mi = mapIdx
        let top = RobotRaid64.ceilTop[mi]
        let fr = fogR
        let fg = fogG
        let fb = fogB
        for y in 0..<144 {
            let t: Float = Float(y) / 143.0
            let r = top[0] + Int(Float(fr - top[0]) * t)
            let g = top[1] + Int(Float(fg - top[1]) * t)
            let b = top[2] + Int(Float(fb - top[2]) * t)
            var c = RobotRaid64.rgb(r, g, b)
            if y % 24 == 12 { c = RobotRaid64.rgb(r - 18, g - 18, b - 10) }
            let base = y * w
            for x in 0..<w { p[base + x] = c }
        }
        let planeX: Float = -dirY * RobotRaid64.planeLen
        let planeY: Float = dirX * RobotRaid64.planeLen
        let rowDist = RobotRaid64.rowDist
        let rowLit = RobotRaid64.rowLit
        let ftex = RobotRaid64.floorTex
        let zone = RobotRaid64.mapZones[mi]
        let fogC = RobotRaid64.rgb(fr, fg, fb)
        let fw: Float = Float(w)
        let belt = (frame / 2) & 63
        for y in 144..<min(h, 288) {
            let base = y * w
            let rd: Float = rowDist[y]
            if rd > 30 {
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
                if fx >= 0 && fy >= 0 && fx < 20 && fy < 20 {
                    zi = Int(zone[Int(fy) * 20 + Int(fx)])
                }
                let tx = Int(fx * 64) & 63
                var ty = Int(fy * 64) & 63
                if zi == 1 { ty = (ty + belt) & 63 }
                let c = ftex[(mi * 2 + zi) * 4096 + ty * 64 + tx]
                p[base + x] = RobotRaid64.shade(c, lit, fr, fg, fb)
                fx += stepX
                fy += stepY
            }
        }
    }

    private func castWalls(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ camPX: Float, _ camPY: Float,
                           _ dirX: Float, _ dirY: Float) {
        let planeX: Float = -dirY * RobotRaid64.planeLen
        let planeY: Float = dirX * RobotRaid64.planeLen
        let map = RobotRaid64.mapWalls[mapIdx]
        let tex = RobotRaid64.wallTex
        let hh = h / 2
        let fh: Float = Float(h)
        let fr = fogR
        let fg = fogG
        let fb = fogB
        for x in 0..<w {
            let cam: Float = 2.0 * Float(x) / Float(w) - 1.0
            let rdx: Float = dirX + planeX * cam
            let rdy: Float = dirY + planeY * cam
            var mapX = max(0, min(19, Int(camPX)))
            var mapY = max(0, min(19, Int(camPY)))
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
            while hit == 0 && steps < 48 {
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
                if mapX < 0 || mapY < 0 || mapX >= 20 || mapY >= 20 {
                    hit = 1
                } else {
                    let v = Int(map[mapY * 20 + mapX])
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
            let texBase = max(0, min(5, hit - 1)) * 4096 + texX
            let step: Float = 64.0 / Float(lineH)
            var texPos: Float = Float(drawStart - hh + lineH / 2) * step
            var lit = 262 - Int(perp * 12)
            if lit > 256 { lit = 256 }
            if lit < 96 { lit = 96 }
            if side == 1 { lit = (lit * 4) / 5 }
            for y in drawStart..<drawEnd {
                let ty = Int(texPos) & 63
                texPos += step
                let c = tex[texBase + ty * 64]
                p[y * w + x] = RobotRaid64.shade(c, lit, fr, fg, fb)
            }
        }
    }

    private func project(_ ex: Float, _ ey: Float) -> (Float, Float) {
        let rx: Float = ex - cX
        let ry: Float = ey - cY
        let invDet: Float = 1.0 / (cPlaneX * cDirY - cDirX * cPlaneY)
        let tx: Float = invDet * (cDirY * rx - cDirX * ry)
        let ty: Float = invDet * (-cPlaneY * rx + cPlaneX * ry)
        if !(ty > 0.05) { return (0, -1) }
        let sx: Float = 160.0 * (1.0 + tx / ty)
        return (sx, ty)
    }

    private func addBill(_ ex: Float, _ ey: Float, _ spr: Int, _ ww: Float, _ wh: Float, _ lift: Float,
                         _ lit: Int, _ white: Int, _ orange: Bool) {
        let rx: Float = ex - cX
        let ry: Float = ey - cY
        let invDet: Float = 1.0 / (cPlaneX * cDirY - cDirX * cPlaneY)
        let tx: Float = invDet * (cDirY * rx - cDirX * ry)
        let ty: Float = invDet * (-cPlaneY * rx + cPlaneX * ry)
        if !(ty > 0.2) || ty > 40 { return }
        let sxf: Float = 160.0 * (1.0 + tx / ty)
        if !(sxf > -2000 && sxf < 2300) { return }
        let swf: Float = ww * RobotRaid64.pxX / ty
        let shf: Float = wh * RobotRaid64.pxY / ty
        if !(swf < 1400 && shf < 1400) { return }
        let sw = Int(swf)
        let sh = Int(shf)
        if sw < 1 || sh < 1 { return }
        let sx = Int(sxf)
        if sx + sw / 2 < 0 || sx - sw / 2 > 320 { return }
        let bottom = 144 + Int((144.0 - lift * 288.0) / ty)
        bills.append(Bill(depth: ty, sx: sx, bottom: bottom, sw: sw, sh: sh, spr: spr, lit: lit,
                          white: white, orange: orange))
    }

    private func robotBill(_ r: Robot) {
        if !r.alive { return }
        var scale: Float = 1.0
        if r.appear > 0 {
            if r.appear > 30 { return }
            scale = 1.0 - Float(r.appear) / 30.0
        }
        let dxr: Float = r.x - cX
        let dyr: Float = r.y - cY
        let d: Float = sqrt(dxr * dxr + dyr * dyr)
        let lit = max(130, 256 - Int(d * 8))
        let sq: Float = sin(r.phase * 2.3)
        let sqc: Float = cos(r.phase * 2.3)
        var spr = 0
        var ww: Float = 0.56
        var wh: Float = 0.7
        var lift: Float = 0
        switch r.kind {
        case 0:
            spr = r.variant * 2 + (Int(r.phase * 1.3) & 1)
            ww = 0.56
            wh = 0.7
        case 1:
            spr = r.shieldUp ? RobotRaid64.sprTank : RobotRaid64.sprTankOpen
            ww = 0.8
            wh = 0.67
        case 2:
            spr = RobotRaid64.sprDrone + r.variant * 2 + (Int(r.phase * 3.0) & 1)
            ww = 0.6
            wh = 0.45
            lift = 0.36 + 0.06 * sq
        default:
            spr = RobotRaid64.sprBoss + (Int(r.phase * 1.1) & 1)
            ww = 1.05
            wh = 1.18
        }
        ww = ww * scale * (1.0 + 0.05 * sq)
        wh = wh * scale * (1.0 + 0.05 * sqc)
        var white = 0
        var orange = false
        if r.flash > 0 {
            white = 200
        } else if r.state == 1 {
            orange = true
            white = ((r.timer / 3) & 1) == 0 ? 190 : 80
        }
        addBill(r.x, r.y, spr, ww, wh, lift, lit, white, orange)
    }

    private func buildBills() {
        bills.removeAll(keepingCapacity: true)
        if phase == .title {
            let h: Float = titleAng
            let k: [Int] = [0, 6, 8]
            let offs: [Float] = [-0.5, 0.52, 0.0]
            for i in 0..<3 {
                let a: Float = h + offs[i]
                let dist: Float = i == 2 ? 6.0 : 3.6
                let ex: Float = cX + cos(a) * dist
                let ey: Float = cY + sin(a) * dist
                var spr = k[i]
                if i == 0 { spr = (frame / 12) & 1 }
                if i == 2 { spr = 8 + ((frame / 3) & 1) }
                let lift: Float = i == 2 ? 0.4 : 0
                let ww: Float = i == 1 ? 0.8 : 0.56
                let wh: Float = i == 1 ? 0.67 : (i == 2 ? 0.45 : 0.7)
                addBill(ex, ey, spr, ww, wh, lift, 256, 0, false)
            }
        }
        for r in robots { robotBill(r) }
        let bob: Float = sin(Float(frame) * 0.09) * 0.04
        for pk in pickups {
            if pk.life < 120 && ((frame / 4) & 1) == 0 { continue }
            addBill(pk.x, pk.y, RobotRaid64.sprHeart + pk.kind, 0.34, 0.34, 0.18 + bob, 256, 0, false)
        }
        for bl in balls {
            let spr = bl.big ? RobotRaid64.sprBigBall : RobotRaid64.sprBall
            let s: Float = bl.big ? 0.4 : 0.3
            addBill(bl.x, bl.y, spr, s, s, 0.3, 256, 0, false)
        }
        for bl in bolts {
            addBill(bl.x, bl.y, RobotRaid64.sprBolt, 0.22, 0.22, 0.3, 256, 0, false)
        }
        for pt in parts {
            let s: Float = pt.size
            addBill(pt.x, pt.y, pt.spr, s, s, pt.z, 256, 0, false)
        }
        bills.sort { $0.depth > $1.depth }
    }

    private func blit(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ it: Bill) {
        let sprs = RobotRaid64.sprites
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
        let orange = it.orange
        let depth = it.depth
        let fr = fogR
        let fg = fogG
        let fb = fogB
        spr.pix.withUnsafeBufferPointer { sp in
            for x in xs..<xe {
                if x < 320 && depth > zbuf[x] { continue }
                let sxp = max(0, min(sprW - 1, ((x - x0) * stepX) >> 16))
                for y in ys..<ye {
                    let syp = max(0, min(sprH - 1, ((y - y0) * stepY) >> 16))
                    let c = sp[syp * sprW + sxp]
                    if c == 0 { continue }
                    var o = c
                    if lit < 256 { o = RobotRaid64.shade(o, lit, fr, fg, fb) }
                    if white > 0 {
                        if orange {
                            o = RobotRaid64.tintTo(o, white, 255, 140, 30)
                        } else {
                            o = RobotRaid64.tintTo(o, white, 255, 255, 255)
                        }
                    }
                    p[y * w + x] = o
                }
            }
        }
    }

    private func tint(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ tr: Int, _ tg: Int, _ tb: Int, _ amt: Int) {
        let n = w * h
        for i in 0..<n {
            p[i] = RobotRaid64.tintTo(p[i], amt, tr, tg, tb)
        }
    }

    override func drawTrueColor(_ b: TrueColorBuffer) {
        var camPX = px
        var camPY = py
        var heading = ang
        if phase == .title {
            let st = RobotRaid64.starts[max(0, min(2, titleMap))]
            camPX = st[0]
            camPY = st[1]
            heading = titleAng
            mapIdx = max(0, min(2, titleMap))
            fogR = RobotRaid64.fogs[mapIdx][0]
            fogG = RobotRaid64.fogs[mapIdx][1]
            fogB = RobotRaid64.fogs[mapIdx][2]
        } else if shake > 0 {
            heading += sin(Float(frame) * 1.9) * 0.004 * Float(shake)
        }
        let dirX: Float = cos(heading)
        let dirY: Float = sin(heading)
        cX = camPX
        cY = camPY
        cDirX = dirX
        cDirY = dirY
        cPlaneX = -dirY * RobotRaid64.planeLen
        cPlaneY = dirX * RobotRaid64.planeLen
        buildBills()
        let list = bills
        var flash = 0
        if dmgFlash > 0 { flash = min(150, dmgFlash * 8) }
        let pflash = pickFlash > 0 ? pickFlash * 9 : 0
        let shielded = shieldT > 0 && phase != .title
        let cpx = camPX
        let cpy = camPY
        b.withPixels { p, w, h in
            if w < 320 || h < 288 { return }
            self.renderBackdrop(p, w, h, cpx, cpy, dirX, dirY)
            self.castWalls(p, w, h, cpx, cpy, dirX, dirY)
            for it in list { self.blit(p, w, h, it) }
            if flash > 0 { self.tint(p, w, h, 255, 40, 50, flash) }
            if pflash > 0 { self.tint(p, w, h, 255, 255, 190, pflash) }
            if shielded { self.tint(p, w, h, 90, 170, 255, 36) }
        }
        if phase != .title {
            drawPops(b)
            drawWeapon(b)
            drawHUD(b)
        }
        drawOverlays(b)
    }

    // MARK: - HUD

    private func otext(_ b: TrueColorBuffer, _ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        let k = max(1, scale / 2)
        let o = RobotRaid64.cBlack
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
        b.fillRect(x - 2, y - 2, w + 4, h + 4, RobotRaid64.cBlack)
        b.fillRect(x, y, w, h, RobotRaid64.cBarBack)
        let fw = Int(clamp(frac, 0, 1) * Float(w))
        if fw > 0 {
            b.fillRect(x, y, fw, h, c)
            b.fillRect(x, y, fw, 2, RobotRaid64.cWhite)
        }
    }

    private func drawHeart(_ b: TrueColorBuffer, _ x: Int, _ y: Int, _ c: UInt32) {
        for cell in RobotRaid64.heartCells {
            b.fillRect(x + cell[0] * 2, y + cell[1] * 2, 2, 2, c)
        }
    }

    private func drawBigHeart(_ b: TrueColorBuffer, _ x: Int, _ y: Int, _ c: UInt32) {
        for cell in RobotRaid64.heartCells {
            b.fillRect(x + cell[0] * 3, y + cell[1] * 3, 3, 3, c)
        }
    }

    private func drawStar(_ b: TrueColorBuffer, _ x: Int, _ y: Int, _ scale: Int, _ c: UInt32) {
        for cell in RobotRaid64.starCells {
            b.fillRect(x + cell[0] * scale, y + cell[1] * scale, scale, scale, c)
        }
    }

    private func drawPops(_ b: TrueColorBuffer) {
        for o in pops {
            let pr = project(o.x, o.y)
            let depth = pr.1
            if depth < 0.3 { continue }
            let rise: Float = Float(o.t) * 0.012
            let sy: Float = 144.0 + (144.0 - (0.7 + rise) * 288.0) / depth
            let sc = o.big ? 2 : 1
            let tw = b.textWidth(o.text, scale: sc)
            let sx = Int(clamp(pr.0, -400, 700)) - tw / 2
            let yy = Int(clamp(sy, -100, 400))
            var c = o.color
            if o.t > 40 && (o.t & 1) == 0 { c = RobotRaid64.cWhite }
            otext(b, o.text, sx, yy, c, sc)
        }
    }

    private func drawWeapon(_ b: TrueColorBuffer) {
        let rec = recoil * 2
        let sway = Int(sin(bobT) * 3.0)
        let gx = 140 + sway
        let gy = 232 + rec + Int(abs(sin(bobT * 0.5)) * 3.0)
        let ink = RobotRaid64.cBlack
        let yel = TrueColorBuffer.rgb(255, 214, 60)
        let pnk = TrueColorBuffer.rgb(255, 110, 180)
        let cyn = RobotRaid64.cCyan
        b.fillRect(gx - 1, gy + 11, 42, 46, ink)
        b.fillRect(gx + 4, gy + 14, 32, 44, pnk)
        b.fillRect(gx + 8, gy + 14, 6, 44, TrueColorBuffer.rgb(255, 170, 214))
        b.fillRect(gx + 8, gy - 1, 24, 18, ink)
        b.fillRect(gx + 10, gy + 1, 20, 16, yel)
        b.fillRect(gx + 12, gy + 1, 4, 16, TrueColorBuffer.rgb(255, 244, 150))
        b.fillRect(gx + 14, gy - 10, 12, 12, ink)
        b.fillRect(gx + 16, gy - 8, 8, 8, rapidT > 0 ? RobotRaid64.cGreen : cyn)
        if muzzle > 0 {
            b.fillRect(gx + 10, gy - 28, 20, 18, RobotRaid64.cWhite)
            b.fillRect(gx + 14, gy - 36, 12, 12, cyn)
        }
        // crosshair
        var cc: UInt32 = RobotRaid64.cWhite
        if lockedTarget >= 0 { cc = RobotRaid64.cRed }
        b.fillRect(153, 143, 5, 2, cc)
        b.fillRect(163, 143, 5, 2, cc)
        b.fillRect(160, 136, 2, 5, cc)
        b.fillRect(160, 147, 2, 5, cc)
        if lockedTarget >= 0 {
            b.fillRect(150, 131, 8, 1, cc)
            b.fillRect(163, 131, 8, 1, cc)
            b.fillRect(150, 156, 8, 1, cc)
            b.fillRect(163, 156, 8, 1, cc)
        }
        if hitMarker > 0 {
            b.fillRect(151, 134, 4, 2, RobotRaid64.cYellow)
            b.fillRect(167, 134, 4, 2, RobotRaid64.cYellow)
            b.fillRect(151, 153, 4, 2, RobotRaid64.cYellow)
            b.fillRect(167, 153, 4, 2, RobotRaid64.cYellow)
        }
    }

    private func drawMinimap(_ b: TrueColorBuffer) {
        let mx = 252
        let my = 44
        let walls = RobotRaid64.mapWalls[mapIdx]
        b.fillRect(mx - 2, my - 2, 64, 64, RobotRaid64.cBlack)
        b.fillRect(mx, my, 60, 60, TrueColorBuffer.rgb(60, 50, 120))
        for y in 0..<20 {
            for x in 0..<20 {
                if walls[y * 20 + x] == 0 { continue }
                b.fillRect(mx + x * 3, my + y * 3, 3, 3, TrueColorBuffer.rgb(200, 190, 255))
            }
        }
        for r in robots {
            if !r.alive || r.appear > 0 { continue }
            let rx = max(0, min(57, Int(r.x * 3) - 1))
            let ry = max(0, min(57, Int(r.y * 3) - 1))
            b.fillRect(mx + rx, my + ry, 3, 3, RobotRaid64.cRed)
        }
        for pk in pickups {
            let rx = max(0, min(58, Int(pk.x * 3)))
            let ry = max(0, min(58, Int(pk.y * 3)))
            b.fillRect(mx + rx, my + ry, 2, 2, RobotRaid64.cGreen)
        }
        let ppx = max(1, min(58, Int(px * 3)))
        let ppy = max(1, min(58, Int(py * 3)))
        b.fillRect(mx + ppx - 1, my + ppy - 1, 3, 3, RobotRaid64.cWhite)
        for k in 2..<5 {
            let lx = ppx + Int(cos(ang) * Float(k) * 2.0)
            let ly = ppy + Int(sin(ang) * Float(k) * 2.0)
            if lx >= 0 && lx < 60 && ly >= 0 && ly < 60 {
                b.fillRect(mx + lx, my + ly, 1, 1, RobotRaid64.cYellow)
            }
        }
    }

    private func drawHUD(_ b: TrueColorBuffer) {
        // hearts
        for i in 0..<RobotRaid64.maxHearts {
            let full = i < hearts
            let c: UInt32 = full ? RobotRaid64.cRed : TrueColorBuffer.rgb(90, 70, 120)
            drawHeart(b, 5 + i * 17, 5, RobotRaid64.cBlack)
            drawHeart(b, 6 + i * 17, 6, c)
            if full && hearts == 1 && ((frame / 8) & 1) == 0 {
                drawHeart(b, 6 + i * 17, 6, RobotRaid64.cWhite)
            }
        }
        otext(b, zeroPad(scoreValue, 6), 6, 24, RobotRaid64.cWhite, 2)
        let wt = "WAVE " + String(max(1, wave))
        otext(b, wt, 314 - b.textWidth(wt, scale: 2), 6, RobotRaid64.cYellow, 2)
        let kt = "KO " + String(kills)
        otext(b, kt, 314 - b.textWidth(kt, scale: 2), 24, RobotRaid64.cWhite, 2)
        if combo >= 2 {
            let ct = "COMBO X" + String(combo)
            ctext(b, ct, 6, RobotRaid64.cPink, 2)
            bar(b, 120, 24, 80, 4, Float(comboT) / 170.0, RobotRaid64.cPink)
        }
        // boss bar
        for r in robots where r.alive && r.kind == 3 && r.appear == 0 {
            ctext(b, "BOSS MECH", 36, RobotRaid64.cOrange, 1)
            bar(b, 80, 46, 160, 7, r.hp / r.maxHp, RobotRaid64.cOrange)
        }
        if showMap { drawMinimap(b) }
        // hints
        if hintT > 0 && waveBanner < 40 && phase == .playing {
            let idx = ((720 - hintT) / 180) % 4
            var s = "HOLD A TO SHOOT - AUTO-AIM HELPS"
            if idx == 1 { s = "B DASHES - DODGE ORANGE BALLS" }
            if idx == 2 { s = "UP DOWN WALK  LEFT RIGHT TURN" }
            if idx == 3 { s = "GRAB HEARTS AND POWER-UPS" }
            ctext(b, s, 222, RobotRaid64.cWhite, 1)
        }
        // bottom panel
        b.fillRect(0, 252, 320, 36, RobotRaid64.cPanel)
        b.fillRect(0, 252, 320, 2, RobotRaid64.cYellow)
        let ammoLbl = ammoLock ? "WAIT" : "AMMO"
        let blink = ammoLock && ((frame / 6) & 1) == 0
        b.text(ammoLbl, 6, 259, blink ? RobotRaid64.cRed : RobotRaid64.cWhite, scale: 2)
        var ac = RobotRaid64.cCyan
        if ammoLock { ac = RobotRaid64.cRed } else if ammo < 30 { ac = RobotRaid64.cOrange }
        bar(b, 6, 274, 96, 7, ammo / 100.0, ac)
        let dashReady = dashCD <= 0
        b.text("DASH", 116, 259, dashReady ? RobotRaid64.cGreen : RobotRaid64.cWhite, scale: 2)
        var dashFrac: Float = 1.0
        var dashCol: UInt32 = RobotRaid64.cGreen
        if !dashReady {
            dashFrac = 1.0 - Float(dashCD) / 55.0
            dashCol = RobotRaid64.cYellow
        }
        bar(b, 116, 274, 58, 7, dashFrac, dashCol)
        // power-ups
        var ix = 190
        if rapidT > 0 {
            b.text("RAPID", ix, 259, RobotRaid64.cGreen, scale: 1)
            bar(b, ix, 274, 36, 5, Float(rapidT) / 600.0, RobotRaid64.cGreen)
            ix += 44
        }
        if tripleT > 0 {
            b.text("TRIPLE", ix, 259, RobotRaid64.cCyan, scale: 1)
            bar(b, ix, 274, 36, 5, Float(tripleT) / 600.0, RobotRaid64.cCyan)
            ix += 44
        }
        if shieldT > 0 {
            b.text("SHIELD", ix, 259, RobotRaid64.cWhite, scale: 1)
            bar(b, ix, 274, 36, 5, Float(shieldT) / 600.0, TrueColorBuffer.rgb(120, 160, 255))
        }
        if ix == 190 && rapidT <= 0 && tripleT <= 0 && shieldT <= 0 {
            b.text("SELECT = MAP", 190, 266, TrueColorBuffer.rgb(170, 150, 230), scale: 1)
        }
    }

    private func drawOverlays(_ b: TrueColorBuffer) {
        let yellow = RobotRaid64.cYellow
        let white = RobotRaid64.cWhite
        switch phase {
        case .title:
            ctext(b, "ROBOT", 18, RobotRaid64.cOrange, 7)
            ctext(b, "RAID 64", 62, yellow, 7)
            ctext(b, "TOY FACTORY SHOOTER", 112, white, 1)
            if (frame / 30) & 1 == 0 { ctext(b, "PRESS A TO START", 188, yellow, 3) }
            let nm = "MAP " + String(titleMap + 1) + ": " + RobotRaid64.mapNames[max(0, min(2, titleMap))]
            ctext(b, nm, 224, RobotRaid64.cCyan, 2)
            if RobotRaid64.unlocked > 0 {
                ctext(b, "LEFT RIGHT CHOOSE MAP", 242, white, 1)
            } else {
                ctext(b, "BEAT WAVE 5 TO UNLOCK MORE MAPS", 242, white, 1)
            }
            ctext(b, "A SHOOT  B DASH  SELECT MAP", 262, TrueColorBuffer.rgb(255, 255, 255), 1)
        case .playing:
            if waveBanner > 0 {
                let sc = waveBanner > 100 ? 6 : 5
                ctext(b, "WAVE " + String(wave), 76, yellow, sc)
                if !bannerText.isEmpty {
                    ctext(b, bannerText, 122, RobotRaid64.cRed, 3)
                } else {
                    ctext(b, "GET READY!", 122, white, 2)
                }
                if wave % 5 == 1 && wave > 1 {
                    ctext(b, "NEW MAP: " + RobotRaid64.mapNames[mapIdx], 150, RobotRaid64.cCyan, 2)
                }
            }
        case .clear:
            ctext(b, "WAVE CLEAR!", 70, RobotRaid64.cGreen, 5)
            ctext(b, "BONUS +" + String(200 * wave), 116, yellow, 2)
            if wave % 5 == 0 && wave < RobotRaid64.maxWave {
                ctext(b, "NEW MAP UNLOCKED!", 142, RobotRaid64.cCyan, 2)
            }
        case .over:
            b.fillRect(36, 30, 248, 226, RobotRaid64.cBlack)
            b.fillRect(38, 32, 244, 222, RobotRaid64.cPanel)
            b.fillRect(38, 32, 244, 4, victory ? RobotRaid64.cGreen : RobotRaid64.cOrange)
            let head = victory ? "FACTORY SAVED!" : "GOOD TRY!"
            ctext(b, head, 44, victory ? RobotRaid64.cGreen : yellow, 3)
            var stars = 1
            if wave >= 5 { stars = 2 }
            if wave >= 10 || victory { stars = 3 }
            for i in 0..<3 {
                let c: UInt32 = i < stars ? yellow : TrueColorBuffer.rgb(100, 84, 150)
                drawStar(b, 100 + i * 46, 76, 4, c)
            }
            var rank = "ROOKIE"
            if stars == 2 { rank = "ROBOT BUSTER" }
            if stars >= 3 { rank = "FACTORY HERO" }
            ctext(b, rank, 118, RobotRaid64.cPink, 2)
            ctext(b, "WAVE " + String(max(1, wave)) + "   KOS " + String(kills), 142, white, 2)
            ctext(b, "BEST COMBO X" + String(bestCombo), 162, white, 2)
            var acc = 0
            if shots > 0 { acc = min(100, (hits * 100) / shots) }
            ctext(b, "ACCURACY " + String(acc) + "%", 182, white, 2)
            ctext(b, "SCORE " + zeroPad(scoreValue, 6), 206, yellow, 3)
            if RobotRaid64.unlocked > 0 && wave >= 5 {
                ctext(b, "MAPS UNLOCKED: " + String(RobotRaid64.unlocked + 1) + " OF 3", 232, RobotRaid64.cCyan, 1)
            }
            if overTimer > 45 && (frame / 30) & 1 == 0 { ctext(b, "PRESS A", 240, white, 1) }
        }
    }
}

extension Cartridge {
    static let robotRaid64 = Cartridge(
        id: "robotraid64", title: "ROBOT RAID 64", genre: "Shooter",
        blurb: "Blast cartoon robots in a bright toy factory. Auto-aim helps your thumbs, dodge the orange balls, grab power-ups and beat the boss mech.",
        controls: "UP/DOWN walk, LEFT/RIGHT turn, hold A to shoot (auto-aim), B dash, SELECT minimap.",
        era: .n64, labelTop: 0xFF8AD0, labelBottom: 0x3A5CFF, factory: { RobotRaid64() })
}
