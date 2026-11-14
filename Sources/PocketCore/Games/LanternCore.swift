#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

enum LanternMode {
    case title, play, scroll, text, menu, map, fade, getItem
}

enum LanternPK {
    static let arrow = 0
    static let boomerang = 1
    static let bomb = 2
    static let blast = 3
    static let flame = 4
    static let rock = 5
    static let fire = 6
    static let spore = 7
    static let thrown = 8
    static let snow = 9
    static let petal = 10
    static let sand = 11
}

struct LanternHero {
    var x: Float = 70
    var y: Float = 60
    /// 0 down, 1 up, 2 left, 3 right
    var dir = 0
    var anim = 0
    var moving = false
    var swing = 0
    var swingId = 0
    var invuln = 0
    var kbx: Float = 0
    var kby: Float = 0
    var kbT = 0
    var run = 0
    var push = 0
    var pushDir = -1
    var safeX: Float = 70
    var safeY: Float = 60
    var pitCooldown = 0
}

struct LanternProj {
    var kind: Int
    var x: Float
    var y: Float
    var vx: Float
    var vy: Float
    var life: Int
    var hostile: Bool
    var dmg: Int
    var aux: Int = 0
}

struct LanternParticle {
    var x: Float
    var y: Float
    var vx: Float
    var vy: Float
    var life: Int
    var color: Int
    /// 0 dot, 1 sparkle star
    var kind: Int
}

final class LanternPickup {
    let reward: String
    var x: Float
    var y: Float
    let flag: Int
    var life = -1
    var age = 0
    var vy: Float = 0

    init(_ reward: String, _ x: Float, _ y: Float, _ flag: Int) {
        self.reward = reward
        self.x = x
        self.y = y
        self.flag = flag
    }
}

final class LanternBlock {
    var x: Float
    var y: Float
    var tx: Float
    var ty: Float
    var heavy: Bool
    var moving = false

    init(_ x: Float, _ y: Float, _ heavy: Bool) {
        self.x = x
        self.y = y
        self.tx = x
        self.ty = y
        self.heavy = heavy
    }
}

final class LanternNpcInst {
    var npc: LanternNPC
    var x: Int
    var y: Int
    var dir = 0

    init(_ npc: LanternNPC, _ x: Int, _ y: Int) {
        self.npc = npc
        self.x = x
        self.y = y
    }
}

struct LanternWare {
    var idx: Int
    var reward: String
    var price: Int
    var flag: Int
}

struct LanternChest {
    var idx: Int
    var reward: String
    var flag: Int
    var need: Int
    var shown: Bool
}

struct LanternGroup {
    var kind: String
    var cells: [Int]
    var flag: Int
}

struct LanternWarp {
    var x: Int
    var y: Int
    var area: Int
    var gx: Int
    var gy: Int
    var tx: Int
    var ty: Int
}

struct LanternHide {
    var idx: Int
    var reward: String
    var flag: Int
}

final class LanternRoom {
    var region: LanternRegion
    var areaNum = 0
    var gx = 0
    var gy = 0
    var flagBase = 0
    var dungeon = 0
    var tiles = [UInt8](repeating: 0, count: 80)
    var variant = [UInt8](repeating: 0, count: 80)
    var bg = Canvas(width: 160, height: 128)
    var enemies: [LanternEnemy] = []
    var pickups: [LanternPickup] = []
    var blocks: [LanternBlock] = []
    var npcs: [LanternNpcInst] = []
    var wares: [LanternWare] = []
    var chests: [LanternChest] = []
    var groups: [LanternGroup] = []
    var warps: [LanternWarp] = []
    var hides: [LanternHide] = []
    var signs: [Int: String] = [:]
    var boards: [Int] = []
    var switches: [Int: Int] = [:]
    var torches: [Int: Int] = [:]
    var eyes: [Int: Int] = [:]
    var fountains: [Int] = []
    var shut: [Int] = []
    var clearFlag = -1
    var dark = false
    var musicName = "meadow"
    var nbL = false
    var nbR = false
    var nbU = false
    var nbD = false
    var boss: LanternEnemy? = nil
    var bossAlive = false
    var bossRewardTimer = 0
    var bossRewardX = 5
    var bossRewardY = 3
    var bossHeartFlag = -1
    var bossSparkFlag = -1
    var bossDungeon = 0
    var hadEnemies = false
    var clearedFlagged = false

    init(_ region: LanternRegion) {
        self.region = region
    }

    func tile(_ tx: Int, _ ty: Int) -> UInt8 {
        if tx < 0 || ty < 0 || tx >= 10 || ty >= 8 { return LanternTile.wall }
        return tiles[ty * 10 + tx]
    }
}

struct LanternDialog {
    var speaker = ""
    var pages: [[String]] = []
    var page = 0
    var shown = 0

    var total: Int {
        if page >= pages.count { return 0 }
        var n = 0
        for l in pages[page] { n += l.count }
        return n
    }
}

// MARK: Items

struct LanternItem {
    var id: String
    /// 0...63, the slot in the save file
    var bit: Int
    var name: String
    var desc: String
    var icon: String
    var active: Bool
    var maxLevel: Int
    /// 0 none, 1 bombs, 2 arrows
    var ammo: Int
    var use: (LanternQuest) -> Bool

    init(id: String, bit: Int, name: String, desc: String, icon: String, active: Bool, maxLevel: Int, ammo: Int,
         use: @escaping (LanternQuest) -> Bool = { _ in false }) {
        self.id = id
        self.bit = bit
        self.name = name
        self.desc = desc
        self.icon = icon
        self.active = active
        self.maxLevel = maxLevel
        self.ammo = ammo
        self.use = use
    }
}

enum LanternItems {
    static func all() -> [LanternItem] {
        var l: [LanternItem] = []
        l.append(LanternItem(id: "sword", bit: 0, name: "SWORD", desc: "A swings it. Stronger with each upgrade.", icon: "sword", active: false, maxLevel: 3, ammo: 0))
        l.append(LanternItem(id: "shield", bit: 1, name: "SHIELD", desc: "Blocks shots when you face them.", icon: "shield", active: false, maxLevel: 1, ammo: 0))
        l.append(LanternItem(id: "boots", bit: 2, name: "DASH BOOTS", desc: "Keep walking and you dash.", icon: "boots", active: false, maxLevel: 1, ammo: 0))
        l.append(LanternItem(id: "bombs", bit: 3, name: "BOMBS", desc: "Boom! Opens cracked walls.", icon: "bombs", active: true, maxLevel: 2, ammo: 1,
                             use: { g in return g.useBomb() }))
        l.append(LanternItem(id: "boomerang", bit: 4, name: "BOOMERANG", desc: "Stuns foes, grabs gems, hits far switches.", icon: "boomerang", active: true, maxLevel: 1, ammo: 0,
                             use: { g in return g.useBoomerang() }))
        l.append(LanternItem(id: "bow", bit: 5, name: "BOW", desc: "Shoots arrows from afar.", icon: "bow", active: true, maxLevel: 1, ammo: 2,
                             use: { g in return g.useBow() }))
        l.append(LanternItem(id: "lantern", bit: 6, name: "LANTERN", desc: "Burns thorns, lights torches and dark rooms.", icon: "lantern", active: true, maxLevel: 1, ammo: 0,
                             use: { g in return g.useLantern() }))
        l.append(LanternItem(id: "gloves", bit: 7, name: "POWER GLOVES", desc: "Lift heavy rocks and push heavy blocks.", icon: "gloves", active: true, maxLevel: 1, ammo: 0,
                             use: { g in return g.useGloves() }))
        return l
    }
}

// MARK: Game logic shared by everything

extension LanternQuest {
    var heroCX: Float { return hero.x + 6 }
    var heroCY: Float { return hero.y + 8 }

    func heroHurtBox() -> Box { return Box(Int(hero.x) + 2, Int(hero.y) + 3, 8, 9) }

    func hasItem(_ id: String) -> Bool {
        guard let it = LanternContent.item(id) else { return false }
        return save.has(it.bit)
    }

    func itemLevel(_ id: String) -> Int {
        guard let it = LanternContent.item(id) else { return 0 }
        return save.itemLevel[clamp(it.bit, 0, 63)]
    }

    func maxBombs() -> Int { return 10 * max(1, itemLevel("bombs")) }
    func maxArrows() -> Int { return 20 }

    func swordDamage() -> Int { return 1 + max(1, itemLevel("sword")) }

    // MARK: Flags and quests

    func flagG(_ g: Int) -> Bool { return save.flag(g) }
    func flagL(_ f: Int) -> Bool { return save.flag(room.flagBase + f) }

    func questIndex(_ id: String) -> LanternQuestDef? { return LanternContent.quest(id) }

    func questComplete(_ q: LanternQuestDef) -> Bool {
        let n = clamp(q.num, 0, 31)
        if q.kind == 2 { return save.flag(q.goal) }
        return save.qProg[n] >= q.goal
    }

    func questKill(_ enemyId: String) {
        for q in LanternContent.quests where q.kind == 1 && q.killId == enemyId {
            let n = clamp(q.num, 0, 31)
            if save.qState[n] == 1 && save.qProg[n] < q.goal { save.qProg[n] += 1 }
        }
    }

    func questLines(_ id: String) -> [String] {
        guard let q = LanternContent.quest(id) else { return ["..."] }
        let n = clamp(q.num, 0, 31)
        let st = save.qState[n]
        if st == 0 {
            save.qState[n] = 1
            return q.offer
        }
        if st == 1 {
            if questComplete(q) {
                save.qState[n] = 2
                giveReward(q.reward, announce: true)
                return q.done
            }
            var lines = q.progress
            if q.kind != 2 {
                lines.append("(" + String(save.qProg[n]) + " OF " + String(q.goal) + ")")
            }
            return lines
        }
        return q.after
    }

    // MARK: Particles

    func addParticle(_ x: Float, _ y: Float, _ vx: Float, _ vy: Float, _ life: Int, _ color: Int, _ kind: Int) {
        if parts.count > 160 { return }
        parts.append(LanternParticle(x: x, y: y, vx: vx, vy: vy, life: life, color: color, kind: kind))
    }

    func puff(_ x: Float, _ y: Float, _ n: Int, _ color: Int) {
        var i = 0
        while i < n {
            let a: Float = Float(rng.int(628)) / 100
            let sp: Float = 0.3 + Float(rng.int(10)) / 10
            addParticle(x, y, cos(a) * sp, sin(a) * sp, 10 + rng.int(10), color, 0)
            i += 1
        }
    }

    func updateParticles() {
        var i = 0
        while i < parts.count {
            parts[i].x += parts[i].vx
            parts[i].y += parts[i].vy
            parts[i].vx *= 0.96
            parts[i].vy *= 0.96
            parts[i].life -= 1
            if parts[i].life <= 0 {
                parts.remove(at: i)
            } else {
                i += 1
            }
        }
    }

    func spawnProj(_ kind: Int, _ x: Float, _ y: Float, _ vx: Float, _ vy: Float, _ life: Int, _ hostile: Bool, _ dmg: Int) {
        if projs.count > 40 { return }
        projs.append(LanternProj(kind: kind, x: x, y: y, vx: vx, vy: vy, life: life, hostile: hostile, dmg: dmg))
    }

    func dropPickup(_ reward: String, _ cx: Float, _ cy: Float) {
        if room.pickups.count > 14 { return }
        let p = LanternPickup(reward, cx - 4, cy - 4, -1)
        p.life = 480
        p.vy = -1.2
        room.pickups.append(p)
    }

    // MARK: Rewards

    func rewardIcon(_ r: String) -> Sprite? {
        let parts = r.split(separator: ":")
        if parts.isEmpty { return nil }
        let head = String(parts[0])
        let arg: String = parts.count > 1 ? String(parts[1]) : ""
        switch head {
        case "gems": return LanternArt.gem
        case "heal", "hp", "heartc": return LanternArt.heartFull
        case "bombs": return LanternArt.itemIcons["bombs"]
        case "arrows": return LanternArt.itemIcons["bow"]
        case "key": return LanternArt.keySmall
        case "bigkey": return LanternArt.keyBig
        case "map": return LanternArt.mapIcon
        case "piece": return LanternArt.piece
        case "spark": return LanternArt.spark
        case "item":
            if let it = LanternContent.item(arg) { return LanternArt.itemIcons[it.icon] }
            return nil
        case "quest":
            if let q = LanternContent.quest(arg) { return LanternArt.questIcons[clamp(q.icon, 0, LanternArt.questIcons.count - 1)] }
            return nil
        default: return nil
        }
    }

    func rewardName(_ r: String) -> String {
        let parts = r.split(separator: ":")
        if parts.isEmpty { return "?" }
        let head = String(parts[0])
        let arg: String = parts.count > 1 ? String(parts[1]) : ""
        switch head {
        case "gems": return arg + " GEMS"
        case "bombs": return arg + " BOMBS"
        case "arrows": return arg + " ARROWS"
        case "key": return "SMALL KEY"
        case "bigkey": return "BIG KEY"
        case "map": return "DUNGEON MAP"
        case "piece": return "HEART PIECE"
        case "heartc": return "HEART CONTAINER"
        case "item":
            if let it = LanternContent.item(arg) { return it.name }
            return "ITEM"
        case "quest":
            if let q = LanternContent.quest(arg) { return q.name }
            return "THING"
        default: return "TREASURE"
        }
    }

    var dungeonIndex: Int {
        if room.areaNum >= 101 && room.areaNum <= 108 { return room.areaNum - 101 }
        return -1
    }

    /// Adds the reward to the save. `announce` shows the item-get scene (for chests, keys, hearts, items).
    func giveReward(_ r: String, announce: Bool) {
        let parts = r.split(separator: ":")
        if parts.isEmpty { return }
        let head = String(parts[0])
        let arg: String = parts.count > 1 ? String(parts[1]) : ""
        let n: Int = Int(arg) ?? 0
        var lines: [String] = []
        var big = announce
        switch head {
        case "gems":
            save.gems = min(999, save.gems + n)
            play(.coin)
            if n < 5 { big = false }
            lines = ["A shiny haul!"]
        case "heal":
            save.hp = min(save.maxHp, save.hp + max(1, n))
            play(.pickup)
            big = false
        case "hp":
            save.hp = save.maxHp
            play(.powerup)
            big = false
        case "bombs":
            save.bombs = min(maxBombs(), save.bombs + n)
            play(.pickup)
            lines = ["Press B with bombs equipped."]
        case "arrows":
            save.arrows = min(maxArrows(), save.arrows + n)
            play(.pickup)
            lines = ["Arrows for your bow."]
        case "key":
            let d = dungeonIndex
            if d >= 0 { save.keys[d] = min(9, save.keys[d] + 1) }
            play(.pickup)
            lines = ["It opens one locked door in this dungeon."]
        case "bigkey":
            let d = dungeonIndex
            if d >= 0 { save.bigKeys |= 1 << d }
            play(.powerup)
            lines = ["It opens the big door to the boss!"]
        case "map":
            let d = dungeonIndex
            if d >= 0 { save.maps |= 1 << d }
            play(.powerup)
            lines = ["Press START to see every room."]
        case "piece":
            save.pieces += 1
            play(.powerup)
            if save.pieces >= 4 {
                save.pieces = 0
                save.maxHp = min(40, save.maxHp + 2)
                save.hp = save.maxHp
                lines = ["Four pieces make a whole heart!", "You have a new heart container."]
            } else {
                lines = [String(save.pieces) + " OF 4 pieces. Collect four for a new heart."]
            }
        case "heartc":
            save.maxHp = min(40, save.maxHp + 2)
            save.hp = save.maxHp
            play(.powerup)
            lines = ["Your hearts grow stronger!"]
        case "spark":
            let k = clamp(n, 1, 8)
            save.sparks |= 1 << (k - 1)
            play(.win)
            lines = ["The lantern's light grows! Go back and tell the Elder."]
            if let d = LanternContent.dungeon(k) { lines.insert(d.sparkName + " restored!", at: 0) }
            shake = 10
        case "item":
            if let it = LanternContent.item(arg) {
                let b = clamp(it.bit, 0, 63)
                if save.itemLevel[b] < it.maxLevel { save.itemLevel[b] += 1 }
                if it.active && save.equipped < 0 { save.equipped = b }
                if it.ammo == 1 { save.bombs = max(save.bombs, 8) }
                if it.ammo == 2 { save.arrows = max(save.arrows, 15) }
                lines = [it.desc]
                if it.active { lines.append("Press SELECT to pick your B item.") }
                play(.powerup)
                big = true
                markItemFlags(it.id)
            }
        case "quest":
            if let q = LanternContent.quest(arg) {
                let qn = clamp(q.num, 0, 31)
                if save.qProg[qn] < 99 { save.qProg[qn] += 1 }
                play(.pickup)
                lines = [String(min(save.qProg[qn], q.goal)) + " OF " + String(q.goal)]
                big = true
            }
        default:
            break
        }
        if big {
            var title = rewardName(r)
            if head == "item", let it = LanternContent.item(arg), it.maxLevel > 1 {
                title = it.name + " LV" + String(itemLevel(arg))
            }
            showGet(rewardIcon(r), title, lines)
        }
    }

    func markItemFlags(_ id: String) {
        if id == "sword" { save.setFlag(LanternFlag.gotSword) }
        if id == "lantern" { save.setFlag(LanternFlag.gotLantern) }
        if id == "bombs" { save.setFlag(LanternFlag.gotBombs) }
        if id == "gloves" { save.setFlag(LanternFlag.gotGloves) }
        if id == "shield" { save.setFlag(LanternFlag.shield) }
        if id == "boots" { save.setFlag(LanternFlag.boots) }
    }

    func showGet(_ icon: Sprite?, _ title: String, _ lines: [String]) {
        getIcon = icon
        getTitle = title
        getLines = lines
        getTimer = 55
        mode = .getItem
        play(.confirm)
    }

    // MARK: Room building

    func setTile(_ r: LanternRoom, _ idx: Int, _ t: UInt8) {
        if idx < 0 || idx >= 80 { return }
        r.tiles[idx] = t
        renderTile(r, idx)
    }

    func renderRoom(_ r: LanternRoom) {
        for i in 0..<80 { renderTile(r, i) }
    }

    func overlayFor(_ t: UInt8, _ r: LanternRoom) -> Sprite? {
        switch t {
        case LanternTile.tree: return LanternArt.trees[clamp(r.region.tree, 0, 3)]
        case LanternTile.bush: return LanternArt.bush
        case LanternTile.rock: return LanternArt.rock
        case LanternTile.thorn: return LanternArt.thorn
        case LanternTile.hole: return LanternArt.hole
        case LanternTile.doorway: return LanternArt.doorway
        case LanternTile.stairs: return LanternArt.stairs
        case LanternTile.houseDoor: return LanternArt.houseDoor
        case LanternTile.lock: return LanternArt.lockDoor(false)
        case LanternTile.bigDoor: return LanternArt.lockDoor(true)
        case LanternTile.shutter: return LanternArt.shutter
        case LanternTile.sign: return LanternArt.sign
        case LanternTile.chest: return LanternArt.chestClosed
        case LanternTile.chestOpen: return LanternArt.chestOpened
        case LanternTile.torch, LanternTile.torchLit: return LanternArt.torchBase
        case LanternTile.switchUp: return LanternArt.switchUpS
        case LanternTile.switchDown: return LanternArt.switchDownS
        case LanternTile.pot: return LanternArt.pot
        case LanternTile.fence: return LanternArt.fence
        case LanternTile.statue: return LanternArt.statue
        case LanternTile.counter: return LanternArt.counter
        case LanternTile.bed: return LanternArt.bed
        case LanternTile.table: return LanternArt.table
        case LanternTile.rug: return LanternArt.rug
        case LanternTile.shelf: return LanternArt.shelf
        case LanternTile.eye: return LanternArt.eyeSprite(false)
        case LanternTile.eyeOpen: return LanternArt.eyeSprite(true)
        case LanternTile.bridge: return LanternArt.bridge
        case LanternTile.pillar: return LanternArt.pillar
        case LanternTile.bombWall: return LanternArt.crack
        default: return nil
        }
    }

    func renderTile(_ r: LanternRoom, _ idx: Int) {
        let tx = idx % 10
        let ty = idx / 10
        let t = r.tiles[idx]
        let px = tx * 16
        let py = ty * 16
        let gs = clamp(r.region.ground, 0, 7)
        let ws = clamp(r.region.wall, 0, 2)
        let v = Int(r.variant[idx])
        var base: Sprite = LanternArt.groundTable[gs][v % 5]
        switch t {
        case LanternTile.wall, LanternTile.bombWall, LanternTile.doorway:
            base = LanternArt.wallTiles[ws]
        case LanternTile.water, LanternTile.bridge:
            base = LanternArt.waterFrames[0]
        case LanternTile.magma:
            base = LanternArt.magmaFrames[0]
        case LanternTile.path:
            base = LanternArt.pathTiles[v % 3]
        case LanternTile.houseWall, LanternTile.houseDoor:
            base = LanternArt.houseWall
        case LanternTile.window:
            base = LanternArt.window
        case LanternTile.roof:
            base = LanternArt.roof
        default:
            break
        }
        r.bg.draw(base, px, py)
        if let o = overlayFor(t, r) { r.bg.draw(o, px, py) }
    }

    func floodGroup(_ r: LanternRoom, _ sx: Int, _ sy: Int, _ tile: UInt8) -> [Int] {
        var out: [Int] = []
        if sx < 0 || sy < 0 || sx > 9 || sy > 7 { return out }
        if r.tiles[sy * 10 + sx] != tile { return out }
        var seen = [Bool](repeating: false, count: 80)
        var stack: [Int] = [sy * 10 + sx]
        seen[sy * 10 + sx] = true
        while let cur = stack.popLast() {
            out.append(cur)
            let cx = cur % 10
            let cy = cur / 10
            let nbs: [(Int, Int)] = [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]
            for nb in nbs {
                if nb.0 < 0 || nb.1 < 0 || nb.0 > 9 || nb.1 > 7 { continue }
                let ni = nb.1 * 10 + nb.0
                if !seen[ni] && r.tiles[ni] == tile {
                    seen[ni] = true
                    stack.append(ni)
                }
            }
        }
        return out
    }

    func buildRoom(_ areaNum: Int, _ gx: Int, _ gy: Int) -> LanternRoom? {
        guard let area = LanternContent.area(areaNum) else { return nil }
        guard let def = area.room(gx, gy) else { return nil }
        let r = LanternRoom(LanternContent.region(def.region))
        r.areaNum = areaNum
        r.gx = gx
        r.gy = gy
        r.flagBase = area.flagBase
        r.dungeon = area.dungeonNum
        r.musicName = r.region.tune
        if area.kind != 1 {
            r.nbL = area.room(gx - 1, gy) != nil
            r.nbR = area.room(gx + 1, gy) != nil
            r.nbU = area.room(gx, gy - 1) != nil
            r.nbD = area.room(gx, gy + 1) != nil
        }
        for y in 0..<8 {
            var row: [Character] = []
            if y < def.tiles.count { row = Array(def.tiles[y]) }
            for x in 0..<10 {
                var t: UInt8 = LanternTile.wall
                if x < row.count, let tt = LanternTile.fromChar(row[x]) { t = tt }
                let idx = y * 10 + x
                r.tiles[idx] = t
                if t == LanternTile.ground2 {
                    r.variant[idx] = UInt8(3 + (x + y) % 2)
                } else {
                    r.variant[idx] = UInt8((x * 7 + y * 13 + gx * 3) % 3)
                }
            }
        }
        var ents: [LanternEnt] = []
        for line in def.ents {
            if let e = LanternEnt(line) { ents.append(e) }
        }
        // pass 1: flags that change the tile layer or the spawn rules
        for e in ents {
            switch e.kind {
            case "dark": r.dark = true
            case "music": r.musicName = e.s(1)
            case "clear": r.clearFlag = r.flagBase + e.i(1)
            case "shut":
                var k = 1
                while k < e.count { r.shut.append(r.flagBase + e.i(k)); k += 1 }
            default: break
            }
        }
        if !r.shut.isEmpty {
            var all = true
            for g in r.shut where !save.flag(g) { all = false }
            if all {
                for i in 0..<80 where r.tiles[i] == LanternTile.shutter { r.tiles[i] = LanternTile.ground }
            }
        }
        let clearedAlready: Bool = r.clearFlag >= 0 && save.flag(r.clearFlag)
        for e in ents {
            let x = e.i(1)
            let y = e.i(2)
            let idx = clamp(y, 0, 7) * 10 + clamp(x, 0, 9)
            switch e.kind {
            case "en":
                if clearedAlready { break }
                if let d = LanternContent.enemy(e.s(1)) {
                    let en = makeEnemy(d, e.i(2), e.i(3))
                    r.enemies.append(en)
                    r.hadEnemies = true
                }
            case "npc":
                if let n = LanternContent.npc(e.s(1)) { r.npcs.append(LanternNpcInst(n, e.i(2) * 16 + 2, e.i(3) * 16 + 4)) }
            case "sign":
                r.signs[clamp(e.i(2), 0, 7) * 10 + clamp(e.i(1), 0, 9)] = e.s(3)
            case "board":
                r.boards.append(idx)
            case "warp":
                r.warps.append(LanternWarp(x: x, y: y, area: e.i(3), gx: e.i(4), gy: e.i(5), tx: e.i(6), ty: e.i(7)))
            case "gate":
                setupGate(r, e)
            case "chest":
                let g = r.flagBase + e.i(4)
                let need: Int = e.count > 5 ? r.flagBase + e.i(5) : -1
                var shown = true
                if need >= 0 && !save.flag(need) { shown = false }
                r.chests.append(LanternChest(idx: clamp(e.i(2), 0, 7) * 10 + clamp(e.i(1), 0, 9), reward: e.s(3), flag: g, need: need, shown: shown))
                let ci = clamp(e.i(2), 0, 7) * 10 + clamp(e.i(1), 0, 9)
                if !shown { r.tiles[ci] = LanternTile.ground }
                else if save.flag(g) { r.tiles[ci] = LanternTile.chestOpen }
                else { r.tiles[ci] = LanternTile.chest }
            case "pick":
                let g = r.flagBase + e.i(4)
                if !save.flag(g) { r.pickups.append(LanternPickup(e.s(3), Float(x * 16 + 4), Float(y * 16 + 4), g)) }
            case "hide":
                let g = r.flagBase + e.i(4)
                if !save.flag(g) { r.hides.append(LanternHide(idx: idx, reward: e.s(3), flag: g)) }
            case "block":
                r.blocks.append(LanternBlock(Float(x * 16), Float(y * 16), e.s(3) == "heavy"))
            case "switch":
                let g = r.flagBase + e.i(3)
                r.switches[idx] = g
                r.tiles[idx] = save.flag(g) ? LanternTile.switchDown : LanternTile.switchUp
            case "torch":
                let g = r.flagBase + e.i(3)
                r.torches[idx] = g
                r.tiles[idx] = save.flag(g) ? LanternTile.torchLit : LanternTile.torch
            case "eye":
                let g = r.flagBase + e.i(3)
                r.eyes[idx] = g
                r.tiles[idx] = save.flag(g) ? LanternTile.eyeOpen : LanternTile.eye
            case "lock", "blk", "bomb", "burn", "lift":
                var tile: UInt8 = LanternTile.lock
                if e.kind == "blk" { tile = LanternTile.bigDoor }
                if e.kind == "bomb" { tile = LanternTile.bombWall }
                if e.kind == "burn" { tile = LanternTile.thorn }
                if e.kind == "lift" { tile = LanternTile.rock }
                let cells = floodGroup(r, x, y, tile)
                let g = r.flagBase + e.i(3)
                if save.flag(g) {
                    for c in cells { r.tiles[c] = LanternTile.ground }
                } else {
                    r.groups.append(LanternGroup(kind: e.kind, cells: cells, flag: g))
                }
            case "mini", "boss":
                let g = r.flagBase + e.i(4)
                if e.kind == "boss" {
                    if save.flag(g) {
                        r.bossRewardTimer = 2
                        r.bossRewardX = x
                        r.bossRewardY = y
                        r.bossHeartFlag = g + 1
                        r.bossSparkFlag = g + 2
                        r.bossDungeon = area.dungeonNum
                    } else if let b = LanternContent.boss(e.s(3)) {
                        let en = makeBossEnemy(b, x, y)
                        en.isBoss = true
                        en.flagGlobal = g
                        en.heartFlag = g + 1
                        en.sparkFlag = g + 2
                        en.dungeon = area.dungeonNum
                        r.enemies.append(en)
                        r.boss = en
                        r.bossAlive = true
                        r.hadEnemies = true
                    }
                } else if !save.flag(g) {
                    if let b = LanternContent.boss(e.s(3)) {
                        let en = makeBossEnemy(b, x, y)
                        en.isMini = true
                        en.flagGlobal = g
                        r.enemies.append(en)
                        r.boss = en
                        r.hadEnemies = true
                    }
                }
            case "wares":
                let g: Int = e.count > 5 ? r.flagBase + e.i(5) : -1
                if g < 0 || !save.flag(g) { r.wares.append(LanternWare(idx: idx, reward: e.s(3), price: e.i(4), flag: g)) }
            case "fountain":
                r.fountains.append(idx)
            default:
                break
            }
        }
        renderRoom(r)
        return r
    }

    func setupGate(_ r: LanternRoom, _ e: LanternEnt) {
        let x = e.i(1)
        let y = e.i(2)
        let n = e.i(3)
        let need: Int = max(0, n - 1)
        if let d = LanternContent.dungeon(n) {
            if save.sparkCount() >= d.sparksNeeded {
                r.warps.append(LanternWarp(x: x, y: y, area: d.area.num, gx: d.entryGx, gy: d.entryGy, tx: d.entryTx, ty: d.entryTy))
                return
            }
            var g = LanternNPC(id: "guard", name: "GATE GUARD")
            g.hair = LanternC.grayD
            g.cloth = LanternC.grayL
            g.lines = ["Halt! Friendly gate guard here. This door opens when you hold " + String(d.sparksNeeded) + " sparks. You have " + String(save.sparkCount()) + ". Keep going!"]
            r.npcs.append(LanternNpcInst(g, x * 16 + 2, (y + 1) * 16 + 4))
        } else {
            var g = LanternNPC(id: "guard", name: "GATE GUARD")
            g.hair = LanternC.grayD
            g.cloth = LanternC.grayL
            g.lines = ["Hi there! This way opens once more sparks are found. I need " + String(need) + " sparks to let you pass. Snacks while you wait? No? Okay!"]
            r.npcs.append(LanternNpcInst(g, x * 16 + 2, (y + 1) * 16 + 4))
        }
    }
}
