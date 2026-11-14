#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// Palette slot names. Slots 0...15 come from the current region (LanternRegion.colors), slots 16...31 are shared.
enum LanternC {
    static let g0 = 0
    static let g1 = 1
    static let path = 2
    static let pathD = 3
    static let fol1 = 4
    static let fol2 = 5
    static let wood = 6
    static let stoneL = 7
    static let stoneD = 8
    static let water = 9
    static let waterL = 10
    static let accent = 11
    static let wallD = 12
    static let wallL = 13
    static let roof = 14
    static let floor2 = 15
    static let out = 16
    static let white = 17
    static let skin = 18
    static let tunic = 19
    static let brown = 20
    static let red = 21
    static let gold = 22
    static let blue = 23
    static let purple = 24
    static let orange = 25
    static let lime = 26
    static let grayL = 27
    static let grayD = 28
    static let pink = 29
    static let cyan = 30
    static let hud = 31

    static let common: [UInt32] = [
        0x181020, 0xFFFFFF, 0xF8C898, 0x28A848, 0x7A4A28, 0xE03838, 0xF8D030, 0x3070E0,
        0x9048D0, 0xF08028, 0x88D848, 0xC8C8D8, 0x686878, 0xF888B0, 0x58D8E8, 0x201830
    ]
}

enum LanternArt {
    static func palette(_ region: LanternRegion) -> [UInt16] {
        var cols: [UInt32] = region.colors
        while cols.count < 16 { cols.append(0xFF00FF) }
        if cols.count > 16 { cols = Array(cols[0..<16]) }
        cols.append(contentsOf: LanternC.common)
        return Palette.make(cols)
    }

    // MARK: Canvas helpers

    static func blank() -> Canvas {
        let c = Canvas(width: 16, height: 16)
        for i in 0..<c.pixels.count { c.pixels[i] = 255 }
        return c
    }

    static func spr(_ c: Canvas) -> Sprite {
        return Sprite(width: c.width, height: c.height, data: c.pixels)
    }

    static func tuft(_ c: Canvas, _ x: Int, _ y: Int, _ col: Int) {
        c.setPixel(x, y + 1, col)
        c.setPixel(x - 1, y, col)
        c.setPixel(x + 1, y, col)
    }

    // MARK: Ground (opaque), 8 styles x 5 variants (0...2 plain, 3...4 decoration)

    static let groundTable: [[Sprite]] = LanternArt.buildGround()

    static func buildGround() -> [[Sprite]] {
        var out: [[Sprite]] = []
        for style in 0..<8 {
            var row: [Sprite] = []
            for v in 0..<5 { row.append(makeGround(style, v)) }
            out.append(row)
        }
        return out
    }

    static func makeGround(_ style: Int, _ v: Int) -> Sprite {
        let c = Canvas(width: 16, height: 16)
        let g1 = LanternC.g1
        switch style {
        case 0, 6:
            if v == 1 { tuft(c, 4, 5, g1) }
            if v == 2 { tuft(c, 11, 10, g1); tuft(c, 3, 12, g1) }
            if v == 3 {
                c.setPixel(8, 8, LanternC.white)
                c.setPixel(7, 8, LanternC.accent); c.setPixel(9, 8, LanternC.accent)
                c.setPixel(8, 7, LanternC.accent); c.setPixel(8, 9, LanternC.accent)
                tuft(c, 3, 4, g1)
            }
            if v == 4 {
                tuft(c, 5, 10, g1); tuft(c, 11, 5, g1)
                c.setPixel(12, 12, LanternC.accent)
            }
            if style == 6 && v >= 1 {
                c.fillCircle(11, 4, 2, g1)
                if v >= 3 { c.vline(4, 9, 5, LanternC.fol2); c.setPixel(3, 9, LanternC.fol2); c.setPixel(5, 8, LanternC.fol2) }
            }
        case 1:
            if v == 1 { c.hline(3, 5, 5, g1); c.hline(9, 11, 3, g1) }
            if v == 2 { c.hline(2, 12, 4, g1); c.hline(10, 4, 3, g1) }
            if v == 3 { c.fillRect(7, 8, 3, 2, LanternC.stoneL); c.setPixel(7, 10, LanternC.stoneD) }
            if v == 4 { c.hline(4, 6, 6, g1); c.setPixel(11, 12, LanternC.accent); c.hline(2, 12, 3, g1) }
        case 2:
            if v == 1 { c.setPixel(4, 4, g1); c.setPixel(11, 9, g1) }
            if v == 2 { c.setPixel(8, 3, g1); c.setPixel(3, 11, g1); c.setPixel(13, 13, g1) }
            if v == 3 { c.setPixel(8, 7, LanternC.white); c.setPixel(7, 8, g1); c.setPixel(9, 8, g1); c.setPixel(8, 9, g1) }
            if v == 4 { c.hline(3, 5, 4, g1); c.hline(8, 11, 5, g1) }
        case 3, 7:
            if v == 1 { c.setPixel(4, 5, g1); c.setPixel(5, 5, g1); c.setPixel(12, 11, g1) }
            if v == 2 { c.setPixel(10, 3, g1); c.setPixel(3, 12, g1); c.setPixel(4, 12, g1) }
            if v == 3 { c.fillRect(6, 7, 3, 2, LanternC.stoneL); c.hline(6, 9, 3, LanternC.stoneD) }
            if v == 4 { c.setPixel(5, 5, g1); c.fillRect(10, 10, 2, 2, LanternC.stoneL) }
            if style == 7 && v == 3 { c.setPixel(8, 8, LanternC.accent) }
        case 4:
            let xs1 = [5, 11, 3, 9, 7]
            let xs2 = [12, 4, 9, 2, 13]
            c.hline(0, 7, 16, g1)
            c.hline(0, 15, 16, g1)
            c.vline(xs1[v % 5], 0, 7, g1)
            c.vline(xs2[v % 5], 8, 7, g1)
        default:
            c.hline(0, 15, 16, LanternC.floor2)
            c.vline(15, 0, 16, LanternC.floor2)
            if v == 1 { c.setPixel(4, 4, g1); c.setPixel(5, 4, g1) }
            if v == 2 { c.line(3, 10, 7, 13, g1) }
            if v == 3 {
                c.line(8, 3, 13, 8, LanternC.floor2); c.line(13, 8, 8, 13, LanternC.floor2)
                c.line(8, 13, 3, 8, LanternC.floor2); c.line(3, 8, 8, 3, LanternC.floor2)
            }
            if v == 4 { c.setPixel(10, 5, g1); c.setPixel(11, 6, g1); c.setPixel(5, 11, g1) }
        }
        return LanternArt.spr(c)
    }

    static let pathTiles: [Sprite] = LanternArt.buildPath()

    static func buildPath() -> [Sprite] {
        var out: [Sprite] = []
        for v in 0..<3 {
            let c = Canvas(width: 16, height: 16)
            c.fillRect(0, 0, 16, 16, LanternC.path)
            if v == 0 { c.setPixel(3, 4, LanternC.pathD); c.setPixel(10, 9, LanternC.pathD); c.setPixel(6, 13, LanternC.pathD) }
            if v == 1 { c.hline(2, 6, 3, LanternC.pathD); c.setPixel(12, 12, LanternC.pathD) }
            if v == 2 { c.setPixel(12, 3, LanternC.pathD); c.setPixel(4, 10, LanternC.pathD); c.setPixel(5, 10, LanternC.pathD) }
            out.append(LanternArt.spr(c))
        }
        return out
    }

    // MARK: Walls (opaque), 3 styles

    static let wallTiles: [Sprite] = LanternArt.buildWalls()

    static func buildWalls() -> [Sprite] {
        var out: [Sprite] = []
        for style in 0..<3 {
            let c = Canvas(width: 16, height: 16)
            if style == 2 {
                c.fillRect(0, 0, 16, 16, LanternC.wallD)
                var x = 3
                while x < 16 { c.vline(x, 0, 14, LanternC.wallL); x += 4 }
                c.fillRect(0, 14, 16, 2, LanternC.wood)
                c.hline(0, 0, 16, LanternC.out)
            } else {
                let base = style == 0 ? LanternC.stoneD : LanternC.wallD
                let hi = style == 0 ? LanternC.stoneL : LanternC.wallL
                c.fillRect(0, 0, 16, 16, base)
                c.fillRect(1, 1, 6, 6, hi); c.fillRect(9, 1, 6, 6, hi)
                c.fillRect(1, 9, 2, 6, hi); c.fillRect(5, 9, 6, 6, hi); c.fillRect(13, 9, 2, 6, hi)
                c.hline(1, 6, 6, base); c.hline(9, 6, 6, base)
                c.hline(5, 14, 6, base)
            }
            out.append(LanternArt.spr(c))
        }
        return out
    }

    // MARK: Water and magma (opaque, 2 frames)

    static let waterFrames: [Sprite] = LanternArt.buildWater(false)
    static let magmaFrames: [Sprite] = LanternArt.buildWater(true)

    static func buildWater(_ lava: Bool) -> [Sprite] {
        var out: [Sprite] = []
        for f in 0..<2 {
            let c = Canvas(width: 16, height: 16)
            let base = lava ? LanternC.roof : LanternC.water
            let hi = lava ? LanternC.accent : LanternC.waterL
            c.fillRect(0, 0, 16, 16, base)
            let o = f * 4
            c.hline(2 + o, 3, 4, hi); c.hline(9 - o, 8, 5, hi); c.hline(3 + o, 13, 4, hi)
            if lava { c.setPixel(12, 3 + f, LanternC.gold); c.setPixel(4, 10 - f, LanternC.gold) }
            out.append(LanternArt.spr(c))
        }
        return out
    }

    // MARK: Overlays (transparent 16x16)

    static let trees: [Sprite] = [LanternArt.treeRound(), LanternArt.treePine(), LanternArt.treeCactus(), LanternArt.treeSpire()]

    static func treeRound() -> Sprite {
        let c = LanternArt.blank()
        c.fillRect(6, 10, 4, 6, LanternC.out)
        c.fillRect(7, 10, 2, 6, LanternC.wood)
        c.fillCircle(8, 7, 7, LanternC.out)
        c.fillCircle(8, 7, 6, LanternC.fol1)
        c.fillCircle(7, 6, 4, LanternC.fol2)
        c.setPixel(5, 4, LanternC.white); c.setPixel(6, 3, LanternC.white)
        return LanternArt.spr(c)
    }

    static func treePine() -> Sprite {
        let c = LanternArt.blank()
        c.fillRect(7, 12, 2, 4, LanternC.wood)
        for tier in 0..<3 {
            let y0 = tier * 4
            for row in 0..<6 {
                var w = 2 + row * 2
                if w > 14 { w = 14 }
                let x0 = 8 - w / 2
                c.hline(x0, y0 + row, w, LanternC.fol1)
                c.setPixel(x0, y0 + row, LanternC.out)
                c.setPixel(x0 + w - 1, y0 + row, LanternC.out)
                if w > 4 { c.hline(x0 + 1, y0 + row, w / 3, LanternC.fol2) }
            }
            c.hline(2, y0 + 5, 12, LanternC.out)
        }
        c.setPixel(8, 0, LanternC.white)
        return LanternArt.spr(c)
    }

    static func treeCactus() -> Sprite {
        let c = LanternArt.blank()
        c.fillRect(5, 1, 6, 15, LanternC.out)
        c.fillRect(6, 2, 4, 13, LanternC.fol2)
        c.vline(9, 2, 13, LanternC.fol1)
        c.fillRect(1, 5, 5, 5, LanternC.out)
        c.fillRect(2, 6, 3, 3, LanternC.fol2)
        c.fillRect(1, 2, 3, 5, LanternC.out)
        c.fillRect(2, 3, 1, 3, LanternC.fol2)
        c.fillRect(10, 7, 5, 4, LanternC.out)
        c.fillRect(11, 8, 3, 2, LanternC.fol2)
        c.setPixel(8, 1, LanternC.accent); c.setPixel(7, 1, LanternC.accent)
        return LanternArt.spr(c)
    }

    static func treeSpire() -> Sprite {
        let c = LanternArt.blank()
        c.fillRect(6, 4, 4, 12, LanternC.out)
        c.fillRect(7, 5, 2, 10, LanternC.fol1)
        c.line(7, 8, 2, 3, LanternC.out); c.line(8, 8, 2, 4, LanternC.fol1)
        c.line(9, 6, 14, 1, LanternC.out); c.line(8, 6, 13, 2, LanternC.fol1)
        c.line(9, 10, 14, 7, LanternC.out); c.line(8, 10, 13, 8, LanternC.fol2)
        c.setPixel(8, 3, LanternC.fol2); c.setPixel(8, 2, LanternC.out)
        return LanternArt.spr(c)
    }

    static let bush: Sprite = {
        let c = LanternArt.blank()
        c.fillCircle(8, 9, 6, LanternC.out)
        c.fillCircle(8, 9, 5, LanternC.fol2)
        c.fillCircle(10, 11, 3, LanternC.fol1)
        c.fillCircle(6, 7, 2, LanternC.fol2)
        c.setPixel(5, 6, LanternC.white)
        c.setPixel(11, 7, LanternC.accent); c.setPixel(6, 11, LanternC.accent)
        return LanternArt.spr(c)
    }()

    static let rock: Sprite = {
        let c = LanternArt.blank()
        c.fillCircle(8, 9, 7, LanternC.out)
        c.fillCircle(8, 9, 6, LanternC.stoneL)
        c.fillRect(8, 10, 6, 4, LanternC.stoneD)
        c.fillRect(4, 5, 3, 2, LanternC.white)
        c.hline(7, 9, 3, LanternC.stoneD)
        return LanternArt.spr(c)
    }()

    static let thorn: Sprite = {
        let c = LanternArt.blank()
        c.line(1, 14, 8, 2, LanternC.out); c.line(14, 14, 8, 2, LanternC.out)
        c.line(2, 8, 14, 9, LanternC.out); c.line(4, 14, 12, 3, LanternC.fol1)
        c.line(11, 14, 4, 3, LanternC.fol1); c.line(2, 12, 14, 12, LanternC.fol1)
        c.setPixel(8, 2, LanternC.red); c.setPixel(3, 8, LanternC.red); c.setPixel(13, 9, LanternC.red); c.setPixel(8, 12, LanternC.red)
        c.setPixel(6, 6, LanternC.fol2); c.setPixel(10, 6, LanternC.fol2)
        return LanternArt.spr(c)
    }()

    static let hole: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(1, 1, 14, 14, LanternC.out)
        c.fillRect(3, 3, 10, 10, LanternC.hud)
        c.hline(1, 15, 14, LanternC.stoneD)
        c.setPixel(2, 2, LanternC.stoneL)
        return LanternArt.spr(c)
    }()

    static let crack: Sprite = {
        let c = LanternArt.blank()
        c.line(2, 1, 6, 6, LanternC.out); c.line(6, 6, 4, 9, LanternC.out); c.line(4, 9, 9, 14, LanternC.out)
        c.line(12, 2, 9, 7, LanternC.out); c.line(9, 7, 13, 11, LanternC.out)
        c.setPixel(7, 6, LanternC.white)
        return LanternArt.spr(c)
    }()

    static let doorway: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(1, 2, 14, 14, LanternC.stoneL)
        c.fillCircle(8, 6, 6, LanternC.stoneL)
        c.fillRect(2, 6, 12, 10, LanternC.out)
        c.fillCircle(8, 6, 5, LanternC.out)
        c.fillRect(4, 8, 8, 8, LanternC.hud)
        c.fillCircle(8, 7, 3, LanternC.hud)
        return LanternArt.spr(c)
    }()

    static let stairs: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(1, 1, 14, 14, LanternC.out)
        for i in 0..<4 {
            c.fillRect(2, 2 + i * 3, 12, 2, i % 2 == 0 ? LanternC.stoneL : LanternC.stoneD)
        }
        return LanternArt.spr(c)
    }()

    static let houseDoor: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(2, 1, 12, 15, LanternC.out)
        c.fillRect(3, 2, 10, 14, LanternC.wood)
        c.vline(8, 2, 14, LanternC.out)
        c.fillRect(6, 8, 2, 2, LanternC.gold)
        c.fillRect(10, 8, 2, 2, LanternC.gold)
        return LanternArt.spr(c)
    }()

    static func lockDoor(_ big: Bool) -> Sprite {
        let c = LanternArt.blank()
        c.fillRect(0, 0, 16, 16, LanternC.out)
        c.fillRect(1, 1, 14, 14, big ? LanternC.red : LanternC.wood)
        c.fillRect(2, 2, 12, 2, LanternC.white)
        c.fillRect(5, 5, 6, 6, LanternC.gold)
        c.fillRect(7, 7, 2, 4, LanternC.out)
        if big { c.fillRect(6, 11, 4, 2, LanternC.gold) }
        return LanternArt.spr(c)
    }

    static let shutter: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(0, 0, 16, 16, LanternC.out)
        var x = 1
        while x < 16 { c.fillRect(x, 0, 2, 16, LanternC.grayL); c.vline(x + 1, 0, 16, LanternC.grayD); x += 4 }
        c.hline(0, 4, 16, LanternC.out); c.hline(0, 11, 16, LanternC.out)
        return LanternArt.spr(c)
    }()

    static let sign: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(7, 10, 2, 6, LanternC.out)
        c.fillRect(1, 2, 14, 9, LanternC.out)
        c.fillRect(2, 3, 12, 7, LanternC.path)
        c.hline(4, 5, 8, LanternC.wood); c.hline(4, 7, 6, LanternC.wood)
        return LanternArt.spr(c)
    }()

    static let chestClosed: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(1, 5, 14, 10, LanternC.out)
        c.fillRect(2, 6, 12, 8, LanternC.orange)
        c.fillRect(2, 6, 12, 3, LanternC.gold)
        c.hline(2, 9, 12, LanternC.out)
        c.fillRect(7, 8, 2, 3, LanternC.white)
        c.vline(3, 9, 5, LanternC.brown); c.vline(12, 9, 5, LanternC.brown)
        return LanternArt.spr(c)
    }()

    static let chestOpened: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(1, 2, 14, 4, LanternC.out)
        c.fillRect(2, 3, 12, 2, LanternC.gold)
        c.fillRect(1, 7, 14, 8, LanternC.out)
        c.fillRect(2, 8, 12, 2, LanternC.hud)
        c.fillRect(2, 10, 12, 4, LanternC.orange)
        return LanternArt.spr(c)
    }()

    static let torchBase: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(6, 8, 4, 8, LanternC.out)
        c.fillRect(7, 9, 2, 6, LanternC.wood)
        c.fillRect(4, 5, 8, 4, LanternC.out)
        c.fillRect(5, 6, 6, 2, LanternC.stoneL)
        return LanternArt.spr(c)
    }()

    static let flames: [Sprite] = [
        Sprite([
            "....p....",
            "...ppp...",
            "..ppmpp..",
            "..pmmmp..",
            "..pmhmp..",
            "...mmm...",
            "....m...."
        ]),
        Sprite([
            ".........",
            "...p.p...",
            "..ppppp..",
            "..pmmmp..",
            "..pmhmp..",
            "...mmm...",
            "....m...."
        ])
    ]

    static let switchUpS: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(2, 4, 12, 10, LanternC.out)
        c.fillRect(3, 5, 10, 7, LanternC.gold)
        c.fillRect(3, 5, 10, 2, LanternC.white)
        c.fillRect(6, 7, 4, 3, LanternC.orange)
        return LanternArt.spr(c)
    }()

    static let switchDownS: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(2, 7, 12, 7, LanternC.out)
        c.fillRect(3, 8, 10, 5, LanternC.orange)
        c.fillRect(5, 9, 6, 2, LanternC.gold)
        return LanternArt.spr(c)
    }()

    static let pot: Sprite = {
        let c = LanternArt.blank()
        c.fillCircle(8, 10, 5, LanternC.out)
        c.fillCircle(8, 10, 4, LanternC.orange)
        c.fillRect(5, 3, 6, 3, LanternC.out)
        c.fillRect(6, 4, 4, 2, LanternC.brown)
        c.fillRect(5, 8, 2, 2, LanternC.gold)
        return LanternArt.spr(c)
    }()

    static let fence: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(1, 3, 3, 13, LanternC.out); c.fillRect(2, 4, 1, 11, LanternC.wood)
        c.fillRect(12, 3, 3, 13, LanternC.out); c.fillRect(13, 4, 1, 11, LanternC.wood)
        c.fillRect(0, 6, 16, 3, LanternC.out); c.fillRect(0, 7, 16, 1, LanternC.wood)
        c.fillRect(0, 11, 16, 3, LanternC.out); c.fillRect(0, 12, 16, 1, LanternC.wood)
        return LanternArt.spr(c)
    }()

    static let statue: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(3, 13, 10, 3, LanternC.out)
        c.fillRect(4, 3, 8, 11, LanternC.out)
        c.fillRect(5, 4, 6, 9, LanternC.grayL)
        c.fillRect(6, 6, 1, 2, LanternC.out); c.fillRect(9, 6, 1, 2, LanternC.out)
        c.hline(6, 10, 4, LanternC.out)
        c.hline(5, 4, 6, LanternC.white)
        return LanternArt.spr(c)
    }()

    static let counter: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(0, 4, 16, 12, LanternC.out)
        c.fillRect(0, 5, 16, 4, LanternC.path)
        c.fillRect(0, 9, 16, 6, LanternC.wood)
        c.hline(0, 9, 16, LanternC.out)
        return LanternArt.spr(c)
    }()

    static let bed: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(1, 1, 14, 15, LanternC.out)
        c.fillRect(2, 2, 12, 5, LanternC.white)
        c.fillRect(2, 7, 12, 8, LanternC.red)
        c.hline(2, 7, 12, LanternC.out)
        c.fillRect(3, 3, 4, 3, LanternC.path)
        return LanternArt.spr(c)
    }()

    static let table: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(1, 3, 14, 10, LanternC.out)
        c.fillRect(2, 4, 12, 7, LanternC.wood)
        c.fillRect(2, 4, 12, 2, LanternC.orange)
        c.fillRect(2, 13, 2, 3, LanternC.out); c.fillRect(12, 13, 2, 3, LanternC.out)
        c.fillRect(6, 6, 3, 3, LanternC.white)
        return LanternArt.spr(c)
    }()

    static let rug: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(1, 1, 14, 14, LanternC.red)
        c.strokeRect(1, 1, 14, 14, LanternC.gold)
        c.strokeRect(4, 4, 8, 8, LanternC.gold)
        return LanternArt.spr(c)
    }()

    static let shelf: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(0, 0, 16, 16, LanternC.out)
        c.fillRect(1, 1, 14, 14, LanternC.wood)
        c.hline(1, 7, 14, LanternC.out)
        c.fillRect(2, 3, 3, 4, LanternC.red); c.fillRect(6, 2, 3, 5, LanternC.blue); c.fillRect(10, 3, 3, 4, LanternC.lime)
        c.fillRect(2, 10, 4, 4, LanternC.gold); c.fillRect(8, 9, 5, 5, LanternC.pink)
        return LanternArt.spr(c)
    }()

    static func eyeSprite(_ open: Bool) -> Sprite {
        let c = LanternArt.blank()
        c.fillRect(1, 1, 14, 14, LanternC.out)
        c.fillRect(2, 2, 12, 12, LanternC.grayL)
        c.fillCircle(8, 8, 4, open ? LanternC.lime : LanternC.white)
        c.fillCircle(8, 8, 2, open ? LanternC.out : LanternC.red)
        if !open { c.hline(3, 8, 10, LanternC.out) }
        return LanternArt.spr(c)
    }

    static let bridge: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(0, 0, 16, 16, LanternC.wood)
        var y = 1
        while y < 16 { c.hline(0, y, 16, LanternC.out); y += 4 }
        c.vline(0, 0, 16, LanternC.out); c.vline(15, 0, 16, LanternC.out)
        return LanternArt.spr(c)
    }()

    static let pillar: Sprite = {
        let c = LanternArt.blank()
        c.fillRect(3, 1, 10, 15, LanternC.out)
        c.fillRect(4, 2, 8, 13, LanternC.grayL)
        c.fillRect(9, 2, 3, 13, LanternC.grayD)
        c.hline(3, 1, 10, LanternC.white)
        return LanternArt.spr(c)
    }()

    static let houseWall: Sprite = {
        let c = Canvas(width: 16, height: 16)
        c.fillRect(0, 0, 16, 16, LanternC.path)
        c.fillRect(0, 0, 2, 16, LanternC.wood)
        c.fillRect(14, 0, 2, 16, LanternC.wood)
        c.hline(0, 15, 16, LanternC.out)
        c.hline(2, 8, 12, LanternC.pathD)
        return LanternArt.spr(c)
    }()

    static let window: Sprite = {
        let c = Canvas(width: 16, height: 16)
        c.fillRect(0, 0, 16, 16, LanternC.path)
        c.fillRect(0, 0, 2, 16, LanternC.wood)
        c.fillRect(14, 0, 2, 16, LanternC.wood)
        c.hline(0, 15, 16, LanternC.out)
        c.fillRect(3, 3, 10, 9, LanternC.out)
        c.fillRect(4, 4, 8, 7, LanternC.cyan)
        c.vline(7, 4, 7, LanternC.out); c.hline(4, 7, 8, LanternC.out)
        return LanternArt.spr(c)
    }()

    static let roof: Sprite = {
        let c = Canvas(width: 16, height: 16)
        c.fillRect(0, 0, 16, 16, LanternC.roof)
        c.hline(0, 4, 16, LanternC.out); c.hline(0, 9, 16, LanternC.out); c.hline(0, 14, 16, LanternC.out)
        var x = 3
        while x < 16 { c.vline(x, 0, 4, LanternC.out); x += 8 }
        x = 7
        while x < 16 { c.vline(x, 5, 4, LanternC.out); x += 8 }
        x = 3
        while x < 16 { c.vline(x, 10, 4, LanternC.out); x += 8 }
        c.hline(0, 15, 16, LanternC.out)
        return LanternArt.spr(c)
    }()

    // MARK: Characters

    static func hero(_ s: Sprite) -> Sprite {
        return s.recolored(3, 16).recolored(6, 20).recolored(12, 18).recolored(11, 19)
    }

    static let heroDown: [Sprite] = [
        LanternArt.hero(Sprite([
            "....3333....", "...366663...", "..36cccc63..", "..3c3cc3c3..", "..3cccccc3..", "...3bbbb3...",
            "..3bbbbbb3..", ".3cbbbbbbc3.", "..3bbbbbb3..", "..3bb33bb3..", "..366..663..", "...33..33..."
        ])),
        LanternArt.hero(Sprite([
            "....3333....", "...366663...", "..36cccc63..", "..3c3cc3c3..", "..3cccccc3..", "...3bbbb3...",
            "..3bbbbbb3..", ".3cbbbbbbc3.", "..3bbbbbb3..", "...3bbbb3...", "...366663...", "....3333...."
        ]))
    ]
    static let heroUp: [Sprite] = [
        LanternArt.hero(Sprite([
            "....3333....", "...366663...", "..36666663..", "..36666663..", "..36666663..", "...3bbbb3...",
            "..3bbbbbb3..", ".3cbbbbbbc3.", "..3bbbbbb3..", "..3bb33bb3..", "..366..663..", "...33..33..."
        ])),
        LanternArt.hero(Sprite([
            "....3333....", "...366663...", "..36666663..", "..36666663..", "..36666663..", "...3bbbb3...",
            "..3bbbbbb3..", ".3cbbbbbbc3.", "..3bbbbbb3..", "...3bbbb3...", "...366663...", "....3333...."
        ]))
    ]
    static let heroSide: [Sprite] = [
        LanternArt.hero(Sprite([
            "....3333....", "...366663...", "..3cc66663..", "..3c3c6663..", "..3cccc663..", "...3bbbb3...",
            "..3bbbbbb3..", "..3cbbbbb3..", "..3bbbbbb3..", "...3bb3b3...", "...36.663...", "...33..33..."
        ])),
        LanternArt.hero(Sprite([
            "....3333....", "...366663...", "..3cc66663..", "..3c3c6663..", "..3cccc663..", "...3bbbb3...",
            "..3bbbbbb3..", "..3cbbbbb3..", "..3bbbbbb3..", "....3bb3....", "....3663....", ".....33....."
        ]))
    ]

    static var npcCache: [Int: Sprite] = [:]

    static func npcSprite(_ hair: Int, _ cloth: Int) -> Sprite {
        let key = hair * 64 + cloth
        if let s = npcCache[key] { return s }
        let base = Sprite([
            "....3333....", "...366663...", "..36cccc63..", "..3c3cc3c3..", "..3cccccc3..", "...3bbbb3...",
            "..3bbbbbb3..", ".3cbbbbbbc3.", "..3bbbbbb3..", "..3bbbbbb3..", "...3bbbb3...", "....3333...."
        ])
        let s = base.recolored(3, 16).recolored(12, 18).recolored(6, hair).recolored(11, cloth)
        npcCache[key] = s
        return s
    }

    static let wick: [Sprite] = [
        Sprite([
            "...gg...", "..gmmg..", ".gmhhmg.", ".gmhhmg.", ".gmmmmg.", "..gmmg..", "...gg...", "........"
        ]),
        Sprite([
            "........", "...gg...", "..gmmg..", ".gmhhmg.", ".gmhhmg.", ".gmmmmg.", "..gmmg..", "...gg..."
        ])
    ]

    // MARK: HUD and item icons (8x8 unless noted)

    static let heartFull = Sprite([".ll.ll.", "lhlllll", "lllllll", ".lllll.", "..lll..", "...l..."])
    static let heartHalf = Sprite([".ll.ss.", "lhll..s", "llll..s", ".lll.s.", "..ll.s.", "...ls.."])
    static let heartEmpty = Sprite([".ss.ss.", "s..s..s", "s.....s", ".s...s.", "..s.s..", "...s..."])
    static let gem = Sprite(["...u...", "..uuu..", ".uuhuu.", ".uuhuu.", "..uuu..", "...u..."])
    static let keySmall = Sprite(["..mmm...", ".m...m..", ".m...m..", "..mmm...", "...m....", "...mm...", "...m....", "...mm..."])
    static let keyBig = Sprite(["..lll...", ".l...l..", ".l...l..", "..lll...", "...l....", "...ll...", "...l....", "...ll..."])
    static let piece = Sprite([".ll.....", "lhll....", "llll....", ".lll....", "..ll....", "...l...."])
    static let spark = Sprite(["...m....", "...m....", ".mmhmm..", "mmhhhmm.", ".mmhmm..", "...m....", "..m.m...", "........"])
    static let mapIcon = Sprite(["gggggggg", "gpppgppg", "gppgpppg", "gpgpppgg", "gpppgppg", "gggggggg"])

    static let itemIcons: [String: Sprite] = [
        "bombs": Sprite(["....m...", "...m.m..", "..gggg..", ".gsssgg.", ".gshsgg.", ".gsssgg.", "..gggg..", "........"]),
        "boomerang": Sprite(["........", ".mmm....", "mggmm...", "mm.gmm..", "....gmm.", "....gmm.", "...gmm..", "........"]),
        "bow": Sprite(["..kk....", ".k.rr...", "k...r...", "k.rhhrr.", "k...r...", ".k.rr...", "..kk....", "........"]),
        "lantern": Sprite(["..gggg..", "...gg...", "..gmmg..", ".gmhhmg.", ".gmhhmg.", ".gmmmmg.", "..gggg..", "........"]),
        "gloves": Sprite(["..t.t.t.", ".tttttt.", ".tttttt.", ".tttttt.", "..tttt..", "..gggg..", "..gggg..", "........"]),
        "boots": Sprite(["........", "..kk....", "..kk....", "..kk....", "..kkkk..", ".kkkkkk.", ".gggggg.", "........"]),
        "sword": Sprite([".....hh.", "....hhg.", "...hhg..", "..hhg...", "m.hg....", ".mg.....", "kmm.....", "k......."]),
        "shield": Sprite([".gggggg.", "gnnhhnng", "gnnhhnng", "gnnnnnng", ".gnnnng.", "..gnng..", "...gg...", "........"])
    ]

    static let questIcons: [Sprite] = [
        Sprite(["..mm....", ".mhmm...", ".mmmmp..", "..mmm...", "..mm....", "..p.p..."]),
        Sprite(["..tttt..", ".tththt.", "tthttht.", ".tttttt.", "..tttt..", "........"]),
        Sprite(["..llll..", ".lhllhl.", "llllllll", "..hhhh..", "..hhhh..", "........"]),
        Sprite(["......u.", ".....u..", "....u...", "...u.m..", "..mmm...", "..mgm...", "..mmm...", "........"]),
        Sprite(["llllllll", "lhlhlhlh", "llllllll", ".l....l.", ".l....l.", ".l....l."]),
        Sprite(["gggggg..", "ghhhhg..", "ghgghg..", "ghhhhg..", "ghgghg..", "gggggg.."])
    ]

    // MARK: Enemies (12x12 unless noted)

    static let enemySprites: [String: Sprite] = [
        "blobbo": Sprite([
            "............", "....gggg....", "...gqqqqg...", "..gqhqqqqg..", ".gqqqqqqqqg.", ".gqgqqqqgqg.",
            ".gqgqqqqgqg.", ".gqqqqqqqqg.", "..gqqqqqqg..", "...gggggg...", "............", "............"
        ]),
        "boarly": Sprite([
            "............", "..t......t..", "..gt....tg..", ".gtttttttg..", "gttgtttgttg.", "gttgtttgttg.",
            "gtttgggtttg.", ".gtttttttg..", "..gtttttg...", "..g.g..g.g..", "..g.g..g.g..", "............"
        ]),
        "pebbler": Sprite([
            "............", "...gggggg...", "..gllllllg..", ".glhllllhlg.", ".glgllllglg.", ".gllllggllg.",
            ".gllllggllg.", ".gllllllllg.", ".glglglglg..", ".g.g.g.g.g..", "............", "............"
        ]),
        "hopper": Sprite([
            "............", "............", ".gg......gg.", "gugg.gg.ggug", "gughgggghgug", ".guuuuuuuug.",
            ".guuuuuuuug.", "gguuuuuuugg.", "gug.gggg.gug", ".gg......gg.", "............", "............"
        ]),
        "shellguard": Sprite([
            "............", "...gggggg...", "..grrrrrrg..", ".grrgrrgrrg.", ".grgrrrrgrg.", ".grrrrrrrrg.",
            ".gqgrrrrgqg.", "gqqqgrrgqqqg", "gqhqqggqqhqg", ".ggqqqqqqgg.", "..gg.gg.gg..", "............"
        ]),
        "flutterbug": Sprite([
            "............", "............", "rr........rr", "rrrg.gg.grrr", "rrrrgoogrrrr", ".rrrgoogrrr.",
            "..rggoogrr..", "...gooog....", "....g.g.....", "............", "............", "............"
        ]),
        "sandmole": Sprite([
            "............", "....gggg....", "...gkkkkg...", "..gkkkkkkg..", ".gkkgkkgkkg.", ".gkkkttkkkg.",
            ".gkkkttkkkg.", ".gkkkkkkkkg.", "..gkkkkkkg..", ".gtg.gg.gtg.", ".ggg....ggg.", "............"
        ]),
        "spinwheel": Sprite([
            "............", "...gggggg...", "..gnnnnnng..", ".gnnnhhnnng.", ".gnnhnnhnng.", ".gnhnnnnhng.",
            ".gnhnnnnhng.", ".gnnhnnhnng.", ".gnnnhhnnng.", "..gnnnnnng..", "...gggggg...", "............"
        ]),
        "beetlebit": Sprite([
            "........", "..gppg..", ".gpppog.", "gpgppgpg", "gppppppg", ".gpppog.", "..g..g..", "........"
        ]),
        "crabby": Sprite([
            "............", "gg........gg", "gpg......gpg", "gpggpppgggpg", ".gppgppgppg.", ".gpgppppgpg.",
            ".gppppppppg.", "..gppppppg..", "..g.g..g.g..", ".g.g....g.g.", "............", "............"
        ]),
        "sporecap": Sprite([
            "............", "...gggggg...", "..gllhllllg.", ".glllllhlllg", ".gllhllllllg", ".ggggggggggg",
            "...grrrrg...", "...grgrrg...", "...grrrrg...", "..gggggggg..", "............", "............"
        ]),
        "frostling": Sprite([
            "............", "....gggg....", "...guuuug...", "..guhhuuug..", ".guhuuuuuug.", ".guuguuguug.",
            ".guuguuguug.", ".guuuuuuuug.", "..guuhhuug..", "...guuuug...", "....gggg....", "............"
        ]),
        "embling": Sprite([
            "....p.......", "...pp..p....", "..ppmp.pp...", "..pmmpppp...", ".gpmmmmppg..", ".gpgmmgmpg..",
            ".gpgmmgmpg..", ".gppmmmmpg..", "..gpppppg...", "..g.gggg.g..", "............", "............"
        ]),
        "wisp": Sprite([
            "............", "....gggg....", "...ghhhhg...", "..ghhhhhhg..", ".ghhghhghhg.", ".ghhghhghhg.",
            ".ghhhuuhhhg.", ".ghhhhhhhhg.", ".ghhghhghhg.", ".gg.gg.gg.g.", "............", "............"
        ]),
        "clunker": Sprite([
            "............", "...gggggg...", "..grrrrrrg..", "..grggggrg..", "..grgsggrg..", "..grrrrrrg..",
            ".ggrsrrsrgg.", "gsrrrrrrrrsg", "gsrrsssrrrsg", ".gggrrrrggg.", "...gsggsg...", "...ggg.ggg.."
        ])
    ]
}
