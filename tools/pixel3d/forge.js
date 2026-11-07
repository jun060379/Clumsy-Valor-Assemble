// The smithy built in code, the same way as the guild hall (tools/pixel3d/hall.js; owner 2026-11-07: "이거 기준으로 다른
// 건물들도"): the reference sprite (assets/town/hx/g_forge.png, 574 x 290, at half size = 287 x 145 cells) is only the
// guide; every part is a solid, lit by the town's one sun, front view, palette ramps only.
//
// Coordinates as in hall.js: x = column, rows counted down from the top, Z toward the viewer; a front face at depth z
// on row r has world Y = B0 + K*z - r. B0 = 145, the foot line; the canvas runs 14 rows lower for the ground in front.

const FORGE = (function () {
  const W = 287, H = 175, B0 = 145, K = 0.25, TOP = 16;   // TOP: rows of sky above row 0 (the chimney cap recedes up)
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    // stone: the furnace and chimney of light dressed stone, a few greyer blocks; mortar deep in the joints
    stone: ["cream", 3], stoneLt: ["cream", 4], stoneGr: ["stone", 6], mortar2: ["wood", 2], crack: ["cream", 1],
    plinthHi: ["cream", 5], plinthLo: ["cream", 1],
    brick: ["cream", 3], soot: ["stone", 2],
    // wood: posts, beams, braces, the planked back wall in the porch's shade, the door
    timber: ["wood", 6], plank: ["wood", 5], plankDk: ["wood", 4], frame: ["wood", 5], door: ["wood", 6], doorGap: ["wood", 2],
    glass: ["cream", 6], mullion: ["wood", 3], sill: ["wood", 4],
    iron: ["iron", 3], ironDk: ["iron", 1],
    roofBase: ["red", 0], tile: ["red", 2], tileDk: ["red", 1], tileLt: ["red", 3], fascia: ["wood", 1],
    // the fire: its own light, never shaded (owner's light sources: 불, 용광로)
    fireDeep: ["red", 1], fireRed: ["red", 3], fireOr: ["ochre", 3], fireHot: ["cream", 6], ember: ["red", 4],
  };
  const LAYERS = ["ground", "back wall", "furnace", "chimney", "fire", "stone wall", "porch", "tools", "window",
                  "door", "roof", "tiles", "work"];

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
    let seed = 11;
    const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };

    // dressed stone laid in courses (owner 2026-11-07: "벽돌이 과하게 들쭉날쭉한듯. 역시나 래퍼런스 찾아서 재구성"; the
    // pixel-art rule, SLYNYRD Pixelblog 45: one brick size per wall, a 1-cell joint, a regular running bond, only now
    // and then a discoloured or cracked one). Every stone in a wall the same width `w` and the course height, each
    // course shifted half a stone; the same small rounding on every corner; a lit top edge. Over a mortar bed that
    // leaves the openings (`skip`) open; `span(row)` gives the wall's [x0, x1] on a row (sloped or curved outlines).
    function courses(layer, rows, span, zf, opts = {}) {
      // `holes(r0, r1)`: the [x0, x1] spans a course leaves open (an arch, a pit); stones are cut at them, not dropped
      const { w = 14, holes = () => [], gx = 35, gr = 16, ch = 7 } = opts;
      const minus = (a, b, H) => { let segs = [[a, b]];
        for (const [h0, h1] of H) segs = segs.flatMap(([s0, s1]) => h1 <= s0 || h0 >= s1 ? [[s0, s1]] : [[s0, Math.min(s1, h0 - 1)], [Math.max(s0, h1 + 1), s1]].filter(([u, v]) => v - u >= 1));
        return segs; };
      for (let i = 0; i < rows.length - 1; i++) {
        const r0 = rows[i], r1 = rows[i + 1] - 1;
        const [a, b] = span(r0 + (r1 - r0) / 2).map(Math.round);
        if (b - a < 3) continue;
        const H = holes(r0, r1);
        for (const [m0, m1] of minus(a, b, H)) box(layer, "mortar2", m0, m1, r0, r1 + 1, zf - 6, zf - 0.8);
        const par = Math.floor((r0 - gr) / ch + 0.01) % 2 !== 0;
        let x00 = gx - (par ? Math.floor(w / 2) : 0);
        x00 -= Math.ceil((x00 - a) / w) * w;
        for (let x = x00; x < b - 2; x += w) {
          for (const [x0, x1] of minus(Math.max(x, a), Math.min(x + w - 2, b), H)) {
            if (x1 - x0 < 4) continue;                                             // no slivers: the mortar shows there
            slab(layer, "stone", [[x0, r1 - 1], [x0 + 1, r1], [x1 - 1, r1], [x1, r1 - 1], [x1, r0 + 1], [x1 - 1, r0], [x0 + 1, r0], [x0, r0 + 1]], zf - 1.4, zf);
            box(layer, "plinthHi", x0 + 1, x1 - 1, r0, r0 + 1, zf - 0.5, zf + 0.15);    // the lit top edge
          }
        }
      }
    }
    // how the two roofs meet (owner 2026-11-07, picked from three drawn ways: "2번" = B, the left roof lower, tucked
    // under the end of the main roof)
    // D (owner 2026-11-07, drawn on the picture): a lean-to - one slope from the main roof's top left corner down to the
    // far left, a post where it meets the main building
    const ROOFV = "D";
    const rowsFrom = (r0, r1, h) => { const r = []; for (let y = r0; y < r1; y += h) r.push(y); r.push(r1); return r; };

    // ---- the porch's back wall: planks, deep under the roof (it lives in the roof's shade most of the day)
    box("back wall", "plankDk", 100, 284, 74, 145, -30, -16);
    for (let x = 101; x < 283; x += 7) box("back wall", "plank", x, Math.min(x + 6, 283), 76, 145, -16, -15.2);

    // ---- the furnace: a wide stone body under the chimney, its shoulders stepping in to the stack
    const ZF = -84;                                                                  // at the back, just behind the roof's back eave (Z -80): the open floor runs to it under the roof
    const fspan = (r) => r < 72 ? [35, 74] : r < 86 ? [35 - (r - 72) * 0.8, 74 + (r - 72) * 1.0] : r < 104 ? [24, 88 + (r - 86) * 0.6] : [19, 100];
    // the fire mouth: an arch in the furnace, the hearth sill under it, the ash pit below
    const mouth = archPts(46, 88, 92, 122);
    slab("furnace", "mortar2", [[19, 145], [19, 104], [24, 104], [24, 86], [35, 72], [74, 72], [88, 86], [99, 104], [100, 145]], ZF - 36, ZF - 7,
         [mouth.slice().reverse(), [[57, 145], [57, 131], [83, 131], [83, 145]].reverse()]);
    const inMouth = (x0, x1, r0, r1) => x1 > 44 && x0 < 90 && r1 > 90 && r0 < 123;
    const pit = (x0, x1, r0, r1) => x1 > 56 && x0 < 84 && r1 > 131;
    // the courses are cut round the voussoir ring (radius 27 about x 67, row 113), the jambs, the sill and the pit
    const fHoles = (r0, r1) => {
      const H = [], rr = Math.min(Math.max(113, r0), r1);
      if (r1 >= 86 && r0 <= 113) { const hw = Math.sqrt(Math.max(0, 27 * 27 - (113 - rr) * (113 - rr))); H.push([67 - hw, 67 + hw]); }
      if (r1 > 113 && r0 < 122) H.push([40, 94]);
      if (r1 >= 122 && r0 < 127) H.push([38, 96]);
      if (r1 >= 127) H.push([56, 84]);
      return H.map(([a, b]) => [Math.floor(a), Math.ceil(b)]); };
    courses("furnace", rowsFrom(72, 145, 7), fspan, ZF, { w: 14, gx: 35, gr: 16, holes: fHoles });
    // the voussoirs round the mouth
    { const cx = 67, sp = 113, ri = 21, ro = 27, n = 7;
      slab("furnace", "mortar2", archPts(40, 94, 86, 122), ZF - 2, ZF + 0.5, [mouth.slice().reverse()]);
      for (let i = 0; i < n; i++) {
        const a0 = Math.PI * (i + 0.08) / n, a1 = Math.PI * (i + 0.92) / n, pts = [];
        for (let t = 0; t <= 4; t++) { const a = a0 + (a1 - a0) * t / 4; pts.push([cx + ro * Math.cos(a), sp - ro * Math.sin(a)]); }
        for (let t = 4; t >= 0; t--) { const a = a0 + (a1 - a0) * t / 4; pts.push([cx + ri * Math.cos(a), sp - ri * Math.sin(a)]); }
        slab("furnace", i === 3 ? "stoneLt" : "stone", pts, ZF - 1.2, ZF + 1.4);
      }
      for (const [x0, x1] of [[40, 46], [88, 94]]) { box("furnace", "stone", x0, x1, 113, 122, ZF - 1.2, ZF + 1.4); }
    }
    // inside the mouth: sooty back, the fire on its bed of embers (its own light)
    slab("furnace", "soot", mouth, ZF - 20, ZF - 18);
    // (no fire drawn here: owner 2026-11-07, "불 텍스쳐는 뺄거지? 나중에 fx로 충당하고?" - the flames come later as
    // an effect laid in the mouth, centre x 67, floor row 122)
    // the hearth sill: a long stone ledge standing out under the mouth
    box("furnace", "stoneLt", 38, 96, 122, 125, ZF - 2, ZF + 6);
    box("furnace", "plinthLo", 38, 96, 125, 126, ZF - 2, ZF + 5.5);
    // the ash pit: a dark low opening under the sill with a brick lintel
    box("furnace", "soot", 57, 83, 131, 145, ZF - 14, ZF - 12);
    for (let x = 56; x < 84; x += 7) box("furnace", "brick", x, Math.min(x + 6, 84), 127, 131, ZF - 1.5, ZF);

    // ---- the chimney stack, a little narrower, with a capstone course
    const ZC = -88;                                                                  // the stack rises behind the roof, past its ridge - it never goes through the roof (owner 2026-11-07: "상식적으로 굴뚝이 지붕을 뚫고 나오겠냐")
    // the stack and the furnace are one bond (owner 2026-11-07: "굴뚝이랑 화덕은 동렬 형태로" = 돌 줄을 맞춤): the same
    // stone, the same grid, the courses running on from the stack down into the furnace
    // the stack is shallow (12 deep): in this view a top recedes up K rows per cell, so a deep stack would show a tall
    // pale top face; the reference shows the top as a thin band
    slab("chimney", "mortar2", [[35, 72], [74, 72], [74, 2], [35, 2]], ZC - 12, ZC - 1);
    courses("chimney", rowsFrom(2, 72, 7), () => [35, 74], ZC, { w: 14, gx: 35, gr: 16 });
    // the top (owner 2026-11-07: "굴뚝 윗부분 형태 다듬고" / "굴뚝형태 해결"): a corbel course standing out a cell,
    // a capstone a cell wider again with rounded corners, and the flue's low crown on it, set back
    slab("chimney", "stone", [[33, 2], [33, -2], [34, -3], [75, -3], [76, -2], [76, 2]], ZC - 13, ZC + 1);
    box("chimney", "plinthHi", 34, 75, -3, -2, ZC + 0.4, ZC + 1.2);
    slab("chimney", "stone", [[31, -3], [31, -5], [33, -7], [76, -7], [78, -5], [78, -3]], ZC - 14, ZC + 2);
    box("chimney", "plinthHi", 33, 76, -7, -6, ZC + 1.4, ZC + 2.2);
    slab("chimney", "stone", [[42, -7], [42, -8], [43, -9], [66, -9], [67, -8], [67, -7]], ZC - 10, ZC - 3);    // the flue's crown

    // ---- the porch: roof on posts with knee braces over a low stone wall, the door set in a stone wall at the right
    const ZP = 9;                                                                    // posts close under the eave (Z 12)
    for (const [a, b] of [[115, 122], [194, 202], [265, 273]]) box("porch", "timber", a, b, 79, 124, ZP - 4, ZP);   // standing on the low wall
    box("porch", "timber", ROOFV === "A" ? 2 : 86, 284, 75, 80, ZP - 4, ZP + 0.5);   // the beam under the eave
    if (ROOFV === "B") box("porch", "timber", 2, 108, 91, 96, ZP - 4, ZP + 0.5);     // the lower roof's own eave beam
    for (const [px0, px1] of [[115, 122], [194, 202], [265, 273]]) {             // knee braces, 1:1
      if (px0 > 110) bar("porch", "timber", px0, 96, px0 - 14, 81, 4, ZP - 3.5, ZP - 0.5);
      if (px1 < 280) bar("porch", "timber", px1, 96, px1 + 14, 81, 4, ZP - 3.5, ZP - 0.5);
    }
    // stone feet under the posts: two or three big blocks each
    // the low wall: one height all along the front, joined from the far left to the door and again past it (owner
    // 2026-11-07: "하단 담장 높이 통합 및 잇고"); the posts stand on it
    // the left workspace stays open (owner 2026-11-07: "좌측은 이으면 안되지"): the wall runs only along the building,
    // from under the run-on of its roof to the door and past it; the left corner post stands on a pier of the same height
    for (const [a, b] of [[88, 207], [252, 281]]) courses("stone wall", [124, 131, 138, 145], () => [a, b], ZP + 1, { w: 16, gx: 0, gr: 124, ch: 7 });
    courses("stone wall", [124, 131, 138, 145], () => [0, 16], ZP + 1, { w: 16, gx: 0, gr: 124, ch: 7 });
    // the low wall between: smaller stones, three courses
    // (the separate low wall and post feet: replaced by the one wall above)

    // ---- on the back wall: hanging tools, a window with a board under it
    box("tools", "ironDk", 129, 151, 88, 89.6, -15, -13.5);                          // the rail
    for (const x of [133, 145]) {                                                   // tongs: two long jaws, a ring at the end
      bar("tools", "iron", x, 89, x - 2, 108, 1.4, -15, -13.6);
      bar("tools", "iron", x + 2, 89, x + 4, 108, 1.4, -15, -13.6);
      const g = new THREE.TorusGeometry(2.2, 0.7, 6, 12); const m = add(g, "iron", "tools"); m.position.set(x + 1, Y(110, -14), -14.2);
    }
    bar("tools", "plank", 140, 89, 140, 103, 1.6, -15, -13.6);                       // a hammer: handle, head
    box("tools", "iron", 137, 144, 103, 106, -15, -13.2);
    { const x0 = 159, x1 = 178, r0 = 84, r1 = 105, z = -15;
      const outer = archPts(x0, x1, r0, r1), inner = archPts(x0 + 3, x1 - 3, r0 + 3, r1 - 2);
      slab("window", "frame", outer, z, z + 1.6, [inner.slice().reverse()]);
      slab("window", "glass", inner, z, z + 0.3);
      box("window", "frame", x0 + 3, x1 - 3, r1 - 2, r1, z, z + 1.6);
      const cx = (x0 + x1) / 2;
      box("window", "mullion", cx - 1, cx + 1, r0 + 3, r1 - 2, z, z + 0.9);
      box("window", "mullion", x0 + 3, x1 - 3, 95, 97, z, z + 0.9);
      box("window", "sill", 154, 184, 106, 111, z, z + 4);                         // the board under it
    }

    // ---- the door wall: stone, an arched plank door in a wooden frame
    // (no stone either side: owner 2026-11-07, "문 좌우 얼룩덜룩 일자형 기둥 빼고" - the door sits in the plank wall)
    const ZD = -12;
    slab("door", "frame", archPts(210, 252, 82, 145), ZD - 1, ZD + 1.5, [archPts(214, 248, 86, 145).slice().reverse()]);
    slab("door", "doorGap", archPts(214, 248, 86, 145), ZD - 3, ZD - 2.6);
    { const rad = 17, cx = 231, spring = 103;
      const top = (xx) => spring - Math.sqrt(Math.max(0, rad * rad - (xx - cx) * (xx - cx)));
      for (let x = 215; x < 247; x += 6) {
        const x1 = Math.min(x + 5, 247), poly = [[x, 145], [x1, 145]];
        for (let s = 0; s <= 4; s++) { const xx = x1 - (x1 - x) * s / 4; poly.push([xx, top(xx) + 1]); }
        slab("door", "door", poly, ZD - 2.6, ZD - 1.6);
      }
    }
    box("door", "ironDk", 216, 244, 116, 118, ZD - 1.6, ZD - 1.0);                   // the strap hinge
    { const g = new THREE.TorusGeometry(1.8, 0.6, 6, 12); const m = add(g, "iron", "door"); m.position.set(241, Y(125, ZD - 1), ZD - 1); }

    // ---- the roofs. tileRoof: a front slope of big tiles in four courses (as the hall's), eave row re at Z ze, ridge
    // row rr at Z zr, hipped at either end (1:2), the body closed behind down to zb; with its eave board and ridge roll
    function tileRoof(x0, x1, re, rr, ze, zr, zb, hipL0, hipR0) {
      const ye = Y(re, ze), yr = Y(rr, zr), run = (re - rr) * 0.5;
      const xl = hipL0 ? x0 + run : x0, xr = hipR0 ? x1 - run : x1;
      { const tri = [], quad = (a, b, c, d) => tri.push(...a, ...b, ...c, ...a, ...c, ...d), t3 = (a, b, c) => tri.push(...a, ...b, ...c);
        const e0 = [x0, ye, ze], e1 = [x1, ye, ze], r0 = [xl, yr, zr], r1 = [xr, yr, zr], b0 = [x0, ye, zb], b1 = [x1, ye, zb];
        quad(e0, e1, r1, r0); t3(e1, b1, r1); quad(b1, b0, r0, r1); quad(e0, b0, b1, e1); t3(e0, r0, b0);
        const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(tri, 3)); g.computeVertexNormals();
        add(g, "roofBase", "roof"); }
      box("roof", "fascia", x0, x1, re, re + 4, ze - 6, ze + 1.5);
      shell("tiles", "tile", (u, v) => { const th = Math.PI * u; return [xl + (xr - xl) * v, yr + 2.6 * Math.sin(th), zr + 3.0 * Math.cos(th)]; },
            [0, 0.17, 0.33, 0.5, 0.67, 0.83, 1], [0, 1], [0, -2, 0]);
      const nC = 4, ch = (re - rr) / nC;
      const slopeN = new THREE.Vector3(0, ze - zr, yr - ye).normalize();
      const onSlope = (x, row) => { const u = (re - row) / (re - rr); return new THREE.Vector3(x, ye + u * (yr - ye), ze + u * (zr - ze)); };
      const hR = (row) => hipR0 ? x1 - (re - row) * 0.5 : x1, hL = (row) => hipL0 ? x0 + (re - row) * 0.5 : x0;
      for (let c = 0; c < nC; c++) {
        const rt = rr + c * ch, rb = rr + (c + 1) * ch + 1.5, lean = 0.25 * (rb - rt);
        for (let x = x0 + (c % 2 ? -14 : 0); x < x1 + 3; x += 29) {
          let xt0 = Math.max(x + 0.8, hL(rt)), xt1 = x + 28.2, xb0 = Math.max(x + 0.8 + lean, hL(rb)), xb1 = x + 28.2 + lean;
          xt1 = Math.min(xt1, hR(rt)); xb1 = Math.min(xb1, hR(rb));
          if (xt1 - xt0 < 4 || xb1 - xb0 < 4) continue;
          const hh = Math.abs(Math.sin((x + 7) * 12.9898 + c * 78.233) * 43758.5453) % 1, dz = hh > 0.85 ? 0.9 : hh < 0.12 ? -0.6 : 0.0;
          const h2 = Math.abs(Math.sin((x + 3) * 4.1414 + c * 17.17) * 24634.6345) % 1;
          const tmat = h2 < 0.1 ? "tileDk" : h2 > 0.94 ? "tileLt" : "tile";
          const lt = 0.6 + dz, lq = 2.6 + dz, lm = 4.4 + dz, lb = 2.8 + dz, fq = 0.16, f = 0.66;
          const prof = (v) => v < fq ? lt + (lq - lt) * v / fq : v < f ? lq + (lm - lq) * (v - fq) / (f - fq) : lm + (lb - lm) * (v - f) / (1 - f);
          const F = (u, v) => {
            const nr = v > 0.78 ? 1 - 0.14 * (v - 0.78) / 0.22 : 1, uu = 0.5 + (u - 0.5) * nr;
            const x = (xt0 + uu * (xt1 - xt0)) * (1 - v) + (xb0 + uu * (xb1 - xb0)) * v, row = rt + (rb - rt) * v;
            const p = onSlope(x, row).addScaledVector(slopeN, prof(v));
            return [p.x, p.y, p.z];
          };
          shell("tiles", tmat, F, [0, 0.15, 0.35, 0.5, 0.65, 0.85, 1], [0, fq, 0.4, f, 0.83, 1], [-slopeN.x * 2, -slopeN.y * 2, -slopeN.z * 2]);
        }
      }
    }
    // how the two roofs meet (owner 2026-11-07, "우측 건물이랑 좌측 건물이랑 지붕을 ... 말로 설명하기도 힘들다"): three ways
    // shown side by side for the owner to pick - A: one roof over both; B: the left one lower, tucked under the main
    // roof's end; C: the left one a front gable, open, its ridge running back into the main roof
    if (ROOFV === "A") tileRoof(2, 287, 72, 25, 12, -40, -80, true, true);
    else {
      tileRoof(ROOFV === "D" ? 86 : 96, 287, 72, 25, 12, -40, -80, ROOFV !== "D", true);   // D: its left end cut square, run on 10 cells over the post (owner)
      if (ROOFV === "B") tileRoof(2, 106, 87, 52, 13, -34, -80, true, false);
      else if (ROOFV === "D") {
        // the lean-to as the owner drew it (2026-11-07: "우측 건물의 좌측 단편을 직각으로 처리하고. 그 상태에서 좌측 지붕이 우측
        // 건물의 지붕을 기준으로 빗선으로 내려오는거야 ... 저걸 지붕위로 왜 쳐보내"): it starts at the main roof's top
        // left corner (x 96, row 25) and comes down in a straight slant to the far left eave (x 2, row 86); the roof
        // is the band under that line and nothing of it shows above - its plane falls away to the back exactly as
        // fast as this view lifts what lies behind, so it stays edge-on and only the tiled band reads
        const ZL = 13, P0 = [86, 25], P1 = [2, 86], BAND = 11;
        const rowAt = (x) => P0[1] + (P1[1] - P0[1]) * (P0[0] - x) / (P0[0] - P1[0]);
        { const tri = [], quad = (a, b, c, d) => tri.push(...a, ...b, ...c, ...a, ...c, ...d);
          const pt = (x, dr, z) => [x, Y(rowAt(x) + dr, z), z];           // a point on the band, at depth z, same screen row
          const zs = [ZL, ZL - 60];
          for (const [dr0, dr1] of [[2, BAND]]) {
            const a0 = pt(P0[0], dr0, zs[0]), a1 = pt(P1[0], dr0, zs[0]), b0 = pt(P0[0], dr0, zs[1]), b1 = pt(P1[0], dr0, zs[1]);
            const c0 = pt(P0[0], dr1, zs[0]), c1 = pt(P1[0], dr1, zs[0]);
            quad(a1, a0, b0, b1); quad(c0, c1, a1, a0);
          }
          const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(tri, 3)); g.computeVertexNormals();
          add(g, "roofBase", "roof"); }
        bar("roof", "fascia", P0[0], P0[1] + BAND + 1, P1[0], P1[1] + BAND + 1, 3, ZL - 5, ZL + 1);   // the board under the band
        // tiles along the slant, as the hall's verge tiles: each one tips up at its top edge and rolls under at its foot
        const n = 8;
        for (let i = 0; i < n; i++) {
          const t0 = i / n + 0.006, t1 = (i + 1) / n - 0.012;
          const hh = Math.abs(Math.sin((i + 3) * 9.137) * 43758.5453) % 1;
          const m = hh < 0.15 ? "tileDk" : hh > 0.9 ? "tileLt" : "tile";
          const pr = (u) => u < 0.55 ? 0.4 + 3.4 * u / 0.55 : 3.8 - 2.6 * (u - 0.55) / 0.45;
          const F = (u, v) => { const t = t0 + (t1 - t0) * v, x = P0[0] + (P1[0] - P0[0]) * t, row = rowAt(x) + 1 + (BAND - 1) * u;
            return [x, Y(row, ZL + 2), ZL + 1 + pr(u) + 0.7 * v]; };
          shell("tiles", m, F, [0, 0.2, 0.4, 0.55, 0.75, 1], [0, 0.5, 1], [0, 0, -2.5]);
        }
      } else {
        // an open front gable: apex x 51 row 34, the verges down to rows 86 at x 0 and 102; tiles laid down each verge,
        // the roof plane running back into the main roof; a tie beam and a king post in the open end
        const AX = 51, AR = 34, ZG = 14, half = 51, re = AR + half * 1.0;
        for (const sgn of [-1, 1]) {
          const xe = AX + sgn * half;
          bar("roof", "fascia", AX, AR + 9, xe, re + 9, 4, ZG - 6, ZG + 1);
          for (let i = 0, n = 5; i < n; i++) {
            const t0 = i / n + 0.006, t1 = (i + 1) / n - 0.012;
            const hh = Math.abs(Math.sin((i + 3) * 9.137 + sgn * 3.3) * 43758.5453) % 1;
            const m = hh < 0.15 ? "tileDk" : hh > 0.9 ? "tileLt" : "tile";
            const pr = (u) => u < 0.55 ? 0.4 + 3.4 * u / 0.55 : 3.8 - 2.6 * (u - 0.55) / 0.45;
            const F = (u, v) => { const t = t0 + (t1 - t0) * v, x = AX + (xe - AX) * t, row = AR + (re - AR) * t + 1 + 10 * u;
              return [x, Y(row, ZG + 2), ZG + 1 + pr(u) + 0.7 * v]; };
            shell("tiles", m, F, [0, 0.2, 0.4, 0.55, 0.75, 1], [0, 0.5, 1], [0, 0, -2.5]);
          }
          const ya = Y(AR, ZG + 2), yb = Y(re, ZG + 2);
          shell("roof", "tile", (u, v) => [AX + (xe - AX) * v, ya + (yb - ya) * v - 1, ZG - 2 + (-60 - ZG + 2) * u], [0, 1], [0, 0.5, 1], [0, -3, 0]);
        }
        box("roof", "timber", 2, 100, 84, 89, ZG - 6, ZG - 2);                        // the tie beam
        box("roof", "timber", AX - 3, AX + 3, AR + 12, 84, ZG - 6, ZG - 2);            // the king post
        bar("roof", "timber", AX, 50, AX - 26, 84, 3, ZG - 6, ZG - 2.5);              // struts
        bar("roof", "timber", AX, 50, AX + 26, 84, 3, ZG - 6, ZG - 2.5);
      }
    }

    // ---- the open space (owner 2026-11-07: "기존 상태에서 벽 짓지 말고 기존 건물이랑 좌측 벽이랑 지붕으로만 잇고 저 뒷
    // 공간에 화로를 박고 그렇게 지붕을 이어서 생긴 공간을 작업 공간으로"): no walls - the main roof runs on to the left
    // end on the eave beam and a corner post; the hearth and its stack stand at the back of it; the floor in front is
    // the working space: an anvil on its block, a quench tub, coal by the hearth, a rack of tools
    const LT = ROOFV === "B" ? 95 : ROOFV === "D" ? 89 : 79;                                             // the left post up to its eave beam
    box("porch", "timber", 4, 11, LT, 124, ZP - 4, ZP);
    bar("porch", "timber", 11, LT + 17, 25, LT + 2, 4, ZP - 3.5, ZP - 0.5);
    if (ROOFV === "D") {
      box("porch", "timber", 92, 99, 74, 124, ZP - 4, ZP);   // under the main roof's run-on now                           // the post under the lean-to's upper end
      box("porch", "timber", 99, 115, 114, 118, ZP - 3.5, ZP - 0.5);                 // a rail across to the building's post
    }
    // the mouth stays clear (x 46..88): the anvil on its block to its left, the quench tub to its right
    box("work", "timber", 22, 46, 132, 145, 2, 10);                                    // the anvil's block
    box("work", "iron", 27, 41, 129, 132, 3, 9);                                       // the anvil: waist, face, horn
    box("work", "iron", 29, 39, 126, 129, 4, 8);
    box("work", "iron", 22, 46, 122, 126, 2.5, 9.5);
    { const g = new THREE.ConeGeometry(2, 8, 10); const m = add(g, "iron", "work"); m.rotation.z = -Math.PI / 2; m.position.set(50, Y(124, 6), 6); }
    bar("work", "plank", 18, 145, 22, 126, 1.6, 4, 6);                                 // a hammer leaning on the block
    box("work", "iron", 19, 26, 123, 127, 3, 7);
    if (ROOFV !== "D") { const g = new THREE.CylinderGeometry(6.5, 6, 12, 16); const m = add(g, "plank", "work"); m.position.set(97, Y(139, 4), 4);   // the quench tub
      for (const r of [135, 143]) { const gg = new THREE.CylinderGeometry(6.8, 6.8, 1.4, 16); const mm = add(gg, "ironDk", "work"); mm.position.set(97, Y(r, 4), 4); } }

    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
