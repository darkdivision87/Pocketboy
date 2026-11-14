// Robot Smash Lab: a kid-safe toy ragdoll sandbox. Canvas 2D + matter-js.
import { Maestro } from '../shared/maestro.js';
import { ICONS } from './icons.js';
import { PART, SKINS, ARENAS, CLASSIC_PALS, getSprites, getIce, drawArena, drawArenaAnim, shade } from './art.js';

const { Engine, Bodies, Body, Composite, Constraint, Events, Query } = Matter;
const $ = (id) => document.getElementById(id);
const TAU = Math.PI * 2;
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const rand = (a, b) => a + Math.random() * (b - a);
const wrapA = (a) => { while (a > Math.PI) a -= TAU; while (a < -Math.PI) a += TAU; return a; };

// ------------------------------------------------------------------ save
const SAVE_KEY = 'robotsmash.v1';
let save = { coins: 120, tools: { grab: 1, glove: 1, hammer: 1 }, skins: { classic: 1 }, arenas: { lab: 1 }, up: { power: 0, grip: 0, coin: 0 }, stars: {}, tool: 'grab', skin: 'classic', arena: 'lab', muted: false, seenHint: false, seenSand: false, pops: 0 };
try { const s = JSON.parse(localStorage.getItem(SAVE_KEY) || 'null'); if (s) save = Object.assign(save, s); } catch (e) { /* ignore */ }
function persist() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(save)); } catch (e) { /* ignore */ } }

// ------------------------------------------------------------------ audio
const music = new Maestro();
const THEME = { bpm: 136, root: 'G', scale: 'major', prog: [0, 4, 5, 3], seventh: false, swing: 0.1, seed: 52, drums: 'half', hats: true, bass: 'bounce', pad: false, arp: { pattern: [0, 2, 4, 7, 4, 2, 5, 2], wave: 'square', oct: 1 }, lead: { wave: 'triangle', oct: 1, density: 0.62 }, bell: true, level: 0.9 };
music.muted = !!save.muted;
const sfxT = {};
function sfx(name, vol = 1, pitch = 1, gap = 45) {
  const n = performance.now(); if (sfxT[name] && n - sfxT[name] < gap) return; sfxT[name] = n;
  try { music.sfx(name, { volume: vol, pitch }); } catch (e) { /* ignore */ }
}
let musicStarted = false, themeKind = '';
function startMusic(kind = 'main') {
  try { music.unlock(); if (!musicStarted || themeKind !== kind) { music.play(kind === 'victory' ? 'victory' : THEME, { intensity: 0.35 }); musicStarted = true; themeKind = kind; } } catch (e) { /* ignore */ }
}
function setMuted(m) { save.muted = m; persist(); try { music.setMuted(m); } catch (e) { /* ignore */ } refreshMuteIcons(); }

// ------------------------------------------------------------------ canvas / layout
const canvas = $('c'), ctx = canvas.getContext('2d');
let dpr = 1, cssW = 0, cssH = 0, W = 1300, H = 900, scale = 1, floorY = 780, sbPx = 0, bg = null, bgKey = '';
const probe = document.createElement('div'); probe.style.cssText = 'position:fixed;left:0;top:0;width:0;height:0;visibility:hidden;padding-bottom:env(safe-area-inset-bottom,0px)'; document.body.appendChild(probe);
let layoutKey = '';
function layout() {
  cssW = Math.max(240, window.innerWidth); cssH = Math.max(240, window.innerHeight);
  sbPx = parseFloat(getComputedStyle(probe).paddingBottom) || 0;
  dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = Math.round(cssW * dpr); canvas.height = Math.round(cssH * dpr);
  const aspect = cssW / cssH;
  W = clamp(740 * aspect, 520, 1500); scale = cssW / W; H = cssH / scale;
  floorY = H - (104 + sbPx) / scale;
  bg = null;
  const k = Math.round(W) + 'x' + Math.round(H);
  if (k !== layoutKey) { layoutKey = k; if (world) buildWorld(); }
}
function makeBg() {
  const c = document.createElement('canvas'); c.width = canvas.width; c.height = canvas.height; const g = c.getContext('2d');
  g.setTransform(dpr * scale, 0, 0, dpr * scale, 0, 0); drawArena(g, S.arena, W, H, floorY); bg = c; bgKey = S.arena;
}

// ------------------------------------------------------------------ state
const S = { screen: 'title', mode: 'demo', arena: 'lab', level: null, paused: false, over: false, started: false, tool: 'grab', time: 0, timeLeft: 0, pops: 0, downCount: 0, moves: 0, chaos: 0, shake: 0, gflip: 1, gTimer: 0, coinsEarned: 0, slow: 0, endT: 0, hintOpen: false, winPending: 0 };
let engine, world, robots = [], props = [], ducks = [], bombs = [], statics = [], obstacles = [], robotSeq = 1, floorBody;

// ------------------------------------------------------------------ particles
const NP = 460; const P = []; for (let i = 0; i < NP; i++) P.push({ on: 0, k: 0, x: 0, y: 0, vx: 0, vy: 0, r: 0, vr: 0, life: 0, max: 1, s: 1, c: '#fff', g: 0 }); let pCur = 0;
function spawnP(k, x, y, vx, vy, life, s, c, g = 0.25, r = 0, vr = 0) {
  const p = P[pCur]; pCur = (pCur + 1) % NP; p.on = 1; p.k = k; p.x = x; p.y = y; p.vx = vx; p.vy = vy; p.life = life; p.max = life; p.s = s; p.c = c; p.g = g; p.r = r; p.vr = vr;
}
const CONF = ['#ff5d9e', '#ffd23f', '#4cd6c8', '#4aa8ff', '#a77bff', '#ff8a3c', '#7ee05a'];
function confetti(x, y, n, spd = 9, up = 4) { for (let i = 0; i < n; i++) { const a = rand(0, TAU), v = rand(2, spd); spawnP(0, x, y, Math.cos(a) * v, Math.sin(a) * v - up, rand(.8, 1.6), rand(5, 9), CONF[i % 7], 0.22, rand(0, 6), rand(-.3, .3)); } }
function bolts(x, y, n) { for (let i = 0; i < n; i++) { const a = rand(0, TAU), v = rand(3, 9); spawnP(1, x, y, Math.cos(a) * v, Math.sin(a) * v - 3, rand(.8, 1.4), rand(5, 8), '#cfd6e6', 0.3, rand(0, 6), rand(-.4, .4)); } }
function sparkle(x, y, n, col = '#fff6a8', spd = 6) { for (let i = 0; i < n; i++) { const a = rand(0, TAU), v = rand(1, spd); spawnP(2, x, y, Math.cos(a) * v, Math.sin(a) * v, rand(.35, .8), rand(6, 14), col, 0.02, 0, 0); } }
function dust(x, y, n, col = 'rgba(255,255,255,.7)') { for (let i = 0; i < n; i++) spawnP(3, x + rand(-8, 8), y + rand(-4, 4), rand(-2, 2), rand(-1.8, .2), rand(.4, .8), rand(8, 18), col, 0, 0, 0); }
function ringFx(x, y, s, col) { spawnP(6, x, y, 0, 0, 0.4, s, col, 0); }
const T = []; for (let i = 0; i < 24; i++) T.push({ on: 0, t: '', x: 0, y: 0, vy: 0, life: 0, max: 1, s: 30, c: '#fff' }); let tCur = 0;
function popText(txt, x, y, col = '#fff', s = 34) { const t = T[tCur]; tCur = (tCur + 1) % 24; t.on = 1; t.t = txt; t.x = clamp(x, 70, W - 70); t.y = Math.max(y, 60); t.vy = -1.3; t.life = 1; t.max = 1; t.s = s; t.c = col; }

// ------------------------------------------------------------------ world
function addB(...b) { Composite.add(world, b); }
function buildWorld() {
  S.over = false; S.started = false; S.pops = 0; S.downCount = 0; S.moves = 0; S.chaos = 0; S.gflip = 1; S.gTimer = 0; S.coinsEarned = 0; S.slow = 0; S.winPending = 0; S.time = 0;
  engine = Engine.create({ positionIterations: TUNE.pos, velocityIterations: TUNE.vel, constraintIterations: TUNE.con });
  world = engine.world; robots = []; props = []; ducks = []; bombs = []; obstacles = []; pointers.clear();
  const A = ARENAS[S.arena]; engine.gravity.y = A.gravity; engine.gravity.scale = 0.001;
  const wopt = { isStatic: true, friction: 0.5, restitution: A.wallRest, label: 'wall' };
  floorBody = Bodies.rectangle(W / 2, floorY + 250, W + 1200, 500, { isStatic: true, friction: A.fric, frictionStatic: A.fric, restitution: A.rest, label: 'floor' });
  addB(floorBody, Bodies.rectangle(-250, H / 2, 500, H * 4, wopt), Bodies.rectangle(W + 250, H / 2, 500, H * 4, wopt), Bodies.rectangle(W / 2, -250, W + 1200, 500, wopt));
  if (S.level) setupLevel(S.level); else setupDemo();
  Events.on(engine, 'collisionStart', onCollide);
}
function setupDemo() { spawnRobot(W * 0.4, 0, 0); spawnRobot(W * 0.62, 0, 1); }

// robot ----------------------------------------------------------------
const JOINTS = [
  ['neck', 'torso', [0, -30], 'head', [0, 19], 0.9],
  ['shL', 'torso', [-31, -22], 'uL', [7, -16], 3.0], ['shR', 'torso', [31, -22], 'uR', [-7, -16], 3.0],
  ['elL', 'uL', [0, 16], 'fL', [0, -19], 2.2], ['elR', 'uR', [0, 16], 'fR', [0, -19], 2.2],
  ['hipL', 'torso', [-14, 30], 'tL', [0, -17], 1.6], ['hipR', 'torso', [14, 30], 'tR', [0, -17], 1.6],
  ['knL', 'tL', [0, 17], 'sL', [0, -20], 1.9], ['knR', 'tR', [0, 17], 'sR', [0, -20], 1.9],
];
const LAYOUT = { head: [0, -49, 'head'], torso: [0, 0, 'torso'], uL: [-38, -6, 'arm'], uR: [38, -6, 'arm'], fL: [-38, 29, 'fore'], fR: [38, 29, 'fore'], tL: [-14, 47, 'thigh'], tR: [14, 47, 'thigh'], sL: [-14, 84, 'shin'], sR: [14, 84, 'shin'] };
const TUNE = { kp: 0.03, kd: 0.3, amax: 1.6, share: 0.35, anti: 0.8, lag: 34, grab: 0.22, pd: 1, stiff: 0.6, damp: 0.12, pos: 8, vel: 6, con: 10, limb: 1, torso: 1 };
const DENS = { head: 0.0016, torso: 0.0024, arm: 0.0013, fore: 0.0013, thigh: 0.0014, shin: 0.0014 };
const STAND_H = 104; // torso center to sole
function spawnRobot(x, y, slot, old) {
  const r = { id: robotSeq++, slot, parts: {}, joints: [], stun: 0, stand: 0, frozen: 0, charge: 0, mood: 0, happy: 0, latched: old ? old.latched : false, down: 0, held: 0, ci: slot, spawnX: x };
  const group = -r.id; const cy = y || (floorY - STAND_H - 2);
  for (const k in LAYOUT) {
    const [dx, dy, kind] = LAYOUT[k], pd = PART[kind];
    const b = Bodies.rectangle(x + dx, cy + dy, pd.w, pd.h, { chamfer: { radius: Math.min(pd.w, pd.h) * 0.32 }, density: DENS[kind] * (kind === 'torso' || kind === 'head' ? TUNE.torso : TUNE.limb), friction: 0.7, frictionStatic: 0.08, frictionAir: 0.014, restitution: 0.22, collisionFilter: { group }, label: 'part' });
    b.plugin = { robot: r, kind, key: k }; r.parts[k] = b;
  }
  for (const [name, pa, pA, pb, pB, lim] of JOINTS) {
    const A = r.parts[pa], B = r.parts[pb];
    const c = Constraint.create({ bodyA: A, pointA: { x: pA[0], y: pA[1] }, bodyB: B, pointB: { x: pB[0], y: pB[1] }, length: 0, stiffness: TUNE.stiff, damping: TUNE.damp });
    r.joints.push({ name, c, A, B, la: { x: pA[0], y: pA[1] }, lb: { x: pB[0], y: pB[1] }, lim, keep: /^(hip|kn|neck)/.test(name), strain: 0, broken: false, rel: 0, freeAt: 0 });
  }
  Composite.add(world, Object.values(r.parts)); Composite.add(world, r.joints.map((j) => j.c));
  robots.push(r); return r;
}
function killRobot(r) { Composite.remove(world, Object.values(r.parts)); for (const j of r.joints) if (!j.broken) Composite.remove(world, j.c); robots.splice(robots.indexOf(r), 1); }
function rebuildAll() {
  if (S.over) return;
  const old = robots.slice(); sfx('powerup', .7, 1.2, 100);
  for (const r of old) {
    const t = r.parts.torso, x = clamp(t.position.x, 70, W - 70), y = clamp(t.position.y, 130, floorY - STAND_H - 2);
    sparkle(t.position.x, t.position.y, 14, '#9ff4ff'); ringFx(t.position.x, t.position.y, 90, '#9ff4ff');
    killRobot(r); const n = spawnRobot(x, y, r.slot, r); n.ci = r.ci; n.stun = 0.3; n.happy = 1.2;
    Body.setVelocity(n.parts.torso, { x: 0, y: -3 });
  }
  popText('Rebuilt!', W / 2, floorY - 240, '#9ff4ff', 40);
}
function addBot() {
  if (robots.length >= 8) { toast('That is a lot of robots!'); return; }
  const r = spawnRobot(rand(W * .25, W * .75), 160, robotSeq, null); r.ci = robotSeq; sparkle(r.parts.torso.position.x, 160, 12); sfx('pop', .7);
}

// ------------------------------------------------------------------ levels
const LEVELS = [
  { id: 1, arena: 'lab', name: 'Bolt Popper', type: 'pop', goal: 3, robots: 1, time: 75, hint: 'Grab an arm or a leg and pull it far away. Stretch until it goes BOING!' },
  { id: 2, arena: 'lab', name: 'Ring Launch', type: 'ring', robots: 1, time: 80, ring: [0.82, 0.5], hint: 'Grab the robot, swing it back and fling it through the glowing ring!' },
  { id: 3, arena: 'lab', name: 'Domino Bots', type: 'knock', goal: 5, robots: 5, time: 80, hint: 'Fling a robot into the line to knock them all down.' },
  { id: 4, arena: 'space', name: 'Zero-G Pops', type: 'pop', goal: 5, robots: 2, time: 80, hint: 'Low gravity! Everything floats. Pop 5 bolts.' },
  { id: 5, arena: 'space', name: 'Moon Ring', type: 'ring', robots: 1, time: 85, ring: [0.16, 0.3], bumpers: [[0.5, 0.42, 46]], hint: 'Bounce off the bumper and through the ring up high!' },
  { id: 6, arena: 'space', name: 'Station Strike', type: 'knock', goal: 6, robots: 6, time: 85, hint: 'Knock down 6 robots on two shelves.' },
  { id: 7, arena: 'candy', name: 'Gummy Bounce', type: 'ring', robots: 1, time: 85, ring: [0.84, 0.32], tramps: [[0.5, 170]], hint: 'Use the trampoline to launch up to the ring!' },
  { id: 8, arena: 'candy', name: 'Sweet Pops', type: 'pop', goal: 6, robots: 2, time: 85, hint: 'Two bots, six bolts. Try the Toy Shelf tools!' },
  { id: 9, arena: 'candy', name: 'Candy Crash', type: 'knock', goal: 8, robots: 8, time: 90, hint: 'Knock down 8 robots. A cannon or bomb can help!' },
  { id: 10, arena: 'snow', name: 'Over the Wall', type: 'ring', robots: 1, time: 90, ring: [0.86, 0.5], walls: [[0.56, 330]], hint: 'Fling the robot over the wall and into the ring.' },
  { id: 11, arena: 'snow', name: 'Winter Pops', type: 'pop', goal: 8, robots: 3, time: 90, hint: 'Slippery floor! Pop 8 bolts.' },
  { id: 12, arena: 'snow', name: 'Big Knockdown', type: 'knock', goal: 10, robots: 10, time: 100, hint: 'Knock down all 10 robots. Try to do it in one big throw!' },
];
const LV = (id) => LEVELS.find((l) => l.id === id);
let ring = null;
function addStatic(b, kind, extra) { b.plugin = Object.assign({ kind }, extra || {}); addB(b); obstacles.push(Object.assign({ kind, body: b }, extra || {})); return b; }
function setupLevel(L) {
  ring = null;
  for (const [fx, h] of L.walls || []) addStatic(Bodies.rectangle(W * fx, floorY - h / 2, 46, h, { isStatic: true, friction: 0.4, restitution: 0.4, chamfer: { radius: 10 } }), 'wall', { w: 46, h });
  for (const [fx, fy, r] of L.bumpers || []) addStatic(Bodies.circle(W * fx, floorY * fy, r, { isStatic: true, restitution: 1.2 }), 'bumper', { r, pulse: 0, bumper: 1 });
  for (const [fx, w] of L.tramps || []) addStatic(Bodies.rectangle(W * fx, floorY - 14, w, 28, { isStatic: true, restitution: 0.4, chamfer: { radius: 8 } }), 'tramp', { w, pad: 1, boost: 24, pulse: 0 });
  if (L.type === 'ring') { ring = { x: W * L.ring[0], y: floorY * L.ring[1], rx: 30, ry: 84, glow: 0, hit: 0 }; spawnRobot(W * (L.ring[0] > 0.5 ? 0.17 : 0.8), 0, 0); }
  else if (L.type === 'pop') { const n = L.robots, sp = Math.min(240, (W - 160) / n); for (let i = 0; i < n; i++) spawnRobot(W / 2 + (i - (n - 1) / 2) * sp, 0, i); }
  else { // knock: rows of robots on ledges
    const x0 = W < 800 ? 80 : W * 0.36, x1 = W - 90, cap = Math.max(3, Math.floor((x1 - x0) / 82) + 1), rows = Math.ceil(L.robots / cap); let k = 0;
    for (let rw = 0; rw < rows; rw++) {
      const cnt = Math.min(cap, L.robots - k), sp = Math.min(86, (x1 - x0) / Math.max(1, cnt - 1)), ly = floorY - rw * 250;
      if (rw > 0) addStatic(Bodies.rectangle((x0 + x1) / 2 + 20, ly + 9, x1 - x0 + 120, 18, { isStatic: true, friction: 0.7, chamfer: { radius: 6 } }), 'ledge', { w: x1 - x0 + 120, h: 18 });
      for (let i = 0; i < cnt; i++) { const r = spawnRobot(x1 - i * sp - (rw % 2) * 30, ly - STAND_H - 2, k, null); r.ci = k; k++; }
    }
  }
  for (const r of robots) { r.baseY = r.parts.torso.position.y; r.ci = r.slot; if (S.mode === 'mission') r.stand = 1; }
  S.timeLeft = L.time;
}

// ------------------------------------------------------------------ collisions
let lastHit = 0;
function bodyKind(b) { return b.plugin ? b.plugin.kind : null; }
function onCollide(e) {
  for (const pair of e.pairs) {
    const a = pair.bodyA, b = pair.bodyB, pa = a.plugin, pb = b.plugin;
    const ra = pa && pa.robot, rb = pb && pb.robot;
    const rv = Math.hypot(a.velocity.x - b.velocity.x, a.velocity.y - b.velocity.y);
    const sp = pair.collision.supports && pair.collision.supports[0] ? pair.collision.supports[0] : a.position;
    // bounce surfaces
    for (const [s, d] of [[a, b], [b, a]]) {
      if (!s.isStatic || d.isStatic || !s.plugin) continue;
      const dp = d.plugin; if (!dp) { /* ducks/bombs also have plugin */ }
      if (s.plugin.bumper || s.plugin.pad) {
        const now = performance.now(); const tag = d.plugin || (d.plugin = {}); if (tag.bcd && now - tag.bcd < 140) continue; tag.bcd = now;
        let nx, ny, boost;
        if (s.plugin.pad) { nx = Math.sin(s.angle); ny = -Math.cos(s.angle); boost = s.plugin.boost; }
        else { nx = d.position.x - s.position.x; ny = d.position.y - s.position.y; const l = Math.hypot(nx, ny) || 1; nx /= l; ny /= l; boost = 15; }
        const k = S.arena === 'space' ? 0.78 : 1;
        Body.setVelocity(d, { x: d.velocity.x * 0.25 + nx * boost * k, y: d.velocity.y * 0.25 + ny * boost * k });
        s.plugin.pulse = 1; for (const o of obstacles) if (o.body === s) o.pulse = 1; for (const o of props) if (o.body === s) o.pulse = 1;
        sfx('boing', .8, rand(.9, 1.3), 90); sparkle(sp.x, sp.y, 8, '#fff6a8'); confetti(sp.x, sp.y, 6, 6); S.shake = Math.max(S.shake, 3); S.chaos = Math.min(1.2, S.chaos + .1);
        if (ra || rb) (ra || rb).stun = Math.max((ra || rb).stun, S.mode === 'mission' ? 1e9 : 2);
      }
    }
    const part = ra ? a : b; const r = ra || rb; if (!r) { if ((pa && pa.kind === 'duck') || (pb && pb.kind === 'duck')) { if (rv > 5) { sfx('squeak', .6, rand(.9, 1.5), 80); } } continue; }
    if (rv > 7) {
      const now = performance.now();
      const big = rv > 15;
      if (now - lastHit > 55) { lastHit = now; sfx(big ? 'hit' : 'pop', clamp(rv / 24, .25, .8), rand(.85, 1.25), 55); }
      S.chaos = Math.min(1.2, S.chaos + rv * 0.006);
      if (rv > 10) { spawnP(2, sp.x, sp.y, rand(-2, 2), rand(-2, 2), .3, rand(10, 18), '#fff6a8', 0, 0, 0); if (big) { dust(sp.x, sp.y, 3); S.shake = Math.max(S.shake, clamp(rv / 4, 2, 9)); } }
      if (rv > 22 && !r.frozen && S.mode !== 'demo' && Math.random() < (rv - 22) * 0.04) { const pr = part.plugin.robot; const jj = pr.joints.find((q) => q.B === part && !q.broken); if (jj) { const [qx, qy] = jointWorld(jj.A, jj.la); snapJoint(pr, jj, qx, qy); } }
      if (rv > 12 && !r.frozen) {
        for (const rr of [ra, rb]) if (rr && !rr.frozen) { rr.stun = Math.max(rr.stun, S.mode === 'mission' ? 1e9 : 2.6); rr.stand = 0; }
        if (rv > 20 && Math.random() < .35) popText(['BONK!', 'WHAM!', 'BOP!', 'THUNK!'][Math.random() * 4 | 0], sp.x, sp.y - 30, '#ffd23f', 30);
      }
    }
  }
}

// ------------------------------------------------------------------ tools forces & props
const pointers = new Map();
function power() { return 1 + 0.2 * save.up.power; }
function coinMult() { return 1 + 0.25 * save.up.coin; }
let dynList = [];
function allDyn() {
  dynList.length = 0;
  for (const r of robots) for (const k in r.parts) dynList.push(r.parts[k]);
  for (const d of ducks) dynList.push(d.body); for (const b of bombs) dynList.push(b.body);
  return dynList;
}
function stepForces() {
  const dyn = allDyn();
  for (const r of robots) if (r.held) { const gy = engine.gravity.y * engine.gravity.scale * TUNE.anti; for (const k in r.parts) { const b = r.parts[k]; Body.applyForce(b, b.position, { x: 0, y: -gy * b.mass }); } }
  for (const p of pointers.values()) if (p.grab) {
    const b = p.grab.body, r = b.plugin && b.plugin.robot, [hx, hy] = jointWorld(b, p.grab.lp);
    let tm = b.mass; if (r) { tm = 0; for (const k in r.parts) tm += r.parts[k].mass; }
    const meff = clamp(1 + (tm / b.mass - 1) * TUNE.share, 1, 9);
    let ax = TUNE.kp * (p.x - hx) - TUNE.kd * b.velocity.x, ay = TUNE.kp * (p.y - hy) - TUNE.kd * b.velocity.y; const am = Math.hypot(ax, ay), cap = TUNE.amax * (1 + 0.1 * save.up.grip);
    if (am > cap) { ax *= cap / am; ay *= cap / am; }
    Body.applyForce(b, { x: hx, y: hy }, { x: b.mass * meff * ax / 278, y: b.mass * meff * ay / 278 });
    if (Math.hypot(b.velocity.x, b.velocity.y) < 6) Body.setAngularVelocity(b, b.angularVelocity * 0.9);
  }
  for (const p of pointers.values()) {
    if (p.tool === 'magnet') {
      for (const b of dyn) {
        const dx = p.x - b.position.x, dy = p.y - b.position.y, d = Math.hypot(dx, dy);
        if (d < 320 && d > 1) { const f = (0.0022 * (1 - d / 320) + 0.0007) * b.mass * (S.arena === 'space' ? .8 : 1); Body.applyForce(b, b.position, { x: dx / d * f * (1 + 0.15 * save.up.power), y: dy / d * f - 0.001 * b.mass * S.gflip * 0.5 }); if (d < 150) Body.setVelocity(b, { x: b.velocity.x * 0.97, y: b.velocity.y * 0.97 }); }
      }
    }
  }
  for (const pr of props) {
    if (pr.kind === 'fan') {
      const dx = pr.dx, dy = pr.dy;
      for (const b of dyn) {
        const rx = b.position.x - pr.x, ry = b.position.y - pr.y, al = rx * dx + ry * dy, pe = Math.abs(rx * dy - ry * dx);
        if (al > 0 && al < 440 && pe < 70 + al * 0.25) { const f = 0.0026 * (1 - al / 460) * b.mass; Body.applyForce(b, b.position, { x: dx * f, y: dy * f }); }
      }
    } else if (pr.kind === 'belt' || pr.kind === 'ramp') {
      const hits = Query.collides(pr.body, dyn);
      for (const h of hits) {
        const b = h.bodyA === pr.body ? h.bodyB : h.bodyA;
        if (pr.kind === 'belt') { if (b.position.y < pr.y) Body.setVelocity(b, { x: b.velocity.x + (pr.dir * 7 - b.velocity.x) * 0.3, y: b.velocity.y }); }
        else { const sp = Math.hypot(b.velocity.x, b.velocity.y); if (sp < 24) Body.setVelocity(b, { x: b.velocity.x + pr.tx * 1.5, y: b.velocity.y + pr.ty * 1.5 }); pr.fire = 0.25; }
      }
    }
  }
}

function jointWorld(body, pt) { const c = Math.cos(body.angle), s = Math.sin(body.angle); return [body.position.x + pt.x * c - pt.y * s, body.position.y + pt.x * s + pt.y * c]; }
const GAIN = { torso: [0.03, 0.1], head: [0.025, 0.1], thigh: [0.034, 0.1], shin: [0.034, 0.1], arm: [0.012, 0.08], fore: [0.012, 0.08] };
const SNAP_WORDS = ['BOING!', 'SPROING!', 'POP!', 'TWANG!', 'POINK!'];
function snapJoint(r, j, wx, wy) {
  j.broken = true; Composite.remove(world, j.c);
  let nx = j.B.position.x - j.A.position.x, ny = j.B.position.y - j.A.position.y; const l = Math.hypot(nx, ny) || 1; nx /= l; ny /= l;
  Body.setVelocity(j.B, { x: j.B.velocity.x + nx * 7, y: j.B.velocity.y + ny * 7 - 4 }); Body.setVelocity(j.A, { x: j.A.velocity.x - nx * 2.5, y: j.A.velocity.y - ny * 2.5 });
  Body.setAngularVelocity(j.B, rand(-.3, .3));
  spawnP(4, wx, wy, nx * 5 + rand(-1, 1), ny * 5 - 6, 3, 1, '#c8d0e6', 0.28, rand(0, 6), rand(-.35, .35));
  bolts(wx, wy, 4); confetti(wx, wy, 16, 10, 5); sparkle(wx, wy, 8); ringFx(wx, wy, 110, '#ffffff');
  popText(SNAP_WORDS[Math.random() * 5 | 0], wx, wy - 40, '#ffd23f', 44);
  sfx('boing', 1, rand(.95, 1.35), 30); sfx('pop', .8, 1.1, 30);
  if (S.mode !== 'demo') { const gain = Math.round(3 * coinMult()); addCoins(gain, wx, wy - 6); }
  if (S.mode !== 'demo') { S.pops++; save.pops++; } S.chaos = Math.min(1.3, S.chaos + 0.4); S.shake = Math.max(S.shake, 8); S.slow = 0.14; r.happy = 1.5; r.stun = Math.max(r.stun, S.mode === 'mission' ? 1e9 : 3);
  for (const o of [j.A, j.B]) { const rr = o.plugin.robot; rr.stun = Math.max(rr.stun, S.mode === 'mission' ? 1e9 : 3); rr.stand = 0; }
  for (const p of pointers.values()) if (p.grab && (p.grab.body === j.B || p.grab.body === j.A)) { /* keep holding the popped part */ }
}
function postStep(dt) {
  S.time += dt;
  for (const r of robots) {
    if (r.stun > 0 && r.stun < 1e8) r.stun -= dt;
    if (r.happy > 0) r.happy -= dt;
    let held = false; for (const p of pointers.values()) if (p.grab && p.grab.body.plugin && p.grab.body.plugin.robot === r) held = true;
    r.held = held;
    if (held) { r.stun = Math.max(r.stun, 1.2); r.stand = 0; }
    if (r.frozen > 0) { r.frozen -= dt; if (r.frozen <= 0) thaw(r); }
    const standOK = r.stun <= 0 && !r.frozen && S.gflip > 0 && !held;
    r.stand = standOK ? Math.min(1, r.stand + 0.025) : 0;
    for (const k in r.parts) r.parts[k].plugin.jit = 0;
    for (const k in r.parts) {
      const b = r.parts[k];
      const sp = Math.hypot(b.velocity.x, b.velocity.y); if (sp > 38) { const f = 38 / sp; Body.setVelocity(b, { x: b.velocity.x * f, y: b.velocity.y * f }); }
      if (r.stand > 0) { const g = GAIN[b.plugin.kind]; const e = wrapA(b.angle); Body.setAngularVelocity(b, b.angularVelocity + TUNE.pd * r.stand * (-g[0] * e - g[1] * b.angularVelocity)); }
    }
    if (r.stand > 0.5) { // a gentle upward hop assist so feet stay under the body
      const t = r.parts.torso; const lowest = r.parts.sL.position.y + 20; if (lowest > floorY - 3 && t.position.y > r.parts.head.position.y) { /* grounded */ }
    }
    for (const j of r.joints) {
      if (j.broken) continue;
      const [ax, ay] = jointWorld(j.A, j.la), [bx, by] = jointWorld(j.B, j.lb);
      const d = Math.hypot(ax - bx, ay - by); j.d = d; j.ax = ax; j.ay = ay; j.bx = bx; j.by = by;
      j.strain = j.strain * 0.92 + (d > 26 ? (d - 26) : 0);
      { const ra = Math.max(clamp(j.strain / 170, 0, 1), j.pullR || 0); if (ra > (j.A.plugin.jit || 0)) j.A.plugin.jit = ra; if (ra > (j.B.plugin.jit || 0)) j.B.plugin.jit = ra; }
      if (!r.frozen && S.mode !== 'demo' && (j.strain > 170 || d > 110)) { snapJoint(r, j, (ax + bx) / 2, (ay + by) / 2); continue; }
      if (j.lim < 2.5) { const lim = j.keep ? j.lim + (0.1 - j.lim) * r.stand : j.lim; const rel = wrapA(j.B.angle - j.A.angle); if (Math.abs(rel) > lim) { Body.setAngle(j.B, j.A.angle + Math.sign(rel) * lim); { const [nx, ny] = jointWorld(j.B, j.lb); Body.translate(j.B, { x: ax - nx, y: ay - ny }); } Body.setAngularVelocity(j.B, j.A.angularVelocity * 0.6); } }
    }
    // lying down detection (for knock missions)
    const t = r.parts.torso; const lying = Math.abs(wrapA(t.angle)) > 1.1 || (r.baseY && t.position.y > r.baseY + 42);
    r.down = lying ? r.down + dt : 0;
    r.settled = r.stun >= 1e8;
    if (!r.latched && r.down > 0.3 && S.mode === 'mission') { r.latched = true; S.downCount++; popText('Down!', t.position.x, t.position.y - 70, '#9ff4ff', 32); sparkle(t.position.x, t.position.y, 6); sfx('pop', .6, 1.4); }
  }
  for (const r of robots) for (const j of r.joints) j.pullR = 0;
  for (const p of pointers.values()) {
    if (!p.grab) continue; const b = p.grab.body, r = b.plugin && b.plugin.robot; if (!r) continue;
    const [hx, hy] = jointWorld(b, p.grab.lp), g = Math.hypot(p.x - hx, p.y - hy);
    p.pull = Math.max(0, (p.pull || 0) + (g > TUNE.lag ? (g - TUNE.lag) * dt : -dt * 3));
    const j = r.joints.find((q) => q.B === b && !q.broken);
    if (j) { j.pullR = clamp(p.pull / 6, 0, 1); if (p.pull > 6 && !r.frozen && S.mode !== 'demo') { snapJoint(r, j, j.ax || hx, j.ay || hy); p.pull = 0; } }
  }
  for (let i = ducks.length - 1; i >= 0; i--) { const d = ducks[i]; d.life -= dt; const sp = Math.hypot(d.body.velocity.x, d.body.velocity.y); if (sp > 40) Body.setVelocity(d.body, { x: d.body.velocity.x * 40 / sp, y: d.body.velocity.y * 40 / sp }); if (d.life <= 0) { poof(d.body.position.x, d.body.position.y); Composite.remove(world, d.body); ducks.splice(i, 1); } }
  for (let i = bombs.length - 1; i >= 0; i--) { const b = bombs[i]; b.t -= dt; if (b.t <= 0) { explode(b); Composite.remove(world, b.body); bombs.splice(i, 1); } }
  for (const pr of props) { if (pr.pulse > 0) pr.pulse -= 0.06; if (pr.fire > 0) pr.fire -= dt; }
  for (const o of obstacles) if (o.pulse > 0) o.pulse -= 0.06;
  if (S.gTimer > 0) { S.gTimer -= dt; if (S.gTimer <= 0) setGravity(1); }
  // pointer tools that tick
  for (const p of pointers.values()) if (p.tool === 'freeze') freezeTick(p, dt);
  S.chaos = Math.max(0, S.chaos - dt * 0.22);
  if (S.mode === 'mission' && !S.over) checkMission(dt);
}
function poof(x, y) { dust(x, y, 6); sparkle(x, y, 6, '#ffd23f'); }
function thaw(r) {
  r.frozen = 0; for (const k in r.parts) { const b = r.parts[k]; b.restitution = 0.22; b.frictionAir = 0.014; b.friction = 0.7; }
  for (const j of r.joints) { j.c.stiffness = 0.9; j.c.damping = 0.14; }
  const t = r.parts.torso; sparkle(t.position.x, t.position.y, 14, '#bfefff'); ringFx(t.position.x, t.position.y, 100, '#bfefff'); popText('Thawed!', t.position.x, t.position.y - 80, '#bfefff', 30); sfx('sparkle', .7);
}
function freezeBot(r) {
  r.frozen = 7 * (1 + 0.15 * save.up.power); r.stun = 0; r.stand = 0; r.charge = 0;
  for (const k in r.parts) { const b = r.parts[k]; b.restitution = 0.95; b.frictionAir = 0.004; b.friction = 0.05; }
  for (const j of r.joints) { j.c.stiffness = 1; j.c.damping = 0.02; j.strain = 0; }
  const t = r.parts.torso; sparkle(t.position.x, t.position.y, 24, '#bfefff', 9); ringFx(t.position.x, t.position.y, 130, '#bfefff'); popText('Ice-pop!', t.position.x, t.position.y - 90, '#bfefff', 40); sfx('sparkle', 1, 1); S.shake = 5;
  Body.setVelocity(r.parts.torso, { x: rand(-5, 5), y: -9 });
}
function freezeTick(p, dt) {
  let best = null, bd = 90;
  for (const r of robots) for (const k in r.parts) { const b = r.parts[k]; const d = Math.hypot(b.position.x - p.x, b.position.y - p.y); if (d < bd) { bd = d; best = r; } }
  for (const r of robots) if (r !== best) r.charge = Math.max(0, r.charge - dt);
  if (best && !best.frozen) { best.charge += dt; if (Math.random() < .4) sparkle(best.parts.torso.position.x + rand(-30, 30), best.parts.torso.position.y + rand(-40, 40), 1, '#bfefff', 2); if (best.charge > 0.5) freezeBot(best); }
}
function explode(b) {
  const x = b.body.position.x, y = b.body.position.y, R = 240 * (1 + 0.1 * save.up.power), pw = power();
  confetti(x, y, 50, 14, 6); sparkle(x, y, 20, '#ffd23f', 10); ringFx(x, y, R * 0.8, '#ffe56a'); ringFx(x, y, R * 0.5, '#ff8ad8'); dust(x, y, 8);
  sfx('boom', .55, 1.4, 20); sfx('pop', .9, .8, 20); S.shake = 14; S.chaos = Math.min(1.3, S.chaos + .5); S.slow = 0.12;
  popText('BOOM!', x, y - 40, '#ff8ad8', 52);
  for (const bd of allDyn()) { if (bd === b.body) continue; const dx = bd.position.x - x, dy = bd.position.y - y, d = Math.hypot(dx, dy); if (d < R) { const f = (1 - d / R) * 22 * pw; const l = d || 1; Body.setVelocity(bd, { x: bd.velocity.x + dx / l * f, y: bd.velocity.y + dy / l * f - 4 }); const rr = bd.plugin && bd.plugin.robot; if (rr && !rr.frozen) { rr.stun = Math.max(rr.stun, S.mode === 'mission' ? 1e9 : 3); rr.stand = 0; if (S.mode !== 'demo' && Math.random() < 0.55 * (1 - d / R)) { const jj = rr.joints.find((q) => q.B === bd && !q.broken); if (jj) snapJoint(rr, jj, bd.position.x, bd.position.y); } } } }
}
function setGravity(dir) {
  S.gflip = dir; engine.gravity.y = ARENAS[S.arena].gravity * dir; if (dir < 0) S.gTimer = 6 * (1 + 0.15 * save.up.power); else S.gTimer = 0;
  for (const r of robots) { if (dir < 0) { r.stun = Math.max(r.stun, 2); r.stand = 0; } }
  sfx('whoosh', .9, dir < 0 ? 1.3 : .8); sparkle(W / 2, H / 2, 20, '#ff8ad8', 14); popText(dir < 0 ? 'Gravity flip!' : 'Gravity back!', W / 2, H * 0.3, '#ff8ad8', 44);
  S.shake = 6; refreshShelf();
}

// ------------------------------------------------------------------ mission logic
function checkMission(dt) {
  const L = S.level; if (!L) return;
  if (S.started) { S.timeLeft -= dt; }
  let done = false;
  if (L.type === 'pop') done = S.pops >= L.goal;
  else if (L.type === 'knock') done = S.downCount >= L.goal;
  else if (L.type === 'ring' && ring) {
    for (const r of robots) for (const k of ['torso', 'head']) { const b = r.parts[k]; const dx = (b.position.x - ring.x) / (ring.rx + 34), dy = (b.position.y - ring.y) / (ring.ry * 0.95); if (dx * dx + dy * dy < 1) done = true; }
    if (done) { ring.hit = 1; }
  }
  if (done) winMission(); else if (S.timeLeft <= 0) loseMission();
}

// ------------------------------------------------------------------ tools
const TOOLS = [
  { id: 'grab', name: 'Grab', price: 0, desc: 'Drag any part. Stretch it to pop it off. Fling it!' },
  { id: 'glove', name: 'Glove', price: 0, desc: 'Giant boxing glove. Tap or swipe to punch!' },
  { id: 'hammer', name: 'Hammer', price: 0, desc: 'Squeaky foam hammer. Tap to bonk!' },
  { id: 'bomb', name: 'Bouncy Bomb', price: 40, desc: 'Bounces, then bursts into confetti.' },
  { id: 'spring', name: 'Spring Pad', price: 60, desc: 'Tap to place a super boing pad.' },
  { id: 'duck', name: 'Duck Cannon', price: 80, desc: 'Fires rubber ducks. Tap or swipe to aim.' },
  { id: 'ramp', name: 'Rocket Ramp', price: 100, desc: 'A boosting skateboard ramp. Swipe to aim.' },
  { id: 'magnet', name: 'Magnet', price: 120, desc: 'Hold to pull everything toward you.' },
  { id: 'fan', name: 'Big Fan', price: 140, desc: 'Tap to place. Swipe to choose wind direction.' },
  { id: 'belt', name: 'Conveyor', price: 160, desc: 'Tap to place a belt. Tap it again to flip.' },
  { id: 'freeze', name: 'Freeze Ray', price: 200, desc: 'Hold on a robot to make a bouncy ice-pop!' },
  { id: 'gravity', name: 'Gravity Flip', price: 240, desc: 'Flip gravity upside down for a few seconds.' },
];
const fx = [];
function toolPower(id) { return power(); }
function pushImpulse(x, y, R, vx, vy, fall = 0.5, stunIt = true, popC = 0) {
  for (const b of allDyn()) {
    const dx = b.position.x - x, dy = b.position.y - y, d = Math.hypot(dx, dy); if (d > R) continue;
    if (popC && b.plugin && b.plugin.robot && S.mode !== 'demo' && Math.random() < popC * (1 - d / R)) { const rr = b.plugin.robot, jj = rr.joints.find((q) => q.B === b && !q.broken); if (jj && !rr.frozen) { const [qx, qy] = jointWorld(jj.A, jj.la); snapJoint(rr, jj, qx, qy); } }
    const f = 1 - (d / R) * fall; Body.setVelocity(b, { x: b.velocity.x + vx * f, y: b.velocity.y + vy * f });
    const rr = b.plugin && b.plugin.robot; if (rr && stunIt && !rr.frozen) { rr.stun = Math.max(rr.stun, S.mode === 'mission' ? 1e9 : 2.8); rr.stand = 0; }
  }
}
function stepFx(dt) {
  for (let i = fx.length - 1; i >= 0; i--) {
    const f = fx[i]; f.t += dt;
    if (f.kind === 'glove') {
      if (!f.hit && f.t >= 0.15) { f.hit = true; const pw = power(); pushImpulse(f.x, f.y, 120, f.dx * 20 * pw, f.dy * 20 * pw - 4, 0.55, true, 0.5); sfx('hit', .9, .8, 20); sfx('whoosh', .5, 1.2, 20); popText(['KAPOW!', 'POW!', 'WHAM!'][Math.random() * 3 | 0], f.x, f.y - 60, '#ff5d6c', 46); S.shake = 11; S.chaos = Math.min(1.3, S.chaos + .35); confetti(f.x, f.y, 14, 9); ringFx(f.x, f.y, 100, '#fff'); S.slow = 0.08; }
      if (f.t > 0.6) fx.splice(i, 1);
    } else if (f.kind === 'hammer') {
      if (!f.hit && f.t >= 0.2) { f.hit = true; const pw = power(); pushImpulse(f.x, f.y, 100, f.sx * 6 * pw, 18 * pw, 0.6, true, 0.45); sfx('squeak', 1, .7, 20); sfx('hit', .7, 1.1, 20); popText('BONK!', f.x, f.y - 60, '#ffd23f', 44); S.shake = 9; S.chaos = Math.min(1.3, S.chaos + .3); dust(f.x, f.y + 20, 6); ringFx(f.x, f.y, 90, '#ffd23f'); S.slow = 0.06; }
      if (f.t > 0.6) fx.splice(i, 1);
    } else if (f.kind === 'cannon') { if (f.t > 0.5) fx.splice(i, 1); }
  }
}
function startAction() { if (!S.started) { S.started = true; } }
function fireDuck(tx, ty, vx, vy, fromX, fromY) {
  if (ducks.length >= 8) { const o = ducks.shift(); Composite.remove(world, o.body); }
  const b = Bodies.circle(fromX, fromY, 17, { density: 0.004, restitution: 0.78, friction: 0.2, frictionAir: 0.004, label: 'duck' }); b.plugin = { kind: 'duck' };
  Body.setVelocity(b, { x: vx, y: vy }); addB(b); ducks.push({ body: b, life: 10 });
}
function useDirectional(tool, p, dx, dy, dragged) {
  const len = Math.hypot(dx, dy) || 1; let ux = dx / len, uy = dy / len;
  if (tool === 'glove') {
    if (!dragged) { ux = p.x < W / 2 ? 1 : -1; uy = -0.25; const l = Math.hypot(ux, uy); ux /= l; uy /= l; }
    fx.push({ kind: 'glove', x: p.x, y: p.y, dx: ux, dy: uy, t: 0, hit: false }); sfx('whoosh', .8, .9, 30);
  } else if (tool === 'duck') {
    const fromX = p.x < W / 2 ? W - 60 : 60, fromY = floorY - 40; let vx, vy;
    if (dragged) { const sp = clamp(len * 0.11, 16, 34); vx = ux * sp; vy = uy * sp; }
    else { const tx = p.x - fromX, ty = p.y - fromY, dist = Math.hypot(tx, ty), sp = 27, t = dist / sp, gs = engine.gravity.y * 0.278; vx = tx / dist * sp; vy = ty / dist * sp - 0.5 * gs * t; }
    fireDuck(p.x, p.y, vx, vy, fromX, fromY); fx.push({ kind: 'cannon', x: fromX, y: fromY, a: Math.atan2(vy, vx), t: 0 }); sfx('pop', .8, 1.3, 20); sfx('squeak', .6, 1.6, 20); sparkle(fromX, fromY, 6, '#ffd23f');
  } else if (tool === 'ramp') {
    const pr = props.find((o) => o.kind === 'ramp' && Math.hypot(o.x - p.x, o.y - p.y) < 110);
    if (pr) { removeProp(pr); return; }
    const dir = dragged ? (ux >= 0 ? 1 : -1) : (p.x < W / 2 ? 1 : -1); const ang = dir > 0 ? -0.5 : 0.5;
    const b = Bodies.rectangle(p.x, p.y, 200, 18, { isStatic: true, angle: ang, friction: 0.15, restitution: 0.1, chamfer: { radius: 8 } });
    addProp({ kind: 'ramp', body: b, x: p.x, y: p.y, dir, tx: dir * 0.88, ty: -0.48, ang, fire: 0 }); sfx('powerup', .6, .8, 50);
  } else if (tool === 'fan') {
    const pr = props.find((o) => o.kind === 'fan' && Math.hypot(o.x - p.x, o.y - p.y) < 90);
    if (pr) { removeProp(pr); return; }
    let ddx = 0, ddy = -1; if (dragged) { ddx = ux; ddy = uy; } else if (p.y < H * 0.35) { ddx = p.x < W / 2 ? 1 : -1; ddy = 0; }
    addProp({ kind: 'fan', body: null, x: p.x, y: p.y, dx: ddx, dy: ddy, spin: 0 }); sfx('whoosh', .5, .6, 50);
  }
}
function addProp(pr) {
  const same = props.filter((o) => o.kind === pr.kind); if (same.length >= 3) removeProp(same[0]);
  pr.pulse = 0; if (pr.body) { if (!pr.body.plugin) pr.body.plugin = {}; if (pr.kind === 'spring') Object.assign(pr.body.plugin, { pad: 1, boost: 24, pulse: 0 }); addB(pr.body); }
  props.push(pr); sparkle(pr.x, pr.y, 10, '#fff6a8'); ringFx(pr.x, pr.y, 70, '#fff');
}
function removeProp(pr) { if (pr.body) Composite.remove(world, pr.body); props.splice(props.indexOf(pr), 1); poof(pr.x, pr.y); sfx('click', .6, 1.4, 30); }
function toolDownAt(tool, p) {
  if (tool === 'hammer') { fx.push({ kind: 'hammer', x: p.x, y: p.y, t: 0, hit: false, sx: p.x < W / 2 ? 1 : -1 }); sfx('swish', .8, 1, 30); startAction(); S.moves++; }
  else if (tool === 'bomb') {
    if (bombs.length >= 5) { const o = bombs.shift(); Composite.remove(world, o.body); }
    const b = Bodies.circle(p.x, p.y, 21, { density: 0.003, restitution: 0.85, friction: 0.3, frictionAir: 0.004, label: 'bomb' }); b.plugin = { kind: 'bomb' }; addB(b); bombs.push({ body: b, t: 1.7 }); Body.setVelocity(b, { x: rand(-2, 2), y: -4 }); sfx('pop', .8, 1.3, 30); startAction(); S.moves++;
  } else if (tool === 'spring') {
    const pr = props.find((o) => o.kind === 'spring' && Math.hypot(o.x - p.x, o.y - p.y) < 80); if (pr) { removeProp(pr); return; }
    const y = p.y > floorY - 70 ? floorY - 10 : p.y; const b = Bodies.rectangle(p.x, y, 110, 20, { isStatic: true, restitution: 0.3, chamfer: { radius: 8 } });
    addProp({ kind: 'spring', body: b, x: p.x, y }); sfx('boing', .8, 1.2, 30); startAction(); S.moves++;
  } else if (tool === 'belt') {
    const pr = props.find((o) => o.kind === 'belt' && Math.abs(o.x - p.x) < 130 && Math.abs(o.y - p.y) < 40);
    if (pr) { pr.dir *= -1; sfx('click', .7, 1.2, 30); popText(pr.dir > 0 ? 'Right!' : 'Left!', pr.x, pr.y - 40, '#fff', 28); return; }
    const b = Bodies.rectangle(p.x, p.y, 240, 26, { isStatic: true, friction: 1, restitution: 0.1, chamfer: { radius: 12 } });
    addProp({ kind: 'belt', body: b, x: p.x, y: p.y, dir: p.x < W / 2 ? 1 : -1, off: 0 }); sfx('powerup', .6, .9, 50); startAction(); S.moves++;
  }
}

// ------------------------------------------------------------------ pointer input
function toWorld(e) { return { x: e.clientX / scale, y: e.clientY / scale }; }
function findPart(p) {
  let best = null, bd = clamp(46 / scale, 40, 84);
  const cand = (b, rad) => { const d = Math.hypot(b.position.x - p.x, b.position.y - p.y) - rad; if (d < bd) { bd = d; best = b; } };
  for (const r of robots) for (const k in r.parts) { const b = r.parts[k], pd = PART[b.plugin.kind]; cand(b, (pd.w + pd.h) / 4); }
  for (const d of ducks) cand(d.body, 17); for (const b of bombs) cand(b.body, 20);
  return best;
}
function tryGrab(pt, p) {
  const b = findPart(p); if (!b) { sparkle(p.x, p.y, 4, '#ffffff', 3); return false; }
  const c = Math.cos(-b.angle), s = Math.sin(-b.angle), dx = p.x - b.position.x, dy = p.y - b.position.y;
  pt.grab = { body: b, lp: { x: dx * c - dy * s, y: dx * s + dy * c } }; pt.pull = 0; sfx('squeak', .45, rand(1, 1.6), 60);
  const r = b.plugin && b.plugin.robot; if (r) { r.stun = Math.max(r.stun, 1.2); r.stand = 0; r.happy = 0.6; }
  startAction(); return true;
}
function releaseGrab(pt) {
  if (!pt.grab) return; const { body } = pt.grab;
  const g = 1.0 + 0.1 * save.up.grip, vx = clamp(pt.vx * g, -36, 36), vy = clamp(pt.vy * g, -36, 36);
  if (Math.hypot(vx, vy) > 3) { Body.setVelocity(body, { x: vx, y: vy }); if (Math.hypot(vx, vy) > 14) { sfx('whoosh', .5, rand(.9, 1.3), 80); S.chaos = Math.min(1.2, S.chaos + .15); } }
  S.moves++; pt.grab = null;
}
function inputBlocked() { return S.screen !== 'play' || S.paused || S.over || S.hintOpen; }
canvas.addEventListener('pointerdown', (e) => {
  e.preventDefault(); if (inputBlocked()) return; try { canvas.setPointerCapture(e.pointerId); } catch (_) { /* ignore */ }
  try { music.unlock(); } catch (_) { /* ignore */ }
  const p = toWorld(e); const pt = { id: e.pointerId, x: p.x, y: p.y, sx: p.x, sy: p.y, vx: 0, vy: 0, t: performance.now(), tool: S.tool, grab: null, moved: 0 };
  pointers.set(e.pointerId, pt);
  if (pt.tool === 'grab') tryGrab(pt, p);
  else if (pt.tool === 'magnet') { startAction(); sfx('powerup', .5, 1.4, 100); S.moves++; }
  else if (pt.tool === 'freeze') { startAction(); sfx('sparkle', .6, 1, 100); }
  else if (['hammer', 'bomb', 'spring', 'belt'].includes(pt.tool)) toolDownAt(pt.tool, p);
});
canvas.addEventListener('pointermove', (e) => {
  const pt = pointers.get(e.pointerId); if (!pt) return; e.preventDefault();
  const p = toWorld(e); const now = performance.now(), steps = Math.max(0.5, (now - pt.t) / 16.667);
  pt.vx += ((p.x - pt.x) / steps - pt.vx) * 0.5; pt.vy += ((p.y - pt.y) / steps - pt.vy) * 0.5; pt.t = now;
  pt.moved += Math.hypot(p.x - pt.x, p.y - pt.y); pt.x = p.x; pt.y = p.y;
});
function endPointer(e) {
  const pt = pointers.get(e.pointerId); if (!pt) return; pointers.delete(e.pointerId);
  if (pt.grab) { const now = performance.now(); if (now - pt.t > 90) { pt.vx *= 0.3; pt.vy *= 0.3; } releaseGrab(pt); }
  else if (['glove', 'duck', 'ramp', 'fan'].includes(pt.tool) && e.type === 'pointerup') {
    const dx = pt.x - pt.sx, dy = pt.y - pt.sy, dragged = Math.hypot(dx, dy) > 45; startAction(); S.moves++; useDirectional(pt.tool, { x: dragged ? pt.sx : pt.x, y: dragged ? pt.sy : pt.y }, dx, dy, dragged);
  }
}
canvas.addEventListener('pointerup', endPointer); canvas.addEventListener('pointercancel', endPointer);
canvas.addEventListener('contextmenu', (e) => e.preventDefault());
['gesturestart', 'gesturechange', 'dblclick'].forEach((n) => document.addEventListener(n, (e) => e.preventDefault()));
document.addEventListener('touchmove', (e) => { if (!e.target.closest('.scroll,#shelf')) e.preventDefault(); }, { passive: false });

// ------------------------------------------------------------------ rendering
function rrPath(g, x, y, w, h, r) { g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath(); }
function drawSpring(x1, y1, x2, y2, ratio) {
  const dx = x2 - x1, dy = y2 - y1, l = Math.hypot(dx, dy); if (l < 2.5) return;
  const nx = -dy / l, ny = dx / l, n = Math.max(4, Math.round(l / 5)), w = clamp(8 - l * 0.08, 3, 7);
  ctx.beginPath(); ctx.moveTo(x1, y1); for (let i = 1; i < n; i++) { const t = i / n, o = (i % 2 ? 1 : -1) * w; ctx.lineTo(x1 + dx * t + nx * o, y1 + dy * t + ny * o); } ctx.lineTo(x2, y2);
  ctx.lineWidth = 6; ctx.strokeStyle = '#3a3a66'; ctx.stroke();
  ctx.lineWidth = 3.4; ctx.strokeStyle = ratio > 0.4 ? (ratio > 0.75 ? '#ff5d6c' : '#ffb347') : '#e6ebf8'; ctx.stroke();
}
function drawPart(b, spr, jit) {
  const vx = b.velocity.x, vy = b.velocity.y, sp = Math.hypot(vx, vy), k = Math.min(sp / 45, 0.16);
  ctx.save(); ctx.translate(b.position.x, b.position.y);
  if (k > 0.02) { const va = Math.atan2(vy, vx); ctx.rotate(va); ctx.scale(1 + k, 1 - k * 0.7); ctx.rotate(b.angle - va); } else ctx.rotate(b.angle);
  if (jit > 0.3) ctx.rotate(Math.sin(S.time * 70 + b.id) * 0.06 * jit);
  ctx.drawImage(spr.c, -spr.uw / 2, -spr.uh / 2, spr.uw, spr.uh); ctx.restore();
}
const ORDER = [['uL', 'arm'], ['fL', 'fore'], ['tL', 'thigh'], ['sL', 'shin'], ['tR', 'thigh'], ['sR', 'shin'], ['torso', 'torso'], ['head', 'head'], ['uR', 'arm'], ['fR', 'fore']];
function drawRobot(r) {
  const spr = getSprites(save.skin, r.ci), ice = r.frozen > 0;
  const t = r.parts.torso, h = Math.max(0, floorY - t.position.y - 40); // shadow
  ctx.fillStyle = 'rgba(20,10,60,' + (0.28 * clamp(1 - h / 700, 0, 1)) + ')'; ctx.beginPath(); ctx.ellipse(t.position.x, floorY + 5, 56 * clamp(1 - h / 1200, .5, 1), 9, 0, 0, TAU); ctx.fill();
  for (const j of r.joints) {
    if (j.broken) {
      for (const [bd, pt] of [[j.A, j.la], [j.B, j.lb]]) { const [x, y] = jointWorld(bd, pt); ctx.fillStyle = '#26214d'; ctx.beginPath(); ctx.arc(x, y, 5, 0, TAU); ctx.fill(); ctx.strokeStyle = '#cfd6e6'; ctx.lineWidth = 2; ctx.stroke(); ctx.fillStyle = '#9aa3c4'; ctx.beginPath(); ctx.arc(x, y, 1.8, 0, TAU); ctx.fill(); }
    } else if (j.d > 2.5) drawSpring(j.ax, j.ay, j.bx, j.by, Math.max(clamp(j.strain / 170, 0, 1), j.pullR || 0));
  }
  const mood = r.frozen > 0 ? 'head' : (r.stun > 0.15 && !r.held ? 'headDizzy' : (r.happy > 0 || r.held ? 'headHappy' : 'head'));
  for (const [k, kind] of ORDER) { let s = kind === 'head' ? spr[mood] : spr[kind]; if (ice) s = getIce(k, s); drawPart(r.parts[k], s, r.parts[k].plugin.jit || 0); }
  if (ice) { const x = t.position.x, y = t.position.y; ctx.globalAlpha = .55 + .45 * Math.sin(S.time * 8); ctx.fillStyle = '#fff'; for (let i = 0; i < 3; i++) { const a = S.time * 2 + i * 2.1; ctx.beginPath(); const sx = x + Math.cos(a) * 46, sy = y + Math.sin(a * 1.3) * 60; ctx.moveTo(sx, sy - 6); ctx.lineTo(sx + 2, sy - 2); ctx.lineTo(sx + 6, sy); ctx.lineTo(sx + 2, sy + 2); ctx.lineTo(sx, sy + 6); ctx.lineTo(sx - 2, sy + 2); ctx.lineTo(sx - 6, sy); ctx.lineTo(sx - 2, sy - 2); ctx.fill(); } ctx.globalAlpha = 1; }
}
function grad(g, x0, y0, x1, y1, a, b) { const q = g.createLinearGradient(x0, y0, x1, y1); q.addColorStop(0, a); q.addColorStop(1, b); return q; }
function drawObstacles() {
  for (const o of obstacles) {
    const b = o.body, x = b.position.x, y = b.position.y;
    if (o.kind === 'wall') { ctx.fillStyle = grad(ctx, x - 23, 0, x + 23, 0, '#ffb347', '#e0791a'); rrPath(ctx, x - 23, y - o.h / 2, 46, o.h, 12); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = '#8a4a0c'; ctx.stroke(); ctx.fillStyle = 'rgba(255,255,255,.35)'; for (let yy = y - o.h / 2 + 24; yy < y + o.h / 2 - 10; yy += 44) { rrPath(ctx, x - 14, yy, 28, 12, 6); ctx.fill(); } }
    else if (o.kind === 'ledge') { ctx.fillStyle = grad(ctx, 0, y - 9, 0, y + 9, '#9a7bff', '#6a47d0'); rrPath(ctx, x - o.w / 2, y - 9, o.w, 18, 8); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = '#3d2590'; ctx.stroke(); ctx.fillStyle = 'rgba(255,255,255,.3)'; ctx.fillRect(x - o.w / 2 + 12, y - 5, o.w - 24, 3); }
    else if (o.kind === 'bumper') { const s = 1 + Math.max(0, o.pulse) * 0.22; ctx.save(); ctx.translate(x, y); ctx.scale(s, s); const gr = ctx.createRadialGradient(-o.r * .3, -o.r * .3, 4, 0, 0, o.r); gr.addColorStop(0, '#ff9ad0'); gr.addColorStop(1, '#e0307f'); ctx.fillStyle = gr; ctx.beginPath(); ctx.arc(0, 0, o.r, 0, TAU); ctx.fill(); ctx.lineWidth = 5; ctx.strokeStyle = '#fff'; ctx.stroke(); ctx.lineWidth = 3; ctx.strokeStyle = '#8a1d52'; ctx.beginPath(); ctx.arc(0, 0, o.r + 3, 0, TAU); ctx.stroke(); ctx.fillStyle = '#fff'; ctx.beginPath(); for (let i = 0; i < 10; i++) { const a = -1.57 + i * .628, rd = i % 2 ? o.r * .22 : o.r * .5; ctx.lineTo(Math.cos(a) * rd, Math.sin(a) * rd); } ctx.closePath(); ctx.fill(); ctx.restore(); }
    else if (o.kind === 'tramp') { const sq = Math.max(0, o.pulse) * 10; ctx.fillStyle = '#5a5f8a'; for (const dx of [-o.w * .38, o.w * .38]) { ctx.fillRect(x + dx - 6, y + 4, 12, 24); } ctx.fillStyle = grad(ctx, 0, y - 14 + sq, 0, y + 4, '#5ee0ff', '#2a9ad8'); rrPath(ctx, x - o.w / 2, y - 14 + sq, o.w, 16, 8); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = '#17608a'; ctx.stroke(); ctx.fillStyle = '#fff'; for (let i = -2; i <= 2; i++) { ctx.fillRect(x + i * o.w * .17 - 8, y - 9 + sq, 16, 4); } }
  }
}
function drawProps() {
  for (const pr of props) {
    const x = pr.x, y = pr.y;
    if (pr.kind === 'belt') {
      pr.off = (pr.off + pr.dir * 0.9) % 30; ctx.fillStyle = '#39406a'; rrPath(ctx, x - 120, y - 13, 240, 26, 13); ctx.fill(); ctx.save(); rrPath(ctx, x - 118, y - 11, 236, 22, 11); ctx.clip(); ctx.fillStyle = '#ffd23f'; for (let i = -10; i < 12; i++) { const px = x - 120 + i * 30 + pr.off; ctx.beginPath(); ctx.moveTo(px, y - 11); ctx.lineTo(px + 14, y - 11); ctx.lineTo(px + 14 + pr.dir * 8, y); ctx.lineTo(px + 14, y + 11); ctx.lineTo(px, y + 11); ctx.lineTo(px + pr.dir * 8, y); ctx.fill(); } ctx.restore(); ctx.lineWidth = 3; ctx.strokeStyle = '#1b1f42'; rrPath(ctx, x - 120, y - 13, 240, 26, 13); ctx.stroke(); for (const dx of [-110, 110]) { ctx.fillStyle = '#9aa3c4'; ctx.beginPath(); ctx.arc(x + dx, y, 9, 0, TAU); ctx.fill(); ctx.stroke(); }
    } else if (pr.kind === 'ramp') {
      ctx.save(); ctx.translate(x, y); ctx.rotate(pr.ang); ctx.fillStyle = grad(ctx, 0, -9, 0, 9, '#ff9a54', '#e0501a'); rrPath(ctx, -100, -9, 200, 18, 9); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = '#7a2a08'; ctx.stroke(); ctx.fillStyle = '#fff'; for (let i = -3; i <= 3; i++) ctx.fillRect(i * 26 - 5, -3, 10, 6);
      const bx = -pr.dir * 100; ctx.fillStyle = '#8a93b8'; ctx.beginPath(); ctx.arc(pr.dir * 70, 14, 9, 0, TAU); ctx.arc(-pr.dir * 70, 14, 9, 0, TAU); ctx.fill();
      const fl = (pr.fire > 0 ? 1 : 0.5) * (0.8 + 0.3 * Math.sin(S.time * 40)); ctx.fillStyle = '#ffd23f'; ctx.beginPath(); ctx.moveTo(bx, -6); ctx.lineTo(bx - pr.dir * (24 + 30 * fl), 0); ctx.lineTo(bx, 6); ctx.fill(); ctx.fillStyle = '#ff5d6c'; ctx.beginPath(); ctx.moveTo(bx, -3); ctx.lineTo(bx - pr.dir * (14 + 18 * fl), 0); ctx.lineTo(bx, 3); ctx.fill(); ctx.restore();
    } else if (pr.kind === 'spring') {
      const sq = Math.max(0, pr.pulse) * 12; ctx.fillStyle = '#2fae6e'; rrPath(ctx, x - 55, y + 4, 110, 8, 4); ctx.fill(); ctx.lineWidth = 6; ctx.strokeStyle = '#6d7497'; ctx.lineJoin = 'round'; ctx.beginPath(); ctx.moveTo(x - 30, y + 4); for (let i = 0; i < 4; i++) { ctx.lineTo(x + 30, y + 4 - (i + .5) * (3.2 - sq * .12)); ctx.lineTo(x - 30, y + 4 - (i + 1) * (3.2 - sq * .12)); } ctx.stroke();
      ctx.fillStyle = grad(ctx, 0, y - 10 + sq, 0, y + 2 + sq, '#ffa45a', '#ec6a1f'); rrPath(ctx, x - 55, y - 10 + sq, 110, 14, 7); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = '#7a3208'; ctx.stroke(); ctx.fillStyle = 'rgba(255,255,255,.5)'; ctx.fillRect(x - 40, y - 6 + sq, 40, 3);
    } else if (pr.kind === 'fan') {
      pr.spin += 0.5; ctx.save(); ctx.translate(x, y);
      ctx.strokeStyle = 'rgba(255,255,255,.55)'; ctx.lineWidth = 4; ctx.lineCap = 'round'; for (let i = 0; i < 6; i++) { const o = ((S.time * 260 + i * 70) % 420), sd = (i % 3 - 1) * 26; ctx.globalAlpha = 1 - o / 420; ctx.beginPath(); ctx.moveTo(pr.dx * o - pr.dy * sd, pr.dy * o + pr.dx * sd); ctx.lineTo(pr.dx * (o + 30) - pr.dy * sd, pr.dy * (o + 30) + pr.dx * sd); ctx.stroke(); } ctx.globalAlpha = 1;
      ctx.fillStyle = '#7a86a8'; rrPath(ctx, -14, 20, 28, 24, 6); ctx.fill(); ctx.fillStyle = '#e8fbff'; ctx.strokeStyle = '#2a3866'; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(0, 0, 32, 0, TAU); ctx.fill(); ctx.stroke();
      ctx.rotate(pr.spin); ctx.fillStyle = '#4aa8ff'; for (let i = 0; i < 3; i++) { ctx.rotate(TAU / 3); ctx.beginPath(); ctx.ellipse(0, -15, 8, 16, 0, 0, TAU); ctx.fill(); } ctx.fillStyle = '#ffd23f'; ctx.beginPath(); ctx.arc(0, 0, 7, 0, TAU); ctx.fill(); ctx.restore();
      ctx.save(); ctx.translate(x, y); ctx.fillStyle = '#ff5d9e'; ctx.rotate(Math.atan2(pr.dy, pr.dx)); ctx.beginPath(); ctx.moveTo(40, 0); ctx.lineTo(30, -7); ctx.lineTo(30, 7); ctx.fill(); ctx.restore();
    }
  }
}
function drawBombs() {
  for (const b of bombs) {
    const x = b.body.position.x, y = b.body.position.y, p = 1 - b.t / 1.7, s = 1 + Math.sin(S.time * (10 + p * 30)) * 0.08 * (1 + p);
    ctx.save(); ctx.translate(x, y); ctx.rotate(b.body.angle); ctx.scale(s, s); const gr = ctx.createRadialGradient(-7, -8, 2, 0, 0, 22); gr.addColorStop(0, p > 0.6 && Math.sin(S.time * 40) > 0 ? '#ffe9f8' : '#d6a8ff'); gr.addColorStop(1, '#8a45e8'); ctx.fillStyle = gr; ctx.beginPath(); ctx.arc(0, 0, 21, 0, TAU); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = '#4a1f9a'; ctx.stroke();
    ctx.strokeStyle = 'rgba(255,255,255,.7)'; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(0, 0, 13, 3.6, 4.8); ctx.stroke(); ctx.fillStyle = '#ffd23f'; ctx.fillRect(-4, -28, 8, 9); ctx.restore();
    spawnP(2, x + 4, y - 30, rand(-1, 1), rand(-2, 0), .3, 8, '#ffd23f', 0, 0, 0);
  }
  for (const d of ducks) {
    const x = d.body.position.x, y = d.body.position.y; ctx.save(); ctx.translate(x, y); ctx.rotate(d.body.angle * .6); const sq = Math.min(Math.hypot(d.body.velocity.x, d.body.velocity.y) / 50, .2); ctx.scale(1 + sq, 1 - sq);
    ctx.fillStyle = '#ffd23f'; ctx.strokeStyle = '#b87a00'; ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(0, 2, 17, 0, TAU); ctx.fill(); ctx.stroke(); ctx.beginPath(); ctx.arc(6, -14, 10, 0, TAU); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#ff8a3c'; ctx.beginPath(); ctx.ellipse(18, -12, 7, 4, 0, 0, TAU); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#2a2260'; ctx.beginPath(); ctx.arc(8, -16, 2.2, 0, TAU); ctx.fill(); ctx.fillStyle = '#ffe98a'; ctx.beginPath(); ctx.ellipse(-6, 4, 8, 6, .4, 0, TAU); ctx.fill(); ctx.restore();
  }
}
function drawRing(front) {
  if (!ring) return; const { x, y, rx, ry } = ring; const g = 0.5 + 0.5 * Math.sin(S.time * 4);
  ctx.save(); ctx.translate(x, y); ctx.lineCap = 'butt';
  if (!front) { ctx.fillStyle = 'rgba(255,230,120,' + (0.14 + 0.1 * g + ring.hit * .3) + ')'; ctx.beginPath(); ctx.ellipse(0, 0, rx + 26, ry + 22, 0, 0, TAU); ctx.fill(); }
  const half = front ? [Math.PI / 2, Math.PI * 1.5] : [-Math.PI / 2, Math.PI / 2];
  for (const [w, col] of [[20, '#8a2d7a'], [14, '#ff5d9e']]) { ctx.lineWidth = w; ctx.strokeStyle = col; ctx.beginPath(); ctx.ellipse(0, 0, rx, ry, 0, half[0], half[1]); ctx.stroke(); }
  ctx.lineWidth = 6; ctx.strokeStyle = '#ffe56a'; ctx.setLineDash([16, 16]); ctx.lineDashOffset = -S.time * 30; ctx.beginPath(); ctx.ellipse(0, 0, rx, ry, 0, half[0], half[1]); ctx.stroke(); ctx.setLineDash([]);
  if (!front) { ctx.fillStyle = '#ffd23f'; ctx.strokeStyle = '#a56f00'; ctx.lineWidth = 3; ctx.beginPath(); for (let i = 0; i < 10; i++) { const a = -1.57 + i * .628, rd = i % 2 ? 8 : 18; ctx.lineTo(Math.cos(a) * rd, -ry - 36 + Math.sin(a) * rd - 4 * g); } ctx.closePath(); ctx.fill(); ctx.stroke(); }
  ctx.restore();
}
function drawFx() {
  for (const f of fx) {
    if (f.kind === 'glove') {
      const t = f.t, k = t < 0.15 ? 1 - Math.pow(1 - t / 0.15, 3) : 1 - clamp((t - 0.25) / 0.3, 0, 1), dist = 360 * (1 - k); const x = f.x - f.dx * dist, y = f.y - f.dy * dist;
      ctx.save(); ctx.translate(x, y); ctx.rotate(Math.atan2(f.dy, f.dx)); ctx.globalAlpha = clamp(k * 3, 0, 1);
      ctx.fillStyle = '#fff'; rrPath(ctx, -118, -30, 56, 60, 10); ctx.fill(); ctx.lineWidth = 4; ctx.strokeStyle = '#2a2260'; ctx.stroke(); ctx.fillStyle = '#ff5d6c'; ctx.beginPath(); ctx.moveTo(-70, -34); ctx.quadraticCurveTo(-70, -66, -20, -62); ctx.quadraticCurveTo(46, -64, 58, -22); ctx.quadraticCurveTo(66, 24, 30, 46); ctx.quadraticCurveTo(-20, 60, -70, 36); ctx.closePath(); ctx.fill(); ctx.stroke();
      ctx.fillStyle = '#ff8fa0'; ctx.beginPath(); ctx.ellipse(-8, -40, 34, 14, -.1, 0, TAU); ctx.fill(); ctx.strokeStyle = '#c23a50'; ctx.lineWidth = 4; ctx.beginPath(); ctx.moveTo(20, -4); ctx.quadraticCurveTo(46, 2, 30, 26); ctx.stroke(); ctx.restore(); ctx.globalAlpha = 1;
    } else if (f.kind === 'hammer') {
      const px = f.x + f.sx * 120, py = f.y - 200, len = Math.hypot(f.x - px, f.y - py) + 30, base = Math.atan2(f.y - py, f.x - px), t = f.t, k = t < 0.2 ? Math.pow(t / 0.2, 2) : 1, rec = t > 0.3 ? clamp((t - 0.3) / 0.3, 0, 1) : 0, ang = base - (1 - k) * 1.8 * f.sx - rec * 1.2 * f.sx;
      ctx.save(); ctx.translate(px, py); ctx.rotate(ang - Math.PI / 2 + Math.PI / 2); ctx.globalAlpha = 1 - rec;
      ctx.fillStyle = '#d19a5a'; ctx.strokeStyle = '#6a4216'; ctx.lineWidth = 4; rrPath(ctx, -6, 0, len - 30, 12, 6); ctx.fill(); ctx.stroke(); ctx.translate(len - 30, 6); const sq = t > 0.2 && t < 0.35 ? 0.88 : 1; ctx.scale(1, sq);
      ctx.fillStyle = grad(ctx, 0, -40, 0, 40, '#ffe56a', '#ffb02e'); rrPath(ctx, -26, -42, 62, 84, 22); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#ff8a3c'; ctx.fillRect(-12, -40, 10, 80); ctx.fillRect(14, -40, 10, 80); ctx.restore(); ctx.globalAlpha = 1;
    } else if (f.kind === 'cannon') {
      ctx.save(); ctx.translate(f.x, f.y); ctx.rotate(f.a); const rec = Math.max(0, 1 - f.t / 0.3) * 10; ctx.fillStyle = '#4a5578'; ctx.strokeStyle = '#1b1f42'; ctx.lineWidth = 4; rrPath(ctx, -50 - rec, -17, 90, 34, 12); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#ffd23f'; rrPath(ctx, 28 - rec, -22, 16, 44, 6); ctx.fill(); ctx.stroke(); ctx.restore(); ctx.fillStyle = '#ff8a3c'; ctx.beginPath(); ctx.arc(f.x, f.y + 14, 22, 0, TAU); ctx.fill();
    }
  }
}
function drawPointers() {
  for (const p of pointers.values()) {
    if (p.tool === 'grab') { ctx.strokeStyle = 'rgba(255,255,255,.85)'; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(p.x, p.y, p.grab ? 18 : 26, 0, TAU); ctx.stroke(); if (p.grab) { { const [hx, hy] = jointWorld(p.grab.body, p.grab.lp); drawSpring(hx, hy, p.x, p.y, clamp((p.pull || 0) / 6, 0, 1)); } ctx.fillStyle = '#ffd23f'; ctx.beginPath(); ctx.arc(p.x, p.y, 8, 0, TAU); ctx.fill(); } }
    else if (p.tool === 'magnet') {
      for (let i = 0; i < 3; i++) { const k = ((S.time * 1.4 + i / 3) % 1); ctx.strokeStyle = 'rgba(255,93,108,' + (1 - k) * .6 + ')'; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(p.x, p.y, 300 * (1 - k), 0, TAU); ctx.stroke(); }
      ctx.save(); ctx.translate(p.x, p.y); ctx.lineWidth = 12; ctx.strokeStyle = '#2a2260'; ctx.beginPath(); ctx.arc(0, 0, 22, Math.PI, 0); ctx.lineTo(22, 22); ctx.moveTo(-22, 0); ctx.lineTo(-22, 22); ctx.stroke(); ctx.lineWidth = 6; ctx.strokeStyle = '#ff4f6a'; ctx.stroke(); ctx.fillStyle = '#e8ecf8'; ctx.fillRect(-27, 18, 10, 10); ctx.fillRect(17, 18, 10, 10); ctx.restore();
    } else if (p.tool === 'freeze') {
      const sx = W / 2, sy = floorY; ctx.save(); ctx.globalAlpha = .55 + .2 * Math.sin(S.time * 20); const g = ctx.createLinearGradient(sx, sy, p.x, p.y); g.addColorStop(0, 'rgba(190,240,255,.1)'); g.addColorStop(1, 'rgba(190,240,255,.9)'); ctx.strokeStyle = g; ctx.lineWidth = 26; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(p.x, p.y); ctx.stroke(); ctx.lineWidth = 8; ctx.strokeStyle = '#fff'; ctx.stroke(); ctx.restore();
      ctx.strokeStyle = '#bfefff'; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(p.x, p.y, 40, 0, TAU); ctx.stroke(); spawnP(2, p.x + rand(-30, 30), p.y + rand(-30, 30), 0, 0, .4, 10, '#bfefff', 0, 0, 0);
    } else if (['glove', 'duck', 'ramp', 'fan'].includes(p.tool) && Math.hypot(p.x - p.sx, p.y - p.sy) > 45) {
      ctx.strokeStyle = 'rgba(255,255,255,.9)'; ctx.lineWidth = 5; ctx.setLineDash([12, 10]); ctx.beginPath(); ctx.moveTo(p.sx, p.sy); ctx.lineTo(p.x, p.y); ctx.stroke(); ctx.setLineDash([]); const a = Math.atan2(p.y - p.sy, p.x - p.sx); ctx.fillStyle = '#fff'; ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(a); ctx.beginPath(); ctx.moveTo(14, 0); ctx.lineTo(-8, -11); ctx.lineTo(-8, 11); ctx.fill(); ctx.restore();
    }
  }
}
function drawParticles(k) {
  for (const p of P) {
    if (!p.on) continue; p.life -= 0.0167 * k; if (p.life <= 0) { p.on = 0; continue; }
    p.vy += p.g * k; p.x += p.vx * k; p.y += p.vy * k; p.r += p.vr * k; const a = clamp(p.life / p.max * 1.6, 0, 1);
    if (p.k === 0) { ctx.globalAlpha = a; ctx.fillStyle = p.c; ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.r); ctx.scale(1, Math.cos(p.r * 2)); ctx.fillRect(-p.s / 2, -p.s * .3, p.s, p.s * .6); ctx.restore(); }
    else if (p.k === 1) { ctx.globalAlpha = a; ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.r); ctx.fillStyle = p.c; ctx.strokeStyle = '#6b7396'; ctx.lineWidth = 1.6; ctx.beginPath(); for (let i = 0; i < 6; i++) ctx.lineTo(Math.cos(i * 1.047) * p.s * .7, Math.sin(i * 1.047) * p.s * .7); ctx.closePath(); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#6b7396'; ctx.beginPath(); ctx.arc(0, 0, p.s * .2, 0, TAU); ctx.fill(); ctx.restore(); }
    else if (p.k === 2) { const s = p.s * (p.life / p.max); ctx.globalAlpha = a; ctx.fillStyle = p.c; ctx.beginPath(); ctx.moveTo(p.x, p.y - s); ctx.quadraticCurveTo(p.x, p.y, p.x + s, p.y); ctx.quadraticCurveTo(p.x, p.y, p.x, p.y + s); ctx.quadraticCurveTo(p.x, p.y, p.x - s, p.y); ctx.quadraticCurveTo(p.x, p.y, p.x, p.y - s); ctx.fill(); }
    else if (p.k === 3) { const s = p.s * (1.4 - p.life / p.max); ctx.globalAlpha = a * .7; ctx.fillStyle = p.c; ctx.beginPath(); ctx.arc(p.x, p.y, s, 0, TAU); ctx.fill(); }
    else if (p.k === 4) { ctx.globalAlpha = Math.min(1, p.life); ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.r); ctx.lineWidth = 6; ctx.strokeStyle = '#3a3a66'; ctx.beginPath(); ctx.moveTo(-16, 0); for (let i = 1; i < 6; i++) ctx.lineTo(-16 + i * 6.4, (i % 2 ? -7 : 7)); ctx.lineTo(16, 0); ctx.stroke(); ctx.lineWidth = 3.4; ctx.strokeStyle = '#e6ebf8'; ctx.stroke(); ctx.restore(); }
    else if (p.k === 6) { const t = 1 - p.life / p.max; ctx.globalAlpha = (1 - t) * .8; ctx.strokeStyle = p.c; ctx.lineWidth = 8 * (1 - t) + 1; ctx.beginPath(); ctx.arc(p.x, p.y, p.s * (0.2 + t * .8), 0, TAU); ctx.stroke(); }
  }
  ctx.globalAlpha = 1;
}
function drawTexts(k) {
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.lineJoin = 'round';
  for (const t of T) {
    if (!t.on) continue; t.life -= 0.0167 * k * 0.8; if (t.life <= 0) { t.on = 0; continue; } t.y += t.vy * k; const age = 1 - t.life, sc = age < .15 ? 0.4 + (age / .15) * 0.9 : (age < .25 ? 1.3 - (age - .15) * 3 : 1);
    ctx.save(); ctx.translate(t.x, t.y); ctx.scale(sc, sc); ctx.rotate(Math.sin(t.y * 0.1) * 0.05); ctx.globalAlpha = clamp(t.life * 2.5, 0, 1);
    ctx.font = '900 ' + t.s + 'px ui-rounded,"SF Pro Rounded",system-ui,sans-serif'; ctx.lineWidth = t.s * 0.28; ctx.strokeStyle = '#2a2260'; ctx.strokeText(t.t, 0, 0); ctx.fillStyle = t.c; ctx.fillText(t.t, 0, 0); ctx.restore();
  }
}
let clock = 0;
function render(k) {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  if (!bg || bgKey !== S.arena) makeBg();
  ctx.drawImage(bg, 0, 0);
  const sh = S.shake; const ox = sh > 0.2 ? rand(-sh, sh) * scale * dpr : 0, oy = sh > 0.2 ? rand(-sh, sh) * scale * dpr : 0;
  ctx.setTransform(dpr * scale, 0, 0, dpr * scale, ox, oy);
  drawArenaAnim(ctx, S.arena, clock, W, H, floorY);
  drawRing(false); drawProps(); drawObstacles();
  for (const r of robots) drawRobot(r);
  drawBombs(); drawRing(true); drawFx(); drawParticles(k); drawPointers(); drawTexts(k);
  if (S.gflip < 0) { ctx.fillStyle = 'rgba(255,138,216,.10)'; ctx.fillRect(0, 0, W, H); }
  ctx.setTransform(1, 0, 0, 1, 0, 0);
}

// ------------------------------------------------------------------ UI helpers
let dirty = false;
function addCoins(n, x, y) { save.coins += n; S.coinsEarned += n; dirty = true; if (x !== undefined) popText('+' + n, x, y, '#ffd23f', 26); sfx('coin', .5, 1, 60); bumpCoins(); }
function bumpCoins() { const p = $('coinPill'); p.classList.remove('bump'); void p.offsetWidth; p.classList.add('bump'); }
let toastT = 0;
function toast(msg, ms = 2600) { const t = $('toast'); t.textContent = msg; t.classList.add('show'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('show'), ms); }
function icon(id) { return ICONS[id] || ''; }
function setIcons() {
  $('bPause').innerHTML = icon('pause'); $('bRebuild').innerHTML = icon('wrench') + '<span class="lbl">Rebuild</span>'; $('bBot').innerHTML = icon('bot') + '<span class="lbl">+ Bot</span>'; $('bScene').innerHTML = icon('scene') + '<span class="lbl">Arena</span>';
  $('coinIc').innerHTML = '<span style="display:block;width:32px;height:32px">' + icon('coin') + '</span>';
  document.querySelectorAll('.ci').forEach((e) => { e.innerHTML = '<span style="display:block;width:32px;height:32px">' + icon('coin') + '</span>'; });
  $('playIc').innerHTML = icon('play'); $('homeBack').innerHTML = icon('back'); $('misBack').innerHTML = icon('back'); $('shopBack').innerHTML = icon('back');
  $('tMi').innerHTML = icon('flag'); $('tSa').innerHTML = icon('bot'); $('tSh').innerHTML = icon('bag');
  $('pResume').querySelector('.ic').innerHTML = icon('play'); $('pRestart').querySelector('.ic').innerHTML = icon('restart'); $('pHome').querySelector('.ic').innerHTML = icon('home');
  $('eRetry').querySelector('.ic').innerHTML = icon('restart'); $('eNext').querySelector('.ic').innerHTML = icon('play'); $('eHome').querySelector('.ic').innerHTML = icon('home');
  $('hintFinger').innerHTML = icon('grab');
  refreshMuteIcons();
}
function refreshMuteIcons() { $('bMuteT').innerHTML = icon(save.muted ? 'soundOff' : 'soundOn'); const pm = $('pMute'); pm.querySelector('.ic').innerHTML = icon(save.muted ? 'soundOff' : 'soundOn'); pm.querySelector('.tx').textContent = save.muted ? 'Sound off' : 'Sound on'; }
let lastCoins = -1;
function refreshCoins() { document.querySelectorAll('.cn').forEach((e) => { e.textContent = save.coins; }); $('coinN').textContent = save.coins; lastCoins = save.coins; }
function setScreen(name) {
  S.screen = name;
  for (const id of ['title', 'home', 'missions', 'shop']) $(id).classList.toggle('show', id === name);
  const play = name === 'play';
  $('hud').classList.toggle('hidden', !play); $('shelf').classList.toggle('hidden', !play); $('goal').classList.toggle('hidden', !play);
  $('bScene').classList.toggle('hidden', !(play && S.mode === 'sandbox')); $('bBot').classList.toggle('hidden', !(play && S.mode === 'sandbox'));
  refreshCoins(); if (name === 'missions') buildMissions(); if (name === 'shop') buildShop(shopTab);
}
function overlay(id, on) { $(id).classList.toggle('show', on); }
function refreshShelf() {
  const sh = $('shelf'); sh.innerHTML = '';
  for (const t of TOOLS) {
    const own = !!save.tools[t.id], b = document.createElement('button'); b.className = 'tool' + (S.tool === t.id ? ' sel' : '') + (own ? '' : ' locked'); b.dataset.id = t.id;
    b.innerHTML = icon(t.id) + '<span>' + t.name + '</span>' + (own ? '' : '<i class="price">' + t.price + '</i>') + (t.id === 'gravity' && S.gTimer > 0 ? '<div class="cd">' + Math.ceil(S.gTimer) + '</div>' : '');
    sh.appendChild(b);
  }
}
$('shelf').addEventListener('click', (e) => {
  const b = e.target.closest('.tool'); if (!b) return; const id = b.dataset.id; const t = TOOLS.find((x) => x.id === id);
  try { music.unlock(); } catch (_) { /* ignore */ }
  if (!save.tools[id]) { sfx('click', .6, .8); toast('Unlock ' + t.name + ' in the Toy Shop for ' + t.price + ' coins'); openShop('tools', 'play'); return; }
  sfx('click', .6, 1.2);
  if (id === 'gravity') { setGravity(S.gflip > 0 ? -1 : 1); startAction(); S.moves++; return; }
  S.tool = id; save.tool = id; dirty = true; refreshShelf(); toast(t.desc, 2200);
});
let hudCache = {};
function setTxt(id, v) { if (hudCache[id] !== v) { hudCache[id] = v; $(id).textContent = v; } }
function updateHud() {
  if (save.coins !== lastCoins) refreshCoins();
  if (S.screen !== 'play') return;
  const L = S.level;
  if (S.mode === 'mission' && L) {
    let t = ''; if (L.type === 'pop') t = 'Pop ' + L.goal + ' bolts   ' + Math.min(S.pops, L.goal) + '/' + L.goal; else if (L.type === 'knock') t = 'Knock down ' + L.goal + '   ' + Math.min(S.downCount, L.goal) + '/' + L.goal; else t = 'Launch a robot through the ring!';
    setTxt('goalTxt', t); const tl = Math.max(0, Math.ceil(S.timeLeft)); setTxt('goalTime', (S.started ? '' : 'Ready! ') + tl + 's'); $('goalTime').classList.toggle('low', S.started && S.timeLeft < 10);
  } else { setTxt('goalTxt', 'Sandbox   Pops: ' + S.pops); setTxt('goalTime', ARENAS[S.arena].name); }
  const g = $('shelf').querySelector('[data-id="gravity"] .cd'); const want = S.gTimer > 0 ? Math.ceil(S.gTimer) : 0;
  if ((g ? +g.textContent : 0) !== want) refreshShelf();
}

// ------------------------------------------------------------------ flow
function ownedArenas() { return Object.keys(ARENAS).filter((a) => save.arenas[a]); }
function enterDemo() {
  S.mode = 'demo'; S.level = null; const o = ownedArenas(); S.arena = o[Math.random() * o.length | 0]; S.paused = false; bg = null; buildWorld();
}
function startMission(id) {
  const L = LV(id); if (!L) return; if (!save.arenas[L.arena]) { toast('Unlock the ' + ARENAS[L.arena].name + ' in the Toy Shop first!'); return; }
  S.mode = 'mission'; S.level = L; S.arena = L.arena; S.paused = false; bg = null; buildWorld(); setScreen('play'); overlay('end', false); overlay('pause', false); refreshShelf();
  startMusic();
  if (!save.seenHint) showHint('How to play', 'Drag a robot part with your finger. Stretch it far and it pops off with a BOING! Flick to fling! ' + L.hint, 'grab'); else toast(L.name + ': ' + L.hint, 4200);
  if (!save.tools[S.tool]) { S.tool = 'grab'; refreshShelf(); }
}
function startSandbox() {
  S.mode = 'sandbox'; S.level = null; S.arena = save.arena && save.arenas[save.arena] ? save.arena : 'lab'; S.paused = false; bg = null; buildWorld(); setScreen('play'); overlay('end', false); overlay('pause', false);
  if (!save.tools[S.tool]) S.tool = 'grab'; refreshShelf(); startMusic();
  if (!save.seenSand) showHint('Sandbox!', 'Pick a toy from the shelf at the bottom, then tap or drag on the robots. Pop 3 coins per bolt and spend them in the Toy Shop!', 'glove');
}
function showHint(title, msg, ic) { $('hintT').textContent = title; $('hintP').textContent = msg; $('hintFinger').innerHTML = icon(ic); overlay('hint', true); S.hintOpen = true; }
$('hintOk').onclick = () => { overlay('hint', false); S.hintOpen = false; save.seenHint = true; save.seenSand = true; dirty = true; sfx('click'); };
function restartCurrent() { overlay('pause', false); overlay('end', false); S.paused = false; buildWorld(); refreshShelf(); }
function goHome() { overlay('pause', false); overlay('end', false); S.paused = false; enterDemo(); setScreen('home'); try { music.setIntensity(0.35); } catch (_) { /* ignore */ } }
function pauseGame() { if (S.screen !== 'play' || S.over) return; S.paused = true; overlay('pause', true); sfx('click'); }
function resumeGame() { S.paused = false; overlay('pause', false); }
function winMission() {
  if (S.over) return; S.over = true; const L = S.level, frac = S.timeLeft / L.time, stars = frac > 0.5 ? 3 : frac > 0.25 ? 2 : 1;
  const reward = 25 + 15 * stars; addCoins(reward); const prev = save.stars[L.id] || 0; if (stars > prev) save.stars[L.id] = stars; dirty = true; persist();
  confetti(W / 2, H * 0.35, 80, 16, 8); sfx('powerup', 1, .9, 10); setTimeout(() => sfx('sparkle', .8, 1, 10), 250); setTimeout(() => sfx('coin', .8, 1, 10), 450); S.shake = 6; popText('Mission complete!', W / 2, H * 0.3, '#ffd23f', 56);
  try { music.setIntensity(1); } catch (_) { /* ignore */ }
  setTimeout(() => showEnd(true, stars, reward), 1500);
}
function loseMission() {
  if (S.over) return; S.over = true; sfx('lose', 1); popText('Time is up!', W / 2, H * 0.3, '#ff8a9a', 56); setTimeout(() => showEnd(false, 0, 0), 1200);
}
function showEnd(win, stars, reward) {
  if (S.screen !== 'play') return; const L = S.level;
  $('endTitle').textContent = win ? 'Great job!' : 'So close!';
  $('endMsg').textContent = win ? ('+' + reward + ' coins!  ' + (stars < 3 ? 'Be quicker for more stars.' : 'Perfect run!')) : 'Time ran out. Try again, you can do it!';
  const st = $('stars'); st.innerHTML = ''; for (let i = 0; i < 3; i++) { const d = document.createElement('div'); d.innerHTML = icon(i < stars ? 'star' : 'starOff'); const sv = d.firstChild; sv.style.width = '96px'; sv.style.height = '96px'; st.appendChild(sv); setTimeout(() => { sv.classList.add('pop'); if (i < stars) sfx('sparkle', .6, .85 + i * .06); }, 250 + i * 330); }
  const next = LV(L.id + 1); $('eNext').classList.toggle('hidden', !(win && next)); overlay('end', true);
}
$('eNext').onclick = () => { const n = LV(S.level.id + 1); overlay('end', false); if (n && save.arenas[n.arena]) startMission(n.id); else { toast('Unlock the next arena in the Toy Shop!'); setScreen('missions'); enterDemo(); } };
$('eRetry').onclick = () => { sfx('click'); startMission(S.level.id); };
$('eHome').onclick = () => { sfx('click'); overlay('end', false); enterDemo(); setScreen('missions'); };

// ------------------------------------------------------------------ menus
function buildMissions() {
  const list = $('misList'); list.innerHTML = '';
  for (const aid of Object.keys(ARENAS)) {
    const A = ARENAS[aid], own = !!save.arenas[aid]; const box = document.createElement('div'); box.className = 'arena';
    box.innerHTML = '<h3>' + A.name + (own ? '' : '<span class="pr">' + icon('lock').replace('<svg', '<svg style="width:22px;height:22px"') + A.price + '</span>') + '</h3>';
    const row = document.createElement('div'); row.className = 'lv';
    for (const L of LEVELS.filter((l) => l.arena === aid)) {
      const open = own && (L.id === 1 || (save.stars[L.id - 1] || 0) > 0), s = save.stars[L.id] || 0;
      const b = document.createElement('button'); b.className = 'lvb' + (open ? '' : ' lk');
      b.innerHTML = open ? ('<span>' + L.id + '</span><small>' + L.name + '</small><div class="st">' + [0, 1, 2].map((i) => icon(i < s ? 'star' : 'starOff')).join('') + '</div>') : ('<span class="lkI">' + icon('lock') + '</span><small>' + L.name + '</small>');
      b.onclick = () => { sfx('click'); if (open) startMission(L.id); else if (!own) { toast('Unlock the ' + A.name + ' in the Toy Shop for ' + A.price + ' coins'); openShop('arenas', 'missions'); } else toast('Win the previous mission first!'); };
      row.appendChild(b);
    }
    box.appendChild(row); list.appendChild(box);
  }
}
let shopTab = 'tools', shopFrom = 'home';
function openShop(tab, from) { shopTab = tab; shopFrom = from; if (from === 'play') S.paused = true; setScreen('shop'); }
const previewCache = {};
function skinPreview(id) {
  if (previewCache[id]) return previewCache[id]; const c = document.createElement('canvas'); c.width = 96; c.height = 120; const g = c.getContext('2d'); const sp = getSprites(id, 0), k = 0.58, cx = 48, cy = 50;
  for (const [key, kind] of ORDER) { const [dx, dy] = LAYOUT[key]; const s = sp[kind]; g.drawImage(s.c, cx + dx * k - s.uw * k / 2, cy + dy * k - s.uh * k / 2, s.uw * k, s.uh * k); }
  return (previewCache[id] = c.toDataURL());
}
function arenaPreview(id) {
  const key = 'a' + id; if (previewCache[key]) return previewCache[key]; const c = document.createElement('canvas'); c.width = 200; c.height = 120; const g = c.getContext('2d'); g.scale(200 / 1300, 200 / 1300); drawArena(g, id, 1300, 780, 640); return (previewCache[key] = c.toDataURL());
}
function buildShop(tab) {
  shopTab = tab; const tabs = $('tabs'); tabs.innerHTML = '';
  for (const [id, n] of [['tools', 'Tools'], ['skins', 'Robot Skins'], ['arenas', 'Arenas'], ['up', 'Upgrades']]) { const b = document.createElement('button'); b.className = 'tab' + (id === tab ? ' on' : ''); b.textContent = n; b.onclick = () => { sfx('click'); buildShop(id); }; tabs.appendChild(b); }
  const cards = $('cards'); cards.innerHTML = '';
  const card = (pv, name, desc, btnTxt, cls, fn, extra) => { const d = document.createElement('div'); d.className = 'card'; d.innerHTML = '<div class="pv">' + pv + '</div><b>' + name + '</b><span>' + desc + '</span>' + (extra || ''); const b = document.createElement('button'); b.className = 'btn ' + cls; b.innerHTML = btnTxt; b.onclick = fn; d.appendChild(b); cards.appendChild(d); };
  const priceTxt = (p) => '<span style="width:26px;height:26px;display:inline-block">' + icon('coin') + '</span>' + p;
  const spend = (p, ok) => { if (save.coins < p) { sfx('lose', .5); toast('Not enough coins yet! Pop some bolts!'); return; } save.coins -= p; persist(); sfx('coin', 1); sfx('powerup', .6); ok(); refreshCoins(); buildShop(tab); };
  if (tab === 'tools') for (const t of TOOLS) { const own = !!save.tools[t.id]; card(icon(t.id), t.name, t.desc, own ? (S.tool === t.id ? 'Selected' : 'Owned') : priceTxt(t.price), own ? 'green' : 'yellow', () => { if (own) { if (t.id !== 'gravity') { S.tool = t.id; save.tool = t.id; persist(); toast(t.name + ' ready!'); buildShop(tab); } } else spend(t.price, () => { save.tools[t.id] = 1; if (t.id !== 'gravity') { S.tool = t.id; save.tool = t.id; } persist(); }); }); }
  if (tab === 'skins') for (const id of Object.keys(SKINS)) { const s = SKINS[id], own = !!save.skins[id]; card('<img alt="" src="' + skinPreview(id) + '">', s.name, s.desc, own ? (save.skin === id ? 'Wearing' : 'Wear it') : priceTxt(s.price), own ? (save.skin === id ? 'green' : 'blue') : 'yellow', () => { if (own) { save.skin = id; persist(); sfx('pop'); buildShop(tab); } else spend(s.price, () => { save.skins[id] = 1; save.skin = id; persist(); }); }); }
  if (tab === 'arenas') for (const id of Object.keys(ARENAS)) { const a = ARENAS[id], own = !!save.arenas[id]; card('<img alt="" style="border-radius:14px;width:150px" src="' + arenaPreview(id) + '">', a.name, a.desc, own ? (save.arena === id ? 'Sandbox arena' : 'Use in sandbox') : priceTxt(a.price), own ? (save.arena === id ? 'green' : 'blue') : 'yellow', () => { if (own) { save.arena = id; persist(); sfx('pop'); buildShop(tab); } else spend(a.price, () => { save.arenas[id] = 1; save.arena = id; persist(); }); }); }
  if (tab === 'up') for (const [id, n, d, ic] of [['power', 'Mega Power', 'Gloves, hammers, bombs and more hit harder.', 'glove'], ['grip', 'Super Grip', 'Stronger grab and bigger fling speed.', 'grab'], ['coin', 'Coin Boost', 'Earn 25% more coins from every pop.', 'coin']]) {
    const lv = save.up[id] || 0, max = lv >= 5, cost = 60 + 60 * lv; card(icon(ic), n, d, max ? 'Maxed!' : priceTxt(cost), max ? 'green' : 'yellow', () => { if (!max) spend(cost, () => { save.up[id] = lv + 1; persist(); }); }, '<div class="lvlpips">' + [0, 1, 2, 3, 4].map((i) => '<i class="' + (i < lv ? 'f' : '') + '"></i>').join('') + '</div>');
  }
}
$('shopBack').onclick = () => { sfx('click'); if (shopFrom === 'play') { S.paused = false; setScreen('play'); refreshShelf(); } else setScreen(shopFrom === 'missions' ? 'missions' : 'home'); };

// ------------------------------------------------------------------ wiring
$('bPlay').onclick = () => { startMusic(); sfx('click'); setScreen('home'); };
$('bMuteT').onclick = () => { try { music.unlock(); } catch (_) { /* ignore */ } setMuted(!save.muted); sfx('click'); };
$('pMute').onclick = () => { setMuted(!save.muted); sfx('click'); };
$('homeBack').onclick = () => { sfx('click'); setScreen('title'); };
$('misBack').onclick = () => { sfx('click'); setScreen('home'); };
$('tMissions').onclick = () => { sfx('click'); setScreen('missions'); };
$('tSandbox').onclick = () => { sfx('click'); startSandbox(); };
$('tShop').onclick = () => { sfx('click'); openShop('tools', 'home'); };
$('bPause').onclick = pauseGame; $('pResume').onclick = () => { sfx('click'); resumeGame(); };
$('pRestart').onclick = () => { sfx('click'); if (S.mode === 'mission') startMission(S.level.id); else restartCurrent(); };
$('pHome').onclick = () => { sfx('click'); goHome(); };
$('bRebuild').onclick = () => { rebuildAll(); };
$('bBot').onclick = addBot;
$('bScene').onclick = () => { const o = ownedArenas(); S.arena = o[(o.indexOf(S.arena) + 1) % o.length]; save.arena = S.arena; dirty = true; bg = null; buildWorld(); sfx('whoosh'); refreshShelf(); };
window.addEventListener('keydown', (e) => {
  if (e.repeat) return; const k = e.key;
  if (k === 'Escape' || k === 'p') { if (S.paused) resumeGame(); else pauseGame(); }
  else if (k === 'm') setMuted(!save.muted);
  else if (S.screen === 'play' && !S.paused) {
    if (k === ' ') { rebuildAll(); e.preventDefault(); } else if (k === 'g' && save.tools.gravity) setGravity(S.gflip > 0 ? -1 : 1);
    else if (/^[1-9]$/.test(k) || k === '0') { const t = TOOLS[k === '0' ? 9 : +k - 1]; if (t && save.tools[t.id] && t.id !== 'gravity') { S.tool = t.id; refreshShelf(); } }
  }
});
window.addEventListener('resize', () => { layout(); });
window.addEventListener('orientationchange', () => setTimeout(layout, 200));
setInterval(() => { if (dirty) { dirty = false; persist(); } }, 2500);
window.addEventListener('pagehide', persist);

// ------------------------------------------------------------------ main loop
function stepSim() { stepForces(); Engine.update(engine, 1000 / 60); postStep(1 / 60); stepFx(1 / 60); }
let last = performance.now(), acc = 0, demoT = 2;
function frame(now) {
  const dtR = Math.min(0.1, (now - last) / 1000); last = now; clock += dtR;
  try {
    const running = !S.paused && !S.hintOpen;
    if (running) {
      const slow = S.slow > 0 ? 0.35 : 1; S.slow = Math.max(0, S.slow - dtR); acc += dtR * slow; let n = 0;
      while (acc >= 1 / 60 && n < 3) { stepSim(); acc -= 1 / 60; n++; }
      if (n === 3) acc = 0;
      if (S.mode === 'demo' || S.screen !== 'play') { demoT -= dtR; if (demoT < 0 && robots.length) { demoT = rand(2, 3.5); const r = robots[Math.random() * robots.length | 0], t = r.parts.torso, hv = { x: rand(-5, 5), y: -13 }; for (const k in r.parts) Body.setVelocity(r.parts[k], hv); Body.setAngularVelocity(t, rand(-.25, .25)); r.stand = 0; r.stun = 1.8; sfx('boing', .25, rand(.8, 1.5), 400); } }
    }
    S.shake *= Math.pow(0.86, dtR * 60); if (S.shake < 0.2) S.shake = 0;
    render(dtR * 60); updateHud();
    const inten = S.screen === 'play' ? clamp(0.22 + S.chaos * 0.85, 0.15, 1) : 0.3; try { if (!S.over) music.setIntensity(inten); } catch (_) { /* ignore */ }
  } catch (err) { console.error(err); }
  requestAnimationFrame(frame);
}
setIcons(); layout(); enterDemo(); setScreen('title'); requestAnimationFrame(frame);
window.__rs = { TUNE, pointers, stepSim, get engine() { return engine; }, S, save, get W() { return W; }, get floorY() { return floorY; }, get robots() { return robots; }, LEVELS, startMission, startSandbox, get props() { return props; }, setGravity, rebuildAll, music };
