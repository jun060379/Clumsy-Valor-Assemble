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
    // ---- the form (owner 2026-11-07: "텐트라는 형태에 대해 이해를 해봐야함"). A ridge tent: an A-frame of two crossed
    // poles at each end, a ridge pole between their crossings, the canvas thrown over the ridge and pegged down along
    // both long sides; each end a canvas triangle, the door in the front one, held up by a pole down its middle. The
    // reference sees it from the front and a little to the left: the FRONT END is the big triangle facing us (its pole
    // down the middle, the door opening at the pole's foot), the ridge runs away to the back crossing at the top right,
    // and beyond the fold from the front apex down to the right the long side shows, going back to the far end's leg.
    const P = (x, r, z) => [x, Y(r, z), z];
    const A = [46, 10, 0], B = [101, 10, -44];                        // the ridge's ends: the front crossing, the back crossing
    const L = [13, 89, 8], M = [100, 89, 8], R = [131, 89, -36];      // the foot: front end's corners, the long side's far corner
    const tri = (layer, mat, pts, lift = 0) => {                      // a flat face through its points, lifted along its normal
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
    const onFace = (p0, p1, p2) => { const [x0, r0, z0] = p0, [x1, r1, z1] = p1, [x2, r2, z2] = p2;
      const d = (x1 - x0) * (r2 - r0) - (x2 - x0) * (r1 - r0);
      const a = ((z1 - z0) * (r2 - r0) - (z2 - z0) * (r1 - r0)) / d, b = ((x1 - x0) * (z2 - z0) - (x2 - x0) * (z1 - z0)) / d;
      return (x, r) => [x, r, z0 + a * (x - x0) + b * (r - r0)]; };
    tri("canvas", "canvas", [A, L, M]);                               // the front end
    tri("canvas", "canvas", [A, M, R, B]);                            // the long side, running back
    tri("canvas", "canvasDk", [A, B, [101, 10, -84], [46, 10, -40]]); // the far slope, behind the ridge
    const E = onFace(A, L, M), S = onFace(A, M, R);
    tri("canvas", "canvasDk", [S(47, 12), S(52, 12), S(103, 88), S(98, 88)], 0.3);   // the fold where the end turns into the side
    // the door at the foot of the middle pole: the canvas parted from halfway up and drawn back either side - an
    // upturned V, the inside dark to the ground, a light fold along each parted edge
    tri("door", "doorGap", [E(46, 26), E(33, 89), E(59, 89)], 0.5);
    tri("door", "canvas", [E(46, 26), E(31, 89), E(33, 89), E(46, 30)], 0.9);
    tri("door", "canvas", [E(46, 26), E(46, 30), E(59, 89), E(61, 89)], 0.9);
    // the hem along the foot, a shade darker
    tri("canvas", "canvasDk", [E(13, 87), E(100, 87), E(100, 89), E(13, 89)], 0.4);
    tri("canvas", "canvasDk", [S(100, 87), S(131, 87), S(131, 89), S(100, 89)], 0.4);
    // a stake by the door, its guy line run up to the fold where the end turns into the side
    const seg = (a, b, r, mat) => { const m = a.clone().add(b).multiplyScalar(0.5);
      const g = new THREE.CylinderGeometry(r, r, a.distanceTo(b), 10); const mesh = add(g, mat, "poles");
      mesh.position.copy(m); mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), b.clone().sub(a).normalize()); };
    { const g = new THREE.CylinderGeometry(2.6, 2.8, 20, 8); const m = add(g, "pole", "poles"); m.position.set(84, Y(84, 22), 22); m.rotation.z = -0.08; }
    // one rope for every line on the tent: the guy line runs from the front crossing, where it is tied with the
    // lashing, down to the head of the stake and wraps it
    const ROPE = 0.8, V = (x, r, z) => new THREE.Vector3(...P(x, r, z));
    seg(V(47, 8, 5), V(84, 75, 23), ROPE, "rope");
    seg(V(81.5, 76, 23), V(86.5, 76, 23), ROPE, "rope");
    // ---- the poles: the middle pole down the front end, the crossed poles at the ridge's ends with their outer legs
    // splayed down to pegs, the ridge pole between the crossings
    bar("poles", "pole", 46, 4, 46, 93, 3, 9, 11.5);
    for (const [x, z] of [[46, 2], [101, -42]]) {
      bar("poles", "pole", x - 6, 0, x + 5, 16, 4, z - 1.5, z + 2);
      bar("poles", "pole", x + 6, 0, x - 5, 16, 4, z - 1.5, z + 2);
      seg(V(x - 3.5, 6.5, z + 2.5), V(x + 3.5, 9.5, z + 2.5), ROPE, "rope");      // the lashing: the same rope,
      seg(V(x - 3.5, 9.5, z + 2.5), V(x + 3.5, 6.5, z + 2.5), ROPE, "rope");      // crossed over the crossing
    }
    bar("poles", "pole", 42, 4, 8, 90, 3.2, 9, 11.5);                                  // the front frame's outer leg
    bar("poles", "pole", 105, 4, 140, 90, 3.2, -40, -37.5);                            // the back frame's outer leg
    for (const [x, z] of [[8, 10], [140, -38]]) box("poles", "peg", x - 3, x + 3, 86, 93, z - 2, z + 2);
    { const a = new THREE.Vector3(...P(46, 9, -1)), b = new THREE.Vector3(...P(101, 9, -45)), m = a.clone().add(b).multiplyScalar(0.5);
      const g = new THREE.CylinderGeometry(1.3, 1.3, a.distanceTo(b), 6); const mesh = add(g, "pole", "poles");
      mesh.position.copy(m); mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), b.clone().sub(a).normalize()); }

    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
