# 인계 문서 (다음 Claude 세션용)

이 파일 하나만 읽고 작업을 이어 갈 수 있게 쓴 문서다. 기준 시점: 2026-11-03, main `1530be4` 다음 커밋.
게임: 「Clumsy Valor [어설픈 용맹] -Assemble-」, 고도 4.4.1 (GDScript). 저장소 `jun060379/Clumsy-Valor-Assemble`.
main에 푸시하면 GitHub Actions가 웹·윈도우로 빌드해서 GitHub Pages(https://jun060379.github.io/Clumsy-Valor-Assemble/)에 올린다.
오너(사용자)는 이 웹 빌드를 **폰으로** 플레이하고 확인한다. 플레이어용 조작·시스템 설명은 `README.md`, 개발 메모도 README 뒷부분에 있다.

---

## 1. 작업 방식 (오너가 정한 규칙)

- 답은 **한국어로만** 쓴다. 코드 주석과 커밋 메시지는 지금까지처럼 영어.
- **표(마크다운 테이블)를 쓰지 않는다.** 폰에서 읽기 힘들다. 줄 목록처럼 세로로 쌓는다.
- 이미지·음악·효과음 생성용 프롬프트(GPT, NAI, Suno, ElevenLabs 등)는 **영어**로 쓰고, 설명은 한국어로 붙인다.
- 보고하기 전에 **직접 눈으로 확인**한다. 캡처(PNG)나 녹화 영상(MP4)을 뽑아서 보고, 그 파일을 같이 보낸다. 소리 작업은 소리 들어간 영상으로 보여 준다.
  - 시연 영상은 배경음이 효과음을 덮었다는 지적이 있었다. 효과음을 보여 주는 영상은 녹화할 때만 배경음을 줄인다(약속한 상태).
- **지나치게 묻지 않는다.** 뜻이 분명하면 바로 하고, 해석한 내용을 보고에서 밝힌다. 정말 갈리는 결정만 묻는다.
- 대사는 오너가 직접 쓴다. 내가 임시로 넣은 대사·문구는 **임시라고 반드시 알린다**(코드에는 `PLACEHOLDER` 주석). 지금 남아 있는 임시 문구:
  - `scripts/menu.gd` NO_SAVE_LINE "던전에서는 저장할 수 없어요", SAVED_LINE "슬롯 %d에 저장했어요"
  - `scripts/title.gd` FRESH_LINE "새로운 이야기를 시작합니다"
  - `scripts/eilin.gd` NOTE_LINE (에일린 부재 쪽지), `fame.gd`의 부재중 접수대 줄
  - `skin_data.gd`의 `placeholder: true` 의상 이름·설명, 마을 잡담(`townsfolk.gd`), 타이틀 카드 문구(`title_card.gd`)
- 기획 문서에서 **정해지지 않은 항목은 빈칸 `[ 　　 ]`과 (예정)/(예시)로 표시**한다. 내가 임의로 채운 설정·숫자를 확정처럼 쓰지 않는다.
- 내 제안은 오너가 승인해야 결정이다. 승인 안 된 제안은 결정으로 취급하지 않는다.
- **라이선스 규칙(중요)**: 상용 샘플 팩(Cymatics 팩, 効果音ラボ), ElevenLabs로 뽑은 결과물은 **가공한 OGG만** 공개 저장소에 넣는다. **원본 WAV·MP3는 절대 커밋하지 않는다.** 변환: `ffmpeg -i src -c:a libvorbis -q:a 5 -ac 1 out.ogg`. 원본은 오너가 채팅에 첨부해 준 것이라, 새 작업 공간에는 없다. 다시 필요하면 오너에게 첨부를 부탁한다.
- 커밋 메시지 끝에는 시스템이 알려 주는 귀속 줄(Co-Authored-By, Claude-Session)을 붙인다. main에서 바로 작업하거나, 큰 일은 브랜치·worktree에서 하고 머지한다.

## 2. 환경 재구축

새 작업 공간에는 고도가 없다. 10분쯤 걸린다.

- 고도 4.4.1 헤드리스 바이너리 (linux x86_64):
  ```
  mkdir -p ~/godot && cd ~/godot
  curl -sSLO https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.x86_64.zip
  unzip -q Godot_v4.4.1-stable_linux.x86_64.zip
  export GODOT=~/godot/Godot_v4.4.1-stable_linux.x86_64
  ```
  웹 내보내기는 Actions가 하므로 export templates는 로컬에 필요 없다.
- 처음 한 번, 그리고 에셋을 바꿀 때마다 가져오기: `$GODOT --headless --path . --import`
- 테스트 전체: `GODOT=$GODOT tools/runtests.sh` (저장소 루트에서). 한 줄에 테스트 하나(`ok` / `BAD`), 끝에 `DONE: n failed`. 일부만: `tools/runtests.sh . test_sfx`.
  - 실패 판정 정규식: `FAIL [^0]|[1-9][0-9]* failed|FAILS:? [1-9]|fails[=:] ?[1-9]|SCRIPT ERROR|Parse Error|FAILS [1-9]`, 300초 넘으면 TIMEOUT(전에 테스트 하나가 멈춘 적이 있다).
  - 테스트 하나만: `timeout 300 $GODOT --headless -s tests/test_title.gd`
  - 테스트는 `user://save_test.json`(슬롯 `save_test_1..3.json`)을 쓰고 타이틀을 건너뛴다. 타이틀을 보려면 스크립트에서 `T.active = true; T.visible = true` (`arena.ui_root.title`).
  - 전체 한 번에 대략 20~40분.
- 화면 캡처(디스플레이 필요): `xvfb-run -a $GODOT --rendering-driver opengl3 --resolution 900x500 --path . -s <script.gd> -- <args>`
  - 프레임 저장은 `await RenderingServer.frame_post_draw` 뒤 `root.get_texture().get_image().save_png(path)`.
  - 기존 캡처 스크립트: `tests/cap_*.gd` (예: `tests/cap_walk.gd -- OUTDIR strips|scale|movie`).
- 녹화(Movie Maker, 소리 포함): 위 명령에 `--fixed-fps 30 --write-movie OUT.avi` 추가. 그다음
  `ffmpeg -y -i OUT.avi -c:v libx264 -crf 20 -pix_fmt yuv420p -c:a aac OUT.mp4`
  - `tools/capture/movie_fight.gd`: 마을 → 실제 출격 흐름으로 동굴 → 콤보·대시·가드·점프 공격·궁극기 (에스텔)
  - `tools/capture/movie_aida.gd`: 아이다 콤보·포털 대시·균열 스킬
  - `tools/capture/movie_title.gd`: 타이틀 30초 (살아 있는 마을 + 타이틀 곡)
  - `tools/capture/cap_fight.gd -- OUTDIR`: 프레임마다 PNG + 효과음 시작을 `SFX <이름> <프레임>`으로 출력(소리 타이밍 확인용)
- 배포 확인: 푸시 뒤
  `gh api 'repos/jun060379/Clumsy-Valor-Assemble/actions/runs?per_page=1' --jq '.workflow_runs[0] | {status, conclusion, head_sha}'`
  가 `completed / success`이고 head_sha가 방금 커밋이면 끝. 빌드 표시는 타이틀 오른쪽 아래 `<날짜> · <해시>`. 웹은 `index.pck?v=<해시>`로 캐시를 깬다.
- 소리 가공에는 파이썬(librosa / soundfile / scipy / numpy)과 ffmpeg를 썼다. 음량 측정은 `tools/measure_sfx.py`.

## 3. 구조 지도

장면은 `scenes/main.tscn` 하나. 그 루트 스크립트가 `arena.gd`이고, 마을·본관·훈련장·던전을 레벨로 갈아 끼운다.

- `arena.gd`: 게임 루트. 레벨 전환(go_town / enter_dungeon …), 카메라, 효과음 시스템 `sfx()`(FILES·VARIANTS·LEVEL·SNAP·JITTER·DUCK), 창 크기 감시 `_fit_poll()`, title_mode, load_file
- `player.gd`: 조작 중인 동료와 파티. 이동·점프·대시·공격·가드·패링, 아이다 균열, 착지음(LAND_LEAD), 발소리, 부활·마을 회복
- `chars.gd`: 세 동료의 시트·애니메이션 표·능력치
- `skin_data.gd` / `skins.gd`: 의상 목록 / 소유·착용과 그림 찾기(모든 화면이 여기서 캐릭터 그림을 받음). 걷기 프레임 시간·보폭 표도 skin_data에
- `char_bounds.gd`: 스프라이트 위·아래 줄 (tools/make_char_bounds.py가 생성)
- `town.gd` / `town_life.gd`: 길드 마을 지형·건물·빛 / 바람·풀·소품·동물 등 작은 생활
- `townsfolk.gd`: 파티 밖 동료가 마을에서 걷고 인사·잡담. 타이틀 아래에서는 전원(주인공 포함)이 마을 사람
- `eilin.gd`: 접수원 에일린의 하루 일과·걷기/달리기·부재 쪽지. `hall.gd` / `hall_data.gd`: 길드 본관 층별 지도
- `bran.gd`: 대장장이 브랜(망치질, 가끔 40~90 px 산책). `ui_forge.gd`: 대장간 화면, `ui_choice.gd`: 브랜 선택지
- `dungeon.gd` / `cave_ter.gd` / `mob.gd`: 버섯 동굴 방 생성 / 바위 굽기 / 몬스터. `loot.gd`: 보스 보물 상자
- `sortie.gd` / `dsel.gd` / `title_card.gd` / `clear_screen.gd` / `sweep.gd`: 출격·귀환 흐름 / 던전 선택 / 타이틀 카드 / 클리어 화면 / 화면 전환 띠
- `training.gd` / `dummy.gd` / `ghost.gd`: 훈련장
- `title.gd`: 타이틀(살아 있는 마을 위 오버레이, 따라가는 카메라, 박자 맞춘 UI, 메뉴). 연출 상세는 `docs/title_storyboard.md`
- `bgm.gd` / `beat.gd` / `beat_maps.gd`: 배경음 플레이어들 / 트랙별 음악 시계 / 측정한 박 지도
- `ambience.gd` / `slow_bus.gd`: 환경음 / 극한 회피 중 소리 느려짐
- `post_fx.gd`: 화면 효과(빛 번짐, 충격파, 색수차, 타격 무게별 히트스톱·펀치 왜곡·줌, 패링 반전, 피격 비네트, 사망 탈색). `pfx.gd`: 도트 이펙트. `lit.gd` / `shade.gd` / `sky.gd`: 빛·그늘·밤하늘
- `save_game.gd` / `slot_card.gd`: 자동 저장 `user://save.json` + 수동 슬롯 `user://save_1..3.json` / 슬롯 카드
- `menu.gd`: 오른쪽 위 버튼과 페르소나식 허브 메뉴(허브의 "저장" 포함). `ui_root.gd`: 화면 앞단(타이틀·메뉴)
- `settings.gd` / `options.gd`: 설정 저장(`user://settings.cfg`) / 설정 화면(음량 슬라이더 넷)
- `fame.gd` / `fame_data.gd` / `fame_book.gd` / `fame_fx.gd` / `fame_skin.gd`: 길드 명성·모험가 레벨 / 데이터 / 길드·모험 수첩 / 연출 / 글꼴·도장음
- `runes.gd` / `elements.gd` / `fatigue.gd`: 룬·장비·실링·도감 / 속성 상성 / 피로도
- `memory.gd` / `memory_data.gd`: 캐릭터 레벨과 기억 노드
- `ult.gd` / `ult_cut.gd`: 궁극기 / 컷인
- `hud.gd` / `touch_controls.gd`: HUD / 폰 터치 조작
- `dialog.gd` / `talk_fx.gd`: 대화창 / 대화 연출
- `ui_kit.gd` / `ui_anim.gd` / `ui_page.gd`: 공용 색·글꼴·글꼴 대체 사슬 / UI 모션 / 메뉴 화면 기반
- `ui_party.gd` / `party_edit.gd` / `ui_char*.gd` / `ui_bag.gd` / `ui_codex.gd` / `ui_wardrobe.gd`: 파티 / 분수대 등 진입점 / 캐릭터 화면(기억·의상 탭) / 가방 / 도감 / 옷장
- `dev.gd`: 디버그 게이트 `DEV.on`(릴리스 빌드에서는 시험 키·웹 훅 전부 꺼짐)

에셋 폴더(`assets/`):
- `chars/` 원래 캐릭터 시트, `skins/<의상>/` 의상별 시트·그림(규격: `docs/skin_assets.md`, 포즈 레퍼런스 `docs/skin_ref/`)
- `sfx/` 효과음(OGG = 팩·ElevenLabs 가공본, WAV = `tools/make_sfx.py` 합성), `bgm/` 배경음 5곡
- `title/` 타이틀 그림(hall, logo 등), `ui/` 얼굴·아이콘·서 있는 그림, `fonts/` Noto·블랙한산스 WOFF2
- `town/`, `hall/`, `cave/`, `bg/`, `props/`, `light/`, `mobs/`, `loot/`, `fame/`, `codex/`, `ult/`(궁극기 JPEG 묶음), `eilin/`, `bran/`, `fx/`

도구(`tools/`): `make_walk.py`(걷기 시트 자르기·맞추기), `make_skin_chosim.py`(초심 시트 — 다시 돌리면 걷기를 덮으니 뒤에 `make_walk.py estelle`), `color_match_chosim.py`, `recolor_al.py`, `make_fonts.py`, `make_sfx.py`, `measure_sfx.py`, `make_ult_seq.py`, `make_char_bounds.py`, `make_beat_maps.py`, `runtests.sh`, `capture/`.
내보내기는 `tests/`, `tools/`, `docs/`, `build/`를 뺀다.

## 4. 사운드 결정 현황 (코드로 확인함)

모든 효과음은 `arena.sfx(이름, 음량, opts)`. 실제 크기 = 호출 음량 × `LEVEL[파일]`. 변형이 있는 소리는 `<이름>_<k>.ogg`를 번갈아(같은 것 연속 없음).

확정(오너가 직접 정함):
- 패링: "쾅!!" 하는 소리 `parry_1/2`, LEVEL 1.2. 완벽한 패링은 +7 반음. 음악 4 dB 덕킹
- **깨지는 소리는 넣지 않는다.** 패링·에스텔 궁극기에서 뺐고, 몬스터 쓰러짐은 `down_1..3`(몸이 쓰러지는 소리)
  - 확인 필요: `break.wav`(합성 노이즈 버스트)가 아직 아이다·루체 궁극기 충격(`ult.gd` 309·371행, 0.8), 보스 상자 깨짐(`loot.gd`), 훈련장 허수아비·유령에서 울린다. 오너의 "깨지는 소리 빼"가 여기까지인지 물어볼 것
- **미끄러지는 소리 없음**: 대시 끝 슬라이드·skid 호출은 전부 지웠다(`skid_1/2` 파일과 표 항목만 남음)
- 발소리: `step_grass/stone/wood/run` 각 8종, LEVEL 0.15(풀) / 0.16, 호출 음량 0.6. 바닥: 본관 = 나무, 동굴 = 돌, 나머지 = 풀
- 점프: `jump` LEVEL 0.06 (예전 0.3의 20 %, 거의 안 들리게). 더블 점프 `djump` 0.32는 그대로 유지
- 착지: 오너가 준 소리 `land.ogg`(트랜지언트에서 시작하게 자름). 진짜 점프·낙하 뒤 12 px 이상이면 울리고, 높을수록 크게(0.3 → 0.6, 160 px에서 최대), LEVEL 0.6. 출력 지연 때문에 발이 닿기 `LAND_LEAD` = 3프레임 전에 미리 울린다(`player.gd`, `_land_y()`로 아래 바닥을 읽음, 측정상 60fps에서 약 2프레임 앞)
- 대시: 오너가 고른 "비디오 게임 대시" 2종 `dodge_1/2`(논리 이름 `dash`), LEVEL 0.6
- 아이다: 포털 열림 `aida_open`(짧고 강한 "쩍") 2종 → 60 ms 뒤 통과 `aida_pass`("슉") 2종, 닫힘 `aida_close` 2종. 약공격 `aida_hit` 4종(어둠 에너지 "지잉"), 3타·차지·균열 찌르기 `aida_heavy` 3종(공허 충격). 글리치·깨진 신호는 작게 섞어 넣음. "애니 대시" 소리는 아이다 포털 대시용으로 쓴다는 결정
- 타격: ElevenLabs 세트(금속 클랭 + 살 타격) `hit1..3` 각 4종, `heavy` 4, `stab` 3. 300 ms 안에 다시 치면 0.7배. 던전에서는 16분음표 격자에 맞춰 최대 90 ms 늦춰 울림
- 극한 회피 중 느려지는 건 움직임 소리만(`WITCH_SLOW`: swing, dodge, skid, foot, jump, djump, land, flare, dash)
- UI: `menu_move / menu_ok / menu_back`, 종이 화면(수첩·접수대·브랜 선택지)만 도장 소리 `ui1..3`

버스와 음량 설정:
- 버스: Master(리미터, 천장 -0.5 dB) / SFX / Voice(아직 쓰는 곳 없음) / Slow(→ SFX) / BGM(-1 dB 트림, `bgm.gd` BUS_DB)
- 설정 화면 슬라이더 넷: 전체 음량 · 배경음 · 효과음 · 보이스 (11칸, 0 % = 음소거). `settings.cfg [audio]`, 기본 1 / 0.8 / 1 / 1

배경음(`bgm.gd`, 파일은 모두 **-14 LUFS**, 루프 지점은 `.import`의 loop_offset과 코드 둘 다):
- `title.ogg` 164.44 s, 0으로 루프 / `town.ogg` 75 s, 0으로 루프(마을·본관, 던전 다녀오면 멈춘 자리에서 이어짐 — 중간부터 다시 도는 버그 고침)
- `battle.ogg` 105.79 s, 4.99 s로 되감김 / `boss.ogg` 174.35 s, 13.49 s로 되감김 / `lowhp.ogg` 60.24 s, 20.18 s로 되감김(HP 30 % 아래에서 들어오고 40 % 이상에서 빠짐)
- 음악은 Suno로 오너가 뽑아 준 곡. 전투곡은 "나중에 바꾸자"(아래 남은 일)

## 4-1. 캐릭터 분류 (오너 확정, 2026-11-03)

- 클래스 8종: 전사 · 도적 · 마법사 · 사제 · 워락 · 정령술사 · 드루이드 · 바드 (`runes.gd` CLS)
- 거리: 근접 / 원거리
- 포지션: 스트라이커(근접 딜러) · 슈터(원거리 딜러) · 디펜더(탱커) · 서포터 · 트릭스터
- 표기는 "클래스 · 거리 · 포지션" 한 줄만(별명·무기 같은 다른 꼬리표는 붙이지 않음). 캐릭터 화면·파티 화면은 `ui_char.gd` SHEET, 인물 도감은 `fame_data.gd` FPEOPLE
- 에스텔 전사·근접·디펜더 / 아이다 워락·근접·스트라이커 / 루체 사제·원거리·서포터 / 브랜 전사·근접·디펜더

## 4-2. 새 캐릭터: 쥐 총잡이 (이름 미정, 원거리 · 슈터, 오너 설정 2026-11-03)

- 원화: 고글·남색 두건과 목도리·올리브색 로브·배낭·부싯돌식 권총을 든 쥐. 스프라이트는 Sprite Flow Pro로 뽑는 중(원화 자산 `738ed0ff-cf91-40d1-808d-e88c30785556`, 원화는 왼쪽을 봄 → 게임용은 좌우 반전).
- 컨셉: QTE로 서브 딜링·디버프 → 교대해 나와서 누킹 → 다시 파티로 들어가 재정비.
  - QTE: 적 근접 거리에서 헤드샷을 쏘는 원호 공격(원피스 벤 베크만 같은). **눌러도 교대하지 않는다.** 쏜 뒤 교대 쿨타임 초기화.
  - 메인으로 나왔을 때: 장탄수와 폭탄 몇 개가 있을 때는 고화력, 다 쓰면 매우 약해져서 쿨을 기다려야 함. 파티 안에 있을 때도 쿨이 돈다(나와서 다 쏘고 → 들어가서 재정비하며 원호).
  - 전투 스킬: **점착 폭탄** — 적에게 붙고 몇 초 뒤 폭발, 붙은 적에게 헤드샷(일반 사격·QTE)이 맞으면 즉시 폭발하며 피해 증가 (오너 확정 2026-11-03)
  - 기폭: **차징 공격**(공격 꾹 → 기폭 상자, 놓으면 플런저)이 붙은 표식·폭탄을 가까운 것부터 연쇄로 터뜨림 — 간격이 점점 짧아지며 파바바방, 마지막 큰 폭발 + 「연쇄 ×N」 (오너 확정 2026-11-04)
  - 표식은 여러 개: 맞은 총알마다 1개, 폭탄 폭발에 휘말린 적마다 1개, QTE 헤드샷 3개, 궁 총알 하나당 1개 (적 하나 최대 8, 궁은 무제한; 연쇄 중 터지는 폭탄은 표식을 안 남김) (오너 2026-11-04)
  - 총알이 없으면 평타가 나가지 않음 — 방아쇠가 찰칵, 총을 보며 당황하는 모션(`kdry`, attack1·teeter 프레임 조합, 임시). 재장전: 필드 15초(빈 뒤부터), 대기석 1발/1초. 폭탄: 마지막으로 던진 뒤 필드 25초 / 대기석 10초에 3개 전부 보충 (오너 2026-11-04, 대기석 수치는 임시)
  - 궁극기: **연쇄 기폭** — 즉시 재장전 → 적 하나를 두고 여러 방향(땅·공중·앉아·머리 위·반대편)에서 순간이동하며 총·폭탄을 다 털고 → 즉시 재장전 → 한 번 더 빠르게 → 등 뒤에 착지해 플런저 → 쌓인 표식·폭탄 연쇄 폭발. 순간이동마다 정지(히트스톱)·잔상 (오너 확정 2026-11-04)
  - 대시: 빙글빙글 구르며 돌진. 벽에 부딪히면 피격 모션으로 뒤로 튕겨 나옴.
  - 일반 총 사격 공격 모션은 그대로 써도 됨.
- **구현됨 (2026-11-04)**: 이름 케닌 클로, 키 `kenin`, 도적 · 원거리 · 트릭스터.
  - 시트: `assets/chars/kenin/kenin_0..3.png` (+ 빈 `_4`). 줄 배치는 `chars.gd` A_KENIN. Sprite Flow 결과를 자르고 묶는 도구는 `tools/sprite_flow/` (trim.py → pack_kenin.py; 원본 프레임은 Sprite Flow 계정의 webm에서 받음 — 작업 공간에는 없음)
  - 전투는 `scripts/kenin.gd` 한 곳: 장탄·재장전(필드 빈 총은 RELOAD_FIELD 뒤 재장전, 대기석에선 빠르게 1발씩), 빈 총 약사격(DRY), 점착 폭탄(붙음 → FUSE 뒤 폭발, 붙은 적에 총알 맞으면 즉시 ×BOMB_HEAD), 표식(`add_marks`, 몸 여기저기 찍히는 도장), 연쇄 기폭(`chain_detonate` → `_step_chain` 대기열, CHAIN_GAP0·CHAIN_ACC·CHAIN_GAP_MIN), QTE 원호(`assist`), 궁 전용 `ult_shot`(반드시 맞는 예광탄)·`ult_bomb`. 차징: player.gd `kcharge`/`kfire`(VIRT, detonate 줄 3~8 프레임). player.gd: `kenin_shoot`, `bomb` 동작, 구르기(dash 9프레임, f1~6 무적, 벽에 막히면 `roll_bounce` → hurt + 뒤로 밀림, 피해 없음), `bench_assist` / `counter_assist`(QTE_STAY 멤버는 교대 안 함, swap_cd 0). ult.gd `_step_kenin`.
  - 영입: 길드 등급 2 승인 때 합류 (`fame.gd` KENIN_RANK, **임시**)
  - **테스트 빌드: 모든 동료가 처음부터 영입됨** (`fame.gd` ALL_IN = true, 오너 요청 2026-11-04). 정식 흐름으로 돌릴 땐 false. 테스트·캡처 스크립트(-s)는 원래 흐름
  - 크기: SCALE 0.88 (머리 크기를 맞춤). Sprite Flow 캔버스가 두 종류(960×960 / 1112×834)라 모션마다 키가 달랐음 → trim.py가 모션별 첫 프레임 키로 맞춤(서 있는 키 186px). 밝기: pack_kenin.py의 tone() — Sprite Flow 프레임이 너무 어두워서 밝기 분위수 곡선으로 보정
  - QTE 원호는 적의 등 뒤(조작 중인 동료 반대편)에서 나타남 (오너 요청)
  - **임시(PLACEHOLDER)**: kenin.gd의 모든 수치, STATS/ULTMAX, 노드 트리(전부 "(예정)"), 시작 장비 이름, 마을 대사·브랜 대사(「(임시)」 표기), 스킬 탭 설명의 숫자, 얼굴·초상(원화 크롭), 스킬 아이콘(선 그림 폭탄), 총소리·폭발음(기존 stab·heavy·slam 재활용)
  - 일러 받음 (2026-11-04): 기본 `kenin_base`, 장비 `kenin_gear`, 스킬 `kenin_skill`, 기억 `kenin_rec`, 메모리얼 전 기록 전체샷 `kenin_old_base` (표정 하나 — 기록 대사 표정은 base로 대체), 실루엣은 tools/memgen/sil.py
  - 필요한 에셋(오너에게 요청): 총소리·폭발음·폭탄 붙는 소리(상용 팩), 표정 차분(cl/smile/sup), 피격 초상, 얼굴, 궁 컷씬 영상(궁 일러는 스킬 일러 재활용, 2026-11-04), 스킬 아이콘, 메모리얼 일러(`kenin_mem` + 눈 감은 `_mem_c`)
  - 테스트 `tests/test_kenin.gd`, 녹화 `tools/capture/movie_kenin.gd`

## 4-3. 편성 화면 (오너 요청 2026-11-04)

- `scripts/ui_party.gd` 새로 씀: 슬롯 3칸(= player.party 순서, 빈 칸은 뒤로) → 칸을 누르면 책상 화면.
- 책상: 나무 책상 + 램프, 왼쪽 「임무 파견 명령서」(채울 칸에 빨간 연필 동그라미), 오른쪽 인사 서류철(이름 탭·클립 사진·분류·「파견 0N」 도장). 서류 한 번 누르면 들림, 한 번 더(또는 「배정」) 누르면 명령서로 날아가고 「배정」 도장 → 슬롯 화면.
- 다른 칸에 있는 인물이면 자리 교환, 빠져 있던 인물이면 그 칸 사람을 대신함(리더 칸이면 새 사람이 조작). 빼기는 리더·마지막 1명 불가(리더는 교체로).
- 테스트 `tests/test_w4.gd`, 캡처 `tests/cap_party.gd`.

## 5. 이번 세션에 끝낸 것 (모두 main, 푸시·배포 완료)

- 타이틀 로고에 한글(동해독도체 B안), 붓 로고·그림 `d7601c9`
- 타이틀 재설계: 살아 있는 마을 배경 `b69aa5a`, 음악 구동 `9a118da`, 5단계(항상 마을, 따라가는 카메라, 박자 맞춘 UI, 시작 = 이어하기, 불러오기 슬롯 카드) `039e870`, 인게임 허브식 메뉴 버튼 `9c3dd09`, 메뉴 옆 꽃 삭제 `d094709`, 타이틀 걷는 속도 늦춤 `227b51d`
- 저장 슬롯: 자동 저장 + 슬롯 1·2·3, 허브의 "저장" `039e870`
- 전체화면: 타이틀 첫 탭에서 요청 `2861056`, 손 뗄 때 요청(폰) `25b3a5d`, 전체화면에서 화면 찌그러짐 수정 `66d9b2d`
- 화면 효과(타격감): 무게별 히트스톱·왜곡·색수차·줌, 패링 반전, 피격 비네트, 사망 탈색 `4f93353`
- 사운드: 상용 팩 OGG·UI 소리·음량 슬라이더 `1f7aad8`, 리미터 `eeb1d39`, 던전 음악 3곡과 격자 맞춤 `2b58cf7` `497b8cd`, ElevenLabs 타격 세트 `7365eb0`, 패링 "쾅" `08d1829`, 깨지는 소리 제거·음악 루프 버그 `996b198`, 슬라이드 소리 제거 `241daea`, 대시 `7de10dc`, 착지음 `271cc3b` `ccbe549`, 아이다 소리 `358455b`
- 모험 수첩의 레벨 배지가 본문을 가리던 문제 `a0f3aac`
- 에일린 달리기와 부재 중 접수대 업무(쪽지) `e556f33`, 새 걷기 `a0aad8f`
- 본관 창문 빛이 캐릭터 위에 그려지던 문제 `b39693c`
- 걷기 시트: 에스텔 초심 35장·아이다 11포즈·루체 27장·브랜 25장, 발이 미끄러지지 않게 보폭 맞춤, 브랜 산책 `77bc940`
- 쓰러진 동료가 마을·본관에 오면 부활 `ed72412`, 마을·본관에 오면 파티 전원 HP 전부 회복 `1530be4`
- 이 문서, `tools/runtests.sh`, `tools/capture/` (이 커밋)

## 6. 남은 일 / 보류

보류(오너가 미룸 — 오너가 다시 꺼낼 때까지 손대지 않음):
- 전투 배경음 교체: "전투 브금이 좀 많이 아쉽긴 하다. 나중에 바꾸든 하자." 새 곡이 오면 `battle.ogg`를 -14 LUFS로 맞추고 루프 지점·`beat_maps.gd` 박 지도를 다시 잰다(`tools/make_beat_maps.py`)

미해결(오너가 불만을 말했고 아직 답이 없음):
- 점프 소리가 여전히 애매하다(오너: "점프가 다 애매해", 상용을 써야 하나 고민). 지금은 20 %로 거의 안 들리게만 해 둠. 새 파일이 오면 교체
- 착지음 타이밍: "아직 좀 늦는 것 같다" → `ccbe549`로 3프레임 앞당겨 배포. 오너 확인은 아직. 늦으면 `LAND_LEAD`만 키우면 된다
- AI 그림 문제: 오너가 "작업물이 죄다 AI라 홍보에 걸림돌", "일러스트는 직접 그리는 게 낫긴 한데"라고 함. 내가 교체 순서(타이틀 키아트 → 대화창 초상화 → 로고 → 메뉴 일러스트, 도트는 나중)와 **교체 목록**(그림마다 크기·여백·투명 여부·화면 캡처, 파일 이름만 같으면 덮어쓰기)을 만들어 주겠다고 제안했다. 오너 답 없음 — **아직 안 만들었다.** 다음에 만들지 물어보거나, 오너가 원하면 바로 만든다
- 홍보 범위(길드 안 / 국내 커뮤니티 / 스팀·itch): 물어봤고 답 없음
- 걷는 속도가 전보다 느려짐(새 시트 보폭이 짧음: 타이틀 36~56 px/s, 마을은 최대 1.3배). 너무 느리면 말해 달라고 했고 답 없음. `townsfolk.gd` TOWN_RATE / TITLE_PACE
- 아이다 걷기 시트 원본 자체가 몇 프레임에서 발이 3~4 px 밀린다. 거슬리면 시트를 다시 받는 게 제일 깔끔(그 프레임은 50 ms로 잡아 둠)
- 타이틀 카메라가 브랜을 따라가지 않는다(산책이 짧아서, 카메라는 280 px 이상 걸을 사람만 따라감). 대장간 쪽으로 갔을 때만 보임
- 다친(쓰러지지 않은) 동료 회복 여부를 물었고, 오너가 "마을 돌아오면 회복되게"로 답해 `1530be4`로 끝남 — 해결됨
- `break` 소리: 아이다·루체 필살기에서 빼고, 허수아비·유령·보스 상자는 "쿵"(down)으로 바꿈 `8879ac3` — 해결됨
- 임시 문구들(1절 목록)을 오너 대사로 바꾸기
- 진행표의 남은 단계: 4단계 나머지 UI 연출, 5단계 길드 시스템(README "진행")
- 기획 쪽 미정 사항(패키지·모바일 판, 피로도, 영입 조건 등)은 기획안 확정본에서 다룬다: https://claude.ai/artifact/UyVyQL8JXbAJMJXvJXnoHu (확정된 것만. 애매해서 뺀 항목 목록은 오너에게 보고했고 답은 아직)

**스프라이트 제작 방식 전환 (진행 중, 이 세션 마지막 주제)**
- 지금까지 시트는 GPT로 뽑았다. 오너: 그림체 통일은 신경 쓰지 말고 퀄리티·성능 좋은 쪽으로 바꾼다.
- 원화(기준 이미지)는 NAI **V4.5** (V5는 캐릭터 레퍼런스가 안 돼서). 정면·A포즈·소품이 몸을 가로지르지 않게. 프롬프트는 그 채팅에 있음(영어 태그식).
- 원화 → 실제 도트 크기: `tools/pixel/pixelize.py` (축소·Lab k-means 16~24색·잡티·1px 머리털 제거·외곽선). 얼굴은 자동으로 약해져서 몇 칸 손봐야 함.
- 생성 서비스: **PixelLab** 시험 완료(정지 이미지·동작 둘 다 "나쁘지 않음"; 업로드 최대 256, 뼈대 애니메이션 캔버스 최대 128, 남쪽 정면 필수). **Sprite Flow**가 다음 시험 대상(옆모습 지원, 최대 512, Godot 내보내기, API/MCP — 상업 라이선스 확인 필요).
- PixelLab 결과 정리 규칙(오너 지시): 반투명 테두리 정리·외곽선·잡티 OK, **얼굴 도트는 크게 바꾸지 말 것(눈은 손대지 않음)**, 비슷한 색만 1~2색으로 합치기, 끊어진 머리카락은 잇기. 예시 스크립트 `tools/pixel/cleanup_pixellab.py`(좌표가 그 한 장 전용).
- **결정 (2026-11-03)**: 기존 캐릭터(에스텔·아이다·루체·브랜·에일린)의 시트는 지금 것 그대로 쓴다. **앞으로 만드는 새 캐릭터는 Sprite Flow로 뽑는다.** 에스텔 원화로 PixelLab과 나란히 비교하는 계획은 취소.
- Sprite Flow 연결 방법: 오너가 claude.ai 커스텀 커넥터로 `https://spriteflow.io/api/mcp`를 붙였다(인증 "로그인 없음" + Request header `Authorization: Bearer <키>`). 도구: get_credit_balance, search_assets, create_upload_url / confirm_upload, estimate_cost, generate_character, generate_sprite_motion(Classic 8장 / Pro 32장), generate_direction_sprites / _animation, get_task, get_download_url 등. 생성 전에는 항상 estimate_cost. 시작 시 잔액 595크레딧.
  - 파일 업로드·다운로드는 Cloudflare R2(`93f3340089e53560d7fc247d7a422b68.r2.cloudflarestorage.com`) 서명 URL(5분 만료)로 오간다. 오너가 claude.ai 설정의 네트워크 접근을 켜서 이 세션에서 받기가 됐다. `spriteflow.io` 자체는 셸에서 여전히 막힘(문서는 오너가 캡처로 보여 줘야 함). 새 세션에서 막히면 같은 설정을 확인해 달라고 할 것.
  - 계정에 이미 있는 것: 에스텔(초심 옷) Pro 모드 `run-sprint-cycle` 32장, `attack-slash-combo` 32장, 1024×1024 RGBA. 기존 캐릭터는 안 바꾸기로 했으니 참고용.
- 다음: 새 캐릭터가 정해지면 원화(NAI V4.5 정면) → Sprite Flow 업로드 → 옆모습·동작 생성 → 받아서 `tools/pixel/` 정리 → 게임에 넣고 영상 확인. "스프라이트 작업대"(폰에서 시트/영상 올리면 자르기·정렬·정리·미리보기·확정) 제작 제안은 아직 걸려 있음.

작업 공간이 사라지면서 없어지는 것:
- 오너가 첨부한 원본 사운드(Cymatics zip, 効果音ラボ, ElevenLabs mp3), 원본 걷기 시트, 로고 원본, scratchpad의 캡처·디버그 스크립트. 저장소에는 가공본만 있다
- worktree들(`/home/claude/cva-*`)은 모두 main에 머지됨. 새로 만들 필요 없음

## 7. 다음 세션 시작 방법

1. 저장소를 받고 이 문서와 `README.md`를 읽는다. `git log --oneline | head -30`으로 이 문서 뒤에 뭐가 바뀌었는지 본다.
2. 2절대로 고도 4.4.1을 받고 `$GODOT --headless --path . --import` 뒤 `GODOT=$GODOT tools/runtests.sh`로 전부 통과하는지 확인한다.
3. 오너에게 한국어로, 6절의 "미해결" 중 답이 필요한 것(교체 목록 만들지, 홍보 범위, 걷는 속도, break 소리)을 짧게 묻거나, 오너가 새로 준 요청부터 한다.
4. 작업 → 캡처·영상으로 확인 → 테스트 → 커밋·푸시 → `gh api`로 배포 성공 확인 → 영상과 함께 한국어로 보고.
5. 큰 결정을 새로 정하면 이 문서의 4절·6절을 고쳐 둔다.
