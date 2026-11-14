// Buddy Playground: a squishy, kid-safe toy sandbox. Canvas 2D + matter-js ragdoll.
import { Maestro, THEMES } from '../shared/maestro.js';
import { drawTool, drawBeachBall, drawCannon, drawHead, drawNeck, drawBack, drawRoom, shade, rr, starPath, SKINS, OUTFITS, ROOMS } from './art.js';

const { Engine, Bodies, Body, Constraint, Composite, Events } = Matter;
const TAU = Math.PI * 2;
const K = 0.85; // buddy scale
const $ = (id) => document.getElementById(id);
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const lerp = (a, b, t) => a + (b - a) * t;
const rnd = (a, b) => a + Math.random() * (b - a);
const pick = (a) => a[(Math.random() * a.length) | 0];

// ---------------------------------------------------------------------------------------------- save data
const SAVE_KEY = 'buddyplayground.v1';
const TOOLS = [
  { id: 'hammer', name: 'Boing Hammer', price: 0 }, { id: 'pillow', name: 'Pillow', price: 0 }, { id: 'hand', name: 'Grab', price: 0 },
  { id: 'confetti', name: 'Confetti', price: 0 }, { id: 'tramp', name: 'Trampoline', price: 20 }, { id: 'balloons', name: 'Balloons', price: 30 },
  { id: 'feather', name: 'Tickle Feather', price: 30 }, { id: 'water', name: 'Water Balloon', price: 45 }, { id: 'fan', name: 'Big Fan', price: 55 },
  { id: 'mushroom', name: 'Bouncy Mushroom', price: 65 }, { id: 'cupcake', name: 'Cupcake Cannon', price: 80 }, { id: 'icecream', name: 'Ice-Cream Launcher', price: 90 },
  { id: 'glitter', name: 'Glitter Bomb', price: 110 }, { id: 'magnet', name: 'Big Magnet', price: 130 }, { id: 'beach', name: 'Beach Ball Blaster', price: 150 },
];
const TOOL = Object.fromEntries(TOOLS.map((t) => [t.id, t]));
const SHORT = { hammer: 'Hammer', pillow: 'Pillow', hand: 'Grab', confetti: 'Confetti', tramp: 'Trampoline', balloons: 'Balloons', feather: 'Tickle', water: 'Water', fan: 'Fan', mushroom: 'Mushroom', cupcake: 'Cupcake', icecream: 'Ice-Cream', glitter: 'Glitter', magnet: 'Magnet', beach: 'Beach Ball' };
const CANNON = { confetti: '#ff5d8f', water: '#3ea8ff', cupcake: '#ff8fbe', icecream: '#4fd0a0', glitter: '#9a6bff', beach: '#ffb52e' };

function defaults() {
  return { coins: 30, stars: 0, tools: { hammer: 1, pillow: 1, hand: 1, confetti: 1 }, rooms: { playroom: 1 }, outfits: { peach: 1 }, equip: { skin: 'peach', hat: null, face: null, neck: null, back: null }, room: 'playroom', bestCombo: 0, hits: 0, muted: false, tool: 'hammer', played: false };
}
let save = defaults();
try { const s = JSON.parse(localStorage.getItem(SAVE_KEY) || 'null'); if (s) { save = Object.assign(defaults(), s); save.equip = Object.assign(defaults().equip, s.equip || {}); } } catch (e) { /* ignore */ }
function persist() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(save)); } catch (e) { /* ignore */ } }

// ---------------------------------------------------------------------------------------------- audio
const music = new Maestro();
try { music.muted = !!save.muted; } catch (e) { /* ignore */ }
let lastSfx = {};
function sfx(name, o) { const now = performance.now(); if (lastSfx[name] && now - lastSfx[name] < 45) return; lastSfx[name] = now; try { music.sfx(name, o); } catch (e) { /* ignore */ } }

// ---------------------------------------------------------------------------------------------- canvas / view
const cv = $('c'), ctx = cv.getContext('2d');
let vw = 0, vh = 0, dpr = 1, S = 1, W = 800, H = 600, floorY = 500, bgCanvas = null, bgKey = '';
function resize() {
  vw = window.innerWidth; vh = window.innerHeight; dpr = Math.min(window.devicePixelRatio || 1, 2);
  cv.width = Math.round(vw * dpr); cv.height = Math.round(vh * dpr);
  S = Math.min(vh / 720, vw / 500); W = vw / S; H = vh / S;
  const safeB = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--safe-b')) || 0;
  floorY = (vh - 138 - safeB) / S;
  bgKey = ''; buildWalls();
  if (buddy && buddy.parts.torso.body.position.y > floorY + 20) respawnBuddy();
  clampBuddyX();
}
window.addEventListener('resize', resize); window.addEventListener('orientationchange', () => setTimeout(resize, 120));
if (window.visualViewport) window.visualViewport.addEventListener('resize', resize);

function ensureBg() {
  const key = `${save.room}|${vw}|${vh}|${dpr}|${Math.round(floorY)}`;
  if (key === bgKey && bgCanvas) return;
  bgKey = key; bgCanvas = bgCanvas || document.createElement('canvas');
  bgCanvas.width = Math.round(vw * dpr); bgCanvas.height = Math.round(vh * dpr);
  const b = bgCanvas.getContext('2d'); b.setTransform(dpr * S, 0, 0, dpr * S, 0, 0); drawRoom(b, save.room, W, H, floorY);
}

// ---------------------------------------------------------------------------------------------- physics
const engine = Engine.create({ enableSleeping: false, positionIterations: 10, velocityIterations: 8, constraintIterations: 5 });
engine.gravity.y = 1;
const world = engine.world;
let statics = [], walls = null;
const ROOM_PHYS = { playroom: { g: 1, fr: 0.9, rest: 0.55, part: 0.5 }, beach: { g: 1, fr: 1.1, rest: 0.1, part: 0.3 }, snow: { g: 0.9, fr: 0.04, rest: 0.25, part: 0.35 }, space: { g: 0.28, fr: 0.5, rest: 0.6, part: 0.55 } };
function buildWalls() {
  if (walls) Composite.remove(world, walls);
  const P = ROOM_PHYS[save.room] || ROOM_PHYS.playroom;
  const o = { isStatic: true, restitution: 0.55, friction: 0.5, label: 'wall' };
  const left = Bodies.rectangle(-60, floorY - 1000, 120, 4000, o), right = Bodies.rectangle(W + 60, floorY - 1000, 120, 4000, o);
  const ceil = Bodies.rectangle(W / 2, -330, W + 600, 160, o);
  const floor = Bodies.rectangle(W / 2, floorY + 100, W + 600, 200, { isStatic: true, restitution: P.rest, friction: P.fr, label: 'ground' });
  walls = Composite.create(); Composite.add(walls, [left, right, ceil, floor]); Composite.add(world, walls);
}
function applyRoomPhysics() {
  const P = ROOM_PHYS[save.room] || ROOM_PHYS.playroom;
  engine.gravity.scale = 0.001 * P.g; buildWalls();
  if (buddy) for (const p of buddy.list) p.body.restitution = p.name === 'head' ? P.part + 0.05 : P.part;
}

// ---------------------------------------------------------------------------------------------- buddy
let buddy = null;
const DIM = { headR: 44 * K, tw: 74 * K, th: 88 * K, aw: 19 * K, ah: 46 * K, lw: 25 * K, lh: 58 * K };
DIM.ajl = DIM.ah - DIM.aw; DIM.ljl = DIM.lh - DIM.lw;

function mkPart(name, body, rad) { return { name, body, rad, sq: 0, sqv: 0, sqa: 0, st: 0 }; }
function buildBuddy(x, y) {
  if (buddy) { Composite.remove(world, buddy.comp); }
  const P = ROOM_PHYS[save.room] || ROOM_PHYS.playroom;
  const grp = { group: -1 };
  const base = { friction: 0.7, frictionAir: 0.012, restitution: P.part, collisionFilter: grp, density: 0.001, slop: 0.02 };
  const D = DIM;
  const parts = {}, list = [], cons = [];
  const add = (name, body, rad) => { body.plugin = { buddy: name }; const p = mkPart(name, body, rad); parts[name] = p; list.push(p); return p; };
  const torso = Bodies.rectangle(x, y, D.tw, D.th, { ...base, chamfer: { radius: D.tw * 0.42 }, density: 0.0016 });
  add('torso', torso, D.tw * 0.5);
  const hy = y - D.th / 2 - D.headR * 0.62;
  add('head', Bodies.circle(x, hy, D.headR, { ...base, restitution: P.part + 0.05, density: 0.0008 }), D.headR);
  const sh = [[-1, x - D.tw / 2 + 8 * K], [1, x + D.tw / 2 - 8 * K]];
  const shY = y - D.th / 2 + 18 * K;
  for (const [s, sx] of sh) {
    const n = s < 0 ? 'L' : 'R';
    const ua = Bodies.rectangle(sx, shY + D.ajl / 2, D.aw, D.ah, { ...base, chamfer: { radius: D.aw / 2 - 0.5 }, density: 0.0008 });
    const la = Bodies.rectangle(sx, shY + D.ajl * 1.5, D.aw, D.ah, { ...base, chamfer: { radius: D.aw / 2 - 0.5 }, density: 0.0008 });
    add('uA' + n, ua, D.aw); add('lA' + n, la, D.aw);
    cons.push(joint(torso, ua, { x: sx, y: shY }), joint(ua, la, { x: sx, y: shY + D.ajl }));
  }
  const hipY = y + D.th / 2 - 16 * K;
  for (const [s, hx] of [[-1, x - 17 * K], [1, x + 17 * K]]) {
    const n = s < 0 ? 'L' : 'R';
    const ul = Bodies.rectangle(hx, hipY + D.ljl / 2, D.lw, D.lh, { ...base, chamfer: { radius: D.lw / 2 - 0.5 }, density: 0.0012 });
    const ll = Bodies.rectangle(hx, hipY + D.ljl * 1.5, D.lw, D.lh, { ...base, chamfer: { radius: D.lw / 2 - 0.5 }, density: 0.0012, friction: 0.9 });
    add('uL' + n, ul, D.lw); add('lL' + n, ll, D.lw);
    cons.push(joint(torso, ul, { x: hx, y: hipY }), joint(ul, ll, { x: hx, y: hipY + D.ljl }));
  }
  cons.push(joint(torso, parts.head.body, { x, y: y - D.th / 2 + 6 * K }, 0.9));
  const comp = Composite.create(); Composite.add(comp, list.map((p) => p.body)); Composite.add(comp, cons); Composite.add(world, comp);
  let mass = 0; for (const p of list) mass += p.body.mass;
  buddy = { parts, list, cons, comp, mass, muscle: 1, floppy: 0, emo: 'idle', emoT: 0, blink: 0, nextBlink: 2, look: { x: 0, y: 0 }, lookT: 0, decals: [], wet: 0, dizzy: 0, grab: null, grounded: false, idle: 0, flutter: 0, sleepy: false };
  return buddy;
}
function joint(a, b, w, stiff = 0.92) {
  return Constraint.create({ bodyA: a, bodyB: b, pointA: { x: w.x - a.position.x, y: w.y - a.position.y }, pointB: { x: w.x - b.position.x, y: w.y - b.position.y }, stiffness: stiff, damping: 0.08, length: 0, render: { visible: false } });
}
function respawnBuddy() { buildBuddy(W / 2, floorY - 380); setEmo('wow', 1.0, true); }
function clampBuddyX() { if (!buddy) return; const t = buddy.parts.torso.body; if (t.position.x > W - 20 || t.position.x < 20) { const dx = clamp(t.position.x, 60, W - 60) - t.position.x; for (const p of buddy.list) Body.translate(p.body, { x: dx, y: 0 }); } }

const norm = (a) => { while (a > Math.PI) a -= TAU; while (a < -Math.PI) a += TAU; return a; };
function pd(b, target, kp, kd, ref, m) {
  const err = norm(b.angle - target);
  const av = b.angularVelocity;
  Body.setAngularVelocity(b, av + (-kp * err - kd * (av - ref)) * m);
}
const LEGK = [0.1, 0.25, 0.12, 0.28]; let ASSIST = 0.5;
function muscles() {
  const B = buddy, P = B.parts, m0 = B.muscle;
  const t = P.torso.body;
  // grounded?
  let low = -1e9; for (const p of B.list) low = Math.max(low, p.body.position.y + p.rad);
  const near = floorY - low;
  B.grounded = near < 14 || (P.lLL.body.bounds.max.y > floorY - 4) || (P.lLR.body.bounds.max.y > floorY - 4);
  const g = ROOM_PHYS[save.room].g;
  const mg = B.grounded ? 1 : 0.28; // weaker in the air so he tumbles
  const m = m0 * mg;
  const grabbed = B.grab ? 0.35 : 1;
  const mm = m * grabbed;
  // upright wobble (weeble)
  pd(t, 0, 0.018 * (g < 0.5 ? 0.4 : 1), 0.07, 0, mm);
  const ta = t.angle, tav = t.angularVelocity;
  pd(P.head.body, ta, 0.012, 0.05, tav, mm);
  for (const [s, n] of [[1, 'L'], [-1, 'R']]) {
    const ua = P['uA' + n].body, la = P['lA' + n].body;
    const swing = Math.sin(B.t * 1.7 + (s > 0 ? 0 : 1.5)) * 0.04;
    pd(ua, ta + s * (0.32 + swing), 0.01, 0.05, tav, mm * 0.7);
    pd(la, ua.angle + s * 0.18, 0.012, 0.06, ua.angularVelocity, mm * 0.6);
  }
  for (const [s, n] of [[1, 'L'], [-1, 'R']]) {
    const ul = P['uL' + n].body, ll = P['lL' + n].body;
    pd(ul, ta + s * 0.1, LEGK[0], LEGK[1], tav, mm * (B.grounded ? 1 : 0.5));
    pd(ll, ul.angle, LEGK[2], LEGK[3], ul.angularVelocity, mm * (B.grounded ? 1 : 0.5));
  }
  if (B.grounded && mm > 0.5) { const gs = engine.gravity.scale * engine.gravity.y; for (const n of ['torso', 'head']) { const bd = P[n].body; bd.force.y -= bd.mass * gs * ASSIST * mm; } }
  // damp the whole body a bit while standing so he settles
  if (B.grounded && m0 > 0.6) for (const p of B.list) { const v = p.body.velocity; if (Math.abs(v.x) < 1.5) Body.setVelocity(p.body, { x: v.x * 0.985, y: v.y }); }
}

// ---------------------------------------------------------------------------------------------- emotes
const EMO_PRI = { idle: 0, sleepy: 0, happy: 1, wow: 2, laugh: 3, dizzy: 4 };
function setEmo(n, dur, force) { const B = buddy; if (!force && B.emoT > 0 && EMO_PRI[n] < EMO_PRI[B.emo]) return; B.emo = n; B.emoT = dur; B.sleepy = false; }

// ---------------------------------------------------------------------------------------------- particles
const PN = 700; const parts_ = new Array(PN); for (let i = 0; i < PN; i++) parts_[i] = { on: false, x: 0, y: 0, vx: 0, vy: 0, life: 0, max: 1, size: 4, rot: 0, vr: 0, type: 0, col: '#fff', g: 0, drag: 1, grow: 0 };
let pIdx = 0;
const PT = { conf: 1, dot: 2, star: 3, puff: 4, drop: 5, heart: 6, streak: 7, glit: 8, snow: 9, ring: 10, z: 11 };
function P_(type, x, y, vx, vy, life, size, col, g = 0, drag = 1, grow = 0) {
  const p = parts_[pIdx]; pIdx = (pIdx + 1) % PN;
  p.on = true; p.type = type; p.x = x; p.y = y; p.vx = vx; p.vy = vy; p.life = life; p.max = life; p.size = size; p.col = col; p.g = g; p.drag = drag; p.grow = grow; p.rot = Math.random() * TAU; p.vr = rnd(-0.3, 0.3); return p;
}
const CONF = ['#ff5d8f', '#3ec6ff', '#ffd23f', '#58d68d', '#b57bff', '#ff9f43'];
function burstConfetti(x, y, n, spd, ang = 0, spread = TAU) {
  for (let i = 0; i < n; i++) { const a = ang + rnd(-spread / 2, spread / 2), s = rnd(0.3, 1) * spd; P_(PT.conf, x, y, Math.cos(a) * s, Math.sin(a) * s, rnd(1.2, 2.4), rnd(5, 9), pick(CONF), 0.16, 0.975); }
}
function burstSparks(x, y, n, spd, cols = ['#fff', '#ffd23f', '#ff9ee0']) { for (let i = 0; i < n; i++) { const a = rnd(0, TAU), s = rnd(0.2, 1) * spd; P_(PT.star, x, y, Math.cos(a) * s, Math.sin(a) * s, rnd(0.5, 1.1), rnd(6, 13), pick(cols), 0.05, 0.96); } }
function puff(x, y, n, col = 'rgba(255,255,255,0.8)', spd = 2.5, size = 16) { for (let i = 0; i < n; i++) { const a = rnd(0, TAU), s = rnd(0.3, 1) * spd; P_(PT.puff, x, y, Math.cos(a) * s, Math.sin(a) * s - 0.4, rnd(0.4, 0.8), size * rnd(0.6, 1.1), col, -0.01, 0.95, 0.7); } }
function splash(x, y, n, col = '#6fcfff', spd = 8) { for (let i = 0; i < n; i++) { const a = rnd(0, TAU), s = rnd(0.3, 1) * spd; P_(PT.drop, x, y, Math.cos(a) * s, Math.sin(a) * s - 2, rnd(0.5, 1.0), rnd(3, 7), col, 0.3, 0.985); } }
function hearts(x, y, n) { for (let i = 0; i < n; i++) P_(PT.heart, x + rnd(-25, 25), y + rnd(-10, 10), rnd(-0.6, 0.6), rnd(-2.4, -1.2), rnd(0.9, 1.5), rnd(10, 17), pick(['#ff5d8f', '#ff8fb8', '#ff3d7a']), -0.01, 0.99); }

// floating text + coin flyers
const texts = []; const flyers = [];
function floatText(txt, x, y, col = '#ff4f94', size = 34) { if (texts.length > 7) texts.shift(); texts.push({ txt, x, y, t: 0, col, size, vx: rnd(-0.4, 0.4) }); }

// ---------------------------------------------------------------------------------------------- fun / combo
const G = { combo: 0, lastFun: -10, meter: 0, t: 0, ses: { hits: 0, best: 0, coins: 0 }, paused: false, state: 'title', tool: save.tool, shake: 0, zoom: 0, idleT: 0, comboMax: 0 };
const WORDS = { boing: ['Boing!', 'Boinng!', 'Whee!', 'Boing boing!'], giggle: ['Hehe!', 'Tee-hee!', 'Giggle!', 'Hee hee!'], wow: ['Wow!', 'Whoa!', 'Wheee!', 'Yippee!'], yay: ['Yay!', 'Woohoo!', 'Hooray!'], tickle: ['Hehehe!', 'Tickles!', 'Haha!'], splat: ['Splat!', 'Yum!', 'Squish!'], sparkle: ['Sparkly!', 'Ooooh!', 'Shiny!'], dizzy: ['Dizzy!', 'Wobbly!', 'Whoa-oa!'], pop: ['Pop!', 'Pop pop!', 'Yay!'] };
function fun(pts, kind, x, y, emo = 'laugh') {
  const B = buddy; const now = G.t;
  if (now - G.lastFun < 2.4) G.combo++; else G.combo = 1;
  G.lastFun = now; G.comboMax = Math.max(G.comboMax, G.combo);
  const mult = 1 + 0.12 * Math.min(G.combo, 12);
  const coins = Math.max(1, Math.round(pts / 5 * mult));
  save.coins += coins; save.hits++; G.ses.hits++; G.ses.coins += coins; G.ses.best = Math.max(G.ses.best, G.combo);
  if (G.combo > save.bestCombo) save.bestCombo = G.combo;
  G.meter += pts * mult; G.idleT = 0;
  let starUp = false;
  while (G.meter >= 100) { G.meter -= 100; save.stars++; starUp = true; }
  const w = pick(WORDS[kind] || WORDS.giggle);
  floatText(w, x, y - 50, pick(['#ff4f94', '#3e9cff', '#ff9f2e', '#9a6bff', '#2fc678']), 30 + Math.min(18, G.combo * 1.5));
  if (G.combo > 1 && G.combo % 3 === 0) floatText(`x${G.combo}!`, x + rnd(-40, 40), y - 100, '#ffb52e', 26);
  for (let i = 0; i < Math.min(5, coins); i++) flyers.push({ x0: x + rnd(-20, 20), y0: y + rnd(-20, 20), t: -i * 0.07, tx: 0, ty: 0 });
  setEmo(emo, emo === 'laugh' ? 1.4 : 1.1, true);
  hearts(x, y - 60, 1 + (pts > 12 ? 2 : 0));
  G.shake = Math.min(14, G.shake + pts * 0.35); G.zoom = Math.min(0.03, G.zoom + pts * 0.0012);
  hideHint();
  updateHud(true);
  music.setIntensity(clamp(0.4 + G.combo * 0.06, 0.4, 1));
  if (starUp) { sfx('sparkle'); burstSparks(x, y - 80, 26, 9); floatText('STAR!', x, y - 140, '#ffb52e', 44); checkLevel(); }
  persist();
}
let lastLevel = Math.floor(save.stars / 5);
function checkLevel() {
  const lv = Math.floor(save.stars / 5);
  if (lv > lastLevel) {
    lastLevel = lv; G.paused = true; $('lvTitle').textContent = `Fun Level ${lv + 1}!`;
    $('lvMsg').textContent = 'Buddy is SO happy! Here are bonus coins!';
    $('lvStars').innerHTML = [0, 1, 2].map((i) => `<svg style="--i:${i}" viewBox="0 0 32 32"><path d="M16 3l3.8 8.2 8.9 1-6.6 6 1.9 8.8L16 22.5 8 27l1.9-8.8-6.6-6 8.9-1z" fill="#ffc83a" stroke="#c47d12" stroke-width="2" stroke-linejoin="round"/></svg>`).join('');
    setTimeout(() => { show('level', true); sfx('win'); }, 500);
  }
}

// ---------------------------------------------------------------------------------------------- world objects (pads, balloons, projectiles)
const pads = []; const projs = []; const balloons = []; const puddles = []; const launchers = [{ t: 0, a: 0, col: '#fff' }, { t: 0, a: 0, col: '#fff' }]; const fx = [];
const pointers = new Map();

function partsNear(x, y, R) {
  const out = [];
  for (const p of buddy.list) { const dx = p.body.position.x - x, dy = p.body.position.y - y, d = Math.hypot(dx, dy); if (d < R + p.rad) out.push({ p, d, dx, dy }); }
  return out;
}
function buddyCenter() { return buddy.parts.torso.body.position; }
function boost(vx, vy) { for (const p of buddy.list) { const v = p.body.velocity; Body.setVelocity(p.body, { x: v.x * 0.5 + vx, y: vy + rnd(-1, 1) }); } buddy.floppy = Math.max(buddy.floppy, 0.5); }
function floppy(t) { buddy.floppy = Math.max(buddy.floppy, t); }

function swingHit(x, y, tool) {
  const hammer = tool === 'hammer';
  const R = hammer ? 70 : 95, power = hammer ? 17 : 11;
  fx.push({ type: tool, x, y, t: 0, dur: 0.34, dir: x < buddyCenter().x ? 1 : -1 });
  const hits = partsNear(x, y, R);
  sfx('whoosh', { volume: 0.5, pitch: hammer ? 1 : 0.8 });
  if (!hits.length) return;
  const cx = buddyCenter().x, side = x < cx ? 1 : -1;
  for (const h of hits) {
    const d = Math.hypot(h.dx, h.dy) || 1, fall = 1 - clamp(h.d / (R + h.p.rad), 0, 1) * 0.55;
    const dx = 0.6 * side + 0.4 * h.dx / d, dy = -0.45 + 0.4 * h.dy / d;
    const l = Math.hypot(dx, dy) || 1;
    Body.setVelocity(h.p.body, { x: h.p.body.velocity.x * 0.3 + dx / l * power * fall, y: h.p.body.velocity.y * 0.3 + dy / l * power * fall });
    Body.setAngularVelocity(h.p.body, h.p.body.angularVelocity + side * rnd(0.1, 0.35) * fall);
    h.p.sq = Math.max(h.p.sq, 0.34); h.p.sqa = Math.atan2(dy, dx); h.p.sqv = 0;
  }
  floppy(hammer ? 1.2 : 0.9);
  if (hammer) { sfx('boing', { pitch: rnd(0.9, 1.3) }); sfx('squeak', { volume: 0.7 }); splashRing(x, y); burstSparks(x, y, 10, 6, ['#fff', '#ffd23f']); }
  else { sfx('pop', { volume: 0.7, pitch: 0.7 }); sfx('squeak', { volume: 0.6, pitch: 0.8 }); for (let i = 0; i < 14; i++) P_(PT.puff, x + rnd(-20, 20), y + rnd(-20, 20), rnd(-3, 3), rnd(-3, 1), rnd(0.5, 0.9), rnd(12, 22), 'rgba(255,255,255,0.85)', 0.02, 0.94, 0.6); hearts(x, y, 2); }
  fun(hammer ? 16 : 10, hammer ? 'boing' : 'giggle', x, y, hammer ? 'wow' : 'laugh');
  if (hammer) { G.shake = Math.max(G.shake, 8); }
}
function splashRing(x, y) { const p = P_(PT.ring, x, y, 0, 0, 0.4, 10, '#ffffff', 0, 1, 190); p.vr = 0; }

function launch(tool, tx, ty) {
  const side = tx > W / 2 ? 0 : 1; // launcher on the far side
  const L = launchers[side]; const px = side === 0 ? 70 : W - 70, py = floorY - 40;
  const a = Math.atan2(ty - py, tx - px);
  L.t = 1.2; L.a = a; L.col = CANNON[tool]; L.rec = 1; L.side = side; L.px = px; L.py = py;
  const mx = px + Math.cos(a) * 70, my = py + Math.sin(a) * 70;
  sfx(tool === 'confetti' ? 'pop' : 'shoot', { pitch: tool === 'beach' ? 0.7 : 1.1, volume: 0.8 });
  puff(mx, my, 6, 'rgba(255,255,255,0.8)', 3, 10);
  if (tool === 'confetti') {
    burstConfetti(mx, my, 46, 20, a, 0.5);
    for (let i = 0; i < 20; i++) P_(PT.conf, mx, my, Math.cos(a + rnd(-0.2, 0.2)) * rnd(10, 30), Math.sin(a + rnd(-0.2, 0.2)) * rnd(10, 30), rnd(1.2, 2.2), rnd(6, 10), pick(CONF), 0.18, 0.97);
    // push buddy if in line
    const dx = Math.cos(a), dy = Math.sin(a); let hit = false;
    for (const p of buddy.list) { const rx = p.body.position.x - mx, ry = p.body.position.y - my, along = rx * dx + ry * dy, perp = Math.abs(rx * dy - ry * dx); if (along > 0 && along < 900 && perp < 70 + along * 0.1) { Body.setVelocity(p.body, { x: p.body.velocity.x + dx * 6, y: p.body.velocity.y + dy * 6 - 1 }); hit = true; } }
    if (hit) { floppy(0.6); sfx('sparkle', { volume: 0.7 }); fun(9, 'pop', tx, ty, 'laugh'); burstConfetti(buddyCenter().x, buddyCenter().y - 40, 30, 8); }
    return;
  }
  const cfg = { water: { r: 18, rest: 0.1 }, cupcake: { r: 19, rest: 0.2 }, icecream: { r: 17, rest: 0.1 }, glitter: { r: 19, rest: 0.3 }, beach: { r: 40, rest: 1.0 } }[tool];
  const g = 0.2778 * engine.gravity.scale / 0.001 * 1;
  const dist = Math.hypot(tx - mx, ty - my); const T = clamp(dist / 17, 22, 52);
  const vx = (tx - mx) / T, vy = (ty - my - 0.5 * g * T * T) / T;
  const body = Bodies.circle(mx, my, cfg.r * (tool === 'beach' ? 1 : K) * (tool === 'beach' ? K : 1), { restitution: cfg.rest, friction: 0.2, frictionAir: tool === 'beach' ? 0.004 : 0.002, density: tool === 'beach' ? 0.0005 : 0.0025, label: 'proj' });
  body.plugin = { proj: tool, born: G.t, hit: false };
  Body.setVelocity(body, { x: vx, y: vy }); Body.setAngularVelocity(body, rnd(-0.2, 0.2));
  Composite.add(world, body); projs.push({ body, tool, r: body.circleRadius, born: G.t, last: 0 });
  if (tool === 'beach') { const bs = projs.filter((p) => p.tool === 'beach'); if (bs.length > 4) killProj(bs[0], true); }
}
function killProj(p, pop) { Composite.remove(world, p.body); const i = projs.indexOf(p); if (i >= 0) projs.splice(i, 1); if (pop) puff(p.body.position.x, p.body.position.y, 8, 'rgba(255,255,255,0.9)', 3, 18); }

function placePad(kind, x) {
  const same = pads.filter((p) => p.kind === kind); if (same.length >= 2) removePad(same[0]);
  x = clamp(x, 90, W - 90);
  let body, y;
  if (kind === 'tramp') { y = floorY - 30 - 11; body = Bodies.rectangle(x, y, 190 * K + 30, 22, { isStatic: true, restitution: 1.0, friction: 0.2, chamfer: { radius: 10 }, label: 'pad' }); }
  else { y = floorY - 76 * K; body = Bodies.circle(x, y, 52 * K, { isStatic: true, restitution: 1.0, friction: 0.2, label: 'pad' }); }
  body.plugin = { pad: kind };
  Composite.add(world, body);
  const pad = { kind, body, x, y, born: G.t, life: kind === 'tramp' ? 14 : 14, sq: 0, sqv: 0, pop: 0 };
  pads.push(pad); sfx('pop', { pitch: 1.3 }); sfx('boing', { pitch: 1.4, volume: 0.5 });
  burstSparks(x, floorY - 40, 10, 5, ['#fff', '#7ad8ff', '#ffd23f']);
  // lift anyone standing right over it
  const c = buddyCenter(); if (Math.abs(c.x - x) < 120 && c.y > floorY - 260) { boost((c.x - x) * 0.05, -16); sfx('boing', { pitch: 1.1 }); fun(18, 'boing', c.x, c.y, 'wow'); pad.sq = 0.5; }
  return pad;
}
function removePad(p) { Composite.remove(world, p.body); const i = pads.indexOf(p); if (i >= 0) pads.splice(i, 1); puff(p.x, p.y, 10, 'rgba(255,255,255,0.9)', 4, 16); burstSparks(p.x, p.y, 8, 5); }

function addBalloons(x, y) {
  const B = buddy, t = B.parts.torso.body;
  if (balloons.length >= 9) return;
  const cols = ['#ff5d8f', '#ffd23f', '#3ec6ff', '#58d68d', '#b57bff', '#ff9f43'];
  for (let i = 0; i < 3 && balloons.length < 9; i++) {
    const hand = B.parts[i % 2 ? 'lAL' : 'lAR'].body;
    const bx = hand.position.x + rnd(-30, 30), by = hand.position.y - 70 - i * 10;
    const body = Bodies.circle(bx, by, 26 * K, { frictionAir: 0.045, restitution: 0.6, density: 0.0004, collisionFilter: { group: -1 }, label: 'balloon' });
    body.plugin = { balloon: true };
    const anchor = i % 2 ? B.parts.lAL.body : B.parts.lAR.body;
    const con = Constraint.create({ bodyA: anchor, bodyB: body, pointA: { x: 0, y: D_ARM() }, pointB: { x: 0, y: 24 * K }, length: 70 + i * 26 + rnd(0, 20), stiffness: 0.03, damping: 0.05 });
    Composite.add(world, [body, con]); balloons.push({ body, con, col: cols[(balloons.length + i) % 6], born: G.t });
  }
  sfx('powerup', { volume: 0.5 }); sfx('squeak', { volume: 0.6 });
  burstSparks(x, y, 8, 4); fun(8, 'yay', buddyCenter().x, buddyCenter().y - 60, 'happy');
}
function D_ARM() { return DIM.ajl / 2; }
function popBalloon(b) {
  const p = b.body.position; Composite.remove(world, [b.body, b.con]); const i = balloons.indexOf(b); if (i >= 0) balloons.splice(i, 1);
  burstConfetti(p.x, p.y, 22, 8); puff(p.x, p.y, 6, b.col, 4, 14); sfx('pop', { pitch: rnd(0.9, 1.4) }); sfx('squeak', { volume: 0.4, pitch: 1.4 });
  fun(7, 'pop', p.x, p.y, 'wow');
}
function balloonForces() {
  if (!balloons.length) return;
  const gs = engine.gravity.scale * engine.gravity.y; const lift = buddy.mass * gs * 0.2;
  for (const b of balloons) { b.body.force.y -= lift + b.body.mass * gs * 1.1; b.body.force.x += Math.sin(G.t * 1.3 + b.born) * b.body.mass * 0.00002; }
}

// ---------------------------------------------------------------------------------------------- collisions
const lastImpact = { t: 0 };
Events.on(engine, 'collisionStart', (ev) => {
  for (const pr of ev.pairs) {
    const A = pr.bodyA, Bd = pr.bodyB; const bp = A.plugin && A.plugin.buddy ? A : (Bd.plugin && Bd.plugin.buddy ? Bd : null);
    const other = bp === A ? Bd : A;
    const nrm = pr.collision.normal;
    const rv = Math.hypot(A.velocity.x - Bd.velocity.x, A.velocity.y - Bd.velocity.y);
    if (bp) {
      const part = buddy.list.find((q) => q.body === bp);
      if (part && rv > 2.5) { part.sq = Math.max(part.sq, Math.min(0.4, rv * 0.03)); part.sqa = Math.atan2(nrm.y, nrm.x); part.sqv = 0; }
      if (rv > 7 && G.t - lastImpact.t > 0.16) { lastImpact.t = G.t; const mass = other.isStatic; sfx(mass ? 'boing' : 'squeak', { volume: clamp(rv / 22, 0.25, 0.8), pitch: rnd(0.8, 1.4) }); if (mass && rv > 11) { puff(bp.position.x, Math.min(bp.position.y + 20, floorY), 4, 'rgba(255,255,255,0.7)', 2, 12); G.shake = Math.max(G.shake, rv * 0.35); if (other.label === 'ground') airFun(rv); } }
      if (other.plugin && other.plugin.pad) padHit(other, rv);
      if (other.plugin && other.plugin.proj && !other.plugin.hit) projHit(other, part, rv);
    } else if (other.plugin && other.plugin.proj && !other.plugin.proj.done) {
      const o = A.plugin && A.plugin.proj ? A : Bd, ot = A === o ? Bd : A;
      if (ot.isStatic) projGround(o, rv);
    }
  }
});
function airFun(rv) { if (rv > 14 && G.t - G.lastFun > 0.8) fun(5 + Math.min(10, rv * 0.3), 'wow', buddyCenter().x, buddyCenter().y - 40, 'happy'); }
function padHit(padBody, rv) {
  const pad = pads.find((p) => p.body === padBody); if (!pad) return;
  const c = buddyCenter(); const kind = pad.kind;
  if (G.t - (pad.lastHit || 0) < 0.25) return; pad.lastHit = G.t;
  pad.sq = 0.6;
  const vy = kind === 'tramp' ? -(Math.max(13, rv * 0.9 + 9)) : -(Math.max(15, rv * 0.9 + 11));
  const vx = kind === 'tramp' ? 0 : clamp((c.x - pad.x) * 0.12, -6, 6);
  boost(vx, Math.max(vy, -26)); sfx('boing', { pitch: kind === 'tramp' ? 1.0 : 1.3, volume: 0.9 }); sfx('squeak', { volume: 0.5 });
  setEmo('wow', 0.8, true);
  burstSparks(pad.x, pad.y - 20, 12, 7, ['#fff', '#7ad8ff']); splashRing(pad.x, pad.y - 10);
  fun(kind === 'tramp' ? 16 : 18, 'boing', c.x, c.y - 30, 'wow'); G.shake = Math.max(G.shake, 7);
}
function projHit(body, part, rv) {
  const tool = body.plugin.proj; const p = projs.find((q) => q.body === body); if (!p) return;
  const pos = body.position; const c = buddyCenter();
  if (tool === 'beach') { if (G.t - p.last < 0.35) return; p.last = G.t; sfx('boing', { pitch: 0.8 }); fun(12, 'boing', pos.x, pos.y - 20, 'laugh'); floppy(0.8); return; }
  body.plugin.hit = true;
  floppy(0.9);
  if (tool === 'water') { splash(pos.x, pos.y, 36, '#6fcfff', 10); splash(pos.x, pos.y, 14, '#fff', 6); sfx('splash'); sfx('squeak', { volume: 0.7 }); buddy.wet = 4; fun(11, 'splat', pos.x, pos.y, 'wow'); puff(pos.x, pos.y, 4, 'rgba(180,230,255,0.8)', 3, 20); }
  else if (tool === 'cupcake') { addDecal(part, pos, ['#ff9ec7', '#ffd2e6'], 'cake'); for (let i = 0; i < 14; i++) P_(PT.dot, pos.x, pos.y, rnd(-5, 5), rnd(-6, 1), rnd(0.5, 1), rnd(3, 6), pick(['#ff9ec7', '#ffd2e6', '#8fe3ff', '#ffd23f']), 0.3, 0.97); sfx('pop', { pitch: 0.8 }); sfx('squeak', { volume: 0.8 }); fun(14, 'splat', pos.x, pos.y, 'happy'); }
  else if (tool === 'icecream') { addDecal(part, pos, ['#ffa8d2', '#a8f0d0'], 'ice'); for (let i = 0; i < 12; i++) P_(PT.dot, pos.x, pos.y, rnd(-5, 5), rnd(-6, 1), rnd(0.5, 1), rnd(3, 6), pick(['#ffa8d2', '#a8f0d0', '#fff']), 0.3, 0.97); sfx('splash', { volume: 0.7 }); sfx('squeak', { volume: 0.8, pitch: 1.2 }); fun(14, 'splat', pos.x, pos.y, 'happy'); }
  else if (tool === 'glitter') { glitterBurst(pos.x, pos.y); }
  killProj(p, false);
}
function projGround(body, rv) {
  const tool = body.plugin.proj; const p = projs.find((q) => q.body === body); if (!p || tool === 'beach' || body.plugin.hit) return;
  const pos = body.position; body.plugin.hit = true;
  if (tool === 'water') { splash(pos.x, pos.y, 26, '#6fcfff', 8); sfx('splash', { volume: 0.7 }); puddles.push({ x: pos.x, t: 0 }); if (puddles.length > 6) puddles.shift(); }
  else if (tool === 'glitter') glitterBurst(pos.x, pos.y, true);
  else { puff(pos.x, pos.y, 8, tool === 'cupcake' ? '#ffb8d6' : '#ffc4e0', 3, 14); sfx('pop', { volume: 0.5 }); }
  killProj(p, false);
}
function glitterBurst(x, y, ground) {
  burstSparks(x, y, 40, 14, ['#fff', '#ffd23f', '#ff9ee0', '#9be6ff', '#c9a6ff']);
  for (let i = 0; i < 70; i++) { const a = rnd(0, TAU), s = rnd(2, 12); P_(PT.glit, x, y, Math.cos(a) * s, Math.sin(a) * s - 2, rnd(1.2, 2.2), rnd(2, 4.5), pick(['#fff', '#ffd23f', '#ff9ee0', '#9be6ff']), 0.1, 0.95); }
  puff(x, y, 8, 'rgba(255,200,255,0.8)', 4, 24); sfx('sparkle'); sfx('pop', { pitch: 1.3, volume: 0.6 });
  let hit = false; for (const h of partsNear(x, y, 170)) { const d = Math.hypot(h.dx, h.dy) || 1, f = 1 - h.d / 220; Body.setVelocity(h.p.body, { x: h.p.body.velocity.x + h.dx / d * 9 * f, y: h.p.body.velocity.y + h.dy / d * 9 * f - 3 }); hit = true; }
  if (hit && !ground) { floppy(1); buddy.glitter = 5; fun(16, 'sparkle', x, y, 'wow'); G.shake = Math.max(G.shake, 6); }
}
function addDecal(part, pos, cols, kind) {
  const b = (part || buddy.parts.head).body; const ang = b.angle; const dx = pos.x - b.position.x, dy = pos.y - b.position.y;
  const lx = dx * Math.cos(-ang) - dy * Math.sin(-ang), ly = dx * Math.sin(-ang) + dy * Math.cos(-ang);
  buddy.decals.push({ part: part ? part.name : 'head', x: lx * 0.7, y: ly * 0.7, r: rnd(12, 18) * K * 1.4, cols, kind, life: 7, rot: rnd(0, TAU) });
  if (buddy.decals.length > 8) buddy.decals.shift();
}

// ---------------------------------------------------------------------------------------------- input / tools
function worldPos(e) { return { x: e.clientX / S, y: e.clientY / S }; }
let fanPtr = null;
function onDown(e) {
  if (G.state !== 'play' || G.paused) { if (G.state === 'title') return; return; }
  try { cv.setPointerCapture(e.pointerId); } catch (err) { /* ignore */ }
  music.unlock();
  const w = worldPos(e); const ptr = { id: e.pointerId, x: w.x, y: w.y, px: w.x, py: w.y, vx: 0, vy: 0, down: true, hitT: 0, tick: 0, grabCon: null };
  pointers.set(e.pointerId, ptr); G.idleT = 0; hideHint();
  const tool = G.tool;
  if (tool === 'hammer' || tool === 'pillow') swingHit(w.x, w.y, tool);
  else if (tool === 'hand') grab(ptr);
  else if (tool === 'tramp' || tool === 'mushroom') placePad(tool, w.x);
  else if (tool === 'balloons') { const b = balloons.find((q) => Math.hypot(q.body.position.x - w.x, q.body.position.y - w.y) < 50); if (b) popBalloon(b); else addBalloons(w.x, w.y); }
  else if (tool === 'feather') sfx('swish', { volume: 0.4 });
  else if (tool === 'fan' || tool === 'magnet') sfx('whoosh', { volume: 0.4 });
  else launch(tool, w.x, w.y);
}
function onMove(e) {
  const ptr = pointers.get(e.pointerId); const w = worldPos(e);
  mouse.x = w.x; mouse.y = w.y;
  if (!ptr) return;
  ptr.vx = w.x - ptr.x; ptr.vy = w.y - ptr.y; ptr.x = w.x; ptr.y = w.y;
  const tool = G.tool;
  if ((tool === 'hammer' || tool === 'pillow')) {
    const sp = Math.hypot(ptr.vx, ptr.vy);
    if (sp > 22 && G.t - ptr.hitT > 0.35) { const near = partsNear(w.x, w.y, 50); if (near.length) { ptr.hitT = G.t; swingHit(w.x, w.y, tool); } }
  }
  if (tool === 'confetti' && G.t - ptr.hitT > 0.5) { ptr.hitT = G.t; launch(tool, w.x, w.y); }
}
function onUp(e) {
  const ptr = pointers.get(e.pointerId); if (!ptr) return;
  if (ptr.grabCon) releaseGrab(ptr);
  pointers.delete(e.pointerId);
}
const mouse = { x: 0, y: 0 };
cv.addEventListener('pointerdown', (e) => { e.preventDefault(); onDown(e); });
cv.addEventListener('pointermove', (e) => { e.preventDefault(); onMove(e); });
cv.addEventListener('pointerup', (e) => { e.preventDefault(); onUp(e); });
cv.addEventListener('pointercancel', onUp);
for (const ev of ['contextmenu', 'gesturestart', 'gesturechange', 'dragstart', 'selectstart']) document.addEventListener(ev, (e) => e.preventDefault());
document.addEventListener('touchmove', (e) => { if (!e.target.closest || !e.target.closest('#shelf,.grid')) e.preventDefault(); }, { passive: false });
let lastTouch = 0; document.addEventListener('touchend', (e) => { const n = Date.now(); if (n - lastTouch < 350) e.preventDefault(); lastTouch = n; }, { passive: false });

function grab(ptr) {
  let best = null, bd = 1e9;
  for (const p of buddy.list) { const d = Math.hypot(p.body.position.x - ptr.x, p.body.position.y - ptr.y) - p.rad; if (d < bd) { bd = d; best = p; } }
  if (!best || bd > 46) return;
  const b = best.body; const dx = ptr.x - b.position.x, dy = ptr.y - b.position.y;
  const lx = dx * Math.cos(-b.angle) - dy * Math.sin(-b.angle), ly = dx * Math.sin(-b.angle) + dy * Math.cos(-b.angle);
  ptr.grabCon = Constraint.create({ pointA: { x: ptr.x, y: ptr.y }, bodyB: b, pointB: { x: lx, y: ly }, stiffness: 0.12, damping: 0.1, length: 0 });
  Composite.add(world, ptr.grabCon); buddy.grab = ptr; ptr.gt = G.t; sfx('squeak', { volume: 0.6, pitch: 1.3 }); setEmo('wow', 1, true);
  best.sq = 0.3; best.sqa = rnd(0, TAU);
}
function releaseGrab(ptr) {
  Composite.remove(world, ptr.grabCon); ptr.grabCon = null; buddy.grab = null;
  const c = buddy.parts.torso.body; const sp = Math.hypot(c.velocity.x, c.velocity.y);
  floppy(1.0); sfx('whoosh', { volume: clamp(sp / 20, 0.2, 0.7) });
  if (sp > 9) { fun(6 + sp * 0.8, 'wow', c.position.x, c.position.y - 50, 'laugh'); }
  else setEmo('happy', 1, true);
}

function toolFrame(dt) {
  const tool = G.tool; const B = buddy;
  for (const ptr of pointers.values()) {
    ptr.tick += dt;
    if (tool === 'hand' && ptr.grabCon) { ptr.grabCon.pointA.x = ptr.x; ptr.grabCon.pointA.y = ptr.y; B.muscle = 0.3; B.floppy = 0.4; const sp = Math.hypot(ptr.vx, ptr.vy); if (sp > 14 && G.t - (ptr.ft || 0) > 1.0) { ptr.ft = G.t; fun(4 + sp * 0.2, 'giggle', B.parts.head.body.position.x, B.parts.head.body.position.y - 30, 'laugh'); } }
    else if (tool === 'feather') {
      const near = partsNear(ptr.x, ptr.y, 30);
      if (near.length) {
        B.tickle = 0.3; const sp = Math.hypot(ptr.vx, ptr.vy);
        for (const h of near) { Body.setAngularVelocity(h.p.body, h.p.body.angularVelocity + rnd(-0.03, 0.03) * (1 + sp * 0.05)); if (Math.random() < 0.2) Body.setVelocity(h.p.body, { x: h.p.body.velocity.x + rnd(-0.8, 0.8), y: h.p.body.velocity.y - rnd(0, 1.3) }); }
        if (Math.random() < 0.18) P_(PT.heart, ptr.x + rnd(-20, 20), ptr.y, rnd(-1, 1), rnd(-2, -1), 1, rnd(9, 14), '#ff8fb8', -0.01, 0.99);
        if (ptr.tick > 0.5 && sp > 2) { ptr.tick = 0; sfx('squeak', { volume: 0.5, pitch: rnd(1, 1.4) }); fun(5, 'tickle', ptr.x, ptr.y - 20, 'laugh'); }
        floppy(0.3); setEmo('laugh', 0.4);
      }
    } else if (tool === 'fan') {
      const dir = ptr.x > buddyCenter().x ? -1 : 1; const fxp = dir > 0 ? 50 : W - 50; fanPtr = { x: fxp, y: ptr.y, dir };
      for (const p of B.list) {
        const dx = (p.body.position.x - fxp) * dir, dy = p.body.position.y - ptr.y;
        if (dx > 0 && dx < 760 && Math.abs(dy) < 170 + dx * 0.15) { const f = (1 - dx / 900) * (1 - Math.abs(dy) / 300); Body.setVelocity(p.body, { x: p.body.velocity.x + dir * 1.0 * f, y: p.body.velocity.y - 0.32 * f }); }
      }
      if (Math.random() < 0.7) { const y = ptr.y + rnd(-100, 100); P_(PT.streak, fxp + dir * 60, y, dir * rnd(14, 24), rnd(-0.5, 0.5), rnd(0.5, 0.9), rnd(30, 60), 'rgba(255,255,255,0.8)', 0, 1); }
      B.floppy = Math.max(B.floppy, 0.5);
      if (Math.abs(B.parts.torso.body.velocity.x) > 3 && G.t - (ptr.ft || 0) > 0.9) { ptr.ft = G.t; fun(6, 'wow', buddyCenter().x, buddyCenter().y - 60, 'wow'); sfx('whoosh', { volume: 0.4 }); }
    } else if (tool === 'magnet') {
      let any = false;
      for (const p of B.list) { const dx = ptr.x - p.body.position.x, dy = ptr.y - p.body.position.y, d = Math.hypot(dx, dy) || 1; if (d < 380) { const a = Math.min(0.9, 90 / d) ; const v = p.body.velocity; Body.setVelocity(p.body, { x: (v.x + dx / d * a) * 0.975, y: (v.y + dy / d * a) * 0.975 }); any = true; } }
      if (any) { B.floppy = Math.max(B.floppy, 0.5); if (Math.random() < 0.3) P_(PT.dot, ptr.x + rnd(-60, 60), ptr.y + rnd(-60, 60), 0, 0, 0.5, rnd(2, 4), pick(['#fff', '#ffd23f', '#9be6ff']), 0, 0.9); if (G.t - (ptr.ft || 0) > 0.8) { ptr.ft = G.t; fun(6, 'wow', ptr.x, ptr.y - 40, 'wow'); sfx('whoosh', { volume: 0.4, pitch: 0.7 }); } }
    }
  }
  if (tool !== 'fan' || !pointers.size) fanPtr = null;
}

// ---------------------------------------------------------------------------------------------- per-step update
let T_ = 0;
function stepPhysics() {
  const B = buddy; B.t = G.t;
  // floppy -> muscle strength
  B.floppy = Math.max(0, B.floppy - 1 / 60);
  const target = B.floppy > 0 ? 0.12 : 1;
  B.muscle += (target - B.muscle) * (B.floppy > 0 ? 0.3 : 0.03);
  muscles(); balloonForces();
  if (buddy.grab) buddy.muscle = 0.3;
  Engine.update(engine, 1000 / 60);
  // squash springs
  for (const p of B.list) { p.sqv += -p.sq * 0.3 - p.sqv * 0.1; p.sq += p.sqv; const v = p.body.velocity, sp = Math.hypot(v.x, v.y); p.st += (Math.min(0.2, sp * 0.011) - p.st) * 0.25; }
  // dizzy meter
  const av = Math.abs(B.parts.torso.body.angularVelocity);
  B.dizzy = B.dizzy * 0.985 + av * 1.2;
  if (B.dizzy > 22 && B.emo !== 'dizzy' && av < 0.25) { B.dizzy = 0; setEmo('dizzy', 2.6, true); fun(10, 'dizzy', buddyCenter().x, buddyCenter().y - 90, 'dizzy'); sfx('squeak', { pitch: 0.7 }); setEmo('dizzy', 2.6, true); }
  // out of bounds rescue
  const tp = buddyCenter(); if (tp.y > floorY + 160 || tp.x < -200 || tp.x > W + 200 || !isFinite(tp.x)) respawnBuddy();
  // balloons expire / projectile cleanup
  for (let i = projs.length - 1; i >= 0; i--) { const p = projs[i]; if (G.t - p.born > (p.tool === 'beach' ? 14 : 8) || p.body.position.y > floorY + 100) killProj(p, true); }
  for (let i = balloons.length - 1; i >= 0; i--) if (G.t - balloons[i].born > 40) popBalloon(balloons[i]);
  for (let i = pads.length - 1; i >= 0; i--) { const p = pads[i]; if (G.t - p.born > p.life) removePad(p); }
}

// ---------------------------------------------------------------------------------------------- rendering: buddy
let shadowGrad = null;
function drawShadow(c) {
  const t = buddyCenter(); const h = Math.max(0, floorY - t.y); const sc = clamp(1 - h / 520, 0.25, 1);
  c.save(); c.translate(t.x, floorY + 8); c.scale(DIM.tw * 1.5 * sc, DIM.tw * 0.32 * sc);
  if (!shadowGrad) { shadowGrad = c.createRadialGradient(0, 0, 0, 0, 0, 1); shadowGrad.addColorStop(0, 'rgba(60,20,80,0.42)'); shadowGrad.addColorStop(1, 'rgba(60,20,80,0)'); }
  c.fillStyle = shadowGrad; c.beginPath(); c.arc(0, 0, 1, 0, TAU); c.fill(); c.restore();
}
function skinCols() { const base = SKINS[save.equip.skin] || SKINS.peach; return { base, light: shade(base, 0.4), mid: shade(base, 0.12), dark: shade(base, -0.28), out: shade(base, -0.42), belly: shade(base, 0.5), cheek: '#ff7aa8' }; }
function squashed(c, p, fn) {
  const b = p.body; c.save(); c.translate(b.position.x, b.position.y);
  const v = b.velocity; const sp = Math.hypot(v.x, v.y);
  if (p.st > 0.01) { const va = Math.atan2(v.y, v.x); c.rotate(va); c.scale(1 + p.st, 1 / (1 + p.st * 0.85)); c.rotate(-va); }
  if (Math.abs(p.sq) > 0.003) { c.rotate(p.sqa); c.scale(1 - p.sq, 1 + p.sq * 0.9); c.rotate(-p.sqa); }
  c.rotate(b.angle); fn(); c.restore();
}
function limb(c, pts, w, col) {
  c.lineCap = 'round'; c.lineJoin = 'round';
  c.beginPath(); c.moveTo(pts[0].x, pts[0].y); c.quadraticCurveTo(pts[1].x, pts[1].y, pts[2].x, pts[2].y);
  c.strokeStyle = col.out; c.lineWidth = w + 4; c.stroke();
  c.strokeStyle = col.base; c.lineWidth = w; c.stroke();
  c.save(); c.translate(-w * 0.12, -w * 0.14); c.strokeStyle = col.light; c.globalAlpha = 0.55; c.lineWidth = w * 0.32; c.stroke(); c.restore();
}
function endPt(b, s) { const jl = b === null ? 0 : 0; return jl; }
function capPts(p, jl) { const b = p.body, s = Math.sin(b.angle), co = Math.cos(b.angle); return [{ x: b.position.x - s * -(-jl / 2) * -1, y: 0 }]; }
function ends(p, jl) { const b = p.body, s = Math.sin(b.angle), c = Math.cos(b.angle); return { top: { x: b.position.x + s * jl / 2, y: b.position.y - c * jl / 2 }, bot: { x: b.position.x - s * jl / 2, y: b.position.y + c * jl / 2 } }; }

function drawBuddy(c) {
  const B = buddy, P = B.parts, col = skinCols(); const t = G.t;
  const torso = P.torso.body, head = P.head.body;
  drawShadow(c);
  // cape / wings behind
  const back = save.equip.back;
  if (back) squashed(c, P.torso, () => drawBack(c, back, DIM.tw, DIM.th, -torso.velocity.x * 3 + Math.sin(t * 6) * 2, t));
  // legs
  for (const n of ['R', 'L']) {
    const u = ends(P['uL' + n], DIM.ljl), l = ends(P['lL' + n], DIM.ljl);
    limb(c, [u.top, { x: (u.bot.x + l.top.x) / 2, y: (u.bot.y + l.top.y) / 2 }, l.bot], DIM.lw, col);
    const lb = P['lL' + n].body; c.save(); c.translate(l.bot.x, l.bot.y + DIM.lw * 0.2); c.rotate(lb.angle * 0.6);
    c.beginPath(); c.ellipse(DIM.lw * 0.35, 0, DIM.lw * 0.95, DIM.lw * 0.62, 0, 0, TAU); c.fillStyle = col.mid; c.fill(); c.strokeStyle = col.out; c.lineWidth = 3.5; c.stroke();
    c.fillStyle = 'rgba(255,255,255,0.35)'; c.beginPath(); c.ellipse(DIM.lw * 0.2, -DIM.lw * 0.2, DIM.lw * 0.5, DIM.lw * 0.18, 0, 0, TAU); c.fill(); c.restore();
  }
  // torso
  squashed(c, P.torso, () => {
    const w = DIM.tw, h = DIM.th; const br = 1 + Math.sin(t * 2.6) * 0.012;
    c.scale(1, br);
    rr(c, -w / 2, -h / 2, w, h, w * 0.46);
    const g = c.createRadialGradient(-w * 0.2, -h * 0.28, 4, 0, 0, h * 0.75); g.addColorStop(0, col.light); g.addColorStop(0.55, col.base); g.addColorStop(1, col.dark);
    c.fillStyle = g; c.fill(); c.strokeStyle = col.out; c.lineWidth = 4; c.lineJoin = 'round'; c.stroke();
    c.save(); c.clip();
    c.fillStyle = col.belly; c.globalAlpha = 0.7; c.beginPath(); c.ellipse(0, h * 0.08, w * 0.3, h * 0.3, 0, 0, TAU); c.fill(); c.globalAlpha = 1;
    c.fillStyle = '#ff8fb8'; c.beginPath(); const hx = 0, hy = h * 0.08, hs = w * 0.1; c.moveTo(hx, hy + hs * 1.1); c.bezierCurveTo(hx - hs * 2.2, hy - hs * 0.4, hx - hs * 0.9, hy - hs * 1.6, hx, hy - hs * 0.4); c.bezierCurveTo(hx + hs * 0.9, hy - hs * 1.6, hx + hs * 2.2, hy - hs * 0.4, hx, hy + hs * 1.1); c.fill();
    drawDecals(c, 'torso');
    c.restore();
    c.fillStyle = 'rgba(255,255,255,0.4)'; c.beginPath(); c.ellipse(-w * 0.26, -h * 0.28, w * 0.12, h * 0.07, -0.6, 0, TAU); c.fill();
    if (save.equip.neck) drawNeck(c, save.equip.neck, w, h);
  });
  // arms
  for (const n of ['R', 'L']) {
    const u = ends(P['uA' + n], DIM.ajl), l = ends(P['lA' + n], DIM.ajl);
    limb(c, [u.top, { x: (u.bot.x + l.top.x) / 2, y: (u.bot.y + l.top.y) / 2 }, l.bot], DIM.aw, col);
    c.beginPath(); c.arc(l.bot.x, l.bot.y, DIM.aw * 0.72, 0, TAU); c.fillStyle = col.mid; c.fill(); c.strokeStyle = col.out; c.lineWidth = 3.5; c.stroke();
    c.fillStyle = 'rgba(255,255,255,0.4)'; c.beginPath(); c.ellipse(l.bot.x - DIM.aw * 0.2, l.bot.y - DIM.aw * 0.25, DIM.aw * 0.22, DIM.aw * 0.12, -0.5, 0, TAU); c.fill();
  }
  // head
  squashed(c, P.head, () => drawHeadPart(c, col, t));
}
function drawDecals(c, which) {
  for (const d of buddy.decals) {
    if (d.part !== which) continue; const a = clamp(d.life / 2, 0, 1); c.save(); c.globalAlpha = a; c.translate(d.x, d.y); c.rotate(d.rot);
    const r = d.r; c.fillStyle = d.cols[0];
    c.beginPath(); for (let i = 0; i < 7; i++) { const aa = i / 7 * TAU, rr_ = r * (0.7 + 0.35 * Math.sin(i * 2.7 + d.rot)); c.lineTo(Math.cos(aa) * rr_, Math.sin(aa) * rr_); } c.closePath(); c.fill();
    c.fillStyle = d.cols[1]; c.beginPath(); c.arc(-r * 0.2, -r * 0.2, r * 0.45, 0, TAU); c.fill();
    if (d.kind === 'cake') { c.fillStyle = '#ffd23f'; c.fillRect(r * 0.2, -r * 0.1, 4, 2); c.fillStyle = '#3ec6ff'; c.fillRect(-r * 0.5, r * 0.2, 4, 2); c.fillStyle = '#58d68d'; c.fillRect(r * 0.1, r * 0.4, 4, 2); }
    c.fillStyle = d.cols[0]; c.beginPath(); c.ellipse(r * 0.1, r * 1.0, r * 0.2, r * 0.45 + (1 - a) * 4, 0, 0, TAU); c.fill();
    c.restore();
  }
}
function drawHeadPart(c, col, t) {
  const R = DIM.headR, B = buddy;
  // ears
  for (const s of [-1, 1]) { c.beginPath(); c.arc(s * R * 0.68, -R * 0.78, R * 0.32, 0, TAU); c.fillStyle = col.mid; c.fill(); c.strokeStyle = col.out; c.lineWidth = 4; c.stroke(); c.beginPath(); c.arc(s * R * 0.68, -R * 0.78, R * 0.17, 0, TAU); c.fillStyle = '#ffb3cf'; c.fill(); }
  c.beginPath(); c.arc(0, 0, R, 0, TAU);
  const g = c.createRadialGradient(-R * 0.35, -R * 0.4, R * 0.1, 0, 0, R * 1.1); g.addColorStop(0, col.light); g.addColorStop(0.5, col.base); g.addColorStop(1, col.dark);
  c.fillStyle = g; c.fill(); c.strokeStyle = col.out; c.lineWidth = 4; c.stroke();
  c.save(); c.beginPath(); c.arc(0, 0, R - 1, 0, TAU); c.clip();
  // muzzle
  c.fillStyle = col.belly; c.globalAlpha = 0.8; c.beginPath(); c.ellipse(0, R * 0.32, R * 0.36, R * 0.27, 0, 0, TAU); c.fill(); c.globalAlpha = 1;
  drawDecals(c, 'head');
  c.restore();
  c.fillStyle = 'rgba(255,255,255,0.5)'; c.beginPath(); c.ellipse(-R * 0.42, -R * 0.58, R * 0.2, R * 0.1, -0.6, 0, TAU); c.fill();
  drawFace(c, R, col, t);
  if (save.equip.face) drawHead(c, save.equip.face, R, t);
  if (save.equip.hat && save.equip.hat !== 'helmet') drawHead(c, save.equip.hat, R, t);
  if (save.equip.hat === 'helmet') drawHead(c, 'helmet', R, t);
  // wet shine / dizzy stars
  if (B.emo === 'dizzy') for (let i = 0; i < 4; i++) { const a = t * 3 + i * TAU / 4; c.save(); c.translate(Math.cos(a) * R * 0.9 - 0, -R * 1.08 + Math.sin(a) * R * 0.2); c.rotate(-B.head_a || 0); c.fillStyle = '#ffd23f'; starPath(c, 0, 0, R * 0.2, R * 0.08, 5, a); c.fill(); c.strokeStyle = '#c9961f'; c.lineWidth = 1.5; c.stroke(); c.restore(); }
  if (B.sleepy) { c.fillStyle = '#7aa8ff'; c.font = `900 ${R * 0.5}px ui-rounded,system-ui,sans-serif`; c.textAlign = 'center'; c.fillText('z', R * 1.0, -R * 0.9 - Math.sin(t * 2) * 4); c.font = `900 ${R * 0.34}px ui-rounded,system-ui,sans-serif`; c.fillText('z', R * 1.25, -R * 1.25 - Math.sin(t * 2 + 1) * 4); }
}
function drawFace(c, R, col, t) {
  const B = buddy; const emo = B.sleepy ? 'sleepy' : B.emo; const head = B.parts.head.body;
  // look direction in head space
  const lx = B.look.x, ly = B.look.y; const ca = Math.cos(-head.angle), sa = Math.sin(-head.angle);
  const lox = (lx * ca - ly * sa) * R * 0.055, loy = (lx * sa + ly * ca) * R * 0.05;
  const blink = B.blink > 0 ? 1 - Math.sin((1 - B.blink / 0.16) * Math.PI) * 0.92 : 1;
  const ex = R * 0.37, ey = -R * 0.05;
  c.lineCap = 'round'; c.lineJoin = 'round';
  // cheeks
  c.fillStyle = col.cheek; c.globalAlpha = emo === 'laugh' || emo === 'happy' ? 0.7 : 0.5;
  for (const s of [-1, 1]) { c.beginPath(); c.ellipse(s * R * 0.66, R * 0.3, R * 0.15, R * 0.1, 0, 0, TAU); c.fill(); } c.globalAlpha = 1;
  const dark = '#3a1d4a';
  // eyes
  if (emo === 'laugh') {
    c.strokeStyle = dark; c.lineWidth = R * 0.075; for (const s of [-1, 1]) { c.beginPath(); c.arc(s * ex, ey + R * 0.07, R * 0.15, Math.PI * 1.1, Math.PI * 1.9); c.stroke(); }
    c.fillStyle = '#7fd4ff'; for (const s of [-1, 1]) { c.beginPath(); c.ellipse(s * R * 0.62, R * 0.12 + Math.sin(t * 9) * 1.5, R * 0.05, R * 0.08, 0, 0, TAU); c.fill(); }
  } else if (emo === 'dizzy') {
    for (const s of [-1, 1]) { c.save(); c.translate(s * ex, ey); c.fillStyle = '#fff'; c.beginPath(); c.arc(0, 0, R * 0.2, 0, TAU); c.fill(); c.strokeStyle = dark; c.lineWidth = 2; c.stroke(); c.rotate(t * 8 * s); c.beginPath(); for (let i = 0; i < 40; i++) { const a = i * 0.45, r = i * R * 0.0045; c.lineTo(Math.cos(a) * r, Math.sin(a) * r); } c.lineWidth = R * 0.04; c.stroke(); c.restore(); }
  } else if (emo === 'sleepy') {
    c.strokeStyle = dark; c.lineWidth = R * 0.07; for (const s of [-1, 1]) { c.beginPath(); c.arc(s * ex, ey - R * 0.02, R * 0.14, 0.15, Math.PI - 0.15); c.stroke(); }
  } else {
    const k = emo === 'wow' ? 1.18 : 1; const rx = R * 0.135 * k, ry = R * 0.185 * k * blink;
    for (const s of [-1, 1]) {
      const x = s * ex + lox, y = ey + loy;
      c.fillStyle = dark; c.beginPath(); c.ellipse(x, y, rx, ry, 0, 0, TAU); c.fill();
      if (ry > R * 0.06) { const g = c.createRadialGradient(x, y + ry * 0.4, 1, x, y, ry); g.addColorStop(0, 'rgba(120,80,200,0.55)'); g.addColorStop(1, 'rgba(120,80,200,0)'); c.fillStyle = g; c.beginPath(); c.ellipse(x, y, rx, ry, 0, 0, TAU); c.fill(); c.fillStyle = '#fff'; c.beginPath(); c.ellipse(x - rx * 0.3, y - ry * 0.32, rx * 0.4, ry * 0.34, 0, 0, TAU); c.fill(); c.beginPath(); c.arc(x + rx * 0.35, y + ry * 0.38, rx * 0.17, 0, TAU); c.fill(); }
    }
    if (emo === 'wow') { c.strokeStyle = shade(col.base, -0.5); c.lineWidth = R * 0.05; for (const s of [-1, 1]) { c.beginPath(); c.arc(s * ex, ey - R * 0.36, R * 0.15, Math.PI * 1.2, Math.PI * 1.8); c.stroke(); } }
  }
  // nose
  c.fillStyle = '#5a2a52'; c.beginPath(); c.ellipse(0, R * 0.2, R * 0.075, R * 0.052, 0, 0, TAU); c.fill(); c.fillStyle = 'rgba(255,255,255,0.7)'; c.beginPath(); c.arc(-R * 0.02, R * 0.185, R * 0.018, 0, TAU); c.fill();
  // mouth
  const my = R * 0.36;
  if (emo === 'laugh' || emo === 'happy' && B.emoT > 0.3) {
    const open = emo === 'laugh' ? 1 : 0.65; const mw = R * 0.26, mh = R * 0.3 * open + Math.sin(t * 14) * (emo === 'laugh' ? R * 0.02 : 0);
    c.beginPath(); c.moveTo(-mw, my); c.quadraticCurveTo(0, my + R * 0.06, mw, my); c.quadraticCurveTo(mw * 0.8, my + mh, 0, my + mh); c.quadraticCurveTo(-mw * 0.8, my + mh, -mw, my); c.closePath();
    c.fillStyle = '#6a1f3f'; c.fill(); c.save(); c.clip(); c.fillStyle = '#ff7a9a'; c.beginPath(); c.ellipse(0, my + mh, mw * 0.65, mh * 0.55, 0, 0, TAU); c.fill(); c.fillStyle = '#fff'; c.fillRect(-mw, my - 2, mw * 2, R * 0.07); c.restore();
    c.strokeStyle = dark; c.lineWidth = R * 0.045; c.beginPath(); c.moveTo(-mw, my); c.quadraticCurveTo(0, my + R * 0.06, mw, my); c.stroke();
  } else if (emo === 'wow') {
    c.fillStyle = '#6a1f3f'; c.beginPath(); c.ellipse(0, my + R * 0.1, R * 0.1, R * 0.14, 0, 0, TAU); c.fill(); c.fillStyle = '#ff7a9a'; c.beginPath(); c.ellipse(0, my + R * 0.18, R * 0.065, R * 0.05, 0, 0, TAU); c.fill();
  } else if (emo === 'dizzy') {
    c.strokeStyle = dark; c.lineWidth = R * 0.05; c.beginPath(); for (let i = 0; i <= 12; i++) { const x = -R * 0.22 + i / 12 * R * 0.44, y = my + R * 0.08 + Math.sin(i * 1.4 + t * 10) * R * 0.04; i ? c.lineTo(x, y) : c.moveTo(x, y); } c.stroke();
  } else {
    c.strokeStyle = dark; c.lineWidth = R * 0.05; c.beginPath(); c.moveTo(-R * 0.2, my); c.quadraticCurveTo(-R * 0.1, my + R * 0.13, 0, my + R * 0.04); c.quadraticCurveTo(R * 0.1, my + R * 0.13, R * 0.2, my); c.stroke();
  }
}
function drawBalloon(c, b) {
  const p = b.body.position, an = b.con.bodyA; const aw = an ? { x: an.position.x + Math.cos(an.angle) * b.con.pointA.x - Math.sin(an.angle) * b.con.pointA.y, y: an.position.y + Math.sin(an.angle) * b.con.pointA.x + Math.cos(an.angle) * b.con.pointA.y } : p;
  const r = b.body.circleRadius;
  c.strokeStyle = 'rgba(90,60,110,0.75)'; c.lineWidth = 2; c.beginPath(); c.moveTo(aw.x, aw.y); c.quadraticCurveTo((aw.x + p.x) / 2 + Math.sin(G.t * 2 + b.born) * 8, (aw.y + p.y) / 2 + 20, p.x, p.y + r * 1.1); c.stroke();
  c.save(); c.translate(p.x, p.y); c.rotate(Math.sin(G.t * 1.5 + b.born) * 0.12);
  c.beginPath(); c.ellipse(0, 0, r * 0.95, r * 1.18, 0, 0, TAU); const g = c.createRadialGradient(-r * 0.3, -r * 0.4, 1, 0, 0, r * 1.3); g.addColorStop(0, shade(b.col, 0.6)); g.addColorStop(0.5, b.col); g.addColorStop(1, shade(b.col, -0.3)); c.fillStyle = g; c.fill(); c.strokeStyle = shade(b.col, -0.35); c.lineWidth = 3; c.stroke();
  c.beginPath(); c.moveTo(-4, r * 1.14); c.lineTo(4, r * 1.14); c.lineTo(0, r * 1.34); c.closePath(); c.fillStyle = shade(b.col, -0.25); c.fill();
  c.fillStyle = 'rgba(255,255,255,0.75)'; c.beginPath(); c.ellipse(-r * 0.35, -r * 0.45, r * 0.16, r * 0.34, 0.4, 0, TAU); c.fill(); c.restore();
}
function drawPad(c, p) {
  const age = G.t - p.born; const sc = age < 0.3 ? 1 - Math.pow(1 - age / 0.3, 3) * 1 + Math.sin(age * 20) * 0.05 * (1 - age / 0.3) : (p.life - age < 0.6 ? (p.life - age) / 0.6 : 1);
  const sq = p.sq; c.save(); c.translate(p.x, floorY); c.scale(sc, sc);
  if (p.kind === 'tramp') {
    const top = -30 - 11 + 0, w = 190 * K + 30;
    c.fillStyle = 'rgba(60,20,80,0.22)'; c.beginPath(); c.ellipse(0, 6, w * 0.55, 10, 0, 0, TAU); c.fill();
    c.strokeStyle = '#4a5ae8'; c.lineWidth = 8; c.lineCap = 'round'; for (const x of [-w * 0.42, w * 0.42]) { c.beginPath(); c.moveTo(x, -26); c.lineTo(x * 1.08, 4); c.stroke(); }
    c.save(); c.translate(0, top); const dip = sq * 14 * Math.cos(age * 30 * (1 - Math.min(1, (G.t - (p.lastHit || 0)) / 0.5)));
    rr(c, -w / 2 - 4, -13, w + 8, 26, 13); c.fillStyle = '#ff5d8f'; c.fill(); c.strokeStyle = '#b82f63'; c.lineWidth = 3.5; c.stroke();
    c.beginPath(); c.moveTo(-w / 2 + 8, -5); c.quadraticCurveTo(0, -5 + dip, w / 2 - 8, -5); c.lineTo(w / 2 - 8, 5); c.quadraticCurveTo(0, 5 + dip, -w / 2 + 8, 5); c.closePath(); c.fillStyle = '#4fb8ff'; c.fill();
    c.strokeStyle = 'rgba(255,255,255,0.7)'; c.lineWidth = 3; c.beginPath(); c.moveTo(-w / 2 + 16, -3); c.quadraticCurveTo(0, -3 + dip, w / 2 - 16, -3); c.stroke(); c.restore();
  } else {
    const rcap = 52 * K; const dip = sq * 0.18;
    c.fillStyle = 'rgba(60,20,80,0.22)'; c.beginPath(); c.ellipse(0, 6, rcap * 1.2, 10, 0, 0, TAU); c.fill();
    rr(c, -16 * K, -62 * K, 32 * K, 62 * K, 14 * K); c.fillStyle = '#fff1d8'; c.fill(); c.strokeStyle = '#b98d52'; c.lineWidth = 3.5; c.stroke();
    c.save(); c.translate(0, -76 * K); c.scale(1 + dip, 1 - dip); const cw = rcap * 1.12;
    c.beginPath(); c.moveTo(-cw, 12 * K); c.bezierCurveTo(-cw * 1.05, -cw * 1.2, cw * 1.05, -cw * 1.2, cw, 12 * K); c.quadraticCurveTo(0, 26 * K, -cw, 12 * K); c.closePath();
    const g = c.createRadialGradient(-cw * 0.3, -cw * 0.5, 2, 0, 0, cw * 1.3); g.addColorStop(0, '#ff9a9a'); g.addColorStop(1, '#e0283e'); c.fillStyle = g; c.fill(); c.strokeStyle = '#9c1428'; c.lineWidth = 3.5; c.stroke();
    c.fillStyle = '#fff'; for (const [x, y, r] of [[-0.5, -0.35, 0.2], [0.35, -0.7, 0.22], [0.62, -0.18, 0.16], [0, -0.1, 0.12]]) { c.beginPath(); c.arc(x * cw, y * cw, r * cw, 0, TAU); c.fill(); }
    c.restore();
  }
  c.restore();
}
function drawProj(c, p) {
  const b = p.body; c.save(); c.translate(b.position.x, b.position.y); c.rotate(b.angle);
  const r = p.r;
  c.fillStyle = 'rgba(60,20,80,0.0)';
  if (p.tool === 'beach') drawBeachBall(c, r, 0); else { const sc = (r * 2.5) / 100; c.scale(sc, sc); drawTool(c, p.tool); }
  c.restore();
  // ground shadow
  const h = floorY - b.position.y; if (h > 0) { c.fillStyle = `rgba(60,20,80,${clamp(0.25 - h / 1800, 0.05, 0.25)})`; c.beginPath(); c.ellipse(b.position.x, floorY + 6, r * (p.tool === 'beach' ? 1.1 : 0.9), r * 0.22, 0, 0, TAU); c.fill(); }
}
function drawLauncher(c, L, i) {
  if (L.t <= 0) return; const age = 1.2 - L.t; const ease = Math.min(1, age / 0.18) * Math.min(1, L.t / 0.3);
  const x0 = L.side === 0 ? -100 : W + 100; const x = lerp(x0, L.px, 1 - Math.pow(1 - ease, 3));
  c.save(); c.translate(x, L.py); c.scale(0.9, 0.9);
  if (L.side === 0) { c.rotate(L.a); drawCannon(c, L.col, L.rec * 14, 1); } else { c.scale(-1, 1); c.rotate(Math.PI - L.a); drawCannon(c, L.col, L.rec * 14, 1); }
  c.restore();
}
function drawToolFx(c) {
  for (const f of fx) {
    const k = f.t / f.dur; if (k > 1) continue;
    c.save(); c.translate(f.x, f.y);
    const e = k < 0.5 ? k * 2 : 1; const ang = f.dir * (lerp(-1.5, 0.75, easeOut(Math.min(1, k * 2.2))));
    c.rotate(-f.dir * 0 + ang * -1 * (f.dir)); // pivot at the tap point
    c.scale(f.dir, 1);
    const sc = f.type === 'hammer' ? 1.45 : 1.8; c.globalAlpha = k < 0.8 ? 1 : (1 - k) / 0.2;
    c.translate(f.type === 'hammer' ? 20 : 14, f.type === 'hammer' ? -22 : -14); c.rotate(-0.0); c.scale(sc, sc); drawTool(c, f.type);
    c.restore();
  }
}
const easeOut = (t) => 1 - Math.pow(1 - t, 3);
function drawPointerTools(c) {
  for (const ptr of pointers.values()) {
    const tool = G.tool; c.save(); c.translate(ptr.x, ptr.y);
    if (tool === 'feather') { c.rotate(Math.sin(G.t * 9) * 0.2 - 0.3); c.scale(1.7, 1.7); c.translate(14, -24); drawTool(c, 'feather'); }
    else if (tool === 'magnet') { c.scale(1.5, 1.5); c.rotate(Math.sin(G.t * 6) * 0.06); drawTool(c, 'magnet'); c.strokeStyle = 'rgba(255,255,255,0.5)'; c.lineWidth = 2; for (let i = 0; i < 3; i++) { c.beginPath(); c.arc(0, 0, ((G.t * 60 + i * 40) % 120) + 10, 0, TAU); c.globalAlpha = 1 - (((G.t * 60 + i * 40) % 120) / 120); c.stroke(); } }
    else if (tool === 'hand' && ptr.grabCon) { c.scale(0.9, 0.9); drawTool(c, 'hand'); }
    c.restore();
  }
  if (fanPtr) { c.save(); c.translate(fanPtr.x, fanPtr.y); c.scale(fanPtr.dir * -1.8, 1.8); c.translate(0, 0); drawTool(c, 'fan', G.t); c.restore(); }
}

// ---------------------------------------------------------------------------------------------- main render
const snow = []; for (let i = 0; i < 70; i++) snow.push({ x: Math.random(), y: Math.random(), s: rnd(1.5, 4), v: rnd(20, 50), ph: rnd(0, 6) });
let hudCoin = null;
function render() {
  ensureBg();
  ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.drawImage(bgCanvas, 0, 0);
  const sh = G.shake; const shx = (Math.random() - 0.5) * sh, shy = (Math.random() - 0.5) * sh; const z = 1 + G.zoom;
  ctx.setTransform(dpr * S * z, 0, 0, dpr * S * z, (shx - (z - 1) * vw / 2 / S * S) * dpr, (shy - (z - 1) * vh / 2) * dpr);
  // ambient
  if (save.room === 'snow') { ctx.fillStyle = 'rgba(255,255,255,0.95)'; for (const f of snow) { const x = ((f.x * W + Math.sin(G.t + f.ph) * 20) % W + W) % W, y = (f.y * (floorY + 20) + G.t * f.v) % (floorY + 20); ctx.beginPath(); ctx.arc(x, y, f.s, 0, TAU); ctx.fill(); } }
  if (save.room === 'space') { for (let i = 0; i < 14; i++) { const x = (i * 137.5) % W, y = (i * 71.3) % (floorY * 0.8), a = 0.5 + 0.5 * Math.sin(G.t * 2 + i); ctx.fillStyle = `rgba(255,255,255,${a})`; starPath(ctx, x, y, 3 + a * 3, 1, 4, G.t * 0.3 + i); ctx.fill(); } }
  for (const pd_ of puddles) { const a = clamp(1 - pd_.t / 3, 0, 1); ctx.fillStyle = `rgba(100,190,255,${a * 0.5})`; ctx.beginPath(); ctx.ellipse(pd_.x, floorY + 10, 50 * Math.min(1, pd_.t * 6 + 0.2), 8, 0, 0, TAU); ctx.fill(); }
  for (const p of pads) drawPad(ctx, p);
  launchers.forEach((L, i) => drawLauncher(ctx, L, i));
  drawBuddy(ctx);
  for (const b of balloons) drawBalloon(ctx, b);
  for (const p of projs) drawProj(ctx, p);
  drawToolFx(ctx); drawPointerTools(ctx);
  drawParticles(ctx); drawTexts(ctx);
}
function drawParticles(c) {
  for (const p of parts_) {
    if (!p.on) continue; const k = p.life / p.max; c.save(); c.translate(p.x, p.y);
    switch (p.type) {
      case PT.conf: c.rotate(p.rot); c.scale(1, Math.abs(Math.cos(p.rot * 1.7))); c.globalAlpha = Math.min(1, k * 2); c.fillStyle = p.col; c.fillRect(-p.size / 2, -p.size / 4, p.size, p.size / 2); break;
      case PT.dot: case PT.glit: c.globalAlpha = Math.min(1, k * 2); c.fillStyle = p.col; c.beginPath(); c.arc(0, 0, p.size * (p.type === PT.glit ? 0.6 + 0.4 * Math.sin(p.rot * 3) : 1), 0, TAU); c.fill(); break;
      case PT.star: c.rotate(p.rot); c.globalAlpha = Math.min(1, k * 2.5); c.fillStyle = p.col; starPath(c, 0, 0, p.size * (0.4 + 0.6 * k), p.size * 0.18, 4, 0); c.fill(); break;
      case PT.puff: c.globalAlpha = k * 0.8; c.fillStyle = p.col; c.beginPath(); c.arc(0, 0, p.size, 0, TAU); c.fill(); break;
      case PT.drop: c.globalAlpha = Math.min(1, k * 2); c.fillStyle = p.col; c.beginPath(); c.arc(0, 0, p.size, 0, TAU); c.fill(); c.fillStyle = 'rgba(255,255,255,0.7)'; c.beginPath(); c.arc(-p.size * 0.3, -p.size * 0.3, p.size * 0.3, 0, TAU); c.fill(); break;
      case PT.heart: { c.globalAlpha = Math.min(1, k * 2); c.fillStyle = p.col; const s = p.size / 12; c.scale(s, s); c.beginPath(); c.moveTo(0, 5); c.bezierCurveTo(-12, -3, -5, -11, 0, -4); c.bezierCurveTo(5, -11, 12, -3, 0, 5); c.fill(); break; }
      case PT.streak: c.globalAlpha = k * 0.7; c.strokeStyle = p.col; c.lineWidth = 3; c.lineCap = 'round'; c.beginPath(); c.moveTo(0, 0); c.lineTo(-Math.sign(p.vx) * p.size, 0); c.stroke(); break;
      case PT.ring: c.globalAlpha = k * 0.8; c.strokeStyle = p.col; c.lineWidth = 6 * k; c.beginPath(); c.arc(0, 0, p.size, 0, TAU); c.stroke(); break;
      default: break;
    }
    c.restore();
  }
  // coin flyers
  for (const f of flyers) { if (f.t < 0) continue; const k = clamp(f.t / 0.7, 0, 1), e = k * k * (3 - 2 * k); const x = lerp(f.x0, f.tx, e), y = lerp(f.y0, f.ty, e) - Math.sin(k * Math.PI) * 60; ctx.save(); ctx.translate(x, y); ctx.scale(1 - k * 0.4, 1 - k * 0.4); ctx.fillStyle = '#ffd23f'; ctx.beginPath(); ctx.arc(0, 0, 11, 0, TAU); ctx.fill(); ctx.strokeStyle = '#c47d12'; ctx.lineWidth = 3; ctx.stroke(); ctx.strokeStyle = '#fff3a0'; ctx.lineWidth = 2.5; ctx.beginPath(); ctx.arc(0, 0, 6, 3.6, 5.2); ctx.stroke(); ctx.restore(); }
}
function drawTexts(c) {
  c.textAlign = 'center'; c.lineJoin = 'round';
  for (const t of texts) {
    const k = t.t / 1.1; const sc = k < 0.15 ? easeOut(k / 0.15) * 1.25 : lerp(1.25, 1, Math.min(1, (k - 0.15) * 4)); c.save(); c.translate(t.x, t.y - k * 60); c.scale(sc, sc); c.rotate(Math.sin(t.t * 8) * 0.04); c.globalAlpha = k > 0.7 ? clamp((1 - k) / 0.3, 0, 1) : 1;
    c.font = `900 ${t.size}px ui-rounded,"SF Pro Rounded",system-ui,sans-serif`; c.lineWidth = 9; c.strokeStyle = '#fff'; c.strokeText(t.txt, 0, 0); c.lineWidth = 4; c.strokeStyle = 'rgba(60,20,90,0.25)'; c.strokeText(t.txt, 0, 2); c.fillStyle = t.col; c.fillText(t.txt, 0, 0); c.restore();
  }
}

// ---------------------------------------------------------------------------------------------- frame update
let last = performance.now(), acc = 0;
function updateVisuals(dt) {
  const B = buddy; G.t += dt;
  G.shake *= Math.pow(0.0008, dt); if (G.shake < 0.05) G.shake = 0; G.zoom *= Math.pow(0.01, dt);
  // particles
  for (const p of parts_) { if (!p.on) continue; const s = dt * 60; p.life -= dt; if (p.life <= 0) { p.on = false; continue; } p.vy += p.g * s; const d = Math.pow(p.drag, s); p.vx *= d; p.vy *= d; p.x += p.vx * s; p.y += p.vy * s; p.rot += p.vr * s; if (p.grow) p.size += p.grow * s * (p.type === PT.ring ? 1 : 0.1); }
  for (let i = texts.length - 1; i >= 0; i--) { texts[i].t += dt; texts[i].x += texts[i].vx; if (texts[i].t > 1.1) texts.splice(i, 1); }
  for (const f of flyers) { f.t += dt; if (!hudCoin) hudCoin = coinTarget(); f.tx = hudCoin.x; f.ty = hudCoin.y; }
  for (let i = flyers.length - 1; i >= 0; i--) if (flyers[i].t > 0.7) { flyers.splice(i, 1); coinBump(); }
  for (let i = fx.length - 1; i >= 0; i--) { fx[i].t += dt; if (fx[i].t > fx[i].dur) fx.splice(i, 1); }
  for (const L of launchers) { if (L.t > 0) { L.t -= dt; L.rec *= Math.pow(0.003, dt); } }
  for (const p of pads) { p.sqv += -p.sq * 0.25 - p.sqv * 0.12; p.sq += p.sqv + 0; if (p.sq > 0.0005 && !p.sqInit) p.sqInit = 1; p.sq *= Math.pow(0.04, dt); }
  for (let i = puddles.length - 1; i >= 0; i--) { puddles[i].t += dt; if (puddles[i].t > 3) puddles.splice(i, 1); }
  // buddy mood
  B.emoT -= dt; if (B.emoT <= 0 && B.emo !== 'idle') { B.emo = 'idle'; }
  B.wet -= dt; if (B.wet > 0 && Math.random() < 0.25) { const h = B.parts.head.body.position; P_(PT.drop, h.x + rnd(-30, 30), h.y + rnd(-10, 30), 0, 0.5, 0.7, rnd(2, 4), '#6fcfff', 0.3, 0.99); }
  if (B.glitter > 0) { B.glitter -= dt; if (Math.random() < 0.35) { const t = buddyCenter(); P_(PT.glit, t.x + rnd(-45, 45), t.y + rnd(-90, 60), rnd(-0.5, 0.5), rnd(0.2, 1), 0.9, rnd(2, 4), pick(['#fff', '#ffd23f', '#ff9ee0']), 0.05, 0.98); } }
  for (let i = B.decals.length - 1; i >= 0; i--) { B.decals[i].life -= dt; if (B.decals[i].life <= 0) B.decals.splice(i, 1); }
  if (!$('hint').classList.contains('hidden')) placeHint();
  B.blink -= dt; B.nextBlink -= dt; if (B.nextBlink <= 0) { B.blink = 0.16; B.nextBlink = rnd(2, 5); }
  if (B.tickle > 0) B.tickle -= dt;
  // eyes follow pointer
  const head = B.parts.head.body.position; let tx = mouse.x - head.x, ty = mouse.y - head.y; const d = Math.hypot(tx, ty) || 1; tx = tx / d * Math.min(1, d / 160); ty = ty / d * Math.min(1, d / 160);
  const first = pointers.values().next().value; if (first) { tx = first.x - head.x; ty = first.y - head.y; const dd = Math.hypot(tx, ty) || 1; tx = tx / dd; ty = ty / dd; }
  B.look.x += (tx - B.look.x) * Math.min(1, dt * 10); B.look.y += (ty - B.look.y) * Math.min(1, dt * 10);
  // sleepy after a long idle
  G.idleT += dt; if (G.state === 'play') { if (G.idleT > 25 && !B.sleepy && B.emo === 'idle') { B.sleepy = true; } if (G.idleT > 12 && G.idleT - dt <= 12) showHint('Pick a toy and play with Buddy!'); }
  if (B.sleepy && Math.random() < 0.01) P_(PT.z, head.x, head.y, 0, 0, 0, 0, '#fff');
  // combo timeout
  if (G.t - G.lastFun > 2.4 && G.combo > 0) { G.combo = 0; music.setIntensity(G.state === 'play' ? 0.5 : 0.4); updateHud(); }
  if (G.t - G.lastFun > 2.4 && G.meter > 0) { G.meter = Math.max(0, G.meter - 8 * dt); updateHudMeter(); }
  // title demo hop
  if (G.state === 'title') { G.demoT = (G.demoT || 0) - dt; if (G.demoT <= 0 && B.grounded) { G.demoT = rnd(2.2, 3.4); const m = Math.random() < 0.5 ? -1 : 1; for (const p of B.list) Body.setVelocity(p.body, { x: m * rnd(0.5, 2.5), y: -rnd(8, 12) }); B.floppy = 0.4; setEmo(Math.random() < 0.5 ? 'laugh' : 'wow', 1.0, true); sfx('boing', { volume: 0.35, pitch: rnd(1, 1.5) }); } }
}
function frame(now) {
  if (window.__hold) { last = now; requestAnimationFrame(frame); return; }
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  if (!G.paused) {
    acc += dt; let n = 0;
    while (acc >= 1 / 60 && n < 3) { stepPhysics(); acc -= 1 / 60; n++; }
    if (acc > 0.1) acc = 0;
    updateVisuals(dt); if (G.state === 'play') toolFrame(dt);
  } else { G.t += 0; }
  render();
  requestAnimationFrame(frame);
}

// ---------------------------------------------------------------------------------------------- UI
const ICON = {
  coin: '<svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="14" fill="#ffd23f" stroke="#c47d12" stroke-width="2.5"/><circle cx="16" cy="16" r="9" fill="none" stroke="#e0a416" stroke-width="2.5"/></svg>',
  speakerOn: '<svg viewBox="0 0 32 32"><path d="M5 12h5l7-6v20l-7-6H5z" fill="#ff4f94" stroke="#ff4f94" stroke-width="2" stroke-linejoin="round"/><path d="M21 11a7 7 0 0 1 0 10M24 7a12 12 0 0 1 0 18" fill="none" stroke="#ff4f94" stroke-width="3" stroke-linecap="round"/></svg>',
  speakerOff: '<svg viewBox="0 0 32 32"><path d="M5 12h5l7-6v20l-7-6H5z" fill="#c9b0d6" stroke="#c9b0d6" stroke-width="2" stroke-linejoin="round"/><path d="M22 12l7 8M29 12l-7 8" fill="none" stroke="#ff4f94" stroke-width="3.2" stroke-linecap="round"/></svg>',
  speakerOnW: '<svg viewBox="0 0 32 32"><path d="M5 12h5l7-6v20l-7-6H5z" fill="#fff" stroke="#fff" stroke-width="2" stroke-linejoin="round"/><path d="M21 11a7 7 0 0 1 0 10M24 7a12 12 0 0 1 0 18" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/></svg>',
  speakerOffW: '<svg viewBox="0 0 32 32"><path d="M5 12h5l7-6v20l-7-6H5z" fill="#fff" stroke="#fff" stroke-width="2" stroke-linejoin="round" opacity=".6"/><path d="M22 12l7 8M29 12l-7 8" fill="none" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/></svg>',
  bag: '<svg viewBox="0 0 32 32"><path d="M6 11h20l-1.6 16H7.6z" fill="#ff8fbe" stroke="#d93a7c" stroke-width="2.5" stroke-linejoin="round"/><path d="M11 13V9a5 5 0 0 1 10 0v4" fill="none" stroke="#d93a7c" stroke-width="2.8" stroke-linecap="round"/><path d="M16 15.5l1.5 3.2 3.4.4-2.5 2.3.7 3.4-3.1-1.7-3.1 1.7.7-3.4-2.5-2.3 3.4-.4z" fill="#fff"/></svg>',
};
const tileCanvases = {};
function iconCanvas(id, size, draw) {
  const cvs = document.createElement('canvas'); const d = Math.min(window.devicePixelRatio || 1, 2) * 1.5; cvs.width = cvs.height = Math.round(size * d);
  const c = cvs.getContext('2d'); c.translate(cvs.width / 2, cvs.height / 2); const s = cvs.width / 108; c.scale(s, s); draw(c); return cvs;
}
function buildShelf() {
  const sh = $('shelf'); sh.innerHTML = '';
  const shop = document.createElement('button'); shop.className = 'tile shopTile'; shop.innerHTML = `<div style="width:54px;height:54px;display:grid;place-items:center;pointer-events:none"><div style="width:46px;height:46px">${ICON.bag}</div></div><div class="nm">Shop</div>`; shop.onclick = () => { sfx('click'); openShop('toys'); }; sh.appendChild(shop);
  for (const t of TOOLS) {
    const b = document.createElement('button'); b.className = 'tile'; b.dataset.id = t.id;
    const cvs = iconCanvas(t.id, 62, (c) => drawTool(c, t.id)); b.appendChild(cvs);
    const nm = document.createElement('div'); nm.className = 'nm'; nm.textContent = SHORT[t.id]; b.appendChild(nm);
    const pr = document.createElement('div'); pr.className = 'price'; pr.innerHTML = `${ICON.coin}${t.price}`; b.appendChild(pr);
    b.onclick = () => tileClick(t, b); sh.appendChild(b);
  }
  sh.addEventListener('wheel', (e) => { if (Math.abs(e.deltaY) > Math.abs(e.deltaX)) { sh.scrollLeft += e.deltaY; e.preventDefault(); } }, { passive: false });
  refreshShelf();
}
function refreshShelf() {
  for (const b of $('shelf').querySelectorAll('.tile[data-id]')) {
    const t = TOOL[b.dataset.id], own = !!save.tools[t.id];
    b.classList.toggle('locked', !own); b.classList.toggle('sel', own && G.tool === t.id); b.classList.toggle('afford', !own && save.coins >= t.price);
    b.querySelector('.price').style.display = own ? 'none' : 'flex'; b.querySelector('.nm').style.display = own ? 'block' : 'none';
  }
}
function tileClick(t, b) {
  if (G.state !== 'play') return;
  if (!save.tools[t.id]) {
    if (save.coins >= t.price) { buy('tool', t.id, t.price); selectTool(t.id); } else { b.classList.remove('shake'); void b.offsetWidth; b.classList.add('shake'); sfx('squeak', { pitch: 0.6 }); toast(`Need ${t.price - save.coins} more coins!`); }
    return;
  }
  sfx('click'); selectTool(t.id);
}
function selectTool(id) {
  G.tool = id; save.tool = id; persist(); refreshShelf(); hideHint(); G.idleT = 0;
  const b = $('shelf').querySelector(`.tile[data-id="${id}"]`); if (b) b.scrollIntoView({ inline: 'center', block: 'nearest', behavior: 'smooth' });
  for (const p of pointers.values()) if (p.grabCon) releaseGrab(p);
}
function buy(kind, id, price) {
  save.coins -= price;
  if (kind === 'tool') save.tools[id] = 1; else if (kind === 'room') save.rooms[id] = 1; else save.outfits[id] = 1;
  persist(); updateHud(true); refreshShelf(); sfx('powerup'); sfx('sparkle');
  burstConfetti(W / 2, H / 2, 50, 14); floatText('Unlocked!', W / 2, floorY - 280, '#ffb52e', 44);
}
let toastT = 0;
function toast(msg) { const t = $('toast'); t.textContent = msg; t.classList.add('show'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('show'), 1800); }
let hintT = 0;
function showHint(msg) { const h = $('hint'); h.textContent = msg; placeHint(); h.classList.remove('hidden'); clearTimeout(hintT); hintT = setTimeout(() => h.classList.add('hidden'), 7000); }
function placeHint() { const h = $('hint'); if (!buddy) return; const hp = buddy.parts.head.body.position; const hh = h.offsetHeight || 60; h.style.top = Math.max(110, hp.y * S - 150 - hh) + 'px'; h.style.left = clamp(hp.x * S, h.offsetWidth / 2 + 8, vw - h.offsetWidth / 2 - 8) + 'px'; }
function hideHint() { $('hint').classList.add('hidden'); clearTimeout(hintT); }
function updateHudMeter() {
  const f = $('comboFill'); f.style.width = clamp(G.meter, 0, 100) + '%';
  const cb = $('combo'); cb.classList.toggle('hidden', !(G.combo > 0 || G.meter > 0.5));
  $('comboTxt').textContent = G.combo > 1 ? `COMBO x${G.combo}` : 'FUN METER';
}
function updateHud(bump) {
  $('coinN').textContent = save.coins; $('starN').textContent = save.stars; $('shopCoin').innerHTML = `${ICON.coin}<span>${save.coins}</span>`;
  updateHudMeter(); refreshShelf();
  if (bump) { const el = $('starPill'); el.classList.remove('bump'); void el.offsetWidth; }
}
function coinBump() { const el = $('coinPill'); el.classList.remove('bump'); void el.offsetWidth; el.classList.add('bump'); $('coinN').textContent = save.coins; sfx('coin', { volume: 0.25 }); }
function coinTarget() { const r = $('coinPill').getBoundingClientRect(); return { x: (r.left + 24) / S, y: (r.top + r.height / 2) / S }; }
function show(id, on) { $(id).classList.toggle('hidden', !on); }
function setMuteIcons() { const m = !!save.muted; $('muteBtn').innerHTML = m ? ICON.speakerOff : ICON.speakerOn; $('titleMute').innerHTML = m ? ICON.speakerOff : ICON.speakerOn; $('pMute').innerHTML = (m ? ICON.speakerOffW : ICON.speakerOnW) + (m ? 'Music Off' : 'Music On'); }
function toggleMute() { save.muted = !save.muted; try { music.setMuted(save.muted); } catch (e) { /* ignore */ } persist(); setMuteIcons(); }

// shop ------------------------------------------------------------------------------------------
let shopTab = 'toys';
function drawMini(c, cfg, size) { // little buddy for previews, drawn in a [-54,54] box
  const col = (() => { const base = SKINS[cfg.skin] || SKINS.peach; return { base, light: shade(base, 0.4), mid: shade(base, 0.12), dark: shade(base, -0.28), out: shade(base, -0.42), belly: shade(base, 0.5) }; })();
  const tw = 52, th = 54, R = 30;
  c.lineJoin = 'round'; c.lineCap = 'round'; c.save(); c.translate(0, 14); c.scale(0.74, 0.74);
  c.save(); c.translate(0, 28);
  if (cfg.back) drawBack(c, cfg.back, tw, th, 0, 0.5);
  rr(c, -tw / 2, -th / 2, tw, th, tw * 0.46); c.fillStyle = col.base; c.fill(); c.strokeStyle = col.out; c.lineWidth = 3.5; c.stroke();
  c.fillStyle = col.belly; c.globalAlpha = 0.7; c.beginPath(); c.ellipse(0, 5, tw * 0.28, th * 0.28, 0, 0, TAU); c.fill(); c.globalAlpha = 1;
  if (cfg.neck) drawNeck(c, cfg.neck, tw, th);
  c.restore();
  c.save(); c.translate(0, -12);
  for (const s of [-1, 1]) { c.beginPath(); c.arc(s * R * 0.68, -R * 0.78, R * 0.3, 0, TAU); c.fillStyle = col.mid; c.fill(); c.strokeStyle = col.out; c.lineWidth = 3.5; c.stroke(); }
  c.beginPath(); c.arc(0, 0, R, 0, TAU); const g = c.createRadialGradient(-R * 0.35, -R * 0.4, 3, 0, 0, R * 1.1); g.addColorStop(0, col.light); g.addColorStop(0.5, col.base); g.addColorStop(1, col.dark); c.fillStyle = g; c.fill(); c.strokeStyle = col.out; c.lineWidth = 3.5; c.stroke();
  c.fillStyle = col.belly; c.beginPath(); c.ellipse(0, R * 0.32, R * 0.34, R * 0.25, 0, 0, TAU); c.fill();
  c.fillStyle = '#3a1d4a'; for (const s of [-1, 1]) { c.beginPath(); c.ellipse(s * R * 0.37, -R * 0.05, R * 0.12, R * 0.17, 0, 0, TAU); c.fill(); c.fillStyle = '#fff'; c.beginPath(); c.arc(s * R * 0.37 - 2, -R * 0.1, R * 0.05, 0, TAU); c.fill(); c.fillStyle = '#3a1d4a'; }
  c.fillStyle = '#ff7aa8'; c.globalAlpha = 0.5; for (const s of [-1, 1]) { c.beginPath(); c.ellipse(s * R * 0.66, R * 0.3, R * 0.14, R * 0.09, 0, 0, TAU); c.fill(); } c.globalAlpha = 1;
  c.strokeStyle = '#3a1d4a'; c.lineWidth = 2.5; c.beginPath(); c.moveTo(-R * 0.18, R * 0.38); c.quadraticCurveTo(0, R * 0.55, R * 0.18, R * 0.38); c.stroke();
  if (cfg.face) drawHead(c, cfg.face, R, 0); if (cfg.hat) drawHead(c, cfg.hat, R, 0);
  c.restore(); c.restore();
}
function openShop(tab) {
  shopTab = tab || shopTab; G.paused = true; renderShop(); show('shop', true);
}
function closeShop() { show('shop', false); G.paused = false; last = performance.now(); refreshShelf(); }
function renderShop() {
  for (const t of document.querySelectorAll('.tab')) t.classList.toggle('on', t.dataset.t === shopTab);
  $('shopCoin').innerHTML = `${ICON.coin}<span>${save.coins}</span>`;
  const g = $('grid'); g.innerHTML = '';
  const card = (canvas, name, state, cls, onTap) => {
    const d = document.createElement('div'); d.className = 'item ' + cls; d.appendChild(canvas);
    const n = document.createElement('div'); n.className = 'nm'; n.textContent = name; d.appendChild(n); const s = document.createElement('div'); s.className = 'st'; s.innerHTML = state; d.appendChild(s);
    d.onclick = () => onTap(d); g.appendChild(d); return d;
  };
  const cantBuy = (d, price) => { d.classList.remove('shake'); void d.offsetWidth; d.classList.add('shake'); sfx('squeak', { pitch: 0.6 }); toast(`Need ${price - save.coins} more coins!`); };
  if (shopTab === 'toys') {
    for (const t of TOOLS) {
      const own = !!save.tools[t.id];
      card(iconCanvas(t.id, 76, (c) => drawTool(c, t.id)), t.name, own ? 'Use it!' : `${ICON.coin}${t.price}`, own ? (G.tool === t.id ? 'eq' : '') : (save.coins >= t.price ? 'buy' : 'cant'), (d) => {
        if (own) { selectTool(t.id); closeShop(); sfx('click'); } else if (save.coins >= t.price) { buy('tool', t.id, t.price); renderShop(); } else cantBuy(d, t.price);
      });
    }
  } else if (shopTab === 'rooms') {
    for (const [id, name, price] of ROOMS) {
      const own = !!save.rooms[id]; const cvs = document.createElement('canvas'); const dd = 2; cvs.width = 140 * dd; cvs.height = 96 * dd; cvs.style.cssText = 'width:140px;height:96px;border-radius:16px;box-shadow:0 3px 0 #e3d3ea';
      const c = cvs.getContext('2d'); c.scale(dd * 140 / 640, dd * 96 / 440); c.save(); c.beginPath(); c.rect(0, 0, 640, 440); c.clip(); drawRoom(c, id, 640, 440, 360); c.restore();
      card(cvs, name, own ? (save.room === id ? 'Here!' : 'Go!') : `${ICON.coin}${price}`, own ? (save.room === id ? 'eq' : '') : (save.coins >= price ? 'buy' : 'cant'), (d) => {
        if (own) { setRoom(id); closeShop(); } else if (save.coins >= price) { buy('room', id, price); setRoom(id); renderShop(); } else cantBuy(d, price);
      });
    }
  } else {
    const sec = (t) => { const s = document.createElement('div'); s.className = 'sec'; s.textContent = t; g.appendChild(s); };
    const section = (title, slot, list) => {
      sec(title);
      for (const [id, name, price] of list) {
        const own = !!save.outfits[id]; const worn = save.equip[slot] === id;
        const cfg = slot === 'skin' ? { skin: id } : { skin: save.equip.skin, [slot]: id };
        card(iconCanvas(id, 76, (c) => drawMini(c, cfg)), name, own ? (worn ? 'Wearing' : 'Wear') : `${ICON.coin}${price}`, own ? (worn ? 'eq' : '') : (save.coins >= price ? 'buy' : 'cant'), (d) => {
          if (own) { save.equip[slot] = (slot !== 'skin' && worn) ? null : id; persist(); sfx('squeak', { pitch: 1.3 }); renderShop(); setEmo('happy', 1, true); }
          else if (save.coins >= price) { buy('outfit', id, price); save.equip[slot] = id; persist(); renderShop(); setEmo('laugh', 1.5, true); } else cantBuy(d, price);
        });
      }
    };
    section('Fur colour', 'skin', OUTFITS.skins); section('Hats', 'hat', OUTFITS.hat); section('Glasses', 'face', OUTFITS.face); section('Neck', 'neck', OUTFITS.neck); section('Back', 'back', OUTFITS.back);
  }
}
function setRoom(id) { save.room = id; persist(); applyRoomPhysics(); bgKey = ''; sfx('whoosh'); puddles.length = 0; }

// ---------------------------------------------------------------------------------------------- flow
function startGame() {
  music.unlock(); music.play(THEMES.toy, { intensity: 0.5 }); sfx('pop'); sfx('squeak');
  G.state = 'play'; show('title', false); $('hud').classList.remove('hidden'); $('shelfWrap').classList.remove('hidden');
  save.played = true; persist(); G.idleT = 0; updateHud();
  const t = TOOL[G.tool] && save.tools[G.tool] ? G.tool : 'hammer'; selectTool(t);
  setTimeout(() => { if (G.state === 'play' && G.ses.hits === 0) showHint(G.tool === 'hammer' ? 'Tap Buddy with the Boing Hammer!' : 'Tap Buddy to play!'); }, 500);
  burstConfetti(W / 2, floorY - 200, 40, 12);
}
function pauseGame() { if (G.state !== 'play') return; G.paused = true; show('pause', true); music.setIntensity(0.15); sfx('click'); }
function resumeGame() { show('pause', false); G.paused = false; last = performance.now(); music.setIntensity(0.5); }
function resetSession() { G.ses = { hits: 0, best: 0, coins: 0 }; G.combo = 0; G.meter = 0; }
function showDone() {
  show('pause', false); const s = G.ses; $('sHits').textContent = s.hits; $('sCombo').textContent = s.best; $('sCoins').textContent = s.coins;
  const stars = s.hits >= 40 ? 3 : s.hits >= 15 ? 2 : 1;
  $('bigStars').innerHTML = [0, 1, 2].map((i) => `<svg style="--i:${i}" viewBox="0 0 32 32"><path d="M16 3l3.8 8.2 8.9 1-6.6 6 1.9 8.8L16 22.5 8 27l1.9-8.8-6.6-6 8.9-1z" fill="${i < stars ? '#ffc83a' : '#e5d8ee'}" stroke="${i < stars ? '#c47d12' : '#c9b8d6'}" stroke-width="2" stroke-linejoin="round"/></svg>`).join('');
  $('doneMsg').textContent = stars === 3 ? 'Buddy is the happiest buddy ever!' : stars === 2 ? 'Buddy giggled a lot. So fun!' : 'Come back and play some more!';
  show('done', true); sfx('win'); burstConfetti(W / 2, H * 0.3, 60, 14); music.setIntensity(0.3);
}

// wire up UI
function wire() {
  $('playBtn').onclick = startGame;
  $('pauseBtn').onclick = pauseGame; $('resumeBtn').onclick = () => { sfx('click'); resumeGame(); };
  $('muteBtn').onclick = toggleMute; $('titleMute').onclick = () => { music.unlock(); toggleMute(); }; $('pMute').onclick = toggleMute;
  $('pReset').onclick = () => { respawnBuddy(); clearObjects(); resumeGame(); sfx('pop'); };
  $('pDone').onclick = showDone;
  $('againBtn').onclick = () => { show('done', false); resetSession(); G.paused = false; last = performance.now(); music.setIntensity(0.5); clearObjects(); respawnBuddy(); updateHud(); };
  $('lvOk').onclick = () => { show('level', false); save.coins += 25; G.ses.coins += 25; persist(); updateHud(); G.paused = false; last = performance.now(); sfx('coin'); burstConfetti(W / 2, H * 0.4, 40, 12); floatText('+25 coins!', W / 2, floorY - 260, '#ffb52e', 40); };
  $('shopClose').onclick = () => { sfx('click'); closeShop(); };
  for (const t of document.querySelectorAll('.tab')) t.onclick = () => { shopTab = t.dataset.t; sfx('click'); renderShop(); };
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' || e.key === 'p') { if (G.state === 'play') { if (!$('pause').classList.contains('hidden')) resumeGame(); else if ($('shop').classList.contains('hidden')) pauseGame(); } }
    if (G.state === 'play' && !G.paused && /^[0-9]$/.test(e.key)) { const own = TOOLS.filter((t) => save.tools[t.id]); const t = own[(+e.key + 9) % 10]; if (t) selectTool(t.id); }
  });
  document.addEventListener('visibilitychange', () => { if (document.hidden && G.state === 'play' && !G.paused) pauseGame(); });
}
function clearObjects() {
  for (const p of projs.slice()) killProj(p, false); for (const b of balloons.slice()) { Composite.remove(world, [b.body, b.con]); } balloons.length = 0; for (const p of pads.slice()) { Composite.remove(world, p.body); } pads.length = 0;
}
function buildLogo() {
  const mk = (txt, el, cols, off) => { el.innerHTML = ''; [...txt].forEach((ch, i) => { const s = document.createElement('span'); s.textContent = ch; const c = cols[(i + off) % cols.length]; s.style.setProperty('--c', c[0]); s.style.setProperty('--d', c[1]); s.style.setProperty('--i', i + off); el.appendChild(s); }); };
  const cols = [['#ff5d9e', '#b82f6a'], ['#ffd23f', '#c47d12'], ['#3ec6ff', '#1a6fb0'], ['#58d68d', '#1a8f50'], ['#b57bff', '#6a3fd4'], ['#ff9f43', '#b5601a']];
  mk('Buddy', document.querySelector('#logo .l1'), cols, 0); mk('Playground', document.querySelector('#logo .l2'), cols, 3);
}

// boot ------------------------------------------------------------------------------------------
function boot() {
  buildLogo(); resize(); applyRoomPhysics(); buildBuddy(W / 2, floorY - 300); buildShelf(); wire(); setMuteIcons(); updateHud();
  lastLevel = Math.floor(save.stars / 5);
  requestAnimationFrame((t) => { last = t; frame(t); });
}
boot();
window.__bp = { burstConfetti, burstSparks, render, LEGK, setAssist(v) { ASSIST = v; }, G, save, get buddy() { return buddy; }, step(n = 1) { for (let i = 0; i < n; i++) { stepPhysics(); updateVisuals(1 / 60); } }, selectTool, startGame, setRoom, music, get S() { return S; }, get W() { return W; }, get floorY() { return floorY; }, projs, pads, balloons, buy, openShop, closeShop, showDone, fun };
