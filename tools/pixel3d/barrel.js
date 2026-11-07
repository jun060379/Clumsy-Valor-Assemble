// The barrels built in code (owner 2026-11-07: 작은 소품). References: assets/town/q_barrelL.png (55 x 70),
// q_barrelM.png (54 x 65), q_barrelS.png (44 x 53), one cell per pixel. A coopered barrel: staves round a bulging
// body, a little gap between each showing dark, iron hoops near the ends and at the quarters, a sunk head with its
// chime round it. SIZE picks the reference (build.py barrelL / barrelM / barrelS).
// Built as a real solid: world units, x right, y up from the ground (y = 0), z toward the viewer.

const BARREL = (function () {
  const SIZE = "L";
  const DIM = { L: [55, 70, 26, 70], M: [54, 65, 25, 61], S: [44, 53, 20, 50] }[SIZE];   // W, H(ref), radius, height
  const W = DIM[0], H = DIM[1] + 8, B0 = DIM[1], K = 0.12, TOP = 4;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = { sand: ["ochre", 5], stave: ["wood", 5], staveLt: ["wood", 6], gap: ["wood", 2], hoop: ["iron", 3], head: ["wood", 6] };
  const LAYERS = ["ground", "barrel"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    const R = DIM[2], HT = DIM[3], CX = W / 2, CZ = -R;
    const rAt = (t) => R * (0.82 + 0.18 * Math.sin(Math.PI * t));   // the bulge
    const prof = (dr) => { const p = []; for (let k = 0; k <= 16; k++) { const t = k / 16; p.push(new THREE.Vector2(rAt(t) + dr, HT * t)); } return p; };
    { const g = new THREE.LatheGeometry(prof(-0.8), 32); const m = add(g, "gap", "barrel"); m.position.set(CX, 0, CZ); }   // dark under the staves
    const N = 10, gap = 0.028;
    for (let i = 0; i < N; i++) { const a0 = i / N * Math.PI * 2 + gap / 2, len = Math.PI * 2 / N - gap;
      const g = new THREE.LatheGeometry(prof(0), 4, a0, len); const m = add(g, i % 4 === 1 ? "staveLt" : "stave", "barrel"); m.position.set(CX, 0, CZ); }
    for (const t of [0.08, 0.3, 0.7, 0.92]) { const g = new THREE.TorusGeometry(rAt(t) + 0.5, 1.3, 6, 32); const m = add(g, "hoop", "barrel");
      m.rotation.x = Math.PI / 2; m.position.set(CX, HT * t, CZ); m.scale.set(1, 1, 1.2); }
    { const g = new THREE.CircleGeometry(rAt(1) - 2.5, 24); const m = add(g, "head", "barrel"); m.rotation.x = -Math.PI / 2; m.position.set(CX, HT - 1.5, CZ); }
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
