import XCTest
@testable import PocketCore

final class PocketCoreTests: XCTestCase {
    func testSpriteParsing() {
        let s = Sprite(["01.", "a.v"])
        XCTAssertEqual(s.width, 3)
        XCTAssertEqual(s.height, 2)
        XCTAssertEqual(s.data[0], 0)
        XCTAssertEqual(s.data[1], 1)
        XCTAssertEqual(s.data[2], Sprite.clear)
        XCTAssertEqual(s.data[3], 10)
        XCTAssertEqual(s.data[5], 31)
        XCTAssertEqual(s.flippedX().data[0], Sprite.clear)
    }

    func testCanvasClipsSafely() {
        let c = Canvas()
        c.fillRect(-50, -50, 400, 400, 3)
        c.fillRect(Int.max / 4, 5, 10, 10, 2)
        c.line(-100, -100, 500, 500, 1)
        c.fillCircle(80, 72, 200, 4)
        c.strokeCircle(-30, 400, 90, 5)
        c.text("HELLO, WORLD! 0123456789 ~", -3, 140, 6, scale: 3)
        c.draw(Sprite(["12", "34"]), 159, 143, flipX: true, flipY: true)
        XCTAssertEqual(c.pixels.count, 160 * 144)
    }

    func testFontCoversAlphabet() {
        for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" {
            XCTAssertNotEqual(Font.glyph(ch), 0, "missing glyph \(ch)")
        }
    }

    func testTuneParsing() {
        let t = Tune(bpm: 120, "C4:1 R:0.5 F#5:2 Bb3:1 X9:1")
        XCTAssertEqual(t.notes.count, 4)
        XCTAssertEqual(t.notes[0].midi, 60)
        XCTAssertEqual(t.notes[1].midi, 0)
        XCTAssertEqual(t.notes[2].midi, 78)
        XCTAssertEqual(t.notes[3].midi, 58)
        for tune in [Tunes.adventure, Tunes.desert, Tunes.tense, Tunes.chill, Tunes.arcade, Tunes.puzzle, Tunes.space, Tunes.race] {
            XCTAssertGreaterThan(tune.notes.count, 4)
        }
    }

    func testSynthProducesFiniteAudio() {
        let synth = ChipSynth()
        synth.setTune(Tunes.adventure)
        var buffer = [Float](repeating: 0, count: 4096)
        var peak: Float = 0
        for sfx in Sfx.allCases {
            synth.trigger(sfx)
            buffer.withUnsafeMutableBufferPointer { p in
                synth.render(p.baseAddress!, frames: 4096)
            }
            for v in buffer {
                XCTAssertTrue(v.isFinite)
                peak = max(peak, abs(v))
            }
        }
        XCTAssertGreaterThan(peak, 0.01)
        XCTAssertLessThanOrEqual(peak, 1.0)
    }

    func testLibraryIsConsistent() {
        var ids = Set<String>()
        for cart in Library.all {
            XCTAssertTrue(ids.insert(cart.id).inserted, "duplicate id \(cart.id)")
            XCTAssertLessThanOrEqual(cart.title.count, 24, cart.title)
            XCTAssertFalse(cart.blurb.isEmpty)
            XCTAssertFalse(cart.controls.isEmpty)
        }
        XCTAssertGreaterThanOrEqual(Library.all.count, 1)
    }

    /// Plays every cartridge headlessly with three different input strategies.
    func testEveryCartridgeSurvivesPlay() {
        for cart in Library.all {
            for strategy in 0..<3 {
                let modes: [DisplayMode] = strategy == 0
                    ? [DisplayMode(color: true), DisplayMode(color: false, tint: .pocket)]
                    : [DisplayMode(color: true)]
                for mode in modes {
                    play(cart, strategy: strategy, mode: mode)
                }
            }
        }
    }

    private func play(_ cart: Cartridge, strategy: Int, mode: DisplayMode) {
        let console = Console()
        console.mode = mode
        console.insert(cart)
        var rng = Rng(seed: UInt64(1234 + strategy))
        var buttons: Buttons = []
        var seen = Set<UInt32>()
        let frames = cart.kind == .sixtyFour ? 900 : 2400
        for f in 0..<frames {
            switch strategy {
            case 0:
                if f % 9 == 0 { buttons = Buttons(rawValue: UInt8(rng.int(256))) }
            case 1:
                // mash A / Start, wander with the D-pad
                buttons = []
                if f % 6 < 3 { buttons.insert(.a) }
                if f % 40 < 3 { buttons.insert(.start) }
                if f % 60 < 20 { buttons.insert(.right) } else if f % 60 < 40 { buttons.insert(.up) } else { buttons.insert(.left) }
            default:
                // hold right + B, tap A, occasionally down
                buttons = [.right, .b]
                if f % 30 < 4 { buttons.insert(.a) }
                if f % 97 < 8 { buttons.insert(.down) }
            }
            console.step(buttons: buttons)
            if f > Console.bootFrames && f % 20 == 0 {
                var i = 0
                while i < console.frame.count {
                    seen.insert(console.frame[i])
                    i += 997
                }
            }
        }
        XCTAssertGreaterThan(seen.count, 1, "\(cart.id) rendered a flat frame")
        XCTAssertEqual(console.frame.count, console.screenWidth * console.screenHeight)
        XCTAssertGreaterThanOrEqual(console.score, 0, cart.id)
        console.eject()
    }
}
