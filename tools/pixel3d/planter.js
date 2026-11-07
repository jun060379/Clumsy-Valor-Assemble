// The planter built in code (owner 2026-11-07: 작은 소품). The reference sprite (assets/town/q_planter.png, 93 x 60,
// one cell per pixel) is only the guide. A plank box with a rim round its top, full of a low mound of leaves with pink
// flowers standing out of it. The leaves and flowers are deco* materials: no outline, as the town's grass and flowers.
// The town stands two, one the other way round: planterL is the same solid mirrored and lit by the same sun.
// Built as a real solid: world units, x right, y up from the ground (y = 0), z toward the viewer.

const PLANTER = (function () {
  const MIRROR = false;
  const W = 93, H = 70, B0 = 60, K = 0.12, TOP = 6;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    plank: ["wood", 5], plankDk: ["wood", 4], rim: ["wood", 6], soil: ["wood", 1],
    decoLeaf: ["leaf", 3], decoLeafDk: ["leaf", 2], decoBloom: ["violet", 5], decoBloomLt: ["red", 7],
  };
  const LAYERS = ["ground", "box", "leaves", "flowers"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    const cube = (layer, mat, x0, x1, y0, y1, z0, z1) => { const m = add(new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0), mat, layer);
      m.position.set((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2); return m; };
    let seed = 5;
    const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };

    // ---- the box: upright planks, a rim round the top, soil inside
    const Z0 = -20, Z1 = 0;
    // on the town's 2-px grid (CELL 2, owner 2026-11-08): the planks' edges on whole cells (2 units)
    const ev = (v) => Math.round(v / 2) * 2;
    for (let i = 0; i < 7; i++) { const a = ev(10 + i * 76 / 7), b = ev(10 + (i + 1) * 76 / 7);
      cube("box", i % 2 ? "plankDk" : "plank", a, b, 0, 22, Z0, Z1 + (i % 2 ? 0 : 1)); }
    cube("box", "plankDk", 10, 86, 0, 22, Z0 + 0.6, Z1 - 0.6);         // the box's body behind the planks: the joints
                                                                      // between them are dark wood, not holes through it
    cube("box", "rim", 6, 90, 22, 28, Z0 - 2, Z1 + 2);
    cube("box", "soil", 10, 86, 28, 30, Z0 + 1, Z1 - 1);

    // ---- the leaves: a low mound of small leafy clumps over the soil, spilling a little over the rim
    for (let i = 0; i < 46; i++) {
      const x = 6 + rnd() * 82, z = Z0 + 2 + rnd() * 18, hump = 1 - Math.pow((x - 47) / 46, 2);
      const r = 3 + rnd() * 3, y = 28 + 4 * hump + rnd() * 6;
      const g = new THREE.IcosahedronGeometry(r, 0); const m = add(g, rnd() < 0.35 ? "decoLeafDk" : "decoLeaf", "leaves");
      m.position.set(x, y, z); m.rotation.set(rnd() * 3, rnd() * 3, 0); m.scale.set(1.2, 0.7, 1);
    }
    // ---- the flowers: pink heads in loose clusters standing out of the leaves
    for (const [cx, cy, n] of [[22, 42, 9], [46, 47, 9], [70, 43, 9], [8, 34, 3], [87, 35, 3]]) {   // big round heads
      for (let i = 0; i < n; i++) {
        const a = rnd() * Math.PI * 2, d = rnd() * 6;
        const g = new THREE.IcosahedronGeometry(3 + rnd() * 1.5, 0);
        const m = add(g, rnd() < 0.3 ? "decoBloomLt" : "decoBloom", "flowers");
        m.position.set(cx + Math.cos(a) * d * 1.3, cy + Math.sin(a) * d, Z0 + 10 + rnd() * 8);
      }
    }
    if (MIRROR) {                                                    // reflect every part across the middle, keep faces outward
      const flip = new THREE.Matrix4().makeTranslation(W, 0, 0).multiply(new THREE.Matrix4().makeScale(-1, 1, 1));
      for (const p of parts) {
        const m = p.mesh; m.updateMatrix();
        let g = m.geometry.index ? m.geometry.toNonIndexed() : m.geometry;
        g.applyMatrix4(m.matrix); g.applyMatrix4(flip);
        const a = g.attributes.position.array;
        for (let i = 0; i < a.length; i += 9) for (let k = 0; k < 3; k++) { const t = a[i + 3 + k]; a[i + 3 + k] = a[i + 6 + k]; a[i + 6 + k] = t; }
        g.deleteAttribute("normal"); g.deleteAttribute("uv"); g.computeVertexNormals();
        m.geometry = g; m.position.set(0, 0, 0); m.rotation.set(0, 0, 0); m.quaternion.identity(); m.scale.set(1, 1, 1); m.updateMatrix();
      }
    }
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
