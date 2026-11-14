#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

extension LanternQuest {
    // MARK: Collision

    func heroTile(_ tx: Int, _ ty: Int) -> UInt8 {
        if tx >= 0 && tx < 10 && ty >= 0 && ty < 8 { return room.tiles[ty * 10 + tx] }
        if tx < 0 && ty >= 0 && ty < 8 { return room.nbL ? LanternTile.ground : LanternTile.wall }
        if tx >= 10 && ty >= 0 && ty < 8 { return room.nbR ? LanternTile.ground : LanternTile.wall }
        if ty < 0 && tx >= 0 && tx < 10 { return room.nbU ? LanternTile.ground : LanternTile.wall }
        if ty >= 8 && tx >= 0 && tx < 10 { return room.nbD ? LanternTile.ground : LanternTile.wall }
        return LanternTile.wall
    }

    func entityBlocked(_ b: Box) -> Bool {
        for bl in room.blocks {
            let bb = Box(Int(bl.x), Int(bl.y), 16, 16)
            if bb.intersects(b) { return true }
        }
        for n in room.npcs {
            let nb = Box(n.x, n.y, 12, 12)
            if nb.intersects(b) { return true }
        }
        return false
    }

    func heroBlocked(_ x: Float, _ y: Float) -> Bool {
        let bx = Int(x) + 2
        let by = Int(y) + 5
        let x0 = bx >> 4
        let y0 = by >> 4
        let x1 = (bx + 7) >> 4
        let y1 = (by + 6) >> 4
        var ty = y0
        while ty <= y1 {
            var tx = x0
            while tx <= x1 {
                if LanternTile.isSolid(heroTile(tx, ty)) { return true }
                tx += 1
            }
            ty += 1
        }
        return entityBlocked(Box(bx, by, 8, 7))
    }

    func setMsg(_ s: String) {
        msg = s
        msgTimer = 100
    }

    // MARK: Main play update

    func updatePlay(_ inp: InputState, _ tapped: Bool, _ tapX: Int, _ tapY: Int) {
        save.playFrames += 1
        if inp.startPressed { openMap(); return }
        if inp.selectPressed { openMenu(); return }
        if msgTimer > 0 { msgTimer -= 1 }
        if pendingBuyTimer > 0 { pendingBuyTimer -= 1 } else { pendingBuy = -1 }

        var mdx = inp.dx
        var mdy = inp.dy
        if mdx == 0 && mdy == 0 && touch.down && touch.startY >= 16 && touch.frames > 4 {
            let ddx: Float = Float(touch.x) - heroCX
            let ddy: Float = Float(touch.y - 16) - heroCY
            let l = LanternMath.length(ddx, ddy)
            if l >= 8 {
                aimX = touch.x
                aimY = touch.y - 16
                if abs(ddx) > abs(ddy) * 0.4 { mdx = ddx < 0 ? -1 : 1 }
                if abs(ddy) > abs(ddx) * 0.4 { mdy = ddy < 0 ? -1 : 1 }
            }
        }
        if tapped {
            handleTap(tapX, tapY)
            if mode != .play { return }
        }
        if inp.aPressed {
            doAction()
            if mode != .play { return }
        }
        if inp.bPressed {
            useEquipped()
            if mode != .play { return }
        }

        // hero timers
        if hero.invuln > 0 { hero.invuln -= 1 }
        if hero.swing > 0 {
            hero.swing -= 1
            if hero.swing <= 12 && hero.swing >= 4 { applySwordHits() }
        }
        if hero.pitCooldown > 0 { hero.pitCooldown -= 1 }

        if hero.kbT > 0 {
            hero.kbT -= 1
            let nx = hero.x + hero.kbx
            if !heroBlocked(nx, hero.y) { hero.x = nx }
            let ny = hero.y + hero.kby
            if !heroBlocked(hero.x, ny) { hero.y = ny }
            hero.kbx *= 0.82
            hero.kby *= 0.82
        } else {
            moveHero(mdx, mdy)
        }

        checkHazards()
        checkWarpsAndEdges()
        if mode != .play { return }

        updateBlocks()
        updateProjs()
        if mode != .play { return }
        updatePickups()
        if mode != .play { return }
        updateEnemies()
        updateParticles()
        updateRoomLogic()
        updateWick()
        if shake > 0 { shake -= 1 }
        if save.hp <= 2 && !save.flag(LanternFlag.tutorialLow) && mode == .play {
            save.setFlag(LanternFlag.tutorialLow)
            say("WICK", ["Careful, hearts are low! Hearts hide in pots and grass. Smash pots and cut bushes to find them."])
        }
    }

    func moveHero(_ dx: Int, _ dy: Int) {
        hero.moving = dx != 0 || dy != 0
        if !hero.moving {
            hero.run = 0
            hero.push = 0
            hero.anim = 0
            return
        }
        if hero.swing == 0 {
            if dx != 0 && dy == 0 { hero.dir = dx < 0 ? 2 : 3 }
            else if dy != 0 && dx == 0 { hero.dir = dy < 0 ? 1 : 0 }
        }
        hero.anim += 1
        hero.run += 1
        var speed: Float = 1.25
        if hasItem("boots") && hero.run > 45 {
            speed = 2.0
            if hero.run % 4 == 0 { addParticle(heroCX, hero.y + 12, 0, -0.1, 10, LanternC.white, 0) }
        }
        if hero.swing > 0 { speed = 0.7 }
        var vx: Float = Float(dx) * speed
        var vy: Float = Float(dy) * speed
        if dx != 0 && dy != 0 {
            vx *= 0.7071
            vy *= 0.7071
        }
        var bumped = -1
        if vx != 0 {
            let nx = hero.x + vx
            if !heroBlocked(nx, hero.y) {
                hero.x = nx
            } else {
                bumped = vx < 0 ? 2 : 3
                if dy == 0 {
                    var k = 1
                    while k <= 5 {
                        if !heroBlocked(nx, hero.y - Float(k)) { hero.y -= 0.8; break }
                        if !heroBlocked(nx, hero.y + Float(k)) { hero.y += 0.8; break }
                        k += 1
                    }
                }
            }
        }
        if vy != 0 {
            let ny = hero.y + vy
            if !heroBlocked(hero.x, ny) {
                hero.y = ny
            } else {
                bumped = vy < 0 ? 1 : 0
                if dx == 0 {
                    var k = 1
                    while k <= 5 {
                        if !heroBlocked(hero.x - Float(k), ny) { hero.x -= 0.8; break }
                        if !heroBlocked(hero.x + Float(k), ny) { hero.x += 0.8; break }
                        k += 1
                    }
                }
            }
        }
        if bumped >= 0 {
            hero.run = min(hero.run, 20)
            bump(bumped)
        } else {
            hero.push = 0
            hero.pushDir = -1
        }
    }

    func bump(_ d: Int) {
        let v = LanternMath.dirVec(d)
        let px = Int(heroCX + v.0 * 9)
        let py = Int(heroCY + v.1 * 9)
        let tx = px >> 4
        let ty = py >> 4
        if tx >= 0 && tx < 10 && ty >= 0 && ty < 8 {
            let idx = ty * 10 + tx
            let t = room.tiles[idx]
            if t == LanternTile.lock { tryOpenLock(idx, false) }
            if t == LanternTile.bigDoor { tryOpenLock(idx, true) }
        }
        if hero.pushDir != d { hero.push = 0 }
        hero.pushDir = d
        for b in room.blocks {
            let bb = Box(Int(b.x) - 1, Int(b.y) - 1, 18, 18)
            if bb.contains(px, py) {
                hero.push += 1
                if hero.push >= 18 {
                    tryPushBlock(b, d)
                    hero.push = 0
                }
                return
            }
        }
        hero.push = 0
    }

    func groupIndex(_ idx: Int, _ kind: String) -> Int {
        var i = 0
        while i < room.groups.count {
            if room.groups[i].kind == kind && room.groups[i].cells.contains(idx) { return i }
            i += 1
        }
        return -1
    }

    func tryOpenLock(_ idx: Int, _ big: Bool) {
        let kind: String = big ? "blk" : "lock"
        let gi = groupIndex(idx, kind)
        if gi < 0 { return }
        let d = dungeonIndex
        if big {
            if d >= 0 && (save.bigKeys >> d) & 1 == 1 {
                openGroup(gi)
            } else if msgTimer == 0 {
                setMsg("NEEDS THE BIG KEY")
            }
        } else {
            if d >= 0 && save.keys[d] > 0 {
                save.keys[d] -= 1
                openGroup(gi)
            } else if msgTimer == 0 {
                setMsg("LOCKED. FIND A SMALL KEY")
            }
        }
    }

    func openGroup(_ gi: Int) {
        if gi < 0 || gi >= room.groups.count { return }
        let g = room.groups[gi]
        room.groups.remove(at: gi)
        for c in g.cells {
            setTile(room, c, LanternTile.ground)
            let px: Float = Float((c % 10) * 16 + 8)
            let py: Float = Float((c / 10) * 16 + 8)
            puff(px, py, 5, LanternC.grayL)
            revealHides(c)
        }
        save.setFlag(g.flag)
        play(.confirm)
        shake = max(shake, 3)
    }

    func tryPushBlock(_ b: LanternBlock, _ d: Int) {
        if b.moving { return }
        if b.heavy && !hasItem("gloves") {
            setMsg("TOO HEAVY!")
            return
        }
        let v = LanternMath.dirVec(d)
        let nx: Float = b.x + v.0 * 16
        let ny: Float = b.y + v.1 * 16
        if nx < 0 || ny < 0 || nx >= 160 || ny >= 128 { return }
        let tx = Int(nx) >> 4
        let ty = Int(ny) >> 4
        let t = room.tiles[ty * 10 + tx]
        if LanternTile.isSolid(t) || LanternTile.isHazard(t) { return }
        for o in room.blocks where o !== b {
            if Int(o.tx) == Int(nx) && Int(o.ty) == Int(ny) { return }
        }
        for n in room.npcs {
            if Box(n.x, n.y, 12, 12).intersects(Box(Int(nx), Int(ny), 16, 16)) { return }
        }
        b.tx = nx
        b.ty = ny
        b.moving = true
        play(.drop)
    }

    func updateBlocks() {
        for b in room.blocks {
            if b.moving {
                if b.x < b.tx { b.x = min(b.tx, b.x + 2) }
                if b.x > b.tx { b.x = max(b.tx, b.x - 2) }
                if b.y < b.ty { b.y = min(b.ty, b.y + 2) }
                if b.y > b.ty { b.y = max(b.ty, b.y - 2) }
                if b.x == b.tx && b.y == b.ty {
                    b.moving = false
                    pressSwitchAt(Int(b.x) / 16, Int(b.y) / 16)
                }
            }
        }
    }

    func pressSwitchAt(_ tx: Int, _ ty: Int) {
        if tx < 0 || ty < 0 || tx > 9 || ty > 7 { return }
        let idx = ty * 10 + tx
        if let g = room.switches[idx] {
            if room.tiles[idx] == LanternTile.switchUp {
                setTile(room, idx, LanternTile.switchDown)
                save.setFlag(g)
                play(.confirm)
            }
        }
    }

    // MARK: Hazards, warps, edges

    func checkHazards() {
        let fx = Int(hero.x) + 6
        let fy = Int(hero.y) + 9
        let t = heroTile(fx >> 4, fy >> 4)
        if LanternTile.isHazard(t) && hero.pitCooldown == 0 && hero.kbT == 0 {
            if save.hp > 1 { save.hp -= 1 }
            hero.x = hero.safeX
            hero.y = hero.safeY
            hero.invuln = 50
            hero.pitCooldown = 30
            play(.hurt)
            puff(heroCX, heroCY, 6, LanternC.white)
            setMsg("OOPS! WATCH YOUR STEP")
            return
        }
        if frame % 6 == 0 && hero.kbT == 0 {
            let bx = Int(hero.x) + 2
            let by = Int(hero.y) + 5
            var ok = true
            let pts: [(Int, Int)] = [(bx, by), (bx + 7, by), (bx, by + 6), (bx + 7, by + 6)]
            for p in pts {
                let tt = heroTile(p.0 >> 4, p.1 >> 4)
                if LanternTile.isHazard(tt) || LanternTile.isSolid(tt) { ok = false }
            }
            if ok && hero.x >= 0 && hero.x < 148 && hero.y >= 0 && hero.y < 112 {
                hero.safeX = hero.x
                hero.safeY = hero.y
            }
        }
    }

    func checkWarpsAndEdges() {
        let cx = heroCX
        let cy = heroCY
        let ftx = Int(cx) >> 4
        let fty = Int(hero.y + 9) >> 4
        for w in room.warps {
            if w.x == ftx && w.y == fty {
                startWarp(w.area, w.gx, w.gy, w.tx, w.ty)
                return
            }
        }
        if cx < 0 && room.nbL { startScroll(-1, 0); return }
        if cx >= 160 && room.nbR { startScroll(1, 0); return }
        if cy < 0 && room.nbU { startScroll(0, -1); return }
        if cy >= 128 && room.nbD { startScroll(0, 1); return }
    }

    func startWarp(_ area: Int, _ gx: Int, _ gy: Int, _ tx: Int, _ ty: Int) {
        mode = .fade
        fadeT = 0
        fadeTarget = [area, gx, gy, tx, ty]
        fadeIsDoor = true
        play(.confirm)
    }

    func updateFade() {
        fadeT += 1
        if fadeT == 12 && fadeTarget.count == 5 {
            enterRoomDirect(fadeTarget[0], fadeTarget[1], fadeTarget[2], fadeTarget[3], fadeTarget[4])
            if fadeIsDoor {
                save.safeArea = fadeTarget[0]
                save.safeGx = fadeTarget[1]
                save.safeGy = fadeTarget[2]
                save.safeTx = fadeTarget[3]
                save.safeTy = fadeTarget[4]
            }
        }
        if fadeT >= 24 { mode = .play }
    }

    func enterRoomDirect(_ areaNum: Int, _ gx: Int, _ gy: Int, _ tx: Int, _ ty: Int) {
        var r = buildRoom(areaNum, gx, gy)
        var useTx = tx
        var useTy = ty
        if r == nil {
            r = buildRoom(0, 3, 7)
            useTx = 2
            useTy = 5
        }
        guard let nr = r else { return }
        room = nr
        hero.x = Float(useTx * 16 + 2)
        hero.y = Float(useTy * 16 + 2)
        hero.safeX = hero.x
        hero.safeY = hero.y
        hero.kbT = 0
        hero.swing = 0
        hero.push = 0
        projs.removeAll()
        parts.removeAll()
        wickX = hero.x
        wickY = hero.y - 10
        onRoomEnter()
    }

    func onRoomEnter() {
        if let area = LanternContent.area(room.areaNum) {
            let vb = area.visitBase
            if vb >= 0 { save.markSeen(vb + room.gy * area.gw + room.gx) }
        }
        pendingBuy = -1
        if curTune != room.musicName { setTune(room.musicName) }
        if room.areaNum == 101 { save.setFlag(LanternFlag.enteredD1) }
        if room.areaNum == 102 { save.setFlag(LanternFlag.enteredD2) }
        if room.region.id == "forest" { save.setFlag(LanternFlag.enteredForest) }
        if room.dark && !save.flag(LanternFlag.tutorialDark) {
            save.setFlag(LanternFlag.tutorialDark)
            if hasItem("lantern") {
                say("WICK", ["It is dark in here! Your lantern lights a little circle. Press B with the lantern to make flames and light torches."])
            } else {
                say("WICK", ["It is dark in here. Stay close to me and be careful."])
            }
        }
    }

    func startScroll(_ dx: Int, _ dy: Int) {
        guard let nr = buildRoom(room.areaNum, room.gx + dx, room.gy + dy) else { return }
        nextRoom = nr
        scrollDX = dx
        scrollDY = dy
        scrollT = 0
        scrollFromX = hero.x
        scrollFromY = hero.y
        var tx = hero.x
        var ty = hero.y
        if dx > 0 { tx = 2 }
        if dx < 0 { tx = 146 }
        if dy > 0 { ty = 2 }
        if dy < 0 { ty = 112 }
        scrollToX = tx
        scrollToY = ty
        mode = .scroll
        projs.removeAll()
    }

    func updateScroll() {
        scrollT += 1
        updateWick()
        if scrollT >= 28 {
            room = nextRoom
            hero.x = scrollToX
            hero.y = scrollToY
            hero.safeX = hero.x
            hero.safeY = hero.y
            mode = .play
            hero.push = 0
            parts.removeAll()
            onRoomEnter()
        }
    }

    // MARK: Defeat and damage

    func onDefeat() {
        save.hp = save.maxHp
        hero.invuln = 90
        projs.removeAll()
        let a = save.safeArea
        let gx = save.safeGx
        let gy = save.safeGy
        let tx = save.safeTx
        let ty = save.safeTy
        say("WICK", ["Oh no! Hold on tight...", "There! Safe again. You keep all your items. Take a breath and try again!"], after: { [unowned self] in
            self.mode = .fade
            self.fadeT = 0
            self.fadeTarget = [a, gx, gy, tx, ty]
            self.fadeIsDoor = false
        })
    }

    func damageHero(_ amount: Int, _ srcX: Float, _ srcY: Float) {
        if hero.invuln > 0 || mode != .play { return }
        var dmg = amount
        if hasItem("shield") {
            let v = LanternMath.dirVec(hero.dir)
            let dot: Float = v.0 * (srcX - heroCX) + v.1 * (srcY - heroCY)
            if dot > 0 && dmg > 1 { dmg -= 1 }
        }
        save.hp -= dmg
        hero.invuln = 100
        play(.hurt)
        shake = 6
        let dx: Float = heroCX - srcX
        let dy: Float = heroCY - srcY
        let l = LanternMath.length(dx, dy)
        if l > 0.01 {
            hero.kbx = dx / l * 3.0
            hero.kby = dy / l * 3.0
        } else {
            hero.kbx = 0
            hero.kby = 3
        }
        hero.kbT = 8
        hero.swing = 0
        puff(heroCX, heroCY, 5, LanternC.red)
        if save.hp <= 0 {
            save.hp = 1
            onDefeat()
        }
    }

    // MARK: Actions

    func doAction() {
        let v = LanternMath.dirVec(hero.dir)
        let px = Int(heroCX + v.0 * 11)
        let py = Int(heroCY + v.1 * 11)
        if interactAt(px, py) { return }
        startSwing()
    }

    func startSwing() {
        if hero.swing > 0 { return }
        hero.swing = 16
        hero.swingId += 1
        play(.sword)
    }

    func handleTap(_ tx: Int, _ ty: Int) {
        if ty < 16 {
            if tx >= 142 { openMap(); return }
            if tx >= 79 && tx < 99 {
                if aimX >= 0 {
                    let ddx: Float = Float(aimX) - heroCX
                    let ddy: Float = Float(aimY) - heroCY
                    if LanternMath.length(ddx, ddy) > 4 { hero.dir = LanternMath.axisDir(ddx, ddy) }
                }
                useEquipped()
                return
            }
            openMenu()
            return
        }
        let fx = tx
        let fy = ty - 16
        aimX = fx
        aimY = fy
        let dx: Float = Float(fx) - heroCX
        let dy: Float = Float(fy) - heroCY
        let dist = LanternMath.length(dx, dy)
        if dist < 8 { return }
        if dist < 32 && interactAt(fx, fy) {
            hero.dir = LanternMath.axisDir(dx, dy)
            return
        }
        hero.dir = LanternMath.axisDir(dx, dy)
        startSwing()
    }

    func interactAt(_ px: Int, _ py: Int) -> Bool {
        for n in room.npcs {
            let nb = Box(n.x - 3, n.y - 3, 18, 18)
            if nb.contains(px, py) {
                talkNPC(n)
                return true
            }
        }
        let tx = px >> 4
        let ty = py >> 4
        if tx < 0 || ty < 0 || tx > 9 || ty > 7 { return false }
        let idx = ty * 10 + tx
        let t = room.tiles[idx]
        if t == LanternTile.sign {
            if let id = room.signs[idx], let lines = LanternContent.texts[id] {
                say("SIGN", lines)
                return true
            }
        }
        for b in room.boards where b == idx {
            boardTalk()
            return true
        }
        if t == LanternTile.chest {
            openChest(idx)
            return true
        }
        for w in room.wares where w.idx == idx {
            talkWare(w)
            return true
        }
        return false
    }

    func talkNPC(_ n: LanternNpcInst) {
        let dx: Float = heroCX - Float(n.x + 6)
        let dy: Float = heroCY - Float(n.y + 6)
        n.dir = LanternMath.axisDir(dx, dy)
        var lines: [String] = []
        if let t = n.npc.talk {
            lines = t(self)
        } else if !n.npc.quest.isEmpty {
            lines = questLines(n.npc.quest)
        } else {
            lines = n.npc.lines
        }
        if lines.isEmpty { lines = ["..."] }
        if mode == .play {
            say(n.npc.name, lines)
        } else if mode == .getItem {
            getAfterSpeaker = n.npc.name
            getAfterLines = lines
        }
    }

    func boardTalk() {
        var lines: [String] = ["HELP WANTED BOARD."]
        var any = false
        for q in LanternContent.quests {
            let n = clamp(q.num, 0, 31)
            let st = save.qState[n]
            if st >= 2 { continue }
            any = true
            var line = q.name + ": " + q.hint
            if st == 1 && q.kind != 2 { line += " (" + String(save.qProg[n]) + "/" + String(q.goal) + ")" }
            lines.append(line)
        }
        if !any { lines.append("Everything is done. Thank you, hero!") }
        say("BOARD", lines)
    }

    func openChest(_ idx: Int) {
        var i = 0
        while i < room.chests.count {
            if room.chests[i].idx == idx {
                let c = room.chests[i]
                if !c.shown || save.flag(c.flag) { return }
                save.setFlag(c.flag)
                setTile(room, idx, LanternTile.chestOpen)
                giveReward(c.reward, announce: true)
                return
            }
            i += 1
        }
    }

    func talkWare(_ w: LanternWare) {
        if pendingBuy == w.idx {
            pendingBuy = -1
            if save.gems >= w.price {
                save.gems -= w.price
                if w.flag >= 0 {
                    save.setFlag(w.flag)
                    var j = 0
                    while j < room.wares.count {
                        if room.wares[j].idx == w.idx { room.wares.remove(at: j); break }
                        j += 1
                    }
                }
                giveReward(w.reward, announce: true)
            } else {
                say("SHOP", ["Oh dear, not enough gems. Cut some grass and come back!"])
            }
        } else {
            pendingBuy = w.idx
            pendingBuyTimer = 240
            say("SHOP", [rewardName(w.reward) + " costs " + String(w.price) + " gems. Press A again to buy it."])
        }
    }

    // MARK: Item use

    func useEquipped() {
        if save.equipped < 0 { setMsg("PRESS SELECT FOR ITEMS"); return }
        guard let it = LanternContent.item(bit: save.equipped) else { return }
        if !save.has(it.bit) { return }
        _ = it.use(self)
    }

    func useBomb() -> Bool {
        if save.bombs <= 0 { setMsg("NO BOMBS"); return false }
        var n = 0
        for p in projs where p.kind == LanternPK.bomb { n += 1 }
        if n >= 2 { return false }
        let v = LanternMath.dirVec(hero.dir)
        let bx: Float = clamp(heroCX + v.0 * 12, 8, 152)
        let by: Float = clamp(heroCY + v.1 * 10 + 2, 8, 120)
        spawnProj(LanternPK.bomb, bx, by, 0, 0, 75, false, 0)
        save.bombs -= 1
        play(.drop)
        return true
    }

    func useBoomerang() -> Bool {
        for p in projs where p.kind == LanternPK.boomerang { return false }
        let v = LanternMath.dirVec(hero.dir)
        spawnProj(LanternPK.boomerang, heroCX + v.0 * 6, heroCY + v.1 * 6, v.0 * 3.0, v.1 * 3.0, 32, false, 1)
        play(.shoot)
        return true
    }

    func useBow() -> Bool {
        if save.arrows <= 0 { setMsg("NO ARROWS"); return false }
        var n = 0
        for p in projs where p.kind == LanternPK.arrow { n += 1 }
        if n >= 2 { return false }
        let v = LanternMath.dirVec(hero.dir)
        spawnProj(LanternPK.arrow, heroCX + v.0 * 8, heroCY + v.1 * 8, v.0 * 3.6, v.1 * 3.6, 55, false, 2)
        save.arrows -= 1
        play(.shoot)
        return true
    }

    func useLantern() -> Bool {
        for p in projs where p.kind == LanternPK.flame { return false }
        let v = LanternMath.dirVec(hero.dir)
        spawnProj(LanternPK.flame, heroCX + v.0 * 11, heroCY + v.1 * 11, v.0 * 0.6, v.1 * 0.6, 26, false, 1)
        play(.laser)
        return true
    }

    func useGloves() -> Bool {
        let v = LanternMath.dirVec(hero.dir)
        let px = Int(heroCX + v.0 * 11)
        let py = Int(heroCY + v.1 * 11)
        let tx = px >> 4
        let ty = py >> 4
        if tx < 0 || ty < 0 || tx > 9 || ty > 7 { return false }
        let idx = ty * 10 + tx
        if room.tiles[idx] != LanternTile.rock { return false }
        let gi = groupIndex(idx, "lift")
        if gi >= 0 {
            openGroup(gi)
        } else {
            setTile(room, idx, LanternTile.ground)
            puff(Float(tx * 16 + 8), Float(ty * 16 + 8), 6, LanternC.grayL)
            revealHides(idx)
            play(.thud)
        }
        return true
    }

    // MARK: Sword and tiles

    func swordBox() -> Box {
        let cx = Int(heroCX)
        let cy = Int(heroCY)
        switch hero.dir {
        case 0: return Box(cx - 7, cy - 2, 14, 16)
        case 1: return Box(cx - 7, cy - 14, 14, 16)
        case 2: return Box(cx - 14, cy - 7, 16, 14)
        default: return Box(cx - 2, cy - 7, 16, 14)
        }
    }

    func applySwordHits() {
        let sb = swordBox()
        let dmg = swordDamage()
        for e in room.enemies {
            if e.dead || e.hitSwing == hero.swingId { continue }
            let eb = Box(Int(e.x), Int(e.y), e.def.w, e.def.h)
            if eb.intersects(sb) {
                e.hitSwing = hero.swingId
                hurtEnemy(e, dmg, 0, heroCX, heroCY)
            }
        }
        var i = 0
        while i < projs.count {
            let p = projs[i]
            if p.hostile && (p.kind == LanternPK.rock || p.kind == LanternPK.fire || p.kind == LanternPK.snow) {
                if sb.contains(Int(p.x), Int(p.y)) {
                    puff(p.x, p.y, 4, LanternC.white)
                    play(.blip)
                    projs.remove(at: i)
                    continue
                }
            }
            i += 1
        }
        let x0 = sb.x >> 4
        let y0 = sb.y >> 4
        let x1 = (sb.x + sb.w - 1) >> 4
        let y1 = (sb.y + sb.h - 1) >> 4
        var ty = y0
        while ty <= y1 {
            var tx = x0
            while tx <= x1 {
                if tx >= 0 && tx < 10 && ty >= 0 && ty < 8 {
                    let idx = ty * 10 + tx
                    let t = room.tiles[idx]
                    if t == LanternTile.bush { cutBush(idx) }
                    if t == LanternTile.pot { breakPot(idx) }
                }
                tx += 1
            }
            ty += 1
        }
    }

    func tileCenter(_ idx: Int) -> (Float, Float) {
        return (Float((idx % 10) * 16 + 8), Float((idx / 10) * 16 + 8))
    }

    func cutBush(_ idx: Int) {
        let c = tileCenter(idx)
        setTile(room, idx, LanternTile.ground)
        for _ in 0..<6 {
            let a: Float = Float(rng.int(628)) / 100
            addParticle(c.0, c.1, cos(a) * 0.9, sin(a) * 0.9 - 0.3, 14, LanternC.lime, 0)
        }
        play(.blip)
        if !revealHides(idx) { randomDrop(c.0, c.1, 26, 14) }
    }

    func breakPot(_ idx: Int) {
        let c = tileCenter(idx)
        setTile(room, idx, LanternTile.ground)
        for _ in 0..<6 {
            let a: Float = Float(rng.int(628)) / 100
            addParticle(c.0, c.1, cos(a) * 1.0, sin(a) * 1.0 - 0.3, 16, LanternC.orange, 0)
        }
        play(.hit)
        if !revealHides(idx) { randomDrop(c.0, c.1, 25, 38) }
    }

    func randomDrop(_ x: Float, _ y: Float, _ gemChance: Int, _ heartChance: Int) {
        let r = rng.int(100)
        if r < heartChance {
            dropPickup("heal:2", x, y)
        } else if r < heartChance + gemChance {
            dropPickup("gems:1", x, y)
        }
    }

    @discardableResult
    func revealHides(_ idx: Int) -> Bool {
        var found = false
        var i = 0
        while i < room.hides.count {
            if room.hides[i].idx == idx {
                let h = room.hides[i]
                let c = tileCenter(idx)
                room.pickups.append(LanternPickup(h.reward, c.0 - 4, c.1 - 4, h.flag))
                room.hides.remove(at: i)
                found = true
                play(.confirm)
                continue
            }
            i += 1
        }
        return found
    }

    func burnTile(_ idx: Int) {
        if idx < 0 || idx >= 80 { return }
        let t = room.tiles[idx]
        let c = tileCenter(idx)
        if t == LanternTile.bush {
            cutBush(idx)
        } else if t == LanternTile.thorn {
            let gi = groupIndex(idx, "burn")
            if gi >= 0 {
                openGroup(gi)
            } else {
                setTile(room, idx, LanternTile.ground)
            }
            puff(c.0, c.1, 8, LanternC.orange)
            play(.explosion)
        } else if t == LanternTile.torch {
            setTile(room, idx, LanternTile.torchLit)
            if let g = room.torches[idx] { save.setFlag(g) }
            play(.powerup)
            puff(c.0, c.1 - 4, 6, LanternC.gold)
        }
    }

    func openEye(_ idx: Int) {
        if idx < 0 || idx >= 80 { return }
        if room.tiles[idx] == LanternTile.eye {
            setTile(room, idx, LanternTile.eyeOpen)
            if let g = room.eyes[idx] { save.setFlag(g) }
            play(.confirm)
            let c = tileCenter(idx)
            puff(c.0, c.1, 6, LanternC.lime)
        }
    }

    // MARK: Projectiles

    func shieldBlocks(_ px: Float, _ py: Float) -> Bool {
        if !hasItem("shield") { return false }
        let v = LanternMath.dirVec(hero.dir)
        let dot: Float = v.0 * (px - heroCX) + v.1 * (py - heroCY)
        return dot > 0
    }

    func explode(_ x: Float, _ y: Float) {
        play(.explosion)
        shake = max(shake, 8)
        puff(x, y, 14, LanternC.orange)
        puff(x, y, 8, LanternC.gold)
        projs.append(LanternProj(kind: LanternPK.blast, x: x, y: y, vx: 0, vy: 0, life: 14, hostile: false, dmg: 0))
        for e in room.enemies {
            if e.dead { continue }
            let d = LanternMath.length(e.cx - x, e.cy - y)
            if d < 28 { hurtEnemy(e, 4, 3, x, y) }
        }
        for idx in 0..<80 {
            let c = tileCenter(idx)
            let d = LanternMath.length(c.0 - x, c.1 - y)
            if d > 26 { continue }
            let t = room.tiles[idx]
            if t == LanternTile.bush { cutBush(idx) }
            else if t == LanternTile.pot { breakPot(idx) }
            else if t == LanternTile.eye { openEye(idx) }
            else if t == LanternTile.bombWall {
                let gi = groupIndex(idx, "bomb")
                if gi >= 0 { openGroup(gi) }
            }
        }
        let hd = LanternMath.length(heroCX - x, heroCY - y)
        if hd < 22 && hero.kbT == 0 {
            let dx: Float = heroCX - x
            let dy: Float = heroCY - y
            let l = max(0.1, LanternMath.length(dx, dy))
            hero.kbx = dx / l * 2.5
            hero.kby = dy / l * 2.5
            hero.kbT = 5
        }
    }

    func updateProjs() {
        var i = 0
        while i < projs.count {
            var p = projs[i]
            var remove = false
            p.life -= 1
            switch p.kind {
            case LanternPK.bomb:
                if p.life <= 0 {
                    explode(p.x, p.y)
                    remove = true
                }
            case LanternPK.blast:
                if p.life <= 0 { remove = true }
            case LanternPK.arrow:
                p.x += p.vx
                p.y += p.vy
                if p.x < 0 || p.y < 0 || p.x >= 160 || p.y >= 128 || p.life <= 0 {
                    remove = true
                } else {
                    let idx = (Int(p.y) >> 4) * 10 + (Int(p.x) >> 4)
                    let t = room.tiles[idx]
                    if t == LanternTile.eye { openEye(idx) }
                    if LanternTile.isSolid(t) && t != LanternTile.water {
                        remove = true
                        puff(p.x, p.y, 3, LanternC.white)
                    }
                }
                if !remove {
                    for e in room.enemies {
                        if e.dead { continue }
                        if Box(Int(e.x), Int(e.y), e.def.w, e.def.h).contains(Int(p.x), Int(p.y)) {
                            hurtEnemy(e, p.dmg, 1, p.x - p.vx * 3, p.y - p.vy * 3)
                            remove = true
                            break
                        }
                    }
                }
            case LanternPK.boomerang:
                if p.aux == 0 {
                    p.x += p.vx
                    p.y += p.vy
                    var turn = p.life <= 0
                    if p.x < 0 || p.y < 0 || p.x >= 160 || p.y >= 128 {
                        turn = true
                    } else {
                        let idx = (Int(p.y) >> 4) * 10 + (Int(p.x) >> 4)
                        let t = room.tiles[idx]
                        if t == LanternTile.eye { openEye(idx); turn = true }
                        else if LanternTile.isSolid(t) && t != LanternTile.water { turn = true }
                    }
                    if turn { p.aux = 1; play(.blip) }
                } else {
                    let dx: Float = heroCX - p.x
                    let dy: Float = heroCY - p.y
                    let l = LanternMath.length(dx, dy)
                    if l < 8 {
                        remove = true
                    } else {
                        p.vx = dx / l * 3.2
                        p.vy = dy / l * 3.2
                        p.x += p.vx
                        p.y += p.vy
                    }
                }
                if !remove {
                    for e in room.enemies {
                        if e.dead || e.invuln > 0 { continue }
                        if Box(Int(e.x) - 2, Int(e.y) - 2, e.def.w + 4, e.def.h + 4).contains(Int(p.x), Int(p.y)) {
                            hurtEnemy(e, 1, 2, p.x, p.y)
                            if p.aux == 0 { p.aux = 1 }
                        }
                    }
                    var k = 0
                    while k < room.pickups.count {
                        let pk = room.pickups[k]
                        if Box(Int(pk.x) - 3, Int(pk.y) - 3, 14, 14).contains(Int(p.x), Int(p.y)) {
                            room.pickups.remove(at: k)
                            collectPickup(pk)
                            continue
                        }
                        k += 1
                    }
                }
            case LanternPK.flame:
                p.x += p.vx
                p.y += p.vy
                let tx = Int(p.x) >> 4
                let ty = Int(p.y) >> 4
                if tx >= 0 && tx < 10 && ty >= 0 && ty < 8 { burnTile(ty * 10 + tx) }
                for e in room.enemies {
                    if e.dead || e.invuln > 0 { continue }
                    if Box(Int(e.x), Int(e.y), e.def.w, e.def.h).contains(Int(p.x), Int(p.y)) {
                        hurtEnemy(e, 1, 4, p.x, p.y)
                    }
                }
                if p.life <= 0 { remove = true }
            default:
                p.x += p.vx
                p.y += p.vy
                if p.x < -4 || p.y < -4 || p.x > 164 || p.y > 132 || p.life <= 0 {
                    remove = true
                } else {
                    let tx = Int(p.x) >> 4
                    let ty = Int(p.y) >> 4
                    if tx >= 0 && tx < 10 && ty >= 0 && ty < 8 {
                        let t = room.tiles[ty * 10 + tx]
                        if LanternTile.isSolid(t) && t != LanternTile.water { remove = true }
                    }
                }
                if !remove && mode == .play {
                    let pb = Box(Int(p.x) - 3, Int(p.y) - 3, 6, 6)
                    if pb.intersects(heroHurtBox()) {
                        if shieldBlocks(p.x, p.y) && hero.swing == 0 {
                            play(.thud)
                            puff(p.x, p.y, 4, LanternC.grayL)
                        } else {
                            damageHero(p.dmg, p.x, p.y)
                            if mode != .play { return }
                        }
                        remove = true
                    }
                }
            }
            if i >= projs.count { return }
            if remove {
                projs.remove(at: i)
            } else {
                projs[i] = p
                i += 1
            }
        }
    }

    // MARK: Pickups

    func collectPickup(_ p: LanternPickup) {
        if p.flag >= 0 { save.setFlag(p.flag) }
        giveReward(p.reward, announce: p.flag >= 0)
    }

    func updatePickups() {
        var i = 0
        let hb = heroHurtBox()
        while i < room.pickups.count {
            let p = room.pickups[i]
            p.age += 1
            if p.vy != 0 {
                p.y += p.vy
                p.vy += 0.15
                if p.vy > 1.3 { p.vy = 0 }
            }
            if p.life > 0 {
                p.life -= 1
                if p.life == 0 {
                    room.pickups.remove(at: i)
                    continue
                }
            }
            let pb = Box(Int(p.x) - 1, Int(p.y) - 1, 10, 10)
            if p.age > 6 && pb.intersects(hb) {
                room.pickups.remove(at: i)
                collectPickup(p)
                if mode != .play { return }
                continue
            }
            i += 1
        }
    }

    // MARK: Room logic

    func updateRoomLogic() {
        var i = 0
        while i < room.chests.count {
            let c = room.chests[i]
            if !c.shown && c.need >= 0 && save.flag(c.need) {
                room.chests[i].shown = true
                setTile(room, c.idx, save.flag(c.flag) ? LanternTile.chestOpen : LanternTile.chest)
                let cc = tileCenter(c.idx)
                puff(cc.0, cc.1, 8, LanternC.gold)
                play(.powerup)
            }
            i += 1
        }
        if !room.shut.isEmpty && frame % 6 == 0 {
            var all = true
            for g in room.shut where !save.flag(g) { all = false }
            if all {
                var opened = false
                for idx in 0..<80 where room.tiles[idx] == LanternTile.shutter {
                    setTile(room, idx, LanternTile.ground)
                    let c = tileCenter(idx)
                    puff(c.0, c.1, 4, LanternC.grayL)
                    opened = true
                }
                if opened { play(.confirm); shake = max(shake, 4) }
            }
        }
        if room.hadEnemies && room.clearFlag >= 0 && room.enemies.isEmpty && !save.flag(room.clearFlag) {
            save.setFlag(room.clearFlag)
            play(.confirm)
        }
        let ftx = Int(heroCX) >> 4
        let fty = Int(hero.y + 9) >> 4
        pressSwitchAt(ftx, fty)
        if let b = room.boss, !b.dead, b.spawnT == 0 {
            if curTune != "boss" { setTune("boss") }
        }
        if !room.fountains.isEmpty && frame % 20 == 0 && save.hp < save.maxHp {
            for idx in room.fountains {
                let c = tileCenter(idx)
                if LanternMath.length(c.0 - heroCX, c.1 - heroCY) < 30 {
                    save.hp = min(save.maxHp, save.hp + 1)
                    play(.pickup)
                    puff(heroCX, heroCY, 4, LanternC.pink)
                }
            }
        }
        if !room.fountains.isEmpty && frame % 8 == 0 {
            for idx in room.fountains {
                let c = tileCenter(idx)
                addParticle(c.0 + Float(rng.int(11)) - 5, c.1 + 4, 0, -0.5, 18, rng.chance(50) ? LanternC.pink : LanternC.white, 1)
            }
        }
    }

    func updateWick() {
        var tx: Float = hero.x + (hero.dir == 3 ? -8 : 14)
        var ty: Float = hero.y - 6
        if mode == .scroll {
            let t: Float = Float(scrollT) / 28
            tx = scrollFromX + (scrollToX - scrollFromX) * t + 14
            ty = scrollFromY + (scrollToY - scrollFromY) * t - 6
        }
        wickX += (tx - wickX) * 0.08
        wickY += (ty - wickY) * 0.08
        wickBob += 1
    }
}
