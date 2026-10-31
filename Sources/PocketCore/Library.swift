import Foundation

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
        .pocketPong
    ]

    public static func cartridge(id: String) -> Cartridge? {
        return all.first { $0.id == id }
    }
}
