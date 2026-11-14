#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

// =====================================================================================================================
// LANTERN QUEST: CONTENT FORMAT (read this before adding a dungeon, region, NPC, quest, item or enemy)
// =====================================================================================================================
//
// Everything in the game lives behind the registry `LanternContent` (bottom of this file). The engine files
// (LanternQuest / LanternCore / LanternEnemies / LanternArt / LanternSave) never mention a specific room or dungeon.
//
// SCREENS AND TILES
//   A room is 10 x 8 tiles of 16 px. `LanternRoomDef.tiles` is 8 strings of exactly 10 characters. Legend:
//     .  ground            ,  ground decoration (flowers, pebbles)   p  path / sand strip       #  wall / cliff / brick
//     T  tree (cactus, pine, spire...)  b  bush (sword cuts it)       r  heavy rock (gloves lift it)   w  deep water
//     o  pit (falling costs half a heart, you reappear on the last safe tile)     M  magma (same as pit)
//     =  bridge (walkable)   B  cracked wall (bomb)   y  thorns (lantern flame burns them)
//     L  small-key door      K  big-key door          N  shutter (stays shut until its flags are set)
//     H  house wall  W  house window  R  roof  d  house door   D  cave / dungeon doorway   v  stairs
//     e  sign / notice board  C  chest  t  torch  S  floor switch  P  pot  F  fence  Q  statue  I  pillar
//     c  shop counter  m  bed  a  table  g  rug  h  shelf  E  eye switch (hit with arrow, boomerang or bomb)
//   Tiles that are solid: # T b r w B H W R L K N e C t P F Q y c m a h E I.  Everything else can be walked on.
//
// AN AREA (LanternArea) is a grid (gw x gh) of rooms. `num` is the number stored in save files and warps:
//   0 = overworld (8 x 8),  1 = indoors (houses, caves, fountains; each room is a separate 1-room interior),
//   100 + N = dungeon N.  Rooms that are neighbours in the grid are joined by scrolling: the 10 (or 8) edge tiles that
//   touch must be walkable on both sides or blocked on both sides (a door tile L K N B y r counts as walkable
//   for this check, so a locked door can sit on one side of an edge only).
//
// ENTITY STRINGS (LanternRoomDef.ents): one entity per string, tokens separated by single spaces. x y are tile coords
//   (x 0...9, y 0...7). `f` is a flag number local to the area (1...flagCount-1). Flags are persistent bits in the save;
//   the global bit is area.flagBase + f. Overworld flagBase 0 (flags 1...39 are reserved for story flags, see LanternFlag),
//   indoors 320, dungeon N = 512 + 128 * (N - 1) (so a dungeon owns flags 1...127).
//     en <enemyId> x y                       enemy; respawns each visit
//     npc <npcId> x y                        a villager (registry: LanternContent.npcs)
//     sign x y <textId>                      readable sign (put an 'e' tile there; texts: LanternContent.texts)
//     board x y                              quest board ('e' tile) listing side quests
//     warp x y <area> <gx> <gy> <tx> <ty>    stepping on tile x,y moves the hero to tile tx,ty of that area/room. The target tile
//                                            must be walkable, and the target room must hold a warp back to this room.
//     gate x y <N>                           overworld entrance of dungeon N ('D' tile at x,y, the only approach is tile x,y+1).
//                                            A guard blocks tile x,y+1 until dungeon N is registered AND you own enough sparks
//                                            (LanternDungeon.sparksNeeded). Unregistered dungeons show a friendly "the way opens
//                                            once more sparks are found" speech. When it opens the 'D' tile warps to the dungeon entry.
//     chest x y <reward> f [need]            chest ('C' tile). Optional `need`: flag that must be set for it to be there.
//     pick x y <reward> f                    visible pickup; f marks it as taken
//     hide x y <reward> f                    pickup revealed when the bush / pot / rock at x,y is destroyed
//     block x y [heavy]                      pushable block (heavy needs the power gloves)
//     switch x y f                           floor switch: sets f when a block or the hero stands on it (and keeps it)
//     torch x y f                            torch ('t' tile): lantern flame lights it and sets f
//     eye x y f                              eye switch ('E' tile): an arrow, boomerang or bomb sets f
//     lock|blk|bomb|burn|lift x y f          gate group: the connected tiles L / K / B / y / r around x,y vanish when f is set. L needs
//                                            a small key (consumed), K the dungeon's big key, B a bomb, y a lantern flame, r gloves.
//     shut f [f f]                           'N' tiles in this room stay closed until ALL listed flags are set
//     clear f                                sets f when every enemy of the room is defeated
//     mini x y <bossId> f                    mini-boss, f = defeated
//     boss x y <bossId> f                    boss: f = defeated, f+1 = heart container taken, f+2 = spark taken
//     wares x y <reward> <price> [f]         shop item for sale (f marks one-time items as sold)
//     fountain x y                           fairy fountain: refills hearts when you step next to it
//     dark                                   the room is dark (lantern gives a light circle; lit torches glow)
//     music <tuneId>                         tune override
//
// REWARDS (strings): gems:N  hp  bombs:N  arrows:N  key (small key)  bigkey  map (dungeon map)  piece (heart piece)
//                    heartc (heart container)  item:<itemId>  quest:<questId> (adds 1 to that quest's counter)
//
// ADDING DUNGEON 3 (one new file + one registry line):
//   1. Create LanternDungeon3.swift with `enum LanternDungeon3 { static func make() -> LanternDungeon { ... } }` returning a
//      LanternDungeon(num: 3, id: "d3", name: ..., sparkName: ..., area: LanternArea(num: 103, ... kind: 2 ...), entry...).
//      Its rooms use region ids that exist in LanternContent.regions (add a LanternRegion if you want a new palette), an exit
//      warp back to the overworld landing tile in front of the gate ("gate" entity already placed on the overworld), a boss
//      (LanternContent.bosses) and a unique item registered in LanternContent.items.
//   2. Add `LanternDungeon3.make()` to `LanternContent.dungeons` below. Done; the overworld gate opens by itself.
//   3. Run LanternValidator.validate() (it must return []) and Tools/lantern/validate.py.
//
// ADDING AN ITEM: append a LanternItem to LanternContent.items with a unique `bit` (0...63; 8...15 are reserved for hookshot,
// flippers, hammer, ...). Its `use` closure receives the game and may call the helper methods of LanternQuest (spawnProjectile etc).
// ADDING AN ENEMY: append a LanternEnemyDef (ai chosen from LanternAI; `.custom` runs the def's closure).
// ADDING A REGION: append a LanternRegion (16 colours, see LanternArt for slot meanings) and name it from rooms.
//
// NOTE FOR LUMINANCE: slot 0 (ground) of every region palette must be light (Y >= 192), slot 4 and 9 dark (Y < 128),
// so that Classic four-shade mode keeps sprites readable.
// =====================================================================================================================

enum LanternTile {
    static let ground: UInt8 = 0
    static let ground2: UInt8 = 1
    static let path: UInt8 = 2
    static let wall: UInt8 = 3
    static let tree: UInt8 = 4
    static let bush: UInt8 = 5
    static let rock: UInt8 = 6
    static let water: UInt8 = 7
    static let hole: UInt8 = 8
    static let bombWall: UInt8 = 9
    static let houseWall: UInt8 = 10
    static let roof: UInt8 = 11
    static let doorway: UInt8 = 12
    static let lock: UInt8 = 13
    static let bigDoor: UInt8 = 14
    static let shutter: UInt8 = 15
    static let sign: UInt8 = 16
    static let chest: UInt8 = 17
    static let chestOpen: UInt8 = 18
    static let torch: UInt8 = 19
    static let torchLit: UInt8 = 20
    static let switchUp: UInt8 = 21
    static let switchDown: UInt8 = 22
    static let pot: UInt8 = 23
    static let fence: UInt8 = 24
    static let statue: UInt8 = 25
    static let thorn: UInt8 = 26
    static let stairs: UInt8 = 27
    static let counter: UInt8 = 28
    static let bed: UInt8 = 29
    static let table: UInt8 = 30
    static let rug: UInt8 = 31
    static let shelf: UInt8 = 32
    static let eye: UInt8 = 33
    static let magma: UInt8 = 34
    static let bridge: UInt8 = 35
    static let pillar: UInt8 = 36
    static let window: UInt8 = 37
    static let houseDoor: UInt8 = 38
    static let eyeOpen: UInt8 = 39
    static let count = 40

    static let chars: [Character] = [".", ",", "p", "#", "T", "b", "r", "w", "o", "B", "H", "R", "D", "L", "K", "N", "e", "C",
                                     "?", "t", "?", "S", "?", "P", "F", "Q", "y", "v", "c", "m", "a", "g", "h", "E", "M", "=",
                                     "I", "W", "d", "?"]

    static func fromChar(_ ch: Character) -> UInt8? {
        var i = 0
        while i < chars.count {
            if chars[i] == ch && ch != "?" { return UInt8(i) }
            i += 1
        }
        return nil
    }

    static func isSolid(_ t: UInt8) -> Bool {
        switch t {
        case 0, 1, 2, 8, 12, 21, 22, 27, 31, 34, 35, 38: return false
        default: return true
        }
    }

    static func isHazard(_ t: UInt8) -> Bool { return t == hole || t == magma }

    /// Tiles that a gate-group entity can remove.
    static func isGated(_ t: UInt8) -> Bool {
        return t == lock || t == bigDoor || t == shutter || t == bombWall || t == thorn || t == rock
    }
}

struct LanternRoomDef {
    var gx: Int
    var gy: Int
    var region: String
    var tiles: [String]
    var ents: [String]

    init(_ gx: Int, _ gy: Int, _ region: String, _ tiles: [String], _ ents: [String]) {
        self.gx = gx
        self.gy = gy
        self.region = region
        self.tiles = tiles
        self.ents = ents
    }
}

struct LanternArea {
    var num: Int
    var id: String
    var name: String
    /// 0 outdoors, 1 interior (rooms are separate), 2 dungeon
    var kind: Int
    var gw: Int
    var gh: Int
    var rooms: [LanternRoomDef]

    func room(_ gx: Int, _ gy: Int) -> LanternRoomDef? {
        for r in rooms where r.gx == gx && r.gy == gy { return r }
        return nil
    }

    /// First global flag bit of this area.
    var flagBase: Int {
        if num == 0 { return 0 }
        if num < 100 { return 320 }
        return 512 + 128 * (num - 101)
    }
    var flagCount: Int {
        if num == 0 { return 320 }
        if num < 100 { return 192 }
        return 128
    }
    /// First bit of this area in the "visited rooms" bit array (overworld 0...63, dungeon N 64 + 40 * (N - 1)).
    var visitBase: Int {
        if num == 0 { return 0 }
        if num < 100 { return -1 }
        return 64 + 40 * (num - 101)
    }
    var dungeonNum: Int { return num >= 100 ? num - 100 : 0 }
}

struct LanternRegion {
    var id: String
    var name: String
    /// 16 colours (0xRRGGBB) for palette slots 0...15
    var colors: [UInt32]
    /// ground art: 0 grass 1 sand 2 snow 3 dirt 4 wood floor 5 dungeon floor 6 marsh 7 ash
    var ground: Int
    /// wall art: 0 rock 1 brick 2 wood panel
    var wall: Int
    /// tree art: 0 round 1 pine 2 cactus 3 spire
    var tree: Int
    var tune: String
}

struct LanternDungeon {
    var num: Int
    var id: String
    var name: String
    var sparkName: String
    var area: LanternArea
    var entryGx: Int
    var entryGy: Int
    var entryTx: Int
    var entryTy: Int
    var sparksNeeded: Int
    var bossId: String
    var rewardItem: String
}

struct LanternBossDef {
    var id: String
    var name: String
    var hp: Int
    var ai: LanternAI
    var w: Int
    var h: Int
    var tune: String
}

struct LanternNPC {
    var id: String
    var name: String
    var hair: Int = 20
    var cloth: Int = 23
    var lines: [String] = []
    var quest: String = ""
    var talk: ((LanternQuest) -> [String])? = nil
}

struct LanternQuestDef {
    var id: String
    /// 0...31, stable slot in the save file
    var num: Int
    var name: String
    var goal: Int
    /// 0 counter (pickups of quest:<id>), 1 kills of killId, 2 flag (global flag `goal` must be set; progress is 1 then)
    var kind: Int
    var killId: String
    var reward: String
    var offer: [String]
    var progress: [String]
    var done: [String]
    var after: [String]
    var hint: String
    /// where the quest marker points: area, gx, gy
    var areaNum: Int
    var gx: Int
    var gy: Int
    /// icon index for pickups: 0 chick 1 shell 2 mushroom 3 lure 4 scarf 5 note
    var icon: Int
}

struct LanternStep {
    var hint: String
    var areaNum: Int
    var gx: Int
    var gy: Int
    /// 0 global flag, 1 spark number, 2 owns item bit
    var condKind: Int
    var condArg: Int
}

enum LanternFlag {
    static let wokeUp = 1
    static let gotSword = 2
    static let metElder = 3
    static let gotLantern = 4
    static let enteredForest = 5
    static let enteredD1 = 6
    static let gotBombs = 7
    static let gotGloves = 8
    static let enteredD2 = 9
    static let burnedThorns = 10
    static let shield = 11
    static let boots = 12
    static let swordUp = 13
    static let tutorialDark = 14
    static let tutorialLow = 15
}

enum LanternContent {
    static var regions: [LanternRegion] = LanternRegions.all()
    static var areas: [LanternArea] = [LanternOverworld.make(), LanternInteriors.make()]
    static var dungeons: [LanternDungeon] = [LanternDungeon1.make(), LanternDungeon2.make()]
    static var npcs: [LanternNPC] = LanternVillage.npcs()
    static var quests: [LanternQuestDef] = LanternVillage.quests()
    static var texts: [String: [String]] = LanternVillage.texts()
    static var story: [LanternStep] = LanternVillage.story()
    static var items: [LanternItem] = LanternItems.all()
    static var enemies: [LanternEnemyDef] = LanternEnemies.defs()
    static var bosses: [LanternBossDef] = LanternEnemies.bosses()

    static func area(_ num: Int) -> LanternArea? {
        for a in areas where a.num == num { return a }
        for d in dungeons where d.area.num == num { return d.area }
        return nil
    }
    static func dungeon(_ n: Int) -> LanternDungeon? {
        for d in dungeons where d.num == n { return d }
        return nil
    }
    static func region(_ id: String) -> LanternRegion {
        for r in regions where r.id == id { return r }
        return regions[0]
    }
    static func hasRegion(_ id: String) -> Bool {
        for r in regions where r.id == id { return true }
        return false
    }
    static func npc(_ id: String) -> LanternNPC? {
        for n in npcs where n.id == id { return n }
        return nil
    }
    static func quest(_ id: String) -> LanternQuestDef? {
        for q in quests where q.id == id { return q }
        return nil
    }
    static func item(_ id: String) -> LanternItem? {
        for i in items where i.id == id { return i }
        return nil
    }
    static func item(bit: Int) -> LanternItem? {
        for i in items where i.bit == bit { return i }
        return nil
    }
    static func enemy(_ id: String) -> LanternEnemyDef? {
        for e in enemies where e.id == id { return e }
        return nil
    }
    static func boss(_ id: String) -> LanternBossDef? {
        for b in bosses where b.id == id { return b }
        return nil
    }
}

/// One parsed entity string.
struct LanternEnt {
    var kind: String
    var t: [String]

    init?(_ s: String) {
        var arr: [String] = []
        for p in s.split(separator: " ") { arr.append(String(p)) }
        if arr.isEmpty { return nil }
        self.t = arr
        self.kind = arr[0]
    }

    func s(_ i: Int) -> String {
        if i >= 0 && i < t.count { return t[i] }
        return ""
    }
    func i(_ n: Int) -> Int {
        if n >= 0 && n < t.count { return Int(t[n]) ?? 0 }
        return 0
    }
    var count: Int { return t.count }
}

/// Pure content checks (no printing). Returns a list of problems; an empty list means the registry is consistent.
enum LanternValidator {
    /// (minimum token count, index of the x token or -1)
    static func spec(_ kind: String) -> (Int, Int)? {
        switch kind {
        case "en", "npc": return (4, 2)
        case "sign": return (4, 1)
        case "board", "fountain", "block": return (3, 1)
        case "warp": return (8, 1)
        case "gate": return (4, 1)
        case "chest": return (5, 1)
        case "pick", "hide": return (5, 1)
        case "switch", "torch", "eye", "lock", "blk", "bomb", "burn", "lift": return (4, 1)
        case "mini", "boss": return (5, 1)
        case "wares": return (5, 1)
        case "shut", "clear", "music": return (2, -1)
        case "dark": return (1, -1)
        default: return nil
        }
    }

    static func validReward(_ r: String) -> Bool {
        let parts = r.split(separator: ":")
        if parts.isEmpty { return false }
        let head = String(parts[0])
        let arg: String = parts.count > 1 ? String(parts[1]) : ""
        switch head {
        case "gems", "bombs", "arrows", "heal", "spark": return Int(arg) != nil
        case "hp", "key", "bigkey", "map", "piece", "heartc": return true
        case "item": return LanternContent.item(arg) != nil
        case "quest": return LanternContent.quest(arg) != nil
        default: return false
        }
    }

    static func edgeClass(_ ch: Character) -> Int {
        guard let t = LanternTile.fromChar(ch) else { return -1 }
        if !LanternTile.isSolid(t) || LanternTile.isGated(t) { return 1 }
        return 0
    }

    static func tileAt(_ room: LanternRoomDef, _ x: Int, _ y: Int) -> Character {
        if y < 0 || y >= room.tiles.count { return "#" }
        let row = Array(room.tiles[y])
        if x < 0 || x >= row.count { return "#" }
        return row[x]
    }

    static func walkable(_ room: LanternRoomDef, _ x: Int, _ y: Int) -> Bool {
        guard let t = LanternTile.fromChar(tileAt(room, x, y)) else { return false }
        return !LanternTile.isSolid(t)
    }

    static func validate() -> [String] {
        var out: [String] = []
        var allAreas: [LanternArea] = LanternContent.areas
        for d in LanternContent.dungeons { allAreas.append(d.area) }

        var seenNums: [Int] = []
        for a in allAreas {
            if seenNums.contains(a.num) { out.append("duplicate area num \(a.num)") }
            seenNums.append(a.num)
        }
        var bits: [Int] = []
        for it in LanternContent.items {
            if it.bit < 0 || it.bit > 63 || bits.contains(it.bit) { out.append("bad item bit \(it.id)") }
            bits.append(it.bit)
        }
        var qn: [Int] = []
        for q in LanternContent.quests {
            if q.num < 0 || q.num > 31 || qn.contains(q.num) { out.append("bad quest num \(q.id)") }
            qn.append(q.num)
        }
        for d in LanternContent.dungeons {
            if d.area.num != 100 + d.num { out.append("dungeon \(d.id) area num must be 100 + num") }
            if LanternContent.boss(d.bossId) == nil { out.append("dungeon \(d.id) boss missing") }
            if LanternContent.item(d.rewardItem) == nil { out.append("dungeon \(d.id) reward item missing") }
            if d.area.gw * d.area.gh > 40 { out.append("dungeon \(d.id) grid too big") }
            if let r = d.area.room(d.entryGx, d.entryGy) {
                if !walkable(r, d.entryTx, d.entryTy) { out.append("dungeon \(d.id) entry tile blocked") }
            } else { out.append("dungeon \(d.id) entry room missing") }
        }

        for a in allAreas {
            for r in a.rooms {
                let tag = "area \(a.num) room \(r.gx),\(r.gy)"
                if r.gx < 0 || r.gy < 0 || r.gx >= a.gw || r.gy >= a.gh { out.append(tag + " outside grid") }
                if !LanternContent.hasRegion(r.region) { out.append(tag + " unknown region " + r.region) }
                if r.tiles.count != 8 { out.append(tag + " needs 8 rows"); continue }
                for row in r.tiles {
                    if row.count != 10 { out.append(tag + " row width") }
                    for ch in row where LanternTile.fromChar(ch) == nil { out.append(tag + " bad tile char") }
                }
                for line in r.ents {
                    guard let e = LanternEnt(line) else { out.append(tag + " empty entity"); continue }
                    guard let sp = spec(e.kind) else { out.append(tag + " unknown entity " + e.kind); continue }
                    if e.count < sp.0 { out.append(tag + " short entity " + line); continue }
                    if sp.1 >= 0 {
                        let ex = e.i(sp.1)
                        let ey = e.i(sp.1 + 1)
                        if ex < 0 || ex > 9 || ey < 0 || ey > 7 { out.append(tag + " entity position " + line) }
                    }
                    checkEntity(e, a, r, tag, &out)
                }
                if a.kind != 1 {
                    if let right = a.room(r.gx + 1, r.gy) { compareEdge(r, right, true, tag, &out) }
                    if let below = a.room(r.gx, r.gy + 1) { compareEdge(r, below, false, tag, &out) }
                }
            }
            checkReach(a, &out)
        }
        return out
    }

    static func flagOK(_ e: LanternEnt, _ idx: Int, _ a: LanternArea, _ tag: String, _ out: inout [String]) {
        let f = e.i(idx)
        if f < 1 || f >= a.flagCount { out.append(tag + " flag out of range in " + e.kind) }
    }

    static func checkEntity(_ e: LanternEnt, _ a: LanternArea, _ r: LanternRoomDef, _ tag: String, _ out: inout [String]) {
        switch e.kind {
        case "en":
            if LanternContent.enemy(e.s(1)) == nil { out.append(tag + " unknown enemy " + e.s(1)) }
        case "npc":
            if LanternContent.npc(e.s(1)) == nil { out.append(tag + " unknown npc " + e.s(1)) }
        case "sign":
            if LanternContent.texts[e.s(3)] == nil { out.append(tag + " unknown text " + e.s(3)) }
        case "chest":
            if !validReward(e.s(3)) { out.append(tag + " bad reward " + e.s(3)) }
            flagOK(e, 4, a, tag, &out)
        case "pick", "hide":
            if !validReward(e.s(3)) { out.append(tag + " bad reward " + e.s(3)) }
            flagOK(e, 4, a, tag, &out)
        case "wares":
            if !validReward(e.s(3)) { out.append(tag + " bad reward " + e.s(3)) }
        case "switch", "torch", "eye", "lock", "blk", "bomb", "burn", "lift":
            flagOK(e, 3, a, tag, &out)
        case "mini", "boss":
            if LanternContent.boss(e.s(3)) == nil { out.append(tag + " unknown boss " + e.s(3)) }
            flagOK(e, 4, a, tag, &out)
        case "warp":
            let ta = e.i(3)
            guard let target = LanternContent.area(ta) else { out.append(tag + " warp to missing area"); return }
            guard let tr = target.room(e.i(4), e.i(5)) else { out.append(tag + " warp to missing room"); return }
            if !walkable(tr, e.i(6), e.i(7)) { out.append(tag + " warp landing blocked") }
            var back = false
            for line in tr.ents {
                if let w = LanternEnt(line), w.kind == "warp", w.count >= 8 {
                    if w.i(3) == a.num && w.i(4) == r.gx && w.i(5) == r.gy { back = true }
                }
            }
            if !back { out.append(tag + " warp has no way back") }
        case "gate":
            if e.i(3) < 1 { out.append(tag + " gate number") }
        default:
            break
        }
    }

    /// Edge tiles that touch must agree on walkable / blocked.
    static func compareEdge(_ a: LanternRoomDef, _ b: LanternRoomDef, _ horizontal: Bool, _ tag: String, _ out: inout [String]) {
        let n = horizontal ? 8 : 10
        var i = 0
        while i < n {
            let ca = horizontal ? tileAt(a, 9, i) : tileAt(a, i, 7)
            let cb = horizontal ? tileAt(b, 0, i) : tileAt(b, i, 0)
            if edgeClass(ca) != edgeClass(cb) { out.append(tag + " edge mismatch at \(i)") }
            i += 1
        }
    }

    /// Every walkable tile must be reachable from some warp (gates count as passable).
    static func checkReach(_ a: LanternArea, _ out: inout [String]) {
        if a.kind == 1 {
            for r in a.rooms { reachRoomOnly(a, r, &out) }
            return
        }
        let w = a.gw * 10
        let h = a.gh * 8
        if w <= 0 || h <= 0 { return }
        var open = [Bool](repeating: false, count: w * h)
        var seen = [Bool](repeating: false, count: w * h)
        var stack: [Int] = []
        for r in a.rooms {
            for y in 0..<8 {
                for x in 0..<10 {
                    guard let t = LanternTile.fromChar(tileAt(r, x, y)) else { continue }
                    let ok = !LanternTile.isSolid(t) || LanternTile.isGated(t)
                    open[(r.gy * 8 + y) * w + r.gx * 10 + x] = ok
                }
            }
        }
        for r in a.rooms {
            for line in r.ents {
                if let e = LanternEnt(line), e.kind == "warp" || e.kind == "gate" {
                    let idx = (r.gy * 8 + e.i(2)) * w + r.gx * 10 + e.i(1)
                    if idx >= 0 && idx < w * h && !seen[idx] { seen[idx] = true; stack.append(idx) }
                }
            }
        }
        for d in LanternContent.dungeons where d.area.num == a.num {
            let idx = (d.entryGy * 8 + d.entryTy) * w + d.entryGx * 10 + d.entryTx
            if idx >= 0 && idx < w * h && !seen[idx] { seen[idx] = true; stack.append(idx) }
        }
        var guardCount = 0
        while let cur = stack.popLast() {
            guardCount += 1
            if guardCount > 200000 { break }
            let cx = cur % w
            let cy = cur / w
            let nbs: [(Int, Int)] = [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]
            for nb in nbs {
                if nb.0 < 0 || nb.1 < 0 || nb.0 >= w || nb.1 >= h { continue }
                let ni = nb.1 * w + nb.0
                if open[ni] && !seen[ni] { seen[ni] = true; stack.append(ni) }
            }
        }
        var bad = 0
        for r in a.rooms {
            for y in 0..<8 {
                for x in 0..<10 {
                    let idx = (r.gy * 8 + y) * w + r.gx * 10 + x
                    if open[idx] && !seen[idx] {
                        if let t = LanternTile.fromChar(tileAt(r, x, y)), LanternTile.isHazard(t) { continue }
                        bad += 1
                    }
                }
            }
        }
        if bad > 0 { out.append("area \(a.num) has \(bad) unreachable walkable tiles") }
    }

    static func reachRoomOnly(_ a: LanternArea, _ r: LanternRoomDef, _ out: inout [String]) {
        var open = [Bool](repeating: false, count: 80)
        var seen = [Bool](repeating: false, count: 80)
        var stack: [Int] = []
        for y in 0..<8 {
            for x in 0..<10 {
                guard let t = LanternTile.fromChar(tileAt(r, x, y)) else { continue }
                open[y * 10 + x] = !LanternTile.isSolid(t) || LanternTile.isGated(t)
            }
        }
        for line in r.ents {
            if let e = LanternEnt(line), e.kind == "warp" {
                let idx = e.i(2) * 10 + e.i(1)
                if idx >= 0 && idx < 80 && !seen[idx] { seen[idx] = true; stack.append(idx) }
            }
        }
        while let cur = stack.popLast() {
            let cx = cur % 10
            let cy = cur / 10
            let nbs: [(Int, Int)] = [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]
            for nb in nbs {
                if nb.0 < 0 || nb.1 < 0 || nb.0 >= 10 || nb.1 >= 8 { continue }
                let ni = nb.1 * 10 + nb.0
                if open[ni] && !seen[ni] { seen[ni] = true; stack.append(ni) }
            }
        }
        var bad = 0
        for i in 0..<80 where open[i] && !seen[i] { bad += 1 }
        if bad > 0 { out.append("interior \(r.gx),\(r.gy) has \(bad) unreachable tiles") }
    }
}
