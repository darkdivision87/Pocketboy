import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { TILES, SETS, AVATARS } from './data.js';
import { glyphCanvas, priceTagCanvas, labelCanvas, makeTexture } from './icons.js';

const TAU = Math.PI * 2;
export const easeOutBack = (u) => { const c1 = 1.9, c3 = c1 + 1; return 1 + c3 * Math.pow(u - 1, 3) + c1 * Math.pow(u - 1, 2); };
export const easeOutCubic = (u) => 1 - Math.pow(1 - u, 3);
export const easeInOut = (u) => (u < 0.5 ? 2 * u * u : 1 - Math.pow(-2 * u + 2, 2) / 2);
export const lin = (u) => u;

// ---------- tiny tween engine (time-scalable and pausable) ----------
export const T = {
  list: [], speed: 1, paused: false,
  add(dur, fn, ease = lin) { return new Promise((res) => T.list.push({ t: 0, dur: Math.max(dur, 1e-4), fn, ease, res })); },
  wait(s) { return T.add(s, () => {}); },
  update(dt) {
    if (T.paused) return; dt *= T.speed; const L = T.list;
    for (let i = 0; i < L.length; i++) { const a = L[i]; a.t += dt; const u = Math.min(1, a.t / a.dur); a.fn(a.ease(u), u); if (u >= 1) { L.splice(i, 1); i--; a.res(); } }
  },
};

const GRASS_TOP = 0.2, SLAB_H = 0.28;
const stdCache = new Map();
function std(color, rough = 0.62, metal = 0, extra = {}) {
  const k = color + '|' + rough + '|' + metal + '|' + (extra.emissive || '') + (extra.ei || '');
  if (!extra.map && stdCache.has(k)) return stdCache.get(k);
  const m = new THREE.MeshStandardMaterial({ color, roughness: rough, metalness: metal, ...extra });
  if (!extra.map) stdCache.set(k, m); return m;
}
function mk(geo, mat, x = 0, y = 0, z = 0, parent) { const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.castShadow = true; m.receiveShadow = true; if (parent) parent.add(m); return m; }
const G = {
  box: new THREE.BoxGeometry(1, 1, 1), cyl: new THREE.CylinderGeometry(1, 1, 1, 24), cone4: new THREE.ConeGeometry(1, 1, 4), cone: new THREE.ConeGeometry(1, 1, 20),
  sph: new THREE.SphereGeometry(1, 24, 16), ico: new THREE.IcosahedronGeometry(1, 1),
};
function B(parent, w, h, d, mat, x, y, z) { const m = mk(G.box, mat, x, y, z, parent); m.scale.set(w, h, d); return m; }
function C(parent, r, h, mat, x, y, z) { const m = mk(G.cyl, mat, x, y, z, parent); m.scale.set(r, h, r); return m; }
function S(parent, r, mat, x, y, z, sy = 1) { const m = mk(G.sph, mat, x, y, z, parent); m.scale.set(r, r * sy, r); return m; }
function spriteOf(cv, w, h, x, y, z, parent) { const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: makeTexture(THREE, cv), transparent: true, depthWrite: false })); sp.scale.set(w, h, 1); sp.position.set(x, y, z); if (parent) parent.add(sp); return sp; }
const lighten = (hex, a) => new THREE.Color(hex).lerp(new THREE.Color(0xffffff), a);
const darken = (hex, a) => new THREE.Color(hex).lerp(new THREE.Color(0x201a30), a);


// Merge many small static meshes (by material) into few draw calls. Positions are baked relative to `root`.
function mergeMeshes(root, meshes) {
  if (!meshes.length) return; root.updateMatrixWorld(true); const inv = new THREE.Matrix4().copy(root.matrixWorld).invert(); const buckets = new Map();
  for (const m of meshes) {
    m.updateWorldMatrix(true, false); let g = m.geometry.index ? m.geometry.toNonIndexed() : m.geometry.clone(); g.applyMatrix4(inv.clone().multiply(m.matrixWorld));
    for (const k of Object.keys(g.attributes)) if (k !== 'position' && k !== 'normal' && k !== 'uv') g.deleteAttribute(k);
    if (!g.attributes.uv) g.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(g.attributes.position.count * 2), 2));
    if (!buckets.has(m.material)) buckets.set(m.material, []); buckets.get(m.material).push(g); m.parent.remove(m);
  }
  for (const [mat, geos] of buckets) { const mm = new THREE.Mesh(mergeGeometries(geos), mat); mm.castShadow = true; mm.receiveShadow = true; root.add(mm); geos.forEach((g) => g.dispose()); }
}
function collectMeshes(o, out = []) { o.traverse((c) => { if (c.isMesh && !c.userData.keep) out.push(c); }); return out; }
function mergeStatic(g) {
  const loose = [];
  for (const c of [...g.children]) { if (c.userData.keep || c.isSprite) continue; if (c.isMesh) loose.push(c); else if (c.isGroup) mergeMeshes(c, collectMeshes(c)); }
  mergeMeshes(g, loose);
}

function windowTexture(kind) {
  const cv = document.createElement('canvas'); cv.width = 128; cv.height = 128; const c = cv.getContext('2d');
  if (kind === 'apt') {
    c.fillStyle = '#ffffff'; c.fillRect(0, 0, 128, 128);
    for (let y = 0; y < 2; y++) for (let x = 0; x < 2; x++) { const px = 12 + x * 60, py = 10 + y * 62; c.fillStyle = '#9ad4ff'; c.beginPath(); c.roundRect(px, py, 44, 46, 8); c.fill(); c.fillStyle = 'rgba(255,255,255,.55)'; c.beginPath(); c.roundRect(px + 4, py + 4, 14, 38, 5); c.fill(); c.strokeStyle = '#ffffff'; c.lineWidth = 3; c.strokeRect(px + 22, py, 0, 46); c.fillStyle = '#e8a860'; c.fillRect(px - 4, py + 44, 52, 6); }
  } else {
    c.fillStyle = '#25356b'; c.fillRect(0, 0, 128, 128);
    for (let y = 0; y < 8; y++) for (let x = 0; x < 4; x++) { const lit = ((x * 7 + y * 13) % 5) < 3; c.fillStyle = lit ? '#ffe9a0' : '#5a78c8'; c.fillRect(6 + x * 31, 5 + y * 15.5, 22, 10); }
  }
  const t = makeTexture(THREE, cv, { repeat: [1, 1] }); t.wrapS = t.wrapT = THREE.RepeatWrapping; return t;
}

// tilt-shift
const TiltShader = {
  uniforms: { tDiffuse: { value: null }, dir: { value: new THREE.Vector2(1, 0) }, res: { value: new THREE.Vector2(1, 1) }, focus: { value: 0.52 }, band: { value: 0.2 }, amount: { value: 1 } },
  vertexShader: 'varying vec2 vUv; void main(){ vUv=uv; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0); }',
  fragmentShader: `uniform sampler2D tDiffuse; uniform vec2 dir; uniform vec2 res; uniform float focus; uniform float band; uniform float amount; varying vec2 vUv;
  void main(){ float d=max(0.0,abs(vUv.y-focus)-band); float r=d*amount*3.5; vec4 s=vec4(0.0); float w=0.0;
    for(int i=-4;i<=4;i++){ float f=float(i); float wt=exp(-f*f/9.0); s+=texture2D(tDiffuse,vUv+dir*f*r/res)*wt; w+=wt; } gl_FragColor=s/w; }`,
};

// ---------- point particle pool (sparkles / dust) ----------
class PointPool {
  constructor(scene, N, additive, tex) {
    this.N = N; this.pos = new Float32Array(N * 3); this.size = new Float32Array(N); this.alpha = new Float32Array(N); this.col = new Float32Array(N * 3);
    this.vel = new Float32Array(N * 3); this.life = new Float32Array(N); this.max = new Float32Array(N); this.grow = new Float32Array(N); this.s0 = new Float32Array(N); this.grav = new Float32Array(N); this.next = 0;
    const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3)); g.setAttribute('aSize', new THREE.BufferAttribute(this.size, 1)); g.setAttribute('aAlpha', new THREE.BufferAttribute(this.alpha, 1)); g.setAttribute('color', new THREE.BufferAttribute(this.col, 3));
    this.geo = g;
    this.mat = new THREE.ShaderMaterial({ transparent: true, depthWrite: false, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending, uniforms: { scale: { value: 600 } },
      vertexShader: 'attribute float aSize; attribute float aAlpha; varying float vA; varying vec3 vC; uniform float scale; void main(){ vA=aAlpha; vC=color; vec4 mv=modelViewMatrix*vec4(position,1.0); gl_PointSize=aSize*scale/-mv.z; gl_Position=projectionMatrix*mv; }',
      fragmentShader: 'varying float vA; varying vec3 vC; void main(){ vec2 p=gl_PointCoord-0.5; float d=length(p); float a=smoothstep(0.5,0.0,d); gl_FragColor=vec4(vC, a*vA); }', vertexColors: true });
    this.pts = new THREE.Points(g, this.mat); this.pts.frustumCulled = false; scene.add(this.pts);
  }
  emit(x, y, z, vx, vy, vz, size, life, color, grow = 0, grav = 0) {
    const i = this.next; this.next = (this.next + 1) % this.N; const c = new THREE.Color(color);
    this.pos[i * 3] = x; this.pos[i * 3 + 1] = y; this.pos[i * 3 + 2] = z; this.vel[i * 3] = vx; this.vel[i * 3 + 1] = vy; this.vel[i * 3 + 2] = vz;
    this.s0[i] = size; this.size[i] = size; this.life[i] = life; this.max[i] = life; this.grow[i] = grow; this.grav[i] = grav; this.col[i * 3] = c.r; this.col[i * 3 + 1] = c.g; this.col[i * 3 + 2] = c.b; this.alpha[i] = 1;
  }
  update(dt) {
    let any = false;
    for (let i = 0; i < this.N; i++) {
      if (this.life[i] <= 0) { if (this.alpha[i] !== 0) { this.alpha[i] = 0; any = true; } continue; }
      any = true; this.life[i] -= dt; const u = Math.max(0, this.life[i] / this.max[i]);
      this.vel[i * 3 + 1] += this.grav[i] * dt; this.pos[i * 3] += this.vel[i * 3] * dt; this.pos[i * 3 + 1] += this.vel[i * 3 + 1] * dt; this.pos[i * 3 + 2] += this.vel[i * 3 + 2] * dt;
      this.alpha[i] = Math.min(1, u * 2.2); this.size[i] = this.s0[i] * (1 + this.grow[i] * (1 - u));
    }
    if (any) { this.geo.attributes.position.needsUpdate = true; this.geo.attributes.aSize.needsUpdate = true; this.geo.attributes.aAlpha.needsUpdate = true; this.geo.attributes.color.needsUpdate = true; }
  }
}

export function yawForTile(i) { const s = Math.floor(i / 10), k = i % 10; return k === 0 ? -(s - 0.5) * (Math.PI / 2) : -s * (Math.PI / 2); }
const SIDE_ROT = [0, -Math.PI / 2, Math.PI, Math.PI / 2];

export class World {
  constructor(canvas) {
    this.canvas = canvas; this.time = 0; this.lite = new URLSearchParams(location.search).has('lite');
    const r = (this.renderer = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance' }));
    r.shadowMap.enabled = true; r.shadowMap.type = THREE.PCFSoftShadowMap; r.toneMapping = THREE.ACESFilmicToneMapping; r.toneMappingExposure = 1.05; r.outputColorSpace = THREE.SRGBColorSpace;
    this.scene = new THREE.Scene(); this.scene.fog = new THREE.Fog(0xcdeeff, 70, 190);
    const pm = new THREE.PMREMGenerator(r); this.scene.environment = pm.fromScene(new RoomEnvironment(), 0.04).texture; this.scene.environmentIntensity = 0.55;
    this.camera = new THREE.PerspectiveCamera(32, 1, 0.5, 600);
    this.view = { target: new THREE.Vector3(), goal: new THREE.Vector3(), yaw: 0.6, tYaw: 0.6, mode: 'orbit', follow: null, dist: 40, pitch: 1.1, zoomOut: false };
    this._v = new THREE.Vector3(); this._q = new THREE.Quaternion();
    this.tiles = []; this.tokens = []; this.pickables = []; this.updaters = [];
    this._lights(); this._sky(); this._island(); this._plaza(); this._buildTiles(); this._fx(); this._dice();
    this._post();
    this.resize();
  }

  _lights() {
    const s = this.scene;
    s.add(new THREE.HemisphereLight(0xcfeaff, 0xffe8c8, 0.95));
    const d = (this.sun = new THREE.DirectionalLight(0xfff0d6, 2.2)); d.position.set(-14, 26, 16); d.castShadow = true;
    d.shadow.mapSize.set(this.lite ? 1024 : 2048, this.lite ? 1024 : 2048); const sc = d.shadow.camera; sc.left = -19; sc.right = 19; sc.top = 19; sc.bottom = -19; sc.near = 5; sc.far = 70; d.shadow.bias = -0.0004; d.shadow.normalBias = 0.03; d.shadow.radius = 3;
    s.add(d); s.add(d.target);
  }

  _sky() {
    const mat = new THREE.ShaderMaterial({ side: THREE.BackSide, depthWrite: false, fog: false,
      vertexShader: 'varying vec3 vP; void main(){ vP=position; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0); }',
      fragmentShader: 'varying vec3 vP; void main(){ float h=normalize(vP).y; vec3 top=vec3(0.36,0.66,1.0); vec3 mid=vec3(0.74,0.9,1.0); vec3 hor=vec3(1.0,0.93,0.82); vec3 c=mix(hor,mid,smoothstep(0.0,0.18,h)); c=mix(c,top,smoothstep(0.15,0.7,h)); gl_FragColor=vec4(c,1.0); }' });
    const sky = new THREE.Mesh(new THREE.SphereGeometry(400, 24, 12), mat); this.scene.add(sky);
    // clouds
    this.clouds = new THREE.Group(); const cm = std(0xffffff, 1, 0, { emissive: 0xffffff, emissiveIntensity: 0.25 });
    for (let i = 0; i < 14; i++) {
      const g = new THREE.Group(); const n = 3 + (i % 3);
      for (let j = 0; j < n; j++) { const s = mk(G.sph, cm, (j - n / 2) * 1.3, Math.sin(j * 1.7) * 0.3, Math.cos(j * 2.1) * 0.4, g); s.scale.set(1.5 + (j % 2) * 0.5, 1.1, 1.3); s.castShadow = false; s.receiveShadow = false; }
      const a = (i / 14) * TAU + 0.4, rad = 32 + (i % 4) * 9; g.position.set(Math.cos(a) * rad, 14 + (i % 5) * 3.2, Math.sin(a) * rad); g.scale.setScalar(1.6 + (i % 3) * 0.6); g.userData.a = a; g.userData.rad = rad; g.userData.sp = 0.012 + (i % 4) * 0.004; this.clouds.add(g);
    }
    this.scene.add(this.clouds);
  }

  _island() {
    const s = this.scene;
    // water
    const wc = document.createElement('canvas'); wc.width = wc.height = 256; const c = wc.getContext('2d'); c.fillStyle = '#5fd0ea'; c.fillRect(0, 0, 256, 256);
    c.strokeStyle = 'rgba(255,255,255,.5)'; c.lineWidth = 3; c.lineCap = 'round'; for (let i = 0; i < 46; i++) { const x = (i * 97) % 256, y = (i * 61) % 256; c.beginPath(); c.moveTo(x, y); c.quadraticCurveTo(x + 14, y - 6, x + 28, y); c.stroke(); c.moveTo(x - 256, y); c.quadraticCurveTo(x - 242, y - 6, x - 228, y); c.stroke(); }
    const wt = makeTexture(THREE, wc, { repeat: [36, 36] }); this.waterTex = wt;
    const water = new THREE.Mesh(new THREE.CircleGeometry(300, 48), new THREE.MeshStandardMaterial({ map: wt, color: 0xffffff, roughness: 0.28, metalness: 0.0, emissive: 0x2a9fc0, emissiveIntensity: 0.35 }));
    water.rotation.x = -Math.PI / 2; water.position.y = -0.7; water.receiveShadow = true; s.add(water);
    // lagoon shallows ring
    const sh = new THREE.Mesh(new THREE.RingGeometry(16, 24, 48), new THREE.MeshBasicMaterial({ color: 0x9ff0f0, transparent: true, opacity: 0.35, depthWrite: false })); sh.rotation.x = -Math.PI / 2; sh.position.y = -0.66; s.add(sh);
    const sand = new RoundedBoxGeometry(31, 1.4, 31, 4, 1.4); mk(sand, std(0xf6dfa6, 0.95), 0, -0.75, 0, s).castShadow = false;
    const grass = new RoundedBoxGeometry(27, 0.5, 27, 4, 0.2); mk(grass, std(0x94dc72, 0.9), 0, GRASS_TOP - 0.25, 0, s).castShadow = false;
    // road ring under the track
    const road = new THREE.Mesh(new THREE.PlaneGeometry(25, 25), std(0xdfe7ea, 0.95)); road.rotation.x = -Math.PI / 2; road.position.y = GRASS_TOP + 0.005; road.receiveShadow = true;
    const hole = new THREE.Mesh(new THREE.PlaneGeometry(18, 18), std(0x8ad96a, 0.95)); hole.rotation.x = -Math.PI / 2; hole.position.y = GRASS_TOP + 0.012; hole.receiveShadow = true;
    s.add(road, hole);
    // pier with boat on the +z side (outside track), lighthouse far away
    const pier = new THREE.Group(); const wood = std(0xc08a52, 0.9);
    for (let i = 0; i < 9; i++) B(pier, 2.4, 0.16, 0.5, i % 2 ? wood : std(0xb27a44, 0.9), 0, 0, i * 0.52);
    for (let i = 0; i < 4; i++) { C(pier, 0.09, 1.4, wood, -1.1, -0.5, i * 1.4); C(pier, 0.09, 1.4, wood, 1.1, -0.5, i * 1.4); }
    pier.position.set(7.5, 0.1, 16.2); s.add(pier); mergeMeshes(pier, collectMeshes(pier));
    const boat = new THREE.Group(); const hull = B(boat, 1.0, 0.4, 2.0, std(0xff5a5a, 0.5), 0, 0.1, 0); hull.rotation.z = 0; B(boat, 0.9, 0.06, 1.8, std(0xfff4d6), 0, 0.33, 0); C(boat, 0.05, 1.6, wood, 0, 1.0, -0.2); const sail = B(boat, 0.03, 1.2, 0.9, std(0xffffff, 0.8), 0, 1.1, 0.2); sail.rotation.y = 0; boat.position.set(11.2, -0.5, 18.5); boat.rotation.y = 0.3; s.add(boat); this.boat = boat;
    const boat2 = boat.clone(); boat2.position.set(-17, -0.5, -12); boat2.rotation.y = 2; s.add(boat2); this.boat2 = boat2;
    // lighthouse on a small islet
    const lh = new THREE.Group(); mk(new RoundedBoxGeometry(7, 1.4, 7, 3, 0.5), std(0xf1d79a, 0.9), 0, -0.2, 0, lh); const tw = mk(G.cyl, std(0xffffff, 0.5), 0, 4, 0, lh); tw.scale.set(1.2, 7, 1.2); tw.geometry = new THREE.CylinderGeometry(0.7, 1.2, 1, 20);
    for (let i = 0; i < 3; i++) { const st = mk(new THREE.CylinderGeometry(1, 1, 1, 20), std(0xff4b5c, 0.5), 0, 1.7 + i * 2.2, 0, lh); st.scale.set(1.05 - i * 0.17, 0.9, 1.05 - i * 0.17); }
    C(lh, 1.0, 0.3, std(0x333a55), 0, 7.6, 0); S(lh, 0.7, std(0xfff3a0, 0.3, 0, { emissive: 0xffe680, emissiveIntensity: 2.4 }), 0, 8.3, 0); mk(G.cone, std(0xff4b5c, 0.5), 0, 9.2, 0, lh).scale.set(1.0, 1.1, 1.0);
    lh.position.set(-30, 0, 22); lh.scale.setScalar(1.3); s.add(lh); mergeMeshes(lh, collectMeshes(lh)); this.lighthouse = lh;
    // far islets with palm-ish trees
    for (const [x, z] of [[34, -18], [-36, -22], [26, 34]]) { const g = new THREE.Group(); mk(new THREE.CylinderGeometry(4, 5.5, 1.4, 18), std(0xf6dfa6, 0.95), 0, -0.2, 0, g); S(g, 3.4, std(0x7ed66a, 0.9), 0, 0.4, 0, 0.3); for (let i = 0; i < 3; i++) { C(g, 0.12, 2.0, wood, i - 1, 1.4, (i % 2) - 0.5); S(g, 0.9, std(0x4fc96a, 0.8), i - 1, 2.6, (i % 2) - 0.5, 0.7); } g.position.set(x, 0, z); s.add(g); }
  }

  _plaza() {
    const s = this.scene, y0 = GRASS_TOP + 0.02;
    // stone paths (cross)
    const pm = std(0xfff0d0, 0.9);
    for (const [w, d] of [[17, 2.2], [2.2, 17]]) { const p = B(s, w, 0.04, d, pm, 0, y0, 0); p.castShadow = false; }
    const ring = new THREE.Mesh(new THREE.RingGeometry(2.7, 3.7, 40), pm); ring.rotation.x = -Math.PI / 2; ring.position.y = y0 + 0.025; ring.receiveShadow = true; s.add(ring);
    // fountain + coin emblem
    const f = new THREE.Group(); const stone = std(0xf4eee2, 0.55);
    mk(new THREE.CylinderGeometry(2.4, 2.6, 0.5, 32), stone, 0, 0.25, 0, f); mk(new THREE.CylinderGeometry(2.0, 2.0, 0.4, 32), std(0x6fdcf0, 0.1, 0, { emissive: 0x2aa8c8, emissiveIntensity: 0.4 }), 0, 0.42, 0, f);
    mk(new THREE.CylinderGeometry(0.35, 0.5, 1.4, 16), stone, 0, 1.1, 0, f); mk(new THREE.CylinderGeometry(1.2, 1.1, 0.25, 24), stone, 0, 1.7, 0, f);
    const coin = new THREE.Group(); const gold = std(0xffc61a, 0.28, 0.6, { emissive: 0xff9a00, emissiveIntensity: 0.25 });
    const disc = mk(new THREE.CylinderGeometry(1.0, 1.0, 0.26, 40), gold, 0, 0, 0, coin); disc.rotation.x = Math.PI / 2;
    const rim = mk(new THREE.TorusGeometry(0.88, 0.07, 10, 40), std(0xffe27a, 0.25, 0.6), 0, 0, 0.14, coin); const rim2 = rim.clone(); rim2.position.z = -0.14; coin.add(rim2);
    const st = new THREE.Shape(); for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + (i * Math.PI) / 5, r = i % 2 ? 0.28 : 0.62; i ? st.lineTo(Math.cos(a) * r, Math.sin(a) * r) : st.moveTo(Math.cos(a) * r, Math.sin(a) * r); }
    const sg = new THREE.ExtrudeGeometry(st, { depth: 0.06, bevelEnabled: false }); const sm1 = mk(sg, std(0xfff1a8, 0.3, 0.4, { emissive: 0xffd24a, emissiveIntensity: 0.5 }), 0, 0, 0.13, coin); const sm2 = sm1.clone(); sm2.position.z = -0.19; coin.add(sm2);
    coin.position.y = 3.2; coin.traverse((c) => (c.userData.keep = true)); f.add(coin); this.coin = coin; f.position.y = GRASS_TOP; s.add(f); mergeMeshes(f, collectMeshes(f));
    // trees (instanced) and bushes
    const N = 46; const trunk = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.12, 0.17, 1, 8), std(0x9a6a3c, 0.9), N); const crown = new THREE.InstancedMesh(new THREE.IcosahedronGeometry(1, 1), new THREE.MeshStandardMaterial({ roughness: 0.75, flatShading: true }), N);
    trunk.castShadow = crown.castShadow = true; trunk.receiveShadow = crown.receiveShadow = true; const m = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler(); const cols = [0x57c75a, 0x6bd45f, 0x46b862, 0x8be06a]; let n = 0;
    let seed = 7; const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
    const spots = []; for (let i = 0; i < 400 && spots.length < N; i++) { const x = (rnd() - 0.5) * 16.4, z = (rnd() - 0.5) * 16.4; if (Math.abs(x) < 1.4 || Math.abs(z) < 1.4) continue; if (Math.hypot(x, z) < 4.2) continue; if (spots.some(([a, b]) => Math.hypot(a - x, b - z) < 1.7)) continue; if (this._reserved(x, z)) continue; spots.push([x, z]); }
    for (const [x, z] of spots) { const sc = 0.8 + rnd() * 0.7; m.compose(new THREE.Vector3(x, y0 + 0.5 * sc * 0.9, z), q, new THREE.Vector3(1, sc * 0.9, 1) ); trunk.setMatrixAt(n, m); m.compose(new THREE.Vector3(x, y0 + 1.4 * sc, z), q.setFromEuler(e.set(0, rnd() * 3, 0)), new THREE.Vector3(0.75 * sc, 0.85 * sc, 0.75 * sc)); crown.setMatrixAt(n, m); crown.setColorAt(n, new THREE.Color(cols[n % 4])); n++; }
    trunk.count = crown.count = n; s.add(trunk, crown);
    // decorative little houses (instanced bodies + roofs)
    const hs = [[-6.2, 6.2], [-2.5, 6.4], [2.6, 6.4], [6.3, 6.1], [-6.4, 2.6], [6.4, 2.6], [-6.4, -2.4], [6.5, -2.3], [-2.6, -6.3], [2.5, -6.4], [6.2, -6.2]];
    const hb = new THREE.InstancedMesh(G.box, std(0xffffff, 0.8), hs.length), hr = new THREE.InstancedMesh(G.cone4, std(0xffffff, 0.7), hs.length); hb.castShadow = hr.castShadow = true; hb.receiveShadow = hr.receiveShadow = true;
    const hc = [0xffd9b8, 0xd4f0ff, 0xfff0a8, 0xffd0e6, 0xd8ffd0], rc = [0xe8503e, 0x4b7cff, 0xff9a3c, 0x9a6cf0, 0x3fb85a];
    hs.forEach(([x, z], i) => { const w = 1.5 + (i % 3) * 0.25, h = 1.0 + (i % 2) * 0.35; const yaw = Math.round(Math.atan2(-x, -z) / (Math.PI / 2)) * (Math.PI / 2); q.setFromEuler(e.set(0, yaw, 0));
      m.compose(new THREE.Vector3(x, y0 + h / 2, z), q, new THREE.Vector3(w, h, w * 0.85)); hb.setMatrixAt(i, m); hb.setColorAt(i, new THREE.Color(hc[i % 5]));
      q.setFromEuler(e.set(0, yaw + Math.PI / 4, 0)); m.compose(new THREE.Vector3(x, y0 + h + 0.4, z), q, new THREE.Vector3(w * 0.78, 0.8, w * 0.68)); hr.setMatrixAt(i, m); hr.setColorAt(i, new THREE.Color(rc[i % 5])); });
    s.add(hb, hr);
    // ferris wheel
    const fw = new THREE.Group(); const wheel = new THREE.Group(); const metal = std(0xffffff, 0.4);
    const rimG = new THREE.TorusGeometry(2.6, 0.06, 8, 48); mk(rimG, metal, 0, 0, 0.35, wheel); mk(rimG, metal, 0, 0, -0.35, wheel);
    const cc = [0xff5a7a, 0xffc61a, 0x4fc96a, 0x4fb4f0, 0xa56cf0, 0xff9a3c, 0xff5a7a, 0xffc61a]; this.cabins = [];
    for (let i = 0; i < 8; i++) { const a = (i / 8) * TAU; const spoke = B(wheel, 0.05, 2.6, 0.05, metal, Math.sin(a) * 1.3, Math.cos(a) * 1.3, 0); spoke.rotation.z = -a; const cab = new THREE.Group(); B(cab, 0.7, 0.55, 0.7, std(cc[i], 0.5), 0, -0.3, 0); B(cab, 0.8, 0.1, 0.8, std(0xffffff), 0, 0.0, 0); cab.position.set(Math.sin(a) * 2.6, Math.cos(a) * 2.6, 0); cab.traverse((c) => (c.userData.keep = true)); wheel.add(cab); this.cabins.push(cab); }
    S(wheel, 0.3, std(0xffc61a, 0.3, 0.4), 0, 0, 0); wheel.position.y = 3.3; fw.add(wheel); this.wheel = wheel;
    for (const sx of [-1, 1]) { const leg = B(fw, 0.12, 3.9, 0.12, metal, sx * 0.9, 1.6, 0.0); leg.rotation.z = sx * 0.28; B(fw, 0.12, 0.12, 0.9, metal, sx * 1.0, 0.1, 0); }
    fw.position.set(-5, y0, -4.6); fw.rotation.y = 0.5; s.add(fw); mergeMeshes(wheel, collectMeshes(wheel)); mergeMeshes(fw, collectMeshes(fw).filter((m) => !wheel.children.includes(m) && m.parent === fw));
    // pond with lily pads + bench + lamp posts
    const pond = new THREE.Mesh(new THREE.CylinderGeometry(1.9, 1.9, 0.08, 28), std(0x6fdcf0, 0.1, 0, { emissive: 0x2aa8c8, emissiveIntensity: 0.3 })); pond.position.set(5.2, y0 + 0.02, -4.6); pond.receiveShadow = true; s.add(pond);
    for (let i = 0; i < 4; i++) { const lp = S(s, 0.28, std(0x4fc96a, 0.7), 5.2 + Math.cos(i * 1.6) * 0.9, y0 + 0.09, -4.6 + Math.sin(i * 1.6) * 0.8, 0.12); lp.castShadow = false; }
    for (const [x, z] of [[-3.3, 0.0], [3.3, 0], [0, 3.3], [0, -3.3]]) { C(s, 0.05, 1.5, std(0x444b66), x, y0 + 0.75, z); S(s, 0.2, std(0xfff3b0, 0.3, 0, { emissive: 0xffe080, emissiveIntensity: 1.6 }), x, y0 + 1.6, z); }
    for (const [x, z, r] of [[-3.8, 3.6, 0.2], [3.8, 3.6, -0.2]]) { const b = new THREE.Group(); B(b, 1.2, 0.1, 0.4, std(0xc08a52), 0, 0.4, 0); B(b, 1.2, 0.5, 0.08, std(0xc08a52), 0, 0.75, -0.2); B(b, 0.1, 0.4, 0.4, std(0x444b66), -0.5, 0.2, 0); B(b, 0.1, 0.4, 0.4, std(0x444b66), 0.5, 0.2, 0); b.position.set(x, y0, z); b.rotation.y = r; s.add(b); }
    // flowers
    const fl = new THREE.InstancedMesh(G.sph, new THREE.MeshStandardMaterial({ roughness: 0.6 }), 120); let fi = 0; const fc = [0xff6fae, 0xffd93b, 0xffffff, 0xff9a3c, 0xa56cf0];
    for (let i = 0; i < 600 && fi < 120; i++) { const x = (rnd() - 0.5) * 16.6, z = (rnd() - 0.5) * 16.6; if (Math.abs(x) < 1.4 || Math.abs(z) < 1.4 || Math.hypot(x, z) < 4 || this._reserved(x, z)) continue; if (spots.some(([a, b]) => Math.hypot(a - x, b - z) < 0.9)) continue; m.compose(new THREE.Vector3(x, y0 + 0.1, z), q.identity(), new THREE.Vector3(0.1, 0.1, 0.1)); fl.setMatrixAt(fi, m); fl.setColorAt(fi, new THREE.Color(fc[fi % 5])); fi++; }
    fl.count = fi; s.add(fl);
  }
  _reserved(x, z) { return (Math.hypot(x + 5, z + 4.6) < 3.3) || (Math.hypot(x - 5.2, z + 4.6) < 2.5) || (Math.abs(x) < 4.2 && Math.abs(z) < 4.2 && Math.hypot(x, z) < 4.2) || [[-3.8, 3.6], [3.8, 3.6]].some(([a, b]) => Math.hypot(a - x, b - z) < 1.2) || [[-6.2, 6.2], [-2.5, 6.4], [2.6, 6.4], [6.3, 6.1], [-6.4, 2.6], [6.4, 2.6], [-6.4, -2.4], [6.5, -2.3], [-2.6, -6.3], [2.5, -6.4], [6.2, -6.2]].some(([a, b]) => Math.hypot(a - x, b - z) < 1.5); }

  // ---------- tiles ----------
  tilePos(i) {
    const s = Math.floor(i / 10), k = i % 10; const L = 10.5; let x, z;
    if (k === 0) { x = [L, -L, -L, L][s]; z = [L, L, -L, -L][s]; }
    else { const a = 10 - 2 * k; if (s === 0) { x = a; z = L; } else if (s === 1) { x = -L; z = a; } else if (s === 2) { x = -a; z = -L; } else { x = L; z = -a; } }
    return { x, z, rot: SIDE_ROT[s] + (k === 0 ? 0 : 0), corner: k === 0 };
  }

  _buildTiles() {
    const slabGeo = new RoundedBoxGeometry(1.92, SLAB_H, 2.92, 3, 0.06), cornerGeo = new RoundedBoxGeometry(2.92, SLAB_H, 2.92, 3, 0.08);
    const bandGeo = new THREE.BoxGeometry(1.92, SLAB_H + 0.04, 0.5);
    this.winApt = windowTexture('apt'); this.winSky = windowTexture('sky');
    for (let i = 0; i < 40; i++) {
      const d = TILES[i], p = this.tilePos(i); const g = new THREE.Group(); g.position.set(p.x, GRASS_TOP, p.z); g.rotation.y = p.rot; this.scene.add(g);
      const set = d.set ? SETS[d.set] : null;
      let base = 0xfff4dc; if (d.type === 'surprise') base = 0xe6d0ff; else if (d.type === 'dig') base = 0xffe6a8; else if (d.type === 'tax') base = 0xffd0d0; else if (d.type === 'start') base = 0xc8f5c0; else if (d.type === 'park') base = 0xbdf0a8; else if (d.type === 'nap') base = 0xd0d8ff; else if (d.type === 'gonap') base = 0xe8e0ff; else if (d.type === 'station') base = 0xe8ecf4; else if (d.type === 'util') base = 0xe8e4ff;
      const slab = new THREE.Mesh(p.corner ? cornerGeo : slabGeo, std(base, 0.5, 0, { })); slab.position.y = SLAB_H / 2; slab.receiveShadow = true; slab.castShadow = true; slab.userData.tile = i; slab.userData.keep = true; g.add(slab); this.pickables.push(slab);
      const tile = { i, d, g, pos: new THREE.Vector3(p.x, GRASS_TOP + SLAB_H, p.z), rot: p.rot, corner: p.corner, level: 0, owner: -1, levels: [], bob: [] };
      if (set && d.type === 'prop') { const band = new THREE.Mesh(bandGeo, std(set.hex, 0.45)); band.position.set(0, (SLAB_H + 0.04) / 2, -1.2); band.castShadow = true; band.userData.tile = i; band.userData.keep = true; g.add(band); this.pickables.push(band); }
      // owner stripe + flag for ownable tiles
      if (d.price) {
        tile.stripeMat = new THREE.MeshStandardMaterial({ color: 0xdddddd, roughness: 0.4, emissive: 0x000000 }); const stripe = new THREE.Mesh(new THREE.BoxGeometry(1.7, 0.02, 0.2), tile.stripeMat); stripe.position.set(0, SLAB_H + 0.005, 1.3); g.add(stripe); tile.stripe = stripe; stripe.userData.keep = true;
        tile.flag = new THREE.Group(); tile.flagMat = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.5, side: THREE.DoubleSide, emissive: 0x000000 }); C(tile.flag, 0.03, 1.3, std(0xf4f4f4, 0.4), 0, 0.65, 0); const fl = mk(new THREE.PlaneGeometry(0.62, 0.36), tile.flagMat, 0.34, 1.12, 0, tile.flag); fl.castShadow = false; S(tile.flag, 0.07, std(0xffd93b, 0.3, 0.5), 0, 1.32, 0); tile.flag.position.set(0.78, SLAB_H, 1.18); tile.flag.visible = false; tile.flag.userData.keep = true; g.add(tile.flag);
        tile.tag = spriteOf(priceTagCanvas('$' + d.price, set.hex), 1.5, 0.75, 0, 2.55, 0.15, g); tile.tag.material.depthTest = false; tile.tag.renderOrder = 10;
      }
      this.tiles.push(tile);
      this['_b_' + d.type] && this['_b_' + d.type](tile, g, d, set); mergeStatic(g);
    }
    // Start arrows are built in _b_start. Shared per-frame animation for floaty decorations
  }

  lane(i, slot, out = new THREE.Vector3()) {
    const t = this.tiles[i]; const off = (slot - 1.5) * 0.46; const lz = t.corner ? 0.55 : 0.98; const c = Math.cos(t.rot), s = Math.sin(t.rot);
    out.set(t.pos.x + off * c + lz * s, t.pos.y, t.pos.z - off * s + lz * c); return out;
  }

  _b_prop(tile, g, d, set) {
    const tint = lighten(set.hex, 0.62), tintMat = std(tint.getHex(), 0.7), roofMat = std(darken(set.hex, 0.05).getHex(), 0.55), white = std(0xffffff, 0.6), door = std(0x8a5a30, 0.7);
    const win = std(0x9ad8ff, 0.2, 0, { emissive: 0x4a90d0, emissiveIntensity: 0.35 }); const y = SLAB_H, zc = -0.2;
    // sign for sale
    const sign = new THREE.Group(); C(sign, 0.04, 0.9, std(0x9a6a3c), 0, 0.45, 0); const bd = B(sign, 0.9, 0.5, 0.06, white, 0, 0.95, 0); B(sign, 0.9, 0.14, 0.07, std(set.hex, 0.5), 0, 1.12, 0); sign.position.set(0, y, 0.15);
    const flw = [0xff6fae, 0xffd93b, 0xffffff]; for (let k = 0; k < 6; k++) S(sign, 0.1, std(flw[k % 3], 0.6), -0.7 + k * 0.28, 0.08, -0.55 + (k % 2) * 1.0, 1);
    g.add(sign); tile.sign = sign; tile.bd = bd;
    const mkGroup = () => { const gg = new THREE.Group(); gg.position.set(0, y, zc); gg.visible = false; g.add(gg); return gg; };
    // level 1: cottage
    const l1 = mkGroup(); B(l1, 1.15, 0.7, 0.95, tintMat, 0, 0.35, 0); const roof = mk(G.cone4, roofMat, 0, 0.98, 0, l1); roof.scale.set(0.95, 0.6, 0.78); roof.rotation.y = Math.PI / 4;
    B(l1, 0.26, 0.42, 0.06, door, 0, 0.21, 0.49); B(l1, 0.22, 0.22, 0.06, win, -0.38, 0.42, 0.49); B(l1, 0.22, 0.22, 0.06, win, 0.38, 0.42, 0.49); B(l1, 0.2, 0.4, 0.2, white, 0.3, 1.1, -0.1); S(l1, 0.06, std(0xffd93b, 0.3), 0.12, 0.2, 0.52);
    // level 2: apartment
    const l2 = mkGroup(); const am = std(tint.getHex(), 0.7, 0, { map: this.winApt }); am.map = this.winApt.clone(); am.map.needsUpdate = true; am.map.repeat.set(1, 1.5);
    B(l2, 1.3, 1.55, 1.0, am, 0, 0.78, 0); B(l2, 1.4, 0.14, 1.1, roofMat, 0, 1.62, 0); B(l2, 0.4, 0.3, 0.4, white, -0.3, 1.84, -0.1); const aw = B(l2, 1.3, 0.07, 0.34, std(set.hex, 0.5), 0, 0.5, 0.62); aw.rotation.x = 0.35; B(l2, 0.3, 0.5, 0.06, door, 0, 0.25, 0.51);
    // level 3: skyscraper
    const l3 = mkGroup(); const sm = std(0xffffff, 0.25, 0.1, { map: this.winSky.clone(), emissive: 0xffffff, emissiveMap: this.winSky, emissiveIntensity: 0.55 }); sm.map.needsUpdate = true; sm.map.repeat.set(1, 1.6);
    B(l3, 1.6, 0.35, 1.25, roofMat, 0, 0.18, 0); B(l3, 1.1, 2.9, 0.9, sm, 0, 1.8, 0); B(l3, 0.8, 0.5, 0.65, roofMat, 0, 3.5, 0); C(l3, 0.03, 0.9, std(0xdddddd, 0.3, 0.6), 0, 4.2, 0); S(l3, 0.07, std(0xff4040, 0.3, 0, { emissive: 0xff2020, emissiveIntensity: 3 }), 0, 4.68, 0); B(l3, 0.34, 0.06, 0.34, std(set.hex, 0.4), 0, 3.78, 0.0);
    tile.levels = [null, l1, l2, l3];
    // scaffolding
    const sc = new THREE.Group(); const yel = std(0xffc61a, 0.5); for (const [x, z] of [[-0.7, -0.55], [0.7, -0.55], [-0.7, 0.55], [0.7, 0.55]]) C(sc, 0.035, 1.6, yel, x, 0.8, z); for (const yy of [0.6, 1.2]) { B(sc, 1.45, 0.04, 0.04, yel, 0, yy, 0.55); B(sc, 1.45, 0.04, 0.04, yel, 0, yy, -0.55); B(sc, 0.04, 0.04, 1.1, yel, -0.7, yy, 0); B(sc, 0.04, 0.04, 1.1, yel, 0.7, yy, 0); } sc.position.set(0, y, zc); sc.visible = false; g.add(sc); tile.scaffold = sc;
  }
  _b_station(tile, g, d, set) {
    const y = SLAB_H, cols = [0x4b7cff, 0xff5a5a, 0x4fc96a, 0xffb21c]; const idx = [5, 15, 25, 35].indexOf(d.i);
    const sign = new THREE.Group(); const bd = B(sign, 1.0, 0.5, 0.06, std(0xffffff), 0, 0.95, 0); C(sign, 0.04, 0.9, std(0x9a6a3c), 0, 0.45, 0); sign.position.set(0, y, 0.2); g.add(sign); tile.sign = sign;
    for (const sx of [-0.55, 0.55]) B(g, 0.06, 0.04, 2.7, std(0x777f90, 0.4, 0.5), sx * 0.7, y + 0.02, 0);
    for (let k = -4; k <= 4; k++) B(g, 1.3, 0.03, 0.1, std(0x9a6a3c), 0, y + 0.01, k * 0.3);
    const st = new THREE.Group(); B(st, 1.5, 0.75, 0.8, std(0xfff0d0, 0.7), 0, 0.38, 0); const rf = B(st, 1.7, 0.1, 1.0, std(0xe8503e, 0.5), 0, 0.82, 0); const rf2 = mk(G.cone4, std(0xe8503e, 0.5), 0, 1.05, 0, st); rf2.scale.set(0.95, 0.45, 0.6); rf2.rotation.y = Math.PI / 4; C(st, 0.22, 0.05, std(0xffffff), 0, 0.5, 0.41).rotation.x = Math.PI / 2; B(st, 0.3, 0.45, 0.05, std(0x8a5a30), 0.45, 0.22, 0.41); st.position.set(0, y, -0.9); g.add(st); tile.levels = [null, st]; tile.stationBase = st;
    const tr = new THREE.Group(); const c = cols[idx]; const body = mk(new THREE.CylinderGeometry(1, 1, 1, 16), std(c, 0.35), 0, 0.3, 0, tr); body.scale.set(0.22, 0.9, 0.22); body.rotation.z = Math.PI / 2; B(tr, 0.4, 0.42, 0.42, std(c, 0.35), -0.55, 0.38, 0); B(tr, 0.45, 0.06, 0.5, std(0x333a55), -0.55, 0.62, 0); C(tr, 0.07, 0.2, std(0x333a55), 0.3, 0.6, 0); for (const wx of [-0.4, 0.0, 0.35]) for (const wz of [-0.2, 0.2]) { const w = C(tr, 0.12, 0.05, std(0x333a55), wx, 0.1, wz); w.rotation.x = Math.PI / 2; }
    B(tr, 0.5, 0.3, 0.38, std(0xffd93b, 0.4), 0.95, 0.28, 0); tr.rotation.y = Math.PI / 2; tr.position.set(0.0, y, 0.45); tr.scale.setScalar(0.9); tr.userData.keep = true; g.add(tr); tile.train = tr;
  }
  _b_util(tile, g, d, set) {
    const y = SLAB_H; const sign = new THREE.Group(); const bd = B(sign, 1.0, 0.5, 0.06, std(0xffffff), 0, 0.95, 0); C(sign, 0.04, 0.9, std(0x9a6a3c), 0, 0.45, 0); sign.position.set(0, y, 1.0); g.add(sign); tile.sign = sign;
    const solar = d.i === 12; const u = new THREE.Group();
    if (solar) { for (const x of [-0.5, 0.5]) C(u, 0.05, 0.8, std(0x777f90, 0.4, 0.5), x, 0.4, 0); const pn = B(u, 1.5, 0.06, 1.0, std(0x2a4fb8, 0.15, 0.4, { emissive: 0x1a3a90, emissiveIntensity: 0.4 }), 0, 1.0, 0); pn.rotation.x = -0.5; for (let k = 1; k < 4; k++) { const ln = B(u, 1.5, 0.07, 0.02, std(0xddeeff), 0, 1.0, 0); ln.rotation.x = -0.5; ln.position.z = (k - 2) * 0.25; ln.position.y = 1.0 + 0.12 * (k - 2) * 0.5 * -1 - 0.0; } S(u, 0.28, std(0xffd93b, 0.3, 0, { emissive: 0xffc000, emissiveIntensity: 1.5 }), 0.9, 1.7, -0.3); }
    else { for (const [x, z] of [[-0.35, -0.3], [0.35, -0.3], [-0.35, 0.3], [0.35, 0.3]]) C(u, 0.04, 1.2, std(0x9a6a3c), x, 0.6, z); C(u, 0.55, 0.8, std(0x7ad0ff, 0.25, 0.1), 0, 1.5, 0); const cp = mk(G.cone, std(0xe8503e, 0.5), 0, 2.15, 0, u); cp.scale.set(0.62, 0.45, 0.62); S(u, 0.12, std(0xffffff, 0.3, 0, { emissive: 0x9ad8ff, emissiveIntensity: 0.8 }), 0, 1.5, 0.56); }
    u.position.set(0, y, -0.6); g.add(u); tile.levels = [null, u]; tile.util = u;
  }
  _b_surprise(tile, g) {
    const y = SLAB_H; const gift = new THREE.Group(); const pm = std(0xa86cf0, 0.35, 0, { }), rb = std(0xffd93b, 0.3);
    B(gift, 0.95, 0.8, 0.95, pm, 0, 0.4, 0); B(gift, 1.0, 0.16, 1.0, std(0xb888ff, 0.35), 0, 0.85, 0); B(gift, 0.18, 0.82, 0.98, rb, 0, 0.41, 0); B(gift, 0.98, 0.82, 0.18, rb, 0, 0.41, 0); const bow1 = S(gift, 0.26, rb, -0.2, 1.05, 0, 0.7); const bow2 = S(gift, 0.26, rb, 0.2, 1.05, 0, 0.7); bow1.rotation.z = 0.5; bow2.rotation.z = -0.5;
    gift.position.set(0, y + 0.1, -0.1); gift.userData.keep = true; g.add(gift); tile.gift = gift;
    const cv = document.createElement('canvas'); cv.width = cv.height = 128; const c = cv.getContext('2d'); c.fillStyle = '#fff'; c.beginPath(); c.arc(64, 64, 54, 0, TAU); c.fill(); c.fillStyle = '#9a5cf0'; c.beginPath(); c.arc(64, 64, 46, 0, TAU); c.fill(); c.fillStyle = '#fff'; c.font = '900 78px ui-rounded, system-ui, sans-serif'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText('?', 64, 70);
    tile.mark = spriteOf(cv, 0.9, 0.9, 0, 2.3, -0.1, g);
  }
  _b_dig(tile, g) {
    const y = SLAB_H; const dirt = std(0x9a6a3c, 0.95); const mound = S(g, 0.9, dirt, 0.1, y, -0.35, 0.35); const chest = new THREE.Group(); const wd = std(0xb8742c, 0.6), gd = std(0xffc61a, 0.3, 0.6);
    B(chest, 0.9, 0.45, 0.6, wd, 0, 0.22, 0); const lid = mk(new THREE.CylinderGeometry(0.3, 0.3, 0.9, 16, 1, false, 0, Math.PI), wd, 0, 0.45, 0, chest); lid.rotation.set(Math.PI / 2, 0, Math.PI / 2); lid.rotation.order = 'YXZ'; lid.rotation.set(0, 0, Math.PI / 2); lid.rotation.y = 0;
    B(chest, 0.94, 0.08, 0.64, gd, 0, 0.3, 0); B(chest, 0.14, 0.2, 0.08, gd, 0, 0.42, 0.31); S(chest, 0.1, gd, 0.5, 0.55, 0.2);
    chest.position.set(0.15, y + 0.2, -0.35); chest.rotation.y = -0.3; g.add(chest); tile.chest = chest;
    const sh = new THREE.Group(); C(sh, 0.04, 1.2, std(0x9a6a3c), 0, 0.6, 0); B(sh, 0.3, 0.4, 0.05, std(0xcfd6e0, 0.3, 0.6), 0, 0.0, 0); sh.position.set(-0.6, y + 0.35, 0.3); sh.rotation.z = 0.35; g.add(sh);
    tile.mark = spriteOf(glyphCanvas('gem', 128), 0.9, 0.9, 0, 2.1, -0.2, g);
  }
  _b_tax(tile, g, d) {
    const y = SLAB_H; const pink = d.i === 4; const sh = new THREE.Group(); const col = pink ? 0xff7ac0 : 0x6fd0ff;
    B(sh, 1.4, 0.8, 0.9, std(0xfff4e8, 0.7), 0, 0.4, 0); const aw = B(sh, 1.5, 0.08, 0.5, std(col, 0.5), 0, 0.88, 0.62); aw.rotation.x = 0.35; for (let k = 0; k < 5; k++) { const st = B(sh, 0.15, 0.09, 0.5, std(0xffffff, 0.5), -0.6 + k * 0.3, 0.885, 0.62); st.rotation.x = 0.35; }
    B(sh, 0.4, 0.5, 0.05, std(0x8a5a30), 0, 0.25, 0.46); B(sh, 1.2, 0.5, 0.06, std(col, 0.5), 0, 1.3, 0); sh.position.set(0, y, -0.4); g.add(sh);
    tile.mark = spriteOf(glyphCanvas(d.glyph, 128), 0.8, 0.8, 0, 1.3, 0.0, g); tile.mark.position.set(0, 1.55, -0.3);
    const c = document.createElement('canvas'); c.width = 256; c.height = 128; const x = c.getContext('2d'); x.fillStyle = '#fff'; x.beginPath(); x.roundRect(20, 20, 216, 80, 38); x.fill(); x.fillStyle = '#ff5a6a'; x.beginPath(); x.roundRect(30, 30, 196, 60, 30); x.fill(); x.fillStyle = '#fff'; x.font = '800 42px ui-rounded, system-ui, sans-serif'; x.textAlign = 'center'; x.textBaseline = 'middle'; x.fillText('-$' + d.fee, 128, 62);
    spriteOf(c, 1.4, 0.7, 0, 2.5, 0.2, g);
  }
  _b_start(tile, g) {
    const y = SLAB_H; const lab = new THREE.Mesh(new THREE.PlaneGeometry(2.4, 1.0), new THREE.MeshStandardMaterial({ map: makeTexture(THREE, labelCanvas('START', '#7ad86a', '#ffffff', 512, 214), {}), roughness: 0.6 })); lab.rotation.x = -Math.PI / 2; lab.position.set(0, y + 0.01, -0.6); lab.receiveShadow = true; g.add(lab);
    const arrow = new THREE.Shape(); arrow.moveTo(-0.8, -0.2); arrow.lineTo(0.2, -0.2); arrow.lineTo(0.2, -0.5); arrow.lineTo(0.9, 0); arrow.lineTo(0.2, 0.5); arrow.lineTo(0.2, 0.2); arrow.lineTo(-0.8, 0.2); const am = new THREE.Mesh(new THREE.ShapeGeometry(arrow), std(0xffffff, 0.5)); am.rotation.x = -Math.PI / 2; am.rotation.z = Math.PI; am.position.set(0, y + 0.012, 0.45); g.add(am);
    const pil = std(0xffd93b, 0.4); for (const sx of [-1.15, 1.15]) { C(g, 0.12, 1.9, pil, sx, y + 0.95, 1.05); S(g, 0.28, std(sx < 0 ? 0xff5a7a : 0x4fb4f0, 0.3), sx, y + 2.1, 1.05); }
    B(g, 2.6, 0.32, 0.2, std(0xff5a7a, 0.4), 0, y + 1.9, 1.05); this.startBanner = spriteOf(labelCanvas('START', '#00000000', '#fff', 256, 80), 1.9, 0.6, 0, y + 1.9, 1.2, g);
    // coin pile
    tile.mark = spriteOf(glyphCanvas('coin', 128), 0.9, 0.9, 0, 2.9, 1.05, g);
  }
  _b_park(tile, g) {
    const y = SLAB_H; const bl = new THREE.Mesh(new THREE.PlaneGeometry(1.4, 1.4), new THREE.MeshStandardMaterial({ map: (() => { const c = document.createElement('canvas'); c.width = c.height = 128; const x = c.getContext('2d'); for (let a = 0; a < 8; a++) for (let b = 0; b < 8; b++) { x.fillStyle = (a + b) % 2 ? '#ff6a6a' : '#fff'; x.fillRect(a * 16, b * 16, 16, 16); } return makeTexture(THREE, c); })(), roughness: 0.9 })); bl.rotation.x = -Math.PI / 2; bl.rotation.z = 0.3; bl.position.set(0.5, y + 0.012, 0.5); g.add(bl);
    const bk = B(g, 0.35, 0.25, 0.25, std(0xc08a52, 0.8), 0.5, y + 0.15, 0.5); const ft = new THREE.Group(); mk(new THREE.CylinderGeometry(0.7, 0.8, 0.2, 20), std(0xf4eee2), 0, 0.1, 0, ft); mk(new THREE.CylinderGeometry(0.5, 0.5, 0.22, 20), std(0x6fdcf0, 0.1, 0, { emissive: 0x2aa8c8, emissiveIntensity: 0.4 }), 0, 0.12, 0, ft); C(ft, 0.09, 0.6, std(0xf4eee2), 0, 0.4, 0); S(ft, 0.2, std(0x9ee8ff, 0.1), 0, 0.75, 0, 0.5); ft.position.set(-0.7, y, -0.7); g.add(ft);
    for (const [x, z, s] of [[0.8, -0.9, 1], [-0.9, 0.7, 0.8]]) { C(g, 0.08, 0.9 * s, std(0x9a6a3c), x, y + 0.45 * s, z); S(g, 0.55 * s, std(0x57c75a, 0.7), x, y + 1.15 * s, z); }
    const lab = new THREE.Mesh(new THREE.PlaneGeometry(1.5, 0.6), new THREE.MeshStandardMaterial({ map: makeTexture(THREE, labelCanvas('PARK', '#8ddc78', '#fff', 320, 128), {}), roughness: 0.7 })); lab.rotation.x = -Math.PI / 2; lab.position.set(-0.2, y + 0.013, 1.05); g.add(lab);
    tile.mark = spriteOf(glyphCanvas('flower', 128), 0.9, 0.9, 0, 2.1, 0, g);
  }
  _b_nap(tile, g) {
    const y = SLAB_H; const bed = new THREE.Group(); B(bed, 1.5, 0.3, 1.0, std(0x9a6a3c, 0.8), 0, 0.15, 0); B(bed, 1.4, 0.18, 0.9, std(0xfff4e8, 0.9), 0, 0.38, 0); B(bed, 0.55, 0.14, 0.7, std(0xffffff, 0.8), -0.45, 0.52, 0); B(bed, 0.85, 0.12, 0.92, std(0x6a76e8, 0.8), 0.3, 0.52, 0); B(bed, 0.1, 0.7, 1.0, std(0x9a6a3c), -0.78, 0.45, 0); bed.position.set(0, y, -0.3); bed.rotation.y = 0.2; g.add(bed);
    tile.mark = spriteOf(glyphCanvas('moon', 128), 0.9, 0.9, 0.0, 1.9, -0.3, g); tile.zs = [];
    for (let k = 0; k < 3; k++) { const cv = labelCanvas('Z', '#00000000', '#8a96ff', 64, 64); const sp = spriteOf(cv, 0.35 + k * 0.1, 0.35 + k * 0.1, 0.3 + k * 0.25, 1.3 + k * 0.4, -0.3, g); tile.zs.push(sp); }
    const lab = new THREE.Mesh(new THREE.PlaneGeometry(1.8, 0.6), new THREE.MeshStandardMaterial({ map: makeTexture(THREE, labelCanvas('NAP', '#8a96ff', '#fff', 320, 110), {}), roughness: 0.7 })); lab.rotation.x = -Math.PI / 2; lab.position.set(0, y + 0.013, 0.95); g.add(lab);
  }
  _b_gonap(tile, g) {
    const y = SLAB_H; const cl = new THREE.Group(); const cm = std(0xffffff, 0.8, 0, { emissive: 0xaab4ff, emissiveIntensity: 0.15 }); S(cl, 0.5, cm, -0.45, 0.5, 0, 0.8); S(cl, 0.7, cm, 0.1, 0.75, 0, 0.8); S(cl, 0.5, cm, 0.65, 0.5, 0, 0.8); cl.position.set(0, y + 0.6, -0.4); cl.userData.keep = true; g.add(cl); tile.cloud = cl;
    const eyes = std(0x2a2233); S(cl, 0.06, eyes, -0.1, 0.78, 0.66); S(cl, 0.06, eyes, 0.3, 0.78, 0.66);
    tile.zs = []; for (let k = 0; k < 3; k++) tile.zs.push(spriteOf(labelCanvas('Z', '#00000000', '#8a96ff', 64, 64), 0.4 + k * 0.1, 0.4 + k * 0.1, 0.8 + k * 0.2, 2.1 + k * 0.35, -0.4, g));
    const lab = new THREE.Mesh(new THREE.PlaneGeometry(2.0, 0.6), new THREE.MeshStandardMaterial({ map: makeTexture(THREE, labelCanvas('SLEEPY!', '#a56cf0', '#fff', 360, 110), {}), roughness: 0.7 })); lab.rotation.x = -Math.PI / 2; lab.position.set(0, y + 0.013, 0.95); g.add(lab);
  }

  // ---------- owner / building state ----------
  setOwner(i, owner, hex, animate) {
    const t = this.tiles[i]; if (!t.d.price) return; t.owner = owner;
    if (owner < 0) { t.flag.visible = false; t.stripeMat.color.set(0xdddddd); t.stripeMat.emissive.set(0); if (t.tag) t.tag.visible = true; this._showLevel(t, 0); t.level = 0; return; }
    t.flag.visible = true; t.flagMat.color.set(hex); t.flagMat.emissive.set(hex).multiplyScalar(0.25); t.stripeMat.color.set(hex); t.stripeMat.emissive.set(hex).multiplyScalar(0.3); if (t.tag) t.tag.visible = false;
    if (animate) { t.flag.scale.setScalar(0.01); T.add(0.5, (u) => t.flag.scale.setScalar(Math.max(0.01, u)), easeOutBack); }
  }
  _showLevel(t, lv) {
    if (t.d.type === 'prop') { t.sign.visible = lv === 0; for (let k = 1; k <= 3; k++) t.levels[k].visible = k === lv; }
  }
  setLevel(i, lv, animate) {
    const t = this.tiles[i]; const d = t.d;
    if (d.type !== 'prop') { t.level = lv; return Promise.resolve(); }
    const prev = t.level; t.level = lv;
    if (!animate || lv === 0) { this._showLevel(t, lv); for (let k = 1; k <= 3; k++) { t.levels[k].scale.set(1, 1, 1); } return Promise.resolve(); }
    // construction animation
    if (t.sign) t.sign.visible = false;
    for (let k = 1; k <= 3; k++) t.levels[k].visible = false;
    const nb = t.levels[lv], old = prev > 0 ? t.levels[prev] : null; const sc = t.scaffold; sc.visible = true; sc.scale.set(0.2, 0.2, 0.2); nb.visible = false;
    this.puff(t.pos, 8, 0xf3e6c8);
    this.sfxHook && this.sfxHook('whoosh');
    return T.add(0.45, (u) => { sc.scale.setScalar(0.2 + 0.8 * easeOutBack(u)); sc.rotation.y = Math.sin(u * 20) * 0.03; }).then(() => {
      if (old) { old.visible = true; T.add(0.3, (u) => old.scale.setScalar(Math.max(0.01, 1 - u))).then(() => { old.visible = false; old.scale.set(1, 1, 1); }); }
      return T.add(0.55, (u) => { const a = u < 0.5 ? u / 0.5 : 1; sc.position.x = 0; nb.visible = true; const s = easeOutBack(Math.min(1, u)); nb.scale.set(1 + (1 - s) * 0.15, Math.max(0.01, s), 1 + (1 - s) * 0.15); });
    }).then(() => { sc.visible = false; nb.scale.set(1, 1, 1); this._showLevel(t, lv); this.puff(t.pos, 12, 0xffffff); this.sparkle(t.pos.clone().setY(t.pos.y + 1.2), 18, 0xfff0a0); this.sfxHook && this.sfxHook('powerup'); this.shake(0.25); });
  }

  // ---------- fx ----------
  _fx() {
    const s = this.scene;
    this.sparks = new PointPool(s, 260, true); this.puffs = new PointPool(s, 120, false);
    // confetti
    const N = 280; this.conf = { N, pos: new Float32Array(N * 3), vel: new Float32Array(N * 3), rot: new Float32Array(N * 3), spin: new Float32Array(N * 3), life: new Float32Array(N), ph: new Float32Array(N), next: 0, alive: 0 };
    this.confMesh = new THREE.InstancedMesh(new THREE.PlaneGeometry(0.2, 0.3), new THREE.MeshBasicMaterial({ side: THREE.DoubleSide, toneMapped: false }), N); this.confMesh.frustumCulled = false; this.confMesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    const cc = [0xff5a7a, 0xffd93b, 0x4fc96a, 0x4fb4f0, 0xa56cf0, 0xff9a3c, 0xffffff]; for (let i = 0; i < N; i++) { this.confMesh.setColorAt(i, new THREE.Color(cc[i % cc.length])); this._dummyZero(i); }
    s.add(this.confMesh);
    // flying coins
    const M = 60; this.coinsN = M; this.coinList = []; this.coinMesh = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.24, 0.24, 0.07, 16), std(0xffc61a, 0.28, 0.6, { emissive: 0xffa800, emissiveIntensity: 0.55 }), M); this.coinMesh.frustumCulled = false; this.coinMesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage); this.coinMesh.count = 0; s.add(this.coinMesh);
    this.dummy = new THREE.Object3D();
    // tile flash ring
    this.flash = new THREE.Mesh(new THREE.RingGeometry(0.9, 1.15, 32), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0, depthWrite: false })); this.flash.rotation.x = -Math.PI / 2; s.add(this.flash);
    this.shakeAmt = 0;
  }
  _dummyZero(i) { const d = new THREE.Object3D(); d.scale.setScalar(0); d.updateMatrix(); this.confMesh.setMatrixAt(i, d.matrix); }
  puff(pos, n = 8, color = 0xffffff) { for (let i = 0; i < n; i++) { const a = Math.random() * TAU, sp = 0.6 + Math.random() * 1.4; this.puffs.emit(pos.x + (Math.random() - 0.5) * 0.8, pos.y + 0.2, pos.z + (Math.random() - 0.5) * 0.8, Math.cos(a) * sp, 0.6 + Math.random() * 0.8, Math.sin(a) * sp, 1.0 + Math.random() * 0.6, 0.7 + Math.random() * 0.4, color, 1.4, -0.3); } }
  sparkle(pos, n = 14, color = 0xfff3a0) { for (let i = 0; i < n; i++) { const a = Math.random() * TAU, e = Math.random() * 1.2 - 0.2, sp = 1.5 + Math.random() * 3; this.sparks.emit(pos.x, pos.y, pos.z, Math.cos(a) * sp, 1 + e * sp, Math.sin(a) * sp, 0.35 + Math.random() * 0.35, 0.6 + Math.random() * 0.7, color, -0.4, -4); } }
  confetti(center, n = 80, power = 1) {
    const c = this.conf; for (let k = 0; k < n; k++) { const i = c.next; c.next = (c.next + 1) % c.N; const a = Math.random() * TAU, sp = (2 + Math.random() * 6) * power;
      c.pos[i * 3] = center.x + (Math.random() - 0.5) * 1.5; c.pos[i * 3 + 1] = center.y + Math.random(); c.pos[i * 3 + 2] = center.z + (Math.random() - 0.5) * 1.5; c.vel[i * 3] = Math.cos(a) * sp; c.vel[i * 3 + 1] = 4 + Math.random() * 7 * power; c.vel[i * 3 + 2] = Math.sin(a) * sp;
      c.rot[i * 3] = Math.random() * 6; c.rot[i * 3 + 1] = Math.random() * 6; c.rot[i * 3 + 2] = Math.random() * 6; c.spin[i * 3] = (Math.random() - 0.5) * 14; c.spin[i * 3 + 1] = (Math.random() - 0.5) * 14; c.spin[i * 3 + 2] = (Math.random() - 0.5) * 14; c.life[i] = 2.4 + Math.random() * 2; c.ph[i] = Math.random() * 6; }
    this.confActive = true;
  }
  rain(center) { // endless gentle confetti above the view
    this.confetti(new THREE.Vector3(center.x + (Math.random() - 0.5) * 14, center.y + 9, center.z + (Math.random() - 0.5) * 10), 4, 0.15);
  }
  coinFly(from, to, n = 8, hop = 2.5) {
    return new Promise((res) => {
      const k = Math.min(n, this.coinsN - this.coinList.length); if (k <= 0) { res(); return; } let left = k;
      for (let i = 0; i < k; i++) this.coinList.push({ from: from.clone(), to: to.clone(), t: -i * 0.07, dur: 0.75 + Math.random() * 0.2, off: new THREE.Vector3((Math.random() - 0.5) * 1.6, 0, (Math.random() - 0.5) * 1.6), hop: hop + Math.random(), done: () => { if (--left === 0) res(); } });
    });
  }
  flashTile(i, color = 0xffffff) { const t = this.tiles[i]; this.flash.position.set(t.pos.x, t.pos.y + 0.03, t.pos.z); this.flash.material.color.set(color); T.add(0.7, (u) => { this.flash.material.opacity = (1 - u) * 0.9; this.flash.scale.setScalar(1 + u * 0.8); }); }
  shake(a) { this.shakeAmt = Math.max(this.shakeAmt, a); }

  // ---------- tokens ----------
  addToken(av, slot) {
    const tk = new THREE.Group(); const gl = (c, r = 0.35) => new THREE.MeshPhysicalMaterial({ color: c, roughness: r, clearcoat: 0.6, clearcoatRoughness: 0.3 });
    const fur = gl(av.fur), belly = gl(av.belly, 0.6), ring = gl(av.color, 0.3), dark = new THREE.MeshStandardMaterial({ color: 0x2a2233, roughness: 0.3 }), white = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.3, emissive: 0xffffff, emissiveIntensity: 0.3 }), pinkM = new THREE.MeshStandardMaterial({ color: 0xff8fb0, roughness: 0.6 });
    const inner = new THREE.Group(); tk.add(inner); tk.userData.inner = inner;
    const base = mk(new THREE.CylinderGeometry(0.46, 0.5, 0.1, 28), ring, 0, 0.05, 0, inner); const bt = mk(new THREE.TorusGeometry(0.47, 0.035, 8, 28), white, 0, 0.1, 0, inner); bt.rotation.x = Math.PI / 2;
    S(inner, 0.36, fur, 0, 0.5, 0, 1.12); S(inner, 0.26, belly, 0, 0.46, 0.17, 1.15);
    const head = new THREE.Group(); head.position.set(0, 1.0, 0); inner.add(head); S(head, 0.34, fur, 0, 0, 0, 0.92);
    const eye = (x) => { S(head, 0.06, dark, x, 0.04, 0.3, 1.2); S(head, 0.02, white, x + 0.02, 0.07, 0.35); };
    const cheek = (x) => { const c = S(head, 0.07, pinkM, x, -0.07, 0.28, 0.6); c.castShadow = false; };
    if (av.kind === 'fox') { for (const sx of [-1, 1]) { const e = mk(G.cone, fur, sx * 0.2, 0.34, 0, head); e.scale.set(0.14, 0.3, 0.1); e.rotation.z = -sx * 0.25; const ei = mk(G.cone, pinkM, sx * 0.2, 0.32, 0.04, head); ei.scale.set(0.08, 0.2, 0.05); ei.rotation.z = -sx * 0.25; } eye(-0.13); eye(0.13); cheek(-0.22); cheek(0.22); S(head, 0.06, dark, 0, -0.03, 0.33, 0.7); S(head, 0.2, belly, 0, -0.1, 0.18, 0.55); const tail = S(inner, 0.2, fur, 0, 0.4, -0.38, 1.3); S(tail, 0.45, belly, 0, 0.0, -0.8, 0.5); tail.rotation.x = 0.8; }
    else if (av.kind === 'bunny') { for (const sx of [-1, 1]) { const e = S(head, 0.1, fur, sx * 0.13, 0.5, 0, 3.0); e.rotation.z = -sx * 0.15; const ei = S(head, 0.055, pinkM, sx * 0.13, 0.5, 0.05, 2.7); ei.rotation.z = -sx * 0.15; } eye(-0.13); eye(0.13); cheek(-0.22); cheek(0.22); S(head, 0.04, pinkM, 0, -0.02, 0.33, 0.7); S(inner, 0.12, belly, 0, 0.25, -0.35, 1); }
    else if (av.kind === 'frog') { for (const sx of [-1, 1]) { S(head, 0.12, fur, sx * 0.2, 0.28, 0.05); S(head, 0.085, white, sx * 0.2, 0.3, 0.12); S(head, 0.045, dark, sx * 0.2, 0.3, 0.19); } const mo = mk(new THREE.TorusGeometry(0.15, 0.012, 6, 16, Math.PI), dark, 0, -0.06, 0.3, head); mo.rotation.z = Math.PI; mo.rotation.x = 0.15; cheek(-0.22); cheek(0.22); }
    else { eye(-0.12); eye(0.12); const bk = mk(G.cone, new THREE.MeshStandardMaterial({ color: 0xffa42b, roughness: 0.4 }), 0, -0.04, 0.34, head); bk.scale.set(0.09, 0.14, 0.07); bk.rotation.x = Math.PI / 2; cheek(-0.22); cheek(0.22); for (const sx of [-1, 1]) { const f = S(inner, 0.12, fur, sx * 0.36, 0.45, 0, 1.6); f.rotation.z = sx * 0.4; } S(head, 0.3, fur, 0, 0.12, -0.02, 0.5); }
    // active marker
    const mark = new THREE.Group(); const cone = mk(new THREE.ConeGeometry(0.2, 0.4, 4), std(0xffd93b, 0.25, 0.3, { emissive: 0xffa800, emissiveIntensity: 0.9 }), 0, 0, 0, mark); cone.rotation.x = Math.PI; mark.position.y = 1.95; mark.visible = false; tk.add(mark); tk.userData.mark = mark;
    tk.scale.setScalar(0.95); this.scene.add(tk);
    const o = { g: tk, inner, mark, av, slot, tile: 0, bobPh: Math.random() * 6, hopping: false };
    this.lane(0, slot, tk.position); this.tokens.push(o); return o;
  }
  hop(o, from, to, dur = 0.3, height = 0.9) {
    const a = this.lane(from, o.slot), b = this.lane(to, o.slot); o.hopping = true; const g = o.g;
    return T.add(dur, (u) => { g.position.lerpVectors(a, b, u); g.position.y += Math.sin(u * Math.PI) * height; const st = Math.sin(u * Math.PI); o.inner.scale.set(1 - st * 0.1, 1 + st * 0.2, 1 - st * 0.1); }, lin).then(() => { o.hopping = false; o.tile = to; o.inner.scale.set(1, 1, 1); return T.add(0.14, (u) => { const s = Math.sin(u * Math.PI); o.inner.scale.set(1 + s * 0.22, 1 - s * 0.22, 1 + s * 0.22); }); });
  }
  placeToken(o, i) { o.tile = i; this.lane(i, o.slot, o.g.position); }
  tileYaw(i) { return yawForTile(i); }

  // ---------- dice ----------
  _dice() {
    const faces = [3, 4, 1, 6, 2, 5]; // +x -x +y -y +z -z
    const mats = faces.map((n) => { const cv = document.createElement('canvas'); cv.width = cv.height = 128; const c = cv.getContext('2d'); const g = c.createLinearGradient(0, 0, 128, 128); g.addColorStop(0, '#ffffff'); g.addColorStop(1, '#eef2fb'); c.fillStyle = g; c.fillRect(0, 0, 128, 128);
      const P = { 1: [[0, 0]], 2: [[-1, -1], [1, 1]], 3: [[-1, -1], [0, 0], [1, 1]], 4: [[-1, -1], [1, -1], [-1, 1], [1, 1]], 5: [[-1, -1], [1, -1], [0, 0], [-1, 1], [1, 1]], 6: [[-1, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [1, 1]] }[n];
      P.forEach(([x, y]) => { c.fillStyle = n === 1 ? '#ff4b5c' : '#2b2f5a'; c.beginPath(); c.arc(64 + x * 32, 64 + y * 32, n === 1 ? 17 : 12, 0, TAU); c.fill(); c.fillStyle = 'rgba(255,255,255,.35)'; c.beginPath(); c.arc(64 + x * 32 - 3, 64 + y * 32 - 3, 4, 0, TAU); c.fill(); });
      const t = makeTexture(THREE, cv); return new THREE.MeshPhysicalMaterial({ map: t, roughness: 0.25, clearcoat: 1, clearcoatRoughness: 0.12 }); });
    const geo = new RoundedBoxGeometry(1.1, 1.1, 1.1, 4, 0.17);
    this.dice = [0, 1].map(() => { const m = new THREE.Mesh(geo, mats); m.castShadow = true; m.receiveShadow = true; m.visible = false; this.scene.add(m); return m; });
    this.faceN = { 3: [1, 0, 0], 4: [-1, 0, 0], 1: [0, 1, 0], 6: [0, -1, 0], 2: [0, 0, 1], 5: [0, 0, -1] };
    this.tray = new THREE.Mesh(new THREE.CylinderGeometry(2.1, 2.2, 0.14, 40), new THREE.MeshPhysicalMaterial({ color: 0xffffff, roughness: 0.4, clearcoat: 0.8 })); this.tray.receiveShadow = true; this.tray.visible = false; this.scene.add(this.tray);
    const rim = new THREE.Mesh(new THREE.TorusGeometry(2.1, 0.08, 8, 40), std(0xffd93b, 0.3, 0.4)); rim.rotation.x = Math.PI / 2; rim.position.y = 0.07; this.tray.add(rim);
  }
  rollDice(vals, focusTile, strength = 1) {
    const v = this.view; const fwd = new THREE.Vector3(-Math.sin(v.tYaw), 0, -Math.cos(v.tYaw)); const side = new THREE.Vector3(fwd.z, 0, -fwd.x);
    const t = this.tiles[focusTile].pos; const land = new THREE.Vector3(t.x, 0, t.z).addScaledVector(fwd, 3.2); land.y = t.y + 0.07 + 0.55 + 0.07;
    this.tray.position.set(land.x, t.y + 0.07, land.z); this.tray.visible = true; this.tray.scale.setScalar(0.01);
    T.add(0.3, (u) => this.tray.scale.setScalar(Math.max(0.01, u)), easeOutBack);
    const jobs = this.dice.map((d, k) => {
      d.visible = true; const spread = (k === 0 ? -1 : 1) * 0.75;
      const end = land.clone().addScaledVector(side, spread).addScaledVector(fwd, (k ? 0.3 : -0.3)); const start = land.clone().addScaledVector(fwd, -9 - k).addScaledVector(side, spread * 2.2 + (k ? 1 : -1)); start.y = land.y + 7 + k * 1.2;
      const n = this.faceN[vals[k]]; const qf = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(n[0], n[1], n[2]), new THREE.Vector3(0, 1, 0)); qf.premultiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), Math.random() * TAU));
      const axis = new THREE.Vector3(Math.random() - 0.5, Math.random() - 0.5, Math.random() - 0.5).normalize(); const A = (7 + Math.random() * 4) * Math.PI * strength; const H0 = start.y - land.y, hs = [H0, 1.9, 0.7, 0.22];
      const durs = hs.map((h, j) => (j === 0 ? Math.sqrt(h) : 2 * Math.sqrt(h))); const tot = durs.reduce((a, b) => a + b, 0); const q = new THREE.Quaternion(); const dur = 1.45 + k * 0.1;
      return T.add(dur, (u) => {
        const hp = Math.min(1, easeOutCubic(Math.min(1, u * 1.15)));
        d.position.lerpVectors(start, end, hp);
        let x = u * tot, j = 0; while (j < 3 && x > durs[j]) { x -= durs[j]; j++; } const f = Math.min(1, x / durs[j]);
        d.position.y = land.y + (j === 0 ? H0 * (1 - f * f) : hs[j] * (1 - Math.pow(2 * f - 1, 2)));
        q.setFromAxisAngle(axis, A * Math.pow(1 - u, 2)); d.quaternion.copy(q).multiply(qf);
        if (u > 0.999) d.quaternion.copy(qf);
      }).then(() => { this.puff(d.position.clone().setY(d.position.y - 0.4), 3, 0xffffff); });
    });
    return Promise.all(jobs).then(() => { this.shake(0.3); });
  }
  hideDice() { return T.add(0.28, (u) => { for (const d of this.dice) d.scale.setScalar(Math.max(0.01, 1 - u)); this.tray.scale.setScalar(Math.max(0.01, 1 - u)); }).then(() => { for (const d of this.dice) { d.visible = false; d.scale.setScalar(1); } this.tray.visible = false; }); }

  // ---------- post ----------
  _post() {
    const pr = this.pixelRatio = Math.min(window.devicePixelRatio || 1, 2); this.renderer.setPixelRatio(pr);
    const rt = new THREE.WebGLRenderTarget(4, 4, { type: THREE.HalfFloatType, samples: pr > 1.5 ? 2 : 4 });
    const comp = (this.composer = new EffectComposer(this.renderer, rt)); comp.setPixelRatio(pr);
    comp.addPass(new RenderPass(this.scene, this.camera));
    this.bloom = new UnrealBloomPass(new THREE.Vector2(512, 512), 0.4, 0.5, 1.5); comp.addPass(this.bloom);
    this.tsH = new ShaderPass(TiltShader); this.tsV = new ShaderPass(TiltShader); this.tsV.uniforms.dir.value.set(0, 1); comp.addPass(this.tsH); comp.addPass(this.tsV);
    comp.addPass(new OutputPass());
  }
  setQuality(q) {
    this.quality = q; const dpr = window.devicePixelRatio || 1; const pr = (this.pixelRatio = q === 0 ? Math.min(dpr, 2) : q === 1 ? Math.min(dpr, 1.5) : 1);
    this.renderer.setPixelRatio(pr); this.composer.setPixelRatio(pr); this.tsH.enabled = this.tsV.enabled = q < 2; this.bloom.enabled = q < 3; this.resize();
  }
  resize() {
    const w = Math.max(1, window.innerWidth), h = Math.max(1, window.innerHeight); const pr = this.pixelRatio;
    this.renderer.setSize(w, h, false); this.composer.setSize(w, h); this.camera.aspect = w / h; this.camera.setViewOffset(w, h, 0, Math.round(h * 0.08), w, h); this.aspect = w / h;
    for (const p of [this.tsH, this.tsV]) { p.uniforms.res.value.set(w * pr, h * pr); p.uniforms.amount.value = pr; }
    this.sparks.mat.uniforms.scale.value = this.puffs.mat.uniforms.scale.value = h * pr * 0.9;
    this.tsH.uniforms.band.value = this.tsV.uniforms.band.value = this.aspect < 1 ? 0.2 : 0.17;
  }

  // ---------- camera ----------
  setMode(mode) { this.view.mode = mode; }
  toScreen(v3, out = { x: 0, y: 0, vis: true }) { this._v.copy(v3).project(this.camera); out.x = (this._v.x * 0.5 + 0.5) * window.innerWidth; out.y = (-this._v.y * 0.5 + 0.5) * window.innerHeight; out.vis = this._v.z < 1; return out; }
  pick(x, y) { const rc = this._rc || (this._rc = new THREE.Raycaster()); const nd = new THREE.Vector2((x / window.innerWidth) * 2 - 1, -(y / window.innerHeight) * 2 + 1); rc.setFromCamera(nd, this.camera); const hit = rc.intersectObjects(this.pickables, false)[0]; return hit ? hit.object.userData.tile : -1; }
  _updateCamera(dt, real) {
    const v = this.view, cam = this.camera; const kk = 1 - Math.exp(-dt * 3.2);
    let needH, needW, pitch;
    if (v.mode === 'orbit') { v.tYaw += dt * 0.12; needH = 30; needW = 28; pitch = 0.95; v.goal.set(0, 0, 0); }
    else if (v.mode === 'overview' || v.zoomOut) { needH = 33; needW = 30; pitch = 1.12; v.goal.set(0, 0, 0); }
    else { needH = 14.5; needW = 10.5; pitch = 0.93; if (v.follow) v.follow(v.goal); }
    const vf = (cam.fov * Math.PI) / 180, th = Math.tan(vf / 2); const dH = (needH * Math.sin(pitch)) / (2 * th), dW = needW / (2 * th * this.aspect); const dist = Math.max(dH, dW);
    v.dist += (dist - v.dist) * kk; v.pitch += (pitch - v.pitch) * kk; v.target.lerp(v.goal, 1 - Math.exp(-dt * (v.mode === 'follow' ? 4.5 : 2.5)));
    let dy = ((((v.tYaw - v.yaw + Math.PI) % TAU) + TAU) % TAU) - Math.PI; v.yaw += dy * (1 - Math.exp(-dt * 2.2));
    const cp = Math.cos(v.pitch), sp = Math.sin(v.pitch);
    cam.position.set(v.target.x + Math.sin(v.yaw) * cp * v.dist, v.target.y + sp * v.dist, v.target.z + Math.cos(v.yaw) * cp * v.dist);
    if (this.shakeAmt > 0.001) { const a = this.shakeAmt; cam.position.x += (Math.random() - 0.5) * a; cam.position.y += (Math.random() - 0.5) * a; cam.position.z += (Math.random() - 0.5) * a; this.shakeAmt *= Math.exp(-dt * 7); }
    cam.lookAt(v.target.x, v.target.y + 0.3, v.target.z);
    // lock the sun's shadow box to the board centre
  }

  update(realDt) {
    const dt = Math.min(realDt, 0.05); this.time += dt; T.update(dt); const tm = this.time;
    this._updateCamera(dt);
    this.waterTex.offset.set(tm * 0.01, tm * 0.006);
    for (const c of this.clouds.children) { c.userData.a += c.userData.sp * dt; c.position.x = Math.cos(c.userData.a) * c.userData.rad; c.position.z = Math.sin(c.userData.a) * c.userData.rad; }
    this.coin.rotation.y = tm * 1.2; this.coin.position.y = 3.2 + Math.sin(tm * 1.8) * 0.12; this.wheel.rotation.z = -tm * 0.12; for (const c of this.cabins) c.rotation.z = tm * 0.12;
    this.boat.position.y = -0.5 + Math.sin(tm * 1.3) * 0.06; this.boat.rotation.z = Math.sin(tm * 1.1) * 0.04; this.boat2.position.y = -0.5 + Math.sin(tm * 1.1 + 2) * 0.06; this.boat2.rotation.z = Math.sin(tm * 0.9) * 0.04; this.lighthouse.rotation.y = tm * 0.2;
    for (const t of this.tiles) {
      if (t.gift) { t.gift.position.y = SLAB_H + 0.2 + Math.abs(Math.sin(tm * 2 + t.i)) * 0.25; t.gift.rotation.y = tm * 0.8; }
      if (t.mark) t.mark.position.y = (t.d.type === 'start' ? 2.9 : t.d.type === 'tax' ? 1.7 : 2.1) + Math.sin(tm * 2 + t.i) * 0.1;
      if (t.zs) t.zs.forEach((z, k) => { z.position.y = 1.3 + k * 0.4 + ((tm * 0.4 + k * 0.33) % 1) * 0.5; z.material.opacity = 1 - ((tm * 0.4 + k * 0.33) % 1); });
      if (t.cloud) t.cloud.position.y = SLAB_H + 0.6 + Math.sin(tm * 1.4) * 0.1;
      if (t.train) t.train.position.x = Math.sin(tm * 0.7 + t.i) * 0.05;
      if (t.flag && t.flag.visible) t.flag.rotation.y = Math.sin(tm * 2 + t.i) * 0.2;
    }
    for (const o of this.tokens) {
      if (!o.hopping) { o.g.position.y = this.tiles[o.tile].pos.y + 0 + Math.abs(Math.sin(tm * 3 + o.bobPh)) * 0.04; }
      o.g.rotation.y += ((((this.view.yaw - o.g.rotation.y + Math.PI) % TAU) + TAU) % TAU - Math.PI) * Math.min(1, dt * 6);
      if (o.mark.visible) { o.mark.position.y = 1.95 + Math.sin(tm * 5) * 0.12; o.mark.rotation.y = tm * 2; }
    }
    // fountain sparkle
    if (Math.random() < 0.5) this.sparks.emit(Math.cos(tm) * 0.3, GRASS_TOP + 1.7, Math.sin(tm) * 0.3, (Math.random() - 0.5) * 1.2, 2 + Math.random(), (Math.random() - 0.5) * 1.2, 0.18, 1.0, 0x9ee8ff, 0, -5);
    this.sparks.update(dt); this.puffs.update(dt);
    // confetti
    const c = this.conf; if (this.confActive) { let alive = 0; const d = this.dummy; for (let i = 0; i < c.N; i++) { if (c.life[i] <= 0) continue; c.life[i] -= dt; if (c.life[i] <= 0) { this._dummyZero(i); continue; } alive++;
      c.vel[i * 3 + 1] -= 11 * dt; c.vel[i * 3] *= 0.985; c.vel[i * 3 + 2] *= 0.985; if (c.vel[i * 3 + 1] < -2.2) c.vel[i * 3 + 1] = -2.2; c.pos[i * 3] += c.vel[i * 3] * dt + Math.sin(tm * 3 + c.ph[i]) * dt * 0.6; c.pos[i * 3 + 1] += c.vel[i * 3 + 1] * dt; c.pos[i * 3 + 2] += c.vel[i * 3 + 2] * dt;
      d.position.set(c.pos[i * 3], c.pos[i * 3 + 1], c.pos[i * 3 + 2]); d.rotation.set(c.rot[i * 3] + c.spin[i * 3] * tm, c.rot[i * 3 + 1] + c.spin[i * 3 + 1] * tm, c.rot[i * 3 + 2]); d.scale.setScalar(Math.min(1, c.life[i] * 2)); d.updateMatrix(); this.confMesh.setMatrixAt(i, d.matrix); }
      this.confMesh.instanceMatrix.needsUpdate = true; if (!alive) this.confActive = false; }
    // coins
    const L = this.coinList; if (L.length) { const d = this.dummy; let n = 0; for (let i = 0; i < L.length; i++) { const k = L[i]; k.t += dt; if (k.t < 0) continue; const u = Math.min(1, k.t / k.dur); const e = u * u * (3 - 2 * u); d.position.lerpVectors(k.from, k.to, e); d.position.addScaledVector(k.off, Math.sin(u * Math.PI)); d.position.y += Math.sin(u * Math.PI) * k.hop; d.rotation.set(tm * 9 + i, 0, tm * 7); d.scale.setScalar(1); d.updateMatrix(); this.coinMesh.setMatrixAt(n++, d.matrix); if (u >= 1) { k.fin = true; } }
      this.coinMesh.count = n; this.coinMesh.instanceMatrix.needsUpdate = true; for (let i = L.length - 1; i >= 0; i--) if (L[i].fin) { const k = L.splice(i, 1)[0]; k.done(); } if (!L.length) this.coinMesh.count = 0; }
  }
  render() { if (this.lite) this.renderer.render(this.scene, this.camera); else this.composer.render(); }
}
