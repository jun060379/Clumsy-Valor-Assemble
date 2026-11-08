// The town's middle distance built as solids (owner 2026-11-08: "근경과 가까운 배경은 없는데 이것도 어캐 못하나"),
// rendered once at noon and laid behind the town as a strip wider than its parallax travel (no repeat).
//   wood:  the far wood (parallax 0.42): rows of firs on a low rolling ground, in the blue ramp (the distance's air)
//   hills: nearer hills (parallax 0.65): a rolling crest with clumps of round-crowned trees and a few firs, green ramp
// Every material is deco* (no outline: background, AGENTS.md 꽃·풀 같은 장식은 외곽선 없이 배경과 같은 팔레트).
// One unit a game px (CELL 2: the town's 2-px grid). y up from the strip's foot, z toward the viewer.
const VARIANT = "hills";
const BGMID = (function () {
  const HILLS = VARIANT === "hills";
  const W = HILLS ? 7400 : 5200, H = HILLS ? 300 : 170, B0 = H - 8, K = 0.12, TOP = 4;
  const Y = (row, z) => B0 + K * z - row;
  const RAMP = { red: 0, wood: 1, ochre: 2, cream: 3, leaf: 4, green: 5, blue: 6, violet: 7, stone: 8, iron: 9 };
  const MAT = HILLS
    ? { sand: ["ochre", 5], decoGround: ["green", 3], decoLeaf: ["green", 3], decoFir: ["green", 2], decoTrunk: ["wood", 2], decoGround2: ["green", 2], decoLeaf2: ["green", 3] }
    : { sand: ["ochre", 5], decoGround: ["blue", 1], decoFir: ["blue", 2], decoFirB: ["blue", 1] };
  const LAYERS = ["ground", "trees"];

  function build(THREE) {
    const parts = [];
    const add = (geo, mat, layer) => { const m = new THREE.Mesh(geo); parts.push({ mesh: m, mat, layer }); return m; };
    let seed = HILLS ? 9 : 5;
    const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
    // smooth noise: interpolated random knots at a few scales
    const knots = (step, amp) => { const k = []; for (let i = 0; i < W / step + 3; i++) k.push((rnd() * 2 - 1) * amp); return { step, k }; };
    const NS = HILLS ? [knots(420, 22), knots(140, 8), knots(40, 2)] : [knots(300, 10), knots(90, 4)];
    const sm = (f) => f * f * (3 - 2 * f);
    const NS2 = HILLS ? [knots(260, 16), knots(70, 4)] : [];
    const hgt2 = (x) => 70 + NS2.reduce((s, n) => { const t = x / n.step, i = Math.floor(t), f = sm(t - i); return s + n.k[i] * (1 - f) + n.k[i + 1] * f; }, 0);
    const hgt = (x) => (HILLS ? 170 : 30) + NS.reduce((s, n) => { const t = x / n.step, i = Math.floor(t), f = sm(t - i); return s + n.k[i] * (1 - f) + n.k[i + 1] * f; }, 0);
    // the ground: the crest line's shape, extruded back
    { const pts = [new THREE.Vector2(-20, -20)];
      for (let x = -20; x <= W + 20; x += 6) pts.push(new THREE.Vector2(x, hgt(Math.max(0, x))));
      pts.push(new THREE.Vector2(W + 20, -20));
      const D = HILLS ? 60 : 50;
      const g = new THREE.ExtrudeGeometry(new THREE.Shape(pts), { depth: D, bevelEnabled: false, steps: 1 });
      const m = add(g, "decoGround", "ground"); m.position.set(0, 0, -D); }
    const fir = (x, z, h, mat, gf = hgt) => {
      const y0 = gf(x) - 2, tiers = h < 34 ? 3 : 4, w = h * (0.32 + rnd() * 0.08);
      for (let t = 0; t < tiers; t++) {
        const f = t / tiers, r = w * (1 - f * 0.62), th = h / tiers * 1.55;
        const g = new THREE.ConeGeometry(r, th, 7); const m = add(g, mat, "trees");
        m.position.set(x, y0 + h * 0.18 + f * h * 0.82 + th / 2 - th * 0.35, z); m.rotation.y = rnd() * 3;
      }
    };
    const tree = (x, z, s, gf = hgt, leaf = "decoLeaf") => {
      const y0 = gf(x) - 2;
      { const g = new THREE.CylinderGeometry(1.6 * s, 2.2 * s, 10 * s, 6); const m = add(g, "decoTrunk", "trees"); m.position.set(x, y0 + 5 * s, z); }
      const n = 4 + Math.floor(rnd() * 4);
      for (let i = 0; i < n; i++) {
        const r = (6 + rnd() * 6) * s, a = rnd() * 6.28, d = i === 0 ? 0 : (5 + rnd() * 6) * s;
        const g = new THREE.IcosahedronGeometry(r, 1); const m = add(g, leaf, "trees");
        m.position.set(x + Math.cos(a) * d, y0 + (14 + rnd() * 9) * s + (i === 0 ? 4 * s : 0), z + Math.sin(a) * d * 0.6);
        m.scale.set(1, 0.82, 0.9); m.rotation.set(rnd() * 3, rnd() * 3, 0);
      }
    };
    if (HILLS) {
      let x = 20 + rnd() * 60;
      while (x < W) {
        const n = 2 + Math.floor(rnd() * 4);
        for (let k = 0; k < n; k++) {
          const cx = x + k * (20 + rnd() * 14), z = -45 + rnd() * 35;
          if (cx > W) break;
          if (rnd() < 0.25) fir(cx, z, 40 + rnd() * 24, "decoFir"); else tree(cx, z, 1.3 + rnd() * 0.7);
        }
        x += 70 + rnd() * 170;
      }
      // the nearer ridge below it (owner 2026-11-08): seen when the camera is down on the lower street, a step darker,
      // firs on it
      { const pts = [new THREE.Vector2(-20, -20)];
        for (let x = -20; x <= W + 20; x += 6) pts.push(new THREE.Vector2(x, hgt2(Math.max(0, x))));
        pts.push(new THREE.Vector2(W + 20, -20));
        const g = new THREE.ExtrudeGeometry(new THREE.Shape(pts), { depth: 14, bevelEnabled: false, steps: 1 });
        const m = add(g, "decoGround2", "ground"); m.position.set(0, 0, 36); }
      // firs along it in groups (round crowns came out in the hill's own colours, a blur against it)
      x = 40 + rnd() * 80;
      while (x < W) {
        const n = 2 + Math.floor(rnd() * 4);
        for (let k = 0; k < n; k++) {
          const cx = x + k * (12 + rnd() * 10), z = 30 + rnd() * 5;
          if (cx > W) break;
          fir(cx, z, 44 + rnd() * 30, "decoFir", hgt2);
        }
        x += 90 + rnd() * 220;
      }
    } else {
      for (const [z, sp, h0, h1, mat] of [[-40, 16, 44, 70, "decoFirB"], [-12, 18, 30, 52, "decoFir"]]) {
        let x = rnd() * sp;
        while (x < W + 10) { if (rnd() < 0.9) fir(x, z + rnd() * 10, h0 + rnd() * (h1 - h0), mat); x += sp * (0.6 + rnd() * 0.9); }
      }
    }
    return parts;
  }
  return { W, H, B0, K, TOP, Y, RAMP, MAT, LAYERS, build };
})();
