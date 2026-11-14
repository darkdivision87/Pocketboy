#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// Everything that persists between play sessions. Layout of the exported bytes is documented in `saveBytes`.
struct LanternSave {
    static let version: UInt8 = 1
    static let byteCount = 446

    var started = false
    /// hearts are counted in halves
    var maxHp = 6
    var hp = 6
    var pieces = 0
    var gems = 0
    var bombs = 0
    var arrows = 0
    /// item bit of the B-button item, -1 for none
    var equipped = -1
    /// bit n set when spark n + 1 is collected
    var sparks = 0
    var itemLevel = [Int](repeating: 0, count: 64)
    var keys = [Int](repeating: 0, count: 8)
    var bigKeys = 0
    var maps = 0
    var qState = [Int](repeating: 0, count: 32)
    var qProg = [Int](repeating: 0, count: 32)
    var safeArea = 0
    var safeGx = 3
    var safeGy = 7
    var safeTx = 2
    var safeTy = 5
    var playFrames = 0
    var flags = [UInt8](repeating: 0, count: 256)
    var visited = [UInt8](repeating: 0, count: 64)

    func flag(_ i: Int) -> Bool {
        if i < 0 || i >= 2048 { return false }
        return (flags[i >> 3] >> UInt8(i & 7)) & 1 == 1
    }

    mutating func setFlag(_ i: Int) {
        if i < 0 || i >= 2048 { return }
        flags[i >> 3] |= UInt8(1) << UInt8(i & 7)
    }

    func seen(_ i: Int) -> Bool {
        if i < 0 || i >= 512 { return false }
        return (visited[i >> 3] >> UInt8(i & 7)) & 1 == 1
    }

    mutating func markSeen(_ i: Int) {
        if i < 0 || i >= 512 { return }
        visited[i >> 3] |= UInt8(1) << UInt8(i & 7)
    }

    func sparkCount() -> Int {
        var n = 0
        for i in 0..<8 where (sparks >> i) & 1 == 1 { n += 1 }
        return n
    }

    func has(_ bit: Int) -> Bool {
        if bit < 0 || bit > 63 { return false }
        return itemLevel[bit] > 0
    }
}

extension LanternQuest {
    /// Byte layout: 0 version, 1 started, 2 maxHp, 3 hp, 4 pieces, 5-6 gems, 7 bombs, 8 arrows, 9 equipped+1, 10 sparks,
    /// 11 bigKeys, 12 maps, 13-16 play minutes, 17-21 safe spot (area, gx, gy, tx, ty), 22-29 keys, 30-61 item levels (nibbles),
    /// 62-93 quest states, 94-125 quest progress, 126-381 flags, 382-445 visited rooms.
    func saveBytes() -> [UInt8] {
        if !save.started { return [] }
        var b = [UInt8](repeating: 0, count: LanternSave.byteCount)
        b[0] = LanternSave.version
        b[1] = 1
        b[2] = UInt8(clamp(save.maxHp, 0, 255))
        b[3] = UInt8(clamp(save.hp, 0, 255))
        b[4] = UInt8(clamp(save.pieces, 0, 255))
        let g = clamp(save.gems, 0, 65535)
        b[5] = UInt8(g & 255)
        b[6] = UInt8((g >> 8) & 255)
        b[7] = UInt8(clamp(save.bombs, 0, 255))
        b[8] = UInt8(clamp(save.arrows, 0, 255))
        b[9] = UInt8(clamp(save.equipped + 1, 0, 255))
        b[10] = UInt8(clamp(save.sparks, 0, 255))
        b[11] = UInt8(clamp(save.bigKeys, 0, 255))
        b[12] = UInt8(clamp(save.maps, 0, 255))
        let minutes = clamp(save.playFrames / 3600, 0, 16_000_000)
        b[13] = UInt8(minutes & 255)
        b[14] = UInt8((minutes >> 8) & 255)
        b[15] = UInt8((minutes >> 16) & 255)
        b[16] = 0
        b[17] = UInt8(clamp(save.safeArea, 0, 255))
        b[18] = UInt8(clamp(save.safeGx, 0, 255))
        b[19] = UInt8(clamp(save.safeGy, 0, 255))
        b[20] = UInt8(clamp(save.safeTx, 0, 255))
        b[21] = UInt8(clamp(save.safeTy, 0, 255))
        for i in 0..<8 { b[22 + i] = UInt8(clamp(save.keys[i], 0, 255)) }
        for i in 0..<32 {
            let lo = clamp(save.itemLevel[i * 2], 0, 15)
            let hi = clamp(save.itemLevel[i * 2 + 1], 0, 15)
            b[30 + i] = UInt8(lo | (hi << 4))
            b[62 + i] = UInt8(clamp(save.qState[i], 0, 255))
            b[94 + i] = UInt8(clamp(save.qProg[i], 0, 255))
        }
        for i in 0..<256 { b[126 + i] = save.flags[i] }
        for i in 0..<64 { b[382 + i] = save.visited[i] }
        return b
    }

    /// Defensive: wrong length, version or nonsense values never trap; everything is clamped.
    func loadBytes(_ b: [UInt8]) {
        if b.count < LanternSave.byteCount { return }
        if b[0] == 0 { return }
        if b[1] == 0 { return }
        var s = LanternSave()
        s.started = true
        s.maxHp = clamp(Int(b[2]), 6, 40)
        if s.maxHp % 2 == 1 { s.maxHp += 1 }
        s.hp = clamp(Int(b[3]), 1, s.maxHp)
        s.pieces = clamp(Int(b[4]), 0, 3)
        s.gems = clamp(Int(b[5]) | (Int(b[6]) << 8), 0, 999)
        s.bombs = clamp(Int(b[7]), 0, 30)
        s.arrows = clamp(Int(b[8]), 0, 50)
        s.equipped = clamp(Int(b[9]) - 1, -1, 63)
        s.sparks = Int(b[10])
        s.bigKeys = Int(b[11])
        s.maps = Int(b[12])
        let minutes = Int(b[13]) | (Int(b[14]) << 8) | (Int(b[15]) << 16)
        s.playFrames = clamp(minutes, 0, 16_000_000) * 3600
        s.safeArea = Int(b[17])
        s.safeGx = clamp(Int(b[18]), 0, 7)
        s.safeGy = clamp(Int(b[19]), 0, 7)
        s.safeTx = clamp(Int(b[20]), 0, 9)
        s.safeTy = clamp(Int(b[21]), 0, 7)
        for i in 0..<8 { s.keys[i] = clamp(Int(b[22 + i]), 0, 9) }
        for i in 0..<32 {
            s.itemLevel[i * 2] = Int(b[30 + i] & 15)
            s.itemLevel[i * 2 + 1] = Int((b[30 + i] >> 4) & 15)
            s.qState[i] = clamp(Int(b[62 + i]), 0, 3)
            s.qProg[i] = clamp(Int(b[94 + i]), 0, 99)
        }
        for i in 0..<256 { s.flags[i] = b[126 + i] }
        for i in 0..<64 { s.visited[i] = b[382 + i] }
        if s.equipped >= 0 && s.itemLevel[s.equipped] == 0 { s.equipped = -1 }
        // the safe spot must exist and be standable, otherwise fall back to the village
        var ok = false
        if let a = LanternContent.area(s.safeArea), let r = a.room(s.safeGx, s.safeGy) {
            ok = LanternValidator.walkable(r, s.safeTx, s.safeTy)
        }
        if !ok {
            s.safeArea = 0
            s.safeGx = 3
            s.safeGy = 7
            s.safeTx = 2
            s.safeTy = 5
        }
        save = s
        hasSave = true
    }
}
