#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

// BUDDY BOUNCE: a kid-safe ragdoll toy playground. A giggly burlap buddy tumbles around a toy room while kids
// fling it, tickle it, bonk it with foam toys and launch it with silly props. No weapons, nobody is ever hurt.
//
// Files: BuddyDraw64 (pixel toolkit), BuddyBounce64 (state, input, physics), BuddyToys64 (toys, goals, save),
// BuddyArt64 (rooms, buddy, toys drawing), BuddyUI64 (HUD, menus, slot machine, title).

// MARK: - Plain data types

struct BuddyPt {
    var x: Float = 0
    var y: Float = 0
    var ox: Float = 0
    var oy: Float = 0
    var r: Float = 5
    var w: Float = 1
}

struct BuddyLink {
    var a: Int
    var b: Int
    var len: Float
    var k: Float
    /// 0 = fixed length, 1 = minimum distance only, 2 = maximum distance only
    var mode: Int
}

struct BuddySpark {
    var x: Float
    var y: Float
    var vx: Float
    var vy: Float
    var life: Int
    var maxLife: Int
    /// 0 star, 1 confetti, 2 dot, 3 droplet, 4 cream, 5 sparkle, 6 balloon, 7 wind streak, 8 heart, 9 feather puff
    var kind: Int
    var col: UInt32
    var size: Float
    var grav: Float
    var rot: Float
}

struct BuddyFloat {
    var x: Float
    var y: Float
    var text: String
    var life: Int
    var col: UInt32
}

struct BuddyBall {
    var x: Float = 0
    var y: Float = 0
    var vx: Float = 0
    var vy: Float = 0
    var r: Float = 6
    /// 0 rubber ball, 1 beach ball, 2 rubber duck
    var kind: Int = 0
    var life: Int = 600
    var sq: Float = 0
    var rot: Float = 0
    var rotV: Float = 0
    var col: UInt32 = 0
    var cool: Int = 0
}

struct BuddyPad {
    /// 0 trampoline, 1 springboard, 2 seesaw, 3 conveyor, 4 catapult
    var kind: Int = 0
    var x: Float = 0
    var y: Float = 0
    var w: Float = 60
    var life: Int = 900
    var anim: Float = 1
    var dir: Float = 1
    var cool: Int = 0
    var phase: Float = 0
}

struct BuddyProp {
    /// 0 spring pad, 1 cloud trampoline, 2 swinging bell, 3 ball pit, 4 gummy platform
    var kind: Int = 0
    var x: Float = 0
    var y: Float = 0
    var w: Float = 50
    var h: Float = 20
    var anim: Float = 0
    var ang: Float = 0
    var angv: Float = 0
    var cool: Int = 0
}

struct BuddyWheel {
    var x: Float = 0
    var y: Float = 0
    var r: Float = 34
    var spin: Float = 0.2
    var rot: Float = 0
    var life: Int = 480
}

struct BuddyAnim {
    /// 0 hammer, 1 glove, 2 chicken, 3 pie, 4 water balloon, 5 cannon, 6 elephant
    var kind: Int = 0
    var x: Float = 0
    var y: Float = 0
    var sx: Float = 0
    var sy: Float = 0
    var t: Int = 0
    var dur: Int = 20
    var hitT: Int = 6
    var applied: Bool = false
    var dir: Float = 1
}

struct BuddyCoin {
    var x: Float = 0
    var y: Float = 0
    var bx: Float = 0
    var ph: Float = 0
    var life: Int = 900
    var gold: Bool = false
}

struct BuddyBurst {
    var x: Float = 0
    var y: Float = 0
    var t: Int = 0
    var maxT: Int = 26
    var text: String = ""
    var col: UInt32 = 0
}

// MARK: - Static tables

enum BuddyData {
    static let toyCount = 21
    static let toyNames: [String] = [
        "HAMMER", "GLOVE", "CHICKEN", "TRAMPO", "PIE", "BALLOON", "SPRING", "CONFETTI", "FAN", "ROCKET", "BALLS",
        "FEATHER", "MAGNET", "SLING", "WHEEL", "SEESAW", "ELEPHANT", "BEACH", "DUCK", "BELT", "CATAPULT"
    ]
    /// 0 tap, 1 hold, 2 slingshot drag
    static let toyKinds: [Int] = [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0]
    static let toyPrice: [Int] = [0, 0, 0, 0, 30, 35, 40, 60, 50, 80, 45, 40, 70, 90, 55, 60, 3, 40, 2, 45, 75]
    /// true when the price is paid in gold bars
    static let toyGold: [Bool] = [false, false, false, false, false, false, false, false, false, false, false,
                                  false, false, false, false, false, true, false, true, false, false]
    static let toyColors: [UInt32] = [
        0xFF8A3C, 0xE84A4A, 0xFFD23C, 0x4AA8FF, 0xFF9CCB, 0x58C8FF, 0x7ED957, 0xB070FF, 0x6AD6D0, 0xFF6A3C, 0x4AD08A,
        0xFF8FD0, 0xE05050, 0x9A78E8, 0xFFB03C, 0x58B8A0, 0x9AA4B8, 0x58C8F0, 0xFFD83C, 0x8890A0, 0xD07A3C
    ]

    static let hatNames: [String] = ["NONE", "PARTY", "TOP", "BEANIE", "CROWN", "PROP", "CHEF", "BUNNY", "FLOWER", "CAT"]
    static let hatPrice: [Int] = [0, 0, 30, 20, 60, 40, 35, 45, 25, 50]
    static let scarfNames: [String] = ["RED", "BLUE", "GREEN", "SUN", "PLUM", "PINK", "RAINBOW"]
    static let scarfPrice: [Int] = [0, 10, 10, 15, 20, 20, 40]
    static let scarfColors: [UInt32] = [0xE04848, 0x3C82E0, 0x46B45A, 0xF2C83C, 0x9A5AC8, 0xF28CB8, 0xFFFFFF]

    static let roomNames: [String] = ["CARDBOARD", "PLAYROOM", "BACKYARD", "BEACH", "SPACE", "CANDY LAND", "ROOFTOP"]
    static let roomStars: [Int] = [0, 2, 4, 6, 8, 11, 15]
    static let roomGravity: [Float] = [0.30, 0.30, 0.30, 0.30, 0.09, 0.30, 0.30]
    static let roomWallRest: [Float] = [0.45, 0.45, 0.45, 0.40, 0.75, 1.0, 0.50]
    static let roomFloorRest: [Float] = [0.45, 0.50, 0.50, 0.15, 0.60, 0.65, 0.50]
    static let roomFric: [Float] = [0.88, 0.90, 0.90, 0.62, 0.97, 0.95, 0.90]

    static let goalTexts: [String] = [
        "BOUNCE 10 TIMES", "FLING ACROSS THE ROOM", "USE 3 DIFFERENT TOYS", "PIE THE BUDDY", "GET A COMBO X5",
        "TICKLE FOR 3 SECONDS", "GET THE BUDDY SOAKED", "LAUNCH WITH SLINGSHOT", "BOOP WITH THE ELEPHANT"
    ]
    static let goalTargets: [Int] = [10, 1, 3, 1, 1, 3, 1, 1, 1]

    static let confettiColors: [UInt32] = [
        0xFF4D6D, 0xFFB703, 0x4CC9F0, 0x80ED99, 0xB388EB, 0xFF8FA3, 0xFFD60A, 0x48CAE4
    ]

    static let speechHappy: [String] = ["HEE HEE!", "WHEEE!", "HA HA!", "TEE HEE!", "BOING!", "YAY!"]
}

// MARK: - Game

final class BuddyBounce64: Game {
    // Layout
    let floorY: Float = 212
    let ceilY: Float = 28
    let wallL: Float = 6
    let wallR: Float = 314
    let shelfTop: Int = 238

    // Phase and clocks
    var phase: Int = 0
    var frameN: Int = 0
    var titleT: Int = 0
    var rng = Rng(seed: 0xB0DD1E5)

    // Persistent progress
    var cash: Int = 25
    var gold: Int = 1
    var stars: Int = 0
    var toysOwned: Int = 15
    var roomsOwned: Int = 1
    var hatsOwned: Int = 3
    var scarvesOwned: Int = 1
    var selHat: Int = 1
    var selScarf: Int = 0
    var selRoom: Int = 0
    var selToy: Int = 0
    var goalIds: [Int] = [0, 1, 2, 3]
    var goalProg: [Int] = [0, 0, 0, 0]
    var toyUsedMask: Int = 0
    var statBounces: Int = 0
    var statFlings: Int = 0
    var statParties: Int = 0
    var statPies: Int = 0
    var statTickle: Int = 0
    var statGoals: Int = 0
    var statBestCombo: Int = 0
    var statSpins: Int = 0
    var statPhotos: Int = 0

    // Pointer (touch or D-pad cursor)
    var px: Float = 160
    var py: Float = 120
    var lastPX: Float = 160
    var lastPY: Float = 120
    var pdown: Bool = false
    var ppressed: Bool = false
    var preleased: Bool = false
    var fvx: Float = 0
    var fvy: Float = 0
    var cursorOn: Bool = false
    var curX: Float = 160
    var curY: Float = 120
    var curSpeed: Float = 2
    var keyGrab: Bool = false
    var pStartX: Float = 0
    var pStartY: Float = 0
    var pFrames: Int = 0
    var pMoved: Float = 0
    /// 0 none, 1 shelf, 2 hud button, 3 tap-toy pending, 4 grabbing, 5 consumed, 6 hold toy, 7 slingshot, 8 consumed until release
    var mode: Int = 0
    var btnId: Int = -1
    var pendIdx: Int = 0

    // Shelf
    var shelfScroll: Float = 0
    var shelfVel: Float = 0
    var shelfPop: Float = 0

    // Menus: 0 none, 1 wardrobe, 2 rooms, 3 goals, 4 lucky spin
    var menu: Int = 0
    var menuShake: Int = 0

    // Buddy
    var pts: [BuddyPt] = []
    var links: [BuddyLink] = []
    var grabIdx: Int = -1
    var cx: Float = 160
    var cy: Float = 150
    var cvx: Float = 0
    var cvy: Float = 0
    var headSq: Float = 0
    var headSqV: Float = 0
    var bodySq: Float = 0
    var bodySqV: Float = 0
    var expr: Int = 0
    var exprT: Int = 0
    var exprNext: Int = 0
    var bubble: String = ""
    var bubbleT: Int = 0
    var dizzyT: Int = 0
    var creamT: Int = 0
    var wetT: Int = 0
    var rocketT: Int = 0
    var idleT: Int = 0
    var spinAccum: Float = 0
    var lastTorsoAng: Float = 0
    var airFrames: Int = 0
    var tickleT: Int = 0
    var tickleActive: Bool = false
    var flung: Bool = false
    var flingStartX: Float = 0
    var flingT: Int = 0
    var flingDone: Bool = false
    var bounceCool: Int = 0
    var frameImpact: Float = 0
    var floorTouch: [Bool] = []
    var shakeT: Int = 0
    var wasSlung: Bool = false

    // World objects
    var props: [BuddyProp] = []
    var pads: [BuddyPad] = []
    var wheels: [BuddyWheel] = []
    var balls: [BuddyBall] = []
    var anims: [BuddyAnim] = []
    var sparks: [BuddySpark] = []
    var floats: [BuddyFloat] = []
    var coinB: [BuddyCoin] = []
    var bursts: [BuddyBurst] = []
    var coinSpawnT: Int = 200
    var ballSfxCool: Int = 0
    var holdX: Float = 0
    var holdY: Float = 0
    var holdOn: Bool = false

    // Slingshot
    var slingOn: Bool = false
    var slingAx: Float = 0
    var slingAy: Float = 0
    var slingPx: Float = 0
    var slingPy: Float = 0

    // Giggle meter and combos
    var meter: Float = 0
    var meterIdle: Int = 0
    var comboCount: Int = 0
    var comboT: Int = 0
    var lastToyFrame: Int = -1000
    var toyChain: Int = 0
    var bannerText: String = ""
    var bannerT: Int = 0
    var bannerCol: UInt32 = 0
    var toastText: String = ""
    var toastT: Int = 0

    // Free gift, camera, slot machine
    var giftT: Int = 1500
    var photoT: Int = 0
    var slotPhase: Int = 0
    var slotT: Int = 0
    var slotPos: [Float] = [0, 0, 0]
    var slotTarget: [Int] = [0, 0, 0]
    var slotGoal: [Float] = [0, 0, 0]
    var slotStop: [Int] = [60, 80, 100]
    var slotStopped: [Bool] = [false, false, false]
    var slotMsg: String = ""
    var slotPrize: Int = 0
    var slotPrizeArg: Int = 0
    var slotDragY: Float = 0
    var slotLever: Float = 0

    // Rendering
    var bgCache: [UInt32] = []
    var bgRoom: Int = -1
    var texts: [BuddyText] = []

    // MARK: Init

    override init() {
        super.init()
        buildBuddy()
        floorTouch = [Bool](repeating: false, count: pts.count)
        setupProps()
    }

    override var score: Int { return max(0, stars * 100 + cash) }
    override var wantsPointer: Bool { return true }

    override func drawTrueColor(_ b: TrueColorBuffer) {
        renderFrame(b)
    }

    override func exportSave() -> [UInt8] {
        return buildSave()
    }

    override func importSave(_ bytes: [UInt8]) {
        loadSave(bytes)
    }

    override func start() {
        playMusic(Tunes.arcade)
        phase = 0
        titleT = 0
        if bgRoom != selRoom { bgRoom = -1 }
    }

    // MARK: Buddy construction

    /// Rest-pose offsets from the neck. Order: head, neck, shL, shR, waist, hipL, hipR, elbL, handL, elbR, handR, kneeL, footL, kneeR, footR.
    static let restX: [Float] = [0, 0, -9, 9, 0, -6, 6, -14, -16, 14, 16, -7, -7, 7, 7]
    static let restY: [Float] = [-16, 0, 3, 3, 21, 25, 25, 14, 26, 14, 26, 39, 53, 39, 53]
    static let ptRadius: [Float] = [11, 8, 7, 7, 9, 7, 7, 5, 6, 5, 6, 6, 6.5, 6, 6.5]
    static let ptWeight: [Float] = [0.7, 0.8, 0.8, 0.8, 0.6, 0.7, 0.7, 1.2, 1.4, 1.2, 1.4, 1.0, 1.2, 1.0, 1.2]

    func buildBuddy() {
        pts = []
        var i: Int = 0
        while i < 15 {
            var p = BuddyPt()
            p.x = 160 + BuddyBounce64.restX[i]
            p.y = 150 + BuddyBounce64.restY[i]
            p.ox = p.x
            p.oy = p.y
            p.r = BuddyBounce64.ptRadius[i]
            p.w = BuddyBounce64.ptWeight[i]
            pts.append(p)
            i += 1
        }
        links = []
        let rigid: [[Int]] = [
            [0, 1], [1, 2], [1, 3], [2, 3], [1, 4], [2, 4], [3, 4], [4, 5], [4, 6], [5, 6], [1, 5], [1, 6], [2, 5], [3, 6],
            [2, 7], [7, 8], [3, 9], [9, 10], [5, 11], [11, 12], [6, 13], [13, 14]
        ]
        for pr in rigid {
            addLink(pr[0], pr[1], 1.0, 0, -1)
        }
        addLink(0, 4, 0.10, 0, -1)
        addLink(0, 2, 0.8, 1, 15)
        addLink(0, 3, 0.8, 1, 15)
        addLink(2, 8, 0.8, 1, 9)
        addLink(3, 10, 0.8, 1, 9)
        addLink(5, 12, 0.8, 1, 11)
        addLink(6, 14, 0.8, 1, 11)
        addLink(11, 13, 0.8, 1, 9)
        addLink(12, 14, 0.8, 1, 10)
    }

    func addLink(_ a: Int, _ b: Int, _ k: Float, _ mode: Int, _ lenOverride: Float) {
        let dx: Float = BuddyBounce64.restX[a] - BuddyBounce64.restX[b]
        let dy: Float = BuddyBounce64.restY[a] - BuddyBounce64.restY[b]
        var len: Float = sqrt(dx * dx + dy * dy)
        if lenOverride > 0 { len = lenOverride }
        links.append(BuddyLink(a: a, b: b, len: len, k: k, mode: mode))
    }

    /// Put the buddy upright with its neck at (nx, ny).
    func placeBuddy(_ nx: Float, _ ny: Float) {
        var i: Int = 0
        while i < pts.count {
            pts[i].x = nx + BuddyBounce64.restX[i]
            pts[i].y = ny + BuddyBounce64.restY[i]
            pts[i].ox = pts[i].x
            pts[i].oy = pts[i].y
            i += 1
        }
        grabIdx = -1
    }

    func resetBuddy() {
        placeBuddy(160, 80)
        var i: Int = 0
        while i < pts.count {
            pts[i].oy += 2.5
            i += 1
        }
        expr = 1
        exprT = 60
        exprNext = 0
        bubble = "HEE HEE!"
        bubbleT = 70
        dizzyT = 0
        creamT = 0
        wetT = 0
        rocketT = 0
        idleT = 0
        spinAccum = 0
        flung = false
        slingOn = false
        tickleActive = false
        headSq = 0
        headSqV = 0
        bodySq = 0
        bodySqV = 0
        computeCentroid()
        lastTorsoAng = torsoAngle()
    }

    func computeCentroid() {
        if pts.count < 15 { return }
        var sx: Float = 0
        var sy: Float = 0
        var svx: Float = 0
        var svy: Float = 0
        let idx: [Int] = [1, 2, 3, 4, 5, 6]
        for i in idx {
            sx += pts[i].x
            sy += pts[i].y
            svx += pts[i].x - pts[i].ox
            svy += pts[i].y - pts[i].oy
        }
        cx = sx / 6
        cy = sy / 6
        cvx = svx / 6
        cvy = svy / 6
    }

    func torsoAngle() -> Float {
        if pts.count < 15 { return 0 }
        let dx: Float = pts[4].x - pts[1].x
        let dy: Float = pts[4].y - pts[1].y
        return atan2(dy, dx)
    }

    // MARK: Rooms

    func setupProps() {
        props = []
        pads = []
        wheels = []
        balls = []
        anims = []
        func add(_ kind: Int, _ x: Float, _ y: Float, _ w: Float, _ h: Float) {
            var p = BuddyProp()
            p.kind = kind
            p.x = x
            p.y = y
            p.w = w
            p.h = h
            if kind == 2 { p.angv = 0.01 }
            props.append(p)
        }
        let f: Float = floorY
        switch selRoom {
        case 0:
            add(0, 62, f - 12, 46, 12)
            add(2, 160, ceilY, 4, 74)
            add(3, 250, f - 26, 66, 26)
        case 1:
            add(0, 250, f - 12, 46, 12)
            add(1, 80, 120, 74, 16)
            add(2, 160, ceilY, 4, 70)
        case 2:
            add(0, 60, f - 12, 52, 12)
            add(1, 235, 110, 70, 16)
            add(2, 160, ceilY, 4, 72)
        case 3:
            add(3, 60, f - 26, 70, 26)
            add(1, 235, 116, 70, 16)
            add(2, 165, ceilY, 4, 72)
        case 4:
            add(1, 70, 100, 70, 16)
            add(1, 250, 140, 70, 16)
            add(0, 160, f - 12, 46, 12)
        case 5:
            add(4, 60, 150, 62, 14)
            add(4, 255, 120, 62, 14)
            add(4, 160, 90, 52, 14)
            add(3, 130, f - 26, 64, 26)
        default:
            add(0, 42, f - 12, 46, 12)
            add(1, 235, 120, 70, 16)
            add(2, 160, ceilY, 4, 72)
            add(3, 255, f - 26, 62, 26)
        }
    }

    func setRoom(_ r: Int) {
        let rr: Int = max(0, min(BuddyData.roomNames.count - 1, r))
        selRoom = rr
        bgRoom = -1
        setupProps()
        resetBuddy()
        sparks = []
        floats = []
        showBanner(BuddyData.roomNames[rr], 0xFFFFFF)
        if rr % 2 == 0 {
            playMusic(Tunes.arcade)
        } else {
            playMusic(Tunes.chill)
        }
    }

    // MARK: Update

    override func update(_ input: InputState) {
        frameN = (frameN + 1) & 0x3FFF_FFFF
        readPointer(input)
        tickGlobals()
        if phase == 0 {
            updateTitle(input)
            return
        }
        if input.selectPressed && menu == 0 { cycleToy() }
        if input.startPressed {
            menu = (menu == 0) ? 1 : 0
        }
        if menu != 0 {
            updateMenu()
            updateSparks()
            updateFloats()
            return
        }
        handleTouch()
        stepWorld()
    }

    func tickGlobals() {
        if giftT > 0 { giftT -= 1 }
        if photoT > 0 { photoT -= 1 }
        if bannerT > 0 { bannerT -= 1 }
        if toastT > 0 { toastT -= 1 }
        if menuShake > 0 { menuShake -= 1 }
        if shelfPop > 0 { shelfPop = max(0, shelfPop - 0.06) }
    }

    func readPointer(_ input: InputState) {
        let ip = input.pointer
        ppressed = false
        preleased = false
        lastPX = px
        lastPY = py
        let touchActive: Bool = ip.down || ip.pressed || ip.released
        if touchActive {
            if ip.x >= 0 && ip.y >= 0 {
                px = Float(ip.x)
                py = Float(ip.y)
            }
            pdown = ip.down
            ppressed = ip.pressed
            preleased = ip.released
            cursorOn = false
        } else {
            let dx: Int = input.dx
            let dy: Int = input.dy
            if dx != 0 || dy != 0 {
                cursorOn = true
                curSpeed = min(5.5, curSpeed + 0.2)
                curX += Float(dx) * curSpeed
                curY += Float(dy) * curSpeed
            } else {
                curSpeed = 2
            }
            curX = buddyClampF(curX, 4, 316)
            curY = buddyClampF(curY, 4, 284)
            let held: Bool = input.a || input.b
            if held { cursorOn = true }
            if cursorOn {
                px = curX
                py = curY
            }
            ppressed = input.aPressed || input.bPressed
            preleased = pdown && !held
            pdown = held
            if ppressed { keyGrab = input.bPressed && !input.aPressed }
        }
        if ppressed {
            fvx = 0
            fvy = 0
        } else if pdown {
            fvx = fvx * 0.55 + (px - lastPX) * 0.45
            fvy = fvy * 0.55 + (py - lastPY) * 0.45
        } else if !preleased {
            fvx *= 0.8
            fvy *= 0.8
        }
    }

    func cycleToy() {
        var n: Int = selToy
        var tries: Int = 0
        while tries < BuddyData.toyCount {
            n = (n + 1) % BuddyData.toyCount
            if toyOwned(n) { break }
            tries += 1
        }
        selToy = n
        play(.select)
        shelfPop = 1
        let target: Float = Float(n) * 44 - 140
        shelfScroll = buddyClampF(target, 0, maxShelfScroll())
        shelfVel = 0
    }

    func maxShelfScroll() -> Float {
        return max(0, Float(BuddyData.toyCount) * 44 + 12 - 320)
    }

    func toyOwned(_ i: Int) -> Bool {
        if i < 0 || i >= BuddyData.toyCount { return false }
        return (toysOwned >> i) & 1 == 1
    }

    // MARK: Touch handling

    static let hudRects: [[Int]] = [
        [3, 3, 28, 24],      // 0 reset
        [3, 29, 28, 24],     // 1 wardrobe
        [3, 55, 28, 24],     // 2 rooms
        [286, 28, 30, 24],   // 3 camera
        [286, 54, 30, 28],   // 4 slot machine
        [124, 2, 72, 28],    // 5 free gift
        [4, 217, 216, 18]    // 6 goals panel
    ]

    func hudButtonAt(_ x: Float, _ y: Float) -> Int {
        var i: Int = 0
        while i < BuddyBounce64.hudRects.count {
            let r: [Int] = BuddyBounce64.hudRects[i]
            let m: Float = 2
            if x >= Float(r[0]) - m && x < Float(r[0] + r[2]) + m && y >= Float(r[1]) - m && y < Float(r[1] + r[3]) + m {
                return i
            }
            i += 1
        }
        return -1
    }

    func nearestPart(_ x: Float, _ y: Float) -> (Int, Float) {
        var best: Int = 0
        var bd: Float = 100000
        var i: Int = 0
        while i < pts.count {
            let dx: Float = pts[i].x - x
            let dy: Float = pts[i].y - y
            let d: Float = sqrt(dx * dx + dy * dy) - pts[i].r
            if d < bd {
                bd = d
                best = i
            }
            i += 1
        }
        return (best, bd)
    }

    func beginTouch() {
        pStartX = px
        pStartY = py
        pFrames = 0
        pMoved = 0
        mode = 0
        holdOn = false
        if py >= Float(shelfTop) {
            mode = 1
            shelfVel = 0
            return
        }
        let b: Int = hudButtonAt(px, py)
        if b >= 0 {
            mode = 2
            btnId = b
            return
        }
        if popCoinAt(px, py) {
            mode = 5
            return
        }
        if keyGrab && !usesHoldToy() {
            let n = nearestPart(px, py)
            if n.1 < 90 {
                startGrab(n.0)
                mode = 4
                return
            }
        }
        let kind: Int = BuddyData.toyKinds[selToy]
        if kind == 1 {
            mode = 6
            holdOn = true
            noteToyUsed(selToy)
        } else if kind == 2 {
            mode = 7
            startSling()
        } else {
            let n = nearestPart(px, py)
            if n.1 < 18 {
                mode = 3
                pendIdx = n.0
            } else {
                useToy(selToy, px, py)
                mode = 5
            }
        }
    }

    func usesHoldToy() -> Bool {
        return BuddyData.toyKinds[selToy] != 0
    }

    func handleTouch() {
        if ppressed { beginTouch() }
        switch mode {
        case 1: touchShelf()
        case 2: touchButton()
        case 3: touchPending()
        case 4: touchGrab()
        case 6: touchHold()
        case 7: touchSling()
        case 5, 8:
            if preleased || !pdown { mode = 0 }
        default:
            break
        }
        if !pdown && !preleased && mode != 0 {
            releaseGrab()
            slingOn = false
            holdOn = false
            mode = 0
        }
        if mode != 1 {
            shelfScroll += shelfVel
            shelfVel *= 0.92
            if abs(shelfVel) < 0.05 { shelfVel = 0 }
        }
        shelfScroll = buddyClampF(shelfScroll, 0, maxShelfScroll())
    }

    func touchShelf() {
        if pdown {
            pFrames += 1
            if !ppressed {
                let dx: Float = px - lastPX
                shelfScroll -= dx
                shelfVel = -dx
                pMoved += abs(dx)
            }
        }
        if preleased {
            if pMoved < 8 && pFrames < 30 { tapShelf(pStartX) }
            mode = 0
        }
    }

    func tapShelf(_ x: Float) {
        let local: Float = x + shelfScroll - 8
        if local < 0 { return }
        let idx: Int = Int(local / 44)
        let off: Float = local - Float(idx) * 44
        if idx < 0 || idx >= BuddyData.toyCount || off > 42 { return }
        selectToy(idx)
    }

    func selectToy(_ i: Int) {
        if toyOwned(i) {
            selToy = i
            shelfPop = 1
            play(.select)
            return
        }
        let price: Int = BuddyData.toyPrice[i]
        if BuddyData.toyGold[i] {
            if gold >= price {
                gold -= price
                unlockToy(i)
            } else {
                notEnough("GOLD")
            }
        } else {
            if cash >= price {
                cash -= price
                unlockToy(i)
            } else {
                notEnough("CASH")
            }
        }
    }

    func unlockToy(_ i: Int) {
        toysOwned |= (1 << i)
        selToy = i
        shelfPop = 1
        play(.powerup)
        showBanner("NEW TOY! " + BuddyData.toyNames[i], 0xFFE066)
        confettiBurst(160, 140, 40)
    }

    func notEnough(_ what: String) {
        play(.blip)
        menuShake = 18
        addFloat("NEED MORE " + what, 160, 228, 0xFFE066)
    }

    func touchButton() {
        if pdown { pMoved += abs(px - lastPX) + abs(py - lastPY) }
        if preleased {
            let b: Int = hudButtonAt(px, py)
            if b == btnId && pMoved < 30 { doButton(btnId) }
            mode = 0
        }
    }

    func doButton(_ id: Int) {
        switch id {
        case 0:
            resetBuddy()
            play(.select)
            confettiBurst(160, 90, 14)
        case 1:
            menu = 1
            play(.select)
        case 2:
            menu = 2
            play(.select)
        case 3:
            takePhoto()
        case 4:
            openSlot()
        case 5:
            claimGift()
        case 6:
            menu = 3
            play(.select)
        default:
            break
        }
    }

    func touchPending() {
        pFrames += 1
        let dx: Float = px - pStartX
        let dy: Float = py - pStartY
        let moved: Float = sqrt(dx * dx + dy * dy)
        if moved > 7 {
            startGrab(pendIdx)
            mode = 4
            return
        }
        if preleased || pFrames >= 5 {
            useToy(selToy, pStartX, pStartY)
            mode = preleased ? 0 : 5
        }
    }

    func startGrab(_ idx: Int) {
        grabIdx = max(0, min(pts.count - 1, idx))
        play(.pickup)
        idleT = 0
        if exprT < 20 || expr == 4 {
            expr = 3
            exprT = 24
            exprNext = 1
        }
        flung = false
    }

    func touchGrab() {
        if preleased || !pdown { releaseGrab(); mode = 0 }
    }

    func releaseGrab() {
        if grabIdx < 0 { return }
        let sp: Float = sqrt(fvx * fvx + fvy * fvy)
        var i: Int = 0
        let bx: Float = buddyClampF(fvx * 0.32, -6, 6)
        let by: Float = buddyClampF(fvy * 0.32, -6, 6)
        while i < pts.count {
            impulse(i, bx, by)
            i += 1
        }
        grabIdx = -1
        if sp > 6.5 {
            flung = true
            flingDone = false
            flingStartX = cx
            flingT = 0
            wasSlung = false
            let bonus: Int = Int(min(30, sp * 1.2))
            addFloat("FLING +" + String(bonus), cx, cy - 40, 0xFFF08A)
            cash += max(1, bonus / 8)
            addCombo(Int(min(14, sp)))
            statFlings += 1
            play(.jump)
            expr = 1
            exprT = 80
            bubble = "WHEEE!"
            bubbleT = 80
        }
    }

    // MARK: Physics

    @inline(__always) func impulse(_ i: Int, _ ix: Float, _ iy: Float) {
        if i < 0 || i >= pts.count { return }
        pts[i].ox -= ix
        pts[i].oy -= iy
    }

    func stepWorld() {
        applyForces()
        stepBuddy()
        updateProps()
        updatePads()
        updateWheels()
        updateBalls()
        updateAnims()
        updateSparks()
        updateFloats()
        updateCoins()
        updateExpr()
        updateMeter()
        if ballSfxCool > 0 { ballSfxCool -= 1 }
        if bounceCool > 0 { bounceCool -= 1 }
    }

    func stepBuddy() {
        let rg: Float = BuddyData.roomGravity[selRoom]
        let wallRest: Float = BuddyData.roomWallRest[selRoom]
        let floorRest: Float = BuddyData.roomFloorRest[selRoom]
        frameImpact = 0
        // grab spring
        if grabIdx >= 0 && grabIdx < pts.count {
            let g: Int = grabIdx
            let tx: Float = buddyClampF(px, wallL + 4, wallR - 4)
            let ty: Float = buddyClampF(py, ceilY + 4, floorY - 4)
            let vx: Float = pts[g].x - pts[g].ox
            let vy: Float = pts[g].y - pts[g].oy
            let ax: Float = (tx - pts[g].x) * 0.24 - vx * 0.28
            let ay: Float = (ty - pts[g].y) * 0.24 - vy * 0.28
            impulse(g, ax, ay)
        }
        // integrate
        let vmax: Float = 15
        var i: Int = 0
        while i < pts.count {
            var vx: Float = (pts[i].x - pts[i].ox) * 0.997
            var vy: Float = (pts[i].y - pts[i].oy) * 0.997
            let sp2: Float = vx * vx + vy * vy
            if sp2 > vmax * vmax {
                let sc: Float = vmax / sqrt(sp2)
                vx *= sc
                vy *= sc
            }
            pts[i].ox = pts[i].x
            pts[i].oy = pts[i].y
            pts[i].x += vx
            pts[i].y += vy + rg
            i += 1
        }
        var iter: Int = 0
        while iter < 3 {
            solveLinks()
            collideBounds(wallRest, floorRest)
            collidePlats()
            collideProps()
            iter += 1
        }
        // floor friction
        let fric: Float = BuddyData.roomFric[selRoom]
        i = 0
        while i < pts.count {
            if pts[i].y >= floorY - pts[i].r - 0.6 {
                pts[i].ox = pts[i].x - (pts[i].x - pts[i].ox) * fric
            }
            i += 1
        }
        // numeric safety
        var bad: Bool = false
        i = 0
        while i < pts.count {
            if !pts[i].x.isFinite || !pts[i].y.isFinite || !pts[i].ox.isFinite || !pts[i].oy.isFinite { bad = true }
            if abs(pts[i].x) > 2000 || abs(pts[i].y) > 2000 { bad = true }
            i += 1
        }
        if bad {
            resetBuddy()
        }
        computeCentroid()
        // squash springs
        headSqV += -headSq * 0.22
        headSqV *= 0.82
        headSq += headSqV
        headSq = buddyClampF(headSq, -0.35, 0.35)
        bodySqV += -bodySq * 0.2
        bodySqV *= 0.82
        bodySq += bodySqV
        bodySq = buddyClampF(bodySq, -0.3, 0.3)
        if frameImpact > 3.2 { onImpact(frameImpact) }
        trackFlight()
    }

    func solveLinks() {
        var li: Int = 0
        while li < links.count {
            let l: BuddyLink = links[li]
            li += 1
            let a: Int = l.a
            let b: Int = l.b
            let dx: Float = pts[b].x - pts[a].x
            let dy: Float = pts[b].y - pts[a].y
            let d2: Float = dx * dx + dy * dy
            if d2 < 0.0001 { continue }
            let d: Float = sqrt(d2)
            if l.mode == 1 && d >= l.len { continue }
            if l.mode == 2 && d <= l.len { continue }
            var wa: Float = pts[a].w
            var wb: Float = pts[b].w
            if a == grabIdx { wa = 0.15 }
            if b == grabIdx { wb = 0.15 }
            let ws: Float = wa + wb
            if ws < 0.0001 { continue }
            let diff: Float = (d - l.len) / d * l.k / ws
            pts[a].x += dx * diff * wa
            pts[a].y += dy * diff * wa
            pts[b].x -= dx * diff * wb
            pts[b].y -= dy * diff * wb
        }
    }

    func collideBounds(_ wallRest: Float, _ floorRest: Float) {
        var i: Int = 0
        while i < pts.count {
            let r: Float = pts[i].r
            if pts[i].y > floorY - r {
                let vy: Float = pts[i].y - pts[i].oy
                pts[i].y = floorY - r
                if vy > 0 {
                    var rest: Float = floorRest
                    if vy < 1.6 { rest = 0 }
                    pts[i].oy = pts[i].y + vy * rest
                    if vy > frameImpact { frameImpact = vy }
                }
            }
            if pts[i].y < ceilY + r {
                let vy: Float = pts[i].y - pts[i].oy
                pts[i].y = ceilY + r
                if vy < 0 {
                    pts[i].oy = pts[i].y + vy * wallRest
                    if -vy > frameImpact { frameImpact = -vy }
                }
            }
            if pts[i].x < wallL + r {
                let vx: Float = pts[i].x - pts[i].ox
                pts[i].x = wallL + r
                if vx < 0 {
                    pts[i].ox = pts[i].x + vx * wallRest
                    if -vx > frameImpact { frameImpact = -vx }
                }
            }
            if pts[i].x > wallR - r {
                let vx: Float = pts[i].x - pts[i].ox
                pts[i].x = wallR - r
                if vx > 0 {
                    pts[i].ox = pts[i].x + vx * wallRest
                    if vx > frameImpact { frameImpact = vx }
                }
            }
            i += 1
        }
    }

    /// mode 0: soft bounce, 1: launcher, 2: conveyor/rest. Returns the impact speed (0 when nothing happened).
    func platCollide(_ x0: Float, _ x1: Float, _ top: Float, _ mode: Int, _ bounce: Float, _ minUp: Float, _ kick: Float, _ armed: Bool) -> Float {
        var hit: Float = 0
        var i: Int = 0
        while i < pts.count {
            defer { i += 1 }
            let r: Float = pts[i].r
            let ppx: Float = pts[i].x
            if ppx < x0 - 3 || ppx > x1 + 3 { continue }
            let vy: Float = pts[i].y - pts[i].oy
            if vy < -0.5 { continue }
            let bottom: Float = pts[i].y + r
            let prevBottom: Float = pts[i].oy + r
            if bottom < top { continue }
            if mode == 1 {
                if !armed || bottom > top + 30 { continue }
                pts[i].y = top - r
                pts[i].oy = pts[i].y + minUp
                pts[i].ox -= kick
                if minUp > hit { hit = minUp }
            } else {
                if prevBottom > top + 8 { continue }
                pts[i].y = top - r
                if mode == 2 {
                    pts[i].oy = pts[i].y
                    pts[i].ox -= kick
                    pts[i].ox = pts[i].x - (pts[i].x - pts[i].ox) * 0.93
                } else if vy >= 1.0 {
                    var nv: Float = -(vy * bounce)
                    if nv > -minUp { nv = -minUp }
                    if nv < -13.5 { nv = -13.5 }
                    pts[i].oy = pts[i].y - nv
                    if vy > hit { hit = vy }
                } else {
                    pts[i].oy = pts[i].y
                }
            }
        }
        return hit
    }

    func collidePlats() {
        var k: Int = 0
        while k < props.count {
            let p: BuddyProp = props[k]
            var hit: Float = 0
            let x0: Float = p.x - p.w * 0.5
            let x1: Float = p.x + p.w * 0.5
            if p.kind == 0 {
                hit = platCollide(x0, x1, p.y, 1, 0, 11.5, 0, p.cool == 0)
            } else if p.kind == 1 {
                hit = platCollide(x0, x1, p.y, 0, 1.08, 6.5, 0, true)
            } else if p.kind == 4 {
                hit = platCollide(x0, x1, p.y, 0, 1.0, 5.5, 0, true)
            }
            if hit > 0 { propHit(k, hit) }
            k += 1
        }
        k = 0
        while k < pads.count {
            let p: BuddyPad = pads[k]
            let x0: Float = p.x - p.w * 0.5
            let x1: Float = p.x + p.w * 0.5
            var hit: Float = 0
            let armed: Bool = p.cool == 0
            switch p.kind {
            case 0:
                hit = platCollide(x0, x1, p.y, 0, 1.1, 7, 0, true)
            case 1:
                hit = platCollide(x0, x1, p.y, 1, 0, 11, p.dir * 2.2, armed)
            case 2:
                let side: Float = cx < p.x ? 1 : -1
                hit = platCollide(x0, x1, p.y, 1, 0, 9.5, side * 3, armed)
            case 3:
                _ = platCollide(x0, x1, p.y, 2, 0, 0, p.dir * 0.28, true)
            default:
                hit = platCollide(x0, x1, p.y, 1, 0, 12.5, p.dir * 6.5, armed)
            }
            if hit > 0 { padHit(k, hit) }
            k += 1
        }
    }

    func collideProps() {
        var k: Int = 0
        while k < props.count {
            let p: BuddyProp = props[k]
            if p.kind == 2 {
                let bxp: Float = p.x + p.h * sin(p.ang)
                let byp: Float = p.y + p.h * cos(p.ang)
                var i: Int = 0
                while i < pts.count {
                    let dx: Float = pts[i].x - bxp
                    let dy: Float = pts[i].y - byp
                    let d: Float = sqrt(dx * dx + dy * dy)
                    if d < 14 + pts[i].r * 0.6 {
                        let vx: Float = pts[i].x - pts[i].ox
                        props[k].angv += buddyClampF(vx * 0.004, -0.03, 0.03)
                        if abs(vx) > 0.8 || p.cool == 0 {
                            if p.cool == 0 { ringBell(k) }
                        }
                        let nd: Float = max(d, 1)
                        pts[i].x += dx / nd * 0.8
                        pts[i].y += dy / nd * 0.8
                    }
                    i += 1
                }
            } else if p.kind == 3 {
                let x0: Float = p.x - p.w * 0.5
                let x1: Float = p.x + p.w * 0.5
                var i: Int = 0
                while i < pts.count {
                    let ppx: Float = pts[i].x
                    if ppx > x0 && ppx < x1 && pts[i].y + pts[i].r > p.y {
                        let vy: Float = pts[i].y - pts[i].oy
                        if vy > 3 && p.cool == 0 { pitSplash(k, pts[i].x, p.y, vy) }
                        pts[i].ox = pts[i].x - (pts[i].x - pts[i].ox) * 0.9
                        pts[i].oy = pts[i].y - (pts[i].y - pts[i].oy) * 0.9
                        if pts[i].y > p.y + 8 { pts[i].oy += 0.12 }
                    }
                    i += 1
                }
            }
            k += 1
        }
    }

    func ringBell(_ k: Int) {
        props[k].cool = 22
        props[k].anim = 1
        play(.coin)
        addCombo(6)
        let bxp: Float = props[k].x + props[k].h * sin(props[k].ang)
        let byp: Float = props[k].y + props[k].h * cos(props[k].ang)
        var i: Int = 0
        while i < 6 {
            spark(bxp, byp, Float(rng.range(-30, 30)) / 10, Float(rng.range(-30, 10)) / 10, 24, 5, 0xFFE066, 3, 0.05)
            i += 1
        }
        addFloat("DING!", bxp, byp - 14, 0xFFE066)
    }

    func pitSplash(_ k: Int, _ x: Float, _ y: Float, _ speed: Float) {
        props[k].cool = 25
        props[k].anim = 1
        play(.drop)
        addCombo(5)
        var i: Int = 0
        while i < 10 {
            let c: UInt32 = BuddyData.confettiColors[rng.int(BuddyData.confettiColors.count)]
            spark(x + Float(rng.range(-12, 12)), y, Float(rng.range(-25, 25)) / 10, -Float(rng.range(20, 50)) / 10, 40, 2, c, 4, 0.2)
            i += 1
        }
        addFloat("SPLASH!", x, y - 24, 0xFFFFFF)
        squashBody(0.12)
    }

    func propHit(_ k: Int, _ speed: Float) {
        props[k].anim = 1
        props[k].cool = 14
        play(.bounce)
        squashBody(min(0.25, speed * 0.02))
        addCombo(speed > 8 ? 10 : 6)
        statBounces += 1
        goalProgress(0, 1)
        let px0: Float = props[k].x
        let py0: Float = props[k].y
        var i: Int = 0
        while i < 6 {
            spark(px0 + Float(rng.range(-16, 16)), py0, Float(rng.range(-20, 20)) / 10, -Float(rng.range(10, 40)) / 10, 26, 5, 0xFFFFFF, 3, 0.05)
            i += 1
        }
        if speed > 7 {
            expr = 1
            exprT = 70
            bubble = "WHEEE!"
            bubbleT = 70
        }
    }

    func padHit(_ k: Int, _ speed: Float) {
        pads[k].anim = 1
        pads[k].cool = 24
        play(.bounce)
        squashBody(min(0.25, speed * 0.02))
        addCombo(8)
        statBounces += 1
        goalProgress(0, 1)
        let kind: Int = pads[k].kind
        if kind == 4 || kind == 1 {
            addFloat("BOING!", pads[k].x, pads[k].y - 24, 0xFFFFFF)
            confettiBurst(pads[k].x, pads[k].y - 10, 10)
            expr = 1
            exprT = 80
            bubble = "WHEEE!"
            bubbleT = 80
            if kind == 4 {
                flung = true
                flingDone = false
                flingStartX = cx
                flingT = 0
            }
        }
    }

    func squashBody(_ s: Float) {
        bodySqV += s
        headSqV += s * 1.2
    }

    func onImpact(_ speed: Float) {
        if bounceCool > 0 { return }
        bounceCool = 12
        statBounces += 1
        goalProgress(0, 1)
        play(.bounce)
        squashBody(min(0.3, speed * 0.025))
        addCombo(Int(min(10, speed)))
        var i: Int = 0
        let n: Int = Int(min(8, speed))
        while i < n {
            spark(cx + Float(rng.range(-14, 14)), min(cy + 30, floorY - 2), Float(rng.range(-20, 20)) / 10, -Float(rng.range(5, 25)) / 10, 18, 2, 0xE8D8B0, 2.5, 0.08)
            i += 1
        }
        if speed > 5 && exprT < 30 && dizzyT == 0 {
            expr = 1
            exprT = 60
            if rng.chance(45) {
                bubble = BuddyData.speechHappy[rng.int(BuddyData.speechHappy.count)]
                bubbleT = 60
            }
        }
        idleT = 0
    }

    func trackFlight() {
        // airtime combos
        let high: Bool = cy < floorY - 60
        if high && grabIdx < 0 {
            airFrames += 1
            if airFrames % 45 == 0 {
                addCombo(3)
                addFloat("AIR!", cx, cy - 36, 0xBFF0FF)
            }
        } else if cy > floorY - 40 {
            airFrames = 0
        }
        // fling distance
        if flung {
            flingT += 1
            if !flingDone && abs(cx - flingStartX) > 170 {
                flingDone = true
                goalProgress(1, 1)
                addFloat("SUPER FLING!", cx, cy - 46, 0xFFF08A)
                addCombo(14)
                cash += 5
                play(.powerup)
            }
            let slow: Bool = (abs(cvx) + abs(cvy)) < 0.8 && cy > floorY - 40
            if flingT > 300 || (flingT > 20 && slow) { flung = false }
        }
        // spin tracking
        let a: Float = torsoAngle()
        var d: Float = a - lastTorsoAng
        if d > Float.pi { d -= 2 * Float.pi }
        if d < -Float.pi { d += 2 * Float.pi }
        lastTorsoAng = a
        if grabIdx < 0 && cy < floorY - 25 {
            spinAccum += d
        } else {
            spinAccum *= 0.9
        }
        spinAccum *= 0.996
        if abs(spinAccum) > 11 {
            spinAccum = 0
            dizzyT = 200
            bubble = "WHOA!"
            bubbleT = 90
            play(.blip)
            addCombo(8)
            var i: Int = 0
            while i < 8 {
                spark(pts[0].x, pts[0].y - 10, Float(rng.range(-20, 20)) / 10, -Float(rng.range(5, 25)) / 10, 30, 0, 0xFFE066, 4, 0.02)
                i += 1
            }
        }
    }

    // MARK: Props, pads, wheels, balls

    func updateProps() {
        var k: Int = 0
        while k < props.count {
            props[k].anim *= 0.9
            if props[k].cool > 0 { props[k].cool -= 1 }
            if props[k].kind == 2 {
                let len: Float = max(20, props[k].h)
                props[k].angv += -(BuddyData.roomGravity[selRoom] / len) * sin(props[k].ang)
                props[k].angv *= 0.995
                props[k].ang += props[k].angv
                props[k].ang = buddyClampF(props[k].ang, -1.2, 1.2)
                if abs(props[k].ang) < 0.02 && abs(props[k].angv) < 0.002 {
                    props[k].angv = 0.004
                }
            }
            k += 1
        }
    }

    func placePad(_ kind: Int, _ x: Float, _ y: Float) {
        var p = BuddyPad()
        p.kind = kind
        switch kind {
        case 0:
            p.w = 66
            p.y = buddyClampF(y, 100, floorY - 10)
        case 1:
            p.w = 54
            p.y = floorY - 14
        case 2:
            p.w = 94
            p.y = floorY - 14
        case 3:
            p.w = 98
            p.y = floorY - 8
        default:
            p.w = 58
            p.y = floorY - 18
        }
        p.x = buddyClampF(x, wallL + p.w * 0.5, wallR - p.w * 0.5)
        p.dir = p.x < 160 ? 1 : -1
        p.life = 900
        p.anim = 1
        if pads.count >= 4 { pads.remove(at: 0) }
        pads.append(p)
        play(.select)
        var i: Int = 0
        while i < 8 {
            spark(p.x + Float(rng.range(-30, 30)), p.y, Float(rng.range(-15, 15)) / 10, -Float(rng.range(5, 20)) / 10, 24, 5, 0xFFFFFF, 3, 0.03)
            i += 1
        }
    }

    func updatePads() {
        var k: Int = 0
        while k < pads.count {
            pads[k].life -= 1
            pads[k].anim *= 0.9
            if pads[k].cool > 0 { pads[k].cool -= 1 }
            pads[k].phase += pads[k].dir * 0.5
            k += 1
        }
        var j: Int = pads.count - 1
        while j >= 0 {
            if pads[j].life <= 0 {
                let p: BuddyPad = pads[j]
                var i: Int = 0
                while i < 8 {
                    spark(p.x + Float(rng.range(-30, 30)), p.y, Float(rng.range(-15, 15)) / 10, -Float(rng.range(5, 20)) / 10, 20, 5, 0xFFFFFF, 3, 0.03)
                    i += 1
                }
                pads.remove(at: j)
            }
            j -= 1
        }
    }

    func updateWheels() {
        var k: Int = 0
        while k < wheels.count {
            wheels[k].life -= 1
            wheels[k].rot += wheels[k].spin
            let w: BuddyWheel = wheels[k]
            var i: Int = 0
            while i < pts.count {
                let dx: Float = pts[i].x - w.x
                let dy: Float = pts[i].y - w.y
                let d: Float = sqrt(dx * dx + dy * dy)
                if d < w.r + pts[i].r && d > 1 {
                    let f: Float = 1 - d / (w.r + pts[i].r) * 0.5
                    let tx: Float = -dy / d
                    let ty: Float = dx / d
                    let s: Float = w.spin > 0 ? 1 : -1
                    impulse(i, tx * s * 0.9 * f, ty * s * 0.9 * f)
                    // gentle pull to the rim so the buddy rides around
                    impulse(i, -dx / d * 0.05, -dy / d * 0.05)
                }
                i += 1
            }
            k += 1
        }
        var j: Int = wheels.count - 1
        while j >= 0 {
            if wheels[j].life <= 0 { wheels.remove(at: j) }
            j -= 1
        }
    }

    func spawnBall(_ x: Float, _ y: Float, _ vx: Float, _ vy: Float, _ kind: Int) {
        var b = BuddyBall()
        b.x = buddyClampF(x, wallL + 10, wallR - 10)
        b.y = buddyClampF(y, ceilY + 10, floorY - 10)
        b.vx = vx
        b.vy = vy
        b.kind = kind
        switch kind {
        case 1:
            b.r = 22
            b.life = 900
        case 2:
            b.r = 18
            b.life = 700
        default:
            b.r = 6
            b.life = 600
        }
        b.col = BuddyData.confettiColors[rng.int(BuddyData.confettiColors.count)]
        b.rotV = Float(rng.range(-10, 10)) / 60
        if balls.count >= 12 { balls.remove(at: 0) }
        balls.append(b)
    }

    func updateBalls() {
        let g: Float = BuddyData.roomGravity[selRoom]
        let wallRest: Float = BuddyData.roomWallRest[selRoom]
        var k: Int = 0
        while k < balls.count {
            var b: BuddyBall = balls[k]
            b.life -= 1
            if b.cool > 0 { b.cool -= 1 }
            b.vy += g * (b.kind == 1 ? 0.7 : 1.0)
            b.vx *= 0.999
            b.vx = buddyClampF(b.vx, -14, 14)
            b.vy = buddyClampF(b.vy, -16, 16)
            b.x += b.vx
            b.y += b.vy
            b.rot += b.rotV
            b.sq *= 0.85
            let e: Float = b.kind == 2 ? 0.55 : 0.9
            if b.y > floorY - b.r {
                b.y = floorY - b.r
                if b.vy > 1.5 {
                    b.sq = 0.3
                    if ballSfxCool == 0 {
                        play(b.kind == 2 ? .pickup : .bounce)
                        ballSfxCool = 6
                    }
                }
                b.vy = -b.vy * e
                b.vx *= 0.985
                if abs(b.vy) < 0.8 { b.vy = 0 }
                b.rotV = b.vx * 0.02
            }
            if b.y < ceilY + b.r {
                b.y = ceilY + b.r
                b.vy = abs(b.vy) * e
            }
            if b.x < wallL + b.r {
                b.x = wallL + b.r
                b.vx = abs(b.vx) * max(e, wallRest)
                b.sq = 0.2
            }
            if b.x > wallR - b.r {
                b.x = wallR - b.r
                b.vx = -abs(b.vx) * max(e, wallRest)
                b.sq = 0.2
            }
            // props: spring pads and platforms bounce balls
            var pk: Int = 0
            while pk < props.count {
                let p: BuddyProp = props[pk]
                if (p.kind == 0 || p.kind == 1 || p.kind == 4) && b.vy > 0 {
                    if b.x > p.x - p.w * 0.5 && b.x < p.x + p.w * 0.5 && b.y + b.r > p.y && b.y + b.r < p.y + 14 {
                        b.y = p.y - b.r
                        b.vy = -max(7, b.vy * 1.05)
                        props[pk].anim = 1
                    }
                }
                pk += 1
            }
            // buddy collisions
            let mass: Float = b.r / 6
            var i: Int = 0
            while i < pts.count {
                let dx: Float = b.x - pts[i].x
                let dy: Float = b.y - pts[i].y
                let minD: Float = b.r + pts[i].r * 0.8
                let d2: Float = dx * dx + dy * dy
                if d2 < minD * minD && d2 > 0.0001 {
                    let d: Float = sqrt(d2)
                    let nx: Float = dx / d
                    let ny: Float = dy / d
                    let pen: Float = minD - d
                    b.x += nx * pen * 0.7
                    b.y += ny * pen * 0.7
                    pts[i].x -= nx * pen * 0.3
                    pts[i].y -= ny * pen * 0.3
                    let dot: Float = b.vx * nx + b.vy * ny
                    if dot < 0 {
                        b.vx -= nx * dot * 1.8
                        b.vy -= ny * dot * 1.8
                        let imp: Float = min(5, 0.4 * mass * (1 + abs(dot) * 0.4))
                        impulse(i, -nx * imp, -ny * imp)
                        b.sq = 0.3
                        if b.cool == 0 {
                            b.cool = 14
                            addCombo(2)
                            if ballSfxCool == 0 {
                                play(b.kind == 2 ? .pickup : .bounce)
                                ballSfxCool = 5
                            }
                            reactHit()
                        }
                    }
                }
                i += 1
            }
            balls[k] = b
            k += 1
        }
        var j: Int = balls.count - 1
        while j >= 0 {
            if balls[j].life <= 0 {
                let b: BuddyBall = balls[j]
                var i: Int = 0
                while i < 8 {
                    spark(b.x, b.y, Float(rng.range(-25, 25)) / 10, Float(rng.range(-25, 25)) / 10, 20, 5, b.col, 3, 0.04)
                    i += 1
                }
                balls.remove(at: j)
            }
            j -= 1
        }
    }

    // MARK: Sparks, floats, coins

    func spark(_ x: Float, _ y: Float, _ vx: Float, _ vy: Float, _ life: Int, _ kind: Int, _ col: UInt32, _ size: Float, _ grav: Float) {
        if sparks.count >= 320 { return }
        let rot: Float = Float(rng.int(628)) / 100
        sparks.append(BuddySpark(x: x, y: y, vx: vx, vy: vy, life: max(1, life), maxLife: max(1, life), kind: kind, col: col, size: size, grav: grav, rot: rot))
    }

    func updateSparks() {
        var i: Int = 0
        while i < sparks.count {
            sparks[i].x += sparks[i].vx
            sparks[i].y += sparks[i].vy
            sparks[i].vy += sparks[i].grav
            sparks[i].rot += 0.2
            if sparks[i].kind == 1 {
                sparks[i].vx *= 0.97
                if sparks[i].vy > 1.3 { sparks[i].vy = 1.3 }
                sparks[i].x += sin(sparks[i].rot * 0.7) * 0.5
            } else if sparks[i].kind == 7 {
                sparks[i].vx *= 0.98
                sparks[i].vy *= 0.98
            } else {
                sparks[i].vx *= 0.99
            }
            sparks[i].life -= 1
            i += 1
        }
        var j: Int = sparks.count - 1
        while j >= 0 {
            if sparks[j].life <= 0 || sparks[j].y > 300 || sparks[j].y < -40 { sparks.remove(at: j) }
            j -= 1
        }
    }

    func confettiBurst(_ x: Float, _ y: Float, _ n: Int) {
        var i: Int = 0
        while i < n {
            let ang: Float = Float(rng.int(628)) / 100
            let sp: Float = Float(rng.range(10, 70)) / 10
            let c: UInt32 = BuddyData.confettiColors[rng.int(BuddyData.confettiColors.count)]
            spark(x, y, cos(ang) * sp, sin(ang) * sp - 2, rng.range(70, 150), 1, c, Float(rng.range(20, 40)) / 10, 0.12)
            i += 1
        }
    }

    func addFloat(_ text: String, _ x: Float, _ y: Float, _ col: UInt32) {
        if floats.count >= 8 { floats.remove(at: 0) }
        floats.append(BuddyFloat(x: x, y: y, text: text, life: 60, col: col))
    }

    func updateFloats() {
        var i: Int = 0
        while i < floats.count {
            floats[i].y -= 0.7
            floats[i].life -= 1
            i += 1
        }
        var j: Int = floats.count - 1
        while j >= 0 {
            if floats[j].life <= 0 { floats.remove(at: j) }
            j -= 1
        }
        var k: Int = bursts.count - 1
        while k >= 0 {
            bursts[k].t += 1
            if bursts[k].t >= bursts[k].maxT { bursts.remove(at: k) }
            k -= 1
        }
    }

    func addBurst(_ x: Float, _ y: Float, _ text: String, _ col: UInt32) {
        if bursts.count >= 4 { bursts.remove(at: 0) }
        var b = BuddyBurst()
        b.x = x
        b.y = y
        b.text = text
        b.col = col
        bursts.append(b)
    }

    func showBanner(_ text: String, _ col: UInt32) {
        bannerText = text
        bannerT = 100
        bannerCol = col
    }

    func showToast(_ text: String) {
        toastText = text
        toastT = 150
    }

    func spawnCoin(_ gold: Bool) {
        var c = BuddyCoin()
        c.x = Float(rng.range(40, 280))
        c.bx = c.x
        c.y = Float(rng.range(80, 170))
        c.ph = Float(rng.int(628)) / 100
        c.life = 900
        c.gold = gold
        coinB.append(c)
    }

    func updateCoins() {
        coinSpawnT -= 1
        if coinSpawnT <= 0 {
            coinSpawnT = rng.range(220, 420)
            if coinB.count < 3 { spawnCoin(rng.chance(8)) }
        }
        var k: Int = coinB.count - 1
        while k >= 0 {
            coinB[k].ph += 0.05
            coinB[k].x = coinB[k].bx + sin(coinB[k].ph) * 8
            coinB[k].y += sin(coinB[k].ph * 0.7) * 0.15
            coinB[k].life -= 1
            var got: Bool = false
            var i: Int = 0
            while i < pts.count {
                let dx: Float = pts[i].x - coinB[k].x
                let dy: Float = pts[i].y - coinB[k].y
                if dx * dx + dy * dy < (14 + pts[i].r) * (14 + pts[i].r) { got = true }
                i += 1
            }
            if got {
                collectCoin(k)
            } else if coinB[k].life <= 0 {
                coinB.remove(at: k)
            }
            k -= 1
        }
    }

    func collectCoin(_ k: Int) {
        if k < 0 || k >= coinB.count { return }
        let c: BuddyCoin = coinB[k]
        coinB.remove(at: k)
        play(.coin)
        if c.gold {
            gold = min(9999, gold + 1)
            addFloat("+1 GOLD", c.x, c.y - 10, 0xFFD23C)
        } else {
            cash = min(999999, cash + 5)
            addFloat("+5", c.x, c.y - 10, 0x9BF28A)
        }
        var i: Int = 0
        while i < 8 {
            let ang: Float = Float(i) * 0.785
            spark(c.x, c.y, cos(ang) * 2, sin(ang) * 2, 20, 5, c.gold ? 0xFFD23C : 0xFFFFFF, 3, 0.02)
            i += 1
        }
    }

    func popCoinAt(_ x: Float, _ y: Float) -> Bool {
        var k: Int = 0
        while k < coinB.count {
            let dx: Float = coinB[k].x - x
            let dy: Float = coinB[k].y - y
            if dx * dx + dy * dy < 22 * 22 {
                collectCoin(k)
                return true
            }
            k += 1
        }
        return false
    }

    // MARK: Expression, meter, combos

    func reactHit() {
        expr = 3
        exprT = 16
        exprNext = 1
        idleT = 0
    }

    func updateExpr() {
        if bubbleT > 0 { bubbleT -= 1 }
        if wetT > 0 {
            wetT -= 1
            if frameN % 5 == 0 {
                let i: Int = rng.int(pts.count)
                spark(pts[i].x, pts[i].y + 4, Float(rng.range(-8, 8)) / 10, 0.3, 26, 3, 0x7FD4FF, 2.5, 0.2)
            }
            if wetT > 180 && wetT % 12 == 0 {
                // shake dry
                impulse(8, Float(rng.range(-12, 12)) / 10, 0)
                impulse(10, Float(rng.range(-12, 12)) / 10, 0)
                impulse(0, Float(rng.range(-8, 8)) / 10, 0)
            }
        }
        if creamT > 0 { creamT -= 1 }
        if dizzyT > 0 {
            dizzyT -= 1
            expr = 2
            if frameN % 8 == 0 {
                spark(pts[0].x + cos(Float(frameN) * 0.2) * 14, pts[0].y - 12, 0, -0.3, 20, 0, 0xFFE066, 3, 0)
            }
            if dizzyT == 0 { expr = 1; exprT = 50 }
            return
        }
        if exprT > 0 {
            exprT -= 1
            if exprT == 0 {
                if exprNext != 0 {
                    expr = exprNext
                    exprT = 60
                    exprNext = 0
                    if expr == 1 && bubbleT == 0 {
                        bubble = BuddyData.speechHappy[rng.int(BuddyData.speechHappy.count)]
                        bubbleT = 60
                    }
                } else {
                    expr = 0
                }
            }
        } else if expr != 4 {
            expr = 0
        }
        // idle / sleepy
        let calm: Bool = (abs(cvx) + abs(cvy)) < 0.5 && grabIdx < 0 && cy > floorY - 50
        if calm && !tickleActive && rocketT == 0 {
            idleT += 1
        } else {
            if idleT > 700 && expr == 4 { expr = 0 }
            idleT = 0
        }
        if idleT > 600 && expr != 4 && exprT == 0 {
            expr = 4
            bubble = "ZZZ"
            bubbleT = 90
        }
        if expr == 4 && idleT > 0 && idleT % 120 == 0 {
            bubble = "ZZZ"
            bubbleT = 80
        }
        if idleT > 1000 {
            // wake up with a happy hop
            idleT = 0
            expr = 1
            exprT = 80
            bubble = "HEE HEE!"
            bubbleT = 80
            var i: Int = 0
            while i < pts.count {
                impulse(i, 0, 5.5)
                i += 1
            }
            impulse(0, 0, 2)
            addCombo(2)
            play(.jump)
        }
    }

    func updateMeter() {
        if comboT > 0 {
            comboT -= 1
            if comboT == 0 { comboCount = 0 }
        }
        meterIdle += 1
        if meterIdle > 150 && meter > 0 { meter = max(0, meter - 0.12) }
        if tickleActive { statTickleTick() }
    }

    func addCombo(_ amount: Int) {
        if phase != 1 { return }
        comboCount += 1
        comboT = 150
        if comboCount > statBestCombo { statBestCombo = min(9999, comboCount) }
        let mult: Float = 1 + min(2, Float(comboCount) / 10)
        meter += Float(max(1, amount)) * mult
        meterIdle = 0
        if comboCount >= 5 && comboCount % 5 == 0 {
            showBanner("COMBO X" + String(comboCount) + "!", 0xFFE066)
            cash = min(999999, cash + 3 * (comboCount / 5))
            if comboCount == 5 { goalProgress(4, 1) }
            confettiBurst(160, 90, 26)
            play(.powerup)
        }
        if meter >= 100 { party() }
    }

    func party() {
        meter = 0
        statParties += 1
        cash = min(999999, cash + 10 + min(20, comboCount))
        if statParties % 2 == 0 { stars = min(9999, stars + 1) }
        showBanner("GIGGLE PARTY!", 0xFF8FD0)
        confettiBurst(160, 100, 70)
        var i: Int = 0
        while i < 6 {
            spark(Float(rng.range(30, 290)), 220, Float(rng.range(-6, 6)) / 10, -Float(rng.range(15, 30)) / 10, 100, 6, BuddyData.confettiColors[rng.int(BuddyData.confettiColors.count)], 8, -0.01)
            i += 1
        }
        if coinB.count < 5 {
            spawnCoin(false)
            spawnCoin(false)
        }
        expr = 1
        exprT = 120
        bubble = "YAY!"
        bubbleT = 100
        play(.win)
    }
}
