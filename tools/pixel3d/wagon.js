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

    // ---- the load under a tarp: a rounded heap over the back two thirds, sagging between the ropes
    const ROPES = [36, 78, 120];
    { const XA = 14, XB = 150, NU = 200, NV = 70, t = [], HMAX = 70, DW = 25;
      const P = (iu, iv) => { const u = iu / NU, th = Math.PI * iv / NV, x = XA + (XB - XA) * u;
        const ends = Math.pow(Math.sin(Math.PI * Math.min(1, Math.min(u, 1 - u) * 5) / 2), 0.6);   // rounded at both ends
        let d = 1e9; for (const r of ROPES) d = Math.min(d, Math.abs(x - r));
        const sag = 1 - 0.07 * Math.exp(-Math.pow(d / 4, 2)) - 0.03 * Math.sin(x * 0.21);       // pulled in under the ropes
        const h = HMAX * ends * (0.92 + 0.08 * Math.sin(x * 0.05 + 1)) * sag;
        return [x, R(BT) + h * Math.sin(th), ZM + DW * sag * Math.cos(th) * (0.7 + 0.3 * ends)]; };
      const q = (a, b, c, d) => t.push(...a, ...b, ...c, ...a, ...c, ...d);
      for (let iu = 0; iu < NU; iu++) for (let iv = 0; iv < NV; iv++) q(P(iu, iv), P(iu, iv + 1), P(iu + 1, iv + 1), P(iu + 1, iv));
      const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(t, 3)); g.computeVertexNormals();
      add(g, "canvas", "load");
      for (const x of ROPES) { const pts = []; for (let k = 0; k <= 32; k++) { const pp = P(Math.round((x - XA) / (XB - XA) * NU), k * NV / 32);
          pts.push(new THREE.Vector3(pp[0], pp[1], pp[2]).add(new THREE.Vector3(0, Math.sin(Math.PI * k / 32) * 0.8, Math.cos(Math.PI * k / 32) * 0.8))); }
        add(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 48, 1.3, 5, false), "rope", "load"); } }
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
