#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

public enum Library {
    /// Every cartridge on the shelf, in display order.
    public static let all: [Cartridge] = [
        .cappyLand,
        .desertPrince,
        .brickSmash,
        .blockDrop,
        .starInvaders,
        .rockBlaster,
        .serpentine,
        .roadHopper,
        .mazeMuncher,
        .caveFlap,
        .mineSweeper,
        .tinyQuest,
        .cratePusher,
        .turboLane,
        .kartRally64,
        .dungeon64,
        .starWing64,
        .tunnelRun64,
        .arena64,
        .hoverRace64,
        .skyGlider64,
        .snowSlalom64,
        .pocketPong
    ]

    public static func cartridge(id: String) -> Cartridge? {
        return all.first { $0.id == id }
    }
}
