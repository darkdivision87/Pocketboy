import Foundation

/// A cinematic platformer in the spirit of the classic palace-dungeon escapes:
/// flip-screen rooms, careful steps, running jumps, ledge climbs, loose floors, spikes, gates and sword duels.
final class DesertPrince: Game {
    // MARK: - Palette

    private static let pal = Palette.make([
        0x1C1828, 0x2C2640, 0x5A4A6A, 0x382C48, 0x7A688C, 0xB89860, 0x6A5030, 0x2E2010,
        0xF4F4F0, 0xE8B890, 0xD03030, 0x3050C0, 0xE8B040, 0x902020, 0x303040, 0xFFA030,
        0xFFE060, 0xC8C8D8, 0xE03050, 0xA0E0F0, 0x8890A0, 0x6A4A20, 0xD0A030, 0x080810,
        0xF0F0F0, 0xE04040, 0x801818, 0xE0E8F8, 0xA08040, 0x9AA0C0
    ])
    override var palette: [UInt16] { return DesertPrince.pal }

    // MARK: - Geometry

    private static let cellW = 16
    private static let cellH = 44
    private static let roomCols = 10
    private static let roomRows = 3

    /// Surface line (feet) of a row.
    private func surface(_ row: Int) -> Float { return Float((row + 1) * DesertPrince.cellH - 6) }
    private func rowOf(_ y: Float) -> Int { return Int(floor((y - 1) / Float(DesertPrince.cellH))) }
    private func colOf(_ x: Float) -> Int { return Int(floor(x / Float(DesertPrince.cellW))) }

    // MARK: - Levels

    private struct LevelDef {
        var name: String
        var rows: [String]
    }

    private static func sp(_ n: Int) -> String { return String(repeating: " ", count: n) }

    private static let levels: [LevelDef] = [
        LevelDef(name: "THE DUNGEON", rows: [
            sp(40),
            sp(14) + "..H.." + sp(21),
            "S........." + "  " + "......" + "^^" + "...." + "~~" + "...." + "T" + ".." + "D" + "...." + "X" + "."
        ]),
        LevelDef(name: "THE GUARDS", rows: [
            sp(40),
            sp(12) + "..H.." + sp(23),
            sp(3) + "X" + "....." + "  " + "......" + "G" + "....." + "~~" + "....." + sp(10),
            sp(30) + "...^^..." + sp(2),
            sp(38) + "..",
            ".S.......W.." + "  " + "......." + "G" + "...." + "^^" + "..." + "T" + ".." + "D" + "....."
        ]),
        LevelDef(name: "THE TOWER", rows: [
            sp(50),
            sp(50),
            ".S" + "......" + "W" + "..........." + "  " + "......" + "#" + "....." + " " + "..." + "^^" + "." + "G" + ".." + "~~" + "." + "X" + "..",
            sp(18) + "......" + "^^" + "." + "G" + "..." + "H" + "..." + sp(5) + "..........",
            sp(50),
            sp(50)
        ])
    ]

    // MARK: - State

    private enum Mode { case title, intro, play, over, win }
    private enum HState { case ground, air, climbUp, climbDown, strike, hurt, dead, exiting }
    private enum GState { case idle, windup, strike, recover, block, hurt, dead }

    private struct Guard {
        var x: Float
        var row: Int
        var hp: Int
        var facing: Float = -1
        var state: GState = .idle
        var timer: Int = 0
        var cooldown: Int = 30
    }

    private struct Pose {
        var lean: Float = 0
        var drop: Float = 0
        var f1x: Float = -2
        var f1y: Float = 0
        var f2x: Float = 2
        var f2y: Float = 0
        var h1x: Float = 1
        var h1y: Float = 10
        var h2x: Float = -1
        var h2y: Float = 10
        var sword: Int = 0
    }

    private struct Rubble {
        var x: Float
        var y: Float
        var vy: Float
        var life: Int
    }

    private var mode: Mode = .title
    private var levelIndex = 0
    private var tick = 0
    private var introTimer = 0

    private var cells: [[Character]] = []
    private var mapW = 0
    private var mapH = 0
    private var fallen = Set<Int>()
    private var looseTimers: [Int: Int] = [:]
    private var gateTimer = 0
    private var gateOpen: Float = 0
    private var guards: [Guard] = []
    private var rubble: [Rubble] = []

    private var hx: Float = 24
    private var hy: Float = 0
    private var hvx: Float = 0
    private var hvy: Float = 0
    private var facing: Float = 1
    private var hstate: HState = .ground
    private var htimer = 0
    private var anim: Float = 0
    private var hp = 3
    private let maxHp = 5
    private var hasSword = false
    private var isJump = false
    private var softFall = false
    private var startRow = 0
    private var blocking = false
    private var invuln = 0
    private var careful = false
    private var strikeResolved = false
    private var climbFromX: Float = 0
    private var climbFromY: Float = 0
    private var climbToX: Float = 0
    private var climbToY: Float = 0
    private var stepTimer = 0

    private var points = 0
    private var kills = 0
    private var timeFrames = 30 * 60 * 60
    private var rng = Rng()

    override var score: Int { return points }

    override func start() {
        playMusic(Tunes.desert)
    }

    // MARK: - Setup

    private func startGame() {
        levelIndex = 0
        points = 0
        kills = 0
        hasSword = false
        hp = 3
        timeFrames = 30 * 60 * 60
        loadLevel(levelIndex)
        mode = .intro
        introTimer = 110
        play(.confirm)
    }

    private func loadLevel(_ index: Int) {
        let def = DesertPrince.levels[min(max(index, 0), DesertPrince.levels.count - 1)]
        var width = 0
        for r in def.rows { width = max(width, r.count) }
        mapW = width
        mapH = def.rows.count
        cells = []
        for r in def.rows {
            var line = Array(r)
            while line.count < width { line.append(" ") }
            cells.append(line)
        }
        fallen = []
        looseTimers = [:]
        gateTimer = 0
        gateOpen = 0
        guards = []
        rubble = []
        var startCol = 1
        var startRowFound = mapH - 1
        for r in 0..<mapH {
            for c in 0..<mapW {
                let ch = cells[r][c]
                if ch == "S" {
                    startCol = c
                    startRowFound = r
                    cells[r][c] = "."
                } else if ch == "G" {
                    let g = Guard(x: Float(c * DesertPrince.cellW + 8), row: r, hp: 2 + index)
                    guards.append(g)
                    cells[r][c] = "."
                }
            }
        }
        hx = Float(startCol * DesertPrince.cellW + 8)
        hy = surface(startRowFound)
        hvx = 0
        hvy = 0
        facing = 1
        hstate = .ground
        htimer = 0
        invuln = 0
        blocking = false
        isJump = false
        softFall = false
        hp = max(hp, 3)
        stepTimer = 0
        playMusic(Tunes.desert)
    }

    private func restartLevel() {
        hp = 3
        loadLevel(levelIndex)
    }

    // MARK: - Map queries

    private func cell(_ c: Int, _ r: Int) -> Character {
        if r < 0 || r >= mapH || c < 0 || c >= mapW { return " " }
        return cells[r][c]
    }

    private func floorAt(_ c: Int, _ r: Int) -> Bool {
        if r < 0 || r >= mapH || c < 0 || c >= mapW { return false }
        if fallen.contains(r * 100 + c) { return false }
        let ch = cells[r][c]
        return ch != " "
    }

    private func isWall(_ c: Int, _ r: Int) -> Bool {
        if c < 0 || c >= mapW { return true }
        if r < 0 || r >= mapH { return false }
        let ch = cells[r][c]
        if ch == "#" { return true }
        if ch == "D" && gateOpen < 0.6 { return true }
        return false
    }

    private func spikePhase(_ c: Int, _ r: Int) -> Int {
        let u = (tick + c * 17 + r * 31) % 150
        if u < 70 { return 0 }
        if u < 85 { return 1 }
        if u < 130 { return 2 }
        return 1
    }

    // MARK: - Update

    override func update(_ input: InputState) {
        tick += 1
        switch mode {
        case .title:
            if input.aPressed || input.startPressed { startGame() }
        case .intro:
            introTimer -= 1
            if introTimer <= 0 { mode = .play }
        case .play:
            updatePlay(input)
        case .over, .win:
            if input.aPressed || input.startPressed {
                mode = .title
                playMusic(Tunes.desert)
            }
        }
    }

    private func updatePlay(_ input: InputState) {
        timeFrames -= 1
        if timeFrames <= 0 {
            mode = .over
            play(.lose)
            return
        }
        if invuln > 0 { invuln -= 1 }
        if gateTimer > 0 {
            gateTimer -= 1
            gateOpen = min(1, gateOpen + 0.04)
        } else {
            gateOpen = max(0, gateOpen - 0.05)
        }
        updateLoose()
        updateRubble()

        switch hstate {
        case .ground: updateGround(input)
        case .air: updateAir(input)
        case .climbUp: updateClimbUp()
        case .climbDown: updateClimbDown()
        case .strike: updateStrike()
        case .hurt:
            htimer -= 1
            if htimer <= 0 { hstate = .ground }
        case .dead:
            htimer += 1
            if htimer > 110 { restartLevel() }
        case .exiting:
            htimer += 1
            hx += facing * 0.5
            anim += 0.1
            if htimer > 45 { levelClear() }
        }
        updateGuards()
    }

    private func updateLoose() {
        for key in Array(looseTimers.keys) {
            let t = (looseTimers[key] ?? 0) - 1
            if t <= 0 {
                looseTimers[key] = nil
                fallen.insert(key)
                let c = key % 100
                let r = key / 100
                for k in 0..<4 {
                    let rx = Float(c * DesertPrince.cellW + 3 + k * 4)
                    rubble.append(Rubble(x: rx, y: surface(r), vy: Float(k) * 0.3, life: 40))
                }
                play(.thud)
            } else {
                looseTimers[key] = t
            }
        }
    }

    private func updateRubble() {
        var i = 0
        while i < rubble.count {
            rubble[i].vy += 0.35
            rubble[i].y += rubble[i].vy
            rubble[i].life -= 1
            if rubble[i].life <= 0 { rubble.remove(at: i) } else { i += 1 }
        }
    }

    // MARK: Hero: ground

    private func fightTarget() -> Int? {
        if hstate == .air || hstate == .dead { return nil }
        let row = rowOf(hy)
        var best: Int? = nil
        var bestDist: Float = 70
        for i in 0..<guards.count {
            if guards[i].state == .dead || guards[i].row != row { continue }
            let d = abs(guards[i].x - hx)
            if d < bestDist {
                bestDist = d
                best = i
            }
        }
        return best
    }

    private func updateGround(_ input: InputState) {
        let col = colOf(hx)
        let row = rowOf(hy)
        let target = fightTarget()
        let fighting = (target != nil) && hasSword
        blocking = false
        careful = false

        if let gi = target, hasSword {
            facing = guards[gi].x > hx ? 1 : -1
        }

        applyCellEffects(col, row)
        if hstate != .ground { return }

        if fighting {
            if input.bPressed {
                hstate = .strike
                htimer = 0
                strikeResolved = false
                play(.sword)
                // Guards may raise a block in response.
                if let gi = target, guards[gi].state == .idle || guards[gi].state == .recover {
                    if rng.chance(35) {
                        guards[gi].state = .block
                        guards[gi].timer = 16
                    }
                }
                return
            }
            blocking = input.a
        } else {
            if input.aPressed && hstate == .ground {
                let dir = input.dx != 0 ? Float(input.dx) : (abs(hvx) > 0.3 ? (hvx > 0 ? Float(1) : Float(-1)) : Float(0))
                if dir != 0 {
                    facing = dir
                    hvx = dir * (abs(hvx) > 1.2 ? 2.2 : 1.8)
                    hvy = -4.2
                } else {
                    hvx = 0
                    hvy = -3.6
                }
                isJump = true
                softFall = false
                startRow = row
                hstate = .air
                play(.jump)
                return
            }
            if input.upPressed {
                if cell(col, row) == "X" {
                    hstate = .exiting
                    htimer = 0
                    hvx = 0
                    play(.confirm)
                    return
                }
                if tryClimbUp(col, row) { return }
            }
            if input.downPressed && tryClimbDown(col, row) { return }
        }

        // Walking
        let dir = input.dx
        var speed: Float = 1.7
        if fighting { speed = 0.7 }
        if input.b && !fighting {
            careful = true
            speed = 0.6
        }
        var target_vx: Float = 0
        if dir != 0 {
            target_vx = Float(dir) * speed
            if !fighting { facing = Float(dir) }
        }
        hvx += (target_vx - hvx) * 0.4
        if abs(hvx) < 0.05 { hvx = 0 }

        var nx = hx + hvx
        if hvx != 0 {
            let sgn: Float = hvx > 0 ? 1 : -1
            let probe = colOf(nx + sgn * 5)
            if isWall(probe, row) {
                nx = hx
                hvx = 0
            }
            if careful {
                let nc = colOf(nx)
                if !floorAt(nc, row) || isWall(nc, row) {
                    nx = hx
                    hvx = 0
                }
            }
        }
        hx = nx
        anim += abs(hvx) * 0.18
        if abs(hvx) > 0.5 {
            stepTimer += 1
            if stepTimer >= 14 {
                stepTimer = 0
                play(.step)
            }
        }

        // Ran off a ledge?
        let newCol = colOf(hx)
        if !floorAt(newCol, row) {
            hstate = .air
            isJump = false
            softFall = false
            startRow = row
            hvy = 0
            hvx = hvx * 0.5
        }
    }

    private func applyCellEffects(_ col: Int, _ row: Int) {
        let ch = cell(col, row)
        switch ch {
        case "^":
            if spikePhase(col, row) == 2 { die(spikes: true) }
        case "~":
            let key = row * 100 + col
            if looseTimers[key] == nil && !fallen.contains(key) {
                looseTimers[key] = 26
            }
        case "T":
            if gateTimer < 520 {
                gateTimer = 620
                play(.pickup)
            }
        case "H":
            cells[row][col] = "."
            if hp < maxHp { hp += 1 }
            points += 100
            play(.powerup)
        case "W":
            cells[row][col] = "."
            hasSword = true
            points += 300
            play(.powerup)
        default:
            break
        }
    }

    private func tryClimbUp(_ col: Int, _ row: Int) -> Bool {
        if row <= 0 { return false }
        if floorAt(col, row - 1) || isWall(col, row - 1) { return false }
        let dirs: [Int] = facing > 0 ? [1, -1] : [-1, 1]
        for d in dirs {
            let tc = col + d
            if floorAt(tc, row - 1) && !isWall(tc, row - 1) {
                climbFromX = hx
                climbFromY = hy
                climbToX = Float(tc * DesertPrince.cellW + 8)
                climbToY = surface(row - 1)
                facing = Float(d)
                hstate = .climbUp
                htimer = 0
                play(.jump)
                return true
            }
        }
        return false
    }

    private func tryClimbDown(_ col: Int, _ row: Int) -> Bool {
        let d: Int = facing > 0 ? 1 : -1
        let nc = col + d
        if floorAt(nc, row) || isWall(nc, row) { return false }
        if row + 1 >= mapH + 1 { return false }
        climbFromX = hx
        climbFromY = hy
        climbToX = Float(col * DesertPrince.cellW + (d > 0 ? 17 : -1))
        climbToY = hy + 22
        hstate = .climbDown
        htimer = 0
        hvx = 0
        play(.step)
        return true
    }

    // MARK: Hero: air / climbing / combat

    private func updateAir(_ input: InputState) {
        let prevY = hy
        hvy = min(hvy + 0.35, 7)
        if isJump {
            let sgn: Float = hvx > 0 ? 1 : -1
            let nx = hx + hvx
            if hvx != 0 && isWall(colOf(nx + sgn * 5), rowOf(hy - 8)) {
                hvx = 0
            } else {
                hx = nx
            }
        } else {
            hvx *= 0.9
            let sgn: Float = hvx > 0 ? 1 : -1
            let nx = hx + hvx
            if hvx != 0 && isWall(colOf(nx + sgn * 5), rowOf(hy - 8)) { hvx = 0 } else { hx = nx }
        }
        hy += hvy
        anim += 0.05

        if hvy > 0 {
            let r0 = rowOf(prevY)
            let r1 = rowOf(hy)
            let c = colOf(hx)
            if r1 >= r0 {
                for r in r0...r1 {
                    if floorAt(c, r) && !isWall(c, r) && prevY <= surface(r) + 0.5 && hy >= surface(r) {
                        land(r)
                        return
                    }
                }
            }
        }
        if hy > Float(mapH * DesertPrince.cellH + 90) {
            die(spikes: false)
        }
    }

    private func land(_ r: Int) {
        hy = surface(r)
        hvy = 0
        let rows = r - startRow
        var dmg = max(0, rows - 1)
        if softFall { dmg = max(0, dmg - 1) }
        isJump = false
        softFall = false
        hvx = 0
        let col = colOf(hx)
        if cell(col, r) == "^" && spikePhase(col, r) == 2 {
            die(spikes: true)
            return
        }
        if dmg > 0 {
            hp -= dmg
            play(.hurt)
            if hp <= 0 {
                hp = 0
                die(spikes: false)
                return
            }
            hstate = .hurt
            htimer = 18
        } else {
            hstate = .ground
            if rows > 0 { play(.thud) } else { play(.step) }
        }
    }

    private func updateClimbUp() {
        htimer += 1
        let t = min(1, Float(htimer) / 28)
        let ease = t * t * (3 - 2 * t)
        hy = climbFromY + (climbToY - climbFromY) * ease
        if t > 0.5 {
            let k = (t - 0.5) * 2
            hx = climbFromX + (climbToX - climbFromX) * k
        }
        if htimer >= 28 {
            hx = climbToX
            hy = climbToY
            hstate = .ground
            hvx = 0
        }
    }

    private func updateClimbDown() {
        htimer += 1
        let t = min(1, Float(htimer) / 20)
        hx = climbFromX + (climbToX - climbFromX) * min(1, t * 2)
        hy = climbFromY + (climbToY - climbFromY) * t
        if htimer >= 24 {
            hstate = .air
            isJump = false
            softFall = true
            startRow = rowOf(climbFromY)
            hvy = 0
            hvx = 0
        }
    }

    private func updateStrike() {
        htimer += 1
        if htimer == 6 && !strikeResolved {
            strikeResolved = true
            for i in 0..<guards.count {
                if guards[i].state == .dead || guards[i].row != rowOf(hy) { continue }
                let dx = guards[i].x - hx
                if dx * facing > 0 && abs(dx) < 28 {
                    if guards[i].state == .block {
                        play(.hit)
                        guards[i].state = .idle
                    } else {
                        guards[i].hp -= 1
                        guards[i].x += facing * 5
                        play(.hit)
                        if guards[i].hp <= 0 {
                            guards[i].state = .dead
                            kills += 1
                            points += 250
                            play(.stomp)
                        } else {
                            guards[i].state = .hurt
                            guards[i].timer = 14
                        }
                    }
                }
            }
        }
        if htimer >= 18 { hstate = .ground }
    }

    private func hurtHero(_ dmg: Int, from dir: Float) {
        if invuln > 0 || hstate == .dead || hstate == .exiting { return }
        hp -= dmg
        invuln = 50
        play(.hurt)
        if hp <= 0 {
            hp = 0
            die(spikes: false)
            return
        }
        let nx = hx + dir * 5
        if !isWall(colOf(nx + dir * 5), rowOf(hy)) { hx = nx }
        if hstate == .ground || hstate == .strike {
            hstate = .hurt
            htimer = 12
        }
    }

    private func die(spikes: Bool) {
        if hstate == .dead { return }
        hstate = .dead
        htimer = 0
        hvx = 0
        play(spikes ? .hit : .death)
        playMusic(nil)
        if spikes { play(.death) }
    }

    private func levelClear() {
        let seconds = timeFrames / 60
        points += 1000 + seconds
        levelIndex += 1
        hp = min(maxHp, hp + 1)
        if levelIndex >= DesertPrince.levels.count {
            mode = .win
            playMusic(nil)
            play(.win)
        } else {
            loadLevel(levelIndex)
            mode = .intro
            introTimer = 110
        }
    }

    // MARK: Guards

    private func updateGuards() {
        let heroRow = rowOf(hy)
        for i in 0..<guards.count {
            var g = guards[i]
            if g.state == .dead {
                guards[i] = g
                continue
            }
            if g.timer > 0 { g.timer -= 1 }
            if g.cooldown > 0 { g.cooldown -= 1 }
            let dx = hx - g.x
            let dist = abs(dx)
            let sameRow = (g.row == heroRow) && hstate != .air && hstate != .dead
            if sameRow && dist < 110 { g.facing = dx > 0 ? 1 : -1 }

            switch g.state {
            case .idle:
                if sameRow && dist < 110 {
                    if dist > 26 {
                        let nx = g.x + g.facing * 0.55
                        let nc = colOf(nx + g.facing * 4)
                        if floorAt(nc, g.row) && !isWall(nc, g.row) { g.x = nx }
                    } else if g.cooldown == 0 {
                        g.state = .windup
                        g.timer = 10
                    }
                }
            case .windup:
                if g.timer <= 0 {
                    g.state = .strike
                    g.timer = 8
                    if sameRow && dist < 30 {
                        if blocking && (g.x - hx) * facing > 0 {
                            play(.hit)
                            g.state = .recover
                            g.timer = 30
                        } else {
                            hurtHero(1, from: g.facing)
                        }
                    }
                }
            case .strike:
                if g.timer <= 0 {
                    g.state = .recover
                    g.timer = 14
                    g.cooldown = 40 + rng.int(30)
                }
            case .recover:
                if g.timer <= 0 { g.state = .idle }
            case .block:
                if g.timer <= 0 { g.state = .idle }
            case .hurt:
                if g.timer <= 0 { g.state = .idle }
            case .dead:
                break
            }
            guards[i] = g
        }
    }

    // MARK: - Drawing

    override func draw(_ c: Canvas) {
        c.clear(0)
        switch mode {
        case .title:
            drawTitle(c)
            return
        case .intro:
            drawIntro(c)
            return
        default:
            break
        }
        let roomX = max(0, colOf(hx)) / DesertPrince.roomCols
        let roomY = max(0, rowOf(hy)) / DesertPrince.roomRows
        c.cameraX = roomX * 160
        c.cameraY = roomY * 132
        drawRoom(c, roomX, roomY)
        drawGuards(c, roomX, roomY)
        drawHero(c)
        for r in rubble {
            c.fillRect(Int(r.x), Int(r.y), 3, 3, 6)
        }
        c.cameraX = 0
        c.cameraY = 0
        drawHUD(c)
        if mode == .over {
            c.fillRect(20, 50, 120, 36, 23)
            c.strokeRect(20, 50, 120, 36, 24)
            c.textCentered("THE SANDS RUN OUT", y: 56, 24)
            c.textCentered("PRESS A", y: 72, 24)
        } else if mode == .win {
            c.fillRect(10, 40, 140, 60, 23)
            c.strokeRect(10, 40, 140, 60, 22)
            c.textCentered("YOU ESCAPED!", y: 48, 22, scale: 2)
            c.textCentered("SCORE " + zeroPad(points, 6), y: 70, 24)
            c.textCentered("FOES FELLED " + String(kills), y: 80, 24)
            c.textCentered("PRESS A", y: 90, 24)
        }
    }

    private func drawTitle(_ c: Canvas) {
        c.clear(0)
        // Stars
        for i in 0..<18 {
            let sx = (i * 37 + 11) % 160
            let sy = (i * 23 + 5) % 70
            if (tick / 20 + i) % 5 != 0 { c.setPixel(sx, sy, 24) }
        }
        // Moon
        c.fillCircle(124, 28, 12, 16)
        c.fillCircle(130, 25, 11, 0)
        // Skyline
        c.fillRect(0, 100, 160, 44, 3)
        for i in 0..<5 {
            let bx = 10 + i * 34
            c.fillRect(bx, 84 - (i % 3) * 8, 18, 60, 2)
            c.fillCircle(bx + 9, 84 - (i % 3) * 8, 9, 2)
            c.vline(bx + 9, 66 - (i % 3) * 8, 6, 4)
        }
        c.fillRect(0, 120, 160, 24, 6)
        c.hline(0, 120, 160, 5)
        let p = Pose()
        drawFigure(c, 80, 120, 1, p, 8, 9, 10, 8, 11)
        c.textCentered("DESERT", y: 14, 22, scale: 2)
        c.textCentered("PRINCE", y: 30, 22, scale: 2)
        if (tick / 24) % 2 == 0 { c.textCentered("PRESS A", y: 56, 24) }
    }

    private func drawIntro(_ c: Canvas) {
        c.clear(23)
        c.textCentered("LEVEL " + String(levelIndex + 1), y: 48, 24, scale: 2)
        c.textCentered(DesertPrince.levels[min(levelIndex, DesertPrince.levels.count - 1)].name, y: 68, 22)
        c.textCentered("30 MINUTES TO ESCAPE", y: 88, 24)
        if levelIndex == 0 {
            c.textCentered("A JUMP  B CAREFUL STEP", y: 104, 20)
            c.textCentered("UP CLIMB OR EXIT", y: 112, 20)
        }
    }

    private func drawRoom(_ c: Canvas, _ roomX: Int, _ roomY: Int) {
        let ox = roomX * 160
        let oy = roomY * 132
        // Back wall
        c.fillRect(ox, oy, 160, 132, 0)
        var row = 0
        var y = oy
        while y < oy + 132 {
            c.hline(ox, y, 160, 1)
            let shift = (row % 2) * 8
            var x = ox + shift
            while x < ox + 160 {
                c.vline(x, y, 11, 1)
                x += 16
            }
            y += 11
            row += 1
        }
        for lr in 0..<DesertPrince.roomRows {
            for lc in 0..<DesertPrince.roomCols {
                let col = roomX * DesertPrince.roomCols + lc
                let r = roomY * DesertPrince.roomRows + lr
                drawCell(c, col, r, ox + lc * 16, oy + lr * 44)
            }
        }
    }

    private func drawCell(_ c: Canvas, _ col: Int, _ r: Int, _ x: Int, _ y: Int) {
        let ch = cell(col, r)
        let ysurf = y + DesertPrince.cellH - 6
        // Torches on some back walls
        if ch == " " || ch == "." {
            if (col * 7 + r * 5) % 11 == 0 {
                c.fillRect(x + 7, y + 12, 2, 6, 27)
                c.fillRect(x + 6, y + 10 - ((tick / 4) % 2), 4, 3, 15)
                c.fillRect(x + 7, y + 8 - ((tick / 3) % 2), 2, 3, 16)
            }
        }
        if ch == "#" {
            c.fillRect(x, y, 16, 44, 2)
            c.vline(x, y, 44, 4)
            c.vline(x + 15, y, 44, 3)
            var by = y
            var rowIdx = 0
            while by < y + 44 {
                c.hline(x, by, 16, 3)
                c.vline(x + 4 + (rowIdx % 2) * 8, by, 8, 3)
                by += 8
                rowIdx += 1
            }
            return
        }
        if !floorAt(col, r) { return }
        // Floor slab
        var shake = 0
        if ch == "~", let t = looseTimers[r * 100 + col], t > 0 { shake = tick % 2 }
        c.fillRect(x + shake, ysurf, 16, 3, 5)
        c.fillRect(x + shake, ysurf + 3, 16, 3, 6)
        c.vline(x + 15 + shake, ysurf, 6, 7)
        if ch == "~" {
            c.hline(x + 3, ysurf + 1, 5, 7)
            c.hline(x + 9, ysurf + 4, 4, 7)
        }
        switch ch {
        case "^":
            let h = [0, 4, 11][spikePhase(col, r)]
            if h > 0 {
                for k in 0..<4 {
                    for hh in 0..<h {
                        let w = max(1, 3 - (hh * 3) / h)
                        c.fillRect(x + 1 + k * 4 + (3 - w) / 2, ysurf - 1 - hh, w, 1, 17)
                    }
                }
            }
            c.fillRect(x, ysurf - 1, 16, 1, 7)
        case "T":
            c.fillRect(x + 3, ysurf - 2, 10, 2, 28)
            c.fillRect(x + 3, ysurf - 2, 10, 1, 22)
        case "D":
            let open = gateOpen
            let h = Int(Float(38) * (1 - open)) + 4
            c.fillRect(x + 1, y, 14, 3, 20)
            for k in 0..<3 {
                c.fillRect(x + 3 + k * 4, y + 3, 2, h, 20)
            }
        case "H":
            let bob = ((tick / 12) % 2)
            c.fillRect(x + 5, ysurf - 8 - bob, 6, 6, 18)
            c.fillRect(x + 7, ysurf - 11 - bob, 2, 3, 19)
            c.setPixel(x + 6, ysurf - 7 - bob, 19)
        case "W":
            c.vline(x + 8, ysurf - 13, 12, 27)
            c.hline(x + 6, ysurf - 3, 5, 22)
        case "X":
            c.fillRect(x + 1, ysurf - 38, 14, 38, 22)
            c.fillRect(x + 3, ysurf - 36, 10, 36, hstate == .exiting ? 23 : 21)
            c.fillCircle(x + 8, ysurf - 36, 5, 22)
            c.fillCircle(x + 8, ysurf - 36, 3, hstate == .exiting ? 23 : 21)
            c.fillRect(x + 11, ysurf - 18, 1, 2, 22)
        default:
            break
        }
    }

    private func drawGuards(_ c: Canvas, _ roomX: Int, _ roomY: Int) {
        for g in guards {
            let gx = Int(g.x)
            if gx / 160 != roomX || g.row / 3 != roomY { continue }
            let gy = Int(surface(g.row))
            if g.state == .dead {
                drawLying(c, gx, gy, g.facing, 12, 9, 13)
                continue
            }
            var p = Pose()
            switch g.state {
            case .idle:
                let moving = abs(hx - g.x) < 110 && abs(hx - g.x) > 26
                if moving {
                    let s = sin(Float(tick) * 0.2)
                    p.f1x = s * 4
                    p.f2x = -s * 4
                }
                p.sword = 1
                p.h1x = 6
                p.h1y = 6
            case .windup:
                p.sword = 3
                p.h1x = 4
                p.h1y = 2
                p.lean = -2
            case .strike:
                p.sword = 2
                p.h1x = 12
                p.h1y = 3
                p.lean = 4
                p.f1x = 6
                p.f2x = -3
            case .recover:
                p.sword = 1
                p.h1x = 6
                p.h1y = 6
            case .block:
                p.sword = 3
                p.h1x = 5
                p.h1y = 0
            case .hurt:
                p.lean = -3
                p.sword = 1
                p.h1x = 4
                p.h1y = 8
            case .dead:
                break
            }
            drawFigure(c, gx, gy, g.facing, p, 12, 9, 13, 14, 13)
        }
    }

    private func heroPose() -> Pose {
        var p = Pose()
        switch hstate {
        case .ground:
            let fighting = fightTarget() != nil && hasSword
            if fighting {
                p.f1x = 6
                p.f2x = -3
                p.lean = 1
                p.sword = blocking ? 3 : 1
                p.h1x = blocking ? 5 : 6
                p.h1y = blocking ? 0 : 6
                p.h2x = -2
                p.h2y = 4
            } else if abs(hvx) > 0.2 {
                let amp: Float = careful ? 3 : 6
                let s = sin(anim)
                let co = cos(anim)
                p.f1x = s * amp
                p.f1y = -max(0, co) * (careful ? 2 : 4)
                p.f2x = -s * amp
                p.f2y = -max(0, -co) * (careful ? 2 : 4)
                p.h1x = -s * (amp - 1)
                p.h1y = 9 - abs(co)
                p.h2x = s * (amp - 1)
                p.h2y = 9 - abs(co)
                p.lean = careful ? 0 : 2
                p.drop = 1 + abs(s)
            }
        case .air:
            if isJump {
                p.f1x = 5
                p.f1y = -8
                p.f2x = -3
                p.f2y = -5
                p.h1x = 6
                p.h1y = -5
                p.h2x = -4
                p.h2y = -3
                p.lean = 2
            } else {
                p.f1x = 4
                p.f1y = -2
                p.f2x = -4
                p.f2y = -2
                p.h1x = 5
                p.h1y = -6
                p.h2x = -5
                p.h2y = -6
            }
        case .climbUp:
            let t = Float(htimer) / 28
            if t < 0.5 {
                p.h1x = 3
                p.h1y = -9
                p.h2x = -1
                p.h2y = -9
                p.f1x = -1
                p.f2x = 1
                p.f2y = -2
            } else {
                p.drop = 5
                p.lean = 3
                p.h1x = 4
                p.h1y = -2
                p.h2x = 0
                p.h2y = 0
                p.f1x = 3
                p.f2x = -3
            }
        case .climbDown:
            p.h1x = 3
            p.h1y = -9
            p.h2x = -1
            p.h2y = -9
            p.f1x = -1
            p.f2x = 1
        case .strike:
            let t = htimer
            p.f1x = 6
            p.f2x = -3
            p.sword = t < 6 ? 3 : 2
            p.h1x = t < 6 ? 4 : 12
            p.h1y = t < 6 ? 2 : 3
            p.lean = t < 6 ? -1 : 4
        case .hurt:
            p.lean = -3
            p.h1x = -2
            p.h1y = 4
            p.h2x = -4
            p.h2y = 6
        case .dead:
            break
        case .exiting:
            let s = sin(anim * 3)
            p.f1x = s * 5
            p.f2x = -s * 5
            p.lean = 1
        }
        return p
    }

    private func drawHero(_ c: Canvas) {
        let x = Int(hx)
        let y = Int(hy)
        if hstate == .dead {
            drawLying(c, x, y, facing, 8, 9, 10)
            return
        }
        if invuln > 0 && (invuln / 3) % 2 == 0 && hstate != .exiting { return }
        var fade = false
        if hstate == .exiting && htimer > 30 { fade = true }
        if fade { return }
        drawFigure(c, x, y, facing, heroPose(), 8, 9, 10, 8, 11)
    }

    private func drawLying(_ c: Canvas, _ x: Int, _ y: Int, _ f: Float, _ robe: Int, _ skin: Int, _ sash: Int) {
        let d = f >= 0 ? 1 : -1
        c.fillRect(min(x, x + d * 16), y - 5, 17, 4, robe)
        c.fillRect(min(x + d * 7, x + d * 9), y - 5, 3, 4, sash)
        c.fillCircle(x + d * 18, y - 4, 3, skin)
        c.fillRect(min(x - d * 2, x), y - 2, 3, 2, 11)
        c.hline(min(x - d * 6, x - d * 10), y - 1, 5, 25)
    }

    private func thick(_ c: Canvas, _ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ color: Int) {
        c.line(x0, y0, x1, y1, color)
        c.line(x0 + 1, y0, x1 + 1, y1, color)
    }

    private func drawFigure(_ c: Canvas, _ x: Int, _ y: Int, _ face: Float, _ p: Pose,
                            _ robe: Int, _ skin: Int, _ sash: Int, _ turban: Int, _ trim: Int) {
        let d: Int = face >= 0 ? 1 : -1
        func px(_ v: Float) -> Int { return x + d * Int(v.rounded()) }
        func py(_ v: Float) -> Int { return y + Int(v.rounded()) }
        let hipY: Float = -13 + p.drop
        let shY: Float = -23 + p.drop
        let shX: Float = p.lean

        // Far leg and arm first (darker), then body, then near limbs.
        thick(c, px(0), py(hipY), px(p.f2x), py(p.f2y), trim)
        thick(c, px(shX), py(shY + 1), px(shX + p.h2x), py(shY + p.h2y), trim)

        for t in 0...10 {
            let yy = hipY - Float(t)
            let off = shX * Float(t) / 10
            let xa = px(off - 3)
            let xb = px(off + 3)
            c.fillRect(min(xa, xb), py(yy), abs(xb - xa) + 1, 1, robe)
        }
        let sxa = px(0 - 3)
        let sxb = px(0 + 3)
        c.fillRect(min(sxa, sxb), py(hipY - 1), abs(sxb - sxa) + 1, 2, sash)

        thick(c, px(0), py(hipY), px(p.f1x), py(p.f1y), robe)
        c.setPixel(px(p.f1x) + d, py(p.f1y), skin)
        c.setPixel(px(p.f2x) + d, py(p.f2y), skin)

        let handX = shX + p.h1x
        let handY = shY + p.h1y
        thick(c, px(shX), py(shY + 1), px(handX), py(handY), robe)
        c.setPixel(px(handX), py(handY), skin)
        if p.sword > 0 {
            var tipX = handX + 10
            var tipY = handY - 3
            if p.sword == 2 {
                tipX = handX + 14
                tipY = handY
            } else if p.sword == 3 {
                tipX = handX + 3
                tipY = handY - 12
            }
            c.line(px(handX), py(handY), px(tipX), py(tipY), 27)
            c.setPixel(px(handX), py(handY) - 1, 22)
            c.setPixel(px(handX), py(handY) + 1, 22)
        }

        let headX = shX + 1
        let headY = shY - 5
        c.fillCircle(px(headX), py(headY + 1), 3, skin)
        c.fillCircle(px(headX), py(headY - 1), 3, turban)
        c.hline(px(headX) - 3, py(headY) + 0, 7, trim)
        c.setPixel(px(headX) + d * 2, py(headY + 1), 0)
    }

    private func drawHUD(_ c: Canvas) {
        c.fillRect(0, 132, 160, 12, 23)
        c.hline(0, 132, 160, 14)
        for i in 0..<maxHp {
            let x = 4 + i * 8
            if i < hp {
                c.fillRect(x, 136, 5, 1, 25)
                c.fillRect(x + 1, 137, 3, 1, 25)
                c.fillRect(x + 2, 138, 1, 1, 25)
            } else {
                c.fillRect(x, 136, 5, 1, 26)
                c.fillRect(x + 1, 137, 3, 1, 26)
                c.fillRect(x + 2, 138, 1, 1, 26)
            }
        }
        let secs = max(0, timeFrames / 60)
        let timeText = String(secs / 60) + ":" + zeroPad(secs % 60, 2)
        c.text(timeText, 62, 136, 24)
        c.text("L" + String(levelIndex + 1), 90, 136, 22)
        if let gi = fightTarget() {
            let g = guards[gi]
            for i in 0..<max(0, g.hp) {
                let x = 150 - i * 6
                c.fillRect(x, 136, 3, 1, 15)
                c.fillRect(x + 1, 137, 1, 1, 15)
            }
        }
    }
}

extension Cartridge {
    static let desertPrince = Cartridge(
        id: "prince", title: "DESERT PRINCE", genre: "Cinematic Platformer",
        blurb: "Escape the palace dungeons in thirty minutes. Time your running jumps, climb to hidden ledges, dodge spikes and crumbling floors, and duel the guards.",
        controls: "LEFT/RIGHT run. Hold B for careful steps. A jump. UP climb a ledge or enter the door. DOWN hang off an edge. With a sword: B strike, A block.",
        era: .gbc, labelTop: 0xD79B3A, labelBottom: 0x5A2A6A, factory: { DesertPrince() })
}
