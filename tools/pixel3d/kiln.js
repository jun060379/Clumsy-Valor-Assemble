// The charcoal kiln built in code (owner 2026-11-07: next -> 숯가마). The reference sprite (assets/town/hx/g_kiln.png,
// 308 x 182, at half size = 154 x 91 cells) is only the guide. A beehive kiln: a round dome of dressed stone laid in
// level courses that draw in as they rise (each course a ring of the same-size stones, every other ring shifted half
// a stone, orange mortar in the joints), a round-arched mouth at the front framed by a ring of wedge stones, dark
// inside. Built as a real solid - a dome of revolution standing on the ground - so it shades and casts true.
// World units: x right, y up from the ground (y = 0), z toward the viewer.

const KILN = (function () {
  const W = 158, H = 118, B0 = 88, K = 0.12, TOP = 8;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    stone: ["cream", 3], stoneDk: ["cream", 2], mortar: ["ochre", 3], arch: ["cream", 4], inside: ["stone", 2],
  };
  const LAYERS = ["ground", "mortar", "stones", "arch", "inside"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    let seed = 7;
    const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
    const V = (x, y, z) => new THREE.Vector3(x, y, z);
    const mesh = (tri, mat, layer) => { const g = new THREE.BufferGeometry();
      g.setAttribute("position", new THREE.Float32BufferAttribute(tri, 3)); g.computeVertexNormals(); return add(g, mat, layer); };

    // the dome: a beehive profile, steep at the foot, rounding over a broad top
    const CX = 79, CZ = 0, R0 = 72, HD = 78;
    const rad = (y) => R0 * Math.pow(Math.max(0, 1 - Math.pow(Math.min(y, HD) / HD, 2.4)), 1 / 2.4);
    let RFIX = null;                                                   // set: a course's stones stand on one radius (the step)
    const at = (a, y, dr = 0) => { const r = (RFIX ?? rad(y)) + dr; return V(CX + r * Math.sin(a), y, CZ + r * Math.cos(a)); };

    // the mouth: a round arch on the front (a = 0), half-width AW, its spring at AS
    const AW = 18, AS = 20, RING = 9;
    const halfW = (y, w) => y <= AS ? w : (y - AS < w ? Math.sqrt(w * w - (y - AS) * (y - AS)) : -1);
    const angOut = (y, w) => { const h = halfW(y, w); return h < 0 ? -1 : Math.asin(Math.min(1, h / rad(y))); };

    // a curved patch of the dome between angles a0..a1 and heights y0..y1, from radius r0 out to r1
    function patch(a0, a1, y0, y1, r0, r1, mat, layer) {
      const na = Math.max(2, Math.ceil((a1 - a0) * R0 / 4)), ny = 3, t = [];
      const P = (i, j, dr) => at(a0 + (a1 - a0) * i / na, y0 + (y1 - y0) * j / ny, dr);
      const q = (a, b, c, d) => t.push(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z);
      for (let i = 0; i < na; i++) for (let j = 0; j < ny; j++) {
        q(P(i, j, r1), P(i + 1, j, r1), P(i + 1, j + 1, r1), P(i, j + 1, r1));
        q(P(i, j + 1, r0), P(i + 1, j + 1, r0), P(i + 1, j, r0), P(i, j, r0));
      }
      for (let j = 0; j < ny; j++) { q(P(0, j + 1, r1), P(0, j + 1, r0), P(0, j, r0), P(0, j, r1));
        q(P(na, j, r1), P(na, j, r0), P(na, j + 1, r0), P(na, j + 1, r1)); }
      for (let i = 0; i < na; i++) { q(P(i + 1, ny, r1), P(i + 1, ny, r0), P(i, ny, r0), P(i, ny, r1));
        q(P(i, 0, r1), P(i, 0, r0), P(i + 1, 0, r0), P(i + 1, 0, r1)); }
      return mesh(t, mat, layer);
    }

    // the mortar bed: the whole dome a little under the stones, the mouth left open
    const CH = 9;                                                       // course height
    for (let y = 0; y < HD; y += 3) {
      const y1 = Math.min(HD, y + 3), o = angOut(y + 1.5, AW);
      if (o < 0) patch(-Math.PI, Math.PI, y, y1, -2.5, -0.2, "mortar", "mortar");
      else patch(o, 2 * Math.PI - o, y, y1, -2.5, -0.2, "mortar", "mortar");
    }
    RFIX = null;
    // the courses: the same stone length all the way up, every other course shifted half a stone; stones that meet
    // the arch ring are cut at it, not dropped
    const SL = 20, GAP = 1.1;
    for (let k = 0, y = 0; y < HD - 4; k++, y += CH) {
      const y0 = y + 0.5, y1 = Math.min(HD - 3, y + CH - 0.5), ym = (y0 + y1) / 2, r = rad(ym);
      const n = Math.max(3, Math.round(2 * Math.PI * r / SL)), da = 2 * Math.PI / n, g = GAP / Math.max(r, 6);
      const cut = angOut(ym, AW + RING);
      for (let i = 0; i < n; i++) {
        let a0 = -Math.PI + (i + (k % 2) * 0.5) * da + g, a1 = a0 + da - 2 * g;
        const mid = Math.atan2(Math.sin((a0 + a1) / 2), Math.cos((a0 + a1) / 2));
        if (Math.cos(mid) < -0.45) continue;                            // the back stays mortar only (unseen)
        const segs = [];
        if (cut < 0) segs.push([a0, a1]);
        else { // the arch's span on this course, in this stone's own winding
          const c = a0 + ((((0 - a0) % (2 * Math.PI)) + 2 * Math.PI) % (2 * Math.PI));
          const h0 = c - cut - g, h1 = c + cut + g;
          if (h1 <= a0 || h0 >= a1) { const c2 = c - 2 * Math.PI, k0 = c2 - cut - g, k1 = c2 + cut + g;
            if (k1 <= a0 || k0 >= a1) segs.push([a0, a1]); else { if (k0 - a0 > 0.03) segs.push([a0, k0]); if (a1 - k1 > 0.03) segs.push([k1, a1]); } }
          else { if (h0 - a0 > 0.03) segs.push([a0, h0]); if (a1 - h1 > 0.03) segs.push([h1, a1]); }
        }
        const mat = rnd() < 0.12 ? "stoneDk" : "stone";
        for (const [s0, s1] of segs) if ((s1 - s0) * r >= 3) patch(s0, s1, y0, y1, -0.6, 1.6, mat, "stones");
        RFIX = null;
      }
    }
    // the cap: one round stone over the top
    patch(-Math.PI, Math.PI, HD - 3, HD, -0.6, 1.6, "stone", "stones");

    // the arch ring: wedge stones around the mouth, standing a touch proud, the jambs straight to the ground
    {
      const path = [];
      const Rm = AW + RING / 2, st = 1;
      for (let y = 0; y <= AS; y += st) path.push([-Rm, y]);
      for (let a = Math.PI; a >= 0; a -= st / Rm) path.push([Rm * Math.cos(a), AS + Rm * Math.sin(a)]);
      for (let y = AS; y >= 0; y -= st) path.push([Rm, y]);
      const len = path.length, NS = 11, per = len / NS;
      for (let s = 0; s < NS; s++) {
        const pts = path.slice(Math.floor(s * per) + 1, Math.floor((s + 1) * per));
        if (pts.length < 2) continue;
        const t = [], q = (a, b, c, d) => t.push(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z);
        const on = (x, y, dr) => { const rr = rad(y) + dr, z = Math.sqrt(Math.max(0, rr * rr - x * x)); return V(CX + x, y, CZ + z); };
        const off = (p, d) => { const [x, y] = p; let cx = 0, cy = AS; if (y < AS) cy = y; const l = Math.hypot(x - cx, y - cy) || 1;
          return [x + (x - cx) / l * d, y + (y - cy) / l * d]; };
        for (let i = 0; i < pts.length - 1; i++) {
          const a = pts[i], b = pts[i + 1];
          const ai = off(a, -RING / 2 + 0.6), bi = off(b, -RING / 2 + 0.6), ao = off(a, RING / 2 - 0.6), bo = off(b, RING / 2 - 0.6);
          q(on(...ai, 2.4), on(...bi, 2.4), on(...bo, 2.4), on(...ao, 2.4));
          q(on(...ao, -0.6), on(...bo, -0.6), on(...bi, -0.6), on(...ai, -0.6));
          q(on(...ai, -0.6), on(...bi, -0.6), on(...bi, 2.4), on(...ai, 2.4));
          q(on(...ao, 2.4), on(...bo, 2.4), on(...bo, -0.6), on(...ao, -0.6));
        }
        const e = (p) => [on(...off(p, -RING / 2 + 0.6), 2.4), on(...off(p, RING / 2 - 0.6), 2.4), on(...off(p, RING / 2 - 0.6), -0.6), on(...off(p, -RING / 2 + 0.6), -0.6)];
        const [f0, f1, f2, f3] = e(pts[0]); q(f3, f2, f1, f0);
        const [g0, g1, g2, g3] = e(pts[pts.length - 1]); q(g0, g1, g2, g3);
        mesh(t, "arch", "arch");
      }
    }
    // inside: the dark of the chamber - its back wall and floor, seen through the mouth
    patch(Math.PI / 2, 3 * Math.PI / 2, 0, HD - 4, -6, -3, "inside", "inside");
    { const g = new THREE.CircleGeometry(R0 - 4, 32); const m = add(g, "inside", "inside"); m.rotation.x = -Math.PI / 2; m.position.set(CX, 0.3, CZ); }

    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
