#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// Metadata plus a factory for one game.
public struct Cartridge: Identifiable, Hashable {
    public enum Era: String, CaseIterable {
        case gb = "GB"
        case gbc = "GBC"
        case n64 = "64"

        public var fullName: String {
            switch self {
            case .gb: return "Game Boy"
            case .gbc: return "Game Boy Color"
            case .n64: return "Pocket 64"
            }
        }
    }

    public enum Kind { case pixel, sixtyFour }

    public let id: String
    public let title: String
    public let genre: String
    public let blurb: String
    public let controls: String
    public let era: Era
    /// Label gradient, 0xRRGGBB.
    public let labelTop: UInt32
    public let labelBottom: UInt32
    let factory: () -> Game

    init(id: String, title: String, genre: String, blurb: String, controls: String, era: Era,
         labelTop: UInt32, labelBottom: UInt32, factory: @escaping () -> Game) {
        self.id = id
        self.title = title
        self.genre = genre
        self.blurb = blurb
        self.controls = controls
        self.era = era
        self.labelTop = labelTop
        self.labelBottom = labelBottom
        self.factory = factory
    }

    public var kind: Kind { return era == .n64 ? .sixtyFour : .pixel }

    func make() -> Game { return factory() }

    public static func == (lhs: Cartridge, rhs: Cartridge) -> Bool { return lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
