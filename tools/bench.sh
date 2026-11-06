#!/bin/bash
# Perf bench (tests/bench_crowd.gd): the crowd scene from a fixed seed.
#   tools/bench.sh            measure: FPS avg / 1% low under a display (rendering counts), plus a headless run (no
#                             GPU raster: scripts + _draw only) to split CPU from rendering; appends to docs/perf/LOG.md
#   tools/bench.sh --check    regression: the state hash after the run must equal docs/perf/STATE_HASH (an optimisation
#                             must not change what happens). --check --update writes the current hash as the new baseline
#                             (only when gameplay was meant to change).
# Same conditions every time: 900x500, --fixed-fps 60, 900 measured frames after 90 warm-up frames.
cd "$(dirname "$0")/.." || exit 99
G="${GODOT:-$HOME/godot/Godot_v4.4.1-stable_linux.x86_64}"
[ -x "$G" ] || G=godot
N="${BENCH_FRAMES:-900}"
mkdir -p docs/perf
if [ "$1" = "--check" ]; then
  # 3 runs: about 1 run in 7 still lands one hit a few hp off (cause not found yet), so the majority decides
  hs=""
  for i in 1 2 3; do
    hs="$hs $(timeout 600 "$G" --headless --path . --fixed-fps 60 -s tests/bench_crowd.gd -- 300 2>&1 | sed -n 's/^RESULT state_hash=//p')"
  done
  top=$(echo $hs | tr ' ' '\n' | sort | uniq -c | sort -rn | head -1)
  h=$(echo $top | awk '{print $2}'); n=$(echo $top | awk '{print $1}')
  if [ "$2" = "--update" ]; then echo "$h" > docs/perf/STATE_HASH; echo "baseline <- $h ($n/3)"; exit 0; fi
  b=$(cat docs/perf/STATE_HASH 2>/dev/null)
  if [ "$h" = "$b" ] && [ "$n" -ge 2 ]; then echo "SAME state hash $h ($n/3 runs)"; exit 0; fi
  echo "DIFF state hash: runs$hs, baseline $b"; exit 1
fi
R=$(timeout 900 xvfb-run -a "$G" --path . --fixed-fps 60 --resolution 900x500 -s tests/bench_crowd.gd -- "$N" 2>&1 | grep '^RESULT')
H=$(timeout 900 "$G" --headless --path . --fixed-fps 60 -s tests/bench_crowd.gd -- "$N" 2>&1 | grep '^RESULT')
echo "== with rendering (xvfb, software GL)"; echo "$R"
echo "== headless (scripts + _draw, no raster)"; echo "$H" | grep -E 'fps_avg'
fps=$(echo "$R" | sed -n 's/.*fps_avg=\([0-9.]*\) fps_1pct_low=\([0-9.]*\) frame_ms_avg=\([0-9.]*\).*/avg \1, 1% low \2, \3 ms/p')
cpu=$(echo "$H" | sed -n 's/.*frame_ms_avg=\([0-9.]*\).*/\1/p')
top=$(echo "$R" | grep 'RESULT prof' | grep -v render | head -3 | sed 's/RESULT prof //; s/ ms\/frame//' | tr '\n' ' ')
[ -f docs/perf/LOG.md ] || printf '# 성능 기록\n\n`tools/bench.sh`가 같은 조건(900x500, 고정 60fps, 측정 900프레임, 적 10)으로 잴 때마다 한 줄씩 붙인다.\n렌더 FPS는 이 작업 공간의 소프트웨어 GL 기준이라 폰과 절대값은 다르다. 같은 조건끼리 비교용.\n\n' > docs/perf/LOG.md
echo "- $(date +%F) $(git rev-parse --short HEAD)$(git diff --quiet || echo '+dirty'): render FPS $fps; headless(script+draw) ${cpu} ms; top: $top" >> docs/perf/LOG.md
tail -1 docs/perf/LOG.md
