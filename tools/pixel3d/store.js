// The store built in code, the same way as the other buildings (owner 2026-11-07: next -> 상점). The reference sprite
// (assets/town/hx/g_store.png, 432 x 268, at half size = 216 x 134 cells) is only the guide. A timber shop clad in
// horizontal boards: a small front gable over the door (its own boards, a king post and two braces), corner posts with
// knee braces under a tiled roof hipped at both ends, a plank door with a ring handle, a sill along the foot.
// Coordinates as hall.js (x column, rows down from the top, Z toward the viewer, B0 = the foot line).

const STORE = (function () {
  const W = 216, H = 158, B0 = 134, K = 0.12, TOP = 10;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    board: ["wood", 6], boardDk: ["wood", 2], gableBoard: ["wood", 7],
    timber: ["wood", 4], frame: ["wood", 4], sill: ["wood", 3], door: ["wood", 5], doorGap: ["wood", 1],
    iron: ["iron", 3], ironDk: ["iron", 1],
    roofBase: ["red", 0], tile: ["red", 2], tileDk: ["red", 1], tileLt: ["red", 3], fascia: ["wood", 1],
    stone: ["cream", 3], plinthHi: ["cream", 5], mortar2: ["wood", 2],
  };
  const LAYERS = ["ground", "walls", "timber", "door", "roof", "tiles", "verge"];

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
    // ---- the walls: horizontal boards over a dark backing, each board a little proud with a dark gap under it
    const ZW = 0;
    box("walls", "boardDk", 22, 196, 52, 124, -50, ZW - 0.6);
    for (let r = 56, k = 0; r < 122; r += 6, k++) box("walls", "board", 22, 196, r, r + 5, ZW - 0.8, ZW + (k % 2 ? 0.3 : 0.6));
    for (const [a, b] of [[18, 28], [188, 198], [64, 72], [144, 152]]) box("timber", "timber", a, b, 52, 124, ZW - 1, ZW + 3);
    box("timber", "sill", 14, 202, 122, 128, ZW - 1, ZW + 3.5);                       // the sill along the foot
    for (const [a, b] of [[14, 32], [184, 202], [60, 76], [140, 156]]) box("timber", "sill", a, b, 126, 134, ZW - 1, ZW + 4.5);   // post feet
    bar("timber", "timber", 28, 76, 50, 58, 4, ZW - 0.5, ZW + 2.5);                   // knee braces from the corner posts
    bar("timber", "timber", 188, 76, 166, 58, 4, ZW - 0.5, ZW + 2.5);

    // ---- the roof: one front slope hipped at both ends
    tileRoof(2, 214, 54, 4, 4, -40, -80, true, true, 25 / 50, 25 / 50);   // a short overhang: the boards stand in the light

    // ---- the gable over the door: its own boards, a king post and two braces, the beam, then the door in its frame
    const ZG = 10, AX = 108, AR = 6;
    const vU = (x) => AR + 8 + Math.abs(x - AX) * 1.0;
    slab("walls", "gableBoard", [[72, 60], [144, 60], [144, vU(144)], [AX, AR + 8], [72, vU(72)]], -40, ZG);
    for (let x = 74; x < 142; x += 7) box("walls", "boardDk", x, x + 1, vU(x + 0.5) , 60, ZG, ZG + 0.3);   // the board joints
    box("timber", "timber", 105, 111, AR + 12, 54, ZG, ZG + 2.5);                      // the king post
    bar("timber", "timber", 106, 32, 84, 52, 4, ZG, ZG + 2);                           // braces
    bar("timber", "timber", 110, 32, 132, 52, 4, ZG, ZG + 2);
    box("timber", "timber", 70, 146, 52, 60, ZG - 1, ZG + 2.5);                         // the beam over the door
    for (const [a, b] of [[72, 80], [136, 144]]) box("timber", "frame", a, b, 60, 124, ZG - 1, ZG + 2);   // the door's frame posts
    box("door", "doorGap", 80, 136, 60, 124, ZG - 2, ZG - 1.6);
    box("door", "frame", 80, 136, 60, 66, ZG - 1, ZG + 1.6);                          // the head
    for (let x = 81, i = 0; x < 135; x += 6, i++) box("door", "door", x, Math.min(x + 5, 135), 66, 124, ZG - 1.6, ZG - (i % 2 ? 0.8 : 0.6));
    box("door", "frame", 81, 135, 70, 75, ZG - 0.6, ZG + 0.6);                          // the ledges across the door
    box("door", "frame", 81, 135, 92, 96, ZG - 0.6, ZG + 0.6);
    box("door", "frame", 81, 135, 114, 119, ZG - 0.6, ZG + 0.6);
    { const g = new THREE.TorusGeometry(3, 0.8, 6, 12); const m = add(g, "iron", "door"); m.position.set(121, Y(103, ZG + 1), ZG + 1); }
    box("door", "ironDk", 116, 122, 101, 103, ZG + 0.6, ZG + 1.2);
    box("timber", "sill", 70, 146, 124, 128, ZG - 2, ZG + 3);                           // the threshold

    // ---- the gable's verges: a board and a band of big tiles down each slope, the gable roof back into the main roof
    const ZV0 = ZG + 1, ZV1 = ZG + 6;
    for (const s of [-1, 1]) {
      const xe = AX + s * 56, re = AR + 56 * 1.0;
      bar("verge", "roofBase", AX, AR + 5, xe, re + 5, 10, ZV0, ZV1 - 1);
      bar("verge", "fascia", AX, AR + 12, xe, re + 12, 4, ZV0 - 1, ZV1 - 0.5);
      for (let i = 0, n = 6; i < n; i++) {
        const t0 = i / n + 0.004, t1 = (i + 1) / n - 0.012;
        const hh = Math.abs(Math.sin((i + 3) * 9.137 + s * 3.3) * 43758.5453) % 1;
        const m = hh < 0.15 ? "tileDk" : hh > 0.92 ? "tileLt" : "tile";
        const pr = (u) => u < 0.55 ? 0.4 + 3.6 * u / 0.55 : 4.0 - 2.8 * (u - 0.55) / 0.45;
        const F = (u, v) => { const t = t0 + (t1 - t0) * v, x = AX + (xe - AX) * t, row = AR + (re - AR) * t + 1 + 11 * u;
          return [x, Y(row, ZV1), ZV1 - 1 + pr(u) + 0.7 * v]; };
        shell("verge", m, F, [0, 0.2, 0.4, 0.55, 0.75, 1], [0, 0.5, 1], [0, 0, -2.5]);
      }
      const ya = Y(AR, ZV1), yb = Y(re, ZV1);
      shell("verge", "tile", (u, v) => [AX + (xe - AX) * v, ya + (yb - ya) * v - 1, ZV0 - 3 + (-40 - ZV0 + 3) * u], [0, 1], [0, 0.5, 1], [0, -3, 0]);
    }
    { const g = new THREE.SphereGeometry(3.6, 12, 8); const m = add(g, "tile", "verge"); m.position.set(AX, Y(AR + 2, ZV1 + 2), ZV1 + 2); }   // the apex cap

    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
