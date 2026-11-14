#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

// Small true-colour 2D drawing toolkit used by BUDDY BOUNCE (smooth discs, capsules, rounded rects, polygons).
// Everything here works on a raw pixel pointer so it can run inside TrueColorBuffer.withPixels.

@inline(__always) func buddyClampF(_ v: Float, _ lo: Float, _ hi: Float) -> Float {
    if !v.isFinite { return lo }
    if v < lo { return lo }
    if v > hi { return hi }
    return v
}

@inline(__always) func buddyFin(_ v: Float) -> Float {
    return v.isFinite ? v : 0
}

func buddyFloorI(_ v: Float) -> Int {
    let c: Float = buddyClampF(v, -30000, 30000)
    return Int(floor(c))
}

func buddyTrunc(_ v: Float) -> Int {
    let c: Float = buddyClampF(v, -30000, 30000)
    return Int(c)
}

enum BuddyCol {
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
        return TrueColorBuffer.rgb(r, g, b)
    }

    static func hex(_ h: UInt32) -> UInt32 {
        return TrueColorBuffer.hex(h)
    }

    static func rr(_ c: UInt32) -> Int { return Int(c & 255) }
    static func gg(_ c: UInt32) -> Int { return Int((c >> 8) & 255) }
    static func bb(_ c: UInt32) -> Int { return Int((c >> 16) & 255) }

    static func mix(_ a: UInt32, _ b: UInt32, _ t: Float) -> UInt32 {
        let tt: Float = buddyClampF(t, 0, 1)
        let ar: Float = Float(rr(a))
        let ag: Float = Float(gg(a))
        let ab: Float = Float(bb(a))
        let br: Float = Float(rr(b))
        let bg: Float = Float(gg(b))
        let bbv: Float = Float(bb(b))
        let r: Int = Int(ar + (br - ar) * tt)
        let g: Int = Int(ag + (bg - ag) * tt)
        let bl: Int = Int(ab + (bbv - ab) * tt)
        return rgb(r, g, bl)
    }

    /// Multiply brightness (f below 1 darkens, above 1 lightens).
    static func shade(_ c: UInt32, _ f: Float) -> UInt32 {
        let ff: Float = buddyClampF(f, 0, 4)
        let r: Int = Int(Float(rr(c)) * ff)
        let g: Int = Int(Float(gg(c)) * ff)
        let b: Int = Int(Float(bb(c)) * ff)
        return rgb(r, g, b)
    }

    static func hsv(_ h: Float, _ s: Float, _ v: Float) -> UInt32 {
        var hh: Float = h - floor(h)
        if !hh.isFinite { hh = 0 }
        let i: Int = Int(hh * 6)
        let f: Float = hh * 6 - Float(i)
        let p: Float = v * (1 - s)
        let q: Float = v * (1 - f * s)
        let t: Float = v * (1 - (1 - f) * s)
        var r: Float = v
        var g: Float = t
        var b: Float = p
        switch i % 6 {
        case 0: r = v; g = t; b = p
        case 1: r = q; g = v; b = p
        case 2: r = p; g = v; b = t
        case 3: r = p; g = q; b = v
        case 4: r = t; g = p; b = v
        default: r = v; g = p; b = q
        }
        return rgb(Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

struct BuddyCanvas {
    let p: UnsafeMutablePointer<UInt32>
    let w: Int
    let h: Int
    /// When true, opaque shapes get a subtle burlap crosshatch.
    var weave: Bool = false

    init(p: UnsafeMutablePointer<UInt32>, w: Int, h: Int) {
        self.p = p
        self.w = w
        self.h = h
    }

    @inline(__always) func put(_ x: Int, _ y: Int, _ c: UInt32, _ a: Int) {
        if x < 0 || y < 0 || x >= w || y >= h || a <= 0 { return }
        var col: UInt32 = c
        if weave && a >= 128 {
            if (x & 3) == 0 || (y & 3) == 0 {
                let r: Int = (Int(col & 255) * 232) >> 8
                let g: Int = (Int((col >> 8) & 255) * 232) >> 8
                let b: Int = (Int((col >> 16) & 255) * 232) >> 8
                col = 0xFF00_0000 | UInt32(r) | (UInt32(g) << 8) | (UInt32(b) << 16)
            }
        }
        let i: Int = y * w + x
        if a >= 255 {
            p[i] = col
            return
        }
        let d: UInt32 = p[i]
        let ia: Int = 255 - a
        let r: Int = (Int(col & 255) * a + Int(d & 255) * ia) / 255
        let g: Int = (Int((col >> 8) & 255) * a + Int((d >> 8) & 255) * ia) / 255
        let b: Int = (Int((col >> 16) & 255) * a + Int((d >> 16) & 255) * ia) / 255
        p[i] = 0xFF00_0000 | UInt32(r) | (UInt32(g) << 8) | (UInt32(b) << 16)
    }

    func hspan(_ y: Int, _ x0: Int, _ x1: Int, _ c: UInt32, _ a: Int = 255) {
        if y < 0 || y >= h { return }
        let xa: Int = max(0, x0)
        let xb: Int = min(w - 1, x1)
        if xa > xb { return }
        if a >= 255 && !weave {
            let base: Int = y * w
            var x: Int = xa
            while x <= xb {
                p[base + x] = c
                x += 1
            }
            return
        }
        var x: Int = xa
        while x <= xb {
            put(x, y, c, a)
            x += 1
        }
    }

    func rect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: UInt32, _ a: Int = 255) {
        if rw <= 0 || rh <= 0 { return }
        let y0: Int = max(0, y)
        let y1: Int = min(h, y + rh)
        if y0 >= y1 { return }
        var yy: Int = y0
        while yy < y1 {
            hspan(yy, x, x + rw - 1, c, a)
            yy += 1
        }
    }

    func vgrad(_ y0: Int, _ y1: Int, _ top: UInt32, _ bot: UInt32) {
        if y1 <= y0 { return }
        let span: Float = Float(y1 - y0)
        var y: Int = y0
        while y < y1 {
            let t: Float = Float(y - y0) / span
            let c: UInt32 = BuddyCol.mix(top, bot, t)
            hspan(y, 0, w - 1, c, 255)
            y += 1
        }
    }

    func disc(_ cx: Float, _ cy: Float, _ r: Float, _ col: UInt32, _ a: Int = 255) {
        if !(r > 0) || !cx.isFinite || !cy.isFinite { return }
        let rr: Float = buddyClampF(r, 0, 400)
        let x0: Int = max(0, buddyFloorI(cx - rr - 1))
        let x1: Int = min(w - 1, buddyFloorI(cx + rr + 1))
        let y0: Int = max(0, buddyFloorI(cy - rr - 1))
        let y1: Int = min(h - 1, buddyFloorI(cy + rr + 1))
        if x0 > x1 || y0 > y1 { return }
        let inner: Float = max(0, rr - 0.7)
        let inner2: Float = inner * inner
        let outer: Float = rr + 0.7
        let outer2: Float = outer * outer
        var y: Int = y0
        while y <= y1 {
            let dy: Float = Float(y) + 0.5 - cy
            let dy2: Float = dy * dy
            var x: Int = x0
            while x <= x1 {
                let dx: Float = Float(x) + 0.5 - cx
                let d2: Float = dx * dx + dy2
                if d2 <= inner2 {
                    put(x, y, col, a)
                } else if d2 < outer2 {
                    let cov: Float = rr + 0.5 - sqrt(d2)
                    if cov > 0 {
                        let aa: Int = Int(buddyClampF(cov, 0, 1) * Float(a))
                        put(x, y, col, aa)
                    }
                }
                x += 1
            }
            y += 1
        }
    }

    func ellipse(_ cx: Float, _ cy: Float, _ rx: Float, _ ry: Float, _ col: UInt32, _ a: Int = 255) {
        if !(rx > 0) || !(ry > 0) || !cx.isFinite || !cy.isFinite { return }
        let rxx: Float = buddyClampF(rx, 0.5, 400)
        let ryy: Float = buddyClampF(ry, 0.5, 400)
        let x0: Int = max(0, buddyFloorI(cx - rxx - 1))
        let x1: Int = min(w - 1, buddyFloorI(cx + rxx + 1))
        let y0: Int = max(0, buddyFloorI(cy - ryy - 1))
        let y1: Int = min(h - 1, buddyFloorI(cy + ryy + 1))
        if x0 > x1 || y0 > y1 { return }
        let mr: Float = min(rxx, ryy)
        let innerN: Float = max(0, 1 - 0.7 / mr)
        let outerN: Float = 1 + 0.7 / mr
        let inner2: Float = innerN * innerN
        let outer2: Float = outerN * outerN
        var y: Int = y0
        while y <= y1 {
            let ny: Float = (Float(y) + 0.5 - cy) / ryy
            let ny2: Float = ny * ny
            var x: Int = x0
            while x <= x1 {
                let nx: Float = (Float(x) + 0.5 - cx) / rxx
                let d2: Float = nx * nx + ny2
                if d2 <= inner2 {
                    put(x, y, col, a)
                } else if d2 < outer2 {
                    let cov: Float = (1 - sqrt(d2)) * mr + 0.5
                    if cov > 0 {
                        let aa: Int = Int(buddyClampF(cov, 0, 1) * Float(a))
                        put(x, y, col, aa)
                    }
                }
                x += 1
            }
            y += 1
        }
    }

    func ring(_ cx: Float, _ cy: Float, _ r: Float, _ th: Float, _ col: UInt32, _ a: Int = 255) {
        if !(r > 0) || !cx.isFinite || !cy.isFinite { return }
        let rr: Float = buddyClampF(r, 0, 400)
        let ht: Float = max(0.5, th * 0.5)
        let x0: Int = max(0, buddyFloorI(cx - rr - ht - 1))
        let x1: Int = min(w - 1, buddyFloorI(cx + rr + ht + 1))
        let y0: Int = max(0, buddyFloorI(cy - rr - ht - 1))
        let y1: Int = min(h - 1, buddyFloorI(cy + rr + ht + 1))
        if x0 > x1 || y0 > y1 { return }
        var y: Int = y0
        while y <= y1 {
            let dy: Float = Float(y) + 0.5 - cy
            var x: Int = x0
            while x <= x1 {
                let dx: Float = Float(x) + 0.5 - cx
                let d: Float = sqrt(dx * dx + dy * dy)
                let dist: Float = abs(d - rr)
                let cov: Float = ht + 0.5 - dist
                if cov > 0 {
                    let aa: Int = Int(buddyClampF(cov, 0, 1) * Float(a))
                    put(x, y, col, aa)
                }
                x += 1
            }
            y += 1
        }
    }

    func capsule(_ ax: Float, _ ay: Float, _ bx: Float, _ by: Float, _ r: Float, _ col: UInt32, _ a: Int = 255) {
        if !(r > 0) || !ax.isFinite || !ay.isFinite || !bx.isFinite || !by.isFinite { return }
        let rr: Float = buddyClampF(r, 0, 200)
        let x0: Int = max(0, buddyFloorI(min(ax, bx) - rr - 1))
        let x1: Int = min(w - 1, buddyFloorI(max(ax, bx) + rr + 1))
        let y0: Int = max(0, buddyFloorI(min(ay, by) - rr - 1))
        let y1: Int = min(h - 1, buddyFloorI(max(ay, by) + rr + 1))
        if x0 > x1 || y0 > y1 { return }
        let vx: Float = bx - ax
        let vy: Float = by - ay
        let len2: Float = vx * vx + vy * vy
        let inner: Float = max(0, rr - 0.7)
        let inner2: Float = inner * inner
        let outer: Float = rr + 0.7
        let outer2: Float = outer * outer
        var y: Int = y0
        while y <= y1 {
            let dy: Float = Float(y) + 0.5 - ay
            var x: Int = x0
            while x <= x1 {
                let dx: Float = Float(x) + 0.5 - ax
                var t: Float = 0
                if len2 > 0.0001 {
                    t = buddyClampF((dx * vx + dy * vy) / len2, 0, 1)
                }
                let qx: Float = dx - t * vx
                let qy: Float = dy - t * vy
                let d2: Float = qx * qx + qy * qy
                if d2 <= inner2 {
                    put(x, y, col, a)
                } else if d2 < outer2 {
                    let cov: Float = rr + 0.5 - sqrt(d2)
                    if cov > 0 {
                        let aa: Int = Int(buddyClampF(cov, 0, 1) * Float(a))
                        put(x, y, col, aa)
                    }
                }
                x += 1
            }
            y += 1
        }
    }

    /// Rounded rectangle with a vertical gradient from c0 (top) to c1 (bottom). Use the same colour twice for flat fills.
    func roundRect(_ x: Float, _ y: Float, _ rw: Float, _ rh: Float, _ r: Float, _ c0: UInt32, _ c1: UInt32, _ a: Int = 255) {
        if !(rw > 0) || !(rh > 0) || !x.isFinite || !y.isFinite { return }
        let hw: Float = rw * 0.5
        let hh: Float = rh * 0.5
        let rad: Float = buddyClampF(r, 0, min(hw, hh))
        let cx: Float = x + hw
        let cy: Float = y + hh
        let xa: Int = max(0, buddyFloorI(x - 1))
        let xb: Int = min(w - 1, buddyFloorI(x + rw + 1))
        let ya: Int = max(0, buddyFloorI(y - 1))
        let yb: Int = min(h - 1, buddyFloorI(y + rh + 1))
        if xa > xb || ya > yb { return }
        var yy: Int = ya
        while yy <= yb {
            let fy: Float = Float(yy) + 0.5
            let ty: Float = buddyClampF((fy - y) / rh, 0, 1)
            let rowCol: UInt32 = (c0 == c1) ? c0 : BuddyCol.mix(c0, c1, ty)
            let ey: Float = abs(fy - cy) - (hh - rad)
            var xx: Int = xa
            while xx <= xb {
                let fx: Float = Float(xx) + 0.5
                let ex: Float = abs(fx - cx) - (hw - rad)
                var d: Float
                if ex > 0 && ey > 0 {
                    d = sqrt(ex * ex + ey * ey) - rad
                } else {
                    d = max(ex, ey) - rad
                }
                if d < -0.5 {
                    put(xx, yy, rowCol, a)
                } else if d < 0.5 {
                    let cov: Float = 0.5 - d
                    let aa: Int = Int(buddyClampF(cov, 0, 1) * Float(a))
                    put(xx, yy, rowCol, aa)
                }
                xx += 1
            }
            yy += 1
        }
    }

    func poly(_ xs: [Float], _ ys: [Float], _ col: UInt32, _ a: Int = 255) {
        let n: Int = min(xs.count, ys.count)
        if n < 3 { return }
        var minY: Float = 100000
        var maxY: Float = -100000
        var i: Int = 0
        while i < n {
            let yv: Float = buddyClampF(ys[i], -2000, 2000)
            if yv < minY { minY = yv }
            if yv > maxY { maxY = yv }
            i += 1
        }
        let y0: Int = max(0, buddyFloorI(minY))
        let y1: Int = min(h - 1, buddyFloorI(maxY))
        if y0 > y1 { return }
        var xi: [Float] = [Float](repeating: 0, count: n + 2)
        var y: Int = y0
        while y <= y1 {
            let fy: Float = Float(y) + 0.5
            var cnt: Int = 0
            var j: Int = n - 1
            var k: Int = 0
            while k < n {
                let ay: Float = ys[j]
                let by: Float = ys[k]
                if (ay <= fy && by > fy) || (by <= fy && ay > fy) {
                    let t: Float = (fy - ay) / (by - ay)
                    if cnt < n {
                        xi[cnt] = xs[j] + t * (xs[k] - xs[j])
                        cnt += 1
                    }
                }
                j = k
                k += 1
            }
            if cnt > 1 {
                var a1: Int = 1
                while a1 < cnt {
                    let v: Float = xi[a1]
                    var b1: Int = a1 - 1
                    while b1 >= 0 && xi[b1] > v {
                        xi[b1 + 1] = xi[b1]
                        b1 -= 1
                    }
                    xi[b1 + 1] = v
                    a1 += 1
                }
            }
            var m: Int = 0
            while m + 1 < cnt {
                let xa: Int = buddyFloorI(xi[m] + 0.5)
                let xb: Int = buddyFloorI(xi[m + 1] - 0.5)
                hspan(y, xa, xb, col, a)
                m += 2
            }
            y += 1
        }
    }

    func tri(_ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float, _ col: UInt32, _ a: Int = 255) {
        poly([x0, x1, x2], [y0, y1, y2], col, a)
    }

    /// Rotated rectangle centred on (cx, cy).
    func rotRect(_ cx: Float, _ cy: Float, _ hw: Float, _ hh: Float, _ ang: Float, _ col: UInt32, _ a: Int = 255) {
        let ca: Float = cos(ang)
        let sa: Float = sin(ang)
        var xs: [Float] = []
        var ys: [Float] = []
        let cxs: [Float] = [-hw, hw, hw, -hw]
        let cys: [Float] = [-hh, -hh, hh, hh]
        var i: Int = 0
        while i < 4 {
            xs.append(cx + cxs[i] * ca - cys[i] * sa)
            ys.append(cy + cxs[i] * sa + cys[i] * ca)
            i += 1
        }
        poly(xs, ys, col, a)
    }

    func star(_ cx: Float, _ cy: Float, _ ro: Float, _ ri: Float, _ points: Int, _ rot: Float, _ col: UInt32, _ a: Int = 255) {
        let n: Int = max(3, min(16, points))
        var xs: [Float] = []
        var ys: [Float] = []
        var i: Int = 0
        while i < n * 2 {
            let ang: Float = rot + Float(i) * Float.pi / Float(n)
            let rr: Float = (i % 2 == 0) ? ro : ri
            xs.append(cx + cos(ang) * rr)
            ys.append(cy + sin(ang) * rr)
            i += 1
        }
        poly(xs, ys, col, a)
    }

    /// Dotted stitching line.
    func stitch(_ ax: Float, _ ay: Float, _ bx: Float, _ by: Float, _ col: UInt32, _ gap: Float = 3.5) {
        let dx: Float = bx - ax
        let dy: Float = by - ay
        let len: Float = sqrt(dx * dx + dy * dy)
        if !len.isFinite || len < 1 { return }
        let steps: Int = min(80, max(1, Int(len / gap)))
        var i: Int = 0
        while i <= steps {
            let t: Float = Float(i) / Float(steps)
            let x: Int = buddyFloorI(ax + dx * t)
            let y: Int = buddyFloorI(ay + dy * t)
            put(x, y, col, 255)
            i += 1
        }
    }

    func stitchRing(_ cx: Float, _ cy: Float, _ r: Float, _ col: UInt32, _ count: Int) {
        let n: Int = max(4, min(60, count))
        var i: Int = 0
        while i < n {
            let ang: Float = Float(i) * 2 * Float.pi / Float(n)
            let x: Int = buddyFloorI(cx + cos(ang) * r)
            let y: Int = buddyFloorI(cy + sin(ang) * r)
            put(x, y, col, 255)
            i += 2
        }
    }
}

/// A queued text draw (text is rendered after the pixel pass because fillRect must not run inside withPixels).
struct BuddyText {
    var s: String
    var x: Int
    var y: Int
    var col: UInt32
    var scale: Int
}
