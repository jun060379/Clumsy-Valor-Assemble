// The campfire built in code (owner 2026-11-07: 작은 소품). The reference sprite (assets/town/g_ring.png, 109 x 63, one
// cell per pixel) is only the guide. A ring of rounded stones round split logs laid low across each other; the fire is
// the pixelfx effect the town lays over it (town.gd starts its flames at the old teepee's apex, (54, 1): with the
// logs low that start must come down to the top of the pile when this goes in). Built as a real solid: world units, x right, y up from the ground (y = 0), z toward the viewer.

const RING = (function () {
  const W = 109, H = 70, B0 = 63, K = 0.12, TOP = 2;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    stone: ["cream", 3], stoneLt: ["cream", 4], log: ["wood", 4], logLt: ["wood", 5], ash: ["stone", 5], char: ["stone", 2],
  };
  const LAYERS = ["ground", "stones", "logs"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    const V = (x, y, z) => new THREE.Vector3(x, y, z);
    let seed = 3;
    const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
    const CX = 54, CZ = -16, APEX = null;

    // ---- the hearth: ash on the ground inside the ring
    { const g = new THREE.CircleGeometry(30, 24); const m = add(g, "ash", "stones"); m.rotation.x = -Math.PI / 2; m.position.set(CX, 0.2, CZ); }
    // ---- the stones (owner 2026-11-07: "돌 너무 둥글기만 한거랑 가운데 빈것만 어캐 해봐"): field stones, not balls - a
    // few broad flat faces each, wider than tall, a flattish top, sat flat on the ground; one stands at the front middle so the ring has no gap
    const rock = (x, y, z, sx, sy, sz, rot, mat) => {
      const g = new THREE.IcosahedronGeometry(1, 0), pos = g.attributes.position, key = new Map();
      for (let k = 0; k < pos.count; k++) {
        const id = [pos.getX(k), pos.getY(k), pos.getZ(k)].map(v => v.toFixed(3)).join();
        if (!key.has(id)) key.set(id, [0.8 + rnd() * 0.35, 0.8 + rnd() * 0.35, 0.8 + rnd() * 0.35]);
        const [a, b, c] = key.get(id); pos.setXYZ(k, pos.getX(k) * a, Math.max(Math.min(pos.getY(k) * b, 0.55), -0.25), pos.getZ(k) * c);
      }
      g.computeVertexNormals(); const m = add(g, mat, "stones"); m.scale.set(sx, sy, sz); m.rotation.y = rot; m.position.set(x, y, z);
    };
    for (let i = 0; i < 12; i++) {
      const a = i / 12 * Math.PI * 2 + Math.PI / 2, r = 42;
      rock(CX + Math.cos(a) * r, 3.4, CZ + Math.sin(a) * r * 0.75, 11 + rnd() * 3, 13 + rnd() * 3, 9 + rnd() * 2, -a + rnd() * 0.6, rnd() < 0.3 ? "stoneLt" : "stone");
    }
    // the middle: a low heap of ash under the logs, charred chunks in it
    { const g = new THREE.SphereGeometry(1, 14, 6, 0, Math.PI * 2, 0, Math.PI / 2); const m = add(g, "ash", "stones");
      m.scale.set(24, 7, 16); m.position.set(CX, 0, CZ); }
    for (let i = 0; i < 7; i++) { const a = rnd() * Math.PI * 2, d = rnd() * 16;
      const g = new THREE.BoxGeometry(5 + rnd() * 3, 3, 3 + rnd() * 2); const m = add(g, "char", "stones");
      m.position.set(CX + Math.cos(a) * d, 4 + rnd() * 2, CZ + Math.sin(a) * d * 0.7); m.rotation.set(rnd(), rnd() * 3, rnd()); }
    // ---- the logs (owner 2026-11-07: 엇갈린 장작): four lengths laid low across each other in a star, each resting on
    // the ones below at the middle and on the ground at its ends; cut ends a shade lighter
    for (let i = 0; i < 4; i++) {
      const a = i / 4 * Math.PI + 0.3, L = 62, h = 12 + i * 5;
      const e0 = V(CX - Math.cos(a) * L / 2, 5, CZ - Math.sin(a) * L * 0.4), e1 = V(CX + Math.cos(a) * L / 2, 5, CZ + Math.sin(a) * L * 0.4);
      const mid = V(CX, h, CZ);
      for (const [p, q] of [[e0, mid], [mid, e1]]) {
        const dir = q.clone().sub(p).normalize(), g = new THREE.CylinderGeometry(4.5, 4.5, p.distanceTo(q) + 2, 8);
        const m = add(g, i % 2 ? "log" : "logLt", "logs"); m.position.copy(p.clone().add(q).multiplyScalar(0.5)); m.quaternion.setFromUnitVectors(V(0, 1, 0), dir);
      }
    }
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
