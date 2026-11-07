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
    canvas: ["cream", 6], lip: ["cream", 7], hoop: ["ochre", 4], inside: ["ochre", 1],
    plank: ["wood", 5], post: ["wood", 4], rim: ["wood", 6], rail: ["wood", 6], cap: ["iron", 3], rivet: ["iron", 2], tyre: ["wood", 3], hub: ["wood", 3], spoke: ["wood", 4], shaft: ["wood", 5],
  };
  const LAYERS = ["ground", "bed", "bonnet", "wheels"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    const cube = (layer, mat, x0, x1, y0, y1, z0, z1) => { const m = add(new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0), mat, layer);
      m.position.set((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2); return m; };
    const R = (row) => 218 - row;
    const Z0 = -48, Z1 = 0, ZM = (Z0 + Z1) / 2;

    // (owner 2026-11-07: 돌린 각도, 천 주름, 천 모양, 짐칸·바퀴 디테일) side on again; the bonnet fuller than the bed
    // and flaring out at its ends; the cloth hung in U folds between the hoops; a top rail and iron-capped posts on the
    // bed; heavier, lighter-rimmed wheels with big square hubs
    // ---- the bed: side planks between posts, a top rail along them, a floor, the shaft out to the right
    cube("bed", "post", 10, 226, R(168), R(100), Z0 + 2, Z1 - 2);                  // the body
    for (const [r0, r1] of [[108, 120], [123, 136], [139, 152], [155, 166]]) cube("bed", "plank", 12, 224, R(r1), R(r0), Z1 - 2, Z1);
    cube("bed", "rail", 6, 230, R(108), R(98), Z0, Z1 + 2.5);                       // the top rail
    for (const x of [22, 84, 142, 200]) { cube("bed", "post", x, x + 14, R(170), R(98), Z1 - 3, Z1 + 1.5);
      cube("bed", "cap", x - 1, x + 15, R(108), R(100), Z1 + 1.5, Z1 + 3.5);         // iron caps over the rail
      for (const yy of [R(104)]) cube("bed", "rivet", x + 5, x + 9, yy - 2, yy + 2, Z1 + 3.5, Z1 + 4.2); }
    cube("bed", "shaft", 214, 272, R(152), R(138), ZM - 4, ZM + 4);
    cube("bed", "post", 264, 278, R(156), R(134), ZM - 5, ZM + 5);

    // ---- the bonnet (owner 2026-11-07: "그냥 원본 형태 좀 더 따라해주면 안되나. 끝부분에 저 형태가 너무 다른데"):
    // its outline taken off the reference row by row - the back end swelling out past the bed and rounding over, the
    // front end belling out wide around its open mouth - and the cloth hung between those ends over the hoops, with
    // two U folds in each bay. L(y), Rx(y): the cloth's ends at height y above the bed top (the reference's columns)
    const lerpT = (tab) => (y) => { if (y <= tab[0][0]) return tab[0][1];
      for (let k = 1; k < tab.length; k++) if (y <= tab[k][0]) { const [y0, x0] = tab[k - 1], [y1, x1] = tab[k]; return x0 + (x1 - x0) * (y - y0) / (y1 - y0); }
      return tab[tab.length - 1][1]; };
    const L = lerpT([[0, 10], [20, 4], [50, 2], [72, 5], [84, 10], [92, 18], [97, 30]]);
    const Rx = lerpT([[0, 220], [30, 234], [56, 238], [74, 236], [86, 229], [94, 218], [97, 206]]);
    { const HO = [22, 90, 148, 212], NU = 260, NV = 90, t = [];
      const bays = [[22, 90], [90, 148], [148, 212]];
      const top = (x) => { let d = 1e9; for (const h of HO) d = Math.min(d, Math.abs(x - h));
        return 97 * (1 - 0.05 * Math.pow(Math.sin(Math.min(d, 30) / 30 * Math.PI / 2), 2)); };
      const fold = (x, yRel) => { let f = 0;
        for (const [a, b] of bays) { if (x < a || x > b) continue; const u = (x - (a + b) / 2) / ((b - a) / 2);
          for (const [low, high] of [[44, 86], [24, 70]]) { const yu = low + (high - low) * u * u;
            f += 0.09 * Math.exp(-Math.pow((yRel - yu) / 6, 2)) * (1 - u * u * 0.6); } }
        return f; };
      const P = (iu, iv) => { const th = Math.PI * iv / NV, sn = Math.sin(th), cs = Math.cos(th);
        let y = 97 * sn; const x0 = L(y), x1 = Rx(y), x = x0 + (x1 - x0) * iu / NU;
        y = Math.min(y, top(x) * sn + (97 - top(x)) * 0);                  // the cloth sags a touch between hoops
        const r = 1 - (cs > 0 ? fold(x, y) : 0);
        return [x, R(100) + y * (1 - (1 - r) * 0.3), ZM + 26.5 * r * cs]; };
      const q = (a, b, c, d) => t.push(...a, ...b, ...c, ...a, ...c, ...d);
      for (let iu = 0; iu < NU; iu++) for (let iv = 0; iv < NV; iv++) q(P(iu, iv), P(iu, iv + 1), P(iu + 1, iv + 1), P(iu + 1, iv));
      for (let iv = 0; iv < NV; iv++) { const a = P(0, iv), b = P(0, iv + 1), c = [L(0) + 4, R(100) + 30, ZM]; t.push(...a, ...b, ...c); }   // the closed back
      const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(t, 3)); g.computeVertexNormals();
      add(g, "canvas", "bonnet");
      // the open mouth at the front: the inside of the belled cloth seen past its lip - a dark sliver inside the edge,
      // the lip itself a light band
      const band = (mat, dx0, dx1, dz) => { const tt = [];
        const Q = (k, d) => { const th = Math.PI * 0.5 * k / 40, y = 97 * Math.sin(th) * 0.98, x = Rx(y) - d; return [x, R(100) + y, ZM + 26.5 * Math.cos(th) + dz]; };
        for (let k = 0; k < 40; k++) tt.push(...Q(k, dx0), ...Q(k, dx1), ...Q(k + 1, dx1), ...Q(k, dx0), ...Q(k + 1, dx1), ...Q(k + 1, dx0));
        const gg = new THREE.BufferGeometry(); gg.setAttribute("position", new THREE.Float32BufferAttribute(tt, 3)); gg.computeVertexNormals();
        add(gg, mat, "bonnet"); };
      band("inside", 3.5, 13, 0.6);
      band("lip", 0.5, 3.5, 0.9); }
    for (const x of [22, 90, 148, 212]) {                             // the hoops: a rib under the cloth, standing just proud
      const pts = []; for (let k = 0; k <= 32; k++) { const th = Math.PI * k / 32; pts.push(new THREE.Vector3(x, R(100) + 96.2 * Math.sin(th), ZM + 27.6 * Math.cos(th))); }
      add(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 64, 1.9, 6, false), "hoop", "bonnet"); }

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
