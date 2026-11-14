#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// LANTERN QUEST: an original top-down adventure. See LanternWorld.swift for the content format and how to add dungeons.
final class LanternQuest: Game {
    var mode: LanternMode = .title
    var frame = 0
    var rng = Rng()
    var save = LanternSave()
    var hasSave = false
    var hero = LanternHero()
    var room: LanternRoom
    var nextRoom: LanternRoom
    var projs: [LanternProj] = []
    var parts: [LanternParticle] = []
    var dialog = LanternDialog()
    var dialogAfter: (() -> Void)? = nil
    var scrollDX = 0
    var scrollDY = 0
    var scrollT = 0
    var scrollFromX: Float = 0
    var scrollFromY: Float = 0
    var scrollToX: Float = 0
    var scrollToY: Float = 0
    var fadeT = 0
    var fadeTarget: [Int] = []
    var fadeIsDoor = true
    var menuCursor = 0
    var mapTab = 0
    var titleCursor = 0
    var touch = TouchGesture()
    var aimX = -1
    var aimY = -1
    var wickX: Float = 70
    var wickY: Float = 50
    var wickBob = 0
    var getIcon: Sprite? = nil
    var getTitle = ""
    var getLines: [String] = []
    var getTimer = 0
    var getAfterLines: [String] = []
    var getAfterSpeaker = ""
    var curTune = ""
    var shake = 0
    var palCache: [String: [UInt16]] = [:]
    var msg = ""
    var msgTimer = 0
    var pendingBuy = -1
    var pendingBuyTimer = 0

    override init() {
        let reg = LanternContent.regions[0]
        room = LanternRoom(reg)
        nextRoom = LanternRoom(reg)
        super.init()
    }

    override var wantsPointer: Bool { return true }

    override var score: Int {
        return save.gems + save.sparkCount() * 1000 + save.maxHp * 10
    }

    override var palette: [UInt16] {
        var region: LanternRegion = room.region
        if mode == .title { region = LanternContent.region("meadow") }
        if mode == .scroll && scrollT > 14 { region = nextRoom.region }
        if mode == .map || mode == .menu { region = room.region }
        if let p = palCache[region.id] { return p }
        let p = LanternArt.palette(region)
        palCache[region.id] = p
        return p
    }

    override func start() {
        setTune("title")
    }

    override func exportSave() -> [UInt8] {
        return saveBytes()
    }

    override func importSave(_ bytes: [UInt8]) {
        loadBytes(bytes)
    }

    func setTune(_ name: String) {
        curTune = name
        playMusic(LanternMusic.tune(name))
    }

    override func update(_ input: InputState) {
        frame += 1
        touch.update(input.pointer)
        var tapped = false
        var tx = 0
        var ty = 0
        if touch.tapped {
            tapped = true
            tx = touch.x
            ty = touch.y
        }
        switch mode {
        case .title: updateTitle(input, tapped, tx, ty)
        case .play: updatePlay(input, tapped, tx, ty)
        case .scroll: updateScroll()
        case .text: updateText(input, tapped)
        case .menu: updateMenu(input, tapped, tx, ty)
        case .map: updateMap(input, tapped, tx, ty)
        case .fade: updateFade()
        case .getItem: updateGet(input, tapped)
        }
    }

    override func draw(_ c: Canvas) {
        c.cameraX = 0
        c.cameraY = 0
        if mode == .title {
            drawTitle(c)
            return
        }
        c.clear(LanternC.hud)
        drawWorld(c)
        c.cameraX = 0
        c.cameraY = 0
        if mode != .map { drawHUD(c) }
        switch mode {
        case .text: drawDialog(c)
        case .menu: drawMenu(c)
        case .map: drawMap(c)
        case .fade: drawFade(c)
        case .getItem: drawGet(c)
        case .play:
            if msgTimer > 0 { drawMsg(c) }
        default: break
        }
    }
}
