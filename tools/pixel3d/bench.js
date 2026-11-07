// The bench built in code (owner 2026-11-07: next -> 작은 소품). The reference sprite (assets/town/q_bench.png,
// 149 x 66, one cell per pixel) is only the guide. A plank bench: two tall back posts carrying two back rails, a
// thick seat board with an apron under its front, a short arm on each end post, square front legs.
// The town stands two, one facing the other way: benchL is the same solid mirrored and lit by the same sun.
// Coordinates as hall.js (x column, rows down from the top, Z toward the viewer, B0 = the foot line).

const BENCH = (function () {
  const MIRROR = false;
  const W = 149, H = 78, B0 = 66, K = 0.12, TOP = 4;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    post: ["wood", 4], rail: ["wood", 5], seat: ["wood", 6], apron: ["wood", 4],
  };
  const LAYERS = ["ground", "frame", "boards"];

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
    const ZB = -14;                                                   // the back's plane
    for (const [a, b] of [[5, 18], [130, 143]]) box("frame", "post", a, b, 0, 66, ZB - 3, ZB + 3);    // back posts
    box("boards", "rail", 14, 134, 3, 15, ZB, ZB + 2.5);              // back rails
    box("boards", "rail", 14, 134, 18, 30, ZB, ZB + 2.5);
    for (const [a, b] of [[1, 21], [127, 147]]) box("frame", "post", a, b, 19, 27, ZB - 2, -1);       // the arms
    box("boards", "seat", 0, 149, 34, 40, ZB - 2, 1);                 // the seat board
    box("boards", "apron", 4, 145, 40, 46, -2, 0);                    // its apron
    for (const [a, b] of [[5, 18], [130, 143]]) box("frame", "post", a, b, 46, 66, -3, 0);           // front legs
    if (MIRROR) {                                                    // reflect every part across the middle, keep faces outward
      const flip = new THREE.Matrix4().makeTranslation(W, 0, 0).multiply(new THREE.Matrix4().makeScale(-1, 1, 1));
      for (const p of parts) {
        const m = p.mesh; m.updateMatrix();
        let g = m.geometry.index ? m.geometry.toNonIndexed() : m.geometry;
        g.applyMatrix4(m.matrix); g.applyMatrix4(flip);
        const a = g.attributes.position.array;
        for (let i = 0; i < a.length; i += 9) for (let k = 0; k < 3; k++) { const t = a[i + 3 + k]; a[i + 3 + k] = a[i + 6 + k]; a[i + 6 + k] = t; }
        g.deleteAttribute("normal"); g.deleteAttribute("uv"); g.computeVertexNormals();
        m.geometry = g; m.position.set(0, 0, 0); m.rotation.set(0, 0, 0); m.quaternion.identity(); m.scale.set(1, 1, 1); m.updateMatrix();
      }
    }
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
