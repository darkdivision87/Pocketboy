import * as THREE from 'three';
import { clamp, lerp, sstep, mulberry } from './util.js';
import { slideMat, padMat } from './shaders.js';

export const HW = 3.7;                       // half width of the riding surface
export const profileH = (u) => 0.085 * u * u; // slide cross-section (a gentle U)
const PRE = 22;                              // units of slide before s=0 (start platform)
const DS = 1.5;

const UP = new THREE.Vector3(0, 1, 0);

export class SlidePath {
  constructor(course, daySeed) {
    const rng = mulberry(course.seed * 131 + daySeed * 17 + 5);
    this.L = course.length; const L = this.L;
    const total = L + PRE; const N = Math.floor(total / DS) + 2; this.N = N;
    this.pos = new Float32Array(N * 3); this.T = new Float32Array(N * 3); this.R = new Float32Array(N * 3); this.U = new Float32Array(N * 3);
    this.yaw = new Float32Array(N); this.bank = new Float32Array(N); this.k = new Float32Array(N);
    // yaw-rate keyframes (rad per unit length), blended with cosine easing
    const keys = []; let s = -PRE; let sign = rng() < 0.5 ? -1 : 1;
    while (s < L + 200) { const len = 110 + rng() * 150; sign = rng() < 0.75 ? -sign : sign; const mag = (0.45 + rng() * 0.55) * 0.034 * course.twist; keys.push({ s, v: sign * Math.min(mag, 0.04) }); s += len; }
    const yawRate = (x) => {
      let j = 0; while (j < keys.length - 2 && keys[j + 1].s <= x) j++;
      const a = keys[j], b = keys[j + 1], t = clamp((x - a.s) / (b.s - a.s), 0, 1);
      const w = sstep(18, 80, x) * (1 - sstep(L - 110, L - 40, x));
      return lerp(a.v, b.v, (1 - Math.cos(Math.PI * t)) / 2) * w;
    };
    const ph = rng() * 6.28, base = course.pitch;
    const pitchAt = (x) => {
      let p = -base * sstep(10, 120, x) - 0.045 + 0.05 * Math.sin(x * 0.012 + ph) * sstep(100, 200, x);
      p = lerp(p, 0.36, sstep(L - 78, L - 4, x));
      return p;
    };
    let px = 0, py = 0, pz = 0, psi = 0;
    for (let i = 0; i < N; i++) {
      const sv = -PRE + i * DS, phi = pitchAt(sv), yr = yawRate(sv);
      const cp = Math.cos(phi);
      const tx = Math.sin(psi) * cp, ty = Math.sin(phi), tz = Math.cos(psi) * cp;
      this.pos[i * 3] = px; this.pos[i * 3 + 1] = py; this.pos[i * 3 + 2] = pz;
      this.T[i * 3] = tx; this.T[i * 3 + 1] = ty; this.T[i * 3 + 2] = tz;
      this.yaw[i] = yr; this.k[i] = yr;
      px += tx * DS; py += ty * DS; pz += tz * DS; psi += yr * DS;
    }
    // vertical offset so the slide ends at endY
    const shift = course.endY - this.pos[(N - 1) * 3 + 1] ; for (let i = 0; i < N; i++) this.pos[i * 3 + 1] += shift;
    // frames with banking
    let bs = 0;
    for (let i = 0; i < N; i++) {
      const T = new THREE.Vector3(this.T[i * 3], this.T[i * 3 + 1], this.T[i * 3 + 2]);
      const R0 = new THREE.Vector3().crossVectors(T, UP).normalize();
      const U0 = new THREE.Vector3().crossVectors(R0, T).normalize();
      bs += (clamp(this.yaw[i] * 17, -0.62, 0.62) - bs) * 0.35; this.bank[i] = bs;
      const c = Math.cos(bs), sn = Math.sin(bs);
      const R = R0.clone().multiplyScalar(c).addScaledVector(U0, sn);
      const U = U0.clone().multiplyScalar(c).addScaledVector(R0, -sn);
      this.R.set([R.x, R.y, R.z], i * 3); this.U.set([U.x, U.y, U.z], i * 3);
    }
    this.end = new THREE.Vector3(); this.endT = new THREE.Vector3(); this.at(L, { p: this.end, T: this.endT, R: new THREE.Vector3(), U: new THREE.Vector3() });
    this.tmp = { p: new THREE.Vector3(), T: new THREE.Vector3(), R: new THREE.Vector3(), U: new THREE.Vector3() };
  }
  idx(s) { const f = (s + PRE) / DS; const i = clamp(Math.floor(f), 0, this.N - 2); return [i, clamp(f - i, 0, 1)]; }
  at(s, o) {
    const [i, t] = this.idx(s), a = i * 3, b = a + 3;
    const L = (arr, v) => v.set(lerp(arr[a], arr[b], t), lerp(arr[a + 1], arr[b + 1], t), lerp(arr[a + 2], arr[b + 2], t));
    L(this.pos, o.p); L(this.T, o.T).normalize(); L(this.R, o.R).normalize(); L(this.U, o.U).normalize();
    return o;
  }
  curvature(s) { const [i, t] = this.idx(s); return lerp(this.k[i], this.k[i + 1], t); }
  bankAt(s) { const [i, t] = this.idx(s); return lerp(this.bank[i], this.bank[i + 1], t); }
  // world position on the riding surface
  surf(s, u, lift, out) {
    const o = this.tmp; this.at(s, o);
    const h = profileH(clamp(u, -HW, HW));
    // surface normal tilts with u
    out.copy(o.p).addScaledVector(o.R, u).addScaledVector(o.U, h + lift);
    return out;
  }
}

// ---- cross-section profile (closed loop) used for the tube mesh
function makeProfile() {
  const pts = [];
  const push = (u, h, lat, kind) => pts.push({ u, h, lat, kind });
  for (let k = 0; k <= 24; k++) { const u = -HW + (2 * HW * k) / 24; push(u, profileH(u), u / HW, 0); }
  const hr = profileH(HW);
  push(HW + 0.12, hr + 0.38, 1, 1); push(HW + 0.4, hr + 0.66, 1, 1); push(HW + 0.68, hr + 0.52, 1, 1); push(HW + 0.74, hr + 0.2, 1, 1);
  push(HW + 0.5, hr - 0.4, 1, 2); push(HW * 0.55, profileH(HW * 0.55) - 0.82, 0, 2); push(0, -0.95, 0, 2); push(-HW * 0.55, profileH(HW * 0.55) - 0.82, 0, 2); push(-HW - 0.5, hr - 0.4, -1, 2);
  push(-HW - 0.74, hr + 0.2, -1, 1); push(-HW - 0.68, hr + 0.52, -1, 1); push(-HW - 0.4, hr + 0.66, -1, 1); push(-HW - 0.12, hr + 0.38, -1, 1);
  return pts;
}

export function buildSlideMesh(path, course) {
  const prof = makeProfile(), P = prof.length, N = path.N;
  const pos = new Float32Array(N * P * 3), lat = new Float32Array(N * P), kind = new Float32Array(N * P), aS = new Float32Array(N * P);
  const idx = [];
  for (let i = 0; i < N; i++) {
    const a = i * 3;
    for (let j = 0; j < P; j++) {
      const q = prof[j], v = (i * P + j);
      pos[v * 3] = path.pos[a] + path.R[a] * q.u + path.U[a] * q.h;
      pos[v * 3 + 1] = path.pos[a + 1] + path.R[a + 1] * q.u + path.U[a + 1] * q.h;
      pos[v * 3 + 2] = path.pos[a + 2] + path.R[a + 2] * q.u + path.U[a + 2] * q.h;
      lat[v] = q.lat; kind[v] = q.kind; aS[v] = i * DS;
    }
    if (i < N - 1) for (let j = 0; j < P; j++) {
      const j2 = (j + 1) % P, a0 = i * P + j, b0 = i * P + j2, a1 = (i + 1) * P + j, b1 = (i + 1) * P + j2;
      idx.push(a0, a1, b0, b0, a1, b1);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.BufferAttribute(pos, 3)); g.setAttribute('aLat', new THREE.BufferAttribute(lat, 1));
  g.setAttribute('aKind', new THREE.BufferAttribute(kind, 1)); g.setAttribute('aS', new THREE.BufferAttribute(aS, 1));
  g.setIndex(new THREE.BufferAttribute(new Uint32Array(idx), 1));
  g.computeVertexNormals();
  const mat = slideMat(course.slide.bands, course.slide.rim, course.slide.under, course.slide.glow);
  const mesh = new THREE.Mesh(g, mat); mesh.frustumCulled = false;
  return mesh;
}

// ---- gameplay items laid out along the slide
export function layoutItems(path, course, daySeed) {
  const rng = mulberry(course.seed * 977 + daySeed * 31 + 3);
  const gems = [], bumpers = [], pads = [];
  const v = new THREE.Vector3();
  const gem = (s, u) => { path.surf(s, u, 0.95, v); gems.push({ x: v.x, y: v.y, z: v.z, s, alive: true, t: rng() * 6, fly: 0 }); };
  let s = 52, n = 0;
  const end = path.L - 105;
  while (s < end) {
    const prog = s / path.L, r = rng();
    const diff = Math.min(1, 0.35 + prog * 0.8);
    if (r < 0.26 + 0.22 * diff && s > 90) {                // bumper gate with a gap
      const gap = (rng() * 2 - 1) * 1.9;
      const two = rng() < 0.55 + 0.3 * diff;
      const us = two ? [gap - 2.05, gap + 2.05] : [gap + (rng() < 0.5 ? -1.2 : 1.2)];
      for (const u of us) { const uu = clamp(u, -2.7, 2.7); bumpers.push({ s, u: uu, hit: false }); }
      for (let k = -2; k <= 2; k++) gem(s + k * 3.4, clamp(gap, -2.4, 2.4));
      s += 34;
    } else if (r < 0.5) {                                   // gem line
      const u = (rng() * 2 - 1) * 2.2;
      for (let k = 0; k < 8; k++) gem(s + k * 3.1, u);
      s += 8 * 3.1 + 12;
    } else if (r < 0.74) {                                  // weaving gems
      const amp = 1.4 + rng() * 1.0, ph = rng() * 6.28;
      for (let k = 0; k < 11; k++) gem(s + k * 3.0, clamp(Math.sin(ph + k * 0.62) * amp, -2.6, 2.6));
      s += 11 * 3 + 12;
    } else if (r < 0.9) {                                   // boost pad + arc of gems
      const u = (rng() * 2 - 1) * 2.0; pads.push({ s: s + 4, u, used: false });
      for (let k = 0; k < 6; k++) gem(s + 12 + k * 3.3, clamp(u + Math.sin(k * 0.5) * 0.6, -2.6, 2.6));
      s += 42;
    } else { s += 22; }
    n++;
  }
  // final boost ramp reward
  pads.push({ s: path.L - 96, u: 0, used: false });
  for (let k = 0; k < 9; k++) gem(path.L - 82 + k * 6.5, 0);
  gems.sort((a, b) => a.s - b.s); bumpers.sort((a, b) => a.s - b.s); pads.sort((a, b) => a.s - b.s);
  return { gems, bumpers, pads };
}

// ---- scenery attached to the slide: pillars, arches, start gate
export function buildSlideProps(path, course, group) {
  const meshes = []; const nR = new THREE.Vector3();
  const o = { p: new THREE.Vector3(), T: new THREE.Vector3(), R: new THREE.Vector3(), U: new THREE.Vector3() };
  // pillars
  const pil = [];
  for (let s = 18; s < path.L - 20; s += 40) { path.at(s, o); const top = o.p.y - 1.0; if (top > 4) pil.push({ x: o.p.x, z: o.p.z, top, ux: o.U.x, uz: o.U.z }); }
  const pg = new THREE.CylinderGeometry(1.0, 1.35, 1, 10, 1, true);
  const pm = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.55, metalness: 0.0, flatShading: false });
  const im = new THREE.InstancedMesh(pg, pm, pil.length || 1); im.frustumCulled = false;
  const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), sc = new THREE.Vector3(), ps = new THREE.Vector3();
  const col = new THREE.Color();
  pil.forEach((p, i) => { const h = p.top + 2; ps.set(p.x, p.top - h / 2, p.z); sc.set(1, h, 1); m4.compose(ps, q, sc); im.setMatrixAt(i, m4); col.setHex(course.slide.bands[i % 7]).lerp(new THREE.Color(0xffffff), 0.55); im.setColorAt(i, col); });
  im.count = pil.length; group.add(im); meshes.push(im);
  // pillar collars (thin rings)
  const cg = new THREE.TorusGeometry(1.35, 0.22, 6, 18); cg.rotateX(Math.PI / 2);
  const cm = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.4 });
  const ci = new THREE.InstancedMesh(cg, cm, pil.length * 2 || 1);
  pil.forEach((p, i) => { for (let k = 0; k < 2; k++) { ps.set(p.x, p.top - 2.2 - k * 24, p.z); sc.set(1, 1, 1); m4.compose(ps, q, sc); ci.setMatrixAt(i * 2 + k, m4); col.setHex(course.slide.bands[(i + k * 3) % 7]); ci.setColorAt(i * 2 + k, col); } });
  ci.count = pil.length * 2; group.add(ci); meshes.push(ci);
  path.pillars = pil;
  // glowing arches
  const arcs = [];
  for (let s = 70; s < path.L - 130; s += 58) arcs.push(s);
  const ag = new THREE.TorusGeometry(4.9, 0.17, 6, 28, Math.PI);
  const am = new THREE.MeshBasicMaterial({ color: 0xffffff, toneMapped: true }); am.color.setScalar(1.9);
  const ai = new THREE.InstancedMesh(ag, am, arcs.length || 1);
  const bas = new THREE.Matrix4();
  arcs.forEach((s, i) => { path.at(s, o); bas.makeBasis(nR.copy(o.R).negate(), o.U, o.T); bas.setPosition(o.p.x + o.U.x * 0.15, o.p.y + o.U.y * 0.15, o.p.z + o.U.z * 0.15); ai.setMatrixAt(i, bas); col.setHex(course.slide.bands[i % 7]); ai.setColorAt(i, col); });
  ai.count = arcs.length; group.add(ai); meshes.push(ai);
  // start gate
  path.at(-17, o);
  const gate = new THREE.Group();
  const postG = new THREE.CylinderGeometry(0.28, 0.34, 7.2, 8), postM = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.4 });
  for (const sd of [-1, 1]) { const p = new THREE.Mesh(postG, postM); p.position.set(sd * 5.6, 3.1, 0); gate.add(p); }
  const beam = new THREE.Mesh(new THREE.BoxGeometry(12.2, 0.5, 0.5), postM); beam.position.y = 6.8; gate.add(beam);
  const arch = new THREE.Mesh(new THREE.TorusGeometry(5.6, 0.32, 8, 36, Math.PI), new THREE.MeshStandardMaterial({ color: 0xffd23f, emissive: 0xff9a00, emissiveIntensity: 1.2, roughness: 0.4 }));
  arch.position.y = 6.8; gate.add(arch);
  // banner
  const cv = document.createElement('canvas'); cv.width = 512; cv.height = 128; const c2 = cv.getContext('2d');
  const gr = c2.createLinearGradient(0, 0, 512, 0); gr.addColorStop(0, '#ff5fa2'); gr.addColorStop(0.5, '#ffb11f'); gr.addColorStop(1, '#2fc8ff');
  c2.fillStyle = gr; c2.beginPath(); if (c2.roundRect) c2.roundRect(4, 4, 504, 120, 40); else c2.rect(4, 4, 504, 120); c2.fill();
  c2.font = '900 78px ui-rounded, "SF Pro Rounded", system-ui, sans-serif'; c2.textAlign = 'center'; c2.textBaseline = 'middle'; c2.lineWidth = 12; c2.strokeStyle = '#1b3f9a'; c2.lineJoin = 'round';
  c2.strokeText('SKY SLIDE', 256, 68); c2.fillStyle = '#fff'; c2.fillText('SKY SLIDE', 256, 68);
  const tex = new THREE.CanvasTexture(cv); tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 4;
  const ban = new THREE.Mesh(new THREE.PlaneGeometry(7.6, 1.9), new THREE.MeshBasicMaterial({ map: tex, transparent: true, side: THREE.DoubleSide }));
  ban.position.y = 8.9; ban.rotation.x = 0; gate.add(ban);
  const gm = new THREE.Matrix4().makeBasis(nR.copy(o.R).negate(), o.U, o.T); gm.setPosition(o.p); gate.applyMatrix4(gm);
  group.add(gate); meshes.push(gate);
  // launch ring marker near the ramp end
  path.at(path.L - 22, o);
  const lr = new THREE.Mesh(new THREE.TorusGeometry(5.6, 0.3, 8, 40), new THREE.MeshBasicMaterial({ color: 0xfff0a0 }));
  lr.material.color.setScalar(2.2);
  const lm = new THREE.Matrix4().makeBasis(nR.copy(o.R).negate(), o.U, o.T); lm.setPosition(o.p.x + o.U.x * 2.2, o.p.y + o.U.y * 2.2, o.p.z + o.U.z * 2.2); lr.applyMatrix4(lm); group.add(lr); meshes.push(lr);
  return meshes;
}

export function buildPads(path, items, group) {
  const mat = padMat(); const out = [];
  const geo = new THREE.PlaneGeometry(2.1, 7, 1, 1);
  const o = { p: new THREE.Vector3(), T: new THREE.Vector3(), R: new THREE.Vector3(), U: new THREE.Vector3() };
  const v = new THREE.Vector3();
  for (const p of items.pads) {
    path.at(p.s, o); path.surf(p.s, p.u, 0.07, v);
    const n = new THREE.Vector3().copy(o.U).addScaledVector(o.R, -0.17 * p.u).normalize();
    const x = new THREE.Vector3().crossVectors(n, o.T).normalize();
    const m = new THREE.Mesh(geo, mat); m.matrixAutoUpdate = false;
    // plane: local x across, local y along travel (uv.y increases along +y), normal +z -> basis(x, T, n)
    const b = new THREE.Matrix4().makeBasis(x.clone().negate(), o.T, n); b.setPosition(v); m.matrix.copy(b); m.frustumCulled = false; m.renderOrder = 3;
    group.add(m); out.push(m);
  }
  return { mat, meshes: out };
}
