// Kenin's pistol shot (faces right, origin at the muzzle): a hot cross-shaped flash with a forward tongue of flame,
// a puff of smoke rolling forward and up, a brass casing kicked up and back that tumbles and falls.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Kenin muzzle",
  desc: "Cross-shaped muzzle flash with a flame tongue, a forward smoke puff, a brass casing kicked back and tumbling.",
  tags: ["gun", "muzzle", "kenin", "one-shot"],
  size: [96, 72],
  origin: [36, 36],
  duration: 0.36,
  loop: false,
  fps: 50,
  options: { seed: 1, big: 0 },
};

const CR = hex("#fff4cf"), Y = hex("#ffd06a"), O = hex("#f08a3a"), R = hex("#8c4a2a"), BR = hex("#f1c35a"), BRD = hex("#a8742a");
const S1 = hex("#8a8276"), S2 = hex("#5e584f"), S3 = hex("#3e3a34");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };

export function draw(p, t, o) {
  const F = Math.floor(t / 0.02), sd = o.seed * 3.1;
  // the flash: two frames hot, one cooling
  if (F < 3) {
    const k = F === 0 ? 1 : F === 1 ? 0.75 : 0.4;
    const L = 22 * k, V = 7 * k;
    for (let i = 0; i <= L; i++) { const u = i / L, c = u < 0.3 ? WHITE : u < 0.6 ? CR : u < 0.85 ? Y : O; p.px(i, 0, c); if (u < 0.6) { p.px(i, -1, u < 0.3 ? CR : Y); p.px(i, 1, u < 0.3 ? CR : Y); } if (u < 0.3) { p.px(i, -2, Y); p.px(i, 2, Y); } }
    for (let i = 0; i <= V; i++) { const c = i < V * 0.5 ? CR : Y; p.px(2, -i, c); p.px(2, i, c); }
    for (let i = 0; i <= V * 0.8; i++) { p.px(2 + i, -i * 0.8, i < 3 ? CR : O); p.px(2 + i, i * 0.8, i < 3 ? CR : O); }
    if (F === 0) p.disc(1, 0, 3.5, WHITE, 1);
    p.glow(6, 0, 18, Y, 0.55 * k);
  }
  // smoke rolling forward and up
  for (let i = 0; i < 5; i++) {
    const st = 0.02 + i * 0.015, k = clamp((t - st) / 0.3);
    if (t < st || k >= 1) continue;
    const x = 6 + i * 3 + ease.outCubic(k) * (14 + i * 3), y = -ease.outCubic(k) * (6 + i * 2) + (hash(sd + i) - 0.5) * 4;
    const r = 1.5 + k * 3 + (i % 2), c = k < 0.3 ? S1 : k < 0.65 ? S2 : S3;
    if (k > 0.7 && ((i + F) & 1)) continue;
    p.disc(x, y, r, c, 1);
    if (k < 0.5) p.px(x - r * 0.4, y - r * 0.5, S1);
  }
  // the casing: kicked up and back from just behind the muzzle, tumbling, falling
  const ck = clamp(t / 0.36);
  const cx = -10 - ck * 22, cy = -6 - 34 * ck + 70 * ck * ck;
  const flip = Math.floor(t / 0.04) % 4;
  const dx = [1, 1, 0, -1][flip], dy = [0, 1, 1, 1][flip];
  p.px(cx, cy, BR); p.px(cx + dx, cy + dy, flip % 2 ? BRD : BR); if (ck < 0.25) p.px(cx - dx, cy - dy, Y);
  // sparks
  if (t < 0.12) for (let i = 0; i < 5; i++) {
    const k = t / 0.12, a = (hash(sd + 9 + i) - 0.5) * 1.1, v = 18 + hash(sd + 19 + i) * 20;
    p.px(Math.cos(a) * v * k + 4, Math.sin(a) * v * k, k < 0.5 ? CR : O);
  }
}
