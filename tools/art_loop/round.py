#!/usr/bin/env python3
"""Art loop, one round (owner 2026-11-06, "[5 루프]"). Procedure: docs/ART_LOOP.md.

  python3 tools/art_loop/round.py snap  WORK FILE.png [FILE.png ...] [--owner] [--note "..."] [--ref REF.png ...]
      (--owner: a round the owner asked for after the cap)
      -> docs/work/WORK/rounds/NN/  (copies of the candidates, metrics.json, compare.png = candidates beside the
         reference sprites at the same scale on the town ground colour). NN = next free round number.
  python3 tools/art_loop/round.py score WORK NN AI_A FIT_A AI_B FIT_B
      -> records the two blind reviewers' scores (1-10 each, higher = better: AI = "AI 티가 안 난다",
         FIT = "우리 그림체와 어울린다") and prints the decision: CONTINUE / STOP (and why).
  python3 tools/art_loop/round.py status WORK
      -> the table of rounds so far (as stacked lines).

Stop rules (whichever comes first): round cap MAX_ROUNDS; the mean score did not rise by MIN_GAIN for PATIENCE
rounds in a row; or the counted faults went up while the score stayed flat. On STOP: show the owner the best round.
"""
import sys, os, json, shutil, glob, subprocess, datetime
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAX_ROUNDS = 6
MIN_GAIN = 0.5
PATIENCE = 2
REF_DEFAULT = ["assets/town/g_cottage.png", "assets/town/g_well.png", "assets/town/q_crateL.png",
               "assets/town/q_barrelM.png"]
GROUND = (86, 120, 62, 255)   # town lawn mid-tone, the background the sprites sit on


def rdir(work):
    return os.path.join(ROOT, "docs", "work", work, "rounds")


def faults(m):
    t = m["total"]
    return t["orphans"] + t["speckle"] + t["outline_gaps"] + t["thick_line"] + t["semi_alpha"] + t["off_palette"]


def compare(cands, refs, out, scale=2):
    ims = [Image.open(p).convert("RGBA") for p in refs + cands]
    pad = 12
    W = sum(i.width for i in ims) * scale + pad * (len(ims) + 1)
    H = max(i.height for i in ims) * scale + pad * 2 + 14
    sheet = Image.new("RGBA", (W, H), GROUND)
    x = pad
    for k, im in enumerate(ims):
        big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        y = H - pad - big.height            # all stand on one ground line, as in the game
        sheet.alpha_composite(big, (x, y))
        # a marker under the candidates (refs left, candidates right of the white tick)
        if k == len(refs) and refs:
            for yy in range(4, H - 4): sheet.putpixel((x - pad // 2, yy), (255, 255, 255, 255))
        x += big.width + pad
    sheet.save(out)


def snap(work, args):
    note = ""
    if "--note" in args:
        i = args.index("--note"); note = args[i + 1]; args = args[:i] + args[i + 2:]
    refs = []
    if "--ref" in args:
        i = args.index("--ref"); refs = args[i + 1:]; args = args[:i]
    refs = refs or [os.path.join(ROOT, p) for p in REF_DEFAULT]
    d = rdir(work)
    os.makedirs(d, exist_ok=True)
    n = 1 + max([int(os.path.basename(p)) for p in glob.glob(os.path.join(d, "[0-9][0-9]"))] or [0])
    owner = "--owner" in args          # the owner asked for this round himself: past the cap, recorded as such
    args = [x for x in args if x != "--owner"]
    if n > MAX_ROUNDS and not owner:
        print(f"STOP: round cap {MAX_ROUNDS} reached -- show the owner the best round (status)"); sys.exit(3)
    od = os.path.join(d, "%02d" % n)
    os.makedirs(od)
    cands = []
    for f in args:
        dst = os.path.join(od, os.path.basename(f)); shutil.copy(f, dst); cands.append(dst)
    m = json.loads(subprocess.check_output([sys.executable, os.path.join(ROOT, "tools/art_loop/metrics.py")] + cands + ["--json"]))
    compare(cands, refs, os.path.join(od, "compare.png"))
    meta = {"round": n, "date": datetime.date.today().isoformat(), "note": note, "files": [os.path.basename(c) for c in cands],
            "refs": [os.path.relpath(r, ROOT) for r in refs], "metrics": m, "faults": faults(m), "scores": None}
    json.dump(meta, open(os.path.join(od, "round.json"), "w"), indent=1, ensure_ascii=False)
    print(f"round {n:02d} -> {os.path.relpath(od, ROOT)}  faults={meta['faults']}  " +
          " ".join(f"{k}={v}" for k, v in m["total"].items()))
    print(f"next: two fresh reviewers score {os.path.relpath(od, ROOT)}/compare.png with docs/ART_LOOP.md's rubric, then"
          f" round.py score {work} {n:02d} AI_A FIT_A AI_B FIT_B")


def rounds(work):
    out = []
    for p in sorted(glob.glob(os.path.join(rdir(work), "[0-9][0-9]", "round.json"))):
        out.append(json.load(open(p)))
    return out


def score(work, nn, s):
    p = os.path.join(rdir(work), nn, "round.json")
    meta = json.load(open(p))
    a = [float(x) for x in s]
    meta["scores"] = {"A": {"ai": a[0], "fit": a[1]}, "B": {"ai": a[2], "fit": a[3]}, "mean": round(sum(a) / 4, 2)}
    json.dump(meta, open(p, "w"), indent=1, ensure_ascii=False)
    rs = [r for r in rounds(work) if r["scores"]]
    best = max(rs, key=lambda r: (r["scores"]["mean"], -r["faults"]))
    print(f"round {meta['round']:02d} mean={meta['scores']['mean']} faults={meta['faults']}  best so far: round {best['round']:02d}")
    why = None
    if meta["round"] >= MAX_ROUNDS: why = f"round cap {MAX_ROUNDS}"
    if len(rs) > PATIENCE:
        last = rs[-(PATIENCE + 1):]
        if all(last[i + 1]["scores"]["mean"] < last[0]["scores"]["mean"] + MIN_GAIN for i in range(PATIENCE)):
            why = f"mean score has not risen by {MIN_GAIN} for {PATIENCE} rounds"
    if len(rs) >= 2 and rs[-1]["faults"] > rs[-2]["faults"] and abs(rs[-1]["scores"]["mean"] - rs[-2]["scores"]["mean"]) < MIN_GAIN:
        why = why or "faults went up while the score stayed flat"
    if why:
        print(f"STOP: {why} -- show the owner round {best['round']:02d} (docs/work/{work}/rounds/{best['round']:02d}/compare.png)")
    else:
        print("CONTINUE")


def status(work):
    for r in rounds(work):
        sc = r["scores"]
        s = f"mean {sc['mean']} (A ai {sc['A']['ai']} fit {sc['A']['fit']}, B ai {sc['B']['ai']} fit {sc['B']['fit']})" if sc else "not scored"
        print(f"- round {r['round']:02d} {r['date']}: faults {r['faults']}, {s}. {r['note']}")


if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) < 2: print(__doc__); sys.exit(2)
    if a[0] == "snap": snap(a[1], a[2:])
    elif a[0] == "score": score(a[1], a[2], a[3:7])
    elif a[0] == "status": status(a[1])
    else: print(__doc__); sys.exit(2)
