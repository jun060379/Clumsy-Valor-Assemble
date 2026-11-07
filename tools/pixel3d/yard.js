// The training yard's fence built in code (owner 2026-11-07: 작은 소품). The reference sprite (assets/town/g_yard.png,
// 706 x 136, one cell per pixel) is only the guide. A post-and-three-rail fence, square posts with rounded caps, a pair
// of taller posts carrying an arch-topped double gate of planks with iron straps and ring pulls. (The reference's straw dummies at the ends are left out.)
// Built as a real solid: world units, x right, y up from the ground (y = 0; a ref row r stands at y = 136 - r), z
// toward the viewer.

const YARD = (function () {
  const W = 706, H = 142, B0 = 136, K = 0.12, TOP = 4;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    rail: ["wood", 5], post: ["wood", 5], cap: ["wood", 6], plank: ["wood", 5], plankGap: ["wood", 2],
    strap: ["iron", 4], ring: ["iron", 3], nail: ["iron", 2], grain: ["wood", 3], farRail: ["stone", 5], farPost: ["stone", 4], straw: ["cream", 5], strawDk: ["cream", 3], rope: ["wood", 3], sash: ["red", 3],
  };
  const LAYERS = ["ground", "far", "fence", "gate", "dummies"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    const cube = (layer, mat, x0, x1, y0, y1, z0, z1) => { const m = add(new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0), mat, layer);
      m.position.set((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2); return m; };
    const R = (row) => 136 - row;                                    // a reference row as a height
    const V = (x, y, z) => new THREE.Vector3(x, y, z);
    const seg = (a, b, r, mat, layer) => { const g = new THREE.CylinderGeometry(r, r, a.distanceTo(b), 8); const m = add(g, mat, layer);
      m.position.copy(a.clone().add(b).multiplyScalar(0.5)); m.quaternion.setFromUnitVectors(V(0, 1, 0), b.clone().sub(a).normalize()); return m; };

    let seed = 13;
    const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
    // (owner 2026-11-07: "울타리 좌우 대칭 너비 맞추기") everything laid out from the gate's middle, C = W / 2: the same
    // posts at the same distances either side
    const C = W / 2, GH = 55;                                         // the gate's middle, its half width
    const POSTS = [150, 237, 324];                                    // the fence posts' distances from C
    // (owner 2026-11-07: "전반적으로 텍스쳐 부여") texture carried by shape, never speckle: grain as shallow grooves of
    // uneven length, a knot now and then, nail heads where rails meet posts and along the gate's straps
    const groove = (layer, x0, x1, y0, y1, z) => cube(layer, "grain", x0, x1, y0, y1, z - 0.3, z + 0.25);

    // ---- the rails: three, the whole length, behind the posts (the gate stands in their gap)
    for (const [r0, r1] of [[60, 73], [88, 100], [117, 129]]) for (const [a, b] of [[0, C - GH - 14], [C + GH + 14, W]]) {
      cube("fence", "rail", a, b, R(r1), R(r0), -4, -0.5);
      for (let k = 0; k < 3; k++) { const x0 = a + rnd() * (b - a - 40), len = 18 + rnd() * 30, y = R(r1) + 3 + rnd() * (R(r0) - R(r1) - 6);
        groove("fence", x0, Math.min(x0 + len, b - 2), y, y + 0.9, -0.5); }
    }
    // ---- the posts: square, a rounded cap on each; the gate's pair taller
    const post = (a, b, top) => { cube("fence", "post", a, b, 0, R(top) - 4, -6, 2);
      cube("fence", "cap", a - 1.5, b + 1.5, R(top) - 8, R(top) - 4, -7, 3);       // the cap: a collar, and a round top on it
      const g = new THREE.CylinderGeometry((b - a) / 2 + 1.5, (b - a) / 2 + 1.5, 10, 20);
      const m = add(g, "cap", "fence"); m.rotation.x = Math.PI / 2; m.scale.set(1, 1, 0.45); m.position.set((a + b) / 2, R(top) - 8, -2);
      for (let k = 0; k < 2; k++) { const x = a + 4 + rnd() * (b - a - 8), y0 = 4 + rnd() * 30, len = 30 + rnd() * 40;
        groove("fence", x, x + 0.9, y0, Math.min(y0 + len, R(top) - 12), 2); }
      if (rnd() < 0.5) cube("fence", "grain", (a + b) / 2 - 2, (a + b) / 2 + 1, 40 + rnd() * 30, 42.5 + rnd() * 30, 2, 2.4);   // a knot
      for (const r of [66, 94, 123]) cube("fence", "nail", (a + b) / 2 - 1, (a + b) / 2 + 1, R(r) - 1, R(r) + 1, 2, 2.6);       // nail heads
    };
    for (const d of POSTS) { post(C - d - 10, C - d + 10, 42); post(C + d - 10, C + d + 10, 42); }
    post(C - GH - 18, C - GH, 30); post(C + GH, C + GH + 18, 30);

    // ---- the gate: two leaves of upright planks under one round arch, iron straps across, a ring pull on each
    { const cx = C, half = GH, spring = R(50), rise = 36;
      const top = (x) => spring + rise * Math.sqrt(Math.max(0, 1 - Math.pow((x - cx) / half, 2)));
      for (let x = C - GH, i = 0; x < C + GH - 0.5; x += 110 / 12, i++) {
        const x1 = Math.min(x + 110 / 12 - 0.6, C + GH), h = top((x + x1) / 2), zf = i % 2 ? 0 : 0.4;
        cube("gate", "plank", x, x1, 0, h, -3 + zf, 0);
        cube("gate", "plankGap", x - 0.6, x1 + 0.6, 0, h - 1.5, -4, -3);          // dark behind the joints, under the arch
        const gy = 6 + rnd() * 30; groove("gate", (x + x1) / 2 - 0.4, (x + x1) / 2 + 0.5, gy, Math.min(gy + 25 + rnd() * 30, h - 6), zf); }
      { const pts = []; for (let i = 0; i <= 24; i++) { const x = cx - half + 2 * half * i / 24; pts.push(V(x, top(x) - 1, 0.6)); }   // the arch's rim
        add(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 48, 2.4, 6, false), "post", "gate"); }
      cube("gate", "plankGap", C - 0.4, C + 0.4, 0, top(cx) - 1, -0.2, 0.6);   // the meeting of the leaves
      for (const r of [[58, 70], [105, 115]]) for (const [a, b] of [[C - GH, C - 5], [C + 5, C + GH]]) {
        cube("gate", "strap", a, b, R(r[1]), R(r[0]), 0, 1.2);
        for (let x = a + 4; x < b - 2; x += 10) cube("gate", "nail", x, x + 2, (R(r[1]) + R(r[0])) / 2 - 1, (R(r[1]) + R(r[0])) / 2 + 1, 1.2, 1.8); }
      for (const x of [C - 15, C + 15]) { const g = new THREE.TorusGeometry(5, 1.2, 6, 14); const m = add(g, "ring", "gate"); m.position.set(x, R(86), 1.6); } }

    // ---- the far fence (owner 2026-11-07: "좀 더 짙고 낮은 채도로 저 너머에 원경 울타리 깔기"): the same fence on the
    // yard's far side, plain, in darker, duller colours (the distance takes the warmth out)
    { const ZF = -96;
      for (const [r0, r1] of [[50, 58], [80, 88]]) cube("far", "farRail", 0, W, R(r1), R(r0), ZF - 3, ZF);
      for (let d = 0; d <= C + 1; d += 87) for (const x of d ? [C - d, C + d] : [C]) {
        cube("far", "farPost", x - 8, x + 8, 0, R(46), ZF - 5, ZF + 2);
        cube("far", "farPost", x - 9.5, x + 9.5, R(46), R(42), ZF - 6, ZF + 3); } }

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
    // (owner 2026-11-07: "양옆에 있는 허수아비 빼자") the dummies are left out
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
