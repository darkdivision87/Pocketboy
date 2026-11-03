#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

public enum Wave {
    case pulse12, pulse25, pulse50, triangle, noise
}

/// Built-in sound effects. Games call `play(.coin)` etc.
public enum Sfx: CaseIterable {
    case blip, select, confirm, jump, coin, powerup, stomp, hit, hurt, death, shoot, laser
    case explosion, lineClear, drop, win, lose, bounce, step, pause, sword, pickup, thud
    case countdown, boot

    struct Note {
        let freq: Float
        let dur: Float
        let wave: Wave
        let vol: Float
        let slide: Float
    }

    private static func n(_ f: Float, _ d: Float, _ w: Wave = .pulse50, _ v: Float = 0.5, slide: Float = 0) -> Note {
        return Note(freq: f, dur: d, wave: w, vol: v, slide: slide)
    }

    var notes: [Note] {
        switch self {
        case .blip: return [Sfx.n(880, 0.03)]
        case .select: return [Sfx.n(660, 0.04), Sfx.n(880, 0.05)]
        case .confirm: return [Sfx.n(523, 0.05), Sfx.n(784, 0.05), Sfx.n(1046, 0.1)]
        case .jump: return [Sfx.n(300, 0.14, .pulse25, 0.5, slide: 2200)]
        case .coin: return [Sfx.n(988, 0.05), Sfx.n(1319, 0.25)]
        case .powerup:
            return [Sfx.n(392, 0.06), Sfx.n(523, 0.06), Sfx.n(659, 0.06), Sfx.n(784, 0.06), Sfx.n(1046, 0.06), Sfx.n(1319, 0.12)]
        case .stomp: return [Sfx.n(260, 0.08, .pulse50, 0.6, slide: -1800)]
        case .hit: return [Sfx.n(3000, 0.08, .noise, 0.5, slide: -9000)]
        case .hurt: return [Sfx.n(300, 0.1, .pulse25, 0.5, slide: -1500), Sfx.n(2500, 0.12, .noise, 0.5, slide: -9000)]
        case .death: return [Sfx.n(440, 0.1), Sfx.n(392, 0.1), Sfx.n(330, 0.1), Sfx.n(262, 0.35, .pulse50, 0.5, slide: -300)]
        case .shoot: return [Sfx.n(1300, 0.1, .pulse12, 0.4, slide: -9000)]
        case .laser: return [Sfx.n(2200, 0.14, .pulse25, 0.4, slide: -12000)]
        case .explosion: return [Sfx.n(4500, 0.45, .noise, 0.7, slide: -9500)]
        case .lineClear: return [Sfx.n(523, 0.06), Sfx.n(659, 0.06), Sfx.n(784, 0.06), Sfx.n(1046, 0.16)]
        case .drop: return [Sfx.n(150, 0.06, .triangle, 0.8)]
        case .win: return [Sfx.n(523, 0.12), Sfx.n(523, 0.12), Sfx.n(523, 0.12), Sfx.n(659, 0.2), Sfx.n(784, 0.4)]
        case .lose: return [Sfx.n(392, 0.18), Sfx.n(370, 0.18), Sfx.n(349, 0.18), Sfx.n(330, 0.5, .pulse50, 0.5, slide: -80)]
        case .bounce: return [Sfx.n(500, 0.07, .pulse50, 0.4, slide: 3000)]
        case .step: return [Sfx.n(1000, 0.015, .noise, 0.2)]
        case .pause: return [Sfx.n(700, 0.05), Sfx.n(500, 0.08)]
        case .sword: return [Sfx.n(9000, 0.09, .noise, 0.4, slide: -4000)]
        case .pickup: return [Sfx.n(700, 0.04), Sfx.n(1400, 0.1)]
        case .thud: return [Sfx.n(110, 0.12, .triangle, 0.9, slide: -400)]
        case .countdown: return [Sfx.n(440, 0.12)]
        case .boot: return [Sfx.n(1046, 0.12), Sfx.n(2093, 0.55, .pulse50, 0.4)]
        }
    }
}

public struct TuneNote {
    public let midi: Int
    public let beats: Float
}

/// A looping melody. Write it as text: "C5:1 E5:0.5 R:0.5 G5:2" (note, octave, ':' beats; R is a rest; '#'/'b' accidentals).
public struct Tune {
    public let bpm: Float
    public let wave: Wave
    public let volume: Float
    public let notes: [TuneNote]

    public init(bpm: Float, wave: Wave = .pulse25, volume: Float = 0.16, _ score: String) {
        var list: [TuneNote] = []
        for token in score.split(separator: " ") {
            let parts = token.split(separator: ":")
            guard let nameSub = parts.first else { continue }
            var beats: Float = 1
            if parts.count > 1, let b = Float(String(parts[1])) { beats = b }
            let chars = Array(String(nameSub))
            if chars.isEmpty { continue }
            if chars[0] == "R" {
                list.append(TuneNote(midi: 0, beats: beats))
                continue
            }
            var semi = 0
            switch chars[0] {
            case "C": semi = 0
            case "D": semi = 2
            case "E": semi = 4
            case "F": semi = 5
            case "G": semi = 7
            case "A": semi = 9
            case "B": semi = 11
            default: continue
            }
            var idx = 1
            if idx < chars.count && chars[idx] == "#" { semi += 1; idx += 1 }
            else if idx < chars.count && chars[idx] == "b" { semi -= 1; idx += 1 }
            guard idx < chars.count, let oct = Int(String(chars[idx])) else { continue }
            list.append(TuneNote(midi: 12 * (oct + 1) + semi, beats: beats))
        }
        self.bpm = bpm
        self.wave = wave
        self.volume = volume
        self.notes = list
    }
}

/// A handful of original looping tunes cartridges can pick from.
public enum Tunes {
    public static let adventure = Tune(bpm: 150, wave: .pulse25, "C5:0.5 E5:0.5 G5:0.5 E5:0.5 A5:1 G5:1 F5:0.5 A5:0.5 G5:0.5 E5:0.5 D5:1 R:1 E5:0.5 G5:0.5 C6:0.5 G5:0.5 B5:1 A5:1 G5:0.5 E5:0.5 F5:0.5 D5:0.5 C5:2 R:1")
    public static let desert = Tune(bpm: 110, wave: .pulse50, volume: 0.14, "A4:1 B4:0.5 C5:0.5 D#5:1.5 C5:0.5 B4:1 A4:1 R:0.5 E5:1 D#5:0.5 C5:0.5 B4:1.5 A4:0.5 G#4:2 R:1 A4:1 C5:0.5 E5:0.5 F5:1.5 E5:0.5 D#5:1 C5:1 B4:1 A4:3 R:1")
    public static let tense = Tune(bpm: 130, wave: .triangle, volume: 0.22, "E3:0.5 E3:0.5 G3:0.5 E3:0.5 A3:0.5 E3:0.5 B3:0.5 E3:0.5 E3:0.5 E3:0.5 G3:0.5 E3:0.5 F3:0.5 E3:0.5 D#3:0.5 E3:0.5")
    public static let chill = Tune(bpm: 100, wave: .triangle, volume: 0.2, "C4:2 E4:2 G4:2 E4:2 F4:2 A4:2 G4:2 E4:2 D4:2 F4:2 A4:2 F4:2 E4:2 G4:2 C5:4")
    public static let arcade = Tune(bpm: 168, wave: .pulse25, volume: 0.14, "G4:0.5 G4:0.5 D5:0.5 D5:0.5 E5:0.5 E5:0.5 D5:1 C5:0.5 C5:0.5 B4:0.5 B4:0.5 A4:0.5 A4:0.5 G4:1 D5:0.5 D5:0.5 C5:0.5 C5:0.5 B4:0.5 B4:0.5 A4:1 D5:0.5 D5:0.5 C5:0.5 C5:0.5 B4:0.5 B4:0.5 A4:1")
    public static let puzzle = Tune(bpm: 144, wave: .pulse50, volume: 0.13, "E5:1 B4:0.5 C5:0.5 D5:1 C5:0.5 B4:0.5 A4:1 A4:0.5 C5:0.5 E5:1 D5:0.5 C5:0.5 B4:1.5 C5:0.5 D5:1 E5:1 C5:1 A4:1 A4:1 R:1")
    public static let space = Tune(bpm: 140, wave: .pulse12, volume: 0.13, "A3:0.5 E4:0.5 A4:0.5 E4:0.5 A3:0.5 E4:0.5 A4:0.5 C5:0.5 G3:0.5 D4:0.5 G4:0.5 D4:0.5 G3:0.5 D4:0.5 G4:0.5 B4:0.5")
    public static let race = Tune(bpm: 176, wave: .pulse25, volume: 0.13, "E5:0.5 E5:0.5 R:0.5 E5:0.5 C5:0.5 E5:1 G5:1 G4:1 R:1 C5:0.5 R:0.5 G4:0.5 R:0.5 E4:1 A4:0.5 B4:0.5 A#4:0.5 A4:1")
}

/// A tiny four-voice-style chip synth: one effects voice plus one music voice.
/// `render` is safe to call from an audio thread; `trigger` and `setTune` from any thread.
public final class ChipSynth {
    private let lock = SimpleLock()
    private let rate: Float

    private var sfxNotes: [Sfx.Note] = []
    private var sfxIndex = 0
    private var sfxPhase: Float = 0
    private var sfxTimeLeft: Float = 0
    private var sfxFreq: Float = 0
    private var sfxNoiseOut: Float = 1

    private var tune: Tune?
    private var tuneIndex = 0
    private var tunePhase: Float = 0
    private var tuneTimeLeft: Float = 0
    private var tuneDur: Float = 0
    private var tuneFreq: Float = 0

    private var lfsr: UInt16 = 0x4A5B

    public var volume: Float = 0.5
    public var muted: Bool = false

    public init(sampleRate: Double = 44100) {
        rate = Float(sampleRate)
    }

    public func trigger(_ sfx: Sfx) {
        lock.lock()
        sfxNotes = sfx.notes
        sfxIndex = 0
        sfxPhase = 0
        if let first = sfxNotes.first {
            sfxTimeLeft = first.dur
            sfxFreq = first.freq
        }
        lock.unlock()
    }

    public func setTune(_ t: Tune?) {
        lock.lock()
        tune = t
        tuneIndex = 0
        tunePhase = 0
        tuneTimeLeft = 0
        tuneDur = 0
        lock.unlock()
    }

    public func render(_ out: UnsafeMutablePointer<Float>, frames: Int) {
        lock.lock()
        defer { lock.unlock() }
        for i in 0..<frames {
            var s: Float = 0
            if !muted {
                s = nextSfx() + nextMusic()
            }
            out[i] = max(-1, min(1, s * volume))
        }
    }

    private func osc(_ wave: Wave, _ phase: Float) -> Float {
        switch wave {
        case .pulse12: return phase < 0.125 ? 1 : -1
        case .pulse25: return phase < 0.25 ? 1 : -1
        case .pulse50: return phase < 0.5 ? 1 : -1
        case .triangle: return 4 * abs(phase - 0.5) - 1
        case .noise: return 0
        }
    }

    private func stepNoise() -> Float {
        let bit = (lfsr ^ (lfsr >> 1)) & 1
        lfsr = (lfsr >> 1) | (bit << 14)
        return (lfsr & 1) == 0 ? 1 : -1
    }

    private func nextSfx() -> Float {
        if sfxIndex >= sfxNotes.count { return 0 }
        let note = sfxNotes[sfxIndex]
        let env: Float = note.dur > 0 ? max(0, sfxTimeLeft / note.dur) : 0
        var sample: Float
        if note.wave == .noise {
            sfxPhase += sfxFreq / rate
            if sfxPhase >= 1 {
                sfxPhase -= 1
                sfxNoiseOut = stepNoise()
            }
            sample = sfxNoiseOut
        } else {
            sfxPhase += sfxFreq / rate
            if sfxPhase >= 1 { sfxPhase -= floor(sfxPhase) }
            sample = osc(note.wave, sfxPhase)
        }
        sample *= note.vol * (0.3 + 0.7 * env)
        sfxFreq = max(40, sfxFreq + note.slide / rate)
        sfxTimeLeft -= 1 / rate
        if sfxTimeLeft <= 0 {
            sfxIndex += 1
            if sfxIndex < sfxNotes.count {
                sfxTimeLeft = sfxNotes[sfxIndex].dur
                sfxFreq = sfxNotes[sfxIndex].freq
            }
        }
        return sample
    }

    private func nextMusic() -> Float {
        guard let t = tune, !t.notes.isEmpty else { return 0 }
        if tuneTimeLeft <= 0 {
            let note = t.notes[tuneIndex % t.notes.count]
            tuneIndex = (tuneIndex + 1) % t.notes.count
            tuneDur = note.beats * 60 / max(30, t.bpm)
            tuneTimeLeft = tuneDur
            tuneFreq = note.midi > 0 ? 440 * powf(2, Float(note.midi - 69) / 12) : 0
            tunePhase = 0
        }
        var sample: Float = 0
        if tuneFreq > 0 {
            tunePhase += tuneFreq / rate
            if tunePhase >= 1 { tunePhase -= floor(tunePhase) }
            let gate: Float = min(1, tuneTimeLeft / max(0.001, tuneDur) * 6)
            sample = osc(t.wave, tunePhase) * t.volume * gate
        }
        tuneTimeLeft -= 1 / rate
        return sample
    }
}

/// Minimal mutex so the engine does not need Foundation (which would bloat the WebAssembly build by tens of megabytes).
final class SimpleLock {
#if os(WASI)
    func lock() {}
    func unlock() {}
#else
    private let mutex: UnsafeMutablePointer<pthread_mutex_t>

    init() {
        mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
        pthread_mutex_init(mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(mutex)
        mutex.deallocate()
    }

    func lock() { pthread_mutex_lock(mutex) }
    func unlock() { pthread_mutex_unlock(mutex) }
#endif
}
