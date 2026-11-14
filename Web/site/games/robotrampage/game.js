import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { Maestro } from '../shared/maestro.js';

// =====================================================================================================================
// helpers / save
// =====================================================================================================================
const $ = (id) => document.getElementById(id);
const clamp = (x, a, b) => Math.min(b, Math.max(a, x));
const rand = (a, b) => a + Math.random() * (b - a);
const TAU = Math.PI * 2;
const wrapPi = (a) => { while (a > Math.PI) a -= TAU; while (a < -Math.PI) a += TAU; return a; };
const QS = new URLSearchParams(location.search);
const SAVE_KEY = 'robotrampage.v1';
const save = { best: 0, bestWave: 0, stars: 0, lv: { foam: 1, twin: 0, mega: 0 }, eq: 'foam', seen: false, muted: false };
try { const s = JSON.parse(localStorage.getItem(SAVE_KEY) || 'null'); if (s) { Object.assign(save, s); save.lv = Object.assign({ foam: 1, twin: 0, mega: 0 }, s.lv || {}); } } catch (e) { /* ignore */ }
function persist() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(save)); } catch (e) { /* ignore */ } }

const WEAPONS = {
  foam: { name: 'Foam Blaster', desc: 'Fast, friendly foam blobs.', unlock: 0, color: 0xff5ec8, hex: '#ff5ec8', rate: [0.2, 0.16, 0.13], dmg: [1, 1, 2], pel: [1, 1, 1], spread: 0, speed: 78, size: 0.2, aoe: [0, 0, 0] },
  twin: { name: 'Twin Splat', desc: 'Two (then three!) splats at once.', unlock: 20, color: 0x40e0ff, hex: '#35d8ff', rate: [0.3, 0.26, 0.22], dmg: [1, 1, 1], pel: [2, 2, 3], spread: 0.07, speed: 72, size: 0.2, aoe: [0, 0, 0] },
  mega: { name: 'Mega Cannon', desc: 'Big boom blobs that splash!', unlock: 60, color: 0xffb52e, hex: '#ffb52e', rate: [0.8, 0.68, 0.56], dmg: [3, 4, 5], pel: [1, 1, 1], spread: 0, speed: 50, size: 0.5, aoe: [3, 3.6, 4.2] },
};
const WKEYS = ['foam', 'twin', 'mega'];
const upCost = (lv) => (lv === 1 ? 15 : 35);

// =====================================================================================================================
// audio
// =====================================================================================================================
const music = new Maestro();
music.muted = !!save.muted;
let curTheme = '';
function sfx(n, o) { try { music.sfx(n, o); } catch (e) { /* ignore */ } }
function playTheme(t, intensity) { try { if (curTheme !== t) { music.play(t, { intensity }); curTheme = t; } else music.setIntensity(intensity); } catch (e) { /* ignore */ } }
const ICON_SND_ON = '<svg viewBox="0 0 32 32"><path d="M4 12h5l7-6v20l-7-6H4z"/><path d="M20 10c2.600 2.200 2.600 9.800 0 12M23.500 6.500c4.800 4.600 4.800 14.400 0 19" fill="none" stroke="#fff" stroke-width="2.800" stroke-linecap="round"/></svg>';
const ICON_SND_OFF = '<svg viewBox="0 0 32 32"><path d="M4 12h5l7-6v20l-7-6H4z"/><path d="M21 12l8 8M29 12l-8 8" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/></svg>';
function refreshMute() {
  const h = save.muted ? ICON_SND_OFF : ICON_SND_ON;
  $('muteBtn').innerHTML = h; $('muteT').innerHTML = h; $('muteP').textContent = 'Music: ' + (save.muted ? 'Off' : 'On');
}
function toggleMute() { save.muted = !save.muted; try { music.unlock(); music.setMuted(save.muted); } catch (e) { /* ignore */ } persist(); refreshMute(); }

// =====================================================================================================================
// renderer / scene
// =====================================================================================================================
const stage = $('stage');
const DPR = Math.min(window.devicePixelRatio || 1, 2);
const renderer = new THREE.WebGLRenderer({ antialias: false, powerPreference: 'high-performance', stencil: false });
renderer.setPixelRatio(DPR);
renderer.setSize(innerWidth, innerHeight);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.85;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.shadowMap.autoUpdate = false;
stage.appendChild(renderer.domElement);

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x6a2c8e);
scene.fog = new THREE.Fog(0x8a3fa0, 38, 120);
const camera = new THREE.PerspectiveCamera(66, innerWidth / innerHeight, 0.05, 400);
camera.rotation.order = 'YXZ';
scene.add(camera);
const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
scene.environmentIntensity = 0.3;

const composer = new EffectComposer(renderer, new THREE.WebGLRenderTarget(innerWidth * DPR, innerHeight * DPR, { type: THREE.HalfFloatType, samples: 4 }));
composer.setPixelRatio(DPR);
composer.setSize(innerWidth, innerHeight);
composer.addPass(new RenderPass(scene, camera));
const bloom = new UnrealBloomPass(new THREE.Vector2(innerWidth / 2, innerHeight / 2), 0.42, 0.55, 1.05);
composer.addPass(bloom);
composer.addPass(new OutputPass());
let bloomOn = true;

let quality = 0;
function applyQuality() {
  const pr = quality === 0 ? DPR : quality === 1 ? Math.min(DPR, 1.5) : 1;
  renderer.setPixelRatio(pr); composer.setPixelRatio(pr); composer.setSize(innerWidth, innerHeight);
  bloomOn = quality < 2; bloom.enabled = bloomOn;
}

// ---------- textures
function canvasTex(w, h, draw, opts = {}) {
  const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
  if (opts.repeat) { t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(opts.repeat[0], opts.repeat[1]); }
  return t;
}
function rrect(g, x, y, w, h, r) { g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath(); }
const softTex = canvasTex(64, 64, (g) => { const r = g.createRadialGradient(32, 32, 0, 32, 32, 32); r.addColorStop(0, 'rgba(255,255,255,1)'); r.addColorStop(0.4, 'rgba(255,255,255,.55)'); r.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = r; g.fillRect(0, 0, 64, 64); });
const ringTex = canvasTex(128, 128, (g) => { const r = g.createRadialGradient(64, 64, 34, 64, 64, 62); r.addColorStop(0, 'rgba(255,255,255,0)'); r.addColorStop(0.55, 'rgba(255,255,255,1)'); r.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = r; g.fillRect(0, 0, 128, 128); });
const puffTex = canvasTex(128, 128, (g) => {
  g.clearRect(0, 0, 128, 128);
  for (let i = 0; i < 7; i++) { const x = 64 + Math.cos(i * 0.9) * 22, y = 64 + Math.sin(i * 1.7) * 22, r = g.createRadialGradient(x, y, 0, x, y, 40); r.addColorStop(0, 'rgba(255,255,255,.8)'); r.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = r; g.fillRect(0, 0, 128, 128); }
});

// ---------- sky
{
  const sky = new THREE.Mesh(new THREE.SphereGeometry(300, 32, 20), new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, fog: false,
    vertexShader: 'varying vec3 vP; void main(){ vP=normalize(position); gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }',
    fragmentShader: 'varying vec3 vP; void main(){ float h=vP.y; vec3 top=vec3(.025,.02,.16), mid=vec3(.17,.04,.32), hor=vec3(.85,.2,.34), low=vec3(.12,.04,.22); vec3 c = h>0. ? mix(hor, mix(mid, top, smoothstep(.2,.85,h)), smoothstep(0.,.4,h)) : mix(hor, low, smoothstep(0.,-.35,h)); gl_FragColor=vec4(c,1.); }',
  }));
  sky.renderOrder = -10; scene.add(sky);
  const N = 260, pos = new Float32Array(N * 3);
  for (let i = 0; i < N; i++) { const a = Math.random() * TAU, e = Math.acos(rand(0.15, 1)), r = 280; pos[i * 3] = Math.sin(e) * Math.cos(a) * r; pos[i * 3 + 1] = Math.cos(e) * r; pos[i * 3 + 2] = Math.sin(e) * Math.sin(a) * r; }
  const pg = new THREE.BufferGeometry(); pg.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  scene.add(new THREE.Points(pg, new THREE.PointsMaterial({ size: 2.4, sizeAttenuation: false, color: 0xfff2ff, fog: false, transparent: true, opacity: 0.85, depthWrite: false })));
}

// ---------- lights
scene.add(new THREE.HemisphereLight(0xb8b0ff, 0x6a2f9a, 0.6));
const sun = new THREE.DirectionalLight(0xffe8d0, 1.7);
sun.position.set(-16, 30, 12); sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048); sun.shadow.bias = -0.0004; sun.shadow.normalBias = 0.04;
Object.assign(sun.shadow.camera, { left: -32, right: 32, top: 32, bottom: -32, near: 5, far: 90 });
scene.add(sun);
const pl1 = new THREE.PointLight(0xff4fb0, 90, 46, 1.6); pl1.position.set(0, 8, -18); scene.add(pl1);
const pl2 = new THREE.PointLight(0x30d8ff, 90, 46, 1.6); pl2.position.set(0, 8, 18); scene.add(pl2);

// ---------- materials
const std = (color, o = {}) => new THREE.MeshStandardMaterial(Object.assign({ color, roughness: 0.5, metalness: 0.02 }, o));
const hdr = (r, g, b, o = {}) => { const m = new THREE.MeshBasicMaterial(Object.assign({ toneMapped: false }, o)); m.color.setRGB(r, g, b); return m; };
const MAT = {
  white: std(0xffffff, { roughness: 0.3 }), dark: std(0x2a2352, { roughness: 0.4 }), metal: std(0xc7cde6, { roughness: 0.25, metalness: 0.7 }),
  gold: std(0xffc83a, { roughness: 0.25, metalness: 0.6 }),
};
const GC = new Map();
const rb = (w, h, d, r = 0.1, s = 3) => { const k = `rb${w},${h},${d},${r}`; if (!GC.has(k)) GC.set(k, new RoundedBoxGeometry(w, h, d, s, r)); return GC.get(k); };
const sph = (r, ws = 16, hs = 12) => { const k = `sp${r},${ws}`; if (!GC.has(k)) GC.set(k, new THREE.SphereGeometry(r, ws, hs)); return GC.get(k); };
const cyl = (r1, r2, h, s = 14) => { const k = `cy${r1},${r2},${h},${s}`; if (!GC.has(k)) GC.set(k, new THREE.CylinderGeometry(r1, r2, h, s)); return GC.get(k); };
const tor = (r, t, a = TAU, rs = 6, ts = 18) => { const k = `to${r},${t},${a}`; if (!GC.has(k)) GC.set(k, new THREE.TorusGeometry(r, t, rs, ts, a)); return GC.get(k); };
function mesh(geo, mat, parent, x = 0, y = 0, z = 0, shadow = false) { const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); if (shadow) { m.castShadow = true; m.receiveShadow = true; } if (parent) parent.add(m); return m; }

// =====================================================================================================================
// arena
// =====================================================================================================================
const ARENA_R = 28;
const arena = new THREE.Group(); scene.add(arena);
const gears = [], balloons = [], gates = [];
{
  // floor
  const floorTex = canvasTex(2048, 2048, (g, w, h) => {
    const n = 16, s = w / n, pal = [['#7b5ce0', '#6a4cd2'], ['#5c8cf0', '#4f7be4']];
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
      const p = pal[(x + y) & 1]; const gr = g.createLinearGradient(x * s, y * s, x * s + s, y * s + s); gr.addColorStop(0, p[0]); gr.addColorStop(1, p[1]);
      g.fillStyle = gr; g.fillRect(x * s, y * s, s, s);
      g.strokeStyle = 'rgba(255,255,255,.18)'; g.lineWidth = 6; g.strokeRect(x * s + 5, y * s + 5, s - 10, s - 10);
      g.strokeStyle = 'rgba(20,10,60,.35)'; g.lineWidth = 3; g.strokeRect(x * s, y * s, s, s);
    }
    const acc = ['#ffd23f', '#ff5fb0', '#35d8ff', '#6bf08a', '#ff9a3d'];
    for (let i = 0; i < 26; i++) { const x = (Math.random() * n) | 0, y = (Math.random() * n) | 0; g.fillStyle = acc[i % 5]; g.globalAlpha = 0.85; rrect(g, x * s + 12, y * s + 12, s - 24, s - 24, 22); g.fill(); g.globalAlpha = 1; g.fillStyle = 'rgba(255,255,255,.35)'; g.beginPath(); g.arc(x * s + s / 2, y * s + s / 2, s * 0.17, 0, TAU); g.fill(); }
    // soft vignette to the rim
    const v = g.createRadialGradient(w / 2, h / 2, w * 0.3, w / 2, h / 2, w * 0.5); v.addColorStop(0, 'rgba(10,0,40,0)'); v.addColorStop(1, 'rgba(10,0,40,.5)'); g.fillStyle = v; g.fillRect(0, 0, w, h);
  });
  const floor = new THREE.Mesh(new THREE.CircleGeometry(ARENA_R + 0.6, 96), std(0xffffff, { map: floorTex, roughness: 0.38, metalness: 0.05 }));
  floor.rotation.x = -Math.PI / 2; floor.receiveShadow = true; arena.add(floor);
  // outer ground
  const out = new THREE.Mesh(new THREE.CircleGeometry(200, 48), std(0x2c1466, { roughness: 0.9 })); out.rotation.x = -Math.PI / 2; out.position.y = -0.05; arena.add(out);
  // player pad
  const pad = new THREE.Mesh(new THREE.RingGeometry(1.6, 2.1, 48), hdr(0.2, 1.6, 2.2, { transparent: true, opacity: 0.8 })); pad.rotation.x = -Math.PI / 2; pad.position.y = 0.02; arena.add(pad);
  const pad2 = new THREE.Mesh(new THREE.RingGeometry(3.1, 3.25, 64), hdr(1.8, 0.5, 1.6, { transparent: true, opacity: 0.55 })); pad2.rotation.x = -Math.PI / 2; pad2.position.y = 0.02; arena.add(pad2);
  // floor neon rim
  const rim = mesh(new THREE.TorusGeometry(ARENA_R, 0.28, 8, 96), hdr(2.2, 0.5, 1.6), arena, 0, 0.28, 0); rim.rotation.x = Math.PI / 2;

  // walls
  const wallTex = canvasTex(1024, 512, (g, w, h) => {
    const gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, '#7a52d8'); gr.addColorStop(1, '#4d2fa8'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
    for (let i = 0; i < 4; i++) { const x = i * 256; g.fillStyle = 'rgba(255,255,255,.14)'; rrect(g, x + 18, 40, 220, 300, 22); g.fill(); g.fillStyle = '#25125e'; rrect(g, x + 36, 58, 184, 168, 16); g.fill(); const cl = ['#ffd23f', '#ff5fb0', '#35d8ff', '#6bf08a'][i]; const gg = g.createLinearGradient(0, 58, 0, 226); gg.addColorStop(0, cl); gg.addColorStop(1, 'rgba(255,255,255,.2)'); g.fillStyle = gg; g.globalAlpha = 0.55; rrect(g, x + 44, 66, 168, 152, 12); g.fill(); g.globalAlpha = 1; }
    // hazard stripe at the bottom
    for (let x = -40; x < w + 60; x += 56) { g.fillStyle = '#ffcf2a'; g.beginPath(); g.moveTo(x, h); g.lineTo(x + 28, h); g.lineTo(x + 56, h - 70); g.lineTo(x + 28, h - 70); g.fill(); }
    g.fillStyle = '#3a2480'; g.fillRect(0, h - 78, w, 8);
  }, { repeat: [10, 1] });
  const wall = new THREE.Mesh(new THREE.CylinderGeometry(ARENA_R + 1.2, ARENA_R + 1.2, 12, 80, 1, true), std(0xffffff, { map: wallTex, side: THREE.BackSide, roughness: 0.6 }));
  wall.position.y = 6; wall.receiveShadow = true; arena.add(wall);
  [[2.0, [0.3, 1.8, 2.4]], [8.2, [2.4, 0.5, 1.8]], [12, [0.6, 2.0, 2.4]]].forEach(([y, c]) => { const t = mesh(new THREE.TorusGeometry(ARENA_R + 1.1, 0.22, 8, 96), hdr(c[0], c[1], c[2]), arena, 0, y, 0); t.rotation.x = Math.PI / 2; });

  // distant skyline of toy blocks
  const winTex = canvasTex(64, 128, (g, w, h) => { g.fillStyle = '#000'; g.fillRect(0, 0, w, h); for (let y = 4; y < h; y += 16) for (let x = 6; x < w; x += 16) { if (Math.random() < 0.55) { g.fillStyle = Math.random() < 0.5 ? '#ffd86b' : '#ff8ad0'; g.fillRect(x, y, 8, 8); } } });
  const sk = new THREE.InstancedMesh(new THREE.BoxGeometry(1, 1, 1), std(0xffffff, { roughness: 0.8, emissive: 0xffffff, emissiveMap: winTex, emissiveIntensity: 0.9 }), 70);
  const dm = new THREE.Object3D(), cc = new THREE.Color(); const cols = [0x6a3fc8, 0x3f7be0, 0xd84fa0, 0x3fbfa8, 0xe8a030];
  for (let i = 0; i < 70; i++) { const a = (i / 70) * TAU + rand(-0.03, 0.03), r = rand(52, 95), w = rand(8, 18), h = rand(16, 52); dm.position.set(Math.sin(a) * r, h / 2 - 3, Math.cos(a) * r); dm.scale.set(w, h, w); dm.rotation.y = rand(0, 3); dm.updateMatrix(); sk.setMatrixAt(i, dm.matrix); sk.setColorAt(i, cc.setHex(cols[i % 5])); }
  arena.add(sk);

  // spawn gates
  for (let i = 0; i < 12; i++) {
    const a = i * Math.PI / 6, g = new THREE.Group(); g.position.set(-Math.sin(a) * (ARENA_R + 0.4), 0, -Math.cos(a) * (ARENA_R + 0.4)); g.rotation.y = Math.atan2(Math.sin(a), Math.cos(a));
    g.rotation.y = Math.atan2(-g.position.x, -g.position.z);
    const col = [[2.4, 0.5, 1.6], [0.4, 1.8, 2.4], [2.4, 1.8, 0.4], [0.6, 2.2, 0.8]][i % 4];
    const door = hdr(col[0] * 0.25, col[1] * 0.25, col[2] * 0.25, { side: THREE.DoubleSide });
    mesh(new THREE.PlaneGeometry(4.4, 4.6), door, g, 0, 2.3, -0.1);
    const frameM = hdr(col[0], col[1], col[2]);
    mesh(rb(0.7, 5.4, 1, 0.3), std(0xffe9b0, { roughness: 0.4 }), g, -2.5, 2.7, 0, true); mesh(rb(0.7, 5.4, 1, 0.3), std(0xffe9b0, { roughness: 0.4 }), g, 2.5, 2.7, 0, true);
    mesh(rb(6.2, 0.8, 1, 0.3), std(0xffe9b0, { roughness: 0.4 }), g, 0, 5.3, 0, true);
    mesh(new THREE.BoxGeometry(5.6, 0.18, 0.2), frameM, g, 0, 4.85, 0.52);
    arena.add(g); gates.push({ g, door, base: col, flash: 0 });
  }

  // striped pillars
  const stripe = canvasTex(64, 256, (g, w, h) => { for (let y = 0; y < 8; y++) { g.fillStyle = y % 2 ? '#fff' : '#ff4f9a'; g.fillRect(0, y * 32, w, 32); } }, { repeat: [3, 1] });
  for (let i = 0; i < 12; i++) { const a = (i + 0.5) * Math.PI / 6; const p = mesh(new THREE.CylinderGeometry(0.9, 0.9, 12, 24), std(0xffffff, { map: stripe, roughness: 0.4 }), arena, -Math.sin(a) * (ARENA_R + 0.3), 6, -Math.cos(a) * (ARENA_R + 0.3), true); p.material.map.repeat.set(3, 1); mesh(sph(1.05), std(0xffd23f), p, 0, 6.2, 0); }

  // gears on the wall
  function gearGeo(n, ro, ri, hole) {
    const s = new THREE.Shape();
    for (let i = 0; i < n; i++) { const a0 = (i / n) * TAU, a1 = ((i + 0.22) / n) * TAU, a2 = ((i + 0.5) / n) * TAU, a3 = ((i + 0.72) / n) * TAU; const pts = [[ri, a0], [ro, a1], [ro, a2], [ri, a3]]; pts.forEach(([r, a], j) => { const x = Math.cos(a) * r, y = Math.sin(a) * r; if (i === 0 && j === 0) s.moveTo(x, y); else s.lineTo(x, y); }); }
    const h = new THREE.Path(); h.absarc(0, 0, hole, 0, TAU, true); s.holes.push(h);
    return new THREE.ExtrudeGeometry(s, { depth: 0.8, bevelEnabled: true, bevelSize: 0.12, bevelThickness: 0.12, bevelSegments: 2, curveSegments: 6 });
  }
  [[0.25, 9, 5.5, 0xffc83a, 1, 0.5], [0.75, 6, 4.4, 0x35d8ff, -1.4, 0.4], [1.6, 7.5, 7.5, 0xff5fb0, 1.2, 0.5], [1.15, 5.5, 8.3, 0x6bf08a, -1.6, 0.4]].forEach(([a, r, y, col, sp]) => {
    const g = new THREE.Group(); const ang = a * Math.PI + (a > 1 ? 0 : 0) + Math.PI; const rr = ARENA_R + 0.7;
    g.position.set(Math.sin(ang * 1.0) * rr, y, Math.cos(ang * 1.0) * rr); g.rotation.y = Math.atan2(-g.position.x, -g.position.z);
    const gm = new THREE.Mesh(gearGeo(14, r * 0.5, r * 0.4, r * 0.15), std(col, { roughness: 0.35, metalness: 0.3 })); gm.castShadow = false; g.add(gm); arena.add(g); gears.push({ m: gm, sp });
  });
  [[-1.9, 8.2, 0xffc83a, 1.2], [2.6, 7.4, 0x35d8ff, -1.4], [-0.6, 9.4, 0xff5fb0, 1], [0.7, 7, 0x6bf08a, -1]].forEach(([a, y, col, sp], i) => {
    const g = new THREE.Group(); const ang = a, rr = ARENA_R + 0.7; g.position.set(Math.sin(ang) * rr, y, Math.cos(ang) * rr); g.rotation.y = Math.atan2(-g.position.x, -g.position.z);
    const gm = new THREE.Mesh(gearGeo(12, 3.4 + i % 2, 2.7 + i % 2 * 0.8, 0.8), std(col, { roughness: 0.35, metalness: 0.3 })); g.add(gm); arena.add(g); gears.push({ m: gm, sp });
  });

  // ABC blocks + toy props
  const letters = 'ABCDEFGHKLMNOPRSTW'; const bcols = ['#ff5fb0', '#ffd23f', '#35d8ff', '#6bf08a', '#ff9a3d', '#b57bff'];
  function blockMats(i) {
    const mats = [];
    for (let f = 0; f < 6; f++) {
      const c = bcols[(i + f) % 6], l = letters[(i * 5 + f * 3) % letters.length];
      mats.push(std(0xffffff, { roughness: 0.45, map: canvasTex(128, 128, (g, w, h) => { g.fillStyle = c; g.fillRect(0, 0, w, h); g.fillStyle = 'rgba(255,255,255,.28)'; rrect(g, 8, 8, 112, 112, 18); g.fill(); g.fillStyle = '#fff'; g.font = '900 78px ui-rounded, system-ui, sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(l, 64, 70); g.strokeStyle = 'rgba(0,0,0,.2)'; g.lineWidth = 3; g.strokeText(l, 64, 70); }) }));
    }
    return mats;
  }
  const placed = [];
  function spot(minR, maxR, clear) { for (let k = 0; k < 30; k++) { const a = rand(0, TAU), r = rand(minR, maxR), x = Math.sin(a) * r, z = Math.cos(a) * r; if (placed.every((p) => Math.hypot(p[0] - x, p[1] - z) > p[2] + clear)) return [x, z, a]; } return null; }
  for (let i = 0; i < 11; i++) {
    const s = rand(1.5, 2.5), sp = spot(11, ARENA_R - 3, s * 0.9 + 2); if (!sp) continue; placed.push([sp[0], sp[1], s * 0.9]);
    const b = new THREE.Mesh(rb(s, s, s, 0.18), blockMats(i)); b.position.set(sp[0], s / 2, sp[1]); b.rotation.y = rand(0, 3); b.castShadow = b.receiveShadow = true; arena.add(b);
    if (Math.random() < 0.4) { const s2 = s * 0.7; const b2 = new THREE.Mesh(rb(s2, s2, s2, 0.14), blockMats(i + 3)); b2.position.set(sp[0] + rand(-0.2, 0.2), s + s2 / 2, sp[1] + rand(-0.2, 0.2)); b2.rotation.y = rand(0, 3); b2.castShadow = true; arena.add(b2); }
  }
  // lollipop / candy cylinders and toy drums
  for (let i = 0; i < 6; i++) {
    const sp = spot(11, ARENA_R - 3, 3); if (!sp) continue; placed.push([sp[0], sp[1], 1.6]);
    const h = rand(1.2, 2.6), col = [0xff5fb0, 0x35d8ff, 0xffd23f, 0x6bf08a][i % 4];
    const g = new THREE.Group(); g.position.set(sp[0], 0, sp[1]);
    mesh(cyl(1.3, 1.3, h, 24), std(col, { roughness: 0.35 }), g, 0, h / 2, 0, true); mesh(cyl(1.38, 1.38, 0.25, 24), std(0xffffff, { roughness: 0.3 }), g, 0, h + 0.12, 0, true); mesh(cyl(1.38, 1.38, 0.25, 24), std(0xffffff, { roughness: 0.3 }), g, 0, 0.12, 0, true);
    const star = mesh(sph(0.4), hdr(1.8, 1.6, 0.4), g, 0, h + 0.7, 0); star.scale.set(1, 0.8, 1); arena.add(g);
  }
  // balloons
  const bgeo = new THREE.SphereGeometry(0.9, 20, 16); bgeo.scale(1, 1.18, 1);
  const bm = new THREE.InstancedMesh(bgeo, std(0xffffff, { roughness: 0.15, metalness: 0.1 }), 26);
  for (let i = 0; i < 26; i++) { const a = rand(0, TAU), r = rand(14, 25); balloons.push({ x: Math.sin(a) * r, z: Math.cos(a) * r, y: rand(3, 9), ph: rand(0, 6) }); bm.setColorAt(i, cc.set(bcols[i % 6])); }
  bm.frustumCulled = false; arena.add(bm); balloons.mesh = bm;
  // light bulbs string overhead ring
  const bulbs = new THREE.InstancedMesh(new THREE.SphereGeometry(0.28, 8, 6), hdr(1, 1, 1), 48);
  for (let i = 0; i < 48; i++) { const a = (i / 48) * TAU, r = ARENA_R - 1; dm.position.set(Math.sin(a) * r, 10.3 - Math.sin(i * 1.3) * 0.5 + 0, Math.cos(a) * r); dm.scale.setScalar(1); dm.rotation.set(0, 0, 0); dm.updateMatrix(); bulbs.setMatrixAt(i, dm.matrix); const c = [[2.4, 1.8, 0.4], [2.4, 0.5, 1.6], [0.4, 1.8, 2.4], [0.6, 2.2, 0.8]][i % 4]; bulbs.setColorAt(i, cc.setRGB(c[0], c[1], c[2])); }
  arena.add(bulbs);
}
function updateAmbient(t, dt) {
  for (const g of gears) g.m.rotation.z += g.sp * dt * 0.5;
  const bm = balloons.mesh, dm = AMB;
  for (let i = 0; i < balloons.length; i++) { const b = balloons[i]; dm.position.set(b.x, b.y + Math.sin(t * 0.8 + b.ph) * 0.5, b.z); dm.rotation.set(0, 0, 0); dm.scale.setScalar(1); dm.updateMatrix(); bm.setMatrixAt(i, dm.matrix); }
  bm.instanceMatrix.needsUpdate = true;
  for (const g of gates) { if (g.flash > 0) { g.flash = Math.max(0, g.flash - dt * 1.5); } const k = 0.25 + g.flash * 1.6 + 0.05 * Math.sin(t * 2); g.door.color.setRGB(g.base[0] * k, g.base[1] * k, g.base[2] * k); }
}
const AMB = new THREE.Object3D();

// blob shadow
const blobMat = new THREE.MeshBasicMaterial({ map: softTex, color: 0x120830, transparent: true, opacity: 0.55, depthWrite: false, fog: false });
const blobGeo = new THREE.PlaneGeometry(1, 1); blobGeo.rotateX(-Math.PI / 2);

// =====================================================================================================================
// robots
// =====================================================================================================================
const PAL = {
  walker: [[0xffb02e, 0xff6f91], [0x4fd1ff, 0xffd23f], [0x6be38a, 0xff8ac6]],
  roller: [[0x4f7bff, 0xffd23f], [0xb36bff, 0x6bf0e0]],
  drone: [[0xb36bff, 0xff8ac6], [0xff6f91, 0xffd23f]],
  armor: [[0x38c9a6, 0xffc83a]],
  boss: [[0xff4f6d, 0xffc83a]],
};
const GLOW = { walker: [0.4, 2.2, 2.6], roller: [2.4, 1.8, 0.4], drone: [2.4, 0.5, 1.8], armor: [0.6, 2.4, 1.0], boss: [2.6, 1.0, 0.3] };
const glowMats = {}; for (const k in GLOW) glowMats[k] = hdr(...GLOW[k]);
const eyeMat = std(0xffffff, { roughness: 0.15 }), pupilMat = std(0x1a1040, { roughness: 0.2 });

function faceParts(parent, y, z, sc, kind, o = {}) {
  const eyes = [];
  for (const s of [-1, 1]) {
    const w = mesh(sph(0.21 * sc), eyeMat, parent, s * 0.25 * sc, y, z); w.scale.set(1, 1.1, 0.8);
    const p = mesh(sph(0.115 * sc), pupilMat, parent, s * 0.25 * sc, y - 0.01 * sc, z + 0.1 * sc);
    mesh(sph(0.04 * sc, 8, 6), eyeMat, p, 0.03 * sc, 0.045 * sc, 0.09 * sc);
    eyes.push(w);
  }
  const sm = mesh(tor(0.16 * sc, 0.03 * sc, Math.PI, 5, 14), pupilMat, parent, 0, y - 0.2 * sc, z - 0.01 * sc); sm.rotation.z = Math.PI;
  for (const s of [-1, 1]) mesh(sph(0.07 * sc, 8, 6), hdr(2.5, 0.6, 1.0), parent, s * 0.42 * sc, y - 0.14 * sc, z - 0.1 * sc).scale.set(1, 0.6, 0.4);
  return eyes;
}

function buildHumanoid(kind, o) {
  const [skinC, trimC] = o.pal;
  const root = new THREE.Group(), vis = new THREE.Group(); root.add(vis);
  const skin = std(skinC, { roughness: 0.38, metalness: 0.05 }), trim = std(trimC, { roughness: 0.38, metalness: 0.05 });
  const sc = 1; const legs = [], arms = [];
  for (const s of [-1, 1]) {
    const lp = new THREE.Group(); lp.position.set(s * 0.32, 0.8, 0); vis.add(lp);
    mesh(cyl(0.14, 0.17, 0.62, 12), MAT.metal, lp, 0, -0.32, 0); mesh(rb(0.46, 0.22, 0.64, 0.1), trim, lp, 0, -0.68, 0.08); legs.push(lp);
    const ap = new THREE.Group(); ap.position.set(s * 0.74, 1.78, 0); vis.add(ap);
    mesh(cyl(0.11, 0.1, 0.62, 10), trim, ap, 0, -0.32, 0); mesh(sph(0.2, 12, 10), skin, ap, 0, -0.7, 0); arms.push(ap);
  }
  const body = mesh(rb(1.1, 1.0, 0.84, 0.22), skin, vis, 0, 1.4, 0);
  mesh(rb(0.52, 0.4, 0.12, 0.06), glowMats[kind], vis, 0, 1.42, 0.43);
  mesh(rb(1.14, 0.18, 0.88, 0.08), trim, vis, 0, 0.98, 0);
  const head = new THREE.Group(); head.position.set(0, 2.3, 0); vis.add(head);
  mesh(rb(1.04, 0.84, 0.88, 0.26), trim, head, 0, 0, 0);
  const eyes = faceParts(head, 0.04, 0.41, 1.05, kind);
  mesh(cyl(0.03, 0.03, 0.32, 6), MAT.metal, head, 0, 0.58, 0); const ball = mesh(sph(0.11), glowMats[kind], head, 0, 0.78, 0);
  for (const s of [-1, 1]) { const e = mesh(cyl(0.13, 0.13, 0.2, 12), MAT.metal, head, s * 0.58, 0, 0); e.rotation.z = Math.PI / 2; }
  if (o.helmet) { const h = mesh(new THREE.SphereGeometry(0.62, 18, 10, 0, TAU, 0, Math.PI / 2), MAT.gold, head, 0, 0.18, 0); h.scale.set(1, 0.85, 0.95); mesh(rb(0.16, 0.5, 0.9, 0.06), skin, head, 0, 0.5, 0); for (const s of [-1, 1]) mesh(sph(0.3, 12, 10), MAT.gold, vis, s * 0.72, 1.85, 0).scale.set(1, 0.7, 1); }
  if (o.crown) {
    for (let i = 0; i < 5; i++) { const a = (i / 5) * TAU; const c = mesh(new THREE.ConeGeometry(0.15, 0.4, 6), MAT.gold, head, Math.sin(a) * 0.36, 0.62, Math.cos(a) * 0.3); mesh(sph(0.07, 8, 6), hdr(2.4, 0.6, 1.2), c, 0, 0.22, 0); }
    mesh(cyl(0.42, 0.46, 0.14, 16), MAT.gold, head, 0, 0.45, 0);
    for (const s of [-1, 1]) { const b = mesh(rb(0.4, 0.09, 0.1, 0.04), pupilMat, head, s * 0.26, 0.3, 0.45); b.rotation.z = -s * 0.35; }
    for (const a of arms) a.children[1].scale.setScalar(1.5);
  }
  const hit = { cy: 1.4 * o.scale, r: o.r };
  vis.scale.setScalar(o.scale);
  return { root, vis, skin, trim, legs, arms, head, ball, eyes, hit, kind, body };
}

function buildRoller(o) {
  const [skinC, trimC] = o.pal; const root = new THREE.Group(), vis = new THREE.Group(); root.add(vis);
  const skin = std(skinC, { roughness: 0.3 }), trim = std(trimC, { roughness: 0.3 });
  const spin = new THREE.Group(); spin.position.y = 0.85; vis.add(spin);
  mesh(sph(0.85, 24, 16), skin, spin, 0, 0, 0);
  for (let i = 0; i < 3; i++) { const t = mesh(tor(0.85, 0.09, TAU, 6, 32), trim, spin, 0, 0, 0); t.rotation.set(i === 0 ? Math.PI / 2 : 0, i === 1 ? Math.PI / 2 : 0, 0); }
  mesh(sph(0.2), MAT.gold, spin, 0, 0, 0.0).scale.setScalar(0.01);
  const head = new THREE.Group(); head.position.set(0, 1.95, 0); vis.add(head);
  mesh(cyl(0.16, 0.2, 0.3, 10), MAT.metal, vis, 0, 1.65, 0);
  mesh(rb(0.96, 0.76, 0.84, 0.26), trim, head, 0, 0, 0);
  faceParts(head, 0.03, 0.39, 1.0, 'roller');
  mesh(cyl(0.03, 0.03, 0.28, 6), MAT.metal, head, 0, 0.52, 0); const ball = mesh(sph(0.11), glowMats.roller, head, 0, 0.7, 0);
  vis.scale.setScalar(o.scale);
  return { root, vis, skin, trim, spin, head, ball, legs: [], arms: [], hit: { cy: 1.2 * o.scale, r: 1.05 * o.scale }, kind: 'roller' };
}

function buildDrone(o) {
  const [skinC, trimC] = o.pal; const root = new THREE.Group(), vis = new THREE.Group(); root.add(vis);
  const skin = std(skinC, { roughness: 0.28 }), trim = std(trimC, { roughness: 0.28 });
  const b = mesh(sph(0.62, 22, 16), skin, vis, 0, 0, 0); b.scale.set(1, 0.85, 1);
  const bt = mesh(tor(0.62, 0.08, TAU, 6, 28), trim, vis, 0, 0, 0); bt.rotation.x = Math.PI / 2;
  const w = mesh(sph(0.36, 18, 14), eyeMat, vis, 0, 0.05, 0.4); w.scale.set(1, 1, 0.7);
  const pu = mesh(sph(0.19, 12, 10), pupilMat, vis, 0, 0.05, 0.66); mesh(sph(0.06, 8, 6), eyeMat, pu, 0.05, 0.07, 0.1);
  const belly = mesh(cyl(0.28, 0.2, 0.12, 14), glowMats.drone, vis, 0, -0.5, 0);
  mesh(cyl(0.03, 0.03, 0.35, 6), MAT.metal, vis, 0, 0.7, 0); const ball = mesh(sph(0.11), glowMats.drone, vis, 0, 0.92, 0);
  const rotors = [];
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    const arm = mesh(cyl(0.05, 0.05, 0.9, 6), MAT.metal, vis, sx * 0.5, 0.25, sz * 0.5); arm.rotation.set(sz * 0.0, 0, sx * 1.2); arm.rotation.order = 'ZYX'; arm.rotation.y = 0; arm.position.set(sx * 0.4, 0.2, sz * 0.4);
    arm.lookAt(sx * 0.9, 0.5, sz * 0.9); arm.rotateX(Math.PI / 2);
    const rg = new THREE.Group(); rg.position.set(sx * 0.82, 0.55, sz * 0.82); vis.add(rg);
    const d = mesh(cyl(0.46, 0.46, 0.03, 20), trim, rg, 0, 0, 0); d.material = new THREE.MeshStandardMaterial({ color: trimC, transparent: true, opacity: 0.5, roughness: 0.3 });
    mesh(rb(0.9, 0.04, 0.12, 0.02), MAT.white, rg, 0, 0.03, 0); rotors.push(rg);
  }
  vis.scale.setScalar(o.scale);
  return { root, vis, skin, trim, rotors, belly, ball, legs: [], arms: [], hit: { cy: 0, r: 0.95 * o.scale }, kind: 'drone' };
}

const DEFS = {
  walker: { n: 12, hp: 1, speed: 1.9, score: 100, stars: 1, build: (i) => buildHumanoid('walker', { pal: PAL.walker[i % 3], scale: 1.25, r: 1.25 }), r: 1.25 },
  roller: { n: 8, hp: 1, speed: 4.4, score: 130, stars: 1, build: (i) => buildRoller({ pal: PAL.roller[i % 2], scale: 1.2 }), r: 1.05 },
  drone: { n: 7, hp: 1, speed: 3, score: 160, stars: 2, build: (i) => buildDrone({ pal: PAL.drone[i % 2], scale: 1.25 }), r: 0.95 },
  armor: { n: 5, hp: 3, speed: 1.5, score: 260, stars: 3, build: () => buildHumanoid('armor', { pal: PAL.armor[0], scale: 1.8, r: 1.9, helmet: true }), r: 1.5 },
  boss: { n: 1, hp: 30, speed: 1.4, score: 2500, stars: 20, build: () => buildHumanoid('boss', { pal: PAL.boss[0], scale: 3.1, r: 3.6, crown: true }), r: 3.2 },
};
const enemies = [];
const pools = {};
for (const k in DEFS) {
  pools[k] = [];
  for (let i = 0; i < DEFS[k].n; i++) {
    const b = DEFS[k].build(i); const e = Object.assign(b, { type: k, def: DEFS[k], alive: false, hp: 1, maxhp: 1, x: 0, z: 0, y: 0, t: 0, sq: 0, fl: 0, ph: 0, st: 0, ang: 0, dir: 1, cool: 0, charge: 0, spawnT: 0, spd: 1, hd: 12, sumT: 0 });
    e.cy = b.hit.cy; e.r = b.hit.r;
    b.root.visible = false; scene.add(b.root);
    e.blob = new THREE.Mesh(blobGeo, blobMat); e.blob.visible = false; e.blob.position.y = 0.03; scene.add(e.blob);
    pools[k].push(e);
  }
}
function setFlash(e, v) { e.skin.emissive.setRGB(v, v * 0.9, v * 0.9); e.trim.emissive.setRGB(v, v * 0.9, v * 0.9); }

// =====================================================================================================================
// particles
// =====================================================================================================================
const dummy = new THREE.Object3D();
const tmpC = new THREE.Color();
class PPool {
  constructor(geo, mat, n) {
    this.m = new THREE.InstancedMesh(geo, mat, n); this.m.frustumCulled = false; this.n = n; this.i = 0; this.dirty = true;
    this.p = []; for (let i = 0; i < n; i++) { this.p.push({ x: 0, y: -50, z: 0, vx: 0, vy: 0, vz: 0, rx: 0, ry: 0, rz: 0, wx: 0, wy: 0, wz: 0, life: 0, max: 1, s: 1, g: 14, bounce: true }); this.m.setColorAt(i, tmpC.setHex(0xffffff)); dummy.scale.setScalar(0); dummy.updateMatrix(); this.m.setMatrixAt(i, dummy.matrix); }
    scene.add(this.m);
  }
  emit(x, y, z, vx, vy, vz, life, s, color, g = 14, spin = 9, bounce = true) {
    const idx = this.i, p = this.p[idx]; this.i = (idx + 1) % this.n;
    p.x = x; p.y = y; p.z = z; p.vx = vx; p.vy = vy; p.vz = vz; p.life = p.max = life; p.s = s; p.g = g; p.bounce = bounce;
    p.rx = rand(0, TAU); p.ry = rand(0, TAU); p.rz = rand(0, TAU); p.wx = rand(-spin, spin); p.wy = rand(-spin, spin); p.wz = rand(-spin, spin);
    if (typeof color === 'number') tmpC.setHex(color); else tmpC.copy(color);
    this.m.setColorAt(idx, tmpC); this.m.instanceColor.needsUpdate = true; this.dirty = true;
  }
  update(dt) {
    if (!this.dirty) return; let any = false;
    for (let i = 0; i < this.n; i++) {
      const p = this.p[i]; if (p.life <= 0) continue;
      p.life -= dt; any = true;
      if (p.life <= 0) { dummy.scale.setScalar(0); dummy.position.set(0, -50, 0); dummy.updateMatrix(); this.m.setMatrixAt(i, dummy.matrix); continue; }
      p.vy -= p.g * dt; const dr = 1 - 0.6 * dt; p.vx *= dr; p.vz *= dr; if (p.g < 0) p.vy *= 1 - 1.5 * dt;
      p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt;
      let sp = 1;
      if (p.bounce && p.y < 0.06) { p.y = 0.06; if (p.vy < -1) { p.vy *= -0.38; p.vx *= 0.7; p.vz *= 0.7; } else { p.vy = 0; p.vx *= 0.85; p.vz *= 0.85; sp = 0.1; } }
      p.rx += p.wx * dt * sp; p.ry += p.wy * dt * sp; p.rz += p.wz * dt * sp;
      const f = p.life < 0.45 ? p.life / 0.45 : 1;
      dummy.position.set(p.x, p.y, p.z); dummy.rotation.set(p.rx, p.ry, p.rz); dummy.scale.setScalar(p.s * f); dummy.updateMatrix(); this.m.setMatrixAt(i, dummy.matrix);
    }
    this.m.instanceMatrix.needsUpdate = true; this.dirty = any;
  }
}
const starShape = (() => { const s = new THREE.Shape(); for (let i = 0; i < 10; i++) { const a = (i / 10) * TAU + Math.PI / 2, r = i % 2 ? 0.1 : 0.22; const x = Math.cos(a) * r, y = Math.sin(a) * r; if (i === 0) s.moveTo(x, y); else s.lineTo(x, y); } s.closePath(); return s; })();
const confetti = new PPool(new THREE.PlaneGeometry(0.2, 0.12), new THREE.MeshBasicMaterial({ side: THREE.DoubleSide, toneMapped: false }), 420);
const starsP = new PPool(new THREE.ExtrudeGeometry(starShape, { depth: 0.05, bevelEnabled: false }), new THREE.MeshBasicMaterial({ toneMapped: false }), 140);
const boltsP = new PPool(new THREE.CylinderGeometry(0.1, 0.1, 0.07, 6), std(0xffffff, { roughness: 0.3, metalness: 0.6 }), 90);
const CONF = [0xff5fb0, 0xffd23f, 0x35d8ff, 0x6bf08a, 0xff9a3d, 0xb57bff, 0xffffff];
function burst(x, y, z, scale = 1, nC = 26, nS = 5, nB = 6) {
  for (let i = 0; i < nC; i++) { const a = rand(0, TAU), u = rand(-0.3, 1), sp = rand(3, 9) * scale; confetti.emit(x, y, z, Math.cos(a) * sp * (1 - Math.abs(u) * 0.3), 4 + u * 7 * scale, Math.sin(a) * sp * (1 - Math.abs(u) * 0.3), rand(1.1, 2), rand(0.8, 1.5) * (0.8 + scale * 0.3), CONF[(Math.random() * 7) | 0], 12); }
  for (let i = 0; i < nS; i++) { const a = rand(0, TAU), sp = rand(2, 6) * scale; starsP.emit(x, y, z, Math.cos(a) * sp, rand(3, 8), Math.sin(a) * sp, rand(1.0, 1.6), rand(1.2, 2) * (0.8 + scale * 0.3), [0xffe45c, 0xfff2a0, 0xffb52e][i % 3], 8, 6); }
  for (let i = 0; i < nB; i++) { const a = rand(0, TAU), sp = rand(2, 6) * scale; boltsP.emit(x, y, z, Math.cos(a) * sp, rand(3, 7), Math.sin(a) * sp, rand(1.2, 2), rand(1, 2) * (0.8 + scale * 0.3), [0xc7cde6, 0xffc83a, 0x9aa6c8][i % 3], 16, 12); }
}
// sprite fx
const fxPool = [];
for (let i = 0; i < 56; i++) { const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: softTex, transparent: true, depthWrite: false, fog: false, toneMapped: false })); s.visible = false; scene.add(s); fxPool.push({ s, life: 0, max: 1, s0: 1, s1: 1, vy: 0, op: 1 }); }
let fxI = 0;
function fx(kind, x, y, z, color, s0, s1, life, add = true, vy = 0, op = 1) {
  const f = fxPool[fxI]; fxI = (fxI + 1) % fxPool.length; const m = f.s.material;
  m.map = kind === 'ring' ? ringTex : kind === 'puff' ? puffTex : softTex; m.blending = add ? THREE.AdditiveBlending : THREE.NormalBlending;
  if (typeof color === 'number') m.color.setHex(color); else m.color.copy(color);
  f.s.position.set(x, y, z); f.s0 = s0; f.s1 = s1; f.life = f.max = life; f.vy = vy; f.op = op; f.s.visible = true; f.s.scale.setScalar(s0); m.opacity = op;
}
function updateFx(dt) {
  for (const f of fxPool) { if (f.life <= 0) continue; f.life -= dt; if (f.life <= 0) { f.s.visible = false; continue; } const k = 1 - f.life / f.max; f.s.scale.setScalar(f.s0 + (f.s1 - f.s0) * (1 - (1 - k) * (1 - k))); f.s.material.opacity = f.op * (1 - k * k); f.s.position.y += f.vy * dt; }
}

// =====================================================================================================================
// gun (first-person)
// =====================================================================================================================
const guns = {}; let gun = null;
function buildGun(kind) {
  const W = WEAPONS[kind], g = new THREE.Group(), cM = std(W.color, { roughness: 0.3 }), glow = hdr(((W.color >> 16) & 255) / 255 * 1.15, ((W.color >> 8) & 255) / 255 * 1.15, (W.color & 255) / 255 * 1.15);
  const white = std(0xf0eaff, { roughness: 0.45 });
  mesh(rb(0.2, 0.24, 0.58, 0.07), white, g, 0, 0, 0.05); mesh(rb(0.215, 0.1, 0.4, 0.04), cM, g, 0, 0.09, 0.0);
  const h = mesh(rb(0.14, 0.3, 0.17, 0.05), MAT.dark, g, 0, -0.23, 0.2); h.rotation.x = 0.25;
  let tipZ = -0.82;
  if (kind === 'foam') {
    const b = mesh(cyl(0.065, 0.075, 0.46, 16), cM, g, 0, 0.03, -0.45); b.rotation.x = Math.PI / 2; mesh(tor(0.082, 0.022, TAU, 8, 20), glow, g, 0, 0.03, -0.69);
    mesh(sph(0.08, 16, 12), glow, g, 0, 0.19, 0.0).scale.set(1, 0.9, 1.3);
  } else if (kind === 'twin') {
    for (const s of [-1, 1]) { const b = mesh(cyl(0.055, 0.065, 0.46, 14), cM, g, s * 0.085, 0.03, -0.45); b.rotation.x = Math.PI / 2; mesh(tor(0.07, 0.02, TAU, 8, 18), glow, g, s * 0.085, 0.03, -0.69); }
    mesh(sph(0.075, 14, 10), glow, g, 0, 0.19, 0.05).scale.set(1.5, 0.8, 1.3);
  } else {
    const b = mesh(cyl(0.17, 0.1, 0.5, 18), cM, g, 0, 0.03, -0.5); b.rotation.x = Math.PI / 2; mesh(tor(0.18, 0.03, TAU, 8, 22), glow, g, 0, 0.03, -0.76);
    mesh(sph(0.1, 16, 12), glow, g, 0, 0.22, 0.0).scale.set(1, 0.9, 1.3); tipZ = -0.86;
    mesh(cyl(0.05, 0.05, 0.12, 8), MAT.metal, g, 0.14, 0.18, 0.12);
  }
  const mz = new THREE.Object3D(); mz.position.set(0, 0.03, tipZ); g.add(mz); g.userData.muzzle = mz;
  g.scale.setScalar(0.7); g.visible = false; camera.add(g); guns[kind] = g;
}
WKEYS.forEach(buildGun);
const flash = new THREE.Sprite(new THREE.SpriteMaterial({ map: softTex, color: 0xffffff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false, toneMapped: false, depthTest: false }));
flash.scale.setScalar(0.5); flash.renderOrder = 20; flash.visible = false; camera.add(flash);
let kick = 0, flashT = 0;
function equip(k) { if (!save.lv[k]) return; save.eq = k; persist(); for (const n of WKEYS) guns[n].visible = n === k; gun = guns[k]; buildWeaponChips(); }

// =====================================================================================================================
// game state
// =====================================================================================================================
let state = 'title'; // title playing paused over victory
const CAMY = 1.7;
let yaw = 0, pitch = 0, tAll = 0;
const run = { score: 0, hearts: 5, maxHearts: 5, wave: 0, stars: 0, combo: 0, comboT: 0, kills: 0, inv: 0, rapid: 0, shield: 0, big: 0, cool: 0, wonOnce: false, shake: 0, over: false };
let queue = [], waveTotal = 0, waveDelay = 0, spawnT = 0, waveClear = 0, bossE = null, bossFx = 0, overT = 0, hintT = 0, firedOnce = false, tapBuf = 0;
const camPos = new THREE.Vector3(0, CAMY, 0);
const fwd = new THREE.Vector3(), tmpA = new THREE.Vector3(), tmpB = new THREE.Vector3(), tmpM = new THREE.Vector3();
const aliveList = [];
function nAlive() { let n = 0; for (const e of enemies) if (e.alive) n++; return n; }

// ---------- projectiles
const projs = [];
{
  const pg = new THREE.SphereGeometry(1, 14, 10);
  for (let i = 0; i < 48; i++) {
    const m = hdr(2, 2, 2); const g = new THREE.Group(); const core = new THREE.Mesh(pg, m); g.add(core);
    const gl = new THREE.Sprite(new THREE.SpriteMaterial({ map: softTex, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false, toneMapped: false })); gl.scale.setScalar(3.2); g.add(gl);
    g.visible = false; scene.add(g); projs.push({ g, core, gl, m, active: false, pos: g.position, vel: new THREE.Vector3(), life: 0, dmg: 1, aoe: 0, size: 0.2, target: null, speed: 70, trail: 0, color: 0xffffff });
  }
}
const orbs = [];
{
  const og = new THREE.SphereGeometry(0.42, 14, 10);
  for (let i = 0; i < 16; i++) {
    const g = new THREE.Group(); const core = new THREE.Mesh(og, hdr(2.4, 0.5, 2.0)); g.add(core);
    const spk = mesh(rb(0.3, 0.3, 0.3, 0.05), hdr(2.6, 1.8, 0.6), g, 0, 0, 0);
    const gl = new THREE.Sprite(new THREE.SpriteMaterial({ map: softTex, color: 0xff4fc8, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false, toneMapped: false })); gl.scale.setScalar(2.4); g.add(gl);
    g.visible = false; scene.add(g); orbs.push({ g, spk, active: false, pos: g.position, vel: new THREE.Vector3(), life: 0, hp: 1 });
  }
}
function fireOrb(x, y, z, tx, ty, tz, speed) {
  const o = orbs.find((q) => !q.active); if (!o) return; o.active = true; o.g.visible = true; o.pos.set(x, y, z);
  tmpA.set(tx - x, ty - y, tz - z).normalize(); o.vel.copy(tmpA).multiplyScalar(speed); o.life = 9;
}

// ---------- aim assist
function updateFwd() { fwd.set(-Math.sin(yaw) * Math.cos(pitch), Math.sin(pitch), -Math.cos(yaw) * Math.cos(pitch)); }
let lockE = null;
function findTarget(coneDeg) {
  const maxA = coneDeg * Math.PI / 180; let best = null, ba = 9;
  for (const e of enemies) {
    if (!e.alive || e.spawnT < 0.45) continue;
    tmpM.set(e.x, e.y + e.cy, e.z).sub(camPos); const len = tmpM.length(); const ang = Math.acos(clamp(tmpM.dot(fwd) / len, -1, 1)) - Math.asin(Math.min(1, e.r * 0.85 / len));
    if (ang < maxA && ang < ba) { ba = ang; best = e; }
  }
  return best;
}
function findOrb(coneDeg) {
  const maxA = coneDeg * Math.PI / 180; let best = null, ba = 9;
  for (const o of orbs) { if (!o.active) continue; tmpM.copy(o.pos).sub(camPos); const len = tmpM.length(); const ang = Math.acos(clamp(tmpM.dot(fwd) / len, -1, 1)) - Math.asin(Math.min(1, 0.6 / len)); if (ang < maxA && ang < ba) { ba = ang; best = o; } }
  return best;
}

function spawnProj(dirV, ox, oy, oz, W, lv, target) {
  const p = projs.find((q) => !q.active); if (!p) return;
  const big = run.big > 0; const size = W.size * (big ? 1.7 : 1);
  p.active = true; p.g.visible = true; p.pos.set(ox, oy, oz); p.vel.copy(dirV).multiplyScalar(W.speed); p.speed = W.speed; p.life = 1.8;
  p.dmg = W.dmg[lv] + (big ? 1 : 0); p.aoe = Math.max(W.aoe[lv], big ? 2.4 : 0); p.size = size; p.target = target; p.trail = 0;
  const c = W.color; const r = ((c >> 16) & 255) / 255, g = ((c >> 8) & 255) / 255, b = (c & 255) / 255;
  p.m.color.setRGB(Math.min(2.6, r * 1.6 + 0.8), Math.min(2.6, g * 1.6 + 0.8), Math.min(2.6, b * 1.6 + 0.8)); p.gl.material.color.setRGB(r, g, b); p.color = c;
  p.core.scale.set(size, size, size * 2.4); p.core.lookAt(tmpA.copy(p.pos).add(dirV)); p.gl.scale.setScalar(size * 14);
}
function fire() {
  const W = WEAPONS[save.eq], lv = save.lv[save.eq] - 1;
  updateFwd();
  const tgt = findTarget(W === WEAPONS.mega ? 12 : 9) || null; let orbT = null;
  if (!tgt) orbT = findOrb(6);
  const dir = tmpB;
  if (tgt) { tmpM.set(tgt.x, tgt.y + tgt.cy, tgt.z).sub(camPos).normalize(); dir.copy(fwd).lerp(tmpM, 0.9).normalize(); }
  else if (orbT) { tmpM.copy(orbT.pos).sub(camPos).normalize(); dir.copy(fwd).lerp(tmpM, 0.85).normalize(); }
  else dir.copy(fwd);
  camera.updateMatrixWorld(true);
  gun.userData.muzzle.getWorldPosition(tmpA);
  const mx = tmpA.x, my = tmpA.y, mz = tmpA.z;
  const n = W.pel[lv];
  const aimX = camPos.x + dir.x * 40, aimY = camPos.y + dir.y * 40, aimZ = camPos.z + dir.z * 40;
  for (let i = 0; i < n; i++) {
    const off = n === 1 ? 0 : (i - (n - 1) / 2);
    // sideways offset at muzzle (right vector)
    const rx = Math.cos(yaw), rz = -Math.sin(yaw);
    const ox = mx + rx * off * 0.22, oy = my, oz = mz + rz * off * 0.22;
    tmpM.set(aimX + rx * off * W.spread * 40 * 0.9, aimY, aimZ + rz * off * W.spread * 40 * 0.9).sub(tmpA.set(ox, oy, oz)).normalize();
    spawnProj(tmpM, ox, oy, oz, W, lv, tgt || null);
  }
  run.cool = W.rate[lv] / (run.rapid > 0 ? 2 : 1);
  kick = 1; flashT = 0.07; flash.visible = true; flash.material.color.setHex(W.color); flash.scale.setScalar(rand(0.45, 0.7) * (W === WEAPONS.mega ? 1.6 : 1));
  sfx(W === WEAPONS.mega ? 'laser' : 'shoot', { volume: 0.55, pitch: W === WEAPONS.twin ? 1.2 : W === WEAPONS.mega ? 0.6 : 1 });
  run.shots = (run.shots || 0) + 1;
  if (!firedOnce) { firedOnce = true; hintT = Math.min(hintT, 2.5); }
}

// ---------- damage and kills
const floaters = []; const FL_N = 14;
for (let i = 0; i < FL_N; i++) { const el = document.createElement('div'); el.className = 'fl'; $('floaters').appendChild(el); floaters.push({ el, t: 0, x: 0, y: 0, z: 0, on: false }); }
let flI = 0;
function floater(text, x, y, z, color) {
  const f = floaters[flI]; flI = (flI + 1) % FL_N; f.el.textContent = text; f.el.style.color = color || '#fff'; f.t = 0; f.x = x; f.y = y; f.z = z; f.on = true; f.el.style.display = 'block';
}
function updateFloaters(dt) {
  const w = innerWidth, h = innerHeight;
  for (const f of floaters) {
    if (!f.on) continue; f.t += dt; if (f.t > 1.1) { f.on = false; f.el.style.display = 'none'; continue; }
    tmpM.set(f.x, f.y + f.t * 1.4, f.z).project(camera);
    if (tmpM.z > 1) { f.el.style.display = 'none'; continue; } f.el.style.display = 'block';
    const s = f.t < 0.12 ? 0.6 + f.t / 0.12 * 0.6 : 1.2 - Math.min(0.3, (f.t - 0.12));
    f.el.style.transform = `translate(${(tmpM.x * 0.5 + 0.5) * w}px,${(-tmpM.y * 0.5 + 0.5) * h}px) translate(-50%,-50%) scale(${s})`; f.el.style.opacity = f.t > 0.7 ? 1 - (f.t - 0.7) / 0.4 : 1;
  }
}

function hurt(n = 1) {
  if (run.shield > 0) { sfx('boing', { volume: 0.5, pitch: 1.4 }); run.shake = Math.max(run.shake, 0.15); return false; }
  if (run.inv > 0 || state !== 'playing') return false;
  run.hearts = Math.max(0, run.hearts - n); run.inv = 1.3; run.shake = 0.5; run.combo = 0; run.comboT = 0;
  sfx('hurt', { volume: 0.7 }); try { navigator.vibrate && navigator.vibrate(60); } catch (e) { /* ignore */ }
  const h = $('hurt'); h.classList.add('on'); setTimeout(() => h.classList.remove('on'), 120);
  updateHearts(true);
  if (run.hearts <= 0) gameOver();
  return true;
}

function dropPickup(e) {
  const boss = e.type === 'boss';
  if (boss) { spawnPickup('heart', e.x, 1.5, e.z); spawnPickup(['rapid', 'shield', 'big'][(Math.random() * 3) | 0], e.x + 1, 1.5, e.z); return; }
  const r = Math.random();
  if (run.hearts < run.maxHearts && r < (run.hearts <= 2 ? 0.3 : 0.1)) spawnPickup('heart', e.x, 1.2, e.z);
  else if (r > 0.88) spawnPickup(['rapid', 'shield', 'big'][(Math.random() * 3) | 0], e.x, 1.2, e.z);
}

function killEnemy(e, byPlayer = true, silent = false) {
  if (!e.alive) return; e.alive = false; e.root.visible = false; e.blob.visible = false;
  const cx = e.x, cy = e.y + e.cy, cz = e.z; const big = e.type === 'boss' ? 3.2 : e.type === 'armor' ? 1.5 : 1;
  burst(cx, cy, cz, big, silent ? 14 : 26 * Math.min(big, 2), silent ? 2 : 5 + (big > 1 ? 4 : 0), silent ? 2 : 6);
  fx('puff', cx, cy, cz, 0xffffff, 1.5 * big, 4.5 * big, 0.55, false, 0.6, 0.9); fx('ring', cx, cy, cz, 0xffe9a6, 1, 7 * big, 0.4, true);
  fx('soft', cx, cy, cz, 0xffd866, 2 * big, 6 * big, 0.25, true);
  if (!silent) sfx(e.type === 'boss' ? 'boom' : 'pop', { volume: 0.8, pitch: rand(0.95, 1.25) });
  if (!byPlayer) return;
  run.combo++; run.comboT = 3; run.kills++;
  const mult = Math.min(8, 1 + Math.floor(run.combo / 3)); const pts = e.def.score * mult; run.score += pts;
  floater('+' + pts + (mult > 1 ? '  x' + mult : ''), cx, cy + 1, cz, mult > 1 ? '#ffe36a' : '#fff');
  const st = e.def.stars; run.stars += st; save.stars += st; $('starChip').classList.remove('bump'); void $('starChip').offsetWidth; $('starChip').classList.add('bump');
  sfx('coin', { volume: 0.35, pitch: 1 + Math.min(0.6, run.combo * 0.03) });
  run.shake = Math.max(run.shake, e.type === 'boss' ? 0.9 : 0.14);
  if (!silent) dropPickup(e);
  const c = $('comboTxt'); c.classList.remove('bump'); void c.offsetWidth; c.classList.add('bump');
  if (e.type === 'boss') bossDown(e);
}
function bossDown(e) {
  bossE = null; $('bossBox').classList.remove('on'); queue.length = 0; bossFx = 1.4; bossPos.set(e.x, e.y + e.cy, e.z);
  for (const o of orbs) if (o.active) { o.active = false; o.g.visible = false; fx('soft', o.pos.x, o.pos.y, o.pos.z, 0xff80d0, 1, 3, 0.3); }
  for (const x of enemies) if (x.alive) { run.score += 50; killEnemy(x, false, true); }
  showBanner('BOSS DEFEATED!', '+' + e.def.stars + ' stars', 2400); sfx('win');
  run.hearts = Math.min(run.maxHearts, run.hearts + 1); updateHearts(false);
}
const bossPos = new THREE.Vector3();

function hitEnemy(e, dmg, px, py, pz) {
  if (!e.alive) return; e.hp -= dmg; e.sq = 1; e.fl = 1;
  confetti.emit(px, py, pz, rand(-3, 3), rand(2, 6), rand(-3, 3), 0.8, 0.9, CONF[(Math.random() * 7) | 0], 12);
  confetti.emit(px, py, pz, rand(-3, 3), rand(2, 6), rand(-3, 3), 0.8, 0.9, CONF[(Math.random() * 7) | 0], 12);
  fx('soft', px, py, pz, 0xfff0a0, 0.4, 1.8, 0.18);
  $('crosshair').classList.remove('hit'); void $('crosshair').offsetWidth; $('crosshair').classList.add('hit');
  if (e.hp <= 0) killEnemy(e); else { sfx('hit', { volume: 0.4, pitch: rand(1.1, 1.5) }); if (e.type === 'boss') { run.shake = Math.max(run.shake, 0.12); updateBossBar(); } }
}
function explode(x, y, z, aoe, dmg, color) {
  fx('ring', x, y, z, color, 0.5, aoe * 2.4, 0.35, true); fx('soft', x, y, z, color, 1, aoe * 2.2, 0.3, true); fx('puff', x, y, z, 0xffffff, 0.8, aoe * 1.6, 0.4, false, 0, 0.6);
  for (let i = 0; i < 10; i++) { const a = rand(0, TAU), sp = rand(3, 8); confetti.emit(x, y, z, Math.cos(a) * sp, rand(2, 7), Math.sin(a) * sp, rand(0.8, 1.4), 1.1, CONF[i % 7], 12); }
  sfx('boom', { volume: 0.5, pitch: 1.3 }); run.shake = Math.max(run.shake, 0.28);
  for (const e of enemies) { if (!e.alive) continue; const d = Math.hypot(e.x - x, e.y + e.cy - y, e.z - z); if (d < aoe + e.r * 0.6) hitEnemy(e, dmg, e.x, e.y + e.cy, e.z); }
  for (const o of orbs) if (o.active && o.pos.distanceTo(tmpM.set(x, y, z)) < aoe) popOrb(o);
}
function popOrb(o) { o.active = false; o.g.visible = false; burst(o.pos.x, o.pos.y, o.pos.z, 0.5, 10, 1, 0); fx('soft', o.pos.x, o.pos.y, o.pos.z, 0xff80d0, 0.8, 3, 0.25); sfx('pop', { volume: 0.5, pitch: 1.6 }); run.score += 25; }

// ---------- pickups
const pickups = [];
function makePickup(kind) {
  const g = new THREE.Group(); let core;
  if (kind === 'heart') {
    const s = new THREE.Shape(); s.moveTo(0, -0.5); s.bezierCurveTo(-0.9, 0.05, -0.55, 0.65, 0, 0.3); s.bezierCurveTo(0.55, 0.65, 0.9, 0.05, 0, -0.5);
    const hg = new THREE.ExtrudeGeometry(s, { depth: 0.25, bevelEnabled: true, bevelSize: 0.1, bevelThickness: 0.1, bevelSegments: 3, curveSegments: 12 }); hg.center();
    core = new THREE.Mesh(hg, hdr(2.6, 0.35, 0.9)); core.scale.setScalar(0.9); g.add(core);
  } else {
    const col = { rapid: [2.6, 1.4, 0.3], shield: [0.4, 1.8, 2.8], big: [2.2, 0.6, 2.8] }[kind];
    mesh(sph(0.62, 16, 12), hdr(col[0] * 0.55, col[1] * 0.55, col[2] * 0.55, { transparent: true, opacity: 0.9 }), g, 0, 0, 0);
    const tex = canvasTex(128, 128, (c) => {
      c.fillStyle = '#fff'; c.strokeStyle = '#fff'; c.lineJoin = 'round';
      if (kind === 'rapid') { c.beginPath(); c.moveTo(76, 14); c.lineTo(36, 70); c.lineTo(62, 70); c.lineTo(50, 114); c.lineTo(94, 52); c.lineTo(68, 52); c.closePath(); c.fill(); }
      else if (kind === 'shield') { c.beginPath(); c.moveTo(64, 14); c.lineTo(100, 28); c.lineTo(100, 62); c.quadraticCurveTo(100, 98, 64, 116); c.quadraticCurveTo(28, 98, 28, 62); c.lineTo(28, 28); c.closePath(); c.fill(); }
      else { for (let i = 0; i < 16; i++) { const a = (i / 16) * TAU, r = i % 2 ? 26 : 50; c.lineTo(64 + Math.cos(a) * r, 64 + Math.sin(a) * r); } c.closePath(); c.fill(); }
    });
    const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, depthTest: false, fog: false, toneMapped: false })); sp.scale.setScalar(0.9); sp.renderOrder = 5; g.add(sp);
    const ring = mesh(tor(0.7, 0.05, TAU, 6, 24), hdr(col[0], col[1], col[2]), g, 0, 0, 0); g.userData.ring = ring;
    core = ring;
  }
  const gl = new THREE.Sprite(new THREE.SpriteMaterial({ map: softTex, color: kind === 'heart' ? 0xff3d74 : kind === 'rapid' ? 0xffa030 : kind === 'shield' ? 0x30b8ff : 0xd060ff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false, toneMapped: false })); gl.scale.setScalar(3); g.add(gl);
  g.visible = false; scene.add(g); return { g, kind, active: false, t: 0, vy: 0, x: 0, y: 0, z: 0, core };
}
for (let i = 0; i < 3; i++) pickups.push(makePickup('heart'));
for (const k of ['rapid', 'shield', 'big']) for (let i = 0; i < 2; i++) pickups.push(makePickup(k));
function spawnPickup(kind, x, y, z) {
  const p = pickups.find((q) => !q.active && q.kind === kind); if (!p) return;
  p.active = true; p.g.visible = true; p.t = 0; p.vy = 6; p.x = x; p.y = y; p.z = z; p.g.position.set(x, y, z);
}
function updatePickups(dt) {
  for (const p of pickups) {
    if (!p.active) continue; p.t += dt;
    if (p.t < 0.7) { p.vy -= 16 * dt; p.y += p.vy * dt; if (p.y < 0.9) { p.y = 0.9; p.vy = Math.abs(p.vy) * 0.4; } }
    else { const k = Math.min(1, (p.t - 0.7) * 0.9); const sp = 5 + 22 * k * k; tmpM.set(0 - p.x, CAMY - 0.3 - p.y, 0 - p.z); const d = tmpM.length(); tmpM.multiplyScalar(Math.min(d, sp * dt) / d); p.x += tmpM.x; p.y += tmpM.y; p.z += tmpM.z; if (d < 1.4) { collect(p); continue; } }
    p.g.position.set(p.x, p.y + Math.sin(p.t * 5) * 0.08, p.z); p.g.rotation.y += dt * 2.6;
    if (p.g.userData.ring) p.g.userData.ring.rotation.x += dt * 2;
  }
}
function collect(p) {
  p.active = false; p.g.visible = false; fx('ring', p.x, p.y, p.z, 0xffffff, 0.5, 4, 0.35); burst(p.x, p.y, p.z, 0.6, 12, 4, 0);
  if (p.kind === 'heart') { run.hearts = Math.min(run.maxHearts, run.hearts + 1); updateHearts(false); sfx('sparkle'); floater('+1 heart', p.x, p.y, p.z, '#ff8aa8'); }
  else { run[p.kind] = 10; sfx('powerup'); floater({ rapid: 'RAPID FIRE!', shield: 'SHIELD!', big: 'BIG BLAST!' }[p.kind], 0, CAMY + 0.5, -4, '#fff'); if (p.kind === 'shield') $('bubble').classList.add('on'); }
}

// =====================================================================================================================
// waves
// =====================================================================================================================
function showBanner(t1, t2, ms = 2200) { const b = $('banner'); $('b1').textContent = t1; $('b2').textContent = t2 || ''; b.classList.remove('show'); void b.offsetWidth; b.style.animationDuration = ms + 'ms'; b.classList.add('show'); b.style.setProperty('--d', ms + 'ms'); }
function startWave(n) {
  run.wave = n; queue = []; waveClear = 0; spawnT = 1;
  const boss = n % 5 === 0;
  if (boss) {
    queue.push('boss'); const m = 4 + n; for (let i = 0; i < m; i++) queue.push(Math.random() < 0.6 ? 'walker' : 'roller');
    showBanner('BOSS WAVE ' + n, 'Look out for the Big Bolt!', 2600); playTheme('boss', 0.7); sfx('whoosh');
  } else {
    const total = Math.min(36, Math.round(5 + n * 2.1));
    for (let i = 0; i < total; i++) {
      const r = Math.random(); let t = 'walker';
      if (n >= 2 && r < 0.18 + n * 0.015) t = 'roller';
      if (n >= 3 && r > 0.84 - Math.min(0.1, n * 0.01)) t = 'drone';
      if (n >= 4 && r > 0.93 - Math.min(0.06, n * 0.006)) t = 'armor';
      queue.push(t);
    }
    showBanner('WAVE ' + n, n === 1 ? 'Get ready!' : n === 2 ? 'Rollers incoming!' : n === 3 ? 'Drones in the sky!' : n === 4 ? 'Armored bots!' : 'Keep it up!', 2200); playTheme('action', 0.4); sfx('whoosh');
  }
  waveTotal = queue.length; waveDelay = 2.2;
  $('waveLbl').textContent = (boss ? 'BOSS ' : 'WAVE ') + n; updateWaveBar();
}
function updateWaveBar() { const left = queue.length + nAlive(); $('waveBar').firstElementChild.style.transform = `scaleX(${waveTotal ? clamp(left / waveTotal, 0, 1) : 0})`; }

function pickGate(spread) {
  const a = yaw + rand(-spread, spread); const idx = ((Math.round(a / (Math.PI / 6)) % 12) + 12) % 12; return idx;
}
function spawnEnemy(type, gateIdx, bx, bz) {
  const e = pools[type].find((q) => !q.alive); if (!e) return null;
  let x, z;
  if (bx !== undefined) { x = bx; z = bz; } else {
    const gi = gateIdx === undefined ? pickGate(run.wave < 3 ? 1.0 : run.wave < 6 ? 2.4 : 3.14) : gateIdx; const a = gi * Math.PI / 6 + rand(-0.12, 0.12); const R = ARENA_R - 3.5;
    x = -Math.sin(a) * R; z = -Math.cos(a) * R; gates[gi].flash = 1; sfx('swish', { volume: 0.25 });
  }
  e.alive = true; e.x = x; e.z = z; e.hp = e.maxhp = type === 'armor' ? 3 + (run.wave > 8 ? 1 : 0) : type === 'boss' ? 26 + 12 * (run.wave / 5) : 1; e.t = 0; e.sq = 0; e.fl = 0; e.spawnT = 0; e.ph = rand(0, TAU);
  e.y = type === 'drone' ? rand(3, 4.2) : 0; e.spd = e.def.speed * (1 + Math.min(0.5, run.wave * 0.04)) * rand(0.9, 1.1); e.hd = rand(10, 15); e.dir = Math.random() < 0.5 ? 1 : -1; e.cool = rand(1.5, 3.5); e.charge = 0; e.sumT = 7; e.ang = Math.atan2(-x, -z);
  e.root.visible = true; e.blob.visible = true; setFlash(e, 0); e.root.scale.setScalar(0.01); e.root.position.set(x, e.y, z);
  fx('soft', x, 2, z, 0xffffff, 1, 5, 0.4); fx('ring', x, 0.4, z, 0x9ff0ff, 0.5, 6, 0.5);
  if (type === 'boss') { bossE = e; $('bossBox').classList.add('on'); updateBossBar(); $('bossName').textContent = 'BIG BOLT' + (run.wave > 5 ? ' ' + (run.wave / 5) : ''); sfx('boom', { volume: 0.5, pitch: 0.6 }); }
  return e;
}
function updateBossBar() { if (bossE) $('bossBar').firstElementChild.style.transform = `scaleX(${clamp(bossE.hp / bossE.maxhp, 0, 1)})`; }

function updateEnemies(dt) {
  for (const e of enemies) {
    if (!e.alive) continue; e.t += dt;
    if (e.spawnT < 0.5) { e.spawnT += dt; const k = clamp(e.spawnT / 0.5, 0, 1); const s = 1 + 2.2 * Math.pow(k - 1, 3) + 1.2 * Math.pow(k - 1, 2); e.root.scale.setScalar(Math.max(0.01, s)); if (e.spawnT >= 0.5) e.root.scale.setScalar(1); }
    const px = 0, pz = 0; let dx = px - e.x, dz = pz - e.z; let dist = Math.hypot(dx, dz) || 0.001; const spawning = e.spawnT < 0.5;
    const face = Math.atan2(dx, dz);
    let bob = 0, sway = 0;
    if (e.type === 'walker' || e.type === 'armor') {
      const sp = spawning ? 0 : e.spd; const stop = e.type === 'armor' ? 2.6 : 2.0;
      if (dist > stop) { e.x += dx / dist * sp * dt; e.z += dz / dist * sp * dt; }
      // gentle sidestep
      e.ph += dt * sp * (e.type === 'armor' ? 2.4 : 3.4); const sw = Math.sin(e.ph);
      e.legs[0].rotation.x = sw * 0.75; e.legs[1].rotation.x = -sw * 0.75; e.arms[0].rotation.x = -sw * 0.7; e.arms[1].rotation.x = sw * 0.7;
      e.arms[0].rotation.z = 0.15; e.arms[1].rotation.z = -0.15; bob = Math.abs(sw) * 0.14 * e.vis.scale.x; sway = sw * 0.09;
      e.head.rotation.z = Math.sin(e.t * 3) * 0.06;
      if (dist <= stop && !spawning) { if (hurt(1) || run.shield > 0) { killEnemy(e, false); } else killEnemy(e, false); continue; }
    } else if (e.type === 'roller') {
      const sp = spawning ? 0 : e.spd * (0.7 + 0.3 * Math.min(1, e.t)); if (dist > 2.0) { e.x += dx / dist * sp * dt; e.z += dz / dist * sp * dt; }
      e.spin.rotation.x += sp * dt / 0.85; bob = Math.abs(Math.sin(e.t * 9)) * 0.06; sway = Math.sin(e.t * 6) * 0.05; e.head.rotation.z = Math.sin(e.t * 9) * 0.07;
      if (dist <= 2.0 && !spawning) { hurt(1); killEnemy(e, false); continue; }
    } else if (e.type === 'drone') {
      if (!spawning) {
        if (dist > e.hd) { e.x += dx / dist * e.spd * dt; e.z += dz / dist * e.spd * dt; e.ang = Math.atan2(-e.x, -e.z); }
        else { e.ang += e.dir * dt * 0.28; const r = Math.max(dist, e.hd); e.x = -Math.sin(e.ang) * r; e.z = -Math.cos(e.ang) * r; }
        e.cool -= dt; if (e.cool < 0.6 && e.cool > 0) { e.charge = 1 - e.cool / 0.6; } if (e.cool <= 0) { e.charge = 0; e.cool = rand(3, 4.6) - Math.min(1, run.wave * 0.06); fireOrb(e.x, e.y, e.z, 0, CAMY, 0, 8 + Math.min(3, run.wave * 0.2)); sfx('laser', { volume: 0.3, pitch: 0.7 }); fx('soft', e.x, e.y, e.z + 0.3, 0xff60c8, 1, 3, 0.25); }
      }
      e.y = clamp(e.y, 2.6, 4.6) + Math.sin(e.t * 2 + e.ph) * dt * 0.5; bob = 0; for (const r of e.rotors) r.rotation.y += dt * 40; e.belly.scale.setScalar(1 + e.charge * 0.9 + Math.sin(e.t * 6) * 0.1); sway = Math.sin(e.t * 2) * 0.1; e.vis.rotation.x = -0.15;
      if (dist < 2.2 && !spawning) { hurt(1); killEnemy(e, false); continue; }
    } else if (e.type === 'boss') {
      if (!spawning) {
        if (dist > 13.5) { e.x += dx / dist * e.spd * dt; e.z += dz / dist * e.spd * dt; e.ang = Math.atan2(-e.x, -e.z); e.ph += dt * 3; }
        else { e.ang += e.dir * dt * 0.16; e.x = -Math.sin(e.ang) * 13.5; e.z = -Math.cos(e.ang) * 13.5; e.ph += dt * 2.2; if (Math.random() < dt * 0.1) e.dir *= -1; }
        e.cool -= dt;
        if (e.cool < 0.7 && e.cool > 0) e.charge = 1 - e.cool / 0.7;
        if (e.cool <= 0) {
          e.charge = 0; e.cool = Math.max(2.0, 3.2 - run.wave * 0.05); const n = run.wave >= 10 ? 5 : 3;
          for (let i = 0; i < n; i++) { const off = (i - (n - 1) / 2) * 0.22; const tx = Math.cos(e.ang) * 0 + off * -Math.cos(face) * 8, tz = off * Math.sin(face) * 8; fireOrb(e.x, 4.2, e.z, tx, CAMY + rand(-0.3, 0.3), tz, 7.5); }
          sfx('laser', { volume: 0.5, pitch: 0.5 }); fx('soft', e.x, 4.2, e.z, 0xff60c8, 2, 7, 0.3);
        }
        e.sumT -= dt; if (e.sumT <= 0 && nAlive() < 8) { e.sumT = 9; for (let i = 0; i < 2; i++) { const a = e.ang + (i ? 0.5 : -0.5); const m = spawnEnemy('walker', undefined, -Math.sin(a) * 20, -Math.cos(a) * 20); if (m) m.spd *= 0.9; } showBanner('Helpers!', '', 1400); }
      }
      const sw = Math.sin(e.ph); e.legs[0].rotation.x = sw * 0.5; e.legs[1].rotation.x = -sw * 0.5; e.arms[0].rotation.x = -0.4 - e.charge * 1.4; e.arms[1].rotation.x = -0.4 - e.charge * 1.4; bob = Math.abs(sw) * 0.4; sway = sw * 0.05;
      e.ball.scale.setScalar(1 + e.charge * 1.5);
    }
    // squash / flash
    e.sq = Math.max(0, e.sq - dt * 5); e.fl = Math.max(0, e.fl - dt * 7); setFlash(e, e.fl * 0.9);
    const sqy = 1 - e.sq * 0.22 * Math.sin(Math.min(1, e.sq) * Math.PI * 0.5 + 0.5), sqx = 1 + e.sq * 0.18;
    if (e.spawnT >= 0.5) e.root.scale.set(sqx, sqy, sqx);
    e.root.position.set(e.x, e.y + bob, e.z); e.root.rotation.y = face; e.vis.rotation.z = sway;
    e.blob.position.set(e.x, 0.03, e.z); const bs = (e.type === 'boss' ? 7 : e.type === 'armor' ? 3.6 : e.type === 'drone' ? 2.4 * (1 + e.y * 0.1) : 2.4); e.blob.scale.set(bs, 1, bs); e.blob.visible = true;
  }
}

// =====================================================================================================================
// loop pieces
// =====================================================================================================================
function updateProjectiles(dt) {
  for (const p of projs) {
    if (!p.active) continue; p.life -= dt;
    if (p.target && p.target.alive) { tmpM.set(p.target.x, p.target.y + p.target.cy, p.target.z).sub(p.pos).normalize(); tmpA.copy(p.vel).normalize().lerp(tmpM, Math.min(1, dt * 7)).normalize(); p.vel.copy(tmpA).multiplyScalar(p.speed); }
    const stepLen = p.speed * dt, n = Math.max(1, Math.ceil(stepLen / 0.6)), sd = dt / n; let hit = false;
    for (let s = 0; s < n && !hit; s++) {
      p.pos.addScaledVector(p.vel, sd);
      for (const e of enemies) { if (!e.alive) continue; const rr = e.r + p.size; const dx = p.pos.x - e.x, dy = p.pos.y - (e.y + e.cy), dz = p.pos.z - e.z; if (dx * dx + dy * dy + dz * dz < rr * rr) { hit = true; impact(p, e); break; } }
      if (!hit) for (const o of orbs) { if (o.active && o.pos.distanceToSquared(p.pos) < (0.55 + p.size) * (0.55 + p.size)) { hit = true; popOrb(o); if (p.aoe > 0) explode(p.pos.x, p.pos.y, p.pos.z, p.aoe, p.dmg, p.color); break; } }
      if (!hit && p.pos.y < 0.1) { hit = true; fx('soft', p.pos.x, 0.1, p.pos.z, p.color, 0.5, 2, 0.2); if (p.aoe > 0) explode(p.pos.x, 0.5, p.pos.z, p.aoe, p.dmg, p.color); }
    }
    if (hit || p.life <= 0 || p.pos.lengthSq() > 2000) { p.active = false; p.g.visible = false; continue; }
    p.core.lookAt(tmpA.copy(p.pos).add(p.vel)); p.trail -= dt; if (p.trail <= 0) { p.trail = 0.035; fx('soft', p.pos.x, p.pos.y, p.pos.z, p.color, p.size * 4, p.size * 1.2, 0.22, true, 0, 0.55); }
  }
}
function impact(p, e) {
  if (p.aoe > 0) { explode(p.pos.x, p.pos.y, p.pos.z, p.aoe, p.dmg, p.color); hitEnemy(e, p.dmg, p.pos.x, p.pos.y, p.pos.z); }
  else hitEnemy(e, p.dmg, p.pos.x, p.pos.y, p.pos.z);
}
function updateOrbs(dt) {
  for (const o of orbs) {
    if (!o.active) continue; o.life -= dt; o.pos.addScaledVector(o.vel, dt); o.g.rotation.y += dt * 4; o.spk.rotation.x += dt * 5; const s = 1 + Math.sin(tAll * 12) * 0.1; o.g.scale.setScalar(s);
    if (o.life <= 0 || o.pos.lengthSq() > 2500) { o.active = false; o.g.visible = false; continue; }
    if (Math.hypot(o.pos.x, o.pos.y - CAMY, o.pos.z) < 1.1) { o.active = false; o.g.visible = false; burst(o.pos.x, o.pos.y, o.pos.z, 0.5, 10, 0, 0); hurt(1); }
  }
}

function updateGame(dt) {
  run.inv = Math.max(0, run.inv - dt); run.cool -= dt; tapBuf -= dt;
  for (const k of ['rapid', 'shield', 'big']) if (run[k] > 0) { run[k] -= dt; if (run[k] <= 0) { run[k] = 0; if (k === 'shield') $('bubble').classList.remove('on'); } }
  if (run.comboT > 0) { run.comboT -= dt; if (run.comboT <= 0) run.combo = 0; }
  // input look (keys)
  const kx = (keys.ArrowLeft || keys.KeyA ? 1 : 0) - (keys.ArrowRight || keys.KeyD ? 1 : 0), ky = (keys.ArrowUp || keys.KeyW ? 1 : 0) - (keys.ArrowDown || keys.KeyS ? 1 : 0);
  yaw += kx * 2.2 * dt; pitch = clamp(pitch + ky * 1.4 * dt, -0.6, 0.9);
  // hold-to-fire detection
  const now = performance.now(); let holding = fireBtnDown || keys.Space || keys.KeyF;
  for (const p of pts.values()) { if (!p.moved && !p.fire && now - p.t > 230) { p.fire = true; tapBuf = 0.25; } if (p.fire) holding = true; }
  if ((holding || tapBuf > 0) && run.cool <= 0 && !(waveDelay > 1.6 && false)) { fire(); tapBuf = 0; }
  // waves
  if (waveDelay > 0) waveDelay -= dt;
  else if (waveClear === 0) {
    spawnT -= dt; const cap = bossE ? 8 : Math.min(11, 3 + run.wave);
    if (queue.length && nAlive() < cap && spawnT <= 0) {
      const t = queue.shift(); spawnEnemy(t); spawnT = t === 'boss' ? 3 : Math.max(0.5, 1.7 - run.wave * 0.07) * rand(0.8, 1.2);
    }
    if (!queue.length && nAlive() === 0) { waveClear = 1; waveEnd(); }
  } else { waveClear -= dt * 0.4; if (waveClear <= 0.001 && state === 'playing') { if (run.wave === 10 && !run.wonOnce) victory(); else startWave(run.wave + 1); waveClear = 0; if (state === 'playing') waveClear = 0; } }
  updateEnemies(dt); updateProjectiles(dt); updateOrbs(dt); updatePickups(dt);
  if (bossFx > 0) { const prev = bossFx; bossFx -= dt; if (((prev * 6) | 0) !== ((bossFx * 6) | 0)) { burst(bossPos.x + rand(-2, 2), bossPos.y + rand(-2, 2), bossPos.z + rand(-2, 2), 2, 24, 4, 4); sfx('pop', { pitch: rand(0.7, 1.2) }); run.shake = 0.5; } }
  hintT -= dt; if (hintT <= 0) $('hint').classList.remove('on');
  const n = nAlive(); updateWaveBar();
  playTheme(bossE ? 'boss' : 'action', clamp(0.18 + n * 0.07 + (bossE ? 0.35 : 0) + (run.combo > 5 ? 0.1 : 0), 0.15, 1));
}
function waveEnd() {
  const bonus = 3 + run.wave; run.stars += bonus; save.stars += bonus; run.score += run.wave * 200; persist();
  if (run.wave % 5 !== 0) showBanner('WAVE CLEAR!', '+' + bonus + ' stars', 2000);
  sfx('win', { volume: 0.7 }); if (run.hearts < run.maxHearts && run.wave % 5 !== 0) { run.hearts++; updateHearts(false); }
  if (run.wave > save.bestWave) save.bestWave = run.wave; persist(); playTheme('action', 0.3);
}

// =====================================================================================================================
// HUD
// =====================================================================================================================
const heartSvg = '<svg viewBox="0 0 32 32"><path d="M16 28C6 20 2 14.500 2 9.500 2 5.400 5.200 3 8.600 3c3 0 5.400 1.700 7.400 4.600C18 4.700 20.400 3 23.400 3 26.800 3 30 5.400 30 9.500 30 14.500 26 20 16 28z"/></svg>';
function buildHearts() { $('hearts').innerHTML = heartSvg.repeat(run.maxHearts); }
let lastHearts = -1;
function updateHearts(pop) {
  const hs = $('hearts').children; for (let i = 0; i < hs.length; i++) { hs[i].classList.toggle('off', i >= run.hearts); }
  if (pop && run.hearts < lastHearts && hs[run.hearts]) { hs[run.hearts].classList.remove('pop'); void hs[run.hearts].getBoundingClientRect(); hs[run.hearts].classList.add('pop'); }
  lastHearts = run.hearts;
}
const gunSvg = (hex, locked) => `<svg viewBox="0 0 120 70"><g stroke="#2a1458" stroke-width="3" stroke-linejoin="round"><rect x="14" y="20" width="62" height="26" rx="12" fill="#fff"/><rect x="50" y="24" width="30" height="18" rx="6" fill="${hex}"/><rect x="74" y="26" width="34" height="14" rx="6" fill="${hex}"/><circle cx="108" cy="33" r="7" fill="#fff"/><path d="M26 44l-5 18h16l5-18z" fill="#4a3090"/><circle cx="36" cy="18" r="9" fill="${hex}"/></g>${locked ? '<g fill="#fff" stroke="#2a1458" stroke-width="3"><rect x="44" y="28" width="32" height="26" rx="6"/><path d="M50 28v-6a10 10 0 0 1 20 0v6" fill="none"/></g>' : ''}</svg>`;
function buildWeaponChips() {
  const w = $('weapons'); w.innerHTML = '';
  const un = WKEYS.filter((k) => save.lv[k] > 0); if (un.length < 2) { w.style.display = 'none'; return; } w.style.display = 'flex';
  un.forEach((k) => { const b = document.createElement('button'); b.className = 'wchip' + (k === save.eq ? ' on' : ''); b.innerHTML = gunSvg(WEAPONS[k].hex) + `<b>${WKEYS.indexOf(k) + 1}</b>`; b.onpointerdown = (e) => { e.stopPropagation(); e.preventDefault(); equip(k); sfx('click'); }; w.appendChild(b); });
}
const arrowEls = []; for (let i = 0; i < 6; i++) { const a = document.createElement('div'); a.className = 'arr'; a.innerHTML = '<svg viewBox="0 0 44 44"><path d="M22 5l15 28c1 2-1 4-3 3l-12-6-12 6c-2 1-4-1-3-3z"/></svg>'; $('arrows').appendChild(a); arrowEls.push(a); }
function updateHud(dt) {
  $('score').textContent = run.score.toLocaleString(); $('runStars').textContent = run.stars;
  // combo
  const mult = Math.min(8, 1 + Math.floor(run.combo / 3)); const cb = $('comboBox'); const on = run.combo >= 2; cb.classList.toggle('on', on);
  if (on) { $('comboTxt').textContent = run.combo + ' COMBO' + (mult > 1 ? '  x' + mult : ''); $('comboBar').firstElementChild.style.transform = `scaleX(${clamp(run.comboT / 3, 0, 1)})`; }
  // powers
  const pw = $('powers'); const defs = [['rapid', 'Rapid', '<svg viewBox="0 0 32 32"><path d="M18 2L6 18h8l-2 12 12-17h-8z"/></svg>'], ['shield', 'Shield', '<svg viewBox="0 0 32 32"><path d="M16 2l11 4v9c0 7-5 12-11 15C10 27 5 22 5 15V6z"/></svg>'], ['big', 'Big', '<svg viewBox="0 0 32 32"><path d="M16 2l4.200 9 9.800 1.100-7.300 6.700 2 9.700L16 23.600 7.300 28.500l2-9.700L2 12.100 11.800 11z"/></svg>']];
  const sig = defs.map((d) => run[d[0]] > 0 ? 1 : 0).join(''); if (pw.dataset.sig !== sig) { pw.dataset.sig = sig; pw.innerHTML = ''; defs.forEach((d) => { if (run[d[0]] > 0) { const el = document.createElement('div'); el.className = 'pw pill ' + d[0]; el.innerHTML = `<div class="ic">${d[2]}</div><div class="bar"><i></i></div>`; el.dataset.k = d[0]; pw.appendChild(el); } }); }
  for (const el of pw.children) el.querySelector('i').style.transform = `scaleX(${clamp(run[el.dataset.k] / 10, 0, 1)})`;
  // crosshair lock
  updateFwd(); const t = findTarget(3.2) || null; const lk = !!t || !!findOrb(3); $('crosshair').classList.toggle('lock', lk); lockE = t;
  // arrows
  const halfH = Math.atan(Math.tan(camera.fov * Math.PI / 360) * camera.aspect); let ai = 0; const w = innerWidth, h = innerHeight;
  const cand = [];
  for (const e of enemies) { if (!e.alive || e.spawnT < 0.5) continue; const rel = wrapPi(Math.atan2(-e.x, -e.z) - yaw); if (Math.abs(rel) > halfH * 0.95) cand.push([Math.hypot(e.x, e.z), rel]); }
  cand.sort((a, b) => a[0] - b[0]);
  for (const [d, rel] of cand) { if (ai >= 6) break; const el = arrowEls[ai++]; el.style.display = 'block'; const rx = w * 0.4, ry = h * 0.36; el.style.transform = `translate(${w / 2 - Math.sin(rel) * rx}px,${h / 2 - Math.cos(rel) * ry * 0.9}px) rotate(${-rel * 180 / Math.PI + 180 * 0}deg)`; el.classList.toggle('near', d < 10); el.style.opacity = d < 10 ? 1 : 0.8; }
  for (; ai < 6; ai++) arrowEls[ai].style.display = 'none';
}

// =====================================================================================================================
// screens / flow
// =====================================================================================================================
const SCR = ['title', 'pause', 'over', 'victory', 'shop'];
function showScreen(id) { for (const s of SCR) $(s).classList.toggle('show', s === id); }
function updateTitleStats() { $('bestChip').textContent = 'Best ' + save.best.toLocaleString() + (save.bestWave ? '  Wave ' + save.bestWave : ''); $('starsChip').textContent = save.stars; }
function resetRun() {
  Object.assign(run, { score: 0, hearts: 5, wave: 0, stars: 0, combo: 0, comboT: 0, kills: 0, inv: 0, rapid: 0, shield: 0, big: 0, cool: 0, wonOnce: false, shake: 0, over: false });
  for (const e of enemies) { e.alive = false; e.root.visible = false; e.blob.visible = false; }
  for (const p of projs) { p.active = false; p.g.visible = false; } for (const o of orbs) { o.active = false; o.g.visible = false; } for (const p of pickups) { p.active = false; p.g.visible = false; }
  bossE = null; bossFx = 0; queue = []; $('bossBox').classList.remove('on'); $('bubble').classList.remove('on'); $('banner').classList.remove('show');
  yaw = 0; pitch = 0; lastHearts = 5; buildHearts(); updateHearts(false);
}
function startGame() {
  try { music.unlock(); } catch (e) { /* ignore */ }
  resetRun(); equip(WEAPONS[save.eq] && save.lv[save.eq] ? save.eq : 'foam'); state = 'playing'; showScreen(''); $('hud').classList.remove('hidden');
  startWave(1); firedOnce = false;
  if (!save.seen) { $('hint').classList.add('on'); hintT = 9; save.seen = true; persist(); } else { $('hint').classList.remove('on'); hintT = 0; }
  sfx('click'); playTheme('action', 0.4);
}
function toTitle() { state = 'title'; resetRun(); $('hud').classList.add('hidden'); showScreen('title'); updateTitleStats(); setupDemo(); playTheme('action', 0.22); }
function pauseGame() { if (state !== 'playing') return; state = 'paused'; showScreen('pause'); try { music.duck(0.4, 99); } catch (e) { /* ignore */ } fireBtnDown = false; pts.clear(); $('fireBtn').classList.remove('down'); sfx('click'); }
function resumeGame() { if (state !== 'paused') return; state = 'playing'; showScreen(''); try { music.duck(1, 0.1); } catch (e) { /* ignore */ } sfx('click'); }
function gameOver() {
  state = 'over'; overT = 1.6; run.over = true; setTimeout(() => { if (state === 'over' && !shopOpen()) showOver(); }, 1500); fireBtnDown = false; pts.clear(); $('fireBtn').classList.remove('down');
  if (run.score > save.best) save.best = run.score; if (run.wave > save.bestWave) save.bestWave = run.wave; persist(); sfx('lose'); playTheme('calm', 0.2); $('hint').classList.remove('on'); $('bossBox').classList.remove('on'); $('bubble').classList.remove('on');
}
function showOver() {
  const rate = clamp(Math.floor(run.wave / 2), 1, 3); $('overStars').innerHTML = [1, 2, 3].map((i) => `<svg viewBox="0 0 32 32" class="${i <= rate ? '' : 'dim'}"><path d="M16 2l4.2 9 9.8 1.1-7.3 6.7 2 9.7L16 23.6 7.3 28.5l2-9.7L2 12.1 11.8 11z"/></svg>`).join('');
  $('overT').textContent = run.wave >= 5 ? 'Great blasting!' : 'Good try!'; $('overS').textContent = `You reached wave ${run.wave} and popped ${run.kills} bots.`;
  $('overScore').textContent = run.score.toLocaleString(); $('overBest').innerHTML = run.score >= save.best && run.score > 0 ? '<p style="color:#ffe36a">New best score!</p>' : `<p>Best: ${save.best.toLocaleString()}</p>`;
  $('overInfo').textContent = `+${run.stars} stars collected (you have ${save.stars})`; showScreen('over');
}
function victory() {
  state = 'victory'; run.wonOnce = true; $('vicScore').textContent = run.score.toLocaleString(); if (run.score > save.best) save.best = run.score; persist();
  playTheme('victory', 0.8); for (let i = 0; i < 6; i++) setTimeout(() => burst(rand(-6, 6), rand(3, 7), -rand(8, 14), 2, 30, 6, 2), i * 220); showScreen('victory'); fireBtnDown = false; pts.clear();
}
function setupDemo() {
  for (const e of enemies) { e.alive = false; e.root.visible = false; e.blob.visible = false; }
  const spots = [['walker', -6, -11, 0], ['roller', 6.5, -12, 1], ['armor', 0, -17, 2], ['walker', -11, -17, 3], ['drone', 10, -17, 4], ['walker', 4, -8, 5]];
  for (const [t, x, z, i] of spots) { const e = spawnEnemy(t, undefined, x, z); if (e) { e.spawnT = 0.5; e.root.scale.setScalar(1); e.demo = true; e.ph = i; if (t === 'drone') e.y = 3.4; } }
  yaw = 0; pitch = 0.04;
}
function updateTitle(dt) {
  yaw = Math.sin(tAll * 0.25) * 0.5; pitch = 0.05 + Math.sin(tAll * 0.4) * 0.03;
  for (const e of enemies) {
    if (!e.alive) continue; e.t += dt; e.ph += dt * 4; const s = Math.sin(e.ph + e.x);
    const dx = -e.x, dz = -e.z; e.root.rotation.y = Math.atan2(dx, dz) + Math.sin(e.t * 1.5) * 0.3;
    if (e.type === 'walker' || e.type === 'armor') { e.legs[0].rotation.x = s * 0.5; e.legs[1].rotation.x = -s * 0.5; e.arms[0].rotation.z = 2.3 + Math.sin(e.t * 8) * 0.4; e.arms[1].rotation.z = -2.3 - Math.sin(e.t * 8) * 0.4; e.arms[0].rotation.x = 0; e.arms[1].rotation.x = 0; }
    if (e.type === 'roller') e.spin.rotation.x += dt * 2;
    if (e.type === 'drone') for (const r of e.rotors) r.rotation.y += dt * 40;
    const bob = Math.abs(Math.sin(e.ph * 0.5)) * 0.35; e.root.position.set(e.x, e.y + (e.type === 'drone' ? Math.sin(e.t * 2) * 0.3 : bob), e.z);
    e.blob.position.set(e.x, 0.03, e.z); const bs = e.type === 'armor' ? 3.6 : 2.4; e.blob.scale.set(bs, 1, bs);
  }
}

// =====================================================================================================================
// input
// =====================================================================================================================
const keys = {}; const pts = new Map(); let fireBtnDown = false;
const SENS = 0.0052;
stage.addEventListener('pointerdown', (e) => {
  if (state !== 'playing') return; try { music.unlock(); } catch (er) { /* ignore */ } e.preventDefault();
  try { stage.setPointerCapture(e.pointerId); } catch (er) { /* ignore */ }
  pts.set(e.pointerId, { x: e.clientX, y: e.clientY, sx: e.clientX, sy: e.clientY, t: e.timeStamp || performance.now(), moved: false, fire: false });
});
stage.addEventListener('pointermove', (e) => {
  const p = pts.get(e.pointerId); if (!p || state !== 'playing') return;
  const dx = e.clientX - p.x, dy = e.clientY - p.y; p.x = e.clientX; p.y = e.clientY;
  if (!p.moved) { if (Math.hypot(e.clientX - p.sx, e.clientY - p.sy) > 9) { p.moved = true; look(e.clientX - p.sx, e.clientY - p.sy); } return; }
  look(dx, dy);
});
function look(dx, dy) { const f = lockE ? 0.55 : 1; const k = SENS * (innerHeight > innerWidth ? 1.15 : 1); yaw -= dx * k * f; pitch = clamp(pitch - dy * k * 0.85 * f, -0.6, 0.9); }
function endPtr(e) {
  const p = pts.get(e.pointerId); if (!p) return; pts.delete(e.pointerId);
  if (e.type !== 'pointercancel' && !p.moved && !p.fire && (e.timeStamp || performance.now()) - p.t < 300 && state === 'playing') { tapBuf = 0.25; }
}
stage.addEventListener('pointerup', endPtr); stage.addEventListener('pointercancel', endPtr);
const fb = $('fireBtn');
fb.addEventListener('pointerdown', (e) => { e.preventDefault(); e.stopPropagation(); try { music.unlock(); } catch (er) { /* ignore */ } fireBtnDown = true; fb.classList.add('down'); tapBuf = 0.25; try { fb.setPointerCapture(e.pointerId); } catch (er) { /* ignore */ } });
const fbUp = (e) => { fireBtnDown = false; fb.classList.remove('down'); }; fb.addEventListener('pointerup', fbUp); fb.addEventListener('pointercancel', fbUp);
addEventListener('keydown', (e) => {
  if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) e.preventDefault();
  keys[e.code] = true;
  if (e.repeat) return;
  if (e.code === 'Escape' || e.code === 'KeyP') { if (state === 'playing') pauseGame(); else if (state === 'paused') resumeGame(); }
  if (state === 'playing') { if (e.code === 'Digit1') equip('foam'); if (e.code === 'Digit2') equip('twin'); if (e.code === 'Digit3') equip('mega'); }
  if (state === 'title' && (e.code === 'Enter' || e.code === 'Space')) startGame();
});
addEventListener('keyup', (e) => { keys[e.code] = false; });
for (const ev of ['contextmenu', 'gesturestart', 'gesturechange', 'dblclick', 'selectstart']) document.addEventListener(ev, (e) => e.preventDefault());
document.addEventListener('touchmove', (e) => e.preventDefault(), { passive: false });
document.addEventListener('visibilitychange', () => { if (document.hidden) pauseGame(); });

// buttons
const press = (id, fn) => { const b = $(id); b.addEventListener('click', (e) => { try { music.unlock(); } catch (er) { /* ignore */ } fn(e); }); };
press('playBtn', startGame); press('againBtn', startGame); press('againBtn2', () => { startGame(); }); press('restartBtn', startGame);
press('keepBtn', () => { state = 'playing'; showScreen(''); playTheme('action', 0.4); startWave(run.wave + 1); });
press('pauseBtn', pauseGame); press('resumeBtn', resumeGame);
press('muteBtn', toggleMute); press('muteT', toggleMute); press('muteP', toggleMute);
let shopFrom = 'title';
press('shopBtn', () => { shopFrom = 'title'; openShop(); }); press('shopBtn2', () => { shopFrom = 'over'; openShop(); });
press('shopBack', () => { sfx('click'); if (shopFrom === 'over') showOver(); else { showScreen('title'); updateTitleStats(); } });
$('pauseBtn').addEventListener('pointerdown', (e) => e.stopPropagation());
$('muteBtn').addEventListener('pointerdown', (e) => e.stopPropagation());

function openShop() { try { music.unlock(); } catch (e) { /* ignore */ } sfx('click'); renderShop(); showScreen('shop'); }
function renderShop() {
  $('shopStars').textContent = save.stars; const c = $('cards'); c.innerHTML = '';
  WKEYS.forEach((k) => {
    const W = WEAPONS[k], lv = save.lv[k], locked = lv === 0, lvi = Math.max(0, lv - 1);
    const d = document.createElement('div'); d.className = 'card' + (locked ? ' locked' : '') + (save.eq === k ? ' eq' : '');
    const pw = (W.dmg[lvi] * W.pel[lvi] + (W.aoe[lvi] ? 2 : 0)) / 8, sp = (1 / W.rate[lvi]) / 8;
    d.innerHTML = `<div class="gi">${gunSvg(W.hex, locked)}</div><h3>${W.name}</h3><div class="d">${W.desc}</div><div class="stat"><span>Power</span><div class="bar"><i style="transform:scaleX(${clamp(pw, 0.08, 1)})"></i></div></div><div class="stat"><span>Speed</span><div class="bar"><i style="transform:scaleX(${clamp(sp * 2.4, 0.08, 1)})"></i></div></div><div class="pips">${[1, 2, 3].map((i) => `<i class="${i <= lv ? 'on' : ''}"></i>`).join('')}</div>`;
    const main = document.createElement('button'); main.className = 'btn ' + (locked ? 'pink' : 'blue');
    const star = '<svg viewBox="0 0 32 32"><path d="M16 2l4.2 9 9.8 1.1-7.3 6.7 2 9.7L16 23.6 7.3 28.5l2-9.7L2 12.1 11.8 11z"/></svg>';
    if (locked) { main.innerHTML = `Unlock ${star}${W.unlock}`; main.disabled = save.stars < W.unlock; main.onclick = () => { if (save.stars >= W.unlock) { save.stars -= W.unlock; save.lv[k] = 1; save.eq = k; persist(); sfx('powerup'); renderShop(); } }; }
    else if (lv < 3) { main.innerHTML = `Upgrade ${star}${upCost(lv)}`; main.disabled = save.stars < upCost(lv); main.onclick = () => { if (save.stars >= upCost(lv)) { save.stars -= upCost(lv); save.lv[k]++; persist(); sfx('sparkle'); renderShop(); } }; }
    else { main.textContent = 'MAX level!'; main.disabled = true; }
    d.appendChild(main);
    if (!locked) { const eqb = document.createElement('button'); eqb.className = 'btn ' + (save.eq === k ? 'green' : 'ghost'); eqb.textContent = save.eq === k ? 'Equipped' : 'Equip'; eqb.onclick = () => { save.eq = k; persist(); sfx('click'); renderShop(); }; d.appendChild(eqb); }
    c.appendChild(d);
  });
}

// =====================================================================================================================
// resize, render loop
// =====================================================================================================================
function resize() {
  const w = innerWidth, h = innerHeight; renderer.setSize(w, h); composer.setSize(w, h); bloom.setSize(w / 2, h / 2);
  camera.aspect = w / h; const portrait = h > w;
  camera.fov = portrait ? clamp(2 * Math.atan(Math.tan(0.62) / camera.aspect) * 180 / Math.PI, 70, 100) : 66; camera.updateProjectionMatrix();
  for (const k of WKEYS) guns[k].position.set(portrait ? 0.24 : 0.3, portrait ? -0.34 : -0.3, portrait ? -0.62 : -0.55);
}
addEventListener('resize', resize); addEventListener('orientationchange', () => setTimeout(resize, 200));

let last = performance.now(), fpsAcc = 0, fpsN = 0, fpsT = 0;
const camBase = new THREE.Vector3();
function frame(now) {
  requestAnimationFrame(frame);
  const rdt = Math.min(0.25, (now - last) / 1000); last = now; const dt = Math.min(0.05, rdt);
  if (state !== 'paused') {
    tAll += dt;
    if (state === 'playing') updateGame(dt); else if (state === 'title') updateTitle(dt);
    else if (state === 'over') { updateEnemies(dt * 0.3); updateProjectiles(dt); updateOrbs(dt); }
    if (state === 'victory') { updatePickups(dt); }
    confetti.update(dt); starsP.update(dt); boltsP.update(dt); updateFx(dt); updateAmbient(tAll, dt);
    updateFloaters(dt);
    if (state === 'playing') updateHud(dt);
    // adaptive quality
    if (state === 'playing' && !QS.has('q')) { fpsAcc += rdt; fpsN++; fpsT += rdt; if (fpsT > 2.5) { const fps = fpsN / fpsAcc; if (fps < 38 && quality < 2) { quality++; applyQuality(); } fpsAcc = 0; fpsN = 0; fpsT = 0; } }
  }
  // camera
  run.shake = Math.max(0, run.shake - dt * 1.6); const sh = run.shake * run.shake;
  camera.rotation.set(pitch + 0.0035 * Math.sin(tAll * 0.9 + 1) + (Math.random() - 0.5) * sh * 0.08, yaw + (Math.random() - 0.5) * sh * 0.08, (Math.random() - 0.5) * sh * 0.06);
  camera.position.set((Math.random() - 0.5) * sh * 0.25, CAMY + (Math.random() - 0.5) * sh * 0.25 + (state === 'title' ? 0 : 0), 0);
  // gun anim
  if (gun) { kick = Math.max(0, kick - dt * 9); const bx = Math.sin(tAll * 1.7) * 0.004, by = Math.sin(tAll * 2.3) * 0.004; const portrait = innerHeight > innerWidth; gun.position.z = (portrait ? -0.62 : -0.55) + kick * 0.09; gun.position.y = (portrait ? -0.34 : -0.3) + by + kick * 0.01; gun.position.x = (portrait ? 0.24 : 0.3) + bx; gun.rotation.x = kick * 0.12; }
  if (flashT > 0) { flashT -= dt; if (flashT <= 0) flash.visible = false; if (gun) { gun.userData.muzzle.getWorldPosition(tmpA); camera.worldToLocal(tmpA); flash.position.copy(tmpA); } }
  sun.position.set(-16, 30, 12);
  if (!bloomOn) renderer.render(scene, camera); else composer.render();
}
const shopOpen = () => $('shop').classList.contains('show');

// =====================================================================================================================
// boot
// =====================================================================================================================
for (const k in pools) enemies.push(...pools[k]);
resize(); refreshMute(); buildHearts(); updateHearts(false); updateTitleStats();
if (!save.lv[save.eq]) save.eq = 'foam';
equip(save.eq); setupDemo();
renderer.shadowMap.needsUpdate = true;
if (QS.get('q') === 'low') { quality = 2; applyQuality(); }
requestAnimationFrame((t) => { last = t; frame(t); });
window.__rr = { spawn(t, x, z) { const e = spawnEnemy(t, undefined, x, z); if (e) { e.spawnT = 0.5; e.root.scale.setScalar(1); } return e; }, sim(sec, hold) { const n = Math.round(sec / 0.02); for (let i = 0; i < n; i++) { tAll += 0.02; if (state === 'playing') { if (hold) { run.cool = Math.min(run.cool, 0); } updateGame(0.02); } else if (state === 'over') { updateEnemies(0.006); updateProjectiles(0.02); updateOrbs(0.02); } confetti.update(0.02); starsP.update(0.02); boltsP.update(0.02); updateFx(0.02); updatePickups(0.02); } }, aimAt(e) { yaw = Math.atan2(-e.x, -e.z); pitch = Math.atan2(e.y + e.cy - CAMY, Math.hypot(e.x, e.z)); }, scene, camera, run, save, get state() { return state; }, enemies, startGame, pauseGame, resumeGame, fire, get yaw() { return yaw; }, set yaw(v) { yaw = v; }, set pitch(v) { pitch = v; }, killAll() { for (const e of enemies) if (e.alive) hitEnemy(e, 99, e.x, e.y + e.cy, e.z); }, hurt, spawnPickup, music, startWave, get bossE() { return bossE; } };
