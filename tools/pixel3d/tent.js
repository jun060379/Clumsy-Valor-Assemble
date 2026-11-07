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
    // ---- the form, built as a real solid (owner 2026-11-07: "3d 기준 형태 자체가 텐트가 아니니까 그림자가 이상해지잖아").
    // World units: x right, y up from the ground (y = 0), z toward the viewer. A ridge tent: a canvas prism whose
    // cross-section is the front end triangle, run back along the ridge; the ridge level, the foot flat on the ground.
    // This camera cannot turn a thing sideways, so the prism runs right and a little back (D), which puts the front
    // end facing us with the long side beyond the fold, as the reference draws it.
    const V = (x, y, z) => new THREE.Vector3(x, y, z);
    const Hh = 86, ZF = 6, D = V(55, 0, -24);                             // ridge height, the front end's plane, the run
    const A = V(46, Hh, ZF), L = V(13, 0, ZF), M = V(79, 0, ZF);         // the front end: apex, foot corners
    const B = A.clone().add(D), R = M.clone().add(D), L2 = L.clone().add(D);
    const face = (layer, mat, v, lift = 0, back = 1.2) => {               // a flat panel through its points, lifted along its normal
      const n = new THREE.Vector3().subVectors(v[1], v[0]).cross(new THREE.Vector3().subVectors(v[2], v[0])).normalize();
      if (n.z < 0) n.negate();
      const w = v.map(p => p.clone().addScaledVector(n, lift)), b = v.map(p => p.clone().addScaledVector(n, lift - back));
      const t = [], q = (a, c, d) => t.push(a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z);
      for (let k = 1; k < w.length - 1; k++) { q(w[0], w[k], w[k + 1]); q(b[0], b[k + 1], b[k]); }
      for (let k = 0; k < w.length; k++) { const m = (k + 1) % w.length; q(w[k], b[k], b[m]); q(w[k], b[m], w[m]); }
      const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(t, 3)); g.computeVertexNormals();
      return add(g, mat, layer);
    };
    face("canvas", "canvas", [A, L, M]);                                 // the front end
    face("canvas", "canvas", [A, M, R, B]);                              // the near long side
    face("canvas", "canvas", [A, B, L2, L]);                             // the far long side
    face("canvas", "canvas", [B, R, L2]);                                // the back end
    const onEnd = (x, y) => V(x, y, ZF), onSide = (s, t) => M.clone().addScaledVector(A.clone().sub(M), s).addScaledVector(D, t);
    // the door at the foot of the middle pole: the canvas parted from well up and drawn back either side - an
    // upturned V, dark inside to the ground, a light fold along each parted edge
    face("door", "doorGap", [onEnd(46, 64), onEnd(33, 0), onEnd(59, 0)], 0.5);
    face("door", "canvas", [onEnd(46, 64), onEnd(31, 0), onEnd(33, 0), onEnd(46, 60)], 0.9);
    face("door", "canvas", [onEnd(46, 64), onEnd(46, 60), onEnd(59, 0), onEnd(61, 0)], 0.9);
    // the hem along the foot, a shade darker
    face("canvas", "canvasDk", [onEnd(13, 2), onEnd(79, 2), onEnd(79, 0), onEnd(13, 0)], 0.4);
    face("canvas", "canvasDk", [onSide(2 / Hh, 0), onSide(2 / Hh, 1), onSide(0, 1), onSide(0, 0)], 0.4);

    // ---- the poles and lines: the middle pole down the front end, short crossed poles over each end of the ridge, the
    // ridge pole between them; one rope for every line - the lashings, a guy line from each crossing out along the
    // ridge to a peg, and one from the front crossing down to the stake by the door
    const ROPE = 0.8;
    const seg = (a, b, r, mat) => { const m = a.clone().add(b).multiplyScalar(0.5);
      const g = new THREE.CylinderGeometry(r, r, a.distanceTo(b), 10); const mesh = add(g, mat, "poles");
      mesh.position.copy(m); mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), b.clone().sub(a).normalize()); return mesh; };
    seg(V(46, -1, ZF + 1.6), V(46, Hh + 4, ZF + 1.6), 1.6, "pole");
    const dn = D.clone().normalize();
    for (const C of [A, B]) {
      const c = C.clone().add(V(0, 1, 1.6));
      seg(c.clone().add(V(-7, -8, 0)), c.clone().add(V(6, 7, 0)), 1.6, "pole");
      seg(c.clone().add(V(7, -8, 0)), c.clone().add(V(-6, 7, 0)), 1.6, "pole");
      seg(c.clone().add(V(-3, -2, 1.4)), c.clone().add(V(3, 2, 1.4)), ROPE, "rope");
      seg(c.clone().add(V(-3, 2, 1.4)), c.clone().add(V(3, -2, 1.4)), ROPE, "rope");
    }
    seg(A.clone().add(V(0, 1.5, 0)), B.clone().add(V(0, 1.5, 0)), 1.3, "pole");
    const pegF = A.clone().addScaledVector(dn, -42).setY(0), pegB = B.clone().addScaledVector(dn, 42).setY(0);
    for (const [C, p] of [[A, pegF], [B, pegB]]) {
      seg(C.clone().add(V(0, 2, 1.6)), p.clone().add(V(0, 3, 0)), ROPE, "rope");
      seg(p.clone().add(V(0, -1, 0)), p.clone().add(V(0, 6, 0)), 2.6, "peg");
    }
    const stake = V(84, 0, 24);
    seg(stake.clone().add(V(0, -1, 0)), stake.clone().add(V(0, 18, 0)), 2.6, "pole");
    seg(A.clone().add(V(0, 2, 1.6)), stake.clone().add(V(0, 17, 0)), ROPE, "rope");
    seg(stake.clone().add(V(-2.6, 16, 0)), stake.clone().add(V(2.6, 16, 0)), ROPE, "rope");

    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
