// Kenin's sticky bomb catching (origin where it hits): a flat clack — a white tick and short impact lines, an olive
// splat of glue spreading and settling, a couple of goo flecks, a few sparks.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Kenin stick",
  desc: "A clack: white tick and impact lines, an olive glue splat spreading and settling, goo flecks, sparks.",
  tags: ["bomb", "impact", "kenin", "one-shot"],
  size: [56, 48],
  origin: [28, 24],
  duration: 0.3,
  loop: false,
  fps: 50,
  options: { seed: 6 },
};

const OV = hex("#9cc14a"), OVD = hex("#5f7a2a"), OL = hex("#e2f5b8"), Y = hex("#ffd06a"), CR = hex("#fff4cf");
const hash = (n) => { const v = Math.sin(n * 12.9898 + 7.3) * 43758.5453; return v - Math.floor(v); };

export function draw(p, t, o) {
  const F = Math.floor(t / 0.02), sd = o.seed * 2.2;
  // the clack: white tick, impact lines
  if (F < 3) {
    const k = [1, 0.7, 0.4][F];
    p.disc(0, 0, 3 * k + 1, F ? OL : WHITE, 1);
    for (let i = 0; i < 6; i++) { const a = (i / 6) * Math.PI * 2 + 0.3, r0 = 6 + (1 - k) * 6, r1 = r0 + 5 * k; p.line(Math.cos(a) * r0, Math.sin(a) * r0, Math.cos(a) * r1, Math.sin(a) * r1, i % 2 ? OL : WHITE); }
  }
  // the splat: glue spreading out in a ragged ring, then settling to a smear
  const sk = ease.outCubic(clamp(t / 0.12)), fade = clamp((t - 0.18) / 0.12);
  if (fade < 1) for (let i = 0; i < 14; i++) {
    const a = (i / 14) * Math.PI * 2, r = (4 + hash(sd + i) * 5) * sk;
    if (fade > 0.4 && (i + F) & 1) continue;
    p.px(Math.cos(a) * r, Math.sin(a) * r * 0.8, fade < 0.3 ? OV : OVD);
    if (hash(sd + 20 + i) > 0.6) p.px(Math.cos(a) * (r + 1), Math.sin(a) * (r + 1) * 0.8, OVD);
  }
  // goo flecks and sparks
  const pk = clamp(t / 0.25);
  for (let i = 0; i < 6; i++) {
    const a = -Math.PI / 2 + (hash(sd + 40 + i) - 0.5) * 3, v = 10 + hash(sd + 50 + i) * 12;
    const x = Math.cos(a) * v * ease.outCubic(pk), y = Math.sin(a) * v * ease.outCubic(pk) + 14 * pk * pk;
    if (pk > 0.7 && (i + F) & 1) continue;
    p.px(x, y, i < 3 ? (pk < 0.5 ? OV : OVD) : pk < 0.4 ? CR : Y);
  }
}
