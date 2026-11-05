// Kenin's sticky bomb going off (origin at the bomb): a white flash, a fireball punching out in lumps (cream heart,
// yellow, orange, a red-brown rim) and rising as it burns, a ground shock ring sweeping out, chunks and sparks thrown
// up and falling, then the smoke blooms dark and is gone fast. About 0.6 s.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Kenin boom",
  desc: "White flash, lumpy fireball rising (cream/yellow/orange/red-brown), ground shock ring, chunks and sparks, quick dark smoke bloom.",
  tags: ["explosion", "bomb", "kenin", "one-shot"],
  size: [200, 180],
  origin: [100, 120],
  duration: 0.62,
  loop: false,
  fps: 50,
  options: { seed: 4 },
};

const CR = hex("#fff4cf"), Y = hex("#ffd06a"), O = hex("#f08a3a"), R = hex("#8c4a2a"), D = hex("#3a2a22"), OL = hex("#e2f5b8"), OV = hex("#9cc14a");
const S1 = hex("#7a7268"), S2 = hex("#55504a"), S3 = hex("#3a3632");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };

export function draw(p, t, o) {
  const F = Math.floor(t / 0.02), sd = o.seed * 3.3;
  // flash
  if (F < 2) { p.disc(0, 0, F ? 22 : 28, WHITE, 1); p.glow(0, 0, 60, CR, 0.8); }
  // the ground shock ring (the bomb sits on the foe or the floor: drawn at its own level, flat)
  const gk = clamp((t - 0.02) / 0.3);
  if (gk > 0 && gk < 1) {
    const rx = 14 + 66 * ease.outCubic(gk), ry = rx * 0.2, n = Math.floor(rx * 3);
    for (let i = 0; i < n; i++) { const a = (i / n) * Math.PI * 2; if (gk > 0.5 && i % 2) continue; p.px(Math.cos(a) * rx, 18 + Math.sin(a) * ry, gk < 0.3 ? WHITE : gk < 0.6 ? Y : O); }
  }
  // smoke behind the fire, blooming late
  for (let i = 0; i < 10; i++) {
    const st = 0.12 + hash(sd + 50 + i) * 0.1, k = clamp((t - st) / 0.42);
    if (t < st || k >= 1) continue;
    const a = hash(sd + 60 + i) * Math.PI * 2, d = 10 + hash(sd + 70 + i) * 18;
    const x = Math.cos(a) * d * (0.6 + k * 0.8), y = Math.sin(a) * d * 0.7 - 12 - k * 26, r = (6 + hash(sd + 80 + i) * 5) * (0.7 + k * 0.6);
    if (k > 0.6 && hash(i * 3 + F) < (k - 0.6) * 2.5) continue;
    const sc = k < 0.35 ? S1 : k < 0.7 ? S2 : S3;
    for (let yy = -Math.ceil(r + 1); yy <= Math.ceil(r + 1); yy++) for (let xx = -Math.ceil(r + 1); xx <= Math.ceil(r + 1); xx++) {
      const d2 = Math.hypot(xx, yy), rr = r + 1.2 * Math.sin(Math.atan2(yy, xx) * 4 + i) ;
      if (d2 > rr || (d2 > rr - 1.5 && hash(xx * 5 + yy * 11 + F) < 0.5)) continue;
      p.px(x + xx, y + yy, d2 < rr * 0.45 && yy < 0 ? (k < 0.35 ? hex("#948b7f") : S1) : sc);
    }
  }
  // the fireball: lumps punching out and rising, cooling from the rim in
  const fk = clamp(t / 0.34);
  if (fk < 1) for (let i = 0; i < 12; i++) {
    const a = hash(sd + i) * Math.PI * 2, d = (6 + hash(sd + 10 + i) * 20) * ease.outCubic(Math.min(1, fk * 2.2));
    const x = Math.cos(a) * d, y = Math.sin(a) * d * 0.8 - fk * 18, r = (7 + hash(sd + 20 + i) * 6) * (1 - fk * 0.55);
    const heat = 1 - fk - hash(sd + 30 + i) * 0.25;
    // a ragged lump: the rim broken by noise, so the ball never reads as stacked circles
    const rim = heat > 0.55 ? O : heat > 0.25 ? R : D, body = heat > 0.75 ? CR : heat > 0.5 ? Y : heat > 0.25 ? O : R;
    for (let yy = -Math.ceil(r + 2); yy <= Math.ceil(r + 2); yy++) for (let xx = -Math.ceil(r + 2); xx <= Math.ceil(r + 2); xx++) {
      const d2 = Math.hypot(xx, yy), ang = Math.atan2(yy, xx), rr = r + 1.6 * Math.sin(ang * 5 + i * 1.7 + fk * 9) + (hash(xx * 7 + yy * 13 + i + F) - 0.5) * 1.6;
      if (d2 > rr + 1.5) continue;
      p.px(x + xx, y + yy, d2 > rr ? rim : body);
    }
    if (heat > 0.6) p.disc(x - r * 0.25, y - r * 0.25, r * 0.45, heat > 0.8 ? WHITE : CR, 1);
  }
  // chunks and sparks thrown up and falling
  const pk = clamp(t / 0.55);
  for (let i = 0; i < 16; i++) {
    const a = -Math.PI / 2 + (hash(sd + 90 + i) - 0.5) * 2.8, v = 50 + hash(sd + 100 + i) * 70;
    const x = Math.cos(a) * v * pk, y = Math.sin(a) * v * pk + 120 * pk * pk;
    if (pk > 0.7 && ((i + F) & 1)) continue;
    if (i % 4 === 0) { p.rect(x, y, 2, 2, pk < 0.4 ? O : D); }
    else p.px(x, y, pk < 0.25 ? WHITE : i % 3 === 0 ? OL : pk < 0.5 ? Y : O);
  }
  if (t < 0.25) p.glow(0, -8, 50, O, 0.5 * (1 - t / 0.25));
}
