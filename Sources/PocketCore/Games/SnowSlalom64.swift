#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// SNOW SLALOM 64: an OutRun style pseudo-3D downhill snowboard racer. The course is a list of road segments
/// with curvature and hills, projected into per-scanline snow bands. Trees, rocks, snowmen, flags, slalom gates
/// and rival boarders are depth-scaled procedural sprites drawn back to front. Hit ramps for spin tricks,
/// grab boost pads, avoid ice, pass three checkpoints and reach the finish before the clock runs out.
final class SnowSlalom64: Game {
    // MARK: - Constants

    private static let segLen: Float = 200
    private static let roadW: Float = 900
    private static let camH: Float = 760
    private static let camDepth: Float = 0.8
    private static let playerDist: Float = 640
    private static let horizonY: Float = 108
    private static let drawN = 120
    private static let courseSegs = 4200
    private static let extraSegs = 170
    private static let fogNear: Float = 9000
    private static let fogFar: Float = 24000
    private static let hazeR = 214
    private static let hazeG = 232
    private static let hazeB = 250
    private static let startTime = 40 * 60
    private static let checkTime = 25 * 60
    private static let maxTime = 99 * 60
    private static let gateHalf: Float = 0.30

    private static let kPine = 0
    private static let kPine2 = 1
    private static let kRock = 2
    private static let kSnowman = 3
    private static let kFlag = 4
    private static let kGate = 5
    private static let kCheck = 6
    private static let kFinish = 7
    private static let kBoarder = 8
    private static let kArrowL = 11
    private static let kArrowR = 12
    private static let kRampSign = 13
    private static let kStart = 14

    private static let collW: [Float] = [0.12, 0.12, 0.17, 0.11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    private static let cWhite: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    private static let cBlack: UInt32 = TrueColorBuffer.rgb(8, 10, 22)
    private static let cYellow: UInt32 = TrueColorBuffer.rgb(255, 226, 64)
    private static let cRed: UInt32 = TrueColorBuffer.rgb(250, 70, 56)
    private static let cGreen: UInt32 = TrueColorBuffer.rgb(100, 255, 130)
    private static let cCyan: UInt32 = TrueColorBuffer.rgb(110, 232, 255)
    private static let cPanel: UInt32 = TrueColorBuffer.rgb(16, 28, 70)
    private static let cOrange: UInt32 = TrueColorBuffer.rgb(255, 150, 40)

    // MARK: - Static tables

    private static let skyRows: [UInt32] = {
        var a = [UInt32](repeating: 0, count: 120)
        for y in 0..<120 {
            let t: Float = Float(y) / 112.0
            let tt: Float = min(1, t)
            let r = Int(62 + (206 - 62) * tt)
            let g = Int(124 + (228 - 124) * tt)
            let bl = Int(226 + (250 - 226) * tt)
            a[y] = TrueColorBuffer.rgb(r, g, bl)
        }
        return a
    }()

    private static let farHill: [Int] = {
        var a = [Int](repeating: 6, count: 512)
        for i in 0..<512 {
            let ang: Float = Float(i) / 512.0 * 2.0 * Float.pi
            let f1: Float = 20 * sin(ang * 2 + 0.7)
            let f2: Float = 12 * sin(ang * 5 + 2.0)
            let f3: Float = 5 * sin(ang * 13 + 1.0)
            let f: Float = 34 + f1 + f2 + f3
            a[i] = max(6, Int(f))
        }
        return a
    }()

    private static let nearHill: [Int] = {
        var a = [Int](repeating: 4, count: 512)
        for i in 0..<512 {
            let ang: Float = Float(i) / 512.0 * 2.0 * Float.pi
            let f1: Float = 8 * sin(ang * 4 + 1.0)
            let f2: Float = 6 * sin(ang * 9 + 4.0)
            let f3: Float = 3 * sin(ang * 21)
            let f: Float = 16 + f1 + f2 + f3
            a[i] = max(4, Int(f))
        }
        return a
    }()

    private static let sprites: [SpriteImg] = SnowSlalom64.makeSprites()

    @inline(__always) private static func mixHaze(_ c: UInt32, _ t: Int) -> UInt32 {
        if t <= 0 { return c }
        let r = Int(c & 255)
        let g = Int((c >> 8) & 255)
        let bl = Int((c >> 16) & 255)
        let r2 = r + (((SnowSlalom64.hazeR - r) * t) >> 8)
        let g2 = g + (((SnowSlalom64.hazeG - g) * t) >> 8)
        let b2 = bl + (((SnowSlalom64.hazeB - bl) * t) >> 8)
        let rr = UInt32(max(0, min(255, r2)))
        let gg = UInt32(max(0, min(255, g2)))
        let bb = UInt32(max(0, min(255, b2)))
        return 0xFF00_0000 | rr | (gg << 8) | (bb << 16)
    }

    private static func fogAmount(_ z: Float) -> Int {
        if z <= SnowSlalom64.fogNear { return 0 }
        var t: Float = (z - SnowSlalom64.fogNear) / (SnowSlalom64.fogFar - SnowSlalom64.fogNear)
        if t > 1 { t = 1 }
        if t < 0 { t = 0 }
        return Int(t * 256)
    }

    private static func col(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
        return TrueColorBuffer.rgb(r, g, b)
    }

    // MARK: - Nested types

    struct Spr {
        var off: Float
        var kind: Int
    }

    struct SpriteImg {
        var w: Int
        var h: Int
        var pix: [UInt32]
        var worldW: Float
    }

    struct Boarder {
        var z: Float
        var baseX: Float
        var x: Float
        var speed: Float
        var phase: Float
        var kind: Int
    }

    enum Phase { case title, countdown, racing, finishing, results }

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

    // MARK: - Course data

    final class Course {
        var curve: [Float] = []
        var pointY: [Float] = [0]
        var decal: [UInt8] = []
        var decalOff: [Float] = []
        var decalHalf: [Float] = []
        var calm: [Bool] = []
        var sprites: [[Spr]] = []
        var rampStarts: [Int] = []
        var total = 0
        var gateCount = 0

        init(_ rng: inout Rng) {
            build(&rng)
        }

        func addSegment(_ c: Float, _ y: Float) {
            curve.append(c)
            pointY.append(y)
            decal.append(0)
            decalOff.append(0)
            decalHalf.append(0)
            calm.append(false)
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
            addRoad(12, 6, 12, 0, 0)
            let start = curve.count
            rampStarts.append(start)
            let y0 = lastY()
            for i in 0..<8 {
                addSegment(0, y0 + 100 * Float(i + 1))
                decal[curve.count - 1] = 3
            }
            let y1 = lastY()
            for i in 0..<20 {
                addSegment(0, y1 - 40 * Float(i + 1))
            }
            for _ in 0..<10 { addSegment(0, lastY()) }
            let lo = max(0, start - 6)
            let hi = min(curve.count - 1, start + 40)
            if lo <= hi {
                for i in lo...hi { calm[i] = true }
            }
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

        func build(_ rng: inout Rng) {
            addRoad(10, 40, 10, 0, 0)
            var sinceRamp = 0
            while curve.count < SnowSlalom64.courseSegs {
                let before = curve.count
                let pick = rng.int(11)
                let sgn: Float = rng.chance(50) ? 1 : -1
                let cmag: Float = 1.6 + Float(rng.int(26)) / 10.0
                switch pick {
                case 0:
                    addRoad(20, 30 + rng.int(40), 20, 0, 0)
                case 1, 2:
                    addRoad(25, 40 + rng.int(50), 25, cmag * sgn, 0)
                case 3:
                    addRoad(25, 20 + rng.int(30), 25, 0, Float(rng.range(-3500, 2200)))
                case 4:
                    addRoad(25, 25, 25, 2.4 * sgn, -800)
                    addRoad(25, 25, 25, -2.4 * sgn, -800)
                case 5:
                    addRoad(30, 40, 30, cmag * sgn, Float(rng.range(-3000, 1800)))
                case 6:
                    if sinceRamp > 350 {
                        addRamp()
                        sinceRamp = 0
                    } else {
                        addRoad(20, 40, 20, 0, -1200)
                    }
                case 7:
                    addRoad(20, 20, 20, 0, Float(rng.range(500, 2400)))
                    addRoad(20, 20, 20, 0, Float(rng.range(-3600, -800)))
                default:
                    addRoad(25, 30 + rng.int(40), 25, cmag * 0.7 * sgn, -600)
                }
                sinceRamp += curve.count - before
            }
            let ly = lastY()
            for _ in 0..<SnowSlalom64.extraSegs { addSegment(0, ly) }
            total = curve.count
            place(&rng)
        }

        func place(_ rng: inout Rng) {
            let n = total
            let cs = SnowSlalom64.courseSegs
            var i = 4
            while i < n - 2 {
                for side in 0..<2 {
                    if rng.chance(58) {
                        let sgn: Float = side == 0 ? -1 : 1
                        let off: Float = sgn * (1.28 + Float(rng.unit()) * 1.5)
                        let kind = rng.chance(50) ? SnowSlalom64.kPine : SnowSlalom64.kPine2
                        sprites[i].append(Spr(off: off, kind: kind))
                    }
                }
                i += 3
            }
            var f = 10
            var fs: Float = 1
            while f < n - 2 {
                sprites[f].append(Spr(off: 1.1 * fs, kind: SnowSlalom64.kFlag))
                fs = -fs
                f += 12
            }
            var r = 32
            while r < cs - 20 {
                if !calm[r] && decal[r] == 0 && rng.chance(50) {
                    let off: Float = Float(rng.range(-80, 80)) / 100.0
                    sprites[r].append(Spr(off: off, kind: SnowSlalom64.kRock))
                }
                r += 17
            }
            var s = 55
            while s < cs - 20 {
                if !calm[s] && decal[s] == 0 && rng.chance(60) {
                    let off: Float = Float(rng.range(-70, 70)) / 100.0
                    sprites[s].append(Spr(off: off, kind: SnowSlalom64.kSnowman))
                }
                s += 41
            }
            var g = 70
            while g < cs - 60 {
                let cluster = 3 + rng.int(4)
                var off: Float = Float(rng.range(-40, 40)) / 100.0
                for k in 0..<cluster {
                    let sg = g + k * 26
                    if sg < cs - 30 && !calm[sg] && decal[sg] == 0 {
                        sprites[sg].append(Spr(off: off, kind: SnowSlalom64.kGate))
                        gateCount += 1
                    }
                    off += Float(rng.range(-35, 35)) / 100.0
                    off = max(-0.55, min(0.55, off))
                }
                g += cluster * 26 + 60 + rng.int(120)
            }
            var bp = 120
            while bp < cs - 80 {
                if !calm[bp] {
                    let off: Float = Float(rng.range(-50, 50)) / 100.0
                    setDecal(1, bp, 5, off, 0.2)
                }
                bp += 200 + rng.int(160)
            }
            var ip = 230
            while ip < cs - 80 {
                if !calm[ip] {
                    let off: Float = Float(rng.range(-40, 40)) / 100.0
                    setDecal(2, ip, 6, off, 0.36)
                }
                ip += 260 + rng.int(200)
            }
            var signed = false
            for q in 10..<cs {
                let c = curve[q]
                if abs(c) > 2.4 && !signed {
                    let at = max(2, q - 8)
                    if c > 0 {
                        sprites[at].append(Spr(off: -1.2, kind: SnowSlalom64.kArrowR))
                    } else {
                        sprites[at].append(Spr(off: 1.2, kind: SnowSlalom64.kArrowL))
                    }
                    signed = true
                } else if abs(c) < 1.0 {
                    signed = false
                }
            }
            for rs in rampStarts {
                let a = max(2, rs - 14)
                let b = max(2, rs - 26)
                sprites[a].append(Spr(off: -1.2, kind: SnowSlalom64.kRampSign))
                sprites[a].append(Spr(off: 1.2, kind: SnowSlalom64.kRampSign))
                sprites[b].append(Spr(off: -1.2, kind: SnowSlalom64.kRampSign))
            }
            sprites[6].append(Spr(off: 0, kind: SnowSlalom64.kStart))
            for k in 1...3 {
                let seg = cs * k / 4
                sprites[seg].append(Spr(off: 0, kind: SnowSlalom64.kCheck))
            }
            sprites[cs].append(Spr(off: 0, kind: SnowSlalom64.kFinish))
        }
    }

    // MARK: - Sprite generation

    static func makePine(_ snowy: Bool) -> SpriteImg {
        var p = Pix(32, 56)
        let dark = col(18, 92, 60)
        let light = col(44, 150, 88)
        let snow = col(250, 252, 255)
        let snowShade = col(200, 218, 244)
        let trunk = col(110, 72, 36)
        p.rect(14, 44, 4, 12, trunk)
        for y in 0..<42 {
            let tier = y / 14
            let row = y % 14
            let hw = 3 + (row * 8) / 13 + tier * 2
            for x in (16 - hw)..<(16 + hw) {
                var c = dark
                if x < 16 - hw / 3 { c = light }
                let capRows = snowy ? 6 : 3
                if row < capRows { c = x < 16 ? snow : snowShade }
                if snowy && row < 9 && x > 16 + hw / 2 { c = snowShade }
                p.set(x, y + 1, c)
            }
        }
        p.outline(col(8, 44, 32))
        return SpriteImg(w: p.w, h: p.h, pix: p.d, worldW: 640)
    }

    static func makeRock() -> SpriteImg {
        var p = Pix(28, 20)
        let grey = col(128, 128, 144)
        let greyD = col(84, 84, 104)
        let snow = col(250, 252, 255)
        p.disc(10, 13, 7, greyD)
        p.disc(18, 12, 8, greyD)
        p.disc(10, 12, 6, grey)
        p.disc(17, 11, 7, grey)
        p.disc(9, 7, 4, snow)
        p.disc(16, 5, 5, snow)
        p.rect(7, 6, 14, 3, snow)
        p.outline(col(30, 30, 50))
        return SpriteImg(w: p.w, h: p.h, pix: p.d, worldW: 420)
    }

    static func makeSnowman() -> SpriteImg {
        var p = Pix(20, 34)
        let white = col(252, 253, 255)
        let shade = col(196, 212, 240)
        p.disc(10, 26, 8, shade)
        p.disc(9, 25, 7, white)
        p.disc(10, 16, 6, shade)
        p.disc(9, 15, 5, white)
        p.disc(10, 8, 5, shade)
        p.disc(9, 8, 4, white)
        p.rect(5, 1, 9, 3, col(30, 30, 40))
        p.rect(7, 0, 5, 2, col(30, 30, 40))
        p.set(7, 7, col(10, 10, 10))
        p.set(11, 7, col(10, 10, 10))
        p.rect(9, 9, 4, 1, col(255, 130, 30))
        p.set(9, 16, col(30, 30, 30))
        p.set(9, 20, col(30, 30, 30))
        p.rect(2, 14, 2, 1, col(110, 72, 36))
        p.rect(16, 14, 2, 1, col(110, 72, 36))
        p.outline(col(40, 52, 90))
        return SpriteImg(w: p.w, h: p.h, pix: p.d, worldW: 300)
    }

    static func makeFlag() -> SpriteImg {
        var p = Pix(12, 40)
        p.rect(2, 0, 2, 40, col(130, 130, 150))
        p.rect(4, 2, 8, 7, col(240, 50, 50))
        p.rect(4, 4, 8, 2, col(255, 255, 255))
        p.outline(col(30, 30, 50))
        return SpriteImg(w: p.w, h: p.h, pix: p.d, worldW: 150)
    }

    static func makeGate() -> SpriteImg {
        var p = Pix(48, 40)
        let red = col(240, 50, 50)
        let blue = col(50, 120, 255)
        let white = col(255, 255, 255)
        p.rect(0, 0, 3, 40, red)
        p.rect(45, 0, 3, 40, blue)
        for y in stride(from: 4, to: 40, by: 8) {
            p.rect(0, y, 3, 3, white)
            p.rect(45, y, 3, 3, white)
        }
        p.rect(3, 1, 11, 6, red)
        p.rect(34, 1, 11, 6, blue)
        p.rect(5, 3, 7, 2, white)
        p.rect(36, 3, 7, 2, white)
        var x = 4
        while x < 44 {
            p.set(x, 8, white)
            x += 2
        }
        p.outline(col(20, 20, 50))
        return SpriteImg(w: p.w, h: p.h, pix: p.d, worldW: 540)
    }

    static func makeArch(_ mode: Int) -> SpriteImg {
        var p = Pix(96, 48)
        var postA = col(255, 210, 40)
        var postB = col(30, 30, 40)
        if mode == 1 {
            postA = col(240, 50, 50)
            postB = col(255, 255, 255)
        } else if mode == 2 {
            postA = col(60, 200, 90)
            postB = col(255, 255, 255)
        }
        for y in 8..<48 {
            let c = ((y / 4) & 1) == 0 ? postA : postB
            p.rect(0, y, 6, 1, c)
            p.rect(90, y, 6, 1, c)
        }
        for y in 0..<16 {
            for x in 0..<96 {
                var c = postA
                if mode == 0 {
                    c = (((x + y) / 4) & 1) == 0 ? col(255, 210, 40) : col(30, 30, 40)
                } else if mode == 1 {
                    c = (((x / 4) + (y / 4)) & 1) == 0 ? col(250, 250, 250) : col(20, 20, 26)
                } else {
                    c = ((x / 6) & 1) == 0 ? col(60, 130, 255) : col(250, 250, 250)
                }
                p.set(x, y, c)
            }
        }
        if mode == 0 {
            p.rect(38, 3, 20, 10, col(40, 220, 90))
            p.rect(40, 5, 16, 6, col(200, 255, 210))
        }
        p.outline(col(10, 12, 24))
        return SpriteImg(w: p.w, h: p.h, pix: p.d, worldW: 2100)
    }

    static func makeBoarder(_ r: Int, _ g: Int, _ b: Int, _ hr: Int, _ hg: Int, _ hb: Int) -> SpriteImg {
        var p = Pix(18, 26)
        let jacket = col(r, g, b)
        let jacketD = col(r / 2, g / 2, b / 2)
        let pants = col(40, 50, 100)
        let helmet = col(hr, hg, hb)
        p.rect(1, 22, 16, 3, col(50, 54, 70))
        p.rect(2, 22, 14, 1, col(210, 215, 230))
        p.rect(5, 15, 3, 7, pants)
        p.rect(10, 15, 3, 7, pants)
        p.rect(4, 7, 10, 9, jacket)
        p.rect(4, 12, 10, 1, jacketD)
        p.rect(2, 8, 2, 6, jacketD)
        p.rect(14, 8, 2, 6, jacketD)
        p.disc(9, 4, 3, helmet)
        p.rect(7, 4, 5, 1, col(30, 30, 40))
        p.outline(col(14, 16, 30))
        return SpriteImg(w: p.w, h: p.h, pix: p.d, worldW: 190)
    }

    static func makeArrow(_ right: Bool) -> SpriteImg {
        var p = Pix(24, 28)
        let yellow = col(255, 214, 40)
        let black = col(20, 20, 30)
        p.rect(11, 16, 2, 12, col(150, 150, 170))
        p.rect(0, 0, 24, 16, black)
        p.rect(1, 1, 22, 14, yellow)
        var shaft = Pix(24, 16)
        shaft.rect(4, 7, 12, 2, black)
        for i in 0..<5 {
            let hgt = 9 - 2 * i
            shaft.rect(15 + i, 8 - hgt / 2, 1, hgt, black)
        }
        for y in 0..<16 {
            for x in 0..<24 {
                if shaft.d[y * 24 + x] != 0 {
                    let xx = right ? x : 23 - x
                    p.set(xx, y, black)
                }
            }
        }
        return SpriteImg(w: p.w, h: p.h, pix: p.d, worldW: 330)
    }

    static func makeRampSign() -> SpriteImg {
        var p = Pix(22, 28)
        let yellow = col(255, 214, 40)
        let black = col(20, 20, 30)
        p.rect(10, 14, 2, 14, col(150, 150, 170))
        for y in 0..<14 {
            let hw = y * 10 / 13
            p.rect(11 - hw - 1, y, 2 * hw + 2, 1, yellow)
        }
        p.rect(10, 5, 2, 5, black)
        p.rect(10, 11, 2, 2, black)
        p.outline(black)
        return SpriteImg(w: p.w, h: p.h, pix: p.d, worldW: 300)
    }

    static func makeSprites() -> [SpriteImg] {
        var list: [SpriteImg] = []
        list.append(makePine(false))
        list.append(makePine(true))
        list.append(makeRock())
        list.append(makeSnowman())
        list.append(makeFlag())
        list.append(makeGate())
        list.append(makeArch(0))
        list.append(makeArch(1))
        list.append(makeBoarder(60, 130, 255, 255, 255, 255))
        list.append(makeBoarder(70, 210, 90, 255, 220, 60))
        list.append(makeBoarder(190, 90, 240, 250, 90, 90))
        list.append(makeArrow(false))
        list.append(makeArrow(true))
        list.append(makeRampSign())
        list.append(makeArch(2))
        return list
    }

    // MARK: - State

    private var phase: Phase = .title
    private var rng = Rng()
    private var course: Course
    private var frame = 0
    private var pos: Float = 160
    private var speed: Float = 0
    private var playerX: Float = 0
    private var xVel: Float = 0
    private var lean: Float = 0
    private var py: Float = 0
    private var vy: Float = 0
    private var lastSlope: Float = 0
    private var grounded = true
    private var airFrames = 0
    private var spinAngle: Float = 0
    private var spinTotal: Float = 0
    private var wipe = 0
    private var wipeAge = 0
    private var invuln = 0
    private var boostTimer = 0
    private var boostCooldown = 0
    private var onIce = false
    private var camBase: Float = 0
    private var groundNow: Float = 0
    private var bgOff: Float = 0
    private var cdTimer = 0
    private var timeLeft = SnowSlalom64.startTime
    private var raceFrames = 0
    private var cpPassed = 0
    private var gatesHit = 0
    private var gatesMissed = 0
    private var streak = 0
    private var distScore = 0
    private var gateScore = 0
    private var trickScore = 0
    private var bonusScore = 0
    private var bestTrick = 0
    private var msg = ""
    private var msgTimer = 0
    private var msgColor: UInt32 = SnowSlalom64.cYellow
    private var finishTimer = 0
    private var timeUp = false
    private var resultTimer = 0
    private var boarders: [Boarder] = []
    private var geoBase = 0
    private var gOK = [Bool](repeating: false, count: SnowSlalom64.drawN)
    private var gDrawn = [Bool](repeating: false, count: SnowSlalom64.drawN)
    private var gY1 = [Float](repeating: 0, count: SnowSlalom64.drawN)
    private var gY2 = [Float](repeating: 0, count: SnowSlalom64.drawN)
    private var gCX1 = [Float](repeating: 0, count: SnowSlalom64.drawN)
    private var gCX2 = [Float](repeating: 0, count: SnowSlalom64.drawN)
    private var gP1 = [Float](repeating: 0, count: SnowSlalom64.drawN)
    private var gP2 = [Float](repeating: 0, count: SnowSlalom64.drawN)
    private var gClip = [Float](repeating: 288, count: SnowSlalom64.drawN)
    private var gBot = [Float](repeating: 0, count: SnowSlalom64.drawN)
    private var gZ1 = [Float](repeating: 0, count: SnowSlalom64.drawN)

    override var score: Int { return max(0, distScore + gateScore + trickScore + bonusScore) }

    override init() {
        var r = Rng()
        course = Course(&r)
        super.init()
        rng = r
        resetRun()
        phase = .title
    }

    override func start() {
        playMusic(Tunes.arcade)
    }

    // MARK: - Setup

    private func resetRun() {
        course = Course(&rng)
        let playerZ: Float = 4 * SnowSlalom64.segLen
        pos = playerZ - SnowSlalom64.playerDist
        speed = 0
        playerX = 0
        xVel = 0
        lean = 0
        vy = 0
        lastSlope = 0
        grounded = true
        airFrames = 0
        spinAngle = 0
        spinTotal = 0
        wipe = 0
        wipeAge = 0
        invuln = 0
        boostTimer = 0
        boostCooldown = 0
        onIce = false
        bgOff = 0
        timeLeft = SnowSlalom64.startTime
        raceFrames = 0
        cpPassed = 0
        gatesHit = 0
        gatesMissed = 0
        streak = 0
        distScore = 0
        gateScore = 0
        trickScore = 0
        bonusScore = 0
        bestTrick = 0
        msg = ""
        msgTimer = 0
        finishTimer = 0
        timeUp = false
        resultTimer = 0
        groundNow = groundAt(playerZ)
        py = groundNow
        camBase = groundNow
        spawnBoarders()
    }

    private func spawnBoarders() {
        boarders = []
        let n = 14
        let span = SnowSlalom64.courseSegs - 160
        for k in 0..<n {
            let seg = 60 + (k * span) / n + rng.int(60)
            let bx: Float = Float(rng.range(-65, 65)) / 100.0
            let sp: Float = 0.42 + Float(rng.int(40)) / 100.0
            let kind = SnowSlalom64.kBoarder + rng.int(3)
            let ph: Float = Float(rng.int(628)) / 100.0
            boarders.append(Boarder(z: Float(seg) * SnowSlalom64.segLen, baseX: bx, x: bx, speed: sp, phase: ph, kind: kind))
        }
    }

    private func startCountdown() {
        resetRun()
        phase = .countdown
        cdTimer = 200
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
        let f: Float = z / SnowSlalom64.segLen
        if f > Float(total - 2) { return max(0, total - 2) }
        return Int(f)
    }

    private func groundAt(_ z: Float) -> Float {
        let idx = segIndex(z)
        var pct: Float = z / SnowSlalom64.segLen - Float(idx)
        if !(pct >= 0) { pct = 0 }
        if pct > 1 { pct = 1 }
        let a = course.pointY[idx]
        let b = course.pointY[idx + 1]
        return a + (b - a) * pct
    }

    // MARK: - Update

    override func update(_ input: InputState) {
        frame += 1
        lastInputA = input.a
        if msgTimer > 0 { msgTimer -= 1 }
        if boostTimer > 0 { boostTimer -= 1 }
        if boostCooldown > 0 { boostCooldown -= 1 }
        if invuln > 0 { invuln -= 1 }
        switch phase {
        case .title:
            stepDemo()
            if input.aPressed || input.startPressed {
                startCountdown()
                play(.confirm)
            }
        case .countdown:
            cdTimer -= 1
            followCamera()
            if cdTimer == 140 || cdTimer == 80 || cdTimer == 20 { play(.countdown) }
            if cdTimer <= 0 {
                phase = .racing
                showMsg("GO!", 60, SnowSlalom64.cGreen)
                play(.powerup)
            }
        case .racing:
            stepRace(input)
        case .finishing:
            stepFinish()
        case .results:
            resultTimer += 1
            followCamera()
            if resultTimer > 40 && (input.aPressed || input.startPressed) {
                startCountdown()
                play(.confirm)
            }
        }
    }

    private func followCamera() {
        let playerZ = pos + SnowSlalom64.playerDist
        groundNow = groundAt(playerZ)
        let air: Float = max(0, py - groundNow)
        let target: Float = groundNow + air * 0.35
        camBase += (target - camBase) * 0.25
        if !camBase.isFinite { camBase = groundNow }
    }

    private func stepDemo() {
        speed = 0.6
        playerX = 0.5 * sin(Float(frame) * 0.025)
        xVel = cos(Float(frame) * 0.025) * 0.012
        pos += speed * SnowSlalom64.segLen
        let limit: Float = Float(SnowSlalom64.courseSegs / 2) * SnowSlalom64.segLen
        if pos > limit { pos = 160 }
        let playerZ = pos + SnowSlalom64.playerDist
        groundNow = groundAt(playerZ)
        py = groundNow
        let idx = segIndex(playerZ)
        let cv = course.curve[idx]
        bgOff += cv * speed * 0.5
        bgOff = bgOff - 5120 * floor(bgOff / 5120)
        lean += (xVel * 20 - lean) * 0.2
        camBase += (groundNow - camBase) * 0.3
    }

    private func endRace(_ timedOut: Bool) {
        timeUp = timedOut
        phase = .results
        resultTimer = 0
        if timedOut {
            play(.lose)
        }
    }

    private func stepFinish() {
        finishTimer -= 1
        speed *= 0.965
        xVel *= 0.9
        playerX += xVel
        pos += speed * SnowSlalom64.segLen
        let maxPos: Float = Float(max(1, course.total - 140)) * SnowSlalom64.segLen
        if pos > maxPos { pos = maxPos }
        let playerZ = pos + SnowSlalom64.playerDist
        groundNow = groundAt(playerZ)
        py = groundNow
        lean += (xVel * 20 - lean) * 0.2
        followCamera()
        if finishTimer <= 0 {
            phase = .results
            resultTimer = 0
        }
    }

    private func stepRace(_ input: InputState) {
        let c = course
        let seg = SnowSlalom64.segLen
        raceFrames += 1
        timeLeft -= 1
        if timeLeft <= 0 {
            timeLeft = 0
            endRace(true)
            return
        }
        if timeLeft < 600 && timeLeft % 60 == 0 { play(.countdown) }

        let prevZ = pos + SnowSlalom64.playerDist
        let idx0 = segIndex(prevZ)
        let curveHere = c.curve[idx0]
        let dySeg = c.pointY[idx0 + 1] - c.pointY[idx0]

        // wipeout
        if wipe > 0 {
            wipe -= 1
            wipeAge += 1
            speed *= 0.93
            xVel *= 0.9
            if wipe == 0 {
                invuln = 100
                speed = 0.15
            }
        } else {
            // speed target
            var ts: Float = 0.62
            if input.a { ts = 0.95 }
            if input.b && grounded { ts = 0.2 }
            ts += clamp(-dySeg * 0.004, -0.15, 0.18)
            if boostTimer > 0 { ts += 0.4 }
            if abs(playerX) > 1.0 { ts = min(ts, 0.4) }
            if speed < ts {
                speed += 0.010
            } else {
                speed -= input.b ? 0.03 : 0.008
            }
            // steering
            let pct: Float = clamp(speed / 1.0, 0, 1.3)
            var grip: Float = 1
            if onIce { grip = 0.28 }
            var steerRate: Float = 0.03 * (0.4 + pct)
            if input.a && grounded { steerRate *= 0.8 }
            if input.b && grounded { steerRate *= 1.25 }
            if !grounded { steerRate *= 0.35 }
            let target: Float = Float(input.dx) * steerRate
            xVel += (target - xVel) * 0.25 * grip
        }
        speed = clamp(speed, 0, 1.45)
        let pctC: Float = clamp(speed, 0, 1.3)
        var centrifugal: Float = curveHere * pctC * pctC * 0.0095
        if !grounded { centrifugal *= 0.3 }
        playerX += xVel - centrifugal
        playerX = clamp(playerX, -2.3, 2.3)
        if !playerX.isFinite { playerX = 0 }
        lean += (clamp(xVel * 22, -1, 1) - lean) * 0.2

        // trick spin
        if !grounded && wipe == 0 {
            if input.b {
                spinAngle += 0.28
                spinTotal += 0.28
            } else {
                let twoPi: Float = 2 * Float.pi
                let nearest: Float = (spinAngle / twoPi).rounded() * twoPi
                spinAngle += (nearest - spinAngle) * 0.15
            }
        }

        // advance
        pos += speed * seg
        let maxPos: Float = Float(max(1, c.total - 140)) * seg
        if pos > maxPos { pos = maxPos }
        let newZ = pos + SnowSlalom64.playerDist
        let newGround = groundAt(newZ)
        groundNow = newGround
        if grounded {
            if newGround < py + lastSlope - 12 && speed > 0.3 && wipe == 0 {
                grounded = false
                vy = lastSlope
                airFrames = 0
                spinAngle = 0
                spinTotal = 0
                py += vy
                play(.jump)
            } else {
                lastSlope = clamp(newGround - py, -400, 400)
                py = newGround
            }
        } else {
            py += vy
            vy -= 6
            airFrames += 1
            if py <= newGround {
                landOn(newGround)
            }
        }
        if !py.isFinite { py = newGround }

        // decals on the current segment
        let idx1 = segIndex(newZ)
        if grounded && wipe == 0 {
            let d = c.decal[idx1]
            let off = c.decalOff[idx1]
            let half = c.decalHalf[idx1]
            let inside = abs(playerX - off) < half + 0.04
            if d == 1 && inside && boostCooldown == 0 {
                boostTimer = 90
                boostCooldown = 25
                speed = max(speed, 0.9)
                showMsg("BOOST!", 45, SnowSlalom64.cOrange)
                play(.powerup)
            }
            let wasIce = onIce
            onIce = (d == 2 && inside)
            if onIce && !wasIce {
                showMsg("ICE!", 40, SnowSlalom64.cCyan)
                play(.blip)
            }
        } else {
            onIce = false
        }

        // crossing checks
        let seg0 = segIndex(prevZ)
        if idx1 > seg0 {
            for i in (seg0 + 1)...idx1 {
                if i >= c.total { break }
                if i <= SnowSlalom64.courseSegs && (i % 2) == 0 { distScore += 1 }
                for s in c.sprites[i] {
                    handleSprite(s, i)
                    if phase != .racing { return }
                }
            }
        }

        // boarders
        updateBoarders(newZ)

        // background parallax
        bgOff += curveHere * speed * 0.5
        bgOff = bgOff - 5120 * floor(bgOff / 5120)
        followCamera()
    }

    private func landOn(_ ground: Float) {
        py = ground
        grounded = true
        lastSlope = 0
        if airFrames > 8 { play(.thud) }
        var pts = 0
        if spinTotal > 1 {
            let twoPi: Float = 2 * Float.pi
            let full = Int(spinTotal / twoPi + 0.4)
            if full >= 1 {
                pts = 300 * full + 100 * (full - 1)
                if airFrames > 45 { pts += 150 }
                trickScore += pts
                bestTrick = max(bestTrick, pts)
                showMsg("SPIN X" + String(full) + "  +" + String(pts), 90, SnowSlalom64.cYellow)
                play(.win)
            } else {
                speed *= 0.75
                showMsg("SLOPPY LANDING", 60, SnowSlalom64.cRed)
                play(.hurt)
            }
        } else if airFrames > 40 {
            pts = 150
            trickScore += pts
            showMsg("BIG AIR  +150", 70, SnowSlalom64.cCyan)
            play(.coin)
        }
        spinAngle = 0
        spinTotal = 0
        airFrames = 0
        vy = 0
    }

    private func handleSprite(_ s: Spr, _ i: Int) {
        let k = s.kind
        if k == SnowSlalom64.kGate {
            if abs(playerX - s.off) < SnowSlalom64.gateHalf {
                gatesHit += 1
                streak += 1
                let pts = 50 * min(streak, 6)
                gateScore += pts
                if streak > 1 {
                    showMsg("GATE X" + String(streak) + "  +" + String(pts), 45, SnowSlalom64.cGreen)
                } else {
                    showMsg("GATE +" + String(pts), 40, SnowSlalom64.cGreen)
                }
                play(.coin)
            } else {
                gatesMissed += 1
                if streak > 1 { showMsg("MISSED GATE", 45, SnowSlalom64.cRed) }
                streak = 0
                play(.blip)
            }
        } else if k == SnowSlalom64.kCheck {
            cpPassed += 1
            timeLeft = min(SnowSlalom64.maxTime, timeLeft + SnowSlalom64.checkTime)
            showMsg("CHECKPOINT +25S", 100, SnowSlalom64.cYellow)
            play(.powerup)
        } else if k == SnowSlalom64.kFinish {
            beginFinish()
        } else if k < SnowSlalom64.collW.count && SnowSlalom64.collW[k] > 0 {
            if grounded && wipe == 0 && invuln == 0 {
                let w = SnowSlalom64.collW[k]
                if abs(playerX - s.off) < w + 0.07 && (py - groundNow) < 220 {
                    startWipeout()
                }
            }
        }
    }

    private func startWipeout() {
        wipe = 75
        wipeAge = 0
        streak = 0
        boostTimer = 0
        xVel = 0
        showMsg("WIPEOUT!", 70, SnowSlalom64.cRed)
        play(.hurt)
    }

    private func beginFinish() {
        phase = .finishing
        finishTimer = 150
        let tb = (timeLeft / 60) * 50
        bonusScore = 2000 + tb
        showMsg("FINISH!", 150, SnowSlalom64.cGreen)
        play(.win)
    }

    private func updateBoarders(_ playerZ: Float) {
        let seg = SnowSlalom64.segLen
        let limit: Float = Float(SnowSlalom64.courseSegs + 100) * seg
        for i in 0..<boarders.count {
            var b = boarders[i]
            b.z += b.speed * seg
            if b.z > limit { b.z = limit }
            b.phase += 0.03
            b.x = b.baseX + 0.22 * sin(b.phase)
            let dz = b.z - playerZ
            if abs(dz) < seg * 0.9 && abs(b.x - playerX) < 0.14 && grounded && wipe == 0 && invuln == 0 {
                speed *= 0.6
                let dir: Float = playerX >= b.x ? 1 : -1
                xVel = dir * 0.03
                b.baseX -= dir * 0.2
                invuln = 30
                showMsg("BUMP!", 30, SnowSlalom64.cOrange)
                play(.hit)
            }
            if !b.x.isFinite { b.x = 0 }
            b.baseX = clamp(b.baseX, -0.9, 0.9)
            boarders[i] = b
        }
    }

    // MARK: - Geometry

    private func buildGeometry() {
        let c = course
        let total = c.total
        let seg = SnowSlalom64.segLen
        let baseIdx = max(0, min(total - 2, Int(max(0, pos) / seg)))
        var basePct: Float = pos / seg - Float(baseIdx)
        if !(basePct >= 0) { basePct = 0 }
        if basePct > 1 { basePct = 1 }
        var x: Float = 0
        var dx: Float = -(basePct * c.curve[baseIdx])
        var maxY: Float = 288
        let camXw: Float = playerX * SnowSlalom64.roadW
        let camYw: Float = camBase + SnowSlalom64.camH
        let depthK: Float = SnowSlalom64.camDepth * 160
        let hz = SnowSlalom64.horizonY
        geoBase = baseIdx
        for n in 0..<SnowSlalom64.drawN {
            let idx = baseIdx + n
            gDrawn[n] = false
            gOK[n] = false
            if idx + 1 >= total { continue }
            let z1: Float = Float(idx) * seg - pos
            let z2: Float = z1 + seg
            gClip[n] = maxY
            gZ1[n] = z1
            if z1 > SnowSlalom64.camDepth {
                let ppu1: Float = depthK / z1
                let ppu2: Float = depthK / z2
                let cx1: Float = 160 + ppu1 * (x - camXw)
                let cx2: Float = 160 + ppu2 * ((x + dx) - camXw)
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

    private func renderBackground(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        let rows = SnowSlalom64.skyRows
        let hzI = 114
        for y in 0..<min(h, hzI) {
            let c = rows[min(119, y)]
            span(p, y * w, 0, w, c)
        }
        let haze = TrueColorBuffer.rgb(SnowSlalom64.hazeR, SnowSlalom64.hazeG, SnowSlalom64.hazeB)
        if hzI < h {
            for y in hzI..<h { span(p, y * w, 0, w, haze) }
        }
        // sun
        let sunIdx: Int = Int(bgOff * 0.1)
        let sx: Int = (((300 - sunIdx) % 512) + 512) % 512 - 100
        let sy = 34
        let sunCore = TrueColorBuffer.rgb(255, 250, 215)
        let sunXa = max(0, sx - 30)
        let sunXb = min(w - 1, sx + 30)
        let sunYa = max(0, sy - 30)
        let sunYb = min(h - 1, sy + 30)
        if sunXa <= sunXb && sunYa <= sunYb {
          for yy in sunYa...sunYb {
            for xx in sunXa...sunXb {
                let ddx = xx - sx
                let ddy = yy - sy
                let d2 = ddx * ddx + ddy * ddy
                if d2 > 900 { continue }
                let idx = yy * w + xx
                if d2 <= 169 {
                    p[idx] = sunCore
                } else {
                    let t: Int = (900 - d2) / 14
                    let cc = p[idx]
                    let r = Int(cc & 255) + t
                    let g = Int((cc >> 8) & 255) + t
                    let bl = Int((cc >> 16) & 255) + t / 2
                    p[idx] = TrueColorBuffer.rgb(r, g, bl)
                }
            }
          }
        }
        // clouds
        let cloudX: [Int] = [20, 130, 260, 350, 450]
        let cloudY: [Int] = [20, 44, 14, 52, 30]
        let cloudW: [Int] = [60, 44, 70, 50, 56]
        let cloudShift: Int = Int(bgOff * 0.2)
        let white = TrueColorBuffer.rgb(255, 255, 255)
        for i in 0..<5 {
            let cx0: Int = (((cloudX[i] - cloudShift) % 512) + 512) % 512 - 100
            let cy0 = cloudY[i]
            let cw = cloudW[i]
            let widths: [Int] = [cw / 2, cw * 4 / 5, cw, cw * 9 / 10, cw / 2]
            for r in 0..<5 {
                let yy = cy0 + r
                if yy < 0 || yy >= h { continue }
                let half = widths[r] / 2
                span(p, yy * w, cx0 - half, cx0 + half, white)
            }
        }
        // mountains
        let far = SnowSlalom64.farHill
        let near = SnowSlalom64.nearHill
        let farShift: Int = Int(bgOff * 0.4)
        let nearShift: Int = Int(bgOff * 0.8)
        let farCol = TrueColorBuffer.rgb(150, 178, 218)
        let farCap = TrueColorBuffer.rgb(250, 252, 255)
        let nearCol = TrueColorBuffer.rgb(88, 124, 176)
        let nearCap = TrueColorBuffer.rgb(226, 238, 252)
        for x in 0..<min(w, 320) {
            let fi = (x + farShift) & 511
            let hf = far[fi]
            let top = hzI - hf
            let capH = max(0, (hf - 30) / 2 + 2)
            for yy in max(0, top)..<hzI {
                let c: UInt32 = (yy - top) < capH ? farCap : farCol
                p[yy * w + x] = c
            }
            let ni = (x + nearShift) & 511
            let hn = near[ni]
            let topN = hzI - hn
            let capN = hn > 20 ? (hn - 20) / 2 : 0
            for yy in max(0, topN)..<hzI {
                let c: UInt32 = (yy - topN) < capN ? nearCap : nearCol
                p[yy * w + x] = c
            }
        }
    }

    private func renderStrips(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        let c = course
        let roadW = SnowSlalom64.roadW
        let groundA = TrueColorBuffer.rgb(246, 250, 255)
        let groundB = TrueColorBuffer.rgb(224, 236, 252)
        let roadA = TrueColorBuffer.rgb(150, 186, 234)
        let roadB = TrueColorBuffer.rgb(130, 168, 224)
        let edgeA = TrueColorBuffer.rgb(236, 70, 56)
        let edgeB = TrueColorBuffer.rgb(255, 255, 255)
        let centre = TrueColorBuffer.rgb(255, 255, 255)
        let rampA = TrueColorBuffer.rgb(246, 198, 64)
        let rampB = TrueColorBuffer.rgb(222, 150, 40)
        let boostA = TrueColorBuffer.rgb(255, 236, 70)
        let boostB = TrueColorBuffer.rgb(255, 150, 30)
        let iceA = TrueColorBuffer.rgb(150, 238, 255)
        let iceB = TrueColorBuffer.rgb(214, 250, 255)
        var n = SnowSlalom64.drawN - 1
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
            let fg = SnowSlalom64.fogAmount(gZ1[n])
            let alt = ((idx / 2) & 1) == 0
            let dk = c.decal[idx]
            let ground = SnowSlalom64.mixHaze(alt ? groundA : groundB, fg)
            var road = alt ? roadA : roadB
            if dk == 3 { road = alt ? rampA : rampB }
            road = SnowSlalom64.mixHaze(road, fg)
            let edge = SnowSlalom64.mixHaze(alt ? edgeA : edgeB, fg)
            let line = SnowSlalom64.mixHaze(centre, fg)
            var dc: UInt32 = 0
            if dk == 1 { dc = SnowSlalom64.mixHaze(alt ? boostA : boostB, fg) }
            if dk == 2 { dc = SnowSlalom64.mixHaze(alt ? iceA : iceB, fg) }
            let dOff = c.decalOff[idx]
            let dHalf = c.decalHalf[idx]
            let yt: Float = max(0, y2)
            let r0 = Int(yt)
            let r1 = min(h, Int(bot))
            if r0 >= r1 { continue }
            let invD: Float = 1.0 / max(0.001, y1 - y2)
            var r = r0
            while r < r1 {
                let t: Float = (Float(r) - y2) * invD
                let cx: Float = cx2 + (cx1 - cx2) * t
                let hw: Float = hw2 + (hw1 - hw2) * t
                let xl = Int(clamp(cx - hw, -2000, 2000))
                let xr = Int(clamp(cx + hw, -2000, 2000))
                let base = r * w
                span(p, base, 0, xl, ground)
                span(p, base, xr, w, ground)
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
                if alt && dk != 3 && hw > 8 {
                    var lw = Int(hw * 0.018)
                    if lw < 1 { lw = 1 }
                    let ci = Int(cx)
                    span(p, base, ci - lw, ci + lw, line)
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
        spr.pix.withUnsafeBufferPointer { sp in
            for y in yStart..<yEnd {
                let ry = y - y0
                let sy = max(0, min(sprH - 1, (ry * stepY) >> 16))
                let srow = sy * sprW
                let rowBase = y * w
                for x in xs..<xe {
                    let sxp = max(0, min(sprW - 1, ((x - x0) * stepX) >> 16))
                    let c = sp[srow + sxp]
                    if c != 0 {
                        if fog > 0 {
                            p[rowBase + x] = SnowSlalom64.mixHaze(c, fog)
                        } else {
                            p[rowBase + x] = c
                        }
                    }
                }
            }
        }
    }

    private func renderSprites(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        let c = course
        let sprs = SnowSlalom64.sprites
        let roadW = SnowSlalom64.roadW
        let seg = SnowSlalom64.segLen
        var n = SnowSlalom64.drawN - 1
        while n >= 0 {
            defer { n -= 1 }
            if !gOK[n] { continue }
            let idx = geoBase + n
            if idx < 0 || idx >= c.total { continue }
            let clip = Int(clamp(gClip[n], -1000, 1000))
            let fog = SnowSlalom64.fogAmount(gZ1[n])
            let list = c.sprites[idx]
            for s in list {
                if s.kind < 0 || s.kind >= sprs.count { continue }
                let cx: Float = gCX1[n] + gP1[n] * s.off * roadW
                blit(p, w, h, sprs[s.kind], cx, gY1[n], gP1[n], clip, fog)
            }
            for b in boarders {
                let bi = Int(max(0, b.z) / seg)
                if bi != idx { continue }
                if b.kind < 0 || b.kind >= sprs.count { continue }
                var pct: Float = b.z / seg - Float(bi)
                if !(pct >= 0) { pct = 0 }
                if pct > 1 { pct = 1 }
                let ppu: Float = gP1[n] + (gP2[n] - gP1[n]) * pct
                let cxm: Float = gCX1[n] + (gCX2[n] - gCX1[n]) * pct
                let ym: Float = gY1[n] + (gY2[n] - gY1[n]) * pct
                let cx: Float = cxm + ppu * b.x * roadW
                blit(p, w, h, sprs[b.kind], cx, ym, ppu, clip, fog)
            }
        }
    }

    override func drawTrueColor(_ b: TrueColorBuffer) {
        buildGeometry()
        b.withPixels { p, w, h in
            if w != 320 || h != 288 { return }
            self.renderBackground(p, w, h)
            self.renderStrips(p, w, h)
            self.renderSprites(p, w, h)
        }
        drawPlayer(b)
        drawEffects(b)
        drawHUD(b)
        drawOverlays(b)
    }

    // MARK: - Player

    private func drawPlayer(_ b: TrueColorBuffer) {
        let ppuP: Float = SnowSlalom64.camDepth * 160 / SnowSlalom64.playerDist
        let camYw: Float = camBase + SnowSlalom64.camH
        var byF: Float = SnowSlalom64.horizonY + ppuP * (camYw - py)
        let gyF: Float = SnowSlalom64.horizonY + ppuP * (camYw - groundNow)
        byF = clamp(byF, 40, 300)
        let by = Int(byF)
        let gy = Int(clamp(gyF, 40, 300))
        let cx = 160
        // ground shadow when airborne
        if !grounded {
            let air = max(0, gy - by)
            let sw = max(10, 30 - air / 6)
            b.fillRect(cx - sw / 2, gy - 1, sw, 3, TrueColorBuffer.rgb(120, 140, 190))
        }
        if phase == .results && wipe > 0 { return }
        let flick: Bool = ((frame / 3) & 1) == 0
        if invuln > 0 && wipe == 0 && flick && phase == .racing { return }
        let tuck = phase == .racing && wipe == 0 && lastInputA
        let jacket = TrueColorBuffer.rgb(236, 56, 56)
        let jacketD = TrueColorBuffer.rgb(170, 30, 40)
        let pants = TrueColorBuffer.rgb(36, 48, 110)
        let helm = TrueColorBuffer.rgb(70, 150, 255)
        let skin = TrueColorBuffer.rgb(255, 214, 180)
        let boardTop = TrueColorBuffer.rgb(255, 150, 30)
        let boardEdge = TrueColorBuffer.rgb(60, 60, 78)
        let white = SnowSlalom64.cWhite
        let dark = SnowSlalom64.cBlack
        if wipe > 0 {
            let t: Float = Float(wipeAge) * 0.35
            let bx = cx + Int(cos(t) * 20)
            let bY = by - 12 - Int(sin(t * 1.3) * 10)
            b.fillRect(bx - 12, bY, 24, 5, boardTop)
            b.fillRect(bx - 12, bY + 4, 24, 1, boardEdge)
            let rx = cx - Int(cos(t * 0.8) * 8)
            let rY = by - 18 - Int(sin(t) * 10)
            b.fillRect(rx - 7, rY, 14, 14, jacket)
            b.fillRect(rx - 5, rY - 9, 10, 9, helm)
            b.fillRect(rx - 9, rY + 14, 5, 8, pants)
            b.fillRect(rx + 4, rY + 14, 5, 8, pants)
            for i in 0..<3 {
                let a: Float = t * 1.7 + Float(i) * 2.1
                let sx = cx + Int(cos(a) * 22)
                let sy = by - 44 + Int(sin(a) * 6)
                b.fillRect(sx - 2, sy, 5, 1, SnowSlalom64.cYellow)
                b.fillRect(sx, sy - 2, 1, 5, SnowSlalom64.cYellow)
            }
            return
        }
        let sa: Float = abs(sin(spinAngle))
        let ca: Float = cos(spinAngle)
        let aca: Float = abs(ca)
        let shift = Int(lean * 5)
        // board
        let bw = 6 + Int(26 * (sa * 0.9 + aca * 0.2))
        let segN = 5
        let segW = max(2, bw / segN)
        for j in 0..<segN {
            let jx = cx - (segN * segW) / 2 + j * segW + shift / 2
            let tilt = Int(lean * Float(j - 2) * 1.6)
            b.fillRect(jx, by - 5 + tilt, segW, 4, boardTop)
            b.fillRect(jx, by - 2 + tilt, segW, 2, boardEdge)
        }
        // legs
        let legH = tuck ? 6 : 10
        let torsoW = max(5, Int(16 * (aca * 0.6 + 0.4)))
        b.fillRect(cx - torsoW / 2 + shift, by - 5 - legH, torsoW / 2 - 1, legH, pants)
        b.fillRect(cx + 1 + shift, by - 5 - legH, torsoW / 2 - 1, legH, pants)
        // torso
        let torsoH = tuck ? 12 : 16
        let ty = by - 5 - legH - torsoH
        b.fillRect(cx - torsoW / 2 + shift, ty, torsoW, torsoH, jacket)
        b.fillRect(cx - torsoW / 2 + shift, ty + torsoH / 2, torsoW, 2, jacketD)
        if ca > 0 {
            b.fillRect(cx - 1 + shift, ty, 2, torsoH, white)
        }
        // arms
        let armH = tuck ? 6 : 11
        b.fillRect(cx - torsoW / 2 - 4 + shift, ty + 2, 4, armH, jacketD)
        b.fillRect(cx + torsoW / 2 + shift, ty + 2, 4, armH, jacketD)
        // head
        let headY = ty - 9 + (tuck ? 3 : 0)
        let headW = max(5, Int(10 * (aca * 0.5 + 0.5)))
        b.fillRect(cx - headW / 2 + shift, headY, headW, 9, ca >= 0 ? helm : skin)
        b.fillRect(cx - headW / 2 + shift, headY + 4, headW, 2, dark)
        b.fillRect(cx - 1 + shift, headY - 2, 3, 3, white)
    }

    private var lastInputA = false

    // MARK: - Effects

    private func drawEffects(_ b: TrueColorBuffer) {
        let white = SnowSlalom64.cWhite
        if phase == .racing || phase == .finishing {
            if grounded && speed > 0.3 && wipe == 0 {
                let ppuP: Float = SnowSlalom64.camDepth * 160 / SnowSlalom64.playerDist
                let camYw: Float = camBase + SnowSlalom64.camH
                let gy = Int(clamp(SnowSlalom64.horizonY + ppuP * (camYw - groundNow), 40, 300))
                let spray = abs(xVel) > 0.014 || onIce
                let count = spray ? 9 : 4
                for i in 0..<count {
                    let hsh = (frame * 7919 + i * 104729) & 255
                    var ox = (hsh % 24) - 12
                    if spray { ox += xVel > 0 ? -14 : 14 }
                    let oy = (hsh / 5) % 9
                    let sz = 2 + (hsh & 1)
                    b.fillRect(160 + ox, gy - oy, sz, sz, white)
                }
            }
            if boostTimer > 0 {
                let streakC = TrueColorBuffer.rgb(255, 244, 190)
                for i in 0..<12 {
                    let yy = 60 + ((i * 47 + frame * 12) % 200)
                    let len = 12 + ((i * 7) % 14)
                    let left = (i & 1) == 0
                    let xx = left ? ((i * 13 + frame * 6) % 50) : (320 - len - ((i * 17 + frame * 6) % 50))
                    b.fillRect(xx, yy, len, 1, streakC)
                }
            } else if speed > 1.0 {
                for i in 0..<6 {
                    let yy = 80 + ((i * 41 + frame * 9) % 180)
                    let left = (i & 1) == 0
                    let xx = left ? ((i * 11 + frame * 5) % 24) : (310 - ((i * 19 + frame * 5) % 24))
                    b.fillRect(xx, yy, 8, 1, white)
                }
            }
        }
    }

    // MARK: - HUD

    private func otext(_ b: TrueColorBuffer, _ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        let k = max(1, scale / 2)
        let o = SnowSlalom64.cBlack
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

    private func timeString(_ f: Int) -> String {
        let t = max(0, f)
        let sec = t / 60
        let tenths = ((t % 60) * 10) / 60
        return String(sec / 60) + ":" + zeroPad(sec % 60, 2) + "." + String(tenths)
    }

    private func drawHUD(_ b: TrueColorBuffer) {
        if phase == .title { return }
        let white = SnowSlalom64.cWhite
        let yellow = SnowSlalom64.cYellow
        // time
        var tcol = white
        if timeLeft < 600 && phase == .racing && (frame / 8) & 1 == 0 { tcol = SnowSlalom64.cRed }
        let secs = (timeLeft + 59) / 60
        otext(b, "TIME", 8, 6, white, 1)
        otext(b, String(secs), 8, 14, tcol, 4)
        // score
        let sc = zeroPad(score, 6)
        let sw = b.textWidth(sc, scale: 2)
        otext(b, "SCORE", 312 - b.textWidth("SCORE", scale: 1), 6, white, 1)
        otext(b, sc, 312 - sw, 14, white, 2)
        if streak > 1 && phase == .racing {
            let st = "GATE X" + String(min(streak, 6))
            let stw = b.textWidth(st, scale: 1)
            otext(b, st, 312 - stw, 34, SnowSlalom64.cGreen, 1)
        }
        // speed
        let kmh = Int(speed * 120)
        otext(b, String(kmh) + " KMH", 8, 262, white, 2)
        b.fillRect(6, 278, 92, 8, SnowSlalom64.cBlack)
        b.fillRect(8, 280, 88, 4, TrueColorBuffer.rgb(50, 60, 90))
        let frac: Float = clamp(speed / 1.3, 0, 1)
        let fw = Int(frac * 88)
        var bc = SnowSlalom64.cGreen
        if frac > 0.8 { bc = SnowSlalom64.cRed } else if frac > 0.55 { bc = yellow }
        if fw > 0 { b.fillRect(8, 280, fw, 4, bc) }
        // progress bar with checkpoints
        let barX = 112
        let barW = 160
        let barY = 278
        b.fillRect(barX - 2, barY - 2, barW + 4, 10, SnowSlalom64.cBlack)
        b.fillRect(barX, barY, barW, 6, TrueColorBuffer.rgb(50, 60, 90))
        let playerSeg: Float = (pos + SnowSlalom64.playerDist) / SnowSlalom64.segLen
        let prog: Float = clamp(playerSeg / Float(SnowSlalom64.courseSegs), 0, 1)
        let pw = Int(prog * Float(barW))
        if pw > 0 { b.fillRect(barX, barY, pw, 6, SnowSlalom64.cCyan) }
        for k in 1...3 {
            let tx = barX + barW * k / 4
            b.fillRect(tx, barY - 2, 2, 10, k <= cpPassed ? SnowSlalom64.cGreen : yellow)
        }
        b.fillRect(barX + pw - 1, barY - 3, 4, 12, white)
        // messages
        if phase == .racing || phase == .finishing {
            if msgTimer > 0 { ctext(b, msg, 70, msgColor, 3) }
        }
    }

    private func drawOverlays(_ b: TrueColorBuffer) {
        let yellow = SnowSlalom64.cYellow
        let white = SnowSlalom64.cWhite
        switch phase {
        case .title:
            b.fillRect(22, 40, 276, 160, SnowSlalom64.cBlack)
            b.fillRect(24, 42, 272, 156, SnowSlalom64.cPanel)
            b.fillRect(24, 42, 272, 3, yellow)
            b.fillRect(24, 195, 272, 3, yellow)
            ctext(b, "SNOW SLALOM", 54, white, 5)
            ctext(b, "64", 92, yellow, 8)
            ctext(b, "GATES  JUMPS  CHECKPOINTS", 140, SnowSlalom64.cCyan, 1)
            if (frame / 30) & 1 == 0 { ctext(b, "PRESS A TO RACE", 156, SnowSlalom64.cGreen, 3) }
            ctext(b, "LEFT RIGHT CARVE  A TUCK  B BRAKE", 182, white, 1)
            ctext(b, "HOLD B IN THE AIR TO SPIN", 218, white, 1)
        case .countdown:
            if cdTimer > 140 {
                ctext(b, "GET READY", 64, white, 5)
            } else if cdTimer > 0 {
                let d = (cdTimer + 59) / 60
                ctext(b, String(d), 50, yellow, 14)
            }
            ctext(b, "A TUCKS FOR SPEED", 180, white, 1)
        case .racing:
            if wipe > 0 { ctext(b, "WIPEOUT", 100, SnowSlalom64.cRed, 4) }
        case .finishing:
            break
        case .results:
            b.fillRect(38, 50, 244, 190, SnowSlalom64.cBlack)
            b.fillRect(40, 52, 240, 186, SnowSlalom64.cPanel)
            b.fillRect(40, 52, 240, 3, yellow)
            if timeUp {
                ctext(b, "TIME UP", 64, SnowSlalom64.cRed, 5)
                let pct = Int(clamp((pos + SnowSlalom64.playerDist) / SnowSlalom64.segLen / Float(SnowSlalom64.courseSegs), 0, 1) * 100)
                ctext(b, "REACHED " + String(pct) + "%", 106, white, 2)
            } else {
                ctext(b, "FINISH!", 64, SnowSlalom64.cGreen, 5)
                ctext(b, "TIME " + timeString(raceFrames), 106, white, 2)
            }
            ctext(b, "GATES " + String(gatesHit) + "/" + String(gatesHit + gatesMissed), 128, white, 2)
            ctext(b, "TRICKS " + String(trickScore), 148, SnowSlalom64.cCyan, 2)
            ctext(b, "SCORE", 176, white, 2)
            ctext(b, zeroPad(score, 6), 194, yellow, 4)
            if resultTimer > 40 && (frame / 30) & 1 == 0 { ctext(b, "PRESS A", 222, white, 1) }
        }
    }
}

extension Cartridge {
    static let snowSlalom64 = Cartridge(
        id: "snowslalom64", title: "SNOW SLALOM 64", genre: "Racing",
        blurb: "Carve a pseudo-3D mountain run: slalom gates, ramps and spin tricks, boost pads, icy patches and rival boarders against the clock.",
        controls: "LEFT/RIGHT carve, A tuck for speed, B brake. Hold B in the air to spin for bonus points.",
        era: .n64, labelTop: 0x7EC8FF, labelBottom: 0x2A3F8E, factory: { SnowSlalom64() })
}
