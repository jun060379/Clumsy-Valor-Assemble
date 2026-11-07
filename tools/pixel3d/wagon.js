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
    canvas: ["cream", 6], hoop: ["ochre", 4], inside: ["wood", 1],
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

    // ---- the bonnet: cloth over four hoops, fuller than the bed, its ends flaring out, closed behind, open in front
    { const HO = [22, 90, 148, 212], XA = 6, XB = 230, NU = 280, NV = 90, t = [];
      const bays = [[22, 90], [90, 148], [148, 212]];
      const hgt = (x) => { let d = 1e9; for (const h of HO) d = Math.min(d, Math.abs(x - h));
        const k = Math.pow(Math.sin(Math.min(d, 30) / 30 * Math.PI / 2), 2);     // 0 at a hoop, 1 midway between
        const e = Math.min(x - XA, XB - x), end = e < 16 ? Math.sqrt(Math.max(0, 1 - Math.pow((16 - e) / 16, 2))) : 1;
        return [96 * (1 - 0.06 * k) * (0.45 + 0.55 * end), 26.5 * (1 - 0.05 * k)]; };
      // the U folds: in each bay two creases hang from near the hoop tops down to a low point midway, the cloth
      // pressed in along them, so the faces above each crease turn down and fall into shade
      const fold = (x, yRel) => { let f = 0;
        for (const [a, b] of bays) { if (x < a || x > b) continue; const u = (x - (a + b) / 2) / ((b - a) / 2);
          for (const [low, high] of [[44, 86], [24, 70]]) { const yu = low + (high - low) * u * u;
            f += 0.09 * Math.exp(-Math.pow((yRel - yu) / 6, 2)) * (1 - u * u * 0.6); } }
        return f; };
      const P = (iu, iv) => { let x = XA + (XB - XA) * iu / NU; const th = Math.PI * iv / NV, [h, w] = hgt(x);
        const e = Math.min(x - XA, XB - x); if (e < 16) x += (x < 118 ? -1 : 1) * 7 * (1 - e / 16) * Math.sin(th);   // the flared ends
        const yRel = h * Math.sin(th), r = 1 - (Math.cos(th) > 0 ? fold(x, yRel) : 0);
        return [x, R(100) + yRel * (1 - (1 - r) * 0.3), ZM + w * r * Math.cos(th)]; };
      const q = (a, b, c, d) => t.push(...a, ...b, ...c, ...a, ...c, ...d);
      for (let iu = 0; iu < NU; iu++) for (let iv = 0; iv < NV; iv++) q(P(iu, iv), P(iu, iv + 1), P(iu + 1, iv + 1), P(iu + 1, iv));
      const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(t, 3)); g.computeVertexNormals();
      add(g, "canvas", "bonnet"); }
    for (const x of [22, 90, 148, 212]) { const g = new THREE.TorusGeometry(1, 0.08, 5, 24, Math.PI); const m = add(g, "hoop", "bonnet");
      m.rotation.y = Math.PI / 2; m.scale.set(27.5, 97.5, 27.5); m.position.set(x, R(100), ZM); }
    { const g = new THREE.CircleGeometry(1, 24, 0, Math.PI); const m = add(g, "inside", "bonnet");            // the dark of the open front
      m.rotation.y = Math.PI / 2; m.scale.set(24, 44, 1); m.position.set(234, R(100), ZM); }

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
