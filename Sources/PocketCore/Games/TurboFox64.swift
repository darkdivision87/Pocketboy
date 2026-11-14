#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// TURBO FOX 64: a Sonic-Forces style high-speed 3D runner. An orange fox runs a winding, rolling projected
/// track automatically. Steer across three soft lanes, jump (double jump), homing-attack robots and springs,
/// ride rails and dash pads, boost with a ring-fed meter. Three stages (Sunny Hills, Neon City, Candy Canyon)
/// with S/A/B/C ranks and a final results screen.
final class TurboFox64: Game {
    // MARK: - Constants

    private static let segLen: Float = 200
    private static let roadW: Float = 800
    private static let camH: Float = 700
    private static let baseFov: Float = 128
    private static let playerDist: Float = 640
    private static let horizonY: Float = 100
    private static let camFollow: Float = 0.6
    private static let drawN = 110
    private static let extraSegs = 160
    private static let laneW: Float = 0.62
    private static let stageSegs: [Int] = [2300, 2600, 2900]
    private static let baseSpeed: [Float] = [0.95, 1.05, 1.15]
    private static let fogNear: Float = 7000
    private static let fogFar: Float = 21000

    private static let kRing = 0
    private static let kEnemy = 1
    private static let kFly = 2
    private static let kSpring = 3
    private static let kObst = 4
    private static let kCheck = 5
    private static let kFinish = 6
    private static let kScnA = 7
    private static let kScnB = 8
    private static let kScnC = 9

    private static let cWhite: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    private static let cBlack: UInt32 = TrueColorBuffer.rgb(10, 10, 24)
    private static let cYellow: UInt32 = TrueColorBuffer.rgb(255, 226, 64)
    private static let cRed: UInt32 = TrueColorBuffer.rgb(255, 80, 70)
    private static let cGreen: UInt32 = TrueColorBuffer.rgb(110, 255, 140)
    private static let cCyan: UInt32 = TrueColorBuffer.rgb(110, 232, 255)
    private static let cPanel: UInt32 = TrueColorBuffer.rgb(20, 32, 84)
    private static let cOrange: UInt32 = TrueColorBuffer.rgb(255, 150, 40)
    private static let cPink: UInt32 = TrueColorBuffer.rgb(255, 120, 200)
    private static let cGold: UInt32 = TrueColorBuffer.rgb(255, 210, 40)

    private static let cFox: UInt32 = TrueColorBuffer.rgb(255, 138, 30)
    private static let cFoxD: UInt32 = TrueColorBuffer.rgb(206, 88, 20)
    private static let cCream: UInt32 = TrueColorBuffer.rgb(255, 238, 212)
    private static let cScarf: UInt32 = TrueColorBuffer.rgb(40, 214, 255)
    private static let cScarfD: UInt32 = TrueColorBuffer.rgb(20, 140, 220)
    private static let cShoe: UInt32 = TrueColorBuffer.rgb(236, 44, 60)
    private static let cOutl: UInt32 = TrueColorBuffer.rgb(60, 26, 20)
    private static let cStrap: UInt32 = TrueColorBuffer.rgb(40, 60, 170)

    // MARK: - Nested types

    struct Theme {
        var name: String = ""
        var sky: [Int] = [0, 0, 0, 0, 0, 0]
        var haze: [Int] = [0, 0, 0]
        var groundA: UInt32 = 0
        var groundB: UInt32 = 0
        var roadA: UInt32 = 0
        var roadB: UInt32 = 0
        var edgeA: UInt32 = 0
        var edgeB: UInt32 = 0
        var lane: UInt32 = 0
        var shadow: UInt32 = 0
        var rail: UInt32 = 0
        var accent: UInt32 = 0
    }

    struct Spr {
        var off: Float
        var kind: Int
        var h: Float
        var taken: Bool
    }

    struct SpriteImg {
        var w: Int
        var h: Int
        var pix: [UInt32]
        var worldW: Float
    }

    struct Part {
        var x: Float
        var y: Float
        var vx: Float
        var vy: Float
        var grav: Float
        var life: Int
        var size: Int
        var c: UInt32
    }

    struct FText {
        var x: Float
        var y: Float
        var life: Int
        var text: String
        var c: UInt32
    }

    enum Phase { case title, ready, run, clear, results, over, final }

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

        mutating func ellipse(_ cx: Int, _ cy: Int, _ rx: Int, _ ry: Int, _ c: UInt32) {
            if rx < 1 || ry < 1 { return }
            for yy in (cy - ry)...(cy + ry) {
                for xx in (cx - rx)...(cx + rx) {
                    let dx = xx - cx
                    let dy = yy - cy
                    let lhs = dx * dx * ry * ry + dy * dy * rx * rx
                    if lhs <= rx * rx * ry * ry { set(xx, yy, c) }
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

    // MARK: - Static helpers and tables

    private static func col(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
        return TrueColorBuffer.rgb(r, g, b)
    }

    @inline(__always) private static func blend(_ c: UInt32, _ tr: Int, _ tg: Int, _ tb: Int, _ t: Int) -> UInt32 {
        if t <= 0 { return c }
        let r = Int(c & 255)
        let g = Int((c >> 8) & 255)
        let bl = Int((c >> 16) & 255)
        let r2 = r + (((tr - r) * t) >> 8)
        let g2 = g + (((tg - g) * t) >> 8)
        let b2 = bl + (((tb - bl) * t) >> 8)
        let rr = UInt32(max(0, min(255, r2)))
        let gg = UInt32(max(0, min(255, g2)))
        let bb = UInt32(max(0, min(255, b2)))
        return 0xFF00_0000 | rr | (gg << 8) | (bb << 16)
    }

    private static func fogAmount(_ z: Float) -> Int {
        if z <= fogNear { return 0 }
        var t: Float = (z - fogNear) / (fogFar - fogNear)
        if t > 1 { t = 1 }
        if t < 0 { t = 0 }
        return Int(t * 256)
    }

    private static func makeTheme(_ i: Int) -> Theme {
        var t = Theme()
        if i == 0 {
            t.name = "SUNNY HILLS"
            t.sky = [52, 140, 255, 190, 232, 255]
            t.haze = [196, 232, 255]
            t.groundA = col(60, 180, 56)
            t.groundB = col(92, 214, 76)
            t.roadA = col(246, 222, 160)
            t.roadB = col(232, 200, 132)
            t.edgeA = col(236, 60, 50)
            t.edgeB = col(255, 255, 255)
            t.lane = col(255, 255, 255)
            t.shadow = col(110, 130, 70)
            t.rail = col(120, 130, 150)
            t.accent = col(255, 220, 60)
        } else if i == 1 {
            t.name = "NEON CITY"
            t.sky = [10, 6, 46, 150, 40, 170]
            t.haze = [110, 34, 150]
            t.groundA = col(22, 12, 54)
            t.groundB = col(34, 18, 76)
            t.roadA = col(70, 70, 126)
            t.roadB = col(88, 88, 150)
            t.edgeA = col(0, 255, 230)
            t.edgeB = col(255, 40, 190)
            t.lane = col(255, 240, 120)
            t.shadow = col(20, 20, 50)
            t.rail = col(120, 255, 240)
            t.accent = col(0, 255, 230)
        } else {
            t.name = "CANDY CANYON"
            t.sky = [255, 168, 222, 255, 238, 250]
            t.haze = [255, 226, 246]
            t.groundA = col(150, 236, 204)
            t.groundB = col(196, 252, 228)
            t.roadA = col(128, 74, 60)
            t.roadB = col(150, 92, 76)
            t.edgeA = col(255, 90, 150)
            t.edgeB = col(255, 255, 255)
            t.lane = col(255, 232, 200)
            t.shadow = col(70, 40, 40)
            t.rail = col(255, 255, 255)
            t.accent = col(255, 100, 170)
        }
        return t
    }

    private static let themes: [Theme] = [TurboFox64.makeTheme(0), TurboFox64.makeTheme(1), TurboFox64.makeTheme(2)]

    private static let skyRows: [[UInt32]] = {
        var out: [[UInt32]] = []
        for t in 0..<3 {
            let th = TurboFox64.themes[t]
            var a = [UInt32](repeating: 0, count: 120)
            for y in 0..<120 {
                var f: Float = Float(y) / 100.0
                if f > 1 { f = 1 }
                let r = Int(Float(th.sky[0]) + Float(th.sky[3] - th.sky[0]) * f)
                let g = Int(Float(th.sky[1]) + Float(th.sky[4] - th.sky[1]) * f)
                let bl = Int(Float(th.sky[2]) + Float(th.sky[5] - th.sky[2]) * f)
                a[y] = TrueColorBuffer.rgb(r, g, bl)
            }
            out.append(a)
        }
        return out
    }()

    private static let farHill: [Int] = {
        var a = [Int](repeating: 6, count: 512)
        for i in 0..<512 {
            let ang: Float = Float(i) / 512.0 * 2.0 * Float.pi
            let f1: Float = 16 * sin(ang * 2 + 0.7)
            let f2: Float = 9 * sin(ang * 5 + 2.0)
            let f3: Float = 4 * sin(ang * 13 + 1.0)
            let f: Float = 30 + f1 + f2 + f3
            a[i] = max(6, Int(f))
        }
        return a
    }()

    private static let nearHill: [Int] = {
        var a = [Int](repeating: 4, count: 512)
        for i in 0..<512 {
            let ang: Float = Float(i) / 512.0 * 2.0 * Float.pi
            let f1: Float = 8 * sin(ang * 4 + 1.0)
            let f2: Float = 5 * sin(ang * 9 + 4.0)
            let f3: Float = 3 * sin(ang * 21)
            let f: Float = 15 + f1 + f2 + f3
            a[i] = max(4, Int(f))
        }
        return a
    }()

    private static let skyline: [Int] = {
        var a = [Int](repeating: 20, count: 512)
        var seed: UInt32 = 12345
        for blk in 0..<64 {
            seed = seed &* 1664525 &+ 1013904223
            let hgt: Int = 18 + Int((seed >> 16) % 50)
            for k in 0..<8 { a[blk * 8 + k] = hgt }
        }
        return a
    }()

    private static let starX: [Int] = {
        var a = [Int](repeating: 0, count: 40)
        var seed: UInt32 = 777
        for i in 0..<40 {
            seed = seed &* 1664525 &+ 1013904223
            a[i] = Int((seed >> 16) % 512)
        }
        return a
    }()

    private static let starY: [Int] = {
        var a = [Int](repeating: 0, count: 40)
        var seed: UInt32 = 991
        for i in 0..<40 {
            seed = seed &* 1664525 &+ 1013904223
            a[i] = 4 + Int((seed >> 16) % 70)
        }
        return a
    }()

    private static let rayCos: [Float] = {
        var a = [Float](repeating: 0, count: 16)
        for i in 0..<16 { a[i] = cos(Float(i) * Float.pi / 8.0 + 0.2) }
        return a
    }()

    private static let raySin: [Float] = {
        var a = [Float](repeating: 0, count: 16)
        for i in 0..<16 { a[i] = sin(Float(i) * Float.pi / 8.0 + 0.2) }
        return a
    }()

    // MARK: - Sprite generation

    static func makeRing(_ f: Int) -> SpriteImg {
        var p = Pix(16, 16)
        let rxs: [Float] = [7.0, 5.2, 2.2, 5.2]
        let rx: Float = rxs[f & 3]
        let gold = col(255, 214, 40)
        let goldL = col(255, 248, 170)
        let goldD = col(226, 140, 10)
        for y in 0..<16 {
            for x in 0..<16 {
                let dx: Float = (Float(x) - 7.5) / rx
                let dy: Float = (Float(y) - 7.5) / 7.2
                let o: Float = dx * dx + dy * dy
                if o > 1.0 { continue }
                var c = gold
                let rin: Float = max(0.2, rx - 2.6)
                let ix: Float = (Float(x) - 7.5) / rin
                let iy: Float = (Float(y) - 7.5) / 4.6
                if ix * ix + iy * iy < 1.0 && rx > 2.6 { continue }
                if o > 0.7 { c = goldD }
                if x < 6 && y < 6 && o > 0.35 { c = goldL }
                p.set(x, y, c)
            }
        }
        p.outline(col(150, 80, 10))
        return SpriteImg(w: 16, h: 16, pix: p.d, worldW: 300)
    }

    static func makeEnemy(_ t: Int) -> SpriteImg {
        var p = Pix(28, 28)
        var red = col(240, 70, 70)
        var redL = col(255, 160, 140)
        var redD = col(170, 36, 56)
        if t == 1 {
            red = col(176, 80, 240)
            redL = col(226, 170, 255)
            redD = col(100, 40, 170)
        } else if t == 2 {
            red = col(255, 96, 150)
            redL = col(255, 190, 215)
            redD = col(190, 50, 110)
        }
        let metal = col(160, 170, 200)
        let metalD = col(80, 90, 124)
        let yellow = col(255, 232, 70)
        let visor = col(28, 28, 60)
        p.rect(5, 23, 7, 4, metalD)
        p.rect(16, 23, 7, 4, metalD)
        p.rect(2, 13, 3, 7, metal)
        p.rect(23, 13, 3, 7, metal)
        p.disc(14, 15, 10, redD)
        p.disc(14, 14, 10, red)
        p.disc(10, 8, 4, redL)
        p.rect(5, 12, 18, 7, visor)
        p.rect(7, 13, 5, 5, yellow)
        p.rect(16, 13, 5, 5, yellow)
        p.rect(9, 14, 2, 3, visor)
        p.rect(18, 14, 2, 3, visor)
        p.rect(5, 10, 7, 2, visor)
        p.rect(16, 10, 7, 2, visor)
        p.rect(13, 0, 2, 5, metalD)
        p.disc(14, 1, 2, yellow)
        p.outline(col(40, 14, 40))
        return SpriteImg(w: 28, h: 28, pix: p.d, worldW: 440)
    }

    static func makeFly(_ t: Int) -> SpriteImg {
        var p = Pix(28, 24)
        var body = col(70, 150, 255)
        var bodyD = col(30, 80, 200)
        if t == 1 {
            body = col(60, 230, 220)
            bodyD = col(20, 130, 150)
        } else if t == 2 {
            body = col(255, 190, 70)
            bodyD = col(220, 120, 30)
        }
        let metal = col(210, 216, 236)
        p.rect(3, 3, 22, 2, metal)
        p.rect(13, 5, 2, 4, col(90, 100, 130))
        p.disc(14, 15, 9, bodyD)
        p.disc(14, 14, 9, body)
        p.disc(14, 13, 5, col(255, 255, 255))
        p.disc(14, 14, 2, col(20, 20, 50))
        p.rect(4, 17, 3, 3, col(90, 100, 130))
        p.rect(21, 17, 3, 3, col(90, 100, 130))
        p.rect(11, 19, 6, 1, col(20, 20, 50))
        p.outline(col(20, 20, 60))
        return SpriteImg(w: 28, h: 24, pix: p.d, worldW: 400)
    }

    static func makeSpring() -> SpriteImg {
        var p = Pix(20, 18)
        let plate = col(70, 76, 110)
        let yellow = col(255, 226, 50)
        let yellowD = col(220, 150, 20)
        p.rect(1, 14, 18, 4, plate)
        for k in 0..<3 {
            p.rect(4, 4 + k * 3, 12, 2, yellow)
            p.rect(4, 6 + k * 3, 12, 1, yellowD)
        }
        p.rect(0, 0, 20, 4, col(240, 50, 60))
        p.rect(2, 1, 8, 1, col(255, 150, 150))
        p.outline(col(30, 20, 40))
        return SpriteImg(w: 20, h: 18, pix: p.d, worldW: 380)
    }

    static func makeObstacle(_ t: Int) -> SpriteImg {
        var p = Pix(24, 22)
        if t == 0 {
            let wood = col(200, 128, 56)
            let woodD = col(128, 74, 30)
            let woodL = col(238, 176, 96)
            p.rect(0, 0, 24, 22, woodD)
            p.rect(2, 2, 20, 18, wood)
            for i in 0..<18 {
                let x = 2 + (i * 20) / 18
                p.set(x, 2 + i, woodD)
                p.set(x + 1, 2 + i, woodD)
                p.set(23 - x, 2 + i, woodD)
            }
            p.rect(2, 2, 20, 2, woodL)
            p.outline(col(60, 30, 10))
        } else if t == 1 {
            let dark = col(30, 20, 70)
            let pink = col(255, 40, 190)
            let cyan = col(0, 255, 230)
            p.rect(0, 0, 24, 22, dark)
            for y in 4..<18 {
                for x in 1..<23 {
                    if (((x + y) / 4) & 1) == 0 { p.set(x, y, pink) }
                }
            }
            p.rect(0, 0, 24, 3, cyan)
            p.rect(0, 19, 24, 3, cyan)
            p.outline(col(255, 255, 255))
        } else {
            let purple = col(176, 90, 236)
            let purpleD = col(110, 50, 170)
            p.rect(1, 3, 22, 19, purpleD)
            p.rect(2, 1, 20, 18, purple)
            p.rect(3, 2, 8, 3, col(226, 180, 255))
            p.set(15, 9, col(255, 255, 255))
            p.set(8, 13, col(255, 255, 255))
            p.set(18, 14, col(255, 255, 255))
            p.set(6, 8, col(255, 255, 255))
            p.outline(col(60, 20, 90))
        }
        return SpriteImg(w: 24, h: 22, pix: p.d, worldW: 440)
    }

    static func makeArch(_ t: Int, _ finish: Bool) -> SpriteImg {
        var p = Pix(96, 48)
        var postA = col(255, 210, 40)
        var postB = col(30, 30, 40)
        if t == 1 {
            postA = col(0, 255, 230)
            postB = col(255, 40, 190)
        } else if t == 2 {
            postA = col(255, 90, 150)
            postB = col(255, 255, 255)
        }
        if finish {
            postA = col(255, 255, 255)
            postB = col(20, 20, 26)
        }
        for y in 8..<48 {
            let c = ((y / 4) & 1) == 0 ? postA : postB
            p.rect(0, y, 6, 1, c)
            p.rect(90, y, 6, 1, c)
        }
        for y in 0..<16 {
            for x in 0..<96 {
                var c = postA
                if finish {
                    c = (((x / 6) + (y / 4)) & 1) == 0 ? col(250, 250, 250) : col(20, 20, 26)
                } else {
                    c = ((x / 8) & 1) == 0 ? postA : postB
                }
                p.set(x, y, c)
            }
        }
        if !finish {
            p.rect(36, 3, 24, 10, col(40, 220, 90))
            p.rect(38, 5, 20, 6, col(210, 255, 220))
        }
        p.outline(col(10, 12, 24))
        return SpriteImg(w: 96, h: 48, pix: p.d, worldW: 1900)
    }

    static func makeScn(_ t: Int, _ k: Int) -> SpriteImg {
        let id = t * 3 + k
        switch id {
        case 0: return makePalm()
        case 1: return makeFlowers()
        case 2: return makeWindmill()
        case 3: return makeTower()
        case 4: return makeSignPole()
        case 5: return makeBillboard()
        case 6: return makeLollipop()
        case 7: return makeCane()
        default: return makeCupcake()
        }
    }

    static func makePalm() -> SpriteImg {
        var p = Pix(28, 46)
        let trunk = col(168, 110, 52)
        let trunkD = col(120, 74, 32)
        let leaf = col(40, 170, 60)
        let leafL = col(96, 220, 90)
        for y in 14..<46 {
            let bend = (46 - y) / 12
            p.rect(12 + bend, y, 4, 1, (y / 4) & 1 == 0 ? trunk : trunkD)
        }
        p.rect(2, 12, 10, 3, leaf)
        p.rect(16, 12, 10, 3, leaf)
        p.rect(5, 8, 8, 3, leafL)
        p.rect(15, 8, 8, 3, leafL)
        p.rect(0, 15, 8, 3, leaf)
        p.rect(20, 15, 8, 3, leaf)
        p.rect(11, 4, 6, 8, leafL)
        p.disc(13, 15, 2, col(120, 70, 30))
        p.disc(17, 16, 2, col(120, 70, 30))
        p.outline(col(20, 70, 30))
        return SpriteImg(w: 28, h: 46, pix: p.d, worldW: 560)
    }

    static func makeFlowers() -> SpriteImg {
        var p = Pix(24, 16)
        let stem = col(40, 150, 50)
        p.rect(4, 8, 2, 8, stem)
        p.rect(11, 6, 2, 10, stem)
        p.rect(18, 9, 2, 7, stem)
        p.disc(5, 6, 3, col(255, 70, 100))
        p.disc(12, 4, 3, col(255, 230, 70))
        p.disc(19, 7, 3, col(255, 130, 220))
        p.set(5, 6, col(255, 240, 120))
        p.set(12, 4, col(255, 120, 40))
        p.set(19, 7, col(255, 240, 120))
        p.outline(col(30, 80, 30))
        return SpriteImg(w: 24, h: 16, pix: p.d, worldW: 360)
    }

    static func makeWindmill() -> SpriteImg {
        var p = Pix(40, 56)
        let wall = col(250, 244, 230)
        let wallD = col(214, 200, 180)
        let roof = col(220, 60, 50)
        for y in 20..<56 {
            let hw = 6 + (y - 20) / 4
            p.rect(20 - hw, y, hw * 2, 1, wall)
            p.rect(20 + hw / 2, y, hw / 2, 1, wallD)
        }
        for y in 14..<22 {
            let hw = 4 + (y - 14)
            p.rect(20 - hw, y, hw * 2, 1, roof)
        }
        p.rect(17, 44, 6, 12, col(130, 80, 40))
        p.rect(17, 28, 6, 5, col(120, 190, 255))
        p.rect(19, 2, 2, 24, col(240, 240, 250))
        p.rect(8, 13, 24, 2, col(240, 240, 250))
        p.rect(19, 2, 2, 10, col(230, 70, 60))
        p.rect(24, 13, 8, 2, col(230, 70, 60))
        p.disc(20, 14, 2, col(90, 60, 40))
        p.outline(col(60, 40, 40))
        return SpriteImg(w: 40, h: 56, pix: p.d, worldW: 800)
    }

    static func makeTower() -> SpriteImg {
        var p = Pix(30, 64)
        let body = col(40, 30, 96)
        let bodyL = col(70, 52, 140)
        p.rect(2, 6, 26, 58, body)
        p.rect(2, 6, 4, 58, bodyL)
        p.rect(14, 0, 2, 8, col(255, 255, 255))
        p.set(14, 0, col(255, 60, 60))
        for wy in 0..<9 {
            for wx in 0..<4 {
                let lit = ((wx * 5 + wy * 3) & 3) != 0
                if lit {
                    let cc = ((wx + wy) & 1) == 0 ? col(255, 236, 110) : col(120, 255, 240)
                    p.rect(7 + wx * 5, 10 + wy * 6, 3, 3, cc)
                }
            }
        }
        p.rect(2, 6, 26, 1, col(255, 60, 200))
        p.outline(col(255, 60, 200))
        return SpriteImg(w: 30, h: 64, pix: p.d, worldW: 620)
    }

    static func makeSignPole() -> SpriteImg {
        var p = Pix(20, 50)
        p.rect(9, 14, 2, 36, col(150, 150, 190))
        p.rect(1, 0, 18, 16, col(30, 16, 70))
        p.rect(2, 1, 16, 14, col(255, 50, 200))
        p.rect(4, 3, 12, 10, col(30, 16, 70))
        p.rect(6, 7, 8, 2, col(0, 255, 230))
        p.rect(11, 5, 2, 6, col(0, 255, 230))
        p.rect(13, 6, 2, 4, col(0, 255, 230))
        p.outline(col(255, 255, 255))
        return SpriteImg(w: 20, h: 50, pix: p.d, worldW: 380)
    }

    static func makeBillboard() -> SpriteImg {
        var p = Pix(40, 38)
        p.rect(8, 20, 3, 18, col(110, 110, 150))
        p.rect(29, 20, 3, 18, col(110, 110, 150))
        p.rect(0, 0, 40, 22, col(24, 12, 60))
        for x in 0..<36 {
            let cc = ((x / 6) & 1) == 0 ? col(255, 70, 180) : col(0, 230, 255)
            p.rect(2 + x, 3, 1, 16, cc)
        }
        p.rect(14, 6, 12, 10, col(255, 236, 110))
        p.rect(17, 8, 6, 6, col(24, 12, 60))
        p.outline(col(255, 255, 255))
        return SpriteImg(w: 40, h: 38, pix: p.d, worldW: 760)
    }

    static func makeLollipop() -> SpriteImg {
        var p = Pix(26, 50)
        p.rect(12, 20, 3, 30, col(255, 255, 255))
        p.rect(12, 24, 1, 26, col(230, 200, 220))
        for y in 0..<22 {
            for x in 0..<26 {
                let dx: Float = Float(x) - 12.5
                let dy: Float = Float(y) - 10.5
                let dist: Float = sqrt(dx * dx + dy * dy)
                if dist > 11 { continue }
                let ang: Float = atan2(dy, dx)
                let q: Int = Int((ang + Float.pi + dist * 0.5) * 1.6)
                var c = (q & 1) == 0 ? col(255, 90, 150) : col(255, 250, 250)
                if dist > 9.5 { c = col(255, 60, 120) }
                p.set(x, y, c)
            }
        }
        p.outline(col(150, 40, 90))
        return SpriteImg(w: 26, h: 50, pix: p.d, worldW: 480)
    }

    static func makeCane() -> SpriteImg {
        var p = Pix(20, 46)
        for y in 8..<46 {
            for x in 6..<10 {
                let c = (((y + x) / 4) & 1) == 0 ? col(255, 60, 70) : col(255, 255, 255)
                p.set(x, y, c)
            }
        }
        for y in 0..<14 {
            for x in 0..<20 {
                let dx: Float = Float(x) - 11.0
                let dy: Float = Float(y) - 8.0
                let dist: Float = sqrt(dx * dx + dy * dy)
                if dist > 5.0 && dist < 9.0 && y < 9 {
                    let c = (((x + y) / 4) & 1) == 0 ? col(255, 60, 70) : col(255, 255, 255)
                    p.set(x, y, c)
                }
            }
        }
        p.outline(col(140, 30, 50))
        return SpriteImg(w: 20, h: 46, pix: p.d, worldW: 380)
    }

    static func makeCupcake() -> SpriteImg {
        var p = Pix(40, 42)
        for y in 22..<42 {
            let hw = 12 + (y - 22) / 3
            for x in (20 - hw)..<(20 + hw) {
                let c = (((x + 100) / 4) & 1) == 0 ? col(255, 190, 210) : col(255, 250, 250)
                p.set(x, y, c)
            }
        }
        p.ellipse(20, 20, 17, 7, col(255, 150, 190))
        p.ellipse(20, 13, 13, 6, col(255, 190, 220))
        p.ellipse(20, 7, 8, 5, col(255, 220, 238))
        p.disc(20, 2, 3, col(240, 40, 60))
        p.set(19, 1, col(255, 200, 200))
        p.set(10, 18, col(80, 200, 255))
        p.set(28, 14, col(255, 240, 80))
        p.set(16, 11, col(120, 230, 120))
        p.set(24, 20, col(255, 255, 255))
        p.outline(col(150, 60, 100))
        return SpriteImg(w: 40, h: 42, pix: p.d, worldW: 760)
    }

    static func makeSet(_ t: Int) -> [SpriteImg] {
        var s: [SpriteImg] = []
        s.append(makeRing(0))
        s.append(makeEnemy(t))
        s.append(makeFly(t))
        s.append(makeSpring())
        s.append(makeObstacle(t))
        s.append(makeArch(t, false))
        s.append(makeArch(t, true))
        s.append(makeScn(t, 0))
        s.append(makeScn(t, 1))
        s.append(makeScn(t, 2))
        return s
    }

    private static let sets: [[SpriteImg]] = [TurboFox64.makeSet(0), TurboFox64.makeSet(1), TurboFox64.makeSet(2)]
    private static let ringFrames: [SpriteImg] = [TurboFox64.makeRing(0), TurboFox64.makeRing(1), TurboFox64.makeRing(2), TurboFox64.makeRing(3)]

    // MARK: - Course

    final class Course {
        var curve: [Float] = []
        var pointY: [Float] = [0]
        var decal: [UInt8] = []
        var decalOff: [Float] = []
        var decalHalf: [Float] = []
        var sprites: [[Spr]] = []
        var rampStarts: [Int] = []
        var segs = 0
        var total = 0
        var ringTotal = 0
        var enemyTotal = 0
        var theme = 0

        init(_ rng: inout Rng, stage: Int) {
            let st = max(0, min(2, stage))
            theme = st
            segs = TurboFox64.stageSegs[st]
            build(&rng, st)
        }

        func addSegment(_ c: Float, _ y: Float) {
            curve.append(c)
            pointY.append(y)
            decal.append(0)
            decalOff.append(0)
            decalHalf.append(0)
            sprites.append([])
        }

        static func easeIn(_ a: Float, _ b: Float, _ p: Float) -> Float { return a + (b - a) * p * p }
        static func easeInOut(_ a: Float, _ b: Float, _ p: Float) -> Float { return a + (b - a) * (0.5 - 0.5 * cos(p * Float.pi)) }

        func lastY() -> Float { return pointY[pointY.count - 1] }

        func addRoad(_ enter: Int, _ hold: Int, _ leave: Int, _ c: Float, _ dy: Float) {
            let startY = lastY()
            let endY = startY + dy
            let tot = max(1, enter + hold + leave)
            var n = 0
            for i in 0..<enter {
                let cv = Course.easeIn(0, c, Float(i) / Float(max(1, enter)))
                addSegment(cv, Course.easeInOut(startY, endY, Float(n) / Float(tot)))
                n += 1
            }
            for _ in 0..<hold {
                addSegment(c, Course.easeInOut(startY, endY, Float(n) / Float(tot)))
                n += 1
            }
            for i in 0..<leave {
                let cv = Course.easeInOut(c, 0, Float(i) / Float(max(1, leave)))
                addSegment(cv, Course.easeInOut(startY, endY, Float(n) / Float(tot)))
                n += 1
            }
        }

        func addRamp() {
            addRoad(10, 4, 10, 0, 0)
            let start = curve.count
            rampStarts.append(start)
            let y0 = lastY()
            for i in 0..<8 {
                addSegment(0, y0 + 60 * Float(i + 1))
                decal[curve.count - 1] = 3
            }
            let y1 = lastY()
            for _ in 0..<16 { addSegment(0, y1) }
            addRoad(20, 6, 20, 0, -480)
        }

        func setDecal(_ kind: UInt8, _ start: Int, _ len: Int, _ off: Float, _ half: Float) {
            for j in 0..<len {
                let i = start + j
                if i < 0 || i >= curve.count { continue }
                if decal[i] != 0 { continue }
                decal[i] = kind
                decalOff[i] = off
                decalHalf[i] = half
            }
        }

        func put(_ seg: Int, _ off: Float, _ kind: Int, _ h: Float) {
            if seg < 0 || seg >= sprites.count { return }
            sprites[seg].append(Spr(off: off, kind: kind, h: h, taken: false))
            if kind == TurboFox64.kRing { ringTotal += 1 }
            if kind == TurboFox64.kEnemy || kind == TurboFox64.kFly { enemyTotal += 1 }
        }

        func build(_ rng: inout Rng, _ stage: Int) {
            addRoad(10, 40, 10, 0, 0)
            var sinceRamp = 0
            while curve.count < segs {
                let before = curve.count
                let pick = rng.int(11)
                let sgn: Float = rng.chance(50) ? 1 : -1
                let cmag: Float = 1.4 + Float(rng.int(20)) / 10.0
                switch pick {
                case 0:
                    addRoad(20, 30 + rng.int(30), 20, 0, 0)
                case 1, 2:
                    addRoad(25, 30 + rng.int(40), 25, cmag * sgn, 0)
                case 3:
                    addRoad(25, 20 + rng.int(30), 25, 0, Float(rng.range(-2600, 1800)))
                case 4:
                    addRoad(22, 20, 22, 2.0 * sgn, -400)
                    addRoad(22, 20, 22, -2.0 * sgn, -400)
                case 5:
                    addRoad(30, 30, 30, cmag * sgn, Float(rng.range(-2200, 1400)))
                case 6:
                    if sinceRamp > 260 {
                        addRamp()
                        sinceRamp = 0
                    } else {
                        addRoad(20, 30, 20, 0, -900)
                    }
                case 7:
                    addRoad(20, 8, 20, 0, -1800)
                    addRoad(20, 8, 20, 0, 1800)
                case 8:
                    addRoad(18, 12, 18, 0, Float(rng.range(900, 1800)))
                    addRoad(18, 12, 18, 0, Float(rng.range(-2400, -900)))
                default:
                    addRoad(25, 30 + rng.int(30), 25, cmag * 0.7 * sgn, -500)
                }
                sinceRamp += curve.count - before
            }
            addRoad(10, 20, 10, 0, 0)
            segs = curve.count
            for _ in 0..<TurboFox64.extraSegs { addSegment(0, lastY()) }
            total = curve.count
            populate(&rng, stage)
        }

        func populate(_ rng: inout Rng, _ stage: Int) {
            let lw = TurboFox64.laneW
            let n = sprites.count
            var reserved = [Bool](repeating: false, count: n)
            for rs in rampStarts {
                let lo = max(0, rs - 10)
                let hi = min(n - 1, rs + 44)
                if lo <= hi {
                    for k in lo...hi { reserved[k] = true }
                }
                let lane = rng.int(3) - 1
                let lx: Float = Float(lane) * lw
                var t = 2
                while t <= 22 {
                    let tt: Float = Float(t)
                    var hh: Float = 60 * tt - 3 * tt * tt + 70
                    if hh < 70 { hh = 70 }
                    put(rs + 8 + t, lx, TurboFox64.kRing, hh)
                    t += 2
                }
            }
            let cp1 = segs / 3
            let cp2 = (segs * 2) / 3
            for cp in [cp1, cp2] {
                let lo = max(0, cp - 8)
                let hi = min(n - 1, cp + 8)
                for k in lo...hi { reserved[k] = true }
                put(cp, 0, TurboFox64.kCheck, 0)
            }
            put(segs, 0, TurboFox64.kFinish, 0)
            setDecal(4, segs - 1, 3, 0, 1.0)
            let lastP = segs - 30
            var i = 36
            var lastObst = -100
            while i < lastP {
                if reserved[i] {
                    i += 3
                    continue
                }
                let pick = rng.int(100)
                let lane = rng.int(3) - 1
                let lx: Float = Float(lane) * lw
                var kind = 1
                var len = 36
                if pick < 18 { kind = 1; len = 36 }
                else if pick < 30 { kind = 2; len = 36 }
                else if pick < 40 { kind = 3; len = 34 }
                else if pick < 54 { kind = 4; len = 32 }
                else if pick < 66 { kind = 5; len = 32 }
                else if pick < 75 { kind = 6; len = 38 }
                else if pick < 83 { kind = 7; len = 40 }
                else if pick < 92 { kind = 8; len = 34 }
                else { kind = 9; len = 56 }
                if i + len >= lastP { break }
                var blocked = false
                for k in i..<(i + len) {
                    if reserved[k] { blocked = true; break }
                }
                if blocked {
                    i += 4
                    continue
                }
                if kind == 5 && i - lastObst < 40 { kind = 1 }
                if stage == 0 && i < 300 && (kind == 5 || kind == 9) { kind = 1 }
                switch kind {
                case 1:
                    let cnt = 8 + rng.int(4)
                    for k in 0..<cnt { put(i + 2 + k * 3, lx, TurboFox64.kRing, 60) }
                case 2:
                    for k in 0..<9 {
                        let t: Float = Float(k) / 8.0
                        let hh: Float = 60 + sin(t * Float.pi) * 300
                        put(i + 4 + k * 3, lx, TurboFox64.kRing, hh)
                    }
                case 3:
                    for k in 0..<14 {
                        let kf: Float = Float(k)
                        let ox: Float = sin(kf * 0.55) * lw
                        let hh: Float = 80 + (cos(kf * 0.55) + 1.0) * 60
                        put(i + 2 + k * 2, ox, TurboFox64.kRing, hh)
                    }
                case 4:
                    let maxCnt = stage == 0 ? 1 : 2
                    let cnt = 1 + rng.int(maxCnt)
                    for k in 0..<cnt {
                        let li = (lane + 1 + k) % 3
                        let ox: Float = Float(li - 1) * lw
                        let sg = i + 10 + k * 8
                        put(sg - 4, ox, TurboFox64.kRing, 200)
                        put(sg - 2, ox, TurboFox64.kRing, 300)
                        put(sg, ox, TurboFox64.kEnemy, 0)
                        put(sg + 2, ox, TurboFox64.kRing, 300)
                        put(sg + 4, ox, TurboFox64.kRing, 200)
                    }
                case 5:
                    let free = lane
                    let blockCount = stage == 0 ? 1 : 2
                    var placed = 0
                    for li in 0..<3 {
                        let laneIdx = li - 1
                        if laneIdx == free { continue }
                        if placed >= blockCount { break }
                        put(i + 14, Float(laneIdx) * lw, TurboFox64.kObst, 0)
                        placed += 1
                    }
                    for k in 0..<6 { put(i + 2 + k * 2, lx, TurboFox64.kRing, 60) }
                    lastObst = i
                case 6:
                    put(i + 6, lx, TurboFox64.kSpring, 0)
                    var t = 5
                    while t <= 25 {
                        let tt: Float = Float(t)
                        let hh: Float = 90 * tt - 3 * tt * tt + 60
                        put(i + 6 + t, lx, TurboFox64.kRing, hh)
                        t += 4
                    }
                case 7:
                    setDecal(1, i, 5, lx, 0.28)
                    for k in 0..<10 { put(i + 8 + k * 3, lx, TurboFox64.kRing, 60) }
                case 8:
                    setDecal(2, i + 3, 16, lx, 0.12)
                    for k in 0..<8 { put(i + 4 + k * 2, lx, TurboFox64.kRing, 120) }
                default:
                    for k in 0..<4 {
                        let li = (k + lane + 1) % 3
                        let ox: Float = Float(li - 1) * lw
                        let sg = i + 8 + k * 10
                        put(sg - 3, ox, TurboFox64.kRing, 330)
                        put(sg, ox, TurboFox64.kFly, 300)
                    }
                }
                i += len + 3 + rng.int(8)
            }
            var s = 2
            while s < n - 2 {
                for side in 0..<2 {
                    if rng.chance(60) {
                        let sgn: Float = side == 0 ? -1 : 1
                        let off: Float = sgn * (1.3 + Float(rng.unit()) * 1.6)
                        let r = rng.int(10)
                        var kind = TurboFox64.kScnA
                        if r >= 8 { kind = TurboFox64.kScnC } else if r >= 5 { kind = TurboFox64.kScnB }
                        sprites[s].append(Spr(off: off, kind: kind, h: 0, taken: false))
                    }
                }
                s += 4
            }
        }
    }

    // MARK: - State

    private var phase: Phase = .title
    private var rng = Rng()
    private var course: Course
    private var stage = 0
    private var theme = 0
    private var frame = 0
    private var pos: Float = 160
    private var speed: Float = 0
    private var playerX: Float = 0
    private var steerTarget: Float = 0
    private var holdFrames = 0
    private var py: Float = 0
    private var vy: Float = 0
    private var lastSlope: Float = 0
    private var grounded = true
    private var jumpsUsed = 0
    private var airFrames = 0
    private var homing = false
    private var homeSeg = -1
    private var homeIdx = -1
    private var homeFrames = 0
    private var lockSeg = -1
    private var lockIdx = -1
    private var lockSX = -100
    private var lockSY = -100
    private var grinding = false
    private var grindTick = 0
    private var boostMeter: Float = 40
    private var boosting = false
    private var padTimer = 0
    private var dashCool = 0
    private var rings = 0
    private var ringsForLife = 0
    private var lives = 3
    private var combo = 0
    private var hurtTimer = 0
    private var invuln = 0
    private var shake = 0
    private var flash = 0
    private var flashR = 255
    private var flashG = 255
    private var flashB = 255
    private var camBase: Float = 0
    private var groundNow: Float = 0
    private var fovK: Float = TurboFox64.baseFov
    private var bgOff: Float = 0
    private var runPhase: Float = 0
    private var cdTimer = 0
    private var resultTimer = 0
    private var clearTimer = 0
    private var pts = 0
    private var totalRings = 0
    private var stageRings = 0
    private var stageBash = 0
    private var stageHits = 0
    private var stageFrames = 0
    private var cpIndex = 0
    private var cpSeg = 4
    private var continues = 0
    private var ranks: [Int] = [0, 0, 0]
    private var rankPct = 0
    private var msg = ""
    private var msgTimer = 0
    private var msgColor: UInt32 = TurboFox64.cYellow
    private var lastRingSfx = -10
    private var boostHinted = false
    private var parts: [Part] = []
    private var texts: [FText] = []
    private var geoBase = 0
    private var gOK = [Bool](repeating: false, count: TurboFox64.drawN)
    private var gDrawn = [Bool](repeating: false, count: TurboFox64.drawN)
    private var gY1 = [Float](repeating: 0, count: TurboFox64.drawN)
    private var gY2 = [Float](repeating: 0, count: TurboFox64.drawN)
    private var gCX1 = [Float](repeating: 0, count: TurboFox64.drawN)
    private var gCX2 = [Float](repeating: 0, count: TurboFox64.drawN)
    private var gP1 = [Float](repeating: 0, count: TurboFox64.drawN)
    private var gP2 = [Float](repeating: 0, count: TurboFox64.drawN)
    private var gClip = [Float](repeating: 288, count: TurboFox64.drawN)
    private var gBot = [Float](repeating: 0, count: TurboFox64.drawN)
    private var gZ1 = [Float](repeating: 0, count: TurboFox64.drawN)

    override var score: Int { return max(0, pts) }
    override var wantsPointer: Bool { return true }

    struct TapT {
        var seg: Int
        var idx: Int
        var sx: Int
        var sy: Int
    }

    private var tapTargets: [TapT] = []
    private var tStartFrame = 0
    private var tStartX = 0
    private var tStartY = 0
    private var tMove = 0
    private var tBottom = false
    private var touchSteer = false
    private var touchX = 160
    private var tapAimSeg = -1
    private var tapAimIdx = -1

    private func processTouch(_ raw: InputState) -> InputState {
        var inp = raw
        let ptr = raw.pointer
        tapAimSeg = -1
        tapAimIdx = -1
        touchSteer = false
        if ptr.pressed {
            tStartFrame = frame
            tStartX = ptr.x
            tStartY = ptr.y
            tMove = 0
            tBottom = ptr.y >= 216
        }
        if ptr.down {
            let m = max(abs(ptr.x - tStartX), abs(ptr.y - tStartY))
            if m > tMove { tMove = m }
        }
        if phase == .run {
            if ptr.down && ptr.y >= 216 {
                inp.held.insert(.b)
            } else if ptr.down {
                touchSteer = true
                touchX = ptr.x
            }
            if ptr.released && !tBottom && frame - tStartFrame <= 15 && tMove < 16 {
                inp.pressed.insert(.a)
                var best = 36 * 36
                for t in tapTargets {
                    let dx = t.sx - ptr.x
                    let dy = t.sy - ptr.y
                    let d2 = dx * dx + dy * dy
                    if d2 < best {
                        best = d2
                        tapAimSeg = t.seg
                        tapAimIdx = t.idx
                    }
                }
            }
        } else if ptr.pressed {
            inp.pressed.insert(.a)
        }
        return inp
    }

    override init() {
        var r = Rng()
        course = Course(&r, stage: 0)
        super.init()
        rng = r
        resetRunState()
        phase = .title
    }

    override func start() {
        playMusic(Tunes.race)
    }

    // MARK: - Setup

    private func resetRunState() {
        theme = stage
        let seg = TurboFox64.segLen
        let playerZ: Float = 4 * seg
        pos = playerZ - TurboFox64.playerDist
        speed = 0
        playerX = 0
        steerTarget = 0
        holdFrames = 0
        vy = 0
        lastSlope = 0
        grounded = true
        jumpsUsed = 0
        airFrames = 0
        homing = false
        homeSeg = -1
        homeIdx = -1
        lockSeg = -1
        lockIdx = -1
        grinding = false
        boostMeter = 40
        boosting = false
        padTimer = 0
        dashCool = 0
        rings = 0
        ringsForLife = 0
        combo = 0
        hurtTimer = 0
        invuln = 0
        shake = 0
        flash = 0
        fovK = TurboFox64.baseFov
        bgOff = 0
        runPhase = 0
        stageRings = 0
        stageBash = 0
        stageHits = 0
        stageFrames = 0
        cpIndex = 0
        cpSeg = 4
        parts = []
        texts = []
        msg = ""
        msgTimer = 0
        groundNow = groundAt(playerZ)
        py = groundNow
        camBase = groundNow
    }

    private func beginGame() {
        stage = 0
        lives = 3
        pts = 0
        totalRings = 0
        continues = 0
        ranks = [0, 0, 0]
        beginStage(0)
    }

    private func beginStage(_ s: Int) {
        stage = s
        course = Course(&rng, stage: s)
        resetRunState()
        phase = .ready
        cdTimer = 190
    }

    private func nextStage() {
        if stage < 2 {
            beginStage(stage + 1)
            play(.confirm)
        } else {
            phase = .final
            resultTimer = 0
            play(.win)
        }
    }

    private func continueFromCheckpoint() {
        let seg = TurboFox64.segLen
        let startSeg = cpIndex > 0 ? cpSeg + 3 : 4
        pos = Float(startSeg) * seg - TurboFox64.playerDist
        speed = 0
        lives = 3
        rings = 0
        playerX = 0
        steerTarget = 0
        vy = 0
        grounded = true
        jumpsUsed = 0
        homing = false
        grinding = false
        hurtTimer = 0
        invuln = 150
        combo = 0
        continues += 1
        let pz = pos + TurboFox64.playerDist
        groundNow = groundAt(pz)
        py = groundNow
        camBase = groundNow
        phase = .ready
        cdTimer = 100
        showMsg("TRY AGAIN!", 60, TurboFox64.cGreen)
        play(.confirm)
    }

    private func showMsg(_ s: String, _ frames: Int, _ c: UInt32) {
        msg = s
        msgTimer = frames
        msgColor = c
    }

    // MARK: - Helpers

    private func segIndex(_ z: Float) -> Int {
        let total = course.total
        if !(z >= 0) { return 0 }
        let f: Float = z / TurboFox64.segLen
        if f > Float(total - 2) { return max(0, total - 2) }
        return Int(f)
    }

    private func groundAt(_ z: Float) -> Float {
        let idx = segIndex(z)
        var pct: Float = z / TurboFox64.segLen - Float(idx)
        if !(pct >= 0) { pct = 0 }
        if pct > 1 { pct = 1 }
        let a = course.pointY[idx]
        let b = course.pointY[idx + 1]
        return a + (b - a) * pct
    }

    private func nearestLane(_ x: Float) -> Int {
        if !x.isFinite { return 0 }
        let f: Float = x / TurboFox64.laneW
        let r = Int(clamp(f, -3, 3).rounded())
        return max(-1, min(1, r))
    }

    private func laneX(_ l: Int) -> Float {
        return Float(l) * TurboFox64.laneW
    }

    private func foxScreenX() -> Int {
        let ppuP: Float = fovK / TurboFox64.playerDist
        let x: Float = 160 + ppuP * (playerX * TurboFox64.roadW * (1 - TurboFox64.camFollow))
        return Int(clamp(x, 20, 300))
    }

    private func foxScreenY(_ wy: Float) -> Int {
        let ppuP: Float = fovK / TurboFox64.playerDist
        let camYw: Float = camBase + TurboFox64.camH
        let y: Float = TurboFox64.horizonY + ppuP * (camYw - wy)
        return Int(clamp(y, 40, 300))
    }

    private func addPart(_ x: Float, _ y: Float, _ vx: Float, _ vy: Float, _ grav: Float, _ life: Int, _ size: Int, _ c: UInt32) {
        if parts.count >= 160 { return }
        parts.append(Part(x: x, y: y, vx: vx, vy: vy, grav: grav, life: life, size: size, c: c))
    }

    private func addText(_ s: String, _ x: Float, _ y: Float, _ c: UInt32) {
        if texts.count >= 8 { texts.removeFirst() }
        texts.append(FText(x: x, y: y, life: 50, text: s, c: c))
    }

    private func burst(_ x: Float, _ y: Float, _ n: Int, _ c: UInt32, _ spd: Float, _ grav: Float) {
        for _ in 0..<n {
            let a: Float = Float(rng.int(628)) / 100.0
            let s: Float = spd * (0.4 + Float(rng.int(100)) / 100.0)
            addPart(x, y, cos(a) * s, sin(a) * s - 1, grav, 18 + rng.int(14), 2 + rng.int(2), c)
        }
    }

    private func updateFX() {
        var i = 0
        while i < parts.count {
            parts[i].x += parts[i].vx
            parts[i].y += parts[i].vy
            parts[i].vy += parts[i].grav
            parts[i].life -= 1
            i += 1
        }
        parts.removeAll(where: { $0.life <= 0 })
        var k = 0
        while k < texts.count {
            texts[k].y -= 0.8
            texts[k].life -= 1
            k += 1
        }
        texts.removeAll(where: { $0.life <= 0 })
    }

    // MARK: - Update

    override func update(_ rawInput: InputState) {
        let input = processTouch(rawInput)
        frame += 1
        if msgTimer > 0 { msgTimer -= 1 }
        if shake > 0 { shake -= 1 }
        if flash > 0 { flash -= 1 }
        if !pos.isFinite { pos = 160 }
        updateFX()
        switch phase {
        case .title:
            stepDemo()
            if input.aPressed || input.startPressed {
                beginGame()
                play(.confirm)
            }
        case .ready:
            cdTimer -= 1
            followCamera()
            runPhase += 0.05
            if cdTimer == 150 || cdTimer == 100 || cdTimer == 50 { play(.countdown) }
            if cdTimer <= 0 {
                phase = .run
                speed = 0.6
                showMsg("GO!", 50, TurboFox64.cGreen)
                play(.powerup)
            }
        case .run:
            stepRun(input)
        case .clear:
            stepClear()
        case .results:
            resultTimer += 1
            followCamera()
            if resultTimer > 45 && (input.aPressed || input.startPressed) { nextStage() }
        case .over:
            resultTimer += 1
            followCamera()
            if resultTimer > 30 {
                if input.aPressed {
                    continueFromCheckpoint()
                } else if input.startPressed {
                    beginGame()
                    play(.confirm)
                }
            }
        case .final:
            resultTimer += 1
            if resultTimer > 60 && (input.aPressed || input.startPressed) {
                resetToTitle()
                play(.confirm)
            }
        }
    }

    private func resetToTitle() {
        stage = 0
        course = Course(&rng, stage: 0)
        resetRunState()
        phase = .title
    }

    private func followCamera() {
        let playerZ = pos + TurboFox64.playerDist
        groundNow = groundAt(playerZ)
        let air: Float = max(0, py - groundNow)
        let target: Float = groundNow + air * 0.35
        camBase += (target - camBase) * 0.25
        if !camBase.isFinite { camBase = groundNow }
    }

    private func stepDemo() {
        let seg = TurboFox64.segLen
        speed = 0.95
        steerTarget = laneX(Int((sin(Float(frame) * 0.02) * 1.4).rounded()))
        playerX += (steerTarget - playerX) * 0.1
        pos += speed * seg
        let limit: Float = Float(course.segs / 2) * seg
        if pos > limit { pos = 160 }
        let pz = pos + TurboFox64.playerDist
        groundNow = groundAt(pz)
        py = groundNow
        grounded = true
        let idx = segIndex(pz)
        bgOff += course.curve[idx] * speed * 0.5
        bgOff = bgOff - 5120 * floor(bgOff / 5120)
        runPhase += speed * 0.3
        camBase += (groundNow - camBase) * 0.3
    }

    private func stepClear() {
        let seg = TurboFox64.segLen
        clearTimer -= 1
        speed *= 0.975
        if speed < 0.25 { speed = 0.25 }
        pos += speed * seg
        let maxPos: Float = Float(max(1, course.total - 140)) * seg
        if pos > maxPos { pos = maxPos }
        playerX += (0 - playerX) * 0.05
        grounded = true
        let pz = pos + TurboFox64.playerDist
        groundNow = groundAt(pz)
        py = groundNow
        runPhase += speed * 0.25
        followCamera()
        fovK += (TurboFox64.baseFov - fovK) * 0.1
        if clearTimer % 4 == 0 {
            let cols: [UInt32] = [TurboFox64.cYellow, TurboFox64.cPink, TurboFox64.cCyan, TurboFox64.cGreen]
            let x: Float = Float(20 + rng.int(280))
            addPart(x, 40, Float(rng.range(-10, 10)) / 10.0, 1.5, 0.05, 50, 3, cols[rng.int(4)])
        }
        if clearTimer <= 0 {
            phase = .results
            resultTimer = 0
        }
    }

    private func stepRun(_ input: InputState) {
        let c = course
        let seg = TurboFox64.segLen
        stageFrames += 1
        if hurtTimer > 0 { hurtTimer -= 1 }
        if invuln > 0 { invuln -= 1 }
        if padTimer > 0 { padTimer -= 1 }
        if dashCool > 0 { dashCool -= 1 }
        let canAct = hurtTimer < 22
        let prevZ = pos + TurboFox64.playerDist
        let idx0 = segIndex(prevZ)
        let curveHere = c.curve[idx0]

        // steering with lane snapping
        var dxIn = input.dx
        if !canAct { dxIn = 0 }
        if canAct && input.leftPressed {
            steerTarget = laneX(nearestLane(steerTarget) - 1)
            holdFrames = 0
        } else if canAct && input.rightPressed {
            steerTarget = laneX(nearestLane(steerTarget) + 1)
            holdFrames = 0
        }
        if dxIn != 0 {
            holdFrames += 1
            if holdFrames > 9 { steerTarget += Float(dxIn) * 0.045 }
        } else {
            if holdFrames > 9 { steerTarget = laneX(nearestLane(steerTarget)) }
            holdFrames = 0
        }
        if touchSteer && dxIn == 0 && canAct {
            var tgt: Float = (Float(touchX) - 160) / 64
            tgt = clamp(tgt, -0.92, 0.92)
            let near: Float = laneX(nearestLane(tgt))
            if abs(tgt - near) < 0.2 { tgt = near }
            steerTarget = tgt
            holdFrames = 0
        }
        steerTarget = clamp(steerTarget, -0.92, 0.92)
        if !homing && !grinding {
            var stepX: Float = (steerTarget - playerX) * 0.2
            stepX = clamp(stepX, -0.075, 0.075)
            playerX += stepX
        }
        playerX = clamp(playerX, -1.0, 1.0)
        if !playerX.isFinite { playerX = 0 }

        // jump / homing
        if input.aPressed && canAct { handleAPress() }

        // boost
        let wantBoost = input.b && canAct
        if wantBoost && boostMeter > 0.5 {
            if !boosting { play(.powerup) }
            boosting = true
            boostMeter -= 0.55
            if boostMeter < 0 { boostMeter = 0 }
        } else {
            boosting = false
            if wantBoost && input.bPressed && !boostHinted {
                showMsg("COLLECT RINGS TO FILL BOOST", 70, TurboFox64.cCyan)
            }
        }
        if !boosting && boostMeter < 100 { boostMeter += 0.03 }
        if boostMeter >= 60 && !boostHinted && stage == 0 && stageFrames > 200 {
            boostHinted = true
            showMsg("HOLD B TO BOOST!", 120, TurboFox64.cCyan)
        }

        // speed
        var target: Float = TurboFox64.baseSpeed[stage]
        if padTimer > 0 { target += 0.5 }
        if boosting { target += 0.6 }
        if grinding { target += 0.15 }
        if hurtTimer > 0 { target = 0.5 }
        speed += (target - speed) * 0.05
        speed = clamp(speed, 0.2, 2.1)

        // homing step
        if homing {
            homeFrames += 1
            var alive = false
            if homeSeg >= 0 && homeSeg < c.total && homeIdx >= 0 && homeIdx < c.sprites[homeSeg].count {
                if !c.sprites[homeSeg][homeIdx].taken { alive = true }
            }
            if !alive || homeFrames > 40 {
                homing = false
                vy = 8
            } else {
                let sp = c.sprites[homeSeg][homeIdx]
                playerX += (sp.off - playerX) * 0.4
                steerTarget = playerX
                let extra: Float = sp.kind == TurboFox64.kFly ? 260 : 40
                let tY: Float = c.pointY[homeSeg] + extra
                py += (tY - py) * 0.35
            }
        }

        // advance
        var adv: Float = speed * seg
        if homing { adv = max(adv, seg * 2.6) }
        pos += adv
        let maxPos: Float = Float(max(1, c.total - 140)) * seg
        if pos > maxPos { pos = maxPos }
        let newZ = pos + TurboFox64.playerDist
        let newGround = groundAt(newZ)
        groundNow = newGround

        // vertical
        if grinding {
            py += (newGround + 36 - py) * 0.5
            vy = 0
        } else if homing {
            airFrames += 1
        } else if grounded {
            if newGround < py + lastSlope - 14 && speed > 0.5 && hurtTimer < 1 {
                grounded = false
                vy = clamp(lastSlope, -60, 90)
                airFrames = 0
                jumpsUsed = 1
                py += vy
                play(.jump)
            } else {
                lastSlope = clamp(newGround - py, -400, 400)
                py = newGround
            }
        } else {
            py += vy
            vy -= 6
            if vy < -90 { vy = -90 }
            airFrames += 1
            if py <= newGround { landOn(newGround) }
        }
        if !py.isFinite { py = newGround }

        // decals on current segment
        let idx1 = segIndex(newZ)
        let d = c.decal[idx1]
        let doff = c.decalOff[idx1]
        let dhalf = c.decalHalf[idx1]
        let lat: Float = abs(playerX - doff)
        if d == 1 && grounded && lat < dhalf + 0.12 && dashCool == 0 {
            padTimer = 75
            dashCool = 20
            speed = max(speed, 1.5)
            shake = 6
            showMsg("DASH!", 40, TurboFox64.cOrange)
            play(.powerup)
        }
        if d == 2 && !grinding && !homing && hurtTimer < 22 && lat < dhalf + 0.22 && (py - newGround) < 170 && (grounded || vy <= 0) {
            grinding = true
            grounded = false
            vy = 0
            jumpsUsed = 0
            combo = 0
            grindTick = 0
            showMsg("GRIND!", 40, TurboFox64.cCyan)
            play(.pickup)
        }
        if grinding {
            if d != 2 {
                grinding = false
                grounded = false
                vy = 14
                airFrames = 0
                jumpsUsed = 1
            } else {
                playerX += (doff - playerX) * 0.3
                steerTarget = doff
                grindTick += 1
                if grindTick % 8 == 0 {
                    pts += 20
                    let sx = Float(foxScreenX())
                    let sy = Float(foxScreenY(py))
                    burst(sx, sy, 3, TurboFox64.cYellow, 2.5, 0.15)
                    play(.step)
                }
            }
        }

        // crossing checks
        if idx1 > idx0 {
            for i in (idx0 + 1)...idx1 {
                if i >= c.total { break }
                if i % 3 == 0 { pts += 1 }
                let n = c.sprites[i].count
                if n > 0 {
                    for j in 0..<n {
                        handleSprite(i, j)
                        if phase != .run { return }
                    }
                }
            }
        }

        // lock-on reticle
        lockSeg = -1
        lockIdx = -1
        if !grounded && !homing && !grinding {
            let t = scanTarget()
            lockSeg = t.0
            lockIdx = t.1
        }

        // trail particles
        if boosting {
            let sx = Float(foxScreenX())
            let sy = Float(foxScreenY(py))
            addPart(sx + Float(rng.range(-8, 8)), sy - 10, 0, 2.5, 0.0, 10, 2, TurboFox64.cCyan)
        }

        bgOff += curveHere * speed * 0.5
        bgOff = bgOff - 5120 * floor(bgOff / 5120)
        runPhase += speed * 0.3
        followCamera()
        var fovT: Float = TurboFox64.baseFov
        if boosting { fovT = 92 } else if padTimer > 0 { fovT = 106 } else if speed > 1.3 { fovT = 116 }
        fovK += (fovT - fovK) * 0.1
    }

    private func handleAPress() {
        if grinding {
            grinding = false
            grounded = false
            vy = 72
            airFrames = 0
            jumpsUsed = 1
            play(.jump)
            return
        }
        if grounded {
            grounded = false
            vy = 78
            airFrames = 0
            jumpsUsed = 1
            play(.jump)
            let sx = Float(foxScreenX())
            let sy = Float(foxScreenY(py))
            burst(sx, sy, 5, TurboFox64.cWhite, 1.8, 0.1)
            return
        }
        if homing { return }
        var t = scanTarget()
        if tapAimSeg >= 0 && tapAimSeg < course.total && tapAimIdx >= 0 && tapAimIdx < course.sprites[tapAimSeg].count {
            let pz = pos + TurboFox64.playerDist
            if tapAimSeg > segIndex(pz) && !course.sprites[tapAimSeg][tapAimIdx].taken {
                t = (tapAimSeg, tapAimIdx)
            }
        }
        if t.0 >= 0 {
            homeSeg = t.0
            homeIdx = t.1
            homing = true
            homeFrames = 0
            play(.sword)
            return
        }
        if jumpsUsed < 2 {
            vy = 68
            jumpsUsed = 2
            airFrames = 0
            play(.jump)
            let sx = Float(foxScreenX())
            let sy = Float(foxScreenY(py))
            burst(sx, sy, 6, TurboFox64.cCyan, 2.0, 0.1)
        }
    }

    private func scanTarget() -> (Int, Int) {
        let c = course
        let pz = pos + TurboFox64.playerDist
        let s0 = segIndex(pz) + 1
        let s1 = min(c.total - 1, s0 + 48)
        var bestSeg = -1
        var bestIdx = -1
        var bestScore: Float = 1000000
        if s0 > s1 { return (-1, -1) }
        for i in s0...s1 {
            let n = c.sprites[i].count
            if n == 0 { continue }
            for j in 0..<n {
                let sp = c.sprites[i][j]
                if sp.taken { continue }
                if sp.kind != TurboFox64.kEnemy && sp.kind != TurboFox64.kFly && sp.kind != TurboFox64.kSpring { continue }
                let latD: Float = abs(sp.off - playerX)
                if latD > 1.3 { continue }
                let sc: Float = Float(i - s0) + latD * 6
                if sc < bestScore {
                    bestScore = sc
                    bestSeg = i
                    bestIdx = j
                }
            }
        }
        return (bestSeg, bestIdx)
    }

    private func landOn(_ g: Float) {
        py = g
        grounded = true
        vy = 0
        lastSlope = 0
        homing = false
        if airFrames > 12 {
            play(.thud)
            shake = max(shake, 4)
            let sx = Float(foxScreenX())
            let sy = Float(foxScreenY(py))
            burst(sx, sy, 6, TurboFox64.cWhite, 2.0, 0.08)
        }
        jumpsUsed = 0
        combo = 0
        airFrames = 0
    }

    private func collectRing() {
        rings += 1
        stageRings += 1
        totalRings += 1
        ringsForLife += 1
        pts += 10
        boostMeter = min(100, boostMeter + 4)
        let sx = Float(foxScreenX())
        let sy = Float(foxScreenY(py)) - 22
        burst(sx, sy, 2, TurboFox64.cGold, 2.2, 0.1)
        if frame - lastRingSfx >= 4 {
            play(.pickup)
            lastRingSfx = frame
        }
        if ringsForLife >= 60 {
            ringsForLife -= 60
            if lives < 5 {
                lives += 1
                showMsg("1UP!", 60, TurboFox64.cGreen)
                play(.win)
            }
        }
    }

    private func bash(_ i: Int, _ j: Int, _ bounce: Bool) {
        course.sprites[i][j].taken = true
        stageBash += 1
        combo += 1
        let add = 100 * min(combo, 8)
        pts += add
        boostMeter = min(100, boostMeter + 8)
        if bounce {
            vy = 62
            grounded = false
            homing = false
            jumpsUsed = 1
            airFrames = 0
        }
        shake = max(shake, 5)
        let sx = Float(foxScreenX())
        let sy = Float(foxScreenY(py)) - 20
        burst(sx, sy, 12, TurboFox64.cYellow, 3.5, 0.12)
        burst(sx, sy, 6, TurboFox64.cWhite, 2.5, 0.05)
        if combo > 1 {
            addText("X" + String(combo) + " +" + String(add), sx, sy - 10, TurboFox64.cYellow)
            showMsg("COMBO X" + String(combo), 50, TurboFox64.cOrange)
        } else {
            addText("+" + String(add), sx, sy - 10, TurboFox64.cYellow)
        }
        play(.stomp)
        if combo >= 2 { play(.pickup) }
    }

    private func takeHit() {
        if invuln > 0 || homing || phase != .run { return }
        stageHits += 1
        combo = 0
        grinding = false
        boosting = false
        invuln = 120
        hurtTimer = 45
        shake = 14
        flash = 6
        flashR = 255
        flashG = 60
        flashB = 50
        let sx = Float(foxScreenX())
        let sy = Float(foxScreenY(py)) - 20
        if rings > 0 {
            let n = min(rings, 24)
            for _ in 0..<n {
                let a: Float = Float(rng.int(628)) / 100.0
                let s: Float = 2.0 + Float(rng.int(30)) / 10.0
                addPart(sx, sy, cos(a) * s, sin(a) * s - 3, 0.18, 40 + rng.int(20), 4, TurboFox64.cGold)
            }
            addText("RINGS LOST", sx, sy - 14, TurboFox64.cRed)
            rings = 0
            play(.hurt)
        } else {
            lives -= 1
            play(.hurt)
            if lives <= 0 {
                lives = 0
                phase = .over
                resultTimer = 0
                play(.lose)
            } else {
                addText("OUCH!", sx, sy - 14, TurboFox64.cRed)
            }
        }
        speed = min(speed, 0.6)
        if grounded {
            grounded = false
            vy = 36
            airFrames = 0
        }
    }

    private func handleSprite(_ i: Int, _ j: Int) {
        let c = course
        let s = c.sprites[i][j]
        if s.taken { return }
        let k = s.kind
        let lat: Float = abs(playerX - s.off)
        let ground: Float = c.pointY[i]
        let rel: Float = py - ground
        if k == TurboFox64.kRing {
            let center: Float = rel + 60
            if lat < 0.42 && abs(s.h - center) < 260 {
                c.sprites[i][j].taken = true
                collectRing()
            }
        } else if k == TurboFox64.kEnemy {
            let isTarget = homing && i == homeSeg && j == homeIdx
            if isTarget || (homing && lat < 0.5) {
                bash(i, j, true)
            } else if boosting && lat < 0.5 {
                bash(i, j, false)
            } else if !grounded && lat < 0.5 && rel > 30 {
                bash(i, j, true)
            } else if grounded && lat < 0.34 && !grinding {
                takeHit()
            }
        } else if k == TurboFox64.kFly {
            let isTarget = homing && i == homeSeg && j == homeIdx
            if isTarget || (homing && lat < 0.5) {
                bash(i, j, true)
            } else if !grounded && lat < 0.5 && abs(rel + 60 - 300) < 300 {
                bash(i, j, true)
            }
        } else if k == TurboFox64.kSpring {
            let isTarget = homing && i == homeSeg && j == homeIdx
            if isTarget || (lat < 0.4 && rel < 200 && !homing) {
                c.sprites[i][j].taken = true
                vy = 90
                grounded = false
                homing = false
                grinding = false
                jumpsUsed = 1
                airFrames = 0
                combo = 0
                shake = 8
                pts += 50
                showMsg("SPRING!", 45, TurboFox64.cYellow)
                play(.bounce)
                play(.jump)
            }
        } else if k == TurboFox64.kObst {
            if lat < 0.3 && rel < 300 && !homing {
                if boosting {
                    c.sprites[i][j].taken = true
                    pts += 50
                    shake = 8
                    let sx = Float(foxScreenX())
                    let sy = Float(foxScreenY(py)) - 20
                    burst(sx, sy, 14, TurboFox64.cOrange, 3.5, 0.15)
                    addText("SMASH +50", sx, sy - 10, TurboFox64.cOrange)
                    play(.explosion)
                } else if invuln == 0 {
                    takeHit()
                }
            }
        } else if k == TurboFox64.kCheck {
            c.sprites[i][j].taken = true
            cpIndex += 1
            cpSeg = i
            pts += 200
            showMsg("CHECKPOINT!", 80, TurboFox64.cGreen)
            play(.powerup)
        } else if k == TurboFox64.kFinish {
            c.sprites[i][j].taken = true
            beginClear()
        }
    }

    private func beginClear() {
        phase = .clear
        clearTimer = 170
        boosting = false
        homing = false
        grinding = false
        let c = course
        var ringFrac: Float = 1
        if c.ringTotal > 0 { ringFrac = min(1, Float(stageRings) / (Float(c.ringTotal) * 0.75)) }
        var enemyFrac: Float = 1
        if c.enemyTotal > 0 { enemyFrac = min(1, Float(stageBash) / Float(c.enemyTotal)) }
        let par: Float = Float(c.segs) / (TurboFox64.baseSpeed[stage] + 0.4)
        let timeFrac: Float = clamp((par * 1.5 - Float(stageFrames)) / (par * 0.5), 0, 1)
        let penalty: Float = Float(stageHits) * 4
        let total: Float = ringFrac * 50 + enemyFrac * 20 + timeFrac * 30 - penalty
        var r = 0
        if total >= 80 { r = 3 } else if total >= 60 { r = 2 } else if total >= 38 { r = 1 }
        ranks[stage] = r
        rankPct = Int(clamp(total, 0, 100))
        let bonus: [Int] = [500, 1000, 2000, 3500]
        pts += bonus[r] + stageRings * 5
        showMsg("STAGE CLEAR!", 150, TurboFox64.cGreen)
        play(.win)
    }

    // MARK: - Geometry

    private func buildGeometry() {
        let c = course
        let total = c.total
        let seg = TurboFox64.segLen
        let baseIdx = max(0, min(total - 2, Int(max(0, pos) / seg)))
        var basePct: Float = pos / seg - Float(baseIdx)
        if !(basePct >= 0) { basePct = 0 }
        if basePct > 1 { basePct = 1 }
        var shX: Float = 0
        var shY: Float = 0
        if shake > 0 {
            let m: Float = Float(min(shake, 8)) * 0.5
            shX = (Float((frame * 7) % 5) - 2) * m * 0.5
            shY = (Float((frame * 11) % 5) - 2) * m * 0.5
        }
        var x: Float = 0
        var dx: Float = -(basePct * c.curve[baseIdx])
        var maxY: Float = 288
        let camXw: Float = playerX * TurboFox64.roadW * TurboFox64.camFollow
        let camYw: Float = camBase + TurboFox64.camH
        let depthK: Float = fovK
        let hz: Float = TurboFox64.horizonY + shY
        geoBase = baseIdx
        for n in 0..<TurboFox64.drawN {
            let idx = baseIdx + n
            gDrawn[n] = false
            gOK[n] = false
            if idx + 1 >= total { continue }
            let z1: Float = Float(idx) * seg - pos
            let z2: Float = z1 + seg
            gClip[n] = maxY
            gZ1[n] = z1
            if z1 > 1 {
                let ppu1: Float = depthK / z1
                let ppu2: Float = depthK / z2
                let cx1: Float = 160 + shX + ppu1 * (x - camXw)
                let cx2: Float = 160 + shX + ppu2 * ((x + dx) - camXw)
                var y1: Float = hz - ppu1 * (c.pointY[idx] - camYw)
                var y2: Float = hz - ppu2 * (c.pointY[idx + 1] - camYw)
                y1 = clamp(y1, -30000, 30000)
                y2 = clamp(y2, -30000, 30000)
                gOK[n] = true
                gY1[n] = y1
                gY2[n] = y2
                gCX1[n] = clamp(cx1, -30000, 30000)
                gCX2[n] = clamp(cx2, -30000, 30000)
                gP1[n] = ppu1
                gP2[n] = ppu2
                if y2 < y1 && y2 < maxY {
                    gDrawn[n] = true
                    gBot[n] = min(y1, maxY)
                    maxY = y2
                }
            }
            x += dx
            dx += c.curve[idx]
        }
    }

    // MARK: - Rendering

    @inline(__always) private func span(_ p: UnsafeMutablePointer<UInt32>, _ base: Int, _ x0: Int, _ x1: Int, _ c: UInt32) {
        let a = max(0, x0)
        let e = min(320, x1)
        if a >= e { return }
        var i = base + a
        let end = base + e
        while i < end {
            p[i] = c
            i += 1
        }
    }

    private func discSpan(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ cx: Int, _ cy: Int, _ r: Int, _ c: UInt32) {
        if r <= 0 { return }
        for dy in -r...r {
            let yy = cy + dy
            if yy < 0 || yy >= h { continue }
            let hw = Int(sqrt(Float(r * r - dy * dy)))
            span(p, yy * w, cx - hw, cx + hw + 1, c)
        }
    }

    private func hillLayer(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ table: [Int], _ shift: Int, _ hzI: Int,
                           _ colr: UInt32, _ cap: UInt32, _ capH: Int) {
        for x in 0..<w {
            let hgt = table[(x + shift) & 511]
            let top = hzI - hgt
            let y0 = max(0, top)
            if y0 >= hzI { continue }
            for yy in y0..<hzI {
                p[yy * w + x] = (yy - top) < capH ? cap : colr
            }
        }
    }

    private func skylineLayer(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ shift: Int, _ hzI: Int,
                              _ colr: UInt32, _ hscale: Int, _ lit: Bool) {
        let sk = TurboFox64.skyline
        let wc0 = TurboFox64.col(255, 236, 110)
        let wc1 = TurboFox64.col(120, 255, 240)
        let wc2 = TurboFox64.col(255, 120, 220)
        for x in 0..<w {
            let wx = (x + shift) & 511
            let hgt = (sk[wx] * hscale) / 4 + 6
            let top = hzI - hgt
            let y0 = max(0, top)
            if y0 >= hzI { continue }
            for yy in y0..<hzI {
                var cc = colr
                if lit && (wx & 3) != 3 && (yy & 3) != 3 && yy > top + 2 {
                    let key = (wx >> 2) * 7 + (yy >> 2) * 13 + (wx >> 3) * 3
                    if (key & 7) == 0 {
                        let sel = (wx >> 3) % 3
                        cc = sel == 0 ? wc0 : (sel == 1 ? wc1 : wc2)
                    }
                }
                p[yy * w + x] = cc
            }
        }
    }

    private func renderBackground(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        let th = TurboFox64.themes[theme]
        let rows = TurboFox64.skyRows[theme]
        let hzI = 104
        for y in 0..<min(h, hzI) {
            span(p, y * w, 0, w, rows[min(119, y)])
        }
        let haze = TurboFox64.rgbOf(th.haze)
        if hzI < h {
            for y in hzI..<h { span(p, y * w, 0, w, haze) }
        }
        let farShift: Int = Int(bgOff * 0.4)
        let nearShift: Int = Int(bgOff * 0.8)
        let skyShift: Int = Int(bgOff * 0.1)
        if theme == 0 {
            let sx: Int = (((260 - skyShift) % 512) + 512) % 512 - 100
            discSpan(p, w, h, sx, 30, 26, TurboFox64.col(255, 252, 214))
            discSpan(p, w, h, sx, 30, 18, TurboFox64.col(255, 240, 150))
            drawClouds(p, w, h, TurboFox64.col(255, 255, 255), Int(bgOff * 0.2))
            hillLayer(p, w, TurboFox64.farHill, farShift, hzI, TurboFox64.col(130, 205, 170), 0, 0)
            hillLayer(p, w, TurboFox64.nearHill, nearShift, hzI, TurboFox64.col(60, 170, 80), TurboFox64.col(110, 220, 100), 2)
        } else if theme == 1 {
            let star = TurboFox64.col(255, 255, 255)
            for i in 0..<40 {
                let sxp: Int = (((TurboFox64.starX[i] - skyShift) % 512) + 512) % 512
                if sxp >= w { continue }
                let syp = TurboFox64.starY[i]
                if ((frame / 12 + i) % 7) == 0 { continue }
                p[syp * w + sxp] = star
            }
            let mx: Int = (((300 - skyShift) % 512) + 512) % 512 - 100
            discSpan(p, w, h, mx, 34, 15, TurboFox64.col(255, 246, 200))
            discSpan(p, w, h, mx + 5, 31, 12, TurboFox64.col(40, 20, 90))
            skylineLayer(p, w, farShift + 200, hzI, TurboFox64.col(70, 36, 130), 3, false)
            skylineLayer(p, w, nearShift, hzI, TurboFox64.col(30, 16, 70), 4, true)
            span(p, (hzI - 1) * w, 0, w, TurboFox64.col(255, 80, 210))
        } else {
            drawRainbow(p, w, h, hzI, 210 - skyShift / 2)
            drawClouds(p, w, h, TurboFox64.col(255, 244, 250), Int(bgOff * 0.2))
            hillLayer(p, w, TurboFox64.farHill, farShift, hzI, TurboFox64.col(255, 176, 206), TurboFox64.col(255, 240, 246), 3)
            hillLayer(p, w, TurboFox64.nearHill, nearShift, hzI, TurboFox64.col(130, 226, 196), TurboFox64.col(255, 250, 240), 2)
        }
    }

    private static func rgbOf(_ a: [Int]) -> UInt32 {
        if a.count < 3 { return 0xFF00_0000 }
        return TrueColorBuffer.rgb(a[0], a[1], a[2])
    }

    private func drawClouds(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ colr: UInt32, _ shift: Int) {
        let cloudX: [Int] = [20, 130, 260, 350, 450]
        let cloudY: [Int] = [22, 46, 14, 52, 32]
        for i in 0..<5 {
            let cx0: Int = (((cloudX[i] - shift) % 512) + 512) % 512 - 100
            let cy0 = cloudY[i]
            discSpan(p, w, h, cx0, cy0, 7, colr)
            discSpan(p, w, h, cx0 + 10, cy0 + 2, 6, colr)
            discSpan(p, w, h, cx0 - 10, cy0 + 3, 5, colr)
            if cy0 + 6 < h && cy0 + 6 >= 0 { span(p, (cy0 + 6) * w, cx0 - 14, cx0 + 16, colr) }
        }
    }

    private func drawRainbow(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ hzI: Int, _ cxR: Int) {
        let bands: [UInt32] = [
            TurboFox64.col(255, 90, 110), TurboFox64.col(255, 170, 80), TurboFox64.col(255, 235, 110),
            TurboFox64.col(120, 230, 140), TurboFox64.col(100, 190, 255), TurboFox64.col(190, 140, 255)
        ]
        let cyR = hzI + 40
        for x in 0..<w {
            let ddx: Float = Float(x - cxR)
            for bnd in 0..<6 {
                let r: Float = Float(150 - bnd * 5)
                let v: Float = r * r - ddx * ddx
                if v <= 0 { continue }
                let yTop: Int = cyR - Int(sqrt(v))
                for k in 0..<5 {
                    let yy = yTop + k
                    if yy < 0 || yy >= hzI { continue }
                    p[yy * w + x] = bands[bnd]
                }
            }
        }
    }

    private func renderStrips(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        let c = course
        let th = TurboFox64.themes[theme]
        let roadW = TurboFox64.roadW
        let hr = th.haze[0]
        let hg = th.haze[1]
        let hb = th.haze[2]
        let rampA = TurboFox64.col(255, 200, 60)
        let rampB = TurboFox64.col(236, 140, 30)
        let dashA = TurboFox64.col(255, 240, 70)
        let dashB = TurboFox64.col(255, 130, 30)
        let railB = TurboFox64.col(250, 250, 255)
        let white = TurboFox64.cWhite
        let black = TurboFox64.col(20, 20, 26)
        var n = TurboFox64.drawN - 1
        while n >= 0 {
            defer { n -= 1 }
            if !gDrawn[n] { continue }
            let idx = geoBase + n
            if idx < 0 || idx >= c.total { continue }
            let y1 = gY1[n]
            let y2 = gY2[n]
            let bot = gBot[n]
            let cx1 = gCX1[n]
            let cx2 = gCX2[n]
            let hw1: Float = gP1[n] * roadW
            let hw2: Float = gP2[n] * roadW
            let fg = TurboFox64.fogAmount(gZ1[n])
            let alt = ((idx / 2) & 1) == 0
            let dk = c.decal[idx]
            let gA = TurboFox64.blend(th.groundA, hr, hg, hb, fg)
            let gB = TurboFox64.blend(th.groundB, hr, hg, hb, fg)
            var roadC = alt ? th.roadA : th.roadB
            if dk == 3 { roadC = alt ? rampA : rampB }
            let road = TurboFox64.blend(roadC, hr, hg, hb, fg)
            let edge = TurboFox64.blend(alt ? th.edgeA : th.edgeB, hr, hg, hb, fg)
            let line = TurboFox64.blend(th.lane, hr, hg, hb, fg)
            var dc: UInt32 = 0
            if dk == 1 { dc = TurboFox64.blend(alt ? dashA : dashB, hr, hg, hb, fg) }
            let railC = TurboFox64.blend(alt ? th.rail : railB, hr, hg, hb, fg)
            let finW = TurboFox64.blend(white, hr, hg, hb, fg)
            let finB = TurboFox64.blend(black, hr, hg, hb, fg)
            let dOff = c.decalOff[idx]
            let dHalf = c.decalHalf[idx]
            let yt: Float = max(0, y2)
            let r0 = Int(yt)
            let r1 = min(h, Int(bot))
            if r0 >= r1 { continue }
            let invD: Float = 1.0 / max(0.001, y1 - y2)
            let bandBit: Int = alt ? 0 : 1
            var r = r0
            while r < r1 {
                let t: Float = (Float(r) - y2) * invD
                let cx: Float = cx2 + (cx1 - cx2) * t
                let hw: Float = hw2 + (hw1 - hw2) * t
                let xl = Int(clamp(cx - hw, -2000, 2000))
                let xr = Int(clamp(cx + hw, -2000, 2000))
                let base = r * w
                var tw = Int(hw * 1.5)
                if tw < 14 { tw = 14 }
                var k = 0
                var xe = xl
                while xe > 0 && k < 30 {
                    let xs2 = xe - tw
                    span(p, base, xs2, xe, ((k + bandBit) & 1) == 0 ? gA : gB)
                    xe = xs2
                    k += 1
                }
                if xe > 0 { span(p, base, 0, xe, gB) }
                k = 0
                var xb = xr
                while xb < w && k < 30 {
                    let xe2 = xb + tw
                    span(p, base, xb, xe2, ((k + bandBit) & 1) == 0 ? gA : gB)
                    xb = xe2
                    k += 1
                }
                if xb < w { span(p, base, xb, w, gB) }
                var ew = Int(hw * 0.07)
                if ew < 1 { ew = 1 }
                span(p, base, xl, xl + ew, edge)
                span(p, base, xr - ew, xr, edge)
                span(p, base, xl + ew, xr - ew, road)
                if dc != 0 {
                    let dl = Int(clamp(cx + hw * (dOff - dHalf), -2000, 2000))
                    let dr = Int(clamp(cx + hw * (dOff + dHalf), -2000, 2000))
                    span(p, base, max(dl, xl + ew), min(dr, xr - ew), dc)
                }
                if dk == 4 {
                    let cellW = max(1, (xr - xl) / 8)
                    for q in 0..<8 {
                        let cc = ((q + idx) & 1) == 0 ? finW : finB
                        span(p, base, xl + q * cellW, xl + (q + 1) * cellW, cc)
                    }
                }
                if dk == 2 && hw > 6 {
                    let rx = Int(clamp(cx + hw * dOff, -2000, 2000))
                    var rw = Int(hw * 0.05)
                    if rw < 1 { rw = 1 }
                    span(p, base, rx - rw, rx + rw, railC)
                }
                if alt && dk != 3 && dk != 4 && hw > 10 {
                    var lw = Int(hw * 0.012)
                    if lw < 1 { lw = 1 }
                    let ca = Int(cx - hw * 0.333)
                    let cb = Int(cx + hw * 0.333)
                    span(p, base, ca - lw, ca + lw, line)
                    span(p, base, cb - lw, cb + lw, line)
                }
                r += 1
            }
        }
    }

    private func blit(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ spr: SpriteImg,
                      _ cxIn: Float, _ bottomIn: Float, _ ppu: Float, _ clipY: Int, _ fog: Int) {
        let dwF: Float = ppu * spr.worldW
        if !(dwF >= 2) || dwF > 1400 { return }
        let dw = Int(dwF)
        let dh = max(1, dw * spr.h / spr.w)
        let bottom = Int(clamp(bottomIn, -3000, 3000))
        let cxc = Int(clamp(cxIn, -3000, 3000))
        let x0 = cxc - dw / 2
        let y0 = bottom - dh
        let yStart = max(0, y0)
        let yEnd = min(min(h, bottom), clipY)
        if yStart >= yEnd { return }
        let stepY = (spr.h << 16) / dh
        let stepX = (spr.w << 16) / dw
        let sprW = spr.w
        let sprH = spr.h
        let xs = max(0, x0)
        let xe = min(w, x0 + dw)
        if xs >= xe { return }
        let th = TurboFox64.themes[theme]
        let hr = th.haze[0]
        let hg = th.haze[1]
        let hb = th.haze[2]
        spr.pix.withUnsafeBufferPointer { sp in
            for y in yStart..<yEnd {
                let ry = y - y0
                let sy = max(0, min(sprH - 1, (ry * stepY) >> 16))
                let srow = sy * sprW
                let rowBase = y * w
                for x in xs..<xe {
                    let sxp = max(0, min(sprW - 1, ((x - x0) * stepX) >> 16))
                    let cc = sp[srow + sxp]
                    if cc != 0 {
                        if fog > 0 {
                            p[rowBase + x] = TurboFox64.blend(cc, hr, hg, hb, fog)
                        } else {
                            p[rowBase + x] = cc
                        }
                    }
                }
            }
        }
    }

    private func renderSprites(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        let c = course
        let sprs = TurboFox64.sets[theme]
        let rf = TurboFox64.ringFrames
        let roadW = TurboFox64.roadW
        lockSX = -100
        lockSY = -100
        tapTargets.removeAll()
        var n = TurboFox64.drawN - 1
        while n >= 0 {
            defer { n -= 1 }
            if !gOK[n] { continue }
            let idx = geoBase + n
            if idx < 0 || idx >= c.total { continue }
            let clip = Int(clamp(gClip[n], -1000, 1000))
            let fog = TurboFox64.fogAmount(gZ1[n])
            let cnt = c.sprites[idx].count
            if cnt == 0 { continue }
            for j in 0..<cnt {
                let s = c.sprites[idx][j]
                if s.taken { continue }
                if s.kind < 0 || s.kind >= sprs.count { continue }
                let cx: Float = gCX1[n] + gP1[n] * s.off * roadW
                let by: Float = gY1[n] - gP1[n] * s.h
                if s.kind == TurboFox64.kRing {
                    let fi = ((frame / 5) + idx) & 3
                    blit(p, w, h, rf[fi], cx, by, gP1[n], clip, fog)
                } else {
                    blit(p, w, h, sprs[s.kind], cx, by, gP1[n], clip, fog)
                }
                if (s.kind == TurboFox64.kEnemy || s.kind == TurboFox64.kFly || s.kind == TurboFox64.kSpring) && tapTargets.count < 16 {
                    let tsx = Int(clamp(cx, -500, 800))
                    let tsy = Int(clamp(by - gP1[n] * 200, -500, 800))
                    tapTargets.append(TapT(seg: idx, idx: j, sx: tsx, sy: tsy))
                }
                if idx == lockSeg && j == lockIdx {
                    let hh: Float = gP1[n] * 200 + gP1[n] * s.h
                    lockSX = Int(clamp(cx, -500, 800))
                    lockSY = Int(clamp(gY1[n] - hh, -500, 800))
                }
            }
        }
    }

    private func applyFlash(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        let amt = min(160, flash * 28)
        if amt <= 0 { return }
        let total = w * h
        var i = 0
        while i < total {
            p[i] = TurboFox64.blend(p[i], flashR, flashG, flashB, amt)
            i += 1
        }
    }

    override func drawTrueColor(_ b: TrueColorBuffer) {
        buildGeometry()
        b.withPixels { p, w, h in
            if w != 320 || h != 288 { return }
            self.renderBackground(p, w, h)
            self.renderStrips(p, w, h)
            self.renderSprites(p, w, h)
            if self.flash > 0 { self.applyFlash(p, w, h) }
        }
        drawSpeedLines(b)
        drawPlayer(b)
        drawParticles(b)
        drawReticle(b)
        drawHUD(b)
        drawOverlays(b)
    }

    // MARK: - Effects

    private func drawSpeedLines(_ b: TrueColorBuffer) {
        if phase != .run && phase != .clear { return }
        var strength = 0
        if boosting { strength = 16 } else if padTimer > 0 { strength = 12 } else if speed > 1.25 { strength = 7 }
        if strength == 0 { return }
        let colr: UInt32 = boosting ? TurboFox64.cCyan : TurboFox64.cWhite
        let vx: Float = 160
        let vyy: Float = 130
        for i in 0..<strength {
            let ci = i & 15
            let phaseN: Int = (frame * 9 + i * 53) % 100
            let r0: Float = 60 + Float(phaseN) * 1.6
            for s in 0..<3 {
                let rr: Float = r0 + Float(s) * 7
                let x = Int(vx + TurboFox64.rayCos[ci] * rr)
                let y = Int(vyy + TurboFox64.raySin[ci] * rr)
                if x < 0 || x > 318 || y < 0 || y > 286 { continue }
                b.fillRect(x, y, 2, 2, colr)
            }
        }
    }

    private func drawParticles(_ b: TrueColorBuffer) {
        for pt in parts {
            let x = Int(clamp(pt.x, -50, 400))
            let y = Int(clamp(pt.y, -50, 400))
            b.fillRect(x, y, pt.size, pt.size, pt.c)
        }
        for t in texts {
            let x = Int(clamp(t.x, -50, 400))
            let y = Int(clamp(t.y, -50, 400))
            let tw = b.textWidth(t.text, scale: 1)
            otext(b, t.text, x - tw / 2, y, t.c, 1)
        }
    }

    private func drawReticle(_ b: TrueColorBuffer) {
        if lockSeg < 0 || lockSX < -50 || lockSX > 370 || lockSY < -20 || lockSY > 300 { return }
        if (frame / 4) & 1 == 0 { return }
        let x = lockSX
        let y = lockSY
        let c = TurboFox64.cRed
        let wc = TurboFox64.cWhite
        b.fillRect(x - 14, y - 14, 8, 2, c)
        b.fillRect(x - 14, y - 14, 2, 8, c)
        b.fillRect(x + 6, y - 14, 8, 2, c)
        b.fillRect(x + 12, y - 14, 2, 8, c)
        b.fillRect(x - 14, y + 12, 8, 2, c)
        b.fillRect(x - 14, y + 6, 2, 8, c)
        b.fillRect(x + 6, y + 12, 8, 2, c)
        b.fillRect(x + 12, y + 6, 2, 8, c)
        otext(b, "A!", x - 4, y - 26, wc, 1)
    }

    // MARK: - Fox

    private func discRows(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int, _ r: Int, _ colr: UInt32) {
        if r <= 0 { return }
        for dy in -r...r {
            let hw = Int(sqrt(Float(r * r - dy * dy)))
            b.fillRect(cx - hw, cy + dy, hw * 2 + 1, 1, colr)
        }
    }

    private func drawBall(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int, _ r: Int, _ spin: Float) {
        discRows(b, cx, cy, r + 1, TurboFox64.cOutl)
        discRows(b, cx, cy, r, TurboFox64.cFox)
        discRows(b, cx, cy + r / 3, r * 2 / 3, TurboFox64.cCream)
        for k in 0..<3 {
            let a: Float = spin + Float(k) * 2.094
            let px = cx + Int(cos(a) * Float(r) * 0.65)
            let pyy = cy + Int(sin(a) * Float(r) * 0.65)
            b.fillRect(px - 1, pyy - 1, 3, 3, TurboFox64.cFoxD)
        }
        let ea: Float = spin + 0.6
        let ex = cx + Int(cos(ea) * Float(r + 2))
        let ey = cy + Int(sin(ea) * Float(r + 2))
        b.fillRect(ex - 2, ey - 2, 4, 4, TurboFox64.cFox)
        let ta: Float = spin + 3.6
        let tx = cx + Int(cos(ta) * Float(r + 4))
        let ty = cy + Int(sin(ta) * Float(r + 4))
        b.fillRect(tx - 3, ty - 3, 6, 6, TurboFox64.cCream)
    }

    private func drawFoxRun(_ b: TrueColorBuffer, _ cx: Int, _ fy: Int) {
        let ph: Float = runPhase
        let sn: Float = sin(ph)
        let bob = Int(abs(sn) * 2.0)
        let leanY = boosting ? 2 : 0
        let legTop = fy - 12 - bob
        let bodyTop = legTop - 13 + leanY
        let headTop = bodyTop - 12
        let orange = TurboFox64.cFox
        let orangeD = TurboFox64.cFoxD
        let cream = TurboFox64.cCream
        let outl = TurboFox64.cOutl
        // tail (behind)
        for pass in 0..<2 {
            for k in 0..<6 {
                let kf: Float = Float(k)
                let sw: Float = sin(ph * 0.7 + kf * 0.6) * 3.0
                let tx = cx + 5 + k * 3
                let ty = legTop - 8 - k * 2 + Int(sw)
                if pass == 0 {
                    b.fillRect(tx - 1, ty - 1, 8, 8, outl)
                } else {
                    let tc: UInt32 = k >= 4 ? cream : orange
                    b.fillRect(tx, ty, 6, 6, tc)
                }
            }
        }
        // legs and shoes
        for side in 0..<2 {
            let sgn = side == 0 ? -1 : 1
            let swing: Float = side == 0 ? sn : -sn
            let lift = Int(max(0, swing) * 5.0)
            let lx = cx + sgn * 5 - 3
            let shoeY = fy - 4 - lift
            let legH = shoeY - legTop
            if legH > 0 { b.fillRect(lx + 1, legTop, 4, legH, orangeD) }
            b.fillRect(lx - 1, shoeY - 1, 9, 6, outl)
            b.fillRect(lx, shoeY, 7, 4, TurboFox64.cShoe)
            b.fillRect(lx, shoeY + 3, 7, 1, TurboFox64.cWhite)
        }
        // body
        b.fillRect(cx - 8, bodyTop - 1, 16, 15, outl)
        b.fillRect(cx - 7, bodyTop, 14, 13, orange)
        b.fillRect(cx - 1, bodyTop, 2, 13, orangeD)
        // arms
        let armSwing = Int(sn * 3.0)
        b.fillRect(cx - 10, bodyTop + 3 + armSwing, 3, 8, orangeD)
        b.fillRect(cx + 7, bodyTop + 3 - armSwing, 3, 8, orangeD)
        // scarf
        b.fillRect(cx - 8, bodyTop - 1, 16, 3, TurboFox64.cScarf)
        for k in 0..<4 {
            let kf: Float = Float(k)
            let sy2 = Int(sin(ph * 1.5 + kf) * 2.0)
            b.fillRect(cx + 8 + k * 3, bodyTop + sy2 - k, 4, 3, k & 1 == 0 ? TurboFox64.cScarfD : TurboFox64.cScarf)
        }
        // head
        b.fillRect(cx - 8, headTop + 2, 16, 10, outl)
        b.fillRect(cx - 7, headTop - 1, 14, 2, outl)
        b.fillRect(cx - 7, headTop + 2, 14, 9, orange)
        b.fillRect(cx - 6, headTop, 12, 3, orange)
        let flutter = (frame / 4) & 1
        for side in 0..<2 {
            let ex = side == 0 ? cx - 8 : cx + 4
            b.fillRect(ex - 1, headTop - 5 - flutter, 6, 7, outl)
            b.fillRect(ex, headTop - 4 - flutter, 4, 6, orange)
            b.fillRect(ex + 1, headTop - 2 - flutter, 2, 3, orangeD)
        }
        b.fillRect(cx - 7, headTop + 5, 14, 2, TurboFox64.cStrap)
        b.fillRect(cx - 9, headTop + 4, 3, 4, TurboFox64.cCyan)
        b.fillRect(cx + 6, headTop + 4, 3, 4, TurboFox64.cCyan)
        b.fillRect(cx - 9, headTop + 4, 1, 1, TurboFox64.cWhite)
        b.fillRect(cx + 6, headTop + 4, 1, 1, TurboFox64.cWhite)
        b.fillRect(cx - 8, headTop + 8, 2, 3, cream)
        b.fillRect(cx + 6, headTop + 8, 2, 3, cream)
    }

    private func drawPlayer(_ b: TrueColorBuffer) {
        let th = TurboFox64.themes[theme]
        let cx = foxScreenX()
        let fy = foxScreenY(py)
        let gy = foxScreenY(groundNow)
        let air = max(0, gy - fy)
        let sw = max(10, 28 - air / 5)
        b.fillRect(cx - sw / 2, gy - 1, sw, 3, th.shadow)
        b.fillRect(cx - sw / 2 + 3, gy - 2, max(2, sw - 6), 1, th.shadow)
        if phase == .over { return }
        let flick: Bool = ((frame / 3) & 1) == 0
        if invuln > 0 && hurtTimer <= 0 && flick && phase == .run { return }
        if hurtTimer > 0 {
            let spin: Float = Float(hurtTimer) * 0.5
            drawBall(b, cx, fy - 14, 11, spin)
            for i in 0..<3 {
                let a: Float = spin * 1.3 + Float(i) * 2.1
                let sx = cx + Int(cos(a) * 20)
                let sy = fy - 38 + Int(sin(a) * 5)
                b.fillRect(sx - 2, sy, 5, 1, TurboFox64.cYellow)
                b.fillRect(sx, sy - 2, 1, 5, TurboFox64.cYellow)
            }
            return
        }
        if homing {
            let spin: Float = Float(frame) * 0.9
            for k in 1..<5 {
                b.fillRect(cx - 2, fy - 14 + k * 5, 4, 3, TurboFox64.cCyan)
            }
            drawBall(b, cx, fy - 14, 10, spin)
            return
        }
        if grinding {
            b.fillRect(cx - 8, fy - 3, 16, 3, TurboFox64.cShoe)
            for i in 0..<3 {
                let jx = cx - 6 + ((frame * 5 + i * 7) % 12)
                b.fillRect(jx, fy - 1 + (i & 1), 2, 2, TurboFox64.cYellow)
            }
            drawFoxRunLow(b, cx, fy - 4)
            return
        }
        if !grounded {
            let spin: Float = Float(airFrames) * (jumpsUsed >= 2 ? 0.6 : 0.4)
            drawBall(b, cx, fy - 14, 11, spin)
            if boosting {
                b.fillRect(cx - 12, fy - 2, 3, 8, TurboFox64.cCyan)
                b.fillRect(cx + 10, fy - 2, 3, 8, TurboFox64.cCyan)
            }
            return
        }
        if boosting {
            b.fillRect(cx - 13, fy - 30, 2, 14, TurboFox64.cCyan)
            b.fillRect(cx + 12, fy - 26, 2, 14, TurboFox64.cCyan)
            b.fillRect(cx - 16, fy - 20, 2, 10, TurboFox64.cWhite)
            b.fillRect(cx + 15, fy - 36, 2, 10, TurboFox64.cWhite)
        }
        drawFoxRun(b, cx, fy)
    }

    private func drawFoxRunLow(_ b: TrueColorBuffer, _ cx: Int, _ fy: Int) {
        let orange = TurboFox64.cFox
        let outl = TurboFox64.cOutl
        b.fillRect(cx - 8, fy - 22, 16, 18, outl)
        b.fillRect(cx - 7, fy - 21, 14, 16, orange)
        b.fillRect(cx - 1, fy - 21, 2, 16, TurboFox64.cFoxD)
        b.fillRect(cx - 8, fy - 22, 16, 3, TurboFox64.cScarf)
        b.fillRect(cx - 8, fy - 33, 16, 12, outl)
        b.fillRect(cx - 7, fy - 32, 14, 10, orange)
        b.fillRect(cx - 7, fy - 28, 14, 2, TurboFox64.cStrap)
        b.fillRect(cx - 8, fy - 38, 5, 7, outl)
        b.fillRect(cx + 3, fy - 38, 5, 7, outl)
        b.fillRect(cx - 7, fy - 37, 3, 6, orange)
        b.fillRect(cx + 4, fy - 37, 3, 6, orange)
        b.fillRect(cx + 7, fy - 18, 10, 8, TurboFox64.cCream)
        b.fillRect(cx - 9, fy - 14, 3, 6, TurboFox64.cFoxD)
        b.fillRect(cx + 7, fy - 14, 3, 6, TurboFox64.cFoxD)
    }

    // MARK: - HUD

    private func otext(_ b: TrueColorBuffer, _ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        let k = max(1, scale / 2)
        let o = TurboFox64.cBlack
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

    private func panel(_ b: TrueColorBuffer, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        b.fillRect(x - 2, y - 2, w + 4, h + 4, TurboFox64.cBlack)
        b.fillRect(x, y, w, h, TurboFox64.cPanel)
        b.fillRect(x, y, w, 3, TurboFox64.cYellow)
        b.fillRect(x, y + h - 3, w, 3, TurboFox64.cYellow)
    }

    private func drawRingIcon(_ b: TrueColorBuffer, _ x: Int, _ y: Int) {
        let gold = TurboFox64.cGold
        for dy in 0..<11 {
            let dyc: Float = Float(dy) - 5.0
            let o2: Float = 30.0 - dyc * dyc
            if o2 <= 0 { continue }
            let ho: Int = Int(sqrt(o2))
            let i2: Float = 7.0 - dyc * dyc
            if i2 > 0 {
                let hi: Int = Int(sqrt(i2))
                b.fillRect(x + 5 - ho, y + dy, ho - hi, 1, gold)
                b.fillRect(x + 6 + hi, y + dy, ho - hi, 1, gold)
            } else {
                b.fillRect(x + 5 - ho, y + dy, ho * 2 + 1, 1, gold)
            }
        }
        b.fillRect(x + 1, y + 3, 1, 3, TurboFox64.cWhite)
    }

    private func drawFoxIcon(_ b: TrueColorBuffer, _ x: Int, _ y: Int) {
        b.fillRect(x - 1, y - 1, 13, 11, TurboFox64.cBlack)
        b.fillRect(x, y + 2, 11, 7, TurboFox64.cFox)
        b.fillRect(x, y, 3, 3, TurboFox64.cFox)
        b.fillRect(x + 8, y, 3, 3, TurboFox64.cFox)
        b.fillRect(x + 3, y + 6, 5, 3, TurboFox64.cCream)
        b.fillRect(x + 2, y + 4, 2, 2, TurboFox64.cBlack)
        b.fillRect(x + 7, y + 4, 2, 2, TurboFox64.cBlack)
    }

    private func drawStar(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int, _ r: Int, _ colr: UInt32) {
        if r <= 0 { return }
        for dy in -r...r {
            let m: Int = r - abs(dy)
            var half: Int = (m * m) / r
            if abs(dy) < 2 { half += 1 }
            if m > r / 2 { half += 1 }
            b.fillRect(cx - half, cy + dy, half * 2 + 1, 1, colr)
        }
    }

    private func rankColor(_ r: Int) -> UInt32 {
        if r >= 3 { return TurboFox64.cGold }
        if r == 2 { return TurboFox64.cGreen }
        if r == 1 { return TurboFox64.cCyan }
        return TurboFox64.cWhite
    }

    private func rankLetter(_ r: Int) -> String {
        if r >= 3 { return "S" }
        if r == 2 { return "A" }
        if r == 1 { return "B" }
        return "C"
    }

    private func drawHUD(_ b: TrueColorBuffer) {
        if phase == .title || phase == .final { return }
        let white = TurboFox64.cWhite
        let yellow = TurboFox64.cYellow
        let th = TurboFox64.themes[theme]
        // rings
        drawRingIcon(b, 6, 7)
        otext(b, zeroPad(rings, 3), 22, 5, yellow, 3)
        // lives
        for i in 0..<lives {
            drawFoxIcon(b, 7 + i * 15, 28)
        }
        // score
        let sc = zeroPad(score, 6)
        let sw = b.textWidth(sc, scale: 2)
        otext(b, "SCORE", 312 - b.textWidth("SCORE", scale: 1), 5, white, 1)
        otext(b, sc, 312 - sw, 13, white, 2)
        // stage name
        let nm = th.name
        let nw = b.textWidth(nm, scale: 1)
        otext(b, nm, 160 - nw / 2, 5, th.accent, 1)
        // combo
        if combo > 1 && phase == .run {
            let ct = "COMBO X" + String(combo)
            let cw = b.textWidth(ct, scale: 2)
            otext(b, ct, 312 - cw, 34, TurboFox64.cOrange, 2)
        }
        // boost meter
        let bx = 70
        let bw = 180
        let by = 264
        b.fillRect(bx - 2, by - 2, bw + 4, 14, TurboFox64.cBlack)
        b.fillRect(bx, by, bw, 10, TurboFox64.col(40, 50, 90))
        let frac: Float = clamp(boostMeter / 100, 0, 1)
        let fw = Int(frac * Float(bw))
        var bc = TurboFox64.cCyan
        if boosting { bc = (frame & 2) == 0 ? white : TurboFox64.cCyan }
        if fw > 0 { b.fillRect(bx, by, fw, 10, bc) }
        b.fillRect(bx, by + 1, max(0, fw), 2, TurboFox64.col(200, 250, 255))
        let label = frac > 0.99 ? "B BOOST READY" : "B BOOST"
        let lw = b.textWidth(label, scale: 1)
        otext(b, label, bx + (bw - lw) / 2, by + 2, white, 1)
        // progress bar
        let barX = 40
        let barW = 240
        let barY = 281
        b.fillRect(barX - 1, barY - 1, barW + 2, 6, TurboFox64.cBlack)
        b.fillRect(barX, barY, barW, 4, TurboFox64.col(50, 60, 90))
        let seg = TurboFox64.segLen
        let playerSeg: Float = (pos + TurboFox64.playerDist) / seg
        let prog: Float = clamp(playerSeg / Float(max(1, course.segs)), 0, 1)
        let pw = Int(prog * Float(barW))
        if pw > 0 { b.fillRect(barX, barY, pw, 4, TurboFox64.cGreen) }
        for k in 1...2 {
            let tx = barX + barW * k / 3
            b.fillRect(tx, barY - 2, 2, 8, k <= cpIndex ? TurboFox64.cGreen : yellow)
        }
        b.fillRect(barX + pw - 1, barY - 2, 4, 8, white)
        // messages
        if (phase == .run || phase == .clear) && msgTimer > 0 {
            ctext(b, msg, 64, msgColor, 3)
        }
        // hints
        if phase == .run && stage == 0 && stageFrames < 260 {
            ctext(b, "TOUCH TO STEER   TAP TO JUMP", 232, white, 1)
            ctext(b, "TAP IN THE AIR TO ATTACK", 244, yellow, 1)
        }
    }

    private func drawOverlays(_ b: TrueColorBuffer) {
        let yellow = TurboFox64.cYellow
        let white = TurboFox64.cWhite
        let th = TurboFox64.themes[theme]
        switch phase {
        case .title:
            panel(b, 24, 34, 272, 170)
            ctext(b, "TURBO FOX", 46, TurboFox64.cOrange, 5)
            ctext(b, "64", 84, yellow, 8)
            ctext(b, "RINGS  ROBOTS  RAILS  BOOST", 132, TurboFox64.cCyan, 1)
            if (frame / 30) & 1 == 0 { ctext(b, "PRESS A TO RUN", 150, TurboFox64.cGreen, 3) }
            ctext(b, "LEFT RIGHT STEER   A JUMP", 176, white, 1)
            ctext(b, "A AGAIN IN AIR: HOMING ATTACK", 186, white, 1)
            ctext(b, "B BOOST  OR HOLD LOWER SCREEN", 196, white, 1)
            ctext(b, "TOUCH: DRAG TO STEER  TAP JUMP", 206, white, 1)
        case .ready:
            ctext(b, "STAGE " + String(stage + 1), 40, white, 4)
            ctext(b, th.name, 76, th.accent, 3)
            if cdTimer > 150 {
                ctext(b, "GET READY", 110, yellow, 4)
            } else if cdTimer > 0 {
                let d = (cdTimer + 49) / 50
                ctext(b, String(d), 104, yellow, 10)
            }
            if stage == 0 { ctext(b, "COLLECT RINGS  BASH ROBOTS", 200, white, 1) }
        case .run:
            break
        case .clear:
            break
        case .results:
            panel(b, 38, 30, 244, 222)
            ctext(b, "STAGE CLEAR", 40, TurboFox64.cGreen, 4)
            ctext(b, th.name, 66, th.accent, 2)
            let r = ranks[stage]
            let rc = rankColor(r)
            b.fillRect(130, 84, 60, 60, TurboFox64.cBlack)
            b.fillRect(132, 86, 56, 56, rc)
            b.fillRect(134, 88, 52, 52, TurboFox64.cPanel)
            ctext(b, rankLetter(r), 92, rc, 6)
            let stars = r >= 2 ? 3 : (r + 1)
            for i in 0..<3 {
                let sx = 120 + i * 40
                let on = i < stars
                drawStar(b, sx, 160, 9, on ? TurboFox64.cGold : TurboFox64.col(50, 60, 100))
            }
            ctext(b, "RINGS " + String(stageRings) + "/" + String(course.ringTotal), 178, white, 2)
            ctext(b, "ROBOTS " + String(stageBash) + "/" + String(course.enemyTotal), 196, white, 2)
            ctext(b, "SCORE " + zeroPad(score, 6), 214, yellow, 2)
            if resultTimer > 45 && (frame / 30) & 1 == 0 {
                ctext(b, stage < 2 ? "PRESS A FOR NEXT STAGE" : "PRESS A", 236, TurboFox64.cGreen, 1)
            }
        case .over:
            panel(b, 44, 70, 232, 130)
            ctext(b, "GAME OVER", 82, TurboFox64.cRed, 5)
            ctext(b, "SCORE " + zeroPad(score, 6), 124, white, 2)
            ctext(b, "STAGE " + String(stage + 1) + "  RINGS " + String(totalRings), 146, TurboFox64.cCyan, 1)
            if resultTimer > 30 && (frame / 30) & 1 == 0 {
                ctext(b, "A TRY AGAIN FROM CHECKPOINT", 166, TurboFox64.cGreen, 1)
                ctext(b, "START NEW GAME", 180, white, 1)
            }
        case .final:
            panel(b, 28, 24, 264, 240)
            ctext(b, "ALL STAGES DONE", 36, TurboFox64.cGreen, 3)
            var sum = 0
            for i in 0..<3 { sum += ranks[i] }
            let overall = min(3, (sum + 1) / 3)
            let oc = rankColor(overall)
            b.fillRect(130, 64, 60, 56, TurboFox64.cBlack)
            b.fillRect(132, 66, 56, 52, oc)
            b.fillRect(134, 68, 52, 48, TurboFox64.cPanel)
            ctext(b, rankLetter(overall), 70, oc, 6)
            for i in 0..<3 {
                let nm = TurboFox64.themes[i].name + "  " + rankLetter(ranks[i])
                ctext(b, nm, 130 + i * 16, rankColor(ranks[i]), 2)
            }
            ctext(b, "TOTAL RINGS " + String(totalRings), 184, yellow, 2)
            ctext(b, "SCORE " + zeroPad(score, 6), 204, white, 3)
            if resultTimer > 60 && (frame / 30) & 1 == 0 {
                ctext(b, "PRESS A TO PLAY AGAIN", 240, TurboFox64.cGreen, 1)
            }
        }
    }
}

extension Cartridge {
    static let turboFox64 = Cartridge(
        id: "turbofox64", title: "TURBO FOX 64", genre: "Runner",
        blurb: "Race an orange fox down a loop-the-loop of rolling tracks. Grab rings, bounce on robots with the homing attack, grind rails and boost through three stages.",
        controls: "LEFT/RIGHT steer, A jump (press A again in the air to attack), B boost.",
        era: .n64, labelTop: 0xFF9A2E, labelBottom: 0x2A5BD7, factory: { TurboFox64() })
}
