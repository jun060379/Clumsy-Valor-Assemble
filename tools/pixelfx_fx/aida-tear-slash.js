// Aida's swing, after the game's aidaSwing shader: four torn strokes laid along the arc, each racing out, opening
// like an eye (the middle first), shutting (the ends first) with a white snap, its lip cooling white -> violet,
// then the line pulling away from its root. Remade with light: a lit outer lip, a soft void glow, twinkling depth.
import { Rng, clamp, ease, WHITE, fit, hex } from "../../core/index.js";

export const meta = {
  name: "Aida tear slash",
  desc: "Four torn strokes along a swing open like eyes onto the void, shut with a white snap and cool from white to violet.",
  tags: ["melee", "slash", "void", "tear", "rift", "one-shot"],
  size: [232, 232],
  origin: [116, 116],
  duration: 0.72,
  loop: false,
  fps: 50,
  options: { a0: -100, a1: 30, r: 62, sy: 1, w: 1, seed: 4, mask: 0 },
};

// the game's TEAR palette
const LIP = ["#ffffff", "#e8d4ff", "#c9a0ff", "#9a62e0", "#5a2a9e"].map(hex), RIM = hex("#b07aff"), RIM2 = hex("#5a1e9e"), VOID = hex("#06020a"), DEEP = hex("#1a0830"), NEB = hex("#3a1260");
const FR = 0.04;   // the shader's frame
// strokes: radius, lo, hi, width, delay (frames), radius drift
const ST = [[1.0, 0.0, 1.0, 7.5, 0.0, -0.06, 0], [0.8, 0.12, 1.04, 4.5, 0.8, -0.1, 0], [1.14, 0.26, 0.93, 1.4, 1.2, 0.04, 0], [0.62, 0.2, 0.9, 3.0, 1.7, -0.14, 0],
  [1.02, 0.04, 0.97, 5.0, 7.0, -0.05, 1]];   // the afterimage: the main tear, not quite healed, opens again faintly

const eo = (x) => 1 - Math.pow(1 - clamp(x), 3), smo = (x) => { x = clamp(x); return x * x * (3 - 2 * x); };
function state(tt) {   // ext, tail, cool step, snap: the shader's tear_state
  const cool = tt < 6.1 ? 0 : tt < 7.2 ? 1 : tt < 8.4 ? 2 : tt < 9.4 ? 3 : 4;
  return { ext: eo(tt / 0.8), tl: tt < 9 ? 0 : eo((tt - 9) / 1.4), cool, snap: tt >= 5.5 && tt < 6.1 };
}
const ov = (tt, v) => { const e = Math.min(1, Math.abs(v - 0.55) / 0.5); return smo((tt - 0.45 - 0.55 * e) / 1.7) * (1 - smo((tt - 3.9 - 0.5 * (1 - e)) / 1.25)); };
const prof = (v) => (v < 0.74 ? 0.07 + 0.93 * Math.pow(v / 0.74, 1.5) : Math.pow(Math.max(0, 1 - (v - 0.74) / 0.26), 0.5));

function world(o) {
  const key = JSON.stringify([o.a0, o.a1, o.r, o.sy, o.w, o.seed]);
  if (o._w && o._w.key === key) return o._w;
  const R = new Rng(o.seed);
  const strokes = ST.map((s) => ({ s, wob: Array.from({ length: 41 }, () => R.next()), wid: Array.from({ length: 27 }, () => R.next()), rim: Array.from({ length: 65 }, () => R.next()) }));
  const sparks = new Set();
  for (let i = 0; i < 4000; i++) if (R.chance(0.06)) sparks.add(i);
  const motes = Array.from({ length: 26 }, () => ({ v: R.range(0.15, 0.95), off: R.range(10, 26) * R.sign(), t0: R.range(0.3, 2.2), dur: R.range(1.6, 2.6) }));
  const specks = Array.from({ length: 44 }, () => ({ v: R.range(0.05, 0.98), sp: R.range(70, 220), side: R.sign(), along: R.range(-40, 40), life: R.range(0.12, 0.24), big: R.chance(0.25) }));
  const dust = Array.from({ length: 22 }, () => ({ v: R.range(0.05, 0.95), up: R.range(10, 26), dx: R.range(-6, 6), life: R.range(0.14, 0.26), d: R.range(0, 0.06) }));
  return (o._w = { key, strokes, sparks, motes, specks, dust });
}

export function draw(p, t, o) {
  const { strokes, sparks, motes, specks, dust } = world(o);
  const F = t / FR, span = o.a1 - o.a0, r0 = o.r, deg = Math.PI / 180;
  const x0 = Math.floor(-r0 * 1.32), x1 = Math.ceil(r0 * 1.32), y0 = Math.floor(-r0 * 1.32 * o.sy), y1 = Math.ceil(r0 * 1.32 * o.sy);
  const glowPts = [];
  p.shade(x0, y0, x1, y1, (xx, yy, out) => {
    const ye = (yy + 0.5) / o.sy, xe = xx + 0.5, rr = Math.hypot(xe, ye);
    if (rr < r0 * 0.45 || rr > r0 * 1.3) return;
    let d = Math.atan2(ye, xe) / deg - o.a0;
    if (span > 0) d = ((d % 360) + 360) % 360; else d = -((((-d) % 360) + 360) % 360);
    let u = d / span;
    if (u > 1.3) u -= 360 / Math.abs(span);
    if (u < -0.1 || u > 1.12) return;
    for (const S of strokes) {
      const [RC, LO, HI, WW, DL, DR, GH] = S.s, tt = F - DL;
      if (tt < 0 || tt > 10.5 || (o.mask && !GH)) continue;
      const st = state(tt), v = (u - LO) / (HI - LO), ga = GH ? 0.55 : 1;
      if (v < st.tl || v > st.ext || v < 0 || v > 1) continue;
      const wob = (S.wob[clamp(Math.floor(u * 40), 0, 40)] - 0.5) * 1.4, rc = r0 * (RC + DR * v) + wob;
      const hw = WW * (r0 / 62) * o.w * 1.2 * prof(v) * ov(tt, v) * (0.6 + 0.8 * S.wid[clamp(Math.floor(u * 26), 0, 26)]);
      const dist = rr - rc, ad = Math.abs(dist);
      if (ad > hw + 3.2) continue;
      const hn = S.rim[clamp(Math.floor(u * 64), 0, 64)];
      if (hw > 0.6 && ad < hw) {                         // the void, deeper toward the middle, with twinkling sparks
        const key = ((xx + 300) * 977 + (yy + 300) * 131) % 4000;
        if (GH) { if (o.mask) out.c = WHITE; return; }   // the afterimage is a window: the game shows through it in negative (mask pass)
        if (sparks.has(key) && Math.sin(t * 40 + key) > 0.2) { out.c = RIM; return; }
        const n = Math.sin(xx * 0.31 + t * 6) + Math.sin(yy * 0.27 - t * 4.5) + Math.sin((xx + yy) * 0.18 + t * 3);
        out.c = ad > hw - 1 ? DEEP : n > 1.3 && hw > 2 ? NEB : n > 0.6 && hw > 2 ? DEEP : VOID;   // a slow nebula deep inside
        return;
      }
      const lip = hw > 0.6 ? ad - hw : ad, lit = dist > 0;  // the outer lip catches the light
      if (o.mask) continue;
      if (GH && lip < 1.0) { out.c = st.cool < 1 ? WHITE : LIP[Math.min(4, st.cool)]; return; }   // framed by a bright line
      if (lip < (st.snap ? 1.4 : 0.85)) { out.c = LIP[Math.min(4, st.cool + (lit || st.snap ? 0 : 1))]; return; }
      if (GH) continue;
      if (st.cool < 3 && lip < 1.9 && hw > 0.8 && hn > 0.15) { out.c = RIM; return; }
      if (st.cool < 2 && lip < 2.9 && hw > 2.2 && hn > 0.6) { out.c = RIM2; out.a = 0.85; return; }
    }
  });
  if (o.mask) return;
  // light: a soft glow along the open strokes, a flash on the snap, the racing head
  for (const S of strokes) {
    const [RC, LO, HI, WW, DL, DR] = S.s, tt = F - DL;
    if (tt < 0 || tt > 10.5) continue;
    const st = state(tt);
    for (let i = 0; i <= 10; i++) {
      const v = st.tl + (st.ext - st.tl) * (i / 10), u = LO + (HI - LO) * v, a = (o.a0 + span * u) * deg, rc = r0 * (RC + DR * v);
      const x = Math.cos(a) * rc, y = Math.sin(a) * rc * o.sy, open = ov(tt, v) * prof(v);
      if (open > 0.05) p.glow(x, y, 6 + WW, LIP[3], 0.18 * open * (WW / 7.5 + 0.3));
      if (st.snap) p.glow(x, y, 8, LIP[1], 0.45 * prof(v));
      if (i === 10 && tt < 1.2 && WW > 4) { p.glow(x, y, 9, LIP[1], 0.7 * (1 - tt / 1.2)); p.px(x, y, WHITE); }
    }
  }

  // the main stroke's path at v, for the embellishments
  const S0 = strokes[0], [RC0, LO0, HI0, WW0] = S0.s, path = (v, dr = 0) => {
    const u = LO0 + (HI0 - LO0) * v, a = (o.a0 + span * u) * deg, rc = r0 * (RC0 - 0.06 * v) + dr;
    return [Math.cos(a) * rc, Math.sin(a) * rc * o.sy, a];
  };
  const st0 = state(F);
  // light leaking out of the open void: thin rays spilling outward, flickering
  for (let i = 0; i < 14; i++) {
    const v = 0.12 + i * 0.06, op = ov(F, v) * prof(v);
    if (op < 0.35 || v > st0.ext) continue;
    const fl = 0.55 + 0.45 * Math.sin(t * 55 + i * 2.7), [x, y, a] = path(v), L = (8 + 22 * op) * fl;
    for (const sd of [1, -1]) {
      const ex = Math.cos(a) * sd, ey = Math.sin(a) * o.sy * sd, h0 = WW0 * 1.3 * op;
      p.glowLine(x + ex * h0, y + ey * h0, x + ex * (h0 + L), y + ey * (h0 + L), 2.6, LIP[2], 0.6 * op * fl);
      p.line(x + ex * h0, y + ey * h0, x + ex * (h0 + L * 0.45), y + ey * (h0 + L * 0.45), LIP[1], 0.35 * op * fl);
    }
  }
  // a highlight running along the lip while it stares, like light sliding over glass
  if (F > 1 && F < 5.4) {
    const hv = clamp((F - 1) / 3.6);
    for (let i = -3; i <= 3; i++) {
      const v = hv + i * 0.012;
      if (v < 0 || v > 1 || ov(F, v) < 0.2) continue;
      const hw = WW0 * (r0 / 62) * o.w * 1.2 * prof(v) * ov(F, v), [x, y, a] = path(v, hw + 0.8);
      p.px(x, y, i === 0 ? WHITE : LIP[1], 1 - Math.abs(i) * 0.25);
      if (i === 0) p.glow(x, y, 6, LIP[1], 0.6);
    }
  }
  // the snap leaves echoes: the tear's line repeated outward, thinning and fading like a ripple in space
  const snapT = 5.5 * FR;
  if (t > snapT && t < snapT + 0.1) for (let i = 0; i <= 12; i++) { const [x, y] = path(i / 12); p.glow(x, y, 12, LIP[0], 0.55 * (1 - (t - snapT) / 0.1)); }
  for (const [dl, amp] of [[0, 1], [0.035, 0.7]]) {
    const k = (t - snapT - dl) / 0.16;
    if (k < 0 || k > 1) continue;
    const pts = [];
    for (let i = 0; i <= 40; i++) { const v = 0.05 + 0.9 * (i / 40); pts.push(path(v, (4 + 16 * ease.outCubic(k)) * amp)); }
    p.polyline(pts.map(([x, y]) => [x, y]), k < 0.35 ? LIP[1] : LIP[3], (1 - k) * amp);
    const pts2 = [];
    for (let i = 0; i <= 40; i++) { const v = 0.05 + 0.9 * (i / 40); pts2.push(path(v, -(3 + 10 * ease.outCubic(k)) * amp)); }
    p.polyline(pts2.map(([x, y]) => [x, y]), LIP[3], (1 - k) * 0.6 * amp);
  }
}
