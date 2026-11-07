// The covered wagon built in code (owner 2026-11-07: 작은 소품). The reference sprite (assets/town/g_wagon2.png, 280 x
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
    canvas: ["cream", 6], hoop: ["ochre", 3], inside: ["wood", 1],
    plank: ["wood", 5], post: ["wood", 4], rim: ["wood", 5], tyre: ["wood", 3], hub: ["wood", 3], spoke: ["wood", 4], shaft: ["wood", 5],
  };
  const LAYERS = ["ground", "bed", "bonnet", "wheels"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    const cube = (layer, mat, x0, x1, y0, y1, z0, z1) => { const m = add(new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0), mat, layer);
      m.position.set((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2); return m; };
    const R = (row) => 218 - row;
    const Z0 = -48, Z1 = 0, ZM = (Z0 + Z1) / 2;

    // ---- the bed: side planks between posts, a floor, the shaft out to the right
    cube("bed", "post", 10, 226, R(168), R(100), Z0 + 2, Z1 - 2);                  // the body
    for (const [r0, r1] of [[102, 116], [119, 134], [137, 152], [155, 166]]) cube("bed", "plank", 10, 226, R(r1), R(r0), Z1 - 2, Z1);
    for (const x of [22, 84, 142, 200]) cube("bed", "post", x, x + 14, R(170), R(98), Z1 - 3, Z1 + 1.5);
    cube("bed", "shaft", 214, 272, R(152), R(138), ZM - 4, ZM + 4);
    cube("bed", "post", 264, 278, R(156), R(134), ZM - 5, ZM + 5);

    // ---- the bonnet: canvas stretched over hoops, closed at the back, open at the front
    // the canvas drawn over the hoops: full height at each hoop, sagging a little between them, the ends rounding
    // off and flaring out past the bed, as a bonnet does
    { const HO = [22, 90, 148, 212], XA = 4, XB = 232, NU = 90, NV = 20, t = [];
      const hgt = (x) => { let d = 1e9; for (const h of HO) d = Math.min(d, Math.abs(x - h));
        const sag = 1 - 0.07 * Math.pow(Math.sin(Math.min(d, 30) / 30 * Math.PI / 2), 2);
        const e = Math.min(x - XA, XB - x), end = e < 18 ? Math.sqrt(Math.max(0, 1 - Math.pow((18 - e) / 18, 2))) : 1;
        return [96 * sag * (0.35 + 0.65 * end), 25.5 * (0.85 + 0.15 * end)]; };
      const P = (iu, iv) => { const x = XA + (XB - XA) * iu / NU, th = Math.PI * iv / NV, [h, w] = hgt(x);
        return [x, R(100) + h * Math.sin(th), ZM + w * Math.cos(th)]; };
      const q = (a, b, c, d) => t.push(...a, ...b, ...c, ...a, ...c, ...d);
      for (let iu = 0; iu < NU; iu++) for (let iv = 0; iv < NV; iv++) q(P(iu, iv), P(iu, iv + 1), P(iu + 1, iv + 1), P(iu + 1, iv));
      const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(t, 3)); g.computeVertexNormals();
      add(g, "canvas", "bonnet"); }
    for (const x of [22, 90, 148, 212]) { const g = new THREE.TorusGeometry(1, 0.045, 5, 24, Math.PI); const m = add(g, "hoop", "bonnet");
      m.rotation.y = Math.PI / 2; m.scale.set(26, 97, 26); m.position.set(x, R(100), ZM); }
    { const g = new THREE.CircleGeometry(1, 24, 0, Math.PI); const m = add(g, "inside", "bonnet");            // the dark of the open front
      m.rotation.y = Math.PI / 2; m.scale.set(20, 30, 1); m.position.set(229, R(100), ZM); }

    // ---- the wheels: an iron-shod rim, eight spokes, a hub; big at the back, smaller at the front
    const wheel = (cx, cyRow, r, z) => {
      const cy = R(cyRow);
      { const g = new THREE.TorusGeometry(r - 4, 4.6, 6, 32); const m = add(g, "rim", "wheels"); m.position.set(cx, cy, z); }
      { const g = new THREE.TorusGeometry(r - 0.5, 1.3, 5, 32); const m = add(g, "tyre", "wheels"); m.position.set(cx, cy, z - 0.5); }
      for (let i = 0; i < 4; i++) { const a = i / 4 * Math.PI; const m = cube("wheels", "spoke", -2.6, 2.6, -(r - 5), r - 5, -1.5, 1.5);
        m.position.set(cx, cy, z); m.rotation.z = a; }
      { const g = new THREE.CylinderGeometry(9, 9, 9, 12); const m = add(g, "hub", "wheels"); m.rotation.x = Math.PI / 2; m.position.set(cx, cy, z + 1); }
    };
    wheel(60, 172, 46, Z1 + 6);
    wheel(181, 176, 42, Z1 + 6);
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
