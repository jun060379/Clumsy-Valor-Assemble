# 성능 기록

`tools/bench.sh`가 같은 조건(900x500, 고정 60fps, 측정 900프레임, 적 10)으로 잴 때마다 한 줄씩 붙인다.
렌더 FPS는 이 작업 공간의 소프트웨어 GL 기준이라 폰과 절대값은 다르다. 같은 조건끼리 비교용.

- 2026-11-06 b4fdde5+dirty: render FPS avg 11.7, 1% low 8.0, 85.38 ms; headless(script+draw) 2.60 ms; top: level.step=0.400 player.step=0.336 mob.step=0.184 
- 2026-11-06 town (tests/bench_town.gd, headless script+draw, 7 spots x 180 frames): before the v30 ground 4.07 ms (p99 6.34); v30 ground 6.51 ms; + grass on the slopes 13.04 ms (p99 25.03, worst on the slope 24.45) -- owner "렉". Fix: blades to the GPU (shaders/grass_blades.gdshader, baked chunk meshes), ground on its own node redrawn only when the view leaves a +-600 px span -> 3.18 ms (p99 3.83). Render under xvfb software GL: 80.8 / 114.6 / 98.0 ms (not phone numbers)
