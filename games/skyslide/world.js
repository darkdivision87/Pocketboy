import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { mulberry, clamp, lerp } from './util.js';
import { skyU, fogU, skyMat, seaMat } from './shaders.js';

const _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _p = new THREE.Vector3(), _s = new THREE.Vector3(), _c = new THREE.Color(), _e = new THREE.Euler();
const Y = new THREE.Vector3(0, 1, 0);

// build a coloured, non-indexed part
function P(geo, hex, px = 0, py = 0, pz = 0, sx = 1, sy = 1, sz = 1, q) {
  let g = geo.index ? geo.toNonIndexed() : geo; g.deleteAttribute('uv');
  _p.set(px, py, pz); _s.set(sx, sy, sz); _m.compose(_p, q || _q.identity(), _s); g.applyMatrix4(_m);
  const c = new THREE.Color(hex), n = g.attributes.position.count, a = new Float32Array(n * 3);
  for (let i = 0; i < n; i++) { a[i * 3] = c.r; a[i * 3 + 1] = c.g; a[i * 3 + 2] = c.b; }
  g.setAttribute('color', new THREE.BufferAttribute(a, 3)); return g;
}
const dirQ = (x, y, z) => new THREE.Quaternion().setFromUnitVectors(Y, new THREE.Vector3(x, y, z).normalize());

function islandGeo(kind, rng) {
  const parts = [];
  const ang = () => rng() * 6.283;
  if (kind === 'palm') {
    parts.push(P(new THREE.CylinderGeometry(0.92, 1.18, 0.55, 10), 0xf5dd9a, 0, 0.02));
    parts.push(P(new THREE.IcosahedronGeometry(0.78, 1), 0x4fd16b, 0, 0.26, 0, 1, 0.5, 1));
    parts.push(P(new THREE.IcosahedronGeometry(0.46, 1), 0x35b85a, -0.38, 0.36, 0.22, 1, 0.6, 1));
    parts.push(P(new THREE.IcosahedronGeometry(0.2, 0), 0x9a8f86, 0.7, 0.2, -0.4, 1, 0.8, 1));
    for (let i = 0; i < 4; i++) {
      const a = ang(), r = 0.1 + rng() * 0.5, x = Math.cos(a) * r, z = Math.sin(a) * r, h = 0.45 + rng() * 0.25;
      const lean = (rng() - 0.5) * 0.35;
      parts.push(P(new THREE.CylinderGeometry(0.026, 0.045, h, 5), 0x9a6a3c, x + lean * 0.5 * h, 0.5 + h / 2 - 0.1, z, 1, 1, 1, dirQ(lean, 1, 0)));
      const cx = x + lean * h, cy = 0.48 + h, cz = z;
      for (let k = 0; k < 7; k++) { const aa = k / 7 * 6.283 + i; const dx = Math.cos(aa), dz = Math.sin(aa); const L = 0.34;
        parts.push(P(new THREE.ConeGeometry(0.075, L, 4), k % 2 ? 0x2fbf5a : 0x3ddc6a, cx + dx * L * 0.42, cy + 0.04 - 0.02, cz + dz * L * 0.42, 1, 1, 0.3, dirQ(dx, 0.1, dz))); }
      parts.push(P(new THREE.SphereGeometry(0.045, 5, 4), 0x8a5a2c, cx, cy - 0.04, cz));
    }
  } else if (kind === 'candy') {
    parts.push(P(new THREE.CylinderGeometry(1.0, 1.06, 0.42, 16), 0xffe2b0, 0, 0.0));
    parts.push(P(new THREE.CylinderGeometry(1.02, 1.02, 0.12, 16), 0xff7fbd, 0, 0.24));
    for (let i = 0; i < 12; i++) { const a = i / 12 * 6.283; parts.push(P(new THREE.SphereGeometry(0.09, 6, 5), 0xff7fbd, Math.cos(a) * 1.0, 0.2, Math.sin(a) * 1.0, 1, 1.6, 1)); }
    parts.push(P(new THREE.CylinderGeometry(0.66, 0.72, 0.34, 14), 0xfff0dc, 0, 0.47));
    parts.push(P(new THREE.CylinderGeometry(0.68, 0.68, 0.1, 14), 0x9ee9ff, 0, 0.66));
    parts.push(P(new THREE.SphereGeometry(0.11, 8, 6), 0xff2f5a, 0.05, 0.78, 0.0));
    const lc = [0xff4f8a, 0xffd23f, 0x4fe0b0, 0xa07aff];
    for (let i = 0; i < 4; i++) {
      const a = ang(), r = 0.55 + rng() * 0.3, x = Math.cos(a) * r, z = Math.sin(a) * r;
      parts.push(P(new THREE.CylinderGeometry(0.02, 0.02, 0.62, 5), 0xffffff, x, 0.55, z));
      const rot = new THREE.Quaternion().setFromEuler(_e.set(Math.PI / 2, a, 0));
      parts.push(P(new THREE.CylinderGeometry(0.2, 0.2, 0.05, 14), lc[i % 4], x, 0.9, z, 1, 1, 1, rot));
      parts.push(P(new THREE.CylinderGeometry(0.11, 0.11, 0.06, 12), 0xffffff, x, 0.9, z, 1, 1, 1, rot));
    }
    for (let i = 0; i < 6; i++) { const a = ang(), r = 0.2 + rng() * 0.7; parts.push(P(new THREE.SphereGeometry(0.1, 8, 5, 0, 6.283, 0, 1.57), lc[(i + 1) % 4], Math.cos(a) * r, 0.68 - (r > 0.7 ? 0.2 : 0), Math.sin(a) * r)); }
  } else if (kind === 'snow') {
    parts.push(P(new THREE.CylinderGeometry(0.95, 1.2, 0.55, 9), 0xbfe6ff, 0, 0.0));
    parts.push(P(new THREE.IcosahedronGeometry(0.85, 1), 0xffffff, 0, 0.22, 0, 1, 0.5, 1));
    for (let i = 0; i < 5; i++) {
      const a = ang(), r = 0.15 + rng() * 0.55, x = Math.cos(a) * r, z = Math.sin(a) * r, sc = 0.8 + rng() * 0.5;
      parts.push(P(new THREE.CylinderGeometry(0.03, 0.04, 0.2, 5), 0x7a5230, x, 0.38, z));
      for (let k = 0; k < 3; k++) {
        const rr = (0.24 - k * 0.055) * sc, hh = 0.3 * sc, y = 0.5 + k * 0.17 * sc;
        parts.push(P(new THREE.ConeGeometry(rr, hh, 7), 0x2a9a78, x, y + hh / 2, z));
        parts.push(P(new THREE.ConeGeometry(rr * 0.72, hh * 0.55, 7), 0xffffff, x, y + hh * 0.62, z));
      }
    }
    // snowman
    parts.push(P(new THREE.SphereGeometry(0.15, 10, 8), 0xffffff, 0.45, 0.46, -0.4)); parts.push(P(new THREE.SphereGeometry(0.1, 10, 8), 0xffffff, 0.45, 0.68, -0.4));
    parts.push(P(new THREE.ConeGeometry(0.025, 0.12, 5), 0xff8a2a, 0.45, 0.68, -0.3, 1, 1, 1, dirQ(0, 0, 1)));
    parts.push(P(new THREE.CylinderGeometry(0.07, 0.07, 0.09, 8), 0x2a2a55, 0.45, 0.8, -0.4));
  } else {
    parts.push(P(new THREE.IcosahedronGeometry(0.85, 0), 0x7a5ad0, 0, 0.2, 0, 1.1, 0.55, 1.1));
    parts.push(P(new THREE.ConeGeometry(0.9, 1.1, 7), 0x3a2a86, 0, -0.55, 0, 1, 1, 1, new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1, 0, 0), Math.PI)));
    parts.push(P(new THREE.IcosahedronGeometry(0.3, 0), 0x5a44b0, 0.7, -0.2, 0.3));
    const cc = [0x59f0ff, 0xff5fc8, 0x9bff6a, 0xffe640];
    for (let i = 0; i < 7; i++) {
      const a = ang(), r = rng() * 0.6, h = 0.35 + rng() * 0.6, t = (rng() - 0.5) * 0.5;
      const col = new THREE.Color(cc[i % 4]).multiplyScalar(1.5);
      parts.push(P(new THREE.OctahedronGeometry(0.14, 0), col.getHex(), Math.cos(a) * r, 0.35 + h * 0.4, Math.sin(a) * r, 1, h / 0.14 * 0.9, 1, dirQ(t, 1, -t)));
    }
  }
  const g = mergeGeometries(parts, false); parts.forEach((p) => p.dispose()); return g;
}

function cloudGeo(rng) {
  const parts = [];
  const n = 8 + Math.floor(rng() * 3);
  for (let i = 0; i < n; i++) {
    const a = rng() * 6.283, d = i === 0 ? 0 : 0.5 + rng() * 0.8, x = Math.cos(a) * d * 1.3, z = Math.sin(a) * d * 0.8;
    const r = i === 0 ? 0.95 : 0.4 + rng() * 0.45 - d * 0.12;
    parts.push(P(new THREE.IcosahedronGeometry(Math.max(0.3, r), 2), 0xffffff, x, r * 0.55 + (i === 0 ? 0.25 : 0), z, 1, 0.8, 1));
  }
  const g = mergeGeometries(parts, false); parts.forEach((p) => p.dispose());
  const pa = g.attributes.position, ca = g.attributes.color;
  for (let i = 0; i < pa.count; i++) { const k = clamp(0.84 + pa.getY(i) * 0.4, 0.8, 1.0); ca.setXYZ(i, k, k, k * 1.03); }
  return g;
}

function radialTex() {
  const c = document.createElement('canvas'); c.width = c.height = 128; const g = c.getContext('2d');
  const gr = g.createRadialGradient(64, 64, 0, 64, 64, 64);
  gr.addColorStop(0, 'rgba(255,255,255,0.55)'); gr.addColorStop(0.42, 'rgba(255,255,255,0.42)'); gr.addColorStop(0.58, 'rgba(255,255,255,0.95)'); gr.addColorStop(0.64, 'rgba(255,255,255,0.45)'); gr.addColorStop(0.82, 'rgba(255,255,255,0.12)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gr; g.fillRect(0, 0, 128, 128);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
export function blobTexture() {
  const c = document.createElement('canvas'); c.width = c.height = 64; const g = c.getContext('2d');
  const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32); gr.addColorStop(0, 'rgba(0,10,40,0.55)'); gr.addColorStop(0.6, 'rgba(0,10,40,0.28)'); gr.addColorStop(1, 'rgba(0,10,40,0)');
  g.fillStyle = gr; g.fillRect(0, 0, 64, 64); const t = new THREE.CanvasTexture(c); return t;
}

function rainbowArcGeo(bands, full) {
  const g = new THREE.RingGeometry(0.84, 1, 72, 7, 0, full ? Math.PI * 2 : Math.PI);
  const n = g.attributes.position.count, a = new Float32Array(n * 3), tc = 73;
  for (let i = 0; i < n; i++) { const j = Math.min(6, Math.floor(i / tc)); const c = new THREE.Color(bands[6 - j]); a[i * 3] = c.r; a[i * 3 + 1] = c.g; a[i * 3 + 2] = c.b; }
  g.setAttribute('color', new THREE.BufferAttribute(a, 3)); return g;
}
export { rainbowArcGeo };

export class World {
  constructor(scene, camera) {
    this.scene = scene; this.camera = camera; this.time = 0;
    scene.fog = new THREE.FogExp2(0xffffff, 0.0013);
    this.sky = new THREE.Mesh(new THREE.SphereGeometry(4000, 40, 24), skyMat()); this.sky.renderOrder = -10; this.sky.frustumCulled = false; scene.add(this.sky);
    this.seaMat = seaMat(); this.sea = new THREE.Mesh(new THREE.PlaneGeometry(16000, 16000).rotateX(-Math.PI / 2), this.seaMat); this.sea.frustumCulled = false; this.sea.renderOrder = -5; scene.add(this.sea);
    this.hemi = new THREE.HemisphereLight(0xffffff, 0x88aaaa, 1); scene.add(this.hemi);
    this.sun = new THREE.DirectionalLight(0xffffff, 2); scene.add(this.sun); scene.add(this.sun.target);
    this.sunDir = skyU.uSunDir.value;
    this.group = new THREE.Group(); scene.add(this.group);        // per-course content
    this.lagoonTex = radialTex();
    this.islands = []; this.clouds = []; this.rainbows = [];
    this.ambient = null; this.planets = null;
    this.landSlots = [];
  }

  clearCourse() {
    this.group.traverse((o) => { if (o.geometry) o.geometry.dispose(); if (o.material && o.material.dispose && !o.material.userData.keep) o.material.dispose(); });
    this.group.clear(); this.islands = []; this.clouds = []; this.rainbows = []; this.ambient = null; this.planets = null; this.lagoon = null;
  }

  setCourse(course, flightDir, seed) {
    this.clearCourse(); this.course = course;
    const sk = course.sky, sea = course.sea;
    skyU.uTop.value.setHex(sk.top); skyU.uMid.value.setHex(sk.mid); skyU.uHor.value.setHex(sk.hor); skyU.uGround.value.setHex(sk.ground);
    skyU.uSunCol.value.setHex(sk.sun); skyU.uStars.value = sk.stars; skyU.uAurora.value = sk.aurora; skyU.uCloud.value = sk.cloudAmt; skyU.uCloudCol.value.setHex(sk.cloud);
    skyU.uNebA.value.setHex(sk.nebA); skyU.uNebB.value.setHex(sk.nebB);
    fogU.uFogColor.value.setHex(sk.hor); fogU.uFogDensity.value = course.fogDensity; this.scene.fog.color.setHex(sk.hor); this.scene.fog.density = course.fogDensity;
    this.seaMat.uniforms.uDeep.value.setHex(sea.deep); this.seaMat.uniforms.uShallow.value.setHex(sea.shallow);
    // sun placed ahead of the flight direction, offset to a side
    const ya = Math.atan2(flightDir.x, flightDir.z) + sk.sunYaw, el = sk.sunElev;
    this.sunDir.set(Math.sin(ya) * Math.cos(el), Math.sin(el), Math.cos(ya) * Math.cos(el)).normalize();
    this.sun.position.copy(this.sunDir).multiplyScalar(200); this.sun.color.setHex(sk.sun); this.sun.intensity = course.sunInt;
    this.hemi.color.setHex(course.hemi[0]); this.hemi.groundColor.setHex(course.hemi[1]); this.hemi.intensity = course.hemi[2];
    const rng = mulberry(seed * 7 + 13);
    // islands
    const kinds = []; for (let i = 0; i < 4; i++) kinds.push(islandGeo(course.deco, rng));
    this.islandMats = new THREE.MeshStandardMaterial({ vertexColors: true, flatShading: true, roughness: 0.8, metalness: 0, emissive: course.deco === 'space' ? 0x1a0a44 : 0x000000 });
    this.islandMeshes = kinds.map((g) => { const m = new THREE.InstancedMesh(g, this.islandMats, 14); m.frustumCulled = false; m.count = 0; this.group.add(m); return m; });
    this.islandCount = 40; this.islands = [];
    for (let i = 0; i < this.islandCount; i++) this.islands.push({ x: 0, z: 0, s: 30, h: 1, rot: 0, grow: 1, v: i % 4, slot: 0 });
    // lagoon discs
    const lg = new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2);
    const lm = new THREE.MeshBasicMaterial({ map: this.lagoonTex, transparent: true, depthWrite: false, opacity: 0.95 });
    this.lagoon = new THREE.InstancedMesh(lg, lm, this.islandCount + 80); this.lagoon.frustumCulled = false; this.lagoon.renderOrder = -4; this.lagoon.count = 0; this.group.add(this.lagoon);
    this.lagoonCol = new THREE.Color(sea.lagoon);
    // clouds
    const cg = [cloudGeo(rng), cloudGeo(rng), cloudGeo(rng)];
    this.cloudMat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 1, metalness: 0, color: course.cloudCol, emissive: course.cloudCol, emissiveIntensity: 0.7, transparent: course.id === 'space', opacity: course.id === 'space' ? 0.5 : 1 });
    this.cloudMeshes = cg.map((g) => { const m = new THREE.InstancedMesh(g, this.cloudMat, 14); m.frustumCulled = false; m.count = 0; this.group.add(m); return m; });
    this.clouds = []; for (let i = 0; i < 30; i++) this.clouds.push({ x: 0, y: 100, z: 0, s: 30, v: i % 3, grow: 1, rot: 0 });
    // rainbows
    this.rainbowGeo = rainbowArcGeo(course.slide.bands, false);
    this.rainbowMat = new THREE.MeshBasicMaterial({ vertexColors: true, transparent: true, opacity: course.id === 'space' ? 0.75 : 0.5, depthWrite: false, side: THREE.DoubleSide });
    this.rainbows = []; for (let i = 0; i < 3; i++) { const m = new THREE.Mesh(this.rainbowGeo, this.rainbowMat); m.renderOrder = -3; this.group.add(m); this.rainbows.push({ mesh: m, x: 0, z: 0, s: 130 }); }
    // ambient floating particles
    this.makeAmbient(course);
    if (course.id === 'space') this.makePlanets();
    this._placed = false;
    this.rng = rng;
  }

  makeAmbient(course) {
    const N = 260, base = new Float32Array(N * 3), seed = new Float32Array(N); const r = mulberry(5);
    for (let i = 0; i < N; i++) { base[i * 3] = r() * 120; base[i * 3 + 1] = r() * 120; base[i * 3 + 2] = r() * 120; seed[i] = r(); }
    const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(base, 3)); g.setAttribute('aSeed', new THREE.BufferAttribute(seed, 1));
    const kind = course.ambient.kind;
    this.ambientU = { uCam: { value: new THREE.Vector3() }, uTime: { value: 0 }, uBox: { value: 120 }, uSize: { value: course.ambient.size }, uScale: { value: 500 }, uMode: { value: kind === 'snow' ? 0 : kind === 'sprinkle' ? 1 : 2 }, uColor: { value: new THREE.Color(course.ambient.color) } };
    const m = new THREE.ShaderMaterial({
      uniforms: this.ambientU, transparent: true, depthWrite: false, blending: kind === 'sprinkle' || kind === 'snow' ? THREE.NormalBlending : THREE.AdditiveBlending,
      vertexShader: `attribute float aSeed; uniform vec3 uCam; uniform float uTime, uBox, uSize, uScale, uMode; uniform vec3 uColor; varying float vA; varying vec3 vC;
        void main(){ vec3 p = position;
          vec3 dr = vec3(sin(uTime*.3+aSeed*6.)*1.2, uMode < 1.5 ? -(1.5+aSeed*2.5) : (0.5+aSeed*1.2), cos(uTime*.27+aSeed*9.)*1.2);
          p += dr * uTime; vec3 rel = mod(p - uCam, uBox) - uBox * 0.5; vec3 wp = uCam + rel; vec4 mv = viewMatrix * vec4(wp, 1.);
          gl_Position = projectionMatrix * mv; float fade = 1. - smoothstep(uBox * 0.3, uBox * 0.5, length(rel));
          vA = fade * (0.55 + 0.45 * sin(uTime * 2. + aSeed * 20.)); gl_PointSize = uSize * uScale * (0.6 + aSeed * 0.9) / max(-mv.z, 0.5);
          vC = uMode > 0.5 && uMode < 1.5 ? 0.55 + 0.45 * cos(6.2832 * (aSeed + vec3(0., .33, .67))) : uColor; }`,
      fragmentShader: `varying float vA; varying vec3 vC; void main(){ float d = length(gl_PointCoord - .5) * 2.; float a = smoothstep(1., .2, d) * vA; if (a < .01) discard; gl_FragColor = vec4(vC * (1.0 + 0.0), a); }`
    });
    this.ambient = new THREE.Points(g, m); this.ambient.frustumCulled = false; this.ambient.renderOrder = 8; this.group.add(this.ambient);
  }

  makePlanets() {
    this.planets = new THREE.Group();
    const mk = (r, c1, c2, ring, dir) => {
      const cv = document.createElement('canvas'); cv.width = 256; cv.height = 128; const g = cv.getContext('2d');
      const gr = g.createLinearGradient(0, 0, 0, 128); gr.addColorStop(0, c1); gr.addColorStop(0.5, c2); gr.addColorStop(1, c1); g.fillStyle = gr; g.fillRect(0, 0, 256, 128);
      for (let i = 0; i < 9; i++) { g.fillStyle = `rgba(255,255,255,${0.05 + Math.random() * 0.1})`; g.fillRect(0, Math.random() * 128, 256, 4 + Math.random() * 9); }
      const t = new THREE.CanvasTexture(cv); t.colorSpace = THREE.SRGBColorSpace;
      const grp = new THREE.Group();
      const m = new THREE.Mesh(new THREE.SphereGeometry(r, 36, 24), new THREE.MeshBasicMaterial({ map: t, fog: false })); grp.add(m);
      if (ring) { const rg = new THREE.Mesh(new THREE.RingGeometry(r * 1.4, r * 2.2, 64), new THREE.MeshBasicMaterial({ color: 0xffd9a0, transparent: true, opacity: 0.55, side: THREE.DoubleSide, fog: false })); rg.rotation.x = Math.PI / 2 - 0.35; rg.rotation.y = 0.2; grp.add(rg); }
      grp.userData.dir = dir; grp.userData.d = 3300; this.planets.add(grp); return grp;
    };
    mk(260, '#ff9ad8', '#a35cff', true, new THREE.Vector3(-0.6, 0.22, 0.75).normalize());
    mk(120, '#8ff0ff', '#3a7bff', false, new THREE.Vector3(0.75, 0.32, 0.55).normalize());
    this.group.add(this.planets);
  }

  // place all decor around a focus point initially
  populate(focus, dir) {
    const rng = this.rng;
    for (const it of this.islands) this.placeIsland(it, focus, dir, true);
    for (const c of this.clouds) this.placeCloud(c, focus, dir, true);
    for (const r of this.rainbows) this.placeRainbow(r, focus, dir, true);
    this.rebuildInstances();
  }
  placeIsland(it, f, d, initial) {
    const r = this.rng; const course = this.course;
    let a, dist;
    if (initial) { a = r() * 6.283; dist = 160 + r() * 1500; } else { a = Math.atan2(d.x, d.z) + (r() - 0.5) * 2.4; dist = 1000 + r() * 800; }
    it.x = f.x + Math.sin(a) * dist; it.z = f.z + Math.cos(a) * dist; it.s = 24 + r() * 44; it.rot = r() * 6.283; it.v = Math.floor(r() * 4);
    it.grow = initial ? 1 : 0; it.dirty = true;
  }
  placeCloud(c, f, d, initial) {
    const r = this.rng; let a, dist;
    if (initial) { a = r() * 6.283; dist = 160 + r() * 1400; } else { a = Math.atan2(d.x, d.z) + (r() - 0.5) * 2.2; dist = 900 + r() * 800; }
    c.x = f.x + Math.sin(a) * dist; c.z = f.z + Math.cos(a) * dist; c.y = clamp(f.y + (r() - 0.6) * 300, 45, 520); c.s = 18 + r() * 44; c.v = Math.floor(r() * 3); c.rot = r() * 6.28; c.grow = initial ? 1 : 0;
  }
  placeRainbow(rb, f, d, initial) {
    const r = this.rng; let a, dist;
    if (initial) { a = r() * 6.283; dist = 300 + r() * 1000; } else { a = Math.atan2(d.x, d.z) + (r() - 0.5) * 1.6; dist = 1000 + r() * 600; }
    rb.x = f.x + Math.sin(a) * dist; rb.z = f.z + Math.cos(a) * dist; rb.s = 110 + r() * 90;
    rb.mesh.position.set(rb.x, -rb.s * 0.08, rb.z); rb.mesh.scale.setScalar(rb.s); rb.mesh.rotation.y = Math.atan2(f.x - rb.x, f.z - rb.z) + (r() - 0.5) * 1.2;
  }
  rebuildInstances() {
    const counts = [0, 0, 0, 0]; let lc = 0;
    for (const it of this.islands) {
      const m = this.islandMeshes[it.v], k = counts[it.v]++;
      const g = it.grow * it.grow * (3 - 2 * it.grow);
      _p.set(it.x, 0, it.z); _q.setFromAxisAngle(Y, it.rot); _s.set(it.s * g, it.s * (0.5 + 0.2 * (it.v % 2)) * g, it.s * g); _m.compose(_p, _q, _s); m.setMatrixAt(k, _m);
      _p.set(it.x, 0.35, it.z); _q.identity(); const ls = it.s * 2.9 * g; _s.set(ls, 1, ls); _m.compose(_p, _q, _s); this.lagoon.setMatrixAt(lc, _m); this.lagoon.setColorAt(lc, this.lagoonCol); lc++;
    }
    this.islandMeshes.forEach((m, i) => { m.count = counts[i]; m.instanceMatrix.needsUpdate = true; });
    this.extraLagoon = lc; this.lagoon.count = lc; this.lagoon.instanceMatrix.needsUpdate = true; if (this.lagoon.instanceColor) this.lagoon.instanceColor.needsUpdate = true;
    const cc = [0, 0, 0];
    for (const c of this.clouds) { const m = this.cloudMeshes[c.v], k = cc[c.v]++; const g = c.grow; _p.set(c.x, c.y, c.z); _q.setFromAxisAngle(Y, c.rot); _s.set(c.s * g, c.s * g * 0.8, c.s * g); _m.compose(_p, _q, _s); m.setMatrixAt(k, _m); }
    this.cloudMeshes.forEach((m, i) => { m.count = cc[i]; m.instanceMatrix.needsUpdate = true; });
  }
  addPillarFoam(pillars) {
    // small foam discs around slide pillars (appended after island discs)
    let lc = this.extraLagoon; const white = new THREE.Color(0xffffff);
    for (const p of pillars) { if (lc >= this.lagoon.instanceMatrix.count) break; _p.set(p.x, 0.4, p.z); _q.identity(); _s.set(9, 1, 9); _m.compose(_p, _q, _s); this.lagoon.setMatrixAt(lc, _m); this.lagoon.setColorAt(lc, white); lc++; }
    this.lagoon.count = lc; this.lagoon.instanceMatrix.needsUpdate = true; this.lagoon.instanceColor.needsUpdate = true;
  }

  islandAt(x, y, z) {
    for (const it of this.islands) { const dx = x - it.x, dz = z - it.z, r = it.s * 0.85; if (dx * dx + dz * dz < r * r && y < it.s * 0.42) return it; }
    return null;
  }

  update(dt, focus, dir, camPos, scaleForPoints, speed) {
    this.time += dt; const t = this.time;
    skyU.uTime.value = t; this.seaMat.uniforms.uTime.value = t;
    this.sky.position.copy(camPos); this.sea.position.set(camPos.x, 0, camPos.z);
    if (this.ambientU) { this.ambientU.uCam.value.copy(camPos); this.ambientU.uTime.value = t; this.ambientU.uScale.value = scaleForPoints; }
    if (this.planets) for (const p of this.planets.children) { p.position.copy(camPos).addScaledVector(p.userData.dir, p.userData.d); p.rotation.y += dt * 0.01; }
    // recycle behind / far away decor
    let dirty = false;
    for (const it of this.islands) {
      const dx = it.x - focus.x, dz = it.z - focus.z, along = dx * dir.x + dz * dir.z, dist2 = dx * dx + dz * dz;
      if (dist2 > 2000 * 2000 || (along < -260 && speed > 20)) { this.placeIsland(it, focus, dir, false); dirty = true; }
      else if (it.grow < 1) { it.grow = Math.min(1, it.grow + dt * 0.8); dirty = true; }
    }
    for (const c of this.clouds) {
      const dx = c.x - focus.x, dz = c.z - focus.z, along = dx * dir.x + dz * dir.z, dist2 = dx * dx + dz * dz;
      if (dist2 > 1900 * 1900 || (along < -260 && speed > 20) || (c.y < focus.y - 320)) { this.placeCloud(c, focus, dir, false); dirty = true; }
      else if (c.grow < 1) { c.grow = Math.min(1, c.grow + dt * 0.6); dirty = true; }
    }
    for (const r of this.rainbows) { const dx = r.x - focus.x, dz = r.z - focus.z; if (dx * dx + dz * dz > 2000 * 2000 || ((dx * dir.x + dz * dir.z) < -300 && speed > 20)) this.placeRainbow(r, focus, dir, false); }
    if (dirty) { const keepFoam = this.pillarFoam; this.rebuildInstances(); if (keepFoam) this.addPillarFoam(keepFoam); }
  }
}
