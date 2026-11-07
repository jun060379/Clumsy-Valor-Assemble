// The tent built in code (owner 2026-11-07: next -> 천막). The reference sprite (assets/town/hx/g_tentR.png, 296 x 190,
// at half size = 148 x 95 cells) is only the guide. A canvas A-frame tent seen end on, as everything here is seen from
// the front: the front end a canvas triangle with its door slit and a flap folded back, the two slopes running back
// (this view lifts what lies behind, so the roof shows above the front end as it does on the hall's gable roofs),
// crossed poles at both apexes, guy ropes to pegs. The town sways it row by row (town_fx.gd draw_tent).
// Coordinates as hall.js (x column, rows down from the top, Z toward the viewer, B0 = the foot line).

const TENT = (function () {
  const W = 210, H = 150, B0 = 95, K = 0.25, TOP = 36;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    canvas: ["cream", 6], canvasDk: ["cream", 4], doorGap: ["wood", 1],
    pole: ["wood", 3], rope: ["wood", 2], peg: ["wood", 3],
  };
  const LAYERS = ["ground", "canvas", "door", "poles", "ropes"];

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
    const AX = 74, AR = 18, BR = 90, HW = 58, ZF = 10, ZB = -90, D = (ZF - ZB) * K;   // D: how many rows the back end stands higher
    const yA = Y(AR, ZF), yB = Y(BR, ZF);
    // ---- the two slopes: canvas from the ridge down to the foot, running back from the front end to the back end,
    // sagging a little between the poles
    for (const s of [-1, 1]) {
      shell("canvas", "canvas", (u, v) => { const z = ZF + (ZB - ZF) * v, sag = 1.6 * Math.sin(Math.PI * u) * (0.6 + 0.4 * Math.sin(Math.PI * v));
        const x = AX + s * HW * u, y = yA + (yB - yA) * u;
        return [x - s * sag * 0.6, y - sag, z]; },
        [0, 0.15, 0.3, 0.5, 0.7, 0.85, 1], [0, 0.25, 0.5, 0.75, 1], [0, -1.2, 0]);
    }
    // ---- the front end: a canvas triangle, the door slit left of the middle, its flap folded back
    slab("canvas", "canvas", [[AX - HW, BR], [AX + HW, BR], [AX, AR]], ZF - 1.2, ZF - 0.2);
    slab("door", "doorGap", [[AX - 30, BR], [AX - 4, BR], [AX - 4, AR + 10]], ZF - 0.2, ZF + 0.1);
    slab("door", "canvasDk", [[AX - 14, BR], [AX - 4, BR], [AX - 4, AR + 22]], ZF + 0.1, ZF + 0.8);   // the flap, tied back
    box("door", "rope", AX - 13, AX - 6, 66, 68, ZF + 0.8, ZF + 1.4);                   // its tie
    box("door", "canvasDk", AX - 2, AX + 26, BR - 2, BR, ZF - 0.2, ZF + 1.2);             // the hem's shade along the foot (its fold)
    // ---- the poles: crossed at each apex, the ridge pole between
    for (const [dr, z] of [[0, ZF + 1.5], [-D, ZB + 1.5]]) {
      bar("poles", "pole", AX - 9, AR - 12 + dr, AX + 6, AR + 10 + dr, 3, z - 1.5, z + 1.5);
      bar("poles", "pole", AX + 9, AR - 12 + dr, AX - 6, AR + 10 + dr, 3, z - 1.5, z + 1.5);
      for (const sx of [-1, 1]) {                                                     // guy ropes from the cross down to pegs
        bar("ropes", "rope", AX + sx * 7, AR - 9 + dr, AX + sx * (HW + 14), BR + 1 + dr, 1.3, z - 1, z);
        box("ropes", "peg", AX + sx * (HW + 14) - 2, AX + sx * (HW + 14) + 2, BR - 3 + dr, BR + 3 + dr, z - 2, z + 1);
      }
    }
    { const g = new THREE.BoxGeometry(2.4, 2.4, ZF - ZB); const m = add(g, "pole", "poles"); m.position.set(AX, yA + 1.4, (ZF + ZB) / 2); }

    // ---- turned as the reference stands (owner 2026-11-07: "이게 뭐고 원본처럼해"): the door end to the front left, the
    // long right slope to the front. Built end-on above, then turned about the upright through its middle, set on the
    // ground (its floor at y 0) and slid to the canvas's left edge
    { const rot = new THREE.Matrix4().makeRotationY(-35 * Math.PI / 180), cz = (ZF + ZB) / 2;
      const toO = new THREE.Matrix4().makeTranslation(-AX, 0, -cz), back = new THREE.Matrix4().makeTranslation(AX, 0, cz);
      const bb = new THREE.Box3();
      for (const p of parts) { const m = p.mesh; m.updateMatrix(); m.geometry = m.geometry.clone(); m.geometry.applyMatrix4(m.matrix);
        m.position.set(0, 0, 0); m.rotation.set(0, 0, 0); m.scale.set(1, 1, 1);
        m.geometry.applyMatrix4(toO); m.geometry.applyMatrix4(rot); m.geometry.applyMatrix4(back);
        m.geometry.computeBoundingBox(); bb.union(m.geometry.boundingBox); }
      const fit = new THREE.Matrix4().makeTranslation(4 - bb.min.x, -yB, 24 - bb.max.z);   // its nearest corner on the ground band's front part
      for (const p of parts) p.mesh.geometry.applyMatrix4(fit); }

    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
