// The orb becomes the spear: the orb flashes and squeezes flat, a hairline of light shoots out both ways along the
// flight, the cross and its ring stamp on, the blade fills from the guard to the point; the last frame is luce-spear's.
import { clamp, ease, WHITE, hex } from "../../core/index.js";
import { draw as spear } from "./luce-spear.js";

export const meta = {
  name: "Luce spear form",
  desc: "The orb flashes and squeezes flat, a hairline shoots out along the flight, the cross stamps on, the blade fills to the point.",
  tags: ["holy", "transform", "spear", "one-shot"],
  size: [132, 32],
  origin: [84, 16],
  duration: 0.1,
  loop: false,
  fps: 50,
  options: {},
};

const W1 = hex("#fff8dc"), G0 = hex("#ffecaa"), G1 = hex("#ffc85a");

export function draw(p, t) {
  const F = Math.round(t / 0.02);
  if (F >= 5) { spear(p, 0); return; }
  if (F <= 1) {
    // the flash: the orb swells white, then squeezes into a lens
    const rx = F === 0 ? 7 : 10, ry = F === 0 ? 7 : 3;
    p.shade(-rx - 1, -ry - 1, rx + 1, ry + 1, (x, y, out) => {
      const d = Math.hypot(x / rx, y / ry);
      if (d <= 1) out.c = d < 0.6 ? WHITE : W1;
      else if (d <= 1.25) out.c = G1;
    });
    const L = F === 0 ? 10 : 16;
    for (let i = 0; i <= L; i++) { p.px(i, 0, WHITE); p.px(-i, 0, W1); }
    p.glow(0, 0, 16, G0, 0.6);
    return;
  }
  // the hairline out both ways, then the blade filling forward
  const k = (F - 1) / 4, reach = -14 + 54 * ease.outCubic(k);
  p.line(-40 * k - 8, 0, 44, 0, F < 3 ? WHITE : G0);
  for (let u = -12; u < reach; u++) { const hw = u < 3 ? 1 : 2 * Math.pow(1 - (u - 3) / 37, 0.7); p.px(u, -Math.round(hw), G1); p.px(u, Math.round(hw), G1); p.px(u, 0, WHITE); }
  for (let y = -7; y <= 7; y++) p.px(-2, y, Math.abs(y) < 2 ? WHITE : W1);
  for (let i = 0; i < 40; i++) { const a = (i / 40) * Math.PI * 2; p.px(-2 + Math.cos(a) * (5 + (4 - F)), Math.sin(a) * (5 + (4 - F)), G1); }
  p.glow(0, 0, 14, G0, 0.4 * (1 - k));
}
