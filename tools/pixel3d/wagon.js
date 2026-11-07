// The cart built in code (a covered wagon at first) (owner 2026-11-07: 작은 소품). The reference sprite (assets/town/g_wagon2.png, 280 x
// 218, one cell per pixel; the town hitches its horse at the shaft separately) is only the guide. A plank bed on posts,
// a canvas bonnet over hoops, open at the front end, big spoked wheels behind and smaller ones in front, the shaft out
// to the right. Built as a real solid: world units, x right, y up from the ground (a ref row r is at y = 218 - r), z
// toward the viewer.

const WAGON = (function () {
  const W = 280, H = 236, B0 = 218, K = 0.12, TOP = 16;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    canvas: ["cream", 5], rope: ["ochre", 3], barrel: ["wood", 5], barrelTop: ["wood", 6], hoopIron: ["iron", 3],
    crate: ["wood", 6], crateDk: ["wood", 4], sack: ["ochre", 5],
    roofBase: ["red", 0], tile: ["red", 2], tileDk: ["red", 1], tileLt: ["red", 3], fascia: ["wood", 1], gable: ["wood", 5],
    plank: ["wood", 5], post: ["wood", 4], rim: ["wood", 6], rail: ["wood", 6], cap: ["iron", 3], rivet: ["iron", 2], tyre: ["wood", 3], hub: ["wood", 3], spoke: ["wood", 4], shaft: ["wood", 5],
  };
  const LAYERS = ["ground", "bed", "load", "roof", "wheels"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    const cube = (layer, mat, x0, x1, y0, y1, z0, z1) => { const m = add(new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0), mat, layer);
      m.position.set((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2); return m; };
    const R = (row) => 218 - row;
    const Z0 = -48, Z1 = 0, ZM = (Z0 + Z1) / 2;

    // (owner 2026-11-07: "씁 미묘한데. 래퍼런스 다시 찾아서 다시 만들어봐" -> 상인 수레) A merchant's cart: an open plank
    // bed with low sides, the load at the back under a tarp lashed down with rope, barrels, a crate and a sack up front.
    const BT = 120;                                                   // the bed's top row
    // ---- the bed: low sides of planks between posts, a top rail, the shaft out to the right
    cube("bed", "post", 10, 226, R(166), R(BT), Z0 + 2, Z1 - 2);
    for (const [r0, r1] of [[126, 138], [141, 152], [155, 164]]) cube("bed", "plank", 12, 224, R(r1), R(r0), Z1 - 2, Z1);
    cube("bed", "rail", 6, 230, R(126), R(BT - 2), Z0, Z1 + 2.5);
    for (const x of [22, 84, 142, 200]) { cube("bed", "post", x, x + 12, R(168), R(BT - 6), Z1 - 3, Z1 + 1.5);
      cube("bed", "cap", x - 1, x + 13, R(BT - 2), R(BT - 8), Z1 - 3.5, Z1 + 2);
      cube("bed", "rivet", x + 4, x + 8, R(131), R(127), Z1 + 1.5, Z1 + 2.2); }
    cube("bed", "shaft", 214, 272, R(152), R(138), ZM - 4, ZM + 4);
    cube("bed", "post", 264, 278, R(156), R(134), ZM - 5, ZM + 5);

    // (owner 2026-11-07: "아 씁. 걍 천을 빼고 지붕으로 덮을까") no tarp: the load stands open - crates and bales stacked
    // at the back - under a roof on four corner posts, a gable of red tiles along the cart like the town's roofs
    for (const [a, b, c, d, hh] of [[16, 58, -44, -8, 40], [52, 100, -42, -6, 48], [62, 92, -32, -16, 66], [98, 148, -44, -8, 36], [104, 132, -36, -18, 52]]) {
      cube("load", "crate", a + 0.6, b - 0.6, R(BT), R(BT) + hh, c, d);
      cube("load", "crateDk", a + 0.6, b - 0.6, R(BT) + hh / 2 - 1.5, R(BT) + hh / 2 + 1.5, d, d + 0.6);   // a batten across
      for (const x of [a + 2.5, b - 5]) cube("load", "crateDk", x, x + 2.5, R(BT), R(BT) + hh, d, d + 0.6); }
    { const RX0 = 4, RX1 = 232, EAVE = R(BT) + 92, RIDGE = R(BT) + 118, ZE = 36;
      for (const x of [12, 220]) for (const z of [Z1 - 3, Z0 + 3]) cube("roof", "post", x - 3, x + 3, R(BT), EAVE, z - 3, z + 3);   // corner posts
      for (const z of [Z1 - 3, Z0 + 3]) cube("roof", "post", 9, 223, EAVE - 6, EAVE, z - 3, z + 3);                                 // plates
      // the two slopes: a board deck, tiles laid on it in courses
      for (const sgn of [1, -1]) {
        const e = new THREE.Vector3(0, EAVE, ZM + sgn * ZE), r = new THREE.Vector3(0, RIDGE, ZM);
        const slope = r.clone().sub(e), len = slope.length(), n = new THREE.Vector3(0, slope.z * -sgn, 0).add(new THREE.Vector3(0, 0, 0));
        const nrm = new THREE.Vector3(0, -slope.z, slope.y).normalize().multiplyScalar(sgn < 0 ? -1 : 1); if (nrm.y < 0) nrm.negate();
        const at = (x, t, off) => new THREE.Vector3(x, e.y + slope.y * t, e.z + slope.z * t).addScaledVector(nrm, off);
        const quad = (mat, pts) => { const tt = [], q = (a, b, c, d) => tt.push(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z);
          q(...pts); q(pts[3], pts[2], pts[1], pts[0]);
          const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(tt, 3)); g.computeVertexNormals(); add(g, mat, "roof"); };
        quad("roofBase", [at(RX0, 0, 0), at(RX1, 0, 0), at(RX1, 1, 0), at(RX0, 1, 0)]);
        const NC = 4;
        for (let c = 0; c < NC; c++) for (let x = RX0 + (c % 2 ? -14 : 0), k = 0; x < RX1; x += 28, k++) {
          const x0 = Math.max(x + 0.8, RX0), x1 = Math.min(x + 27.2, RX1); if (x1 - x0 < 4) continue;
          const t0 = c / NC, t1 = Math.min(1, (c + 1) / NC + 0.06), hh = Math.abs(Math.sin((x + 7) * 12.9 + c * 78.2) * 43758.5) % 1;
          const mat = hh < 0.12 ? "tileDk" : hh > 0.92 ? "tileLt" : "tile";
          quad(mat, [at(x0, t0, 2.6), at(x1, t0, 2.6), at(x1, t1, 0.8), at(x0, t1, 0.8)]);
          quad(mat, [at(x0, t0, 0.2), at(x1, t0, 0.2), at(x1, t0, 2.6), at(x0, t0, 2.6)]); }
        cube("roof", "fascia", RX0, RX1, EAVE - 2.5, EAVE + 1.5, e.z - (sgn > 0 ? 0 : 2), e.z + (sgn > 0 ? 2 : 0));
      }
      // the gable ends: boards closing the triangle under each end of the roof
      for (const x of [RX0 + 6, RX1 - 6]) { const sh = new THREE.Shape([new THREE.Vector2(ZM - ZE + 6, EAVE), new THREE.Vector2(ZM + ZE - 6, EAVE), new THREE.Vector2(ZM, RIDGE - 4)]);
        const g = new THREE.ExtrudeGeometry(sh, { depth: 2, bevelEnabled: false }); const m = add(g, "gable", "roof"); m.rotation.y = -Math.PI / 2; m.position.x = x; }
      { const g = new THREE.CylinderGeometry(3.2, 3.2, RX1 - RX0, 10); const m = add(g, "tile", "roof"); m.rotation.z = Math.PI / 2; m.position.set((RX0 + RX1) / 2, RIDGE + 1.5, ZM); }   // the ridge roll
    }
    // ---- up front: two barrels, a crate with a sack on it
    const barrel = (x, z, h, r) => { const prof = []; for (let k = 0; k <= 10; k++) { const t2 = k / 10; prof.push(new THREE.Vector2(r * (0.86 + 0.14 * Math.sin(Math.PI * t2)), h * t2)); }
      const g = new THREE.LatheGeometry(prof, 16); const m = add(g, "barrel", "load"); m.position.set(x, R(BT), z);
      for (const f of [0.15, 0.85]) { const gg = new THREE.TorusGeometry(r * (0.86 + 0.14 * Math.sin(Math.PI * f)) + 0.4, 1.0, 5, 18);
        const mm = add(gg, "hoopIron", "load"); mm.rotation.x = Math.PI / 2; mm.position.set(x, R(BT) + h * f, z); }
      const lid = new THREE.CircleGeometry(r * 0.86, 16); const ml = add(lid, "barrelTop", "load"); ml.rotation.x = -Math.PI / 2; ml.position.set(x, R(BT) + h + 0.1, z); };
    barrel(170, ZM + 8, 44, 13);
    barrel(170, ZM - 12, 38, 12);
    cube("load", "crate", 188, 224, R(BT), R(BT) + 30, ZM - 14, ZM + 14);
    for (const [a, b] of [[188, 191], [221, 224]]) cube("load", "crateDk", a, b, R(BT), R(BT) + 30, ZM + 14, ZM + 14.6);
    cube("load", "crateDk", 188, 224, R(BT) + 13.5, R(BT) + 16.5, ZM + 14, ZM + 14.6);
    { const g = new THREE.SphereGeometry(1, 12, 8); const m = add(g, "sack", "load"); m.scale.set(15, 9, 11); m.position.set(205, R(BT) + 37, ZM + 2); m.rotation.z = 0.2;
      const g2 = new THREE.CylinderGeometry(2.2, 3.6, 6, 8); const m2 = add(g2, "sack", "load"); m2.position.set(216, R(BT) + 45, ZM + 2); m2.rotation.z = -0.7; }

    // ---- the wheels: an iron-shod rim, eight spokes, a hub; big at the back, smaller at the front
    const wheel = (cx, cyRow, r, z) => {
      const cy = R(cyRow);
      { const g = new THREE.TorusGeometry(r - 5, 5.6, 6, 32); const m = add(g, "rim", "wheels"); m.position.set(cx, cy, z); }
      { const g = new THREE.TorusGeometry(r - 11, 1.9, 5, 32); const m = add(g, "tyre", "wheels"); m.position.set(cx, cy, z + 3); }
      { const g = new THREE.TorusGeometry(r - 1, 2.0, 5, 32); const m = add(g, "tyre", "wheels"); m.position.set(cx, cy, z - 0.5); }
      for (let i = 0; i < 4; i++) { const a = i / 4 * Math.PI; const m = cube("wheels", "spoke", -3.4, 3.4, -(r - 8), r - 8, -2, 2);
        m.position.set(cx, cy, z); m.rotation.z = a; }
      cube("wheels", "hub", cx - 9, cx + 9, cy - 9, cy + 9, z - 4, z + 5);                      // the hub, squared
      cube("wheels", "rivet", cx - 3, cx + 3, cy - 3, cy + 3, z + 5, z + 6.5);
    };
    wheel(60, 172, 46, Z1 + 6);
    wheel(181, 176, 42, Z1 + 6);

    // (owner 2026-11-07: "좀 더 재현성 높게") the reference sees the wagon a little from its front end - the bonnet's
    // round and its open mouth show. The whole wagon turned TURN about the vertical through its middle, front end
    // toward us: a real turn, so it still shades and casts true.
    const TURN = 0;
    const rot = new THREE.Matrix4().makeTranslation(140, 0, ZM).multiply(new THREE.Matrix4().makeRotationY(TURN)).multiply(new THREE.Matrix4().makeTranslation(-140, 0, -ZM));
    for (const p of parts) { const m = p.mesh; m.updateMatrix();
      const g = m.geometry.index ? m.geometry.toNonIndexed() : m.geometry; g.applyMatrix4(m.matrix); g.applyMatrix4(rot);
      g.deleteAttribute("normal"); g.computeVertexNormals();
      m.geometry = g; m.position.set(0, 0, 0); m.rotation.set(0, 0, 0); m.quaternion.identity(); m.scale.set(1, 1, 1); m.updateMatrix(); }
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
