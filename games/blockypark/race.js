import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { Batch, worldMat, makeSky, makeClouds, makeLights, textSprite, rng, clamp, damp, angDiff, Save, svg } from './util.js';
import { buildAvatar, updateAvatar, addNameTag, SKINS, SHIRTS, PANTS, ITEMS, SHIRTS as SH } from './avatar.js';

const N = 400, HW = 7.2, LAPS = 3;
const BOT_COL = [0xff5a5f, 0xffd23f, 0x7ed957];
const ORD = ['1st', '2nd', '3rd', '4th'];

export function createRace(G) {
  const z = { scene: new THREE.Scene(), cols: [], theme: 'action', intensity: 0.8, t: 0, phase: 'idle', cd: 0, bots: [], karts: [] };
  const scene = z.scene;
  const cx = new Float32Array(N), cz = new Float32Array(N), tx = new Float32Array(N), tz = new Float32Array(N), nx = new Float32Array(N), nz = new Float32Array(N), len = new Float32Array(N);
  const K = { x: 0, z: 0, th: 0, v: 0, idx: 0, cross: 0, boost: 0, meter: 1, steer: 0, off: false, pad: 0, finished: false, bank: 0, yaw: 0 };
  z.K = K;
  const rad = (t) => 92 + 24 * Math.sin(2 * t + 0.5) + 13 * Math.sin(3 * t + 1.7);
  function ribbon(w0, w1, y, colorFn, step = 1, from = 0, to = N) {
    const pos = [], col = [], idx = []; let n = 0; const c = new THREE.Color();
    for (let i = from; i <= to; i += step) {
      const a = i % N, ci = colorFn(i); c.set(ci);
      for (const w of [w0, w1]) { pos.push(cx[a] + nx[a] * w, y, cz[a] + nz[a] * w); col.push(c.r, c.g, c.b); }
      if (n > 0) { const k = n * 2; idx.push(k - 2, k - 1, k, k - 1, k + 1, k); } n++;
    }
    const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3)); g.setIndex(idx); g.computeVertexNormals();
    return g;
  }
  z.init = () => {
    const r = rng(19), b = new Batch();
    for (let i = 0; i < N; i++) { const t = i / N * 6.283185, R = rad(t); cx[i] = Math.cos(t) * R; cz[i] = Math.sin(t) * R; }
    for (let i = 0; i < N; i++) { const a = (i + 1) % N, p = (i + N - 1) % N; let dx = cx[a] - cx[p], dz = cz[a] - cz[p]; const l = Math.hypot(dx, dz); tx[i] = dx / l; tz[i] = dz / l; nx[i] = -tz[i]; nz[i] = tx[i]; len[i] = Math.hypot(cx[a] - cx[i], cz[a] - cz[i]); }
    scene.fog = new THREE.Fog(0xcdeeff, 120, 380); scene.add(makeSky(0x2e8cff, 0xaee3ff, 0xe8f7d8)); scene.add(makeClouds(26, 4, 300, 55, 100));
    z.light = makeLights(scene, { shadow: 44 });
    // grass
    const c = document.createElement('canvas'); c.width = c.height = 64; const g = c.getContext('2d'); g.fillStyle = '#6fd86a'; g.fillRect(0, 0, 64, 64); g.fillStyle = '#63ce5f'; g.fillRect(0, 0, 32, 32); g.fillRect(32, 32, 32, 32); const tex = new THREE.CanvasTexture(c); tex.wrapS = tex.wrapT = THREE.RepeatWrapping; tex.repeat.set(70, 70); tex.colorSpace = THREE.SRGBColorSpace; tex.magFilter = THREE.NearestFilter;
    const gr = new THREE.Mesh(new THREE.PlaneGeometry(700, 700), new THREE.MeshStandardMaterial({ map: tex, roughness: 0.9 })); gr.rotation.x = -Math.PI / 2; gr.receiveShadow = true; scene.add(gr);
    const rm = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.8, side: THREE.DoubleSide, polygonOffset: true, polygonOffsetFactor: -1, polygonOffsetUnits: -1 });
    const road = new THREE.Mesh(ribbon(-HW, HW, 0.03, (i) => ((i >> 3) & 1) ? 0x555b78 : 0x4e546f, 1, 0, N), rm); road.receiveShadow = true; scene.add(road);
    const km = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.7, side: THREE.DoubleSide, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 });
    scene.add(new THREE.Mesh(ribbon(HW, HW + 1.3, 0.05, (i) => ((i >> 1) & 1) ? 0xff4f5e : 0xffffff, 1, 0, N), km)); scene.add(new THREE.Mesh(ribbon(-HW - 1.3, -HW, 0.05, (i) => ((i >> 1) & 1) ? 0xff4f5e : 0xffffff, 1, 0, N), km));
    scene.add(new THREE.Mesh(ribbon(-0.2, 0.2, 0.05, (i) => ((i % 8) < 4) ? 0xfff3a0 : 0x555b78, 1, 0, N), km));
    // boost pads
    z.pads = [70, 170, 275, 345]; const bm = new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.DoubleSide, polygonOffset: true, polygonOffsetFactor: -3, polygonOffsetUnits: -3 });
    z.pads.forEach((p) => scene.add(new THREE.Mesh(ribbon(-3.2, 3.2, 0.07, (i) => (((i - p) >> 1) & 1) ? 0xffd23f : 0xff8a1c, 1, p, p + 6), bm)));
    // start line
    const cv = document.createElement('canvas'); cv.width = 128; cv.height = 32; const cg = cv.getContext('2d'); for (let x = 0; x < 16; x++) for (let y = 0; y < 4; y++) { cg.fillStyle = (x + y) & 1 ? '#111' : '#fff'; cg.fillRect(x * 8, y * 8, 8, 8); }
    const st = new THREE.Mesh(new THREE.PlaneGeometry(HW * 2, 3), new THREE.MeshBasicMaterial({ map: new THREE.CanvasTexture(cv), polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4 })); st.rotation.x = -Math.PI / 2; st.rotation.z = Math.atan2(tx[0], tz[0]) - Math.PI / 2 + Math.PI / 2; st.position.set(cx[0], 0.09, cz[0]); st.rotation.set(-Math.PI / 2, 0, 0); st.rotation.order = 'YXZ'; st.rotation.y = Math.atan2(nx[0], nz[0]) + Math.PI / 2 - Math.PI / 2; scene.add(st);
    // gantry
    const gy = Math.atan2(nx[0], nz[0]); for (const s of [-1, 1]) b.boxR(cx[0] + nx[0] * s * (HW + 2), 3.5, cz[0] + nz[0] * s * (HW + 2), 1.2, 7, 1.2, gy, s < 0 ? 0xff4f5e : 0x3d9bff);
    b.boxR(cx[0], 7.3, cz[0], HW * 2 + 6, 1.6, 1.4, gy + Math.PI / 2, 0xffffff); for (let k = -5; k <= 5; k++) b.boxR(cx[0] + nx[0] * k * 1.4, 7.3, cz[0] + nz[0] * k * 1.4, 1.4, 1.6, 1.5, gy + Math.PI / 2, k & 1 ? 0x222222 : 0xffffff);
    const sg = textSprite('START', { px: 70, size: 1.3 }); sg.position.set(cx[0], 9.4, cz[0]); scene.add(sg);
    // fence posts and trees
    for (let i = 0; i < N; i += 4) for (const s of [-1, 1]) { const d = (HW + 6.5) * s, x = cx[i] + nx[i] * d, zz = cz[i] + nz[i] * d; b.box(x, 0.8, zz, 0.5, 1.6, 0.5, (i >> 2) & 1 ? 0xff5c8a : 0xffffff); }
    const near = (x, zz) => { let m = 1e9; for (let i = 0; i < N; i += 3) { const d = Math.hypot(x - cx[i], zz - cz[i]); if (d < m) m = d; } return m; };
    for (let k = 0, nt = 0; k < 500 && nt < 110; k++) { const a = r() * 6.283, d = r() * 190, x = Math.cos(a) * d, zz = Math.sin(a) * d; if (near(x, zz) < 17) continue; nt++; const h = 2 + r() * 2.5; b.box(x, h / 2, zz, 0.9, h, 0.9, 0x9a6a3a); b.box(x, h + 0.9, zz, 3.4, 1.8, 3.4, [0x3fc060, 0x4acd64, 0x35b457][nt % 3], 0.06); b.box(x, h + 2.3, zz, 2.2, 1.4, 2.2, 0x4acd64, 0.06); if (r() < 0.35) b.box(x + 3, 0.5, zz, 1.2, 1, 1.2, [0xff5c8a, 0xffd23f, 0xb06cff][nt % 3]); }
    const cone = new THREE.ConeGeometry(1, 1, 4); for (let k = 0; k < 20; k++) { const a = k / 20 * 6.283, d = 250 + r() * 40, h = 40 + r() * 40, w = 50 + r() * 30; b.geo(cone, Math.cos(a) * d, h / 2, Math.sin(a) * d, w, h, w, new THREE.Color().setHSL(0.55 + r() * 0.1, 0.4, 0.5).getHex(), r() * 3); }
    z.world = b.build(worldMat()); scene.add(z.world);
    // karts
    const mk = (color, avCfg, name) => {
      const g = new THREE.Group(), m = new THREE.MeshStandardMaterial({ color, roughness: 0.3 }); const ch = new THREE.Mesh(new RoundedBoxGeometry(1.7, 0.6, 3, 2, 0.2), m); ch.position.y = 0.55; ch.castShadow = true; g.add(ch);
      const hood = new THREE.Mesh(new RoundedBoxGeometry(1.4, 0.4, 1.1, 2, 0.15), m); hood.position.set(0, 0.95, 0.85); hood.castShadow = true; g.add(hood);
      const sp = new THREE.Mesh(new THREE.BoxGeometry(1.8, 0.12, 0.5), new THREE.MeshStandardMaterial({ color: 0xffffff })); sp.position.set(0, 1.35, -1.3); g.add(sp); for (const s of [-1, 1]) { const p = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.5, 0.1), new THREE.MeshStandardMaterial({ color: 0x333355 })); p.position.set(s * 0.6, 1.1, -1.3); g.add(p); }
      const wm = new THREE.MeshStandardMaterial({ color: 0x20213a, roughness: 0.7 }), wg = new THREE.CylinderGeometry(0.5, 0.5, 0.4, 14); g.wheels = [];
      for (const [x, zz] of [[-0.95, 1.0], [0.95, 1.0], [-0.95, -1.0], [0.95, -1.0]]) { const w = new THREE.Mesh(wg, wm); w.rotation.z = Math.PI / 2; w.position.set(x, 0.5, zz); w.castShadow = true; g.add(w); g.wheels.push(w); }
      const fl = new THREE.Mesh(new THREE.ConeGeometry(0.35, 1.6, 8), new THREE.MeshBasicMaterial({ color: 0xffa020, transparent: true, opacity: 0.85 })); fl.rotation.x = -Math.PI / 2; fl.position.set(0, 0.7, -2.4); fl.visible = false; g.add(fl); g.flame = fl;
      const av = buildAvatar(avCfg); av.seated = true; av.root.position.set(0, 0.75, -0.1); av.root.scale.setScalar(0.8); g.add(av.root); g.av = av; if (name) addNameTag(av, name); scene.add(g); return g;
    };
    z.playerKart = mk(0x3d9bff, G.S.avatar, null);
    const rr = rng(5); const names = ['Zippy', 'Pogo', 'Nova'];
    for (let i = 0; i < 3; i++) { const cfg = { skin: (rr() * SKINS.length) | 0, face: ['happy', 'cool', 'wink'][i], shirt: (rr() * SHIRTS.length) | 0, pattern: 'none', pants: (rr() * PANTS.length) | 0, hat: ['cap', 'cat', 'prop'][i], pack: 'none', trail: 'none' }; z.bots.push({ g: mk(BOT_COL[i], cfg, names[i]), s: 0, lane: (i - 1) * 3, v: 0, base: [21.8, 22.8, 23.6][i], fin: false, t: 0 }); }
    z.bots.forEach((b) => { b.g.av.tag && (b.g.av.tag.position.y = 2.6); });
  };

  function nearest(x, zz, hint) { let best = hint, bd = 1e9; for (let k = -25; k <= 25; k++) { const i = (hint + k + N) % N, d = (x - cx[i]) ** 2 + (zz - cz[i]) ** 2; if (d < bd) { bd = d; best = i; } } return best; }
  function hud(G) {
    const lap = clamp(K.cross, 1, LAPS), pos = rank() + 1;
    G.zoneHud(`<div class="pill">Lap ${lap} / ${LAPS}</div><div class="pill">${ORD[pos - 1]}</div><div class="bar" style="width:min(30vw,220px);height:16px"><i id="bst" style="width:${K.meter * 100}%;background:linear-gradient(90deg,#4cc3ff,#9fe8ff)"></i></div>`);
  }
  const total = () => K.cross * N + K.idx;
  function rank() { let r = 0; const me = total(); for (const b of z.bots) if (b.s > me) r++; return r; }
  function startRace(G) {
    const sl = [[-1, 0], [1, 0], [-1, 1], [1, 1]]; // grid slots (lane, row)
    const slot = (i) => { const [l, row] = sl[i]; const idx = N - 6 - row * 7; return { idx, lane: l * 2.6 }; };
    const me = slot(3); K.idx = me.idx; K.cross = 0; K.x = cx[K.idx] + nx[K.idx] * me.lane; K.z = cz[K.idx] + nz[K.idx] * me.lane; K.th = Math.atan2(tx[K.idx], tz[K.idx]); K.v = 0; K.boost = 0; K.meter = 1; K.finished = false; K.hp = 0;
    z.bots.forEach((b, i) => { const sp = slot(i); b.s = sp.idx; b.lane = sp.lane; b.fin = false; b.v = 0; });
    z.phase = 'count'; z.cd = 3.5; z.lastN = 4; z.time = 0; hud(G); G.playMusic('action', 0.85); G.cam.auto = null; G.cam.dist = 8.5; z.camInit = true;
  }
  z.restart = (G) => startRace(G);
  z.enter = (G) => {
    const av = G.P.avatar; z.playerKart.add(av.root); av.root.position.set(0, 0.75, -0.1); av.root.scale.setScalar(0.8); av.root.rotation.set(0, 0, 0); av.seated = true; av.emote = null;
    startRace(G); if (!G.S.best.raceWins && !G.S.best.race) setTimeout(() => G.hint('Steer with the left stick or A / D<small>Press BOOST when the bar is full!</small>', 7000), 600);
  };
  z.exit = (G) => { const av = G.P.avatar; av.root.scale.setScalar(1); av.seated = false; av.root.rotation.set(0, 0, 0); document.getElementById('countdown').classList.add('hidden'); };

  function finish(G) {
    if (K.finished) return; K.finished = true; z.phase = 'done'; const pos = rank() + 1, S = G.S, coins = [120, 70, 40, 20][pos - 1], tm = z.time;
    if (pos === 1) { S.best.raceWins++; G.ach('race'); G.sfx('win'); G.playMusic('victory', 0.8); } else G.sfx('lose');
    if (!S.best.race || tm < S.best.race) S.best.race = tm; G.addCoins(coins); Save.save();
    setTimeout(() => G.modal(`<h2>${pos === 1 ? 'You won!' : 'You finished ' + ORD[pos - 1] + '!'}</h2><div class="stars">${[0, 1, 2].map((i) => `<span class="${(4 - pos) > i ? '' : 'off'}">&#9733;</span>`).join('')}</div><p>Time ${tm.toFixed(1)}s &nbsp;·&nbsp; Best ${S.best.race.toFixed(1)}s</p><div class="big">+${coins} coins</div><div class="row"><button class="btn green" data-a="again">Race again</button><button class="btn blue" data-a="home">Back to park</button></div>`, { again: () => startRace(G), home: () => G.go('hub', { from: 'race' }) }), 1200);
  }

  const _v = new THREE.Vector3();
  z.update = (dt, G, last) => {
    z.t += dt; const input = G.input;
    // countdown
    if (z.phase === 'count') { z.cd -= dt; const n = Math.ceil(z.cd), el = document.getElementById('countdown'); if (z.cd > 0) { if (n !== z.lastN) { z.lastN = n; G.sfx('click', { pitch: 0.9 }); } el.classList.remove('hidden'); el.textContent = n > 3 ? '' : n; } else { z.phase = 'go'; el.textContent = 'GO!'; G.sfx('powerup'); setTimeout(() => el.classList.add('hidden'), 800); } }
    const racing = z.phase === 'go' || z.phase === 'done';
    if (z.phase === 'go') z.time += dt;
    // ---- player kart ----
    const jump = input.takeJump();
    if (z.phase === 'go' && jump && K.meter >= 0.99) { K.meter = 0; K.boost = 1.4; G.sfx('whoosh'); G.shake(0.25); }
    K.meter = Math.min(1, K.meter + dt / 7); K.boost = Math.max(0, K.boost - dt);
    const steer = -input.mx, accel = z.phase === 'go' && !K.finished ? (input.my < -0.5 ? -1 : 1) : 0;
    const vmax = K.boost > 0 ? 38 : K.off ? 12 : 26;
    if (accel > 0) K.v += (K.boost > 0 ? 40 : 17) * dt; else if (accel < 0) K.v -= 34 * dt; else K.v -= 12 * dt;
    if (K.v > vmax) K.v = Math.max(vmax, K.v - 30 * dt); if (K.v < -6) K.v = -6;
    const tr = (2.1 - 1.15 * clamp(K.v / 26, 0, 1)) * clamp(Math.abs(K.v) / 3, 0, 1) * Math.sign(K.v || 1);
    K.th += steer * tr * dt; K.steer = damp(K.steer, steer, 10, dt);
    K.x += Math.sin(K.th) * K.v * dt; K.z += Math.cos(K.th) * K.v * dt;
    K.idx = nearest(K.x, K.z, K.idx);
    const dx = K.x - cx[K.idx], dz = K.z - cz[K.idx], d = dx * nx[K.idx] + dz * nz[K.idx]; K.off = Math.abs(d) > HW + 0.6;
    const lim = HW + 5.6; if (Math.abs(d) > lim) { const ex = Math.abs(d) - lim; K.x -= nx[K.idx] * Math.sign(d) * ex; K.z -= nz[K.idx] * Math.sign(d) * ex; if (K.v > 8) { G.sfx('hit', { volume: 0.5 }); G.shake(0.2); } K.v *= 0.6; }
    // lap crossing
    if (K.last === undefined) K.last = K.idx; if (K.last > N * 0.75 && K.idx < N * 0.25) { K.cross++; if (K.cross >= 1 && K.cross <= LAPS) { G.sfx('sparkle'); if (K.cross > 1) G.banner(K.cross === LAPS ? 'Final lap!' : 'Lap ' + K.cross); } if (K.cross > LAPS) finish(G); hud(G); } else if (K.last < N * 0.25 && K.idx > N * 0.75) K.cross--; K.last = K.idx;
    // pads
    for (const p of z.pads) { let df = K.idx - p; if (df > N / 2) df -= N; if (df < -N / 2) df += N; if (df >= 0 && df <= 6 && Math.abs(d) < 3.6 && K.boost < 0.8) { K.boost = 1.1; G.sfx('whoosh'); G.shake(0.2); } }
    if (K.finished) { K.v *= 0.985; }
    // ---- bots ----
    const me = total();
    z.bots.forEach((b, i) => {
      if (racing && !b.fin) {
        let sp = b.base + Math.sin(z.t * 0.6 + i * 2) * 0.8; const gap = b.s - me; if (gap > 40) sp *= 0.9; else if (gap < -25) sp *= 1.07; if (K.finished) sp *= 0.9;
        b.v = damp(b.v, sp, 2.5, dt); const ii = Math.floor(b.s) % N; b.s += b.v * dt / len[ii]; if (b.s >= (LAPS + 1) * N) b.fin = true;
      } else if (b.fin) b.v = damp(b.v, 8, 1, dt);
      const ii = Math.floor(b.s) % N, jj = (ii + 1) % N, f = b.s - Math.floor(b.s); const bx = cx[ii] + (cx[jj] - cx[ii]) * f, bz = cz[ii] + (cz[jj] - cz[ii]) * f, lane = b.lane + Math.sin(z.t * 0.7 + i) * 1.6;
      b.px = bx + nx[ii] * lane; b.pz = bz + nz[ii] * lane; const h = Math.atan2(tx[ii], tz[ii]);
      // push-away from player
      const ddx = b.px - K.x, ddz = b.pz - K.z, dd = Math.hypot(ddx, ddz); if (dd < 2.4 && dd > 0.01) { const push = (2.4 - dd) * 0.5; K.x -= ddx / dd * push; K.z -= ddz / dd * push; b.lane += clamp(ddx * nx[ii] + ddz * nz[ii], -1, 1) * dt * 5; K.v *= 0.995; if (dd < 2.0) G.sfx('hit', { volume: 0.25 }); }
      b.lane = clamp(b.lane, -HW + 1.5, HW - 1.5);
      b.g.position.set(b.px, 0, b.pz); b.g.rotation.y = angDiff(0, h); b.g.wheels.forEach((w) => { w.rotation.x -= b.v * dt * 2; }); updateAvatar(b.g.av, dt, 0, false, 0);
    });
    if (z.phase === 'go') { z.hudT = (z.hudT || 0) + dt; if (z.hudT > 0.3) { z.hudT = 0; hud(G); } }
    // kart visuals
    const pk = z.playerKart; pk.position.set(K.x, 0, K.z); pk.rotation.y = K.th; pk.rotation.z = -K.steer * 0.06 * clamp(K.v / 20, 0, 1);
    pk.wheels.forEach((w, i) => { w.rotation.x -= K.v * dt * 2; if (i < 2) w.rotation.y = -K.steer * 0.4; });
    pk.flame.visible = K.boost > 0; pk.flame.scale.set(1, 0.7 + Math.random() * 0.6, 1); updateAvatar(G.P.avatar, dt, 0, false, 0);
    if (K.boost > 0 || (K.v > 5 && K.off)) G.fx.emit(K.x - Math.sin(K.th) * 1.8 + (Math.random() - 0.5), 0.5, K.z - Math.cos(K.th) * 1.8 + (Math.random() - 0.5), 0, 1.5, 0, 0.5, K.boost > 0 ? [0xffd23f, 0xff8a1c, 0xffffff][(Math.random() * 3) | 0] : 0x8a6a3a, K.boost > 0 ? 0.55 : 0.4, 0);
    const st = document.getElementById('bst'); if (st) st.style.width = K.meter * 100 + '%';
    G.music.setIntensity(clamp(0.5 + K.v / 60, 0, 1));
    G.P.body.x = K.x; G.P.body.z = K.z; G.P.body.y = 0;
  };
  z.camera = (dt, G) => {
    const cam = G.camera; const back = 9.5 + K.v * 0.05, up = 4.4; const h = K.th;
    const tx_ = K.x - Math.sin(h) * back, tz_ = K.z - Math.cos(h) * back;
    if (z.camInit) { cam.position.set(tx_, up, tz_); z.camInit = false; }
    cam.position.x = damp(cam.position.x, tx_, 5, dt); cam.position.z = damp(cam.position.z, tz_, 5, dt); cam.position.y = damp(cam.position.y, up + K.v * 0.02, 3, dt);
    _v.set(K.x + Math.sin(h) * 6, 1.4, K.z + Math.cos(h) * 6); cam.lookAt(_v); G.input.takeCam();
    const fov = (innerWidth / innerHeight < 1 ? 70 : 54) + (K.boost > 0 ? 9 : 0) + clamp(K.v - 20, 0, 8) * 0.3; cam.fov = damp(cam.fov, fov, 5, dt); cam.updateProjectionMatrix();
    if (G.cam.shake > 0.001) { cam.position.x += (Math.random() - 0.5) * G.cam.shake; cam.position.y += (Math.random() - 0.5) * G.cam.shake; G.cam.shake *= 0.88; }
  };
  return z;
}
