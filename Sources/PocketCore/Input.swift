#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// The eight Game Boy buttons.
public struct Buttons: OptionSet, Hashable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let up = Buttons(rawValue: 1 << 0)
    public static let down = Buttons(rawValue: 1 << 1)
    public static let left = Buttons(rawValue: 1 << 2)
    public static let right = Buttons(rawValue: 1 << 3)
    public static let a = Buttons(rawValue: 1 << 4)
    public static let b = Buttons(rawValue: 1 << 5)
    public static let start = Buttons(rawValue: 1 << 6)
    public static let select = Buttons(rawValue: 1 << 7)
}

/// Per-frame input handed to a game. `pressed` is only set on the first frame a button goes down.
public struct InputState {
    public var held: Buttons = []
    public var pressed: Buttons = []
    public var released: Buttons = []

    public init() {}

    public mutating func advance(to new: Buttons) {
        pressed = new.subtracting(held)
        released = held.subtracting(new)
        held = new
    }

    public var left: Bool { held.contains(.left) }
    public var right: Bool { held.contains(.right) }
    public var up: Bool { held.contains(.up) }
    public var down: Bool { held.contains(.down) }
    public var a: Bool { held.contains(.a) }
    public var b: Bool { held.contains(.b) }
    public var start: Bool { held.contains(.start) }
    public var select: Bool { held.contains(.select) }

    public var leftPressed: Bool { pressed.contains(.left) }
    public var rightPressed: Bool { pressed.contains(.right) }
    public var upPressed: Bool { pressed.contains(.up) }
    public var downPressed: Bool { pressed.contains(.down) }
    public var aPressed: Bool { pressed.contains(.a) }
    public var bPressed: Bool { pressed.contains(.b) }
    public var startPressed: Bool { pressed.contains(.start) }
    public var selectPressed: Bool { pressed.contains(.select) }
    public var aReleased: Bool { released.contains(.a) }
    public var bReleased: Bool { released.contains(.b) }

    /// -1, 0 or 1 from the D-pad.
    public var dx: Int { (right ? 1 : 0) - (left ? 1 : 0) }
    public var dy: Int { (down ? 1 : 0) - (up ? 1 : 0) }
    /// True if any button went down this frame.
    public var anyPressed: Bool { !pressed.isEmpty }
}
