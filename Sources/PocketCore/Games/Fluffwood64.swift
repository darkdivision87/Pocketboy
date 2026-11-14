#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// FLUFFWOOD 64: an original open-world creature collector. Voxel-space terrain, billboards, befriending with treats,
/// a collection book, goals, day/night, saving and direct-touch controls.
final class Fluffwood64: Game {
    // MARK: - Types

    enum Phase { case title, play, card, book, detail, quests }

    struct FluffCam {
        var x: Float = 0
        var y: Float = 0
        var alt: Float = 5
        var fx: Float = 1
        var fy: Float = 0
        var rx: Float = 0
        var ry: Float = 1
        var horizon: Float = 118
    }

    struct Particle {
        var x: Float
        var y: Float
        var z: Float
        var vx: Float
        var vy: Float
        var vz: Float
        var life: Int
        var maxLife: Int
        var kind: Int
        var color: UInt32
        var size: Float
    }

    struct Floater {
        var text: String
        var x: Float
        var y: Float
        var z: Float
        var life: Int
        var color: UInt32
    }

    struct Pickup {
        var x: Float
        var y: Float
        var kind: Int
        var bob: Int
    }

    struct Projectile {
        var active: Bool = false
        var sx: Float = 0
        var sy: Float = 0
        var sz: Float = 0
        var x: Float = 0
        var y: Float = 0
        var z: Float = 0
        var uid: Int = -1
        var treat: Int = 0
        var t: Int = 0
    }

    struct Wisp {
        var x: Float
        var y: Float
        var phase: Float
        var vx: Float
        var vy: Float
        var hue: Int
    }

    struct Cloud {
        var az: Float
        var el: Float
        var size: Float
        var speed: Float
    }

    struct DrawItem {
        var z: Float
        var kind: Int
        var idx: Int
        var sx: Float
        var sy: Float
        var s: Float
    }

    struct UiConfetti {
        var x: Float
        var y: Float
        var vx: Float
        var vy: Float
        var color: UInt32
        var size: Int
    }

    // MARK: - Constants and tables

    private static let focal: Float = 210
    private static let maxDist: Float = 200
    private static let camBack: Float = 6.8
    private static let camUp: Float = 3.6
    private static let nSp: Int = FluffSpecies.all.count
    private static let sunAz: Float = 1.2

    private static let goalTitles: [String] = [
        "BEFRIEND 3 CREATURES", "BEFRIEND 8 CREATURES", "BEFRIEND 15 CREATURES", "FIND A SHINY FRIEND",
        "VISIT ALL 3 REGIONS", "LEVEL UP A FRIEND", "ONE FRIEND OF EACH TYPE", "BEFRIEND 20 CREATURES"
    ]
    private static let goalRewards: [String] = [
        "OPENS CRYSTAL HOLLOW + SUN HAT", "FLOWER CROWN + 5 TREATS", "BIGGER STAMINA + BEANIE", "STAR BOW + 3 TREATS",
        "RAINBOW CAPE", "BIGGER STAMINA + 4 TREATS", "GOLDEN CROWN", "SPARKLY TREAT BASKET"
    ]
    private static let hatNames: [String] = ["EXPLORER CAP", "SUN HAT", "FLOWER CROWN", "PROPELLER BEANIE", "STAR BOW", "GOLDEN CROWN"]

    private static let fogTab: [Int] = {
        var a = [Int](repeating: 0, count: 256)
        let start: Float = 40
        let span: Float = Fluffwood64.maxDist - start
        for i in 0..<256 {
            let z: Float = Float(i)
            if z <= start { continue }
            let t: Float = FluffMath.clampF((z - start) / span, 0, 1)
            let f: Float = t * (0.35 + 0.65 * t)
            a[i] = Int(f * 256)
        }
        return a
    }()

    private static let shimmerTab: [Int] = {
        var a = [Int](repeating: 0, count: 32)
        for k in 0..<32 {
            let v: Float = sin(Float(k) / 32.0 * 2 * Float.pi)
            a[k] = Int(v * 12) + 6
        }
        return a
    }()

    private static let waterTab: [UInt32] = {
        var a = [UInt32](repeating: 0, count: 16)
        for i in 0..<16 {
            let t: Float = Float(i) / 15.0
            let r: Float = FluffMath.lerp(170, 70, t)
            let g: Float = FluffMath.lerp(244, 156, t)
            let b: Float = FluffMath.lerp(232, 228, t)
            a[i] = FluffMath.rgb(r, g, b)
        }
        return a
    }()

    private static let starAz: [Float] = {
        var a = [Float](repeating: 0, count: 70)
        for i in 0..<70 { a[i] = (FluffWorld.hash01(i, 3, 91) - 0.5) * 2 * Float.pi }
        return a
    }()
    private static let starEl: [Float] = {
        var a = [Float](repeating: 0, count: 70)
        for i in 0..<70 { a[i] = FluffWorld.hash01(i, 7, 92) }
        return a
    }()

    private static let confettiColors: [UInt32] = [
        TrueColorBuffer.rgb(255, 120, 160), TrueColorBuffer.rgb(255, 214, 90), TrueColorBuffer.rgb(120, 220, 255),
        TrueColorBuffer.rgb(160, 240, 140), TrueColorBuffer.rgb(200, 150, 255), TrueColorBuffer.rgb(255, 255, 255)
    ]
    private static let treatColors: [UInt32] = [
        TrueColorBuffer.rgb(240, 80, 80), TrueColorBuffer.rgb(250, 190, 60), TrueColorBuffer.rgb(240, 212, 160)
    ]
    private static let typeColors: [UInt32] = [
        TrueColorBuffer.rgb(110, 210, 110), TrueColorBuffer.rgb(90, 170, 255), TrueColorBuffer.rgb(255, 140, 70),
        TrueColorBuffer.rgb(150, 200, 255), TrueColorBuffer.rgb(255, 200, 90)
    ]
    private static let wispColors: [UInt32] = [
        TrueColorBuffer.rgb(255, 170, 210), TrueColorBuffer.rgb(255, 230, 120), TrueColorBuffer.rgb(160, 210, 255),
        TrueColorBuffer.rgb(200, 170, 255)
    ]

    private static let cWhite: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
    private static let cInk: UInt32 = TrueColorBuffer.rgb(70, 52, 96)
    private static let cShadow: UInt32 = TrueColorBuffer.rgb(60, 40, 90)
    private static let cPink: UInt32 = TrueColorBuffer.rgb(255, 150, 190)
    private static let cGold: UInt32 = TrueColorBuffer.rgb(255, 214, 80)
    private static let cMint: UInt32 = TrueColorBuffer.rgb(140, 225, 170)
    private static let cPanel: UInt32 = TrueColorBuffer.rgb(255, 250, 255)

    // MARK: - State

    private let world: FluffWorld = FluffWorld.shared
    private var rng = Rng()
    private var phase: Phase = .title
    private var frame: Int = 0
    private var hasSave: Bool = false

    // player
    private var px: Float = 64
    private var py: Float = 70
    private var pzBase: Float = 8
    private var jh: Float = 0
    private var jv: Float = 0
    private var heading: Float = 0.3
    private var camHeading: Float = 0.3
    private var turnVel: Float = 0
    private var speed: Float = 0
    private var walkPhase: Float = 0
    private var moving: Bool = false
    private var sprinting: Bool = false
    private var gliding: Bool = false
    private var stamina: Float = 100
    private var exhausted: Bool = false
    private var stillT: Int = 0
    private var walkedDist: Float = 0
    private var sprintFrames: Int = 0
    private var camBackNow: Float = 14
    private var lastCam = FluffCam()

    // collection and progress
    private var caught = [Bool](repeating: false, count: FluffSpecies.all.count)
    private var shinyOwned = [Bool](repeating: false, count: FluffSpecies.all.count)
    private var fp = [Int](repeating: 0, count: FluffSpecies.all.count)
    private var treats = [Int](repeating: 0, count: 3)
    private var goalDone = [Bool](repeating: false, count: 8)
    private var accUnlocked = [Bool](repeating: false, count: 7)
    private var hat: Int = 0
    private var companion: Int = -1
    private var companionShiny: Bool = false
    private var visited = [Bool](repeating: false, count: 3)
    private var tod: Float = 0.34

    // world state
    private var creatures: [FluffCreature] = []
    private var nextUid: Int = 1
    private var particles: [Particle] = []
    private var floaters: [Floater] = []
    private var pickups: [Pickup] = []
    private var wisps: [Wisp] = []
    private var clouds: [Cloud] = []
    private var proj = Projectile()
    private var propStock: [Int] = []
    private var propRegrow: [Int] = []
    private var targetIdx: Int = -1
    private var drawList: [DrawItem] = []
    private var uiConfetti: [UiConfetti] = []

    // companion
    private var cmx: Float = 62
    private var cmy: Float = 70
    private var cmHop: Float = 0
    private var cmMoving: Bool = false

    // powers
    private var powerT: Int = 0
    private var powerCool: Int = 0
    private var lastBFrame: Int = -100
    private var markers: [(Float, Float, Int)] = []

    // messages
    private var toast: String = ""
    private var toastT: Int = 0
    private var hintStep: Int = 0
    private var hintT: Int = 0
    private var shakenOnce: Bool = false
    private var goalBanner: String = ""
    private var goalBannerT: Int = 0

    // card
    private var cardSp: Int = 0
    private var cardShiny: Bool = false
    private var cardT: Int = 0
    private var cardLevelUp: Bool = false
    private var pendingCards: [(Int, Bool, Bool)] = []

    // book
    private var bookCursor: Int = 0
    private var bookScroll: Int = 0
    private var detailSp: Int = 0

    // light
    private var sunH: Float = 1
    private var dayF: Float = 1
    private var nightF: Float = 0
    private var tintR: Int = 256
    private var tintG: Int = 256
    private var tintB: Int = 256
    private var horR: Int = 208
    private var horG: Int = 234
    private var horB: Int = 252
    private var zenR: Int = 96
    private var zenG: Int = 168
    private var zenB: Int = 240

    // pointer
    private var ptConsumed: Bool = false
    private var ptSprint: Bool = false
    private var ptLastReleaseFrame: Int = -100
    private var ptHoldFrames: Int = 0
    private var ptDownPrev: Bool = false

    override var wantsPointer: Bool { return true }

    override var score: Int {
        var friends = 0
        var levels = 0
        var shinies = 0
        for i in 0..<Fluffwood64.nSp {
            if caught[i] {
                friends += 1
                levels += level(i) - 1
            }
            if shinyOwned[i] { shinies += 1 }
        }
        var stars = 0
        for g in goalDone where g { stars += 1 }
        var reg = 0
        for v in visited where v { reg += 1 }
        let disc: Int = reg * 20 + shinies * 50 + levels * 10
        return friends * 100 + stars * 250 + disc
    }

    override init() {
        super.init()
        resetWorldState()
        phase = .title
    }

    override func start() {
        playMusic(Tunes.chill)
    }

    // MARK: - Setup

    private func resetWorldState() {
        px = world.spawnX
        py = world.spawnY
        pzBase = max(world.height(px, py), FluffWorld.waterLevel)
        heading = 0.3
        camHeading = 0.3
        cmx = px - 2
        cmy = py
        propStock = [Int](repeating: 0, count: world.props.count)
        propRegrow = [Int](repeating: 0, count: world.props.count)
        for i in 0..<world.props.count {
            let k = world.props[i].kind
            if k == FluffKind.bush || k == FluffKind.hive || k == FluffKind.shells {
                propStock[i] = 2 + rng.int(2)
            }
        }
        clouds = []
        for i in 0..<9 {
            let az: Float = Float(i) * 0.7 + Float(rng.unit()) * 0.4
            let el: Float = 28 + Float(rng.unit()) * 70
            let sz: Float = 0.8 + Float(rng.unit()) * 0.9
            let sp: Float = 0.0002 + Float(rng.unit()) * 0.0003
            clouds.append(Cloud(az: az, el: el, size: sz, speed: sp))
        }
        wisps = []
        for _ in 0..<26 {
            let a: Float = Float(rng.unit()) * 2 * Float.pi
            let d: Float = Float(rng.unit()) * 45
            let w = Wisp(x: px + cos(a) * d, y: py + sin(a) * d, phase: Float(rng.unit()) * 6.28,
                         vx: (Float(rng.unit()) - 0.5) * 0.04, vy: (Float(rng.unit()) - 0.5) * 0.04, hue: rng.int(4))
            wisps.append(w)
        }
        creatures = []
        spawnInitialCreatures()
        drawList.reserveCapacity(900)
        particles.reserveCapacity(300)
    }

    private func spawnInitialCreatures() {
        // the starter friend, a few steps ahead
        let sx: Float = px + cos(heading) * 11
        let sy: Float = py + sin(heading) * 11 + 3
        addCreature(0, false, sx, sy)
        for _ in 0..<9 {
            let a: Float = Float(rng.unit()) * 2 * Float.pi
            let d: Float = 14 + Float(rng.unit()) * 40
            trySpawnAt(px + cos(a) * d, py + sin(a) * d, announce: false)
        }
    }

    // MARK: - Helpers

    private func level(_ i: Int) -> Int {
        if i < 0 || i >= fp.count { return 1 }
        let f = fp[i]
        if f >= 14 { return 5 }
        if f >= 9 { return 4 }
        if f >= 5 { return 3 }
        if f >= 2 { return 2 }
        return 1
    }

    private func caughtCount() -> Int {
        var n = 0
        for c in caught where c { n += 1 }
        return n
    }

    private func starCount() -> Int {
        var n = 0
        for g in goalDone where g { n += 1 }
        return n
    }

    private func staminaMax() -> Float {
        var m: Float = 100
        if goalDone[2] { m += 40 }
        if goalDone[5] { m += 40 }
        return m
    }

    private func companionType() -> Int {
        if companion < 0 || companion >= Fluffwood64.nSp { return -1 }
        return FluffSpecies.all[companion].type
    }

    private func showToast(_ s: String, _ frames: Int) {
        toast = s
        toastT = frames
    }

    private func timeCode() -> Int {
        if sunH > 0.25 { return 1 }
        if sunH < -0.15 { return 2 }
        return 3
    }

    private func groundAt(_ x: Float, _ y: Float) -> Float {
        return world.height(x, y)
    }

    private func dist2(_ x: Float, _ y: Float, _ x2: Float, _ y2: Float) -> Float {
        let dx: Float = FluffMath.wrapDelta(x2 - x)
        let dy: Float = FluffMath.wrapDelta(y2 - y)
        return (dx * dx + dy * dy).squareRoot()
    }

    private func spawnP(_ kind: Int, _ x: Float, _ y: Float, _ z: Float, _ vx: Float, _ vy: Float, _ vz: Float,
                        _ life: Int, _ color: UInt32, _ size: Float) {
        if particles.count >= 280 { return }
        particles.append(Particle(x: x, y: y, z: z, vx: vx, vy: vy, vz: vz, life: life, maxLife: life, kind: kind, color: color, size: size))
    }

    private func addFloater(_ text: String, _ x: Float, _ y: Float, _ z: Float, _ color: UInt32) {
        if floaters.count > 12 { floaters.removeFirst() }
        floaters.append(Floater(text: text, x: x, y: y, z: z, life: 70, color: color))
    }

    private func burst(_ x: Float, _ y: Float, _ z: Float, _ count: Int, _ kind: Int, _ spread: Float) {
        for _ in 0..<count {
            let a: Float = Float(rng.unit()) * 2 * Float.pi
            let sp: Float = (0.01 + Float(rng.unit()) * spread)
            let vz: Float = 0.04 + Float(rng.unit()) * 0.08
            let col: UInt32 = Fluffwood64.confettiColors[rng.int(6)]
            spawnP(kind, x, y, z, cos(a) * sp, sin(a) * sp, vz, 50 + rng.int(40), col, 0.22)
        }
    }

    // MARK: - Creatures

    @discardableResult
    private func addCreature(_ sp: Int, _ shiny: Bool, _ x: Float, _ y: Float) -> Int {
        let wx: Float = FluffMath.wrap(x)
        let wy: Float = FluffMath.wrap(y)
        var c = FluffCreature(uid: nextUid, sp: sp, shiny: shiny, x: wx, y: wy, gz: world.height(wx, wy),
                              heading: Float(rng.unit()) * 6.28, state: FluffState.idle, timer: 60 + rng.int(120),
                              tx: wx, ty: wy, phase: Float(rng.unit()) * 6.28)
        c.blink = rng.int(200)
        nextUid += 1
        creatures.append(c)
        return creatures.count - 1
    }

    private func pickSpecies(_ region: Int) -> Int {
        let tc = timeCode()
        var weights = [Float](repeating: 0, count: Fluffwood64.nSp)
        var total: Float = 0
        for i in 0..<Fluffwood64.nSp {
            let s = FluffSpecies.all[i]
            if s.region != region { continue }
            var w: Float = s.rarity == 0 ? 10 : (s.rarity == 1 ? 4 : 1)
            if s.time != 0 {
                if s.time == tc { w *= 3 } else if s.rarity == 2 { w = 0 } else { w *= 0.2 }
            } else if s.rarity == 2 {
                w *= 0.5
            }
            weights[i] = w
            total += w
        }
        if total <= 0 { return -1 }
        var r: Float = Float(rng.unit()) * total
        for i in 0..<Fluffwood64.nSp {
            r -= weights[i]
            if r <= 0 && weights[i] > 0 { return i }
        }
        return -1
    }

    private func trySpawnAt(_ x: Float, _ y: Float, announce: Bool) {
        let wx: Float = FluffMath.wrap(x)
        let wy: Float = FluffMath.wrap(y)
        let g: Float = world.height(wx, wy)
        let region = world.region(wx, wy)
        if region == 2 && !goalDone[0] { return }
        let sp = pickSpecies(region)
        if sp < 0 { return }
        let species = FluffSpecies.all[sp]
        if g < FluffWorld.waterLevel + 0.4 && species.type != 1 { return }
        if g < FluffWorld.waterLevel - 0.8 { return }
        let shinyChance: Int = species.rarity == 2 ? 10 : 4
        let shiny: Bool = rng.chance(shinyChance)
        let idx = addCreature(sp, shiny, wx, wy)
        if announce && (species.rarity == 2 || shiny) && idx >= 0 {
            creatures[idx].announced = true
            play(.coin)
            showToast(shiny ? "A SPARKLY SHINY FRIEND APPEARED!" : "A RARE FRIEND APPEARED! FOLLOW THE SPARKLES!", 220)
        }
    }

    private func maintainCreatures() {
        // despawn far ones
        var i = 0
        while i < creatures.count {
            let c = creatures[i]
            let d = dist2(px, py, c.x, c.y)
            if d > 115 && c.state != FluffState.joy {
                creatures.remove(at: i)
                continue
            }
            i += 1
        }
        if creatures.count < 13 {
            let a: Float = Float(rng.unit()) * 2 * Float.pi
            let d: Float = 28 + Float(rng.unit()) * 55
            trySpawnAt(px + cos(a) * d, py + sin(a) * d, announce: true)
        }
    }

    private func updateCreatures() {
        let pspeed: Float = speed
        var idx = 0
        while idx < creatures.count {
            var c = creatures[idx]
            c.age += 1
            c.blink += 1
            let dpx: Float = FluffMath.wrapDelta(px - c.x)
            let dpy: Float = FluffMath.wrapDelta(py - c.y)
            let d: Float = (dpx * dpx + dpy * dpy).squareRoot()
            let sp = FluffSpecies.all[c.sp]
            var moveSpeed: Float = 0
            var wantRemove = false
            // startle
            if sprinting && d < 11 && c.state != FluffState.joy && c.state != FluffState.flee && c.state != FluffState.eating {
                c.state = FluffState.flee
                c.timer = 90
            }
            switch c.state {
            case FluffState.idle:
                c.timer -= 1
                if stillT > 70 && treatTotal() > 0 && d < 26 && d > 4 && phase == .play {
                    c.state = FluffState.curious
                    c.timer = 420
                } else if c.timer <= 0 {
                    let r = rng.int(100)
                    let nightMismatch: Bool = (sp.time == 1 && timeCode() == 2) || (sp.time == 2 && timeCode() == 1)
                    if nightMismatch && r < 55 {
                        c.state = FluffState.nap
                        c.timer = 300 + rng.int(300)
                    } else if r < 55 {
                        let a: Float = Float(rng.unit()) * 2 * Float.pi
                        let dd: Float = 4 + Float(rng.unit()) * 9
                        c.tx = c.x + cos(a) * dd
                        c.ty = c.y + sin(a) * dd
                        c.state = FluffState.wander
                        c.timer = 400
                    } else if r < 68 {
                        c.state = FluffState.nap
                        c.timer = 200 + rng.int(200)
                    } else if r < 85 {
                        let p = nearestPartner(idx)
                        if p >= 0 {
                            c.state = FluffState.play
                            c.partner = creatures[p].uid
                            c.timer = 240
                        } else {
                            c.timer = 80 + rng.int(100)
                        }
                    } else {
                        c.timer = 60 + rng.int(120)
                    }
                }
            case FluffState.wander:
                c.timer -= 1
                let tdx: Float = FluffMath.wrapDelta(c.tx - c.x)
                let tdy: Float = FluffMath.wrapDelta(c.ty - c.y)
                let td: Float = (tdx * tdx + tdy * tdy).squareRoot()
                if td < 0.6 || c.timer <= 0 {
                    c.state = FluffState.idle
                    c.timer = 90 + rng.int(150)
                } else {
                    c.heading = atan2(tdy, tdx)
                    moveSpeed = 0.022
                }
            case FluffState.nap:
                c.timer -= 1
                if c.timer % 70 == 5 {
                    addFloater("Z", c.x, c.y, c.gz + 1.8, TrueColorBuffer.rgb(200, 220, 255))
                }
                if c.timer <= 0 || (d < 3.0 && pspeed > 4) {
                    c.state = FluffState.idle
                    c.timer = 60
                }
            case FluffState.play:
                c.timer -= 1
                var found = false
                for o in creatures where o.uid == c.partner {
                    found = true
                    let odx: Float = FluffMath.wrapDelta(o.x - c.x)
                    let ody: Float = FluffMath.wrapDelta(o.y - c.y)
                    let od: Float = (odx * odx + ody * ody).squareRoot()
                    c.heading = atan2(ody, odx)
                    if od > 2.6 { moveSpeed = 0.03 } else if od < 1.5 {
                        c.heading += Float.pi
                        moveSpeed = 0.02
                    }
                    if c.timer % 40 == 0 { spawnP(2, c.x, c.y, c.gz + 1.6, 0, 0, 0.03, 50, Fluffwood64.cPink, 0.25) }
                }
                if !found || c.timer <= 0 {
                    c.state = FluffState.idle
                    c.timer = 80
                }
                c.hopT += 0.18
            case FluffState.flee:
                c.timer -= 1
                c.heading = atan2(-dpy, -dpx)
                moveSpeed = 0.085
                if c.timer <= 0 || d > 40 {
                    c.state = FluffState.idle
                    c.timer = 100
                }
            case FluffState.curious:
                c.timer -= 1
                c.heading = atan2(dpy, dpx)
                if d > 3.4 { moveSpeed = 0.032 }
                if c.timer <= 0 || stillT < 20 || treatTotal() == 0 {
                    c.state = FluffState.idle
                    c.timer = 80
                }
            case FluffState.joy:
                c.joyT -= 1
                c.hopT += 0.3
                if c.joyT % 12 == 0 {
                    spawnP(2, c.x, c.y, c.gz + 1.5, (Float(rng.unit()) - 0.5) * 0.03, (Float(rng.unit()) - 0.5) * 0.03, 0.04, 50, Fluffwood64.cPink, 0.28)
                }
                if c.joyT <= 0 {
                    burst(c.x, c.y, c.gz + 1.0, 14, 1, 0.05)
                    wantRemove = true
                }
            default:
                // eating
                c.timer -= 1
                if c.timer <= 0 {
                    c.state = FluffState.flee
                    c.timer = 80
                }
            }

            if moveSpeed > 0 {
                let nx: Float = c.x + cos(c.heading) * moveSpeed
                let ny: Float = c.y + sin(c.heading) * moveSpeed
                let ng: Float = world.height(nx, ny)
                let wl: Float = FluffWorld.waterLevel
                let ok: Bool = ng > wl + 0.15 || (sp.type == 1 && ng > wl - 0.8)
                var gateBlock = false
                if !goalDone[0] && world.region(nx, ny) == 2 { gateBlock = true }
                if ok && !gateBlock {
                    c.x = FluffMath.wrap(nx)
                    c.y = FluffMath.wrap(ny)
                    c.hopT += moveSpeed * 7
                    let dxm: Float = cos(c.heading - lastCam.fx * 0)
                    c.face = dxm >= 0 ? 1 : -1
                } else if c.state != FluffState.flee {
                    c.state = FluffState.idle
                    c.timer = 60
                } else {
                    c.heading += 1.5
                }
            }
            c.gz = max(world.height(c.x, c.y), FluffWorld.waterLevel - 0.3)
            if c.announced && c.age % 18 == 0 {
                spawnP(1, c.x + (Float(rng.unit()) - 0.5) * 0.8, c.y + (Float(rng.unit()) - 0.5) * 0.8, c.gz + 1,
                       0, 0, 0.12, 80, Fluffwood64.cGold, 0.3)
            }
            if wantRemove {
                creatures.remove(at: idx)
                continue
            }
            creatures[idx] = c
            idx += 1
        }
    }

    private func nearestPartner(_ i: Int) -> Int {
        let c = creatures[i]
        var best = -1
        var bd: Float = 16
        for j in 0..<creatures.count where j != i {
            let o = creatures[j]
            if o.state != FluffState.idle && o.state != FluffState.wander { continue }
            let d = dist2(c.x, c.y, o.x, o.y)
            if d < bd { bd = d; best = j }
        }
        return best
    }

    private func treatTotal() -> Int {
        return treats[0] + treats[1] + treats[2]
    }

    // MARK: - Update

    override func update(_ input: InputState) {
        frame += 1
        if toastT > 0 { toastT -= 1 }
        if goalBannerT > 0 { goalBannerT -= 1 }
        var inp = input
        let pt = input.pointer
        let tapped: Bool = pt.pressed
        // pointer-driven synthetic buttons while playing
        if phase == .play {
            applyPointerSteering(&inp, pt, tapped)
        } else {
            ptDownPrev = pt.down
        }
        switch phase {
        case .title: updateTitle(inp, pt, tapped)
        case .play: updatePlay(inp)
        case .card: updateCard(inp, tapped)
        case .book: updateBook(inp, pt, tapped)
        case .detail: updateDetail(inp, tapped)
        case .quests: updateQuests(inp, pt, tapped)
        }
    }

    private func stepTime() {
        tod += 1.0 / 14400.0
        if tod >= 1 { tod -= 1 }
        for i in 0..<clouds.count { clouds[i].az += clouds[i].speed }
    }

    // MARK: title

    private func updateTitle(_ input: InputState, _ pt: PointerState, _ tapped: Bool) {
        stepTime()
        heading = FluffMath.wrapAngle(heading + 0.0035)
        camHeading = heading
        camBackNow = 13
        updateCreatures()
        updateAmbient()
        updateParticles()
        if frame % 40 == 0 { maintainCreatures() }
        if input.aPressed || input.startPressed || tapped {
            phase = .play
            heading = 0.3
            camHeading = 0.3
            camBackNow = 13
            ptConsumed = true
            if !hasSave {
                treats[0] = 3
                treats[1] = 1
            }
            hintStep = hasSave ? 5 : 0
            hintT = 0
            play(.confirm)
        }
    }

    // MARK: pointer steering

    private func applyPointerSteering(_ inp: inout InputState, _ pt: PointerState, _ tapped: Bool) {
        if tapped {
            ptConsumed = handleTap(pt.x, pt.y)
            ptHoldFrames = 0
            ptSprint = !ptConsumed && (frame - ptLastReleaseFrame) < 22
        }
        if pt.released {
            if !ptConsumed && ptHoldFrames < 14 { ptLastReleaseFrame = frame }
            ptSprint = false
        }
        if pt.down {
            ptHoldFrames += 1
            if !ptConsumed && ptHoldFrames > 3 {
                let fx: Int = pt.x - 160
                if fx < -26 { inp.held.insert(.left) }
                if fx > 26 { inp.held.insert(.right) }
                if pt.y < 215 {
                    inp.held.insert(.up)
                } else if pt.y > 252 {
                    inp.held.insert(.down)
                }
                if ptSprint { inp.held.insert(.b) }
            }
        }
        ptDownPrev = pt.down
    }

    private func projectScreen(_ x: Float, _ y: Float, _ z: Float) -> (Float, Float, Float) {
        let cam = lastCam
        let dx: Float = FluffMath.wrapDelta(x - cam.x)
        let dy: Float = FluffMath.wrapDelta(y - cam.y)
        let zc: Float = dx * cam.fx + dy * cam.fy
        if zc < 0.5 { return (-999, -999, 0) }
        let xr: Float = dx * cam.rx + dy * cam.ry
        let sx: Float = 160 + xr * Fluffwood64.focal / zc
        let sy: Float = cam.horizon + (cam.alt - z) * Fluffwood64.focal / zc
        return (sx, sy, zc)
    }

    /// Handles a fresh touch in play. Returns true if it hit something (so holding does not walk).
    private func handleTap(_ tx: Int, _ ty: Int) -> Bool {
        // big buttons
        if tx < 52 && ty > 236 {
            openBook()
            return true
        }
        if tx > 268 && ty > 236 {
            phase = .quests
            play(.select)
            return true
        }
        // creatures
        var bestI = -1
        var bestZ: Float = 1000
        for i in 0..<creatures.count {
            let c = creatures[i]
            if c.state == FluffState.joy { continue }
            let sp = FluffSpecies.all[c.sp]
            let p = projectScreen(c.x, c.y, c.gz)
            if p.2 <= 0.5 || p.2 > 90 { continue }
            let s: Float = Fluffwood64.focal / p.2
            let r: Float = 0.9 * sp.size * s
            let hw: Float = r * 1.5 + 16
            let top: Float = p.1 - r * 2.6 - 16
            let fx: Float = Float(tx)
            let fy: Float = Float(ty)
            if abs(fx - p.0) < hw && fy > top && fy < p.1 + 14 {
                if p.2 < bestZ { bestZ = p.2; bestI = i }
            }
        }
        if bestI >= 0 {
            targetIdx = bestI
            touchThrow(bestI)
            return true
        }
        // props to shake
        let cx0: Int = Int(px) >> 4
        let cy0: Int = Int(py) >> 4
        var bestP = -1
        var bestPz: Float = 1000
        for dyc in -2...2 {
            for dxc in -2...2 {
                let ci = FluffWorld.cellIndex(cx0 + dxc, cy0 + dyc)
                for pi in world.grid[ci] {
                    let pr = world.props[pi]
                    if pr.kind == FluffKind.flower || pr.kind == FluffKind.mushroom { continue }
                    let d = dist2(px, py, pr.x, pr.y)
                    if d > 22 { continue }
                    let p = projectScreen(pr.x, pr.y, pr.gz)
                    if p.2 < 1 { continue }
                    let s: Float = Fluffwood64.focal / p.2
                    let hw: Float = pr.size * s * 1.6 + 8
                    let hh: Float = pr.size * s * 4.5 + 8
                    if abs(Float(tx) - p.0) < hw && Float(ty) < p.1 + 8 && Float(ty) > p.1 - hh {
                        if p.2 < bestPz { bestPz = p.2; bestP = pi }
                    }
                }
            }
        }
        if bestP >= 0 {
            let pr = world.props[bestP]
            if dist2(px, py, pr.x, pr.y) > 4.6 {
                showToast("WALK A LITTLE CLOSER, THEN TAP AGAIN!", 120)
            } else {
                shakeProp(bestP)
            }
            return true
        }
        return false
    }

    private func touchThrow(_ i: Int) {
        if i < 0 || i >= creatures.count { return }
        let c = creatures[i]
        let d = dist2(px, py, c.x, c.y)
        if d > 34 {
            showToast("GET CLOSER TO THROW A TREAT!", 100)
            return
        }
        throwTreat(i)
    }

    // MARK: play

    private func openBook() {
        phase = .book
        bookCursor = max(0, min(bookCursor, Fluffwood64.nSp - 1))
        play(.select)
    }

    private func updatePlay(_ input: InputState) {
        if input.selectPressed { openBook(); return }
        if input.startPressed { phase = .quests; play(.select); return }
        stepTime()
        movePlayer(input)
        updateCreatures()
        if frame % 30 == 0 { maintainCreatures() }
        updateTargeting()
        if input.aPressed { actionA() }
        updateProjectile()
        updateCompanion()
        updatePowers(input)
        updatePickups()
        updateAmbient()
        updateParticles()
        updateRegrow()
        if frame % 20 == 0 { checkGoals() }
        updateHints()
        // floaters
        var i = 0
        while i < floaters.count {
            floaters[i].life -= 1
            floaters[i].z += 0.02
            if floaters[i].life <= 0 { floaters.remove(at: i) } else { i += 1 }
        }
        // region discovery
        let r = world.region(px, py)
        if r >= 0 && r < 3 && !visited[r] {
            visited[r] = true
            let names = ["SUNNY MEADOW", "SHELL BEACH", "CRYSTAL HOLLOW"]
            showToast("WELCOME TO " + names[r] + "!", 200)
            play(.coin)
        }
    }

    private func movePlayer(_ input: InputState) {
        let turnT: Float = Float(input.dx) * 0.040
        turnVel += (turnT - turnVel) * 0.2
        heading = FluffMath.wrapAngle(heading + turnVel)
        var fwdIn: Float = 0
        if input.up && !input.down { fwdIn = 1 }
        if input.down && !input.up { fwdIn = -0.55 }
        let maxSt: Float = staminaMax()
        let wantSprint: Bool = input.b && fwdIn > 0 && !exhausted && stamina > 1
        sprinting = wantSprint
        let ground: Float = world.height(px, py)
        let wl: Float = FluffWorld.waterLevel
        let inWater: Bool = ground < wl - 0.05
        var tgt: Float = fwdIn * 8.0
        if sprinting { tgt *= 1.75 }
        let ct = companionType()
        let waterPower: Bool = ct == 1 && powerT > 0
        if inWater {
            tgt *= waterPower ? 1.7 : 0.55
        } else if waterPower {
            tgt *= 1.15
        }
        gliding = false
        if input.a && jh > 0.05 && jv < 0 && ct == 3 {
            gliding = true
            jv = max(jv, -0.017)
            if tgt < 5 { tgt = 5 }
            tgt *= 1.35
        }
        speed += (tgt - speed) * 0.12
        if abs(speed) < 0.05 { speed = 0 }
        moving = abs(speed) > 0.6 && jh < 0.05
        let step: Float = speed / 60.0
        var nx: Float = px + cos(heading) * step
        var ny: Float = py + sin(heading) * step
        // soft collisions
        let cx0: Int = Int(FluffMath.wrap(nx)) >> 4
        let cy0: Int = Int(FluffMath.wrap(ny)) >> 4
        for dyc in -1...1 {
            for dxc in -1...1 {
                let ci = FluffWorld.cellIndex(cx0 + dxc, cy0 + dyc)
                for pi in world.grid[ci] {
                    let pr = world.props[pi]
                    let rad: Float = FluffWorld.solidRadius(pr.kind, pr.size)
                    if rad <= 0 { continue }
                    if jh > 2.4 && pr.kind != FluffKind.crystal { continue }
                    let ddx: Float = FluffMath.wrapDelta(nx - pr.x)
                    let ddy: Float = FluffMath.wrapDelta(ny - pr.y)
                    let dd: Float = (ddx * ddx + ddy * ddy).squareRoot()
                    let lim: Float = rad + 0.45
                    if dd < lim && dd > 0.001 {
                        nx = pr.x + ddx / dd * lim
                        ny = pr.y + ddy / dd * lim
                    }
                }
            }
        }
        // gate
        if !goalDone[0] && world.region(nx, ny) == 2 {
            nx = px
            ny = py
            speed *= 0.5
            if frame % 40 == 0 {
                showToast("THE CRYSTAL GATE IS SLEEPING. BEFRIEND 3 CREATURES!", 160)
                burst(px + cos(heading) * 1.5, py + sin(heading) * 1.5, pzBase + 1.2, 6, 1, 0.03)
            }
        }
        if speed != 0 {
            walkedDist += abs(step)
        }
        px = FluffMath.wrap(nx)
        py = FluffMath.wrap(ny)
        if sprinting {
            sprintFrames += 1
            stamina -= 0.55
            if stamina <= 0 { stamina = 0; exhausted = true }
        } else {
            stamina = min(maxSt, stamina + 0.35)
            if exhausted && stamina > maxSt * 0.3 { exhausted = false }
        }
        if abs(speed) < 0.3 { stillT += 1 } else { stillT = 0 }
        // vertical
        let g2: Float = world.height(px, py)
        let target: Float = max(g2, wl - 0.7)
        if jh <= 0 && jv <= 0 {
            pzBase += (target - pzBase) * 0.4
        } else {
            pzBase += (target - pzBase) * 0.2
        }
        if jh > 0 || jv > 0 {
            jh += jv
            jv -= 0.012
            if jh <= 0 {
                jh = 0
                jv = 0
                for _ in 0..<4 {
                    spawnP(0, px, py, pzBase, (Float(rng.unit()) - 0.5) * 0.05, (Float(rng.unit()) - 0.5) * 0.05, 0.01, 24, TrueColorBuffer.rgb(240, 230, 200), 0.3)
                }
                play(.thud)
            }
        }
        // footsteps
        if moving {
            let before: Float = walkPhase
            walkPhase += abs(speed) * 0.032
            let a: Int = Int(before / Float.pi)
            let b: Int = Int(walkPhase / Float.pi)
            if a != b {
                if inWater {
                    for _ in 0..<3 {
                        spawnP(4, px, py, wl, (Float(rng.unit()) - 0.5) * 0.06, (Float(rng.unit()) - 0.5) * 0.06, 0.05, 26, TrueColorBuffer.rgb(230, 250, 255), 0.2)
                    }
                } else {
                    let n: Int = sprinting ? 3 : 1
                    for _ in 0..<n {
                        spawnP(0, px - cos(heading) * 0.3, py - sin(heading) * 0.3, pzBase, (Float(rng.unit()) - 0.5) * 0.03,
                               (Float(rng.unit()) - 0.5) * 0.03, 0.012, 28, TrueColorBuffer.rgb(236, 226, 196), 0.34)
                    }
                }
            }
        } else if jh <= 0 {
            walkPhase *= 0.9
        }
        // camera lag
        let diff: Float = FluffMath.wrapAngle(heading - camHeading)
        camHeading = FluffMath.wrapAngle(camHeading + diff * 0.14)
        camBackNow += (Fluffwood64.camBack - camBackNow) * 0.05
    }

    private func updateTargeting() {
        targetIdx = -1
        var best: Float = 100000
        for i in 0..<creatures.count {
            let c = creatures[i]
            if c.state == FluffState.joy { continue }
            let dx: Float = FluffMath.wrapDelta(c.x - px)
            let dy: Float = FluffMath.wrapDelta(c.y - py)
            let d: Float = (dx * dx + dy * dy).squareRoot()
            if d > 30 || d < 0.4 { continue }
            let ang: Float = abs(FluffMath.wrapAngle(atan2(dy, dx) - heading))
            if ang > 0.62 { continue }
            let sc: Float = d + ang * 14
            if sc < best {
                best = sc
                targetIdx = i
            }
        }
    }

    private func nearestShakeable() -> Int {
        let cx0: Int = Int(px) >> 4
        let cy0: Int = Int(py) >> 4
        var best = -1
        var bd: Float = 3.6
        for dyc in -1...1 {
            for dxc in -1...1 {
                let ci = FluffWorld.cellIndex(cx0 + dxc, cy0 + dyc)
                for pi in world.grid[ci] {
                    let pr = world.props[pi]
                    if pr.kind != FluffKind.bush && pr.kind != FluffKind.hive && pr.kind != FluffKind.shells { continue }
                    let d = dist2(px, py, pr.x, pr.y) - pr.size * 0.4
                    if d < bd {
                        bd = d
                        best = pi
                    }
                }
            }
        }
        return best
    }

    private func actionA() {
        let sh = nearestShakeable()
        var tDist: Float = 1000
        if targetIdx >= 0 && targetIdx < creatures.count {
            tDist = dist2(px, py, creatures[targetIdx].x, creatures[targetIdx].y)
        }
        if sh >= 0 && (targetIdx < 0 || tDist > 9) {
            shakeProp(sh)
            return
        }
        if targetIdx >= 0 {
            throwTreat(targetIdx)
            return
        }
        if jh <= 0.02 {
            jv = 0.22
            jh = 0.01
            play(.jump)
        }
    }

    private func shakeProp(_ idx: Int) {
        if idx < 0 || idx >= world.props.count { return }
        let pr = world.props[idx]
        var k = -1
        if pr.kind == FluffKind.bush { k = 0 }
        if pr.kind == FluffKind.hive { k = 1 }
        if pr.kind == FluffKind.shells { k = 2 }
        if k < 0 {
            showToast("NOTHING TO SHAKE HERE. TRY A BUSH!", 100)
            return
        }
        if propStock[idx] <= 0 {
            showToast("ALL OUT FOR NOW. CHECK BACK SOON!", 110)
            return
        }
        let n: Int = min(propStock[idx], 1 + rng.int(2))
        propStock[idx] -= n
        propRegrow[idx] = 2400
        treats[k] = min(99, treats[k] + n)
        shakenOnce = true
        let names = ["BERRY", "HONEY", "BISCUIT"]
        addFloater("+" + String(n) + " " + names[k], px, py, pzBase + 2.2, Fluffwood64.treatColors[k])
        for _ in 0..<8 {
            spawnP(5, pr.x, pr.y, pr.gz + 2.5, (Float(rng.unit()) - 0.5) * 0.08, (Float(rng.unit()) - 0.5) * 0.08, 0.02,
                   40, TrueColorBuffer.rgb(120, 210, 110), 0.28)
        }
        play(.pickup)
    }

    private func chooseTreat(_ sp: Int) -> Int {
        let fav = FluffSpecies.all[sp].treat
        if treats[fav] > 0 { return fav }
        var best = -1
        var bc = 0
        for k in 0..<3 where treats[k] > bc {
            bc = treats[k]
            best = k
        }
        return best
    }

    private func throwTreat(_ i: Int) {
        if i < 0 || i >= creatures.count { return }
        if proj.active { return }
        let c = creatures[i]
        let k = chooseTreat(c.sp)
        if k < 0 {
            showToast("NO TREATS! SHAKE A BUSH: STAND NEXT TO IT AND PRESS A.", 180)
            play(.blip)
            return
        }
        treats[k] -= 1
        proj = Projectile(active: true, sx: px, sy: py, sz: pzBase + jh + 1.2, x: px, y: py, z: pzBase + 1.2, uid: c.uid, treat: k, t: 0)
        creatures[i].state = FluffState.idle
        creatures[i].timer = 70
        play(.shoot)
    }

    private func updateProjectile() {
        if !proj.active { return }
        proj.t += 1
        var ti = -1
        for j in 0..<creatures.count where creatures[j].uid == proj.uid { ti = j }
        if ti < 0 {
            proj.active = false
            treats[proj.treat] = min(99, treats[proj.treat] + 1)
            return
        }
        let c = creatures[ti]
        let total: Float = 26
        let f: Float = min(1, Float(proj.t) / total)
        let dx: Float = FluffMath.wrapDelta(c.x - proj.sx)
        let dy: Float = FluffMath.wrapDelta(c.y - proj.sy)
        proj.x = proj.sx + dx * f
        proj.y = proj.sy + dy * f
        let tz: Float = c.gz + 0.9
        proj.z = proj.sz + (tz - proj.sz) * f + sin(f * Float.pi) * 2.2
        if proj.t % 2 == 0 {
            spawnP(1, proj.x, proj.y, proj.z, 0, 0, 0.0, 22, Fluffwood64.treatColors[proj.treat], 0.22)
        }
        if proj.t >= 26 {
            proj.active = false
            resolveTreat(ti, proj.treat)
        }
    }

    private func resolveTreat(_ i: Int, _ treat: Int) {
        if i < 0 || i >= creatures.count { return }
        let c = creatures[i]
        let sp = FluffSpecies.all[c.sp]
        let loves: Bool = treat == sp.treat
        var chance: Int = loves ? 100 : (sp.rarity == 0 ? 55 : (sp.rarity == 1 ? 42 : 32))
        chance += min(30, c.fails * 18)
        if rng.chance(chance) {
            befriend(i, loves)
        } else {
            creatures[i].fails += 1
            creatures[i].state = FluffState.eating
            creatures[i].timer = 45
            addFloater("YUM!", c.x, c.y, c.gz + 2.2, Fluffwood64.cGold)
            let names = ["BERRIES", "HONEY", "BISCUITS"]
            showToast(sp.name + " WOULD LOVE " + names[sp.treat] + "!", 170)
            burst(c.x, c.y, c.gz + 1.2, 6, 0, 0.03)
            play(.bounce)
        }
    }

    private func befriend(_ i: Int, _ loved: Bool) {
        let c = creatures[i]
        let sp = c.sp
        let wasNew = !caught[sp]
        let wasLevel = level(sp)
        caught[sp] = true
        let firstShiny: Bool = c.shiny && !shinyOwned[sp]
        if c.shiny { shinyOwned[sp] = true }
        fp[sp] = min(255, fp[sp] + (wasNew ? 1 : (c.shiny ? 3 : 1)))
        let nowLevel = level(sp)
        creatures[i].state = FluffState.joy
        creatures[i].joyT = 80
        creatures[i].announced = false
        burst(c.x, c.y, c.gz + 1.2, 40, 3, 0.07)
        for _ in 0..<8 {
            spawnP(2, c.x + (Float(rng.unit()) - 0.5), c.y + (Float(rng.unit()) - 0.5), c.gz + 1.5,
                   (Float(rng.unit()) - 0.5) * 0.03, (Float(rng.unit()) - 0.5) * 0.03, 0.05 + Float(rng.unit()) * 0.04,
                   70, Fluffwood64.cPink, 0.3)
        }
        play(.powerup)
        if companion < 0 {
            companion = sp
            companionShiny = c.shiny
            cmx = px
            cmy = py
        }
        if wasNew || firstShiny {
            pendingCards.append((sp, c.shiny, nowLevel > wasLevel))
            showToast("NEW FRIEND!", 80)
        } else {
            let lv: Bool = nowLevel > wasLevel
            addFloater(lv ? "LEVEL UP!" : "+FRIENDSHIP", c.x, c.y, c.gz + 2.4, Fluffwood64.cGold)
            showToast(lv ? sp2name(sp) + " IS NOW LEVEL " + String(nowLevel) + "!" : sp2name(sp) + " LIKES YOU MORE!", 150)
        }
    }

    private func sp2name(_ i: Int) -> String {
        if i < 0 || i >= FluffSpecies.all.count { return "FRIEND" }
        return FluffSpecies.all[i].name
    }

    // MARK: companion and powers

    private func updateCompanion() {
        if companion < 0 { return }
        let bx: Float = -cos(heading) * 2.4 - sin(heading) * 1.3
        let by: Float = -sin(heading) * 2.4 + cos(heading) * 1.3
        let tx: Float = px + bx
        let ty: Float = py + by
        let dx: Float = FluffMath.wrapDelta(tx - cmx)
        let dy: Float = FluffMath.wrapDelta(ty - cmy)
        let d: Float = (dx * dx + dy * dy).squareRoot()
        if d > 30 {
            cmx = tx
            cmy = ty
            burst(cmx, cmy, pzBase + 1, 6, 1, 0.03)
        } else {
            cmx = FluffMath.wrap(cmx + dx * 0.06)
            cmy = FluffMath.wrap(cmy + dy * 0.06)
        }
        cmMoving = d > 0.8
        if cmMoving { cmHop += min(0.35, d * 0.06 + 0.08) } else { cmHop *= 0.9 }
    }

    private func updatePowers(_ input: InputState) {
        if input.bPressed {
            if frame - lastBFrame < 20 && powerT <= 0 && powerCool <= 0 {
                activatePower()
            }
            lastBFrame = frame
        }
        if powerT > 0 {
            powerT -= 1
            if powerT == 0 { powerCool = 300 }
            let ct = companionType()
            if ct == 2 && frame % 6 == 0 {
                spawnP(6, px - cos(heading) * 0.8, py - sin(heading) * 0.8, pzBase + 0.1, 0, 0, 0.0, 240,
                       TrueColorBuffer.rgb(255, 190, 90), 0.5)
                if nightF > 0.4 && frame % 30 == 0 { addFloater("WARM", px, py, pzBase + 2.6, TrueColorBuffer.rgb(255, 190, 120)) }
            }
        } else if powerCool > 0 {
            powerCool -= 1
        }
        // markers
        markers.removeAll(keepingCapacity: true)
        if powerT > 0 && frame % 4 == 0 || (powerT > 0 && markers.isEmpty) {
            let ct = companionType()
            if ct == 0 {
                var found = 0
                for i in 0..<world.props.count where found < 6 {
                    if propStock[i] > 0 && world.props[i].kind == FluffKind.bush {
                        let d = dist2(px, py, world.props[i].x, world.props[i].y)
                        if d < 60 {
                            markers.append((world.props[i].x, world.props[i].y, 0))
                            found += 1
                        }
                    }
                }
            } else if ct == 4 {
                for c in creatures where FluffSpecies.all[c.sp].rarity == 2 || c.shiny {
                    if caught[c.sp] && !c.shiny { continue }
                    markers.append((c.x, c.y, 1))
                }
            }
        }
    }

    private func activatePower() {
        let ct = companionType()
        if ct < 0 {
            showToast("BEFRIEND SOMEONE TO GET A COMPANION POWER!", 140)
            return
        }
        switch ct {
        case 3:
            jv = 0.32
            jh = max(jh, 0.02)
            powerT = 1
            showToast("WIND LIFT! HOLD A IN THE AIR TO GLIDE.", 140)
        case 1:
            powerT = 480
            showToast("SPLASH DASH! SWIM SUPER FAST.", 140)
        case 0:
            powerT = 600
            showToast("BERRY SNIFF! FOLLOW THE ARROWS.", 140)
        case 2:
            powerT = 720
            showToast("WARM GLOW! A COSY LIGHT FOLLOWS YOU.", 140)
        default:
            powerT = 480
            showToast("SPARKLE SENSE! RARE FRIENDS SHOW UP.", 140)
        }
        play(.powerup)
        burst(px, py, pzBase + 1.2, 16, 1, 0.05)
    }

    // MARK: pickups, ambient, particles

    private func updatePickups() {
        var i = 0
        while i < pickups.count {
            pickups[i].bob += 1
            let d = dist2(px, py, pickups[i].x, pickups[i].y)
            if d < 1.8 {
                let k = pickups[i].kind
                treats[k] = min(99, treats[k] + 1)
                let names = ["BERRY", "HONEY", "BISCUIT"]
                addFloater("+1 " + names[k], pickups[i].x, pickups[i].y, pzBase + 1.6, Fluffwood64.treatColors[k])
                burst(pickups[i].x, pickups[i].y, pzBase + 0.6, 6, 1, 0.03)
                play(.pickup)
                pickups.remove(at: i)
                continue
            }
            if d > 90 {
                pickups.remove(at: i)
                continue
            }
            i += 1
        }
        if pickups.count < 6 && frame % 90 == 0 {
            let a: Float = Float(rng.unit()) * 2 * Float.pi
            let dd: Float = 10 + Float(rng.unit()) * 45
            let x: Float = FluffMath.wrap(px + cos(a) * dd)
            let y: Float = FluffMath.wrap(py + sin(a) * dd)
            let g = world.height(x, y)
            let r = world.region(x, y)
            if g > FluffWorld.waterLevel + 0.5 && !(r == 2 && !goalDone[0]) {
                var k = rng.int(3)
                if r == 1 && rng.chance(60) { k = 2 }
                pickups.append(Pickup(x: x, y: y, kind: k, bob: rng.int(60)))
            }
        }
    }

    private func updateRegrow() {
        if frame % 30 != 0 { return }
        for i in 0..<propRegrow.count where propRegrow[i] > 0 {
            propRegrow[i] -= 30
            if propRegrow[i] <= 0 {
                propRegrow[i] = 0
                propStock[i] = 3
            }
        }
    }

    private func updateAmbient() {
        for i in 0..<wisps.count {
            wisps[i].phase += 0.05
            wisps[i].vx += (Float(rng.unit()) - 0.5) * 0.004
            wisps[i].vy += (Float(rng.unit()) - 0.5) * 0.004
            wisps[i].vx = FluffMath.clampF(wisps[i].vx, -0.05, 0.05)
            wisps[i].vy = FluffMath.clampF(wisps[i].vy, -0.05, 0.05)
            wisps[i].x = FluffMath.wrap(wisps[i].x + wisps[i].vx)
            wisps[i].y = FluffMath.wrap(wisps[i].y + wisps[i].vy)
            if dist2(px, py, wisps[i].x, wisps[i].y) > 48 {
                let a: Float = heading + (Float(rng.unit()) - 0.5) * 2.0
                let d: Float = 10 + Float(rng.unit()) * 36
                wisps[i].x = FluffMath.wrap(px + cos(a) * d)
                wisps[i].y = FluffMath.wrap(py + sin(a) * d)
            }
        }
        // drifting sparkles in the air
        if frame % 10 == 0 {
            let a: Float = Float(rng.unit()) * 2 * Float.pi
            let d: Float = 4 + Float(rng.unit()) * 26
            let col: UInt32 = nightF > 0.5 ? TrueColorBuffer.rgb(255, 240, 150) : TrueColorBuffer.rgb(255, 255, 255)
            spawnP(1, px + cos(a) * d, py + sin(a) * d, pzBase + 1.0 + Float(rng.unit()) * 3, 0, 0, 0.012, 110, col, 0.2)
        }
    }

    private func updateParticles() {
        var i = 0
        while i < particles.count {
            particles[i].life -= 1
            if particles[i].life <= 0 {
                particles.remove(at: i)
                continue
            }
            let k = particles[i].kind
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].z += particles[i].vz
            if k == 3 || k == 5 {
                particles[i].vz -= 0.002
                particles[i].vx *= 0.99
                particles[i].vy *= 0.99
            } else if k == 0 {
                particles[i].vz *= 0.96
            } else if k == 4 {
                particles[i].vz -= 0.004
            }
            i += 1
        }
    }

    // MARK: goals

    private func checkGoals() {
        let n = caughtCount()
        var types = [Bool](repeating: false, count: 5)
        var anyLevel = false
        var anyShiny = false
        for i in 0..<Fluffwood64.nSp where caught[i] {
            let t = FluffSpecies.all[i].type
            if t >= 0 && t < 5 { types[t] = true }
            if level(i) >= 2 { anyLevel = true }
            if shinyOwned[i] { anyShiny = true }
        }
        var allTypes = true
        for t in types where !t { allTypes = false }
        let allReg: Bool = visited[0] && visited[1] && visited[2]
        let conds: [Bool] = [n >= 3, n >= 8, n >= 15, anyShiny, allReg, anyLevel, allTypes, n >= 20]
        for g in 0..<8 where !goalDone[g] && conds[g] {
            completeGoal(g)
        }
    }

    private func unlockHat(_ h: Int) {
        if h >= 0 && h < accUnlocked.count {
            accUnlocked[h] = true
            if h < 6 { hat = h }
        }
    }

    private func completeGoal(_ g: Int) {
        goalDone[g] = true
        switch g {
        case 0: unlockHat(1)
        case 1:
            unlockHat(2)
            for k in 0..<3 { treats[k] = min(99, treats[k] + 2) }
            treats[0] = min(99, treats[0] + 2)
        case 2:
            unlockHat(3)
            stamina = staminaMax()
        case 3:
            unlockHat(4)
            for k in 0..<3 { treats[k] = min(99, treats[k] + 1) }
        case 4: unlockHat(6)
        case 5:
            for k in 0..<3 { treats[k] = min(99, treats[k] + 1) }
            treats[1] = min(99, treats[1] + 1)
            stamina = staminaMax()
        case 6: unlockHat(5)
        default:
            for k in 0..<3 { treats[k] = min(99, treats[k] + 3) }
        }
        goalBanner = "GOAL COMPLETE! STAR EARNED!"
        goalBannerT = 220
        showToast(Fluffwood64.goalTitles[g] + " " + Fluffwood64.goalRewards[g], 240)
        play(.win)
        burst(px, py, pzBase + 1.5, 40, 3, 0.07)
    }

    // MARK: hints

    private func updateHints() {
        hintT += 1
        switch hintStep {
        case 0:
            if walkedDist > 14 || hintT > 900 { hintStep = 1; hintT = 0 }
        case 1:
            if sprintFrames > 50 || hintT > 500 { hintStep = 2; hintT = 0 }
        case 2:
            if caughtCount() > 0 || hintT > 2400 { hintStep = 3; hintT = 0 }
        case 3:
            if shakenOnce || hintT > 900 { hintStep = 4; hintT = 0 }
        case 4:
            if hintT > 700 { hintStep = 5; hintT = 0 }
        default:
            break
        }
    }

    private func currentHint() -> String {
        switch hintStep {
        case 0: return "DRAG ON THE SCREEN OR USE THE D-PAD TO WALK. LEFT AND RIGHT TURN!"
        case 1: return "HOLD B (OR TAP TWICE AND HOLD) TO SPRINT!"
        case 2: return "WALK UP TO A FLUFFY FRIEND AND PRESS A TO GIVE IT A TREAT!"
        case 3: return "SHAKE A BUSH: STAND NEXT TO IT AND PRESS A TO FIND TREATS."
        case 4: return "SELECT OPENS YOUR FRIEND BOOK. START SHOWS YOUR GOALS."
        default: return ""
        }
    }

    // MARK: card, book, quests

    private func updateCard(_ input: InputState, _ tapped: Bool) {
        cardT += 1
        updateParticles()
        var i = 0
        while i < uiConfetti.count {
            uiConfetti[i].y += uiConfetti[i].vy
            uiConfetti[i].x += uiConfetti[i].vx
            if uiConfetti[i].y > 300 { uiConfetti.remove(at: i) } else { i += 1 }
        }
        if cardT % 3 == 0 && uiConfetti.count < 70 {
            let col = Fluffwood64.confettiColors[rng.int(6)]
            uiConfetti.append(UiConfetti(x: Float(rng.int(320)), y: -4, vx: (Float(rng.unit()) - 0.5) * 1.2,
                                         vy: 1.0 + Float(rng.unit()) * 1.6, color: col, size: 2 + rng.int(3)))
        }
        if cardT > 30 && (input.aPressed || input.bPressed || input.startPressed || tapped) {
            if !pendingCards.isEmpty {
                showNextCard()
            } else {
                phase = .play
                ptConsumed = true
                play(.select)
            }
        }
    }

    private func showNextCard() {
        if pendingCards.isEmpty { return }
        let c = pendingCards.removeFirst()
        cardSp = c.0
        cardShiny = c.1
        cardLevelUp = c.2
        cardT = 0
        phase = .card
        uiConfetti.removeAll()
        play(.coin)
    }

    private func bookCellRect(_ i: Int) -> (Int, Int, Int, Int) {
        let col = i % 5
        let row = i / 5 - bookScroll
        return (20 + col * 56, 48 + row * 50, 54, 48)
    }

    private func updateBook(_ input: InputState, _ pt: PointerState, _ tapped: Bool) {
        if input.bPressed || input.selectPressed { phase = .play; play(.select); ptConsumed = true; return }
        var moved = false
        if input.leftPressed { bookCursor -= 1; moved = true }
        if input.rightPressed { bookCursor += 1; moved = true }
        if input.upPressed { bookCursor -= 5; moved = true }
        if input.downPressed { bookCursor += 5; moved = true }
        bookCursor = max(0, min(Fluffwood64.nSp - 1, bookCursor))
        if moved { play(.blip) }
        let row = bookCursor / 5
        if row < bookScroll { bookScroll = row }
        if row > bookScroll + 3 { bookScroll = row - 3 }
        if input.aPressed { openDetail() }
        if tapped {
            if pt.x > 282 && pt.y < 34 {
                phase = .play
                play(.select)
                ptConsumed = true
                return
            }
            for i in 0..<Fluffwood64.nSp {
                let r = bookCellRect(i)
                if r.1 < 40 || r.1 > 240 { continue }
                if pt.x >= r.0 && pt.x < r.0 + r.2 && pt.y >= r.1 && pt.y < r.1 + r.3 {
                    bookCursor = i
                    openDetail()
                    break
                }
            }
        }
    }

    private func openDetail() {
        if bookCursor < 0 || bookCursor >= Fluffwood64.nSp { return }
        if caught[bookCursor] {
            detailSp = bookCursor
            phase = .detail
            play(.confirm)
        } else {
            play(.blip)
        }
    }

    private func updateDetail(_ input: InputState, _ tapped: Bool) {
        if input.bPressed || tapped {
            phase = .book
            play(.select)
            return
        }
        if input.aPressed {
            companion = detailSp
            companionShiny = shinyOwned[detailSp]
            cmx = px
            cmy = py
            showToast(sp2name(detailSp) + " IS NOW YOUR PARTNER!", 150)
            play(.powerup)
            phase = .book
        }
    }

    private func updateQuests(_ input: InputState, _ pt: PointerState, _ tapped: Bool) {
        if input.bPressed || input.startPressed || input.selectPressed || input.aPressed {
            phase = .play
            ptConsumed = true
            play(.select)
            return
        }
        var dirn = 0
        if input.leftPressed { dirn = -1 }
        if input.rightPressed { dirn = 1 }
        if tapped {
            if pt.y < 40 || pt.y > 250 {
                phase = .play
                ptConsumed = true
                play(.select)
                return
            }
            if pt.y >= 224 { dirn = pt.x < 160 ? -1 : 1 }
        }
        if dirn != 0 {
            var h = hat
            for _ in 0..<6 {
                h = (h + dirn + 6) % 6
                if accUnlocked[h] || h == 0 { break }
            }
            if h == 0 || accUnlocked[h] { hat = h }
            play(.blip)
        }
    }

    // MARK: - Save

    override func exportSave() -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(96)
        out.append(1)
        out.append(UInt8(Fluffwood64.nSp))
        for i in 0..<Fluffwood64.nSp {
            var f: UInt8 = 0
            if caught[i] { f |= 1 }
            if shinyOwned[i] { f |= 2 }
            out.append(f)
            out.append(UInt8(max(0, min(255, fp[i]))))
        }
        for k in 0..<3 { out.append(UInt8(max(0, min(99, treats[k])))) }
        var gm: Int = 0
        for g in 0..<8 where goalDone[g] { gm |= (1 << g) }
        out.append(UInt8(gm & 255))
        var am: Int = 0
        for a in 0..<7 where accUnlocked[a] { am |= (1 << a) }
        out.append(UInt8(am & 255))
        out.append(UInt8(max(0, min(6, hat))))
        out.append(UInt8(max(0, min(254, companion + 1))))
        out.append(companionShiny ? 1 : 0)
        let tq: Int = max(0, min(255, Int(tod * 256)))
        out.append(UInt8(tq))
        var vm: Int = 0
        for r in 0..<3 where visited[r] { vm |= (1 << r) }
        out.append(UInt8(vm))
        return out
    }

    override func importSave(_ bytes: [UInt8]) {
        if bytes.count < 4 { return }
        if bytes[0] != 1 { return }
        let nb: Int = Int(bytes[1])
        if nb <= 0 || nb > 200 { return }
        let need: Int = 2 + nb * 2 + 3 + 6 + 1
        if bytes.count < need { return }
        var any = false
        for i in 0..<min(nb, Fluffwood64.nSp) {
            let f: UInt8 = bytes[2 + i * 2]
            let p: Int = Int(bytes[3 + i * 2])
            caught[i] = (f & 1) != 0
            shinyOwned[i] = (f & 2) != 0 && caught[i]
            fp[i] = caught[i] ? max(1, min(255, p)) : 0
            if caught[i] { any = true }
        }
        var o: Int = 2 + nb * 2
        for k in 0..<3 {
            treats[k] = max(0, min(99, Int(bytes[o + k])))
        }
        o += 3
        let gm: Int = Int(bytes[o])
        for g in 0..<8 { goalDone[g] = (gm & (1 << g)) != 0 }
        let am: Int = Int(bytes[o + 1])
        for a in 0..<7 { accUnlocked[a] = (am & (1 << a)) != 0 }
        hat = max(0, min(5, Int(bytes[o + 2])))
        if hat != 0 && !accUnlocked[hat] { hat = 0 }
        let comp: Int = Int(bytes[o + 3]) - 1
        if comp >= 0 && comp < Fluffwood64.nSp && caught[comp] {
            companion = comp
            companionShiny = bytes[o + 4] != 0
        } else {
            companion = -1
        }
        tod = Float(Int(bytes[o + 5])) / 256.0
        let vm: Int = Int(bytes[o + 6])
        for r in 0..<3 { visited[r] = (vm & (1 << r)) != 0 }
        if any || starCount() > 0 { hasSave = true }
        if goalDone[0] { }
    }

    // MARK: - Light

    private func computeLight() {
        let a: Float = tod * 2 * Float.pi
        sunH = -cos(a)
        dayF = FluffMath.smooth((sunH + 0.15) / 0.5)
        nightF = 1 - dayF
        let dusk: Float = max(0, 1 - abs(sunH) / 0.30)
        var zr: Float = FluffMath.lerp(20, 96, dayF)
        var zg: Float = FluffMath.lerp(24, 168, dayF)
        var zb: Float = FluffMath.lerp(66, 240, dayF)
        var hr: Float = FluffMath.lerp(58, 208, dayF)
        var hg: Float = FluffMath.lerp(56, 234, dayF)
        var hb: Float = FluffMath.lerp(112, 252, dayF)
        let dk: Float = dusk * 0.7
        zr = FluffMath.lerp(zr, 140, dk * 0.6)
        zg = FluffMath.lerp(zg, 120, dk * 0.6)
        zb = FluffMath.lerp(zb, 200, dk * 0.6)
        hr = FluffMath.lerp(hr, 255, dk)
        hg = FluffMath.lerp(hg, 182, dk)
        hb = FluffMath.lerp(hb, 150, dk)
        var tr: Float = FluffMath.lerp(88, 256, dayF)
        var tg: Float = FluffMath.lerp(102, 256, dayF)
        var tb: Float = FluffMath.lerp(172, 256, dayF)
        tg *= 1 - 0.12 * dusk
        tb *= 1 - 0.28 * dusk
        if powerT > 0 && companionType() == 2 {
            tr = FluffMath.lerp(tr, 230, nightF * 0.6)
            tg = FluffMath.lerp(tg, 190, nightF * 0.6)
            tb = FluffMath.lerp(tb, 150, nightF * 0.6)
        }
        tintR = max(0, min(256, FluffMath.i(tr)))
        tintG = max(0, min(256, FluffMath.i(tg)))
        tintB = max(0, min(256, FluffMath.i(tb)))
        horR = max(0, min(255, FluffMath.i(hr)))
        horG = max(0, min(255, FluffMath.i(hg)))
        horB = max(0, min(255, FluffMath.i(hb)))
        zenR = max(0, min(255, FluffMath.i(zr)))
        zenG = max(0, min(255, FluffMath.i(zg)))
        zenB = max(0, min(255, FluffMath.i(zb)))
    }

    // MARK: - Camera

    private func makeCam() -> FluffCam {
        var c = FluffCam()
        let fx: Float = cos(camHeading)
        let fy: Float = sin(camHeading)
        c.fx = fx
        c.fy = fy
        c.rx = -fy
        c.ry = fx
        c.x = px - fx * camBackNow
        c.y = py - fy * camBackNow
        let base: Float = pzBase + jh + Fluffwood64.camUp
        let gc: Float = max(world.height(c.x, c.y), FluffWorld.waterLevel)
        c.alt = max(base, gc + 1.6)
        c.horizon = 118 - FluffMath.clampF(jh * 3, 0, 8)
        return c
    }

    // MARK: - Drawing

    override func drawTrueColor(_ b: TrueColorBuffer) {
        if b.width != 320 || b.height != 288 {
            b.clear(TrueColorBuffer.rgb(200, 230, 250))
            return
        }
        computeLight()
        let cam = makeCam()
        lastCam = cam
        let dpPtr = UnsafeMutablePointer<UInt16>.allocate(capacity: 320 * 288)
        dpPtr.initialize(repeating: 65535, count: 320 * 288)
        defer { dpPtr.deallocate() }
        b.withPixels { p, w, h in
            if w != 320 || h != 288 { return }
            let pt = FluffPainter(p: p, dp: dpPtr, w: w, h: h)
            switch self.phase {
            case .book:
                self.drawBook(pt)
            case .detail:
                self.drawBook(pt)
                self.drawDetail(pt)
            default:
                self.renderScene(pt, cam)
                pt.beginUI()
                switch self.phase {
                case .title: self.drawTitle(pt)
                case .play: self.drawHUD(pt, cam)
                case .card:
                    self.drawHUD(pt, cam)
                    self.drawCard(pt)
                case .quests:
                    self.drawHUD(pt, cam)
                    self.drawQuests(pt)
                default: break
                }
            }
        }
    }

    private func renderScene(_ pt: FluffPainter, _ cam: FluffCam) {
        let p = pt.p
        let dp = pt.dp
        let w = pt.w
        let h = pt.h
        pt.setLight(tintR, tintG, tintB, horR, horG, horB)
        renderSky(pt, cam)
        renderTerrain(p, dp, w, h, cam)
        renderSprites(pt, cam)
        if nightF > 0.15 { applyVignette(p, w, h) }
    }

    private func renderSky(_ pt: FluffPainter, _ cam: FluffCam) {
        let p = pt.p
        let w = pt.w
        let h = pt.h
        let hz: Int = FluffMath.i(cam.horizon)
        let horPix: UInt32 = TrueColorBuffer.rgb(horR, horG, horB)
        let zenPix: UInt32 = TrueColorBuffer.rgb(zenR, zenG, zenB)
        for y in 0..<h {
            var c: UInt32 = horPix
            if y < hz && hz > 0 {
                let t: Float = Float(hz - y) / Float(hz)
                c = FluffMath.mixPix(horPix, zenPix, FluffMath.i(FluffMath.smooth(t) * 256))
            }
            let base = y * w
            for x in 0..<w { p[base + x] = c }
        }
        pt.begin(z: 0, fogAmount: 0, depthOn: false)
        pt.tr = 256; pt.tg = 256; pt.tb = 256
        pt.glow = true
        let hzF: Float = cam.horizon
        // stars
        if nightF > 0.3 {
            let n: Int = FluffMath.i(nightF * 70)
            for i in 0..<min(70, n) {
                let da: Float = FluffMath.wrapAngle(Fluffwood64.starAz[i] - camHeading)
                if abs(da) > 0.85 { continue }
                let sx: Int = 160 + FluffMath.i(da * Fluffwood64.focal)
                let sy: Int = FluffMath.i(hzF - 8 - Fluffwood64.starEl[i] * (hzF - 14))
                let tw: Bool = ((frame / 20 + i) & 3) == 0
                pt.rect(sx, sy, tw ? 2 : 1, tw ? 2 : 1, TrueColorBuffer.rgb(255, 255, 235))
            }
        }
        // sun
        if sunH > -0.25 {
            let da: Float = FluffMath.wrapAngle(Fluffwood64.sunAz - camHeading)
            if abs(da) < 1.1 {
                let sx: Int = 160 + FluffMath.i(da * Fluffwood64.focal)
                let sy: Int = FluffMath.i(hzF - sunH * 92) + 10
                let warm: Float = max(0, 1 - sunH * 1.6)
                let core: UInt32 = TrueColorBuffer.rgb(255, FluffMath.i(250 - warm * 70), FluffMath.i(210 - warm * 110))
                pt.ellA(sx, sy, 46, 46, core, 26)
                pt.ellA(sx, sy, 32, 32, core, 40)
                pt.ellA(sx, sy, 22, 22, core, 80)
                pt.ell(sx, sy, 15, 15, core)
            }
        }
        // moon
        let moonH: Float = -sunH
        if moonH > -0.2 {
            let da: Float = FluffMath.wrapAngle(Fluffwood64.sunAz + Float.pi - camHeading)
            if abs(da) < 1.1 {
                let sx: Int = 160 + FluffMath.i(da * Fluffwood64.focal)
                let sy: Int = FluffMath.i(hzF - moonH * 88) + 10
                let mc: UInt32 = TrueColorBuffer.rgb(244, 244, 255)
                pt.ellA(sx, sy, 28, 28, mc, 30)
                pt.ell(sx, sy, 13, 13, mc)
                pt.ell(sx - 4, sy - 3, 3, 3, TrueColorBuffer.rgb(214, 214, 238))
                pt.ell(sx + 4, sy + 4, 2, 2, TrueColorBuffer.rgb(214, 214, 238))
            }
        }
        // clouds
        let cloudCol: UInt32 = TrueColorBuffer.rgb(255, 255, 255)
        let cloudSh: UInt32 = TrueColorBuffer.rgb(226, 232, 250)
        pt.glow = false
        pt.setLight(tintR, tintG, tintB, horR, horG, horB)
        for cl in clouds {
            let da: Float = FluffMath.wrapAngle(cl.az - camHeading)
            if abs(da) > 1.1 { continue }
            let sx: Int = 160 + FluffMath.i(da * Fluffwood64.focal)
            let sy: Int = FluffMath.i(hzF - cl.el)
            let r: Int = FluffMath.i(14 * cl.size)
            pt.ell(sx, sy + r / 3, r * 2, r * 2 / 3, cloudSh)
            pt.ell(sx - r, sy, r, r * 3 / 4, cloudCol)
            pt.ell(sx + r, sy, r * 9 / 10, r * 2 / 3, cloudCol)
            pt.ell(sx, sy - r / 3, r * 11 / 10, r * 4 / 5, cloudCol)
        }
    }

    private func renderTerrain(_ p: UnsafeMutablePointer<UInt32>, _ dp: UnsafeMutablePointer<UInt16>, _ w: Int, _ h: Int, _ cam: FluffCam) {
        let hg = world.hgt
        let cp = world.col
        let fogT = Fluffwood64.fogTab
        let shim = Fluffwood64.shimmerTab
        let wtab = Fluffwood64.waterTab
        let invF: Float = 1.0 / Fluffwood64.focal
        let vs: Float = Fluffwood64.focal
        let maxD: Float = Fluffwood64.maxDist
        let ox: Float = cam.x + 4096
        let oy: Float = cam.y + 4096
        let hz: Float = cam.horizon
        let camAlt: Float = cam.alt
        let wl: Float = FluffWorld.waterLevel
        let tR: Int = tintR
        let tG: Int = tintG
        let tB: Int = tintB
        let hR: Int = horR
        let hG: Int = horG
        let hB: Int = horB
        let tick: Int = frame
        for x in 0..<w {
            let u: Float = (Float(x) - 159.5) * invF
            let dX: Float = cam.fx + cam.rx * u
            let dY: Float = cam.fy + cam.ry * u
            var ybuf: Int = h
            var z: Float = 1.5
            while z < maxD && ybuf > 0 {
                let wx: Float = ox + dX * z
                let wy: Float = oy + dY * z
                let xi: Int = Int(wx)
                let yi: Int = Int(wy)
                let fx: Float = wx - Float(xi)
                let fy: Float = wy - Float(yi)
                let x0: Int = xi & 255
                let x1: Int = (xi + 1) & 255
                let y0: Int = (yi & 255) << 8
                let y1: Int = ((yi + 1) & 255) << 8
                let h00: Float = hg[y0 + x0]
                let h10: Float = hg[y0 + x1]
                let h01: Float = hg[y1 + x0]
                let h11: Float = hg[y1 + x1]
                let top: Float = h00 + (h10 - h00) * fx
                let bot: Float = h01 + (h11 - h01) * fx
                var hh: Float = top + (bot - top) * fy
                var water: Bool = false
                var wdepth: Float = 0
                if hh < wl {
                    water = true
                    wdepth = wl - hh
                    hh = wl
                }
                var yf: Float = hz + (camAlt - hh) * vs / z
                if yf < -1 { yf = -1 }
                if yf > 400 { yf = 400 }
                let ys: Int = Int(yf)
                if ys < ybuf {
                    var c: UInt32
                    if water {
                        let di: Int = min(15, Int(wdepth * 3.0))
                        c = wtab[di]
                        if z < 110 {
                            let k: Int = ((Int(wx * 5.0) &* 7) &+ (Int(wy * 5.0) &* 13) &+ (tick >> 1)) & 31
                            let add: Int = shim[k]
                            let rr: Int = min(255, max(0, Int(c & 255) + add))
                            let gg: Int = min(255, max(0, Int((c >> 8) & 255) + add))
                            let bb: Int = min(255, max(0, Int((c >> 16) & 255) + add))
                            c = 0xFF00_0000 | UInt32(rr) | (UInt32(gg) << 8) | (UInt32(bb) << 16)
                            let hs: Int = ((Int(wx * 4.0) &* 73856093) ^ (Int(wy * 4.0) &* 19349663) ^ (tick >> 4)) & 63
                            if hs == 0 { c = 0xFFFF_FFFF }
                        }
                        if wdepth < 0.25 {
                            let fo: Int = Int((0.25 - wdepth) / 0.25 * 190)
                            c = FluffMath.mixPix(c, 0xFFFF_FFFF, fo)
                        }
                    } else if z < 28 {
                        let tx: UInt32 = UInt32(max(0, min(255, Int(fx * 256))))
                        let ty: UInt32 = UInt32(max(0, min(255, Int(fy * 256))))
                        let ca: UInt32 = Fluffwood64.lerpPix(cp[y0 + x0], cp[y0 + x1], tx)
                        let cb: UInt32 = Fluffwood64.lerpPix(cp[y1 + x0], cp[y1 + x1], tx)
                        c = Fluffwood64.lerpPix(ca, cb, ty)
                    } else {
                        c = cp[y0 + x0]
                    }
                    var r: Int = Int(c & 255)
                    var g: Int = Int((c >> 8) & 255)
                    var bl: Int = Int((c >> 16) & 255)
                    r = (r * tR) >> 8
                    g = (g * tG) >> 8
                    bl = (bl * tB) >> 8
                    let zi: Int = Int(z)
                    let fg: Int = fogT[zi]
                    if fg > 0 {
                        r += ((hR - r) * fg) >> 8
                        g += ((hG - g) * fg) >> 8
                        bl += ((hB - bl) * fg) >> 8
                    }
                    let pix: UInt32 = 0xFF00_0000 | UInt32(r & 255) | (UInt32(g & 255) << 8) | (UInt32(bl & 255) << 16)
                    let yStart: Int = max(0, ys)
                    let zd: UInt16 = UInt16(zi)
                    var yy: Int = yStart
                    while yy < ybuf {
                        let idx: Int = yy * w + x
                        p[idx] = pix
                        dp[idx] = zd
                        yy += 1
                    }
                    ybuf = yStart
                }
                z += 0.45 + z * 0.02
            }
        }
    }

    @inline(__always) private static func lerpPix(_ a: UInt32, _ b: UInt32, _ t: UInt32) -> UInt32 {
        let it: UInt32 = 256 &- t
        let rb: UInt32 = ((((a & 0x00FF_00FF) &* it) &+ ((b & 0x00FF_00FF) &* t)) >> 8) & 0x00FF_00FF
        let g: UInt32 = ((((a & 0x0000_FF00) &* it) &+ ((b & 0x0000_FF00) &* t)) >> 8) & 0x0000_FF00
        return 0xFF00_0000 | rb | g
    }

    private func applyVignette(_ p: UnsafeMutablePointer<UInt32>, _ w: Int, _ h: Int) {
        let strength: Float = FluffMath.clampF((nightF - 0.15) / 0.6, 0, 1) * 0.55
        var fxs = [Int](repeating: 256, count: w)
        var fys = [Int](repeating: 256, count: h)
        for x in 0..<w {
            let d: Float = abs(Float(x) - 159.5) / 160.0
            let t: Float = FluffMath.clampF((d - 0.5) / 0.5, 0, 1)
            fxs[x] = 256 - FluffMath.i(t * t * strength * 256)
        }
        for y in 0..<h {
            let d: Float = abs(Float(y) - 143.5) / 144.0
            let t: Float = FluffMath.clampF((d - 0.5) / 0.5, 0, 1)
            fys[y] = 256 - FluffMath.i(t * t * strength * 256)
        }
        for y in 0..<h {
            let fy: Int = fys[y]
            let base: Int = y * w
            let edgeRow: Bool = fy < 250
            for x in 0..<w {
                if !edgeRow && x > 70 && x < 250 { continue }
                let f: Int = (fxs[x] * fy) >> 8
                if f >= 252 { continue }
                let c: UInt32 = p[base + x]
                let r: Int = (Int(c & 255) * f) >> 8
                let g: Int = (Int((c >> 8) & 255) * f) >> 8
                let b: Int = (Int((c >> 16) & 255) * f) >> 8
                p[base + x] = 0xFF00_0000 | UInt32(r) | (UInt32(g) << 8) | (UInt32(b) << 16)
            }
        }
    }

    // MARK: sprites

    private func renderSprites(_ pt: FluffPainter, _ cam: FluffCam) {
        drawList.removeAll(keepingCapacity: true)
        let foc: Float = Fluffwood64.focal
        let fogT = Fluffwood64.fogTab
        // props
        let ccx: Int = Int(floor(cam.x / 16))
        let ccy: Int = Int(floor(cam.y / 16))
        for dyc in -8...8 {
            for dxc in -8...8 {
                let cellCx: Float = Float((ccx + dxc) * 16 + 8)
                let cellCy: Float = Float((ccy + dyc) * 16 + 8)
                let ddx: Float = cellCx - cam.x
                let ddy: Float = cellCy - cam.y
                let cz: Float = ddx * cam.fx + ddy * cam.fy
                let cxr: Float = ddx * cam.rx + ddy * cam.ry
                if cz < -22 { continue }
                if abs(cxr) > cz * 1.0 + 30 { continue }
                let ci = FluffWorld.cellIndex(ccx + dxc, ccy + dyc)
                for pi in world.grid[ci] {
                    let pr = world.props[pi]
                    let dx: Float = FluffMath.wrapDelta(pr.x - cam.x)
                    let dy: Float = FluffMath.wrapDelta(pr.y - cam.y)
                    let zc: Float = dx * cam.fx + dy * cam.fy
                    if zc < 2.4 { continue }
                    var maxZ: Float = 140
                    switch pr.kind {
                    case FluffKind.flower: maxZ = 40
                    case FluffKind.mushroom: maxZ = 55
                    case FluffKind.shells: maxZ = 70
                    case FluffKind.bush: maxZ = 80
                    case FluffKind.rock: maxZ = 85
                    default: maxZ = 150
                    }
                    if zc > maxZ { continue }
                    let xr: Float = dx * cam.rx + dy * cam.ry
                    if abs(xr) > zc * 0.9 + pr.size * 4 { continue }
                    let s: Float = foc / zc
                    let sx: Float = 160 + xr * s
                    let sy: Float = cam.horizon + (cam.alt - pr.gz) * s
                    drawList.append(DrawItem(z: zc, kind: 0, idx: pi, sx: sx, sy: sy, s: s))
                }
            }
        }
        // creatures
        for i in 0..<creatures.count {
            let c = creatures[i]
            let dx: Float = FluffMath.wrapDelta(c.x - cam.x)
            let dy: Float = FluffMath.wrapDelta(c.y - cam.y)
            let zc: Float = dx * cam.fx + dy * cam.fy
            if zc < 1.5 || zc > 170 { continue }
            let xr: Float = dx * cam.rx + dy * cam.ry
            if abs(xr) > zc * 0.95 + 4 { continue }
            let s: Float = foc / zc
            let sp = FluffSpecies.all[c.sp]
            let gzz: Float = sp.type == 1 ? max(c.gz, FluffWorld.waterLevel - 0.2) : c.gz
            drawList.append(DrawItem(z: zc, kind: 1, idx: i, sx: 160 + xr * s, sy: cam.horizon + (cam.alt - gzz) * s, s: s))
            if c.announced || c.shiny {
                if zc > 8 {
                    drawList.append(DrawItem(z: zc + 0.5, kind: 6, idx: i, sx: 160 + xr * s, sy: cam.horizon + (cam.alt - gzz) * s, s: s))
                }
            }
        }
        // player, companion, projectile, pickups, wisps, particles
        addItem(cam, 2, 0, px, py, pzBase)
        if companion >= 0 { addItem(cam, 3, 0, cmx, cmy, world.height(cmx, cmy)) }
        if proj.active { addItem(cam, 4, 0, proj.x, proj.y, proj.z) }
        for i in 0..<pickups.count {
            let g = world.height(pickups[i].x, pickups[i].y)
            addItem(cam, 5, i, pickups[i].x, pickups[i].y, g)
        }
        for i in 0..<wisps.count {
            let g = world.height(wisps[i].x, wisps[i].y)
            let zz: Float = max(g, FluffWorld.waterLevel) + 1.1 + sin(wisps[i].phase) * 0.6
            addItem(cam, 7, i, wisps[i].x, wisps[i].y, zz)
        }
        for i in 0..<particles.count {
            addItem(cam, 8, i, particles[i].x, particles[i].y, particles[i].z)
        }
        drawList.sort { $0.z > $1.z }
        let night: Float = nightF
        for it in drawList {
            let zi: Int = max(0, min(255, Int(it.z)))
            pt.begin(z: it.z, fogAmount: fogT[zi], depthOn: true)
            pt.setLight(tintR, tintG, tintB, horR, horG, horB)
            if it.sx < -150 || it.sx > 470 { continue }
            let sx: Int = FluffMath.i(it.sx)
            let sy: Int = FluffMath.i(it.sy)
            switch it.kind {
            case 0:
                let pr = world.props[it.idx]
                pt.drawProp(pr, sx, sy, it.s, frame, night, propStock[it.idx])
            case 1:
                drawCreatureItem(pt, it, sx, sy)
            case 2:
                drawPlayerItem(pt, sx, sy, it.s)
            case 3:
                drawCompanionItem(pt, sx, sy, it.s)
            case 4:
                let r: Int = max(1, FluffMath.i(0.3 * it.s))
                pt.glow = true
                pt.ellA(sx, sy, r * 2, r * 2, Fluffwood64.treatColors[proj.treat], 70)
                pt.drawTreat(proj.treat, sx, sy, r)
            case 5:
                drawPickupItem(pt, it, sx, sy)
            case 6:
                let bw: Int = max(1, FluffMath.i(0.7 * it.s))
                let top: Int = max(0, sy - FluffMath.i(60 * it.s))
                let beam: UInt32 = TrueColorBuffer.rgb(255, 240, 160)
                pt.glow = true
                pt.rectA(sx - bw, top, bw * 2 + 1, sy - top, beam, 34)
                pt.rectA(sx - bw / 2, top, bw + 1, sy - top, beam, 50)
            case 7:
                drawWispItem(pt, it, sx, sy)
            default:
                drawParticleItem(pt, it, sx, sy)
            }
        }
    }

    private func addItem(_ cam: FluffCam, _ kind: Int, _ idx: Int, _ x: Float, _ y: Float, _ z: Float) {
        let dx: Float = FluffMath.wrapDelta(x - cam.x)
        let dy: Float = FluffMath.wrapDelta(y - cam.y)
        let zc: Float = dx * cam.fx + dy * cam.fy
        if zc < 0.8 || zc > 170 { return }
        let xr: Float = dx * cam.rx + dy * cam.ry
        let s: Float = Fluffwood64.focal / zc
        let sx: Float = 160 + xr * s
        if sx < -120 || sx > 440 { return }
        drawList.append(DrawItem(z: zc, kind: kind, idx: idx, sx: sx, sy: cam.horizon + (cam.alt - z) * s, s: s))
    }

    private func drawCreatureItem(_ pt: FluffPainter, _ it: DrawItem, _ sx: Int, _ sy: Int) {
        let c = creatures[it.idx]
        let sp = FluffSpecies.all[c.sp]
        let rad: Int = FluffMath.i(0.9 * sp.size * it.s)
        if rad < 1 { return }
        var pose = FluffPose()
        let hop: Float = abs(sin(c.hopT))
        var lift: Float = 0
        if c.state == FluffState.wander || c.state == FluffState.flee || c.state == FluffState.curious || c.state == FluffState.play || c.state == FluffState.joy {
            lift = hop * (c.state == FluffState.joy ? 0.9 : 0.5)
            pose.squash = 0.86 + hop * 0.26
        } else {
            pose.squash = 1.0 + sin(Float(frame) * 0.07 + c.phase) * 0.03
        }
        if c.state == FluffState.eating {
            pose.squash = 1.0 + sin(Float(frame) * 0.5) * 0.08
        }
        pose.blink = c.state == FluffState.nap || ((frame + c.blink) % 200) < 7
        pose.happy = c.state == FluffState.joy
        pose.tick = frame + Int(c.phase * 10)
        pose.facing = c.face
        pose.level = caught[c.sp] ? level(c.sp) : 1
        pose.shiny = c.shiny
        let shR: Int = max(1, FluffMath.i(Float(rad) * sp.aspect * 0.95))
        pt.ellA(sx, sy, shR, max(1, shR / 4), TrueColorBuffer.rgb(40, 60, 40), 80)
        let by: Int = sy - FluffMath.i(lift * it.s)
        pt.drawCreature(sp, sx, by, rad, pose)
    }

    private func drawPlayerItem(_ pt: FluffPainter, _ sx: Int, _ sy: Int, _ s: Float) {
        var wade: Float = 0
        let g = world.height(px, py)
        if g < FluffWorld.waterLevel { wade = min(0.7, FluffWorld.waterLevel - g) * 0.4 }
        let u: Float = s
        let capeOn: Bool = accUnlocked[6]
        pt.drawExplorer(sx, sy, u, walkPhase, jh, hat, capeOn, frame, moving, gliding, wade)
        if wade > 0.05 {
            let wy: Int = sy - FluffMath.i(0.1 * s)
            pt.ellA(sx, wy, FluffMath.i(0.8 * s), max(1, FluffMath.i(0.14 * s)), TrueColorBuffer.rgb(200, 240, 255), 120)
        }
    }

    private func drawCompanionItem(_ pt: FluffPainter, _ sx: Int, _ sy: Int, _ s: Float) {
        if companion < 0 { return }
        let sp = FluffSpecies.all[companion]
        let rad: Int = FluffMath.i(0.62 * sp.size * s)
        if rad < 1 { return }
        var pose = FluffPose()
        let hop: Float = abs(sin(cmHop))
        pose.squash = 0.88 + hop * 0.22
        pose.blink = (frame % 190) < 7
        pose.tick = frame
        pose.level = level(companion)
        pose.shiny = companionShiny
        pose.happy = false
        pose.facing = 1
        let lift: Int = FluffMath.i(hop * 0.4 * s)
        pt.ellA(sx, sy, max(1, rad), max(1, rad / 4), TrueColorBuffer.rgb(40, 60, 40), 80)
        pt.drawCreature(sp, sx, sy - lift, rad, pose)
        if (frame / 30) % 4 == 0 {
            pt.heart(sx + rad, sy - rad * 2 - lift, max(3, rad / 3), Fluffwood64.cPink)
        }
    }

    private func drawPickupItem(_ pt: FluffPainter, _ it: DrawItem, _ sx: Int, _ sy: Int) {
        let pk = pickups[it.idx]
        let bob: Float = sin(Float(pk.bob) * 0.1) * 0.25
        let r: Int = max(2, FluffMath.i(0.38 * it.s))
        let y: Int = sy - FluffMath.i((0.9 + bob) * it.s)
        pt.ellA(sx, sy, r, max(1, r / 3), TrueColorBuffer.rgb(40, 60, 40), 70)
        pt.ellA(sx, y, r * 2, r * 2, Fluffwood64.treatColors[pk.kind], 50)
        pt.drawTreat(pk.kind, sx, y, r)
        if (pk.bob / 12) % 3 == 0 { pt.star(sx + r, y - r, max(1, r / 2), 0xFFFFFFFF) }
    }

    private func drawWispItem(_ pt: FluffPainter, _ it: DrawItem, _ sx: Int, _ sy: Int) {
        let wsp = wisps[it.idx]
        if nightF > 0.45 {
            let r: Int = max(1, FluffMath.i(0.14 * it.s))
            let blink: Bool = (Int(wsp.phase * 4) & 7) != 0
            pt.glow = true
            let col: UInt32 = TrueColorBuffer.rgb(255, 245, 140)
            if blink {
                pt.ellA(sx, sy, r * 4, r * 4, col, 40)
                pt.ellA(sx, sy, r * 2, r * 2, col, 90)
            }
            pt.ell(sx, sy, r, r, col)
        } else {
            let flap: Float = abs(sin(wsp.phase * 4))
            let r: Int = max(1, FluffMath.i(0.3 * it.s))
            let col = Fluffwood64.wispColors[wsp.hue & 3]
            let wx: Int = max(1, FluffMath.i(Float(r) * (0.3 + flap)))
            pt.ell(sx - wx, sy, wx, r, col)
            pt.ell(sx + wx, sy, wx, r, col)
            pt.rect(sx, sy - r / 2, max(1, r / 3), r, TrueColorBuffer.rgb(90, 70, 110))
        }
    }

    private func drawParticleItem(_ pt: FluffPainter, _ it: DrawItem, _ sx: Int, _ sy: Int) {
        let pa = particles[it.idx]
        let sz: Int = max(1, FluffMath.i(pa.size * it.s))
        let fade: Int = min(256, pa.life * 256 / max(1, pa.maxLife) * 2)
        pt.glow = pa.kind != 0
        switch pa.kind {
        case 0:
            pt.ellA(sx, sy, sz, max(1, sz * 2 / 3), pa.color, fade / 2)
        case 1:
            pt.star(sx, sy, max(1, sz / 2 + 1), pa.color)
        case 2:
            pt.heart(sx, sy, max(3, sz), pa.color)
        case 3:
            let w2: Int = max(1, sz / 2)
            pt.rect(sx, sy, w2 + (pa.life & 1), max(1, sz / 2) + 1, pa.color)
        case 4:
            pt.ellA(sx, sy, max(1, sz / 2), max(1, sz / 2), pa.color, 200)
        case 6:
            pt.ellA(sx, sy, sz * 2, sz * 2, pa.color, fade / 4)
            pt.ell(sx, sy, max(1, sz / 2), max(1, sz / 2), TrueColorBuffer.rgb(255, 240, 160))
        default:
            pt.ell(sx, sy, max(1, sz / 2), max(1, sz / 3), pa.color)
        }
    }

    // MARK: - UI drawing

    private func uiText(_ pt: FluffPainter, _ s: String, _ x: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        pt.text(s, x + scale, y + scale, Fluffwood64.cShadow, scale)
        pt.text(s, x, y, c, scale)
    }

    private func uiTextCentered(_ pt: FluffPainter, _ s: String, _ cx: Int, _ y: Int, _ c: UInt32, _ scale: Int) {
        let wpx: Int = s.count * 4 * scale - scale
        uiText(pt, s, cx - wpx / 2, y, c, scale)
    }

    private func wrapText(_ s: String, _ maxChars: Int) -> [String] {
        var lines: [String] = []
        var cur: String = ""
        for word in s.split(separator: " ") {
            let ws = String(word)
            if cur.isEmpty {
                cur = ws
            } else if cur.count + 1 + ws.count <= maxChars {
                cur += " " + ws
            } else {
                lines.append(cur)
                cur = ws
            }
        }
        if !cur.isEmpty { lines.append(cur) }
        return lines
    }

    private func rainbow(_ i: Int) -> UInt32 {
        let cols = Fluffwood64.confettiColors
        return cols[((i % 5) + 5) % 5]
    }

    private func drawTitle(_ pt: FluffPainter) {
        pt.roundRect(0, 0, 320, 288, 0, TrueColorBuffer.rgb(255, 255, 255), 0)
        let word = "FLUFFWOOD"
        let startX: Int = 160 - (word.count * 4 * 5 - 5) / 2
        var i = 0
        for ch in word {
            let bob: Int = FluffMath.i(sin(Float(frame) * 0.06 + Float(i) * 0.6) * 4)
            let x: Int = startX + i * 20
            pt.text(String(ch), x + 3, 34 + bob + 3, Fluffwood64.cShadow, 5)
            pt.text(String(ch), x, 34 + bob, rainbow(i), 5)
            i += 1
        }
        uiTextCentered(pt, "64", 160, 72, Fluffwood64.cWhite, 7)
        uiTextCentered(pt, "COLLECT ADORABLE FRIENDS!", 160, 124, Fluffwood64.cWhite, 2)
        if (frame / 30) % 2 == 0 {
            let msg: String = hasSave ? "A / TAP: CONTINUE" : "A / TAP: START"
            pt.roundRect(70, 236, 180, 26, 10, TrueColorBuffer.rgb(255, 255, 255), 210)
            uiTextCentered(pt, msg, 160, 243, Fluffwood64.cInk, 2)
        }
        if hasSave {
            uiTextCentered(pt, "FRIENDS " + String(caughtCount()) + "/" + String(Fluffwood64.nSp), 160, 268, Fluffwood64.cWhite, 2)
        }
    }

    private func drawRing(_ pt: FluffPainter, _ cx: Int, _ cy: Int, _ r: Int, _ frac: Float, _ col: UInt32, _ back: UInt32) {
        let ri: Int = r - 4
        for yy in (cy - r)...(cy + r) {
            for xx in (cx - r)...(cx + r) {
                let dx: Int = xx - cx
                let dy: Int = yy - cy
                let d2: Int = dx * dx + dy * dy
                if d2 > r * r || d2 < ri * ri { continue }
                // angle from top, clockwise
                var a: Float = atan2(Float(dx), Float(-dy))
                if a < 0 { a += 2 * Float.pi }
                let f: Float = a / (2 * Float.pi)
                pt.rawRect(xx, yy, 1, 1, f <= frac ? col : back)
            }
        }
    }

    private func drawHUD(_ pt: FluffPainter, _ cam: FluffCam) {
        let white = TrueColorBuffer.rgb(255, 255, 255)
        // treats
        pt.roundRect(4, 4, 102, 24, 10, white, 200)
        for k in 0..<3 {
            let x: Int = 8 + k * 33
            pt.drawTreat(k, x + 7, 16, 5)
            uiText(pt, String(treats[k]), x + 15, 10, Fluffwood64.cInk, 2)
        }
        // stars
        pt.roundRect(4, 31, 54, 20, 9, white, 200)
        pt.star(15, 41, 6, Fluffwood64.cGold)
        pt.ell(15, 41, 3, 3, Fluffwood64.cGold)
        uiText(pt, "X" + String(starCount()), 26, 36, Fluffwood64.cInk, 2)
        // collection
        pt.roundRect(214, 4, 102, 24, 10, white, 200)
        pt.heart(228, 15, 8, Fluffwood64.cPink)
        uiText(pt, String(caughtCount()) + "/" + String(Fluffwood64.nSp), 240, 10, Fluffwood64.cInk, 2)
        let frac: Float = Float(caughtCount()) / Float(max(1, Fluffwood64.nSp))
        pt.roundRect(214, 31, 102, 8, 4, TrueColorBuffer.rgb(255, 255, 255), 200)
        pt.roundRect(216, 33, max(3, FluffMath.i(98 * frac)), 4, 2, Fluffwood64.cPink, 256)
        drawCompass(pt)
        // message banner
        var msg: String = ""
        if goalBannerT > 0 { msg = goalBanner } else if toastT > 0 { msg = toast } else if phase == .play { msg = currentHint() }
        if !msg.isEmpty {
            let lines = wrapText(msg, 34)
            let n: Int = min(3, lines.count)
            let hh: Int = n * 12 + 8
            pt.roundRect(14, 56, 292, hh, 10, TrueColorBuffer.rgb(255, 250, 240), 225)
            for li in 0..<n {
                uiTextCentered(pt, lines[li], 160, 60 + li * 12, Fluffwood64.cInk, 2)
            }
        }
        if phase != .play { return }
        // target reticle
        if targetIdx >= 0 && targetIdx < creatures.count {
            let c = creatures[targetIdx]
            let sp = FluffSpecies.all[c.sp]
            let p = projectScreen(c.x, c.y, c.gz + 0.9 * sp.size)
            if p.2 > 0.5 {
                let s: Float = Fluffwood64.focal / p.2
                let r: Int = max(10, FluffMath.i(1.5 * sp.size * s))
                let cx: Int = FluffMath.i(p.0)
                let cy: Int = FluffMath.i(p.1)
                for k in 0..<12 {
                    let a: Float = Float(frame) * 0.04 + Float(k) * Float.pi / 6
                    let x: Int = cx + FluffMath.i(cos(a) * Float(r))
                    let y: Int = cy + FluffMath.i(sin(a) * Float(r))
                    pt.rawRect(x - 1, y - 1, 3, 3, (k & 1) == 0 ? Fluffwood64.cWhite : Fluffwood64.cGold)
                }
                let nm: String = caught[c.sp] ? sp.name : "???"
                var label: String = nm
                if c.shiny { label = "SHINY " + nm }
                let wpx: Int = label.count * 8
                let lx: Int = max(4, min(316 - wpx - 14, cx - wpx / 2 - 7))
                let ly: Int = max(64, cy - r - 22)
                pt.roundRect(lx - 4, ly - 3, wpx + 26, 18, 8, white, 225)
                if caught[c.sp] { pt.drawTypeIcon(sp.type, lx + wpx + 8, ly + 6, 6) }
                else { pt.drawTreat(sp.treat < 0 ? 0 : 0, lx + wpx + 8, ly + 6, 0) }
                uiText(pt, label, lx, ly, Fluffwood64.cInk, 2)
            }
        }
        // markers (powers)
        for m in markers {
            let p = projectScreen(m.0, m.1, world.height(m.0, m.1) + 3)
            if p.2 < 0.5 { continue }
            let bob: Int = FluffMath.i(sin(Float(frame) * 0.15) * 3)
            let col: UInt32 = m.2 == 0 ? Fluffwood64.cMint : Fluffwood64.cGold
            let mx: Int = max(8, min(312, FluffMath.i(p.0)))
            let my: Int = max(70, min(230, FluffMath.i(p.1) + bob))
            pt.cone(mx, my + 10, 7, 12, 0, col)
            pt.rect(mx - 2, my - 6, 5, 8, col)
        }
        // floaters
        for f in floaters {
            let p = projectScreen(f.x, f.y, f.z)
            if p.2 < 0.5 { continue }
            let fx: Int = FluffMath.i(p.0)
            let fy: Int = FluffMath.i(p.1)
            let wpx: Int = f.text.count * 8
            if fx < -wpx || fx > 320 + wpx { continue }
            uiText(pt, f.text, fx - wpx / 2, fy, f.color, 2)
        }
        // stamina ring and power ring
        let maxSt: Float = staminaMax()
        let sf: Float = max(0, min(1, stamina / maxSt))
        let scol: UInt32 = exhausted ? TrueColorBuffer.rgb(255, 150, 120) : TrueColorBuffer.rgb(120, 230, 150)
        pt.ellA(74, 264, 17, 17, white, 190)
        drawRing(pt, 74, 264, 16, sf, scol, TrueColorBuffer.rgb(210, 210, 230))
        uiTextCentered(pt, "B", 74, 259, Fluffwood64.cInk, 2)
        let ct = companionType()
        if ct >= 0 {
            pt.ellA(246, 264, 17, 17, white, 190)
            var pf: Float = 1
            var pc: UInt32 = Fluffwood64.typeColors[ct]
            if powerT > 0 { pf = Float(powerT) / 600.0; pc = Fluffwood64.cGold }
            else if powerCool > 0 { pf = 1 - Float(powerCool) / 300.0; pc = TrueColorBuffer.rgb(200, 200, 215) }
            drawRing(pt, 246, 264, 16, max(0, min(1, pf)), pc, TrueColorBuffer.rgb(225, 225, 240))
            pt.drawTypeIcon(ct, 246, 264, 8)
        }
        // action label
        var act: String = "JUMP"
        if nearestShakeable() >= 0 { act = "SHAKE" }
        if targetIdx >= 0 { act = "THROW" }
        pt.roundRect(110, 254, 100, 20, 9, white, 190)
        uiTextCentered(pt, "A: " + act, 160, 259, Fluffwood64.cInk, 2)
        // big touch buttons
        pt.roundRect(4, 238, 44, 46, 12, TrueColorBuffer.rgb(255, 214, 232), 235)
        pt.roundRect(6, 240, 40, 42, 10, TrueColorBuffer.rgb(255, 238, 246), 255)
        pt.ell(26, 258, 11, 13, TrueColorBuffer.rgb(255, 150, 190))
        pt.rect(23, 255, 6, 2, white)
        pt.heart(26, 258, 7, white)
        uiTextCentered(pt, "BOOK", 26, 273, Fluffwood64.cInk, 1)
        pt.roundRect(272, 238, 44, 46, 12, TrueColorBuffer.rgb(255, 232, 150), 235)
        pt.roundRect(274, 240, 40, 42, 10, TrueColorBuffer.rgb(255, 248, 214), 255)
        pt.star(294, 256, 9, Fluffwood64.cGold)
        pt.ell(294, 256, 5, 5, Fluffwood64.cGold)
        uiTextCentered(pt, "GOALS", 294, 273, Fluffwood64.cInk, 1)
    }

    private func drawCompass(_ pt: FluffPainter) {
        let x0: Int = 112
        let wd: Int = 96
        pt.roundRect(x0, 6, wd, 16, 7, TrueColorBuffer.rgb(255, 255, 255), 170)
        let cx: Int = x0 + wd / 2
        let half: Float = Float(wd / 2 - 6)
        // cardinal letters (world -y is north)
        let dirs: [(Float, String)] = [(-Float.pi / 2, "N"), (0, "E"), (Float.pi / 2, "S"), (Float.pi, "W")]
        for d in dirs {
            let rel: Float = FluffMath.wrapAngle(d.0 - heading)
            if abs(rel) < 1.2 {
                let x: Int = cx + FluffMath.i(rel / 1.2 * half)
                pt.text(d.1, x - 2, 10, Fluffwood64.cInk, 1)
            }
        }
        pt.rect(cx - 1, 20, 3, 2, Fluffwood64.cPink)
        for c in creatures {
            let d = dist2(px, py, c.x, c.y)
            if d > 90 || c.state == FluffState.joy { continue }
            let ang: Float = atan2(FluffMath.wrapDelta(c.y - py), FluffMath.wrapDelta(c.x - px))
            let rel: Float = FluffMath.wrapAngle(ang - heading)
            if abs(rel) > 1.2 { continue }
            let x: Int = cx + FluffMath.i(rel / 1.2 * half)
            let sp = FluffSpecies.all[c.sp]
            if c.shiny {
                pt.star(x, 15, 3, rainbow(frame / 6))
            } else if sp.rarity == 2 {
                pt.star(x, 15, 3, Fluffwood64.cGold)
            } else {
                let col: UInt32 = sp.rarity == 1 ? TrueColorBuffer.rgb(120, 190, 255) : TrueColorBuffer.rgb(255, 170, 200)
                pt.rect(x - 1, 13, 3, 3, col)
            }
        }
    }

    // MARK: book

    private func drawBook(_ pt: FluffPainter) {
        pt.beginUI()
        let h = pt.h
        let w = pt.w
        for y in 0..<h {
            let t: Int = y * 256 / h
            let c = FluffMath.mixPix(TrueColorBuffer.rgb(226, 210, 255), TrueColorBuffer.rgb(255, 236, 222), t)
            let base = y * w
            for x in 0..<w { pt.p[base + x] = c }
        }
        for k in 0..<18 {
            let x: Int = (k * 53 + 17) % 320
            let y: Int = (k * 97 + 31) % 288
            let tw: Int = (frame / 20 + k) % 4
            pt.star(x, y, tw == 0 ? 3 : 2, TrueColorBuffer.rgb(255, 255, 255))
        }
        pt.roundRect(60, 4, 200, 30, 12, TrueColorBuffer.rgb(255, 150, 190), 255)
        pt.roundRect(62, 6, 196, 26, 10, TrueColorBuffer.rgb(255, 190, 214), 255)
        uiTextCentered(pt, "FRIEND BOOK " + String(caughtCount()) + "/" + String(Fluffwood64.nSp), 160, 13, Fluffwood64.cWhite, 2)
        pt.roundRect(284, 6, 30, 24, 8, TrueColorBuffer.rgb(255, 120, 150), 255)
        uiTextCentered(pt, "X", 299, 12, Fluffwood64.cWhite, 2)
        for i in 0..<Fluffwood64.nSp {
            let r = bookCellRect(i)
            if r.1 < 40 || r.1 > 240 { continue }
            let sp = FluffSpecies.all[i]
            let got = caught[i]
            let bg: UInt32 = got ? TrueColorBuffer.rgb(255, 255, 255) : TrueColorBuffer.rgb(204, 190, 232)
            if i == bookCursor {
                let pulse: Int = (frame / 8) % 2
                pt.roundRect(r.0 - 2, r.1 - 2, r.2 + 4, r.3 + 4, 10, pulse == 0 ? Fluffwood64.cGold : TrueColorBuffer.rgb(255, 160, 90), 255)
            }
            pt.roundRect(r.0, r.1, r.2, r.3, 8, bg, 255)
            var pose = FluffPose()
            pose.level = 1
            pose.tick = frame
            pose.shiny = shinyOwned[i]
            pose.showFace = got
            pt.begin(z: 0, fogAmount: 0, depthOn: false)
            pt.glow = false
            if !got { pt.sil = TrueColorBuffer.rgb(150, 132, 188) }
            pt.drawCreature(sp, r.0 + r.2 / 2, r.1 + r.3 - 8, 13, pose)
            pt.sil = 0
            if got {
                for l in 0..<level(i) {
                    pt.rect(r.0 + 6 + l * 5, r.1 + r.3 - 5, 3, 3, Fluffwood64.cPink)
                }
                if shinyOwned[i] { pt.star(r.0 + r.2 - 8, r.1 + 8, 3, Fluffwood64.cGold) }
                if companion == i { pt.heart(r.0 + 8, r.1 + 8, 6, TrueColorBuffer.rgb(255, 90, 130)) }
            }
        }
        let sp = FluffSpecies.all[max(0, min(Fluffwood64.nSp - 1, bookCursor))]
        pt.roundRect(14, 250, 292, 34, 10, TrueColorBuffer.rgb(255, 255, 255), 230)
        if caught[bookCursor] {
            uiText(pt, sp.name, 22, 255, Fluffwood64.cInk, 2)
            pt.drawTypeIcon(sp.type, 22 + sp.name.count * 8 + 12, 261, 6)
            uiText(pt, "A: INFO  B: BACK", 22, 271, TrueColorBuffer.rgb(140, 110, 170), 1)
        } else {
            uiText(pt, "???", 22, 255, Fluffwood64.cInk, 2)
            uiText(pt, "LIVES IN " + FluffSpecies.regionNames[sp.region], 22, 273, TrueColorBuffer.rgb(140, 110, 170), 1)
        }
    }

    private func drawDetail(_ pt: FluffPainter) {
        pt.beginUI()
        let sp = FluffSpecies.all[detailSp]
        let shiny = shinyOwned[detailSp]
        let lv = level(detailSp)
        pt.roundRect(10, 10, 300, 268, 16, TrueColorBuffer.rgb(255, 214, 232), 255)
        pt.roundRect(14, 14, 292, 260, 13, TrueColorBuffer.rgb(255, 252, 255), 255)
        let bgc: UInt32 = TrueColorBuffer.rgb(220, 238, 255)
        pt.roundRect(22, 22, 128, 128, 14, bgc, 255)
        let cx: Int = 86
        let cy: Int = 132
        if lv >= 4 {
            let cols = Fluffwood64.confettiColors
            for k in 0..<5 {
                pt.ell(cx, cy - 20, 56 - k * 4, 56 - k * 4, cols[k])
            }
            pt.ell(cx, cy - 20, 36, 36, bgc)
            pt.rect(22, cy - 20, 128, 40, bgc)
        }
        if lv >= 3 {
            for k in 0..<8 {
                let a: Float = Float(k) * Float.pi / 4 + Float(frame) * 0.01
                pt.heart(cx + FluffMath.i(cos(a) * 58), cy - 30 + FluffMath.i(sin(a) * 50), 6, Fluffwood64.cPink)
            }
        }
        var pose = FluffPose()
        let hop: Float = abs(sin(Float(frame) * 0.07))
        pose.squash = 0.96 + hop * 0.08
        pose.tick = frame
        pose.level = lv
        pose.shiny = shiny
        pose.happy = (frame / 90) % 3 == 0
        pose.blink = (frame % 160) < 7
        pt.begin(z: 0, fogAmount: 0, depthOn: false)
        pt.glow = false
        pt.ellA(cx, cy + 2, 40, 7, TrueColorBuffer.rgb(120, 110, 160), 80)
        pt.drawCreature(sp, cx, cy - FluffMath.i(hop * 6), 38, pose)
        if lv >= 5 {
            let ty: Int = cy - 98
            pt.rect(cx - 14, ty + 8, 28, 6, Fluffwood64.cGold)
            for k in 0..<3 { pt.cone(cx - 12 + k * 12, ty + 8, 4, 12, 0, Fluffwood64.cGold) }
        }
        uiText(pt, sp.name, 158, 26, Fluffwood64.cInk, 2)
        pt.drawTypeIcon(sp.type, 168, 52, 7)
        uiText(pt, FluffSpecies.typeNames[sp.type], 180, 49, Fluffwood64.typeColors[sp.type], 2)
        uiText(pt, FluffSpecies.rarityNames[sp.rarity] + (shiny ? " SHINY" : ""), 158, 66, TrueColorBuffer.rgb(170, 110, 200), 2)
        let rn: [String] = wrapText(FluffSpecies.regionNames[sp.region], 18)
        for (i, l) in rn.enumerated() { uiText(pt, l, 158, 84 + i * 12, TrueColorBuffer.rgb(90, 160, 120), 2) }
        pt.drawTreat(sp.treat, 166, 120, 6)
        uiText(pt, "LOVES " + FluffSpecies.treatNames[sp.treat], 178, 114, Fluffwood64.cInk, 1)
        uiText(pt, "TIME: " + ["ANYTIME", "DAYTIME", "NIGHT", "DAWN/DUSK"][sp.time], 158, 130, TrueColorBuffer.rgb(120, 110, 160), 1)
        for l in 0..<5 {
            let col: UInt32 = l < lv ? Fluffwood64.cPink : TrueColorBuffer.rgb(222, 214, 236)
            pt.heart(166 + l * 16, 148, 9, col)
        }
        uiText(pt, "LEVEL " + String(lv), 158, 158, Fluffwood64.cInk, 1)
        let lines = wrapText(sp.fact, 32)
        for (i, l) in lines.enumerated() where i < 4 {
            uiTextCentered(pt, l, 160, 176 + i * 14, Fluffwood64.cInk, 2)
        }
        let isPartner: Bool = companion == detailSp
        pt.roundRect(40, 240, 240, 26, 10, isPartner ? TrueColorBuffer.rgb(255, 190, 214) : TrueColorBuffer.rgb(170, 230, 190), 255)
        uiTextCentered(pt, isPartner ? "YOUR PARTNER! TAP TO CLOSE" : "A: MAKE PARTNER  B: BACK", 160, 247, Fluffwood64.cInk, 1)
    }

    private func drawQuests(_ pt: FluffPainter) {
        pt.beginUI()
        pt.roundRect(14, 30, 292, 222, 14, TrueColorBuffer.rgb(255, 214, 232), 245)
        pt.roundRect(18, 34, 284, 214, 11, TrueColorBuffer.rgb(255, 252, 255), 250)
        uiTextCentered(pt, "COZY GOALS", 160, 40, Fluffwood64.cInk, 2)
        for g in 0..<8 {
            let y: Int = 60 + g * 20
            let done = goalDone[g]
            pt.roundRect(24, y, 272, 18, 7, done ? TrueColorBuffer.rgb(255, 244, 190) : TrueColorBuffer.rgb(240, 236, 252), 255)
            pt.star(36, y + 9, 6, done ? Fluffwood64.cGold : TrueColorBuffer.rgb(206, 198, 224))
            pt.ell(36, y + 9, 3, 3, done ? Fluffwood64.cGold : TrueColorBuffer.rgb(206, 198, 224))
            uiText(pt, Fluffwood64.goalTitles[g], 48, y + 2, Fluffwood64.cInk, 1)
            uiText(pt, Fluffwood64.goalRewards[g], 48, y + 10, TrueColorBuffer.rgb(150, 120, 180), 1)
            var prog: String = done ? "OK" : ""
            if !done {
                let n = caughtCount()
                if g == 0 { prog = String(min(n, 3)) + "/3" }
                else if g == 1 { prog = String(min(n, 8)) + "/8" }
                else if g == 2 { prog = String(min(n, 15)) + "/15" }
                else if g == 7 { prog = String(min(n, 20)) + "/20" }
            }
            uiText(pt, prog, 262, y + 5, Fluffwood64.cInk, 1)
        }
        pt.roundRect(24, 224, 272, 22, 9, TrueColorBuffer.rgb(214, 238, 255), 255)
        uiTextCentered(pt, "< HAT: " + Fluffwood64.hatNames[max(0, min(5, hat))] + " >", 160, 230, Fluffwood64.cInk, 2)
    }

    private func drawCard(_ pt: FluffPainter) {
        pt.beginUI()
        pt.roundRect(0, 0, 320, 288, 0, TrueColorBuffer.rgb(60, 40, 100), 0)
        let sp = FluffSpecies.all[cardSp]
        pt.roundRect(24, 28, 272, 232, 18, TrueColorBuffer.rgb(255, 200, 224), 255)
        pt.roundRect(28, 32, 264, 224, 15, TrueColorBuffer.rgb(255, 252, 255), 255)
        let bgc: UInt32 = TrueColorBuffer.rgb(214, 238, 255)
        pt.roundRect(70, 76, 180, 104, 14, bgc, 255)
        for c in uiConfetti {
            pt.rect(FluffMath.i(c.x), FluffMath.i(c.y), c.size, c.size + 1, c.color)
        }
        let word: String = cardShiny ? "SHINY FRIEND!" : "NEW FRIEND!"
        let wpx: Int = word.count * 24
        let sx0: Int = 160 - wpx / 2
        var i = 0
        for ch in word {
            let bob: Int = FluffMath.i(sin(Float(cardT) * 0.15 + Float(i) * 0.5) * 3)
            pt.text(String(ch), sx0 + i * 24 + 1, 42 + bob + 1, Fluffwood64.cShadow, 4)
            pt.text(String(ch), sx0 + i * 24, 42 + bob, rainbow(i), 4)
            i += 1
        }
        var pose = FluffPose()
        let hop: Float = abs(sin(Float(cardT) * 0.12))
        pose.squash = 0.9 + hop * 0.2
        pose.tick = cardT
        pose.level = 1
        pose.shiny = cardShiny
        pose.happy = true
        pt.begin(z: 0, fogAmount: 0, depthOn: false)
        pt.glow = false
        pt.ellA(160, 172, 46, 7, TrueColorBuffer.rgb(120, 110, 160), 80)
        pt.drawCreature(sp, 160, 172 - FluffMath.i(hop * 10), 40, pose)
        uiTextCentered(pt, sp.name, 160, 186, Fluffwood64.cInk, 3)
        pt.drawTypeIcon(sp.type, 98, 214, 7)
        uiText(pt, FluffSpecies.typeNames[sp.type] + " / " + FluffSpecies.rarityNames[sp.rarity], 110, 211, Fluffwood64.typeColors[sp.type], 1)
        let lines = wrapText(sp.fact, 30)
        for (k, l) in lines.enumerated() where k < 3 {
            uiTextCentered(pt, l, 160, 222 + k * 11, Fluffwood64.cInk, 1)
        }
        if cardLevelUp { uiTextCentered(pt, "LEVEL UP!", 160, 62, Fluffwood64.cGold, 2) }
        if cardT > 30 && (cardT / 20) % 2 == 0 {
            uiTextCentered(pt, "A / TAP: CONTINUE", 160, 248, TrueColorBuffer.rgb(150, 110, 190), 1)
        }
    }
}

extension Cartridge {
    static let fluffwood64 = Cartridge(
        id: "fluffwood64", title: "FLUFFWOOD 64", genre: "Adventure",
        blurb: "Explore a sunny open world, throw treats to befriend 26 fluffy creatures and fill your Friend Book. Shiny and rare friends appear at special times.",
        controls: "D-PAD walk/turn, B sprint, A treat/shake/jump, SELECT book, START goals. Touch: tap creatures and bushes, hold to walk.",
        era: .n64, labelTop: 0xFFB6D9, labelBottom: 0x7FD6A8, factory: { Fluffwood64() })
}
