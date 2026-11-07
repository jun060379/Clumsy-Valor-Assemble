// The smithy, second try (owner 2026-11-07: "아무리해도 별론데 다른 래퍼런스를 기반으로 팔레트스왑해서 만들어볼래?" -
// the owner's pick: the Cainos "Village House" smithy, a paid pack, used only as a reference for form, never stored).
// Built in code like the hall: an open forge bay under a low slate roof (a stone hearth, its chimney up through the
// roof, a table, a bucket, an anvil, a hanging lantern, a sign on an arm), and a taller plastered shop at the right
// with a slatted awning over its window. Colours are the reference's own families swapped onto the town palette:
// slate and stone -> the cream ramp's greyer low steps, plaster -> its light end, wood -> the wood ramp.
// Coordinates as hall.js / forge.js (x column, rows down from the top, Z toward the viewer, B0 = foot line).

const FORGE2 = (function () {
  const W = 295, H = 169, B0 = 145, K = 0.25, TOP = 10;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    slate: ["cream", 1], slateDk: ["cream", 0], slateLt: ["cream", 2], roofBase: ["cream", 0], ridge: ["cream", 2],
    stone: ["cream", 3], plinthHi: ["cream", 5], mortar2: ["wood", 2], soot: ["stone", 2],
    plaster: ["cream", 6], timber: ["wood", 5], plank: ["wood", 4], plankDk: ["wood", 2],
    frame: ["wood", 4], slat: ["wood", 6], shopDk: ["wood", 1],
    iron: ["iron", 3], ironDk: ["iron", 1], pot: ["iron", 2],
    sign: ["wood", 5], signMark: ["cream", 7],
    fireLamp: ["ochre", 6],
  };
  const LAYERS = ["ground", "back", "chimney", "hearth", "bay", "props", "shop", "roof", "tiles", "sign"];

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
    const rowsFrom = (r0, r1, h) => { const r = []; for (let y = r0; y < r1; y += h) r.push(y); r.push(r1); return r; };

    // ---- slate roofs: a roof body and courses of slates with rounded lower corners, each a curved shell (the hall's
    // tile, smaller: the reference's slates), joints upright, every course shifted half a slate
    function slateRoof(layer, x0, x1, re, rr, ze, zr, w, nC) {
      const ye = Y(re, ze), yr = Y(rr, zr);
      const q = [[x0, ye, ze], [x1, ye, ze], [x1, yr, zr], [x0, yr, zr], [x0, ye, zr - 20], [x1, ye, zr - 20]];
      const tri = [], quad = (a, b, c, d) => tri.push(...a, ...b, ...c, ...a, ...c, ...d);
      quad(q[0], q[1], q[2], q[3]); quad(q[1], q[5], q[2], q[2]); quad(q[4], q[0], q[3], q[3]); quad(q[5], q[4], q[3], q[2]); quad(q[0], q[4], q[5], q[1]);
      const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(tri, 3)); g.computeVertexNormals();
      add(g, "roofBase", "roof");
      const slopeN = new THREE.Vector3(0, ze - zr, yr - ye).normalize();
      const on = (x, row) => { const u = (re - row) / (re - rr); return new THREE.Vector3(x, ye + u * (yr - ye), ze + u * (zr - ze)); };
      const ch = (re - rr) / nC;
      for (let c = 0; c < nC; c++) {
        const rt = rr + c * ch, rb = rr + (c + 1) * ch + 1.5;
        for (let x = x0 - (c % 2 ? w / 2 : 0); x < x1; x += w) {
          const a = Math.max(x + 0.5, x0), b = Math.min(x + w - 0.5, x1);     // a one-cell joint: every slate outlined, as the reference
          if (b - a < 4) continue;
          const hh = Math.abs(Math.sin((x + 7) * 12.9898 + c * 78.233 + x0) * 43758.5453) % 1;
          const m = hh < 0.08 ? "slateDk" : hh > 0.95 ? "slateLt" : "slate";
          const prof = (v) => v < 0.85 ? 0.4 + 3.2 * v / 0.85 : 3.6 - 0.6 * (v - 0.85) / 0.15;   // a wedge, thick at its butt: the butt stands well proud of the course below (a clean outline)
          const F = (u, v) => {
            const nr = v > 0.8 ? 1 - 0.12 * Math.pow((v - 0.8) / 0.2, 2) : 1, uu = 0.5 + (u - 0.5) * nr;   // rounded lower corners
            const p = on(a + uu * (b - a), rt + (rb - rt) * v).addScaledVector(slopeN, prof(v));
            return [p.x, p.y, p.z];
          };
          shell("tiles", m, F, [0, 0.12, 0.3, 0.5, 0.7, 0.88, 1], [0, 0.3, 0.6, 0.85, 0.93, 1], [-slopeN.x * 2, -slopeN.y * 2, -slopeN.z * 2]);
        }
      }
    }

    // ---- the open bay: a dark planked back, posts with knee braces under the low roof
    box("back", "plankDk", 50, 182, 100, 145, -40, -30);
    for (let x = 51; x < 181; x += 7) box("back", "plank", x, Math.min(x + 6, 181), 102, 145, -30, -29.2);
    const ZP = 10;
    box("bay", "timber", 58, 64, 100, 145, ZP - 4, ZP);
    box("bay", "timber", 50, 182, 99, 103, ZP - 4, ZP + 0.5);                          // the eave beam
    bar("bay", "timber", 64, 116, 78, 103, 3, ZP - 3.5, ZP - 0.5);                      // knee braces
    bar("bay", "timber", 181, 118, 166, 103, 3, ZP - 3.5, ZP - 0.5);

    // ---- the chimney: dressed stone up through the low roof, a little hood on two legs at the top
    const ZC = -4;
    slab("chimney", "mortar2", [[81, 104], [100, 104], [100, 11], [81, 11]], ZC - 10, ZC - 1);
    courses("chimney", rowsFrom(11, 104, 6), () => [81, 100], ZC, { w: 12, gx: 81, gr: 11, ch: 6 });
    box("chimney", "stone", 79, 102, 8, 11, ZC - 11, ZC + 1.2);                          // the top course, a cell proud
    box("chimney", "plinthHi", 80, 101, 8, 9, ZC + 0.6, ZC + 1.4);
    for (const x of [82, 96]) box("chimney", "timber", x, x + 3, 3, 8, ZC - 6, ZC - 3);   // the legs
    box("chimney", "timber", 80, 101, 0, 3, ZC - 8, ZC - 1);                            // the little hood board

    // ---- the hearth: a stone block with a sloped right shoulder and an arched fire mouth (the fire comes later as an
    // effect, centre x 103, floor row 136)
    const ZH = 6;
    const hspan = (r) => r < 117 ? [77, 118 + (r - 101) * 0.4] : [77, 124];
    const mouth = archPts(90, 116, 117, 137);
    slab("hearth", "mortar2", [[77, 145], [77, 101], [118, 101], [124, 117], [124, 145]], -8, ZH - 6, [mouth.slice().reverse()]);
    const hHoles = (r0, r1) => { const H = [];
      if (r1 >= 113 && r0 < 137) { const rr = Math.min(Math.max(130, r0), r1), hw = r1 < 130 ? Math.sqrt(Math.max(0, 16 * 16 - (130 - rr) * (130 - rr))) : 16; H.push([103 - hw, 103 + hw]); }
      if (r1 >= 136 && r0 < 141) H.push([86, 120]);
      return H.map(([a, b]) => [Math.floor(a), Math.ceil(b)]); };
    courses("hearth", rowsFrom(101, 145, 7), hspan, ZH, { w: 12, gx: 77, gr: 101, ch: 7, holes: hHoles });
    { const cx = 103, sp = 130, ri = 13, ro = 17, n = 7;                               // the voussoirs
      for (let i = 0; i < n; i++) {
        const a0 = Math.PI * (i + 0.1) / n, a1 = Math.PI * (i + 0.9) / n, pts = [];
        for (let t = 0; t <= 3; t++) { const a = a0 + (a1 - a0) * t / 3; pts.push([cx + ro * Math.cos(a), sp - ro * Math.sin(a)]); }
        for (let t = 3; t >= 0; t--) { const a = a0 + (a1 - a0) * t / 3; pts.push([cx + ri * Math.cos(a), sp - ri * Math.sin(a)]); }
        slab("hearth", "stone", pts, ZH - 1.2, ZH + 1.2);
      }
      for (const [a, b] of [[86, 90], [116, 120]]) box("hearth", "stone", a, b, 130, 137, ZH - 1.2, ZH + 1.2);
    }
    slab("hearth", "soot", mouth, -6, -4);
    box("hearth", "stone", 86, 120, 137, 141, ZH - 2, ZH + 4);                           // the sill
    box("hearth", "plinthHi", 87, 119, 137, 138, ZH + 3.4, ZH + 4.2);

    // ---- props in the bay: a table with a pot and a cup, a bucket, a lantern from the beam, an anvil on its block
    box("props", "plank", 26, 72, 128, 131, 8, 16);                                    // table top
    for (const x of [30, 66]) box("props", "timber", x, x + 3, 131, 145, 10, 13);
    { const g = new THREE.CylinderGeometry(5, 5.5, 7, 12); const m = add(g, "pot", "props"); m.position.set(39, Y(124.5, 12), 12); }
    box("props", "ironDk", 33, 45, 120, 121.5, 9, 15);                                  // the pot's rim
    { const g = new THREE.CylinderGeometry(2.6, 2.6, 6, 10); const m = add(g, "plank", "props"); m.position.set(54, Y(125, 12), 12); }
    { const g = new THREE.CylinderGeometry(7, 6.5, 18, 14); const m = add(g, "plank", "props"); m.position.set(128, Y(136, 14), 14); }   // bucket
    for (const r of [130, 141]) { const g = new THREE.CylinderGeometry(7.2, 7.2, 1.4, 14); const m = add(g, "ironDk", "props"); m.position.set(128, Y(r, 14), 14); }
    bar("props", "timber", 121, 125, 135, 125, 1.6, 13, 15);                            // its handle
    box("props", "ironDk", 143, 144, 103, 110, 4, 5);                                    // lantern: hanger, cap, glass, base
    box("props", "iron", 140, 147, 110, 112, 2, 7);
    box("props", "fireLamp", 141, 146, 112, 119, 3, 6);
    box("props", "iron", 140, 147, 119, 121, 2, 7);
    box("props", "timber", 152, 172, 136, 145, 10, 18);                                  // the anvil's block
    { // the anvil: a waist, a face, a horn to the left
      box("props", "iron", 156, 168, 133, 136, 11, 17);
      box("props", "iron", 158, 166, 130, 133, 12, 16);
      box("props", "iron", 152, 172, 126, 130, 10.5, 17.5);
      const g = new THREE.ConeGeometry(2, 8, 10); const m = add(g, "iron", "props"); m.rotation.z = Math.PI / 2; m.position.set(148, Y(128, 14), 14);
    }
    bar("props", "timber", 172, 145, 176, 124, 1.6, 16, 18);                            // a hammer leaning on it
    box("props", "iron", 173, 180, 121, 125, 15, 19);

    // ---- the shop: plastered walls in a timber frame, a stone foot, a window with a slatted awning and a counter
    const ZS = 6;
    slab("shop", "plaster", [[186, 145], [254, 145], [254, 84], [186, 84]], -30, ZS, [[[203, 109], [233, 109], [233, 128], [203, 128]].reverse()]);   // with the window opening
    for (const [a, b] of [[181, 188], [252, 259]]) box("shop", "timber", a, b, 82, 145, ZS - 2, ZS + 2);
    box("shop", "timber", 181, 259, 82, 87, ZS - 2, ZS + 2);
    courses("shop", [138, 145], () => [188, 252], ZS + 1, { w: 13, gx: 188, gr: 138, ch: 7 });
    box("shop", "shopDk", 202, 234, 108, 129, ZS - 6, ZS - 5);                           // the window: dark inside, a frame
    for (const [a, b] of [[199, 203], [233, 237]]) box("shop", "frame", a, b, 106, 130, ZS - 1, ZS + 1.6);
    box("shop", "frame", 199, 237, 106, 109, ZS - 1, ZS + 1.6);
    box("shop", "slat", 199, 237, 128, 132, ZS - 1, ZS + 7);                              // the counter board
    box("shop", "frame", 201, 235, 132, 134, ZS - 1, ZS + 4);
    { // the awning: slats leaning out from the wall over the window
      for (let x = 196; x < 240; x += 7) {
        const F = (u, v) => [x + 0.5 + u * 5.6, Y(93 + v * 15, ZS) - v * 2, ZS + 1 + v * 10 + 1.2 * Math.sin(Math.PI * u)];
        shell("shop", "slat", F, [0, 0.25, 0.5, 0.75, 1], [0, 1], [0, 0, -1.6]);
      }
      box("shop", "timber", 195, 241, 91, 94, ZS - 1, ZS + 2);
    }
    // the little bracket roof on the right end
    bar("shop", "timber", 259, 104, 274, 90, 3, ZS - 3, ZS);
    bar("shop", "slat", 256, 86, 290, 99, 3, ZS - 6, ZS + 1);

    // ---- the roofs: the low one over the bay, the shop's higher one
    slateRoof("roof", 50, 186, 102, 47, 16, -30, 17, 6);
    slateRoof("roof", 166, 270, 85, 30, 20, -34, 17, 6);
    box("roof", "ridge", 168, 268, 24, 30, -38, -30);                                   // the shop's ridge board

    // ---- the sign on its arm, from the low roof's end
    box("sign", "timber", 2, 58, 50, 55, -14, -10);
    bar("sign", "timber", 36, 55, 52, 72, 3, -14, -11);
    for (const x of [9, 22]) box("sign", "ironDk", x, x + 1, 55, 65, -13, -12);
    slab("sign", "sign", [[6, 65], [26, 65], [26, 84], [16, 89], [6, 84]], -14, -11);
    // the mark: an anvil and a hammer, in the light end of the cream ramp
    box("sign", "signMark", 10, 22, 76, 78, -11, -10.4);
    box("sign", "signMark", 13, 19, 78, 81, -11, -10.4);
    box("sign", "signMark", 11, 21, 81, 83, -11, -10.4);
    bar("sign", "signMark", 13, 75, 19, 69, 1.4, -11, -10.4);
    box("sign", "signMark", 17, 22, 67, 71, -11, -10.4);

    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
