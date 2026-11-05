#!/usr/bin/env bash
# One-shot workspace setup for a fresh session: Godot 4.4.1 headless, pixelfx (+ our effect sources), first import.
# bash tools/setup.sh   (from the repo root)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G=~/godot/Godot_v4.4.1-stable_linux.x86_64
if [ ! -x "$G" ]; then
  mkdir -p ~/godot && cd ~/godot
  curl -sSLO https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.x86_64.zip
  unzip -qo Godot_v4.4.1-stable_linux.x86_64.zip
  chmod +x "$G"
fi
if [ ! -d ~/tools/pixelfx ]; then
  mkdir -p ~/tools && git clone -q https://github.com/patch-gg/pixelfx.git ~/tools/pixelfx
  (cd ~/tools/pixelfx && npm install --silent >/dev/null 2>&1 || true)
fi
# our effect sources go back into pixelfx (holy/* for Luce, impacts/* and melee/* for the rest)
for f in "$ROOT"/tools/pixelfx_fx/*.js; do
  n=$(basename "$f")
  case "$n" in
    luce-*) d=holy ;;
    aida-tear-slash.js|aida-thrust-tear.js|estelle-slash.js|estelle-thrust.js) d=melee ;;
    *) d=impacts ;;
  esac
  cp -n "$f" ~/tools/pixelfx/src/fx/$d/ 2>/dev/null || true
done
(cd ~/tools/pixelfx && node tools/index.mjs >/dev/null 2>&1 || true)
cd "$ROOT" && timeout 600 "$G" --headless --path . --import >/dev/null 2>&1 || true
echo "ready: GODOT=$G"
