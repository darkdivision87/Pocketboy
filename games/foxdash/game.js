// Fox Dash: main game. Rendering, input, run logic, UI, missions, skins and music.
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { Maestro } from '../shared/maestro.js';
import { buildFox, buildRobot, SKINS, foxFaceSVG } from './fox.js';
import { World, Particles, BIOMES, biomeAt, LANE_W, TILE, BIOME_LEN, U } from './world.js';
import { Coins, ObstacleField, makePowerup, makeShadow } from './props.js';

const $ = (id) => document.getElementById(id);
const QS = new URLSearchParams(location.search);
const clamp = (x, a, b) => Math.min(b, Math.max(a, x));
const lerp = (a, b, t) => a + (b - a) * t;
const ease = (t) => t * t * (3 - 2 * t);

// ---------- save ----------
const SAVE_KEY = 'foxdash.v1';
let save = { best: 0, rings: 0, stars: 0, skin: 'classic', owned: ['classic'], missions: null, music: true, seenTut: 0 };
try { const s = JSON.parse(localStorage.getItem(SAVE_KEY) || 'null'); if (s) save = Object.assign(save, s); } catch (e) { /* ignore */ }
const persist = () => { try { localStorage.setItem(SAVE_KEY, JSON.stringify(save)); } catch (e) { /* ignore */ } };

// ---------- renderer ----------
const canvas = $('gl');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance' });
renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.05;
let pr = Math.min(window.devicePixelRatio || 1, 2);
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(60, 1, 0.1, 900);
let W = innerWidth, H = innerHeight;
const rt = new THREE.WebGLRenderTarget(W * pr, H * pr, { type: THREE.HalfFloatType, samples: pr >= 2 ? 0 : 4 });
const composer = new EffectComposer(renderer, rt);
composer.addPass(new RenderPass(scene, camera));
const bloom = new UnrealBloomPass(new THREE.Vector2(W, H), 0.3, 0.55, 0.88); composer.addPass(bloom);
composer.addPass(new OutputPass());
let useComposer = !QS.has('nobloom');

const world = new World(scene, renderer);
const glow = new Particles(scene, 700, true), soft = new Particles(scene, 500, false);
const coins = new Coins(scene), field = new ObstacleField(scene);
const fox = buildFox(); scene.add(fox.root);
const foxShadow = makeShadow(); scene.add(foxShadow);
const robot = buildRobot(); scene.add(robot.root); const robShadow = makeShadow(); robShadow.scale.set(2, 1, 2); scene.add(robShadow);
const bubble = new THREE.Mesh(new THREE.SphereGeometry(0.95, 20, 14), new THREE.MeshBasicMaterial({ color: new THREE.Color(0.5, 1.0, 1.5), transparent: true, opacity: 0.26, depthWrite: false, blending: THREE.AdditiveBlending }));
bubble.visible = false; scene.add(bubble);
// power-up pickups (small pool per kind)
const puPool = { magnet: [], shield: [], boost: [] };
for (const k in puPool) for (let i = 0; i < 3; i++) { const m = makePowerup(k); m.visible = false; scene.add(m); puPool[k].push(m); }
const pickups = [];

// ---------- audio ----------
const music = new Maestro(); let musicStarted = false;
music.muted = !save.music;
const sfx = (n, o) => { try { music.sfx(n, o); } catch (e) { /* ignore */ } };
function startMusic(theme, intensity) { try { music.unlock(); music.play(theme, { intensity }); musicStarted = true; } catch (e) { /* ignore */ } }

// ---------- state ----------
let mode = 'title', time = 0, last = performance.now();
const MAXDT = parseFloat(QS.get('maxdt')) || 0.05;
const p = { x: 0, y: 0, z: 0, vy: 0, lane: 0, grounded: true, rollT: 0, grind: null, sq: 0, coyote: 0, jumpBuf: 0, rollOnLand: false, rise: 0 };
const R = { v: 12, dist: 0, score: 0, rings: 0, boost: 0, magnet: 0, shield: 0, invuln: 0, stumbleT: 0, hurtT: 0, meter: 0, combo: 0, comboT: 0, deadT: 0, jumps: 0, rolls: 0, grinds: 0, pups: 0, dashes: 0, ramps: 0, startT: 0, biome: 0, stars0: 0, newBest: false, sinceTut: 0, onRamp: false };
let genZ = 0, segCount = 0, lastPU = 0, lastIdx = -999, shake = 0, fovK = 0, camA = 0, shiftX = 0, shiftY = 0, shopFrom = 'title', preview = 0, speedLine = 0;
const rob = { d: 3.4, dT: 3.4, x: 0, side: 1 };
const mult = () => 1 + 0.1 * Math.min(save.stars, 30);

// ---------- missions ----------
const MT = [
  { k: 'rings', t: (n) => `Collect ${n} rings`, base: 60, step: 25 }, { k: 'jumps', t: (n) => `Jump ${n} times`, base: 25, step: 10 },
  { k: 'rolls', t: (n) => `Roll ${n} times`, base: 12, step: 5 }, { k: 'dist', t: (n) => `Run ${n} m in one go`, base: 600, step: 250, run: 1 },
  { k: 'score', t: (n) => `Score ${n} in one run`, base: 2500, step: 1500, run: 1 }, { k: 'grinds', t: (n) => `Grind ${n} rails`, base: 2, step: 1 },
  { k: 'pups', t: (n) => `Grab ${n} power-ups`, base: 3, step: 2 }, { k: 'dashes', t: (n) => `Spin dash ${n} times`, base: 1, step: 1 },
  { k: 'ramps', t: (n) => `Launch off ${n} ramps`, base: 2, step: 1 },
];
function newMission(avoid) {
  const pool = MT.filter((m) => !avoid.includes(m.k)); const m = pool[(Math.random() * pool.length) | 0]; const tier = Math.floor(save.stars / 3);
  return { k: m.k, n: m.base + m.step * tier, p: 0 };
}
if (!save.missions || save.missions.length !== 3) { save.missions = []; for (let i = 0; i < 3; i++) save.missions.push(newMission(save.missions.map((m) => m.k))); }
const mdef = (k) => MT.find((m) => m.k === k);
function bump(k, n = 1, isMax = false) {
  for (let i = 0; i < save.missions.length; i++) {
    const m = save.missions[i]; if (m.k !== k) continue;
    m.p = isMax ? Math.max(m.p, n) : m.p + n;
    if (m.p >= m.n) {
      save.stars++; toast(mdef(k).t(m.n), 'Mission complete!'); sfx('win'); sfx('sparkle');
      const others = save.missions.filter((_, j) => j !== i).map((x) => x.k); save.missions[i] = newMission([...others, k]); persist();
      confetti(); updateStatsUI();
    }
  }
}

// ---------- HUD helpers ----------
const el = { score: $('score'), mult: $('mult'), dist: $('distv'), rings: $('rings'), ringBox: $('ringBox'), pups: $('pups'), dash: $('btnDash'), arc: $('dashArc'), banner: $('banner'), toasts: $('toasts'), tut: $('tut'), flash: $('flash') };
const ICONS = {
  magnet: '<svg viewBox="0 0 24 24"><path d="M4 3h5v9a3 3 0 0 0 6 0V3h5v9a8 8 0 0 1-16 0z" fill="#ff4d5e"/><path d="M4 3h5v4H4zM15 3h5v4h-5z" fill="#e8eef5"/></svg>',
  shield: '<svg viewBox="0 0 24 24"><path d="M12 2 4 5v6c0 5 3.500 9 8 11 4.500-2 8-6 8-11V5z" fill="#4fc3ff"/><path d="M12 5 7 7v4c0 3.500 2 6 5 7.500z" fill="#c8f0ff"/></svg>',
  boost: '<svg viewBox="0 0 24 24"><path d="M13.500 1 4 13.500h6L8.500 23 20 9.500h-6.500z" fill="#ffe14a"/></svg>',
};
const puEls = {}; const COL = { magnet: '#ff4d5e', shield: '#4fc3ff', boost: '#ffe14a' };
for (const k of ['boost', 'shield', 'magnet']) { const d = document.createElement('div'); d.className = 'pu'; d.style.setProperty('--c', COL[k]); d.innerHTML = '<i></i>' + ICONS[k]; d.style.display = 'none'; el.pups.appendChild(d); puEls[k] = d; }
const STAR = '<svg viewBox="0 0 32 32" width="30" height="30"><path d="M16 3l4 8.500 9 1.200-6.600 6.400 1.700 9.100L16 23.800 7.900 28.200l1.700-9.100L3 12.700l9-1.200z" fill="#ffd23f" stroke="#c77a10" stroke-width="1.500" stroke-linejoin="round"/></svg>';
function toast(text, head) {
  const d = document.createElement('div'); d.className = 'toast txt'; d.innerHTML = STAR + `<div><div style="font-size:.8em;opacity:.9">${head || ''}</div>${text}</div>`; el.toasts.appendChild(d); setTimeout(() => d.remove(), 3300);
}
function banner(big, small) { const b = el.banner; b.innerHTML = `<small>${small || ''}</small>${big}`; b.classList.remove('show'); void b.offsetWidth; b.classList.add('show'); }
const cache = {}; const setT = (e, k, v) => { if (cache[k] !== v) { cache[k] = v; e.textContent = v; } };
const RING_SVG = '<svg viewBox="0 0 32 32" width="26" height="26" style="display:inline-block;vertical-align:-6px"><circle cx="16" cy="16" r="10" fill="none" stroke="#ff9a00" stroke-width="7"/><circle cx="16" cy="16" r="10" fill="none" stroke="#ffd23f" stroke-width="4"/></svg>';
function updateStatsUI() {
  $('tBest').textContent = save.best.toLocaleString(); $('tRings').textContent = save.rings.toLocaleString(); $('sRings').textContent = save.rings.toLocaleString();
  $('tStars').innerHTML = `${STAR}<span>${save.stars}</span>`;
  $('missList').innerHTML = save.missions.map((m) => `<div class="m txt"><span>${mdef(m.k).t(m.n)}</span><span>${Math.min(m.p, m.n)}/${m.n}</span><div class="bar"><b style="width:${clamp(m.p / m.n, 0, 1) * 100}%"></b></div></div>`).join('');
}
const SPK_ON = '<svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 4V5L7 9zM15.500 8.500a5 5 0 0 1 0 7M18 6a8.500 8.500 0 0 1 0 12" stroke="currentColor" stroke-width="2" fill="currentColor" stroke-linecap="round"/></svg>';
const SPK_OFF = '<svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 4V5L7 9zM16 9l6 6M22 9l-6 6" stroke="currentColor" stroke-width="2.200" fill="currentColor" stroke-linecap="round"/></svg>';
function updateMute() { $('btnMute').innerHTML = save.music ? SPK_ON : SPK_OFF; $('btnMute2').innerHTML = (save.music ? SPK_ON : SPK_OFF) + (save.music ? 'Music on' : 'Music off'); }
function toggleMute() { save.music = !save.music; music.setMuted(!save.music); persist(); updateMute(); sfx('click'); }

// ---------- effects ----------
function burst(x, y, z, n, r, g, b, speed, size, life, grav, sys = glow) {
  for (let i = 0; i < n; i++) { const a = Math.random() * 6.283, e = Math.random() * 2 - 0.4, s = speed * (0.4 + Math.random() * 0.8); sys.emit(x, y, z, Math.cos(a) * s, e * s * 0.7 + speed * 0.2, Math.sin(a) * s, life * (0.6 + Math.random() * 0.6), size * (0.6 + Math.random() * 0.8), r, g, b, grav); }
}
function confetti() {
  const cols = [[1, 0.3, 0.4], [1, 0.8, 0.2], [0.3, 0.8, 1], [0.5, 1, 0.5], [0.8, 0.5, 1]];
  for (let i = 0; i < 46; i++) { const c = cols[i % 5]; soft.emit(p.x + (Math.random() - 0.5) * 2, p.y + 2.4, p.z - 1 - Math.random() * 3, (Math.random() - 0.5) * 6, 5 + Math.random() * 5, (Math.random() - 0.5) * 3 - 4, 1.6, 0.28, c[0], c[1], c[2], 9); }
}
const fx = $('fx'), fctx = fx.getContext('2d'); const lines = []; for (let i = 0; i < 44; i++) lines.push({ a: Math.random() * 6.283, r: Math.random(), s: 0.6 + Math.random() * 0.8 });
let fxDirty = false;
function drawLines(dt, k) {
  if (k < 0.02) { if (fxDirty) { fctx.clearRect(0, 0, fx.width, fx.height); fxDirty = false; } return; }
  fxDirty = true; fctx.clearRect(0, 0, fx.width, fx.height); const cx = fx.width / 2, cy = fx.height * 0.46, R0 = Math.hypot(cx, cy);
  fctx.lineCap = 'round';
  for (const l of lines) {
    l.r += dt * l.s * (0.9 + k * 1.6); if (l.r > 1) { l.r = 0.05 + Math.random() * 0.1; l.a = Math.random() * 6.283; l.s = 0.6 + Math.random() * 0.8; }
    const r0 = (0.28 + l.r * 0.75) * R0, r1 = r0 + (0.1 + 0.25 * k) * R0 * l.r, c = Math.cos(l.a), s = Math.sin(l.a);
    fctx.strokeStyle = `rgba(255,255,255,${(0.1 + 0.4 * k) * l.r})`; fctx.lineWidth = (1 + 3 * l.r) * pr;
    fctx.beginPath(); fctx.moveTo(cx + c * r0, cy + s * r0); fctx.lineTo(cx + c * r1, cy + s * r1); fctx.stroke();
  }
}

// ---------- resize ----------
let portrait = false, camDist = 6.5, camH = 3.5, baseFov = 60;
function resize() {
  W = innerWidth; H = innerHeight; portrait = H > W * 1.05; const a = W / H;
  renderer.setPixelRatio(pr); renderer.setSize(W, H, false); composer.setPixelRatio(pr); composer.setSize(W, H);
  fx.width = Math.round(W * Math.min(pr, 1.5)); fx.height = Math.round(H * Math.min(pr, 1.5));
  camera.aspect = a;
  if (a >= 1.25) { baseFov = 60; camDist = 5.7; camH = 3.1; }
  else { const need = clamp((1.25 - a) / 0.8, 0, 1); camDist = 5.7 + need * 5.5; camH = 3.1 + need * 2.6; const t = 4.9 / camDist; baseFov = Math.min(88, 2 * Math.atan(t / a) * 180 / Math.PI); }
  camera.fov = baseFov; camera.updateProjectionMatrix();
}
addEventListener('resize', resize); addEventListener('orientationchange', () => setTimeout(resize, 200));
if (window.visualViewport) window.visualViewport.addEventListener('resize', resize);

// ---------- generation ----------
const lx = (l) => l * LANE_W;
function ringsLine(l, z, n, y = 0.78, step = 1.9) { for (let i = 0; i < n; i++) coins.add(lx(l), y, z - i * step); }
function ringsArc(l, z, n, peak, step = 1.8) { for (let i = 0; i < n; i++) { const t = n > 1 ? i / (n - 1) : 0; coins.add(lx(l), 0.78 + peak * 4 * t * (1 - t), z - i * step); } }
const shuffled = () => { const a = [-1, 0, 1]; for (let i = 2; i > 0; i--) { const j = (Math.random() * (i + 1)) | 0; [a[i], a[j]] = [a[j], a[i]]; } return a; };
function ob(type, l, z) { return field.spawn(type, lx(l), z, biomeAt(z)); }
function addPickup(kind, x, y, z) { const m = puPool[kind].find((q) => !q.visible); if (!m) return; m.visible = true; pickups.push({ kind, x, y, z, m }); }
function genSegment() {
  const d = clamp(-genZ / 3500, 0, 1), z0 = genZ; let len = 18; const ls = shuffled(); segCount++;
  const easy = segCount <= 3; const r = Math.random();
  if (easy) {
    if (segCount === 1) ringsLine(0, z0 - 4, 8); else if (segCount === 2) { ringsLine(ls[0], z0 - 3, 7); ob('low', ls[1], z0 - 8); ob('low', ls[2], z0 - 8); ringsArc(ls[0], z0 - 3, 1, 0); } else { ob('low', ls[0], z0 - 8); ringsArc(ls[0], z0 - 3, 8, 2.1, 1.6); ringsLine(ls[1], z0 - 3, 6); }
    len = 16;
  } else if (segCount - lastPU >= 9) {
    lastPU = segCount; const kind = ['magnet', 'shield', 'boost'][(Math.random() * 3) | 0]; addPickup(kind, lx(ls[0]), 0.95, z0 - 6); ringsLine(ls[0], z0 - 10, 5); ringsLine(ls[1], z0 - 3, 6); len = 14;
  } else if (r < 0.2) { // ring trail
    const n = 9 + ((Math.random() * 5) | 0); let l = ls[0]; for (let i = 0; i < n; i++) { if (i % 4 === 0 && i) l = clamp(l + (Math.random() < 0.5 ? -1 : 1), -1, 1); coins.add(lx(l), 0.78, z0 - 3 - i * 1.9); } len = n * 1.9 + 6;
  } else if (r < 0.38) { // low hurdles
    const k = 1 + (Math.random() < 0.25 + 0.4 * d ? (Math.random() < 0.5 ? 1 : 2) : 0); for (let i = 0; i < 3; i++) { if (i < k) { ob('low', ls[i], z0 - 7); ringsArc(ls[i], z0 - 2, 7, 2.1, 1.6); } else ringsLine(ls[i], z0 - 3, 6); } len = 15;
  } else if (r < 0.5) { // roll-under gates
    const k = 1 + (Math.random() < 0.25 + 0.4 * d ? (Math.random() < 0.5 ? 1 : 2) : 0); for (let i = 0; i < 3; i++) { if (i < k) { ob('high', ls[i], z0 - 7); ringsLine(ls[i], z0 - 3, 6, 0.4, 1.4); } else ringsLine(ls[i], z0 - 3, 6); } len = 15;
  } else if (r < 0.64) { // blocks
    const k = 1 + (Math.random() < 0.3 + 0.5 * d ? 1 : 0); for (let i = 0; i < 3; i++) { if (i < k) ob('block', ls[i], z0 - 9); else { ringsLine(ls[i], z0 - 3, 8); if (d > 0.35 && i === 1 && Math.random() < 0.5) ob('low', ls[i], z0 - 16); } } len = 19;
  } else if (r < 0.76) { // mixed
    let blocks = 0; for (let i = 0; i < 3; i++) { const q = Math.random(); let t = q < 0.3 ? null : q < 0.55 ? 'low' : q < 0.75 ? 'high' : 'block'; if (t === 'block' && (blocks >= 2 || i === 2 && blocks === 2)) t = 'low'; if (t === 'block') blocks++; if (i === 2 && blocks === 2 && !t) t = null; if (t) ob(t, ls[i], z0 - 7); else ringsLine(ls[i], z0 - 3, 6); } len = 15;
  } else if (r < 0.86) { // ramp + rooftop platform, or ramp launch
    const l = ls[0], zc = z0 - 5.5, ramp = ob('ramp', l, zc);
    if (Math.random() < 0.55) { const plat = ob('plat', l, ramp.zMin - 6); ringsLine(l, ramp.zMin - 1.5, 6, 1.8 + 0.78, 1.8); len = 25; void plat; }
    else { ringsArc(l, ramp.zMin - 1.5, 9, 2.7, 2.0); ringsArc(l, ramp.zMin - 1.5, 0, 0); len = 26; }
    ringsLine(ls[1], z0 - 3, 8); if (Math.random() < 0.5) ob('low', ls[2], z0 - 9); else ringsLine(ls[2], z0 - 3, 8);
  } else { // rail grind
    const l = ls[0], rail = ob('rail', l, z0 - 12); ob('low', l, rail.zMax + 3.5);
    for (let i = 0; i < 8; i++) coins.add(lx(l), 1.39 + 0.62, rail.zMax - 2.2 - i * 2.0);
    ringsLine(ls[1], z0 - 3, 8); if (d > 0.2 && Math.random() < 0.6) ob('low', ls[2], z0 - 10); else ringsLine(ls[2], z0 - 3, 7); len = 24;
  }
  genZ -= len + lerp(11, 7, d);
}

// ---------- run control ----------
const wipe = document.createElement('div'); wipe.style.cssText = 'position:fixed;inset:0;background:#fff;opacity:0;pointer-events:none;transition:opacity .35s;z-index:50'; document.body.appendChild(wipe);
function doWipe() { wipe.style.transition = 'none'; wipe.style.opacity = '0.9'; void wipe.offsetWidth; wipe.style.transition = 'opacity .5s'; wipe.style.opacity = '0'; }
function resetWorldAt(z) { p.z = z; world.ensure(p.z); lastIdx = Math.floor(-p.z / TILE); }
function setMode(m) { mode = m; document.body.dataset.s = m; }
function startRun() {
  doWipe(); coins.clear(); field.clear(); for (const q of pickups) q.m.visible = false; pickups.length = 0;
  resetWorldAt(0); Object.assign(p, { x: 0, y: 0, vy: 0, lane: 0, grounded: true, rollT: 0, grind: null, sq: 0, coyote: 0, jumpBuf: 0, rollOnLand: false, rise: 0 });
  Object.assign(R, { v: 12, dist: 0, score: 0, rings: 0, boost: 0, magnet: 0, shield: 0, invuln: 0.5, stumbleT: 0, hurtT: 0, meter: 0, combo: 0, comboT: 0, deadT: 0, jumps: 0, rolls: 0, grinds: 0, pups: 0, dashes: 0, ramps: 0, startT: 0, biome: 0, newBest: false, sinceTut: 0 });
  rob.d = 3.2; rob.dT = 3.0; rob.x = 1.7; genZ = -52; segCount = 0; lastPU = 0; fox.roll = 0;
  while (genZ > p.z - 190) genSegment();
  setMode('play'); camA = Math.min(camA, 0.0); if (!musicStarted || true) startMusic('sunny', 0.35);
  el.tut.classList.toggle('on', save.seenTut < 2); R.tutShown = save.seenTut < 2; sfx('whoosh'); banner('GO!', 'Sunny Meadow'); R.biomeName = 0;
  fox.setSkin(SKINS.find((s) => s.id === save.skin) || SKINS[0]);
}
function toTitle() { doWipe(); coins.clear(); field.clear(); for (const q of pickups) q.m.visible = false; pickups.length = 0; resetWorldAt(0); p.x = 0; p.y = 0; p.lane = 0; fox.roll = 0; rob.d = 3.6; setMode('title'); updateStatsUI(); startMusic('sunny', 0.3); R.boost = R.magnet = R.shield = 0; bubble.visible = false; }
function pause() { if (mode !== 'play') return; setMode('pause'); try { music.pause(); } catch (e) { /* ignore */ } sfx('click'); }
function resume() { if (mode !== 'pause') return; setMode('play'); try { music.resume(); } catch (e) { /* ignore */ } sfx('click'); last = performance.now(); }
function addScore(n) { R.score += n * mult(); }
function die() {
  if (R.deadT > 0) return; R.deadT = 0.001; sfx('hit'); sfx('lose'); try { music.stop(0.6); } catch (e) { /* ignore */ }
  shake = 1.2; fox.tumbleT0 = fox.t; el.flash.classList.add('on'); setTimeout(() => el.flash.classList.remove('on'), 60); rob.dT = 1.6;
  burst(p.x, p.y + 0.8, p.z, 26, 1, 0.8, 0.3, 7, 0.45, 0.8, 8); el.tut.classList.remove('on');
}
function stumble() {
  R.stumbleT = 7; R.invuln = 1.2; R.hurtT = 0.5; R.v *= 0.55; rob.d = 2.1; rob.dT = 2.1; shake = Math.max(shake, 0.7); sfx('hurt'); R.combo = 0;
  el.flash.classList.add('on'); setTimeout(() => el.flash.classList.remove('on'), 80); p.sq = -0.8; burst(p.x, p.y + 0.7, p.z, 14, 1, 0.9, 0.4, 5, 0.4, 0.6, 8);
}
function breakObstacle(o) {
  o.hit = true; field.release(o); const bx = o.x, bz = (o.zMin + o.zMax) / 2; sfx('boom', { volume: 0.5 });
  const c = [[1, 0.7, 0.3], [1, 0.4, 0.7], [0.4, 0.9, 1]][biomeAt(bz)]; burst(bx, 1.0, Math.max(o.zMin, Math.min(o.zMax, p.z)), 22, c[0], c[1], c[2], 8, 0.5, 0.7, 10); burst(bx, 1.0, p.z, 8, 1, 1, 1, 6, 0.4, 0.6, 10, soft);
  shake = Math.max(shake, 0.35); addScore(25);
}
function hitObstacle(o) {
  o.hit = true;
  if (R.boost > 0) { o.hit = false; breakObstacle(o); return; }
  if (R.shield > 0) { R.shield = 0; sfx('pop'); R.invuln = 1.4; o.hit = false; breakObstacle(o); burst(p.x, p.y + 0.9, p.z, 30, 0.4, 0.9, 1.3, 7, 0.4, 0.7, 0); return; }
  if (R.stumbleT > 0) die(); else stumble();
}
function startBoost(dur = 4.2) {
  R.boost = dur; R.invuln = Math.max(R.invuln, dur + 0.8); R.meter = 0; R.dashes++; bump('dashes'); sfx('powerup'); sfx('whoosh'); try { music.duck(0.6, 0.3); } catch (e) { /* ignore */ }
  shake = Math.max(shake, 0.4); if (p.rollT > 0) p.rollT = 0; burst(p.x, p.y + 0.7, p.z, 28, 1, 0.7, 0.2, 6, 0.5, 0.5, 0);
}
function collectRing(x, y, z) {
  R.rings++; save.rings++; R.combo++; R.comboT = 0.6; R.meter = Math.min(1, R.meter + 0.04); addScore(10); bump('rings');
  sfx('coin', { pitch: 1 + Math.min(R.combo, 8) * 0.03, volume: 0.5 }); burst(x, y, z, 3, 1, 0.85, 0.2, 2.5, 0.35, 0.4, 0);
  el.ringBox.classList.remove('pop'); void el.ringBox.offsetWidth; el.ringBox.classList.add('pop');
}
function jump() {
  if (mode !== 'play' || R.deadT > 0) return;
  if (p.grounded || p.grind || p.coyote > 0) {
    p.vy = 13.2; p.grounded = false; p.grind = null; p.coyote = 0; p.rollT = 0; p.sq = 0.9; R.jumps++; bump('jumps'); sfx('jump', { volume: 0.7 });
    burst(p.x, p.y + 0.1, p.z, 6, 1, 1, 1, 3, 0.32, 0.4, 2, soft); R.sinceTut++;
  } else p.jumpBuf = 0.14;
}
function roll() {
  if (mode !== 'play' || R.deadT > 0) return;
  if (p.grounded || p.grind) { if (p.rollT <= 0) { R.rolls++; bump('rolls'); } p.rollT = 0.7; sfx('swish', { volume: 0.7 }); R.sinceTut++; }
  else { p.vy = Math.min(p.vy, -26); p.rollOnLand = true; sfx('swish', { volume: 0.5, pitch: 0.7 }); }
}
function lane(dir) {
  if (mode !== 'play' || R.deadT > 0) return; const n = clamp(p.lane + dir, -1, 1); if (n === p.lane) { shake = Math.max(shake, 0.12); return; }
  p.lane = n; sfx('swish', { volume: 0.5, pitch: 1.2 }); R.sinceTut++;
}

// ---------- play update ----------
const _v = new THREE.Vector3();
function baseSpeed(d) { return 14 + 20 * (1 - Math.exp(-d / 2600)); }
function playUpdate(dt) {
  const dead = R.deadT > 0;
  if (dead) { R.deadT += dt; R.v *= Math.exp(-dt * 2.5); if (R.deadT > 1.5 && mode === 'play') showOver(); }
  R.startT += dt;
  const z0 = p.z;
  let vt = baseSpeed(R.dist) * (R.boost > 0 ? 1.65 : 1) * (R.stumbleT > 5.8 ? 0.7 : 1) * (p.grind ? 1.1 : 1);
  if (R.startT < 2.5) vt = Math.min(vt, 12 + R.startT * 2); if (dead) vt = 0;
  if (!dead) R.v += (vt - R.v) * Math.min(1, dt * (vt > R.v ? 0.9 : 3));
  p.z -= R.v * dt; R.dist = -p.z;
  // lanes
  const tx = lx(p.lane); const dx = tx - p.x; p.x += dx * (1 - Math.exp(-dt * 15));
  const hb = p.rollT > 0 || R.boost > 0 ? 0.55 : 1.15;
  // vertical
  const dtv = Math.max(dt, 1e-4);
  if (p.grind) {
    const rail = field.railAt(p.x, p.z);
    if (!rail) { p.grind = null; p.grounded = false; p.vy = 0; } else { p.y = 1.39; if (Math.random() < 0.8) glow.emit(p.x + (Math.random() - 0.5) * 0.3, 1.4, p.z + 0.3, (Math.random() - 0.5) * 3, 2 + Math.random() * 3, 2 + Math.random() * 2, 0.4, 0.18, 1.4, 1, 0.4, 14); }
  }
  if (!p.grind) {
    const floor = field.floorAt(p.x, p.z, p.y);
    if (p.grounded) {
      if (floor < p.y - 0.06) { p.grounded = false; p.coyote = 0.1; p.vy = p.rise > 2.5 ? p.rise * 1.45 + 4.5 : 0; if (p.rise > 2.5) { R.ramps++; bump('ramps'); sfx('boing', { volume: 0.6 }); burst(p.x, p.y, p.z, 12, 1, 1, 1, 4, 0.5, 0.5, 4, soft); p.sq = 1; } p.rise = 0; }
      else { p.rise = (floor - p.y) / dtv; p.y = floor; }
    }
    if (!p.grounded) {
      p.coyote = Math.max(0, p.coyote - dt); p.vy -= 38 * dt; p.y += p.vy * dt;
      const rail = (p.vy <= 0 && !dead) ? field.railAt(p.x, p.z) : null;
      if (rail && p.y <= 1.9 && p.y >= 1.15) { p.grind = rail; p.y = 1.39; p.vy = 0; p.grounded = false; R.grinds++; bump('grinds'); sfx('sparkle'); p.rollT = 0; }
      else if (p.y <= floor && p.vy <= 0) {
        const fall = -p.vy; p.y = floor; p.vy = 0; p.grounded = true; p.sq = -clamp(fall / 16, 0.25, 1); if (fall > 6) { burst(p.x, p.y + 0.05, p.z, 6, 1, 1, 1, 3.5, 0.34, 0.45, 2, soft); if (fall > 9) sfx('step', { volume: 0.5 }); }
        if (p.rollOnLand) { p.rollOnLand = false; p.rollT = 0.6; R.rolls++; bump('rolls'); } if (p.jumpBuf > 0) { p.jumpBuf = 0; jump(); }
      }
    }
  }
  p.jumpBuf = Math.max(0, p.jumpBuf - dt); p.rollT = Math.max(0, p.rollT - dt); p.sq *= Math.exp(-dt * 9);
  // collisions
  R.invuln = Math.max(0, R.invuln - dt);
  if (!dead && R.invuln <= 0) { const o = field.crash(p.x, z0, p.z, p.y, hb); if (o) hitObstacle(o); }
  else if (!dead && R.boost > 0) { const o = field.crash(p.x, z0, p.z, p.y, hb + 0.6); if (o) breakObstacle(o); }
  if (R.deadT > 0) rob.dT = 1.7;
  // timers
  R.stumbleT = Math.max(0, R.stumbleT - dt); R.hurtT = Math.max(0, R.hurtT - dt); R.comboT -= dt; if (R.comboT < 0) R.combo = 0;
  if (R.boost > 0) { R.boost -= dt; if (R.boost <= 0) { R.boost = 0; R.invuln = Math.max(R.invuln, 0.9); sfx('whoosh', { pitch: 0.7 }); } }
  R.magnet = Math.max(0, R.magnet - dt); if (R.shield > 0) R.shield -= dt * 0.35;
  if (!dead) { addScore(R.v * dt); if (R.rings === 0 && 0) addScore(0); }
  // robot
  if (R.startT > 4 && R.stumbleT <= 0 && !dead) rob.dT = 16; rob.d += (rob.dT - rob.d) * Math.min(1, dt * 0.9); if (p.lane !== 0) rob.side = p.lane > 0 ? -1 : 1; rob.x += (p.x + (rob.side || 1) * 1.7 - rob.x) * Math.min(1, dt * 4);
  // rings
  const magnet = (R.magnet > 0 || R.boost > 0) && !dead;
  for (let n = coins.list.length - 1; n >= 0; n--) {
    const i = coins.list[n], cz = coins.z[i], dzc = cz - p.z;
    if (dzc > 14) { coins.remove(i); continue; }
    const cx = coins.x[i] - p.x, cy = coins.y[i];
    if (magnet && dzc < 0 && dzc > -14 && Math.abs(cx) < 7.5 && cy < p.y + 5) { coins.launch(i); continue; }
    if (!dead && Math.abs(dzc) < 1.0 && Math.abs(cx) < 1.05 && cy > p.y - 0.25 && cy < p.y + hb + 0.45) { collectRing(coins.x[i], cy, cz); coins.remove(i); }
  }
  const fl = coins.fl; _v.set(p.x, p.y + 0.7, p.z);
  for (let n = fl.length - 1; n >= 0; n--) {
    const f = fl[n]; f.t += dt; const dxf = _v.x - f.x, dyf = _v.y - f.y, dzf = _v.z - f.z, dd = Math.hypot(dxf, dyf, dzf) + 1e-4, sp = (R.v + 18 + f.t * 50) * dt;
    if (dd < 0.7 || dd < sp) { collectRing(f.x, f.y, f.z); coins.fly.setMatrixAt(f.slot, coins.zero); coins.ffree.push(f.slot); fl[n] = fl[fl.length - 1]; fl.pop(); coins.fdirty = true; continue; }
    f.x += dxf / dd * sp; f.y += dyf / dd * sp; f.z += dzf / dd * sp; coins.m4.makeTranslation(f.x, f.y, f.z); coins.fly.setMatrixAt(f.slot, coins.m4); coins.fdirty = true;
  }
  // pickups
  for (let n = pickups.length - 1; n >= 0; n--) {
    const q = pickups[n]; q.m.position.set(q.x, q.y + Math.sin(time * 3 + q.z) * 0.12, q.z); q.m.rotation.y = time * 2.2; q.m.children[0].scale.setScalar(1 + Math.sin(time * 5) * 0.08);
    if (q.m.userData.spin) q.m.userData.spin.rotation.y = -time * 3;
    if (q.z - p.z > 12) { q.m.visible = false; pickups.splice(n, 1); continue; }
    if (!dead && Math.abs(q.z - p.z) < 1.2 && Math.abs(q.x - p.x) < 1.2 && q.y > p.y - 0.8 && q.y < p.y + hb + 1) {
      q.m.visible = false; pickups.splice(n, 1); R.pups++; bump('pups'); sfx('powerup'); addScore(30); burst(q.x, q.y, q.z, 24, ...(q.kind === 'magnet' ? [1, 0.3, 0.4] : q.kind === 'shield' ? [0.3, 0.8, 1.2] : [1.2, 1, 0.3]), 6, 0.5, 0.7, 0);
      if (q.kind === 'magnet') R.magnet = 10; else if (q.kind === 'shield') R.shield = 18; else startBoost(3.6);
    }
  }
  // stats and bookkeeping
  field.recycle(p.z + 22);
  if (!dead) { bump('dist', Math.floor(R.dist), true); bump('score', Math.floor(R.score), true); }
  while (genZ > p.z - 190) genSegment();
  if (R.meter >= 1 && R.boost <= 0 && !el.dash.classList.contains('ready')) { el.dash.classList.add('ready'); sfx('sparkle'); }
  if (R.meter < 1 || R.boost > 0) el.dash.classList.remove('ready');
  // biome change
  const b = biomeAt(p.z);
  if (b !== R.biome) { R.biome = b; banner(BIOMES[b].name, 'Now entering'); sfx('whoosh'); startMusic(BIOMES[b].music, 0.5); confetti(); }
  try { music.setIntensity(clamp(0.28 + (R.v - 12) / 28 * 0.5 + (R.boost > 0 ? 0.25 : 0), 0.2, 1)); } catch (e) { /* ignore */ }
  if (R.tutShown && (R.sinceTut >= 5 || R.startT > 14)) { R.tutShown = false; el.tut.classList.remove('on'); save.seenTut++; persist(); }
  // fx
  if (R.boost > 0 && !dead) { for (let k = 0; k < 3; k++) glow.emit(p.x + (Math.random() - 0.5) * 0.6, p.y + 0.5 + Math.random() * 0.5, p.z + 0.4, (Math.random() - 0.5) * 2, Math.random() * 2, 5 + Math.random() * 6, 0.5, 0.45, 1.3, 0.8 + Math.random() * 0.5, 0.3, 0); }
  else if (!dead && p.grounded && R.v > 8 && Math.random() < dt * 18) soft.emit(p.x + (Math.random() - 0.5) * 0.5, p.y + 0.06, p.z + 0.5, (Math.random() - 0.5), 0.6 + Math.random(), 1.5, 0.45, 0.22, 1, 1, 1, 0);
  if (rob.d < 9) { if (Math.random() < dt * 40) glow.emit(rob.x + (Math.random() - 0.5) * 0.5, 0.35, p.z + rob.d + 0.9, (Math.random() - 0.5), -1, 3 + Math.random() * 3, 0.35, 0.4, 1.6, 0.8, 0.2, 0); }
  speedLine = lerp(speedLine, clamp((R.v - 17) / 18, 0, 1) * 0.55 + (R.boost > 0 ? 0.6 : 0), Math.min(1, dt * 3));
  // fox pose
  let md = 'run'; if (dead) md = 'tumble'; else if (R.boost > 0 || (p.rollT > 0 && !p.grounded)) md = 'spin'; else if (p.rollT > 0) md = 'roll'; else if (p.grind) md = 'grind'; else if (!p.grounded) md = 'jump';
  fox.update(dt, md, R.v, p.vy);
  placeFox(dt, tx, md);
  // hud
  setT(el.score, 's', Math.floor(R.score).toLocaleString()); setT(el.mult, 'm', 'x' + mult().toFixed(1)); setT(el.dist, 'd', Math.floor(R.dist) + ' m'); setT(el.rings, 'r', R.rings.toString());
  el.arc.setAttribute('stroke-dasharray', `${(R.boost > 0 ? R.boost / 3.6 : R.meter) * 302} 302`);
  const pp = { magnet: R.magnet / 10, shield: R.shield / 18, boost: R.boost / 4.2 };
  for (const k in puEls) { const on = pp[k] > 0; const e = puEls[k]; if (on !== (e.style.display !== 'none')) e.style.display = on ? 'grid' : 'none'; if (on) e.firstChild.style.setProperty('--p', (pp[k] * 100).toFixed(0)); }
}
function placeFox(dt, tx, md) {
  const r = fox.root; r.position.set(p.x, p.y, p.z); const dx = tx - p.x;
  r.rotation.y = -dx * 0.4; r.rotation.z = -dx * 0.22; if (md === 'tumble') { r.rotation.y = 0; r.rotation.z = 0; }
  const sy = 1 + p.sq * 0.3, sxz = 1 - p.sq * 0.18; r.scale.set(sxz, sy, sxz);
  r.visible = !(R.invuln > 0 && R.invuln < 3 && R.boost <= 0 && R.shield <= 0 && R.deadT <= 0 && Math.sin(time * 50) > 0.3);
  if (R.hurtT > 0) { r.rotation.z += Math.sin(time * 40) * 0.2 * R.hurtT; }
  const gy = (p.grounded || p.grind) ? p.y : field.floorAt(p.x, p.z, p.y); const hgt = Math.max(0, p.y - gy);
  foxShadow.position.set(p.x, gy + 0.03, p.z); foxShadow.scale.setScalar(1.5 * Math.max(0.4, 1 - hgt * 0.18)); foxShadow.visible = r.visible || true;
  bubble.visible = R.shield > 0; if (R.shield > 0) { bubble.position.set(p.x, p.y + 0.65, p.z); const s = 1 + Math.sin(time * 6) * 0.04; bubble.scale.set(s, s * 1.1, s); if (R.shield < 3 && Math.sin(time * 20) > 0) bubble.visible = false; }
}
function placeRobot(dt, spd) {
  robot.update(dt, spd); const vis = rob.d < 11; robot.root.visible = vis; robShadow.visible = vis; if (!vis) return;
  robot.root.scale.setScalar(0.88); robot.root.position.set(rob.x, 0, p.z + rob.d); robot.root.rotation.y = clamp((p.x - rob.x) * -0.2, -0.4, 0.4); robShadow.position.set(rob.x, 0.03, p.z + rob.d);
}

// ---------- camera ----------
const camPos = new THREE.Vector3(), camLook = new THREE.Vector3(), tmpA = new THREE.Vector3(), tmpB = new THREE.Vector3();
function updateCamera(dt) {
  const ta = mode === 'play' || mode === 'pause' ? 1 : 0; camA += (ta - camA) * Math.min(1, dt * 2.2); if (Math.abs(ta - camA) < 0.002) camA = ta;
  const e = ease(clamp(camA, 0, 1));
  const boost = R.boost > 0 ? 1 : 0; fovK += (boost - fovK) * Math.min(1, dt * 4);
  const cd = camDist + fovK * 1.4, ch = camH + clamp(p.y, 0, 3) * 0.5 + fovK * 0.3;
  let hx = 2.5, hy = 1.5, hz = -4.3, lyk = 1.0, lzk = 0.2;
  if (mode === 'shop') { hx = 1.9 + Math.sin(time * 0.5) * 0.6; hy = 1.25; hz = -3.4; lyk = 0.85; lzk = 0; }
  if (portrait && (mode !== 'play')) { hx *= 0.9; hz *= 1.25; hy += 0.3; }
  if (mode === 'over') { hx = portrait ? 4.2 : 5.6; hy = 2.0; hz = portrait ? 4.2 : 1.8; lyk = 0.8; lzk = -0.4; }
  tmpA.set(p.x + hx, hy, p.z + hz); tmpB.set(p.x * 0.6, ch, p.z + cd); camPos.copy(tmpA).lerp(tmpB, e); camPos.y += Math.sin(e * Math.PI) * 1.2;
  tmpA.set(p.x, lyk, p.z + lzk); tmpB.set(p.x * 0.7, 1.35 + p.y * 0.35, p.z - 9); camLook.copy(tmpA).lerp(tmpB, e);
  shake = Math.max(0, shake - dt * 2.4); const sh = shake * shake * 0.35;
  camera.position.set(camPos.x + (Math.random() - 0.5) * sh, camPos.y + (Math.random() - 0.5) * sh, camPos.z);
  camera.lookAt(camLook);
  if (mode === 'play') camera.rotation.z = clamp((p.x - lx(p.lane)) * 0.03, -0.1, 0.1) + (R.deadT > 0 ? 0 : 0);
  camera.fov = baseFov + fovK * 11; camera.updateProjectionMatrix();
  // shift the subject out from behind the menu panels
  let sx = 0, sy = 0; if (mode === 'title' || mode === 'over') { sx = portrait ? 0 : 0.2; sy = portrait ? 0.02 : 0; } else if (mode === 'shop') { sx = portrait ? 0 : -0.22; sy = portrait ? 0.2 : 0; }
  shiftX += (sx - shiftX) * Math.min(1, dt * 4); shiftY += (sy - shiftY) * Math.min(1, dt * 4);
  if (Math.abs(shiftX) > 0.001 || Math.abs(shiftY) > 0.001) camera.setViewOffset(W, H, -shiftX * W, shiftY * H, W, H); else camera.clearViewOffset();
  const tanH = Math.tan(camera.fov * Math.PI / 360); glow.uScale.value = soft.uScale.value = H * pr / (2 * tanH);
}

// ---------- title / over ----------
function idleUpdate(dt) {
  const v = mode === 'over' ? 0 : 9; R.v = v; p.z -= v * dt; const md = mode === 'over' ? 'tumble' : 'run';
  if (mode === 'title' || mode === 'shop') { fox.update(dt, 'run', 10); p.x = 0; p.y = 0; fox.root.position.set(0, 0, p.z); fox.root.rotation.set(0, mode === 'shop' ? Math.sin(time * 0.9) * 0.5 : 0, 0); fox.root.scale.setScalar(1); fox.root.visible = true; foxShadow.position.set(0, 0.03, p.z); foxShadow.scale.setScalar(1.5); rob.d += (3.4 - rob.d) * dt; rob.x = Math.sin(time * 1.3) * 0.5; }
  else { R.deadT += dt; fox.update(dt, md, 0); fox.root.position.set(p.x, 0, p.z); p.sq *= Math.exp(-dt * 9); rob.d += (1.5 - rob.d) * dt * 2; rob.x += (p.x - rob.x) * dt * 3; fox.root.visible = true; }
  if (mode === 'title' || mode === 'shop' || mode === 'over') speedLine = lerp(speedLine, 0, dt * 4);
}
function showOver() {
  const sc = Math.floor(R.score); R.newBest = sc > save.best; if (R.newBest) save.best = sc;
  bump('dist', Math.floor(R.dist), true); persist(); updateStatsUI(); setMode('over');
  $('oTitle').textContent = R.newBest ? 'New best!' : ['Oh no!', 'Bonk!', 'Caught!', 'So close!'][(Math.random() * 4) | 0];
  $('oScore').textContent = sc.toLocaleString(); const ob = $('oBest'); ob.textContent = R.newBest ? 'Amazing run!' : 'Best ' + save.best.toLocaleString(); ob.classList.toggle('new', R.newBest);
  $('oRings').textContent = R.rings; $('oDist').textContent = Math.floor(R.dist) + ' m'; $('oStars').textContent = save.stars; if (R.newBest) confetti();
  try { music.play(R.newBest ? 'victory' : 'calm', { intensity: 0.4 }); } catch (e) { /* ignore */ }
  R.deadT = 0.001; rob.dT = 1.5;
}

// ---------- shop ----------
function openShop(from) { shopFrom = from; preview = Math.max(0, SKINS.findIndex((s) => s.id === save.skin)); if (from === 'over') { doWipe(); coins.clear(); field.clear(); resetWorldAt(0); p.x = 0; p.y = 0; fox.roll = 0; } setMode('shop'); buildShop(); sfx('click'); }
function buildShop() {
  const g = $('skinGrid'); g.innerHTML = '';
  SKINS.forEach((s, i) => {
    const owned = save.owned.includes(s.id), d = document.createElement('button'); d.className = 'card txt' + (i === preview ? ' sel' : '') + (owned ? '' : ' locked');
    d.innerHTML = foxFaceSVG(s) + `<div>${s.name}</div>` + (owned ? `<div class="pr">${save.skin === s.id ? 'Equipped' : 'Owned'}</div>` : `<div class="pr">${RING_SVG.replace('26', '18').replace('26', '18')}${s.price}</div>`);
    d.onclick = () => { preview = i; fox.setSkin(s); sfx('click'); buildShop(); }; g.appendChild(d);
  });
  const s = SKINS[preview], owned = save.owned.includes(s.id), b = $('btnBuy'); fox.setSkin(s);
  if (owned) { b.textContent = save.skin === s.id ? 'Equipped' : 'Use this fox'; b.disabled = save.skin === s.id; } else { b.innerHTML = `Unlock ${RING_SVG}${s.price}`; b.disabled = save.rings < s.price; }
  $('sRings').textContent = save.rings.toLocaleString();
}
function buy() {
  const s = SKINS[preview];
  if (!save.owned.includes(s.id)) { if (save.rings < s.price) return; save.rings -= s.price; save.owned.push(s.id); sfx('powerup'); sfx('sparkle'); burst(0, 1, p.z, 30, 1, 0.9, 0.3, 6, 0.5, 0.8, 2); }
  save.skin = s.id; persist(); sfx('click'); buildShop(); updateStatsUI();
}
function closeShop() { fox.setSkin(SKINS.find((s) => s.id === save.skin) || SKINS[0]); if (shopFrom === 'over') { setMode('title'); updateStatsUI(); startMusic('sunny', 0.3); } else setMode('title'); sfx('click'); }

// ---------- input ----------
let ptr = null, unlocked = false;
function unlock() { if (unlocked) return; unlocked = true; try { music.unlock(); } catch (e) { /* ignore */ } if (mode === 'title' && !musicStarted) startMusic('sunny', 0.3); }
addEventListener('pointerdown', (e) => { unlock(); if (mode !== 'play' || e.target.closest('button,a')) return; ptr = { id: e.pointerId, x: e.clientX, y: e.clientY, t: performance.now(), moved: false }; });
addEventListener('pointermove', (e) => {
  if (!ptr || e.pointerId !== ptr.id) return; const dx = e.clientX - ptr.x, dy = e.clientY - ptr.y, th = Math.max(26, Math.min(W, H) * 0.04);
  if (Math.abs(dx) < th && Math.abs(dy) < th) return; ptr.moved = true;
  if (Math.abs(dx) > Math.abs(dy)) lane(dx > 0 ? 1 : -1); else if (dy < 0) jump(); else roll();
  ptr.x = e.clientX; ptr.y = e.clientY;
});
const endPtr = (e) => { if (ptr && e.pointerId === ptr.id) { if (!ptr.moved && performance.now() - ptr.t < 220 && e.type === 'pointerup') jump(); ptr = null; } };
addEventListener('pointerup', endPtr); addEventListener('pointercancel', endPtr);
addEventListener('keydown', (e) => {
  unlock(); if (e.repeat) return; const k = e.key;
  if (k === 'ArrowLeft' || k === 'a' || k === 'A') lane(-1); else if (k === 'ArrowRight' || k === 'd' || k === 'D') lane(1);
  else if (k === 'ArrowUp' || k === 'w' || k === 'W' || k === ' ') { if (mode === 'title') startRun(); else if (mode === 'over') startRun(); else jump(); e.preventDefault(); }
  else if (k === 'ArrowDown' || k === 's' || k === 'S') roll();
  else if (k === 'Shift' || k === 'e' || k === 'E') { if (mode === 'play' && R.meter >= 1 && R.boost <= 0 && !R.deadT) startBoost(); }
  else if (k === 'p' || k === 'P' || k === 'Escape') { if (mode === 'play') pause(); else if (mode === 'pause') resume(); }
  else if (k === 'Enter' && (mode === 'title' || mode === 'over')) startRun();
});
for (const ev of ['gesturestart', 'gesturechange', 'contextmenu', 'dblclick', 'selectstart']) document.addEventListener(ev, (e) => e.preventDefault(), { passive: false });
document.addEventListener('touchmove', (e) => e.preventDefault(), { passive: false });
let lastTouchEnd = 0; document.addEventListener('touchend', (e) => { const n = Date.now(); if (n - lastTouchEnd < 350) e.preventDefault(); lastTouchEnd = n; }, { passive: false });
document.addEventListener('visibilitychange', () => { if (document.hidden && mode === 'play') pause(); });
const on = (id, fn) => $(id).addEventListener('click', (e) => { unlock(); fn(e); });
on('btnPlay', () => { sfx('click'); startRun(); }); on('btnSkins', () => openShop('title')); on('btnMute', toggleMute); on('btnMute2', toggleMute);
on('btnPause', pause); on('btnResume', resume); on('btnRestart', () => { setMode('play'); try { music.resume(); } catch (e) { /* ignore */ } startRun(); });
on('btnQuit', () => { try { music.resume(); } catch (e) { /* ignore */ } toTitle(); }); on('btnAgain', () => { sfx('click'); startRun(); });
on('btnOSkins', () => openShop('over')); on('btnOTitle', () => { sfx('click'); toTitle(); }); on('btnShopBack', closeShop); on('btnBuy', buy);
on('btnDash', () => { if (mode === 'play' && R.meter >= 1 && R.boost <= 0 && !R.deadT) startBoost(); });

// ---------- bot (testing only: ?bot) ----------
const bot = { on: QS.has('bot'), fail: QS.has('botfail') };
function botThink() {
  if (!bot.on || mode !== 'play' || R.deadT > 0) return;
  const fz = (l) => { let best = 999, t = null; for (const o of field.list) { if (o.hit || o.type === 'rail' || Math.abs(o.x - lx(l)) > 1) continue; const dz = p.z - o.zMax; if (dz < -1 || dz > 60) continue; if (o.type === 'ramp' || o.type === 'plat') continue; if (dz < best) { best = dz; t = o; } } return { d: best, o: t }; };
  const res = [-1, 0, 1].map((l) => ({ l, ...fz(l) }));
  const cur = res[p.lane + 1];
  if (cur.o && cur.o.type === 'block' && cur.d < R.v * 1.1) { const alt = res.filter((r) => !(r.o && r.o.type === 'block' && r.d < 40) && Math.abs(r.l - p.lane) <= 1).sort((a, b) => b.d - a.d)[0] || res.filter((r) => Math.abs(r.l - p.lane) <= 1).sort((a, b) => b.d - a.d)[0]; if (alt && alt.l !== p.lane) lane(Math.sign(alt.l - p.lane)); }
  else if (cur.o && cur.o.type === 'low' && cur.d < R.v * 0.3 && cur.d > 0 && p.grounded && !bot.fail) jump();
  else if (cur.o && cur.o.type === 'high' && cur.d < R.v * 0.32 && cur.d > 0 && p.rollT <= 0 && !bot.fail) roll();
  if (R.meter >= 1 && R.boost <= 0) startBoost();
}

// ---------- main loop ----------
let ema = 16, slow = 0, lastT = 0;
function frame(now) {
  requestAnimationFrame(frame);
  const raw = Math.min(now - last, 500); last = now; const dt = Math.min(raw / 1000, MAXDT); if (dt <= 0) return;
  ema = ema * 0.95 + raw * 0.05;
  if (!QS.has('noadapt') && mode !== 'pause') { slow = ema > 26 ? slow + dt : Math.max(0, slow - dt); if (slow > 2.5) { slow = 0; if (pr > 1.01) { pr = Math.max(1, pr - 0.34); resize(); } else if (useComposer) useComposer = false; } }
  if (mode !== 'pause') {
    time += dt; world.ensure(p.z); const idx = Math.floor(-p.z / TILE);
    if (mode === 'play') { botThink(); playUpdate(dt); placeRobot(dt, R.v); } else { idleUpdate(dt); placeRobot(dt, 9); }
    if (idx !== lastIdx) lastIdx = idx;
    glow.update(dt); soft.update(dt); coins.flush(); U.uSpin.value = time * 3.2; fox.root.updateMatrixWorld();
    for (const k in puPool) { /* animated in playUpdate */ }
    updateCamera(dt); world.atmosphere(p.z, dt, camera, time);
    drawLines(dt, mode === 'play' ? speedLine : 0);
  }
  bloom.strength = world.bloom + (R.boost > 0 ? 0.3 : 0);
  if (useComposer) composer.render(); else renderer.render(scene, camera);
}

// ---------- boot ----------
resize(); world.ensure(0); lastIdx = 0; fox.setSkin(SKINS.find((s) => s.id === save.skin) || SKINS[0]);
updateStatsUI(); updateMute(); $('oStarsChip').title = 'Stars';
window.__fox = { music, p, R, rob, mode: () => mode, save, startRun, jump, roll, lane, bot, field, coins, world, die, pause, resume, showOver, startBoost, openShop, closeShop, teleport(d) { genZ = -d - 52; coins.clear(); field.clear(); resetWorldAt(-d); R.dist = d; while (genZ > p.z - 190) genSegment(); }, setStars(n) { save.stars = n; } };
requestAnimationFrame(frame);
