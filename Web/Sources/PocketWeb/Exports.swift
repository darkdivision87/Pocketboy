import Foundation
import PocketCore

// All state lives in these globals; JavaScript talks to it through the pb_* exports below.
private var pbConsole = Console()
private var pbSynth = ChipSynth(sampleRate: 44100)
private let pbFrame = UnsafeMutablePointer<UInt32>.allocate(capacity: 320 * 288)
private let pbScratch = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
private let pbAudio = UnsafeMutablePointer<Float>.allocate(capacity: 8192)
private var pbLastCopied = -1
private var pbWired = false

private func wire() {
    if pbWired { return }
    pbWired = true
    pbConsole.audio.onSfx = { sfx in pbSynth.trigger(sfx) }
    pbConsole.audio.onTune = { tune in pbSynth.setTune(tune) }
}

private func syncFrame() {
    let rc = pbConsole.renderCount
    if rc == pbLastCopied { return }
    pbLastCopied = rc
    let n = min(pbConsole.frame.count, 320 * 288)
    pbConsole.frame.withUnsafeBufferPointer { src in
        if let base = src.baseAddress { pbFrame.update(from: base, count: n) }
    }
}

private func writeScratch(_ s: String) -> Int32 {
    var count = 0
    for b in s.utf8 {
        if count >= 4000 { break }
        pbScratch[count] = b
        count += 1
    }
    return Int32(count)
}

@_expose(wasm, "pb_init") @_cdecl("pb_init")
public func pb_init(_ sampleRate: Int32) {
    pbSynth = ChipSynth(sampleRate: Double(max(8000, sampleRate)))
    wire()
}

@_expose(wasm, "pb_set_rate") @_cdecl("pb_set_rate")
public func pb_set_rate(_ sampleRate: Int32) {
    let muted = pbSynth.muted
    pbSynth = ChipSynth(sampleRate: Double(max(8000, sampleRate)))
    pbSynth.muted = muted
    wire()
}

@_expose(wasm, "pb_cart_count") @_cdecl("pb_cart_count")
public func pb_cart_count() -> Int32 { return Int32(Library.all.count) }

/// field: 0 id, 1 title, 2 genre, 3 blurb, 4 controls, 5 era. Text is written to the scratch buffer; returns its byte length.
@_expose(wasm, "pb_cart_text") @_cdecl("pb_cart_text")
public func pb_cart_text(_ index: Int32, _ field: Int32) -> Int32 {
    let i = Int(index)
    if i < 0 || i >= Library.all.count { return 0 }
    let cart = Library.all[i]
    switch field {
    case 0: return writeScratch(cart.id)
    case 1: return writeScratch(cart.title)
    case 2: return writeScratch(cart.genre)
    case 3: return writeScratch(cart.blurb)
    case 4: return writeScratch(cart.controls)
    default: return writeScratch(cart.era.rawValue)
    }
}

/// which: 0 top colour, 1 bottom colour (0xRRGGBB)
@_expose(wasm, "pb_cart_label") @_cdecl("pb_cart_label")
public func pb_cart_label(_ index: Int32, _ which: Int32) -> Int32 {
    let i = Int(index)
    if i < 0 || i >= Library.all.count { return 0 }
    let cart = Library.all[i]
    return Int32(which == 0 ? cart.labelTop : cart.labelBottom)
}

@_expose(wasm, "pb_scratch") @_cdecl("pb_scratch")
public func pb_scratch() -> UnsafeMutablePointer<UInt8> { return pbScratch }

@_expose(wasm, "pb_frame_ptr") @_cdecl("pb_frame_ptr")
public func pb_frame_ptr() -> UnsafeMutablePointer<UInt32> { return pbFrame }

@_expose(wasm, "pb_audio_ptr") @_cdecl("pb_audio_ptr")
public func pb_audio_ptr() -> UnsafeMutablePointer<Float> { return pbAudio }

@_expose(wasm, "pb_insert") @_cdecl("pb_insert")
public func pb_insert(_ index: Int32) {
    let i = Int(index)
    if i < 0 || i >= Library.all.count { return }
    wire()
    pbConsole.insert(Library.all[i])
    syncFrame()
}

@_expose(wasm, "pb_eject") @_cdecl("pb_eject")
public func pb_eject() { pbConsole.eject() }

@_expose(wasm, "pb_tick") @_cdecl("pb_tick")
public func pb_tick(_ dtMs: Double, _ buttons: Int32) {
    pbConsole.tick(dt: dtMs / 1000.0, buttons: Buttons(rawValue: UInt8(truncatingIfNeeded: buttons)))
    syncFrame()
}

@_expose(wasm, "pb_set_mode") @_cdecl("pb_set_mode")
public func pb_set_mode(_ color: Int32, _ tint: Int32) {
    let tints = DMGTint.allCases
    let t = tints[min(max(Int(tint), 0), tints.count - 1)]
    pbConsole.mode = DisplayMode(color: color != 0, tint: t)
    syncFrame()
}

@_expose(wasm, "pb_width") @_cdecl("pb_width")
public func pb_width() -> Int32 { return Int32(pbConsole.screenWidth) }

@_expose(wasm, "pb_height") @_cdecl("pb_height")
public func pb_height() -> Int32 { return Int32(pbConsole.screenHeight) }

@_expose(wasm, "pb_render_count") @_cdecl("pb_render_count")
public func pb_render_count() -> Int32 { return Int32(truncatingIfNeeded: pbConsole.renderCount) }

@_expose(wasm, "pb_score") @_cdecl("pb_score")
public func pb_score() -> Int32 { return Int32(truncatingIfNeeded: min(pbConsole.score, 2_000_000_000)) }

@_expose(wasm, "pb_booting") @_cdecl("pb_booting")
public func pb_booting() -> Int32 { return pbConsole.isBooting ? 1 : 0 }

@_expose(wasm, "pb_set_muted") @_cdecl("pb_set_muted")
public func pb_set_muted(_ muted: Int32) { pbSynth.muted = muted != 0 }

/// Renders `frames` mono samples into the buffer returned by pb_audio_ptr.
@_expose(wasm, "pb_audio") @_cdecl("pb_audio")
public func pb_audio(_ frames: Int32) {
    let n = min(max(Int(frames), 0), 8192)
    pbSynth.render(pbAudio, frames: n)
}
