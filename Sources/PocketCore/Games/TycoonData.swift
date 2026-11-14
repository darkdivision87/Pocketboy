#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

// TYCOON TOWN data tables, save format and a tiny software rasteriser (all writing straight into the pixel pointer).

// MARK: - Safe float helpers

@inline(__always) func tycI(_ f: Float) -> Int {
    if !(f > -1000000 && f < 1000000) { return 0 }
    return Int(f)
}

@inline(__always) func tycFloorI(_ f: Float) -> Int { return tycI(floor(f)) }
@inline(__always) func tycCeilI(_ f: Float) -> Int { return tycI(ceil(f)) }

// MARK: - 3x3 matrix (dice rotation)

struct TycoonM3 {
    var a: Float
    var b: Float
    var c: Float
    var d: Float
    var e: Float
    var f: Float
    var g: Float
    var h: Float
    var i: Float

    static let identity = TycoonM3(a: 1, b: 0, c: 0, d: 0, e: 1, f: 0, g: 0, h: 0, i: 1)

    static func rotX(_ t: Float) -> TycoonM3 {
        let cs: Float = cos(t)
        let sn: Float = sin(t)
        return TycoonM3(a: 1, b: 0, c: 0, d: 0, e: cs, f: -sn, g: 0, h: sn, i: cs)
    }

    static func rotY(_ t: Float) -> TycoonM3 {
        let cs: Float = cos(t)
        let sn: Float = sin(t)
        return TycoonM3(a: cs, b: 0, c: sn, d: 0, e: 1, f: 0, g: -sn, h: 0, i: cs)
    }

    static func rotZ(_ t: Float) -> TycoonM3 {
        let cs: Float = cos(t)
        let sn: Float = sin(t)
        return TycoonM3(a: cs, b: -sn, c: 0, d: sn, e: cs, f: 0, g: 0, h: 0, i: 1)
    }

    /// Rotation by angle t around the axis (ax, ay, az) (Rodrigues).
    static func axis(_ ax: Float, _ ay: Float, _ az: Float, _ t: Float) -> TycoonM3 {
        var len: Float = sqrt(ax * ax + ay * ay + az * az)
        if len < 0.0001 { len = 1 }
        let kx: Float = ax / len
        let ky: Float = ay / len
        let kz: Float = az / len
        let ct: Float = cos(t)
        let st: Float = sin(t)
        let oc: Float = 1 - ct
        let m00: Float = ct + kx * kx * oc
        let m01: Float = kx * ky * oc - kz * st
        let m02: Float = kx * kz * oc + ky * st
        let m10: Float = ky * kx * oc + kz * st
        let m11: Float = ct + ky * ky * oc
        let m12: Float = ky * kz * oc - kx * st
        let m20: Float = kz * kx * oc - ky * st
        let m21: Float = kz * ky * oc + kx * st
        let m22: Float = ct + kz * kz * oc
        return TycoonM3(a: m00, b: m01, c: m02, d: m10, e: m11, f: m12, g: m20, h: m21, i: m22)
    }

    /// self * o
    func mul(_ o: TycoonM3) -> TycoonM3 {
        let r00: Float = a * o.a + b * o.d + c * o.g
        let r01: Float = a * o.b + b * o.e + c * o.h
        let r02: Float = a * o.c + b * o.f + c * o.i
        let r10: Float = d * o.a + e * o.d + f * o.g
        let r11: Float = d * o.b + e * o.e + f * o.h
        let r12: Float = d * o.c + e * o.f + f * o.i
        let r20: Float = g * o.a + h * o.d + i * o.g
        let r21: Float = g * o.b + h * o.e + i * o.h
        let r22: Float = g * o.c + h * o.f + i * o.i
        return TycoonM3(a: r00, b: r01, c: r02, d: r10, e: r11, f: r12, g: r20, h: r21, i: r22)
    }

    func apply(_ x: Float, _ y: Float, _ z: Float) -> (Float, Float, Float) {
        let nx: Float = a * x + b * y + c * z
        let ny: Float = d * x + e * y + f * z
        let nz: Float = g * x + h * y + i * z
        return (nx, ny, nz)
    }

    /// Matrix that brings the die face showing `v` (1...6) to the top (+Y).
    static func faceUp(_ v: Int) -> TycoonM3 {
        let q: Float = Float.pi / 2
        switch v {
        case 1: return TycoonM3.identity
        case 2: return TycoonM3.rotZ(q)
        case 3: return TycoonM3.rotX(-q)
        case 4: return TycoonM3.rotX(q)
        case 5: return TycoonM3.rotZ(-q)
        default: return TycoonM3.rotX(Float.pi)
        }
    }
}

// MARK: - Palette

enum TycoonPal {
    static func h(_ v: UInt32) -> UInt32 { return TrueColorBuffer.hex(v) }
    static let white: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    static let cream: UInt32 = TrueColorBuffer.rgb(255, 246, 220)
    static let ink: UInt32 = TrueColorBuffer.rgb(40, 38, 74)
    static let navy: UInt32 = TrueColorBuffer.rgb(36, 48, 110)
    static let gold: UInt32 = TrueColorBuffer.rgb(255, 205, 40)
    static let goldDark: UInt32 = TrueColorBuffer.rgb(214, 140, 20)
    static let goldLight: UInt32 = TrueColorBuffer.rgb(255, 240, 150)
    static let red: UInt32 = TrueColorBuffer.rgb(255, 84, 84)
    static let green: UInt32 = TrueColorBuffer.rgb(70, 205, 110)
    static let greenDark: UInt32 = TrueColorBuffer.rgb(30, 140, 80)
    static let blue: UInt32 = TrueColorBuffer.rgb(70, 150, 255)
    static let pink: UInt32 = TrueColorBuffer.rgb(255, 130, 190)
    static let grey: UInt32 = TrueColorBuffer.rgb(150, 160, 190)
    static let greyDark: UInt32 = TrueColorBuffer.rgb(96, 104, 140)
    static let panel: UInt32 = TrueColorBuffer.rgb(46, 60, 128)
    static let panelLight: UInt32 = TrueColorBuffer.rgb(84, 104, 196)
    static let grass: UInt32 = TrueColorBuffer.rgb(122, 214, 110)
    static let grassDark: UInt32 = TrueColorBuffer.rgb(78, 168, 92)
    static let stone: UInt32 = TrueColorBuffer.rgb(236, 228, 208)
    static let wood: UInt32 = TrueColorBuffer.rgb(176, 112, 74)
    static let rock: UInt32 = TrueColorBuffer.rgb(142, 98, 112)
}

// MARK: - Software rasteriser

struct TycoonGfx {
    let p: UnsafeMutablePointer<UInt32>
    let w: Int
    let h: Int

    static func mul(_ c: UInt32, _ f: Float) -> UInt32 {
        let r: Float = Float(c & 255) * f
        let g: Float = Float((c >> 8) & 255) * f
        let b: Float = Float((c >> 16) & 255) * f
        return TrueColorBuffer.rgb(tycI(r), tycI(g), tycI(b))
    }

    static func mix(_ a: UInt32, _ b: UInt32, _ t: Float) -> UInt32 {
        let tt: Float = max(0, min(1, t))
        let ar: Float = Float(a & 255)
        let ag: Float = Float((a >> 8) & 255)
        let ab: Float = Float((a >> 16) & 255)
        let br: Float = Float(b & 255)
        let bg: Float = Float((b >> 8) & 255)
        let bb: Float = Float((b >> 16) & 255)
        let r: Float = ar + (br - ar) * tt
        let g: Float = ag + (bg - ag) * tt
        let bl: Float = ab + (bb - ab) * tt
        return TrueColorBuffer.rgb(tycI(r), tycI(g), tycI(bl))
    }

    func rect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: UInt32) {
        let x0 = max(0, x)
        let y0 = max(0, y)
        let x1 = min(w, x + rw)
        let y1 = min(h, y + rh)
        if x0 >= x1 || y0 >= y1 { return }
        for yy in y0..<y1 {
            let row = p + yy * w
            for xx in x0..<x1 { row[xx] = c }
        }
    }

    func rectA(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: UInt32, _ a: Int) {
        let x0 = max(0, x)
        let y0 = max(0, y)
        let x1 = min(w, x + rw)
        let y1 = min(h, y + rh)
        if x0 >= x1 || y0 >= y1 { return }
        let al = max(0, min(255, a))
        let ia = 255 - al
        let sr = Int(c & 255) * al
        let sg = Int((c >> 8) & 255) * al
        let sb = Int((c >> 16) & 255) * al
        for yy in y0..<y1 {
            let row = p + yy * w
            for xx in x0..<x1 {
                let d = row[xx]
                let nr = (sr + Int(d & 255) * ia) / 255
                let ng = (sg + Int((d >> 8) & 255) * ia) / 255
                let nb = (sb + Int((d >> 16) & 255) * ia) / 255
                row[xx] = 0xFF00_0000 | UInt32(nr) | (UInt32(ng) << 8) | (UInt32(nb) << 16)
            }
        }
    }

    /// Rectangle with chamfered (rounded looking) corners.
    func rrect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ r: Int, _ c: UInt32) {
        if rw <= 0 || rh <= 0 { return }
        let rr = max(0, min(r, min(rw, rh) / 2))
        if rr == 0 { rect(x, y, rw, rh, c); return }
        rect(x, y + rr, rw, rh - 2 * rr, c)
        var i = 0
        while i < rr {
            let t = Float(rr - i) - 0.5
            let inset = rr - tycI(sqrt(max(0, Float(rr * rr) - t * t)) + 0.5)
            let ins = max(0, min(rr, inset))
            rect(x + ins, y + i, rw - 2 * ins, 1, c)
            rect(x + ins, y + rh - 1 - i, rw - 2 * ins, 1, c)
            i += 1
        }
    }

    func frame(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ t: Int, _ c: UInt32) {
        rect(x, y, rw, t, c)
        rect(x, y + rh - t, rw, t, c)
        rect(x, y, t, rh, c)
        rect(x + rw - t, y, t, rh, c)
    }

    func tri(_ ax: Float, _ ay: Float, _ bx: Float, _ by: Float, _ cx: Float, _ cy: Float, _ col: UInt32) {
        if abs(ax) > 20000 || abs(ay) > 20000 || abs(bx) > 20000 || abs(by) > 20000 || abs(cx) > 20000 || abs(cy) > 20000 { return }
        if ax != ax || ay != ay || bx != bx || by != by || cx != cx || cy != cy { return }
        var x0 = ax
        var y0 = ay
        var x1 = bx
        var y1 = by
        var x2 = cx
        var y2 = cy
        if y0 > y1 { swap(&x0, &x1); swap(&y0, &y1) }
        if y1 > y2 { swap(&x1, &x2); swap(&y1, &y2) }
        if y0 > y1 { swap(&x0, &x1); swap(&y0, &y1) }
        let ys = max(0, tycCeilI(y0 - 0.5))
        let ye = min(h - 1, tycCeilI(y2 - 0.5) - 1)
        if ys > ye { return }
        let d02: Float = y2 - y0
        if d02 < 0.0001 { return }
        let d01: Float = y1 - y0
        let d12: Float = y2 - y1
        var y = ys
        while y <= ye {
            let yc: Float = Float(y) + 0.5
            let t02: Float = (yc - y0) / d02
            let xa: Float = x0 + (x2 - x0) * t02
            var xb: Float = x1
            if yc < y1 {
                if d01 > 0.0001 { xb = x0 + (x1 - x0) * ((yc - y0) / d01) }
            } else {
                if d12 > 0.0001 { xb = x1 + (x2 - x1) * ((yc - y1) / d12) }
            }
            let xl: Float = min(xa, xb)
            let xr: Float = max(xa, xb)
            let sx = max(0, tycCeilI(xl - 0.5))
            let ex = min(w, tycCeilI(xr - 0.5))
            if sx < ex {
                let row = p + y * w
                for x in sx..<ex { row[x] = col }
            }
            y += 1
        }
    }

    func quad(_ ax: Float, _ ay: Float, _ bx: Float, _ by: Float, _ cx: Float, _ cy: Float, _ dx: Float, _ dy: Float, _ col: UInt32) {
        tri(ax, ay, bx, by, cx, cy, col)
        tri(ax, ay, cx, cy, dx, dy, col)
    }

    func line(_ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float, _ t: Float, _ col: UInt32) {
        let dx: Float = x1 - x0
        let dy: Float = y1 - y0
        let len: Float = sqrt(dx * dx + dy * dy)
        if len < 0.001 { return }
        let nx: Float = -dy / len * t * 0.5
        let ny: Float = dx / len * t * 0.5
        quad(x0 + nx, y0 + ny, x1 + nx, y1 + ny, x1 - nx, y1 - ny, x0 - nx, y0 - ny, col)
    }

    func ellipse(_ cx: Float, _ cy: Float, _ rx: Float, _ ry: Float, _ col: UInt32) {
        if !(rx > 0.2 && ry > 0.2) { return }
        if abs(cx) > 20000 || abs(cy) > 20000 || rx > 20000 || ry > 20000 { return }
        let ys = max(0, tycCeilI(cy - ry - 0.5))
        let ye = min(h - 1, tycFloorI(cy + ry - 0.5))
        if ys > ye { return }
        for y in ys...ye {
            let dy: Float = (Float(y) + 0.5 - cy) / ry
            let k: Float = 1 - dy * dy
            if k <= 0 { continue }
            let half: Float = rx * sqrt(k)
            let sx = max(0, tycCeilI(cx - half - 0.5))
            let ex = min(w, tycCeilI(cx + half - 0.5))
            if sx < ex {
                let row = p + y * w
                for x in sx..<ex { row[x] = col }
            }
        }
    }

    func ellipseA(_ cx: Float, _ cy: Float, _ rx: Float, _ ry: Float, _ col: UInt32, _ a: Int) {
        if !(rx > 0.2 && ry > 0.2) { return }
        if abs(cx) > 20000 || abs(cy) > 20000 || rx > 20000 || ry > 20000 { return }
        let al = max(0, min(255, a))
        if al == 0 { return }
        let ia = 255 - al
        let sr = Int(col & 255) * al
        let sg = Int((col >> 8) & 255) * al
        let sb = Int((col >> 16) & 255) * al
        let ys = max(0, tycCeilI(cy - ry - 0.5))
        let ye = min(h - 1, tycFloorI(cy + ry - 0.5))
        if ys > ye { return }
        for y in ys...ye {
            let dy: Float = (Float(y) + 0.5 - cy) / ry
            let k: Float = 1 - dy * dy
            if k <= 0 { continue }
            let half: Float = rx * sqrt(k)
            let sx = max(0, tycCeilI(cx - half - 0.5))
            let ex = min(w, tycCeilI(cx + half - 0.5))
            if sx < ex {
                let row = p + y * w
                for x in sx..<ex {
                    let d = row[x]
                    let nr = (sr + Int(d & 255) * ia) / 255
                    let ng = (sg + Int((d >> 8) & 255) * ia) / 255
                    let nb = (sb + Int((d >> 16) & 255) * ia) / 255
                    row[x] = 0xFF00_0000 | UInt32(nr) | (UInt32(ng) << 8) | (UInt32(nb) << 16)
                }
            }
        }
    }

    func disc(_ cx: Float, _ cy: Float, _ r: Float, _ col: UInt32) {
        ellipse(cx, cy, r, r, col)
    }

    func textWidth(_ s: String, _ sc: Int) -> Int {
        return s.isEmpty ? 0 : (s.count * 4 - 1) * sc
    }

    func text(_ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ sc: Int) {
        var cx = x
        for ch in s.uppercased() {
            let gl = Font.glyph(ch)
            if gl != 0 {
                for row in 0..<5 {
                    for col in 0..<3 {
                        if (gl >> UInt16(14 - (row * 3 + col))) & 1 == 1 {
                            rect(cx + col * sc, y + row * sc, sc, sc, c)
                        }
                    }
                }
            }
            cx += 4 * sc
        }
    }

    func textC(_ s: String, _ cx: Int, _ y: Int, _ c: UInt32, _ sc: Int) {
        text(s, cx - textWidth(s, sc) / 2, y, c, sc)
    }

    func textS(_ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ sc: Int, _ sh: UInt32) {
        text(s, x + sc, y + sc, sh, sc)
        text(s, x, y, c, sc)
    }

    func textCS(_ s: String, _ cx: Int, _ y: Int, _ c: UInt32, _ sc: Int, _ sh: UInt32) {
        textS(s, cx - textWidth(s, sc) / 2, y, c, sc, sh)
    }

    func textO(_ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ sc: Int, _ oc: UInt32) {
        let o = max(1, sc / 2)
        text(s, x - o, y, oc, sc)
        text(s, x + o, y, oc, sc)
        text(s, x, y - o, oc, sc)
        text(s, x, y + o + (sc >= 3 ? 1 : 0), oc, sc)
        text(s, x, y, c, sc)
    }

    func textCO(_ s: String, _ cx: Int, _ y: Int, _ c: UInt32, _ sc: Int, _ oc: UInt32) {
        textO(s, cx - textWidth(s, sc) / 2, y, c, sc, oc)
    }

    /// Little gold coin.
    func coin(_ cx: Float, _ cy: Float, _ r: Float) {
        disc(cx, cy, r, TycoonPal.goldDark)
        disc(cx, cy - r * 0.08, r * 0.82, TycoonPal.gold)
        disc(cx - r * 0.2, cy - r * 0.25, r * 0.35, TycoonPal.goldLight)
        if r >= 4 {
            rect(tycI(cx) - 1, tycI(cy) - tycI(r * 0.4), 2, max(2, tycI(r * 0.8)), TycoonPal.goldDark)
        }
    }

    /// Coin glyph followed by a number. Returns the drawn width.
    @discardableResult
    func money(_ x: Int, _ y: Int, _ n: Int, _ sc: Int, _ col: UInt32, _ sh: UInt32) -> Int {
        let r: Float = Float(sc) * 2.6 + 0.6
        coin(Float(x) + r, Float(y) + Float(sc) * 2.5, r)
        let tx = x + tycI(r * 2) + 2
        let s = String(n)
        textS(s, tx, y, col, sc, sh)
        return tycI(r * 2) + 2 + textWidth(s, sc) + sc
    }

    func moneyWidth(_ n: Int, _ sc: Int) -> Int {
        let r: Float = Float(sc) * 2.6 + 0.6
        return tycI(r * 2) + 2 + textWidth(String(n), sc) + sc
    }
}

// MARK: - Board tables

struct TycoonTile {
    let kind: Int
    let name: String
    let dist: Int
    let price: Int
}

struct TycoonCard {
    let kind: Int
    let amt: Int
    let l1: String
    let l2: String
}

enum TycoonBoard {
    static let kStart = 0
    static let kTimeOut = 1
    static let kPark = 2
    static let kGoTimeOut = 3
    static let kStreet = 4
    static let kStation = 5
    static let kSurprise = 6
    static let kTreasure = 7
    static let kTax = 8

    static let tileSize: Float = 40
    static let tileH: Float = 7
    static let count = 32
    static let maxRounds = 30
    static let salary = 200
    static let startCash = 1500
    static let taxAmount = 100

    static let distNames: [String] = [
        "GUMDROP GARDENS", "CLOUD HEIGHTS", "CORAL COVE", "TANGERINE TERRACE",
        "CHERRY HILL", "SUNBEAM SQUARE", "MOSSY MEADOWS", "STARLIGHT BLVD"
    ]

    static let distCols: [UInt32] = [
        TrueColorBuffer.hex(0xC68642), TrueColorBuffer.hex(0x4FC3F7), TrueColorBuffer.hex(0xFF8FB8), TrueColorBuffer.hex(0xFF9F1C),
        TrueColorBuffer.hex(0xE63946), TrueColorBuffer.hex(0xFFD60A), TrueColorBuffer.hex(0x43C06E), TrueColorBuffer.hex(0x6C4FD8)
    ]

    static let tokenNames: [String] = ["BISCUIT", "BEEP", "PIP", "RUMBLE"]
    static let tokenLabels: [String] = ["PUPPY", "ROBOT", "PENGUIN", "DINO"]
    static let tokenCols: [UInt32] = [
        TrueColorBuffer.hex(0xF2A65A), TrueColorBuffer.hex(0x6EC6F0), TrueColorBuffer.hex(0x8E7CE8), TrueColorBuffer.hex(0x5BCB6B)
    ]
    static let hatNames: [String] = ["NO HAT", "PARTY HAT", "CROWN", "PROPELLER", "FLOWER", "STAR HALO", "CAP"]
    static let skinNames: [String] = ["CLASSIC", "GOLDEN", "RAINBOW"]
    static let personalityNames: [String] = ["CAUTIOUS", "BUILDER", "GAMBLER"]

    static let tiles: [TycoonTile] = {
        var t: [TycoonTile] = []
        func st(_ n: String, _ d: Int, _ p: Int) { t.append(TycoonTile(kind: 4, name: n, dist: d, price: p)) }
        func other(_ k: Int, _ n: String, _ p: Int) { t.append(TycoonTile(kind: k, name: n, dist: -1, price: p)) }
        other(0, "START", 0)
        st("JELLYBEAN LANE", 0, 60)
        other(7, "TREASURE", 0)
        st("SPRINKLE STREET", 0, 60)
        other(8, "FIX-IT", 0)
        other(5, "BUS DEPOT", 200)
        st("PUFFY PLACE", 1, 100)
        st("NIMBUS ROW", 1, 100)
        other(1, "TIME-OUT", 0)
        st("SKYLARK COURT", 1, 120)
        st("CORAL CIRCLE", 2, 140)
        other(6, "SURPRISE!", 0)
        st("SEASHELL WALK", 2, 160)
        other(5, "FERRY PIER", 200)
        st("CITRUS CIRCLE", 3, 180)
        st("MARMALADE MEWS", 3, 180)
        other(2, "FREE PARK", 0)
        st("ZEST AVENUE", 3, 200)
        st("CHERRY ROAD", 4, 220)
        st("ROSY LANE", 4, 240)
        other(5, "TRAIN STATION", 200)
        st("HONEY HILL", 5, 260)
        st("DAISY DRIVE", 5, 260)
        st("BUTTERCUP WAY", 5, 280)
        other(3, "GO TO TIME-OUT", 0)
        other(6, "SURPRISE!", 0)
        st("CLOVER COURT", 6, 300)
        st("FERN STREET", 6, 320)
        other(5, "CABLE CAR", 200)
        st("COMET DRIVE", 7, 350)
        st("GALAXY GATE", 7, 380)
        st("MOONBEAM PLAZA", 7, 400)
        return t
    }()

    static let distTiles: [[Int]] = {
        var d = [[Int]](repeating: [], count: 8)
        for i in 0..<tiles.count {
            let dd = tiles[i].dist
            if dd >= 0 && dd < 8 { d[dd].append(i) }
        }
        return d
    }()

    /// Grid cell (0...8) of ring index i.
    static func grid(_ i: Int) -> (Int, Int) {
        let k = ((i % 32) + 32) % 32
        if k < 8 { return (8 - k, 8) }
        if k < 16 { return (0, 8 - (k - 8)) }
        if k < 24 { return (k - 16, 0) }
        return (8, k - 24)
    }

    static let tx: [Float] = {
        var a = [Float](repeating: 0, count: 32)
        for i in 0..<32 {
            let g = grid(i)
            a[i] = Float(g.0 - 4) * tileSize
        }
        return a
    }()

    static let tz: [Float] = {
        var a = [Float](repeating: 0, count: 32)
        for i in 0..<32 {
            let g = grid(i)
            a[i] = Float(g.1 - 4) * tileSize
        }
        return a
    }()

    /// Static painter's order (far to near) for tiles; decor items get ids 32+.
    static let decor: [(Float, Float, Int)] = [
        (0, 0, 0), (-70, -70, 1), (70, -70, 1), (-70, 70, 1), (70, 70, 1),
        (-100, 0, 2), (100, 0, 2), (0, -100, 2), (0, 100, 2), (-40, 100, 1), (100, -40, 1), (-100, 40, 1), (40, -100, 1)
    ]

    static let order: [Int] = {
        var items: [(Int, Float)] = []
        for i in 0..<32 { items.append((i, tx[i] + tz[i])) }
        for j in 0..<decor.count { items.append((32 + j, decor[j].0 + decor[j].1)) }
        var k = 1
        while k < items.count {
            let cur = items[k]
            var m = k - 1
            while m >= 0 && items[m].1 > cur.1 {
                items[m + 1] = items[m]
                m -= 1
            }
            items[m + 1] = cur
            k += 1
        }
        var out: [Int] = []
        for it in items { out.append(it.0) }
        return out
    }()

    static let surprise: [TycoonCard] = [
        TycoonCard(kind: 0, amt: 60, l1: "BALLOON PARADE!", l2: "YOU WIN 60 COINS"),
        TycoonCard(kind: 1, amt: 50, l1: "ICE CREAM OOPS!", l2: "YOU BOUGHT 100 CONES. PAY 50"),
        TycoonCard(kind: 2, amt: 20, l1: "HAPPY BIRTHDAY!", l2: "EVERYONE GIVES YOU 20"),
        TycoonCard(kind: 3, amt: 10, l1: "PIZZA PARTY!", l2: "TREAT EACH FRIEND 10"),
        TycoonCard(kind: 4, amt: 0, l1: "SPEEDY SCOOTER!", l2: "ZOOM TO START"),
        TycoonCard(kind: 5, amt: 3, l1: "WHEEE SLIDE!", l2: "GO FORWARD 3 TILES"),
        TycoonCard(kind: 6, amt: 0, l1: "FREE BUILDERS!", l2: "UPGRADE A STREET FREE"),
        TycoonCard(kind: 0, amt: 80, l1: "FOUND A RAINBOW!", l2: "POT OF 80 COINS"),
        TycoonCard(kind: 1, amt: 30, l1: "SILLY SPILL!", l2: "LOST 30 IN THE SANDBOX"),
        TycoonCard(kind: 4, amt: 16, l1: "PICNIC TIME!", l2: "SKIP OVER TO FREE PARK"),
        TycoonCard(kind: 0, amt: 100, l1: "MAGIC SHOW!", l2: "THE CROWD TIPS YOU 100"),
        TycoonCard(kind: 7, amt: 3, l1: "BACKWARDS DAY!", l2: "WALK BACK 3 TILES")
    ]

    static let treasure: [TycoonCard] = [
        TycoonCard(kind: 0, amt: 100, l1: "TREASURE CHEST!", l2: "SHINY GOLD COINS +100"),
        TycoonCard(kind: 0, amt: 50, l1: "GIFT FROM GRAN!", l2: "A CARD WITH 50 COINS"),
        TycoonCard(kind: 0, amt: 60, l1: "LEMONADE STAND!", l2: "SWEET PROFIT +60"),
        TycoonCard(kind: 0, amt: 40, l1: "SUPER REFUND!", l2: "THE BANK SAYS SORRY +40"),
        TycoonCard(kind: 0, amt: 120, l1: "GOLD STAR PRIZE!", l2: "BEST CITY BUILDER +120"),
        TycoonCard(kind: 0, amt: 30, l1: "CAKE SALE!", l2: "YUMMY CRUMBS +30"),
        TycoonCard(kind: 0, amt: 80, l1: "PET SHOW WINNER!", l2: "BLUE RIBBON +80"),
        TycoonCard(kind: 0, amt: 70, l1: "BURIED TREASURE!", l2: "X MARKS THE SPOT +70")
    ]

    // Economy helpers
    static let rentMult: [Int] = [8, 25, 60, 120, 200, 320]

    static func buildCost(_ tile: Int, _ toLevel: Int) -> Int {
        if tile < 0 || tile >= tiles.count { return 0 }
        let pr = tiles[tile].price
        if toLevel >= 5 { return pr }
        let c = pr * 45 / 100
        return max(20, (c / 5) * 5)
    }

    static func levelName(_ lv: Int) -> String {
        switch lv {
        case 0: return "EMPTY LOT"
        case 1: return "COTTAGE"
        case 2: return "HOUSE"
        case 3: return "SHOP"
        case 4: return "TOWER"
        default: return "LANDMARK"
        }
    }
}

// MARK: - Save

struct TycoonSave {
    var games: Int = 0
    var wins: [Int] = [0, 0, 0, 0]
    var best: Int = 0
    var unlocked: Int = 0
    var token: Int = 0
    var hat: Int = 0
    var skin: Int = 0
    var how: Int = 0

    static let version: UInt8 = 1
    static let length = 16

    func encode() -> [UInt8] {
        var o = [UInt8](repeating: 0, count: TycoonSave.length)
        o[0] = TycoonSave.version
        let g = max(0, min(65535, games))
        o[1] = UInt8(g >> 8)
        o[2] = UInt8(g & 255)
        for i in 0..<4 {
            let wv = i < wins.count ? wins[i] : 0
            o[3 + i] = UInt8(max(0, min(255, wv)))
        }
        let bs = max(0, min(2_000_000_000, best))
        o[7] = UInt8((bs >> 24) & 255)
        o[8] = UInt8((bs >> 16) & 255)
        o[9] = UInt8((bs >> 8) & 255)
        o[10] = UInt8(bs & 255)
        o[11] = UInt8(max(0, min(8, unlocked)))
        o[12] = UInt8(max(0, min(3, token)))
        o[13] = UInt8(max(0, min(6, hat)))
        o[14] = UInt8(max(0, min(2, skin)))
        o[15] = UInt8(max(0, min(1, how)))
        return o
    }

    static func decode(_ b: [UInt8]) -> TycoonSave? {
        if b.count < length { return nil }
        if b[0] != version { return nil }
        var s = TycoonSave()
        s.games = (Int(b[1]) << 8) | Int(b[2])
        for i in 0..<4 { s.wins[i] = Int(b[3 + i]) }
        let v: Int = (Int(b[7]) << 24) | (Int(b[8]) << 16) | (Int(b[9]) << 8) | Int(b[10])
        s.best = max(0, min(2_000_000_000, v))
        s.unlocked = max(0, min(8, Int(b[11])))
        s.token = max(0, min(3, Int(b[12])))
        s.hat = max(0, min(6, Int(b[13])))
        s.skin = max(0, min(2, Int(b[14])))
        s.how = max(0, min(1, Int(b[15])))
        if s.hat > s.unlocked && s.hat > 0 { s.hat = 0 }
        if s.skin == 1 && s.unlocked < 7 { s.skin = 0 }
        if s.skin == 2 && s.unlocked < 8 { s.skin = 0 }
        return s
    }
}
