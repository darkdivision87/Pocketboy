import * as THREE from 'three';
import { Batch, worldMat, makeSky, makeClouds, makeLights, textSprite, rng, angDiff, clamp, damp } from './util.js';
import { box, boxC } from './physics.js';
import { Save } from './util.js';

const DIRS = [[0, 1], [1, 0], [0, -1], [-1, 0]];
const TYPES = ['hops', 'zig', 'slider', 'stairs', 'tiles', 'spinner', 'beam', 'bounce', 'pillars', 'lift', 'sweeper', 'ringhop'];
const N = 30;

export function createObby(G) {
  const z = { scene: new THREE.Scene(), cols: [], theme: 'action', intensity: 0.55, movers: [], tiles: [], spinners: [], stages: [], t: 0, cp: 0, deaths: 0, best: 0, finished: false, resp: 0 };
  const scene = z.scene, unit = new THREE.BoxGeometry(1, 1, 1);
  let batch, o, rr;
  const mover = [];
  // ---- local-frame helpers ----
  const fw = () => DIRS[o.h], rt = () => { const f = DIRS[o.h]; return [-f[1], f[0]]; };
  const W = (lr, lf) => { const f = fw(), r = rt(); return [o.x + lr * r[0] + lf * f[0], o.z + lr * r[1] + lf * f[1]]; };
  const SZ = (sr, sf) => { const f = fw(), r = rt(); return [Math.abs(r[0]) * sr + Math.abs(f[0]) * sf, Math.abs(r[1]) * sr + Math.abs(f[1]) * sf]; };
  const PAL = [0xff5a5f, 0xff9f1c, 0xf5c518, 0x6fd54a, 0x1fbf8f, 0xa06cff, 0xff6f4a, 0x8bd33f];
  const col = () => new THREE.Color(PAL[o.i % PAL.length]);
  const dark = (c) => c.clone().multiplyScalar(0.6);
  function stat(lr, ly, lf, sr, sy, sf, color, extra) {
    const [x, zz] = W(lr, lf), [sx, sz] = SZ(sr, sf), cy = o.y + ly - sy / 2;
    batch.box(x, cy, zz, sx, sy, sz, color); batch.box(x, o.y + ly - 0.06, zz, sx + 0.04, 0.12, sz + 0.04, new THREE.Color(color).lerp(new THREE.Color(0xffffff), 0.28));
    const c = boxC(x, cy, zz, sx, sy, sz, extra); z.cols.push(c); return c;
  }
  function mov(lr, ly, lf, sr, sy, sf, color, fn, extra) {
    const [x, zz] = W(lr, lf), [sx, sz] = SZ(sr, sf), cy = o.y + ly - sy / 2;
    const m = new THREE.Mesh(unit, new THREE.MeshStandardMaterial({ color, roughness: 0.5 })); m.scale.set(sx, sy, sz); m.position.set(x, cy, zz); m.castShadow = m.receiveShadow = true; scene.add(m);
    const top = new THREE.Mesh(unit, new THREE.MeshStandardMaterial({ color: new THREE.Color(color).lerp(new THREE.Color(0xffffff), 0.28), roughness: 0.5 })); top.scale.set(1.01, 0.1 / sy, 1.01); top.position.y = 0.5 - 0.05 / sy; m.add(top);
    const c = boxC(x, cy, zz, sx, sy, sz, extra); c.cam = false; z.cols.push(c);
    const f = fw(), r = rt(); const mv = { c, m, bx: x, by: cy, bz: zz, sx, sy, sz, fn, f, r, px: x, py: cy, pz: zz }; z.movers.push(mv); return mv;
  }
  const finishAt = (lf) => { const f = fw(); return lf; };

  // ---- obstacle generators: return {L, rise} ----
  const gens = {
    hops(d) { const n = 3 + Math.round(d * 3), sz = 3.2 - d * 0.9, gap = 2 + d * 2.0, c = col(); let f = 6;
      for (let k = 0; k < n; k++) { f += gap; stat(((k % 2) * 2 - 1) * 0.9 * d, 0, f + sz / 2, sz, 0.8, sz, c); f += sz; } return { L: f + gap - 6, rise: 1 }; },
    zig(d) { const n = 4 + Math.round(d * 2), c = col(); let f = 6 + 2;
      for (let k = 0; k < n; k++) { stat(((k % 2) * 2 - 1) * 3.0, 0, f + 1.6, 3.2, 0.8, 3.2, c); f += 4.2 + d; } return { L: f - 6 + 1.0, rise: 1 }; },
    slider(d) { const L = 14 + d * 4, per = 5 - d * 1.5, a = 6 + 2.7, b = 6 + L - 2.7; mov(0, 0, (a + b) / 2, 4, 0.8, 4, col(), (t) => [0, 0, (b - a) / 2 * Math.sin(t * 6.283 / per)]); return { L, rise: 1 }; },
    stairs(d) { const n = 6, c = col(); let f = 6 + 1;
      for (let k = 0; k < n; k++) { stat(0, (k + 1) * 1.2, f + 1.1, 3.6, 1.2, 2.2, c); f += 3.0; } return { L: f - 6 + 0.2 - 0.0, rise: n * 1.2 }; },
    tiles(d) { const n = 4 + Math.round(d * 3), c = col(); let f = 6 + 0.9;
      for (let k = 0; k < n; k++) { for (let q = -1; q <= 1; q++) { const [x, zz] = W(q * 3.0, f + 1.3), [sx, sz] = SZ(2.6, 2.6); const m = new THREE.Mesh(unit, new THREE.MeshStandardMaterial({ color: c, roughness: 0.5 })); m.scale.set(sx, 0.5, sz); m.position.set(x, o.y - 0.25, zz); m.castShadow = m.receiveShadow = true; scene.add(m); const cc = boxC(x, o.y - 0.25, zz, sx, 0.5, sz); cc.cam = false; z.cols.push(cc); z.tiles.push({ c: cc, m, st: 0, t: 0, bx: x, bz: zz }); } f += 3.1; } return { L: f - 6 + 0.8, rise: 1 }; },
    spinner(d) { const L = 14, c = col(); stat(0, 0, 6 + L / 2, 8, 0.8, L, c); const [px, pz] = W(0, 6 + L / 2); const sp = (1.3 + d * 1.5) * (rr() < 0.5 ? 1 : -1);
      const bars = d > 0.55 ? 2 : 1; for (let k = 0; k < bars; k++) { const g = new THREE.Group(); const bar = new THREE.Mesh(unit, new THREE.MeshStandardMaterial({ color: 0xff4f5e, roughness: 0.4 })); bar.scale.set(9.4, 0.7, 0.6); bar.position.y = 0.55; bar.castShadow = true; g.add(bar); const st = new THREE.Mesh(unit, new THREE.MeshStandardMaterial({ color: 0xffffff })); st.scale.set(9.4, 0.12, 0.7); st.position.y = 0.5; g.add(st); const hub = new THREE.Mesh(new THREE.CylinderGeometry(0.7, 0.8, 1.2, 12), new THREE.MeshStandardMaterial({ color: 0xffd23f })); hub.position.y = 0.6; if (k === 0) g.add(hub); g.position.set(px, o.y, pz); g.rotation.y = k * Math.PI / 2; scene.add(g); z.spinners.push({ g, a: k * Math.PI / 2, w: sp, y: o.y, px, pz }); }
      return { L: L + 0, rise: 1 }; },
    beam(d) { const len = 12 + d * 6, w = 1.5 - d * 0.5, c = col(); stat(0, 0, 6 + len / 2, w, 0.6, len, c); return { L: len + 2, rise: 1.2 }; },
    bounce(d) { const [x, zz] = W(0, 8.5), [sx, sz] = SZ(3.2, 3.2), c = boxC(x, o.y + 0.15, zz, sx, 0.3, sz, { bounce: 25 }); z.cols.push(c); batch.box(x, o.y + 0.15, zz, sx, 0.3, sz, 0xff5c8a); batch.box(x, o.y + 0.32, zz, sx * 0.7, 0.06, sz * 0.7, 0xffffff); stat(0, 0, 6 + 1.2, 6, 0.8, 2.4, col()); return { L: 13, rise: 2 }; },
    pillars(d) { const n = 6, gap = 2 + d * 1.6, c = col(); let f = 6, h = 0; for (let k = 0; k < n; k++) { f += gap; const dh = (rr() - 0.4) * 2.4; h = clamp(h + dh, -1.5, 2.5); stat((rr() - 0.5) * 4, h, f + 1.3, 2.6, 7, 2.6, c); f += 2.6; } return { L: f + gap - 6, rise: h }; },
    lift(d) { const per = 6.5 - d * 1.5; mov(0, 0, 6 + 2.6, 4.4, 0.8, 4, col(), (t) => [0, 3 - 3 * Math.cos(t * 6.283 / per), 0]); return { L: 8.2, rise: 6 }; },
    sweeper(d) { const L = 17, per = 3.4 - d * 1.0, c = col(); stat(0, 0, 6 + L / 2, 5.6, 0.8, L, c); for (let k = 0; k < 2; k++) mov(0, 1.7, 6 + 5 + k * 6, 3.4, 1.7, 0.7, 0xff6b3d, (t) => [Math.sin((t / per + k * 0.5) * 6.283) * 2.0, 0, 0]); return { L: L, rise: 1 }; },
    ringhop(d) { const per = 5.2 - d, c = col(); for (let k = 0; k < 3; k++) { const ph = k * 2.1; mov(0, 0, 6 + 4 + k * 7, 3.6, 0.8, 3.6, c, (t) => [Math.cos(t * 6.283 / per + ph) * 2.4, 0, Math.sin(t * 6.283 / per + ph) * 2.4]); } return { L: 22, rise: 1 }; },
  };

  z.init = (G) => {
    rr = rng(33); batch = new Batch(); const S = G.S;
    scene.fog = new THREE.Fog(0xcfeaff, 90, 330); scene.add(makeSky(0x2e8cff, 0xaee3ff, 0xffe6f2)); const cl = makeClouds(40, 9, 280, -50, -18); scene.add(cl);
    z.light = makeLights(scene, { shadow: 34 });
    o = { x: 0, y: 0, z: 0, h: 0, i: 0 };
    for (let i = 0; i < N; i++) {
      o.i = i; const c = col(); const pc = i === N - 1 ? 0xffd23f : c;
      const pad = stat(0, 0, 3, 6, 1.0, 6, pc); pad.pad = i;
      // flag
      const [fx, fz] = W(2.4, 0.8); batch.box(fx, o.y + 1.4, fz, 0.14, 2.8, 0.14, 0xffffff);
      const flag = new THREE.Mesh(unit, new THREE.MeshStandardMaterial({ color: 0xff5a5f, emissive: 0x000000 })); flag.scale.set(0.9, 0.6, 0.08); flag.position.set(fx, o.y + 2.5, fz); scene.add(flag);
      const sp = textSprite(i === N - 1 ? 'FINISH' : i === 0 ? 'START' : String(i + 1), { px: 70, size: 0.8, bg: null }); const [sx, sz] = W(0, 3); sp.position.set(fx, o.y + 3.7, fz); sp.material.depthWrite = false; scene.add(sp);
      z.stages.push({ i, x: sx, y: o.y, z: sz, h: o.h, pad, flag });
      if (i === N - 1) { // trophy
        const tm = new THREE.MeshStandardMaterial({ color: 0xffd23f, roughness: 0.2, metalness: 0.7, emissive: 0xff9d00, emissiveIntensity: 0.35 }); const tg = new THREE.Group();
        const cup = new THREE.Mesh(new THREE.CylinderGeometry(0.9, 0.5, 1.3, 14), tm); cup.position.y = 1.5; tg.add(cup); const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.15, 0.7, 8), tm); stem.position.y = 0.6; tg.add(stem); const base = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.25, 1.2), tm); base.position.y = 0.12; tg.add(base);
        tg.position.set(sx, o.y + 0.05, sz); scene.add(tg); z.trophy = tg; break;
      }
      const dd = i / (N - 2), type = TYPES[(i + (i > 11 ? 2 : 0)) % TYPES.length];
      const res = gens[type](dd); const lfEnd = 6 + res.L; z.stages[i].type = type;
      const turn = (i + 1) % 6 === 0; const f = fw(), r = DIRS; const cx = o.x + f[0] * (lfEnd + 3), cz = o.z + f[1] * (lfEnd + 3);
      const nh = turn ? (o.h + 1) % 4 : o.h, nf = DIRS[nh];
      o = { x: cx - nf[0] * 3, y: o.y + res.rise, z: cz - nf[1] * 3, h: nh, i: i + 1 };
      // connect corner turn: bridge small slab already covered by pad
    }
    // decorative floating blocks
    for (let k = 0; k < 70; k++) { const a = rr() * 6.283, d = 40 + rr() * 220, x = 70 + Math.cos(a) * d, zz = 70 + Math.sin(a) * d, y = -20 + rr() * 160, s = 2 + rr() * 6; const cc = new THREE.Color().setHSL(rr(), 0.6, 0.7); if (Math.hypot(x - 70, zz - 70) < 60) continue; batch.box(x, y, zz, s, s, s, cc); }
    z.world = batch.build(worldMat()); scene.add(z.world);
    const gc = document.createElement('canvas'); gc.width = gc.height = 128; const gg = gc.getContext('2d'); const gr = gg.createRadialGradient(64, 64, 8, 64, 64, 64); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.7, 'rgba(255,255,255,.9)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); gg.fillStyle = gr; gg.fillRect(0, 0, 128, 128);
    z.goo = new THREE.Mesh(new THREE.PlaneGeometry(150, 150), new THREE.MeshBasicMaterial({ color: 0x2fb8ff, map: new THREE.CanvasTexture(gc), transparent: true, depthWrite: false, fog: false })); z.goo.rotation.x = -Math.PI / 2; z.goo.renderOrder = -1; scene.add(z.goo);
    z.last = z.stages[N - 1];
  };

  function placeAt(G, i, fresh) {
    const s = z.stages[i], b = G.P.body; z.cp = i; b.x = s.x; b.y = s.y; b.z = s.z; b.vx = b.vy = b.vz = 0; G.P.face = Math.atan2(DIRS[s.h][0], DIRS[s.h][1]); G.P.stun = 0;
    if (fresh) { G.cam.yaw = Math.atan2(-DIRS[s.h][0], -DIRS[s.h][1]); G.snapCam(); }
    updateHud(G);
  }
  function updateHud(G) {
    const s = G.S; G.zoneHud(`<div class="pill">Stage ${z.cp + 1} / ${N}</div><div class="bar"><i style="width:${(z.cp / (N - 1)) * 100}%"></i></div>${z.deaths >= 4 && z.cp < N - 1 ? `<button class="btn small blue" id="skipBtn">Skip stage</button>` : ''}`);
    const sb = document.getElementById('skipBtn'); if (sb) sb.onclick = () => { z.deaths = 0; G.sfx('click'); reach(G, z.cp + 1); placeAt(G, z.cp, false); G.snapCam(); };
  }
  function reach(G, i) {
    if (i <= z.cp && !(i === z.cp && !z.stages[i].got)) { return; }
    const s = z.stages[i]; s.got = true; z.cp = i; s.flag.material.color.set(0x4cd964); s.flag.material.emissive.set(0x1a8f3a); z.deaths = 0;
    const S = G.S; if (i > S.obby.best) { S.obby.best = i; G.addCoins(i % 5 === 0 ? 12 : 3, s.x, s.y + 2, s.z); } S.obby.cp = i; Save_(G);
    G.sfx('powerup'); G.fx.burst(s.x, s.y + 2.5, s.z, 22, [0x4cd964, 0xffe14a, 0xffffff], 6, 0.9, 0.4, 6);
    if (i > 0) G.banner(i === N - 1 ? 'FINISH!' : 'Stage ' + (i + 1));
    if (i >= 9) G.ach('obby10'); if (i >= 19) G.ach('obby20');
    updateHud(G);
  }
  const Save_ = () => Save.save();
  function respawn(G, splash) {
    const b = G.P.body; z.deaths++; G.sfx(splash ? 'splash' : 'pop'); G.fx.burst(b.x, Math.max(b.y, z.goo.position.y) + 0.3, b.z, 24, [0xff6fd0, 0xffa8e8, 0xffffff], 7, 0.9, 0.5, 14); G.shake(0.25);
    placeAt(G, z.cp, false); G.fx.burst(b.x, b.y + 1, b.z, 14, [0xffffff, 0xffe14a], 4, 0.6, 0.3, 4); updateHud(G); z.resp = 0.5;
  }
  function win(G) {
    if (z.finished) return; z.finished = true; const S = G.S; S.obby.wins++; S.obby.best = N - 1; G.ach('obby30'); G.addCoins(150); G.sfx('win'); G.playMusic('victory', 0.8); const s = z.stages[N - 1];
    for (let k = 0; k < 4; k++) setTimeout(() => G.fx.burst(s.x + (Math.random() - 0.5) * 4, s.y + 3 + Math.random() * 2, s.z + (Math.random() - 0.5) * 4, 40, [0xffd23f, 0xff5c8a, 0x6fd0ff, 0x7ed957, 0xffffff], 9, 1.6, 0.5, 6), k * 350);
    setTimeout(() => G.modal(`<h2>You did it!</h2><div class="stars">${'<span>&#9733;</span>'.repeat(3)}</div><p>All ${N} stages cleared!</p><div class="big">+150 coins</div><div class="row"><button class="btn green" data-a="again">Play again</button><button class="btn blue" data-a="home">Back to park</button></div>`, { again: () => { z.restart(G); }, home: () => G.go('hub', { from: 'obby' }) }), 1500);
  }
  z.respawn = (G) => respawn(G, false);
  z.restartLabel = 'Start over';
  z.restart = (G) => { G.S.obby.cp = 0; z.finished = false; z.deaths = 0; z.stages.forEach((s) => { s.got = false; s.flag.material.color.set(0xff5a5f); s.flag.material.emissive.set(0x000000); }); placeAt(G, 0, true); G.playMusic('action', 0.55); };

  z.enter = (G, opts) => {
    G.cam.minY = -1e9; G.cam.dist = 10; G.cam.pitch = 0.45; z.finished = false; z.deaths = 0; z.t = 0;
    const S = G.S; z.stages.forEach((s, i) => { s.got = i <= S.obby.cp && i > 0; const c = s.got ? [0x4cd964, 0x1a8f3a] : [0xff5a5f, 0x000000]; s.flag.material.color.set(c[0]); s.flag.material.emissive.set(c[1]); });
    placeAt(G, S.obby.cp, true); updateHud(G);
    if (S.obby.cp > 0) G.toast('Welcome back! Stage ' + (S.obby.cp + 1), 'flag'); else setTimeout(() => G.toast('Reach the golden finish! Touch a flag to save your spot', 'flag'), 600);
  };
  z.exit = () => {};

  z.update = (dt, G, last) => {
    z.t += dt; const P = G.P, b = P.body;
    // movers
    for (const m of z.movers) {
      const off = m.fn(z.t), f = m.f, r = m.r; const nx = m.bx + off[0] * r[0] + off[2] * f[0], nz = m.bz + off[0] * r[1] + off[2] * f[1], ny = m.by + off[1];
      const dx = nx - m.px, dy = ny - m.py, dz = nz - m.pz; m.px = nx; m.py = ny; m.pz = nz;
      const c = m.c; c.x0 = nx - m.sx / 2; c.x1 = nx + m.sx / 2; c.y0 = ny - m.sy / 2; c.y1 = ny + m.sy / 2; c.z0 = nz - m.sz / 2; c.z1 = nz + m.sz / 2; m.m.position.set(nx, ny, nz);
      if (b.ground === c) { b.x += dx; b.y += dy; b.z += dz; }
    }
    // tiles
    for (const t of z.tiles) {
      if (t.st === 0) { if (b.ground === t.c) { t.st = 1; t.t = 0.55; G.sfx('step'); } t.m.position.x = t.bx; }
      else if (t.st === 1) { t.t -= dt; t.m.position.x = t.bx + Math.sin(z.t * 60) * 0.05; if (t.t <= 0) { t.st = 2; t.t = 2.4; t.c.on = false; t.m.visible = false; G.fx.burst(t.bx, t.m.position.y, t.bz, 6, 0xffffff, 2, 0.5, 0.3, 8); } }
      else { t.t -= dt; if (t.t <= 0) { t.st = 0; t.c.on = true; t.m.visible = true; t.m.position.x = t.bx; } }
    }
    // spinners
    for (const s of z.spinners) {
      s.a += s.w * dt; s.g.rotation.y = s.a; const dx = b.x - s.px, dz = b.z - s.pz, ca = Math.cos(s.a), sa = Math.sin(s.a), lx = dx * ca - dz * sa, lz = dx * sa + dz * ca;
      if (G.state === 'play' && Math.abs(lx) < 4.9 && Math.abs(lz) < 0.65 && b.y < s.y + 1.1 && b.y + 1.8 > s.y + 0.1 && P.stun <= 0) {
        const sg = Math.sign(lx * s.w) || 1; const nx = -sa * sg, nz = -ca * sg; b.vx = nx * 13; b.vz = nz * 13; b.vy = 8; P.stun = 0.45; G.sfx('hit'); G.shake(0.3); G.fx.burst(b.x, b.y + 1, b.z, 10, 0xffe14a, 4, 0.5, 0.3, 6);
      }
    }
    if (G.state === 'play') {
      G.walk(dt, z.cols, null, {});
      // auto camera heading
      const cur = z.stages[Math.min(N - 1, z.cp)]; G.cam.auto = Math.atan2(-DIRS[stageHeading(b)][0], -DIRS[stageHeading(b)][1]);
      const g = b.ground; if (g && g.pad !== undefined && b.onGround) { if (g.pad > z.cp || (g.pad === z.cp && !z.stages[g.pad].got)) { reach(G, g.pad); if (g.pad === N - 1) win(G); } }
      if (b.y < z.goo.position.y + 0.2) respawn(G, true);
    }
    z.goo.position.set(b.x, z.goo.position.y, b.z);
    const gy = z.stages[z.cp].y - 12; z.goo.position.y = damp(z.goo.position.y, gy, 2, dt); z.goo.scale.setScalar(1 + Math.sin(z.t * 1.5) * 0.03);
    if (z.trophy) z.trophy.rotation.y = z.t;
    G.music.setIntensity(clamp(0.35 + z.cp / N * 0.55, 0, 1));
  };
  function stageHeading(b) { let best = z.cp, bd = 1e9; for (let i = Math.max(0, z.cp - 1); i < Math.min(N, z.cp + 2); i++) { const s = z.stages[i], d = Math.hypot(s.x - b.x, s.z - b.z, (s.y - b.y)); if (d < bd) { bd = d; best = i; } } return z.stages[best].h; }
  return z;
}
