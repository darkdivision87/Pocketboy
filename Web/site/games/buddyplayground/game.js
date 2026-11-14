// Buddy Playground: a squishy, kid-safe toy sandbox in the spirit of classic "ragdoll toy" games. Canvas 2D + matter-js ragdoll.
import { Maestro, THEMES } from '../shared/maestro.js';
import { drawBeachBall, drawCannon, drawHead, drawNeck, drawBack, drawRoom, shade, rr, starPath, lg, SKINS, OUTFITS, ROOMS } from './art.js';
import { drawItem, drawShirt, SHIRTS } from './items_art.js';
import { CATS, ITEMS, ITEM, SHORT } from './items.js';

const { Engine, Bodies, Body, Constraint, Composite, Events } = Matter;
const TAU = Math.PI * 2;
const K = 0.85; // buddy scale
const $ = (id) => document.getElementById(id);
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const lerp = (a, b, t) => a + (b - a) * t;
const rnd = (a, b) => a + Math.random() * (b - a);
const pick = (a) => a[(Math.random() * a.length) | 0];

// ---------------------------------------------------------------------------------------------- save data
const SAVE_KEY = 'buddyplayground.v2';
function defaults() {
  return { cash: 60, gold: 1, items: { bat: 1, pillow: 1, popper: 1 }, rooms: { box: 1 }, outfits: { peach: 1, yellow: 1 }, equip: { skin: 'peach', shirt: 'yellow', hat: null, face: null, neck: null, back: null }, room: 'box', item: 'bat', cat: 'soft', muted: false, speech: true, vib: true, level: 1, daily: { last: '', streak: 0 }, stats: { hits: 0, earned: 0, spent: 0, time: 0, peas: 0, ko: 0, used: 0, best: 0 }, hints: {} };
}
let save = defaults();
try { const s = JSON.parse(localStorage.getItem(SAVE_KEY) || 'null'); if (s) { const d = defaults(); save = Object.assign(d, s); save.equip = Object.assign(d.equip, s.equip || {}); save.stats = Object.assign(d.stats, s.stats || {}); save.daily = Object.assign(d.daily, s.daily || {}); save.hints = s.hints || {}; } } catch (e) { /* ignore */ }
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
  const shH = $('shelfWrap').offsetHeight || 190; document.documentElement.style.setProperty('--shelfH', shH + 'px'); floorY = (vh - shH - 30) / S;
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
const ROOM_PHYS = { box: { g: 1, fr: 0.9, rest: 0.5, part: 0.45 }, kitchen: { g: 1, fr: 0.9, rest: 0.5, part: 0.45 }, jungle: { g: 1, fr: 1, rest: 0.4, part: 0.4 }, beach: { g: 1, fr: 1.1, rest: 0.1, part: 0.3 }, snow: { g: 0.9, fr: 0.04, rest: 0.25, part: 0.35 }, space: { g: 0.28, fr: 0.5, rest: 0.6, part: 0.55 }, candy: { g: 1, fr: 0.5, rest: 0.75, part: 0.6 }, haunted: { g: 0.95, fr: 0.8, rest: 0.45, part: 0.45 } };
function buildWalls() {
  if (walls) Composite.remove(world, walls);
  const P = ROOM_PHYS[save.room] || ROOM_PHYS.box;
  const o = { isStatic: true, restitution: 0.55, friction: 0.5, label: 'wall' };
  const left = Bodies.rectangle(-60, floorY - 1000, 120, 4000, o), right = Bodies.rectangle(W + 60, floorY - 1000, 120, 4000, o);
  const ceil = Bodies.rectangle(W / 2, -330, W + 600, 160, o);
  const floor = Bodies.rectangle(W / 2, floorY + 100, W + 600, 200, { isStatic: true, restitution: P.rest, friction: P.fr, label: 'ground' });
  walls = Composite.create(); Composite.add(walls, [left, right, ceil, floor]); Composite.add(world, walls);
}
function applyRoomPhysics() {
  const P = ROOM_PHYS[save.room] || ROOM_PHYS.box;
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
  const P = ROOM_PHYS[save.room] || ROOM_PHYS.box;
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
  buddy = { parts, list, cons, comp, mass, muscle: 1, floppy: 0, emo: 'idle', emoT: 0, blink: 0, nextBlink: 2, look: { x: 0, y: 0 }, lookT: 0, decals: [], wet: 0, dizzy: 0, grab: null, grounded: false, idle: 0, flutter: 0, sleepy: false, hp: 100, ko: 0, wounds: [], say: null, aiT: 2, chatT: 8, walkT: 0, walkDir: 1, circT: 0, flat: 0, flatV: 0, zap: 0, cold: 0, glow: 0, costume: 0, t: 0 };
  return buddy;
}
function joint(a, b, w, stiff = 0.92) {
  return Constraint.create({ bodyA: a, bodyB: b, pointA: { x: w.x - a.position.x, y: w.y - a.position.y }, pointB: { x: w.x - b.position.x, y: w.y - b.position.y }, stiffness: stiff, damping: 0.08, length: 0, render: { visible: false } });
}
function respawnBuddy() { for (const p of pointers.values()) { if (p.grabCon) Composite.remove(world, p.grabCon); } buildBuddy(W / 2, floorY - 92); buddy.emo = 'happy'; buddy.emoT = 1.2; lastHp = -1; if (G.state === 'play') updateHud(); }
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
  const mm = m * grabbed; const walkSwing = B.walkT > 0 && B.grounded ? Math.sin(B.t * 11) * 0.5 : 0;
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
    pd(ul, ta + s * 0.1 + s * walkSwing, LEGK[0], LEGK[1], tav, mm * (B.grounded ? 1 : 0.5));
    pd(ll, ul.angle, LEGK[2], LEGK[3], ul.angularVelocity, mm * (B.grounded ? 1 : 0.5));
  }
  if (B.grounded && mm > 0.5) { const gs = engine.gravity.scale * engine.gravity.y; for (const n of ['torso', 'head']) { const bd = P[n].body; bd.force.y -= bd.mass * gs * ASSIST * mm; } }
  // damp the whole body a bit while standing so he settles
  if (B.grounded && m0 > 0.6) for (const p of B.list) { const v = p.body.velocity; if (Math.abs(v.x) < 1.5) Body.setVelocity(p.body, { x: v.x * 0.985, y: v.y }); }
}

// ---------------------------------------------------------------------------------------------- emotes
const EMO_PRI = { idle: 0, sleepy: 0, happy: 1, yum: 1, beg: 1, wow: 2, scared: 2, laugh: 3, dizzy: 4, ko: 5 };
function setEmo(n, dur, force) { const B = buddy; if (B.ko > 0 && n !== 'ko') return; if (!force && B.emoT > 0 && EMO_PRI[n] < EMO_PRI[B.emo]) return; B.emo = n; B.emoT = dur; B.sleepy = false; }

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

// ---------------------------------------------------------------------------------------------- state / cash / damage
const G = { combo: 0, lastFun: -10, t: 0, ses: { hits: 0, best: 0, cash: 0 }, paused: false, state: 'title', item: save.item, shake: 0, zoom: 0, idleT: 0, slow: 1, slowT: 0, flash: 0 };
const recent = {};
const WORDS = { smash: ['Boing!', 'Bonk!', 'Whoa!', 'Oof!'], soft: ['Poof!', 'Hehe!', 'Squish!'], boom: ['Boom!', 'Wheee!', 'Kaboom!'], liquid: ['Splash!', 'Splat!', 'Brr!'], food: ['Splat!', 'Yum?'], animal: ['Hehe!', 'Whee!'], zap: ['Zap!', 'Bzzt!'], wind: ['Wheee!', 'Whoa!'], squish: ['Squish!', 'Pancake!'], tickle: ['Hehehe!', 'Tickles!'], spook: ['Boo!', 'Eep!'], magic: ['Wow!', 'Sparkly!'], slap: ['Thwack!', 'Boing!'] };
const LINES = {
  hit: ['Hey, that tickled!', 'Is that all you got?', 'Ha! I felt nothing!', 'Whoa, careful!', 'Boing boing!', 'Okay, okay!'],
  scared: ['Eek! That is HUGE!', 'Mommy!', 'Nooo, not that one!', 'Please be gentle!'],
  beg: ['Truce? Pleeease?', 'I give up, I give up!', 'Can we just be friends?', 'I surrender! Hugs?'],
  food: ['Yummy!', 'Nom nom nom!', 'More please!', 'You are the best!'],
  yuck: ['Eww, peas!', 'Yuck! ...hmm, not bad.', 'Is this soup?'],
  zap: ['My hair!', 'Bzzzt!', 'Static!'],
  wet: ['Brrr! Cold!', 'I am all wet!', 'Splashy!'],
  squish: ['I am a pancake!', 'Flat Buddy!', 'Mmmf!'],
  idle: ['La la la~', 'Got any snacks?', 'Nice day, huh?', 'Anybody there?', 'Boop!', 'I like this box.'],
  ko: ['x_x', 'See the stars...'], revive: ['I am back!', 'Ta-da! Good as new!'],
  giggle: ['Hehe!', 'Hee hee hee!', 'That is funny!'], spook: ['Boo! Aaah!', 'Spooky!'],
};
function say(kind, force) {
  const B = buddy; if (!save.speech || !B) return; if (B.say && B.say.t < B.say.dur && !force) return;
  const txt = typeof kind === 'string' && LINES[kind] ? pick(LINES[kind]) : kind;
  B.say = { txt, t: 0, dur: 1.8 + txt.length * 0.045 }; voice(txt);
}
function voice(txt) {
  if (!save.speech || save.muted) return; const ac = music.ctx; if (!ac || ac.state !== 'running' || !music.sfxBus) return;
  const n = clamp(Math.round(txt.length / 2.2), 2, 9); let t = ac.currentTime + 0.02; const base = 240 + Math.random() * 50; const q = txt.endsWith('?') ? 1.3 : 1;
  for (let i = 0; i < n; i++) {
    const o = ac.createOscillator(), g = ac.createGain(), f = ac.createBiquadFilter(); o.type = 'sawtooth'; f.type = 'bandpass'; f.frequency.value = 800 + Math.random() * 1000; f.Q.value = 3;
    const fr = base * (0.8 + Math.random() * 0.7) * (i === n - 1 ? q : 1); o.frequency.setValueAtTime(fr, t); o.frequency.linearRampToValueAtTime(fr * (0.85 + Math.random() * 0.4), t + 0.07);
    g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.17, t + 0.012); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.09);
    o.connect(f); f.connect(g); g.connect(music.sfxBus); o.start(t); o.stop(t + 0.11); t += 0.075 + Math.random() * 0.03;
  }
}
function vib(ms) { if (save.vib) { try { navigator.vibrate && navigator.vibrate(ms); } catch (e) { /* ignore */ } } }
function earn(n) {
  save.cash += n; save.stats.earned += n; G.ses.cash += n;
}
function checkLevel() {
  const lv = 1 + Math.floor(Math.sqrt(save.stats.hits / 5));
  if (lv > save.level) {
    save.level = lv; save.gold += 2; save.cash += 100; persist();
    setTimeout(() => { if (G.paused) return; G.paused = true; $('lvTitle').textContent = `Level ${lv}!`; $('lvMsg').textContent = 'Buddy loves playing with you! You got 2 gold and 100 cash.'; $('lvStars').innerHTML = [0, 1, 2].map((i) => `<svg style="--i:${i}" viewBox="0 0 32 32"><path d="M16 3l3.8 8.2 8.9 1-6.6 6 1.9 8.8L16 22.5 8 27l1.9-8.8-6.6-6 8.9-1z" fill="#ffc83a" stroke="#c47d12" stroke-width="2" stroke-linejoin="round"/></svg>`).join(''); show('level', true); sfx('win'); updateHud(); }, 700);
  }
}
// pts = fun/damage points; type = damage type (mixing types raises the cash rate)
function fun(pts, kind, x, y, emo = 'laugh', type = 'smash', it = null) {
  const B = buddy; if (B.ko > 0) return; const now = G.t;
  if (now - G.lastFun < 2.4) G.combo++; else G.combo = 1;
  G.lastFun = now; recent[type] = now; let distinct = 0; for (const k in recent) if (now - recent[k] < 4) distinct++;
  const mult = (1 + 0.1 * Math.min(G.combo, 12)) * (1 + 0.3 * (distinct - 1));
  const food = type === 'food' && it && it.fx === 'feed';
  const cash = Math.max(1, Math.round(pts * mult * (food ? 0.6 : 1)));
  earn(cash); save.stats.hits++; G.ses.hits++; G.ses.best = Math.max(G.ses.best, G.combo); save.stats.best = Math.max(save.stats.best, G.combo);
  if (food) { B.hp = Math.min(100, B.hp + (it.heal || 10)); healWounds(2); } else B.hp -= pts * 0.55 * (type === 'soft' || type === 'tickle' ? 0.5 : 1);
  G.idleT = 0; B.chatT = Math.max(B.chatT, 4);
  floatText(`+$${cash}`, x + rnd(-30, 30), y - 20, '#2fa84f', 26 + Math.min(14, pts * 0.4));
  if (pts >= 8 && !food) floatText(pick(WORDS[type] || WORDS.smash), x, y - 64, pick(['#ff4f94', '#3e9cff', '#ff9f2e', '#9a6bff']), 30 + Math.min(18, G.combo * 1.4));
  if (G.combo > 1 && G.combo % 3 === 0) floatText(`COMBO x${G.combo}`, x, y - 110, '#ffb52e', 26);
  for (let i = 0; i < Math.min(4, 1 + cash / 12); i++) flyers.push({ x0: x + rnd(-20, 20), y0: y + rnd(-20, 20), t: -i * 0.07, tx: 0, ty: 0 });
  setEmo(emo, emo === 'laugh' ? 1.3 : 1.1, true);
  if (!food) { woundHit(x, y, pts); if (pts >= 16) stuffing(x, y); }
  hearts(x, y - 60, pts > 12 ? 2 : 1);
  G.shake = Math.min(18, G.shake + pts * 0.35); G.zoom = Math.min(0.03, G.zoom + pts * 0.0012);
  if (pts >= 12) vib(Math.min(60, pts * 2));
  hideHint(); updateHud(true); music.setIntensity(clamp(0.4 + G.combo * 0.06, 0.4, 1));
  // reaction speech
  if (!food && B.hp < 35 && Math.random() < 0.5) { setEmo('beg', 1.6, true); say('beg'); }
  else if (it && it.scared && Math.random() < 0.8) { setEmo('scared', 1.6, true); say('scared'); }
  else if (food) { setEmo('yum', 1.5, true); say('food'); }
  else if (it && it.say) say(it.say);
  else if (Math.random() < 0.35) say(emo === 'laugh' ? 'giggle' : 'hit');
  checkLevel(); persist();
  if (B.hp <= 0) knockOut();
}
function healWounds(n) { for (let i = 0; i < n && buddy.wounds.length; i++) buddy.wounds.shift(); }
function woundHit(x, y, pts) {
  const B = buddy; if (pts < 6) return; const part = Math.random() < 0.55 ? 'head' : 'torso'; const hd = DIM.headR, tw = DIM.tw, th = DIM.th;
  const lx = part === 'head' ? rnd(-0.6, 0.6) * hd : rnd(-0.3, 0.3) * tw, ly = part === 'head' ? rnd(-0.6, 0.5) * hd : rnd(-0.3, 0.3) * th;
  const hp = B.hp; const kind = hp > 75 ? 'bump' : hp > 50 ? pick(['bump', 'bruise', 'plaster']) : pick(['bruise', 'plaster', 'crack', 'bandage']);
  B.wounds.push({ part, x: lx, y: ly, kind, life: 40 + rnd(0, 15), rot: rnd(-0.6, 0.6), s: rnd(0.8, 1.15) }); if (B.wounds.length > 9) B.wounds.shift();
}
function stuffing(x, y) { for (let i = 0; i < 6; i++) { const a = rnd(0, TAU); P_(PT.puff, x, y, Math.cos(a) * rnd(1, 4), Math.sin(a) * rnd(1, 4) - 2, rnd(0.9, 1.5), rnd(6, 10), '#fffaf0', 0.08, 0.96, 0.1); } }
function knockOut() {
  const B = buddy; B.ko = 5.5; B.hp = 0; B.emo = 'ko'; B.emoT = 99; save.stats.ko++; G.slow = 0.28; G.slowT = 1.1; floppy(6); B.muscle = 0.1;
  say('ko', true); sfx('squeak', { pitch: 0.6 }); vib(120); burstSparks(buddyCenter().x, buddyCenter().y - 70, 20, 8);
  const reward = Math.round(rnd(50, 300) / 10) * 10; G.koReward = reward;
  setTimeout(() => { G.paused = true; $('koAmt').textContent = '+' + reward; $('koDbl').disabled = false; $('koDbl').classList.remove('spin'); $('koTxt').textContent = 'Bonus cash!'; show('ko', true); sfx('win'); }, 1500);
}
function revive() {
  const B = buddy; B.hp = 100; B.ko = 0; B.emo = 'happy'; B.emoT = 2; B.wounds.length = Math.min(B.wounds.length, 3); B.muscle = 0.2; floppy(0.2);
  burstSparks(buddyCenter().x, buddyCenter().y - 60, 24, 9); sfx('powerup'); say('revive', true); updateHud();
}

// ---------------------------------------------------------------------------------------------- world objects
const pads = []; const projs = []; const balloons = []; const puddles = []; const launchers = [{ t: 0, a: 0, col: '#fff' }, { t: 0, a: 0, col: '#fff' }]; const fx = []; const ents = []; const bubbles = [];
const pointers = new Map(); const mouse = { x: 0, y: 0 };

function partsNear(x, y, R) { const out = []; for (const p of buddy.list) { const dx = p.body.position.x - x, dy = p.body.position.y - y, d = Math.hypot(dx, dy); if (d < R + p.rad) out.push({ p, d, dx, dy }); } return out; }
function buddyCenter() { return buddy.parts.torso.body.position; }
function boost(vx, vy) { for (const p of buddy.list) { const v = p.body.velocity; Body.setVelocity(p.body, { x: v.x * 0.5 + vx, y: vy + rnd(-1, 1) }); } buddy.floppy = Math.max(buddy.floppy, 0.5); }
function floppy(t) { buddy.floppy = Math.max(buddy.floppy, t); }
function push(x, y, R, power, up = 0) { let any = false; for (const h of partsNear(x, y, R)) { const d = Math.hypot(h.dx, h.dy) || 1, f = 1 - clamp(h.d / (R + h.p.rad), 0, 1) * 0.7; Body.setVelocity(h.p.body, { x: h.p.body.velocity.x + h.dx / d * power * f, y: h.p.body.velocity.y + h.dy / d * power * f - up * f }); any = true; } if (any) floppy(1); return any; }
function sideOf(x) { return x > W / 2 ? 0 : 1; }

function swingHit(x, y, it) {
  fx.push({ type: it.id, x, y, t: 0, dur: 0.34, dir: x < buddyCenter().x ? 1 : -1 });
  const hits = partsNear(x, y, it.r); sfx('whoosh', { volume: 0.5, pitch: it.big ? 0.7 : 1 });
  if (!hits.length) return;
  const side = x < buddyCenter().x ? 1 : -1;
  for (const h of hits) {
    const d = Math.hypot(h.dx, h.dy) || 1, fall = 1 - clamp(h.d / (h.p.rad + it.r), 0, 1) * 0.55;
    const dx = 0.6 * side + 0.4 * h.dx / d, dy = -0.45 + 0.4 * h.dy / d, l = Math.hypot(dx, dy) || 1;
    Body.setVelocity(h.p.body, { x: h.p.body.velocity.x * 0.3 + dx / l * it.pw * fall, y: h.p.body.velocity.y * 0.3 + dy / l * it.pw * fall });
    Body.setAngularVelocity(h.p.body, h.p.body.angularVelocity + side * rnd(0.1, 0.35) * fall); h.p.sq = Math.max(h.p.sq, 0.34); h.p.sqa = Math.atan2(dy, dx); h.p.sqv = 0;
  }
  floppy(0.5 + it.pw * 0.05); sfx(it.sfx || 'boing', { pitch: rnd(0.9, 1.3) }); if (it.squeak || it.pw < 12) sfx('squeak', { volume: 0.6 });
  if (it.puff) for (let i = 0; i < 12; i++) P_(PT.puff, x + rnd(-20, 20), y + rnd(-20, 20), rnd(-3, 3), rnd(-3, 1), rnd(0.5, 0.9), rnd(12, 22), 'rgba(255,255,255,0.85)', 0.02, 0.94, 0.6);
  else burstSparks(x, y, 8, 6, ['#fff', '#ffd23f']);
  if (it.suck) { puff(x, y, 5, 'rgba(255,255,255,0.8)', 2, 10); sfx('pop', { pitch: 0.6 }); }
  if (it.type === 'tickle') { sfx('squeak', { volume: 0.5, pitch: 1.4 }); }
  splashRing(x, y);
  if (it.big) { G.shake = Math.max(G.shake, 16); G.slow = 0.5; G.slowT = 0.22; }
  fun(it.pts, 'smash', x, y, it.type === 'tickle' ? 'laugh' : 'wow', it.type, it);
}
function splashRing(x, y) { const p = P_(PT.ring, x, y, 0, 0, 0.4, 10, '#ffffff', 0, 1, 190); p.vr = 0; }

// ---- thrown / launched bodies -----------------------------------------------------------------------------
function spawnBody(spec, sprite, x, y, vx, vy) {
  const gprops = { restitution: spec.rest !== undefined ? spec.rest : 0.35, friction: 0.3, frictionAir: spec.light ? 0.004 : 0.002, density: spec.light ? 0.0005 : 0.0025, label: 'proj' };
  const body = spec.shape === 'r' ? Bodies.rectangle(x, y, spec.w, spec.h, { ...gprops, chamfer: { radius: 5 } }) : Bodies.circle(x, y, spec.r, gprops);
  if (spec.noSpin) { Body.setInertia(body, Infinity); body.friction = 0.002; body.frictionAir = 0.0005; }
  body.plugin = { proj: true }; Body.setVelocity(body, { x: vx, y: vy }); if (!spec.noSpin) Body.setAngularVelocity(body, rnd(-0.2, 0.2));
  Composite.add(world, body);
  const p = { body, spec, sprite: sprite || spec.id, r: spec.r || Math.max(spec.w, spec.h) / 2, born: G.t, fuse: spec.fuse || 0, held: null, hit: false, last: 0 };
  projs.push(p); if (projs.length > 24) killProj(projs[0], true); return p;
}
function killProj(p, pop) { Composite.remove(world, p.body); const i = projs.indexOf(p); if (i >= 0) projs.splice(i, 1); if (pop) puff(p.body.position.x, p.body.position.y, 6, 'rgba(255,255,255,0.9)', 3, 16); }

function startThrow(it, ptr) {
  const n = it.n || 1; ptr.held = [];
  for (let i = 0; i < n; i++) { const p = spawnBody(it, it.id, ptr.x + (i - (n - 1) / 2) * 34, ptr.y + (i % 2) * 14, 0, 0); p.held = ptr; ptr.held.push(p); }
  sfx('pop', { pitch: 1.4, volume: 0.5 }); if (it.peas) save.stats.peas++;
}
function releaseThrow(ptr) {
  if (!ptr.held) return;
  const h = ptr.hist; let vx = 0, vy = 0;
  if (h.length > 1) { const a = h[0], b = h[h.length - 1], dt = Math.max(16, b.t - a.t) / 16.67; vx = (b.x - a.x) / dt; vy = (b.y - a.y) / dt; }
  let sp = Math.hypot(vx, vy); const k = sp > 3 ? 1.5 : 1; vx *= k; vy *= k; sp = Math.hypot(vx, vy); if (sp > 36) { vx *= 36 / sp; vy *= 36 / sp; }
  for (const p of ptr.held) { p.held = null; Body.setVelocity(p.body, { x: vx + rnd(-1, 1), y: vy + rnd(-1, 1) }); }
  if (sp > 6) sfx('whoosh', { volume: clamp(sp / 30, 0.2, 0.6) });
  ptr.held = null; ptr.hist = [];
}
function fireAim(it, tx, ty) {
  const side = sideOf(tx); const L = launchers[side]; const px = side === 0 ? 70 : W - 70, py = floorY - 40; const a = Math.atan2(ty - py, tx - px);
  L.t = 1.2; L.a = a; L.col = ({ poppergun: '#ff8fbe', rocket: '#ff5d6c', waterpistol: '#3ea8ff', cupcakecannon: '#4fd0a0' })[it.id] || '#ffb52e'; L.rec = 1; L.side = side; L.px = px; L.py = py;
  const mx = px + Math.cos(a) * 70, my = py + Math.sin(a) * 70; puff(mx, my, 5, 'rgba(255,255,255,0.8)', 3, 10);
  const proj = it.proj;
  if (proj === 'confetti') {
    sfx('pop', { pitch: 1.1 }); burstConfetti(mx, my, 40, 20, a, 0.5);
    const dx = Math.cos(a), dy = Math.sin(a); let hit = false;
    for (const p of buddy.list) { const rx = p.body.position.x - mx, ry = p.body.position.y - my, along = rx * dx + ry * dy, perp = Math.abs(rx * dy - ry * dx); if (along > 0 && along < 900 && perp < 70 + along * 0.1) { Body.setVelocity(p.body, { x: p.body.velocity.x + dx * 6, y: p.body.velocity.y + dy * 6 - 1 }); hit = true; } }
    if (hit) { floppy(0.6); sfx('sparkle', { volume: 0.7 }); fun(9, 'smash', tx, ty, 'laugh', 'boom', it); burstConfetti(buddyCenter().x, buddyCenter().y - 40, 24, 8); }
    return;
  }
  const spec = { rocket: { id: 'rocket', r: 11, fx: 'bomb', fuse: 1.4, contact: 1, burst: 'sparks', blast: 160, push: 12, pts: 20, type: 'boom', trail: 1, rest: 0.1 }, water: { id: 'water', r: 8, fx: 'water', pts: 4, type: 'liquid', small: 1 }, cupcake: { ...ITEM.cupcake, r: 15 } }[proj];
  sfx(proj === 'rocket' ? 'whoosh' : 'shoot', { pitch: proj === 'rocket' ? 1 : 1.3, volume: 0.7 });
  const g = 0.2778 * engine.gravity.scale / 0.001; const dist = Math.hypot(tx - mx, ty - my); const T = clamp(dist / (proj === 'rocket' ? 24 : 18), 16, 50);
  spawnBody(spec, spec.id, mx, my, (tx - mx) / T, (ty - my - 0.5 * g * T * T) / T);
}
function explode(p) {
  const s = p.spec, pos = p.body.position, x = pos.x, y = pos.y; killProj(p, false);
  if (s.burst === 'confetti') { burstConfetti(x, y, 70, 14); burstSparks(x, y, 14, 9); sfx('pop', { pitch: 0.7 }); sfx('boom', { volume: 0.5 }); }
  else if (s.burst === 'sparks') { burstSparks(x, y, 44, 14, ['#ff5d8f', '#ffd23f', '#3ec6ff', '#58d68d', '#fff']); burstConfetti(x, y, 24, 10); sfx('boom', { volume: 0.6 }); sfx('sparkle'); }
  else { glitterBurst(x, y, true); burstConfetti(x, y, 140, 24); G.flash = 0.8; G.slow = 0.35; G.slowT = 0.5; sfx('boom'); }
  puff(x, y, 8, 'rgba(255,240,255,0.8)', 5, 26); splashRing(x, y); G.shake = Math.max(G.shake, s.big ? 22 : 11);
  const near = push(x, y, s.blast, s.push, 3);
  if (near) { vib(80); fun(s.pts, 'smash', x, y - 30, 'wow', 'boom', s); }
}
function projTouch(p, partName, rv) {
  const s = p.spec, pos = p.body.position; if (p.held && rv < 2) return;
  if (s.fx === 'bomb') { if (s.contact && !p.hit) { p.hit = true; explode(p); } return; }
  if (s.fx === 'bounce') {
    if (G.t - p.last < 0.35 || rv < 3) return; p.last = G.t; sfx(s.squeak ? 'squeak' : 'boing', { pitch: rnd(0.9, 1.4), volume: 0.7 }); fun(s.pts, 'smash', pos.x, pos.y - 20, 'laugh', s.type, s); floppy(0.6);
    if (s.boo) { floatText('BOO!', pos.x, pos.y - 70, '#ff9f43', 36); say('spook'); }
    return;
  }
  if (p.hit || rv < 2.5) return; p.hit = true; const part = buddy.list.find((q) => q.name === partName);
  if (s.fx === 'water') { splash(pos.x, pos.y, 34, '#6fcfff', 10); splash(pos.x, pos.y, 12, '#fff', 6); sfx('splash'); sfx('squeak', { volume: 0.6 }); buddy.wet = 4; if (!s.small) say('wet'); fun(s.pts, 'smash', pos.x, pos.y, 'wow', 'liquid', s); }
  else if (s.fx === 'splat') {
    const cols = s.rainbow ? pick([['#b57bff', '#e0c8ff'], ['#ff5d8f', '#ffc4d8'], ['#3ec6ff', '#c4ecff'], ['#ffd23f', '#fff0a0']]) : s.cols; addDecal(part, pos, cols, 'ice');
    for (let i = 0; i < 14; i++) P_(PT.dot, pos.x, pos.y, rnd(-5, 5), rnd(-6, 1), rnd(0.5, 1), rnd(3, 6), pick(cols), 0.3, 0.97); sfx('splash', { volume: 0.7 }); sfx('squeak', { volume: 0.7, pitch: 1.2 }); if (s.floppy) floppy(1.2);
    fun(s.pts, 'smash', pos.x, pos.y, s.say === 'yuck' ? 'scared' : 'wow', s.type, s); if (s.say === 'yuck') say('yuck');
  } else if (s.fx === 'feed') {
    for (let i = 0; i < 14; i++) P_(PT.dot, pos.x, pos.y, rnd(-4, 4), rnd(-5, 1), rnd(0.5, 1), rnd(2.5, 5), pick(s.crumbs), 0.25, 0.97); sfx('pop', { pitch: 1.5 }); sfx('squeak', { pitch: 1.3, volume: 0.7 }); burstSparks(pos.x, pos.y - 30, 8, 5);
    fun(s.pts, 'smash', pos.x, pos.y, 'yum', 'food', s);
  }
  killProj(p, false);
}
function projGround(p) {
  const s = p.spec, pos = p.body.position; if (p.hit) return;
  if (s.fx === 'water') { p.hit = true; splash(pos.x, pos.y, 22, '#6fcfff', 8); sfx('splash', { volume: 0.6 }); if (!s.small) puddles.push({ x: pos.x, t: 0 }); if (puddles.length > 6) puddles.shift(); killProj(p, false); }
  else if (s.fx === 'splat' || s.fx === 'feed') { p.hit = true; puff(pos.x, pos.y, 8, s.cols ? s.cols[1] : '#ffc4e0', 3, 14); sfx('pop', { volume: 0.5 }); killProj(p, false); }
  else if (s.fx === 'bomb' && s.contact) { p.hit = true; explode(p); }
}
function glitterBurst(x, y, ground) {
  burstSparks(x, y, 40, 14, ['#fff', '#ffd23f', '#ff9ee0', '#9be6ff', '#c9a6ff']);
  for (let i = 0; i < 70; i++) { const a = rnd(0, TAU), s = rnd(2, 12); P_(PT.glit, x, y, Math.cos(a) * s, Math.sin(a) * s - 2, rnd(1.2, 2.2), rnd(2, 4.5), pick(['#fff', '#ffd23f', '#ff9ee0', '#9be6ff']), 0.1, 0.95); }
  puff(x, y, 8, 'rgba(255,200,255,0.8)', 4, 24); sfx('sparkle');
}
function addDecal(part, pos, cols, kind) {
  const b = (part || buddy.parts.head).body; const ang = b.angle; const dx = pos.x - b.position.x, dy = pos.y - b.position.y;
  const lx = dx * Math.cos(-ang) - dy * Math.sin(-ang), ly = dx * Math.sin(-ang) + dy * Math.cos(-ang);
  buddy.decals.push({ part: part && part.name === 'torso' ? 'torso' : 'head', x: lx * 0.7, y: ly * 0.7, r: rnd(12, 18) * K * 1.4, cols, kind, life: 7, rot: rnd(0, TAU) });
  if (buddy.decals.length > 8) buddy.decals.shift();
}

// ---- pads -------------------------------------------------------------------------------------------------
function placePad(kind, x, dir = 1) {
  const same = pads.filter((p) => p.kind === kind); if (same.length >= 2) removePad(same[0]);
  x = clamp(x, 90, W - 90); let body, y;
  if (kind === 'tramp') { y = floorY - 30 - 11; body = Bodies.rectangle(x, y, 190 * K + 30, 22, { isStatic: true, restitution: 1.0, friction: 0.2, chamfer: { radius: 10 }, label: 'pad' }); }
  else if (kind === 'spring') { y = floorY - 38; body = Bodies.rectangle(x, y, 70, 60, { isStatic: true, restitution: 0.6, friction: 0.2, chamfer: { radius: 10 }, label: 'pad' }); }
  else { y = floorY - 76 * K; body = Bodies.circle(x, y, 52 * K, { isStatic: true, restitution: 1.0, friction: 0.2, label: 'pad' }); }
  body.plugin = { pad: kind }; Composite.add(world, body);
  const pad = { kind, body, x, y, born: G.t, life: 14, sq: 0, sqv: 0, dir }; pads.push(pad);
  sfx('pop', { pitch: 1.3 }); sfx('boing', { pitch: 1.4, volume: 0.5 }); burstSparks(x, floorY - 40, 10, 5, ['#fff', '#7ad8ff', '#ffd23f']);
  const c = buddyCenter(); if (Math.abs(c.x - x) < 110 && c.y > floorY - 260) { padHit(body, 6); pad.sq = 0.5; }
  return pad;
}
function removePad(p) { Composite.remove(world, p.body); const i = pads.indexOf(p); if (i >= 0) pads.splice(i, 1); puff(p.x, p.y, 10, 'rgba(255,255,255,0.9)', 4, 16); burstSparks(p.x, p.y, 8, 5); }
function padHit(padBody, rv) {
  const pad = pads.find((p) => p.body === padBody); if (!pad) return; const c = buddyCenter(); const kind = pad.kind;
  if (G.t - (pad.lastHit || 0) < 0.25) return; pad.lastHit = G.t; pad.sq = 0.6;
  const spring = kind === 'spring'; const vy = spring ? -30 : kind === 'tramp' ? -(Math.max(13, rv * 0.9 + 9)) : -(Math.max(15, rv * 0.9 + 11));
  const vx = spring ? pad.dir * 10 : kind === 'tramp' ? 0 : clamp((c.x - pad.x) * 0.12, -6, 6);
  boost(vx, Math.max(vy, -32)); sfx('boing', { pitch: spring ? 0.8 : kind === 'tramp' ? 1.0 : 1.3, volume: 0.9 }); sfx('squeak', { volume: 0.5 }); setEmo('wow', 0.8, true);
  burstSparks(pad.x, pad.y - 20, 12, 7, ['#fff', '#7ad8ff']); splashRing(pad.x, pad.y - 10);
  fun(spring ? 20 : 16, 'smash', c.x, c.y - 30, 'wow', 'launch', ITEM[kind]); G.shake = Math.max(G.shake, 7);
}

// ---- balloons ---------------------------------------------------------------------------------------------
function addBalloons(x, y) {
  const B = buddy; if (balloons.length >= 9) return; const cols = ['#ff5d8f', '#ffd23f', '#3ec6ff', '#58d68d', '#b57bff', '#ff9f43'];
  for (let i = 0; i < 3 && balloons.length < 9; i++) {
    const anchor = B.parts[i % 2 ? 'lAL' : 'lAR'].body; const bx = anchor.position.x + rnd(-30, 30), by = anchor.position.y - 70 - i * 10;
    const body = Bodies.circle(bx, by, 26 * K, { frictionAir: 0.045, restitution: 0.6, density: 0.0004, collisionFilter: { group: -1 }, label: 'balloon' }); body.plugin = { balloon: true };
    const con = Constraint.create({ bodyA: anchor, bodyB: body, pointA: { x: 0, y: DIM.ajl / 2 }, pointB: { x: 0, y: 24 * K }, length: 70 + i * 26 + rnd(0, 20), stiffness: 0.03, damping: 0.05 });
    Composite.add(world, [body, con]); balloons.push({ body, con, col: cols[(balloons.length + i) % 6], born: G.t });
  }
  sfx('powerup', { volume: 0.5 }); sfx('squeak', { volume: 0.6 }); burstSparks(x, y, 8, 4); fun(8, 'soft', buddyCenter().x, buddyCenter().y - 60, 'happy', 'soft', ITEM.balloons);
}
function popBalloon(b) {
  const p = b.body.position; Composite.remove(world, [b.body, b.con]); const i = balloons.indexOf(b); if (i >= 0) balloons.splice(i, 1);
  burstConfetti(p.x, p.y, 22, 8); puff(p.x, p.y, 6, b.col, 4, 14); sfx('pop', { pitch: rnd(0.9, 1.4) }); sfx('squeak', { volume: 0.4, pitch: 1.4 }); fun(7, 'boom', p.x, p.y, 'wow', 'boom', null);
}
function balloonForces() { if (!balloons.length) return; const gs = engine.gravity.scale * engine.gravity.y; const lift = buddy.mass * gs * 0.2; for (const b of balloons) { b.body.force.y -= lift + b.body.mass * gs * 1.1; b.body.force.x += Math.sin(G.t * 1.3 + b.born) * b.body.mass * 0.00002; } }

// ---- scripted entities (animals, magic, machines) ---------------------------------------------------------
function addEnt(e) { e.t = 0; ents.push(e); return e; }
function useTap(it, x, y) {
  const B = buddy, c = buddyCenter();
  switch (it.id) {
    case 'popper': {
      burstConfetti(x, y, 60, 15); burstSparks(x, y, 10, 8); sfx('pop', { pitch: 1.2 }); sfx('sparkle', { volume: 0.5 }); splashRing(x, y);
      if (push(x, y, 130, 7, 3)) fun(9, 'boom', x, y, 'laugh', 'boom', it); break; }
    case 'balloons': { const b = balloons.find((q) => Math.hypot(q.body.position.x - x, q.body.position.y - y) < 50); if (b) popBalloon(b); else addBalloons(x, y); break; }
    case 'icebucket': addEnt({ k: 'bucket', x: c.x, life: 1.6 }); sfx('whoosh', { pitch: 0.8 }); break;
    case 'vice': addEnt({ k: 'vice', life: 2.2, cx: c.x }); sfx('whoosh', { pitch: 0.5 }); break;
    case 'butterflies': addEnt({ k: 'butter', life: 7 }); sfx('sparkle'); say('giggle'); break;
    case 'bees': addEnt({ k: 'bees', life: 6 }); sfx('squeak', { pitch: 1.6 }); setEmo('laugh', 5, true); B.circT = 6; say('Bzzz! Hehehe!', true); break;
    case 'penguin': addEnt({ k: 'penguins', life: 1.2, side: sideOf(c.x), n: 0 }); break;
    case 'dino': addEnt({ k: 'stomp', x: clamp(x, 120, W - 120), life: 1.4 }); sfx('whoosh', { pitch: 0.4 }); break;
    case 'raincloud': addEnt({ k: 'cloud', x: clamp(x, 100, W - 100), life: 7 }); sfx('whoosh', { pitch: 0.7 }); break;
    case 'lightning': { const ex = clamp(x, 60, W - 60); addEnt({ k: 'bolt', x: ex, y: Math.min(y, floorY), life: 0.5 }); G.flash = 0.9; G.shake = 16; sfx('boom', { volume: 0.6 }); sfx('laser', { pitch: 0.6 });
      if (Math.hypot(c.x - ex, c.y - y) < 190 || Math.abs(c.x - ex) < 90) { B.zap = 1.6; floppy(1.2); setEmo('wow', 1.6, true); boost(0, -9); for (let i = 0; i < 24; i++) P_(PT.star, c.x + rnd(-40, 40), c.y + rnd(-110, 40), rnd(-4, 4), rnd(-4, 4), 0.6, rnd(6, 12), pick(['#ffd23f', '#fff', '#9be6ff']), 0, 0.92); say('zap'); fun(20, 'smash', c.x, c.y - 60, 'wow', 'zap', it); vib(100); } break; }
    case 'tornado': addEnt({ k: 'tornado', x: clamp(x, 140, W - 140), life: 5.5 }); sfx('whoosh', { pitch: 0.4 }); break;
    case 'hand': addEnt({ k: 'hand', dir: sideOf(c.x) === 0 ? 1 : -1, life: 1.1, done: false }); sfx('whoosh', { pitch: 0.5 }); break;
    case 'meteor': for (let i = 0; i < 5; i++) setTimeout(() => { if (G.state !== 'play') return; const s = { id: 'meteor', r: 20, rest: 0.55, fx: 'bounce', pts: 11, type: 'boom', life: 9, light: 1 }; const sx = clamp(c.x + rnd(-260, 260), 60, W - 60); const p = spawnBody(s, 'meteor', sx, -80, (c.x - sx) * 0.01, 14 + rnd(0, 4)); p.noRot = 1; sfx('whoosh', { pitch: rnd(0.6, 1) }); }, i * 220); break;
    case 'ghost': addEnt({ k: 'ghosts', life: 5 }); sfx('squeak', { pitch: 0.5 }); floatText('BOO!', c.x, c.y - 150, '#b57bff', 44); break;
    case 'skeleton': B.costume = 12; sfx('squeak', { pitch: 0.7 }); sfx('sparkle'); burstSparks(c.x, c.y, 16, 7, ['#fff', '#cfd8ff']); say('Boo! I am a skeleton!', true); fun(8, 'smash', c.x, c.y - 60, 'laugh', 'spook', it); break;
    default: break;
  }
}
function useItem(it, x, y) {
  switch (it.mode) { case 'tap': useTap(it, x, y); break; case 'place': if (it.id === 'conveyor') { addEnt({ k: 'conveyor', x: clamp(x, 160, W - 160), life: 12, dir: x < buddyCenter().x ? 1 : -1 }); sfx('pop', { pitch: 0.9 }); } else placePad(it.id, x, x < buddyCenter().x ? 1 : -1); break; default: break; }
}
function updateEnts(dt) {
  const B = buddy, c = buddyCenter();
  for (let i = ents.length - 1; i >= 0; i--) {
    const e = ents[i]; e.t += dt; if (e.t > e.life) { ents.splice(i, 1); if (e.k === 'vice') B.flat = B.flat; continue; }
    switch (e.k) {
      case 'cloud': e.x += (c.x - e.x) * dt * 0.4; if (Math.random() < 0.9) P_(PT.streak, e.x + rnd(-80, 80), floorY - 420 + rnd(0, 20), 0, 11, 0.5, 16, 'rgba(120,190,255,0.9)', 0.1, 1);
        if (Math.abs(c.x - e.x) < 110) { B.wet = 1.5; e.f = (e.f || 0) - dt; if (e.f <= 0) { e.f = 0.8; fun(4, 'smash', c.x, c.y - 60, 'wow', 'liquid', null); if (Math.random() < 0.4) say('wet'); } } break;
      case 'tornado': e.x += Math.sin(e.t * 1.3) * 60 * dt; for (const p of B.list) { const dx = e.x - p.body.position.x; const v = p.body.velocity; Body.setVelocity(p.body, { x: v.x + clamp(dx * 0.004, -0.5, 0.5), y: v.y - (p.body.position.y > floorY - 380 ? 0.34 : 0) }); }
        if (Math.abs(c.x - e.x) < 200) { Body.setAngularVelocity(B.parts.torso.body, B.parts.torso.body.angularVelocity + 0.03); floppy(0.6); e.f = (e.f || 0) - dt; if (e.f <= 0) { e.f = 0.6; fun(6, 'smash', c.x, c.y - 60, 'laugh', 'wind', null); } }
        if (Math.random() < 0.6) P_(PT.dot, e.x + rnd(-60, 60), floorY - rnd(0, 360), 0, 0, 0.4, rnd(2, 4), '#dfe6ff', 0, 1); break;
      case 'hand': if (!e.done && e.t > 0.4) { e.done = true; const d = e.dir; for (const p of B.list) Body.setVelocity(p.body, { x: d * 24 + rnd(-2, 2), y: -10 + rnd(-2, 2) }); floppy(1.5); G.shake = 20; G.slow = 0.4; G.slowT = 0.25; sfx('boom', { volume: 0.7 }); sfx('squeak', { pitch: 0.7 }); splashRing(c.x, c.y); burstSparks(c.x, c.y, 16, 9); fun(26, 'smash', c.x, c.y - 40, 'wow', 'smash', ITEM.hand); } break;
      case 'stomp': if (!e.done && e.t > 0.4) { e.done = true; G.shake = 20; sfx('boom'); puff(e.x, floorY, 12, 'rgba(230,210,190,0.9)', 6, 26); splashRing(e.x, floorY); if (push(e.x, floorY - 40, 360, 6, 16)) { fun(24, 'smash', c.x, c.y - 40, 'wow', 'smash', ITEM.dino); } } break;
      case 'bolt': break;
      case 'bucket': if (!e.done && e.t > 0.7) { e.done = true; const x = c.x, y = c.y - 140; splash(x, y + 40, 40, '#9be6ff', 8); for (let k = 0; k < 14; k++) P_(PT.conf, x + rnd(-30, 30), y, rnd(-3, 3), rnd(0, 3), 1.4, rnd(8, 12), '#e8fbff', 0.3, 0.98); B.wet = 5; B.cold = 4; setEmo('scared', 2, true); say('wet'); sfx('splash'); fun(14, 'smash', x, y + 60, 'wow', 'liquid', null); } break;
      case 'conveyor': for (const p of B.list) { const px = p.body.position; if (Math.abs(px.x - e.x) < 150 && px.y > floorY - 70) { Body.setVelocity(p.body, { x: clamp(p.body.velocity.x + e.dir * 0.4, -5, 5), y: p.body.velocity.y }); } }
        e.f = (e.f || 0) - dt; if (Math.abs(c.x - e.x) < 150 && c.y > floorY - 140 && e.f <= 0) { e.f = 1.0; fun(4, 'smash', c.x, c.y - 60, 'laugh', 'launch', null); } break;
      case 'vice': {
        const k = e.t < 0.8 ? e.t / 0.8 : e.t < 1.3 ? 1 : Math.max(0, 1 - (e.t - 1.3) / 0.35); e.k2 = k; const half = lerp(W * 0.5, 50, easeOut(k));
        if (k > 0.05 && !e.snd) { e.snd = 1; sfx('squeak', { pitch: 0.6 }); }
        const target = k > 0.6 ? 1 : 0; B.flat += (Math.min(1, k * 1.2) - B.flat) * 0.25;
        if (k > 0.3) for (const p of B.list) { Body.setVelocity(p.body, { x: (e.cx - p.body.position.x) * 0.15, y: p.body.velocity.y }); }
        if (e.t > 1.0 && !e.hit) { e.hit = true; G.shake = 14; sfx('boom', { volume: 0.5 }); say('squish'); setEmo('wow', 2, true); fun(25, 'smash', c.x, c.y - 30, 'wow', 'squish', ITEM.vice); }
        if (e.t > 1.4 && !e.pop) { e.pop = true; B.flatV = 0.5; boost(0, -12); sfx('boing', { pitch: 1.2 }); burstSparks(c.x, c.y, 14, 8); }
        break; }
      case 'bees': { if (Math.random() < 0.06) sfx('squeak', { volume: 0.3, pitch: rnd(1.4, 2) }); e.f = (e.f || 0) - dt; if (e.f <= 0) { e.f = 0.9; fun(4, 'smash', c.x, c.y - 60, 'laugh', 'animal', null); } break; }
      case 'butter': { e.f = (e.f || 0) - dt; if (e.f <= 0) { e.f = 1.1; B.hp = Math.min(100, B.hp + 2); setEmo('happy', 1.2, true); hearts(c.x, c.y - 60, 2); fun(3, 'soft', c.x, c.y - 60, 'happy', 'animal', null); } break; }
      case 'penguins': { if (e.n < 3 && e.t > e.n * 0.3) { e.n++; const dir = e.side === 0 ? -1 : 1; const x = e.side === 0 ? W - 40 : 40; const p = spawnBody({ id: 'penguin', r: 21, rest: 0.4, noSpin: true, fx: 'bounce', pts: 12, type: 'animal', life: 7 }, 'penguin', x, floorY - 26, -dir * 0 + (e.side === 0 ? -1 : 1) * rnd(10, 13), 0); p.noRot = 1; sfx('squeak', { pitch: 1.5 }); } break; }
      case 'ghosts': { if (!e.boo && e.t > 0.5) { e.boo = true; setEmo('scared', 2.5, true); say('spook'); boost(rnd(-3, 3), -8); fun(8, 'smash', c.x, c.y - 70, 'wow', 'spook', null); sfx('squeak', { pitch: 0.5 }); } break; }
      default: break;
    }
  }
}
function drawEnts(c) {
  const B = buddy, bc = buddyCenter();
  for (const e of ents) {
    const k = e.t / e.life; c.save();
    switch (e.k) {
      case 'cloud': c.translate(e.x, floorY - 440); c.globalAlpha = Math.min(1, e.t * 3, (e.life - e.t) * 2); c.scale(2.4, 2.4); drawItem(c, 'raincloud'); break;
      case 'tornado': { c.globalAlpha = Math.min(1, e.t * 3, (e.life - e.t) * 2); c.translate(e.x, floorY); for (let i = 0; i < 9; i++) { const f = i / 8, w = 28 + f * 120, y = -f * 380; c.fillStyle = `rgba(${160 + f * 40},${175 + f * 30},${215 + f * 20},0.75)`; c.beginPath(); c.ellipse(Math.sin(e.t * 6 + i) * 10, y, w, 18, 0, 0, TAU); c.fill(); c.strokeStyle = 'rgba(255,255,255,0.45)'; c.lineWidth = 3; c.stroke(); } break; }
      case 'hand': { const t = e.t, d = e.dir; const x0 = d > 0 ? -160 : W + 160; const px = t < 0.4 ? lerp(x0, bc.x - d * 70, easeOut(t / 0.4)) : lerp(bc.x - d * 70, bc.x + d * 120, clamp((t - 0.4) / 0.3, 0, 1)); const alpha = t > 0.75 ? clamp((1.1 - t) / 0.35, 0, 1) : 1; c.globalAlpha = alpha; c.translate(px, bc.y - 10); c.rotate(d * (t < 0.4 ? 0.2 : 0.2 - (t - 0.4) * 2)); c.scale(-d * 3, 3); drawItem(c, 'hand'); break; }
      case 'stomp': { const t = e.t; const y = t < 0.4 ? lerp(-260, floorY, (t / 0.4) * (t / 0.4)) : t < 0.9 ? floorY : lerp(floorY, -260, (t - 0.9) / 0.5); c.translate(e.x, y); c.fillStyle = '#5cc85a'; c.fillRect(-26, -520, 52, 520); c.strokeStyle = '#2f8f3a'; c.lineWidth = 5; c.strokeRect(-26, -520, 52, 520); c.beginPath(); c.ellipse(0, -8, 78, 40, 0, 0, TAU); c.fillStyle = '#6fd86a'; c.fill(); c.stroke(); for (const x of [-46, 0, 46]) { c.beginPath(); c.ellipse(x, 20, 20, 14, 0, 0, TAU); c.fillStyle = '#fff6d8'; c.fill(); c.stroke(); } break; }
      case 'bolt': { const a = 1 - e.t / e.life; c.strokeStyle = `rgba(255,255,255,${a})`; c.shadowColor = '#ffe27a'; c.shadowBlur = 24; c.lineWidth = 12; c.lineJoin = 'round'; c.beginPath(); let x = e.x, y = -20; c.moveTo(x, y); const seed = Math.floor(e.t * 30); for (let i = 0; i < 9; i++) { x += Math.sin(i * 3.1 + seed) * 40; y += (e.y + 20) / 9; c.lineTo(x, y); } c.stroke(); c.strokeStyle = `rgba(255,226,90,${a})`; c.lineWidth = 5; c.stroke(); break; }
      case 'bucket': { const t = e.t; const rot = t < 0.7 ? easeOut(t / 0.7) * 2.1 : 2.1; c.translate(bc.x, bc.y - 170); c.rotate(rot * (bc.x < W / 2 ? -1 : 1)); c.scale(1.7, 1.7); c.globalAlpha = clamp((e.life - t) * 3, 0, 1); drawItem(c, 'icebucket'); break; }
      case 'conveyor': { c.translate(e.x, floorY); const w = 300, off = (e.t * 60 * e.dir) % 40; c.fillStyle = 'rgba(60,20,80,0.2)'; c.beginPath(); c.ellipse(0, 8, w / 2 + 10, 8, 0, 0, TAU); c.fill(); rr(c, -w / 2, -18, w, 24, 12); c.fillStyle = '#4a5ae8'; c.fill(); c.strokeStyle = '#2a3ab8'; c.lineWidth = 3.5; c.stroke(); c.save(); rr(c, -w / 2 + 6, -14, w - 12, 16, 8); c.clip(); c.fillStyle = '#9fb0ff'; for (let x = -w / 2 - 40; x < w / 2 + 40; x += 40) { const xx = x + off; c.beginPath(); c.moveTo(xx, -12); c.lineTo(xx + 10 * e.dir, -5); c.lineTo(xx, 2); c.lineTo(xx + 4 * e.dir, -5); c.fill(); } c.restore(); for (const x of [-w / 2 + 4, w / 2 - 4]) { c.beginPath(); c.arc(x, -6, 14, 0, TAU); c.fillStyle = '#ffd23f'; c.fill(); c.strokeStyle = '#c9961f'; c.stroke(); } break; }
      case 'vice': { const k2 = e.k2 || 0; const half = lerp(W * 0.55, 46, easeOut(k2)); for (const s of [-1, 1]) { c.save(); c.translate(e.cx + s * (half + 10), floorY - 140); c.scale(s * 1.4, 1.4); rr(c, -34, -150, 40, 330, 12); c.fillStyle = lg(c, -34, 0, 6, 0, '#ffa24d', '#ff8a3d'); c.fill(); c.strokeStyle = '#b8561a'; c.lineWidth = 4; c.stroke(); c.fillStyle = '#ffd23f'; for (let y = -120; y < 160; y += 50) { c.beginPath(); c.arc(-14, y, 6, 0, TAU); c.fill(); } c.restore(); } break; }
      case 'bees': { for (let i = 0; i < 8; i++) { const a = e.t * 5 + i * 0.8, r = 70 + Math.sin(e.t * 3 + i) * 26; c.save(); c.translate(bc.x + Math.cos(a) * r, bc.y - 40 + Math.sin(a * 1.3) * r * 0.8); c.scale(0.5 * (Math.cos(a) > 0 ? 1 : -1), 0.5); drawItem(c, '_bee'); c.restore(); } break; }
      case 'butter': { for (let i = 0; i < 6; i++) { const a = e.t * 1.4 + i * 1.05, r = 90 + Math.sin(e.t * 2 + i) * 30; c.save(); c.translate(bc.x + Math.cos(a) * r, bc.y - 60 + Math.sin(a * 1.7) * 70); c.scale(0.45 * (0.6 + 0.4 * Math.abs(Math.sin(e.t * 12 + i))), 0.45); c.globalAlpha = clamp((e.life - e.t) * 2, 0, 1); drawItem(c, 'butterflies'); c.restore(); } break; }
      case 'ghosts': { for (let i = 0; i < 3; i++) { const a = e.t * 1.6 + i * 2.09, r = 130 - Math.min(1, e.t) * 10; c.save(); c.translate(bc.x + Math.cos(a) * r, bc.y - 70 + Math.sin(a) * 50 + Math.sin(e.t * 4 + i) * 10); c.globalAlpha = 0.85 * clamp(Math.min(e.t * 2, (e.life - e.t) * 2), 0, 1); c.scale(1.0, 1.0); drawItem(c, 'ghost'); c.restore(); } break; }
      default: break;
    }
    c.restore();
  }
}
// ---------------------------------------------------------------------------------------------- collisions
const lastImpact = { t: 0 };
Events.on(engine, 'collisionStart', (ev) => {
  for (const pr of ev.pairs) {
    const A = pr.bodyA, Bd = pr.bodyB; const bp = A.plugin && A.plugin.buddy ? A : (Bd.plugin && Bd.plugin.buddy ? Bd : null);
    const other = bp === A ? Bd : A; const nrm = pr.collision.normal; const rv = Math.hypot(A.velocity.x - Bd.velocity.x, A.velocity.y - Bd.velocity.y);
    if (bp) {
      const part = buddy.list.find((q) => q.body === bp);
      if (part && rv > 2.5) { part.sq = Math.max(part.sq, Math.min(0.4, rv * 0.03)); part.sqa = Math.atan2(nrm.y, nrm.x); part.sqv = 0; }
      if (rv > 7 && G.t - lastImpact.t > 0.16) { lastImpact.t = G.t; const st = other.isStatic; sfx(st ? 'boing' : 'squeak', { volume: clamp(rv / 22, 0.25, 0.8), pitch: rnd(0.8, 1.4) }); if (st && rv > 11) { puff(bp.position.x, Math.min(bp.position.y + 20, floorY), 4, 'rgba(255,255,255,0.7)', 2, 12); G.shake = Math.max(G.shake, rv * 0.35); if (other.label === 'ground' && rv > 14 && G.t - G.lastFun > 0.8) fun(5 + Math.min(10, rv * 0.3), 'smash', buddyCenter().x, buddyCenter().y - 40, 'happy', 'launch', null); } }
      if (other.plugin && other.plugin.pad) padHit(other, rv);
      if (other.plugin && other.plugin.proj) { const p = projs.find((q) => q.body === other); if (p) projTouch(p, bp.plugin.buddy, rv); }
    } else if (A.plugin && A.plugin.proj !== undefined || Bd.plugin && Bd.plugin.proj !== undefined) {
      const o = A.plugin && A.plugin.proj ? A : Bd, ot = A === o ? Bd : A;
      if (ot.isStatic && (ot.label === 'ground' || ot.label === 'wall')) { const p = projs.find((q) => q.body === o); if (p) { projGround(p); if (p.spec.fx === 'bounce' && p.spec.squeak && rv > 4) sfx('squeak', { volume: 0.4, pitch: rnd(1, 1.5) }); } }
    }
  }
});

// ---------------------------------------------------------------------------------------------- input
function worldPos(e) { return { x: e.clientX / S, y: e.clientY / S }; }
let fanPtr = null, hoseDir = null;
function onDown(e) {
  if (G.state !== 'play' || G.paused) return;
  try { cv.setPointerCapture(e.pointerId); } catch (err) { /* ignore */ }
  music.unlock(); const w = worldPos(e);
  const ptr = { id: e.pointerId, x: w.x, y: w.y, vx: 0, vy: 0, down: true, hitT: 0, tick: 0, held: null, hist: [{ x: w.x, y: w.y, t: performance.now() }] };
  pointers.set(e.pointerId, ptr); G.idleT = 0; hideHint(); save.stats.used++;
  const it = ITEM[G.item]; if (!it) return;
  switch (it.mode) {
    case 'melee': swingHit(w.x, w.y, it); break;
    case 'throw': startThrow(it, ptr); break;
    case 'aim': fireAim(it, w.x, w.y); break;
    case 'tap': case 'place': useItem(it, w.x, w.y); break;
    case 'hold': sfx(it.id === 'hose' ? 'splash' : 'whoosh', { volume: 0.4 }); break;
    default: break;
  }
}
function onMove(e) {
  const w = worldPos(e); mouse.x = w.x; mouse.y = w.y; const ptr = pointers.get(e.pointerId); if (!ptr) return;
  ptr.vx = w.x - ptr.x; ptr.vy = w.y - ptr.y; ptr.x = w.x; ptr.y = w.y;
  const now = performance.now(); ptr.hist.push({ x: w.x, y: w.y, t: now }); while (ptr.hist.length > 2 && now - ptr.hist[0].t > 90) ptr.hist.shift();
  const it = ITEM[G.item];
  if (it && it.mode === 'melee' && Math.hypot(ptr.vx, ptr.vy) > 22 && G.t - ptr.hitT > 0.35 && partsNear(w.x, w.y, 50).length) { ptr.hitT = G.t; swingHit(w.x, w.y, it); }
}
function onUp(e) { const ptr = pointers.get(e.pointerId); if (!ptr) return; if (ptr.held) releaseThrow(ptr); if (ptr.grabCon) { Composite.remove(world, ptr.grabCon); } pointers.delete(e.pointerId); }
cv.addEventListener('pointerdown', (e) => { e.preventDefault(); onDown(e); });
cv.addEventListener('pointermove', (e) => { e.preventDefault(); onMove(e); });
cv.addEventListener('pointerup', (e) => { e.preventDefault(); onUp(e); });
cv.addEventListener('pointercancel', onUp);
for (const ev of ['contextmenu', 'gesturestart', 'gesturechange', 'dragstart', 'selectstart']) document.addEventListener(ev, (e) => e.preventDefault());
document.addEventListener('touchmove', (e) => { if (!e.target.closest || !e.target.closest('#items,#tabs,.grid')) e.preventDefault(); }, { passive: false });
let lastTouch = 0; document.addEventListener('touchend', (e) => { const n = Date.now(); if (n - lastTouch < 350) e.preventDefault(); lastTouch = n; }, { passive: false });

function toolFrame(dt) {
  const it = ITEM[G.item]; const B = buddy; if (!it) return; let fanActive = false;
  for (const ptr of pointers.values()) {
    ptr.tick += dt; ptr.ft = ptr.ft || 0;
    if (ptr.held) { for (const p of ptr.held) { const v = p.body.velocity; Body.setVelocity(p.body, { x: (ptr.x - p.body.position.x) * 0.4, y: (ptr.y - p.body.position.y) * 0.4 }); } continue; }
    if (it.mode === 'aim' && it.id === 'waterpistol' && ptr.tick > 0.2) { ptr.tick = 0; fireAim(it, ptr.x, ptr.y); }
    if (it.id === 'feather') {
      const near = partsNear(ptr.x, ptr.y, 30);
      if (near.length) {
        B.tickle = 0.3; const sp = Math.hypot(ptr.vx, ptr.vy);
        for (const h of near) { Body.setAngularVelocity(h.p.body, h.p.body.angularVelocity + rnd(-0.03, 0.03) * (1 + sp * 0.05)); if (Math.random() < 0.2) Body.setVelocity(h.p.body, { x: h.p.body.velocity.x + rnd(-0.8, 0.8), y: h.p.body.velocity.y - rnd(0, 1.3) }); }
        if (Math.random() < 0.18) P_(PT.heart, ptr.x + rnd(-20, 20), ptr.y, rnd(-1, 1), rnd(-2, -1), 1, rnd(9, 14), '#ff8fb8', -0.01, 0.99);
        if (ptr.tick > 0.5 && sp > 2) { ptr.tick = 0; sfx('squeak', { volume: 0.5, pitch: rnd(1, 1.4) }); fun(5, 'smash', ptr.x, ptr.y - 20, 'laugh', 'tickle', it); }
        floppy(0.3); setEmo('laugh', 0.4);
      }
    } else if (it.id === 'fan') {
      const dir = ptr.x > buddyCenter().x ? -1 : 1; const fxp = dir > 0 ? 50 : W - 50; fanPtr = { x: fxp, y: ptr.y, dir }; fanActive = true;
      for (const p of B.list) { const dx = (p.body.position.x - fxp) * dir, dy = p.body.position.y - ptr.y; if (dx > 0 && dx < 760 && Math.abs(dy) < 170 + dx * 0.15) { const f = (1 - dx / 900) * (1 - Math.abs(dy) / 300); Body.setVelocity(p.body, { x: p.body.velocity.x + dir * 1.0 * f, y: p.body.velocity.y - 0.32 * f }); } }
      if (Math.random() < 0.7) P_(PT.streak, fxp + dir * 60, ptr.y + rnd(-100, 100), dir * rnd(14, 24), rnd(-0.5, 0.5), rnd(0.5, 0.9), rnd(30, 60), 'rgba(255,255,255,0.8)', 0, 1);
      B.floppy = Math.max(B.floppy, 0.5); if (Math.abs(B.parts.torso.body.velocity.x) > 3 && G.t - ptr.ft > 0.9) { ptr.ft = G.t; fun(6, 'smash', buddyCenter().x, buddyCenter().y - 60, 'wow', 'wind', it); sfx('whoosh', { volume: 0.4 }); }
    } else if (it.id === 'magnet') {
      let any = false; for (const p of B.list) { const dx = ptr.x - p.body.position.x, dy = ptr.y - p.body.position.y, d = Math.hypot(dx, dy) || 1; if (d < 380) { const a = Math.min(0.9, 90 / d); const v = p.body.velocity; Body.setVelocity(p.body, { x: (v.x + dx / d * a) * 0.975, y: (v.y + dy / d * a) * 0.975 }); any = true; } }
      if (any) { B.floppy = Math.max(B.floppy, 0.5); if (Math.random() < 0.3) P_(PT.dot, ptr.x + rnd(-60, 60), ptr.y + rnd(-60, 60), 0, 0, 0.5, rnd(2, 4), pick(['#fff', '#ffd23f', '#9be6ff']), 0, 0.9); if (G.t - ptr.ft > 0.8) { ptr.ft = G.t; fun(6, 'smash', ptr.x, ptr.y - 40, 'wow', 'magic', it); sfx('whoosh', { volume: 0.4, pitch: 0.7 }); } }
    } else if (it.id === 'hose') {
      const side = sideOf(ptr.x); const px = side === 0 ? 40 : W - 40, py = floorY - 30; const a = Math.atan2(ptr.y - py, ptr.x - px); hoseDir = { px, py, a, side };
      for (let i = 0; i < 4; i++) { const aa = a + rnd(-0.05, 0.05), s = rnd(20, 27); P_(PT.drop, px + Math.cos(aa) * 40, py + Math.sin(aa) * 40, Math.cos(aa) * s, Math.sin(aa) * s, rnd(0.5, 0.9), rnd(3, 6), pick(['#6fcfff', '#9be6ff', '#fff']), 0.35, 0.995); }
      const dx = Math.cos(a), dy = Math.sin(a); let hit = false;
      for (const p of B.list) { const rx = p.body.position.x - px, ry = p.body.position.y - py, along = rx * dx + ry * dy, perp = Math.abs(rx * dy - ry * dx); if (along > 0 && along < 1000 && perp < 55) { Body.setVelocity(p.body, { x: p.body.velocity.x + dx * 0.8, y: p.body.velocity.y + dy * 0.5 }); hit = true; } }
      if (hit) { B.wet = 2; floppy(0.4); if (G.t - ptr.ft > 0.45) { ptr.ft = G.t; fun(7, 'smash', buddyCenter().x, buddyCenter().y - 50, 'wow', 'liquid', null); splash(buddyCenter().x, buddyCenter().y, 10, '#9be6ff', 7); } }
      if (ptr.tick > 0.15) { ptr.tick = 0; sfx('splash', { volume: 0.18 }); }
    } else if (it.id === 'bubble') {
      if (ptr.tick > 0.12) { ptr.tick = 0; const side = sideOf(ptr.x); const px = side === 0 ? 70 : W - 70, py = floorY - 50; const a = Math.atan2(ptr.y - py, ptr.x - px) + rnd(-0.15, 0.15), s = rnd(4, 8); bubbles.push({ x: px + Math.cos(a) * 40, y: py + Math.sin(a) * 40, vx: Math.cos(a) * s, vy: Math.sin(a) * s, r: rnd(10, 24), t: 0, ph: rnd(0, 6) }); if (bubbles.length > 40) bubbles.shift(); sfx('pop', { volume: 0.12, pitch: rnd(1.6, 2.4) }); }
    } else if (it.id === 'torch') {
      if (Math.random() < 0.6) P_(PT.star, ptr.x + rnd(-24, 24), ptr.y + rnd(-34, 10), rnd(-1, 1), rnd(-2, -0.5), rnd(0.5, 1), rnd(5, 10), pick(['#ffe27a', '#fff', '#ffb52e']), -0.02, 0.97);
      if (partsNear(ptr.x, ptr.y - 20, 100).length) { B.glow = 0.5; if (G.t - ptr.ft > 0.9) { ptr.ft = G.t; setEmo('laugh', 1, true); fun(3, 'smash', buddyCenter().x, buddyCenter().y - 60, 'laugh', 'magic', it); sfx('sparkle', { volume: 0.4 }); } }
    }
  }
  if (!fanActive) fanPtr = null; let hs = false; for (const p of pointers.values()) if (ITEM[G.item] && ITEM[G.item].id === 'hose') hs = true; if (!hs) hoseDir = null;
}

// ---------------------------------------------------------------------------------------------- per-step update
function buddyAI() {
  const B = buddy; if (B.ko > 0 || B.grab || G.state === 'play' && G.paused) return; const dt = 1 / 60; const p = B.parts.torso.body.position;
  if (B.circT > 0) { B.circT -= dt; if (!(B.walkT > 0)) { B.walkDir = -B.walkDir || 1; B.walkT = 0.9; if (B.grounded) hopBuddy(B.walkDir * 2); } }
  B.aiT -= dt;
  if (B.aiT <= 0) { B.aiT = rnd(2, 4.5); const r = Math.random(); if (r < 0.35 && B.grounded) hopBuddy(rnd(-2, 2)); else if (r < 0.8) { B.walkDir = Math.random() < 0.5 ? -1 : 1; B.walkT = rnd(0.8, 1.8); } }
  if (B.walkT > 0) { B.walkT -= dt; if (p.x < 90) B.walkDir = 1; if (p.x > W - 90) B.walkDir = -1; if (B.grounded && B.muscle > 0.6) for (const n of ['lLL', 'lLR', 'uLL', 'uLR', 'torso']) { const b = B.parts[n].body; Body.setVelocity(b, { x: clamp(b.velocity.x + B.walkDir * 0.1, -1.8, 1.8), y: b.velocity.y }); } }
}
function hopBuddy(vx) { for (const p of buddy.list) Body.setVelocity(p.body, { x: vx + rnd(-0.3, 0.3), y: -rnd(7, 9.5) }); setEmo('happy', 0.8); sfx('boing', { volume: 0.25, pitch: rnd(1.1, 1.6) }); }
function stepPhysics() {
  const B = buddy; B.t = G.t;
  B.floppy = Math.max(0, B.floppy - 1 / 60);
  const target = B.floppy > 0 ? 0.12 : 1; B.muscle += (target - B.muscle) * (B.floppy > 0 ? 0.3 : 0.03);
  muscles(); balloonForces(); buddyAI();
  if (B.grab) B.muscle = 0.3;
  Engine.update(engine, 1000 / 60);
  for (const p of B.list) { p.sqv += -p.sq * 0.3 - p.sqv * 0.1; p.sq += p.sqv; const v = p.body.velocity, sp = Math.hypot(v.x, v.y); p.st += (Math.min(0.2, sp * 0.011) - p.st) * 0.25; }
  const av = Math.abs(B.parts.torso.body.angularVelocity); B.dizzy = B.dizzy * 0.985 + av * 1.2;
  if (B.dizzy > 22 && B.emo !== 'dizzy' && B.ko <= 0 && av < 0.25) { B.dizzy = 0; setEmo('dizzy', 2.6, true); fun(10, 'smash', buddyCenter().x, buddyCenter().y - 90, 'dizzy', 'launch', null); sfx('squeak', { pitch: 0.7 }); setEmo('dizzy', 2.6, true); }
  const tp = buddyCenter(); if (tp.y > floorY + 160 || tp.x < -200 || tp.x > W + 200 || !isFinite(tp.x)) respawnBuddy();
  for (let i = projs.length - 1; i >= 0; i--) {
    const p = projs[i], s = p.spec; if (p.held) continue;
    if (p.fuse > 0) { p.fuse -= 1 / 60; if (p.fuse <= 0 && s.fx === 'bomb') { explode(p); continue; } }
    if (s.trail && Math.random() < 0.9) P_(PT.puff, p.body.position.x, p.body.position.y, rnd(-0.5, 0.5), rnd(-0.5, 0.5), 0.5, 8, 'rgba(255,200,120,0.8)', 0, 0.95, 0.4);
    if (G.t - p.born > (s.life || 8) || p.body.position.y > floorY + 100 || p.body.position.x < -150 || p.body.position.x > W + 150) killProj(p, true);
  }
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
  c.strokeStyle = buddy.costume > 0 ? '#f4f4ff' : col.base; c.lineWidth = w; c.stroke();
  c.save(); c.translate(-w * 0.12, -w * 0.14); c.strokeStyle = col.light; c.globalAlpha = 0.55; c.lineWidth = w * 0.32; c.stroke(); c.restore();
}
function endPt(b, s) { const jl = b === null ? 0 : 0; return jl; }
function capPts(p, jl) { const b = p.body, s = Math.sin(b.angle), co = Math.cos(b.angle); return [{ x: b.position.x - s * -(-jl / 2) * -1, y: 0 }]; }
function ends(p, jl) { const b = p.body, s = Math.sin(b.angle), c = Math.cos(b.angle); return { top: { x: b.position.x + s * jl / 2, y: b.position.y - c * jl / 2 }, bot: { x: b.position.x - s * jl / 2, y: b.position.y + c * jl / 2 } }; }

function drawBuddy(c) {
  const B = buddy, P = B.parts, col = skinCols(); const t = G.t;
  const torso = P.torso.body, head = P.head.body;
  drawShadow(c);
  c.save(); if (Math.abs(B.flat) > 0.01) { const cx = torso.position.x; c.translate(cx, floorY); c.scale(1 + B.flat * 0.9, Math.max(0.2, 1 - B.flat * 0.72)); c.translate(-cx, -floorY); }
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
    if (save.equip.shirt) drawShirt(c, save.equip.shirt, w, h); if (B.costume > 0) drawBones(c, w, h); drawWounds(c, 'torso'); drawDecals(c, 'torso');
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
  c.restore();
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
  if (B.zap > 0) drawZapHair(c, R, t);
  // ears
  for (const s of [-1, 1]) { c.beginPath(); c.arc(s * R * 0.68, -R * 0.78, R * 0.32, 0, TAU); c.fillStyle = col.mid; c.fill(); c.strokeStyle = col.out; c.lineWidth = 4; c.stroke(); c.beginPath(); c.arc(s * R * 0.68, -R * 0.78, R * 0.17, 0, TAU); c.fillStyle = '#ffb3cf'; c.fill(); }
  c.beginPath(); c.arc(0, 0, R, 0, TAU);
  const g = c.createRadialGradient(-R * 0.35, -R * 0.4, R * 0.1, 0, 0, R * 1.1); g.addColorStop(0, col.light); g.addColorStop(0.5, col.base); g.addColorStop(1, col.dark);
  c.fillStyle = g; c.fill(); c.strokeStyle = col.out; c.lineWidth = 4; c.stroke();
  c.save(); c.beginPath(); c.arc(0, 0, R - 1, 0, TAU); c.clip();
  // muzzle
  c.fillStyle = col.belly; c.globalAlpha = 0.8; c.beginPath(); c.ellipse(0, R * 0.32, R * 0.36, R * 0.27, 0, 0, TAU); c.fill(); c.globalAlpha = 1;
  drawWounds(c, 'head'); drawDecals(c, 'head');
  c.restore();
  c.fillStyle = 'rgba(255,255,255,0.5)'; c.beginPath(); c.ellipse(-R * 0.42, -R * 0.58, R * 0.2, R * 0.1, -0.6, 0, TAU); c.fill();
  drawFace(c, R, col, t);
  if (B.cold > 0) { c.fillStyle = 'rgba(150,220,255,0.3)'; c.beginPath(); c.arc(0, 0, R, 0, TAU); c.fill(); }
  if (B.costume > 0) { c.fillStyle = 'rgba(58,29,74,0.9)'; for (const s of [-1, 1]) { c.beginPath(); c.ellipse(s * R * 0.37, -R * 0.05, R * 0.2, R * 0.24, 0, 0, TAU); c.fill(); } }
  if (save.equip.face) drawHead(c, save.equip.face, R, t);
  if (save.equip.hat && save.equip.hat !== 'helmet') drawHead(c, save.equip.hat, R, t);
  if (save.equip.hat === 'helmet') drawHead(c, 'helmet', R, t);
  // wet shine / dizzy stars
  if (B.emo === 'dizzy') for (let i = 0; i < 4; i++) { const a = t * 3 + i * TAU / 4; c.save(); c.translate(Math.cos(a) * R * 0.9 - 0, -R * 1.08 + Math.sin(a) * R * 0.2); c.rotate(-B.head_a || 0); c.fillStyle = '#ffd23f'; starPath(c, 0, 0, R * 0.2, R * 0.08, 5, a); c.fill(); c.strokeStyle = '#c9961f'; c.lineWidth = 1.5; c.stroke(); c.restore(); }
  if (B.sleepy || B.emo === 'ko') { c.fillStyle = '#7aa8ff'; c.font = `900 ${R * 0.5}px ui-rounded,system-ui,sans-serif`; c.textAlign = 'center'; c.fillText('z', R * 1.0, -R * 0.9 - Math.sin(t * 2) * 4); c.font = `900 ${R * 0.34}px ui-rounded,system-ui,sans-serif`; c.fillText('z', R * 1.25, -R * 1.25 - Math.sin(t * 2 + 1) * 4); }
}
function drawFace(c, R, col, t) {
  const B = buddy; let emo = B.sleepy ? 'sleepy' : B.emo; const yum = emo === 'yum'; if (yum) emo = 'laugh'; const ko = emo === 'ko'; if (ko) emo = 'dizzy'; const head = B.parts.head.body;
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
    c.fillStyle = '#7fd4ff'; if (!yum) for (const s of [-1, 1]) { c.beginPath(); c.ellipse(s * R * 0.62, R * 0.12 + Math.sin(t * 9) * 1.5, R * 0.05, R * 0.08, 0, 0, TAU); c.fill(); }
  } else if (emo === 'dizzy') {
    for (const s of [-1, 1]) { c.save(); c.translate(s * ex, ey); c.fillStyle = '#fff'; c.beginPath(); c.arc(0, 0, R * 0.2, 0, TAU); c.fill(); c.strokeStyle = dark; c.lineWidth = 2; c.stroke(); c.rotate(ko ? 0 : t * 8 * s); c.beginPath(); for (let i = 0; i < 40; i++) { const a = i * 0.45, r = i * R * 0.0045; c.lineTo(Math.cos(a) * r, Math.sin(a) * r); } c.lineWidth = R * 0.04; c.stroke(); c.restore(); }
  } else if (emo === 'sleepy') {
    c.strokeStyle = dark; c.lineWidth = R * 0.07; for (const s of [-1, 1]) { c.beginPath(); c.arc(s * ex, ey - R * 0.02, R * 0.14, 0.15, Math.PI - 0.15); c.stroke(); }
  } else {
    const k = emo === 'wow' || emo === 'zap' ? 1.2 : emo === 'scared' ? 1.12 : emo === 'beg' ? 1.25 : 1; const rx = R * 0.135 * k, ry = R * 0.185 * k * blink;
    for (const s of [-1, 1]) {
      const x = s * ex + lox, y = ey + loy;
      c.fillStyle = dark; c.beginPath(); c.ellipse(x, y, rx, ry, 0, 0, TAU); c.fill();
      if (ry > R * 0.06) { const g = c.createRadialGradient(x, y + ry * 0.4, 1, x, y, ry); g.addColorStop(0, 'rgba(120,80,200,0.55)'); g.addColorStop(1, 'rgba(120,80,200,0)'); c.fillStyle = g; c.beginPath(); c.ellipse(x, y, rx, ry, 0, 0, TAU); c.fill(); c.fillStyle = '#fff'; c.beginPath(); c.ellipse(x - rx * 0.3, y - ry * 0.32, rx * 0.4, ry * 0.34, 0, 0, TAU); c.fill(); c.beginPath(); c.arc(x + rx * 0.35, y + ry * 0.38, rx * 0.17, 0, TAU); c.fill(); }
    }
    if (emo === 'wow' || emo === 'scared' || emo === 'beg') { c.strokeStyle = shade(col.base, -0.5); c.lineWidth = R * 0.05; for (const s of [-1, 1]) { c.beginPath(); c.arc(s * ex, ey - R * 0.36, R * 0.15, Math.PI * 1.2, Math.PI * 1.8); c.stroke(); } }
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
  } else if (emo === 'scared') {
    c.strokeStyle = dark; c.lineWidth = R * 0.05; c.beginPath(); for (let i = 0; i <= 8; i++) { const x = -R * 0.2 + i / 8 * R * 0.4, y = my + R * 0.1 + (i % 2 ? -1 : 1) * R * 0.03; i ? c.lineTo(x, y) : c.moveTo(x, y); } c.stroke(); c.fillStyle = '#9be6ff'; c.beginPath(); c.moveTo(R * 0.78, -R * 0.42); c.quadraticCurveTo(R * 0.92, -R * 0.2, R * 0.78, -R * 0.14); c.quadraticCurveTo(R * 0.64, -R * 0.2, R * 0.78, -R * 0.42); c.fill();
  } else if (emo === 'beg') {
    c.strokeStyle = dark; c.lineWidth = R * 0.05; c.beginPath(); c.moveTo(-R * 0.18, my + R * 0.12); c.quadraticCurveTo(0, my - R * 0.02, R * 0.18, my + R * 0.12); c.stroke(); c.fillStyle = 'rgba(150,220,255,0.9)'; for (const s of [-1, 1]) { c.beginPath(); c.ellipse(s * R * 0.5, R * 0.14 + (t * 20 % 6), R * 0.05, R * 0.09, 0, 0, TAU); c.fill(); }
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
  } else if (p.kind === 'spring') {
    c.fillStyle = 'rgba(60,20,80,0.22)'; c.beginPath(); c.ellipse(0, 6, 50, 9, 0, 0, TAU); c.fill(); c.translate(0, -2); c.scale(1 - sq * 0.15, 1 + sq * 0.5); c.scale(1.15, 1.15); c.translate(0, -34); drawItem(c, 'spring');
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
    const sc = (ITEM[f.type] && ITEM[f.type].big) ? 2.2 : 1.5; c.globalAlpha = k < 0.8 ? 1 : (1 - k) / 0.2;
    c.translate(f.type === 'hammer' ? 20 : 14, f.type === 'hammer' ? -22 : -14); c.rotate(-0.0); c.scale(sc, sc); drawItem(c, f.type);
    c.restore();
  }
}
const easeOut = (t) => 1 - Math.pow(1 - t, 3);
// ---------------------------------------------------------------------------------------------- main render
const snow = []; for (let i = 0; i < 70; i++) snow.push({ x: Math.random(), y: Math.random(), s: rnd(1.5, 4), v: rnd(20, 50), ph: rnd(0, 6) });
let hudCoin = null;
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

// ---------------------------------------------------------------------------------------------- render helpers (v2)
function drawWounds(c, which) {
  for (const w of buddy.wounds) {
    if (w.part !== which) continue; const a = clamp(w.life / 4, 0, 1); let kind = w.kind;
    if (kind === 'bruise' && w.life < 26) kind = 'bandage';
    c.save(); c.globalAlpha = a; c.translate(w.x, w.y); c.rotate(w.rot); c.scale(w.s, w.s);
    if (kind === 'bump') { c.fillStyle = 'rgba(255,255,255,0.55)'; c.beginPath(); c.arc(0, 0, 7, 0, TAU); c.fill(); c.strokeStyle = 'rgba(160,80,60,0.55)'; c.lineWidth = 2.5; c.beginPath(); c.arc(0, 0, 7, 0.4, 2.6); c.stroke(); c.fillStyle = '#fff'; c.beginPath(); c.arc(-2, -2, 2, 0, TAU); c.fill(); }
    else if (kind === 'bruise') { c.fillStyle = 'rgba(150,90,200,0.45)'; c.beginPath(); c.ellipse(0, 0, 11, 8, 0.3, 0, TAU); c.fill(); c.fillStyle = 'rgba(90,150,220,0.35)'; c.beginPath(); c.ellipse(3, 2, 6, 4, 0.3, 0, TAU); c.fill(); }
    else if (kind === 'plaster') { rr(c, -12, -5.5, 24, 11, 5); c.fillStyle = '#ffd9b8'; c.fill(); c.strokeStyle = '#d9a070'; c.lineWidth = 2; c.stroke(); c.fillStyle = 'rgba(200,120,70,0.5)'; for (const x of [-4, 0, 4]) for (const y of [-2, 2]) { c.beginPath(); c.arc(x, y, 1, 0, TAU); c.fill(); } }
    else if (kind === 'bandage') { rr(c, -13, -6, 26, 12, 4); c.fillStyle = '#fff'; c.fill(); c.strokeStyle = '#c9c9d8'; c.lineWidth = 2; c.stroke(); c.strokeStyle = '#ff9ec7'; c.lineWidth = 3; c.beginPath(); c.moveTo(-4, -4); c.lineTo(4, 4); c.moveTo(4, -4); c.lineTo(-4, 4); c.stroke(); }
    else { c.strokeStyle = 'rgba(70,40,40,0.7)'; c.lineWidth = 2.5; c.beginPath(); c.moveTo(-12, 0); c.lineTo(-6, -4); c.lineTo(0, 3); c.lineTo(6, -3); c.lineTo(12, 1); c.stroke(); c.strokeStyle = '#fff'; c.lineWidth = 2; for (const x of [-8, -1, 5, 10]) { c.beginPath(); c.moveTo(x, -6); c.lineTo(x, 6); c.stroke(); } }
    c.restore();
  }
}
function drawBones(c, w, h) { c.strokeStyle = 'rgba(255,255,255,0.95)'; c.lineWidth = 5; c.lineCap = 'round'; c.beginPath(); c.moveTo(0, -h * 0.28); c.lineTo(0, h * 0.4); c.stroke(); for (let i = 0; i < 4; i++) { const y = -h * 0.2 + i * h * 0.15, r = w * (0.34 - i * 0.03); c.beginPath(); c.moveTo(-r, y + 4); c.quadraticCurveTo(0, y - 6, r, y + 4); c.stroke(); } }
function drawZapHair(c, R, t) { c.fillStyle = '#ffe27a'; c.strokeStyle = '#c9961f'; c.lineWidth = 2.5; for (let i = -3; i <= 3; i++) { const a = -Math.PI / 2 + i * 0.28, l = R * (0.5 + 0.2 * Math.sin(t * 40 + i * 2)); c.beginPath(); c.moveTo(Math.cos(a - 0.1) * R * 0.9, Math.sin(a - 0.1) * R * 0.9); c.lineTo(Math.cos(a) * (R + l), Math.sin(a) * (R + l)); c.lineTo(Math.cos(a + 0.1) * R * 0.9, Math.sin(a + 0.1) * R * 0.9); c.fill(); c.stroke(); } }
function drawBox(c, front) {
  const bw = 230, bh = 94, x = W / 2, y = floorY; c.save(); c.translate(x, y);
  if (!front) {
    c.fillStyle = '#b98544'; for (const s of [-1, 1]) { c.beginPath(); c.moveTo(s * bw / 2, -bh + 4); c.lineTo(s * (bw / 2 + 26), -bh - 44); c.lineTo(s * (bw / 2 - 40), -bh - 52); c.lineTo(s * (bw / 2 - 66), -bh + 4); c.closePath(); c.fill(); c.strokeStyle = '#7e5424'; c.lineWidth = 3.5; c.lineJoin = 'round'; c.stroke(); }
    c.fillStyle = '#8f6330'; c.fillRect(-bw / 2 + 4, -bh, bw - 8, bh * 0.6);
  } else {
    c.fillStyle = 'rgba(60,20,80,0.2)'; c.beginPath(); c.ellipse(0, 8, bw * 0.62, 12, 0, 0, TAU); c.fill();
    const g = c.createLinearGradient(0, -bh, 0, 0); g.addColorStop(0, '#e6b878'); g.addColorStop(1, '#c99352'); c.fillStyle = g; rr(c, -bw / 2, -bh * 0.82, bw, bh * 0.82, 8); c.fill(); c.strokeStyle = '#8f6330'; c.lineWidth = 4; c.stroke();
    c.fillStyle = '#d9a864'; c.beginPath(); c.moveTo(-bw / 2, -bh * 0.82); c.lineTo(-bw / 2 - 6, -bh); c.lineTo(bw / 2 + 6, -bh); c.lineTo(bw / 2, -bh * 0.82); c.closePath(); c.fill(); c.stroke();
    c.fillStyle = 'rgba(255,235,200,0.9)'; c.fillRect(-18, -bh, 36, bh * 0.82); c.strokeStyle = '#c9a878'; c.lineWidth = 2; c.strokeRect(-18, -bh, 36, bh * 0.82);
    c.fillStyle = '#e03c3c'; c.font = '900 17px ui-rounded,system-ui,sans-serif'; c.textAlign = 'center'; c.save(); c.translate(-bw * 0.3, -bh * 0.4); c.rotate(-0.08); c.fillText('BUDDY', 0, 0); c.restore();
    c.strokeStyle = '#3a1d4a'; c.lineWidth = 3; c.beginPath(); c.arc(bw * 0.3, -bh * 0.4, 12, 0.2, Math.PI - 0.2); c.stroke(); c.fillStyle = '#3a1d4a'; c.beginPath(); c.arc(bw * 0.3 - 5, -bh * 0.5, 2.2, 0, TAU); c.arc(bw * 0.3 + 5, -bh * 0.5, 2.2, 0, TAU); c.fill();
  }
  c.restore();
}
function drawSpeech(c) {
  const B = buddy; if (!B.say || !save.speech) return; const s = B.say; if (s.t > s.dur) return; const hp = B.parts.head.body.position;
  const a = clamp(Math.min(s.t * 6, (s.dur - s.t) * 4), 0, 1); c.save(); c.globalAlpha = a; c.font = '800 21px ui-rounded,"SF Pro Rounded",system-ui,sans-serif'; const tw = Math.min(260, c.measureText(s.txt).width); const words = s.txt.split(' '); const lines = []; let cur = '';
  for (const w of words) { const test = cur ? cur + ' ' + w : w; if (c.measureText(test).width > 230 && cur) { lines.push(cur); cur = w; } else cur = test; } lines.push(cur);
  const bw = Math.min(260, Math.max(...lines.map((l) => c.measureText(l).width))) + 30, bh = lines.length * 26 + 18; let bx = clamp(hp.x + 30, bw / 2 + 8, W - bw / 2 - 8), by = hp.y - DIM.headR - 40 - bh; by = Math.max(100, by) - Math.sin(s.t * 3) * 2;
  c.translate(bx, by); c.scale(0.9 + 0.1 * Math.min(1, s.t * 8), 0.9 + 0.1 * Math.min(1, s.t * 8));
  c.fillStyle = 'rgba(80,30,110,0.18)'; rr(c, -bw / 2 + 2, 4, bw, bh, 16); c.fill(); c.fillStyle = '#fff'; rr(c, -bw / 2, 0, bw, bh, 16); c.fill(); c.strokeStyle = '#d9c4ee'; c.lineWidth = 3; c.stroke();
  c.beginPath(); c.moveTo(clamp(hp.x - bx, -bw / 2 + 24, bw / 2 - 24) - 10, bh - 1); c.lineTo(hp.x - bx, bh + 22 + Math.max(0, hp.y - DIM.headR - 40 - by - bh) * 0 ); c.lineTo(clamp(hp.x - bx, -bw / 2 + 24, bw / 2 - 24) + 10, bh - 1); c.fillStyle = '#fff'; c.fill();
  c.fillStyle = '#4a2a6b'; c.textAlign = 'center'; lines.forEach((l, i) => c.fillText(l, 0, 26 + i * 26 - 4)); c.restore();
}
function drawProj(c, p) {
  const b = p.body, s = p.spec; c.save(); c.translate(b.position.x, b.position.y); if (!p.noRot && !s.noSpin) c.rotate(b.angle); const r = p.r;
  if (s.fx === 'bomb' && p.fuse > 0) { const k = 1 + 0.1 * Math.sin(G.t * (10 + (2 - p.fuse) * 14)); c.scale(k, k); }
  if (p.sprite === 'beach') drawBeachBall(c, r, 0);
  else if (p.sprite === 'blocks') { const col = ['#ff5d8f', '#3ec6ff', '#ffd23f'][(p.born * 7 | 0) % 3]; rr(c, -s.w / 2, -s.h / 2, s.w, s.h, 6); c.fillStyle = col; c.fill(); c.strokeStyle = shade(col, -0.4); c.lineWidth = 3; c.stroke(); c.fillStyle = 'rgba(255,255,255,0.9)'; c.beginPath(); c.arc(0, 0, s.w * 0.22, 0, TAU); c.fill(); }
  else { const sc = (r * 3.3) / 100 * (p.sprite === 'penguin' ? 1.2 : p.sprite === 'rocket' ? 1.1 : 1); c.scale(sc, sc); drawItem(c, p.sprite); }
  if (s.fx === 'bomb' && p.fuse > 0 && Math.sin(G.t * 24) > 0.4) { c.fillStyle = 'rgba(255,255,255,0.35)'; c.beginPath(); c.arc(0, 0, r, 0, TAU); c.fill(); }
  c.restore();
  const h = floorY - b.position.y; if (h > 0) { c.fillStyle = `rgba(60,20,80,${clamp(0.25 - h / 1800, 0.05, 0.25)})`; c.beginPath(); c.ellipse(b.position.x, floorY + 6, r * 0.9, r * 0.22, 0, 0, TAU); c.fill(); }
}
function drawPointerTools(c) {
  const it = ITEM[G.item];
  for (const ptr of pointers.values()) {
    if (ptr.held || !it) continue; c.save(); c.translate(ptr.x, ptr.y);
    if (it.id === 'feather') { c.rotate(Math.sin(G.t * 9) * 0.2 - 0.3); c.scale(1.7, 1.7); c.translate(14, -24); drawItem(c, 'feather'); }
    else if (it.id === 'magnet') { c.scale(1.5, 1.5); c.rotate(Math.sin(G.t * 6) * 0.06); drawItem(c, 'magnet'); c.strokeStyle = 'rgba(255,255,255,0.5)'; c.lineWidth = 2; for (let i = 0; i < 3; i++) { c.beginPath(); c.arc(0, 0, ((G.t * 60 + i * 40) % 120) + 10, 0, TAU); c.globalAlpha = 1 - (((G.t * 60 + i * 40) % 120) / 120); c.stroke(); } }
    else if (it.id === 'torch') { glowAt(c, 0, -10, 90 + Math.sin(G.t * 20) * 8); c.scale(1.4, 1.4); c.translate(0, 14); drawItem(c, 'torch'); }
    else if (it.id === 'bubble') { c.scale(1.4, 1.4); c.translate(10, 10); drawItem(c, 'bubble'); }
    c.restore();
  }
  if (fanPtr) { c.save(); c.translate(fanPtr.x, fanPtr.y); c.scale(fanPtr.dir * -1.8, 1.8); drawItem(c, 'fan', G.t); c.restore(); }
  if (hoseDir) { c.save(); c.translate(hoseDir.px, hoseDir.py); c.rotate(hoseDir.a); if (hoseDir.side === 1) { /* keep upright */ } c.scale(1.3, 1.3); c.fillStyle = '#ff5d6c'; rr(c, -30, -14, 70, 28, 12); c.fill(); c.strokeStyle = '#a82a3a'; c.lineWidth = 3.5; c.stroke(); c.fillStyle = '#ffd23f'; rr(c, 34, -11, 22, 22, 6); c.fill(); c.stroke(); c.restore(); }
}
function glowAt(c, x, y, r) { const g = c.createRadialGradient(x, y, 0, x, y, r); g.addColorStop(0, 'rgba(255,220,120,0.6)'); g.addColorStop(1, 'rgba(255,200,80,0)'); c.fillStyle = g; c.beginPath(); c.arc(x, y, r, 0, TAU); c.fill(); }
function drawBubbles(c) {
  for (const b of bubbles) { c.save(); c.translate(b.x, b.y); c.globalAlpha = clamp(Math.min(b.t * 4, (5 - b.t)), 0, 1) * 0.9; c.beginPath(); c.arc(0, 0, b.r, 0, TAU); const g = c.createRadialGradient(-b.r * 0.3, -b.r * 0.3, 1, 0, 0, b.r); g.addColorStop(0, 'rgba(255,255,255,0.75)'); g.addColorStop(0.7, 'rgba(180,230,255,0.25)'); g.addColorStop(1, 'rgba(200,170,255,0.5)'); c.fillStyle = g; c.fill(); c.strokeStyle = 'rgba(255,255,255,0.8)'; c.lineWidth = 2; c.stroke(); c.fillStyle = 'rgba(255,255,255,0.9)'; c.beginPath(); c.ellipse(-b.r * 0.4, -b.r * 0.4, b.r * 0.2, b.r * 0.1, -0.7, 0, TAU); c.fill(); c.restore(); }
}
function render() {
  ensureBg();
  ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.drawImage(bgCanvas, 0, 0);
  const sh = G.shake; const shx = (Math.random() - 0.5) * sh, shy = (Math.random() - 0.5) * sh; const z = 1 + G.zoom;
  ctx.setTransform(dpr * S * z, 0, 0, dpr * S * z, (shx - (z - 1) * vw / 2) * dpr, (shy - (z - 1) * vh / 2) * dpr);
  if (save.room === 'snow') { ctx.fillStyle = 'rgba(255,255,255,0.95)'; for (const f of snow) { const x = ((f.x * W + Math.sin(G.t + f.ph) * 20) % W + W) % W, y = (f.y * (floorY + 20) + G.t * f.v) % (floorY + 20); ctx.beginPath(); ctx.arc(x, y, f.s, 0, TAU); ctx.fill(); } }
  if (save.room === 'space') { for (let i = 0; i < 14; i++) { const x = (i * 137.5) % W, y = (i * 71.3) % (floorY * 0.8), a = 0.5 + 0.5 * Math.sin(G.t * 2 + i); ctx.fillStyle = `rgba(255,255,255,${a})`; starPath(ctx, x, y, 3 + a * 3, 1, 4, G.t * 0.3 + i); ctx.fill(); } }
  for (const pd_ of puddles) { const a = clamp(1 - pd_.t / 3, 0, 1); ctx.fillStyle = `rgba(100,190,255,${a * 0.5})`; ctx.beginPath(); ctx.ellipse(pd_.x, floorY + 10, 50 * Math.min(1, pd_.t * 6 + 0.2), 8, 0, 0, TAU); ctx.fill(); }
  const inBox = save.room === 'box' && Math.abs(buddyCenter().x - W / 2) < 90;
  if (save.room === 'box') { drawBox(ctx, false); if (!inBox) drawBox(ctx, true); }
  for (const p of pads) drawPad(ctx, p);
  for (const e of ents) if (e.k === 'conveyor' || e.k === 'vice') { /* drawn in drawEnts */ }
  launchers.forEach((L, i) => drawLauncher(ctx, L, i));
  if (buddy.glow > 0) { const t = buddyCenter(); glowAt(ctx, t.x, t.y - 20, 190 * Math.min(1, buddy.glow * 2)); }
  drawBuddy(ctx); if (inBox) drawBox(ctx, true);
  for (const b of balloons) drawBalloon(ctx, b);
  for (const p of projs) drawProj(ctx, p);
  drawEnts(ctx); drawBubbles(ctx); drawToolFx(ctx); drawPointerTools(ctx);
  drawParticles(ctx); drawTexts(ctx); drawSpeech(ctx);
  if (G.flash > 0.01) { ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = `rgba(255,255,255,${G.flash})`; ctx.fillRect(0, 0, cv.width, cv.height); }
}

// ---------------------------------------------------------------------------------------------- frame update
let last = performance.now(), acc = 0;
function updateVisuals(dt) {
  const B = buddy; G.t += dt; if (G.state === 'play') save.stats.time += dt;
  G.shake *= Math.pow(0.0008, dt); if (G.shake < 0.05) G.shake = 0; G.zoom *= Math.pow(0.01, dt); G.flash *= Math.pow(0.002, dt);
  for (const p of parts_) { if (!p.on) continue; const s = dt * 60; p.life -= dt; if (p.life <= 0) { p.on = false; continue; } p.vy += p.g * s; const d = Math.pow(p.drag, s); p.vx *= d; p.vy *= d; p.x += p.vx * s; p.y += p.vy * s; p.rot += p.vr * s; if (p.grow) p.size += p.grow * s * (p.type === PT.ring ? 1 : 0.1); }
  for (let i = texts.length - 1; i >= 0; i--) { texts[i].t += dt; texts[i].x += texts[i].vx; if (texts[i].t > 1.1) texts.splice(i, 1); }
  for (const f of flyers) { f.t += dt; if (!hudCoin) hudCoin = coinTarget(); f.tx = hudCoin.x; f.ty = hudCoin.y; }
  for (let i = flyers.length - 1; i >= 0; i--) if (flyers[i].t > 0.7) { flyers.splice(i, 1); coinBump(); }
  for (let i = fx.length - 1; i >= 0; i--) { fx[i].t += dt; if (fx[i].t > fx[i].dur) fx.splice(i, 1); }
  for (const L of launchers) { if (L.t > 0) { L.t -= dt; L.rec *= Math.pow(0.003, dt); } }
  for (const p of pads) { p.sq *= Math.pow(0.04, dt); }
  for (let i = puddles.length - 1; i >= 0; i--) { puddles[i].t += dt; if (puddles[i].t > 3) puddles.splice(i, 1); }
  updateEnts(dt);
  for (let i = bubbles.length - 1; i >= 0; i--) { const b = bubbles[i]; b.t += dt; b.x += b.vx * dt * 60 + Math.sin(G.t * 3 + b.ph) * 0.3; b.y += b.vy * dt * 60; b.vy -= 0.02 * dt * 60; b.vx *= Math.pow(0.99, dt * 60); let pop = b.t > 5; for (const p of B.list) { if (Math.hypot(p.body.position.x - b.x, p.body.position.y - b.y) < b.r + p.rad * 0.8) { pop = true; if (G.t - (B.bubT || 0) > 0.35) { B.bubT = G.t; setEmo('laugh', 0.6); fun(3, 'soft', b.x, b.y, 'laugh', 'soft', null); } } } if (pop) { puff(b.x, b.y, 4, 'rgba(210,240,255,0.8)', 2, b.r * 0.6); sfx('pop', { volume: 0.25, pitch: rnd(1.5, 2.5) }); bubbles.splice(i, 1); } }
  // buddy state
  B.emoT -= dt; if (B.emoT <= 0 && B.emo !== 'idle' && B.ko <= 0) B.emo = B.hp < 35 ? 'beg' : 'idle';
  if (B.ko > 0) { B.ko -= dt; if (!G.paused && B.ko <= 0) revive(); }
  if (B.say) { B.say.t += dt; if (B.say.t > B.say.dur) B.say = null; }
  if (B.zap > 0) B.zap -= dt; if (B.cold > 0) B.cold -= dt; if (B.glow > 0) B.glow -= dt; if (B.costume > 0) B.costume -= dt;
  if (B.hp < 100 && B.ko <= 0 && G.t - G.lastFun > 2.5) B.hp = Math.min(100, B.hp + dt * 1.2);
  if (Math.round(B.hp) !== lastHp && G.state === 'play') updateHud();
  for (let i = B.wounds.length - 1; i >= 0; i--) { B.wounds[i].life -= dt * (B.hp > 60 ? 1.8 : 1); if (B.wounds[i].life <= 0) B.wounds.splice(i, 1); }
  const viceOn = ents.some((e) => e.k === 'vice' && e.t < 1.4);
  if (!viceOn) { B.flatV += -B.flat * 0.25 - B.flatV * 0.1; B.flat += B.flatV; if (Math.abs(B.flat) < 0.002 && Math.abs(B.flatV) < 0.002) { B.flat = 0; B.flatV = 0; } }
  B.wet -= dt; if (B.wet > 0 && Math.random() < 0.25) { const h = B.parts.head.body.position; P_(PT.drop, h.x + rnd(-30, 30), h.y + rnd(-10, 30), 0, 0.5, 0.7, rnd(2, 4), '#6fcfff', 0.3, 0.99); }
  if (B.cold > 0 && Math.random() < 0.3) { const h = B.parts.head.body.position; P_(PT.star, h.x + rnd(-40, 40), h.y + rnd(-50, 30), 0, 0, 0.4, 6, '#cfefff', 0, 1); Body.setAngularVelocity(B.parts.torso.body, B.parts.torso.body.angularVelocity + rnd(-0.01, 0.01)); }
  if (B.glitter > 0) { B.glitter -= dt; if (Math.random() < 0.35) { const t = buddyCenter(); P_(PT.glit, t.x + rnd(-45, 45), t.y + rnd(-90, 60), rnd(-0.5, 0.5), rnd(0.2, 1), 0.9, rnd(2, 4), pick(['#fff', '#ffd23f', '#ff9ee0']), 0.05, 0.98); } }
  for (let i = B.decals.length - 1; i >= 0; i--) { B.decals[i].life -= dt; if (B.decals[i].life <= 0) B.decals.splice(i, 1); }
  if (!$('hint').classList.contains('hidden')) placeHint();
  B.blink -= dt; B.nextBlink -= dt; if (B.nextBlink <= 0) { B.blink = 0.16; B.nextBlink = rnd(2, 5); }
  const head = B.parts.head.body.position; let tx = mouse.x - head.x, ty = mouse.y - head.y; const d = Math.hypot(tx, ty) || 1; tx = tx / d * Math.min(1, d / 160); ty = ty / d * Math.min(1, d / 160);
  const first = pointers.values().next().value; if (first) { tx = first.x - head.x; ty = first.y - head.y; const dd = Math.hypot(tx, ty) || 1; tx = tx / dd; ty = ty / dd; }
  B.look.x += (tx - B.look.x) * Math.min(1, dt * 10); B.look.y += (ty - B.look.y) * Math.min(1, dt * 10);
  G.idleT += dt; B.chatT -= dt;
  if (G.state === 'play') { if (G.idleT > 25 && !B.sleepy && B.emo === 'idle') B.sleepy = true; if (G.idleT > 14 && G.idleT - dt <= 14) showHint('Pick a toy and play with Buddy!'); if (B.chatT <= 0 && B.ko <= 0) { B.chatT = rnd(9, 15); say(B.hp < 40 ? 'beg' : 'idle'); } }
  if (B.sleepy && Math.random() < 0.01) P_(PT.z, head.x, head.y, 0, 0, 0, 0, '#fff');
  if (G.t - G.lastFun > 2.4 && G.combo > 0) { G.combo = 0; music.setIntensity(G.state === 'play' ? 0.5 : 0.4); updateHud(); }
  if (G.state === 'title') { G.demoT = (G.demoT || 0) - dt; if (G.demoT <= 0 && B.grounded) { G.demoT = rnd(2.2, 3.4); hopBuddy(rnd(-1.5, 1.5)); setEmo(Math.random() < 0.5 ? 'laugh' : 'wow', 1.0, true); } }
}
function frame(now) {
  if (window.__hold) { last = now; requestAnimationFrame(frame); return; }
  const real = Math.min(0.05, (now - last) / 1000); last = now; if (G.slowT > 0) { G.slowT -= real; if (G.slowT <= 0) G.slow = 1; }
  const dt = real * G.slow;
  if (!G.paused) {
    acc += dt; let n = 0;
    while (acc >= 1 / 60 && n < 3) { stepPhysics(); acc -= 1 / 60; n++; }
    if (acc > 0.1) acc = 0;
    updateVisuals(dt); if (G.state === 'play') toolFrame(dt);
  }
  render();
  requestAnimationFrame(frame);
}
// ---------------------------------------------------------------------------------------------- UI
const ICON = {
  cash: '<svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="14" fill="#58d68d" stroke="#1a8f50" stroke-width="2.5"/><circle cx="16" cy="16" r="9.5" fill="none" stroke="#a8f0c8" stroke-width="2"/><text x="16" y="21.5" text-anchor="middle" font-size="15" font-weight="900" fill="#fff" font-family="system-ui,sans-serif">$</text></svg>',
  gold: '<svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="14" fill="#ffd23f" stroke="#c47d12" stroke-width="2.5"/><path d="M16 7l2.6 5.6 6 .7-4.5 4.1 1.3 6L16 20.4 10.6 23.4l1.3-6-4.5-4.1 6-.7z" fill="#fff6c0" stroke="#e0a416" stroke-width="1.5" stroke-linejoin="round"/></svg>',
  speakerOn: '<svg viewBox="0 0 32 32"><path d="M5 12h5l7-6v20l-7-6H5z" fill="#ff4f94" stroke="#ff4f94" stroke-width="2" stroke-linejoin="round"/><path d="M21 11a7 7 0 0 1 0 10M24 7a12 12 0 0 1 0 18" fill="none" stroke="#ff4f94" stroke-width="3" stroke-linecap="round"/></svg>',
  speakerOff: '<svg viewBox="0 0 32 32"><path d="M5 12h5l7-6v20l-7-6H5z" fill="#c9b0d6" stroke="#c9b0d6" stroke-width="2" stroke-linejoin="round"/><path d="M22 12l7 8M29 12l-7 8" fill="none" stroke="#ff4f94" stroke-width="3.2" stroke-linecap="round"/></svg>',
  hanger: '<svg viewBox="0 0 32 32"><path d="M16 9a3 3 0 1 1 3 3c-1.4 0-3 .8-3 2.4V16L4 24h24L16 16" fill="#ffd23f" stroke="#c47d12" stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round"/></svg>',
  gift: '<svg viewBox="0 0 32 32"><rect x="5" y="13" width="22" height="14" rx="3" fill="#ff8fbe" stroke="#d93a7c" stroke-width="2.4"/><rect x="3" y="9" width="26" height="6" rx="2.5" fill="#ffc4e0" stroke="#d93a7c" stroke-width="2.4"/><path d="M16 9v18" stroke="#d93a7c" stroke-width="3"/><path d="M16 9c-4-6-9-2-5 0M16 9c4-6 9-2 5 0" fill="none" stroke="#d93a7c" stroke-width="2.4" stroke-linecap="round"/></svg>',
  trash: '<svg viewBox="0 0 32 32"><path d="M8 10h16l-1.6 17H9.6z" fill="#cfe2ff" stroke="#4a6ab8" stroke-width="2.4" stroke-linejoin="round"/><rect x="6" y="6" width="20" height="4" rx="2" fill="#9fb8f0" stroke="#4a6ab8" stroke-width="2.4"/><path d="M13 5.5h6M12.5 14v9M16 14v9M19.5 14v9" stroke="#4a6ab8" stroke-width="2.2" stroke-linecap="round"/></svg>',
  heart: '<svg viewBox="0 0 32 32"><path d="M16 27C4 18 3 10 9 7c3-1.5 6 0 7 3 1-3 4-4.500 7-3 6 3 5 11-7 20z" fill="#ff4f6a" stroke="#b81f3c" stroke-width="2.2" stroke-linejoin="round"/></svg>',
};
const isGold = (it) => it.cur === 'gold';
let shelfCat = save.cat || 'soft';
function iconCanvas(size, draw) {
  const cvs = document.createElement('canvas'); const d = Math.min(window.devicePixelRatio || 1, 2) * 1.5; cvs.width = cvs.height = Math.round(size * d);
  const c = cvs.getContext('2d'); c.translate(cvs.width / 2, cvs.height / 2); const s = cvs.width / 108; c.scale(s, s); draw(c); return cvs;
}
function buildShelf() {
  const tb = $('tabs'); tb.innerHTML = '';
  for (const cat of CATS) {
    const b = document.createElement('button'); b.className = 'ctab'; b.dataset.cat = cat.id;
    const cv2 = iconCanvas(30, (c) => { c.scale(1.05, 1.05); drawItem(c, cat.icon); }); b.appendChild(cv2); const s = document.createElement('span'); s.textContent = cat.name; b.appendChild(s);
    b.onclick = () => { shelfCat = cat.id; save.cat = cat.id; sfx('click'); renderItems(); $('items').scrollLeft = 0; }; tb.appendChild(b);
  }
  tb.addEventListener('wheel', (e) => { if (Math.abs(e.deltaY) > Math.abs(e.deltaX)) { tb.scrollLeft += e.deltaY; e.preventDefault(); } }, { passive: false });
  $('items').addEventListener('wheel', (e) => { if (Math.abs(e.deltaY) > Math.abs(e.deltaX)) { $('items').scrollLeft += e.deltaY; e.preventDefault(); } }, { passive: false });
  renderItems();
}
function renderItems() {
  for (const b of $('tabs').children) b.classList.toggle('on', b.dataset.cat === shelfCat);
  const box = $('items'); box.innerHTML = '';
  for (const it of ITEMS.filter((i) => i.cat === shelfCat)) {
    const b = document.createElement('button'); b.className = 'tile'; b.dataset.id = it.id;
    b.appendChild(iconCanvas(60, (c) => drawItem(c, it.id)));
    const nm = document.createElement('div'); nm.className = 'nm'; nm.textContent = SHORT[it.id]; b.appendChild(nm);
    const pr = document.createElement('div'); pr.className = 'price'; pr.innerHTML = it.daily ? `${ICON.gift}<span>Daily</span>` : `${isGold(it) ? ICON.gold : ICON.cash}<span>${it.price}</span>`; b.appendChild(pr);
    b.onclick = () => tileClick(it, b); box.appendChild(b);
  }
  refreshShelf();
}
function owned(it) { return !!save.items[it.id]; }
function refreshShelf() {
  for (const b of $('items').querySelectorAll('.tile')) {
    const it = ITEM[b.dataset.id], own = owned(it);
    b.classList.toggle('locked', !own); b.classList.toggle('sel', own && G.item === it.id); b.classList.toggle('afford', !own && !it.daily && (isGold(it) ? save.gold : save.cash) >= it.price);
    b.querySelector('.price').style.display = own ? 'none' : 'flex'; b.querySelector('.nm').style.display = own ? 'block' : 'none';
  }
  for (const b of $('tabs').children) b.classList.toggle('on', b.dataset.cat === shelfCat);
}
function pay(price, cur) {
  if (cur === 'gold') { if (save.gold < price) return false; save.gold -= price; } else { if (save.cash < price) return false; save.cash -= price; save.stats.spent += price; }
  persist(); updateHud(); return true;
}
function need(price, cur, el) { if (el) { el.classList.remove('shake'); void el.offsetWidth; el.classList.add('shake'); } sfx('squeak', { pitch: 0.6 }); const have = cur === 'gold' ? save.gold : save.cash; toast(`Need ${price - have} more ${cur === 'gold' ? 'gold' : 'cash'}!`); }
function tileClick(it, b) {
  if (G.state !== 'play') return;
  if (!owned(it)) {
    if (it.daily) { toast('Win this one with the daily gift!'); sfx('squeak', { pitch: 0.6 }); return; }
    if (pay(it.price, it.cur)) { save.items[it.id] = 1; persist(); sfx('powerup'); sfx('sparkle'); burstConfetti(W / 2, floorY - 200, 50, 14); floatText('Unlocked!', W / 2, floorY - 280, '#ffb52e', 44); selectItem(it.id); } else need(it.price, it.cur, b);
    return;
  }
  sfx('click'); selectItem(it.id);
}
const HINTS = { melee: 'Tap Buddy to whack him!', throw: 'Drag and flick to throw!', aim: 'Tap to aim and fire!', hold: 'Press and hold on Buddy!', tap: 'Tap to use!', place: 'Tap the floor to place it!' };
function selectItem(id) {
  const it = ITEM[id]; G.item = id; save.item = id; shelfCat = it.cat; save.cat = it.cat; persist(); renderItems(); G.idleT = 0; hideHint();
  if (!save.hints[it.mode]) { save.hints[it.mode] = 1; showHint(HINTS[it.mode]); }
  const b = $('items').querySelector(`.tile[data-id="${id}"]`); if (b) b.scrollIntoView({ inline: 'center', block: 'nearest', behavior: 'smooth' });
  for (const p of pointers.values()) { if (p.held) releaseThrow(p); }
}
let toastT = 0;
function toast(msg) { const t = $('toast'); t.textContent = msg; t.classList.add('show'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('show'), 1800); }
let hintT = 0;
function showHint(msg) { const h = $('hint'); h.textContent = msg; placeHint(); h.classList.remove('hidden'); clearTimeout(hintT); hintT = setTimeout(() => h.classList.add('hidden'), 6500); }
function placeHint() { const h = $('hint'); h.style.top = (128 + (parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--safe-t')) || 0)) + 'px'; h.style.left = '50%'; }
function hideHint() { $('hint').classList.add('hidden'); clearTimeout(hintT); }
let lastHp = -1;
function updateHud(bump) {
  $('cashN').textContent = save.cash; $('goldN').textContent = save.gold; $('exCash').innerHTML = `${ICON.cash}<span>${save.cash}</span>`;
  const hp = Math.round(clamp(buddy.hp, 0, 100)); if (hp !== lastHp) { lastHp = hp; const f = $('hpFill'); f.style.width = hp + '%'; f.style.background = hp > 55 ? 'linear-gradient(#8cf29a,#2fc678)' : hp > 28 ? 'linear-gradient(#ffe27a,#ffb52e)' : 'linear-gradient(#ff9aa4,#ff4f6a)'; }
  $('hpTxt').textContent = `Buddy  Lv ${save.level}`; const ct = $('comboTag'); ct.classList.toggle('hidden', G.combo < 2); ct.textContent = `COMBO x${G.combo}`;
  refreshShelf(); updateGift();
}
function coinBump() { const el = $('cashPill'); el.classList.remove('bump'); void el.offsetWidth; el.classList.add('bump'); $('cashN').textContent = save.cash; sfx('coin', { volume: 0.2 }); }
function coinTarget() { const r = $('cashPill').getBoundingClientRect(); return { x: (r.left + 24) / S, y: (r.top + r.height / 2) / S }; }
function show(id, on) { $(id).classList.toggle('hidden', !on); }
function setMuteIcons() { const m = !!save.muted; $('muteBtn').innerHTML = m ? ICON.speakerOff : ICON.speakerOn; $('titleMute').innerHTML = m ? ICON.speakerOff : ICON.speakerOn; for (const [id, on, label] of [['tMusic', !m, 'Music'], ['tSpeech', save.speech, 'Speech'], ['tVib', save.vib, 'Vibrate']]) { const b = $(id); b.classList.toggle('on', !!on); b.querySelector('span').textContent = `${label} ${on ? 'On' : 'Off'}`; } }
function toggleMute() { save.muted = !save.muted; try { music.setMuted(save.muted); } catch (e) { /* ignore */ } persist(); setMuteIcons(); }

// extras (shirts, looks, decor) ---------------------------------------------------------------------------
let exTab = 'shirts';
function drawMini(c, cfg) {
  const base = SKINS[cfg.skin] || SKINS.peach; const col = { base, light: shade(base, 0.4), mid: shade(base, 0.12), dark: shade(base, -0.28), out: shade(base, -0.42), belly: shade(base, 0.5) };
  const tw = 52, th = 54, R = 30; c.lineJoin = 'round'; c.lineCap = 'round'; c.save(); c.translate(0, 14); c.scale(0.74, 0.74);
  c.save(); c.translate(0, 28); if (cfg.back) drawBack(c, cfg.back, tw, th, 0, 0.5);
  rr(c, -tw / 2, -th / 2, tw, th, tw * 0.46); c.fillStyle = col.base; c.fill(); c.save(); c.clip(); c.fillStyle = col.belly; c.globalAlpha = 0.7; c.beginPath(); c.ellipse(0, 5, tw * 0.28, th * 0.28, 0, 0, TAU); c.fill(); c.globalAlpha = 1; if (cfg.shirt) drawShirt(c, cfg.shirt, tw, th); c.restore();
  rr(c, -tw / 2, -th / 2, tw, th, tw * 0.46); c.strokeStyle = col.out; c.lineWidth = 3.5; c.stroke(); if (cfg.neck) drawNeck(c, cfg.neck, tw, th); c.restore();
  c.save(); c.translate(0, -12);
  for (const s of [-1, 1]) { c.beginPath(); c.arc(s * R * 0.68, -R * 0.78, R * 0.3, 0, TAU); c.fillStyle = col.mid; c.fill(); c.strokeStyle = col.out; c.lineWidth = 3.5; c.stroke(); }
  c.beginPath(); c.arc(0, 0, R, 0, TAU); const g = c.createRadialGradient(-R * 0.35, -R * 0.4, 3, 0, 0, R * 1.1); g.addColorStop(0, col.light); g.addColorStop(0.5, col.base); g.addColorStop(1, col.dark); c.fillStyle = g; c.fill(); c.strokeStyle = col.out; c.lineWidth = 3.5; c.stroke();
  c.fillStyle = col.belly; c.beginPath(); c.ellipse(0, R * 0.32, R * 0.34, R * 0.25, 0, 0, TAU); c.fill();
  c.fillStyle = '#3a1d4a'; for (const s of [-1, 1]) { c.beginPath(); c.ellipse(s * R * 0.37, -R * 0.05, R * 0.12, R * 0.17, 0, 0, TAU); c.fill(); c.fillStyle = '#fff'; c.beginPath(); c.arc(s * R * 0.37 - 2, -R * 0.1, R * 0.05, 0, TAU); c.fill(); c.fillStyle = '#3a1d4a'; }
  c.strokeStyle = '#3a1d4a'; c.lineWidth = 2.5; c.beginPath(); c.moveTo(-R * 0.18, R * 0.38); c.quadraticCurveTo(0, R * 0.55, R * 0.18, R * 0.38); c.stroke();
  if (cfg.face) drawHead(c, cfg.face, R, 0); if (cfg.hat) drawHead(c, cfg.hat, R, 0); c.restore(); c.restore();
}
function openExtras(tab) { exTab = tab || exTab; G.paused = true; renderExtras(); show('extras', true); }
function closeExtras() { show('extras', false); G.paused = false; last = performance.now(); refreshShelf(); }
const OP = 12; // outfit price multiplier: extras cost much more than items
function renderExtras() {
  for (const t of document.querySelectorAll('.tab')) t.classList.toggle('on', t.dataset.t === exTab);
  $('exCash').innerHTML = `${ICON.cash}<span>${save.cash}</span>`;
  const g = $('grid'); g.innerHTML = '';
  const card = (canvas, name, state, cls, onTap) => { const d = document.createElement('div'); d.className = 'item ' + cls; d.appendChild(canvas); const n = document.createElement('div'); n.className = 'nm'; n.textContent = name; d.appendChild(n); const s = document.createElement('div'); s.className = 'st'; s.innerHTML = state; d.appendChild(s); d.onclick = () => onTap(d); g.appendChild(d); };
  const sec = (t) => { const s = document.createElement('div'); s.className = 'sec'; s.textContent = t; g.appendChild(s); };
  const status = (own, worn, price) => own ? (worn ? 'Wearing' : 'Wear') : `${ICON.cash}${price}`;
  const cls = (own, worn, price) => own ? (worn ? 'eq' : '') : (save.cash >= price ? 'buy' : 'cant');
  const gear = (title, slot, list, mul, cfgOf) => {
    sec(title);
    for (const [id, name, base] of list) {
      const price = base * mul, own = !!save.outfits[id] || price === 0, worn = save.equip[slot] === id;
      card(iconCanvas(76, (c) => drawMini(c, cfgOf(id))), name, status(own, worn, price), cls(own, worn, price), (d) => {
        if (own) { save.equip[slot] = (slot !== 'skin' && worn) ? null : id; persist(); sfx('squeak', { pitch: 1.3 }); renderExtras(); setEmo('happy', 1, true); }
        else if (pay(price, 'cash')) { save.outfits[id] = 1; save.equip[slot] = id; persist(); sfx('powerup'); sfx('sparkle'); renderExtras(); setEmo('laugh', 1.5, true); } else need(price, 'cash', d);
      });
    }
  };
  const eq = save.equip;
  if (exTab === 'shirts') gear('Shirts', 'shirt', SHIRTS, 1, (id) => ({ skin: eq.skin, shirt: id }));
  else if (exTab === 'looks') {
    gear('Fur colour', 'skin', OUTFITS.skins, OP / 2, (id) => ({ skin: id, shirt: eq.shirt })); gear('Hats', 'hat', OUTFITS.hat, OP, (id) => ({ skin: eq.skin, hat: id })); gear('Glasses', 'face', OUTFITS.face, OP, (id) => ({ skin: eq.skin, face: id }));
    gear('Neck', 'neck', OUTFITS.neck, OP, (id) => ({ skin: eq.skin, shirt: eq.shirt, neck: id })); gear('Back', 'back', OUTFITS.back, OP, (id) => ({ skin: eq.skin, shirt: eq.shirt, back: id }));
  } else {
    sec('Decor');
    for (const [id, name, price] of ROOMS) {
      const own = !!save.rooms[id]; const cvs = document.createElement('canvas'); const dd = 2; cvs.width = 140 * dd; cvs.height = 96 * dd; cvs.style.cssText = 'width:140px;height:96px;border-radius:16px;box-shadow:0 3px 0 #e3d3ea';
      const c = cvs.getContext('2d'); c.scale(dd * 140 / 640, dd * 96 / 440); c.save(); c.beginPath(); c.rect(0, 0, 640, 440); c.clip(); drawRoom(c, id, 640, 440, 360); c.restore();
      card(cvs, name, own ? (save.room === id ? 'Here!' : 'Go!') : `${ICON.cash}${price}`, own ? (save.room === id ? 'eq' : '') : (save.cash >= price ? 'buy' : 'cant'), (d) => {
        if (own) { setRoom(id); closeExtras(); } else if (pay(price, 'cash')) { save.rooms[id] = 1; persist(); sfx('powerup'); setRoom(id); renderExtras(); } else need(price, 'cash', d);
      });
    }
  }
}
function setRoom(id) { save.room = id; persist(); applyRoomPhysics(); bgKey = ''; sfx('whoosh'); puddles.length = 0; respawnBuddy(); }

// stats / daily / ko ---------------------------------------------------------------------------------------
function fmtTime(s) { s = Math.floor(s); const m = Math.floor(s / 60), h = Math.floor(m / 60); return h ? `${h}h ${m % 60}m` : m ? `${m}m ${s % 60}s` : `${s}s`; }
function openStats() {
  const s = save.stats; const rows = [['Total hits', s.hits], ['Cash earned', '$' + s.earned], ['Cash spent', '$' + s.spent], ['Time with Buddy', fmtTime(s.time)], ['Pea soup poured', s.peas], ['Knock-outs', s.ko], ['Items used', s.used], ['Best combo', 'x' + s.best], ['Level', save.level]];
  $('statRows').innerHTML = rows.map(([k, v]) => `<div class="srow"><span>${k}</span><b>${v}</b></div>`).join(''); show('stats', true);
}
const DAILY = [{ t: 'cash', v: 100, label: '$100' }, { t: 'gold', v: 2, label: '2 Gold' }, { t: 'item', v: 'claws', label: 'Paper Claws' }, { t: 'gold', v: 3, label: '3 Gold' }, { t: 'item', v: 'torch', label: 'Sparkly Torch' }];
const todayStr = () => { const d = new Date(); return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`; };
const claimable = () => save.daily.streak < 5 && save.daily.last !== todayStr();
function updateGift() { $('giftBtn').classList.toggle('hidden', !claimable()); }
function openDaily() {
  const st = save.daily.streak; const can = claimable();
  $('dayGrid').innerHTML = DAILY.map((d, i) => { const done = i < st, today = i === st && can; const ic = d.t === 'cash' ? ICON.cash : d.t === 'gold' ? ICON.gold : `<canvas data-it="${d.v}" width="96" height="96"></canvas>`; return `<div class="day ${done ? 'done' : ''} ${today ? 'today' : ''}"><b>Day ${i + 1}</b><div class="dic">${ic}</div><span>${d.label}</span>${done ? '<i>&#10003;</i>' : ''}</div>`; }).join('');
  for (const cvs of $('dayGrid').querySelectorAll('canvas')) { const c = cvs.getContext('2d'); c.translate(48, 48); c.scale(0.9, 0.9); drawItem(c, cvs.dataset.it); }
  $('dailyMsg').textContent = st >= 5 ? 'You got every daily gift. Wow!' : can ? 'Your gift is ready!' : 'Come back tomorrow for the next gift!';
  $('claimBtn').classList.toggle('hidden', !can); show('daily', true);
}
function claimDaily() {
  if (!claimable()) return; const d = DAILY[save.daily.streak]; save.daily.streak++; save.daily.last = todayStr();
  if (d.t === 'cash') { save.cash += d.v; } else if (d.t === 'gold') { save.gold += d.v; } else { save.items[d.v] = 1; }
  persist(); sfx('powerup'); sfx('sparkle'); burstConfetti(W / 2, H / 3, 60, 14); updateHud(); renderItems(); toast(`You got ${d.label}!`); openDaily();
}

// flow -------------------------------------------------------------------------------------------------------
function startGame() {
  music.unlock(); music.play(THEMES.toy, { intensity: 0.5 }); sfx('pop'); sfx('squeak');
  G.state = 'play'; show('title', false); $('hud').classList.remove('hidden'); $('shelfWrap').classList.remove('hidden'); $('trash').classList.remove('hidden'); $('hp').classList.remove('hidden');
  G.idleT = 0; updateHud(); const t = ITEM[G.item] && owned(ITEM[G.item]) ? G.item : 'bat'; selectItem(t);
  buddy.say = null; setTimeout(() => { if (G.state === 'play') say('Hi there! Be nice, okay?', true); }, 600);
  burstConfetti(W / 2, floorY - 200, 40, 12); if (claimable()) setTimeout(() => { if (G.state === 'play' && !G.paused) { G.paused = true; openDaily(); } }, 1800);
}
function pauseGame() { if (G.state !== 'play') return; G.paused = true; show('pause', true); music.setIntensity(0.15); sfx('click'); }
function resumeGame() { for (const id of ['pause', 'stats', 'daily']) show(id, false); G.paused = false; last = performance.now(); music.setIntensity(0.5); }
function resetSession() { G.ses = { hits: 0, best: 0, cash: 0 }; G.combo = 0; }
function showDone() {
  show('pause', false); const s = G.ses; $('sHits').textContent = s.hits; $('sCombo').textContent = s.best; $('sCash').textContent = '$' + s.cash;
  const stars = s.hits >= 40 ? 3 : s.hits >= 15 ? 2 : 1;
  $('bigStars').innerHTML = [0, 1, 2].map((i) => `<svg style="--i:${i}" viewBox="0 0 32 32"><path d="M16 3l3.8 8.2 8.9 1-6.6 6 1.9 8.8L16 22.5 8 27l1.9-8.8-6.6-6 8.9-1z" fill="${i < stars ? '#ffc83a' : '#e5d8ee'}" stroke="${i < stars ? '#c47d12' : '#c9b8d6'}" stroke-width="2" stroke-linejoin="round"/></svg>`).join('');
  $('doneMsg').textContent = stars === 3 ? 'Buddy is the happiest buddy ever!' : stars === 2 ? 'Buddy giggled a lot. So fun!' : 'Come back and play some more!';
  show('done', true); sfx('win'); burstConfetti(W / 2, H * 0.3, 60, 14); music.setIntensity(0.3);
}
function clearObjects() {
  for (const p of projs.slice()) killProj(p, false); for (const b of balloons.slice()) Composite.remove(world, [b.body, b.con]); balloons.length = 0; for (const p of pads.slice()) Composite.remove(world, p.body); pads.length = 0; ents.length = 0; bubbles.length = 0; fx.length = 0;
}
let trashT = 0;
function trashTap() {
  if (G.state !== 'play' || G.paused) return; const b = $('trash');
  if (!b.classList.contains('armed')) { b.classList.add('armed'); sfx('click'); toast('Tap the trash again to clear everything'); clearTimeout(trashT); trashT = setTimeout(() => b.classList.remove('armed'), 2200); return; }
  b.classList.remove('armed'); clearTimeout(trashT); clearObjects(); respawnBuddy(); sfx('whoosh'); sfx('pop'); burstSparks(W / 2, floorY - 120, 18, 8); G.combo = 0; updateHud();
}
function wire() {
  $('extrasBtn').innerHTML = ICON.hanger; $('giftBtn').innerHTML = ICON.gift; $('trash').innerHTML = ICON.trash; $('hpHeart').innerHTML = ICON.heart;
  $('playBtn').onclick = startGame; $('pauseBtn').onclick = pauseGame; $('resumeBtn').onclick = () => { sfx('click'); resumeGame(); };
  $('muteBtn').onclick = toggleMute; $('titleMute').onclick = () => { music.unlock(); toggleMute(); }; $('tMusic').onclick = toggleMute;
  $('tSpeech').onclick = () => { save.speech = !save.speech; persist(); setMuteIcons(); if (save.speech) say('Hello again!', true); };
  $('tVib').onclick = () => { save.vib = !save.vib; persist(); setMuteIcons(); vib(60); };
  $('pReset').onclick = () => { respawnBuddy(); clearObjects(); resumeGame(); sfx('pop'); };
  $('pDone').onclick = showDone; $('pStats').onclick = () => { openStats(); }; $('statsClose').onclick = () => show('stats', false);
  $('pDaily').onclick = () => { openDaily(); }; $('giftBtn').onclick = () => { sfx('click'); G.paused = true; openDaily(); }; $('claimBtn').onclick = claimDaily; $('dailyClose').onclick = () => { show('daily', false); if (!$('pause').classList.contains('hidden')) return; G.paused = false; last = performance.now(); };
  $('againBtn').onclick = () => { show('done', false); resetSession(); G.paused = false; last = performance.now(); music.setIntensity(0.5); clearObjects(); respawnBuddy(); updateHud(); };
  $('lvOk').onclick = () => { show('level', false); G.paused = false; last = performance.now(); sfx('coin'); burstConfetti(W / 2, H * 0.4, 40, 12); updateHud(); };
  $('extrasBtn').onclick = () => { sfx('click'); openExtras(); }; $('exClose').onclick = () => { sfx('click'); closeExtras(); };
  for (const t of document.querySelectorAll('.tab')) t.onclick = () => { exTab = t.dataset.t; sfx('click'); renderExtras(); };
  $('trash').onclick = trashTap;
  const koDone = (mult) => { const r = G.koReward * mult; earn(r); persist(); updateHud(); floatText('+$' + r, W / 2, floorY - 250, '#2fa84f', 46); burstConfetti(W / 2, H * 0.4, 50, 12); G.slow = 1; show('ko', false); G.paused = false; last = performance.now(); };
  $('koOk').onclick = () => { sfx('coin'); koDone(1); };
  $('koDbl').onclick = () => { $('koDbl').disabled = true; $('koDbl').classList.add('spin'); sfx('whoosh'); sfx('sparkle'); let n = 0; const iv = setInterval(() => { n++; $('koAmt').textContent = '+' + Math.round(G.koReward * (1 + Math.min(1, n / 8))); if (n >= 8) { clearInterval(iv); $('koTxt').textContent = 'DOUBLED!'; sfx('win'); setTimeout(() => koDone(2), 700); } }, 70); };
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' || e.key === 'p') { if (G.state === 'play') { if (!$('pause').classList.contains('hidden')) resumeGame(); else if (!G.paused) pauseGame(); } }
    if (G.state === 'play' && !G.paused && /^[0-9]$/.test(e.key)) { const own = ITEMS.filter((t) => t.cat === shelfCat && owned(t)); const t = own[(+e.key + 9) % 10]; if (t) selectItem(t.id); }
  });
  document.addEventListener('visibilitychange', () => { if (document.hidden && G.state === 'play' && !G.paused) pauseGame(); });
}
function buildLogo() {
  const mk = (txt, el, cols, off) => { el.innerHTML = ''; [...txt].forEach((ch, i) => { const s = document.createElement('span'); s.textContent = ch; const c = cols[(i + off) % cols.length]; s.style.setProperty('--c', c[0]); s.style.setProperty('--d', c[1]); s.style.setProperty('--i', i + off); el.appendChild(s); }); };
  const cols = [['#ff5d9e', '#b82f6a'], ['#ffd23f', '#c47d12'], ['#3ec6ff', '#1a6fb0'], ['#58d68d', '#1a8f50'], ['#b57bff', '#6a3fd4'], ['#ff9f43', '#b5601a']];
  mk('Buddy', document.querySelector('#logo .l1'), cols, 0); mk('Playground', document.querySelector('#logo .l2'), cols, 3);
}
function boot() {
  buildLogo(); resize(); applyRoomPhysics(); respawnBuddy(); buddy.emo = 'happy'; buildShelf(); wire(); setMuteIcons(); updateHud(); try { music.setMuted(!!save.muted); } catch (e) { /* ignore */ }
  requestAnimationFrame((t) => { last = t; frame(t); });
}
boot();
window.__bp = { burstConfetti, burstSparks, render, step(n = 1) { for (let i = 0; i < n; i++) { stepPhysics(); updateVisuals(1 / 60); } }, G, save, get buddy() { return buddy; }, selectItem, startGame, setRoom, music, get S() { return S; }, get W() { return W; }, get floorY() { return floorY; }, projs, pads, ents, fun, say, knockOut, openExtras, closeExtras, openStats, openDaily, claimable, trashTap, updateHud, renderItems, DAILY };
