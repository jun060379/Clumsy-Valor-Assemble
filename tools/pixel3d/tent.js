// The tent built in code (owner 2026-11-07: next -> 천막). The reference sprite (assets/town/hx/g_tentR.png, 296 x 190,
// at half size = 148 x 95 cells) is only the guide. A canvas A-frame tent seen end on, as everything here is seen from
// the front: the front end a canvas triangle with its door slit and a flap folded back, the two slopes running back
// (this view lifts what lies behind, so the roof shows above the front end as it does on the hall's gable roofs),
// crossed poles at both apexes, guy ropes to pegs. The town sways it row by row (town_fx.gd draw_tent).
// Coordinates as hall.js (x column, rows down from the top, Z toward the viewer, B0 = the foot line).

const TENT = (function () {
  const W = 150, H = 125, B0 = 95, K = 0.25, TOP = 16;
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
    // ---- the form, read off the reference (owner 2026-11-07: "형태에 대한 제대로된 이해가 없나?"): a ridge tent seen from
    // its front left. Its door end is the triangle at the left (the front pole down its right edge, the door slit in
    // it); the long side runs from that pole to the right, its ridge a level line between the two crossed poles; the
    // far end shows at the right as a narrower triangle. The foot is one level line. Each face is a plane of its own
    // (the end facing front left, the side front and up, the far end right and up), so the one sun shades them apart.
    // Points as (column, row, Z); a face's points take their world height from their row at their own depth.
    const P = (x, r, z) => [x, Y(r, z), z];
    const A = [46, 10, -18], B = [101, 10, -30];                      // the ridge ends (front pole, far pole)
    const L = [13, 89, -14], F = [46, 89, 10], M = [110, 89, 4], R = [131, 89, -22];   // the foot
    const tri = (layer, mat, pts, lift = 0) => {                      // a flat face through 3 or 4 points, lifted along its normal
      const v = pts.map(p => new THREE.Vector3(...P(...p)));
      const n = new THREE.Vector3().subVectors(v[1], v[0]).cross(new THREE.Vector3().subVectors(v[2], v[0])).normalize();
      if (n.z < 0) n.negate();
      const w = v.map(p => p.clone().addScaledVector(n, lift)), b = v.map(p => p.clone().addScaledVector(n, lift - 1.2));
      const t = [], q = (a, c, d) => t.push(a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z);
      for (let i = 1; i < w.length - 1; i++) { q(w[0], w[i], w[i + 1]); q(b[0], b[i + 1], b[i]); }
      for (let i = 0; i < w.length; i++) { const j = (i + 1) % w.length; q(w[i], b[i], b[j]); q(w[i], b[j], w[j]); }
      const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(t, 3)); g.computeVertexNormals();
      return add(g, mat, layer);
    };
    // a point on a face at (x, row): its Z from the face's plane in (column, row) terms
    const onFace = (p0, p1, p2) => { const [x0, r0, z0] = p0, [x1, r1, z1] = p1, [x2, r2, z2] = p2;
      const d = (x1 - x0) * (r2 - r0) - (x2 - x0) * (r1 - r0);
      const a = ((z1 - z0) * (r2 - r0) - (z2 - z0) * (r1 - r0)) / d, b = ((x1 - x0) * (z2 - z0) - (x2 - x0) * (z1 - z0)) / d;
      return (x, r) => [x, r, z0 + a * (x - x0) + b * (r - r0)]; };
    tri("canvas", "canvas", [A, L, F]);                               // the door end
    tri("canvas", "canvas", [A, F, M, B]);                            // the long side
    tri("canvas", "canvas", [B, M, R]);                               // the far end
    tri("canvas", "canvasDk", [A, B, [101, 10, -60], [46, 10, -48]]); // the far slope, behind the ridge (seen only as its top edge)
    // the door: a dark slit down the door end beside the front pole, its flap folded back
    const E = onFace(A, L, F);
    // the door (owner 2026-11-07: "문이 뭔지 모르시나?"): the end's canvas parted down the middle from near the top and
    // tied back - an opening shaped like an upturned V, the dark of the inside showing to the ground, each half of the
    // canvas folded back on itself and lashed at the side, a cord across where it is tied
    tri("door", "doorGap", [E(36, 30), E(25, 89), E(45, 89)], 0.4);              // the opening
    tri("door", "canvasDk", [E(36, 30), E(31, 62), E(25, 89), E(20, 89)], 0.8);    // the left half folded back
    tri("door", "canvasDk", [E(36, 30), E(41, 62), E(45, 89), E(45, 60)], 0.8);    // the right half folded back against the pole
    for (const [x0, x1] of [[23, 32], [40, 46]]) tri("door", "rope", [E(x0, 62), E(x1, 62), E(x1, 64), E(x0, 64)], 1.1);   // the ties
    // a seam of shade down the long side where the canvas folds over the far end's pole
    // ---- the poles: the front pole down the door end's edge, crossed poles at both ridge ends, the ridge pole
    bar("poles", "pole", 46, 6, 46, 89, 3, 10, 12.5);
    for (const [x, z] of [[46, 12], [101, -26]]) {
      bar("poles", "pole", x - 6, 0, x + 5, 16, 4, z - 1.5, z + 2);           // the short legs of the cross, lashed
      bar("poles", "pole", x + 6, 0, x - 5, 16, 4, z - 1.5, z + 2);
      box("poles", "rope", x - 3, x + 3, 6, 9, z + 1.5, z + 2.5);
    }
    { const a = new THREE.Vector3(...P(46, 9, -16)), b = new THREE.Vector3(...P(101, 9, -28)), m = a.clone().add(b).multiplyScalar(0.5);
      const g = new THREE.CylinderGeometry(1.3, 1.3, a.distanceTo(b), 6); const mesh = add(g, "pole", "poles");
      mesh.position.copy(m); mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), b.clone().sub(a).normalize()); }
    // ---- the crossed poles' outer legs run on down to the ground either side (the reference's long poles), staked
    bar("poles", "pole", 42, 4, 8, 90, 3.2, 11, 13.5);
    bar("poles", "pole", 105, 4, 140, 90, 3.2, -27, -24.5);
    for (const [x, z] of [[8, 12], [140, -26]]) box("poles", "peg", x - 3, x + 3, 86, 93, z - 2, z + 2);

    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
