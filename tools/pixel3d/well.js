// The well built in code, the same way as the other buildings (owner 2026-11-07: next -> 우물). The reference sprite
// (assets/town/hx/g_well.png, 236 x 212, at half size = 118 x 106 cells) is only the guide. A square stone curb in
// three courses with capstones round the top and dark water inside, two posts standing in it with knee braces, a
// windlass across between them with the rope and an iron-banded bucket, under a small tiled roof hipped at both ends.
// Coordinates as hall.js (x column, rows down from the top, Z toward the viewer, B0 = the foot line).

const WELL = (function () {
  const W = 118, H = 122, B0 = 106, K = 0.12, TOP = 8;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    stone: ["cream", 2], plinthHi: ["cream", 4], mortar2: ["stone", 5], water: ["blue", 0],
    post: ["wood", 5], windlass: ["wood", 4], rope: ["ochre", 3], bucket: ["wood", 5], iron: ["iron", 3],
    roofBase: ["red", 0], tile: ["red", 2], tileDk: ["red", 1], tileLt: ["red", 3], fascia: ["wood", 1],
  };
  const LAYERS = ["ground", "walls", "timber", "roof", "tiles"];

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
    // ---- the roofs. tileRoof: a front slope of big tiles in four courses (as the hall's), eave row re at Z ze, ridge
    // row rr at Z zr, hipped at either end (1:2), the body closed behind down to zb; with its eave board and ridge roll
    function tileRoof(x0, x1, re, rr, ze, zr, zb, hipL0, hipR0, kL = 0.5, kR = 0.5) {   // kL: the left hip's run in cells per row
      const ye = Y(re, ze), yr = Y(rr, zr), run = (re - rr) * 0.5;
      const xl = hipL0 ? x0 + (re - rr) * kL : x0, xr = hipR0 ? x1 - (re - rr) * kR : x1;
      { const tri = [], quad = (a, b, c, d) => tri.push(...a, ...b, ...c, ...a, ...c, ...d), t3 = (a, b, c) => tri.push(...a, ...b, ...c);
        const e0 = [x0, ye, ze], e1 = [x1, ye, ze], r0 = [xl, yr, zr], r1 = [xr, yr, zr], b0 = [x0, ye, zb], b1 = [x1, ye, zb];
        quad(e0, e1, r1, r0); t3(e1, b1, r1); quad(b1, b0, r0, r1); quad(e0, b0, b1, e1); t3(e0, r0, b0);
        const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(tri, 3)); g.computeVertexNormals();
        add(g, "roofBase", "roof"); }
      box("roof", "fascia", x0, x1, re, re + 4, ze - 6, ze + 1.5);
      if (xr - xl > 2) shell("tiles", "tile", (u, v) => { const th = Math.PI * u; return [xl + (xr - xl) * v, yr + 2.6 * Math.sin(th), zr + 3.0 * Math.cos(th)]; },
            [0, 0.17, 0.33, 0.5, 0.67, 0.83, 1], [0, 1], [0, -2, 0]);
      const nC = 4, ch = (re - rr) / nC;
      const slopeN = new THREE.Vector3(0, ze - zr, yr - ye).normalize();
      const onSlope = (x, row) => { const u = (re - row) / (re - rr); return new THREE.Vector3(x, ye + u * (yr - ye), ze + u * (zr - ze)); };
      const hR = (row) => hipR0 ? x1 - (re - row) * kR : x1, hL = (row) => hipL0 ? x0 + (re - row) * kL : x0;
      for (let c = 0; c < nC; c++) {
        const rt = rr + c * ch, rb = rr + (c + 1) * ch + 1.5, lean = 0.25 * (rb - rt);
        for (let x = x0 + (c % 2 ? -14 : 0); x < x1 + 3; x += 29) {
          const tuck = 0;   // under a long hip the tiles run a little in under its raised face: no dark wedge
          let xt0 = Math.max(x + 0.8, hL(rt) - tuck), xt1 = x + 28.2, xb0 = Math.max(x + 0.8 + lean, hL(rb) - tuck), xb1 = x + 28.2 + lean;
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
    const rowsFrom = (r0, r1, h) => { const r = []; for (let y = r0; y < r1; y += h) r.push(y); r.push(r1); return r; };
    const ZB = -40, ZP = -20;                                       // the well's back face; the posts' plane (its middle)

    // ---- the well: a square stone curb, its front in three courses of dressed stone, the sides and back plain, a rim
    // of capstones round the top, dark water below it
    box("walls", "mortar2", 16, 101, 74, 106, ZB, -5);
    courses("walls", [74, 85, 95, 106], (r) => r > 95 ? [15, 102] : [16, 101], 0, { w: 24, gx: 16, gr: 74, ch: 10.5 });
    box("walls", "stone", 16, 101, 72, 75, ZB, -0.4);               // capstones: front, back and both sides,
    box("walls", "water", 22, 95, 73, 74, ZB + 6, -6);              // the water down inside them
    for (let x = 16; x < 101; x += 24) box("walls", "plinthHi", x + 1, Math.min(x + 22, 100), 72, 73, -6, 0.2);

    // ---- the frame: two posts standing in the curb, knee braces up under the roof, the windlass across between them
    for (const [a, b] of [[20, 28], [89, 97]]) box("timber", "post", a, b, 26, 74, ZP - 3, ZP + 3);
    bar("timber", "post", 28, 48, 40, 31, 4, ZP - 1.5, ZP + 1.5);   // inner braces
    bar("timber", "post", 89, 48, 77, 31, 4, ZP - 1.5, ZP + 1.5);
    bar("timber", "post", 20, 48, 8, 31, 4, ZP - 1.5, ZP + 1.5);    // outer braces
    bar("timber", "post", 97, 48, 109, 31, 4, ZP - 1.5, ZP + 1.5);
    { const g = new THREE.CylinderGeometry(3.4, 3.4, 64, 12); const m = add(g, "windlass", "timber");
      m.rotation.z = Math.PI / 2; m.position.set(58.5, Y(43, ZP), ZP); }
    { const g = new THREE.CylinderGeometry(4.2, 4.2, 5, 12); const m = add(g, "post", "timber");       // the drum's collar
      m.rotation.z = Math.PI / 2; m.position.set(60, Y(43, ZP), ZP); }

    // ---- the rope and the bucket hanging from the windlass
    { const a = new THREE.Vector3(60, Y(46, ZP), ZP + 1), b = new THREE.Vector3(60, Y(54, ZP), ZP + 1);
      const g = new THREE.CylinderGeometry(0.8, 0.8, a.distanceTo(b), 8); const m = add(g, "rope", "timber"); m.position.copy(a.clone().add(b).multiplyScalar(0.5)); }
    { const g = new THREE.TorusGeometry(9, 0.8, 6, 16, Math.PI); const m = add(g, "iron", "timber"); m.position.set(60, Y(62, ZP), ZP); }   // the bail
    { const g = new THREE.CylinderGeometry(10, 8.5, 16, 14); const m = add(g, "bucket", "timber"); m.position.set(60, Y(64, ZP), ZP); }
    for (const r of [57.5, 69.5]) { const g = new THREE.CylinderGeometry(r < 60 ? 10.3 : 8.8, r < 60 ? 10.3 : 8.8, 1.6, 14);
      const m = add(g, "iron", "timber"); m.position.set(60, Y(r, ZP), ZP); }

    // ---- the roof: one tiled front slope over the whole, hipped at both ends, overhanging the curb front and back
    tileRoof(2, 116, 30, 2, 8, ZP, ZB - 8, true, true, 16 / 28, 16 / 28);

    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
