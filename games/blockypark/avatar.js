import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { ICON, iconTexture, textSprite, clamp, damp } from './util.js';

export const SKINS = [0xffdbb4, 0xf5c28f, 0xe0a070, 0xc68642, 0x8d5524, 0x5c3a1e, 0xffd1dc, 0xa8e6cf, 0xb5a7ff, 0x9fd8ff];
export const SHIRTS = [0xff5a5f, 0xff9f1c, 0xffd23f, 0x7ed957, 0x2ec4b6, 0x3d9bff, 0x7c5cff, 0xff6fb5, 0xffffff, 0x2b2d42, 0xb5651d, 0x00c9a7];
export const PANTS = [0x3b4cca, 0x2b2d42, 0x6a994e, 0xc1121f, 0xf4a261, 0x7b2cbf, 0xe9e9ef, 0x118ab2];
export const ITEMS = {
  face: [{ id: 'smile', name: 'Smile', price: 0 }, { id: 'happy', name: 'Happy', price: 0 }, { id: 'wink', name: 'Wink', price: 20 }, { id: 'wow', name: 'Wow', price: 30 }, { id: 'cool', name: 'Cool', price: 60 }, { id: 'silly', name: 'Silly', price: 60 }, { id: 'stars', name: 'Starry', price: 90 }],
  pattern: [{ id: 'none', name: 'Plain', price: 0 }, { id: 'stripe', name: 'Stripe', price: 30 }, { id: 'star', name: 'Star', price: 50 }, { id: 'heart', name: 'Heart', price: 50 }, { id: 'bolt', name: 'Bolt', price: 70 }, { id: 'dots', name: 'Dots', price: 70 }],
  hat: [{ id: 'none', name: 'No hat', price: 0 }, { id: 'cap', name: 'Cap', price: 60 }, { id: 'cat', name: 'Kitty', price: 90 }, { id: 'bunny', name: 'Bunny', price: 90 }, { id: 'phones', name: 'Beats', price: 120 }, { id: 'party', name: 'Party', price: 120 }, { id: 'prop', name: 'Propeller', price: 150 }, { id: 'wizard', name: 'Wizard', price: 200 }, { id: 'tophat', name: 'Top hat', price: 220 }, { id: 'halo', name: 'Halo', price: 260 }, { id: 'crown', name: 'Crown', price: 400 }],
  pack: [{ id: 'none', name: 'None', price: 0 }, { id: 'bag', name: 'Backpack', price: 70 }, { id: 'cape', name: 'Cape', price: 140 }, { id: 'shell', name: 'Shell', price: 160 }, { id: 'wings', name: 'Wings', price: 240 }, { id: 'jet', name: 'Jetpack', price: 320 }],
  trail: [{ id: 'none', name: 'None', price: 0 }, { id: 'sparkle', name: 'Sparkles', price: 100 }, { id: 'bubbles', name: 'Bubbles', price: 140 }, { id: 'hearts', name: 'Hearts', price: 180 }, { id: 'stars', name: 'Stars', price: 220 }, { id: 'rainbow', name: 'Rainbow', price: 300 }],
};
export const TRAIL_COL = { sparkle: [0xfff6a0, 0xffffff], bubbles: [0x9fe8ff, 0xd8f6ff], hearts: [0xff7aa8, 0xff4f86], stars: [0xffd23f, 0xffb703], rainbow: [0xff5a5f, 0xffd23f, 0x7ed957, 0x3d9bff, 0x9b5cff] };

// ---- caches ----
const gcache = new Map(), mcache = new Map();
function rb(w, h, d, r = 0.06) { const k = [w, h, d, r].join(); let g = gcache.get(k); if (!g) { g = new RoundedBoxGeometry(w, h, d, 2, r); gcache.set(k, g); } return g; }
function bx(w, h, d) { const k = 'b' + [w, h, d].join(); let g = gcache.get(k); if (!g) { g = new THREE.BoxGeometry(w, h, d); gcache.set(k, g); } return g; }
function mat(color, rough = 0.42, extra) { const k = color + '|' + rough + '|' + (extra ? JSON.stringify(extra) : ''); let m = mcache.get(k); if (!m) { m = new THREE.MeshStandardMaterial(Object.assign({ color, roughness: rough, metalness: 0 }, extra)); mcache.set(k, m); } return m; }
function part(geo, m, x, y, z, parent) { const o = new THREE.Mesh(geo, m); o.position.set(x, y, z); o.castShadow = true; if (parent) parent.add(o); return o; }

// ---- decal textures ----
const dtex = new Map();
function canvasTex(key, fn) { let t = dtex.get(key); if (t) return t; const c = document.createElement('canvas'); c.width = c.height = 128; const g = c.getContext('2d'); fn(g); t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4; dtex.set(key, t); return t; }
const INK = '#2a1d3a';
function faceTex(id) {
  return canvasTex('f' + id, (g) => {
    g.lineCap = 'round'; g.lineJoin = 'round'; g.fillStyle = INK; g.strokeStyle = INK; g.lineWidth = 8;
    const eye = (x, y) => { g.beginPath(); g.ellipse(x, y, 9, 13, 0, 0, 7); g.fill(); g.fillStyle = '#fff'; g.beginPath(); g.arc(x + 3, y - 5, 3.5, 0, 7); g.fill(); g.fillStyle = INK; };
    const smile = (open) => { g.beginPath(); if (open) { g.moveTo(40, 80); g.quadraticCurveTo(64, 112, 88, 80); g.closePath(); g.fillStyle = INK; g.fill(); g.fillStyle = '#ff6f91'; g.beginPath(); g.ellipse(64, 92, 10, 6, 0, 0, 7); g.fill(); g.fillStyle = INK; } else { g.moveTo(42, 82); g.quadraticCurveTo(64, 104, 86, 82); g.stroke(); } };
    if (id !== 'cool' && id !== 'stars') { g.fillStyle = 'rgba(255,110,140,.45)'; g.beginPath(); g.ellipse(26, 78, 11, 7, 0, 0, 7); g.ellipse(102, 78, 11, 7, 0, 0, 7); g.fill(); g.fillStyle = INK; }
    if (id === 'smile') { eye(40, 56); eye(88, 56); smile(false); }
    else if (id === 'happy') { g.beginPath(); g.moveTo(28, 62); g.quadraticCurveTo(40, 40, 52, 62); g.moveTo(76, 62); g.quadraticCurveTo(88, 40, 100, 62); g.stroke(); smile(true); }
    else if (id === 'wink') { eye(40, 56); g.beginPath(); g.moveTo(76, 58); g.quadraticCurveTo(88, 44, 100, 58); g.stroke(); smile(false); }
    else if (id === 'wow') { eye(40, 54); eye(88, 54); g.beginPath(); g.ellipse(64, 92, 10, 13, 0, 0, 7); g.fill(); }
    else if (id === 'cool') { g.fillStyle = '#15121f'; g.beginPath(); g.roundRect(18, 38, 40, 28, 8); g.roundRect(70, 38, 40, 28, 8); g.fill(); g.fillRect(56, 44, 16, 6); g.fillStyle = 'rgba(255,255,255,.35)'; g.fillRect(24, 42, 12, 5); g.fillRect(76, 42, 12, 5); g.fillStyle = INK; smile(true); }
    else if (id === 'silly') { eye(38, 54); g.beginPath(); g.arc(90, 54, 14, 0, 7); g.fillStyle = '#fff'; g.fill(); g.lineWidth = 5; g.stroke(); g.fillStyle = INK; g.beginPath(); g.arc(93, 54, 6, 0, 7); g.fill(); g.beginPath(); g.moveTo(40, 82); g.quadraticCurveTo(64, 98, 88, 80); g.lineWidth = 8; g.stroke(); g.fillStyle = '#ff6f91'; g.beginPath(); g.roundRect(58, 84, 22, 24, 10); g.fill(); g.lineWidth = 4; g.stroke(); }
    else if (id === 'stars') { const star = (x, y) => { g.fillStyle = '#ffd23f'; g.strokeStyle = '#b8770a'; g.lineWidth = 4; g.beginPath(); for (let i = 0; i < 10; i++) { const r = i % 2 ? 7 : 17, a = -Math.PI / 2 + i * Math.PI / 5; g.lineTo(x + Math.cos(a) * r, y + Math.sin(a) * r); } g.closePath(); g.fill(); g.stroke(); }; star(38, 54); star(90, 54); g.strokeStyle = INK; g.lineWidth = 8; smile(true); }
  });
}
function patTex(id) {
  return canvasTex('p' + id, (g) => {
    g.lineJoin = 'round';
    if (id === 'stripe') { g.fillStyle = 'rgba(255,255,255,.85)'; g.fillRect(0, 34, 128, 22); g.fillRect(0, 76, 128, 22); }
    else if (id === 'star') { g.fillStyle = '#ffd23f'; g.strokeStyle = '#c98a00'; g.lineWidth = 5; g.beginPath(); for (let i = 0; i < 10; i++) { const r = i % 2 ? 24 : 54, a = -Math.PI / 2 + i * Math.PI / 5; g.lineTo(64 + Math.cos(a) * r, 66 + Math.sin(a) * r); } g.closePath(); g.fill(); g.stroke(); }
    else if (id === 'heart') { g.save(); g.translate(64, 64); g.scale(4, 4); g.translate(-12, -12); g.fillStyle = '#ff5c8a'; g.fill(new Path2D(ICON.heart)); g.restore(); }
    else if (id === 'bolt') { g.save(); g.translate(64, 64); g.scale(4.4, 4.4); g.translate(-12, -12); g.fillStyle = '#ffe14a'; g.strokeStyle = '#c98a00'; g.lineWidth = 0.8; g.fill(new Path2D(ICON.bolt)); g.stroke(new Path2D(ICON.bolt)); g.restore(); }
    else if (id === 'dots') { g.fillStyle = 'rgba(255,255,255,.85)'; for (let y = 0; y < 3; y++) for (let x = 0; x < 3; x++) { g.beginPath(); g.arc(24 + x * 40 + (y % 2) * 8, 24 + y * 40, 11, 0, 7); g.fill(); } }
  });
}
const dm = new Map();
const decalMat = (t) => { let m = dm.get(t.uuid); if (!m) { m = new THREE.MeshStandardMaterial({ map: t, transparent: true, depthWrite: false, roughness: 0.7, polygonOffset: true, polygonOffsetFactor: -2 }); dm.set(t.uuid, m); } return m; };
const planeG = new THREE.PlaneGeometry(1, 1);

// ---- hats / packs ----
function buildHat(id, g) {
  const M = (c, r) => mat(c, r ?? 0.5), Y = 0;
  switch (id) {
    case 'cap': part(rb(0.7, 0.2, 0.7, 0.08), M(0xe63946), 0, 0.08, 0, g); part(rb(0.5, 0.06, 0.34, 0.03), M(0xb5202e), 0, 0.0, 0.46, g); part(bx(0.12, 0.05, 0.12), M(0xffffff), 0, 0.2, 0, g); break;
    case 'cat': part(rb(0.7, 0.08, 0.7, 0.03), M(0x2b2d42), 0, 0.0, 0, g); for (const s of [-1, 1]) { const e = part(bx(0.2, 0.26, 0.1), M(0x2b2d42), s * 0.22, 0.2, 0, g); e.rotation.z = -s * 0.2; part(bx(0.1, 0.16, 0.06), M(0xff9ebd), s * 0.22, 0.19, 0.04, g).rotation.z = -s * 0.2; } break;
    case 'bunny': part(rb(0.66, 0.1, 0.66, 0.04), M(0xffffff), 0, -0.01, 0, g); for (const s of [-1, 1]) { part(rb(0.16, 0.62, 0.1, 0.05), M(0xffffff), s * 0.18, 0.4, 0, g).rotation.z = -s * 0.12; part(rb(0.08, 0.46, 0.06, 0.03), M(0xffb3c7), s * 0.18, 0.4, 0.04, g).rotation.z = -s * 0.12; } break;
    case 'phones': { const arc = new THREE.Mesh(new THREE.TorusGeometry(0.4, 0.045, 6, 16, Math.PI), M(0x2b2d42)); arc.position.set(0, -0.12, 0); arc.castShadow = true; g.add(arc); for (const s of [-1, 1]) part(rb(0.14, 0.3, 0.3, 0.05), M(0xff4f86), s * 0.4, -0.2, 0, g); break; }
    case 'party': { const c = new THREE.Mesh(new THREE.ConeGeometry(0.26, 0.6, 12), M(0xff6fb5)); c.position.y = 0.3; c.castShadow = true; g.add(c); part(new THREE.SphereGeometry(0.07, 8, 6), M(0xffd23f), 0, 0.62, 0, g); for (let i = 0; i < 3; i++) part(new THREE.BoxGeometry(0.4 - i * 0.1, 0.05, 0.4 - i * 0.1), M(i % 2 ? 0x3d9bff : 0xffd23f), 0, 0.12 + i * 0.16, 0, g).visible = false; break; }
    case 'prop': part(rb(0.62, 0.22, 0.62, 0.1), M(0x3d9bff), 0, 0.08, 0, g); part(bx(0.04, 0.12, 0.04), M(0x555555), 0, 0.24, 0, g); const p = new THREE.Group(); p.position.y = 0.32; p.name = 'prop'; g.add(p); part(bx(0.7, 0.03, 0.12), M(0xff5a5f), 0, 0, 0, p); part(bx(0.12, 0.03, 0.7), M(0xffd23f), 0, 0, 0, p); break;
    case 'wizard': { const c = new THREE.Mesh(new THREE.ConeGeometry(0.34, 0.8, 4), M(0x5b3cc4)); c.position.y = 0.4; c.rotation.y = Math.PI / 4; c.castShadow = true; g.add(c); part(rb(0.86, 0.06, 0.86, 0.02), M(0x4a2fa8), 0, 0.0, 0, g); part(new THREE.SphereGeometry(0.08, 8, 6), M(0xffd23f, 0.2), 0.0, 0.5, 0.2, g); break; }
    case 'tophat': part(rb(0.9, 0.06, 0.9, 0.02), M(0x1d1d2b), 0, 0, 0, g); part(rb(0.56, 0.52, 0.56, 0.04), M(0x1d1d2b), 0, 0.28, 0, g); part(bx(0.58, 0.1, 0.58), M(0xe63946), 0, 0.12, 0, g); break;
    case 'halo': { const t = new THREE.Mesh(new THREE.TorusGeometry(0.28, 0.05, 8, 20), mat(0xffe27a, 0.3, { emissive: 0xffc83d, emissiveIntensity: 0.9 })); t.rotation.x = Math.PI / 2; t.position.y = 0.3; t.name = 'halo'; g.add(t); break; }
    case 'crown': { const gm = mat(0xffd23f, 0.25, { metalness: 0.5 }); part(rb(0.62, 0.16, 0.62, 0.05), gm, 0, 0.06, 0, g); for (const [x, z] of [[-.24, -.24], [.24, -.24], [-.24, .24], [.24, .24], [0, 0]]) { part(bx(0.12, 0.2, 0.12), gm, x, 0.22, z, g); part(new THREE.SphereGeometry(0.06, 8, 6), mat([0xff4f86, 0x3d9bff, 0x7ed957, 0xff4f86, 0xffffff][(x * 10 + z * 10 + 5 | 0) % 5] || 0xff4f86, 0.2), x, 0.36, z, g); } break; }
  }
}
function buildPack(id, g) {
  const M = (c, r) => mat(c, r ?? 0.5);
  switch (id) {
    case 'bag': part(rb(0.46, 0.5, 0.22, 0.07), M(0xff9f1c), 0, 0, -0.13, g); part(rb(0.36, 0.2, 0.06, 0.03), M(0xe07b00), 0, -0.08, -0.26, g); break;
    case 'cape': { const c = part(rb(0.62, 0.9, 0.06, 0.02), M(0xe63946), 0, -0.14, -0.2, g); c.name = 'cape'; c.geometry = bx(0.62, 0.9, 0.05); part(bx(0.7, 0.1, 0.1), M(0xffd23f), 0, 0.3, -0.18, g); break; }
    case 'shell': part(rb(0.62, 0.56, 0.3, 0.14), M(0x3fae5a), 0, -0.02, -0.22, g); part(rb(0.4, 0.36, 0.1, 0.06), M(0x2d8a45), 0, -0.02, -0.38, g); break;
    case 'wings': for (const s of [-1, 1]) { const w = new THREE.Group(); w.position.set(s * 0.12, 0.12, -0.2); w.name = s < 0 ? 'wingL' : 'wingR'; g.add(w); part(rb(0.6, 0.16, 0.05, 0.02), M(0xffffff, 0.35), s * 0.3, 0.1, 0, w).rotation.z = s * 0.35; part(rb(0.44, 0.14, 0.05, 0.02), M(0xdff3ff, 0.35), s * 0.28, -0.08, 0, w).rotation.z = s * 0.25; } break;
    case 'jet': for (const s of [-1, 1]) { const c = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, 0.5, 10), M(0xc9d3e0, 0.25)); c.position.set(s * 0.15, -0.02, -0.22); c.castShadow = true; g.add(c); part(new THREE.CylinderGeometry(0.06, 0.1, 0.1, 10), M(0xff5a5f), s * 0.15, -0.3, -0.22, g); const f = part(new THREE.ConeGeometry(0.07, 0.24, 8), mat(0xffa500, 0.5, { emissive: 0xff7a00, emissiveIntensity: 1 }), s * 0.15, -0.46, -0.22, g); f.rotation.x = Math.PI; f.name = 'flame'; } break;
  }
}

// ---- builder ----
export function buildAvatar(cfg) {
  const root = new THREE.Group(), body = new THREE.Group(); root.add(body);
  const skin = SKINS[cfg.skin % SKINS.length], shirt = SHIRTS[cfg.shirt % SHIRTS.length], pants = PANTS[cfg.pants % PANTS.length];
  const A = { root, body, cfg, emote: null, emT: 0, phase: Math.random() * 6, squash: 0, seated: false, bubbleT: 0, t: 0 };
  // legs (pivot at hip)
  A.legL = new THREE.Group(); A.legR = new THREE.Group();
  for (const [L, s] of [[A.legL, -1], [A.legR, 1]]) { L.position.set(s * 0.15, 0.52, 0); body.add(L); part(rb(0.26, 0.46, 0.28, 0.06), mat(pants, 0.5), 0, -0.23, 0, L); part(rb(0.28, 0.11, 0.36, 0.05), mat(0xffffff, 0.4), 0, -0.47, 0.03, L); }
  // torso
  const torso = part(rb(0.62, 0.64, 0.36, 0.09), mat(shirt, 0.45), 0, 0.84, 0, body); A.torso = torso;
  if (cfg.pattern !== 'none') { const d = new THREE.Mesh(planeG, decalMat(patTex(cfg.pattern))); d.scale.set(0.46, 0.46, 1); d.position.set(0, 0.86, 0.186); body.add(d); const d2 = d.clone(); d2.rotation.y = Math.PI; d2.position.z = -0.186; d2.visible = cfg.pattern === 'stripe' || cfg.pattern === 'dots'; body.add(d2); }
  // arms
  A.armL = new THREE.Group(); A.armR = new THREE.Group();
  for (const [Ar, s] of [[A.armL, -1], [A.armR, 1]]) { Ar.position.set(s * 0.42, 1.12, 0); body.add(Ar); part(rb(0.22, 0.32, 0.24, 0.07), mat(shirt, 0.45), 0, -0.14, 0, Ar); part(rb(0.19, 0.3, 0.2, 0.07), mat(skin, 0.45), 0, -0.4, 0, Ar); }
  // head
  A.head = new THREE.Group(); A.head.position.set(0, 1.48, 0); body.add(A.head);
  part(rb(0.66, 0.64, 0.64, 0.15), mat(skin, 0.4), 0, 0, 0, A.head);
  const f = new THREE.Mesh(planeG, decalMat(faceTex(cfg.face))); f.scale.set(0.54, 0.54, 1); f.position.set(0, -0.02, 0.322); A.head.add(f);
  // hat
  A.hat = new THREE.Group(); A.hat.position.set(0, 0.3, 0); A.head.add(A.hat); buildHat(cfg.hat, A.hat);
  A.prop = A.hat.getObjectByName('prop'); A.halo = A.hat.getObjectByName('halo');
  // pack
  A.pack = new THREE.Group(); A.pack.position.set(0, 0.86, 0); body.add(A.pack); buildPack(cfg.pack, A.pack);
  A.wingL = A.pack.getObjectByName('wingL'); A.wingR = A.pack.getObjectByName('wingR'); A.cape = A.pack.getObjectByName('cape');
  A.flames = []; A.pack.traverse((o) => { if (o.name === 'flame') A.flames.push(o); });
  // shadow blob handled by real shadows; name tag / bubble added lazily
  return A;
}

export function setSeated(A, on) { A.seated = on; }

export function showBubble(A, icon) {
  if (!A.bubble) { A.bubble = new THREE.Sprite(new THREE.SpriteMaterial({ transparent: true, depthWrite: false, depthTest: false, fog: false })); A.bubble.scale.set(0.8, 0.8, 1); A.bubble.renderOrder = 20; A.root.add(A.bubble); }
  const colors = { heart: '#ff4f86', star: '#ffb703', smile: '#ffa400', note: '#7c5cff', hand: '#ff9f1c', sparkle: '#2ec4b6' };
  A.bubble.material.map = iconTexture(icon, colors[icon] || '#f90'); A.bubble.material.needsUpdate = true; A.bubble.visible = true; A.bubbleT = 2.2; A.bubble.position.set(0, 2.5, 0);
}
export function addNameTag(A, name) { if (A.tag) return; A.tag = textSprite(name, { px: 44, size: 0.36 }); A.tag.position.set(0, 2.2, 0); A.tag.material.depthTest = true; A.root.add(A.tag); }

export const EMOTES = [
  { id: 'wave', icon: 'hand', anim: 'wave', label: 'Wave' }, { id: 'dance', icon: 'note', anim: 'dance', label: 'Dance' }, { id: 'heart', icon: 'heart', anim: 'cheer', label: 'Love' },
  { id: 'star', icon: 'star', anim: 'spin', label: 'Spin' }, { id: 'laugh', icon: 'smile', anim: 'laugh', label: 'Haha' }, { id: 'sparkle', icon: 'sparkle', anim: 'cheer', label: 'Yay' },
];
export function playEmote(A, e) { A.emote = e.anim; A.emT = 0; showBubble(A, e.icon); }

// st: {speed, air, vy}
export function updateAvatar(A, dt, speed, air, vy) {
  A.t += dt; const t = A.t;
  const run = clamp(speed / 9, 0, 1.3);
  if (run > 0.15 && !A.seated) A.emote = null;
  if (A.emote) A.emT += dt;
  if (A.emote && A.emT > 2.4) A.emote = null;
  A.phase += dt * (6 + run * 7) * (run > 0.05 ? 1 : 0);
  const sw = Math.sin(A.phase) * run * 0.95;
  let aL = -sw * 0.9, aR = sw * 0.9, lL = sw, lR = -sw, by = 0, ry = 0, hx = 0, tz = 0;
  const idle = Math.sin(t * 2.4) * 0.04;
  if (!air && run <= 0.15) { aL = idle * 2 + 0.05; aR = -idle * 2 - 0.05; lL = lR = 0; }
  if (air) { const up = clamp(vy / 14, -1, 1); aL = -(1.2 + up * 0.5); aR = -(1.2 + up * 0.5); lL = 0.5; lR = -0.4; }
  let armLz = 0.06, armRz = -0.06;
  if (run > 0.5 && !air) by = Math.abs(Math.sin(A.phase)) * 0.06;
  switch (A.emote) {
    case 'wave': armRz = -(2.5 + Math.sin(A.emT * 14) * 0.4); aR = 0; aL = 0; break;
    case 'dance': { const s = Math.sin(A.emT * 9); by = Math.abs(s) * 0.12; ry = s * 0.5; armLz = 2.2 + s * 0.4; armRz = -2.2 + s * 0.4; aL = aR = 0; lL = s * 0.5; lR = -s * 0.5; tz = s * 0.1; break; }
    case 'cheer': by = Math.abs(Math.sin(A.emT * 8)) * 0.35; armLz = 2.9; armRz = -2.9; aL = aR = 0; break;
    case 'spin': ry = A.emT * 9; by = Math.sin(Math.min(1, A.emT / 0.7) * Math.PI) * 0.25; armLz = 1.4; armRz = -1.4; aL = aR = 0; break;
    case 'laugh': by = Math.abs(Math.sin(A.emT * 14)) * 0.07; hx = Math.sin(A.emT * 14) * 0.15; armLz = 0.2; armRz = -0.2; aL = aR = -0.5; break;
  }
  if (A.seated) { lL = lR = -1.45; aL = aR = -0.9; by = 0; }
  A.armL.rotation.x = aL; A.armR.rotation.x = aR; A.armL.rotation.z = armLz; A.armR.rotation.z = armRz;
  A.legL.rotation.x = lL; A.legR.rotation.x = lR;
  A.body.position.y = by; A.body.rotation.y = ry; A.body.rotation.z = tz; A.head.rotation.z = hx;
  A.body.rotation.x = damp(A.body.rotation.x, run > 0.2 && !air ? 0.1 : 0, 10, dt);
  A.squash = damp(A.squash, 0, 9, dt); A.body.scale.set(1 + A.squash * 0.5, 1 - A.squash, 1 + A.squash * 0.5);
  if (A.prop) A.prop.rotation.y += dt * 18; if (A.halo) A.halo.position.y = 0.34 + Math.sin(t * 3) * 0.03;
  if (A.wingL) { const fl = Math.sin(t * (air ? 14 : 3)) * (air ? 0.6 : 0.12); A.wingL.rotation.y = -0.25 - fl; A.wingR.rotation.y = 0.25 + fl; }
  if (A.cape) A.cape.rotation.x = 0.1 + run * 0.5 + (air ? 0.2 : 0);
  for (const f of A.flames) { f.scale.y = air || run > 0.3 ? 0.9 + Math.sin(t * 30) * 0.3 : 0.4; }
  if (A.bubble && A.bubbleT > 0) { A.bubbleT -= dt; A.bubble.position.y = 2.5 + (2.2 - A.bubbleT) * 0.15; const k = clamp(A.bubbleT * 3, 0, 1); A.bubble.material.opacity = k; A.bubble.scale.setScalar(0.8 * (0.6 + 0.4 * clamp((2.2 - A.bubbleT) * 8, 0, 1)) ); if (A.bubbleT <= 0) A.bubble.visible = false; }
}

// ---- thumbnails (rendered with the main renderer, copied to a 2D canvas) ----
let tScene, tCam;
const thumbCache = new Map();
export function thumbnail(renderer, kind, id, cfg) {
  const key = kind + ':' + id + ':' + (kind === 'face' || kind === 'hat' ? cfg.skin : kind === 'pattern' ? cfg.shirt : kind === 'pack' ? cfg.shirt : '');
  if (thumbCache.has(key)) return thumbCache.get(key);
  const SZ = 144; const can = document.createElement('canvas'); can.width = can.height = SZ; const g = can.getContext('2d');
  if (kind === 'trail') {
    g.fillStyle = '#f3f0ff'; g.fillRect(0, 0, SZ, SZ); const cols = TRAIL_COL[id];
    if (cols) for (let i = 0; i < 14; i++) { const x = 20 + i * 8, y = 100 - i * 4 + Math.sin(i * 1.7) * 12; g.fillStyle = '#' + cols[i % cols.length].toString(16).padStart(6, '0'); g.globalAlpha = 0.45 + i / 28; g.beginPath(); g.arc(x, y, 5 + i * 0.5, 0, 7); g.fill(); }
    else { g.fillStyle = '#c9c4e6'; g.font = '700 40px system-ui'; g.textAlign = 'center'; g.fillText('-', 72, 84); }
    g.globalAlpha = 1; const url = can.toDataURL(); thumbCache.set(key, url); return url;
  }
  if (!tScene) { tScene = new THREE.Scene(); tScene.add(new THREE.HemisphereLight(0xffffff, 0xb5b0d0, 1.6)); const d = new THREE.DirectionalLight(0xffffff, 2.2); d.position.set(2, 4, 5); tScene.add(d); tCam = new THREE.PerspectiveCamera(30, 1, 0.1, 50); tScene.background = new THREE.Color(0xf3f0ff); }
  const c2 = Object.assign({}, cfg); if (kind !== 'skin') c2[kind] = id;
  if (kind === 'face' || kind === 'hat') { c2.pack = 'none'; } else if (kind === 'pack') { c2.hat = 'none'; } else { c2.hat = 'none'; c2.pack = 'none'; }
  const A = buildAvatar(c2); updateAvatar(A, 0.01, 0, false, 0); tScene.add(A.root);
  if (kind === 'pack') { A.root.rotation.y = Math.PI * 0.82; tCam.position.set(0, 1.0, 3.4); tCam.lookAt(0, 0.95, 0); }
  else if (kind === 'pattern') { A.root.rotation.y = -0.25; tCam.position.set(0, 0.95, 3.0); tCam.lookAt(0, 0.9, 0); }
  else { A.root.rotation.y = kind === 'face' ? 0 : -0.35; tCam.position.set(0, 1.75, kind === 'face' ? 2.5 : 3.1); tCam.lookAt(0, kind === 'face' ? 1.5 : 1.65, 0); }
  const pr = renderer.getPixelRatio(); const cv = renderer.domElement;
  renderer.setScissorTest(true); renderer.setViewport(0, 0, SZ, SZ); renderer.setScissor(0, 0, SZ, SZ); renderer.render(tScene, tCam);
  g.drawImage(cv, 0, cv.height - SZ * pr, SZ * pr, SZ * pr, 0, 0, SZ, SZ);
  renderer.setScissorTest(false);
  tScene.remove(A.root);
  const url = can.toDataURL(); thumbCache.set(key, url); return url;
}
