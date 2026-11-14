#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

// HUD, toy shelf, icons, menus, lucky spin, title screen and frame composition for BUDDY BOUNCE.

extension BuddyBounce64 {
    // MARK: Frame

    func renderFrame(_ b: TrueColorBuffer) {
        if b.width < 320 || b.height < 288 {
            b.clear(TrueColorBuffer.rgb(40, 40, 60))
            return
        }
        ensureBackground()
        texts.removeAll(keepingCapacity: true)
        b.withPixels { p, w, h in
            let c = BuddyCanvas(p: p, w: w, h: h)
            self.blitBackground(c)
            self.renderRoomDynamic(c)
            if self.phase == 0 {
                self.drawTitleScene(c)
            } else {
                self.drawScene(c)
            }
        }
        for t in texts {
            b.text(t.s, t.x, t.y, t.col, scale: t.scale)
        }
    }

    func drawScene(_ c: BuddyCanvas) {
        drawProps(c)
        drawPads(c)
        drawWheels(c)
        drawCoins(c)
        drawBuddyShadow(c)
        drawBuddy(c)
        drawPropsFront(c)
        drawBalls(c)
        drawAnims(c)
        drawSparks(c)
        drawBursts(c)
        drawBubble(c)
        drawTouchOverlays(c)
        drawHUD(c)
        drawBannerToast(c)
        if menu != 0 {
            drawMenu(c)
            drawSparks(c)
        }
        drawPhotoFx(c)
        if cursorOn {
            c.ring(curX, curY, 9, 2, brgb(255, 255, 255), 230)
            c.disc(curX, curY, 2.6, brgb(255, 220, 70))
            c.capsule(curX - 14, curY, curX - 10, curY, 1, brgb(255, 255, 255), 200)
            c.capsule(curX + 10, curY, curX + 14, curY, 1, brgb(255, 255, 255), 200)
        }
        drawFloats()
    }

    func drawTouchOverlays(_ c: BuddyCanvas) {
        if pdown && mode == 4 && grabIdx >= 0 && grabIdx < pts.count {
            c.capsule(px, py, pts[grabIdx].x, pts[grabIdx].y, 1.6, brgb(255, 255, 255), 110)
            c.ring(px, py, 11, 2, brgb(255, 255, 255), 190)
            c.disc(px, py, 4, brgb(255, 255, 255), 150)
        }
        if holdOn && pdown && mode == 6 {
            drawToyIcon(c, selToy, px, py - 4, 1.35)
        }
        if slingOn {
            let ax: Float = slingAx
            let ay: Float = slingAy
            c.capsule(ax, ay + 34, ax, ay + 10, 3, brgb(150, 100, 60))
            c.capsule(ax, ay + 10, ax - 15, ay - 12, 3, brgb(150, 100, 60))
            c.capsule(ax, ay + 10, ax + 15, ay - 12, 3, brgb(150, 100, 60))
            c.capsule(ax - 15, ay - 12, slingPx, slingPy, 1.5, brgb(255, 120, 170))
            c.capsule(ax + 15, ay - 12, slingPx, slingPy, 1.5, brgb(255, 120, 170))
            c.disc(slingPx, slingPy, 5, brgb(120, 80, 50))
            var lvx: Float = (ax - slingPx) * 0.17
            var lvy: Float = (ay - slingPy) * 0.17
            let m: Float = sqrt(lvx * lvx + lvy * lvy)
            if m >= 2.5 {
                if m > 15 {
                    lvx = lvx / m * 15
                    lvy = lvy / m * 15
                }
                let g: Float = BuddyData.roomGravity[selRoom]
                var n: Int = 1
                while n <= 9 {
                    let t: Float = Float(n) * 4
                    let x: Float = slingPx + lvx * t
                    let y: Float = slingPy + lvy * t + 0.5 * g * t * t
                    c.disc(x, y, 2.2, brgb(255, 255, 255), 200 - n * 14)
                    n += 1
                }
            }
        }
    }

    // MARK: Title

    func updateTitle(_ input: InputState) {
        titleT += 1
        poseTitleBuddy()
        if titleT % 14 == 0 {
            let c: UInt32 = BuddyData.confettiColors[rng.int(BuddyData.confettiColors.count)]
            spark(Float(rng.range(10, 310)), 20, Float(rng.range(-5, 5)) / 10, 0.6, 140, 1, c, 3, 0.02)
        }
        updateSparks()
        if titleT > 6 && (ppressed || input.aPressed || input.startPressed || input.bPressed) {
            startPlaying()
        }
    }

    func startPlaying() {
        phase = 1
        sparks = []
        floats = []
        mode = pdown ? 8 : 0
        menu = 0
        setupProps()
        resetBuddy()
        play(.confirm)
        if selRoom % 2 == 0 {
            playMusic(Tunes.arcade)
        } else {
            playMusic(Tunes.chill)
        }
        showBanner("LET'S PLAY!", 0xFFE066)
        shelfScroll = buddyClampF(Float(selToy) * 44 - 140, 0, maxShelfScroll())
    }

    func poseTitleBuddy() {
        let t: Float = Float(titleT) * 0.09
        let hop: Float = -abs(sin(t)) * 14
        let nx: Float = 160 + sin(t * 0.5) * 8
        let ny: Float = 150 + hop
        placeBuddy(nx, ny)
        let w: Float = sin(t * 2)
        pts[7].x = nx - 15
        pts[7].y = ny - 2 + w * 3
        pts[8].x = nx - 23
        pts[8].y = ny - 17 + w * 5
        pts[9].x = nx + 15
        pts[9].y = ny - 2 - w * 3
        pts[10].x = nx + 23
        pts[10].y = ny - 17 - w * 5
        pts[12].x += sin(t * 2) * 6
        pts[14].x -= sin(t * 2) * 6
        pts[0].x += sin(t) * 3
        expr = 1
        bubbleT = 0
        creamT = 0
        wetT = 0
        dizzyT = 0
        headSq = hop < -10 ? -0.08 : 0.06
        computeCentroid()
    }

    func drawTitleScene(_ c: BuddyCanvas) {
        drawBuddyShadow(c)
        drawBuddy(c)
        drawSparks(c)
        let t: Float = Float(titleT)
        let w1: [Character] = Array("BUDDY")
        let w2: [Character] = Array("BOUNCE")
        var i: Int = 0
        while i < w1.count {
            let x: Int = 160 - (w1.count * 24 - 6) / 2 + i * 24
            let y: Int = 22 + Int(sin(t * 0.12 + Float(i) * 0.9) * 4)
            let col: UInt32 = BuddyCol.hsv(Float(i) * 0.12 + t * 0.004, 0.65, 1)
            qtOutlined(String(w1[i]), x, y, col, brgb(70, 40, 20), 6)
            i += 1
        }
        i = 0
        while i < w2.count {
            let x: Int = 160 - (w2.count * 24 - 6) / 2 + i * 24
            let y: Int = 60 + Int(sin(t * 0.12 + Float(i) * 0.9 + 2) * 4)
            let col: UInt32 = BuddyCol.hsv(Float(i) * 0.12 + 0.5 + t * 0.004, 0.6, 1)
            qtOutlined(String(w2[i]), x, y, col, brgb(70, 40, 20), 6)
            i += 1
        }
        qtCentered("GIGGLY TOY PLAYGROUND", 160, 100, brgb(255, 255, 255), brgb(90, 50, 20), 1)
        let pulse: Float = 1 + sin(t * 0.12) * 0.05
        let bw: Float = 124 * pulse
        let bh: Float = 40 * pulse
        c.roundRect(160 - bw * 0.5 - 3, 252 - bh * 0.5 - 3, bw + 6, bh + 6, 20, brgb(255, 255, 255), brgb(255, 255, 255), 235)
        c.roundRect(160 - bw * 0.5, 252 - bh * 0.5, bw, bh, 17, brgb(120, 236, 120), brgb(40, 168, 70))
        c.roundRect(160 - bw * 0.5 + 6, 252 - bh * 0.5 + 3, bw - 12, bh * 0.4, 9, brgb(255, 255, 255), brgb(255, 255, 255), 70)
        qtCentered("PLAY", 160, 244, brgb(255, 255, 255), brgb(20, 100, 40), 3)
        if (titleT / 25) % 2 == 0 {
            qtCentered("TAP ANYWHERE", 160, 276, brgb(255, 255, 255), brgb(70, 40, 20), 1)
        }
    }

    // MARK: HUD

    func numStr(_ n: Int, _ cap: Int) -> String {
        return String(max(0, min(cap, n)))
    }

    func drawHUD(_ c: BuddyCanvas) {
        drawShelf(c)
        let white: UInt32 = brgb(255, 255, 255)
        // reset
        hudButton(c, 0, brgb(255, 176, 70), brgb(226, 104, 40))
        c.ring(17, 15, 6.5, 2.2, white)
        c.tri(17, 6, 17, 14, 24, 10, white)
        // wardrobe
        hudButton(c, 1, brgb(190, 130, 255), brgb(120, 70, 200))
        c.rotRect(17, 38, 6, 6, 0, white)
        c.rect(9, 43, 16, 3, white)
        c.rect(14, 38, 6, 2, brgb(220, 60, 90))
        // rooms
        hudButton(c, 2, brgb(110, 220, 130), brgb(50, 160, 90))
        c.roundRect(8, 60, 18, 14, 2, white, white)
        c.disc(21, 64, 2.2, brgb(255, 210, 60))
        c.tri(9, 73, 16, 65, 22, 73, brgb(70, 160, 90))
        // camera
        hudButton(c, 3, brgb(90, 210, 220), brgb(40, 150, 180))
        c.roundRect(291, 34, 20, 13, 3, white, white)
        c.rect(296, 32, 7, 3, white)
        c.disc(301, 41, 4.4, brgb(50, 60, 90))
        c.disc(301, 41, 2.2, brgb(120, 180, 255))
        c.disc(307, 37, 1.2, brgb(255, 210, 70))
        // slot machine
        hudButton(c, 4, brgb(255, 110, 120), brgb(200, 40, 70))
        c.roundRect(290, 58, 20, 18, 3, brgb(255, 214, 90), brgb(220, 160, 30))
        c.rect(292, 62, 5, 9, white)
        c.rect(298, 62, 5, 9, white)
        c.rect(304, 62, 4, 9, white)
        c.disc(294, 66, 1.6, brgb(230, 50, 70))
        c.disc(300, 66, 1.6, brgb(70, 150, 230))
        c.disc(306, 66, 1.6, brgb(70, 190, 100))
        c.capsule(312, 62, 312, 72, 1.1, brgb(230, 230, 240))
        c.disc(312, 61, 2, brgb(255, 70, 70))
        // star pill
        c.roundRect(34, 3, 56, 22, 11, brgb(70, 48, 110), brgb(40, 26, 74), 225)
        c.star(46, 14, 8, 3.6, 5, -1.57, brgb(255, 214, 70))
        c.star(46, 14, 5, 2.2, 5, -1.57, brgb(255, 240, 150))
        qtOutlined(numStr(stars, 9999), 58, 8, brgb(255, 255, 255), brgb(40, 26, 74), 2)
        // gold and cash pills
        c.roundRect(198, 3, 53, 22, 11, brgb(70, 48, 110), brgb(40, 26, 74), 225)
        drawGoldBar(c, 210, 14, 0.85)
        qtOutlined(numStr(gold, 9999), 222, 8, brgb(255, 230, 120), brgb(70, 40, 10), 2)
        c.roundRect(254, 3, 64, 22, 11, brgb(70, 48, 110), brgb(40, 26, 74), 225)
        drawCashStack(c, 266, 15, 0.85)
        qtOutlined(numStr(cash, 99999), 278, 8, brgb(170, 255, 170), brgb(20, 70, 30), 2)
        // free gift
        let ready: Bool = giftT <= 0
        if ready {
            let pulse: Float = 0.5 + 0.5 * sin(Float(frameN) * 0.18)
            c.roundRect(121, -1, 78, 36, 14, brgb(255, 255, 255), brgb(255, 220, 255), Int(70 + pulse * 120))
        }
        c.roundRect(123, 1, 74, 30, 12, brgb(255, 255, 255), brgb(255, 255, 255), 240)
        c.roundRect(125, 3, 70, 26, 10, brgb(255, 120, 210), brgb(196, 28, 140))
        c.roundRect(129, 5, 62, 9, 5, brgb(255, 255, 255), brgb(255, 255, 255), 80)
        drawGoldBar(c, 138, 17, 0.9)
        if ready {
            qtOutlined("FREE", 151, 10, brgb(255, 255, 255), brgb(140, 10, 90), 2)
        } else {
            let secs: Int = (giftT + 59) / 60
            let m: Int = secs / 60
            let s: Int = secs % 60
            let txt: String = String(m) + ":" + (s < 10 ? "0" : "") + String(s)
            qtOutlined(txt, 151, 10, brgb(255, 240, 255), brgb(140, 10, 90), 2)
        }
        // giggle meter
        c.roundRect(116, 32, 92, 11, 5.5, brgb(50, 30, 80), brgb(30, 18, 56), 215)
        let fillW: Float = 88 * buddyClampF(meter / 100, 0, 1)
        if fillW > 3 {
            c.roundRect(118, 34, fillW, 7, 3.5, brgb(255, 130, 200), brgb(255, 214, 90))
        }
        c.disc(112, 37.5, 8, brgb(255, 255, 255))
        c.disc(112, 37.5, 6.8, brgb(255, 214, 70))
        c.disc(109.5, 36, 1, brgb(60, 40, 40))
        c.disc(114.5, 36, 1, brgb(60, 40, 40))
        c.capsule(109, 40, 115, 40, 0.8, brgb(120, 50, 50))
        if comboCount >= 2 {
            qtOutlined("X" + String(min(comboCount, 99)), 212, 33, brgb(255, 240, 150), brgb(90, 40, 20), 1)
        }
        // goal panel
        let slot: Int = (frameN / 300) % 4
        let gid: Int = goalIds[slot]
        let target: Int = max(1, BuddyData.goalTargets[gid])
        let frac: Float = buddyClampF(Float(goalProg[slot]) / Float(target), 0, 1)
        c.roundRect(4, 217, 216, 18, 9, brgb(40, 26, 74), brgb(24, 14, 48), 190)
        if frac > 0.02 {
            c.roundRect(5, 218, 214 * frac, 16, 8, brgb(110, 220, 130), brgb(60, 170, 100), 150)
        }
        c.star(15, 226, 6, 2.8, 5, -1.57, brgb(255, 214, 70))
        let gtxt: String = BuddyData.goalTexts[gid] + "  " + String(goalProg[slot]) + "/" + String(target)
        qt(gtxt, 25, 223, brgb(255, 255, 255), 1)
    }

    func hudButton(_ c: BuddyCanvas, _ id: Int, _ c0: UInt32, _ c1: UInt32) {
        let r: [Int] = BuddyBounce64.hudRects[id]
        let down: Bool = pdown && mode == 2 && btnId == id
        let off: Float = down ? 1 : 0
        c.roundRect(Float(r[0]) - 1, Float(r[1]) - 1 + off, Float(r[2]) + 2, Float(r[3]) + 2, 9, brgb(255, 255, 255), brgb(255, 255, 255), 235)
        c.roundRect(Float(r[0]), Float(r[1]) + off, Float(r[2]), Float(r[3]), 8, c0, c1)
        c.roundRect(Float(r[0]) + 3, Float(r[1]) + 2 + off, Float(r[2]) - 6, 6, 3, brgb(255, 255, 255), brgb(255, 255, 255), 80)
    }

    func drawBannerToast(_ c: BuddyCanvas) {
        if bannerT > 0 {
            let tw: Int = textW(bannerText, 3)
            let slide: Float = bannerT > 88 ? Float(bannerT - 88) * 4 : 0
            let y: Float = 62 - slide
            var a: Int = 255
            if bannerT < 14 { a = bannerT * 255 / 14 }
            c.roundRect(160 - Float(tw) * 0.5 - 15, y - 6, Float(tw) + 30, 38, 14, brgb(40, 20, 70), brgb(40, 20, 70), a * 200 / 255)
            c.roundRect(160 - Float(tw) * 0.5 - 13, y - 4, Float(tw) + 26, 34, 12, brgb(255, 120, 190), brgb(150, 60, 200), a)
            if a > 100 {
                qtOutlined(bannerText, 160 - tw / 2, Int(y) + 3, bhx(bannerCol), brgb(60, 20, 80), 3)
            }
        }
        if toastT > 0 {
            let tw: Int = textW(toastText, 1)
            c.roundRect(160 - Float(tw) * 0.5 - 8, 196, Float(tw) + 16, 15, 7, brgb(30, 20, 60), brgb(30, 20, 60), 215)
            qt(toastText, 160 - tw / 2, 201, brgb(255, 255, 255), 1)
        }
    }

    func drawPhotoFx(_ c: BuddyCanvas) {
        if photoT <= 0 { return }
        if photoT > 52 {
            c.rect(0, 0, 320, 288, brgb(255, 255, 255), (photoT - 52) * 255 / 18)
        }
        var a: Int = 255
        if photoT < 16 { a = photoT * 255 / 16 }
        let white: UInt32 = brgb(255, 255, 255)
        c.rect(0, 0, 320, 9, white, a)
        c.rect(0, 0, 9, 288, white, a)
        c.rect(311, 0, 9, 288, white, a)
        c.rect(0, 262, 320, 26, white, a)
        var i: Int = 0
        while i < 56 {
            let t: Int = buddyHash(i + 900) % 1000
            let u: Float = Float(t) / 1000
            var x: Float = 0
            var y: Float = 0
            switch i % 4 {
            case 0:
                x = u * 320
                y = 4
            case 1:
                x = u * 320
                y = 267 + Float(buddyHash(i) % 8)
            case 2:
                x = 4
                y = u * 288
            default:
                x = 316
                y = u * 288
            }
            let col: UInt32 = BuddyCol.hsv(Float(buddyHash(i + 5) % 100) / 100, 0.7, 1)
            c.rotRect(x, y, 4, 2, Float(i) * 0.7 + Float(frameN) * 0.05, col, a)
            i += 1
        }
        if photoT > 20 {
            qtCentered("SNAP!", 160, 100, brgb(255, 255, 255), brgb(255, 80, 150), 4)
        }
        qtCentered("BUDDY BOUNCE", 160, 272, brgb(120, 80, 150), brgb(255, 255, 255), 1)
    }

    // MARK: Shelf and icons

    func drawShelf(_ c: BuddyCanvas) {
        c.vgrad(shelfTop, 288, brgb(150, 92, 54), brgb(96, 58, 34))
        c.rect(0, shelfTop, 320, 3, brgb(220, 160, 100))
        c.rect(0, shelfTop + 3, 320, 2, brgb(60, 34, 18), 120)
        var i: Int = 0
        while i < BuddyData.toyCount {
            let ix: Float = 8 + Float(i) * 44 - shelfScroll
            i += 1
            let idx: Int = i - 1
            if ix < -44 || ix > 320 { continue }
            let owned: Bool = toyOwned(idx)
            let selected: Bool = idx == selToy
            var yoff: Float = 0
            if selected { yoff = -3 - sin(shelfPop * 3.14159) * 4 }
            let base: UInt32 = bhx(BuddyData.toyColors[idx])
            if selected {
                c.roundRect(ix - 3, 243 + yoff, 46, 45, 11, brgb(255, 255, 255), brgb(255, 236, 140), 255)
            }
            c.roundRect(ix, 246 + yoff, 40, 40, 9, BuddyCol.shade(base, 1.2), BuddyCol.shade(base, 0.78))
            c.roundRect(ix + 3, 248 + yoff, 34, 7, 3, brgb(255, 255, 255), brgb(255, 255, 255), 70)
            drawToyIcon(c, idx, ix + 20, 261 + yoff, 0.8)
            if owned {
                qt(BuddyData.toyNames[idx], Int(ix) + 20 - textW(BuddyData.toyNames[idx], 1) / 2, Int(278 + yoff), brgb(255, 255, 255), 1)
            } else {
                c.roundRect(ix, 246 + yoff, 40, 40, 9, brgb(70, 60, 90), brgb(40, 34, 60), 175)
                // padlock
                c.roundRect(ix + 14, 256 + yoff, 12, 9, 2, brgb(255, 214, 80), brgb(220, 160, 40))
                c.ring(ix + 20, 256 + yoff, 4, 1.8, brgb(230, 230, 240))
                if BuddyData.toyGold[idx] {
                    drawGoldBar(c, ix + 9, 277 + yoff, 0.55)
                } else {
                    drawCashStack(c, ix + 9, 278 + yoff, 0.5)
                }
                qt(String(BuddyData.toyPrice[idx]), Int(ix) + 17, Int(274 + yoff), brgb(255, 255, 255), 2)
            }
        }
        if shelfScroll > 2 {
            c.tri(6, 262, 14, 255, 14, 269, brgb(255, 255, 255), 200)
        }
        if shelfScroll < maxShelfScroll() - 2 {
            c.tri(314, 262, 306, 255, 306, 269, brgb(255, 255, 255), 200)
        }
    }

    /// Draws toy icon number t centred on (cx0, cy0). s = 1 spans roughly 32 pixels.
    func drawToyIcon(_ c: BuddyCanvas, _ t: Int, _ cx0: Float, _ cy0: Float, _ s: Float) {
        func X(_ d: Float) -> Float { return cx0 + d * s }
        func Y(_ d: Float) -> Float { return cy0 + d * s }
        let white: UInt32 = brgb(255, 255, 255)
        let frameF: Float = Float(frameN)
        switch t {
        case 0:
            c.capsule(X(-10), Y(12), X(5), Y(-5), 2.5 * s, brgb(150, 100, 60))
            c.rotRect(X(8), Y(-8), 10 * s, 6.5 * s, 0.7, brgb(255, 150, 60))
            c.rotRect(X(8), Y(-8), 10 * s, 1.8 * s, 0.7, brgb(255, 226, 100))
        case 1:
            var i: Int = 0
            while i < 4 {
                let y0: Float = (i % 2 == 0) ? -3 : 3
                let y1: Float = (i % 2 == 0) ? 3 : -3
                c.capsule(X(-15 + Float(i) * 3.5), Y(6 + y0), X(-15 + Float(i + 1) * 3.5), Y(6 + y1), 1.2 * s, brgb(225, 228, 240))
                i += 1
            }
            c.capsule(X(0), Y(-3), X(0), Y(13), 2.6 * s, white)
            c.disc(X(7), Y(5), 9 * s, brgb(255, 70, 86))
            c.disc(X(10), Y(-5), 4.6 * s, brgb(255, 70, 86))
            c.disc(X(4), Y(2), 3 * s, white, 140)
        case 2:
            c.capsule(X(-3), Y(9), X(-4), Y(15), 1.3 * s, brgb(255, 150, 50))
            c.capsule(X(3), Y(9), X(3), Y(15), 1.3 * s, brgb(255, 150, 50))
            c.capsule(X(-9), Y(3), X(-15), Y(-2), 2.4 * s, brgb(255, 200, 50))
            c.ellipse(X(0), Y(4), 11 * s, 7.5 * s, brgb(255, 224, 70))
            c.capsule(X(6), Y(1), X(10), Y(-7), 2.8 * s, brgb(255, 224, 70))
            c.disc(X(11), Y(-9), 5 * s, brgb(255, 228, 80))
            c.tri(X(14), Y(-10), X(20), Y(-8), X(14), Y(-6), brgb(255, 150, 50))
            c.disc(X(10), Y(-15), 2.3 * s, brgb(240, 60, 70))
            c.disc(X(12), Y(-10.5), 1.2 * s, brgb(30, 30, 40))
        case 3:
            c.capsule(X(-11), Y(5), X(-13), Y(13), 1.6 * s, brgb(160, 166, 180))
            c.capsule(X(11), Y(5), X(13), Y(13), 1.6 * s, brgb(160, 166, 180))
            c.roundRect(X(-15), Y(2), 30 * s, 6 * s, 3 * s, brgb(100, 170, 255), brgb(50, 100, 210))
            c.roundRect(X(-12), Y(3), 24 * s, 2 * s, s, white, white, 150)
            c.star(X(0), Y(-8), 5 * s, 2 * s, 4, 0.3, brgb(255, 230, 90))
        case 4:
            c.ellipse(X(0), Y(8), 14 * s, 5 * s, brgb(170, 176, 190))
            c.ellipse(X(0), Y(5), 12 * s, 4 * s, brgb(240, 190, 120))
            c.disc(X(-6), Y(1), 6 * s, white)
            c.disc(X(6), Y(1), 6 * s, white)
            c.disc(X(0), Y(-2), 7.5 * s, white)
            c.disc(X(-2), Y(-4), 2.5 * s, brgb(255, 255, 255), 255)
            c.disc(X(0), Y(-10), 3 * s, brgb(230, 40, 60))
        case 5:
            c.tri(X(-3), Y(16), X(3), Y(16), X(0), Y(9), brgb(60, 150, 230))
            c.disc(X(0), Y(0), 11.5 * s, brgb(70, 170, 255))
            c.disc(X(-4), Y(-4), 3.6 * s, white, 190)
            c.disc(X(5), Y(4), 1.8 * s, white, 110)
        case 6:
            var i: Int = 0
            while i < 4 {
                let y0: Float = 6 + Float(i) * 2.4
                c.capsule(X(-6), Y(y0), X(6), Y(y0 + 1.2), 1.2 * s, brgb(225, 228, 240))
                i += 1
            }
            c.roundRect(X(-9), Y(12), 18 * s, 4 * s, 2 * s, brgb(90, 80, 110), brgb(60, 50, 80))
            c.rotRect(X(0), Y(3), 14 * s, 3 * s, -0.25, brgb(255, 170, 60))
            c.disc(X(10), Y(-6), 2.5 * s, brgb(255, 240, 150))
        case 7:
            c.rotRect(X(-3), Y(5), 12 * s, 6 * s, -0.75, brgb(150, 106, 230))
            c.rotRect(X(-8), Y(10), 5 * s, 6.5 * s, -0.75, brgb(255, 214, 80))
            c.star(X(9), Y(-9), 4 * s, 1.6 * s, 5, 0.2, brgb(255, 90, 140))
            c.rotRect(X(13), Y(-1), 2 * s, 1.2 * s, 0.5, brgb(80, 200, 255))
            c.rotRect(X(3), Y(-12), 2 * s, 1.2 * s, 1.1, brgb(120, 230, 130))
        case 8:
            c.capsule(X(0), Y(10), X(0), Y(15), 2 * s, brgb(120, 130, 150))
            c.disc(X(0), Y(-1), 13 * s, brgb(255, 255, 255), 80)
            c.ring(X(0), Y(-1), 12 * s, 2 * s, brgb(120, 130, 150))
            var i: Int = 0
            while i < 4 {
                let ang: Float = frameF * 0.3 + Float(i) * 1.5708
                c.capsule(X(0), Y(-1), X(cos(ang) * 10), Y(-1 + sin(ang) * 10), 3 * s, brgb(90, 210, 205))
                i += 1
            }
            c.disc(X(0), Y(-1), 3 * s, brgb(255, 220, 90))
        case 9:
            c.tri(X(-5), Y(8), X(-11), Y(14), X(-5), Y(2), brgb(255, 210, 60))
            c.tri(X(5), Y(8), X(11), Y(14), X(5), Y(2), brgb(255, 210, 60))
            c.capsule(X(0), Y(-8), X(0), Y(7), 5.2 * s, brgb(240, 80, 70))
            c.tri(X(-5), Y(-9), X(5), Y(-9), X(0), Y(-17), brgb(255, 245, 235))
            c.disc(X(0), Y(-3), 2.6 * s, brgb(120, 200, 255))
            c.ellipse(X(0), Y(12), 3.5 * s, 4.5 * s, brgb(255, 170, 50))
        case 10:
            c.disc(X(-6), Y(5), 7 * s, brgb(255, 90, 100))
            c.disc(X(7), Y(4), 7 * s, brgb(90, 190, 255))
            c.disc(X(0), Y(-6), 7 * s, brgb(255, 214, 70))
            c.disc(X(-8), Y(2), 2 * s, white, 180)
            c.disc(X(5), Y(1), 2 * s, white, 180)
            c.disc(X(-2), Y(-9), 2 * s, white, 180)
        case 11:
            c.capsule(X(-10), Y(13), X(-2), Y(4), 1.3 * s, brgb(160, 150, 170))
            c.capsule(X(-3), Y(5), X(9), Y(-12), 5.5 * s, brgb(255, 140, 200))
            c.capsule(X(-2), Y(4), X(8), Y(-10), 2 * s, brgb(255, 210, 235))
            c.capsule(X(4), Y(-3), X(12), Y(-6), 2 * s, brgb(255, 160, 210))
        case 12:
            c.capsule(X(-8), Y(-8), X(-8), Y(4), 3.8 * s, brgb(230, 70, 80))
            c.capsule(X(8), Y(-8), X(8), Y(4), 3.8 * s, brgb(230, 70, 80))
            c.capsule(X(-8), Y(4), X(-4), Y(10), 3.8 * s, brgb(230, 70, 80))
            c.capsule(X(-4), Y(10), X(4), Y(10), 3.8 * s, brgb(230, 70, 80))
            c.capsule(X(4), Y(10), X(8), Y(4), 3.8 * s, brgb(230, 70, 80))
            c.capsule(X(-8), Y(-13), X(-8), Y(-8), 3.9 * s, brgb(225, 228, 240))
            c.capsule(X(8), Y(-13), X(8), Y(-8), 3.9 * s, brgb(225, 228, 240))
        case 13:
            c.capsule(X(0), Y(15), X(0), Y(3), 2.6 * s, brgb(150, 100, 60))
            c.capsule(X(0), Y(3), X(-9), Y(-10), 2.6 * s, brgb(150, 100, 60))
            c.capsule(X(0), Y(3), X(9), Y(-10), 2.6 * s, brgb(150, 100, 60))
            c.capsule(X(-9), Y(-10), X(0), Y(-3), 1.1 * s, brgb(255, 120, 170))
            c.capsule(X(9), Y(-10), X(0), Y(-3), 1.1 * s, brgb(255, 120, 170))
            c.disc(X(0), Y(-3), 3.4 * s, brgb(120, 80, 50))
        case 14:
            var i: Int = 0
            while i < 6 {
                let a0: Float = frameF * 0.05 + Float(i) * 1.0472
                let a1: Float = a0 + 0.5236
                let a2: Float = a0 + 1.0472
                let r: Float = 13 * s
                c.poly([X(0), X(0) + cos(a0) * r, X(0) + cos(a1) * r, X(0) + cos(a2) * r],
                       [Y(0), Y(0) + sin(a0) * r, Y(0) + sin(a1) * r, Y(0) + sin(a2) * r],
                       BuddyCol.hsv(Float(i) / 6, 0.55, 1))
                i += 1
            }
            c.ring(X(0), Y(0), 13 * s, 2 * s, white)
            c.disc(X(0), Y(0), 3 * s, white)
        case 15:
            c.tri(X(-5), Y(14), X(5), Y(14), X(0), Y(4), brgb(110, 120, 150))
            c.rotRect(X(0), Y(4), 15 * s, 2.8 * s, -0.28, brgb(100, 210, 175))
            c.disc(X(-13.4), Y(7.9), 3.6 * s, brgb(255, 200, 70))
            c.disc(X(13.4), Y(0.1), 3.6 * s, brgb(255, 200, 70))
        case 16:
            c.disc(X(-9), Y(-2), 8 * s, brgb(140, 150, 170))
            c.disc(X(-9), Y(-2), 5.5 * s, brgb(246, 178, 198))
            c.disc(X(2), Y(-1), 11 * s, brgb(170, 180, 198))
            c.capsule(X(8), Y(3), X(13), Y(10), 4.2 * s, brgb(170, 180, 198))
            c.capsule(X(13), Y(10), X(10), Y(16), 3.4 * s, brgb(170, 180, 198))
            c.disc(X(5), Y(-4), 1.8 * s, brgb(34, 28, 36))
            c.disc(X(5), Y(3), 2.6 * s, brgb(255, 150, 170), 130)
        case 17:
            c.disc(X(0), Y(0), 12.5 * s, white)
            var i: Int = 0
            while i < 6 {
                if i % 2 == 0 {
                    let a0: Float = 0.5 + Float(i) * 1.0472
                    let a1: Float = a0 + 0.5236
                    let a2: Float = a0 + 1.0472
                    let col: UInt32 = (i == 0) ? brgb(255, 90, 100) : ((i == 2) ? brgb(255, 205, 70) : brgb(80, 170, 255))
                    let r: Float = 12 * s
                    c.poly([X(0), X(0) + cos(a0) * r, X(0) + cos(a1) * r, X(0) + cos(a2) * r],
                           [Y(0), Y(0) + sin(a0) * r, Y(0) + sin(a1) * r, Y(0) + sin(a2) * r], col)
                }
                i += 1
            }
            c.disc(X(0), Y(0), 2.5 * s, white)
        case 18:
            c.ellipse(X(0), Y(5), 13 * s, 9 * s, brgb(255, 214, 40))
            c.disc(X(7), Y(-5), 6.5 * s, brgb(255, 222, 60))
            c.ellipse(X(14), Y(-3), 4.2 * s, 2.2 * s, brgb(255, 140, 40))
            c.disc(X(8), Y(-7), 1.5 * s, brgb(30, 30, 40))
            c.ellipse(X(-2), Y(6), 7 * s, 4 * s, brgb(240, 180, 20))
            c.disc(X(-12), Y(2), 3.4 * s, brgb(255, 214, 40))
        case 19:
            c.roundRect(X(-15), Y(1), 30 * s, 10 * s, 5 * s, brgb(90, 96, 114), brgb(50, 54, 70))
            var i: Int = 0
            while i < 4 {
                let bx: Float = -9 + Float(i) * 6
                c.tri(X(bx), Y(3), X(bx + 3), Y(6), X(bx), Y(9), brgb(255, 214, 80))
                i += 1
            }
            c.disc(X(-13), Y(6), 5 * s, brgb(255, 200, 60))
            c.disc(X(13), Y(6), 5 * s, brgb(255, 200, 60))
            c.disc(X(0), Y(-8), 3.4 * s, brgb(255, 120, 150))
        default:
            c.roundRect(X(-13), Y(8), 26 * s, 6 * s, 2 * s, brgb(150, 100, 60), brgb(110, 70, 40))
            c.disc(X(-9), Y(15), 3.4 * s, brgb(60, 50, 60))
            c.disc(X(9), Y(15), 3.4 * s, brgb(60, 50, 60))
            c.capsule(X(0), Y(8), X(11), Y(-9), 2.8 * s, brgb(190, 130, 76))
            c.disc(X(11), Y(-10), 5.5 * s, brgb(230, 90, 70))
            c.disc(X(14), Y(-16), 2.8 * s, brgb(255, 214, 70))
        }
    }

    func drawSlotSym(_ c: BuddyCanvas, _ sym: Int, _ x: Float, _ y: Float, _ s: Float) {
        switch sym {
        case 0:
            drawCashStack(c, x, y + 2 * s, 1.5 * s)
        case 1:
            drawGoldBar(c, x, y, 1.6 * s)
        case 2:
            c.roundRect(x - 14 * s, y - 8 * s, 28 * s, 22 * s, 3 * s, brgb(90, 170, 255), brgb(50, 110, 220))
            c.rect(Int(x - 2 * s), Int(y - 8 * s), max(2, Int(4 * s)), Int(22 * s), brgb(255, 220, 90))
            c.rect(Int(x - 14 * s), Int(y + 1 * s), Int(28 * s), max(2, Int(4 * s)), brgb(255, 220, 90))
            c.disc(x - 5 * s, y - 11 * s, 5 * s, brgb(255, 220, 90))
            c.disc(x + 5 * s, y - 11 * s, 5 * s, brgb(255, 220, 90))
        case 3:
            c.rotRect(x, y - 3 * s, 11 * s, 11 * s, 0, brgb(56, 48, 78))
            c.rotRect(x, y + 7 * s, 19 * s, 3 * s, 0, brgb(44, 38, 64))
            c.rotRect(x, y + 3 * s, 11.2 * s, 2.5 * s, 0, brgb(220, 60, 70))
        case 4:
            c.star(x, y, 17 * s, 7.5 * s, 5, -1.57, brgb(255, 210, 60))
            c.star(x, y, 10 * s, 4.5 * s, 5, -1.57, brgb(255, 240, 150))
        default:
            c.disc(x, y, 16 * s, brgb(255, 214, 70))
            c.disc(x - 6 * s, y - 4 * s, 2.4 * s, brgb(60, 40, 40))
            c.disc(x + 6 * s, y - 4 * s, 2.4 * s, brgb(60, 40, 40))
            c.ellipse(x, y + 6 * s, 7 * s, 4 * s, brgb(120, 40, 50))
        }
    }

    // MARK: Gift and photo

    func claimGift() {
        if giftT > 0 {
            let secs: Int = (giftT + 59) / 60
            showToast("NEXT FREE GIFT IN " + String(secs / 60) + ":" + (secs % 60 < 10 ? "0" : "") + String(secs % 60))
            play(.blip)
            return
        }
        gold = min(9999, gold + 1)
        cash = min(999999, cash + 40)
        giftT = 10800
        confettiBurst(160, 40, 60)
        showBanner("FREE GIFT!", 0xFFE066)
        showToast("+1 GOLD BAR  +40 CASH")
        play(.win)
    }

    func takePhoto() {
        photoT = 70
        statPhotos = min(99999999, statPhotos + 1)
        play(.hit)
        play(.blip)
        confettiBurst(160, 20, 30)
    }

    // MARK: Menus

    static let roomTops: [UInt32] = [0xE0AC6E, 0xFFEEB0, 0x78C8FF, 0x6ACCFF, 0x0A0C34, 0xFFBEE0, 0x3C2468]
    static let roomBots: [UInt32] = [0xC28A50, 0xFFDC96, 0xD2EEFF, 0xC4EEFF, 0x2C1658, 0xFFEAF8, 0xFF9678]
    static let roomFloors: [UInt32] = [0x96603A, 0xE2AA6A, 0x64B848, 0xDEBE86, 0x606A8C, 0xFF96C4, 0x746C86]

    func hatOwned(_ i: Int) -> Bool { return (hatsOwned >> i) & 1 == 1 }
    func scarfOwned(_ i: Int) -> Bool { return (scarvesOwned >> i) & 1 == 1 }
    func roomUnlocked(_ i: Int) -> Bool {
        return ((roomsOwned >> i) & 1 == 1) || stars >= BuddyData.roomStars[i]
    }

    func updateMenu() {
        if menu == 4 { updateSlot() }
        if menu == 4 && slotPhase == 0 {
            // swipe down on the machine pulls the lever
            if ppressed { slotDragY = py }
            if pdown && !ppressed && py - slotDragY > 22 && px > 40 && px < 300 {
                startSpin()
                slotDragY = py + 1000
            }
        }
        if !ppressed { return }
        let x: Float = px
        let y: Float = py
        if x >= 270 && x < 308 && y >= 32 && y < 58 {
            menu = 0
            play(.select)
            return
        }
        if x < 10 || x > 310 || y < 28 || y > 234 {
            menu = 0
            return
        }
        switch menu {
        case 1: tapWardrobe(x, y)
        case 2: tapRooms(x, y)
        case 4: tapSlot(x, y)
        default: break
        }
    }

    func tapWardrobe(_ x: Float, _ y: Float) {
        var i: Int = 0
        while i < BuddyData.hatNames.count {
            let cxp: Float = 22 + Float(i % 5) * 56
            let cyp: Float = 66 + Float(i / 5) * 52
            if x >= cxp && x < cxp + 54 && y >= cyp && y < cyp + 48 {
                if hatOwned(i) {
                    selHat = i
                    play(.select)
                } else if cash >= BuddyData.hatPrice[i] {
                    cash -= BuddyData.hatPrice[i]
                    hatsOwned |= (1 << i)
                    selHat = i
                    play(.powerup)
                    confettiBurst(160, 120, 25)
                } else {
                    notEnough("CASH")
                }
                return
            }
            i += 1
        }
        i = 0
        while i < BuddyData.scarfNames.count {
            let cxp: Float = 20 + Float(i) * 40
            if x >= cxp && x < cxp + 37 && y >= 178 && y < 212 {
                if scarfOwned(i) {
                    selScarf = i
                    play(.select)
                } else if cash >= BuddyData.scarfPrice[i] {
                    cash -= BuddyData.scarfPrice[i]
                    scarvesOwned |= (1 << i)
                    selScarf = i
                    play(.powerup)
                    confettiBurst(160, 120, 25)
                } else {
                    notEnough("CASH")
                }
                return
            }
            i += 1
        }
    }

    func tapRooms(_ x: Float, _ y: Float) {
        var i: Int = 0
        while i < BuddyData.roomNames.count {
            let cxp: Float = 18 + Float(i % 4) * 72
            let cyp: Float = 66 + Float(i / 4) * 80
            if x >= cxp && x < cxp + 68 && y >= cyp && y < cyp + 72 {
                if roomUnlocked(i) {
                    roomsOwned |= (1 << i)
                    menu = 0
                    if i != selRoom {
                        setRoom(i)
                    }
                    play(.powerup)
                } else {
                    play(.blip)
                    menuShake = 18
                    addFloat("NEED " + String(BuddyData.roomStars[i]) + " STARS", 160, 226, 0xFFE066)
                }
                return
            }
            i += 1
        }
    }

    func drawPanel(_ c: BuddyCanvas, _ title: String) {
        c.rect(0, 0, 320, 288, brgb(20, 10, 40), 150)
        let sh: Float = menuShake > 0 ? sin(Float(menuShake) * 1.6) * 3 : 0
        c.roundRect(10 + sh, 28, 300, 208, 14, brgb(255, 255, 255), brgb(255, 255, 255), 245)
        c.roundRect(13 + sh, 31, 294, 202, 12, brgb(255, 244, 214), brgb(255, 224, 170))
        c.roundRect(13 + sh, 31, 294, 22, 12, brgb(190, 110, 255), brgb(130, 70, 220))
        c.roundRect(272, 33, 32, 20, 9, brgb(255, 120, 120), brgb(220, 50, 70))
        c.capsule(282, 38, 294, 48, 1.6, brgb(255, 255, 255))
        c.capsule(294, 38, 282, 48, 1.6, brgb(255, 255, 255))
        qtOutlined(title, 22, 37, brgb(255, 255, 255), brgb(80, 30, 120), 2)
    }

    func drawMenu(_ c: BuddyCanvas) {
        switch menu {
        case 1: drawWardrobe(c)
        case 2: drawRoomsMenu(c)
        case 3: drawGoalsMenu(c)
        default: drawSlot(c)
        }
    }

    func priceBadge(_ c: BuddyCanvas, _ x: Float, _ y: Float, _ price: Int, _ isGold: Bool) {
        c.roundRect(x, y, 30, 12, 6, brgb(40, 26, 74), brgb(24, 14, 48), 220)
        if isGold {
            drawGoldBar(c, x + 7, y + 6, 0.5)
        } else {
            drawCashStack(c, x + 7, y + 7, 0.45)
        }
        qt(String(price), Int(x) + 14, Int(y) + 4, brgb(255, 255, 255), 1)
    }

    func drawWardrobe(_ c: BuddyCanvas) {
        drawPanel(c, "WARDROBE")
        var i: Int = 0
        while i < BuddyData.hatNames.count {
            let cxp: Float = 22 + Float(i % 5) * 56
            let cyp: Float = 66 + Float(i / 5) * 52
            let sel: Bool = i == selHat
            if sel {
                c.roundRect(cxp - 2, cyp - 2, 58, 52, 10, brgb(255, 200, 40), brgb(255, 150, 30))
            }
            c.roundRect(cxp, cyp, 54, 48, 9, brgb(255, 255, 255), brgb(236, 226, 255))
            let hx: Float = cxp + 27
            let hy: Float = cyp + 36
            c.disc(hx, hy, 11, brgb(160, 120, 72))
            c.disc(hx, hy, 10, brgb(212, 172, 112))
            c.disc(hx - 4, hy - 1, 1.8, brgb(34, 28, 36))
            c.disc(hx + 4, hy - 1, 1.8, brgb(34, 28, 36))
            c.disc(hx, hy + 4, 1.2, brgb(104, 70, 38))
            drawHat(c, i, hx, hy - 9.5, 0)
            if !hatOwned(i) {
                c.roundRect(cxp, cyp, 54, 48, 9, brgb(60, 50, 80), brgb(60, 50, 80), 110)
                priceBadge(c, cxp + 12, cyp + 34, BuddyData.hatPrice[i], false)
            } else if sel {
                c.disc(cxp + 46, cyp + 8, 6, brgb(80, 200, 110))
                c.capsule(cxp + 43, cyp + 8, cxp + 45.5, cyp + 11, 1.2, brgb(255, 255, 255))
                c.capsule(cxp + 45.5, cyp + 11, cxp + 50, cyp + 5, 1.2, brgb(255, 255, 255))
            }
            i += 1
        }
        qt("SCARVES", 22, 166, brgb(110, 60, 150), 1)
        i = 0
        while i < BuddyData.scarfNames.count {
            let cxp: Float = 20 + Float(i) * 40
            let sel: Bool = i == selScarf
            if sel {
                c.roundRect(cxp - 2, 176, 41, 38, 9, brgb(255, 200, 40), brgb(255, 150, 30))
            }
            c.roundRect(cxp, 178, 37, 34, 8, brgb(255, 255, 255), brgb(236, 226, 255))
            if i == 6 {
                var k: Int = 0
                while k < 5 {
                    c.rect(Int(cxp) + 5 + k * 5, 184, 5, 14, scarfColor(6, k))
                    k += 1
                }
            } else {
                c.roundRect(cxp + 5, 184, 27, 14, 6, scarfColor(i, 0), BuddyCol.shade(scarfColor(i, 0), 0.8))
            }
            if !scarfOwned(i) {
                c.roundRect(cxp, 178, 37, 34, 8, brgb(60, 50, 80), brgb(60, 50, 80), 110)
                priceBadge(c, cxp + 3, 198, BuddyData.scarfPrice[i], false)
            } else if sel {
                c.disc(cxp + 30, 184, 4.5, brgb(80, 200, 110))
            }
            i += 1
        }
        qtCentered("TAP TO WEAR OR BUY", 160, 220, brgb(110, 60, 150), brgb(255, 244, 214), 1)
    }

    func drawRoomsMenu(_ c: BuddyCanvas) {
        drawPanel(c, "ROOMS")
        var i: Int = 0
        while i < BuddyData.roomNames.count {
            let cxp: Float = 18 + Float(i % 4) * 72
            let cyp: Float = 66 + Float(i / 4) * 80
            let sel: Bool = i == selRoom
            if sel {
                c.roundRect(cxp - 2, cyp - 2, 72, 76, 10, brgb(255, 200, 40), brgb(255, 150, 30))
            }
            c.roundRect(cxp, cyp, 68, 72, 9, brgb(255, 255, 255), brgb(236, 226, 255))
            c.roundRect(cxp + 4, cyp + 4, 60, 40, 6, bhx(BuddyBounce64.roomTops[i]), bhx(BuddyBounce64.roomBots[i]))
            c.rect(Int(cxp) + 5, Int(cyp) + 34, 58, 9, bhx(BuddyBounce64.roomFloors[i]))
            c.disc(cxp + 18, cyp + 24, 5, brgb(255, 255, 255), 150)
            let name: String = BuddyData.roomNames[i]
            qt(name, Int(cxp) + 34 - textW(name, 1) / 2, Int(cyp) + 48, brgb(80, 40, 110), 1)
            if roomUnlocked(i) {
                qt("OPEN", Int(cxp) + 34 - textW("OPEN", 1) / 2, Int(cyp) + 60, brgb(40, 150, 80), 1)
            } else {
                c.star(cxp + 20, cyp + 63, 5, 2.2, 5, -1.57, brgb(255, 190, 40))
                qt(String(BuddyData.roomStars[i]) + " STARS", Int(cxp) + 28, Int(cyp) + 61, brgb(200, 90, 40), 1)
                c.roundRect(cxp + 4, cyp + 4, 60, 40, 6, brgb(50, 40, 70), brgb(50, 40, 70), 130)
                c.roundRect(cxp + 28, cyp + 16, 12, 9, 2, brgb(255, 214, 80), brgb(220, 160, 40))
                c.ring(cxp + 34, cyp + 16, 4, 1.8, brgb(230, 230, 240))
            }
            i += 1
        }
        qtCentered("EARN STARS FROM GOALS AND PARTIES", 160, 222, brgb(110, 60, 150), brgb(255, 244, 214), 1)
    }

    func drawGoalsMenu(_ c: BuddyCanvas) {
        drawPanel(c, "GOALS")
        var i: Int = 0
        while i < 4 {
            let y: Float = 60 + Float(i) * 32
            let gid: Int = goalIds[i]
            let target: Int = max(1, BuddyData.goalTargets[gid])
            let frac: Float = buddyClampF(Float(goalProg[i]) / Float(target), 0, 1)
            c.roundRect(20, y, 280, 28, 10, brgb(255, 255, 255), brgb(240, 232, 255))
            c.roundRect(24, y + 17, 272, 7, 3.5, brgb(210, 200, 230), brgb(210, 200, 230))
            if frac > 0.02 {
                c.roundRect(24, y + 17, 272 * frac, 7, 3.5, brgb(110, 220, 130), brgb(60, 170, 100))
            }
            c.star(34, y + 8, 6, 2.8, 5, -1.57, brgb(255, 200, 40))
            qt(BuddyData.goalTexts[gid], 46, Int(y) + 5, brgb(80, 40, 110), 1)
            let prog: String = String(goalProg[i]) + "/" + String(target)
            qt(prog, 296 - textW(prog, 1), Int(y) + 5, brgb(80, 40, 110), 1)
            i += 1
        }
        qt("BOUNCES " + String(statBounces) + "   FLINGS " + String(statFlings), 24, 192, brgb(110, 60, 150), 1)
        qt("PARTIES " + String(statParties) + "   PIES " + String(statPies), 24, 202, brgb(110, 60, 150), 1)
        qt("BEST COMBO " + String(statBestCombo) + "   GOALS " + String(statGoals), 24, 212, brgb(110, 60, 150), 1)
        qt("PHOTOS " + String(statPhotos) + "   SPINS " + String(statSpins), 24, 222, brgb(110, 60, 150), 1)
    }

    // MARK: Lucky spin

    func openSlot() {
        menu = 4
        slotPhase = 0
        slotMsg = statSpins == 0 ? "FIRST SPIN IS FREE!" : "PULL THE LEVER! 25 CASH"
        slotDragY = 5000
        play(.select)
    }

    func tapSlot(_ x: Float, _ y: Float) {
        if slotPhase != 0 { return }
        if x >= 100 && x < 220 && y >= 168 && y < 200 { startSpin() }
        if x >= 258 && x < 306 && y >= 70 && y < 190 { startSpin() }
    }

    func startSpin() {
        if slotPhase != 0 { return }
        let cost: Int = statSpins == 0 ? 0 : 25
        if cash < cost {
            slotMsg = "NEED 25 CASH"
            menuShake = 18
            play(.blip)
            return
        }
        cash -= cost
        statSpins = min(99999999, statSpins + 1)
        var a: Int = rng.int(6)
        var b: Int = rng.int(6)
        var d: Int = rng.int(6)
        slotPrize = 0
        slotPrizeArg = 0
        let r: Int = rng.int(100)
        if r < 38 {
            if a == b && b == d { d = (d + 1) % 6 }
        } else if r < 63 {
            a = 0; b = 0; d = 0
            slotPrize = 1
            slotPrizeArg = 60
        } else if r < 74 {
            a = 1; b = 1; d = 1
            slotPrize = 2
            slotPrizeArg = 1
        } else if r < 84 {
            var locked: [Int] = []
            var i: Int = 0
            while i < BuddyData.toyCount {
                if !toyOwned(i) { locked.append(i) }
                i += 1
            }
            if locked.isEmpty {
                a = 0; b = 0; d = 0
                slotPrize = 1
                slotPrizeArg = 80
            } else {
                a = 2; b = 2; d = 2
                slotPrize = 3
                slotPrizeArg = locked[rng.int(locked.count)]
            }
        } else if r < 93 {
            var locked: [Int] = []
            var i: Int = 0
            while i < BuddyData.hatNames.count {
                if !hatOwned(i) { locked.append(i) }
                i += 1
            }
            if locked.isEmpty {
                a = 0; b = 0; d = 0
                slotPrize = 1
                slotPrizeArg = 80
            } else {
                a = 3; b = 3; d = 3
                slotPrize = 4
                slotPrizeArg = locked[rng.int(locked.count)]
            }
        } else {
            a = 4; b = 4; d = 4
            slotPrize = 5
        }
        slotTarget = [a, b, d]
        slotPhase = 1
        slotT = 0
        slotStop = [52, 76, 100]
        slotStopped = [false, false, false]
        slotLever = 1
        slotMsg = "SPINNING..."
        play(.select)
        play(.pickup)
    }

    func updateSlot() {
        if slotLever > 0 { slotLever = max(0, slotLever - 0.04) }
        if slotPhase != 1 { return }
        slotT += 1
        var i: Int = 0
        while i < 3 {
            if !slotStopped[i] {
                if slotT >= slotStop[i] {
                    slotStopped[i] = true
                    slotPos[i] = slotGoal[i]
                    play(.blip)
                } else if slotT >= slotStop[i] - 14 {
                    if slotT == slotStop[i] - 14 {
                        let target: Int = slotTarget[i]
                        var g: Float = floor(slotPos[i]) + 8
                        var guardN: Int = 0
                        while Int(g) % 6 != target && guardN < 8 {
                            g += 1
                            guardN += 1
                        }
                        slotGoal[i] = g
                    }
                    let left: Float = Float(max(1, slotStop[i] - slotT + 1))
                    slotPos[i] += (slotGoal[i] - slotPos[i]) / left
                } else {
                    slotPos[i] += 0.6
                }
            }
            i += 1
        }
        if slotStopped[0] && slotStopped[1] && slotStopped[2] {
            slotPhase = 2
            finishSpin()
        }
    }

    func finishSpin() {
        switch slotPrize {
        case 1:
            cash = min(999999, cash + slotPrizeArg)
            slotMsg = "WIN! +" + String(slotPrizeArg) + " CASH"
            play(.win)
        case 2:
            gold = min(9999, gold + slotPrizeArg)
            slotMsg = "GOLD BAR! +1 GOLD"
            play(.win)
        case 3:
            toysOwned |= (1 << slotPrizeArg)
            slotMsg = "NEW TOY! " + BuddyData.toyNames[slotPrizeArg]
            play(.win)
        case 4:
            hatsOwned |= (1 << slotPrizeArg)
            slotMsg = "NEW HAT! " + BuddyData.hatNames[slotPrizeArg]
            play(.win)
        case 5:
            stars = min(9999, stars + 1)
            slotMsg = "A SHINY STAR!"
            play(.win)
        default:
            cash = min(999999, cash + 5)
            slotMsg = "SO CLOSE! +5 CASH"
            play(.coin)
        }
        if slotPrize != 0 { confettiBurst(160, 110, 60) }
        slotPhase = 0
    }

    func drawSlot(_ c: BuddyCanvas) {
        drawPanel(c, "LUCKY SPIN")
        let body: UInt32 = brgb(204, 52, 66)
        c.roundRect(56, 58, 208, 112, 14, brgb(255, 214, 90), brgb(220, 160, 30))
        c.roundRect(60, 62, 200, 104, 12, body, body)
        // reels
        var i: Int = 0
        while i < 3 {
            let rx: Float = 70 + Float(i) * 62
            c.roundRect(rx - 2, 76, 60, 66, 6, brgb(80, 30, 40), brgb(80, 30, 40))
            c.roundRect(rx, 78, 56, 62, 5, brgb(255, 250, 235), brgb(240, 230, 210))
            let pos: Float = slotPos[i]
            let base: Int = Int(floor(buddyClampF(pos, -100000, 100000)))
            let frac: Float = pos - floor(pos)
            var k: Int = -1
            while k <= 2 {
                let sym: Int = ((base + k) % 6 + 6) % 6
                let yc: Float = 109 - frac * 40 + Float(k) * 40
                if yc > 62 && yc < 156 {
                    drawSlotSym(c, sym, rx + 28, yc, 0.9)
                }
                k += 1
            }
            c.rect(Int(rx) - 3, 62, 62, 16, body)
            c.rect(Int(rx) - 3, 140, 62, 26, body)
            c.roundRect(rx - 2, 76, 60, 66, 6, brgb(255, 255, 255), brgb(255, 255, 255), 0)
            c.rect(Int(rx), 78, 56, 3, brgb(0, 0, 0), 40)
            c.rect(Int(rx), 137, 56, 3, brgb(0, 0, 0), 40)
            i += 1
        }
        c.rect(66, 108, 188, 2, brgb(255, 80, 90), 90)
        qtOutlined("LUCKY", 160 - textW("LUCKY", 2) / 2, 63, brgb(255, 240, 150), brgb(120, 20, 40), 2)
        // lever
        let ly: Float = 96 + slotLever * 0 + (1 - slotLever) * 0
        c.capsule(278, 150, 278, 112 + slotLever * 36, 3, brgb(200, 204, 216))
        c.disc(278, ly + slotLever * 40 + 4, 8, brgb(255, 70, 80))
        c.disc(275, ly + slotLever * 40 + 1, 2.4, brgb(255, 255, 255), 180)
        c.roundRect(268, 150, 20, 12, 4, brgb(150, 156, 172), brgb(100, 106, 124))
        // button
        let ready: Bool = slotPhase == 0
        c.roundRect(100, 172, 120, 28, 12, brgb(255, 255, 255), brgb(255, 255, 255), 240)
        c.roundRect(102, 174, 116, 24, 10, ready ? brgb(120, 236, 120) : brgb(170, 170, 180), ready ? brgb(40, 168, 70) : brgb(120, 120, 134))
        let costTxt: String = statSpins == 0 ? "SPIN FREE" : "SPIN 25"
        qtOutlined(costTxt, 160 - textW(costTxt, 2) / 2, 180, brgb(255, 255, 255), brgb(20, 90, 40), 2)
        qtCentered(slotMsg, 160, 210, brgb(110, 40, 150), brgb(255, 244, 214), 1)
        qt("SWIPE DOWN OR TAP THE LEVER", 160 - textW("SWIPE DOWN OR TAP THE LEVER", 1) / 2, 222, brgb(150, 100, 180), 1)
    }
}
