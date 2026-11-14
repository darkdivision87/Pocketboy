#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// TYCOON TOWN: an original roll-and-build property board game on a floating isometric city board.
/// This file holds the state machine, economy, AI and persistence. TycoonData.swift has tables and the rasteriser,
/// TycoonDraw.swift has all of the drawing.

enum TycoonPhase {
    case title, how, intro, menu, roll, rolling, hop, prompt, card, wait, results
}

struct TycoonPlayer {
    var token: Int = 0
    var skin: Int = 0
    var hat: Int = 0
    var ai: Bool = false
    var persona: Int = 0
    var cash: Int = 1500
    var shown: Float = 1500
    var pos: Int = 0
    var vis: Float = 0
    var skip: Int = 0
    var bankrupt: Bool = false
    var squash: Float = 0
}

struct TycoonPart {
    var x: Float = 0
    var y: Float = 0
    var z: Float = 0
    var vx: Float = 0
    var vy: Float = 0
    var vz: Float = 0
    var life: Int = 0
    var maxLife: Int = 1
    var kind: Int = 0
    var col: UInt32 = 0xFFFF_FFFF
    var size: Float = 2
    var spin: Float = 0
}

struct TycoonFloat {
    var text: String = ""
    var amt: Int = 0
    var x: Float = 0
    var y: Float = 0
    var life: Int = 0
    var col: UInt32 = 0xFFFF_FFFF
}

struct TycoonFly {
    var sx: Float = 0
    var sy: Float = 0
    var ex: Float = 0
    var ey: Float = 0
    var t: Float = 0
    var delay: Int = 0
    var active: Bool = false
}

final class TycoonTown64: Game {
    static let diceDur = 74
    static let hopFrames = 12

    // MARK: - State

    var phase: TycoonPhase = .title
    var phaseT: Int = 0
    var frame: Int = 0
    var rng = Rng()
    var players: [TycoonPlayer] = [TycoonPlayer(), TycoonPlayer(), TycoonPlayer(), TycoonPlayer()]
    var tOwner = [Int](repeating: -1, count: 32)
    var tLevel = [Int](repeating: 0, count: 32)
    var tAnim = [Float](repeating: 99, count: 32)
    var cur: Int = 0
    var round: Int = 1
    var pot: Int = 50
    var inGame: Bool = false
    var doublesCount: Int = 0
    var rolledDouble: Bool = false
    var chainActive: Bool = false
    var lastTotal: Int = 0

    // dice
    var d1: Int = 1
    var d2: Int = 1
    var diceT: Int = 0
    var diceAxis: [Float] = [0.3, 1.0, 0.2, -0.5, 0.8, 0.4]
    var diceSpin: [Float] = [20, -18]
    var diceYaw: [Float] = [0.3, 1.2]

    // hop
    var hopLeft: Int = 0
    var hopDir: Int = 1
    var hopT: Int = 0
    var hopBase: Int = 0

    // prompt
    var promptKind: Int = 0
    var promptSel: Int = 0
    var promptRec: Int = 0
    var promptT: Int = 0
    var promptTile: Int = 0

    // pre-turn build menu
    var menuList: [Int] = []
    var menuIdx: Int = 0

    // cards
    var curCard = TycoonCard(kind: 0, amt: 0, l1: "", l2: "")
    var cardT: Int = 0
    var cardSurprise: Bool = true

    // wait
    var waitT: Int = 0
    var waitThen: Int = 0

    // messages
    var msgA: String = ""
    var msgB: String = ""

    // camera
    var camX: Float = 0
    var camZ: Float = 0
    var camZoom: Float = 0.64
    var zoomWide: Bool = false
    var pjZoom: Float = 0.64
    var pjX0: Float = 0
    var pjF0: Float = 0
    var pjCY: Float = 132

    // effects
    var parts = [TycoonPart](repeating: TycoonPart(), count: 220)
    var partCursor: Int = 0
    var floats = [TycoonFloat](repeating: TycoonFloat(), count: 12)
    var floatCursor: Int = 0
    var flies = [TycoonFly](repeating: TycoonFly(), count: 48)
    var flyCursor: Int = 0
    var bannerText: String = ""
    var bannerT: Int = 999
    var bannerCol: UInt32 = 0xFFFF_FFFF

    // ambient
    var cloudX: [Float] = [20, 120, 230, 330, 60]
    var cloudY: [Float] = [30, 54, 22, 70, 86]
    var cloudS: [Float] = [1.0, 0.8, 1.2, 0.9, 0.7]
    var cloudV: [Float] = [0.10, 0.07, 0.12, 0.08, 0.05]
    var balX: [Float] = [44, 272, 160]
    var balY: [Float] = [210, 130, 270]

    // overlays
    var ovOpen: Bool = false
    var ovT: Int = 0

    // title
    var titleRow: Int = 0
    var titleT: Int = 0
    var selCount: Int = 3
    var attract: Float = 0

    // how to
    var howPage: Int = 0
    var howT: Int = 0
    var howFromTitle: Bool = true

    // results
    var ranks: [Int] = []
    var wealthList: [Int] = []
    var resT: Int = 0
    var humanWon: Bool = false
    var unlockText: String = ""

    // save
    var sv = TycoonSave()

    // touch
    var ptDown: Bool = false
    var ptX: Int = 0
    var ptY: Int = 0
    var ptSX: Int = 0
    var ptSY: Int = 0
    var ptMoved: Bool = false
    var ptPan: Bool = false
    var panX: Float = 0
    var panY: Float = 0
    var panBX: Float = 0
    var panBY: Float = 0
    var infoTile: Int = -1
    var infoT: Int = 0
    var ovSel: Int = -1

    // MARK: - Game overrides

    override var score: Int {
        var w = 0
        for x in sv.wins { w += x }
        let cw: Int = inGame && players.count > 0 ? wealth(0) : 0
        return max(0, cw) + 1000 * w
    }

    override var wantsPointer: Bool { return true }

    override func start() {
        playMusic(Tunes.puzzle)
        setupAttract()
    }

    override func exportSave() -> [UInt8] {
        return sv.encode()
    }

    override func importSave(_ bytes: [UInt8]) {
        if let s = TycoonSave.decode(bytes) {
            sv = s
        }
    }

    override func drawTrueColor(_ b: TrueColorBuffer) {
        b.withPixels { p, w, h in
            if w != 320 || h != 288 { return }
            let g = TycoonGfx(p: p, w: w, h: h)
            self.render(g)
        }
    }

    // MARK: - Small helpers

    func rf(_ lo: Float, _ hi: Float) -> Float {
        return lo + Float(rng.unit()) * (hi - lo)
    }

    func who(_ i: Int) -> String {
        if i < 0 || i >= players.count { return "THE BANK" }
        if i == 0 { return "YOU" }
        return TycoonBoard.tokenNames[players[i].token % 4]
    }

    func turnText(_ i: Int) -> String {
        if i == 0 { return "YOUR TURN" }
        return who(i) + "'S TURN"
    }

    func setMsg(_ a: String, _ b: String) {
        msgA = a
        msgB = b
    }

    func showBanner(_ t: String, _ c: UInt32) {
        bannerText = t
        bannerT = 0
        bannerCol = c
    }

    func ownedCount(_ p: Int) -> Int {
        var n = 0
        for i in 0..<32 where tOwner[i] == p { n += 1 }
        return n
    }

    func ownsDistrict(_ p: Int, _ d: Int) -> Bool {
        if d < 0 || d >= 8 { return false }
        let list = TycoonBoard.distTiles[d]
        if list.isEmpty { return false }
        for t in list where tOwner[t] != p { return false }
        return true
    }

    func stationsOwned(_ p: Int) -> Int {
        var n = 0
        for i in 0..<32 where tOwner[i] == p && TycoonBoard.tiles[i].kind == TycoonBoard.kStation { n += 1 }
        return n
    }

    func rentFor(_ tile: Int) -> Int {
        if tile < 0 || tile >= 32 { return 0 }
        let t = TycoonBoard.tiles[tile]
        let owner = tOwner[tile]
        if t.kind == TycoonBoard.kStation {
            let cnt = max(1, min(4, stationsOwned(owner)))
            return 25 * (1 << (cnt - 1))
        }
        let lv = max(0, min(5, tLevel[tile]))
        var base = t.price * TycoonBoard.rentMult[lv] / 100
        if lv == 0 && ownsDistrict(owner, t.dist) { base *= 2 }
        return max(2, base)
    }

    func propValue(_ tile: Int) -> Int {
        if tile < 0 || tile >= 32 { return 0 }
        var v = TycoonBoard.tiles[tile].price
        let lv = max(0, min(5, tLevel[tile]))
        if lv >= 1 {
            for l in 1...lv { v += TycoonBoard.buildCost(tile, l) }
        }
        return v
    }

    func wealth(_ p: Int) -> Int {
        if p < 0 || p >= players.count { return 0 }
        if players[p].bankrupt { return 0 }
        var w = players[p].cash
        for i in 0..<32 where tOwner[i] == p { w += propValue(i) }
        return w
    }

    func aliveCount() -> Int {
        var n = 0
        for p in players where !p.bankrupt { n += 1 }
        return n
    }

    func canUpgrade(_ tile: Int, _ pi: Int) -> Bool {
        if tile < 0 || tile >= 32 || pi < 0 || pi >= players.count { return false }
        let t = TycoonBoard.tiles[tile]
        if t.kind != TycoonBoard.kStreet || tOwner[tile] != pi || tLevel[tile] >= 5 { return false }
        let next = tLevel[tile] + 1
        if next >= 5 && !ownsDistrict(pi, t.dist) { return false }
        return players[pi].cash >= TycoonBoard.buildCost(tile, next)
    }

    func isDecision() -> Bool {
        switch phase {
        case .title, .how, .results: return true
        case .menu, .roll, .prompt, .card:
            if cur >= 0 && cur < players.count { return !players[cur].ai }
            return true
        default: return false
        }
    }

    func inGamePhase() -> Bool {
        switch phase {
        case .title, .how, .results: return false
        default: return true
        }
    }

    func humanOut() -> Bool {
        return inGame && players.count > 0 && players[0].bankrupt
    }

    // MARK: - Projection and positions

    func updateProj() {
        pjZoom = camZoom
        pjX0 = (camX - camZ) * 0.70710678 - panX / max(0.3, camZoom)
        pjF0 = -(camX + camZ) * 0.70710678
        pjCY = 132 + panY
    }

    @inline(__always) func pj(_ x: Float, _ y: Float, _ z: Float) -> (Float, Float) {
        let xr: Float = (x - z) * 0.70710678
        let f: Float = -(x + z) * 0.70710678
        let sx: Float = 160 + (xr - pjX0) * pjZoom
        let sy: Float = pjCY - ((f - pjF0) * 0.55 + y * 0.835) * pjZoom
        return (sx, sy)
    }

    static let slotOff: [(Float, Float)] = [(-12, 13), (13, -12), (14, 14), (-14, -6)]

    func tokenWorld(_ i: Int) -> (Float, Float, Float) {
        if i < 0 || i >= players.count { return (0, 0, 0) }
        var v: Float = players[i].vis
        if !(v > -1000 && v < 1000) { v = 0 }
        while v < 0 { v += 32 }
        v = v.truncatingRemainder(dividingBy: 32)
        var i0 = tycFloorI(v)
        i0 = max(0, min(31, i0))
        let fr: Float = max(0, min(1, v - Float(i0)))
        let i1 = (i0 + 1) % 32
        let off = TycoonTown64.slotOff[i % 4]
        let x: Float = TycoonBoard.tx[i0] + (TycoonBoard.tx[i1] - TycoonBoard.tx[i0]) * fr + off.0
        let z: Float = TycoonBoard.tz[i0] + (TycoonBoard.tz[i1] - TycoonBoard.tz[i0]) * fr + off.1
        var y: Float = TycoonBoard.tileH
        if fr > 0.001 { y += 16 * sin(Float.pi * fr) }
        return (x, y, z)
    }

    func tokenScreen(_ i: Int) -> (Float, Float) {
        let w = tokenWorld(i)
        let s = pj(w.0, w.1 + 12, w.2)
        return (s.0, s.1)
    }

    func slotW() -> Int {
        return 320 / max(1, players.count)
    }

    func slotCenter(_ i: Int) -> (Float, Float) {
        let sw = slotW()
        return (Float(i * sw + sw / 2), 24)
    }

    // MARK: - Effects

    func spawnPart(_ p: TycoonPart) {
        partCursor = (partCursor + 1) % parts.count
        parts[partCursor] = p
    }

    func spawnSparkles(_ x: Float, _ y: Float, _ z: Float, _ n: Int, _ col: UInt32) {
        for _ in 0..<n {
            var p = TycoonPart()
            p.x = x
            p.y = y
            p.z = z
            p.vx = rf(-1.4, 1.4)
            p.vy = rf(0.6, 2.6)
            p.vz = rf(-1.4, 1.4)
            p.life = rng.range(22, 40)
            p.maxLife = p.life
            p.kind = 0
            p.col = rng.chance(50) ? col : TycoonPal.white
            p.size = rf(1.6, 3.2)
            spawnPart(p)
        }
    }

    func spawnDust(_ x: Float, _ y: Float, _ z: Float) {
        for _ in 0..<6 {
            var p = TycoonPart()
            p.x = x
            p.y = y
            p.z = z
            p.vx = rf(-0.9, 0.9)
            p.vy = rf(0.1, 0.5)
            p.vz = rf(-0.9, 0.9)
            p.life = rng.range(14, 24)
            p.maxLife = p.life
            p.kind = 1
            p.col = TycoonPal.h(0xF4EFE2)
            p.size = rf(2.0, 3.6)
            spawnPart(p)
        }
    }

    func spawnConfetti(_ n: Int) {
        let cols: [UInt32] = [TycoonPal.red, TycoonPal.gold, TycoonPal.green, TycoonPal.blue, TycoonPal.pink, TycoonPal.white]
        for _ in 0..<n {
            var p = TycoonPart()
            p.x = rf(0, 320)
            p.y = rf(-50, -4)
            p.vx = rf(-0.6, 0.6)
            p.vy = rf(1.0, 2.4)
            p.life = 260
            p.maxLife = 260
            p.kind = 2
            p.col = cols[rng.int(cols.count)]
            p.size = rf(2.0, 4.0)
            p.spin = rf(0, 6)
            spawnPart(p)
        }
    }

    func spawnFloat(_ text: String, _ amt: Int, _ x: Float, _ y: Float, _ col: UInt32) {
        floatCursor = (floatCursor + 1) % floats.count
        var f = TycoonFloat()
        f.text = text
        f.amt = amt
        f.x = x
        f.y = y
        f.life = 70
        f.col = col
        floats[floatCursor] = f
    }

    func spawnFlies(_ sx: Float, _ sy: Float, _ ex: Float, _ ey: Float, _ n: Int) {
        for k in 0..<n {
            flyCursor = (flyCursor + 1) % flies.count
            var f = TycoonFly()
            f.sx = sx + rf(-6, 6)
            f.sy = sy + rf(-4, 4)
            f.ex = ex + rf(-6, 6)
            f.ey = ey + rf(-3, 3)
            f.t = 0
            f.delay = k * 3
            f.active = true
            flies[flyCursor] = f
        }
    }

    func tickEffects() {
        for i in 0..<parts.count {
            if parts[i].life <= 0 { continue }
            var p = parts[i]
            p.life -= 1
            if p.kind == 2 {
                p.x += p.vx + sin(p.spin) * 0.7
                p.y += p.vy
                p.spin += 0.16
                if p.y > 300 { p.life = 0 }
            } else {
                p.x += p.vx
                p.y += p.vy
                p.z += p.vz
                if p.kind == 0 { p.vy -= 0.10 }
            }
            parts[i] = p
        }
        for i in 0..<floats.count {
            if floats[i].life > 0 {
                floats[i].life -= 1
                floats[i].y -= 0.6
            }
        }
        for i in 0..<flies.count {
            if !flies[i].active { continue }
            if flies[i].delay > 0 {
                flies[i].delay -= 1
                continue
            }
            flies[i].t += 0.04
            if flies[i].t >= 1 {
                flies[i].active = false
            }
        }
        if bannerT < 999 { bannerT += 1 }
        for i in 0..<players.count {
            let diff: Float = Float(players[i].cash) - players[i].shown
            if abs(diff) < 1.5 {
                players[i].shown = Float(players[i].cash)
            } else {
                players[i].shown += diff * 0.12
            }
            if players[i].squash > 0 { players[i].squash = max(0, players[i].squash - 0.05) }
        }
        for i in 0..<32 where tAnim[i] < 60 { tAnim[i] += 1 }
    }

    func updateAmbient() {
        for i in 0..<cloudX.count {
            cloudX[i] += cloudV[i]
            if cloudX[i] > 400 { cloudX[i] = -90 }
        }
        for i in 0..<balY.count {
            balY[i] -= 0.12
            if balY[i] < -30 { balY[i] = 310 }
        }
    }

    func updateCamera() {
        var ctx: Float = 0
        var ctz: Float = 0
        var czm: Float = 0.64
        switch phase {
        case .title, .how, .results:
            ctx = sin(Float(frame) * 0.005) * 24
            ctz = cos(Float(frame) * 0.004) * 16
        case .rolling:
            czm = zoomWide ? 0.64 : 0.95
        case .menu:
            if menuIdx >= 0 && menuIdx < menuList.count {
                let t = menuList[menuIdx]
                ctx = TycoonBoard.tx[t]
                ctz = TycoonBoard.tz[t]
            }
            czm = 1.2
        default:
            let w = tokenWorld(cur)
            ctx = w.0
            ctz = w.2
            czm = 1.15
            if phase == .wait && waitThen == 0 && waitT < 40 {
                ctx = 0
                ctz = 0
                czm = 0.64
            }
        }
        if zoomWide && inGame && phase != .results {
            ctx = 0
            ctz = 0
            czm = 0.64
        }
        let k: Float = 0.075
        camX += (ctx - camX) * k
        camZ += (ctz - camZ) * k
        camZoom += (czm - camZoom) * 0.06
        updateProj()
    }

    // MARK: - Setup

    func resetTiles() {
        for i in 0..<32 {
            tOwner[i] = -1
            tLevel[i] = 0
            tAnim[i] = 99
        }
    }

    func setupAttract() {
        var list: [TycoonPlayer] = []
        for k in 0..<4 {
            var p = TycoonPlayer()
            p.token = k
            p.hat = k == 0 ? sv.hat : (1 + k)
            p.skin = k == 0 ? sv.skin : 0
            p.vis = Float(k * 8)
            list.append(p)
        }
        players = list
        resetTiles()
        for i in 0..<32 {
            let t = TycoonBoard.tiles[i]
            if t.kind == TycoonBoard.kStreet && rng.chance(70) {
                tOwner[i] = rng.int(4)
                tLevel[i] = rng.range(0, 5)
            } else if t.kind == TycoonBoard.kStation && rng.chance(50) {
                tOwner[i] = rng.int(4)
            }
        }
        inGame = false
        phase = .title
        phaseT = 0
        titleT = 0
        cur = 0
    }

    func startGame() {
        let n = max(2, min(4, selCount))
        var list: [TycoonPlayer] = []
        var human = TycoonPlayer()
        human.token = max(0, min(3, sv.token))
        human.hat = sv.hat
        human.skin = sv.skin
        human.ai = false
        human.cash = TycoonBoard.startCash
        human.shown = Float(TycoonBoard.startCash)
        list.append(human)
        var personas: [Int] = [0, 1, 2]
        var k = 2
        while k > 0 {
            let j = rng.int(k + 1)
            let tmp = personas[k]
            personas[k] = personas[j]
            personas[j] = tmp
            k -= 1
        }
        var tk = (human.token + 1) % 4
        for a in 0..<(n - 1) {
            var ai = TycoonPlayer()
            ai.token = tk
            tk = (tk + 1) % 4
            ai.ai = true
            ai.persona = personas[a % 3]
            ai.hat = rng.chance(60) ? 1 + rng.int(6) : 0
            ai.cash = TycoonBoard.startCash
            ai.shown = Float(TycoonBoard.startCash)
            list.append(ai)
        }
        players = list
        resetTiles()
        cur = 0
        round = 1
        pot = 50
        inGame = true
        doublesCount = 0
        rolledDouble = false
        chainActive = false
        bannerT = 999
        zoomWide = false
        camX = 0
        camZ = 0
        camZoom = 0.64
        for i in 0..<players.count {
            players[i].pos = 0
            players[i].vis = 0
        }
        playMusic(Tunes.adventure)
        if sv.how == 0 {
            openHow(false)
        } else {
            beginTurn()
        }
    }

    // MARK: - How to play

    func openHow(_ fromTitle: Bool) {
        howPage = 0
        howT = 0
        howFromTitle = fromTitle
        phase = .how
        phaseT = 0
    }

    func closeHow() {
        sv.how = 1
        if howFromTitle {
            phase = .title
            titleT = 0
        } else {
            beginTurn()
        }
    }

    // MARK: - Main loop

    override func update(_ input: InputState) {
        frame += 1
        updateAmbient()
        let tapped = trackPointer(input.pointer)
        if !(ptDown && ptMoved && ptPan) {
            panX *= 0.9
            panY *= 0.9
            if abs(panX) < 0.3 { panX = 0 }
            if abs(panY) < 0.3 { panY = 0 }
        }
        var inp = input
        if ovOpen {
            ovT += 1
            if tapped { overviewTap(ptX, ptY) }
            if inp.upPressed || inp.downPressed || inp.aPressed || inp.bPressed || ovT > 600 {
                ovOpen = false
            }
            return
        }
        if infoTile >= 0 {
            infoT += 1
            if tapped || infoT > 300 { infoTile = -1 }
            if tapped { return }
        }
        if tapped && bannerT < 80 && ptY >= 66 && ptY < 128 && inGamePhase() {
            bannerT = 999
            return
        }
        if tapped {
            handleTap(ptX, ptY, &inp)
        }
        if ovOpen { return }
        if inGamePhase() {
            if inp.upPressed {
                ovOpen = true
                ovSel = -1
                ovT = 0
                play(.blip)
                return
            }
            if inp.downPressed {
                zoomWide = !zoomWide
                play(.blip)
            }
        }
        var reps = 1
        if (inp.a && !isDecision()) || humanOut() { reps = 2 }
        if humanOut() && phase != .results { reps = 3 }
        for r in 0..<reps {
            if r == 0 { tick(inp) } else { tick(InputState()) }
        }
    }

    // MARK: - Touch

    func trackPointer(_ p: PointerState) -> Bool {
        var tapped = false
        if p.pressed {
            ptDown = true
            ptSX = p.x
            ptSY = p.y
            ptX = p.x
            ptY = p.y
            ptMoved = false
            ptPan = p.y >= 34 && p.y < 100 && !ovOpen
            panBX = panX
            panBY = panY
            titleT = 0
        } else if p.down && ptDown {
            ptX = p.x
            ptY = p.y
            let dx = ptX - ptSX
            let dy = ptY - ptSY
            if abs(dx) > 8 || abs(dy) > 8 { ptMoved = true }
            if ptMoved && ptPan {
                panX = clamp(panBX + Float(dx), -70, 70)
                panY = clamp(panBY + Float(dy), -40, 40)
            }
        }
        if p.released && ptDown {
            ptDown = false
            if !ptMoved { tapped = true }
            ptPan = false
        }
        if !p.down && !p.released { ptDown = false }
        return tapped
    }

    /// True while the finger is pressed on the given rectangle (for button highlight).
    func hot(_ r: (Int, Int, Int, Int)) -> Bool {
        if !ptDown || ptMoved { return false }
        return TycoonUI.inside(ptSX, ptSY, r)
    }

    func tileAt(_ x: Int, _ y: Int) -> Int {
        if y < 34 || y > 226 { return -1 }
        var best = -1
        var bd: Float = 1_000_000
        for i in 0..<32 {
            let s = pj(TycoonBoard.tx[i], 12, TycoonBoard.tz[i])
            let dx: Float = s.0 - Float(x)
            let dy: Float = (s.1 - Float(y)) * 1.6
            let d: Float = dx * dx + dy * dy
            if d < bd {
                bd = d
                best = i
            }
        }
        let lim: Float = max(24, 38 * pjZoom)
        if bd < lim * lim { return best }
        return -1
    }

    func showTileInfo(_ x: Int, _ y: Int) {
        let t = tileAt(x, y)
        if t >= 0 {
            infoTile = t
            infoT = 0
            play(.blip)
        }
    }

    func handleTap(_ x: Int, _ y: Int, _ inp: inout InputState) {
        switch phase {
        case .title:
            titleTap(x, y, &inp)
        case .how:
            if TycoonUI.inside(x, y, TycoonUI.howSkip) {
                inp.pressed.insert(.b)
            } else {
                inp.pressed.insert(.a)
            }
        case .menu:
            if TycoonUI.inside(x, y, TycoonUI.menuLeft) {
                inp.pressed.insert(.left)
            } else if TycoonUI.inside(x, y, TycoonUI.menuRight) {
                inp.pressed.insert(.right)
            } else if TycoonUI.inside(x, y, TycoonUI.btn0) {
                inp.pressed.insert(.a)
            } else if TycoonUI.inside(x, y, TycoonUI.btn1) {
                inp.pressed.insert(.b)
            }
        case .roll:
            if players[cur].ai {
                showTileInfo(x, y)
            } else {
                let ds = pj(0, 10, 0)
                let dx: Float = ds.0 - Float(x)
                let dy: Float = ds.1 - Float(y)
                if y >= 226 || dx * dx + dy * dy < 48 * 48 {
                    inp.pressed.insert(.a)
                }
            }
        case .prompt:
            if players[cur].ai {
                showTileInfo(x, y)
            } else if TycoonUI.inside(x, y, TycoonUI.btn0) {
                promptSel = 0
                inp.pressed.insert(.a)
            } else if TycoonUI.inside(x, y, TycoonUI.btn1) {
                promptSel = 1
                inp.pressed.insert(.a)
            }
        case .card:
            if !players[cur].ai { inp.pressed.insert(.a) }
        case .results:
            inp.pressed.insert(.a)
        case .wait:
            if !players[cur].ai {
                inp.pressed.insert(.a)
            } else {
                showTileInfo(x, y)
            }
        default:
            showTileInfo(x, y)
        }
    }

    func titleTap(_ x: Int, _ y: Int, _ inp: inout InputState) {
        if TycoonUI.inside(x, y, TycoonUI.playBtn) {
            inp.pressed.insert(.a)
            return
        }
        if TycoonUI.inside(x, y, TycoonUI.howBtn) {
            inp.pressed.insert(.b)
            return
        }
        if y >= 130 && y < 130 + 28 * 4 {
            let row = max(0, min(3, (y - 130) / 28))
            titleRow = row
            if x >= 270 {
                titleRow = 1
                changeTitle(1)
            } else if x >= 170 {
                changeTitle(1)
            } else if x >= 90 {
                changeTitle(-1)
            } else {
                play(.blip)
            }
        }
    }

    func overviewTap(_ x: Int, _ y: Int) {
        for i in 0..<8 {
            if TycoonUI.inside(x, y, TycoonUI.ovCell(i)) {
                ovSel = i
                ovT = 0
                play(.select)
                return
            }
        }
        for k in 0..<4 {
            if TycoonUI.inside(x, y, TycoonUI.ovStation(k)) {
                ovSel = 8 + k
                ovT = 0
                play(.select)
                return
            }
        }
        ovOpen = false
    }

    func stationTile(_ k: Int) -> Int {
        let list: [Int] = [5, 13, 20, 28]
        return list[max(0, min(3, k))]
    }

    func overviewDetail() -> (String, String) {
        if ovSel < 0 { return ("TAP A DISTRICT", "TO SEE WHO OWNS IT") }
        if ovSel >= 8 {
            let t = stationTile(ovSel - 8)
            let o = tOwner[t]
            let nm = TycoonBoard.tiles[t].name
            if o < 0 { return (nm, "FOR SALE 200  RENT 25 AND UP") }
            return (nm, "OWNED BY " + who(o) + "  RENT " + String(rentFor(t)))
        }
        let list = TycoonBoard.distTiles[ovSel]
        var mine = 0
        var top = 0
        for t in list {
            if tOwner[t] == 0 { mine += 1 }
            top = max(top, TycoonBoard.tiles[t].price)
        }
        return (TycoonBoard.distNames[ovSel], "YOU OWN " + String(mine) + " OF " + String(list.count) + "  WHOLE DISTRICT = LANDMARK")
    }

    func tick(_ input: InputState) {
        phaseT += 1
        tickEffects()
        updateCamera()
        switch phase {
        case .title: tickTitle(input)
        case .how: tickHow(input)
        case .intro: tickIntro(input)
        case .menu: tickMenu(input)
        case .roll: tickRoll(input)
        case .rolling: tickRolling()
        case .hop: tickHop()
        case .prompt: tickPrompt(input)
        case .card: tickCard(input)
        case .wait: tickWait(input)
        case .results: tickResults(input)
        }
    }

    // MARK: - Title and how-to

    func tickTitle(_ input: InputState) {
        titleT += 1
        attract += 0.03
        for k in 0..<players.count {
            players[k].vis = attract + Float(k * 8)
        }
        if input.anyPressed { titleT = 0 }
        if input.upPressed {
            titleRow = (titleRow + 3) % 4
            play(.blip)
        }
        if input.downPressed {
            titleRow = (titleRow + 1) % 4
            play(.blip)
        }
        let d: Int = (input.rightPressed ? 1 : 0) - (input.leftPressed ? 1 : 0)
        if d != 0 { changeTitle(d) }
        if input.aPressed {
            play(.confirm)
            startGame()
            return
        }
        if input.bPressed {
            play(.select)
            openHow(true)
            return
        }
        if titleT > 600 { startGame() }
    }

    func changeTitle(_ d: Int) {
        play(.select)
        switch titleRow {
        case 0:
            selCount = ((selCount - 2 + d + 3) % 3) + 2
        case 1:
            sv.token = (sv.token + d + 4) % 4
        case 2:
            let n = min(6, sv.unlocked) + 1
            sv.hat = (sv.hat + d + n) % n
        default:
            let n = sv.unlocked >= 8 ? 3 : (sv.unlocked >= 7 ? 2 : 1)
            sv.skin = (sv.skin + d + n) % n
        }
        if players.count > 0 {
            players[0].token = sv.token
            players[0].hat = sv.hat
            players[0].skin = sv.skin
        }
    }

    func tickHow(_ input: InputState) {
        howT += 1
        if input.bPressed {
            closeHow()
            return
        }
        if input.leftPressed {
            howPage = max(0, howPage - 1)
            howT = 0
            play(.blip)
        }
        if input.rightPressed || input.aPressed || howT > 900 {
            howPage += 1
            howT = 0
            play(.blip)
            if howPage >= 3 { closeHow() }
        }
    }

    // MARK: - Turn flow

    func beginTurn() {
        if cur < 0 || cur >= players.count { cur = 0 }
        if players[cur].bankrupt {
            advanceTurn()
            return
        }
        doublesCount = 0
        rolledDouble = false
        chainActive = false
        if players[cur].skip > 0 {
            players[cur].skip -= 1
            setMsg("TIME-OUT!", who(cur) + " TAKES A BREAK THIS TURN")
            showBanner("TIME-OUT", TycoonPal.h(0xFF9F1C))
            play(.pause)
            endAfter(80, 0)
            return
        }
        phase = .intro
        phaseT = 0
        setMsg(turnText(cur), "ROUND " + String(round) + " OF " + String(TycoonBoard.maxRounds))
    }

    func endAfter(_ frames: Int, _ then: Int) {
        phase = .wait
        phaseT = 0
        waitT = max(1, frames)
        waitThen = then
    }

    func toRoll() {
        phase = .roll
        phaseT = 0
        let tt = tokenName()
        setMsg(turnText(cur), tt)
    }

    func tokenName() -> String {
        return "ROLL THE DICE"
    }

    func tickIntro(_ input: InputState) {
        if phaseT == 2 { showBanner(turnText(cur), TycoonBoard.tokenCols[players[cur].token % 4]) }
        if phaseT < 55 { return }
        if players[cur].ai {
            aiTurnStart()
        } else {
            buildMenu()
            if menuList.isEmpty {
                toRoll()
            } else {
                phase = .menu
                phaseT = 0
                setMsg("BUILD SOMETHING?", "PICK A STREET, THEN PRESS A")
            }
        }
    }

    func buildMenu() {
        menuList = []
        menuIdx = 0
        for i in 0..<32 {
            let t = TycoonBoard.tiles[i]
            if t.kind == TycoonBoard.kStreet && tOwner[i] == cur && ownsDistrict(cur, t.dist) && canUpgrade(i, cur) {
                menuList.append(i)
            }
        }
    }

    func tickMenu(_ input: InputState) {
        if menuList.isEmpty {
            toRoll()
            return
        }
        if input.leftPressed {
            menuIdx = (menuIdx + menuList.count - 1) % menuList.count
            play(.select)
        }
        if input.rightPressed {
            menuIdx = (menuIdx + 1) % menuList.count
            play(.select)
        }
        if input.aPressed {
            let t = menuList[max(0, min(menuList.count - 1, menuIdx))]
            if canUpgrade(t, cur) {
                upgradeTile(t, cur, false)
                endAfter(75, 1)
            } else {
                toRoll()
            }
            return
        }
        if input.bPressed || phaseT > 600 {
            toRoll()
        }
    }

    func aiTurnStart() {
        var best = -1
        var bestLv = 99
        for i in 0..<32 {
            let t = TycoonBoard.tiles[i]
            if t.kind != TycoonBoard.kStreet || tOwner[i] != cur { continue }
            if !ownsDistrict(cur, t.dist) || !canUpgrade(i, cur) { continue }
            if tLevel[i] < bestLv {
                bestLv = tLevel[i]
                best = i
            }
        }
        if best >= 0 && aiWantsBuild(cur, best) {
            upgradeTile(best, cur, false)
            endAfter(75, 1)
        } else {
            toRoll()
        }
    }

    func tickRoll(_ input: InputState) {
        let ai = players[cur].ai
        if ai {
            if phaseT > 40 { doRoll() }
            return
        }
        if input.aPressed {
            doRoll()
            return
        }
        if input.bPressed {
            ovOpen = true
            ovT = 0
            return
        }
        if phaseT > 540 { doRoll() }
    }

    func doRoll() {
        d1 = rng.range(1, 6)
        d2 = rng.range(1, 6)
        diceT = 0
        for k in 0..<6 {
            diceAxis[k] = rf(-1, 1)
        }
        diceAxis[1] += 0.6
        diceAxis[4] += 0.6
        diceSpin[0] = rf(15, 24) * (rng.chance(50) ? 1 : -1)
        diceSpin[1] = rf(15, 24) * (rng.chance(50) ? 1 : -1)
        diceYaw[0] = rf(0, 6.28)
        diceYaw[1] = rf(0, 6.28)
        phase = .rolling
        phaseT = 0
        setMsg("ROLLING...", "")
        showBanner("ROLL!", TycoonPal.h(0xFF8A1C))
        play(.blip)
    }

    func tickRolling() {
        diceT += 1
        let dd = TycoonTown64.diceDur
        if diceT == 37 {
            play(.drop)
            spawnDust(-9, 2, 9)
            spawnDust(9, 2, -9)
        }
        if diceT == 59 { play(.bounce) }
        if diceT == dd {
            play(.blip)
            spawnSparkles(0, 18, 0, 10, TycoonPal.gold)
            lastTotal = d1 + d2
            setMsg("YOU ROLLED " + String(lastTotal) + "!", String(d1) + " AND " + String(d2))
            if cur != 0 { setMsg(who(cur) + " ROLLED " + String(lastTotal), String(d1) + " AND " + String(d2)) }
        }
        if diceT >= dd + 42 { afterRoll() }
    }

    func afterRoll() {
        let total = d1 + d2
        rolledDouble = d1 == d2
        if rolledDouble {
            doublesCount += 1
            if doublesCount >= 3 {
                sendToTimeOut("3 DOUBLES IN A ROW!")
                return
            }
            showBanner("DOUBLES!", TycoonPal.h(0xB05CFF))
            spawnConfetti(26)
        }
        startHop(total, 1)
    }

    func sendToTimeOut(_ why: String) {
        let w = tokenWorld(cur)
        spawnSparkles(w.0, w.1 + 10, w.2, 14, TycoonPal.h(0xFF9F1C))
        players[cur].pos = 8
        players[cur].vis = 8
        players[cur].skip = 1
        doublesCount = 0
        rolledDouble = false
        chainActive = false
        let w2 = tokenWorld(cur)
        spawnSparkles(w2.0, w2.1 + 10, w2.2, 14, TycoonPal.white)
        showBanner("TIME-OUT", TycoonPal.h(0xFF9F1C))
        setMsg(why, who(cur) + " RESTS NEXT TURN")
        play(.pause)
        endAfter(90, 0)
    }

    func startHop(_ steps: Int, _ dir: Int) {
        if steps <= 0 {
            resolveTile()
            return
        }
        hopLeft = steps
        hopDir = dir >= 0 ? 1 : -1
        hopT = 0
        hopBase = players[cur].pos
        phase = .hop
        phaseT = 0
    }

    func tickHop() {
        let fr = TycoonTown64.hopFrames
        hopT += 1
        let f: Float = Float(hopT) / Float(fr)
        players[cur].vis = Float(hopBase) + Float(hopDir) * f
        if hopT >= fr {
            let np = (((hopBase + hopDir) % 32) + 32) % 32
            players[cur].pos = np
            players[cur].vis = Float(np)
            hopBase = np
            hopLeft -= 1
            hopT = 0
            players[cur].squash = 1
            let w = tokenWorld(cur)
            spawnDust(w.0, w.1, w.2)
            play(.step)
            if hopDir > 0 && np == 0 { passStart() }
            if hopLeft <= 0 { resolveTile() }
        }
    }

    func passStart() {
        _ = transfer(-1, cur, TycoonBoard.salary)
        showBanner("BONUS!", TycoonPal.h(0x2FC76A))
        spawnConfetti(24)
        play(.coin)
    }

    // MARK: - Tile resolution

    func resolveTile() {
        let pi = cur
        let pos = players[pi].pos
        let t = TycoonBoard.tiles[pos]
        let chained = chainActive
        chainActive = false
        let w = tokenWorld(pi)
        spawnDust(w.0, w.1, w.2)
        switch t.kind {
        case TycoonBoard.kStart:
            setMsg("START!", "BACK WHERE IT ALL BEGINS")
            endAfter(40, 0)
        case TycoonBoard.kTimeOut:
            setMsg("JUST VISITING", "TIME-OUT IS A NICE PLACE TO REST")
            endAfter(45, 0)
        case TycoonBoard.kPark:
            let amt = pot
            pot = 50
            _ = transfer(-1, pi, amt)
            showBanner("JACKPOT!", TycoonPal.h(0x2FC76A))
            spawnConfetti(40)
            setMsg("FREE PARK!", who(pi) + " WON THE POT OF " + String(amt))
            play(.win)
            endAfter(95, 0)
        case TycoonBoard.kGoTimeOut:
            sendToTimeOut("OFF TO TIME-OUT!")
        case TycoonBoard.kSurprise, TycoonBoard.kTreasure:
            if chained {
                setMsg("NICE VIEW!", "NO CARD THIS TIME")
                endAfter(45, 0)
            } else {
                startCard(t.kind == TycoonBoard.kSurprise)
            }
        case TycoonBoard.kTax:
            let paid = transfer(pi, -1, TycoonBoard.taxAmount)
            pot += paid
            showBanner("FIX-IT!", TycoonPal.h(0x7B8CDE))
            setMsg("FIX-IT TIME!", who(pi) + " PAID " + String(paid) + " TO REPAIR THE TOWN")
            endAfter(85, 0)
        default:
            resolveProperty(pi, pos, t)
        }
    }

    func resolveProperty(_ pi: Int, _ pos: Int, _ t: TycoonTile) {
        let owner = tOwner[pos]
        if owner < 0 {
            if players[pi].cash >= t.price {
                openPrompt(1, pos)
            } else {
                setMsg(t.name, "NOT ENOUGH COINS TO BUY")
                endAfter(55, 0)
            }
        } else if owner == pi {
            if t.kind == TycoonBoard.kStation {
                setMsg("YOUR " + t.name, "WELCOME BACK!")
                endAfter(50, 0)
            } else if canUpgrade(pos, pi) {
                openPrompt(2, pos)
            } else if tLevel[pos] >= 5 {
                setMsg(t.name, "ALREADY A SHINING LANDMARK!")
                endAfter(50, 0)
            } else {
                setMsg(t.name, "SAVE UP TO BUILD HERE")
                endAfter(50, 0)
            }
        } else {
            let rent = rentFor(pos)
            let paid = transfer(pi, owner, rent)
            showBanner("RENT!", TycoonPal.h(0xFF6B4A))
            setMsg(who(pi) + " PAID " + who(owner) + " " + String(paid), t.name)
            play(.hit)
            endAfter(100, 0)
        }
    }

    // MARK: - Prompts

    func openPrompt(_ kind: Int, _ tile: Int) {
        promptKind = kind
        promptTile = tile
        promptT = 0
        phase = .prompt
        phaseT = 0
        let t = TycoonBoard.tiles[tile]
        if kind == 1 {
            let left = players[cur].cash - t.price
            promptRec = left >= 150 || ownsAlmost(cur, tile) ? 0 : 1
            if t.kind == TycoonBoard.kStation { promptRec = left >= 100 ? 0 : 1 }
            setMsg(t.name, "BUY THIS PLACE?")
        } else {
            let next = tLevel[tile] + 1
            let left = players[cur].cash - TycoonBoard.buildCost(tile, next)
            promptRec = left >= 100 ? 0 : 1
            setMsg(t.name, "BUILD A " + TycoonBoard.levelName(next) + "?")
        }
        promptSel = promptRec
    }

    func ownsAlmost(_ pi: Int, _ tile: Int) -> Bool {
        let t = TycoonBoard.tiles[tile]
        if t.dist < 0 { return false }
        var mine = 0
        let list = TycoonBoard.distTiles[t.dist]
        for x in list where tOwner[x] == pi { mine += 1 }
        return mine + 1 >= list.count
    }

    func tickPrompt(_ input: InputState) {
        promptT += 1
        if players[cur].ai {
            if promptT == 45 {
                let yes = promptKind == 1 ? aiWantsBuy(cur, promptTile) : aiWantsBuild(cur, promptTile)
                promptSel = yes ? 0 : 1
            }
            if promptT >= 75 { applyPrompt(promptSel == 0) }
            return
        }
        if input.leftPressed || input.rightPressed {
            promptSel = 1 - promptSel
            play(.select)
        }
        if input.aPressed {
            applyPrompt(promptSel == 0)
        } else if input.bPressed {
            applyPrompt(false)
        } else if promptT >= 780 {
            applyPrompt(promptRec == 0)
        }
    }

    func applyPrompt(_ confirm: Bool) {
        let t = TycoonBoard.tiles[promptTile]
        if !confirm {
            setMsg(who(cur) + " PASSED", t.name)
            play(.blip)
            endAfter(28, 0)
            return
        }
        if promptKind == 1 {
            if players[cur].cash >= t.price {
                buyTile(promptTile, cur)
                endAfter(75, 0)
            } else {
                endAfter(20, 0)
            }
        } else {
            if canUpgrade(promptTile, cur) {
                upgradeTile(promptTile, cur, false)
                endAfter(85, 0)
            } else {
                endAfter(20, 0)
            }
        }
    }

    func buyTile(_ tile: Int, _ pi: Int) {
        let t = TycoonBoard.tiles[tile]
        _ = transfer(pi, -1, t.price)
        tOwner[tile] = pi
        tLevel[tile] = 0
        tAnim[tile] = 0
        showBanner("SOLD!", TycoonBoard.tokenCols[players[pi].token % 4])
        setMsg(who(pi) + " BOUGHT", t.name)
        let x = TycoonBoard.tx[tile]
        let z = TycoonBoard.tz[tile]
        spawnSparkles(x, 14, z, 16, TycoonBoard.tokenCols[players[pi].token % 4])
        play(.confirm)
        play(.coin)
        if t.kind == TycoonBoard.kStreet && ownsDistrict(pi, t.dist) {
            spawnConfetti(36)
            showBanner("DISTRICT!", TycoonBoard.distCols[t.dist])
        }
    }

    func upgradeTile(_ tile: Int, _ pi: Int, _ free: Bool) {
        let next = min(5, tLevel[tile] + 1)
        if !free {
            _ = transfer(pi, -1, TycoonBoard.buildCost(tile, next))
        }
        tLevel[tile] = next
        tAnim[tile] = 0
        let x = TycoonBoard.tx[tile]
        let z = TycoonBoard.tz[tile]
        spawnSparkles(x, 20 + Float(next) * 8, z, 22, TycoonPal.gold)
        spawnDust(x, 8, z)
        if next >= 5 {
            showBanner("LANDMARK!", TycoonPal.h(0xFFB400))
            spawnConfetti(50)
        } else {
            showBanner("BUILD!", TycoonPal.h(0x2FC76A))
        }
        setMsg(TycoonBoard.tiles[tile].name, "NOW A " + TycoonBoard.levelName(next) + "!")
        play(.powerup)
    }

    // MARK: - Cards

    func startCard(_ surprise: Bool) {
        cardSurprise = surprise
        if surprise {
            curCard = TycoonBoard.surprise[rng.int(TycoonBoard.surprise.count)]
        } else {
            curCard = TycoonBoard.treasure[rng.int(TycoonBoard.treasure.count)]
        }
        cardT = 0
        phase = .card
        phaseT = 0
        showBanner(surprise ? "SURPRISE!" : "TREASURE!", surprise ? TycoonPal.h(0xE05CE0) : TycoonPal.h(0xFFB400))
        setMsg(surprise ? "SURPRISE CARD" : "TREASURE CHEST", "FLIPPING...")
        play(.pickup)
    }

    func tickCard(_ input: InputState) {
        cardT += 1
        if cardT == 20 { play(.blip) }
        var dismiss = false
        if players[cur].ai {
            if cardT > 115 { dismiss = true }
        } else {
            if cardT > 50 && (input.aPressed || input.bPressed) { dismiss = true }
            if cardT > 420 { dismiss = true }
        }
        if cardT == 40 {
            setMsg(curCard.l1, curCard.l2)
        }
        if dismiss { applyCard() }
    }

    func applyCard() {
        let c = curCard
        let pi = cur
        switch c.kind {
        case 0:
            _ = transfer(-1, pi, c.amt)
            play(.coin)
            endAfter(75, 0)
        case 1:
            let paid = transfer(pi, -1, c.amt)
            pot += paid
            endAfter(75, 0)
        case 2:
            for j in 0..<players.count where j != pi && !players[j].bankrupt {
                _ = transfer(j, pi, c.amt)
            }
            endAfter(85, 0)
        case 3:
            for j in 0..<players.count where j != pi && !players[j].bankrupt && !players[pi].bankrupt {
                _ = transfer(pi, j, c.amt)
            }
            endAfter(85, 0)
        case 4:
            let steps = ((c.amt - players[pi].pos) % 32 + 32) % 32
            chainActive = true
            startHop(steps, 1)
        case 5:
            chainActive = true
            startHop(c.amt, 1)
        case 6:
            var best = -1
            var bestLv = 99
            for i in 0..<32 {
                let t = TycoonBoard.tiles[i]
                if t.kind != TycoonBoard.kStreet || tOwner[i] != pi || tLevel[i] >= 5 { continue }
                if tLevel[i] + 1 >= 5 && !ownsDistrict(pi, t.dist) { continue }
                if tLevel[i] < bestLv {
                    bestLv = tLevel[i]
                    best = i
                }
            }
            if best >= 0 {
                upgradeTile(best, pi, true)
                endAfter(90, 0)
            } else {
                _ = transfer(-1, pi, 50)
                setMsg("NO STREETS YET", "HERE ARE 50 COINS INSTEAD")
                endAfter(75, 0)
            }
        default:
            chainActive = true
            startHop(c.amt, -1)
        }
    }

    // MARK: - Waiting and turn end

    func tickWait(_ input: InputState) {
        waitT -= 1
        if !players[cur].ai && input.aPressed && waitT > 8 { waitT = 8 }
        if waitT <= 0 {
            if waitThen == 1 {
                toRoll()
            } else {
                finishTurn()
            }
        }
    }

    func finishTurn() {
        if aliveCount() <= 1 {
            endGame()
            return
        }
        let again = rolledDouble && !players[cur].bankrupt && players[cur].skip == 0
        if again {
            rolledDouble = false
            toRoll()
            showBanner("ROLL AGAIN!", TycoonPal.h(0xB05CFF))
            setMsg("DOUBLES! ROLL AGAIN", who(cur) + " GOES AGAIN")
            return
        }
        advanceTurn()
    }

    func advanceTurn() {
        var n = cur
        var wrapped = false
        var guardN = 0
        repeat {
            n += 1
            if n >= players.count {
                n = 0
                wrapped = true
            }
            guardN += 1
        } while players[n].bankrupt && guardN < 8
        cur = n
        if wrapped {
            round += 1
            if round > TycoonBoard.maxRounds {
                round = TycoonBoard.maxRounds
                endGame()
                return
            }
        }
        beginTurn()
    }

    // MARK: - Money

    @discardableResult
    func transfer(_ from: Int, _ to: Int, _ amount: Int) -> Int {
        let amt = max(0, amount)
        var paid = amt
        if from >= 0 && from < players.count {
            var guardN = 0
            while players[from].cash < amt && ownedCount(from) > 0 && guardN < 40 {
                sellCheapest(from)
                guardN += 1
            }
            paid = min(amt, max(0, players[from].cash))
            players[from].cash -= paid
        }
        if to >= 0 && to < players.count {
            players[to].cash += paid
        }
        if paid > 0 {
            var sx: Float = 160
            var sy: Float = 120
            var ex: Float = 160
            var ey: Float = 120
            if from >= 0 && from < players.count {
                let c = slotCenter(from)
                sx = c.0
                sy = c.1
                if to < 0 { ex = 160; ey = 130 }
            }
            if to >= 0 && to < players.count {
                let c = slotCenter(to)
                ex = c.0
                ey = c.1
                if from < 0 {
                    let ts = tokenScreen(to)
                    sx = ts.0
                    sy = ts.1
                    if inGamePhase() == false { sx = 160; sy = 140 }
                }
            }
            if from >= 0 && to < 0 {
                let ts = tokenScreen(from)
                ex = ts.0
                ey = ts.1 - 20
            }
            let n = max(2, min(10, 2 + paid / 25))
            spawnFlies(sx, sy, ex, ey, n)
            if from >= 0 && from < players.count {
                let c = slotCenter(from)
                spawnFloat("", -paid, c.0, c.1 + 14, TycoonPal.red)
            }
            if to >= 0 && to < players.count {
                let c = slotCenter(to)
                spawnFloat("", paid, c.0, c.1 + 14, TycoonPal.green)
            }
        }
        if from >= 0 && from < players.count && paid < amt {
            goBankrupt(from)
        }
        return paid
    }

    func sellCheapest(_ pi: Int) {
        var best = -1
        var bv = Int.max
        for i in 0..<32 where tOwner[i] == pi {
            let v = propValue(i)
            if v < bv {
                bv = v
                best = i
            }
        }
        if best < 0 { return }
        let gain = max(10, bv * 60 / 100)
        players[pi].cash += gain
        tOwner[best] = -1
        tLevel[best] = 0
        tAnim[best] = 99
        let c = slotCenter(pi)
        spawnFloat("SOLD " + TycoonBoard.tiles[best].name, 0, c.0, c.1 + 30, TycoonPal.gold)
        spawnSparkles(TycoonBoard.tx[best], 14, TycoonBoard.tz[best], 10, TycoonPal.grey)
    }

    func goBankrupt(_ pi: Int) {
        players[pi].bankrupt = true
        for i in 0..<32 where tOwner[i] == pi {
            tOwner[i] = -1
            tLevel[i] = 0
            tAnim[i] = 99
        }
        players[pi].cash = 0
        showBanner("OUT!", TycoonPal.h(0x7B8CDE))
        setMsg(who(pi) + " RAN OUT OF COINS", "STREETS GO BACK TO THE BANK")
        play(.lose)
    }

    // MARK: - AI

    func aiWantsBuy(_ pi: Int, _ tile: Int) -> Bool {
        let t = TycoonBoard.tiles[tile]
        let cash = players[pi].cash
        if cash < t.price { return false }
        let left = cash - t.price
        if ownsAlmost(pi, tile) { return true }
        switch players[pi].persona {
        case 0:
            return left >= 400 || (t.price <= 120 && left >= 250)
        case 1:
            return left >= 100
        default:
            return rng.chance(80)
        }
    }

    func aiWantsBuild(_ pi: Int, _ tile: Int) -> Bool {
        let next = tLevel[tile] + 1
        let cost = TycoonBoard.buildCost(tile, next)
        let left = players[pi].cash - cost
        if left < 0 { return false }
        switch players[pi].persona {
        case 0:
            return left >= 350
        case 1:
            return left >= 120
        default:
            return left >= 60 && rng.chance(70)
        }
    }

    // MARK: - Game end

    func endGame() {
        var order: [Int] = []
        var wl: [Int] = []
        for i in 0..<players.count {
            order.append(i)
            wl.append(wealth(i))
        }
        var k = 1
        while k < order.count {
            let cv = order[k]
            var m = k - 1
            while m >= 0 && wl[order[m]] < wl[cv] {
                order[m + 1] = order[m]
                m -= 1
            }
            order[m + 1] = cv
            k += 1
        }
        ranks = order
        wealthList = wl
        humanWon = !order.isEmpty && order[0] == 0 && !players[0].bankrupt
        sv.games = min(65535, sv.games + 1)
        unlockText = ""
        if players.count > 0 && !players[0].bankrupt {
            sv.best = max(sv.best, wl[0])
        }
        if humanWon {
            let tk = max(0, min(3, players[0].token))
            sv.wins[tk] = min(255, sv.wins[tk] + 1)
            if sv.unlocked < 8 {
                sv.unlocked += 1
                if sv.unlocked <= 6 {
                    sv.hat = sv.unlocked
                    unlockText = "NEW HAT: " + TycoonBoard.hatNames[sv.unlocked]
                } else if sv.unlocked == 7 {
                    sv.skin = 1
                    unlockText = "NEW SKIN: GOLDEN"
                } else {
                    sv.skin = 2
                    unlockText = "NEW SKIN: RAINBOW"
                }
            }
            play(.win)
            spawnConfetti(80)
        } else {
            play(.lose)
            spawnConfetti(24)
        }
        phase = .results
        phaseT = 0
        resT = 0
        inGame = true
        zoomWide = false
        playMusic(Tunes.puzzle)
    }

    func tickResults(_ input: InputState) {
        resT += 1
        if resT % 40 == 0 { spawnConfetti(humanWon ? 14 : 4) }
        if (resT > 90 && (input.aPressed || input.bPressed)) || resT > 1800 {
            play(.confirm)
            setupAttract()
            playMusic(Tunes.puzzle)
        }
    }
}

extension Cartridge {
    static let tycoonTown64 = Cartridge(
        id: "tycoontown64", title: "TYCOON TOWN", genre: "Board Game",
        blurb: "Roll the chunky dice, hop around a floating isometric city, buy streets and build cottages, shops, towers and glowing landmarks. Beat your pet-and-robot rivals before round 30!",
        controls: "A roll / confirm, LEFT/RIGHT choose, B skip or info, UP town map, DOWN zoom.",
        era: .n64, labelTop: 0xFFC94A, labelBottom: 0xE0457B, factory: { TycoonTown64() })
}

/// Shared on-screen button layout so drawing and touch hit-testing agree. Rects are (x, y, w, h) in game pixels.
enum TycoonUI {
    static let btn0: (Int, Int, Int, Int) = (6, 256, 150, 30)
    static let btn1: (Int, Int, Int, Int) = (164, 256, 150, 30)
    static let rollBtn: (Int, Int, Int, Int) = (60, 242, 200, 42)
    static let menuLeft: (Int, Int, Int, Int) = (2, 226, 50, 30)
    static let menuRight: (Int, Int, Int, Int) = (268, 226, 50, 30)
    static let howSkip: (Int, Int, Int, Int) = (8, 252, 96, 32)
    static let howNext: (Int, Int, Int, Int) = (208, 252, 104, 32)
    static let playBtn: (Int, Int, Int, Int) = (10, 248, 150, 34)
    static let howBtn: (Int, Int, Int, Int) = (170, 248, 140, 34)

    static func titleRow(_ i: Int) -> (Int, Int, Int, Int) {
        return (0, 130 + 28 * i, 320, 28)
    }

    static func ovCell(_ i: Int) -> (Int, Int, Int, Int) {
        return (10 + (i % 2) * 152, 52 + (i / 2) * 42, 148, 40)
    }

    static func ovStation(_ k: Int) -> (Int, Int, Int, Int) {
        return (10 + k * 76, 222, 72, 30)
    }

    static func inside(_ x: Int, _ y: Int, _ r: (Int, Int, Int, Int)) -> Bool {
        return x >= r.0 && y >= r.1 && x < r.0 + r.2 && y < r.1 + r.3
    }
}
