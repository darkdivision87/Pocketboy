// Tiny AABB physics: boxes {x0,y0,z0,x1,y1,z1,on?} and a voxel grid for the build zone.
const EPS = 0.001, STEP = 0.62;
const near = [];
export function box(x0, y0, z0, x1, y1, z1, extra) { return Object.assign({ x0, y0, z0, x1, y1, z1, on: true }, extra); }
export function boxC(cx, cy, cz, w, h, d, extra) { return box(cx - w / 2, cy - h / 2, cz - d / 2, cx + w / 2, cy + h / 2, cz + d / 2, extra); }
export function makeBody(x = 0, y = 0, z = 0, hw = 0.3, h = 1.8) { return { x, y, z, vx: 0, vy: 0, vz: 0, hw, h, onGround: false, wasGround: false, ground: null, hitWall: false, lastVy: 0 }; }

export class VoxelGrid {
  constructor() { this.map = new Map(); this.pool = []; this.pi = 0; }
  key(x, y, z) { return ((y + 2) * 128 + (z + 64)) * 128 + (x + 64); }
  get(x, y, z) { return this.map.get(this.key(x, y, z)); }
  set(x, y, z, v) { this.map.set(this.key(x, y, z), v); }
  del(x, y, z) { this.map.delete(this.key(x, y, z)); }
  query(x0, y0, z0, x1, y1, z1, out) {
    const ix0 = Math.floor(x0), ix1 = Math.floor(x1), iy0 = Math.floor(y0), iy1 = Math.floor(y1), iz0 = Math.floor(z0), iz1 = Math.floor(z1);
    this.pi = 0;
    for (let y = iy0; y <= iy1; y++) for (let z = iz0; z <= iz1; z++) for (let x = ix0; x <= ix1; x++) {
      if (this.map.get(this.key(x, y, z)) === undefined) continue;
      let b = this.pool[this.pi]; if (!b) b = this.pool[this.pi] = { on: true };
      this.pi++; b.x0 = x; b.x1 = x + 1; b.y0 = y; b.y1 = y + 1; b.z0 = z; b.z1 = z + 1; out.push(b);
    }
  }
}

function ov(b, c) { return b.x + b.hw > c.x0 && b.x - b.hw < c.x1 && b.z + b.hw > c.z0 && b.z - b.hw < c.z1 && b.y + b.h > c.y0 + EPS && b.y < c.y1 - EPS; }

export function moveBody(b, dt, cols, grid) {
  const mx = Math.abs(b.vx * dt) + 0.7, mz = Math.abs(b.vz * dt) + 0.7, my = Math.abs(b.vy * dt) + 0.7;
  const X0 = b.x - b.hw - mx, X1 = b.x + b.hw + mx, Z0 = b.z - b.hw - mz, Z1 = b.z + b.hw + mz, Y0 = b.y - my, Y1 = b.y + b.h + my;
  near.length = 0;
  for (let i = 0; i < cols.length; i++) { const c = cols[i]; if (c.on === false || c.x1 < X0 || c.x0 > X1 || c.z1 < Z0 || c.z0 > Z1 || c.y1 < Y0 || c.y0 > Y1) continue; near.push(c); }
  if (grid) grid.query(X0, Y0, Z0, X1, Y1, Z1, near);
  b.wasGround = b.onGround; b.onGround = false; b.ground = null; b.hitWall = false; b.lastVy = b.vy;
  b.x += b.vx * dt;
  for (let i = 0; i < near.length; i++) {
    const c = near[i]; if (!ov(b, c)) continue;
    const rise = c.y1 - b.y;
    if (b.wasGround && rise > 0 && rise <= STEP && !c.noStep) { b.y = c.y1; continue; }
    const dir = b.vx > 0 ? 1 : b.vx < 0 ? -1 : (b.x < (c.x0 + c.x1) / 2 ? 1 : -1);
    b.x = dir > 0 ? c.x0 - b.hw - EPS : c.x1 + b.hw + EPS; b.vx = 0; b.hitWall = true;
  }
  b.z += b.vz * dt;
  for (let i = 0; i < near.length; i++) {
    const c = near[i]; if (!ov(b, c)) continue;
    const rise = c.y1 - b.y;
    if (b.wasGround && rise > 0 && rise <= STEP && !c.noStep) { b.y = c.y1; continue; }
    const dir = b.vz > 0 ? 1 : b.vz < 0 ? -1 : (b.z < (c.z0 + c.z1) / 2 ? 1 : -1);
    b.z = dir > 0 ? c.z0 - b.hw - EPS : c.z1 + b.hw + EPS; b.vz = 0; b.hitWall = true;
  }
  b.y += b.vy * dt;
  for (let i = 0; i < near.length; i++) {
    const c = near[i]; if (!ov(b, c)) continue;
    if (b.vy <= 0) { b.y = c.y1; b.vy = 0; b.onGround = true; b.ground = c; }
    else { b.y = c.y0 - b.h - EPS; b.vy = 0; }
  }
}

// ray vs boxes (slab); returns smallest t in [0,maxT] or maxT
export function rayBoxes(ox, oy, oz, dx, dy, dz, maxT, cols, inflate = 0, grid = null) {
  let best = maxT;
  for (let i = 0; i < cols.length; i++) {
    const c = cols[i]; if (c.on === false || c.cam === false) continue;
    let t0 = 0, t1 = best;
    const mn = [c.x0 - inflate, c.y0 - inflate, c.z0 - inflate], mx = [c.x1 + inflate, c.y1 + inflate, c.z1 + inflate], o = [ox, oy, oz], d = [dx, dy, dz];
    let hit = true;
    for (let a = 0; a < 3; a++) {
      if (Math.abs(d[a]) < 1e-9) { if (o[a] < mn[a] || o[a] > mx[a]) { hit = false; break; } }
      else { let ta = (mn[a] - o[a]) / d[a], tb = (mx[a] - o[a]) / d[a]; if (ta > tb) { const s = ta; ta = tb; tb = s; } if (ta > t0) t0 = ta; if (tb < t1) t1 = tb; if (t0 > t1) { hit = false; break; } }
    }
    if (hit && t0 < best) best = t0;
  }
  if (grid) { for (let t = 0.5; t < best; t += 0.4) { if (grid.get(Math.floor(ox + dx * t), Math.floor(oy + dy * t), Math.floor(oz + dz * t)) !== undefined) { best = Math.max(0.3, t - 0.4); break; } } }
  return best;
}
