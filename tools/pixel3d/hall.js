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
    sand:    ["ochre", 5], plinth: ["cream", 3], mortar2: ["wood", 2], crack: ["cream", 1], plinthHi: ["cream", 5], plinthLo: ["cream", 1], stone: ["cream", 2], stoneLt: ["cream", 3], plaster: ["cream", 6],
    timber:  ["wood", 5],  frame: ["wood", 3], glass: ["ochre", 4], mullion: ["wood", 3],
    roofBase: ["red", 1], tile: ["red", 2], verge: ["red", 2], fascia: ["wood", 1],
    chimney: ["ochre", 1], chimCap: ["wood", 5], chimTop: ["cream", 5],
    door:    ["wood", 3], doorGap: ["wood", 1], iron: ["iron", 2], sign: ["wood", 4], signRim: ["wood", 2],
    letter:  ["cream", 7], shield: ["cream", 3], finial: ["wood", 4], ball: ["ochre", 6],
    glassHi: ["cream", 7], chimHi: ["ochre", 3], chimCrack: ["ochre", 0], mortar: ["ochre", 0], nail: ["iron", 1], shutter: ["wood", 3],
    curtain: ["cream", 7], planter: ["wood", 3], leaves: ["leaf", 4], flower: ["violet", 5],
  };
  // the layers (the 3D view pulls them apart in this order, back to front)
  const LAYERS = ["ground", "plinth", "walls", "timber", "windows", "roof", "tiles", "chimneys", "gable", "gable timber",
                  "door", "sign", "steps", "verge", "finial"];

  function build(THREE) {
    const parts = [];   // {mesh, mat, layer}
    let winN = 0;       // windows built so far (picks each window's variant)
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
    // (no ground strip: the town draws its own ground under the building)
    // the plinth: a dry-stone base (owner 2026-11-07: not cut up, not all alike, not plain boxes, with texture). A
    // continuous mortar bed behind; stones in two staggered courses with now and then one tall stone, each a little
    // different (chamfered corners, a bump on top), some with a crack. A fixed seed: the same wall every time.
    { let seed = 7;
      const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
      const runs = [[20, 140, 6], [140, 296, 19], [296, 416, 6]];
      for (const [a, b, zf] of runs) {
        box("plinth", "mortar2", a, b, 268, 282, -4, zf - 0.8);
        const stone = (x0, x1, r0, r1) => {
          const c = 2 + Math.floor(rnd() * 2), c2 = 2 + Math.floor(rnd() * 2), bump = rnd() < 0.5 ? 1 : 0;
          const mx = (x0 + x1) / 2 + (rnd() - 0.5) * (x1 - x0) * 0.4;
          // rounded on top (2-3 cell chamfers), softer at the foot, the top edge not quite straight
          const pts = [[x0, r1 - 1], [x0 + 1, r1], [x1 - 1, r1], [x1, r1 - 1], [x1, r0 + c2], [x1 - 1, r0 + 1], [x1 - c2, r0],
                       [mx + 3, r0], [mx, r0 - bump], [mx - 3, r0], [x0 + c, r0], [x0 + 1, r0 + 1], [x0, r0 + c]];
          slab("plinth", "plinth", pts, zf - 1.2, zf);
          box("plinth", "plinthHi", x0 + c, x1 - c2, r0 + 1, r0 + 2, zf - 0.5, zf + 0.15);   // the lit top
          box("plinth", "plinthLo", x0 + 2, x1 - 2, r1 - 2, r1 - 1, zf - 0.5, zf + 0.15);     // the shaded foot
          if (rnd() < 0.45 && x1 - x0 > 12) {                // a crack: two short strokes from the top edge
            const sx = x0 + 4 + rnd() * (x1 - x0 - 8), sr = r0 + 2, dx = rnd() < 0.5 ? -1 : 1;
            bar("plinth", "crack", sx, sr, sx + dx * 2, sr + 3, 1, zf - 0.3, zf + 0.2);
            bar("plinth", "crack", sx + dx * 2, sr + 3, sx + dx * 2, sr + 6, 1, zf - 0.3, zf + 0.2);
          }
          if (rnd() < 0.6 && x1 - x0 > 10) {                 // a pit or two in the stone's face (2-cell dashes, not dots)
            const px = x0 + 3 + rnd() * (x1 - x0 - 7), pr = r0 + 5 + Math.floor(rnd() * 4);
            box("plinth", "crack", px, px + 2, pr, pr + 1, zf - 0.3, zf + 0.2);
          }
        };
        let x = a;
        while (x < b - 4) {
          const w = Math.min(b - x, 15 + Math.floor(rnd() * 16));
          const dr = Math.floor(rnd() * 2);                   // heights differ by a row
          stone(x, x + w - 1, 268 + dr, 281);
          x += w;
        }
      }
    }

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
        bar("timber", "timber", fx(a), 173, fx(a + 11), 184, 4, -2, 1.2);
        bar("timber", "timber", fx(b), 173, fx(b - 11), 184, 4, -2, 1.2);
        bar("timber", "timber", fx(a), 222, fx(c), 211, 4, -2, 1.2);   // 2:1, a clean pixel step
        bar("timber", "timber", fx(b), 222, fx(c), 211, 4, -2, 1.2);
        for (const [r0, r1] of [[179, 204], [225, 250]]) window_(fx(c) - 11, fx(c) + 11, r0, r1, 0);
        // the ground-floor windows of the wings have shutters, swung open against the wall
        for (const [sx0, sx1] of [[fx(c) - 17, fx(c) - 12], [fx(c) + 12, fx(c) + 17]]) box("windows", "shutter", sx0, sx1, 231, 250, 0, 1.2);
      }
    }
    function window_(x0, x1, r0, r1, z) {
      // reference windows: a heavy dark frame, four light panes behind a cross of mullions, a stone sill
      const outer = archPts(x0, x1, r0, r1), inner = archPts(x0 + 3, x1 - 3, r0 + 3, r1 - 2);
      slab("windows", "frame", outer, z, z + 1.6, [inner.slice().reverse()]);
      slab("windows", "glass", inner, z, z + 0.3);
      box("windows", "frame", x0 + 3, x1 - 3, r1 - 2, r1, z, z + 1.6);
      const cx = (x0 + x1) / 2, mid = Math.round(r0 + 3 + (x1 - x0 - 6) / 2 + 1);   // the transom at the arch's spring: two even panes, no sliver
      box("windows", "mullion", cx - 1, cx + 1, r0 + 3, r1 - 2, z, z + 0.9);
      box("windows", "mullion", x0 + 3, x1 - 3, mid - 1, mid + 1, z, z + 0.9);
      box("windows", "stoneLt", x0 - 2, x1 + 2, r1, r1 + 3, z, z + 3);   // the sill
      // not every window alike: some have curtains drawn, some a flower box (a fixed order, not random)
      const v = [0, 2, 1, 0, 0, 1, 2, 0, 1, 0, 0, 2, 0, 1][winN++ % 14];
      if (v === 2) {                                         // (no curtains: owner 2026-11-07, they read as beige blocks)
        box("windows", "planter", x0 - 1, x1 + 1, r1 + 3, r1 + 8, z, z + 5);
        const top = [];
        for (let i = 0; i <= 8; i++) { const xx = x0 - 1 + (x1 - x0 + 2) * i / 8; top.push([xx, r1 + 3 - (i % 2 ? 7 : 5)]); }
        slab("windows", "leaves", [[x1 + 1, r1 + 3.5], [x0 - 1, r1 + 3.5], ...top], z + 2, z + 4.6);
        for (const [fx0, fr] of [[x0 + 1, r1 - 3], [cx - 2, r1 - 4], [x1 - 4, r1 - 2]]) box("windows", "flower", fx0, fx0 + 3, fr, fr + 2, z + 4.6, z + 5.4);
      }
    }

    // ---- the wing roofs (hips): eave row 166 at Z 12, ridge row 81 at Z -40, back eave at Z -92
    const ZE = 12, ZR = -40, ZB = -92, RE = 166, RR = 81;
    const ye = Y(RE, ZE), yr = Y(RR, ZR);
    for (const side of [0, 1]) {
      const fx = side ? mirror : (x) => x;
      const P = (x, y, z) => [fx(x), y, z];
      // the roof body as one closed solid: front slope, hip end, back slope (the gable hides the inner end)
      const e0 = P(12, ye, ZE), e1 = P(218, ye, ZE), r0 = P(54.5, yr, ZR), r1 = P(218, yr, ZR), b0 = P(12, ye, ZB), b1 = P(218, ye, ZB);   // runs on behind the gable to the middle
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
      const hipX = (row) => 12 + (RE - row) * 0.5;                    // the hip at 1:2
      for (let c = 0; c < 5; c++) {
        const rt = courses[c], rb = courses[c + 1] + 1.5;               // each course hangs 1.5 rows over the next
        const lean = 0.5 * (rb - rt);                                   // joints at 1:2, like the hip
        for (let x = (c % 2 ? -13 : 0) + 4; x < 218; x += 26) {          // big tiles: fewer, chunkier
          let xt0 = x + 0.8, xt1 = x + 25.2, xb0 = xt0 - lean, xb1 = xt1 - lean;
          const ht = hipX(rt), hb = hipX(rb);
          if (xt1 <= ht && xb1 <= hb) continue;
          xt0 = Math.max(xt0, ht); xb0 = Math.max(xb0, hb); // tiles stop where the gable covers them (its wall below the verge, the verge above): no tile pokes through
          const cut = (row) => Math.max(142, Math.min(218, 218 - (row - 28) + 8));
          xt1 = Math.min(Math.max(xt1, ht + 1), cut(rt)); xb1 = Math.min(Math.max(xb1, hb + 1), cut(rb));
          if (xt0 >= cut(rt) || xb0 >= cut(rb)) continue;
          // a tile in two bands: the upper rises out of the course (catches the light), the lower rolls down to its
          // butt (turns from the sun), the way the reference tiles are lit on top and dark at the foot
          // three bands: a steep lip that catches the light, the body, the foot rolled down into shade; some tiles sit a
          // little proud or sunk (fixed per tile, not noise)
          const hh = Math.abs(Math.sin((x + 7) * 12.9898 + c * 78.233) * 43758.5453) % 1;
          const dz = hh > 0.85 ? 0.9 : hh < 0.12 ? -0.6 : 0.0;
          const lt = 0.6 + dz, lq = 2.6 + dz, lm = 4.4 + dz, lb = 2.8 + dz, fq = 0.16, f = 0.66;
          const rq = rt + fq * (rb - rt), xq0 = xt0 + fq * (xb0 - xt0), xq1 = xt1 + fq * (xb1 - xt1);
          const rm = rt + f * (rb - rt), xm0 = xt0 + f * (xb0 - xt0), xm1 = xt1 + f * (xb1 - xt1);
          const seg = (xa0, xa1, ra, la, xc0, xc1, rc, lc) => {     // a: lower edge, c: upper edge
            const v = [onSlope(xa0, ra), onSlope(xa1, ra), onSlope(xc1, rc), onSlope(xc0, rc)];
            const fr = [v[0].clone().addScaledVector(slopeN, la), v[1].clone().addScaledVector(slopeN, la),
                        v[2].clone().addScaledVector(slopeN, lc), v[3].clone().addScaledVector(slopeN, lc)];
            const q = side ? [fr[1], fr[0], fr[3], fr[2], v[1], v[0], v[3], v[2]] : [...fr, ...v];
            hexa("tiles", "tile", q.map(p => [p.x, p.y, p.z]));
          };
          seg(xq0, xq1, rq, lq, xt0, xt1, rt, lt);
          seg(xm0, xm1, rm, lm, xq0, xq1, rq, lq);
          seg(xb0, xb1, rb, lb, xm0, xm1, rm, lm);
        }
      }
      // chimney behind the ridge-side of the slope
      // the chimney, laid like the plinth (owner 2026-11-07: "굴뚝도"): a mortar core, stone courses of varied blocks
      // with rounded corners, lit tops, shaded feet, a crack here and there, soot near the top (pattern pass); a cap
      // slab with chamfered ends and a lighter crown. Mirrored stone order per side, fixed seed.
      { let seed = 41;
        const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
        const X = (a, b) => side ? [mirror(b), mirror(a)] : [a, b];
        box("chimneys", "mortar2", ...X(108, 139), 58, 150, -52, -38.6);
        for (let r = 58, c = 0; r < 110; r += 6, c++) {
          let x = 108 - (c % 2 ? 5 : 0);
          while (x < 139) {
            const w = 8 + Math.floor(rnd() * 6);
            const xa = Math.max(108, x), xb = Math.min(139, x + w - 1);
            if (xb - xa >= 3) {
              const [p, q] = X(xa, xb);
              const pts = [[p, r + 4], [p + 1, r + 5], [q - 1, r + 5], [q, r + 4], [q, r + 1], [q - 1, r], [p + 1, r], [p, r + 1]];
              slab("chimneys", "chimney", pts, -52, -38);
              box("chimneys", "chimHi", p + 1, q - 1, r, r + 1, -38.5, -37.85);
              if (rnd() < 0.25 && q - p > 7) { const sx = p + 3 + rnd() * (q - p - 6); bar("chimneys", "chimCrack", sx, r + 1, sx + 1, r + 4, 1, -38.3, -37.8); }
            }
            x += w;
          }
        }
        const [ca, cb] = X(105, 142), [ta, tb] = X(110, 137);
        slab("chimneys", "chimCap", [[ca, 58], [cb, 58], [cb, 52], [cb - 2, 50], [ca + 2, 50], [ca, 52]], -54, -36);
        box("chimneys", "chimHi", ca + 2, cb - 2, 50, 51, -36.5, -35.85);
        slab("chimneys", "chimTop", [[ta, 50], [tb, 50], [tb, 47], [tb - 2, 45], [ta + 2, 45], [ta, 47]], -50, -40);
      }
    }

    // ---- the gable (front at Z 8)
    const ZG = 16;                                            // the gable stands out in front of the wing eaves (Z 12)
    const vU = (x) => 40 + Math.abs(x - 218);                 // the verge's underside, as a row (1:1)          // the verge's underside, as a row
    slab("gable", "plaster", [[142, 264], [294, 264], [294, vU(294)], [218, 40], [142, vU(142)]], -40, ZG);
    for (const [a, b] of [[142, 150], [188, 195], [241, 248], [286, 294]]) {
      const top = Math.min(vU(a), vU(b)) - 2;
      box("gable timber", "timber", a, b, top, 264, ZG - 2, ZG + 1.5);
    }
    for (const [r0, r1] of [[104, 108], [136, 140], [176, 180], [258, 264]]) {
      const half = r0 - 40;
      box("gable timber", "timber", Math.max(142, 218 - half), Math.min(294, 218 + half), r0, r1, ZG - 2, ZG + 1.5);
    }
    for (const [a, b] of [[150, 189], [195, 241], [247, 286]]) {
      bar("gable timber", "timber", a, 109, b, 135, 4, ZG - 2, ZG + 1.2);
      bar("gable timber", "timber", b, 109, a, 135, 4, ZG - 2, ZG + 1.2);
    }
    for (const [a, b] of [[150, 189], [247, 286]]) {
      bar("gable timber", "timber", a, 182, b, 182 + (b - a), 4, ZG - 2, ZG + 1.2);
      bar("gable timber", "timber", b, 182, a, 182 + (b - a), 4, ZG - 2, ZG + 1.2);
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
    // the stone surround: arch voussoirs (wedges with joints between) and jamb blocks
    // the mortar bed behind the surround (the stones sit in it, the joints between them read dark, not as wall)
    slab("door", "mortar2", archPts(192, 244, 207, 264), ZG, ZG + 1.8, [archPts(198, 238, 213, 264).slice().reverse()]);
    { const cx = 218, sp = 233, ri = 20, ro = 25, n = 7;
      for (let i = 0; i < n; i++) {
        const a0 = Math.PI * (i + 0.1) / n, a1 = Math.PI * (i + 0.9) / n, pts = [];
        for (let t = 0; t <= 4; t++) { const a = a0 + (a1 - a0) * t / 4; pts.push([cx + ro * Math.cos(a), sp - ro * Math.sin(a)]); }
        for (let t = 4; t >= 0; t--) { const a = a0 + (a1 - a0) * t / 4; pts.push([cx + ri * Math.cos(a), sp - ri * Math.sin(a)]); }
        slab("door", "stone", pts, ZG, ZG + 2.4);
      }
      for (const [x0, x1] of [[193, 198], [238, 243]]) for (let r = 234; r < 264; r += 10) box("door", "stone", x0, x1, r, Math.min(r + 9, 264), ZG, ZG + 2.4);
    }
    for (const x of [212, 224]) { const g = new THREE.TorusGeometry(1.8, 0.6, 6, 12); const m = add(g, "iron", "door"); m.position.set(x, Y(241, ZG + 1.6), ZG + 1.6); }

    // the sign: board, rim, shield, letters
    slab("sign", "signRim", [[168, 196.5], [174, 186], [260, 186], [266, 196.5], [260, 207], [174, 207]], ZG, ZG + 3);
    slab("sign", "sign", [[171, 196.5], [176, 188], [258, 188], [263, 196.5], [258, 205], [176, 205]], ZG, ZG + 3.6);
    for (const [x, r] of [[179, 190], [255, 190], [179, 202], [255, 202]]) box("sign", "nail", x, x + 1, r, r + 1, ZG + 3.6, ZG + 4.2);
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
    // the steps: three treads, each laid of a few stones like the plinth (owner 2026-11-07: "계단도 다른 돌처럼"):
    // a mortar bed, slabs of different lengths with rounded front corners, a lit nose, a shaded foot, now and then a
    // crack or a pit. Fixed seed.
    { let seed = 23;
      const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
      for (const [x0s, x1s, r0, r1, zf] of [[182, 254, 262, 268, 22], [176, 260, 268, 274, 28], [170, 266, 274, 280, 34]]) {
        box("steps", "mortar2", x0s, x1s, r0, r1, -10, zf - 0.6);
        let x = x0s;
        while (x < x1s - 4) {
          const w = Math.min(x1s - x, 16 + Math.floor(rnd() * 14));
          const xa = x, xb = x + w - 1, c = 1 + Math.floor(rnd() * 2), c2 = 1 + Math.floor(rnd() * 2);
          const pts = [[xa, r1 - 1], [xa + 1, r1], [xb - 1, r1], [xb, r1 - 1], [xb, r0 + c2], [xb - c2, r0], [xa + c, r0], [xa, r0 + c]];
          slab("steps", "plinth", pts, -10, zf);
          box("steps", "plinthHi", xa + c, xb - c2, r0, r0 + 1, zf - 0.5, zf + 0.15);       // the lit nose
          box("steps", "plinthLo", xa + 1, xb - 1, r1 - 1, r1, zf - 0.5, zf + 0.15);        // the shaded foot
          if (rnd() < 0.4 && w > 14) {
            const sx = xa + 4 + rnd() * (w - 9), dx = rnd() < 0.5 ? -1 : 1;
            bar("steps", "crack", sx, r0 + 1, sx + dx * 2, r0 + 3, 1, zf - 0.3, zf + 0.2);
          } else if (rnd() < 0.5 && w > 10) {
            const px = xa + 3 + rnd() * (w - 7);
            box("steps", "crack", px, px + 2, r0 + 3, r0 + 4, zf - 0.3, zf + 0.2);
          }
          x += w;
        }
      }
    }

    // the verges: two thick boards from the apex, an eave board under each, and the short gable roof behind them
    const ZV0 = 14, ZV1 = 22;
    for (const s of [-1, 1]) {
      const xe = 218 + s * 112, re = 28 + 112;
      bar("verge", "verge", 218, 28 + 6, xe, re + 6, 12, ZV0, ZV1);
      bar("verge", "fascia", 218, 28 + 14, xe, re + 14, 4, ZV0 - 1, ZV1 - 0.5);
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
