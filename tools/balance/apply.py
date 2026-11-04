"""Write the balance tool's numbers into the game: data/balance.json ({"C": {member: {key: pct}}, "knobs": ...}).
usage: python3 -I tools/balance/apply.py TOOL_STATE.json   (the tool's saved document, as read from its store)"""
import sys, json, os
src = json.load(open(sys.argv[1], encoding="utf8"))
C = {c: {k: int(round(float(v))) for k, v in d.items()} for c, d in src["C"].items()}
out = {"C": C, "knobs": src.get("knobs", {}), "from": "balance tool"}
dst = os.path.join(os.path.dirname(__file__), "..", "..", "data", "balance.json")
os.makedirs(os.path.dirname(dst), exist_ok=True)
json.dump(out, open(dst, "w", encoding="utf8"), ensure_ascii=False, indent=1)
print("wrote", dst, sum(len(v) for v in C.values()), "coefficients")
