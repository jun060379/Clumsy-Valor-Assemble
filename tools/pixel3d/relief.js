// A relief built from a picture (tools/pixel3d/tree_relief.py writes DATA: per pixel a material code and a height):
// each pixel a flat top at its height, with walls down to its lower neighbours, so the parts stand apart in depth and
// the viewer's light and outlines read them. One unit a game px (CELL 2). y up from the picture's bottom row.
const DATA = null;
const RELIEF = (function () {
  // MX: room either side for a low sun's long shadow (cards: their shadow is all they are for); below the foot, the
  // ground the shadow lies on
  const MX = DATA.card ? 160 : 0;
  const W = DATA.w + 2 * MX, H = DATA.h + (DATA.card ? 70 : 6), B0 = DATA.h, K = 0.12, TOP = 4;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = { sand: ["ochre", 5], bark: ["wood", 5], barkDk: ["wood", 3], leaf: ["leaf", 4], leafDk: ["leaf", 3], barkLt: ["wood", 6], leafLt: ["leaf", 5] };
  const LAYERS = ["ground", "wood", "leaves"];
  const NAMES = [null, "bark", "barkDk", "leaf", "leafDk", "barkLt", "leafLt"];
  function build(THREE) {
    const parts = [];
    const w = DATA.w, h = DATA.h, M = DATA.mat, Z = DATA.z;
    const at = (x, y) => (x < 0 || y < 0 || x >= w || y >= h) ? 0 : +M[y * w + x];
    const zz = (x, y) => Z[y * w + x] / 4;
    for (let code = 1; code <= 6; code++) {
      const pos = [];
      const quad = (a, b, c, d) => pos.push(...a, ...b, ...c, ...a, ...c, ...d);
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
        if (+M[y * w + x] !== code) continue;
        const z = zz(x, y), X0 = x, X1 = x + 1, Y1 = h - y, Y0 = h - y - 1;
        // a corner's height: the mean of the pixels of the same part round it, so a part's face is one smooth surface
        // (a dome turns its slopes to the light) while different parts stay apart
        const cz = (cx, cy) => { let s = 0, k = 0;
          for (const [px, py] of [[cx - 1, cy - 1], [cx, cy - 1], [cx - 1, cy], [cx, cy]]) if (at(px, py) === code) { s += zz(px, py); k++; }
          return k ? s / k : z; };
        quad([X0, Y0, cz(x, y + 1)], [X1, Y0, cz(x + 1, y + 1)], [X1, Y1, cz(x + 1, y)], [X0, Y1, cz(x, y)]);   // the face toward us
        // walls down to a lower (or empty) neighbour on each side, so nothing behind shows through the step
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          const n = at(x + dx, y + dy), zn = n ? zz(x + dx, y + dy) : 0;
          if (n === code || zn >= z - 0.25) continue;
          if (dx === 1) quad([X1, Y0, z], [X1, Y0, zn], [X1, Y1, zn], [X1, Y1, z]);
          if (dx === -1) quad([X0, Y0, zn], [X0, Y0, z], [X0, Y1, z], [X0, Y1, zn]);
          if (dy === -1) quad([X0, Y1, z], [X1, Y1, z], [X1, Y1, zn], [X0, Y1, zn]);    // the top edge
          if (dy === 1) quad([X0, Y0, zn], [X1, Y0, zn], [X1, Y0, z], [X0, Y0, z]);     // the bottom edge
        }
      }
      if (!pos.length) continue;
      const g = new THREE.BufferGeometry();
      g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
      g.computeVertexNormals();
      const m = new THREE.Mesh(g);
      m.position.z = DATA.card ? -DATA.depth / 2 : -20; m.position.x = MX;   // a card or a relief's shadow: centred on the stand line
      parts.push({ mesh: m, mat: NAMES[code], layer: (code <= 2 || code === 5) ? "wood" : "leaves" });
    }
    return parts;
  }
  // a card's shadow lies on the town's whole ground plane: 42 px behind the stand line (town.gd RAISE), 30 in front
  const GROUND = DATA.card ? [42, 30] : null;
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, GROUND, build };
})();
