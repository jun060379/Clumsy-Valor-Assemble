// The campfire built in code (owner 2026-11-07: 작은 소품). The reference sprite (assets/town/g_ring.png, 109 x 63, one
// cell per pixel) is only the guide. A ring of rounded stones round a teepee of split logs leaning together; the fire
// itself is the pixelfx effect the town already lays over it, its flames starting at the teepee's apex (54, 1), which
// stays where it was. Built as a real solid: world units, x right, y up from the ground (y = 0), z toward the viewer.

const RING = (function () {
  const W = 109, H = 70, B0 = 63, K = 0.12, TOP = 2;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = {
    sand: ["ochre", 5],
    stone: ["cream", 3], stoneLt: ["cream", 4], log: ["wood", 4], logLt: ["wood", 5], ash: ["stone", 3],
  };
  const LAYERS = ["ground", "stones", "logs"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    const V = (x, y, z) => new THREE.Vector3(x, y, z);
    let seed = 3;
    const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
    const CX = 54, CZ = -16, APEX = V(CX, B0 + K * CZ - 1, CZ);       // the apex lands on row 1, where the flames start

    // ---- the hearth: ash on the ground inside the ring
    { const g = new THREE.CircleGeometry(30, 24); const m = add(g, "ash", "stones"); m.rotation.x = -Math.PI / 2; m.position.set(CX, 0.2, CZ); }
    // ---- the stones: a ring of rounded field stones, each a little different
    for (let i = 0; i < 10; i++) {
      const a = (i + 0.5) / 10 * Math.PI * 2, r = 40;
      const g = new THREE.IcosahedronGeometry(1, 1); const m = add(g, rnd() < 0.3 ? "stoneLt" : "stone", "stones");
      m.scale.set(15 + rnd() * 3, 10 + rnd() * 2, 10 + rnd() * 2);
      m.position.set(CX + Math.cos(a) * r, 8, CZ + Math.sin(a) * r * 0.75); m.rotation.y = -a;
    }
    // ---- the logs: split lengths leaning in to a point, their tops a little past it
    for (let i = 0; i < 8; i++) {
      const a = (i + 0.25) / 8 * Math.PI * 2, foot = V(CX + Math.cos(a) * 34, 0, CZ + Math.sin(a) * 22);
      const dir = APEX.clone().sub(foot).normalize(), top = APEX.clone().addScaledVector(dir, 3);
      const g = new THREE.CylinderGeometry(4, 5.5, foot.distanceTo(top), 7); const m = add(g, i % 3 ? "log" : "logLt", "logs");
      m.position.copy(foot.clone().add(top).multiplyScalar(0.5)); m.quaternion.setFromUnitVectors(V(0, 1, 0), dir);
    }
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
