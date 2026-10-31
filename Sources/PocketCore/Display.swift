import Foundation

/// The four-colour LCD tints available in Classic (2-bit) mode.
public enum DMGTint: String, CaseIterable, Identifiable {
    case classic, pocket, light, amber

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .classic: return "Classic Green"
        case .pocket: return "Pocket Gray"
        case .light: return "Backlit Teal"
        case .amber: return "Amber"
        }
    }

    /// Four colours, lightest to darkest, as 0xRRGGBB.
    public var shades: [UInt32] {
        switch self {
        case .classic: return [0xC4D68B, 0x8FAE5B, 0x4F7348, 0x24402E]
        case .pocket: return [0xD4D8C8, 0xA0A598, 0x62665C, 0x24261F]
        case .light: return [0xCFF2E4, 0x8CCBB6, 0x3D8A7C, 0x123A3A]
        case .amber: return [0xFFE9A8, 0xF0B24C, 0xB4601C, 0x3C1A0A]
        }
    }
}

/// `color == false` is the original 2-bit, four-shade handheld look. `color == true` is 15-bit (32,768 colours) Game Boy Color style.
public struct DisplayMode: Equatable {
    public var color: Bool
    public var tint: DMGTint

    public init(color: Bool = true, tint: DMGTint = .classic) {
        self.color = color
        self.tint = tint
    }
}

/// Colour helpers. Palettes are arrays of up to 32 RGB555 values (bits 0-4 red, 5-9 green, 10-14 blue), like the Game Boy Color.
public enum Palette {
    /// Builds a 32-entry RGB555 palette from 0xRRGGBB values. Missing entries are black.
    public static func make(_ hex: [UInt32]) -> [UInt16] {
        var out = [UInt16](repeating: 0, count: 32)
        for (i, h) in hex.enumerated() where i < 32 {
            let r = Int((h >> 16) & 255)
            let g = Int((h >> 8) & 255)
            let b = Int(h & 255)
            out[i] = rgb555(r, g, b)
        }
        return out
    }

    public static func rgb555(_ r8: Int, _ g8: Int, _ b8: Int) -> UInt16 {
        let r = (max(0, min(255, r8)) * 31 + 127) / 255
        let g = (max(0, min(255, g8)) * 31 + 127) / 255
        let b = (max(0, min(255, b8)) * 31 + 127) / 255
        return UInt16(r) | (UInt16(g) << 5) | (UInt16(b) << 10)
    }

    public static let standard: [UInt16] = make([
        0xE8F0D0, 0xA8C890, 0x60A070, 0x203830, 0xE03030, 0xF0B030, 0x3060D0, 0x40B040,
        0xFFFFFF, 0x000000, 0x808080, 0xC0C0C0
    ])
}

enum Display {
    @inline(__always) static func pack(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
        return UInt32(r & 255) | (UInt32(g & 255) << 8) | (UInt32(b & 255) << 16) | 0xFF00_0000
    }

    static func packHex(_ hex: UInt32) -> UInt32 {
        return pack(Int((hex >> 16) & 255), Int((hex >> 8) & 255), Int(hex & 255))
    }

    @inline(__always) static func expand5(_ v: Int) -> Int { return (v << 3) | (v >> 2) }

    @inline(__always) static func luma(_ r: Int, _ g: Int, _ b: Int) -> Int {
        return (r * 299 + g * 587 + b * 114) / 1000
    }

    /// 0 = lightest ... 3 = darkest
    @inline(__always) static func shade(_ y: Int) -> Int {
        if y < 64 { return 3 }
        if y < 128 { return 2 }
        if y < 192 { return 1 }
        return 0
    }

    static func lookup(palette: [UInt16], mode: DisplayMode) -> [UInt32] {
        var out = [UInt32](repeating: 0xFF00_0000, count: 32)
        var shades: [UInt32] = []
        for h in mode.tint.shades { shades.append(packHex(h)) }
        for i in 0..<32 {
            let c: UInt16 = i < palette.count ? palette[i] : 0
            let r = expand5(Int(c & 31))
            let g = expand5(Int((c >> 5) & 31))
            let b = expand5(Int((c >> 10) & 31))
            if mode.color {
                out[i] = pack(r, g, b)
            } else {
                out[i] = shades[shade(luma(r, g, b))]
            }
        }
        return out
    }

    static func convert(canvas: Canvas, palette: [UInt16], mode: DisplayMode, into frame: inout [UInt32]) {
        let lut = lookup(palette: palette, mode: mode)
        let n = min(frame.count, canvas.pixels.count)
        for i in 0..<n {
            frame[i] = lut[Int(canvas.pixels[i] & 31)]
        }
    }

    private static let bayer: [Int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

    static func convert(buffer: TrueColorBuffer, mode: DisplayMode, into frame: inout [UInt32]) {
        let n = min(frame.count, buffer.pixels.count)
        if mode.color {
            for i in 0..<n { frame[i] = buffer.pixels[i] | 0xFF00_0000 }
            return
        }
        var shades: [UInt32] = []
        for h in mode.tint.shades { shades.append(packHex(h)) }
        let w = buffer.width
        for i in 0..<n {
            let p = buffer.pixels[i]
            let r = Int(p & 255)
            let g = Int((p >> 8) & 255)
            let b = Int((p >> 16) & 255)
            let x = i % w
            let y = i / w
            let d = (bayer[(y & 3) * 4 + (x & 3)] - 8) * 5
            frame[i] = shades[shade(max(0, min(255, luma(r, g, b) + d)))]
        }
    }
}

/// A true-colour framebuffer used by the "64" cartridges (320x288). Pixels are packed 0xAABBGGRR; use `rgb(_:_:_:)`.
public final class TrueColorBuffer {
    public let width: Int
    public let height: Int
    public var pixels: [UInt32]

    public init(width: Int = 320, height: Int = 288) {
        self.width = width
        self.height = height
        self.pixels = [UInt32](repeating: 0xFF00_0000, count: width * height)
    }

    @inline(__always) public static func rgb(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
        return Display.pack(max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
    }

    public static func hex(_ h: UInt32) -> UInt32 {
        return Display.packHex(h)
    }

    public func clear(_ color: UInt32) {
        for i in 0..<pixels.count { pixels[i] = color }
    }

    public func setPixel(_ x: Int, _ y: Int, _ color: UInt32) {
        if x < 0 || y < 0 || x >= width || y >= height { return }
        pixels[y * width + x] = color
    }

    public func fillRect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: UInt32) {
        let x0 = max(0, x)
        let y0 = max(0, y)
        let x1 = min(width, x + w)
        let y1 = min(height, y + h)
        if x0 >= x1 || y0 >= y1 { return }
        for yy in y0..<y1 {
            let base = yy * width
            for xx in x0..<x1 { pixels[base + xx] = color }
        }
    }

    public func textWidth(_ s: String, scale: Int = 1) -> Int {
        return s.isEmpty ? 0 : (s.count * 4 - 1) * scale
    }

    public func text(_ s: String, _ x: Int, _ y: Int, _ color: UInt32, scale: Int = 1) {
        var cx = x
        for ch in s.uppercased() {
            let g = Font.glyph(ch)
            if g != 0 {
                for row in 0..<5 {
                    for col in 0..<3 {
                        if (g >> UInt16(14 - (row * 3 + col))) & 1 == 1 {
                            fillRect(cx + col * scale, y + row * scale, scale, scale, color)
                        }
                    }
                }
            }
            cx += 4 * scale
        }
    }

    public func textCentered(_ s: String, y: Int, _ color: UInt32, scale: Int = 1) {
        text(s, (width - textWidth(s, scale: scale)) / 2, y, color, scale: scale)
    }

    /// Fast raw access for per-pixel renderers.
    public func withPixels(_ body: (UnsafeMutablePointer<UInt32>, Int, Int) -> Void) {
        let w = width
        let h = height
        pixels.withUnsafeMutableBufferPointer { buf in
            if let base = buf.baseAddress { body(base, w, h) }
        }
    }
}
