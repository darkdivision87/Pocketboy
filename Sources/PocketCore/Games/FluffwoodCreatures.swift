#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

// FLUFFWOOD 64 : creature species, runtime creature state and the procedural sprite artists.

struct FluffSpecies {
    let name: String
    let type: Int
    let region: Int
    let time: Int
    let rarity: Int
    let treat: Int
    let fact: String
    let body: UInt32
    let belly: UInt32
    let accent: UInt32
    let shinyBody: UInt32
    let shinyBelly: UInt32
    let shinyAccent: UInt32
    let ears: Int
    let tail: Int
    let wings: Bool
    let shell: Bool
    let glow: Bool
    let aspect: Float
    let size: Float

    static func shinyOf(_ c: UInt32) -> UInt32 {
        let r: Int = Int(c & 255)
        let g: Int = Int((c >> 8) & 255)
        let b: Int = Int((c >> 16) & 255)
        let nr: Int = min(255, (g + 90) * 3 / 4 + 40)
        let ng: Int = min(255, (b + 80) * 3 / 4 + 40)
        let nb: Int = min(255, (r + 120) * 3 / 4 + 20)
        return 0xFF00_0000 | UInt32(nr) | (UInt32(ng) << 8) | (UInt32(nb) << 16)
    }

    static func make(_ name: String, _ type: Int, _ region: Int, _ time: Int, _ rarity: Int, _ treat: Int,
                     _ body: UInt32, _ belly: UInt32, _ accent: UInt32,
                     _ ears: Int, _ tail: Int, _ flags: Int, _ aspect: Float, _ size: Float, _ fact: String) -> FluffSpecies {
        let b: UInt32 = FluffPainter.abgr(body)
        let l: UInt32 = FluffPainter.abgr(belly)
        let a: UInt32 = FluffPainter.abgr(accent)
        return FluffSpecies(name: name, type: type, region: region, time: time, rarity: rarity, treat: treat, fact: fact,
                            body: b, belly: l, accent: a,
                            shinyBody: shinyOf(b), shinyBelly: shinyOf(l), shinyAccent: shinyOf(a),
                            ears: ears, tail: tail, wings: (flags & 1) != 0, shell: (flags & 2) != 0, glow: (flags & 4) != 0,
                            aspect: aspect, size: size)
    }

    static let typeNames: [String] = ["LEAF", "WATER", "FIRE", "SKY", "SPARKLE"]
    static let treatNames: [String] = ["BERRY", "HONEY", "BISCUIT"]
    static let regionNames: [String] = ["SUNNY MEADOW", "SHELL BEACH", "CRYSTAL HOLLOW"]
    static let rarityNames: [String] = ["COMMON", "UNCOMMON", "RARE"]

    static let all: [FluffSpecies] = [
        FluffSpecies.make("PUFFNIP", 0, 0, 0, 0, 0, 0xAAE68C, 0xF0FFDC, 0x5ABE64, 4, 1, 0, 1.05, 1.0,
             "Naps under its leaf hat so the rain only tickles its tail."),
        FluffSpecies.make("DANDIBUN", 0, 0, 1, 0, 0, 0xFFEC8C, 0xFFFAD2, 0xFFC83C, 3, 1, 0, 0.95, 1.0,
             "Its fluffy tuft is full of wishes. Please sneeze gently!"),
        FluffSpecies.make("CLOVELET", 0, 0, 0, 0, 1, 0x78D6AA, 0xDCFFEB, 0x3CAA78, 1, 3, 0, 1.0, 0.95,
             "Every lucky clover it finds, it gives to a friend."),
        FluffSpecies.make("BUMBLO", 3, 0, 1, 0, 1, 0xFFD650, 0xFFF0AA, 0x46405A, 6, 0, 1, 1.0, 0.9,
             "Hums happy songs and shares honey with anyone who smiles."),
        FluffSpecies.make("CLOUDWREN", 3, 0, 1, 1, 0, 0xBEE1FF, 0xFFFFFF, 0x6EAAF0, 2, 1, 1, 1.0, 0.95,
             "Naps on soft clouds and wakes up fluffier every day."),
        FluffSpecies.make("BLOSSOMOO", 4, 0, 1, 1, 1, 0xFFC8DC, 0xFFF0F5, 0xFF78AA, 7, 1, 0, 1.12, 1.1,
             "The flower on its head changes colour with its mood."),
        FluffSpecies.make("EMBERKIT", 2, 0, 3, 1, 2, 0xFFAA6E, 0xFFE6BE, 0xFF6E3C, 2, 2, 0, 1.0, 0.95,
             "Its tail glows like a tiny campfire. So cosy to hug!"),
        FluffSpecies.make("MOONMOTH", 4, 0, 2, 1, 1, 0xC8BEFF, 0xF0EBFF, 0x9682F0, 6, 0, 5, 1.0, 0.95,
             "Dances around lanterns and sprinkles moon dust on dreams."),
        FluffSpecies.make("TWINKLEFAWN", 4, 0, 3, 2, 0, 0xFFE2BE, 0xFFF6E2, 0xFFC85A, 10, 1, 0, 0.95, 1.15,
             "The freckles on its coat show where the first stars will appear."),
        FluffSpecies.make("DRIBBLET", 1, 1, 0, 0, 2, 0x82D2FF, 0xD2F0FF, 0x46A0F0, 0, 4, 0, 1.15, 1.0,
             "Bounces like a water balloon and giggles when it splashes."),
        FluffSpecies.make("SHELLABY", 1, 1, 1, 0, 2, 0xFFBEC8, 0xFFE6E6, 0xFF96A0, 1, 0, 2, 1.0, 1.0,
             "Adds one new swirl to its shell every single day."),
        FluffSpecies.make("SANDPUFF", 2, 1, 1, 0, 2, 0xFAD896, 0xFFF4D2, 0xFFAA46, 1, 2, 0, 1.05, 1.0,
             "Builds sandcastles then waves at the passing crabs."),
        FluffSpecies.make("SEABUN", 3, 1, 1, 0, 2, 0xF5FAFF, 0xFFFFFF, 0xFFB05A, 0, 1, 1, 1.0, 0.95,
             "Rides the sea breeze and swaps secrets with the waves."),
        FluffSpecies.make("CORALPUP", 1, 1, 0, 1, 0, 0xFF9696, 0xFFDCD2, 0xFF5A78, 9, 4, 0, 1.0, 1.0,
             "Its fins wiggle in rhythm whenever someone plays a drum."),
        FluffSpecies.make("PALMPOM", 0, 1, 1, 1, 1, 0x96DE96, 0xE6FFD7, 0x3CAA5A, 4, 3, 0, 1.05, 1.05,
             "Waves its palm hat to make a cool breeze for friends."),
        FluffSpecies.make("PEARLY", 4, 1, 2, 2, 2, 0xFAF4FF, 0xFFFFFF, 0xC8B4FF, 0, 1, 6, 1.05, 1.1,
             "Glows softly on moonlit nights and hums a lullaby."),
        FluffSpecies.make("SPLASHOTTER", 1, 1, 3, 1, 0, 0xBEA08C, 0xFAE6D2, 0x78C8FF, 1, 4, 0, 1.0, 1.05,
             "Floats on its back and juggles shiny pebbles."),
        FluffSpecies.make("GEMNIBBLE", 4, 2, 0, 0, 1, 0xBEAAF0, 0xE6DCFF, 0x78F0E6, 5, 5, 0, 0.95, 0.95,
             "Nibbles tiny crystals that make its cheeks twinkle."),
        FluffSpecies.make("MAUVLET", 0, 2, 0, 0, 0, 0xD2A0DC, 0xF5DCFA, 0x9664BE, 8, 0, 0, 1.05, 1.0,
             "Grows a new spotted cap every season. So fashionable!"),
        FluffSpecies.make("GLOWCAP", 0, 2, 2, 1, 1, 0x8CF0D2, 0xDCFFF5, 0x5ADCFF, 8, 0, 4, 1.0, 1.0,
             "Lights up dark caves so every friend can find the way."),
        FluffSpecies.make("PEBBLIN", 2, 2, 1, 0, 2, 0xB4AFC8, 0xE1DCEB, 0xFF8C5A, 1, 2, 0, 1.1, 1.0,
             "Warms up in the sun and keeps cuddles toasty all night."),
        FluffSpecies.make("MINTLYNX", 1, 2, 0, 1, 0, 0x96EBE1, 0xE6FFFA, 0x5ABED2, 2, 4, 0, 1.0, 1.1,
             "Its minty tail leaves a cool, sparkly trail in the grass."),
        FluffSpecies.make("ZIPWISP", 3, 2, 0, 1, 1, 0xD2F0FF, 0xFFFFFF, 0x96DCFF, 6, 4, 1, 0.9, 0.9,
             "Zips around so fast it giggles before it arrives."),
        FluffSpecies.make("LANTERNOX", 2, 2, 2, 2, 1, 0xFFBE6E, 0xFFEBAA, 0xFFE65A, 2, 2, 4, 1.0, 1.15,
             "Carries a glowing lantern tail to guide lost travellers."),
        FluffSpecies.make("STARLUNE", 4, 2, 2, 2, 0, 0x5A64B4, 0x96A0E6, 0xFFF096, 2, 1, 4, 1.05, 1.15,
             "Collects falling stars in its fur and makes a wish on each."),
        FluffSpecies.make("RAINWING", 3, 2, 3, 2, 2, 0xFFBEE6, 0xFFEBF5, 0x96DCFF, 5, 2, 1, 1.0, 1.2,
             "Shows up when morning light bends into a rainbow.")
    ]
}

// MARK: - Runtime creature

enum FluffState {
    static let idle = 0
    static let wander = 1
    static let nap = 2
    static let play = 3
    static let flee = 4
    static let curious = 5
    static let joy = 6
    static let eating = 7
}

struct FluffCreature {
    var uid: Int
    var sp: Int
    var shiny: Bool
    var x: Float
    var y: Float
    var gz: Float
    var heading: Float
    var state: Int
    var timer: Int
    var tx: Float
    var ty: Float
    var phase: Float
    var hopT: Float = 0
    var blink: Int = 0
    var partner: Int = -1
    var joyT: Int = 0
    var announced: Bool = false
    var face: Int = 1
    var age: Int = 0
    var fails: Int = 0
}

// MARK: - Creature sprites

struct FluffPose {
    var squash: Float = 1.0
    var blink: Bool = false
    var happy: Bool = false
    var tick: Int = 0
    var facing: Int = 1
    var level: Int = 1
    var shiny: Bool = false
    var showFace: Bool = true
}

extension FluffPainter {
    static func darker(_ c: UInt32, _ f: Int) -> UInt32 {
        let r: Int = (Int(c & 255) * f) >> 8
        let g: Int = (Int((c >> 8) & 255) * f) >> 8
        let b: Int = (Int((c >> 16) & 255) * f) >> 8
        return 0xFF00_0000 | UInt32(r & 255) | (UInt32(g & 255) << 8) | (UInt32(b & 255) << 16)
    }

    static func lighter(_ c: UInt32, _ add: Int) -> UInt32 {
        let r: Int = min(255, Int(c & 255) + add)
        let g: Int = min(255, Int((c >> 8) & 255) + add)
        let b: Int = min(255, Int((c >> 16) & 255) + add)
        return 0xFF00_0000 | UInt32(r) | (UInt32(g) << 8) | (UInt32(b) << 16)
    }

    /// Draws a fluffy creature. (cx, baseY) is where it touches the ground, r is the body radius in pixels.
    func drawCreature(_ sp: FluffSpecies, _ cx: Int, _ baseY: Int, _ r: Int, _ pose: FluffPose) {
        let rr: Int = max(2, min(r, 400))
        let shiny: Bool = pose.shiny
        let bodyC: UInt32 = shiny ? sp.shinyBody : sp.body
        let bellyC: UInt32 = shiny ? sp.shinyBelly : sp.belly
        let accC: UInt32 = shiny ? sp.shinyAccent : sp.accent
        let outline: UInt32 = FluffPainter.darker(bodyC, 150)
        let accD: UInt32 = FluffPainter.darker(accC, 190)
        let sqv: Float = FluffMath.clampF(pose.squash, 0.6, 1.4)
        let ry: Int = max(2, FluffMath.i(Float(rr) * sqv))
        let widen: Float = 1.0 + (1.0 - sqv) * 0.6
        let rx: Int = max(2, FluffMath.i(Float(rr) * sp.aspect * widen))
        let cy: Int = baseY - ry
        let side: Int = pose.facing >= 0 ? -1 : 1
        let oldGlow = glow
        let silhouette: Bool = sil != 0
        if sp.glow && !silhouette { glow = true }
        defer { glow = oldGlow }

        if rr < 6 {
            // tiny version for far away creatures
            ell(cx, cy, rx, ry, bodyC)
            if rr >= 3 {
                ell(cx, cy + ry / 3, rx * 2 / 3, ry / 2, bellyC)
                rect(cx - rx / 2, cy - ry / 4, 1, 2, 0xFF462E5A)
                rect(cx + rx / 2 - 1, cy - ry / 4, 1, 2, 0xFF462E5A)
                if sp.ears == 4 || sp.ears == 7 || sp.ears == 8 { ell(cx, cy - ry, max(1, rx / 2), max(1, ry / 4), accC) }
                else if sp.ears != 0 { rect(cx - rx / 2, cy - ry - 1, 1, 2, bodyC); rect(cx + rx / 2, cy - ry - 1, 1, 2, bodyC) }
            }
            if shiny { star(cx + rx, cy - ry, 1, 0xFFFFFFFF) }
            return
        }

        // glow aura
        if sp.glow && !silhouette {
            ellA(cx, cy, rx * 14 / 10, ry * 14 / 10, accC, 46)
            ellA(cx, cy, rx * 11 / 10, ry * 11 / 10, accC, 50)
        }
        if pose.level >= 4 && !silhouette {
            ellA(cx, cy, rx * 15 / 10, ry * 15 / 10, 0xFF9EEBFF, 40)
        }

        // tail
        switch sp.tail {
        case 1:
            ell(cx + side * (rx - rr / 8), cy + ry / 4, rr / 3 + 1, rr / 3 + 1, bellyC)
        case 2:
            let fl: Int = (pose.tick / 4) & 3
            let fx: Int = cx + side * (rx + rr / 8)
            ell(fx, cy + ry / 6 - fl, rr / 3 + 1, rr / 2 + fl, 0xFF3C78FF)
            ell(fx, cy + ry / 5 - fl, rr / 5 + 1, rr / 3 + fl, 0xFF50DCFF)
        case 3:
            ell(cx + side * (rx + rr / 10), cy - ry / 5, rr / 4 + 1, rr * 6 / 10, accC)
            ell(cx + side * (rx + rr / 10), cy - ry / 5 - rr / 6, max(1, rr / 8), rr / 3, FluffPainter.lighter(accC, 50))
        case 4:
            ell(cx + side * (rx + rr / 8), cy + ry / 3, rr / 2, rr / 4 + 1, accC)
            ell(cx + side * (rx + rr * 4 / 10), cy + ry / 5, rr / 5 + 1, rr / 5 + 1, FluffPainter.lighter(accC, 40))
        case 5:
            cone(cx + side * (rx - rr / 6), cy + ry / 2, rr / 4 + 1, rr * 7 / 10, side * rr / 4, accC)
        default:
            break
        }

        // wings
        if sp.wings {
            let fl: Float = sin(Float(pose.tick) * 0.3) * 0.35
            let wy: Int = cy - ry / 8 + FluffMath.i(fl * Float(ry))
            let wc: UInt32 = FluffPainter.lighter(accC, 30)
            ell(cx - rx - rr / 8, wy, rr * 6 / 10, rr * 4 / 10, wc)
            ell(cx + rx + rr / 8, wy, rr * 6 / 10, rr * 4 / 10, wc)
            ell(cx - rx - rr / 8, wy - rr / 6, rr / 3, rr / 5, 0xFFFFFFFF)
            ell(cx + rx + rr / 8, wy - rr / 6, rr / 3, rr / 5, 0xFFFFFFFF)
        }

        // shell on the back
        if sp.shell {
            ell(cx, cy - ry * 4 / 10, rx * 9 / 10, ry * 9 / 10, accD)
            ell(cx, cy - ry * 5 / 10, rx * 8 / 10, ry * 8 / 10, accC)
            rect(cx - 1, cy - ry * 13 / 10, 2, ry * 8 / 10, accD)
            rect(cx - rx / 2, cy - ry, 1, ry / 2, accD)
            rect(cx + rx / 2, cy - ry, 1, ry / 2, accD)
        }

        // feet
        ell(cx - rx / 2, baseY - rr / 10, rr / 4 + 1, rr / 6 + 1, outline)
        ell(cx + rx / 2, baseY - rr / 10, rr / 4 + 1, rr / 6 + 1, outline)

        // ears and horns that sit behind the head
        let ex: Int = rx * 55 / 100
        let topY: Int = cy - ry * 85 / 100
        switch sp.ears {
        case 1:
            for sgn in [-1, 1] {
                ell(cx + sgn * ex, topY + rr / 8, rr * 32 / 100 + 1, rr * 32 / 100 + 1, outline)
                ell(cx + sgn * ex, topY + rr / 8, rr * 28 / 100 + 1, rr * 28 / 100 + 1, bodyC)
                ell(cx + sgn * ex, topY + rr / 8, rr / 7 + 1, rr / 7 + 1, 0xFFC8B4FF)
            }
        case 2:
            for sgn in [-1, 1] {
                cone(cx + sgn * ex, cy - ry * 45 / 100, rr * 32 / 100 + 1, rr * 85 / 100, sgn * rr / 6, outline)
                cone(cx + sgn * ex, cy - ry * 48 / 100, rr * 25 / 100 + 1, rr * 75 / 100, sgn * rr / 6, bodyC)
                cone(cx + sgn * ex, cy - ry * 52 / 100, rr / 8 + 1, rr * 45 / 100, sgn * rr / 8, 0xFFC8B4FF)
            }
        case 3:
            for sgn in [-1, 1] {
                ell(cx + sgn * ex * 7 / 10, cy - ry - rr * 30 / 100, rr * 21 / 100 + 1, rr * 62 / 100, outline)
                ell(cx + sgn * ex * 7 / 10, cy - ry - rr * 30 / 100, rr * 17 / 100 + 1, rr * 56 / 100, bodyC)
                ell(cx + sgn * ex * 7 / 10, cy - ry - rr * 28 / 100, rr / 10 + 1, rr * 38 / 100, 0xFFC8B4FF)
            }
        case 5:
            for sgn in [-1, 1] {
                cone(cx + sgn * ex * 7 / 10, cy - ry * 60 / 100, rr / 6 + 1, rr * 55 / 100, sgn * rr / 5, accC)
            }
        case 6:
            for sgn in [-1, 1] {
                let bx: Int = cx + sgn * ex * 5 / 10
                let by: Int = cy - ry * 85 / 100
                let tx: Int = cx + sgn * ex * 12 / 10
                let ty: Int = cy - ry - rr * 55 / 100
                line(bx, by, tx, ty, max(1, rr / 10), outline)
                ell(tx, ty, rr / 7 + 1, rr / 7 + 1, accC)
            }
        case 9:
            for sgn in [-1, 1] {
                ell(cx + sgn * (rx + rr / 12), cy - ry * 25 / 100, rr * 38 / 100, rr * 22 / 100, accC)
                ell(cx + sgn * (rx + rr / 12), cy - ry * 28 / 100, rr * 28 / 100, rr / 10 + 1, FluffPainter.lighter(accC, 50))
            }
        case 10:
            for sgn in [-1, 1] {
                let bx: Int = cx + sgn * ex * 5 / 10
                let by: Int = cy - ry * 85 / 100
                let tx: Int = cx + sgn * ex * 11 / 10
                let ty: Int = cy - ry - rr * 65 / 100
                line(bx, by, tx, ty, max(1, rr / 9), accC)
                line((bx + tx) / 2, (by + ty) / 2, tx + sgn * rr / 4, (by + ty) / 2 - rr / 6, max(1, rr / 12), accC)
            }
        default:
            break
        }

        // body: outline pass then fill pass
        let tuftR: Int = rr * 22 / 100 + 1
        let tx1: Int = rx * 92 / 100
        let tx2: Int = rx * 70 / 100
        if rr >= 5 {
            ell(cx, cy, rx + 1, ry + 1, outline)
            if rr >= 8 {
                ell(cx - tx1, cy + ry * 22 / 100, tuftR + 1, tuftR + 1, outline)
                ell(cx + tx1, cy + ry * 22 / 100, tuftR + 1, tuftR + 1, outline)
                ell(cx - tx2, cy - ry * 62 / 100, tuftR + 1, tuftR + 1, outline)
                ell(cx + tx2, cy - ry * 62 / 100, tuftR + 1, tuftR + 1, outline)
                ell(cx - tx2, cy + ry * 70 / 100, tuftR + 1, tuftR + 1, outline)
                ell(cx + tx2, cy + ry * 70 / 100, tuftR + 1, tuftR + 1, outline)
            }
        }
        if rr >= 8 {
            ell(cx - tx1, cy + ry * 22 / 100, tuftR, tuftR, bodyC)
            ell(cx + tx1, cy + ry * 22 / 100, tuftR, tuftR, bodyC)
            ell(cx - tx2, cy - ry * 62 / 100, tuftR, tuftR, bodyC)
            ell(cx + tx2, cy - ry * 62 / 100, tuftR, tuftR, bodyC)
            ell(cx - tx2, cy + ry * 70 / 100, tuftR, tuftR, bodyC)
            ell(cx + tx2, cy + ry * 70 / 100, tuftR, tuftR, bodyC)
        }
        ell(cx, cy, rx, ry, bodyC)
        if sp.shell {
            ell(cx, cy + ry * 40 / 100, rx * 5 / 10, ry * 4 / 10, bellyC)
        } else {
            ell(cx, cy + ry * 32 / 100, rx * 62 / 100, ry * 55 / 100, bellyC)
        }
        if !silhouette {
            ellA(cx - rx * 35 / 100, cy - ry * 55 / 100, rx * 28 / 100 + 1, ry * 16 / 100 + 1, 0xFFFFFFFF, 110)
        }

        // head gear drawn on top
        switch sp.ears {
        case 4:
            let lc: UInt32 = accC
            let ll: UInt32 = FluffPainter.lighter(accC, 55)
            rect(cx - 1, cy - ry - rr / 5, max(1, rr / 12), rr / 4 + 1, accD)
            ell(cx - rr / 4, cy - ry - rr / 8, rr * 55 / 100, rr * 22 / 100, lc)
            ell(cx + rr * 32 / 100, cy - ry - rr * 25 / 100, rr * 40 / 100, rr * 17 / 100, ll)
            ell(cx - rr / 3, cy - ry - rr / 6, rr / 4, max(1, rr / 14), ll)
        case 7:
            let fx: Int = cx + rx * 38 / 100
            let fy: Int = cy - ry * 92 / 100
            let pr: Int = max(2, rr * 17 / 100)
            let pc: UInt32 = accC
            ell(fx - pr, fy, pr, pr, pc)
            ell(fx + pr, fy, pr, pr, pc)
            ell(fx, fy - pr, pr, pr, pc)
            ell(fx, fy + pr, pr, pr, pc)
            ell(fx, fy, max(1, pr * 7 / 10), max(1, pr * 7 / 10), 0xFF50E6FF)
        case 8:
            ell(cx, cy - ry * 62 / 100, rx * 105 / 100, ry * 52 / 100, accD)
            ell(cx, cy - ry * 68 / 100, rx * 100 / 100, ry * 48 / 100, accC)
            ell(cx - rx / 3, cy - ry * 85 / 100, max(1, rr / 7), max(1, rr / 8), 0xFFFFFFFF)
            ell(cx + rx / 3, cy - ry * 72 / 100, max(1, rr / 8), max(1, rr / 9), 0xFFFFFFFF)
            ell(cx + rx / 8, cy - ry * 95 / 100, max(1, rr / 9), max(1, rr / 10), 0xFFFFFFFF)
        default:
            break
        }

        if !pose.showFace {
            if shiny { drawShinyStars(cx, cy, rx, ry, pose.tick) }
            return
        }

        // face
        let eyeX: Int = rx * 38 / 100
        let eyeY: Int = cy - ry * 4 / 100
        let ew: Int = max(1, rr * 17 / 100)
        let eh: Int = max(2, rr * 27 / 100)
        let dark: UInt32 = 0xFF462E5A
        if pose.happy {
            let hs: Int = max(3, rr * 40 / 100)
            heart(cx - eyeX, eyeY, hs, 0xFF5A5AFF)
            heart(cx + eyeX, eyeY, hs, 0xFF5A5AFF)
        } else if pose.blink {
            rect(cx - eyeX - ew, eyeY + eh / 2, ew * 2 + 1, max(1, rr / 10), dark)
            rect(cx + eyeX - ew, eyeY + eh / 2, ew * 2 + 1, max(1, rr / 10), dark)
        } else {
            let iris: UInt32 = FluffPainter.darker(accC, 170)
            for sgn in [-1, 1] {
                let ex2: Int = cx + sgn * eyeX
                ell(ex2, eyeY, ew + 1, eh + 1, dark)
                if ew >= 2 {
                    ell(ex2, eyeY + eh / 5, max(1, ew * 8 / 10), max(1, eh * 7 / 10), iris)
                }
                ell(ex2 - ew / 3, eyeY - eh / 3, max(1, ew * 45 / 100), max(1, ew * 45 / 100), 0xFFFFFFFF)
                if ew >= 3 {
                    ell(ex2 + ew / 3, eyeY + eh / 3, max(1, ew * 20 / 100), max(1, ew * 20 / 100), 0xFFFFFFFF)
                }
            }
        }
        if rr >= 8 && !silhouette {
            ellA(cx - eyeX - rr / 5, eyeY + eh + rr / 12, rr * 20 / 100 + 1, rr * 12 / 100 + 1, 0xFFAA78FF, 150)
            ellA(cx + eyeX + rr / 5, eyeY + eh + rr / 12, rr * 20 / 100 + 1, rr * 12 / 100 + 1, 0xFFAA78FF, 150)
        }
        let m: Int = max(1, rr / 10)
        let my: Int = cy + ry * 36 / 100
        if pose.happy {
            ell(cx, my + m, m * 2, m * 2, 0xFF46325A)
            ell(cx, my + m * 2, m + 1, max(1, m), 0xFF8C8CFF)
        } else {
            rect(cx - m * 2, my, m, m, dark)
            rect(cx - m, my + m, m * 2, m, dark)
            rect(cx + m, my, m, m, dark)
        }

        if pose.level >= 2 && !silhouette {
            let n: Int = min(4, pose.level - 1)
            for k in 0..<n {
                let a: Float = Float(pose.tick) * 0.04 + Float(k) * (2 * Float.pi / Float(n))
                let ox: Int = FluffMath.i(cos(a) * Float(rx) * 1.35)
                let oy: Int = FluffMath.i(sin(a) * Float(ry) * 0.9)
                star(cx + ox, cy + oy, max(1, rr / 8), 0xFFFFFFFF)
            }
        }
        if shiny { drawShinyStars(cx, cy, rx, ry, pose.tick) }
    }

    private func drawShinyStars(_ cx: Int, _ cy: Int, _ rx: Int, _ ry: Int, _ tick: Int) {
        for k in 0..<3 {
            let ph: Int = (tick / 6 + k * 5) % 14
            if ph < 8 {
                let a: Float = Float(k) * 2.1 + 0.6
                let ox: Int = FluffMath.i(cos(a) * Float(rx) * 1.15)
                let oy: Int = FluffMath.i(sin(a) * Float(ry) * 1.1)
                let sz: Int = max(1, min(ph, 8 - ph) * max(1, rx / 10) / 2 + 1)
                star(cx + ox, cy + oy, sz, 0xFFFFFFFF)
            }
        }
    }

    // MARK: icons

    func drawTypeIcon(_ type: Int, _ cx: Int, _ cy: Int, _ r: Int) {
        let rr: Int = max(3, r)
        ell(cx, cy, rr, rr, 0xFFFFFFFF)
        switch type {
        case 0:
            ell(cx, cy, rr * 6 / 10, rr * 8 / 10, 0xFF6ED26E)
            rect(cx, cy - rr * 6 / 10, 1, rr * 12 / 10, 0xFF3C9A44)
        case 1:
            cone(cx, cy, rr * 5 / 10, rr * 8 / 10, 0, 0xFFFFAA50)
            ell(cx, cy + rr / 5, rr * 5 / 10, rr * 5 / 10, 0xFFFFAA50)
        case 2:
            cone(cx, cy + rr / 2, rr * 5 / 10, rr * 12 / 10, 0, 0xFF3C78FF)
            cone(cx, cy + rr / 2, rr * 3 / 10, rr * 7 / 10, 0, 0xFF50DCFF)
        case 3:
            ell(cx - rr / 4, cy + rr / 6, rr * 4 / 10, rr * 3 / 10, 0xFFFFC878)
            ell(cx + rr / 4, cy + rr / 6, rr * 4 / 10, rr * 3 / 10, 0xFFFFC878)
            ell(cx, cy - rr / 6, rr * 4 / 10, rr * 3 / 10, 0xFFFFC878)
        default:
            star(cx, cy, rr * 7 / 10, 0xFF50C8FF)
            star(cx + rr / 2, cy - rr / 2, max(1, rr / 4), 0xFFFF96FF)
        }
    }

    func drawTreat(_ kind: Int, _ cx: Int, _ cy: Int, _ r: Int) {
        let rr: Int = max(2, r)
        switch kind {
        case 0:
            ell(cx, cy + rr / 6, rr, rr, 0xFF5050F0)
            ell(cx - rr / 3, cy - rr / 4, max(1, rr / 4), max(1, rr / 4), 0xFFFFFFFF)
            ell(cx + rr / 3, cy - rr * 9 / 10, rr / 2 + 1, max(1, rr / 4), 0xFF50C85A)
        case 1:
            rect(cx - rr * 7 / 10, cy - rr / 2, rr * 14 / 10, rr * 14 / 10, 0xFF3CB4F0)
            rect(cx - rr * 8 / 10, cy - rr * 9 / 10, rr * 16 / 10, max(1, rr / 3), 0xFF64DCFF)
            rect(cx - rr / 3, cy - rr / 6, rr * 6 / 10, rr / 3 + 1, 0xFFFFFFFF)
        default:
            ell(cx, cy, rr, rr * 8 / 10, 0xFFA0D4F0)
            ell(cx, cy - rr / 8, rr * 8 / 10, rr * 6 / 10, 0xFFC8E6FF)
            rect(cx - 1, cy - rr / 2, 1, rr, 0xFF78AAD2)
            rect(cx - rr / 3, cy - rr / 3, 1, rr * 7 / 10, 0xFF78AAD2)
            rect(cx + rr / 3, cy - rr / 3, 1, rr * 7 / 10, 0xFF78AAD2)
        }
    }

    // MARK: explorer

    /// The little explorer seen from behind. u = pixels per world unit.
    func drawExplorer(_ cx: Int, _ baseY: Int, _ u: Float, _ walk: Float, _ air: Float, _ hat: Int, _ cape: Bool,
                      _ tick: Int, _ moving: Bool, _ gliding: Bool, _ wade: Float) {
        let hop: Int = FluffMath.i(air * u)
        let by: Int = baseY - hop + FluffMath.i(wade * u)
        let bob: Int = moving ? FluffMath.i(abs(sin(walk)) * 0.1 * u) : FluffMath.i(sin(Float(tick) * 0.06) * 0.03 * u)
        let sx: Float = sin(walk)
        let legW: Int = max(2, FluffMath.i(0.3 * u))
        let legH: Int = max(3, FluffMath.i(0.55 * u))
        let lift: Int = moving ? FluffMath.i(max(0, sx) * 0.18 * u) : 0
        let lift2: Int = moving ? FluffMath.i(max(0, -sx) * 0.18 * u) : 0
        let pants: UInt32 = 0xFFD2786E
        let shoe: UInt32 = 0xFFF0F0FA
        // ground shadow
        ellA(cx, baseY, FluffMath.i(0.6 * u), max(1, FluffMath.i(0.16 * u)), 0xFF304030, 90)
        let hipY: Int = by - legH + bob
        if cape {
            // rainbow cape fluttering behind
            let cw: Int = FluffMath.i(0.62 * u)
            let ch: Int = FluffMath.i(1.0 * u)
            let flutter: Int = FluffMath.i(sin(Float(tick) * 0.2) * 0.07 * u) + (moving ? FluffMath.i(0.1 * u) : 0)
            let cols: [UInt32] = [0xFF5A5AFF, 0xFF50A0FF, 0xFF50E6FF, 0xFF78D278, 0xFFFFC85A, 0xFFE678C8]
            let bandH: Int = max(1, ch / 6)
            for k in 0..<6 {
                rect(cx - cw / 2 - flutter / 2, hipY - FluffMath.i(0.95 * u) + k * bandH, cw + flutter, bandH + 1, cols[k])
            }
        }
        // legs
        rect(cx - legW - 1, by - legH + bob - lift, legW, legH - 2, pants)
        rect(cx + 1, by - legH + bob - lift2, legW, legH - 2, pants)
        ell(cx - legW / 2 - 1, by - lift - 1, legW / 2 + 2, max(1, legW / 3 + 1), shoe)
        ell(cx + legW / 2 + 1, by - lift2 - 1, legW / 2 + 2, max(1, legW / 3 + 1), shoe)
        // torso (tunic)
        let tw: Int = max(3, FluffMath.i(0.62 * u))
        let th: Int = max(3, FluffMath.i(0.7 * u))
        let tunic: UInt32 = 0xFF8C8CFF
        let tunicD: UInt32 = 0xFF6464E6
        ell(cx, hipY - th / 2 + bob / 2, tw / 2 + 1, th / 2 + 1, tunicD)
        ell(cx, hipY - th / 2 + bob / 2, tw / 2, th / 2, tunic)
        // arms swinging
        let armLen: Int = max(2, FluffMath.i(0.4 * u))
        let aSw: Int = moving ? FluffMath.i(sx * 0.14 * u) : 0
        ell(cx - tw / 2 - 1, hipY - th * 6 / 10 + aSw, max(1, legW / 2 + 1), armLen / 2 + 1, tunic)
        ell(cx + tw / 2 + 1, hipY - th * 6 / 10 - aSw, max(1, legW / 2 + 1), armLen / 2 + 1, tunic)
        ell(cx - tw / 2 - 1, hipY - th * 6 / 10 + aSw + armLen / 2, max(1, legW / 2), max(1, legW / 2), 0xFFB8D6FF)
        ell(cx + tw / 2 + 1, hipY - th * 6 / 10 - aSw + armLen / 2, max(1, legW / 2), max(1, legW / 2), 0xFFB8D6FF)
        // backpack
        let bw: Int = max(3, FluffMath.i(0.52 * u))
        let bh: Int = max(3, FluffMath.i(0.58 * u))
        let pack: UInt32 = 0xFFBEBE50
        let packD: UInt32 = 0xFF96962E
        ell(cx, hipY - th * 55 / 100 + bob / 2, bw / 2 + 1, bh / 2 + 1, packD)
        ell(cx, hipY - th * 55 / 100 + bob / 2, bw / 2, bh / 2, pack)
        rect(cx - bw / 2, hipY - th * 55 / 100 - bh / 6 + bob / 2, bw, max(1, bh / 6), packD)
        ell(cx, hipY - th * 55 / 100 + bh / 3 + bob / 2, max(1, bw / 4), max(1, bh / 8), 0xFFA0DCFF)
        // head
        let headR: Int = max(3, FluffMath.i(0.4 * u))
        let hy: Int = hipY - th - headR + bob + headR / 5
        ell(cx - headR, hy + headR / 4, max(1, headR / 5), max(1, headR / 4), 0xFFB8D6FF)
        ell(cx + headR, hy + headR / 4, max(1, headR / 5), max(1, headR / 4), 0xFFB8D6FF)
        ell(cx, hy, headR + 1, headR + 1, 0xFF3C466E)
        ell(cx, hy, headR, headR, 0xFF5A78A8)
        ell(cx - headR / 3, hy - headR / 3, max(1, headR / 3), max(1, headR / 4), 0xFF7A9AC8)
        // hats
        let topY: Int = hy - headR * 7 / 10
        switch hat {
        case 1:
            ell(cx, topY + headR / 3, headR * 17 / 10, max(2, headR * 5 / 10), 0xFF82D2F0)
            ell(cx, topY, headR * 9 / 10, headR * 7 / 10, 0xFF9CE6FF)
            rect(cx - headR * 9 / 10, topY + headR / 10, headR * 18 / 10, max(1, headR / 5), 0xFFB478FF)
        case 2:
            for k in 0..<7 {
                let a: Float = Float(k) / 7.0 * 2 * Float.pi
                let fx: Int = cx + FluffMath.i(cos(a) * Float(headR) * 1.0)
                let fy: Int = hy - headR * 3 / 10 + FluffMath.i(sin(a) * Float(headR) * 0.45)
                let pc: UInt32 = FluffPainter.flowerColors[k & 7]
                ell(fx, fy, max(1, headR / 4), max(1, headR / 4), pc)
            }
        case 3:
            ell(cx, topY + headR / 6, headR * 9 / 10, headR * 6 / 10, 0xFFFF8C50)
            ell(cx, topY - headR / 6, headR * 6 / 10, headR * 3 / 10, 0xFFFFB478)
            rect(cx, topY - headR * 4 / 10, 1, headR * 3 / 10, 0xFFF0F0F0)
            let pw: Int = max(1, FluffMath.i(abs(cos(Float(tick) * 0.5)) * Float(headR) * 1.3))
            ell(cx, topY - headR * 5 / 10, pw, max(1, headR / 8), 0xFF5AE6FF)
        case 4:
            ell(cx - headR * 6 / 10, topY, headR * 5 / 10, headR * 4 / 10, 0xFFE678FF)
            ell(cx + headR * 6 / 10, topY, headR * 5 / 10, headR * 4 / 10, 0xFFE678FF)
            ell(cx, topY, max(1, headR / 4), max(1, headR / 4), 0xFFC850FF)
            star(cx + headR * 9 / 10, topY - headR / 3, max(1, headR / 4), 0xFF50E6FF)
        case 5:
            rect(cx - headR * 7 / 10, topY - headR / 5, headR * 14 / 10, max(2, headR * 4 / 10), 0xFF3CC8FF)
            for k in 0..<3 {
                let px: Int = cx - headR * 6 / 10 + k * headR * 6 / 10
                cone(px, topY - headR / 5, max(1, headR / 5), max(2, headR * 6 / 10), 0, 0xFF3CC8FF)
                ell(px, topY - headR * 8 / 10, max(1, headR / 8), max(1, headR / 8), 0xFF5A5AFF)
            }
        default:
            ell(cx, topY + headR / 8, headR + 1, headR * 7 / 10, 0xFF4646D2)
            ell(cx, topY, headR, headR * 6 / 10, 0xFF6464F0)
            rect(cx - 1, topY - headR * 6 / 10, max(1, headR / 6), max(1, headR / 4), 0xFFFFFFFF)
        }
        if gliding {
            // little glide streaks
            rect(cx - headR * 3, hy, headR * 2, 1, 0xFFFFFFFF)
            rect(cx + headR * 2, hy, headR * 2, 1, 0xFFFFFFFF)
        }
    }
}
