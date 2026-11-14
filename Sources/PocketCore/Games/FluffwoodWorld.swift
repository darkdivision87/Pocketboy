#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

// FLUFFWOOD 64 : world generation, prop data and the software "painter" used for every sprite.

enum FluffMath {
    @inline(__always) static func i(_ f: Float) -> Int {
        if !f.isFinite { return 0 }
        if f > 30000 { return 30000 }
        if f < -30000 { return -30000 }
        return Int(f)
    }

    @inline(__always) static func clampF(_ v: Float, _ lo: Float, _ hi: Float) -> Float {
        if !v.isFinite { return lo }
        return min(max(v, lo), hi)
    }

    @inline(__always) static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a + (b - a) * t
    }

    @inline(__always) static func smooth(_ t: Float) -> Float {
        let c: Float = clampF(t, 0, 1)
        return c * c * (3 - 2 * c)
    }

    static func wrap(_ v: Float) -> Float {
        if !v.isFinite { return 0 }
        let r: Float = v - 256 * floor(v / 256)
        if r >= 256 { return 0 }
        return r
    }

    static func wrapDelta(_ d: Float) -> Float {
        if !d.isFinite { return 0 }
        return d - 256 * floor(d / 256 + 0.5)
    }

    static func wrapAngle(_ a: Float) -> Float {
        if !a.isFinite { return 0 }
        var d = a
        while d > Float.pi { d -= 2 * Float.pi }
        while d < -Float.pi { d += 2 * Float.pi }
        return d
    }

    static func rgb(_ r: Float, _ g: Float, _ b: Float) -> UInt32 {
        let ri: Int = max(0, min(255, i(r)))
        let gi: Int = max(0, min(255, i(g)))
        let bi: Int = max(0, min(255, i(b)))
        return 0xFF00_0000 | UInt32(ri) | (UInt32(gi) << 8) | (UInt32(bi) << 16)
    }

    static func mixPix(_ a: UInt32, _ b: UInt32, _ t256: Int) -> UInt32 {
        let t: Int = max(0, min(256, t256))
        let it: Int = 256 - t
        let r: Int = (Int(a & 255) * it + Int(b & 255) * t) >> 8
        let g: Int = (Int((a >> 8) & 255) * it + Int((b >> 8) & 255) * t) >> 8
        let bl: Int = (Int((a >> 16) & 255) * it + Int((b >> 16) & 255) * t) >> 8
        return 0xFF00_0000 | UInt32(r & 255) | (UInt32(g & 255) << 8) | (UInt32(bl & 255) << 16)
    }
}

enum FluffKind {
    static let tree = 0
    static let blossom = 1
    static let hive = 2
    static let palm = 3
    static let bush = 4
    static let shells = 5
    static let flower = 6
    static let rock = 7
    static let crystal = 8
    static let mushroom = 9
}

struct FluffProp {
    var x: Float
    var y: Float
    var gz: Float
    var kind: Int
    var variant: Int
    var size: Float
    var region: Int
}

// MARK: - World

final class FluffWorld {
    static let shared = FluffWorld()
    static let waterLevel: Float = 3.0

    let hgt: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.allocate(capacity: 65536)
    let col: UnsafeMutablePointer<UInt32> = UnsafeMutablePointer<UInt32>.allocate(capacity: 65536)
    let reg: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: 65536)
    var props: [FluffProp] = []
    var grid: [[Int]] = [[Int]](repeating: [], count: 256)
    var spawnX: Float = 64
    var spawnY: Float = 70

    init() {
        hgt.initialize(repeating: 5, count: 65536)
        col.initialize(repeating: 0xFF00_0000, count: 65536)
        reg.initialize(repeating: 0, count: 65536)
        build()
    }

    // MARK: noise

    static func hash01(_ x: Int, _ y: Int, _ seed: Int) -> Float {
        var h: Int = x &* 374761393 &+ y &* 668265263 &+ seed &* 144269504
        h = (h ^ (h >> 13)) &* 1274126177
        h = h ^ (h >> 16)
        return Float(h & 0xFFFF) / 65535.0
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

    static func fbm(_ u: Float, _ v: Float, _ octaves: Int, _ basePeriod: Int, _ seed: Int) -> Float {
        var sum: Float = 0
        var amp: Float = 0.5
        var norm: Float = 0
        var per = basePeriod
        for o in 0..<octaves {
            let n: Float = vnoise(u * Float(per), v * Float(per), per, seed + o * 17)
            sum += amp * n
            norm += amp
            amp *= 0.5
            per *= 2
        }
        return sum / norm
    }

    static func weight(_ x: Float, _ y: Float, _ cx: Float, _ cy: Float, _ warp: Float) -> Float {
        let dx: Float = FluffMath.wrapDelta(x - cx)
        let dy: Float = FluffMath.wrapDelta(y - cy)
        let d: Float = (dx * dx + dy * dy).squareRoot() + warp
        let q: Float = max(0, d) / 46.0
        return 1.0 / (1.0 + q * q * q)
    }

    // MARK: queries

    func height(_ x: Float, _ y: Float) -> Float {
        if !(x.isFinite && y.isFinite) { return 5 }
        let wx: Float = x - 256 * floor(x / 256)
        let wy: Float = y - 256 * floor(y / 256)
        let xi = Int(wx) & 255
        let yi = Int(wy) & 255
        let fx: Float = wx - floor(wx)
        let fy: Float = wy - floor(wy)
        let x1 = (xi + 1) & 255
        let y0 = yi << 8
        let y1 = ((yi + 1) & 255) << 8
        let h00: Float = hgt[y0 + xi]
        let h10: Float = hgt[y0 + x1]
        let h01: Float = hgt[y1 + xi]
        let h11: Float = hgt[y1 + x1]
        let top: Float = h00 + (h10 - h00) * fx
        let bot: Float = h01 + (h11 - h01) * fx
        return top + (bot - top) * fy
    }

    func region(_ x: Float, _ y: Float) -> Int {
        if !(x.isFinite && y.isFinite) { return 0 }
        let wx: Float = x - 256 * floor(x / 256)
        let wy: Float = y - 256 * floor(y / 256)
        let xi = Int(wx) & 255
        let yi = Int(wy) & 255
        return Int(reg[(yi << 8) + xi])
    }

    static func cellIndex(_ cx: Int, _ cy: Int) -> Int {
        return ((cy & 15) << 4) | (cx & 15)
    }

    static func solidRadius(_ kind: Int, _ size: Float) -> Float {
        switch kind {
        case FluffKind.tree, FluffKind.blossom, FluffKind.hive: return 0.6 * size
        case FluffKind.palm: return 0.4 * size
        case FluffKind.rock: return 0.8 * size
        case FluffKind.crystal: return 0.55 * size
        default: return 0
        }
    }

    // MARK: build

    private func build() {
        let n = 65536
        var w0a = [Float](repeating: 0, count: n)
        var w1a = [Float](repeating: 0, count: n)
        var w2a = [Float](repeating: 0, count: n)

        // ponds in the meadow
        var rng = Rng(seed: 777)
        var ponds: [(Float, Float, Float)] = []
        var attempts = 0
        while ponds.count < 7 && attempts < 80 {
            attempts += 1
            let px: Float = Float(rng.unit()) * 256
            let py: Float = Float(rng.unit()) * 256
            let a0: Float = FluffWorld.weight(px, py, 64, 70, 0)
            let a1: Float = FluffWorld.weight(px, py, 192, 84, 0)
            let a2: Float = FluffWorld.weight(px, py, 120, 198, 0)
            let share: Float = a0 / (a0 + a1 + a2)
            let sdx: Float = FluffMath.wrapDelta(px - 64)
            let sdy: Float = FluffMath.wrapDelta(py - 70)
            if share > 0.6 && (sdx * sdx + sdy * sdy) > 28 * 28 {
                let pr: Float = 6 + Float(rng.unit()) * 5
                ponds.append((px, py, pr))
            }
        }

        for y in 0..<256 {
            for x in 0..<256 {
                let idx = (y << 8) + x
                let fx: Float = Float(x)
                let fy: Float = Float(y)
                let u: Float = fx / 256
                let v: Float = fy / 256
                let nn: Float = FluffWorld.fbm(u, v, 4, 3, 11)
                let wr: Float = FluffWorld.fbm(u, v, 2, 2, 99)
                let warp: Float = (wr - 0.5) * 70
                let a0: Float = FluffWorld.weight(fx, fy, 64, 70, warp)
                let a1: Float = FluffWorld.weight(fx, fy, 192, 84, warp)
                let a2: Float = FluffWorld.weight(fx, fy, 120, 198, warp)
                let sum: Float = a0 + a1 + a2 + 0.00001
                let w0: Float = a0 / sum
                let w1: Float = a1 / sum
                let w2: Float = a2 / sum
                w0a[idx] = w0
                w1a[idx] = w1
                w2a[idx] = w2
                var rid: Int = 0
                var best: Float = w0
                if w1 > best { rid = 1; best = w1 }
                if w2 > best { rid = 2 }
                reg[idx] = UInt8(rid)

                let hM: Float = 5 + nn * 13
                let sRaw: Float = (FluffWorld.fbm(u, v, 3, 2, 37) - 0.5) * 3 + 0.5
                let s: Float = FluffMath.clampF(sRaw, 0, 1)
                let hB: Float = 0.8 + s * 7
                let rr: Float = FluffWorld.fbm(u, v, 4, 2, 73)
                let ridge: Float = 1 - abs(2 * rr - 1)
                let hH: Float = 7 + ridge * 17 + nn * 4
                var hv: Float = w0 * hM + w1 * hB + w2 * hH
                for pd in ponds {
                    let dx: Float = FluffMath.wrapDelta(fx - pd.0)
                    let dy: Float = FluffMath.wrapDelta(fy - pd.1)
                    let d: Float = (dx * dx + dy * dy).squareRoot()
                    if d < pd.2 {
                        let t: Float = 1 - d / pd.2
                        let k: Float = FluffMath.smooth(t * 1.8)
                        hv = hv + (0.8 - hv) * k
                    }
                }
                hgt[idx] = hv
            }
        }

        // colours with baked lighting
        for y in 0..<256 {
            for x in 0..<256 {
                let idx = (y << 8) + x
                let h0: Float = hgt[idx]
                let hl: Float = hgt[(y << 8) + ((x - 1) & 255)]
                let hr: Float = hgt[(y << 8) + ((x + 1) & 255)]
                let hu: Float = hgt[(((y - 1) & 255) << 8) + x]
                let hd: Float = hgt[(((y + 1) & 255) << 8) + x]
                let slope: Float = (hl - hr) * 0.5 + (hu - hd) * 0.35
                let shade: Float = FluffMath.clampF(1.0 + slope * 0.09, 0.78, 1.18)
                let u: Float = Float(x) / 256
                let v: Float = Float(y) / 256
                let var1: Float = FluffWorld.fbm(u, v, 3, 5, 5)
                let w0: Float = w0a[idx]
                let w1: Float = w1a[idx]
                let w2: Float = w2a[idx]

                // meadow
                let ht: Float = FluffMath.clampF((h0 - 6) / 10, 0, 1)
                var mr: Float = FluffMath.lerp(108, 196, ht) + (var1 - 0.5) * 50
                var mg: Float = FluffMath.lerp(196, 232, ht) + (var1 - 0.5) * 24
                var mb: Float = FluffMath.lerp(120, 122, ht) + (var1 - 0.5) * 30
                let sp: Float = FluffWorld.hash01(x, y, 3)
                if sp < 0.05 && h0 > FluffWorld.waterLevel + 0.9 {
                    let pick = Int(sp * 1000) % 4
                    if pick == 0 { mr = 255; mg = 236; mb = 130 }
                    else if pick == 1 { mr = 255; mg = 176; mb = 206 }
                    else if pick == 2 { mr = 255; mg = 255; mb = 255 }
                    else { mr = 190; mg = 170; mb = 255 }
                }
                // sandy shores for ponds
                let shore: Float = FluffMath.clampF(1 - (h0 - FluffWorld.waterLevel) / 0.8, 0, 1)
                mr = FluffMath.lerp(mr, 238, shore)
                mg = FluffMath.lerp(mg, 224, shore)
                mb = FluffMath.lerp(mb, 160, shore)

                // beach
                let wet: Float = FluffMath.clampF(1 - (h0 - FluffWorld.waterLevel) / 0.7, 0, 1)
                let br: Float = FluffMath.lerp(246, 232, var1) - wet * 34
                let bg: Float = FluffMath.lerp(228, 206, var1) - wet * 30
                let bb: Float = FluffMath.lerp(172, 150, var1) - wet * 22

                // hollow
                let hz: Float = FluffMath.clampF((h0 - 6) / 20, 0, 1)
                var hr2: Float = FluffMath.lerp(118, 226, hz) + (var1 - 0.5) * 40
                var hg2: Float = FluffMath.lerp(204, 204, hz) + (var1 - 0.5) * 20
                var hb2: Float = FluffMath.lerp(192, 244, hz) + (var1 - 0.5) * 30
                if hz > 0.3 && hz < 0.6 {
                    let k: Float = 1 - abs(hz - 0.45) / 0.15
                    hr2 = FluffMath.lerp(hr2, 176, k * 0.7)
                    hg2 = FluffMath.lerp(hg2, 160, k * 0.7)
                    hb2 = FluffMath.lerp(hb2, 232, k * 0.7)
                }
                if sp > 0.985 {
                    hr2 = 150; hg2 = 245; hb2 = 235
                }

                let cr: Float = (w0 * mr + w1 * br + w2 * hr2) * shade
                let cg: Float = (w0 * mg + w1 * bg + w2 * hg2) * shade
                let cb: Float = (w0 * mb + w1 * bb + w2 * hb2) * shade
                col[idx] = FluffMath.rgb(cr, cg, cb)
            }
        }

        placeSpawn()
        placeProps()
    }

    private func placeSpawn() {
        var bestX: Float = 64
        var bestY: Float = 70
        var bestScore: Float = -1000
        var dyy = -20
        while dyy <= 20 {
            var dxx = -20
            while dxx <= 20 {
                let x: Float = 64 + Float(dxx)
                let y: Float = 70 + Float(dyy)
                let h: Float = height(x, y)
                let r: Int = region(x, y)
                if r == 0 && h > FluffWorld.waterLevel + 2.0 {
                    let hx: Float = height(x + 4, y)
                    let hy: Float = height(x, y + 4)
                    let flat: Float = abs(hx - h) + abs(hy - h)
                    let sc: Float = -flat * 4 - Float(abs(dxx) + abs(dyy)) * 0.2
                    if sc > bestScore { bestScore = sc; bestX = x; bestY = y }
                }
                dxx += 2
            }
            dyy += 2
        }
        spawnX = bestX
        spawnY = bestY
    }

    private func addProp(_ kind: Int, _ variant: Int, _ size: Float, _ x: Float, _ y: Float, _ region: Int) {
        let wx: Float = FluffMath.wrap(x)
        let wy: Float = FluffMath.wrap(y)
        let p = FluffProp(x: wx, y: wy, gz: height(wx, wy), kind: kind, variant: variant, size: size, region: region)
        let ci = FluffWorld.cellIndex(Int(wx) >> 4, Int(wy) >> 4)
        grid[ci].append(props.count)
        props.append(p)
    }

    private func placeProps() {
        var rng = Rng(seed: 20240611)
        let wl: Float = FluffWorld.waterLevel
        // guaranteed starter props near the spawn
        addProp(FluffKind.bush, 0, 1.0, spawnX + 7, spawnY + 3, 0)
        addProp(FluffKind.bush, 0, 1.1, spawnX + 4, spawnY - 8, 0)
        addProp(FluffKind.hive, 0, 1.1, spawnX - 9, spawnY + 6, 0)
        addProp(FluffKind.blossom, 0, 1.0, spawnX + 12, spawnY - 3, 0)
        addProp(FluffKind.tree, 0, 1.0, spawnX - 11, spawnY - 7, 0)

        for _ in 0..<12000 {
            let x: Float = Float(rng.unit()) * 256
            let y: Float = Float(rng.unit()) * 256
            let h: Float = height(x, y)
            if h < wl + 0.7 { continue }
            let sdx: Float = FluffMath.wrapDelta(x - spawnX)
            let sdy: Float = FluffMath.wrapDelta(y - spawnY)
            if sdx * sdx + sdy * sdy < 36 { continue }
            let slope: Float = abs(height(x + 1.5, y) - h) + abs(height(x, y + 1.5) - h)
            if slope > 3.2 { continue }
            let r: Int = region(x, y)
            let roll: Int = rng.int(1000)
            let sz: Float = 0.8 + Float(rng.unit()) * 0.6
            switch r {
            case 0:
                if roll < 18 { addProp(FluffKind.tree, rng.int(2), sz, x, y, r) }
                else if roll < 95 { addProp(FluffKind.blossom, rng.int(2), sz, x, y, r) }
                else if roll < 103 { addProp(FluffKind.hive, 0, sz, x, y, r) }
                else if roll < 150 { addProp(FluffKind.bush, 0, sz, x, y, r) }
                else if roll < 175 { addProp(FluffKind.rock, 0, sz * 0.8, x, y, r) }
                else if roll < 195 { addProp(FluffKind.mushroom, rng.int(3), sz * 0.8, x, y, r) }
                else if roll < 330 { addFlowers(&rng, x, y, r) }
            case 1:
                if roll < 30 { addProp(FluffKind.palm, rng.int(2), sz, x, y, r) }
                else if roll < 125 { addProp(FluffKind.shells, 0, sz, x, y, r) }
                else if roll < 145 { addProp(FluffKind.rock, 2, sz * 0.8, x, y, r) }
                else if roll < 200 { addFlowers(&rng, x, y, r) }
                else if roll < 222 { addProp(FluffKind.bush, 1, sz, x, y, r) }
            default:
                if roll < 150 { addProp(FluffKind.crystal, rng.int(4), sz * (0.8 + Float(rng.unit())), x, y, r) }
                else if roll < 190 { addProp(FluffKind.rock, 1, sz, x, y, r) }
                else if roll < 255 { addProp(FluffKind.mushroom, 3 + rng.int(3), sz, x, y, r) }
                else if roll < 278 { addProp(FluffKind.bush, 2, sz, x, y, r) }
            }
        }
    }

    private func addFlowers(_ rng: inout Rng, _ x: Float, _ y: Float, _ r: Int) {
        let base: Int = rng.int(8)
        for _ in 0..<4 {
            let ox: Float = (Float(rng.unit()) - 0.5) * 3.2
            let oy: Float = (Float(rng.unit()) - 0.5) * 3.2
            let h: Float = height(x + ox, y + oy)
            if h < FluffWorld.waterLevel + 0.6 { continue }
            addProp(FluffKind.flower, (base + rng.int(2)) & 7, 0.8 + Float(rng.unit()) * 0.5, x + ox, y + oy, r)
        }
    }
}

// MARK: - Painter

/// Software sprite painter: clipped, depth-tested ellipses/rects, with tint (day/night) and fog applied per colour.
final class FluffPainter {
    let p: UnsafeMutablePointer<UInt32>
    let dp: UnsafeMutablePointer<UInt16>
    let w: Int
    let h: Int
    var zq: UInt16 = 0
    var useDepth: Bool = true
    var tr: Int = 256
    var tg: Int = 256
    var tb: Int = 256
    var fog: Int = 0
    var hzR: Int = 200
    var hzG: Int = 225
    var hzB: Int = 245
    var glow: Bool = false
    var sil: UInt32 = 0

    init(p: UnsafeMutablePointer<UInt32>, dp: UnsafeMutablePointer<UInt16>, w: Int, h: Int) {
        self.p = p
        self.dp = dp
        self.w = w
        self.h = h
    }

    func setLight(_ r: Int, _ g: Int, _ b: Int, _ hr: Int, _ hg: Int, _ hb: Int) {
        tr = r; tg = g; tb = b
        hzR = hr; hzG = hg; hzB = hb
    }

    func begin(z: Float, fogAmount: Int, depthOn: Bool) {
        let zi: Int = FluffMath.i(z * 0.97 - 1.2)
        zq = UInt16(max(0, min(60000, zi)))
        fog = max(0, min(256, fogAmount))
        useDepth = depthOn
        glow = false
        sil = 0
    }

    func col(_ c: UInt32) -> UInt32 {
        if sil != 0 { return sil }
        var r: Int = Int(c & 255)
        var g: Int = Int((c >> 8) & 255)
        var b: Int = Int((c >> 16) & 255)
        if !glow {
            r = (r * tr) >> 8
            g = (g * tg) >> 8
            b = (b * tb) >> 8
        }
        if fog > 0 {
            r += ((hzR - r) * fog) >> 8
            g += ((hzG - g) * fog) >> 8
            b += ((hzB - b) * fog) >> 8
        }
        let rr: UInt32 = UInt32(max(0, min(255, r)))
        let gg: UInt32 = UInt32(max(0, min(255, g)))
        let bb: UInt32 = UInt32(max(0, min(255, b)))
        return 0xFF00_0000 | rr | (gg << 8) | (bb << 16)
    }

    @inline(__always) func blendPix(_ d: UInt32, _ s: UInt32, _ a: Int) -> UInt32 {
        let ia: Int = 256 - a
        let r: Int = (Int(d & 255) * ia + Int(s & 255) * a) >> 8
        let g: Int = (Int((d >> 8) & 255) * ia + Int((s >> 8) & 255) * a) >> 8
        let b: Int = (Int((d >> 16) & 255) * ia + Int((s >> 16) & 255) * a) >> 8
        return 0xFF00_0000 | UInt32(r & 255) | (UInt32(g & 255) << 8) | (UInt32(b & 255) << 16)
    }

    func rawRect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ cc: UInt32) {
        let x0 = max(0, x)
        let y0 = max(0, y)
        let x1 = min(w, x + rw)
        let y1 = min(h, y + rh)
        if x0 >= x1 || y0 >= y1 { return }
        for yy in y0..<y1 {
            let base = yy * w
            if useDepth {
                for xx in x0..<x1 {
                    if dp[base + xx] >= zq { p[base + xx] = cc }
                }
            } else {
                for xx in x0..<x1 { p[base + xx] = cc }
            }
        }
    }

    func rect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: UInt32) {
        rawRect(x, y, rw, rh, col(c))
    }

    func rectA(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: UInt32, _ alpha: Int) {
        let cc = col(c)
        let x0 = max(0, x)
        let y0 = max(0, y)
        let x1 = min(w, x + rw)
        let y1 = min(h, y + rh)
        if x0 >= x1 || y0 >= y1 { return }
        for yy in y0..<y1 {
            let base = yy * w
            for xx in x0..<x1 {
                if useDepth && dp[base + xx] < zq { continue }
                p[base + xx] = blendPix(p[base + xx], cc, alpha)
            }
        }
    }

    func ell(_ cx: Int, _ cy: Int, _ rx: Int, _ ry: Int, _ c: UInt32) {
        ellCore(cx, cy, rx, ry, col(c), 256)
    }

    func ellA(_ cx: Int, _ cy: Int, _ rx: Int, _ ry: Int, _ c: UInt32, _ alpha: Int) {
        ellCore(cx, cy, rx, ry, col(c), alpha)
    }

    private func ellCore(_ cx: Int, _ cy: Int, _ rx: Int, _ ry: Int, _ cc: UInt32, _ alpha: Int) {
        if rx <= 0 || ry <= 0 { return }
        if cx + rx < 0 || cx - rx >= w { return }
        let y0 = max(0, cy - ry)
        let y1 = min(h - 1, cy + ry)
        if y0 > y1 { return }
        let invry: Float = 1.0 / Float(ry)
        let frx: Float = Float(rx)
        for yy in y0...y1 {
            let t: Float = Float(yy - cy) * invry
            let q: Float = 1 - t * t
            if q <= 0 { continue }
            let hw: Int = Int(frx * q.squareRoot())
            let xa = max(0, cx - hw)
            let xb = min(w - 1, cx + hw)
            if xa > xb { continue }
            let base = yy * w
            if alpha >= 256 {
                if useDepth {
                    for xx in xa...xb {
                        if dp[base + xx] >= zq { p[base + xx] = cc }
                    }
                } else {
                    for xx in xa...xb { p[base + xx] = cc }
                }
            } else {
                for xx in xa...xb {
                    if useDepth && dp[base + xx] < zq { continue }
                    p[base + xx] = blendPix(p[base + xx], cc, alpha)
                }
            }
        }
    }

    func line(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ th: Int, _ c: UInt32) {
        let cc = col(c)
        let dx = x1 - x0
        let dy = y1 - y0
        let n = max(max(abs(dx), abs(dy)), 1)
        let t = max(1, th)
        let half = t / 2
        for i in 0...n {
            let x = x0 + dx * i / n
            let y = y0 + dy * i / n
            rawRect(x - half, y - half, t, t, cc)
        }
    }

    /// Upright cone / triangle: apex at top, base at `baseY`, `lean` shifts the tip sideways.
    func cone(_ cx: Int, _ baseY: Int, _ halfW: Int, _ height: Int, _ lean: Int, _ c: UInt32) {
        let cc = col(c)
        let hh = max(1, height)
        for i in 0..<hh {
            let t: Int = hh - i
            let wd: Int = max(0, halfW * t / hh)
            let off: Int = lean * i / hh
            rawRect(cx - wd + off, baseY - i, wd * 2 + 1, 1, cc)
        }
    }

    func heart(_ cx: Int, _ cy: Int, _ s: Int, _ c: UInt32) {
        let cc = col(c)
        let r = max(1, s / 2)
        ellCore(cx - r + r / 2, cy - r / 2, r, r, cc, 256)
        ellCore(cx + r - r / 2, cy - r / 2, r, r, cc, 256)
        let hh = r * 2
        for i in 0..<hh {
            let wd = max(0, (hh - i) * r / hh * 2 - 1 + (r > 2 ? 1 : 0))
            rawRect(cx - wd, cy + i - r / 2 + 1, wd * 2 + 1, 1, cc)
        }
    }

    func star(_ cx: Int, _ cy: Int, _ s: Int, _ c: UInt32) {
        let cc = col(c)
        let r = max(1, s)
        rawRect(cx - r, cy, r * 2 + 1, 1, cc)
        rawRect(cx, cy - r, 1, r * 2 + 1, cc)
        if r >= 3 {
            let d = r / 2
            rawRect(cx - d, cy - d, d * 2 + 1, d * 2 + 1, cc)
        }
    }
}

// MARK: - Prop sprites

extension FluffPainter {
    static let flowerColors: [UInt32] = [
        FluffPainter.abgr(0xFF9EC8), FluffPainter.abgr(0xFFE070), FluffPainter.abgr(0xFFFFFF), FluffPainter.abgr(0xB8A0FF),
        FluffPainter.abgr(0xFF9A80), FluffPainter.abgr(0x8ADCFF), FluffPainter.abgr(0xFFB0E8), FluffPainter.abgr(0xFFC860)
    ]
    static let crystalColors: [UInt32] = [
        FluffPainter.abgr(0x78E8E0), FluffPainter.abgr(0xC0A0FF), FluffPainter.abgr(0xFFA8E0), FluffPainter.abgr(0x8CC4FF)
    ]

    static func abgr(_ rgb: UInt32) -> UInt32 {
        let r: UInt32 = (rgb >> 16) & 255
        let g: UInt32 = (rgb >> 8) & 255
        let b: UInt32 = rgb & 255
        return 0xFF00_0000 | r | (g << 8) | (b << 16)
    }

    /// Draws a world prop. `sx, gy` is the ground contact in screen pixels, `s` is pixels per world unit.
    func drawProp(_ pr: FluffProp, _ sx: Int, _ gy: Int, _ s: Float, _ tick: Int, _ night: Float, _ stock: Int) {
        let size: Float = pr.size
        switch pr.kind {
        case FluffKind.tree, FluffKind.blossom, FluffKind.hive:
            drawTree(pr, sx, gy, s, stock)
        case FluffKind.palm:
            drawPalm(pr, sx, gy, s)
        case FluffKind.bush:
            drawBush(pr, sx, gy, s, stock)
        case FluffKind.shells:
            drawShells(sx, gy, s, size, stock, tick)
        case FluffKind.flower:
            drawFlower(pr, sx, gy, s, tick)
        case FluffKind.rock:
            drawRock(pr, sx, gy, s)
        case FluffKind.crystal:
            drawCrystal(pr, sx, gy, s, tick, night)
        default:
            drawMushroom(pr, sx, gy, s, tick, night)
        }
    }

    private func drawTree(_ pr: FluffProp, _ sx: Int, _ gy: Int, _ s: Float, _ stock: Int) {
        let u: Float = s * pr.size
        let tw: Int = max(1, FluffMath.i(0.7 * u))
        let th: Int = max(2, FluffMath.i(3.4 * u))
        let trunk: UInt32 = 0xFF4B6E9A
        let trunkD: UInt32 = 0xFF3A5278
        rect(sx - tw / 2, gy - th, tw, th, trunk)
        if tw > 3 { rect(sx + tw / 4, gy - th, max(1, tw / 4), th, trunkD) }
        let rad: Int = max(2, FluffMath.i(2.7 * u))
        let cy: Int = gy - FluffMath.i(4.6 * u)
        var leaf: UInt32 = 0xFF78C860
        var leafD: UInt32 = 0xFF58A84C
        var leafL: UInt32 = 0xFF9CE880
        if pr.kind == FluffKind.blossom {
            leaf = 0xFFD2B8FF
            leafD = 0xFFB496EC
            leafL = 0xFFE8D8FF
        } else if pr.variant == 1 {
            leaf = 0xFF8CD070
            leafD = 0xFF64B058
            leafL = 0xFFB4EE90
        }
        // soft ground shadow
        ellA(sx, gy, max(2, rad * 3 / 4), max(1, rad / 5), 0xFF305030, 90)
        if rad <= 4 {
            ell(sx, cy, rad, rad, leaf)
            return
        }
        ell(sx - rad * 6 / 10, cy + rad / 4, rad * 7 / 10, rad * 7 / 10, leafD)
        ell(sx + rad * 6 / 10, cy + rad / 4, rad * 7 / 10, rad * 7 / 10, leafD)
        ell(sx, cy, rad, rad * 9 / 10, leaf)
        ell(sx - rad / 3, cy - rad / 3, rad / 2, rad / 3, leafL)
        if pr.kind == FluffKind.blossom && rad > 8 {
            let dots: Int = 7
            for k in 0..<dots {
                let ox: Int = ((k * 37) % 17 - 8) * rad / 11
                let oy: Int = ((k * 53) % 13 - 6) * rad / 11
                ell(sx + ox, cy + oy, max(1, rad / 10), max(1, rad / 10), 0xFFFFFFFF)
            }
        }
        if pr.kind == FluffKind.hive {
            let hx: Int = sx + rad * 6 / 10
            let hy: Int = cy + rad * 9 / 10
            let hr: Int = max(2, rad / 4)
            rect(hx, cy + rad / 2, max(1, hr / 5), hy - cy - rad / 2, trunkD)
            ell(hx, hy + hr, hr, hr * 5 / 4, stock > 0 ? 0xFF50C8F0 : 0xFFB0B0A8)
            if hr > 3 {
                rect(hx - hr + 1, hy + hr - 1, hr * 2 - 2, max(1, hr / 4), 0xFF3A6A9A)
                rect(hx - hr + 1, hy + hr + hr / 2, hr * 2 - 2, max(1, hr / 4), 0xFF3A6A9A)
            }
        }
    }

    private func drawPalm(_ pr: FluffProp, _ sx: Int, _ gy: Int, _ s: Float) {
        let u: Float = s * pr.size
        let th: Int = max(3, FluffMath.i(6.0 * u))
        let lean: Int = pr.variant == 0 ? FluffMath.i(1.3 * u) : -FluffMath.i(1.3 * u)
        let tw: Int = max(1, FluffMath.i(0.55 * u))
        ellA(sx, gy, max(2, FluffMath.i(1.6 * u)), max(1, FluffMath.i(0.35 * u)), 0xFF305030, 80)
        let segs: Int = 7
        var topX: Int = sx
        var topY: Int = gy
        for i in 0..<segs {
            let t0: Float = Float(i) / Float(segs)
            let t1: Float = Float(i + 1) / Float(segs)
            let x0: Int = sx + FluffMath.i(Float(lean) * t0 * t0)
            let x1: Int = sx + FluffMath.i(Float(lean) * t1 * t1)
            let y0: Int = gy - FluffMath.i(Float(th) * t0)
            let y1: Int = gy - FluffMath.i(Float(th) * t1)
            line(x0, y0, x1, y1, tw, (i & 1) == 0 ? 0xFF6AA0C8 : 0xFF5088B4)
            topX = x1
            topY = y1
        }
        let fl: Int = max(3, FluffMath.i(3.2 * u))
        let angs: [Float] = [-2.9, -2.3, -1.7, -1.1, -0.5, 0.1]
        for a in angs {
            let ex: Int = topX + FluffMath.i(cos(a) * Float(fl))
            let ey: Int = topY + FluffMath.i(sin(a) * Float(fl) * 0.55) + fl / 3
            let midx: Int = topX + FluffMath.i(cos(a) * Float(fl) * 0.55)
            let midy: Int = topY + FluffMath.i(sin(a) * Float(fl) * 0.7) - fl / 6
            line(topX, topY, midx, midy, max(1, fl / 5), 0xFF68D07C)
            line(midx, midy, ex, ey, max(1, fl / 6), 0xFF4CB464)
        }
        let cr: Int = max(1, fl / 6)
        ell(topX - cr, topY + cr, cr, cr, 0xFF4A6AA0)
        ell(topX + cr, topY + cr, cr, cr, 0xFF4A6AA0)
    }

    private func drawBush(_ pr: FluffProp, _ sx: Int, _ gy: Int, _ s: Float, _ stock: Int) {
        let u: Float = s * pr.size
        let rx: Int = max(2, FluffMath.i(1.35 * u))
        let ry: Int = max(2, FluffMath.i(1.0 * u))
        var leaf: UInt32 = 0xFF6ABE58
        var leafD: UInt32 = 0xFF4EA044
        var leafL: UInt32 = 0xFF90E078
        var berry: UInt32 = 0xFF5060F0
        if pr.variant == 1 {
            leaf = 0xFF78C8A0; leafD = 0xFF58AC88; leafL = 0xFF9CE8C4; berry = 0xFFA050E8
        } else if pr.variant == 2 {
            leaf = 0xFF9ABC70; leafD = 0xFF789E5C; leafL = 0xFFB8DC98; berry = 0xFFE0E040
        }
        ellA(sx, gy, rx, max(1, ry / 4), 0xFF305030, 80)
        ell(sx - rx / 2, gy - ry / 2, rx * 3 / 5, ry / 2 + 1, leafD)
        ell(sx + rx / 2, gy - ry / 2, rx * 3 / 5, ry / 2 + 1, leafD)
        ell(sx, gy - ry * 6 / 10, rx * 4 / 5, ry * 6 / 10 + 1, leaf)
        ell(sx - rx / 4, gy - ry * 9 / 10, rx / 3, ry / 4 + 1, leafL)
        if stock > 0 && ry >= 4 {
            let br: Int = max(1, ry / 6)
            ell(sx - rx / 2, gy - ry / 2, br, br, berry)
            ell(sx + rx / 4, gy - ry * 3 / 4, br, br, berry)
            ell(sx + rx / 2, gy - ry / 3, br, br, berry)
            ell(sx - rx / 8, gy - ry / 4, br, br, berry)
            if br > 1 { ell(sx - rx / 2 - br / 3, gy - ry / 2 - br / 3, max(1, br / 3), max(1, br / 3), 0xFFFFFFFF) }
        }
    }

    private func drawShells(_ sx: Int, _ gy: Int, _ s: Float, _ size: Float, _ stock: Int, _ tick: Int) {
        let u: Float = s * size
        let rx: Int = max(2, FluffMath.i(1.1 * u))
        ell(sx, gy - rx / 4, rx, max(1, rx / 3), 0xFFA0D4E8)
        let r: Int = max(1, rx / 2)
        let col1: UInt32 = stock > 0 ? 0xFFC8B4FF : 0xFFC8C4C8
        let col2: UInt32 = stock > 0 ? 0xFFA0DCFF : 0xFFB8B8BC
        ell(sx - rx / 2, gy - r, r, r, col1)
        ell(sx + rx / 3, gy - r - r / 3, r, r, col2)
        ell(sx, gy - r / 2, max(1, r - 1), max(1, r - 1), 0xFFFFF0F0)
        if r > 2 {
            rect(sx - rx / 2, gy - r - r / 2, 1, r, 0xFFFFFFFF)
        }
        if stock > 0 && ((tick / 10) & 3) == 0 {
            star(sx + rx / 2, gy - rx - 2, max(1, rx / 3), 0xFFFFFFFF)
        }
    }

    private func drawFlower(_ pr: FluffProp, _ sx: Int, _ gy: Int, _ s: Float, _ tick: Int) {
        let u: Float = s * pr.size
        let petal: UInt32 = FluffPainter.flowerColors[pr.variant & 7]
        let hgt: Int = max(2, FluffMath.i(0.8 * u))
        if hgt < 4 {
            rect(sx, gy - hgt, max(1, hgt / 2 + 1), max(1, hgt / 2 + 1), petal)
            return
        }
        let sway: Int = ((tick / 24 + sx) & 3) == 0 ? 1 : 0
        rect(sx, gy - hgt, max(1, hgt / 8), hgt, 0xFF58B04E)
        let pr2: Int = max(2, hgt / 4)
        let hx: Int = sx + sway
        let hy: Int = gy - hgt
        ell(hx - pr2, hy, pr2 / 2 + 1, pr2 / 2 + 1, petal)
        ell(hx + pr2, hy, pr2 / 2 + 1, pr2 / 2 + 1, petal)
        ell(hx, hy - pr2, pr2 / 2 + 1, pr2 / 2 + 1, petal)
        ell(hx, hy + pr2, pr2 / 2 + 1, pr2 / 2 + 1, petal)
        ell(hx, hy, max(1, pr2 / 2), max(1, pr2 / 2), 0xFF4CD0FF)
    }

    private func drawRock(_ pr: FluffProp, _ sx: Int, _ gy: Int, _ s: Float) {
        let u: Float = s * pr.size
        let rx: Int = max(2, FluffMath.i(1.3 * u))
        let ry: Int = max(2, FluffMath.i(0.95 * u))
        var base: UInt32 = 0xFFC0B8B0
        var dark: UInt32 = 0xFF9C94A0
        var light: UInt32 = 0xFFE0D8D4
        if pr.variant == 1 {
            base = 0xFFD0A8C8; dark = 0xFFA888A8; light = 0xFFECC8E4
        } else if pr.variant == 2 {
            base = 0xFFB0C4DC; dark = 0xFF90A0C0; light = 0xFFD0E0F0
        }
        ellA(sx, gy, rx + 1, max(1, ry / 4), 0xFF303040, 80)
        ell(sx, gy - ry * 4 / 10, rx, ry * 6 / 10 + 1, dark)
        ell(sx - rx / 8, gy - ry / 2, rx * 9 / 10, ry * 6 / 10, base)
        ell(sx - rx / 3, gy - ry * 7 / 10, rx / 3, ry / 4 + 1, light)
    }

    private func drawCrystal(_ pr: FluffProp, _ sx: Int, _ gy: Int, _ s: Float, _ tick: Int, _ night: Float) {
        let u: Float = s * pr.size
        let ch: Int = max(4, FluffMath.i(4.2 * u))
        let cw: Int = max(2, FluffMath.i(0.95 * u))
        let base: UInt32 = FluffPainter.crystalColors[pr.variant & 3]
        let nightGlow: Int = FluffMath.i(night * 110)
        if nightGlow > 10 {
            ellA(sx, gy - ch / 2, cw * 3, ch * 6 / 10, base, nightGlow)
        }
        ellA(sx, gy, cw * 2, max(1, cw / 3), 0xFF303050, 70)
        let oldGlow = glow
        glow = night > 0.5
        crystalShard(sx, gy, cw, ch, 0, base)
        crystalShard(sx - cw * 2, gy, max(2, cw * 7 / 10), ch * 6 / 10, -cw / 2, base)
        crystalShard(sx + cw * 2, gy, max(2, cw * 6 / 10), ch / 2, cw / 2, base)
        glow = oldGlow
        if ((tick / 14 + pr.variant + sx) & 7) == 0 {
            star(sx + cw / 2, gy - ch * 7 / 10, max(1, cw / 2), 0xFFFFFFFF)
        }
    }

    private func crystalShard(_ cx: Int, _ gy: Int, _ cw: Int, _ ch: Int, _ lean: Int, _ base: UInt32) {
        let r: Int = Int(base & 255)
        let g: Int = Int((base >> 8) & 255)
        let b: Int = Int((base >> 16) & 255)
        let light: UInt32 = 0xFF00_0000 | UInt32(min(255, r + 50)) | (UInt32(min(255, g + 40)) << 8) | (UInt32(min(255, b + 30)) << 16)
        let dark: UInt32 = 0xFF00_0000 | UInt32(r * 3 / 4) | (UInt32(g * 3 / 4) << 8) | (UInt32(b * 4 / 5) << 16)
        let tipH: Int = max(2, ch / 4)
        let bodyH: Int = ch - tipH
        // body: left half light, right half dark
        rect(cx - cw + lean / 2, gy - bodyH, cw, bodyH, light)
        rect(cx + lean / 2, gy - bodyH, cw, bodyH, dark)
        // pointed tip
        for i in 0..<tipH {
            let t: Int = tipH - i
            let wd: Int = max(0, cw * t / tipH)
            let off: Int = lean * i / max(1, tipH) + lean / 2
            rect(cx - wd + off, gy - bodyH - i - 1, wd, 1, light)
            rect(cx + off, gy - bodyH - i - 1, wd, 1, dark)
        }
        if cw >= 3 {
            rect(cx - cw / 2 + lean / 2, gy - bodyH + 1, max(1, cw / 5), max(1, bodyH * 6 / 10), 0xFFFFFFFF)
        }
    }

    private func drawMushroom(_ pr: FluffProp, _ sx: Int, _ gy: Int, _ s: Float, _ tick: Int, _ night: Float) {
        let u: Float = s * pr.size
        let v: Int = pr.variant
        let hgt: Int = max(2, FluffMath.i(0.9 * u))
        let capR: Int = max(2, FluffMath.i(0.8 * u))
        var capCol: UInt32 = 0xFF9C9CFF
        var capL: UInt32 = 0xFFC4C4FF
        if v == 1 { capCol = 0xFF98D4FF; capL = 0xFFC8EAFF }
        else if v == 2 { capCol = 0xFFFFB0D8; capL = 0xFFFFD4EC }
        else if v == 3 { capCol = 0xFFE8A0FF; capL = 0xFFF4CCFF }
        else if v == 4 { capCol = 0xFF98F0D8; capL = 0xFFC8FFF0 }
        else if v == 5 { capCol = 0xFFFFE08A; capL = 0xFFFFF0C0 }
        let glows: Bool = v >= 3
        let ng: Int = FluffMath.i(night * 120)
        if glows && ng > 8 {
            ellA(sx, gy - hgt, capR * 3, capR * 2, capCol, ng / 2)
            ellA(sx, gy - hgt, capR * 2, capR * 3 / 2, capCol, ng / 2)
        }
        ellA(sx, gy, capR, max(1, capR / 4), 0xFF303040, 70)
        rect(sx - max(1, capR / 3), gy - hgt, max(2, capR * 2 / 3), hgt, 0xFFF0F4FF)
        let og = glow
        glow = glows && night > 0.4
        ell(sx, gy - hgt, capR, max(1, capR * 7 / 10), capCol)
        ell(sx - capR / 3, gy - hgt - capR / 4, max(1, capR / 3), max(1, capR / 5), capL)
        if capR > 3 {
            ell(sx + capR / 3, gy - hgt, max(1, capR / 6), max(1, capR / 6), 0xFFFFFFFF)
            ell(sx - capR / 2, gy - hgt + capR / 6, max(1, capR / 7), max(1, capR / 7), 0xFFFFFFFF)
        }
        glow = og
    }
}

// MARK: - UI helpers

extension FluffPainter {
    func beginUI() {
        useDepth = false
        fog = 0
        tr = 256
        tg = 256
        tb = 256
        glow = false
        sil = 0
    }

    func text(_ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        let cc = col(c)
        let sc = max(1, scale)
        var cx = x
        for ch in s.uppercased() {
            let g: UInt16 = Font.glyph(ch)
            if g != 0 && cx < w && cx + 4 * sc > 0 {
                for row in 0..<5 {
                    for colm in 0..<3 {
                        if (g >> UInt16(14 - (row * 3 + colm))) & 1 == 1 {
                            rawRect(cx + colm * sc, y + row * sc, sc, sc, cc)
                        }
                    }
                }
            }
            cx += 4 * sc
        }
    }

    func roundRect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ r: Int, _ c: UInt32, _ alpha: Int) {
        if alpha <= 0 || rw <= 0 || rh <= 0 { return }
        let cc = col(c)
        let rad = max(0, min(r, min(rw, rh) / 2))
        for i in 0..<rh {
            var inset = 0
            var edge = -1
            if i < rad { edge = rad - i - 1 } else if i >= rh - rad { edge = i - (rh - rad) }
            if edge >= 0 {
                let dy: Float = Float(rad - edge) - 0.5
                let q: Float = Float(rad * rad) - dy * dy
                let hw: Float = q > 0 ? q.squareRoot() : 0
                inset = rad - FluffMath.i(hw)
            }
            let yy = y + i
            if yy < 0 || yy >= h { continue }
            let xa = max(0, x + inset)
            let xb = min(w, x + rw - inset)
            if xa >= xb { continue }
            let base = yy * w
            if alpha >= 256 {
                for xx in xa..<xb { p[base + xx] = cc }
            } else {
                for xx in xa..<xb { p[base + xx] = blendPix(p[base + xx], cc, alpha) }
            }
        }
    }
}
