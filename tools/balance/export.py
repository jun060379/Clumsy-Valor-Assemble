"""Export what the balance tool needs (timings, stats, current coefficients, enemy HP) as JSON on stdout.
usage: python3 -I tools/balance/export.py > data.json"""
import re, json, os
R = os.path.join(os.path.dirname(__file__), "..", "..")
def rd(p): return open(os.path.join(R, p), encoding="utf8").read()
ch = rd("scripts/chars.gd")
def tab(name):
    blk = ch[ch.index("const " + name + " := {"):]
    blk = blk[:blk.index("\n}")]
    return {k: [int(x) for x in ms.split(",")] for k, row, ms in re.findall(r'"(\w+)": \[(-?\d+), \[([\d, ]+)\]\]', blk)}
tabs = {"estelle": tab("A_EST"), "luce": tab("A_LUCE"), "kenin": tab("A_KENIN")}
m = re.search(r'const TABLE := \{"estelle": (\w+), "aida": (\w+)', ch); tabs["aida"] = tab(m.group(2))
stats = json.loads(re.search(r"const STATS := (\{.*\})", ch).group(1).replace(".0", ".0"))
bal = rd("scripts/balance.gd")
C = {}
for c in ["estelle", "aida", "luce", "kenin"]:
    blk = bal[bal.index('"%s": {' % c):]
    blk = blk[:blk.index("\n\t},")]
    C[c] = {k: int(v) for k, v in re.findall(r'"(\w+)": (-?\d+)', blk)}
mobs = {k: int(v) for k, v in re.findall(r'"(\w+)": \{"name": "[^"]+", "atkEl": "\w+", "defEl": \[[^\]]*\], "hp": (\d+)', rd("scripts/mob.gd"))}
lv = json.loads(re.search(r"const LVCURVE := (\[.*?\])", rd("scripts/memory_data.gd")).group(1))
out = {"stats": stats, "lvcurve": lv, "C": C, "mobs": mobs,
       "ms": {c: {k: sum(tabs[c].get(k, [0])) for k in ["attack1", "attack2", "attack3", "air_combo", "kneel_attack", "attack_high"]} for c in tabs}}
print(json.dumps(out, ensure_ascii=False))
