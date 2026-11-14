#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

// TYCOON TOWN rendering: backdrop, isometric board, buildings, tokens, dice, HUD and screens.

extension TycoonTown64 {
    // MARK: - Static tables

    static let skyRows: [UInt32] = {
        var a = [UInt32](repeating: 0, count: 288)
        for y in 0..<288 {
            if y < 178 {
                let t: Float = Float(y) / 177.0
                let r = tycI(74 + (255 - 74) * t)
                let gg = tycI(158 + (232 - 158) * t)
                let b = tycI(255 + (200 - 255) * t)
                a[y] = TrueColorBuffer.rgb(r, gg, b)
            } else {
                let t: Float = Float(y - 178) / 110.0
                let r = tycI(208 + (112 - 208) * t)
                let gg = tycI(214 + (140 - 214) * t)
                let b = tycI(244 + (200 - 244) * t)
                a[y] = TrueColorBuffer.rgb(r, gg, b)
            }
        }
        return a
    }()

    static func genCity(_ seed: Int, _ minH: Int, _ maxH: Int) -> [Int] {
        var out: [Int] = []
        var s = seed
        var x = 0
        while x < 640 {
            s = (s &* 1103515245 &+ 12345) & 0x7fffffff
            let w = 14 + (s >> 8) % 20
            s = (s &* 1103515245 &+ 12345) & 0x7fffffff
            let hh = minH + (s >> 8) % (maxH - minH + 1)
            out.append(x)
            out.append(w)
            out.append(hh)
            x += w + (s >> 4) % 3
        }
        return out
    }

    static let farCity: [Int] = TycoonTown64.genCity(77, 18, 58)
    static let nearCity: [Int] = TycoonTown64.genCity(1234, 26, 72)

    static let faceN: [[Float]] = [[0, 1, 0], [0, -1, 0], [1, 0, 0], [-1, 0, 0], [0, 0, 1], [0, 0, -1]]
    static let faceT1: [[Float]] = [[1, 0, 0], [1, 0, 0], [0, 0, 1], [0, 0, 1], [1, 0, 0], [1, 0, 0]]
    static let faceT2: [[Float]] = [[0, 0, 1], [0, 0, 1], [0, 1, 0], [0, 1, 0], [0, 1, 0], [0, 1, 0]]
    static let faceVal: [Int] = [1, 6, 2, 5, 3, 4]
    static let pipTable: [[Float]] = [
        [],
        [0, 0],
        [-0.5, -0.5, 0.5, 0.5],
        [-0.55, -0.55, 0, 0, 0.55, 0.55],
        [-0.5, -0.5, 0.5, -0.5, -0.5, 0.5, 0.5, 0.5],
        [-0.55, -0.55, 0.55, -0.55, 0, 0, -0.55, 0.55, 0.55, 0.55],
        [-0.5, -0.6, 0.5, -0.6, -0.5, 0, 0.5, 0, -0.5, 0.6, 0.5, 0.6]
    ]

    // MARK: - Entry

    func render(_ g: TycoonGfx) {
        updateProj()
        drawBackdrop(g)
        drawIsland(g)
        drawItems(g)
        drawLabels(g)
        drawDiceLayer(g)
        drawWorldParts(g)
        switch phase {
        case .title:
            drawTitle(g)
        case .how:
            drawHow(g)
        case .results:
            drawResults(g)
        default:
            drawHUD(g)
            drawPanel(g)
            drawDiceResult(g)
            if phase == .card { drawCard(g) }
        }
        drawScreenParts(g)
        drawFlies(g)
        drawFloats(g)
        drawBanner(g)
        drawInfoCard(g)
        if ovOpen { drawOverview(g) }
    }

    // MARK: - Backdrop

    func drawBackdrop(_ g: TycoonGfx) {
        let rows = TycoonTown64.skyRows
        for y in 0..<288 {
            let c = rows[y]
            let row = g.p + y * g.w
            for x in 0..<320 { row[x] = c }
        }
        // sun
        g.ellipseA(252, 52, 52, 52, TycoonPal.gold, 26)
        g.ellipseA(252, 52, 38, 38, TycoonPal.gold, 40)
        g.disc(252, 52, 22, TycoonPal.h(0xFFE066))
        g.disc(248, 47, 12, TycoonPal.h(0xFFF4B0))
        // clouds
        for i in 0..<cloudX.count {
            let cx: Float = cloudX[i] - pjX0 * 0.05
            drawCloud(g, cx, cloudY[i], cloudS[i])
        }
        drawCity(g, TycoonTown64.farCity, 178, TycoonPal.h(0xBCC8EE), -pjX0 * 0.04, false)
        drawCity(g, TycoonTown64.nearCity, 222, TycoonPal.h(0x8CA2D6), -pjX0 * 0.09, true)
        // balloons
        let bc: [UInt32] = [TycoonPal.red, TycoonPal.blue, TycoonPal.gold]
        for i in 0..<balX.count {
            let bx: Float = balX[i] + sin(Float(frame) * 0.02 + Float(i) * 2) * 8 - pjX0 * 0.08
            let by: Float = balY[i]
            g.line(bx, by + 9, bx + 2, by + 30, 1, TycoonPal.white)
            g.ellipse(bx, by, 8, 10, bc[i % 3])
            g.ellipse(bx - 3, by - 3, 2.5, 3.5, TycoonGfx.mix(bc[i % 3], TycoonPal.white, 0.6))
            g.tri(bx - 2, by + 14, bx + 2, by + 14, bx, by + 9, TycoonGfx.mul(bc[i % 3], 0.7))
        }
    }

    func drawCloud(_ g: TycoonGfx, _ cx: Float, _ cy: Float, _ s: Float) {
        let sh = TycoonPal.h(0xD6E2FA)
        g.ellipse(cx, cy + 4 * s, 30 * s, 9 * s, sh)
        g.ellipse(cx, cy, 27 * s, 9 * s, TycoonPal.white)
        g.ellipse(cx - 12 * s, cy - 5 * s, 12 * s, 9 * s, TycoonPal.white)
        g.ellipse(cx + 8 * s, cy - 8 * s, 14 * s, 11 * s, TycoonPal.white)
        g.ellipse(cx + 22 * s, cy - 2 * s, 10 * s, 7 * s, TycoonPal.white)
    }

    func drawCity(_ g: TycoonGfx, _ rects: [Int], _ base: Int, _ col: UInt32, _ offset: Float, _ windows: Bool) {
        var o: Float = offset.truncatingRemainder(dividingBy: 640)
        if o < 0 { o += 640 }
        let oi = tycI(o)
        let wc = TycoonPal.h(0xFFF0A8)
        var k = 0
        while k + 2 < rects.count {
            let bx = rects[k]
            let bw = rects[k + 1]
            let bh = rects[k + 2]
            for rep in 0..<2 {
                let x = bx + oi - (rep == 0 ? 640 : 0)
                if x + bw < 0 || x > 320 { continue }
                let top = base - bh
                g.rect(x, top, bw, 288 - top, col)
                g.rect(x, top, bw, 2, TycoonGfx.mul(col, 1.12))
                if windows {
                    var wy = top + 6
                    var r = 0
                    while wy < base && r < 12 {
                        var wx = x + 3
                        var c = 0
                        while wx < x + bw - 3 {
                            if ((k + r * 3 + c * 5) % 4) == 0 { g.rect(wx, wy, 2, 3, wc) }
                            wx += 6
                            c += 1
                        }
                        wy += 8
                        r += 1
                    }
                }
            }
            k += 3
        }
    }

    // MARK: - Island and board base

    func drawIsland(_ g: TycoonGfx) {
        let R: Float = 188
        let sc = pj(0, -130, 0)
        g.ellipseA(sc.0, sc.1, 210 * pjZoom, 116 * pjZoom, TycoonPal.h(0x3C4690), 44)
        let a = pj(-R, -12, R)
        let b = pj(R, -12, R)
        let c = pj(R, -12, -R)
        let apex = pj(0, -80, 0)
        g.tri(a.0, a.1, b.0, b.1, apex.0, apex.1, TycoonGfx.mul(TycoonPal.rock, 0.95))
        g.tri(b.0, b.1, c.0, c.1, apex.0, apex.1, TycoonGfx.mul(TycoonPal.rock, 0.7))
        let d0 = pj(-R, 0, R)
        let d1 = pj(R, 0, R)
        let d2 = pj(R, 0, -R)
        let d3 = pj(-R, 0, -R)
        g.quad(d0.0, d0.1, d1.0, d1.1, b.0, b.1, a.0, a.1, TycoonGfx.mul(TycoonPal.wood, 1.0))
        g.quad(d1.0, d1.1, d2.0, d2.1, c.0, c.1, b.0, b.1, TycoonGfx.mul(TycoonPal.wood, 0.72))
        g.quad(d3.0, d3.1, d2.0, d2.1, d1.0, d1.1, d0.0, d0.1, TycoonPal.grassDark)
        let L: Float = 150
        let l0 = pj(-L, 0.3, L)
        let l1 = pj(L, 0.3, L)
        let l2 = pj(L, 0.3, -L)
        let l3 = pj(-L, 0.3, -L)
        g.quad(l3.0, l3.1, l2.0, l2.1, l1.0, l1.1, l0.0, l0.1, TycoonPal.grass)
        let pc = pj(0, 0.5, 0)
        g.ellipse(pc.0, pc.1 + 2 * pjZoom, 98 * pjZoom, 98 * 0.55 * pjZoom, TycoonGfx.mul(TycoonPal.stone, 0.75))
        g.ellipse(pc.0, pc.1, 98 * pjZoom, 98 * 0.55 * pjZoom, TycoonPal.stone)
        g.ellipse(pc.0, pc.1, 78 * pjZoom, 78 * 0.55 * pjZoom, TycoonPal.h(0xFFE9B0))
        g.ellipse(pc.0, pc.1, 56 * pjZoom, 56 * 0.55 * pjZoom, TycoonPal.stone)
    }

    // MARK: - Geometry helpers

    func box(_ g: TycoonGfx, _ cx: Float, _ y0: Float, _ cz: Float, _ hw: Float, _ hd: Float, _ hgt: Float, _ top: UInt32, _ lf: UInt32, _ rt: UInt32) {
        let ya: Float = y0 + hgt
        let a = pj(cx - hw, ya, cz - hd)
        let b = pj(cx + hw, ya, cz - hd)
        let c = pj(cx + hw, ya, cz + hd)
        let d = pj(cx - hw, ya, cz + hd)
        let e = pj(cx + hw, y0, cz + hd)
        let f = pj(cx - hw, y0, cz + hd)
        let gg = pj(cx + hw, y0, cz - hd)
        g.quad(d.0, d.1, c.0, c.1, e.0, e.1, f.0, f.1, lf)
        g.quad(c.0, c.1, b.0, b.1, gg.0, gg.1, e.0, e.1, rt)
        g.quad(a.0, a.1, b.0, b.1, c.0, c.1, d.0, d.1, top)
    }

    func pyramid(_ g: TycoonGfx, _ cx: Float, _ y0: Float, _ cz: Float, _ hw: Float, _ hd: Float, _ hgt: Float, _ col: UInt32) {
        let ap = pj(cx, y0 + hgt, cz)
        let l = pj(cx - hw, y0, cz + hd)
        let n = pj(cx + hw, y0, cz + hd)
        let r = pj(cx + hw, y0, cz - hd)
        g.tri(l.0, l.1, n.0, n.1, ap.0, ap.1, col)
        g.tri(n.0, n.1, r.0, r.1, ap.0, ap.1, TycoonGfx.mul(col, 0.7))
    }

    func winL(_ g: TycoonGfx, _ cx: Float, _ y0: Float, _ cz: Float, _ hw: Float, _ hd: Float, _ u0: Float, _ u1: Float, _ v0: Float, _ v1: Float, _ col: UInt32) {
        let x0: Float = cx - hw + u0 * 2 * hw
        let x1: Float = cx - hw + u1 * 2 * hw
        let zf: Float = cz + hd
        let a = pj(x0, y0 + v0, zf)
        let b = pj(x1, y0 + v0, zf)
        let c = pj(x1, y0 + v1, zf)
        let d = pj(x0, y0 + v1, zf)
        g.quad(a.0, a.1, b.0, b.1, c.0, c.1, d.0, d.1, col)
    }

    func winR(_ g: TycoonGfx, _ cx: Float, _ y0: Float, _ cz: Float, _ hw: Float, _ hd: Float, _ u0: Float, _ u1: Float, _ v0: Float, _ v1: Float, _ col: UInt32) {
        let z0: Float = cz - hd + u0 * 2 * hd
        let z1: Float = cz - hd + u1 * 2 * hd
        let xf: Float = cx + hw
        let a = pj(xf, y0 + v0, z0)
        let b = pj(xf, y0 + v0, z1)
        let c = pj(xf, y0 + v1, z1)
        let d = pj(xf, y0 + v1, z0)
        g.quad(a.0, a.1, b.0, b.1, c.0, c.1, d.0, d.1, col)
    }

    func windows(_ g: TycoonGfx, _ cx: Float, _ y0: Float, _ cz: Float, _ hw: Float, _ hd: Float, _ hgt: Float, _ cols: Int, _ rows: Int, _ seed: Int) {
        if cols <= 0 || rows <= 0 { return }
        let litC = TycoonPal.h(0xFFE98A)
        let darkC = TycoonPal.h(0x8FB8E8)
        for r in 0..<rows {
            for c in 0..<cols {
                let lit = ((seed + r * 7 + c * 3 + frame / 110) % 4) != 0
                let u0: Float = (Float(c) + 0.2) / Float(cols)
                let u1: Float = (Float(c) + 0.8) / Float(cols)
                let v0: Float = hgt * (Float(r) + 0.28) / Float(rows)
                let v1: Float = hgt * (Float(r) + 0.78) / Float(rows)
                let cl: UInt32 = lit ? litC : darkC
                winL(g, cx, y0, cz, hw, hd, u0, u1, v0, v1, cl)
                winR(g, cx, y0, cz, hw, hd, u0, u1, v0, v1, TycoonGfx.mul(cl, 0.78))
            }
        }
    }

    // MARK: - Items (tiles, buildings, tokens, decor)

    func bucketOf(_ j: Int) -> Int {
        var v: Float = players[j].vis
        if !(v > -1000 && v < 1000) { v = 0 }
        let k = tycFloorI(v + 0.5)
        return ((k % 32) + 32) % 32
    }

    func drawItems(_ g: TycoonGfx) {
        var buckets: [Int] = []
        for j in 0..<players.count { buckets.append(bucketOf(j)) }
        for id in TycoonBoard.order {
            if id < 32 {
                drawTileFull(g, id, buckets)
            } else {
                drawDecor(g, id - 32)
            }
        }
    }

    func tileBase(_ t: TycoonTile) -> UInt32 {
        switch t.kind {
        case TycoonBoard.kStreet: return TycoonBoard.distCols[max(0, min(7, t.dist))]
        case TycoonBoard.kStation: return TycoonPal.h(0x7F98CC)
        case TycoonBoard.kStart: return TycoonPal.h(0x4CCB78)
        case TycoonBoard.kTimeOut: return TycoonPal.h(0xFFA84A)
        case TycoonBoard.kPark: return TycoonPal.h(0x9ADF58)
        case TycoonBoard.kGoTimeOut: return TycoonPal.h(0xFF6F6F)
        case TycoonBoard.kSurprise: return TycoonPal.h(0xE066E0)
        case TycoonBoard.kTreasure: return TycoonPal.h(0xFFC23C)
        default: return TycoonPal.h(0x8296E0)
        }
    }

    func drawTileFull(_ g: TycoonGfx, _ i: Int, _ buckets: [Int]) {
        let cx = TycoonBoard.tx[i]
        let cz = TycoonBoard.tz[i]
        let cs = pj(cx, 0, cz)
        let m: Float = 60 * pjZoom + 40
        if cs.0 < -m || cs.0 > 320 + m || cs.1 < -m - 60 * pjZoom || cs.1 > 288 + m { return }
        drawTileBase(g, i)
        for j in 0..<players.count where buckets[j] == i && j % 4 == 3 && !players[j].bankrupt {
            drawPlayerToken(g, j)
        }
        let t = TycoonBoard.tiles[i]
        if t.kind == TycoonBoard.kStreet {
            if tOwner[i] >= 0 { drawFlag(g, i) }
            drawBuilding(g, i)
        } else {
            drawProp(g, i)
            if t.kind == TycoonBoard.kStation && tOwner[i] >= 0 { drawFlag(g, i) }
        }
        for s in 0..<3 {
            for j in 0..<players.count where buckets[j] == i && j % 4 == s && !players[j].bankrupt {
                drawPlayerToken(g, j)
            }
        }
    }

    func drawTileBase(_ g: TycoonGfx, _ i: Int) {
        let t = TycoonBoard.tiles[i]
        let cx = TycoonBoard.tx[i]
        let cz = TycoonBoard.tz[i]
        let hs: Float = 19
        let hy: Float = TycoonBoard.tileH
        let base = tileBase(t)
        let a = pj(cx - hs, hy, cz - hs)
        let b = pj(cx + hs, hy, cz - hs)
        let c = pj(cx + hs, hy, cz + hs)
        let d = pj(cx - hs, hy, cz + hs)
        let e = pj(cx + hs, 0, cz + hs)
        let f = pj(cx - hs, 0, cz + hs)
        let gg = pj(cx + hs, 0, cz - hs)
        g.quad(d.0, d.1, c.0, c.1, e.0, e.1, f.0, f.1, TycoonGfx.mul(base, 0.8))
        g.quad(c.0, c.1, b.0, b.1, gg.0, gg.1, e.0, e.1, TycoonGfx.mul(base, 0.6))
        g.quad(a.0, a.1, b.0, b.1, c.0, c.1, d.0, d.1, base)
        // plot
        let ph: Float = 13
        let pa = pj(cx - ph, hy + 0.2, cz - ph)
        let pb = pj(cx + ph, hy + 0.2, cz - ph)
        let pc = pj(cx + ph, hy + 0.2, cz + ph)
        let pd = pj(cx - ph, hy + 0.2, cz + ph)
        var plot = TycoonGfx.mix(base, TycoonPal.white, 0.62)
        if t.kind == TycoonBoard.kStreet || t.kind == TycoonBoard.kStation {
            plot = TycoonPal.cream
            let o = tOwner[i]
            if o >= 0 && o < players.count {
                plot = TycoonGfx.mix(TycoonPal.cream, TycoonBoard.tokenCols[players[o].token % 4], 0.5)
            }
        }
        g.quad(pa.0, pa.1, pb.0, pb.1, pc.0, pc.1, pd.0, pd.1, plot)
        // active tile glow
        if inGame && i == players[max(0, min(players.count - 1, cur))].pos && phase != .results && phase != .title && phase != .how {
            let al = 70 + tycI(40 * sin(Float(frame) * 0.12))
            let ct = pj(cx, hy + 0.4, cz)
            g.ellipseA(ct.0, ct.1, 26 * pjZoom, 26 * 0.55 * pjZoom, TycoonPal.white, al)
        }
    }

    func drawFlag(_ g: TycoonGfx, _ i: Int) {
        let o = tOwner[i]
        if o < 0 || o >= players.count { return }
        let cx = TycoonBoard.tx[i] + 14
        let cz = TycoonBoard.tz[i] + 14
        let by: Float = TycoonBoard.tileH
        let p0 = pj(cx, by, cz)
        let p1 = pj(cx, by + 15, cz)
        g.line(p0.0, p0.1, p1.0, p1.1, max(1, 1.4 * pjZoom), TycoonPal.white)
        let wv: Float = sin(Float(frame) * 0.15 + Float(i)) * 1.5
        let f0 = pj(cx, by + 15, cz)
        let f1 = pj(cx, by + 10, cz)
        let f2 = pj(cx - 8, by + 12.5 + wv, cz - 8)
        g.tri(f0.0, f0.1, f1.0, f1.1, f2.0, f2.1, TycoonBoard.tokenCols[players[o].token % 4])
    }

    func drawBuilding(_ g: TycoonGfx, _ i: Int) {
        let lv = tLevel[i]
        if lv <= 0 { return }
        let t = TycoonBoard.tiles[i]
        let dcol = TycoonBoard.distCols[max(0, min(7, t.dist))]
        let anim = tAnim[i]
        var sy: Float = 1
        var sxz: Float = 1
        if anim < 40 {
            let u: Float = anim / 40
            let ease: Float = 1 - (1 - u) * (1 - u)
            let s: Float = ease + 0.22 * sin(u * 7.85) * (1 - u)
            sy = 0.3 + 0.7 * s
            sxz = 1 + (1 - sy) * 0.45
        }
        let cx = TycoonBoard.tx[i]
        let cz = TycoonBoard.tz[i]
        let by: Float = TycoonBoard.tileH
        let wall = TycoonGfx.mix(TycoonPal.white, dcol, 0.26)
        let lf = TycoonGfx.mul(wall, 0.96)
        let rt = TycoonGfx.mul(wall, 0.72)
        let tp = TycoonGfx.mul(wall, 1.04)
        let roof = TycoonGfx.mul(dcol, 0.9)
        switch lv {
        case 1:
            let w: Float = 7 * sxz
            let h: Float = 11 * sy
            box(g, cx, by, cz, w, w, h, tp, lf, rt)
            pyramid(g, cx, by + h, cz, w + 1.5, w + 1.5, 9 * sy, roof)
            winL(g, cx, by, cz, w, w, 0.38, 0.64, 0, 6 * sy, TycoonPal.wood)
            winR(g, cx, by, cz, w, w, 0.3, 0.7, 4 * sy, 8 * sy, TycoonPal.h(0xFFE98A))
        case 2:
            let w: Float = 9 * sxz
            let h: Float = 17 * sy
            box(g, cx, by, cz, w, w, h, tp, lf, rt)
            box(g, cx + 4, by + h, cz - 3, 2, 2, 7 * sy, TycoonPal.rock, TycoonGfx.mul(TycoonPal.rock, 0.9), TycoonGfx.mul(TycoonPal.rock, 0.65))
            pyramid(g, cx, by + h, cz, w + 2, w + 2, 11 * sy, roof)
            windows(g, cx, by, cz, w, w, h, 2, 1, i)
        case 3:
            let w: Float = 10 * sxz
            let h: Float = 24 * sy
            box(g, cx, by, cz, w, w, h, tp, lf, rt)
            let aw = TycoonGfx.mix(dcol, TycoonPal.white, 0.2)
            winL(g, cx, by, cz, w, w, 0.0, 1.0, h * 0.34, h * 0.44, aw)
            winR(g, cx, by, cz, w, w, 0.0, 1.0, h * 0.34, h * 0.44, TycoonGfx.mul(aw, 0.75))
            box(g, cx, by + h, cz, 6, 2.5, 6 * sy, dcol, TycoonGfx.mul(dcol, 0.92), TycoonGfx.mul(dcol, 0.7))
            windows(g, cx, by + h * 0.45, cz, w, w, h * 0.5, 2, 1, i)
            winL(g, cx, by, cz, w, w, 0.4, 0.62, 0, h * 0.3, TycoonPal.wood)
        default:
            let w: Float = 11 * sxz
            let h1: Float = 12 * sy
            box(g, cx, by, cz, w, w, h1, tp, lf, rt)
            let w2: Float = 8.5 * sxz
            let h2: Float = (lv >= 5 ? 38 : 34) * sy
            if lv >= 5 {
                let al = 36 + tycI(30 * sin(Float(frame) * 0.1))
                let gc = pj(cx, by + 34 * sy, cz)
                g.ellipseA(gc.0, gc.1, 34 * pjZoom, 38 * pjZoom, TycoonPal.gold, al)
                g.ellipseA(gc.0, gc.1, 22 * pjZoom, 26 * pjZoom, TycoonPal.goldLight, al)
            }
            let upperWall = lv >= 5 ? TycoonGfx.mix(wall, TycoonPal.goldLight, 0.45) : wall
            box(g, cx, by + h1, cz, w2, w2, h2, TycoonGfx.mul(upperWall, 1.05), TycoonGfx.mul(upperWall, 0.96), TycoonGfx.mul(upperWall, 0.72))
            windows(g, cx, by + h1, cz, w2, w2, h2, 2, 5, i)
            let top: Float = by + h1 + h2
            if lv >= 5 {
                let dc = pj(cx, top + 2, cz)
                g.ellipse(dc.0, dc.1 - 4 * pjZoom, 8.5 * pjZoom, 8 * pjZoom, TycoonPal.gold)
                g.ellipse(dc.0 - 2 * pjZoom, dc.1 - 6 * pjZoom, 3 * pjZoom, 3 * pjZoom, TycoonPal.goldLight)
                let sp = pj(cx, top + 14 * sy, cz)
                g.line(dc.0, dc.1 - 10 * pjZoom, sp.0, sp.1 - 4 * pjZoom, max(1, pjZoom), TycoonPal.goldDark)
                g.disc(sp.0, sp.1 - 4 * pjZoom, 2.4 * pjZoom, TycoonPal.red)
            } else {
                let a0 = pj(cx, top, cz)
                let a1 = pj(cx, top + 12 * sy, cz)
                g.line(a0.0, a0.1, a1.0, a1.1, max(1, pjZoom), TycoonPal.greyDark)
                g.disc(a1.0, a1.1, 1.8 * pjZoom, TycoonPal.red)
            }
        }
    }

    func drawProp(_ g: TycoonGfx, _ i: Int) {
        let t = TycoonBoard.tiles[i]
        let cx = TycoonBoard.tx[i]
        let cz = TycoonBoard.tz[i]
        let by: Float = TycoonBoard.tileH
        let fz: Float = Float(frame)
        switch t.kind {
        case TycoonBoard.kStart:
            let y: Float = by + 0.5
            let a = pj(cx + 9, y, cz - 3)
            let b = pj(cx - 3, y, cz - 3)
            let c = pj(cx - 3, y, cz + 3)
            let d = pj(cx + 9, y, cz + 3)
            g.quad(a.0, a.1, b.0, b.1, c.0, c.1, d.0, d.1, TycoonPal.h(0xFFE04A))
            let h0 = pj(cx - 3, y, cz - 8)
            let h1 = pj(cx - 3, y, cz + 8)
            let h2 = pj(cx - 13, y, cz)
            g.tri(h0.0, h0.1, h1.0, h1.1, h2.0, h2.1, TycoonPal.h(0xFFE04A))
            let p0 = pj(cx + 12, by, cz - 12)
            let p1 = pj(cx + 12, by + 22, cz - 12)
            g.line(p0.0, p0.1, p1.0, p1.1, max(1, 1.4 * pjZoom), TycoonPal.white)
            let f2 = pj(cx + 12, by + 14, cz - 12 + 9 + sin(fz * 0.15) * 2)
            let f0 = pj(cx + 12, by + 22, cz - 12)
            let f1 = pj(cx + 12, by + 14, cz - 12)
            g.tri(f0.0, f0.1, f1.0, f1.1, f2.0, f2.1, TycoonPal.red)
        case TycoonBoard.kTimeOut:
            let bc = TycoonPal.h(0x5C8CFF)
            box(g, cx - 5, by, cz, 2.6, 7, 13, bc, TycoonGfx.mul(bc, 0.9), TycoonGfx.mul(bc, 0.65))
            box(g, cx + 5, by, cz, 2.6, 7, 13, bc, TycoonGfx.mul(bc, 0.9), TycoonGfx.mul(bc, 0.65))
        case TycoonBoard.kPark:
            drawTreeAt(g, cx - 5, cz - 5, 0.8, by)
            for k in 0..<3 {
                let cp = pj(cx + 6, by + 1.5 + Float(k) * 2.2, cz + 6)
                g.ellipse(cp.0, cp.1 + 1, 6 * pjZoom, 3.2 * pjZoom, TycoonPal.goldDark)
                g.ellipse(cp.0, cp.1, 6 * pjZoom, 3.2 * pjZoom, TycoonPal.gold)
            }
        case TycoonBoard.kGoTimeOut:
            let p0 = pj(cx, by, cz)
            let p1 = pj(cx, by + 20, cz)
            g.line(p0.0, p0.1, p1.0, p1.1, max(1.5, 2 * pjZoom), TycoonPal.greyDark)
            g.ellipse(p1.0, p1.1 - 4 * pjZoom, 8 * pjZoom, 8 * pjZoom, TycoonPal.red)
            g.rect(tycI(p1.0 - 5 * pjZoom), tycI(p1.1 - 5 * pjZoom), max(2, tycI(10 * pjZoom)), max(1, tycI(2.4 * pjZoom)), TycoonPal.white)
        case TycoonBoard.kSurprise:
            let lift: Float = 2 + sin(fz * 0.1 + Float(i)) * 1.5
            let pk = TycoonPal.h(0xE866E8)
            box(g, cx, by + lift, cz, 7, 7, 10, pk, TycoonGfx.mul(pk, 0.95), TycoonGfx.mul(pk, 0.7))
            let y: Float = by + lift + 10.1
            let r0 = pj(cx - 1.3, y, cz - 7)
            let r1 = pj(cx + 1.3, y, cz - 7)
            let r2 = pj(cx + 1.3, y, cz + 7)
            let r3 = pj(cx - 1.3, y, cz + 7)
            g.quad(r0.0, r0.1, r1.0, r1.1, r2.0, r2.1, r3.0, r3.1, TycoonPal.gold)
            let bw = pj(cx, y + 2, cz)
            g.ellipse(bw.0 - 3 * pjZoom, bw.1, 3.5 * pjZoom, 2.6 * pjZoom, TycoonPal.goldLight)
            g.ellipse(bw.0 + 3 * pjZoom, bw.1, 3.5 * pjZoom, 2.6 * pjZoom, TycoonPal.goldLight)
        case TycoonBoard.kTreasure:
            let bc = TycoonPal.h(0xB5703A)
            box(g, cx, by, cz, 8, 6, 7, TycoonGfx.mul(bc, 1.1), bc, TycoonGfx.mul(bc, 0.7))
            box(g, cx, by + 7, cz, 8, 6, 3, TycoonPal.gold, TycoonPal.goldLight, TycoonPal.goldDark)
            winL(g, cx, by, cz, 8, 6, 0.42, 0.58, 2, 5.5, TycoonPal.ink)
            if (frame / 12 + i) % 4 == 0 {
                let sp = pj(cx + 4, by + 16, cz + 4)
                g.rect(tycI(sp.0) - 3, tycI(sp.1), 7, 1, TycoonPal.white)
                g.rect(tycI(sp.0), tycI(sp.1) - 3, 1, 7, TycoonPal.white)
            }
        case TycoonBoard.kTax:
            let rc = TycoonPal.h(0xFF5C5C)
            box(g, cx, by, cz, 8, 5, 7, rc, TycoonGfx.mul(rc, 0.95), TycoonGfx.mul(rc, 0.7))
            let h0 = pj(cx, by + 7, cz)
            let h1 = pj(cx, by + 11, cz)
            g.line(h0.0, h0.1, h1.0, h1.1, max(1.5, 2 * pjZoom), TycoonPal.goldDark)
            let ge = pj(cx + 9, by + 5, cz + 9)
            g.ellipse(ge.0, ge.1, 4.5 * pjZoom, 4.5 * pjZoom, TycoonPal.grey)
            g.ellipse(ge.0, ge.1, 1.8 * pjZoom, 1.8 * pjZoom, TycoonPal.greyDark)
        default:
            drawStation(g, i)
        }
    }

    func drawStation(_ g: TycoonGfx, _ i: Int) {
        let cx = TycoonBoard.tx[i]
        let cz = TycoonBoard.tz[i]
        let by: Float = TycoonBoard.tileH
        if i == 5 {
            // bus depot
            let yc = TycoonPal.h(0xFFD13A)
            box(g, cx, by + 2, cz, 11, 6, 9, yc, TycoonGfx.mul(yc, 0.95), TycoonGfx.mul(yc, 0.7))
            winL(g, cx, by + 2, cz, 11, 6, 0.1, 0.9, 4.5, 8, TycoonPal.h(0xA8DCFF))
            let w0 = pj(cx - 6, by + 2, cz + 6)
            let w1 = pj(cx + 6, by + 2, cz + 6)
            g.disc(w0.0, w0.1, 2.4 * pjZoom, TycoonPal.ink)
            g.disc(w1.0, w1.1, 2.4 * pjZoom, TycoonPal.ink)
        } else if i == 13 {
            // ferry
            let hc = TycoonPal.h(0x3C78D8)
            box(g, cx, by + 1, cz, 11, 5, 4, hc, TycoonGfx.mul(hc, 0.95), TycoonGfx.mul(hc, 0.7))
            box(g, cx, by + 5, cz, 6, 4, 5, TycoonPal.white, TycoonGfx.mul(TycoonPal.white, 0.92), TycoonGfx.mul(TycoonPal.white, 0.7))
            box(g, cx + 2, by + 10, cz, 1.6, 1.6, 5, TycoonPal.red, TycoonGfx.mul(TycoonPal.red, 0.9), TycoonGfx.mul(TycoonPal.red, 0.7))
        } else if i == 20 {
            // train
            let rc = TycoonPal.h(0xE84A4A)
            box(g, cx, by + 2, cz, 12, 4.5, 8, rc, TycoonGfx.mul(rc, 0.95), TycoonGfx.mul(rc, 0.7))
            box(g, cx + 6, by + 10, cz, 3, 3.5, 4, TycoonPal.ink, TycoonGfx.mul(TycoonPal.ink, 0.9), TycoonGfx.mul(TycoonPal.ink, 0.7))
            winL(g, cx - 4, by + 2, cz, 5, 4.5, 0.15, 0.85, 3.5, 7, TycoonPal.h(0xFFF0A8))
            let w0 = pj(cx - 6, by + 2, cz + 4.5)
            let w1 = pj(cx + 6, by + 2, cz + 4.5)
            g.disc(w0.0, w0.1, 2.4 * pjZoom, TycoonPal.ink)
            g.disc(w1.0, w1.1, 2.4 * pjZoom, TycoonPal.ink)
        } else {
            // cable car
            let p0 = pj(cx, by, cz)
            let p1 = pj(cx, by + 24, cz)
            g.line(p0.0, p0.1, p1.0, p1.1, max(1.5, 2 * pjZoom), TycoonPal.greyDark)
            let sw: Float = sin(Float(frame) * 0.05) * 6
            let gc = pj(cx + sw, by + 8, cz + sw)
            g.line(p1.0, p1.1, gc.0, gc.1, max(1, pjZoom), TycoonPal.greyDark)
            g.rrect(tycI(gc.0 - 6 * pjZoom), tycI(gc.1), max(4, tycI(12 * pjZoom)), max(4, tycI(9 * pjZoom)), 2, TycoonPal.h(0x39C0F0))
            g.rect(tycI(gc.0 - 4 * pjZoom), tycI(gc.1 + 2 * pjZoom), max(2, tycI(8 * pjZoom)), max(1, tycI(3 * pjZoom)), TycoonPal.white)
        }
    }

    func drawTreeAt(_ g: TycoonGfx, _ x: Float, _ z: Float, _ s: Float, _ y0: Float) {
        let p0 = pj(x, y0, z)
        let p1 = pj(x, y0 + 12 * s, z)
        g.line(p0.0, p0.1, p1.0, p1.1, max(1.5, 3.5 * pjZoom * s), TycoonPal.wood)
        let f1 = pj(x, y0 + 17 * s, z)
        let f2 = pj(x - 1, y0 + 24 * s, z - 1)
        g.disc(f1.0, f1.1, 11 * pjZoom * s, TycoonPal.greenDark)
        g.disc(f1.0 - 1, f1.1 - 1, 9.5 * pjZoom * s, TycoonPal.green)
        g.disc(f2.0, f2.1, 8 * pjZoom * s, TycoonGfx.mul(TycoonPal.green, 1.12))
        g.disc(f2.0 - 2 * pjZoom * s, f2.1 - 2 * pjZoom * s, 3 * pjZoom * s, TycoonGfx.mix(TycoonPal.green, TycoonPal.white, 0.5))
    }

    func drawDecor(_ g: TycoonGfx, _ k: Int) {
        if k < 0 || k >= TycoonBoard.decor.count { return }
        let d = TycoonBoard.decor[k]
        let x = d.0
        let z = d.1
        let z0 = pjZoom
        switch d.2 {
        case 0:
            let p = pj(x, 0, z)
            g.ellipse(p.0, p.1, 27 * z0, 27 * 0.55 * z0, TycoonGfx.mul(TycoonPal.stone, 0.7))
            let q = pj(x, 6, z)
            g.ellipse(q.0, q.1, 27 * z0, 27 * 0.55 * z0, TycoonPal.stone)
            g.ellipse(q.0, q.1, 22 * z0, 22 * 0.55 * z0, TycoonPal.h(0x6FC8FF))
            g.ellipse(q.0, q.1 - 1, 15 * z0, 15 * 0.55 * z0, TycoonPal.h(0x9BDCFF))
            let c = pj(x, 14, z)
            g.ellipse(c.0, c.1, 5 * z0, 4 * z0, TycoonPal.stone)
            let tp = pj(x, 26, z)
            g.rect(tycI(c.0) - max(1, tycI(1.5 * z0)), tycI(tp.1), max(2, tycI(3 * z0)), max(2, tycI(c.1 - tp.1)), TycoonPal.stone)
            for n in 0..<5 {
                let ph: Float = Float(frame) * 0.09 + Float(n) * 1.25
                let u: Float = ph - floor(ph)
                let ang: Float = Float(n) * 1.256
                let rr: Float = u * 13
                let hh: Float = 26 + 10 * sin(u * 3.14159) - u * 12
                let dp = pj(x + cos(ang) * rr, hh, z + sin(ang) * rr)
                g.disc(dp.0, dp.1, max(1, 1.8 * z0), TycoonPal.h(0xD8F2FF))
            }
        case 1:
            drawTreeAt(g, x, z, 1.1, 0)
        default:
            let p = pj(x, 4, z)
            g.disc(p.0 - 4 * z0, p.1, 6 * z0, TycoonPal.greenDark)
            g.disc(p.0 + 4 * z0, p.1 - 1, 6 * z0, TycoonPal.green)
            g.disc(p.0, p.1 - 3 * z0, 5 * z0, TycoonGfx.mul(TycoonPal.green, 1.1))
            g.disc(p.0 - 3 * z0, p.1 - 4 * z0, 1.6 * z0, TycoonPal.pink)
            g.disc(p.0 + 3 * z0, p.1 - 2 * z0, 1.6 * z0, TycoonPal.gold)
        }
    }

    // MARK: - Labels

    func drawLabels(_ g: TycoonGfx) {
        if pjZoom < 0.85 { return }
        for i in 0..<32 {
            let t = TycoonBoard.tiles[i]
            let cx = TycoonBoard.tx[i]
            let cz = TycoonBoard.tz[i]
            let sp = pj(cx + 6, TycoonBoard.tileH + 1, cz + 15)
            let px = tycI(sp.0)
            let py = tycI(sp.1)
            if px < -40 || px > 360 || py < 30 || py > 230 { continue }
            switch t.kind {
            case TycoonBoard.kStreet, TycoonBoard.kStation:
                if tOwner[i] < 0 {
                    let s = String(t.price)
                    let ww = g.textWidth(s, 1) + 12
                    g.rrect(px - ww / 2, py - 2, ww, 9, 3, TycoonPal.white)
                    g.coin(Float(px - ww / 2 + 5), Float(py + 2), 2.6)
                    g.text(s, px - ww / 2 + 9, py, TycoonPal.ink, 1)
                }
            case TycoonBoard.kPark:
                let s = "POT " + String(pot)
                let ww = g.textWidth(s, 1) + 6
                g.rrect(px - ww / 2, py - 2, ww, 9, 3, TycoonPal.gold)
                g.text(s, px - ww / 2 + 3, py, TycoonPal.ink, 1)
            case TycoonBoard.kStart, TycoonBoard.kTimeOut, TycoonBoard.kGoTimeOut, TycoonBoard.kTax:
                let s = t.kind == TycoonBoard.kGoTimeOut ? "GO TO TIME-OUT" : t.name
                let ww = g.textWidth(s, 1) + 6
                g.rrect(px - ww / 2, py - 2, ww, 9, 3, TycoonPal.ink)
                g.text(s, px - ww / 2 + 3, py, TycoonPal.white, 1)
            default:
                break
            }
        }
    }

    // MARK: - Tokens

    func tokenBodyColor(_ tk: Int, _ skin: Int) -> UInt32 {
        if skin == 1 { return TycoonPal.h(0xFFD54A) }
        if skin == 2 {
            let a: Float = Float(frame) * 0.05
            let r = tycI(160 + 95 * sin(a))
            let gg = tycI(160 + 95 * sin(a + 2.1))
            let b = tycI(160 + 95 * sin(a + 4.2))
            return TrueColorBuffer.rgb(r, gg, b)
        }
        return TycoonBoard.tokenCols[((tk % 4) + 4) % 4]
    }

    func drawPlayerToken(_ g: TycoonGfx, _ j: Int) {
        let w = tokenWorld(j)
        var s = pj(w.0, w.1, w.2)
        let gs = pj(w.0, TycoonBoard.tileH, w.2)
        let u: Float = pjZoom * 0.95
        let sq: Float = players[j].squash
        let qy: Float = 1 - 0.22 * sq
        let qx: Float = 1 + 0.2 * sq
        let isCur = inGame && j == cur && (phase == .roll || phase == .prompt || phase == .intro || phase == .menu)
        if isCur {
            s.1 -= abs(sin(Float(frame) * 0.12)) * 4 * pjZoom
        }
        let shrink: Float = max(0.5, 1 - (gs.1 - s.1) * 0.01)
        g.ellipseA(gs.0, gs.1, 10 * u * shrink, 4.5 * u * shrink, TycoonPal.h(0x202850), 80)
        drawToken(g, players[j].token, players[j].hat, players[j].skin, s.0, s.1, u, qx, qy)
        if isCur {
            let ay: Float = s.1 - 40 * u - abs(sin(Float(frame) * 0.1)) * 4
            g.tri(s.0 - 5 * u, ay - 6 * u, s.0 + 5 * u, ay - 6 * u, s.0, ay + 2 * u, TycoonPal.gold)
        }
    }

    func eyes(_ g: TycoonGfx, _ sx: Float, _ hy: Float, _ u: Float, _ sp: Float, _ r: Float) {
        let ink = TycoonPal.ink
        g.disc(sx - sp * u, hy, r * u, TycoonPal.white)
        g.disc(sx + sp * u, hy, r * u, TycoonPal.white)
        g.disc(sx - sp * u + 0.4 * u, hy + 0.3 * u, r * 0.58 * u, ink)
        g.disc(sx + sp * u + 0.4 * u, hy + 0.3 * u, r * 0.58 * u, ink)
        g.disc(sx - sp * u + 0.1 * u, hy - 0.5 * u, r * 0.22 * u, TycoonPal.white)
        g.disc(sx + sp * u + 0.1 * u, hy - 0.5 * u, r * 0.22 * u, TycoonPal.white)
    }

    func drawToken(_ g: TycoonGfx, _ token: Int, _ hat: Int, _ skin: Int, _ sx: Float, _ sy: Float, _ u: Float, _ qx: Float, _ qy: Float) {
        let tk = ((token % 4) + 4) % 4
        let body = tokenBodyColor(tk, skin)
        let dark = TycoonGfx.mul(body, 0.7)
        let light = TycoonGfx.mix(body, TycoonPal.white, 0.35)
        let hy: Float = sy - 22 * u * qy
        let by: Float = sy - 9 * u * qy
        let ink = TycoonPal.ink
        let cheek = TycoonPal.h(0xFF9EB8)
        switch tk {
        case 0:
            g.ellipse(sx + 10 * u, sy - 13 * u * qy, 3.4 * u, 2.4 * u, dark)
            g.ellipse(sx - 4.5 * u, sy - 1.4 * u, 3.8 * u, 2.2 * u, dark)
            g.ellipse(sx + 4.5 * u, sy - 1.4 * u, 3.8 * u, 2.2 * u, dark)
            g.ellipse(sx, by, 8.5 * u * qx, 8 * u * qy, body)
            g.ellipse(sx, by + 1.5 * u * qy, 5 * u * qx, 5.5 * u * qy, TycoonPal.cream)
            g.ellipse(sx - 11.5 * u * qx, hy - 1 * u, 4.2 * u, 7.5 * u * qy, dark)
            g.ellipse(sx + 11.5 * u * qx, hy - 1 * u, 4.2 * u, 7.5 * u * qy, dark)
            g.ellipse(sx, hy, 12 * u * qx, 10.5 * u * qy, body)
            g.ellipse(sx, hy + 4 * u * qy, 5.8 * u, 4.2 * u * qy, TycoonPal.cream)
            eyes(g, sx, hy - 2 * u * qy, u, 5, 2.4)
            g.disc(sx, hy + 2.4 * u * qy, 2 * u, ink)
            g.ellipse(sx + 1.5 * u, hy + 7 * u * qy, 1.6 * u, 2 * u, TycoonPal.pink)
            g.ellipseA(sx - 8 * u, hy + 3 * u * qy, 2 * u, 1.4 * u, cheek, 150)
            g.ellipseA(sx + 8 * u, hy + 3 * u * qy, 2 * u, 1.4 * u, cheek, 150)
        case 1:
            g.rect(tycI(sx - 7 * u), tycI(sy - 3 * u), max(1, tycI(5 * u)), max(1, tycI(3 * u)), dark)
            g.rect(tycI(sx + 2 * u), tycI(sy - 3 * u), max(1, tycI(5 * u)), max(1, tycI(3 * u)), dark)
            g.rrect(tycI(sx - 8 * u * qx), tycI(by - 7 * u * qy), max(2, tycI(16 * u * qx)), max(2, tycI(13 * u * qy)), 3, body)
            g.rect(tycI(sx - 3 * u), tycI(by - 3 * u * qy), max(1, tycI(6 * u)), max(1, tycI(5 * u * qy)), TycoonPal.h(0xFFE04A))
            g.disc(sx - 10 * u, hy, 2.4 * u, dark)
            g.disc(sx + 10 * u, hy, 2.4 * u, dark)
            g.rrect(tycI(sx - 11 * u * qx), tycI(hy - 9 * u * qy), max(2, tycI(22 * u * qx)), max(2, tycI(17 * u * qy)), 4, light)
            g.rrect(tycI(sx - 8.5 * u * qx), tycI(hy - 5.5 * u * qy), max(2, tycI(17 * u * qx)), max(2, tycI(10 * u * qy)), 3, ink)
            let ec = TycoonPal.h(0x7CF0FF)
            g.rect(tycI(sx - 5.5 * u), tycI(hy - 3 * u * qy), max(1, tycI(3.4 * u)), max(1, tycI(4 * u * qy)), ec)
            g.rect(tycI(sx + 2.2 * u), tycI(hy - 3 * u * qy), max(1, tycI(3.4 * u)), max(1, tycI(4 * u * qy)), ec)
            let a1 = hy - 15 * u * qy
            g.line(sx, hy - 9 * u * qy, sx, a1, max(1, 1.2 * u), ink)
            g.disc(sx, a1, 2 * u, TycoonPal.red)
        case 2:
            g.ellipse(sx - 4 * u, sy - 1.2 * u, 4 * u, 2 * u, TycoonPal.h(0xFF9A2E))
            g.ellipse(sx + 4 * u, sy - 1.2 * u, 4 * u, 2 * u, TycoonPal.h(0xFF9A2E))
            g.ellipse(sx - 10 * u * qx, by - 1 * u, 2.6 * u, 6 * u * qy, dark)
            g.ellipse(sx + 10 * u * qx, by - 1 * u, 2.6 * u, 6 * u * qy, dark)
            g.ellipse(sx, by, 8.5 * u * qx, 8 * u * qy, body)
            g.ellipse(sx, by + 1 * u * qy, 5.4 * u * qx, 6.4 * u * qy, TycoonPal.white)
            g.ellipse(sx, hy, 12 * u * qx, 10.5 * u * qy, body)
            g.ellipse(sx, hy + 2 * u * qy, 8.6 * u, 6.6 * u * qy, TycoonPal.white)
            eyes(g, sx, hy - 1.5 * u * qy, u, 4.2, 2.3)
            g.tri(sx - 3 * u, hy + 3 * u * qy, sx + 3 * u, hy + 3 * u * qy, sx, hy + 7 * u * qy, TycoonPal.h(0xFF9A2E))
            g.ellipseA(sx - 8 * u, hy + 3 * u * qy, 2 * u, 1.4 * u, cheek, 150)
            g.ellipseA(sx + 8 * u, hy + 3 * u * qy, 2 * u, 1.4 * u, cheek, 150)
        default:
            let spk = TycoonPal.h(0xFF9A2E)
            g.tri(sx + 6 * u, by - 3 * u, sx + 6 * u, by + 5 * u, sx + 17 * u, by + 6 * u, dark)
            g.ellipse(sx - 4.5 * u, sy - 1.4 * u, 3.8 * u, 2.2 * u, dark)
            g.ellipse(sx + 4.5 * u, sy - 1.4 * u, 3.8 * u, 2.2 * u, dark)
            g.ellipse(sx, by, 8.5 * u * qx, 8 * u * qy, body)
            g.ellipse(sx, by + 1.5 * u * qy, 5 * u * qx, 5.5 * u * qy, TycoonPal.h(0xFFF1B8))
            g.ellipse(sx - 9 * u, by - 1 * u, 2.2 * u, 3 * u, dark)
            g.ellipse(sx + 9 * u, by - 1 * u, 2.2 * u, 3 * u, dark)
            g.tri(sx - 7 * u, hy - 8 * u * qy, sx - 2 * u, hy - 10 * u * qy, sx - 4.5 * u, hy - 15 * u * qy, spk)
            g.tri(sx - 1.5 * u, hy - 10 * u * qy, sx + 3.5 * u, hy - 10 * u * qy, sx + 1 * u, hy - 16 * u * qy, spk)
            g.tri(sx + 4 * u, hy - 9 * u * qy, sx + 9 * u, hy - 7 * u * qy, sx + 7 * u, hy - 13 * u * qy, spk)
            g.ellipse(sx, hy, 12 * u * qx, 10.5 * u * qy, body)
            g.ellipse(sx, hy + 4 * u * qy, 7.4 * u, 5 * u * qy, light)
            g.disc(sx - 2.4 * u, hy + 3 * u * qy, 0.9 * u, dark)
            g.disc(sx + 2.4 * u, hy + 3 * u * qy, 0.9 * u, dark)
            eyes(g, sx, hy - 2.5 * u * qy, u, 5, 2.4)
            g.ellipseA(sx - 8.5 * u, hy + 2 * u * qy, 2 * u, 1.4 * u, cheek, 150)
            g.ellipseA(sx + 8.5 * u, hy + 2 * u * qy, 2 * u, 1.4 * u, cheek, 150)
        }
        if hat > 0 { drawHat(g, hat, sx, hy - 10 * u * qy, u) }
        _ = ink
    }

    func drawHat(_ g: TycoonGfx, _ hat: Int, _ sx: Float, _ ty: Float, _ u: Float) {
        switch hat {
        case 1:
            g.tri(sx - 5.5 * u, ty + 1 * u, sx + 5.5 * u, ty + 1 * u, sx, ty - 14 * u, TycoonPal.h(0xFF6FB5))
            g.tri(sx - 3 * u, ty - 4 * u, sx + 3 * u, ty - 4 * u, sx, ty - 14 * u, TycoonPal.h(0xFFE04A))
            g.disc(sx, ty - 14.5 * u, 2.2 * u, TycoonPal.gold)
        case 2:
            let c = TycoonPal.gold
            g.rect(tycI(sx - 7 * u), tycI(ty - 5 * u), max(2, tycI(14 * u)), max(1, tycI(6 * u)), c)
            g.tri(sx - 7 * u, ty - 5 * u, sx - 3.5 * u, ty - 5 * u, sx - 5.5 * u, ty - 10 * u, c)
            g.tri(sx - 2 * u, ty - 5 * u, sx + 2 * u, ty - 5 * u, sx, ty - 11 * u, c)
            g.tri(sx + 3.5 * u, ty - 5 * u, sx + 7 * u, ty - 5 * u, sx + 5.5 * u, ty - 10 * u, c)
            g.disc(sx, ty - 2.5 * u, 1.5 * u, TycoonPal.red)
        case 3:
            g.ellipse(sx, ty - 1 * u, 8 * u, 4.5 * u, TycoonPal.h(0xFF5C5C))
            g.ellipse(sx - 2 * u, ty - 2.5 * u, 3 * u, 1.5 * u, TycoonPal.h(0xFF9A9A))
            let bl: Float = cos(Float(frame) * 0.4) * 8 * u
            g.line(sx, ty - 4 * u, sx, ty - 7 * u, max(1, u), TycoonPal.ink)
            g.line(sx - bl, ty - 7 * u, sx + bl, ty - 7 * u, max(1.5, 1.6 * u), TycoonPal.h(0x4C9CFF))
        case 4:
            let fx: Float = sx + 5 * u
            let fy: Float = ty - 2 * u
            for k in 0..<5 {
                let a: Float = Float(k) * 1.2566
                g.disc(fx + cos(a) * 3 * u, fy + sin(a) * 3 * u, 2.2 * u, TycoonPal.pink)
            }
            g.disc(fx, fy, 1.8 * u, TycoonPal.gold)
        case 5:
            for k in 0..<7 {
                let a: Float = Float(k) * 0.8976 + Float(frame) * 0.06
                g.disc(sx + cos(a) * 9 * u, ty - 6 * u + sin(a) * 3 * u, 1.7 * u, TycoonPal.gold)
            }
        default:
            g.ellipse(sx, ty - 1.5 * u, 9.5 * u, 6 * u, TycoonPal.h(0x3C78D8))
            g.ellipse(sx + 6 * u, ty + 1 * u, 7 * u, 2.2 * u, TycoonPal.h(0x2C5AA8))
            g.disc(sx, ty - 6 * u, 1.4 * u, TycoonPal.h(0x2C5AA8))
        }
    }

    // MARK: - Dice

    func drawDiceLayer(_ g: TycoonGfx) {
        if phase == .rolling {
            drawDie(g, 0, d1)
            drawDie(g, 1, d2)
        } else if phase == .roll && !players[cur].ai {
            drawDie(g, 0, d1)
            drawDie(g, 1, d2)
        }
    }

    func drawDie(_ g: TycoonGfx, _ k: Int, _ val: Int) {
        let dd: Float = Float(TycoonTown64.diceDur)
        let idle = phase != .rolling
        var t: Float = idle ? 1 : min(1, Float(diceT) / dd)
        if t < 0 { t = 0 }
        let rx: Float = k == 0 ? -9 : 9
        let rz: Float = k == 0 ? 9 : -9
        let sx0: Float = k == 0 ? 64 : 82
        let sz0: Float = k == 0 ? 82 : 64
        let hp: Float = 1 - (1 - t) * (1 - t)
        let x: Float = sx0 + (rx - sx0) * hp
        let z: Float = sz0 + (rz - sz0) * hp
        var arc: Float = 0
        if idle {
            arc = 3 + sin(Float(frame) * 0.1 + Float(k) * 1.7) * 2.5
        } else if t < 0.5 {
            let u: Float = t / 0.5
            arc = 46 * 4 * u * (1 - u) + (0.5 - t) * 30
        } else if t < 0.8 {
            let u: Float = (t - 0.5) / 0.3
            arc = 16 * 4 * u * (1 - u)
        } else {
            let u: Float = (t - 0.8) / 0.2
            arc = 5 * 4 * u * (1 - u)
        }
        let D: Float = 8
        let y: Float = D + 0.5 + arc
        let yaw: Float = diceYaw[k % 2] + (idle ? sin(Float(frame) * 0.04 + Float(k)) * 0.25 : 0)
        let fin = TycoonM3.rotY(yaw).mul(TycoonM3.faceUp(max(1, min(6, val))))
        var m = fin
        if !idle {
            let tt: Float = min(1, t / 0.9)
            let rem: Float = 1 - tt
            let ang: Float = diceSpin[k % 2] * rem * rem
            if rem > 0 {
                m = TycoonM3.axis(diceAxis[k * 3], diceAxis[k * 3 + 1], diceAxis[k * 3 + 2], ang).mul(fin)
            }
        }
        // shadow
        let sp = pj(x, 0.6, z)
        let shr: Float = max(0.5, 1 - arc * 0.012)
        g.ellipseA(sp.0, sp.1, 13 * pjZoom * shr, 13 * 0.55 * pjZoom * shr, TycoonPal.h(0x1C2450), 80)
        let body: UInt32 = k == 0 ? TycoonPal.h(0xFF5A5A) : TycoonPal.h(0x4C9CFF)
        for f in 0..<6 {
            let n = TycoonTown64.faceN[f]
            let t1 = TycoonTown64.faceT1[f]
            let t2 = TycoonTown64.faceT2[f]
            let rn = m.apply(n[0], n[1], n[2])
            let vis: Float = rn.0 * 0.5904 + rn.1 * 0.55 + rn.2 * 0.5904
            if vis <= 0.02 { continue }
            let lit: Float = max(0, rn.0 * -0.35 + rn.1 * 0.8 + rn.2 * 0.4)
            let col = TycoonGfx.mul(body, 0.66 + 0.4 * lit)
            var px: [Float] = [0, 0, 0, 0]
            var py: [Float] = [0, 0, 0, 0]
            let s1: [Float] = [-1, 1, 1, -1]
            let s2: [Float] = [-1, -1, 1, 1]
            for c in 0..<4 {
                let lx: Float = n[0] + s1[c] * t1[0] + s2[c] * t2[0]
                let ly: Float = n[1] + s1[c] * t1[1] + s2[c] * t2[1]
                let lz: Float = n[2] + s1[c] * t1[2] + s2[c] * t2[2]
                let r = m.apply(lx, ly, lz)
                let p = pj(x + D * r.0, y + D * r.1, z + D * r.2)
                px[c] = p.0
                py[c] = p.1
            }
            g.quad(px[0], py[0], px[1], py[1], px[2], py[2], px[3], py[3], col)
            let edge = TycoonGfx.mul(body, 0.5)
            let et: Float = max(1, pjZoom * 1.1)
            g.line(px[0], py[0], px[1], py[1], et, edge)
            g.line(px[1], py[1], px[2], py[2], et, edge)
            g.line(px[2], py[2], px[3], py[3], et, edge)
            g.line(px[3], py[3], px[0], py[0], et, edge)
            let fv = TycoonTown64.faceVal[f]
            let pips = TycoonTown64.pipTable[fv]
            var q = 0
            while q + 1 < pips.count {
                let pu: Float = pips[q]
                let pv: Float = pips[q + 1]
                var qx: [Float] = [0, 0, 0, 0]
                var qy: [Float] = [0, 0, 0, 0]
                let o1: [Float] = [-1, 1, 1, -1]
                let o2: [Float] = [-1, -1, 1, 1]
                for c in 0..<4 {
                    let uu: Float = pu + o1[c] * 0.2
                    let vv: Float = pv + o2[c] * 0.2
                    let lx: Float = n[0] * 1.01 + uu * t1[0] + vv * t2[0]
                    let ly: Float = n[1] * 1.01 + uu * t1[1] + vv * t2[1]
                    let lz: Float = n[2] * 1.01 + uu * t1[2] + vv * t2[2]
                    let r = m.apply(lx, ly, lz)
                    let p = pj(x + D * r.0, y + D * r.1, z + D * r.2)
                    qx[c] = p.0
                    qy[c] = p.1
                }
                g.quad(qx[0], qy[0], qx[1], qy[1], qx[2], qy[2], qx[3], qy[3], TycoonPal.white)
                q += 2
            }
        }
    }

    func drawDiceResult(_ g: TycoonGfx) {
        if phase != .rolling || diceT < TycoonTown64.diceDur { return }
        let age: Int = diceT - TycoonTown64.diceDur
        let pop: Float = min(1, Float(age) / 8)
        let sc = pj(0, 40, 0)
        let s = String(d1 + d2)
        let r: Float = (14 + 4 * sin(Float(age) * 0.3)) * pop
        g.disc(sc.0, sc.1, r + 2, TycoonPal.ink)
        g.disc(sc.0, sc.1, r, TycoonPal.gold)
        if pop > 0.6 {
            g.textCO(s, tycI(sc.0), tycI(sc.1) - 7, TycoonPal.white, 3, TycoonPal.ink)
        }
    }

    // MARK: - Particles

    func drawWorldParts(_ g: TycoonGfx) {
        for p in parts where p.life > 0 && p.kind != 2 {
            let s = pj(p.x, p.y, p.z)
            if s.0 < -10 || s.0 > 330 || s.1 < -10 || s.1 > 300 { continue }
            let ratio: Float = Float(p.life) / Float(max(1, p.maxLife))
            if p.kind == 1 {
                g.ellipseA(s.0, s.1, p.size * pjZoom * (1.5 - ratio), p.size * pjZoom * 0.8 * (1.5 - ratio), p.col, tycI(150 * ratio))
            } else {
                let sz = max(1, tycI(p.size * (0.5 + ratio * 0.6)))
                let px = tycI(s.0)
                let py = tycI(s.1)
                g.rect(px - sz, py, sz * 2 + 1, 1, p.col)
                g.rect(px, py - sz, 1, sz * 2 + 1, p.col)
                g.rect(px - 1, py - 1, 2, 2, TycoonPal.white)
            }
        }
    }

    func drawScreenParts(_ g: TycoonGfx) {
        for p in parts where p.life > 0 && p.kind == 2 {
            let wv: Float = abs(cos(p.spin)) * p.size
            g.rect(tycI(p.x), tycI(p.y), max(1, tycI(wv)), max(1, tycI(p.size * 0.7)), p.col)
        }
    }

    func drawFlies(_ g: TycoonGfx) {
        for f in flies where f.active && f.delay <= 0 {
            let t: Float = min(1, f.t)
            let x: Float = f.sx + (f.ex - f.sx) * t
            let y: Float = f.sy + (f.ey - f.sy) * t - 40 * sin(Float.pi * t)
            let sq: Float = abs(cos(t * 12)) * 5 + 1.5
            g.ellipse(x, y + 1, sq, 5.5, TycoonPal.goldDark)
            g.ellipse(x, y, sq, 5.5, TycoonPal.gold)
        }
    }

    func drawFloats(_ g: TycoonGfx) {
        for f in floats where f.life > 0 {
            if !f.text.isEmpty {
                let cx = max(50, min(270, tycI(f.x)))
                g.textCO(f.text, cx, tycI(f.y), f.col, 1, TycoonPal.ink)
            } else {
                let sign = f.amt >= 0 ? "+" : "-"
                let n = abs(f.amt)
                let total = 8 + g.moneyWidth(n, 2)
                let x0 = max(2, min(318 - total, tycI(f.x) - total / 2))
                g.textO(sign, x0, tycI(f.y), f.col, 2, TycoonPal.ink)
                g.money(x0 + 8, tycI(f.y), n, 2, f.col, TycoonPal.ink)
            }
        }
    }

    // MARK: - Banner

    func drawBanner(_ g: TycoonGfx) {
        if bannerT >= 80 { return }
        let u: Float = Float(bannerT)
        var pop: Float = 1
        if u < 10 {
            let k: Float = u / 10
            pop = 1 + 0.25 * sin(k * 3.1416) - (1 - k) * 0.9
        }
        var yOff: Float = (1 - min(1, pop)) * -50
        if u > 66 { yOff -= (u - 66) * 8 }
        let tw = g.textWidth(bannerText, 3)
        let rw = tw + 56
        let h = 30
        let x0 = 160 - rw / 2
        let y0 = 78 + tycI(yOff)
        let col = bannerCol
        let dk = TycoonGfx.mul(col, 0.6)
        // tails
        g.quad(Float(x0 - 14), Float(y0 + 8), Float(x0 + 8), Float(y0 + 8), Float(x0 + 8), Float(y0 + h + 8), Float(x0 - 14), Float(y0 + h + 8), dk)
        g.tri(Float(x0 - 14), Float(y0 + 8), Float(x0 - 4), Float(y0 + 8 + h / 2), Float(x0 - 14), Float(y0 + h + 8), dk)
        g.quad(Float(x0 + rw - 8), Float(y0 + 8), Float(x0 + rw + 14), Float(y0 + 8), Float(x0 + rw + 14), Float(y0 + h + 8), Float(x0 + rw - 8), Float(y0 + h + 8), dk)
        g.rect(x0 + 2, y0 + 3, rw, h, TycoonGfx.mul(col, 0.55))
        g.rect(x0, y0, rw, h, col)
        g.rect(x0, y0, rw, h / 2, TycoonGfx.mix(col, TycoonPal.white, 0.3))
        g.rect(x0, y0 + h - 3, rw, 3, dk)
        g.rect(x0, y0, rw, 2, TycoonPal.white)
        g.textCO(bannerText, 160, y0 + 8, TycoonPal.white, 3, TycoonPal.ink)
    }

    // MARK: - HUD

    func drawAvatar(_ g: TycoonGfx, _ pl: TycoonPlayer, _ cx: Float, _ baseY: Float, _ u: Float) {
        drawToken(g, pl.token, pl.hat, pl.skin, cx, baseY, u, 1, 1)
    }

    func drawHUD(_ g: TycoonGfx) {
        // round progress
        g.rect(0, 0, 320, 11, TycoonPal.h(0x1C2554))
        let frac: Float = Float(min(round, TycoonBoard.maxRounds)) / Float(TycoonBoard.maxRounds)
        let fw = max(2, tycI(320 * frac))
        g.rect(0, 0, fw, 11, TycoonPal.h(0xFFB21C))
        g.rect(0, 0, fw, 5, TycoonPal.h(0xFFD866))
        g.rect(0, 10, 320, 1, TycoonPal.h(0x0E1438))
        g.textCS("ROUND " + String(min(round, TycoonBoard.maxRounds)) + "/" + String(TycoonBoard.maxRounds), 160, 3, TycoonPal.white, 1, TycoonPal.ink)
        let pt = "POT " + String(pot)
        g.textS(pt, 316 - g.textWidth(pt, 1), 3, TycoonPal.white, 1, TycoonPal.ink)
        // players
        let sw = slotW()
        for i in 0..<players.count {
            let pl = players[i]
            let x0 = i * sw
            let active = (i == cur) && !pl.bankrupt
            let bg: UInt32 = active ? TycoonPal.h(0x5A6ED8) : TycoonPal.h(0x2C3A86)
            g.rrect(x0 + 2, 12, sw - 4, 23, 4, bg)
            if active {
                let pulse = 2 + tycI(1.2 * sin(Float(frame) * 0.15))
                g.frame(x0 + 2, 12, sw - 4, 23, pulse > 2 ? 2 : 1, TycoonPal.gold)
            }
            g.rect(x0 + 4, 14, 3, 19, TycoonBoard.tokenCols[pl.token % 4])
            drawAvatar(g, pl, Float(x0 + 17), 33, 0.5)
            if pl.bankrupt {
                g.textS("OUT", x0 + 28, 17, TycoonPal.grey, 2, TycoonPal.ink)
            } else {
                g.textS(String(tycI(pl.shown)), x0 + 28, 15, TycoonPal.goldLight, 2, TycoonPal.ink)
                let nm = i == 0 ? "YOU" : TycoonBoard.tokenNames[pl.token % 4]
                g.text(nm, x0 + 28, 27, TycoonPal.white, 1)
            }
        }
    }

    func drawButton(_ g: TycoonGfx, _ r: (Int, Int, Int, Int), _ label: String, _ hint: String, _ col: UInt32, _ selected: Bool, _ cost: Int) {
        let hotNow = hot(r)
        let x = r.0
        let y = r.1 + (hotNow ? 2 : 0)
        let w = r.2
        let h = r.3 - 3
        var c = col
        if hotNow { c = TycoonGfx.mix(col, TycoonPal.white, 0.3) }
        g.rrect(x, y + 3, w, h, 6, TycoonGfx.mul(col, 0.5))
        if selected {
            let pul = 2 + tycI(1.5 * sin(Float(frame) * 0.2))
            g.rrect(x - pul, y - pul, w + pul * 2, h + pul * 2, 8, TycoonPal.white)
        }
        g.rrect(x, y, w, h, 6, c)
        g.rrect(x + 3, y + 2, w - 6, h / 2 - 2, 4, TycoonGfx.mix(c, TycoonPal.white, 0.35))
        // badge
        let cy = Float(y) + Float(h) / 2
        g.disc(Float(x + 14), cy, 8.5, TycoonPal.ink)
        g.disc(Float(x + 14), cy, 7, TycoonPal.white)
        g.textC(hint, x + 14, tycI(cy) - 2, TycoonPal.ink, 1)
        var tw = g.textWidth(label, 2)
        if cost > 0 { tw += 6 + g.moneyWidth(cost, 2) }
        let tx0 = x + 26 + max(0, (w - 26 - tw) / 2)
        let ty = y + (h - 10) / 2
        g.textS(label, tx0, ty, TycoonPal.white, 2, TycoonGfx.mul(col, 0.4))
        if cost > 0 {
            g.money(tx0 + g.textWidth(label, 2) + 6, ty, cost, 2, TycoonPal.white, TycoonGfx.mul(col, 0.4))
        }
    }

    func drawPanel(_ g: TycoonGfx) {
        g.rect(0, 226, 320, 62, TycoonPal.panel)
        g.rect(0, 226, 320, 2, TycoonPal.panelLight)
        g.rect(0, 228, 320, 1, TycoonGfx.mul(TycoonPal.panelLight, 0.7))
        let human = cur >= 0 && cur < players.count && !players[cur].ai
        switch phase {
        case .roll:
            g.textCS(msgA, 160, 230, TycoonPal.white, 1, TycoonPal.ink)
            if human {
                let r = TycoonUI.rollBtn
                let pulse: Float = 1 + 0.05 * sin(Float(frame) * 0.2)
                let ww = tycI(Float(r.2) * pulse)
                let hh = tycI(Float(r.3) * pulse)
                let rr = (160 - ww / 2, r.1 + (r.3 - hh) / 2, ww, hh)
                drawBigRoll(g, rr)
                let left = max(0, 540 - phaseT)
                g.rect(60, 240, 200 * left / 540, 2, TycoonPal.gold)
            } else {
                g.textCS(who(cur) + " IS ROLLING...", 160, 252, TycoonPal.goldLight, 2, TycoonPal.ink)
            }
        case .prompt, .menu:
            drawPromptPanel(g)
        default:
            g.textCS(msgA, 160, 236, TycoonPal.white, 2, TycoonPal.ink)
            g.textCS(msgB, 160, 256, TycoonPal.goldLight, 1, TycoonPal.ink)
            if human && phase != .wait && phase != .hop && phase != .rolling && phase != .card {
                g.textCS("HOLD A TO SPEED UP", 160, 272, TycoonPal.grey, 1, TycoonPal.ink)
            }
        }
        _ = human
    }

    func drawBigRoll(_ g: TycoonGfx, _ r: (Int, Int, Int, Int)) {
        let hotNow = hot(TycoonUI.rollBtn)
        let x = r.0
        let y = r.1 + (hotNow ? 2 : 0)
        let w = r.2
        let h = r.3 - 4
        let col: UInt32 = hotNow ? TycoonPal.h(0xFFB040) : TycoonPal.h(0xFF8A1C)
        g.rrect(x, y + 4, w, h, 10, TycoonPal.h(0xA04A08))
        g.rrect(x - 2, y - 2, w + 4, h + 4, 12, TycoonPal.white)
        g.rrect(x, y, w, h, 10, col)
        g.rrect(x + 4, y + 3, w - 8, h / 2 - 3, 7, TycoonPal.h(0xFFC56A))
        g.rect(x + 10, y + 4, w / 3, 2, TycoonPal.white)
        g.disc(Float(x + 20), Float(y + h / 2), 9, TycoonPal.ink)
        g.disc(Float(x + 20), Float(y + h / 2), 7.5, TycoonPal.white)
        g.textC("A", x + 20, y + h / 2 - 2, TycoonPal.ink, 1)
        g.textCO("ROLL!", x + w / 2 + 10, y + (h - 15) / 2, TycoonPal.white, 3, TycoonPal.h(0x7A3004))
    }

    func rentLadder(_ tile: Int) -> String {
        let t = TycoonBoard.tiles[tile]
        if t.kind == TycoonBoard.kStation { return "RENT 25/50/100/200" }
        var s = "RENT"
        for lv in 0..<5 {
            s += (lv == 0 ? " " : "/") + String(t.price * TycoonBoard.rentMult[lv] / 100)
        }
        return s
    }

    func drawPromptPanel(_ g: TycoonGfx) {
        let tile = phase == .menu ? (menuIdx >= 0 && menuIdx < menuList.count ? menuList[menuIdx] : 0) : promptTile
        let t = TycoonBoard.tiles[max(0, min(31, tile))]
        let col: UInt32 = t.kind == TycoonBoard.kStreet ? TycoonBoard.distCols[max(0, min(7, t.dist))] : TycoonPal.h(0x7F98CC)
        g.rrect(8, 231, 9, 12, 2, col)
        let nameX = 22
        if phase == .menu {
            g.textS(t.name, nameX + 30, 231, TycoonPal.white, 2, TycoonPal.ink)
            let next = tLevel[tile] + 1
            let line = "NOW " + TycoonBoard.levelName(tLevel[tile]) + " > " + TycoonBoard.levelName(next)
            g.textCS(line, 160, 246, TycoonPal.goldLight, 1, TycoonPal.ink)
            drawArrowButton(g, TycoonUI.menuLeft, true)
            drawArrowButton(g, TycoonUI.menuRight, false)
            drawButton(g, TycoonUI.btn0, "BUILD", "A", TycoonPal.h(0x2FC76A), true, TycoonBoard.buildCost(tile, next))
            drawButton(g, TycoonUI.btn1, "SKIP", "B", TycoonPal.h(0x8A94C8), false, 0)
            let left = max(0, 600 - phaseT)
            g.rect(8, 252, 304 * left / 600, 2, TycoonPal.gold)
            return
        }
        g.textS(t.name, nameX, 231, TycoonPal.white, 2, TycoonPal.ink)
        if promptKind == 1 {
            let pw = g.moneyWidth(t.price, 2)
            g.money(314 - pw, 231, t.price, 2, TycoonPal.goldLight, TycoonPal.ink)
            g.text(rentLadder(tile), 8, 246, TycoonPal.goldLight, 1)
            drawButton(g, TycoonUI.btn0, "BUY", "A", TycoonPal.h(0x2FC76A), promptSel == 0, t.price)
        } else {
            let next = tLevel[tile] + 1
            let cost = TycoonBoard.buildCost(tile, next)
            let line = "BUILD A " + TycoonBoard.levelName(next)
            g.text(line, 8, 246, TycoonPal.goldLight, 1)
            let nr = t.price * TycoonBoard.rentMult[min(5, next)] / 100
            g.text("NEW RENT " + String(nr), 200, 246, TycoonPal.goldLight, 1)
            drawButton(g, TycoonUI.btn0, "BUILD", "A", TycoonPal.h(0x2FC76A), promptSel == 0, cost)
        }
        drawButton(g, TycoonUI.btn1, "SKIP", "B", TycoonPal.h(0x8A94C8), promptSel == 1, 0)
        if !players[cur].ai {
            let left = max(0, 780 - promptT)
            g.rect(8, 252, 304 * left / 780, 2, TycoonPal.gold)
        }
    }

    func drawArrowButton(_ g: TycoonGfx, _ r: (Int, Int, Int, Int), _ left: Bool) {
        let hotNow = hot(r)
        let c: UInt32 = hotNow ? TycoonPal.h(0xA0B4FF) : TycoonPal.h(0x6A80E8)
        g.rrect(r.0, r.1, r.2, r.3 - 4, 6, c)
        let cx = Float(r.0 + r.2 / 2)
        let cy = Float(r.1 + (r.3 - 4) / 2)
        if left {
            g.tri(cx + 6, cy - 8, cx + 6, cy + 8, cx - 7, cy, TycoonPal.white)
        } else {
            g.tri(cx - 6, cy - 8, cx - 6, cy + 8, cx + 7, cy, TycoonPal.white)
        }
    }

    // MARK: - Card overlay

    func drawCard(_ g: TycoonGfx) {
        let prog: Float = min(1, Float(cardT) / 36)
        let sx: Float = abs(cos(prog * Float.pi))
        let front = prog >= 0.5
        let w = max(4, tycI(190 * sx))
        let h = 104
        let x = 160 - w / 2
        let y = 62
        let hdr: UInt32 = cardSurprise ? TycoonPal.h(0xE05CE0) : TycoonPal.h(0xFFB400)
        g.rrect(x - 3, y - 3, w + 6, h + 6, 8, TycoonPal.ink)
        if !front {
            g.rrect(x, y, w, h, 7, hdr)
            if w > 30 {
                g.rrect(x + 6, y + 6, w - 12, h - 12, 5, TycoonGfx.mul(hdr, 0.8))
                if cardSurprise {
                    g.textCO("?", 160, y + 38, TycoonPal.white, 4, TycoonPal.ink)
                } else {
                    g.coin(160, Float(y + 52), 18)
                }
            }
            return
        }
        g.rrect(x, y, w, h, 7, TycoonPal.cream)
        g.rrect(x, y, w, 24, 7, hdr)
        g.rect(x, y + 14, w, 10, hdr)
        if w > 120 {
            g.textCO(curCard.l1, 160, y + 7, TycoonPal.white, 2, TycoonPal.ink)
            switch curCard.kind {
            case 0:
                let tw = g.moneyWidth(curCard.amt, 3) + 12
                g.textO("+", 160 - tw / 2, y + 36, TycoonPal.green, 3, TycoonPal.ink)
                g.money(160 - tw / 2 + 12, y + 36, curCard.amt, 3, TycoonPal.goldDark, TycoonPal.cream)
            case 1:
                let tw = g.moneyWidth(curCard.amt, 3) + 12
                g.textO("-", 160 - tw / 2, y + 36, TycoonPal.red, 3, TycoonPal.ink)
                g.money(160 - tw / 2 + 12, y + 36, curCard.amt, 3, TycoonPal.goldDark, TycoonPal.cream)
            default:
                g.disc(160, Float(y + 46), 12, hdr)
                g.disc(160, Float(y + 46), 9, TycoonPal.white)
                g.textC("!", 160, y + 41, TycoonPal.ink, 2)
            }
            g.textC(curCard.l2, 160, y + 70, TycoonPal.ink, 1)
            if cardT > 50 && !players[cur].ai {
                let r = (110, y + h + 8, 100, 30)
                drawButton(g, r, "OK", "A", TycoonPal.h(0x2FC76A), true, 0)
            }
        }
    }

    // MARK: - Info card (tapped tile)

    func drawInfoCard(_ g: TycoonGfx) {
        if infoTile < 0 || infoTile >= 32 { return }
        let t = TycoonBoard.tiles[infoTile]
        let x = 24
        let y = 40
        g.rrect(x - 2, y - 2, 276, 78, 9, TycoonPal.ink)
        g.rrect(x, y, 272, 74, 8, TycoonPal.cream)
        g.rrect(x, y, 272, 20, 8, tileBase(t))
        g.rect(x, y + 12, 272, 8, tileBase(t))
        g.textCO(t.name, 160, y + 5, TycoonPal.white, 2, TycoonPal.ink)
        if t.kind == TycoonBoard.kStreet || t.kind == TycoonBoard.kStation {
            let o = tOwner[infoTile]
            let ow = o < 0 ? "FOR SALE" : "OWNER " + who(o)
            g.text(ow, x + 10, y + 28, TycoonPal.ink, 2)
            if t.kind == TycoonBoard.kStreet {
                g.text(TycoonBoard.levelName(tLevel[infoTile]), x + 10, y + 46, TycoonPal.greyDark, 2)
            }
            let rent = o < 0 ? t.price : rentFor(infoTile)
            let label = o < 0 ? "PRICE" : "RENT"
            g.text(label, x + 150, y + 28, TycoonPal.ink, 2)
            g.money(x + 150, y + 46, rent, 2, TycoonPal.goldDark, TycoonPal.cream)
        } else {
            g.textC("A SPECIAL TILE", 160, y + 36, TycoonPal.ink, 2)
        }
        g.textC("TAP TO CLOSE", 160, y + 64, TycoonPal.greyDark, 1)
    }

    // MARK: - Overview

    func drawOverview(_ g: TycoonGfx) {
        g.rectA(0, 30, 320, 258, TycoonPal.h(0x141C48), 200)
        g.textCS("TOWN MAP", 160, 34, TycoonPal.white, 2, TycoonPal.ink)
        for i in 0..<8 {
            let r = TycoonUI.ovCell(i)
            let hotNow = hot(r)
            let sel = ovSel == i
            g.rrect(r.0, r.1, r.2, r.3, 5, hotNow ? TycoonPal.h(0x5668C8) : TycoonPal.h(0x34428E))
            if sel { g.frame(r.0, r.1, r.2, r.3, 2, TycoonPal.gold) }
            g.rect(r.0 + 4, r.1 + 4, 5, r.3 - 8, TycoonBoard.distCols[i])
            g.text(TycoonBoard.distNames[i], r.0 + 13, r.1 + 5, TycoonPal.white, 1)
            let list = TycoonBoard.distTiles[i]
            for (j, tile) in list.enumerated() {
                let bx = r.0 + 13 + j * 44
                let by = r.1 + 16
                let o = tOwner[tile]
                var c: UInt32 = TycoonPal.greyDark
                if o >= 0 && o < players.count { c = TycoonBoard.tokenCols[players[o].token % 4] }
                g.rrect(bx, by, 40, 20, 3, c)
                if o < 0 {
                    g.textC(String(TycoonBoard.tiles[tile].price), bx + 20, by + 7, TycoonPal.white, 1)
                } else {
                    let lv = tLevel[tile]
                    if lv == 0 {
                        g.textC("LOT", bx + 20, by + 7, TycoonPal.white, 1)
                    } else {
                        for l in 0..<lv { g.rect(bx + 4 + l * 7, by + 7, 5, 6, TycoonPal.white) }
                    }
                }
            }
        }
        for k in 0..<4 {
            let r = TycoonUI.ovStation(k)
            let tile = stationTile(k)
            let o = tOwner[tile]
            var c: UInt32 = TycoonPal.greyDark
            if o >= 0 && o < players.count { c = TycoonBoard.tokenCols[players[o].token % 4] }
            if hot(r) { c = TycoonGfx.mix(c, TycoonPal.white, 0.3) }
            g.rrect(r.0, r.1, r.2, r.3, 5, c)
            if ovSel == 8 + k { g.frame(r.0, r.1, r.2, r.3, 2, TycoonPal.gold) }
            let names: [String] = ["BUS", "FERRY", "TRAIN", "CABLE"]
            g.textC(names[k], r.0 + r.2 / 2, r.1 + 10, TycoonPal.white, 2)
        }
        let d = overviewDetail()
        g.textCS(d.0, 160, 258, TycoonPal.goldLight, 2, TycoonPal.ink)
        g.textC(d.1, 160, 274, TycoonPal.white, 1)
        g.textC("TAP OUTSIDE OR PRESS UP TO CLOSE", 160, 281, TycoonPal.grey, 1)
    }

    // MARK: - How to play

    func drawHow(_ g: TycoonGfx) {
        g.rectA(0, 0, 320, 288, TycoonPal.h(0x141C48), 150)
        g.rrect(12, 20, 296, 220, 10, TycoonPal.ink)
        g.rrect(14, 22, 292, 216, 9, TycoonPal.cream)
        let titles: [String] = ["ROLL AND HOP", "BUY AND BUILD", "HOW TO WIN"]
        let pg = max(0, min(2, howPage))
        g.rrect(14, 22, 292, 30, 9, TycoonPal.h(0xFF8A1C))
        g.rect(14, 38, 292, 14, TycoonPal.h(0xFF8A1C))
        g.textCO(titles[pg], 160, 30, TycoonPal.white, 3, TycoonPal.ink)
        var lines: [String] = []
        switch pg {
        case 0:
            lines = ["TAP ROLL TO THROW THE DICE", "HOP ALONG THE TOWN LOOP", "DOUBLES? ROLL AGAIN!", "THREE DOUBLES = TIME-OUT", "PASS START FOR 200 COINS"]
        case 1:
            lines = ["LAND ON A STREET TO BUY IT", "BUILD COTTAGES, HOUSES,", "SHOPS AND TOWERS FOR RENT", "OWN A WHOLE DISTRICT FOR", "A GLOWING LANDMARK!"]
        default:
            lines = ["AFTER 30 ROUNDS THE RICHEST", "PLAYER WINS THE TOWN!", "A OR TAP = OK, B = SKIP", "LEFT/RIGHT = CHOOSE", "UP = TOWN MAP, DOWN = ZOOM"]
        }
        for (k, s) in lines.enumerated() {
            g.textC(s, 160, 66 + k * 24, TycoonPal.ink, 2)
        }
        for k in 0..<3 {
            g.disc(Float(148 + k * 12), 226, 3, k == pg ? TycoonPal.h(0xFF8A1C) : TycoonPal.grey)
        }
        drawButton(g, TycoonUI.howSkip, "SKIP", "B", TycoonPal.h(0x8A94C8), false, 0)
        drawButton(g, TycoonUI.howNext, pg >= 2 ? "PLAY!" : "NEXT", "A", TycoonPal.h(0x2FC76A), true, 0)
    }

    // MARK: - Title

    func drawTitle(_ g: TycoonGfx) {
        let cols: [UInt32] = [TycoonPal.red, TycoonPal.h(0xFF9A2E), TycoonPal.gold, TycoonPal.green, TycoonPal.blue, TycoonPal.pink]
        let w1 = "TYCOON"
        for (k, ch) in w1.enumerated() {
            let x = 160 - 115 / 2 + k * 20
            let y = 12 + tycI(sin(Float(frame) * 0.08 + Float(k) * 0.7) * 3)
            g.textO(String(ch), x, y, cols[k % 6], 5, TycoonPal.ink)
        }
        let w2 = "TOWN"
        for (k, ch) in w2.enumerated() {
            let x = 160 - 75 / 2 + k * 20
            let y = 44 + tycI(sin(Float(frame) * 0.08 + Float(k) * 0.7 + 2) * 3)
            g.textO(String(ch), x, y, cols[(k + 2) % 6], 5, TycoonPal.ink)
        }
        g.textCO("ROLL  BUY  BUILD  WIN", 160, 80, TycoonPal.white, 2, TycoonPal.ink)
        g.rectA(0, 126, 320, 162, TycoonPal.h(0x141C48), 215)
        g.rect(0, 126, 320, 2, TycoonPal.gold)
        let labels: [String] = ["PLAYERS", "TOKEN", "HAT", "SKIN"]
        var vals: [String] = []
        vals.append(String(selCount) + " PLAYERS")
        vals.append(TycoonBoard.tokenLabels[max(0, min(3, sv.token))])
        vals.append(TycoonBoard.hatNames[max(0, min(6, sv.hat))])
        vals.append(TycoonBoard.skinNames[max(0, min(2, sv.skin))])
        for i in 0..<4 {
            let r = TycoonUI.titleRow(i)
            if titleRow == i {
                g.rectA(r.0 + 4, r.1 + 1, 258, r.3 - 2, TycoonPal.gold, 55)
                g.frame(r.0 + 4, r.1 + 1, 258, r.3 - 2, 1, TycoonPal.gold)
            }
            if hot(r) { g.rectA(r.0 + 4, r.1 + 1, 258, r.3 - 2, TycoonPal.white, 50) }
            g.textS(labels[i], 12, r.1 + 9, TycoonPal.white, 2, TycoonPal.ink)
            g.textS("<", 94, r.1 + 9, TycoonPal.goldLight, 2, TycoonPal.ink)
            g.textS(">", 254, r.1 + 9, TycoonPal.goldLight, 2, TycoonPal.ink)
            g.textC(vals[i], 174, r.1 + 9, TycoonPal.goldLight, 2)
        }
        // token preview
        g.ellipseA(296, 220, 24, 10, TycoonPal.gold, 70)
        let bob: Float = abs(sin(Float(frame) * 0.1)) * 4
        drawToken(g, sv.token, sv.hat, sv.skin, 296, 216 - bob, 1.1, 1, 1)
        // footer
        let st = "WINS " + String(winTotal()) + "  BEST " + String(sv.best) + "  HATS " + String(min(6, sv.unlocked)) + "/6"
        g.textC(st, 160, 241, TycoonPal.grey, 1)
        drawButton(g, TycoonUI.playBtn, "PLAY!", "A", TycoonPal.h(0x2FC76A), true, 0)
        drawButton(g, TycoonUI.howBtn, "HOW TO", "B", TycoonPal.h(0x6A80E8), false, 0)
        if titleT > 420 {
            g.textC("STARTING IN " + String(max(0, (600 - titleT) / 60 + 1)), 160, 288 - 5, TycoonPal.goldLight, 1)
        }
    }

    func winTotal() -> Int {
        var n = 0
        for x in sv.wins { n += x }
        return n
    }

    // MARK: - Results

    func drawTrophy(_ g: TycoonGfx, _ cx: Float, _ cy: Float, _ s: Float) {
        g.rrect(tycI(cx - 8 * s), tycI(cy - 4 * s), max(2, tycI(16 * s)), max(1, tycI(4 * s)), 2, TycoonPal.goldDark)
        g.rect(tycI(cx - 2 * s), tycI(cy - 10 * s), max(1, tycI(4 * s)), max(1, tycI(6 * s)), TycoonPal.gold)
        g.ellipse(cx - 11 * s, cy - 21 * s, 4 * s, 5 * s, TycoonPal.goldDark)
        g.ellipse(cx + 11 * s, cy - 21 * s, 4 * s, 5 * s, TycoonPal.goldDark)
        g.quad(cx - 9 * s, cy - 29 * s, cx + 9 * s, cy - 29 * s, cx + 5 * s, cy - 10 * s, cx - 5 * s, cy - 10 * s, TycoonPal.gold)
        g.quad(cx - 7 * s, cy - 27 * s, cx - 4 * s, cy - 27 * s, cx - 2 * s, cy - 12 * s, cx - 4 * s, cy - 12 * s, TycoonPal.goldLight)
        g.disc(cx + 1 * s, cy - 20 * s, 2.6 * s, TycoonPal.white)
    }

    func drawResults(_ g: TycoonGfx) {
        g.rectA(0, 0, 320, 288, TycoonPal.h(0x141C48), 140)
        let head = humanWon ? "YOU WON!" : (ranks.isEmpty ? "GAME OVER" : who(ranks[0]) + " WINS!")
        let bob: Int = tycI(sin(Float(resT) * 0.1) * 2)
        g.textCO(head, 160, 10 + bob, TycoonPal.gold, 3, TycoonPal.ink)
        let n = ranks.count
        if n == 0 { return }
        let colW = 72
        let x0 = 160 - n * colW / 2
        let heights: [Int] = [76, 58, 44, 32]
        let colors: [UInt32] = [TycoonPal.gold, TycoonPal.h(0xC8D0E0), TycoonPal.h(0xD08850), TycoonPal.greyDark]
        let slots: [Int] = [1, 0, 2, 3]
        var pos = 0
        for place in slots where place < n {
            let pi = ranks[place]
            let cx = x0 + pos * colW + colW / 2
            pos += 1
            let hh = heights[place]
            let base = 190
            let c = colors[place]
            g.rrect(cx - 31, base - hh, 62, hh, 5, TycoonGfx.mul(c, 0.7))
            g.rrect(cx - 31, base - hh, 62, hh - 3, 5, c)
            g.rect(cx - 28, base - hh + 2, 10, 2, TycoonPal.white)
            g.textCO(String(place + 1), cx, base - hh + 10, TycoonPal.white, 3, TycoonGfx.mul(c, 0.4))
            let pl = players[pi]
            var jump: Float = 0
            if place == 0 { jump = abs(sin(Float(resT) * 0.12)) * 8 }
            let tb = Float(base - hh) - jump
            g.ellipseA(Float(cx), Float(base - hh), 14, 5, TycoonPal.h(0x202850), 70)
            drawToken(g, pl.token, pl.hat, pl.skin, Float(cx), tb, 1.15, 1, 1)
            if place == 0 { drawTrophy(g, Float(cx + 26), Float(base - hh), 0.9) }
            let wv = wealthList[pi]
            if pl.bankrupt {
                g.textCS("OUT", cx, base + 8, TycoonPal.grey, 2, TycoonPal.ink)
            } else {
                let mw = g.moneyWidth(wv, 2)
                g.money(cx - mw / 2, base + 6, wv, 2, TycoonPal.goldLight, TycoonPal.ink)
            }
            g.textC(pi == 0 ? "YOU" : TycoonBoard.tokenNames[pl.token % 4], cx, base + 24, TycoonPal.white, 1)
        }
        if !unlockText.isEmpty {
            g.textCO(unlockText, 160, 226, TycoonPal.goldLight, 2, TycoonPal.ink)
        } else {
            g.textC("ROUNDS PLAYED " + String(min(round, TycoonBoard.maxRounds)), 160, 228, TycoonPal.grey, 1)
        }
        if resT > 40 {
            let r = (80, 248, 160, 34)
            drawButton(g, r, "PLAY AGAIN", "A", TycoonPal.h(0x2FC76A), true, 0)
        }
    }
}
