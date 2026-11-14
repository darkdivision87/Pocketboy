#!/usr/bin/env python3
"""Lantern Quest content builder and validator.

Authoring helper for Phase 1: it generates the 64-screen overworld, the indoor rooms and dungeons 1 and 2 as plain Swift data
(LanternOverworld.swift, LanternInteriors.swift, LanternDungeon1.swift, LanternDungeon2.swift) and then validates every map:
edges match, warps pair up, spawn tiles are walkable, every walkable tile / chest / key / boss is reachable under the item and key
rules, and every locked door has a key obtainable before it.

Usage:  python3 build_world.py            (writes the Swift files and validates)
        python3 build_world.py --check     (validate only, do not write)
"""
import random
import sys
import collections

OUT = '/home/user/pocketboy/Sources/PocketCore/Games/'
SOLID = set("#TbrwBHWRLKNeCtPFQycmahEI")
HAZ = set("oM")
VALID = set(".,p#TbrwoBHRDLKNeCtSPFQyvcmagh E M=IWd".replace(' ', ''))


def walk(ch):
    return ch not in SOLID and ch not in HAZ


class Room:
    def __init__(self, gx, gy, region, tiles, ents=None):
        self.gx = gx
        self.gy = gy
        self.region = region
        self.t = [list(r) for r in tiles]
        self.ents = list(ents or [])
        self.noenemy = False

    def rows(self):
        return [''.join(r) for r in self.t]


class Area:
    def __init__(self, num, aid, name, kind, gw, gh):
        self.num = num
        self.id = aid
        self.name = name
        self.kind = kind
        self.gw = gw
        self.gh = gh
        self.rooms = {}

    @property
    def flag_count(self):
        if self.num == 0:
            return 320
        if self.num < 100:
            return 192
        return 128


errors = []


def err(msg):
    errors.append(msg)


# ---------------------------------------------------------------------------------------------------------------------
# Overworld generation
# ---------------------------------------------------------------------------------------------------------------------
RG = ["FFHHHHEE",
      "FFHHHHEE",
      "FFSSSSEE",
      "FFSSSSEE",
      "LLWWWWDD",
      "LLWWWWDD",
      "LLMMMMDD",
      "LLMMMMDD"]
REGNAME = {'F': 'frost', 'H': 'hills', 'E': 'crater', 'S': 'marsh', 'L': 'lake', 'W': 'forest', 'D': 'dunes', 'M': 'meadow'}
BLOCK = {'F': 'T', 'H': '#', 'E': '#', 'S': 'T', 'L': 'w', 'W': 'T', 'D': 'T', 'M': 'T'}
DECOR = {
    'M': [('T', 5, 'c'), ('b', 8, 'c'), (',', 10, 'c'), ('P', 1, 'c'), ('w', 1, 'pond')],
    'W': [('T', 16, 'c'), ('b', 5, 'c'), (',', 6, 'c'), ('r', 2, 'c'), ('P', 1, 'c')],
    'D': [('T', 4, 'c'), ('#', 3, 'blob'), ('b', 2, 'c'), (',', 8, 'c')],
    'L': [('w', 3, 'blob'), ('T', 3, 'c'), ('b', 3, 'c'), (',', 6, 'c')],
    'H': [('#', 6, 'blob'), ('r', 3, 'c'), ('b', 5, 'c'), ('T', 3, 'c'), (',', 5, 'c')],
    'S': [('w', 3, 'blob'), ('T', 6, 'c'), ('b', 4, 'c'), (',', 8, 'c')],
    'F': [('T', 8, 'c'), ('#', 5, 'c'), ('w', 1, 'pond'), (',', 8, 'c')],
    'E': [('#', 7, 'blob'), ('M', 3, 'pool'), ('T', 3, 'c'), (',', 5, 'c')],
}
ENEMIES = {
    'M': ['blobbo', 'blobbo', 'blobbo', 'boarly', 'pebbler'],
    'W': ['blobbo', 'flutterbug', 'shellguard', 'beetlebit', 'pebbler', 'boarly'],
    'D': ['sandmole', 'crabby', 'boarly', 'spinwheel', 'sandmole'],
    'L': ['hopper', 'crabby', 'pebbler', 'blobbo', 'hopper'],
    'H': ['spinwheel', 'shellguard', 'boarly', 'flutterbug', 'pebbler'],
    'S': ['hopper', 'sporecap', 'beetlebit', 'wisp', 'hopper'],
    'F': ['frostling', 'pebbler', 'flutterbug', 'frostling', 'shellguard'],
    'E': ['embling', 'boarly', 'spinwheel', 'shellguard', 'embling'],
}

rnd = random.Random(20260301)
vm = {}
hm = {}


def rows_mask(n, rows):
    return [i in rows for i in range(n)]


def default_masks():
    for y in range(8):
        for x in range(7):
            if RG[y][x] == RG[y][x + 1]:
                w = rnd.choice([4, 6, 8])
                s = rnd.randint(0, 8 - w)
                vm[(x, y)] = rows_mask(8, range(s, s + w))
            else:
                vm[(x, y)] = [False] * 8
    for y in range(7):
        for x in range(8):
            if RG[y][x] == RG[y + 1][x]:
                w = rnd.choice([6, 8, 10])
                s = rnd.randint(0, 10 - w)
                hm[(x, y)] = rows_mask(10, range(s, s + w))
            else:
                hm[(x, y)] = [False] * 10


def special_masks():
    R34 = (3, 4)
    C45 = (4, 5)
    # cross-region links
    vm[(1, 1)] = rows_mask(8, R34)      # frost - hills
    vm[(5, 0)] = rows_mask(8, R34)      # hills - crater
    vm[(1, 2)] = rows_mask(8, R34)      # frost - marsh
    vm[(5, 3)] = rows_mask(8, R34)      # marsh - crater
    vm[(1, 6)] = rows_mask(8, R34)      # lake - meadow (gloves rocks)
    vm[(5, 6)] = rows_mask(8, R34)      # meadow - dunes (bomb wall)
    hm[(3, 1)] = rows_mask(10, C45)     # hills - marsh
    hm[(4, 3)] = rows_mask(10, C45)     # marsh - forest (gloves rocks)
    hm[(3, 5)] = rows_mask(10, C45)     # forest - meadow (thorns)
    hm[(1, 3)] = rows_mask(10, C45)     # frost - lake
    # meadow screens are generous
    for y in (6, 7):
        for x in (2, 3, 4):
            vm[(x, y)] = rows_mask(8, range(1, 7))
    for x in range(2, 6):
        hm[(x, 6)] = rows_mask(10, range(1, 9))


class Gen:
    def __init__(self):
        self.screens = {}
        self.nf = 40

    def flag(self):
        f = self.nf
        self.nf += 1
        return f


def ring_open(gx, gy, side, i):
    if side == 'W':
        return gx > 0 and vm[(gx - 1, gy)][i]
    if side == 'E':
        return gx < 7 and vm[(gx, gy)][i]
    if side == 'N':
        return gy > 0 and hm[(gx, gy - 1)][i]
    return gy < 7 and hm[(gx, gy)][i]


def bfs_cells(t, seeds, ok):
    seen = set(seeds)
    st = list(seeds)
    while st:
        x, y = st.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < 10 and 0 <= ny < 8 and (nx, ny) not in seen and ok(t[ny][nx]):
                seen.add((nx, ny))
                st.append((nx, ny))
    return seen


def make_screen(gx, gy):
    reg = RG[gy][gx]
    blk = BLOCK[reg]
    t = [['.'] * 10 for _ in range(8)]
    opens = []
    for x in range(10):
        for side, y in (('N', 0), ('S', 7)):
            if ring_open(gx, gy, side, x):
                opens.append((x, y))
            else:
                t[y][x] = blk
    for y in range(8):
        for side, x in (('W', 0), ('E', 9)):
            if ring_open(gx, gy, side, y):
                if (x, y) not in opens:
                    opens.append((x, y))
            else:
                t[y][x] = blk
    # corners are always blocked (diagonal leaks)
    for (x, y) in ((0, 0), (9, 0), (0, 7), (9, 7)):
        t[y][x] = blk
        if (x, y) in opens:
            opens.remove((x, y))
    s = Room(gx, gy, REGNAME[reg], [''.join(r) for r in t])
    s.t = t
    s.opens = opens
    return s


def connected(s):
    if not s.opens:
        return True
    reach = bfs_cells(s.t, [s.opens[0]], walk)
    return all(o in reach for o in s.opens)


def decorate(s, reg):
    for ch, count, kind in DECOR[reg]:
        for _ in range(count):
            if kind == 'pond' and rnd.random() > 0.25:
                continue
            for _try in range(25):
                cx = rnd.randint(1, 8)
                cy = rnd.randint(1, 6)
                cells = [(cx, cy)]
                if kind in ('blob', 'pond', 'pool'):
                    r = rnd.randint(1, 2)
                    cells = []
                    for dy in range(-r, r + 1):
                        for dx in range(-r, r + 1):
                            if dx * dx + dy * dy <= r * r + rnd.randint(0, 1):
                                cells.append((cx + dx, cy + dy))
                cells = [(x, y) for (x, y) in cells if 1 <= x <= 8 and 1 <= y <= 6]
                if not cells:
                    continue
                old = [(x, y, s.t[y][x]) for (x, y) in cells]
                for (x, y) in cells:
                    s.t[y][x] = ch
                if ch in ',':
                    break
                if connected(s):
                    break
                for (x, y, c0) in old:
                    s.t[y][x] = c0


def fill_pockets(s, reg):
    if not s.opens:
        return
    reach = bfs_cells(s.t, [s.opens[0]], walk)
    for y in range(1, 7):
        for x in range(1, 9):
            if walk(s.t[y][x]) and (x, y) not in reach and s.t[y][x] in '.,':
                s.t[y][x] = BLOCK[reg] if BLOCK[reg] != 'w' else 'T'


def build_overworld():
    default_masks()
    special_masks()
    g = Gen()
    S = {}
    for gy in range(8):
        for gx in range(8):
            s = make_screen(gx, gy)
            S[(gx, gy)] = s
    # village screens get no random decoration; others do
    village = {(3, 7), (4, 7), (5, 7), (2, 7)}
    for (gx, gy), s in S.items():
        reg = RG[gy][gx]
        if (gx, gy) in village:
            continue
        decorate(s, reg)
    return g, S


def stamp(s, x0, y0, rows):
    if not hasattr(s, 'locked'):
        s.locked = set()
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch != ' ':
                s.t[y0 + dy][x0 + dx] = ch
                s.locked.add((x0 + dx, y0 + dy))


def carve_to(s, cell):
    """Make sure `cell` is connected to the screen's open edges by carving through decoration."""
    reach = bfs_cells(s.t, s.opens[:1], walk)
    if cell in reach:
        return
    locked = getattr(s, 'locked', set())
    prev = {cell: None}
    q = collections.deque([cell])
    goal = None
    while q:
        c = q.popleft()
        if c in reach:
            goal = c
            break
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (c[0] + dx, c[1] + dy)
            if n in prev or not (1 <= n[0] <= 8 and 1 <= n[1] <= 6):
                if n not in prev and n in reach:
                    prev[n] = c
                    q.append(n)
                continue
            if n in locked and n not in reach:
                continue
            prev[n] = c
            q.append(n)
    if goal is None:
        err('cannot connect %s in screen %d,%d' % (cell, s.gx, s.gy))
        return
    c = goal
    while c is not None:
        if (1 <= c[0] <= 8 and 1 <= c[1] <= 6) and not walk(s.t[c[1]][c[0]]) and c not in locked:
            s.t[c[1]][c[0]] = '.'
        c = prev[c]


def put(s, x, y, ch):
    s.t[y][x] = ch


def clear_interior(s, ch='.'):
    for y in range(1, 7):
        for x in range(1, 9):
            s.t[y][x] = ch


def near_free(s, x, y, used, avoid=()):
    best = None
    for yy in range(1, 7):
        for xx in range(1, 9):
            if s.t[yy][xx] not in '.,p' or (xx, yy) in used:
                continue
            d = abs(xx - x) + abs(yy - y)
            if any(abs(xx - ax) + abs(yy - ay) < 2 for ax, ay in avoid):
                continue
            if best is None or d < best[0]:
                best = (d, xx, yy)
    if best is None:
        err('no free tile near %d,%d in screen %d,%d' % (x, y, s.gx, s.gy))
        return (x, y)
    used.add((best[1], best[2]))
    return (best[1], best[2])


def hand_features(g, S):
    used = collections.defaultdict(set)
    avoid = collections.defaultdict(list)
    ents = {k: v.ents for k, v in S.items()}

    def E(k, line):
        ents[k].append(line)

    def keep(k, x, y):
        used[k].add((x, y))
        avoid[k].append((x, y))

    # ---- warp helpers
    interior_back = {}

    def house(k, x, y, target, tx=4, ty=6):
        """3x2 house with door at x,y; warp to interior room target (gx,gy)."""
        s = S[k]
        stamp(s, x - 1, y - 1, ["RRR", "HdH"])
        put(s, x, y + 1, '.')
        E(k, 'warp %d %d 1 %d %d %d %d' % (x, y, target[0], target[1], tx, ty))
        interior_back[target] = (k, x, y + 1)
        keep(k, x, y + 1)

    def cave(k, x, y, target, kind, tx=4, ty=6):
        """Doorway D at x,y with a 3x3 rock frame. kind: open | bomb | burn"""
        s = S[k]
        if kind == 'open':
            stamp(s, x - 1, y - 1, ["###", "#D#", "#.#"])
            land = (x, y + 1)
            put(s, x, y + 2, '.')
        elif kind == 'bomb':
            stamp(s, x - 1, y - 1, ["###", "#D#", "#B#"])
            land = (x, y + 2)
            put(s, x, y + 2, '.')
            put(s, x, y + 3, '.')
            E(k, 'bomb %d %d %d' % (x, y + 1, g.flag()))
        else:
            stamp(s, x - 1, y - 1, ["###", "#D#", "#y#"])
            land = (x, y + 2)
            put(s, x, y + 2, '.')
            put(s, x, y + 3, '.')
            E(k, 'burn %d %d %d' % (x, y + 1, g.flag()))
        E(k, 'warp %d %d 1 %d %d %d %d' % (x, y, target[0], target[1], tx, ty))
        interior_back[target] = (k, land[0], land[1])
        keep(k, land[0], land[1])

    def gate(k, x, y, n):
        s = S[k]
        stamp(s, x - 1, y - 1, ["###", "#D#", "#.#"])
        put(s, x, y + 2, '.')
        E(k, 'gate %d %d %d' % (x, y, n))
        keep(k, x, y + 1)
        keep(k, x, y + 2)
        gates[n] = (k, x, y)

    gates = {}

    def sign(k, x, y, text):
        s = S[k]
        if s.t[y][x] not in '.,':
            x, y = near_free(s, x, y, used[k], avoid[k])
        put(s, x, y, 'e')
        E(k, 'sign %d %d %s' % (x, y, text))
        keep(k, x, y)

    def npc(k, nid, x, y):
        x, y = near_free(S[k], x, y, used[k], avoid[k])
        E(k, 'npc %s %d %d' % (nid, x, y))
        keep(k, x, y)

    def pick(k, reward, x, y):
        x, y = near_free(S[k], x, y, used[k], avoid[k])
        E(k, 'pick %d %d %s %d' % (x, y, reward, g.flag()))
        keep(k, x, y)

    # ---- masks gates on edges
    # thorns between meadow (3,6) and forest (3,5): screen (3,6) top cells
    s = S[(3, 6)]
    put(s, 4, 0, 'y'); put(s, 5, 0, 'y')
    put(s, 3, 0, 'T'); put(s, 6, 0, 'T')
    E((3, 6), 'burn 4 0 %d' % g.flag())
    # heavy rocks between forest (4,4) and marsh: screen (4,4) top cells
    s = S[(4, 4)]
    put(s, 4, 0, 'r'); put(s, 5, 0, 'r')
    E((4, 4), 'lift 4 0 %d' % g.flag())
    # heavy rocks between meadow (2,6) and lake: screen (2,6) west cells
    s = S[(2, 6)]
    put(s, 0, 3, 'r'); put(s, 0, 4, 'r')
    put(s, 0, 2, '#'); put(s, 0, 5, '#')
    E((2, 6), 'lift 0 3 %d' % g.flag())
    # cracked wall between meadow (5,6) and dunes
    s = S[(5, 6)]
    put(s, 9, 3, 'B'); put(s, 9, 4, 'B')
    put(s, 9, 2, '#'); put(s, 9, 5, '#')
    E((5, 6), 'bomb 9 3 %d' % g.flag())
    # the dunes side of that wall must be open
    for k in ((6, 6),):
        pass

    # ---- Village A (3,7)
    k = (3, 7)
    s = S[k]
    for x in range(10):
        pass
    clear_interior(s)
    for x in range(1, 9):
        put(s, x, 5, 'p')
    for y in range(0, 5):
        put(s, 4, y, 'p'); put(s, 5, y, 'p')
    put(s, 4, 6, 'p'); put(s, 5, 6, 'p')
    for (x, y) in ((1, 1), (8, 1), (2, 6), (7, 6), (1, 2), (8, 2)):
        put(s, x, y, ',')
    house(k, 2, 4, (0, 0))
    house(k, 7, 4, (1, 0))
    sign(k, 3, 2, 'village')
    npc(k, 'mira', 8, 6)
    npc(k, 'bobo', 3, 6)
    keep(k, 4, 5); keep(k, 5, 5)
    # ---- Village B (4,7)
    k = (4, 7)
    s = S[k]
    clear_interior(s)
    for x in range(1, 9):
        put(s, x, 5, 'p')
    for y in range(0, 5):
        put(s, 4, y, 'p'); put(s, 5, y, 'p')
    put(s, 4, 6, 'p'); put(s, 5, 6, 'p')
    for (x, y) in ((1, 1), (8, 1), (1, 6), (8, 6), (7, 2)):
        put(s, x, y, ',')
    house(k, 2, 4, (2, 0))
    house(k, 7, 4, (4, 0))
    put(s, 6, 2, 'e')
    E(k, 'board 6 2')
    keep(k, 6, 2)
    npc(k, 'wanda', 3, 6)
    # ---- Smithy (5,7)
    k = (5, 7)
    s = S[k]
    clear_interior(s)
    for x in range(0, 9):
        put(s, x, 5, 'p')
    for (x, y) in ((1, 1), (8, 1), (8, 5 - 1), (2, 6)):
        put(s, x, y, ',')
    house(k, 4, 4, (3, 0))
    npc(k, 'captain', 7, 4)
    pick(k, 'quest:chicks', 8, 2)
    # ---- Farm (2,7)
    k = (2, 7)
    s = S[k]
    clear_interior(s)
    for x in range(1, 9):
        put(s, x, 1, 'F')
    for x in range(1, 4):
        put(s, x, 3, 'F')
    for (x, y) in ((6, 5), (7, 3), (3, 5), (2, 2)):
        put(s, x, y, ',')
    put(s, 8, 6, 'P'); put(s, 1, 6, 'P')
    npc(k, 'hazel', 5, 4)
    pick(k, 'quest:chicks', 2, 2)
    sign(k, 7, 5, 'village')
    # extra chick in meadow (3,6)
    pick((3, 6), 'quest:chicks', 7, 4)

    # ---- Forest
    gate((4, 4), 5, 2, 1)
    cave((2, 5), 3, 3, (0, 1), 'bomb', 4, 6)
    cave((5, 4), 7, 3, (2, 1), 'burn', 4, 6)
    pick((3, 4), 'quest:mushrooms', 3, 3)
    pick((5, 5), 'quest:mushrooms', 6, 4)
    pick((2, 4), 'quest:mushrooms', 6, 5)
    sign((3, 5), 2, 3, 'forestsign')
    sign((4, 4), 8, 5, 'd1sign')
    npc((3, 5), 'gus', 7, 3)
    # ---- Meadow secrets
    cave((5, 6), 2, 2, (6, 1), 'bomb', 4, 6)
    sign((3, 6), 2, 4, 'village')
    # ---- Dunes
    gate((7, 5), 4, 2, 2)
    cave((6, 6), 3, 3, (1, 1), 'bomb', 4, 6)
    pick((7, 4), 'quest:shells', 3, 3)
    pick((6, 5), 'quest:shells', 6, 5)
    pick((7, 7), 'quest:shells', 5, 4)
    npc((6, 5), 'sandy', 3, 3)
    npc((7, 6), 'dusty', 5, 3)
    sign((6, 4), 2, 3, 'dunesign')
    # ---- Lake
    gate((0, 5), 4, 2, 3)
    house((1, 6), 5, 4, (0, 2))
    npc((0, 4), 'ripple', 5, 4)
    sign((1, 4), 2, 3, 'lakesign')
    # ---- Marsh
    gate((4, 2), 5, 2, 4)
    npc((3, 3), 'moss', 4, 3)
    sign((3, 3), 2, 2, 'marshsign')
    s = S[(2, 3)]
    pos = near_free(s, 6, 4, used[(2, 3)], avoid[(2, 3)])
    put(s, pos[0], pos[1], 'C')
    E((2, 3), 'chest %d %d quest:lure %d' % (pos[0], pos[1], g.flag()))
    # ---- Hills
    cave((5, 1), 6, 3, (3, 1), 'open', 4, 6)
    pick((3, 1), 'quest:scarf', 4, 4)
    npc((3, 0), 'marla', 4, 4)
    sign((4, 1), 3, 4, 'hillsign')
    # ---- Frost
    gate((0, 1), 4, 2, 5)
    house((1, 2), 5, 4, (1, 2))
    cave((1, 0), 7, 3, (4, 1), 'open', 4, 6)
    cave((0, 3), 3, 3, (5, 1), 'bomb', 4, 6)
    sign((1, 1), 2, 4, 'frostsign')
    # ---- Crater
    gate((7, 1), 4, 2, 6)
    npc((6, 2), 'ember', 4, 3)
    sign((6, 1), 2, 4, 'cratersign')
    return used, avoid, ents, interior_back, gates


def populate(g, S, used, avoid, ents):
    """enemies, hidden gems under bushes."""
    village = {(3, 7), (4, 7), (5, 7), (2, 7)}
    for (gx, gy), s in sorted(S.items()):
        reg = RG[gy][gx]
        k = (gx, gy)
        if k in village:
            continue
        free = [(x, y) for y in range(2, 6) for x in range(2, 8) if s.t[y][x] in '.,' and (x, y) not in used[k]]
        rnd.shuffle(free)
        base = 1 if reg == 'M' else 2
        n = rnd.randint(base, base + 1)
        # no enemies right next to warps
        wp = [(int(e.split()[1]), int(e.split()[2])) for e in ents[k] if e.startswith(('warp', 'gate'))]
        for _ in range(n):
            if not free:
                break
            et = rnd.choice(ENEMIES[reg])
            x, y = free.pop()
            if any(abs(x - a) + abs(y - b) < 3 for a, b in wp):
                continue
            if et == 'beetlebit':
                for i in range(4):
                    if free:
                        xx, yy = free.pop()
                        ents[k].append('en beetlebit %d %d' % (xx, yy))
                continue
            ents[k].append('en %s %d %d' % (et, x, y))
        bushes = [(x, y) for y in range(1, 7) for x in range(1, 9) if s.t[y][x] == 'b']
        rnd.shuffle(bushes)
        if bushes and rnd.random() < 0.5:
            x, y = bushes.pop()
            amount = 5 if reg in 'MW' else 10
            ents[k].append('hide %d %d gems:%d %d' % (x, y, amount, g.flag()))
        if bushes and rnd.random() < 0.25:
            x, y = bushes.pop()
            ents[k].append('hide %d %d gems:5 %d' % (x, y, g.flag()))
    # guarantee blobbo supply for the Blobbo Trouble quest
    count = sum(1 for k, v in ents.items() for e in v if e.startswith('en blobbo'))
    cand = [k for k in sorted(S) if RG[k[1]][k[0]] in 'MW' and k not in village]
    guard = 0
    while count < 12 and guard < 200:
        guard += 1
        k = rnd.choice(cand)
        s = S[k]
        free = [(x, y) for y in range(2, 6) for x in range(2, 8)
                if s.t[y][x] in '.,' and not any(e.split()[0] in ('en', 'npc', 'pick') and (int(e.split()[-3 if e.startswith('en') or e.startswith('npc') else 1]) if False else 0) == 1 for e in [])]
        occupied = set()
        for e in ents[k]:
            q = e.split()
            if q[0] in ('en', 'npc'):
                occupied.add((int(q[2]), int(q[3])))
            elif q[0] in ('pick', 'hide', 'warp', 'gate', 'sign', 'chest', 'board'):
                occupied.add((int(q[1]), int(q[2])))
        free = [c for c in free if c not in occupied and c not in used[k]]
        if not free:
            continue
        x, y = rnd.choice(free)
        ents[k].append('en blobbo %d %d' % (x, y))
        count += 1
    return count


# ---------------------------------------------------------------------------------------------------------------------
# Interiors
# ---------------------------------------------------------------------------------------------------------------------
def frame_room(interior, door=None):
    rows = ['#' * 10]
    for r in interior:
        rows.append('#' + r + '#')
    last = list('#' * 10)
    if door is not None:
        last[door[0]] = door[1]
    rows.append(''.join(last))
    return rows


def build_interiors(back):
    area = Area(1, 'indoors', 'INDOORS', 1, 8, 8)

    def add(gx, gy, region, rows, ents, doorch='d'):
        r = Room(gx, gy, region, rows, ents)
        area.rooms[(gx, gy)] = r
        return r

    def backwarp(gx, gy, ch_ok=True):
        k, x, y = back[(gx, gy)]
        return 'warp 4 7 0 %d %d %d %d' % (k[0], k[1], x, y)

    add(0, 0, 'indoor', frame_room(["mC...hh.", "........", "..gg..a.", "..gg....", "........", "........"], (4, 'd')) if False else
        ['##########', '#mC...hh.#', '#........#', '#..gg..a.#', '#..gg....#', '#........#', '#........#', '####d#####'],
        ['chest 2 1 item:sword 1', 'npc biscuit 7 5', backwarp(0, 0), 'music indoor'])
    add(1, 0, 'indoor',
        ['##########', '#hhh..hhh#', '#........#', '#..aaa...#', '#........#', '#.g....g.#', '#........#', '####d#####'],
        ['npc elder 6 4', backwarp(1, 0)])
    add(2, 0, 'indoor',
        ['##########', '#hh....hh#', '#........#', '#.ccccc..#', '#........#', '#........#', '#........#', '####d#####'],
        ['wares 2 3 item:shield 30 2', 'wares 4 3 bombs:5 10', 'wares 6 3 arrows:10 15', 'npc shopkeeper 4 2', backwarp(2, 0)])
    add(3, 0, 'indoor',
        ['##########', '#hh......#', '#........#', '#...aa...#', '#........#', '#.g......#', '#........#', '####d#####'],
        ['npc smith 6 4', backwarp(3, 0)])
    add(4, 0, 'indoor',
        ['##########', '#hhh..aa.#', '#........#', '#........#', '#...g....#', '#........#', '#........#', '####d#####'],
        ['npc basil 4 3', backwarp(4, 0)])
    # caves
    add(0, 1, 'cave',
        ['##########', '#........#', '#..C.....#', '#........#', '#........#', '#........#', '#........#', '####D#####'],
        ['chest 3 2 item:gloves 3', backwarp(0, 1)])
    add(1, 1, 'cave',
        ['##########', '#P......P#', '#........#', '#........#', '#........#', '#........#', '#P......P#', '####D#####'],
        ['pick 4 3 piece 4', backwarp(1, 1)])
    add(2, 1, 'cave',
        ['##########', '#........#', '#...ww...#', '#...ww...#', '#........#', '#........#', '#........#', '####D#####'],
        ['fountain 4 2', 'music fairy', backwarp(2, 1)])
    add(3, 1, 'cave',
        ['##########', '#........#', '#...NNNN.#', '#........#', '#........#', '#........#', '#........#', '####D#####'],
        ['block 2 5', 'switch 7 5 5', 'shut 5', 'pick 5 1 piece 6', backwarp(3, 1)])
    # fix cave 3,1: switch tile char and pickup in alcove
    r = area.rooms[(3, 1)]
    r.t[5][7] = 'S'
    r.t[1][5] = '.'
    r.t[2] = list('#...NNNN.#')
    # alcove row 1 is open floor behind the shutter row 2; connect only through row 2 shutters
    r.t[2] = list('#NNNNNNNN#')
    r.t[1] = list('#........#')
    # the alcove (row 1) is only reachable through the shutters: give the room a floor of rows 3..6
    add(4, 1, 'cave',
        ['##########', '#........#', '#...ww...#', '#...ww...#', '#........#', '#........#', '#........#', '####D#####'],
        ['fountain 4 2', 'music fairy', backwarp(4, 1)])
    add(5, 1, 'cave',
        ['##########', '#P......P#', '#........#', '#........#', '#........#', '#........#', '#P......P#', '####D#####'],
        ['pick 4 3 piece 7', backwarp(5, 1)])
    add(6, 1, 'cave',
        ['##########', '#........#', '#...C....#', '#........#', '#........#', '#........#', '#........#', '####D#####'],
        ['chest 4 2 gems:30 8', backwarp(6, 1)])
    add(0, 2, 'indoor',
        ['##########', '#hh......#', '#........#', '#...aa...#', '#........#', '#.g......#', '#........#', '####d#####'],
        ['npc finn 5 4', backwarp(0, 2)])
    add(1, 2, 'indoor',
        ['##########', '#........#', '#.hh.....#', '#........#', '#...g....#', '#........#', '#........#', '####d#####'],
        ['npc frosty 5 4', backwarp(1, 2)])
    return area


# ---------------------------------------------------------------------------------------------------------------------
# Dungeons
# ---------------------------------------------------------------------------------------------------------------------
def dungeon_room(gx, gy, region, interior, opens, marks, extras):
    """interior: 6 strings of 8 chars. opens: dict side -> 'open' | 'L:f' | 'K:f' | 'N' | 'D'. marks: char -> (tile, template)."""
    tiles = [list('#' * 10) for _ in range(8)]
    ents = []
    for ry, row in enumerate(interior):
        assert len(row) == 8, (gx, gy, row)
        for rx, ch in enumerate(row):
            x, y = rx + 1, ry + 1
            if ch in marks:
                tile, tpl = marks[ch]
                tiles[y][x] = tile
                ents.append(tpl.format(x=x, y=y))
            else:
                tiles[y][x] = ch
    for side, spec in opens.items():
        cells = {'N': [(4, 0), (5, 0)], 'S': [(4, 7), (5, 7)], 'W': [(0, 3), (0, 4)], 'E': [(9, 3), (9, 4)]}[side]
        kind = spec.split(':')[0]
        if kind == 'open':
            ch = '.'
        elif kind == 'L':
            ch = 'L'
        elif kind == 'K':
            ch = 'K'
        elif kind == 'N':
            ch = 'N'
        elif kind == 'D':
            ch = 'D'
            cells = cells[:1]
        else:
            raise Exception(spec)
        for (x, y) in cells:
            tiles[y][x] = ch
        if kind in ('L', 'K'):
            f = int(spec.split(':')[1])
            ents.append('%s %d %d %d' % ('lock' if kind == 'L' else 'blk', cells[0][0], cells[0][1], f))
    ents.extend(extras)
    return Room(gx, gy, region, [''.join(r) for r in tiles], ents)


def build_dungeon1():
    a = Area(101, 'd1', 'HOLLOW OAK', 2, 4, 4)
    reg = 'dun1'
    R = lambda gx, gy, interior, opens, marks, extras: a.rooms.__setitem__(
        (gx, gy), dungeon_room(gx, gy, reg, interior, opens, marks, extras))
    en = lambda name: ('.', 'en %s {x} {y}' % name)
    R(1, 3, ["P......P", "........", "..I..I..", "..1..2..", "........", "........"],
      {'N': 'open', 'E': 'open', 'S': 'D'}, {'1': en('blobbo'), '2': en('blobbo')},
      ['warp 4 7 0 4 4 5 3', 'sign 4 5 d1sign'] if False else ['warp 4 7 0 4 4 5 3'])
    R(2, 3, ["P.P..P.P", "........", "........", "........", ".5....6.", "...7...."],
      {'W': 'open'}, {'5': en('flutterbug'), '6': en('flutterbug'), '7': ('C', 'chest {x} {y} gems:20 17')}, [])
    R(1, 2, ["..P..P..", ".o....o.", "...II...", "...II...", ".o.12.o.", "........"],
      {'S': 'open', 'W': 'open', 'E': 'L:11', 'N': 'L:12'},
      {'1': en('flutterbug'), '2': en('shellguard')}, [])
    R(0, 2, ["........", "........", "..1.....", "........", ".2......", "..3....."],
      {'E': 'open', 'N': 'N'}, {'1': ('S', 'switch {x} {y} 1'), '2': ('.', 'block {x} {y}'), '3': en('blobbo')}, ['shut 1'])
    R(0, 1, ["P......P", "........", ".1....2.", "...C....", "........", "P......P"],
      {'S': 'open', 'N': 'open'}, {'1': en('flutterbug'), '2': en('blobbo'), 'C': ('C', 'chest {x} {y} key 4 3')}, ['clear 3'])
    R(0, 0, ["I......I", "........", "...C....", "........", "........", "I......I"],
      {'S': 'open'}, {'C': ('C', 'chest {x} {y} map 5')}, [])
    R(2, 2, ["........", ".I....I.", "...1.2..", "........", ".3....S.", "...C...."],
      {'W': 'open', 'N': 'N', 'E': 'open'},
      {'1': en('shellguard'), '2': en('blobbo'), '3': ('.', 'block {x} {y}'), 'S': ('S', 'switch {x} {y} 6'),
       'C': ('C', 'chest {x} {y} key 9 10')}, ['shut 6', 'clear 10'])
    R(2, 1, ["I......I", "........", "........", "...1....", "........", "I......I"],
      {'S': 'open', 'E': 'N'}, {'1': ('.', 'mini {x} {y} mossback 7')}, ['shut 7'])
    R(3, 1, ["P......P", "........", "........", "...C....", "........", "P......P"],
      {'W': 'open', 'S': 'open'}, {'C': ('C', 'chest {x} {y} item:boomerang 8')}, [])
    R(3, 2, ["........", ".......1", "........", "..oo....", ".2....3.", "...C...."],
      {'N': 'open', 'W': 'open'},
      {'1': ('E', 'eye {x} {y} 13'), '2': en('wisp'), '3': en('wisp'), 'C': ('C', 'chest {x} {y} bigkey 14 13')}, [])
    R(1, 1, ["P......P", "........", ".1....2.", "........", "...C....", "........"],
      {'S': 'open', 'N': 'K:16'},
      {'1': en('shellguard'), '2': en('flutterbug'), 'C': ('C', 'chest {x} {y} item:bombs 15')}, [])
    R(1, 0, ["I......v", "........", "...1....", "........", "........", "I......I"],
      {'S': 'open'}, {'1': ('.', 'boss {x} {y} bramble 20')}, ['warp 8 1 101 1 3 4 6 oneway'])
    return a


def build_dungeon2():
    a = Area(102, 'd2', 'SUNKEN SANDHOUSE', 2, 4, 4)
    reg = 'dun2'
    R = lambda gx, gy, interior, opens, marks, extras: a.rooms.__setitem__(
        (gx, gy), dungeon_room(gx, gy, reg, interior, opens, marks, extras))
    en = lambda name: ('.', 'en %s {x} {y}' % name)
    R(2, 3, ["P......P", "........", "..1..2..", "........", "..I..I..", "........"],
      {'N': 'open', 'W': 'open', 'S': 'D'}, {'1': en('crabby'), '2': en('sandmole')}, ['warp 4 7 0 7 5 4 3'])
    R(1, 3, ["P.P..P.P", "........", "...1....", "........", ".2....3.", "P.C....P"],
      {'E': 'open'}, {'1': en('sandmole'), '2': en('crabby'), '3': en('crabby'), 'C': ('C', 'chest {x} {y} gems:20 3')}, [])
    R(2, 2, ["..P..P..", "........", ".I....I.", "........", "...1.2..", "........"],
      {'S': 'open', 'W': 'open', 'E': 'open', 'N': 'L:5'}, {'1': en('spinwheel'), '2': en('crabby')}, [])
    R(1, 2, ["1......2", "........", "...3....", "........", ".4....5.", "........"],
      {'E': 'open', 'W': 'open', 'N': 'N'},
      {'1': ('t', 'torch {x} {y} 1'), '2': ('t', 'torch {x} {y} 2'), '3': en('wisp'), '4': en('sandmole'), '5': en('crabby')},
      ['dark', 'shut 1 2'])
    R(0, 2, ["........", "...1....", "........", "..C.....", "........", "....2..."],
      {'E': 'open'}, {'1': en('sandmole'), '2': en('sandmole'), 'C': ('C', 'chest {x} {y} key 12')}, ['dark'])
    R(1, 1, ["..o..o..", "........", ".1....2.", "........", "..o..o..", "........"],
      {'S': 'open', 'N': 'L:6'}, {'1': en('wisp'), '2': en('spinwheel')}, ['dark'])
    R(1, 0, ["P......P", "........", "...C....", "........", "........", "P......P"],
      {'S': 'open'}, {'C': ('C', 'chest {x} {y} map 13')}, [])
    R(3, 2, ["........", ".I....I.", "...1.2..", "........", ".3....4.", "...C...."],
      {'W': 'open', 'N': 'K:18'},
      {'1': en('spinwheel'), '2': en('crabby'), '3': en('clunker'), '4': en('sandmole'), 'C': ('C', 'chest {x} {y} key 11 10')},
      ['clear 10'])
    R(2, 1, ["I......I", "........", "........", "...1....", "........", "I......I"],
      {'S': 'open', 'N': 'N'}, {'1': ('.', 'mini {x} {y} clunkknight 14')}, ['shut 14'])
    R(2, 0, ["P......P", "........", "........", "...C....", "........", "P......P"],
      {'S': 'open', 'E': 'open'}, {'C': ('C', 'chest {x} {y} item:bow 15')}, [])
    R(3, 0, ["P......P", "........", ".......1", "........", "...2....", "...C...."],
      {'W': 'open'}, {'1': ('E', 'eye {x} {y} 16'), '2': en('wisp'), 'C': ('C', 'chest {x} {y} bigkey 17 16')}, [])
    R(3, 1, ["I......v", "........", "...1....", "........", "........", "I......I"],
      {'S': 'open'}, {'1': ('.', 'boss {x} {y} scarab 20')}, ['warp 8 1 102 2 3 4 6 oneway'])
    return a


DUNGEON_INFO = {
    101: dict(num=1, id='d1', name='HOLLOW OAK', spark='DEW SPARK', entry=(1, 3, 4, 6), needs=0, boss='bramble', reward='boomerang'),
    102: dict(num=2, id='d2', name='SUNKEN SANDHOUSE', spark='SUN SPARK', entry=(2, 3, 4, 6), needs=0, boss='scarab', reward='bow'),
}


# ---------------------------------------------------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------------------------------------------------
def room_swift(r, indent='        '):
    lines = []
    lines.append('%srooms.append(LanternRoomDef(%d, %d, "%s", [' % (indent, r.gx, r.gy, r.region))
    rows = r.rows()
    for i, row in enumerate(rows):
        lines.append('%s    "%s"%s' % (indent, row, ',' if i < len(rows) - 1 else ''))
    lines.append('%s], [' % indent)
    for i, e in enumerate(r.ents):
        lines.append('%s    "%s"%s' % (indent, e, ',' if i < len(r.ents) - 1 else ''))
    lines.append('%s]))' % indent)
    return '\n'.join(lines)


HEADER = """#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

"""


def write_area_file(fname, enum_name, doc, area, extra_args, area_expr):
    src = HEADER + doc + 'enum %s {\n    static func make() -> LanternArea {\n        var rooms: [LanternRoomDef] = []\n' % enum_name
    for key in sorted(area.rooms, key=lambda k: (k[1], k[0])):
        src += room_swift(area.rooms[key]) + '\n'
    src += '        return %s\n    }\n}\n' % area_expr
    open(OUT + fname, 'w').write(src)


def write_all(S, interiors, d1, d2):
    ow = Area(0, 'overworld', 'THE VALLEY', 0, 8, 8)
    for k, s in S.items():
        ow.rooms[k] = s
    write_area_file('LanternOverworld.swift', 'LanternOverworld',
                    '/// The 8 x 8 overworld (generated by Tools/lantern/build_world.py, edit freely afterwards).\n'
                    '/// Regions: frost (NW), hills, crater (NE), marsh, lake (W), forest, dunes (E), meadow (S, with the village).\n',
                    ow, '', 'LanternArea(num: 0, id: "overworld", name: "THE VALLEY", kind: 0, gw: 8, gh: 8, rooms: rooms)')
    write_area_file('LanternInteriors.swift', 'LanternInteriors',
                    '/// Houses, shop and caves: every room of this area is a separate one-room interior reached by warps.\n',
                    interiors, '', 'LanternArea(num: 1, id: "indoors", name: "INDOORS", kind: 1, gw: 8, gh: 8, rooms: rooms)')
    for fname, enum, area, info, doc in (
            ('LanternDungeon1.swift', 'LanternDungeon1', d1, DUNGEON_INFO[101],
             '/// Dungeon 1, HOLLOW OAK (Whispering Forest). Theme: push blocks onto switches. Item: boomerang. Boss: Queen Bramble.\n'),
            ('LanternDungeon2.swift', 'LanternDungeon2', d2, DUNGEON_INFO[102],
             '/// Dungeon 2, SUNKEN SANDHOUSE (Sandy Dunes). Theme: dark rooms, torches and eye switches. Item: bow. Boss: Grand Scarab.\n')):
        src = HEADER + doc + 'enum %s {\n    static func make() -> LanternDungeon {\n        var rooms: [LanternRoomDef] = []\n' % enum
        for key in sorted(area.rooms, key=lambda k: (k[1], k[0])):
            src += room_swift(area.rooms[key]) + '\n'
        e = info['entry']
        src += ('        let area = LanternArea(num: %d, id: "%s", name: "%s", kind: 2, gw: 4, gh: 4, rooms: rooms)\n' % (
            area.num, info['id'], info['name']))
        src += ('        return LanternDungeon(num: %d, id: "%s", name: "%s", sparkName: "%s", area: area,\n'
                '                              entryGx: %d, entryGy: %d, entryTx: %d, entryTy: %d, sparksNeeded: %d,\n'
                '                              bossId: "%s", rewardItem: "%s")\n    }\n}\n' % (
                    info['num'], info['id'], info['name'], info['spark'], e[0], e[1], e[2], e[3], info['needs'],
                    info['boss'], info['reward']))
        open(OUT + fname, 'w').write(src)


# ---------------------------------------------------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------------------------------------------------
class World:
    def __init__(self, areas):
        self.areas = {a.num: a for a in areas}


def parse(e):
    return e.split()


def edge_class(ch):
    if ch not in SOLID or ch in 'LKNByr':
        return 1
    return 0


def validate_structure(w):
    for a in w.areas.values():
        for (gx, gy), r in a.rooms.items():
            tag = 'area %d room %d,%d' % (a.num, gx, gy)
            rows = r.rows()
            if len(rows) != 8:
                err(tag + ' rows')
            for row in rows:
                if len(row) != 10:
                    err(tag + ' width')
                for ch in row:
                    if ch not in VALID:
                        err(tag + ' bad char ' + ch)
            if a.kind != 1:
                if (gx + 1, gy) in a.rooms:
                    o = a.rooms[(gx + 1, gy)].rows()
                    for y in range(8):
                        if edge_class(rows[y][9]) != edge_class(o[y][0]):
                            err(tag + ' east edge mismatch row %d (%s|%s)' % (y, rows[y][9], o[y][0]))
                if (gx, gy + 1) in a.rooms:
                    o = a.rooms[(gx, gy + 1)].rows()
                    for x in range(10):
                        if edge_class(rows[7][x]) != edge_class(o[0][x]):
                            err(tag + ' south edge mismatch col %d (%s|%s)' % (x, rows[7][x], o[0][x]))
            flags = set()
            for e in r.ents:
                p = parse(e)
                k = p[0]
                try:
                    check_entity(w, a, r, p, tag, flags)
                except Exception as ex:
                    err('%s entity %r failed: %s' % (tag, e, ex))
    # global flag uniqueness per area (local numbers must not be reused by different features, except shared references)


FLAG_DEF_KINDS = ('chest', 'pick', 'hide', 'switch', 'torch', 'eye', 'lock', 'blk', 'bomb', 'burn', 'lift', 'mini', 'boss')


def check_entity(w, a, r, p, tag, flags):
    k = p[0]
    t = r.t

    def at(x, y):
        return t[y][x]
    if k in ('en', 'npc'):
        x, y = int(p[2]), int(p[3])
        if not walk(at(x, y)):
            err('%s %s at %d,%d not walkable (%s)' % (tag, k, x, y, at(x, y)))
    elif k == 'pick':
        x, y = int(p[1]), int(p[2])
        if not walk(at(x, y)):
            err('%s pick at %d,%d not walkable' % (tag, x, y))
    elif k == 'chest':
        x, y = int(p[1]), int(p[2])
        if at(x, y) != 'C':
            err('%s chest at %d,%d tile is %s' % (tag, x, y, at(x, y)))
    elif k == 'sign':
        x, y = int(p[1]), int(p[2])
        if at(x, y) != 'e':
            err('%s sign tile %s' % (tag, at(x, y)))
    elif k == 'board':
        x, y = int(p[1]), int(p[2])
        if at(x, y) != 'e':
            err('%s board tile' % tag)
    elif k == 'switch':
        if at(int(p[1]), int(p[2])) != 'S':
            err('%s switch tile' % tag)
    elif k == 'torch':
        if at(int(p[1]), int(p[2])) != 't':
            err('%s torch tile' % tag)
    elif k == 'eye':
        if at(int(p[1]), int(p[2])) != 'E':
            err('%s eye tile' % tag)
    elif k == 'block':
        if not walk(at(int(p[1]), int(p[2]))):
            err('%s block tile' % tag)
    elif k in ('lock', 'blk', 'bomb', 'burn', 'lift'):
        want = {'lock': 'L', 'blk': 'K', 'bomb': 'B', 'burn': 'y', 'lift': 'r'}[k]
        if at(int(p[1]), int(p[2])) != want:
            err('%s %s tile is %s' % (tag, k, at(int(p[1]), int(p[2]))))
    elif k == 'hide':
        if at(int(p[1]), int(p[2])) not in 'bPr':
            err('%s hide tile is %s' % (tag, at(int(p[1]), int(p[2]))))
    elif k == 'wares':
        if at(int(p[1]), int(p[2])) != 'c':
            err('%s wares tile' % tag)
    elif k == 'fountain':
        pass
    elif k == 'warp':
        x, y = int(p[1]), int(p[2])
        if at(x, y) not in 'dDv':
            err('%s warp tile %s' % (tag, at(x, y)))
        ta, tgx, tgy, tx, ty = int(p[3]), int(p[4]), int(p[5]), int(p[6]), int(p[7])
        if ta not in w.areas or (tgx, tgy) not in w.areas[ta].rooms:
            err('%s warp target missing' % tag)
            return
        tr = w.areas[ta].rooms[(tgx, tgy)]
        if not walk(tr.t[ty][tx]):
            err('%s warp landing %d,%d blocked (%s)' % (tag, tx, ty, tr.t[ty][tx]))
        if len(p) > 8 and p[8] == 'oneway':
            return
        back = False
        for e2 in tr.ents:
            q = e2.split()
            if q[0] == 'warp' and int(q[3]) == a.num and int(q[4]) == r.gx and int(q[5]) == r.gy:
                back = True
            if q[0] == 'gate' and a.num > 100 and int(q[3]) == a.num - 100:
                back = True
        if not back:
            err('%s warp has no way back' % tag)
    elif k == 'gate':
        x, y = int(p[1]), int(p[2])
        if at(x, y) != 'D':
            err('%s gate tile' % tag)
        for dx, dy in ((1, 0), (-1, 0), (0, -1)):
            if walk(t[y + dy][x + dx]):
                err('%s gate has extra neighbour %d,%d' % (tag, dx, dy))
        if not walk(t[y + 1][x]):
            err('%s gate approach blocked' % tag)
    for token_idx, name in ():
        pass
    # flag range
    fi = {'chest': 4, 'pick': 4, 'hide': 4, 'switch': 3, 'torch': 3, 'eye': 3, 'lock': 3, 'blk': 3, 'bomb': 3, 'burn': 3, 'lift': 3,
          'mini': 4, 'boss': 4, 'clear': 1}
    if k in fi:
        f = int(p[fi[k]])
        if f < 1 or f + (2 if k == 'boss' else 0) >= a.flag_count:
            err('%s flag out of range %d' % (tag, f))
        if k in FLAG_DEF_KINDS:
            key = ('def', f)
            if key in flags and k not in ('lock', 'blk', 'bomb', 'lift', 'burn'):
                err('%s flag %d defined twice' % (tag, f))
            flags.add(key)


# ----- reachability simulation

def neighbors(w, node):
    a, gx, gy, x, y = node
    ar = w.areas[a]
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = x + dx, y + dy
        ngx, ngy = gx, gy
        if nx < 0:
            ngx, nx = gx - 1, 9
        elif nx > 9:
            ngx, nx = gx + 1, 0
        elif ny < 0:
            ngy, ny = gy - 1, 7
        elif ny > 7:
            ngy, ny = gy + 1, 0
        if (ngx, ngy) != (gx, gy):
            if ar.kind == 1 or (ngx, ngy) not in ar.rooms:
                continue
        yield (a, ngx, ngy, nx, ny)


def tile_of(w, node):
    a, gx, gy, x, y = node
    return w.areas[a].rooms[(gx, gy)].t[y][x]


def group_cells(w, a, gx, gy, x, y, ch):
    r = w.areas[a].rooms[(gx, gy)]
    seen = set()
    if r.t[y][x] != ch:
        return seen
    st = [(x, y)]
    seen.add((x, y))
    while st:
        cx, cy = st.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < 10 and 0 <= ny < 8 and (nx, ny) not in seen and r.t[ny][nx] == ch:
                seen.add((nx, ny))
                st.append((nx, ny))
    return seen


def overworld_reach(w, items, start):
    """BFS over overworld + interiors. Gate doors are endpoints only (dungeons are simulated separately)."""
    # groups opened by flags are not tracked in the overworld: gate groups use item rules
    def passable(ch):
        if walk(ch):
            return True
        if ch == 'b':
            return True
        if ch == 'y':
            return 'lantern' in items
        if ch == 'B':
            return 'bombs' in items
        if ch == 'r':
            return 'gloves' in items
        if ch == 'N':
            return True
        return False

    seen = {start}
    st = [start]
    warp_map = {}
    for num, a in w.areas.items():
        if num > 100:
            continue
        for (gx, gy), r in a.rooms.items():
            for e in r.ents:
                q = e.split()
                if q[0] == 'warp':
                    warp_map[(num, gx, gy, int(q[1]), int(q[2]))] = (int(q[3]), int(q[4]), int(q[5]), int(q[6]), int(q[7]))
    while st:
        node = st.pop()
        nxts = list(neighbors(w, node))
        if node in warp_map:
            nxts.append(warp_map[node])
        for nb in nxts:
            if nb in seen:
                continue
            if w.areas[nb[0]].rooms.get((nb[1], nb[2])) is None:
                continue
            if not passable(tile_of(w, nb)):
                continue
            seen.add(nb)
            st.append(nb)
    return seen


def sim_dungeon(w, anum, items):
    """Returns (gained items set, boss reached, chests collected set, all chests set)."""
    a = w.areas[anum]
    info = DUNGEON_INFO[anum]
    entry = (anum, info['entry'][0], info['entry'][1], info['entry'][2], info['entry'][3])
    all_chests = set()
    for (gx, gy), r in a.rooms.items():
        for e in r.ents:
            q = e.split()
            if q[0] in ('chest', 'pick'):
                all_chests.add((gx, gy, int(q[1]), int(q[2])))

    def solve(opened):
        gained = set()
        flags = set()
        keys = set()
        bigkey = False
        boss = False
        collected = set()
        while True:
            have = set(items) | gained

            def passable_factory():
                shut_open = {}
                for (gx, gy), r in a.rooms.items():
                    req = []
                    for e in r.ents:
                        q = e.split()
                        if q[0] == 'shut':
                            req = [int(v) for v in q[1:]]
                    shut_open[(gx, gy)] = all(f in flags for f in req) if req else False
                return shut_open
            shut_open = passable_factory()
            lockgroups = {}
            for (gx, gy), r in a.rooms.items():
                for e in r.ents:
                    q = e.split()
                    if q[0] in ('lock', 'blk'):
                        ch = 'L' if q[0] == 'lock' else 'K'
                        cells = group_cells(w, anum, gx, gy, int(q[1]), int(q[2]), ch)
                        for c in cells:
                            lockgroups[(gx, gy, c[0], c[1])] = (q[0], int(q[3]), (gx, gy))

            def passable(node):
                ch = tile_of(w, node)
                if walk(ch):
                    return True
                gx, gy, x, y = node[1], node[2], node[3], node[4]
                if ch in 'LK':
                    g = lockgroups.get((gx, gy, x, y))
                    if g is None:
                        return False
                    if g[0] == 'lock':
                        return g[1] in opened
                    return bigkey
                if ch == 'N':
                    return shut_open[(gx, gy)]
                return False
            seen = {entry}
            st = [entry]
            while st:
                n = st.pop()
                for nb in neighbors(w, n):
                    if nb in seen:
                        continue
                    if not passable(nb):
                        continue
                    seen.add(nb)
                    st.append(nb)
            changed = False

            def adj_reach(gx, gy, x, y):
                for nb in neighbors(w, (anum, gx, gy, x, y)):
                    if nb in seen:
                        return True
                return (anum, gx, gy, x, y) in seen
            for (gx, gy), r in a.rooms.items():
                inroom = any(n[1] == gx and n[2] == gy for n in seen)
                if not inroom:
                    continue
                blocks = any(e.startswith('block') for e in r.ents)
                for e in r.ents:
                    q = e.split()
                    if q[0] == 'clear':
                        if int(q[1]) not in flags:
                            flags.add(int(q[1])); changed = True
                    elif q[0] == 'mini':
                        if int(q[4]) not in flags:
                            flags.add(int(q[4])); changed = True
                    elif q[0] == 'boss':
                        if adj_reach(gx, gy, int(q[1]), int(q[2])):
                            boss = True
                    elif q[0] == 'switch':
                        if blocks and int(q[3]) not in flags:
                            flags.add(int(q[3])); changed = True
                    elif q[0] == 'torch':
                        if 'lantern' in have and adj_reach(gx, gy, int(q[1]), int(q[2])) and int(q[3]) not in flags:
                            flags.add(int(q[3])); changed = True
                    elif q[0] == 'eye':
                        if (have & {'boomerang', 'bow', 'bombs'}) and int(q[3]) not in flags:
                            flags.add(int(q[3])); changed = True
                    elif q[0] in ('chest', 'pick'):
                        key = (gx, gy, int(q[1]), int(q[2]))
                        if key in collected:
                            continue
                        need = int(q[5]) if q[0] == 'chest' and len(q) > 5 else 0
                        if need and need not in flags:
                            continue
                        if not adj_reach(gx, gy, int(q[1]), int(q[2])):
                            continue
                        collected.add(key)
                        changed = True
                        rew = q[3]
                        if rew == 'key':
                            keys.add(key)
                        elif rew == 'bigkey':
                            bigkey = True
                        elif rew.startswith('item:'):
                            gained.add(rew[5:])
            # candidate locks
            cands = set()
            for (gx, gy, x, y), g in lockgroups.items():
                if g[0] != 'lock' or g[1] in opened:
                    continue
                for nb in neighbors(w, (anum, gx, gy, x, y)):
                    if nb in seen:
                        cands.add(g[1])
            if not changed:
                free = len(keys) - len(opened)
                if cands and free > 0:
                    best = None
                    for c in sorted(cands):
                        res = solve(opened | {c})
                        score = (res[1], len(res[2]))
                        if best is None or score > best[0]:
                            best = (score, res)
                    return best[1]
                return (gained, boss, collected, seen)

    res = solve(frozenset())
    return res[0], res[1], res[2], all_chests, res[3]


def validate_progression(w, gates):
    start = (1, 0, 0, 4, 4)
    items = set()
    log = []
    ow = w.areas[0]
    # ground-truth lists
    def region_of(node):
        if node[0] != 0:
            return 'indoors'
        return RG[node[2]][node[1]]
    done_d = set()
    stages = []
    for _round in range(12):
        reach = overworld_reach(w, items, start)
        regs = collections.Counter(region_of(n) for n in reach)
        stages.append((set(items), sorted(regs)))
        new = set(items)
        # chests with items
        for num in (0, 1):
            for (gx, gy), r in w.areas[num].rooms.items():
                for e in r.ents:
                    q = e.split()
                    if q[0] == 'chest' and q[3].startswith('item:'):
                        x, y = int(q[1]), int(q[2])
                        ok = any((num, gx, gy, x + dx, y + dy) in reach for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                        if ok:
                            new.add(q[3][5:])
                    if q[0] == 'npc' and q[1] == 'elder' and 'sword' in items:
                        if (num, gx, gy, int(q[2]), int(q[3]) + 1) in reach or (num, gx, gy, int(q[2]) - 1, int(q[3])) in reach \
                                or (num, gx, gy, int(q[2]) + 1, int(q[3])) in reach or (num, gx, gy, int(q[2]), int(q[3]) - 1) in reach:
                            new.add('lantern')
        # dungeons
        for n in (1, 2):
            if n in done_d:
                continue
            k, x, y = gates[n]
            if (0, k[0], k[1], x, y + 1) in reach:
                gained, boss, collected, allc, seen = sim_dungeon(w, 100 + n, new)
                if not boss:
                    err('dungeon %d: boss not reachable' % n)
                if collected != allc:
                    err('dungeon %d: unreachable chests/pickups %s' % (n, sorted(allc - collected)))
                # every walkable tile must be reachable (pits excluded)
                for (gx, gy), r in w.areas[100 + n].rooms.items():
                    for yy in range(8):
                        for xx in range(10):
                            if walk(r.t[yy][xx]) and (100 + n, gx, gy, xx, yy) not in seen:
                                err('dungeon %d room %d,%d tile %d,%d unreachable (%s)' % (n, gx, gy, xx, yy, r.t[yy][xx]))
                new |= gained
                done_d.add(n)
        # side-quest rewards (items)
        if 'quest_boots' not in items:
            pass
        if new == items:
            break
        items = new
    final = overworld_reach(w, items, start)
    return items, stages, final


def validate_world(w, gates):
    items, stages, final = validate_progression(w, gates)
    for st in stages:
        print('  stage items=%s regions=%s' % (sorted(st[0]), ''.join(st[1])))
    need = {'sword', 'lantern', 'bombs', 'boomerang', 'bow', 'gloves'}
    if not need <= items:
        err('progression never obtains %s' % sorted(need - items))
    # every walkable tile of the overworld and interiors reachable with all items
    for num in (0, 1):
        for (gx, gy), r in w.areas[num].rooms.items():
            for y in range(8):
                for x in range(10):
                    ch = r.t[y][x]
                    if walk(ch) and (num, gx, gy, x, y) not in final:
                        err('area %d room %d,%d tile %d,%d (%s) unreachable' % (num, gx, gy, x, y, ch))
    # stage assertions: before bombs only meadow+forest+indoors; before gloves not marsh/lake
    first = stages[0]
    for st in stages:
        if 'bombs' not in st[0]:
            for r in st[1]:
                if r not in 'MWindoors':
                    err('region %s reachable before bombs' % r)
        if 'gloves' not in st[0]:
            for r in st[1]:
                if r in 'SLFHE':
                    err('region %s reachable before gloves' % r)
    # entities that must be reachable: every pick / chest / npc
    for num in (0, 1):
        for (gx, gy), r in w.areas[num].rooms.items():
            for e in r.ents:
                q = e.split()
                if q[0] in ('pick',):
                    if (num, gx, gy, int(q[1]), int(q[2])) not in final:
                        err('pickup unreachable %s in %d %d,%d' % (e, num, gx, gy))
                if q[0] == 'chest':
                    x, y = int(q[1]), int(q[2])
                    if not any((num, gx, gy, x + dx, y + dy) in final for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                        err('chest unreachable %s in %d %d,%d' % (e, num, gx, gy))
    # quest supply
    cnt = collections.Counter()
    for num in (0, 1):
        for (gx, gy), r in w.areas[num].rooms.items():
            for e in r.ents:
                q = e.split()
                if q[0] == 'pick' and q[3].startswith('quest:'):
                    cnt[q[3]] += 1
                if q[0] == 'chest' and q[3].startswith('quest:'):
                    cnt[q[3]] += 1
    for k, n in (('quest:chicks', 3), ('quest:mushrooms', 3), ('quest:shells', 3), ('quest:lure', 1), ('quest:scarf', 1)):
        if cnt[k] < n:
            err('quest item %s only %d' % (k, cnt[k]))
    return items


def main():
    check_only = '--check' in sys.argv
    g, S = build_overworld()
    used, avoid, ents, back, gates = hand_features(g, S)
    for k, s in S.items():
        s.ents = ents[k]
    for k, s in S.items():
        for (x, y) in sorted(used[k]):
            if walk(s.t[y][x]):
                carve_to(s, (x, y))
        for (x, y) in list(s.opens):
            carve_to(s, (x, y))
        fill_pockets(s, RG[k[1]][k[0]])
    blobs = populate(g, S, used, avoid, ents)
    for k, s in S.items():
        s.ents = ents[k]
    interiors = build_interiors(back)
    d1 = build_dungeon1()
    d2 = build_dungeon2()
    ow = Area(0, 'overworld', 'THE VALLEY', 0, 8, 8)
    for k, s in S.items():
        ow.rooms[k] = s
    w = World([ow, interiors, d1, d2])
    validate_structure(w)
    validate_world(w, gates)
    print('overworld flags used: %d (limit 320), blobbos: %d' % (g.nf, blobs))
    if g.nf >= 320:
        err('too many overworld flags')
    if blobs < 10:
        err('too few blobbos for the Blobbo Trouble quest: %d' % blobs)
    if errors:
        print('%d PROBLEMS:' % len(errors))
        for e in errors[:80]:
            print('  ' + e)
        if len(errors) > 80:
            print('  ...')
        sys.exit(1)
    print('all maps valid')
    if not check_only:
        write_all(S, interiors, d1, d2)
        print('wrote Swift files')


if __name__ == '__main__':
    main()
