// The string of lights built in code (owner 2026-11-07: 작은 소품). The reference sprite (assets/town/q_lights.png,
// 397 x 58, one cell per pixel; the town stretches it across each span of the lower plaza) is only the guide. A wire
// hung between two points sagging in the middle, seven bulbs on it - a socket each and a glass globe that glows (fire*
// materials are drawn unlit). Built as a real solid: world units, x right, y up from the sprite's foot, z toward the
// viewer; it hangs high, so it casts nothing on the ground.

const LIGHTS = (function () {
  const W = 397, H = 62, B0 = 58, K = 0.12, TOP = 2;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = { sand: ["ochre", 5], wire: ["wood", 1], socket: ["violet", 2], fireGlass: ["cream", 6], fireGlassLt: ["cream", 7] };
  const LAYERS = ["ground", "wire", "bulbs"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    const V = (x, y, z) => new THREE.Vector3(x, y, z);
    const Z = -4, y0 = 56, y1 = 53, ymid = 31;                       // the ends and the low point of the sag
    const wireY = (x) => { const t = x / W; return y0 + (y1 - y0) * t - 4 * (((y0 + y1) / 2) - ymid) * t * (1 - t); };
    const pts = []; for (let x = -2; x <= W + 2; x += 8) pts.push(V(x, wireY(x), Z));
    add(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 80, 1.0, 5, false), "wire", "wire");
    [26, 86, 142, 198, 256, 312, 372].forEach((x, i) => {
      const yw = wireY(x);
      { const g = new THREE.CylinderGeometry(2.6, 3.2, 6, 8); const m = add(g, "socket", "bulbs"); m.position.set(x, yw - 3.5, Z); }
      { const g = new THREE.SphereGeometry(7, 12, 10); const m = add(g, i % 3 === 1 ? "fireGlassLt" : "fireGlass", "bulbs");
        m.scale.set(1, 1.15, 1); m.position.set(x, yw - 14.5, Z); }
    });
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
