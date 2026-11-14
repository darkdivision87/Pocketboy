#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// JET SKI 64: a tropical sunset jet-ski race. The water is a Mode-7 floor sampled from a generated 512x512 island
/// circuit map; wave motion comes from offsetting the sample coordinates and shading by a sine table, so the water
/// shimmers while the coast stays put. Palms, buoys, ramps, boost buoys and wave bumps are billboards. Three
/// rubber-banding rivals, jump ramps with spin tricks, drifting, a boost meter, a shortcut channel, a minimap, and a
/// second harder circuit that unlocks when you finish in the top three.
final class JetSki64: Game {
    // MARK: - Types

    private enum Phase { case title, ready, race, finish, results }

    private struct Racer {
        var x: Float = 0
        var y: Float = 0
        var psi: Float = 0
        var speed: Float = 0
        var vx: Float = 0
        var vy: Float = 0
        var z: Float = 0
        var vz: Float = 0
        var lean: Float = 0
        var spin: Float = 0
        var seg = 0
        var segT: Float = 0
        var lat: Float = 0
        var lapIdx = -1
        var total: Float = 0
        var lane: Float = 0
        var col = 0
        var top: Float = 2.4
        var boostT = 0
        var rampCool = 0
        var bumpCool = 0
        var done = false
        var finishFrame = 0
        var driftT = 0
        var bounceCool = 0
    }

    private struct Obj {
        var x: Float = 0
        var y: Float = 0
        var kind = 0
        var cool = 0
        var variant = 0
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

    private struct DrawItem {
        var z: Float = 0
        var kind = 0
        var idx = 0
        var sx = 0
        var sy = 0
        var sc: Float = 1
    }

    // MARK: - Constants

    private static let nSeg = 48
    private static let focal: Float = 190
    private static let totalLaps = 3

    private static let kPalm = 0
    private static let kRed = 1
    private static let kWhite = 2
    private static let kBoost = 3
    private static let kRamp = 4
    private static let kBump = 5
    private static let kSign = 6
    private static let kGate = 7

    private static let cWhite: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    private static let cBlack: UInt32 = TrueColorBuffer.rgb(14, 12, 40)
    private static let cYellow: UInt32 = TrueColorBuffer.rgb(255, 230, 60)
    private static let cRed: UInt32 = TrueColorBuffer.rgb(255, 70, 80)
    private static let cGreen: UInt32 = TrueColorBuffer.rgb(100, 240, 130)
    private static let cCyan: UInt32 = TrueColorBuffer.rgb(90, 230, 255)
    private static let cPink: UInt32 = TrueColorBuffer.rgb(255, 110, 200)
    private static let cOrange: UInt32 = TrueColorBuffer.rgb(255, 150, 40)
    private static let cPanel: UInt32 = TrueColorBuffer.rgb(16, 50, 120)
    private static let cSkin: UInt32 = TrueColorBuffer.rgb(255, 205, 160)

    private static let tune = Tune(bpm: 142, wave: .pulse25, volume: 0.12,
        "G4:0.5 C5:0.5 E5:0.5 G5:1 E5:0.5 C5:0.5 D5:0.5 F5:0.5 A5:1 F5:0.5 D5:0.5 E5:0.5 G5:0.5 C6:1 G5:0.5 E5:0.5 A4:0.5 C5:0.5 E5:0.5 A5:1 E5:0.5 C5:0.5 B4:0.5 D5:0.5 G5:1 D5:0.5 B4:0.5 C5:1 R:1")

    /// Course shape: base radius, then amplitude/phase pairs for the 2nd, 3rd and 5th harmonics, half-width, width wobble.
    private static let courseParams: [[Float]] = [
        [250, 52, 0.4, 28, 1.1, 10, 2.0, 38, 5],
        [255, 60, 1.2, 40, 0.3, 18, 0.7, 32, 4]
    ]
    private static let courseNames: [String] = ["PALM COVE", "TYPHOON BAY"]
    private static let aiTop: [[Float]] = [[2.5, 2.4, 2.3], [2.78, 2.68, 2.58]]
    private static let rivalNames: [String] = ["YOU", "COCO", "FINN", "MIA"]

    private static let skiMain: [UInt32] = [
        TrueColorBuffer.rgb(255, 70, 150), TrueColorBuffer.rgb(255, 160, 30),
        TrueColorBuffer.rgb(60, 200, 90), TrueColorBuffer.rgb(150, 90, 240)
    ]
    private static let skiAccent: [UInt32] = [
        TrueColorBuffer.rgb(255, 235, 80), TrueColorBuffer.rgb(255, 245, 160),
        TrueColorBuffer.rgb(255, 255, 255), TrueColorBuffer.rgb(120, 245, 200)
    ]
    private static let helmetCol: [UInt32] = [
        TrueColorBuffer.rgb(40, 140, 255), TrueColorBuffer.rgb(255, 60, 60),
        TrueColorBuffer.rgb(255, 230, 60), TrueColorBuffer.rgb(255, 255, 255)
    ]
    private static let shirtCol: [UInt32] = [
        TrueColorBuffer.rgb(255, 235, 60), TrueColorBuffer.rgb(40, 120, 255),
        TrueColorBuffer.rgb(255, 90, 90), TrueColorBuffer.rgb(60, 220, 200)
    ]

    private static let sinT: [Int] = {
        var a = [Int](repeating: 0, count: 256)
        for i in 0..<256 {
            let v: Float = sin(Float(i) / 256 * 2 * Float.pi) * 32
            a[i] = Int(v)
        }
        return a
    }()

    private static let hazeCol: UInt32 = TrueColorBuffer.rgb(255, 206, 150)

    private static let skyLut: [UInt32] = {
        var out = [UInt32](repeating: 0, count: 64)
        let stops: [Float] = [
            70, 70, 190,
            200, 80, 170,
            255, 130, 110,
            255, 206, 150
        ]
        for i in 0..<64 {
            let t: Float = Float(i) / 63 * 3
            var k: Int = Int(t)
            if k > 2 { k = 2 }
            let f: Float = t - Float(k)
            let r: Float = stops[k * 3] + (stops[k * 3 + 3] - stops[k * 3]) * f
            let g: Float = stops[k * 3 + 1] + (stops[k * 3 + 4] - stops[k * 3 + 1]) * f
            let bl: Float = stops[k * 3 + 2] + (stops[k * 3 + 5] - stops[k * 3 + 2]) * f
            out[i] = TrueColorBuffer.rgb(Int(r), Int(g), Int(bl))
        }
        return out
    }()

    /// 12 fog levels x 20 palette entries: water (3 kinds x 4 wave shades) then land colours.
    private static let groundLut: [UInt32] = {
        var out = [UInt32](repeating: 0, count: 12 * 20)
        let water: [Float] = [10, 110, 235, 0, 165, 245, 60, 225, 225]
        let land: [Float] = [255, 226, 150, 208, 170, 105, 90, 205, 70, 40, 150, 60, 255, 255, 255, 40, 40, 60]
        for fl in 0..<12 {
            let ft: Float = min(1, Float(fl) / 11) * 0.92
            for pal in 0..<18 {
                var r: Float = 0
                var g: Float = 0
                var bl: Float = 0
                if pal < 12 {
                    let kind: Int = pal / 4
                    let lv: Int = pal % 4
                    r = water[kind * 3]
                    g = water[kind * 3 + 1]
                    bl = water[kind * 3 + 2]
                    if lv == 0 {
                        r *= 0.84
                        g *= 0.84
                        bl *= 0.9
                    } else if lv == 2 {
                        r = min(255, r * 1.1 + 8)
                        g = min(255, g * 1.08 + 8)
                        bl = min(255, bl * 1.04 + 4)
                    } else if lv == 3 {
                        r = r + (255 - r) * 0.42
                        g = g + (255 - g) * 0.42
                        bl = bl + (255 - bl) * 0.42
                    }
                } else {
                    let li: Int = pal - 12
                    r = land[li * 3]
                    g = land[li * 3 + 1]
                    bl = land[li * 3 + 2]
                }
                let fr: Float = r + (255 - r) * ft
                let fg: Float = g + (206 - g) * ft
                let fb: Float = bl + (150 - bl) * ft
                out[fl * 20 + pal] = TrueColorBuffer.rgb(Int(fr), Int(fg), Int(fb))
            }
        }
        return out
    }()

    // MARK: - Course data

    private static func rad(_ p: [Float], _ th: Float) -> Float {
        let a: Float = p[1] * cos(2 * th + p[2])
        let b: Float = p[3] * cos(3 * th + p[4])
        let c: Float = p[5] * cos(5 * th + p[6])
        return p[0] + a + b + c
    }

    private static func drad(_ p: [Float], _ th: Float) -> Float {
        let a: Float = -2 * p[1] * sin(2 * th + p[2])
        let b: Float = -3 * p[3] * sin(3 * th + p[4])
        let c: Float = -5 * p[5] * sin(5 * th + p[6])
        return a + b + c
    }

    private static func halfWidth(_ p: [Float], _ th: Float) -> Float {
        return p[7] + p[8] * cos(5 * th + 1)
    }

    private static let shortA = 8
    private static let shortB = 16

    private static func waypoints(_ p: [Float]) -> [Float] {
        let n: Int = nSeg
        var out = [Float](repeating: 0, count: n * 2)
        for k in 0..<n {
            let th: Float = Float(k) / Float(n) * 2 * Float.pi
            let r: Float = rad(p, th)
            out[k * 2] = 512 + r * cos(th)
            out[k * 2 + 1] = 512 + r * sin(th)
        }
        return out
    }

    private static func buildMap(_ p: [Float], _ pts: [Float]) -> [UInt8] {
        var m = [UInt8](repeating: 0, count: 512 * 512)
        let bins = 2048
        var rt = [Float](repeating: 0, count: bins)
        var dt = [Float](repeating: 0, count: bins)
        var ht = [Float](repeating: 0, count: bins)
        for i in 0..<bins {
            let th: Float = Float(i) / Float(bins) * 2 * Float.pi
            rt[i] = rad(p, th)
            dt[i] = drad(p, th)
            ht[i] = halfWidth(p, th)
        }
        let twoPi: Float = 2 * Float.pi
        for ty in 0..<512 {
            for tx in 0..<512 {
                let wx: Float = Float(tx * 2 + 1) - 512
                let wy: Float = Float(ty * 2 + 1) - 512
                let r: Float = max(1, sqrt(wx * wx + wy * wy))
                var th: Float = atan2(wy, wx)
                if th < 0 { th += twoPi }
                var bi: Int = Int(th / twoPi * Float(bins))
                if bi >= bins { bi = bins - 1 }
                if bi < 0 { bi = 0 }
                let rc: Float = rt[bi]
                let slope: Float = dt[bi] / r
                let f: Float = r - rc
                let d: Float = f / sqrt(1 + slope * slope)
                let hw: Float = ht[bi]
                let ad: Float = abs(d)
                var id = 0
                if ad < hw * 0.42 {
                    id = 0
                } else if ad < hw * 0.78 {
                    id = 1
                } else if ad < hw {
                    id = 2
                } else {
                    let over: Float = ad - hw
                    if over < 5 {
                        id = 4
                    } else if over < 14 {
                        id = 3
                    } else if d > 0 && over > 78 {
                        if over < 88 {
                            id = 2
                        } else if over < 130 {
                            id = 1
                        } else {
                            id = 0
                        }
                    } else {
                        let hsh: Int = ((tx >> 3) &* 73 &+ (ty >> 3) &* 151) & 7
                        id = hsh < 3 ? 6 : 5
                    }
                }
                // start/finish line across the channel at waypoint 0 (angle 0)
                if ad < hw && th < 0.012 * 250 / max(rc, 1) * 1.0 + 0.0 && wy > -1 && wy < 14 && wx > 0 {
                    id = ((tx >> 1) + (ty >> 1)) & 1 == 0 ? 7 : 8
                }
                m[ty * 512 + tx] = UInt8(id)
            }
        }
        // shortcut channel carved through the inner island
        let a: Int = shortA
        let bb: Int = shortB
        let ax: Float = pts[a * 2]
        let ay: Float = pts[a * 2 + 1]
        let bx: Float = pts[bb * 2]
        let by: Float = pts[bb * 2 + 1]
        let ex: Float = bx - ax
        let ey: Float = by - ay
        let len2: Float = max(1, ex * ex + ey * ey)
        let minX: Int = Int(min(ax, bx) / 2) - 8
        let maxX: Int = Int(max(ax, bx) / 2) + 8
        let minY: Int = Int(min(ay, by) / 2) - 8
        let maxY: Int = Int(max(ay, by) / 2) + 8
        for ty in max(0, minY)...min(511, maxY) {
            for tx in max(0, minX)...min(511, maxX) {
                let wx: Float = Float(tx * 2 + 1)
                let wy: Float = Float(ty * 2 + 1)
                var t: Float = ((wx - ax) * ex + (wy - ay) * ey) / len2
                t = max(0, min(1, t))
                let px: Float = ax + ex * t
                let py: Float = ay + ey * t
                let dd: Float = sqrt((wx - px) * (wx - px) + (wy - py) * (wy - py))
                let cur: Int = Int(m[ty * 512 + tx])
                if cur >= 3 && cur <= 6 {
                    if dd < 6 {
                        m[ty * 512 + tx] = 1
                    } else if dd < 9 {
                        m[ty * 512 + tx] = 2
                    }
                }
            }
        }
        return m
    }

    private static var mapCache: [[UInt8]?] = [nil, nil]

    // MARK: - State

    private var phase: Phase = .title
    private var tick = 0
    private var rng = Rng()
    private var course = 0
    private var unlocked2 = false
    private var justUnlocked = false
    private var phaseT = 0
    private var raceT = 0
    private var shake = 0
    private var flashT = 0
    private var bannerT = 0
    private var bannerText = ""
    private var hintT = 0
    private var raceScore = 0
    private var placeBonus = 0
    private var meter: Float = 20
    private var turboWindowUsed = false
    private var lockedMsgT = 0

    private var map = [UInt8](repeating: 0, count: 512 * 512)
    private var pts = [Float](repeating: 0, count: 96)
    private var dirX = [Float](repeating: 1, count: 48)
    private var dirY = [Float](repeating: 0, count: 48)
    private var hwArr = [Float](repeating: 36, count: 48)
    private var objs: [Obj] = []
    private var racers: [Racer] = []
    private var sparks: [Spark] = []
    private var texts: [FText] = []
    private var drawList: [DrawItem] = []

    private var camAng: Float = 0
    private var camX: Float = 0
    private var camY: Float = 0
    private var camH: Float = 26
    private var hzCur = 100
    private var lapStartFrame = 0
    private var bestLap = 0
    private var lastLapMark = 0
    private var finalPlace = 4
    private var tricks = 0
    private var bestTrick = 0
    private var spinHeld = false
    private var lapBannerDone = -2
    private var finalStars = 0
    private var results: [Int] = [0, 1, 2, 3]

    override var score: Int { return raceScore + placeBonus }

    override init() {
        super.init()
        loadCourse(0)
        resetRacers(true)
    }

    override func start() {
        playMusic(JetSki64.tune)
    }

    // MARK: - Setup

    private func loadCourse(_ c: Int) {
        course = c
        let p: [Float] = JetSki64.courseParams[c]
        pts = JetSki64.waypoints(p)
        let n: Int = JetSki64.nSeg
        for k in 0..<n {
            let k2: Int = (k + 1) % n
            let ex: Float = pts[k2 * 2] - pts[k * 2]
            let ey: Float = pts[k2 * 2 + 1] - pts[k * 2 + 1]
            let l: Float = max(0.001, sqrt(ex * ex + ey * ey))
            dirX[k] = ex / l
            dirY[k] = ey / l
            let th: Float = Float(k) / Float(n) * 2 * Float.pi
            hwArr[k] = JetSki64.halfWidth(p, th)
        }
        if let cached = JetSki64.mapCache[c] {
            map = cached
        } else {
            let built: [UInt8] = JetSki64.buildMap(p, pts)
            JetSki64.mapCache[c] = built
            map = built
        }
        buildObjects()
    }

    private func buildObjects() {
        objs.removeAll()
        var r = Rng(seed: UInt64(900 + course * 77))
        let n: Int = JetSki64.nSeg
        for k in 0..<n {
            let px: Float = pts[k * 2]
            let py: Float = pts[k * 2 + 1]
            let nx: Float = -dirY[k]
            let ny: Float = dirX[k]
            let hw: Float = hwArr[k]
            if k % 2 == 0 {
                addObj(JetSki64.kRed, px + nx * hw * 0.97, py + ny * hw * 0.97, 0)
                addObj(JetSki64.kWhite, px - nx * hw * 0.97, py - ny * hw * 0.97, 0)
            }
            for side in 0..<2 {
                let sg: Float = side == 0 ? 1 : -1
                let off: Float = hw + 24 + Float(r.int(34))
                let jitter: Float = Float(r.int(24)) - 12
                addObj(JetSki64.kPalm, px + nx * sg * off + dirX[k] * jitter, py + ny * sg * off + dirY[k] * jitter, r.int(3))
            }
        }
        // boost buoys, ramps, wave bumps
        let boostAt: [Int] = course == 0 ? [5, 18, 30, 42] : [4, 12, 21, 29, 37, 44]
        for (i, k) in boostAt.enumerated() {
            let off: Float = (i % 2 == 0 ? 0.3 : -0.3) * hwArr[k]
            addObj(JetSki64.kBoost, pts[k * 2] - dirY[k] * off, pts[k * 2 + 1] + dirX[k] * off, 0)
        }
        let rampAt: [Int] = course == 0 ? [11, 24, 37, 47] : [2, 10, 19, 26, 34, 41, 46]
        for (i, k) in rampAt.enumerated() {
            let off: Float = (i % 2 == 0 ? -0.35 : 0.35) * hwArr[k]
            addObj(JetSki64.kRamp, pts[k * 2] - dirY[k] * off, pts[k * 2 + 1] + dirX[k] * off, 0)
        }
        let bumpAt: [Int] = course == 0 ? [1, 14, 27, 40] : [0, 7, 15, 23, 31, 39, 45]
        for (i, k) in bumpAt.enumerated() {
            let off: Float = (i % 2 == 0 ? 0.2 : -0.25) * hwArr[k]
            addObj(JetSki64.kBump, pts[k * 2] - dirY[k] * off, pts[k * 2 + 1] + dirX[k] * off, 0)
        }
        // shortcut markers
        let a: Int = JetSki64.shortA
        let b: Int = JetSki64.shortB
        let ax: Float = pts[a * 2]
        let ay: Float = pts[a * 2 + 1]
        let bx: Float = pts[b * 2]
        let by: Float = pts[b * 2 + 1]
        var cdx: Float = bx - ax
        var cdy: Float = by - ay
        let cl: Float = max(1, sqrt(cdx * cdx + cdy * cdy))
        cdx /= cl
        cdy /= cl
        let start: Float = hwArr[a] + 8
        let px0: Float = ax + cdx * start
        let py0: Float = ay + cdy * start
        addObj(JetSki64.kGate, px0 - cdy * 11, py0 + cdx * 11, 0)
        addObj(JetSki64.kGate, px0 + cdy * 11, py0 - cdx * 11, 0)
        addObj(JetSki64.kSign, px0 - cdy * 24, py0 + cdx * 24, 0)
        let px1: Float = bx - cdx * (hwArr[b] + 8)
        let py1: Float = by - cdy * (hwArr[b] + 8)
        addObj(JetSki64.kGate, px1 - cdy * 11, py1 + cdx * 11, 0)
        addObj(JetSki64.kGate, px1 + cdy * 11, py1 - cdx * 11, 0)
    }

    private func addObj(_ kind: Int, _ x: Float, _ y: Float, _ v: Int) {
        var o = Obj()
        o.kind = kind
        o.x = x
        o.y = y
        o.variant = v
        objs.append(o)
    }

    private func resetRacers(_ autopilot: Bool) {
        racers.removeAll()
        let tops: [Float] = JetSki64.aiTop[course]
        // player takes the second grid slot
        let order: [Int] = [1, 0, 2, 3]
        for i in 0..<4 {
            var r = Racer()
            let slot: Int = order[i]
            let row: Int = slot / 2
            let sg: Float = (slot % 2 == 0) ? 1 : -1
            let back: Float = 14 + Float(row) * 18
            let nx: Float = -dirY[0]
            let ny: Float = dirX[0]
            r.x = pts[0] - dirX[0] * back + nx * sg * 11
            r.y = pts[1] - dirY[0] * back + ny * sg * 11
            r.psi = atan2(dirY[0], dirX[0])
            r.seg = JetSki64.nSeg - 1
            r.lapIdx = -1
            r.col = i
            r.top = i == 0 ? 2.8 : tops[i - 1]
            r.lane = (i == 1 ? 0.35 : (i == 2 ? -0.4 : 0.05)) * 0.8
            racers.append(r)
        }
        for i in 0..<4 { trackRacer(i, false) }
        camAng = racers[0].psi
        updateCamera(true)
    }

    private func beginRace() {
        if map.isEmpty || JetSki64.mapCache[course] == nil { loadCourse(course) }
        resetRacers(false)
        phase = .ready
        phaseT = 200
        raceT = 0
        raceScore = 0
        placeBonus = 0
        meter = 20
        tricks = 0
        bestTrick = 0
        bestLap = 0
        lapBannerDone = -2
        turboWindowUsed = false
        justUnlocked = false
        sparks.removeAll()
        texts.removeAll()
        hintT = 0
        shake = 0
        flashT = 0
        bannerT = 0
        playMusic(JetSki64.tune)
    }

    private func resetAll() {
        phase = .title
        phaseT = 0
        tick = 0
        loadCourse(course)
        resetRacers(true)
        sparks.removeAll()
        texts.removeAll()
        raceScore = 0
        placeBonus = 0
    }

    // MARK: - Helpers

    private func angDiff(_ a: Float, _ b: Float) -> Float {
        let d: Float = a - b
        if !d.isFinite { return 0 }
        return d - 2 * Float.pi * floor((d + Float.pi) / (2 * Float.pi))
    }

    private func groundId(_ x: Float, _ y: Float) -> Int {
        if !x.isFinite || !y.isFinite { return 0 }
        let ux: Int = Int(max(-100000, min(100000, x * 0.5))) & 511
        let uy: Int = Int(max(-100000, min(100000, y * 0.5))) & 511
        return Int(map[uy * 512 + ux])
    }

    private func addText(_ s: String, _ x: Int, _ y: Float, _ c: UInt32) {
        var t = FText()
        t.x = x
        t.y = y
        t.text = s
        t.col = c
        t.life = 50
        texts.append(t)
        if texts.count > 10 { texts.removeFirst() }
    }

    private func addSpark(_ x: Float, _ y: Float, _ vx: Float, _ vy: Float, _ grav: Float, _ life: Int, _ size: Int, _ c: UInt32) {
        if sparks.count > 260 { return }
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

    private func spray(_ x: Float, _ y: Float, _ n: Int, _ power: Float, _ c: UInt32) {
        for _ in 0..<n {
            let sx: Float = (Float(rng.int(200)) - 100) / 100 * power
            let sy: Float = -(0.6 + Float(rng.int(100)) / 100) * power
            addSpark(x + Float(rng.int(10)) - 5, y, sx, sy, 0.12, 16 + rng.int(14), 2 + rng.int(2), c)
        }
    }

    private func fmtTime(_ frames: Int) -> String {
        let t: Int = max(0, frames) / 6
        let m: Int = t / 600
        let s: Int = (t / 10) % 60
        let d: Int = t % 10
        return String(m) + ":" + zeroPad(s, 2) + "." + String(d)
    }

    private func placeOf(_ i: Int) -> Int {
        var p = 1
        let mine: Float = rankValue(i)
        for j in 0..<racers.count where j != i {
            if rankValue(j) > mine { p += 1 }
        }
        return p
    }

    private func rankValue(_ i: Int) -> Float {
        let r = racers[i]
        if r.done { return 1_000_000 - Float(r.finishFrame) }
        return r.total
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
    private var tapSpinT = 0
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
        if tapSpinT > 0 { tapSpinT -= 1 }
        if p.pressed {
            if phase == .race && ptX < 112 && ptY > 250 {
                tapBoostT = 50
                ptIgnore = true
                ptDown = false
            } else if phase == .race && !racers.isEmpty && racers[0].z > 1.5 {
                tapSpinT = 45
            }
            if phase == .ready {
                input.pressed.insert(.a)
            } else if phase == .title {
                if ptY >= 120 && ptY < 160 {
                    if ptX < 160 { input.pressed.insert(.left) } else { input.pressed.insert(.right) }
                } else {
                    input.pressed.insert(.a)
                }
            } else if phase == .results {
                if ptY < 30 { input.pressed.insert(.start) } else { input.pressed.insert(.a) }
            }
        }
    }

    // MARK: - Update

    override func update(_ inputRaw: InputState) {
        var input = inputRaw
        readPointer(&input)
        tick += 1
        if shake > 0 { shake -= 1 }
        if flashT > 0 { flashT -= 1 }
        if bannerT > 0 { bannerT -= 1 }
        if lockedMsgT > 0 { lockedMsgT -= 1 }
        updateSparks()
        for i in 0..<texts.count {
            texts[i].life -= 1
            texts[i].y -= 0.7
        }
        texts.removeAll { $0.life <= 0 }

        switch phase {
        case .title:
            updateTitle(input)
        case .ready:
            updateReady(input)
        case .race:
            updateRace(input)
        case .finish:
            updateRace(input)
        case .results:
            phaseT += 1
            updateCamera(false)
            if phaseT > 50 {
                if input.startPressed {
                    resetAll()
                    play(.select)
                } else if input.aPressed {
                    if justUnlocked {
                        course = 1
                        loadCourse(1)
                    }
                    play(.confirm)
                    beginRace()
                }
            }
        }
    }

    private func updateTitle(_ input: InputState) {
        // attract mode: all four ski cruise around the circuit
        for i in 0..<4 {
            driveAI(i, 2.2)
            moveRacer(i)
            trackRacer(i, false)
        }
        updateCamera(false)
        if input.leftPressed || input.rightPressed {
            let want: Int = course == 0 ? 1 : 0
            if want == 1 && !unlocked2 {
                lockedMsgT = 90
                play(.hit)
            } else {
                play(.select)
                loadCourse(want)
                resetRacers(true)
            }
        }
        if input.aPressed || input.startPressed {
            play(.confirm)
            beginRace()
        }
    }

    private func updateReady(_ input: InputState) {
        phaseT -= 1
        if phaseT > 0 && phaseT % 65 == 0 { play(.countdown) }
        // idle wobble on the start grid
        for i in 0..<4 {
            racers[i].lean = sin(Float(tick) * 0.1 + Float(i))
        }
        updateCamera(false)
        if phaseT <= 40 && phaseT >= 0 && input.aPressed && !turboWindowUsed {
            turboWindowUsed = true
            racers[0].boostT = 80
            racers[0].speed = 1.6
            bannerText = "TURBO START!"
            bannerT = 70
            play(.powerup)
            flashT = 8
            raceScore += 200
        }
        if phaseT <= 0 {
            phase = .race
            if bannerT <= 0 {
                bannerText = "GO!"
                bannerT = 45
                play(.powerup)
            }
            hintT = 360
            lapStartFrame = 0
        }
    }

    private func updateRace(_ input: InputState) {
        raceT += 1
        if hintT > 0 { hintT -= 1 }
        // player
        var steer: Float = Float(input.dx)
        if ptDown {
            steer = max(-1, min(1, Float(ptX - 160) / 60))
            if abs(steer) < 0.1 { steer = 0 }
        }
        if racers[0].done { steer = 0 }
        let pr = racers[0]
        var airSpin = false
        if pr.z > 1.5 && (input.b || tapSpinT > 0) && !pr.done { airSpin = true }
        if airSpin {
            racers[0].spin += 0.19
        }
        var top: Float = pr.top * ((input.a || ptDown) ? 1.0 : 0.82)
        if pr.done { top = pr.top * 0.6 }
        let touchBrake: Bool = ptDown && ptY > 230
        let brake: Bool = (input.b || touchBrake) && pr.z <= 1.5 && !pr.done
        var boosting = false
        if (input.up || tapBoostT > 0) && meter > 1 && !pr.done {
            boosting = true
            meter = max(0, meter - 0.7)
        }
        // steering help: ease toward the course direction when the D-pad is idle
        if steer == 0 && !ptDown && pr.z <= 1.5 {
            let want: Float = atan2(dirY[pr.seg], dirX[pr.seg])
            let diff: Float = angDiff(want, pr.psi)
            racers[0].psi += max(-0.02, min(0.02, diff * 0.04))
        }
        // drift boost
        if brake && abs(steer) > 0.1 && pr.speed > 1.2 {
            racers[0].driftT += 1
            meter = min(100, meter + 0.28)
            if tick % 2 == 0 {
                spray(160 + steer * -22, 236, 2, 2.2, TrueColorBuffer.rgb(255, 200, 80))
            }
        } else {
            if racers[0].driftT > 50 {
                racers[0].boostT = max(racers[0].boostT, 45)
                bannerText = "DRIFT BOOST!"
                bannerT = 40
                play(.powerup)
                flashT = 5
                raceScore += 150
            }
            racers[0].driftT = 0
        }
        let landed: Bool = stepRacer(0, steer, top, brake, boosting)
        if landed { onPlayerLanded() }
        if pr.z <= 1.5 { racers[0].spin = 0 }
        for i in 1..<4 {
            let rb: Float = rubber(i)
            driveAI(i, racers[i].top * rb)
            _ = moveRacer(i)
        }
        interactObjects()
        collideRacers()
        for i in 0..<4 { trackRacer(i, i == 0) }
        // gentle bounce off the soft boundary is applied inside trackRacer
        updateCamera(false)
        playerFx(input, boosting)
        // cooldowns
        for i in 0..<objs.count where objs[i].cool > 0 {
            objs[i].cool -= 1
        }
        if phase == .finish {
            phaseT += 1
            if phaseT > 170 {
                showResults()
            }
        } else if raceT > 60 * 200 {
            racers[0].done = true
            racers[0].finishFrame = raceT
            beginFinish()
        }
    }

    private func rubber(_ i: Int) -> Float {
        let diff: Float = racers[0].total - racers[i].total
        let span: Float = Float(JetSki64.nSeg) * 0.12
        var rb: Float = diff / span
        rb = max(-1, min(1, rb))
        var k: Float = 0.07
        if course == 1 { k = 0.085 }
        var mul: Float = 1 + rb * k
        if rb < 0 { mul = 1 + rb * 0.05 }
        return mul
    }

    @discardableResult
    private func moveRacer(_ i: Int) -> Bool {
        return stepRacer(i, racers[i].lean, racers[i].top * 0.9, false, false)
    }

    private func driveAI(_ i: Int, _ topSpeed: Float) {
        let n: Int = JetSki64.nSeg
        let seg: Int = racers[i].seg
        let look: Int = (seg + 2) % n
        let nx: Float = -dirY[look]
        let ny: Float = dirX[look]
        let hw: Float = hwArr[look]
        let tx: Float = pts[look * 2] + nx * racers[i].lane * hw
        let ty: Float = pts[look * 2 + 1] + ny * racers[i].lane * hw
        let want: Float = atan2(ty - racers[i].y, tx - racers[i].x)
        let diff: Float = angDiff(want, racers[i].psi)
        let steer: Float = max(-1, min(1, diff / 0.12))
        racers[i].lean = steer
        racers[i].top = max(racers[i].top, 0.5)
        _ = topSpeed
        // the AI steers in stepRacer through lean; speed target stored in aiTarget
        aiTarget[i] = topSpeed
    }

    private var aiTarget: [Float] = [2.2, 2.2, 2.2, 2.2]

    /// Shared physics step. For AI skis `steer` is their lean value and the target speed comes from `aiTarget`.
    @discardableResult
    private func stepRacer(_ i: Int, _ steerIn: Float, _ topIn: Float, _ brake: Bool, _ boosting: Bool) -> Bool {
        var r = racers[i]
        var steer: Float = steerIn
        var top: Float = topIn
        if i != 0 || phase == .title {
            top = aiTarget[i]
        }
        if phase == .title && i == 0 {
            steer = r.lean
        }
        let gid: Int = groundId(r.x, r.y)
        let onLand: Bool = gid >= 3 && gid <= 6 && r.z <= 0.5
        var target: Float = top
        if boosting || r.boostT > 0 {
            target *= 1.38
            if r.boostT > 0 { r.boostT -= 1 }
        }
        if brake { target *= 0.62 }
        if onLand {
            target *= 0.4
            if i == 0 && tick % 3 == 0 {
                spray(160, 236, 2, 2, TrueColorBuffer.rgb(235, 200, 130))
            }
            if i == 0 && hintT < 60 && phase == .race && bannerT <= 0 {
                bannerText = "STAY IN THE WATER!"
                bannerT = 40
            }
        }
        let accel: Float = r.speed < target ? 0.04 : 0.07
        r.speed += (target - r.speed) * accel
        if !r.speed.isFinite { r.speed = 1 }
        let sp01: Float = min(1, r.speed / 1.6)
        var turn: Float = steer * (brake ? 0.052 : 0.036) * (0.35 + 0.65 * sp01)
        if r.z > 1.5 { turn *= 0.35 }
        r.psi += turn
        r.lean += (steer - r.lean) * 0.2
        let fwdX: Float = cos(r.psi)
        let fwdY: Float = sin(r.psi)
        var grip: Float = 0.2
        if brake && abs(steer) > 0.1 { grip = 0.07 }
        if r.z > 1.5 { grip = 0.05 }
        r.vx += (fwdX * r.speed - r.vx) * grip
        r.vy += (fwdY * r.speed - r.vy) * grip
        r.x += r.vx
        r.y += r.vy
        if !r.x.isFinite || !r.y.isFinite {
            r.x = pts[0]
            r.y = pts[1]
            r.vx = 0
            r.vy = 0
        }
        if r.rampCool > 0 { r.rampCool -= 1 }
        if r.bumpCool > 0 { r.bumpCool -= 1 }
        if r.bounceCool > 0 { r.bounceCool -= 1 }
        var landed = false
        if r.z > 0 || r.vz > 0 {
            r.z += r.vz
            r.vz -= 0.14
            if r.z <= 0 {
                r.z = 0
                r.vz = 0
                landed = true
            }
        }
        racers[i] = r
        return landed
    }

    private func onPlayerLanded() {
        let spins: Int = Int(racers[0].spin / (2 * Float.pi) + 0.35)
        racers[0].spin = 0
        shake = 6
        play(.thud)
        spray(160, 236, 18, 3.2, JetSki64.cWhite)
        if spins > 0 {
            tricks += spins
            bestTrick = max(bestTrick, spins)
            let bonus: Int = 300 * spins
            raceScore += bonus
            meter = min(100, meter + 22 * Float(spins))
            racers[0].boostT = max(racers[0].boostT, 30 + spins * 15)
            let label: String = spins == 1 ? "360 TRICK!" : String(spins * 360) + " WOW!"
            bannerText = label
            bannerT = 60
            addText("+" + String(bonus), 160, 150, JetSki64.cYellow)
            play(.win)
            flashT = 6
            for _ in 0..<14 {
                let a: Float = Float(rng.int(628)) / 100
                addSpark(160, 200, cos(a) * 3, sin(a) * 3, 0.05, 24, 3, JetSki64.cYellow)
            }
        }
    }

    private func interactObjects() {
        for i in 0..<racers.count {
            let rx: Float = racers[i].x
            let ry: Float = racers[i].y
            for j in 0..<objs.count {
                let k: Int = objs[j].kind
                if k < JetSki64.kBoost || k > JetSki64.kBump { continue }
                let dx: Float = objs[j].x - rx
                let dy: Float = objs[j].y - ry
                if abs(dx) > 24 || abs(dy) > 24 { continue }
                let d2: Float = dx * dx + dy * dy
                if k == JetSki64.kBoost {
                    if objs[j].cool <= 0 && d2 < 17 * 17 {
                        objs[j].cool = 700
                        racers[i].boostT = max(racers[i].boostT, 60)
                        if i == 0 {
                            meter = min(100, meter + 30)
                            raceScore += 100
                            bannerText = "BOOST!"
                            bannerT = 36
                            addText("+100", 160, 160, JetSki64.cYellow)
                            play(.powerup)
                            flashT = 5
                        }
                    }
                } else if k == JetSki64.kRamp {
                    if racers[i].rampCool <= 0 && racers[i].z <= 0.6 && d2 < 20 * 20 {
                        racers[i].rampCool = 50
                        racers[i].vz = 3.0 + min(1.2, racers[i].speed * 0.25)
                        racers[i].z = 0.5
                        racers[i].spin = 0
                        if i == 0 {
                            play(.jump)
                            if hintT > 0 { hintT = 0 }
                            bannerText = "HOLD B TO SPIN!"
                            bannerT = 50
                        }
                    }
                } else {
                    if racers[i].bumpCool <= 0 && racers[i].z <= 0.6 && d2 < 16 * 16 {
                        racers[i].bumpCool = 40
                        racers[i].vz = 1.5
                        racers[i].z = 0.5
                        if i == 0 {
                            play(.bounce)
                            spray(160, 236, 10, 2.6, JetSki64.cWhite)
                        }
                    }
                }
            }
        }
    }

    private func collideRacers() {
        for i in 0..<racers.count {
            for j in (i + 1)..<racers.count where j < racers.count {
                if abs(racers[i].z - racers[j].z) > 6 { continue }
                let dx: Float = racers[j].x - racers[i].x
                let dy: Float = racers[j].y - racers[i].y
                let d2: Float = dx * dx + dy * dy
                if d2 < 11 * 11 && d2 > 0.01 {
                    let d: Float = sqrt(d2)
                    let push: Float = (11 - d) * 0.5
                    let ux: Float = dx / d
                    let uy: Float = dy / d
                    racers[i].x -= ux * push
                    racers[i].y -= uy * push
                    racers[j].x += ux * push
                    racers[j].y += uy * push
                    if i == 0 && racers[0].bounceCool <= 0 {
                        racers[0].bounceCool = 20
                        shake = 5
                        play(.bounce)
                        spray(160, 232, 8, 2.4, JetSki64.cCyan)
                    }
                }
            }
        }
    }

    private func trackRacer(_ i: Int, _ events: Bool) {
        var r = racers[i]
        let n: Int = JetSki64.nSeg
        var best: Float = 1e12
        var bs: Int = r.seg
        var bt: Float = 0
        var bl: Float = 0
        for k in -2...8 {
            let s: Int = ((r.seg + k) % n + n) % n
            let s2: Int = (s + 1) % n
            let ax: Float = pts[s * 2]
            let ay: Float = pts[s * 2 + 1]
            let ex: Float = pts[s2 * 2] - ax
            let ey: Float = pts[s2 * 2 + 1] - ay
            let len2: Float = max(0.001, ex * ex + ey * ey)
            var t: Float = ((r.x - ax) * ex + (r.y - ay) * ey) / len2
            t = max(0, min(1, t))
            let px: Float = ax + ex * t
            let py: Float = ay + ey * t
            let dx: Float = r.x - px
            let dy: Float = r.y - py
            let d2: Float = dx * dx + dy * dy
            if d2 < best {
                best = d2
                bs = s
                bt = t
                bl = dx * (-dirY[s]) + dy * dirX[s]
            }
        }
        var crossed = false
        if r.seg >= n - 6 && bs <= 5 {
            r.lapIdx += 1
            crossed = true
        } else if r.seg <= 5 && bs >= n - 6 {
            r.lapIdx -= 1
            if r.lapIdx < -1 { r.lapIdx = -1 }
        }
        r.seg = bs
        r.segT = bt
        r.lat = bl
        // soft boundary
        let lim: Float = hwArr[bs] + 46
        if abs(bl) > lim {
            let ex: Float = abs(bl) - lim
            let sg: Float = bl > 0 ? 1 : -1
            r.x -= (-dirY[bs]) * sg * ex
            r.y -= dirX[bs] * sg * ex
            r.speed *= 0.9
            r.vx *= 0.8
            r.vy *= 0.8
            if i == 0 && r.bounceCool <= 0 {
                r.bounceCool = 20
                shake = 6
                play(.thud)
            }
        }
        r.total = Float(r.lapIdx) * Float(n) + Float(bs) + bt
        if crossed && phase != .title && !r.done {
            if r.lapIdx >= JetSki64.totalLaps {
                r.done = true
                r.finishFrame = raceT
                racers[i] = r
                if i == 0 { beginFinish() }
                return
            }
            if i == 0 && events && r.lapIdx >= 0 {
                let lapTime: Int = raceT - lapStartFrame
                if bestLap == 0 || lapTime < bestLap { bestLap = lapTime }
                lapStartFrame = raceT
                if r.lapIdx == JetSki64.totalLaps - 1 {
                    bannerText = "FINAL LAP!"
                    play(.confirm)
                } else {
                    bannerText = "LAP " + String(r.lapIdx + 1)
                    play(.pickup)
                }
                bannerT = 70
            }
        }
        racers[i] = r
    }

    private func beginFinish() {
        if phase == .finish { return }
        phase = .finish
        phaseT = 0
        finalPlace = placeOf(0)
        bannerText = finalPlace == 1 ? "YOU WIN!" : "FINISH!"
        bannerT = 150
        flashT = 10
        if finalPlace <= 3 { play(.win) } else { play(.lose) }
    }

    private func showResults() {
        let ranked: [Int] = [0, 1, 2, 3].sorted { rankValue($0) > rankValue($1) }
        results = ranked
        var pl = 4
        for (i, idx) in ranked.enumerated() where idx == 0 { pl = i + 1 }
        finalPlace = pl
        let bonuses: [Int] = [5000, 3000, 1500, 500]
        placeBonus = bonuses[max(0, min(3, pl - 1))]
        finalStars = 1
        if pl <= 3 { finalStars += 1 }
        if pl == 1 { finalStars += 1 }
        if pl <= 3 && course == 0 && !unlocked2 {
            unlocked2 = true
            justUnlocked = true
        } else {
            justUnlocked = false
        }
        phase = .results
        phaseT = 0
        if pl == 1 { play(.win) }
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

    private func playerFx(_ input: InputState, _ boosting: Bool) {
        let r = racers[0]
        if r.z <= 1 && r.speed > 0.8 && tick % 2 == 0 {
            let amt: Int = r.boostT > 0 || boosting ? 3 : 1
            let col: UInt32 = r.boostT > 0 || boosting ? JetSki64.cYellow : JetSki64.cWhite
            spray(160, 240, amt, 1.8 + r.speed * 0.4, col)
        }
        if boosting && tick % 3 == 0 {
            flashT = max(flashT, 1)
        }
    }

    private func updateCamera(_ snap: Bool) {
        let r = racers[0]
        if snap {
            camAng = r.psi
        } else {
            camAng += angDiff(r.psi, camAng) * 0.12
        }
        camX = r.x - cos(camAng) * 38
        camY = r.y - sin(camAng) * 38
        let want: Float = 26 + r.z * 0.35
        camH += (want - camH) * 0.2
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

    private func sparkle(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int, _ r: Int, _ c: UInt32) {
        if r <= 0 { return }
        if cx + r < 0 || cx - r >= 320 || cy + r < 0 || cy - r >= 288 { return }
        let rr: Int = min(r, 200)
        for dy in -rr...rr {
            let t: Float = Float(abs(dy)) / Float(rr)
            let hwf: Float = Float(rr) * (1 - t) * (1 - t * 0.55)
            let hw: Int = Int(hwf + 0.5)
            b.fillRect(cx - hw, cy + dy, hw * 2 + 1, 1, c)
        }
    }

    private func shadowText(_ b: TrueColorBuffer, _ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        b.text(s, x + scale, y + scale, JetSki64.cBlack, scale: scale)
        b.text(s, x, y, c, scale: scale)
    }

    private func ctext(_ b: TrueColorBuffer, _ s: String, _ y: Int, _ c: UInt32, _ scale: Int) {
        let x: Int = (320 - b.textWidth(s, scale: scale)) / 2
        shadowText(b, s, x, y, c, scale)
    }

    private func panel(_ b: TrueColorBuffer, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        b.fillRect(x, y, w, h, JetSki64.cBlack)
        b.fillRect(x + 2, y + 2, w - 4, h - 4, JetSki64.cPanel)
        b.fillRect(x + 2, y + 2, w - 4, 2, TrueColorBuffer.rgb(70, 140, 230))
    }

    // MARK: - Projection

    private func project(_ wx: Float, _ wy: Float) -> (Bool, Int, Int, Float, Float) {
        let fwdX: Float = cos(camAng)
        let fwdY: Float = sin(camAng)
        let rx: Float = wx - camX
        let ry: Float = wy - camY
        let z: Float = rx * fwdX + ry * fwdY
        if z < 18 || z > 760 { return (false, 0, 0, 0, z) }
        let lat: Float = -rx * fwdY + ry * fwdX
        let sc: Float = JetSki64.focal / z
        let sxf: Float = 160 + lat * sc
        let syf: Float = Float(hzCur) + camH * sc
        if sxf < -700 || sxf > 1020 || syf < -300 || syf > 1200 { return (false, 0, 0, 0, z) }
        return (true, Int(sxf), Int(syf), sc, z)
    }

    // MARK: - Draw entry

    override func drawTrueColor(_ b: TrueColorBuffer) {
        drawWorld(b)
        drawSparks(b)
        if phase == .race || phase == .finish || phase == .ready {
            drawHUD(b)
        }
        drawOverlays(b)
    }

    private func drawSparks(_ b: TrueColorBuffer) {
        for s in sparks {
            let sz: Int = max(1, s.size * s.life / max(1, s.maxLife) + 1)
            b.fillRect(Int(s.x), Int(s.y), sz, sz, s.col)
        }
    }

    private func drawWorld(_ b: TrueColorBuffer) {
        var hz: Int = 100
        if shake > 0 { hz += (tick & 1) == 0 ? 2 : -2 }
        let pz: Float = racers.isEmpty ? 0 : racers[0].z
        hz += Int(min(20, pz * 0.25))
        hzCur = hz
        let fwdX: Float = cos(camAng)
        let fwdY: Float = sin(camAng)
        let rightX: Float = -fwdY
        let rightY: Float = fwdX
        let cH: Float = camH
        let cX: Float = camX
        let cY: Float = camY
        let t1: Int = (tick * 2) & 255
        let t2: Int = (tick * 3) & 255
        b.withPixels { p, w, h in
            if w < 320 || h < 288 { return }
            let sky = JetSki64.skyLut
            let tex = self.map
            let lut = JetSki64.groundLut
            let sinT = JetSki64.sinT
            let haze = JetSki64.hazeCol
            let top: Int = min(hz, h)
            for y in 0..<top {
                let li: Int = min(63, y * 63 / max(1, hz))
                let c: UInt32 = sky[li]
                let base: Int = y * w
                for x in 0..<w { p[base + x] = c }
            }
            if hz >= h { return }
            for y in hz..<h {
                let dy: Int = y - hz
                let base: Int = y * w
                if dy == 0 {
                    for x in 0..<w { p[base + x] = haze }
                    continue
                }
                let dist: Float = cH * JetSki64.focal / Float(dy)
                if dist > 760 {
                    for x in 0..<w { p[base + x] = haze }
                    continue
                }
                var fl: Int = Int(dist / 66)
                if fl > 11 { fl = 11 }
                if fl < 0 { fl = 0 }
                let k: Float = dist / JetSki64.focal * 0.5
                var wx: Float = (cX + fwdX * dist) * 0.5 - rightX * k * 160
                var wy: Float = (cY + fwdY * dist) * 0.5 - rightY * k * 160
                let stx: Float = rightX * k
                let sty: Float = rightY * k
                let lb: Int = fl * 20
                for x in 0..<w {
                    var u: Int = Int(wx) & 511
                    var v: Int = Int(wy) & 511
                    var id: Int = Int(tex[(v << 9) | u])
                    if id < 3 {
                        let warp: Int = sinT[(v * 3 + t1) & 255] >> 4
                        let warp2: Int = sinT[(u * 3 + t2) & 255] >> 4
                        u = (u + warp) & 511
                        v = (v + warp2) & 511
                        id = Int(tex[(v << 9) | u])
                    }
                    if id < 3 {
                        let wv: Int = sinT[(u * 5 + t1) & 255] + sinT[(v * 5 + 256 - t2) & 255]
                        var lv: Int = (wv + 64) >> 5
                        if lv < 0 { lv = 0 }
                        if lv > 3 { lv = 3 }
                        p[base + x] = lut[lb + id * 4 + lv]
                    } else {
                        p[base + x] = lut[lb + id + 9]
                    }
                    wx += stx
                    wy += sty
                }
            }
        }
        drawHorizon(b, hz)

        // billboards
        drawList.removeAll()
        for i in 0..<objs.count {
            if objs[i].cool > 0 && (objs[i].kind == JetSki64.kBoost) { continue }
            let pr = project(objs[i].x, objs[i].y)
            if pr.0 {
                var di = DrawItem()
                di.z = pr.4
                di.kind = 0
                di.idx = i
                di.sx = pr.1
                di.sy = pr.2
                di.sc = pr.3
                drawList.append(di)
            }
        }
        for i in 1..<racers.count {
            let pr = project(racers[i].x, racers[i].y)
            if pr.0 {
                var di = DrawItem()
                di.z = pr.4
                di.kind = 1
                di.idx = i
                di.sx = pr.1
                di.sy = pr.2
                di.sc = pr.3
                drawList.append(di)
            }
        }
        var pd = DrawItem()
        pd.z = 38
        pd.kind = 2
        drawList.append(pd)
        drawList.sort { $0.z > $1.z }
        for di in drawList {
            if di.kind == 0 {
                drawObject(b, di)
            } else if di.kind == 1 {
                drawRival(b, di)
            } else {
                drawPlayer(b)
            }
        }
    }

    private func drawHorizon(_ b: TrueColorBuffer, _ hz: Int) {
        // distant islands as a silhouette strip that slides with the camera heading
        let ridge: UInt32 = TrueColorBuffer.rgb(110, 60, 140)
        let beach: UInt32 = TrueColorBuffer.rgb(255, 225, 150)
        var x = 0
        while x < 320 {
            let a: Float = camAng + Float(x - 160) / 230
            let h1: Float = 9 * sin(a * 3 + 0.5) + 6 * sin(a * 7 + 1.3) + 3 * sin(a * 13)
            let hh: Int = Int(max(0, h1 + 7))
            if hh > 0 {
                b.fillRect(x, hz - hh, 4, hh, ridge)
                if hh > 4 { b.fillRect(x, hz - hh, 4, 2, TrueColorBuffer.rgb(140, 80, 160)) }
            }
            b.fillRect(x, hz - 1, 4, 2, beach)
            x += 4
        }
        // sun
        let sunDx: Int = Int(angDiff(2.2, camAng) * 230)
        let sx: Int = 160 + sunDx
        if sx > -60 && sx < 380 {
            disc(b, sx, hz - 6, 30, TrueColorBuffer.rgb(255, 170, 120))
            disc(b, sx, hz - 6, 22, TrueColorBuffer.rgb(255, 205, 130))
            disc(b, sx, hz - 6, 16, TrueColorBuffer.rgb(255, 245, 190))
            b.fillRect(sx - 40, hz - 1, 80, 2, TrueColorBuffer.rgb(255, 230, 160))
        }
        // lighthouse
        let lx: Int = 160 + Int(angDiff(-0.9, camAng) * 230)
        if lx > -30 && lx < 350 {
            for i in 0..<30 {
                let hw: Int = 5 - i / 9
                let c: UInt32 = (i / 4) % 2 == 0 ? JetSki64.cRed : JetSki64.cWhite
                b.fillRect(lx - hw, hz - 8 - i, hw * 2 + 1, 1, c)
            }
            b.fillRect(lx - 4, hz - 42, 9, 4, JetSki64.cBlack)
            let blink: Bool = (tick / 20) % 2 == 0
            disc(b, lx, hz - 46, 4, blink ? JetSki64.cYellow : TrueColorBuffer.rgb(255, 245, 190))
            if blink {
                b.fillRect(lx - 22, hz - 47, 44, 2, TrueColorBuffer.rgb(255, 240, 160))
            }
            b.fillRect(lx - 7, hz - 8, 15, 8, TrueColorBuffer.rgb(255, 225, 150))
        }
    }

    // MARK: - Object sprites

    private func drawObject(_ b: TrueColorBuffer, _ di: DrawItem) {
        let o = objs[di.idx]
        let x: Int = di.sx
        let y: Int = di.sy
        let sc: Float = di.sc
        switch o.kind {
        case JetSki64.kPalm:
            let h: Int = Int(max(4, min(420, 46 * sc)))
            let tw: Int = max(2, Int(3.5 * sc))
            let lean: Int = (o.variant - 1) * max(1, h / 12)
            b.fillRect(x - tw / 2, y - h / 2, tw, h / 2, TrueColorBuffer.rgb(140, 95, 55))
            b.fillRect(x - tw / 2 + lean / 2, y - h, tw, h / 2, TrueColorBuffer.rgb(165, 115, 65))
            let tx: Int = x + lean
            let ty: Int = y - h
            let fr: Int = max(3, h * 2 / 5)
            let g1: UInt32 = TrueColorBuffer.rgb(40, 185, 70)
            let g2: UInt32 = TrueColorBuffer.rgb(80, 225, 90)
            ell(b, tx - fr * 2 / 3, ty + fr / 8, fr, max(1, fr / 4), g1)
            ell(b, tx + fr * 2 / 3, ty + fr / 8, fr, max(1, fr / 4), g1)
            ell(b, tx - fr / 3, ty - fr / 6, fr * 2 / 3, max(1, fr / 4), g2)
            ell(b, tx + fr / 3, ty - fr / 6, fr * 2 / 3, max(1, fr / 4), g2)
            disc(b, tx, ty - fr / 8, max(1, fr / 6), TrueColorBuffer.rgb(130, 80, 40))
            disc(b, tx - fr / 8, ty + fr / 12, max(1, fr / 8), TrueColorBuffer.rgb(110, 65, 30))
        case JetSki64.kRed, JetSki64.kWhite:
            let h: Int = Int(max(3, min(300, 15 * sc)))
            let w: Int = max(2, h / 3)
            let base: UInt32 = o.kind == JetSki64.kRed ? JetSki64.cRed : JetSki64.cWhite
            ell(b, x, y, w + 1, max(1, w / 3), TrueColorBuffer.rgb(0, 100, 200))
            ell(b, x, y - h / 2, w, h / 2, base)
            if o.kind == JetSki64.kRed {
                b.fillRect(x - w + 1, y - h / 2 - h / 8, w * 2 - 1, max(1, h / 5), JetSki64.cWhite)
            } else {
                b.fillRect(x - w + 1, y - h / 2 - h / 8, w * 2 - 1, max(1, h / 5), JetSki64.cRed)
            }
            let lamp: UInt32 = ((tick / 15) & 1) == 0 ? JetSki64.cYellow : base
            disc(b, x, y - h - h / 8, max(1, w / 3), lamp)
        case JetSki64.kBoost:
            let h: Int = Int(max(4, min(300, 22 * sc)))
            let w: Int = max(3, h * 2 / 5)
            ell(b, x, y, w + 2, max(1, w / 3), TrueColorBuffer.rgb(255, 255, 255))
            ell(b, x, y - h / 2, w, h / 2, TrueColorBuffer.rgb(255, 190, 20))
            ell(b, x, y - h / 2, w * 2 / 3, h / 3, JetSki64.cYellow)
            // chevron arrow
            let cw: Int = max(1, w / 4)
            b.fillRect(x - w / 2, y - h / 2, w, cw, TrueColorBuffer.rgb(255, 110, 20))
            b.fillRect(x - w / 4, y - h / 2 - cw * 2, w / 2, cw, TrueColorBuffer.rgb(255, 110, 20))
            if (tick / 6 + di.idx) % 3 == 0 {
                sparkle(b, x + w, y - h, max(2, w / 2), JetSki64.cWhite)
            }
        case JetSki64.kRamp:
            let h: Int = Int(max(3, min(300, 15 * sc)))
            let w: Int = Int(max(6, min(500, 24 * sc)))
            // wedge: narrow top, wide base with stripes
            for i in 0..<h {
                let t: Float = Float(i) / Float(max(1, h))
                let hw: Int = Int(Float(w) * (0.45 + t * 0.55))
                let c: UInt32 = (i / max(1, h / 4)) % 2 == 0 ? JetSki64.cYellow : TrueColorBuffer.rgb(255, 120, 40)
                b.fillRect(x - hw, y - h + i, hw * 2 + 1, 1, c)
            }
            b.fillRect(x - w, y - 1, w * 2 + 1, max(1, h / 8), TrueColorBuffer.rgb(255, 255, 255))
            ell(b, x, y + 1, w + 2, max(1, h / 6), TrueColorBuffer.rgb(255, 255, 255))
        case JetSki64.kBump:
            let h: Int = Int(max(2, min(200, 9 * sc)))
            let w: Int = Int(max(5, min(500, 20 * sc)))
            ell(b, x, y, w, h, TrueColorBuffer.rgb(40, 200, 235))
            ell(b, x, y - h / 4, w * 3 / 4, h * 2 / 3, TrueColorBuffer.rgb(120, 235, 245))
            ell(b, x, y - h / 2, w / 2, max(1, h / 3), JetSki64.cWhite)
        case JetSki64.kSign:
            let h: Int = Int(max(6, min(400, 30 * sc)))
            let w: Int = max(4, h / 2)
            b.fillRect(x - max(1, w / 12), y - h, max(2, w / 6), h, TrueColorBuffer.rgb(120, 80, 50))
            b.fillRect(x - w, y - h - w, w * 2, w + w / 2, JetSki64.cBlack)
            b.fillRect(x - w + 2, y - h - w + 2, w * 2 - 4, w + w / 2 - 4, JetSki64.cYellow)
            let aw: Int = max(1, w / 4)
            b.fillRect(x - w / 2, y - h - w / 2 - aw / 2, w, aw, JetSki64.cRed)
            b.fillRect(x + w / 4, y - h - w + aw, aw, w - aw, JetSki64.cRed)
            if sc > 1.2 {
                let t: String = "SHORTCUT"
                shadowText(b, t, x - b.textWidth(t) / 2, y - h - w * 2 - 6, JetSki64.cYellow, 1)
            }
        default:
            let h: Int = Int(max(3, min(300, 14 * sc)))
            let w: Int = max(2, h / 3)
            ell(b, x, y, w + 1, max(1, w / 3), TrueColorBuffer.rgb(0, 100, 200))
            ell(b, x, y - h / 2, w, h / 2, JetSki64.cYellow)
            ell(b, x, y - h / 2, max(1, w / 2), h / 3, TrueColorBuffer.rgb(255, 150, 30))
        }
    }

    /// Cartoon jet-ski with a kid rider, drawn from behind. `cosSp` squashes the width for the spin trick.
    private func drawSki(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int, _ s: Float, _ yaw: Float, _ lean: Float,
                         _ cosSp: Float, _ ci: Int, _ boost: Bool) {
        let main: UInt32 = JetSki64.skiMain[ci & 3]
        let acc: UInt32 = JetSki64.skiAccent[ci & 3]
        let hel: UInt32 = JetSki64.helmetCol[ci & 3]
        let shirt: UInt32 = JetSki64.shirtCol[ci & 3]
        let dark: UInt32 = TrueColorBuffer.rgb(40, 40, 70)
        let wsq: Float = max(0.22, abs(cosSp))
        func e(_ dx: Float, _ dy: Float, _ rx: Float, _ ry: Float, _ c: UInt32) {
            let px: Int = cx + Int(dx * cosSp * s)
            let py: Int = cy + Int(dy * s)
            let rxi: Int = max(1, Int(rx * wsq * s))
            let ryi: Int = max(1, Int(ry * s))
            self.ell(b, px, py, rxi, ryi, c)
        }
        if boost {
            e(0, 5, 14, 5, JetSki64.cOrange)
            e(0, 6, 9, 4, JetSki64.cYellow)
        }
        e(0, 1, 22, 7, dark)
        e(0, -2, 20, 8, main)
        e(0, 0, 18, 3, acc)
        e(0, -3, 12, 3, JetSki64.cWhite)
        e(yaw * 10, -9, 10, 5, main)
        e(yaw * 10, -9, 6, 2, acc)
        e(yaw * 10, -15, 6, 4, TrueColorBuffer.rgb(150, 235, 255))
        e(0, -9, 11, 4, dark)
        e(yaw * 8, -17, 11, 2, dark)
        e(-5, -8, 3, 5, TrueColorBuffer.rgb(40, 100, 220))
        e(5, -8, 3, 5, TrueColorBuffer.rgb(40, 100, 220))
        e(lean * 6, -19, 7, 9, shirt)
        e(lean * 6, -18, 3, 4, JetSki64.cWhite)
        e(lean * 6 - 9, -18, 3, 6, JetSki64.cSkin)
        e(lean * 6 + 9, -18, 3, 6, JetSki64.cSkin)
        e(lean * 9, -33, 7, 7, TrueColorBuffer.rgb(120, 70, 30))
        e(lean * 9, -35, 8, 7, hel)
        e(lean * 9, -36, 2, 7, JetSki64.cWhite)
        e(lean * 9, -42, 2, 2, JetSki64.cYellow)
    }

    private func drawPlayer(_ b: TrueColorBuffer) {
        let r = racers[0]
        var cx: Int = 160
        let bob: Float = sin(Float(tick) * 0.2) * 1.5
        var cy: Int = 236 - Int(r.z * 1.3 + bob)
        if shake > 0 { cy += (tick & 1) == 0 ? 2 : -2 }
        let yaw: Float = max(-1, min(1, angDiff(r.psi, camAng) * 3))
        cx += Int(yaw * 6)
        // shadow and wake stay on the water
        let sh: Int = Int(max(4, 22 - r.z * 0.5))
        ell(b, 160, 240, sh, max(2, sh / 4), TrueColorBuffer.rgb(0, 80, 170))
        // foamy wake
        let sp: Float = min(1, r.speed / 2.5)
        for i in 0..<5 {
            let yy: Int = 244 + i * 9
            let spread: Int = Int((10 + Float(i) * 12) * (0.4 + sp * 0.6))
            let wob: Int = ((tick / 4 + i) & 1) * 2
            let fc: UInt32 = i % 2 == 0 ? JetSki64.cWhite : TrueColorBuffer.rgb(190, 240, 255)
            if r.z < 4 {
                ell(b, 160 - spread - wob, yy, max(2, 8 - i), max(1, 3 - i / 2), fc)
                ell(b, 160 + spread + wob, yy, max(2, 8 - i), max(1, 3 - i / 2), fc)
                ell(b, 160, yy - 2, max(3, 10 - i), 2, fc)
            }
        }
        let boosting: Bool = r.boostT > 0
        drawSki(b, cx, cy, 1.15, yaw, r.lean, cos(r.spin), 0, boosting)
    }

    private func drawRival(_ b: TrueColorBuffer, _ di: DrawItem) {
        let r = racers[di.idx]
        let s: Float = max(0.12, min(2.2, di.sc * 0.3))
        let rw: Int = Int(24 * s)
        ell(b, di.sx, di.sy, rw, max(1, rw / 4), TrueColorBuffer.rgb(0, 80, 170))
        // wake behind
        ell(b, di.sx, di.sy + max(1, rw / 5), rw * 3 / 4, max(1, rw / 5), JetSki64.cWhite)
        let yaw: Float = max(-1, min(1, angDiff(r.psi, camAng) * 3))
        let yy: Int = di.sy - Int(r.z * di.sc * 0.8) - Int(10 * s)
        drawSki(b, di.sx, yy, s, yaw, r.lean, 1, r.col, r.boostT > 0)
    }

    // MARK: - HUD

    private func drawHUD(_ b: TrueColorBuffer) {
        let pl: Int = placeOf(0)
        let names: [String] = ["1ST", "2ND", "3RD", "4TH"]
        let pc: [UInt32] = [JetSki64.cYellow, TrueColorBuffer.rgb(210, 225, 245), TrueColorBuffer.rgb(255, 170, 100), JetSki64.cWhite]
        panel(b, 4, 4, 70, 32)
        shadowText(b, names[max(0, min(3, pl - 1))], 10, 10, pc[max(0, min(3, pl - 1))], 4)
        let lap: Int = max(1, min(JetSki64.totalLaps, racers[0].lapIdx + 1))
        let ls: String = "LAP " + String(lap) + "/" + String(JetSki64.totalLaps)
        panel(b, 120, 4, 80, 20)
        b.text(ls, 160 - b.textWidth(ls, scale: 2) / 2, 9, JetSki64.cWhite, scale: 2)
        let ts: String = fmtTime(raceT)
        b.text(ts, 160 - b.textWidth(ts) / 2, 27, JetSki64.cWhite, scale: 1)
        // boost meter
        panel(b, 4, 252, 108, 32)
        b.fillRect(10, 270, 96, 8, TrueColorBuffer.rgb(30, 40, 90))
        let mf: Int = Int(max(0, min(1, meter / 100)) * 96)
        let mc: UInt32 = racers[0].boostT > 0 ? JetSki64.cYellow : JetSki64.cOrange
        b.fillRect(10, 270, mf, 8, mc)
        b.fillRect(10, 270, mf, 2, JetSki64.cWhite)
        b.text("BOOST  UP", 10, 258, JetSki64.cWhite, scale: 1)
        // speed readout
        let kmh: Int = Int(racers[0].speed * 52)
        shadowText(b, String(kmh) + " KMH", 10, 240, JetSki64.cCyan, 1)
        drawMinimap(b)
    }

    private func drawMinimap(_ b: TrueColorBuffer) {
        let ox: Int = 282
        let oy: Int = 66
        b.fillRect(ox - 36, oy - 36, 72, 72, JetSki64.cBlack)
        b.fillRect(ox - 34, oy - 34, 68, 68, TrueColorBuffer.rgb(30, 110, 200))
        let sc: Float = 0.082
        let n: Int = JetSki64.nSeg
        for k in 0..<n {
            let px: Int = ox + Int((pts[k * 2] - 512) * sc)
            let py: Int = oy + Int((pts[k * 2 + 1] - 512) * sc)
            b.fillRect(px - 2, py - 2, 5, 5, TrueColorBuffer.rgb(120, 225, 245))
        }
        let sa: Int = JetSki64.shortA
        let sb: Int = JetSki64.shortB
        let ax: Int = ox + Int((pts[sa * 2] - 512) * sc)
        let ay: Int = oy + Int((pts[sa * 2 + 1] - 512) * sc)
        let bx: Int = ox + Int((pts[sb * 2] - 512) * sc)
        let by: Int = oy + Int((pts[sb * 2 + 1] - 512) * sc)
        for q in 0..<6 {
            let t: Float = Float(q) / 5
            let px: Int = ax + Int(Float(bx - ax) * t)
            let py: Int = ay + Int(Float(by - ay) * t)
            b.fillRect(px, py, 2, 2, JetSki64.cYellow)
        }
        b.fillRect(ox + Int((pts[0] - 512) * sc) - 3, oy + Int((pts[1] - 512) * sc) - 1, 7, 2, JetSki64.cWhite)
        let order: [Int] = [3, 2, 1, 0]
        for i in order {
            let px: Int = ox + Int((racers[i].x - 512) * sc)
            let py: Int = oy + Int((racers[i].y - 512) * sc)
            let c: UInt32 = JetSki64.skiMain[i & 3]
            if i == 0 {
                b.fillRect(px - 3, py - 3, 7, 7, JetSki64.cWhite)
                b.fillRect(px - 2, py - 2, 5, 5, c)
            } else {
                b.fillRect(px - 2, py - 2, 5, 5, JetSki64.cBlack)
                b.fillRect(px - 1, py - 1, 3, 3, c)
            }
        }
    }

    // MARK: - Overlays

    private func drawOverlays(_ b: TrueColorBuffer) {
        // speed lines when boosting
        let boosting: Bool = !racers.isEmpty && racers[0].boostT > 0
        if boosting && (phase == .race || phase == .finish) {
            for i in 0..<10 {
                let ph: Int = (tick * 9 + i * 37) % 120
                let side: Int = i % 2 == 0 ? 0 : 1
                let x: Int = side == 0 ? 6 + (i * 13) % 50 : 314 - (i * 13) % 50
                b.fillRect(x, 60 + ph * 2, 2, 18, JetSki64.cWhite)
            }
        }
        for t in texts {
            let w: Int = b.textWidth(t.text, scale: 2)
            shadowText(b, t.text, t.x - w / 2, Int(t.y), t.col, 2)
        }
        if flashT > 0 {
            let th: Int = min(26, flashT * 3)
            let c: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
            b.fillRect(0, 0, 320, th / 2, c)
            b.fillRect(0, 288 - th / 2, 320, th / 2, c)
        }
        if bannerT > 0 && (phase == .race || phase == .finish || phase == .ready) {
            let col: UInt32 = (tick / 4) % 2 == 0 ? JetSki64.cYellow : JetSki64.cWhite
            ctext(b, bannerText, 70, col, 3)
        }
        switch phase {
        case .title:
            drawTitle(b)
        case .ready:
            drawReady(b)
        case .race:
            if hintT > 200 {
                panel(b, 30, 196, 260, 34)
                ctext(b, "TOUCH TO STEER  LOW SCREEN BRAKES  TAP AIR SPINS", 203, JetSki64.cWhite, 1)
                ctext(b, "TAP BOOST METER OR UP FOR BOOST", 215, JetSki64.cYellow, 1)
            } else if hintT > 0 {
                ctext(b, "HIT RAMPS AND HOLD B TO SPIN", 200, JetSki64.cWhite, 1)
            }
        case .finish:
            break
        case .results:
            drawResults(b)
        }
    }

    private func drawTitle(_ b: TrueColorBuffer) {
        panel(b, 24, 20, 272, 96)
        ctext(b, "JET SKI", 30, JetSki64.cYellow, 5)
        ctext(b, "64", 72, JetSki64.cPink, 4)
        ctext(b, "SUNSET ISLAND RACE", 106, JetSki64.cCyan, 1)
        // circuit select
        let nm: String = JetSki64.courseNames[course]
        panel(b, 50, 124, 220, 34)
        ctext(b, "CIRCUIT " + String(course + 1) + "  " + nm, 131, JetSki64.cWhite, 1)
        if lockedMsgT > 0 {
            ctext(b, "FINISH TOP 3 TO UNLOCK CIRCUIT 2", 144, JetSki64.cRed, 1)
        } else {
            ctext(b, unlocked2 ? "LEFT RIGHT CHANGE CIRCUIT" : "CIRCUIT 2 LOCKED - FINISH TOP 3", 144, JetSki64.cYellow, 1)
        }
        if (tick / 30) % 2 == 0 {
            ctext(b, "PRESS A", 190, JetSki64.cWhite, 3)
        }
        panel(b, 40, 226, 240, 40)
        ctext(b, "3 LAPS  3 RIVALS  RAMPS  TRICKS", 233, JetSki64.cWhite, 1)
        ctext(b, "A GAS  B BRAKE  UP BOOST", 245, JetSki64.cYellow, 1)
        ctext(b, "HOLD B IN THE AIR TO SPIN", 255, JetSki64.cPink, 1)
    }

    private func drawReady(_ b: TrueColorBuffer) {
        var s = "3"
        if phaseT <= 5 {
            s = "GO"
        } else if phaseT <= 70 {
            s = "1"
        } else if phaseT <= 135 {
            s = "2"
        }
        let col: UInt32 = s == "GO" ? JetSki64.cGreen : JetSki64.cYellow
        ctext(b, s, 70, col, 9)
        panel(b, 40, 196, 240, 44)
        ctext(b, "GET READY  " + JetSki64.courseNames[course], 203, JetSki64.cWhite, 1)
        ctext(b, "TAP A ON 1 FOR A TURBO START", 215, JetSki64.cYellow, 1)
        ctext(b, "A GAS  B BRAKE  UP BOOST", 227, JetSki64.cCyan, 1)
    }

    private func drawCup(_ b: TrueColorBuffer, _ cx: Int, _ cy: Int, _ place: Int) {
        var gold: UInt32 = TrueColorBuffer.rgb(255, 210, 40)
        var dk: UInt32 = TrueColorBuffer.rgb(215, 150, 20)
        if place == 2 {
            gold = TrueColorBuffer.rgb(215, 225, 240)
            dk = TrueColorBuffer.rgb(150, 165, 190)
        } else if place == 3 {
            gold = TrueColorBuffer.rgb(225, 140, 70)
            dk = TrueColorBuffer.rgb(165, 95, 45)
        }
        if place >= 4 {
            // rosette ribbon for finishing
            disc(b, cx, cy, 18, TrueColorBuffer.rgb(60, 150, 255))
            disc(b, cx, cy, 12, TrueColorBuffer.rgb(255, 255, 255))
            disc(b, cx, cy, 7, TrueColorBuffer.rgb(255, 90, 130))
            b.fillRect(cx - 12, cy + 16, 8, 16, TrueColorBuffer.rgb(60, 150, 255))
            b.fillRect(cx + 4, cy + 16, 8, 16, TrueColorBuffer.rgb(255, 90, 130))
            return
        }
        ell(b, cx - 24, cy - 6, 8, 11, dk)
        ell(b, cx + 24, cy - 6, 8, 11, dk)
        ell(b, cx - 24, cy - 6, 4, 7, JetSki64.cPanel)
        ell(b, cx + 24, cy - 6, 4, 7, JetSki64.cPanel)
        ell(b, cx, cy - 4, 22, 22, dk)
        b.fillRect(cx - 22, cy - 28, 44, 24, gold)
        ell(b, cx, cy - 4, 20, 20, gold)
        ell(b, cx, cy - 28, 22, 5, dk)
        ell(b, cx, cy - 28, 18, 3, TrueColorBuffer.rgb(255, 250, 210))
        b.fillRect(cx - 4, cy + 14, 8, 12, dk)
        b.fillRect(cx - 18, cy + 26, 36, 8, gold)
        b.fillRect(cx - 18, cy + 32, 36, 3, dk)
        sparkle(b, cx - 8, cy - 12, 9, TrueColorBuffer.rgb(255, 255, 255))
        if (tick / 8) % 3 == 0 {
            sparkle(b, cx + 26, cy - 26, 6, TrueColorBuffer.rgb(255, 255, 220))
        }
    }

    private func drawResults(_ b: TrueColorBuffer) {
        panel(b, 20, 12, 280, 264)
        ctext(b, "RACE RESULTS", 20, JetSki64.cYellow, 2)
        ctext(b, JetSki64.courseNames[course], 40, JetSki64.cCyan, 1)
        drawCup(b, 70, 86, finalPlace)
        let pn: [String] = ["1ST PLACE", "2ND PLACE", "3RD PLACE", "4TH PLACE"]
        ctext(b, pn[max(0, min(3, finalPlace - 1))], 56, JetSki64.cWhite, 2)
        // stars
        let shown: Int = min(finalStars, max(0, (phaseT - 8) / 12))
        for i in 0..<3 {
            let cx: Int = 200 + i * 30 - 30
            if i < shown {
                sparkle(b, cx, 96, 14, TrueColorBuffer.rgb(255, 140, 30))
                sparkle(b, cx, 96, 11, JetSki64.cYellow)
                disc(b, cx, 96, 3, JetSki64.cWhite)
            } else {
                sparkle(b, cx, 96, 11, TrueColorBuffer.rgb(60, 90, 150))
            }
        }
        // standings
        for (row, idx) in results.enumerated() {
            let y: Int = 134 + row * 20
            b.fillRect(40, y - 2, 240, 17, row % 2 == 0 ? TrueColorBuffer.rgb(30, 70, 150) : TrueColorBuffer.rgb(24, 56, 130))
            b.text(String(row + 1), 46, y + 2, JetSki64.cYellow, scale: 2)
            b.fillRect(70, y, 14, 12, JetSki64.skiMain[idx & 3])
            b.fillRect(72, y + 2, 10, 3, JetSki64.skiAccent[idx & 3])
            b.text(JetSki64.rivalNames[idx], 92, y + 3, idx == 0 ? JetSki64.cYellow : JetSki64.cWhite, scale: 1)
        }
        let sc: String = "SCORE " + String(raceScore + placeBonus)
        ctext(b, sc, 222, JetSki64.cWhite, 2)
        let info: String = "TRICKS " + String(tricks) + "  TIME " + fmtTime(raceT)
        ctext(b, info, 242, JetSki64.cCyan, 1)
        if justUnlocked {
            ctext(b, "CIRCUIT 2 UNLOCKED!", 254, (tick / 6) % 2 == 0 ? JetSki64.cYellow : JetSki64.cGreen, 1)
        }
        if phaseT > 50 && (tick / 30) % 2 == 0 {
            let a: String = justUnlocked ? "A RACE CIRCUIT 2" : "A RACE AGAIN"
            ctext(b, a + "   START MENU", 264, JetSki64.cWhite, 1)
        }
    }
}

extension Cartridge {
    static let jetSki64 = Cartridge(
        id: "jetski64", title: "JET SKI 64", genre: "Racing",
        blurb: "Tear around a sunset island circuit on a jet-ski: ramps, spin tricks, drift boosts, a secret shortcut and three rival riders.",
        controls: "A gas, B brake/drift (hold in air to spin), LEFT/RIGHT steer, UP boost.",
        era: .n64, labelTop: 0xFF9A50, labelBottom: 0x1A8FE0, factory: { JetSki64() })
}
