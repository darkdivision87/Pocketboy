// Fox Dash: procedural characters (the fox, its skins, the rival robot) and the SVG face icons.
import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';

export const SKINS = [
  { id: 'classic', name: 'Rusty', price: 0, body: '#ff8a2a', belly: '#fff3dc', dark: '#3b2a30', tip: '#fff3dc', scarf: '#2ab6ff' },
  { id: 'frost', name: 'Frosty', price: 100, body: '#bfe3ff', belly: '#ffffff', dark: '#4a6a9a', tip: '#7fd6ff', scarf: '#ff5c8a' },
  { id: 'berry', name: 'Berry', price: 200, body: '#d44a9c', belly: '#ffe0f2', dark: '#4a1a48', tip: '#ffe0f2', scarf: '#ffd23f' },
  { id: 'mint', name: 'Minty', price: 300, body: '#3fd6a0', belly: '#f3fff0', dark: '#1f5a50', tip: '#f3fff0', scarf: '#ff7a2a' },
  { id: 'gold', name: 'Goldie', price: 500, body: '#ffc83a', belly: '#fff8d8', dark: '#8a4a10', tip: '#ffffff', scarf: '#ef3d4d' },
  { id: 'ninja', name: 'Ninja', price: 800, body: '#5b4b9a', belly: '#c4b6ff', dark: '#171030', tip: '#8ff5ff', scarf: '#ff3d7f' },
  { id: 'galaxy', name: 'Cosmo', price: 1200, body: '#2c2f8a', belly: '#c8d0ff', dark: '#10123a', tip: '#ffe27a', scarf: '#7af0ff', special: 'galaxy' },
  { id: 'rainbow', name: 'Prism', price: 2000, body: '#ff6a6a', belly: '#ffffff', dark: '#2a2040', tip: '#ffffff', scarf: '#ffffff', special: 'rainbow' },
];

let gradMap;
export function toonGradient() {
  if (!gradMap) {
    const d = new Uint8Array([110, 110, 110, 255, 175, 175, 175, 255, 225, 225, 225, 255, 255, 255, 255, 255]);
    gradMap = new THREE.DataTexture(d, 4, 1, THREE.RGBAFormat);
    gradMap.minFilter = gradMap.magFilter = THREE.NearestFilter; gradMap.needsUpdate = true;
  }
  return gradMap;
}

function galaxyTexture() {
  const c = document.createElement('canvas'); c.width = 256; c.height = 128; const g = c.getContext('2d');
  const gr = g.createLinearGradient(0, 0, 256, 128); gr.addColorStop(0, '#2a2f9a'); gr.addColorStop(0.5, '#5a2a9a'); gr.addColorStop(1, '#1a1a6a');
  g.fillStyle = gr; g.fillRect(0, 0, 256, 128);
  for (let i = 0; i < 70; i++) { g.fillStyle = `rgba(255,255,255,${0.5 + Math.random() * 0.5})`; g.beginPath(); g.arc(Math.random() * 256, Math.random() * 128, Math.random() * 1.8 + 0.5, 0, 7); g.fill(); }
  for (let i = 0; i < 6; i++) { g.fillStyle = '#ffe27a'; const x = Math.random() * 256, y = Math.random() * 128; g.fillRect(x - 3, y - 0.8, 6, 1.6); g.fillRect(x - 0.8, y - 3, 1.6, 6); }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}

export function buildFox() {
  const grad = toonGradient();
  const mk = (c) => new THREE.MeshToonMaterial({ color: c, gradientMap: grad });
  const M = { body: mk('#ff8a2a'), belly: mk('#fff'), dark: mk('#333'), tip: mk('#fff'), scarf: mk('#2af'), white: mk('#fff'), pink: mk('#ff9eb5'),
    pupil: new THREE.MeshBasicMaterial({ color: '#1a1224' }), hl: new THREE.MeshBasicMaterial({ color: '#ffffff' }) };
  const root = new THREE.Group(), pivot = new THREE.Group(), body = new THREE.Group();
  pivot.position.y = 0.55; body.position.y = -0.55; root.add(pivot); pivot.add(body);
  const sph = new THREE.SphereGeometry(1, 22, 16), cone = new THREE.ConeGeometry(1, 1, 16), cap = new THREE.CapsuleGeometry(0.075, 0.26, 4, 10);
  const add = (parent, geo, mat, p = [0, 0, 0], s = [1, 1, 1], r = [0, 0, 0]) => { const m = new THREE.Mesh(geo, mat); m.position.set(...p); m.scale.set(...s); m.rotation.set(...r); parent.add(m); return m; };

  add(body, sph, M.body, [0, 0.62, 0.06], [0.36, 0.34, 0.56]);
  add(body, sph, M.belly, [0, 0.55, -0.12], [0.3, 0.27, 0.42]);
  // head
  const head = new THREE.Group(); head.position.set(0, 0.98, -0.5); body.add(head);
  add(head, sph, M.body, [0, 0, 0], [0.37, 0.31, 0.33]);
  add(head, sph, M.belly, [-0.2, -0.1, -0.12], [0.2, 0.14, 0.2]);
  add(head, sph, M.belly, [0.2, -0.1, -0.12], [0.2, 0.14, 0.2]);
  add(head, cone, M.body, [0, -0.07, -0.31], [0.14, 0.32, 0.14], [-Math.PI / 2, 0, 0]);
  add(head, sph, M.dark, [0, -0.045, -0.47], [0.055, 0.045, 0.05]);
  const eyes = [];
  for (const sx of [-1, 1]) {
    const eg = new THREE.Group(); eg.position.set(sx * 0.15, 0.05, -0.255); head.add(eg);
    add(eg, sph, M.white, [0, 0, 0], [0.1, 0.12, 0.07]);
    add(eg, sph, M.pupil, [sx * -0.005, -0.005, -0.04], [0.062, 0.08, 0.04]);
    add(eg, sph, M.hl, [sx * 0.018, 0.035, -0.06], [0.02, 0.02, 0.012]);
    eyes.push(eg);
  }
  const ears = [];
  for (const sx of [-1, 1]) {
    const eg = new THREE.Group(); eg.position.set(sx * 0.2, 0.27, 0.0); eg.rotation.z = -sx * 0.28; head.add(eg);
    add(eg, cone, M.body, [0, 0.18, 0], [0.15, 0.36, 0.1]);
    add(eg, cone, M.pink, [0, 0.16, -0.03], [0.09, 0.27, 0.05]);
    add(eg, cone, M.dark, [0, 0.185 - 0.1134, 0.0], [0.095, 0.2268, 0.063]);
    ears.push(eg);
  }
  // scarf
  const scarf = new THREE.Group(); scarf.position.set(0, 0.84, -0.3); body.add(scarf);
  add(scarf, new THREE.TorusGeometry(0.25, 0.075, 10, 24), M.scarf, [0, 0, 0], [1, 1, 1], [Math.PI / 2 - 0.4, 0, 0]);
  const scarfTails = [];
  for (const sx of [-0.06, 0.07]) {
    const g = new THREE.Group(); g.position.set(sx, 0.02, 0.2); scarf.add(g);
    add(g, new THREE.BoxGeometry(0.12, 0.025, 0.55), M.scarf, [0, 0, 0.27]);
    scarfTails.push(g);
  }
  // legs
  const legs = [];
  for (const [x, z, front] of [[-0.17, -0.3, 1], [0.17, -0.3, 1], [-0.17, 0.38, 0], [0.17, 0.38, 0]]) {
    const g = new THREE.Group(); g.position.set(x, 0.52, z); body.add(g);
    add(g, cap, M.body, [0, -0.2, 0]);
    add(g, sph, M.dark, [0, -0.41, -0.035], [0.1, 0.075, 0.14]);
    legs.push({ g, front, side: Math.sign(x) });
  }
  // tail
  const tail = new THREE.Group(); tail.position.set(0, 0.66, 0.55); body.add(tail);
  const segs = []; let parent = tail; const rs = [0.14, 0.19, 0.2, 0.15];
  for (let i = 0; i < 4; i++) {
    const g = new THREE.Group(); g.position.z = i === 0 ? 0 : 0.17; parent.add(g);
    add(g, sph, i === 3 ? M.tip : M.body, [0, 0, 0.1], [rs[i], rs[i], rs[i] * 1.35]);
    segs.push(g); parent = g;
  }
  // soft contact shadow lives in the game; here only the character
  const fox = { root, pivot, body, head, ears, eyes, scarf, scarfTails, legs, tail, segs, M, phase: 0, t: 0, roll: 0, skin: null, hue: 0, galaxyTex: null,
    squash: 0 };

  fox.setSkin = (s) => {
    fox.skin = s;
    M.body.color.set(s.body); M.belly.color.set(s.belly); M.dark.color.set(s.dark); M.tip.color.set(s.tip); M.scarf.color.set(s.scarf);
    if (s.special === 'galaxy') { if (!fox.galaxyTex) fox.galaxyTex = galaxyTexture(); M.body.color.set('#ffffff'); M.body.map = fox.galaxyTex; M.body.emissiveMap = fox.galaxyTex; M.body.emissive.set('#8a8aff'); M.body.emissiveIntensity = 0.7; }
    else { M.body.map = null; M.body.emissiveMap = null; M.body.emissive.set('#000000'); }
    M.body.needsUpdate = true;
    M.tip.emissive.set(s.id === 'ninja' ? '#2a9aa6' : '#000000');
  };

  const _c = new THREE.Color();
  // mode: run | jump | roll | spin | idle | tumble | grind
  fox.update = (dt, mode = 'run', speed = 14, vy = 0) => {
    fox.t += dt; const t = fox.t;
    fox.phase += dt * (7 + speed * 0.28);
    const ph = fox.phase, s = Math.sin(ph);
    if (fox.skin && fox.skin.special === 'rainbow') {
      fox.hue = (fox.hue + dt * 0.35) % 1;
      M.body.color.setHSL(fox.hue, 0.85, 0.58); M.tip.color.setHSL((fox.hue + 0.5) % 1, 0.9, 0.7); M.scarf.color.setHSL((fox.hue + 0.3) % 1, 0.9, 0.62);
      M.belly.color.setHSL((fox.hue + 0.12) % 1, 0.8, 0.9);
    }
    const curl = mode === 'roll' || mode === 'spin';
    if (curl) fox.roll -= dt * (mode === 'spin' ? 30 : 17);
    else { // settle the flip back to upright
      const k = Math.round(fox.roll / (Math.PI * 2)) * Math.PI * 2; fox.roll = k + (fox.roll - k) * Math.exp(-dt * 14);
      if (Math.abs(fox.roll - k) < 0.01) fox.roll = 0;
    }
    const tumble = mode === 'tumble'; if (tumble) fox.roll -= dt * 9 * Math.max(0, 1 - (t - (fox.tumbleT0 || 0)) * 1.2);
    let bob = 0, pitch = 0;
    const L = legs;
    if (mode === 'run' || mode === 'idle') {
      const a = mode === 'idle' ? 0.5 : 1;
      L[0].g.rotation.x = s * 0.95 * a; L[1].g.rotation.x = Math.sin(ph + 0.35) * 0.95 * a;
      L[2].g.rotation.x = Math.sin(ph + 2.4) * 0.95 * a; L[3].g.rotation.x = Math.sin(ph + 2.75) * 0.95 * a;
      bob = Math.abs(Math.sin(ph + 0.6)) * 0.08 * a; pitch = Math.sin(ph + 1.2) * 0.07;
    } else if (mode === 'jump') {
      const k = Math.max(-1, Math.min(1, vy / 12));
      for (const l of L) l.g.rotation.x = (l.front ? 0.9 + k * 0.3 : -0.9 - k * 0.25) + Math.sin(t * 24 + l.side) * 0.05;
      pitch = -k * 0.35; bob = 0.02;
    } else if (mode === 'grind') {
      for (const l of L) l.g.rotation.x = l.front ? 0.5 : -0.5;
      pitch = 0.06; bob = -0.12;
    } else if (curl) {
      for (const l of L) l.g.rotation.x = l.front ? 1.75 : -1.75;
    } else if (tumble) {
      for (const l of L) l.g.rotation.x = Math.sin(t * 18 + l.side * 2 + (l.front ? 0 : 1.5)) * 1.1;
    }
    pivot.rotation.x = fox.roll + pitch;
    const sc = curl ? 0.78 : 1; pivot.scale.setScalar(THREE.MathUtils.lerp(pivot.scale.x, sc, Math.min(1, dt * 18)));
    body.position.y = -0.55 + bob;
    head.rotation.x = curl ? 0.55 : -pitch * 0.8 + (mode === 'idle' ? Math.sin(t * 2) * 0.03 : 0);
    head.position.y = 0.98 + (curl ? -0.1 : 0);
    // ears
    ears[0].rotation.x = ears[1].rotation.x = curl ? -0.5 : 0.25 + Math.sin(ph + 1) * 0.22 + (mode === 'jump' ? 0.5 : 0);
    // eyes blink
    const bl = (Math.sin(t * 1.3) > 0.985 || Math.sin(t * 0.7 + 2) > 0.992) ? 0.1 : 1;
    eyes[0].scale.y = eyes[1].scale.y = bl;
    // scarf + tail
    const sp = Math.min(1, speed / 30);
    scarf.rotation.x = 0;
    scarfTails.forEach((g, i) => { g.rotation.x = -0.1 - sp * 0.5 + Math.sin(t * 14 + i * 1.7) * (0.14 + sp * 0.15); g.rotation.y = Math.sin(t * 9 + i * 2.2) * 0.2; });
    tail.rotation.x = curl ? -0.2 : -0.55 + (mode === 'jump' ? 0.25 : 0) - sp * 0.2;
    const wag = mode === 'idle' ? 0.5 : 0.28;
    segs.forEach((g, i) => { g.rotation.y = Math.sin(t * (mode === 'idle' ? 5 : 9) - i * 0.85) * wag; g.rotation.x = curl ? 0.45 : Math.sin(t * 7 - i * 0.9) * 0.1 - 0.12; });
  };
  fox.setSkin(SKINS[0]);
  return fox;
}

// Cute rival robot that chases the fox
export function buildRobot() {
  const grad = toonGradient();
  const mk = (c) => new THREE.MeshToonMaterial({ color: c, gradientMap: grad });
  const hull = mk('#5b86ff'), dark = mk('#262d52'), trim = mk('#ffd23f'), light = mk('#cfe0ff');
  const glow = new THREE.MeshBasicMaterial({ color: new THREE.Color(3.2, 0.25, 0.25) });
  const siren = new THREE.MeshBasicMaterial({ color: new THREE.Color(3, 0.3, 0.3) });
  const flameMat = new THREE.MeshBasicMaterial({ color: new THREE.Color(2.4, 1.2, 0.3), transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, depthWrite: false });
  const root = new THREE.Group(), core = new THREE.Group(); root.add(core);
  const rb = (w, h, d, r = 0.08) => new RoundedBoxGeometry(w, h, d, 3, r);
  const add = (p, geo, mat, pos = [0, 0, 0], sc = [1, 1, 1], rot = [0, 0, 0]) => { const m = new THREE.Mesh(geo, mat); m.position.set(...pos); m.scale.set(...sc); m.rotation.set(...rot); p.add(m); return m; };
  const sph = new THREE.SphereGeometry(1, 16, 12), cyl = new THREE.CylinderGeometry(1, 1, 1, 14), cone = new THREE.ConeGeometry(1, 1, 14);
  add(core, rb(1.0, 0.95, 0.8, 0.18), hull, [0, 0.95, 0]);
  add(core, rb(0.7, 0.4, 0.05, 0.06), light, [0, 0.95, -0.4]);
  add(core, sph, trim, [0, 0.95, -0.43], [0.09, 0.09, 0.04]);
  // head
  const head = new THREE.Group(); head.position.set(0, 1.7, 0); core.add(head);
  add(head, rb(0.9, 0.62, 0.7, 0.2), light, [0, 0, 0]);
  add(head, rb(0.72, 0.28, 0.1, 0.08), dark, [0, 0.03, -0.33]);
  const eyeL = add(head, sph, glow, [-0.2, 0.03, -0.38], [0.1, 0.07, 0.03]), eyeR = add(head, sph, glow, [0.2, 0.03, -0.38], [0.1, 0.07, 0.03]);
  add(head, new THREE.BoxGeometry(0.28, 0.05, 0.04), dark, [-0.2, 0.17, -0.38], [1, 1, 1], [0, 0, -0.35]);
  add(head, new THREE.BoxGeometry(0.28, 0.05, 0.04), dark, [0.2, 0.17, -0.38], [1, 1, 1], [0, 0, 0.35]);
  add(head, cyl, dark, [0, 0.42, 0], [0.04, 0.3, 0.04]);
  const bulb = add(head, sph, siren, [0, 0.62, 0], [0.1, 0.1, 0.1]);
  add(head, cyl, dark, [-0.47, 0, 0], [0.07, 0.2, 0.07], [0, 0, Math.PI / 2]); add(head, cyl, dark, [0.47, 0, 0], [0.07, 0.2, 0.07], [0, 0, Math.PI / 2]);
  // arms reaching forward
  const arms = [];
  for (const sx of [-1, 1]) {
    const g = new THREE.Group(); g.position.set(sx * 0.62, 1.15, -0.05); core.add(g);
    add(g, new THREE.CapsuleGeometry(0.1, 0.5, 4, 8), hull, [0, 0, -0.3], [1, 1, 1], [Math.PI / 2, 0, 0]);
    add(g, sph, trim, [0, 0, -0.68], [0.15, 0.15, 0.15]);
    arms.push(g);
  }
  // jet pack and flames
  add(core, rb(0.7, 0.7, 0.3, 0.1), dark, [0, 1.0, 0.5]);
  const flames = [];
  for (const sx of [-0.2, 0.2]) {
    add(core, cyl, trim, [sx, 0.55, 0.5], [0.12, 0.18, 0.12]);
    const f = add(core, cone, flameMat, [sx, 0.25, 0.5], [0.13, 0.55, 0.13], [Math.PI, 0, 0]); flames.push(f);
  }
  add(core, cyl, dark, [0, 0.42, -0.05], [0.3, 0.12, 0.3]);
  const robot = { root, core, head, arms, flames, eyeL, eyeR, bulb, siren, t: 0 };
  robot.update = (dt, speed) => {
    robot.t += dt; const t = robot.t;
    core.position.y = 0.25 + Math.sin(t * 6) * 0.1; core.rotation.x = -0.12 - speed * 0.003; core.rotation.z = Math.sin(t * 3) * 0.05;
    head.rotation.y = Math.sin(t * 2.2) * 0.12;
    arms[0].rotation.x = Math.sin(t * 9) * 0.25; arms[1].rotation.x = Math.sin(t * 9 + 2) * 0.25;
    flames.forEach((f, i) => { f.scale.y = 0.5 + Math.random() * 0.25; f.scale.x = f.scale.z = 0.12 + Math.random() * 0.03; });
    const on = Math.sin(t * 12) > 0; siren.color.setRGB(on ? 3 : 0.2, on ? 0.2 : 0.3, on ? 0.2 : 3);
  };
  return robot;
}

// Little SVG fox face used on the skin cards
export function foxFaceSVG(s) {
  const id = 'g' + s.id;
  let fill = s.body, defs = '';
  if (s.special === 'rainbow') { defs = `<linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff5a5a"/><stop offset=".25" stop-color="#ffd23f"/><stop offset=".5" stop-color="#4be08a"/><stop offset=".75" stop-color="#3fb7ff"/><stop offset="1" stop-color="#b06bff"/></linearGradient>`; fill = `url(#${id})`; }
  if (s.special === 'galaxy') { defs = `<linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2a2f9a"/><stop offset="1" stop-color="#6a2aa0"/></linearGradient>`; fill = `url(#${id})`; }
  const stars = s.special === 'galaxy' ? '<g fill="#fff"><circle cx="30" cy="40" r="1.6"/><circle cx="66" cy="36" r="1.2"/><circle cx="50" cy="48" r="1.8"/><circle cx="76" cy="58" r="1.2"/><circle cx="24" cy="60" r="1.2"/></g>' : '';
  return `<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><defs>${defs}</defs>
<path d="M10 6 L42 30 L16 54 Z" fill="${fill}"/><path d="M90 6 L58 30 L84 54 Z" fill="${fill}"/>
<path d="M17 20 L33 31 L20 44 Z" fill="#ff9eb5"/><path d="M83 20 L67 31 L80 44 Z" fill="#ff9eb5"/>
<path d="M10 6 L24 16 L14 22 Z" fill="${s.dark}"/><path d="M90 6 L76 16 L86 22 Z" fill="${s.dark}"/>
<path d="M50 26 C80 26 94 46 92 62 C90 80 70 94 50 94 C30 94 10 80 8 62 C6 46 20 26 50 26 Z" fill="${fill}"/>${stars}
<path d="M8 62 C22 62 38 66 50 76 C62 66 78 62 92 62 C90 80 70 94 50 94 C30 94 10 80 8 62 Z" fill="${s.belly}"/>
<ellipse cx="33" cy="55" rx="7" ry="9" fill="#fff"/><ellipse cx="67" cy="55" rx="7" ry="9" fill="#fff"/>
<ellipse cx="34" cy="56" rx="4.6" ry="6.4" fill="#1a1224"/><ellipse cx="66" cy="56" rx="4.6" ry="6.4" fill="#1a1224"/>
<circle cx="35.5" cy="52.5" r="1.8" fill="#fff"/><circle cx="67.5" cy="52.5" r="1.8" fill="#fff"/>
<ellipse cx="50" cy="73" rx="6.5" ry="4.8" fill="${s.dark}"/><path d="M50 77 Q50 84 43 85 M50 77 Q50 84 57 85" stroke="${s.dark}" stroke-width="2.2" fill="none" stroke-linecap="round"/></svg>`;
}
