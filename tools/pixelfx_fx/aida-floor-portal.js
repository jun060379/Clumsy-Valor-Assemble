// Aida's floor portal (처형), a clean modern take: a horizontal line draws out and the void eases open into a
// crisp ellipse; thin arc rings draw on and turn against each other with tick marks; a hairline beam lifts from
// the centre; then it collapses back to the line and blinks. Far half (half -1) behind her, near half (1) in front.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Aida floor portal",
  desc: "A clean floor portal: a line draws out, the void eases open, thin arc rings turn with tick marks, a hairline beam lifts, it collapses and blinks.",
  tags: ["arcane", "portal", "rift", "void", "floor", "modern", "one-shot"],
  size: [180, 84],
  origin: [90, 54],
  duration: 0.34,
  loop: false,
  fps: 50,
  options: { R: 50, half: 0 },
};

const W2 = hex("#e8d4ff"), V1 = hex("#c9a0ff"), V2 = hex("#9a62e0"), V3 = hex("#5a2a9e"), VOID = hex("#06020a"), DEEP = hex("#140624");
const SQ = 0.27, TAU = Math.PI * 2;

function arc(p, rx, ry, a0, a1, c, half, alpha = 1, step = 0.012) {
  for (let a = a0; a <= a1; a += step) {
    const y = Math.sin(a) * ry;
    if (half !== 0 && (half < 0 ? y >= 0 : y < 0)) continue;
    p.px(Math.round(Math.cos(a) * rx), Math.round(y), c, alpha);
  }
}

export function draw(p, t, o) {
  const u = t / meta.duration, R = o.R, half = o.half;
  const line = ease.outExpo(clamp(u / 0.14)), open = ease.outBack(clamp((u - 0.08) / 0.18), 1.4) * (1 - ease.inCubic(clamp((u - 0.74) / 0.18)));
  const rx = R * (0.2 + 0.8 * line), ry = Math.max(0, R * SQ * open);
  const show = (y) => half === 0 || (half < 0 ? y < 0 : y >= 0);
  // the line: draws out from the centre, and is all that is left as it shuts
  if (u < 0.12 || u > 0.9) {
    if (half >= 0) {
      const k = u > 0.9 ? 1 - (u - 0.9) / 0.1 : 1;
      p.line(-rx, 0, rx, 0, WHITE, k);
      p.line(-rx * 1.25, 0, -rx * 1.05, 0, V1, k); p.line(rx * 1.05, 0, rx * 1.25, 0, V1, k);
      p.glowLine(-rx, 0, rx, 0, 4, W2, 0.5 * k);
    }
    if (u < 0.12) return;
  }
  // the void: a crisp ellipse, a faint inner contour turning in it for depth
  if (ry >= 1) {
    p.shade(-Math.ceil(rx), -Math.ceil(ry), Math.ceil(rx), Math.ceil(ry), (xx, yy, out) => {
      const X = xx + 0.5, Y = yy + 0.5;
      if (!show(Y)) return;
      const e = (X * X) / (rx * rx) + (Y * Y) / (ry * ry);
      if (e > 1) return;
      out.c = e > 0.82 ? (Y < 0 ? V3 : DEEP) : VOID;
    });
    arc(p, rx * 0.55, ry * 0.55, t * 6, t * 6 + TAU * 0.7, V3, half, 0.9);
    // the rim: one clean pixel, white on the far side, violet on the near
    arc(p, rx, ry, 0, TAU, W2, half);
    arc(p, rx, ry, Math.PI * 1.15, Math.PI * 1.85, WHITE, half);
  }
  // two thin rings drawing on and turning against each other, with ticks at the quarters
  const draw1 = ease.outCubic(clamp((u - 0.1) / 0.2)), fade = 1 - clamp((u - 0.8) / 0.12);
  if (draw1 > 0 && fade > 0) {
    const r1x = rx * 1.22 + 2, r1y = Math.max(1.5, ry * 1.22 + 1), r2x = rx * 1.42 + 4, r2y = Math.max(2, ry * 1.42 + 1.5);
    for (let i = 0; i < 3; i++) arc(p, r1x, r1y, t * 5 + (i * TAU) / 3, t * 5 + (i * TAU) / 3 + 1.6 * draw1, V1, half, fade);
    for (let i = 0; i < 2; i++) arc(p, r2x, r2y, -t * 3.5 + i * Math.PI, -t * 3.5 + i * Math.PI + 0.9 * draw1, V2, half, fade * 0.85);
    for (const q of [0, 1, 2, 3]) {
      const a = (q * TAU) / 4, x = Math.round(Math.cos(a) * r2x), y = Math.round(Math.sin(a) * r2y);
      if (!show(y === 0 ? 0 : y)) continue;
      if (q % 2 === 0) { p.px(x, y, WHITE, fade); p.px(x + Math.sign(x), y, W2, fade); p.px(x + 2 * Math.sign(x), y, V2, fade); }
      else { p.px(x, y, W2, fade); p.px(x, y + Math.sign(y), V2, fade); }
    }
  }
  // a hairline beam lifting from the centre as it opens, thinning out
  const bk = clamp((u - 0.12) / 0.3);
  if (half <= 0 && bk > 0 && bk < 1) {
    const top = -ry - 4 - 36 * ease.outCubic(bk), k = 1 - bk;
    p.line(0, -ry, 0, top, WHITE, k);
    p.line(0, top, 0, top - 6, W2, k * 0.6);
    p.glowLine(0, -ry, 0, top, 3, V1, 0.4 * k);
  }
}
