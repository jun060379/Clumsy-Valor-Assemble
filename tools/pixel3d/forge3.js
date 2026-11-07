// The smithy, third try (owner 2026-11-07: "우측 요소 우선으로 리모델링" - the right one of the two references the owner
// sent, a stylised 3D smithy (meshy.ai), first; the Cainos smithy's parts where they fit). Reference for form only.
// A cottage with its forge built into the foot of a central chimney: at the left a front gable with the door and a
// small gable window, in the middle the stack rising from a stone forge with an arched fire mouth and a hearth ledge,
// at the right a timber-framed wing under a long slate roof with a hanging sign on a scrolled iron bracket; a lantern
// at the left, a barrel and a shield by the hearth. Palette as forge2 (slate and stone on the cream ramp's low steps,
// plaster its light end, wood the wood ramp).

const FORGE3 = (function () {
  const W = 295, H = 169, B0 = 145, K = 0.25, TOP = 10;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    slate: ["cream", 1], slateDk: ["cream", 0], slateLt: ["cream", 2], roofBase: ["cream", 0], ridge: ["cream", 2],
    stone: ["cream", 3], plinthHi: ["cream", 5], mortar2: ["wood", 2], soot: ["stone", 2],
    plaster: ["cream", 6], timber: ["wood", 5], plank: ["wood", 4], plankDk: ["wood", 2],
    frame: ["wood", 4], door: ["wood", 5], doorGap: ["wood", 1], glass: ["cream", 6], mullion: ["wood", 3],
    iron: ["iron", 3], ironDk: ["iron", 1], barrel: ["wood", 5], shield: ["red", 2], shieldRim: ["iron", 3],
    sign: ["wood", 5], signMark: ["cream", 7],
    fireLamp: ["ochre", 6],
  };
  const LAYERS = ["ground", "walls", "timber", "windows", "door", "forge", "chimney", "roof", "tiles", "verge", "sign", "props"];

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

    // ---- a stone foot along the whole front
    courses("walls", [136, 145], () => [14, 256], 8, { w: 13, gx: 14, gr: 136, ch: 9 });

    // ---- the left: a front gable over the door
    const ZG = 6, AX = 66, AR = 20;                                                  // apex column and row
    const vU = (x) => AR + 12 + Math.abs(x - AX) * 0.95;                             // the verge's underside (a steep gable)
    slab("walls", "plaster", [[22, 136], [110, 136], [110, vU(110)], [AX, AR + 12], [22, vU(22)]], -30, ZG, [[[48, 99], [84, 99], [84, 136], [48, 136]].reverse()]);   // the door opening
    for (const [a, b] of [[22, 28], [104, 110]]) box("timber", "timber", a, b, vU(a) - 1, 136, ZG - 2, ZG + 2);
    box("timber", "timber", 22, 110, 86, 91, ZG - 2, ZG + 2);                        // the floor beam
    for (const [a, b] of [[34, 40], [92, 98]]) box("timber", "timber", a, b, vU((a + b) / 2) - 1, 86, ZG - 2, ZG + 2);
    bar("timber", "timber", 40, 86, 60, 62, 4, ZG - 2, ZG + 1.5);                     // a brace either side of the gable window
    bar("timber", "timber", 92, 86, 72, 62, 4, ZG - 2, ZG + 1.5);
    { // the gable window: a small square of four panes
      const x0 = 57, x1 = 75, r0 = 48, r1 = 66, z = ZG;
      slab("windows", "frame", [[x0, r1], [x1, r1], [x1, r0], [x0, r0]], z, z + 1.6, [[[x0 + 3, r0 + 3], [x1 - 3, r0 + 3], [x1 - 3, r1 - 3], [x0 + 3, r1 - 3]]]);
      box("windows", "glass", x0 + 3, x1 - 3, r0 + 3, r1 - 3, z, z + 0.3);
      box("windows", "mullion", 65, 67, r0 + 3, r1 - 3, z, z + 0.9);
      box("windows", "mullion", x0 + 3, x1 - 3, 56, 58, z, z + 0.9);
      box("windows", "frame", x0 - 2, x1 + 2, r1, r1 + 3, z, z + 3);
    }
    { // the door: planks in a frame, an iron ring, set back a little
      slab("door", "frame", [[44, 136], [88, 136], [88, 96], [44, 96]], ZG - 1, ZG + 1.8, [[[48, 99], [84, 99], [84, 136], [48, 136]]]);
      box("door", "doorGap", 48, 84, 99, 136, ZG - 2.6, ZG - 2.2);
      for (let x = 49; x < 84; x += 6) box("door", "door", x, Math.min(x + 5, 84), 100, 136, ZG - 2.2, ZG - 1.2);
      for (const r of [107, 127]) box("door", "ironDk", 50, 82, r, r + 2, ZG - 1.2, ZG - 0.6);
      const g = new THREE.TorusGeometry(2.2, 0.7, 6, 12); const m = add(g, "iron", "door"); m.position.set(78, Y(118, ZG - 0.4), ZG - 0.4);
    }
    // the gable's verges: a board and a band of slates down each slope; the gable roof behind
    const ZV0 = ZG + 2, ZV1 = ZG + 10;
    for (const s of [-1, 1]) {
      const xe = AX + s * 58, re = AR + 58 * 0.95 + 12;
      bar("verge", "plankDk", AX, AR + 14, xe, re + 2, 4, ZV0, ZV1 - 2);
      for (let i = 0, n = 6; i < n; i++) {
        const t0 = i / n + 0.006, t1 = (i + 1) / n - 0.012;
        const hh = Math.abs(Math.sin((i + 3) * 9.137 + s * 3.3) * 43758.5453) % 1;
        const m = hh < 0.15 ? "slateDk" : "slate";
        const pr = (u) => u < 0.55 ? 0.4 + 3.0 * u / 0.55 : 3.4 - 2.4 * (u - 0.55) / 0.45;
        const F = (u, v) => { const t = t0 + (t1 - t0) * v, x = AX + (xe - AX) * t, row = AR + (re - AR - 12) * t + 12 * u;
          return [x, Y(row, ZV1), ZV1 - 1 + pr(u) + 0.6 * v]; };
        shell("verge", m, F, [0, 0.2, 0.4, 0.55, 0.75, 1], [0, 0.5, 1], [0, 0, -2.5]);
      }
      const ya = Y(AR, ZV1), yb = Y(re - 12, ZV1);
      // the gable roof behind: one plane back to the main roof (strips of shells made a checker of single cells here)
      shell("verge", "slate", (u, v) => [AX + (xe - AX) * v, ya + (yb - ya) * v - 1, ZV0 - 3 + (-40 - ZV0 + 3) * u], [0, 1], [0, 0.5, 1], [0, -3, 0]);
    }

    // ---- the right wing, turned to run back (owner 2026-11-07: "오른 쪽에 있는 집을 90도 돌려서 뒤편을 향하게" /
    // "붙여"): its gable end now faces the street, set right against the forge; a shop window with shutters below, a
    // small window in the gable, the timber frame and slate verges as on the left gable; its roof runs far back
    const ZR = 2, BX = 212, BR = 34, BH = 42;                                        // apex column, apex row, half width
    const vR = (x) => BR + 12 + Math.abs(x - BX) * 0.95;
    const w0 = parts.length;
    slab("walls", "plaster", [[BX - BH, 136], [BX + BH, 136], [BX + BH, vR(BX + BH)], [BX, BR + 12], [BX - BH, vR(BX - BH)]], -90, ZR,
         [[[194, 101], [230, 101], [230, 123], [194, 123]].reverse()]);
    for (const [a, b] of [[BX - BH, BX - BH + 6], [BX + BH - 6, BX + BH]]) box("timber", "timber", a, b, vR(a) - 1, 136, ZR - 2, ZR + 2);
    box("timber", "timber", BX - BH, BX + BH, 86, 91, ZR - 2, ZR + 2);
    for (const [a, b] of [[BX - 30, BX - 24], [BX + 24, BX + 30]]) box("timber", "timber", a, b, vR((a + b) / 2) - 1, 86, ZR - 2, ZR + 2);
    bar("timber", "timber", BX - 24, 86, BX - 8, 66, 4, ZR - 2, ZR + 1.5);
    bar("timber", "timber", BX + 24, 86, BX + 8, 66, 4, ZR - 2, ZR + 1.5);
    { const x0 = BX - 8, x1 = BX + 8, r0 = 54, r1 = 70, z = ZR;                       // the gable window
      slab("windows", "frame", [[x0, r1], [x1, r1], [x1, r0], [x0, r0]], z, z + 1.6, [[[x0 + 3, r0 + 3], [x1 - 3, r0 + 3], [x1 - 3, r1 - 3], [x0 + 3, r1 - 3]]]);
      box("windows", "glass", x0 + 3, x1 - 3, r0 + 3, r1 - 3, z, z + 0.3);
      box("windows", "mullion", BX - 1, BX + 1, r0 + 3, r1 - 3, z, z + 0.9);
      box("windows", "frame", x0 - 2, x1 + 2, r1, r1 + 3, z, z + 3); }
    { // the shop window: a dark inside, a frame with a cross, shutters swung open, a sill board
      box("windows", "plankDk", 194, 230, 101, 123, ZR - 8, ZR - 7);
      slab("windows", "frame", [[192, 125], [232, 125], [232, 99], [192, 99]], ZR - 1, ZR + 1.6, [[[195, 102], [229, 102], [229, 122], [195, 122]]]);
      box("windows", "mullion", 211, 213, 102, 122, ZR - 1, ZR + 0.6);
      box("windows", "mullion", 195, 229, 111, 113, ZR - 1, ZR + 0.6);
      for (const [a, b] of [[184, 192], [232, 240]]) { box("windows", "plank", a, b, 99, 125, ZR, ZR + 1.4); box("windows", "ironDk", a + 1, b - 1, 104, 105, ZR + 1.4, ZR + 1.8); box("windows", "ironDk", a + 1, b - 1, 119, 120, ZR + 1.4, ZR + 1.8); }
      box("windows", "frame", 190, 234, 125, 128, ZR, ZR + 4); }
    { const ZV0 = ZR + 2, ZV1 = ZR + 10;                                              // verges and the long roof behind
      for (const s of [-1, 1]) {
        const xe = BX + s * (BH + 12), re = BR + (BH + 12) * 0.95 + 12;
        bar("verge", "plankDk", BX, BR + 14, xe, re + 2, 4, ZV0, ZV1 - 2);
        for (let i = 0, n = 6; i < n; i++) {
          const t0 = i / n + 0.006, t1 = (i + 1) / n - 0.012;
          const hh = Math.abs(Math.sin((i + 5) * 9.137 + s * 4.1) * 43758.5453) % 1;
          const m = hh < 0.15 ? "slateDk" : "slate";
          const pr = (u) => u < 0.55 ? 0.4 + 3.0 * u / 0.55 : 3.4 - 2.4 * (u - 0.55) / 0.45;
          const F = (u, v) => { const t = t0 + (t1 - t0) * v, x = BX + (xe - BX) * t, row = BR + (re - BR - 12) * t + 12 * u;
            return [x, Y(row, ZV1), ZV1 - 1 + pr(u) + 0.6 * v]; };
          shell("verge", m, F, [0, 0.2, 0.4, 0.55, 0.75, 1], [0, 0.5, 1], [0, 0, -2.5]);
        }
        const ya = Y(BR, ZV1), yb = Y(re - 12, ZV1);
        shell("verge", "slate", (u, v) => [BX + (xe - BX) * v, ya + (yb - ya) * v - 1, ZV0 - 3 + (-100 - ZV0 + 3) * u], [0, 1], [0, 0.5, 1], [0, -3, 0]);
      }
    }
    const w1 = parts.length;

    // ---- the forge in the chimney's foot: a stone block, an arched fire mouth, a hearth ledge; the hood narrows into
    // the stack, which runs up past the ridge (the fire comes later as an effect, centre x 140, row 128)
    const ZF = 18, CX = 140;
    const fspan = (r) => r < 72 ? [124, 156] : r < 92 ? [124 - (r - 72) * 0.75, 156 + (r - 72) * 0.75] : [108, 172];
    const mouth = archPts(122, 158, 100, 130);
    slab("forge", "mortar2", [[108, 145], [108, 92], [124, 72], [156, 72], [172, 92], [172, 145]], ZF - 22, ZF - 6, [mouth.slice().reverse()]);
    slab("chimney", "mortar2", [[124, 72], [124, 8], [156, 8], [156, 72]], ZF - 22, ZF - 11);
    const fHoles = (r0, r1) => { const H = [];
      if (r1 >= 94 && r0 < 118) { const rr = Math.min(Math.max(118, r0), r1), hw = Math.sqrt(Math.max(0, 24 * 24 - (118 - rr) * (118 - rr))); H.push([CX - hw, CX + hw]); }
      if (r1 >= 118 && r0 < 136) H.push([116, 164]);
      return H.map(([a, b]) => [Math.floor(a), Math.ceil(b)]); };
    courses("forge", rowsFrom(72, 145, 8), fspan, ZF, { w: 14, gx: 124, gr: 8, ch: 8, holes: fHoles });
    courses("chimney", rowsFrom(8, 72, 8), () => [124, 156], ZF - 5, { w: 14, gx: 124, gr: 8, ch: 8 });
    bar("forge", "stone", 108, 92, 124, 72, 3, ZF - 1.5, ZF + 1);                      // the hood's weathering stones
    bar("forge", "stone", 172, 92, 156, 72, 3, ZF - 1.5, ZF + 1);
    box("chimney", "stone", 121, 159, 3, 8, ZF - 20, ZF - 3.5);                         // the cap
    box("chimney", "plinthHi", 122, 158, 3, 4, ZF - 4.2, ZF - 3.4);
    { const cx = CX, sp = 118, ri = 18, ro = 24, n = 9;                                // voussoirs
      for (let i = 0; i < n; i++) {
        const a0 = Math.PI * (i + 0.08) / n, a1 = Math.PI * (i + 0.92) / n, pts = [];
        for (let t = 0; t <= 3; t++) { const a = a0 + (a1 - a0) * t / 3; pts.push([cx + ro * Math.cos(a), sp - ro * Math.sin(a)]); }
        for (let t = 3; t >= 0; t--) { const a = a0 + (a1 - a0) * t / 3; pts.push([cx + ri * Math.cos(a), sp - ri * Math.sin(a)]); }
        slab("forge", "stone", pts, ZF - 1.2, ZF + (i === 4 ? 2.2 : 1.4));
      }
      for (const [a, b] of [[116, 122], [158, 164]]) box("forge", "stone", a, b, 118, 130, ZF - 1.2, ZF + 1.4);
    }
    slab("forge", "soot", mouth, ZF - 18, ZF - 16);
    box("forge", "soot", 122, 158, 126, 130, ZF - 16, ZF - 2);                        // the fire bed
    box("forge", "stone", 112, 168, 130, 136, ZF - 2, ZF + 5);                        // the hearth ledge
    box("forge", "plinthHi", 113, 167, 130, 131, ZF + 4.4, ZF + 5.2);

    // ---- the signs: a scrolled iron bracket and a board at the right, a lantern on a bracket at the left
    const s0 = parts.length;
    box("sign", "ironDk", 252, 276, 92, 94, ZR, ZR + 2);
    bar("sign", "ironDk", 256, 106, 272, 94, 1.6, ZR, ZR + 2);
    { const g = new THREE.TorusGeometry(4, 0.8, 6, 16, Math.PI * 1.5); const m = add(g, "ironDk", "sign"); m.position.set(262, Y(90, ZR + 1), ZR + 1); }
    for (const x of [259, 271]) box("sign", "ironDk", x, x + 1, 94, 100, ZR, ZR + 1);
    slab("sign", "sign", [[255, 100], [275, 100], [275, 118], [265, 123], [255, 118]], ZR - 1, ZR + 2);
    bar("sign", "signMark", 259, 117, 271, 103, 1.6, ZR + 2, ZR + 2.6);                   // crossed swords
    bar("sign", "signMark", 271, 117, 259, 103, 1.6, ZR + 2, ZR + 2.6);
    box("sign", "signMark", 263, 267, 109, 111, ZR + 2.2, ZR + 2.8);
    const s1 = parts.length;
    box("sign", "ironDk", 8, 24, 84, 86, ZG - 2, ZG);                                   // the lantern's bracket
    box("sign", "ironDk", 10, 11, 86, 91, ZG - 2, ZG - 1);
    box("sign", "iron", 6, 15, 91, 93, ZG - 4, ZG + 1);
    box("sign", "fireLamp", 7, 14, 93, 101, ZG - 3, ZG);
    box("sign", "iron", 6, 15, 101, 103, ZG - 4, ZG + 1);

    // ---- props: a barrel by the wing, a shield leaning on the hearth
    { const g = new THREE.CylinderGeometry(10, 10, 24, 16); const m = add(g, "barrel", "props"); m.position.set(244, Y(133, 22), 22);
      for (const r of [125, 141]) { const gg = new THREE.CylinderGeometry(10.4, 10.4, 1.6, 16); const mm = add(gg, "ironDk", "props"); mm.position.set(244, Y(r, 22), 22); } }
    slab("props", "shieldRim", [[172, 118], [190, 118], [190, 132], [181, 141], [172, 132]], ZF + 4, ZF + 6);
    slab("props", "shield", [[174, 120], [188, 120], [188, 131], [181, 138], [174, 131]], ZF + 6, ZF + 7);
    box("props", "signMark", 180, 182, 122, 134, ZF + 7, ZF + 7.6);

    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
