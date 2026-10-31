# PocketBoy

An iOS handheld-console app in the spirit of the original Game Boy, the Game Boy Color, and a "64" tier of true-color 3D carts.
Every game is original and runs on a built-in engine (no ROMs, no Nintendo assets).

## What is in the box

* A virtual console with a boot logo, on-screen D-pad / A / B / Start / Select, haptics, a chip-tune synth, and a pause menu.
* Hardware controller and keyboard support (arrows or WASD, X = A, Z = B, Return = Start, Right Shift = Select).
* Three display depths:
  * **Classic 2-bit**: four shades with selectable LCD tints (green, pocket gray, backlit teal, amber).
  * **Color 15-bit**: Game Boy Color style RGB555 palettes (32,768 colors).
  * **64 carts**: true-color 320x288 rendering (Mode-7 racing, textured raycasting); Classic mode dithers them to four shades.
* A cartridge shelf with filters, per-game high scores, and five console shell colors.

## Cartridges

See `Sources/PocketCore/Library.swift` for the live list. Highlights: a Mario-style platformer (Super Cappy Land),
a Prince-of-Persia-style cinematic platformer (Desert Prince), Brick Smash, Block Drop, Star Invaders, Rock Blaster,
Serpentine, Road Hopper, Maze Muncher, Cave Flap, Mine Sweeper, Crate Pusher, Tiny Quest, Turbo Lane,
and the 64 carts Kart Rally 64 and Dungeon 64.

## Build and run

Requirements: a Mac with Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
cd PocketBoy
xcodegen generate
open PocketBoy.xcodeproj
```

Pick an iPhone or iPad simulator (or your device, after choosing a signing team under Signing & Capabilities) and press Run.

The engine is a separate Swift package (`PocketCore`) with no UIKit dependency:

```sh
cd PocketBoy
swift test -c release -Xswiftc -enable-testing
```

The test suite plays every cartridge headlessly for thousands of frames with random and scripted input in both display modes.
GitHub Actions (`.github/workflows/pocketboy.yml`) runs the tests and a simulator build on every push.

## Adding a game

Read [`GAME_AUTHORING.md`](GAME_AUTHORING.md), copy `Games/PocketPong.swift`, and add your cartridge to `Library.all`.

## Status

The engine and games are covered by the headless smoke tests, but nobody has yet judged feel, difficulty, or visual polish on a
real device. Expect to tune physics numbers and palettes after playing.
