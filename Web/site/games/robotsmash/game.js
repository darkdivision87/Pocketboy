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
  W = clamp(900 * aspect, 760, 1700); scale = cssW / W; H = cssH / scale;
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
  engine = Engine.create({ positionIterations: 8, velocityIterations: 6, constraintIterations: 5 });
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
  ['knL', 'tL', [0, 17], 'sL', [0, -17], 1.9], ['knR', 'tR', [0, 17], 'sR', [0, -17], 1.9],
];
const LAYOUT = { head: [0, -49, 'head'], torso: [0, 0, 'torso'], uL: [-38, -6, 'arm'], uR: [38, -6, 'arm'], fL: [-38, 29, 'fore'], fR: [38, 29, 'fore'], tL: [-14, 47, 'thigh'], tR: [14, 47, 'thigh'], sL: [-14, 84, 'shin'], sR: [14, 84, 'shin'] };
const DENS = { head: 0.0016, torso: 0.0024, arm: 0.0013, fore: 0.0013, thigh: 0.0014, shin: 0.0014 };
const STAND_H = 104; // torso center to sole
function spawnRobot(x, y, slot, old) {
  const r = { id: robotSeq++, slot, parts: {}, joints: [], stun: 0, stand: 0, frozen: 0, charge: 0, mood: 0, happy: 0, latched: old ? old.latched : false, down: 0, held: 0, ci: slot, spawnX: x };
  const group = -r.id; const cy = y || (floorY - STAND_H - 2);
  for (const k in LAYOUT) {
    const [dx, dy, kind] = LAYOUT[k], pd = PART[kind];
    const b = Bodies.rectangle(x + dx, cy + dy, pd.w, pd.h, { chamfer: { radius: Math.min(pd.w, pd.h) * 0.32 }, density: DENS[kind], friction: 0.7, frictionStatic: 0.08, frictionAir: 0.014, restitution: 0.22, collisionFilter: { group }, label: 'part' });
    b.plugin = { robot: r, kind, key: k }; r.parts[k] = b;
  }
  for (const [name, pa, pA, pb, pB, lim] of JOINTS) {
    const A = r.parts[pa], B = r.parts[pb];
    const c = Constraint.create({ bodyA: A, pointA: { x: pA[0], y: pA[1] }, bodyB: B, pointB: { x: pB[0], y: pB[1] }, length: 0, stiffness: 0.9, damping: 0.14 });
    r.joints.push({ name, c, A, B, lim, strain: 0, broken: false, rel: 0, freeAt: 0 });
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
