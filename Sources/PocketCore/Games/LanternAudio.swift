#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// Original tunes for Lantern Quest, looked up by name (LanternRegion.tune, `music` entities, boss tunes).
enum LanternMusic {
    static let title = Tune(bpm: 100, wave: .pulse25, volume: 0.15, "G4:1 C5:1 E5:2 D5:1 C5:1 G4:2 A4:1 D5:1 F5:2 E5:1 D5:1 C5:2 G4:1 C5:1 E5:1 G5:1 F5:2 E5:2 D5:1 B4:1 C5:3 R:1")
    static let meadow = Tune(bpm: 132, wave: .pulse25, volume: 0.14, "C5:0.5 E5:0.5 G5:1 E5:0.5 C5:0.5 D5:1 R:0.5 D5:0.5 F5:0.5 A5:1 G5:0.5 E5:0.5 C5:1 R:0.5 E5:0.5 G5:0.5 C6:1 B5:0.5 G5:0.5 A5:1 G5:0.5 F5:0.5 E5:0.5 D5:0.5 C5:2 R:1")
    static let forest = Tune(bpm: 90, wave: .pulse50, volume: 0.13, "A4:1 C5:0.5 E5:0.5 D5:1 C5:0.5 B4:0.5 A4:1 R:0.5 G4:0.5 A4:1 C5:1 B4:0.5 A4:0.5 G#4:1 E4:1 A4:1 C5:0.5 E5:0.5 A5:1 G5:0.5 E5:0.5 D5:1 C5:1 B4:0.5 C5:0.5 A4:2 R:1")
    static let dunes = Tune(bpm: 108, wave: .pulse50, volume: 0.13, "D4:1 E4:0.5 F4:0.5 G#4:1.5 F4:0.5 E4:1 D4:1 R:0.5 A4:1 G#4:0.5 F4:0.5 E4:1.5 D4:0.5 C#4:2 R:1 D4:1 F4:0.5 A4:0.5 Bb4:1.5 A4:0.5 G#4:1 F4:1 E4:1 D4:3 R:1")
    static let lake = Tune(bpm: 84, wave: .triangle, volume: 0.22, "E5:1 G5:1 B5:2 A5:1 G5:1 E5:2 D5:1 F#5:1 A5:2 G5:1 F#5:1 D5:2 E5:1 G5:1 B5:1 D6:1 C6:2 B5:2 A5:1 G5:1 E5:3 R:1")
    static let hills = Tune(bpm: 120, wave: .pulse50, volume: 0.13, "G4:0.5 G4:0.5 D5:1 C5:0.5 B4:0.5 A4:1 G4:1 R:0.5 E4:0.5 G4:0.5 B4:1 A4:0.5 G4:0.5 F#4:1 D4:1 R:0.5 G4:0.5 B4:0.5 D5:1 E5:0.5 D5:0.5 C5:1 B4:1 A4:0.5 B4:0.5 G4:2 R:1")
    static let marsh = Tune(bpm: 70, wave: .triangle, volume: 0.22, "D4:1.5 F4:0.5 A4:1 G#4:1 A4:1.5 F4:0.5 D4:2 C4:1 E4:1 G4:1 F#4:1 G4:1.5 E4:0.5 C4:2 R:1 D4:1 A4:1 D5:2 C#5:1 A4:1 F4:2 E4:1 D4:3 R:1")
    static let frost = Tune(bpm: 100, wave: .pulse12, volume: 0.12, "E6:0.5 B5:0.5 G5:0.5 B5:0.5 E6:0.5 B5:0.5 G5:0.5 B5:0.5 D6:0.5 A5:0.5 F#5:0.5 A5:0.5 D6:0.5 A5:0.5 F#5:0.5 A5:0.5 C6:0.5 G5:0.5 E5:0.5 G5:0.5 C6:0.5 G5:0.5 E5:0.5 G5:0.5 B5:1 R:0.5 B5:0.5 E6:2 R:1")
    static let crater = Tune(bpm: 150, wave: .pulse25, volume: 0.13, "A3:0.5 A3:0.5 E4:0.5 A3:0.5 G4:0.5 A3:0.5 E4:0.5 A3:0.5 F3:0.5 F3:0.5 C4:0.5 F3:0.5 E4:0.5 F3:0.5 C4:0.5 F3:0.5 G3:0.5 G3:0.5 D4:0.5 G3:0.5 F4:0.5 G3:0.5 D4:0.5 G3:0.5 E3:0.5 B3:0.5 E4:0.5 B3:0.5 G#4:1 R:1")
    static let indoor = Tune(bpm: 96, wave: .triangle, volume: 0.2, "C4:1 E4:1 G4:1 E4:1 F4:1 A4:1 G4:2 D4:1 F4:1 A4:1 F4:1 E4:1 G4:1 C5:2")
    static let cave = Tune(bpm: 80, wave: .triangle, volume: 0.2, "A3:2 R:1 E4:1 A3:2 R:1 C4:1 G3:2 R:1 D4:1 G3:2 R:1 B3:1")
    static let fairy = Tune(bpm: 110, wave: .triangle, volume: 0.22, "C5:0.5 E5:0.5 G5:0.5 C6:0.5 G5:0.5 E5:0.5 C5:0.5 R:0.5 D5:0.5 F5:0.5 A5:0.5 D6:0.5 A5:0.5 F5:0.5 D5:0.5 R:0.5")
    static let dungeon1 = Tune(bpm: 108, wave: .pulse25, volume: 0.13, "E4:0.5 G4:0.5 B4:1 A4:0.5 G4:0.5 E4:1 R:0.5 D4:0.5 F#4:0.5 A4:1 G4:0.5 F#4:0.5 D4:1 R:0.5 E4:0.5 G4:0.5 B4:0.5 E5:0.5 D5:1 B4:1 A4:0.5 G4:0.5 F#4:0.5 G4:0.5 E4:2 R:1")
    static let dungeon2 = Tune(bpm: 118, wave: .pulse50, volume: 0.13, "D4:0.5 D4:0.5 F4:0.5 A4:0.5 G#4:1 A4:0.5 F4:0.5 D4:1 R:0.5 C4:0.5 C4:0.5 E4:0.5 G4:0.5 F#4:1 G4:0.5 E4:0.5 C4:1 R:0.5 D4:0.5 F4:0.5 A4:0.5 D5:0.5 C5:1 A4:1 G4:0.5 F4:0.5 E4:0.5 F4:0.5 D4:2 R:1")
    static let boss = Tune(bpm: 160, wave: .pulse25, volume: 0.14, "E4:0.5 E4:0.5 B4:0.5 E4:0.5 C5:0.5 E4:0.5 B4:0.5 E4:0.5 D4:0.5 D4:0.5 A4:0.5 D4:0.5 B4:0.5 D4:0.5 A4:0.5 D4:0.5 C4:0.5 C4:0.5 G4:0.5 C4:0.5 A4:0.5 C4:0.5 G4:0.5 C4:0.5 B3:0.5 B3:0.5 F#4:0.5 B3:0.5 B4:1 R:1")

    static func tune(_ name: String) -> Tune {
        switch name {
        case "title": return title
        case "meadow": return meadow
        case "forest": return forest
        case "dunes": return dunes
        case "lake": return lake
        case "hills": return hills
        case "marsh": return marsh
        case "frost": return frost
        case "crater": return crater
        case "indoor": return indoor
        case "cave": return cave
        case "fairy": return fairy
        case "dungeon1": return dungeon1
        case "dungeon2": return dungeon2
        case "boss": return boss
        default: return meadow
        }
    }
}

enum LanternRegions {
    static func make(_ id: String, _ name: String, _ ground: Int, _ wall: Int, _ tree: Int, _ tune: String, _ c: [UInt32]) -> LanternRegion {
        return LanternRegion(id: id, name: name, colors: c, ground: ground, wall: wall, tree: tree, tune: tune)
    }

    /// Slots: 0 ground, 1 ground detail, 2 path, 3 path detail, 4 foliage dark, 5 foliage light, 6 wood, 7 stone light,
    /// 8 stone dark, 9 water, 10 water light, 11 accent, 12 wall dark, 13 wall light, 14 roof, 15 floor line.
    static func all() -> [LanternRegion] {
        var r: [LanternRegion] = []
        r.append(make("meadow", "MEADOW", 0, 0, 0, "meadow", [
            0xC8F0A0, 0xA8D878, 0xF0E0A8, 0xD8C488, 0x207838, 0x48A848, 0x8A5A30, 0xB8B8C8,
            0x707890, 0x3C78D8, 0x8CC0F8, 0xF06090, 0x585878, 0x9090B0, 0xD04838, 0xB89868]))
        r.append(make("forest", "WHISPERING FOREST", 0, 0, 0, "forest", [
            0xB8E090, 0x98C870, 0xE0D098, 0xC0A870, 0x105830, 0x307840, 0x704828, 0xA8B0A8,
            0x586858, 0x306890, 0x78B0C8, 0xF8E060, 0x405040, 0x889088, 0x806030, 0xA09060]))
        r.append(make("dunes", "SANDY DUNES", 1, 0, 2, "dunes", [
            0xF8E8B0, 0xE8D088, 0xF8F0D0, 0xE0C890, 0x508030, 0x78B040, 0x9A6A38, 0xD0B890,
            0x8A6840, 0x2890B8, 0x90D8E8, 0xE85848, 0x6A4A30, 0xB09068, 0xC86030, 0xD8C088]))
        r.append(make("lake", "MIRROR LAKE", 0, 0, 0, "lake", [
            0xC0F0E0, 0x98D8C0, 0xF0F0D8, 0xD0D0B0, 0x207858, 0x40A880, 0x7A5A40, 0xB0C0D0,
            0x607890, 0x2858C8, 0x78B0F0, 0xF8A0C8, 0x405878, 0x8098B8, 0x4870C0, 0xA8C0C8]))
        r.append(make("hills", "STONE HILLS", 3, 0, 0, "hills", [
            0xD8E0A8, 0xB8C888, 0xE8D8B0, 0xC8B890, 0x386830, 0x589848, 0x805830, 0xC0B8A8,
            0x786858, 0x3878C0, 0x90C0E8, 0xE8A040, 0x685848, 0xA89888, 0xB05838, 0xB0A080]))
        r.append(make("marsh", "MISTY MARSH", 6, 0, 3, "marsh", [
            0xC8D8A0, 0xA0B878, 0xD8C898, 0xB8A878, 0x305038, 0x70A068, 0x685030, 0xA8B098,
            0x586050, 0x406860, 0x88B8A0, 0xC860E0, 0x405040, 0x808870, 0x7A6040, 0x98A070]))
        r.append(make("frost", "FROST PEAKS", 2, 0, 1, "frost", [
            0xF0F8FF, 0xD0E4F4, 0xE0E8F0, 0xB8C8D8, 0x285868, 0x4888A0, 0x806850, 0xC0D0E0,
            0x6880A0, 0x3868B8, 0xA8D8F8, 0xF06080, 0x506888, 0x98B0D0, 0x5880B0, 0xC8D8E8]))
        r.append(make("crater", "EMBER CRATER", 7, 0, 3, "crater", [
            0xE0C8B8, 0xC8A898, 0xF0D8B0, 0xD0B088, 0x502828, 0x904838, 0x6A4030, 0xB09890,
            0x604840, 0x4868C0, 0x88A8E0, 0xF86820, 0x483030, 0x886058, 0xA03828, 0xB89880]))
        r.append(make("indoor", "INDOORS", 4, 2, 0, "indoor", [
            0xF0D8A8, 0xD8B880, 0xE8C890, 0xC8A068, 0x207838, 0x48A848, 0x8A5A30, 0xB8B0A8,
            0x706860, 0x3C78D8, 0x8CC0F8, 0xE85070, 0x6A4A38, 0x9A7A58, 0xC04838, 0xC8A870]))
        r.append(make("cave", "CAVE", 3, 0, 0, "cave", [
            0xD0C8D8, 0xB8B0C8, 0xE0D8E8, 0xC0B8D0, 0x386830, 0x589848, 0x805830, 0xB0A8C0,
            0x686078, 0x3878C0, 0x90C0E8, 0xF8D030, 0x484058, 0x807898, 0xB05838, 0xB0A8C0]))
        r.append(make("dun1", "HOLLOW OAK", 5, 1, 0, "dungeon1", [
            0xD8E8B8, 0xB8D090, 0xE0E8C0, 0xC0D0A0, 0x285830, 0x508040, 0x785030, 0xA8B098,
            0x586048, 0x306890, 0x78B0C8, 0xF8E060, 0x3C5030, 0x6C8858, 0x806030, 0xB0C890]))
        r.append(make("dun2", "SUNKEN SANDHOUSE", 5, 1, 2, "dungeon2", [
            0xF0E0B8, 0xD8C490, 0xF8F0D0, 0xE0C890, 0x508030, 0x78B040, 0x9A6A38, 0xD0B890,
            0x8A6840, 0x2890B8, 0x90D8E8, 0xE85848, 0x6A4830, 0xA88058, 0xC86030, 0xD8C090]))
        return r
    }
}
