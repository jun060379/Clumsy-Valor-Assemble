// The training yard's fence built in code (owner 2026-11-07: 작은 소품). The reference sprite (assets/town/g_yard.png,
// 706 x 136, one cell per pixel) is only the guide. A post-and-three-rail fence, square posts with rounded caps, a pair
// of taller posts carrying an arch-topped double gate of planks with iron straps and ring pulls, and a straw training
// dummy at each end: a post with a cross arm, a bound straw body with a red sash, splayed feet.
// Built as a real solid: world units, x right, y up from the ground (y = 0; a ref row r stands at y = 136 - r), z
// toward the viewer.

const YARD = (function () {
  const W = 706, H = 142, B0 = 136, K = 0.12, TOP = 4;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    rail: ["wood", 5], post: ["wood", 5], cap: ["wood", 6], plank: ["wood", 5], plankGap: ["wood", 2],
    strap: ["iron", 4], ring: ["iron", 3], straw: ["cream", 5], strawDk: ["cream", 3], rope: ["wood", 3], sash: ["red", 3],
  };
  const LAYERS = ["ground", "fence", "gate", "dummies"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    const cube = (layer, mat, x0, x1, y0, y1, z0, z1) => { const m = add(new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0), mat, layer);
      m.position.set((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2); return m; };
    const R = (row) => 136 - row;                                    // a reference row as a height
    const V = (x, y, z) => new THREE.Vector3(x, y, z);
    const seg = (a, b, r, mat, layer) => { const g = new THREE.CylinderGeometry(r, r, a.distanceTo(b), 8); const m = add(g, mat, layer);
      m.position.copy(a.clone().add(b).multiplyScalar(0.5)); m.quaternion.setFromUnitVectors(V(0, 1, 0), b.clone().sub(a).normalize()); return m; };

    // ---- the rails: three, the whole length, behind the posts (the gate stands in their gap)
    for (const [r0, r1] of [[60, 73], [88, 100], [117, 129]]) for (const [a, b] of [[0, 304], [442, 706]])
      cube("fence", "rail", a, b, R(r1), R(r0), -4, -0.5);
    // ---- the posts: square, a rounded cap on each; the gate's pair taller
    const post = (a, b, top) => { cube("fence", "post", a, b, 0, R(top) - 4, -6, 2);
      cube("fence", "cap", a - 1.5, b + 1.5, R(top) - 8, R(top) - 4, -7, 3);       // the cap: a collar, and a round top on it
      const g = new THREE.CylinderGeometry((b - a) / 2 + 1.5, (b - a) / 2 + 1.5, 10, 20);
      const m = add(g, "cap", "fence"); m.rotation.x = Math.PI / 2; m.scale.set(1, 1, 0.45); m.position.set((a + b) / 2, R(top) - 8, -2); };
    for (const a of [143, 230, 497, 580, 663]) post(a, a + 20, 42);
    for (const a of [300, 428]) post(a, a + 18, 30);

    // ---- the gate: two leaves of upright planks under one round arch, iron straps across, a ring pull on each
    { const cx = 373, half = 55, spring = R(50), rise = 36;
      const top = (x) => spring + rise * Math.sqrt(Math.max(0, 1 - Math.pow((x - cx) / half, 2)));
      for (let x = 318, i = 0; x < 428; x += 9.2, i++) {
        const x1 = Math.min(x + 8.6, 428), h = top((x + x1) / 2);
        cube("gate", "plank", x, x1, 0, h, -3 + (i % 2 ? 0 : 0.4), 0);
        cube("gate", "plankGap", x - 0.6, x1 + 0.6, 0, h - 1.5, -4, -3); }         // dark behind the joints, under the arch
      { const pts = []; for (let i = 0; i <= 24; i++) { const x = cx - half + 2 * half * i / 24; pts.push(V(x, top(x) - 1, 0.6)); }   // the arch's rim
        add(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 48, 2.4, 6, false), "post", "gate"); }
      cube("gate", "plankGap", 372.6, 373.4, 0, top(cx) - 1, -0.2, 0.6);    // the meeting of the leaves
      for (const r of [[58, 70], [105, 115]]) for (const [a, b] of [[318, 368], [378, 428]]) cube("gate", "strap", a, b, R(r[1]), R(r[0]), 0, 1.2);
      for (const x of [358, 388]) { const g = new THREE.TorusGeometry(5, 1.2, 6, 14); const m = add(g, "ring", "gate"); m.position.set(x, R(86), 1.6); } }

    // ---- the dummies: a post with a cross arm, a bound straw body hung on it, a red sash, splayed feet
    const dummy = (px, side) => {                                     // side: which way the straw body hangs off the post
      cube("dummies", "post", px - 6, px + 6, 0, R(26), -10, -2);
      cube("dummies", "post", px - 18, px + 18, R(60), R(54), -8, -4);  // the cross arm
      for (const s of [-1, 1]) seg(V(px, R(110), -6), V(px + s * 22, 0.5, -6), 2.4, "post", "dummies");   // the feet
      const bx = px - side * 14;
      { const g = new THREE.CapsuleGeometry(11, 46, 4, 12); const m = add(g, "straw", "dummies"); m.position.set(bx, R(70), -2); }
      for (const r of [48, 72, 96]) { const g = new THREE.TorusGeometry(11.3, 1.1, 5, 16); const m = add(g, "rope", "dummies");
        m.rotation.x = Math.PI / 2; m.position.set(bx, R(r), -2); }
      seg(V(bx - side * 9, R(40), 6), V(bx + side * 4, R(104), 7), 2.6, "sash", "dummies");
    };
    dummy(84, 1);
    dummy(612, -1);
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
