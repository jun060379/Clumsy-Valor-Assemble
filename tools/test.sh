#!/bin/bash
# Picks the tests that guard the files you changed (tools/test_tiers.txt) and runs them, P0 first.
#   tools/test.sh               changed vs HEAD (uncommitted work) — or, if none, vs HEAD~1 (the last commit)
#   tools/test.sh REF           changed vs REF (e.g. origin/main)
#   tools/test.sh --p0          every P0 test
#   tools/test.sh --all         every test (P0, then P1, then the unlisted ones)
#   GODOT=... overrides the binary (default ~/godot/Godot_v4.4.1-stable_linux.x86_64 or `godot`)
# Boss-bot lines are appended to docs/test/BOSS_LOG.md with the date. Exit code = number of failed tests.
cd "$(dirname "$0")/.." || exit 99
G="${GODOT:-$HOME/godot/Godot_v4.4.1-stable_linux.x86_64}"
[ -x "$G" ] || G=godot
FAIL_RE='FAIL [^0]|[1-9][0-9]* failed|FAILS:? [1-9]|fails[=:] ?[1-9]|SCRIPT ERROR|Parse Error|FAILS [1-9]'
MODE="changed"; REF=""
case "$1" in
  --all) MODE="all" ;;
  --p0) MODE="p0" ;;
  "") ;;
  *) REF="$1" ;;
esac
if [ "$MODE" = "changed" ]; then
  if [ -n "$REF" ]; then CH=$(git diff --name-only "$REF"); else
    CH=$( (git diff --name-only HEAD; git ls-files --others --exclude-standard) | sort -u)
    [ -z "$CH" ] && CH=$(git diff --name-only HEAD~1)
  fi
  echo "changed: $(echo $CH | tr '\n' ' ')"
fi
# pick: tier order P0 then P1
PICK=$(python3 - "$MODE" <<EOF
import sys, fnmatch, glob, os
mode = sys.argv[1]
ch = """$CH""".split()
rows = []
for ln in open("tools/test_tiers.txt"):
    ln = ln.split("#")[0].split()
    if len(ln) >= 2: rows.append((ln[0], ln[1], ln[2:]))
listed = {r[0] for r in rows}
out = []
for t, tier, globs in sorted(rows, key=lambda r: r[1]):
    if mode == "all" or (mode == "p0" and tier == "P0"):
        out.append((tier, t)); continue
    if mode == "changed" and ch and any(g == "*" or any(fnmatch.fnmatch(c, g) for c in ch) for g in globs):
        out.append((tier, t))
if mode == "all":
    for f in sorted(glob.glob("tests/test_*.gd")):
        b = os.path.basename(f)
        if b not in listed: out.append(("P1", b))
print("\n".join(f"{a} {b}" for a, b in out))
EOF
)
[ -z "$PICK" ] && { echo "no test guards these files"; exit 0; }
"$G" --headless --path . --import >/dev/null 2>&1
bad=0
while read -r tier t; do
  [ -z "$t" ] && continue
  if [ "$t" = "bot_boss.gd" ]; then
    out=$(timeout 600 "$G" --headless --fixed-fps 60 --path . -s "tests/$t" 2>&1); rc=$?
    mkdir -p docs/test
    echo "$out" | grep '^BOSS ' | sed "s/^/- $(date +%F) $(git rev-parse --short HEAD) /" >> docs/test/BOSS_LOG.md
    echo "$out" | grep '^BOSS '
  else
    out=$(timeout 300 "$G" --headless --path . -s "tests/$t" 2>&1); rc=$?
  fi
  hits=$(echo "$out" | grep -E "$FAIL_RE" | head -3 | tr '\n' ' ')
  if [ -n "$hits" ] || [ $rc -eq 124 ]; then
    bad=$((bad + 1)); [ $rc -eq 124 ] && hits="TIMEOUT $hits"
    echo "BAD  [$tier] $t: $hits"
  else
    echo "ok   [$tier] $t"
  fi
done <<< "$PICK"
echo "DONE: $bad failed"
exit $bad
