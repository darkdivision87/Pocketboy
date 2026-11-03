#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// SKY GLIDER 64: a voxel-space ("Comanche" style) flight game. A procedurally generated 256x256 tileable
/// heightmap (hills, a river valley, snowy peaks, forests) is ray-marched one column at a time, front to back,
/// with distance fog into a sky gradient. Fly a glider through glowing rings before the clock runs out.
final class SkyGlider64: Game {
    // MARK: - Constants

    private static let screenW = 320
    private static let screenH = 288
    private static let focal: Float = 210
    private static let vscale: Float = 210
    private static let maxDist: Float = 230
    private static let fogStart: Float = 55
    private static let hazeR = 192
    private static let hazeG = 222
    private static let hazeB = 246
    private static let totalRings = 20
    private static let ringRadius: Float = 11
    private static let startTime = 50 * 60
    private static let maxTime = 99 * 60
    private static let camBack: Float = 14
    private static let camUp: Float = 7
    private static let sunAzimuth: Float = 1.0

    private static let cWhite: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    private static let cBlack: UInt32 = TrueColorBuffer.rgb(8, 10, 18)
    private static let cYellow: UInt32 = TrueColorBuffer.rgb(255, 230, 70)
    private static let cRed: UInt32 = TrueColorBuffer.rgb(255, 80, 64)
    private static let cGreen: UInt32 = TrueColorBuffer.rgb(110, 255, 130)
    private static let cCyan: UInt32 = TrueColorBuffer.rgb(100, 235, 255)
    private static let cPanel: UInt32 = TrueColorBuffer.rgb(14, 22, 54)
    private static let cDim: UInt32 = TrueColorBuffer.rgb(40, 52, 90)

    // MARK: - Static tables

    private static let terrain = TerrainData()

    private static let fogTab: [Int] = {
        var a = [Int](repeating: 0, count: 512)
        let span: Float = SkyGlider64.maxDist - SkyGlider64.fogStart
        for i in 0..<512 {
            let z: Float = Float(i)
            if z <= SkyGlider64.fogStart { continue }
            var t: Float = (z - SkyGlider64.fogStart) / span
            if t > 1 { t = 1 }
            if t < 0 { t = 0 }
            let f: Float = t * (0.4 + 0.6 * t)
            a[i] = Int(f * 256)
        }
        return a
    }()

    private static let skyTab: [UInt32] = {
        var a = [UInt32](repeating: 0, count: 640)
        for k in 0..<640 {
            let d: Float = Float(k - 320)
            var t: Float = d / 220.0
            if t < 0 { t = 0 }
            if t > 1 { t = 1 }
            let r: Float = Float(SkyGlider64.hazeR) + (46 - Float(SkyGlider64.hazeR)) * t
            let g: Float = Float(SkyGlider64.hazeG) + (104 - Float(SkyGlider64.hazeG)) * t
            let bl: Float = Float(SkyGlider64.hazeB) + (214 - Float(SkyGlider64.hazeB)) * t
            a[k] = TrueColorBuffer.rgb(Int(r), Int(g), Int(bl))
        }
        return a
    }()

    private static let ringCos: [Float] = {
        var a = [Float](repeating: 1, count: 56)
        for i in 0..<56 { a[i] = cos(Float(i) / 56.0 * 2.0 * Float.pi) }
        return a
    }()

    private static let ringSin: [Float] = {
        var a = [Float](repeating: 0, count: 56)
        for i in 0..<56 { a[i] = sin(Float(i) / 56.0 * 2.0 * Float.pi) }
        return a
    }()

    @inline(__always) private static func mix(_ c: UInt32, _ t: Int) -> UInt32 {
        let r = Int(c & 255)
        let g = Int((c >> 8) & 255)
        let bl = Int((c >> 16) & 255)
        let r2 = r + (((SkyGlider64.hazeR - r) * t) >> 8)
        let g2 = g + (((SkyGlider64.hazeG - g) * t) >> 8)
        let b2 = bl + (((SkyGlider64.hazeB - bl) * t) >> 8)
        let rr = UInt32(max(0, min(255, r2)))
        let gg = UInt32(max(0, min(255, g2)))
        let bb = UInt32(max(0, min(255, b2)))
        return 0xFF00_0000 | rr | (gg << 8) | (bb << 16)
    }

    static func wrapAngle(_ a: Float) -> Float {
        if !a.isFinite { return 0 }
        var d = a
        while d > Float.pi { d -= 2 * Float.pi }
        while d < -Float.pi { d += 2 * Float.pi }
        return d
    }

    static func wrapDelta(_ d: Float) -> Float {
        if !d.isFinite { return 0 }
        return d - 256 * floor(d / 256 + 0.5)
    }

    // MARK: - Nested types

    final class TerrainData {
        let hgt: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.allocate(capacity: 65536)
        let col: UnsafeMutablePointer<UInt32> = UnsafeMutablePointer<UInt32>.allocate(capacity: 65536)
        static let heightScale: Float = 0.5
        static let waterLevel: Float = 0.08

        init() {
            hgt.initialize(repeating: 0, count: 65536)
            col.initialize(repeating: 0xFF00_0000, count: 65536)
            build()
        }

        static func hash01(_ x: Int, _ y: Int, _ seed: Int) -> Float {
            var h: Int = x &* 374761393 &+ y &* 668265263 &+ seed &* 144269504
            h = (h ^ (h >> 13)) &* 1274126177
            h = h ^ (h >> 16)
            return Float(h & 0xFFFF) / 65535.0
        }

        static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
            return a + (b - a) * t
        }

        static func vnoise(_ x: Float, _ y: Float, _ period: Int, _ seed: Int) -> Float {
            let fx0: Float = floor(x)
            let fy0: Float = floor(y)
            let xi = Int(fx0)
            let yi = Int(fy0)
            let tx: Float = x - fx0
            let ty: Float = y - fy0
            let sx: Float = tx * tx * (3 - 2 * tx)
            let sy: Float = ty * ty * (3 - 2 * ty)
            let x0 = ((xi % period) + period) % period
            let x1 = (x0 + 1) % period
            let y0 = ((yi % period) + period) % period
            let y1 = (y0 + 1) % period
            let a: Float = hash01(x0, y0, seed)
            let b: Float = hash01(x1, y0, seed)
            let c: Float = hash01(x0, y1, seed)
            let d: Float = hash01(x1, y1, seed)
            let top: Float = a + (b - a) * sx
            let bot: Float = c + (d - c) * sx
            return top + (bot - top) * sy
        }

        func sample(_ x: Float, _ y: Float) -> Float {
            if !(x.isFinite && y.isFinite) { return 0 }
            let wx: Float = x - 256 * floor(x / 256)
            let wy: Float = y - 256 * floor(y / 256)
            let xi = Int(wx)
            let yi = Int(wy)
            let fx: Float = wx - Float(xi)
            let fy: Float = wy - Float(yi)
            let x0 = xi & 255
            let x1 = (xi + 1) & 255
            let y0 = (yi & 255) << 8
            let y1 = ((yi + 1) & 255) << 8
            let h00: Float = hgt[y0 + x0]
            let h10: Float = hgt[y0 + x1]
            let h01: Float = hgt[y1 + x0]
            let h11: Float = hgt[y1 + x1]
            let top: Float = h00 + (h10 - h00) * fx
            let bot: Float = h01 + (h11 - h01) * fx
            return top + (bot - top) * fy
        }

        func build() {
            var raw = [Float](repeating: 0, count: 65536)
            let periods: [Int] = [3, 6, 12, 24, 48, 96]
            var mn: Float = 100000
            var mx: Float = -100000
            for y in 0..<256 {
                let v: Float = Float(y) / 256.0
                for x in 0..<256 {
                    let u: Float = Float(x) / 256.0
                    var n: Float = 0
                    var amp: Float = 0.5
                    for k in 0..<6 {
                        let per = periods[k]
                        let fp: Float = Float(per)
                        n += amp * TerrainData.vnoise(u * fp, v * fp, per, 11 + k)
                        amp *= 0.5
                    }
                    let m: Float = TerrainData.vnoise(u * 3, v * 3, 3, 77)
                    let ridge: Float = 1 - abs(2 * TerrainData.vnoise(u * 8, v * 8, 8, 5) - 1)
                    n += ridge * ridge * 0.28 * m
                    raw[y * 256 + x] = n
                    if n < mn { mn = n }
                    if n > mx { mx = n }
                }
            }
            let span: Float = max(0.0001, mx - mn)
            var hn = [Float](repeating: 0, count: 65536)
            let twoPi: Float = 2.0 * Float.pi
            let wl = TerrainData.waterLevel
            for y in 0..<256 {
                let fy: Float = Float(y) / 256.0
                let riverX: Float = 128 + 38 * sin(twoPi * fy) + 14 * sin(twoPi * 3 * fy + 1.3)
                for x in 0..<256 {
                    var t: Float = (raw[y * 256 + x] - mn) / span
                    if t < 0 { t = 0 }
                    if t > 1 { t = 1 }
                    var h: Float = t * t * (1.6 - 0.6 * t)
                    let dist: Float = abs(Float(x) - riverX)
                    var vf: Float = dist / 34.0
                    if vf > 1 { vf = 1 }
                    let s: Float = vf * vf * (3 - 2 * vf)
                    h = h * s + 0.04 * (1 - s)
                    if h < wl { h = wl }
                    hn[y * 256 + x] = h
                }
            }
            let hs = TerrainData.heightScale
            for y in 0..<256 {
                let v: Float = Float(y) / 256.0
                for x in 0..<256 {
                    let u: Float = Float(x) / 256.0
                    let i = y * 256 + x
                    let hh: Float = hn[i]
                    hgt[i] = hh * 255 * hs
                    let xm = (x + 255) & 255
                    let xp = (x + 1) & 255
                    let ym = (y + 255) & 255
                    let yp = (y + 1) & 255
                    let hxm: Float = hn[y * 256 + xm]
                    let hxp: Float = hn[y * 256 + xp]
                    let hym: Float = hn[ym * 256 + x]
                    let hyp: Float = hn[yp * 256 + x]
                    var shade: Float = 1 + (hxp - hxm + hyp - hym) * 9
                    if shade < 0.72 { shade = 0.72 }
                    if shade > 1.3 { shade = 1.3 }
                    let n1: Float = TerrainData.vnoise(u * 20, v * 20, 20, 31)
                    let n2: Float = TerrainData.vnoise(u * 40, v * 40, 40, 41)
                    let jit: Float = TerrainData.hash01(x, y, 3) - 0.5
                    var r: Float = 0
                    var g: Float = 0
                    var b: Float = 0
                    if hh <= wl + 0.002 {
                        r = 36 + 22 * n1
                        g = 112 + 34 * n1
                        b = 208 + 30 * n1
                        shade = 1
                    } else if hh < wl + 0.03 {
                        r = 236
                        g = 218
                        b = 152
                    } else {
                        r = 88 + 30 * n1
                        g = 172 - 22 * n1
                        b = 62
                        if n2 > 0.58 && hh < 0.5 {
                            var f: Float = (n2 - 0.58) * 8
                            if f > 1 { f = 1 }
                            r = TerrainData.lerp(r, 26, f)
                            g = TerrainData.lerp(g, 108, f)
                            b = TerrainData.lerp(b, 44, f)
                        }
                        var rt: Float = (hh - 0.42) * 7
                        if rt < 0 { rt = 0 }
                        if rt > 1 { rt = 1 }
                        let slope: Float = abs(hxp - hxm) + abs(hyp - hym)
                        var st: Float = (slope - 0.035) * 20
                        if st < 0 { st = 0 }
                        if st > 1 { st = 1 }
                        let rockT: Float = max(rt, st * 0.8)
                        r = TerrainData.lerp(r, 156, rockT)
                        g = TerrainData.lerp(g, 140, rockT)
                        b = TerrainData.lerp(b, 124, rockT)
                        var sn: Float = (hh - 0.6) * 12
                        if sn < 0 { sn = 0 }
                        if sn > 1 { sn = 1 }
                        r = TerrainData.lerp(r, 250, sn)
                        g = TerrainData.lerp(g, 252, sn)
                        b = TerrainData.lerp(b, 255, sn)
                        r += jit * 10
                        g += jit * 10
                        b += jit * 10
                    }
                    r = max(0, min(255, r * shade))
                    g = max(0, min(255, g * shade))
                    b = max(0, min(255, b * shade))
                    col[i] = TrueColorBuffer.rgb(Int(r), Int(g), Int(b))
                }
            }
        }
    }

    struct Cam {
        var x: Float = 0
        var y: Float = 0
        var alt: Float = 0
        var fx: Float = 1
        var fy: Float = 0
        var rx: Float = 0
        var ry: Float = 1
        var horizon: Float = 150
        var roll: Float = 0
    }

    struct Ring {
        var x: Float
        var y: Float
        var z: Float
        var yaw: Float
    }

    enum Phase { case title, flying, crash, results }

    // MARK: - State

    private var phase: Phase = .title
    private var rng = Rng()
    private var frame = 0
    private var gx: Float = 128
    private var gy: Float = 128
    private var alt: Float = 120
    private var heading: Float = 0
    private var pitch: Float = 0
    private var bank: Float = 0
    private var speed: Float = 0.6
    private var energy: Float = 1
    private var boosting = false
    private var braking = false
    private var timeLeft = SkyGlider64.startTime
    private var rings: [Ring] = []
    private var ringIdx = 0
    private var ringsHit = 0
    private var combo = 0
    private var comboTimer = 0
    private var scoreValue = 0
    private var prevF: Float = 0
    private var msg = ""
    private var msgTimer = 0
    private var crashTimer = 0
    private var endReason = 0
    private var resultTimer = 0
    private var finishBonus = 0
    private var hcol = [Int](repeating: 150, count: 320)
    private let depth: UnsafeMutablePointer<UInt16> = UnsafeMutablePointer<UInt16>.allocate(capacity: 320 * 288)
    private var gliderSY = 212
    private var camOut = Cam()

    override var score: Int { return max(0, scoreValue) }

    override init() {
        super.init()
        depth.initialize(repeating: 65535, count: 320 * 288)
        resetRun()
        phase = .title
    }

    deinit {
        depth.deallocate()
    }

    override func start() {
        playMusic(Tunes.adventure)
    }

    // MARK: - Setup

    private func resetRun() {
        let tr = SkyGlider64.terrain
        var bestX: Float = 128
        var bestY: Float = 128
        var bestH: Float = 100000
        for _ in 0..<10 {
            let cx = Float(rng.range(20, 235))
            let cy = Float(rng.range(20, 235))
            let hh = tr.sample(cx, cy)
            if hh < bestH {
                bestH = hh
                bestX = cx
                bestY = cy
            }
        }
        gx = bestX
        gy = bestY
        alt = bestH + 40
        heading = Float(rng.int(628)) / 100.0
        pitch = 0
        bank = 0
        speed = 0.6
        energy = 1
        boosting = false
        braking = false
        timeLeft = SkyGlider64.startTime
        ringIdx = 0
        ringsHit = 0
        combo = 0
        comboTimer = 0
        scoreValue = 0
        msg = ""
        msgTimer = 0
        crashTimer = 0
        endReason = 0
        resultTimer = 0
        finishBonus = 0
        buildRings()
        prevF = 0
        updateTargetF()
    }

    private func buildRings() {
        let tr = SkyGlider64.terrain
        rings = []
        var px = gx
        var py = gy
        var h = heading
        var prevAlt = alt
        for _ in 0..<SkyGlider64.totalRings {
            var bestH: Float = h
            var bestG: Float = 100000
            var bestX: Float = px
            var bestY: Float = py
            var chosen = false
            var attempt = 0
            while attempt < 8 && !chosen {
                let cand: Float = h + Float(rng.range(-70, 70)) / 100.0
                let dist: Float = Float(rng.range(78, 108))
                let nx: Float = px + cos(cand) * dist
                let ny: Float = py + sin(cand) * dist
                let mx: Float = px + cos(cand) * dist * 0.5
                let my: Float = py + sin(cand) * dist * 0.5
                let g1 = tr.sample(nx, ny)
                let g2 = tr.sample(mx, my)
                let g: Float = max(g1, g2)
                if g < bestG {
                    bestG = g
                    bestH = cand
                    bestX = nx
                    bestY = ny
                }
                if g < prevAlt + 8 { chosen = true }
                attempt += 1
            }
            h = bestH
            px = bestX
            py = bestY
            let ground = tr.sample(px, py)
            var a: Float = ground + 22 + Float(rng.range(0, 30))
            a = min(a, prevAlt + 24)
            a = max(a, ground + 16)
            a = max(a, prevAlt - 60)
            a = min(a, 215)
            a = max(a, ground + 14)
            prevAlt = a
            let wx: Float = px - 256 * floor(px / 256)
            let wy: Float = py - 256 * floor(py / 256)
            rings.append(Ring(x: wx, y: wy, z: a, yaw: h))
            px = wx
            py = wy
        }
    }

    private func startRun() {
        resetRun()
        phase = .flying
        showMsg("GO!", 70)
        play(.confirm)
    }

    private func showMsg(_ s: String, _ frames: Int) {
        msg = s
        msgTimer = frames
    }

    private func updateTargetF() {
        if ringIdx < 0 || ringIdx >= rings.count { return }
        let r = rings[ringIdx]
        let dx: Float = SkyGlider64.wrapDelta(r.x - gx)
        let dy: Float = SkyGlider64.wrapDelta(r.y - gy)
        prevF = dx * cos(heading) + dy * sin(heading)
    }

    // MARK: - Update

    override func update(_ input: InputState) {
        frame += 1
        if msgTimer > 0 { msgTimer -= 1 }
        switch phase {
        case .title:
            heading += 0.005
            bank = 0.35
            pitch = 0.04 + 0.05 * sin(Float(frame) * 0.02)
            gx += cos(heading) * 0.5
            gy += sin(heading) * 0.5
            gx = gx - 256 * floor(gx / 256)
            gy = gy - 256 * floor(gy / 256)
            alt = 150
            speed = 0.6
            boosting = false
            if input.aPressed || input.startPressed { startRun() }
        case .flying:
            stepFlight(input)
        case .crash:
            crashTimer -= 1
            if crashTimer <= 0 {
                phase = .results
                resultTimer = 0
            }
        case .results:
            resultTimer += 1
            if resultTimer > 40 && (input.aPressed || input.startPressed) {
                startRun()
            }
        }
    }

    private func stepFlight(_ input: InputState) {
        let tr = SkyGlider64.terrain
        let dxIn: Float = Float(input.dx)
        let climbIn: Float = -Float(input.dy)
        // pitch
        if input.dy != 0 {
            pitch += (climbIn * 0.5 - pitch) * 0.06
        } else {
            pitch += (-0.04 - pitch) * 0.02
        }
        if speed < 0.3 { pitch -= 0.006 }
        pitch = clamp(pitch, -0.55, 0.55)
        // speed
        var ts: Float = 0.62 - pitch * 0.9
        boosting = false
        braking = false
        if input.a && energy > 0.02 {
            ts += 0.5
            energy -= 0.006
            boosting = true
        } else {
            energy += 0.0015
            if energy > 1 { energy = 1 }
        }
        var turnMul: Float = 1
        if input.b {
            ts *= 0.55
            turnMul = 1.5
            braking = true
        }
        ts = clamp(ts, 0.25, 1.5)
        speed += (ts - speed) * 0.025
        speed = clamp(speed, 0.15, 1.7)
        // bank and turn
        bank += (dxIn - bank) * 0.08
        heading += bank * 0.022 * (0.7 + speed * 0.6) * turnMul
        heading = SkyGlider64.wrapAngle(heading)
        // move
        let fx: Float = cos(heading)
        let fy: Float = sin(heading)
        gx += fx * speed
        gy += fy * speed
        gx = gx - 256 * floor(gx / 256)
        gy = gy - 256 * floor(gy / 256)
        alt += speed * sin(pitch) * 1.6 - 0.04
        if alt > 240 { alt = 240 }
        if !alt.isFinite { alt = 120 }
        // terrain collision
        let ground = tr.sample(gx, gy)
        if alt < ground + 1.2 {
            crashNow()
            return
        }
        // timer
        timeLeft -= 1
        if comboTimer > 0 {
            comboTimer -= 1
            if comboTimer == 0 { combo = 0 }
        }
        if timeLeft > 0 && timeLeft < 600 && timeLeft % 60 == 0 { play(.countdown) }
        if timeLeft <= 0 {
            timeLeft = 0
            endRun(1)
            return
        }
        // rings
        if ringIdx >= 0 && ringIdx < rings.count {
            let r = rings[ringIdx]
            let dx: Float = SkyGlider64.wrapDelta(r.x - gx)
            let dy: Float = SkyGlider64.wrapDelta(r.y - gy)
            let f: Float = dx * fx + dy * fy
            let l: Float = dx * (-fy) + dy * fx
            let v: Float = r.z - alt
            if prevF > 0 && f <= 0 && prevF < 8 {
                let lim: Float = SkyGlider64.ringRadius + 2
                if l * l + v * v <= lim * lim { collectRing() }
            }
            prevF = f
        }
    }

    private func collectRing() {
        ringsHit += 1
        if comboTimer > 0 { combo = min(5, combo + 1) } else { combo = 1 }
        comboTimer = 600
        let pts = 100 * combo + Int(speed * 100)
        scoreValue += pts
        timeLeft = min(SkyGlider64.maxTime, timeLeft + 7 * 60)
        ringIdx += 1
        if combo >= 3 { play(.powerup) } else { play(.coin) }
        if ringIdx >= SkyGlider64.totalRings {
            endRun(2)
            return
        }
        if combo > 1 {
            showMsg("RING +7S  X" + String(combo), 70)
        } else {
            showMsg("RING +7S", 70)
        }
        updateTargetF()
    }

    private func crashNow() {
        phase = .crash
        crashTimer = 110
        endReason = 0
        boosting = false
        play(.explosion)
    }

    private func endRun(_ reason: Int) {
        endReason = reason
        phase = .results
        resultTimer = 0
        finishBonus = 0
        if reason == 2 {
            finishBonus = (timeLeft / 60) * 25
            scoreValue += finishBonus
            play(.win)
        } else {
            play(.lose)
        }
    }

    // MARK: - Rendering

    private func makeCam() -> Cam {
        let tr = SkyGlider64.terrain
        var c = Cam()
        let fx: Float = cos(heading)
        let fy: Float = sin(heading)
        c.fx = fx
        c.fy = fy
        c.rx = -fy
        c.ry = fx
        c.x = gx - fx * SkyGlider64.camBack
        c.y = gy - fy * SkyGlider64.camBack
        var ca: Float = alt + SkyGlider64.camUp
        let ground = tr.sample(c.x, c.y)
        if ca < ground + 3 { ca = ground + 3 }
        c.alt = ca
        var hz: Float = 150 + pitch * 210
        if phase == .crash {
            hz += Float((frame * 7) % 9) - 4
        }
        if !hz.isFinite { hz = 150 }
        c.horizon = clamp(hz, -100, 400)
        c.roll = -bank * 0.12
        return c
    }

    private func renderSky(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ cam: Cam) {
        let sky = SkyGlider64.skyTab
        let hc = hcol
        for y in 0..<h {
            let base = y * w
            for x in 0..<w {
                var k = hc[x] - y + 320
                if k < 0 { k = 0 }
                if k > 639 { k = 639 }
                p[base + x] = sky[k]
            }
        }
        depth.initialize(repeating: 65535, count: w * h)
        // sun
        let da: Float = SkyGlider64.wrapAngle(SkyGlider64.sunAzimuth - heading)
        if abs(da) < 1.15 {
            let sxf: Float = 160 + tan(da) * SkyGlider64.focal * 0.5
            let sx = Int(clamp(sxf, -200, 520))
            let sy = hc[160] - 80
            let rad = 48
            let y0 = max(0, sy - rad)
            let y1 = min(h - 1, sy + rad)
            let x0 = max(0, sx - rad)
            let x1 = min(w - 1, sx + rad)
            if y0 <= y1 && x0 <= x1 {
                let core = TrueColorBuffer.rgb(255, 250, 220)
                for yy in y0...y1 {
                    for xx in x0...x1 {
                        let ddx = xx - sx
                        let ddy = yy - sy
                        let d2 = ddx * ddx + ddy * ddy
                        if d2 > rad * rad { continue }
                        let d: Float = sqrt(Float(d2))
                        let idx = yy * w + xx
                        if d <= 13 {
                            p[idx] = core
                        } else {
                            var t: Float = 1 - (d - 13) / Float(rad - 13)
                            if t < 0 { t = 0 }
                            let add = Int(t * t * 150)
                            let c = p[idx]
                            let r = Int(c & 255) + add
                            let g = Int((c >> 8) & 255) + add
                            let bl = Int((c >> 16) & 255) + add * 2 / 3
                            p[idx] = TrueColorBuffer.rgb(r, g, bl)
                        }
                    }
                }
            }
        }
    }

    private func renderTerrain(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ cam: Cam) {
        let tr = SkyGlider64.terrain
        let hg = tr.hgt
        let cp = tr.col
        let dp = depth
        let fogTab = SkyGlider64.fogTab
        let hc = hcol
        let invFocal: Float = 1.0 / SkyGlider64.focal
        let vs = SkyGlider64.vscale
        let maxD = SkyGlider64.maxDist
        let ox: Float = cam.x + 1024
        let oy: Float = cam.y + 1024
        let camAlt = cam.alt
        for x in 0..<w {
            let u: Float = (Float(x) - 159.5) * invFocal
            let dX: Float = cam.fx + cam.rx * u
            let dY: Float = cam.fy + cam.ry * u
            let hz: Float = Float(hc[x])
            var ybuf = h
            var z: Float = 2.0
            while z < maxD && ybuf > 0 {
                let wx: Float = ox + dX * z
                let wy: Float = oy + dY * z
                let xi = Int(wx)
                let yi = Int(wy)
                let fx: Float = wx - Float(xi)
                let fy: Float = wy - Float(yi)
                let x0 = xi & 255
                let x1 = (xi + 1) & 255
                let y0 = (yi & 255) << 8
                let y1 = ((yi + 1) & 255) << 8
                let h00: Float = hg[y0 + x0]
                let h10: Float = hg[y0 + x1]
                let h01: Float = hg[y1 + x0]
                let h11: Float = hg[y1 + x1]
                let top: Float = h00 + (h10 - h00) * fx
                let bot: Float = h01 + (h11 - h01) * fx
                let hh: Float = top + (bot - top) * fy
                var yf: Float = hz + (camAlt - hh) * vs / z
                if yf < -1 { yf = -1 }
                if yf > 400 { yf = 400 }
                let ys = Int(yf)
                if ys < ybuf {
                    var c: UInt32 = cp[y0 + x0]
                    let zi = Int(z)
                    let fg = fogTab[zi]
                    if fg > 0 { c = SkyGlider64.mix(c, fg) }
                    let yStart = max(0, ys)
                    let zd = UInt16(zi)
                    var yy = yStart
                    while yy < ybuf {
                        let idx = yy * w + x
                        p[idx] = c
                        dp[idx] = zd
                        yy += 1
                    }
                    ybuf = yStart
                }
                z += 0.45 + z * 0.018
            }
        }
    }

    private func drawRingShape(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ cam: Cam,
                               _ ring: Ring, _ scale: Float, _ colA: UInt32, _ colB: UInt32, _ thickMul: Float) {
        let dx: Float = SkyGlider64.wrapDelta(ring.x - cam.x)
        let dy: Float = SkyGlider64.wrapDelta(ring.y - cam.y)
        let zc: Float = dx * cam.fx + dy * cam.fy
        let xc: Float = dx * cam.rx + dy * cam.ry
        if zc < 3 || zc > SkyGlider64.maxDist + 40 { return }
        // ring tangent (horizontal, perpendicular to its normal)
        let tx: Float = -sin(ring.yaw)
        let ty: Float = cos(ring.yaw)
        let ctz: Float = tx * cam.fx + ty * cam.fy
        let ctx: Float = tx * cam.rx + ty * cam.ry
        let rad: Float = SkyGlider64.ringRadius * scale
        let cs = SkyGlider64.ringCos
        let sn = SkyGlider64.ringSin
        let dp = depth
        let screenRad: Float = rad * SkyGlider64.focal / zc
        var thick = Int(screenRad * 0.16 * thickMul)
        if thick < 1 { thick = 1 }
        if thick > 7 { thick = 7 }
        for k in 0..<56 {
            let zc2: Float = zc + ctz * rad * cs[k]
            if zc2 < 1.5 { continue }
            let xc2: Float = xc + ctx * rad * cs[k]
            let sxF: Float = 160 + xc2 * SkyGlider64.focal / zc2
            let hzF: Float = cam.horizon + (sxF - 159.5) * cam.roll
            let syF: Float = hzF + (cam.alt - (ring.z + rad * sn[k])) * SkyGlider64.vscale / zc2
            if !(sxF > -50 && sxF < 370 && syF > -50 && syF < 340) { continue }
            let sx = Int(sxF)
            let sy = Int(syF)
            let zq = UInt16(max(0, min(60000, Int(zc2))))
            if sx >= 0 && sx < w && sy >= 0 && sy < h {
                if dp[sy * w + sx] < zq { continue }
            }
            let c: UInt32 = ((k / 4) & 1) == 0 ? colA : colB
            let half = thick / 2
            let ya = max(0, sy - half)
            let yb = min(h - 1, sy - half + thick - 1)
            let xa = max(0, sx - half)
            let xb = min(w - 1, sx - half + thick - 1)
            if ya > yb || xa > xb { continue }
            for yy in ya...yb {
                for xx in xa...xb { p[yy * w + xx] = c }
            }
        }
    }

    private func drawRings(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ cam: Cam) {
        if rings.isEmpty || ringIdx >= rings.count { return }
        let last = min(rings.count - 1, ringIdx + 4)
        var i = last
        while i >= ringIdx {
            let r = rings[i]
            if i == ringIdx {
                let pulse: Float = 1.0 + 0.06 * sin(Float(frame) * 0.2)
                drawRingShape(p, w, h, cam, r, pulse, TrueColorBuffer.rgb(255, 232, 70), TrueColorBuffer.rgb(255, 255, 255), 1.2)
                drawRingShape(p, w, h, cam, r, 0.78 * pulse, TrueColorBuffer.rgb(255, 150, 40), TrueColorBuffer.rgb(255, 210, 90), 0.7)
            } else {
                drawRingShape(p, w, h, cam, r, 1.0, TrueColorBuffer.rgb(90, 232, 255), TrueColorBuffer.rgb(190, 255, 255), 1.0)
            }
            i -= 1
        }
    }

    private func drawShadow(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ cam: Cam) {
        let ground = SkyGlider64.terrain.sample(gx, gy)
        let agl: Float = max(0, alt - ground)
        let off = Int(min(34, agl * 0.45))
        let cy = gliderSY + 20 + off
        let cx = 160
        var rxF: Float = 26 - agl * 0.1
        if rxF < 8 { rxF = 8 }
        let rx = Int(rxF)
        let ry = max(3, rx / 4)
        if cy - ry < hcol[160] + 2 { return }
        let ya = max(0, cy - ry)
        let yb = min(h - 1, cy + ry)
        if ya > yb { return }
        for yy in ya...yb {
            let ddy: Float = Float(yy - cy) / Float(ry)
            let span2: Float = 1 - ddy * ddy
            if span2 <= 0 { continue }
            let half = Int(Float(rx) * sqrt(span2))
            let xa = max(0, cx - half)
            let xb = min(w - 1, cx + half)
            if xa > xb { continue }
            for xx in xa...xb {
                let idx = yy * w + xx
                let c = p[idx]
                p[idx] = ((c >> 1) & 0x007F_7F7F) | 0xFF00_0000
            }
        }
    }

    override func drawTrueColor(_ b: TrueColorBuffer) {
        let cam = makeCam()
        camOut = cam
        gliderSY = 212 - Int(pitch * 36)
        for x in 0..<320 {
            let hv: Float = cam.horizon + (Float(x) - 159.5) * cam.roll
            hcol[x] = Int(clamp(hv, -400, 700))
        }
        b.withPixels { p, w, h in
            if w != 320 || h != 288 { return }
            self.renderSky(p, w, h, cam)
            self.renderTerrain(p, w, h, cam)
            self.drawRings(p, w, h, cam)
            if self.phase == .flying || self.phase == .title { self.drawShadow(p, w, h, cam) }
        }
        drawGlider(b)
        drawEffects(b)
        drawHUD(b)
        drawOverlays(b)
    }

    // MARK: - Glider and effects

    private func drawGlider(_ b: TrueColorBuffer) {
        if phase == .crash && crashTimer < 100 { return }
        if phase == .results && endReason == 0 { return }
        let gyc = gliderSY
        let white = TrueColorBuffer.rgb(250, 250, 255)
        let shadeW = TrueColorBuffer.rgb(170, 184, 214)
        let red = TrueColorBuffer.rgb(240, 60, 52)
        let dark = TrueColorBuffer.rgb(40, 50, 84)
        var i = -34
        while i <= 34 {
            let ax = abs(i)
            let tilt = Int(Float(i) * bank * 0.3)
            let yy = gyc + ax / 6 + tilt
            let c: UInt32 = ax > 24 ? red : white
            b.fillRect(160 + i, yy, 2, 4, c)
            b.fillRect(160 + i, yy + 4, 2, 1, shadeW)
            i += 2
        }
        b.fillRect(155, gyc - 6, 10, 18, dark)
        b.fillRect(157, gyc - 8, 6, 14, shadeW)
        b.fillRect(158, gyc - 11, 4, 5, SkyGlider64.cCyan)
        b.fillRect(159, gyc - 17, 2, 10, red)
        b.fillRect(151, gyc + 8, 18, 3, white)
        b.fillRect(151, gyc + 11, 18, 1, shadeW)
        if boosting {
            let fl = 6 + (frame & 3) * 2
            b.fillRect(158, gyc + 12, 4, fl, TrueColorBuffer.rgb(255, 150, 30))
            b.fillRect(159, gyc + 12, 2, fl / 2, TrueColorBuffer.rgb(255, 245, 140))
        }
        if braking {
            b.fillRect(130, gyc + 2, 8, 2, SkyGlider64.cRed)
            b.fillRect(182, gyc + 2, 8, 2, SkyGlider64.cRed)
        }
    }

    private func drawEffects(_ b: TrueColorBuffer) {
        if (phase == .flying) && boosting {
            let streak = TrueColorBuffer.rgb(255, 250, 210)
            for i in 0..<14 {
                let yy = 30 + ((i * 53 + frame * 13) % 220)
                let len = 12 + ((i * 7) % 16)
                let left = (i & 1) == 0
                let xx = left ? ((i * 13 + frame * 6) % 50) : (320 - len - ((i * 17 + frame * 6) % 50))
                b.fillRect(xx, yy, len, 1, streak)
            }
        }
        if phase == .crash {
            let age = 110 - crashTimer
            let cs = SkyGlider64.ringCos
            let sn = SkyGlider64.ringSin
            let cx = 160
            let cy = gliderSY
            let ball = max(0, 26 - age / 3)
            if age < 70 {
                let r = min(40, 6 + age)
                b.fillRect(cx - r / 2, cy - r / 2, r, r, TrueColorBuffer.rgb(255, 150, 30))
                b.fillRect(cx - ball / 2, cy - ball / 2, ball, ball, TrueColorBuffer.rgb(255, 245, 160))
            }
            for i in 0..<28 {
                let ang = (i * 7) % 56
                let spd: Float = 0.9 + Float(i % 5) * 0.45
                let dist: Float = Float(age) * spd
                let sx = cx + Int(cs[ang] * dist)
                let sy = cy + Int(sn[ang] * dist * 0.8 + Float(age * age) * 0.012)
                let col: UInt32 = (i % 3) == 0 ? TrueColorBuffer.rgb(255, 240, 120) : ((i % 3) == 1 ? TrueColorBuffer.rgb(255, 130, 40) : TrueColorBuffer.rgb(235, 235, 235))
                if age < 100 { b.fillRect(sx, sy, 4, 4, col) }
            }
        }
    }

    // MARK: - HUD

    private func otext(_ b: TrueColorBuffer, _ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        let k = max(1, scale / 2)
        let o = SkyGlider64.cBlack
        b.text(s, x - k, y, o, scale: scale)
        b.text(s, x + k, y, o, scale: scale)
        b.text(s, x, y - k, o, scale: scale)
        b.text(s, x, y + k, o, scale: scale)
        b.text(s, x, y, c, scale: scale)
    }

    private func ctext(_ b: TrueColorBuffer, _ s: String, _ y: Int, _ c: UInt32, _ scale: Int) {
        let tw = b.textWidth(s, scale: scale)
        otext(b, s, (b.width - tw) / 2, y, c, scale)
    }

    private func line(_ b: TrueColorBuffer, _ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ c: UInt32, _ t: Int) {
        let dx = x1 - x0
        let dy = y1 - y0
        let steps = min(300, max(abs(dx), abs(dy)))
        if steps == 0 {
            b.fillRect(x0, y0, t, t, c)
            return
        }
        for i in 0...steps {
            let x = x0 + (dx * i) / steps
            let y = y0 + (dy * i) / steps
            b.fillRect(x - t / 2, y - t / 2, t, t, c)
        }
    }

    private func drawCompass(_ b: TrueColorBuffer) {
        let white = SkyGlider64.cWhite
        b.fillRect(78, 3, 164, 19, SkyGlider64.cBlack)
        b.fillRect(80, 5, 160, 15, SkyGlider64.cPanel)
        var deg: Float = heading * 180.0 / Float.pi + 90.0
        deg = deg - 360 * floor(deg / 360)
        let base = Int(floor(deg / 10.0)) * 10
        for i in -8...9 {
            let a = base + i * 10
            let off: Float = Float(a) - deg
            let sx = 160 + Int(off * 1.25)
            if sx < 82 || sx > 237 { continue }
            var n = a % 360
            if n < 0 { n += 360 }
            if n % 90 == 0 {
                var label = "N"
                if n == 90 { label = "E" } else if n == 180 { label = "S" } else if n == 270 { label = "W" }
                let colr: UInt32 = n == 0 ? SkyGlider64.cRed : SkyGlider64.cYellow
                b.text(label, sx - 1, 8, colr, scale: 2)
            } else if n % 30 == 0 {
                b.fillRect(sx, 9, 1, 8, white)
                b.text(String(n / 10), sx - 3, 18, white, scale: 1)
            } else {
                b.fillRect(sx, 12, 1, 4, SkyGlider64.cDim)
            }
        }
        b.fillRect(159, 3, 3, 4, SkyGlider64.cYellow)
    }

    private func drawArrow(_ b: TrueColorBuffer) {
        if ringIdx < 0 || ringIdx >= rings.count { return }
        let r = rings[ringIdx]
        let dx: Float = SkyGlider64.wrapDelta(r.x - gx)
        let dy: Float = SkyGlider64.wrapDelta(r.y - gy)
        let ang: Float = atan2(dy, dx)
        let rel: Float = SkyGlider64.wrapAngle(ang - heading)
        let cx = 160
        let cy = 52
        b.fillRect(cx - 17, cy - 17, 34, 34, SkyGlider64.cBlack)
        b.fillRect(cx - 16, cy - 16, 32, 32, SkyGlider64.cPanel)
        let tipX = cx + Int(sin(rel) * 13)
        let tipY = cy - Int(cos(rel) * 13)
        let tailX = cx - Int(sin(rel) * 9)
        let tailY = cy + Int(cos(rel) * 9)
        let col: UInt32 = abs(rel) < 0.25 ? SkyGlider64.cGreen : SkyGlider64.cYellow
        line(b, tailX, tailY, tipX, tipY, col, 3)
        let b1x = tipX + Int(sin(rel + 2.6) * 8)
        let b1y = tipY - Int(cos(rel + 2.6) * 8)
        let b2x = tipX + Int(sin(rel - 2.6) * 8)
        let b2y = tipY - Int(cos(rel - 2.6) * 8)
        line(b, tipX, tipY, b1x, b1y, col, 3)
        line(b, tipX, tipY, b2x, b2y, col, 3)
        let dist = Int(sqrt(dx * dx + dy * dy))
        let s = String(dist) + "M"
        let tw = b.textWidth(s, scale: 1)
        otext(b, s, 160 - tw / 2, 72, SkyGlider64.cWhite, 1)
    }

    private func timeText() -> String {
        return String((timeLeft + 59) / 60)
    }

    private func drawHUD(_ b: TrueColorBuffer) {
        if phase == .title { return }
        let white = SkyGlider64.cWhite
        let yellow = SkyGlider64.cYellow
        drawCompass(b)
        if phase == .flying { drawArrow(b) }
        // top-left score and rings
        otext(b, zeroPad(scoreValue, 6), 8, 6, white, 2)
        let shownRing = min(SkyGlider64.totalRings, ringsHit)
        otext(b, "RINGS " + String(shownRing) + "/" + String(SkyGlider64.totalRings), 8, 24, yellow, 2)
        if combo > 1 { otext(b, "COMBO X" + String(combo), 8, 42, SkyGlider64.cGreen, 1) }
        // time
        var tcol = white
        if timeLeft < 600 && (frame / 8) & 1 == 0 { tcol = SkyGlider64.cRed }
        let tt = timeText()
        let tw = b.textWidth(tt, scale: 4)
        otext(b, "TIME", 312 - b.textWidth("TIME", scale: 1), 6, white, 1)
        otext(b, tt, 312 - tw, 14, tcol, 4)
        // speed bar
        let kts = Int(speed * 160)
        otext(b, "SPD " + String(kts), 8, 244, white, 2)
        b.fillRect(6, 262, 92, 12, SkyGlider64.cBlack)
        b.fillRect(8, 264, 88, 8, TrueColorBuffer.rgb(50, 56, 80))
        let frac: Float = clamp(speed / 1.4, 0, 1)
        let fw = Int(frac * 88)
        var bc = SkyGlider64.cGreen
        if frac > 0.8 { bc = SkyGlider64.cRed } else if frac > 0.55 { bc = yellow }
        if fw > 0 { b.fillRect(8, 264, fw, 8, bc) }
        // boost bar
        b.fillRect(6, 276, 92, 8, SkyGlider64.cBlack)
        b.fillRect(8, 278, 88, 4, TrueColorBuffer.rgb(50, 56, 80))
        let ew = Int(clamp(energy, 0, 1) * 88)
        if ew > 0 { b.fillRect(8, 278, ew, 4, boosting ? yellow : SkyGlider64.cCyan) }
        // altitude
        let ground = SkyGlider64.terrain.sample(gx, gy)
        let agl = max(0, alt - ground)
        let altText = "ALT " + String(Int(alt * 2))
        let aw = b.textWidth(altText, scale: 2)
        otext(b, altText, 312 - aw, 244, white, 2)
        let gText = "AGL " + String(Int(agl * 2))
        let gw = b.textWidth(gText, scale: 2)
        otext(b, gText, 312 - gw, 262, agl < 12 ? SkyGlider64.cRed : SkyGlider64.cCyan, 2)
        // altimeter column
        b.fillRect(300, 90, 12, 140, SkyGlider64.cBlack)
        b.fillRect(302, 92, 8, 136, SkyGlider64.cPanel)
        let gh = Int(clamp(ground / 130.0, 0, 1) * 136)
        b.fillRect(302, 228 - gh, 8, gh, TrueColorBuffer.rgb(90, 160, 80))
        let ay = Int(clamp(alt / 240.0, 0, 1) * 136)
        b.fillRect(298, 228 - ay - 1, 14, 3, yellow)
        if phase == .flying {
            if agl < 10 && (frame / 6) & 1 == 0 { ctext(b, "PULL UP!", 120, SkyGlider64.cRed, 4) }
            else if speed < 0.3 && (frame / 10) & 1 == 0 { ctext(b, "STALL", 120, yellow, 3) }
        }
        // drop-shadow lines to ground-impact warning handled above
    }

    private func drawOverlays(_ b: TrueColorBuffer) {
        let yellow = SkyGlider64.cYellow
        let white = SkyGlider64.cWhite
        switch phase {
        case .title:
            b.fillRect(22, 56, 276, 168, SkyGlider64.cBlack)
            b.fillRect(24, 58, 272, 164, SkyGlider64.cPanel)
            b.fillRect(24, 58, 272, 3, yellow)
            b.fillRect(24, 219, 272, 3, yellow)
            ctext(b, "SKY GLIDER", 70, yellow, 6)
            ctext(b, "64", 112, white, 8)
            ctext(b, "FLY THROUGH 20 RINGS", 160, white, 2)
            if (frame / 30) & 1 == 0 { ctext(b, "PRESS A TO FLY", 184, SkyGlider64.cGreen, 3) }
            ctext(b, "UP/DOWN PITCH  LEFT/RIGHT BANK", 206, SkyGlider64.cCyan, 1)
            ctext(b, "A BOOST  B AIR BRAKE", 236, white, 2)
        case .flying:
            if msgTimer > 0 { ctext(b, msg, 96, yellow, 3) }
        case .crash:
            if crashTimer > 40 { ctext(b, "CRASH!", 110, SkyGlider64.cRed, 6) }
        case .results:
            b.fillRect(38, 50, 244, 190, SkyGlider64.cBlack)
            b.fillRect(40, 52, 240, 186, SkyGlider64.cPanel)
            b.fillRect(40, 52, 240, 3, yellow)
            var head = "CRASHED"
            if endReason == 1 { head = "TIME UP" }
            if endReason == 2 { head = "COURSE CLEAR" }
            ctext(b, head, 64, endReason == 2 ? SkyGlider64.cGreen : SkyGlider64.cRed, 4)
            ctext(b, "RINGS " + String(ringsHit) + "/" + String(SkyGlider64.totalRings), 108, white, 2)
            if endReason == 2 {
                ctext(b, "TIME BONUS " + String(finishBonus), 130, white, 2)
            } else {
                ctext(b, "TIME LEFT " + timeText() + "S", 130, white, 2)
            }
            ctext(b, "SCORE", 160, white, 2)
            ctext(b, zeroPad(scoreValue, 6), 180, yellow, 4)
            if resultTimer > 40 && (frame / 30) & 1 == 0 { ctext(b, "PRESS A", 216, white, 2) }
        }
    }
}

extension Cartridge {
    static let skyGlider64 = Cartridge(
        id: "skyglider64", title: "SKY GLIDER 64", genre: "Flight",
        blurb: "Soar over a voxel landscape of rivers, forests and snowy peaks. Thread glowing rings to buy more time before you run out of sky.",
        controls: "UP climb, DOWN dive, LEFT/RIGHT bank, A boost, B air brake. Dive for speed.",
        era: .n64, labelTop: 0x58B8F0, labelBottom: 0x2E6A3C, factory: { SkyGlider64() })
}
