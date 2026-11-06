# 성능 기록

`tools/bench.sh`가 같은 조건(900x500, 고정 60fps, 측정 900프레임, 적 10)으로 잴 때마다 한 줄씩 붙인다.
렌더 FPS는 이 작업 공간의 소프트웨어 GL 기준이라 폰과 절대값은 다르다. 같은 조건끼리 비교용.

- 2026-11-06 b4fdde5+dirty: render FPS avg 11.7, 1% low 8.0, 85.38 ms; headless(script+draw) 2.60 ms; top: level.step=0.400 player.step=0.336 mob.step=0.184 
