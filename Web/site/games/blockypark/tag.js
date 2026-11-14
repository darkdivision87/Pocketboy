import * as THREE from 'three';
import { Batch, worldMat, makeSky, makeClouds, makeLights, textSprite, rng, clamp, damp, angDiff, Save } from './util.js';
import { box, makeBody, moveBody } from './physics.js';
import { buildAvatar, updateAvatar, addNameTag, SKINS, SHIRTS, PANTS, ITEMS } from './avatar.js';

const A = 22, TIME = 75, NB = 6;
const NAMES = ['Pogo', 'Kiwi', 'Zippy', 'Bean', 'Nova', 'Taco', 'Sprout', 'Mango'];

export function createTag(G) {
  const z = { scene: new THREE.Scene(), cols: [], theme: 'toy', intensity: 0.7, bots: [], t: 0, phase: 'idle', timeLeft: TIME, frozen: 0, cd: 0 };
  const scene = z.scene;
  z.init = () => {
    const b = new Batch(), r = rng(15);
    scene.fog = new THREE.Fog(0xffe1ef, 70, 240); scene.add(makeSky(0x6a7bff, 0xffc4e1, 0xfff3d6)); scene.add(makeClouds(26, 8, 160, 30, 70));
    z.light = makeLights(scene, { shadow: 30, hemi: 1.0 });
    for (let x = -A; x < A; x += 2) for (let zz = -A; zz < A; zz += 2) b.box(x + 1, -0.5, zz + 1, 2, 1, 2, ((x + zz) / 2) & 1 ? 0x7fe0b0 : 0x6fd3a2, 0.02);
    b.box(0, -3, 0, A * 2 + 6, 4, A * 2 + 6, 0x8a6a4a);
    z.cols.push(box(-A - 6, -6, -A - 6, A + 6, 0, A + 6, { cam: false }));
    // walls
    for (let i = -A; i < A; i += 4) for (const [x, zz, ry] of [[i + 2, -A - 1, 0], [i + 2, A + 1, 0], [-A - 1, i + 2, 1], [A + 1, i + 2, 1]]) { const c = (i / 4) & 1 ? 0xff7aa8 : 0xffd23f; b.box(x, 1.1, zz, ry ? 2 : 4, 2.2, ry ? 4 : 2, c); b.box(x, 2.3, zz, ry ? 2.3 : 4.3, 0.3, ry ? 4.3 : 2.3, 0xffffff); }
    z.cols.push(box(-A - 2, 0, -A - 2, A + 2, 2.4, -A, { cam: false }), box(-A - 2, 0, A, A + 2, 2.4, A + 2, { cam: false }), box(-A - 2, 0, -A, -A, 2.4, A, { cam: false }), box(A, 0, -A, A + 2, 2.4, A, { cam: false }));
    const add = (cx, cz, w, d, h, color, extra) => { b.box(cx, h / 2, cz, w, h, d, color); b.box(cx, h + 0.1, cz, w + 0.1, 0.2, d + 0.1, 0xffffff); z.cols.push(box(cx - w / 2, 0, cz - d / 2, cx + w / 2, h, cz + d / 2, extra)); };
    // central platform with steps
    for (let i = 0; i < 3; i++) { const s = 10 - i * 2; b.box(0, i * 0.5 + 0.25, 0, s, 0.5, s, [0x4cc3ff, 0x7cd6ff, 0xb5e6ff][i]); z.cols.push(box(-s / 2, 0, -s / 2, s / 2, i * 0.5 + 0.5, s / 2)); }
    // crates + walls
    const spots = [[-12, -12, 3, 3, 3, 0xff9f1c], [12, -12, 3, 3, 2, 0xff5a5f], [-12, 12, 3, 3, 2, 0xb06cff], [12, 12, 3, 3, 3, 0x3d9bff], [0, -15, 8, 1.6, 2.2, 0x2fbf71], [0, 15, 8, 1.6, 2.2, 0x2fbf71], [-16, 0, 1.6, 8, 2.2, 0xff6fb5], [16, 0, 1.6, 8, 2.2, 0xff6fb5], [-6, -7, 2, 2, 1.2, 0xffd23f], [7, 8, 2, 2, 1.2, 0xffd23f], [-7, 8, 2, 2, 2.0, 0x4cd964], [7, -7, 2, 2, 2.0, 0x4cd964], [-9, 0, 1.4, 1.4, 1.2, 0xffffff], [9, 0, 1.4, 1.4, 1.2, 0xffffff]];
    for (const s of spots) add(s[0], s[1], s[2], s[3], s[4], s[5]);
    z.world = b.build(worldMat()); scene.add(z.world);
    const rr = rng(77);
    for (let i = 0; i < NB; i++) {
      const cfg = { skin: (rr() * SKINS.length) | 0, face: ['happy', 'wink', 'cool', 'silly', 'wow'][(rr() * 5) | 0], shirt: (rr() * SHIRTS.length) | 0, pattern: 'none', pants: (rr() * PANTS.length) | 0, hat: ITEMS.hat[(rr() * ITEMS.hat.length) | 0].id, pack: 'none', trail: 'none' };
      const av = buildAvatar(cfg); addNameTag(av, NAMES[i]); scene.add(av.root);
      const ice = new THREE.Mesh(new THREE.BoxGeometry(1.3, 2.2, 1.3), new THREE.MeshStandardMaterial({ color: 0x9fe8ff, transparent: true, opacity: 0.5, roughness: 0.08, metalness: 0.1, emissive: 0x40b8ff, emissiveIntensity: 0.25 })); ice.visible = false; scene.add(ice);
      z.bots.push({ av, body: makeBody(0, 0, 0, 0.32, 1.8), face: 0, frozen: false, ice, wander: 0, wa: 0, dash: 0, dashCd: 2 + Math.random() * 3, speed: 0 });
    }
    z.ring = new THREE.Mesh(new THREE.TorusGeometry(0.9, 0.06, 6, 24), new THREE.MeshBasicMaterial({ color: 0xffe14a, transparent: true, opacity: 0.8 })); z.ring.rotation.x = Math.PI / 2; z.ring.position.y = 0.05; scene.add(z.ring);
  };

  function hud(G) {
    const m = Math.max(0, Math.ceil(z.timeLeft)); G.zoneHud(`<div class="pill">Frozen ${z.frozen} / ${NB}</div><div class="pill">${Math.floor(m / 60)}:${String(m % 60).padStart(2, '0')}</div>`);
  }
  function startRound(G) {
    const b = G.P.body; b.x = 0; b.z = 14; b.y = 0; b.vx = b.vz = b.vy = 0; G.P.face = Math.PI; G.cam.yaw = 0; G.snapCam();
    z.bots.forEach((o, i) => { const a = i / NB * 6.283 + 0.4, d = 9 + (i % 2) * 4; o.body.x = Math.cos(a) * d; o.body.z = Math.sin(a) * d - 2; o.body.y = 0; o.body.vx = o.body.vy = o.body.vz = 0; o.frozen = false; o.ice.visible = false; o.av.root.visible = true; o.dash = 0; });
    z.frozen = 0; z.timeLeft = TIME; z.phase = 'count'; z.cd = 3.4; z.lastN = 4; hud(G); G.playMusic('toy', 0.6);
  }
  z.restart = (G) => startRound(G);
  z.enter = (G) => { G.cam.minY = 0.5; G.cam.dist = 11; G.cam.pitch = 0.5; startRound(G); setTimeout(() => G.toast('Tag every buddy to freeze them!', 'ice'), 3600); };
  z.exit = () => { document.getElementById('countdown').classList.add('hidden'); };

  function end(G, win) {
    z.phase = 'done'; const S = G.S; const left = Math.ceil(z.timeLeft); const coins = win ? 40 + left : z.frozen * 6; document.getElementById('countdown').classList.add('hidden');
    if (win) { S.best.tagWins++; if (!S.best.tagTime || TIME - z.timeLeft < S.best.tagTime) S.best.tagTime = TIME - z.timeLeft; G.ach('tag'); G.sfx('win'); G.playMusic('victory', 0.8); } else { G.sfx('lose'); }
    G.addCoins(coins); Save.save();
    setTimeout(() => G.modal(`<h2>${win ? 'All frozen!' : "Time's up!"}</h2><div class="stars">${[0, 1, 2].map((i) => `<span class="${(win ? 3 : z.frozen >= 4 ? 2 : z.frozen >= 2 ? 1 : 0) > i ? '' : 'off'}">&#9733;</span>`).join('')}</div><p>You froze ${z.frozen} of ${NB} buddies${win ? ' with ' + left + 's to spare' : ''}.</p><div class="big">+${coins} coins</div><div class="row"><button class="btn green" data-a="again">Play again</button><button class="btn blue" data-a="home">Back to park</button></div>`, { again: () => startRound(G), home: () => G.go('hub', { from: 'tag' }) }), 900);
  }

  z.update = (dt, G, last) => {
    z.t += dt; const P = G.P, pb = P.body;
    if (z.phase === 'count') {
      z.cd -= dt; const n = Math.ceil(z.cd), el = document.getElementById('countdown');
      if (z.cd > 0) { if (n !== z.lastN) { z.lastN = n; G.sfx('click'); } el.classList.remove('hidden'); el.textContent = n > 3 ? '' : n; } else { z.phase = 'play'; el.textContent = 'GO!'; G.sfx('powerup'); setTimeout(() => el.classList.add('hidden'), 700); }
    }
    G.walk(dt, z.cols, null, { speed: z.phase === 'count' ? 0 : 9 });
    if (z.phase === 'play') {
      z.timeLeft -= dt; z.hudT = (z.hudT || 0) + dt; if (z.hudT > 0.25) { z.hudT = 0; hud(G); }
      G.music.setIntensity(clamp(0.5 + (1 - z.timeLeft / TIME) * 0.5, 0, 1));
      if (z.timeLeft <= 0) { z.timeLeft = 0; end(G, false); }
    }
    for (const o of z.bots) {
      const b = o.body;
      if (!o.frozen && z.phase !== 'done') {
        let dx = b.x - pb.x, dz = b.z - pb.z; const d = Math.hypot(dx, dz) || 1; dx /= d; dz /= d;
        o.wander -= dt; if (o.wander <= 0) { o.wander = 0.4 + Math.random() * 0.6; o.wa = (Math.random() - 0.5) * 1.6; }
        const ca = Math.cos(o.wa), sa = Math.sin(o.wa); let fx = dx * ca - dz * sa, fz = dx * sa + dz * ca;
        const scare = clamp(1 - d / 16, 0, 1);
        if (z.phase === 'count') { fx = fz = 0; } else if (scare < 0.05) { fx *= 0.3; fz *= 0.3; }
        // keep away from walls and steer toward the middle when close to an edge
        const ex = Math.max(0, Math.abs(b.x) - (A - 7)) / 7, ez = Math.max(0, Math.abs(b.z) - (A - 7)) / 7;
        fx -= Math.sign(b.x) * ex * 1.6; fz -= Math.sign(b.z) * ez * 1.6;
        const fl = Math.hypot(fx, fz) || 1; fx /= fl; fz /= fl;
        o.dashCd -= dt; if (o.dashCd <= 0 && scare > 0.5) { o.dash = 0.6; o.dashCd = 4 + Math.random() * 3; } o.dash -= dt;
        const sp = (z.phase === 'count' ? 0 : 7.3 + (o.dash > 0 ? 2.6 : 0)) * (scare < 0.05 ? 0.5 : 1);
        b.vx = damp(b.vx, fx * sp, 9, dt); b.vz = damp(b.vz, fz * sp, 9, dt);
        if (b.hitWall && b.onGround && Math.random() < 0.15) b.vy = 12.5;
        // tag!
        if (z.phase === 'play' && Math.hypot(b.x - pb.x, b.z - pb.z) < 1.25 && Math.abs(b.y - pb.y) < 1.5) {
          o.frozen = true; z.frozen++; o.ice.visible = true; b.vx = b.vz = 0; G.sfx('powerup'); G.sfx('sparkle'); G.shake(0.2); G.fx.burst(b.x, b.y + 1, b.z, 20, [0x9fe8ff, 0xffffff, 0xd8f6ff], 6, 0.9, 0.4, 5); hud(G);
          G.pop('Frozen!', b.x, b.y + 2.6, b.z, 'w'); if (z.frozen >= NB) end(G, true);
        }
      } else { b.vx = damp(b.vx, 0, 12, dt); b.vz = damp(b.vz, 0, 12, dt); }
      b.vy = Math.max(b.vy - 38 * dt, -50); moveBody(b, dt, z.cols);
      o.speed = Math.hypot(b.vx, b.vz); if (o.speed > 0.8) o.face += angDiff(o.face, Math.atan2(b.vx, b.vz)) * Math.min(1, dt * 12);
      o.av.root.position.set(b.x, b.y, b.z); o.av.root.rotation.y = o.face; updateAvatar(o.av, dt, o.frozen ? 0 : o.speed, !b.onGround, b.vy); o.ice.position.set(b.x, b.y + 1.05, b.z);
      if (o.frozen) { o.av.body.rotation.z = 0.05; o.ice.rotation.y += 0.0; }
    }
    z.ring.position.set(pb.x, pb.y + 0.05, pb.z); z.ring.scale.setScalar(1 + Math.sin(z.t * 6) * 0.08);
  };
  return z;
}
