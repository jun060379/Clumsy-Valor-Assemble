// The cottage built in code, the same way as the hall, the forge and the barn (owner 2026-11-07: next -> 오두막). The
// reference sprite (assets/town/hx/g_cottage.png, 428 x 292, at half size = 214 x 146 cells) is only the guide.
// A stone cottage: a front gable at the left (plastered and timbered above, dressed stone below, an arched plank door
// in a stone arch), a lower wing at the right under a tiled roof hipped at its end, a shuttered arched window, a stone
// chimney standing on the ridge, big corner stones at the foot.
// Coordinates as hall.js (x column, rows down from the top, Z toward the viewer, B0 = the foot line).

const COTTAGE = (function () {
  const W = 214, H = 170, B0 = 146, K = 0.25, TOP = 10;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    stone: ["cream", 4], stoneLt: ["cream", 5], plinthHi: ["cream", 6], mortar2: ["wood", 2], arch: ["cream", 3],
    plaster: ["cream", 6], timber: ["wood", 5], frame: ["wood", 4], door: ["wood", 4], doorGap: ["wood", 1],
    shutter: ["wood", 3], glass: ["ochre", 4], mullion: ["wood", 3],
    iron: ["iron", 3], ironDk: ["iron", 1],
    roofBase: ["red", 0], tile: ["red", 2], tileDk: ["red", 1], tileLt: ["red", 3], fascia: ["wood", 1],
    chimney: ["cream", 4], soot: ["stone", 2],
  };
  const LAYERS = ["ground", "walls", "timber", "door", "window", "chimney", "roof", "tiles", "verge"];

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
    // ---- the wing at the right: dressed stone, a shuttered window under a stone arch
    const ZW = 0;
    slab("walls", "mortar2", [[112, 140], [204, 140], [204, 88], [112, 88]], -60, ZW - 1, [[[140, 105], [174, 105], [174, 124], [140, 124]].reverse()]);
    courses("walls", rowsFrom(88, 140, 7), () => [112, 204], ZW, { w: 16, gx: 112, gr: 88, ch: 7,
      holes: (r0, r1) => r1 >= 98 && r0 < 125 ? [[136, 178]] : [] });
    { const x0 = 140, x1 = 174, r0 = 105, r1 = 124, z = ZW;                         // the window: a frame, four warm panes
      box("window", "glass", x0, x1, r0, r1, z - 3, z - 2.6);
      slab("window", "frame", [[x0, r1], [x1, r1], [x1, r0], [x0, r0]], z - 2, z + 1.4, [[[x0 + 3, r0 + 3], [x1 - 3, r0 + 3], [x1 - 3, r1 - 3], [x0 + 3, r1 - 3]]]);
      box("window", "mullion", 156, 158, r0 + 3, r1 - 3, z - 2.4, z - 1.2);
      box("window", "mullion", x0 + 3, x1 - 3, 113, 115, z - 2.4, z - 1.2);
      for (const [a, b] of [[131, 140], [174, 183]]) box("window", "shutter", a, b, r0 - 1, r1 + 1, z, z + 1.6);   // shutters, open
      box("window", "stoneLt", x0 - 3, x1 + 3, r1, r1 + 4, z, z + 4);              // the sill
      // a stone lintel over it, its ends a little longer than the frame
      slab("window", "stoneLt", [[136, 104], [178, 104], [178, 99], [177, 98], [137, 98], [136, 99]], z - 1, z + 2);
      box("window", "plinthHi", 137, 177, 98, 99, z + 1.4, z + 2.2);
    }
    for (const [a, b] of [[200, 210]]) box("timber", "timber", a, b, 88, 140, ZW - 2, ZW + 2.5);   // the corner post

    // ---- the wing roof: front slope, hipped at the right end, running on behind the gable
    tileRoof(70, 212, 88, 30, 8, -40, -90, false, true, 0.5, 30 / 58);

    // ---- the chimney: standing on the ridge, dressed stone, a capstone (it rises from the house below, not through
    // an open roof)
    const ZC = -36;
    slab("chimney", "mortar2", [[143, 60], [175, 60], [175, 8], [143, 8]], ZC - 14, ZC - 1);
    courses("chimney", rowsFrom(8, 60, 7), () => [143, 175], ZC, { w: 13, gx: 143, gr: 8, ch: 7 });
    slab("chimney", "chimney", [[140, 8], [140, 4], [141, 3], [177, 3], [178, 4], [178, 8]], ZC - 16, ZC + 2);
    box("chimney", "plinthHi", 141, 177, 3, 4, ZC + 1.4, ZC + 2.2);
    slab("chimney", "chimney", [[148, 3], [148, 0], [149, -1], [169, -1], [170, 0], [170, 3]], ZC - 12, ZC - 3);
    box("chimney", "soot", 150, 168, -1.4, -1, ZC - 11, ZC - 4);

    // ---- the gable at the left: plaster and timber above the beam, dressed stone below, the arched door
    const ZG = 16, AX = 65, AR = 22;
    const vU = (x) => AR + 12 + Math.abs(x - AX) * 1.0;
    slab("walls", "plaster", [[18, 80], [114, 80], [114, vU(114)], [AX, AR + 12], [18, vU(18)]], -40, ZG);
    slab("walls", "mortar2", [[18, 140], [114, 140], [114, 80], [18, 80]], -40, ZG - 1);
    courses("walls", rowsFrom(80, 140, 7), () => [20, 112], ZG, { w: 16, gx: 20, gr: 80, ch: 7,
      // the whole wall laid in stone; the door and its arch are set on it (owner 2026-11-07: "아치 유지하고 그냥 벽 전체
      // 벽돌 넣고 그 위에 문 달라고")
    });
    for (const [a, b] of [[12, 22], [110, 120]]) box("timber", "timber", a, b, vU((a + b) / 2) - 1, 140, ZG - 2, ZG + 2.5);
    // (no king post over the door: owner 2026-11-07, "문 위 나무 ㅗ 모양 된거 그냥 빼기" / "ㅡ 자 판자는 두고" - the beam stays)
    box("timber", "timber", 22, 110, 72, 80, ZG - 2, ZG + 2.5);                      // the beam
    // the door: planks in a round-topped arch of stone, a long iron strap and a handle
    { const outer = archPts(40, 90, 86, 140), inner = archPts(47, 83, 93, 140);
      slab("door", "arch", outer, ZG + 0.5, ZG + 2.6, [inner.slice().reverse()]);
      for (let i = 0; i < 9; i++) { const a0 = Math.PI * (i + 0.06) / 9, a1 = Math.PI * (i + 0.94) / 9, pts = [];   // voussoirs
        for (let t = 0; t <= 3; t++) { const a = a0 + (a1 - a0) * t / 3; pts.push([65 + 25 * Math.cos(a), 111 - 25 * Math.sin(a)]); }
        for (let t = 3; t >= 0; t--) { const a = a0 + (a1 - a0) * t / 3; pts.push([65 + 18 * Math.cos(a), 111 - 18 * Math.sin(a)]); }
        slab("door", "stoneLt", pts, ZG + 0.8, ZG + 3.2); }
      slab("door", "doorGap", inner, ZG, ZG + 0.2);                                  // the door's back: dark between the planks
      const rad = 18, cx = 65, sp = 111, top = (xx) => sp - Math.sqrt(Math.max(0, rad * rad - (xx - cx) * (xx - cx)));
      for (let x = 47; x < 83; x += 6) { const x1 = Math.min(x + 5, 83), poly = [[x, 140], [x1, 140]];
        for (let s = 0; s <= 4; s++) { const xx = x1 - (x1 - x) * s / 4; poly.push([xx, top(xx) + 1]); }
        slab("door", "door", poly, ZG + 0.2, ZG + 1.2); }
      box("door", "ironDk", 50, 80, 118, 120, ZG + 1.2, ZG + 1.8);
      const g = new THREE.TorusGeometry(2, 0.7, 6, 12); const m = add(g, "iron", "door"); m.position.set(76, Y(124, ZG + 2), ZG + 2); }
    // big corner stones at the foot
    for (const [a, b] of [[8, 26], [104, 124]]) { slab("walls", "stoneLt", [[a, 146], [b, 146], [b, 131], [b - 1, 130], [a + 1, 130], [a, 131]], ZG - 4, ZG + 4);
      box("walls", "plinthHi", a + 1, b - 1, 130, 131, ZG + 3.4, ZG + 4.2); }

    // ---- the gable's verges: a board and a band of big tiles down each slope, the gable roof back to the wing ridge
    const ZV0 = ZG + 1, ZV1 = ZG + 6;
    for (const s of [-1, 1]) {
      const xe = AX + s * 62, re = AR + 62 * 1.0;
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
    { const g = new THREE.SphereGeometry(4, 12, 8); const m = add(g, "tile", "verge"); m.position.set(AX, Y(AR + 2, ZV1 + 2), ZV1 + 2); }   // the apex cap

    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
