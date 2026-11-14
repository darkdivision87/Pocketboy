import * as THREE from 'three';
import { Batch, worldMat, makeSky, makeClouds, makeLights, textSprite, rng, damp, angDiff, clamp } from './util.js';
import { box, boxC, makeBody, moveBody } from './physics.js';
import { buildAvatar, updateAvatar, playEmote, addNameTag, EMOTES, SKINS, SHIRTS, PANTS, ITEMS } from './avatar.js';

const R = 60, GR = 36;
const GATES = [
  { id: 'build', name: 'Build Zone', color: 0xb06cff, a: 30 }, { id: 'shop', name: 'Style Shop', color: 0xff8a3d, a: 90 }, { id: 'obby', name: 'Sky Obby', color: 0x35c7ff, a: 150 },
  { id: 'tycoon', name: 'Coin Tycoon', color: 0xffc533, a: 210 }, { id: 'tag', name: 'Freeze Tag', color: 0xff6f91, a: 270 }, { id: 'race', name: 'Kart Race', color: 0x4cd964, a: 330 },
];
const NPC_NAMES = ['Mango', 'Zippy', 'Pogo', 'Nova', 'Bean', 'Sprout', 'Kiwi', 'Taco', 'Pixel', 'Waffles', 'Bubbles', 'Ziggy'];
const swirlMat = (col) => new THREE.ShaderMaterial({
  transparent: true, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending, fog: false,
  uniforms: { t: { value: 0 }, col: { value: new THREE.Color(col) } },
  vertexShader: 'varying vec2 vUv; void main(){ vUv=uv; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }',
  fragmentShader: 'uniform float t; uniform vec3 col; varying vec2 vUv; void main(){ vec2 p=vUv*2.-1.; float r=length(p); float a=atan(p.y,p.x); float s=sin(a*3.+r*9.-t*2.6)*.5+.5; float s2=sin(a*5.-r*6.+t*1.7)*.5+.5; float m=smoothstep(1.,.55,max(abs(p.x),abs(p.y)*.92)); vec3 c=mix(col,vec3(1.),s*.55+s2*.15); gl_FragColor=vec4(c*(.7+.6*s),m*(.45+.4*s));\n#include <colorspace_fragment>\n}',
});

export function createHub(G) {
  const z = { scene: new THREE.Scene(), cols: [], theme: 'sunny', intensity: 0.6, npcs: [], gates: [], coins: [], pads: [], swirls: [], t: 0, cool: 0, giftCool: 0 };
  const scene = z.scene;
  z.init = () => {
    const r = rng(7); const b = new Batch();
    scene.fog = new THREE.Fog(0xbfe6ff, 110, 340);
    scene.add(makeSky(0x3fa0ff, 0xc8ecff, 0xd8f4d8)); scene.add(makeClouds(26, 5));
    z.light = makeLights(scene, { shadow: 40 });
    // ground tiles
    const onPath = (x, zz) => { for (const g of GATES) { const a = g.a * Math.PI / 180, cx = Math.cos(a), cz = Math.sin(a), t = x * cx + zz * cz; if (t > 0 && t < GR - 2) { const d = Math.abs(-x * cz + zz * cx); if (d < 2.2) return true; } } return false; };
    for (let x = -R; x < R; x += 2) for (let zz = -R; zz < R; zz += 2) {
      const cx = x + 1, cz = zz + 1, d = Math.hypot(cx, cz); if (d > R + 0.5) continue;
      let col, jit = 0.05;
      if (d < 14) { col = ((x / 2 + zz / 2) & 1) ? 0xffe9c9 : 0xffcfe0; jit = 0.02; }
      else if (d < 15.5) col = 0xff9fc0;
      else if (onPath(cx, cz)) { col = ((x / 2 + zz / 2) & 1) ? 0xf6df9d : 0xefd28a; jit = 0.02; }
      else col = ((x / 2 + zz / 2) & 1) ? 0x72dc6b : 0x66d062;
      b.box(cx, -0.5, cz, 2.0, 1, 2.0, col, jit);
    }
    z.cols.push(box(-R - 5, -6, -R - 5, R + 5, 0, R + 5, { cam: false }));
    // fountain
    b.box(0, 0.3, 0, 7.2, 0.6, 7.2, 0xd8dff0); b.box(0, 0.62, 0, 6.4, 0.08, 6.4, 0x58c8ff); b.box(0, 1.1, 0, 1.4, 1.6, 1.4, 0xe6ebf8); b.box(0, 2.0, 0, 3.0, 0.3, 3.0, 0xd8dff0); b.box(0, 2.6, 0, 0.8, 1.0, 0.8, 0xe6ebf8); b.box(0, 3.2, 0, 1.6, 0.25, 1.6, 0xffd23f);
    z.cols.push(box(-3.6, 0, -3.6, 3.6, 0.62, 3.6), box(-0.7, 0, -0.7, 0.7, 3.4, 0.7));
    // gates
    GATES.forEach((g) => {
      const a = g.a * Math.PI / 180, ca = Math.cos(a), sa = Math.sin(a), px = ca * GR, pz = sa * GR, tx = -sa, tz = ca, ry = Math.atan2(-tz, tx);
      const col = g.color, dark = new THREE.Color(col).multiplyScalar(0.7).getHex();
      for (const s of [-1, 1]) {
        const x = px + tx * 3.4 * s, zz = pz + tz * 3.4 * s;
        b.boxR(x, 3, zz, 1.5, 6, 1.5, ry, col); b.boxR(x, 6.1, zz, 2.0, 0.4, 2.0, ry, 0xffffff); b.boxR(x, 0.4, zz, 2.1, 0.8, 2.1, ry, dark);
        z.cols.push(box(x - 0.75, 0, zz - 0.75, x + 0.75, 6, zz + 0.75));
      }
      b.boxR(px, 6.8, pz, 9.2, 1.3, 1.5, ry, col); b.boxR(px, 7.6, pz, 8.0, 0.35, 1.7, ry, 0xffffff);
      for (let k = -3; k <= 3; k++) b.boxR(px + tx * k * 1.2, 6.8, pz + tz * k * 1.2, 0.45, 0.45, 1.6, ry, k % 2 ? 0xffffff : 0xffe14a);
      // little decorations
      for (let k = 0; k < 5; k++) { const s = k < 3 ? 1 : -1, o = 7 + r() * 3, h = 0.8 + r() * 1.4, x = px + tx * s * o - ca * (2 + r() * 3), zz = pz + tz * s * o - sa * (2 + r() * 3); b.box(x, h / 2, zz, 1.2, h, 1.2, [col, 0xffffff, 0xffe14a][k % 3]); z.cols.push(box(x - 0.6, 0, zz - 0.6, x + 0.6, h, zz + 0.6)); }
      const m = new THREE.Mesh(new THREE.PlaneGeometry(5.2, 5.9), swirlMat(col)); m.position.set(px, 3.0, pz); m.rotation.y = Math.atan2(-ca, -sa); scene.add(m); z.swirls.push(m);
      const ring = new THREE.Mesh(new THREE.CircleGeometry(4.2, 28), new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: 0.32, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -3 })); ring.rotation.x = -Math.PI / 2; ring.position.set(px - ca * 1.0, 0.03, pz - sa * 1.0); scene.add(ring);
      const sp = textSprite(g.name, { px: 64, size: 1.7, bg: 'rgba(25,20,70,.62)' }); sp.position.set(px, 9.6, pz); sp.material.fog = false; scene.add(sp); z.gates.push({ g, x: px, z: pz, sp });
    });
    // pyramid hill
    for (let i = 0; i < 10; i++) { const s = 20 - i * 2; b.box(-46, i * 0.5 + 0.25, 0, s, 0.5, s, i % 2 ? 0x7fe070 : 0x6cd05f); z.cols.push(box(-46 - s / 2, 0, -s / 2, -46 + s / 2, i * 0.5 + 0.5, s / 2, { cam: false })); }
    b.box(-46, 5.4, 0, 2, 0.8, 2, 0xffd23f); z.cols.push(box(-47, 4.9, -1, -45, 5.8, 1));
    // trees
    const free = (x, zz) => { if (Math.hypot(x, zz) < 20 || Math.hypot(x, zz) > R - 3) return false; for (const g of GATES) { const a = g.a * Math.PI / 180, cx = Math.cos(a), cz = Math.sin(a), t = x * cx + zz * cz; if (t > 0 && t < GR + 8 && Math.abs(-x * cz + zz * cx) < 6.5) return false; } if (Math.hypot(x + 46, zz) < 14) return false; return true; };
    let nt = 0; for (let k = 0; k < 400 && nt < 75; k++) {
      const a = r() * 6.283, d = 20 + r() * 38, x = Math.cos(a) * d, zz = Math.sin(a) * d; if (!free(x, zz)) continue; nt++;
      const h = 2 + r() * 1.6, gc = [0x3fc060, 0x4acd64, 0x35b457][nt % 3], big = 1 + r() * 0.5;
      b.box(x, h / 2, zz, 0.9, h, 0.9, 0x9a6a3a); b.box(x, h + 0.9, zz, 3.4 * big, 1.8, 3.4 * big, gc, 0.06); b.box(x, h + 2.4, zz, 2.4 * big, 1.4, 2.4 * big, gc, 0.06); b.box(x, h + 3.5, zz, 1.3 * big, 1.0, 1.3 * big, gc, 0.06);
      z.cols.push(box(x - 0.45, 0, zz - 0.45, x + 0.45, h, zz + 0.45));
    }
    // flowers + bushes
    for (let k = 0; k < 260; k++) { const a = r() * 6.283, d = 16 + r() * 42, x = Math.cos(a) * d, zz = Math.sin(a) * d; if (!free(x, zz) && r() < 0.8) continue; const c = [0xff5c8a, 0xffd23f, 0xffffff, 0xb06cff, 0xff8a3d][(r() * 5) | 0]; b.box(x, 0.18, zz, 0.08, 0.36, 0.08, 0x3a9a40); b.box(x, 0.4, zz, 0.3, 0.2, 0.3, c); }
    for (let k = 0; k < 30; k++) { const a = r() * 6.283, d = 18 + r() * 38, x = Math.cos(a) * d, zz = Math.sin(a) * d; if (!free(x, zz)) continue; b.box(x, 0.5, zz, 1.6, 1, 1.4, 0x2fae54, 0.06); z.cols.push(box(x - 0.8, 0, zz - 0.7, x + 0.8, 0.9, zz + 0.7, { cam: false })); }
    // benches + lamps around plaza
    for (let k = 0; k < 8; k++) { const a = (k + 0.5) / 8 * 6.283, x = Math.cos(a) * 12.2, zz = Math.sin(a) * 12.2, ry = Math.atan2(-Math.cos(a), Math.sin(a)); if (k % 2) { b.boxR(x, 0.5, zz, 2.2, 0.2, 0.7, ry, 0xb5651d); b.boxR(x - Math.cos(a) * 0.3, 0.9, zz - Math.sin(a) * 0.3, 2.2, 0.5, 0.15, ry, 0xb5651d); z.cols.push(box(x - 1, 0, zz - 1, x + 1, 0.55, zz + 1)); } else { b.box(x, 1.6, zz, 0.25, 3.2, 0.25, 0x394060); b.box(x, 3.3, zz, 0.8, 0.8, 0.8, 0xfff0a0); z.cols.push(box(x - 0.15, 0, zz - 0.15, x + 0.15, 3.2, zz + 0.15)); } }
    // fence
    for (let k = 0; k < 120; k++) { const a = k / 120 * 6.283, x = Math.cos(a) * (R - 0.5), zz = Math.sin(a) * (R - 0.5), a2 = (k + 1) / 120 * 6.283, mx = (x + Math.cos(a2) * (R - 0.5)) / 2, mz = (zz + Math.sin(a2) * (R - 0.5)) / 2; b.box(x, 0.9, zz, 0.35, 1.8, 0.35, 0xffffff); b.boxR(mx, 1.3, mz, 3.3, 0.22, 0.14, -(a + a2) / 2 - Math.PI / 2, k % 2 ? 0xff9fc0 : 0x8fd8ff); b.boxR(mx, 0.7, mz, 3.3, 0.22, 0.14, -(a + a2) / 2 - Math.PI / 2, k % 2 ? 0x8fd8ff : 0xff9fc0); }
    // distant mountains
    const cone = new THREE.ConeGeometry(1, 1, 4);
    for (let k = 0; k < 28; k++) { const a = k / 28 * 6.283 + r() * 0.2, d = 175 + r() * 60, h = 40 + r() * 60, w = 50 + r() * 40, c = new THREE.Color().setHSL(0.52 + r() * 0.12, 0.45, 0.5 - r() * 0.1).getHex(); b.geo(cone, Math.cos(a) * d, h / 2 - 2, Math.sin(a) * d, w, h, w, c, r() * 3); b.geo(cone, Math.cos(a) * d, h * 0.86 - 2, Math.sin(a) * d, w * 0.28, h * 0.28, w * 0.28, 0xffffff, 0); }
    // bounce mushrooms
    const cyl = new THREE.CylinderGeometry(1, 1.15, 1, 14);
    for (const [x, zz] of [[-11, 21], [13, -22], [-30, -44], [48, 6]]) { b.box(x, 0.25, zz, 0.7, 0.5, 0.7, 0xfff4d8); b.geo(cyl, x, 0.62, zz, 1.6, 0.36, 1.6, 0xff4f6d); for (let k = 0; k < 5; k++) b.box(x + Math.cos(k * 1.26) * 0.8, 0.82, zz + Math.sin(k * 1.26) * 0.8, 0.28, 0.08, 0.28, 0xffffff); const c = box(x - 0.9, 0, zz - 0.9, x + 0.9, 0.8, zz + 0.9, { bounce: 21 }); z.cols.push(c); z.pads.push({ x, z: zz }); }
    // bridge-ish blocks sculpture near pyramid for climbing
    for (let i = 0; i < 6; i++) { const x = -22 + i * 1.6, h = 0.7 + i * 0.9; b.box(x, h / 2, 38, 1.5, h, 2.4, [0xff5a5f, 0xffd23f, 0x7ed957, 0x3d9bff, 0xff6fb5, 0xb06cff][i]); z.cols.push(box(x - 0.75, 0, 36.8, x + 0.75, h, 39.2)); }
    z.world = b.build(worldMat()); scene.add(z.world);
    // coins
    const cg = new THREE.CylinderGeometry(0.5, 0.5, 0.14, 16); cg.rotateX(Math.PI / 2);
    for (let k = 0; k < 40; k++) { for (let tries = 0; tries < 20; tries++) { const a = r() * 6.283, d = 6 + r() * 50, x = Math.cos(a) * d, zz = Math.sin(a) * d; if (Math.hypot(x, zz) < 6 || Math.hypot(x + 46, zz) < 11) continue; z.coins.push({ x, y: 1.1, z: zz, v: 1, t: 0 }); break; } }
    for (let i = 0; i < 6; i++) z.coins.push({ x: -22 + i * 1.6, y: 0.7 + i * 0.9 + 1.4, z: 38, v: 2, t: 0 });
    z.coins.push({ x: -46, y: 6.6, z: 0, v: 15, t: 0, big: 1 });
    z.coinMesh = new THREE.InstancedMesh(cg, new THREE.MeshStandardMaterial({ color: 0xffd23f, roughness: 0.25, metalness: 0.6, emissive: 0xff9d00, emissiveIntensity: 0.35 }), z.coins.length); z.coinMesh.frustumCulled = false; scene.add(z.coinMesh);
    // gift box
    z.gift = new THREE.Group(); const gm = new THREE.MeshStandardMaterial({ color: 0xff5c8a, roughness: 0.4 }), rm = new THREE.MeshStandardMaterial({ color: 0xffd23f, roughness: 0.4 });
    const gb = new THREE.Mesh(new THREE.BoxGeometry(1.3, 1.1, 1.3), gm); gb.castShadow = true; z.gift.add(gb);
    const lid = new THREE.Mesh(new THREE.BoxGeometry(1.5, 0.35, 1.5), gm); lid.position.y = 0.7; z.gift.add(lid);
    z.gift.add(new THREE.Mesh(new THREE.BoxGeometry(0.3, 1.2, 1.35), rm)); z.gift.add(new THREE.Mesh(new THREE.BoxGeometry(1.35, 1.2, 0.3), rm));
    z.gift.position.set(6.5, 1.1, 8); scene.add(z.gift); z.giftTag = textSprite('Daily gift', { px: 48, size: 0.55 }); z.giftTag.position.set(0, 1.7, 0); z.gift.add(z.giftTag);
    // NPCs
    const rr = rng(21);
    for (let i = 0; i < 9; i++) {
      const cfg = { skin: (rr() * SKINS.length) | 0, face: ['smile', 'happy', 'wink', 'cool', 'silly', 'wow', 'stars'][(rr() * 7) | 0], shirt: (rr() * SHIRTS.length) | 0, pattern: rr() < 0.5 ? 'none' : ITEMS.pattern[1 + ((rr() * 5) | 0)].id, pants: (rr() * PANTS.length) | 0, hat: rr() < 0.7 ? ITEMS.hat[(rr() * ITEMS.hat.length) | 0].id : 'none', pack: rr() < 0.4 ? ITEMS.pack[(rr() * ITEMS.pack.length) | 0].id : 'none', trail: 'none' };
      const A = buildAvatar(cfg); addNameTag(A, NPC_NAMES[i]); scene.add(A.root);
      const a = rr() * 6.283, d = 8 + rr() * 22;
      z.npcs.push({ avatar: A, body: makeBody(Math.cos(a) * d, 0, Math.sin(a) * d), face: rr() * 6.28, state: 'idle', t: rr() * 3, tx: 0, tz: 0, stuck: 0, wCool: rr() * 5, speed: 0, resp: -1, respE: null });
    }
  };

  z.enter = (G, o) => {
    const P = G.P, b = P.body; G.cam.minY = 0.6; G.cam.dist = 9.5; G.cam.pitch = 0.4;
    const gt = o.from && z.gates.find((q) => q.g.id === o.from);
    if (gt) { const a = Math.atan2(gt.z, gt.x), x = Math.cos(a) * (GR - 8), zz = Math.sin(a) * (GR - 8); b.x = x; b.z = zz; b.y = 0; P.face = Math.atan2(-Math.cos(a), -Math.sin(a)); G.cam.yaw = Math.atan2(Math.cos(a), Math.sin(a)); }
    else if (o.title) { b.x = 0; b.z = 11; b.y = 0; P.face = Math.PI; G.cam.yaw = 0; }
    else { b.x = 0; b.z = 11; b.y = 0; P.face = Math.PI; G.cam.yaw = 0; }
    z.cool = 1.2; G.snapCam(); G.zoneHud('');
  };
  z.startPlay = (G) => { G.cam.yaw = 0; G.snapCam(); };

  const pickTarget = (n) => { const a = Math.random() * 6.283, d = 6 + Math.random() * 46; n.tx = Math.cos(a) * d; n.tz = Math.sin(a) * d; };
  function updNpc(n, dt, G) {
    const b = n.body, Pb = G.P.body; n.t -= dt; n.wCool -= dt;
    const dxp = Pb.x - b.x, dzp = Pb.z - b.z, dp = Math.hypot(dxp, dzp); let wx = 0, wz = 0, want = 0;
    if (n.resp >= 0) { n.resp -= dt; if (n.resp < 0 && n.respE) { playEmote(n.avatar, n.respE); n.state = 'emote'; n.t = 2.2; n.respE = null; } }
    switch (n.state) {
      case 'idle': if (n.t <= 0) { const r = Math.random(); if (r < 0.5) { n.state = 'walk'; n.t = 6 + Math.random() * 6; pickTarget(n); } else if (r < 0.64) { playEmote(n.avatar, EMOTES[1]); n.state = 'emote'; n.t = 2.4; } else if (r < 0.72) { playEmote(n.avatar, EMOTES[0]); n.state = 'emote'; n.t = 2.4; } else if (r < 0.78) { b.vy = 12; n.t = 1; } else if (dp < 30) { n.state = 'follow'; n.t = 8 + Math.random() * 5; } else { n.state = 'walk'; n.t = 8; pickTarget(n); } } break;
      case 'walk': { const tx = n.tx - b.x, tz = n.tz - b.z, td = Math.hypot(tx, tz); if (td < 1.2 || n.t <= 0) { n.state = 'idle'; n.t = 1 + Math.random() * 3; } else { wx = tx / td; wz = tz / td; want = 1; } break; }
      case 'follow': if (dp > 3.4) { wx = dxp / dp; wz = dzp / dp; want = dp > 9 ? 1.5 : 1; } if (n.t <= 0) { n.state = 'idle'; n.t = 1; } break;
      case 'emote': n.face += angDiff(n.face, Math.atan2(dxp, dzp)) * Math.min(1, dt * 6); if (n.t <= 0) { n.state = 'idle'; n.t = 0.5; } break;
    }
    if (dp < 5.5 && n.wCool <= 0 && (n.state === 'idle' || n.state === 'walk') && G.state === 'play') { playEmote(n.avatar, EMOTES[0]); n.state = 'emote'; n.t = 2.2; n.wCool = 14; G.fx.burst(b.x, b.y + 2, b.z, 3, 0xffe14a, 1, 0.5, 0.2, 0); }
    const sp = 4.4 * want; b.vx = damp(b.vx, wx * sp, 8, dt); b.vz = damp(b.vz, wz * sp, 8, dt);
    if (want && b.hitWall && b.onGround) { n.stuck += dt; if (n.stuck > 0.25) { b.vy = 12.5; n.stuck = 0; } } else n.stuck = Math.max(0, n.stuck - dt);
    b.vy = Math.max(b.vy - 38 * dt, -50); moveBody(b, dt, z.cols);
    const d2 = Math.hypot(b.x, b.z); if (d2 > R - 2) { b.x *= (R - 2) / d2; b.z *= (R - 2) / d2; }
    n.speed = Math.hypot(b.vx, b.vz); if (n.speed > 0.8) n.face += angDiff(n.face, Math.atan2(b.vx, b.vz)) * Math.min(1, dt * 10);
    const A = n.avatar; A.root.position.set(b.x, b.y, b.z); A.root.rotation.y = n.face; updateAvatar(A, dt, n.speed, !b.onGround, b.vy);
  }

  z.onEmote = (G, e) => {
    const Pb = G.P.body; let any = false;
    for (const n of z.npcs) { const d = Math.hypot(n.body.x - Pb.x, n.body.z - Pb.z); if (d < 12) { any = true; if (n.resp < 0 && n.state !== 'emote') { n.resp = 0.5 + Math.random() * 0.9; n.respE = EMOTES[(Math.random() * 6) | 0]; } if (d < 8 && e.id === 'wave') G.ach('friend'); } }
  };

  const _m = new THREE.Matrix4(), _p = new THREE.Vector3(), _q = new THREE.Quaternion(), _s = new THREE.Vector3(), _e = new THREE.Euler();
  z.update = (dt, G, last) => {
    z.t += dt; z.cool -= dt; z.giftCool -= dt; const P = G.P, b = P.body;
    if (G.state === 'play') {
      G.walk(dt, z.cols, null, {});
      const d = Math.hypot(b.x, b.z); if (d > R - 1.5) { b.x *= (R - 1.5) / d; b.z *= (R - 1.5) / d; }
      if (b.y < -15) { b.x = 0; b.z = 11; b.y = 0; b.vy = 0; }
      if (z.cool <= 0) for (const q of z.gates) {
        if (Math.hypot(b.x - q.x, b.z - q.z) < 2.7 && b.y < 3) {
          z.cool = 3; G.sfx('whoosh');
          if (q.g.id === 'shop') { const a = Math.atan2(q.z, q.x); b.x = Math.cos(a) * (GR - 5); b.z = Math.sin(a) * (GR - 5); G.openEditor(); } else { G.banner(q.g.name); G.go(q.g.id, { from: 'hub' }); }
          break;
        }
      }
      // coins
      for (const c of z.coins) { if (c.t > 0) continue; if (Math.abs(c.x - b.x) < 1.4 && Math.abs(c.z - b.z) < 1.4 && Math.abs(c.y - (b.y + 0.9)) < 1.9) { c.t = c.big ? 45 : 25; G.addCoins(c.v, c.x, c.y + 0.6, c.z); G.sfx('coin'); G.stat('coinsPicked', c.v); if (S().stats.coinsPicked >= 50) G.ach('coins50'); G.fx.burst(c.x, c.y, c.z, 8, 0xffd23f, 3, 0.6, 0.3, 6); } }
      // gift
      const gx = z.gift.position.x - b.x, gz = z.gift.position.z - b.z;
      if (Math.hypot(gx, gz) < 2.2 && z.giftCool <= 0) { z.giftCool = 4; if (G.dailyAvailable()) G.claimDaily(); else G.toast('Come back tomorrow for another gift!', 'gift'); }
    }
    for (const n of z.npcs) updNpc(n, dt, G);
    if (!last) return;
    for (const m of z.swirls) m.material.uniforms.t.value = z.t;
    // coin instances
    let i = 0; for (const c of z.coins) { if (c.t > 0) c.t -= dt * 4; const vis = c.t <= 0; const sc = vis ? (c.big ? 2 : 1) : 0.0001; _p.set(c.x, c.y + Math.sin(z.t * 2.5 + c.x) * 0.15, c.z); _e.set(0, z.t * 2.2 + c.x, 0); _q.setFromEuler(_e); _s.set(sc, sc, sc); _m.compose(_p, _q, _s); z.coinMesh.setMatrixAt(i++, _m); }
    z.coinMesh.instanceMatrix.needsUpdate = true;
    const av = G.dailyAvailable(); z.gift.rotation.y = z.t * (av ? 1.6 : 0.4); z.gift.position.y = 1.1 + Math.sin(z.t * 2.2) * (av ? 0.25 : 0.06); z.giftTag.visible = true; z.gift.scale.setScalar(av ? 1 + Math.sin(z.t * 6) * 0.05 : 0.9);
    if (av && Math.random() < 0.25) G.fx.emit(z.gift.position.x + (Math.random() - 0.5), z.gift.position.y + 0.8, z.gift.position.z + (Math.random() - 0.5), 0, 1.5, 0, 0.8, [0xffd23f, 0xff7aa8, 0xffffff][(Math.random() * 3) | 0], 0.3, 0);
    for (let k = 0; k < 2; k++) G.fx.emit((Math.random() - 0.5) * 0.6, 3.5, (Math.random() - 0.5) * 0.6, (Math.random() - 0.5) * 2.2, 7 + Math.random() * 2, (Math.random() - 0.5) * 2.2, 1.3, Math.random() < 0.5 ? 0x8fe0ff : 0xffffff, 0.28, 14);
  };
  const S = () => G.S;
  z.exit = () => {};
  return z;
}
