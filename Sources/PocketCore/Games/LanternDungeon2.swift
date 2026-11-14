#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// Dungeon 2, SUNKEN SANDHOUSE (Sandy Dunes). Theme: dark rooms, torches and eye switches. Item: bow. Boss: Grand Scarab.
enum LanternDungeon2 {
    static func make() -> LanternDungeon {
        var rooms: [LanternRoomDef] = []
        rooms.append(LanternRoomDef(1, 0, "dun2", [
            "##########",
            "#P......P#",
            "#........#",
            "#...C....#",
            "#........#",
            "#........#",
            "#P......P#",
            "####..####"
        ], [
            "chest 4 3 map 13"
        ]))
        rooms.append(LanternRoomDef(2, 0, "dun2", [
            "##########",
            "#P......P#",
            "#........#",
            "#.........",
            "#...C.....",
            "#........#",
            "#P......P#",
            "####..####"
        ], [
            "chest 4 4 item:bow 15"
        ]))
        rooms.append(LanternRoomDef(3, 0, "dun2", [
            "##########",
            "#P......P#",
            "#........#",
            "........E#",
            ".........#",
            "#........#",
            "#...C....#",
            "##########"
        ], [
            "eye 8 3 16",
            "en wisp 4 5",
            "chest 4 6 bigkey 17 16"
        ]))
        rooms.append(LanternRoomDef(1, 1, "dun2", [
            "####LL####",
            "#..o..o..#",
            "#........#",
            "#........#",
            "#........#",
            "#..o..o..#",
            "#........#",
            "####..####"
        ], [
            "en wisp 2 3",
            "en spinwheel 7 3",
            "lock 4 0 6",
            "dark"
        ]))
        rooms.append(LanternRoomDef(2, 1, "dun2", [
            "####NN####",
            "#I......I#",
            "#........#",
            "#........#",
            "#........#",
            "#........#",
            "#I......I#",
            "####..####"
        ], [
            "mini 4 4 clunkknight 14",
            "shut 14"
        ]))
        rooms.append(LanternRoomDef(3, 1, "dun2", [
            "##########",
            "#I......v#",
            "#........#",
            "#........#",
            "#........#",
            "#........#",
            "#I......I#",
            "####..####"
        ], [
            "boss 4 3 scarab 20",
            "warp 8 1 102 2 3 4 6 oneway"
        ]))
        rooms.append(LanternRoomDef(0, 2, "dun2", [
            "##########",
            "#........#",
            "#........#",
            "#.........",
            "#..C......",
            "#........#",
            "#........#",
            "##########"
        ], [
            "en sandmole 4 2",
            "chest 3 4 key 12",
            "en sandmole 5 6",
            "dark"
        ]))
        rooms.append(LanternRoomDef(1, 2, "dun2", [
            "####NN####",
            "#t......t#",
            "#........#",
            "..........",
            "..........",
            "#........#",
            "#........#",
            "##########"
        ], [
            "torch 1 1 1",
            "torch 8 1 2",
            "en wisp 4 3",
            "en sandmole 2 5",
            "en crabby 7 5",
            "dark",
            "shut 1 2"
        ]))
        rooms.append(LanternRoomDef(2, 2, "dun2", [
            "####LL####",
            "#..P..P..#",
            "#........#",
            "..I....I..",
            "..........",
            "#........#",
            "#........#",
            "####..####"
        ], [
            "en spinwheel 4 5",
            "en crabby 6 5",
            "lock 4 0 5"
        ]))
        rooms.append(LanternRoomDef(3, 2, "dun2", [
            "####KK####",
            "#........#",
            "#.I....I.#",
            ".........#",
            ".........#",
            "#........#",
            "#...C....#",
            "##########"
        ], [
            "en spinwheel 4 3",
            "en crabby 6 3",
            "en clunker 2 5",
            "en sandmole 7 5",
            "chest 4 6 key 11 10",
            "blk 4 0 18",
            "clear 10"
        ]))
        rooms.append(LanternRoomDef(1, 3, "dun2", [
            "##########",
            "#P.P..P.P#",
            "#........#",
            "#.........",
            "#.........",
            "#........#",
            "#P.C....P#",
            "##########"
        ], [
            "en sandmole 4 3",
            "en crabby 2 5",
            "en crabby 7 5",
            "chest 3 6 gems:20 3"
        ]))
        rooms.append(LanternRoomDef(2, 3, "dun2", [
            "####..####",
            "#P......P#",
            "#........#",
            ".........#",
            ".........#",
            "#..I..I..#",
            "#........#",
            "####D#####"
        ], [
            "en crabby 3 3",
            "en sandmole 6 3",
            "warp 4 7 0 7 5 4 4"
        ]))
        let area = LanternArea(num: 102, id: "d2", name: "SUNKEN SANDHOUSE", kind: 2, gw: 4, gh: 4, rooms: rooms)
        return LanternDungeon(num: 2, id: "d2", name: "SUNKEN SANDHOUSE", sparkName: "SUN SPARK", area: area,
                              entryGx: 2, entryGy: 3, entryTx: 4, entryTy: 6, sparksNeeded: 0,
                              bossId: "scarab", rewardItem: "bow")
    }
}
