import Foundation

/// The virtual handheld. Insert a cartridge, call `tick` every display refresh, read `frame` to present.
public final class Console {
    public static let bootFrames = 150

    public let audio = AudioBus()
    public var mode = DisplayMode() {
        didSet { redraw() }
    }
    public private(set) var cartridge: Cartridge?
    public private(set) var screenWidth = 160
    public private(set) var screenHeight = 144
    /// Packed RGBA pixels (R in the low byte), `screenWidth * screenHeight` long.
    public private(set) var frame: [UInt32]
    public private(set) var frameCount = 0
    /// Increments every time `frame` is rewritten; presenters compare it to skip identical frames.
    public private(set) var renderCount = 0
    public private(set) var score = 0
    public private(set) var isBooting = false
    public var highScores: [String: Int] = [:]
    public var onHighScoresChanged: (([String: Int]) -> Void)?

    private var game: Game?
    private var boot: Game?
    private var bootCounter = 0
    private let canvas = Canvas()
    private let truecolor = TrueColorBuffer()
    private var input = InputState()
    private var accumulator: Double = 0
    private var scoresDirty = false
    private static let stepLength = 1.0 / 60.0

    public init() {
        frame = [UInt32](repeating: 0xFF00_0000, count: 160 * 144)
    }

    public func insert(_ cart: Cartridge) {
        eject()
        cartridge = cart
        let g = cart.make()
        g.audio = audio
        game = g
        let b = BootGame()
        b.audio = audio
        boot = b
        bootCounter = 0
        isBooting = true
        input = InputState()
        accumulator = 0
        score = 0
        frameCount = 0
        resize(160, 144)
        b.start()
        redraw()
    }

    public func eject() {
        audio.setTune(nil)
        if scoresDirty {
            scoresDirty = false
            onHighScoresChanged?(highScores)
        }
        game = nil
        boot = nil
        cartridge = nil
        isBooting = false
    }

    /// Advances emulation by `dt` seconds of wall time using a fixed 60 Hz step.
    public func tick(dt: Double, buttons: Buttons) {
        accumulator += min(max(dt, 0), 0.1)
        var steps = 0
        while accumulator >= Console.stepLength - 0.0005 && steps < 4 {
            step(buttons: buttons)
            accumulator -= Console.stepLength
            steps += 1
        }
        if accumulator < 0 { accumulator = 0 }
        if steps == 4 { accumulator = 0 }
    }

    /// One 60 Hz frame (also used by tests).
    public func step(buttons: Buttons) {
        input.advance(to: buttons)
        frameCount += 1
        if let b = boot {
            b.update(input)
            bootCounter += 1
            if bootCounter >= Console.bootFrames {
                boot = nil
                isBooting = false
                game?.start()
            }
        } else if let g = game {
            g.update(input)
            score = g.score
            if let id = cartridge?.id, score > (highScores[id] ?? 0) {
                highScores[id] = score
                scoresDirty = true
            }
        }
        render()
    }

    /// Re-renders the current frame (after a display mode change or while paused).
    public func redraw() {
        render()
    }

    public func flushHighScores() {
        if scoresDirty {
            scoresDirty = false
            onHighScoresChanged?(highScores)
        }
    }

    private func resize(_ w: Int, _ h: Int) {
        if w != screenWidth || h != screenHeight || frame.count != w * h {
            screenWidth = w
            screenHeight = h
            frame = [UInt32](repeating: 0xFF00_0000, count: w * h)
        }
    }

    private func render() {
        renderCount += 1
        if let b = boot {
            renderPixels(b)
            return
        }
        guard let g = game, let c = cartridge else { return }
        if c.kind == .sixtyFour {
            resize(320, 288)
            g.drawTrueColor(truecolor)
            Display.convert(buffer: truecolor, mode: mode, into: &frame)
        } else {
            renderPixels(g)
        }
    }

    private func renderPixels(_ g: Game) {
        resize(160, 144)
        canvas.cameraX = 0
        canvas.cameraY = 0
        canvas.clear(0)
        g.draw(canvas)
        Display.convert(canvas: canvas, palette: g.palette, mode: mode, into: &frame)
    }
}

/// The power-on logo drop.
final class BootGame: Game {
    private var t = 0
    private static let pal = Palette.make([
        0xE8F0D0, 0xA0C080, 0x508060, 0x203830, 0xD02828, 0xC06010, 0x2E8B2E, 0x2060C0, 0x7030C0, 0xC03080, 0x105060, 0x805020
    ])

    override var palette: [UInt16] { return BootGame.pal }

    override func update(_ input: InputState) {
        t += 1
        if t == 72 { play(.boot) }
    }

    override func draw(_ c: Canvas) {
        c.clear(0)
        let landing = 58
        let y = min(landing, -8 + t)
        let title = "POCKETBOY"
        let x = (160 - c.textWidth(title, scale: 2)) / 2
        var cx = x
        var i = 0
        for ch in title {
            c.text(String(ch), cx, y, 4 + (i % 8), scale: 2)
            cx += 8
            i += 1
        }
        if t > 72 {
            c.textCentered("PIXEL SYSTEM", y: y + 16, 3)
            c.hline(x, y + 24, c.textWidth(title, scale: 2), 2)
        }
    }
}
