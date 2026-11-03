#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// Breakout clone with angle-controlled paddle, hard bricks, steel bricks, power-ups and six layouts.
final class BrickSmash: Game {
    private enum Phase { case title, ready, play, levelDone, over, win }

    private struct Ball {
        var x: Float
        var y: Float
        var vx: Float
        var vy: Float

        mutating func normalize(_ speed: Float) {
            var ny = vy
            let minVy = speed * 0.35
            if abs(ny) < minVy {
                ny = ny < 0 ? -minVy : minVy
            }
            let m = sqrt(vx * vx + ny * ny)
            if m < 0.001 {
                vx = 0
                vy = -speed
                return
            }
            vx = vx / m * speed
            vy = ny / m * speed
        }
    }

    private struct Capsule {
        var x: Float
        var y: Float
        var kind: Int
    }

    private struct Spark {
        var x: Float
        var y: Float
        var vx: Float
        var vy: Float
        var life: Int
        var color: Int
    }

    // Palette indices:
    // 0 bg, 1 white, 2 red, 3 orange, 4 yellow, 5 green, 6 cyan, 7 blue, 8 purple,
    // 9 light grey, 10 steel (dark), 11 border (dark blue-grey), 12 faint stripe
    private static let pal = Palette.make([
        0x101830, 0xF8F8F8, 0xE04848, 0xF09030, 0xF8E050, 0x40C860, 0x40C0E8,
        0x4060E0, 0xA050D0, 0xA0A8B8, 0x606878, 0x6070A0, 0x182448
    ])
    override var palette: [UInt16] { return BrickSmash.pal }

    // '1'...'7' coloured bricks, 'H' hard (2 hits), 'X' steel (indestructible), '.' empty. 10 columns, up to 8 rows.
    private static let levels: [[String]] = [
        [
            "1111111111",
            "2222222222",
            "3333333333",
            "4444444444",
            "5555555555"
        ],
        [
            "1.1.1.1.1.",
            ".2.2.2.2.2",
            "3.3.3.3.3.",
            ".4.4.4.4.4",
            "HHHHHHHHHH"
        ],
        [
            "....11....",
            "...2222...",
            "..333333..",
            ".44HHHH44.",
            "..555555..",
            "...6666...",
            "....77...."
        ],
        [
            "X.1.2.3.4X",
            "H1H2H3H4H5",
            "1H2H3H4H5H",
            "X........X",
            "6767676767",
            "7676767676"
        ],
        [
            "HHHHHHHHHH",
            "1234567123",
            "7654321765",
            "X..HHHH..X",
            "1234567123",
            "H.H.H.H.H."
        ],
        [
            "..1....1..",
            "...2..2...",
            "..333333..",
            ".44.44.44.",
            "5555555555",
            "5.666666.5",
            "5.6....6.5",
            "...77.77.."
        ]
    ]

    private let colsN = 10
    private let rowsN = 8
    private let originX = 5
    private let originY = 18
    private let cellW = 15
    private let cellH = 7
    private let padY: Float = 134

    private var phase: Phase = .title
    private var tick = 0
    private var rng = Rng()
    private var brickHP = [Int](repeating: 0, count: 80)
    private var brickCol = [Int](repeating: 0, count: 80)
    private var remaining = 0
    private var balls: [Ball] = []
    private var capsules: [Capsule] = []
    private var sparks: [Spark] = []
    private var padX: Float = 80
    private var padW: Float = 26
    private var wideTimer = 0
    private var slowTimer = 0
    private var lives = 3
    private var level = 0
    private var speed: Float = 1.8
    private var points = 0
    private var paused = false
    private var phaseTimer = 0

    override var score: Int { return points }

    override func start() { playMusic(Tunes.arcade) }

    // MARK: Setup

    private func startGame() {
        level = 0
        lives = 3
        points = 0
        padW = 26
        padX = 80
        paused = false
        loadLevel()
        resetBall()
        phase = .ready
    }

    private func loadLevel() {
        let layout = BrickSmash.levels[level % BrickSmash.levels.count]
        for i in 0..<80 {
            brickHP[i] = 0
            brickCol[i] = 0
        }
        remaining = 0
        let rowCount = min(layout.count, rowsN)
        for r in 0..<rowCount {
            let chars = Array(layout[r])
            let colCount = min(chars.count, colsN)
            for c in 0..<colCount {
                let ch = chars[c]
                let i = r * colsN + c
                if i < 0 || i >= 80 { continue }
                if ch == "H" {
                    brickHP[i] = 2
                    brickCol[i] = 9
                    remaining += 1
                } else if ch == "X" {
                    brickHP[i] = 99
                    brickCol[i] = 10
                } else if let d = ch.wholeNumberValue, d >= 1, d <= 7 {
                    brickHP[i] = 1
                    brickCol[i] = d + 1
                    remaining += 1
                }
            }
        }
        speed = min(3.2, 1.7 + Float(level) * 0.12)
        capsules = []
        sparks = []
    }

    private func resetBall() {
        balls = [Ball(x: padX, y: padY - 3, vx: 0, vy: 0)]
        capsules = []
        wideTimer = 0
        slowTimer = 0
    }

    // MARK: Update

    override func update(_ input: InputState) {
        tick += 1
        switch phase {
        case .title:
            if input.aPressed || input.startPressed {
                play(.confirm)
                startGame()
            }
        case .ready:
            movePaddle(input)
            if !balls.isEmpty {
                balls[0].x = padX
                balls[0].y = padY - 3
            }
            if input.aPressed && !balls.isEmpty {
                var b = balls[0]
                var dir = Float(input.dx)
                if input.dx == 0 { dir = rng.chance(50) ? 0.35 : -0.35 }
                b.vx = dir * speed * 0.6
                b.vy = -speed
                b.normalize(speed)
                balls[0] = b
                phase = .play
                play(.blip)
            }
        case .play:
            if input.startPressed {
                paused = !paused
                play(.pause)
            }
            if !paused {
                movePaddle(input)
                updateBalls()
                updateCapsules()
                if remaining <= 0 {
                    points += 100
                    phaseTimer = 120
                    if (level + 1) % BrickSmash.levels.count == 0 {
                        phase = .win
                    } else {
                        phase = .levelDone
                    }
                    play(.win)
                } else if balls.isEmpty {
                    lives -= 1
                    capsules = []
                    if lives <= 0 {
                        phase = .over
                        play(.lose)
                    } else {
                        phase = .ready
                        resetBall()
                        play(.hurt)
                    }
                }
            }
        case .levelDone:
            phaseTimer -= 1
            if phaseTimer <= 0 || input.aPressed {
                level += 1
                loadLevel()
                resetBall()
                phase = .ready
            }
        case .over:
            if input.aPressed || input.startPressed {
                play(.confirm)
                startGame()
            }
        case .win:
            if phaseTimer > 0 { phaseTimer -= 1 }
            if (input.aPressed || input.startPressed) && phaseTimer <= 60 {
                level += 1
                loadLevel()
                resetBall()
                phase = .ready
                play(.confirm)
            }
        }
        updateSparks()
    }

    private func movePaddle(_ input: InputState) {
        let sp: Float = input.b ? 4.4 : 3.0
        padX += Float(input.dx) * sp
        if wideTimer > 0 { wideTimer -= 1 }
        if slowTimer > 0 { slowTimer -= 1 }
        let target: Float = wideTimer > 0 ? 40 : 26
        if padW < target { padW += 1 } else if padW > target { padW -= 1 }
        padX = clamp(padX, padW / 2, 160 - padW / 2)
    }

    private func updateBalls() {
        var alive: [Ball] = []
        for var b in balls {
            if moveBall(&b) { alive.append(b) }
        }
        balls = alive
    }

    /// Returns false when the ball fell off the bottom.
    private func moveBall(_ b: inout Ball) -> Bool {
        b.normalize(speed)
        let mul: Float = slowTimer > 0 ? 0.7 : 1.0
        let sx = b.vx * mul
        let sy = b.vy * mul
        let fast = min(8, max(abs(sx), abs(sy)))
        let steps = max(1, Int(ceil(fast)))
        var ddx = sx / Float(steps)
        var ddy = sy / Float(steps)
        for _ in 0..<steps {
            // Horizontal
            b.x += ddx
            if b.x < 2 {
                b.x = 2
                b.vx = abs(b.vx)
                ddx = abs(ddx)
                play(.blip)
            } else if b.x > 158 {
                b.x = 158
                b.vx = -abs(b.vx)
                ddx = -abs(ddx)
                play(.blip)
            }
            let hx = ballHit(b)
            if hx >= 0 {
                b.x -= ddx
                b.vx = -b.vx
                ddx = -ddx
                damageBrick(hx)
            }
            // Vertical
            b.y += ddy
            if b.y < 14 {
                b.y = 14
                b.vy = abs(b.vy)
                ddy = abs(ddy)
                play(.blip)
            }
            let hy = ballHit(b)
            if hy >= 0 {
                b.y -= ddy
                b.vy = -b.vy
                ddy = -ddy
                damageBrick(hy)
            }
            // Paddle
            if ddy > 0 && b.vy > 0 {
                let half = padW / 2
                if b.y + 2 >= padY && b.y + 2 <= padY + 5 && b.x + 2 >= padX - half && b.x - 2 <= padX + half {
                    var t = (b.x - padX) / (half + 2)
                    t = clamp(t, -1, 1)
                    let ang = t * 1.05
                    b.vx = speed * sin(ang)
                    b.vy = -speed * cos(ang)
                    b.y = padY - 3
                    ddx = b.vx * mul / Float(steps)
                    ddy = b.vy * mul / Float(steps)
                    play(.bounce)
                }
            }
            if b.y > 148 { return false }
        }
        return true
    }

    private func brickIndexAt(_ fx: Float, _ fy: Float) -> Int {
        if fx < Float(originX) || fy < Float(originY) { return -1 }
        let c = Int((fx - Float(originX)) / Float(cellW))
        let r = Int((fy - Float(originY)) / Float(cellH))
        if c < 0 || c >= colsN || r < 0 || r >= rowsN { return -1 }
        let i = r * colsN + c
        if i < 0 || i >= brickHP.count { return -1 }
        if brickHP[i] > 0 { return i }
        return -1
    }

    private func ballHit(_ b: Ball) -> Int {
        let h: Float = 1.9
        var i = brickIndexAt(b.x - h, b.y - h)
        if i >= 0 { return i }
        i = brickIndexAt(b.x + h, b.y - h)
        if i >= 0 { return i }
        i = brickIndexAt(b.x - h, b.y + h)
        if i >= 0 { return i }
        i = brickIndexAt(b.x + h, b.y + h)
        return i
    }

    private func damageBrick(_ idx: Int) {
        if idx < 0 || idx >= brickHP.count { return }
        let hp = brickHP[idx]
        if hp >= 90 {
            play(.thud)
            return
        }
        if hp <= 0 { return }
        brickHP[idx] = hp - 1
        speed = min(3.6, speed + 0.012)
        if hp - 1 <= 0 {
            remaining -= 1
            let row = idx / colsN
            points += 10 + max(0, 4 - row) * 2 + (hp > 1 ? 10 : 0)
            let col = idx % colsN
            let cx = Float(originX + col * cellW + 7)
            let cy = Float(originY + row * cellH + 3)
            spawnSparks(cx, cy, brickCol[idx])
            if rng.chance(15) { spawnCapsule(cx, cy) }
            play(.pickup)
        } else {
            points += 5
            play(.hit)
        }
    }

    private func spawnSparks(_ x: Float, _ y: Float, _ color: Int) {
        if sparks.count > 70 { return }
        for _ in 0..<5 {
            let vx = Float(rng.range(-12, 12)) / 10
            let vy = Float(rng.range(-14, 2)) / 10
            sparks.append(Spark(x: x, y: y, vx: vx, vy: vy, life: 20 + rng.int(12), color: color))
        }
    }

    private func spawnCapsule(_ x: Float, _ y: Float) {
        let r = rng.int(100)
        var kind = 3
        if r < 32 { kind = 0 } else if r < 60 { kind = 1 } else if r < 76 { kind = 2 }
        capsules.append(Capsule(x: x, y: y, kind: kind))
    }

    private func updateCapsules() {
        var keep: [Capsule] = []
        let half = padW / 2
        for var cap in capsules {
            cap.y += 0.9
            if cap.y + 4 >= padY && cap.y <= padY + 4 && cap.x + 5 >= padX - half && cap.x - 5 <= padX + half {
                applyCapsule(cap.kind)
                continue
            }
            if cap.y > 146 { continue }
            keep.append(cap)
        }
        capsules = keep
    }

    private func applyCapsule(_ kind: Int) {
        points += 50
        play(.powerup)
        switch kind {
        case 0:
            wideTimer = 900
        case 1:
            slowTimer = 600
        case 2:
            lives = min(5, lives + 1)
        default:
            let current = balls
            for b in current {
                if balls.count >= 6 { break }
                var n1 = b
                n1.vx += 0.9
                n1.normalize(speed)
                balls.append(n1)
                if balls.count >= 6 { break }
                var n2 = b
                n2.vx -= 0.9
                n2.normalize(speed)
                balls.append(n2)
            }
        }
    }

    private func updateSparks() {
        if sparks.isEmpty { return }
        var keep: [Spark] = []
        for var s in sparks {
            s.x += s.vx
            s.y += s.vy
            s.vy += 0.05
            s.life -= 1
            if s.life > 0 { keep.append(s) }
        }
        sparks = keep
    }

    // MARK: Draw

    private func outlinedCentered(_ c: Canvas, _ s: String, _ y: Int, _ col: Int) {
        let w = c.textWidth(s)
        c.outlinedText(s, (160 - w) / 2, y, col, outline: 0)
    }

    override func draw(_ c: Canvas) {
        c.clear(0)
        for x in stride(from: 0, to: 160, by: 16) { c.vline(x, 11, 133, 12) }

        if phase == .title {
            drawTitle(c)
            return
        }

        drawBricks(c)

        for cap in capsules { drawCapsule(c, cap) }

        // Paddle
        let pw = Int(padW)
        let px = Int(padX - padW / 2)
        c.fillRect(px, Int(padY), pw, 4, 1)
        c.fillRect(px, Int(padY), 3, 4, 6)
        c.fillRect(px + pw - 3, Int(padY), 3, 4, 6)
        c.hline(px, Int(padY) + 3, pw, 11)

        for b in balls {
            let bx = Int(b.x) - 2
            let by = Int(b.y) - 2
            c.fillRect(bx, by, 4, 4, 1)
            c.setPixel(bx + 3, by + 3, 9)
        }
        for s in sparks {
            c.setPixel(Int(s.x), Int(s.y), s.color)
        }

        // HUD
        c.fillRect(0, 0, 160, 10, 0)
        c.hline(0, 10, 160, 11)
        c.text("SCORE " + zeroPad(points, 5), 2, 2, 1)
        c.text("L" + String(level + 1), 78, 2, 6)
        for i in 0..<max(0, min(lives, 5)) {
            c.fillRect(158 - (i + 1) * 8, 3, 6, 3, 6)
            c.hline(158 - (i + 1) * 8, 3, 6, 1)
        }
        if wideTimer > 0 { c.text("W", 100, 2, 4) }
        if slowTimer > 0 { c.text("S", 108, 2, 5) }

        switch phase {
        case .ready:
            outlinedCentered(c, "LEVEL " + String(level + 1), 92, 4)
            if (tick / 20) % 2 == 0 { outlinedCentered(c, "A: LAUNCH", 102, 1) }
        case .levelDone:
            outlinedCentered(c, "LEVEL CLEAR!", 92, 4)
        case .over:
            c.fillRect(30, 80, 100, 34, 0)
            c.strokeRect(30, 80, 100, 34, 11)
            outlinedCentered(c, "GAME OVER", 86, 2)
            outlinedCentered(c, "SCORE " + zeroPad(points, 5), 96, 1)
            if (tick / 20) % 2 == 0 { outlinedCentered(c, "PRESS A", 106, 4) }
        case .win:
            c.fillRect(24, 80, 112, 34, 0)
            c.strokeRect(24, 80, 112, 34, 11)
            outlinedCentered(c, "BOARD CLEARED!", 86, 4)
            outlinedCentered(c, "SCORE " + zeroPad(points, 5), 96, 1)
            if (tick / 20) % 2 == 0 && phaseTimer <= 60 { outlinedCentered(c, "A: KEEP GOING", 106, 6) }
        case .play:
            if paused { outlinedCentered(c, "PAUSED", 92, 1) }
        case .title:
            break
        }
    }

    private func drawTitle(_ c: Canvas) {
        c.textCentered("BRICK", y: 22, 3, scale: 3)
        c.textCentered("SMASH", y: 42, 4, scale: 3)
        let colors: [Int] = [2, 3, 4, 5, 6, 7, 8]
        for r in 0..<7 {
            for i in 0..<10 {
                let x = 5 + i * 15
                let y = 68 + r * 7
                let col = colors[(r + i) % 7]
                c.fillRect(x, y, 14, 5, col)
                c.hline(x, y + 5, 14, 11)
            }
        }
        let bx = 80 + Int(30 * sin(Float(tick) * 0.05))
        c.fillRect(bx - 2, 124, 4, 4, 1)
        c.fillRect(bx - 12, 132, 24, 4, 1)
        c.fillRect(bx - 12, 132, 3, 4, 6)
        c.fillRect(bx + 9, 132, 3, 4, 6)
        if (tick / 25) % 2 == 0 { outlinedCentered(c, "PRESS A TO PLAY", 56, 1) }
    }

    private func drawBricks(_ c: Canvas) {
        for r in 0..<rowsN {
            for col in 0..<colsN {
                let i = r * colsN + col
                if i < 0 || i >= brickHP.count { continue }
                let hp = brickHP[i]
                if hp <= 0 { continue }
                let x = originX + col * cellW
                let y = originY + r * cellH
                if hp >= 90 {
                    c.fillRect(x, y, 14, 6, 10)
                    c.strokeRect(x, y, 14, 6, 9)
                    c.setPixel(x + 3, y + 3, 9)
                    c.setPixel(x + 10, y + 3, 9)
                } else if brickCol[i] == 9 {
                    c.fillRect(x, y, 14, 6, 9)
                    c.hline(x, y, 14, 1)
                    c.hline(x, y + 5, 14, 10)
                    if hp == 1 {
                        c.setPixel(x + 4, y + 1, 10)
                        c.setPixel(x + 5, y + 2, 10)
                        c.setPixel(x + 6, y + 3, 10)
                        c.setPixel(x + 7, y + 2, 10)
                        c.setPixel(x + 8, y + 3, 10)
                        c.setPixel(x + 9, y + 4, 10)
                    }
                } else {
                    c.fillRect(x, y, 14, 5, brickCol[i])
                    c.hline(x, y + 5, 14, 11)
                    c.setPixel(x + 1, y + 1, 1)
                }
            }
        }
    }

    private func drawCapsule(_ c: Canvas, _ cap: Capsule) {
        let x = Int(cap.x) - 5
        let y = Int(cap.y)
        var fill = 4
        var letter = "W"
        var ink = 0
        switch cap.kind {
        case 0:
            fill = 4
            letter = "W"
            ink = 0
        case 1:
            fill = 6
            letter = "S"
            ink = 0
        case 2:
            fill = 2
            letter = "L"
            ink = 1
        default:
            fill = 5
            letter = "M"
            ink = 0
        }
        c.fillRect(x, y, 11, 7, fill)
        c.strokeRect(x, y, 11, 7, 1)
        c.text(letter, x + 4, y + 1, ink)
    }
}

extension Cartridge {
    static let brickSmash = Cartridge(
        id: "bricksmash", title: "BRICK SMASH", genre: "Arcade",
        blurb: "Bounce the ball, smash every brick and catch falling power-ups. Six layouts with tough and steel bricks.",
        controls: "LEFT / RIGHT moves (hold B for speed), A launches, START pauses.",
        era: .gbc, labelTop: 0xE0603C, labelBottom: 0x2A2050, factory: { BrickSmash() })
}
