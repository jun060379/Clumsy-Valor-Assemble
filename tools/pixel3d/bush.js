// The bushes built in code (owner 2026-11-08: "O는 넣고 X는 코드로 만들라고 건물 만든 것 처럼"), after the bush
// design the owner picked (grass_numbered.png row 3: two or three rounded masses, each a cloud of leaf lobes, cool
// greens, the lawn's light on the tops). References: assets/town/f_bush1.png (129 x 84), f_bush2 (98 x 71),
// f_bush3 (81 x 56), one cell per pixel. SIZE picks one (build.py bushL / bushM / bushS).
// Built as a real solid: world units, x right, y up from the ground (y = 0), z toward the viewer.

const BUSH = (function () {
  const SIZE = "L";
  const DIM = { L: [129, 84], M: [98, 71], S: [81, 56] }[SIZE];
  const W = DIM[0], H = DIM[1] + 8, B0 = DIM[1], K = 0.12, TOP = 4;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  // the lower lobes and the heart in the cool green ramp, the upper lobes in the lawn's leaf ramp (the design's light tops)
  const MAT = { sand: ["ochre", 5], leaf: ["green", 5], leafTop: ["leaf", 5], leafIn: ["green", 3], stem: ["wood", 3] };
  const LAYERS = ["ground", "bush"];
  // the masses: [x of the middle (share of W), radius (share of H), height of the middle (share of the radius)]
  const MASSES = {
    L: [[0.27, 0.44, 1.0], [0.56, 0.5, 1.0], [0.8, 0.38, 1.0]],
    M: [[0.33, 0.46, 1.0], [0.68, 0.4, 1.0]],
    S: [[0.5, 0.5, 1.0]],
  }[SIZE];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    let seed = { L: 17, M: 23, S: 31 }[SIZE];
    const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
    const HT = DIM[1] - 2, CZ = -HT * 0.45;
    for (const [mx, mr] of MASSES) {
      const r = HT * mr * 0.9, cx = W * mx, cy = r * 0.92, cz = CZ + (rnd() - 0.5) * 6;
      // the mass's dark heart, so the gaps between lobes read deep
      { const g = new THREE.SphereGeometry(r * 0.9, 16, 12); const m = add(g, "leafIn", "bush"); m.position.set(cx, cy, cz); m.scale.set(1.15, 1.0, 0.85); }
      // the lobes: round leaf clumps (smooth balls: clean light bands, no speckle) packed over the top and the front, so
      // the edge breaks into a scalloped line and the face into clusters (the design's cloud edge)
      const n = Math.round(14 + r * 0.2);
      for (let i = 0; i < n; i++) {
        const th = Math.PI * (0.08 + 0.84 * ((i * 0.618) % 1)), ph = 0.1 + (i / n) * 1.75 + rnd() * 0.12;    // the front half, top to foot
        const dx = Math.sin(ph) * Math.cos(th) * (i % 2 ? 1 : -1), dy = Math.cos(ph), dz = Math.sin(ph) * Math.sin(th);
        const lr = r * (0.27 + rnd() * 0.07);
        const g = new THREE.SphereGeometry(lr, 12, 9); const m = add(g, dy > 0.2 ? "leafTop" : "leaf", "bush");
        m.position.set(cx + dx * r * 0.92, Math.max(lr * 0.9, cy + dy * r * 0.85), cz + dz * r * 0.75);
      }
    }
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
