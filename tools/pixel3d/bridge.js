// The footbridge built in code (owner 2026-11-07: 작은 소품). The reference sprite (assets/town/q_bridge.png, 317 x 55,
// one cell per pixel) is only the guide. A plank deck on a thick edge beam, a post-and-rail fence along each side, the
// deck carried on squared legs with a raking brace either side of each.
// Coordinates as hall.js (x column, rows down from the top, Z toward the viewer, B0 = the foot line).

const BRIDGE = (function () {
  const W = 317, H = 66, B0 = 55, K = 0.12, TOP = 8;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    post: ["wood", 4], rail: ["wood", 5], beam: ["wood", 6], deck: ["wood", 5], deckGap: ["wood", 2], leg: ["wood", 4],
  };
  const LAYERS = ["ground", "deck", "fence", "legs"];

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
    const ZF = 0, ZK = -40;                                          // the deck's front and back edges
    box("deck", "beam", 0, 317, 22, 38, ZF - 6, ZF);                  // the front edge beam
    box("deck", "beam", 0, 317, 22, 38, ZK, ZK + 6);                  // the back one
    box("deck", "deck", 0, 317, 22, 24, ZK + 6, ZF - 6);              // the deck between them
    for (let x = 12; x < 317; x += 12) box("deck", "deckGap", x, x + 1, 21.8, 22.2, ZK + 6, ZF - 6);   // its board joints
    for (const z of [ZF, ZK + 4]) {                                   // a fence along each side
      for (const x of [10, 66, 124, 186, 242, 296]) box("fence", "post", x, x + 10, 0, 24, z - 4, z);
      box("fence", "rail", 14, 302, 4, 13, z - 3, z - 1);
    }
    for (const [a, b] of [[10, 20], [104, 118], [200, 214], [290, 304]]) {   // the legs and their braces
      box("legs", "leg", a, b, 38, 55, ZF - 8, ZF - 2);
      bar("legs", "leg", a - 14, 39, a, 50, 6, ZF - 7, ZF - 3);
      bar("legs", "leg", b + 14, 39, b, 50, 6, ZF - 7, ZF - 3);
    }

    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
