// Aida's thrust, after the game's aidaThrust: four tears laid along the jab (from a little behind her out past the
// point), each opening like an eye, snapping shut white and cooling; then one negative window along it (mask pass).
import { Rng, clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Aida thrust tear",
  desc: "Four tears laid along a jab open like eyes onto the void, snap shut white, cool, and reopen once as a negative window.",
  tags: ["melee", "thrust", "rift", "void", "tear", "one-shot"],
  size: [200, 72],
  origin: [10, 30],
  duration: 0.72,
  loop: false,
  fps: 50,
  options: { len: 98, seed: 9, mask: 0 },
};

const LIP = ["#ffffff", "#e8d4ff", "#c9a0ff", "#9a62e0", "#5a2a9e"].map(hex), RIM = hex("#b07aff"), RIM2 = hex("#5a1e9e"), VOID = hex("#06020a"), DEEP = hex("#1a0830"), NEB = hex("#3a1260");
const FR = 0.04, OM = 30;

const eo = (x) => 1 - Math.pow(1 - clamp(x), 3), smo = (x) => { x = clamp(x); return x * x * (3 - 2 * x); };
function state(tt) {
  const cool = tt < 6.1 ? 0 : tt < 7.2 ? 1 : tt < 8.4 ? 2 : tt < 9.4 ? 3 : 4;
  return { ext: eo(tt / 0.8), tl: tt < 9 ? 0 : eo((tt - 9) / 1.4), cool, snap: tt >= 5.5 && tt < 6.1 };
}
const ov = (tt, v) => { const e = Math.min(1, Math.abs(v - 0.55) / 0.5); return smo((tt - 0.45 - 0.55 * e) / 1.7) * (1 - smo((tt - 3.9 - 0.5 * (1 - e)) / 1.25)); };
const almond = (v) => Math.pow(Math.sin(Math.PI * clamp(v)), 0.8);
const tprof = (v) => (v < 0.74 ? 0.07 + 0.93 * Math.pow(v / 0.74, 1.5) : Math.pow(Math.max(0, 1 - (v - 0.74) / 0.26), 0.5));
const PROF = [tprof, (v) => almond(0.15 + 0.85 * v)];

function world(o) {
  const key = JSON.stringify([o.len, o.seed]);
  if (o._w && o._w.key === key) return o._w;
  const R = new Rng(o.seed);
  // stroke: side, offset at root/tip (+ down on the right cut, mirrored on the left), lo, hi, width, delay, profile, ghost
  const ST = [[1, 0, -1, 0, 1, 7, 0, 0, 0], [1, -9, -15, 0.22, 0.96, 3.6, 0.7, 0, 0], [1, 8, 12, 0.12, 0.82, 2.4, 1.1, 0, 0], [1, -4, -6, 0.4, 1.04, 1, 0.4, 0, 0],
    [1, 0, -1, 0.04, 0.98, 4.8, 7.0, 0, 1]];   // the afterimage: the main tear's line, a window in negative
  const strokes = ST.map((s) => ({ s, wob: Array.from({ length: 31 }, () => R.next()), wid: Array.from({ length: 23 }, () => R.next()), rim: Array.from({ length: 57 }, () => R.next()) }));
  const sparks = new Set();
  for (let i = 0; i < 4000; i++) if (R.chance(0.06)) sparks.add(i);
  return (o._w = { key, strokes, sparks });
}


export function draw(p, t, o) {
  const { strokes, sparks } = world(o);
  const T = t / FR, ta = t, L = o.len;
  p.shade(-6, -28, L + 8, 26, (xx, yy, out) => {
    const X = xx + 0.5, Y = yy + 0.5;
    for (const S of strokes) {
      const [sd, o0, o1, lo, hi, WW, DL, pk, GH] = S.s, tt = T - DL;
      if (tt < 0 || tt > 10.5 || (o.mask && !GH)) continue;
      // along: from the blow out to the tip (the ghost spans both sides); across: down on the right, up on the left
      const u = X / L, pd = Y;
      if (u < -0.02 || u > 1.02) continue;
      const st = state(tt), v = (u - lo) / (hi - lo);
      if (v < st.tl || v > st.ext || v < 0 || v > 1) continue;
      const oc = o0 + (o1 - o0) * v + (S.wob[clamp(Math.floor(u * 30), 0, 30)] - 0.5) * 1.2;
      const hw = WW * (GH ? almond(v) : PROF[pk](v)) * ov(tt, v) * (0.6 + 0.8 * S.wid[clamp(Math.floor(u * 22), 0, 22)]);
      const dist = pd - oc, ad = Math.abs(dist);
      if (ad > hw + 3.2) continue;
      const hn = S.rim[clamp(Math.floor(u * 56), 0, 56)];
      if (hw > 0.6 && ad < hw) {
        if (GH) { if (o.mask) out.c = WHITE; return; }
        const key = ((xx + 300) * 977 + (yy + 300) * 131) % 4000;
        if (sparks.has(key) && Math.sin(ta * OM * 3 + key) > 0.2) { out.c = RIM; return; }
        const n = Math.sin(xx * 0.31 + ta * OM) + Math.sin(yy * 0.27 - ta * OM * 2) + Math.sin((xx + yy) * 0.18 + ta * OM);
        out.c = ad > hw - 1 ? DEEP : n > 1.3 && hw > 2 ? NEB : n > 0.6 && hw > 2 ? DEEP : VOID;
        return;
      }
      if (o.mask) continue;
      const lip = hw > 0.6 ? ad - hw : ad;
      if (GH) { if (lip < 1.0) { out.c = st.cool < 1 ? WHITE : LIP[Math.min(4, st.cool)]; return; } continue; }
      if (lip < (st.snap ? 1.4 : 0.85)) { out.c = LIP[Math.min(4, st.cool + (Y < oc || st.snap ? 0 : 1))]; return; }
      if (st.cool < 3 && lip < 1.9 && hw > 0.8 && hn > 0.15) { out.c = RIM; return; }
      if (st.cool < 2 && lip < 2.9 && hw > 2.2 && hn > 0.6) { out.c = RIM2; out.a = 0.85; return; }
    }
  });
  if (o.mask) return;
  const st0 = state(T), M0 = strokes[0];
  // the tearing head racing out; glow along the open tear; light spilling up and down out of it
  if (T < 1.0) { const x = L * st0.ext; p.glow(x, -0.5, 9, LIP[1], 0.7 * (1 - T)); p.px(x, -1, WHITE); }
  for (let i = 0; i <= 12; i++) {
    const v = i / 12, op = ov(T, v) * tprof(v), x = L * v, y = -v;
    if (v > st0.ext || v < st0.tl) continue;
    if (op > 0.05) p.glow(x, y, 8, LIP[3], 0.22 * op);
    if (st0.snap) p.glow(x, y, 9, LIP[1], 0.5 * tprof(v));
    if (op > 0.35 && i > 0 && i < 12) {
      const fl = 0.55 + 0.45 * Math.sin(t * 50 + i * 2.7), Lr = (6 + 16 * op) * fl, h0 = 7 * op;
      for (const sd of [1, -1]) {
        p.glowLine(x, y + sd * h0, x, y + sd * (h0 + Lr), 2.4, LIP[2], 0.5 * op * fl);
        p.line(x, y + sd * h0, x, y + sd * (h0 + Lr * 0.45), LIP[1], 0.3 * op * fl);
      }
    }
  }
  // a highlight sliding along the lip while it is open
  if (T > 1 && T < 5.2) {
    const hv = clamp((T - 1) / 3.8);
    for (let i = -3; i <= 3; i++) {
      const v = hv + i * 0.012;
      if (v < 0 || v > 1) continue;
      const hw = 7 * tprof(v) * ov(T, v), x = L * v;
      p.px(x, -v - hw - 0.8, i === 0 ? WHITE : LIP[1], 1 - Math.abs(i) * 0.25);
      if (i === 0) p.glow(x, -v, 6, LIP[1], 0.45);
    }
  }
  // the snap: a flash along the tear and echoes of its line rippling up and down
  const snapT = 5.5 * FR;
  if (t > snapT && t < snapT + 0.1) for (let i = 0; i <= 12; i++) p.glow((L * i) / 12, -i / 12, 12, LIP[0], 0.5 * (1 - (t - snapT) / 0.1));
  for (const [dl, amp] of [[0, 1], [0.035, 0.7]]) {
    const k = (t - snapT - dl) / 0.16;
    if (k < 0 || k > 1) continue;
    for (const sd of [-1, 1]) {
      const off = sd * (2 + 9 * ease.outCubic(k)) * amp, pts = [];
      for (let i = 0; i <= 30; i++) { const v = i / 30; pts.push([L * v, -v + off * tprof(v)]); }
      p.polyline(pts, k < 0.35 ? LIP[1] : LIP[3], (1 - k) * amp);
    }
  }
}
