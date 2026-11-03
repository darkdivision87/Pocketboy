#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// TUNNEL RUN 64: a demoscene-style tunnel racer. The tunnel is drawn per pixel from precomputed angle and
/// depth lookup tables (polar technique): each frame only the scroll, twist and vanishing-point sway change.
/// Obstacles live in tunnel space (32 sectors around the rim x depth) and are rasterised through a per-depth
/// bucket table, so they perspective-scale for free. Orbit the rim, boost, brake, collect fuel rings.
final class TunnelRun64: Game {
    // MARK: - Types

    private enum Phase { case title, ready, play, over }

    private struct Obs {
        var kind = 0
        var z: Float = 0
        var len: Float = 40
        var mask: UInt32 = 0
        var spin = 1
        var t = 0
        var hit = false
        var checked = false
        var dead = false
        var minD = 99
    }

    private struct Spark {
        var x: Float = 0
        var y: Float = 0
        var vx: Float = 0
        var vy: Float = 0
        var life = 1
        var maxLife = 1
        var col: UInt32 = 0
    }

    /// Precomputed per-pixel polar tables (angle 0..1023, depth 0..4095) plus colour lookup tables.
    private final class Tables {
        static let tw = 448
        static let th = 416
        let ang: UnsafeMutablePointer<Int16>
        let dep: UnsafeMutablePointer<UInt16>
        let fog: UnsafeMutablePointer<Int>
        let lut: UnsafeMutablePointer<UInt32>
        let olut: UnsafeMutablePointer<UInt32>

        init() {
            let tw = Tables.tw
            let th = Tables.th
            let n = tw * th
            let a = UnsafeMutablePointer<Int16>.allocate(capacity: n)
            let d = UnsafeMutablePointer<UInt16>.allocate(capacity: n)
            let twoPi: Float = 2 * Float.pi
            for ty in 0..<th {
                for tx in 0..<tw {
                    let dx: Float = Float(tx - 224) + 0.5
                    let dy: Float = Float(ty - 208) + 0.5
                    let r: Float = max(0.5, sqrt(dx * dx + dy * dy))
                    let an: Float = atan2(dy, dx)
                    var ai = Int((an + Float.pi) / twoPi * 1024)
                    if ai < 0 { ai = 0 }
                    if ai > 1023 { ai = 1023 }
                    var di = Int(TunnelRun64.depthK / r)
                    if di > 4095 { di = 4095 }
                    if di < 0 { di = 0 }
                    let idx = ty * tw + tx
                    a[idx] = Int16(ai)
                    d[idx] = UInt16(di)
                }
            }
            let f = UnsafeMutablePointer<Int>.allocate(capacity: 128)
            for i in 0..<128 {
                var t: Float = (Float(i * 32) - 100) / 1700
                if t < 0 { t = 0 }
                if t > 1 { t = 1 }
                f[i] = Int(t * 15)
            }
            let wc: [Int] = [28, 36, 120, 54, 46, 152, 70, 255, 255, 255, 60, 210, 255, 255, 255]
            let l = UnsafeMutablePointer<UInt32>.allocate(capacity: 80)
            for pi in 0..<5 {
                for lv in 0..<16 {
                    l[pi * 16 + lv] = Tables.fogged(wc[pi * 3], wc[pi * 3 + 1], wc[pi * 3 + 2], lv)
                }
            }
            let oc: [Int] = [255, 214, 30, 232, 40, 40, 200, 64, 124, 124, 22, 84,
                             90, 255, 150, 30, 172, 102, 70, 215, 255, 30, 124, 190, 255, 255, 255]
            let o = UnsafeMutablePointer<UInt32>.allocate(capacity: 144)
            for ti in 0..<9 {
                for lv in 0..<16 {
                    o[ti * 16 + lv] = Tables.fogged(oc[ti * 3], oc[ti * 3 + 1], oc[ti * 3 + 2], lv)
                }
            }
            self.ang = a
            self.dep = d
            self.fog = f
            self.lut = l
            self.olut = o
        }

        static func fogged(_ r: Int, _ g: Int, _ b: Int, _ lv: Int) -> UInt32 {
            let t: Float = Float(lv) / 15
            let fr: Float = Float(r) + Float(16 - r) * t
            let fg: Float = Float(g) + Float(6 - g) * t
            let fb: Float = Float(b) + Float(38 - b) * t
            return TrueColorBuffer.rgb(Int(fr), Int(fg), Int(fb))
        }
    }

    // MARK: - Constants

    private static let depthK: Float = 14000
    private static let shipDepth: Float = 120
    private static let sectors = 32

    private static let kWall = 0
    private static let kBarrier = 1
    private static let kSpoke = 2
    private static let kMine = 3
    private static let kPick = 4

    private static let cWhite: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    private static let cBlack: UInt32 = TrueColorBuffer.rgb(8, 6, 20)
    private static let cYellow: UInt32 = TrueColorBuffer.rgb(255, 226, 64)
    private static let cRed: UInt32 = TrueColorBuffer.rgb(255, 80, 64)
    private static let cGreen: UInt32 = TrueColorBuffer.rgb(100, 255, 140)
    private static let cCyan: UInt32 = TrueColorBuffer.rgb(110, 240, 255)
    private static let cMagenta: UInt32 = TrueColorBuffer.rgb(255, 90, 220)
    private static let cPanel: UInt32 = TrueColorBuffer.rgb(14, 12, 48)

    private static let tables = Tables()
    private static let mineW: [Int] = [2, 3, 4, 3]

    // MARK: - State

    private var phase: Phase = .title
    private var tick = 0
    private var rng = Rng()

    private let hf = UnsafeMutablePointer<UInt32>.allocate(capacity: 2048)
    private let ht = UnsafeMutablePointer<UInt32>.allocate(capacity: 2048)
    private let pf = UnsafeMutablePointer<UInt32>.allocate(capacity: 2048)
    private let pt = UnsafeMutablePointer<UInt32>.allocate(capacity: 2048)
    private let anyB = UnsafeMutablePointer<UInt32>.allocate(capacity: 2048)

    private var shipPos: Float = 24
    private var steerV: Float = 0
    private var speed: Float = 7
    private var travel: Float = 0
    private var boosting = false
    private var energy: Float = 100
    private var lives = 3
    private var invuln = 0
    private var shake = 0
    private var flashT = 0
    private var dist: Float = 0
    private var bonus = 0
    private var nearMisses = 0
    private var combo = 0
    private var pickups = 0
    private var playTicks = 0
    private var readyT = 0
    private var overT = 0
    private var bannerT = 0
    private var bannerText = ""
    private var bestSpeed: Float = 0

    private var curveT: Float = 0
    private var swayX = 0
    private var swayY = 0
    private var twist = 0
    private var rotAng = 0

    private var obs: [Obs] = []
    private var spawnCount = 0
    private var lastSafe = 24
    private var sparks: [Spark] = []

    private var dustAng = [Float](repeating: 0, count: 56)
    private var dustD = [Float](repeating: 500, count: 56)
    private var dustF = [Float](repeating: 0.5, count: 56)

    override var score: Int { return max(0, Int(dist) + bonus) }

    override init() {
        super.init()
        for i in 0..<2048 {
            hf[i] = 0
            ht[i] = 0
            pf[i] = 0
            pt[i] = 0
            anyB[i] = 0
        }
        _ = TunnelRun64.tables
        resetGame()
    }

    deinit {
        hf.deallocate()
        ht.deallocate()
        pf.deallocate()
        pt.deallocate()
        anyB.deallocate()
    }

    override func start() {
        playMusic(Tunes.arcade)
    }

    // MARK: - Setup

    private func resetGame() {
        phase = .title
        tick = 0
        shipPos = 24
        steerV = 0
        speed = 7
        travel = 0
        boosting = false
        energy = 100
        lives = 3
        invuln = 0
        shake = 0
        flashT = 0
        dist = 0
        bonus = 0
        nearMisses = 0
        combo = 0
        pickups = 0
        playTicks = 0
        readyT = 0
        overT = 0
        bannerT = 0
        bannerText = ""
        bestSpeed = 0
        curveT = 0
        obs.removeAll()
        sparks.removeAll()
        spawnCount = 0
        lastSafe = 24
        for i in 0..<56 {
            dustAng[i] = Float(rng.int(628)) / 100
            dustD[i] = Float(rng.range(80, 3400))
            dustF[i] = 0.15 + Float(rng.int(80)) / 100
        }
        for i in 0..<4 {
            spawnObstacle(1300 + Float(i) * 300)
        }
        updateSway()
        buildBuckets()
    }

    private func beginReady() {
        resetGame()
        phase = .ready
        readyT = 200
        playMusic(Tunes.arcade)
    }

    // MARK: - Helpers

    private static func cf(_ v: Float, _ lo: Float, _ hi: Float) -> Float {
        if !v.isFinite { return 0 }
        return min(max(v, lo), hi)
    }

    private func difficulty() -> Float {
        return min(1, Float(playTicks) / 5400)
    }

    private func arcMask(_ start: Int, _ count: Int) -> UInt32 {
        var m: UInt32 = 0
        let n = min(32, max(0, count))
        if n == 0 { return 0 }
        for i in 0..<n {
            let s = (((start + i) % 32) + 32) % 32
            m |= UInt32(1) << UInt32(s)
        }
        return m
    }

    private func rotMask(_ m: UInt32, _ k: Int) -> UInt32 {
        let kk = ((k % 32) + 32) % 32
        if kk == 0 { return m }
        return (m << UInt32(kk)) | (m >> UInt32(32 - kk))
    }

    private func maskOf(_ o: Obs) -> UInt32 {
        if o.kind == TunnelRun64.kSpoke {
            return rotMask(o.mask, (o.t / 6) * o.spin)
        }
        if o.kind == TunnelRun64.kMine {
            let wd = TunnelRun64.mineW[(o.t / 10) & 3]
            var m: UInt32 = 0
            for s in 0..<32 {
                if (o.mask >> UInt32(s)) & 1 != 0 {
                    m |= arcMask(s - wd / 2, wd)
                }
            }
            return m
        }
        return o.mask
    }

    private func shipCenter() -> Int {
        return (Int(shipPos + 0.5) % 32 + 32) % 32
    }

    private func shipMask() -> UInt32 {
        return arcMask(shipCenter() - 1, 3)
    }

    private func bitDist(_ m: UInt32, _ c: Int) -> Int {
        if m == 0 { return 99 }
        for k in 0...16 {
            let a = (((c + k) % 32) + 32) % 32
            let b = (((c - k) % 32) + 32) % 32
            if (m >> UInt32(a)) & 1 != 0 { return k }
            if (m >> UInt32(b)) & 1 != 0 { return k }
        }
        return 99
    }

    // MARK: - Spawning

    private func spawnObstacle(_ z: Float) {
        spawnCount += 1
        let diff = difficulty()
        var o = Obs()
        o.z = z
        if spawnCount % 5 == 3 {
            o.kind = TunnelRun64.kPick
            o.len = 16
            let c = lastSafe + rng.range(-5, 5)
            o.mask = arcMask(c - 3, 6)
            obs.append(o)
            return
        }
        let r = rng.int(100)
        if r < 36 {
            o.kind = TunnelRun64.kWall
            o.len = 36
            let g = 9 - Int(diff * 4)
            let shiftMax = 6 - Int(diff * 1.5)
            let c = lastSafe + rng.range(-shiftMax, shiftMax)
            o.mask = ~arcMask(c - g / 2, g)
            lastSafe = ((c % 32) + 32) % 32
        } else if r < 54 && spawnCount > 6 {
            o.kind = TunnelRun64.kSpoke
            o.len = 60
            let s0 = rng.int(32)
            o.mask = arcMask(s0, 2) | arcMask(s0 + 11, 2) | arcMask(s0 + 21, 2)
            o.spin = rng.chance(50) ? 1 : -1
        } else if r < 80 {
            o.kind = TunnelRun64.kMine
            o.len = 26
            var count = 1
            if diff > 0.35 { count += 1 }
            if diff > 0.7 { count += 1 }
            var m: UInt32 = 0
            for _ in 0..<count {
                let c = lastSafe + rng.range(5, 25)
                m |= UInt32(1) << UInt32(((c % 32) + 32) % 32)
            }
            o.mask = m
        } else {
            o.kind = TunnelRun64.kBarrier
            o.len = 44
            let n = rng.range(8, 16)
            let start = lastSafe + 4 + rng.int(24 - n + 1)
            o.mask = arcMask(start, n)
        }
        obs.append(o)
    }

    // MARK: - Update

    private func updateSway() {
        let ct = curveT
        let sx: Float = sin(ct) * 30 + sin(ct * 2.3 + 1) * 12
        let sy: Float = sin(ct * 1.7 + 2) * 12
        swayX = Int(TunnelRun64.cf(sx, -40, 40))
        swayY = Int(TunnelRun64.cf(sy, -16, 16))
        twist = Int(TunnelRun64.cf(sin(ct * 0.9) * 6, -6, 6))
        rotAng = Int(TunnelRun64.cf(sin(ct * 0.6) * 120, -200, 200))
    }

    private func moveWorld() {
        travel += speed
        if travel > 65536 { travel -= 65536 }
        curveT += 0.006 + speed * 0.0005
        if curveT > 1000 { curveT -= 1000 }
        updateSway()
        for i in 0..<56 {
            dustD[i] -= speed * 0.9 + 1
            if dustD[i] < 70 {
                dustD[i] += 3300
                dustAng[i] = Float(rng.int(628)) / 100
                dustF[i] = 0.15 + Float(rng.int(80)) / 100
            }
        }
        for i in 0..<sparks.count {
            sparks[i].x += sparks[i].vx
            sparks[i].y += sparks[i].vy
            sparks[i].vy += 0.05
            sparks[i].life -= 1
        }
        sparks.removeAll(where: { $0.life <= 0 })
    }

    override func update(_ input: InputState) {
        tick += 1
        if shake > 0 { shake -= 1 }
        if flashT > 0 { flashT -= 1 }
        if invuln > 0 { invuln -= 1 }
        switch phase {
        case .title:
            speed = 7
            moveWorld()
            shipPos += 0.12
            if shipPos >= 32 { shipPos -= 32 }
            for i in 0..<obs.count {
                obs[i].z -= speed
                obs[i].t += 1
            }
            refillObstacles()
            obs.removeAll(where: { $0.dead || $0.z + $0.len < -20 })
            buildBuckets()
            if input.aPressed || input.startPressed {
                play(.confirm)
                beginReady()
            }
        case .ready:
            readyT -= 1
            speed += (5 - speed) * 0.1
            moveWorld()
            steerShip(input)
            if readyT == 190 || readyT == 130 || readyT == 70 { play(.countdown) }
            if readyT <= 0 {
                phase = .play
                play(.confirm)
                bannerText = "GO!"
                bannerT = 60
            }
            buildBuckets()
        case .play:
            updatePlay(input)
        case .over:
            overT += 1
            speed *= 0.975
            moveWorld()
            for i in 0..<obs.count {
                obs[i].z -= speed
                obs[i].t += 1
            }
            obs.removeAll(where: { $0.dead || $0.z + $0.len < -20 })
            buildBuckets()
            if overT > 70 && (input.aPressed || input.startPressed) {
                play(.confirm)
                beginReady()
            }
        }
        if bannerT > 0 { bannerT -= 1 }
    }

    private func steerShip(_ input: InputState) {
        let target: Float = Float(input.dx) * 0.55
        steerV += (target - steerV) * 0.3
        shipPos -= steerV
        while shipPos >= 32 { shipPos -= 32 }
        while shipPos < 0 { shipPos += 32 }
    }

    private func refillObstacles() {
        let spacing: Float = 330 - difficulty() * 130
        var far: Float = 0
        for o in obs { if o.z > far { far = o.z } }
        if far < 2500 - spacing {
            spawnObstacle(2500)
        }
    }

    private func updatePlay(_ input: InputState) {
        playTicks += 1
        let diff = difficulty()
        let base: Float = 7 + diff * 11
        var target: Float = base
        boosting = false
        if input.b {
            target = max(3.5, base * 0.5)
        } else if input.a && energy > 0 {
            target = base * 1.6
            boosting = true
            energy -= 0.5
            if energy < 0 { energy = 0 }
        } else {
            energy = min(100, energy + 0.02)
        }
        speed += (target - speed) * 0.07
        if speed > bestSpeed { bestSpeed = speed }
        steerShip(input)
        moveWorld()
        dist += speed * 0.03
        if playTicks % 600 == 0 {
            bannerText = "SPEED UP"
            bannerT = 70
            play(.powerup)
        }
        if playTicks % 90 == 0 { combo = max(0, combo - 1) }

        let zp = TunnelRun64.shipDepth
        let sm = shipMask()
        let c = shipCenter()
        for i in 0..<obs.count {
            var o = obs[i]
            o.z -= speed
            o.t += 1
            let m = maskOf(o)
            let overlap = o.z <= zp + 10 && o.z + o.len + speed >= zp - 10
            if overlap && !o.hit && !o.dead {
                if o.kind == TunnelRun64.kPick {
                    if (m & sm) != 0 {
                        o.dead = true
                        energy = min(100, energy + 40)
                        pickups += 1
                        bonus += 100
                        play(.powerup)
                        bannerText = "FUEL +40"
                        bannerT = 50
                        addSparks(60)
                    }
                } else {
                    let d = bitDist(m, c)
                    if d < o.minD { o.minD = d }
                    if (m & sm) != 0 && invuln == 0 {
                        o.hit = true
                        hitShip()
                    }
                }
            }
            if !o.checked && o.z + o.len < zp - 10 {
                o.checked = true
                if o.kind != TunnelRun64.kPick && !o.hit && o.minD >= 2 && o.minD <= 3 {
                    nearMisses += 1
                    combo += 1
                    let pts = 50 + 25 * min(combo, 8)
                    bonus += pts
                    bannerText = "NEAR MISS +" + String(pts)
                    bannerT = 45
                    play(.blip)
                }
            }
            if o.z + o.len < -20 { o.dead = true }
            obs[i] = o
        }
        obs.removeAll(where: { $0.dead })
        refillObstacles()
        buildBuckets()
    }

    private func hitShip() {
        lives -= 1
        invuln = 100
        shake = 14
        flashT = 14
        combo = 0
        speed *= 0.55
        addSparks(40)
        if lives <= 0 {
            lives = 0
            phase = .over
            overT = 0
            addSparks(80)
            playMusic(nil)
            play(.death)
        } else {
            play(.hurt)
        }
    }

    private func shipScreen() -> (Float, Float) {
        let phi: Float = shipPos / 32 * 2 * Float.pi - Float.pi
        let rs: Float = TunnelRun64.depthK / TunnelRun64.shipDepth - 14
        let sx: Float = Float(160 + swayX) + cos(phi) * rs
        let sy: Float = Float(144 + swayY) + sin(phi) * rs
        return (sx, sy)
    }

    private func addSparks(_ n: Int) {
        if sparks.count > 200 { return }
        let pos = shipScreen()
        for _ in 0..<n {
            var s = Spark()
            s.x = pos.0
            s.y = pos.1
            let a: Float = Float(rng.int(628)) / 100
            let v: Float = 0.5 + Float(rng.int(100)) / 25
            s.vx = cos(a) * v
            s.vy = sin(a) * v
            s.life = rng.range(14, 36)
            s.maxLife = s.life
            let k = rng.int(3)
            if k == 0 { s.col = TunnelRun64.cYellow } else if k == 1 { s.col = TunnelRun64.cWhite } else { s.col = TunnelRun64.cMagenta }
            sparks.append(s)
        }
    }

    // MARK: - Bucket table

    private func buildBuckets() {
        for i in 0..<2048 {
            hf[i] = 0
            ht[i] = 0
            pf[i] = 0
            pt[i] = 0
            anyB[i] = 0
        }
        for o in obs {
            let m = maskOf(o)
            if m == 0 { continue }
            let isPick = o.kind == TunnelRun64.kPick
            let zf: Float = TunnelRun64.cf(o.z, -1000, 6000)
            if zf > 1 {
                let b0 = max(0, Int(zf) >> 1)
                let b1 = min(2047, Int(zf * 1.54) >> 1)
                if b0 <= b1 {
                    for k in b0...b1 {
                        if isPick { pf[k] |= m } else { hf[k] |= m }
                        anyB[k] |= m
                    }
                }
            }
            let startD: Float = max(0, zf * 1.54)
            let endD: Float = (zf + o.len) * 1.54
            let t0 = max(0, Int(startD) >> 1)
            let t1 = min(2047, Int(max(0, endD)) >> 1)
            if t0 <= t1 {
                for k in t0...t1 {
                    if isPick { pt[k] |= m } else { ht[k] |= m }
                    anyB[k] |= m
                }
            }
        }
    }

    // MARK: - Pixel helpers

    private static func hspan(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ y: Int, _ x0: Int, _ x1: Int, _ c: UInt32) {
        if y < 0 || y >= h { return }
        let a = max(0, x0)
        let b = min(w - 1, x1)
        if a > b { return }
        let base = y * w
        var x = a
        while x <= b {
            p[base + x] = c
            x += 1
        }
    }

    private static func rectP(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: UInt32) {
        if rw <= 0 || rh <= 0 { return }
        let y0 = max(0, y)
        let y1 = min(h, y + rh)
        if y0 >= y1 { return }
        for yy in y0..<y1 {
            TunnelRun64.hspan(p, w, h, yy, x, x + rw - 1, c)
        }
    }

    private static func disc(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int, _ cx: Float, _ cy: Float, _ r: Float, _ c: UInt32) {
        let rr: Float = TunnelRun64.cf(r, 0, 300)
        let ri = max(1, Int(rr + 0.5))
        let cxi = Int(TunnelRun64.cf(cx, -2000, 2000))
        let cyi = Int(TunnelRun64.cf(cy, -2000, 2000))
        let y0 = max(0, cyi - ri)
        let y1 = min(h - 1, cyi + ri)
        if y0 > y1 { return }
        for y in y0...y1 {
            let dy = y - cyi
            let q = ri * ri - dy * dy
            if q < 0 { continue }
            let half = Int(sqrt(Float(q)))
            TunnelRun64.hspan(p, w, h, y, cxi - half, cxi + half, c)
        }
    }

    private static func edge(_ ax: Float, _ ay: Float, _ bx: Float, _ by: Float, _ fy: Float, _ lo: inout Float, _ hi: inout Float) {
        let mn: Float = min(ay, by)
        let mx: Float = max(ay, by)
        if fy >= mn && fy < mx {
            let t: Float = (fy - ay) / (by - ay)
            let x: Float = ax + t * (bx - ax)
            if x < lo { lo = x }
            if x > hi { hi = x }
        }
    }

    private static func tri(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int,
                            _ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float, _ c: UInt32) {
        let ax: Float = TunnelRun64.cf(x0, -2000, 2000)
        let ay: Float = TunnelRun64.cf(y0, -2000, 2000)
        let bx: Float = TunnelRun64.cf(x1, -2000, 2000)
        let by: Float = TunnelRun64.cf(y1, -2000, 2000)
        let cx: Float = TunnelRun64.cf(x2, -2000, 2000)
        let cy: Float = TunnelRun64.cf(y2, -2000, 2000)
        let ymin = max(0, Int(min(ay, min(by, cy))))
        let ymax = min(h - 1, Int(max(ay, max(by, cy))) + 1)
        if ymin > ymax { return }
        for y in ymin...ymax {
            let fy: Float = Float(y) + 0.5
            var lo: Float = 100000
            var hi: Float = -100000
            TunnelRun64.edge(ax, ay, bx, by, fy, &lo, &hi)
            TunnelRun64.edge(bx, by, cx, cy, fy, &lo, &hi)
            TunnelRun64.edge(cx, cy, ax, ay, fy, &lo, &hi)
            if lo <= hi {
                TunnelRun64.hspan(p, w, h, y, Int(lo + 0.5), Int(hi - 0.5), c)
            }
        }
    }

    private static func lineP(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int,
                              _ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float, _ c: UInt32) {
        let ax: Float = TunnelRun64.cf(x0, -1500, 1500)
        let ay: Float = TunnelRun64.cf(y0, -1500, 1500)
        let bx: Float = TunnelRun64.cf(x1, -1500, 1500)
        let by: Float = TunnelRun64.cf(y1, -1500, 1500)
        let dx: Float = bx - ax
        let dy: Float = by - ay
        let steps = min(300, max(1, Int(max(abs(dx), abs(dy)))))
        let sx: Float = dx / Float(steps)
        let sy: Float = dy / Float(steps)
        var fx: Float = ax
        var fy: Float = ay
        for _ in 0...steps {
            TunnelRun64.rectP(p, w, h, Int(fx), Int(fy), 1, 1, c)
            fx += sx
            fy += sy
        }
    }

    // MARK: - Rendering

    override func drawTrueColor(_ b: TrueColorBuffer) {
        b.withPixels { p, w, h in
            if w < 320 || h < 288 { return }
            self.renderTunnel(p, w, h)
            self.renderSprites(p, w, h)
        }
        drawHUD(b)
        drawOverlays(b)
    }

    private func renderTunnel(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        let t = TunnelRun64.tables
        let tw = Tables.tw
        var ox = swayX
        var oy = swayY
        if shake > 0 {
            ox += ((tick & 1) == 0) ? 3 : -3
            oy += ((tick & 2) == 0) ? 2 : -2
        }
        ox = max(-48, min(48, ox))
        oy = max(-24, min(24, oy))
        let rot = rotAng
        let tws = twist
        let scroll = Int(travel) & 4095
        let flash = (tick >> 3) & 1
        let ang = t.ang
        let dep = t.dep
        let fog = t.fog
        let lut = t.lut
        let olut = t.olut
        let hfP = hf
        let htP = ht
        let pfP = pf
        let anyP = anyB
        for y in 0..<h {
            let rowIdx = (y + 64 - oy) * tw + 64 - ox
            let outBase = y * w
            var x = 0
            while x < w {
                let idx = rowIdx + x
                let a = Int(ang[idx])
                let d = Int(dep[idx])
                let u = (a + rot + ((d * tws) >> 6)) & 1023
                let v = d + scroll
                let su = u >> 5
                var sh = 6
                if d >= 1024 { sh = 8 } else if d >= 512 { sh = 7 }
                var pi = (su ^ (v >> sh)) & 1
                if d < 1024 && (v & 63) < 4 { pi = 2 }
                if (u & 31) < 2 && (su & 1) == 0 {
                    pi = (pi == 2) ? 4 : 3
                }
                let lv = fog[d >> 5]
                var col = lut[pi * 16 + lv]
                let bk = d >> 1
                let m = anyP[bk]
                if m != 0 {
                    let sec = a >> 5
                    let bit: UInt32 = UInt32(1) << UInt32(sec)
                    if (m & bit) != 0 {
                        var ty = 6
                        if (hfP[bk] & bit) != 0 {
                            ty = 0
                        } else if (pfP[bk] & bit) != 0 {
                            ty = 4
                        } else if (htP[bk] & bit) != 0 {
                            ty = 2
                        }
                        let lv2 = lv > 10 ? 10 : lv
                        if (a & 31) < 2 {
                            col = olut[8 * 16 + lv2]
                        } else {
                            let stripe = ((a >> 3) + (d >> 3) + flash) & 1
                            col = olut[(ty + stripe) * 16 + lv2]
                        }
                    }
                }
                p[outBase + x] = col
                x += 1
            }
        }
        // light at the end of the tunnel
        let vx = Float(160 + ox)
        let vy = Float(144 + oy)
        let pulse: Float = 4 + sin(Float(tick) * 0.15) * 1.5
        TunnelRun64.disc(p, w, h, vx, vy, pulse + 3, TrueColorBuffer.rgb(120, 40, 160))
        TunnelRun64.disc(p, w, h, vx, vy, pulse, TrueColorBuffer.rgb(255, 150, 240))
        TunnelRun64.disc(p, w, h, vx, vy, pulse * 0.5, TunnelRun64.cWhite)
    }

    private func renderSprites(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        let vx: Float = Float(160 + swayX)
        let vy: Float = Float(144 + swayY)
        let k: Float = TunnelRun64.depthK
        // dust / speed lines
        let streak: Float = speed * 3 + 6
        for i in 0..<56 {
            let d = dustD[i]
            if d < 70 { continue }
            let a = dustAng[i]
            let f = dustF[i]
            let r1: Float = k * f / d
            let r2: Float = k * f / (d + streak)
            let ca: Float = cos(a)
            let sa: Float = sin(a)
            var bv = Int(300 - d / 14)
            if bv > 255 { bv = 255 }
            if bv < 70 { bv = 70 }
            let c = TrueColorBuffer.rgb(bv, bv, 255)
            TunnelRun64.lineP(p, w, h, vx + ca * r1, vy + sa * r1, vx + ca * r2, vy + sa * r2, c)
        }
        // sparks
        for s in sparks {
            let tl: Float = Float(s.life) / Float(max(1, s.maxLife))
            let sz = tl > 0.5 ? 3 : 2
            TunnelRun64.rectP(p, w, h, Int(TunnelRun64.cf(s.x, -100, 500)), Int(TunnelRun64.cf(s.y, -100, 500)), sz, sz, s.col)
        }
        if phase == .over && lives <= 0 { return }
        drawShip(p, w, h)
    }

    private func drawShip(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        if invuln > 0 && (tick / 3) % 2 == 0 { return }
        let pos = shipScreen()
        let sx = pos.0
        let sy = pos.1
        let phi: Float = shipPos / 32 * 2 * Float.pi - Float.pi
        let psi: Float = phi + Float.pi + steerV * 0.6
        let nx: Float = cos(psi)
        let ny: Float = sin(psi)
        let qx: Float = -ny
        let qy: Float = nx
        func ox(_ lx: Float, _ ly: Float) -> Float { return sx + lx * qx + ly * nx }
        func oy(_ lx: Float, _ ly: Float) -> Float { return sy + lx * qy + ly * ny }
        let body = TrueColorBuffer.rgb(240, 246, 255)
        let wing = TrueColorBuffer.rgb(255, 90, 210)
        let wingD = TrueColorBuffer.rgb(190, 50, 170)
        let dark = TrueColorBuffer.rgb(10, 8, 30)
        let flameLen: Float = boosting ? 22 : 10
        let fl: Float = flameLen + Float(tick & 3) * 2
        let flameC = (tick & 1) == 0 ? TrueColorBuffer.rgb(255, 210, 70) : TrueColorBuffer.rgb(255, 120, 40)
        // outline
        TunnelRun64.tri(p, w, h, ox(0, 21), oy(0, 21), ox(-11, -12), oy(-11, -12), ox(11, -12), oy(11, -12), dark)
        TunnelRun64.tri(p, w, h, ox(-18, -16), oy(-18, -16), ox(-5, 2), oy(-5, 2), ox(-5, -12), oy(-5, -12), dark)
        TunnelRun64.tri(p, w, h, ox(18, -16), oy(18, -16), ox(5, 2), oy(5, 2), ox(5, -12), oy(5, -12), dark)
        // flame
        TunnelRun64.tri(p, w, h, ox(-4, -11), oy(-4, -11), ox(4, -11), oy(4, -11), ox(0, -11 - fl), oy(0, -11 - fl), flameC)
        // wings
        TunnelRun64.tri(p, w, h, ox(-16, -14), oy(-16, -14), ox(-5, 0), oy(-5, 0), ox(-5, -10), oy(-5, -10), wing)
        TunnelRun64.tri(p, w, h, ox(16, -14), oy(16, -14), ox(5, 0), oy(5, 0), ox(5, -10), oy(5, -10), wingD)
        // body
        TunnelRun64.tri(p, w, h, ox(0, 19), oy(0, 19), ox(-9, -10), oy(-9, -10), ox(9, -10), oy(9, -10), body)
        TunnelRun64.disc(p, w, h, ox(0, 5), oy(0, 5), 3, TunnelRun64.cCyan)
    }

    // MARK: - HUD

    private func txt(_ b: TrueColorBuffer, _ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        b.text(s, x + scale, y + scale, TunnelRun64.cBlack, scale: scale)
        b.text(s, x, y, c, scale: scale)
    }

    private func ctxt(_ b: TrueColorBuffer, _ s: String, _ y: Int, _ c: UInt32, _ scale: Int) {
        let tw = b.textWidth(s, scale: scale)
        txt(b, s, (b.width - tw) / 2, y, c, scale)
    }

    private func drawHUD(_ b: TrueColorBuffer) {
        if phase == .title { return }
        txt(b, "SCORE " + zeroPad(score, 6), 6, 6, TunnelRun64.cWhite, 2)
        txt(b, "DIST " + String(Int(dist)) + "M", 6, 24, TunnelRun64.cYellow, 1)
        // lives
        for i in 0..<3 {
            let x = 262 + i * 18
            let on = i < lives
            b.fillRect(x - 1, 5, 14, 14, TunnelRun64.cBlack)
            b.fillRect(x, 6, 12, 12, on ? TunnelRun64.cMagenta : TrueColorBuffer.rgb(50, 40, 70))
            if on { b.fillRect(x + 4, 9, 4, 6, TunnelRun64.cWhite) }
        }
        // energy bar
        b.fillRect(6, 266, 124, 16, TunnelRun64.cBlack)
        let ew = max(0, min(100, Int(energy)))
        var ec = TunnelRun64.cCyan
        if ew < 30 { ec = TunnelRun64.cRed } else if boosting { ec = TunnelRun64.cYellow }
        b.fillRect(8, 268, ew, 12, ec)
        b.text(boosting ? "BOOST" : "FUEL", 10, 271, TunnelRun64.cBlack, scale: 1)
        // speed
        let spd = Int(speed * 10)
        txt(b, "SPD " + String(spd), 236, 272, TunnelRun64.cWhite, 1)
        if combo > 1 { txt(b, "COMBO X" + String(combo), 236, 260, TunnelRun64.cGreen, 1) }
        if bannerT > 0 && phase == .play {
            ctxt(b, bannerText, 52, TunnelRun64.cWhite, 2)
        }
        if flashT > 0 {
            let th = 2 + flashT / 2
            let rc = TunnelRun64.cRed
            b.fillRect(0, 0, b.width, th, rc)
            b.fillRect(0, b.height - th, b.width, th, rc)
            b.fillRect(0, 0, th, b.height, rc)
            b.fillRect(b.width - th, 0, th, b.height, rc)
        }
    }

    private func drawOverlays(_ b: TrueColorBuffer) {
        switch phase {
        case .title:
            b.fillRect(28, 56, 264, 190, TunnelRun64.cBlack)
            b.fillRect(30, 58, 260, 186, TunnelRun64.cPanel)
            b.fillRect(30, 58, 260, 3, TunnelRun64.cMagenta)
            ctxt(b, "TUNNEL RUN", 70, TunnelRun64.cCyan, 5)
            ctxt(b, "SIXTY FOUR", 108, TunnelRun64.cMagenta, 3)
            ctxt(b, "LEFT RIGHT ORBIT THE RIM", 150, TunnelRun64.cWhite, 1)
            ctxt(b, "A BOOST   B BRAKE", 164, TunnelRun64.cWhite, 1)
            ctxt(b, "DODGE BARRIERS AND SPOKES", 178, TunnelRun64.cYellow, 1)
            ctxt(b, "GRAB GREEN RINGS FOR FUEL", 192, TunnelRun64.cGreen, 1)
            if (tick / 30) % 2 == 0 { ctxt(b, "PRESS A", 214, TunnelRun64.cWhite, 2) }
        case .ready:
            var s = "GET READY"
            if readyT > 140 { s = "3" } else if readyT > 80 { s = "2" } else if readyT > 20 { s = "1" } else { s = "GO!" }
            ctxt(b, s, 100, TunnelRun64.cYellow, 6)
            ctxt(b, "GET READY", 70, TunnelRun64.cWhite, 2)
        case .play:
            break
        case .over:
            b.fillRect(38, 58, 244, 186, TunnelRun64.cBlack)
            b.fillRect(40, 60, 240, 182, TunnelRun64.cPanel)
            b.fillRect(40, 60, 240, 3, TunnelRun64.cRed)
            ctxt(b, "CRASHED", 72, TunnelRun64.cRed, 5)
            ctxt(b, "SCORE " + zeroPad(score, 6), 114, TunnelRun64.cYellow, 2)
            ctxt(b, "DISTANCE " + String(Int(dist)) + " M", 140, TunnelRun64.cWhite, 1)
            ctxt(b, "NEAR MISSES " + String(nearMisses) + "  FUEL RINGS " + String(pickups), 156, TunnelRun64.cWhite, 1)
            ctxt(b, "TOP SPEED " + String(Int(bestSpeed * 10)), 172, TunnelRun64.cCyan, 1)
            if overT > 70 && (tick / 30) % 2 == 0 { ctxt(b, "PRESS A", 204, TunnelRun64.cWhite, 2) }
        }
    }
}

extension Cartridge {
    static let tunnelRun64 = Cartridge(
        id: "tunnelrun64", title: "TUNNEL RUN 64", genre: "Racing",
        blurb: "Race the rim of an endless neon tunnel. Per-pixel polar rendering, swaying curves, barriers, spokes and mines at ever-higher speed.",
        controls: "LEFT/RIGHT orbit the rim, A boost, B brake.",
        era: .n64, labelTop: 0xE040C8, labelBottom: 0x101040, factory: { TunnelRun64() })
}
