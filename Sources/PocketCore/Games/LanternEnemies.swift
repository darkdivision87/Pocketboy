#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

enum LanternMath {
    /// 0 down, 1 up, 2 left, 3 right
    static func dirVec(_ d: Int) -> (Float, Float) {
        switch d {
        case 0: return (0, 1)
        case 1: return (0, -1)
        case 2: return (-1, 0)
        default: return (1, 0)
        }
    }

    static func axisDir(_ dx: Float, _ dy: Float) -> Int {
        if abs(dx) > abs(dy) { return dx < 0 ? 2 : 3 }
        return dy < 0 ? 1 : 0
    }

    static func length(_ dx: Float, _ dy: Float) -> Float {
        let v: Float = dx * dx + dy * dy
        if v <= 0 { return 0 }
        return sqrt(v)
    }
}

enum LanternAI {
    case wander, charge, shoot, hop, shield, flutter, burrow, spin, swarm, sidestep, spore, slide, fire, wisp
    case armored, mossback, bramble, scarab, custom
}

struct LanternEnemyDef {
    var id: String
    var name: String
    var hp: Int
    var speed: Float
    var touch: Int
    var ai: LanternAI
    var w: Int
    var h: Int
    var sprite: String
    /// ignores pits and water
    var flies = false
    /// ignores walls too
    var ghost = false
    /// 0 none, 1 front shield, 2 armour (only back hits count)
    var shield = 0
    var custom: ((LanternQuest, LanternEnemy) -> Void)? = nil

    init(_ id: String, _ name: String, hp: Int, speed: Float, touch: Int, ai: LanternAI, w: Int, h: Int, sprite: String) {
        self.id = id
        self.name = name
        self.hp = hp
        self.speed = speed
        self.touch = touch
        self.ai = ai
        self.w = w
        self.h = h
        self.sprite = sprite
    }
}

final class LanternEnemy {
    var def: LanternEnemyDef
    var x: Float
    var y: Float
    var vx: Float = 0
    var vy: Float = 0
    var hp: Int
    var maxHp: Int
    var dir = 0
    var state = 0
    var timer = 0
    var flash = 0
    var stun = 0
    var invuln = 0
    var spawnT = 40
    var hidden = false
    var kbx: Float = 0
    var kby: Float = 0
    var kbT = 0
    var hitSwing = -1
    var dead = false
    var aux = 0
    var anim = 0
    var isMini = false
    var isBoss = false
    var flagGlobal = -1
    var heartFlag = -1
    var sparkFlag = -1
    var dungeon = 0
    var z: Float = 0

    init(_ def: LanternEnemyDef, _ x: Float, _ y: Float) {
        self.def = def
        self.x = x
        self.y = y
        self.hp = def.hp
        self.maxHp = def.hp
    }

    var cx: Float { return x + Float(def.w) / 2 }
    var cy: Float { return y + Float(def.h) / 2 }
}

enum LanternEnemies {
    static func make(_ id: String, _ name: String, _ hp: Int, _ speed: Float, _ touch: Int, _ ai: LanternAI,
                     _ w: Int, _ h: Int) -> LanternEnemyDef {
        return LanternEnemyDef(id, name, hp: hp, speed: speed, touch: touch, ai: ai, w: w, h: h, sprite: id)
    }

    static func defs() -> [LanternEnemyDef] {
        var d: [LanternEnemyDef] = []
        d.append(make("blobbo", "BLOBBO", 2, 0.35, 1, .wander, 12, 10))
        d.append(make("boarly", "BOARLY", 4, 0.4, 2, .charge, 12, 11))
        d.append(make("pebbler", "PEBBLER", 3, 0.3, 1, .shoot, 12, 11))
        d.append(make("hopper", "HOPPER", 3, 1.5, 1, .hop, 12, 10))
        var shell = make("shellguard", "SHELLGUARD", 4, 0.5, 1, .shield, 12, 11)
        shell.shield = 1
        d.append(shell)
        var bug = make("flutterbug", "FLUTTERBUG", 2, 0.8, 1, .flutter, 12, 8)
        bug.flies = true
        d.append(bug)
        d.append(make("sandmole", "SANDMOLE", 3, 0.9, 1, .burrow, 12, 11))
        d.append(make("spinwheel", "SPINWHEEL", 3, 1.3, 1, .spin, 12, 11))
        d.append(make("beetlebit", "BEETLEBIT", 1, 0.9, 1, .swarm, 8, 8))
        d.append(make("crabby", "CRABBY", 3, 0.8, 1, .sidestep, 12, 10))
        d.append(make("sporecap", "SPORECAP", 3, 0, 1, .spore, 12, 10))
        d.append(make("frostling", "FROSTLING", 4, 2.2, 1, .slide, 12, 11))
        d.append(make("embling", "EMBLING", 3, 0.35, 1, .fire, 12, 11))
        var wisp = make("wisp", "WISP", 2, 0.45, 1, .wisp, 12, 10)
        wisp.flies = true
        wisp.ghost = true
        d.append(wisp)
        var clunk = make("clunker", "CLUNKER", 6, 0.7, 2, .armored, 12, 11)
        clunk.shield = 2
        d.append(clunk)
        return d
    }

    static func bosses() -> [LanternBossDef] {
        return [
            LanternBossDef(id: "mossback", name: "MOSSBACK", hp: 14, ai: .mossback, w: 20, h: 16, tune: "boss"),
            LanternBossDef(id: "clunkknight", name: "CLUNK KNIGHT", hp: 16, ai: .armored, w: 20, h: 20, tune: "boss"),
            LanternBossDef(id: "bramble", name: "QUEEN BRAMBLE", hp: 24, ai: .bramble, w: 28, h: 28, tune: "boss"),
            LanternBossDef(id: "scarab", name: "GRAND SCARAB", hp: 28, ai: .scarab, w: 26, h: 18, tune: "boss")
        ]
    }
}

extension LanternQuest {
    // MARK: Spawning

    func makeEnemy(_ def: LanternEnemyDef, _ tx: Int, _ ty: Int) -> LanternEnemy {
        let ex = Float(tx * 16 + (16 - def.w) / 2)
        let ey = Float(ty * 16 + (16 - def.h))
        let e = LanternEnemy(def, ex, ey)
        e.dir = rng.int(4)
        e.timer = rng.range(10, 60)
        e.aux = rng.int(60)
        e.spawnT = 30 + rng.int(20)
        return e
    }

    func makeBossEnemy(_ b: LanternBossDef, _ tx: Int, _ ty: Int) -> LanternEnemy {
        var def = LanternEnemyDef(b.id, b.name, hp: b.hp, speed: 0.6, touch: 2, ai: b.ai, w: b.w, h: b.h, sprite: "")
        if b.ai == .armored { def.shield = 2; def.speed = 0.9 }
        let ex = Float(tx * 16 + (16 - b.w) / 2)
        let ey = Float(ty * 16 + (16 - b.h))
        let e = LanternEnemy(def, ex, ey)
        e.spawnT = 50
        e.timer = 60
        return e
    }

    func spawnMinion(_ id: String, _ x: Float, _ y: Float) {
        guard let def = LanternContent.enemy(id) else { return }
        if room.enemies.count > 9 { return }
        let e = LanternEnemy(def, x, y)
        e.spawnT = 20
        room.enemies.append(e)
        puff(x + 6, y + 6, 5, LanternC.white)
    }

    // MARK: Collision helpers

    func enemyBlocked(_ x: Float, _ y: Float, _ e: LanternEnemy) -> Bool {
        let w = e.def.w
        let h = e.def.h
        if x < 0 || y < 0 || x + Float(w) > 160 || y + Float(h) > 128 { return true }
        if e.def.ghost { return false }
        let x0 = Int(x) >> 4
        let y0 = Int(y) >> 4
        let x1 = (Int(x) + w - 1) >> 4
        let y1 = (Int(y) + h - 1) >> 4
        var ty = y0
        while ty <= y1 {
            var tx = x0
            while tx <= x1 {
                let t = room.tile(tx, ty)
                if LanternTile.isSolid(t) {
                    if !(e.def.flies && t == LanternTile.water) { return true }
                } else if LanternTile.isHazard(t) && !e.def.flies {
                    return true
                }
                tx += 1
            }
            ty += 1
        }
        return false
    }

    /// Returns true if both axes moved.
    func enemyStep(_ e: LanternEnemy, _ dx: Float, _ dy: Float) -> Bool {
        var ok = true
        let nx = e.x + dx
        if !enemyBlocked(nx, e.y, e) { e.x = nx } else { ok = false }
        let ny = e.y + dy
        if !enemyBlocked(e.x, ny, e) { e.y = ny } else { ok = false }
        return ok
    }

    func towardHero(_ e: LanternEnemy) -> (Float, Float) {
        let dx: Float = heroCX - e.cx
        let dy: Float = heroCY - e.cy
        let l = LanternMath.length(dx, dy)
        if l < 0.001 { return (0, 0) }
        return (dx / l, dy / l)
    }

    // MARK: Damage

    func isShielded(_ e: LanternEnemy, _ srcX: Float, _ srcY: Float) -> Bool {
        if e.def.shield == 0 { return false }
        if e.def.ai == .armored {
            if e.state == 2 { return false }
            if e.state == 1 { return true }
        }
        let v = LanternMath.dirVec(e.dir)
        let dot: Float = v.0 * (srcX - e.cx) + v.1 * (srcY - e.cy)
        if e.def.shield == 1 { return dot > 0 }
        return dot > -4
    }

    func bossVulnerable(_ e: LanternEnemy) -> Bool {
        switch e.def.ai {
        case .bramble: return e.state == 2
        case .scarab: return e.state == 4 || e.state == 6
        default: return true
        }
    }

    /// kind: 0 sword, 1 arrow, 2 boomerang, 3 bomb, 4 flame, 5 thrown rock
    @discardableResult
    func hurtEnemy(_ e: LanternEnemy, _ dmg: Int, _ kind: Int, _ srcX: Float, _ srcY: Float) -> Bool {
        if e.dead || e.hidden || e.spawnT > 0 { return false }
        if e.invuln > 0 { return false }
        if (e.isBoss || e.isMini) && !bossVulnerable(e) && kind != 3 {
            play(.blip)
            e.invuln = 8
            puff(srcX, srcY, 3, LanternC.white)
            return false
        }
        if kind != 3 && isShielded(e, srcX, srcY) {
            play(.thud)
            e.invuln = 10
            puff(srcX, srcY, 3, LanternC.grayL)
            return false
        }
        if kind == 2 {
            e.stun = 70
            if !(e.isBoss || e.isMini) { e.hp -= 1 }
            else { e.hp -= 1 }
        } else {
            e.hp -= dmg
        }
        e.flash = 10
        e.invuln = kind == 0 ? 14 : 8
        play(.hit)
        if !(e.isBoss || e.isMini) {
            let dx: Float = e.cx - srcX
            let dy: Float = e.cy - srcY
            let l = LanternMath.length(dx, dy)
            if l > 0.01 {
                e.kbx = dx / l * 2.6
                e.kby = dy / l * 2.6
                e.kbT = 7
            }
        } else {
            shake = max(shake, 4)
        }
        if e.hp <= 0 { killEnemy(e) }
        return true
    }

    func killEnemy(_ e: LanternEnemy) {
        if e.dead { return }
        e.dead = true
        let px: Float = e.cx
        let py: Float = e.cy
        for _ in 0..<10 {
            let a: Float = Float(rng.int(628)) / 100
            let sp: Float = 0.6 + Float(rng.int(14)) / 10
            addParticle(px, py, cos(a) * sp, sin(a) * sp, 24 + rng.int(14), rng.chance(50) ? LanternC.gold : LanternC.white, 1)
        }
        play(.stomp)
        questKill(e.def.id)
        if e.isBoss || e.isMini {
            shake = 24
            play(.explosion)
            for _ in 0..<20 {
                let a: Float = Float(rng.int(628)) / 100
                let sp: Float = 0.4 + Float(rng.int(24)) / 10
                addParticle(px, py, cos(a) * sp, sin(a) * sp, 40 + rng.int(30), rng.chance(50) ? LanternC.pink : LanternC.gold, 1)
            }
            if e.flagGlobal >= 0 { save.setFlag(e.flagGlobal) }
            if e.isBoss {
                bossDefeated(e)
            } else if curTune != room.musicName { setTune(room.musicName) }
            return
        }
        let r = rng.int(100)
        if r < 12 && e.def.id != "beetlebit" {
            dropPickup("heal:2", px, py)
        } else if r < 50 {
            dropPickup("gems:1", px, py)
        }
    }

    func bossDefeated(_ e: LanternEnemy) {
        setTune(room.musicName)
        room.bossAlive = false
        let cxTile = clamp(Int(e.cx) / 16, 1, 8)
        let cyTile = clamp(Int(e.cy) / 16, 1, 6)
        room.bossRewardTimer = 70
        room.bossRewardX = cxTile
        room.bossRewardY = cyTile
        room.bossHeartFlag = e.heartFlag
        room.bossSparkFlag = e.sparkFlag
        room.bossDungeon = e.dungeon
    }

    // MARK: AI

    func updateEnemies() {
        var i = 0
        while i < room.enemies.count {
            let e = room.enemies[i]
            if e.dead {
                room.enemies.remove(at: i)
                continue
            }
            updateEnemy(e)
            i += 1
        }
        // boss rewards appear a moment after the boss is gone
        if room.bossRewardTimer > 0 {
            room.bossRewardTimer -= 1
            if room.bossRewardTimer == 0 { spawnBossRewards() }
        }
    }

    func spawnBossRewards() {
        let bx = room.bossRewardX
        let by = room.bossRewardY
        if !save.flag(room.bossHeartFlag) {
            let p = LanternPickup("heartc", Float(bx * 16 - 12 + 4), Float(by * 16 + 4), room.bossHeartFlag)
            room.pickups.append(p)
        }
        if !save.flag(room.bossSparkFlag) {
            let p = LanternPickup("spark:" + String(room.bossDungeon), Float(bx * 16 + 12 + 4), Float(by * 16 + 4), room.bossSparkFlag)
            room.pickups.append(p)
        }
        play(.powerup)
    }

    func updateEnemy(_ e: LanternEnemy) {
        e.anim += 1
        if e.spawnT > 0 { e.spawnT -= 1; return }
        if e.flash > 0 { e.flash -= 1 }
        if e.invuln > 0 { e.invuln -= 1 }
        if e.kbT > 0 {
            _ = enemyStep(e, e.kbx, e.kby)
            e.kbT -= 1
            e.kbx *= 0.85
            e.kby *= 0.85
        }
        if e.stun > 0 {
            e.stun -= 1
            touchHero(e)
            return
        }
        switch e.def.ai {
        case .wander: aiWander(e)
        case .charge: aiCharge(e)
        case .shoot: aiShoot(e, false)
        case .fire: aiShoot(e, true)
        case .hop: aiHop(e)
        case .shield: aiChase(e, e.def.speed)
        case .flutter: aiFlutter(e)
        case .burrow: aiBurrow(e)
        case .spin: aiSpin(e)
        case .swarm: aiSwarm(e)
        case .sidestep: aiSidestep(e)
        case .spore: aiSpore(e)
        case .slide: aiSlide(e)
        case .wisp: aiWisp(e)
        case .armored: aiArmored(e)
        case .mossback: aiMossback(e)
        case .bramble: aiBramble(e)
        case .scarab: aiScarab(e)
        case .custom:
            if let f = e.def.custom { f(self, e) }
        }
        touchHero(e)
    }

    func touchHero(_ e: LanternEnemy) {
        if e.hidden || e.spawnT > 0 || e.dead { return }
        if e.def.touch <= 0 { return }
        let hb = heroHurtBox()
        let eb = Box(Int(e.x) + 1, Int(e.y) + 1, max(1, e.def.w - 2), max(1, e.def.h - 2))
        if hb.intersects(eb) {
            damageHero(e.def.touch, e.cx, e.cy)
        }
    }

    func aiWander(_ e: LanternEnemy) {
        e.timer -= 1
        if e.timer <= 0 {
            e.state = rng.int(3)
            e.timer = rng.range(30, 80)
            if e.state < 2 { e.dir = rng.int(4) }
        }
        if e.state < 2 {
            let v = LanternMath.dirVec(e.dir)
            if !enemyStep(e, v.0 * e.def.speed, v.1 * e.def.speed) { e.timer = 0 }
        }
    }

    func aiChase(_ e: LanternEnemy, _ speed: Float) {
        e.timer -= 1
        if e.timer <= 0 {
            e.timer = 24
            e.dir = LanternMath.axisDir(heroCX - e.cx, heroCY - e.cy)
        }
        let v = LanternMath.dirVec(e.dir)
        if !enemyStep(e, v.0 * speed, v.1 * speed) {
            e.dir = rng.int(4)
            e.timer = 12
        }
    }

    func aiCharge(_ e: LanternEnemy) {
        if e.state == 5 {
            e.timer -= 1
            if e.timer <= 0 { e.state = 6; e.timer = 70 }
            return
        }
        if e.state == 6 {
            let v = LanternMath.dirVec(e.dir)
            e.timer -= 1
            if !enemyStep(e, v.0 * 2.1, v.1 * 2.1) || e.timer <= 0 {
                e.state = 0
                e.stun = 40
                e.timer = 30
                play(.thud)
            }
            return
        }
        aiWander(e)
        let dx: Float = heroCX - e.cx
        let dy: Float = heroCY - e.cy
        let near: Bool = LanternMath.length(dx, dy) < 100
        let aligned: Bool = abs(dx) < 8 || abs(dy) < 8
        if near && aligned && e.timer % 7 == 0 && rng.chance(40) {
            e.dir = LanternMath.axisDir(dx, dy)
            e.state = 5
            e.timer = 22
        }
    }

    func aiShoot(_ e: LanternEnemy, _ aimed: Bool) {
        if e.state == 3 {
            e.timer -= 1
            if e.timer <= 0 {
                if aimed {
                    let t = towardHero(e)
                    spawnProj(LanternPK.fire, e.cx, e.cy, t.0 * 1.4, t.1 * 1.4, 150, true, 1)
                } else {
                    let v = LanternMath.dirVec(e.dir)
                    spawnProj(LanternPK.rock, e.cx + v.0 * 6, e.cy + v.1 * 6, v.0 * 1.7, v.1 * 1.7, 120, true, 1)
                }
                play(.shoot)
                e.state = 0
                e.timer = rng.range(70, 130)
            }
            return
        }
        e.timer -= 1
        if e.timer <= 0 {
            let near: Bool = LanternMath.length(heroCX - e.cx, heroCY - e.cy) < 120
            if near && rng.chance(70) {
                e.dir = LanternMath.axisDir(heroCX - e.cx, heroCY - e.cy)
                e.state = 3
                e.timer = 22
                return
            }
            e.timer = rng.range(30, 70)
            e.dir = rng.int(4)
        }
        let v = LanternMath.dirVec(e.dir)
        if !enemyStep(e, v.0 * e.def.speed, v.1 * e.def.speed) { e.timer = 0 }
    }

    func aiHop(_ e: LanternEnemy) {
        e.timer -= 1
        if e.state == 0 {
            e.z = 0
            if e.timer <= 0 {
                e.state = 1
                e.timer = 20
                let t = towardHero(e)
                e.vx = t.0 * e.def.speed
                e.vy = t.1 * e.def.speed
                if rng.chance(25) { e.vx = -e.vx }
            }
        } else {
            _ = enemyStep(e, e.vx, e.vy)
            let p: Float = Float(20 - e.timer) / 20
            e.z = sin(p * 3.14159) * 7
            if e.timer <= 0 {
                e.state = 0
                e.timer = rng.range(25, 55)
            }
        }
    }

    func aiFlutter(_ e: LanternEnemy) {
        e.timer -= 1
        if e.timer <= 0 {
            e.timer = rng.range(18, 34)
            let t = towardHero(e)
            let rx: Float = Float(rng.int(200) - 100) / 100
            let ry: Float = Float(rng.int(200) - 100) / 100
            var vx: Float = t.0 * 0.5 + rx
            var vy: Float = t.1 * 0.5 + ry
            let l = LanternMath.length(vx, vy)
            if l > 0.01 { vx = vx / l * e.def.speed; vy = vy / l * e.def.speed }
            e.vx = vx
            e.vy = vy
        }
        if !enemyStep(e, e.vx, e.vy) {
            e.vx = -e.vx
            e.vy = -e.vy
        }
    }

    func aiBurrow(_ e: LanternEnemy) {
        e.timer -= 1
        if e.state == 0 {
            e.hidden = true
            let t = towardHero(e)
            _ = enemyStep(e, t.0 * e.def.speed, t.1 * e.def.speed)
            if e.anim % 6 == 0 { addParticle(e.cx, e.y + 10, 0, -0.2, 14, LanternC.pathD, 0) }
            let near: Bool = LanternMath.length(heroCX - e.cx, heroCY - e.cy) < 26
            if e.timer <= 0 || near && e.timer < 100 {
                e.state = 1
                e.hidden = false
                e.timer = 70
                puff(e.cx, e.cy, 6, LanternC.pathD)
                play(.thud)
            }
        } else {
            e.hidden = false
            if e.timer <= 0 {
                e.state = 0
                e.timer = rng.range(80, 130)
                puff(e.cx, e.cy, 5, LanternC.pathD)
            }
        }
    }

    func aiSpin(_ e: LanternEnemy) {
        if e.vx == 0 && e.vy == 0 {
            e.vx = rng.chance(50) ? e.def.speed : -e.def.speed
            e.vy = rng.chance(50) ? e.def.speed : -e.def.speed
        }
        let nx = e.x + e.vx
        if enemyBlocked(nx, e.y, e) { e.vx = -e.vx } else { e.x = nx }
        let ny = e.y + e.vy
        if enemyBlocked(e.x, ny, e) { e.vy = -e.vy } else { e.y = ny }
    }

    func aiSwarm(_ e: LanternEnemy) {
        let t = towardHero(e)
        let wob: Float = sin(Float(e.anim + e.aux) * 0.25) * 0.6
        let vx: Float = t.0 * e.def.speed - t.1 * wob
        let vy: Float = t.1 * e.def.speed + t.0 * wob
        _ = enemyStep(e, vx, vy)
    }

    func aiSidestep(_ e: LanternEnemy) {
        e.timer -= 1
        if e.state == 0 {
            let dx: Float = heroCX - e.cx
            let step: Float = dx < 0 ? -e.def.speed : e.def.speed
            if abs(dx) > 3 { _ = enemyStep(e, step, 0) }
            if e.timer <= 0 {
                if abs(heroCY - e.cy) < 50 && rng.chance(60) {
                    e.state = 1
                    e.timer = 14
                    e.vy = heroCY < e.cy ? -2.0 : 2.0
                } else {
                    e.timer = rng.range(30, 60)
                }
            }
        } else {
            if !enemyStep(e, 0, e.vy) { e.timer = 0 }
            if e.timer <= 0 { e.state = 0; e.timer = rng.range(40, 80) }
        }
    }

    func aiSpore(_ e: LanternEnemy) {
        e.timer -= 1
        if e.timer <= 0 {
            e.timer = 140
            if LanternMath.length(heroCX - e.cx, heroCY - e.cy) < 130 {
                for d in 0..<4 {
                    let v = LanternMath.dirVec(d)
                    spawnProj(LanternPK.spore, e.cx, e.cy, v.0 * 0.7, v.1 * 0.7, 70, true, 1)
                }
                play(.blip)
            }
        }
    }

    func aiSlide(_ e: LanternEnemy) {
        if e.state == 0 {
            e.timer -= 1
            if e.timer <= 0 {
                e.dir = LanternMath.axisDir(heroCX - e.cx, heroCY - e.cy)
                let v = LanternMath.dirVec(e.dir)
                e.vx = v.0 * e.def.speed
                e.vy = v.1 * e.def.speed
                e.state = 1
            }
        } else {
            let nx = e.x + e.vx
            if enemyBlocked(nx, e.y, e) { e.vx = -e.vx * 0.5 } else { e.x = nx }
            let ny = e.y + e.vy
            if enemyBlocked(e.x, ny, e) { e.vy = -e.vy * 0.5 } else { e.y = ny }
            e.vx *= 0.965
            e.vy *= 0.965
            if abs(e.vx) + abs(e.vy) < 0.25 {
                e.state = 0
                e.timer = rng.range(40, 70)
            }
        }
    }

    func aiWisp(_ e: LanternEnemy) {
        let t = towardHero(e)
        let wob: Float = sin(Float(e.anim) * 0.07) * 0.5
        e.x += t.0 * e.def.speed - t.1 * wob * 0.5
        e.y += t.1 * e.def.speed + t.0 * wob * 0.5
        e.x = clamp(e.x, 0, 148)
        e.y = clamp(e.y, 0, 116)
    }

    func aiArmored(_ e: LanternEnemy) {
        let big: Bool = e.isMini
        e.timer -= 1
        switch e.state {
        case 0:
            if e.timer % 30 == 0 { e.dir = LanternMath.axisDir(heroCX - e.cx, heroCY - e.cy) }
            let v = LanternMath.dirVec(e.dir)
            if !enemyStep(e, v.0 * e.def.speed, v.1 * e.def.speed) { e.dir = rng.int(4) }
            if e.timer <= 0 {
                e.state = 1
                e.timer = big ? 80 : 60
                e.dir = LanternMath.axisDir(heroCX - e.cx, heroCY - e.cy)
                play(.blip)
            }
        case 1:
            let v = LanternMath.dirVec(e.dir)
            let sp: Float = big ? 2.2 : 1.7
            if !enemyStep(e, v.0 * sp, v.1 * sp) {
                e.state = 2
                e.timer = big ? 110 : 90
                shake = max(shake, 6)
                play(.thud)
            }
            if e.timer <= 0 { e.state = 2; e.timer = big ? 110 : 90 }
        default:
            if e.timer <= 0 {
                e.state = 0
                e.timer = rng.range(110, 170)
            }
        }
    }

    func aiMossback(_ e: LanternEnemy) {
        e.timer -= 1
        switch e.state {
        case 0:
            if e.timer % 30 == 0 { e.dir = LanternMath.axisDir(heroCX - e.cx, heroCY - e.cy) }
            let v = LanternMath.dirVec(e.dir)
            _ = enemyStep(e, v.0 * 0.6, v.1 * 0.6)
            if e.timer <= 0 {
                e.state = 1
                e.timer = 26
                e.dir = LanternMath.axisDir(heroCX - e.cx, heroCY - e.cy)
            }
        case 1:
            if e.timer <= 0 { e.state = 2; e.timer = 80 }
        default:
            let v = LanternMath.dirVec(e.dir)
            let sp: Float = e.hp * 2 < e.maxHp ? 3.0 : 2.5
            if !enemyStep(e, v.0 * sp, v.1 * sp) || e.timer <= 0 {
                e.state = 0
                e.timer = 80
                e.stun = 90
                shake = 10
                play(.thud)
                if e.hp * 2 < e.maxHp {
                    spawnMinion("beetlebit", e.x, e.y)
                    spawnMinion("beetlebit", e.x + 8, e.y + 4)
                }
            }
        }
    }

    func aiBramble(_ e: LanternEnemy) {
        let phase: Int = e.hp > 16 ? 0 : (e.hp > 8 ? 1 : 2)
        e.timer -= 1
        e.x += sin(Float(e.anim) / 38) * 0.45
        e.x = clamp(e.x, 20, 110)
        switch e.state {
        case 0:
            if e.timer <= 0 {
                e.state = 1
                e.timer = 10
                e.aux = phase == 2 ? 4 : 3
            }
        case 1:
            if e.timer <= 0 {
                e.timer = 24
                e.aux -= 1
                play(.shoot)
                let t = towardHero(e)
                if phase == 0 {
                    for k in -1...1 { petal(e, t, Float(k) * 0.35) }
                } else if phase == 1 {
                    for k in -2...2 { petal(e, t, Float(k) * 0.3) }
                } else {
                    for k in 0..<8 {
                        let a: Float = Float(k) * 0.785 + Float(e.anim % 20) * 0.02
                        spawnProj(LanternPK.petal, e.cx, e.cy, cos(a) * 1.2, sin(a) * 1.2, 160, true, 1)
                    }
                }
                if e.aux <= 0 {
                    e.state = 2
                    e.timer = phase == 2 ? 80 : 95
                    shake = 12
                    if phase >= 1 {
                        spawnMinion("blobbo", e.x - 8, e.y + 22)
                        spawnMinion("blobbo", e.x + 28, e.y + 22)
                    }
                }
            }
        default:
            if e.timer <= 0 {
                e.state = 0
                e.timer = phase == 0 ? 70 : (phase == 1 ? 55 : 40)
            }
        }
    }

    func petal(_ e: LanternEnemy, _ t: (Float, Float), _ spread: Float) {
        let base: Float = atan2(t.1, t.0) + spread
        spawnProj(LanternPK.petal, e.cx, e.cy + 6, cos(base) * 1.3, sin(base) * 1.3, 160, true, 1)
    }

    func aiScarab(_ e: LanternEnemy) {
        let phase: Int = e.hp > 18 ? 0 : (e.hp > 9 ? 1 : 2)
        e.timer -= 1
        switch e.state {
        case 0:
            let dx: Float = heroCX - e.cx
            let sx: Float = dx < 0 ? -0.6 : 0.6
            if abs(dx) > 4 { _ = enemyStep(e, sx, 0) }
            if e.timer <= 0 {
                e.state = 1
                e.timer = 30
                e.dir = LanternMath.axisDir(heroCX - e.cx, heroCY - e.cy)
                play(.blip)
            }
        case 1:
            if e.timer <= 0 { e.state = 2; e.timer = 90 }
        case 2:
            let v = LanternMath.dirVec(e.dir)
            let sp: Float = phase == 2 ? 3.6 : 3.0
            if !enemyStep(e, v.0 * sp, v.1 * sp) || e.timer <= 0 {
                e.state = 4
                e.stun = 100
                e.timer = 1
                shake = 14
                play(.thud)
                if phase == 2 { sandRing(e) }
            }
        case 4:
            // dazed (stun counts down in updateEnemy, so this runs once it ends)
            if phase >= 1 {
                e.state = 5
                e.timer = 70
                e.hidden = true
                puff(e.cx, e.cy, 8, LanternC.pathD)
            } else {
                e.state = 0
                e.timer = 70
            }
        case 5:
            // burrowed: follow the hero's position, then pop up
            let dx: Float = heroCX - e.cx
            let dy: Float = heroCY - e.cy
            e.x += clamp(dx, -1.4, 1.4)
            e.y += clamp(dy, -1.4, 1.4)
            e.x = clamp(e.x, 4, 130)
            e.y = clamp(e.y, 4, 106)
            if e.anim % 5 == 0 { addParticle(e.cx, e.cy + 4, 0, -0.3, 14, LanternC.pathD, 0) }
            if e.timer <= 0 {
                e.state = 6
                e.timer = 80
                e.hidden = false
                shake = 8
                sandRing(e)
                play(.explosion)
            }
        default:
            if e.timer <= 0 {
                e.state = 0
                e.timer = 60
            }
        }
    }

    func sandRing(_ e: LanternEnemy) {
        for k in 0..<8 {
            let a: Float = Float(k) * 0.785
            spawnProj(LanternPK.sand, e.cx, e.cy, cos(a) * 1.1, sin(a) * 1.1, 80, true, 1)
        }
    }

    // MARK: Drawing

    func drawScaled(_ c: Canvas, _ s: Sprite, _ x: Int, _ y: Int, _ scale: Int, _ solid: Int?) {
        for sy in 0..<s.height {
            for sx in 0..<s.width {
                let v = s.data[sy * s.width + sx]
                if v == Sprite.clear { continue }
                let col: Int = solid ?? Int(v)
                c.fillRect(x + sx * scale, y + sy * scale, scale, scale, col)
            }
        }
    }

    func drawEnemy(_ c: Canvas, _ e: LanternEnemy) {
        if e.dead { return }
        if e.spawnT > 0 {
            if (e.spawnT / 3) % 2 == 0 { return }
        }
        let flashing: Bool = e.flash > 0 && e.flash % 4 < 2
        let solid: Int? = flashing ? LanternC.white : nil
        let ix = Int(e.x)
        let iy = Int(e.y)
        if e.hidden {
            if e.def.ai == .burrow || e.def.ai == .scarab {
                c.fillRect(ix + 3, iy + e.def.h - 3, 6, 2, LanternC.pathD)
            }
            return
        }
        switch e.def.ai {
        case .mossback: drawMossback(c, e, solid)
        case .bramble: drawBramble(c, e, solid)
        case .scarab: drawScarab(c, e, solid)
        default:
            if e.isMini {
                if let s = LanternArt.enemySprites["clunker"] {
                    drawScaled(c, s, ix - 2, iy - 4, 2, solid)
                    if e.state == 2 { dizzy(c, ix + 10, iy - 8) }
                    drawShieldMark(c, e, ix + 10, iy + 10, 12)
                }
                return
            }
            guard let s = LanternArt.enemySprites[e.def.sprite] else { return }
            let sx: Int = ix + (e.def.w - s.width) / 2
            var sy: Int = iy + e.def.h - s.height - Int(e.z)
            if e.def.flies && !e.def.ghost { sy += Int(sin(Float(e.anim) * 0.2) * 2) }
            var flip = (e.anim / 14) % 2 == 1
            if e.def.ai == .spin { flip = (e.anim / 4) % 2 == 1 }
            if e.state == 5 && e.def.ai == .charge && e.timer % 4 < 2 { c.fillRect(ix + 5, iy - 6, 2, 4, LanternC.red); c.fillRect(ix + 5, iy - 1, 2, 1, LanternC.red) }
            if e.def.ai == .shoot || e.def.ai == .fire {
                if e.state == 3 && e.timer % 6 < 3 { c.draw(s, sx, sy, flipX: flip, solid: LanternC.white); return }
            }
            c.draw(s, sx, sy, flipX: flip, solid: solid)
            if e.def.shield > 0 { drawShieldMark(c, e, ix + e.def.w / 2, iy + e.def.h / 2, 6) }
            if e.def.ai == .armored && e.state == 2 { dizzy(c, ix + 6, iy - 4) }
            if e.stun > 0 && e.def.ai != .armored { dizzy(c, ix + 6, iy - 4) }
        }
    }

    func dizzy(_ c: Canvas, _ x: Int, _ y: Int) {
        let a: Int = (frame / 4) % 4
        let offs: [Int] = [-5, -2, 2, 5]
        c.setPixel(x + offs[a], y, LanternC.gold)
        c.setPixel(x + offs[(a + 2) % 4], y + 1, LanternC.white)
    }

    func drawShieldMark(_ c: Canvas, _ e: LanternEnemy, _ cx: Int, _ cy: Int, _ r: Int) {
        let v = LanternMath.dirVec(e.dir)
        let sx: Int = cx + Int(v.0 * Float(r)) - 1
        let sy: Int = cy + Int(v.1 * Float(r)) - 1
        if e.dir < 2 {
            c.fillRect(sx - 3, sy, 8, 3, LanternC.out)
            c.fillRect(sx - 2, sy + 1, 6, 1, LanternC.grayL)
        } else {
            c.fillRect(sx, sy - 3, 3, 8, LanternC.out)
            c.fillRect(sx + 1, sy - 2, 1, 6, LanternC.grayL)
        }
    }

    func drawMossback(_ c: Canvas, _ e: LanternEnemy, _ solid: Int?) {
        let x = Int(e.x)
        let y = Int(e.y)
        let sh: Int = e.state == 1 ? (e.timer % 4 < 2 ? 1 : -1) : 0
        let body: Int = solid ?? LanternC.brown
        let shell: Int = solid ?? LanternC.lime
        c.fillCircle(x + 10 + sh, y + 9, 9, LanternC.out)
        c.fillCircle(x + 10 + sh, y + 9, 8, body)
        c.fillCircle(x + 10 + sh, y + 8, 6, shell)
        c.vline(x + 10 + sh, y + 3, 11, solid ?? LanternC.out)
        c.hline(x + 5 + sh, y + 8, 11, solid ?? LanternC.out)
        c.fillRect(x + 7 + sh, y + 13, 2, 3, LanternC.out)
        c.fillRect(x + 12 + sh, y + 13, 2, 3, LanternC.out)
        let v = LanternMath.dirVec(e.dir)
        let hx: Int = x + 10 + Int(v.0 * 8)
        let hy: Int = y + 8 + Int(v.1 * 7)
        c.fillCircle(hx + sh, hy, 4, LanternC.out)
        c.fillCircle(hx + sh, hy, 3, solid ?? LanternC.gold)
        c.setPixel(hx + sh - 1, hy - 1, LanternC.out)
        c.setPixel(hx + sh + 1, hy - 1, LanternC.out)
        if e.stun > 0 { dizzy(c, x + 10, y - 6) }
    }

    func drawBramble(_ c: Canvas, _ e: LanternEnemy, _ solid: Int?) {
        let cx = Int(e.x) + 14
        let cy = Int(e.y) + 14
        let sway: Int = Int(sin(Float(e.anim) * 0.1) * 1.5)
        for k in 0..<8 {
            let a: Float = Float(k) * 0.785
            let px: Int = cx + Int(cos(a) * 11)
            let py: Int = cy + Int(sin(a) * 11) + sway
            c.fillCircle(px, py, 5, LanternC.out)
            c.fillCircle(px, py, 4, solid ?? (k % 2 == 0 ? LanternC.pink : LanternC.red))
        }
        c.fillCircle(cx, cy, 10, LanternC.out)
        c.fillCircle(cx, cy, 9, solid ?? LanternC.gold)
        c.fillCircle(cx - 3, cy - 3, 3, solid ?? LanternC.white)
        c.fillRect(cx - 5, cy - 3, 3, 3, LanternC.out)
        c.fillRect(cx + 2, cy - 3, 3, 3, LanternC.out)
        if e.state == 2 {
            c.fillRect(cx - 4, cy + 2, 9, 5, LanternC.out)
            c.fillRect(cx - 3, cy + 3, 7, 3, LanternC.red)
        } else {
            c.hline(cx - 4, cy + 4, 9, LanternC.out)
        }
        c.fillRect(cx - 14, cy + 13, 6, 3, LanternC.lime)
        c.fillRect(cx + 9, cy + 13, 6, 3, LanternC.lime)
    }

    func drawScarab(_ c: Canvas, _ e: LanternEnemy, _ solid: Int?) {
        let x = Int(e.x)
        let y = Int(e.y)
        let sh: Int = e.state == 1 ? (e.timer % 4 < 2 ? 1 : -1) : 0
        let shell: Int = solid ?? LanternC.blue
        c.fillCircle(x + 13 + sh, y + 10, 11, LanternC.out)
        c.fillRect(x + 2 + sh, y + 3, 22, 14, LanternC.out)
        c.fillCircle(x + 13 + sh, y + 10, 10, shell)
        c.fillRect(x + 3 + sh, y + 4, 20, 12, shell)
        c.vline(x + 13 + sh, y + 2, 16, solid ?? LanternC.out)
        c.fillRect(x + 7 + sh, y + 6, 3, 3, solid ?? LanternC.cyan)
        c.fillRect(x + 16 + sh, y + 6, 3, 3, solid ?? LanternC.cyan)
        c.hline(x + sh, y + 17, 5, LanternC.out)
        c.hline(x + 21 + sh, y + 17, 5, LanternC.out)
        c.fillRect(x + 11 + sh, y - 1, 4, 4, solid ?? LanternC.gold)
        if e.state == 4 || e.stun > 0 { dizzy(c, x + 13, y - 6) }
        if e.state == 6 && e.timer > 60 { c.fillRect(x - 2, y + 17, 30, 2, LanternC.pathD) }
    }

    /// A marker shadow where a burrowing boss will surface.
    func drawBossShadow(_ c: Canvas, _ e: LanternEnemy) {
        if e.def.ai == .scarab && e.state == 5 {
            let sx = Int(e.cx)
            let sy = Int(e.cy)
            c.strokeCircle(sx, sy + 4, 8, LanternC.out)
            if (e.timer / 4) % 2 == 0 { c.strokeCircle(sx, sy + 4, 6, LanternC.white) }
        }
    }
}
