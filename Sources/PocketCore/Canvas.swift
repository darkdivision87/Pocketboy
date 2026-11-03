#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// An indexed-colour framebuffer (default 160x144). Every pixel is a palette index 0...31.
/// All drawing is clipped, so out-of-range coordinates are always safe.
/// `cameraX/cameraY` are subtracted from every coordinate (world -> screen); reset them to 0 to draw HUDs.
public final class Canvas {
    public let width: Int
    public let height: Int
    public var pixels: [UInt8]
    public var cameraX: Int = 0
    public var cameraY: Int = 0

    public init(width: Int = 160, height: Int = 144) {
        self.width = width
        self.height = height
        self.pixels = [UInt8](repeating: 0, count: width * height)
    }

    @inline(__always) static func col(_ c: Int) -> UInt8 { UInt8(truncatingIfNeeded: c & 31) }

    public func clear(_ c: Int) {
        let v = Canvas.col(c)
        for i in 0..<pixels.count { pixels[i] = v }
    }

    public func setPixel(_ x: Int, _ y: Int, _ c: Int) {
        let sx = x - cameraX
        let sy = y - cameraY
        if sx < 0 || sy < 0 || sx >= width || sy >= height { return }
        pixels[sy * width + sx] = Canvas.col(c)
    }

    /// Reads a screen-space pixel (no camera applied). Returns 0 outside the screen.
    public func pixel(_ sx: Int, _ sy: Int) -> Int {
        if sx < 0 || sy < 0 || sx >= width || sy >= height { return 0 }
        return Int(pixels[sy * width + sx])
    }

    public func fillRect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: Int) {
        if w <= 0 || h <= 0 { return }
        let x0 = max(0, x - cameraX)
        let y0 = max(0, y - cameraY)
        let x1 = min(width, x - cameraX + w)
        let y1 = min(height, y - cameraY + h)
        if x0 >= x1 || y0 >= y1 { return }
        let v = Canvas.col(c)
        for yy in y0..<y1 {
            let base = yy * width
            for xx in x0..<x1 { pixels[base + xx] = v }
        }
    }

    /// Checkerboard fill alternating two colours (a cheap "dither" for gradients and shadows).
    public func fillChecker(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c1: Int, _ c2: Int) {
        if w <= 0 || h <= 0 { return }
        for yy in 0..<h {
            for xx in 0..<w {
                setPixel(x + xx, y + yy, ((xx + yy) & 1) == 0 ? c1 : c2)
            }
        }
    }

    public func strokeRect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ c: Int) {
        if w <= 0 || h <= 0 { return }
        fillRect(x, y, w, 1, c)
        fillRect(x, y + h - 1, w, 1, c)
        fillRect(x, y, 1, h, c)
        fillRect(x + w - 1, y, 1, h, c)
    }

    public func hline(_ x: Int, _ y: Int, _ length: Int, _ c: Int) { fillRect(x, y, length, 1, c) }
    public func vline(_ x: Int, _ y: Int, _ length: Int, _ c: Int) { fillRect(x, y, 1, length, c) }

    public func line(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ c: Int) {
        var x = x0
        var y = y0
        let dx = abs(x1 - x0)
        let dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        var guardCount = 0
        while guardCount < 4096 {
            setPixel(x, y, c)
            if x == x1 && y == y1 { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x += sx }
            if e2 <= dx { err += dx; y += sy }
            guardCount += 1
        }
    }

    public func fillCircle(_ cx: Int, _ cy: Int, _ r: Int, _ c: Int) {
        if r < 0 { return }
        for dy in -r...r {
            var dx = 0
            while (dx + 1) * (dx + 1) + dy * dy <= r * r + r { dx += 1 }
            fillRect(cx - dx, cy + dy, dx * 2 + 1, 1, c)
        }
    }

    public func strokeCircle(_ cx: Int, _ cy: Int, _ r: Int, _ c: Int) {
        if r < 0 { return }
        var x = r
        var y = 0
        var err = 1 - r
        while x >= y {
            setPixel(cx + x, cy + y, c); setPixel(cx - x, cy + y, c)
            setPixel(cx + x, cy - y, c); setPixel(cx - x, cy - y, c)
            setPixel(cx + y, cy + x, c); setPixel(cx - y, cy + x, c)
            setPixel(cx + y, cy - x, c); setPixel(cx - y, cy - x, c)
            y += 1
            if err < 0 {
                err += 2 * y + 1
            } else {
                x -= 1
                err += 2 * (y - x) + 1
            }
        }
    }

    /// Draws a sprite with its top-left at (x, y). If `solid` is set, every opaque pixel is drawn in that colour (hit flashes).
    public func draw(_ s: Sprite, _ x: Int, _ y: Int, flipX: Bool = false, flipY: Bool = false, solid: Int? = nil) {
        let ox = x - cameraX
        let oy = y - cameraY
        if s.width == 0 || s.height == 0 { return }
        if ox >= width || oy >= height || ox + s.width <= 0 || oy + s.height <= 0 { return }
        let solidValue: UInt8 = solid == nil ? 0 : Canvas.col(solid ?? 0)
        for sy in 0..<s.height {
            let dy = oy + sy
            if dy < 0 || dy >= height { continue }
            let srow = (flipY ? s.height - 1 - sy : sy) * s.width
            for sx in 0..<s.width {
                let dx = ox + sx
                if dx < 0 || dx >= width { continue }
                let v = s.data[srow + (flipX ? s.width - 1 - sx : sx)]
                if v != Sprite.clear {
                    pixels[dy * width + dx] = solid == nil ? v : solidValue
                }
            }
        }
    }

    // MARK: Text (built-in 3x5 font, 4px advance)

    public func textWidth(_ s: String, scale: Int = 1) -> Int {
        let n = s.count
        if n == 0 { return 0 }
        return (n * 4 - 1) * scale
    }

    public func text(_ s: String, _ x: Int, _ y: Int, _ c: Int, scale: Int = 1) {
        var cx = x
        for ch in s.uppercased() {
            let g = Font.glyph(ch)
            if g != 0 {
                for row in 0..<5 {
                    for col in 0..<3 {
                        if (g >> UInt16(14 - (row * 3 + col))) & 1 == 1 {
                            fillRect(cx + col * scale, y + row * scale, scale, scale, c)
                        }
                    }
                }
            }
            cx += 4 * scale
        }
    }

    public func textCentered(_ s: String, y: Int, _ c: Int, scale: Int = 1) {
        let w = textWidth(s, scale: scale)
        text(s, cameraX + (width - w) / 2, y, c, scale: scale)
    }

    /// Text with a one-pixel outline, for HUDs over busy backgrounds.
    public func outlinedText(_ s: String, _ x: Int, _ y: Int, _ c: Int, outline: Int) {
        text(s, x - 1, y, outline); text(s, x + 1, y, outline)
        text(s, x, y - 1, outline); text(s, x, y + 1, outline)
        text(s, x, y, c)
    }
}

/// A small paletted image. Build one from rows of text; '.' or ' ' is transparent,
/// '0'-'9' and 'a'-'v' are palette indices 0...31.
public struct Sprite {
    public static let clear: UInt8 = 255
    public let width: Int
    public let height: Int
    public let data: [UInt8]

    public init(_ rows: [String]) {
        let h = rows.count
        var w = 0
        for r in rows { w = max(w, r.count) }
        var d = [UInt8](repeating: Sprite.clear, count: w * h)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                d[y * w + x] = Sprite.index(of: ch)
            }
        }
        self.width = w
        self.height = h
        self.data = d
    }

    public init(width: Int, height: Int, data: [UInt8]) {
        self.width = width
        self.height = height
        self.data = data
    }

    static func index(of ch: Character) -> UInt8 {
        guard let a = ch.asciiValue else { return clear }
        if a >= 48 && a <= 57 { return a - 48 }
        if a >= 97 && a <= 118 { return a - 97 + 10 }
        if a >= 65 && a <= 86 { return a - 65 + 10 }
        return clear
    }

    public func flippedX() -> Sprite {
        var d = data
        for y in 0..<height {
            for x in 0..<width { d[y * width + x] = data[y * width + (width - 1 - x)] }
        }
        return Sprite(width: width, height: height, data: d)
    }

    /// Splits a wide strip into `count` equal-width frames.
    public func frames(_ count: Int) -> [Sprite] {
        if count <= 1 || width < count { return [self] }
        let fw = width / count
        var out: [Sprite] = []
        for f in 0..<count {
            var d = [UInt8](repeating: Sprite.clear, count: fw * height)
            for y in 0..<height {
                for x in 0..<fw { d[y * fw + x] = data[y * width + f * fw + x] }
            }
            out.append(Sprite(width: fw, height: height, data: d))
        }
        return out
    }

    /// A copy with palette index `from` replaced by `to` (palette swaps for enemies, team colours...).
    public func recolored(_ from: Int, _ to: Int) -> Sprite {
        var d = data
        let f = Canvas.col(from)
        let t = Canvas.col(to)
        for i in 0..<d.count where d[i] == f { d[i] = t }
        return Sprite(width: width, height: height, data: d)
    }
}

enum Font {
    static let source: [Character: String] = [
        "A": ".#./#.#/###/#.#/#.#", "B": "##./#.#/##./#.#/##.", "C": ".##/#../#../#../.##",
        "D": "##./#.#/#.#/#.#/##.", "E": "###/#../##./#../###", "F": "###/#../##./#../#..",
        "G": ".##/#../#.#/#.#/.##", "H": "#.#/#.#/###/#.#/#.#", "I": "###/.#./.#./.#./###",
        "J": "..#/..#/..#/#.#/.#.", "K": "#.#/#.#/##./#.#/#.#", "L": "#../#../#../#../###",
        "M": "#.#/###/###/#.#/#.#", "N": "##./#.#/#.#/#.#/#.#", "O": ".#./#.#/#.#/#.#/.#.",
        "P": "##./#.#/##./#../#..", "Q": ".#./#.#/#.#/##./.##", "R": "##./#.#/##./#.#/#.#",
        "S": ".##/#../.#./..#/##.", "T": "###/.#./.#./.#./.#.", "U": "#.#/#.#/#.#/#.#/###",
        "V": "#.#/#.#/#.#/#.#/.#.", "W": "#.#/#.#/###/###/#.#", "X": "#.#/#.#/.#./#.#/#.#",
        "Y": "#.#/#.#/.#./.#./.#.", "Z": "###/..#/.#./#../###",
        "0": "###/#.#/#.#/#.#/###", "1": ".#./##./.#./.#./###", "2": "##./..#/.#./#../###",
        "3": "##./..#/.#./..#/##.", "4": "#.#/#.#/###/..#/..#", "5": "###/#../##./..#/##.",
        "6": ".##/#../###/#.#/###", "7": "###/..#/.#./.#./.#.", "8": "###/#.#/###/#.#/###",
        "9": "###/#.#/###/..#/##.",
        ".": ".../.../.../.../.#.", ",": ".../.../.../.#./#..", ":": ".../.#./.../.#./...",
        "!": ".#./.#./.#./.../.#.", "?": "##./..#/.#./.../.#.", "-": ".../.../###/.../...",
        "+": ".../.#./###/.#./...", "/": "..#/..#/.#./#../#..", "'": ".#./.#./.../.../...",
        "(": ".#./#../#../#../.#.", ")": ".#./..#/..#/..#/.#.", "%": "#.#/..#/.#./#../#.#",
        "*": "#.#/.#./###/.#./#.#", "=": ".../###/.../###/...", "<": "..#/.#./#../.#./..#",
        ">": "#../.#./..#/.#./#..", "_": ".../.../.../.../###", " ": ".../.../.../.../..."
    ]

    static let table: [Character: UInt16] = {
        var t: [Character: UInt16] = [:]
        for (key, value) in source {
            var bits: UInt16 = 0
            var i = 0
            for ch in value where ch != "/" {
                if ch == "#" { bits |= UInt16(1) << UInt16(14 - i) }
                i += 1
            }
            t[key] = bits
        }
        return t
    }()

    static func glyph(_ ch: Character) -> UInt16 {
        if let g = table[ch] { return g }
        return table["?"] ?? 0
    }
}
