import SwiftUI
import UIKit
import PocketCore

enum InputSource { case touch, pad, keys }

/// App-wide state: the console, settings, input merging and audio.
final class Hub: ObservableObject {
    let console = Console()
    let synth = ChipSynth()
    private var audioOut: AudioOutput?
    private var bridge: InputBridge?
    private let defaults = UserDefaults.standard
    private let impact = UIImpactFeedbackGenerator(style: .rigid)

    @Published var colorMode: Bool {
        didSet { defaults.set(colorMode, forKey: "colorMode"); applyMode() }
    }
    @Published var tint: DMGTint {
        didSet { defaults.set(tint.rawValue, forKey: "tint"); applyMode() }
    }
    @Published var lcdGrid: Bool {
        didSet { defaults.set(lcdGrid, forKey: "lcdGrid") }
    }
    @Published var soundOn: Bool {
        didSet { defaults.set(soundOn, forKey: "soundOn"); synth.muted = !soundOn }
    }
    @Published var haptics: Bool {
        didSet { defaults.set(haptics, forKey: "haptics") }
    }
    @Published var shell: ShellColor {
        didSet { defaults.set(shell.rawValue, forKey: "shell") }
    }
    @Published var active: Cartridge?
    @Published var menuOpen = false {
        didSet { menuChanged() }
    }
    @Published var highScores: [String: Int]

    private var sources: [InputSource: Buttons] = [:]
    private var touchState: Buttons = []
    private var held: Buttons = []
    private var latched: Buttons = []
    private var currentTune: Tune?

    init() {
        let d = UserDefaults.standard
        colorMode = d.object(forKey: "colorMode") as? Bool ?? true
        tint = DMGTint(rawValue: d.string(forKey: "tint") ?? "") ?? .classic
        lcdGrid = d.object(forKey: "lcdGrid") as? Bool ?? true
        soundOn = d.object(forKey: "soundOn") as? Bool ?? true
        haptics = d.object(forKey: "haptics") as? Bool ?? true
        shell = ShellColor(rawValue: d.string(forKey: "shell") ?? "") ?? .classic
        if let data = d.data(forKey: "highScores"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            highScores = decoded
        } else {
            highScores = [:]
        }

        synth.muted = !soundOn
        console.highScores = highScores
        console.audio.onSfx = { [weak self] sfx in self?.synth.trigger(sfx) }
        console.audio.onTune = { [weak self] tune in
            guard let self = self else { return }
            self.currentTune = tune
            self.synth.setTune(tune)
        }
        console.onHighScoresChanged = { [weak self] scores in
            guard let self = self else { return }
            self.highScores = scores
            if let data = try? JSONEncoder().encode(scores) {
                self.defaults.set(data, forKey: "highScores")
            }
        }
        applyMode()
        audioOut = AudioOutput(synth: synth)
        audioOut?.start()
        bridge = InputBridge(hub: self)
        impact.prepare()
    }

    private func applyMode() {
        console.mode = DisplayMode(color: colorMode, tint: tint)
    }

    // MARK: Cartridge lifecycle

    func insert(_ cart: Cartridge) {
        releaseAll()
        console.highScores = highScores
        console.insert(cart)
        menuOpen = false
        audioOut?.start()
        active = cart
    }

    func restart() {
        guard let cart = active else { return }
        releaseAll()
        console.insert(cart)
        menuOpen = false
    }

    func eject() {
        releaseAll()
        console.eject()
        menuOpen = false
        active = nil
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            audioOut?.start()
        case .inactive, .background:
            if active != nil { menuOpen = true }
            console.flushHighScores()
        @unknown default:
            break
        }
    }

    private func menuChanged() {
        if menuOpen {
            synth.setTune(nil)
            releaseAll()
        } else if active != nil {
            synth.setTune(currentTune)
        }
    }

    // MARK: Input

    func releaseAll() {
        touchState = []
        sources = [:]
        held = []
        latched = []
    }

    func touch(_ button: Buttons, down: Bool) {
        if down { touchState.formUnion(button) } else { touchState.subtract(button) }
        merge(touchState, from: .touch)
    }

    func touchDirection(_ direction: Buttons) {
        touchState.subtract([.up, .down, .left, .right])
        touchState.formUnion(direction)
        merge(touchState, from: .touch)
    }

    func set(_ buttons: Buttons, from source: InputSource) {
        merge(buttons, from: source)
    }

    private func merge(_ buttons: Buttons, from source: InputSource) {
        let old = held
        sources[source] = buttons
        var merged: Buttons = []
        for (_, value) in sources { merged.formUnion(value) }
        held = merged
        let newly = merged.subtracting(old)
        if !newly.isEmpty {
            latched.formUnion(newly)
            if source == .touch && haptics { impact.impactOccurred(intensity: 0.7) }
        }
    }

    /// Called by the display link on every refresh.
    func runFrame(dt: Double) {
        if menuOpen { return }
        let pressed = held.union(latched)
        latched = []
        console.tick(dt: dt, buttons: pressed)
    }
}
