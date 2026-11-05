// Kenin's sticky bomb while its fuse burns (loop, origin at the bomb's middle): a round soot-iron shell with an olive
// strap and a brass cap, a highlight, a tacky olive smear where it grips, a short fuse curling up, and the fuse tip
// spitting sparks. `hot` (last stretch): the shell's warning lamp blinks red fast and the fuse throws twice the sparks.
import { WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Kenin bomb",
  desc: "Soot-iron sticky bomb with olive strap, brass cap, grip smear and a curling fuse spitting sparks (loop); hot: red lamp blinking fast, more sparks.",
  tags: ["bomb", "fuse", "kenin", "loop"],
  size: [40, 40],
  origin: [20, 24],
  duration: 0.4,
  loop: true,
  fps: 50,
  options: { seed: 5, hot: 0 },
};

const K0 = hex("#1a1714"), K1 = hex("#2c2823"), K2 = hex("#45403a"), K3 = hex("#6b645b"), OV = hex("#9cc14a"), OVD = hex("#5f7a2a"), OL = hex("#e2f5b8");
const BR = hex("#f1c35a"), BRD = hex("#a8742a"), CR = hex("#fff4cf"), Y = hex("#ffd06a"), O = hex("#f08a3a"), RD = hex("#ff4a2a"), RDD = hex("#7a1e14");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };

export function draw(p, t, o) {
  const F = Math.floor(t / 0.02), hot = !!o.hot;
  // the grip smear under it
  for (let x = -5; x <= 5; x++) p.px(x, 5, Math.abs(x) > 3 ? OVD : OV);
  p.px(-2, 6, OVD); p.px(3, 6, OVD); if ((F >> 2) % 2) p.px(3, 7, OVD);
  // the shell
  const R = 4.6;
  for (let y = -5; y <= 5; y++) for (let x = -5; x <= 5; x++) {
    const d = Math.hypot(x + 0.3, y + 0.3);
    if (d > R) continue;
    const lit = (-x - y) / 7;
    p.px(x, y, d > R - 1 ? K0 : lit > 0.45 ? K3 : lit > 0.05 ? K2 : K1);
  }
  p.px(-2, -3, OL); p.px(-3, -2, K3);
  // the strap across it
  for (let x = -4; x <= 4; x++) p.px(x, 1, Math.abs(x) === 4 ? OVD : x < 0 ? OV : OVD);
  // the warning lamp on the strap
  const on = hot ? (F % 4) < 2 : (F % 20) < 3;
  p.px(1, 1, on ? RD : RDD); if (on) { p.px(1, 0, hot ? CR : RD); p.glow(1, 1, hot ? 5 : 3, RD, hot ? 0.4 : 0.3); }
  // the brass cap and the fuse curling up
  p.px(0, -5, BRD); p.px(1, -5, BR); p.px(-1, -5, BRD); p.px(0, -6, BR);
  const fuse = [[0, -7], [1, -8], [1, -9], [2, -10]];
  for (const [x, y] of fuse) p.px(x, y, hex("#7a6a52"));
  const [tx, ty] = fuse[fuse.length - 1];
  // the tip burning, spitting sparks
  p.px(tx, ty, (F & 1) ? CR : Y); p.px(tx + 1, ty - 1, (F & 1) ? Y : O);
  p.glow(tx, ty, hot ? 6 : 4, Y, 0.5);
  const n = hot ? 8 : 4;
  for (let i = 0; i < n; i++) {
    const life = 0.14, q = ((t + hash(o.seed + i) * life) % life) / life;
    const a = -Math.PI / 2 + (hash(o.seed + 10 + i + Math.floor((t + hash(o.seed + i) * life) / life) * 3) - 0.5) * 2.6;
    const v = 6 + hash(o.seed + 20 + i) * 6;
    const x = tx + Math.cos(a) * v * q, y = ty + Math.sin(a) * v * q + 8 * q * q;
    p.px(x, y, q < 0.3 ? WHITE : q < 0.6 ? Y : O);
  }
}
