import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 255) / 255
        let g = Double((hex >> 8) & 255) / 255
        let b = Double(hex & 255) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

/// Console body colours.
enum ShellColor: String, CaseIterable, Identifiable {
    case classic, grape, banana, teal, cherry, midnight

    var id: String { rawValue }

    var name: String {
        switch self {
        case .classic: return "Dust Gray"
        case .grape: return "Grape"
        case .banana: return "Banana"
        case .teal: return "Lagoon"
        case .cherry: return "Cherry"
        case .midnight: return "Midnight"
        }
    }

    var body: Color {
        switch self {
        case .classic: return Color(hex: 0xCCC8BE)
        case .grape: return Color(hex: 0x6C45A8)
        case .banana: return Color(hex: 0xEBCB2E)
        case .teal: return Color(hex: 0x2BA59C)
        case .cherry: return Color(hex: 0xC8283A)
        case .midnight: return Color(hex: 0x2B2E3C)
        }
    }

    var bodyShade: Color {
        switch self {
        case .classic: return Color(hex: 0xA9A59B)
        case .grape: return Color(hex: 0x4E2F82)
        case .banana: return Color(hex: 0xC4A41A)
        case .teal: return Color(hex: 0x1D7F78)
        case .cherry: return Color(hex: 0x9C1A2A)
        case .midnight: return Color(hex: 0x1A1C27)
        }
    }

    var accent: Color {
        switch self {
        case .classic: return Color(hex: 0x9E1F5C)
        case .grape: return Color(hex: 0xF0D84A)
        case .banana: return Color(hex: 0x2A64A8)
        case .teal: return Color(hex: 0xE04A8C)
        case .cherry: return Color(hex: 0xF4EFE2)
        case .midnight: return Color(hex: 0x5CC8C8)
        }
    }

    /// Colour for printed labels on the body.
    var ink: Color {
        switch self {
        case .classic, .banana: return Color(hex: 0x3A3A8C)
        case .grape, .teal, .cherry, .midnight: return Color.white.opacity(0.85)
        }
    }
}

enum Retro {
    static func font(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        return .system(size: size, weight: weight, design: .monospaced)
    }
    static let background = Color(hex: 0x15171E)
    static let card = Color(hex: 0x23262F)
}
