#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

// Rooms, props, pads and effects drawing for BUDDY BOUNCE.

/// 0xRRGGBB hex to the framebuffer pixel format.
@inline(__always) func bhx(_ h: UInt32) -> UInt32 {
    return BuddyCol.hex(h)
}

@inline(__always) func brgb(_ r: Int, _ g: Int, _ b: Int) -> UInt32 {
    return BuddyCol.rgb(r, g, b)
}

func buddyHash(_ n: Int) -> Int {
    var v: Int = (n &* 1103515245 &+ 12345) & 0x7FFF_FFFF
    v = (v ^ (v >> 13)) & 0x7FFF_FFFF
    v = (v &* 1103515245 &+ 12345) & 0x7FFF_FFFF
    return v
}

extension BuddyBounce64 {
    // MARK: Text queue

    func qt(_ s: String, _ x: Int, _ y: Int, _ col: UInt32, _ scale: Int) {
        texts.append(BuddyText(s: s, x: x, y: y, col: col, scale: scale))
    }

    func qtOutlined(_ s: String, _ x: Int, _ y: Int, _ col: UInt32, _ outline: UInt32, _ scale: Int) {
        let o: Int = max(1, scale / 2)
        qt(s, x - o, y, outline, scale)
        qt(s, x + o, y, outline, scale)
        qt(s, x, y - o, outline, scale)
        qt(s, x, y + o, outline, scale)
        qt(s, x + o, y + o, outline, scale)
        qt(s, x, y, col, scale)
    }

    func textW(_ s: String, _ scale: Int) -> Int {
        return s.isEmpty ? 0 : (s.count * 4 - 1) * scale
    }

    func qtCentered(_ s: String, _ cxx: Int, _ y: Int, _ col: UInt32, _ outline: UInt32, _ scale: Int) {
        let w: Int = textW(s, scale)
        qtOutlined(s, cxx - w / 2, y, col, outline, scale)
    }

    // MARK: Background cache

    func ensureBackground() {
        let desired: Int = (phase == 0) ? 0 : selRoom
        if bgRoom == desired && bgCache.count == 320 * 288 { return }
        var tmp: [UInt32] = [UInt32](repeating: 0xFF00_0000, count: 320 * 288)
        tmp.withUnsafeMutableBufferPointer { buf in
            if let base = buf.baseAddress {
                let c = BuddyCanvas(p: base, w: 320, h: 288)
                self.renderRoomStatic(c, desired)
            }
        }
        bgCache = tmp
        bgRoom = desired
    }

    func blitBackground(_ c: BuddyCanvas) {
        let n: Int = min(bgCache.count, c.w * c.h)
        bgCache.withUnsafeBufferPointer { src in
            if let s = src.baseAddress {
                var i: Int = 0
                while i < n {
                    c.p[i] = s[i]
                    i += 1
                }
            }
        }
    }

    func vignette(_ c: BuddyCanvas, _ strength: Float) {
        var y: Int = 0
        while y < c.h {
            let ny: Float = (Float(y) - 144) / 160
            var x: Int = 0
            while x < c.w {
                let nx: Float = (Float(x) - 160) / 190
                let d: Float = nx * nx + ny * ny
                if d > 0.35 {
                    var f: Float = 1 - strength * (d - 0.35) * 1.1
                    if f < 0.55 { f = 0.55 }
                    let i: Int = y * c.w + x
                    let px0: UInt32 = c.p[i]
                    let fi: Int = Int(f * 256)
                    let r: Int = (Int(px0 & 255) * fi) >> 8
                    let g: Int = (Int((px0 >> 8) & 255) * fi) >> 8
                    let b: Int = (Int((px0 >> 16) & 255) * fi) >> 8
                    c.p[i] = 0xFF00_0000 | UInt32(r) | (UInt32(g) << 8) | (UInt32(b) << 16)
                }
                x += 1
            }
            y += 1
        }
    }

    func renderRoomStatic(_ c: BuddyCanvas, _ room: Int) {
        switch room {
        case 0: roomBox(c)
        case 1: roomPlay(c)
        case 2: roomYard(c)
        case 3: roomBeach(c)
        case 4: roomSpace(c)
        case 5: roomCandy(c)
        default: roomRoof(c)
        }
        vignette(c, room == 4 ? 0.4 : 0.32)
    }

    func planks(_ c: BuddyCanvas, _ y0: Int, _ y1: Int, _ rowH: Int, _ dark: UInt32, _ seed: Int) {
        var row: Int = 0
        var y: Int = y0
        while y < y1 {
            c.rect(0, y, 320, 1, dark, 110)
            var x: Int = (buddyHash(seed + row) % 90)
            while x < 320 {
                c.rect(x, y, 1, rowH, dark, 90)
                x += 70 + (buddyHash(seed + row * 7 + x) % 50)
            }
            y += rowH
            row += 1
        }
    }

    // MARK: Rooms (static layer)

    func roomBox(_ c: BuddyCanvas) {
        c.vgrad(0, 212, brgb(224, 172, 110), brgb(194, 138, 80))
        var x: Int = 0
        while x < 320 {
            let s: Float = sin(Float(x) * 0.7854)
            if s > 0 {
                c.rect(x, 0, 1, 212, brgb(255, 236, 200), Int(s * 26))
            } else {
                c.rect(x, 0, 1, 212, brgb(90, 50, 20), Int(-s * 34))
            }
            x += 1
        }
        // box corners and top flap
        c.rect(0, 0, 10, 212, brgb(70, 36, 12), 70)
        c.rect(310, 0, 10, 212, brgb(70, 36, 12), 70)
        c.rect(0, 0, 320, 22, brgb(120, 72, 34), 90)
        var y: Int = 22
        while y < 44 {
            let a: Int = 60 - (y - 22) * 3
            c.rect(0, y, 320, 1, brgb(70, 36, 12), max(0, a))
            y += 1
        }
        c.capsule(0, 22, 320, 22, 1.2, brgb(110, 70, 36), 200)
        // tape on the top-right corner
        c.rotRect(296, 20, 40, 9, 0.7, brgb(244, 226, 164), 200)
        c.rotRect(296, 20, 40, 9, 0.7, brgb(255, 255, 255), 40)
        c.capsule(262, 40, 332, -10, 0.8, brgb(200, 176, 110), 160)
        // red ribbon tab
        let ribX: [Float] = [98, 118, 118, 108, 98]
        let ribY: [Float] = [0, 0, 40, 32, 40]
        c.poly(ribX, ribY, brgb(214, 52, 62))
        c.rect(98, 0, 3, 38, brgb(255, 255, 255), 50)
        c.stitch(108, 2, 108, 28, brgb(255, 210, 210), 4)
        // wall base shadow
        y = 192
        while y < 212 {
            c.rect(0, y, 320, 1, brgb(60, 30, 10), (y - 192) * 3)
            y += 1
        }
        // wooden floor
        c.vgrad(212, 288, brgb(150, 98, 56), brgb(104, 64, 36))
        planks(c, 212, 288, 13, brgb(50, 28, 12), 5)
        c.rect(0, 212, 320, 2, brgb(196, 138, 86))
        c.rect(0, 214, 320, 3, brgb(40, 20, 8), 60)
        // wire waste basket
        c.poly([284, 316, 311, 291], [194, 194, 236, 236], brgb(70, 50, 40), 110)
        var k: Int = 0
        while k < 6 {
            let fx: Float = 288 + Float(k) * 5.4
            c.capsule(fx, 196, 291 + Float(k) * 3.4, 235, 0.7, brgb(170, 176, 190))
            k += 1
        }
        c.capsule(286, 208, 314, 208, 0.7, brgb(170, 176, 190))
        c.capsule(288, 222, 312, 222, 0.7, brgb(170, 176, 190))
        c.ellipse(300, 195, 17, 4, brgb(80, 60, 50), 255)
        c.ring(300, 195, 16, 1.6, brgb(200, 206, 218))
        c.disc(295, 193, 5, brgb(245, 245, 240))
        c.disc(305, 192, 4, brgb(236, 232, 220))
    }

    func roomPlay(_ c: BuddyCanvas) {
        c.vgrad(0, 212, brgb(255, 238, 176), brgb(255, 220, 150))
        var x: Int = 0
        while x < 320 {
            c.rect(x, 0, 12, 212, brgb(255, 255, 255), 40)
            x += 24
        }
        var i: Int = 0
        while i < 40 {
            let dx: Int = buddyHash(i * 3) % 320
            let dy: Int = buddyHash(i * 3 + 1) % 150
            c.disc(Float(dx), Float(dy), 3, brgb(255, 190, 160), 150)
            i += 1
        }
        c.rect(0, 160, 320, 52, brgb(150, 202, 238))
        c.rect(0, 158, 320, 4, brgb(255, 255, 255))
        x = 0
        while x < 320 {
            c.rect(x, 162, 1, 50, brgb(255, 255, 255), 60)
            x += 16
        }
        // window
        c.roundRect(194, 40, 68, 72, 6, brgb(255, 255, 255), brgb(235, 235, 235))
        c.roundRect(200, 46, 56, 60, 4, brgb(130, 205, 255), brgb(200, 236, 255))
        c.disc(236, 66, 11, brgb(255, 226, 90))
        c.rect(226, 46, 4, 60, brgb(255, 255, 255))
        c.rect(200, 74, 56, 4, brgb(255, 255, 255))
        // poster
        c.roundRect(76, 50, 52, 44, 4, brgb(255, 255, 255), brgb(250, 240, 240))
        c.star(102, 72, 15, 7, 5, -1.57, brgb(255, 210, 60))
        c.stitchRing(102, 72, 17, brgb(200, 120, 60), 24)
        // floor
        c.vgrad(212, 288, brgb(226, 170, 106), brgb(190, 132, 78))
        planks(c, 212, 288, 13, brgb(110, 70, 36), 11)
        c.rect(0, 212, 320, 2, brgb(250, 214, 160))
        c.ellipse(160, 244, 132, 20, brgb(220, 70, 80))
        c.ellipse(160, 244, 112, 16, brgb(255, 210, 90))
        c.ellipse(160, 244, 92, 12, brgb(80, 160, 230))
        c.ellipse(160, 244, 70, 8, brgb(255, 255, 255))
        // toy blocks
        self.toyBlock(c, 14, 184, 28, brgb(230, 70, 70), "A")
        self.toyBlock(c, 46, 184, 28, brgb(70, 130, 230), "B")
        self.toyBlock(c, 30, 156, 28, brgb(250, 200, 50), "C")
    }

    func toyBlock(_ c: BuddyCanvas, _ x: Int, _ y: Int, _ s: Int, _ col: UInt32, _ letter: String) {
        c.roundRect(Float(x), Float(y), Float(s), Float(s), 4, BuddyCol.shade(col, 1.15), BuddyCol.shade(col, 0.82))
        c.roundRect(Float(x + 4), Float(y + 4), Float(s - 8), Float(s - 8), 3, BuddyCol.shade(col, 0.95), BuddyCol.shade(col, 0.95))
        c.disc(Float(x + s / 2), Float(y + s / 2), 5, brgb(255, 255, 255), 230)
    }

    func roomYard(_ c: BuddyCanvas) {
        c.vgrad(0, 160, brgb(120, 200, 255), brgb(210, 238, 255))
        c.ellipse(60, 176, 130, 44, brgb(116, 196, 104))
        c.ellipse(250, 182, 140, 40, brgb(98, 180, 92))
        c.rect(0, 150, 320, 62, brgb(98, 180, 92))
        var x: Int = 0
        while x < 320 {
            c.rect(x + 1, 152, 11, 60, brgb(252, 248, 236))
            c.tri(Float(x + 1), 152, Float(x + 12), 152, Float(x + 6), 144, brgb(252, 248, 236))
            c.rect(x + 9, 152, 3, 60, brgb(210, 200, 180), 120)
            x += 14
        }
        c.rect(0, 166, 320, 5, brgb(214, 176, 120))
        c.rect(0, 190, 320, 5, brgb(214, 176, 120))
        c.rect(0, 171, 320, 2, brgb(120, 90, 50), 80)
        c.vgrad(212, 288, brgb(100, 184, 72), brgb(60, 132, 50))
        var i: Int = 0
        while i < 80 {
            let gx: Int = buddyHash(i) % 320
            let gy: Int = 214 + buddyHash(i + 99) % 70
            c.capsule(Float(gx), Float(gy + 5), Float(gx + 2), Float(gy), 0.8, brgb(130, 210, 90), 200)
            i += 1
        }
        c.rect(0, 212, 320, 2, brgb(140, 214, 100))
    }

    func roomBeach(_ c: BuddyCanvas) {
        c.vgrad(0, 116, brgb(106, 204, 255), brgb(196, 238, 255))
        c.disc(262, 56, 34, brgb(255, 240, 160), 90)
        c.disc(262, 56, 22, brgb(255, 232, 110))
        c.vgrad(116, 152, brgb(70, 176, 226), brgb(34, 132, 202))
        c.vgrad(152, 212, brgb(246, 226, 172), brgb(230, 200, 144))
        c.vgrad(212, 288, brgb(222, 190, 134), brgb(190, 156, 102))
        var i: Int = 0
        while i < 90 {
            let gx: Int = buddyHash(i) % 320
            let gy: Int = 156 + buddyHash(i + 7) % 130
            c.disc(Float(gx), Float(gy), 1.2, brgb(190, 160, 108), 160)
            i += 1
        }
        // sandcastle
        let sand: UInt32 = brgb(222, 186, 124)
        let sandD: UInt32 = brgb(190, 152, 94)
        c.rect(118, 176, 84, 36, sand)
        c.rect(108, 158, 24, 54, sand)
        c.rect(188, 158, 24, 54, sand)
        c.rect(146, 146, 28, 66, sand)
        c.rect(118, 176, 84, 3, sandD)
        var k: Int = 0
        while k < 3 {
            c.rect(108 + k * 9, 152, 6, 8, sand)
            c.rect(188 + k * 9, 152, 6, 8, sand)
            k += 1
        }
        c.rect(146, 140, 6, 8, sand)
        c.rect(154, 140, 6, 8, sand)
        c.rect(162, 140, 6, 8, sand)
        c.ellipse(160, 212, 12, 16, brgb(120, 86, 50))
        c.rect(148, 160, 24, 3, sandD)
        c.capsule(160, 146, 160, 120, 1.2, brgb(140, 100, 60))
        c.tri(161, 120, 161, 132, 176, 126, brgb(230, 60, 70))
        c.stitch(110, 195, 130, 195, sandD, 4)
        // umbrella
        c.capsule(48, 150, 56, 212, 1.8, brgb(240, 240, 240))
        c.poly([22, 30, 48, 74, 80, 88], [148, 130, 118, 122, 134, 150], brgb(240, 80, 90))
        c.poly([48, 74, 80, 62, 54], [118, 122, 134, 150, 148], brgb(255, 255, 255), 255)
        c.rect(0, 212, 320, 2, brgb(246, 226, 172))
    }

    func roomSpace(_ c: BuddyCanvas) {
        c.vgrad(0, 288, brgb(8, 10, 40), brgb(44, 22, 84))
        c.disc(70, 80, 80, brgb(150, 60, 200), 22)
        c.disc(260, 140, 70, brgb(60, 90, 220), 22)
        var i: Int = 0
        while i < 150 {
            let sx: Int = buddyHash(i) % 320
            let sy: Int = buddyHash(i + 31) % 212
            let br: Int = 120 + buddyHash(i + 5) % 135
            let big: Bool = buddyHash(i + 9) % 9 == 0
            c.rect(sx, sy, big ? 2 : 1, big ? 2 : 1, brgb(br, br, 255), 255)
            i += 1
        }
        // ringed planet
        c.ellipse(86, 96, 66, 13, brgb(236, 214, 160), 200)
        c.disc(86, 96, 36, brgb(236, 150, 84))
        c.disc(76, 86, 30, brgb(246, 176, 104), 120)
        c.ellipse(86, 100, 36, 7, brgb(200, 110, 60), 120)
        c.disc(250, 78, 20, brgb(90, 170, 240))
        c.disc(244, 72, 12, brgb(130, 200, 255), 130)
        c.disc(206, 126, 10, brgb(190, 190, 205))
        c.disc(203, 124, 2.5, brgb(150, 150, 170))
        c.disc(209, 129, 2, brgb(150, 150, 170))
        // station floor
        c.vgrad(212, 288, brgb(96, 106, 140), brgb(48, 54, 84))
        var x: Int = 0
        while x < 320 {
            c.rect(x, 214, 1, 74, brgb(20, 24, 48), 140)
            c.disc(Float(x + 4), 222, 1.4, brgb(200, 210, 240))
            x += 40
        }
        c.rect(0, 226, 320, 1, brgb(20, 24, 48), 140)
        c.rect(0, 212, 320, 2, brgb(120, 220, 255))
        c.rect(0, 214, 320, 2, brgb(80, 180, 240), 120)
    }

    func roomCandy(_ c: BuddyCanvas) {
        c.vgrad(0, 212, brgb(255, 190, 224), brgb(255, 234, 248))
        self.lollipop(c, 52, 118, 28, brgb(255, 100, 150), brgb(255, 240, 246))
        self.lollipop(c, 268, 96, 32, brgb(120, 210, 255), brgb(255, 255, 255))
        self.lollipop(c, 170, 150, 20, brgb(160, 230, 150), brgb(255, 250, 220))
        var i: Int = 0
        while i < 30 {
            let sy: Float = 8 + Float(i) * 6.2
            let alt: Bool = i % 2 == 0
            c.capsule(112 + Float(i % 3), sy, 113, sy + 8, 4, alt ? brgb(240, 60, 80) : brgb(255, 255, 255))
            i += 1
        }
        c.capsule(116, 8, 130, 4, 3.5, brgb(240, 60, 80))
        // gumdrop hills
        var x: Int = 0
        while x < 340 {
            let cols: [UInt32] = [brgb(255, 150, 190), brgb(150, 220, 170), brgb(255, 220, 120), brgb(170, 190, 255)]
            let col: UInt32 = cols[(x / 40) % 4]
            c.ellipse(Float(x), 214, 30, 22 + Float(buddyHash(x) % 10), col)
            c.ellipse(Float(x) - 8, 200, 6, 3, brgb(255, 255, 255), 120)
            x += 40
        }
        c.vgrad(212, 288, brgb(255, 150, 196), brgb(236, 110, 170))
        x = 0
        while x < 340 {
            c.rotRect(Float(x), 250, 10, 60, 0.5, brgb(255, 255, 255), 70)
            x += 40
        }
        c.rect(0, 212, 320, 3, brgb(255, 255, 255), 200)
    }

    func lollipop(_ c: BuddyCanvas, _ x: Float, _ y: Float, _ r: Float, _ col: UInt32, _ col2: UInt32) {
        c.capsule(x, y, x + 3, 212, 3, brgb(255, 255, 255))
        c.disc(x, y, r, col)
        var k: Int = 1
        while k < 6 {
            let rr: Float = r - Float(k) * (r / 6.5)
            c.ring(x, y, rr, r / 13, (k % 2 == 0) ? col : col2)
            k += 1
        }
        c.disc(x - r * 0.35, y - r * 0.4, r * 0.18, brgb(255, 255, 255), 160)
    }

    func roomRoof(_ c: BuddyCanvas) {
        c.vgrad(0, 212, brgb(52, 34, 104), brgb(255, 150, 120))
        var i: Int = 0
        while i < 40 {
            let sx: Int = buddyHash(i) % 320
            let sy: Int = buddyHash(i + 13) % 90
            c.rect(sx, sy, 1, 1, brgb(255, 255, 255), 200)
            i += 1
        }
        c.disc(244, 52, 18, brgb(255, 244, 200))
        c.disc(238, 48, 16, brgb(52, 40, 108), 70)
        // two layers of city
        var layer: Int = 0
        while layer < 2 {
            var x: Int = -10
            while x < 330 {
                let seed: Int = x * 3 + layer * 100
                let bw: Int = 22 + buddyHash(seed) % 16
                let bh: Int = (layer == 0 ? 60 : 40) + buddyHash(seed + 1) % 56
                let tone: Int = layer == 0 ? 44 : 78
                let col: UInt32 = brgb(tone, tone - 10, tone + 34)
                c.rect(x, 190 - bh, bw, bh + 24, col)
                var wy: Int = 190 - bh + 6
                while wy < 184 {
                    var wx: Int = x + 4
                    while wx < x + bw - 4 {
                        if buddyHash(wx * 7 + wy * 13 + layer) % 3 != 0 {
                            c.rect(wx, wy, 3, 4, brgb(255, 226, 130), layer == 0 ? 230 : 150)
                        }
                        wx += 7
                    }
                    wy += 10
                }
                x += bw + 2
            }
            layer += 1
        }
        // parapet and floor
        c.rect(0, 190, 320, 22, brgb(124, 112, 148))
        c.rect(0, 190, 320, 4, brgb(168, 156, 190))
        var x2: Int = 0
        while x2 < 320 {
            c.rect(x2, 194, 1, 18, brgb(70, 60, 96), 120)
            x2 += 24
        }
        c.vgrad(212, 288, brgb(116, 108, 134), brgb(70, 64, 92))
        planks(c, 212, 288, 18, brgb(40, 34, 60), 21)
        c.rect(0, 212, 320, 2, brgb(190, 180, 210))
    }

    // MARK: Dynamic room decoration

    func renderRoomDynamic(_ c: BuddyCanvas) {
        let t: Float = Float(frameN)
        let room: Int = (phase == 0) ? 0 : selRoom
        switch room {
        case 2:
            var i: Int = 0
            while i < 3 {
                let cxp: Float = (Float(i) * 140 + t * 0.15).truncatingRemainder(dividingBy: 400) - 40
                let cyp: Float = 40 + Float(i) * 22
                c.ellipse(cxp, cyp, 28, 9, brgb(255, 255, 255), 230)
                c.ellipse(cxp - 10, cyp - 7, 14, 9, brgb(255, 255, 255), 230)
                c.ellipse(cxp + 10, cyp - 5, 16, 10, brgb(255, 255, 255), 230)
                i += 1
            }
            let xs: [Float] = [24, 196, 292]
            for sx in xs {
                let sway: Float = sin(t * 0.04 + sx) * 3
                c.capsule(sx, 212, sx + sway, 168, 2.2, brgb(70, 150, 60))
                c.disc(sx + sway, 164, 12, brgb(255, 206, 40))
                c.disc(sx + sway, 164, 6, brgb(110, 70, 30))
                c.ellipse(sx + 8, 192, 9, 3, brgb(70, 150, 60))
            }
        case 3:
            var i: Int = 0
            while i < 9 {
                let wx: Float = (Float(i) * 44 + t * 0.6).truncatingRemainder(dividingBy: 380) - 30
                let wy: Float = 150 + sin(t * 0.05 + Float(i)) * 3
                c.ellipse(wx, wy, 22, 4, brgb(255, 255, 255), 200)
                c.ellipse(wx + 14, 128 + sin(t * 0.04 + Float(i) * 2) * 2, 12, 2, brgb(255, 255, 255), 110)
                i += 1
            }
            let cxp: Float = (t * 0.1).truncatingRemainder(dividingBy: 400) - 40
            c.ellipse(cxp, 34, 26, 8, brgb(255, 255, 255), 220)
            c.ellipse(cxp + 12, 28, 14, 8, brgb(255, 255, 255), 220)
        case 4:
            var i: Int = 0
            while i < 14 {
                let sx: Int = buddyHash(i + 500) % 320
                let sy: Int = buddyHash(i + 531) % 200
                let ph: Float = sin(t * 0.08 + Float(i) * 1.7)
                if ph > 0.3 {
                    let a: Int = Int(ph * 255)
                    c.capsule(Float(sx) - 3, Float(sy), Float(sx) + 3, Float(sy), 0.6, brgb(255, 255, 255), a)
                    c.capsule(Float(sx), Float(sy) - 3, Float(sx), Float(sy) + 3, 0.6, brgb(255, 255, 255), a)
                }
                i += 1
            }
            let px0: Float = (t * 0.12).truncatingRemainder(dividingBy: 380) - 30
            c.disc(px0, 52 + sin(t * 0.02) * 6, 9, brgb(255, 130, 170))
            c.ellipse(px0, 52 + sin(t * 0.02) * 6, 15, 3, brgb(255, 220, 240), 200)
            let ux: Float = (t * 0.7).truncatingRemainder(dividingBy: 1100) - 60
            if ux < 380 {
                c.ellipse(ux, 120, 14, 5, brgb(190, 200, 220))
                c.ellipse(ux, 115, 7, 6, brgb(130, 230, 250), 220)
                c.disc(ux - 8, 121, 1.5, brgb(255, 240, 120))
                c.disc(ux + 8, 121, 1.5, brgb(255, 240, 120))
            }
        case 5:
            var i: Int = 0
            while i < 12 {
                let sx: Float = Float(buddyHash(i + 60) % 320)
                let sy: Float = 30 + Float(buddyHash(i + 70) % 170) + sin(t * 0.04 + Float(i)) * 4
                let ph: Float = sin(t * 0.07 + Float(i) * 1.3)
                if ph > 0 {
                    c.star(sx, sy, 3.5 * ph + 1, 1.2, 4, t * 0.02, brgb(255, 255, 255), 220)
                }
                i += 1
            }
        case 6:
            // string lights
            var k: Int = 0
            while k < 14 {
                let u: Float = Float(k) / 13
                let lx: Float = u * 320
                let ly: Float = 30 + sin(u * 3.14159) * 22
                let on: Bool = (frameN / 20 + k) % 3 != 0
                let col: UInt32 = BuddyCol.hsv(Float(k) * 0.13, 0.7, 1)
                c.capsule(lx, ly - 3, lx, ly, 0.6, brgb(40, 40, 50))
                c.disc(lx, ly + 3, on ? 4 : 3, col, on ? 255 : 120)
                k += 1
            }
            // balloons
            let bxs: [Float] = [20, 300, 270]
            var b: Int = 0
            while b < bxs.count {
                let by: Float = 80 + sin(t * 0.03 + Float(b) * 2) * 8
                let col: UInt32 = BuddyCol.hsv(Float(b) * 0.3 + 0.05, 0.6, 1)
                c.capsule(bxs[b], by + 14, bxs[b] - 2, 160, 0.6, brgb(220, 220, 230), 200)
                c.ellipse(bxs[b], by, 11, 14, col)
                c.disc(bxs[b] - 4, by - 5, 3, brgb(255, 255, 255), 140)
                b += 1
            }
        default:
            break
        }
    }

    // MARK: Props, pads, wheels

    func drawProps(_ c: BuddyCanvas) {
        var k: Int = 0
        while k < props.count {
            let p: BuddyProp = props[k]
            switch p.kind {
            case 0: drawSpringPad(c, p)
            case 1: drawCloudPad(c, p)
            case 2: drawBell(c, p)
            case 3: drawPitBack(c, p)
            default: drawGummy(c, p, k)
            }
            k += 1
        }
    }

    func drawPropsFront(_ c: BuddyCanvas) {
        var k: Int = 0
        while k < props.count {
            if props[k].kind == 3 { drawPitFront(c, props[k]) }
            k += 1
        }
    }

    func drawSpringPad(_ c: BuddyCanvas, _ p: BuddyProp) {
        let x0: Float = p.x - p.w * 0.5
        let sag: Float = p.anim * 5
        let top: Float = p.y + sag
        c.roundRect(x0 - 2, floorY - 4, p.w + 4, 5, 2, brgb(70, 70, 90), brgb(50, 50, 70))
        var i: Int = 0
        while i < 4 {
            let fx: Float = x0 + 8 + Float(i) * (p.w - 16) / 3
            c.capsule(fx - 3, top + 4, fx + 3, floorY - 8, 1.3, brgb(230, 232, 244))
            c.capsule(fx + 3, top + 4, fx - 3, floorY - 8, 1.3, brgb(190, 194, 210))
            i += 1
        }
        c.roundRect(x0, top, p.w, 6, 3, brgb(255, 120, 130), brgb(220, 60, 80))
        c.rect(Int(x0) + 4, Int(top) + 1, Int(p.w) - 8, 1, brgb(255, 255, 255), 140)
    }

    func cloudTint() -> UInt32 {
        if selRoom == 4 { return brgb(220, 200, 255) }
        if selRoom == 5 { return brgb(255, 230, 245) }
        return brgb(255, 255, 255)
    }

    func drawCloudPad(_ c: BuddyCanvas, _ p: BuddyProp) {
        let sag: Float = p.anim * 4
        let y: Float = p.y + sag
        let col: UInt32 = cloudTint()
        let shade: UInt32 = BuddyCol.shade(col, 0.86)
        c.ellipse(p.x, y + 12, p.w * 0.5, 7, shade)
        c.disc(p.x - p.w * 0.28, y + 8, 10, col)
        c.disc(p.x - p.w * 0.1, y + 6, 13, col)
        c.disc(p.x + p.w * 0.14, y + 7, 12, col)
        c.disc(p.x + p.w * 0.32, y + 9, 9, col)
        c.ellipse(p.x, y + 6, p.w * 0.46, 7, col)
        c.ellipse(p.x, y + 2, p.w * 0.3, 3, brgb(255, 255, 255), 120)
    }

    func drawGummy(_ c: BuddyCanvas, _ p: BuddyProp, _ k: Int) {
        let cols: [UInt32] = [brgb(255, 120, 170), brgb(120, 220, 160), brgb(255, 210, 90)]
        let col: UInt32 = cols[k % 3]
        let wob: Float = p.anim * 4
        c.roundRect(p.x - p.w * 0.5, p.y + wob, p.w, p.h + 2, 7, BuddyCol.shade(col, 1.12), BuddyCol.shade(col, 0.88), 235)
        c.roundRect(p.x - p.w * 0.5 + 4, p.y + 2 + wob, p.w - 8, 3, 1.5, brgb(255, 255, 255), brgb(255, 255, 255), 150)
        c.disc(p.x - p.w * 0.3, p.y + 9, 1.6, brgb(255, 255, 255), 120)
    }

    func drawBell(_ c: BuddyCanvas, _ p: BuddyProp) {
        let bx: Float = p.x + p.h * sin(p.ang)
        let by: Float = p.y + p.h * cos(p.ang)
        c.capsule(p.x, p.y, bx, by - 8, 1.2, brgb(120, 90, 60))
        c.disc(p.x, p.y, 3, brgb(110, 80, 50))
        if p.anim > 0.2 {
            c.ring(bx, by, 14 + (1 - p.anim) * 16, 2, brgb(255, 240, 150), Int(p.anim * 200))
        }
        c.disc(bx, by - 2, 9, brgb(255, 205, 60))
        c.poly([bx - 9, bx + 9, bx + 13, bx - 13], [by - 2, by - 2, by + 8, by + 8], brgb(244, 180, 40))
        c.rect(Int(bx) - 12, Int(by) + 7, 24, 2, brgb(200, 140, 30))
        c.disc(bx, by + 10, 3, brgb(150, 100, 40))
        c.disc(bx - 3, by - 5, 2.5, brgb(255, 250, 210), 200)
    }

    func pitBallColor(_ i: Int) -> UInt32 {
        let cols: [UInt32] = [brgb(255, 90, 100), brgb(255, 205, 70), brgb(90, 190, 255), brgb(120, 220, 130), brgb(190, 130, 255)]
        return cols[buddyHash(i) % 5]
    }

    func drawPitBack(_ c: BuddyCanvas, _ p: BuddyProp) {
        let x0: Float = p.x - p.w * 0.5
        c.roundRect(x0 - 3, p.y - 2, p.w + 6, floorY - p.y + 4, 4, brgb(90, 120, 200), brgb(60, 80, 160))
        let rows: Int = 2
        var r: Int = 0
        while r < rows {
            var i: Int = 0
            let n: Int = Int(p.w / 9)
            while i < n {
                let bx: Float = x0 + 5 + Float(i) * 9 + Float(r % 2) * 4
                let by: Float = p.y + 3 + Float(r) * 7 - p.anim * Float(buddyHash(i) % 5)
                c.disc(bx, by, 5.2, pitBallColor(i + r * 17))
                c.disc(bx - 1.5, by - 1.5, 1.4, brgb(255, 255, 255), 150)
                i += 1
            }
            r += 1
        }
    }

    func drawPitFront(_ c: BuddyCanvas, _ p: BuddyProp) {
        let x0: Float = p.x - p.w * 0.5
        var i: Int = 0
        let n: Int = Int(p.w / 9)
        while i < n {
            let bx: Float = x0 + 5 + Float(i) * 9
            let by: Float = p.y + 14 - p.anim * Float(buddyHash(i + 3) % 4)
            c.disc(bx, by, 5.4, pitBallColor(i + 40))
            c.disc(bx - 1.5, by - 1.5, 1.4, brgb(255, 255, 255), 150)
            i += 1
        }
        c.roundRect(x0 - 3, p.y + 15, p.w + 6, floorY - p.y - 13, 4, brgb(120, 150, 235), brgb(70, 96, 190))
        c.rect(Int(x0), Int(p.y) + 17, Int(p.w), 2, brgb(255, 255, 255), 110)
        c.stitch(x0 + 2, p.y + 23, x0 + p.w - 2, p.y + 23, brgb(230, 240, 255), 4)
    }

    func drawPads(_ c: BuddyCanvas) {
        var k: Int = 0
        while k < pads.count {
            let p: BuddyPad = pads[k]
            if p.life < 50 && (p.life / 4) % 2 == 0 {
                k += 1
                continue
            }
            let x0: Float = p.x - p.w * 0.5
            let sag: Float = p.anim * 4
            switch p.kind {
            case 0:
                let legLen: Float = min(floorY - p.y, 36)
                c.capsule(x0 + 6, p.y + 4, x0 + 3, p.y + legLen, 2, brgb(150, 156, 170))
                c.capsule(x0 + p.w - 6, p.y + 4, x0 + p.w - 3, p.y + legLen, 2, brgb(150, 156, 170))
                var i: Int = 0
                while i < 6 {
                    let fx: Float = x0 + 4 + Float(i) * (p.w - 8) / 5
                    c.capsule(fx, p.y + 2, fx, p.y + 8, 1, brgb(220, 224, 236))
                    i += 1
                }
                c.roundRect(x0, p.y + sag, p.w, 7, 3.5, brgb(90, 160, 255), brgb(50, 100, 210))
                c.roundRect(x0 + 3, p.y + 1 + sag, p.w - 6, 2, 1, brgb(200, 230, 255), brgb(200, 230, 255), 200)
            case 1:
                let ang: Float = -p.dir * 0.2 + p.dir * 0.5 * p.anim
                c.roundRect(x0 + 8, floorY - 5, p.w - 16, 5, 2, brgb(110, 80, 50), brgb(90, 60, 40))
                var i: Int = 0
                while i < 3 {
                    let yy: Float = floorY - 6 - Float(i) * 3
                    c.capsule(p.x - 8, yy, p.x + 8, yy - 2, 1.2, brgb(230, 232, 244))
                    i += 1
                }
                c.rotRect(p.x, p.y + 4, p.w * 0.5, 3.5, ang, brgb(255, 170, 60))
                c.rotRect(p.x + p.dir * p.w * 0.3, p.y + 2, 6, 2, ang, brgb(255, 230, 150))
            case 2:
                let tilt: Float = sin(Float(frameN) * 0.09) * 0.06 + p.dir * p.anim * 0.35
                c.poly([p.x - 10, p.x + 10, p.x], [floorY, floorY, p.y + 10], brgb(120, 130, 160))
                c.rotRect(p.x, p.y + 6, p.w * 0.5, 3.5, tilt, brgb(96, 200, 170))
                let ex: Float = cos(tilt) * p.w * 0.46
                let ey: Float = sin(tilt) * p.w * 0.46
                c.disc(p.x - ex, p.y + 6 - ey, 5, brgb(255, 200, 70))
                c.disc(p.x + ex, p.y + 6 + ey, 5, brgb(255, 200, 70))
                c.disc(p.x, p.y + 6, 3, brgb(255, 255, 255))
            case 3:
                c.roundRect(x0, p.y, p.w, 8, 4, brgb(70, 76, 92), brgb(40, 44, 58))
                let n: Int = Int(p.w / 8)
                var i: Int = 0
                while i < n {
                    var fx: Float = (Float(i) * 8 + p.phase).truncatingRemainder(dividingBy: p.w - 8)
                    if fx < 0 { fx += p.w - 8 }
                    let px0: Float = x0 + 4 + fx
                    c.tri(px0, p.y + 1.5, px0 + 3 * p.dir, p.y + 4, px0, p.y + 6.5, brgb(255, 214, 80))
                    i += 1
                }
                c.disc(x0 + 2, p.y + 4, 5, brgb(255, 200, 60))
                c.disc(x0 + p.w - 2, p.y + 4, 5, brgb(255, 200, 60))
            default:
                let fired: Float = p.dir * 0.5
                let cocked: Float = -p.dir * 0.9
                let ang: Float = fired + (cocked - fired) * (1 - p.anim)
                let px1: Float = p.x
                let py1: Float = p.y + 10
                c.roundRect(x0, floorY - 8, p.w, 8, 3, brgb(150, 100, 60), brgb(110, 70, 40))
                c.disc(x0 + 8, floorY - 2, 5, brgb(60, 50, 50))
                c.disc(x0 + p.w - 8, floorY - 2, 5, brgb(60, 50, 50))
                let tx: Float = px1 + sin(ang) * 36 * p.dir * -1
                let ty: Float = py1 - cos(ang) * 30
                c.capsule(px1, py1, tx, ty, 3, brgb(170, 120, 70))
                c.disc(tx, ty, 8, brgb(220, 90, 70))
                c.disc(tx, ty, 5, brgb(255, 140, 120))
                c.disc(px1, py1, 4, brgb(240, 230, 200))
            }
            k += 1
        }
    }

    func drawWheels(_ c: BuddyCanvas) {
        var k: Int = 0
        while k < wheels.count {
            let w: BuddyWheel = wheels[k]
            var a: Int = 235
            if w.life < 40 { a = w.life * 235 / 40 }
            let n: Int = 8
            var i: Int = 0
            while i < n {
                let a0: Float = w.rot + Float(i) * 2 * Float.pi / Float(n)
                let a1: Float = a0 + Float.pi / Float(n)
                let a2: Float = a0 + 2 * Float.pi / Float(n)
                let col: UInt32 = BuddyCol.hsv(Float(i) / Float(n), 0.55, 1)
                c.poly([w.x, w.x + cos(a0) * w.r, w.x + cos(a1) * w.r, w.x + cos(a2) * w.r],
                       [w.y, w.y + sin(a0) * w.r, w.y + sin(a1) * w.r, w.y + sin(a2) * w.r], col, a)
                i += 1
            }
            c.ring(w.x, w.y, w.r, 3, brgb(255, 255, 255), a)
            c.disc(w.x, w.y, 6, brgb(255, 255, 255), a)
            c.disc(w.x, w.y, 3, brgb(255, 120, 160), a)
            k += 1
        }
    }

    // MARK: Balls

    func drawBalls(_ c: BuddyCanvas) {
        var k: Int = 0
        while k < balls.count {
            let b: BuddyBall = balls[k]
            let rx: Float = b.r * (1 + b.sq)
            let ry: Float = b.r * (1 - b.sq)
            c.ellipse(b.x, floorY + 4, b.r * 0.9, 3, brgb(0, 0, 0), 50)
            switch b.kind {
            case 1:
                c.ellipse(b.x, b.y, rx, ry, brgb(255, 255, 255))
                var i: Int = 0
                while i < 6 {
                    if i % 2 == 0 {
                        let a0: Float = b.rot + Float(i) * Float.pi / 3
                        let a1: Float = a0 + Float.pi / 6
                        let a2: Float = a0 + Float.pi / 3
                        let col: UInt32 = (i == 0) ? brgb(255, 90, 100) : ((i == 2) ? brgb(255, 205, 70) : brgb(80, 170, 255))
                        let s: Float = 0.94
                        c.poly([b.x, b.x + cos(a0) * rx * s, b.x + cos(a1) * rx * s, b.x + cos(a2) * rx * s],
                               [b.y, b.y + sin(a0) * ry * s, b.y + sin(a1) * ry * s, b.y + sin(a2) * ry * s], col)
                    }
                    i += 1
                }
                c.disc(b.x, b.y, 3, brgb(255, 255, 255))
                c.disc(b.x - rx * 0.4, b.y - ry * 0.45, rx * 0.16, brgb(255, 255, 255), 160)
            case 2:
                let f: Float = b.vx >= 0 ? 1 : -1
                c.ellipse(b.x, b.y + b.r * 0.15, rx * 1.05, ry * 0.82, brgb(255, 214, 40))
                c.disc(b.x - f * b.r * 0.9, b.y - b.r * 0.05, b.r * 0.3, brgb(255, 214, 40))
                c.disc(b.x + f * b.r * 0.55, b.y - b.r * 0.62, b.r * 0.5 * (1 + b.sq * 0.5), brgb(255, 220, 60))
                c.ellipse(b.x + f * b.r * 1.05, b.y - b.r * 0.48, b.r * 0.32, b.r * 0.15, brgb(255, 140, 40))
                c.disc(b.x + f * b.r * 0.62, b.y - b.r * 0.76, 2, brgb(30, 30, 40))
                c.disc(b.x + f * b.r * 0.58, b.y - b.r * 0.8, 0.8, brgb(255, 255, 255))
                c.ellipse(b.x - f * b.r * 0.1, b.y + b.r * 0.1, rx * 0.5, ry * 0.32, brgb(240, 180, 20))
                c.disc(b.x + f * b.r * 0.4, b.y - b.r * 0.45, 2, brgb(255, 150, 160), 150)
            default:
                c.ellipse(b.x, b.y, rx, ry, bhx(b.col))
                c.ellipse(b.x, b.y, rx * 0.8, ry * 0.8, BuddyCol.shade(bhx(b.col), 1.2))
                c.disc(b.x - b.r * 0.35, b.y - b.r * 0.35, b.r * 0.28, brgb(255, 255, 255), 190)
            }
            k += 1
        }
    }

    // MARK: Sparks, floats, bursts

    func drawSparks(_ c: BuddyCanvas) {
        var i: Int = 0
        while i < sparks.count {
            let s: BuddySpark = sparks[i]
            i += 1
            var a: Int = s.life * 255 / 18
            if a > 255 { a = 255 }
            if a < 8 { continue }
            let col: UInt32 = bhx(s.col)
            switch s.kind {
            case 0:
                c.star(s.x, s.y, s.size * 1.6, s.size * 0.7, 5, s.rot, col, a)
            case 1:
                c.rotRect(s.x, s.y, s.size, s.size * 0.55, s.rot, col, a)
            case 3:
                c.disc(s.x, s.y, s.size * 0.7, col, a)
                c.disc(s.x - 0.6, s.y - 0.6, s.size * 0.25, brgb(255, 255, 255), a / 2)
            case 4:
                c.disc(s.x, s.y, s.size, col, a)
                c.disc(s.x - s.size * 0.3, s.y - s.size * 0.3, s.size * 0.35, brgb(255, 255, 255), a)
            case 5:
                let l: Float = s.size * 1.5
                c.capsule(s.x - l, s.y, s.x + l, s.y, 0.7, col, a)
                c.capsule(s.x, s.y - l, s.x, s.y + l, 0.7, col, a)
                c.disc(s.x, s.y, s.size * 0.5, brgb(255, 255, 255), a)
            case 6:
                c.capsule(s.x, s.y + s.size, s.x + sin(s.rot) * 2, s.y + s.size + 16, 0.5, brgb(230, 230, 240), a)
                c.ellipse(s.x, s.y, s.size * 0.85, s.size * 1.05, col, a)
                c.disc(s.x - s.size * 0.3, s.y - s.size * 0.4, s.size * 0.25, brgb(255, 255, 255), a / 2)
            case 7:
                c.capsule(s.x, s.y, s.x - s.vx * 3, s.y - s.vy * 3, 1.3, col, a / 2)
            case 8:
                let r: Float = s.size
                c.disc(s.x - r * 0.5, s.y - r * 0.3, r * 0.6, col, a)
                c.disc(s.x + r * 0.5, s.y - r * 0.3, r * 0.6, col, a)
                c.tri(s.x - r * 1.05, s.y - r * 0.1, s.x + r * 1.05, s.y - r * 0.1, s.x, s.y + r * 1.2, col, a)
            case 9:
                c.ellipse(s.x, s.y, s.size * 0.9, s.size * 0.5, col, a)
            default:
                c.disc(s.x, s.y, s.size * 0.7, col, a)
            }
        }
    }

    func drawBursts(_ c: BuddyCanvas) {
        var i: Int = 0
        while i < bursts.count {
            let b: BuddyBurst = bursts[i]
            i += 1
            let u: Float = Float(b.t) / Float(max(1, b.maxT))
            let grow: Float = min(1, u * 5)
            let e: Float = 1 - (1 - grow) * (1 - grow)
            let scale: Float = 0.4 + e * 0.8 + (u > 0.7 ? (u - 0.7) * 0.3 : 0)
            var a: Int = 255
            if u > 0.75 { a = Int((1 - u) / 0.25 * 255) }
            let col: UInt32 = bhx(b.col)
            let rot: Float = Float(b.t) * 0.04
            c.star(b.x, b.y, 38 * scale + 4, 22 * scale, 10, rot, brgb(255, 255, 255), a)
            c.star(b.x, b.y, 34 * scale, 19 * scale, 10, rot, col, a)
            if a > 90 {
                let ty: Int = Int(b.y) - 5
                qtCentered(b.text, Int(b.x), ty, brgb(255, 255, 255), brgb(70, 40, 90), 2)
            }
        }
    }

    func drawFloats() {
        for f in floats {
            var s: Int = 2
            if f.text.count * 8 > 200 { s = 1 }
            let w: Int = textW(f.text, s)
            var x: Int = Int(f.x) - w / 2
            x = max(2, min(318 - w, x))
            let y: Int = Int(f.y)
            qtOutlined(f.text, x, y, bhx(f.col), brgb(60, 40, 70), s)
        }
    }

    func drawCoins(_ c: BuddyCanvas) {
        for b in coinB {
            var a: Int = 255
            if b.life < 60 { a = b.life * 255 / 60 }
            c.disc(b.x, b.y, 14, brgb(190, 240, 255), min(a, 90))
            c.ring(b.x, b.y, 13, 1.6, brgb(255, 255, 255), min(a, 190))
            if b.gold {
                drawGoldBar(c, b.x, b.y, 0.9)
            } else {
                drawCashStack(c, b.x, b.y + 1, 0.9)
            }
            c.disc(b.x - 7, b.y - 7, 2.2, brgb(255, 255, 255), min(a, 220))
        }
    }

    func drawGoldBar(_ c: BuddyCanvas, _ x: Float, _ y: Float, _ s: Float) {
        c.poly([x - 9 * s, x + 9 * s, x + 12 * s, x - 12 * s], [y - 4 * s, y - 4 * s, y + 6 * s, y + 6 * s], brgb(236, 170, 20))
        c.poly([x - 6 * s, x + 6 * s, x + 9 * s, x - 9 * s], [y - 8 * s, y - 8 * s, y - 4 * s, y - 4 * s], brgb(255, 226, 100))
        c.rect(Int(x - 9 * s), Int(y - 1 * s), Int(18 * s), max(1, Int(1.5 * s)), brgb(255, 240, 160), 200)
        c.capsule(x - 8 * s, y - 6 * s, x - 3 * s, y - 6 * s, 0.8, brgb(255, 255, 255), 200)
    }

    func drawCashStack(_ c: BuddyCanvas, _ x: Float, _ y: Float, _ s: Float) {
        c.roundRect(x - 10 * s, y + 1 * s, 20 * s, 8 * s, 2, brgb(70, 160, 80), brgb(46, 120, 60))
        c.roundRect(x - 10 * s, y - 3 * s, 20 * s, 8 * s, 2, brgb(96, 190, 100), brgb(60, 150, 76))
        c.roundRect(x - 10 * s, y - 7 * s, 20 * s, 8 * s, 2, brgb(130, 220, 130), brgb(84, 180, 96))
        c.disc(x, y - 3 * s, 2.6 * s, brgb(200, 255, 200), 230)
        c.rect(Int(x - 7 * s), Int(y - 5 * s), max(1, Int(2 * s)), max(1, Int(2 * s)), brgb(230, 255, 230), 200)
    }
}
