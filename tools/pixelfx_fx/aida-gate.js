// Aida's rift gate, after the game's tear-line gate: three eye-tears standing on the floor; it tears down from the
// top and opens like an eye, stares (a seamless loop the game holds while she passes), then shuts with a white snap,
// its lip cooling white -> violet, and a moment later the not-quite-healed cut opens once more as a window onto the
// game in negative (the mask pass), framed by a bright line.
import { Rng, clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Aida gate",
  desc: "A rift tears down and opens like an eye, stares in a loop, snaps shut white and reopens once as a negative window.",
  tags: ["arcane", "portal", "rift", "void", "tear", "gate", "one-shot"],
  size: [128, 150],
  origin: [64, 134],
  duration: 1.12,
  loop: false,
  fps: 50,
  options: { h: 100, w: 1.3, seed: 6, mask: 0 },
};

const LIP = ["#ffffff", "#e8d4ff", "#c9a0ff", "#9a62e0", "#5a2a9e"].map(hex), RIM = hex("#b07aff"), RIM2 = hex("#5a1e9e"), VOID = hex("#06020a"), DEEP = hex("#1a0830"), NEB = hex("#3a1260");
const FR = 0.04, OPEN = 0.12, HOLD = 0.4, CLOSE = OPEN + HOLD, OM = (Math.PI * 2) / HOLD;   // the hold loops seamlessly
export const timing = { open: OPEN, holdFrom: OPEN, holdTo: CLOSE };

const eo = (x) => 1 - Math.pow(1 - clamp(x), 3), smo = (x) => { x = clamp(x); return x * x * (3 - 2 * x); };
function state(tt) {
  const cool = tt < 6.1 ? 0 : tt < 7.2 ? 1 : tt < 8.4 ? 2 : tt < 9.4 ? 3 : 4;
  return { ext: eo(tt / 0.8), tl: tt < 9 ? 0 : eo((tt - 9) / 1.4), cool, snap: tt >= 5.5 && tt < 6.1 };
}
const ov = (tt, v) => { const e = Math.min(1, Math.abs(v - 0.55) / 0.5); return smo((tt - 0.45 - 0.55 * e) / 1.7) * (1 - smo((tt - 3.9 - 0.5 * (1 - e)) / 1.25)); };
const almond = (v) => Math.pow(Math.sin(Math.PI * clamp(v)), 0.8);

function world(o) {
  const key = JSON.stringify([o.h, o.w, o.seed]);
  if (o._w && o._w.key === key) return o._w;
  const R = new Rng(o.seed), w = o.w;
  // stroke: lateral offset at top/bottom, lo, hi (along), width, delay (tear frames), ghost
  const ST = [[0, 0, 0, 1, 7.5 * w, 0, 0], [-6 * w, -4 * w, 0.08, 0.8, 2 * w, 0.5, 0], [5 * w, 7 * w, 0.3, 0.98, 1.3 * w, 0.8, 0], [0, 0, 0.04, 0.96, 5.2 * w, 7.0, 1]];
  const strokes = ST.map((s) => ({ s, wob: Array.from({ length: 31 }, () => R.next()), wid: Array.from({ length: 23 }, () => R.next()), rim: Array.from({ length: 57 }, () => R.next()) }));
  const sparks = new Set();
  for (let i = 0; i < 4000; i++) if (R.chance(0.06)) sparks.add(i);
  return (o._w = { key, strokes, sparks });
}

// the tear clock: tears open, holds at 3 while she passes, then runs on
const clock = (t) => (t < OPEN ? (t / OPEN) * 3 : t < CLOSE ? 3 : 3 + (t - CLOSE) / FR);
const anim = (t) => (t < OPEN || t >= CLOSE ? t : OPEN + ((t - OPEN) % HOLD));   // the time the shimmer runs on

export function draw(p, t, o) {
  const { strokes, sparks } = world(o);
  const T = clock(t), ta = anim(t), L = o.h, W = 14 * o.w;
  p.shade(-Math.ceil(W + 6), -Math.ceil(L + 4), Math.ceil(W + 6), 2, (xx, yy, out) => {
    const u = (yy + 0.5 + L) / L, pd = -(xx + 0.5);
    if (u < -0.02 || u > 1.02) return;
    for (const S of strokes) {
      const [o0, o1, lo, hi, WW, DL, GH] = S.s, tt = T - DL;
      if (tt < 0 || tt > 10.5 || (o.mask && !GH)) continue;
      const st = state(tt), v = (u - lo) / (hi - lo);
      if (v < st.tl || v > st.ext || v < 0 || v > 1) continue;
      const oc = o0 + (o1 - o0) * v + (S.wob[clamp(Math.floor(u * 30), 0, 30)] - 0.5) * 1.2;
      const hw = WW * almond(v) * ov(tt, v) * (0.6 + 0.8 * S.wid[clamp(Math.floor(u * 22), 0, 22)]);
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
      if (lip < (st.snap ? 1.4 : 0.85)) { out.c = LIP[Math.min(4, st.cool + (dist < 0 || st.snap ? 0 : 1))]; return; }
      if (st.cool < 3 && lip < 1.9 && hw > 0.8 && hn > 0.15) { out.c = RIM; return; }
      if (st.cool < 2 && lip < 2.9 && hw > 2.2 && hn > 0.6) { out.c = RIM2; out.a = 0.85; return; }
    }
  });
  if (o.mask) return;
  const S0 = strokes[0], [, , , , WW0] = S0.s, st0 = state(T);
  // glow along the open gate; light spilling sideways out of it, flickering in the loop
  for (let i = 0; i <= 12; i++) {
    const v = i / 12, op = ov(T, v) * almond(v), y = -L + L * v;
    if (v > st0.ext || v < st0.tl) continue;
    if (op > 0.05) p.glow(0, y, 6 + WW0, LIP[3], 0.22 * op);
    if (st0.snap) p.glow(0, y, 9, LIP[1], 0.5 * almond(v));
    if (op > 0.35 && i > 0 && i < 12) {
      const fl = 0.55 + 0.45 * Math.sin(ta * OM * 2 + i * 2.7), Lr = (8 + 20 * op) * fl, h0 = WW0 * 1.3 * op;
      for (const sd of [1, -1]) {
        p.glowLine(sd * h0, y, sd * (h0 + Lr), y, 2.6, LIP[2], 0.55 * op * fl);
        p.line(sd * h0, y, sd * (h0 + Lr * 0.45), y, LIP[1], 0.3 * op * fl);
      }
    }
  }
  // the tearing head racing down, and a highlight sliding down the lip while it stares
  if (T < 1.2) { const y = -L + L * st0.ext; p.glow(0, y, 9, LIP[1], 0.7 * (1 - T / 1.2)); p.px(0, y, WHITE); }
  if (t >= OPEN && t < CLOSE) {
    const hv = ((t - OPEN) % HOLD) / HOLD;
    for (let i = -3; i <= 3; i++) {
      const v = hv + i * 0.015;
      if (v < 0 || v > 1) continue;
      const hw = WW0 * almond(v) * ov(T, v), y = -L + L * v;
      for (const sd of [-1, 1]) p.px(sd * (hw + 0.8), y, i === 0 ? WHITE : LIP[1], 1 - Math.abs(i) * 0.25);
      if (i === 0) p.glow(0, y, 7, LIP[1], 0.45);
    }
  }
  // the snap: a flash down the line, and echoes of it rippling out sideways
  const snapT = CLOSE + 2.5 * FR;
  if (t > snapT && t < snapT + 0.1) for (let i = 0; i <= 10; i++) p.glow(0, -L + (L * i) / 10, 12, LIP[0], 0.55 * (1 - (t - snapT) / 0.1));
  for (const [dl, amp] of [[0, 1], [0.035, 0.7]]) {
    const k = (t - snapT - dl) / 0.16;
    if (k < 0 || k > 1) continue;
    for (const sd of [-1, 1]) {
      const off = sd * (3 + 14 * ease.outCubic(k)) * amp, pts = [];
      for (let i = 0; i <= 20; i++) { const v = 0.05 + 0.9 * (i / 20); pts.push([off * almond(v), -L + L * v]); }
      p.polyline(pts, k < 0.35 ? LIP[1] : LIP[3], (1 - k) * amp);
    }
  }
}
