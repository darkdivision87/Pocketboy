#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// Alien-grid shooter with pixel-destructible shields, bombs, a bonus UFO and escalating waves.
final class StarInvaders: Game {
    private enum Phase { case title, intro, play, dying, over }

    private struct Bomb {
        var x: Float
        var y: Float
        var vy: Float
    }

    private struct Boom {
        var x: Int
        var y: Int
        var t: Int
    }

    // Palette: 0 bg, 1 white, 2 squid, 3 crab, 4 octopus, 5 ship, 6 shield, 7 bomb, 8 ufo, 9 stars, 10 ground
    private static let pal = Palette.make([
        0x080C18, 0xF8F8F8, 0xF8E858, 0x58E0B0, 0x8068E0, 0xB0F8B0, 0x40C050,
        0xF86060, 0xF05858, 0x283058, 0x306840
    ])
    override var palette: [UInt16] { return StarInvaders.pal }

    private static let squid1 = Sprite([
        "...22...",
        "..2222..",
        ".222222.",
        "22.22.22",
        "22222222",
        "..2..2..",
        ".2.22.2.",
        "2.2..2.2"
    ])
    private static let squid2 = Sprite([
        "...22...",
        "..2222..",
        ".222222.",
        "22.22.22",
        "22222222",
        ".2.22.2.",
        "2......2",
        ".2....2."
    ])
    private static let crab1 = Sprite([
        "..3..3..",
        "3.3333.3",
        "33.33.33",
        "33333333",
        ".333333.",
        "..3..3..",
        ".3....3.",
        "3......3"
    ])
    private static let crab2 = Sprite([
        "..3..3..",
        "..3333..",
        ".333333.",
        "33.33.33",
        "33333333",
        "3.3333.3",
        "3.3..3.3",
        "..3..3.."
    ])
    private static let octo1 = Sprite([
        "..4444..",
        ".444444.",
        "44444444",
        "444..444",
        "44444444",
        "..4..4..",
        ".44..44.",
        "44....44"
    ])
    private static let octo2 = Sprite([
        "..4444..",
        ".444444.",
        "44444444",
        "444..444",
        "44444444",
        ".44..44.",
        "44.44.44",
        ".4....4."
    ])
    private static let ufoSprite = Sprite([
        "....8888....",
        "..88888888..",
        ".8888888888.",
        "88.88.88.88.",
        "888888888888",
        "..8..88..8.."
    ])
    private static let shipSprite = Sprite([
        "....5....",
        "...555...",
        "...555...",
        ".5555555.",
        "555555555",
        "555555555"
    ])
    private static let bombSprite = Sprite([
        ".7.",
        "7..",
        ".7.",
        "..7",
        ".7."
    ])
    private static let alienFrames: [[Sprite]] = [
        [StarInvaders.squid1, StarInvaders.squid2],
        [StarInvaders.crab1, StarInvaders.crab2],
        [StarInvaders.octo1, StarInvaders.octo2]
    ]

    private static let shieldTemplate: [String] = [
        "....############....",
        "..################..",
        ".##################.",
        "####################",
        "####################",
        "####################",
        "####################",
        "####################",
        "####################",
        "#######......#######",
        "######........######",
        "#####..........#####"
    ]

    private static let rowType: [Int] = [0, 1, 1, 2, 2]
    private static let typeValue: [Int] = [30, 20, 10]
    private static let ufoValues: [Int] = [50, 100, 150, 300]

    private let colsN = 9
    private let rowsN = 5
    private let shieldY = 106
    private let shieldXs: [Int] = [16, 52, 88, 124]
    private let playerY = 130

    private var phase: Phase = .title
    private var tick = 0
    private var rng = Rng()
    private var points = 0
    private var lives = 3
    private var wave = 1
    private var alive = [Bool](repeating: false, count: 45)
    private var aliveCount = 0
    private var gridX = 10
    private var gridY = 24
    private var dir = 1
    private var marchTimer = 0
    private var animFrame = 0
    private var shields = [UInt8](repeating: 0, count: 960)
    private var playerX: Float = 75
    private var bulletOn = false
    private var bulletX = 0
    private var bulletY = 0
    private var bombs: [Bomb] = []
    private var fireTimer = 60
    private var ufoOn = false
    private var ufoX: Float = 0
    private var ufoDir: Float = 1
    private var ufoTimer = 700
    private var popupText = ""
    private var popupX = 0
    private var popupTimer = 0
    private var booms: [Boom] = []
    private var phaseTimer = 0
    private var paused = false
    private var invaded = false

    override var score: Int { return points }

    override func start() { playMusic(Tunes.space) }

    // MARK: Setup

    private func newGame() {
        points = 0
        lives = 3
        wave = 1
        playerX = 75
        paused = false
        invaded = false
        booms = []
        popupTimer = 0
        startWave()
    }

    private func startWave() {
        for i in 0..<45 { alive[i] = true }
        aliveCount = 45
        gridX = 10
        gridY = 22 + min(wave - 1, 5) * 6
        dir = 1
        marchTimer = 0
        animFrame = 0
        bombs = []
        bulletOn = false
        ufoOn = false
        ufoTimer = rng.range(500, 900)
        fireTimer = 70
        buildShields()
        phase = .intro
        phaseTimer = 90
    }

    private func buildShields() {
        for s in 0..<4 {
            for y in 0..<12 {
                let chars = Array(StarInvaders.shieldTemplate[y])
                for x in 0..<20 {
                    var v: UInt8 = 0
                    if x < chars.count && chars[x] == "#" { v = 1 }
                    shields[s * 240 + y * 20 + x] = v
                }
            }
        }
    }

    // MARK: Shields

    private func shieldIndex(_ x: Int, _ y: Int) -> Int {
        if y < shieldY || y >= shieldY + 12 { return -1 }
        for s in 0..<4 {
            let sx = shieldXs[s]
            if x >= sx && x < sx + 20 {
                let idx = s * 240 + (y - shieldY) * 20 + (x - sx)
                if idx >= 0 && idx < shields.count { return idx }
                return -1
            }
        }
        return -1
    }

    private func shieldSolid(_ x: Int, _ y: Int) -> Bool {
        let i = shieldIndex(x, y)
        if i < 0 { return false }
        return shields[i] != 0
    }

    private func erode(_ cx: Int, _ cy: Int, _ r: Int) {
        for dy in -r...r {
            for dx in -r...r {
                if dx * dx + dy * dy > r * r + 1 { continue }
                let i = shieldIndex(cx + dx, cy + dy)
                if i < 0 { continue }
                if dx * dx + dy * dy >= r * r && rng.chance(40) { continue }
                shields[i] = 0
            }
        }
    }

    private func eraseRect(_ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        if y + h < shieldY || y > shieldY + 12 { return }
        for yy in 0..<h {
            for xx in 0..<w {
                let i = shieldIndex(x + xx, y + yy)
                if i >= 0 { shields[i] = 0 }
            }
        }
    }

    // MARK: Update

    override func update(_ input: InputState) {
        tick += 1
        updateBooms()
        if popupTimer > 0 { popupTimer -= 1 }
        switch phase {
        case .title:
            if input.aPressed || input.startPressed {
                play(.confirm)
                newGame()
            }
        case .intro:
            phaseTimer -= 1
            movePlayer(input, false)
            if phaseTimer <= 0 { phase = .play }
        case .play:
            if input.startPressed {
                paused = !paused
                play(.pause)
            }
            if !paused { updatePlay(input) }
        case .dying:
            phaseTimer -= 1
            if phaseTimer <= 0 {
                if lives <= 0 {
                    phase = .over
                    play(.lose)
                } else {
                    playerX = 75
                    phase = .play
                }
            }
        case .over:
            if input.aPressed || input.startPressed {
                play(.confirm)
                newGame()
            }
        }
    }

    private func movePlayer(_ input: InputState, _ canFire: Bool) {
        playerX += Float(input.dx) * 1.4
        playerX = clamp(playerX, 3, 148)
        if canFire && (input.a || input.b) && !bulletOn {
            bulletOn = true
            bulletX = Int(playerX) + 4
            bulletY = playerY - 3
            play(.shoot)
        }
    }

    private func updatePlay(_ input: InputState) {
        movePlayer(input, true)

        // Alien march
        marchTimer += 1
        if marchTimer >= marchInterval() {
            marchTimer = 0
            stepAliens()
            if phase != .play { return }
        }

        updateBullet()
        updateBombs()
        updateUfo()
        maybeFire()

        if aliveCount <= 0 {
            points += 100 * wave
            wave += 1
            play(.win)
            startWave()
        }
    }

    private func marchInterval() -> Int {
        let base = 3 + aliveCount * 22 / 45
        return max(2, base - (wave - 1))
    }

    private func stepAliens() {
        if aliveCount <= 0 { return }
        animFrame = 1 - animFrame
        if animFrame == 0 { play(.drop) } else { play(.step) }
        var minC = colsN
        var maxC = -1
        var lowRow = -1
        for r in 0..<rowsN {
            for c in 0..<colsN {
                if alive[r * colsN + c] {
                    minC = min(minC, c)
                    maxC = max(maxC, c)
                    lowRow = max(lowRow, r)
                }
            }
        }
        if maxC < 0 { return }
        let left = gridX + minC * 12 + 2
        let right = gridX + maxC * 12 + 2 + 8
        if (dir > 0 && right + 2 > 156) || (dir < 0 && left - 2 < 4) {
            gridY += 6
            dir = -dir
        } else {
            gridX += dir * 2
        }
        let bottom = gridY + lowRow * 10 + 8
        if bottom >= shieldY - 10 {
            for r in 0..<rowsN {
                for c in 0..<colsN {
                    if alive[r * colsN + c] {
                        eraseRect(gridX + c * 12 + 2, gridY + r * 10, 8, 8)
                    }
                }
            }
        }
        if bottom >= playerY - 2 {
            invaded = true
            lives = 0
            phase = .dying
            phaseTimer = 70
            play(.explosion)
        }
    }

    private func killAlien(_ i: Int) {
        if i < 0 || i >= 45 || !alive[i] { return }
        alive[i] = false
        aliveCount -= 1
        let r = i / colsN
        let c = i % colsN
        let t = StarInvaders.rowType[r]
        points += StarInvaders.typeValue[t]
        booms.append(Boom(x: gridX + c * 12 + 6, y: gridY + r * 10 + 4, t: 0))
        play(.hit)
    }

    private func hitAlien(_ px: Int, _ py: Int) -> Bool {
        for r in 0..<rowsN {
            let ay = gridY + r * 10
            if py < ay || py >= ay + 8 { continue }
            for c in 0..<colsN {
                let i = r * colsN + c
                if !alive[i] { continue }
                let ax = gridX + c * 12 + 2
                if px >= ax && px < ax + 8 {
                    killAlien(i)
                    return true
                }
            }
        }
        return false
    }

    private func updateBullet() {
        if !bulletOn { return }
        for _ in 0..<4 {
            bulletY -= 1
            if bulletY < 11 {
                bulletOn = false
                return
            }
            if shieldSolid(bulletX, bulletY) {
                erode(bulletX, bulletY, 2)
                bulletOn = false
                return
            }
            if hitAlien(bulletX, bulletY) {
                bulletOn = false
                return
            }
            if ufoOn && Float(bulletX) >= ufoX && Float(bulletX) < ufoX + 12 && bulletY >= 11 && bulletY < 17 {
                ufoOn = false
                bulletOn = false
                let v = StarInvaders.ufoValues[rng.int(StarInvaders.ufoValues.count)]
                points += v
                popupText = String(v)
                popupX = Int(ufoX)
                popupTimer = 50
                booms.append(Boom(x: Int(ufoX) + 6, y: 14, t: 0))
                play(.coin)
                return
            }
        }
    }

    private func updateBombs() {
        var keep: [Bomb] = []
        for var b in bombs {
            var removed = false
            let steps = max(1, Int(ceil(b.vy)))
            let dy = b.vy / Float(steps)
            for _ in 0..<steps {
                b.y += dy
                let bx = Int(b.x)
                let by = Int(b.y)
                if shieldSolid(bx + 1, by + 4) {
                    erode(bx + 1, by + 4, 2)
                    removed = true
                    break
                }
                if by >= 136 {
                    removed = true
                    break
                }
                if bulletOn && bulletX >= bx && bulletX < bx + 3 && bulletY >= by - 3 && bulletY < by + 5 {
                    bulletOn = false
                    removed = true
                    booms.append(Boom(x: bx + 1, y: by + 2, t: 4))
                    break
                }
                if bx + 3 > Int(playerX) && bx < Int(playerX) + 9 && by + 5 > playerY && by < playerY + 6 {
                    removed = true
                    killPlayer()
                    break
                }
            }
            if removed { continue }
            keep.append(b)
        }
        if phase == .play { bombs = keep }
    }

    private func killPlayer() {
        lives -= 1
        play(.explosion)
        phase = .dying
        phaseTimer = 70
        bombs = []
        bulletOn = false
    }

    private func maybeFire() {
        fireTimer -= 1
        let maxBombs = 2 + min(wave, 3)
        if fireTimer > 0 || bombs.count >= maxBombs || aliveCount <= 0 { return }
        fireTimer = max(10, rng.range(20, 50) - min(wave, 5) * 4)
        var cols: [Int] = []
        for c in 0..<colsN {
            for r in 0..<rowsN where alive[r * colsN + c] {
                cols.append(c)
                break
            }
        }
        if cols.isEmpty { return }
        var col = cols[rng.int(cols.count)]
        if rng.chance(40) {
            // Aim at the column nearest the player.
            var best = col
            var bestDist = 9999
            for c in cols {
                let cx = gridX + c * 12 + 6
                let d = abs(cx - (Int(playerX) + 4))
                if d < bestDist {
                    bestDist = d
                    best = c
                }
            }
            col = best
        }
        var row = -1
        for r in 0..<rowsN where alive[r * colsN + col] { row = r }
        if row < 0 { return }
        let bx = Float(gridX + col * 12 + 5)
        let by = Float(gridY + row * 10 + 8)
        let vy = min(2.6, 1.2 + Float(wave) * 0.12)
        bombs.append(Bomb(x: bx, y: by, vy: vy))
    }

    private func updateUfo() {
        if ufoOn {
            ufoX += 0.7 * ufoDir
            if tick % 14 == 0 { play(.blip) }
            if ufoX < -16 || ufoX > 164 { ufoOn = false }
        } else {
            ufoTimer -= 1
            if ufoTimer <= 0 && aliveCount >= 6 {
                ufoOn = true
                ufoDir = rng.chance(50) ? 1 : -1
                ufoX = ufoDir > 0 ? -12 : 160
                ufoTimer = rng.range(700, 1300)
            }
        }
    }

    private func updateBooms() {
        if booms.isEmpty { return }
        var keep: [Boom] = []
        for var b in booms {
            b.t += 1
            if b.t < 14 { keep.append(b) }
        }
        booms = keep
    }

    // MARK: Draw

    private func centered(_ c: Canvas, _ s: String, _ y: Int, _ col: Int) {
        let w = c.textWidth(s)
        c.text(s, (160 - w) / 2, y, col)
    }

    override func draw(_ c: Canvas) {
        c.clear(0)
        for i in 0..<24 {
            let sx = (i * 37 + 11) % 160
            let sy = (i * 53 + 17) % 100 + 14
            c.setPixel(sx, sy, 9)
        }

        if phase == .title {
            drawTitle(c)
            return
        }

        // Shields
        for s in 0..<4 {
            for y in 0..<12 {
                for x in 0..<20 {
                    if shields[s * 240 + y * 20 + x] != 0 {
                        c.setPixel(shieldXs[s] + x, shieldY + y, 6)
                    }
                }
            }
        }
        c.hline(0, 139, 160, 10)

        // Aliens
        let fr = animFrame & 1
        for r in 0..<rowsN {
            let t = StarInvaders.rowType[r]
            let sprite = StarInvaders.alienFrames[t][fr]
            for col in 0..<colsN where alive[r * colsN + col] {
                c.draw(sprite, gridX + col * 12 + 2, gridY + r * 10)
            }
        }

        if ufoOn { c.draw(StarInvaders.ufoSprite, Int(ufoX), 11) }
        if popupTimer > 0 { c.text(popupText, popupX, 12, 1) }

        // Player
        if phase == .dying {
            let t = 70 - phaseTimer
            let cx = Int(playerX) + 4
            let cy = playerY + 3
            let burstColor = (t / 3) % 2 == 0 ? 1 : 7
            c.fillCircle(cx, cy, min(8, t / 6 + 1), burstColor)
        } else {
            c.draw(StarInvaders.shipSprite, Int(playerX), playerY)
        }
        if bulletOn { c.vline(bulletX, bulletY, 4, 1) }

        let bombFlip = (tick / 4) % 2 == 0
        for b in bombs {
            c.draw(StarInvaders.bombSprite, Int(b.x), Int(b.y), flipX: bombFlip)
        }
        for b in booms { drawBoom(c, b) }

        // HUD
        c.text("SCORE " + zeroPad(points, 5), 2, 2, 1)
        c.text("WAVE " + String(wave), 62, 2, 3)
        let shown = max(0, min(lives, 3))
        for i in 0..<shown {
            c.draw(StarInvaders.shipSprite, 124 + i * 12, 2)
        }
        c.hline(0, 10, 160, 10)

        switch phase {
        case .intro:
            centered(c, "WAVE " + String(wave), 74, 1)
        case .over:
            c.fillRect(30, 50, 100, 44, 0)
            c.strokeRect(30, 50, 100, 44, 10)
            centered(c, invaded ? "INVADED!" : "GAME OVER", 56, 7)
            centered(c, "SCORE " + zeroPad(points, 5), 68, 1)
            if (tick / 25) % 2 == 0 { centered(c, "PRESS A", 80, 2) }
        case .play:
            if paused { centered(c, "PAUSED", 70, 1) }
        case .title, .dying:
            break
        }
    }

    private func drawBoom(_ c: Canvas, _ b: Boom) {
        let r = 1 + b.t / 3
        c.setPixel(b.x - r, b.y, 1)
        c.setPixel(b.x + r, b.y, 1)
        c.setPixel(b.x, b.y - r, 1)
        c.setPixel(b.x, b.y + r, 1)
        let d = max(1, r - 1)
        c.setPixel(b.x - d, b.y - d, 2)
        c.setPixel(b.x + d, b.y - d, 2)
        c.setPixel(b.x - d, b.y + d, 2)
        c.setPixel(b.x + d, b.y + d, 2)
    }

    private func drawTitle(_ c: Canvas) {
        c.textCentered("STAR", y: 12, 2, scale: 3)
        c.textCentered("INVADERS", y: 32, 3, scale: 2)
        let fr = (tick / 30) % 2
        c.draw(StarInvaders.alienFrames[0][fr], 48, 58)
        c.text("= 30 PTS", 64, 60, 1)
        c.draw(StarInvaders.alienFrames[1][fr], 48, 70)
        c.text("= 20 PTS", 64, 72, 1)
        c.draw(StarInvaders.alienFrames[2][fr], 48, 82)
        c.text("= 10 PTS", 64, 84, 1)
        c.draw(StarInvaders.ufoSprite, 46, 94)
        c.text("= ???", 64, 96, 1)
        c.draw(StarInvaders.shipSprite, 76, 116)
        if (tick / 25) % 2 == 0 { centered(c, "PRESS A TO START", 128, 5) }
    }
}

extension Cartridge {
    static let starInvaders = Cartridge(
        id: "starinvaders", title: "STAR INVADERS", genre: "Shooter",
        blurb: "Defend the planet from marching alien waves. Hide behind crumbling shields and shoot the bonus UFO.",
        controls: "LEFT / RIGHT move, A or B fire (one shot at a time), START pauses.",
        era: .gb, labelTop: 0x58E0B0, labelBottom: 0x0C1830, factory: { StarInvaders() })
}
