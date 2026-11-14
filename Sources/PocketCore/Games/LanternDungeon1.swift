#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// Dungeon 1, HOLLOW OAK (Whispering Forest). Theme: push blocks onto switches. Item: boomerang. Boss: Queen Bramble.
enum LanternDungeon1 {
    static func make() -> LanternDungeon {
        var rooms: [LanternRoomDef] = []
        rooms.append(LanternRoomDef(0, 0, "dun1", [
            "##########",
            "#I......I#",
            "#........#",
            "#...C....#",
            "#........#",
            "#........#",
            "#I......I#",
            "####..####"
        ], [
            "chest 4 3 map 5"
        ]))
        rooms.append(LanternRoomDef(1, 0, "dun1", [
            "##########",
            "#I......v#",
            "#........#",
            "#........#",
            "#........#",
            "#........#",
            "#I......I#",
            "####..####"
        ], [
            "boss 4 3 bramble 20",
            "warp 8 1 101 1 3 4 6 oneway"
        ]))
        rooms.append(LanternRoomDef(0, 1, "dun1", [
            "####..####",
            "#P......P#",
            "#........#",
            "#........#",
            "#...C....#",
            "#........#",
            "#P......P#",
            "####..####"
        ], [
            "en flutterbug 2 3",
            "en blobbo 7 3",
            "chest 4 4 key 4 3",
            "clear 3"
        ]))
        rooms.append(LanternRoomDef(1, 1, "dun1", [
            "####KK####",
            "#P......P#",
            "#........#",
            "#........#",
            "#........#",
            "#...C....#",
            "#........#",
            "####..####"
        ], [
            "en shellguard 2 3",
            "en flutterbug 7 3",
            "chest 4 5 item:bombs 15",
            "blk 4 0 16"
        ]))
        rooms.append(LanternRoomDef(2, 1, "dun1", [
            "##########",
            "#I......I#",
            "#........#",
            "#........N",
            "#........N",
            "#........#",
            "#I......I#",
            "####..####"
        ], [
            "mini 4 4 mossback 7",
            "shut 7"
        ]))
        rooms.append(LanternRoomDef(3, 1, "dun1", [
            "##########",
            "#P......P#",
            "#........#",
            ".........#",
            "....C....#",
            "#........#",
            "#P......P#",
            "####..####"
        ], [
            "chest 4 4 item:boomerang 8"
        ]))
        rooms.append(LanternRoomDef(0, 2, "dun1", [
            "####NN####",
            "#........#",
            "#........#",
            "#..S......",
            "#.........",
            "#........#",
            "#........#",
            "##########"
        ], [
            "switch 3 3 1",
            "block 2 5",
            "en blobbo 3 6",
            "shut 1"
        ]))
        rooms.append(LanternRoomDef(1, 2, "dun1", [
            "####LL####",
            "#..P..P..#",
            "#.o....o.#",
            "....II...L",
            "....II...L",
            "#.o....o.#",
            "#........#",
            "####..####"
        ], [
            "en flutterbug 4 5",
            "en shellguard 5 5",
            "lock 9 3 11",
            "lock 4 0 12"
        ]))
        rooms.append(LanternRoomDef(2, 2, "dun1", [
            "####NN####",
            "#........#",
            "#.I....I.#",
            "..........",
            "..........",
            "#......S.#",
            "#...C....#",
            "##########"
        ], [
            "en shellguard 4 3",
            "en blobbo 6 3",
            "block 2 5",
            "switch 7 5 6",
            "chest 4 6 key 9 10",
            "shut 6",
            "clear 10"
        ]))
        rooms.append(LanternRoomDef(3, 2, "dun1", [
            "####..####",
            "#........#",
            "#.......E#",
            ".........#",
            "...oo....#",
            "#........#",
            "#...C....#",
            "##########"
        ], [
            "eye 8 2 13",
            "en wisp 2 5",
            "en wisp 7 5",
            "chest 4 6 bigkey 14 13"
        ]))
        rooms.append(LanternRoomDef(1, 3, "dun1", [
            "####..####",
            "#P......P#",
            "#........#",
            "#..I..I...",
            "#.........",
            "#........#",
            "#........#",
            "####D#####"
        ], [
            "en blobbo 3 4",
            "en blobbo 6 4",
            "warp 4 7 0 4 4 6 4"
        ]))
        rooms.append(LanternRoomDef(2, 3, "dun1", [
            "##########",
            "#P.P..P.P#",
            "#........#",
            ".........#",
            ".........#",
            "#........#",
            "#...C....#",
            "##########"
        ], [
            "en flutterbug 2 5",
            "en flutterbug 7 5",
            "chest 4 6 gems:20 17"
        ]))
        let area = LanternArea(num: 101, id: "d1", name: "HOLLOW OAK", kind: 2, gw: 4, gh: 4, rooms: rooms)
        return LanternDungeon(num: 1, id: "d1", name: "HOLLOW OAK", sparkName: "DEW SPARK", area: area,
                              entryGx: 1, entryGy: 3, entryTx: 4, entryTy: 6, sparksNeeded: 0,
                              bossId: "bramble", rewardItem: "boomerang")
    }
}
