// The plaza's paving built as a solid (owner 2026-11-08: "돌 바닥은 좀 모델링으로 할만해보이는데 요철이 있고 중세라 타일
// 기술이 높지도 않을거니까"): hand-laid field cobbles, each a low irregular block with rounded corners and its own
// height, set in packed dirt with uneven gaps, a row of long curb stones along the front showing their faces, the
// cobbles thinning out into the lawn at both ends. One unit a game px (CELL 2: on the town's 2-px grid).
// The plane: y = 0 the ground; the camera's tilt (K) turns depth into rows, so the town's 42 px of plane behind the
// stand line are 42 / K units deep. z: from -42/K (the plane's back edge) to +12/K (where the earth face begins).
// x: 0..920, the paving proper 40..880 (the hall's forecourt, HDOOR -/+ 420), the ends 40 px over the lawn.

const PAVING = (function () {
  const W = 920, K = 0.12, B0 = 42, TOP = 4, H = 62;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = { sand: ["ochre", 5], dirt: ["wood", 2], cobble: ["stone", 6], cobbleLt: ["stone", 7], cobbleDk: ["stone", 5], curb: ["stone", 7], moss: ["leaf", 3] };
  const LAYERS = ["ground", "cobbles", "curb"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    let seed = 7;
    const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
    const ZB = -42 / K, ZF = 12 / K, X0 = 40, X1 = 880;
    // a cobble: an irregular rounded outline in x-z (z in rows, scaled by 1/K), raised h units
    const cobble = (cx, cz, w, d, h, mat) => {
      const pts = [], n = 10;
      for (let i = 0; i < n; i++) {
        const a = i / n * Math.PI * 2, j = 0.82 + rnd() * 0.22;
        const cx2 = Math.cos(a), sz2 = Math.sin(a);
        // a squarish rounded outline (superellipse), each corner pushed a little
        const sx = Math.sign(cx2) * Math.pow(Math.abs(cx2), 0.5), sz = Math.sign(sz2) * Math.pow(Math.abs(sz2), 0.5);
        pts.push(new THREE.Vector2(sx * w / 2 * j, sz * d / 2 * j));
      }
      const g = new THREE.ExtrudeGeometry(new THREE.Shape(pts), { depth: h, bevelEnabled: true, bevelThickness: 0.8, bevelSize: 1.6, bevelSegments: 1 });
      g.rotateX(-Math.PI / 2);                              // extrude up: shape x-y -> x-(-z)
      const m = add(g, mat, "cobbles"); m.position.set(cx, 0, cz); return m;
    };
    // the dirt they are set in: under the paving, ragged at the ends
    { const g = new THREE.PlaneGeometry(X1 - X0 - 40, ZF - ZB); g.rotateX(-Math.PI / 2);
      const m = add(g, "dirt", "ground"); m.position.set((X0 + X1) / 2, 0, (ZB + ZF) / 2); }
    const bed = (cx, cz, w, d) => {                          // the dirt round a stone near the ends (no straight cut)
      const g = new THREE.CircleGeometry(1, 12); g.rotateX(-Math.PI / 2); const m = add(g, "dirt", "ground");
      m.scale.set(w / 2 + 3, 1, d / 2 + 2 / K); m.position.set(cx, 0.01, cz); };
    // courses from the back (rows on screen): a little lower at the back (owner 2026-11-08: "돌은 너무 작아지는 게 가파른듯")
    const rows = [4, 6, 6, 6, 6, 6, 6];                      // px of plane per course, back to front (the curb takes the rest)
    let r = 0;
    for (let ci = 0; ci < rows.length; ci++) {
      const z0 = ZB + r / K, z1 = ZB + (r + rows[ci]) / K, cz = (z0 + z1) / 2, d = (z1 - z0) - 1.6 / K;
      let x = X0 - 40 + rnd() * 10;
      while (x < X1 + 40) {
        const w = (ci < 2 ? 12 : 14) + rnd() * 8, cx = x + w / 2;
        // the ends: thinning out into the lawn, the stones there sparser and sunk
        const edge = Math.min(cx - (X0 - 40), (X1 + 40) - cx) / 40;
        if (edge < 1 && rnd() > edge * 0.9) { x += w + 2; continue; }
        if (Math.min(cx - X0, X1 - cx) < 30) bed(cx, cz, w, d);
        const t = rnd(), mat = t < 0.22 ? "cobbleLt" : t < 0.36 ? "cobbleDk" : "cobble";
        cobble(cx, cz + (rnd() - 0.5) * 0.3 / K, w - 3 - rnd() * 1.5, d, (edge < 1 ? 0.6 : 1.0) + rnd() * 1.2, mat);
        if (rnd() < 0.07) { const g = new THREE.BoxGeometry(2, 1.2, d * 0.5); const m = add(g, "moss", "cobbles"); m.position.set(x + w - 1, 0.6, cz); }
        x += w + 0.5 + rnd() * 1.5;
      }
      r += rows[ci];
    }
    // the curb along the front: long dressed stones, their faces showing down to the earth face
    { let x = X0 + rnd() * 6;
      const zc0 = ZB + r / K, zc1 = ZF;
      while (x < X1 - 4) {
        const w = Math.min(X1 - x, 26 + rnd() * 14);
        const g = new THREE.BoxGeometry(w - 1.5, 5 + rnd() * 1.5, zc1 - zc0 - 0.8 / K); const m = add(g, "curb", "curb");
        m.position.set(x + w / 2, 2.5, (zc0 + zc1) / 2); x += w;
      } }
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
