// Fox Dash: rings (instanced, spinning in the shader), obstacle field (hurdles, gates, trains, ramps, rails), power-up pickups.
import * as THREE from 'three';
import { toonGradient } from './fox.js';
import { bend, part, merged, toonMat, glowMat, canvasTex } from './world.js';

export const STEP = 0.42;
const SPH = new THREE.SphereGeometry(1, 10, 7), CYL = new THREE.CylinderGeometry(1, 1, 1, 10), CONE = new THREE.ConeGeometry(1, 1, 8), BOX = new THREE.BoxGeometry(1, 1, 1);
const PI = Math.PI;

// ---------- rings ----------
export class Coins {
  constructor(scene) {
    this.cap = 560; this.geo = new THREE.TorusGeometry(0.34, 0.1, 8, 20);
    this.mat = bend(new THREE.MeshToonMaterial({ color: '#ffc92e', emissive: '#ff9400', emissiveIntensity: 0.85, gradientMap: toonGradient() }), true);
    this.mesh = new THREE.InstancedMesh(this.geo, this.mat, this.cap); this.mesh.frustumCulled = false;
    this.x = new Float32Array(this.cap); this.y = new Float32Array(this.cap); this.z = new Float32Array(this.cap); this.alive = new Uint8Array(this.cap);
    this.free = []; this.list = []; this.dirty = true;
    this.zero = new THREE.Matrix4().makeScale(0, 0, 0);
    for (let i = 0; i < this.cap; i++) { this.mesh.setMatrixAt(i, this.zero); this.free.push(this.cap - 1 - i); }
    scene.add(this.mesh);
    // coins that are flying towards the player (magnet)
    this.fcap = 80; this.fly = new THREE.InstancedMesh(this.geo, this.mat, this.fcap); this.fly.frustumCulled = false; this.fl = []; this.ffree = [];
    for (let i = 0; i < this.fcap; i++) { this.fly.setMatrixAt(i, this.zero); this.ffree.push(this.fcap - 1 - i); }
    scene.add(this.fly); this.m4 = new THREE.Matrix4(); this.fdirty = false;
  }
  add(x, y, z) {
    if (!this.free.length) return -1; const i = this.free.pop(); this.x[i] = x; this.y[i] = y; this.z[i] = z; this.alive[i] = 1; this.list.push(i);
    this.m4.makeTranslation(x, y, z); this.mesh.setMatrixAt(i, this.m4); this.dirty = true; return i;
  }
  remove(i) {
    if (!this.alive[i]) return; this.alive[i] = 0; this.free.push(i); this.mesh.setMatrixAt(i, this.zero); this.dirty = true;
    const k = this.list.indexOf(i); if (k >= 0) { this.list[k] = this.list[this.list.length - 1]; this.list.pop(); }
  }
  clear() { for (let n = this.list.length - 1; n >= 0; n--) this.remove(this.list[n]); for (const f of this.fl) { this.fly.setMatrixAt(f.slot, this.zero); this.ffree.push(f.slot); } this.fl.length = 0; this.fdirty = true; }
  launch(i, px, py, pz) { // turn a placed ring into a flying one
    if (!this.ffree.length) return; const slot = this.ffree.pop(); this.fl.push({ slot, x: this.x[i], y: this.y[i], z: this.z[i], t: 0 }); this.remove(i);
  }
  flush() { if (this.dirty) { this.mesh.instanceMatrix.needsUpdate = true; this.dirty = false; } if (this.fdirty) { this.fly.instanceMatrix.needsUpdate = true; this.fdirty = false; } }
}

// ---------- shadow decal ----------
let shadowMat, shadowGeo;
export function makeShadow() {
  if (!shadowMat) {
    const t = canvasTex(64, 64, (g) => { const gr = g.createRadialGradient(32, 32, 2, 32, 32, 30); gr.addColorStop(0, 'rgba(0,0,0,0.55)'); gr.addColorStop(0.6, 'rgba(0,0,0,0.25)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, 64, 64); });
    shadowMat = bend(new THREE.MeshBasicMaterial({ map: t, transparent: true, depthWrite: false, fog: false })); shadowMat.polygonOffset = true; shadowMat.polygonOffsetFactor = -2;
    shadowGeo = new THREE.PlaneGeometry(1, 1); shadowGeo.rotateX(-PI / 2);
  }
  const m = new THREE.Mesh(shadowGeo, shadowMat); m.renderOrder = 1; m.frustumCulled = false; return m;
}

// ---------- obstacles ----------
const DEFS = {
  low: { len: 0.9, top: 0.9, bot: 0 }, high: { len: 0.8, top: 2.4, bot: 0.9 }, block: { len: 6, top: 2.6, bot: 0 },
  plat: { len: 12, top: 1.8, bot: 0 }, ramp: { len: 7, top: 1.8, bot: 0 }, rail: { len: 18, top: 1.39, bot: 1.2 },
};
export const OB = DEFS;
const quad = (arr, a, b, c, d, out) => { // pushes two triangles with the normal facing `out`
  const ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2], vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
  const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
  if (nx * out[0] + ny * out[1] + nz * out[2] < 0) { arr.push(...a, ...c, ...b, ...a, ...d, ...c); } else arr.push(...a, ...b, ...c, ...a, ...c, ...d);
};
function rampGeo(c1, c2, side) {
  const w = 1.9, L = 7, H = 1.8, n = 7, P = [], C = [];
  const col = new THREE.Color();
  const push = (tri, c) => { col.set(c); for (let i = 0; i < tri.length / 3; i++) C.push(col.r, col.g, col.b); P.push(...tri); };
  for (let i = 0; i < n; i++) {
    const u0 = i / n, u1 = (i + 1) / n, y0 = H * u0, y1 = H * u1, z0 = L / 2 - u0 * L, z1 = L / 2 - u1 * L; let t = [];
    quad(t, [-w / 2, y0, z0], [w / 2, y0, z0], [w / 2, y1, z1], [-w / 2, y1, z1], [0, 1, 0]); push(t, i % 2 ? c1 : c2);
    t = []; quad(t, [-w / 2, 0, z0], [-w / 2, 0, z1], [-w / 2, y1, z1], [-w / 2, y0, z0], [-1, 0, 0]); push(t, side);
    t = []; quad(t, [w / 2, 0, z0], [w / 2, 0, z1], [w / 2, y1, z1], [w / 2, y0, z0], [1, 0, 0]); push(t, side);
  }
  const t = []; quad(t, [-w / 2, 0, -L / 2], [w / 2, 0, -L / 2], [w / 2, H, -L / 2], [-w / 2, H, -L / 2], [0, 0, -1]); push(t, side);
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(P, 3)); g.setAttribute('color', new THREE.Float32BufferAttribute(C, 3)); g.computeVertexNormals(); return g;
}
function build(type, b) {
  const P = [], G = []; const X = [-1, 1];
  if (type === 'low') {
    if (b === 0) { P.push(part(CYL, '#9a6238', { p: [0, 0.52, 0], s: [0.34, 2.0, 0.34], r: [0, 0, PI / 2] })); for (const s of X) { P.push(part(CYL, '#e0bd86', { p: [s * 1.0, 0.52, 0], s: [0.28, 0.05, 0.28], r: [0, 0, PI / 2] })); P.push(part(CYL, '#7a4a28', { p: [s * 0.7, 0.17, 0], s: [0.3, 0.34, 0.3] })); } P.push(part(SPH, '#4cc04a', { p: [0.2, 0.86, 0.1], s: [0.3, 0.12, 0.2] })); }
    if (b === 1) { for (let i = 0; i < 5; i++) P.push(part(BOX, i % 2 ? '#ffd23f' : '#2a2458', { p: [-0.8 + i * 0.4, 0.62, 0], s: [0.4, 0.5, 0.34] })); for (const s of X) P.push(part(BOX, '#2a2458', { p: [s * 0.8, 0.2, 0], s: [0.12, 0.4, 0.4] })); G.push(part(BOX, '#ff5d3a', { p: [0, 0.92, 0], s: [1.9, 0.07, 0.1], k: 2.6 })); }
    if (b === 2) { for (let i = 0; i < 8; i++) P.push(part(CYL, i % 2 ? '#ff5fa8' : '#ffffff', { p: [-0.9 + (i + 0.5) * 0.225, 0.58, 0], s: [0.34, 0.23, 0.34], r: [0, 0, PI / 2] })); for (const s of X) P.push(part(SPH, '#7a5cff', { p: [s * 0.9, 0.32, 0], s: [0.3, 0.4, 0.3] })); }
  } else if (type === 'high') {
    const c = [['#8a5a34', '#c8935a'], ['#2a2458', '#3a3078'], ['#ff7ab8', '#fff0f6']][b];
    for (const s of X) P.push(part(BOX, c[0], { p: [s * 1.0, 1.2, 0], s: [0.22, 2.4, 0.3] }));
    P.push(part(BOX, c[1], { p: [0, 1.65, 0], s: [2.0, 1.5, 0.34] })); P.push(part(BOX, c[0], { p: [0, 0.98, 0.0], s: [2.05, 0.14, 0.4] }));
    for (let i = 0; i < 6; i++) P.push(part(BOX, i % 2 ? '#ffd23f' : '#2a2438', { p: [-0.85 + i * 0.34, 0.98, 0.2], s: [0.17, 0.12, 0.05] }));
    const ac = b === 1 ? '#40e8ff' : '#ffffff'; (b === 1 ? G : P).push(part(CONE, ac, { p: [0, 1.65, 0.19], s: [0.55, 0.7, 0.05], r: [PI, 0, 0], k: b === 1 ? 2.2 : 1 }));
    (b === 1 ? G : P).push(part(BOX, b === 1 ? '#ff3fd0' : '#ff5a4a', { p: [0, 2.2, 0.19], s: [1.7, 0.1, 0.05], k: b === 1 ? 2.2 : 1 }));
  } else if (type === 'block') {
    if (b === 0) { P.push(part(BOX, '#c48a52', { p: [0, 0.95, 0], s: [1.9, 1.1, 6] })); P.push(part(CYL, '#fff6e0', { p: [0, 1.65, 0], s: [0.95, 5.8, 0.95], r: [PI / 2, 0, 0] })); P.push(part(BOX, '#8a5a34', { p: [0, 0.4, 0], s: [1.8, 0.3, 5.8] })); for (const s of X) for (const z of [-1.8, 1.8]) P.push(part(CYL, '#5a3a22', { p: [s * 0.98, 0.5, z], s: [0.5, 0.18, 0.5], r: [0, 0, PI / 2] })); for (const z of [-2.2, -0.7, 0.8, 2.3]) P.push(part(BOX, '#e8d2a4', { p: [0, 1.65, z], s: [1.95, 0.07, 0.07] })); }
    if (b === 1) { P.push(part(BOX, '#3e6bff', { p: [0, 1.3, 0], s: [1.9, 2.2, 6] })); P.push(part(BOX, '#c9d4e0', { p: [0, 2.48, 0], s: [1.8, 0.24, 5.8] })); P.push(part(BOX, '#232a52', { p: [0, 0.3, 0], s: [1.95, 0.5, 5.9] })); for (const s of X) for (let i = 0; i < 4; i++) G.push(part(BOX, '#ffe9a8', { p: [s * 0.96, 1.7, -2.1 + i * 1.4], s: [0.04, 0.7, 0.9], k: 2 })); for (const s of X) G.push(part(BOX, '#ff3fd0', { p: [s * 0.96, 1.0, 0], s: [0.04, 0.12, 5.8], k: 2 })); for (const z of [-3.02, 3.02]) for (const s of X) G.push(part(BOX, '#ffffff', { p: [s * 0.5, 1.0, z], s: [0.3, 0.2, 0.04], k: 3 })); }
    if (b === 2) { P.push(part(BOX, '#b86f3a', { p: [0, 1.05, 0], s: [1.9, 2.1, 6] })); P.push(part(BOX, '#ffffff', { p: [0, 2.22, 0], s: [2.05, 0.4, 6.1] })); const cs = ['#ff4d6d', '#ffd23f', '#3fb7ff', '#7a5cff', '#2fd6b0']; for (let i = 0; i < 8; i++) P.push(part(SPH, cs[i % 5], { p: [(i % 2 ? 0.45 : -0.45), 2.55, -2.6 + i * 0.75], s: [0.26, 0.26, 0.26] })); for (const s of X) for (let i = 0; i < 3; i++) P.push(part(BOX, '#ffe9a8', { p: [s * 0.96, 1.2, -1.8 + i * 1.8], s: [0.04, 0.7, 0.8] })); for (let i = 0; i < 5; i++) P.push(part(SPH, '#ff9ec7', { p: [(i - 2) * 0.4, 0.4, 3.0], s: [0.15, 0.15, 0.1] })); }
  } else if (type === 'plat') {
    const c = [['#d9a85a', '#f0c878', '#b88a40'], ['#ff7a3a', '#c9d4e0', '#e0551f'], ['#7a4a2c', '#ffffff', '#5a3220']][b];
    P.push(part(BOX, c[0], { p: [0, 0.9, 0], s: [1.9, 1.8, 12] })); P.push(part(BOX, c[1], { p: [0, 1.76, 0], s: [1.96, 0.1, 12.05] }));
    for (let i = 0; i < 12; i++) for (const s of X) P.push(part(BOX, c[2], { p: [s * 0.96, 0.9, -5.5 + i], s: [0.04, 1.7, 0.1] }));
    if (b === 2) for (let i = 0; i < 10; i++) P.push(part(SPH, ['#ff9ec7', '#9fe8d4', '#ffd23f'][i % 3], { p: [s2(i) * 0.7, 1.82, -5.2 + i * 1.15], s: [0.2, 0.16, 0.2] }));
    if (b === 1) for (let i = 0; i < 12; i += 2) G.push(part(BOX, '#35e6ff', { p: [0, 1.82, -5.5 + i], s: [1.7, 0.03, 0.1], k: 2 }));
  } else if (type === 'ramp') {
    const c = [['#d9a85a', '#c28a3e', '#8a5a34'], ['#2a2458', '#35e6ff', '#1c1650'], ['#ff8ac4', '#ffffff', '#c25a9a']][b];
    return { geo: rampGeo(c[0], c[1], c[2]), glow: null };
  } else if (type === 'rail') {
    P.push(part(CYL, '#d8e2f0', { p: [0, 1.3, 0], s: [0.09, 18, 0.09], r: [PI / 2, 0, 0] }));
    for (const z of [-8.6, 0, 8.6]) { P.push(part(CYL, '#8a96ac', { p: [0, 0.65, z], s: [0.07, 1.3, 0.07] })); P.push(part(BOX, '#6a768c', { p: [0, 0.04, z], s: [0.5, 0.08, 0.5] })); }
    const gc = ['#ffd75a', '#ff3fd0', '#ff4fa8'][b]; for (let i = -4; i <= 4; i++) G.push(part(CYL, gc, { p: [0, 1.3, i * 2], s: [0.12, 0.12, 0.12], r: [PI / 2, 0, 0], k: 2.0 }));
  }
  return { geo: merged(P), glow: G.length ? merged(G, false) : null };
}
function s2(i) { return i % 2 ? 1 : -1; }

let obMat, obGlow;
export class ObstacleField {
  constructor(scene) { this.scene = scene; this.list = []; this.pool = {}; this.geos = {}; obMat = obMat || toonMat({ vertexColors: true }); obGlow = obGlow || glowMat(); }
  acquire(type, b) {
    const key = type + b; const p = this.pool[key] || (this.pool[key] = []);
    let g = p.find((m) => !m.visible); if (g) { g.visible = true; return g; }
    if (!this.geos[key]) this.geos[key] = build(type, b); const geo = this.geos[key];
    g = new THREE.Group(); g.userData.key = key; g.add(new THREE.Mesh(geo.geo, obMat)); if (geo.glow) g.add(new THREE.Mesh(geo.glow, obGlow));
    const sh = makeShadow(); const d = DEFS[type]; sh.scale.set(2.3, 1, type === 'low' || type === 'high' ? 1.6 : d.len + 1.2); sh.position.y = 0.02; if (type !== 'ramp' && type !== 'rail') g.add(sh);
    for (const c of g.children) c.frustumCulled = false;
    this.scene.add(g); p.push(g); return g;
  }
  spawn(type, x, z, b) {
    const d = DEFS[type], mesh = this.acquire(type, b); mesh.position.set(x, 0, z);
    const o = { type, x, z, zMin: z - d.len / 2, zMax: z + d.len / 2, top: d.top, bot: d.bot, len: d.len, mesh, hit: false };
    this.list.push(o); return o;
  }
  release(o) { o.mesh.visible = false; }
  recycle(zLimit) { for (let i = this.list.length - 1; i >= 0; i--) { const o = this.list[i]; if (o.zMin > zLimit) { this.release(o); this.list[i] = this.list[this.list.length - 1]; this.list.pop(); } } }
  clear() { for (const o of this.list) this.release(o); this.list.length = 0; }
  floorAt(px, pz, feet) {
    let f = 0;
    for (const o of this.list) {
      if (o.hit || o.type === 'high' || o.type === 'rail') continue; if (Math.abs(px - o.x) > 1.0 || pz > o.zMax || pz < o.zMin) continue;
      const top = o.type === 'ramp' ? 1.8 * (o.zMax - pz) / o.len : o.top;
      if (top <= feet + STEP && top > f) f = top;
    }
    return f;
  }
  crash(px, z0, z1, feet, h) { // z0/z1: previous and current player z
    const lo = Math.min(z0, z1) - 0.4, hi = Math.max(z0, z1) + 0.4;
    for (const o of this.list) {
      if (o.hit || o.type === 'ramp' || o.type === 'rail') continue; if (Math.abs(px - o.x) > 1.18) continue; if (lo > o.zMax || hi < o.zMin) continue;
      if (o.type === 'high') { if (feet < o.top && feet + h > o.bot) return o; continue; }
      if (feet < o.top - STEP && feet + h > o.bot) return o;
    }
    return null;
  }
  railAt(px, pz) { for (const o of this.list) if (o.type === 'rail' && !o.hit && Math.abs(px - o.x) < 0.85 && pz < o.zMax - 0.3 && pz > o.zMin + 0.3) return o; return null; }
}

// ---------- power-ups ----------
export function makePowerup(kind) {
  const g = new THREE.Group(); const gm = (c, k = 1) => new THREE.MeshBasicMaterial({ color: new THREE.Color(c).multiplyScalar(k) });
  const tm = (c, e) => new THREE.MeshToonMaterial({ color: c, emissive: e, emissiveIntensity: 0.6, gradientMap: toonGradient() });
  const halo = new THREE.Mesh(new THREE.SphereGeometry(0.72, 16, 12), new THREE.MeshBasicMaterial({ color: kind === 'magnet' ? '#ff5a6a' : kind === 'shield' ? '#5ad0ff' : '#ffe14a', transparent: true, opacity: 0.22, depthWrite: false, blending: THREE.AdditiveBlending }));
  g.add(halo);
  if (kind === 'magnet') {
    const arc = new THREE.Mesh(new THREE.TorusGeometry(0.3, 0.11, 10, 18, PI), tm('#ff3b4a', '#a01020')); arc.position.y = 0.05; g.add(arc);
    for (const s of [-1, 1]) { const l = new THREE.Mesh(new THREE.CylinderGeometry(0.11, 0.11, 0.3, 10), tm('#ff3b4a', '#a01020')); l.position.set(s * 0.3, -0.1, 0); g.add(l); const t = new THREE.Mesh(new THREE.CylinderGeometry(0.115, 0.115, 0.12, 10), tm('#e8eef5', '#555')); t.position.set(s * 0.3, -0.3, 0); g.add(t); }
  } else if (kind === 'shield') {
    const s = new THREE.Mesh(new THREE.IcosahedronGeometry(0.42, 1), new THREE.MeshToonMaterial({ color: '#58c8ff', emissive: '#1a88d8', emissiveIntensity: 0.8, gradientMap: toonGradient(), transparent: true, opacity: 0.85 })); g.add(s);
    const st = new THREE.Mesh(new THREE.OctahedronGeometry(0.2, 0), gm('#ffffff', 1.6)); g.add(st); g.userData.spin = st;
  } else {
    const sh = new THREE.Shape(); const pts = [[0.12, 0.5], [-0.28, -0.06], [-0.02, -0.06], [-0.16, -0.52], [0.3, 0.1], [0.04, 0.1], [0.24, 0.5]]; sh.moveTo(pts[0][0], pts[0][1]); for (let i = 1; i < pts.length; i++) sh.lineTo(pts[i][0], pts[i][1]);
    const geo = new THREE.ExtrudeGeometry(sh, { depth: 0.16, bevelEnabled: true, bevelSize: 0.03, bevelThickness: 0.03, bevelSegments: 1 }); geo.translate(0, 0, -0.08);
    g.add(new THREE.Mesh(geo, gm('#ffe14a', 1.8)));
  }
  g.userData.halo = halo; g.userData.kind = kind; return g;
}
