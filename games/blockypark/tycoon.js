import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { Batch, worldMat, makeSky, makeClouds, makeLights, textSprite, rng, clamp, damp, Save, svg } from './util.js';
import { playEmote, EMOTES, updateAvatar } from './avatar.js';

const DROP = [
  { name: 'Pebble', unlock: 0, base: 1, color: 0xb0b7c9, lv0: 12 }, { name: 'Candy', unlock: 60, base: 4, color: 0xff6f91 }, { name: 'Gold Bar', unlock: 350, base: 15, color: 0xffc533 },
  { name: 'Emerald', unlock: 2000, base: 60, color: 0x4cd964 }, { name: 'Sapphire', unlock: 11000, base: 250, color: 0x3d9bff }, { name: 'Star Gem', unlock: 60000, base: 1100, color: 0xb06cff },
];
const MAXLV = 15, SELLX = 10.5, BELTY = 1.2, XS = [-8.4, -5.8, -3.2, -0.6, 2.0, 4.6];
const fmt = (n) => n >= 1e6 ? (n / 1e6).toFixed(1) + 'M' : n >= 1e4 ? (n / 1e3).toFixed(1) + 'K' : Math.floor(n).toString();

export function createTycoon(G) {
  const z = { scene: new THREE.Scene(), cols: [], theme: 'board', intensity: 0.5, stick: false, t: 0, items: [], timers: [0, 0, 0, 0, 0, 0], pending: 0, pendT: 0, sq: 0, ui: 0, saveT: 0, yaw: 0, rate: 0 };
  const scene = z.scene;
  const T = () => G.S.tycoon;
  const dropVal = (k) => DROP[k].base * (1 + 0.5 * (T().drop[k] - 1));
  const lvCost = (k) => Math.ceil((DROP[k].lv0 || DROP[k].unlock * 0.45) * Math.pow(1.5, T().drop[k] - 1));
  const mult = () => 1 + T().mult, tapVal = () => 1 + T().tap * 2, interval = () => 2.1 / (1 + 0.14 * T().belt), beltSpeed = () => 3 + 0.35 * T().belt;
  const costs = { tap: () => Math.ceil(15 * Math.pow(1.5, T().tap)), belt: () => Math.ceil(80 * Math.pow(1.9, T().belt)), mult: () => Math.ceil(400 * Math.pow(5, T().mult)), auto: () => Math.ceil(120 * Math.pow(1.7, T().auto)) };
  const income = () => { let r = 0; for (let k = 0; k < 6; k++) if (T().drop[k] > 0) r += dropVal(k) / interval(); return (r + T().auto * 0.5 * tapVal()) * mult(); };

  z.init = () => {
    const r = rng(4); const b = new Batch();
    scene.fog = new THREE.Fog(0xb8e4ff, 60, 200); scene.add(makeSky(0x3a8dff, 0xbfe8ff, 0xe8f7ff)); scene.add(makeClouds(22, 3, 120, 28, 60));
    z.light = makeLights(scene, { shadow: 26 }); z.light.sun.position.set(12, 30, 14);
    // island
    for (let x = -22; x < 22; x += 2) for (let zz = -16; zz < 16; zz += 2) { const d = Math.hypot(x / 1.3, zz); if (d > 15) continue; const inF = Math.abs(zz) < 5 && x > -12 && x < 14; b.box(x + 1, -0.5, zz + 1, 2, 1, 2, inF ? (((x + zz) / 2) & 1 ? 0xd5d9e8 : 0xc7ccde) : (((x + zz) / 2) & 1 ? 0x72dc6b : 0x66d062), 0.03); }
    b.box(0, -3, 0, 40, 4, 28, 0x9a6a3a); // earth base (under tiles)
    // belt frame
    b.box(-0.5, 0.55, 0, 20, 1.1, 2.8, 0x4a5170); b.box(-0.5, 0.2, 1.5, 20, 0.5, 0.3, 0xffc533); b.box(-0.5, 0.2, -1.5, 20, 0.5, 0.3, 0xffc533);
    // gantry
    for (const x of [-9.8, 6.4]) b.box(x, 3.5, -2.0, 0.6, 7, 0.6, 0x6a7090);
    b.box(-1.7, 7.1, -2.0, 17, 0.6, 0.6, 0x6a7090); b.box(-1.7, 3.2, -2.3, 17, 0.4, 0.5, 0x6a7090);
    // sell machine
    b.box(SELLX + 1.2, 2.0, 0, 4.2, 4.0, 4.6, 0xff6a3d); b.box(SELLX + 1.2, 4.2, 0, 4.6, 0.5, 5.0, 0xffd23f); b.box(SELLX - 0.9, 1.7, 0, 0.3, 1.8, 2.6, 0x2b2d42); b.box(SELLX + 1.4, 3.1, 0, 2.6, 1.0, 4.7, 0xfff0c8);
    // trees & decor
    for (let k = 0; k < 26; k++) { const a = r() * 6.283, d = 10 + r() * 6, x = Math.cos(a) * d * 1.3, zz = Math.sin(a) * d; if (zz > -7 && x > -16 && x < 18) continue; const h = 2 + r() * 1.5; b.box(x, h / 2, zz, 0.8, h, 0.8, 0x9a6a3a); b.box(x, h + 0.8, zz, 3, 1.6, 3, 0x3fc060); b.box(x, h + 2.1, zz, 2, 1.2, 2, 0x4acd64); }
    for (let k = 0; k < 40; k++) { const a = r() * 6.283, d = 6 + r() * 9, x = Math.cos(a) * d * 1.3, zz = Math.sin(a) * d; if (Math.abs(zz) < 5.5 && x > -13 && x < 15) continue; b.box(x, 0.2, zz, 0.3, 0.4, 0.3, [0xff5c8a, 0xffd23f, 0xffffff][k % 3]); }
    z.world = b.build(worldMat()); scene.add(z.world);
    z.sea = new THREE.Mesh(new THREE.PlaneGeometry(600, 600), new THREE.MeshStandardMaterial({ color: 0x3fb7ff, roughness: 0.35, metalness: 0 })); z.sea.rotation.x = -Math.PI / 2; z.sea.position.y = -3.2; scene.add(z.sea);
    // belt top (scrolling)
    const c = document.createElement('canvas'); c.width = 128; c.height = 128; const g = c.getContext('2d'); g.fillStyle = '#3b4160'; g.fillRect(0, 0, 128, 128); g.fillStyle = '#5a6288'; for (let i = 0; i < 4; i++) { g.save(); g.translate(i * 32 + 16, 64); g.beginPath(); g.moveTo(-10, -30); g.lineTo(6, 0); g.lineTo(-10, 30); g.lineTo(-2, 30); g.lineTo(14, 0); g.lineTo(-2, -30); g.fill(); g.restore(); }
    z.beltTex = new THREE.CanvasTexture(c); z.beltTex.wrapS = z.beltTex.wrapT = THREE.RepeatWrapping; z.beltTex.repeat.set(10, 1); z.beltTex.colorSpace = THREE.SRGBColorSpace;
    const belt = new THREE.Mesh(new THREE.BoxGeometry(20, 0.12, 2.4), new THREE.MeshStandardMaterial({ map: z.beltTex, roughness: 0.8 })); belt.position.set(-0.5, 1.12, 0); belt.receiveShadow = true; scene.add(belt);
    // droppers
    z.drops = XS.map((x, k) => {
      const grp = new THREE.Group(); grp.position.set(x, 0, 0); scene.add(grp);
      const mat = new THREE.MeshStandardMaterial({ color: DROP[k].color, roughness: 0.35 }), body = new THREE.Mesh(new RoundedBoxGeometry(1.9, 1.6, 1.9, 2, 0.15), mat); body.position.y = 4.9; body.castShadow = true; grp.add(body);
      const hop = new THREE.Mesh(new THREE.CylinderGeometry(1.2, 0.75, 0.8, 4), new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.4 })); hop.position.y = 6.2; hop.rotation.y = Math.PI / 4; hop.castShadow = true; grp.add(hop);
      const fun = new THREE.Mesh(new THREE.CylinderGeometry(0.75, 0.2, 0.8, 4), new THREE.MeshStandardMaterial({ color: 0x4a5170 })); fun.position.y = 3.7; fun.rotation.y = Math.PI / 4; grp.add(fun);
      const lock = textSprite('', { px: 40, size: 0.5 }); grp.add(lock); return { grp, mat, body, hop, fun, lock, lvSprite: null, lastLv: -1, lastState: '' };
    });
    // sell machine mouth glow + sign
    z.mouth = new THREE.Mesh(new THREE.BoxGeometry(0.2, 1.6, 2.4), new THREE.MeshStandardMaterial({ color: 0xffd23f, emissive: 0xffa400, emissiveIntensity: 1.2 })); z.mouth.position.set(SELLX - 0.9, 1.7, 0); scene.add(z.mouth);
    const sg = textSprite('SELL', { px: 70, size: 1.1, bg: 'rgba(255,255,255,.0)', color: '#fff' }); sg.position.set(SELLX + 1.2, 5.3, 0); scene.add(sg);
    const sn = textSprite('COIN FACTORY', { px: 64, size: 1.3 }); sn.position.set(-1.5, 9.2, 0); scene.add(sn);
    // cube instances
    z.cube = new THREE.InstancedMesh(new RoundedBoxGeometry(0.95, 0.95, 0.95, 2, 0.14), new THREE.MeshStandardMaterial({ roughness: 0.3, metalness: 0.2 }), 90); z.cube.frustumCulled = false; z.cube.castShadow = true;
    z.cube.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(90 * 3), 3); scene.add(z.cube);
    for (let i = 0; i < 90; i++) z.items.push({ on: false, x: 0, y: 0, vy: 0, k: 0, v: 0, st: 0, rot: 0 });
    z.zero = new THREE.Matrix4().makeScale(0, 0, 0);
    for (let i = 0; i < 90; i++) z.cube.setMatrixAt(i, z.zero);
  };

  // ---- UI ----
  const cards = [];
  function buildUI(G) {
    G.zoneHud(`<div class="pill" id="tcCash"></div><div class="pill" id="tcRate" style="font-size:16px;padding:4px 14px"></div><button class="btn small green" id="tcBank"></button>`);
    document.getElementById('tcBank').onclick = () => bank(G);
    const bar = document.getElementById('bottomBar'); bar.innerHTML = `<button id="tapBtn">TAP!</button><div class="strip scroll" id="tcStrip"></div>`;
    const strip = document.getElementById('tcStrip'); cards.length = 0;
    const defs = [];
    for (let k = 0; k < 6; k++) defs.push({ id: 'd' + k, k });
    defs.push({ id: 'tap' }, { id: 'belt' }, { id: 'auto' }, { id: 'mult' });
    for (const d of defs) {
      const el = document.createElement('div'); el.className = 'shopc'; el.innerHTML = `<div class="nm"></div><small class="in"></small><button class="buy"></button>`; strip.appendChild(el);
      el.querySelector('.buy').onclick = () => buy(G, d); d.el = el; d.nm = el.querySelector('.nm'); d.in = el.querySelector('.in'); d.buy = el.querySelector('.buy'); cards.push(d);
    }
    const tb = document.getElementById('tapBtn'); tb.onpointerdown = (e) => { e.preventDefault(); e.stopPropagation(); tapEarn(G, innerWidth / 2, innerHeight - 260); };
    document.getElementById('tcBank').innerHTML = svg('coin') + ' Bank';
    refreshUI(G, true);
  }
  function refreshUI(G, force) {
    const t = T(); document.getElementById('tcCash').textContent = '$' + fmt(t.cash); document.getElementById('tcRate').textContent = '$' + fmt(income()) + ' / sec  ·  x' + mult();
    const bk = document.getElementById('tcBank'); bk.disabled = t.cash < 20;
    for (const d of cards) {
      let nm, inf, price, state = '';
      if (d.k !== undefined) { const L = t.drop[d.k]; nm = DROP[d.k].name; if (L === 0) { inf = 'Locked'; price = DROP[d.k].unlock; state = 'buy'; } else if (L >= MAXLV) { inf = `Lv ${L} · $${fmt(dropVal(d.k))} each`; price = 0; state = 'max'; } else { inf = `Lv ${L} · $${fmt(dropVal(d.k))} each`; price = lvCost(d.k); state = 'up'; } if (L === 0 && d.k > 0 && t.drop[d.k - 1] === 0) { inf = 'Unlock the one before'; state = 'lock'; } }
      else if (d.id === 'tap') { nm = 'Tap Power'; inf = `+$${fmt(tapVal() * mult())} per tap`; price = costs.tap(); state = 'up'; }
      else if (d.id === 'belt') { nm = 'Fast Belt'; inf = `Lv ${t.belt}/10`; price = costs.belt(); state = t.belt >= 10 ? 'max' : 'up'; }
      else if (d.id === 'auto') { nm = 'Auto Tapper'; inf = `${(t.auto * 0.5).toFixed(1)} taps/sec`; price = costs.auto(); state = t.auto >= 10 ? 'max' : 'up'; }
      else { nm = 'Cash Boost'; inf = `x${mult()} all cash`; price = costs.mult(); state = t.mult >= 6 ? 'max' : 'up'; }
      d.price = price; d.state = state; d.nm.textContent = nm; d.in.textContent = inf;
      const ok = state !== 'max' && state !== 'lock' && t.cash >= price;
      d.el.className = 'shopc' + (ok ? '' : state === 'max' ? ' max' : ' no');
      d.buy.innerHTML = state === 'max' ? 'MAX' : state === 'lock' ? svg('lock') : (state === 'buy' ? 'Unlock ' : 'Upgrade ') + '$' + fmt(price);
    }
  }
  function buy(G, d) {
    const t = T(); if (d.state === 'max' || d.state === 'lock' || t.cash < d.price) { G.sfx('hurt', { volume: 0.4 }); return; }
    t.cash -= d.price; G.sfx('powerup');
    if (d.k !== undefined) t.drop[d.k]++; else t[d.id]++;
    if (d.k !== undefined && t.drop[d.k] === 1) { G.banner('New ' + DROP[d.k].name + '!'); G.fx.burst(XS[d.k], 5, 0, 24, DROP[d.k].color, 6, 1, 0.5, 5); }
    z.sq = 1; Save.save(); refreshUI(G, true);
  }
  function bank(G) {
    const t = T(), n = Math.floor(t.cash / 20); if (n < 1) return; t.cash -= n * 20; G.addCoins(n); G.sfx('win'); G.toast('Banked $' + n * 20 + ' into ' + n + ' coins', 'coin'); Save.save(); refreshUI(G, true);
  }
  function earn(G, amt) { const t = T(); t.cash += amt; t.total += amt; if (t.total >= 1000) G.ach('tycoon'); }
  function tapEarn(G, sx, sy) {
    const v = tapVal() * mult(); earn(G, v); G.sfx('coin', { volume: 0.6, pitch: 1 + Math.random() * 0.3 }); G.floatText('+$' + fmt(v), sx, sy, '');
    z.sq = 1; G.fx.burst(SELLX - 1, 2.5, 0, 6, 0xffd23f, 4, 0.6, 0.3, 8); playEmote(G.P.avatar, EMOTES[5]); G.P.avatar.emT = 0.6; z.tapped = true;
  }

  z.enter = (G) => {
    const t = T(); G.cam.dist = 25; const av = G.P.avatar; G.P.body.x = 7.5; G.P.body.z = 5.5; G.P.body.y = 0; G.P.face = Math.atan2(SELLX - 7.5, -5.5);
    av.root.position.set(7.5, 0, 5.5); av.root.rotation.y = G.P.face;
    z.yaw = 0; z.t = 0; const now = Date.now();
    if (t.last && now - t.last > 20000) { const sec = Math.min(3600, (now - t.last) / 1000), e = Math.floor(sec * income() * 0.5); if (e > 0) { earn(G, e); setTimeout(() => G.toast('Welcome back! Factory earned $' + fmt(e), 'coin'), 600); } }
    t.last = now; Save.save(); buildUI(G); if (!t.total) setTimeout(() => G.hint('Tap TAP! to earn cash, then upgrade your machines!<small>Bank turns cash into coins for the shop</small>', 9000), 800);
    G.input.onTap = (x, y) => { if (G.state === 'play') tapEarn(G, x, y); };
    z.items.forEach((it) => { it.on = false; }); z.timers.fill(0);
  };
  z.exit = (G) => { G.input.onTap = null; T().last = Date.now(); Save.save(); };
  z.restart = null;

  const _m = new THREE.Matrix4(), _p = new THREE.Vector3(), _q = new THREE.Quaternion(), _s = new THREE.Vector3(), _e = new THREE.Euler(), _c = new THREE.Color();
  z.update = (dt, G, last) => {
    z.t += dt; const t = T(); const A = G.P.avatar;
    for (let k = 0; k < 6; k++) {
      if (t.drop[k] <= 0) continue; z.timers[k] += dt;
      if (z.timers[k] >= interval()) { z.timers[k] = 0; const it = z.items.find((i) => !i.on); if (it) { it.on = true; it.x = XS[k]; it.y = 3.6; it.vy = 0; it.k = k; it.v = dropVal(k) * mult(); it.st = 0; _c.set(DROP[k].color); z.cube.setColorAt(items_i(it), _c); z.cube.instanceColor.needsUpdate = true; } }
    }
    const sp = beltSpeed();
    for (let i = 0; i < 90; i++) {
      const it = z.items[i]; if (!it.on) continue;
      if (it.st === 0) { it.vy -= 30 * dt; it.y += it.vy * dt; if (it.y <= BELTY + 0.55) { it.y = BELTY + 0.55; it.st = 1; } }
      else { it.x += sp * dt; if (it.x > SELLX - 1.3) { it.on = false; z.cube.setMatrixAt(i, z.zero); earn(G, it.v); z.pending += it.v; z.sq = Math.max(z.sq, 0.5); G.sfx('step', { volume: 0.5 }); G.fx.burst(SELLX - 1, 2.3, 0, 3, DROP[it.k].color, 3, 0.5, 0.28, 8); continue; } }
      it.rot += dt * 2; _p.set(it.x, it.y, 0); _e.set(0, it.rot * (it.st ? 0 : 1), 0); _q.setFromEuler(_e); _s.set(1, 1, 1); _m.compose(_p, _q, _s); z.cube.setMatrixAt(i, _m);
    }
    z.cube.instanceMatrix.needsUpdate = true;
    z.pendT += dt; if (z.pendT > 0.5 && z.pending > 0) { z.pendT = 0; const p = G.project(SELLX + 1, 5.5, 0); G.floatText('+$' + fmt(z.pending), p.x, p.y, 'g'); z.pending = 0; }
    z.beltTex.offset.x -= sp * dt / 2;
    if (t.auto > 0) { z.autoT = (z.autoT || 0) + dt * t.auto * 0.5; if (z.autoT >= 1) { z.autoT -= 1; const v = tapVal() * mult(); earn(G, v); z.sq = Math.max(z.sq, 0.4); } }
    z.sq = damp(z.sq, 0, 8, dt);
    // visuals
    z.drops.forEach((d, k) => {
      const L = t.drop[k], st = L > 0 ? 'on' : 'off';
      if (d.lastState !== st || d.lastLv !== L) {
        d.lastState = st; d.lastLv = L;
        if (L > 0) { d.mat.color.set(DROP[k].color); d.mat.emissive.set(0x000000); d.lock.visible = false; if (d.lvSprite) d.grp.remove(d.lvSprite); d.lvSprite = textSprite('Lv ' + L, { px: 44, size: 0.5 }); d.lvSprite.position.set(0, 7.2, 0); d.grp.add(d.lvSprite); }
        else { d.mat.color.set(0x8a90a8); d.lock.visible = false; if (d.lvSprite) d.grp.remove(d.lvSprite); d.lvSprite = textSprite('$' + fmt(DROP[k].unlock), { px: 44, size: 0.55, bg: 'rgba(255,255,255,.85)', color: '#8a4b00' }); d.lvSprite.position.set(0, 7.2, 0); d.grp.add(d.lvSprite); }
      }
      d.body.scale.y = 1 + Math.sin(z.timers[k] / interval() * 6.283) * (L > 0 ? 0.04 : 0); d.grp.position.y = L > 0 ? 0 : -0.2;
    });
    if (A) { A.root.position.y = 0; }
    z.mouth.material.emissiveIntensity = 0.9 + z.sq * 1.5; z.mouth.scale.y = 1 + z.sq * 0.25;
    G.P.speed = 0; updateAvatar(A, dt, 0, false, 0);
    z.ui += dt; if (z.ui > 0.25) { z.ui = 0; refreshUI(G); }
    z.saveT += dt; if (z.saveT > 4) { z.saveT = 0; t.last = Date.now(); Save.save(); }
    G.music.setIntensity(clamp(0.35 + Math.log10(1 + income()) * 0.12, 0, 0.95));
  };
  const items_i = (it) => z.items.indexOf(it);
  z.camera = (dt, G) => {
    const [dx, dy, dz] = G.input.takeCam(); z.yaw = clamp(z.yaw - dx * 0.005, -0.8, 0.8); G.cam.dist = clamp(G.cam.dist + dz, 16, 40);
    const asp = innerWidth / innerHeight, d = G.cam.dist * (asp < 1 ? 1.5 : 1), y = 0.45 + clamp(dy * 0, 0, 0);
    G.camera.position.set(1 + Math.sin(z.yaw) * d, 7 + d * 0.5, Math.cos(z.yaw) * d); G.camera.lookAt(1.5, asp < 1 ? 3.5 : 3.0, 0);
  };
  return z;
}
