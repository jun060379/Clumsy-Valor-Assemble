// The crates built in code (owner 2026-11-07: 작은 소품). References: assets/town/q_crateL.png (66 x 60),
// q_crateS.png (49 x 49), one cell per pixel. A nailed crate: a frame of thick boards round each face, upright planks
// inside it, a diagonal brace across the front, nail heads at the joints. SIZE picks the reference (build.py crateL /
// crateS). Built as a real solid: world units, x right, y up from the ground (y = 0), z toward the viewer.

const CRATE = (function () {
  const SIZE = "L";
  const DIM = { L: [66, 60, 50], S: [49, 49, 40] }[SIZE];         // W, H, depth
  const W = DIM[0] + 2, H = DIM[1] + 8, B0 = DIM[1], K = 0.12, TOP = 4;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = { sand: ["ochre", 5], frame: ["wood", 6], plank: ["wood", 5], gap: ["wood", 2], brace: ["wood", 6], nail: ["iron", 2] };
  const LAYERS = ["ground", "crate"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    const cube = (mat, x0, x1, y0, y1, z0, z1) => { const m = add(new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0), mat, "crate");
      m.position.set((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2); return m; };
    const [CW, CH, CD] = DIM, X0 = 1, X1 = 1 + CW, Z1 = 0, Z0 = -CD, F = Math.round(CW * 0.11);   // F: the frame boards' width
    cube("gap", X0 + 1, X1 - 1, 0, CH - 1, Z0 + 1, Z1 - 1);                         // the box behind
    const np = Math.max(3, Math.round((CW - 2 * F) / 9)), pw = (CW - 2 * F) / np;
    for (let i = 0; i < np; i++) cube(i % 2 ? "plank" : "frame", X0 + F + i * pw + 0.4, X0 + F + (i + 1) * pw - 0.4, F, CH - F, Z1 - 1.5, Z1 - 0.3);   // upright planks
    for (const [a, b, c, d] of [[X0, X1, 0, F], [X0, X1, CH - F, CH], [X0, X0 + F, 0, CH], [X1 - F, X1, 0, CH]]) cube("frame", a, b, c, d, Z1 - 1.5, Z1 + 0.3);   // the frame
    { const a = new THREE.Vector3(X0 + F, F + 1, Z1 - 0.2), b = new THREE.Vector3(X1 - F, CH - F - 1, Z1 - 0.2), len = a.distanceTo(b);   // the brace
      const m = cube("brace", -len / 2, len / 2, -F * 0.42, F * 0.42, -0.6, 0.6); m.position.copy(a.clone().add(b).multiplyScalar(0.5)); m.rotation.z = Math.atan2(b.y - a.y, b.x - a.x); }
    cube("frame", X0, X1, CH - 1.2, CH, Z0, Z1);                                     // the lid's edge boards
    for (const [x, y] of [[X0 + F / 2, F / 2], [X1 - F / 2, F / 2], [X0 + F / 2, CH - F / 2], [X1 - F / 2, CH - F / 2]]) cube("nail", x - 1, x + 1, y - 1, y + 1, Z1 + 0.6, Z1 + 1.2);
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
