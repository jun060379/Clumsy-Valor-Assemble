// The cart built in code (a covered wagon at first) (owner 2026-11-07: 작은 소품). The reference sprite (assets/town/g_wagon2.png, 280 x
// 218, one cell per pixel; the town hitches its horse at the shaft separately) is only the guide. A plank bed on posts,
// a canvas bonnet over hoops, open at the front end, big spoked wheels behind and smaller ones in front, the shaft out
// to the right. Built as a real solid: world units, x right, y up from the ground (a ref row r is at y = 218 - r), z
// toward the viewer.

const WAGON = (function () {
  const W = 280, H = 224, B0 = 218, K = 0.12, TOP = 4;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    canvas: ["cream", 5], rope: ["ochre", 3], barrel: ["wood", 5], barrelTop: ["wood", 6], hoopIron: ["iron", 3],
    crate: ["wood", 6], crateDk: ["wood", 4], sack: ["ochre", 5],
    plank: ["wood", 5], post: ["wood", 4], rim: ["wood", 6], rail: ["wood", 6], cap: ["iron", 3], rivet: ["iron", 2], tyre: ["wood", 3], hub: ["wood", 3], spoke: ["wood", 4], shaft: ["wood", 5],
  };
  const LAYERS = ["ground", "bed", "load", "wheels"];

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

    // ---- the load under a tarp (owner 2026-11-07: "천이 왤케 미묘하지"): the cloth is thrown over real things - crates and
    // bales of different heights - and takes their shape: a height field drawn over the stack and softened, falling
    // to the bed between and past them and hanging a hand's breadth over the near side; ropes across it follow it
    { const STACK = [[16, 58, -44, -8, 50], [52, 100, -42, -6, 60], [62, 92, -32, -16, 70], [98, 148, -44, -8, 42], [104, 132, -36, -18, 52]];
      const X0 = 10, X1 = 154, NX = 144, Zs = Z0 - 1, Ze = Z1 + 2, NZ = 56;
      const raw = (x, z) => { let h = 0; for (const [a, b, c, d, hh] of STACK) if (x >= a && x <= b && z >= c && z <= d) h = Math.max(h, hh); return h; };
      const grid = []; for (let ix = 0; ix <= NX; ix++) { grid.push([]); for (let iz = 0; iz <= NZ; iz++) grid[ix].push(raw(X0 + (X1 - X0) * ix / NX, Zs + (Ze - Zs) * iz / NZ)); }
      const blur = (g, rx, rz) => g.map((col, ix) => col.map((_, iz) => { let sum = 0, n = 0;
        for (let dx = -rx; dx <= rx; dx++) for (let dz = -rz; dz <= rz; dz++) { const a = g[ix + dx], v = a && a[iz + dz]; if (v !== undefined) { sum += v; n++; } }
        return sum / n; }));
      let H = blur(blur(grid, 4, 3), 4, 3);
      const zAt = (iz) => Zs + (Ze - Zs) * iz / NZ, xAt = (ix) => X0 + (X1 - X0) * ix / NX;
      const Pt = (ix, iz) => { const z = zAt(iz); let y = H[ix][iz] * 1.08;
        if (z > Z1 - 1) y = Math.min(y, 2);                               // the hem lies on the near rail
        return [xAt(ix), R(BT) + y + 0.3, z]; };
      const t = [], q = (a, b, c, d) => t.push(...a, ...b, ...c, ...a, ...c, ...d);
      for (let ix = 0; ix < NX; ix++) for (let iz = 0; iz < NZ; iz++) q(Pt(ix, iz), Pt(ix, iz + 1), Pt(ix + 1, iz + 1), Pt(ix + 1, iz));
      const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(t, 3)); g.computeVertexNormals();
      add(g, "canvas", "load");
      for (const x of [34, 80, 124]) { const ix = Math.round((x - X0) / (X1 - X0) * NX), pts = [];
        for (let iz = 0; iz <= NZ; iz += 2) { const [px, py, pz] = Pt(ix, iz); pts.push(new THREE.Vector3(px, py + 1.2, pz)); }
        add(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 60, 1.2, 5, false), "rope", "load"); } }
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
      { const g = new THREE.TorusGeometry(r - 11, 1.2, 5, 32); const m = add(g, "tyre", "wheels"); m.position.set(cx, cy, z + 3); }
      { const g = new THREE.TorusGeometry(r - 0.5, 1.3, 5, 32); const m = add(g, "tyre", "wheels"); m.position.set(cx, cy, z - 0.5); }
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
