#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

// The burlap buddy, its hats and scarves, speech bubbles and the animated toy props.

extension BuddyBounce64 {
    func scarfColor(_ idx: Int, _ part: Int) -> UInt32 {
        if idx == 6 {
            let cols: [UInt32] = [brgb(235, 70, 70), brgb(250, 200, 60), brgb(80, 190, 110), brgb(80, 140, 235), brgb(160, 100, 210)]
            return cols[part % 5]
        }
        let i: Int = max(0, min(BuddyData.scarfColors.count - 1, idx))
        return bhx(BuddyData.scarfColors[i])
    }

    func drawBuddyShadow(_ c: BuddyCanvas) {
        let h: Float = buddyClampF((floorY - (cy + 30)) / 160, 0, 1)
        let rx: Float = 30 * (1 - h * 0.5)
        let a: Int = Int(90 * (1 - h * 0.8))
        c.ellipse(cx, floorY + 3, rx, 5.5, brgb(40, 20, 8), a)
        c.ellipse(cx, floorY + 3, rx * 0.65, 3.5, brgb(40, 20, 8), a / 2)
    }

    func rotPt(_ ax: Float, _ ay: Float, _ ca: Float, _ sa: Float, _ lx: Float, _ ly: Float) -> (Float, Float) {
        return (ax + lx * ca - ly * sa, ay + lx * sa + ly * ca)
    }

    func drawBuddy(_ cIn: BuddyCanvas) {
        if pts.count < 15 { return }
        var c: BuddyCanvas = cIn
        c.weave = true
        let p: [BuddyPt] = pts
        var skin: UInt32 = brgb(210, 170, 110)
        var skinD: UInt32 = brgb(160, 120, 72)
        var skinL: UInt32 = brgb(232, 198, 138)
        if wetT > 0 {
            let k: Float = min(0.4, Float(wetT) / 240)
            let wetCol: UInt32 = brgb(120, 160, 215)
            skin = BuddyCol.mix(skin, wetCol, k)
            skinD = BuddyCol.mix(skinD, wetCol, k)
            skinL = BuddyCol.mix(skinL, wetCol, k)
        }
        let seam: UInt32 = brgb(104, 70, 38)
        let rope: UInt32 = brgb(156, 116, 66)
        let ropeD: UInt32 = brgb(108, 74, 40)
        let boot: UInt32 = brgb(110, 70, 42)
        let bootL: UInt32 = brgb(150, 100, 62)

        // torso axis
        let topX: Float = (p[2].x + p[3].x) * 0.5
        let topY: Float = (p[2].y + p[3].y) * 0.5
        let botX: Float = (p[5].x + p[6].x) * 0.5
        let botY: Float = (p[5].y + p[6].y) * 0.5
        var ax: Float = botX - topX
        var ay: Float = botY - topY
        let al: Float = max(0.001, sqrt(ax * ax + ay * ay))
        ax /= al
        ay /= al
        let perX: Float = -ay
        let perY: Float = ax

        // rocket pack behind the buddy
        if rocketT > 0 {
            let rx0: Float = topX + perX * 9 - ax * 6
            let ry0: Float = topY + perY * 9 - ay * 6
            let rx1: Float = botX + perX * 9 + ax * 4
            let ry1: Float = botY + perY * 9 + ay * 4
            c.capsule(rx0, ry0, rx1, ry1, 5.2, brgb(230, 70, 70))
            c.capsule(rx0, ry0, rx1, ry1, 3.2, brgb(255, 120, 110))
            c.disc(rx0 - ax * 4, ry0 - ay * 4, 4, brgb(255, 240, 230))
            c.disc(rx1 + ax * 3, ry1 + ay * 3, 3, brgb(255, 190, 60))
        }

        func seg(_ i: Int, _ j: Int, _ r: Float) {
            c.capsule(p[i].x, p[i].y, p[j].x, p[j].y, r + 1.1, skinD)
            c.capsule(p[i].x, p[i].y, p[j].x, p[j].y, r, skin)
            c.stitch(p[i].x, p[i].y, p[j].x, p[j].y, seam, 4)
        }

        func hand(_ e: Int, _ h: Int) {
            c.disc(p[h].x, p[h].y, 6.4, skinD)
            c.disc(p[h].x, p[h].y, 5.3, skin)
            c.disc(p[h].x - 1.5, p[h].y - 1.6, 1.8, skinL, 150)
            var dx: Float = p[h].x - p[e].x
            var dy: Float = p[h].y - p[e].y
            let l: Float = max(0.001, sqrt(dx * dx + dy * dy))
            dx /= l
            dy /= l
            let wx: Float = p[e].x + (p[h].x - p[e].x) * 0.72
            let wy: Float = p[e].y + (p[h].y - p[e].y) * 0.72
            c.capsule(wx - dy * 5, wy + dx * 5, wx + dy * 5, wy - dx * 5, 1.7, rope)
            c.capsule(wx - dy * 4.5, wy + dx * 4.5, wx + dy * 4.5, wy - dx * 4.5, 0.5, ropeD)
        }

        func foot(_ k: Int, _ f: Int) {
            var dx: Float = p[k].x - p[f].x
            var dy: Float = p[k].y - p[f].y
            let l: Float = max(0.001, sqrt(dx * dx + dy * dy))
            dx /= l
            dy /= l
            c.capsule(p[f].x, p[f].y, p[f].x + dx * 5, p[f].y + dy * 5, 7, boot)
            c.disc(p[f].x - dy * 1.5, p[f].y + dx * 1.5, 2.4, bootL, 170)
            c.capsule(p[f].x + dx * 4 - dy * 6, p[f].y + dy * 4 + dx * 6, p[f].x + dx * 4 + dy * 6, p[f].y + dy * 4 - dx * 6, 1.4, ropeD)
        }

        // back limbs (character's right)
        seg(3, 9, 4.8)
        seg(9, 10, 4.5)
        hand(9, 10)
        seg(6, 13, 5.6)
        seg(13, 14, 5.2)
        foot(13, 14)
        c.disc(p[9].x, p[9].y, 4.0, brgb(214, 90, 84))
        c.stitchRing(p[9].x, p[9].y, 3.2, brgb(255, 230, 200), 10)

        // torso
        let tr: Float = 10.8 * (1 - bodySq * 0.5)
        c.capsule(topX, topY, botX, botY, tr + 1.2, skinD)
        c.capsule(p[2].x, p[2].y, p[3].x, p[3].y, 6.6, skinD)
        c.capsule(topX, topY, botX, botY, tr, skin)
        c.capsule(p[2].x, p[2].y, p[3].x, p[3].y, 5.4, skin)
        c.capsule(topX - perX * 4.5, topY - perY * 4.5, botX - perX * 4.5, botY - perY * 4.5, 2.4, skinL, 90)
        c.stitch(topX + perX * 9.5, topY + perY * 9.5, botX + perX * 8.5, botY + perY * 8.5, seam, 4)
        // star patch shirt
        let pcx: Float = topX + (botX - topX) * 0.42
        let pcy: Float = topY + (botY - topY) * 0.42
        c.disc(pcx, pcy, 8.4, brgb(52, 120, 140))
        c.disc(pcx, pcy, 7.4, brgb(76, 164, 186))
        c.star(pcx, pcy, 6.2, 2.7, 5, atan2(ay, ax) + Float.pi, brgb(255, 214, 70))
        c.stitchRing(pcx, pcy, 8.6, brgb(255, 240, 210), 20)
        // rope belt
        let bx: Float = topX + (botX - topX) * 0.8
        let by: Float = topY + (botY - topY) * 0.8
        c.capsule(bx - perX * 10.5, by - perY * 10.5, bx + perX * 10.5, by + perY * 10.5, 2.1, rope)
        c.capsule(bx - perX * 10, by - perY * 10, bx + perX * 10, by + perY * 10, 0.6, ropeD)
        c.disc(bx + perX * 2, by + perY * 2, 2.8, ropeD)
        c.capsule(bx + perX * 2, by + perY * 2, bx + perX * 4 + ax * 6, by + perY * 4 + ay * 6, 1.3, rope)
        c.capsule(bx + perX * 2, by + perY * 2, bx - perX * 1 + ax * 7, by - perY * 1 + ay * 7, 1.3, rope)

        // front limbs (character's left)
        seg(5, 11, 5.6)
        seg(11, 12, 5.2)
        foot(11, 12)
        c.disc(p[11].x, p[11].y, 4.2, brgb(88, 140, 214))
        c.stitchRing(p[11].x, p[11].y, 3.4, brgb(255, 240, 210), 10)
        c.stitch(p[11].x - 3, p[11].y, p[11].x + 3, p[11].y, brgb(255, 240, 210), 2)
        seg(2, 7, 4.8)
        seg(7, 8, 4.5)
        hand(7, 8)

        // neck rope and scarf
        var hnx: Float = p[0].x - p[1].x
        var hny: Float = p[0].y - p[1].y
        let hl: Float = max(0.001, sqrt(hnx * hnx + hny * hny))
        hnx /= hl
        hny /= hl
        let pnx: Float = -hny
        let pny: Float = hnx
        let nkx: Float = p[1].x + hnx * 2
        let nky: Float = p[1].y + hny * 2
        c.capsule(nkx - pnx * 7.5, nky - pny * 7.5, nkx + pnx * 7.5, nky + pny * 7.5, 2.2, rope)
        c.capsule(nkx - pnx * 7, nky - pny * 7, nkx + pnx * 7, nky + pny * 7, 0.6, ropeD)
        var cloth: BuddyCanvas = cIn
        cloth.weave = false
        let sx0: Float = nkx - hnx * 1.5
        let sy0: Float = nky - hny * 1.5
        let parts: Int = (selScarf == 6) ? 5 : 1
        var sp: Int = 0
        while sp < parts {
            let u0: Float = Float(sp) / Float(parts)
            let u1: Float = Float(sp + 1) / Float(parts)
            let c0: UInt32 = scarfColor(selScarf, sp)
            let ax0: Float = sx0 + pnx * (-9 + 18 * u0)
            let ay0: Float = sy0 + pny * (-9 + 18 * u0)
            let ax1: Float = sx0 + pnx * (-9 + 18 * u1)
            let ay1: Float = sy0 + pny * (-9 + 18 * u1)
            cloth.capsule(ax0, ay0, ax1, ay1, 3.8, c0)
            sp += 1
        }
        cloth.stitch(sx0 - pnx * 8, sy0 - pny * 8, sx0 + pnx * 8, sy0 + pny * 8, brgb(255, 255, 255), 3)
        // scarf tails flutter against the motion
        let knotX: Float = sx0 + pnx * 7 + hnx * -2
        let knotY: Float = sy0 + pny * 7 + hny * -2
        var tvx: Float = -cvx * 2.2 + sin(Float(frameN) * 0.2) * 1.5
        var tvy: Float = 10 - cvy * 1.6
        let tl: Float = sqrt(tvx * tvx + tvy * tvy)
        if tl > 15 {
            tvx = tvx / tl * 15
            tvy = tvy / tl * 15
        }
        cloth.capsule(knotX, knotY, knotX + tvx, knotY + tvy, 2.7, scarfColor(selScarf, 1))
        cloth.capsule(knotX, knotY, knotX + tvx * 0.8 + 3, knotY + tvy * 0.9, 2.5, scarfColor(selScarf, 3))

        drawHead(c, cloth, p, hnx, hny)
    }

    func drawHead(_ cIn: BuddyCanvas, _ cloth: BuddyCanvas, _ p: [BuddyPt], _ hnx: Float, _ hny: Float) {
        var c: BuddyCanvas = cIn
        c.weave = true
        let hx: Float = p[0].x
        let hy: Float = p[0].y
        let ha: Float = atan2(hnx, -hny)
        let ca: Float = cos(ha)
        let sa: Float = sin(ha)
        let skin: UInt32 = (wetT > 0) ? BuddyCol.mix(brgb(210, 170, 110), brgb(120, 160, 215), min(0.4, Float(wetT) / 240)) : brgb(210, 170, 110)
        let skinD: UInt32 = brgb(160, 120, 72)
        let skinL: UInt32 = brgb(236, 202, 142)
        let seam: UInt32 = brgb(104, 70, 38)
        let hr: Float = 12.2
        let rx: Float = hr * (1 + headSq)
        let ry: Float = hr * (1 - headSq)
        // gathered sack top
        let t0 = rotPt(hx, hy, ca, sa, 0, -ry + 2)
        let t1 = rotPt(hx, hy, ca, sa, -4.5, -ry - 4)
        let t2 = rotPt(hx, hy, ca, sa, 4, -ry - 5)
        c.capsule(t0.0, t0.1, t1.0, t1.1, 3.0, skinD)
        c.capsule(t0.0, t0.1, t2.0, t2.1, 3.0, skinD)
        c.capsule(t0.0, t0.1, t1.0, t1.1, 2.0, skin)
        c.capsule(t0.0, t0.1, t2.0, t2.1, 2.0, skin)
        c.ellipse(hx, hy, rx + 1.2, ry + 1.2, skinD)
        c.ellipse(hx, hy, rx, ry, skin)
        let hl = rotPt(hx, hy, ca, sa, -3.5, -5)
        c.ellipse(hl.0, hl.1, 6, 4, skinL, 110)
        c.stitchRing(hx, hy, hr * 0.86, seam, 30)
        // head patch
        let pp = rotPt(hx, hy, ca, sa, 7.2, -6.4)
        c.disc(pp.0, pp.1, 3.4, brgb(88, 140, 214))
        c.stitchRing(pp.0, pp.1, 2.7, brgb(255, 240, 210), 8)
        // whipped cream
        if creamT > 0 {
            let f: Float = min(1, Float(creamT) / 90)
            let cc: UInt32 = brgb(255, 249, 234)
            let cs: UInt32 = brgb(236, 214, 190)
            let spots: [[Float]] = [[0, 4, 8.6], [-6, 6, 5.6], [6, 6, 5.6], [0, -2, 4.6], [-3, 9, 4.2], [3.5, 9.5, 3.8]]
            for s in spots {
                let q = rotPt(hx, hy, ca, sa, s[0] * f, s[1] * f)
                c.disc(q.0, q.1 + 0.8, s[2] * f + 1, cs)
            }
            for s in spots {
                let q = rotPt(hx, hy, ca, sa, s[0] * f, s[1] * f)
                c.disc(q.0, q.1, s[2] * f, cc)
            }
            let d0 = rotPt(hx, hy, ca, sa, -4, 10)
            let d1 = rotPt(hx, hy, ca, sa, 4, 10)
            c.capsule(d0.0, d0.1, d0.0, d0.1 + 6 * f, 1.8 * f + 0.4, cc)
            c.capsule(d1.0, d1.1, d1.0, d1.1 + 4 * f, 1.8 * f + 0.4, cc)
        }
        // eyes
        let eyeY: Float = -1.8
        let e0 = rotPt(hx, hy, ca, sa, -4.7, eyeY)
        let e1 = rotPt(hx, hy, ca, sa, 4.7, eyeY)
        let dark: UInt32 = brgb(34, 28, 36)
        switch expr {
        case 2:
            c.disc(e0.0, e0.1, 4.0, brgb(255, 252, 240))
            c.disc(e1.0, e1.1, 4.0, brgb(255, 252, 240))
            let eyes: [(Float, Float)] = [e0, e1]
            for e in eyes {
                var j: Int = 0
                while j < 9 {
                    let ang: Float = Float(j) * 0.95 + Float(frameN) * 0.3
                    let rad: Float = Float(j) * 0.4
                    c.disc(e.0 + cos(ang) * rad, e.1 + sin(ang) * rad, 0.8, dark)
                    j += 1
                }
            }
        case 4:
            let eyes: [(Float, Float)] = [e0, e1]
            for e in eyes {
                c.capsule(e.0 - 2.8, e.1 - 0.4, e.0, e.1 + 1.2, 0.9, dark)
                c.capsule(e.0, e.1 + 1.2, e.0 + 2.8, e.1 - 0.4, 0.9, dark)
            }
        default:
            let er: Float = (expr == 3) ? 3.3 : 2.8
            c.disc(e0.0, e0.1, er, dark)
            c.disc(e1.0, e1.1, er, dark)
            c.disc(e0.0 - 0.9, e0.1 - 1.0, 0.95, brgb(255, 255, 255))
            c.disc(e1.0 - 0.9, e1.1 - 1.0, 0.95, brgb(255, 255, 255))
            c.disc(e0.0 + 1, e0.1 + 0.9, 0.5, brgb(255, 255, 255), 150)
            c.disc(e1.0 + 1, e1.1 + 0.9, 0.5, brgb(255, 255, 255), 150)
        }
        // cheeks
        if expr != 2 {
            let k0 = rotPt(hx, hy, ca, sa, -7.8, 3.2)
            let k1 = rotPt(hx, hy, ca, sa, 7.8, 3.2)
            c.disc(k0.0, k0.1, 2.6, brgb(255, 130, 140), 90)
            c.disc(k1.0, k1.1, 2.6, brgb(255, 130, 140), 90)
        }
        // mouth
        if creamT <= 0 || creamT < 40 {
            switch expr {
            case 1, 2:
                let m = rotPt(hx, hy, ca, sa, 0, 4.6)
                let big: Float = (expr == 1) ? 1 : 0.7
                c.ellipse(m.0, m.1, 4.8 * big, 3.5 * big, brgb(112, 40, 52))
                let tg = rotPt(hx, hy, ca, sa, 0, 5.8)
                c.ellipse(tg.0, tg.1, 2.6 * big, 1.5 * big, brgb(240, 120, 132))
            case 3:
                let m = rotPt(hx, hy, ca, sa, 0, 5.2)
                c.disc(m.0, m.1, 2.5, brgb(112, 40, 52))
                c.disc(m.0, m.1 + 0.6, 1.2, brgb(240, 120, 132))
            default:
                var j: Int = 0
                let small: Float = (expr == 4) ? 0.7 : 1
                while j < 7 {
                    let u: Float = Float(j) / 6
                    let ang: Float = 0.2 * Float.pi + u * 0.6 * Float.pi
                    let q = rotPt(hx, hy, ca, sa, cos(ang) * 5.4 * small, 2.2 + sin(ang) * 3.4 * small)
                    c.disc(q.0, q.1, 0.8, seam)
                    j += 1
                }
                let l0 = rotPt(hx, hy, ca, sa, -5.6 * small, 3.0)
                let l1 = rotPt(hx, hy, ca, sa, 5.6 * small, 3.0)
                c.capsule(l0.0, l0.1 - 1.2, l0.0, l0.1 + 1.0, 0.5, seam)
                c.capsule(l1.0, l1.1 - 1.2, l1.0, l1.1 + 1.0, 0.5, seam)
            }
        }
        // dizzy stars
        if dizzyT > 0 {
            var k: Int = 0
            while k < 3 {
                let ang: Float = Float(frameN) * 0.14 + Float(k) * 2.094
                cloth.star(hx + cos(ang) * 17, hy - 15 + sin(ang) * 5, 4.2, 1.9, 5, Float(frameN) * 0.1, brgb(255, 226, 80))
                k += 1
            }
        }
        // hat
        let anc = rotPt(hx, hy, ca, sa, 0, -ry + 1.5)
        drawHat(cloth, selHat, anc.0, anc.1, ha)
    }

    func drawHat(_ c: BuddyCanvas, _ hat: Int, _ ax: Float, _ ay: Float, _ ha: Float) {
        let ca: Float = cos(ha)
        let sa: Float = sin(ha)
        func W(_ lx: Float, _ ly: Float) -> (Float, Float) {
            return (ax + lx * ca - ly * sa, ay + lx * sa + ly * ca)
        }
        let stitchC: UInt32 = brgb(255, 245, 225)
        switch hat {
        case 1:
            let a = W(-9, 1)
            let b = W(9, 1)
            let t = W(0, -26)
            c.tri(a.0, a.1, b.0, b.1, t.0, t.1, brgb(255, 110, 170))
            let q1 = W(-5.4, -9)
            let q2 = W(5.4, -9)
            let q3 = W(3.2, -15)
            let q4 = W(-3.2, -15)
            c.poly([q1.0, q2.0, q3.0, q4.0], [q1.1, q2.1, q3.1, q4.1], brgb(255, 236, 120))
            c.disc(t.0, t.1, 3.3, brgb(255, 230, 90))
            c.stitch(a.0, a.1, b.0, b.1, stitchC, 3)
        case 2:
            let m1 = W(0, -9)
            let m2 = W(0, -3)
            let m3 = W(0, 0.5)
            c.rotRect(m1.0, m1.1, 8, 8, ha, brgb(56, 48, 78))
            c.rotRect(m2.0, m2.1, 8.2, 1.9, ha, brgb(220, 60, 70))
            c.rotRect(m3.0, m3.1, 13.5, 2.2, ha, brgb(44, 38, 64))
        case 3:
            let m = W(0, -3)
            c.ellipse(m.0, m.1, 10.8, 8.2, brgb(64, 176, 196))
            let b = W(0, 0)
            c.rotRect(b.0, b.1, 11.4, 2.7, ha, brgb(250, 240, 220))
            let pm = W(0, -11.5)
            c.disc(pm.0, pm.1, 3.2, brgb(255, 255, 255))
            c.stitch(W(-9, -4).0, W(-9, -4).1, W(9, -4).0, W(9, -4).1, stitchC, 3)
        case 4:
            let a = W(-9, 0.5)
            let b = W(-9, -9)
            let d = W(-4.5, -4.5)
            let e = W(0, -11.5)
            let f = W(4.5, -4.5)
            let g = W(9, -9)
            let h = W(9, 0.5)
            c.poly([a.0, b.0, d.0, e.0, f.0, g.0, h.0], [a.1, b.1, d.1, e.1, f.1, g.1, h.1], brgb(255, 206, 50))
            let band = W(0, -1)
            c.rotRect(band.0, band.1, 9, 1.3, ha, brgb(255, 240, 160))
            let gem = W(0, -4.5)
            c.disc(gem.0, gem.1, 2, brgb(235, 60, 90))
        case 5:
            let m = W(0, -2)
            c.ellipse(m.0, m.1, 9.4, 6.2, brgb(230, 70, 70))
            let s0 = W(0, -7)
            let s1 = W(0, -10.5)
            c.capsule(s0.0, s0.1, s1.0, s1.1, 1.1, brgb(90, 90, 110))
            let spin: Float = cos(Float(frameN) * 0.5)
            let b0 = W(-spin * 12, -10.5)
            let b1 = W(spin * 12, -10.5)
            c.capsule(b0.0, b0.1, b1.0, b1.1, 1.7, brgb(250, 210, 60))
            c.disc(s1.0, s1.1, 1.9, brgb(70, 140, 235))
        case 6:
            let b = W(0, -2)
            c.rotRect(b.0, b.1, 8.8, 3.6, ha, brgb(255, 255, 255))
            let p1 = W(-5.2, -9)
            let p2 = W(5.2, -9)
            let p3 = W(0, -13)
            c.disc(p1.0, p1.1, 5.6, brgb(238, 238, 244))
            c.disc(p2.0, p2.1, 5.6, brgb(238, 238, 244))
            c.disc(p3.0, p3.1, 6.2, brgb(250, 250, 255))
            c.stitch(W(-8, -2).0, W(-8, -2).1, W(8, -2).0, W(8, -2).1, brgb(200, 200, 215), 3)
        case 7:
            let sway: Float = sin(Float(frameN) * 0.1) * 2
            let l0 = W(-4, -2)
            let l1 = W(-7 + sway, -19)
            let r0 = W(4, -2)
            let r1 = W(7 + sway, -19)
            c.capsule(l0.0, l0.1, l1.0, l1.1, 3.4, brgb(250, 248, 250))
            c.capsule(l0.0, l0.1, l1.0, l1.1, 1.6, brgb(255, 170, 190))
            c.capsule(r0.0, r0.1, r1.0, r1.1, 3.4, brgb(250, 248, 250))
            c.capsule(r0.0, r0.1, r1.0, r1.1, 1.6, brgb(255, 170, 190))
        case 8:
            let m = W(0, -9)
            var k: Int = 0
            while k < 5 {
                let ang: Float = Float(k) * 1.2566 - 1.57
                let q = W(cos(ang) * 4.8, -9 + sin(ang) * 4.8)
                c.disc(q.0, q.1, 3.7, brgb(255, 140, 190))
                k += 1
            }
            c.disc(m.0, m.1, 3.1, brgb(255, 214, 70))
            let lf = W(-6, -2.5)
            c.ellipse(lf.0, lf.1, 4, 2, brgb(90, 180, 90))
        case 9:
            let a0 = W(-10, -1)
            let a1 = W(-3, -3)
            let a2 = W(-9, -12)
            c.tri(a0.0, a0.1, a1.0, a1.1, a2.0, a2.1, brgb(240, 150, 60))
            let i0 = W(-8.2, -3)
            let i1 = W(-4.5, -4)
            let i2 = W(-8.4, -8.5)
            c.tri(i0.0, i0.1, i1.0, i1.1, i2.0, i2.1, brgb(255, 180, 190))
            let b0 = W(10, -1)
            let b1 = W(3, -3)
            let b2 = W(9, -12)
            c.tri(b0.0, b0.1, b1.0, b1.1, b2.0, b2.1, brgb(240, 150, 60))
            let j0 = W(8.2, -3)
            let j1 = W(4.5, -4)
            let j2 = W(8.4, -8.5)
            c.tri(j0.0, j0.1, j1.0, j1.1, j2.0, j2.1, brgb(255, 180, 190))
        default:
            break
        }
    }

    // MARK: Speech bubble

    func drawBubble(_ c: BuddyCanvas) {
        if bubbleT <= 0 || bubble.isEmpty || pts.count < 15 { return }
        let tw: Int = textW(bubble, 2)
        let bw: Float = Float(tw + 14)
        let bh: Float = 20
        let hx: Float = pts[0].x
        let hy: Float = pts[0].y
        var x: Float = hx - bw * 0.5
        x = buddyClampF(x, 4, 316 - bw)
        var y: Float = hy - 48
        var below: Bool = false
        if y < 32 {
            y = hy + 24
            below = true
        }
        y = buddyClampF(y, 30, 200)
        let pop: Float = min(1, Float(90 - bubbleT) / 8 + 0.4)
        _ = pop
        c.roundRect(x - 1.5, y - 1.5, bw + 3, bh + 3, 9, brgb(80, 50, 110), brgb(80, 50, 110), 230)
        c.roundRect(x, y, bw, bh, 8, brgb(255, 255, 255), brgb(244, 238, 255))
        let tx: Float = buddyClampF(hx, x + 12, x + bw - 12)
        if below {
            c.tri(tx - 5, y + 1, tx + 5, y + 1, hx, y - 8, brgb(255, 255, 255))
        } else {
            c.tri(tx - 5, y + bh - 1, tx + 5, y + bh - 1, hx, y + bh + 8, brgb(255, 255, 255))
        }
        qt(bubble, Int(x) + 7, Int(y) + 5, brgb(70, 40, 100), 2)
    }

    // MARK: Animated toys

    func drawAnims(_ c: BuddyCanvas) {
        for a in anims {
            switch a.kind {
            case 0: drawHammer(c, a)
            case 1: drawGlove(c, a)
            case 2: drawChicken(c, a)
            case 3, 4:
                if a.t <= a.hitT {
                    let u: Float = Float(a.t) / Float(max(1, a.hitT))
                    let x: Float = a.sx + (a.x - a.sx) * u
                    let y: Float = a.sy + (a.y - a.sy) * u - sin(u * Float.pi) * 50
                    drawToyIcon(c, a.kind == 3 ? 4 : 5, x, y, 0.8)
                }
            case 5: drawCannon(c, a)
            default: drawElephant(c, a)
            }
        }
    }

    func drawHammer(_ c: BuddyCanvas, _ a: BuddyAnim) {
        let tt: Float = Float(a.t)
        let down: Float = 0.3
        var ang: Float = down
        if a.t < a.hitT {
            let u: Float = tt / Float(max(1, a.hitT))
            ang = down - 1.5 * (1 - u * u)
        } else {
            let u: Float = min(1, (tt - Float(a.hitT)) / 9)
            ang = down - 1.5 * u * u
        }
        let len: Float = 64
        let pivX: Float = a.x - sin(down) * len
        let pivY: Float = a.y - cos(down) * len
        let hx: Float = pivX + sin(ang) * len
        let hy: Float = pivY + cos(ang) * len
        var hw: Float = 16
        var hh: Float = 11
        if a.t >= a.hitT && a.t < a.hitT + 4 {
            hw = 18.5
            hh = 8.8
        }
        c.capsule(pivX, pivY, hx, hy, 3.4, brgb(150, 100, 60))
        c.rotRect(hx, hy, hw, hh, -ang, brgb(255, 150, 60))
        c.rotRect(hx, hy, hw, 2.6, -ang, brgb(255, 220, 90))
        c.rotRect(hx, hy - 3, hw - 3, 1.6, -ang, brgb(255, 255, 255), 90)
    }

    func drawGlove(_ c: BuddyCanvas, _ a: BuddyAnim) {
        let xw: Float = a.dir < 0 ? wallL : wallR
        var ext: Float = 1
        if a.t < 6 {
            ext = Float(a.t) / 6
        } else if a.t > 12 {
            ext = max(0, 1 - Float(a.t - 12) / 8)
        }
        if ext < 0.02 { return }
        let gx: Float = xw + (a.x - xw) * ext
        let gy: Float = a.y
        let fx: Float = -a.dir
        var i: Int = 0
        let n: Int = 8
        while i < n {
            let u0: Float = Float(i) / Float(n)
            let u1: Float = Float(i + 1) / Float(n)
            let y0: Float = gy + ((i % 2 == 0) ? -6 : 6)
            let y1: Float = gy + ((i % 2 == 0) ? 6 : -6)
            c.capsule(xw + (gx - xw) * u0, y0, xw + (gx - xw) * u1, y1, 1.5, brgb(210, 214, 228))
            i += 1
        }
        c.capsule(gx - fx * 14, gy - 9, gx - fx * 14, gy + 9, 3.2, brgb(255, 255, 255))
        c.disc(gx, gy, 13.5, brgb(180, 40, 56))
        c.disc(gx, gy, 12.2, brgb(255, 80, 96))
        c.disc(gx + fx * 3, gy - 12, 6.2, brgb(255, 80, 96))
        c.disc(gx - 3 * fx, gy - 4, 4, brgb(255, 255, 255), 130)
        c.stitch(gx - fx * 6, gy - 8, gx - fx * 6, gy + 8, brgb(255, 220, 220), 3)
    }

    func drawChicken(_ c: BuddyCanvas, _ a: BuddyAnim) {
        let p: Float = buddyClampF(Float(a.t) / 16, 0, 1)
        let f: Float = a.dir
        let px0: Float = a.x + f * (-48 + 96 * p)
        let py0: Float = a.y - sin(p * Float.pi) * 18 - 6
        let sw: Float = sin(Float(a.t) * 0.6) * 3
        c.capsule(px0 - f * 3, py0 + 8, px0 - f * 3 + sw, py0 + 20, 1.7, brgb(255, 150, 50))
        c.capsule(px0 + f * 3, py0 + 8, px0 + f * 3 - sw, py0 + 20, 1.7, brgb(255, 150, 50))
        c.capsule(px0 - f * 12, py0, px0 - f * 23, py0 - 7, 3, brgb(255, 200, 50))
        c.ellipse(px0, py0, 14, 9.5, brgb(255, 222, 70))
        c.ellipse(px0 - f * 2, py0 + 2, 8, 5, brgb(240, 190, 30))
        c.capsule(px0 + f * 8, py0 - 2, px0 + f * 16, py0 - 12, 3.6, brgb(255, 222, 70))
        c.disc(px0 + f * 17, py0 - 14, 6.2, brgb(255, 226, 80))
        c.disc(px0 + f * 16, py0 - 21, 2.8, brgb(240, 60, 70))
        c.disc(px0 + f * 19.5, py0 - 20, 2.6, brgb(240, 60, 70))
        c.tri(px0 + f * 22, py0 - 16, px0 + f * 30, py0 - 13, px0 + f * 22, py0 - 11, brgb(255, 150, 50))
        c.disc(px0 + f * 19, py0 - 15.5, 1.5, brgb(30, 30, 40))
        c.disc(px0 + f * 18.6, py0 - 16, 0.5, brgb(255, 255, 255))
    }

    func drawCannon(_ c: BuddyCanvas, _ a: BuddyAnim) {
        let bx: Float = a.dir < 0 ? wallL + 10 : wallR - 10
        let by: Float = floorY - 16
        var dx: Float = a.x - bx
        var dy: Float = a.y - by
        let l: Float = max(1, sqrt(dx * dx + dy * dy))
        dx /= l
        dy /= l
        var recoil: Float = 0
        if a.t >= a.hitT { recoil = Float(max(0, 8 - (a.t - a.hitT))) * 0.8 }
        let r0x: Float = bx - dx * 8 - dx * recoil
        let r0y: Float = by - dy * 8 - dy * recoil
        let r1x: Float = bx + dx * (24 - recoil)
        let r1y: Float = by + dy * (24 - recoil)
        c.disc(bx, by + 6, 9, brgb(60, 50, 80))
        c.disc(bx, by + 6, 4, brgb(150, 140, 170))
        c.capsule(r0x, r0y, r1x, r1y, 9.5, brgb(90, 56, 160))
        c.capsule(r0x, r0y, r1x, r1y, 7.5, brgb(150, 106, 230))
        c.capsule(r0x + dx * 6, r0y + dy * 6, r0x + dx * 7, r0y + dy * 7, 9.8, brgb(255, 214, 80))
        c.ring(r1x, r1y, 8.5, 2.2, brgb(255, 220, 90))
        c.disc(r1x - dy * 3, r1y + dx * 3, 1.8, brgb(255, 255, 255), 150)
    }

    func drawElephant(_ c: BuddyCanvas, _ a: BuddyAnim) {
        let pose = elephantPose(a)
        let ex: Float = pose.0
        let raise: Float = pose.1
        let f: Float = a.dir
        let t: Float = Float(a.t)
        let walking: Bool = a.t < 70 || a.t > 118
        let bob: Float = walking ? sin(t * 0.45) * 1.5 : 0
        var sY: Float = 1
        if a.t >= 88 && a.t < 100 {
            sY = 1 - 0.1 * sin(Float(a.t - 88) / 12 * Float.pi)
        }
        let grey: UInt32 = brgb(160, 170, 188)
        let greyD: UInt32 = brgb(124, 134, 154)
        let greyL: UInt32 = brgb(190, 200, 216)
        let pink: UInt32 = brgb(246, 178, 198)
        c.ellipse(ex, floorY + 3, 40, 5, brgb(0, 0, 0), 60)
        let legX: [Float] = [-21, -9, 10, 22]
        var k: Int = 0
        while k < 4 {
            let lx: Float = ex + f * legX[k]
            let sw: Float = walking ? sin(t * 0.45 + Float(k) * 2.2) * 4 : 0
            let col: UInt32 = (k < 2) ? greyD : grey
            c.capsule(lx, floorY - 26 * sY, lx + sw, floorY - 4, 6.6, col)
            c.ellipse(lx + sw, floorY - 3, 7.8, 4.6, BuddyCol.shade(col, 1.05))
            c.disc(lx + sw - 3, floorY - 3, 1.5, brgb(250, 240, 236))
            c.disc(lx + sw + 3, floorY - 3, 1.5, brgb(250, 240, 236))
            k += 1
        }
        let bodyY: Float = floorY - 26 - 17 * sY + bob
        c.capsule(ex - f * 33, floorY - 42 + bob, ex - f * 41 + sin(t * 0.3) * 4, floorY - 27, 1.9, greyD)
        c.disc(ex - f * 41 + sin(t * 0.3) * 4, floorY - 25, 3.2, greyD)
        c.ellipse(ex, bodyY, 35 * (1 + (1 - sY) * 0.5), 23 * sY, grey)
        c.ellipse(ex, bodyY + 8 * sY, 28, 11 * sY, greyL, 150)
        let hx: Float = ex + f * 34
        let hy: Float = floorY - 54 + bob
        c.disc(hx, hy, 16.5, grey)
        c.disc(hx + f * 3, hy - 4, 5, greyL, 120)
        // trunk
        let b0x: Float = hx + f * 11
        let b0y: Float = hy + 6
        let hangX: Float = b0x + f * 6
        let hangY: Float = b0y + 26
        let tgtY: Float = max(34, a.y)
        let tipX: Float = hangX + (a.x - hangX) * raise
        let tipY: Float = hangY + (tgtY - hangY) * raise
        let ctrlX: Float = b0x + f * 14
        let ctrlY: Float = b0y + 10 - 40 * raise
        var prevX: Float = b0x
        var prevY: Float = b0y
        var i: Int = 1
        while i <= 6 {
            let u: Float = Float(i) / 6
            let qx: Float = (1 - u) * (1 - u) * b0x + 2 * u * (1 - u) * ctrlX + u * u * tipX
            let qy: Float = (1 - u) * (1 - u) * b0y + 2 * u * (1 - u) * ctrlY + u * u * tipY
            c.capsule(prevX, prevY, qx, qy, 6.6 - 3.4 * u, grey)
            prevX = qx
            prevY = qy
            i += 1
        }
        c.disc(tipX, tipY, 3.4, pink)
        // ear, eye, cheek
        c.disc(hx - f * 9, hy - 2, 13, greyD)
        c.disc(hx - f * 9, hy - 2, 9.4, pink)
        c.disc(hx + f * 6.5, hy - 4.5, 2.6, brgb(34, 28, 36))
        c.disc(hx + f * 5.8, hy - 5.3, 0.9, brgb(255, 255, 255))
        c.disc(hx + f * 4, hy + 4, 3.6, brgb(255, 150, 170), 130)
    }
}
