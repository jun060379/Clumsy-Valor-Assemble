// The fountain built in code, the same way as the other buildings (owner 2026-11-07: next -> 분수). The reference sprite
// (assets/town/hx/q_fountain.png, 282 x 204, at half size = 141 x 102 cells) is only the guide. A sandstone basin -
// a long front wall with a coping round its top, two blind arches either side of a middle pilaster, a plinth along
// its foot, a pedestal with a rounded cap at each end - and in it a small shrine tower: a plinth, two piers, two
// cantilevered ledges, a niche arch with the spout in it, a cornice and a pyramid cap. The water (pool, fall,
// spread) is left to an effect.
// Coordinates as hall.js (x column, rows down from the top, Z toward the viewer, B0 = the foot line).

const FOUNTAIN = (function () {
  const W = 141, H = 114, B0 = 102, K = 0.12, TOP = 6;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    stone: ["ochre", 4], stoneLt: ["ochre", 5], stoneDk: ["ochre", 3], niche: ["wood", 1],
    water: ["blue", 4], waterLt: ["blue", 5],
  };
  const LAYERS = ["ground", "basin", "tower", "water"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    function box(layer, mat, x0, x1, r0, r1, z0, z1) {
      if (x1 < x0) [x0, x1] = [x1, x0];
      const yt = Y(r0, z1), yb = Y(r1, z1);
      const m = add(new THREE.BoxGeometry(x1 - x0, yt - yb, z1 - z0), mat, layer);
      m.position.set((x0 + x1) / 2, (yt + yb) / 2, (z0 + z1) / 2);
      return m;
    }
    function bar(layer, mat, xa, ra, xb, rb, t, z0, z1) {
      const a = new THREE.Vector2(xa, Y(ra, z1)), b = new THREE.Vector2(xb, Y(rb, z1));
      const m = add(new THREE.BoxGeometry(a.distanceTo(b), t, z1 - z0), mat, layer);
      m.position.set((a.x + b.x) / 2, (a.y + b.y) / 2, (z0 + z1) / 2);
      m.rotation.z = Math.atan2(b.y - a.y, b.x - a.x);
      return m;
    }
    function slab(layer, mat, pts, z0, z1, holes) {
      const sh = new THREE.Shape(pts.map(([x, r]) => new THREE.Vector2(x, Y(r, z1))));
      for (const hp of holes || []) sh.holes.push(new THREE.Path(hp.map(([x, r]) => new THREE.Vector2(x, Y(r, z1)))));
      const m = add(new THREE.ExtrudeGeometry(sh, { depth: z1 - z0, bevelEnabled: false, curveSegments: 24 }), mat, layer);
      m.position.z = z0;
      return m;
    }
    function archPts(x0, x1, r0, r1, n = 20) {
      const rad = (x1 - x0) / 2, cx = (x0 + x1) / 2, spring = r0 + rad;
      const p = [[x0, r1], [x1, r1], [x1, spring]];
      for (let i = 1; i < n; i++) { const a = Math.PI * i / n; p.push([cx + rad * Math.cos(a), spring - rad * Math.sin(a)]); }
      p.push([x0, spring]);
      return p;
    }
    function shell(layer, mat, F, us, vs, D) {
      const P = us.map(u => vs.map(v => F(u, v)));
      const tri = [], quad = (a, b, c, d) => tri.push(...a, ...b, ...c, ...a, ...c, ...d);
      const dn = (p) => [p[0] + D[0], p[1] + D[1], p[2] + D[2]];
      for (let i = 0; i < us.length - 1; i++) for (let j = 0; j < vs.length - 1; j++) quad(P[i][j], P[i + 1][j], P[i + 1][j + 1], P[i][j + 1]);
      for (let i = 0; i < us.length - 1; i++) { quad(dn(P[i][0]), dn(P[i + 1][0]), P[i + 1][0], P[i][0]);
        const L = vs.length - 1; quad(P[i][L], P[i + 1][L], dn(P[i + 1][L]), dn(P[i][L])); }
      for (let j = 0; j < vs.length - 1; j++) { quad(P[0][j], P[0][j + 1], dn(P[0][j + 1]), dn(P[0][j]));
        const L = us.length - 1; quad(dn(P[L][j]), dn(P[L][j + 1]), P[L][j + 1], P[L][j]); }
      const g = new THREE.BufferGeometry();
      g.setAttribute("position", new THREE.Float32BufferAttribute(tri, 3));
      g.computeVertexNormals();
      return add(g, mat, layer);
    }
    // ---- the basin: walls round a pool, a coping along their tops, the water inside
    const ZF = 0, ZK = -60;                                          // front and back of the basin
    box("basin", "stone", 20, 120, 72, 102, ZF - 4, ZF);             // the front wall
    box("basin", "stone", 20, 120, 72, 102, ZK, ZK + 4);             // the back wall
    for (const [a, b] of [[20, 24], [116, 120]]) box("basin", "stone", a, b, 72, 102, ZK, ZF);
    box("basin", "stoneLt", 18, 122, 66, 72, ZF - 6, ZF + 2);        // the coping, front,
    box("basin", "stoneLt", 18, 122, 66, 72, ZK - 2, ZK + 6);        // back,
    for (const [a, b] of [[18, 26], [114, 122]]) box("basin", "stoneLt", a, b, 66, 72, ZK - 2, ZF + 2);   // and sides
    box("basin", "stoneDk", 20, 120, 72, 76, ZF - 1, ZF + 0.6);       // the shadowed band under it
    // the front: a middle pilaster, a blind arch in each bay, the plinth along the foot
    box("basin", "stoneLt", 60, 80, 76, 92, ZF, ZF + 2);
    for (const [a, b] of [[24, 58], [82, 116]]) {
      const cx = (a + b) / 2, rx = (b - a) / 2, ry = 13, ring = [];
      for (let i = 0; i <= 24; i++) { const t = Math.PI * i / 24; ring.push([cx - rx * Math.cos(t), 92 - ry * Math.sin(t)]); }
      const inner = ring.map(([x, r]) => [cx + (x - cx) * (rx - 2.2) / rx, 92 - (92 - r) * (ry - 2.2) / ry]).reverse();
      slab("basin", "stoneLt", [...ring, ...inner], ZF, ZF + 1.4);    // the arch ring, standing proud
    }
    box("basin", "stoneLt", 18, 122, 92, 102, ZF - 1, ZF + 2.5);      // the plinth
    box("basin", "stoneDk", 18, 122, 92, 93, ZF + 2.5, ZF + 2.8);     // its top edge, a joint
    // the pedestals at the ends, each with a rounded cap
    for (const [a, b] of [[2, 20], [120, 139]]) {
      box("basin", "stone", a, b, 70, 102, -16, 4);
      box("basin", "stoneDk", a, b, 90, 91, 4, 4.4);
      box("basin", "stoneLt", a - 0.5, b + 0.5, 66, 70, -16.5, 4.5);
      const g = new THREE.CylinderGeometry((b - a) / 2 - 1.5, (b - a) / 2 - 1.5, 20, 20);   // the rounded cap: a drum
      const m = add(g, "stoneLt", "basin"); m.rotation.x = Math.PI / 2;                    // lying back, half sunk
      m.scale.set(1, 0.55, 1); m.position.set((a + b) / 2, Y(70, 4), -6);
    }

    // ---- the tower, standing in the pool
    const ZT = -18;                                                   // its front face
    box("tower", "stone", 42, 98, 60, 72, ZT - 24, ZT + 2);           // the plinth
    box("tower", "stoneLt", 41, 99, 60, 62, ZT - 25, ZT + 3);
    for (const [a, b] of [[46, 63], [77, 94]]) box("tower", "stone", a, b, 50, 60, ZT - 20, ZT);   // the piers
    box("tower", "stoneDk", 63, 77, 46, 60, ZT - 20, ZT - 14);        // the dark between them, behind the fall
    for (const [a, b] of [[42, 64], [76, 98]]) { box("tower", "stoneLt", a, b, 42, 50, ZT - 22, ZT + 2);   // the ledges
      box("tower", "stoneDk", a, b, 49, 50, ZT + 2, ZT + 2.3); }
    box("tower", "stone", 54, 86, 22, 42, ZT - 20, ZT - 4);           // the shrine
    for (const [a, b] of [[54, 59], [81, 86]]) box("tower", "stoneLt", a, b, 22, 38, ZT - 4, ZT - 2);   // its pilasters
    box("tower", "stoneLt", 52, 88, 36, 40, ZT - 22, ZT - 1);         // the sill under the niche
    slab("tower", "niche", archPts(64, 76, 25, 36), ZT - 4.4, ZT - 3.9);   // the niche, dark, round-headed
    slab("tower", "stoneLt", archPts(61, 79, 22, 36.2), ZT - 4, ZT - 2.4, [archPts(64, 76, 25, 35.9)]);   // its arch ring
    box("tower", "stoneLt", 52, 88, 14, 22, ZT - 22, ZT - 1);         // the cornice
    box("tower", "stoneDk", 52, 88, 21, 22, ZT - 1, ZT - 0.7);
    { const g = new THREE.ConeGeometry(14.1, 12, 4); const m = add(g, "stoneLt", "tower");   // the pyramid cap
      m.rotation.y = Math.PI / 4; m.position.set(70, Y(8, ZT - 11), ZT - 11); }

    // the water - the pool, the fall from the spout, the spread over the plinth - is not built here: it moves, so it
    // comes as an effect over the sprite (owner 2026-11-07: "물 빼고 fx로 넣어도 되나?")

    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
