import * as THREE from 'three';
import { Maestro, THEMES } from '../shared/maestro.js';
import { COURSES } from './courses.js';
import { clamp, lerp, sstep, damp, mulberry, fmt, store } from './util.js';
import { SlidePath, HW, profileH, buildSlideMesh, layoutItems, buildSlideProps, buildPads } from './slide.js';
import { buildRider } from './rider.js';
import { World, blobTexture, rainbowArcGeo } from './world.js';
import { Particles, Post, SpeedLines } from './fx.js';
import { skyU } from './shaders.js';

const $ = (s) => document.querySelector(s);
const qs = new URLSearchParams(location.search);

// =================================================================== save data
const SAVE = 'skyslide.save.v1';
const DEF = { gems: 0, up: { speed: 0, wings: 0, magnet: 0, glide: 0 }, courses: {}, plays: 0, hints: { slide: 0, fly: 0 }, muted: false, last: 'island' };
const save = Object.assign({}, DEF, store(SAVE) || {});
save.up = Object.assign({}, DEF.up, save.up); save.hints = Object.assign({}, DEF.hints, save.hints); save.courses = save.courses || {};
const persist = () => store(SAVE, save);
const totalStars = () => Object.values(save.courses).reduce((a, c) => a + (c.stars || 0), 0);
const UPG = [
  { id: 'speed', name: 'Slide Speed', desc: 'Faster slide and a stronger launch', icon: 'i-bolt', c: ['#ffd54a', '#ff8f1c'] },
  { id: 'wings', name: 'Super Wings', desc: 'Bigger wings, mightier flaps and turns', icon: 'i-wing', c: ['#ff9ad0', '#ff3f8e'] },
  { id: 'magnet', name: 'Gem Magnet', desc: 'Pulls gems and balloons to you', icon: 'i-magnet', c: ['#8cf06a', '#1fae46'] },
  { id: 'glide', name: 'Glide Time', desc: 'Glide farther with extra flaps', icon: 'i-plane', c: ['#7fe0ff', '#1b8ef0'] }
];
const UCOST = [40, 90, 160, 260, 400];
const dayNum = Math.floor((Date.now() - new Date().getTimezoneOffset() * 60000) / 86400000);
const daySeed = dayNum % 997;
const dailyIdx = dayNum % COURSES.length;

// =================================================================== audio
const music = new Maestro(); music.muted = !!save.muted;
let audioOn = false, musicMode = 'none';
const slideTheme = (c) => Object.assign({}, THEMES.sunny, { root: c.music.root, bpm: c.music.bpm, seed: c.music.seed });
const menuTheme = (c) => Object.assign({}, THEMES.calm, { root: c.flightRoot, seed: c.music.seed + 9 });
const flightTheme = (c) => ({ bpm: 76, root: c.flightRoot, scale: 'lydian', prog: [0, 1, 4, 2], seventh: true, swing: 0.08, seed: c.music.seed + 3, drums: 'soft', hats: false, bass: 'sub', pad: true, arp: { pattern: [0, 2, 4, 6, 4, 2, 1, 3], wave: 'sine', oct: 1 }, lead: { wave: 'triangle', oct: 1, density: 0.42 }, bell: true, level: 0.85 });
function setMusic(mode, intensity) {
  if (!audioOn || musicMode === mode) return;
  musicMode = mode; const c = course || COURSES[0];
  try { music.play(mode === 'slide' ? slideTheme(c) : mode === 'flight' ? flightTheme(c) : menuTheme(c), { intensity }); music.duck(0.45, 0.7); } catch (e) { console.warn(e); }
}
function sfx(n, o) { if (audioOn) { try { music.sfx(n, o); } catch (e) { /* ignore */ } } }
function unlockAudio() { if (audioOn) return; try { music.unlock(); audioOn = true; } catch (e) { console.warn(e); } }
function setMute(m) {
  save.muted = m; persist(); music.setMuted(m);
  document.querySelectorAll('#btnMute use,#btnMuteT use,#btnMuteS use').forEach((u) => u.setAttribute('href', m ? '#i-mute' : '#i-snd'));
  $('#btnMusic span').textContent = 'Music: ' + (m ? 'Off' : 'On'); $('#btnMusic use').setAttribute('href', m ? '#i-mute' : '#i-snd');
}

// =================================================================== renderer / scene
const canvas = $('#gl');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance', stencil: false });
renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 0.92;
let pr = Math.min(window.devicePixelRatio || 1, 2); if (qs.get('pr')) pr = parseFloat(qs.get('pr'));
const prMax = pr; let adaptOn = !qs.has('fixed'); let raysOn = true;
renderer.setPixelRatio(pr); renderer.setSize(innerWidth, innerHeight);
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(58, innerWidth / innerHeight, 0.5, 7000);
const post = new Post(renderer, scene, camera, pr >= 1.75 ? 0 : 4);
const speedLines = new SpeedLines($('#lines'));
let W = innerWidth, H = innerHeight, baseFov = 58, camScale = 1;
function resize() {
  W = innerWidth; H = innerHeight; renderer.setPixelRatio(pr); renderer.setSize(W, H); post.setSize(W, H, pr);
  const a = W / H; camera.aspect = a; camScale = a < 1 ? 1.2 : 1;
  baseFov = a >= 1.2 ? 58 : Math.min(88, (2 * Math.atan(Math.tan(29 * Math.PI / 180) * 1.2 / a) * 180) / Math.PI);
  camera.fov = baseFov; camera.updateProjectionMatrix(); speedLines.resize(W, H);
}
addEventListener('resize', resize); addEventListener('orientationchange', () => setTimeout(resize, 120)); resize();

const world = new World(scene, camera);
const rider = buildRider(); rider.root.scale.setScalar(1.2); scene.add(rider.root);
const blob = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({ map: blobTexture(), transparent: true, depthWrite: false })); blob.renderOrder = 2; scene.add(blob);
const spray = new Particles(scene, 800, false), glow = new Particles(scene, 600, true);

// =================================================================== reusable temporaries
const V1 = new THREE.Vector3(), V2 = new THREE.Vector3(), V3 = new THREE.Vector3(), V4 = new THREE.Vector3();
const M4 = new THREE.Matrix4(), Q1 = new THREE.Quaternion(), Q2 = new THREE.Quaternion(), QZ = new THREE.Quaternion();
const AXZ = new THREE.Vector3(0, 0, 1), UPV = new THREE.Vector3(0, 1, 0);
const F = { p: new THREE.Vector3(), T: new THREE.Vector3(), R: new THREE.Vector3(), U: new THREE.Vector3() };
const camPos = new THREE.Vector3(0, 200, 0), camLook = new THREE.Vector3(), camUpV = new THREE.Vector3(0, 1, 0), tgt = new THREE.Vector3(), tgtLook = new THREE.Vector3();

// =================================================================== gem field (slide gems + flight gems)
class GemField {
  constructor(cap) {
    const g = new THREE.OctahedronGeometry(0.46, 0); g.scale(1, 1.5, 1);
    this.mat = new THREE.MeshBasicMaterial({ color: 0xffffff }); this.mat.color.setScalar(1.9);
    this.mesh = new THREE.InstancedMesh(g, this.mat, cap); this.mesh.frustumCulled = false; this.mesh.count = 0; this.mesh.setColorAt(0, new THREE.Color(1, 1, 1));
    scene.add(this.mesh); this.items = []; this.start = 0; this.cols = [new THREE.Color(), new THREE.Color()]; this.cap = cap;
  }
  setItems(arr) { this.items = arr; this.start = 0; arr.forEach((it, i) => { it.c = i % 2; }); }
  update(dt, t, key, px, py, pz, magnetR, collectR, onCollect, vis) {
    const it = this.items; while (this.start < it.length && it[this.start].s < key - 14) this.start++;
    let n = 0; const cr2 = collectR * collectR, mr2 = magnetR * magnetR * 6;
    for (let i = this.start; i < it.length && n < this.cap; i++) {
      const g = it[i]; if (g.s > key + vis) break; if (!g.alive) continue;
      let dx = px - g.x, dy = py - g.y, dz = pz - g.z; let d2 = dx * dx + dy * dy + dz * dz;
      if (magnetR > 0 && (g.fly || d2 < mr2)) { g.fly = 1; const k = Math.min(1, (10 + 26 * (1 - Math.min(1, d2 / (mr2 + 1)))) * dt); g.x += dx * k; g.y += dy * k; g.z += dz * k; dx = px - g.x; dy = py - g.y; dz = pz - g.z; d2 = dx * dx + dy * dy + dz * dz; }
      if (d2 < cr2) { g.alive = false; onCollect(g); continue; }
      V1.set(g.x, g.y + Math.sin(t * 3 + g.t) * 0.12, g.z); Q1.setFromAxisAngle(UPV, t * 2.4 + g.t); const sc = 1 + 0.08 * Math.sin(t * 6 + g.t);
      M4.compose(V1, Q1, V2.set(sc, sc, sc)); this.mesh.setMatrixAt(n, M4); this.mesh.setColorAt(n, this.cols[g.c]); n++;
    }
    this.mesh.count = n; this.mesh.instanceMatrix.needsUpdate = true; if (this.mesh.instanceColor) this.mesh.instanceColor.needsUpdate = true;
  }
  setColors(a, b) { this.cols[0].setHex(a); this.cols[1].setHex(b); }
}
const slideGems = new GemField(260), flightGems = new GemField(150);

// =================================================================== course management
let course = null, path = null, slideGroup = null, items = null, padInfo = null, bumperMesh = null, curId = null, D0 = new THREE.Vector3(0, 0, 1), RT = new THREE.Vector3(-1, 0, 0);
const stripeTex = (() => { const c = document.createElement('canvas'); c.width = 128; c.height = 64; const g = c.getContext('2d'); for (let i = 0; i < 8; i++) { g.fillStyle = i % 2 ? '#ffffff' : '#ff3d5a'; g.fillRect(i * 16, 0, 16, 64); } g.fillStyle = 'rgba(255,230,80,1)'; g.fillRect(0, 26, 128, 12); const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.wrapS = THREE.RepeatWrapping; return t; })();
const ZERO = new THREE.Matrix4().makeScale(0, 0, 0);

function disposeGroup(g) { g.traverse((o) => { if (o.geometry) o.geometry.dispose(); if (o.material && o.material.dispose) o.material.dispose(); if (o.dispose && o.isInstancedMesh) o.dispose(); }); scene.remove(g); }
function loadCourse(id) {
  if (curId === id && path) return;
  const c = COURSES.find((x) => x.id === id);
  if (slideGroup) disposeGroup(slideGroup);
  curId = id; course = c; save.last = id;
  path = new SlidePath(c, daySeed);
  D0.set(path.endT.x, 0, path.endT.z).normalize(); RT.set(-D0.z, 0, D0.x);
  slideGroup = new THREE.Group(); scene.add(slideGroup);
  slideGroup.add(buildSlideMesh(path, c));
  slideGroup.slideMesh = slideGroup.children[0];
  buildSlideProps(path, c, slideGroup);
  items = layoutItems(path, c, daySeed);
  padInfo = buildPads(path, items, slideGroup);
  // bumpers
  const bg = new THREE.SphereGeometry(0.85, 20, 14), bm = new THREE.MeshStandardMaterial({ map: stripeTex, roughness: 0.32, emissive: 0x401018, emissiveIntensity: 0.5 });
  bumperMesh = new THREE.InstancedMesh(bg, bm, Math.max(1, items.bumpers.length)); bumperMesh.frustumCulled = false;
  items.bumpers.forEach((b, i) => { path.surf(b.s, b.u, 0.78, V1); b.x = V1.x; b.y = V1.y; b.z = V1.z; b.m = new THREE.Matrix4().makeTranslation(V1.x, V1.y, V1.z); bumperMesh.setMatrixAt(i, b.m); });
  bumperMesh.count = items.bumpers.length; slideGroup.add(bumperMesh);
  slideGems.setItems(items.gems); slideGems.setColors(c.gem[0], c.gem[1]); flightGems.setColors(c.gem[0], c.gem[1]);
  rider.setWingColor(c.gem[1]);
  // world
  path.at(0, F); world.setCourse(c, D0, c.seed + daySeed);
  V1.copy(F.p); V1.y = 0; world.populate(V1, V2.set(F.T.x, 0, F.T.z).normalize());
  world.pillarFoam = path.pillars; world.addPillarFoam(path.pillars);
  resetRun(); camSnap = true;
}

// =================================================================== flight props (rings, balloons, rainbow gates, pools)
const flightGroup = new THREE.Group(); scene.add(flightGroup);
const ringGeo = new THREE.TorusGeometry(1, 0.15, 12, 44), ringMat = new THREE.MeshStandardMaterial({ color: 0xffd23f, emissive: 0xffa800, emissiveIntensity: 2.2, roughness: 0.3, metalness: 0.3 });
const starTex = (() => { const c = document.createElement('canvas'); c.width = c.height = 128; const g = c.getContext('2d'); const gr = g.createRadialGradient(64, 64, 0, 64, 64, 64); gr.addColorStop(0, 'rgba(255,240,160,.7)'); gr.addColorStop(0.7, 'rgba(255,200,60,.22)'); gr.addColorStop(1, 'rgba(255,200,60,0)'); g.fillStyle = gr; g.fillRect(0, 0, 128, 128); g.fillStyle = 'rgba(255,255,255,.9)'; g.beginPath(); for (let i = 0; i < 10; i++) { const r = i % 2 ? 14 : 30, a = -Math.PI / 2 + i * Math.PI / 5; g.lineTo(64 + Math.cos(a) * r, 64 + Math.sin(a) * r); } g.closePath(); g.fill(); return new THREE.CanvasTexture(c); })();
const ringGlowMat = new THREE.MeshBasicMaterial({ map: starTex, opacity: 0.5, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide });
const hoopGeo = rainbowArcGeo([0xff4d6d, 0xff9a3c, 0xffe14a, 0x4fe07a, 0x3fc4ff, 0x6a6bff, 0xc062ff], true);
const hoopMat = new THREE.MeshBasicMaterial({ vertexColors: true, transparent: true, opacity: 0.85, side: THREE.DoubleSide, depthWrite: false });
const rings = [], hoops = [], pools = [];
for (let i = 0; i < 10; i++) { const g = new THREE.Group(); const t = new THREE.Mesh(ringGeo, ringMat.clone()); t.material.transparent = true; g.add(t); const gl = new THREE.Mesh(new THREE.CircleGeometry(1.05, 24), ringGlowMat.clone()); g.add(gl); g.visible = false; flightGroup.add(g); rings.push({ g, t, gl, active: false, done: 0, r: 5, x: 0, y: 0, z: 0, f: 0 }); }
for (let i = 0; i < 3; i++) { const m = new THREE.Mesh(hoopGeo, hoopMat); m.visible = false; m.renderOrder = 4; flightGroup.add(m); hoops.push({ m, active: false, done: 0, r: 13, x: 0, y: 0, z: 0, f: 0 }); }
// pool target texture
const poolTex = (() => { const c = document.createElement('canvas'); c.width = c.height = 256; const g = c.getContext('2d'); const cols = ['#2fc8ff', '#ffffff', '#ff5f86', '#ffffff', '#ffd23f']; const rr = [128, 100, 72, 46, 22]; rr.forEach((r, i) => { g.fillStyle = cols[i]; g.beginPath(); g.arc(128, 128, r, 0, 7); g.fill(); }); g.strokeStyle = 'rgba(255,255,255,.9)'; g.lineWidth = 6; g.beginPath(); g.arc(128, 128, 124, 0, 7); g.stroke(); const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t; })();
const beaconTex = (() => { const c = document.createElement('canvas'); c.width = 4; c.height = 128; const g = c.getContext('2d'); const gr = g.createLinearGradient(0, 128, 0, 0); gr.addColorStop(0, 'rgba(255,255,255,.9)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.fillRect(0, 0, 4, 128); return new THREE.CanvasTexture(c); })();
for (let i = 0; i < 3; i++) {
  const g = new THREE.Group(); const disc = new THREE.Mesh(new THREE.CircleGeometry(1, 48).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ map: poolTex, transparent: true, opacity: 0.96 })); disc.position.y = 0.45; disc.renderOrder = 1; g.add(disc);
  const beam = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, 150, 12, 1, true), new THREE.MeshBasicMaterial({ map: beaconTex, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide, color: 0xffe28a })); beam.position.y = 75; g.add(beam);
  g.visible = false; flightGroup.add(g); pools.push({ g, disc, active: false, x: 0, z: 0, r: 22, f: 0 });
}
// balloons (instanced)
const balloons = []; let balloonMesh = null;
{
  const sp = new THREE.SphereGeometry(1.5, 14, 12); sp.scale(1, 1.22, 1);
  const kn = new THREE.ConeGeometry(0.28, 0.5, 6); kn.rotateX(Math.PI); kn.translate(0, -1.95, 0);
  const st = new THREE.CylinderGeometry(0.025, 0.025, 3.4, 4); st.translate(0, -3.7, 0);
  const parts = [sp, kn, st].map((g) => { const gg = g.index ? g.toNonIndexed() : g; gg.deleteAttribute('uv'); const n = gg.attributes.position.count, a = new Float32Array(n * 3).fill(g === st ? 0.9 : 1); gg.setAttribute('color', new THREE.BufferAttribute(a, 3)); return gg; });
  import('three/addons/utils/BufferGeometryUtils.js').then((m) => {
    const geo = m.mergeGeometries(parts, false);
    balloonMesh = new THREE.InstancedMesh(geo, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.25, metalness: 0.0, emissive: 0x333333, color: 0xffffff }), 48); balloonMesh.material.color.setScalar(1.5); balloonMesh.frustumCulled = false; balloonMesh.count = 0; balloonMesh.setColorAt(0, new THREE.Color(1, 1, 1)); flightGroup.add(balloonMesh);
  });
}
const BCOL = [0xff4d6d, 0xffd23f, 0x35e0ff, 0x6bff7a, 0xc062ff, 0xff8a2a].map((h) => new THREE.Color(h));

// =================================================================== state
let state = 'title', paused = false, timeScale = 1, time = 0;
const input = { steerRaw: 0, steerS: 0, down: false, downT: 0, anchorX: 0, curX: 0, moved: 0, kL: false, kR: false, kDive: false, flapQ: 0, holdActive: false, id: null, spaceT: 0 };
const sl = { s: 0, u: 0, uv: 0, v: 0, boost: 0, stun: 0, t: 0, gems: 0, shake: 0, sprayAcc: 0, glowAcc: 0, bumps: 0, wallT: 0 };
const fl = { x: 0, y: 0, z: 0, px: 0, py: 0, pz: 0, yaw: 0, th: 0, v: 0, bank: 0, lift: 0, dive: 0, flaps: 3, maxFlaps: 3, f: 0, l: 0, rings: 0, gems: 0, balloons: 0, t: 0, nextF: 0, guideY: 60, guideL: 0, skips: 0, ox: 0, oz: 0, launchY: 60, flapAnim: 0, maxY: 0, poolNext: 0, lastGemF: 0, chain: 0, hoops: 0, prevF: 0 };
const run = { gems: 0, score: 0, dist: 0, mult: 1, pool: null, poolZone: -1, stars: 0, beach: false, daily: false };
let landTimer = 0, flapCool = 0, hintTimer = 0, cdNum = 0, cdTimer = 0, orbitT = 0, menuLook = 0, menuSide = 0, frng = mulberry(1), launchSlow = 0, camBlend = 0;
let courseSel = save.last || 'island';

function resetRun() {
  if (!items) return;
  items.gems.forEach((g) => { g.alive = true; g.fly = 0; });
  // restore gem positions (magnet moves them)
  items.gems.forEach((g) => { if (g.ox === undefined) { g.ox = g.x; g.oy = g.y; g.oz = g.z; } else { g.x = g.ox; g.y = g.oy; g.z = g.oz; } });
  items.bumpers.forEach((b, i) => { b.hit = false; bumperMesh.setMatrixAt(i, b.m); }); bumperMesh.instanceMatrix.needsUpdate = true;
  items.pads.forEach((p) => { p.used = false; });
  slideGems.start = 0;
  Object.assign(sl, { s: 0, u: 0, uv: 0, v: 0, boost: 0, stun: 0, t: 0, gems: 0, shake: 0, bumps: 0 });
  run.gems = 0; run.score = 0; run.dist = 0; run.mult = 1; run.pool = null; run.beach = false;
  flightGems.items = []; flightGems.start = 0; balloons.length = 0;
  for (const r of rings) { r.active = false; r.g.visible = false; } for (const h of hoops) { h.active = false; h.m.visible = false; } for (const p of pools) { p.active = false; p.g.visible = false; }
  spray.clear(); glow.clear(); rider.open = 0; rider.root.visible = true;
}

// =================================================================== UI helpers
const el = { hud: $('#hud'), banner: $('#banner'), cd: $('#countdown'), hint: $('#hint'), hintText: $('#hintText'), hand: $('#hand'), slideBar: $('#slideBar'), slideFill: $('#slideFill'), slideDot: $('#slideDot'), distBox: $('#distBox'), distVal: $('#distVal'), mult: $('#multChip'), gemVal: $('#gemVal'), gemChip: $('#gemChip'), altBar: $('#altBar'), altFill: $('#altFill'), altDot: $('#altDot'), flaps: $('#flaps') };
const screens = { title: $('#title'), select: $('#select'), upgrades: $('#upgrades'), pause: $('#pause'), results: $('#results') };
function showScreen(n) { const s = screens[n]; s.classList.remove('hidden'); void s.offsetWidth; s.classList.remove('fade'); }
function hideScreen(n) { const s = screens[n]; if (s.classList.contains('hidden')) return; s.classList.add('fade'); setTimeout(() => { if (s.classList.contains('fade')) s.classList.add('hidden'); }, 360); }
function hideAll() { for (const k in screens) hideScreen(k); }
function banner(txt, color) { const b = el.banner; b.textContent = txt; b.style.color = color || '#fff'; b.classList.remove('show'); void b.offsetWidth; b.classList.add('show'); }
function toast(t) { const d = document.createElement('div'); d.className = 'toast'; d.textContent = t; document.body.appendChild(d); setTimeout(() => d.remove(), 1800); }
function refreshGems() { document.querySelectorAll('.gv').forEach((e) => { e.textContent = fmt(save.gems); }); }
const hudVals = { dist: -1, mult: -1, gems: -1, flaps: -1, maxFlaps: -1 };
function setHint(txt, hold) { el.hint.classList.remove('hidden'); el.hintText.textContent = txt; el.hand.className = hold ? 'hold' : ''; el.hand.id = 'hand'; el.hand.classList.toggle('hold', !!hold); }
function clearHint() { el.hint.classList.add('hidden'); }
function updateHud() {
  const g = run.gems; if (g !== hudVals.gems) { el.gemVal.textContent = fmt(g); hudVals.gems = g; el.gemChip.classList.remove('pop'); void el.gemChip.offsetWidth; el.gemChip.classList.add('pop'); }
  if (state === 'slide') { const p = clamp(sl.s / path.L, 0, 1); el.slideFill.style.width = `calc(${(p * 100).toFixed(1)}% - 8px)`; el.slideDot.style.left = `calc(${(p * 100).toFixed(1)}%)`; }
  if (state === 'flight' || state === 'landing') {
    const d = Math.floor(Math.max(0, fl.f)); if (d !== hudVals.dist) { el.distVal.textContent = fmt(d); hudVals.dist = d; }
    const m = Math.min(12, 1 + 0.5 * fl.rings); if (m !== hudVals.mult) { el.mult.textContent = 'x' + (m % 1 ? m.toFixed(1) : m); hudVals.mult = m; el.mult.classList.remove('pop'); void el.mult.offsetWidth; el.mult.classList.add('pop'); }
    const top = Math.max(140, fl.launchY * 1.6), a = clamp(fl.y / top, 0, 1); el.altFill.style.height = `calc(${(a * 100).toFixed(1)}% - 6px)`; el.altDot.style.bottom = `calc(${(a * 100).toFixed(1)}% - 15px)`;
    if (fl.flaps !== hudVals.flaps || fl.maxFlaps !== hudVals.maxFlaps) { hudVals.flaps = fl.flaps; hudVals.maxFlaps = fl.maxFlaps; let h = ''; for (let i = 0; i < fl.maxFlaps; i++) h += `<i class="${i < fl.flaps ? '' : 'off'}"></i>`; el.flaps.innerHTML = h; }
  }
}
function hudMode(m) { // 'none' | 'slide' | 'flight'
  el.hud.classList.toggle('hidden', m === 'none');
  el.slideBar.classList.toggle('hidden', m !== 'slide'); el.distBox.classList.toggle('hidden', m !== 'flight'); el.altBar.classList.toggle('hidden', m !== 'flight'); el.flaps.classList.toggle('hidden', m !== 'flight');
  $('#hudTL').classList.toggle('hidden', m === 'none');
  hudVals.dist = hudVals.mult = hudVals.gems = hudVals.flaps = -1;
}

// =================================================================== input
const interactive = (t) => t.closest && t.closest('button,a,.panel,#cards,.screen:not(#title)');
addEventListener('pointerdown', (e) => {
  unlockAudio();
  if (interactive(e.target) || !(state === 'slide' || state === 'flight' || state === 'countdown') || paused) return;
  if (input.id !== null) return;
  input.id = e.pointerId; input.down = true; input.downT = performance.now(); input.anchorX = input.curX = e.clientX; input.moved = 0;
});
addEventListener('pointermove', (e) => {
  if (e.pointerId !== input.id) return;
  input.moved += Math.abs(e.clientX - input.curX) + 0; input.curX = e.clientX;
  const range = Math.min(W, H) * 0.14; if (e.clientX - input.anchorX > range) input.anchorX = e.clientX - range; else if (input.anchorX - e.clientX > range) input.anchorX = e.clientX + range;
});
const endPtr = (e) => {
  if (e.pointerId !== input.id) return;
  const dur = performance.now() - input.downT;
  if (dur < 190 && input.moved < 26 && state === 'flight') input.flapQ = 1;
  input.id = null; input.down = false; input.holdActive = false;
};
addEventListener('pointerup', endPtr); addEventListener('pointercancel', endPtr);
addEventListener('blur', () => { input.id = null; input.down = false; input.holdActive = false; input.kL = input.kR = input.kDive = false; });
addEventListener('keydown', (e) => {
  if (e.repeat) return; unlockAudio();
  const k = e.key;
  if (k === 'ArrowLeft' || k === 'a' || k === 'A') input.kL = true; else if (k === 'ArrowRight' || k === 'd' || k === 'D') input.kR = true;
  else if (k === 'ArrowDown' || k === 's' || k === 'S') input.kDive = true;
  else if (k === 'ArrowUp' || k === 'w' || k === 'W') { if (state === 'flight') input.flapQ = 1; }
  else if (k === ' ') { input.spaceT = performance.now(); e.preventDefault(); }
  else if (k === 'Escape' || k === 'p' || k === 'P') { if (state === 'slide' || state === 'flight' || state === 'countdown') setPaused(!paused); }
  else if (k === 'Enter') { if (state === 'title') $('#btnPlay').click(); else if (state === 'select') $('#btnGo').click(); }
});
addEventListener('keyup', (e) => {
  const k = e.key;
  if (k === 'ArrowLeft' || k === 'a' || k === 'A') input.kL = false; else if (k === 'ArrowRight' || k === 'd' || k === 'D') input.kR = false;
  else if (k === 'ArrowDown' || k === 's' || k === 'S') input.kDive = false;
  else if (k === ' ') { if (performance.now() - input.spaceT < 190 && state === 'flight') input.flapQ = 1; input.spaceT = 0; }
});
function pollInput(dt) {
  let raw = 0;
  if (input.down) raw = clamp((input.curX - input.anchorX) / (Math.min(W, H) * 0.14), -1, 1);
  if (input.kL) raw -= 1; if (input.kR) raw += 1; raw = clamp(raw, -1, 1);
  if (bot.on) raw = bot.steer;
  input.steerS += (raw - input.steerS) * (1 - Math.exp(-11 * dt));
  const now = performance.now();
  input.holdActive = bot.on ? bot.dive : ((input.down && now - input.downT > 160 && input.moved < 400) || input.kDive || (input.spaceT > 0 && now - input.spaceT > 160));
  if (bot.on && bot.flap) { input.flapQ = 1; bot.flap = false; }
}

// =================================================================== camera helpers
let camSnap = true;
function setCam(dt, k) {
  if (camSnap) { camPos.copy(tgt); camLook.copy(tgtLook); camSnap = false; } else { camPos.lerp(tgt, 1 - Math.exp(-k * dt)); camLook.lerp(tgtLook, 1 - Math.exp(-k * 1.4 * dt)); }
  camera.position.copy(camPos);
  if (sl.shake > 0.001 || fl.shake > 0.001) { const s = Math.max(sl.shake, fl.shake || 0); camera.position.x += (Math.random() - 0.5) * s * 0.5; camera.position.y += (Math.random() - 0.5) * s * 0.5; camera.position.z += (Math.random() - 0.5) * s * 0.5; }
  camera.up.copy(camUpV); camera.lookAt(camLook);
}
function setFov(target, dt) { camera.fov = damp(camera.fov, target, 5, dt); camera.updateProjectionMatrix(); }

// rider pose helpers
const poseO = { mode: 'slide', lean: 0, dive: 0, flapping: 0, speed01: 0, t: 0, pitch: 0 };
function placeRiderSlide() {
  path.at(sl.s, F); const u = clamp(sl.u, -HW, HW);
  V1.copy(F.p).addScaledVector(F.R, u).addScaledVector(F.U, profileH(u));
  V2.copy(F.U).addScaledVector(F.R, -0.17 * u).normalize();             // surface normal
  V3.copy(F.T).addScaledVector(V2, -F.T.dot(V2)).normalize();           // forward in surface
  V4.crossVectors(V2, V3);                                              // x axis
  M4.makeBasis(V4, V2, V3); rider.root.quaternion.setFromRotationMatrix(M4);
  rider.root.position.copy(V1).addScaledVector(V2, 0.04 + Math.sin(sl.t * 9) * 0.01);
  // blob
  M4.makeBasis(V4, V3, V2); blob.quaternion.setFromRotationMatrix(M4); blob.position.copy(V1).addScaledVector(V2, 0.06); blob.scale.setScalar(2.4); blob.material.opacity = 0.9;
  return V2;
}

// =================================================================== slide simulation
const bot = { on: qs.has('bot'), steer: 0, dive: false, flap: false, t: 0 };
function slideBot() {
  let tu = sl.u;
  for (const g of items.gems) { if (!g.alive || g.s < sl.s + 2) continue; if (g.s > sl.s + 34) break; path.at(g.s, F); V1.set(g.x, g.y, g.z).sub(F.p); tu = V1.dot(F.R); break; }
  for (const b of items.bumpers) { if (b.hit || b.s < sl.s - 1) continue; if (b.s > sl.s + 16) break; if (Math.abs(tu - b.u) < 1.5) tu = b.u + (tu >= b.u ? 1 : -1) * 1.9; }
  tu = clamp(tu, -2.5, 2.5); bot.steer = clamp((tu - sl.u) * 1.0 - sl.uv * 0.12, -1, 1);
}
function stepSlide(dt) {
  const up = save.up, ci = COURSES.indexOf(course);
  sl.t += dt; if (bot.on) slideBot();
  const steer = input.steerS;
  const vMax = (25 + up.speed * 2.6) * (1 + ci * 0.03);
  sl.boost = Math.max(0, sl.boost - dt); sl.stun = Math.max(0, sl.stun - dt); sl.shake = Math.max(0, sl.shake - dt * 3); sl.wallT = Math.max(0, sl.wallT - dt);
  const vT = vMax * (sl.stun > 0 ? 0.62 : 1) + (sl.boost > 0 ? (13 + up.speed * 1.4) * Math.min(1, sl.boost / 0.5) : 0);
  sl.v += clamp(vT - sl.v, -45 * dt, 15 * dt);
  const k = path.curvature(sl.s);
  sl.uv += (steer * 7.4 - sl.uv) * (1 - Math.exp(-7 * dt));
  sl.uv += (k * sl.v * sl.v * 0.3 - sl.u * 0.45) * dt;
  sl.u += sl.uv * dt;
  const wall = 2.95;
  if (Math.abs(sl.u) > wall) {
    const sg = Math.sign(sl.u); sl.u = sg * wall;
    if (sl.uv * sg > 0) { if (sl.uv * sg > 3.5 && sl.wallT <= 0) { sfx('swish', { volume: 0.7 }); sl.wallT = 0.3; sl.shake = Math.max(sl.shake, 0.25); } sl.uv = -sl.uv * 0.3; }
    sl.v *= 1 - 0.3 * dt;
    for (let i = 0; i < 2; i++) emitSpray(1.4, 0xffffff, sg);
  }
  sl.s += sl.v * dt;
  const N = placeRiderSlide();
  // gems
  V3.copy(rider.root.position).addScaledVector(N, 0.9);
  slideGems.update(dt, time, sl.s, V3.x, V3.y, V3.z, save.up.magnet > 0 ? 1.4 + save.up.magnet * 1.15 : 0, 1.35 + save.up.magnet * 0.2, collectSlideGem, 55);
  // bumpers
  for (let i = 0; i < items.bumpers.length; i++) {
    const b = items.bumpers[i]; if (b.hit) continue; if (b.s < sl.s - 3) continue; if (b.s > sl.s + 3) break;
    const dx = V3.x - b.x, dy = V3.y - b.y, dz = V3.z - b.z; if (dx * dx + dy * dy + dz * dz < 1.62 * 1.62) hitBumper(b, i);
  }
  // pads
  for (const p of items.pads) { if (p.used || Math.abs(p.s - sl.s) > 4) continue; if (Math.abs(p.u - sl.u) < 1.6) { p.used = true; sl.boost = 1.7; sl.v += 6; sl.shake = Math.max(sl.shake, 0.25); sfx('whoosh'); sfx('powerup', { volume: 0.5 }); banner('BOOST!', '#fff3a0'); for (let i = 0; i < 26; i++) emitGlow(); } }
  // effects
  sl.sprayAcc += dt * (50 + sl.v * 2.8); while (sl.sprayAcc > 1) { sl.sprayAcc -= 1; emitSpray(1, 0xffffff, 0); }
  if (sl.boost > 0) { sl.glowAcc += dt * 90; while (sl.glowAcc > 1) { sl.glowAcc -= 1; emitGlow(); } }
  // rider pose
  poseO.mode = 'slide'; poseO.lean = -clamp(sl.uv / 6, -1, 1); poseO.dive = 0; poseO.flapping = 0; poseO.speed01 = clamp((sl.v - 18) / 30, 0, 1); poseO.t = time;
  rider.pose(dt, poseO);
  // camera
  const back = (6.2 + sl.v * 0.04 + (sl.boost > 0 ? 1.2 : 0)) * camScale, upo = (2.7 + sl.v * 0.01) * camScale;
  tgt.copy(rider.root.position).addScaledVector(F.T, -back).addScaledVector(F.U, upo).addScaledVector(F.R, sl.u * 0.35);
  tgtLook.copy(rider.root.position).addScaledVector(F.T, 13).addScaledVector(F.U, 0.9);
  V1.set(0, 1, 0).multiplyScalar(0.55).addScaledVector(F.U, 0.45).normalize(); camUpV.lerp(V1, 1 - Math.exp(-5 * dt)).normalize();
  setCam(dt, 9);
  const sp01 = clamp((sl.v - 18) / 32, 0, 1), bk = clamp(sl.boost / 0.6, 0, 1);
  setFov(baseFov + 15 * sp01 + 11 * bk - (sl.stun > 0 ? 3 : 0), dt);
  fxK.speed = sp01 * 0.55 + bk * 0.6; fxK.lines = sp01 * 0.5 + bk * 0.7; fxK.vig = 0.3 + bk * 0.2; fxK.tint = 1;
  music.setIntensity(0.3 + sp01 * 0.7);
  if (sl.s >= path.L - 0.5) startFlight();
}
const fxK = { speed: 0, lines: 0, vig: 0.3, flash: 0, tint: 1 };

function emitSpray(sc, hex, side) {
  const N = V2.copy(rider.root.up || UPV);
  const q = rider.root.quaternion; const fwd = V3.set(0, 0, 1).applyQuaternion(q), upv = V4.set(0, 1, 0).applyQuaternion(q);
  const right = V1.set(1, 0, 0).applyQuaternion(q);
  const px = rider.root.position.x, py = rider.root.position.y, pz = rider.root.position.z;
  const sx = (Math.random() - 0.5) * 1.2 + (side ? side * 0.5 : 0);
  const v = sl.v;
  spray.emit(px - fwd.x * 0.55 + right.x * sx, py + upv.y * 0.25 - fwd.y * 0.55, pz - fwd.z * 0.55 + right.z * sx,
    -fwd.x * v * 0.22 + right.x * sx * 2.2 + upv.x * 3 + (Math.random() - 0.5) * 2, -fwd.y * v * 0.22 + upv.y * (2 + Math.random() * 3.5), -fwd.z * v * 0.22 + right.z * sx * 2.2 + upv.z * 3 + (Math.random() - 0.5) * 2,
    0.85 + Math.random() * 0.15, 0.95, 1.0, (0.2 + Math.random() * 0.3) * sc, 0.4 + Math.random() * 0.35, 9);
}
function emitGlow() {
  const p = rider.root.position, q = rider.root.quaternion, fwd = V3.set(0, 0, 1).applyQuaternion(q);
  const c = Math.random() < 0.5 ? [1.0, 0.85, 0.3] : [0.3, 0.9, 1.0];
  glow.emit(p.x - fwd.x * 0.6 + (Math.random() - 0.5) * 1.2, p.y + 0.5 + Math.random() * 0.8, p.z - fwd.z * 0.6 + (Math.random() - 0.5) * 1.2, -fwd.x * 6 + (Math.random() - 0.5) * 3, 1 + Math.random() * 3, -fwd.z * 6 + (Math.random() - 0.5) * 3, c[0] * 1.5, c[1] * 1.5, c[2] * 1.5, 0.4 + Math.random() * 0.5, 0.6 + Math.random() * 0.4, 0);
}
function burst(x, y, z, n, hexA, speed, size, life, grav, additive) {
  const pa = additive ? glow : spray, c = new THREE.Color(hexA);
  for (let i = 0; i < n; i++) { const a = Math.random() * 6.283, b = Math.random() * 2 - 1, s = speed * (0.4 + Math.random() * 0.8), r = Math.sqrt(1 - b * b); pa.emit(x, y, z, Math.cos(a) * r * s, b * s, Math.sin(a) * r * s, c.r * (additive ? 1.5 : 1), c.g * (additive ? 1.5 : 1), c.b * (additive ? 1.5 : 1), size * (0.6 + Math.random() * 0.8), life * (0.6 + Math.random() * 0.6), grav); }
}
function collectSlideGem(g) {
  run.gems += course.id === COURSES[dailyIdx].id ? 2 : 1; sl.gems++; save.gemsPending = true;
  sfx('coin', { pitch: 1 + (sl.gems % 8) * 0.06, volume: 0.6 });
  burst(g.x, g.y, g.z, 6, course.gem[g.c], 5, 0.4, 0.5, 0, true);
}
function hitBumper(b, i) {
  b.hit = true; bumperMesh.setMatrixAt(i, ZERO); bumperMesh.instanceMatrix.needsUpdate = true;
  sl.v *= 0.58; sl.stun = 0.55; sl.shake = 0.9; sl.bumps++;
  sl.uv += (sl.u - b.u >= 0 ? 1 : -1) * 6.5; fxK.flash = 0.25;
  sfx('hit'); sfx('boing', { volume: 0.7 });
  burst(b.x, b.y, b.z, 22, 0xff4d6d, 9, 0.55, 0.8, 12, false); burst(b.x, b.y, b.z, 16, 0xffffff, 8, 0.5, 0.7, 12, false);
  rider.squash = 1;
}

// =================================================================== flight
function startFlight() {
  state = 'flight'; fl.t = 0;
  path.at(path.L - 0.5, F);
  fl.x = rider.root.position.x; fl.y = rider.root.position.y + 0.4; fl.z = rider.root.position.z; fl.px = fl.x; fl.py = fl.y; fl.pz = fl.z;
  fl.ox = fl.x; fl.oz = fl.z; fl.launchY = fl.y;
  fl.th = Math.asin(clamp(F.T.y, -1, 1)); fl.v = sl.v * 1.12 + 8 + save.up.speed; fl.yaw = 0; fl.bank = 0; fl.lift = 0; fl.dive = 0;
  fl.maxFlaps = 3 + save.up.glide; fl.flaps = fl.maxFlaps; fl.f = 0; fl.l = 0; fl.rings = 0; fl.balloons = 0; fl.skips = 0; fl.hoops = 0; fl.chain = 0; fl.flapAnim = 0; fl.prevF = 0; fl.shake = 0;
  fl.guideY = fl.y + 22; fl.guideL = 0; fl.nextF = 140; fl.lastF = undefined; fl.lastL = 0; fl.lastY = undefined; fl.trailAcc = 0; fl.poolNext = 430; fl.maxY = fl.y; fl.lastRingF = 0;
  flightGems.items = []; flightGems.start = 0;
  rider.wingScale = 1.3 + save.up.wings * 0.08; rider.root.visible = true;
  hudMode('flight'); el.distVal.textContent = '0'; clearHint();
  banner('WINGS OUT!', '#ffffff'); sfx('whoosh'); sfx('powerup'); music.duck(0.5, 0.5);
  setMusic('flight', 0.5); fxK.flash = 0.35; launchSlow = 0.9; sl.shake = 0.6;
  burst(fl.x, fl.y, fl.z, 40, 0xffffff, 14, 0.7, 0.9, 6, false);
  if (save.hints.fly < 3) { hintTimer = 6; setHint('Hold to DIVE, tap to FLAP, drag to steer!', true); }
  spawnAhead();
}
function spawnRing(f, l, y) {
  const r = rings.find((q) => !q.active); if (!r) return null;
  r.active = true; r.done = 0; r.f = f; r.l = l; r.r = 5.3 + frng() * 1.2 - Math.min(1.2, f / 5000);
  r.x = fl.ox + D0.x * f + RT.x * l; r.z = fl.oz + D0.z * f + RT.z * l; r.y = y;
  r.g.visible = true; r.g.position.set(r.x, y, r.z); r.g.rotation.set(0, Math.atan2(D0.x, D0.z), 0); r.g.scale.setScalar(r.r); r.t.material.opacity = 1; r.gl.visible = true; r.gl.material.opacity = 0.5;
  return r;
}
function addGemTrail(f0, l0, y0, f1, l1, y1) {
  const n = 6;
  for (let i = 1; i <= n; i++) {
    const t = i / (n + 1), f = lerp(f0, f1, t), l = lerp(l0, l1, t), y = lerp(y0, y1, t) + Math.sin(t * Math.PI) * 4.5;
    const x = fl.ox + D0.x * f + RT.x * l, z = fl.oz + D0.z * f + RT.z * l;
    flightGems.items.push({ x, y, z, s: f, alive: true, t: frng() * 6, fly: 0, c: i % 2 });
  }
}
function spawnChunk() {
  const f = fl.nextF; fl.nextF += 95 + frng() * 45;
  // guide drifts toward the player and slowly sinks
  fl.guideY += (fl.y - fl.guideY) * 0.4 + (frng() - 0.35) * 22 - 5; fl.guideY = clamp(fl.guideY, 28, 330);
  fl.guideL = clamp(fl.guideL * 0.6 + (fl.l) * 0.4 + (frng() - 0.5) * 80, -170, 170);
  const prevF = fl.lastF === undefined ? f - 100 : fl.lastF, prevL = fl.lastL || 0, prevY = fl.lastY || fl.guideY;
  const r = frng(), gy = fl.guideY, gl = fl.guideL;
  if (r < 0.58) { spawnRing(f, gl, gy); addGemTrail(prevF, prevL, prevY, f, gl, gy); }
  else if (r < 0.8) {
    for (let i = 0; i < 4; i++) { if (balloons.length > 40) break; const a = i * 1.7 + frng(); balloons.push({ x: fl.ox + D0.x * f + RT.x * (gl + Math.cos(a) * 7), y: gy + Math.sin(a) * 6, z: fl.oz + D0.z * f + RT.z * (gl + Math.cos(a) * 7) + 0, f: f + Math.sin(a) * 4, alive: true, c: Math.floor(frng() * 6), ph: frng() * 6 }); }
    addGemTrail(prevF, prevL, prevY, f, gl, gy);
  } else if (r < 0.9) {
    const h = hoops.find((q) => !q.active);
    if (h) { h.active = true; h.done = 0; h.f = f; h.x = fl.ox + D0.x * f + RT.x * gl; h.z = fl.oz + D0.z * f + RT.z * gl; h.y = gy + 2; h.r = 13.5; h.m.visible = true; h.m.position.set(h.x, h.y, h.z); h.m.rotation.set(0, Math.atan2(D0.x, D0.z), 0); h.m.scale.setScalar(h.r); h.m.material.opacity = 0.85; }
    addGemTrail(prevF, prevL, prevY, f, gl, gy);
  } else { spawnRing(f, gl, gy); spawnRing(f + 22, gl + (frng() < 0.5 ? -16 : 16), gy + 4); addGemTrail(prevF, prevL, prevY, f, gl, gy); }
  fl.lastF = f; fl.lastL = gl; fl.lastY = gy;
  if (f > fl.poolNext) { const p = pools.find((q) => !q.active); if (p) { p.active = true; p.f = fl.poolNext; const l = clamp(gl + (frng() - 0.5) * 120, -200, 200); p.x = fl.ox + D0.x * p.f + RT.x * l; p.z = fl.oz + D0.z * p.f + RT.z * l; p.r = 24; p.g.visible = true; p.g.position.set(p.x, 0, p.z); p.g.scale.set(p.r, 1, p.r); p.g.children[1].scale.set(1 / 1, 1, 1); } fl.poolNext += 420; }
}
function spawnAhead() { let n = 0; while (fl.nextF < fl.f + 560 && n++ < 8) spawnChunk(); }

function doFlap() {
  if (flapCool > 0) return;
  if (fl.flaps < 1) { sfx('click'); banner('No flaps left!', '#ffd0d0'); flapCool = 0.5; return; }
  fl.flaps--; flapCool = 0.18; const wm = 1 + save.up.wings * 0.12;
  fl.lift = 1; fl.v = Math.min(110, fl.v + 4 * wm); fl.th += 0.16; fl.flapAnim = 0.55; rider.squash = 0.4;
  sfx('swish'); sfx('jump', { volume: 0.35, pitch: 1.4 });
  burst(fl.x, fl.y - 0.5, fl.z, 14, 0xffffff, 5, 0.5, 0.6, 2, true);
}
const HV = new THREE.Vector3();
function stepFlight(dt) {
  const up = save.up, wm = 1 + up.wings * 0.12, cD = 0.0016 * (1 - up.glide * 0.06);
  fl.t += dt; flapCool = Math.max(0, flapCool - dt); fl.flapAnim = Math.max(0, fl.flapAnim - dt); fl.shake = Math.max(0, (fl.shake || 0) - dt * 3); sl.shake = Math.max(0, sl.shake - dt * 3);
  if (bot.on) flightBot();
  const steer = input.steerS;
  if (input.flapQ) { input.flapQ = 0; doFlap(); }
  fl.yaw = clamp(fl.yaw - steer * 0.85 * (1 + up.wings * 0.04) * dt, -1.1, 1.1);
  const diveT = input.holdActive ? 1 : 0; fl.dive += (diveT - fl.dive) * (1 - Math.exp(-9 * dt));
  let thT = diveT ? -0.78 : lerp(-0.07, 0.36, sstep(30, 64, fl.v));
  if (fl.v < 24) thT -= (24 - fl.v) * 0.035;
  if (fl.y > 360) thT = Math.min(thT, -0.12 * (fl.y - 360) / 40);
  fl.th += (thT - fl.th) * (1 - Math.exp(-(diveT ? 2.7 : 1.35) * dt));
  fl.v += (-24 * Math.sin(fl.th) - cD * (1 + Math.max(0, fl.f) / 3000) * fl.v * fl.v) * dt; fl.v = clamp(fl.v, 12, 112);
  fl.lift *= Math.exp(-2.3 * dt);
  const vy = fl.v * Math.sin(fl.th) + fl.lift * 9 * wm, vh = fl.v * Math.cos(fl.th);
  const cy = Math.cos(fl.yaw), sy = Math.sin(fl.yaw); HV.set(D0.x * cy + D0.z * sy, 0, -D0.x * sy + D0.z * cy);
  fl.px = fl.x; fl.py = fl.y; fl.pz = fl.z;
  fl.x += HV.x * vh * dt; fl.z += HV.z * vh * dt; fl.y += vy * dt;
  fl.prevF = fl.f; fl.f = (fl.x - fl.ox) * D0.x + (fl.z - fl.oz) * D0.z; fl.l = (fl.x - fl.ox) * RT.x + (fl.z - fl.oz) * RT.z; fl.maxY = Math.max(fl.maxY, fl.y);
  // magnet strength etc.
  const magR = up.magnet > 0 ? 3 + up.magnet * 2.4 : 0;
  flightGems.update(dt, time, fl.f, fl.x, fl.y, fl.z, magR, 3.3 + up.magnet * 0.6, collectFlightGem, 420);
  // rings & hoops (plane crossing)
  for (const r of rings) {
    if (!r.active) continue;
    if (r.done > 0) { r.done += dt * 2.0; r.g.scale.setScalar(r.r * (1 + r.done * 0.3)); r.t.material.opacity = Math.max(0, 1 - r.done); r.gl.material.opacity = Math.max(0, 0.5 - r.done * 1.5); if (r.done > 1) { r.active = false; r.g.visible = false; } continue; }
    r.g.rotation.z += dt * 0.5;
    const sd0 = (fl.px - r.x) * D0.x + (fl.pz - r.z) * D0.z, sd1 = (fl.x - r.x) * D0.x + (fl.z - r.z) * D0.z;
    if (sd0 < 0 && sd1 >= 0) { const t = sd0 / (sd0 - sd1), hx = lerp(fl.px, fl.x, t) - r.x, hy = lerp(fl.py, fl.y, t) - r.y, hz = lerp(fl.pz, fl.z, t) - r.z; if (Math.hypot(hx, hy, hz) < r.r * 1.12 + (up.magnet > 0 ? up.magnet * 0.6 : 0)) collectRing(r); }
    if (sd1 > 60) { r.active = false; r.g.visible = false; }
  }
  for (const h of hoops) {
    if (!h.active) continue;
    if (h.done > 0) { h.done += dt * 1.8; h.m.scale.setScalar(h.r * (1 + h.done * 0.8)); h.m.material.opacity = Math.max(0, 0.85 - h.done * 0.8); if (h.done > 1.1) { h.active = false; h.m.visible = false; } continue; }
    const sd0 = (fl.px - h.x) * D0.x + (fl.pz - h.z) * D0.z, sd1 = (fl.x - h.x) * D0.x + (fl.z - h.z) * D0.z;
    if (sd0 < 0 && sd1 >= 0) { const t = sd0 / (sd0 - sd1), hx = lerp(fl.px, fl.x, t) - h.x, hy = lerp(fl.py, fl.y, t) - h.y, hz = lerp(fl.pz, fl.z, t) - h.z; if (Math.hypot(hx, hy, hz) < h.r * 1.05) collectHoop(h); }
    if (sd1 > 60) { h.active = false; h.m.visible = false; }
  }
  for (const p of pools) { if (p.active && (fl.x - p.x) * D0.x + (fl.z - p.z) * D0.z > 80) { p.active = false; p.g.visible = false; } }
  // balloons
  const bR = 3.1 + up.magnet * 0.5;
  for (let i = balloons.length - 1; i >= 0; i--) {
    const b = balloons[i]; if (b.f < fl.f - 60) { balloons.splice(i, 1); continue; } if (!b.alive) continue;
    const dx = fl.x - b.x, dy = fl.y - (b.y + Math.sin(time * 1.4 + b.ph) * 0.8), dz = fl.z - b.z;
    if (up.magnet > 0 && dx * dx + dy * dy + dz * dz < (magR * 4) ** 2) { const k = Math.min(1, 6 * dt); b.x += dx * k; b.y += dy * k; b.z += dz * k; }
    if (dx * dx + dy * dy + dz * dz < bR * bR * 2.2) popBalloon(b);
  }
  // spawn / cleanup
  spawnAhead(); if (flightGems.start > 120) { flightGems.items.splice(0, flightGems.start); flightGems.start = 0; }
  // slow regen of flaps
  
  // landing
  const gy = 0.9;
  if (fl.y < 36) { const isl = world.islandAt(fl.x, fl.y, fl.z); if (isl) { beachLand(isl); return; } }
  if (fl.y <= gy) { splashDown(); return; }
  // orient rider
  const cth = Math.cos(fl.th); V1.set(HV.x * cth, Math.sin(fl.th), HV.z * cth).normalize();
  fl.bank += (steer * 0.75 - fl.bank) * (1 - Math.exp(-5 * dt));
  V2.crossVectors(UPV, V1).normalize(); V3.crossVectors(V1, V2); M4.makeBasis(V2, V3, V1); rider.root.quaternion.setFromRotationMatrix(M4);
  QZ.setFromAxisAngle(AXZ, fl.bank); rider.root.quaternion.multiply(QZ);
  rider.root.position.set(fl.x, fl.y, fl.z);
  poseO.mode = 'fly'; poseO.lean = -steer * 0.6; poseO.dive = fl.dive; poseO.flapping = fl.flapAnim > 0 ? 1 : 0; poseO.speed01 = clamp((fl.v - 25) / 60, 0, 1); poseO.t = time; poseO.pitch = fl.th;
  rider.pose(dt, poseO);
  // shadow on sea
  blob.rotation.set(-Math.PI / 2, 0, 0); blob.position.set(fl.x, 0.9, fl.z); blob.scale.setScalar(5 + fl.y * 0.05); blob.material.opacity = clamp(1 - fl.y / 260, 0.15, 0.85);
  // trail particles
  fl.trailAcc = (fl.trailAcc || 0) + dt * (14 + fl.dive * 40 + clamp((fl.v - 40) / 40, 0, 1) * 25);
  while (fl.trailAcc > 1) { fl.trailAcc -= 1; glow.emit(fl.x - V1.x * 0.6 + (Math.random() - 0.5) * 3, fl.y + 0.8 + (Math.random() - 0.5) * 2, fl.z - V1.z * 0.6 + (Math.random() - 0.5) * 3, -V1.x * 8, -V1.y * 8 + 1, -V1.z * 8, 1.3, 1.4, 1.6, 0.35 + Math.random() * 0.3, 0.7, 0); }
  // camera
  flightCamera(dt);
  const sp01 = clamp((fl.v - 30) / 62, 0, 1);
  fxK.speed = sp01 * 0.7 + (fl.dive * 0.3); fxK.lines = sp01 * 0.85; fxK.vig = 0.3 + sp01 * 0.25; fxK.tint = 1;
  music.setIntensity(0.25 + sp01 * 0.75);
  if (hintTimer > 0) { hintTimer -= dt; if (hintTimer <= 0 || fl.t > 9) { clearHint(); save.hints.fly++; persist(); hintTimer = 0; } }
}
function flightCamera(dt) {
  const sp01 = clamp((fl.v - 30) / 62, 0, 1);
  const cth = Math.cos(fl.th); V1.set(HV.x * cth, Math.sin(fl.th) * 0.6, HV.z * cth).normalize();
  const back = (8.5 + sp01 * 4 + (fl.t < 1.2 ? (1.2 - fl.t) * 6 : 0)) * camScale, upo = (3.2 - fl.dive * 1.0 + (fl.t < 1.2 ? (1.2 - fl.t) * 2 : 0)) * camScale;
  tgt.set(fl.x, fl.y, fl.z).addScaledVector(V1, -back); tgt.y += upo; tgt.x += RT.x * 0 + HV.z * -fl.bank * 1.6; tgt.z += HV.x * fl.bank * 1.6;
  if (tgt.y < 3) tgt.y = 3;
  tgtLook.set(fl.x, fl.y, fl.z).addScaledVector(V1, 14); tgtLook.y += 0.5 - fl.dive * 1.5;
  camUpV.lerp(V2.set(0, 1, 0), 1 - Math.exp(-3 * dt));
  camUpV.x += fl.bank * 0.05; camUpV.normalize();
  setCam(dt, fl.t < 1 ? 5 : 8);
  setFov(baseFov + 22 * sp01 + fl.dive * 5 + (fl.t < 1 ? 6 : 0), dt);
}
function collectFlightGem(g) {
  run.gems += course.id === COURSES[dailyIdx].id ? 2 : 1; fl.gems++;
  sfx('coin', { pitch: 1.1 + (fl.gems % 8) * 0.05, volume: 0.55 }); burst(g.x, g.y, g.z, 6, course.gem[g.c], 6, 0.6, 0.5, 0, true);
}
function collectRing(r) {
  r.done = 0.01; fl.rings++; fl.chain++; run.gems += 2; if (fl.rings % 3 === 0) fl.flaps = Math.min(fl.maxFlaps, fl.flaps + 1);
  const m = Math.min(12, 1 + 0.5 * fl.rings); banner(`RING!  x${m % 1 ? m.toFixed(1) : m}`, '#ffe36a');
  sfx('powerup', { volume: 0.4, pitch: 0.9 + Math.min(fl.chain, 8) * 0.07 });
  burst(r.x, r.y, r.z, 36, 0xffd23f, 16, 0.9, 0.8, 0, true); burst(r.x, r.y, r.z, 14, 0xffffff, 10, 0.7, 0.7, 0, true);
  fl.v = Math.min(112, fl.v + 2); fxK.flash = 0.12; fl.lift = Math.max(fl.lift, 0.35);
}
function collectHoop(h) {
  h.done = 0.01; fl.rings++; fl.hoops++; fl.flaps = Math.min(fl.maxFlaps, fl.flaps + 2); run.gems += 5;
  fl.v = Math.min(112, fl.v + 14); fl.lift = 0.7; fl.shake = 0.4; fxK.flash = 0.3;
  banner('RAINBOW BOOST!', '#ffffff'); sfx('whoosh'); sfx('powerup');
  for (let i = 0; i < 40; i++) { const a = Math.random() * 6.283; glow.emit(h.x + Math.cos(a) * h.r * 0.9, h.y + Math.sin(a) * h.r * 0.9, h.z, (Math.random() - 0.5) * 6, (Math.random() - 0.5) * 6, 18 + Math.random() * 20, ...BCOL[i % 6].toArray().map((c) => c * 1.5), 1 + Math.random(), 1, 0); }
}
function popBalloon(b) {
  b.alive = false; fl.balloons++; run.gems += 2; fl.v = Math.min(112, fl.v + 2.5); fl.lift = Math.max(fl.lift, 0.6); fl.flaps = Math.min(fl.maxFlaps, fl.flaps + (fl.balloons % 4 === 0 ? 1 : 0));
  sfx('pop', { pitch: 0.9 + Math.random() * 0.4 }); burst(b.x, b.y, b.z, 22, BCOL[b.c].getHex(), 9, 0.6, 0.9, 6, false); burst(b.x, b.y, b.z, 8, 0xffffff, 6, 0.4, 0.6, 0, true);
}
function updateBalloons() {
  if (!balloonMesh) return; let n = 0;
  for (const b of balloons) { if (!b.alive || n >= 48) continue; const by = b.y + Math.sin(time * 1.4 + b.ph) * 0.8; V1.set(b.x, by + 1.5, b.z); Q1.setFromAxisAngle(UPV, b.ph + time * 0.3); M4.compose(V1, Q1, V2.set(1.35, 1.35, 1.35)); balloonMesh.setMatrixAt(n, M4); balloonMesh.setColorAt(n, BCOL[b.c]); n++; }
  balloonMesh.count = n; balloonMesh.instanceMatrix.needsUpdate = true; if (balloonMesh.instanceColor) balloonMesh.instanceColor.needsUpdate = true;
}
function flightBot() {
  // chase the next ring / balloon
  let t = null;
  for (const r of rings) if (r.active && !r.done && r.f > fl.f && (!t || r.f < t.f)) t = r;
  if (!t) for (const h of hoops) if (h.active && !h.done && h.f > fl.f && (!t || h.f < t.f)) t = { f: h.f, l: 0, y: h.y, x: h.x, z: h.z };
  let tx = fl.x + HV.x * 100, tz = fl.z + HV.z * 100, ty = fl.y;
  if (t) { tx = t.x; tz = t.z; ty = t.y; }
  const dl = (tx - fl.x) * RT.x + (tz - fl.z) * RT.z, df = Math.max(10, (tx - fl.x) * D0.x + (tz - fl.z) * D0.z);
  const want = -Math.atan2(dl, df); bot.steer = clamp((fl.yaw - want) * 3, -1, 1);
  bot.dive = ty < fl.y - 3 && fl.v < 95; if (ty > fl.y + 8 && fl.flaps > 0 && flapCool <= 0 && fl.v < 60) bot.flap = true;
  if (fl.y < 25 && fl.flaps > 0 && flapCool <= 0) bot.flap = true;
  if (fl.y < 12) bot.dive = false;
}

// -------- landing
let rippleMesh = null; const ripples = [];
{
  const g = new THREE.RingGeometry(0.88, 1, 56).rotateX(-Math.PI / 2);
  for (let i = 0; i < 3; i++) { const m = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0, depthWrite: false, side: THREE.DoubleSide })); m.visible = false; m.renderOrder = 3; scene.add(m); ripples.push({ m, t: 9, s: 10 }); }
}
function ripple(x, z, size) { const r = ripples.find((q) => q.t > 3) || ripples[0]; r.t = 0; r.s = size; r.m.position.set(x, 0.8, z); r.m.visible = true; }
function splashDown() {
  // pools take priority; otherwise skip on shallow fast landings
  let pool = null, zone = -1;
  for (const p of pools) { if (!p.active) continue; const d = Math.hypot(fl.x - p.x, fl.z - p.z); if (d < p.r) { pool = p; zone = d < p.r * 0.3 ? 0 : d < p.r * 0.62 ? 1 : 2; break; } }
  const sink = -fl.v * Math.sin(fl.th);
  if (!pool && fl.skips < 3 && fl.th > -0.42 && fl.v > 34) {
    fl.skips++; fl.y = 1.0; fl.th = 0.16 + 0.04 * fl.skips * 0; fl.v *= 0.84; fl.lift = 0; fl.dive = 0;
    sfx('splash', { volume: 0.7 }); sfx('boing', { volume: 0.4, pitch: 1.3 }); banner('SKIP!', '#8fe8ff'); ripple(fl.x, fl.z, 14); fl.shake = 0.5;
    burst(fl.x, 1, fl.z, 36, 0xffffff, 12, 0.8, 0.9, 14, false);
    return;
  }
  state = 'landing'; landTimer = 0; run.pool = pool; run.poolZone = zone; run.beach = false;
  finishRun(); landFx(fl.x, fl.z, true);
  if (pool) { banner(zone === 0 ? 'BULLSEYE!' : 'POOL SPLASH!', '#ffe36a'); sfx('win', { volume: 0.7 }); } else { banner('SPLASH!', '#8fe8ff'); }
}
function beachLand(isl) {
  state = 'landing'; landTimer = 0; run.pool = null; run.poolZone = -1; run.beach = true; finishRun(); landFx(fl.x, fl.z, false);
  banner('BEACH LANDING!', '#ffeaa0'); fl.y = Math.max(fl.y, 2);
}
function landFx(x, z, water) {
  const gy = water ? 0 : fl.y;
  sfx(water ? 'splash' : 'step'); sfx('boom', { volume: 0.3 }); fl.shake = 1; fxK.flash = 0.2;
  ripple(x, z, 40); setTimeout(() => ripple(x, z, 70), 180);
  burst(x, gy + 1, z, 110, water ? 0xffffff : 0xffe9b0, 26, 1.6, 1.6, 20, false); burst(x, gy + 2, z, 60, water ? 0x9fe8ff : 0xffe9b0, 20, 2.0, 1.8, 14, false);
  for (let i = 0; i < 50; i++) { const a = Math.random() * 6.283, r = Math.random() * 3; spray.emit(x + Math.cos(a) * r, gy + 1, z + Math.sin(a) * r, Math.cos(a) * (2 + Math.random() * 5), 14 + Math.random() * 20, Math.sin(a) * (2 + Math.random() * 5), 0.9, 0.98, 1, 1.4 + Math.random() * 1.6, 1.8 + Math.random() * 0.8, 16); }
  burst(x, gy + 3, z, 40, 0xffffff, 18, 1.2, 1.2, 8, true);
  rider.squash = 1; rider.root.position.set(x, water ? 0.5 : gy, z); V1.set(0, 1, 0); rider.root.quaternion.setFromAxisAngle(UPV, Math.atan2(HV.x, HV.z));
  blob.material.opacity = 0; music.duck(0.25, 1.3);
}
function finishRun() {
  const dist = Math.max(0, fl.f), mult = Math.min(12, 1 + 0.5 * fl.rings), pm = run.pool ? [2, 1.5, 1.25][run.poolZone] : 1;
  run.dist = dist; run.mult = mult; run.score = Math.round(dist * mult * pm);
  const th = course.stars; run.stars = run.score >= th[2] ? 3 : run.score >= th[1] ? 2 : run.score >= th[0] ? 1 : 0;
}
function stepLanding(dt) {
  landTimer += dt; fl.shake = Math.max(0, (fl.shake || 0) - dt * 2.5);
  poseO.mode = 'idle'; poseO.lean = 0; poseO.dive = 0; poseO.flapping = 0; poseO.speed01 = 0; poseO.t = time; rider.pose(dt, poseO);
  if (run.beach) { rider.root.position.y = fl.y; } else { rider.root.position.y = 0.35 + Math.sin(time * 2.2) * 0.12; rider.root.rotation.z = Math.sin(time * 1.6) * 0.1; }
  // cheer arms
  rider.armL.rotation.x = -2.7; rider.armR.rotation.x = -2.7; rider.armL.rotation.z = -0.35; rider.armR.rotation.z = 0.35;
  V1.copy(rider.root.position); tgt.set(V1.x - HV.x * 17, V1.y + 10, V1.z - HV.z * 17); tgtLook.copy(V1); tgtLook.y += 2; camUpV.set(0, 1, 0); setCam(dt, 2.5); setFov(baseFov + 4, dt);
  fxK.speed = 0; fxK.lines = 0; fxK.vig = 0.3; music.setIntensity(0.2);
  if (landTimer > 0.5 && landTimer - dt <= 0.5) { for (let i = 0; i < 40; i++) glow.emit(V1.x + (Math.random() - 0.5) * 3, V1.y + 3 + Math.random() * 3, V1.z + (Math.random() - 0.5) * 3, (Math.random() - 0.5) * 10, 8 + Math.random() * 8, (Math.random() - 0.5) * 10, ...BCOL[i % 6].toArray().map((c) => c * 1.3), 0.5, 1.6, 12); }
  if (landTimer > 2.0) showResults();
}

// =================================================================== results / menus
function countUp(elm, to, fmtFn, ms) { const t0 = performance.now(); const f = (now) => { const k = clamp((now - t0) / ms, 0, 1), e = 1 - Math.pow(1 - k, 3); elm.textContent = fmtFn(to * e); if (k < 1) requestAnimationFrame(f); }; requestAnimationFrame(f); }
function showResults() {
  if (state === 'results') return; state = 'results'; hudMode('none'); clearHint();
  const rec = save.courses[course.id] || { stars: 0, bestDist: 0, bestScore: 0 };
  const newBest = run.score > rec.bestScore; const best = Math.max(rec.bestScore, run.score);
  rec.bestScore = best; rec.bestDist = Math.max(rec.bestDist, Math.round(run.dist)); const newStars = Math.max(0, run.stars - (rec.stars || 0)); rec.stars = Math.max(rec.stars || 0, run.stars); save.courses[course.id] = rec;
  const bonus = (run.pool ? [20, 10, 5][run.poolZone] : 0) + run.stars * 5;
  const gemsGot = run.gems + bonus; save.gems += gemsGot; save.plays++; persist(); refreshGems();
  $('#resTitle').textContent = run.stars === 3 ? 'Super Star Glide!' : run.stars === 2 ? 'Great Glide!' : run.stars === 1 ? 'Nice Flying!' : 'Good Try!';
  $('#rDist').textContent = '0 m'; $('#rMult').textContent = 'x' + (run.mult % 1 ? run.mult.toFixed(1) : run.mult);
  $('#rPoolL').textContent = run.beach ? 'Landing' : 'Pool bonus'; $('#rPool').textContent = run.beach ? 'Beach' : run.pool ? ['Bullseye x2', 'Inner x1.5', 'Pool x1.25'][run.poolZone] : 'none';
  $('#rGems').textContent = '0'; $('#rScore').textContent = '0'; $('#rBest').textContent = fmt(best); $('#newBest').classList.toggle('hidden', !newBest);
  const stars = document.querySelectorAll('#stars .i'); stars.forEach((s) => s.classList.remove('on'));
  showScreen('results'); sfx(run.stars ? 'win' : 'lose', { volume: 0.7 });
  setTimeout(() => countUp($('#rDist'), run.dist, (v) => fmt(v) + ' m', 900), 250);
  setTimeout(() => countUp($('#rGems'), gemsGot, (v) => fmt(v), 900), 450);
  setTimeout(() => countUp($('#rScore'), run.score, (v) => fmt(v), 1200), 650);
  stars.forEach((s, i) => { if (i < run.stars) setTimeout(() => { s.classList.add('on'); sfx('coin', { volume: 0.6, pitch: 1 + i * 0.25 }); }, 1300 + i * 380); });
  setMusic('menu', 0.35);
}
function renderCards() {
  const box = $('#cards'); box.innerHTML = ''; const ts = totalStars();
  COURSES.forEach((c, i) => {
    const rec = save.courses[c.id] || {}; const locked = ts < c.unlock;
    const d = document.createElement('button'); d.className = 'card' + (c.id === courseSel ? ' sel' : '') + (locked ? ' locked' : '');
    d.style.setProperty('--g', `linear-gradient(${c.card[0]},${c.card[1]})`); d.style.setProperty('--sea', c.card[2]);
    d.innerHTML = `<span class="sun"></span><span class="nm">${c.name}</span><span class="st">${[0, 1, 2].map((k) => `<svg class="i ${k < (rec.stars || 0) ? 'on' : ''}"><use href="#i-star"/></svg>`).join('')}</span><span class="bs">${rec.bestScore ? 'Best ' + fmt(rec.bestScore) : 'New!'}</span>` +
      (i === dailyIdx && !locked ? '<span class="rib">TODAY x2 GEMS</span>' : '') + (locked ? `<span class="lock"><svg class="i"><use href="#i-lock"/></svg><span>${c.unlock} ${c.unlock === 1 ? 'star' : 'stars'}</span></span>` : '');
    d.onclick = () => { unlockAudio(); sfx('click'); if (locked) { toast(`Collect ${c.unlock} stars to unlock!`); return; } courseSel = c.id; setTimeout(() => { loadCourse(c.id); path.at(0, F); }, 0); renderCards(); updateSel(); };
    box.appendChild(d);
  });
  const sel = box.querySelector('.sel'); if (sel) sel.scrollIntoView({ inline: 'center', block: 'nearest' });
}
function updateSel() { const c = COURSES.find((x) => x.id === courseSel); $('#selName').textContent = c.name; $('#selSub').textContent = c.sub + (COURSES[dailyIdx].id === c.id ? '  |  Today: double gems!' : ''); }
function renderUpgrades() {
  const box = $('#upList'); box.innerHTML = '';
  UPG.forEach((u) => {
    const lvl = save.up[u.id], max = lvl >= UCOST.length, cost = UCOST[lvl];
    const d = document.createElement('div'); d.className = 'up'; d.style.setProperty('--c1', u.c[0]); d.style.setProperty('--c2', u.c[1]);
    d.innerHTML = `<div class="ic"><svg class="i"><use href="#${u.icon}"/></svg></div><div><div class="nm">${u.name}</div><div class="ds">${u.desc}</div><div class="pips">${UCOST.map((_, i) => `<i class="${i < lvl ? 'on' : ''}"></i>`).join('')}</div></div>`;
    const b = document.createElement('button'); b.className = 'btn ' + (max ? 'glass' : 'green'); b.disabled = max || save.gems < cost;
    b.innerHTML = max ? 'MAX' : `<svg class="i" style="color:#5ff0ff"><use href="#i-gem"/></svg>${cost}`;
    b.onclick = () => { if (max || save.gems < cost) return; save.gems -= cost; save.up[u.id]++; persist(); sfx('powerup'); refreshGems(); renderUpgrades(); };
    d.appendChild(b); box.appendChild(d);
  });
}

// =================================================================== flow
function toTitle() { state = 'title'; hudMode('none'); hideAll(); showScreen('title'); paused = false; resetRun(); rider.root.visible = true; blob.material.opacity = 0.9; setMusic('menu', 0.4); }
function toSelect() { state = 'select'; hudMode('none'); hideAll(); showScreen('select'); renderCards(); updateSel(); resetRun(); loadCourse(courseSel); path.at(0, F); paused = false; clearHint(); setMusic('menu', 0.4); }
function startRun() {
  unlockAudio(); hideAll(); loadCourse(courseSel); resetRun(); paused = false;
  state = 'countdown'; cdTimer = 0; cdNum = 4; hudMode('slide'); refreshHudGems(); clearHint();
  rider.open = 0; rider.root.visible = true; flapCool = 0; input.flapQ = 0; frng = mulberry(courseSeedFor());
  fxK.flash = 0; landTimer = 0; fl.shake = 0; sl.shake = 0;
  setMusic('slide', 0.35);
}
const courseSeedFor = () => course.seed * 3 + daySeed + save.plays;
function refreshHudGems() { hudVals.gems = -1; el.gemVal.textContent = '0'; }
function beginSlide() { state = 'slide'; banner('GO!', '#ffffff'); sfx('whoosh'); sfx('powerup', { volume: 0.5 }); if (save.hints.slide < 3) { hintTimer = 5.5; setHint('Drag left and right to steer!', false); } sl.v = 6; }
function setPaused(p) {
  paused = p; if (p) { showScreen('pause'); music.setIntensity(0.1); } else { hideScreen('pause'); }
  if (!p) { input.id = null; input.down = false; }
}
function stepCountdown(dt) {
  cdTimer += dt; const n = 3 - Math.floor(cdTimer / 0.85);
  if (n !== cdNum && n >= 1) { cdNum = n; el.cd.textContent = n; el.cd.classList.remove('show'); void el.cd.offsetWidth; el.cd.classList.add('show'); sfx('click', { pitch: 0.8 + (3 - n) * 0.15 }); }
  placeRiderSlide(); poseO.mode = 'slide'; poseO.lean = 0; poseO.dive = 0; poseO.flapping = 0; poseO.speed01 = 0; poseO.t = time; rider.pose(dt, poseO);
  // camera swings from front to chase
  path.at(0, F); const k = clamp(cdTimer / 2.5, 0, 1);
  tgt.copy(rider.root.position).addScaledVector(F.T, lerp(5.5, -7.4, sstep(0, 1, k)) * camScale).addScaledVector(F.R, lerp(3.6, 0, sstep(0, 1, k))).addScaledVector(F.U, lerp(1.9, 3.3, k) * camScale);
  tgtLook.copy(rider.root.position).addScaledVector(F.U, 1.0).addScaledVector(F.T, lerp(0, 13, k)); camUpV.set(0, 1, 0);
  setCam(dt, 4.5); setFov(baseFov, dt); fxK.speed = 0; fxK.lines = 0;
  if (cdTimer >= 2.55) beginSlide();
}
function menuCamera(dt) {
  orbitT += dt; path.at(0, F);
  placeRiderSlide(); poseO.mode = 'slide'; poseO.lean = 0; poseO.dive = 0; poseO.flapping = 0; poseO.speed01 = 0.1; poseO.t = time; rider.pose(dt, poseO);
  const a = 1.3 + Math.sin(orbitT * 0.22) * 0.3, dist = (state === 'select' ? 11 : 10) * camScale;
  const portrait = W < H;
  const lookDown = state === 'select' ? (portrait ? -2.2 : -2.9) : (portrait ? 1.7 : -0.2); menuLook = damp(menuLook, lookDown, 2, dt);
  const sideOff = state === 'title' && !portrait ? -5.6 : 0; menuSide = damp(menuSide, sideOff, 2, dt);
  tgt.copy(F.p).addScaledVector(F.T, Math.cos(a) * dist).addScaledVector(F.R, Math.sin(a) * dist).addScaledVector(F.U, 6.5);
  tgtLook.copy(F.p).addScaledVector(F.U, 1.2 + menuLook).addScaledVector(F.T, 0.5);
  V1.subVectors(tgtLook, tgt).cross(UPV).normalize(); tgtLook.addScaledVector(V1, menuSide); camUpV.set(0, 1, 0);
  setCam(dt, state === 'select' || state === 'title' ? 3 : 6); setFov(baseFov, dt);
  fxK.speed = 0; fxK.lines = 0; fxK.vig = 0.35; blob.material.opacity = 0.9;
  music.setIntensity(0.4);
}

// =================================================================== main update / render
const fpsAvg = { v: 16, lowT: 0, hiT: 0, since: 0 };
let sunProj = new THREE.Vector3();
function updateFx(dt) {
  const u = post.u;
  u.speed.value = damp(u.speed.value, fxK.speed, 6, dt); u.vig.value = damp(u.vig.value, fxK.vig, 4, dt);
  fxK.flash = Math.max(0, fxK.flash - dt * 2.4); u.flash.value = fxK.flash * 0.5;
  // sun rays
  sunProj.copy(skyU.uSunDir.value).multiplyScalar(1000).add(camera.position).project(camera);
  const inFront = sunProj.z < 1; const vis = inFront ? 1 - sstep(0.85, 1.7, Math.max(Math.abs(sunProj.x), Math.abs(sunProj.y))) : 0;
  u.sunUV.value.set(sunProj.x * 0.5 + 0.5, sunProj.y * 0.5 + 0.5); u.rays.value = raysOn ? vis * 1.0 : 0;
  speedLines.draw(dt, fxK.lines, course && course.id === 'space' ? '200,230,255' : '255,255,255');
}
function update(dt) {
  time += dt;
  pollInput(dt);
  if (!paused) {
    let sdt = dt;
    if (launchSlow > 0) { launchSlow -= dt; sdt = dt * (0.55 + 0.45 * (1 - launchSlow / 0.9)); }
    if (state === 'title' || state === 'select') menuCamera(dt);
    else if (state === 'countdown') stepCountdown(dt);
    else if (state === 'slide') {
      stepSlide(sdt);
      if (state === 'slide' && hintTimer > 0) { hintTimer -= dt; if (hintTimer <= 0 || sl.t > 6) { clearHint(); save.hints.slide++; persist(); hintTimer = 0; } }
    }
    else if (state === 'flight') stepFlight(sdt);
    else if (state === 'landing' || state === 'results') stepLanding(dt);
  }
  // world & fx
  const ft = (state === 'slide' || state === 'countdown' || state === 'title' || state === 'select') ? path : null;
  if (state === 'flight' || state === 'landing' || state === 'results') { V1.set(fl.x, fl.y, fl.z); V2.copy(HV); }
  else { V1.copy(rider.root.position); path.at(Math.min(sl.s, path.L), F); V2.set(F.T.x, 0, F.T.z).normalize(); }
  const spd = state === 'flight' ? fl.v : state === 'slide' ? sl.v : 0;
  const scalePts = H * pr / (2 * Math.tan(camera.fov * Math.PI / 360));
  world.update(paused ? 0 : dt, V1, V2, camera.position, scalePts, spd);
  spray.update(paused ? 0 : dt, scalePts); glow.update(paused ? 0 : dt, scalePts);
  if (padInfo) padInfo.mat.uniforms.uTime.value = time; if (slideGroup && slideGroup.slideMesh) slideGroup.slideMesh.material.uniforms.uTime.value = time;
  if (state === 'flight' || state === 'landing') { updateBalloons(); } else if (balloonMesh && balloonMesh.count) { balloonMesh.count = 0; }
  if (state === 'title' || state === 'select' || state === 'countdown') { flightGems.mesh.count = 0; }
  if (state !== 'slide' && state !== 'countdown' && state !== 'title' && state !== 'select' && state !== 'results') slideGems.mesh.count = slideGems.mesh.count;
  if (state === 'title' || state === 'select' || state === 'countdown') slideGems.update(0, time, 0, 0, -9999, 0, 0, 0, () => {}, 60);
  if (state === 'flight' || state === 'landing' || state === 'results') { if (state !== 'flight') flightGems.update(0, time, fl.f, 0, -9999, 0, 0, 0, () => {}, 420); }
  for (const r of ripples) { if (r.t < 3) { r.t += dt; const k = clamp(r.t / 1.6, 0, 1); r.m.scale.setScalar(2 + r.s * k); r.m.material.opacity = (1 - k) * 0.85; if (k >= 1) { r.m.visible = false; r.t = 9; } } }
  updateFx(dt); updateHud();
}
function render(dt) { post.render(dt); }
function adapt(realDt) {
  fpsAvg.v += (realDt * 1000 - fpsAvg.v) * 0.05; fpsAvg.since += realDt;
  if (!adaptOn || fpsAvg.since < 2.5) return;
  if (fpsAvg.v > 24 && pr > 1) { pr = Math.max(1, pr - 0.25); fpsAvg.since = 0; fpsAvg.v = 16; resize(); }
  else if (fpsAvg.v > 24 && raysOn && pr <= 1) { raysOn = false; fpsAvg.since = 0; fpsAvg.v = 16; post.bloom.strength = 0.4; }
}
const MAXDT = qs.get('maxdt') ? parseFloat(qs.get('maxdt')) : 0.05;
let last = performance.now();
function frame(now) {
  requestAnimationFrame(frame);
  const real = Math.min((now - last) / 1000, 0.25); last = now;
  if (document.hidden || qs.has('manual')) return;
  const dt = Math.min(real, MAXDT);
  try { update(dt); render(dt); } catch (e) { console.error(e); }
  adapt(real);
}

// =================================================================== wiring
$('#btnPlay').onclick = () => { unlockAudio(); sfx('click'); toSelect(); };
$('#btnGo').onclick = () => { unlockAudio(); sfx('powerup', { volume: 0.5 }); startRun(); };
$('#btnSelBack').onclick = () => { sfx('click'); toTitle(); };
$('#btnUpg').onclick = () => { sfx('click'); renderUpgrades(); refreshGems(); showScreen('upgrades'); };
$('#btnUpg2').onclick = () => { sfx('click'); hideScreen('results'); state = 'select'; courseSel = course.id; showScreen('select'); renderCards(); updateSel(); renderUpgrades(); showScreen('upgrades'); resetRun(); setMusic('menu', 0.4); };
$('#btnUpClose').onclick = () => { sfx('click'); hideScreen('upgrades'); };
$('#btnPause').onclick = () => { sfx('click'); setPaused(true); };
$('#btnResume').onclick = () => { sfx('click'); setPaused(false); };
$('#btnRestart').onclick = () => { sfx('click'); hideScreen('pause'); startRun(); };
$('#btnQuitSel').onclick = () => { sfx('click'); hideScreen('pause'); toSelect(); };
$('#btnMusic').onclick = () => setMute(!save.muted);
for (const id of ['#btnMute', '#btnMuteT', '#btnMuteS']) $(id).onclick = () => { unlockAudio(); setMute(!save.muted); sfx('click'); };
$('#btnAgain').onclick = () => { sfx('click'); hideScreen('results'); startRun(); };
$('#btnCourses').onclick = () => { sfx('click'); toSelect(); };
document.addEventListener('visibilitychange', () => { if (document.hidden && (state === 'slide' || state === 'flight' || state === 'countdown') && !paused) setPaused(true); });

setMute(!!save.muted); refreshGems();
if (!COURSES.find((c) => c.id === courseSel) || totalStars() < COURSES.find((c) => c.id === courseSel).unlock) courseSel = 'island';
loadCourse(courseSel); path.at(0, F);
requestAnimationFrame(frame);
window.__sky = { music, D0, rider,
  get state() { return state; }, sl, fl, run, save, input, bot, course: () => course, path: () => path, items: () => items, THREE, camera, world, rings, pools, balloons, hoops, post,
  step(sec, dt = 1 / 30) { const n = Math.round(sec / dt); for (let i = 0; i < n; i++) update(dt); },
  setState(s) { state = s; }, startRun, toSelect, toTitle, showResults, setCourse(id) { courseSel = id; loadCourse(id); }, doFlap, renderNow() { render(0.016); }, frameNow() { update(1 / 30); render(1 / 30); }, setPaused
};
