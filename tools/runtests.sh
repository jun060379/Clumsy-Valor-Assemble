#!/bin/bash
# Runs every tests/test_*.gd headless and prints one line per test plus a total.
#   GODOT=/path/to/Godot_v4.4.1-stable_linux.x86_64 tools/runtests.sh [repo_dir] [pattern]
#   GODOT defaults to `godot` on PATH; repo_dir defaults to this script's repo; pattern (e.g. test_sfx) picks tests.
# A test counts as failed when its output matches FAIL_RE (a nonzero FAILS: n, "n failed", a SCRIPT ERROR, ...)
# or it hits the 300 s timeout. Exit code = number of failed tests (0 = all clean).
G="${GODOT:-godot}"
cd "${1:-$(dirname "$0")/..}" || exit 99
PAT="${2:-test_}"
FAIL_RE='FAIL [^0]|[1-9][0-9]* failed|FAILS:? [1-9]|fails[=:] ?[1-9]|SCRIPT ERROR|Parse Error|FAILS [1-9]'
"$G" --headless --import >/dev/null 2>&1
# a parse check of the whole project (the main scene for ~300 frames)
"$G" --headless --quit-after 300 2>&1 | grep -B1 -A2 "SCRIPT ERROR\|Parse Error" | head -20
bad=0
for t in tests/test_*.gd; do
  case "$t" in *"$PAT"*) ;; *) continue ;; esac
  out=$(timeout 300 "$G" --headless -s "$t" 2>&1); rc=$?
  hits=$(echo "$out" | grep -E "$FAIL_RE" | head -3 | tr '\n' ' ')
  if [ -n "$hits" ] || [ $rc -eq 124 ]; then
    bad=$((bad + 1)); [ $rc -eq 124 ] && hits="TIMEOUT $hits"
    echo "BAD  $t: $hits"
  else
    echo "ok   $t"
  fi
done
echo "DONE: $bad failed"
exit $bad
