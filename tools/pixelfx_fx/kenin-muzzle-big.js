// Kenin's hand-cannon finisher (faces right, origin at the muzzle): a wide fan of flame, a white core, an upright
// shock ring thrown forward, a thick smoke bank rolling out, two casings, heavy sparks.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Kenin muzzle big",
  desc: "Wide flame fan with a white core, an upright shock ring thrown forward, a rolling smoke bank, sparks, a casing.",
  tags: ["gun", "muzzle", "kenin", "one-shot"],
  size: [160, 104],
  origin: [44, 52],
  duration: 0.5,
  loop: false,
  fps: 50,
  options: { seed: 2 },
};

const CR = hex("#fff4cf"), Y = hex("#ffd06a"), O = hex("#f08a3a"), R = hex("#8c4a2a"), BR = hex("#f1c35a"), BRD = hex("#a8742a"), OL = hex("#e2f5b8");
const S1 = hex("#8a8276"), S2 = hex("#5e584f"), S3 = hex("#3e3a34");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };

export function draw(p, t, o) {
  const F = Math.floor(t / 0.02), sd = o.seed * 2.7;
  if (F < 5) {
    const k = [1, 0.9, 0.7, 0.45, 0.25][F];
    // the fan: rows of flame spreading forward
    for (let i = 0; i <= 46 * k; i++) {
      const u = i / (46 * k), hw = (2 + u * 14) * k * (1 - u * 0.4);
      for (let j = -Math.ceil(hw); j <= Math.ceil(hw); j++) {
        const q = Math.abs(j) / Math.max(0.5, hw);
        if (q > 1 || (u > 0.6 && hash(i * 7 + j * 13 + F) < (u - 0.6) * 1.8)) continue;
        p.px(i, j, q < 0.3 && u < 0.5 ? WHITE : q < 0.55 && u < 0.7 ? CR : q < 0.8 ? Y : u > 0.7 ? R : O);
      }
    }
    for (let i = 0; i <= 14 * k; i++) { p.px(3, -i, i < 6 ? CR : Y); p.px(3, i, i < 6 ? CR : Y); }
    if (F < 2) p.disc(2, 0, 7, WHITE, 1);
    p.glow(14, 0, 40, Y, 0.6 * k);
  }
  // the shock ring thrown forward
  const rk = clamp(t / 0.22);
  if (rk < 1) {
    const ry = 8 + 26 * ease.outCubic(rk), rx = ry * 0.3, cx = 8 + 40 * ease.outCubic(rk), n = Math.floor(ry * 4);
    for (let i = 0; i < n; i++) { const a = (i / n) * Math.PI * 2; if (rk > 0.5 && i % 2) continue; p.px(cx + Math.cos(a) * rx, Math.sin(a) * ry, rk < 0.3 ? WHITE : rk < 0.6 ? OL : Y); }
  }
  // the smoke bank
  for (let i = 0; i < 9; i++) {
    const st = 0.03 + i * 0.012, k = clamp((t - st) / 0.45);
    if (t < st || k >= 1) continue;
    const x = 10 + i * 5 + ease.outCubic(k) * (20 + i * 4), y = (hash(sd + i) - 0.5) * 16 - ease.outCubic(k) * (6 + i);
    const r = 3 + k * 5 + (i % 3), c = k < 0.3 ? S1 : k < 0.65 ? S2 : S3;
    if (k > 0.7 && ((i + F) & 1)) continue;
    p.disc(x, y, r, c, 1);
    if (k < 0.5) p.disc(x - r * 0.3, y - r * 0.4, r * 0.4, S1, 1);
  }
  // sparks
  const pk = clamp(t / 0.25);
  if (pk < 1) for (let i = 0; i < 12; i++) {
    const a = (hash(sd + 9 + i) - 0.5) * 1.3, v = 40 + hash(sd + 19 + i) * 50;
    const x = Math.cos(a) * v * ease.outCubic(pk) + 6, y = Math.sin(a) * v * ease.outCubic(pk) + 14 * pk * pk;
    p.px(x, y, pk < 0.4 ? CR : pk < 0.7 ? Y : O); if (pk < 0.5) p.px(x - 1, y, O);
  }
  // the casing
  const ck = clamp(t / 0.5), cx = -12 - ck * 26, cy = -8 - 40 * ck + 80 * ck * ck, fl = Math.floor(t / 0.04) % 4;
  const dx = [1, 1, 0, -1][fl], dy = [0, 1, 1, 1][fl];
  p.px(cx, cy, BR); p.px(cx + dx, cy + dy, BR); p.px(cx + dx * 2, cy + dy * 2, fl % 2 ? BRD : BR);
}
