import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

export const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
export const lerp = (a, b, t) => a + (b - a) * t;
export const damp = (a, b, l, dt) => a + (b - a) * (1 - Math.exp(-l * dt));
export const angDiff = (a, b) => { let d = (b - a) % (Math.PI * 2); if (d > Math.PI) d -= Math.PI * 2; if (d < -Math.PI) d += Math.PI * 2; return d; };
export function rng(seed) { let a = seed >>> 0; return () => { a |= 0; a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

// ---------- save ----------
const KEY = 'blockypark.v1';
const DEFAULTS = () => ({
  coins: 120, name: '', avatar: { skin: 2, face: 'smile', shirt: 5, pattern: 'none', pants: 1, hat: 'none', pack: 'none', trail: 'none' },
  owned: { face: ['smile'], pattern: ['none'], hat: ['none'], pack: ['none'], trail: ['none'] },
  obby: { best: 0, cp: 0, wins: 0 }, tycoon: { cash: 0, total: 0, drop: [1, 0, 0, 0, 0, 0], tap: 0, belt: 0, mult: 0, auto: 0, last: 0 },
  build: [], daily: { last: '', streak: 0 }, ach: {}, stats: { coinsPicked: 0, emotes: 0, jumps: 0, waves: 0 },
  best: { tagTime: 0, tagWins: 0, race: 0, raceWins: 0 }, muted: false, played: false,
});
function merge(d, s) { if (s && typeof s === 'object') for (const k in d) { if (k in s) { if (d[k] && typeof d[k] === 'object' && !Array.isArray(d[k])) merge(d[k], s[k]); else d[k] = s[k]; } } return d; }
export const Save = {
  data: DEFAULTS(), _t: 0,
  load() { try { const s = localStorage.getItem(KEY); if (s) merge(this.data, JSON.parse(s)); } catch (e) {} return this.data; },
  save() { clearTimeout(this._t); this._t = setTimeout(() => this.flush(), 250); },
  flush() { try { localStorage.setItem(KEY, JSON.stringify(this.data)); } catch (e) {} },
  reset() { this.data = DEFAULTS(); this.flush(); },
};
addEventListener('pagehide', () => Save.flush());
document.addEventListener('visibilitychange', () => { if (document.hidden) Save.flush(); });

// ---------- icons (24x24 paths) ----------
export const ICON = {
  heart: 'M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z',
  star: 'M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z',
  smile: 'M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM8.5 8a1.5 1.5 0 110 3 1.5 1.5 0 010-3zm7 0a1.5 1.5 0 110 3 1.5 1.5 0 010-3zM12 18c-2.28 0-4.22-1.66-5-4h10c-.78 2.34-2.72 4-5 4z',
  note: 'M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z',
  hand: 'M23 5.5V20c0 2.2-1.8 4-4 4h-7.3c-1.08 0-2.1-.43-2.85-1.19L1 14.83s1.26-1.23 1.3-1.25c.22-.19.49-.29.79-.29.22 0 .42.06.6.16.04.01 4.31 2.46 4.31 2.46V4c0-.83.67-1.5 1.5-1.5S11 3.17 11 4v7h1V1.5c0-.83.67-1.5 1.5-1.5S15 .67 15 1.5V11h1V2.5c0-.83.67-1.5 1.5-1.5S19 1.67 19 2.5V11h1V5.5c0-.83.67-1.5 1.5-1.5s1.5.67 1.5 1.5z',
  sparkle: 'M12 1l2.6 8.4L23 12l-8.4 2.6L12 23l-2.6-8.4L1 12l8.4-2.6z',
  coin: 'M12 2a10 10 0 100 20 10 10 0 000-20zm0 3.2a6.8 6.8 0 110 13.6 6.8 6.8 0 010-13.6zM11 8v1.1c-1.2.2-2 .9-2 2 0 1.3 1 1.7 2.4 2.1 1 .3 1.1.5 1.1.8 0 .4-.4.6-1 .6-.7 0-1.1-.3-1.2-.8H8.9c.1 1.1.9 1.8 2.1 2V17h1.8v-1.2c1.3-.2 2.1-.9 2.1-2 0-1.4-1.1-1.8-2.5-2.2-.9-.3-1-.4-1-.7 0-.3.3-.5.8-.5s.9.3 1 .7h1.6c-.1-1-.8-1.7-1.9-1.9V8z',
  jump: 'M12 3l-8 9h5v9h6v-9h5z',
  menu: 'M6 4h4v16H6zM14 4h4v16h-4z',
  shirt: 'M16 3l5 3-2 4-3-1v12H8V9l-3 1-2-4 5-3c.5 1.7 2 2.5 4 2.5s3.5-.8 4-2.5z',
  home: 'M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z',
  vol: 'M3 9v6h4l5 5V4L7 9H3zm13.5 3A4.5 4.5 0 0014 7.97v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z',
  mute: 'M16.5 12A4.5 4.5 0 0014 7.97v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51A8.8 8.8 0 0021 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06a8.99 8.99 0 003.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z',
  gift: 'M20 6h-2.18c.11-.31.18-.65.18-1 0-1.66-1.34-3-3-3-1.05 0-1.96.54-2.5 1.35l-.5.67-.5-.67C11.96 2.54 11.05 2 10 2 8.34 2 7 3.34 7 5c0 .35.07.69.18 1H5c-1.11 0-1.99.89-1.99 2L3 19c0 1.11.89 2 2 2h15c1.11 0 2-.89 2-2V8c0-1.11-.89-2-2-2zm-5-2c.55 0 1 .45 1 1s-.45 1-1 1-1-.45-1-1 .45-1 1-1zM9 4c.55 0 1 .45 1 1s-.45 1-1 1-1-.45-1-1 .45-1 1-1z',
  trophy: 'M19 5h-2V3H7v2H5c-1.1 0-2 .9-2 2v1c0 2.55 1.92 4.63 4.39 4.94.63 1.5 1.98 2.63 3.61 2.96V19H7v2h10v-2h-4v-3.1c1.63-.33 2.98-1.46 3.61-2.96C19.08 12.63 21 10.55 21 8V7c0-1.1-.9-2-2-2zM5 8V7h2v3.82C5.84 10.4 5 9.3 5 8zm14 0c0 1.3-.84 2.4-2 2.82V7h2v1z',
  lock: 'M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z',
  check: 'M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z',
  close: 'M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z',
  play: 'M8 5v14l11-7z', undo: 'M12.5 8c-2.65 0-5.05.99-6.9 2.6L2 7v9h9l-3.62-3.62c1.39-1.16 3.16-1.88 5.12-1.88 3.54 0 6.55 2.31 7.6 5.5l2.37-.78C21.08 11.03 17.15 8 12.5 8z',
  eraser: 'M16.24 3.56l4.95 4.94c.78.79.78 2.05 0 2.84L12 20.53a4.008 4.008 0 01-5.66 0L2.81 17c-.78-.79-.78-2.05 0-2.84l10.6-10.6c.79-.78 2.05-.78 2.83 0zM4.22 15.58l3.54 3.53c.78.79 2.04.79 2.83 0l3.53-3.53-4.95-4.95-4.95 4.95z',
  dice: 'M19 3H5a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2V5a2 2 0 00-2-2zM7.5 18a1.5 1.5 0 110-3 1.5 1.5 0 010 3zm0-9a1.5 1.5 0 110-3 1.5 1.5 0 010 3zm4.5 4.5a1.5 1.5 0 110-3 1.5 1.5 0 010 3zm4.5 4.5a1.5 1.5 0 110-3 1.5 1.5 0 010 3zm0-9a1.5 1.5 0 110-3 1.5 1.5 0 010 3z',
  bolt: 'M7 2v11h3v9l7-12h-4l4-8z', flag: 'M14.4 6L14 4H5v17h2v-7h5.6l.4 2h7V6z', ice: 'M12 2l2.5 4.5L19 5l-1.5 4.5L22 12l-4.5 2.5L19 19l-4.5-1.5L12 22l-2.5-4.5L5 19l1.5-4.5L2 12l4.5-2.5L5 5l4.5 1.5z',
};
export const svg = (name, cls = 'i') => `<svg class="${cls}" viewBox="0 0 24 24"><path d="${ICON[name]}"/></svg>`;

// ---------- textures / sprites ----------
const iconTex = {};
export function iconTexture(name, color = '#fff') {
  const k = name + color; if (iconTex[k]) return iconTex[k];
  const c = document.createElement('canvas'); c.width = c.height = 128; const g = c.getContext('2d');
  g.fillStyle = 'rgba(255,255,255,.95)'; g.beginPath(); g.arc(64, 64, 60, 0, 7); g.fill();
  g.lineWidth = 6; g.strokeStyle = 'rgba(0,0,0,.12)'; g.stroke();
  g.translate(64, 64); g.scale(3.3, 3.3); g.translate(-12, -12); g.fillStyle = color; g.fill(new Path2D(ICON[name]));
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return (iconTex[k] = t);
}
export function textSprite(text, o = {}) {
  const px = o.px || 56, pad = px * 0.45;
  const c = document.createElement('canvas'), g = c.getContext('2d');
  const font = `900 ${px}px ui-rounded,"SF Pro Rounded",system-ui,-apple-system,"Segoe UI",sans-serif`;
  g.font = font; const w = Math.ceil(g.measureText(text).width + pad * 2), h = Math.ceil(px * 1.5);
  c.width = w; c.height = h; g.font = font; g.textAlign = 'center'; g.textBaseline = 'middle';
  if (o.bg !== null) { g.fillStyle = o.bg || 'rgba(20,24,50,.55)'; g.beginPath(); g.roundRect(0, 4, w, h - 8, (h - 8) / 2); g.fill(); }
  g.lineWidth = px * 0.16; g.strokeStyle = o.stroke || 'rgba(0,0,0,.35)'; g.lineJoin = 'round'; if (o.bg === null) g.strokeText(text, w / 2, h / 2 + 2);
  g.fillStyle = o.color || '#fff'; g.fillText(text, w / 2, h / 2 + 2);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4;
  const m = new THREE.SpriteMaterial({ map: t, transparent: true, depthWrite: false, fog: false });
  const s = new THREE.Sprite(m); const sc = (o.size || 0.55) / h; s.scale.set(w * sc, h * sc, 1); s.userData.tex = t; return s;
}

// ---------- merged static geometry builder with vertex colours ----------
const _unit = new THREE.BoxGeometry(1, 1, 1).toNonIndexed();
const _m4 = new THREE.Matrix4(), _q = new THREE.Quaternion(), _v = new THREE.Vector3(), _s = new THREE.Vector3(), _c = new THREE.Color(), _e = new THREE.Euler();
export class Batch {
  constructor() { this.p = []; this.n = []; this.c = []; this.jit = 0; }
  addGeo(geo, color, m4, jit = 0) {
    const g = geo.index ? geo.toNonIndexed() : geo.clone();
    g.applyMatrix4(m4);
    const pa = g.attributes.position.array, na = g.attributes.normal.array, cnt = pa.length / 3;
    _c.set(color); const j = jit ? (Math.random() - 0.5) * jit : 0;
    for (let i = 0; i < cnt; i++) {
      const ny = na[i * 3 + 1], nx = na[i * 3];
      const sh = (ny > 0.6 ? 1 : ny < -0.6 ? 0.55 : 0.82 + nx * 0.07) + j;
      this.c.push(_c.r * sh, _c.g * sh, _c.b * sh);
    }
    for (let i = 0; i < pa.length; i++) { this.p.push(pa[i]); this.n.push(na[i]); }
    g.dispose();
  }
  box(cx, cy, cz, w, h, d, color, jit = 0) { _m4.makeScale(w, h, d); _m4.setPosition(cx, cy, cz); this.addGeo(_unit, color, _m4, jit); }
  boxR(cx, cy, cz, w, h, d, ry, color, jit = 0) { _e.set(0, ry, 0); _q.setFromEuler(_e); _v.set(cx, cy, cz); _s.set(w, h, d); _m4.compose(_v, _q, _s); this.addGeo(_unit, color, _m4, jit); }
  geo(geo, x, y, z, sx, sy, sz, color, ry = 0, jit = 0) { _e.set(0, ry, 0); _q.setFromEuler(_e); _v.set(x, y, z); _s.set(sx, sy, sz); _m4.compose(_v, _q, _s); this.addGeo(geo, color, _m4, jit); }
  build(mat, shadow = true) {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(this.p), 3));
    g.setAttribute('normal', new THREE.BufferAttribute(new Float32Array(this.n), 3));
    g.setAttribute('color', new THREE.BufferAttribute(new Float32Array(this.c), 3));
    g.computeBoundingSphere();
    const m = new THREE.Mesh(g, mat); m.castShadow = shadow; m.receiveShadow = true; return m;
  }
}
let _wm = null;
export function worldMat() { return _wm || (_wm = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.55, metalness: 0.0 })); }

// ---------- sky ----------
export function makeSky(top, mid, bot) {
  const mat = new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, fog: false,
    uniforms: { top: { value: new THREE.Color(top) }, mid: { value: new THREE.Color(mid) }, bot: { value: new THREE.Color(bot) } },
    vertexShader: 'varying vec3 vP; void main(){ vP = normalize(position); gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.); }',
    fragmentShader: 'uniform vec3 top,mid,bot; varying vec3 vP; void main(){ float h=vP.y; vec3 c = h>0. ? mix(mid, top, pow(h,0.6)) : mix(mid, bot, pow(-h,0.5)); gl_FragColor=vec4(c,1.);\n#include <colorspace_fragment>\n}',
  });
  const m = new THREE.Mesh(new THREE.SphereGeometry(400, 24, 16), mat); m.renderOrder = -10; m.frustumCulled = false; return m;
}
export function makeClouds(n, seed, rad = 220, y0 = 45, y1 = 90) {
  const r = rng(seed), b = new Batch(), col = 0xffffff;
  for (let i = 0; i < n; i++) {
    const a = r() * 6.283, d = 80 + r() * rad, x = Math.cos(a) * d, z = Math.sin(a) * d, y = y0 + r() * (y1 - y0), s = 6 + r() * 10;
    const parts = 3 + Math.floor(r() * 3);
    for (let k = 0; k < parts; k++) b.box(x + (k - parts / 2) * s * 0.6, y + (k % 2) * s * 0.12, z + (r() - 0.5) * s * 0.4, s * (0.7 + r() * 0.5), s * 0.38, s * (0.6 + r() * 0.3), col);
  }
  const mat = new THREE.MeshLambertMaterial({ vertexColors: true, fog: false, emissive: 0x9fb4d8, emissiveIntensity: 0.55 });
  const m = b.build(mat, false); m.receiveShadow = false; return m;
}
export function makeLights(scene, opts = {}) {
  const hemi = new THREE.HemisphereLight(opts.sky || 0xcfe9ff, opts.ground || 0x88c070, opts.hemi ?? 1.15); scene.add(hemi);
  const sun = new THREE.DirectionalLight(opts.sun || 0xfff1d6, opts.sunI ?? 2.1);
  sun.position.set(30, 50, 20); sun.castShadow = true; const sh = opts.shadow || 36;
  sun.shadow.mapSize.set(opts.map || 2048, opts.map || 2048);
  const c = sun.shadow.camera; c.left = -sh; c.right = sh; c.top = sh; c.bottom = -sh; c.near = 5; c.far = 140;
  sun.shadow.bias = -0.0004; sun.shadow.normalBias = 0.04;
  scene.add(sun); scene.add(sun.target);
  return { hemi, sun, follow(x, y, z) { sun.target.position.set(x, y, z); sun.position.set(x + 30, y + 50, z + 20); } };
}
