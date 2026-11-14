#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

extension LanternQuest {
    // MARK: Text helpers

    func wrapText(_ s: String, _ maxChars: Int) -> [String] {
        var lines: [String] = []
        var cur = ""
        for w in s.split(separator: " ") {
            let word = String(w)
            if cur.isEmpty {
                cur = word
            } else if cur.count + 1 + word.count <= maxChars {
                cur += " " + word
            } else {
                lines.append(cur)
                cur = word
            }
        }
        if !cur.isEmpty { lines.append(cur) }
        return lines
    }

    func say(_ speaker: String, _ texts: [String], after: (() -> Void)? = nil) {
        var pages: [[String]] = []
        for t in texts {
            let lines = wrapText(t, 34)
            var i = 0
            while i < lines.count {
                let end = min(i + 3, lines.count)
                pages.append(Array(lines[i..<end]))
                i += 3
            }
        }
        if pages.isEmpty { pages = [["..."]] }
        dialog = LanternDialog(speaker: speaker, pages: pages, page: 0, shown: 0)
        dialogAfter = after
        mode = .text
    }

    func updateText(_ inp: InputState, _ tapped: Bool) {
        updateWick()
        let adv: Bool = inp.aPressed || tapped
        let total = dialog.total
        if dialog.shown < total {
            if frame % 2 == 0 {
                dialog.shown += 1
                if dialog.shown % 4 == 0 { play(.step) }
            }
            if adv { dialog.shown = total }
        } else if adv {
            dialog.page += 1
            dialog.shown = 0
            if dialog.page >= dialog.pages.count {
                mode = .play
                let a = dialogAfter
                dialogAfter = nil
                if let f = a { f() }
            } else {
                play(.blip)
            }
        }
    }

    func drawDialog(_ c: Canvas) {
        c.cameraX = 0
        c.cameraY = 0
        c.fillRect(4, 98, 152, 42, LanternC.hud)
        c.strokeRect(4, 98, 152, 42, LanternC.gold)
        c.strokeRect(5, 99, 150, 40, LanternC.out)
        if !dialog.speaker.isEmpty {
            let w = c.textWidth(dialog.speaker) + 6
            c.fillRect(8, 92, w, 9, LanternC.gold)
            c.text(dialog.speaker, 11, 94, LanternC.out)
        }
        if dialog.page < dialog.pages.count {
            var left = dialog.shown
            var y = 105
            for line in dialog.pages[dialog.page] {
                if left <= 0 { break }
                var show = line
                if left < line.count { show = String(line.prefix(left)) }
                c.text(show, 10, y, LanternC.white)
                left -= line.count
                y += 9
            }
        }
        if dialog.shown >= dialog.total && (frame / 15) % 2 == 0 {
            c.fillRect(146, 132, 5, 3, LanternC.gold)
            c.fillRect(147, 135, 3, 1, LanternC.gold)
        }
    }

    // MARK: Title

    func updateTitle(_ inp: InputState, _ tapped: Bool, _ tx: Int, _ ty: Int) {
        if hasSave {
            if inp.upPressed || inp.downPressed || inp.leftPressed || inp.rightPressed {
                titleCursor = 1 - titleCursor
                play(.select)
            }
        }
        var confirm = inp.aPressed || inp.startPressed
        if tapped {
            if hasSave {
                let row = ty >= 108 ? 1 : 0
                if ty >= 90 {
                    if row == titleCursor { confirm = true } else { titleCursor = row; play(.select) }
                }
            } else {
                confirm = true
            }
        }
        if confirm {
            let fresh: Bool = hasSave ? titleCursor == 1 : true
            beginGame(fresh)
        }
    }

    func beginGame(_ fresh: Bool) {
        hero = LanternHero()
        projs.removeAll()
        parts.removeAll()
        if fresh {
            save = LanternSave()
            save.started = true
            hasSave = true
            save.setFlag(LanternFlag.wokeUp)
            mode = .play
            enterRoomDirect(1, 0, 0, 4, 4)
            say("WICK", ["Mmm... wake up, sleepyhead! It is me, Wick, a little lantern spirit.",
                         "The great Lantern that lights our valley went out! Its six Sparks scattered far and wide, and you are the hero who can find them.",
                         "Walk with the D-pad or hold your finger on the screen. Open the chest by the bed: face it and press A, or just tap it."])
        } else {
            save.hp = save.maxHp
            mode = .play
            enterRoomDirect(save.safeArea, save.safeGx, save.safeGy, save.safeTx, save.safeTy)
            say("WICK", ["Welcome back! I kept your lantern warm. Let us find those Sparks."])
        }
    }

    func drawTitle(_ c: Canvas) {
        c.clear(LanternC.waterL)
        c.fillCircle(30, 118, 44, LanternC.fol2)
        c.fillCircle(124, 126, 52, LanternC.fol1)
        c.fillCircle(80, 140, 60, LanternC.g1)
        c.fillRect(0, 124, 160, 20, LanternC.g0)
        c.fillRect(70, 124, 20, 20, LanternC.path)
        // stars
        var i = 0
        while i < 14 {
            let sx = (i * 37 + 11) % 160
            let sy = (i * 23 + 5) % 70
            if (frame / 20 + i) % 3 != 0 { c.setPixel(sx, sy, LanternC.white) }
            i += 1
        }
        let pulse: Int = (frame / 6) % 4
        c.strokeCircle(80, 82, 22 + pulse, LanternC.white)
        c.strokeCircle(80, 82, 26 + pulse, LanternC.gold)
        c.fillCircle(80, 82, 18, LanternC.white)
        c.fillRect(72, 66, 16, 4, LanternC.out)
        c.fillRect(70, 70, 20, 24, LanternC.out)
        c.fillRect(72, 72, 16, 20, LanternC.gold)
        c.fillRect(77, 76, 6, 12, LanternC.white)
        c.fillRect(75, 94, 10, 3, LanternC.out)
        c.hline(76, 61, 8, LanternC.out)
        c.vline(76, 61, 6, LanternC.out)
        c.vline(83, 61, 6, LanternC.out)
        titleText(c, "LANTERN", 6)
        titleText(c, "QUEST", 22)
        if hasSave {
            drawTitleButton(c, "CONTINUE", 96, titleCursor == 0)
            drawTitleButton(c, "NEW GAME", 111, titleCursor == 1)
            let mins = save.playFrames / 3600
            c.textCentered("PLAYED " + String(mins / 60) + "H " + String(mins % 60) + "M", y: 130, LanternC.out)
        } else {
            drawTitleButton(c, "PRESS A OR START", 104, true)
        }
    }

    func titleText(_ c: Canvas, _ s: String, _ y: Int) {
        let w = c.textWidth(s, scale: 2)
        let x = (160 - w) / 2
        for dy in -1...1 {
            for dx in -1...1 {
                if dx != 0 || dy != 0 { c.text(s, x + dx, y + dy, LanternC.out, scale: 2) }
            }
        }
        c.text(s, x, y, LanternC.gold, scale: 2)
    }

    func drawTitleButton(_ c: Canvas, _ s: String, _ y: Int, _ sel: Bool) {
        let w = c.textWidth(s) + 14
        let x = (160 - w) / 2
        c.fillRect(x, y - 3, w, 13, LanternC.hud)
        c.strokeRect(x, y - 3, w, 13, sel ? LanternC.gold : LanternC.grayD)
        c.textCentered(s, y: y, sel ? LanternC.white : LanternC.grayL)
    }

    // MARK: Item get

    func updateGet(_ inp: InputState, _ tapped: Bool) {
        updateWick()
        getTimer -= 1
        if getTimer <= 0 || ((inp.aPressed || tapped) && getTimer < 30) {
            mode = .play
            var texts: [String] = ["You got " + getTitle + "!"]
            for l in getLines { texts.append(l) }
            for l in getAfterLines { texts.append(l) }
            let who: String = getAfterLines.isEmpty ? "" : getAfterSpeaker
            getAfterLines = []
            say(who, texts)
        }
    }

    func drawGet(_ c: Canvas) {
        c.cameraX = 0
        c.cameraY = 0
        let hx = Int(hero.x)
        let hy = Int(hero.y) + 16
        if let ic = getIcon {
            let bob: Int = (frame / 6) % 2
            if ic.width <= 8 {
                drawScaled(c, ic, hx + 2, hy - 18 - bob, 1, nil)
                c.strokeCircle(hx + 6, hy - 14 - bob, 7 + (frame / 4) % 3, LanternC.gold)
            }
        }
    }

    // MARK: Objective

    func stepDone(_ s: LanternStep) -> Bool {
        switch s.condKind {
        case 0: return save.flag(s.condArg)
        case 1: return (save.sparks >> clamp(s.condArg - 1, 0, 7)) & 1 == 1
        default: return save.has(s.condArg)
        }
    }

    func currentStep() -> LanternStep? {
        for s in LanternContent.story where !stepDone(s) { return s }
        return nil
    }

    func hintText() -> String {
        if let s = currentStep() { return s.hint }
        return "You have found every spark this valley holds so far! Explore, help folks and check the quest board. More gates open soon."
    }

    // MARK: Item menu

    func activeList() -> [LanternItem] {
        var out: [LanternItem] = []
        for b in 0..<64 {
            if let it = LanternContent.item(bit: b), it.active, save.has(b) { out.append(it) }
        }
        return out
    }

    func openMenu() {
        mode = .menu
        let list = activeList()
        menuCursor = 0
        var i = 0
        while i < list.count {
            if list[i].bit == save.equipped { menuCursor = i }
            i += 1
        }
        play(.pause)
    }

    func equip(_ it: LanternItem) {
        save.equipped = it.bit
        play(.confirm)
        mode = .play
    }

    func cellRect(_ i: Int) -> Box {
        return Box(12 + (i % 4) * 35, 31 + (i / 4) * 24, 32, 22)
    }

    func updateMenu(_ inp: InputState, _ tapped: Bool, _ tx: Int, _ ty: Int) {
        let list = activeList()
        if inp.selectPressed || inp.bPressed || inp.startPressed {
            mode = .play
            play(.pause)
            return
        }
        if !list.isEmpty {
            menuCursor = clamp(menuCursor, 0, list.count - 1)
            if inp.rightPressed { menuCursor = min(list.count - 1, menuCursor + 1); play(.select) }
            if inp.leftPressed { menuCursor = max(0, menuCursor - 1); play(.select) }
            if inp.downPressed { menuCursor = min(list.count - 1, menuCursor + 4); play(.select) }
            if inp.upPressed { menuCursor = max(0, menuCursor - 4); play(.select) }
            if inp.aPressed {
                equip(list[menuCursor])
                return
            }
        }
        if tapped {
            if Box(112, 17, 40, 12).contains(tx, ty) {
                mode = .play
                return
            }
            var i = 0
            while i < list.count {
                if cellRect(i).contains(tx, ty) {
                    if i == menuCursor {
                        equip(list[i])
                        return
                    }
                    menuCursor = i
                    play(.select)
                }
                i += 1
            }
        }
    }

    func drawMenu(_ c: Canvas) {
        c.cameraX = 0
        c.cameraY = 0
        c.fillRect(6, 16, 148, 126, LanternC.hud)
        c.strokeRect(6, 16, 148, 126, LanternC.gold)
        c.text("ITEMS", 12, 20, LanternC.gold)
        c.fillRect(112, 17, 40, 12, LanternC.grayD)
        c.strokeRect(112, 17, 40, 12, LanternC.grayL)
        c.text("CLOSE", 120, 21, LanternC.white)
        let list = activeList()
        if list.isEmpty {
            c.text("NO ITEMS YET.", 12, 40, LanternC.grayL)
        }
        var i = 0
        while i < list.count {
            let it = list[i]
            let r = cellRect(i)
            c.fillRect(r.x, r.y, r.w, r.h, LanternC.grayD)
            c.strokeRect(r.x, r.y, r.w, r.h, i == menuCursor ? LanternC.gold : LanternC.out)
            if i == menuCursor { c.strokeRect(r.x + 1, r.y + 1, r.w - 2, r.h - 2, LanternC.gold) }
            if let s = LanternArt.itemIcons[it.icon] { drawScaled(c, s, r.x + 8, r.y + 2, 2, nil) }
            if it.ammo == 1 { c.text(String(save.bombs), r.x + 3, r.y + 15, LanternC.white) }
            if it.ammo == 2 { c.text(String(save.arrows), r.x + 3, r.y + 15, LanternC.white) }
            if it.bit == save.equipped { c.text("B", r.x + 24, r.y + 15, LanternC.pink) }
            i += 1
        }
        if !list.isEmpty && menuCursor < list.count {
            let it = list[menuCursor]
            c.text(it.name, 12, 104, LanternC.gold)
            var y = 111
            for l in wrapText(it.desc, 34) {
                c.text(l, 12, y, LanternC.white)
                y += 7
            }
        }
        // passive items and progress
        var x = 12
        for pid in ["sword", "shield", "boots"] {
            if let it = LanternContent.item(pid) {
                let lv = save.itemLevel[clamp(it.bit, 0, 63)]
                if lv > 0, let s = LanternArt.itemIcons[it.icon] {
                    c.draw(s, x, 126)
                    if it.maxLevel > 1 { c.text("L" + String(lv), x + 9, 128, LanternC.white) }
                    x += 28
                }
            }
        }
        c.text("HEART " + String(save.pieces) + "/4", 98, 126, LanternC.white)
        c.text("SPARKS " + String(save.sparkCount()), 98, 133, LanternC.gold)
    }

    // MARK: Map and quest log

    func openMap() {
        mode = .map
        mapTab = 0
        play(.pause)
    }

    func updateMap(_ inp: InputState, _ tapped: Bool, _ tx: Int, _ ty: Int) {
        if inp.startPressed || inp.bPressed || inp.selectPressed {
            mode = .play
            play(.pause)
            return
        }
        if inp.leftPressed || inp.rightPressed {
            mapTab = 1 - mapTab
            play(.select)
        }
        if inp.aPressed && mapTab == 0 {
            mode = .play
            say("WICK", [hintText()])
            return
        }
        if tapped {
            if Box(4, 2, 40, 14).contains(tx, ty) { mapTab = 0; play(.select); return }
            if Box(48, 2, 56, 14).contains(tx, ty) { mapTab = 1; play(.select); return }
            if Box(112, 2, 44, 14).contains(tx, ty) { mode = .play; return }
            if mapTab == 0 && Box(4, 124, 74, 16).contains(tx, ty) {
                mode = .play
                say("WICK", [hintText()])
                return
            }
            if Box(82, 124, 74, 16).contains(tx, ty) { mode = .play; return }
        }
    }

    func drawTab(_ c: Canvas, _ x: Int, _ w: Int, _ s: String, _ on: Bool) {
        c.fillRect(x, 2, w, 12, on ? LanternC.gold : LanternC.grayD)
        c.strokeRect(x, 2, w, 12, LanternC.out)
        c.text(s, x + 5, 6, on ? LanternC.out : LanternC.white)
    }

    func drawMap(_ c: Canvas) {
        c.cameraX = 0
        c.cameraY = 0
        c.clear(LanternC.hud)
        drawTab(c, 4, 40, "MAP", mapTab == 0)
        drawTab(c, 48, 56, "QUESTS", mapTab == 1)
        drawTab(c, 112, 44, "CLOSE", false)
        if mapTab == 1 {
            drawQuestLog(c)
            drawButton(c, 82, 124, 74, "BACK")
            return
        }
        let blink: Bool = (frame / 15) % 2 == 0
        let step = currentStep()
        if room.areaNum == 0 {
            let cell = 10
            let ox = 40
            let oy = 20
            for gy in 0..<8 {
                for gx in 0..<8 {
                    let seen = save.seen(gy * 8 + gx)
                    let x = ox + gx * cell
                    let y = oy + gy * cell
                    c.fillRect(x, y, cell, cell, seen ? LanternC.grayL : LanternC.grayD)
                    c.strokeRect(x, y, cell, cell, LanternC.out)
                    if let s = step, s.areaNum == 0, s.gx == gx, s.gy == gy, blink {
                        c.fillRect(x + 2, y + 2, 6, 6, LanternC.gold)
                        c.strokeRect(x + 2, y + 2, 6, 6, LanternC.red)
                    }
                    if room.gx == gx && room.gy == gy && !blink {
                        c.fillRect(x + 3, y + 3, 4, 4, LanternC.red)
                    }
                }
            }
            c.textCentered(room.region.name, y: 102, LanternC.gold)
        } else if room.areaNum >= 101, let area = LanternContent.area(room.areaNum) {
            let cell = 14
            let ox = (160 - area.gw * cell) / 2
            let oy = 20
            let vb = area.visitBase
            let mapped: Bool = dungeonIndex >= 0 && (save.maps >> dungeonIndex) & 1 == 1
            for r in area.rooms {
                let seen = vb >= 0 && save.seen(vb + r.gy * area.gw + r.gx)
                if !seen && !mapped { continue }
                let x = ox + r.gx * cell
                let y = oy + r.gy * cell
                c.fillRect(x, y, cell, cell, seen ? LanternC.grayL : LanternC.grayD)
                c.strokeRect(x, y, cell, cell, LanternC.out)
                if mapped {
                    for line in r.ents where line.hasPrefix("boss ") {
                        c.fillRect(x + 4, y + 4, 6, 6, LanternC.red)
                    }
                }
                if room.gx == r.gx && room.gy == r.gy && !blink {
                    c.fillRect(x + 4, y + 4, 6, 6, LanternC.gold)
                }
            }
            c.textCentered(area.name, y: 102, LanternC.gold)
            c.text("KEYS " + String(dungeonIndex >= 0 ? save.keys[dungeonIndex] : 0), 6, 20, LanternC.white)
            if dungeonIndex >= 0 && (save.bigKeys >> dungeonIndex) & 1 == 1 { c.text("BIG KEY", 6, 28, LanternC.pink) }
        } else {
            c.textCentered("INDOORS", y: 50, LanternC.white)
            c.textCentered("GO OUTSIDE FOR THE MAP", y: 60, LanternC.grayL)
        }
        var y = 110
        c.text("GOAL:", 6, y, LanternC.gold)
        y += 7
        for l in wrapText(hintText(), 38) {
            if y > 120 { break }
            c.text(l, 6, y, LanternC.white)
            y += 6
        }
        drawButton(c, 4, 124, 74, "ASK WICK")
        drawButton(c, 82, 124, 74, "BACK")
    }

    func drawButton(_ c: Canvas, _ x: Int, _ y: Int, _ w: Int, _ s: String) {
        c.fillRect(x, y, w, 16, LanternC.grayD)
        c.strokeRect(x, y, w, 16, LanternC.gold)
        let tw = c.textWidth(s)
        c.text(s, x + (w - tw) / 2, y + 5, LanternC.white)
    }

    func drawQuestLog(_ c: Canvas) {
        var y = 20
        for q in LanternContent.quests {
            if y > 118 { break }
            let n = clamp(q.num, 0, 31)
            let st = save.qState[n]
            var status = "NEW"
            var col = LanternC.grayL
            if st == 1 {
                status = q.kind == 2 ? "OPEN" : String(min(save.qProg[n], q.goal)) + "/" + String(q.goal)
                col = LanternC.gold
                if questComplete(q) { status = "READY!"; col = LanternC.lime }
            }
            if st >= 2 { status = "DONE"; col = LanternC.lime }
            c.text(q.name, 6, y, st == 0 ? LanternC.grayL : LanternC.white)
            c.text(status, 154 - c.textWidth(status), y, col)
            y += 10
        }
        c.text("TALK TO FOLKS TO FIND QUESTS", 6, 112, LanternC.grayL)
    }

    // MARK: Drawing the world

    func blit(_ bg: Canvas, _ c: Canvas, _ ox: Int, _ oy: Int) {
        var sx0 = 0
        var sx1 = 160
        if ox < 0 { sx0 = -ox }
        if ox > 0 { sx1 = 160 - ox }
        if sx0 >= sx1 { return }
        for sy in 0..<128 {
            let dy = oy + sy
            if dy < 0 || dy >= 144 { continue }
            let srow = sy * 160
            let drow = dy * 160 + ox
            var sx = sx0
            while sx < sx1 {
                c.pixels[drow + sx] = bg.pixels[srow + sx]
                sx += 1
            }
        }
    }

    func drawRoomLayer(_ c: Canvas, _ r: LanternRoom, _ ox: Int, _ oy: Int) {
        let oyy = oy + 16
        blit(r.bg, c, ox, oyy)
        c.cameraX = -ox
        c.cameraY = -oyy
        let wf = (frame / 24) % 2
        for idx in 0..<80 {
            let t = r.tiles[idx]
            let px = (idx % 10) * 16
            let py = (idx / 10) * 16
            if t == LanternTile.water {
                c.draw(LanternArt.waterFrames[wf], px, py)
            } else if t == LanternTile.magma {
                c.draw(LanternArt.magmaFrames[wf], px, py)
            } else if t == LanternTile.torchLit {
                c.draw(LanternArt.flames[(frame / 4 + idx) % 2], px + 3, py - 5)
            }
        }
        for w in r.wares {
            let px = (w.idx % 10) * 16
            let py = (w.idx / 10) * 16
            if let s = rewardIcon(w.reward) { c.draw(s, px + 4, py + 1) }
            c.text(String(w.price), px + 8 - (String(w.price).count * 4) / 2, py - 6, LanternC.out)
            c.text(String(w.price), px + 7 - (String(w.price).count * 4) / 2, py - 7, LanternC.white)
        }
        for p in r.pickups {
            if p.life > 0 && p.life < 90 && (p.life / 4) % 2 == 0 { continue }
            let bob: Int = p.flag >= 0 ? Int(sin(Float(p.age) * 0.12) * 1.6) : 0
            drawPickupSprite(c, p, bob)
        }
        for b in r.blocks {
            let bx = Int(b.x)
            let by = Int(b.y)
            c.fillRect(bx, by, 16, 16, LanternC.out)
            c.fillRect(bx + 1, by + 1, 14, 14, b.heavy ? LanternC.red : LanternC.grayL)
            c.fillRect(bx + 3, by + 3, 10, 10, b.heavy ? LanternC.orange : LanternC.white)
            c.hline(bx + 1, by + 14, 14, LanternC.grayD)
            c.vline(bx + 14, by + 1, 14, LanternC.grayD)
        }
        for n in r.npcs {
            let s = LanternArt.npcSprite(n.npc.hair, n.npc.cloth)
            c.draw(s, n.x, n.y)
        }
        for e in r.enemies {
            drawEnemy(c, e)
            drawBossShadow(c, e)
        }
    }

    func drawPickupSprite(_ c: Canvas, _ p: LanternPickup, _ bob: Int) {
        guard let s = rewardIcon(p.reward) else { return }
        let x = Int(p.x)
        let y = Int(p.y) + bob
        if p.reward.hasPrefix("heartc") || p.reward.hasPrefix("spark") {
            drawScaled(c, s, x - 3, y - 3, 2, nil)
            c.strokeCircle(x + 4, y + 4, 9 + (frame / 5) % 2, LanternC.white)
        } else {
            c.fillRect(x + 1, y + 7, 6, 1, LanternC.pathD)
            c.draw(s, x, y)
        }
    }

    func drawHero(_ c: Canvas, _ x: Int, _ y: Int) {
        var spr: Sprite = LanternArt.heroDown[0]
        let f = (hero.anim / 8) % 2
        var flip = false
        switch hero.dir {
        case 0: spr = LanternArt.heroDown[f]
        case 1: spr = LanternArt.heroUp[f]
        case 2: spr = LanternArt.heroSide[f]
        default:
            spr = LanternArt.heroSide[f]
            flip = true
        }
        if mode == .getItem { spr = LanternArt.heroDown[1]; flip = false }
        if hero.invuln > 0 && mode == .play && (hero.invuln / 3) % 2 == 0 { return }
        c.draw(spr, x, y, flipX: flip)
    }

    func drawSword(_ c: Canvas) {
        if hero.swing < 3 || hero.swing > 15 { return }
        let t: Float = clamp(Float(15 - hero.swing) / 11, 0, 1)
        var base: Float = 1.5708
        switch hero.dir {
        case 0: base = 1.5708
        case 1: base = -1.5708
        case 2: base = 3.1416
        default: base = 0
        }
        let cx = Int(hero.x) + 6
        let cy = Int(hero.y) + 8
        let lv = max(1, itemLevel("sword"))
        let len: Float = 10 + Float(lv) * 1.5
        var k = 0
        while k < 3 {
            let tt: Float = max(0, t - Float(k) * 0.12)
            let a: Float = base + (tt - 0.5) * 2.4
            let ex = cx + Int(cos(a) * len)
            let ey = cy + Int(sin(a) * len)
            if k == 0 {
                c.line(cx + Int(cos(a) * 3), cy + Int(sin(a) * 3) + 1, ex, ey + 1, LanternC.out)
                c.line(cx + Int(cos(a) * 3) + 1, cy + Int(sin(a) * 3), ex + 1, ey, LanternC.out)
                c.line(cx + Int(cos(a) * 3), cy + Int(sin(a) * 3), ex, ey, LanternC.white)
                c.setPixel(ex, ey, LanternC.gold)
            } else {
                c.setPixel(ex, ey, k == 1 ? LanternC.grayL : LanternC.gold)
            }
            k += 1
        }
    }

    func drawProjs(_ c: Canvas) {
        for p in projs {
            let x = Int(p.x)
            let y = Int(p.y)
            switch p.kind {
            case LanternPK.arrow:
                c.line(x, y, x - Int(p.vx * 3), y - Int(p.vy * 3), LanternC.white)
                c.setPixel(x, y, LanternC.gold)
            case LanternPK.boomerang:
                if let s = LanternArt.itemIcons["boomerang"] {
                    let k = (frame / 3) % 4
                    c.draw(s, x - 4, y - 4, flipX: k == 1 || k == 2, flipY: k >= 2)
                }
            case LanternPK.bomb:
                if let s = LanternArt.itemIcons["bombs"] {
                    let blinking: Bool = p.life < 25 && (p.life / 3) % 2 == 0
                    c.draw(s, x - 4, y - 4, solid: blinking ? LanternC.red : nil)
                }
            case LanternPK.blast:
                let r: Int = 24 - p.life
                c.fillCircle(x, y, max(2, r), LanternC.orange)
                c.fillCircle(x, y, max(1, r - 5), LanternC.gold)
                c.strokeCircle(x, y, max(2, r + 2), LanternC.white)
            case LanternPK.flame:
                c.draw(LanternArt.flames[(frame / 3) % 2], x - 4, y - 6)
            case LanternPK.rock:
                c.fillCircle(x, y, 2, LanternC.out)
                c.fillCircle(x, y, 1, LanternC.grayL)
            case LanternPK.fire:
                c.fillCircle(x, y, 3, LanternC.orange)
                c.fillCircle(x, y, 1, LanternC.gold)
            case LanternPK.spore:
                c.fillCircle(x, y, 3, LanternC.purple)
                c.setPixel(x, y, LanternC.pink)
            case LanternPK.petal:
                c.fillCircle(x, y, 2, LanternC.out)
                c.fillCircle(x, y, 1, LanternC.pink)
            case LanternPK.sand:
                c.fillCircle(x, y, 2, LanternC.out)
                c.fillCircle(x, y, 1, LanternC.gold)
            default:
                c.fillCircle(x, y, 2, LanternC.white)
            }
        }
    }

    func drawParticles(_ c: Canvas) {
        for p in parts {
            let x = Int(p.x)
            let y = Int(p.y)
            if p.kind == 1 {
                c.setPixel(x, y, p.color)
                if p.life % 6 < 3 {
                    c.setPixel(x - 1, y, p.color)
                    c.setPixel(x + 1, y, p.color)
                    c.setPixel(x, y - 1, p.color)
                    c.setPixel(x, y + 1, p.color)
                }
            } else {
                c.setPixel(x, y, p.color)
                if p.life > 8 { c.setPixel(x + 1, y, p.color) }
            }
        }
    }

    func drawWick(_ c: Canvas) {
        let x = Int(wickX)
        let y = Int(wickY) + Int(sin(Float(wickBob) * 0.12) * 2)
        let s = LanternArt.wick[(wickBob / 12) % 2]
        c.draw(s, x, y)
        if (wickBob / 3) % 2 == 0 {
            c.setPixel(x - 2, y + 3, LanternC.white)
            c.setPixel(x + 9, y + 3, LanternC.white)
        }
    }

    func applyDarkness(_ c: Canvas, _ ox: Int, _ oy: Int) {
        var lx: [Int] = []
        var ly: [Int] = []
        var lr: [Int] = []
        lx.append(Int(heroCX) + ox)
        ly.append(Int(heroCY) + oy + 16)
        lr.append(hasItem("lantern") ? 36 : 20)
        lx.append(Int(wickX) + 4 + ox)
        ly.append(Int(wickY) + 4 + oy + 16)
        lr.append(14)
        for idx in 0..<80 where room.tiles[idx] == LanternTile.torchLit {
            lx.append((idx % 10) * 16 + 8 + ox)
            ly.append((idx / 10) * 16 + 8 + oy + 16)
            lr.append(26)
        }
        for p in projs where p.kind == LanternPK.flame {
            lx.append(Int(p.x) + ox)
            ly.append(Int(p.y) + oy + 16)
            lr.append(22)
        }
        let n = lx.count
        var full = [Int](repeating: 0, count: n)
        var soft = [Int](repeating: 0, count: n)
        for i in 0..<n {
            soft[i] = lr[i] * lr[i]
            full[i] = lr[i] * lr[i] * 6 / 10
        }
        let dark = UInt8(LanternC.hud)
        for y in 16..<144 {
            let base = y * 160
            for x in 0..<160 {
                var state = 0
                var i = 0
                while i < n {
                    let dx = x - lx[i]
                    let dy = y - ly[i]
                    let d2 = dx * dx + dy * dy
                    if d2 < full[i] { state = 2; break }
                    if d2 < soft[i] { state = 1 }
                    i += 1
                }
                if state == 2 { continue }
                if state == 1 && ((x + y) & 1) == 0 { continue }
                c.pixels[base + x] = dark
            }
        }
    }

    func drawWorld(_ c: Canvas) {
        var sx = 0
        var sy = 0
        if shake > 0 && mode != .scroll {
            let amp: Int = shake > 8 ? 2 : 1
            sx = ((frame % 3) - 1) * amp
            sy = (((frame / 2) % 3) - 1) * amp
        }
        if mode == .scroll {
            let t: Float = Float(scrollT) / 28
            let offX = Int(Float(160 * scrollDX) * t)
            let offY = Int(Float(128 * scrollDY) * t)
            drawRoomLayer(c, room, -offX, -offY)
            drawRoomLayer(c, nextRoom, 160 * scrollDX - offX, 128 * scrollDY - offY)
            c.cameraX = 0
            c.cameraY = -16
            let hx = scrollFromX + (scrollToX - scrollFromX) * t
            let hy = scrollFromY + (scrollToY - scrollFromY) * t
            drawHero(c, Int(hx), Int(hy))
            drawWick(c)
            return
        }
        drawRoomLayer(c, room, sx, sy)
        c.cameraX = -sx
        c.cameraY = -(sy + 16)
        drawHero(c, Int(hero.x), Int(hero.y))
        drawSword(c)
        drawProjs(c)
        drawParticles(c)
        drawWick(c)
        if room.dark { applyDarkness(c, sx, sy) }
    }

    // MARK: HUD

    func drawHUD(_ c: Canvas) {
        c.cameraX = 0
        c.cameraY = 0
        c.fillRect(0, 0, 160, 16, LanternC.hud)
        c.hline(0, 15, 160, LanternC.grayD)
        let hearts = save.maxHp / 2
        let lowBlink: Bool = save.hp <= 2 && (frame / 20) % 2 == 0
        for i in 0..<hearts {
            let col = i % 10
            let row = i / 10
            let x = 2 + col * 7
            let y = 1 + row * 7
            if save.hp >= (i + 1) * 2 {
                c.draw(LanternArt.heartFull, x, y, solid: lowBlink ? LanternC.white : nil)
            } else if save.hp == i * 2 + 1 {
                c.draw(LanternArt.heartHalf, x, y)
            } else {
                c.draw(LanternArt.heartEmpty, x, y)
            }
        }
        // B item slot
        c.fillRect(80, 1, 18, 14, LanternC.grayD)
        c.strokeRect(80, 1, 18, 14, LanternC.gold)
        if save.equipped >= 0, let it = LanternContent.item(bit: save.equipped), let s = LanternArt.itemIcons[it.icon] {
            c.draw(s, 82, 2)
            if it.ammo == 1 { c.text(String(save.bombs), 90, 9, LanternC.white) }
            if it.ammo == 2 { c.text(String(save.arrows), 90, 9, LanternC.white) }
        } else {
            c.text("B", 87, 5, LanternC.grayL)
        }
        // gems, keys, sparks
        c.draw(LanternArt.gem, 102, 2)
        c.text(String(save.gems), 111, 2, LanternC.white)
        let d = dungeonIndex
        if d >= 0 {
            c.draw(LanternArt.keySmall, 101, 8)
            c.text(String(save.keys[d]), 111, 9, LanternC.white)
            if (save.bigKeys >> d) & 1 == 1 { c.draw(LanternArt.keyBig, 122, 8) }
        } else {
            c.draw(LanternArt.spark, 101, 8)
            c.text(String(save.sparkCount()), 111, 9, LanternC.gold)
        }
        // minimap
        c.fillRect(142, 0, 18, 16, LanternC.out)
        let step = currentStep()
        let blink: Bool = (frame / 15) % 2 == 0
        if room.areaNum == 0 {
            for gy in 0..<8 {
                for gx in 0..<8 {
                    var col = save.seen(gy * 8 + gx) ? LanternC.grayL : LanternC.grayD
                    if let s = step, s.areaNum == 0, s.gx == gx, s.gy == gy, blink { col = LanternC.gold }
                    if room.gx == gx && room.gy == gy && !blink { col = LanternC.red }
                    c.fillRect(143 + gx * 2, gy * 2, 2, 2, col)
                }
            }
        } else if let area = LanternContent.area(room.areaNum), room.areaNum >= 101 {
            let cell = max(2, 16 / max(1, max(area.gw, area.gh)))
            let vb = area.visitBase
            for r in area.rooms {
                let seen = vb >= 0 && save.seen(vb + r.gy * area.gw + r.gx)
                var col = seen ? LanternC.grayL : LanternC.grayD
                if room.gx == r.gx && room.gy == r.gy && !blink { col = LanternC.red }
                c.fillRect(143 + r.gx * cell, r.gy * cell, cell - 1, cell - 1, col)
            }
        } else {
            c.fillRect(147, 5, 8, 7, LanternC.grayL)
            c.fillRect(146, 3, 10, 3, LanternC.red)
            c.fillRect(150, 8, 2, 4, LanternC.out)
        }
    }

    func drawMsg(_ c: Canvas) {
        let w = c.textWidth(msg) + 8
        let x = (160 - w) / 2
        c.fillRect(x, 20, w, 11, LanternC.hud)
        c.strokeRect(x, 20, w, 11, LanternC.gold)
        c.text(msg, x + 4, 23, LanternC.white)
    }

    func drawFade(_ c: Canvas) {
        var level = 0
        if fadeT < 12 { level = min(4, fadeT / 3 + 1) } else { level = max(0, 4 - (fadeT - 12) / 3) }
        if fadeT >= 24 { level = 0 }
        if level <= 0 { return }
        let dark = UInt8(LanternC.hud)
        for y in 0..<144 {
            let base = y * 160
            for x in 0..<160 {
                var th = 0
                switch ((y & 1) << 1) | (x & 1) {
                case 0: th = 1
                case 3: th = 2
                case 1: th = 4
                default: th = 3
                }
                if level >= th { c.pixels[base + x] = dark }
            }
        }
    }
}
