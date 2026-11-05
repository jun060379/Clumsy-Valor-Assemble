// Aida's rift sigil (the teleport mark), in the language of her tears: a crisp diamond frame with an eye-tear inside
// that breathes open onto the void, four pips orbiting it, a diamond pulse thrown out every half beat, and a dashed
// landing ring turning on the floor below. A seamless loop.
import { clamp, ease, WHITE, hex } from "../../core/index.js";

export const meta = {
  name: "Aida sigil",
  desc: "A diamond-framed eye-tear breathing open onto the void, orbiting pips, diamond pulses and a turning landing ring on the floor.",
  tags: ["arcane", "sigil", "mark", "rift", "void", "loop"],
  size: [80, 80],
  origin: [40, 66],
  duration: 1.0,
  loop: true,
  fps: 30,
  options: {},
};

const LIP = ["#ffffff", "#e8d4ff", "#c9a0ff", "#9a62e0", "#5a2a9e"].map(hex), RIM = hex("#b07aff"), VOID = hex("#06020a"), DEEP = hex("#1a0830"), NEB = hex("#3a1260");
const TAU = Math.PI * 2, CY = -24;

function diamond(p, cx, cy, r, c, a = 1) {
  r = Math.round(r);
  for (let i = 0; i <= r; i++) {
    p.px(cx + i, cy - r + i, c, a); p.px(cx - i, cy - r + i, c, a);
    p.px(cx + i, cy + r - i, c, a); p.px(cx - i, cy + r - i, c, a);
  }
}

export function draw(p, t, o) {
  const ph = t * TAU;                       // one turn a loop
  // the landing ring on the floor: dashes turning, ticks at the four points
  for (let i = 0; i < 40; i++) {
    const a = (i / 40) * TAU + ph * 0.5;
    if (i % 5 > 2) continue;
    const x = Math.cos(a) * 14, y = Math.sin(a) * 4.2;
    p.px(x, y, y < 0 ? LIP[3] : LIP[2], y < 0 ? 0.6 : 0.95);
  }
  for (const [x, y] of [[-16, 0], [16, 0]]) { p.px(x, y, LIP[1]); p.px(x - Math.sign(x), y, LIP[2]); }
  p.glow(0, 0, 14, LIP[3], 0.25);
  // a faint thread of light from the ring up to the sigil
  for (let y = -1; y > CY + 11; y -= 2) p.px(0, y, LIP[3], 0.35 + 0.25 * Math.sin(ph * 2 + y * 0.6));

  // the pulse: a diamond thrown out every half loop, thinning as it grows
  for (const off of [0, 0.5]) {
    const k = (t + off) % 1 * 2 % 1;
    if (off === 0.5 && t < 0) continue;
    const r = 13 + 9 * ease.outCubic(k);
    if (k < 0.95) diamond(p, 0, CY, r, k < 0.3 ? LIP[1] : LIP[3], 1 - k);
  }
  // the frame: a crisp diamond with a darker inner line, its points tipped with light
  diamond(p, 0, CY, 12, RIM);
  diamond(p, 0, CY, 11, LIP[4], 0.8);
  for (const [dx, dy] of [[0, -12], [12, 0], [0, 12], [-12, 0]]) { p.px(dx, CY + dy, WHITE); p.glow(dx, CY + dy, 4, LIP[1], 0.5); }
  // four pips orbiting just outside it
  for (let i = 0; i < 4; i++) {
    const a = ph + (i / 4) * TAU, x = Math.round(Math.cos(a) * 16), y = Math.round(Math.sin(a) * 16) + CY;
    p.px(x, y, LIP[0]); p.px(x + 1, y, LIP[2]); p.px(x - 1, y, LIP[2]); p.px(x, y + 1, LIP[2]); p.px(x, y - 1, LIP[2]);
    p.glow(x, y, 3, LIP[2], 0.4);
  }
  // the eye-tear inside, breathing open onto the void and nearly shut again
  const open = 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(ph * 2 - Math.PI / 2));
  const H = 8, W = 3.6 * open;
  for (let y = -H; y <= H; y++) {
    const v = (y + H) / (2 * H), w = W * Math.pow(Math.sin(Math.PI * v), 0.8);
    const wi = Math.round(w);
    for (let x = -wi; x <= wi; x++) {
      const n = Math.sin(x * 0.9 + ph) + Math.sin(y * 0.7 - ph * 2);
      p.px(x, CY + y, Math.abs(x) === wi ? (x < 0 ? LIP[0] : LIP[2]) : n > 1.2 ? NEB : Math.abs(x) >= wi - 1 ? DEEP : VOID);
    }
    if (wi === 0) p.px(0, CY + y, LIP[1]);
  }
  // the pupil: a spark of light deep in the void, pulsing
  const pk = 0.5 + 0.5 * Math.sin(ph * 4);
  p.px(0, CY, WHITE);
  if (open > 0.6) { p.px(0, CY - 1, LIP[1], pk); p.px(0, CY + 1, LIP[1], pk); }
  p.glow(0, CY, 10, RIM, 0.35 + 0.2 * pk);
}
