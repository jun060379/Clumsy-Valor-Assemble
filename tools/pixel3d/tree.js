// The town's trees built as solids (owner 2026-11-08: "나무나 풀 같은 자연물 리모델링 해보자"), lit by the same sun as
// the buildings. A trunk that flares into roots, splitting into limbs that split again, and the crown as clumps of
// leaf balls at the twig ends (each clump a few overlapping lumps). The trunk and limbs never move; the game splits a
// render by colour into the wood (fixed) and the leaves (they sway) - AGENTS.md 나무: 줄기·가지는 고정, 잎만 흔든다.
// VARIANT picks the tree (sizes mixed, none a copy of a reference). One unit a cell (2 px), as the buildings.
const VARIANT = "oak";
const TREE = (function () {
  const V = {
    // crown: an ellipsoid (centre height, radii x y z) covered in leaf lumps; lumps: how many; leaf: lump radius
    oak:   { W: 190, H: 140, trunk: 11, fork: 34, limbs: 4, spread: 0.95, reach: 46, rise: 30, crown: [88, 84, 46, 30], lumps: 46, leaf: [10, 14], seed: 3 },
    round: { W: 140, H: 150, trunk: 8, fork: 40, limbs: 3, spread: 0.6, reach: 30, rise: 40, crown: [98, 62, 50, 34], lumps: 40, leaf: [10, 13], seed: 7 },
    young: { W: 80, H: 122, trunk: 4, fork: 52, limbs: 3, spread: 0.55, reach: 18, rise: 28, crown: [92, 32, 26, 18], lumps: 22, leaf: [6, 8], seed: 11 },
    tall:  { W: 70, H: 168, trunk: 5.5, fork: 34, limbs: 4, spread: 0.3, reach: 12, rise: 70, crown: [104, 28, 62, 22], lumps: 32, leaf: [7, 9], seed: 19 },
  }[VARIANT];
  const W = V.W, H = V.H, B0 = H - 4, K = 0.12, TOP = 4;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = { sand: ["ochre", 5], bark: ["wood", 5], barkDk: ["wood", 4], leaf: ["leaf", 4], leafDk: ["green", 4], leafLt: ["leaf", 5] };
  const LAYERS = ["ground", "wood", "leaves"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    const P = (x, y, z) => new THREE.Vector3(x, y, z);
    let seed = V.seed;
    const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
    const r = (a, b) => a + rnd() * (b - a);
    // a limb: a tapered round from a to b
    const limb = (a, b, r0, r1, mat = "bark") => {
      const g = new THREE.CylinderGeometry(r1, r0, a.distanceTo(b), 8);
      const m = add(g, mat, "wood");
      m.position.copy(a.clone().add(b).multiplyScalar(0.5));
      m.quaternion.setFromUnitVectors(P(0, 1, 0), b.clone().sub(a).normalize());
      return m;
    };
    const CX = W / 2, CZ = -10;
    // a leaf lump: a ball with its surface pushed in and out at random (a leafy, broken edge, not a smooth bubble)
    const lump = (rad) => {
      const g = new THREE.IcosahedronGeometry(rad, 2), pos = g.attributes.position, key = new Map();
      for (let k = 0; k < pos.count; k++) {
        const id = `${pos.getX(k).toFixed(3)},${pos.getY(k).toFixed(3)},${pos.getZ(k).toFixed(3)}`;
        if (!key.has(id)) key.set(id, r(0.78, 1.12));
        const f = key.get(id);
        pos.setXYZ(k, pos.getX(k) * f, pos.getY(k) * f, pos.getZ(k) * f);
      }
      g.computeVertexNormals(); return g;
    };
    // the trunk, a little bent, flaring into roots at the foot
    const base = P(CX, 0, CZ), fork = P(CX + r(-3, 3), V.fork, CZ + r(-2, 2));
    limb(base, fork, V.trunk, V.trunk * 0.72);
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * Math.PI * 2 + r(-0.3, 0.3);
      const out = P(CX + Math.cos(a) * V.trunk * 1.9, 0, CZ + Math.sin(a) * V.trunk * 1.2);
      limb(P(CX, V.trunk * 1.6, CZ), out, V.trunk * 0.45, V.trunk * 0.22, "barkDk");
    }
    // limbs out of the fork, each splitting once into twigs; a clump of leaves at every twig end
    const ends = [];
    for (let i = 0; i < V.limbs; i++) {
      const t = V.limbs === 1 ? 0 : i / (V.limbs - 1) - 0.5;
      const ang = t * 2 * V.spread * 1.3 + r(-0.15, 0.15);
      const len = V.reach * r(0.75, 1.05);
      const tip = P(fork.x + Math.sin(ang) * len, fork.y + V.rise * r(0.7, 1.0) * (1 - Math.abs(t) * 0.5), fork.z + r(-8, 8));
      limb(fork, tip, V.trunk * 0.62, V.trunk * 0.32);
      for (let j = 0; j < 2; j++) {
        const a2 = ang + (j ? 0.5 : -0.5) * V.spread;
        const l2 = len * r(0.35, 0.5);
        const tw = P(tip.x + Math.sin(a2) * l2, tip.y + l2 * r(0.4, 0.8), tip.z + r(-8, 8));
        limb(tip, tw, V.trunk * 0.3, V.trunk * 0.16);
        ends.push(tw);
      }
      ends.push(tip.clone().add(P(0, V.crown[0] * 0.6, 0)));
    }
    // the crown: an ellipsoid filled with a few big leaf masses and covered with many small lumps (low-poly, so each
    // lump breaks into lit and shaded facets - leaf clusters, not smooth balls); the lower lumps a darker green
    const [cy, rx, ry, rz] = V.crown, C = P(CX, cy, CZ);
    // the inside filled with lumps of the same leaf (no one dark mass showing through the gaps)
    for (let i = 0; i < Math.round(V.lumps * 0.6); i++) {
      const m = add(lump(r(V.leaf[0], V.leaf[1]) * 1.15), "leafDk", "leaves");
      m.position.copy(C.clone().add(P(r(-0.6, 0.6) * rx, r(-0.5, 0.4) * ry, r(-0.5, 0.5) * rz)));
      m.scale.set(1, 0.85, 0.9);
    }
    for (let i = 0; i < V.lumps; i++) {
      // a point on the ellipsoid, the upper part favoured (the crown's underside is mostly hidden and in shade)
      const u = r(-0.55, 1), th = r(0, Math.PI * 2), q = Math.sqrt(1 - u * u);
      const d = P(Math.cos(th) * q, u, Math.sin(th) * q);
      const p = C.clone().add(P(d.x * rx, d.y * ry, d.z * rz).multiplyScalar(r(0.72, 0.9)));
      const m = add(lump(r(V.leaf[0], V.leaf[1])), u < -0.2 ? "leafDk" : "leaf", "leaves");
      m.position.copy(p); m.scale.set(1, r(0.8, 0.92), r(0.85, 1)); m.rotation.set(r(0, 3), r(0, 3), r(0, 3));
    }
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
