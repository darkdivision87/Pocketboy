import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { Batch, worldMat, makeSky, makeClouds, makeLights, textSprite, rng, clamp, Save, svg } from './util.js';
import { box, VoxelGrid } from './physics.js';

const COLORS = [0xff5a5f, 0xff9f1c, 0xffd23f, 0x9be564, 0x2fbf71, 0x2ec4b6, 0x4cc3ff, 0x3d6bff, 0x9b5cff, 0xff6fb5, 0xffffff, 0xa0632e];
const MAXB = 2000, XM = -16, XM2 = 15, YM = 29;

export function createBuild(G) {
  const z = { scene: new THREE.Scene(), cols: [], grid: new VoxelGrid(), theme: 'calm', intensity: 0.55, t: 0, n: 0, sel: 2, erase: false, undo: [], saveT: 0, dirty: false };
  const scene = z.scene;
  const px = new Int16Array(MAXB * 3), pc = new Uint8Array(MAXB); const _m = new THREE.Matrix4(), _c = new THREE.Color();
  z.init = () => {
    const b = new Batch(); const r = rng(2);
    scene.fog = new THREE.Fog(0xcfeaff, 80, 300); scene.add(makeSky(0x3a8dff, 0xbfe8ff, 0xffe9f4)); scene.add(makeClouds(30, 12, 200, -30, 70));
    z.light = makeLights(scene, { shadow: 30 });
    for (let x = XM; x <= XM2; x++) for (let zz = XM; zz <= XM2; zz++) b.box(x + 0.5, -0.5, zz + 0.5, 1, 1, 1, (x + zz) & 1 ? 0xc9ecff : 0xaedbff, 0.01);
    b.box(-0.5 + 0, -3, -0.5, 34, 4, 34, 0x9a6a3a); b.box(-0.5, -1.0, -0.5, 33, 0.8, 33, 0x6fd86a);
    z.world = b.build(worldMat()); scene.add(z.world);
    z.cols.push(box(XM - 4, -6, XM - 4, XM2 + 5, 0, XM2 + 5, { cam: false }));
    z.inst = new THREE.InstancedMesh(new RoundedBoxGeometry(1, 1, 1, 2, 0.09), new THREE.MeshStandardMaterial({ roughness: 0.38, metalness: 0.05 }), MAXB); z.inst.count = 0; z.inst.castShadow = z.inst.receiveShadow = true; z.inst.frustumCulled = false;
    z.inst.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(MAXB * 3), 3); scene.add(z.inst);
    z.hint = textSprite('Tap to build!', { px: 56, size: 0.9 }); z.hint.position.set(0, 3.2, -8); scene.add(z.hint);
    z.ghost = new THREE.Mesh(new THREE.BoxGeometry(1.02, 1.02, 1.02), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.3, depthWrite: false })); z.ghost.visible = false; scene.add(z.ghost);
    const saved = G.S.build; for (let i = 0; i + 3 < saved.length && z.n < MAXB; i += 4) add(saved[i], saved[i + 1], saved[i + 2], saved[i + 3], true);
  };
  function writeInst(i) { _m.makeTranslation(px[i * 3] + 0.5, px[i * 3 + 1] + 0.5, px[i * 3 + 2] + 0.5); z.inst.setMatrixAt(i, _m); _c.set(COLORS[pc[i]]); z.inst.setColorAt(i, _c); }
  function add(x, y, zz, c, quiet) {
    if (z.n >= MAXB || z.grid.get(x, y, zz) !== undefined) return false; const i = z.n++; px[i * 3] = x; px[i * 3 + 1] = y; px[i * 3 + 2] = zz; pc[i] = c; z.grid.set(x, y, zz, i); writeInst(i); z.inst.count = z.n; z.inst.instanceMatrix.needsUpdate = true; z.inst.instanceColor.needsUpdate = true; z.dirty = true; if (!quiet) sched(); return true;
  }
  function remove(x, y, zz) {
    const i = z.grid.get(x, y, zz); if (i === undefined) return null; const c = pc[i]; z.grid.del(x, y, zz); const last = --z.n;
    if (i !== last) { px[i * 3] = px[last * 3]; px[i * 3 + 1] = px[last * 3 + 1]; px[i * 3 + 2] = px[last * 3 + 2]; pc[i] = pc[last]; z.grid.set(px[i * 3], px[i * 3 + 1], px[i * 3 + 2], i); writeInst(i); }
    z.inst.count = z.n; z.inst.instanceMatrix.needsUpdate = true; z.inst.instanceColor.needsUpdate = true; z.dirty = true; sched(); return c;
  }
  function sched() { clearTimeout(z.pt); z.pt = setTimeout(() => persist(), 350); }
  function persist() { const a = []; for (let i = 0; i < z.n; i++) a.push(px[i * 3], px[i * 3 + 1], px[i * 3 + 2], pc[i]); G.S.build = a; Save.save(); z.dirty = false; }
  const ray = new THREE.Raycaster(), v2 = new THREE.Vector2();
  function pick(sx, sy) {
    v2.set(sx / innerWidth * 2 - 1, -(sy / innerHeight) * 2 + 1); ray.setFromCamera(v2, G.camera); const o = ray.ray.origin, d = ray.ray.direction; let prev = null;
    for (let t = 0; t < 70; t += 0.06) { const x = o.x + d.x * t, y = o.y + d.y * t, zz = o.z + d.z * t, cx = Math.floor(x), cy = Math.floor(y), cz = Math.floor(zz);
      if (cx < XM - 2 || cx > XM2 + 2 || cz < XM - 2 || cz > XM2 + 2) { prev = null; continue; }
      if (z.grid.get(cx, cy, cz) !== undefined) return { hit: [cx, cy, cz], prev };
      if (y < 0) return { ground: true, prev }; prev = [cx, cy, cz]; }
    return null;
  }
  function tap(sx, sy) {
    if (G.state !== 'play') return; const p = pick(sx, sy); if (!p) return;
    if (z.erase) { if (p.hit) { const c = remove(...p.hit); if (c !== null) { z.undo.push(['r', ...p.hit, c]); G.sfx('pop', { pitch: 0.7 }); G.fx.burst(p.hit[0] + 0.5, p.hit[1] + 0.5, p.hit[2] + 0.5, 8, COLORS[c], 3, 0.5, 0.3, 8); updateHud(); } } return; }
    const cell = p.prev; if (!cell) return; const [x, y, zz] = cell; if (x < XM || x > XM2 || zz < XM || zz > XM2 || y < 0 || y > YM) return;
    const b = G.P.body; if (b.x + 0.3 > x && b.x - 0.3 < x + 1 && b.z + 0.3 > zz && b.z - 0.3 < zz + 1 && b.y + 1.8 > y && b.y < y + 1) { G.toast('Step aside first!', 'smile'); return; }
    if (z.n >= MAXB) { G.toast('Block limit reached!', 'lock'); return; }
    if (add(x, y, zz, z.sel)) { z.undo.push(['a', x, y, zz]); if (z.undo.length > 80) z.undo.shift(); G.sfx('pop', { pitch: 0.8 + Math.min(1, y / 14) * 0.9 }); G.fx.burst(x + 0.5, y + 0.5, zz + 0.5, 6, COLORS[z.sel], 2.5, 0.4, 0.25, 6); G.stat('placed'); if (G.S.stats.placed >= 50) G.ach('build50'); updateHud(); }
  }
  function updateHud() { const e = document.getElementById('bdCount'); if (e) e.textContent = `${z.n} / ${MAXB} blocks`; }
  function buildUI() {
    G.zoneHud(`<div class="pill" id="bdCount"></div>`); updateHud();
    const bar = document.getElementById('bottomBar'); let h = '<div class="pal">';
    COLORS.forEach((c, i) => { h += `<button class="c${i === z.sel && !z.erase ? ' on' : ''}" data-c="${i}" style="background:#${c.toString(16).padStart(6, '0')}"></button>`; });
    h += `<span class="gap"></span><button class="t${z.erase ? ' on' : ''}" id="bdEr">${svg('eraser')}</button><button class="t" id="bdUn">${svg('undo')}</button><button class="t" id="bdClr">${svg('close')}</button></div>`; bar.innerHTML = h;
    bar.querySelectorAll('.c').forEach((el) => el.onclick = () => { z.sel = +el.dataset.c; z.erase = false; G.sfx('click'); buildUI(); });
    document.getElementById('bdEr').onclick = () => { z.erase = !z.erase; G.sfx('click'); buildUI(); };
    document.getElementById('bdUn').onclick = () => { const u = z.undo.pop(); if (!u) return; if (u[0] === 'a') remove(u[1], u[2], u[3]); else add(u[1], u[2], u[3], u[4]); G.sfx('swish'); updateHud(); };
    document.getElementById('bdClr').onclick = () => { G.sfx('click'); G.modal(`<h2>Clear everything?</h2><p>This removes all ${z.n} blocks.</p><div class="row"><button class="btn pink" data-a="y">Yes, clear</button><button class="btn blue" data-a="n">Keep building</button></div>`, { y: () => z.clearAll(G) }); };
  }
  z.clearAll = () => { while (z.n > 0) remove(px[0], px[1], px[2]); z.undo.length = 0; persist(); updateHud(); G.sfx('boom', { volume: 0.5 }); };
  z.enter = () => {
    const b = G.P.body; b.x = 0; b.z = 5; b.y = 0; G.P.face = Math.PI; G.cam.yaw = 0; G.cam.dist = 12; G.cam.pitch = 0.5; G.cam.minY = 0.4; G.snapCam(); buildUI();
    G.input.onTap = tap; if (!G.S.stats.placed) setTimeout(() => G.toast('Tap the world to place blocks. Pick a colour below!', 'star'), 700);
  };
  z.exit = () => { G.input.onTap = null; if (z.dirty) persist(); };
  z.update = (dt, G) => {
    z.t += dt;
    if (G.state === 'play') { G.walk(dt, z.cols, z.grid, {}); const b = G.P.body; if (b.y < -12) { b.x = 0; b.z = 5; b.y = 8; b.vy = 0; } }
    z.hint.visible = z.n === 0; z.saveT += dt; if (z.dirty && z.saveT > 2) { z.saveT = 0; persist(); }
    G.music.setIntensity(0.45);
  };
  return z;
}
