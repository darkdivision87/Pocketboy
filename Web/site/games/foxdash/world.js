// Fox Dash: the bent endless world. Materials with a curved-world vertex shader, sky dome, terrain/track tiles,
// instanced scenery for the three biomes (sunny meadow, neon city, candy canyon) and the particle systems.
import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { toonGradient } from './fox.js';

export const LANE_W = 2.2, TILE = 24, TILES_PER_BIOME = 38, BIOME_LEN = TILE * TILES_PER_BIOME;
export const U = { uBendY: { value: 0.0009 }, uBendX: { value: 0 }, uSpin: { value: 0 } };
const smooth = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
export function mulberry(seed) { let a = seed >>> 0; return () => { a |= 0; a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

// Curved world: everything further than a few metres from the camera slopes down and drifts sideways.
export function bend(mat, spin = false) {
  mat.onBeforeCompile = (sh) => {
    sh.uniforms.uBendY = U.uBendY; sh.uniforms.uBendX = U.uBendX; sh.uniforms.uSpin = U.uSpin;
    sh.vertexShader = 'uniform float uBendY;\nuniform float uBendX;\nuniform float uSpin;\n' + sh.vertexShader
      .replace('#include <begin_vertex>', spin ? '#include <begin_vertex>\n float cs=cos(uSpin), sn=sin(uSpin); transformed.xz = mat2(cs,-sn,sn,cs)*transformed.xz;' : '#include <begin_vertex>')
      .replace('#include <project_vertex>', `
        vec4 mvPosition = vec4( transformed, 1.0 );
        #ifdef USE_INSTANCING
          mvPosition = instanceMatrix * mvPosition;
        #endif
        mvPosition = modelViewMatrix * mvPosition;
        float bz = max(0.0, -mvPosition.z - 7.0);
        mvPosition.y -= bz * bz * uBendY;
        mvPosition.x += bz * bz * uBendX;
        gl_Position = projectionMatrix * mvPosition;`);
  };
  mat.customProgramCacheKey = () => 'bend' + (spin ? 'S' : '');
  return mat;
}

export const BIOMES = [
  { name: 'Sunny Meadow', music: 'sunny', top: '#2f86ff', mid: '#8ed4ff', bot: '#e8f6ff', fog: '#d6eeff', hemiS: '#e2f2ff', hemiG: '#7fcf6a', sun: '#fff0c4', sunI: 2.3, hemiI: 1.1, stars: 0, bloom: 0.28 },
  { name: 'Neon City', music: 'neon', top: '#080428', mid: '#4a1a8a', bot: '#ff5db0', fog: '#5b1f8c', hemiS: '#9a7bff', hemiG: '#3a1a6a', sun: '#ff9ad8', sunI: 1.8, hemiI: 1.5, stars: 1, bloom: 0.5 },
  { name: 'Candy Canyon', music: 'toy', top: '#ff8ac4', mid: '#ffc6e2', bot: '#fff1d0', fog: '#ffd9ea', hemiS: '#fff0fa', hemiG: '#ffb6d8', sun: '#fff4d6', sunI: 2.0, hemiI: 1.2, stars: 0, bloom: 0.3 },
];
for (const b of BIOMES) for (const k of ['top', 'mid', 'bot', 'fog', 'hemiS', 'hemiG', 'sun']) b[k + 'C'] = new THREE.Color(b[k]);

// biome weights at world z (smooth ground blending across the border; decor uses the hard biomeAt)
export function biomeAt(z) { const t = -z / BIOME_LEN; return t < 0 ? 0 : Math.floor(t) % 3; }
export function weights(z, out) {
  const t = -z / BIOME_LEN; out[0] = out[1] = out[2] = 0;
  const k = Math.round(t);
  if (k <= 0) { out[0] = 1; return out; }
  const d = (t - k) * BIOME_LEN, s = smooth(-60, 60, d);
  out[(k - 1) % 3] += 1 - s; out[k % 3] += s; return out;
}
function nz(x, z) { return Math.sin(x * 0.17 + z * 0.11) * 0.5 + Math.sin(x * 0.07 - z * 0.19 + 1.3) * 0.35 + Math.sin(x * 0.31 + z * 0.05 + 4) * 0.15; }
function hOf(b, x, z) {
  const ax = Math.abs(x), e = smooth(4.5, 16, ax), far = smooth(14, 70, ax);
  if (b === 0) return e * (0.6 * nz(x, z) + 0.7) * 1.4 + far * (nz(x * 0.5, z * 0.5) + 1.1) * 5;
  if (b === 1) return e * 0.15 * (nz(x, z) + 1);
  return e * (0.9 * nz(x, z) + 1) * 1.1 + far * (nz(x * 0.6 + 9, z * 0.6) + 1.1) * 6.5;
}
const _w = [0, 0, 0];
export function terrainH(x, z) { weights(z, _w); return -0.07 + _w[0] * hOf(0, x, z) + _w[1] * hOf(1, x, z) + _w[2] * hOf(2, x, z); }

// ---------- procedural helpers ----------
const _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _e = new THREE.Euler(), _s = new THREE.Vector3(), _p = new THREE.Vector3();
export function part(geo, color, o = {}) {
  const g = geo.clone(); const p = o.p || [0, 0, 0], s = o.s || [1, 1, 1], r = o.r || [0, 0, 0];
  _e.set(r[0], r[1], r[2]); _q.setFromEuler(_e); _m.compose(_p.set(p[0], p[1], p[2]), _q, _s.set(s[0], s[1], s[2])); g.applyMatrix4(_m);
  g.deleteAttribute('uv');
  const c = new THREE.Color(color), k = o.k || 1, n = g.attributes.position.count, arr = new Float32Array(n * 3);
  for (let i = 0; i < n; i++) { arr[i * 3] = c.r * k; arr[i * 3 + 1] = c.g * k; arr[i * 3 + 2] = c.b * k; }
  g.setAttribute('color', new THREE.BufferAttribute(arr, 3)); return g;
}
export function merged(parts, flat = true) { let g = mergeGeometries(parts, false); if (flat) { g = g.toNonIndexed(); g.computeVertexNormals(); } return g; }
export function canvasTex(w, h, draw, srgb = true) {
  const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); if (srgb) t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4; return t;
}
export const toonMat = (o = {}) => bend(new THREE.MeshToonMaterial({ gradientMap: toonGradient(), ...o }));
export const glowMat = () => bend(new THREE.MeshBasicMaterial({ vertexColors: true, fog: true }));

const SPH = new THREE.SphereGeometry(1, 10, 7), CYL = new THREE.CylinderGeometry(1, 1, 1, 9), CONE = new THREE.ConeGeometry(1, 1, 9), BOX = new THREE.BoxGeometry(1, 1, 1);
const TOR = (r, t, arc = Math.PI * 2) => new THREE.TorusGeometry(r, t, 6, 18, arc);

// ---------- scenery kinds ----------
function buildKinds() {
  const K = {};
  const dm = toonMat({ vertexColors: true }), gm = glowMat();
  const def = (name, geo, mat, cap) => { K[name] = { name, geo, mat, cap, free: [], mesh: null }; };
  // meadow
  def('tree', merged([part(CYL, '#8a5a34', { p: [0, 0.9, 0], s: [0.28, 1.8, 0.28] }), part(SPH, '#49b84a', { p: [0, 2.6, 0], s: [1.5, 1.35, 1.5] }), part(SPH, '#62cf55', { p: [0.55, 3.2, 0.2], s: [1.0, 0.95, 1.0] }), part(SPH, '#3da646', { p: [-0.6, 2.2, -0.3], s: [0.95, 0.9, 0.95] })]), dm, 90);
  def('pine', merged([part(CYL, '#7a4c2c', { p: [0, 0.5, 0], s: [0.22, 1, 0.22] }), part(CONE, '#2f9a58', { p: [0, 1.7, 0], s: [1.3, 1.7, 1.3] }), part(CONE, '#3bb36a', { p: [0, 2.8, 0], s: [1.0, 1.5, 1.0] }), part(CONE, '#52cc7c', { p: [0, 3.7, 0], s: [0.7, 1.3, 0.7] })]), dm, 70);
  def('bush', merged([part(SPH, '#4cc04a', { p: [0, 0.4, 0], s: [0.9, 0.62, 0.8] }), part(SPH, '#66d55a', { p: [0.55, 0.35, 0.1], s: [0.6, 0.45, 0.55] }), part(SPH, '#ff6f91', { p: [0.2, 0.72, 0.5], s: [0.13, 0.13, 0.13] }), part(SPH, '#ffe066', { p: [-0.4, 0.8, 0.2], s: [0.13, 0.13, 0.13] })]), dm, 90);
  def('flower', merged([part(CYL, '#3da646', { p: [0, 0.3, 0], s: [0.03, 0.6, 0.03] }), part(SPH, '#fff', { p: [0, 0.65, 0], s: [0.22, 0.12, 0.22] }), part(SPH, '#ffd23f', { p: [0, 0.7, 0], s: [0.1, 0.08, 0.1] }),
    part(CYL, '#3da646', { p: [0.3, 0.22, 0.1], s: [0.03, 0.44, 0.03] }), part(SPH, '#fff', { p: [0.3, 0.5, 0.1], s: [0.18, 0.1, 0.18] }), part(SPH, '#ffd23f', { p: [0.3, 0.55, 0.1], s: [0.08, 0.07, 0.08] })]), dm, 120);
  def('rock', merged([part(SPH, '#9aa3b5', { p: [0, 0.35, 0], s: [0.8, 0.55, 0.65] }), part(SPH, '#b3bccd', { p: [0.5, 0.25, 0.2], s: [0.45, 0.38, 0.4] })]), dm, 60);
  def('hill', merged([part(SPH, '#52c455', { p: [0, 0, 0], s: [1, 0.55, 1] }), part(SPH, '#66d964', { p: [0.3, 0.3, -0.2], s: [0.5, 0.35, 0.5] })], false), dm, 24);
  def('windmill', merged([part(CONE, '#e8d2a4', { p: [0, 1.6, 0], s: [1.1, 3.2, 1.1] }), part(CONE, '#d9534f', { p: [0, 3.6, 0], s: [1.3, 1.1, 1.3] }),
    part(BOX, '#fff', { p: [0, 3.2, -0.65], s: [3.4, 0.28, 0.1], r: [0, 0, 0.5] }), part(BOX, '#fff', { p: [0, 3.2, -0.65], s: [0.28, 3.4, 0.1], r: [0, 0, 0.5] })]), dm, 6);
  // city
  const winTex = (seed) => canvasTex(128, 256, (g, w, h) => {
    const r = mulberry(seed); g.fillStyle = '#17123e'; g.fillRect(0, 0, w, h);
    const cols = ['#ffd86a', '#7cf3ff', '#ff7ad9', '#fff1b0', '#9d7bff'];
    for (let y = 6; y < h - 6; y += 16) for (let x = 8; x < w - 8; x += 16) { if (r() < 0.62) { g.fillStyle = cols[(r() * cols.length) | 0]; g.globalAlpha = 0.6 + r() * 0.4; g.fillRect(x, y, 9, 10); g.globalAlpha = 1; } else { g.fillStyle = '#241c5c'; g.fillRect(x, y, 9, 10); } }
  });
  const bmat = (seed, rx, ry) => { const t = winTex(seed); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(rx, ry); const m = toonMat({ map: t, emissiveMap: t, emissive: new THREE.Color('#ffffff'), emissiveIntensity: 1.25 }); return m; };
  const bgeo = (w, h, d) => { const g = new THREE.BoxGeometry(w, h, d); g.translate(0, h / 2, 0); const n = g.attributes.normal; void n; return g; };
  def('bldgA', bgeo(6, 38, 6), bmat(1, 2, 3.4), 40); def('bldgB', bgeo(7, 20, 7), bmat(2, 2.4, 2), 40); def('bldgC', bgeo(12, 11, 8), bmat(3, 4, 1.2), 30);
  def('lamp', merged([part(CYL, '#2a2458', { p: [0, 1.6, 0], s: [0.09, 3.2, 0.09] }), part(CYL, '#2a2458', { p: [-0.35, 3.2, 0], s: [0.7, 0.07, 0.07], r: [0, 0, 0] })]), dm, 60);
  def('lampGlow', merged([part(SPH, '#ffe9a8', { p: [-0.7, 3.12, 0], s: [0.2, 0.12, 0.2], k: 2.2 })], false), gm, 60);
  def('sign', merged([part(BOX, '#ffffff', { s: [0.2, 1, 0.2], k: 1.5 })], false), gm, 70);
  def('holo', merged([part(TOR(1, 0.07), '#ffffff', { k: 2.2 }), part(TOR(0.7, 0.05), '#ffffff', { k: 1.8, r: [0.6, 0, 0] })], false), gm, 14);
  // candy
  const stripes = (col1, col2, n, h) => { const a = []; for (let i = 0; i < n; i++) a.push(part(CYL, i % 2 ? col1 : col2, { p: [0, (i + 0.5) * h / n, 0], s: [0.2, h / n * 1.02, 0.2] })); return a; };
  def('cane', merged([...stripes('#ff4d6d', '#ffffff', 10, 3.6), ...[0, 1, 2, 3, 4].map((i) => part(CYL, i % 2 ? '#ff4d6d' : '#ffffff', { p: [0.5 - 0.5 * Math.cos(i * 0.5), 3.6 + 0.5 * Math.sin(i * 0.5 + 0.2), 0], s: [0.2, 0.42, 0.2], r: [0, 0, -(i * 0.5 + 0.2) - Math.PI / 2 + Math.PI / 2] }))]), dm, 60);
  def('lolly', merged([part(CYL, '#fff', { p: [0, 1.4, 0], s: [0.1, 2.8, 0.1] }), part(CYL, '#ff6fb5', { p: [0, 3.2, 0], s: [1.2, 0.22, 1.2], r: [Math.PI / 2, 0, 0] }), part(CYL, '#ffffff', { p: [0, 3.2, 0.02], s: [0.9, 0.22, 0.9], r: [Math.PI / 2, 0, 0] }), part(CYL, '#8a6bff', { p: [0, 3.2, 0.04], s: [0.6, 0.22, 0.6], r: [Math.PI / 2, 0, 0] }), part(CYL, '#ffd23f', { p: [0, 3.2, 0.06], s: [0.3, 0.22, 0.3], r: [Math.PI / 2, 0, 0] })]), dm, 60);
  def('gumdrop', merged([part(SPH, '#ffffff', { p: [0, 0.55, 0], s: [0.75, 0.85, 0.75] }), part(SPH, '#ffffff', { p: [0, 1.05, 0], s: [0.45, 0.5, 0.45] })]), dm, 110);
  def('cupcake', merged([part(CONE, '#d9a066', { p: [0, 0.5, 0], s: [0.95, 1, 0.95], r: [Math.PI, 0, 0] }), part(SPH, '#fff0f6', { p: [0, 1.15, 0], s: [1.0, 0.55, 1.0] }), part(SPH, '#ff9ec7', { p: [0, 1.55, 0], s: [0.65, 0.4, 0.65] }), part(SPH, '#e8203c', { p: [0, 1.95, 0], s: [0.2, 0.2, 0.2] })]), dm, 60);
  def('donut', merged([part(TOR(0.8, 0.38), '#e9a860', { p: [0, 0.8, 0], r: [Math.PI / 2 - 0.25, 0, 0] }), part(TOR(0.8, 0.4), '#ff8fc0', { p: [0, 0.86, 0.02], s: [1, 1, 0.8], r: [Math.PI / 2 - 0.25, 0, 0] })]), dm, 50);
  def('cone', merged([part(CONE, '#e8b472', { p: [0, 1.2, 0], s: [0.8, 2.4, 0.8], r: [Math.PI, 0, 0] }), part(SPH, '#ffe0ee', { p: [0, 2.6, 0], s: [0.95, 0.9, 0.95] }), part(SPH, '#9fe8d8', { p: [0, 3.45, 0], s: [0.78, 0.74, 0.78] }), part(SPH, '#e8203c', { p: [0, 4.1, 0], s: [0.16, 0.16, 0.16] })]), dm, 50);
  def('swirl', merged([part(SPH, '#ff9ec7', { s: [1, 0.6, 1] }), part(SPH, '#fff0d6', { p: [0.0, 0.1, 0], s: [0.8, 0.52, 0.8] }), part(SPH, '#ff9ec7', { p: [0, 0.2, 0], s: [0.58, 0.46, 0.58] }), part(SPH, '#fff0d6', { p: [0, 0.3, 0], s: [0.36, 0.4, 0.36] })], false), dm, 24);
  // shared
  def('cloud', merged([part(SPH, '#ffffff', { s: [1.4, 0.8, 1], k: 1.35 }), part(SPH, '#ffffff', { p: [1.1, -0.1, 0.1], s: [1.0, 0.65, 0.8], k: 1.3 }), part(SPH, '#ffffff', { p: [-1.2, -0.15, 0], s: [0.95, 0.6, 0.8], k: 1.3 }), part(SPH, '#ffffff', { p: [0.2, 0.45, 0], s: [0.9, 0.7, 0.8], k: 1.45 })], false), bend(new THREE.MeshBasicMaterial({ vertexColors: true, fog: false })), 40);
  def('arch', merged([part(TOR(4.6, 0.32, Math.PI), '#ffffff', { k: 2.0 }), part(TOR(4.0, 0.14, Math.PI), '#ffffff', { k: 1.4 }), part(CYL, '#ffffff', { p: [4.6, 0.25, 0], s: [0.5, 0.5, 0.5], k: 1.2 }), part(CYL, '#ffffff', { p: [-4.6, 0.25, 0], s: [0.5, 0.5, 0.5], k: 1.2 })], false), gm, 8);
  return K;
}

// ---------- track textures ----------
function trackTextures() {
  const W = 256, H = 768, ppu = 33.7;
  const lines = (g, col, w, dash) => { g.strokeStyle = col; g.lineWidth = w; g.setLineDash(dash || []); for (const s of [-1, 1]) { g.beginPath(); g.moveTo(128 + s * 1.1 * ppu, 0); g.lineTo(128 + s * 1.1 * ppu, H); g.stroke(); } g.setLineDash([]); };
  const meadow = canvasTex(W, H, (g) => {
    const r = mulberry(4); g.fillStyle = '#ecd29a'; g.fillRect(0, 0, W, H);
    for (let i = 0; i < 230; i++) { const x = 18 + r() * 220, y = 8 + r() * 750, w = 14 + r() * 24, h = 10 + r() * 14; g.fillStyle = `hsl(${36 + r() * 10},${50 + r() * 20}%,${66 + r() * 12}%)`; g.beginPath(); g.roundRect(x, y, w, h, 5); g.fill(); }
    g.fillStyle = '#6fbf4e'; g.fillRect(0, 0, 14, H); g.fillRect(W - 14, 0, 14, H); g.fillStyle = '#8a6a3c'; g.fillRect(14, 0, 4, H); g.fillRect(W - 18, 0, 4, H);
    lines(g, 'rgba(255,255,255,0.55)', 3, [38, 52]);
  });
  const cityE = canvasTex(W, H, (g) => { g.fillStyle = '#000'; g.fillRect(0, 0, W, H); lines(g, '#35e6ff', 4); g.fillStyle = '#ff3fd0'; g.fillRect(6, 0, 6, H); g.fillRect(W - 12, 0, 6, H);
    g.fillStyle = 'rgba(120,80,255,0.6)'; for (let y = 0; y < H; y += 96) g.fillRect(30, y, W - 60, 3); });
  const city = canvasTex(W, H, (g) => { g.fillStyle = '#1c1650'; g.fillRect(0, 0, W, H); const gr = g.createLinearGradient(0, 0, W, 0); gr.addColorStop(0, 'rgba(255,255,255,0.06)'); gr.addColorStop(0.5, 'rgba(255,255,255,0)'); gr.addColorStop(1, 'rgba(255,255,255,0.06)'); g.fillStyle = gr; g.fillRect(0, 0, W, H);
    g.strokeStyle = 'rgba(120,100,255,0.25)'; g.lineWidth = 1; for (let y = 0; y < H; y += 48) { g.beginPath(); g.moveTo(0, y); g.lineTo(W, y); g.stroke(); } lines(g, '#35e6ff', 4); g.fillStyle = '#ff3fd0'; g.fillRect(6, 0, 6, H); g.fillRect(W - 12, 0, 6, H); });
  const candy = canvasTex(W, H, (g) => {
    const r = mulberry(9); g.fillStyle = '#ffc2dd'; g.fillRect(0, 0, W, H);
    for (let y = 0; y < H; y += 128) { g.fillStyle = 'rgba(255,255,255,0.35)'; g.fillRect(0, y, W, 64); }
    g.fillStyle = '#ff6fb0'; g.fillRect(0, 0, 14, H); g.fillRect(W - 14, 0, 14, H); g.fillStyle = '#fff'; for (let y = 0; y < H; y += 40) { g.fillRect(0, y, 14, 20); g.fillRect(W - 14, y + 20, 14, 20); }
    const cols = ['#ff4d6d', '#7a5cff', '#2fd6b0', '#ffd23f', '#3fb7ff'];
    for (let i = 0; i < 150; i++) { g.save(); g.translate(20 + r() * 216, r() * H); g.rotate(r() * 6.28); g.fillStyle = cols[(r() * 5) | 0]; g.beginPath(); g.roundRect(-5, -1.6, 10, 3.2, 1.6); g.fill(); g.restore(); }
    lines(g, 'rgba(255,255,255,0.8)', 3, [34, 40]);
  });
  return [{ map: meadow }, { map: city, emissiveMap: cityE }, { map: candy }];
}

export class Particles {
  constructor(scene, cap, additive) {
    this.cap = cap; this.n = 0; this.next = 0;
    const g = new THREE.BufferGeometry();
    this.pos = new Float32Array(cap * 3); this.col = new Float32Array(cap * 4); this.siz = new Float32Array(cap);
    g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3)); g.setAttribute('color', new THREE.BufferAttribute(this.col, 4)); g.setAttribute('size', new THREE.BufferAttribute(this.siz, 1));
    this.vel = new Float32Array(cap * 3); this.life = new Float32Array(cap); this.max = new Float32Array(cap); this.s0 = new Float32Array(cap); this.grav = new Float32Array(cap);
    this.uScale = { value: 600 };
    this.mat = new THREE.ShaderMaterial({ transparent: true, depthWrite: false, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending, uniforms: { uScale: this.uScale },
      vertexShader: `attribute float size; attribute vec4 color; varying vec4 vC; uniform float uScale; void main(){ vC=color; vec4 mv=modelViewMatrix*vec4(position,1.0); gl_PointSize=size*uScale/max(0.1,-mv.z); gl_Position=projectionMatrix*mv; }`,
      fragmentShader: `varying vec4 vC; void main(){ vec2 d=gl_PointCoord-0.5; float r=length(d)*2.0; float a=smoothstep(1.0,0.35,r); gl_FragColor=vec4(vC.rgb, vC.a*a); }` });
    this.points = new THREE.Points(g, this.mat); this.points.frustumCulled = false; this.points.renderOrder = 5; scene.add(this.points); this.geo = g;
    this.siz.fill(0);
  }
  emit(x, y, z, vx, vy, vz, life, size, r, g, b, grav = 0) {
    const i = this.next; this.next = (this.next + 1) % this.cap; const p = i * 3;
    this.pos[p] = x; this.pos[p + 1] = y; this.pos[p + 2] = z; this.vel[p] = vx; this.vel[p + 1] = vy; this.vel[p + 2] = vz;
    this.life[i] = life; this.max[i] = life; this.s0[i] = size; this.grav[i] = grav; this.col[i * 4] = r; this.col[i * 4 + 1] = g; this.col[i * 4 + 2] = b; this.col[i * 4 + 3] = 1; this.siz[i] = size;
  }
  update(dt) {
    for (let i = 0; i < this.cap; i++) {
      if (this.life[i] <= 0) continue; this.life[i] -= dt; const p = i * 3;
      if (this.life[i] <= 0) { this.siz[i] = 0; continue; }
      this.vel[p + 1] -= this.grav[i] * dt; this.pos[p] += this.vel[p] * dt; this.pos[p + 1] += this.vel[p + 1] * dt; this.pos[p + 2] += this.vel[p + 2] * dt;
      const k = this.life[i] / this.max[i]; this.siz[i] = this.s0[i] * (0.4 + 0.6 * k); this.col[i * 4 + 3] = Math.min(1, k * 2);
    }
    this.geo.attributes.position.needsUpdate = true; this.geo.attributes.color.needsUpdate = true; this.geo.attributes.size.needsUpdate = true;
  }
}

const XS = [-62, -46, -34, -25, -18, -13, -9, -6.5, -4.4, -3.4, 3.4, 4.4, 6.5, 9, 13, 18, 25, 34, 46, 62], NZ = 8;
const BASE = { b0: [new THREE.Color('#5bc948'), new THREE.Color('#92e05a'), new THREE.Color('#aaea72'), new THREE.Color('#2f9d54')], b1: [new THREE.Color('#1d1654'), new THREE.Color('#2c2078'), new THREE.Color('#3b2a9a'), new THREE.Color('#150f40')],
  b2: [new THREE.Color('#ff9ec7'), new THREE.Color('#fff0d4'), new THREE.Color('#9fe8d4'), new THREE.Color('#ffc0dc')] };

export class World {
  constructor(scene, renderer) {
    this.scene = scene; this.renderer = renderer; this.K = buildKinds(); this.tiles = new Map(); this.pool = [];
    this.rng = Math.random; this.t = 0; this.fogC = new THREE.Color('#d6eeff');
    for (const k of Object.values(this.K)) {
      const m = new THREE.InstancedMesh(k.geo, k.mat, k.cap); m.frustumCulled = false; m.visible = false; k.active = 0;
      const z = new THREE.Matrix4().compose(new THREE.Vector3(0, -900, 0), new THREE.Quaternion(), new THREE.Vector3(0.001, 0.001, 0.001)); const w = new THREE.Color(1, 1, 1);
      for (let i = 0; i < k.cap; i++) { m.setMatrixAt(i, z); m.setColorAt(i, w); k.free.push(k.cap - 1 - i); }
      k.mesh = m; k.zero = z; scene.add(m);
    }
    // terrain index (shared)
    const idx = []; for (let j = 0; j < NZ; j++) for (let i = 0; i < XS.length - 1; i++) { const a = j * XS.length + i, b = a + 1, c = a + XS.length, d = c + 1; idx.push(a, b, c, b, d, c); }
    this.terrIdx = idx;
    this.terrMat = toonMat({ vertexColors: true });
    const tt = trackTextures(); this.trackMats = tt.map((o) => toonMat({ ...o, ...(o.emissiveMap ? { emissive: new THREE.Color('#ffffff'), emissiveIntensity: 1.3 } : {}) }));
    this.trackGeo = new THREE.PlaneGeometry(7.6, TILE); this.trackGeo.rotateX(-Math.PI / 2);
    // sky
    this.skyU = { uTop: { value: new THREE.Color() }, uMid: { value: new THREE.Color() }, uBot: { value: new THREE.Color() }, uSun: { value: new THREE.Vector3(-0.3, 0.38, -0.87).normalize() }, uSunC: { value: new THREE.Color() }, uStars: { value: 0 }, uTime: { value: 0 } };
    this.sky = new THREE.Mesh(new THREE.SphereGeometry(500, 24, 16), new THREE.ShaderMaterial({ side: THREE.BackSide, depthWrite: false, fog: false, uniforms: this.skyU,
      vertexShader: 'varying vec3 vD; void main(){ vD=position; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0); }',
      fragmentShader: `varying vec3 vD; uniform vec3 uTop,uMid,uBot,uSun,uSunC; uniform float uStars,uTime;
      void main(){ vec3 d=normalize(vD); float h=d.y; vec3 c=mix(uBot,uMid,smoothstep(-0.02,0.22,h)); c=mix(c,uTop,smoothstep(0.18,0.85,h)); c=mix(c,uBot,smoothstep(0.0,-0.25,h));
        float s=max(dot(d,uSun),0.0); c+=uSunC*(pow(s,2500.0)*3.0+pow(s,10.0)*0.1);
        if(uStars>0.0){ vec3 q=floor(d*70.0); float r=fract(sin(dot(q,vec3(12.9898,78.233,37.719)))*43758.5453); float tw=step(0.988,r)*(0.55+0.45*sin(uTime*3.0+r*40.0)); c+=vec3(tw*1.4)*uStars*smoothstep(0.08,0.5,h);} gl_FragColor=vec4(c,1.0); }` }));
    this.sky.renderOrder = -10; this.sky.frustumCulled = false; scene.add(this.sky);
    scene.fog = new THREE.Fog('#d6eeff', 35, 175);
    this.hemi = new THREE.HemisphereLight('#fff', '#8c8', 1.1); scene.add(this.hemi);
    this.sun = new THREE.DirectionalLight('#fff', 2.2); this.sun.position.set(-4, 9, -3); scene.add(this.sun); scene.add(this.sun.target);
    this.cur = { top: new THREE.Color(), mid: new THREE.Color(), bot: new THREE.Color(), fog: new THREE.Color(), hemiS: new THREE.Color(), hemiG: new THREE.Color(), sun: new THREE.Color(), sunI: 2, hemiI: 1, stars: 0, bloom: 0.3 };
    this._w = [1, 0, 0]; this.atmInit = false; this.bloom = 0.3;
  }

  spawnItem(tile, kindName, x, y, z, sx, sy, sz, ry, color) {
    const k = this.K[kindName]; if (!k.free.length) return;
    const i = k.free.pop(); _e.set(0, ry, 0); _q.setFromEuler(_e); _m.compose(_p.set(x, y, z), _q, _s.set(sx, sy, sz)); k.mesh.setMatrixAt(i, _m);
    if (color) k.mesh.setColorAt(i, color); k.mesh.instanceMatrix.needsUpdate = true; if (color && k.mesh.instanceColor) k.mesh.instanceColor.needsUpdate = true;
    k.active++; k.mesh.visible = true; tile.items.push(k, i);
  }
  freeItems(tile) {
    const it = tile.items; for (let n = 0; n < it.length; n += 2) { const k = it[n], i = it[n + 1]; k.mesh.setMatrixAt(i, k.zero); k.free.push(i); k.active--; k.mesh.instanceMatrix.needsUpdate = true; if (k.active <= 0) k.mesh.visible = false; }
    it.length = 0;
  }

  makeTile() {
    const g = new THREE.BufferGeometry(); const n = XS.length * (NZ + 1);
    g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(n * 3), 3)); g.setAttribute('color', new THREE.BufferAttribute(new Float32Array(n * 3), 3)); g.setAttribute('normal', new THREE.BufferAttribute(new Float32Array(n * 3), 3));
    g.setIndex(this.terrIdx);
    const terrain = new THREE.Mesh(g, this.terrMat); terrain.frustumCulled = false; const track = new THREE.Mesh(this.trackGeo, this.trackMats[0]); track.frustumCulled = false; track.position.y = 0;
    this.scene.add(terrain, track); return { idx: null, terrain, track, items: [] };
  }
  buildTile(tile, idx) {
    tile.idx = idx; const zc = -(idx + 0.5) * TILE; tile.terrain.position.set(0, 0, zc); tile.track.position.z = zc;
    const bi = idx < 0 ? 0 : Math.floor(idx / TILES_PER_BIOME) % 3; tile.track.material = this.trackMats[bi];
    const P = tile.terrain.geometry.attributes.position, C = tile.terrain.geometry.attributes.color, w = [0, 0, 0], col = new THREE.Color(), tmp = new THREE.Color();
    let v = 0;
    for (let j = 0; j <= NZ; j++) {
      const lz = TILE / 2 - (j / NZ) * TILE, wz = zc + lz; weights(wz, w);
      for (let i = 0; i < XS.length; i++, v++) {
        const x = XS[i]; let h = -0.07, ax = Math.abs(x);
        col.setRGB(0, 0, 0);
        for (let b = 0; b < 3; b++) {
          if (w[b] < 0.001) continue; const hb = hOf(b, x, wz); h += w[b] * hb; const n = nz(x, wz) * 0.5 + 0.5; const pal = b === 0 ? BASE.b0 : b === 1 ? BASE.b1 : BASE.b2;
          if (b === 2) { const f = (Math.sin(wz * 0.09 + x * 0.05 + n * 3.0) * 0.5 + 0.5); tmp.copy(f > 0.66 ? pal[0] : f > 0.34 ? pal[1] : pal[2]); if (ax < 8) tmp.lerp(pal[3], 0.4); }
          else { tmp.copy(pal[0]).lerp(pal[1], n); if (ax < 9) tmp.lerp(pal[2], 0.4 * (1 - ax / 9)); if (hb > 4) tmp.lerp(pal[3], Math.min(0.6, (hb - 4) * 0.07)); }
          col.r += tmp.r * w[b]; col.g += tmp.g * w[b]; col.b += tmp.b * w[b];
        }
        P.setXYZ(v, x, h, lz); C.setXYZ(v, col.r, col.g, col.b);
      }
    }
    P.needsUpdate = true; C.needsUpdate = true; tile.terrain.geometry.computeVertexNormals();
    this.decorate(tile, idx, zc);
  }

  decorate(tile, idx, zc) {
    const r = mulberry(idx * 7919 + 17), z0 = zc + TILE / 2, col = new THREE.Color();
    const rr = (a, b) => a + r() * (b - a);
    const sp = (kind, x, z, sc, o = {}) => this.spawnItem(tile, kind, x, (o.y !== undefined ? o.y : terrainH(x, z)), z, sc * (o.sx || 1), sc * (o.sy || 1), sc * (o.sz || 1), o.ry !== undefined ? o.ry : r() * 6.28, o.color);
    for (let side = -1; side <= 1; side += 2) {
      for (let n = 0; n < 7; n++) {
        const z = z0 - r() * TILE, b = biomeAt(z), x = side * (5.4 + Math.pow(r(), 1.5) * 38);
        if (b === 0) { const q = r(); if (q < 0.26) sp('tree', x, z, rr(0.8, 1.5)); else if (q < 0.46) sp('pine', x, z, rr(0.8, 1.5)); else if (q < 0.62) sp('bush', x, z, rr(0.8, 1.4)); else if (q < 0.88) { col.setHSL(r(), 0.8, 0.7); sp('flower', x, z, rr(1.2, 2.2), { color: col }); } else sp('rock', x, z, rr(0.8, 1.6)); }
        else if (b === 2) { const q = r(); col.setHSL(r(), 0.7, 0.72); if (q < 0.22) sp('cane', x, z, rr(0.9, 1.6)); else if (q < 0.42) sp('lolly', x, z, rr(0.9, 1.5)); else if (q < 0.68) sp('gumdrop', x, z, rr(0.8, 1.7), { color: col }); else if (q < 0.8) sp('cupcake', x, z, rr(1, 1.7)); else if (q < 0.9) sp('donut', x, z, rr(1, 1.6)); else sp('cone', x, z, rr(0.9, 1.5)); }
      }
      const zb = z0 - r() * TILE, bb = biomeAt(zb);
      if (bb === 1) {
        for (let n = 0; n < 2; n++) {
          const z = z0 - (n + r() * 0.8) * (TILE / 2); const cls = r(), name = cls < 0.5 ? 'bldgA' : cls < 0.8 ? 'bldgB' : 'bldgC', wd = name === 'bldgC' ? 12 : name === 'bldgB' ? 7 : 6;
          const sc = rr(0.85, 1.3), x = side * (5.6 + wd * sc / 2 + r() * 4 + (n ? 12 + r() * 14 : 0)); sp(name, x, z, 1, { sx: sc * 0.95 + 0.05, sy: sc, sz: sc, ry: 0, y: 0 });
          if (n === 0 && r() < 0.8) { col.setHSL(r() < 0.5 ? 0.5 : 0.88, 1, 0.5); sp('sign', side * (x * side - wd * sc / 2 - 0.4), z + wd * sc * 0.5 * 0.0, rr(2, 5), { y: rr(4, 16), ry: 0, sy: 1, color: col, sx: 1, sz: 1 }); }
        }
        if (r() < 0.12) { col.setHSL(r() < 0.5 ? 0.5 : 0.85, 1, 0.6); sp('holo', side * rr(30, 60), z0 - r() * TILE, rr(4, 9), { y: rr(14, 34), color: col }); }
        for (let n = 0; n < 2; n++) { const z = z0 - n * 12 - 3; this.spawnItem(tile, 'lamp', side * 4.5, 0, z, 1, 1, 1, side > 0 ? 0 : Math.PI); this.spawnItem(tile, 'lampGlow', side * 4.5, 0, z, 1, 1, 1, side > 0 ? 0 : Math.PI); }
      } else if (bb === 0) {
        if (r() < 0.38) sp('hill', side * rr(50, 90), z0 - r() * TILE, rr(14, 28), { y: terrainH(side * 70, zb) - 4, sy: 1 });
        if (r() < 0.07) sp('windmill', side * rr(14, 30), zb, rr(1.4, 2.0));
      } else if (r() < 0.4) sp('swirl', side * rr(48, 90), z0 - r() * TILE, rr(14, 26), { y: terrainH(side * 70, zb) - 3 });
      if (r() < 0.4 && bb !== 1) { if (bb === 2) col.setRGB(1, 0.85, 0.93); else col.setRGB(1, 1, 1); sp('cloud', side * rr(15, 130), z0 - r() * TILE, rr(4, 9), { y: rr(26, 50), color: col, ry: 0, sy: 0.8 }); }
    }
    // arches over the track now and then, plus the biome gate
    const bz = idx - Math.floor(idx / TILES_PER_BIOME) * TILES_PER_BIOME;
    if (idx >= 1 && bz === 0) { const nb = Math.floor(idx / TILES_PER_BIOME) % 3; col.set(nb === 0 ? '#ffe36a' : nb === 1 ? '#40e8ff' : '#ff7fc4'); this.spawnItem(tile, 'arch', 0, 0, z0 - 1, 1.55, 1.7, 1.2, 0, col); col.set(nb === 0 ? '#ffffff' : nb === 1 ? '#ff4fd8' : '#ffffff'); this.spawnItem(tile, 'arch', 0, 0, z0 - 3.5, 1.3, 1.45, 1.2, 0, col); }
    else if (idx >= 4 && idx % 5 === 2) { const b = biomeAt(zc); col.set(b === 0 ? '#ffdf7a' : b === 1 ? (idx % 2 ? '#40e8ff' : '#ff4fd8') : '#ff7fc4'); this.spawnItem(tile, 'arch', 0, 0, zc, 0.95, 0.9, 1, 0, col); }
  }

  ensure(pz) {
    const c = Math.floor(-pz / TILE), lo = c - 6, hi = c + 9, free = [];
    for (const [i, t] of this.tiles) if (i < lo || i > hi) { this.tiles.delete(i); this.freeItems(t); free.push(t); }
    for (let i = lo; i <= hi; i++) if (!this.tiles.has(i)) { const t = free.pop() || this.pool.pop() || this.makeTile(); this.buildTile(t, i); this.tiles.set(i, t); }
    for (const t of free) this.pool.push(t); // spare (kept in scene, parked far away)
    for (const t of free) { t.terrain.position.y = -999; t.track.position.y = -999; }
    for (const t of this.tiles.values()) { if (t.terrain.position.y < -900) { t.terrain.position.y = 0; t.track.position.y = 0; } }
  }

  atmosphere(pz, dt, camera, time) {
    const cur = this.cur, w = this._w; weights(pz - 70, w);
    const a = this.atmInit ? Math.min(1, dt * 1.6) : 1; this.atmInit = true;
    const tgt = { top: new THREE.Color(0, 0, 0), mid: new THREE.Color(0, 0, 0), bot: new THREE.Color(0, 0, 0), fog: new THREE.Color(0, 0, 0), hemiS: new THREE.Color(0, 0, 0), hemiG: new THREE.Color(0, 0, 0), sun: new THREE.Color(0, 0, 0) };
    let sunI = 0, hemiI = 0, stars = 0, bloom = 0;
    for (let b = 0; b < 3; b++) { const B = BIOMES[b], k = w[b]; if (k <= 0) continue; for (const n in tgt) { tgt[n].r += B[n + 'C'].r * k; tgt[n].g += B[n + 'C'].g * k; tgt[n].b += B[n + 'C'].b * k; } sunI += B.sunI * k; hemiI += B.hemiI * k; stars += B.stars * k; bloom += B.bloom * k; }
    for (const n in tgt) cur[n].lerp(tgt[n], a); cur.sunI += (sunI - cur.sunI) * a; cur.hemiI += (hemiI - cur.hemiI) * a; cur.stars += (stars - cur.stars) * a; cur.bloom += (bloom - cur.bloom) * a;
    this.skyU.uTop.value.copy(cur.top); this.skyU.uMid.value.copy(cur.mid); this.skyU.uBot.value.copy(cur.bot); this.skyU.uSunC.value.copy(cur.sun); this.skyU.uStars.value = cur.stars; this.skyU.uTime.value = time;
    this.scene.fog.color.copy(cur.fog); this.hemi.color.copy(cur.hemiS); this.hemi.groundColor.copy(cur.hemiG); this.hemi.intensity = cur.hemiI; this.sun.color.copy(cur.sun); this.sun.intensity = cur.sunI;
    this.bloom = cur.bloom; this.sky.position.copy(camera.position);
    // slow lazy curve of the road ahead
    U.uBendX.value = Math.sin(time * 0.11) * 0.0004 + Math.sin(time * 0.043 + 1) * 0.0003;
    U.uBendY.value = 0.00052 + Math.sin(time * 0.07) * 0.00005;
  }
}
