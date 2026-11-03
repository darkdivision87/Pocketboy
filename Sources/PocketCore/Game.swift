#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// Base class for every cartridge. Override `update`, `draw` (pixel carts) or `drawTrueColor` (64 carts).
/// `update` runs at a fixed 60 Hz; `draw` is called after each update.
public class Game {
    public var audio = AudioBus()

    public init() {}

    /// 32-entry RGB555 palette (see `Palette.make`). May change at runtime (e.g. per level).
    public var palette: [UInt16] { return Palette.standard }
    /// Current score, used for the high-score board.
    public var score: Int { return 0 }
    /// Called once when the console finishes booting and hands control to the cartridge.
    public func start() {}
    public func update(_ input: InputState) {}
    public func draw(_ canvas: Canvas) {}
    public func drawTrueColor(_ buffer: TrueColorBuffer) {}

    public func play(_ sfx: Sfx) { audio.play(sfx) }
    public func playMusic(_ tune: Tune?) { audio.setTune(tune) }
}

public final class AudioBus {
    public var onSfx: ((Sfx) -> Void)?
    public var onTune: ((Tune?) -> Void)?
    public init() {}
    public func play(_ sfx: Sfx) { onSfx?(sfx) }
    public func setTune(_ tune: Tune?) { onTune?(tune) }
}

/// Small deterministic-capable random generator (SplitMix64).
public struct Rng {
    var state: UInt64

    public init(seed: UInt64) { state = seed }
    public init() { state = UInt64.random(in: 1...UInt64.max) }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0..<n (0 if n <= 0)
    public mutating func int(_ n: Int) -> Int {
        if n <= 0 { return 0 }
        return Int(next() % UInt64(n))
    }

    /// lo...hi inclusive
    public mutating func range(_ lo: Int, _ hi: Int) -> Int {
        if hi <= lo { return lo }
        return lo + int(hi - lo + 1)
    }

    public mutating func chance(_ percent: Int) -> Bool { return int(100) < percent }

    /// 0..<1
    public mutating func unit() -> Double { return Double(next() >> 11) / Double(1 << 53) }
}

/// Integer rectangle helper for collisions.
public struct Box {
    public var x: Int
    public var y: Int
    public var w: Int
    public var h: Int

    public init(_ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }

    public func intersects(_ o: Box) -> Bool {
        return x < o.x + o.w && o.x < x + w && y < o.y + o.h && o.y < y + h
    }

    public func contains(_ px: Int, _ py: Int) -> Bool {
        return px >= x && py >= y && px < x + w && py < y + h
    }
}

/// 42 -> "00042"
public func zeroPad(_ n: Int, _ digits: Int) -> String {
    var s = String(max(0, n))
    while s.count < digits { s = "0" + s }
    return s
}

@inline(__always) public func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T {
    return min(max(v, lo), hi)
}
