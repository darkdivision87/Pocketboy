# Writing a PocketBoy cartridge

A cartridge is one Swift file in `Sources/PocketCore/Games/` containing a `Game` subclass and a
`Cartridge` registration. Read `Games/PocketPong.swift` first; it is the reference.

## Pixel carts (Game Boy / Game Boy Color era): 160x144, indexed colour

* Subclass `Game`. `update(_ input: InputState)` runs at a fixed 60 Hz, then `draw(_ c: Canvas)`.
* `Canvas` pixels are palette indices 0...31 (anything else is masked with `& 31`). All drawing is clipped.
  Index 0 is what the console clears to before `draw`; call `c.clear(n)` yourself if you want another background.
* `override var palette: [UInt16]` returns up to 32 colours made with `Palette.make([0xRRGGBB, ...])`.
  It is converted to 15-bit colour (Color mode) or to four shades by **luminance** (Classic mode):
  Y < 64 darkest, < 128 dark, < 192 light, otherwise lightest (Y = 0.299R + 0.587G + 0.114B).
  **Design for both**: anything that must be distinguishable in Classic mode (player vs background,
  enemy vs floor, HUD text vs backdrop) needs a different luminance band, not just a different hue.
  Pick backgrounds either clearly light (Y >= 192) or clearly dark (Y < 64) and keep foreground outlines on the other side.
  The palette can change per level (return a different array).
* Sprites: `Sprite(["..0110..", ...])`. `.`/space transparent, `0-9` = index 0-9, `a-v` = index 10-31.
  Define them once as `static let` (never rebuild every frame). `canvas.draw(sprite, x, y, flipX:, flipY:, solid:)`,
  `sprite.frames(n)` splits a wide strip, `sprite.recolored(from, to)`.
* Primitives: `fillRect strokeRect hline vline line fillCircle strokeCircle setPixel fillChecker`.
  Text: built-in 3x5 font, 4 px advance, upper-case, digits and `. , : ! ? - + / ' ( ) % * = < > _`:
  `text(_:_:_:_:scale:)`, `textCentered(_:y:_:scale:)`, `textWidth`, `outlinedText`.
* `canvas.cameraX/cameraY` are subtracted from all coordinates (scrolling). Reset to 0 before drawing the HUD.
* Input: `input.held`, `input.pressed` (first frame only), `input.dx`, `input.dy`, `input.aPressed`, `input.startPressed`...
  Buttons: D-pad, A, B, Start, Select. Handle Start as pause if the game wants one (the app has its own menu button too).
* Sound: `play(.jump)` (see `Sfx` in Audio.swift), `playMusic(Tunes.adventure)` from `start()` (not from `init`).
  `Tune(bpm:wave:volume:"C5:1 E5:0.5 R:0.5")` for custom tunes.
* `override var score: Int` feeds the high-score board; return a running score.
* Random: `var rng = Rng()` as a stored property; `rng.int(n)`, `rng.range(lo, hi)`, `rng.chance(percent)`.
* Helpers: `Box` (intersects), `clamp`, `zeroPad`.

## 64 carts: 320x288, true colour

Set `era: .n64` in the `Cartridge`. Override `drawTrueColor(_ b: TrueColorBuffer)` instead of `draw`.
Colours are `TrueColorBuffer.rgb(r, g, b)` (0...255). Use `b.withPixels { ptr, w, h in ... }` for per-pixel renderers
(floor/ray casters), and keep per-frame cost low (about 92k pixels). Classic mode converts the frame to four dithered shades automatically.

## Registering

At the bottom of the file:

```swift
extension Cartridge {
    static let myGame = Cartridge(id: "mygame", title: "MY GAME", genre: "Puzzle",
        blurb: "One or two sentences.", controls: "D-PAD move, A jump.", era: .gbc,
        labelTop: 0x5C9A6E, labelBottom: 0x1E4A38, factory: { MyGame() })
}
```

then add `.myGame` to `Library.all`. Titles are upper case, 20 characters or fewer.

## Rules that keep it crash-free (there is no compiler in the authoring environment, so be conservative)

* Pure Swift + Foundation only. No UIKit/SwiftUI, no `print`, no files, no networking, no timers/threads.
* Never trap: guard every array index, never divide by zero, avoid `Int(someFloat)` on huge/NaN values (clamp first),
  use `&+` style wrapping only when intended, don't force-unwrap.
* Keep expressions simple and explicitly typed (`Float(x)`, `Int(f)`); no mixed Int/Float arithmetic; no clever generics, result builders or long chained ternaries (the type checker times out).
* Nest helper types inside your game class (or make them `private`) so names never collide with other files.
* Every game must be playable immediately, show a title/instruction state or start playing right away,
  handle game over and restart (A or Start), and keep some score.
* State must reset cleanly (a fresh instance is created each time a cartridge is inserted).
