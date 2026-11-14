#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// SKY SLIDE 64: ride an inner-tube down a giant twisting water slide, get launched off the end, pop open a pair of
/// wings and glide over a floating-island world to land in a splash pool. The slide is a polar-table tunnel (per
/// pixel angle/depth tables, only the scroll and the vanishing point change each frame); the sky is a Mode-7 floor
/// with billboards. Land near the bullseye for a multiplier that carries into the next, faster slide.
final class SkySlide64: Game {
    // MARK: - Types

    private enum Phase { case title, ready, slide, fly, splash, summary, results }

    /// Slide pickups and hazards live in tube space: z along the slide, pos around the rim (0..<256).
    private struct Item {
        var kind = 0
        var z: Float = 0
        var pos: Float = 0
        var done = false
    }

    private struct Spark {
        var x: Float = 0
        var y: Float = 0
        var vx: Float = 0
        var vy: Float = 0
        var grav: Float = 0
        var life = 1
        var maxLife = 1
        var size = 2
        var col: UInt32 = 0
    }

    private struct FText {
        var x: Int = 0
        var y: Float = 0
        var life = 40
        var text = ""
        var col: UInt32 = 0
    }

    private struct Ring {
        var x: Float = 0
        var y: Float = 0
        var alt: Float = 40
        var prevZ: Float = 9999
        var done = false
        var missed = false
    }

    private struct Balloon {
        var x: Float = 0
        var y: Float = 0
        var alt: Float = 40
        var col = 0
        var popped = false
    }

    private struct Deco {
        var x: Float = 0
        var y: Float = 0
        var alt: Float = 40
        var size: Float = 20
        var kind = 0
    }

    private struct DrawItem {
        var z: Float = 0
        var kind = 0
        var idx = 0
        var sx = 0
        var sy = 0
        var sc: Float = 1
    }

    /// Per-pixel polar tables for the slide (angle 0..255, depth 0..4095) plus colour lookups.
    private final class Tables {
        static let tw = 400
        static let th = 360
        let ang: UnsafeMutablePointer<UInt8>
        let dep: UnsafeMutablePointer<UInt16>
        let fog: UnsafeMutablePointer<Int>
        let lut: UnsafeMutablePointer<UInt32>

        init() {
            let tw = Tables.tw
            let th = Tables.th
            let n = tw * th
            let a = UnsafeMutablePointer<UInt8>.allocate(capacity: n)
            let d = UnsafeMutablePointer<UInt16>.allocate(capacity: n)
            let twoPi: Float = 2 * Float.pi
            for ty in 0..<th {
                for tx in 0..<tw {
                    let dx: Float = Float(tx - 200) + 0.5
                    let dy: Float = Float(ty - 180) + 0.5
                    let r: Float = max(0.5, sqrt(dx * dx + dy * dy))
                    var an: Float = atan2(dy, dx)
                    if an < 0 { an += twoPi }
                    var ai = Int(an / twoPi * 256)
                    if ai < 0 { ai = 0 }
                    if ai > 255 { ai = 255 }
                    var di = Int(SkySlide64.depthK / r)
                    if di > 4095 { di = 4095 }
                    if di < 0 { di = 0 }
                    let idx = ty * tw + tx
                    a[idx] = UInt8(ai)
                    d[idx] = UInt16(di)
                }
            }
            let f = UnsafeMutablePointer<Int>.allocate(capacity: 128)
            for i in 0..<128 {
                var t: Float = (Float(i * 32) - 300) / 2600
                if t < 0 { t = 0 }
                if t > 1 { t = 1 }
                f[i] = Int(t * 15)
            }
            let l = UnsafeMutablePointer<UInt32>.allocate(capacity: 1024)
            for pan in 0..<32 {
                for band in 0..<2 {
                    var r = 70
                    var g = 150
                    var bl = 255
                    if pan >= 6 && pan <= 9 {
                        r = 60; g = 205; bl = 255
                        if band == 1 { r = 150; g = 240; bl = 255 }
                    } else if pan >= 22 && pan <= 25 {
                        r = 255; g = 246; bl = 190
                        if band == 1 { r = 255; g = 255; bl = 240 }
                    } else if pan % 8 == 0 {
                        r = 255; g = 214; bl = 60
                        if band == 1 { r = 255; g = 240; bl = 130 }
                    } else if (pan / 2) % 2 == 0 {
                        r = 64; g = 140; bl = 250
                        if band == 1 { r = 110; g = 185; bl = 255 }
                    } else {
                        r = 255; g = 96; bl = 184
                        if band == 1 { r = 255; g = 150; bl = 220 }
                    }
                    for lv in 0..<16 {
                        l[(pan * 2 + band) * 16 + lv] = Tables.fogged(r, g, bl, lv)
                    }
                }
            }
            self.ang = a
            self.dep = d
            self.fog = f
            self.lut = l
        }

        static func fogged(_ r: Int, _ g: Int, _ b: Int, _ lv: Int) -> UInt32 {
            let t: Float = Float(lv) / 15
            let fr: Float = Float(r) + Float(215 - r) * t
            let fg: Float = Float(g) + Float(240 - g) * t
            let fb: Float = Float(b) + Float(255 - b) * t
            return TrueColorBuffer.rgb(Int(fr), Int(fg), Int(fb))
        }
    }

    // MARK: - Constants

    private static let depthK: Float = 14000
    private static let shipDepth: Float = 120
    private static let focal: Float = 200
    private static let poolR: Float = 46

    private static let kStar = 0
    private static let kGem = 1
    private static let kPad = 2
    private static let kBump = 3
    private static let kHop = 4

    private static let cWhite: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    private static let cBlack: UInt32 = TrueColorBuffer.rgb(10, 14, 40)
    private static let cYellow: UInt32 = TrueColorBuffer.rgb(255, 232, 70)
    private static let cRed: UInt32 = TrueColorBuffer.rgb(255, 80, 90)
    private static let cGreen: UInt32 = TrueColorBuffer.rgb(110, 255, 140)
    private static let cCyan: UInt32 = TrueColorBuffer.rgb(100, 235, 255)
    private static let cPink: UInt32 = TrueColorBuffer.rgb(255, 110, 200)
    private static let cOrange: UInt32 = TrueColorBuffer.rgb(255, 160, 40)
    private static let cPanel: UInt32 = TrueColorBuffer.rgb(20, 40, 110)
    private static let cSkin: UInt32 = TrueColorBuffer.rgb(255, 214, 172)

    private static let tables = Tables()

    private static let tune = Tune(bpm: 150, wave: .pulse50, volume: 0.12,
        "C5:0.5 E5:0.5 G5:0.5 C6:0.5 G5:0.5 E5:0.5 G5:0.5 E5:0.5 F5:0.5 A5:0.5 C6:0.5 A5:0.5 F5:0.5 A5:0.5 G5:1 D5:0.5 G5:0.5 B5:0.5 G5:0.5 D5:0.5 G5:0.5 B5:0.5 D6:0.5 C6:1 G5:0.5 E5:0.5 C5:1 R:1")

    /// Colour ids in the ground texture.
    private static let groundPal: [Int] = [
        84, 176, 255, 130, 210, 255, 250, 252, 255, 255, 230, 150,
        120, 225, 80, 70, 190, 70, 255, 130, 180, 255, 255, 255
    ]

    private static let groundLut: [UInt32] = {
        var out = [UInt32](repeating: 0, count: 16 * 8)
        for fl in 0..<16 {
            let t: Float = Float(fl) / 15
            for c in 0..<8 {
                let r: Float = Float(SkySlide64.groundPal[c * 3])
                let g: Float = Float(SkySlide64.groundPal[c * 3 + 1])
                let bl: Float = Float(SkySlide64.groundPal[c * 3 + 2])
                let fr: Float = r + (200 - r) * t
                let fg: Float = g + (236 - g) * t
                let fb: Float = bl + (255 - bl) * t
                out[fl * 8 + c] = TrueColorBuffer.rgb(Int(fr), Int(fg), Int(fb))
            }
        }
        return out
    }()

    private static let groundTex: [UInt8] = {
        var out = [UInt8](repeating: 0, count: 65536)
        let k: Float = 2 * Float.pi / 256
        for y in 0..<256 {
            for x in 0..<256 {
                let fx: Float = Float(x)
                let fy: Float = Float(y)
                let t1: Float = sin(fx * 3 * k + 1.3) * cos(fy * 2 * k)
                let t2: Float = 0.6 * sin((fx * 5 + fy * 4) * k + 0.5)
                let t3: Float = 0.5 * cos((fy * 7 - fx * 3) * k)
                let v: Float = t1 + t2 + t3
                var c = 0
                if v > 1.7 {
                    c = 5
                } else if v > 1.25 {
                    c = 4
                } else if v > 1.0 {
                    c = 3
                } else if v < -1.0 {
                    c = 2
                } else if v < -0.4 {
                    c = 1
                }
                if (c == 4 || c == 5) && ((x * 7 + y * 13) % 37) == 0 {
                    c = 6
                }
                out[y * 256 + x] = UInt8(c)
            }
        }
        return out
    }()

    private static let skyLut: [UInt32] = {
        var out = [UInt32](repeating: 0, count: 64)
        for i in 0..<64 {
            let t: Float = Float(i) / 63
            let r: Float = 40 + (205 - 40) * t
            let g: Float = 120 + (236 - 120) * t
            let bl: Float = 255
            out[i] = TrueColorBuffer.rgb(Int(r), Int(g), Int(bl))
        }
        return out
    }()

    private static let hazeCol: UInt32 = TrueColorBuffer.rgb(200, 236, 255)
    private static let balloonCols: [UInt32] = [
        TrueColorBuffer.rgb(255, 80, 90), TrueColorBuffer.rgb(255, 210, 50),
        TrueColorBuffer.rgb(90, 230, 120), TrueColorBuffer.rgb(255, 110, 210),
        TrueColorBuffer.rgb(255, 150, 40)
    ]
    private static let rainbow: [UInt32] = [
        TrueColorBuffer.rgb(255, 70, 70), TrueColorBuffer.rgb(255, 150, 40),
        TrueColorBuffer.rgb(255, 235, 70), TrueColorBuffer.rgb(90, 220, 90),
        TrueColorBuffer.rgb(70, 160, 255), TrueColorBuffer.rgb(150, 100, 240)
    ]

    // MARK: - State

    private var phase: Phase = .title
    private var tick = 0
    private var rng = Rng()

    private var round = 1
    private var totalScore = 0
    private var totalStars = 0
    private var roundStars = 0
    private var carryMult = 10
    private var shake = 0
    private var flashT = 0
    private var phaseT = 0
    private var bannerT = 0
    private var bannerText = ""
    private var hintT = 0

    // slide
    private var travel: Float = 0
    private var slideLen: Float = 6500
    private var speed: Float = 8
    private var pos: Float = 64
    private var steerV: Float = 0
    private var meter: Float = 40
    private var boosting = false
    private var padT = 0
    private var slowT = 0
    private var jumpT = 0
    private var combo = 0
    private var bestCombo = 0
    private var nextChunkZ: Float = 500
    private var swayX = 0
    private var swayY = 0
    private var curveT: Float = 0
    private var pickupsGot = 0
    private var pickupsTotal = 0
    private var items: [Item] = []
    private var slidePts = 0

    // fly
    private var fx: Float = 20000
    private var fy: Float = 20000
    private var alt: Float = 90
    private var psi: Float = 0
    private var fSpeed: Float = 3.4
    private var vy: Float = 0
    private var pitch: Float = 0
    private var bank: Float = 0
    private var stamina: Float = 100
    private var flapT = 0
    private var diveOn = false
    private var poolX: Float = 0
    private var poolY: Float = 0
    private var rings: [Ring] = []
    private var balloons: [Balloon] = []
    private var decos: [Deco] = []
    private var ringsGot = 0
    private var balloonsGot = 0
    private var landMult = 10
    private var landDist: Float = 0
    private var flyT = 0
    private var camX: Float = 0
    private var camY: Float = 0
    private var camH: Float = 30
    private var hzCur = 112

    private var sparks: [Spark] = []
    private var texts: [FText] = []
    private var drawList: [DrawItem] = []
    private var streakAng = [Float](repeating: 0, count: 28)
    private var streakPh = [Float](repeating: 0, count: 28)
    private var bestRoundScore = 0

    override var score: Int { return totalScore }

    override init() {
        super.init()
        _ = SkySlide64.tables
        _ = SkySlide64.groundTex
        for i in 0..<28 {
            streakAng[i] = Float(rng.int(628)) / 100
            streakPh[i] = Float(rng.int(100)) / 100
        }
        resetAll()
    }

    override func start() {
        playMusic(SkySlide64.tune)
    }

    // MARK: - Setup

    private func resetAll() {
        phase = .title
        tick = 0
        round = 1
        totalScore = 0
        totalStars = 0
        roundStars = 0
        carryMult = 10
        shake = 0
        flashT = 0
        phaseT = 0
        bannerT = 0
        bannerText = ""
        hintT = 0
        bestRoundScore = 0
        sparks.removeAll()
        texts.removeAll()
        prepareSlide()
    }

    private func prepareSlide() {
        travel = 0
        let rr: Float = Float(min(round, 9))
        slideLen = 6500 + rr * 650
        speed = 8
        pos = 64
        steerV = 0
        meter = 40
        boosting = false
        padT = 0
        slowT = 0
        jumpT = 0
        combo = 0
        bestCombo = 0
        nextChunkZ = 500
        swayX = 0
        swayY = 0
        curveT = Float(rng.int(600)) / 100
        pickupsGot = 0
        pickupsTotal = 0
        slidePts = 0
        items.removeAll()
        sparks.removeAll()
        texts.removeAll()
        while nextChunkZ < 2800 {
            spawnChunk()
        }
    }

    private func beginRound() {
        prepareSlide()
        phase = .ready
        phaseT = 190
        hintT = 0
        playMusic(SkySlide64.tune)
    }

    // MARK: - Helpers

    private func angDiff(_ a: Float, _ b: Float) -> Float {
        let d: Float = a - b
        return d - 256 * floor((d + 128) / 256)
    }

    private func wrapPos(_ v: Float) -> Float {
        if !v.isFinite { return 64 }
        return v - 256 * floor(v / 256)
    }

    private func fmtMult(_ m: Int) -> String {
        return "X" + String(m / 10) + "." + String(m % 10)
    }

    private func difficulty() -> Float {
        let r: Float = Float(min(round, 8) - 1)
        return min(1, r / 6)
    }

    private func addText(_ s: String, _ x: Int, _ y: Float, _ c: UInt32) {
        var t = FText()
        t.x = x
        t.y = y
        t.text = s
        t.col = c
        t.life = 46
        texts.append(t)
        if texts.count > 14 { texts.removeFirst() }
    }

    private func addSpark(_ x: Float, _ y: Float, _ vx: Float, _ vy: Float, _ grav: Float, _ life: Int, _ size: Int, _ c: UInt32) {
        if sparks.count > 220 { return }
        var s = Spark()
        s.x = x
        s.y = y
        s.vx = vx
        s.vy = vy
        s.grav = grav
        s.life = life
        s.maxLife = life
        s.size = size
        s.col = c
        sparks.append(s)
    }

    private func burst(_ x: Float, _ y: Float, _ n: Int, _ c: UInt32, _ power: Float) {
        for _ in 0..<n {
            let a: Float = Float(rng.int(628)) / 100
            let sp: Float = (0.4 + Float(rng.int(100)) / 100) * power
            addSpark(x, y, cos(a) * sp, sin(a) * sp, 0.1, 18 + rng.int(14), 2 + rng.int(2), c)
        }
    }

    private func award(_ pts: Int, _ x: Int, _ y: Float) {
        let gain: Int = pts * carryMult / 10
        totalScore += gain
        slidePts += gain
        addText("+" + String(gain), x, y, SkySlide64.cYellow)
    }

    // MARK: - Slide spawning

    private func addItem(_ kind: Int, _ z: Float, _ p: Float) {
        var it = Item()
        it.kind = kind
        it.z = z
        it.pos = wrapPos(p)
        items.append(it)
        if kind == SkySlide64.kStar || kind == SkySlide64.kGem { pickupsTotal += 1 }
    }

    private func spawnChunk() {
        let z: Float = nextChunkZ
        let diff: Float = difficulty()
        let k: Int = rng.int(100)
        let p0: Float = Float(rng.int(256))
        let bumpOdds: Int = round <= 1 ? 62 : 70
        if k < 28 {
            for i in 0..<6 {
                addItem(SkySlide64.kStar, z + Float(i) * 58, p0 + Float(i) * 9)
            }
        } else if k < 42 {
            for i in 0..<4 {
                addItem(SkySlide64.kStar, z + Float(i) * 60, p0)
            }
            addItem(SkySlide64.kGem, z + 250, p0)
        } else if k < 56 {
            addItem(SkySlide64.kPad, z, p0)
            for i in 0..<4 {
                addItem(SkySlide64.kStar, z + 130 + Float(i) * 70, p0 + Float(i) * 4)
            }
        } else if k < bumpOdds {
            addItem(SkySlide64.kHop, z, p0)
            for i in 0..<4 {
                addItem(SkySlide64.kGem, z + 90 + Float(i) * 45, p0 + Float(i) * 6)
            }
        } else {
            var nb = 1
            if diff > 0.35 { nb += 1 }
            if diff > 0.7 { nb += 1 }
            for i in 0..<nb {
                addItem(SkySlide64.kBump, z, p0 + Float(i) * 64)
            }
            let gap: Float = p0 + 32
            addItem(SkySlide64.kStar, z + 20, gap)
            addItem(SkySlide64.kStar, z + 80, gap)
            addItem(SkySlide64.kGem, z + 140, gap)
        }
        items.sort { $0.z < $1.z }
        nextChunkZ += 340 - diff * 70
    }

    // MARK: - Update

    override func update(_ inputRaw: InputState) {
        var input = inputRaw
        readPointer(&input)
        tick += 1
        if shake > 0 { shake -= 1 }
        if flashT > 0 { flashT -= 1 }
        if bannerT > 0 { bannerT -= 1 }
        updateSparks()
        for i in 0..<texts.count {
            texts[i].life -= 1
            texts[i].y -= 0.8
        }
        texts.removeAll { $0.life <= 0 }

        switch phase {
        case .title:
            travel += 5
            curveT += 0.01
            updateSway()
            if input.aPressed || input.startPressed {
                play(.confirm)
                beginRound()
            }
        case .ready:
            curveT += 0.01
            updateSway()
            phaseT -= 1
            if phaseT > 0 && phaseT % 60 == 0 { play(.countdown) }
            if phaseT <= 0 {
                phase = .slide
                phaseT = 0
                bannerText = "GO!"
                bannerT = 40
                play(.powerup)
                hintT = 280
            }
            let dx: Float = slideAxis(input)
            steerV += (dx * 2.6 - steerV) * 0.25
            pos = wrapPos(pos + steerV)
        case .slide:
            updateSlide(input)
        case .fly:
            updateFly(input)
        case .splash:
            phaseT -= 1
            if phaseT <= 0 {
                finishRound()
            }
        case .summary:
            phaseT += 1
            if phaseT > 40 && input.aPressed {
                round += 1
                play(.confirm)
                beginRound()
            } else if phaseT > 40 && round > 5 && input.startPressed {
                phase = .results
                phaseT = 0
                play(.win)
            }
        case .results:
            phaseT += 1
            if phaseT > 60 && input.startPressed {
                resetAll()
                play(.select)
            } else if phaseT > 60 && input.aPressed && round == 5 {
                round += 1
                play(.confirm)
                beginRound()
            } else if phaseT > 60 && input.aPressed {
                resetAll()
                play(.select)
            }
        }
    }


    // MARK: - Pointer (touch) input

    override var wantsPointer: Bool { return true }

    private var ptDown = false
    private var ptX = 160
    private var ptY = 144
    private var ptTap = false
    private var ptT = 0
    private var ptSX = 0
    private var ptSY = 0
    private var ptPressed = false
    private var tapBoostT = 0
    private var ptIgnore = false

    private func readPointer(_ input: inout InputState) {
        let p: PointerState = input.pointer
        ptTap = false
        ptPressed = p.pressed
        ptDown = p.down && !ptIgnore
        if p.x >= 0 && p.y >= 0 {
            ptX = max(0, min(319, p.x))
            ptY = max(0, min(287, p.y))
        }
        if p.pressed {
            ptT = 0
            ptSX = ptX
            ptSY = ptY
            ptIgnore = false
        }
        if p.down { ptT += 1 }
        if p.released {
            let moved: Int = abs(ptX - ptSX) + abs(ptY - ptSY)
            if ptT <= 16 && moved < 24 { ptTap = true }
            ptIgnore = false
        }
        if !p.down { ptDown = false }
        if tapBoostT > 0 { tapBoostT -= 1 }
        if p.pressed {
            if phase == .title || phase == .summary || phase == .results {
                if phase == .summary && round > 5 && ptY < 24 {
                    input.pressed.insert(.start)
                } else {
                    input.pressed.insert(.a)
                }
            }
        }
        if ptTap && phase == .slide { tapBoostT = 50 }
    }

    private func slideAxis(_ inp: InputState) -> Float {
        if !ptDown { return Float(inp.dx) }
        var fxp: Float = Float(ptX - 160)
        let fyp: Float = Float(ptY - 144)
        if abs(fxp) < 14 && abs(fyp) < 14 { fxp = 0 }
        if fxp == 0 && abs(fyp) < 14 { return Float(inp.dx) }
        let target: Float = wrapPos(atan2(fyp, fxp) / (2 * Float.pi) * 256)
        let diff: Float = angDiff(target, pos)
        if abs(diff) < 3 { return 0 }
        return max(-1, min(1, diff / 18))
    }

    private func updateSway() {
        curveT += 0.006
        let sx: Float = sin(curveT * 1.3) * 30 + sin(curveT * 0.37 + 1) * 8
        let sy: Float = cos(curveT * 0.9) * 22
        swayX = Int(max(-34, min(34, sx)))
        swayY = Int(max(-26, min(26, sy)))
    }

    private func updateSparks() {
        for i in 0..<sparks.count {
            sparks[i].x += sparks[i].vx
            sparks[i].y += sparks[i].vy
            sparks[i].vy += sparks[i].grav
            sparks[i].life -= 1
        }
        sparks.removeAll { $0.life <= 0 }
    }

    private func updateSlide(_ inp: InputState) {
        phaseT += 1
        let rr: Float = Float(min(round, 8))
        let dx: Float = slideAxis(inp)
        steerV += (dx * 2.7 - steerV) * 0.25
        pos = wrapPos(pos + steerV)

        // assists: magnet toward the next pickup, nudge away from the next bump when not steering
        if dx == 0 && !ptDown {
            var assist: Float = 0.05
            if round <= 2 { assist = 0.08 }
            for it in items {
                let rel: Float = it.z - travel
                if rel < 40 || rel > 650 { continue }
                let d: Float = angDiff(it.pos, pos)
                if it.kind == SkySlide64.kStar || it.kind == SkySlide64.kGem {
                    if abs(d) < 34 { pos = wrapPos(pos + d * assist) }
                    break
                } else if it.kind == SkySlide64.kBump && abs(d) < 18 && rel < 380 {
                    let away: Float = d >= 0 ? -1.0 : 1.0
                    pos = wrapPos(pos + away * 1.1)
                    break
                }
            }
        }

        // speed
        let carryBonus: Float = Float(carryMult - 10) / 10 * 0.9
        let baseSpeed: Float = 8 + rr * 0.55
        var target: Float = baseSpeed + carryBonus
        if (inp.a || tapBoostT > 0) && meter > 1 {
            boosting = true
            meter -= 0.55
            target += 5
        } else {
            boosting = false
        }
        if padT > 0 {
            padT -= 1
            target += 4.5
        }
        if slowT > 0 {
            slowT -= 1
            target *= 0.6
        }
        speed += (target - speed) * 0.08
        travel += speed
        meter = min(100, meter + 0.05)
        if jumpT > 0 { jumpT -= 1 }
        updateSway()

        // items
        let jumpH: Float = jumpHeight()
        for i in 0..<items.count {
            if items[i].done { continue }
            let rel: Float = items[i].z - travel
            if rel > 0 { continue }
            items[i].done = true
            let ad: Float = abs(angDiff(items[i].pos, pos))
            let k: Int = items[i].kind
            let sp: Float = shipScreenRadius()
            let ang: Float = pos / 256 * 2 * Float.pi
            let scx: Int = 160 + swayX + Int(cos(ang) * sp)
            let scy: Int = 144 + swayY + Int(sin(ang) * sp)
            if k == SkySlide64.kStar {
                if ad < 16 {
                    combo += 1
                    pickupsGot += 1
                    award(10 + min(combo, 20), scx, Float(scy))
                    burst(Float(scx), Float(scy), 8, SkySlide64.cYellow, 2.5)
                    play(.coin)
                } else {
                    combo = 0
                }
            } else if k == SkySlide64.kGem {
                if ad < 16 {
                    combo += 1
                    pickupsGot += 1
                    meter = min(100, meter + 14)
                    award(50 + min(combo, 20), scx, Float(scy))
                    burst(Float(scx), Float(scy), 12, SkySlide64.cPink, 3)
                    play(.pickup)
                } else {
                    combo = 0
                }
            } else if k == SkySlide64.kPad {
                if ad < 18 {
                    padT = 55
                    speed += 3
                    flashT = 6
                    bannerText = "BOOST!"
                    bannerT = 30
                    play(.powerup)
                    burst(Float(scx), Float(scy), 10, SkySlide64.cOrange, 3)
                }
            } else if k == SkySlide64.kBump {
                if ad < 12 && jumpH < 0.3 {
                    slowT = 32
                    speed *= 0.55
                    combo = 0
                    shake = 14
                    flashT = 4
                    meter = max(0, meter - 8)
                    play(.hit)
                    addText("BONK!", scx, Float(scy), SkySlide64.cRed)
                    burst(Float(scx), Float(scy), 14, SkySlide64.cCyan, 3.5)
                }
            } else if k == SkySlide64.kHop {
                if ad < 16 {
                    jumpT = 40
                    play(.jump)
                    addText("HOP!", scx, Float(scy), SkySlide64.cGreen)
                }
            }
        }
        items.removeAll { $0.z - travel < -100 }
        while nextChunkZ < travel + 2800 && nextChunkZ < slideLen - 500 {
            spawnChunk()
        }

        // combo milestones
        if combo > bestCombo { bestCombo = combo }
        if combo > 0 && combo % 10 == 0 && bannerT < 10 {
            bannerText = "COMBO " + String(combo) + "!"
            bannerT = 30
        }

        // water spray from the tube
        if tick % 2 == 0 {
            let sp: Float = shipScreenRadius()
            let ang: Float = pos / 256 * 2 * Float.pi
            let sx: Float = Float(160 + swayX) + cos(ang) * sp
            let sy: Float = Float(144 + swayY) + sin(ang) * sp
            let inwardX: Float = -cos(ang)
            let inwardY: Float = -sin(ang)
            let rx: Float = Float(rng.int(100) - 50) / 40
            let ry: Float = Float(rng.int(100) - 50) / 40
            addSpark(sx, sy, inwardX * 2 + rx, inwardY * 2 + ry, 0.05, 16, 2, SkySlide64.cCyan)
        }

        if hintT > 0 { hintT -= 1 }
        if travel >= slideLen {
            startFly()
        }
    }

    private func jumpHeight() -> Float {
        if jumpT <= 0 { return 0 }
        return sin(Float.pi * Float(jumpT) / 40)
    }

    private func shipScreenRadius() -> Float {
        let base: Float = SkySlide64.depthK / SkySlide64.shipDepth * 0.9
        return base * (1 - jumpHeight() * 0.35)
    }

    // MARK: - Fly

    private func startFly() {
        phase = .fly
        flyT = 0
        flashT = 24
        shake = 10
        bannerText = "WINGS OUT!"
        bannerT = 70
        play(.powerup)
        sparks.removeAll()
        texts.removeAll()
        fx = 20000 + Float(rng.int(2000))
        fy = 20000 + Float(rng.int(2000))
        psi = 0
        let spBonus: Float = min(speed, 18) - 8
        let spUp: Float = max(0, spBonus)
        let altBase: Float = 84 + spUp * 2.4
        alt = altBase + meter * 0.1
        fSpeed = 3.4 + max(0, spBonus) * 0.06
        vy = 2.4
        pitch = 0.3
        bank = 0
        stamina = 100
        flapT = 0
        diveOn = false
        ringsGot = 0
        balloonsGot = 0
        rings.removeAll()
        balloons.removeAll()
        decos.removeAll()
        let rr: Int = min(round, 8)
        let dist: Float = 800 + Float(rr) * 35
        var lat: Float = Float(rng.range(-200, 200))
        if round == 1 { lat = Float(rng.range(-90, 90)) }
        poolX = fx + dist
        poolY = fy + lat
        let nr: Int = 5 + min(rr, 6) / 2
        for i in 0..<nr {
            let t: Float = 0.16 + 0.68 * Float(i) / Float(max(1, nr - 1))
            var r = Ring()
            let weave: Float = sin(Float(i) * 1.7 + Float(rr)) * 60 * (1 - t)
            r.x = fx + dist * t
            r.y = fy + lat * t + weave
            let pathAlt: Float = alt * (1 - t) * 0.9 + 16
            r.alt = max(22, pathAlt + Float(rng.range(-8, 8)))
            rings.append(r)
        }
        let nb: Int = 9 + min(rr, 6)
        for _ in 0..<nb {
            let t: Float = 0.1 + Float(rng.int(80)) / 100
            var bl = Balloon()
            bl.x = fx + dist * t
            bl.y = fy + lat * t + Float(rng.range(-110, 110))
            let pathAlt: Float = alt * (1 - t) * 0.9 + 16
            bl.alt = max(14, pathAlt + Float(rng.range(-25, 25)))
            bl.col = rng.int(5)
            balloons.append(bl)
        }
        for _ in 0..<16 {
            var d = Deco()
            d.x = fx - 200 + Float(rng.int(1700))
            d.y = fy - 650 + Float(rng.int(1300))
            d.alt = 40 + Float(rng.int(110))
            d.size = 16 + Float(rng.int(26))
            d.kind = 0
            decos.append(d)
        }
        for i in 0..<6 {
            var d = Deco()
            d.x = fx + 150 + Float(i) * 220 + Float(rng.int(80))
            let side: Float = (i % 2 == 0) ? 1 : -1
            d.y = fy + side * Float(190 + rng.int(220))
            d.alt = 35 + Float(rng.int(70))
            d.size = 34 + Float(rng.int(20))
            d.kind = 1
            decos.append(d)
        }
        hintT = 330
    }

    private func updateFly(_ inp: InputState) {
        flyT += 1
        if hintT > 0 { hintT -= 1 }
        if flyT > 1800 { alt -= 0.5 }

        // steering with a gentle auto-steer toward the pool when the D-pad is idle
        let fwdX: Float = cos(psi)
        let fwdY: Float = sin(psi)
        var axisX: Float = Float(inp.dx)
        var axisY: Float = Float(inp.dy) * -1.0
        var touchDive = false
        if ptDown {
            axisX = max(-1, min(1, Float(ptX - 160) / 70))
            axisY = max(-1, min(1, Float(144 - ptY) / 80))
            if ptY > 192 { touchDive = true }
            if abs(axisX) < 0.12 { axisX = 0 }
        }
        var turn: Float = axisX * 0.024
        if axisX == 0 && !ptDown {
            let bearing: Float = atan2(poolY - fy, poolX - fx)
            var diff: Float = bearing - psi
            diff = diff - 2 * Float.pi * floor((diff + Float.pi) / (2 * Float.pi))
            turn = max(-0.012, min(0.012, diff * 0.05))
        }
        psi += turn
        let targetBank: Float = axisX
        bank += (targetBank - bank) * 0.12

        // pitch
        let tp: Float = axisY
        pitch += (tp - pitch) * 0.14
        diveOn = inp.b || touchDive
        var dAlt: Float = -0.3
        var spMul: Float = 1
        if pitch >= 0 {
            dAlt += 0.2 * pitch
            spMul = 1 - 0.22 * pitch
        } else {
            dAlt += 0.6 * pitch
            spMul = 1 - 0.5 * pitch
        }
        if diveOn {
            dAlt -= 0.55
            spMul += 0.35
        }
        if (inp.aPressed || ptTap) && stamina >= 22 {
            stamina -= 22
            vy += 2.0
            flapT = 18
            play(.jump)
            burst(160, 230, 6, SkySlide64.cWhite, 2)
        }
        if flapT > 0 { flapT -= 1 }
        stamina = min(100, stamina + 0.22)
        vy *= 0.94
        alt += dAlt + vy * 0.5
        if alt > 200 { alt = 200; vy = 0 }
        let sp: Float = fSpeed * spMul
        let prevX: Float = fx
        let prevY: Float = fy
        fx += fwdX * sp
        fy += fwdY * sp
        if !fx.isFinite || !fy.isFinite || !alt.isFinite {
            fx = prevX
            fy = prevY
            alt = 50
        }

        // rings
        let rightX: Float = -sin(psi)
        let rightY: Float = cos(psi)
        for i in 0..<rings.count {
            if rings[i].done { continue }
            let rx: Float = rings[i].x - fx
            let ry: Float = rings[i].y - fy
            let zf: Float = rx * fwdX + ry * fwdY
            if rings[i].prevZ > 0 && zf <= 0 && !rings[i].missed {
                let lat: Float = rx * rightX + ry * rightY
                let da: Float = rings[i].alt - alt
                let d: Float = sqrt(lat * lat + da * da)
                if d < 26 {
                    rings[i].done = true
                    ringsGot += 1
                    totalScore += 100
                    stamina = min(100, stamina + 25)
                    addText("+100", 160, 120, SkySlide64.cYellow)
                    burst(160, 130, 16, SkySlide64.cYellow, 3.5)
                    flashT = 4
                    play(.coin)
                    alt += 3
                } else {
                    rings[i].missed = true
                }
            }
            rings[i].prevZ = zf
        }
        // balloons
        for i in 0..<balloons.count {
            if balloons[i].popped { continue }
            let rx: Float = balloons[i].x - fx
            let ry: Float = balloons[i].y - fy
            let da: Float = balloons[i].alt - alt
            let d: Float = sqrt(rx * rx + ry * ry + da * da)
            if d < 21 {
                balloons[i].popped = true
                balloonsGot += 1
                totalScore += 50
                addText("+50", 160, 150, SkySlide64.cPink)
                burst(160, 160, 14, SkySlide64.balloonCols[balloons[i].col % 5], 3)
                play(.pickup)
            }
        }

        // landing
        if alt <= 1.5 {
            alt = 0
            landDist = sqrt((poolX - fx) * (poolX - fx) + (poolY - fy) * (poolY - fy))
            let rel: Float = landDist
            if rel < 8 {
                landMult = 40
            } else if rel < 18 {
                landMult = 30
            } else if rel < 30 {
                landMult = 20
            } else if rel < SkySlide64.poolR {
                landMult = 15
            } else {
                landMult = 10
            }
            let pts: Int = 200 * landMult / 10
            totalScore += pts
            phase = .splash
            phaseT = 130
            shake = 16
            flashT = 8
            if landMult >= 30 {
                bannerText = "BULLSEYE!"
                play(.win)
            } else if landMult >= 15 {
                bannerText = "SPLASH! " + fmtMult(landMult)
                play(.confirm)
            } else {
                bannerText = "BELLY FLOP!"
                play(.drop)
            }
            bannerT = 120
            carryMult = landMult
            for _ in 0..<60 {
                let a: Float = -Float.pi * Float(rng.int(100)) / 100
                let spd: Float = 1.5 + Float(rng.int(30)) / 10
                let cols: [UInt32] = [SkySlide64.cWhite, SkySlide64.cCyan, SkySlide64.cWhite]
                addSpark(160, 232, cos(a) * spd * 1.6, sin(a) * spd * 2.4, 0.14, 40 + rng.int(25), 3, cols[rng.int(3)])
            }
        }
        // wind streaks
        if tick % 3 == 0 {
            let sx: Float = Float(rng.int(320))
            addSpark(sx, 60 + Float(rng.int(200)), 0, 6 + sp, 0, 8, 2, SkySlide64.cWhite)
        }
    }

    private func finishRound() {
        var stars = 0
        if landMult > 10 { stars += 1 }
        if pickupsTotal > 0 && pickupsGot * 100 >= pickupsTotal * 60 { stars += 1 }
        if !rings.isEmpty && ringsGot * 100 >= rings.count * 60 { stars += 1 }
        roundStars = stars
        totalStars += stars
        phase = .summary
        phaseT = 0
        if stars == 3 {
            play(.win)
        } else {
            play(.confirm)
        }
        if slidePts > bestRoundScore { bestRoundScore = slidePts }
        if round == 5 {
            phase = .results
            phaseT = 0
        }
    }

    // MARK: - Drawing helpers

    private func disc(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int, _ r: Int, _ c: UInt32) {
        if r <= 0 {
            b.fillRect(cx, cy, 1, 1, c)
            return
        }
        if cx + r < 0 || cx - r >= 320 || cy + r < 0 || cy - r >= 288 { return }
        let rr: Int = min(r, 400)
        let y0: Int = max(-rr, -cy)
        let y1: Int = min(rr, 287 - cy)
        if y0 > y1 { return }
        for dy in y0...y1 {
            let hw: Int = Int(sqrt(Float(rr * rr - dy * dy)) + 0.5)
            b.fillRect(cx - hw, cy + dy, hw * 2 + 1, 1, c)
        }
    }

    private func ell(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int, _ rx: Int, _ ry: Int, _ c: UInt32) {
        if rx <= 0 { return }
        if ry <= 0 {
            b.fillRect(cx - rx, cy, rx * 2 + 1, 1, c)
            return
        }
        if cx + rx < 0 || cx - rx >= 320 || cy + ry < 0 || cy - ry >= 288 { return }
        let ryc: Int = min(ry, 400)
        let y0: Int = max(-ryc, -cy)
        let y1: Int = min(ryc, 287 - cy)
        if y0 > y1 { return }
        for dy in y0...y1 {
            let t: Float = Float(dy) / Float(ryc)
            let q: Float = max(0, 1 - t * t)
            let hw: Int = Int(Float(min(rx, 600)) * sqrt(q) + 0.5)
            b.fillRect(cx - hw, cy + dy, hw * 2 + 1, 1, c)
        }
    }

    /// Ring outline; rows at or below `clipY` are skipped.
    private func ringO(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int, _ r: Int, _ th: Int, _ c: UInt32, _ clipY: Int) {
        if r <= 0 { return }
        if cx + r < 0 || cx - r >= 320 || cy + r < 0 || cy - r >= 288 { return }
        let rr: Int = min(r, 400)
        let inner: Int = max(0, rr - th)
        let y0: Int = max(-rr, -cy)
        let y1: Int = min(rr, 287 - cy)
        if y0 > y1 { return }
        for dy in y0...y1 {
            let y: Int = cy + dy
            if y >= clipY { continue }
            let ho: Int = Int(sqrt(Float(rr * rr - dy * dy)) + 0.5)
            if abs(dy) < inner {
                let hi: Int = Int(sqrt(Float(inner * inner - dy * dy)) + 0.5)
                b.fillRect(cx - ho, y, max(1, ho - hi), 1, c)
                b.fillRect(cx + hi, y, max(1, ho - hi), 1, c)
            } else {
                b.fillRect(cx - ho, y, ho * 2 + 1, 1, c)
            }
        }
    }

    /// Pointy four-sided sparkle (stars) or diamond (gems, `fat` = 0).
    private func sparkle(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int, _ r: Int, _ c: UInt32, _ diamond: Bool) {
        if r <= 0 { return }
        if cx + r < 0 || cx - r >= 320 || cy + r < 0 || cy - r >= 288 { return }
        let rr: Int = min(r, 300)
        for dy in -rr...rr {
            let t: Float = Float(abs(dy)) / Float(rr)
            var hwf: Float = Float(rr) * (1 - t)
            if !diamond { hwf = hwf * (1 - t * 0.55) }
            let hw: Int = Int(hwf + 0.5)
            b.fillRect(cx - hw, cy + dy, hw * 2 + 1, 1, c)
        }
    }

    private func shadowText(_ b: TrueColorBuffer, _ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        b.text(s, x + scale, y + scale, SkySlide64.cBlack, scale: scale)
        b.text(s, x, y, c, scale: scale)
    }

    private func ctext(_ b: TrueColorBuffer, _ s: String, _ y: Int, _ c: UInt32, _ scale: Int) {
        let x: Int = (320 - b.textWidth(s, scale: scale)) / 2
        shadowText(b, s, x, y, c, scale)
    }

    private func panel(_ b: TrueColorBuffer, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        b.fillRect(x, y, w, h, SkySlide64.cBlack)
        b.fillRect(x + 2, y + 2, w - 4, h - 4, SkySlide64.cPanel)
        b.fillRect(x + 2, y + 2, w - 4, 2, TrueColorBuffer.rgb(70, 110, 220))
    }

    // MARK: - Draw entry

    override func drawTrueColor(_ b: TrueColorBuffer) {
        switch phase {
        case .title, .ready, .slide:
            drawSlideWorld(b)
        case .fly, .splash:
            drawFlyWorld(b)
        case .summary, .results:
            drawFlyWorld(b)
        }
        drawSparks(b)
        drawHUD(b)
        drawOverlays(b)
    }

    private func drawSparks(_ b: TrueColorBuffer) {
        for s in sparks {
            let sz: Int = max(1, s.size * s.life / max(1, s.maxLife) + 1)
            b.fillRect(Int(s.x), Int(s.y), sz, sz, s.col)
        }
    }

    // MARK: - Slide rendering

    private func drawSlideWorld(_ b: TrueColorBuffer) {
        var sx: Int = swayX
        var sy: Int = swayY
        if shake > 0 {
            sx += (tick & 1) == 0 ? 3 : -3
            sy += (tick & 2) == 0 ? 2 : -2
        }
        sx = max(-40, min(40, sx))
        sy = max(-36, min(36, sy))
        let tr: Int = Int(max(0, min(travel, 1_000_000)))
        b.withPixels { p, w, h in
            if w < 320 || h < 288 { return }
            self.renderTube(p, w, h, sx, sy, tr)
        }
        let cx: Int = 160 + sx
        let cy: Int = 144 + sy

        // the open sky at the end of the slide
        let relEnd: Float = slideLen - travel
        if relEnd < 3400 && phase != .title {
            let d: Float = relEnd + SkySlide64.shipDepth
            let rr: Int = Int(max(2, min(500, SkySlide64.depthK / max(30, d))))
            disc(b, cx, cy, rr, TrueColorBuffer.rgb(120, 200, 255))
            disc(b, cx, cy + rr / 6, rr * 3 / 4, TrueColorBuffer.rgb(170, 225, 255))
            disc(b, cx - rr / 4, cy + rr / 4, rr / 4, SkySlide64.cWhite)
            disc(b, cx + rr / 5, cy + rr / 3, rr / 5, SkySlide64.cWhite)
            if rr > 6 {
                disc(b, cx + rr / 6, cy - rr / 3, max(1, rr / 8), SkySlide64.cYellow)
            }
        }

        drawStreaks(b, cx, cy)

        // far items first, then the rider, then items that already passed the rider
        var i: Int = items.count - 1
        while i >= 0 {
            let d: Float = items[i].z - travel + SkySlide64.shipDepth
            if d >= SkySlide64.shipDepth { drawItem(b, items[i], d, cx, cy) }
            i -= 1
        }
        drawRiderSlide(b, cx, cy)
        i = items.count - 1
        while i >= 0 {
            let d: Float = items[i].z - travel + SkySlide64.shipDepth
            if d < SkySlide64.shipDepth && d > 34 { drawItem(b, items[i], d, cx, cy) }
            i -= 1
        }
    }

    private func renderTube(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ sx: Int, _ sy: Int, _ tr: Int) {
        let t = SkySlide64.tables
        let tw = Tables.tw
        let ox: Int = 40 - sx
        let oy: Int = 36 - sy
        let ang = t.ang
        let dep = t.dep
        let fog = t.fog
        let lut = t.lut
        for y in 0..<h {
            let ty: Int = y + oy
            if ty < 0 || ty >= Tables.th { continue }
            let rowBase: Int = ty * tw + ox
            let outBase: Int = y * w
            for x in 0..<w {
                let ti: Int = rowBase + x
                let a: Int = Int(ang[ti])
                let d: Int = Int(dep[ti])
                let u: Int = d + tr
                let pan: Int = a >> 3
                var band: Int = ((u >> 6) + (a >> 4)) & 1
                if pan >= 6 && pan <= 9 { band = (u >> 5) & 1 }
                let f: Int = fog[d >> 5]
                p[outBase + x] = lut[((pan << 1) | band) * 16 + f]
            }
        }
    }

    private func drawStreaks(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int) {
        if phase == .title || phase == .ready { return }
        if speed < 9.5 && !boosting && padT <= 0 { return }
        let n: Int = (boosting || padT > 0) ? 28 : 14
        for i in 0..<n {
            let ph: Float = (streakPh[i] + Float(tick) * 0.03).truncatingRemainder(dividingBy: 1)
            let r0: Float = 40 + ph * ph * 190
            let r1: Float = r0 + 8 + ph * 22
            let a: Float = streakAng[i]
            let ca: Float = cos(a)
            let sa: Float = sin(a)
            for k in 0..<4 {
                let rr: Float = r0 + (r1 - r0) * Float(k) / 3
                b.fillRect(cx + Int(ca * rr), cy + Int(sa * rr), 2, 2, SkySlide64.cWhite)
            }
        }
    }

    private func itemScreen(_ it: Item, _ d: Float, _ cx: Int, _ cy: Int) -> (Int, Int, Int) {
        let rr: Float = SkySlide64.depthK / d * 0.9
        let a: Float = it.pos / 256 * 2 * Float.pi
        let x: Int = cx + Int(cos(a) * rr)
        let y: Int = cy + Int(sin(a) * rr)
        let unit: Int = Int(max(1, min(200, 1700 / d)))
        return (x, y, unit)
    }

    private func drawItem(_ b: TrueColorBuffer, _ it: Item, _ d: Float, _ cx: Int, _ cy: Int) {
        if it.done && it.z - travel < 0 { return }
        if it.done { return }
        let (x, y, u) = itemScreen(it, d, cx, cy)
        if x < -80 || x > 400 || y < -80 || y > 370 { return }
        let pulse: Int = ((tick / 6) & 1)
        switch it.kind {
        case SkySlide64.kStar:
            let r: Int = u + 2
            sparkle(b, x, y, r + 2, TrueColorBuffer.rgb(255, 150, 30), false)
            sparkle(b, x, y, r, SkySlide64.cYellow, false)
            disc(b, x, y, max(1, r / 3), SkySlide64.cWhite)
        case SkySlide64.kGem:
            let r: Int = Int(Float(u) * 1.2) + 2
            sparkle(b, x, y, r + 1, TrueColorBuffer.rgb(120, 30, 140), true)
            sparkle(b, x, y, r, SkySlide64.cPink, true)
            sparkle(b, x - r / 5, y - r / 5, max(1, r / 2), TrueColorBuffer.rgb(255, 210, 245), true)
        case SkySlide64.kPad:
            let r: Int = Int(Float(u) * 1.7) + 2
            ell(b, x, y, r + 2, r * 2 / 3 + 2, TrueColorBuffer.rgb(255, 90, 20))
            ell(b, x, y, r, r * 2 / 3, pulse == 0 ? SkySlide64.cYellow : SkySlide64.cOrange)
            let cw: Int = max(1, r / 3)
            b.fillRect(x - r / 2, y - cw / 2, r, cw, SkySlide64.cWhite)
            b.fillRect(x + r / 4, y - cw, cw, cw * 2, SkySlide64.cWhite)
        case SkySlide64.kBump:
            let r: Int = Int(Float(u) * 1.5) + 3
            disc(b, x, y, r + 1, TrueColorBuffer.rgb(40, 30, 80))
            disc(b, x, y, r, SkySlide64.cRed)
            disc(b, x, y, r * 2 / 3, SkySlide64.cWhite)
            disc(b, x, y, r / 3, SkySlide64.cYellow)
            disc(b, x - r / 3, y - r / 3, max(1, r / 6), SkySlide64.cWhite)
        default:
            let r: Int = Int(Float(u) * 1.6) + 3
            ell(b, x, y, r + 2, r / 2 + 2, TrueColorBuffer.rgb(20, 120, 60))
            ell(b, x, y, r, r / 2, SkySlide64.cGreen)
            b.fillRect(x - max(1, r / 8), y - r / 3, max(2, r / 4), r * 2 / 3, SkySlide64.cWhite)
        }
    }

    private func drawRiderSlide(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int) {
        let jh: Float = jumpHeight()
        let rr: Float = SkySlide64.depthK / SkySlide64.shipDepth * 0.9
        let a: Float = pos / 256 * 2 * Float.pi
        let wallX: Int = cx + Int(cos(a) * rr)
        let wallY: Int = cy + Int(sin(a) * rr)
        let lift: Float = jh * 34
        let x: Int = wallX + Int(-cos(a) * lift)
        let y: Int = wallY + Int(-sin(a) * lift)
        // shadow on the wall
        ell(b, wallX, wallY + 10, 15, 5, TrueColorBuffer.rgb(30, 70, 150))
        let lean: Int = Int(steerV * 1.5)
        let bob: Int = ((tick / 8) & 1)
        // inner-tube
        ell(b, x, y + 6, 20, 12, TrueColorBuffer.rgb(200, 40, 120))
        ell(b, x, y + 4, 19, 11, TrueColorBuffer.rgb(255, 100, 170))
        ell(b, x, y + 5, 10, 5, TrueColorBuffer.rgb(40, 150, 235))
        ell(b, x - 8, y, 6, 2, TrueColorBuffer.rgb(255, 200, 230))
        ell(b, x + 11, y + 7, 3, 2, SkySlide64.cYellow)
        // rider
        ell(b, x + lean / 2, y - 3, 7, 8, SkySlide64.cYellow)
        ell(b, x + lean / 2, y - 1, 7, 3, TrueColorBuffer.rgb(255, 140, 40))
        b.fillRect(x + lean / 2 - 12, y - 13 - bob, 4, 8, SkySlide64.cSkin)
        b.fillRect(x + lean / 2 + 9, y - 13, 4, 8, SkySlide64.cSkin)
        disc(b, x + lean, y - 14, 7, SkySlide64.cSkin)
        disc(b, x + lean, y - 18, 7, SkySlide64.cRed)
        b.fillRect(x + lean - 7, y - 15, 14, 2, SkySlide64.cRed)
        disc(b, x + lean, y - 25, 2, SkySlide64.cYellow)
        b.fillRect(x + lean - 4, y - 12, 2, 2, SkySlide64.cBlack)
        b.fillRect(x + lean + 2, y - 12, 2, 2, SkySlide64.cBlack)
        b.fillRect(x + lean - 2, y - 8, 4, 1, TrueColorBuffer.rgb(200, 60, 60))
        if boosting || padT > 0 {
            ell(b, x, y + 18, 9, 6, SkySlide64.cOrange)
            ell(b, x, y + 18, 5, 4, SkySlide64.cYellow)
        }
    }

    // MARK: - Fly rendering

    private func projectPoint(_ wx: Float, _ wy: Float, _ wa: Float) -> (Bool, Int, Int, Float, Float) {
        let fwdX: Float = cos(psi)
        let fwdY: Float = sin(psi)
        let rx: Float = wx - camX
        let ry: Float = wy - camY
        let z: Float = rx * fwdX + ry * fwdY
        if z < 12 || z > 1500 { return (false, 0, 0, 0, z) }
        let lat: Float = rx * (-fwdY) + ry * fwdX
        let sc: Float = SkySlide64.focal / z
        let sxf: Float = 160 + lat * sc
        let syf: Float = Float(hzCur) + (camH - wa) * sc
        if sxf < -600 || sxf > 920 || syf < -600 || syf > 900 { return (false, 0, 0, 0, z) }
        return (true, Int(sxf), Int(syf), sc, z)
    }

    private func drawFlyWorld(_ b: TrueColorBuffer) {
        // camera
        let fwdX: Float = cos(psi)
        let fwdY: Float = sin(psi)
        camX = fx - fwdX * 55
        camY = fy - fwdY * 55
        camH = max(0, alt) + 16
        var hz: Int = 112 + Int(pitch * 26)
        if shake > 0 { hz += (tick & 1) == 0 ? 3 : -3 }
        hz = max(50, min(220, hz))
        hzCur = hz
        let rightX: Float = -fwdY
        let rightY: Float = fwdX
        let bankV: Float = bank
        let cH: Float = camH

        b.withPixels { p, w, h in
            if w < 320 || h < 288 { return }
            let sky = SkySlide64.skyLut
            let tex = SkySlide64.groundTex
            let lut = SkySlide64.groundLut
            let haze = SkySlide64.hazeCol
            let top: Int = min(hz, h)
            for y in 0..<top {
                let li: Int = min(63, y * 63 / max(1, hz))
                let c: UInt32 = sky[li]
                let base: Int = y * w
                for x in 0..<w { p[base + x] = c }
            }
            if hz < h {
                for y in hz..<h {
                    let dy: Int = y - hz
                    let base: Int = y * w
                    if dy == 0 {
                        for x in 0..<w { p[base + x] = haze }
                        continue
                    }
                    let dist: Float = cH * SkySlide64.focal / Float(dy)
                    if dist > 1400 {
                        for x in 0..<w { p[base + x] = haze }
                        continue
                    }
                    var fl: Int = Int(dist / 85)
                    if fl > 15 { fl = 15 }
                    if fl < 0 { fl = 0 }
                    let k: Float = dist / SkySlide64.focal
                    let shear: Float = bankV * Float(dy) * 0.16
                    let off: Float = -160 - shear
                    var wx: Float = self.camX + fwdX * dist + rightX * k * off
                    var wy: Float = self.camY + fwdY * dist + rightY * k * off
                    let stx: Float = rightX * k
                    let sty: Float = rightY * k
                    let lb: Int = fl * 8
                    for x in 0..<w {
                        let u: Int = Int(wx) & 255
                        let v: Int = Int(wy) & 255
                        p[base + x] = lut[lb + Int(tex[(v << 8) | u])]
                        wx += stx
                        wy += sty
                    }
                }
            }
        }

        drawSkyDecor(b, hz)
        drawPool(b, hz)

        // collect billboards
        drawList.removeAll()
        for i in 0..<decos.count {
            let d = decos[i]
            let pr = projectPoint(d.x, d.y, d.alt)
            if pr.0 {
                var di = DrawItem()
                di.z = pr.4
                di.kind = d.kind
                di.idx = i
                di.sx = pr.1
                di.sy = pr.2
                di.sc = pr.3
                drawList.append(di)
            }
        }
        for i in 0..<rings.count {
            if rings[i].done { continue }
            let r = rings[i]
            let pr = projectPoint(r.x, r.y, r.alt)
            if pr.0 {
                var di = DrawItem()
                di.z = pr.4
                di.kind = 2
                di.idx = i
                di.sx = pr.1
                di.sy = pr.2
                di.sc = pr.3
                drawList.append(di)
            }
        }
        for i in 0..<balloons.count {
            if balloons[i].popped { continue }
            let bl = balloons[i]
            let pr = projectPoint(bl.x, bl.y, bl.alt)
            if pr.0 {
                var di = DrawItem()
                di.z = pr.4
                di.kind = 3
                di.idx = i
                di.sx = pr.1
                di.sy = pr.2
                di.sc = pr.3
                drawList.append(di)
            }
        }
        drawList.sort { $0.z > $1.z }
        for di in drawList {
            drawBillboard(b, di)
        }

        // shadow on the ground below the glider
        if phase == .fly {
            let pr = projectPoint(fx, fy, 0)
            if pr.0 {
                let rx: Int = Int(max(3, min(60, 14 * pr.3)))
                let ry: Int = max(1, rx * max(1, pr.2 - hz) / 200)
                ell(b, pr.1, pr.2, rx, ry, TrueColorBuffer.rgb(40, 90, 170))
            }
            drawGlider(b)
        } else if phase == .splash || phase == .summary || phase == .results {
            drawSplashRipples(b)
        }
    }

    private func drawSkyDecor(_ b: TrueColorBuffer, _ hz: Int) {
        // rainbow, parallax with heading
        let rx: Int = 190 - Int(psi * 240) % 800
        for i in 0..<6 {
            ringO(b, rx, hz + 60, 190 - i * 6, 6, SkySlide64.rainbow[i], hz)
        }
        // sun
        let sxp: Int = 70 - Int(psi * 120) % 500
        disc(b, sxp, max(20, hz - 70), 20, TrueColorBuffer.rgb(255, 244, 170))
        disc(b, sxp, max(20, hz - 70), 14, TrueColorBuffer.rgb(255, 255, 230))
    }

    private func drawPool(_ b: TrueColorBuffer, _ hz: Int) {
        let pr = projectPoint(poolX, poolY, 0)
        if !pr.0 { return }
        let sc: Float = pr.3
        let rx: Float = SkySlide64.poolR * sc
        let ratio: Float = Float(max(1, pr.2 - hz)) / SkySlide64.focal
        let x: Int = pr.1
        let y: Int = pr.2
        let ryf: Float = rx * ratio
        let cols: [UInt32] = [
            TrueColorBuffer.rgb(255, 255, 255), TrueColorBuffer.rgb(60, 200, 255),
            TrueColorBuffer.rgb(255, 255, 255), TrueColorBuffer.rgb(255, 230, 60),
            TrueColorBuffer.rgb(255, 70, 70)
        ]
        let radii: [Float] = [1.0, 0.92, 0.65, 0.39, 0.17]
        for i in 0..<5 {
            var c: UInt32 = cols[i]
            if i == 0 && (tick / 8) & 1 == 1 { c = TrueColorBuffer.rgb(180, 235, 255) }
            let rxi: Int = Int(max(1, min(500, rx * radii[i])))
            let ryi: Int = Int(max(1, min(500, ryf * radii[i])))
            ell(b, x, y, rxi, ryi, c)
        }
        // tall flag so the pool is easy to spot from far away
        let poleH: Int = Int(max(8, min(260, 60 * sc)))
        let pw: Int = max(2, Int(sc * 2))
        b.fillRect(x - pw / 2, y - poleH, pw, poleH, SkySlide64.cWhite)
        let fl: Int = max(6, poleH / 4)
        let wave: Int = ((tick / 6) & 1)
        b.fillRect(x + pw / 2, y - poleH, fl, fl * 2 / 3 + wave, SkySlide64.cRed)
        b.fillRect(x + pw / 2, y - poleH + fl / 3, fl * 2 / 3, fl / 3, SkySlide64.cYellow)
    }

    private func drawBillboard(_ b: TrueColorBuffer, _ di: DrawItem) {
        let x: Int = di.sx
        let y: Int = di.sy
        let sc: Float = di.sc
        if di.kind == 0 {
            if di.idx >= decos.count { return }
            let s: Int = Int(max(2, min(200, decos[di.idx].size * sc)))
            let c1: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
            let c2: UInt32 = TrueColorBuffer.rgb(205, 228, 255)
            ell(b, x, y + s / 4, s * 3 / 2, s / 2, c2)
            disc(b, x - s / 2, y, s * 2 / 3, c1)
            disc(b, x + s / 3, y - s / 5, s * 3 / 4, c1)
            disc(b, x - s / 8, y - s / 3, s / 2, c1)
        } else if di.kind == 1 {
            if di.idx >= decos.count { return }
            let s: Int = Int(max(3, min(240, decos[di.idx].size * sc)))
            // rock underside
            for i in 0..<s {
                let t: Float = Float(i) / Float(s)
                let hw: Int = Int(Float(s) * (1 - t) * 1.1)
                let c: UInt32 = (i % 4 < 2) ? TrueColorBuffer.rgb(150, 100, 60) : TrueColorBuffer.rgb(120, 80, 50)
                b.fillRect(x - hw, y + i, hw * 2 + 1, 1, c)
            }
            ell(b, x, y, Int(Float(s) * 1.2), s / 3 + 1, TrueColorBuffer.rgb(255, 230, 150))
            ell(b, x, y - s / 20, Int(Float(s) * 1.1), s / 4 + 1, TrueColorBuffer.rgb(110, 225, 80))
            // palm tree
            b.fillRect(x - max(1, s / 14), y - s / 2, max(2, s / 7), s / 2, TrueColorBuffer.rgb(150, 100, 50))
            disc(b, x - s / 5, y - s / 2, s / 5 + 1, TrueColorBuffer.rgb(40, 190, 70))
            disc(b, x + s / 5, y - s / 2, s / 5 + 1, TrueColorBuffer.rgb(40, 190, 70))
            disc(b, x, y - s * 6 / 10, s / 5 + 1, TrueColorBuffer.rgb(70, 220, 90))
        } else if di.kind == 2 {
            if di.idx >= rings.count { return }
            let r: Int = Int(max(3, min(240, 22 * sc)))
            let th: Int = max(2, r / 5)
            let missed: Bool = rings[di.idx].missed
            var col: UInt32 = SkySlide64.cYellow
            if missed { col = TrueColorBuffer.rgb(170, 190, 220) }
            ringO(b, x, y, r + 1, th + 2, TrueColorBuffer.rgb(255, 140, 20), 999)
            ringO(b, x, y, r, th, col, 999)
            if !missed && ((tick / 5) + di.idx) % 4 == 0 {
                sparkle(b, x + r * 7 / 10, y - r * 7 / 10, max(3, r / 4), SkySlide64.cWhite, false)
            }
        } else {
            if di.idx >= balloons.count { return }
            let r: Int = Int(max(3, min(160, 11 * sc)))
            let c: UInt32 = SkySlide64.balloonCols[balloons[di.idx].col % 5]
            let bob: Int = Int(sin(Float(tick) * 0.1 + Float(di.idx)) * Float(r) * 0.1)
            let yy: Int = y + bob
            b.fillRect(x, yy + r, max(1, r / 14), r * 2, SkySlide64.cWhite)
            disc(b, x, yy, r, c)
            disc(b, x - r / 3, yy - r / 3, max(1, r / 4), SkySlide64.cWhite)
            b.fillRect(x - r / 6, yy + r - 1, max(2, r / 3), max(2, r / 5), c)
        }
    }

    private func drawGlider(_ b: TrueColorBuffer) {
        var cx: Int = 160 + Int(bank * 16)
        var cy: Int = 214 - Int(pitch * 12)
        if shake > 0 { cy += (tick & 1) == 0 ? 2 : -2 }
        cx = max(40, min(280, cx))
        cy = max(120, min(250, cy))
        let flap: Float = flapT > 0 ? sin(Float(flapT) * 0.35) : sin(Float(tick) * 0.12) * 0.3
        let bk: Int = Int(bank * 8)
        // wings
        for side in 0..<2 {
            let sgn: Int = side == 0 ? -1 : 1
            for i in 0..<4 {
                let wxp: Int = cx + sgn * (10 + i * 11)
                var wyp: Int = cy - 6 - i * 2 + Int(flap * Float(i) * 6)
                wyp -= sgn * bk * (i + 1) / 3
                let c: UInt32 = (i % 2 == 0) ? SkySlide64.cWhite : TrueColorBuffer.rgb(255, 205, 235)
                ell(b, wxp, wyp + 1, 11 - i, 6, TrueColorBuffer.rgb(170, 190, 230))
                ell(b, wxp, wyp, 11 - i, 5, c)
            }
        }
        // legs and body
        b.fillRect(cx - 5, cy + 14, 4, 8, TrueColorBuffer.rgb(40, 90, 220))
        b.fillRect(cx + 1, cy + 14, 4, 8, TrueColorBuffer.rgb(40, 90, 220))
        b.fillRect(cx - 5, cy + 21, 4, 2, SkySlide64.cRed)
        b.fillRect(cx + 1, cy + 21, 4, 2, SkySlide64.cRed)
        ell(b, cx, cy + 6, 8, 10, SkySlide64.cOrange)
        ell(b, cx, cy + 4, 7, 6, TrueColorBuffer.rgb(255, 190, 80))
        // head and cap seen from behind
        disc(b, cx + bk / 3, cy - 8, 8, TrueColorBuffer.rgb(110, 60, 30))
        disc(b, cx + bk / 3, cy - 11, 8, SkySlide64.cRed)
        disc(b, cx + bk / 3, cy - 19, 2, SkySlide64.cYellow)
        b.fillRect(cx + bk / 3 - 8, cy - 8, 16, 2, SkySlide64.cRed)
        // arms
        b.fillRect(cx - 12, cy - 1, 5, 4, SkySlide64.cSkin)
        b.fillRect(cx + 8, cy - 1, 5, 4, SkySlide64.cSkin)
        if diveOn {
            for i in 0..<3 {
                b.fillRect(cx - 20 + i * 20, cy + 26, 2, 14, SkySlide64.cWhite)
            }
        }
    }

    private func drawSplashRipples(_ b: TrueColorBuffer) {
        let pr = projectPoint(fx, fy, 0)
        if !pr.0 { return }
        let t: Int = max(0, 130 - phaseT)
        if phase != .splash { return }
        for i in 0..<3 {
            let rr: Int = (t * 2 + i * 22) % 90 + 6
            let ry: Int = max(1, rr / 3)
            let c: UInt32 = i % 2 == 0 ? SkySlide64.cWhite : SkySlide64.cCyan
            ell(b, pr.1, pr.2, rr, ry, c)
            ell(b, pr.1, pr.2, max(1, rr - 3), max(1, ry - 1), TrueColorBuffer.rgb(70, 190, 255))
        }
    }

    // MARK: - HUD

    private func drawMeterBar(_ b: TrueColorBuffer, _ x: Int, _ y: Int, _ w: Int, _ frac: Float, _ c: UInt32, _ label: String) {
        b.fillRect(x - 2, y - 2, w + 4, 12, SkySlide64.cBlack)
        b.fillRect(x, y, w, 8, TrueColorBuffer.rgb(40, 50, 90))
        let f: Float = max(0, min(1, frac))
        b.fillRect(x, y, Int(Float(w) * f), 8, c)
        b.fillRect(x, y, Int(Float(w) * f), 2, SkySlide64.cWhite)
        b.text(label, x + 3, y + 2, SkySlide64.cBlack, scale: 1)
    }

    private func drawHUD(_ b: TrueColorBuffer) {
        if phase == .title { return }
        if phase == .summary || phase == .results { return }
        // top bar
        b.fillRect(0, 0, 320, 22, SkySlide64.cBlack)
        b.fillRect(0, 22, 320, 2, TrueColorBuffer.rgb(70, 110, 220))
        shadowText(b, zeroPad(totalScore, 6), 6, 4, SkySlide64.cWhite, 2)
        let rl: String = round > 5 ? "ENDLESS " + String(round) : "ROUND " + String(round) + "/5"
        b.text(rl, 160 - b.textWidth(rl) / 2, 8, SkySlide64.cCyan, scale: 1)
        let ml: String = fmtMult(carryMult)
        let mc: UInt32 = carryMult > 10 ? SkySlide64.cYellow : SkySlide64.cWhite
        shadowText(b, ml, 314 - b.textWidth(ml, scale: 2), 4, mc, 2)

        if phase == .slide || phase == .ready {
            // progress bar with a rider marker
            let frac: Float = max(0, min(1, travel / slideLen))
            b.fillRect(60, 280, 200, 6, SkySlide64.cBlack)
            b.fillRect(61, 281, 198, 4, TrueColorBuffer.rgb(40, 60, 120))
            b.fillRect(61, 281, Int(198 * frac), 4, SkySlide64.cCyan)
            disc(b, 61 + Int(198 * frac), 283, 5, SkySlide64.cPink)
            b.text("TOP", 36, 280, SkySlide64.cWhite, scale: 1)
            b.text("SKY", 266, 280, SkySlide64.cYellow, scale: 1)
            drawMeterBar(b, 8, 262, 90, meter / 100, boosting ? SkySlide64.cOrange : SkySlide64.cGreen, "BOOST")
            if combo >= 3 {
                let cs: String = "COMBO " + String(combo)
                shadowText(b, cs, 314 - b.textWidth(cs, scale: 2), 30, SkySlide64.cYellow, 2)
            }
        }
        if phase == .fly || phase == .splash {
            drawMeterBar(b, 8, 262, 90, stamina / 100, stamina >= 22 ? SkySlide64.cGreen : SkySlide64.cRed, "FLAP")
            // altitude gauge
            b.fillRect(304, 60, 10, 140, SkySlide64.cBlack)
            b.fillRect(306, 62, 6, 136, TrueColorBuffer.rgb(40, 50, 90))
            let af: Float = max(0, min(1, alt / 160))
            let ah: Int = Int(136 * af)
            b.fillRect(306, 198 - ah, 6, ah, alt < 25 ? SkySlide64.cRed : SkySlide64.cCyan)
            b.text("ALT", 300, 204, SkySlide64.cWhite, scale: 1)
            // counts
            let rs: String = "RINGS " + String(ringsGot) + "/" + String(rings.count)
            shadowText(b, rs, 6, 30, SkySlide64.cYellow, 1)
            let bs: String = "BALLOONS " + String(balloonsGot)
            shadowText(b, bs, 6, 40, SkySlide64.cPink, 1)
            if phase == .fly { drawPoolArrow(b) }
        }
    }

    private func drawPoolArrow(_ b: TrueColorBuffer) {
        let fwdX: Float = cos(psi)
        let fwdY: Float = sin(psi)
        let rx: Float = poolX - fx
        let ry: Float = poolY - fy
        let zf: Float = rx * fwdX + ry * fwdY
        let lat: Float = rx * (-fwdY) + ry * fwdX
        let dist: Int = Int(max(0, min(9999, sqrt(rx * rx + ry * ry))))
        let ds: String = "POOL " + String(dist) + "M"
        shadowText(b, ds, 160 - b.textWidth(ds) / 2, 30, SkySlide64.cWhite, 1)
        if zf < 0 || abs(lat) > zf * 0.8 {
            let left: Bool = lat < 0
            let ax: Int = left ? 14 : 306
            let bob: Int = (tick / 6) & 1
            for i in 0..<10 {
                let w: Int = 10 - i
                let xx: Int = left ? ax + i - bob : ax - i + bob
                b.fillRect(xx, 130 - w, 2, w * 2, SkySlide64.cYellow)
            }
        }
    }

    // MARK: - Overlays

    private func drawOverlays(_ b: TrueColorBuffer) {
        // floating texts
        for t in texts {
            let w: Int = b.textWidth(t.text, scale: 2)
            shadowText(b, t.text, t.x - w / 2, Int(t.y), t.col, 2)
        }
        if flashT > 0 {
            let th: Int = min(40, flashT * 4)
            let c: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
            b.fillRect(0, 0, 320, th, c)
            b.fillRect(0, 288 - th, 320, th, c)
            b.fillRect(0, 0, th, 288, c)
            b.fillRect(320 - th, 0, th, 288, c)
        }
        if bannerT > 0 && (phase == .slide || phase == .fly || phase == .splash) {
            let col: UInt32 = (tick / 4) % 2 == 0 ? SkySlide64.cYellow : SkySlide64.cWhite
            ctext(b, bannerText, 90, col, 3)
        }

        switch phase {
        case .title:
            drawTitle(b)
        case .ready:
            let n: Int = phaseT / 60 + 1
            if phaseT > 20 {
                ctext(b, String(min(3, n)), 96, SkySlide64.cYellow, 8)
            }
            panel(b, 40, 200, 240, 44)
            ctext(b, "LEFT RIGHT  STEER", 208, SkySlide64.cWhite, 1)
            ctext(b, "A  BOOST     GRAB STARS", 220, SkySlide64.cYellow, 1)
            ctext(b, "DODGE THE BEACH BALLS", 232, SkySlide64.cPink, 1)
        case .slide:
            if hintT > 0 {
                ctext(b, "TOUCH TO STEER - TAP OR HOLD A TO BOOST", 252, SkySlide64.cWhite, 1)
            }
        case .fly:
            if hintT > 0 {
                panel(b, 20, 236, 280, 40)
                ctext(b, "TOUCH OR D-PAD STEER  HIGH CLIMBS LOW DIVES", 243, SkySlide64.cWhite, 1)
                ctext(b, "TAP OR A FLAP  LOW TOUCH OR B DIVE", 255, SkySlide64.cYellow, 1)
                ctext(b, "FLY THROUGH RINGS AND POP BALLOONS", 265, SkySlide64.cPink, 1)
            }
        case .splash:
            let m: String = fmtMult(landMult)
            ctext(b, "LANDING " + m, 130, SkySlide64.cYellow, 2)
            ctext(b, "NEXT SLIDE " + m + " SCORE", 150, SkySlide64.cWhite, 1)
        case .summary:
            drawSummary(b)
        case .results:
            drawResults(b)
        }
    }

    private func drawTitle(_ b: TrueColorBuffer) {
        panel(b, 24, 54, 272, 104)
        ctext(b, "SKY SLIDE", 66, SkySlide64.cYellow, 5)
        ctext(b, "64", 106, SkySlide64.cPink, 4)
        ctext(b, "SLIDE  LAUNCH  GLIDE  SPLASH", 144, SkySlide64.cCyan, 1)
        if (tick / 30) % 2 == 0 {
            ctext(b, "PRESS A", 190, SkySlide64.cWhite, 3)
        }
        panel(b, 40, 226, 240, 40)
        ctext(b, "RIDE THE SLIDE - FLY - LAND IN THE POOL", 233, SkySlide64.cWhite, 1)
        ctext(b, "BULLSEYE LANDINGS MAKE THE NEXT SLIDE FASTER", 245, SkySlide64.cYellow, 1)
        ctext(b, "5 ROUNDS THEN ENDLESS", 255, SkySlide64.cPink, 1)
    }

    private func drawStarRow(_ b: TrueColorBuffer, _ y: Int, _ got: Int, _ r: Int) {
        let gap: Int = r * 3
        let x0: Int = 160 - gap
        for i in 0..<3 {
            let on: Bool = i < got
            let cx: Int = x0 + i * gap
            if on {
                sparkle(b, cx, y, r + 2, TrueColorBuffer.rgb(255, 140, 30), false)
                sparkle(b, cx, y, r, SkySlide64.cYellow, false)
                disc(b, cx, y, max(1, r / 3), SkySlide64.cWhite)
            } else {
                sparkle(b, cx, y, r, TrueColorBuffer.rgb(70, 80, 130), false)
            }
        }
    }

    private func drawSummary(_ b: TrueColorBuffer) {
        panel(b, 30, 36, 260, 216)
        ctext(b, "ROUND " + String(round) + " DONE", 46, SkySlide64.cYellow, 2)
        let shown: Int = min(roundStars, max(0, (phaseT - 10) / 14))
        drawStarRow(b, 88, shown, 14)
        let ok1: Bool = landMult > 10
        let ok2: Bool = pickupsTotal > 0 && pickupsGot * 100 >= pickupsTotal * 60
        let ok3: Bool = !rings.isEmpty && ringsGot * 100 >= rings.count * 60
        let l1: String = (ok1 ? "YES " : "NO  ") + "SPLASHED IN THE POOL"
        let l2: String = (ok2 ? "YES " : "NO  ") + "SLIDE STARS " + String(pickupsGot) + "/" + String(pickupsTotal)
        let l3: String = (ok3 ? "YES " : "NO  ") + "RINGS " + String(ringsGot) + "/" + String(rings.count)
        b.text(l1, 52, 118, ok1 ? SkySlide64.cGreen : TrueColorBuffer.rgb(170, 180, 220), scale: 1)
        b.text(l2, 52, 132, ok2 ? SkySlide64.cGreen : TrueColorBuffer.rgb(170, 180, 220), scale: 1)
        b.text(l3, 52, 146, ok3 ? SkySlide64.cGreen : TrueColorBuffer.rgb(170, 180, 220), scale: 1)
        b.text("BALLOONS " + String(balloonsGot) + "   BEST COMBO " + String(bestCombo), 52, 162, SkySlide64.cPink, scale: 1)
        ctext(b, "LANDING " + fmtMult(landMult), 180, SkySlide64.cYellow, 2)
        ctext(b, "SCORE " + String(totalScore), 202, SkySlide64.cWhite, 2)
        if phaseT > 40 && (tick / 30) % 2 == 0 {
            ctext(b, "A NEXT SLIDE", 226, SkySlide64.cCyan, 1)
            if round > 5 { ctext(b, "START OR TAP TOP FINISH", 238, SkySlide64.cWhite, 1) }
        }
    }

    private func rankName() -> String {
        if totalStars >= 14 { return "SKY CHAMPION" }
        if totalStars >= 11 { return "GOLD FLYER" }
        if totalStars >= 8 { return "SILVER GLIDER" }
        if totalStars >= 4 { return "BRONZE SPLASHER" }
        return "TUBE ROOKIE"
    }

    private func drawResults(_ b: TrueColorBuffer) {
        panel(b, 24, 30, 272, 228)
        ctext(b, round > 5 ? "ALL DONE" : "SLIDE COMPLETE", 40, SkySlide64.cYellow, 2)
        ctext(b, "ROUND " + String(round) + "  STARS " + String(totalStars), 66, SkySlide64.cWhite, 1)
        let shown: Int = min(roundStars, max(0, (phaseT - 5) / 14))
        drawStarRow(b, 100, shown, 14)
        ctext(b, "RANK", 130, SkySlide64.cCyan, 1)
        ctext(b, rankName(), 142, SkySlide64.cPink, 2)
        ctext(b, "SCORE " + String(totalScore), 170, SkySlide64.cWhite, 3)
        ctext(b, "LAST LANDING " + fmtMult(landMult), 200, SkySlide64.cYellow, 1)
        if phaseT > 60 && (tick / 30) % 2 == 0 {
            if round == 5 {
                ctext(b, "A OR TAP ENDLESS MODE", 222, SkySlide64.cGreen, 1)
            }
            ctext(b, "START PLAY AGAIN", 236, SkySlide64.cWhite, 1)
        }
    }
}

extension Cartridge {
    static let skySlide64 = Cartridge(
        id: "skyslide64", title: "SKY SLIDE 64", genre: "Arcade",
        blurb: "Zoom down a giant water slide, launch into the sky, unfold your wings and glide over floating islands to splash in the bullseye pool.",
        controls: "SLIDE: LEFT/RIGHT steer, A boost. FLY: D-PAD pitch and bank, A flap, B dive.",
        era: .n64, labelTop: 0x40B8FF, labelBottom: 0xFF70C0, factory: { SkySlide64() })
}
