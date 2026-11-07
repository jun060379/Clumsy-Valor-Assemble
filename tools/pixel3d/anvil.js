// The anvil built in code (owner 2026-11-07: next -> 모루). The reference sprite (assets/town/hx/g_anvil.png, 90 x 74,
// at half size = 45 x 37 cells) is only the guide. An iron anvil - a flat face with a step at the heel, a horn
// tapering off to the left, a pinched waist, broad feet - sitting on a squared wooden block with its grain running up.
// Built as a real solid: world units, x right, y up from the ground (y = 0), z toward the viewer.

const ANVIL = (function () {
  const W = 46, H = 46, B0 = 37, K = 0.12, TOP = 4;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    block: ["wood", 5], grain: ["wood", 3], blockTop: ["wood", 6],
    iron: ["iron", 4], face: ["iron", 5], ironDk: ["iron", 3],
  };
  const LAYERS = ["ground", "block", "anvil"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    const cube = (layer, mat, x0, x1, y0, y1, z0, z1) => { const m = add(new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0), mat, layer);
      m.position.set((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2); return m; };

    // ---- the block: a squared length of trunk, the grain in shallow grooves up its face
    cube("block", "block", 5, 40, 0, 19, -24, 0);
    for (const x of [13, 21, 30, 36]) cube("block", "grain", x, x + 1, 1, 18, -0.4, 0.3);
    cube("block", "blockTop", 6, 39, 18.6, 19.2, -23, -1);                          // the sawn top

    // ---- the anvil: feet, waist, face with its heel step, the horn
    // ---- the anvil, its outline drawn side on and run back through its depth: broad feet flaring up into a pinched
    // waist, sloping shoulders out to the face, the heel square at the right, the horn's underside curving up to a
    // point at the left; the steel face a separate plate on top
    const ZA0 = -19, ZA1 = -5;
    const prof = [[1.5, 33.6], [9, 33.2], [12, 34], [40, 34], [43, 34], [43, 30.5], [40, 29.5], [35.5, 27.5], [33.5, 25],
      [34, 22.5], [37.5, 21], [38, 19], [7, 19], [7.5, 21], [11, 22.5], [12.5, 25], [11.5, 27.5], [8, 29.8], [4, 31.6]];
    { const sh = new THREE.Shape(prof.map(([x, y]) => new THREE.Vector2(x, y)));
      const g = new THREE.ExtrudeGeometry(sh, { depth: ZA1 - ZA0, bevelEnabled: false, curveSegments: 8 });
      const m = add(g, "iron", "anvil"); m.position.z = ZA0; }
    cube("anvil", "face", 12, 40, 34, 35.4, ZA0 + 0.5, ZA1 - 0.5);                   // the steel face
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
