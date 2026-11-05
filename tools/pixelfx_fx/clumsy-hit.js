// Clumsy Valor's everyday enemy hit: an ink four-point star rimmed white on the impact frame with a long cut line
// across it along the blow, then a white diamond core, a crisp gold ring thrown out and thinning to a dotted
// ghost, two tapered flares raking along the blow and a few sharp ink-edged chips flung forward and slowing.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Clumsy hit",
  desc: "Ink four-point star rimmed white with a cut line, white diamond core, crisp gold ring thinning to dots, two tapered flares and sharp chips along the blow.",
  tags: ["impact", "hit", "combat", "directional", "one-shot"],
  size: [120, 90],
  origin: [48, 45],
  duration: 0.3,
  loop: false,
  fps: 50,
  options: { seed: 1 },
};

const G0 = hex("#fff3b0"), G1 = hex("#ffd34d"), G2 = hex("#ff8a3d"), G3 = hex("#c2304a"), INK = hex("#120509"), INK2 = hex("#3a1424");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };

// a four-point star: radius r along the four arms, pinched to k*r between them; tilt a; long arm stretched by L
function starR(ang, r, k, tilt, L) {
  const u = ang - tilt, c = Math.abs(Math.cos(2 * u));
  const arm = Math.pow(c, 2.4);
  const along = Math.max(0, Math.cos(u)) ** 8;   // the forward arm runs longer
  return r * (k + (1 - k) * arm) * (1 + L * along);
}

function star(p, r, k, tilt, L, rim, fill) {
  const M = Math.ceil(r * (1 + L) + 3);
  p.shade(-M, -M, M, M, (x, y, out) => {
    const d = Math.hypot(x, y), R = starR(Math.atan2(y, x), r, k, tilt, L);
    if (d <= R - 1.4) out.c = fill;
    else if (d <= R + 0.2) out.c = rim;
  });
}

// a tapered flare: fat at the root, a hair at the tip, white cooling to gold
function flare(p, a, r0, L, w) {
  const c = Math.cos(a), s = Math.sin(a);
  for (let d = 0; d <= L; d += 0.5) {
    const u = d / L, hw = w * Math.pow(1 - u, 1.5), x = c * (r0 + d), y = s * (r0 + d);
    p.px(x, y, u < 0.45 ? WHITE : u < 0.8 ? G0 : G1);
    for (let o = 0.5; o <= hw; o += 0.5) for (const e of [-o, o]) p.px(x - s * e, y + c * e, o > hw - 0.6 ? G1 : G0);
  }
}

// a sharp chip: a slim triangle pointing along its flight, ink-edged
function chip(p, x, y, a, len, w, col) {
  const c = Math.cos(a), s = Math.sin(a);
  const pts = [[x + c * len, y + s * len], [x - s * w, y + c * w], [x + s * w, y - c * w]];
  p.poly(pts.map(([px, py]) => [px + c * 0.8, py + s * 0.8]), INK);
  p.poly(pts, col);
}

export function draw(p, t, o) {
  const sd = o.seed * 17.3, F = t / 0.02;
  const tilt = (hash(sd) - 0.5) * 0.5, cut = tilt * 0.6 - 0.12;
  // the cut line: a hair-thin white slash across the blow, ink beneath, shrinking from both ends
  if (t < 0.12) {
    const k = clamp(t / 0.12), L = 44 * (1 - ease.inCubic(k)) + 6, c = Math.cos(cut), s = Math.sin(cut), off = 10 * ease.outCubic(k);
    p.line(-c * (L * 0.55) + off * c, -s * (L * 0.55) + 1, c * L + off * c, s * L + 1, INK);
    p.line(-c * (L * 0.55) + off * c, -s * (L * 0.55), c * L + off * c, s * L, k < 0.4 ? WHITE : G0);
  }
  if (F < 2) {
    // the impact frame: an ink star rimmed white, the forward arm long
    star(p, F < 1 ? 14 : 18, 0.22, tilt, 0.8, WHITE, INK);
    star(p, F < 1 ? 6 : 7, 0.3, tilt, 0.5, WHITE, WHITE);
    p.glow(0, 0, 26, G1, 0.35);
    return;
  }
  // the ring: two crisp crescents thrown out fast (gaps along the blow), thinning, then a dotted ghost
  const rk = clamp((t - 0.04) / 0.17), R = 6 + 16 * ease.outQuart(rk), w = Math.max(0, 3.4 * (1 - rk) ** 1.2);
  if (rk < 1) {
    const col = rk < 0.2 ? WHITE : rk < 0.45 ? G0 : rk < 0.7 ? G1 : G2;
    const M = Math.ceil(R + 4);
    p.shade(-M, -M, M, M, (x, y, out) => {
      const a = Math.atan2(y, x) - tilt, d = Math.hypot(x, y * 1.15);
      const s2 = Math.abs(Math.sin(a));                      // 0 along the blow, 1 across
      if (s2 < 0.28 + 0.2 * rk) return;                       // the gaps widen as it goes
      const ww = w * (0.4 + 0.6 * s2);                         // fat across the blow, tapering to the gaps
      if (ww > 0.6 ? d >= R - ww && d <= R : (Math.abs(d - R) < 0.5 && ((Math.floor(a * 9) & 1) === 0))) out.c = ww > 1.6 && d < R - ww + 1 ? INK2 : col;
    });
  }
  // the core: a white star collapsing to a diamond, then out
  const ck = clamp((t - 0.04) / 0.08);
  if (ck < 1) {
    const r = 11 * (1 - ease.inQuad(ck)) + 1;
    star(p, r, 0.22 + 0.4 * ck, tilt, 0.5 * (1 - ck), G1, WHITE);
  }
  // two tapered flares along the blow, reaching then burning away from the root
  const fk = clamp((t - 0.04) / 0.14);
  if (fk < 1) {
    for (let i = 0; i < 2; i++) {
      const a = tilt + (i ? -0.42 : 0.18) + (hash(sd + i) - 0.5) * 0.2;
      const L = (i ? 22 : 36) * ease.outCubic(Math.min(1, fk * 2.2)), r0 = 6 + 22 * ease.inQuad(fk);
      flare(p, a, r0, Math.max(1, L * (1 - fk)), (i ? 2.0 : 2.8) * (1 - fk));
    }
  }
  // sharp chips flung forward, slowing, shrinking
  const pk = clamp((t - 0.04) / 0.24);
  if (pk < 1) {
    for (let i = 0; i < 4; i++) {
      const a = tilt + (hash(sd + 9 + i) - 0.5) * 1.6, v = 26 + hash(sd + 20 + i) * 22;
      const d = 6 + v * ease.outCubic(pk), drop = 6 * pk * pk;
      const len = (6 + hash(sd + 30 + i) * 4) * (1 - pk * 0.7), wd = 2.0 * (1 - pk * 0.5);
      chip(p, Math.cos(a) * d, Math.sin(a) * d + drop, a + pk * (i % 2 ? 0.8 : -0.8), len, wd, pk < 0.35 ? WHITE : pk < 0.7 ? G1 : G3);
    }
  }
  const pop = Math.exp(-(t - 0.04) / 0.05);
  if (pop > 0.03) p.glow(0, 0, 22, G1, 0.3 * pop);
}
