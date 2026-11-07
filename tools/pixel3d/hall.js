// The guild hall built in code (owner 2026-11-07: "저건 래퍼런스로 쓰고 코드로 도트 구현하라"): every part is a solid in
// three.js, written in the reference sprite's own cells (assets/town/hx/g_hall.png at half size, 436 x 296) so the
// render lines up with it. Rendered with an oblique camera (front faces true, tops recede up at K rows per cell of
// depth), one cell = one pixel; colours come only from the town palette ramps (assets/town/palette.png).
//
// Coordinates: x = reference column, rows counted down from the top; Z = depth toward the viewer (cells). A front face
// at depth z drawn on reference rows r0..r1 has world Y = B0 + K*z - r (B0 = the row of the ground under the walls).
// Materials: [ramp, base step] of the palette; the light moves a cell up or down its own ramp, never across.

const HALL = (function () {
  const W = 436, H = 296, B0 = 282, K = 0.25;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand:    ["ochre", 5], stone: ["cream", 2], stoneLt: ["cream", 3], plaster: ["cream", 5],
    timber:  ["wood", 5],  frame: ["wood", 3], glass: ["ochre", 4], mullion: ["wood", 3],
    roofBase: ["red", 0], tile: ["red", 3], verge: ["red", 3], fascia: ["wood", 2],
    chimney: ["ochre", 1], chimCap: ["ochre", 4], chimTop: ["cream", 4],
    door:    ["wood", 3], doorGap: ["wood", 1], iron: ["iron", 2], sign: ["wood", 4], signRim: ["wood", 2],
    letter:  ["cream", 7], shield: ["cream", 3], finial: ["wood", 4], ball: ["ochre", 6],
  };
  // the layers (the 3D view pulls them apart in this order, back to front)
  const LAYERS = ["ground", "plinth", "walls", "timber", "windows", "roof", "tiles", "chimneys", "gable", "gable timber",
                  "door", "sign", "steps", "verge", "finial"];

  function build(THREE) {
    const parts = [];   // {mesh, mat, layer}
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };

    // an axis-aligned box: x0..x1, front face on rows r0..r1 at depth z1, back at z0
    function box(layer, mat, x0, x1, r0, r1, z0, z1) {
      if (x1 < x0) [x0, x1] = [x1, x0];
      const yt = Y(r0, z1), yb = Y(r1, z1);
      const m = add(new THREE.BoxGeometry(x1 - x0, yt - yb, z1 - z0), mat, layer);
      m.position.set((x0 + x1) / 2, (yt + yb) / 2, (z0 + z1) / 2);
      return m;
    }
    // a bar between two points of a front plane (rows at depth z1), `t` cells thick, z0..z1 deep
    function bar(layer, mat, xa, ra, xb, rb, t, z0, z1) {
      const a = new THREE.Vector2(xa, Y(ra, z1)), b = new THREE.Vector2(xb, Y(rb, z1));
      const len = a.distanceTo(b);
      const m = add(new THREE.BoxGeometry(len, t, z1 - z0), mat, layer);
      m.position.set((a.x + b.x) / 2, (a.y + b.y) / 2, (z0 + z1) / 2);
      m.rotation.z = Math.atan2(b.y - a.y, b.x - a.x);
      return m;
    }
    // a flat shape (points in x / rows at depth z1) pushed back to z0
    function slab(layer, mat, pts, z0, z1, holes) {
      const sh = new THREE.Shape(pts.map(([x, r]) => new THREE.Vector2(x, Y(r, z1))));
      for (const hp of holes || []) sh.holes.push(new THREE.Path(hp.map(([x, r]) => new THREE.Vector2(x, Y(r, z1)))));
      const g = new THREE.ExtrudeGeometry(sh, { depth: z1 - z0, bevelEnabled: false, curveSegments: 24 });
      const m = add(g, mat, layer);
      m.position.z = z0;
      return m;
    }
    // an arch outline: x0..x1, rows r0 (top of the arch) .. r1 (bottom), semicircle on top
    function archPts(x0, x1, r0, r1, n = 20) {
      const rad = (x1 - x0) / 2, cx = (x0 + x1) / 2, spring = r0 + rad;
      const p = [[x0, r1], [x1, r1], [x1, spring]];
      for (let i = 1; i < n; i++) { const a = Math.PI * i / n; p.push([cx + rad * Math.cos(a), spring - rad * Math.sin(a)]); }
      p.push([x0, spring]);
      return p;
    }
    // a hexahedron from 8 world points (front quad a, back quad b), for tiles and roof planes
    function hexa(layer, mat, q) {
      const g = new THREE.BufferGeometry();
      const v = [];
      const faces = [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]];
      for (const f of faces) {
        const [a, b, c, d] = f.map(i => q[i]);
        v.push(...a, ...b, ...c, ...a, ...c, ...d);
      }
      g.setAttribute("position", new THREE.Float32BufferAttribute(v, 3));
      g.computeVertexNormals();
      return add(g, mat, layer);
    }
    const mirror = (x) => W - x;

    // ---- ground and plinth
    { const g = new THREE.PlaneGeometry(W, 54); g.rotateX(-Math.PI / 2);
      const m = add(g, "sand", "ground"); m.position.set(W / 2, 0, 4 + 27); }
    for (let x = 20; x < 416; x += 25) box("plinth", "stone", x, Math.min(x + 24, 416), 266, 282, -4, 5);

    // ---- the wings: plaster body, timber frame, windows
    box("walls", "plaster", 28, 408, 168, 266, -78, 0);
    const posts = [[28, 36], [80, 88], [130, 138]];
    const bays = [[36, 80], [88, 130]];
    for (const side of [0, 1]) {
      const X = side ? (a, b) => [mirror(b), mirror(a)] : (a, b) => [a, b];
      for (const [a, b] of posts) box("timber", "timber", ...X(a, b), 168, 266, -2, 1.5);
      for (const [r0, r1] of [[168, 172], [206, 210], [260, 266]]) box("timber", "timber", ...X(28, 142), r0, r1, -2, 1.5);
      for (const [a, b] of bays) {
        const c = (a + b) / 2;
        const fx = side ? mirror : (x) => x;
        // upper band: short corner braces over the window's shoulders; lower band: a pitched brace over the window
        bar("timber", "timber", fx(a), 173, fx(a + 11), 184, 3, -2, 1.2);
        bar("timber", "timber", fx(b), 173, fx(b - 11), 184, 3, -2, 1.2);
        bar("timber", "timber", fx(a), 230, fx(c), 211, 3, -2, 1.2);
        bar("timber", "timber", fx(b), 230, fx(c), 211, 3, -2, 1.2);
        for (const [r0, r1] of [[179, 204], [225, 250]]) window_(fx(c) - 11, fx(c) + 11, r0, r1, 0);
      }
    }
    function window_(x0, x1, r0, r1, z) {
      // reference windows: a heavy dark frame, four light panes behind a cross of mullions, a stone sill
      const outer = archPts(x0, x1, r0, r1), inner = archPts(x0 + 3, x1 - 3, r0 + 3, r1 - 2);
      slab("windows", "frame", outer, z, z + 1.6, [inner.slice().reverse()]);
      slab("windows", "glass", inner, z, z + 0.3);
      box("windows", "frame", x0 + 3, x1 - 3, r1 - 2, r1, z, z + 1.6);
      const cx = (x0 + x1) / 2, mid = Math.round((r0 + 3 + (x1 - x0) / 2 + r1 - 2) / 2);
      box("windows", "mullion", cx - 1, cx + 1, r0 + 3, r1 - 2, z, z + 0.9);
      box("windows", "mullion", x0 + 3, x1 - 3, mid - 1, mid + 1, z, z + 0.9);
      box("windows", "stoneLt", x0 - 2, x1 + 2, r1, r1 + 3, z, z + 3);   // the sill
    }

    // ---- the wing roofs (hips): eave row 166 at Z 12, ridge row 81 at Z -40, back eave at Z -92
    const ZE = 12, ZR = -40, ZB = -92, RE = 166, RR = 81;
    const ye = Y(RE, ZE), yr = Y(RR, ZR);
    for (const side of [0, 1]) {
      const fx = side ? mirror : (x) => x;
      const P = (x, y, z) => [fx(x), y, z];
      // the roof body as one closed solid: front slope, hip end, back slope (the gable hides the inner end)
      const e0 = P(12, ye, ZE), e1 = P(218, ye, ZE), r0 = P(62, yr, ZR), r1 = P(218, yr, ZR), b0 = P(12, ye, ZB), b1 = P(218, ye, ZB);   // runs on behind the gable to the middle
      const tri = [];
      const quad = (a, b, c, d) => tri.push(...a, ...b, ...c, ...a, ...c, ...d);
      const t3 = (a, b, c) => tri.push(...a, ...b, ...c);
      if (!side) { quad(e0, e1, r1, r0); t3(e0, r0, b0); quad(b1, b0, r0, r1); quad(e0, b0, b1, e1); quad(e1, b1, r1, r1); }
      else { quad(e1, e0, r0, r1); t3(r0, e0, b0); quad(b0, b1, r1, r0); quad(b0, e0, e1, b1); quad(b1, e1, r1, r1); }
      const g = new THREE.BufferGeometry();
      g.setAttribute("position", new THREE.Float32BufferAttribute(tri, 3));
      g.computeVertexNormals();
      add(g, "roofBase", "roof");
      // the eave board along the front edge
      box("roof", "fascia", fx(10), fx(140), 166, 170, ZE - 6, ZE + 1.5);
      // tiles: five courses, staggered, joints leaning with the hip, each course's butt lifted over the one below
      const courses = [81, 98, 115, 132, 149, 166];
      const slopeN = new THREE.Vector3(0, ZE - ZR, yr - ye).normalize();   // the slope's outward normal: up and toward the viewer
      const onSlope = (x, row) => { const u = (RE - row) / (RE - RR); return new THREE.Vector3(fx(x), ye + u * (yr - ye), ZE + u * (ZR - ZE)); };
      const hipX = (row) => 12 + (RE - row) * 50 / (RE - RR);
      for (let c = 0; c < 5; c++) {
        const rt = courses[c], rb = courses[c + 1] + 1.5;               // each course hangs 1.5 rows over the next
        const lean = 0.35 * (rb - rt);
        for (let x = (c % 2 ? -11 : 0) + 4; x < 218; x += 22) {
          let xt0 = x + 0.8, xt1 = x + 21.2, xb0 = xt0 - lean, xb1 = xt1 - lean;
          const ht = hipX(rt), hb = hipX(rb);
          if (xt1 <= ht && xb1 <= hb) continue;
          xt0 = Math.max(xt0, ht); xb0 = Math.max(xb0, hb); // tiles stop where the gable covers them (its wall below the verge, the verge above): no tile pokes through
          const cut = (row) => Math.max(142, Math.min(218, 218 - (row - 28) / 1.07 + 8));
          xt1 = Math.min(Math.max(xt1, ht + 1), cut(rt)); xb1 = Math.min(Math.max(xb1, hb + 1), cut(rb));
          if (xt0 >= cut(rt) || xb0 >= cut(rb)) continue;
          const lt = 1.6, lb = 4.6;
          const v = [onSlope(xb0, rb), onSlope(xb1, rb), onSlope(xt1, rt), onSlope(xt0, rt)];
          const front = [v[0].clone().addScaledVector(slopeN, lb), v[1].clone().addScaledVector(slopeN, lb),
                         v[2].clone().addScaledVector(slopeN, lt), v[3].clone().addScaledVector(slopeN, lt)];
          const q = side ? [front[1], front[0], front[3], front[2], v[1], v[0], v[3], v[2]] : [...front, ...v];
          hexa("tiles", "tile", q.map(p => [p.x, p.y, p.z]));
        }
      }
      // chimney behind the ridge-side of the slope
      box("chimneys", "chimney", fx(side ? 139 : 108), fx(side ? 108 : 139), 58, 150, -52, -38).position.x = side ? mirror(123.5) : 123.5;
      box("chimneys", "chimCap", fx(side ? 142 : 105), fx(side ? 105 : 142), 50, 58, -54, -36).position.x = side ? mirror(123.5) : 123.5;
      box("chimneys", "chimTop", fx(side ? 139 : 111), fx(side ? 111 : 139), 46, 50, -50, -40).position.x = side ? mirror(125) : 125;
    }

    // ---- the gable (front at Z 8)
    const ZG = 16;                                            // the gable stands out in front of the wing eaves (Z 12)
    const vU = (x) => 40 + Math.abs(x - 218) * 1.05;          // the verge's underside, as a row
    slab("gable", "plaster", [[142, 264], [294, 264], [294, vU(294)], [218, 40], [142, vU(142)]], -40, ZG);
    for (const [a, b] of [[142, 150], [189, 195], [241, 247], [286, 294]]) {
      const top = Math.min(vU(a), vU(b)) - 2;
      box("gable timber", "timber", a, b, top, 264, ZG - 2, ZG + 1.5);
    }
    for (const [r0, r1] of [[104, 108], [136, 140], [176, 180], [258, 264]]) {
      const half = (r0 - 40) / 1.05;
      box("gable timber", "timber", Math.max(142, 218 - half), Math.min(294, 218 + half), r0, r1, ZG - 2, ZG + 1.5);
    }
    for (const [a, b] of [[150, 189], [195, 241], [247, 286]]) {
      bar("gable timber", "timber", a, 109, b, 135, 3, ZG - 2, ZG + 1.2);
      bar("gable timber", "timber", b, 109, a, 135, 3, ZG - 2, ZG + 1.2);
    }
    for (const [a, b] of [[150, 189], [247, 286]]) {
      bar("gable timber", "timber", a, 182, b, 224, 3, ZG - 2, ZG + 1.2);
      bar("gable timber", "timber", b, 182, a, 224, 3, ZG - 2, ZG + 1.2);
    }
    for (const [x0, r0] of [[207, 80], [157, 150], [207, 150], [257, 150], [157, 227], [257, 227]]) window_(x0, x0 + 22, r0, r0 + 23, ZG);

    // the door: two leaves of planks in a stone arch, set back into the wall
    slab("door", "doorGap", archPts(198, 238, 213, 264), ZG, ZG + 0.3);
    for (let x = 199; x < 237; x += 6) {
      const x1 = Math.min(x + 5, 237);
      // plank = the arch clipped to [x, x1]
      const rad = 20, cx = 218, spring = 233;
      const top = (xx) => spring - Math.sqrt(Math.max(0, rad * rad - (xx - cx) * (xx - cx)));
      const poly = [[x, 264], [x1, 264]];
      for (let s = 0; s <= 4; s++) { const xx = x1 - (x1 - x) * s / 4; poly.push([xx, top(xx) + 1]); }
      slab("door", "door", poly, ZG, ZG + 0.9);
    }
    for (const r of [228, 252]) { box("door", "iron", 201, 216, r, r + 2, ZG, ZG + 1.4); box("door", "iron", 220, 235, r, r + 2, ZG, ZG + 1.4); }
    slab("door", "stone", archPts(193, 243, 208, 264), ZG, ZG + 2.4, [archPts(198, 238, 213, 264).slice().reverse()]);

    // the sign: board, rim, shield, letters
    box("sign", "signRim", 172, 262, 186, 207, ZG, ZG + 3);
    box("sign", "sign", 174, 260, 188, 205, ZG, ZG + 3.6);
    slab("sign", "shield", [[212, 180], [224, 180], [224, 187], [218, 193], [212, 187]], ZG + 3, ZG + 4.4);
    const GL = {
      C: [" ### ", "#   #", "#    ", "#    ", "#    ", "#   #", " ### "], L: ["#    ", "#    ", "#    ", "#    ", "#    ", "#    ", "#####"],
      U: ["#   #", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "], M: ["#   #", "## ##", "# # #", "#   #", "#   #", "#   #", "#   #"],
      S: [" ####", "#    ", "#    ", " ### ", "    #", "    #", "#### "], Y: ["#   #", "#   #", " # # ", "  #  ", "  #  ", "  #  ", "  #  "],
      V: ["#   #", "#   #", "#   #", "#   #", "#   #", " # # ", "  #  "], A: [" ### ", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
      O: [" ### ", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "], R: ["#### ", "#   #", "#   #", "#### ", "# #  ", "#  # ", "#   #"],
    };
    const text = "CLUMSY VALOR";
    let lx = 218 - (text.length * 6 - 1) / 2;
    for (const ch of text) {
      const g = GL[ch];
      if (g) g.forEach((row, ry) => [...row].forEach((c, rx) => { if (c === "#") box("sign", "letter", lx + rx, lx + rx + 1, 193 + ry, 194 + ry, ZG + 3.6, ZG + 4.2); }));
      lx += 6;
    }

    // steps, three treads stepping out toward the viewer
    box("steps", "stoneLt", 182, 254, 262, 268, -10, 22);
    box("steps", "stoneLt", 176, 260, 268, 274, -10, 28);
    box("steps", "stoneLt", 170, 266, 274, 280, -10, 34);

    // the verges: two thick boards from the apex, an eave board under each, and the short gable roof behind them
    const ZV0 = 14, ZV1 = 22;
    for (const s of [-1, 1]) {
      const xe = 218 + s * 112, re = 28 + 112 * 1.07;
      bar("verge", "verge", 218, 28 + 6, xe, re + 6, 12, ZV0, ZV1);
      bar("verge", "fascia", 218, 28 + 13, xe, re + 13, 3, ZV0 - 1, ZV1 - 1);
      // the gable roof slope behind the verge
      const a = [218, Y(28, ZV1), ZV0], b = [xe, Y(re, ZV1), ZV0];
      const q = s < 0
        ? [a, b, [b[0], b[1], -40], [a[0], a[1], -40], [a[0], a[1] - 6, ZV0], [b[0], b[1] - 6, ZV0], [b[0], b[1] - 6, -40], [a[0], a[1] - 6, -40]]
        : [b, a, [a[0], a[1], -40], [b[0], b[1], -40], [b[0], b[1] - 6, ZV0], [a[0], a[1] - 6, ZV0], [a[0], a[1] - 6, -40], [b[0], b[1] - 6, -40]];
      hexa("verge", "tile", q);
    }
    // the finial on the apex
    { const g = new THREE.CylinderGeometry(1.6, 1.6, 26, 8); const m = add(g, "finial", "finial"); m.position.set(218, Y(18, 18), 18); }
    { const g = new THREE.SphereGeometry(3, 12, 8); const m = add(g, "ball", "finial"); m.position.set(218, Y(4, 18), 18); }

    return parts;
  }
  return { W, H, B0, K, Y, RAMP, MAT, LAYERS, build };
})();
