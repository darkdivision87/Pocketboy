#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// RAIL RUNNER 64: a Subway-Surfers style endless runner on a three-lane rail yard. A cartoon kid in a hoodie
/// runs forward automatically while a friendly guard-and-dog duo chases. Switch lanes, jump, roll, hop onto
/// train roofs, ride ramps, grab coin trails and power-ups (magnet, jetpack, 2x, super sneakers) and finish
/// the three mission goals for bonus stars. First hit is a stumble, the second one gets you caught.
final class RailRunner64: Game {
    // MARK: - Constants

    private static let sc: Float = 194
    private static let camBack: Float = 2.6
    private static let hz: Float = 96
    private static let camBase: Float = 1.7
    private static let roofH: Float = 1.15
    private static let standH: Float = 0.68
    private static let rollH: Float = 0.38
    private static let gravity: Float = 0.012
    private static let farZ: Float = 78

    private static let kTrain = 0
    private static let kLow = 1
    private static let kHigh = 2
    private static let kGap = 3
    private static let kRamp = 4
    private static let kCoin = 5
    private static let kPower = 6
    private static let kLamp = 7
    private static let kBuild = 8

    private static let cWhite: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    private static let cBlack: UInt32 = TrueColorBuffer.rgb(10, 10, 24)
    private static let cYellow: UInt32 = TrueColorBuffer.rgb(255, 226, 64)
    private static let cRed: UInt32 = TrueColorBuffer.rgb(255, 80, 70)
    private static let cGreen: UInt32 = TrueColorBuffer.rgb(110, 255, 140)
    private static let cCyan: UInt32 = TrueColorBuffer.rgb(110, 232, 255)
    private static let cPanel: UInt32 = TrueColorBuffer.rgb(24, 30, 80)
    private static let cOrange: UInt32 = TrueColorBuffer.rgb(255, 150, 40)
    private static let cGold: UInt32 = TrueColorBuffer.rgb(255, 212, 40)

    private static let missionText: [String] = [
        "COLLECT 50 COINS", "JUMP ONTO 3 TRAINS", "ROLL 5 TIMES", "GRAB 2 POWER UPS",
        "RUN 600 METERS", "JUMP 10 TIMES", "SWITCH LANES 20 TIMES", "COLLECT 100 COINS"
    ]
    private static let missionTarget: [Int] = [50, 3, 5, 2, 600, 10, 20, 100]

    private static let trainBody: [UInt32] = [
        TrueColorBuffer.rgb(232, 64, 70), TrueColorBuffer.rgb(66, 128, 235),
        TrueColorBuffer.rgb(52, 186, 108), TrueColorBuffer.rgb(250, 186, 44)
    ]

    // MARK: - Nested types

    struct Obj {
        var kind: Int
        var x: Float
        var wz: Float
        var len: Float
        var w: Float
        var h: Float
        var sub: Int
        var move: Float
        var alive: Bool
    }

    struct BoxCols {
        var side: UInt32
        var roof: UInt32
        var front: UInt32
        var accent: UInt32
    }

    struct Part {
        var x: Float
        var y: Float
        var vx: Float
        var vy: Float
        var grav: Float
        var life: Int
        var size: Int
        var c: UInt32
    }

    struct FText {
        var x: Float
        var y: Float
        var life: Int
        var text: String
        var c: UInt32
    }

    enum Phase { case title, ready, run, caught, results }

    // MARK: - Static tables

    @inline(__always) private static func blend(_ c: UInt32, _ tr: Int, _ tg: Int, _ tb: Int, _ t: Int) -> UInt32 {
        if t <= 0 { return c }
        let r = Int(c & 255)
        let g = Int((c >> 8) & 255)
        let bl = Int((c >> 16) & 255)
        let r2 = r + (((tr - r) * t) >> 8)
        let g2 = g + (((tg - g) * t) >> 8)
        let b2 = bl + (((tb - bl) * t) >> 8)
        let rr = UInt32(max(0, min(255, r2)))
        let gg = UInt32(max(0, min(255, g2)))
        let bb = UInt32(max(0, min(255, b2)))
        return 0xFF00_0000 | rr | (gg << 8) | (bb << 16)
    }

    private static func col(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
        return TrueColorBuffer.rgb(r, g, b)
    }

    private static let skylineFar: [Int] = {
        var a = [Int](repeating: 20, count: 512)
        var seed: UInt32 = 4242
        for blk in 0..<64 {
            seed = seed &* 1664525 &+ 1013904223
            let hgt: Int = 14 + Int((seed >> 16) % 40)
            for k in 0..<8 { a[blk * 8 + k] = hgt }
        }
        return a
    }()

    private static let skylineNear: [Int] = {
        var a = [Int](repeating: 14, count: 512)
        var seed: UInt32 = 9191
        for blk in 0..<51 {
            seed = seed &* 1664525 &+ 1013904223
            let hgt: Int = 10 + Int((seed >> 16) % 30)
            for k in 0..<10 {
                let idx = blk * 10 + k
                if idx < 512 { a[idx] = hgt }
            }
        }
        return a
    }()

    // MARK: - State

    private var phase: Phase = .title
    private var rng = Rng()
    private var frame = 0
    private var objs: [Obj] = []
    private var genZ: Float = 18
    private var decorZ: Float = 4
    private var chunkCount = 0
    private var lastPat = -1
    private var dist: Float = 0
    private var v: Float = 0.26
    private var distPts: Float = 0
    private var coinPts = 0
    private var bonusPts = 0
    private var coins = 0
    private var x: Float = 0
    private var laneTarget = 1
    private var laneFrom = 1
    private var laneQueue = 0
    private var y: Float = 0
    private var vy: Float = 0
    private var grounded = true
    private var airFrames = 0
    private var rollTimer = 0
    private var rollBuf = 0
    private var jumpBuf = 0
    private var fastFall = false
    private var onRampPrev = false
    private var surfNow: Float = 0
    private var stumble = 0
    private var invuln = 0
    private var chase: Float = 0
    private var magnetTimer = 0
    private var jetTimer = 0
    private var multTimer = 0
    private var shoeTimer = 0
    private var runPhase: Float = 0
    private var camY: Float = 0
    private var camHNow: Float = RailRunner64.camBase
    private var shake = 0
    private var flash = 0
    private var cdTimer = 0
    private var caughtTimer = 0
    private var resultTimer = 0
    private var mIds: [Int] = [0, 1, 2]
    private var mProg: [Int] = [0, 0, 0]
    private var mDone: [Bool] = [false, false, false]
    private var stars = 0
    private var bestDist = 0
    private var banner = ""
    private var bannerTimer = 0
    private var hint = ""
    private var tipJump = false
    private var tipRoll = false
    private var lastCoinSfx = -10
    private var parts: [Part] = []
    private var texts: [FText] = []
    private var skyRowCols = [UInt32](repeating: 0, count: 100)
    private var hazeR = 200
    private var hazeG = 230
    private var hazeB = 255
    private var duskAmt: Float = 0

    override var score: Int { return max(0, Int(distPts) + coinPts + bonusPts) }

    override init() {
        super.init()
        resetWorld()
        phase = .title
    }

    override func start() {
        playMusic(Tunes.adventure)
    }

    // MARK: - Setup

    private func resetWorld() {
        objs = []
        genZ = 18
        decorZ = 4
        chunkCount = 0
        lastPat = -1
        dist = 0
        v = 0.26
        distPts = 0
        coinPts = 0
        bonusPts = 0
        coins = 0
        x = 0
        laneTarget = 1
        laneFrom = 1
        laneQueue = 0
        y = 0
        vy = 0
        grounded = true
        airFrames = 0
        rollTimer = 0
        rollBuf = 0
        jumpBuf = 0
        fastFall = false
        onRampPrev = false
        surfNow = 0
        stumble = 0
        invuln = 0
        chase = 0
        magnetTimer = 0
        jetTimer = 0
        multTimer = 0
        shoeTimer = 0
        runPhase = 0
        camY = 0
        camHNow = RailRunner64.camBase
        shake = 0
        flash = 0
        stars = 0
        mProg = [0, 0, 0]
        mDone = [false, false, false]
        banner = ""
        bannerTimer = 0
        hint = ""
        tipJump = false
        tipRoll = false
        parts = []
        texts = []
    }

    private func pickMissions() {
        var ids: [Int] = []
        while ids.count < 3 {
            let m = rng.int(8)
            var dup = false
            for e in ids {
                if e == m { dup = true }
                if (e == 0 && m == 7) || (e == 7 && m == 0) { dup = true }
            }
            if !dup { ids.append(m) }
        }
        mIds = ids
        mProg = [0, 0, 0]
        mDone = [false, false, false]
    }

    private func beginReady() {
        resetWorld()
        pickMissions()
        phase = .ready
        cdTimer = 0
    }

    private func beginRun() {
        phase = .run
        v = 0.26
        showBanner("GO!", 50)
        play(.powerup)
    }

    private func showBanner(_ s: String, _ frames: Int) {
        banner = s
        bannerTimer = frames
    }

    // MARK: - Missions

    private func missionEvent(_ type: Int, _ n: Int) {
        for s in 0..<3 {
            if mDone[s] { continue }
            if mIds[s] != type { continue }
            mProg[s] += n
            checkMission(s)
        }
    }

    private func missionSet(_ type: Int, _ value: Int) {
        for s in 0..<3 {
            if mDone[s] { continue }
            if mIds[s] != type { continue }
            mProg[s] = max(mProg[s], value)
            checkMission(s)
        }
    }

    private func checkMission(_ s: Int) {
        let target = RailRunner64.missionTarget[mIds[s]]
        if mProg[s] >= target && !mDone[s] {
            mDone[s] = true
            stars += 1
            bonusPts += 500
            showBanner("MISSION DONE! +1 STAR", 120)
            play(.win)
            addText("+500", 160, 120, RailRunner64.cYellow)
        }
    }

    // MARK: - Helpers

    private func laneOf(_ f: Float) -> Float {
        return Float(laneTarget - 1)
    }

    @inline(__always) private func projX(_ xx: Float, _ zc: Float) -> Float {
        return 160 + xx * RailRunner64.sc / zc
    }

    @inline(__always) private func projY(_ yy: Float, _ zc: Float) -> Float {
        return RailRunner64.hz + (camHNow - yy) * RailRunner64.sc / zc
    }

    private func kidX() -> Int {
        return Int(clamp(160 + x * RailRunner64.sc / RailRunner64.camBack, 0, 320))
    }

    private func kidY(_ yy: Float) -> Int {
        return Int(clamp(projY(yy, RailRunner64.camBack), -100, 400))
    }

    private func addPart(_ px: Float, _ py: Float, _ vx: Float, _ vyy: Float, _ grav: Float, _ life: Int, _ size: Int, _ c: UInt32) {
        if parts.count >= 140 { return }
        parts.append(Part(x: px, y: py, vx: vx, vy: vyy, grav: grav, life: life, size: size, c: c))
    }

    private func addText(_ s: String, _ px: Float, _ py: Float, _ c: UInt32) {
        if texts.count >= 6 { texts.removeFirst() }
        texts.append(FText(x: px, y: py, life: 50, text: s, c: c))
    }

    private func burst(_ px: Float, _ py: Float, _ n: Int, _ c: UInt32, _ spd: Float, _ grav: Float) {
        for _ in 0..<n {
            let a: Float = Float(rng.int(628)) / 100.0
            let s: Float = spd * (0.4 + Float(rng.int(100)) / 100.0)
            addPart(px, py, cos(a) * s, sin(a) * s - 1, grav, 16 + rng.int(14), 2 + rng.int(2), c)
        }
    }

    private func updateFX() {
        var i = 0
        while i < parts.count {
            parts[i].x += parts[i].vx
            parts[i].y += parts[i].vy
            parts[i].vy += parts[i].grav
            parts[i].life -= 1
            i += 1
        }
        parts.removeAll(where: { $0.life <= 0 })
        var k = 0
        while k < texts.count {
            texts[k].y -= 0.7
            texts[k].life -= 1
            k += 1
        }
        texts.removeAll(where: { $0.life <= 0 })
    }

    // MARK: - Object generation

    private func addObj(_ kind: Int, _ ox: Float, _ wz: Float, _ len: Float, _ w: Float, _ h: Float, _ sub: Int, _ move: Float) {
        objs.append(Obj(kind: kind, x: ox, wz: wz, len: len, w: w, h: h, sub: sub, move: move, alive: true))
    }

    private func addCoin(_ cx: Float, _ wz: Float, _ h: Float) {
        addObj(RailRunner64.kCoin, cx, wz, 0, 0.2, h, 0, 0)
    }

    private func laneX(_ l: Int) -> Float {
        return Float(l - 1)
    }

    private func genDecor() {
        let z = decorZ
        let n = Int(z / 6.0)
        // lamps and signal masts every 6 units
        let sideSign: Float = (n & 1) == 0 ? -1 : 1
        addObj(RailRunner64.kLamp, sideSign * 2.05, z, 0.1, 0.05, 1.9, n & 3, 0)
        // buildings every 12 units on both sides
        if n % 2 == 0 {
            for side in 0..<2 {
                let sg: Float = side == 0 ? -1 : 1
                let bw: Float = 1.2 + Float(rng.int(12)) / 10.0
                let bh: Float = 2.6 + Float(rng.int(40)) / 10.0
                let gap: Float = 3.2 + Float(rng.int(10)) / 10.0
                addObj(RailRunner64.kBuild, sg * (gap + bw), z + Float(rng.int(30)) / 10.0, 5.0 + Float(rng.int(30)) / 10.0, bw, bh, rng.int(4), 0)
            }
        }
        decorZ += 6
    }

    private func genChunk(_ demo: Bool) {
        let d = min(3, Int(dist / 450))
        let start = genZ
        var len: Float = 14
        var pat = 0
        if demo {
            pat = rng.chance(50) ? 0 : 10
        } else if chunkCount == 0 {
            pat = 0
        } else if chunkCount == 1 {
            pat = 1
        } else if chunkCount == 2 {
            pat = 2
        } else {
            var list: [Int] = [0, 1, 2, 7, 10, 8]
            if d == 1 { list = [0, 1, 2, 3, 4, 6, 7, 8, 10] }
            if d == 2 { list = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 3] }
            if d >= 3 { list = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 5, 9] }
            var tries = 0
            pat = list[rng.int(list.count)]
            while pat == lastPat && tries < 4 {
                pat = list[rng.int(list.count)]
                tries += 1
            }
        }
        lastPat = pat
        let free = rng.int(3)
        let fx = laneX(free)
        switch pat {
        case 0:
            for k in 0..<10 { addCoin(fx, start + 1 + Float(k) * 1.3, 0.4) }
            len = 14
        case 1:
            let blockN = d == 0 ? 1 : 2
            var placed = 0
            for l in 0..<3 {
                if l == free || placed >= blockN { continue }
                addObj(RailRunner64.kLow, laneX(l), start + 7, 0.3, 0.45, 0.45, 0, 0)
                for k in 0..<5 {
                    let t: Float = Float(k) / 4.0
                    let hh: Float = 0.55 + sin(t * Float.pi) * 0.8
                    addCoin(laneX(l), start + 5 + Float(k), hh)
                }
                placed += 1
            }
            for k in 0..<9 { addCoin(fx, start + 1 + Float(k) * 1.4, 0.4) }
            len = 13
        case 2:
            if d >= 1 && rng.chance(50) {
                addObj(RailRunner64.kHigh, 0, start + 8, 0.3, 1.5, 0.7, 0, 0)
                for k in 0..<6 { addCoin(fx, start + 3 + Float(k), 0.3) }
            } else {
                addObj(RailRunner64.kHigh, fx, start + 8, 0.3, 0.5, 0.7, 0, 0)
                for k in 0..<6 { addCoin(fx, start + 3 + Float(k), 0.3) }
                let other = (free + 1) % 3
                for k in 0..<6 { addCoin(laneX(other), start + 2 + Float(k) * 1.5, 0.4) }
            }
            len = 12
        case 3:
            let tl = rng.int(3)
            addObj(RailRunner64.kRamp, laneX(tl), start + 2, 4.5, 0.45, RailRunner64.roofH, 0, 0)
            addObj(RailRunner64.kTrain, laneX(tl), start + 6.5, 11, 0.43, 0, rng.int(4), 0)
            for k in 0..<8 { addCoin(laneX(tl), start + 8 + Float(k) * 1.3, RailRunner64.roofH + 0.4) }
            let other = (tl + 1) % 3
            for k in 0..<6 { addCoin(laneX(other), start + 2 + Float(k) * 1.6, 0.4) }
            len = 21
        case 4:
            let blockN = (d >= 2 && rng.chance(60)) ? 2 : 1
            var placed = 0
            for l in 0..<3 {
                if l == free || placed >= blockN { continue }
                let tl: Float = 8 + Float(rng.int(5))
                addObj(RailRunner64.kTrain, laneX(l), start + 3, tl, 0.43, 0, rng.int(4), 0)
                placed += 1
            }
            for k in 0..<10 { addCoin(fx, start + 1 + Float(k) * 1.3, 0.4) }
            len = 16
        case 5:
            let ml = rng.int(3)
            addObj(RailRunner64.kTrain, laneX(ml), start + 14, 7, 0.43, 1, rng.int(4), 7)
            let other = (ml + 1 + rng.int(2)) % 3
            for k in 0..<10 { addCoin(laneX(other), start + 1 + Float(k) * 1.4, 0.4) }
            len = 22
        case 6:
            let blockN = d >= 2 ? 2 : 1
            var placed = 0
            for l in 0..<3 {
                if l == free || placed >= blockN { continue }
                addObj(RailRunner64.kGap, laneX(l), start + 5, 3.8, 0.45, 0, 0, 0)
                for k in 0..<6 {
                    let t: Float = Float(k) / 5.0
                    let hh: Float = 0.5 + sin(t * Float.pi) * 1.0
                    addCoin(laneX(l), start + 3.6 + Float(k) * 1.2, hh)
                }
                placed += 1
            }
            for k in 0..<8 { addCoin(fx, start + 1 + Float(k) * 1.4, 0.4) }
            len = 13
        case 7:
            for k in 0..<4 { addCoin(fx, start + 1 + Float(k) * 1.3, 0.4) }
            let r = rng.int(100)
            var kindSub = 3
            if d == 0 {
                kindSub = r < 40 ? 0 : (r < 70 ? 2 : 3)
            } else {
                if r < 28 { kindSub = 0 } else if r < 54 { kindSub = 2 } else if r < 80 { kindSub = 3 } else { kindSub = 1 }
            }
            addObj(RailRunner64.kPower, fx, start + 7, 0, 0.35, 0.6, kindSub, 0)
            for k in 0..<4 { addCoin(fx, start + 9 + Float(k) * 1.3, 0.4) }
            len = 14
        case 8:
            addObj(RailRunner64.kRamp, fx, start + 3, 4.5, 0.45, RailRunner64.roofH, 0, 0)
            for k in 0..<7 {
                let t: Float = Float(k) / 6.0
                let hh: Float = 0.8 + sin(t * Float.pi) * 1.0
                addCoin(fx, start + 9 + Float(k) * 1.4, hh)
            }
            len = 20
        case 9:
            let a = rng.int(3)
            let bb = (a + 1) % 3
            let cc = (a + 2) % 3
            addObj(RailRunner64.kTrain, laneX(a), start + 3, 8, 0.43, 0, rng.int(4), 0)
            addObj(RailRunner64.kLow, laneX(bb), start + 5, 0.3, 0.45, 0.45, 0, 0)
            for k in 0..<10 { addCoin(laneX(cc), start + 1 + Float(k) * 1.3, 0.4) }
            len = 14
        default:
            for k in 0..<16 {
                let wx: Float = sin(Float(k) * 0.5) * 1.0
                addCoin(wx, start + 1 + Float(k) * 1.2, 0.4)
            }
            len = 22
        }
        chunkCount += 1
        let gap: Float = max(5.5, 11.0 - Float(d) * 1.4 - dist / 1800.0)
        genZ = start + len + gap
    }

    private func startJet() {
        jetTimer = 480
        objs.removeAll(where: { o in
            let isDecor = o.kind == RailRunner64.kLamp || o.kind == RailRunner64.kBuild
            return !isDecor && (o.wz - dist) > 3
        })
        var z = dist + 8
        let endZ = dist + 8 + 235
        var k = 0
        while z < endZ {
            let ph: Float = Float(k) * 0.35
            let xx: Float = sin(ph)
            let hh: Float = 2.1 + sin(ph * 0.7) * 0.4
            addCoin(xx, z, hh)
            addCoin(-xx * 0.8, z + 0.9, hh + 0.3)
            z += 1.8
            k += 1
        }
        genZ = endZ + 14
        showBanner("JETPACK!", 80)
    }

    // MARK: - Update

    override func update(_ input: InputState) {
        frame += 1
        if bannerTimer > 0 { bannerTimer -= 1 }
        if shake > 0 { shake -= 1 }
        if flash > 0 { flash -= 1 }
        updateFX()
        switch phase {
        case .title:
            stepWorld(input, true)
            if input.aPressed || input.startPressed {
                beginReady()
                play(.confirm)
            }
        case .ready:
            cdTimer += 1
            camY += (0 - camY) * 0.1
            runPhase += 0.05
            if cdTimer > 20 && (input.aPressed || input.startPressed) {
                beginRun()
            }
        case .run:
            stepWorld(input, false)
        case .caught:
            caughtTimer -= 1
            runPhase += 0.1
            if caughtTimer <= 0 {
                phase = .results
                resultTimer = 0
                bestDist = max(bestDist, Int(dist))
            }
        case .results:
            resultTimer += 1
            if resultTimer > 40 && (input.aPressed || input.startPressed) {
                beginReady()
                play(.confirm)
            }
        }
    }

    private func tryLane(_ dir: Int) {
        let tx: Float = Float(laneTarget - 1)
        let slideLeft: Float = abs(x - tx)
        if slideLeft > 0.3 {
            laneQueue = dir
            return
        }
        let nt = laneTarget + dir
        if nt < 0 || nt > 2 { return }
        laneFrom = laneTarget
        laneTarget = nt
        missionEvent(6, 1)
        play(.step)
    }

    private func doJump() {
        grounded = false
        vy = shoeTimer > 0 ? 0.25 : 0.2
        airFrames = 0
        rollTimer = 0
        fastFall = false
        missionEvent(5, 1)
        play(.jump)
        burst(Float(kidX()), Float(kidY(y)), 4, RailRunner64.cWhite, 1.5, 0.08)
    }

    private func doRoll() {
        rollTimer = 26
        missionEvent(2, 1)
        play(.drop)
        burst(Float(kidX()), Float(kidY(y)), 4, RailRunner64.cWhite, 1.5, 0.08)
    }

    private func stepWorld(_ input: InputState, _ demo: Bool) {
        if stumble > 0 { stumble -= 1 }
        if invuln > 0 { invuln -= 1 }
        if magnetTimer > 0 { magnetTimer -= 1 }
        if multTimer > 0 { multTimer -= 1 }
        if shoeTimer > 0 { shoeTimer -= 1 }
        if rollTimer > 0 { rollTimer -= 1 }
        if jumpBuf > 0 { jumpBuf -= 1 }
        if rollBuf > 0 { rollBuf -= 1 }
        if chase > 0 {
            chase -= 1.0 / 720.0
            if chase < 0 { chase = 0 }
        }
        let jet = jetTimer > 0
        if jetTimer > 0 {
            jetTimer -= 1
            if jetTimer == 0 { showBanner("JETPACK OVER", 50) }
        }
        let ghost = demo || invuln > 0 || jet
        let mult = multTimer > 0 ? 2 : 1

        // speed
        var base: Float = 0.26 + clamp(dist / 9000.0, 0, 0.2)
        if stumble > 0 { base *= 0.55 }
        if jet { base *= 1.1 }
        v += (base - v) * 0.1
        if !v.isFinite { v = 0.26 }
        dist += v
        distPts += v * Float(mult)
        runPhase += v * 1.9
        missionSet(4, Int(dist))

        // moving trains
        for i in 0..<objs.count {
            if objs[i].kind == RailRunner64.kTrain && objs[i].move > 0 {
                let z = objs[i].wz - dist
                if z < 26 {
                    objs[i].wz -= 0.16
                    objs[i].move -= 0.16
                }
            }
        }

        // input
        let canAct = stumble < 25 && !demo
        if demo && frame % 90 == 0 {
            let nl = rng.int(3)
            if nl != laneTarget { tryLane(nl > laneTarget ? 1 : -1) }
        }
        if canAct {
            if input.leftPressed { tryLane(-1) }
            if input.rightPressed { tryLane(1) }
            if input.upPressed || input.aPressed {
                if grounded && !jet {
                    doJump()
                } else {
                    jumpBuf = 7
                }
            }
            if input.downPressed || input.bPressed {
                if grounded && !jet {
                    doRoll()
                } else if !grounded && !jet {
                    fastFall = true
                    if vy > -0.22 { vy = -0.22 }
                    rollBuf = 12
                }
            }
        }
        let tx: Float = Float(laneTarget - 1)
        let dxl: Float = tx - x
        x += clamp(dxl, -0.13, 0.13)
        if laneQueue != 0 && abs(tx - x) <= 0.3 {
            let q = laneQueue
            laneQueue = 0
            tryLane(q)
        }

        // surface under the player
        var surf: Float = 0
        var pit = false
        var onRamp = false
        var hitIdx = -1
        let hitDebris: Float = 0
        _ = hitDebris
        for i in 0..<objs.count {
            let o = objs[i]
            if !o.alive { continue }
            let z = o.wz - dist
            if z > 3 { continue }
            if z + o.len < -0.6 { continue }
            let lat: Float = abs(o.x - x)
            if o.kind == RailRunner64.kTrain {
                if lat < 0.48 && z <= 0.3 && z + o.len >= -0.3 {
                    if y >= RailRunner64.roofH - 0.3 {
                        surf = max(surf, RailRunner64.roofH)
                    } else if !ghost && hitIdx < 0 {
                        hitIdx = i
                    }
                }
            } else if o.kind == RailRunner64.kRamp {
                if lat < 0.47 && z <= 0.1 && z + o.len >= 0 {
                    let s: Float = clamp(-z / o.len, 0, 1) * RailRunner64.roofH
                    surf = max(surf, s)
                    onRamp = true
                }
            } else if o.kind == RailRunner64.kGap {
                if lat < 0.48 && z <= 0.15 && z + o.len >= -0.15 { pit = true }
            } else if o.kind == RailRunner64.kLow {
                if lat < 0.5 && z <= 0.25 && z >= -0.35 && y < 0.28 && !ghost && hitIdx < 0 { hitIdx = i }
            } else if o.kind == RailRunner64.kHigh {
                if lat < o.w + 0.1 && z <= 0.25 && z >= -0.35 && rollTimer <= 0 && y < 0.85 && !ghost && hitIdx < 0 { hitIdx = i }
            }
        }
        if pit && surf <= 0 && !ghost { surf = -9 }
        surfNow = max(0, surf)

        // vertical motion
        if jet {
            grounded = false
            vy = 0
            y += (2.4 - y) * 0.08
            airFrames = 0
            fastFall = false
            if frame % 2 == 0 {
                addPart(Float(kidX()) + Float(rng.range(-5, 5)), Float(kidY(y)) - 6, 0, 3, 0.1, 14, 3, rng.chance(50) ? RailRunner64.cOrange : RailRunner64.cYellow)
            }
        } else {
            if grounded {
                if surf > y + 0.0001 {
                    y = surf
                } else if surf < y - 0.03 {
                    grounded = false
                    vy = onRampPrev ? 0.09 : 0
                    airFrames = 0
                } else {
                    y = surf
                }
            }
            if !grounded {
                y += vy
                vy -= RailRunner64.gravity
                if vy < -0.4 { vy = -0.4 }
                airFrames += 1
                if y <= surf && vy <= 0 {
                    landOn(surf)
                } else if y < -1.3 {
                    fellInPit()
                }
            }
        }
        onRampPrev = onRamp
        if !y.isFinite { y = 0 }

        // collisions
        if hitIdx >= 0 && hitIdx < objs.count {
            let o = objs[hitIdx]
            if o.kind == RailRunner64.kTrain || o.kind == RailRunner64.kLow || o.kind == RailRunner64.kHigh {
                objs[hitIdx].alive = false
                hitPlayer(o.kind)
                if phase != .run { return }
            }
        }

        // pickups
        let magnet = magnetTimer > 0
        for i in 0..<objs.count {
            let o = objs[i]
            if !o.alive { continue }
            if o.kind != RailRunner64.kCoin && o.kind != RailRunner64.kPower { continue }
            let z = o.wz - dist
            if z > 9 || z < -1.2 { continue }
            if magnet && o.kind == RailRunner64.kCoin && z > -0.5 {
                objs[i].x += (x - o.x) * 0.2
                objs[i].h += ((y + 0.34) - o.h) * 0.12
            }
            let lat: Float = abs(objs[i].x - x)
            let latMax: Float = magnet ? 1.2 : 0.55
            if abs(z) < 0.6 && lat < latMax && abs(objs[i].h - (y + 0.34)) < 0.85 {
                objs[i].alive = false
                if o.kind == RailRunner64.kCoin {
                    collectCoin(mult)
                } else {
                    collectPower(o.sub)
                }
            }
        }

        // generation and cleanup
        var guardCount = 0
        while genZ < dist + 85 && guardCount < 4 {
            genChunk(demo)
            guardCount += 1
        }
        guardCount = 0
        while decorZ < dist + 85 && guardCount < 8 {
            genDecor()
            guardCount += 1
        }
        objs.removeAll(where: { $0.alive == false || ($0.wz + $0.len - dist) < -7 })
        sortObjs()

        // hints
        hint = ""
        if !demo {
            if frame % 1 == 0 && dist < 25 { hint = "LEFT RIGHT: SWITCH LANE" }
            if !tipJump {
                for o in objs {
                    let z = o.wz - dist
                    if o.kind == RailRunner64.kLow && z > 0 && z < 15 { hint = "UP OR A: JUMP!" }
                    if o.kind == RailRunner64.kLow && z < -1 { tipJump = true }
                }
            }
            if !tipRoll {
                for o in objs {
                    let z = o.wz - dist
                    if o.kind == RailRunner64.kHigh && z > 0 && z < 15 { hint = "DOWN OR B: ROLL!" }
                    if o.kind == RailRunner64.kHigh && z < -1 { tipRoll = true }
                }
            }
        }

        camY += (y - camY) * 0.12
        camHNow = RailRunner64.camBase + 0.7 * camY
        if !camHNow.isFinite { camHNow = RailRunner64.camBase }
        if grounded && frame % 8 == 0 && v > 0.2 && !demo {
            addPart(Float(kidX()) + Float(rng.range(-6, 6)), Float(kidY(y)), Float(rng.range(-5, 5)) / 10.0, 0.6, 0.02, 12, 2, RailRunner64.cWhite)
        }
    }

    private func sortObjs() {
        var i = 1
        while i < objs.count {
            let o = objs[i]
            var j = i - 1
            while j >= 0 && objs[j].wz > o.wz {
                objs[j + 1] = objs[j]
                j -= 1
            }
            objs[j + 1] = o
            i += 1
        }
    }

    private func landOn(_ surf: Float) {
        y = surf
        vy = 0
        grounded = true
        fastFall = false
        if surf >= RailRunner64.roofH - 0.05 {
            if airFrames > 4 {
                missionEvent(1, 1)
                bonusPts += 25
                addText("TRAIN TOP! +25", Float(kidX()), Float(kidY(y)) - 50, RailRunner64.cCyan)
                play(.bounce)
            }
            burst(Float(kidX()), Float(kidY(y)), 6, RailRunner64.cCyan, 2.0, 0.08)
        } else if airFrames > 8 {
            play(.thud)
            burst(Float(kidX()), Float(kidY(y)), 6, RailRunner64.cWhite, 2.0, 0.08)
        }
        airFrames = 0
        if rollBuf > 0 {
            rollBuf = 0
            doRoll()
        }
        if jumpBuf > 0 {
            jumpBuf = 0
            doJump()
        }
    }

    private func fellInPit() {
        y = 0
        vy = 0
        grounded = true
        airFrames = 0
        hitPlayer(RailRunner64.kGap)
    }

    private func collectCoin(_ mult: Int) {
        coins += 1
        coinPts += 10 * mult
        missionEvent(0, 1)
        missionEvent(7, 1)
        burst(Float(kidX()), Float(kidY(y)) - 24, 2, RailRunner64.cGold, 2.2, 0.1)
        if frame - lastCoinSfx >= 3 {
            play(.pickup)
            lastCoinSfx = frame
        }
        if coins % 25 == 0 {
            addText(String(coins) + " COINS!", Float(kidX()), Float(kidY(y)) - 60, RailRunner64.cYellow)
        }
    }

    private func collectPower(_ sub: Int) {
        missionEvent(3, 1)
        play(.powerup)
        var name = "MAGNET!"
        if sub == 0 {
            magnetTimer = 600
        } else if sub == 1 {
            startJet()
            name = "JETPACK!"
        } else if sub == 2 {
            multTimer = 600
            name = "2X SCORE!"
        } else {
            shoeTimer = 600
            name = "SUPER SNEAKERS!"
        }
        addText(name, Float(kidX()), Float(kidY(y)) - 60, RailRunner64.cGreen)
        burst(Float(kidX()), Float(kidY(y)) - 20, 12, RailRunner64.cGreen, 3.0, 0.08)
    }

    private func hitPlayer(_ kind: Int) {
        if invuln > 0 || jetTimer > 0 || phase != .run { return }
        shake = 12
        flash = 6
        let sx = Float(kidX())
        let sy = Float(kidY(y)) - 20
        burst(sx, sy, 12, RailRunner64.cOrange, 3.2, 0.12)
        burst(sx, sy, 6, RailRunner64.cWhite, 2.4, 0.06)
        if abs(x - Float(laneTarget - 1)) > 0.2 {
            laneTarget = laneFrom
            laneQueue = 0
        }
        if chase > 0.25 {
            phase = .caught
            caughtTimer = 110
            play(.hurt)
            play(.lose)
            showBanner("CAUGHT!", 110)
            return
        }
        stumble = 40
        invuln = 100
        chase = 1.0
        rollTimer = 0
        showBanner("OUCH! WATCH OUT!", 70)
        addText("THE GUARD IS CLOSE!", 160, 150, RailRunner64.cRed)
        play(.hurt)
    }

    // MARK: - Rendering helpers

    @inline(__always) private func spanP(_ p: UnsafeMutablePointer<UInt32>, _ yy: Int, _ x0: Int, _ x1: Int, _ c: UInt32) {
        if yy < 0 || yy >= 288 { return }
        let a = max(0, x0)
        let e = min(320, x1)
        if a >= e { return }
        var i = yy * 320 + a
        let end = yy * 320 + e
        while i < end {
            p[i] = c
            i += 1
        }
    }

    private func rectP(_ p: UnsafeMutablePointer<UInt32>, _ rx: Int, _ ry: Int, _ rw: Int, _ rh: Int, _ c: UInt32) {
        if rw <= 0 || rh <= 0 { return }
        let y0 = max(0, ry)
        let y1 = min(288, ry + rh)
        if y0 >= y1 { return }
        for yy in y0..<y1 { spanP(p, yy, rx, rx + rw, c) }
    }

    private func discP(_ p: UnsafeMutablePointer<UInt32>, _ cx: Int, _ cy: Int, _ r: Int, _ c: UInt32) {
        if r <= 0 { return }
        for dy in -r...r {
            let hw = Int(sqrt(Float(r * r - dy * dy)))
            spanP(p, cy + dy, cx - hw, cx + hw + 1, c)
        }
    }

    private func fillQuad(_ p: UnsafeMutablePointer<UInt32>, _ y0: Int, _ y1: Int,
                          _ xl0: Float, _ xr0: Float, _ xl1: Float, _ xr1: Float, _ c: UInt32) {
        let ya = max(0, y0)
        let yb = min(288, y1)
        if ya >= yb { return }
        let inv: Float = 1.0 / Float(max(1, y1 - y0))
        for r in ya..<yb {
            let t: Float = Float(r - y0) * inv
            let xl: Float = xl0 + (xl1 - xl0) * t
            let xr: Float = xr0 + (xr1 - xr0) * t
            spanP(p, r, Int(clamp(xl, -3000, 3000)), Int(clamp(xr, -3000, 3000)), c)
        }
    }

    private func fogOf(_ zc: Float) -> Int {
        let t: Float = clamp((zc - 24) / 56, 0, 0.9)
        return Int(t * 256)
    }

    private func fogCol(_ c: UInt32, _ fog: Int) -> UInt32 {
        return RailRunner64.blend(c, hazeR, hazeG, hazeB, fog)
    }

    private func drawBox(_ p: UnsafeMutablePointer<UInt32>, _ xa: Float, _ xb: Float, _ ht: Float,
                         _ zn: Float, _ zf: Float, _ cols: BoxCols, _ style: Int, _ fog: Int) {
        let zcN: Float = max(0.5, zn + RailRunner64.camBack)
        let zcF: Float = min(zf + RailRunner64.camBack, 110)
        if zcF <= 0.5 || zcN >= zcF { return }
        let xlN = projX(xa, zcN)
        let xrN = projX(xb, zcN)
        let xlF = projX(xa, zcF)
        let xrF = projX(xb, zcF)
        let yGN = projY(0, zcN)
        let yTN = projY(ht, zcN)
        let yGF = projY(0, zcF)
        let yTF = projY(ht, zcF)
        let sideC = fogCol(cols.side, fog)
        let roofC = fogCol(cols.roof, fog)
        let frontC = fogCol(cols.front, fog)
        let accC = fogCol(cols.accent, fog)
        let mid: Float = (xa + xb) * 0.5
        // side face
        if abs(mid) > 0.12 {
            let faceX: Float = mid > 0 ? xa : xb
            let sN: Float = mid > 0 ? xlN : xrN
            let sF: Float = mid > 0 ? xlF : xrF
            if abs(sN - sF) >= 0.5 {
                let cs = max(0, Int(min(sN, sF)))
                let ce = min(319, Int(max(sN, sF)))
                if cs <= ce {
                    for c in cs...ce {
                        let t: Float = (Float(c) - sF) / (sN - sF)
                        let top = Int(yTF + (yTN - yTF) * t)
                        let bot = Int(yGF + (yGN - yGF) * t)
                        let y0 = max(0, top)
                        let y1 = min(287, bot)
                        if y0 > y1 { continue }
                        var win = false
                        if style == 0 {
                            let dx: Float = max(0.5, abs(Float(c) - 160))
                            let zcol: Float = abs(faceX) * RailRunner64.sc / dx
                            let u: Float = (zcol - RailRunner64.camBack - zn) * 1.25
                            let fr: Float = u - floor(u)
                            win = fr < 0.6 && u > 0.5
                        }
                        for yy in y0...y1 {
                            var cc = sideC
                            if win {
                                let fy: Float = Float(yy - top) / Float(max(1, bot - top))
                                if fy > 0.22 && fy < 0.55 { cc = accC }
                            }
                            p[yy * 320 + c] = cc
                        }
                    }
                }
            }
        }
        // roof
        if ht < camHNow - 0.02 {
            fillQuad(p, Int(yTF), Int(yTN), xlF, xrF, xlN, xrN, roofC)
        }
        // front
        if zn + RailRunner64.camBack > 0.5 {
            let fx0 = Int(clamp(xlN, -3000, 3000))
            let fx1 = Int(clamp(xrN, -3000, 3000))
            let fy0 = Int(clamp(yTN, -3000, 3000))
            let fy1 = Int(clamp(yGN, -3000, 3000))
            let fw = fx1 - fx0
            let fh = fy1 - fy0
            if fw > 0 && fh > 0 {
                rectP(p, fx0, fy0, fw, fh, frontC)
                if style == 0 {
                    rectP(p, fx0 + fw / 8, fy0 + fh / 7, fw * 3 / 4, fh * 3 / 8, accC)
                    rectP(p, fx0 + fw / 8, fy0 + fh * 11 / 20, fw * 3 / 4, max(1, fh / 12), fogCol(RailRunner64.cWhite, fog))
                    let lampC = fogCol(RailRunner64.cYellow, fog)
                    rectP(p, fx0 + fw / 8, fy0 + fh * 7 / 10, max(1, fw / 6), max(1, fh / 8), lampC)
                    rectP(p, fx0 + fw * 3 / 4, fy0 + fh * 7 / 10, max(1, fw / 6), max(1, fh / 8), lampC)
                } else if style == 1 {
                    let cell: Int = Int(0.55 * RailRunner64.sc / zcN)
                    if cell >= 4 {
                        var wy = fy0 + cell / 2
                        var row = 0
                        while wy + cell < fy1 - 2 {
                            var wx = fx0 + cell / 2
                            var cl = 0
                            while wx + cell < fx1 - 1 {
                                let lit = ((row * 5 + cl * 3 + Int(zn * 0.5)) & 3) != 0
                                if lit { rectP(p, wx, wy, cell * 6 / 10, cell * 6 / 10, accC) }
                                wx += cell
                                cl += 1
                            }
                            wy += cell
                            row += 1
                        }
                    }
                }
            }
        }
    }

    private func drawFlat(_ p: UnsafeMutablePointer<UInt32>, _ xa: Float, _ xb: Float, _ zn: Float, _ zf: Float,
                          _ c: UInt32, _ edge: UInt32) {
        let zcN: Float = max(0.5, zn + RailRunner64.camBack)
        let zcF: Float = min(zf + RailRunner64.camBack, 110)
        if zcF <= 0.5 || zcN >= zcF { return }
        let yN = Int(projY(0, zcN))
        let yF = Int(projY(0, zcF))
        fillQuad(p, yF, yN, projX(xa, zcF), projX(xb, zcF), projX(xa, zcN), projX(xb, zcN), c)
        // hazard lip at the near edge
        let lip = max(1, (yN - yF) / 8)
        fillQuad(p, yN - lip, yN, projX(xa, zcN), projX(xb, zcN), projX(xa, zcN), projX(xb, zcN), edge)
    }

    private func drawRamp(_ p: UnsafeMutablePointer<UInt32>, _ xa: Float, _ xb: Float, _ zn: Float, _ zf: Float, _ fog: Int) {
        let zcN: Float = max(0.5, zn + RailRunner64.camBack)
        let zcF: Float = min(zf + RailRunner64.camBack, 110)
        if zcF <= 0.5 || zcN >= zcF { return }
        let yN = Int(projY(0, zcN))
        let yF = Int(projY(RailRunner64.roofH, zcF))
        if yN <= yF { return }
        let xlN = projX(xa, zcN)
        let xrN = projX(xb, zcN)
        let xlF = projX(xa, zcF)
        let xrF = projX(xb, zcF)
        let c1 = fogCol(RailRunner64.col(255, 214, 60), fog)
        let c2 = fogCol(RailRunner64.col(60, 60, 70), fog)
        let ya = max(0, yF)
        let yb = min(288, yN)
        if ya >= yb { return }
        let inv: Float = 1.0 / Float(max(1, yN - yF))
        for r in ya..<yb {
            let t: Float = Float(r - yF) * inv
            let xl: Float = xlF + (xlN - xlF) * t
            let xr: Float = xrF + (xrN - xrF) * t
            let cc = (((r - yF) / 4) & 1) == 0 ? c1 : c2
            spanP(p, r, Int(clamp(xl, -3000, 3000)), Int(clamp(xr, -3000, 3000)), cc)
        }
    }

    private func drawCoin(_ p: UnsafeMutablePointer<UInt32>, _ cxw: Float, _ cyw: Float, _ zc: Float, _ idx: Int, _ fog: Int) {
        let sx = Int(clamp(projX(cxw, zc), -400, 700))
        let sy = Int(clamp(projY(cyw, zc), -400, 700))
        let r = max(1, Int(0.24 * RailRunner64.sc / zc))
        let ang: Float = Float(frame) * 0.12 + Float(idx) * 0.7
        let rx = max(1, Int(Float(r) * abs(cos(ang))))
        let gold = fogCol(RailRunner64.cGold, fog)
        let goldD = fogCol(RailRunner64.col(220, 140, 20), fog)
        for dy in -r...r {
            let f: Float = Float(dy) / Float(r)
            let hw = max(1, Int(Float(rx) * sqrt(max(0, 1 - f * f))))
            spanP(p, sy + dy, sx - hw, sx + hw + 1, abs(dy) > r - 1 || hw == rx ? goldD : gold)
        }
        if rx > 2 && r > 3 {
            rectP(p, sx - rx / 3, sy - r / 2, max(1, rx / 3), max(1, r), fogCol(RailRunner64.col(255, 244, 170), fog))
        }
    }

    private func drawPower(_ p: UnsafeMutablePointer<UInt32>, _ cxw: Float, _ cyw: Float, _ zc: Float, _ sub: Int, _ fog: Int) {
        let sx = Int(clamp(projX(cxw, zc), -400, 700))
        let sy = Int(clamp(projY(cyw, zc), -400, 700))
        let r = max(3, Int(0.42 * RailRunner64.sc / zc))
        let pulse: Int = ((frame / 6) & 1) == 0 ? 0 : 1
        let cols: [UInt32] = [RailRunner64.col(240, 60, 70), RailRunner64.col(70, 150, 255),
                              RailRunner64.col(255, 200, 40), RailRunner64.col(60, 210, 100)]
        let cc = fogCol(cols[max(0, min(3, sub))], fog)
        discP(p, sx, sy, r + 2 + pulse, fogCol(RailRunner64.cWhite, fog))
        discP(p, sx, sy, r, cc)
        let u = max(1, r / 5)
        let wh = fogCol(RailRunner64.cWhite, fog)
        if sub == 0 {
            rectP(p, sx - 3 * u, sy - 3 * u, 2 * u, 6 * u, wh)
            rectP(p, sx + u, sy - 3 * u, 2 * u, 6 * u, wh)
            rectP(p, sx - 3 * u, sy + 2 * u, 6 * u, 2 * u, wh)
        } else if sub == 1 {
            rectP(p, sx - u, sy - 4 * u, 2 * u, 7 * u, wh)
            rectP(p, sx - 2 * u, sy + 2 * u, 4 * u, u, wh)
            rectP(p, sx - u, sy + 3 * u, 2 * u, 2 * u, fogCol(RailRunner64.cOrange, fog))
        } else if sub == 2 {
            rectP(p, sx - 3 * u, sy - 3 * u, 3 * u, u, wh)
            rectP(p, sx - u, sy - 2 * u, u, 2 * u, wh)
            rectP(p, sx - 3 * u, sy, 3 * u, u, wh)
            rectP(p, sx - 3 * u, sy + u, u, 2 * u, wh)
            rectP(p, sx - 3 * u, sy + 3 * u, 3 * u, u, wh)
            rectP(p, sx + u, sy - 3 * u, u, 6 * u, wh)
            rectP(p, sx + 2 * u, sy - 3 * u, 2 * u, u, wh)
        } else {
            rectP(p, sx - 3 * u, sy - u, 4 * u, 3 * u, wh)
            rectP(p, sx - 3 * u, sy + 2 * u, 6 * u, u, wh)
            rectP(p, sx + u, sy - 3 * u, u, 2 * u, wh)
        }
    }

    // MARK: - Background

    private func prepareSky() {
        var d: Float = clamp((dist - 150) / 1300.0, 0, 1)
        if phase == .title { d = 0 }
        duskAmt = d
        let tr: Float = 64 + (96 - 64) * d
        let tg: Float = 150 + (60 - 150) * d
        let tb: Float = 255 + (150 - 255) * d
        let br: Float = 190 + (255 - 190) * d
        let bg: Float = 232 + (170 - 232) * d
        let bb: Float = 255 + (110 - 255) * d
        for yy in 0..<100 {
            var f: Float = Float(yy) / 96.0
            if f > 1 { f = 1 }
            let r = Int(tr + (br - tr) * f)
            let g = Int(tg + (bg - tg) * f)
            let b = Int(tb + (bb - tb) * f)
            skyRowCols[yy] = TrueColorBuffer.rgb(r, g, b)
        }
        hazeR = Int(br)
        hazeG = Int(bg)
        hazeB = Int(bb)
    }

    private func tint(_ c: UInt32, _ warm: Int) -> UInt32 {
        // blend towards sunset orange by dusk
        let t: Int = Int(duskAmt * Float(warm))
        return RailRunner64.blend(c, 255, 120, 90, t)
    }

    private func drawSkyline(_ p: UnsafeMutablePointer<UInt32>, _ tbl: [Int], _ shift: Int, _ colr: UInt32, _ lit: Bool) {
        let hzI = 96
        let wc0 = RailRunner64.col(255, 236, 130)
        let wc1 = RailRunner64.col(255, 190, 110)
        let thr: Int = Int(duskAmt * 6)
        for xx in 0..<320 {
            let wx = (xx + shift + 512) & 511
            let hgt = tbl[wx]
            let top = hzI - hgt
            if top >= hzI { continue }
            for yy in max(0, top)..<hzI {
                var cc = colr
                if lit && thr > 0 && (wx & 3) != 3 && (yy & 3) != 3 && yy > top + 2 {
                    let key = ((wx >> 2) * 7 + (yy >> 2) * 13) & 7
                    if key < thr { cc = ((wx >> 3) & 1) == 0 ? wc0 : wc1 }
                }
                p[yy * 320 + xx] = cc
            }
        }
    }

    private func renderWorld(_ p: UnsafeMutablePointer<UInt32>) {
        prepareSky()
        let hzI = 96
        for yy in 0..<hzI { spanP(p, yy, 0, 320, skyRowCols[yy]) }
        // sun
        let sunY: Int = 44 + Int(duskAmt * 44)
        let sunC = RailRunner64.blend(RailRunner64.col(255, 252, 214), 255, 150, 70, Int(duskAmt * 200))
        discP(p, 246, sunY, 20, RailRunner64.blend(sunC, hazeR, hazeG, hazeB, 90))
        discP(p, 246, sunY, 14, sunC)
        // clouds
        let cloudC = tint(RailRunner64.col(255, 255, 255), 140)
        for i in 0..<4 {
            let cx0: Int = (((i * 120 + 30 - frame / 6) % 480) + 480) % 480 - 80
            let cy0: Int = 16 + (i * 17) % 40
            discP(p, cx0, cy0, 8, cloudC)
            discP(p, cx0 + 11, cy0 + 2, 6, cloudC)
            discP(p, cx0 - 11, cy0 + 3, 5, cloudC)
        }
        // skyline layers
        let shiftF: Int = Int(x * 5)
        let shiftN: Int = Int(x * 10)
        drawSkyline(p, RailRunner64.skylineFar, shiftF, tint(RailRunner64.col(120, 140, 185), 190), false)
        drawSkyline(p, RailRunner64.skylineNear, shiftN + 100, tint(RailRunner64.col(84, 100, 150), 210), true)
        // ground
        let gravelA = tint(RailRunner64.col(160, 150, 134), 110)
        let gravelB = tint(RailRunner64.col(140, 130, 116), 110)
        let platC = tint(RailRunner64.col(206, 204, 200), 90)
        let platD = tint(RailRunner64.col(176, 176, 176), 90)
        let outer = tint(RailRunner64.col(92, 124, 84), 120)
        let tieC = tint(RailRunner64.col(98, 66, 44), 90)
        let railC = RailRunner64.col(236, 238, 246)
        let railD = RailRunner64.col(120, 124, 140)
        let lineY = RailRunner64.col(255, 214, 60)
        let camH = camHNow
        let sc = RailRunner64.sc
        var row = hzI
        while row < 288 {
            let dyy: Float = Float(row - hzI)
            if dyy < 1 {
                spanP(p, row, 0, 320, gravelA)
                row += 1
                continue
            }
            let zc: Float = camH * sc / dyy
            let fog = fogOf(zc)
            let wzRow: Float = dist + zc - RailRunner64.camBack
            let band = Int(floor(wzRow * 0.5)) & 1
            let k: Float = sc / zc
            spanP(p, row, 0, 320, fogCol(outer, fog))
            // platforms
            let pl0 = Int(160 - 2.6 * k)
            let pl1 = Int(160 - 1.6 * k)
            let pr0 = Int(160 + 1.6 * k)
            let pr1 = Int(160 + 2.6 * k)
            let pc = band == 0 ? platC : platD
            spanP(p, row, pl0, pl1, fogCol(pc, fog))
            spanP(p, row, pr0, pr1, fogCol(pc, fog))
            let ly: Int = max(1, Int(0.06 * k))
            spanP(p, row, pl1 - ly, pl1, fogCol(lineY, fog))
            spanP(p, row, pr0, pr0 + ly, fogCol(lineY, fog))
            // gravel bed
            spanP(p, row, pl1, pr0, fogCol(band == 0 ? gravelA : gravelB, fog))
            // ties and rails per lane
            let tf: Float = wzRow * 1.8
            let tfr: Float = tf - floor(tf)
            let isTie = tfr < 0.42
            for l in 0..<3 {
                let lc: Float = Float(l - 1)
                if isTie {
                    let t0 = Int(160 + (lc - 0.46) * k)
                    let t1 = Int(160 + (lc + 0.46) * k)
                    spanP(p, row, t0, t1, fogCol(tieC, fog))
                }
                let rw: Int = max(1, Int(0.045 * k))
                let r0 = Int(160 + (lc - 0.28) * k)
                let r1 = Int(160 + (lc + 0.28) * k)
                spanP(p, row, r0 - rw, r0 + rw, fogCol(railC, fog))
                spanP(p, row, r1 - rw, r1 + rw, fogCol(railC, fog))
                if rw >= 2 {
                    spanP(p, row, r0 + rw, r0 + rw + 1, fogCol(railD, fog))
                    spanP(p, row, r1 + rw, r1 + rw + 1, fogCol(railD, fog))
                }
            }
            row += 1
        }
        // objects far to near
        var i = objs.count - 1
        while i >= 0 {
            let o = objs[i]
            i -= 1
            if !o.alive { continue }
            let z = o.wz - dist
            if z > RailRunner64.farZ { continue }
            if z + o.len + RailRunner64.camBack < 0.5 { continue }
            let zcN = max(0.5, z + RailRunner64.camBack)
            let fog = fogOf(zcN)
            if o.kind == RailRunner64.kTrain {
                let body = RailRunner64.trainBody[o.sub & 3]
                var cols = BoxCols(side: tint(body, 70), roof: tint(RailRunner64.blend(body, 255, 255, 255, 90), 70),
                                   front: tint(RailRunner64.blend(body, 0, 0, 30, 40), 70),
                                   accent: RailRunner64.col(60, 90, 130))
                if o.h > 0.5 && o.move > 0 && (frame / 5) & 1 == 0 { cols.accent = RailRunner64.col(255, 250, 200) }
                drawBox(p, o.x - o.w, o.x + o.w, RailRunner64.roofH, z, z + o.len, cols, 0, fog)
            } else if o.kind == RailRunner64.kLow {
                let stripe = (((frame / 1) + 0) & 0) == 0
                _ = stripe
                let cols = BoxCols(side: RailRunner64.col(240, 70, 60), roof: RailRunner64.col(255, 255, 255),
                                   front: RailRunner64.col(250, 250, 250), accent: RailRunner64.col(240, 70, 60))
                drawBox(p, o.x - 0.42, o.x + 0.42, 0.45, z, z + 0.3, cols, 2, fog)
                // red stripes on the front
                let zc = z + RailRunner64.camBack
                if zc > 0.5 {
                    let xl = projX(o.x - 0.42, zc)
                    let xr = projX(o.x + 0.42, zc)
                    let yt = projY(0.45, zc)
                    let yb = projY(0, zc)
                    let sw = max(2, Int((xr - xl) / 6))
                    var sxp = Int(xl)
                    var flip = false
                    while sxp < Int(xr) {
                        if flip { rectP(p, sxp, Int(yt), sw, Int(yb - yt), fogCol(RailRunner64.col(240, 70, 60), fog)) }
                        flip = !flip
                        sxp += sw
                    }
                }
            } else if o.kind == RailRunner64.kHigh {
                let zc = z + RailRunner64.camBack
                if zc > 0.5 {
                    let xl = projX(o.x - o.w, zc)
                    let xr = projX(o.x + o.w, zc)
                    let yTop = projY(0.85, zc)
                    let yBot = projY(0.55, zc)
                    let yGround = projY(0, zc)
                    let postW = max(2, Int(0.07 * RailRunner64.sc / zc))
                    let post = fogCol(RailRunner64.col(90, 94, 120), fog)
                    rectP(p, Int(xl) - postW, Int(yTop) - Int((yBot - yTop)), postW, Int(yGround - yTop) + Int(yBot - yTop), post)
                    rectP(p, Int(xr), Int(yTop) - Int((yBot - yTop)), postW, Int(yGround - yTop) + Int(yBot - yTop), post)
                    let sw = max(3, Int((yBot - yTop) * 1.4))
                    var sxp = Int(xl)
                    var flip = false
                    let yc1 = fogCol(RailRunner64.col(255, 214, 40), fog)
                    let yc2 = fogCol(RailRunner64.col(30, 30, 40), fog)
                    while sxp < Int(xr) {
                        let wd = min(sw, Int(xr) - sxp)
                        rectP(p, sxp, Int(yTop), wd, max(1, Int(yBot - yTop)), flip ? yc2 : yc1)
                        flip = !flip
                        sxp += sw
                    }
                }
            } else if o.kind == RailRunner64.kGap {
                drawFlat(p, o.x - 0.46, o.x + 0.46, z, z + o.len, fogCol(RailRunner64.col(12, 10, 24), fog), fogCol(RailRunner64.cYellow, fog))
            } else if o.kind == RailRunner64.kRamp {
                drawRamp(p, o.x - 0.44, o.x + 0.44, z, z + o.len, fog)
            } else if o.kind == RailRunner64.kCoin {
                if z + RailRunner64.camBack > 0.6 { drawCoin(p, o.x, o.h, z + RailRunner64.camBack, i, fog) }
            } else if o.kind == RailRunner64.kPower {
                if z + RailRunner64.camBack > 0.6 { drawPower(p, o.x, o.h + 0.2, z + RailRunner64.camBack, o.sub, fog) }
            } else if o.kind == RailRunner64.kLamp {
                let cols = BoxCols(side: RailRunner64.col(70, 74, 96), roof: RailRunner64.col(110, 114, 136),
                                   front: RailRunner64.col(90, 94, 116), accent: RailRunner64.col(255, 240, 180))
                drawBox(p, o.x - 0.05, o.x + 0.05, o.h, z, z + 0.1, cols, 2, fog)
                let zc = z + RailRunner64.camBack
                if zc > 0.6 {
                    let lx = Int(projX(o.x, zc))
                    let ly = Int(projY(o.h + 0.05, zc))
                    let ls = max(2, Int(0.18 * RailRunner64.sc / zc))
                    let lampC = RailRunner64.blend(RailRunner64.col(255, 250, 200), hazeR, hazeG, hazeB, fog)
                    rectP(p, lx - ls / 2, ly - ls / 2, ls, ls, lampC)
                }
            } else if o.kind == RailRunner64.kBuild {
                let pal: [UInt32] = [RailRunner64.col(170, 110, 100), RailRunner64.col(110, 130, 180),
                                     RailRunner64.col(150, 150, 120), RailRunner64.col(130, 100, 150)]
                let b0 = pal[o.sub & 3]
                let cols = BoxCols(side: tint(RailRunner64.blend(b0, 0, 0, 20, 50), 120), roof: tint(b0, 120),
                                   front: tint(b0, 120), accent: RailRunner64.col(255, 236, 140))
                drawBox(p, o.x - o.w, o.x + o.w, o.h, z, z + o.len, cols, 1, fog)
            }
        }
    }

    override func drawTrueColor(_ b: TrueColorBuffer) {
        b.withPixels { p, w, h in
            if w != 320 || h != 288 { return }
            self.renderWorld(p)
            if self.flash > 0 { self.applyFlash(p) }
        }
        drawChasers(b)
        drawKid(b)
        drawParticles(b)
        drawHUD(b)
        drawOverlays(b)
    }

    private func applyFlash(_ p: UnsafeMutablePointer<UInt32>) {
        let amt = min(140, flash * 26)
        var i = 0
        while i < 320 * 288 {
            p[i] = RailRunner64.blend(p[i], 255, 70, 60, amt)
            i += 1
        }
    }

    // MARK: - Characters

    private func discRows(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int, _ r: Int, _ colr: UInt32) {
        if r <= 0 { return }
        for dy in -r...r {
            let hw = Int(sqrt(Float(r * r - dy * dy)))
            b.fillRect(cx - hw, cy + dy, hw * 2 + 1, 1, colr)
        }
    }

    private func drawKid(_ b: TrueColorBuffer) {
        let cx = kidX()
        var fy = kidY(y)
        let gy = kidY(surfNow)
        let air = max(0, gy - fy)
        let sw = max(10, 30 - air / 5)
        let shadow = tint(RailRunner64.col(90, 84, 72), 100)
        b.fillRect(cx - sw / 2, gy - 1, sw, 3, shadow)
        b.fillRect(cx - sw / 2 + 3, gy - 2, max(2, sw - 6), 1, shadow)
        if phase == .results || (phase == .title) { if phase == .results { return } }
        let hurt = stumble > 0
        if invuln > 0 && !hurt && ((frame / 3) & 1) == 0 && jetTimer == 0 { return }
        let teal = RailRunner64.col(32, 196, 190)
        let tealD = RailRunner64.col(18, 136, 150)
        let yellow = RailRunner64.col(255, 214, 60)
        let jeans = RailRunner64.col(50, 80, 172)
        let skin = RailRunner64.col(255, 214, 176)
        let beanie = RailRunner64.col(238, 62, 70)
        let hair = RailRunner64.col(120, 70, 40)
        let pack = RailRunner64.col(255, 140, 40)
        let packD = RailRunner64.col(200, 90, 20)
        let outl = RailRunner64.col(30, 24, 50)
        let white = RailRunner64.cWhite
        let rolling = rollTimer > 0 && grounded
        if rolling {
            let spin: Float = Float(rollTimer) * 0.6
            discRows(b, cx, fy - 13, 14, outl)
            discRows(b, cx, fy - 13, 13, teal)
            discRows(b, cx, fy - 11, 8, tealD)
            for k in 0..<3 {
                let a: Float = spin + Float(k) * 2.094
                let px = cx + Int(cos(a) * 8)
                let pyy = fy - 13 + Int(sin(a) * 8)
                b.fillRect(px - 2, pyy - 2, 5, 5, k == 0 ? beanie : (k == 1 ? pack : white))
            }
            return
        }
        var bob = 0
        var swing: Float = sin(runPhase)
        var armsUp = false
        var tuck = false
        if !grounded {
            tuck = true
            armsUp = !hurt
            bob = 0
        } else {
            bob = Int(abs(swing) * 2.0)
        }
        if jetTimer > 0 {
            fy -= 0
            tuck = false
            swing = 0
        }
        let jx: Int = hurt ? Int(sin(Float(frame) * 1.5) * 3) : 0
        let ccx = cx + jx
        // jetpack flames
        if jetTimer > 0 {
            let fl = (frame & 2) == 0 ? 14 : 20
            b.fillRect(ccx - 9, fy - 40, 6, fl, RailRunner64.cOrange)
            b.fillRect(ccx + 3, fy - 40, 6, fl, RailRunner64.cOrange)
            b.fillRect(ccx - 8, fy - 40, 4, fl - 6, RailRunner64.cYellow)
            b.fillRect(ccx + 4, fy - 40, 4, fl - 6, RailRunner64.cYellow)
        }
        // legs
        for side in 0..<2 {
            let sgn = side == 0 ? -1 : 1
            let sw2: Float = side == 0 ? swing : -swing
            var lift = Int(max(0, sw2) * 6.0)
            var lx = ccx + sgn * 5 - 3
            if tuck {
                lift = 7
                lx = ccx + sgn * 7 - 3
            }
            if jetTimer > 0 {
                lift = 3
                lx = ccx + sgn * 4 - 3
            }
            let shoeY = fy - 5 - lift
            let legTop = fy - 22 - bob
            let legH = shoeY - legTop
            b.fillRect(lx - 1, legTop, 7, max(1, legH), outl)
            if legH > 0 { b.fillRect(lx, legTop, 5, legH, jeans) }
            b.fillRect(lx - 2, shoeY - 1, 9, 7, outl)
            b.fillRect(lx - 1, shoeY, 7, 5, white)
            b.fillRect(lx - 1, shoeY + 4, 7, 1, RailRunner64.cRed)
        }
        // body
        let bodyTop = fy - 44 - bob
        b.fillRect(ccx - 11, bodyTop - 1, 22, 25, outl)
        b.fillRect(ccx - 10, bodyTop, 20, 23, teal)
        b.fillRect(ccx - 10, bodyTop + 19, 20, 4, tealD)
        b.fillRect(ccx - 1, bodyTop + 2, 2, 17, yellow)
        // backpack or jetpack
        if jetTimer > 0 {
            b.fillRect(ccx - 10, bodyTop + 2, 8, 22, RailRunner64.col(160, 168, 190))
            b.fillRect(ccx + 2, bodyTop + 2, 8, 22, RailRunner64.col(160, 168, 190))
            b.fillRect(ccx - 10, bodyTop + 2, 8, 4, RailRunner64.cRed)
            b.fillRect(ccx + 2, bodyTop + 2, 8, 4, RailRunner64.cRed)
        } else {
            b.fillRect(ccx - 8, bodyTop + 2, 16, 16, packD)
            b.fillRect(ccx - 7, bodyTop + 3, 14, 14, pack)
            b.fillRect(ccx - 5, bodyTop + 10, 10, 5, packD)
            b.fillRect(ccx - 4, bodyTop + 11, 8, 3, pack)
        }
        // arms
        let armSwing = Int(swing * 4.0)
        if armsUp {
            b.fillRect(ccx - 16, bodyTop - 10, 6, 14, outl)
            b.fillRect(ccx - 15, bodyTop - 9, 4, 12, teal)
            b.fillRect(ccx - 15, bodyTop - 13, 4, 4, skin)
            b.fillRect(ccx + 10, bodyTop - 10, 6, 14, outl)
            b.fillRect(ccx + 11, bodyTop - 9, 4, 12, teal)
            b.fillRect(ccx + 11, bodyTop - 13, 4, 4, skin)
        } else {
            b.fillRect(ccx - 16, bodyTop + 2 + armSwing, 6, 14, outl)
            b.fillRect(ccx - 15, bodyTop + 3 + armSwing, 4, 12, teal)
            b.fillRect(ccx - 15, bodyTop + 13 + armSwing, 4, 4, skin)
            b.fillRect(ccx + 10, bodyTop + 2 - armSwing, 6, 14, outl)
            b.fillRect(ccx + 11, bodyTop + 3 - armSwing, 4, 12, teal)
            b.fillRect(ccx + 11, bodyTop + 13 - armSwing, 4, 4, skin)
        }
        // head
        let headTop = bodyTop - 15
        b.fillRect(ccx - 9, headTop, 18, 16, outl)
        b.fillRect(ccx - 8, headTop + 1, 16, 14, hair)
        b.fillRect(ccx - 10, headTop + 7, 3, 5, skin)
        b.fillRect(ccx + 7, headTop + 7, 3, 5, skin)
        b.fillRect(ccx - 6, headTop + 12, 12, 3, skin)
        // beanie
        b.fillRect(ccx - 10, headTop - 7, 20, 13, outl)
        b.fillRect(ccx - 9, headTop - 6, 18, 11, beanie)
        b.fillRect(ccx - 9, headTop + 2, 18, 3, white)
        b.fillRect(ccx - 4, headTop - 12, 8, 7, outl)
        b.fillRect(ccx - 3, headTop - 11, 6, 5, yellow)
        if hurt {
            let spin: Float = Float(frame) * 0.2
            for i in 0..<3 {
                let a: Float = spin + Float(i) * 2.1
                let sx = ccx + Int(cos(a) * 20)
                let sy = headTop - 16 + Int(sin(a) * 5)
                b.fillRect(sx - 2, sy, 5, 1, yellow)
                b.fillRect(sx, sy - 2, 1, 5, yellow)
            }
        }
        if magnetTimer > 0 && (frame / 4) & 1 == 0 {
            b.fillRect(ccx - 20, bodyTop + 8, 3, 3, RailRunner64.cRed)
            b.fillRect(ccx + 18, bodyTop + 8, 3, 3, RailRunner64.cRed)
        }
        if shoeTimer > 0 && grounded {
            b.fillRect(ccx - 9, fy - 2, 18, 2, RailRunner64.cGreen)
        }
    }

    private func ur(_ b: TrueColorBuffer, _ cx: Int, _ by: Int, _ u: Float, _ xu: Float, _ yu: Float, _ wu: Float, _ hu: Float, _ c: UInt32) {
        let px = cx + Int(xu * u)
        let w = max(1, Int(wu * u))
        let h = max(1, Int(hu * u))
        let py = by - Int((yu + hu) * u)
        b.fillRect(px, py, w, h, c)
    }

    private func drawChasers(_ b: TrueColorBuffer) {
        if phase != .run && phase != .caught { return }
        var show: Float = chase
        var zcG: Float = 2.0 + (1 - chase) * 1.3
        if phase == .caught {
            show = 1
            zcG = 1.7
        }
        if show < 0.12 { return }
        let u: Float = RailRunner64.sc / zcG
        let by = Int(clamp(projY(0, zcG), 0, 420))
        let bob: Float = abs(sin(Float(frame) * 0.35)) * 0.06
        let gxw: Float = clamp(x - 0.55, -1.6, 1.6)
        let dxw: Float = clamp(x + 0.6, -1.6, 1.6)
        let gx = Int(clamp(160 + gxw * u, -100, 420))
        let dx = Int(clamp(160 + dxw * u, -100, 420))
        let navy = RailRunner64.col(34, 44, 110)
        let blue = RailRunner64.col(60, 100, 210)
        let skin = RailRunner64.col(255, 206, 170)
        let reflect = RailRunner64.col(255, 236, 80)
        let outl = RailRunner64.col(20, 20, 40)
        let sw: Float = sin(Float(frame) * 0.35)
        // guard (seen from behind)
        let gb: Float = bob
        ur(b, gx, by, u, -0.26, -0.02 + gb, 0.5, 0.52, outl)
        ur(b, gx, by, u, -0.22, 0.0 + max(0, sw) * 0.1, 0.18, 0.46, navy)
        ur(b, gx, by, u, 0.04, 0.0 + max(0, -sw) * 0.1, 0.18, 0.46, navy)
        ur(b, gx, by, u, -0.34, 0.44 + gb, 0.68, 0.5, outl)
        ur(b, gx, by, u, -0.31, 0.46 + gb, 0.62, 0.45, blue)
        ur(b, gx, by, u, -0.31, 0.62 + gb, 0.62, 0.07, reflect)
        ur(b, gx, by, u, -0.46, 0.5 + gb + sw * 0.08, 0.14, 0.38, blue)
        ur(b, gx, by, u, 0.32, 0.5 + gb - sw * 0.08, 0.14, 0.38, blue)
        ur(b, gx, by, u, -0.2, 0.92 + gb, 0.4, 0.3, skin)
        ur(b, gx, by, u, -0.26, 1.12 + gb, 0.52, 0.2, outl)
        ur(b, gx, by, u, -0.24, 1.13 + gb, 0.48, 0.16, navy)
        ur(b, gx, by, u, -0.3, 1.1 + gb, 0.6, 0.05, outl)
        // dog (seen from behind)
        let brown = RailRunner64.col(176, 110, 56)
        let brownD = RailRunner64.col(120, 70, 34)
        ur(b, dx, by, u, -0.2, 0.0, 0.1, 0.22 + max(0, sw) * 0.06, brownD)
        ur(b, dx, by, u, 0.1, 0.0, 0.1, 0.22 + max(0, -sw) * 0.06, brownD)
        ur(b, dx, by, u, -0.24, 0.2 + bob, 0.48, 0.34, outl)
        ur(b, dx, by, u, -0.21, 0.22 + bob, 0.42, 0.29, brown)
        ur(b, dx, by, u, -0.17, 0.5 + bob, 0.34, 0.26, outl)
        ur(b, dx, by, u, -0.14, 0.52 + bob, 0.28, 0.22, brown)
        ur(b, dx, by, u, -0.24, 0.5 + bob, 0.1, 0.22, brownD)
        ur(b, dx, by, u, 0.14, 0.5 + bob, 0.1, 0.22, brownD)
        let wag: Float = sin(Float(frame) * 0.6) * 0.1
        ur(b, dx, by, u, 0.0 + wag, 0.46 + bob, 0.07, 0.3, brownD)
        if phase == .caught {
            let tw = b.textWidth("GOT YOU!", scale: 2)
            otext(b, "GOT YOU!", 160 - tw / 2, 120, RailRunner64.cYellow, 2)
        }
    }

    private func drawParticles(_ b: TrueColorBuffer) {
        for pt in parts {
            let px = Int(clamp(pt.x, -50, 400))
            let py = Int(clamp(pt.y, -50, 400))
            b.fillRect(px, py, pt.size, pt.size, pt.c)
        }
        for t in texts {
            let px = Int(clamp(t.x, -50, 400))
            let py = Int(clamp(t.y, -50, 400))
            let tw = b.textWidth(t.text, scale: 1)
            otext(b, t.text, px - tw / 2, py, t.c, 1)
        }
    }

    // MARK: - HUD

    private func otext(_ b: TrueColorBuffer, _ s: String, _ px: Int, _ py: Int, _ c: UInt32, _ scale: Int) {
        let k = max(1, scale / 2)
        let o = RailRunner64.cBlack
        b.text(s, px - k, py, o, scale: scale)
        b.text(s, px + k, py, o, scale: scale)
        b.text(s, px, py - k, o, scale: scale)
        b.text(s, px, py + k, o, scale: scale)
        b.text(s, px, py, c, scale: scale)
    }

    private func ctext(_ b: TrueColorBuffer, _ s: String, _ py: Int, _ c: UInt32, _ scale: Int) {
        let tw = b.textWidth(s, scale: scale)
        otext(b, s, (b.width - tw) / 2, py, c, scale)
    }

    private func panel(_ b: TrueColorBuffer, _ px: Int, _ py: Int, _ w: Int, _ h: Int) {
        b.fillRect(px - 2, py - 2, w + 4, h + 4, RailRunner64.cBlack)
        b.fillRect(px, py, w, h, RailRunner64.cPanel)
        b.fillRect(px, py, w, 3, RailRunner64.cYellow)
        b.fillRect(px, py + h - 3, w, 3, RailRunner64.cYellow)
    }

    private func drawCoinIcon(_ b: TrueColorBuffer, _ px: Int, _ py: Int) {
        discRows(b, px + 6, py + 6, 6, RailRunner64.col(150, 80, 10))
        discRows(b, px + 6, py + 6, 5, RailRunner64.cGold)
        b.fillRect(px + 4, py + 3, 2, 6, RailRunner64.col(255, 246, 170))
    }

    private func drawStarIcon(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int, _ r: Int, _ c: UInt32) {
        if r <= 0 { return }
        for dy in -r...r {
            let m: Int = r - abs(dy)
            var half: Int = (m * m) / r
            if abs(dy) < 2 { half += 1 }
            if m > r / 2 { half += 1 }
            b.fillRect(cx - half, cy + dy, half * 2 + 1, 1, c)
        }
    }

    private func firstMission() -> Int {
        for s in 0..<3 {
            if !mDone[s] { return s }
        }
        return -1
    }

    private func drawHUD(_ b: TrueColorBuffer) {
        if phase == .title { return }
        let white = RailRunner64.cWhite
        let yellow = RailRunner64.cYellow
        drawCoinIcon(b, 6, 6)
        otext(b, zeroPad(coins, 3), 22, 5, yellow, 3)
        // stars
        for i in 0..<3 {
            drawStarIcon(b, 12 + i * 16, 36, 6, i < stars ? RailRunner64.cGold : RailRunner64.col(60, 70, 110))
        }
        // score and distance
        let sc = zeroPad(score, 6)
        let sw = b.textWidth(sc, scale: 2)
        otext(b, "SCORE", 312 - b.textWidth("SCORE", scale: 1), 5, white, 1)
        otext(b, sc, 312 - sw, 13, white, 2)
        let dm = String(Int(dist)) + " M"
        otext(b, dm, 312 - b.textWidth(dm, scale: 2), 31, RailRunner64.cCyan, 2)
        // power-up timers
        var rowY = 50
        if multTimer > 0 {
            otext(b, "2X", 8, rowY, yellow, 1)
            b.fillRect(24, rowY + 1, multTimer / 10, 4, yellow)
            rowY += 10
        }
        if magnetTimer > 0 {
            otext(b, "MAG", 8, rowY, RailRunner64.cRed, 1)
            b.fillRect(24, rowY + 1, magnetTimer / 10, 4, RailRunner64.cRed)
            rowY += 10
        }
        if shoeTimer > 0 {
            otext(b, "JMP", 8, rowY, RailRunner64.cGreen, 1)
            b.fillRect(24, rowY + 1, shoeTimer / 10, 4, RailRunner64.cGreen)
            rowY += 10
        }
        if jetTimer > 0 {
            otext(b, "JET", 8, rowY, RailRunner64.cCyan, 1)
            b.fillRect(24, rowY + 1, jetTimer / 10, 4, RailRunner64.cCyan)
            rowY += 10
        }
        // current mission
        if phase == .run {
            let m = firstMission()
            if m >= 0 {
                let id = mIds[m]
                let t = RailRunner64.missionText[id] + "  " + String(min(mProg[m], RailRunner64.missionTarget[id])) + "/" + String(RailRunner64.missionTarget[id])
                let tw = b.textWidth(t, scale: 1)
                b.fillRect(160 - tw / 2 - 4, 273, tw + 8, 11, RailRunner64.cBlack)
                b.text(t, 160 - tw / 2, 276, RailRunner64.cCyan, scale: 1)
            }
        }
        // banner and hints
        if bannerTimer > 0 && phase != .title {
            ctext(b, banner, 70, RailRunner64.cYellow, 3)
        }
        if phase == .run && hint != "" {
            ctext(b, hint, 100, white, 2)
        }
        // chase warning
        if phase == .run && chase > 0.5 && (frame / 10) & 1 == 0 {
            ctext(b, "GUARD IS CLOSE", 252, RailRunner64.cRed, 1)
        }
    }

    private func drawOverlays(_ b: TrueColorBuffer) {
        let yellow = RailRunner64.cYellow
        let white = RailRunner64.cWhite
        switch phase {
        case .title:
            panel(b, 24, 34, 272, 160)
            ctext(b, "RAIL RUNNER", 46, RailRunner64.cOrange, 5)
            ctext(b, "64", 84, yellow, 8)
            ctext(b, "RUN  JUMP  ROLL  COLLECT", 132, RailRunner64.cCyan, 1)
            if (frame / 30) & 1 == 0 { ctext(b, "PRESS A TO PLAY", 148, RailRunner64.cGreen, 3) }
            ctext(b, "LEFT RIGHT SWITCH LANE", 174, white, 1)
            ctext(b, "UP OR A JUMP   DOWN OR B ROLL", 184, white, 1)
        case .ready:
            panel(b, 30, 30, 260, 204)
            ctext(b, "MISSIONS", 40, yellow, 4)
            for s in 0..<3 {
                let py = 76 + s * 30
                b.fillRect(40, py - 2, 240, 22, RailRunner64.col(40, 50, 120))
                drawStarIcon(b, 54, py + 9, 7, RailRunner64.cGold)
                b.text(RailRunner64.missionText[mIds[s]], 70, py + 6, white, scale: 1)
            }
            ctext(b, "FINISH THEM FOR BONUS STARS", 172, RailRunner64.cCyan, 1)
            ctext(b, "AVOID TRAINS  JUMP  ROLL  GRAB COINS", 186, white, 1)
            if (frame / 30) & 1 == 0 && cdTimer > 20 { ctext(b, "PRESS A TO RUN", 206, RailRunner64.cGreen, 2) }
        case .run:
            break
        case .caught:
            break
        case .results:
            panel(b, 36, 24, 248, 240)
            ctext(b, "CAUGHT!", 34, RailRunner64.cRed, 5)
            ctext(b, "DISTANCE " + String(Int(dist)) + " M", 74, white, 2)
            ctext(b, "COINS " + String(coins), 94, yellow, 2)
            ctext(b, "SCORE " + zeroPad(score, 6), 114, white, 2)
            for i in 0..<3 {
                drawStarIcon(b, 120 + i * 40, 146, 10, i < stars ? RailRunner64.cGold : RailRunner64.col(60, 70, 110))
            }
            for s in 0..<3 {
                let t = (mDone[s] ? "DONE  " : "      ") + RailRunner64.missionText[mIds[s]]
                b.text(t, 50, 170 + s * 12, mDone[s] ? RailRunner64.cGreen : RailRunner64.col(150, 160, 200), scale: 1)
            }
            ctext(b, "BEST " + String(bestDist) + " M", 212, RailRunner64.cCyan, 1)
            if resultTimer > 40 && (frame / 30) & 1 == 0 { ctext(b, "PRESS A TO RUN AGAIN", 238, RailRunner64.cGreen, 1) }
        }
    }
}

extension Cartridge {
    static let railRunner64 = Cartridge(
        id: "railrunner64", title: "RAIL RUNNER 64", genre: "Runner",
        blurb: "Dash through a busy rail yard: swap lanes, jump onto train roofs, roll under bars, grab coins and power-ups and finish missions for stars. Do not get caught by the guard and his dog!",
        controls: "LEFT/RIGHT switch lane, UP or A jump, DOWN or B roll.",
        era: .n64, labelTop: 0x35C8C8, labelBottom: 0xE8683A, factory: { RailRunner64() })
}
