#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// KART RALLY 64: a Mode-7 style kart racer. Perspective floor drawn per scanline from a procedurally
/// generated 512x512 true-colour track, billboarded karts / trees / signs, three laps against three rivals.
final class KartRally64: Game {
    // MARK: - Constants

    private static let horizon = 104
    private static let focal: Float = 200
    private static let camHeight: Float = 30
    private static let camDist: Float = 40
    private static let maxDist: Float = 620
    private static let fogStart: Float = 200
    private static let hazeR = 178
    private static let hazeG = 214
    private static let hazeB = 244
    private static let maxSpeed: Float = 1.85
    private static let totalLaps = 3

    private static let hazeColor: UInt32 = TrueColorBuffer.rgb(178, 214, 244)
    private static let outsideColor: UInt32 = TrueColorBuffer.rgb(46, 124, 50)
    private static let cWhite: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    private static let cBlack: UInt32 = TrueColorBuffer.rgb(10, 10, 16)
    private static let cYellow: UInt32 = TrueColorBuffer.rgb(255, 226, 64)
    private static let cRed: UInt32 = TrueColorBuffer.rgb(244, 64, 52)
    private static let cGreen: UInt32 = TrueColorBuffer.rgb(90, 255, 110)
    private static let cPanel: UInt32 = TrueColorBuffer.rgb(14, 16, 44)
    private static let kartCols: [UInt32] = [
        TrueColorBuffer.rgb(240, 50, 50),
        TrueColorBuffer.rgb(60, 120, 255),
        TrueColorBuffer.rgb(255, 224, 50),
        TrueColorBuffer.rgb(190, 80, 240)
    ]
    private static let placeNames: [String] = ["1ST", "2ND", "3RD", "4TH"]

    // MARK: - Static tables

    private static let rowDist: [Float] = {
        var a = [Float](repeating: 100000, count: 288)
        let k: Float = KartRally64.camHeight * KartRally64.focal
        for r in 1..<288 { a[r] = k / Float(r) }
        return a
    }()

    private static let rowFog: [Int] = {
        var a = [Int](repeating: 0, count: 288)
        let k: Float = KartRally64.camHeight * KartRally64.focal
        for r in 1..<288 { a[r] = KartRally64.fogAmount(k / Float(r)) }
        return a
    }()

    private static let skyRows: [UInt32] = {
        var a = [UInt32](repeating: 0, count: 104)
        for y in 0..<104 {
            let t: Float = Float(y) / 104.0
            let r = Int(56 + (178 - 56) * t)
            let g = Int(108 + (214 - 108) * t)
            let b = Int(212 + (244 - 212) * t)
            a[y] = TrueColorBuffer.rgb(r, g, b)
        }
        return a
    }()

    private static let colAngle: [Float] = {
        var a = [Float](repeating: 0, count: 320)
        for x in 0..<320 {
            let dx: Float = Float(x - 160) + 0.5
            a[x] = atan(dx / KartRally64.focal)
        }
        return a
    }()

    private static let hillFar: [Int] = {
        var a = [Int](repeating: 4, count: 1024)
        for i in 0..<1024 {
            let ang: Float = Float(i) / 1024.0 * 2.0 * Float.pi
            let f1: Float = 11 * sin(ang * 3 + 0.5)
            let f2: Float = 7 * sin(ang * 7 + 2.0)
            let f3: Float = 3 * sin(ang * 17)
            let f: Float = 22 + f1 + f2 + f3
            a[i] = max(4, Int(f))
        }
        return a
    }()

    private static let hillNear: [Int] = {
        var a = [Int](repeating: 2, count: 1024)
        for i in 0..<1024 {
            let ang: Float = Float(i) / 1024.0 * 2.0 * Float.pi
            let f1: Float = 7 * sin(ang * 5 + 1.0)
            let f2: Float = 5 * sin(ang * 11 + 4.0)
            let f3: Float = 2 * sin(ang * 23)
            let f: Float = 10 + f1 + f2 + f3
            a[i] = max(2, Int(f))
        }
        return a
    }()

    private static let track = TrackData()
    private static let sprites: [SpriteImg] = KartRally64.makeSprites()

    private static let sprTree = 0
    private static let sprPine = 1
    private static let sprSign = 2
    private static let sprArch = 3
    private static let sprKart0 = 4

    static func fogAmount(_ z: Float) -> Int {
        if z <= KartRally64.fogStart { return 0 }
        let span: Float = KartRally64.maxDist - KartRally64.fogStart
        var t: Float = (z - KartRally64.fogStart) / span
        if t < 0 { t = 0 }
        if t > 1 { t = 1 }
        return Int(t * 256)
    }

    @inline(__always) static func mix(_ c: UInt32, _ t: Int) -> UInt32 {
        let r = Int(c & 255)
        let g = Int((c >> 8) & 255)
        let bl = Int((c >> 16) & 255)
        let r2 = r + (((KartRally64.hazeR - r) * t) >> 8)
        let g2 = g + (((KartRally64.hazeG - g) * t) >> 8)
        let b2 = bl + (((KartRally64.hazeB - bl) * t) >> 8)
        let rr = UInt32(max(0, min(255, r2)))
        let gg = UInt32(max(0, min(255, g2)))
        let bb = UInt32(max(0, min(255, b2)))
        return 0xFF00_0000 | rr | (gg << 8) | (bb << 16)
    }

    static func wrapAngle(_ a: Float) -> Float {
        if !a.isFinite { return 0 }
        var d = a
        while d > Float.pi { d -= 2 * Float.pi }
        while d < -Float.pi { d += 2 * Float.pi }
        return d
    }

    static func angleDiff(_ a: Float, _ b: Float) -> Float {
        return KartRally64.wrapAngle(a - b)
    }

    // MARK: - Nested types

    struct Kart {
        var x: Float = 0
        var y: Float = 0
        var heading: Float = 0
        var speed: Float = 0
        var idx: Int = 0
        var cum: Int = 0
        var lapsCounted: Int = 0
        var finished: Bool = false
        var finishFrame: Int = 0
        var spr: Int = 4
        var lane: Float = 0
        var skill: Float = 0.9
    }

    struct DrawItem {
        var depth: Float
        var sx: Int
        var bottom: Int
        var sw: Int
        var sh: Int
        var spr: Int
        var fog: Int
        var shear: Int
        var flip: Bool
    }

    struct Prop {
        var x: Float
        var y: Float
        var spr: Int
        var flip: Bool
    }

    struct SpriteImg {
        var w: Int
        var h: Int
        var pix: [UInt32]
        var worldW: Float
        var worldH: Float
    }

    enum Phase { case title, countdown, racing, finished }

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

    // MARK: - Track data (generated once, shared)

    final class TrackData {
        let tex: UnsafeMutablePointer<UInt32> = UnsafeMutablePointer<UInt32>.allocate(capacity: 262144)
        var surf: [UInt8] = [UInt8](repeating: 0, count: 262144)
        var denseX: [Float] = []
        var denseY: [Float] = []
        var wpx: [Float] = []
        var wpy: [Float] = []
        var wtx: [Float] = []
        var wty: [Float] = []
        var wnx: [Float] = []
        var wny: [Float] = []
        var count: Int = 0
        var spacing: Float = 12
        var props: [Prop] = []
        var miniX: [Int] = []
        var miniY: [Int] = []

        init() {
            tex.initialize(repeating: 0, count: 262144)
            build()
        }

        func surface(_ x: Float, _ y: Float) -> UInt8 {
            if !(x >= 0 && x < 511 && y >= 0 && y < 511) { return 0 }
            return surf[(Int(y) << 9) + Int(x)]
        }

        func hash(_ x: Int, _ y: Int) -> Int {
            var h: Int = x &* 374761393 &+ y &* 668265263
            h = (h ^ (h >> 13)) &* 1274126177
            return (h ^ (h >> 16)) & 0xFFFF
        }

        func build() {
            paintGrass()
            makeCenterline()
            paintShortcut(330, 64, 440, 235)
            paintShortcut(158, 238, 155, 100)
            paintRoad()
            resample()
            placeProps()
        }

        func paintGrass() {
            for y in 0..<512 {
                for x in 0..<512 {
                    let n = hash(x, y) & 15
                    let blotch = hash(x >> 3, y >> 3) & 7
                    var g = 118 + blotch * 3 + n
                    if (((x >> 5) ^ (y >> 5)) & 1) == 1 { g -= 12 }
                    let r = 40 + (blotch & 3) * 2 + (n >> 2)
                    let bl = 44 + (n >> 1)
                    tex[(y << 9) + x] = TrueColorBuffer.rgb(r, g, bl)
                    surf[(y << 9) + x] = 0
                }
            }
        }

        func catmull(_ p0: Float, _ p1: Float, _ p2: Float, _ p3: Float, _ t: Float) -> Float {
            let t2: Float = t * t
            let t3: Float = t2 * t
            let a: Float = 2 * p1
            let b: Float = (p2 - p0) * t
            let c: Float = (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
            let d: Float = (3 * p1 - p0 - 3 * p2 + p3) * t3
            return 0.5 * (a + b + c + d)
        }

        func makeCenterline() {
            let px: [Float] = [256, 390, 455, 440, 350, 390, 370, 280, 200, 130, 65, 70, 150, 100, 150]
            let py: [Float] = [60, 70, 150, 240, 270, 350, 440, 450, 415, 440, 390, 300, 250, 170, 90]
            let n = px.count
            for i in 0..<n {
                let i0 = (i + n - 1) % n
                let i1 = i
                let i2 = (i + 1) % n
                let i3 = (i + 2) % n
                for s in 0..<40 {
                    let t: Float = Float(s) / 40.0
                    var x = catmull(px[i0], px[i1], px[i2], px[i3], t)
                    var y = catmull(py[i0], py[i1], py[i2], py[i3], t)
                    x = max(40, min(470, x))
                    y = max(40, min(470, y))
                    denseX.append(x)
                    denseY.append(y)
                }
            }
        }

        func stamp(_ cx: Float, _ cy: Float, _ r: Float, _ r0: Int, _ g0: Int, _ b0: Int, _ noise: Int, _ sid: UInt8) {
            let x0 = max(0, Int(cx - r))
            let x1 = min(511, Int(cx + r) + 1)
            let y0 = max(0, Int(cy - r))
            let y1 = min(511, Int(cy + r) + 1)
            if x0 > x1 || y0 > y1 { return }
            let r2: Float = r * r
            for y in y0...y1 {
                let dy: Float = Float(y) - cy
                for x in x0...x1 {
                    let dx: Float = Float(x) - cx
                    if dx * dx + dy * dy <= r2 {
                        var rr = r0
                        var gg = g0
                        var bb = b0
                        if noise > 0 {
                            let d = ((hash(x, y) & 7) - 3) * noise
                            rr += d
                            gg += d
                            bb += d
                        }
                        tex[(y << 9) + x] = TrueColorBuffer.rgb(rr, gg, bb)
                        surf[(y << 9) + x] = sid
                    }
                }
            }
        }

        func paintShortcut(_ ax: Float, _ ay: Float, _ bx: Float, _ by: Float) {
            let dx: Float = bx - ax
            let dy: Float = by - ay
            let len: Float = sqrt(dx * dx + dy * dy)
            let steps = max(1, Int(len / 2))
            for i in 0...steps {
                let t: Float = Float(i) / Float(steps)
                stamp(ax + dx * t, ay + dy * t, 10, 232, 208, 130, 2, 3)
            }
        }

        func paintRoad() {
            let n = denseX.count
            if n < 4 { return }
            for i in 0..<n {
                if ((i / 3) & 1) == 0 {
                    stamp(denseX[i], denseY[i], 30, 214, 40, 40, 0, 2)
                } else {
                    stamp(denseX[i], denseY[i], 30, 240, 240, 240, 0, 2)
                }
            }
            for i in 0..<n {
                var tone = 0
                if ((i / 5) & 1) == 1 { tone = -10 }
                stamp(denseX[i], denseY[i], 24, 142 + tone, 144 + tone, 154 + tone, 1, 1)
            }
            for i in 0..<n {
                if ((i / 6) & 1) == 0 {
                    stamp(denseX[i], denseY[i], 1.8, 236, 236, 236, 0, 1)
                }
            }
            // Checkered start / finish line at the first sample.
            var tx: Float = denseX[1] - denseX[0]
            var ty: Float = denseY[1] - denseY[0]
            let tl: Float = max(0.0001, sqrt(tx * tx + ty * ty))
            tx /= tl
            ty /= tl
            let nx: Float = -ty
            let ny: Float = tx
            var u: Float = -24
            while u <= 24 {
                var v: Float = -4
                while v < 4 {
                    let cx: Float = denseX[0] + nx * u + tx * v
                    let cy: Float = denseY[0] + ny * u + ty * v
                    if cx >= 0 && cx < 511 && cy >= 0 && cy < 511 {
                        let cu = Int((u + 24) / 4)
                        let cv = Int((v + 4) / 4)
                        let white = ((cu + cv) & 1) == 0
                        let idx = (Int(cy) << 9) + Int(cx)
                        tex[idx] = white ? TrueColorBuffer.rgb(245, 245, 245) : TrueColorBuffer.rgb(20, 20, 24)
                        surf[idx] = 1
                    }
                    v += 0.5
                }
                u += 0.5
            }
        }

        func resample() {
            let n = denseX.count
            if n < 4 { return }
            var cum = [Float](repeating: 0, count: n + 1)
            for i in 1...n {
                let a = i - 1
                let b = i % n
                let dx: Float = denseX[b] - denseX[a]
                let dy: Float = denseY[b] - denseY[a]
                cum[i] = cum[i - 1] + sqrt(dx * dx + dy * dy)
            }
            let total = cum[n]
            let m = max(40, Int(total / 12))
            spacing = total / Float(m)
            var j = 0
            for k in 0..<m {
                let target: Float = spacing * Float(k)
                while j < n - 1 && cum[j + 1] <= target { j += 1 }
                let segLen: Float = max(0.0001, cum[j + 1] - cum[j])
                var t: Float = (target - cum[j]) / segLen
                if t < 0 { t = 0 }
                if t > 1 { t = 1 }
                let j2 = (j + 1) % n
                wpx.append(denseX[j] + (denseX[j2] - denseX[j]) * t)
                wpy.append(denseY[j] + (denseY[j2] - denseY[j]) * t)
            }
            count = m
            for k in 0..<m {
                let a = (k + m - 1) % m
                let b = (k + 1) % m
                var tx: Float = wpx[b] - wpx[a]
                var ty: Float = wpy[b] - wpy[a]
                let l: Float = max(0.0001, sqrt(tx * tx + ty * ty))
                tx /= l
                ty /= l
                wtx.append(tx)
                wty.append(ty)
                wnx.append(-ty)
                wny.append(tx)
                let mx = max(0, min(59, Int(wpx[k] * 0.1171875)))
                let my = max(0, min(59, Int(wpy[k] * 0.1171875)))
                miniX.append(mx)
                miniY.append(my)
            }
        }

        func farFromTrack(_ x: Float, _ y: Float, _ minDist: Float) -> Bool {
            let r2: Float = minDist * minDist
            for i in 0..<count {
                let dx: Float = wpx[i] - x
                let dy: Float = wpy[i] - y
                if dx * dx + dy * dy < r2 { return false }
            }
            return true
        }

        func placeProps() {
            let m = count
            if m < 8 { return }
            props.append(Prop(x: wpx[0], y: wpy[0], spr: 3, flip: false))
            var k = 1
            while k < m {
                for side in 0..<2 {
                    let h = hash(k * 7 + side, 91)
                    if (h & 3) == 0 { continue }
                    let off: Float = 40 + Float(h % 30)
                    let sgn: Float = side == 0 ? -1 : 1
                    let ox: Float = wpx[k] + wnx[k] * off * sgn
                    let oy: Float = wpy[k] + wny[k] * off * sgn
                    if ox < 10 || ox > 500 || oy < 10 || oy > 500 { continue }
                    if surface(ox, oy) != 0 { continue }
                    if !farFromTrack(ox, oy, 36) { continue }
                    props.append(Prop(x: ox, y: oy, spr: (h >> 4) & 1, flip: ((h >> 5) & 1) == 1))
                }
                k += 2
            }
            var s = 4
            while s < m {
                let k2 = (s + 5) % m
                let cross: Float = wtx[s] * wty[k2] - wty[s] * wtx[k2]
                if abs(cross) > 0.30 {
                    let sgn: Float = cross > 0 ? -1 : 1
                    let ox: Float = wpx[s] + wnx[s] * 42 * sgn
                    let oy: Float = wpy[s] + wny[s] * 42 * sgn
                    if ox > 10 && ox < 500 && oy > 10 && oy < 500 && farFromTrack(ox, oy, 34) && surface(ox, oy) == 0 {
                        props.append(Prop(x: ox, y: oy, spr: 2, flip: cross < 0))
                    }
                }
                s += 4
            }
        }
    }

    // MARK: - Sprite generation

    static func col(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
        return TrueColorBuffer.rgb(r, g, b)
    }

    static func finish(_ p: Pix, _ ww: Float, _ wh: Float) -> SpriteImg {
        return SpriteImg(w: p.w, h: p.h, pix: p.d, worldW: ww, worldH: wh)
    }

    static func makeKartSprite(_ r: Int, _ g: Int, _ bl: Int) -> SpriteImg {
        var p = Pix(24, 18)
        let body = col(r, g, bl)
        let light = col(r + 55, g + 55, bl + 55)
        let dark = col(r - 70, g - 70, bl - 70)
        let wheel = col(24, 24, 30)
        let wheelHi = col(110, 110, 124)
        let metal = col(90, 90, 100)
        p.rect(2, 16, 20, 2, col(40, 40, 48))
        p.rect(0, 8, 5, 8, wheel)
        p.rect(19, 8, 5, 8, wheel)
        p.rect(1, 9, 1, 5, wheelHi)
        p.rect(22, 9, 1, 5, wheelHi)
        p.rect(4, 7, 16, 8, dark)
        p.rect(4, 6, 16, 7, body)
        p.rect(6, 5, 12, 2, body)
        p.rect(4, 11, 16, 1, light)
        p.rect(6, 5, 2, 3, metal)
        p.rect(16, 5, 2, 3, metal)
        p.rect(2, 2, 20, 3, dark)
        p.rect(2, 2, 20, 1, light)
        p.rect(9, 9, 6, 3, light)
        p.disc(12, 7, 3, col(245, 245, 245))
        p.rect(10, 6, 5, 2, col(30, 30, 70))
        p.rect(7, 14, 2, 2, metal)
        p.rect(15, 14, 2, 2, metal)
        p.outline(col(12, 12, 18))
        return finish(p, 16, 12)
    }

    static func makeTree() -> SpriteImg {
        var p = Pix(32, 48)
        let trunk = col(116, 76, 34)
        let trunkDark = col(70, 44, 20)
        let leafD = col(22, 86, 40)
        let leafL = col(92, 190, 76)
        let leafO = col(8, 40, 18)
        p.rect(14, 28, 5, 20, trunk)
        p.rect(17, 28, 2, 20, trunkDark)
        let centers: [[Int]] = [[16, 13, 12], [9, 22, 9], [23, 22, 9], [16, 25, 9]]
        for c in centers { p.disc(c[0], c[1], c[2] + 1, leafO) }
        for c in centers { p.disc(c[0], c[1], c[2], leafD) }
        p.disc(12, 9, 6, leafL)
        p.disc(7, 19, 3, leafL)
        p.disc(19, 16, 3, leafL)
        p.outline(leafO)
        return finish(p, 22, 32)
    }

    static func makePine() -> SpriteImg {
        var p = Pix(28, 44)
        let trunk = col(100, 64, 30)
        let dark = col(20, 84, 46)
        let light = col(84, 180, 96)
        p.rect(12, 34, 4, 10, trunk)
        for y in 0..<36 {
            let tier = y / 12
            let row = y % 12
            let hw = 2 + (row * 7) / 11 + tier * 2
            for x in (14 - hw)..<(14 + hw) {
                var c = dark
                if x < 14 - hw / 3 { c = light }
                p.set(x, y + 2, c)
            }
        }
        p.outline(col(6, 36, 20))
        return finish(p, 18, 28)
    }

    static func makeSign() -> SpriteImg {
        var p = Pix(20, 24)
        let red = col(220, 30, 30)
        p.rect(9, 12, 3, 12, col(120, 120, 130))
        p.rect(0, 0, 20, 14, col(20, 20, 30))
        p.rect(2, 2, 16, 10, col(250, 250, 250))
        p.rect(4, 6, 8, 2, red)
        for i in 0..<4 {
            p.rect(11 + i, 4 + i, 1, 6 - 2 * i, red)
        }
        return finish(p, 16, 19)
    }

    static func makeArch() -> SpriteImg {
        var p = Pix(64, 32)
        let post = col(210, 40, 40)
        p.rect(0, 8, 5, 24, post)
        p.rect(59, 8, 5, 24, post)
        p.rect(0, 8, 1, 24, col(120, 16, 16))
        p.rect(59, 8, 1, 24, col(120, 16, 16))
        for y in 0..<12 {
            for x in 0..<64 {
                let white = (((x / 4) + (y / 4)) & 1) == 0
                p.set(x, y, white ? col(245, 245, 245) : col(20, 20, 26))
            }
        }
        p.outline(col(10, 10, 14))
        return finish(p, 64, 32)
    }

    static func makeSprites() -> [SpriteImg] {
        var list: [SpriteImg] = []
        list.append(makeTree())
        list.append(makePine())
        list.append(makeSign())
        list.append(makeArch())
        list.append(makeKartSprite(236, 44, 44))
        list.append(makeKartSprite(56, 116, 255))
        list.append(makeKartSprite(255, 222, 48))
        list.append(makeKartSprite(186, 76, 240))
        return list
    }

    // MARK: - Game state

    private var phase: Phase = .title
    private var frame = 0
    private var karts: [Kart] = []
    private var items: [DrawItem] = []
    private var camX: Float = 0
    private var camY: Float = 0
    private var camHeading: Float = 0
    private var lean: Float = 0
    private var cdTimer = 0
    private var aHeld = 0
    private var boostTimer = 0
    private var raceFrames = 0
    private var lapStart = 0
    private var bestLap = 0
    private var place = 4
    private var finishTimer = 0
    private var msg = ""
    private var msgTimer = 0
    private var scoreValue = 0
    private var bumpCooldown = 0
    private var wrongWay = false
    private var playerOffroad = false
    private var playerSX = 160
    private var playerBottom = 250
    private var playerFinishFrame = 0

    override var score: Int { return max(0, scoreValue) }

    override init() {
        super.init()
        setupRace()
        phase = .title
    }

    override func start() {
        playMusic(Tunes.race)
    }

    // MARK: - Setup

    private func makeKart(back: Int, lane: Float, spr: Int, skill: Float) -> Kart {
        let tr = KartRally64.track
        let m = max(1, tr.count)
        let idx = ((m - back) % m + m) % m
        var k = Kart()
        if tr.count > 0 {
            k.x = tr.wpx[idx] + tr.wnx[idx] * lane
            k.y = tr.wpy[idx] + tr.wny[idx] * lane
            k.heading = atan2(tr.wty[idx], tr.wtx[idx])
        } else {
            k.x = 256
            k.y = 60
        }
        k.idx = idx
        k.cum = -back
        k.spr = spr
        k.lane = lane
        k.skill = skill
        return k
    }

    private func setupRace() {
        karts = []
        karts.append(makeKart(back: 6, lane: -9, spr: KartRally64.sprKart0, skill: 1.0))
        karts.append(makeKart(back: 3, lane: 9, spr: KartRally64.sprKart0 + 1, skill: 0.90))
        karts.append(makeKart(back: 4, lane: -9, spr: KartRally64.sprKart0 + 2, skill: 0.94))
        karts.append(makeKart(back: 5, lane: 9, spr: KartRally64.sprKart0 + 3, skill: 0.97))
        raceFrames = 0
        lapStart = 0
        bestLap = 0
        place = 4
        boostTimer = 0
        lean = 0
        aHeld = 0
        msg = ""
        msgTimer = 0
        scoreValue = 0
        finishTimer = 0
        playerFinishFrame = 0
        wrongWay = false
        camHeading = karts[0].heading
        updateCamera()
    }

    private func startCountdown() {
        setupRace()
        phase = .countdown
        cdTimer = 215
    }

    private func showMsg(_ s: String, _ frames: Int) {
        msg = s
        msgTimer = frames
    }

    // MARK: - Helpers

    private func updateCamera() {
        if karts.isEmpty { return }
        let p = karts[0]
        let diff = KartRally64.angleDiff(p.heading, camHeading)
        camHeading = KartRally64.wrapAngle(camHeading + diff * 0.2)
        camX = p.x - cos(camHeading) * KartRally64.camDist
        camY = p.y - sin(camHeading) * KartRally64.camDist
    }

    private func surfaceCap(_ s: UInt8) -> Float {
        if s == 0 { return 0.45 }
        if s == 3 { return 0.85 }
        if s == 2 { return 0.93 }
        return 1.0
    }

    private func moveKart(_ k: inout Kart) {
        if !k.x.isFinite || !k.y.isFinite || !k.heading.isFinite || !k.speed.isFinite {
            let tr = KartRally64.track
            let j = max(0, min(tr.count - 1, k.idx))
            if tr.count > 0 {
                k.x = tr.wpx[j]
                k.y = tr.wpy[j]
            } else {
                k.x = 256
                k.y = 60
            }
            k.heading = 0
            k.speed = 0
        }
        k.speed = max(-0.8, min(2.8, k.speed))
        k.x += cos(k.heading) * k.speed
        k.y += sin(k.heading) * k.speed
        k.x = max(6, min(505, k.x))
        k.y = max(6, min(505, k.y))
    }

    private func advanceTrack(_ k: inout Kart) {
        let tr = KartRally64.track
        let m = tr.count
        if m <= 0 { return }
        var best = k.idx
        var bestD: Float = Float.greatestFiniteMagnitude
        var bestOff = 0
        for off in -6...6 {
            let j = (((k.idx + off) % m) + m) % m
            let dx: Float = tr.wpx[j] - k.x
            let dy: Float = tr.wpy[j] - k.y
            let d: Float = dx * dx + dy * dy
            if d < bestD {
                bestD = d
                best = j
                bestOff = off
            }
        }
        k.idx = best
        k.cum += bestOff
    }

    private func progress(_ k: Kart) -> Float {
        let tr = KartRally64.track
        let j = k.idx
        if j < 0 || j >= tr.count { return Float(k.cum) }
        let px: Float = (k.x - tr.wpx[j]) * tr.wtx[j]
        let py: Float = (k.y - tr.wpy[j]) * tr.wty[j]
        let proj: Float = (px + py) / max(1, tr.spacing)
        return Float(k.cum) + clamp(proj, -1, 1)
    }

    private func currentRank() -> Int {
        if karts.count < 4 { return 4 }
        if phase == .finished { return place }
        let pp = progress(karts[0])
        var rank = 1
        for i in 1..<karts.count {
            if karts[i].finished || progress(karts[i]) > pp { rank += 1 }
        }
        return min(4, rank)
    }

    private func driveAI(_ k: inout Kart, rubber: Float, top: Float) {
        let tr = KartRally64.track
        let m = tr.count
        if m <= 0 { return }
        let look = 3 + Int(max(0, min(3, k.speed)) * 2.5)
        let j = (k.idx + look) % m
        let tx: Float = tr.wpx[j] + tr.wnx[j] * k.lane
        let ty: Float = tr.wpy[j] + tr.wny[j] * k.lane
        let desired: Float = atan2(ty - k.y, tx - k.x)
        let diff: Float = KartRally64.angleDiff(desired, k.heading)
        let turn: Float = clamp(diff, -0.045, 0.045)
        k.heading = KartRally64.wrapAngle(k.heading + turn)
        let corner: Float = min(1, abs(diff) / 0.7)
        var target: Float = top * k.skill * rubber * (1 - 0.4 * corner)
        target = target * surfaceCap(tr.surface(k.x, k.y))
        let dv: Float = clamp(target - k.speed, -0.03, 0.03)
        k.speed += dv
        moveKart(&k)
    }

    private func collisions() {
        let n = karts.count
        if n < 2 { return }
        for i in 0..<(n - 1) {
            for j in (i + 1)..<n {
                let dx: Float = karts[j].x - karts[i].x
                let dy: Float = karts[j].y - karts[i].y
                var d: Float = sqrt(dx * dx + dy * dy)
                if d < 12 {
                    var nx: Float = 1
                    var ny: Float = 0
                    if d > 0.001 {
                        nx = dx / d
                        ny = dy / d
                    } else {
                        d = 0.001
                    }
                    let overlap: Float = 12 - d
                    karts[i].x -= nx * overlap * 0.5
                    karts[i].y -= ny * overlap * 0.5
                    karts[j].x += nx * overlap * 0.5
                    karts[j].y += ny * overlap * 0.5
                    karts[i].speed *= 0.985
                    karts[j].speed *= 0.985
                    if i == 0 && bumpCooldown <= 0 {
                        play(.thud)
                        bumpCooldown = 20
                    }
                }
            }
        }
        if bumpCooldown > 0 { bumpCooldown -= 1 }
    }

    // MARK: - Update

    private func updatePlayer(_ input: InputState) {
        var k = karts[0]
        let tr = KartRally64.track
        let s = tr.surface(k.x, k.y)
        let cap = surfaceCap(s)
        playerOffroad = (s == 0)
        let maxS = KartRally64.maxSpeed
        var target: Float = maxS * cap
        var accel: Float = 0.03
        if boostTimer > 0 {
            boostTimer -= 1
            target = max(target, maxS * 1.2)
            target = min(target, maxS * 1.45)
            accel = 0.09
        }
        if input.a {
            if k.speed < target { k.speed += accel }
        } else if input.b {
            if k.speed > 0 {
                k.speed -= 0.06
            } else {
                k.speed -= 0.025
            }
        } else {
            k.speed *= 0.992
        }
        if k.speed > target {
            let over: Float = k.speed - target
            k.speed -= over * 0.06 + 0.002
        }
        k.speed = max(-0.8, min(2.8, k.speed))
        let sp: Float = abs(k.speed)
        let grip: Float = min(1, sp / 0.9)
        let ratio: Float = min(1, sp / maxS)
        var turn: Float = Float(input.dx) * 0.036 * grip * (1.15 - 0.3 * ratio)
        if k.speed < 0 { turn = -turn }
        k.heading = KartRally64.wrapAngle(k.heading + turn)
        moveKart(&k)
        karts[0] = k
        lean += (Float(input.dx) - lean) * 0.2

        // wrong way detection
        let j = max(0, min(tr.count - 1, k.idx))
        if tr.count > 0 {
            let dot: Float = cos(k.heading) * tr.wtx[j] + sin(k.heading) * tr.wty[j]
            wrongWay = dot < -0.3 && k.speed > 0.5
        }
    }

    private func updateRivals() {
        if karts.count < 2 { return }
        let pp = karts[0].finished ? Float(0) : progress(karts[0])
        for i in 1..<karts.count {
            var k = karts[i]
            var rubber: Float = 1
            if !karts[0].finished {
                let rp = progress(k)
                rubber = clamp(1 - (rp - pp) * 0.010, 0.86, 1.10)
            }
            driveAI(&k, rubber: rubber, top: KartRally64.maxSpeed)
            karts[i] = k
        }
    }

    private func trackAndLaps() {
        for i in 0..<karts.count {
            var k = karts[i]
            advanceTrack(&k)
            let m = max(1, KartRally64.track.count)
            let done = k.cum >= 0 ? k.cum / m : 0
            if done > k.lapsCounted {
                k.lapsCounted = done
                if done >= KartRally64.totalLaps && !k.finished {
                    k.finished = true
                    k.finishFrame = raceFrames
                }
                karts[i] = k
                if i == 0 { playerLapDone(done) }
            } else {
                karts[i] = k
            }
        }
    }

    private func playerLapDone(_ done: Int) {
        let lapTime = raceFrames - lapStart
        lapStart = raceFrames
        if bestLap == 0 || lapTime < bestLap { bestLap = lapTime }
        if done >= KartRally64.totalLaps {
            finishRace()
        } else {
            play(.coin)
            if done == KartRally64.totalLaps - 1 {
                showMsg("FINAL LAP!", 100)
            } else {
                showMsg("LAP " + String(done + 1), 80)
            }
        }
    }

    private func finishRace() {
        var ahead = 0
        for i in 1..<karts.count {
            if karts[i].finished { ahead += 1 }
        }
        place = min(4, 1 + ahead)
        playerFinishFrame = raceFrames
        phase = .finished
        finishTimer = 0
        let bonuses: [Int] = [5000, 3000, 1800, 1000]
        let placeBonus = bonuses[max(0, min(3, place - 1))]
        let sec = raceFrames / 60
        let timeBonus = max(0, 3000 - sec * 25)
        let lapSec = bestLap / 60
        let lapBonus = max(0, 1000 - lapSec * 20)
        scoreValue = placeBonus + timeBonus + lapBonus
        if place <= 2 { play(.win) } else { play(.lose) }
    }

    private func goRace() {
        phase = .racing
        raceFrames = 0
        lapStart = 0
        for i in 1..<karts.count { karts[i].speed = 0.3 + karts[i].skill * 0.2 }
        if aHeld >= 1 && aHeld <= 45 {
            boostTimer = 75
            karts[0].speed = 1.3
            showMsg("ROCKET START!", 90)
            play(.powerup)
        } else {
            play(.confirm)
            if aHeld > 45 { showMsg("TOO EARLY!", 60) }
        }
    }

    override func update(_ input: InputState) {
        frame += 1
        if msgTimer > 0 { msgTimer -= 1 }
        if karts.count < 4 { setupRace() }
        switch phase {
        case .title:
            for i in 0..<karts.count {
                var k = karts[i]
                driveAI(&k, rubber: 1, top: 1.0)
                advanceTrack(&k)
                karts[i] = k
            }
            updateCamera()
            if input.aPressed || input.startPressed {
                play(.confirm)
                startCountdown()
            }
        case .countdown:
            if input.a { aHeld += 1 } else { aHeld = 0 }
            cdTimer -= 1
            if cdTimer == 180 || cdTimer == 120 || cdTimer == 60 { play(.countdown) }
            lean += (Float(input.dx) - lean) * 0.2
            updateCamera()
            if cdTimer <= 0 { goRace() }
        case .racing:
            raceFrames += 1
            updatePlayer(input)
            updateRivals()
            collisions()
            trackAndLaps()
            updateCamera()
            if phase == .racing {
                let p = progress(karts[0])
                let running = Int(max(0, min(400, p + 6)))
                scoreValue = max(scoreValue, running * 2)
            }
        case .finished:
            finishTimer += 1
            var k = karts[0]
            k.speed *= 0.97
            moveKart(&k)
            karts[0] = k
            lean *= 0.9
            updateRivals()
            collisions()
            for i in 1..<karts.count {
                var r = karts[i]
                advanceTrack(&r)
                karts[i] = r
            }
            updateCamera()
            if finishTimer > 60 && (input.aPressed || input.startPressed) {
                play(.confirm)
                startCountdown()
            }
        }
    }

    // MARK: - Rendering

    private func buildItems(_ cs: Float, _ sn: Float) {
        items.removeAll(keepingCapacity: true)
        let tr = KartRally64.track
        let sprs = KartRally64.sprites
        let focal = KartRally64.focal
        let hz = KartRally64.horizon
        let maxD = KartRally64.maxDist
        for p in tr.props {
            if p.spr < 0 || p.spr >= sprs.count { continue }
            let dx: Float = p.x - camX
            let dy: Float = p.y - camY
            let depth: Float = dx * cs + dy * sn
            if depth < 14 || depth > maxD { continue }
            let lat: Float = -dx * sn + dy * cs
            let scale: Float = focal / depth
            let wW: Float = sprs[p.spr].worldW
            let wH: Float = sprs[p.spr].worldH
            let sw = Int(wW * scale)
            let sh = Int(wH * scale)
            let sx = 160 + Int(lat * scale)
            if sw < 1 || sh < 1 || sw > 900 { continue }
            if sx + sw / 2 < 0 || sx - sw / 2 > 320 { continue }
            let bottom = hz + Int(KartRally64.camHeight * scale)
            let fog = KartRally64.fogAmount(depth)
            items.append(DrawItem(depth: depth, sx: sx, bottom: bottom, sw: sw, sh: sh, spr: p.spr, fog: fog, shear: 0, flip: p.flip))
        }
        for i in 0..<karts.count {
            let k = karts[i]
            if k.spr < 0 || k.spr >= sprs.count { continue }
            let dx: Float = k.x - camX
            let dy: Float = k.y - camY
            let depth: Float = dx * cs + dy * sn
            if depth < 12 || depth > maxD { continue }
            let lat: Float = -dx * sn + dy * cs
            let scale: Float = focal / depth
            let sw = Int(sprs[k.spr].worldW * scale)
            let sh = Int(sprs[k.spr].worldH * scale)
            let sx = 160 + Int(lat * scale)
            if sw < 1 || sh < 1 || sw > 900 { continue }
            var bottom = KartRally64.horizon + Int(KartRally64.camHeight * scale)
            var shear = 0
            if i == 0 {
                shear = Int(lean * Float(sw) * 0.12)
                if playerOffroad && abs(k.speed) > 0.4 && ((frame / 2) & 1) == 1 { bottom += 2 }
                playerSX = sx
                playerBottom = bottom
            }
            let fog = KartRally64.fogAmount(depth)
            items.append(DrawItem(depth: depth, sx: sx, bottom: bottom, sw: sw, sh: sh, spr: k.spr, fog: fog, shear: shear, flip: false))
        }
        items.sort { $0.depth > $1.depth }
    }

    private func renderSky(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ heading: Float) {
        let hz = KartRally64.horizon
        if hz >= h { return }
        let sky = KartRally64.skyRows
        for y in 0..<hz {
            let c = sky[y]
            let base = y * w
            for x in 0..<w { p[base + x] = c }
        }
        // Sun
        let sunAngle: Float = 1.1
        let sd: Float = KartRally64.angleDiff(sunAngle, heading)
        if abs(sd) < 1.0 {
            let sxf: Float = 160 + tan(sd) * KartRally64.focal
            let sx = Int(max(-100, min(420, sxf)))
            let sunColor = TrueColorBuffer.rgb(255, 248, 205)
            let sunEdge = TrueColorBuffer.rgb(255, 226, 150)
            for yy in 20..<60 {
                for xx in (sx - 20)..<(sx + 21) {
                    if xx < 0 || xx >= w { continue }
                    let dx = xx - sx
                    let dy = yy - 40
                    let d2 = dx * dx + dy * dy
                    if d2 <= 144 {
                        p[yy * w + xx] = sunColor
                    } else if d2 <= 400 {
                        p[yy * w + xx] = sunEdge
                    }
                }
            }
        }
        let cw = min(w, 320)
        let ang = KartRally64.colAngle
        let far = KartRally64.hillFar
        let near = KartRally64.hillNear
        let farColor = TrueColorBuffer.rgb(118, 158, 204)
        let farTop = TrueColorBuffer.rgb(150, 188, 226)
        let nearColor = TrueColorBuffer.rgb(40, 104, 72)
        let nearTop = TrueColorBuffer.rgb(84, 156, 100)
        let invTwoPi: Float = 1.0 / (2.0 * Float.pi)
        for x in 0..<cw {
            var t: Float = (heading + ang[x]) * invTwoPi
            t = t - floor(t)
            if !(t >= 0 && t < 1) { t = 0 }
            let idx = Int(t * 1024) & 1023
            let hf = far[idx]
            let hn = near[idx]
            let yf = max(0, hz - hf)
            for yy in yf..<hz { p[yy * w + x] = farColor }
            p[yf * w + x] = farTop
            let yn = max(0, hz - hn)
            for yy in yn..<hz { p[yy * w + x] = nearColor }
            p[yn * w + x] = nearTop
        }
    }

    private func renderFloor(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ tp: UnsafeMutablePointer<UInt32>,
                             _ cx: Float, _ cy: Float, _ cosH: Float, _ sinH: Float) {
        let hz = KartRally64.horizon
        let rows = min(h, 288)
        if hz + 1 >= rows { return }
        let rightX: Float = -sinH
        let rightY: Float = cosH
        let halfW: Float = Float(w / 2)
        let focal = KartRally64.focal
        let maxD = KartRally64.maxDist
        let outside = KartRally64.outsideColor
        let haze = KartRally64.hazeColor
        let rowDist = KartRally64.rowDist
        let rowFog = KartRally64.rowFog
        for y in (hz + 1)..<rows {
            let r = y - hz
            let z: Float = rowDist[r]
            let base = y * w
            if z > maxD {
                for x in 0..<w { p[base + x] = haze }
                continue
            }
            let step: Float = z / focal
            let startOff: Float = -halfW * step
            var px: Float = cx + cosH * z + rightX * startOff
            var py: Float = cy + sinH * z + rightY * startOff
            let ddx: Float = rightX * step
            let ddy: Float = rightY * step
            let t = rowFog[r]
            for x in 0..<w {
                var c = outside
                if px >= 0 && px < 511 && py >= 0 && py < 511 {
                    c = tp[(Int(py) << 9) + Int(px)]
                }
                if t > 0 { c = KartRally64.mix(c, t) }
                p[base + x] = c
                px += ddx
                py += ddy
            }
        }
    }

    private func blit(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ item: DrawItem) {
        let sprs = KartRally64.sprites
        if item.spr < 0 || item.spr >= sprs.count { return }
        let spr = sprs[item.spr]
        let sw = item.sw
        let sh = item.sh
        if sw < 1 || sh < 1 || sw > 900 || sh > 900 { return }
        let x0 = item.sx - sw / 2
        let y0 = item.bottom - sh
        let yStart = max(0, y0)
        let yEnd = min(h, item.bottom)
        if yStart >= yEnd { return }
        let stepY = (spr.h << 16) / sh
        let stepX = (spr.w << 16) / sw
        let sprW = spr.w
        let sprH = spr.h
        let fog = item.fog
        let flip = item.flip
        let shear = item.shear
        spr.pix.withUnsafeBufferPointer { sp in
            for y in yStart..<yEnd {
                let ry = y - y0
                let sy = max(0, min(sprH - 1, (ry * stepY) >> 16))
                let rowShift = (shear * (sh - ry)) / sh
                let xa = x0 + rowShift
                let xs = max(0, xa)
                let xe = min(w, xa + sw)
                if xs >= xe { continue }
                let rowBase = y * w
                let srow = sy * sprW
                for x in xs..<xe {
                    var sxp = ((x - xa) * stepX) >> 16
                    sxp = max(0, min(sprW - 1, sxp))
                    if flip { sxp = sprW - 1 - sxp }
                    let c = sp[srow + sxp]
                    if c != 0 {
                        if fog > 0 {
                            p[rowBase + x] = KartRally64.mix(c, fog)
                        } else {
                            p[rowBase + x] = c
                        }
                    }
                }
            }
        }
    }

    override func drawTrueColor(_ b: TrueColorBuffer) {
        let tr = KartRally64.track
        let heading = camHeading
        let cs: Float = cos(heading)
        let sn: Float = sin(heading)
        buildItems(cs, sn)
        let list = items
        let cx = camX
        let cy = camY
        let tp = tr.tex
        b.withPixels { p, w, h in
            if w < 64 || h < 200 { return }
            self.renderSky(p, w, h, heading)
            self.renderFloor(p, w, h, tp, cx, cy, cs, sn)
            for it in list { self.blit(p, w, h, it) }
        }
        drawEffects(b)
        drawHUD(b)
        drawOverlays(b)
    }

    // MARK: - HUD

    private func otext(_ b: TrueColorBuffer, _ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        let k = max(1, scale / 2)
        let o = KartRally64.cBlack
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

    private func timeString(_ f: Int) -> String {
        let t = max(0, f)
        let sec = t / 60
        let tenths = ((t % 60) * 10) / 60
        let mins = sec / 60
        let s = sec % 60
        return String(mins) + ":" + zeroPad(s, 2) + "." + String(tenths)
    }

    private func drawEffects(_ b: TrueColorBuffer) {
        if phase != .racing && phase != .finished { return }
        if boostTimer > 0 {
            let streak = TrueColorBuffer.rgb(255, 240, 180)
            for i in 0..<14 {
                let yy = 40 + ((i * 53 + frame * 11) % 200)
                let len = 10 + ((i * 7) % 14)
                let left = (i & 1) == 0
                let xx = left ? ((i * 13 + frame * 5) % 40) : (320 - len - ((i * 17 + frame * 5) % 40))
                b.fillRect(xx, yy, len, 1, streak)
            }
            let fl = TrueColorBuffer.rgb(255, 150, 30)
            let fl2 = TrueColorBuffer.rgb(255, 240, 120)
            let fx = playerSX
            let fy = playerBottom - 12
            let flick = 6 + (frame & 3) * 2
            b.fillRect(fx - 9, fy, 6, flick, fl)
            b.fillRect(fx + 3, fy, 6, flick, fl)
            b.fillRect(fx - 8, fy, 4, flick / 2, fl2)
            b.fillRect(fx + 4, fy, 4, flick / 2, fl2)
        }
        if playerOffroad && phase == .racing && karts.count > 0 && abs(karts[0].speed) > 0.5 {
            let dust = TrueColorBuffer.rgb(176, 148, 96)
            let dust2 = TrueColorBuffer.rgb(120, 190, 100)
            for i in 0..<8 {
                let hsh = (frame * 7919 + i * 104729) & 255
                let ox = (hsh % 70) - 35
                let oy = ((hsh / 5) % 14)
                let size = 2 + (hsh & 3)
                b.fillRect(playerSX + ox, playerBottom - oy, size, size, (i & 1) == 0 ? dust : dust2)
            }
        }
    }

    private func drawMinimap(_ b: TrueColorBuffer) {
        let tr = KartRally64.track
        let mx = 252
        let my = 214
        b.fillRect(mx - 2, my - 2, 64, 64, KartRally64.cBlack)
        b.fillRect(mx, my, 60, 60, TrueColorBuffer.rgb(28, 56, 40))
        let road = TrueColorBuffer.rgb(236, 236, 236)
        let n = min(tr.miniX.count, tr.miniY.count)
        for i in 0..<n {
            b.fillRect(mx + tr.miniX[i], my + tr.miniY[i], 2, 2, road)
        }
        if n > 0 {
            b.fillRect(mx + tr.miniX[0] - 1, my + tr.miniY[0] - 1, 4, 4, KartRally64.cYellow)
        }
        var i = karts.count - 1
        while i >= 0 {
            let k = karts[i]
            let kx = max(0, min(59, Int(k.x * 0.1171875)))
            let ky = max(0, min(59, Int(k.y * 0.1171875)))
            let colIdx = max(0, min(KartRally64.kartCols.count - 1, i))
            if i == 0 {
                b.fillRect(mx + kx - 3, my + ky - 3, 7, 7, KartRally64.cBlack)
                b.fillRect(mx + kx - 2, my + ky - 2, 5, 5, KartRally64.kartCols[colIdx])
            } else {
                b.fillRect(mx + kx - 2, my + ky - 2, 5, 5, KartRally64.cBlack)
                b.fillRect(mx + kx - 1, my + ky - 1, 3, 3, KartRally64.kartCols[colIdx])
            }
            i -= 1
        }
    }

    private func drawHUD(_ b: TrueColorBuffer) {
        if phase == .title { return }
        let rank = currentRank()
        let names = KartRally64.placeNames
        let pn = names[max(0, min(3, rank - 1))]
        otext(b, pn, 8, 8, rank == 1 ? KartRally64.cYellow : KartRally64.cWhite, 5)
        otext(b, "/4", 68, 20, KartRally64.cWhite, 2)
        var lap = 1
        if karts.count > 0 { lap = min(KartRally64.totalLaps, karts[0].lapsCounted + 1) }
        let lapText = "LAP " + String(lap) + "/" + String(KartRally64.totalLaps)
        let lw = b.textWidth(lapText, scale: 2)
        otext(b, lapText, 312 - lw, 8, KartRally64.cWhite, 2)
        let shownTime = phase == .finished ? playerFinishFrame : raceFrames
        let tt = timeString(shownTime)
        let tw = b.textWidth(tt, scale: 2)
        otext(b, tt, 312 - tw, 26, KartRally64.cWhite, 2)

        // speed bar
        var frac: Float = 0
        if karts.count > 0 { frac = clamp(abs(karts[0].speed) / (KartRally64.maxSpeed * 1.2), 0, 1) }
        otext(b, "SPEED", 8, 250, KartRally64.cWhite, 2)
        b.fillRect(6, 264, 88, 14, KartRally64.cBlack)
        b.fillRect(8, 266, 84, 10, TrueColorBuffer.rgb(50, 50, 60))
        let fw = Int(frac * 84)
        var barColor = KartRally64.cGreen
        if frac > 0.85 { barColor = KartRally64.cRed } else if frac > 0.6 { barColor = KartRally64.cYellow }
        if fw > 0 { b.fillRect(8, 266, fw, 10, barColor) }

        drawMinimap(b)
    }

    private func drawOverlays(_ b: TrueColorBuffer) {
        let yellow = KartRally64.cYellow
        let white = KartRally64.cWhite
        switch phase {
        case .title:
            b.fillRect(22, 40, 276, 134, KartRally64.cBlack)
            b.fillRect(24, 42, 272, 130, KartRally64.cPanel)
            b.fillRect(24, 42, 272, 3, yellow)
            b.fillRect(24, 169, 272, 3, yellow)
            ctext(b, "KART RALLY", 56, yellow, 6)
            ctext(b, "64", 100, white, 8)
            ctext(b, "3 LAPS  3 RIVALS", 148, white, 2)
            if (frame / 30) & 1 == 0 { ctext(b, "PRESS A TO RACE", 196, yellow, 3) }
            ctext(b, "A GAS  B BRAKE", 232, white, 2)
            ctext(b, "PAD STEERS", 250, white, 2)
        case .countdown:
            if cdTimer > 180 {
                ctext(b, "READY", 70, white, 8)
            } else if cdTimer > 0 {
                let d = (cdTimer + 59) / 60
                ctext(b, String(d), 56, yellow, 14)
            }
            if cdTimer <= 150 { ctext(b, "TAP A AT GO FOR A BOOST", 236, white, 1) }
        case .racing:
            if raceFrames < 50 { ctext(b, "GO!", 60, KartRally64.cGreen, 12) }
            if msgTimer > 0 { ctext(b, msg, 100, yellow, 3) }
            if wrongWay && (frame / 12) & 1 == 0 { ctext(b, "WRONG WAY!", 140, KartRally64.cRed, 4) }
        case .finished:
            b.fillRect(38, 58, 244, 176, KartRally64.cBlack)
            b.fillRect(40, 60, 240, 172, KartRally64.cPanel)
            b.fillRect(40, 60, 240, 3, yellow)
            ctext(b, "RACE OVER", 72, white, 4)
            let pn = KartRally64.placeNames[max(0, min(3, place - 1))] + " PLACE"
            ctext(b, pn, 108, place == 1 ? yellow : white, 4)
            ctext(b, "TIME " + timeString(playerFinishFrame), 148, white, 2)
            ctext(b, "BEST LAP " + timeString(bestLap), 168, white, 2)
            ctext(b, "SCORE " + zeroPad(scoreValue, 5), 188, yellow, 2)
            if finishTimer > 60 && (frame / 30) & 1 == 0 { ctext(b, "PRESS A", 210, white, 2) }
        }
    }
}

extension Cartridge {
    static let kartRally64 = Cartridge(
        id: "kart64", title: "KART RALLY 64", genre: "Racing",
        blurb: "Three laps, three rivals and one dusty circuit. Mode-7 style racing with shortcuts, boost starts and rubber-band AI.",
        controls: "A gas, B brake/reverse, LEFT/RIGHT steer. Hold A as GO appears for a rocket start.",
        era: .n64, labelTop: 0xE8602C, labelBottom: 0x2A2A6E, factory: { KartRally64() })
}
