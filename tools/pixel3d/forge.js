// The smithy built in code, the same way as the guild hall (tools/pixel3d/hall.js; owner 2026-11-07: "이거 기준으로 다른
// 건물들도"): the reference sprite (assets/town/hx/g_forge.png, 574 x 290, at half size = 287 x 145 cells) is only the
// guide; every part is a solid, lit by the town's one sun, front view, palette ramps only.
//
// Coordinates as in hall.js: x = column, rows counted down from the top, Z toward the viewer; a front face at depth z
// on row r has world Y = B0 + K*z - r. B0 = 145, the foot line; the canvas runs 14 rows lower for the ground in front.

const FORGE = (function () {
  const W = 287, H = 169, B0 = 145, K = 0.25, TOP = 10;   // TOP: rows of sky above row 0 (the chimney cap recedes up)
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
                  "door", "roof", "tiles", "lean-to"];

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
      const { w = 14, skip = () => false, gx = 35, gr = 16, ch = 7 } = opts;   // the bond's grid: x origin, first row, course height
      for (let i = 0; i < rows.length - 1; i++) {
        const r0 = rows[i], r1 = rows[i + 1] - 1;
        const [a, b] = span(r0 + (r1 - r0) / 2);
        if (b - a < 3) continue;
        let m0 = null;
        for (let xx = a; xx <= b; xx++) {
          const open = xx === b || skip(xx, xx + 1, r0, r1);
          if (!open && m0 === null) m0 = xx;
          if (open && m0 !== null) { box(layer, "mortar2", m0, xx, r0, r1 + 1, zf - 6, zf - 0.8); m0 = null; }
        }
        const par = Math.floor((r0 - gr) / ch + 0.01) % 2 !== 0;
        let x00 = gx - (par ? Math.floor(w / 2) : 0);
        x00 -= Math.ceil((x00 - a) / w) * w;                                     // the first joint on the grid at or left of a
        for (let x = x00; x < b - 2; x += w) {
          const x0 = Math.max(x, a), x1 = Math.min(x + w - 2, b);
          if (x1 - x0 < 3 || skip(x0, x1, r0, r1)) continue;
          const h = rnd();
          const m = h < 0.05 ? "stoneLt" : h > 0.96 ? "stoneGr" : "stone";       // rarely a stone of another shade
          slab(layer, m, [[x0, r1 - 1], [x0 + 1, r1], [x1 - 1, r1], [x1, r1 - 1], [x1, r0 + 1], [x1 - 1, r0], [x0 + 1, r0], [x0, r0 + 1]], zf - 1.4, zf);
          box(layer, "plinthHi", x0 + 1, x1 - 1, r0, r0 + 1, zf - 0.5, zf + 0.15);      // the lit top edge
          if (rnd() < 0.05 && x1 - x0 > 10) {                                          // rarely a crack
            const sx = x0 + 3 + rnd() * (x1 - x0 - 6);
            bar(layer, "crack", sx, r0 + 1, sx + 2, r0 + 4, 1, zf - 0.3, zf + 0.2);
          }
        }
      }
    }
    const rowsFrom = (r0, r1, h) => { const r = []; for (let y = r0; y < r1; y += h) r.push(y); r.push(r1); return r; };

    // ---- the porch's back wall: planks, deep under the roof (it lives in the roof's shade most of the day)
    box("back wall", "plankDk", 100, 284, 74, 145, -30, -16);
    for (let x = 101; x < 283; x += 7) box("back wall", "plank", x, Math.min(x + 6, 283), 76, 145, -16, -15.2);

    // ---- the furnace: a wide stone body under the chimney, its shoulders stepping in to the stack
    const ZF = 6;
    const fspan = (r) => r < 72 ? [35, 74] : r < 86 ? [35 - (r - 72) * 0.8, 74 + (r - 72) * 1.0] : r < 104 ? [24, 88 + (r - 86) * 0.6] : [19, 100];
    // the fire mouth: an arch in the furnace, the hearth sill under it, the ash pit below
    const mouth = archPts(46, 88, 92, 122);
    slab("furnace", "mortar2", [[19, 145], [19, 104], [24, 104], [24, 86], [35, 72], [74, 72], [88, 86], [99, 104], [100, 145]], -30, ZF - 7,
         [mouth.slice().reverse(), [[57, 145], [57, 131], [83, 131], [83, 145]].reverse()]);
    const inMouth = (x0, x1, r0, r1) => x1 > 44 && x0 < 90 && r1 > 90 && r0 < 123;
    const pit = (x0, x1, r0, r1) => x1 > 56 && x0 < 84 && r1 > 131;
    courses("furnace", rowsFrom(72, 145, 7), fspan, ZF, { w: 14, gx: 35, gr: 16, skip: (a, b, c, d) => inMouth(a, b, c, d) || pit(a, b, c, d) });
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
    slab("furnace", "soot", mouth, -14, -12);
    // (no fire drawn here: owner 2026-11-07, "불 텍스쳐는 뺄거지? 나중에 fx로 충당하고?" - the flames come later as
    // an effect laid in the mouth, centre x 67, floor row 122)
    // the hearth sill: a long stone ledge standing out under the mouth
    box("furnace", "stoneLt", 38, 96, 122, 125, ZF - 2, ZF + 6);
    box("furnace", "plinthLo", 38, 96, 125, 126, ZF - 2, ZF + 5.5);
    // the ash pit: a dark low opening under the sill with a brick lintel
    box("furnace", "soot", 57, 83, 131, 145, -8, -6);
    for (let x = 56; x < 84; x += 7) box("furnace", "brick", x, Math.min(x + 6, 84), 127, 131, ZF - 1.5, ZF);

    // ---- the chimney stack, a little narrower, with a capstone course
    const ZC = 2;
    // the stack and the furnace are one bond (owner 2026-11-07: "굴뚝이랑 화덕은 동렬 형태로" = 돌 줄을 맞춤): the same
    // stone, the same grid, the courses running on from the stack down into the furnace
    slab("chimney", "mortar2", [[35, 72], [74, 72], [74, 16], [35, 16]], -26, ZC - 1);
    courses("chimney", rowsFrom(16, 72, 7), () => [35, 74], ZC, { w: 14, gx: 35, gr: 16 });
    // the top (owner 2026-11-07: "굴뚝 윗부분 형태 다듬고"): a corbel course standing out a little, a capstone wider
    // still with its corners rounded and a lit top edge, and the crown of the flue on it, set back
    slab("chimney", "stone", [[33, 15], [33, 11], [34, 10], [75, 10], [76, 11], [76, 15]], -22, ZC + 1.2);
    box("chimney", "plinthHi", 34, 75, 10, 11, ZC + 0.6, ZC + 1.4);
    box("chimney", "mortar2", 33, 76, 15, 16, -22, ZC + 0.6);
    slab("chimney", "stoneLt", [[31, 10], [31, 7], [33, 5], [76, 5], [78, 7], [78, 10]], -24, ZC + 2.4);
    box("chimney", "plinthHi", 33, 76, 5, 6, ZC + 1.8, ZC + 2.6);
    box("chimney", "mortar2", 31, 78, 9.5, 10, -24, ZC + 2);
    slab("chimney", "stone", [[38, 5], [38, 2], [39, 1], [70, 1], [71, 2], [71, 5]], -18, ZC - 2);    // the flue's crown, set back
    box("chimney", "plinthHi", 39, 70, 1, 2, ZC - 2.6, ZC - 1.8);

    // ---- the porch: roof on posts with knee braces over a low stone wall, the door set in a stone wall at the right
    const ZP = 9;                                                                    // posts close under the eave (Z 12)
    for (const [a, b] of [[115, 122], [194, 202], [265, 273]]) box("porch", "timber", a, b, 79, 128, ZP - 4, ZP);
    box("porch", "timber", 100, 284, 75, 80, ZP - 4, ZP + 0.5);                     // the beam under the eave
    for (const [px0, px1] of [[115, 122], [194, 202], [265, 273]]) {             // knee braces, 1:1
      if (px0 > 110) bar("porch", "timber", px0, 96, px0 - 14, 81, 4, ZP - 3.5, ZP - 0.5);
      if (px1 < 280) bar("porch", "timber", px1, 96, px1 + 14, 81, 4, ZP - 3.5, ZP - 0.5);
    }
    // stone feet under the posts: two or three big blocks each
    courses("stone wall", [115, 125, 135, 145], () => [107, 128], ZP + 3, { w: 11 });
    courses("stone wall", [128, 136, 145], () => [259, 280], ZP + 3, { w: 11 });
    // the low wall between: smaller stones, three courses
    courses("stone wall", [118, 127, 136, 145], () => [128, 194], ZP, { w: 16 });
    courses("stone wall", [128, 136, 145], () => [194, 204], ZP + 2, { w: 11 });

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

    // ---- the roof: one long front slope, eave at row 72 (Z 12), ridge at row 25 (Z -40), hipped at the right end,
    // running behind the chimney at the left; big tiles in four courses as on the hall
    const ZE = 12, ZR = -40, RE = 72, RR = 25;
    const ye = Y(RE, ZE), yr = Y(RR, ZR);
    { const tri = [], quad = (a, b, c, d) => tri.push(...a, ...b, ...c, ...a, ...c, ...d), t3 = (a, b, c) => tri.push(...a, ...b, ...c);
      const e0 = [60, ye, ZE], e1 = [287, ye, ZE], r0 = [60, yr, ZR], r1 = [263.5, yr, ZR], b0 = [60, ye, -80], b1 = [287, ye, -80];
      quad(e0, e1, r1, r0); t3(e1, b1, r1); quad(b1, b0, r0, r1); quad(e0, b0, b1, e1); quad(e0, r0, b0, b0);
      const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(tri, 3)); g.computeVertexNormals();
      add(g, "roofBase", "roof"); }
    box("roof", "fascia", 74, 287, 72, 76, ZE - 6, ZE + 1.5);
    { const xa = 74, xb = 263.5;                                                    // the ridge roll
      shell("tiles", "tile", (u, v) => { const th = Math.PI * u; return [xa + (xb - xa) * v, yr + 2.6 * Math.sin(th), ZR + 3.0 * Math.cos(th)]; },
            [0, 0.17, 0.33, 0.5, 0.67, 0.83, 1], [0, 1], [0, -2, 0]); }
    { const courseRows = [25, 37, 49, 61, 72];
      const slopeN = new THREE.Vector3(0, ZE - ZR, yr - ye).normalize();
      const onSlope = (x, row) => { const u = (RE - row) / (RE - RR); return new THREE.Vector3(x, ye + u * (yr - ye), ZE + u * (ZR - ZE)); };
      const hipX = (row) => 287 - (RE - row) * 0.5;
      for (let c = 0; c < 4; c++) {
        const rt = courseRows[c], rb = courseRows[c + 1] + 1.5, lean = 0.25 * (rb - rt);   // joints nearly upright, as the reference's
        for (let x = 74 + (c % 2 ? -14 : 0); x < 290; x += 29) {
          let xt0 = Math.max(x + 0.8, 74), xt1 = x + 28.2, xb0 = Math.max(x + 0.8 + lean, 74), xb1 = x + 28.2 + lean;
          xt1 = Math.min(xt1, hipX(rt)); xb1 = Math.min(xb1, hipX(rb));
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

    // ---- the lean-to at the left: a short roof down from the chimney over a post and a stone foot
    const ZL = 10;
    box("lean-to", "timber", 12, 17, 80, 113, ZL - 6, ZL - 2);
    courses("lean-to", [113, 124, 135, 145], () => [6, 28], ZL - 2, { w: 11 });
    bar("lean-to", "roofBase", 35, 56, 2, 80, 7, ZL - 8, ZL);
    bar("lean-to", "fascia", 35, 61, 2, 85, 3, ZL - 7, ZL + 0.5);
    for (let i = 0, n = 4; i < n; i++) {                                           // tiles down the short slope
      const t0 = i / n + 0.01, t1 = (i + 1) / n - 0.02;
      const F = (u, v) => { const t = t0 + (t1 - t0) * v, x = 35 + (2 - 35) * t, row = 52 + (78 - 52) * t + 6 * u;
        return [x, Y(row, ZL), ZL + 0.5 + (u < 0.5 ? 2.6 * u / 0.5 : 2.6 - 2.0 * (u - 0.5) / 0.5)]; };
      shell("lean-to", i === 2 ? "tileDk" : "tile", F, [0, 0.25, 0.5, 0.75, 1], [0, 1], [0, 0, -2.5]);
    }

    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
