#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// HOVER RACE 64: a futuristic anti-gravity Mode-7 racer on a night-city circuit. Momentum and drift physics with an
/// air-brake, walled track edges that bleed shield energy, boost pads, jump ramps with ground shadows, speed-gate arches,
/// a parallax skyline and three AI rivals following a racing line. The 512x512 track texture is generated once.
final class HoverRace64: Game {
    // MARK: - Constants

    static let horizonBase = 100
    static let focal: Float = 190
    static let camHeight: Float = 28
    static let camDist: Float = 42
    static let maxDist: Float = 700
    static let fogStart: Float = 240
    static let hazeR = 84
    static let hazeG = 28
    static let hazeB = 116
    static let totalLaps = 3
    static let topSpeed: Float = 2.1
    static let roadLimit: Float = 24.5

    static let cWhite: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    static let cBlack: UInt32 = TrueColorBuffer.rgb(6, 6, 16)
    static let cYellow: UInt32 = TrueColorBuffer.rgb(255, 232, 70)
    static let cRed: UInt32 = TrueColorBuffer.rgb(255, 70, 70)
    static let cGreen: UInt32 = TrueColorBuffer.rgb(110, 255, 140)
    static let cCyan: UInt32 = TrueColorBuffer.rgb(80, 240, 255)
    static let cMagenta: UInt32 = TrueColorBuffer.rgb(255, 80, 220)
    static let cOrange: UInt32 = TrueColorBuffer.rgb(255, 150, 40)
    static let cPanel: UInt32 = TrueColorBuffer.rgb(12, 12, 40)
    static let hazeColor: UInt32 = TrueColorBuffer.rgb(84, 28, 116)
    static let voidColor: UInt32 = TrueColorBuffer.rgb(10, 12, 34)
    static let craftCols: [UInt32] = [
        TrueColorBuffer.rgb(80, 240, 255),
        TrueColorBuffer.rgb(255, 80, 220),
        TrueColorBuffer.rgb(255, 160, 40),
        TrueColorBuffer.rgb(140, 255, 90)
    ]
    static let placeNames: [String] = ["1ST", "2ND", "3RD", "4TH"]

    static let tune = Tune(bpm: 156, wave: .pulse50, volume: 0.12,
        "E4:0.5 B4:0.5 E5:0.5 B4:0.5 E4:0.5 B4:0.5 G5:0.5 B4:0.5 C4:0.5 G4:0.5 C5:0.5 G4:0.5 C4:0.5 G4:0.5 E5:0.5 G4:0.5 D4:0.5 A4:0.5 D5:0.5 A4:0.5 D4:0.5 A4:0.5 F#5:0.5 A4:0.5 B3:0.5 F#4:0.5 B4:0.5 F#4:0.5 B3:0.5 F#4:0.5 D5:0.5 F#4:0.5")

    // MARK: - Static tables

    static let rowDist: [Float] = {
        var a = [Float](repeating: 100000, count: 288)
        let k: Float = HoverRace64.camHeight * HoverRace64.focal
        for r in 1..<288 { a[r] = k / Float(r) }
        return a
    }()

    static let rowFog: [Int] = {
        var a = [Int](repeating: 256, count: 288)
        let k: Float = HoverRace64.camHeight * HoverRace64.focal
        for r in 1..<288 { a[r] = HoverRace64.fogAmount(k / Float(r)) }
        return a
    }()

    static let skyRows: [UInt32] = {
        var a = [UInt32](repeating: 0, count: 160)
        for y in 0..<160 {
            let t: Float = Float(y) / 159.0
            let tp: Float = t * sqrt(t)
            let r = Int(6 + Float(HoverRace64.hazeR - 6) * tp)
            let g = Int(6 + Float(HoverRace64.hazeG - 6) * t)
            let b = Int(30 + Float(HoverRace64.hazeB - 30) * sqrt(t))
            a[y] = TrueColorBuffer.rgb(r, g, b)
        }
        return a
    }()

    static let colAngle: [Float] = {
        var a = [Float](repeating: 0, count: 320)
        for x in 0..<320 {
            let dx: Float = Float(x - 160) + 0.5
            a[x] = atan(dx / HoverRace64.focal)
        }
        return a
    }()

    /// Skyline: building heights and building ids per 1/1024 of a full turn.
    static func makeSkyline(_ minW: Int, _ varW: Int, _ minH: Int, _ varH: Int, _ seed: Int) -> [[Int]] {
        var heights = [Int](repeating: minH, count: 1024)
        var ids = [Int](repeating: 0, count: 1024)
        var i = 0
        var bid = seed
        while i < 1024 {
            let h1 = HoverRace64.hash(bid, seed)
            let w = minW + (h1 % varW)
            let hh = minH + ((h1 >> 4) % varH)
            var k = 0
            while k < w && i + k < 1024 {
                heights[i + k] = hh
                ids[i + k] = bid
                k += 1
            }
            i += w
            bid += 1
        }
        return [heights, ids]
    }

    static let skylineFar: [[Int]] = HoverRace64.makeSkyline(5, 8, 10, 30, 3)
    static let skylineNear: [[Int]] = HoverRace64.makeSkyline(4, 9, 6, 24, 77)

    static let stars: [[Int]] = {
        var list: [[Int]] = []
        for i in 0..<60 {
            let h1 = HoverRace64.hash(i, 5)
            let h2 = HoverRace64.hash(i, 6)
            list.append([h1 % 1024, 3 + (h2 % 60), 150 + (h1 & 100)])
        }
        return list
    }()

    static let track = TrackData()
    static let sprites: [SpriteImg] = HoverRace64.makeSprites()

    static func hash(_ x: Int, _ y: Int) -> Int {
        var h: Int = x &* 374761393 &+ y &* 668265263
        h = (h ^ (h >> 13)) &* 1274126177
        return (h ^ (h >> 16)) & 0xFFFF
    }

    static func fogAmount(_ z: Float) -> Int {
        if z <= HoverRace64.fogStart { return 0 }
        let span: Float = HoverRace64.maxDist - HoverRace64.fogStart
        var t: Float = (z - HoverRace64.fogStart) / span
        if t < 0 { t = 0 }
        if t > 1 { t = 1 }
        return Int(t * 256)
    }

    @inline(__always) static func mix(_ c: UInt32, _ t: Int) -> UInt32 {
        let r = Int(c & 255)
        let g = Int((c >> 8) & 255)
        let bl = Int((c >> 16) & 255)
        let r2 = r + (((HoverRace64.hazeR - r) * t) >> 8)
        let g2 = g + (((HoverRace64.hazeG - g) * t) >> 8)
        let b2 = bl + (((HoverRace64.hazeB - bl) * t) >> 8)
        return 0xFF00_0000 | UInt32(r2 & 255) | (UInt32(g2 & 255) << 8) | (UInt32(b2 & 255) << 16)
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

    // MARK: - Nested types

    struct Craft {
        var x: Float = 0
        var y: Float = 0
        var heading: Float = 0
        var vx: Float = 0
        var vy: Float = 0
        var speed: Float = 0
        var z: Float = 0
        var vz: Float = 0
        var idx: Int = 0
        var cum: Int = 0
        var lapsCounted: Int = 0
        var finished: Bool = false
        var finishFrame: Int = 0
        var spr: Int = 0
        var lane: Float = 0
        var skill: Float = 0.95
        var boostTimer: Int = 0
    }

    struct Bill {
        var depth: Float
        var sx: Int
        var bottom: Int
        var sw: Int
        var sh: Int
        var spr: Int
        var fog: Int
        var shear: Int
    }

    struct Prop {
        var x: Float
        var y: Float
        var spr: Int
    }

    struct SpriteImg {
        var w: Int
        var h: Int
        var pix: [UInt32]
        var worldW: Float
        var worldH: Float
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

    enum Phase { case title, countdown, racing, finished }

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
        var curv: [Float] = []
        var racing: [Float] = []
        var cornerF: [Float] = []
        var count: Int = 0
        var spacing: Float = 12
        var props: [Prop] = []
        var gates: [Int] = []
        var miniX: [Int] = []
        var miniY: [Int] = []

        init() {
            tex.initialize(repeating: 0xFF00_0000, count: 262144)
            build()
        }

        func surface(_ x: Float, _ y: Float) -> UInt8 {
            if !(x >= 0 && x < 511 && y >= 0 && y < 511) { return 0 }
            return surf[(Int(y) << 9) + Int(x)]
        }

        func build() {
            paintVoid()
            makeCenterline()
            resample()
            paintRoad()
            paintFeatures()
            computeRacing()
            placeProps()
        }

        func paintVoid() {
            for y in 0..<512 {
                for x in 0..<512 {
                    let n = HoverRace64.hash(x, y) & 7
                    var r = 10 + (n >> 1)
                    var g = 12 + (n >> 1)
                    var b = 34 + n
                    let gx = x & 31
                    let gy = y & 31
                    if gx == 0 || gy == 0 {
                        r = 36; g = 70; b = 160
                    } else if gx == 1 || gy == 1 {
                        r = 18; g = 30; b = 80
                    }
                    if gx == 0 && gy == 0 {
                        r = 120; g = 220; b = 255
                    }
                    tex[(y << 9) + x] = HoverRace64.rgb(r, g, b)
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
            let px: [Float] = [256, 390, 460, 440, 350, 400, 460, 400, 300, 250, 180, 100, 55, 100, 170, 110, 60, 130]
            let py: [Float] = [50, 60, 130, 215, 250, 320, 390, 455, 430, 360, 420, 450, 380, 310, 270, 200, 130, 70]
            let n = px.count
            for i in 0..<n {
                let i0 = (i + n - 1) % n
                let i2 = (i + 1) % n
                let i3 = (i + 2) % n
                for s in 0..<40 {
                    let t: Float = Float(s) / 40.0
                    var x = catmull(px[i0], px[i], px[i2], px[i3], t)
                    var y = catmull(py[i0], py[i], py[i2], py[i3], t)
                    x = max(40, min(470, x))
                    y = max(40, min(470, y))
                    denseX.append(x)
                    denseY.append(y)
                }
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
            for k in 0..<m {
                let b = (k + 3) % m
                curv.append(wtx[k] * wty[b] - wty[k] * wtx[b])
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
                        var d = 0
                        if noise > 0 { d = ((HoverRace64.hash(x, y) & 7) - 3) * noise }
                        tex[(y << 9) + x] = HoverRace64.rgb(r0 + d, g0 + d, b0 + d)
                        surf[(y << 9) + x] = sid
                    }
                }
            }
        }

        func paintRoad() {
            let n = denseX.count
            if n < 4 { return }
            var i = 0
            while i < n {
                stamp(denseX[i], denseY[i], 34, 28, 20, 78, 0, 0)
                i += 2
            }
            i = 0
            while i < n {
                if ((i / 4) & 1) == 0 {
                    stamp(denseX[i], denseY[i], 30.5, 255, 70, 215, 0, 2)
                } else {
                    stamp(denseX[i], denseY[i], 30.5, 70, 235, 255, 0, 2)
                }
                i += 2
            }
            i = 0
            while i < n {
                var tone = 0
                if ((i / 6) & 1) == 1 { tone = -9 }
                stamp(denseX[i], denseY[i], 27, 78 + tone, 84 + tone, 118 + tone, 1, 1)
                i += 2
            }
            for k in 0..<n {
                if ((k / 5) & 1) == 0 {
                    stamp(denseX[k], denseY[k], 1.6, 230, 236, 255, 0, 1)
                }
            }
            // faint lane lines either side of centre
            for k in 0..<count {
                if (k & 1) == 0 {
                    for side in 0..<2 {
                        let sg: Float = side == 0 ? -1 : 1
                        stamp(wpx[k] + wnx[k] * 14 * sg, wpy[k] + wny[k] * 14 * sg, 1.0, 130, 150, 220, 0, 1)
                    }
                }
            }
        }

        func putPixel(_ x: Float, _ y: Float, _ r: Int, _ g: Int, _ b: Int, _ sid: UInt8) {
            if !(x >= 0 && x < 511 && y >= 0 && y < 511) { return }
            let idx = (Int(y) << 9) + Int(x)
            tex[idx] = HoverRace64.rgb(r, g, b)
            surf[idx] = sid
        }

        func straightNear(_ frac: Float) -> Int {
            let m = count
            if m < 8 { return 0 }
            let c0 = Int(frac * Float(m))
            var best = c0 % m
            var bestC: Float = 100
            for off in -8...8 {
                let j = (((c0 + off) % m) + m) % m
                var worst: Float = 0
                for q in -3...3 {
                    let jj = (((j + q) % m) + m) % m
                    worst = max(worst, abs(curv[jj]))
                }
                if worst < bestC {
                    bestC = worst
                    best = j
                }
            }
            return best
        }

        func paintPad(_ j: Int, _ lane: Float) {
            var u: Float = -11
            while u <= 11 {
                var v: Float = -8
                while v <= 8 {
                    let cx: Float = wpx[j] + wtx[j] * u + wnx[j] * (v + lane)
                    let cy: Float = wpy[j] + wty[j] * u + wny[j] * (v + lane)
                    let phase: Float = u + abs(v) * 0.9 + 40
                    let band = Int(phase / 4) & 1
                    if abs(v) > 7 || abs(u) > 10 {
                        putPixel(cx, cy, 255, 255, 255, 3)
                    } else if band == 0 {
                        putPixel(cx, cy, 255, 238, 70, 3)
                    } else {
                        putPixel(cx, cy, 255, 120, 20, 3)
                    }
                    v += 0.5
                }
                u += 0.5
            }
        }

        func paintRamp(_ j: Int) {
            var u: Float = -8
            while u <= 8 {
                var v: Float = -24
                while v <= 24 {
                    let cx: Float = wpx[j] + wtx[j] * u + wnx[j] * v
                    let cy: Float = wpy[j] + wty[j] * u + wny[j] * v
                    let band = Int((u + 8) / 3.2)
                    if abs(v) > 22 {
                        putPixel(cx, cy, 255, 80, 220, 4)
                    } else if (band & 1) == 0 {
                        putPixel(cx, cy, 70, 235, 255, 4)
                    } else {
                        putPixel(cx, cy, 235, 250, 255, 4)
                    }
                    v += 0.5
                }
                u += 0.5
            }
        }

        func paintFeatures() {
            let m = count
            if m < 20 { return }
            let padFracs: [Float] = [0.12, 0.38, 0.62, 0.86]
            let padLanes: [Float] = [-9, 9, 0, -9]
            for i in 0..<padFracs.count {
                paintPad(straightNear(padFracs[i]), padLanes[i])
            }
            paintRamp(straightNear(0.26))
            paintRamp(straightNear(0.74))
            // checkered start line
            var u: Float = -3
            while u < 3 {
                var v: Float = -26
                while v < 26 {
                    let cx: Float = wpx[0] + wtx[0] * u + wnx[0] * v
                    let cy: Float = wpy[0] + wty[0] * u + wny[0] * v
                    let white = ((Int((u + 3) / 3) + Int((v + 26) / 3)) & 1) == 0
                    if white {
                        putPixel(cx, cy, 245, 245, 250, 1)
                    } else {
                        putPixel(cx, cy, 16, 16, 24, 1)
                    }
                    v += 0.5
                }
                u += 0.5
            }
            gates = [0, straightNear(0.27), straightNear(0.52), straightNear(0.78)]
        }

        func computeRacing() {
            let m = count
            if m < 8 { return }
            var smooth = [Float](repeating: 0, count: m)
            for i in 0..<m {
                var s: Float = 0
                for q in -6...6 {
                    let j = (((i + q) % m) + m) % m
                    s += curv[j]
                }
                smooth[i] = s / 13.0
            }
            for i in 0..<m {
                racing.append(max(-15, min(15, smooth[i] * 90)))
                var worst: Float = 0
                for q in 0..<10 {
                    let j = (i + q) % m
                    worst = max(worst, abs(curv[j]))
                }
                cornerF.append(max(0.5, 1.0 - min(0.5, worst * 1.1)))
            }
        }

        func placeProps() {
            let m = count
            if m < 8 { return }
            for g in gates {
                props.append(Prop(x: wpx[g], y: wpy[g], spr: 6))
            }
            var k = 2
            while k < m {
                var nearGate = false
                for g in gates {
                    if abs(g - k) < 3 { nearGate = true }
                }
                if !nearGate {
                    let spr = 4 + ((k / 4) & 1)
                    for side in 0..<2 {
                        let sg: Float = side == 0 ? -1 : 1
                        props.append(Prop(x: wpx[k] + wnx[k] * 38 * sg, y: wpy[k] + wny[k] * 38 * sg, spr: spr))
                    }
                }
                k += 4
            }
        }
    }

    // MARK: - Sprite generation

    static func col(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
        return TrueColorBuffer.rgb(r, g, b)
    }

    static func makeCraft(_ r: Int, _ g: Int, _ bl: Int) -> SpriteImg {
        var p = Pix(30, 16)
        let body = col(r / 2 + 70, g / 2 + 70, bl / 2 + 70)
        let light = col(235, 240, 255)
        let dark = col(r / 4 + 20, g / 4 + 20, bl / 4 + 30)
        let glow = col(r, g, bl)
        p.rect(1, 8, 28, 3, dark)
        p.rect(3, 6, 24, 3, body)
        p.rect(5, 4, 20, 3, body)
        p.rect(3, 6, 24, 1, light)
        p.rect(12, 0, 6, 8, body)
        p.rect(13, 0, 4, 2, light)
        p.rect(11, 3, 8, 3, col(20, 26, 60))
        p.rect(12, 3, 6, 1, glow)
        p.rect(0, 6, 3, 5, glow)
        p.rect(27, 6, 3, 5, glow)
        p.rect(4, 10, 7, 4, col(30, 30, 44))
        p.rect(19, 10, 7, 4, col(30, 30, 44))
        p.rect(5, 11, 5, 3, glow)
        p.rect(20, 11, 5, 3, glow)
        p.rect(6, 12, 3, 2, light)
        p.rect(21, 12, 3, 2, light)
        p.outline(col(6, 6, 16))
        return SpriteImg(w: p.w, h: p.h, pix: p.d, worldW: 17, worldH: 9)
    }

    static func makePylon(_ r: Int, _ g: Int, _ bl: Int) -> SpriteImg {
        var p = Pix(10, 44)
        let glow = col(r, g, bl)
        p.rect(3, 6, 4, 38, col(40, 44, 74))
        p.rect(3, 6, 1, 38, col(100, 110, 170))
        p.rect(0, 0, 10, 6, glow)
        p.rect(2, 1, 6, 3, col(255, 255, 255))
        var y = 12
        while y < 40 {
            p.rect(4, y, 2, 2, glow)
            y += 7
        }
        p.outline(col(6, 6, 16))
        return SpriteImg(w: p.w, h: p.h, pix: p.d, worldW: 7, worldH: 32)
    }

    static func makeGate() -> SpriteImg {
        var p = Pix(96, 44)
        let post = col(60, 66, 110)
        let cyan = col(80, 240, 255)
        let mag = col(255, 80, 220)
        p.rect(0, 6, 6, 38, post)
        p.rect(90, 6, 6, 38, post)
        p.rect(0, 6, 1, 38, col(140, 150, 220))
        p.rect(90, 6, 1, 38, col(140, 150, 220))
        p.rect(0, 0, 96, 10, col(30, 34, 70))
        for x in 0..<96 {
            let c = ((x / 6) & 1) == 0 ? cyan : mag
            p.set(x, 1, c)
            p.set(x, 8, c)
        }
        for x in 6..<90 {
            if (((x / 8) + 0) & 1) == 0 {
                p.set(x, 4, col(255, 255, 255))
                p.set(x + 1, 5, col(255, 255, 255))
            }
        }
        var y = 14
        while y < 42 {
            p.rect(1, y, 4, 2, cyan)
            p.rect(91, y, 4, 2, mag)
            y += 6
        }
        p.outline(col(6, 6, 16))
        return SpriteImg(w: p.w, h: p.h, pix: p.d, worldW: 78, worldH: 40)
    }

    static func makeSprites() -> [SpriteImg] {
        var list: [SpriteImg] = []
        list.append(makeCraft(80, 240, 255))
        list.append(makeCraft(255, 80, 220))
        list.append(makeCraft(255, 160, 40))
        list.append(makeCraft(140, 255, 90))
        list.append(makePylon(80, 240, 255))
        list.append(makePylon(255, 80, 220))
        list.append(makeGate())
        return list
    }

    // MARK: - Game state

    private var phase: Phase = .title
    private var frame = 0
    private var crafts: [Craft] = []
    private var bills: [Bill] = []
    private var camX: Float = 0
    private var camY: Float = 0
    private var camHeading: Float = 0
    private var horizon = 100
    private var lean: Float = 0
    private var cdTimer = 0
    private var aHeld = 0
    private var raceFrames = 0
    private var lapStart = 0
    private var bestLap = 0
    private var place = 4
    private var finishTimer = 0
    private var msg = ""
    private var msgTimer = 0
    private var scoreValue = 0
    private var bumpCooldown = 0
    private var wallCooldown = 0
    private var padCooldown = 0
    private var boostMeter: Float = 50
    private var shield: Float = 100
    private var airFrames = 0
    private var scrapeTimer = 0
    private var scrapeSide: Float = 1
    private var calmFrames = 0
    private var gatesPassed = 0
    private var bonusScore = 0
    private var boostingNow = false
    private var airbrakeNow = false
    private var wrongWay = false
    private var shake = 0
    private var playerSX = 160
    private var playerBottom = 240
    private var playerFinishFrame = 0

    override var score: Int { return max(0, scoreValue) }

    override init() {
        super.init()
        setupRace()
        phase = .title
    }

    override func start() {
        playMusic(HoverRace64.tune)
    }

    // MARK: - Setup

    private func makeCraftAt(back: Int, lane: Float, spr: Int, skill: Float) -> Craft {
        let tr = HoverRace64.track
        let m = max(1, tr.count)
        let idx = ((m - back) % m + m) % m
        var k = Craft()
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
        crafts = []
        crafts.append(makeCraftAt(back: 6, lane: -9, spr: 0, skill: 1.0))
        crafts.append(makeCraftAt(back: 3, lane: 9, spr: 1, skill: 0.93))
        crafts.append(makeCraftAt(back: 4, lane: -9, spr: 2, skill: 0.96))
        crafts.append(makeCraftAt(back: 5, lane: 9, spr: 3, skill: 0.985))
        raceFrames = 0
        lapStart = 0
        bestLap = 0
        place = 4
        lean = 0
        aHeld = 0
        msg = ""
        msgTimer = 0
        scoreValue = 0
        bonusScore = 0
        finishTimer = 0
        playerFinishFrame = 0
        wrongWay = false
        boostMeter = 50
        shield = 100
        airFrames = 0
        scrapeTimer = 0
        calmFrames = 0
        gatesPassed = 0
        padCooldown = 0
        wallCooldown = 0
        shake = 0
        boostingNow = false
        airbrakeNow = false
        camHeading = crafts[0].heading
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

    // MARK: - Track helpers

    private func updateCamera() {
        if crafts.isEmpty { return }
        let p = crafts[0]
        var target: Float = p.heading
        let sp: Float = sqrt(p.vx * p.vx + p.vy * p.vy)
        if sp > 0.5 && phase != .title {
            let va: Float = atan2(p.vy, p.vx)
            target = p.heading + HoverRace64.wrapAngle(va - p.heading) * 0.35
        }
        let diff = HoverRace64.wrapAngle(target - camHeading)
        camHeading += diff * 0.14
        camX = p.x - cos(camHeading) * HoverRace64.camDist
        camY = p.y - sin(camHeading) * HoverRace64.camDist
        let hz: Int = HoverRace64.horizonBase + Int(max(0, min(30, p.z)) * 0.35)
        var sh = 0
        if shake > 0 {
            sh = ((frame & 1) == 0) ? 2 : -2
        }
        horizon = max(90, min(124, hz + sh))
    }

    private func advanceTrack(_ k: inout Craft) {
        let tr = HoverRace64.track
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

    private func progress(_ k: Craft) -> Float {
        let tr = HoverRace64.track
        let j = k.idx
        if j < 0 || j >= tr.count { return Float(k.cum) }
        let px: Float = (k.x - tr.wpx[j]) * tr.wtx[j]
        let py: Float = (k.y - tr.wpy[j]) * tr.wty[j]
        let proj: Float = (px + py) / max(1, tr.spacing)
        return Float(k.cum) + clamp(proj, -1, 1)
    }

    private func currentRank() -> Int {
        if crafts.count < 4 { return 4 }
        if phase == .finished { return place }
        let pp = progress(crafts[0])
        var rank = 1
        for i in 1..<crafts.count {
            if crafts[i].finished || progress(crafts[i]) > pp { rank += 1 }
        }
        return min(4, rank)
    }

    /// Keeps a craft inside the walls. Returns the outward impact speed (0 when not touching).
    private func wallResolve(_ k: inout Craft, _ lim: Float) -> Float {
        let tr = HoverRace64.track
        let j = k.idx
        if j < 0 || j >= tr.count { return 0 }
        let lat: Float = (k.x - tr.wpx[j]) * tr.wnx[j] + (k.y - tr.wpy[j]) * tr.wny[j]
        if abs(lat) <= lim { return 0 }
        let sg: Float = lat > 0 ? 1 : -1
        let push: Float = abs(lat) - lim
        k.x -= tr.wnx[j] * sg * push
        k.y -= tr.wny[j] * sg * push
        let vn: Float = (k.vx * tr.wnx[j] + k.vy * tr.wny[j]) * sg
        scrapeSide = sg
        if vn > 0 {
            k.vx -= 1.45 * vn * tr.wnx[j] * sg
            k.vy -= 1.45 * vn * tr.wny[j] * sg
            return max(0.02, vn)
        }
        return 0.02
    }

    private func sanitize(_ k: inout Craft) {
        if !k.x.isFinite || !k.y.isFinite || !k.heading.isFinite || !k.vx.isFinite || !k.vy.isFinite || !k.speed.isFinite {
            let tr = HoverRace64.track
            let j = max(0, min(tr.count - 1, k.idx))
            if tr.count > 0 {
                k.x = tr.wpx[j]
                k.y = tr.wpy[j]
                k.heading = atan2(tr.wty[j], tr.wtx[j])
            } else {
                k.x = 256
                k.y = 60
                k.heading = 0
            }
            k.vx = 0
            k.vy = 0
            k.speed = 0
        }
        k.x = max(6, min(505, k.x))
        k.y = max(6, min(505, k.y))
    }

    private func applyAir(_ k: inout Craft) -> Bool {
        // returns true on the frame the craft lands
        if k.z > 0 || k.vz > 0 {
            k.z += k.vz
            k.vz -= 0.11
            if k.z <= 0 {
                k.z = 0
                k.vz = 0
                return true
            }
        }
        return false
    }

    // MARK: - AI

    private func driveAI(_ k: inout Craft, rubber: Float, top: Float) {
        let tr = HoverRace64.track
        let m = tr.count
        if m <= 0 { return }
        let look = 3 + Int(max(0, min(3, k.speed)) * 2.2)
        let j = (k.idx + look) % m
        let lane: Float = tr.racing[j] + k.lane * 0.6
        let tx: Float = tr.wpx[j] + tr.wnx[j] * lane
        let ty: Float = tr.wpy[j] + tr.wny[j] * lane
        let desired: Float = atan2(ty - k.y, tx - k.x)
        let diff: Float = HoverRace64.wrapAngle(desired - k.heading)
        k.heading = HoverRace64.wrapAngle(k.heading + clamp(diff, -0.05, 0.05))
        let corner: Float = tr.cornerF[(k.idx + 5) % m]
        var target: Float = top * k.skill * rubber * corner
        if k.boostTimer > 0 {
            k.boostTimer -= 1
            target = max(target, top * 1.3)
        }
        let dv: Float = clamp(target - k.speed, -0.04, 0.03)
        k.speed += dv
        k.speed = max(0, min(3.4, k.speed))
        k.vx = cos(k.heading) * k.speed
        k.vy = sin(k.heading) * k.speed
        k.x += k.vx
        k.y += k.vy
        sanitize(&k)
        advanceTrack(&k)
        let impact = wallResolve(&k, HoverRace64.roadLimit - 1)
        if impact > 0.05 { k.speed *= 0.97 }
        let sf = tr.surface(k.x, k.y)
        if sf == 3 && k.boostTimer <= 0 { k.boostTimer = 55 }
        if sf == 4 && k.z <= 0 && k.speed > 0.8 { k.vz = 1.1 + k.speed * 0.35 }
        _ = applyAir(&k)
    }

    // MARK: - Player

    private func updatePlayer(_ input: InputState) {
        var c = crafts[0]
        let tr = HoverRace64.track
        let airborne: Bool = c.z > 0.01
        let dirIn: Float = Float(input.dx)
        let airbrake: Bool = input.b && input.dx != 0 && !airborne
        let boosting: Bool = input.a && input.b && input.dx == 0 && boostMeter > 0
        airbrakeNow = airbrake
        boostingNow = boosting || c.boostTimer > 0

        // steering first, then split velocity in the new frame so the craft can slide
        let fx0: Float = cos(c.heading)
        let fy0: Float = sin(c.heading)
        let vF0: Float = c.vx * fx0 + c.vy * fy0
        let sp0: Float = min(1, abs(vF0) / 1.1)
        var turn: Float = dirIn * 0.033 * sp0
        if airbrake { turn *= 1.9 }
        if airborne { turn *= 0.35 }
        if vF0 < 0 { turn = -turn }
        c.heading = HoverRace64.wrapAngle(c.heading + turn)
        let fx: Float = cos(c.heading)
        let fy: Float = sin(c.heading)
        let rx: Float = -fy
        let ry: Float = fx
        var vF: Float = c.vx * fx + c.vy * fy
        var vL: Float = c.vx * rx + c.vy * ry

        var top: Float = HoverRace64.topSpeed
        var accel: Float = 0.034
        if shield <= 0 { top = 1.1 }
        if boosting {
            top = 3.0
            accel = 0.07
            boostMeter -= 0.85
            if boostMeter < 0 { boostMeter = 0 }
        } else {
            boostMeter = min(100, boostMeter + 0.03)
        }
        if c.boostTimer > 0 {
            c.boostTimer -= 1
            top = max(top, 3.2)
            accel = max(accel, 0.09)
        }
        if input.a {
            if vF < top { vF += accel }
        } else if input.b && !airbrake {
            vF *= 0.965
        } else {
            vF *= 0.992
        }
        if vF > top {
            let over: Float = vF - top
            vF -= over * 0.05 + 0.004
        }
        vF = max(-0.8, min(3.4, vF))
        if airborne {
            vL *= 0.995
        } else if airbrake {
            vL *= 0.93
            vF *= 0.988
        } else {
            vL *= 0.80
        }
        vL = max(-1.8, min(1.8, vL))
        c.vx = fx * vF + rx * vL
        c.vy = fy * vF + ry * vL
        c.x += c.vx
        c.y += c.vy
        sanitize(&c)
        advanceTrack(&c)

        // walls
        let impact = wallResolve(&c, HoverRace64.roadLimit)
        if impact > 0 && !airborne {
            scrapeTimer = 8
            calmFrames = 0
            shield -= impact * 9.0 + 0.2
            if impact > 0.5 && wallCooldown <= 0 {
                play(.thud)
                wallCooldown = 14
                shake = 6
            }
        } else {
            calmFrames += 1
        }
        if wallCooldown > 0 { wallCooldown -= 1 }
        if shield < 0 { shield = 0 }
        if calmFrames > 90 && shield < 100 { shield = min(100, shield + 0.05) }

        // surfaces
        let sf = tr.surface(c.x, c.y)
        if padCooldown > 0 { padCooldown -= 1 }
        if sf == 3 && padCooldown <= 0 && !airborne {
            c.boostTimer = 70
            boostMeter = min(100, boostMeter + 35)
            padCooldown = 45
            play(.powerup)
            showMsg("BOOST!", 45)
        }
        if sf == 4 && !airborne && vF > 0.6 {
            c.vz = 1.15 + vF * 0.4
            airFrames = 0
            play(.jump)
        }
        if c.z > 0 || c.vz > 0 { airFrames += 1 }
        let landed = applyAir(&c)
        if landed {
            if airFrames > 14 {
                play(.bounce)
                shake = 5
                bonusScore += airFrames
                if airFrames > 30 { showMsg("BIG AIR!", 60) }
            }
            airFrames = 0
        }
        crafts[0] = c
        lean += (dirIn - lean) * 0.2

        let j = max(0, min(tr.count - 1, c.idx))
        if tr.count > 0 {
            let dot: Float = cos(c.heading) * tr.wtx[j] + sin(c.heading) * tr.wty[j]
            let sp: Float = sqrt(c.vx * c.vx + c.vy * c.vy)
            wrongWay = dot < -0.3 && sp > 0.5
        }
        if shield <= 0 && ((frame / 45) & 1) == 0 && msgTimer <= 0 { showMsg("SYSTEMS DOWN", 40) }
        if scrapeTimer > 0 { scrapeTimer -= 1 }
        if shake > 0 { shake -= 1 }
    }

    private func updateRivals() {
        if crafts.count < 2 { return }
        let pp: Float = crafts[0].finished ? 0 : progress(crafts[0])
        for i in 1..<crafts.count {
            var k = crafts[i]
            var rubber: Float = 1
            if !crafts[0].finished {
                let rp = progress(k)
                rubber = clamp(1 - (rp - pp) * 0.010, 0.86, 1.10)
            }
            driveAI(&k, rubber: rubber, top: HoverRace64.topSpeed)
            crafts[i] = k
        }
    }

    private func collisions() {
        let n = crafts.count
        if n < 2 { return }
        for i in 0..<(n - 1) {
            for j in (i + 1)..<n {
                if abs(crafts[i].z - crafts[j].z) > 8 { continue }
                let dx: Float = crafts[j].x - crafts[i].x
                let dy: Float = crafts[j].y - crafts[i].y
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
                    crafts[i].x -= nx * overlap * 0.5
                    crafts[i].y -= ny * overlap * 0.5
                    crafts[j].x += nx * overlap * 0.5
                    crafts[j].y += ny * overlap * 0.5
                    crafts[i].speed *= 0.985
                    crafts[j].speed *= 0.985
                    if i == 0 {
                        crafts[0].vx *= 0.985
                        crafts[0].vy *= 0.985
                        crafts[0].vx -= nx * 0.12
                        crafts[0].vy -= ny * 0.12
                        if bumpCooldown <= 0 {
                            play(.thud)
                            bumpCooldown = 20
                        }
                    }
                }
            }
        }
        if bumpCooldown > 0 { bumpCooldown -= 1 }
    }

    private func trackAndLaps() {
        let tr = HoverRace64.track
        for i in 0..<crafts.count {
            var k = crafts[i]
            let oldIdx = k.idx
            advanceTrack(&k)
            let m = max(1, tr.count)
            if i == 0 {
                let fwd = (k.idx - oldIdx + m) % m
                if fwd > 0 && fwd < 8 {
                    for g in tr.gates {
                        let d = (g - oldIdx + m) % m
                        if d > 0 && d <= fwd {
                            gatesPassed += 1
                            bonusScore += 50
                            boostMeter = min(100, boostMeter + 6)
                            play(.blip)
                        }
                    }
                }
            }
            let done = k.cum >= 0 ? k.cum / m : 0
            if done > k.lapsCounted {
                k.lapsCounted = done
                if done >= HoverRace64.totalLaps && !k.finished {
                    k.finished = true
                    k.finishFrame = raceFrames
                }
                crafts[i] = k
                if i == 0 { playerLapDone(done) }
            } else {
                crafts[i] = k
            }
        }
    }

    private func playerLapDone(_ done: Int) {
        let lapTime = raceFrames - lapStart
        lapStart = raceFrames
        if bestLap == 0 || lapTime < bestLap { bestLap = lapTime }
        if done >= HoverRace64.totalLaps {
            finishRace()
        } else {
            play(.coin)
            if done == HoverRace64.totalLaps - 1 {
                showMsg("FINAL LAP!", 100)
            } else {
                showMsg("LAP " + String(done + 1), 80)
            }
        }
    }

    private func finishRace() {
        var ahead = 0
        for i in 1..<crafts.count {
            if crafts[i].finished { ahead += 1 }
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
        let shieldBonus = Int(shield) * 5
        scoreValue = placeBonus + timeBonus + lapBonus + shieldBonus + bonusScore
        if place <= 2 { play(.win) } else { play(.lose) }
    }

    private func goRace() {
        phase = .racing
        raceFrames = 0
        lapStart = 0
        for i in 1..<crafts.count {
            crafts[i].speed = 0.3 + crafts[i].skill * 0.2
        }
        if aHeld >= 1 && aHeld <= 45 {
            crafts[0].boostTimer = 80
            let fx: Float = cos(crafts[0].heading)
            let fy: Float = sin(crafts[0].heading)
            crafts[0].vx = fx * 1.4
            crafts[0].vy = fy * 1.4
            showMsg("TURBO START!", 90)
            play(.powerup)
        } else {
            play(.confirm)
            if aHeld > 45 { showMsg("TOO EARLY!", 60) }
        }
    }

    override func update(_ input: InputState) {
        frame += 1
        if msgTimer > 0 { msgTimer -= 1 }
        if crafts.count < 4 { setupRace() }
        switch phase {
        case .title:
            for i in 0..<crafts.count {
                var k = crafts[i]
                driveAI(&k, rubber: 1, top: 1.9)
                crafts[i] = k
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
                let p = progress(crafts[0])
                let running = Int(max(0, min(500, p + 6)))
                scoreValue = max(scoreValue, running * 2 + bonusScore)
            }
        case .finished:
            finishTimer += 1
            var k = crafts[0]
            k.vx *= 0.97
            k.vy *= 0.97
            k.x += k.vx
            k.y += k.vy
            sanitize(&k)
            advanceTrack(&k)
            _ = wallResolve(&k, HoverRace64.roadLimit)
            _ = applyAir(&k)
            crafts[0] = k
            lean *= 0.9
            boostingNow = false
            airbrakeNow = false
            updateRivals()
            collisions()
            for i in 1..<crafts.count {
                var r = crafts[i]
                advanceTrack(&r)
                crafts[i] = r
            }
            if shake > 0 { shake -= 1 }
            updateCamera()
            if finishTimer > 60 && (input.aPressed || input.startPressed) {
                play(.confirm)
                startCountdown()
            }
        }
    }

    // MARK: - Rendering

    private func addBill(_ ex: Float, _ ey: Float, _ spr: Int, _ lift: Float, _ scaleUp: Float,
                         _ cs: Float, _ sn: Float, _ minDepth: Float, _ shear: Int) -> Int {
        let sprs = HoverRace64.sprites
        if spr < 0 || spr >= sprs.count { return 160 }
        let dx: Float = ex - camX
        let dy: Float = ey - camY
        let depth: Float = dx * cs + dy * sn
        if depth < minDepth || depth > HoverRace64.maxDist { return 160 }
        let lat: Float = -dx * sn + dy * cs
        let scale: Float = HoverRace64.focal / depth
        let sw = Int(sprs[spr].worldW * scale * scaleUp)
        let sh = Int(sprs[spr].worldH * scale * scaleUp)
        let sxf: Float = 160 + lat * scale
        if sw < 1 || sh < 1 || sw > 900 || sh > 900 { return 160 }
        if !(sxf > -1500 && sxf < 1800) { return 160 }
        let sx = Int(sxf)
        if sx + sw / 2 < 0 || sx - sw / 2 > 320 { return sx }
        let bf: Float = Float(horizon) + (HoverRace64.camHeight - lift) * scale
        let bottom = Int(max(-2000, min(2000, bf)))
        let fog = HoverRace64.fogAmount(depth)
        bills.append(Bill(depth: depth, sx: sx, bottom: bottom, sw: sw, sh: sh, spr: spr, fog: fog, shear: shear))
        return sx
    }

    private func addShadow(_ k: Craft, _ cs: Float, _ sn: Float) {
        let dx: Float = k.x - camX
        let dy: Float = k.y - camY
        let depth: Float = dx * cs + dy * sn
        if depth < 12 || depth > 500 { return }
        let lat: Float = -dx * sn + dy * cs
        let scale: Float = HoverRace64.focal / depth
        let fall: Float = max(0.35, 1.0 - k.z * 0.025)
        let sw = Int(18 * scale * fall)
        let sh = max(2, Int(4 * scale * fall))
        if sw < 2 || sw > 600 { return }
        let sxf: Float = 160 + lat * scale
        if !(sxf > -800 && sxf < 1100) { return }
        let sx = Int(sxf)
        let bf: Float = Float(horizon) + HoverRace64.camHeight * scale
        let bottom = Int(max(-2000, min(2000, bf)))
        bills.append(Bill(depth: depth + 0.5, sx: sx, bottom: bottom, sw: sw, sh: sh, spr: -1, fog: 0, shear: 0))
    }

    private func buildItems(_ cs: Float, _ sn: Float) {
        bills.removeAll(keepingCapacity: true)
        let tr = HoverRace64.track
        for p in tr.props {
            _ = addBill(p.x, p.y, p.spr, 0, 1, cs, sn, 14, 0)
        }
        for i in 0..<crafts.count {
            let k = crafts[i]
            addShadow(k, cs, sn)
            var shear = 0
            if i == 0 { shear = Int(lean * 3) }
            let up: Float = 1.0 + k.z * 0.012
            let sx = addBill(k.x, k.y, k.spr, 3 + k.z, up, cs, sn, 12, shear)
            if i == 0 {
                playerSX = sx
                let scale: Float = HoverRace64.focal / max(12, (k.x - camX) * cs + (k.y - camY) * sn)
                playerBottom = Int(max(-500, min(600, Float(horizon) + (HoverRace64.camHeight - 3 - k.z) * scale)))
            }
        }
        bills.sort { $0.depth > $1.depth }
    }

    private func renderSky(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ heading: Float, _ hz: Int) {
        if hz <= 0 || hz >= h { return }
        let sky = HoverRace64.skyRows
        for y in 0..<hz {
            let idx = max(0, min(159, (y * 159) / max(1, hz - 1)))
            let c = sky[idx]
            let base = y * w
            for x in 0..<w { p[base + x] = c }
        }
        let invTwoPi: Float = 1.0 / (2.0 * Float.pi)
        // stars (slow parallax)
        let stars = HoverRace64.stars
        for s in stars {
            var t: Float = heading * 0.15 * invTwoPi
            t = t - floor(t)
            if !(t >= 0 && t < 1) { t = 0 }
            let shift = Int(t * 1024)
            var rel = (s[0] - shift) & 1023
            if rel > 512 { rel -= 1024 }
            let sx = 160 + rel * 2
            if sx >= 0 && sx < w && s[1] < hz - 20 {
                let v = min(255, s[2] + 60)
                p[s[1] * w + sx] = HoverRace64.rgb(v, v, 255)
            }
        }
        // retro sun with scan-line cutouts
        let sd: Float = HoverRace64.wrapAngle(0.9 - heading * 0.35)
        if abs(sd) < 1.0 {
            let sxf: Float = 160 + tan(sd) * HoverRace64.focal
            let sx = Int(max(-200, min(520, sxf)))
            let top = max(0, hz - 78)
            let cy = hz - 40
            for yy in top..<hz {
                let dyy = yy - cy
                if dyy < -30 || dyy > 30 { continue }
                if dyy > 4 && ((yy / 3) & 1) == 0 { continue }
                let half2 = 900 - dyy * dyy
                if half2 <= 0 { continue }
                let half = Int(sqrt(Float(half2)))
                let t = (dyy + 30) * 255 / 60
                let c = HoverRace64.rgb(255, 230 - (t * 170) / 255, 80 + (t * 140) / 255)
                var xx = sx - half
                let xe = sx + half
                while xx <= xe {
                    if xx >= 0 && xx < w { p[yy * w + xx] = c }
                    xx += 1
                }
            }
        }
        // skyline layers
        let ang = HoverRace64.colAngle
        let far = HoverRace64.skylineFar
        let near = HoverRace64.skylineNear
        let farC = HoverRace64.rgb(38, 20, 84)
        let nearC = HoverRace64.rgb(18, 12, 46)
        for x in 0..<min(w, 320) {
            var tf: Float = (heading * 0.5 + ang[x]) * invTwoPi
            tf = tf - floor(tf)
            if !(tf >= 0 && tf < 1) { tf = 0 }
            let fi = Int(tf * 1024) & 1023
            let fh = far[0][fi]
            let top = max(0, hz - fh)
            for yy in top..<hz { p[yy * w + x] = farC }
            p[top * w + x] = HoverRace64.rgb(120, 70, 190)
            var tn: Float = (heading + ang[x]) * invTwoPi
            tn = tn - floor(tn)
            if !(tn >= 0 && tn < 1) { tn = 0 }
            let ni = Int(tn * 1024) & 1023
            let nh = near[0][ni]
            let bid = near[1][ni]
            let topN = max(0, hz - nh)
            for yy in topN..<hz { p[yy * w + x] = nearC }
            let trim: UInt32 = (bid & 1) == 0 ? HoverRace64.cCyan : HoverRace64.cMagenta
            p[topN * w + x] = trim
            if (ni & 2) == 0 {
                var yy = topN + 3
                while yy < hz - 1 {
                    let hv = HoverRace64.hash(bid, (yy - topN) >> 2)
                    if (hv & 3) == 0 && ((yy - topN) & 3) == 3 {
                        p[yy * w + x] = (hv & 4) == 0 ? HoverRace64.rgb(255, 224, 120) : HoverRace64.rgb(120, 230, 255)
                    }
                    yy += 1
                }
            }
        }
    }

    private func renderFloor(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ tp: UnsafeMutablePointer<UInt32>,
                             _ cx: Float, _ cy: Float, _ cosH: Float, _ sinH: Float, _ hz: Int) {
        let rows = min(h, 288)
        if hz + 1 >= rows { return }
        let rightX: Float = -sinH
        let rightY: Float = cosH
        let halfW: Float = Float(w / 2)
        let focal = HoverRace64.focal
        let maxD = HoverRace64.maxDist
        let outside = HoverRace64.voidColor
        let haze = HoverRace64.hazeColor
        let rowDist = HoverRace64.rowDist
        let rowFog = HoverRace64.rowFog
        for y in (hz + 1)..<rows {
            let r = y - hz
            if r < 1 || r >= 288 { continue }
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
                if t > 0 { c = HoverRace64.mix(c, t) }
                p[base + x] = c
                px += ddx
                py += ddy
            }
        }
        // the strip above r = 1 (row hz itself) takes the haze colour
        let hb = hz * w
        if hz >= 0 && hz < rows {
            for x in 0..<w { p[hb + x] = haze }
        }
    }

    private func blit(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ item: Bill) {
        if item.spr < 0 {
            blitShadow(p, w, h, item)
            return
        }
        let sprs = HoverRace64.sprites
        if item.spr >= sprs.count { return }
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
                    let c = sp[srow + sxp]
                    if c != 0 {
                        if fog > 0 {
                            p[rowBase + x] = HoverRace64.mix(c, fog)
                        } else {
                            p[rowBase + x] = c
                        }
                    }
                }
            }
        }
    }

    private func blitShadow(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ item: Bill) {
        let hh = max(1, item.sh / 2)
        let hw = max(1, item.sw / 2)
        let yTop = max(0, item.bottom - hh)
        let yBot = min(h, item.bottom + hh + 1)
        if yTop >= yBot { return }
        for y in yTop..<yBot {
            let dy: Float = Float(y - item.bottom) / Float(hh)
            let k: Float = 1.0 - dy * dy
            if k <= 0 { continue }
            let half = Int(Float(hw) * sqrt(k))
            let xs = max(0, item.sx - half)
            let xe = min(w, item.sx + half + 1)
            if xs >= xe { continue }
            let base = y * w
            for x in xs..<xe {
                let c = p[base + x]
                p[base + x] = 0xFF00_0000 | ((c >> 1) & 0x007F_7F7F)
            }
        }
    }

    override func drawTrueColor(_ b: TrueColorBuffer) {
        let tr = HoverRace64.track
        let heading = camHeading
        let cs: Float = cos(heading)
        let sn: Float = sin(heading)
        buildItems(cs, sn)
        let list = bills
        let cx = camX
        let cy = camY
        let tp = tr.tex
        let hz = horizon
        b.withPixels { p, w, h in
            if w < 64 || h < 200 { return }
            self.renderSky(p, w, h, heading, hz)
            self.renderFloor(p, w, h, tp, cx, cy, cs, sn, hz)
            for it in list { self.blit(p, w, h, it) }
        }
        drawEffects(b)
        drawHUD(b)
        drawOverlays(b)
    }

    // MARK: - HUD

    private func otext(_ b: TrueColorBuffer, _ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        let k = max(1, scale / 2)
        let o = HoverRace64.cBlack
        b.text(s, x - k, y, o, scale: scale)
        b.text(s, x + k, y, o, scale: scale)
        b.text(s, x, y - k, o, scale: scale)
        b.text(s, x, y + k, o, scale: scale)
        b.text(s, x - k, y - k, o, scale: scale)
        b.text(s, x + k, y + k, o, scale: scale)
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

    private func bar(_ b: TrueColorBuffer, _ x: Int, _ y: Int, _ w: Int, _ h: Int, _ frac: Float, _ c: UInt32) {
        b.fillRect(x - 2, y - 2, w + 4, h + 4, HoverRace64.cBlack)
        b.fillRect(x, y, w, h, TrueColorBuffer.rgb(44, 44, 70))
        let fw = Int(clamp(frac, 0, 1) * Float(w))
        if fw > 0 { b.fillRect(x, y, fw, h, c) }
    }

    private func drawEffects(_ b: TrueColorBuffer) {
        if phase != .racing && phase != .finished && phase != .countdown { return }
        if crafts.isEmpty { return }
        let k = crafts[0]
        let spd: Float = sqrt(k.vx * k.vx + k.vy * k.vy)
        if boostingNow || spd > 2.5 {
            let streak = boostingNow ? TrueColorBuffer.rgb(255, 240, 180) : TrueColorBuffer.rgb(170, 200, 255)
            for i in 0..<14 {
                let yy = 30 + ((i * 53 + frame * 11) % 200)
                let len = 10 + ((i * 7) % 16)
                let left = (i & 1) == 0
                let xx = left ? ((i * 13 + frame * 5) % 44) : (320 - len - ((i * 17 + frame * 5) % 44))
                b.fillRect(xx, yy, len, 1, streak)
            }
        }
        if boostingNow || (phase == .countdown && aHeld > 0) {
            let fl = TrueColorBuffer.rgb(255, 150, 30)
            let fl2 = TrueColorBuffer.rgb(255, 245, 140)
            let fx = playerSX
            let fy = playerBottom - 6
            let flick = 5 + (frame & 3) * 2
            b.fillRect(fx - 11, fy, 5, flick, fl)
            b.fillRect(fx + 6, fy, 5, flick, fl)
            b.fillRect(fx - 10, fy, 3, flick / 2, fl2)
            b.fillRect(fx + 7, fy, 3, flick / 2, fl2)
        }
        if scrapeTimer > 0 && phase == .racing {
            let spark = TrueColorBuffer.rgb(255, 230, 90)
            let spark2 = TrueColorBuffer.rgb(255, 140, 30)
            let side = Int(scrapeSide)
            for i in 0..<9 {
                let hsh = (frame * 7919 + i * 104729) & 255
                let ox = side * (14 + (hsh % 14))
                let oy = (hsh / 7) % 16
                let size = 1 + (hsh & 1)
                b.fillRect(playerSX + ox, playerBottom - oy, size + 1, size + 1, (i & 1) == 0 ? spark : spark2)
            }
        }
        if airbrakeNow && phase == .racing {
            let c = TrueColorBuffer.rgb(200, 220, 255)
            let dirSign = lean >= 0 ? 1 : -1
            for i in 0..<6 {
                let hsh = (frame * 3331 + i * 7717) & 127
                b.fillRect(playerSX - dirSign * (16 + hsh % 18) - 2, playerBottom - 6 - (hsh / 9), 6, 1, c)
            }
        }
    }

    private func drawMinimap(_ b: TrueColorBuffer) {
        let tr = HoverRace64.track
        let mx = 254
        let my = 8
        b.fillRect(mx - 2, my - 2, 64, 64, HoverRace64.cBlack)
        b.fillRect(mx, my, 60, 60, TrueColorBuffer.rgb(14, 14, 44))
        let road = TrueColorBuffer.rgb(120, 180, 255)
        let n = min(tr.miniX.count, tr.miniY.count)
        for i in 0..<n {
            b.fillRect(mx + tr.miniX[i], my + tr.miniY[i], 2, 2, road)
        }
        if n > 0 {
            b.fillRect(mx + tr.miniX[0] - 1, my + tr.miniY[0] - 1, 4, 4, HoverRace64.cYellow)
        }
        var i = crafts.count - 1
        while i >= 0 {
            let k = crafts[i]
            let kx = max(0, min(59, Int(k.x * 0.1171875)))
            let ky = max(0, min(59, Int(k.y * 0.1171875)))
            let colIdx = max(0, min(HoverRace64.craftCols.count - 1, i))
            if i == 0 {
                b.fillRect(mx + kx - 3, my + ky - 3, 7, 7, HoverRace64.cBlack)
                b.fillRect(mx + kx - 2, my + ky - 2, 5, 5, HoverRace64.craftCols[colIdx])
            } else {
                b.fillRect(mx + kx - 2, my + ky - 2, 5, 5, HoverRace64.cBlack)
                b.fillRect(mx + kx - 1, my + ky - 1, 3, 3, HoverRace64.craftCols[colIdx])
            }
            i -= 1
        }
    }

    private func drawHUD(_ b: TrueColorBuffer) {
        if phase == .title { return }
        let rank = currentRank()
        let pn = HoverRace64.placeNames[max(0, min(3, rank - 1))]
        otext(b, pn, 8, 8, rank == 1 ? HoverRace64.cYellow : HoverRace64.cWhite, 5)
        otext(b, "/4", 68, 20, HoverRace64.cWhite, 2)
        var lap = 1
        if crafts.count > 0 { lap = min(HoverRace64.totalLaps, crafts[0].lapsCounted + 1) }
        otext(b, "LAP " + String(lap) + "/" + String(HoverRace64.totalLaps), 8, 38, HoverRace64.cWhite, 2)
        let shownTime = phase == .finished ? playerFinishFrame : raceFrames
        otext(b, timeString(shownTime), 8, 56, HoverRace64.cCyan, 2)

        var spd: Float = 0
        if crafts.count > 0 { spd = sqrt(crafts[0].vx * crafts[0].vx + crafts[0].vy * crafts[0].vy) }
        let kph = Int(max(0, min(999, spd * 100)))
        otext(b, String(kph), 8, 250, HoverRace64.cWhite, 3)
        otext(b, "KPH", 8 + b.textWidth(String(kph), scale: 3) + 6, 258, HoverRace64.cWhite, 1)
        // boost and shield bars
        b.text("BOOST", 92, 242, HoverRace64.cOrange, scale: 1)
        bar(b, 92, 250, 90, 6, boostMeter / 100.0, boostingNow ? HoverRace64.cYellow : HoverRace64.cOrange)
        b.text("SHIELD", 92, 262, HoverRace64.cCyan, scale: 1)
        var shc = HoverRace64.cCyan
        if shield < 30 { shc = ((frame / 6) & 1) == 0 ? HoverRace64.cRed : TrueColorBuffer.rgb(255, 160, 160) }
        bar(b, 92, 270, 90, 6, shield / 100.0, shc)

        drawMinimap(b)
    }

    private func drawOverlays(_ b: TrueColorBuffer) {
        let yellow = HoverRace64.cYellow
        let white = HoverRace64.cWhite
        switch phase {
        case .title:
            b.fillRect(22, 36, 276, 148, HoverRace64.cBlack)
            b.fillRect(24, 38, 272, 144, HoverRace64.cPanel)
            b.fillRect(24, 38, 272, 3, HoverRace64.cCyan)
            b.fillRect(24, 179, 272, 3, HoverRace64.cMagenta)
            ctext(b, "HOVER", 50, HoverRace64.cCyan, 8)
            ctext(b, "RACE 64", 98, HoverRace64.cMagenta, 6)
            ctext(b, "3 LAPS  3 RIVALS  NIGHT CITY", 148, white, 1)
            ctext(b, "ANTI-GRAVITY CIRCUIT", 162, yellow, 1)
            if (frame / 30) & 1 == 0 { ctext(b, "PRESS A TO RACE", 198, yellow, 3) }
            ctext(b, "A THROTTLE  A+B BOOST", 232, white, 1)
            ctext(b, "B+LEFT OR RIGHT AIR-BRAKE", 244, white, 1)
        case .countdown:
            if cdTimer > 180 {
                ctext(b, "READY", 70, white, 8)
            } else if cdTimer > 0 {
                let d = (cdTimer + 59) / 60
                ctext(b, String(d), 56, yellow, 14)
            }
            if cdTimer <= 150 { ctext(b, "HOLD A AT GO FOR A TURBO START", 236, white, 1) }
        case .racing:
            if raceFrames < 50 { ctext(b, "GO!", 60, HoverRace64.cGreen, 12) }
            if msgTimer > 0 { ctext(b, msg, 100, yellow, 3) }
            if wrongWay && (frame / 12) & 1 == 0 { ctext(b, "WRONG WAY!", 140, HoverRace64.cRed, 4) }
        case .finished:
            b.fillRect(38, 58, 244, 176, HoverRace64.cBlack)
            b.fillRect(40, 60, 240, 172, HoverRace64.cPanel)
            b.fillRect(40, 60, 240, 3, HoverRace64.cCyan)
            ctext(b, "RACE OVER", 72, white, 4)
            let pn = HoverRace64.placeNames[max(0, min(3, place - 1))] + " PLACE"
            ctext(b, pn, 108, place == 1 ? yellow : white, 4)
            ctext(b, "TIME " + timeString(playerFinishFrame), 148, white, 2)
            ctext(b, "BEST LAP " + timeString(bestLap), 168, white, 2)
            ctext(b, "SCORE " + zeroPad(scoreValue, 5), 188, yellow, 2)
            if finishTimer > 60 && (frame / 30) & 1 == 0 { ctext(b, "PRESS A", 210, white, 2) }
        }
    }
}

extension Cartridge {
    static let hoverRace64 = Cartridge(
        id: "hover64", title: "HOVER RACE 64", genre: "Racing",
        blurb: "Anti-gravity night racing with drift physics, boost pads, jump ramps and bouncy walls that drain your shield.",
        controls: "A throttle, A+B boost, B+LEFT/RIGHT air-brake drift, LEFT/RIGHT steer. Hold A at GO for a turbo start.",
        era: .n64, labelTop: 0xFF50DC, labelBottom: 0x101048, factory: { HoverRace64() })
}
