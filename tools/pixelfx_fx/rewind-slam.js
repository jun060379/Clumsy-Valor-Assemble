// Aida's slam: the floor breaks, a thin bright dome of air thumps out, chunks of floor glowing violet burst into the
// air, slow to a weightless float, then fly back into their holes as if time ran backwards, and the cracks seal.
import { Rng, clamp, ease, TAU, WHITE, fit, mix } from "../../core/index.js";
import { stone, makeCracks, drawCracks, rockShape, rock } from "./_lib.js";

// a sharp shard: a jagged 3 to 5 point polygon around (x, y), turned a, size s
function shardPts(c, x, y, a) {
  const n = c.poly.length, r = 1.2 + c.s * 1.05;
  return c.poly.map(([k, f], i) => { const ang = a + (i / n) * TAU + (i % 2 ? 0.35 : 0); const rr = r * f * (i === 0 ? 1.6 : 1); return [x + Math.cos(ang) * rr, y + Math.sin(ang) * rr * 0.85]; });
}
function shard(p, c, x, y, a, st, C, k = 1, ghost = false) {
  const q = shardPts(c, x, y, a);
  if (ghost) { p.polyline([...q, q[0]], C[3], k); return; }
  p.poly(q, (px, py) => (py < y - c.s * 0.3 ? st.light : py > y + c.s * 0.3 ? st.shade : st.body), k);
  p.polyline([...q, q[0]], C[4], k);
  p.px(q[0][0], q[0][1], C[6], k);
}

export const meta = {
  name: "Rewind slam",
  desc: "The floor breaks, a thin bright dome of air thumps out, glowing violet chunks burst up, float weightless, then rewind into the floor and the cracks seal.",
  tags: ["impact", "ground", "slam", "shockwave", "dome", "rewind", "time", "one-shot"],
  size: [440, 176],
  origin: [220, 140],
  duration: 1.82,
  loop: false,
  fps: 30,
  bg: "ground",
  options: { palette: ["#0a0114", "#2a0a4c", "#601ea0", "#9a5cff", "#cda0ff", "#e6c8ff", "#ffffff"], stone: "#4a3b46", reach: 112, seed: 3 },
};

// beats (s): the thump, the burst, the float, the rewind, the seal
// the hit-stop: everything that moves holds still for two frames on the big thump
const HOLD = 0.067, warp = (t) => (t < 0.07 ? t : t < 0.07 + HOLD ? 0.07 : t - HOLD);
const BURST = 0.2, FLOAT = 0.98, BACK = 1.25, SEAL = 1.33;

function world(o) {
  if (o._w) return o._w;
  const R = new Rng(o.seed), C = fit(o.palette, 7), st = stone(o.stone);
  const cracks = makeCracks(R, 10, { len: [22, 60], dive: 0.5, maxY: 18, forks: 0.7, x0: [2, 8] });
  const chunks = [];
  for (let i = 0; i < 38; i++) {
    const x0 = R.range(-o.reach * 0.85, o.reach * 0.85) * (i < 6 ? 0.35 : 1);
    const s = i < 4 ? R.int(6, 8) : i < 14 ? R.int(3, 5) : R.int(1, 2);
    const far = Math.max(0.15, 1 - Math.abs(x0) / o.reach);
    chunks.push({
      x0, s, pts: rockShape(R), poly: Array.from({ length: R.int(3, 5) }, (_, k, n) => [k, R.range(0.45, 1.25)]),
      fx: x0 * R.range(1.1, 1.45) + Math.sign(x0 || 1) * R.range(0, 30), fy: -R.range(18, 92) * (0.5 + 0.7 * far) * (s > 5 ? 0.6 : 1),
      drift: R.range(-5, 5), bob: R.range(2, 4.5), ph: R.range(0, TAU), a0: R.range(0, TAU), spin: R.range(-2.2, 2.2),
      back: R.range(-0.04, 0.05),
    });
  }
  const grit = [];      // plain floor rubble: thrown and falling for real, the rough contrast to the floating chunks
  for (let i = 0; i < 80; i++) {
    const u = R.range(-1, 1), a = -Math.PI / 2 + u * 1.3, sp = R.range(150, 420) * (1 - 0.3 * Math.abs(u));
    grit.push({ x0: R.range(-10, 10), vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, life: R.range(0.5, 0.95), s: R.chance(0.35) ? 2 : 1, c: R.pick([st.light, st.body, st.shade, st.shade]) });
  }
  const specks = [];    // violet dust frozen in the air with the chunks, rewound with them
  for (let i = 0; i < 40; i++) {
    const x0 = R.range(-o.reach * 0.85, o.reach * 0.85);
    specks.push({ x0, fx: x0 * 1.3 + R.range(-14, 14), fy: -R.range(6, 90), ph: R.range(0, TAU), c: R.chance(0.3) ? 6 : R.chance(0.5) ? 5 : 4, back: R.range(-0.05, 0.06) });
  }
  const motes = [];     // slow motes rising while time hangs
  for (let i = 0; i < 18; i++) motes.push({ x: R.range(-o.reach * 0.7, o.reach * 0.7), y: -R.range(0, 20), sp: R.range(10, 26), t0: R.range(0.15, 0.6), ph: R.range(0, TAU) });
  return (o._w = { R, C, st, cracks, chunks, grit, specks, motes });
}

// where a chunk is at t: out fast, coasting to a stop, weightless bobbing, then sucked home, faster and faster
function place(c, t) {
  if (t < 0.07) return { x: c.x0, y: 0, a: c.a0, on: false };
  const tb = BACK + c.back;
  if (t < BURST) {
    const u = ease.outExpo((t - 0.07) / (BURST - 0.07));
    return { x: c.x0 + (c.fx - c.x0) * u, y: c.fy * u, a: c.a0 + c.spin * u * 0.6, on: true };
  }
  const fl = Math.min(t, FLOAT) - BURST;
  const fx = c.fx + c.drift * fl, fy = c.fy - 3 * fl + Math.sin(c.ph + fl * 4) * c.bob * clamp(fl / 0.25), fa = c.a0 + c.spin * (0.6 + fl * 0.5);
  if (t < FLOAT) return { x: fx, y: fy, a: fa, on: true };
  const u = ease.inCubic(clamp((t - FLOAT) / (tb - FLOAT)));
  if (u >= 1) return { x: c.x0, y: 0, a: c.a0, on: false, home: t - tb };
  return { x: fx + (c.x0 - fx) * u, y: fy * (1 - u), a: fa + (c.a0 - fa) * u, on: true, rew: u };
}

export function drawBack(p, t, o) {
  t = warp(t);
  const { C, st, cracks } = world(o);
  const seal = clamp((t - BACK) / (SEAL - BACK + 0.15));
  const heat = (d) => clamp(1.1 - d / 42) * (t < BURST ? 1 : 0.55 + 0.45 * Math.sin(t * 9) * 0.3) * (1 - seal);
  // cracks race out at the thump, glow violet while the chunks are up, then zip back shut
  drawCracks(p, cracks, (c) => c.len * ease.outCubic(clamp((t - c.t0) / 0.09)) * (1 - ease.inCubic(seal)), heat,
    [WHITE, C[5], C[4], C[3]], C[0], st.light, 1);
  // holes where the chunks came from, glowing from below while they are away
  for (const c of world(o).chunks) {
    const q = place(c, t);
    if (!q.on && t > 0.02 && q.home === undefined) continue;
    if (t < 0.02 || (q.home !== undefined && q.home > 0.05)) continue;
    const w = 1 + c.s;
    for (let x = -w; x <= w; x++) p.px(c.x0 + x, 0, C[0]);
    p.glow(c.x0, 0, 5 + c.s * 2, C[3], 0.35);
  }
}

export function draw(p, t, o) {
  const T0 = t;
  t = warp(t);
  const { C, st, chunks } = world(o);
  const R = o.reach;
  // 쿠-궁: a small thump, a two-frame breath, then the big one
  const T2 = 0.07;
  if (T0 < 0.045) {
    const k = 1 - T0 / 0.045;
    p.glowLine(-R * 0.45, 0, R * 0.45, 0, 7, WHITE, 0.6 * k);
    p.ellipse(0, 0, 16, 2.5, WHITE, k);
  }
  if (T0 >= T2 && T0 < T2 + 0.1) {
    const k = 1 - (T0 - T2) / 0.1;
    if (T0 < T2 + 0.067) p.glow(0, -10, R * 1.4, WHITE, 0.6 * k);                    // the hero frame
    for (let i = 0; i < 4; i++) {                                                    // a hard white impact star
      const ang = -Math.PI / 2 + (i - 1.5) * 0.9, L = (i === 1 || i === 2 ? 46 : 30) * (0.6 + 0.4 * k);
      p.beam(0, -1, Math.cos(ang) * L, Math.sin(ang) * L * 0.8, 3 * k + 1, WHITE, k);
    }
    p.beam(-R * 0.7 * (1.2 - k), -1, R * 0.7 * (1.2 - k), -1, 3, WHITE, k);
    p.glowLine(-R * 1.1, 0, R * 1.1, 0, 14, WHITE, 0.9 * k);
    p.glow(0, -8, 46, C[5], k);
    p.ellipse(0, 0, 38 * (1.3 - k * 0.5), 4, (d) => (d > 0.6 ? C[5] : WHITE), k);
    for (let i = 0; i < 14; i++) {                                                    // speed lines thrown out of the hit
      const ang = Math.PI + (i + 0.5) / 14 * Math.PI, r0 = 14 + (1 - k) * 40, r1 = r0 + 10 + (i % 3) * 7;
      p.line(Math.cos(ang) * r0, Math.sin(ang) * r0 * 0.7, Math.cos(ang) * r1, Math.sin(ang) * r1 * 0.7, i % 2 ? C[6] : WHITE, k);
    }
  }
  // ground shock: two hard lines skidding out along the floor ahead of the dome
  const gu = clamp((t - T2) / 0.22);
  if (gu > 0 && gu < 1) {
    const x = 10 + R * 1.4 * ease.outExpo(gu), k = 1 - gu;
    for (const sd of [-1, 1]) {
      p.line(sd * x * 0.55, -1, sd * x, -1, WHITE, k);
      p.line(sd * x * 0.7, -2, sd * x * 0.96, -2, C[5], k * 0.8);
      p.glowLine(sd * x * 0.6, -1, sd * x, -1, 6, C[5], 0.6 * k);
    }
  }
  // rubble kicked up both ways and low dust rolling out along the floor
  for (const g of world(o).grit) {
    const tt = t - 0.07;
    if (tt < 0 || tt > g.life) continue;
    const x = g.x0 + g.vx * tt, y = Math.min(0, g.vy * tt + 0.5 * 900 * tt * tt);
    p.rect(x, y, g.s, g.s, g.c, 1 - Math.pow(tt / g.life, 3));
  }
  const dd = clamp((t - 0.07) / 0.6);
  if (dd > 0 && dd < 1)
    for (const sd of [-1, 1]) for (let i = 0; i < 5; i++) {
      const x = sd * (8 + (R * 0.85) * ease.outCubic(dd) * (0.55 + i * 0.1)), r = 4 + i * 1.3 + dd * 6;
      p.disc(x, -r * 0.45, r, st.dust, 0.35 * (1 - dd) * (1 - i * 0.12));
    }
  // the dome of air: it pops out on the big thump (fast, then coasting), a hard bright front with a dark band of
  // pressure behind it and torn gaps, and a fainter echo shell a beat behind
  for (const [dl, amp, echo] of [[0, 1, false], [0.06, 0.8, true]]) {
    const du = clamp((t - T2 - dl) / 0.3);
    if (du <= 0 || du >= 1) continue;
    const r0 = 14 + (R * 1.25 * amp - 14) * ease.outExpo(du), ry0 = r0 * (0.4 + 0.26 * ease.outBack(clamp(du / 0.35), 2.5)), k = Math.pow(1 - du, 1.3) * (echo ? 0.5 : 1);
    const col = echo ? C[5] : du < 0.25 ? WHITE : du < 0.55 ? C[6] : C[5], th = echo ? 1 : du < 0.1 ? 7 : du < 0.25 ? 5 : du < 0.5 ? 3 : 1;
    for (let i = 0; i <= 440; i++) {
      const a = Math.PI + (i / 440) * Math.PI, ca = Math.cos(a), sa = Math.sin(a);
      const wob = 1;
      const r = r0 * wob, ry = ry0 * wob, edge = 0.45 + 0.55 * Math.abs(ca);
      for (let j = 0; j < th; j++) p.px(ca * (r - j), sa * (ry - j), j ? C[5] : col, k * edge);
      if (!echo) for (let j = th; j < th + 3; j++) p.px(ca * (r - j), sa * (ry - j), C[0], 0.35 * k * edge);   // the pressure band
      if (!echo && i % 20 === 0) p.glow(ca * r, sa * ry, 8, C[5], 0.45 * k * edge);
      if (!echo && du < 0.12) for (let j = th + 3; j < th + 9; j++) p.px(ca * (r - j), sa * (ry - j), C[6], 0.25 * (1 - du / 0.12));   // the punch: a bright fill in the first frames
    }
  }
  // time rewinds: the dome comes back and shrinks into the floor
  const rd = clamp((t - FLOAT) / (BACK - FLOAT));
  if (rd > 0 && rd < 1) {
    const r = R * 0.95 * (1 - ease.inCubic(rd)), ry = r * 0.6, k = 0.35 + 0.5 * rd;
    for (let i = 0; i <= 300; i++) {
      const a = Math.PI + (i / 300) * Math.PI;
      if (Math.sin(a * 11 - t * 25) > 0.6) continue;
      p.px(Math.cos(a) * r, Math.sin(a) * ry, C[4], k * (0.4 + 0.6 * Math.abs(Math.cos(a))));
    }
  }
  // violet dust frozen mid-air, then rewound; slow motes rising while time hangs
  for (const sp of world(o).specks) {
    if (t < 0.06) continue;
    const tb = BACK + sp.back;
    if (t >= tb) continue;
    const u = t < BURST + 0.05 ? ease.outExpo((t - 0.06) / (BURST - 0.01)) : 1, b = t > FLOAT ? ease.inCubic(clamp((t - FLOAT) / (tb - FLOAT))) : 0;
    const x = (sp.x0 + (sp.fx - sp.x0) * u) * (1 - b) + sp.x0 * b, y = sp.fy * u * (1 - b) + Math.sin(t * 3 + sp.ph) * 1.2 * (1 - b);
    p.px(x, y, C[sp.c], 0.5 + 0.5 * Math.sin(t * 11 + sp.ph));
    if (b > 0.3) p.px(x + (x - sp.x0) * 0.08, y * 1.08, C[3], 0.5);
  }
  for (const m of world(o).motes) {
    const a = t - m.t0;
    if (a < 0 || t > FLOAT + 0.1) continue;
    const k = Math.min(1, a / 0.2) * (1 - clamp((t - FLOAT + 0.1) / 0.2));
    p.px(m.x + Math.sin(a * 2 + m.ph) * 3, m.y - m.sp * a, C[5], k * 0.8);
    p.glow(m.x + Math.sin(a * 2 + m.ph) * 3, m.y - m.sp * a, 3, C[4], 0.25 * k);
  }
  // the chunks: floor stone with a violet glow while they are out of place; afterimages on the way home
  for (const c of chunks) {
    const q = place(c, t);
    if (q.home !== undefined) {
      if (q.home < 0.12) { p.glow(c.x0, -1, 7 + c.s * 2, C[5], 0.8 * (1 - q.home / 0.12)); p.px(c.x0, -1, WHITE); }
      continue;
    }
    if (!q.on) continue;
    if (q.rew !== undefined && q.rew > 0.05) {
      const g = place(c, t - 0.035), g2 = place(c, t - 0.07);
      for (const [gg, kk] of [[g2, 0.35], [g, 0.6]]) if (gg.on) shard(p, c, gg.x, gg.y, gg.a, st, C, kk, true);
    }
    shard(p, c, q.x, q.y, q.a, st, C);
    const pulse = 0.6 + 0.4 * Math.sin(t * 7 + c.ph);
    p.glow(q.x, q.y, 3 + c.s * 1.2, C[4], (t < BURST ? 0.6 : 0.3 * pulse) * (q.rew ? 1 + q.rew : 1));
    if (t < BURST + 0.05 || q.rew > 0.6) p.px(q.x, q.y - c.s * 0.5, C[5]);
  }
  // 쿵: the floor takes the last chunk back with one more thump and seals in a violet line
  const sk = 1 - (t - (BACK + 0.05)) / 0.35;
  if (sk > 0 && sk <= 1) {
    p.glowLine(-R * 0.7, 0, R * 0.7, 0, 9, C[5], 0.7 * sk);
    p.line(-R * 0.6, 0, R * 0.6, 0, sk > 0.6 ? WHITE : C[4], sk);
    if (sk > 0.7) p.glow(0, -3, 30, C[5], 0.8 * (sk - 0.7) / 0.3);
  }
}
