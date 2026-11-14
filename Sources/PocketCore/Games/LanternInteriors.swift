#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// Houses, shop and caves: every room of this area is a separate one-room interior reached by warps.
enum LanternInteriors {
    static func make() -> LanternArea {
        var rooms: [LanternRoomDef] = []
        rooms.append(LanternRoomDef(0, 0, "indoor", [
            "##########",
            "#mC...hh.#",
            "#........#",
            "#..gg..a.#",
            "#..gg....#",
            "#........#",
            "#........#",
            "####d#####"
        ], [
            "chest 2 1 item:sword 1",
            "npc biscuit 7 5",
            "warp 4 7 0 3 7 2 5",
            "music indoor"
        ]))
        rooms.append(LanternRoomDef(1, 0, "indoor", [
            "##########",
            "#hhh..hhh#",
            "#........#",
            "#..aaa...#",
            "#........#",
            "#.g....g.#",
            "#........#",
            "####d#####"
        ], [
            "npc elder 6 4",
            "warp 4 7 0 3 7 7 5"
        ]))
        rooms.append(LanternRoomDef(2, 0, "indoor", [
            "##########",
            "#hh....hh#",
            "#........#",
            "#.ccccc..#",
            "#........#",
            "#........#",
            "#........#",
            "####d#####"
        ], [
            "wares 2 3 item:shield 30 2",
            "wares 4 3 bombs:5 10",
            "wares 6 3 arrows:10 15",
            "npc shopkeeper 4 2",
            "warp 4 7 0 4 7 2 5"
        ]))
        rooms.append(LanternRoomDef(3, 0, "indoor", [
            "##########",
            "#hh......#",
            "#........#",
            "#...aa...#",
            "#........#",
            "#.g......#",
            "#........#",
            "####d#####"
        ], [
            "npc smith 6 4",
            "warp 4 7 0 5 7 4 5"
        ]))
        rooms.append(LanternRoomDef(4, 0, "indoor", [
            "##########",
            "#hhh..aa.#",
            "#........#",
            "#........#",
            "#...g....#",
            "#........#",
            "#........#",
            "####d#####"
        ], [
            "npc basil 4 3",
            "warp 4 7 0 4 7 7 5"
        ]))
        rooms.append(LanternRoomDef(0, 1, "cave", [
            "##########",
            "#........#",
            "#..C.....#",
            "#........#",
            "#........#",
            "#........#",
            "#........#",
            "####D#####"
        ], [
            "chest 3 2 item:gloves 3",
            "warp 4 7 0 2 5 3 5"
        ]))
        rooms.append(LanternRoomDef(1, 1, "cave", [
            "##########",
            "#P......P#",
            "#........#",
            "#........#",
            "#........#",
            "#........#",
            "#P......P#",
            "####D#####"
        ], [
            "pick 4 3 piece 4",
            "warp 4 7 0 6 6 3 5"
        ]))
        rooms.append(LanternRoomDef(2, 1, "cave", [
            "##########",
            "#........#",
            "#...ww...#",
            "#...ww...#",
            "#........#",
            "#........#",
            "#........#",
            "####D#####"
        ], [
            "fountain 4 2",
            "music fairy",
            "warp 4 7 0 5 4 7 5"
        ]))
        rooms.append(LanternRoomDef(3, 1, "cave", [
            "##########",
            "#........#",
            "#NNNNNNNN#",
            "#........#",
            "#........#",
            "#......S.#",
            "#........#",
            "####D#####"
        ], [
            "block 2 5",
            "switch 7 5 5",
            "shut 5",
            "pick 5 1 piece 6",
            "warp 4 7 0 5 1 6 4"
        ]))
        rooms.append(LanternRoomDef(4, 1, "cave", [
            "##########",
            "#........#",
            "#...ww...#",
            "#...ww...#",
            "#........#",
            "#........#",
            "#........#",
            "####D#####"
        ], [
            "fountain 4 2",
            "music fairy",
            "warp 4 7 0 1 0 7 4"
        ]))
        rooms.append(LanternRoomDef(5, 1, "cave", [
            "##########",
            "#P......P#",
            "#........#",
            "#........#",
            "#........#",
            "#........#",
            "#P......P#",
            "####D#####"
        ], [
            "pick 4 3 piece 7",
            "warp 4 7 0 0 3 3 5"
        ]))
        rooms.append(LanternRoomDef(6, 1, "cave", [
            "##########",
            "#........#",
            "#...C....#",
            "#........#",
            "#........#",
            "#........#",
            "#........#",
            "####D#####"
        ], [
            "chest 4 2 gems:30 8",
            "warp 4 7 0 5 6 2 4"
        ]))
        rooms.append(LanternRoomDef(0, 2, "indoor", [
            "##########",
            "#hh......#",
            "#........#",
            "#...aa...#",
            "#........#",
            "#.g......#",
            "#........#",
            "####d#####"
        ], [
            "npc finn 5 4",
            "warp 4 7 0 1 6 5 5"
        ]))
        rooms.append(LanternRoomDef(1, 2, "indoor", [
            "##########",
            "#........#",
            "#.hh.....#",
            "#........#",
            "#...g....#",
            "#........#",
            "#........#",
            "####d#####"
        ], [
            "npc frosty 5 4",
            "warp 4 7 0 1 2 5 5"
        ]))
        return LanternArea(num: 1, id: "indoors", name: "INDOORS", kind: 1, gw: 8, gh: 8, rooms: rooms)
    }
}
