// The flower pot built in code (owner 2026-11-07: 작은 소품). The reference sprite (assets/town/q_pot.png, 59 x 69,
// one cell per pixel) is only the guide. A clay pot turned round - a rolled rim, a body tapering to a little foot -
// holding a bushy plant with big pink flowers and peach buds over the top. Leaves and flowers are deco* materials: no
// outline. Built as a real solid: world units, x right, y up from the ground (y = 0), z toward the viewer.

const POT = (function () {
  const W = 60, H = 76, B0 = 69, K = 0.12, TOP = 4;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    clay: ["red", 4], clayRim: ["red", 5], soil: ["wood", 1],
    decoLeaf: ["leaf", 3], decoLeafDk: ["leaf", 2], decoBloom: ["violet", 5], decoBloomLt: ["red", 7], decoBud: ["ochre", 3],
  };
  const LAYERS = ["ground", "pot", "leaves", "flowers"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    let seed = 9;
    const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
    const CX = 30, CZ = -14;

    // ---- the pot: a turned profile - foot, tapering body, a rolled rim
    { const prof = [[0, 0], [12, 0], [12, 2], [13, 3], [16, 20], [16.5, 21], [19, 21.5], [19.5, 24], [19, 26.5], [16, 27], [15, 26]];
      const g = new THREE.LatheGeometry(prof.map(([r, y]) => new THREE.Vector2(r, y)), 20); const m = add(g, "clay", "pot"); m.position.set(CX, 0, CZ); }
    { const g = new THREE.TorusGeometry(18.2, 1.9, 6, 24); const m = add(g, "clayRim", "pot"); m.rotation.x = Math.PI / 2; m.position.set(CX, 24, CZ); }
    { const g = new THREE.CircleGeometry(15.5, 20); const m = add(g, "soil", "pot"); m.rotation.x = -Math.PI / 2; m.position.set(CX, 25, CZ); }

    // ---- the plant: a bushy mound of leafy clumps over the rim
    for (let i = 0; i < 60; i++) {
      const a = rnd() * Math.PI * 2, d = rnd(), x = CX + Math.cos(a) * d * 25, z = CZ + Math.sin(a) * d * 12 + 3;
      const y = 25 + (1 - d * d) * 17 + rnd() * 5, r = 3 + rnd() * 3;
      const g = new THREE.IcosahedronGeometry(r, 0); const m = add(g, rnd() < 0.35 ? "decoLeafDk" : "decoLeaf", "leaves");
      m.position.set(x, y, z); m.rotation.set(rnd() * 3, rnd() * 3, 0); m.scale.set(1.1, 0.75, 1);
    }
    // ---- the bud stalks: long leaves standing up out of the bush, each carrying a bud at its tip
    for (const [x0, x1, top] of [[22, 14, 52], [38, 46, 52], [30, 30, 59]]) for (let k = 0; k < 4; k++) {
      const t = k / 3, g = new THREE.IcosahedronGeometry(2.6, 0); const m = add(g, k % 2 ? "decoLeafDk" : "decoLeaf", "leaves");
      m.position.set(x0 + (x1 - x0) * t, 42 + (top - 42) * t, CZ + 2); m.scale.set(0.8, 1.6, 0.8); }
    // ---- the flowers: two big pink heads at the front, peach buds standing up out of the top
    const head = (cx, cy, cz, n, rr, mats) => { for (let i = 0; i < n; i++) { const a = rnd() * Math.PI * 2, d = rnd() * rr;
      const g = new THREE.IcosahedronGeometry(2.6 + rnd() * 1.2, 0); const m = add(g, mats[rnd() < 0.3 ? 1 : 0], "flowers");
      m.position.set(cx + Math.cos(a) * d * 1.2, cy + Math.sin(a) * d, cz + rnd() * 3); } };
    head(20, 42, CZ + 10, 9, 6, ["decoBloom", "decoBloomLt"]);
    head(40, 42, CZ + 10, 9, 6, ["decoBloom", "decoBloomLt"]);
    head(14, 55, CZ + 2, 4, 3, ["decoBud", "decoBloomLt"]);
    head(46, 55, CZ + 2, 4, 3, ["decoBud", "decoBloomLt"]);
    head(30, 62, CZ + 2, 5, 3.5, ["decoBud", "decoBloomLt"]);
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
