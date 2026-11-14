import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { Maestro } from '../shared/maestro.js';
import { Save, svg, clamp, lerp, damp, angDiff, makeSky, makeLights } from './util.js';
import { Input } from './input.js';
import { Particles, floatText } from './fx.js';
import { makeBody, rayBoxes } from './physics.js';
import { stepWalker, syncAvatar } from './player.js';
import { buildAvatar, updateAvatar, playEmote, EMOTES, ITEMS, SKINS, SHIRTS, PANTS, TRAIL_COL, thumbnail } from './avatar.js';
import { createHub } from './hub.js';
import { createObby } from './obby.js';
import { createTycoon } from './tycoon.js';
import { createTag } from './tag.js';
import { createRace } from './race.js';
import { createBuild } from './build.js';

const $ = (id) => document.getElementById(id);
const S = Save.load();
const errs = []; window.__errs = errs;
addEventListener('error', (e) => errs.push(String(e.message)));

// ---------- renderer ----------
const canvas = $('gl');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 2));
renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.NoToneMapping;
const camera = new THREE.PerspectiveCamera(52, 1, 0.1, 900);
let envTex = null;
try { const pm = new THREE.PMREMGenerator(renderer); envTex = pm.fromScene(new RoomEnvironment(), 0.04).texture; } catch (e) { errs.push('env ' + e); }

// ---------- audio ----------
const music = new Maestro();
music.setMuted(!!S.muted);

// ---------- input ----------
const input = new Input(canvas);
input.setJumpButton($('bJump'));

// ---------- player ----------
const P = { body: makeBody(0, 0, 10), avatar: null, face: Math.PI, stun: 0, speed: 0, trailT: 0, speedMul: 1 };
function rebuildAvatar() {
  const old = P.avatar; const parent = old && old.root.parent;
  P.avatar = buildAvatar(S.avatar); if (parent) parent.add(P.avatar.root); if (old && parent) parent.remove(old.root);
}
rebuildAvatar();
const NAMES_A = ['Happy', 'Zippy', 'Sunny', 'Bouncy', 'Cosmic', 'Fuzzy', 'Jolly', 'Lucky', 'Brave', 'Giggly', 'Snazzy', 'Turbo'];
const NAMES_B = ['Panda', 'Rocket', 'Pickle', 'Otter', 'Comet', 'Waffle', 'Tiger', 'Bunny', 'Robot', 'Dino', 'Koala', 'Muffin'];
const rollName = () => NAMES_A[(Math.random() * 12) | 0] + ' ' + NAMES_B[(Math.random() * 12) | 0];
if (!S.name) { S.name = rollName(); Save.save(); }

// ---------- camera rig ----------
const cam = { yaw: 0, pitch: 0.42, dist: 9, cur: 9, tgt: new THREE.Vector3(), minY: 0.5, free: false };

// ---------- game object ----------
const G = {
  THREE, renderer, camera, input, music, P, S, cam, state: 'title', zone: null, zones: {}, scene: null, fx: null, envTex,
  $, svg, floatText,
  addCoins(n, wx, wy, wz) {
    S.coins += n; Save.save(); refreshCoins(); G.pop(n > 0 ? '+' + n : '' + n, wx, wy, wz);
  },
  pop(text, wx, wy, wz, cls = '') {
    let x = innerWidth * 0.5, y = innerHeight * 0.4;
    if (wx !== undefined) { const p = G.project(wx, wy, wz); x = p.x; y = p.y; } else { const r = $('coinChip').getBoundingClientRect(); x = r.left + r.width / 2; y = r.bottom + 10; }
    floatText(text, x, y, cls);
  },
  project(x, y, z) { const v = G._v || (G._v = new THREE.Vector3()); v.set(x, y, z).project(camera); return { x: (v.x * 0.5 + 0.5) * innerWidth, y: (-v.y * 0.5 + 0.5) * innerHeight, behind: v.z > 1 }; },
  toast(msg, icon = 'star') { const t = document.createElement('div'); t.className = 'toast'; t.innerHTML = (icon ? svg(icon) : '') + '<span></span>'; t.lastChild.textContent = msg; $('toasts').appendChild(t); setTimeout(() => t.remove(), 2700); },
  banner(text) { const b = $('banner'); b.textContent = text; b.classList.remove('show'); void b.offsetWidth; b.classList.add('show'); },
  ach(id) { if (S.ach[id]) return; const a = ACH.find((x) => x.id === id); if (!a) return; S.ach[id] = 1; S.coins += a.reward; Save.save(); refreshCoins(); G.toast('Award: ' + a.name + '  +' + a.reward, 'trophy'); music.sfx('powerup'); },
  stat(k, n = 1) { S.stats[k] = (S.stats[k] || 0) + n; },
  sfx(n, o) { music.sfx(n, o); },
  zoneHud(html) { $('zoneHud').innerHTML = html || ''; },
  bottomBar(html) { $('bottomBar').innerHTML = html || ''; },
  playMusic(theme, intensity = 0.6) { music.play(theme, { intensity }); },
  walk(dt, cols, grid, o = {}) {
    P.jumpHeld = input.jump; const j = input.takeJump();
    stepWalker(P, dt, input.mx, input.my, cam.yaw, j, cols, grid, o);
    if (P.ev === 'jump') { music.sfx('jump', { volume: 0.7 }); G.stat('jumps'); G.ach('first_jump'); G.fx.burst(P.body.x, P.body.y + 0.1, P.body.z, 5, 0xffffff, 2, 0.4, 0.25, 6); }
    else if (P.ev === 'land') { music.sfx('step', { volume: 1.2 }); G.fx.burst(P.body.x, P.body.y + 0.1, P.body.z, 6, 0xf4efe0, 2.5, 0.4, 0.3, 6); }
    const bb = P.body; if (bb.onGround && bb.ground && bb.ground.bounce) {}
    if (bb.onGround && bb.ground && bb.ground.bounce) { bb.vy = bb.ground.bounce; bb.onGround = false; P.avatar.squash = -0.25; music.sfx('boing'); G.fx.burst(bb.x, bb.y, bb.z, 8, 0xff6f91, 3, 0.5, 0.3, 4); }
    syncAvatar(P, dt); G.trail(dt);
  },
  trail(dt) {
    const id = S.avatar.trail; if (id === 'none' || P.speed < 1.5) return; P.trailT -= dt; if (P.trailT > 0) return; P.trailT = 0.045;
    const cols = TRAIL_COL[id], b = P.body, c = cols[(Math.random() * cols.length) | 0];
    const big = id === 'hearts' || id === 'stars' ? 0.5 : id === 'bubbles' ? 0.45 : 0.3;
    G.fx.emit(b.x + (Math.random() - 0.5) * 0.4, b.y + 0.3 + Math.random() * 0.6, b.z + (Math.random() - 0.5) * 0.4, (Math.random() - 0.5) * 0.8, id === 'bubbles' ? 1.2 : 0.6, (Math.random() - 0.5) * 0.8, 0.8, c, big, id === 'bubbles' ? -0.5 : 1.5);
  },
  modal(html, handlers = {}, opts = {}) {
    const m = $('modal'), card = m.firstElementChild; card.className = 'card scroll'; card.style.width = ''; card.innerHTML = html; m.classList.remove('hidden'); input.enabled = false; input.reset();
    card.querySelectorAll('[data-a]').forEach((el) => el.addEventListener('click', () => { music.sfx('click'); const a = el.dataset.a; if (!opts.keep) G.closeModal(); handlers[a] && handlers[a](el); }));
  },
  closeModal() { $('modal').classList.add('hidden'); input.enabled = G.state === 'play'; },
  async go(id, opts = {}) {
    if (G.state === 'trans') return; const prev = G.state; G.state = 'trans'; input.reset(); input.enabled = false;
    const f = $('fade'); f.classList.add('on'); await new Promise((r) => setTimeout(r, 300));
    try { await enterZone(id, opts); } catch (e) { console.error(e); errs.push('enter ' + e + ' ' + (e.stack || '')); G.state = prev; }
    f.classList.remove('on'); input.enabled = G.state === 'play';
  },
  hint(html, ms = 8000) { const h = $('hint'); clearTimeout(G._ht); if (!html) { h.classList.add('hidden'); return; } h.innerHTML = html; h.classList.remove('hidden'); G._ht = setTimeout(() => h.classList.add('hidden'), ms); },
  shake(a = 0.3) { cam.shake = Math.max(cam.shake || 0, a); },
  openEditor, refreshCoins,
};
window.G = G; G.rebuildAvatar = rebuildAvatar;
const ACH = [
  { id: 'first_jump', name: 'Boing!', desc: 'Jump for the first time', reward: 10 }, { id: 'coins50', name: 'Pocket Money', desc: 'Collect 50 park coins', reward: 25 },
  { id: 'fashion', name: 'Fashionista', desc: 'Buy a new item', reward: 20 }, { id: 'friend', name: 'Friendly', desc: 'Wave at a park buddy', reward: 15 },
  { id: 'dancer', name: 'Party Starter', desc: 'Use 10 emotes', reward: 25 }, { id: 'obby10', name: 'Climber', desc: 'Reach Sky Obby stage 10', reward: 40 },
  { id: 'obby20', name: 'High Flyer', desc: 'Reach Sky Obby stage 20', reward: 60 }, { id: 'obby30', name: 'Sky Champion', desc: 'Finish Sky Obby', reward: 150 },
  { id: 'tycoon', name: 'Little Boss', desc: 'Earn $1000 in Coin Tycoon', reward: 50 }, { id: 'tag', name: 'Freeze Master', desc: 'Win a game of Freeze Tag', reward: 60 },
  { id: 'race', name: 'Speedy', desc: 'Win a kart race', reward: 60 }, { id: 'build50', name: 'Builder', desc: 'Place 50 blocks', reward: 40 },
  { id: 'daily3', name: 'Regular', desc: '3 days in a row', reward: 50 },
];
G.ACH = ACH;

// ---------- zones ----------
const FACTORY = { hub: createHub, obby: createObby, tycoon: createTycoon, tag: createTag, race: createRace, build: createBuild };
const ZONE_NAMES = { hub: 'Blocky Park', obby: 'Sky Obby', tycoon: 'Coin Tycoon', tag: 'Freeze Tag', race: 'Kart Race', build: 'Build Zone' };
async function enterZone(id, opts) {
  const old = G.zone; if (old) { old.exit && old.exit(G); if (P.avatar.root.parent) P.avatar.root.parent.remove(P.avatar.root); }
  let z = G.zones[id]; if (!z) { z = G.zones[id] = FACTORY[id](G); z.id = id; z.init(G); z.fx = new Particles(); z.scene.add(z.fx.points); z.fx.resize(innerHeight, renderer.getPixelRatio()); if (envTex && !z.noEnv) { z.scene.environment = envTex; z.scene.environmentIntensity = 0.35; } }
  G.zone = z; G.scene = z.scene; G.fx = z.fx;
  G.hint(''); document.body.className = document.body.className.replace(/z-\w+/g, '') + ' z-' + id;
  $('zoneLabel').textContent = ZONE_NAMES[id]; G.zoneHud(''); G.bottomBar('');
  $('bJump').innerHTML = id === 'race' ? svg('bolt') + 'BOOST' : svg('jump') + 'JUMP';
  input.hasStick = z.stick !== false;
  z.scene.add(P.avatar.root); P.avatar.root.visible = true; P.avatar.seated = false;
  P.stun = 0; P.speedMul = 1; P.body.vx = P.body.vy = P.body.vz = 0;
  cam.auto = null; cam.lastDrag = 0;
  z.enter(G, opts || {});
  cam.shake = 0;
  G.state = 'play';
  if (z.theme) G.playMusic(z.theme, z.intensity ?? 0.6);
  resize();
}

// ---------- coins HUD ----------
function refreshCoins() { $('coinChip').innerHTML = svg('coin') + `<b>${S.coins}</b>`; const e = $('edCoins'); if (e) e.innerHTML = svg('coin') + `<b>${S.coins}</b>`; }

// ---------- orbit camera ----------
const _o = new THREE.Vector3();
function orbitCamera(dt, tx, ty, tz, cols, grid) {
  const [dx, dy, dz] = input.takeCam(); const nowT = performance.now(); if (dx || dy) cam.lastDrag = nowT;
  if (cam.auto != null && nowT - (cam.lastDrag || 0) > 1500 && (input.mx || input.my)) cam.yaw += angDiff(cam.yaw, cam.auto) * Math.min(1, dt * 1.6);
  cam.yaw -= dx * 0.0058; cam.pitch = clamp(cam.pitch + dy * 0.0042, 0.04, 1.25); cam.dist = clamp(cam.dist + dz, 4.5, 18);
  cam.tgt.x = damp(cam.tgt.x, tx, 18, dt); cam.tgt.y = damp(cam.tgt.y, ty, 10, dt); cam.tgt.z = damp(cam.tgt.z, tz, 18, dt);
  const cp = Math.cos(cam.pitch), dxn = Math.sin(cam.yaw) * cp, dyn = Math.sin(cam.pitch), dzn = Math.cos(cam.yaw) * cp;
  let t = cam.dist; if (cols) t = rayBoxes(cam.tgt.x, cam.tgt.y, cam.tgt.z, dxn, dyn, dzn, cam.dist, cols, 0.28, grid);
  t = Math.max(1.2, t);
  cam.cur = t < cam.cur ? t : damp(cam.cur, t, 4, dt);
  camera.position.set(cam.tgt.x + dxn * cam.cur, Math.max(cam.minY, cam.tgt.y + dyn * cam.cur), cam.tgt.z + dzn * cam.cur);
  if (cam.shake > 0.001) { camera.position.x += (Math.random() - 0.5) * cam.shake; camera.position.y += (Math.random() - 0.5) * cam.shake; cam.shake *= 0.88; }
  camera.lookAt(cam.tgt);
}
G.orbitCamera = orbitCamera;
G.followCam = (dt, cols, grid) => { const b = P.body; orbitCamera(dt, b.x, b.y + 1.55, b.z, cols, grid); };
G.snapCam = () => { const b = P.body; cam.tgt.set(b.x, b.y + 1.55, b.z); cam.cur = cam.dist; };

// ---------- resize ----------
function resize() {
  const w = innerWidth, h = innerHeight; renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 2)); renderer.setSize(w, h, false);
  camera.aspect = w / h; camera.fov = w / h < 1 ? 66 : 52; camera.updateProjectionMatrix();
  for (const k in G.zones) G.zones[k].fx && G.zones[k].fx.resize(h, renderer.getPixelRatio());
  if (G.zone && G.zone.resize) G.zone.resize(G);
}
addEventListener('resize', resize); addEventListener('orientationchange', () => setTimeout(resize, 150));

// ---------- UI wiring ----------
$('coinChip').innerHTML = svg('coin') + '<b>0</b>';
$('bWard').innerHTML = svg('shirt'); $('bAch').innerHTML = svg('trophy'); $('bMenu').innerHTML = svg('menu'); $('bEmote').innerHTML = svg('smile');
$('playBtn').innerHTML = svg('play') + ' PLAY';
function syncMute() { $('bMute').innerHTML = svg(S.muted ? 'mute' : 'vol'); }
syncMute();
$('bMute').onclick = () => { S.muted = !S.muted; music.setMuted(S.muted); Save.save(); syncMute(); music.sfx('click'); };
$('bWard').onclick = () => { music.sfx('click'); openEditor(); };
$('bAch').onclick = () => { music.sfx('click'); showAchievements(); };
$('bMenu').onclick = () => { music.sfx('click'); showPause(); };
function showAchievements() {
  G.modal(`<h2>Awards</h2><p>${Object.keys(S.ach).length} of ${ACH.length} collected</p><div class="achl">${ACH.map((a) => `<div class="ach ${S.ach[a.id] ? 'got' : ''}">${svg('trophy')}<div>${a.name}<small>${a.desc}</small></div></div>`).join('')}</div><div class="row"><button class="btn blue" data-a="x">Close</button></div>`);
  $('modal').firstElementChild.style.width = 'min(92vw,720px)';
}
function showPause() {
  const z = G.zone, inHub = z && z.id === 'hub';
  G.modal(`<h2>Paused</h2><div class="row"><button class="btn green" data-a="resume">${svg('play')} Keep playing</button>${z && z.respawn ? `<button class="btn blue" data-a="respawn">Back to checkpoint</button>` : ''}${z && z.restart ? `<button class="btn blue" data-a="restart">${z.restartLabel || 'Restart'}</button>` : ''}<button class="btn pink" data-a="mute">${S.muted ? 'Music: OFF' : 'Music: ON'}</button>${inHub ? `<button class="btn grey" data-a="arcade">${svg('home')} Back to arcade</button>` : `<button class="btn grey" data-a="home">${svg('home')} Back to park</button>`}</div>`, {
    restart: () => z.restart(G), respawn: () => z.respawn(G), mute: () => $('bMute').onclick(), arcade: () => { Save.flush(); location.href = '../'; }, home: () => G.go('hub', { from: z.id }),
  });
}
G.showPause = showPause;
addEventListener('keydown', (e) => { if (e.code === 'Escape' && G.state === 'play') showPause(); });

// emotes
const wheel = $('emoteWheel');
EMOTES.forEach((e, i) => {
  const b = document.createElement('button'); b.innerHTML = svg(e.icon);
  const a = Math.PI * 0.5 + (i / (EMOTES.length - 1)) * Math.PI * 0.5 * 1.0; // fan to up-left
  const ang = Math.PI + (i / (EMOTES.length - 1)) * (Math.PI / 2); // from left (180) to up (270)
  b.style.left = (340 - 76 - 4 + Math.cos(ang) * 230 - 0) + 'px'; b.style.top = (340 - 76 - 4 + Math.sin(ang) * 230) + 'px'; b.style.animationDelay = i * 30 + 'ms';
  b.onclick = () => { wheel.classList.add('hidden'); doEmote(e); }; wheel.appendChild(b);
});
$('bEmote').onclick = () => { music.sfx('click'); wheel.classList.toggle('hidden'); };
$('bEmote').addEventListener('pointerdown', (e) => e.stopPropagation());
canvas.addEventListener('pointerdown', () => wheel.classList.add('hidden'));
function doEmote(e) {
  playEmote(P.avatar, e); music.sfx(e.id === 'heart' ? 'sparkle' : e.id === 'laugh' ? 'squeak' : 'pop'); G.stat('emotes'); G.fx && G.fx.burst(P.body.x, P.body.y + 1.2, P.body.z, 8, e.id === 'heart' ? 0xff7aa8 : 0xffe14a, 3, 0.8, 0.3, 3);
  if (S.stats.emotes >= 10) G.ach('dancer');
  if (G.zone && G.zone.onEmote) G.zone.onEmote(G, e);
}
G.doEmote = doEmote;

// ---------- daily reward ----------
function dayKey(d = new Date()) { return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate(); }
G.dailyAvailable = () => S.daily.last !== dayKey();
G.claimDaily = () => {
  if (!G.dailyAvailable()) return false;
  const y = new Date(); y.setDate(y.getDate() - 1);
  S.daily.streak = S.daily.last === dayKey(y) ? S.daily.streak + 1 : 1; S.daily.last = dayKey();
  const amt = 40 + 20 * Math.min(S.daily.streak, 7);
  G.modal(`<h2>Daily gift!</h2><div class="stars" style="color:#ff5c8a">${svg('gift')}</div><p>Day ${S.daily.streak} in a row</p><div class="big">+${amt}</div><div class="row"><button class="btn green" data-a="ok">Yay!</button></div>`, { ok: () => { G.addCoins(amt); music.sfx('win'); if (S.daily.streak >= 3) G.ach('daily3'); } });
  music.sfx('sparkle'); Save.save(); return true;
};

// ---------- avatar editor ----------
let edScene, edCam, edAvatar, edLights, edDraft, edTab = 'skin', edRot = 0.4, edView = { y: 0.95, d: 5.2, a: 0.4 }, edCur = { y: 0.95, d: 5.2 };
const TABS = [['skin', 'Skin'], ['face', 'Face'], ['shirt', 'Shirt'], ['pants', 'Pants'], ['hat', 'Hats'], ['pack', 'Back'], ['trail', 'Trails']];
function hex(c) { return '#' + c.toString(16).padStart(6, '0'); }
function openEditor() {
  if (!edScene) {
    edScene = new THREE.Scene(); edScene.add(makeSky(0x6f5cff, 0xb78bff, 0xffc4e6));
    edLights = makeLights(edScene, { sky: 0xffffff, ground: 0xd8c8ff, hemi: 1.2, shadow: 6, map: 1024 }); edLights.sun.position.set(4, 8, 6); edLights.sun.target.position.set(0, 1, 0); edLights.sun.shadow.camera.near = 1; edLights.sun.shadow.camera.far = 30;
    const ped = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 1.7, 0.4, 28), new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.3 })); ped.position.y = -0.2; ped.receiveShadow = true; edScene.add(ped);
    const ring = new THREE.Mesh(new THREE.TorusGeometry(1.5, 0.06, 8, 40), new THREE.MeshStandardMaterial({ color: 0xffd23f, emissive: 0xffa400, emissiveIntensity: 0.6 })); ring.rotation.x = Math.PI / 2; ring.position.y = 0.02; edScene.add(ring);
    edCam = new THREE.PerspectiveCamera(34, 1, 0.1, 100); if (envTex) edScene.environment = envTex;
    edScene.fx = new Particles(); edScene.add(edScene.fx.points);
    for (let i = 0; i < 14; i++) { const m = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.4, 0.4), new THREE.MeshStandardMaterial({ color: [0xff5a5f, 0xffd23f, 0x7ed957, 0x3d9bff, 0xff6fb5][i % 5], roughness: 0.4 })); const a = i / 14 * 6.28; m.position.set(Math.cos(a) * 6, 0.5 + (i % 4) * 1.2, Math.sin(a) * 6 - 2); m.userData.s = 0.5 + Math.random(); edScene.add(m); (edScene.cubes = edScene.cubes || []).push(m); }
  }
  G.state = 'editor'; input.enabled = false; input.reset(); music.sfx('whoosh');
  edDraft = Object.assign({}, S.avatar); edTab = 'skin'; edView = { y: 0.95, d: 5.6, a: 0.4 }; edRot = 0.35;
  rebuildEd(); document.getElementById('hud').classList.add('hidden'); $('editor').classList.remove('hidden'); document.body.classList.add('ed');
  $('edTop').firstElementChild.textContent = S.name; refreshCoins(); renderTabs(); renderGrid(); refreshBuy(); G.playMusic('toy', 0.5);
  // drag to rotate
  const st = $('edStage'); if (!st._bound) { st._bound = 1; let id = null, lx = 0; st.addEventListener('pointerdown', (e) => { id = e.pointerId; lx = e.clientX; st.setPointerCapture(id); }); st.addEventListener('pointermove', (e) => { if (e.pointerId === id) { edRot += (e.clientX - lx) * 0.012; lx = e.clientX; } }); st.addEventListener('pointerup', () => { id = null; }); }
}
function rebuildEd() { if (edAvatar) edScene.remove(edAvatar.root); edAvatar = buildAvatar(edDraft); edAvatar.root.traverse((o) => { if (o.isMesh) { o.castShadow = true; } }); edScene.add(edAvatar.root); }
function applyDraft(k, v) { edDraft[k] = v; rebuildEd(); renderGrid(); refreshBuy(); music.sfx('pop', { volume: 0.6 }); edAvatar.squash = -0.12;  }
function renderTabs() {
  const t = $('edTabs'); t.innerHTML = '';
  TABS.forEach(([k, n]) => { const b = document.createElement('button'); b.textContent = n; if (k === edTab) b.className = 'on'; b.onclick = () => { edTab = k; music.sfx('click'); edView = k === 'hat' || k === 'face' ? { y: 1.3, d: 4.3, a: 0 } : { y: 0.95, d: 5.6, a: 0.4 }; if (k === 'pack') edRot = Math.PI + 0.35; else if (edRot > 2.5) edRot = 0.35; renderTabs(); renderGrid(); refreshBuy(); }; t.appendChild(b); });
}
const owned = (k, id) => S.owned[k] && S.owned[k].includes(id);
function renderGrid() {
  const g = $('edGrid'); g.innerHTML = '';
  const sw = (list, key) => list.forEach((c, i) => { const b = document.createElement('button'); b.className = 'it sw' + (edDraft[key] === i ? ' sel' : ''); b.innerHTML = `<i style="background:${hex(c)}"></i>`; b.onclick = () => applyDraft(key, i); g.appendChild(b); });
  const items = (kind) => ITEMS[kind].forEach((it) => {
    const b = document.createElement('button'); b.className = 'it' + (edDraft[kind] === it.id ? ' sel' : '');
    const own = owned(kind, it.id) || it.price === 0;
    b.innerHTML = `<img alt="" src="${thumbnail(renderer, kind, it.id, edDraft)}">${it.name}` + (edDraft[kind] === it.id && own ? `<span class="ck">${svg('check')}</span>` : !own ? `<span class="pr">${svg('coin')}${it.price}</span>` : '');
    b.onclick = () => applyDraft(kind, it.id); g.appendChild(b);
  });
  if (edTab === 'skin') sw(SKINS, 'skin'); else if (edTab === 'pants') sw(PANTS, 'pants');
  else if (edTab === 'shirt') { sw(SHIRTS, 'shirt'); const d = document.createElement('div'); d.style.gridColumn = '1/-1'; d.style.fontWeight = '900'; d.style.opacity = '.6'; d.textContent = 'Patterns'; g.appendChild(d); items('pattern'); }
  else items(edTab);
}
function curKind() { return { face: 'face', shirt: 'pattern', hat: 'hat', pack: 'pack', trail: 'trail' }[edTab]; }
function refreshBuy() {
  const k = curKind(), b = $('edBuy'); if (!k) { b.classList.add('hidden'); return; }
  const it = ITEMS[k].find((x) => x.id === edDraft[k]); const own = it.price === 0 || owned(k, it.id);
  b.classList.toggle('hidden', own); if (!own) { b.innerHTML = `Buy ${svg('coin')} ${it.price}`; b.disabled = S.coins < it.price; }
}
$('edBuy').onclick = () => {
  const k = curKind(), it = ITEMS[k].find((x) => x.id === edDraft[k]); if (!it || S.coins < it.price) return;
  S.coins -= it.price; (S.owned[k] = S.owned[k] || []).push(it.id); S.avatar[k] = it.id; Save.save(); refreshCoins(); music.sfx('powerup'); G.ach('fashion');
  edScene.fx.burst(0, 1.4, 0, 30, [0xffd23f, 0xff6fb5, 0x6fd0ff, 0xffffff], 5, 1.1, 0.4, 5); edAvatar.emote = 'cheer'; edAvatar.emT = 0; renderGrid(); refreshBuy();
};
$('edDone').onclick = () => {
  for (const k of Object.keys(ITEMS)) if (!(owned(k, edDraft[k]) || ITEMS[k].find((x) => x.id === edDraft[k]).price === 0)) edDraft[k] = S.avatar[k];
  Object.assign(S.avatar, edDraft); Save.save(); rebuildAvatar(); music.sfx('click');
  $('editor').classList.add('hidden'); document.body.classList.remove('ed'); document.getElementById('hud').classList.remove('hidden');
  G.state = 'play'; input.enabled = true; G.playMusic(G.zone.theme || 'sunny', 0.6);
};
function renderEditor(dt) {
  const r = $('edStage').getBoundingClientRect(), W = innerWidth, H = innerHeight;
  edCur.y = damp(edCur.y, edView.y, 6, dt); edCur.d = damp(edCur.d, edView.d, 6, dt);
  edAvatar.root.rotation.y = edRot + Math.sin(performance.now() / 1400) * 0.05; updateAvatar(edAvatar, dt, 0, false, 0);
  edCam.aspect = r.width / r.height; edCam.fov = r.width / r.height < 0.9 ? 40 : 34; edCam.updateProjectionMatrix();
  const d = edCur.d * (r.width / r.height < 0.9 ? 1.25 : 1);
  edCam.position.set(0, edCur.y + 0.35, d); edCam.lookAt(0, edCur.y, 0);
  edScene.cubes.forEach((m, i) => { m.rotation.x += dt * m.userData.s; m.rotation.y += dt * m.userData.s * 0.7; m.position.y += Math.sin(performance.now() / 700 + i) * 0.004; });
  edScene.fx.update(dt);
  const dpr = renderer.getPixelRatio();
  renderer.setScissorTest(true); renderer.setViewport(r.left, H - r.bottom, r.width, r.height); renderer.setScissor(r.left, H - r.bottom, r.width, r.height);
  renderer.setClearColor(0x9c7bff, 1); renderer.clear(); renderer.render(edScene, edCam); renderer.setScissorTest(false); renderer.setViewport(0, 0, W, H);
}

// ---------- title / start ----------
let started = false;
$('playBtn').onclick = async () => {
  music.unlock(); music.sfx('click'); if (started) return; started = true;
  $('title').classList.add('out'); setTimeout(() => $('title').classList.add('hidden'), 450);
  document.getElementById('hud').classList.remove('hidden'); G.state = 'play'; input.enabled = true; document.body.classList.remove('z-title');
  S.played = true; refreshCoins();
  G.zone.startPlay && G.zone.startPlay(G);
  G.playMusic('sunny', 0.6);
  setTimeout(() => { if (G.dailyAvailable()) G.claimDaily(); }, 900);
  if (!S.hint) { S.hint = 1; Save.save(); const tch = document.body.classList.contains('touch'); const hx = G.P.body.x, hz = G.P.body.z; setTimeout(() => { G.hint(tch ? 'Drag on the left to run, tap JUMP to hop!<small>Drag on the right to look around</small>' : 'WASD to run, SPACE to jump<small>Drag the mouse to look around</small>', 14000); const iv = setInterval(() => { if (!G.zone || G.zone.id !== 'hub') { clearInterval(iv); return; } if (Math.hypot(G.P.body.x - hx, G.P.body.z - hz) > 7) { clearInterval(iv); G.hint('Walk into a glowing gate to play a game!<small>Collect coins and pick up your daily gift</small>', 9000); } }, 400); }, 2200); }
};

// ---------- main loop ----------
let last = performance.now(), fpsT = 0, frames = 0; G.fps = 60;
function frame(now) {
  requestAnimationFrame(frame);
  if (window.__freeze) { last = now; return; }
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  frames++; fpsT += dt; if (fpsT > 1) { G.fps = frames / fpsT; frames = 0; fpsT = 0; }
  if (G.state === 'editor') { renderEditor(dt); return; }
  const z = G.zone; if (!z) return;
  input.poll();
  if (G.state === 'play' || G.state === 'title') {
    const n = Math.max(1, Math.ceil(dt / (1 / 60))); for (let i = 0; i < n; i++) z.update(dt / n, G, i === n - 1);
  }
  if (G.state === 'title') titleCamera(dt);
  else if (z.camera) z.camera(dt, G); else G.followCam(dt, z.cols, z.grid);
  if (z.light) z.light.follow(P.body.x, P.body.y, P.body.z);
  z.fx.update(dt); z.late && z.late(dt, G);
  renderer.render(z.scene, camera);
}
function titleCamera(dt) {
  const a = performance.now() / 6000, k = innerWidth / innerHeight < 1 ? 1.5 : 1; camera.position.set(Math.sin(a) * 26 * k, 8.5 * k, 2 + Math.cos(a) * 26 * k); camera.lookAt(0, 2.2, 2);
}
G.titleCam = titleCamera;

(async function boot() {
  G.state = 'title'; try { if (matchMedia('(pointer: coarse)').matches || navigator.maxTouchPoints > 1) { document.body.classList.add('touch'); input.touchSeen = true; } } catch (e) {}
  try { await enterZone('hub', { title: true }); } catch (e) { console.error(e); errs.push('boot ' + e + (e.stack || '')); }
  G.state = 'title'; resize(); $('floaters');
  requestAnimationFrame(frame);
  window.__ready = true;
})();
