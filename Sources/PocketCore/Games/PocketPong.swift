import Foundation

/// REFERENCE GAME: shows the conventions every cartridge follows.
final class PocketPong: Game {
    // Palette: index 0 is always the background colour Console clears to.
    private static let pal = Palette.make([
        0xD8EAC0, // 0 court
        0xA8C888, // 1 court stripe
        0x2C5A44, // 2 dark green
        0x102A20, // 3 near black
        0xE04848, // 4 red paddle
        0x4880E0, // 5 blue paddle
        0xF8F8F8  // 6 white
    ])
    override var palette: [UInt16] { return PocketPong.pal }

    private var playerY: Float = 60
    private var cpuY: Float = 60
    private var ballX: Float = 80
    private var ballY: Float = 72
    private var vx: Float = 1.6
    private var vy: Float = 1.0
    private var playerScore = 0
    private var cpuScore = 0
    private var serveDelay = 60
    private var rng = Rng()
    private let paddleH: Float = 24

    override var score: Int { return playerScore * 100 }

    override func start() { playMusic(Tunes.arcade) }

    private func serve(toward dir: Float) {
        ballX = 80
        ballY = 72
        vx = 1.6 * dir
        vy = Float(rng.range(-12, 12)) / 10
        serveDelay = 45
    }

    override func update(_ input: InputState) {
        let speed: Float = 2.2
        playerY = clamp(playerY + Float(input.dy) * speed, 8, 144 - 8 - paddleH)
        // Simple CPU: follow the ball with a speed limit.
        let target = ballY - paddleH / 2
        if cpuY < target - 2 { cpuY += 1.3 } else if cpuY > target + 2 { cpuY -= 1.3 }
        cpuY = clamp(cpuY, 8, 144 - 8 - paddleH)

        if serveDelay > 0 { serveDelay -= 1; return }
        ballX += vx
        ballY += vy
        if ballY < 9 { ballY = 9; vy = abs(vy); play(.blip) }
        if ballY > 134 { ballY = 134; vy = -abs(vy); play(.blip) }

        // Paddles
        if vx < 0 && ballX <= 14 && ballX >= 8 && ballY + 3 >= playerY && ballY <= playerY + paddleH {
            vx = abs(vx) * 1.06
            vy += (ballY - (playerY + paddleH / 2)) / 8
            play(.bounce)
        }
        if vx > 0 && ballX >= 143 && ballX <= 150 && ballY + 3 >= cpuY && ballY <= cpuY + paddleH {
            vx = -abs(vx) * 1.04
            vy += (ballY - (cpuY + paddleH / 2)) / 8
            play(.bounce)
        }
        vy = clamp(vy, -3, 3)
        vx = clamp(vx, -4, 4)
        if ballX < 0 { cpuScore += 1; play(.hurt); serve(toward: 1) }
        if ballX > 157 { playerScore += 1; play(.coin); serve(toward: -1) }
        if playerScore >= 7 || cpuScore >= 7 {
            if playerScore >= 7 { play(.win) } else { play(.lose) }
            playerScore = 0
            cpuScore = 0
            serve(toward: 1)
        }
    }

    override func draw(_ c: Canvas) {
        c.clear(0)
        c.fillRect(0, 0, 160, 8, 2)
        c.fillRect(0, 136, 160, 8, 2)
        for y in stride(from: 10, to: 134, by: 8) { c.fillRect(79, y, 2, 4, 1) }
        c.text(String(playerScore), 60, 1, 6)
        c.text(String(cpuScore), 96, 1, 6)
        c.fillRect(8, Int(playerY), 4, Int(paddleH), 4)
        c.fillRect(148, Int(cpuY), 4, Int(paddleH), 5)
        c.fillRect(Int(ballX), Int(ballY), 4, 4, 3)
    }
}

extension Cartridge {
    static let pocketPong = Cartridge(
        id: "pong", title: "POCKET PONG", genre: "Sports",
        blurb: "The grandfather of video games. First to seven wins.",
        controls: "UP / DOWN moves your paddle.",
        era: .gb, labelTop: 0x5C9A6E, labelBottom: 0x1E4A38, factory: { PocketPong() })
}
