// The street lamp built in code (owner 2026-11-07: 작은 소품). The reference sprite (assets/town/q_lamp.png, 113 x 197,
// one cell per pixel) is only the guide. A cast-iron post turned on a lathe - a stepped foot, collars, a slim shaft, a
// spiked finial - an arm that curls out over a scroll and hooks down to a lantern with four glowing panes under a
// pyramid hood, and a short bracket lower down that carries the town's banner. The game draws the banner as its own
// swaying layer (q_lamp_ban): here it is its own layer too.
// Built as a real solid: world units, x right, y up from the ground (y = 0), z toward the viewer.

const LAMP = (function () {
  const W = 113, H = 205, B0 = 197, K = 0.12, TOP = 4;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    iron: ["stone", 6], ironLt: ["stone", 7], fireGlass: ["cream", 5],
    banner: ["violet", 3], trim: ["cream", 5],
  };
  const LAYERS = ["ground", "post", "lantern", "banner"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    const V = (x, y, z) => new THREE.Vector3(x, y, z);
    const yr = (row) => B0 - row;                                    // a row on the post's plane (z = 0) as a height
    const PX = 20, PZ = -6;

    // ---- the post, turned: its radius step by step from the foot up
    const prof = [[0, 0], [17, 0], [17, 5], [13, 6], [13, 12], [10, 13], [10, 20], [8, 21], [8, 27], [9.5, 28], [9.5, 37],
      [5.5, 38], [5.5, 112], [8, 113], [8, 125], [5.5, 126], [5.5, 153], [9, 154], [9, 160], [6, 161], [6, 168], [9, 169],
      [9, 175], [4.5, 176], [1, 186], [0, 187]];
    { const g = new THREE.LatheGeometry(prof.map(([r, y]) => new THREE.Vector2(r, y)), 16);
      const m = add(g, "iron", "post"); m.position.set(PX, 0, PZ); }
    for (const y of [37, 125, 160]) { const g = new THREE.TorusGeometry(y === 125 ? 8 : 9.5, 0.9, 6, 20);   // the collars' lips
      const m = add(g, "ironLt", "post"); m.rotation.x = Math.PI / 2; m.position.set(PX, y, PZ); }

    // ---- the arm: out from under the top collar, over a curl, hooking down to the lantern
    const tube = (pts, r, mat, layer) => { const c = new THREE.CatmullRomCurve3(pts);
      return add(new THREE.TubeGeometry(c, 40, r, 6, false), mat, layer); };
    tube([V(26, yr(44), PZ), V(48, yr(39), PZ), V(72, yr(38), PZ), V(90, yr(41), PZ), V(94, yr(47), PZ), V(87, yr(52), PZ), V(86, yr(60), PZ)], 1.7, "iron", "post");
    tube([V(26, yr(66), PZ), V(34, yr(52), PZ), V(48, yr(48), PZ), V(64, yr(44), PZ)], 1.3, "iron", "post");   // the brace
    { const g = new THREE.TorusGeometry(6, 1.3, 6, 18, Math.PI * 1.6); const m = add(g, "iron", "post");       // the curl
      m.position.set(43, yr(61), PZ); m.rotation.z = 0.6; }

    // ---- the lantern: a pyramid hood with a knob, four glazed sides in a frame, a short tapered bottom
    const LX = 86, LZ = PZ;
    { const g = new THREE.ConeGeometry(17, 12, 4); const m = add(g, "iron", "lantern"); m.rotation.y = Math.PI / 4; m.position.set(LX, yr(66), LZ); }
    { const g = new THREE.SphereGeometry(2.4, 8, 6); const m = add(g, "ironLt", "lantern"); m.position.set(LX, yr(60), LZ); }
    { const g = new THREE.BoxGeometry(22, 26, 22); const m = add(g, "fireGlass", "lantern"); m.position.set(LX, yr(87), LZ); }
    for (const [sx, sz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {                       // the frame's corner posts
      const g = new THREE.BoxGeometry(3, 28, 3); const m = add(g, "iron", "lantern"); m.position.set(LX + sx * 11, yr(87), LZ + sz * 11); }
    for (const sx of [-1, 1]) { const g = new THREE.BoxGeometry(1.6, 26, 1.6); const m = add(g, "iron", "lantern");   // the glazing bars
      m.position.set(LX + sx * 3.5, yr(87), LZ + 11.2); }
    { const g = new THREE.BoxGeometry(26, 3, 26); const m = add(g, "ironLt", "lantern"); m.position.set(LX, yr(73), LZ); }
    { const g = new THREE.BoxGeometry(26, 3, 26); const m = add(g, "iron", "lantern"); m.position.set(LX, yr(101), LZ); }
    { const g = new THREE.ConeGeometry(9, 7, 4); const m = add(g, "iron", "lantern"); m.rotation.x = Math.PI; m.rotation.y = Math.PI / 4; m.position.set(LX, yr(106), LZ); }

    // ---- the banner bracket, and the banner: a cloth hung from it, swallow-tailed, a light trim down its edge
    { const g = new THREE.BoxGeometry(40, 3, 3); const m = add(g, "iron", "post"); m.position.set(46, yr(94), PZ + 4); }
    for (const x of [33, 58]) { const g = new THREE.SphereGeometry(2.4, 8, 6); const m = add(g, "ironLt", "post"); m.position.set(x, yr(94), PZ + 4); }
    { const pts = [[34, 97], [58, 97], [58, 140], [52, 132], [46, 140], [40, 132], [34, 140]];
      const sh = new THREE.Shape(pts.map(([x, r]) => new THREE.Vector2(x, yr(r))));
      const g = new THREE.ExtrudeGeometry(sh, { depth: 1.2, bevelEnabled: false }); const m = add(g, "banner", "banner"); m.position.z = PZ + 4.5; }
    { const sh = new THREE.Shape([[54, 98], [57, 98], [57, 137], [54, 134]].map(([x, r]) => new THREE.Vector2(x, yr(r))));
      const g = new THREE.ExtrudeGeometry(sh, { depth: 0.4, bevelEnabled: false }); const m = add(g, "trim", "banner"); m.position.z = PZ + 5.7; }
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
