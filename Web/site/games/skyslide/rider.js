import * as THREE from 'three';
import { lerp, clamp, damp } from './util.js';

const std = (c, o = {}) => new THREE.MeshStandardMaterial(Object.assign({ color: c, roughness: 0.55, metalness: 0.0 }, o));

function wingGeometry() {
  const sh = new THREE.Shape();
  sh.moveTo(0, 0.05);
  sh.bezierCurveTo(0.5, 0.42, 1.5, 0.55, 2.45, 0.1);
  sh.quadraticCurveTo(2.5, -0.3, 2.2, -0.42);
  sh.quadraticCurveTo(2.15, -0.2, 1.95, -0.22);
  sh.quadraticCurveTo(1.95, -0.7, 1.55, -0.78);
  sh.quadraticCurveTo(1.55, -0.45, 1.3, -0.5);
  sh.quadraticCurveTo(1.25, -0.95, 0.8, -1.0);
  sh.quadraticCurveTo(0.85, -0.65, 0.55, -0.62);
  sh.quadraticCurveTo(0.45, -0.9, 0.05, -0.7);
  sh.lineTo(0, 0.05);
  const g = new THREE.ExtrudeGeometry(sh, { depth: 0.05, bevelEnabled: true, bevelThickness: 0.03, bevelSize: 0.03, bevelSegments: 1, curveSegments: 8 });
  g.rotateX(Math.PI / 2);
  return g;
}

export function buildRider() {
  const root = new THREE.Group();
  const body = new THREE.Group(); root.add(body);       // squashes / leans
  // swim tube
  const tg = new THREE.TorusGeometry(0.64, 0.28, 14, 30); tg.rotateX(Math.PI / 2);
  const cols = new Float32Array(tg.attributes.position.count * 3), p = tg.attributes.position, cA = new THREE.Color(0xff4d7a), cB = new THREE.Color(0xfff4d6);
  for (let i = 0; i < p.count; i++) { const a = Math.atan2(p.getZ(i), p.getX(i)); const c = (Math.floor((a + Math.PI) / (Math.PI * 2) * 12) % 2) ? cA : cB; cols[i * 3] = c.r; cols[i * 3 + 1] = c.g; cols[i * 3 + 2] = c.b; }
  tg.setAttribute('color', new THREE.BufferAttribute(cols, 3));
  const tube = new THREE.Mesh(tg, std(0xffffff, { vertexColors: true, roughness: 0.35 })); tube.position.y = 0.27; body.add(tube);
  const skin = std(0xffc9a0, { roughness: 0.7 }), shirt = std(0x2fb7ff), shorts = std(0xffd23f), shoe = std(0xff5fa2), helm = std(0xff4fa0, { roughness: 0.3 });
  // torso
  const torso = new THREE.Mesh(new THREE.CapsuleGeometry(0.28, 0.32, 6, 14), shirt); torso.position.set(0, 0.84, -0.02); torso.rotation.x = -0.18; body.add(torso);
  const trunks = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.32, 0.22, 14), shorts); trunks.position.set(0, 0.52, 0.0); body.add(trunks);
  // head
  const head = new THREE.Group(); head.position.set(0, 1.42, 0.03); body.add(head);
  head.add(new THREE.Mesh(new THREE.SphereGeometry(0.34, 20, 16), skin));
  const cap = new THREE.Mesh(new THREE.SphereGeometry(0.375, 22, 14, 0, Math.PI * 2, 0, Math.PI * 0.55), helm); cap.position.y = 0.035; cap.rotation.x = -0.18; head.add(cap);
  const brim = new THREE.Mesh(new THREE.TorusGeometry(0.36, 0.035, 8, 24), std(0xffffff, { roughness: 0.3 })); brim.rotation.x = Math.PI / 2 - 0.18; brim.position.set(0, 0.0, 0.025); head.add(brim);
  const eyeM = std(0xffffff, { roughness: 0.2 }), pupM = std(0x201040, { roughness: 0.2 });
  for (const sx of [-1, 1]) {
    const e = new THREE.Mesh(new THREE.SphereGeometry(0.075, 10, 8), eyeM); e.position.set(sx * 0.125, 0.03, 0.29); e.scale.set(1, 1.25, 0.6); head.add(e);
    const pu = new THREE.Mesh(new THREE.SphereGeometry(0.042, 8, 6), pupM); pu.position.set(sx * 0.125, 0.025, 0.325); head.add(pu);
    const ch = new THREE.Mesh(new THREE.SphereGeometry(0.05, 8, 6), std(0xff8aa8, { roughness: 0.8 })); ch.position.set(sx * 0.21, -0.07, 0.25); ch.scale.set(1, 0.7, 0.4); head.add(ch);
  }
  const smile = new THREE.Mesh(new THREE.TorusGeometry(0.085, 0.017, 6, 14, Math.PI), std(0x7a1f3a)); smile.rotation.z = Math.PI; smile.position.set(0, -0.09, 0.315); head.add(smile);
  // propeller beanie
  const prop = new THREE.Group(); prop.position.set(0, 0.4, 0); head.add(prop);
  const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.1, 6), std(0xffffff)); stem.position.y = -0.02; head.add(stem); stem.position.y = 0.37;
  const bl = new THREE.BoxGeometry(0.62, 0.025, 0.11);
  const b1 = new THREE.Mesh(bl, std(0xffe14a, { roughness: 0.3 })), b2 = new THREE.Mesh(bl, std(0x3fe0ff, { roughness: 0.3 })); b2.rotation.y = Math.PI / 2; prop.add(b1, b2); prop.position.y = 0.43;
  // limbs (pivots)
  const limbG = new THREE.CapsuleGeometry(0.085, 0.3, 4, 8);
  const mkArm = (sx) => { const g = new THREE.Group(); g.position.set(sx * 0.33, 1.02, 0); const m = new THREE.Mesh(limbG, skin); m.position.y = -0.24; g.add(m); const h = new THREE.Mesh(new THREE.SphereGeometry(0.1, 8, 6), skin); h.position.y = -0.46; g.add(h); body.add(g); return g; };
  const armL = mkArm(-1), armR = mkArm(1);
  const legG = new THREE.CapsuleGeometry(0.1, 0.3, 4, 8);
  const mkLeg = (sx) => { const g = new THREE.Group(); g.position.set(sx * 0.15, 0.58, 0.05); const m = new THREE.Mesh(legG, skin); m.position.y = -0.27; g.add(m); const f = new THREE.Mesh(new THREE.SphereGeometry(0.13, 10, 8), shoe); f.position.set(0, -0.5, 0.04); f.scale.set(1, 0.8, 1.35); g.add(f); body.add(g); return g; };
  const legL = mkLeg(-1), legR = mkLeg(1);
  // wings
  const wg = wingGeometry(); const wp = wg.attributes.position, wc = new Float32Array(wp.count * 3);
  const mkWingMat = () => new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.4, side: THREE.DoubleSide, emissive: 0xaab4ff, emissiveIntensity: 0.4 });
  const wingMat = mkWingMat();
  const setWingColor = (hex) => { const tip = new THREE.Color(hex), w = new THREE.Color(0xffffff); for (let i = 0; i < wp.count; i++) { const t = clamp((wp.getX(i) - 0.6) / 1.9, 0, 1); const c = w.clone().lerp(tip, Math.min(1, t * 1.25)); wc[i * 3] = c.r; wc[i * 3 + 1] = c.g; wc[i * 3 + 2] = c.b; } wg.setAttribute('color', new THREE.BufferAttribute(wc, 3)); wg.attributes.color.needsUpdate = true; };
  setWingColor(0xff7ac8);
  const wingPivot = (sx) => { const pv = new THREE.Group(); pv.position.set(sx * 0.2, 1.05, -0.2); const m = new THREE.Mesh(wg, wingMat); m.scale.x = sx; pv.add(m); body.add(pv); return pv; };
  const wingL = wingPivot(-1), wingR = wingPivot(1);
  // blob shadow (separate; parented by the game)
  const R = {
    root, body, tube, head, armL, armR, legL, legR, wingL, wingR, prop, torso, setWingColor,
    squash: 0, open: 0, flapT: 0, wingScale: 1, propSpin: 0,
    pose(dt, o) {
      // o: mode 'slide'|'fly'|'idle', lean (side), dive 0..1, flapping 0..1, speed01, t
      const mode = o.mode, k = 1 - Math.exp(-10 * dt);
      const tOpen = mode === 'fly' ? 1 : 0; this.open = damp(this.open, tOpen, mode === 'fly' ? 7 : 12, dt);
      const op = this.open;
      const ws = this.wingScale;
      for (const [w, sx] of [[wingL, -1], [wingR, 1]]) {
        w.visible = op > 0.02; w.scale.set(Math.max(0.02, op) * ws, Math.max(0.02, op) * ws, Math.max(0.02, op) * ws);
        const flap = Math.sin(this.flapT * 16) * 0.5 * o.flapping;
        w.rotation.z = sx * (0.34 * (1 - o.dive) - 0.15 * o.dive + flap + (1 - op) * 1.2);
        w.rotation.y = sx * (-0.15 + 0.15 * o.dive);
      }
      this.flapT += dt;
      const slide = mode !== 'fly';
      // arms and legs
      const aX = slide ? -1.05 + Math.sin(o.t * 5) * 0.05 : -0.25 + o.dive * 1.3, aZ = slide ? 0.45 : 1.15 - o.dive * 0.9;
      armL.rotation.x += (aX - armL.rotation.x) * k; armR.rotation.x += (aX - armR.rotation.x) * k;
      armL.rotation.z += (-aZ - armL.rotation.z) * k; armR.rotation.z += (aZ - armR.rotation.z) * k;
      const lX = slide ? -1.35 : -0.15 + o.dive * 0.1;
      legL.rotation.x += (lX - legL.rotation.x) * k; legR.rotation.x += (lX - legR.rotation.x) * k;
      legL.rotation.z += ((slide ? 0.1 : 0.06) - legL.rotation.z) * k; legR.rotation.z += ((slide ? -0.1 : -0.06) - legR.rotation.z) * k;
      // body pitch & lean & squash
      const pitchT = slide ? -0.06 : -(o.pitch || 0) * 0.9 - 0.9 * o.dive * 0.4 + 1.0 * (o.dive > 0.3 ? 0 : 0);
      body.rotation.x += (slide ? -0.1 : pitchT - 0.0) * k * 0.0 + 0; // body pitch handled by root orientation
      body.rotation.z += (-(o.lean || 0) * 0.5 - body.rotation.z) * k;
      this.squash = damp(this.squash, 0, 8, dt);
      const sq = this.squash; body.scale.set(1 + sq * 0.25, 1 - sq * 0.3, 1 + sq * 0.25);
      head.rotation.z = Math.sin(o.t * 3) * 0.04 - (o.lean || 0) * 0.15;
      this.propSpin += dt * (6 + 30 * (o.speed01 || 0)); prop.rotation.y = this.propSpin;
      tube.visible = mode !== 'fly' || o.tubeOn !== false;
    }
  };
  return R;
}
