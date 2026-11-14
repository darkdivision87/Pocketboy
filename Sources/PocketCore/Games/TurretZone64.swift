#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// TURRET ZONE 64: you man a twin-barrel turret on a floating sky-city rooftop. The view rotates through 360 degrees
/// over a procedural panorama (parallax cloud and skyline layers that wrap seamlessly) and a polar-checker deck with a
/// ring road. Cartoon robots, drones, bomber blimps and bosses approach from the horizon as scaled billboards. Soft
/// auto-lock, hitscan plasma with tracers, a charge-up bomb, upgrade cards between waves, 10 waves and endless mode.
final class TurretZone64: Game {
    // MARK: - Constants

    static let focal: Float = 200.0
    static let twoPi: Float = 6.2831853
    static let groundDrop: Float = 2.4
    static let maxWave = 10
    static let eyeY = 128

    static let cWhite: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    static let cBlack: UInt32 = TrueColorBuffer.rgb(24, 14, 44)
    static let cYellow: UInt32 = TrueColorBuffer.rgb(255, 228, 70)
    static let cRed: UInt32 = TrueColorBuffer.rgb(255, 80, 96)
    static let cGreen: UInt32 = TrueColorBuffer.rgb(100, 240, 130)
    static let cCyan: UInt32 = TrueColorBuffer.rgb(90, 232, 255)
    static let cOrange: UInt32 = TrueColorBuffer.rgb(255, 154, 40)
    static let cPink: UInt32 = TrueColorBuffer.rgb(255, 120, 204)
    static let cPanel: UInt32 = TrueColorBuffer.rgb(40, 34, 104)
    static let cBarBack: UInt32 = TrueColorBuffer.rgb(70, 60, 130)

    static let tune = Tune(bpm: 146, wave: .pulse50, volume: 0.11,
        "G4:0.5 C5:0.5 E5:0.5 G5:1 E5:0.5 C5:0.5 D5:0.5 F5:0.5 A5:1 F5:0.5 D5:0.5 E5:0.5 G5:0.5 C6:1 G5:0.5 E5:0.5 F5:0.5 D5:0.5 B4:0.5 D5:0.5 G5:1.5 R:0.5")

    // sky palettes: top rgb, horizon rgb, tint rgb, tint amount
    static let skyPal: [[Int]] = [
        [60, 140, 255, 196, 232, 255, 255, 255, 255, 0],
        [110, 120, 225, 255, 205, 160, 255, 170, 120, 60],
        [60, 52, 150, 255, 160, 196, 150, 100, 210, 80]
    ]

    // wave table: walkers, drones, blimps, boss variant + 1 (0 = none)
    static let waveTable: [[Int]] = [
        [5, 0, 0, 0],
        [5, 2, 0, 0],
        [6, 3, 0, 0],
        [4, 2, 1, 1],
        [7, 4, 1, 0],
        [6, 5, 2, 0],
        [5, 4, 2, 2],
        [8, 6, 2, 0],
        [8, 7, 3, 0],
        [6, 6, 3, 3]
    ]

    static let upgradeNames: [String] = ["DAMAGE", "FAST GUNS", "SHIELD", "BOMB", "REPAIR"]
    static let upgradeDesc1: [String] = ["+25% PLASMA", "SHOOT FASTER", "+30 ENERGY", "CHARGES FASTER", "+45 BASE"]
    static let upgradeDesc2: [String] = ["POWER", "AND SMOOTHER", "SHIELD", "AND +40 NOW", "HEALTH"]

    // sprite indices
    static let sprDrone = 4
    static let sprBlimp = 8
    static let sprBoss = 10
    static let sprBall = 16
    static let sprBomb = 17
    static let sprPuff = 18

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

        mutating func ellipse(_ cx: Int, _ cy: Int, _ rx: Int, _ ry: Int, _ c: UInt32) {
            if rx < 1 || ry < 1 { return }
            for yy in (cy - ry)...(cy + ry) {
                for xx in (cx - rx)...(cx + rx) {
                    let fx: Float = Float(xx - cx) / Float(rx)
                    let fy: Float = Float(yy - cy) / Float(ry)
                    if fx * fx + fy * fy <= 1.0 { set(xx, yy, c) }
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

    struct SpriteImg {
        var w: Int
        var h: Int
        var pix: [UInt32]
    }

    /// Column-major panorama strip, 0 = transparent. Wraps horizontally.
    struct Layer {
        var w: Int
        var h: Int
        var px: [UInt32]
    }

    struct Enemy {
        var kind: Int = 0
        var variant: Int = 0
        var az: Float = 0
        var d: Float = 42
        var hp: Float = 3
        var maxHp: Float = 3
        var alive: Bool = true
        var state: Int = 0
        var timer: Int = 0
        var cd: Int = 100
        var flash: Int = 0
        var phase: Float = 0
        var orbit: Float = 1
        var speed: Float = 0.06
        var stand: Float = 14
    }

    struct Ball {
        var az: Float
        var d: Float
        var h: Float
        var vd: Float
        var vh: Float
        var kind: Int
        var dmg: Int
        var alive: Bool
    }

    struct Part {
        var az: Float
        var d: Float
        var h: Float
        var vaz: Float
        var vh: Float
        var life: Int
        var col: UInt32
        var size: Float
    }

    struct Burst {
        var az: Float
        var d: Float
        var h: Float
        var t: Int
        var maxT: Int
        var size: Float
    }

    struct Pop {
        var az: Float
        var d: Float
        var h: Float
        var t: Int
        var text: String
        var color: UInt32
        var big: Bool
    }

    struct Tracer {
        var x0: Int
        var y0: Int
        var x1: Int
        var y1: Int
        var t: Int
    }

    struct Bill {
        var depth: Float
        var sx: Int
        var bottom: Int
        var sw: Int
        var sh: Int
        var spr: Int
        var white: Int
        var orange: Bool
        var fog: Int
        var hpFrac: Float
        var boss: Bool
    }

    enum Phase { case title, playing, clear, upgrade, over }

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

    static func norm2Pi(_ a: Float) -> Float {
        if !a.isFinite { return 0 }
        var d = a
        while d >= twoPi { d -= twoPi }
        while d < 0 { d += twoPi }
        return d
    }

    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
        return TrueColorBuffer.rgb(r, g, b)
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

    static let colAng: [Float] = {
        var a = [Float](repeating: 0, count: 320)
        for x in 0..<320 {
            let dx: Float = Float(x) - 159.5
            a[x] = atan(dx / TurretZone64.focal)
        }
        return a
    }()

    static let invCos: [Float] = {
        var a = [Float](repeating: 1, count: 320)
        for x in 0..<320 {
            let c: Float = cos(TurretZone64.colAng[x])
            a[x] = c > 0.05 ? 1.0 / c : 20.0
        }
        return a
    }()

    static let layerClouds: Layer = TurretZone64.makeClouds()
    static let layerFar: Layer = TurretZone64.makeFarCity()
    static let layerNear: Layer = TurretZone64.makeNearCity()
    static let sprites: [SpriteImg] = TurretZone64.makeSprites()

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

    // MARK: - Panorama layers

    static func makeClouds() -> Layer {
        let w = 640
        let h = 60
        var px = [UInt32](repeating: 0, count: w * h)
        func put(_ x: Int, _ y: Int, _ c: UInt32) {
            if y < 0 || y >= h { return }
            let xx = ((x % w) + w) % w
            px[xx * h + y] = c
        }
        func ell(_ cx: Int, _ cy: Int, _ rx: Int, _ ry: Int, _ c: UInt32) {
            if rx < 1 || ry < 1 { return }
            for yy in (cy - ry)...(cy + ry) {
                for xx in (cx - rx)...(cx + rx) {
                    let fx: Float = Float(xx - cx) / Float(rx)
                    let fy: Float = Float(yy - cy) / Float(ry)
                    if fx * fx + fy * fy <= 1.0 { put(xx, yy, c) }
                }
            }
        }
        let shade = rgb(222, 232, 252)
        let lite = rgb(255, 255, 255)
        for k in 0..<20 {
            let cx = (k * 33 + (hash(k, 3) % 28)) % w
            let cy = 20 + (hash(k, 5) % 26)
            let r = 6 + (hash(k, 7) % 8)
            ell(cx, cy, r * 2, r, shade)
            ell(cx - r, cy + 3, r * 3 / 2, r * 3 / 4, shade)
            ell(cx + r * 2, cy + 3, r * 3 / 2, r * 3 / 4, shade)
            ell(cx, cy - 2, r * 2 - 3, r - 2, lite)
            ell(cx - r, cy + 1, r * 3 / 2 - 2, r * 3 / 4 - 1, lite)
            ell(cx + r * 2, cy + 1, r * 3 / 2 - 2, r * 3 / 4 - 1, lite)
        }
        return Layer(w: w, h: h, px: px)
    }

    static func makeFarCity() -> Layer {
        let w = 900
        let h = 70
        var px = [UInt32](repeating: 0, count: w * h)
        func put(_ x: Int, _ y: Int, _ c: UInt32) {
            if y < 0 || y >= h { return }
            let xx = ((x % w) + w) % w
            px[xx * h + y] = c
        }
        func box(_ x: Int, _ y: Int, _ bw: Int, _ bh: Int, _ c: UInt32) {
            if bw <= 0 || bh <= 0 { return }
            for yy in y..<(y + bh) {
                for xx in x..<(x + bw) { put(xx, yy, c) }
            }
        }
        let wall = rgb(172, 188, 236)
        let roof = rgb(196, 208, 248)
        let win = rgb(208, 220, 252)
        let haze = rgb(178, 196, 238)
        // floating islands
        for k in 0..<6 {
            let cx = k * 150 + 40 + (hash(k, 11) % 40)
            let cy = 6 + (hash(k, 13) % 16)
            box(cx - 18, cy, 36, 4, rgb(168, 220, 192))
            box(cx - 5, cy - 7, 10, 7, rgb(214, 200, 240))
            box(cx - 6, cy - 9, 12, 2, rgb(232, 170, 190))
            for i in 0..<9 {
                box(cx - 17 + i * 2, cy + 4 + i, 34 - i * 4, 1, rgb(186, 170, 206))
            }
        }
        var x = 0
        while x < w {
            let bw = 12 + (hash(x, 21) % 20)
            let bh = 14 + (hash(x, 23) % 34)
            let top = h - 12 - bh
            box(x, top, bw, bh, wall)
            box(x, top, bw, 2, roof)
            var wy = top + 5
            while wy < h - 14 {
                var wx = x + 3
                while wx < x + bw - 3 {
                    put(wx, wy, win)
                    wx += 4
                }
                wy += 5
            }
            if hash(x, 29) % 5 == 0 {
                box(x + bw / 2, top - 12, 2, 12, wall)
            }
            x += bw + (hash(x, 31) % 5)
        }
        box(0, h - 12, w, 12, haze)
        return Layer(w: w, h: h, px: px)
    }

    static func makeNearCity() -> Layer {
        let w = 1257
        let h = 80
        var px = [UInt32](repeating: 0, count: w * h)
        func put(_ x: Int, _ y: Int, _ c: UInt32) {
            if y < 0 || y >= h { return }
            let xx = ((x % w) + w) % w
            px[xx * h + y] = c
        }
        func box(_ x: Int, _ y: Int, _ bw: Int, _ bh: Int, _ c: UInt32) {
            if bw <= 0 || bh <= 0 { return }
            for yy in y..<(y + bh) {
                for xx in x..<(x + bw) { put(xx, yy, c) }
            }
        }
        let pal: [[Int]] = [[255, 150, 176], [120, 226, 190], [255, 214, 100], [140, 190, 255], [200, 160, 255], [255, 170, 110]]
        let ink = rgb(70, 50, 120)
        var x = 0
        var idx = 0
        while x < w {
            let bw = 14 + (hash(x, 41) % 18)
            let bh = 20 + (hash(x, 43) % 36)
            let top = h - 8 - bh
            let pc = pal[(hash(x, 47) + idx) % pal.count]
            let wall = rgb(pc[0], pc[1], pc[2])
            let dark = rgb(pc[0] * 7 / 10, pc[1] * 7 / 10, pc[2] * 7 / 10)
            box(x, top, bw, bh, wall)
            box(x + bw - 3, top, 3, bh, dark)
            box(x, top, 1, bh, ink)
            box(x + bw - 1, top, 1, bh, ink)
            box(x, top, bw, 1, ink)
            var wy = top + 4
            while wy < h - 12 {
                var wx = x + 3
                while wx < x + bw - 5 {
                    let lit = (hash(wx, wy) & 3) != 0
                    box(wx, wy, 2, 3, lit ? rgb(255, 250, 220) : rgb(110, 130, 200))
                    wx += 5
                }
                wy += 7
            }
            let roofKind = hash(x, 53) % 4
            if roofKind == 0 {
                for i in 0..<(bw / 2) {
                    box(x + i, top - 1 - i / 2, bw - 2 * i, 1, dark)
                }
            } else if roofKind == 1 {
                box(x + bw / 2, top - 14, 2, 14, ink)
                box(x + bw / 2 - 1, top - 16, 4, 3, rgb(255, 90, 100))
            } else if roofKind == 2 {
                box(x + 3, top - 5, bw - 6, 5, dark)
                box(x + 5, top - 8, bw - 10, 3, dark)
            }
            idx += 1
            x += bw + (hash(x, 59) % 4)
        }
        box(0, h - 8, w, 8, rgb(112, 100, 176))
        box(0, h - 8, w, 2, rgb(206, 196, 246))
        return Layer(w: w, h: h, px: px)
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

    static func makeBlimp(_ variant: Int) -> SpriteImg {
        var p = Pix(64, 44)
        let ink = rgb(30, 20, 50)
        var ca = rgb(255, 90, 110)
        var cb = rgb(255, 245, 245)
        if variant == 1 {
            ca = rgb(70, 150, 255)
            cb = rgb(255, 232, 110)
        }
        for y in 0..<30 {
            for x in 0..<64 {
                let fx: Float = (Float(x) - 31.5) / 31.0
                let fy: Float = (Float(y) - 14.5) / 14.5
                if fx * fx + fy * fy <= 1.0 {
                    var c = ((x / 8) & 1) == 0 ? ca : cb
                    if y < 6 { c = rgb(255, 255, 255) }
                    if y > 24 { c = rgb(190, 90, 110) }
                    p.set(x, y, c)
                }
            }
        }
        p.rect(0, 10, 6, 10, ca)
        p.rect(2, 4, 4, 8, cb)
        p.rect(2, 18, 4, 8, cb)
        p.rect(24, 30, 16, 9, rgb(150, 110, 90))
        p.rect(26, 32, 12, 4, rgb(255, 240, 170))
        p.rect(28, 29, 2, 3, ink)
        p.rect(34, 29, 2, 3, ink)
        p.rect(58, 12, 3, 8, rgb(210, 214, 226))
        p.disc(24, 13, 4, rgb(255, 255, 255))
        p.disc(40, 13, 4, rgb(255, 255, 255))
        p.disc(25, 14, 2, ink)
        p.disc(41, 14, 2, ink)
        p.rect(20, 7, 8, 2, ink)
        p.rect(36, 7, 8, 2, ink)
        p.rect(28, 20, 8, 2, ink)
        p.outline(ink)
        return SpriteImg(w: p.w, h: p.h, pix: p.d)
    }

    static func makeMech(_ variant: Int, _ frame: Int) -> SpriteImg {
        var p = Pix(64, 72)
        var body = rgb(255, 120, 60)
        var light = rgb(255, 190, 120)
        var dark = rgb(190, 70, 40)
        if variant == 2 {
            body = rgb(170, 100, 240)
            light = rgb(215, 170, 255)
            dark = rgb(110, 60, 180)
        }
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

    static func makeSaucer(_ frame: Int) -> SpriteImg {
        var p = Pix(72, 44)
        let ink = rgb(30, 20, 50)
        p.ellipse(36, 14, 16, 13, rgb(120, 230, 255))
        p.ellipse(33, 10, 8, 6, rgb(210, 250, 255))
        p.disc(36, 15, 6, rgb(255, 255, 255))
        p.disc(36, 16, 3, ink)
        p.ellipse(36, 26, 34, 10, rgb(150, 120, 230))
        p.ellipse(36, 23, 32, 6, rgb(190, 170, 250))
        for i in 0..<7 {
            let on = ((i + frame) & 1) == 0
            p.disc(8 + i * 9, 28, 2, on ? rgb(255, 230, 70) : rgb(255, 120, 150))
        }
        p.rect(32, 34, 8, 7, rgb(196, 202, 216))
        p.rect(30, 40, 12, 2, rgb(255, 150, 40))
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

    static func makeBomb() -> SpriteImg {
        var p = Pix(28, 32)
        let ink = rgb(30, 20, 50)
        p.disc(14, 19, 11, rgb(60, 56, 84))
        p.disc(10, 15, 3, rgb(150, 150, 190))
        p.rect(12, 5, 4, 5, rgb(180, 150, 90))
        p.rect(14, 2, 6, 2, rgb(180, 150, 90))
        p.disc(22, 2, 2, rgb(255, 220, 70))
        p.set(22, 2, rgb(255, 255, 255))
        p.rect(9, 20, 10, 4, rgb(255, 90, 100))
        p.outline(ink)
        return SpriteImg(w: p.w, h: p.h, pix: p.d)
    }

    static func makeSprites() -> [SpriteImg] {
        var list: [SpriteImg] = []
        list.append(makeWalker(246, 90, 96, 0))
        list.append(makeWalker(246, 90, 96, 1))
        list.append(makeWalker(92, 210, 110, 0))
        list.append(makeWalker(92, 210, 110, 1))
        list.append(makeDrone(255, 190, 50, 0))
        list.append(makeDrone(255, 190, 50, 1))
        list.append(makeDrone(80, 214, 230, 0))
        list.append(makeDrone(80, 214, 230, 1))
        list.append(makeBlimp(0))
        list.append(makeBlimp(1))
        list.append(makeMech(0, 0))
        list.append(makeMech(0, 1))
        list.append(makeSaucer(0))
        list.append(makeSaucer(1))
        list.append(makeMech(2, 0))
        list.append(makeMech(2, 1))
        list.append(makeOrb(rgb(255, 255, 210), rgb(255, 160, 30), rgb(240, 70, 24), false))
        list.append(makeBomb())
        list.append(makeOrb(rgb(255, 255, 230), rgb(255, 214, 90), rgb(255, 130, 60), true))
        return list
    }

    // MARK: - Game state

    private var phase: Phase = .title
    private var frame = 0
    private var rng = Rng()

    private var yaw: Float = 0
    private var pitch: Float = 0
    private var turnHold = 0
    private var baseHP = 120
    private var baseMax = 120
    private var shield = 0
    private var shieldMax = 0
    private var dmgLv = 0
    private var rateLv = 0
    private var chargeLv = 0
    private var bomb: Float = 0
    private var fireCD = 0
    private var recoil = 0
    private var muzzle = 0
    private var gunSide = 0
    private var shake = 0
    private var dmgFlash = 0
    private var bombFlash = 0
    private var bombRing = 0
    private var hitMarker = 0
    private var lockKind = 0
    private var lockIdx = -1
    private var lockSX: Float = 160
    private var lockSY: Float = 128
    private var lockR: Float = 20
    private var showRadar = true

    private var enemies: [Enemy] = []
    private var balls: [Ball] = []
    private var parts: [Part] = []
    private var bursts: [Burst] = []
    private var pops: [Pop] = []
    private var tracers: [Tracer] = []
    private var bills: [Bill] = []
    private var queue: [Int] = []
    private var queueVar: [Int] = []
    private var lanes: [Float] = [0, 3]
    private var spawnT = 0

    private var wave = 0
    private var endless = false
    private var waveBanner = 0
    private var clearT = 0
    private var overTimer = 0
    private var victory = false
    private var scoreValue = 0
    private var kills = 0
    private var combo = 0
    private var comboT = 0
    private var bestCombo = 0
    private var shots = 0
    private var hits = 0
    private var hintT = 0
    private var cards: [Int] = [0, 1, 2]
    private var cardSel = 0
    private var upgradeT = 0
    private var bonusText = 0

    override var score: Int { return max(0, scoreValue) }

    override init() {
        super.init()
        resetGame()
        phase = .title
    }

    override func start() {
        playMusic(TurretZone64.tune)
    }

    // MARK: - Setup

    private func resetGame() {
        yaw = 0
        pitch = 0
        turnHold = 0
        baseHP = 120
        baseMax = 120
        shield = 0
        shieldMax = 0
        dmgLv = 0
        rateLv = 0
        chargeLv = 0
        bomb = 0
        fireCD = 0
        recoil = 0
        muzzle = 0
        shake = 0
        dmgFlash = 0
        bombFlash = 0
        bombRing = 0
        hitMarker = 0
        lockKind = 0
        lockIdx = -1
        enemies = []
        balls = []
        parts = []
        bursts = []
        pops = []
        tracers = []
        queue = []
        queueVar = []
        wave = 0
        endless = false
        waveBanner = 0
        clearT = 0
        overTimer = 0
        victory = false
        scoreValue = 0
        kills = 0
        combo = 0
        comboT = 0
        bestCombo = 0
        shots = 0
        hits = 0
        hintT = 0
    }

    private func beginGame() {
        resetGame()
        hintT = 900
        startWave(1)
        phase = .playing
    }

    private func waveCounts(_ n: Int) -> [Int] {
        if n >= 1 && n <= TurretZone64.waveTable.count {
            return TurretZone64.waveTable[n - 1]
        }
        let w = min(12, 5 + n / 2)
        let d = min(10, 4 + n / 2)
        let bl = min(5, 1 + n / 4)
        var boss = 0
        if n % 3 == 1 { boss = ((n / 3) % 3) + 1 }
        return [w, d, bl, boss]
    }

    private func startWave(_ n: Int) {
        wave = n
        enemies = []
        balls = []
        queue = []
        queueVar = []
        let c = waveCounts(n)
        for _ in 0..<c[0] { queue.append(0) }
        for _ in 0..<c[1] { queue.append(1) }
        for _ in 0..<c[2] { queue.append(2) }
        // shuffle
        var i = queue.count - 1
        while i > 0 {
            let j = rng.int(i + 1)
            let t = queue[i]
            queue[i] = queue[j]
            queue[j] = t
            i -= 1
        }
        if c[3] > 0 {
            let at = min(queue.count, 2)
            queue.insert(3, at: at)
        }
        queueVar = []
        for k in queue {
            if k == 3 {
                queueVar.append(c[3] - 1)
            } else {
                queueVar.append(rng.int(2))
            }
        }
        let laneA: Float = TurretZone64.norm2Pi(yaw + Float(rng.int(100) - 50) / 100.0)
        let laneB: Float = TurretZone64.norm2Pi(laneA + 2.0 + Float(rng.int(200)) / 100.0)
        lanes = [laneA, laneB]
        spawnT = 90
        waveBanner = 130
        shield = shieldMax
        baseHP = min(baseMax, baseHP + 10)
        play(.countdown)
    }

    private func spawnEnemy(_ kind: Int, _ variant: Int) {
        var e = Enemy()
        e.kind = kind
        e.variant = variant
        let lane = lanes[rng.int(2)]
        e.az = TurretZone64.norm2Pi(lane + Float(rng.int(80) - 40) / 100.0)
        e.d = 42
        e.orbit = rng.chance(50) ? 1 : -1
        e.phase = Float(rng.int(60))
        let w: Float = Float(wave)
        switch kind {
        case 0:
            e.hp = 3
            e.speed = 0.06 + 0.002 * w
            e.stand = 14.3
        case 1:
            e.hp = 2
            e.speed = 0.08 + 0.002 * w
            e.stand = 8.5 + Float(rng.int(30)) / 10.0
        case 2:
            e.hp = 8
            e.speed = 0.04
            e.stand = 11.0
        default:
            var hpv: Float = 36
            if variant == 1 { hpv = 50 }
            if variant == 2 { hpv = 70 }
            if endless { hpv += Float(wave) * 2 }
            e.hp = hpv
            e.speed = 0.045
            e.stand = variant == 1 ? 10.5 : 12.5
        }
        e.maxHp = e.hp
        e.cd = 50 + rng.int(70)
        enemies.append(e)
    }

    // MARK: - Projection

    private func proj(_ az: Float, _ d: Float, _ h: Float, _ yawV: Float, _ hz: Float) -> (Float, Float, Float) {
        let daz: Float = TurretZone64.wrapAngle(az - yawV)
        let c: Float = cos(daz)
        if c < 0.2 { return (0, 0, -1) }
        let z: Float = d * c
        if z < 0.4 { return (0, 0, -1) }
        let sx: Float = 160.0 + TurretZone64.focal * sin(daz) / c
        let sy: Float = hz - TurretZone64.focal * h / z
        return (sx, sy, z)
    }

    static func enemyHeight(_ kind: Int, _ variant: Int) -> Float {
        switch kind {
        case 0: return 3.0
        case 1: return 1.9
        case 2: return 3.2
        default:
            if variant == 1 { return 5.6 }
            if variant == 2 { return 9.5 }
            return 8.0
        }
    }

    /// World height of the sprite's bottom edge.
    static func enemyBottom(_ e: Enemy) -> Float {
        switch e.kind {
        case 0: return -TurretZone64.groundDrop
        case 1: return 0.2 + 0.35 * sin(e.phase * 0.8)
        case 2: return 2.6 + 0.3 * sin(e.phase * 0.5)
        default:
            if e.variant == 1 { return 1.0 + 0.3 * sin(e.phase * 0.6) }
            return -TurretZone64.groundDrop
        }
    }

    static func enemySprite(_ e: Enemy) -> Int {
        let f = Int(e.phase * 0.9) & 1
        switch e.kind {
        case 0: return e.variant * 2 + f
        case 1: return TurretZone64.sprDrone + e.variant * 2 + f
        case 2: return TurretZone64.sprBlimp + (e.variant & 1)
        default: return TurretZone64.sprBoss + e.variant * 2 + f
        }
    }

    // MARK: - Effects

    private func addPop(_ az: Float, _ d: Float, _ h: Float, _ s: String, _ c: UInt32, _ big: Bool) {
        pops.append(Pop(az: az, d: d, h: h, t: 0, text: s, color: c, big: big))
        while pops.count > 12 { pops.removeFirst() }
    }

    private func spark(_ az: Float, _ d: Float, _ h: Float, _ count: Int, _ power: Float) {
        for _ in 0..<count {
            let vaz: Float = (Float(rng.int(200)) - 100.0) / 100.0 * 0.004 * power / max(4.0, d) * 10.0
            let vh: Float = (0.02 + Float(rng.int(60)) / 1000.0) * power
            let pick = rng.int(4)
            var col = TurretZone64.cYellow
            if pick == 1 { col = TurretZone64.cOrange }
            if pick == 2 { col = TurretZone64.cWhite }
            if pick == 3 { col = TurretZone64.rgb(190, 196, 214) }
            parts.append(Part(az: az, d: d, h: h, vaz: vaz, vh: vh, life: 22 + rng.int(18), col: col,
                              size: 0.16 + Float(rng.int(14)) / 100.0))
        }
        while parts.count > 110 { parts.removeFirst() }
    }

    // MARK: - Combat

    private func hitBase(_ dmg: Int) {
        if phase == .over { return }
        var left = dmg
        if shield > 0 {
            let s = min(shield, left)
            shield -= s
            left -= s
        }
        shake = max(shake, 10)
        dmgFlash = 14
        play(.hurt)
        if left > 0 {
            baseHP -= left
            combo = 0
            comboT = 0
        } else {
            play(.thud)
        }
        if baseHP <= 0 {
            baseHP = 0
            finishGame(false)
        }
    }

    private func awardKill(_ points: Int, _ charge: Float) {
        if comboT > 0 { combo = min(8, combo + 1) } else { combo = 1 }
        comboT = 150
        bestCombo = max(bestCombo, combo)
        scoreValue += points * combo
        let gain: Float = charge * (1.0 + 0.35 * Float(chargeLv))
        bomb = min(100, bomb + gain)
    }

    private func damageEnemy(_ i: Int, _ dmg: Float) {
        if i < 0 || i >= enemies.count { return }
        var e = enemies[i]
        if !e.alive { return }
        e.hp -= dmg
        e.flash = 4
        hits += 1
        hitMarker = 8
        let h: Float = TurretZone64.enemyBottom(e) + TurretZone64.enemyHeight(e.kind, e.variant) * 0.5
        spark(e.az, e.d, h, 3, 0.7)
        if e.hp <= 0 {
            e.alive = false
            enemies[i] = e
            killEnemy(e)
            return
        }
        play(.hit)
        enemies[i] = e
    }

    private func killEnemy(_ e: Enemy) {
        kills += 1
        var pts = 100
        var ch: Float = 6
        switch e.kind {
        case 1:
            pts = 150
            ch = 6
        case 2:
            pts = 300
            ch = 10
        case 3:
            pts = 2000
            ch = 25
        default:
            pts = 100
            ch = 6
        }
        awardKill(pts, ch)
        let hh: Float = TurretZone64.enemyHeight(e.kind, e.variant)
        let mid: Float = TurretZone64.enemyBottom(e) + hh * 0.5
        bursts.append(Burst(az: e.az, d: e.d, h: mid, t: 0, maxT: e.kind == 3 ? 40 : 22, size: hh * (e.kind == 3 ? 1.1 : 0.8)))
        spark(e.az, e.d, mid, e.kind == 3 ? 40 : 14, e.kind == 3 ? 2.0 : 1.2)
        addPop(e.az, e.d, mid + hh * 0.4, "+" + String(pts * max(1, combo)), TurretZone64.cYellow, true)
        if combo >= 2 {
            addPop(e.az, e.d, mid - hh * 0.2, "COMBO X" + String(combo), TurretZone64.cPink, false)
            play(.coin)
        }
        shake = max(shake, e.kind == 3 ? 22 : 5)
        if e.kind == 0 || e.kind == 1 {
            play(.stomp)
        } else {
            play(.explosion)
        }
    }

    private func damageBall(_ i: Int) {
        if i < 0 || i >= balls.count { return }
        var b = balls[i]
        if !b.alive { return }
        b.alive = false
        balls[i] = b
        hits += 1
        hitMarker = 8
        let pts = b.kind == 1 ? 75 : 25
        awardKill(pts, 3)
        bursts.append(Burst(az: b.az, d: b.d, h: b.h, t: 0, maxT: 14, size: 1.6))
        spark(b.az, b.d, b.h, 6, 0.8)
        addPop(b.az, b.d, b.h + 0.8, "+" + String(pts * max(1, combo)), TurretZone64.cOrange, false)
        play(.blip)
    }

    private func enemyFire(_ e: Enemy) {
        var offsets: [Float] = [0]
        if e.kind == 3 { offsets = [-0.06, 0, 0.06] }
        let hh: Float = TurretZone64.enemyHeight(e.kind, e.variant)
        let h0: Float = TurretZone64.enemyBottom(e) + hh * 0.4
        var speed: Float = min(0.12, 0.08 + 0.003 * Float(wave))
        var dmg = 5
        var kind = 0
        if e.kind == 1 { dmg = 6 }
        if e.kind == 2 {
            speed = 0.07
            dmg = 9
            kind = 1
        }
        if e.kind == 3 { dmg = 8 }
        let steps: Float = max(10.0, e.d / speed)
        let vh: Float = (-1.0 - h0) / steps
        for o in offsets {
            balls.append(Ball(az: e.az + o, d: e.d - 0.8, h: h0, vd: speed, vh: vh, kind: kind, dmg: dmg, alive: true))
        }
        play(.laser)
    }

    private func detonateBomb() {
        bomb = 0
        bombFlash = 22
        bombRing = 36
        shake = 24
        play(.explosion)
        play(.powerup)
        for i in 0..<enemies.count {
            var e = enemies[i]
            if !e.alive { continue }
            if e.kind == 3 {
                e.hp -= e.maxHp * 0.35
                e.flash = 8
                if e.hp <= 0 {
                    e.alive = false
                    enemies[i] = e
                    killEnemy(e)
                } else {
                    enemies[i] = e
                }
            } else {
                e.alive = false
                enemies[i] = e
                killEnemy(e)
            }
        }
        for i in 0..<balls.count {
            if balls[i].alive {
                var b = balls[i]
                b.alive = false
                balls[i] = b
                scoreValue += 25
                bursts.append(Burst(az: b.az, d: b.d, h: b.h, t: 0, maxT: 14, size: 1.4))
            }
        }
    }

    private func finishGame(_ won: Bool) {
        victory = won
        phase = .over
        overTimer = 0
        if won {
            scoreValue += baseHP * 10 + 1000
            play(.win)
        } else {
            play(.lose)
            bursts.append(Burst(az: yaw, d: 3, h: 0, t: 0, maxT: 40, size: 3))
        }
    }

    // MARK: - Update

    private func updateControls(_ input: InputState) {
        if input.dx != 0 { turnHold = min(40, turnHold + 1) } else { turnHold = 0 }
        let ts: Float = 0.020 + 0.030 * Float(min(turnHold, 24)) / 24.0
        yaw = TurretZone64.norm2Pi(yaw + Float(input.dx) * ts)
        pitch += -Float(input.dy) * 0.014
        pitch = clamp(pitch, -0.28, 0.28)
    }

    private func updateLock() {
        lockKind = 0
        lockIdx = -1
        var best: Float = 100000
        let hz: Float = Float(TurretZone64.eyeY) + pitch * 170.0
        for i in 0..<balls.count {
            let b = balls[i]
            if !b.alive { continue }
            let p = proj(b.az, b.d, b.h, yaw, hz)
            if p.2 < 0 { continue }
            let dx: Float = p.0 - 160.0
            let dy: Float = p.1 - Float(TurretZone64.eyeY)
            let dist: Float = sqrt(dx * dx + dy * dy)
            if dist > 80 { continue }
            let sc: Float = dist - 30.0
            if sc < best {
                best = sc
                lockKind = 2
                lockIdx = i
                lockSX = p.0
                lockSY = p.1
                lockR = clamp(TurretZone64.focal * 0.7 / p.2, 8, 60)
            }
        }
        for i in 0..<enemies.count {
            let e = enemies[i]
            if !e.alive { continue }
            let hh: Float = TurretZone64.enemyHeight(e.kind, e.variant)
            let center: Float = TurretZone64.enemyBottom(e) + hh * 0.5
            let p = proj(e.az, e.d, center, yaw, hz)
            if p.2 < 0 { continue }
            let rad: Float = clamp(TurretZone64.focal * hh * 0.5 / p.2, 6, 160)
            let dx: Float = p.0 - 160.0
            let dy: Float = p.1 - Float(TurretZone64.eyeY)
            let dist: Float = sqrt(dx * dx + dy * dy)
            if dist > 80 + rad * 0.8 { continue }
            var sc: Float = max(0, dist - rad * 0.7)
            if e.kind == 3 { sc -= 10 }
            if sc < best {
                best = sc
                lockKind = 1
                lockIdx = i
                lockSX = p.0
                lockSY = p.1
                lockR = rad
            }
        }
    }

    private func fireShot(_ input: InputState) {
        let dmg: Float = 1.0 + 0.25 * Float(dmgLv)
        gunSide = 1 - gunSide
        let x0 = gunSide == 0 ? 136 : 184
        var x1 = 160 + rng.int(40) - 20
        var y1 = 96 + rng.int(30)
        if lockKind > 0 {
            x1 = Int(clamp(lockSX, -200, 520))
            y1 = Int(clamp(lockSY, -100, 400))
            if lockKind == 1 {
                damageEnemy(lockIdx, dmg)
            } else {
                damageBall(lockIdx)
            }
        }
        tracers.append(Tracer(x0: x0, y0: 212, x1: x1, y1: y1, t: 0))
        while tracers.count > 6 { tracers.removeFirst() }
        fireCD = max(3, 8 - rateLv)
        recoil = 4
        muzzle = 3
        shots += 1
        play(.shoot)
    }

    private func updateEnemy(_ i: Int) {
        var e = enemies[i]
        if !e.alive { return }
        e.phase += 0.1
        if e.flash > 0 { e.flash -= 1 }
        switch e.state {
        case 0:
            e.d -= e.speed
            if e.kind == 1 { e.az = TurretZone64.norm2Pi(e.az + sin(e.phase * 0.7) * 0.0012) }
            if e.d <= e.stand {
                e.d = e.stand
                e.state = 1
                e.cd = 40 + rng.int(60)
            }
        case 1:
            var orb: Float = 0.0045
            if e.kind == 1 { orb = 0.003 }
            if e.kind == 2 { orb = 0.0015 }
            if e.kind == 3 { orb = 0.002 }
            e.az = TurretZone64.norm2Pi(e.az + e.orbit * orb)
            if e.cd > 0 {
                e.cd -= 1
            } else {
                e.state = 2
                e.timer = e.kind == 3 ? 40 : 30
            }
        default:
            e.timer -= 1
            if e.timer <= 0 {
                enemyFire(e)
                e.state = 1
                let w = wave
                var base = max(110, 210 - 8 * w)
                if e.kind == 1 { base = max(90, 180 - 8 * w) }
                if e.kind == 2 { base = 190 }
                if e.kind == 3 { base = 120 }
                e.cd = base + rng.int(50)
                if rng.chance(40) { e.orbit = -e.orbit }
            }
        }
        enemies[i] = e
    }

    private func updateBalls() {
        for i in 0..<balls.count {
            var b = balls[i]
            if !b.alive { continue }
            b.d -= b.vd
            b.h += b.vh
            if b.d <= 1.2 {
                b.alive = false
                balls[i] = b
                hitBase(b.dmg)
                bursts.append(Burst(az: b.az, d: 2.5, h: -1.0, t: 0, maxT: 16, size: 2.0))
                continue
            }
            balls[i] = b
        }
    }

    private func updateFx() {
        var keepP: [Part] = []
        for var p in parts {
            p.life -= 1
            if p.life <= 0 { continue }
            p.az += p.vaz
            p.h += p.vh
            p.vh -= 0.004
            if p.h < -TurretZone64.groundDrop {
                p.h = -TurretZone64.groundDrop
                p.vh = -p.vh * 0.4
            }
            keepP.append(p)
        }
        parts = keepP
        var keepB: [Burst] = []
        for var b in bursts {
            b.t += 1
            if b.t < b.maxT { keepB.append(b) }
        }
        bursts = keepB
        var keepO: [Pop] = []
        for var o in pops {
            o.t += 1
            if o.t < 56 { keepO.append(o) }
        }
        pops = keepO
        var keepT: [Tracer] = []
        for var t in tracers {
            t.t += 1
            if t.t < 5 { keepT.append(t) }
        }
        tracers = keepT
        if shake > 0 { shake -= 1 }
        if dmgFlash > 0 { dmgFlash -= 1 }
        if bombFlash > 0 { bombFlash -= 1 }
        if bombRing > 0 { bombRing -= 1 }
        if hitMarker > 0 { hitMarker -= 1 }
        if recoil > 0 { recoil -= 1 }
        if muzzle > 0 { muzzle -= 1 }
        if fireCD > 0 { fireCD -= 1 }
        if hintT > 0 { hintT -= 1 }
        if comboT > 0 {
            comboT -= 1
            if comboT == 0 { combo = 0 }
        }
    }

    private func updateCombat(_ input: InputState, _ spawning: Bool) {
        updateControls(input)
        enemies = enemies.filter { $0.alive }
        balls = balls.filter { $0.alive }
        if spawning && waveBanner < 70 && !queue.isEmpty {
            spawnT -= 1
            if spawnT <= 0 {
                let k = queue.removeFirst()
                let v = queueVar.isEmpty ? 0 : queueVar.removeFirst()
                spawnEnemy(k, v)
                spawnT = max(30, 82 - 4 * wave) + rng.int(20)
                if k == 3 {
                    spawnT = 150
                    play(.powerup)
                }
            }
        }
        for i in 0..<enemies.count { updateEnemy(i) }
        updateBalls()
        updateLock()
        let firing = input.a && phase == .playing
        if firing && lockKind > 0 {
            let ta: Float = lockKind == 1 ? enemies[lockIdx].az : balls[lockIdx].az
            let diff: Float = TurretZone64.wrapAngle(ta - yaw)
            let maxS: Float = input.dx != 0 ? 0.006 : 0.016
            yaw = TurretZone64.norm2Pi(yaw + clamp(diff * 0.3, -maxS, maxS))
            if input.dy == 0 {
                let dyp: Float = (Float(TurretZone64.eyeY) - lockSY) / 170.0
                pitch = clamp(pitch + clamp(dyp * 0.2, -0.006, 0.006), -0.28, 0.28)
            }
        }
        if firing && fireCD <= 0 {
            fireShot(input)
        }
        if input.bPressed && phase == .playing {
            if bomb >= 100 {
                detonateBomb()
            } else {
                play(.blip)
                addPop(yaw, 6, 1.2, "BOMB " + String(Int(bomb)) + "%", TurretZone64.cCyan, false)
            }
        }
    }

    private func makeCards() {
        var pool: [Int] = [0, 1, 2, 3, 4]
        var i = pool.count - 1
        while i > 0 {
            let j = rng.int(i + 1)
            let t = pool[i]
            pool[i] = pool[j]
            pool[j] = t
            i -= 1
        }
        cards = [pool[0], pool[1], pool[2]]
        if baseHP * 2 < baseMax && !cards.contains(4) {
            cards[2] = 4
        }
        cardSel = 1
        upgradeT = 25
    }

    private func applyUpgrade(_ k: Int) {
        switch k {
        case 0:
            dmgLv += 1
        case 1:
            rateLv = min(4, rateLv + 1)
        case 2:
            shieldMax += 30
            shield = shieldMax
        case 3:
            chargeLv += 1
            bomb = min(100, bomb + 40)
        default:
            baseMax += 15
            baseHP = min(baseMax, baseHP + 45)
        }
    }

    override func update(_ input: InputState) {
        frame += 1
        updateFx()
        if input.selectPressed { showRadar = !showRadar }
        switch phase {
        case .title:
            yaw = TurretZone64.norm2Pi(yaw + 0.004)
            if input.aPressed || input.startPressed {
                play(.confirm)
                beginGame()
            }
        case .playing:
            if waveBanner > 0 { waveBanner -= 1 }
            updateCombat(input, true)
            if phase == .playing && queue.isEmpty && waveBanner == 0 {
                var alive = 0
                for e in enemies where e.alive { alive += 1 }
                if alive == 0 {
                    let bonus = 150 * wave + baseHP * 2
                    scoreValue += bonus
                    bonusText = bonus
                    phase = .clear
                    clearT = 110
                    play(.win)
                }
            }
        case .clear:
            clearT -= 1
            updateCombat(input, false)
            if clearT <= 0 && phase == .clear {
                if wave >= TurretZone64.maxWave && !endless {
                    finishGame(true)
                } else {
                    balls = []
                    makeCards()
                    phase = .upgrade
                }
            }
        case .upgrade:
            if upgradeT > 0 { upgradeT -= 1 }
            if input.leftPressed {
                cardSel = (cardSel + 2) % 3
                play(.select)
            }
            if input.rightPressed {
                cardSel = (cardSel + 1) % 3
                play(.select)
            }
            if (input.aPressed || input.startPressed) && upgradeT <= 0 {
                applyUpgrade(cards[cardSel])
                play(.powerup)
                phase = .playing
                startWave(wave + 1)
            }
        case .over:
            overTimer += 1
            if overTimer > 45 {
                if input.startPressed {
                    play(.confirm)
                    beginGame()
                } else if input.aPressed {
                    play(.confirm)
                    if victory && !endless {
                        endless = true
                        victory = false
                        baseHP = min(baseMax, baseHP + 50)
                        enemies = []
                        balls = []
                        makeCards()
                        phase = .upgrade
                    } else {
                        beginGame()
                    }
                }
            }
        }
    }

    // MARK: - Rendering (pixel pass)

    private func drawSky(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ hz: Int, _ pal: [Int]) {
        let top0 = pal[0]
        let top1 = pal[1]
        let top2 = pal[2]
        let hor0 = pal[3]
        let hor1 = pal[4]
        let hor2 = pal[5]
        let den = max(1, hz)
        for y in 0..<hz {
            let t = (y * 256) / den
            let r = top0 + (((hor0 - top0) * t) >> 8)
            let g = top1 + (((hor1 - top1) * t) >> 8)
            let b = top2 + (((hor2 - top2) * t) >> 8)
            let c = TurretZone64.rgb(r, g, b)
            let base = y * w
            for x in 0..<w { p[base + x] = c }
        }
    }

    private func drawSun(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ yawV: Float, _ hz: Int, _ pal: Int) {
        let daz: Float = TurretZone64.wrapAngle(1.1 - yawV)
        if abs(daz) > 1.0 { return }
        let sx = 160 + Int(TurretZone64.focal * tan(daz))
        let sy = hz - 78
        let rad = pal == 0 ? 17 : 24
        var core = TurretZone64.rgb(255, 250, 190)
        var halo = TurretZone64.rgb(255, 240, 150)
        if pal == 1 {
            core = TurretZone64.rgb(255, 230, 150)
            halo = TurretZone64.rgb(255, 190, 120)
        }
        if pal == 2 {
            core = TurretZone64.rgb(255, 200, 200)
            halo = TurretZone64.rgb(255, 150, 190)
        }
        let r2 = rad * rad
        let h2 = (rad + 8) * (rad + 8)
        let y0 = max(0, sy - rad - 8)
        let y1 = min(min(h, hz), sy + rad + 9)
        let x0 = max(0, sx - rad - 8)
        let x1 = min(w, sx + rad + 9)
        if y0 >= y1 || x0 >= x1 { return }
        for y in y0..<y1 {
            for x in x0..<x1 {
                let dx = x - sx
                let dy = y - sy
                let d2 = dx * dx + dy * dy
                if d2 <= r2 {
                    p[y * w + x] = core
                } else if d2 <= h2 {
                    p[y * w + x] = TurretZone64.tintTo(p[y * w + x], 120, 255, 245, 190)
                    if d2 < h2 / 2 { p[y * w + x] = halo }
                }
            }
        }
    }

    private func drawLayer(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ layer: Layer, _ yTop: Int, _ yLimit: Int,
                           _ yawV: Float, _ extend: Bool, _ tintAmt: Int, _ tr: Int, _ tg: Int, _ tb: Int) {
        let colAng = TurretZone64.colAng
        let lw = layer.w
        let lh = layer.h
        let scale: Float = Float(lw) / TurretZone64.twoPi
        layer.px.withUnsafeBufferPointer { src in
            for x in 0..<320 {
                let az: Float = yawV + colAng[x]
                var tx = Int(az * scale)
                tx = ((tx % lw) + lw) % lw
                let colBase = tx * lh
                var y0 = yTop
                var y1 = yTop + lh
                if extend { y1 = yLimit }
                if y1 > yLimit { y1 = yLimit }
                if y0 < 0 { y0 = 0 }
                if y0 >= y1 { continue }
                for y in y0..<y1 {
                    var ty = y - yTop
                    if ty >= lh { ty = lh - 1 }
                    if ty < 0 { continue }
                    let c = src[colBase + ty]
                    if c == 0 { continue }
                    if tintAmt > 0 {
                        p[y * w + x] = TurretZone64.tintTo(c, tintAmt, tr, tg, tb)
                    } else {
                        p[y * w + x] = c
                    }
                }
            }
        }
    }

    private func drawGround(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ yawV: Float, _ hz: Int, _ pal: [Int]) {
        let ic = TurretZone64.invCos
        let colAng = TurretZone64.colAng
        let hr = pal[3]
        let hg = pal[4]
        let hb = pal[5]
        let tr = pal[6]
        let tg = pal[7]
        let tb = pal[8]
        let ta = pal[9]
        let hazeC = TurretZone64.rgb(hr, hg, hb)
        let startY = max(0, hz)
        if startY >= h { return }
        for y in startY..<h {
            let dy: Float = Float(y - hz) + 0.5
            let zr: Float = TurretZone64.focal * TurretZone64.groundDrop / dy
            let base = y * w
            if zr > 60 {
                for x in 0..<w { p[base + x] = hazeC }
                continue
            }
            for x in 0..<w {
                let d: Float = zr * ic[x]
                if d >= 40 {
                    p[base + x] = hazeC
                    continue
                }
                let az: Float = yawV + colAng[x] + 8.0
                var r = 255
                var g = 255
                var b = 255
                if d < 6.0 {
                    let k = (Int(az * d * 0.7) + Int(d * 0.9)) & 1
                    if k == 0 {
                        r = 255; g = 238; b = 206
                    } else {
                        r = 255; g = 196; b = 220
                    }
                } else if d < 12.9 {
                    let k = (Int(az * d * 0.55) + Int(d * 0.7)) & 1
                    if k == 0 {
                        r = 170; g = 232; b = 226
                    } else {
                        r = 140; g = 210; b = 240
                    }
                } else if d < 16.1 {
                    r = 84; g = 90; b = 128
                    if d > 14.0 && d < 14.6 {
                        if (Int(az * d * 1.6) & 3) < 2 {
                            r = 255; g = 220; b = 70
                        }
                    }
                } else if d < 26.0 {
                    let k = (Int(az * d * 0.4) + Int(d * 0.5)) & 1
                    if d < 16.9 {
                        r = 250; g = 250; b = 250
                    } else if k == 0 {
                        r = 112; g = 222; b = 120
                    } else {
                        r = 92; g = 200; b = 108
                    }
                } else {
                    let k = (Int(az * d * 0.35) + Int(d * 0.4)) & 3
                    if k == 0 {
                        r = 255; g = 170; b = 190
                    } else if k == 1 {
                        r = 255; g = 224; b = 120
                    } else if k == 2 {
                        r = 150; g = 200; b = 255
                    } else {
                        r = 196; g = 156; b = 255
                    }
                }
                if ta > 0 {
                    r += ((tr - r) * ta) >> 9
                    g += ((tg - g) * ta) >> 9
                    b += ((tb - b) * ta) >> 9
                }
                var fa = Int((d - 9.0) * 6.0)
                if fa < 0 { fa = 0 }
                if fa > 215 { fa = 215 }
                r += ((hr - r) * fa) >> 8
                g += ((hg - g) * fa) >> 8
                b += ((hb - b) * fa) >> 8
                p[base + x] = 0xFF00_0000 | UInt32(r & 255) | (UInt32(g & 255) << 8) | (UInt32(b & 255) << 16)
            }
        }
    }

    private func blit(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ it: Bill, _ hazeR: Int, _ hazeG: Int, _ hazeB: Int) {
        let sprs = TurretZone64.sprites
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
        let white = it.white
        let orange = it.orange
        let fog = it.fog
        spr.pix.withUnsafeBufferPointer { sp in
            for x in xs..<xe {
                let sxp = max(0, min(sprW - 1, ((x - x0) * stepX) >> 16))
                for y in ys..<ye {
                    let syp = max(0, min(sprH - 1, ((y - y0) * stepY) >> 16))
                    let c = sp[syp * sprW + sxp]
                    if c == 0 { continue }
                    var o = c
                    if fog > 0 { o = TurretZone64.tintTo(o, fog, hazeR, hazeG, hazeB) }
                    if white > 0 {
                        if orange {
                            o = TurretZone64.tintTo(o, white, 255, 140, 30)
                        } else {
                            o = TurretZone64.tintTo(o, white, 255, 255, 255)
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
            p[i] = TurretZone64.tintTo(p[i], amt, tr, tg, tb)
        }
    }

    private func addBill(_ sx: Float, _ bottom: Float, _ z: Float, _ spr: Int, _ worldH: Float, _ white: Int,
                         _ orange: Bool, _ hpFrac: Float, _ boss: Bool) {
        if !(sx > -1500 && sx < 1800) { return }
        let shf: Float = TurretZone64.focal * worldH / z
        if !(shf < 1000 && shf >= 1) { return }
        let sprs = TurretZone64.sprites
        if spr < 0 || spr >= sprs.count { return }
        let aspect: Float = Float(sprs[spr].w) / Float(sprs[spr].h)
        let swf: Float = shf * aspect
        if !(swf < 1500) { return }
        let sh = Int(shf)
        let sw = Int(swf)
        if sw < 1 || sh < 1 { return }
        let sxi = Int(sx)
        if sxi + sw / 2 < 0 || sxi - sw / 2 > 320 { return }
        if !(bottom > -1500 && bottom < 1500) { return }
        var fog = Int((z - 16.0) * 5.0)
        if fog < 0 { fog = 0 }
        if fog > 140 { fog = 140 }
        bills.append(Bill(depth: z, sx: sxi, bottom: Int(bottom), sw: sw, sh: sh, spr: spr, white: white,
                          orange: orange, fog: fog, hpFrac: hpFrac, boss: boss))
    }

    private func buildBills(_ yawV: Float, _ hz: Float) {
        bills.removeAll(keepingCapacity: true)
        for e in enemies {
            if !e.alive { continue }
            let hh: Float = TurretZone64.enemyHeight(e.kind, e.variant)
            let bot: Float = TurretZone64.enemyBottom(e)
            let p = proj(e.az, e.d, bot, yawV, hz)
            if p.2 < 0 { continue }
            var white = 0
            var orange = false
            if e.flash > 0 {
                white = 200
            } else if e.state == 2 {
                orange = true
                white = ((e.timer / 3) & 1) == 0 ? 190 : 80
            }
            let wob: Float = 1.0 + 0.04 * sin(e.phase * 2.1)
            var frac: Float = -1
            if e.kind >= 2 || e.hp < e.maxHp { frac = e.hp / e.maxHp }
            addBill(p.0, p.1, p.2, TurretZone64.enemySprite(e), hh * wob, white, orange, frac, e.kind == 3)
        }
        for b in balls {
            if !b.alive { continue }
            let s: Float = b.kind == 1 ? 1.3 : 1.0
            let p = proj(b.az, b.d, b.h - s * 0.5, yawV, hz)
            if p.2 < 0 { continue }
            addBill(p.0, p.1, p.2, b.kind == 1 ? TurretZone64.sprBomb : TurretZone64.sprBall, s, 0, false, -1, false)
        }
        bills.sort { $0.depth > $1.depth }
    }

    // MARK: - Draw

    override func drawTrueColor(_ b: TrueColorBuffer) {
        var shx: Float = 0
        var shy = 0
        if shake > 0 && phase != .title {
            shx = sin(Float(frame) * 1.7) * 0.0035 * Float(shake)
            shy = Int(cos(Float(frame) * 2.3) * 0.5 * Float(shake))
        }
        let yawV: Float = yaw + shx
        var hzI = TurretZone64.eyeY + Int(pitch * 170.0) + shy
        hzI = max(50, min(210, hzI))
        let hzF: Float = Float(hzI)
        let palIdx = max(0, min(2, (max(1, wave) - 1) / 4))
        let pal = TurretZone64.skyPal[palIdx]
        buildBills(yawV, hzF)
        let list = bills
        let flashBomb = bombFlash > 0 ? bombFlash * 9 : 0
        let flashHit = dmgFlash > 0 ? min(120, dmgFlash * 8) : 0
        let drift = Float(frame) * 0.0004
        b.withPixels { p, w, h in
            if w < 320 || h < 288 { return }
            self.drawSky(p, w, hzI, pal)
            self.drawSun(p, w, h, yawV, hzI, palIdx)
            let ta = pal[9]
            let cloudTop = (hzI - 128) * 6 / 10 + 14
            self.drawLayer(p, w, TurretZone64.layerClouds, cloudTop, hzI, yawV * 0.5 + drift, false, ta / 2, pal[6], pal[7], pal[8])
            self.drawLayer(p, w, TurretZone64.layerFar, hzI - 70 + 4, hzI, yawV, true, ta, pal[6], pal[7], pal[8])
            self.drawLayer(p, w, TurretZone64.layerNear, hzI - 80, hzI, yawV, false, ta, pal[6], pal[7], pal[8])
            self.drawGround(p, w, h, yawV, hzI, pal)
            for it in list { self.blit(p, w, h, it, pal[3], pal[4], pal[5]) }
            if flashBomb > 0 { self.tint(p, w, h, 255, 255, 255, min(230, flashBomb)) }
            if flashHit > 0 { self.tint(p, w, h, 255, 40, 50, flashHit) }
        }
        if phase != .title {
            drawBursts(b, yawV, hzF)
            drawParts(b, yawV, hzF)
            drawBarMarks(b, list)
            drawTracers(b)
            drawPops(b, yawV, hzF)
            drawLock(b)
            drawTurret(b)
            drawArrows(b)
            drawHUD(b)
        }
        drawOverlays(b)
    }

    // MARK: - HUD helpers

    private func otext(_ b: TrueColorBuffer, _ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        let k = max(1, scale / 2)
        let o = TurretZone64.cBlack
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
        b.fillRect(x - 2, y - 2, w + 4, h + 4, TurretZone64.cBlack)
        b.fillRect(x, y, w, h, TurretZone64.cBarBack)
        let fw = Int(clamp(frac, 0, 1) * Float(w))
        if fw > 0 {
            b.fillRect(x, y, fw, h, c)
            b.fillRect(x, y, fw, 2, TurretZone64.cWhite)
        }
    }

    private func fillDisc(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int, _ r: Int, _ c: UInt32) {
        if r < 1 || r > 400 { return }
        for dy in -r...r {
            let fy: Float = Float(dy)
            let half = Int(sqrt(max(0, Float(r * r) - fy * fy)))
            b.fillRect(cx - half, cy + dy, half * 2 + 1, 1, c)
        }
    }

    private func thickLine(_ b: TrueColorBuffer, _ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ th: Int, _ c: UInt32) {
        let dx = x1 - x0
        let dy = y1 - y0
        let n = max(abs(dx), abs(dy))
        if n == 0 {
            b.fillRect(x0 - th / 2, y0 - th / 2, th, th, c)
            return
        }
        let step = max(1, th / 2)
        var i = 0
        while i <= n {
            let x = x0 + dx * i / n
            let y = y0 + dy * i / n
            b.fillRect(x - th / 2, y - th / 2, th, th, c)
            i += step
        }
        b.fillRect(x1 - th / 2, y1 - th / 2, th, th, c)
    }

    private func drawBursts(_ b: TrueColorBuffer, _ yawV: Float, _ hz: Float) {
        for u in bursts {
            let p = proj(u.az, u.d, u.h, yawV, hz)
            if p.2 < 0 { continue }
            let t: Float = Float(u.t) / Float(max(1, u.maxT))
            let rf: Float = TurretZone64.focal * u.size * (0.3 + 0.9 * t) / p.2
            let r = Int(clamp(rf, 2, 120))
            let cx = Int(clamp(p.0, -300, 620))
            let cy = Int(clamp(p.1, -300, 600))
            if t < 0.35 {
                fillDisc(b, cx, cy, r, TurretZone64.cWhite)
                fillDisc(b, cx, cy, r * 2 / 3, TurretZone64.cYellow)
            } else if t < 0.7 {
                fillDisc(b, cx, cy, r, TurretZone64.cOrange)
                fillDisc(b, cx, cy, r * 2 / 3, TurretZone64.cYellow)
            } else {
                fillDisc(b, cx, cy, r, TurretZone64.rgb(255, 120, 80))
                fillDisc(b, cx, cy, r * 3 / 5, TurretZone64.cOrange)
            }
        }
    }

    private func drawParts(_ b: TrueColorBuffer, _ yawV: Float, _ hz: Float) {
        for q in parts {
            let p = proj(q.az, q.d, q.h, yawV, hz)
            if p.2 < 0 { continue }
            let s = Int(clamp(TurretZone64.focal * q.size / p.2, 2, 8))
            let x = Int(clamp(p.0, -50, 400))
            let y = Int(clamp(p.1, -50, 400))
            b.fillRect(x - s / 2, y - s / 2, s, s, q.col)
        }
    }

    private func drawBarMarks(_ b: TrueColorBuffer, _ list: [Bill]) {
        for it in list {
            if it.hpFrac < 0 { continue }
            let w = max(16, min(90, it.sw))
            let x = it.sx - w / 2
            let y = it.bottom - it.sh - 8
            if y < 40 && !it.boss { continue }
            let col: UInt32 = it.hpFrac > 0.5 ? TurretZone64.cGreen : (it.hpFrac > 0.25 ? TurretZone64.cYellow : TurretZone64.cRed)
            b.fillRect(x - 1, y - 1, w + 2, 6, TurretZone64.cBlack)
            b.fillRect(x, y, w, 4, TurretZone64.cBarBack)
            let fw = Int(clamp(it.hpFrac, 0, 1) * Float(w))
            if fw > 0 { b.fillRect(x, y, fw, 4, col) }
        }
    }

    private func drawTracers(_ b: TrueColorBuffer) {
        for t in tracers {
            let life = 5 - t.t
            if life <= 0 { continue }
            let c1 = TurretZone64.rgb(70, 170, 255)
            thickLine(b, t.x0, t.y0, t.x1, t.y1, life > 3 ? 5 : 3, c1)
            thickLine(b, t.x0, t.y0, t.x1, t.y1, life > 3 ? 2 : 1, TurretZone64.cWhite)
            if t.t < 2 && t.x1 > -40 && t.x1 < 360 {
                fillDisc(b, t.x1, t.y1, 7, TurretZone64.cCyan)
                fillDisc(b, t.x1, t.y1, 3, TurretZone64.cWhite)
            }
        }
    }

    private func drawPops(_ b: TrueColorBuffer, _ yawV: Float, _ hz: Float) {
        for o in pops {
            let rise: Float = Float(o.t) * 0.03
            let p = proj(o.az, o.d, o.h + rise, yawV, hz)
            if p.2 < 0 { continue }
            let sc = o.big ? 2 : 1
            let tw = b.textWidth(o.text, scale: sc)
            let sx = Int(clamp(p.0, -300, 600)) - tw / 2
            let sy = Int(clamp(p.1, -100, 400))
            var c = o.color
            if o.t > 40 && (o.t & 1) == 0 { c = TurretZone64.cWhite }
            otext(b, o.text, sx, sy, c, sc)
        }
    }

    private func drawLock(_ b: TrueColorBuffer) {
        if lockKind > 0 && phase != .over {
            let r = Int(clamp(lockR, 10, 90))
            let cx = Int(clamp(lockSX, -100, 420))
            let cy = Int(clamp(lockSY, -100, 400))
            let c: UInt32 = lockKind == 2 ? TurretZone64.cOrange : TurretZone64.cRed
            let l = 8
            b.fillRect(cx - r, cy - r, l, 2, c)
            b.fillRect(cx - r, cy - r, 2, l, c)
            b.fillRect(cx + r - l, cy - r, l, 2, c)
            b.fillRect(cx + r - 2, cy - r, 2, l, c)
            b.fillRect(cx - r, cy + r - 2, l, 2, c)
            b.fillRect(cx - r, cy + r - l, 2, l, c)
            b.fillRect(cx + r - l, cy + r - 2, l, 2, c)
            b.fillRect(cx + r - 2, cy + r - l, 2, l, c)
        }
        // reticle
        let rc: UInt32 = lockKind > 0 ? TurretZone64.cRed : TurretZone64.cWhite
        let ey = TurretZone64.eyeY
        b.fillRect(150, ey - 1, 7, 3, TurretZone64.cBlack)
        b.fillRect(164, ey - 1, 7, 3, TurretZone64.cBlack)
        b.fillRect(159, ey - 10, 3, 7, TurretZone64.cBlack)
        b.fillRect(159, ey + 4, 3, 7, TurretZone64.cBlack)
        b.fillRect(151, ey, 5, 1, rc)
        b.fillRect(165, ey, 5, 1, rc)
        b.fillRect(160, ey - 9, 1, 5, rc)
        b.fillRect(160, ey + 5, 1, 5, rc)
        b.fillRect(160, ey, 1, 1, rc)
        if hitMarker > 0 {
            b.fillRect(146, ey - 14, 5, 2, TurretZone64.cYellow)
            b.fillRect(170, ey - 14, 5, 2, TurretZone64.cYellow)
            b.fillRect(146, ey + 13, 5, 2, TurretZone64.cYellow)
            b.fillRect(170, ey + 13, 5, 2, TurretZone64.cYellow)
        }
        if bombRing > 0 {
            let r = (36 - bombRing) * 9
            let c2 = TurretZone64.rgb(255, 255, 255)
            let n = 48
            for k in 0..<n {
                let a: Float = Float(k) * TurretZone64.twoPi / Float(n)
                let x = 160 + Int(cos(a) * Float(r))
                let y = ey + Int(sin(a) * Float(r) * 0.8)
                b.fillRect(x - 3, y - 3, 6, 6, c2)
            }
        }
    }

    private func drawTurret(_ b: TrueColorBuffer) {
        let rec = recoil
        let ink = TurretZone64.cBlack
        let body = TurretZone64.rgb(120, 200, 255)
        let hi = TurretZone64.rgb(225, 246, 255)
        let ready = bomb >= 100
        // left and right barrels converge toward the reticle
        let lx0 = 84
        let rx0 = 236
        let y0 = 268
        let lx1 = 134 - rec
        let rx1 = 186 + rec
        let y1 = 210 + rec * 2
        thickLine(b, lx0, y0, lx1, y1, 16, ink)
        thickLine(b, rx0, y0, rx1, y1, 16, ink)
        thickLine(b, lx0, y0, lx1, y1, 11, body)
        thickLine(b, rx0, y0, rx1, y1, 11, body)
        thickLine(b, lx0 + 2, y0, lx1 + 1, y1, 3, hi)
        thickLine(b, rx0 - 2, y0, rx1 - 1, y1, 3, hi)
        b.fillRect(lx1 - 7, y1 - 9, 14, 8, ink)
        b.fillRect(rx1 - 7, y1 - 9, 14, 8, ink)
        let tip: UInt32 = ready ? TurretZone64.cYellow : TurretZone64.cCyan
        b.fillRect(lx1 - 4, y1 - 7, 8, 5, tip)
        b.fillRect(rx1 - 4, y1 - 7, 8, 5, tip)
        if muzzle > 0 {
            let mx = gunSide == 0 ? lx1 : rx1
            fillDisc(b, mx, y1 - 12, 9, TurretZone64.cWhite)
            fillDisc(b, mx, y1 - 12, 5, TurretZone64.cCyan)
        }
    }

    private func drawArrows(_ b: TrueColorBuffer) {
        var count = 0
        for e in enemies {
            if !e.alive || count > 9 { continue }
            let daz: Float = TurretZone64.wrapAngle(e.az - yaw)
            if abs(daz) < 0.66 { continue }
            count += 1
            var y = 70 + Int(e.d * 3.5)
            y = max(60, min(220, y))
            let near = e.d < 20
            var c: UInt32 = near ? TurretZone64.cRed : TurretZone64.cYellow
            if e.kind == 3 { c = TurretZone64.cOrange }
            if near && ((frame / 6) & 1) == 0 { c = TurretZone64.cWhite }
            let right = daz > 0
            for k in 0..<8 {
                let hh = (7 - k)
                if right {
                    b.fillRect(309 + k - 1, y - hh - 1, 1, hh * 2 + 3, TurretZone64.cBlack)
                    b.fillRect(309 + k, y - hh, 1, hh * 2 + 1, c)
                } else {
                    b.fillRect(10 - k + 1, y - hh - 1, 1, hh * 2 + 3, TurretZone64.cBlack)
                    b.fillRect(10 - k, y - hh, 1, hh * 2 + 1, c)
                }
            }
        }
        for bl in balls {
            if !bl.alive { continue }
            let daz: Float = TurretZone64.wrapAngle(bl.az - yaw)
            if abs(daz) < 0.66 { continue }
            let right = daz > 0
            let y = max(60, min(230, 100 + Int(bl.d * 4.0)))
            let c = ((frame / 4) & 1) == 0 ? TurretZone64.cOrange : TurretZone64.cWhite
            b.fillRect(right ? 304 : 6, y - 5, 10, 10, TurretZone64.cBlack)
            b.fillRect(right ? 306 : 8, y - 3, 6, 6, c)
        }
    }

    private func drawRadar(_ b: TrueColorBuffer) {
        let cx = 288
        let cy = 34
        b.fillRect(cx - 27, cy - 27, 54, 54, TurretZone64.cBlack)
        b.fillRect(cx - 25, cy - 25, 50, 50, TurretZone64.rgb(40, 56, 120))
        b.fillRect(cx - 25, cy, 50, 1, TurretZone64.rgb(70, 90, 160))
        b.fillRect(cx, cy - 25, 1, 50, TurretZone64.rgb(70, 90, 160))
        // view cone edges
        for k in 3..<12 {
            let r: Float = Float(k) * 2.0
            let a: Float = 0.68
            b.fillRect(cx + Int(sin(a) * r), cy - Int(cos(a) * r), 1, 1, TurretZone64.cYellow)
            b.fillRect(cx - Int(sin(a) * r), cy - Int(cos(a) * r), 1, 1, TurretZone64.cYellow)
        }
        b.fillRect(cx - 1, cy - 1, 3, 3, TurretZone64.cWhite)
        for e in enemies {
            if !e.alive { continue }
            let rel: Float = e.az - yaw
            let r: Float = min(24.0, e.d / 42.0 * 24.0)
            let x = cx + Int(sin(rel) * r)
            let y = cy - Int(cos(rel) * r)
            let s = e.kind == 3 ? 5 : 3
            b.fillRect(x - s / 2, y - s / 2, s, s, e.kind == 3 ? TurretZone64.cOrange : TurretZone64.cRed)
        }
        for bl in balls {
            if !bl.alive { continue }
            let rel: Float = bl.az - yaw
            let r: Float = min(24.0, bl.d / 42.0 * 24.0)
            let x = cx + Int(sin(rel) * r)
            let y = cy - Int(cos(rel) * r)
            b.fillRect(x, y, 2, 2, TurretZone64.cYellow)
        }
    }

    private func drawHUD(_ b: TrueColorBuffer) {
        // base health
        let hpFrac: Float = Float(baseHP) / Float(max(1, baseMax))
        b.text("BASE", 6, 5, TurretZone64.cWhite, scale: 2)
        otext(b, "BASE", 6, 5, TurretZone64.cWhite, 2)
        var hc = TurretZone64.cGreen
        if hpFrac < 0.5 { hc = TurretZone64.cYellow }
        if hpFrac < 0.25 { hc = ((frame / 6) & 1) == 0 ? TurretZone64.cRed : TurretZone64.rgb(150, 40, 60) }
        bar(b, 42, 7, 90, 8, hpFrac, hc)
        if shieldMax > 0 {
            otext(b, "SHLD", 6, 19, TurretZone64.cCyan, 2)
            bar(b, 42, 21, 90, 6, Float(shield) / Float(max(1, shieldMax)), TurretZone64.rgb(120, 180, 255))
        }
        otext(b, zeroPad(scoreValue, 6), 6, 34, TurretZone64.cWhite, 2)
        let wt: String = endless ? "ENDLESS " + String(wave) : "WAVE " + String(max(1, wave)) + "/" + String(TurretZone64.maxWave)
        ctext(b, wt, 5, TurretZone64.cYellow, 2)
        if combo >= 2 {
            ctext(b, "COMBO X" + String(combo), 22, TurretZone64.cPink, 2)
            bar(b, 130, 38, 60, 4, Float(comboT) / 150.0, TurretZone64.cPink)
        }
        for e in enemies where e.alive && e.kind == 3 {
            ctext(b, "BOSS", 50, TurretZone64.cOrange, 1)
            bar(b, 90, 60, 140, 7, e.hp / e.maxHp, TurretZone64.cOrange)
        }
        if showRadar { drawRadar(b) }
        if hintT > 0 && waveBanner < 40 && phase == .playing {
            let idx = ((900 - hintT) / 200) % 4
            var s = "LEFT RIGHT TURN - FIND THE ROBOTS"
            if idx == 1 { s = "HOLD A - AUTO-LOCK SHOOTS FOR YOU" }
            if idx == 2 { s = "SHOOT ORANGE BALLS BEFORE THEY LAND" }
            if idx == 3 { s = "B = BOMB WHEN THE METER IS FULL" }
            ctext(b, s, 232, TurretZone64.cWhite, 1)
        }
        // bottom panel
        b.fillRect(0, 252, 320, 36, TurretZone64.cPanel)
        b.fillRect(0, 252, 320, 2, TurretZone64.cCyan)
        let ready = bomb >= 100
        let blink = ready && ((frame / 6) & 1) == 0
        b.text(ready ? "B BOMB!" : "BOMB", 6, 259, blink ? TurretZone64.cYellow : TurretZone64.cWhite, scale: 2)
        bar(b, 6, 274, 120, 8, bomb / 100.0, ready ? TurretZone64.cYellow : TurretZone64.cCyan)
        b.text("KO " + String(kills), 140, 259, TurretZone64.cWhite, scale: 2)
        b.text("D" + String(dmgLv + 1) + " R" + String(rateLv + 1) + " C" + String(chargeLv + 1), 140, 276,
               TurretZone64.rgb(190, 176, 240), scale: 1)
        b.text("SEL=RADAR", 250, 276, TurretZone64.rgb(170, 150, 230), scale: 1)
        let dirTxt = lockKind > 0 ? "LOCK" : "SEEK"
        b.text(dirTxt, 250, 259, lockKind > 0 ? TurretZone64.cRed : TurretZone64.cWhite, scale: 2)
    }

    private func drawIcon(_ b: TrueColorBuffer, _ kind: Int, _ cx: Int, _ cy: Int) {
        let ink = TurretZone64.cBlack
        switch kind {
        case 0:
            fillDisc(b, cx, cy, 15, ink)
            fillDisc(b, cx, cy, 12, TurretZone64.cRed)
            fillDisc(b, cx, cy, 6, TurretZone64.cYellow)
            fillDisc(b, cx, cy, 2, TurretZone64.cWhite)
        case 1:
            b.fillRect(cx - 14, cy - 14, 28, 28, ink)
            b.fillRect(cx - 11, cy - 11, 22, 22, TurretZone64.cGreen)
            b.fillRect(cx - 2, cy - 10, 8, 8, TurretZone64.cYellow)
            b.fillRect(cx - 8, cy - 3, 12, 6, TurretZone64.cYellow)
            b.fillRect(cx - 4, cy + 2, 8, 8, TurretZone64.cYellow)
        case 2:
            fillDisc(b, cx, cy, 15, ink)
            fillDisc(b, cx, cy, 12, TurretZone64.rgb(90, 150, 255))
            fillDisc(b, cx, cy, 7, TurretZone64.rgb(170, 220, 255))
            b.fillRect(cx - 1, cy - 8, 3, 16, TurretZone64.cWhite)
        case 3:
            fillDisc(b, cx, cy + 3, 13, ink)
            fillDisc(b, cx, cy + 3, 10, TurretZone64.rgb(70, 66, 100))
            b.fillRect(cx - 1, cy - 12, 3, 6, TurretZone64.cOrange)
            b.fillRect(cx + 1, cy - 14, 5, 3, TurretZone64.cYellow)
            fillDisc(b, cx - 3, cy, 3, TurretZone64.rgb(170, 170, 210))
        default:
            b.fillRect(cx - 14, cy - 14, 28, 28, ink)
            b.fillRect(cx - 11, cy - 11, 22, 22, TurretZone64.cWhite)
            b.fillRect(cx - 3, cy - 9, 6, 18, TurretZone64.cRed)
            b.fillRect(cx - 9, cy - 3, 18, 6, TurretZone64.cRed)
        }
    }

    private func drawStar(_ b: TrueColorBuffer, _ x: Int, _ y: Int, _ scale: Int, _ c: UInt32) {
        for cell in TurretZone64.starCells {
            b.fillRect(x + cell[0] * scale, y + cell[1] * scale, scale, scale, c)
        }
    }

    private func drawOverlays(_ b: TrueColorBuffer) {
        let yellow = TurretZone64.cYellow
        let white = TurretZone64.cWhite
        switch phase {
        case .title:
            ctext(b, "TURRET", 22, TurretZone64.cOrange, 7)
            ctext(b, "ZONE 64", 66, yellow, 7)
            ctext(b, "DEFEND THE SKY CITY", 118, white, 1)
            if (frame / 30) & 1 == 0 { ctext(b, "PRESS A TO START", 196, yellow, 3) }
            ctext(b, "LEFT RIGHT SPIN  UP DOWN TILT", 232, white, 1)
            ctext(b, "A FIRE (AUTO-LOCK)  B BOMB", 246, white, 1)
        case .playing:
            if waveBanner > 0 {
                let sc = waveBanner > 100 ? 6 : 5
                ctext(b, "WAVE " + String(wave), 80, yellow, sc)
                let c = waveCounts(wave)
                if c[3] > 0 {
                    ctext(b, "BOSS INCOMING!", 124, TurretZone64.cRed, 3)
                } else {
                    ctext(b, "GET READY!", 124, white, 2)
                }
            }
        case .clear:
            ctext(b, "WAVE CLEAR!", 76, TurretZone64.cGreen, 5)
            ctext(b, "BONUS +" + String(bonusText), 122, yellow, 2)
        case .upgrade:
            b.fillRect(0, 0, 320, 288, TurretZone64.rgb(30, 20, 80))
            for k in 0..<12 {
                let yy = k * 24 + (frame / 2) % 24
                b.fillRect(0, yy, 320, 2, TurretZone64.rgb(50, 36, 110))
            }
            ctext(b, "CHOOSE AN UPGRADE", 18, yellow, 3)
            ctext(b, "WAVE " + String(wave) + " CLEAR", 46, TurretZone64.cGreen, 2)
            for i in 0..<3 {
                let x = 14 + i * 100
                let sel = i == cardSel
                let y = sel ? 70 : 78
                let h = sel ? 150 : 134
                let k = cards[i]
                b.fillRect(x - 3, y - 3, 98, h + 6, sel ? yellow : TurretZone64.cBlack)
                b.fillRect(x, y, 92, h, TurretZone64.cPanel)
                b.fillRect(x, y, 92, 4, sel ? yellow : TurretZone64.cCyan)
                drawIcon(b, k, x + 46, y + 34)
                let nm = TurretZone64.upgradeNames[k]
                b.textCentered(nm, y: y + 62, TurretZone64.cWhite, scale: 2)
                let d1 = TurretZone64.upgradeDesc1[k]
                let d2 = TurretZone64.upgradeDesc2[k]
                b.text(d1, x + 46 - b.textWidth(d1, scale: 1) / 2, y + 88, TurretZone64.cCyan, scale: 1)
                b.text(d2, x + 46 - b.textWidth(d2, scale: 1) / 2, y + 98, TurretZone64.cCyan, scale: 1)
            }
            ctext(b, "LEFT RIGHT CHOOSE   A PICK", 246, white, 1)
            ctext(b, "BASE " + String(baseHP) + "/" + String(baseMax), 262, TurretZone64.cGreen, 1)
        case .over:
            b.fillRect(36, 26, 248, 230, TurretZone64.cBlack)
            b.fillRect(38, 28, 244, 226, TurretZone64.cPanel)
            b.fillRect(38, 28, 244, 4, victory ? TurretZone64.cGreen : TurretZone64.cOrange)
            let head = victory ? "SKY CITY SAVED!" : "BASE DOWN!"
            ctext(b, head, 40, victory ? TurretZone64.cGreen : yellow, 3)
            var stars = 1
            if wave >= 4 { stars = 2 }
            if wave >= 8 || victory { stars = 3 }
            for i in 0..<3 {
                let c: UInt32 = i < stars ? yellow : TurretZone64.rgb(100, 84, 150)
                drawStar(b, 100 + i * 46, 72, 4, c)
            }
            var rank = "CADET"
            if stars == 2 { rank = "GUNNER" }
            if stars >= 3 { rank = "SKY GUARDIAN" }
            ctext(b, rank, 114, TurretZone64.cPink, 2)
            ctext(b, "WAVE " + String(max(1, wave)) + "   KOS " + String(kills), 138, white, 2)
            ctext(b, "BEST COMBO X" + String(bestCombo), 158, white, 2)
            var acc = 0
            if shots > 0 { acc = min(100, (hits * 100) / shots) }
            ctext(b, "ACCURACY " + String(acc) + "%", 178, white, 2)
            ctext(b, "SCORE " + zeroPad(scoreValue, 6), 202, yellow, 3)
            if overTimer > 45 && (frame / 30) & 1 == 0 {
                if victory && !endless {
                    ctext(b, "A ENDLESS MODE", 232, white, 1)
                    ctext(b, "START NEW GAME", 242, white, 1)
                } else {
                    ctext(b, "PRESS A", 236, white, 1)
                }
            }
        }
    }
}

extension Cartridge {
    static let turretZone64 = Cartridge(
        id: "turretzone64", title: "TURRET ZONE 64", genre: "Shooter",
        blurb: "Man a turret on a floating sky-city and spin 360 degrees to blast robots, drones and blimps. Auto-lock helps your thumbs, bombs clear the sky, and upgrades keep you ahead.",
        controls: "LEFT/RIGHT spin, UP/DOWN tilt, hold A to fire (auto-lock), B bomb when charged, SELECT radar.",
        era: .n64, labelTop: 0x5CC8FF, labelBottom: 0x7A3AD8, factory: { TurretZone64() })
}
