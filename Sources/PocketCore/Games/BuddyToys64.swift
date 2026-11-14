#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

// Toys, goals and saving for BUDDY BOUNCE.

extension BuddyBounce64 {
    // MARK: Using toys

    func noteToyUsed(_ t: Int) {
        if frameN - lastToyFrame < 150 {
            toyChain += 1
            addCombo(6 + min(10, toyChain * 2))
            if toyChain >= 2 { addFloat("TOY CHAIN!", px, py - 20, 0xBFF0FF) }
        } else {
            toyChain = 0
            addCombo(3)
        }
        lastToyFrame = frameN
        if t >= 0 && t < BuddyData.toyCount {
            let bit: Int = 1 << t
            if toyUsedMask & bit == 0 {
                toyUsedMask |= bit
                goalProgress(2, 1)
            }
        }
        idleT = 0
    }

    func addAnim(_ kind: Int, _ x: Float, _ y: Float, _ dur: Int, _ hitT: Int, _ dir: Float) {
        if anims.count >= 6 { anims.remove(at: 0) }
        var a = BuddyAnim()
        a.kind = kind
        a.x = x
        a.y = y
        a.dur = dur
        a.hitT = hitT
        a.dir = dir
        a.sx = x < 160 ? 24 : 296
        a.sy = 250
        anims.append(a)
    }

    func useToy(_ t: Int, _ x: Float, _ y: Float) {
        noteToyUsed(t)
        let tx: Float = buddyClampF(x, wallL + 2, wallR - 2)
        let ty: Float = buddyClampF(y, ceilY, floorY)
        let side: Float = tx < 160 ? -1 : 1
        switch t {
        case 0:
            addAnim(0, tx, ty, 16, 5, side)
        case 1:
            addAnim(1, tx, ty, 20, 6, side)
        case 2:
            addAnim(2, tx, ty, 22, 8, -side)
        case 3:
            placePad(0, tx, ty)
        case 4:
            addAnim(3, tx, ty, 12, 10, side)
        case 5:
            addAnim(4, tx, ty, 12, 10, side)
        case 6:
            placePad(1, tx, ty)
        case 7:
            addAnim(5, tx, ty, 28, 8, side)
        case 9:
            rocketT = 170
            play(.powerup)
            expr = 1
            exprT = 90
            bubble = "WHEEE!"
            bubbleT = 90
            var i: Int = 0
            while i < 10 {
                spark(pts[4].x, pts[4].y, Float(rng.range(-20, 20)) / 10, Float(rng.range(0, 30)) / 10, 24, 5, 0xFFD23C, 3, 0.02)
                i += 1
            }
        case 10:
            var i: Int = 0
            while i < 3 {
                let ang: Float = Float(rng.int(628)) / 100
                let sp: Float = Float(rng.range(40, 80)) / 10
                spawnBall(tx, ty, cos(ang) * sp, sin(ang) * sp, 0)
                i += 1
            }
            play(.bounce)
            addBurst(tx, ty, "POP!", 0x4AD08A)
        case 14:
            if wheels.count >= 2 { wheels.remove(at: 0) }
            var w = BuddyWheel()
            w.x = buddyClampF(tx, 40, 280)
            w.y = buddyClampF(ty, 70, floorY - 30)
            w.spin = rng.chance(50) ? 0.22 : -0.22
            wheels.append(w)
            play(.select)
        case 15:
            placePad(2, tx, ty)
        case 16:
            addAnim(6, tx, ty, 150, 88, side == 1 ? -1 : 1)
            play(.stomp)
        case 17:
            spawnBall(tx, min(ty, floorY - 60), Float(rng.range(-30, 30)) / 10, -2, 1)
            play(.bounce)
        case 18:
            spawnBall(tx, ceilY + 24, Float(rng.range(-10, 10)) / 10, 1, 2)
            play(.drop)
        case 19:
            placePad(3, tx, ty)
        case 20:
            placePad(4, tx, ty)
        default:
            break
        }
    }

    func starPop(_ x: Float, _ y: Float, _ n: Int, _ col: UInt32) {
        var i: Int = 0
        while i < n {
            let ang: Float = Float(i) * 6.2832 / Float(max(1, n)) + Float(rng.int(100)) / 100
            let sp: Float = Float(rng.range(20, 55)) / 10
            spark(x, y, cos(ang) * sp, sin(ang) * sp, 26, 0, col, Float(rng.range(30, 50)) / 10, 0.04)
            i += 1
        }
    }

    /// Pushes every body part near (x, y). Returns how many parts were pushed.
    func radialPush(_ x: Float, _ y: Float, _ radius: Float, _ power: Float, _ up: Float, _ biasX: Float) -> Int {
        var hits: Int = 0
        var i: Int = 0
        while i < pts.count {
            let dx: Float = pts[i].x - x
            let dy: Float = pts[i].y - y
            let d: Float = sqrt(dx * dx + dy * dy)
            let lim: Float = radius + pts[i].r
            if d < lim {
                var f: Float = 1 - d / lim
                if f < 0.3 { f = 0.3 }
                var nx: Float = 0
                var ny: Float = -1
                if d > 0.5 {
                    nx = dx / d
                    ny = dy / d
                }
                impulse(i, nx * power * f + biasX * f, ny * power * f - up * f)
                hits += 1
            }
            i += 1
        }
        return hits
    }

    func applyAnim(_ a: BuddyAnim) {
        switch a.kind {
        case 0:
            let n: Int = radialPush(a.x, a.y, 38, 9.5, 4, 0)
            addBurst(a.x, a.y, "BONK!", 0xFFD23C)
            starPop(a.x, a.y, 10, 0xFFE066)
            play(.hit)
            if n > 0 {
                reactHit()
                squashBody(0.25)
                addCombo(8)
                cash = min(999999, cash + 1)
            }
        case 1:
            let n: Int = radialPush(a.x, a.y, 38, 6, 3, -a.dir * 7)
            addBurst(a.x, a.y, "POW!", 0xFF6B6B)
            starPop(a.x, a.y, 8, 0xFF9C9C)
            play(.stomp)
            if n > 0 {
                reactHit()
                squashBody(0.2)
                addCombo(8)
            }
        case 2:
            let n: Int = radialPush(a.x, a.y, 32, 6, 2, a.dir * 3)
            addBurst(a.x, a.y, "SQUEAK!", 0xFFD23C)
            play(.blip)
            play(.pickup)
            var i: Int = 0
            while i < 10 {
                spark(a.x, a.y, Float(rng.range(-30, 30)) / 10, Float(rng.range(-30, 10)) / 10, 36, 9, 0xFFF2A0, 4, 0.04)
                i += 1
            }
            if n > 0 {
                impulse(0, a.dir * 2, -1)
                impulse(12, -a.dir * 2, 0)
                impulse(14, -a.dir * 2, 0)
                reactHit()
                addCombo(8)
            }
        case 3:
            let near = nearestPart(a.x, a.y)
            addBurst(a.x, a.y, "SPLAT!", 0xFFFFFF)
            play(.drop)
            var i: Int = 0
            while i < 16 {
                spark(a.x, a.y, Float(rng.range(-35, 35)) / 10, Float(rng.range(-35, 10)) / 10, 34, 4, 0xFFF6E0, Float(rng.range(25, 45)) / 10, 0.14)
                i += 1
            }
            if near.1 < 30 {
                creamT = near.0 == 0 ? 620 : 420
                wetT = 0
                statPies = min(99999, statPies + 1)
                goalProgress(3, 1)
                _ = radialPush(a.x, a.y, 30, 2.5, 1, 0)
                reactHit()
                addCombo(9)
                bubble = "YUMMY!"
                bubbleT = 80
            }
        case 4:
            let near = nearestPart(a.x, a.y)
            addBurst(a.x, a.y, "SPLASH!", 0x7FD4FF)
            play(.drop)
            var i: Int = 0
            while i < 24 {
                spark(a.x, a.y, Float(rng.range(-45, 45)) / 10, Float(rng.range(-45, 5)) / 10, 34, 3, 0x7FD4FF, Float(rng.range(20, 40)) / 10, 0.16)
                i += 1
            }
            if near.1 < 36 {
                wetT = 480
                creamT = 0
                goalProgress(6, 1)
                _ = radialPush(a.x, a.y, 30, 2, 1, 0)
                reactHit()
                addCombo(9)
                bubble = "SPLISH SPLASH!"
                bubbleT = 90
            }
        case 5:
            let baseX: Float = a.dir < 0 ? wallL + 10 : wallR - 10
            let baseY: Float = floorY - 16
            var dx: Float = a.x - baseX
            var dy: Float = a.y - baseY
            let len: Float = max(1, sqrt(dx * dx + dy * dy))
            dx /= len
            dy /= len
            var i: Int = 0
            while i < 40 {
                let spread: Float = Float(rng.range(-15, 15)) / 40
                let ca: Float = cos(spread)
                let sa: Float = sin(spread)
                let vx0: Float = dx * ca - dy * sa
                let vy0: Float = dx * sa + dy * ca
                let sp: Float = Float(rng.range(40, 100)) / 10
                let c: UInt32 = BuddyData.confettiColors[rng.int(BuddyData.confettiColors.count)]
                spark(baseX + dx * 24, baseY + dy * 24, vx0 * sp, vy0 * sp, rng.range(60, 120), 1, c, Float(rng.range(20, 40)) / 10, 0.1)
                i += 1
            }
            let n: Int = radialPush(a.x, a.y, 70, 7.5, 3, 0)
            confettiBurst(a.x, a.y, 50)
            var b: Int = 0
            while b < 3 {
                spark(a.x + Float(rng.range(-20, 20)), a.y, Float(rng.range(-8, 8)) / 10, -Float(rng.range(10, 20)) / 10, 110, 6, BuddyData.confettiColors[rng.int(BuddyData.confettiColors.count)], 8, -0.01)
                b += 1
            }
            addBurst(a.x, a.y, "POP!", 0xB070FF)
            play(.powerup)
            if n > 0 {
                reactHit()
                squashBody(0.2)
                addCombo(10)
            }
        default:
            let n: Int = radialPush(a.x, a.y, 48, 11, 9, 0)
            addBurst(a.x, a.y, "BOOP!", 0x9AA4B8)
            play(.hit)
            play(.stomp)
            starPop(a.x, a.y, 10, 0xFFFFFF)
            if n > 0 {
                reactHit()
                squashBody(0.3)
                addCombo(14)
                goalProgress(8, 1)
                bubble = "WHEEE!"
                bubbleT = 90
            }
        }
    }

    // MARK: Elephant geometry (shared by update and drawing)

    /// Returns (x of the body centre, trunk raise 0...1).
    func elephantPose(_ a: BuddyAnim) -> (Float, Float) {
        let startX: Float = a.dir > 0 ? -60 : 380
        let standX: Float = buddyClampF(a.x - a.dir * 50, 10, 310)
        let t: Float = Float(a.t)
        var ex: Float = standX
        var raise: Float = 0
        if t < 70 {
            let u: Float = t / 70
            let e: Float = u * u * (3 - 2 * u)
            ex = startX + (standX - startX) * e
        } else if t < 118 {
            ex = standX
            if t < 88 {
                raise = (t - 70) / 18
            } else if t < 108 {
                raise = 1
            } else {
                raise = 1 - (t - 108) / 10
            }
        } else {
            let u: Float = min(1, (t - 118) / 32)
            let e: Float = u * u * (3 - 2 * u)
            ex = standX + (startX - standX) * e
        }
        return (ex, buddyClampF(raise, 0, 1))
    }

    func updateAnims() {
        var k: Int = 0
        while k < anims.count {
            anims[k].t += 1
            let a: BuddyAnim = anims[k]
            if !a.applied && a.t >= a.hitT {
                anims[k].applied = true
                applyAnim(a)
            }
            if a.kind == 6 && a.t >= 88 && a.t < 112 {
                let c: UInt32 = BuddyData.confettiColors[rng.int(BuddyData.confettiColors.count)]
                let drop: UInt32 = 0x7FD4FF
                spark(a.x, a.y, Float(rng.range(-25, 25)) / 10, -Float(rng.range(10, 30)) / 10, 40, 3, drop, 3, 0.12)
                spark(a.x, a.y, Float(rng.range(-25, 25)) / 10, -Float(rng.range(10, 30)) / 10, 40, 1, c, 3, 0.1)
            }
            k += 1
        }
        var j: Int = anims.count - 1
        while j >= 0 {
            if anims[j].t >= anims[j].dur { anims.remove(at: j) }
            j -= 1
        }
    }

    // MARK: Continuous (hold) toys

    func touchHold() {
        if preleased || !pdown {
            holdOn = false
            tickleActive = false
            mode = 0
            return
        }
        holdX = px
        holdY = py
    }

    func startSling() {
        noteToyUsed(selToy)
        slingOn = true
        slingAx = buddyClampF(cx, 40, 280)
        slingAy = buddyClampF(cy, 60, floorY - 40)
        slingPx = slingAx
        slingPy = slingAy
        play(.select)
    }

    func touchSling() {
        if pdown {
            var dx: Float = px - slingAx
            var dy: Float = py - slingAy
            let d: Float = sqrt(dx * dx + dy * dy)
            let maxD: Float = 90
            if d > maxD {
                dx = dx / d * maxD
                dy = dy / d * maxD
            }
            slingPx = slingAx + dx
            slingPy = slingAy + dy
        }
        if preleased || !pdown {
            launchSling()
            slingOn = false
            mode = 0
        }
    }

    func launchSling() {
        if !slingOn { return }
        var lvx: Float = (slingAx - slingPx) * 0.17
        var lvy: Float = (slingAy - slingPy) * 0.17
        let m: Float = sqrt(lvx * lvx + lvy * lvy)
        if m < 2.5 { return }
        if m > 15 {
            lvx = lvx / m * 15
            lvy = lvy / m * 15
        }
        var i: Int = 0
        while i < pts.count {
            pts[i].ox = pts[i].x - lvx
            pts[i].oy = pts[i].y - lvy
            i += 1
        }
        flung = true
        flingDone = false
        flingStartX = cx
        flingT = 0
        statFlings = min(99999, statFlings + 1)
        goalProgress(7, 1)
        addCombo(16)
        cash = min(999999, cash + 2)
        play(.powerup)
        play(.hit)
        expr = 1
        exprT = 100
        bubble = "WHEEE!"
        bubbleT = 100
        addBurst(slingPx, slingPy, "TWANG!", 0xB070FF)
        var s: Int = 0
        while s < 10 {
            spark(slingPx, slingPy, Float(rng.range(-30, 30)) / 10, Float(rng.range(-30, 30)) / 10, 24, 5, 0xFFFFFF, 3, 0.02)
            s += 1
        }
    }

    func applyForces() {
        tickleActive = false
        if holdOn && pdown {
            switch selToy {
            case 8:
                fanForce()
            case 11:
                tickleForce()
            case 12:
                magnetForce()
            default:
                break
            }
        }
        if slingOn && pdown && pts.count > 4 {
            let vx: Float = pts[4].x - pts[4].ox
            let vy: Float = pts[4].y - pts[4].oy
            let ax: Float = (slingPx - pts[4].x) * 0.25 - vx * 0.3
            let ay: Float = (slingPy - pts[4].y) * 0.25 - vy * 0.3
            impulse(4, ax, ay)
            impulse(1, ax * 0.5, ay * 0.5)
        }
        if rocketT > 0 {
            rocketT -= 1
            let ids: [Int] = [1, 2, 3, 4, 5, 6]
            for i in ids { impulse(i, 0, 0.6) }
            impulse(0, 0, 0.4)
            var steer: Float = 0
            if pdown && mode != 1 && py < Float(shelfTop) {
                steer = buddyClampF((px - cx) * 0.006, -0.3, 0.3)
            } else {
                steer = sin(Float(frameN) * 0.07) * 0.08
            }
            for i in ids { impulse(i, steer, 0) }
            let flame: UInt32 = rng.chance(50) ? 0xFFD23C : 0xFF8A3C
            spark(pts[4].x + Float(rng.range(-3, 3)), pts[4].y + 10, Float(rng.range(-8, 8)) / 10, 2.4, 22, 5, flame, 3.5, 0.02)
            if rocketT == 0 {
                play(.pickup)
                addBurst(pts[4].x, pts[4].y, "POOF!", 0xFFFFFF)
                starPop(pts[4].x, pts[4].y, 8, 0xFFE066)
            }
        }
    }

    func fanForce() {
        var i: Int = 0
        while i < pts.count {
            let dx: Float = pts[i].x - holdX
            let dy: Float = pts[i].y - holdY
            let d: Float = max(sqrt(dx * dx + dy * dy), 20)
            if d < 170 {
                let f: Float = 1 - d / 170
                impulse(i, dx / d * 0.6 * f, dy / d * 0.6 * f)
            }
            i += 1
        }
        if frameN % 3 == 0 {
            var dx: Float = cx - holdX
            var dy: Float = cy - holdY
            let d: Float = max(1, sqrt(dx * dx + dy * dy))
            dx /= d
            dy /= d
            spark(holdX + dx * 14, holdY + dy * 14 + Float(rng.range(-8, 8)), dx * 5, dy * 5, 24, 7, 0xFFFFFF, 3, 0)
        }
        if frameN % 20 == 0 { play(.blip) }
    }

    func tickleForce() {
        let near = nearestPart(holdX, holdY)
        if near.1 > 30 { return }
        tickleActive = true
        let ph: Float = Float(frameN) * 0.55
        impulse(8, sin(ph) * 0.55, -0.1)
        impulse(10, -sin(ph) * 0.55, -0.1)
        impulse(12, sin(ph + 1.5) * 0.5, 0)
        impulse(14, -sin(ph + 1.5) * 0.5, 0)
        impulse(0, sin(ph * 0.7) * 0.3, 0)
        if frameN % 24 == 0 {
            var i: Int = 0
            while i < pts.count {
                impulse(i, 0, 1.4)
                i += 1
            }
        }
        expr = 1
        exprT = 12
        exprNext = 1
        idleT = 0
        meter += 0.28
        meterIdle = 0
        if meter >= 100 { party() }
        if frameN % 36 == 0 {
            let words: [String] = ["HAHAHA!", "HEE HEE!", "TEE HEE!", "GIGGLE!"]
            bubble = words[rng.int(words.count)]
            bubbleT = 40
        }
        if frameN % 14 == 0 {
            play(.blip)
            spark(pts[0].x + Float(rng.range(-12, 12)), pts[0].y - 14, 0, -1, 30, 8, 0xFF8FB8, 5, -0.01)
        }
    }

    func statTickleTick() {
        tickleT += 1
        if tickleT % 60 == 0 {
            statTickle = min(99999, statTickle + 1)
            goalProgress(5, 1)
        }
    }

    func magnetForce() {
        var i: Int = 0
        while i < pts.count {
            let dx: Float = holdX - pts[i].x
            let dy: Float = holdY - pts[i].y
            let d: Float = max(sqrt(dx * dx + dy * dy), 8)
            if d < 230 {
                let f: Float = 1 - d / 230
                impulse(i, dx / d * 0.75 * f, dy / d * 0.75 * f)
                if d < 34 {
                    pts[i].ox = pts[i].x - (pts[i].x - pts[i].ox) * 0.88
                    pts[i].oy = pts[i].y - (pts[i].y - pts[i].oy) * 0.88
                }
            }
            i += 1
        }
        if frameN % 4 == 0 {
            let ang: Float = Float(rng.int(628)) / 100
            spark(holdX + cos(ang) * 26, holdY + sin(ang) * 26, -cos(ang) * 1.6, -sin(ang) * 1.6, 14, 5, 0xFF9CB0, 3, 0)
        }
        if frameN % 30 == 0 { play(.pickup) }
        idleT = 0
    }

    // MARK: Goals

    func goalProgress(_ id: Int, _ n: Int) {
        if id < 0 || id >= BuddyData.goalTargets.count { return }
        var s: Int = 0
        while s < goalIds.count {
            if goalIds[s] == id {
                goalProg[s] += n
                if goalProg[s] >= BuddyData.goalTargets[id] {
                    completeGoal(s)
                }
            }
            s += 1
        }
    }

    func completeGoal(_ s: Int) {
        if s < 0 || s >= goalIds.count { return }
        stars = min(9999, stars + 1)
        cash = min(999999, cash + 25)
        statGoals = min(99999, statGoals + 1)
        var reward: String = "+1 STAR +25"
        if statGoals % 2 == 0 {
            gold = min(9999, gold + 1)
            reward = "+1 STAR +1 GOLD"
        }
        showBanner("GOAL DONE!", 0x9BF28A)
        showToast(BuddyData.goalTexts[goalIds[s]] + "  " + reward)
        confettiBurst(160, 100, 50)
        play(.win)
        let count: Int = BuddyData.goalTargets.count
        var next: Int = (goalIds[s] + 1) % count
        var guardN: Int = 0
        while goalIds.contains(next) && guardN < count {
            next = (next + 1) % count
            guardN += 1
        }
        goalIds[s] = next
        goalProg[s] = 0
        if next == 2 { toyUsedMask = 0 }
    }

    // MARK: Saving

    func wr32(_ o: inout [UInt8], _ v: Int) {
        let c: Int = max(0, min(0x7FFF_FFFF, v))
        o.append(UInt8(c & 255))
        o.append(UInt8((c >> 8) & 255))
        o.append(UInt8((c >> 16) & 255))
        o.append(UInt8((c >> 24) & 255))
    }

    func rd32(_ b: [UInt8], _ i: Int) -> Int {
        if i < 0 || i + 3 >= b.count { return 0 }
        let lo: Int = Int(b[i]) | (Int(b[i + 1]) << 8) | (Int(b[i + 2]) << 16)
        let hi: Int = Int(b[i + 3] & 0x7F) << 24
        return lo | hi
    }

    func rd8(_ b: [UInt8], _ i: Int) -> Int {
        if i < 0 || i >= b.count { return 0 }
        return Int(b[i])
    }

    func buildSave() -> [UInt8] {
        var o: [UInt8] = []
        o.append(2)
        wr32(&o, cash)
        wr32(&o, stars)
        wr32(&o, gold)
        wr32(&o, toysOwned)
        o.append(UInt8(roomsOwned & 255))
        wr32(&o, hatsOwned)
        o.append(UInt8(scarvesOwned & 255))
        o.append(UInt8(max(0, min(255, selHat))))
        o.append(UInt8(max(0, min(255, selScarf))))
        o.append(UInt8(max(0, min(255, selRoom))))
        o.append(UInt8(max(0, min(255, selToy))))
        var i: Int = 0
        while i < 4 {
            o.append(UInt8(max(0, min(255, goalIds[i]))))
            i += 1
        }
        i = 0
        while i < 4 {
            o.append(UInt8(max(0, min(255, goalProg[i]))))
            i += 1
        }
        wr32(&o, toyUsedMask)
        wr32(&o, statBounces)
        wr32(&o, statFlings)
        wr32(&o, statParties)
        wr32(&o, statPies)
        wr32(&o, statTickle)
        wr32(&o, statGoals)
        wr32(&o, statBestCombo)
        wr32(&o, statSpins)
        wr32(&o, statPhotos)
        return o
    }

    func loadSave(_ bytes: [UInt8]) {
        if bytes.count < 40 || bytes.count > 3900 { return }
        if bytes[0] != 2 { return }
        cash = min(999999, rd32(bytes, 1))
        stars = min(9999, rd32(bytes, 5))
        gold = min(9999, rd32(bytes, 9))
        let allToys: Int = (1 << BuddyData.toyCount) - 1
        toysOwned = (rd32(bytes, 13) & allToys) | 15
        roomsOwned = (rd8(bytes, 17) & 0x7F) | 1
        hatsOwned = (rd32(bytes, 18) & 0x3FF) | 3
        scarvesOwned = (rd8(bytes, 22) & 0x7F) | 1
        selHat = max(0, min(BuddyData.hatNames.count - 1, rd8(bytes, 23)))
        selScarf = max(0, min(BuddyData.scarfNames.count - 1, rd8(bytes, 24)))
        selRoom = max(0, min(BuddyData.roomNames.count - 1, rd8(bytes, 25)))
        selToy = max(0, min(BuddyData.toyCount - 1, rd8(bytes, 26)))
        if (hatsOwned >> selHat) & 1 == 0 { selHat = 1 }
        if (scarvesOwned >> selScarf) & 1 == 0 { selScarf = 0 }
        if (roomsOwned >> selRoom) & 1 == 0 { selRoom = 0 }
        if (toysOwned >> selToy) & 1 == 0 { selToy = 0 }
        let pool: Int = BuddyData.goalTargets.count
        var ids: [Int] = []
        var i: Int = 0
        while i < 4 {
            var g: Int = rd8(bytes, 27 + i) % pool
            var guardN: Int = 0
            while ids.contains(g) && guardN < pool {
                g = (g + 1) % pool
                guardN += 1
            }
            ids.append(g)
            i += 1
        }
        goalIds = ids
        var prog: [Int] = []
        i = 0
        while i < 4 {
            let target: Int = BuddyData.goalTargets[goalIds[i]]
            prog.append(max(0, min(target - 1, rd8(bytes, 31 + i))))
            i += 1
        }
        goalProg = prog
        toyUsedMask = rd32(bytes, 35) & allToys
        statBounces = min(99_999_999, rd32(bytes, 39))
        statFlings = min(99_999_999, rd32(bytes, 43))
        statParties = min(99_999_999, rd32(bytes, 47))
        statPies = min(99_999_999, rd32(bytes, 51))
        statTickle = min(99_999_999, rd32(bytes, 55))
        statGoals = min(99_999_999, rd32(bytes, 59))
        statBestCombo = min(99_999, rd32(bytes, 63))
        statSpins = min(99_999_999, rd32(bytes, 67))
        statPhotos = min(99_999_999, rd32(bytes, 71))
        giftT = 1500
        bgRoom = -1
        setupProps()
    }
}

extension Cartridge {
    static let buddyBounce64 = Cartridge(
        id: "buddybounce64", title: "BUDDY BOUNCE", genre: "Sandbox",
        blurb: "A giggly burlap buddy tumbles around a toy room. Fling it, tickle it, bonk it with foam toys, launch it with a slingshot, collect cash and gold bars, and dress it up. Totally gentle and silly.",
        controls: "TOUCH to use toys, drag the buddy to fling it. D-PAD cursor, A use toy, B grab, SELECT next toy.",
        era: .n64, labelTop: 0xFF9A3C, labelBottom: 0x7A3CD8, factory: { BuddyBounce64() })
}
