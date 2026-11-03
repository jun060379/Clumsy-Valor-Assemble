extends RefCounted
## Costume skins: the registry (scripts/skins.gd reads it; the 의상 tab and the wardrobe show it).
## Each skin is a full costume for one member: five sprite sheets in the exact layout of the 기본 sheets, its standing art,
## its round face and, where it has them, the other pictures the screens use. Files live in assets/skins/<id>/ (docs/skin_assets.md).
## Every entry:
##   id       unique id; also the asset folder name (assets/skins/<id>/)
##   c        "estelle" / "aida" / "luce"
##   n, d     name and one-line description shown in the 의상 tab and the wardrobe
##   unlock   {kind, value}:
##              default  always owned (the 기본 of each member)
##              fame     guild fame grade reward: value = the grade (2..7); granted on the rank-up, shown in the rank cut's list
##              drop     boss chest: value = the lowest chest grade that can hold it (0 커먼 .. 4 레전더리, loot.gd CGN);
##                       a low chance per chest (DROP_CHANCE), only skins whose art is in
##              level    character level: value = the level (12 = 메모리얼 해방)
##              shop     bought in the wardrobe: value = price in shillings (only once its art is in)
##              story    a story reward: value = the story key; the story system calls skins.grant(id, "story")
##   dir      the asset folder ("" = the original art in assets/chars, assets/ui/st, ... as it always was)
## optional, for a costume drawn in parts or with its own timing:
##   rows     the sheet rows this costume draws itself (others come from the original art, row by row); absent = all 35
##   anims    {anim: [row, [ms...]]}: its own frame count / timing / row for an animation (frames run 9 a row, then wrap
##            to the next row; rows past 34 live in sheet_5.png ...)
##   bob      {anim: [...]}: its own stride bob (empty = none: the frames carry it); steps {anim: [frames]}: footfalls
##   stride   {anim: world px a cycle}: the ground its walk covers (townsfolk.gd natural_speed: stride / the cycle's ms)
##   partial  true: "부분 완성" on the screens; done = the animations it has
##   placeholder  true: the name / description were invented and wait for the user's own (the 기본 entries: only the description)

const BASE := {"estelle": "estelle_base", "aida": "aida_base", "luce": "luce_base"}
## 초심's run and walk, played at sprite timing (tools/make_skin_chosim.py):
##   run: run_7f (fourth delivery, fringes cleaned by tools/fix_run7.py), 7 frames for two steps, rotated so its
##        footfalls (its frames 3 and 6) are frames 1 and 4; 620 ms a cycle (each step 310 ms) and a dip on each contact
##        (BOB_RUN). The art's stride is short for player.gd RUN 0.36 px/ms, so the soles slide a little
##   walk: the user's 35-frame walk (2026-11, tools/make_walk.py; replaces walk_43f's 10), rows 36-39, below
## The members' own walk cycles (tools/make_walk.py, 2026-11): cut from the user's one-row walk sheets, every frame's
## planted sole on the feet line and its head + torso on the cell's centre, scaled and colour-matched to the member's
## in-game rows. Each frame's time is the planted sole's measured shift to the next frame over one ground speed, so a
## walker moving at "stride" (world px a cycle) / the cycle keeps the foot under her still (townsfolk.gd natural_speed).
## The art spaces its frames unevenly (아이다's is drawn on twos and threes: 11 poses), hence the uneven times; in
## 아이다's frames 1-2 and 5 / 8-10 the planted boot barely moves, so those poses are held 50 ms and her sole slides
## there by up to ~2.5 world px.
const WALK_EST := [20, 25, 24, 36, 24, 36, 31, 39, 27, 33, 31, 46, 24, 38, 26, 39, 25, 37, 25, 37, 24, 37, 24, 37, 27, 42, 32, 44, 27, 37, 25, 36, 23, 32, 20]   # 1090 ms
const WALK_AIDA := [136, 50, 204, 122, 163, 50, 201, 182, 50, 50, 50]               # 1258 ms (poses held >= 50 ms: drawn on twos)
const WALK_LUCE := [64, 57, 48, 59, 52, 39, 64, 35, 31, 20, 20, 29, 57, 37, 46, 59, 50, 48, 42, 55, 34, 58, 43, 20, 21, 46, 50]   # 1184 ms
## world px of ground a walk cycle covers (the planted sole's travel over the cycle × the member's draw scale)
const STRIDE_EST := 55.9
const STRIDE_AIDA := 45.5
const STRIDE_LUCE := 58.7
const RUN7 := [103, 103, 103, 78, 78, 78, 77]         # contact (1) → contact (4) is 3 frames, 4 → 1 is 4: each step 310 ms, 620 ms a cycle
const BOB_RUN := [-4, 3, 1, -2, 3, 1, -3]              # world px, + = down: dip on the contacts (1, 4), up in the flights (0, 3, 6)
## parry / air_parry have no art: attack2's rising cut and air_combo's (make_skin_chosim.py COMPOSE). Frames 0-1 keep the
## parry window (180 + 35 ms; drawn as guard frame 1 until a parry lands, player.gd _draw); after a parry lands the cut
## shows 110 ms and the raised blade 240 ms (기본's 200 + 150: the same 350 ms, a smear frame shouldn't hang)
const PARRY4 := [180, 35, 110, 240]
const STEP_RUN7 := [1, 4]       # the frames a foot lands (dust puffs, footstep sounds)
const ROOT := "res://assets/skins/"

const SKINS := [
	# 초심: Estelle's default since the white dress arrived. Every sprite row is its own now (tools/make_skin_chosim.py;
	# parry / air_parry / tag_in / tag_out made of its other rows' frames); partial because the pictures besides st_base
	# (face, bust, the tab art, ...) still come from the original art (미숙한 결의's files).
	{"id": "estelle_base", "c": "estelle", "n": "초심", "d": "흰 드레스에 검은 소매, 검 한 자루. 방패도 망토도 없이 다시 시작하는 차림.", "unlock": {"kind": "default", "value": 0},
		"dir": ROOT + "estelle_base/", "placeholder": true, "partial": true,
		# own rows: 0 idle · 3 start · 4 stop · 5 turn · 6 jump · 7 runjump · 8-10 attack1-3 · 11 kneel · 12 kneel_attack ·
		# 13 attack_high · 14 guard · 15 parry · 16 air_combo · 17 dive · 18 double_jump · 19 hurt · 20 death · 21 dash ·
		# 22 vow · 23 air_guard · 24 air_parry · 26 tag_in · 27 tag_out · 28 teeter · 35 run (7) · 36-39 walk (35)
		"rows": [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 26, 27, 28, 35, 36, 37, 38, 39],
		"anims": {"run": [35, RUN7], "walk": [36, WALK_EST], "parry": [15, PARRY4], "air_parry": [24, PARRY4]},
		"bob": {"run": BOB_RUN, "walk": []},      # run: Aida's bounce on top of the frames' own; walk: the frames' own
		"steps": {"run": STEP_RUN7}, "stride": {"walk": STRIDE_EST},
		"breath_top": 158,                         # the head's top in the idle cells (player.gd idle breathing)
		"done": ["idle", "start", "stop", "turn", "jump", "runjump", "run", "walk", "attack1", "attack2", "attack3", "kneel",
			"kneel_attack", "attack_high", "guard", "parry", "air_combo", "dive", "double_jump", "hurt", "death", "dash", "vow",
			"air_guard", "air_parry", "tag_in", "tag_out", "teeter"]},
	# 미숙한 결의: the original art (cape and shield), the files in assets/chars/estelle and assets/ui/st as they always were
	{"id": "estelle_misuk", "c": "estelle", "n": "미숙한 결의", "d": "망토와 방패를 두르고 길드 문을 처음 두드리던 날의 차림.", "unlock": {"kind": "story", "value": "estelle_misuk"}, "dir": "", "placeholder": true},
	{"id": "estelle_s1", "c": "estelle", "n": "순례자의 여행복", "d": "먼 길을 걷는 순례자의 차림. 방패는 등에 메고, 망토 자락엔 길 먼지가 앉았다.", "unlock": {"kind": "fame", "value": 2}, "dir": ROOT + "estelle_s1/", "placeholder": true},
	{"id": "estelle_s2", "c": "estelle", "n": "축제의 밤 드레스", "d": "마을 축제 날 빌려 입은 드레스. 방패를 들어도 춤출 수 있게 치맛단을 줄였다.", "unlock": {"kind": "shop", "value": 300}, "dir": ROOT + "estelle_s2/", "placeholder": true},
	{"id": "aida_base", "c": "aida", "n": "기본", "d": "묘지기 앞치마 원피스와 흙 묻은 장화.", "unlock": {"kind": "default", "value": 0}, "dir": ROOT + "aida_base/", "placeholder": true, "partial": true,
		# own standing art (st_base, st_cl) and walk (rows 35-36, sheet_5); the other sprites are the original's
		"rows": [35, 36], "anims": {"walk": [35, WALK_AIDA]}, "bob": {"walk": []}, "stride": {"walk": STRIDE_AIDA}, "done": ["walk"]},
	{"id": "aida_s1", "c": "aida", "n": "묘지기의 상복", "d": "검은 베일과 긴 상복. 동굴 깊은 곳 상자에서 나온, 누군가의 장례 차림.", "unlock": {"kind": "drop", "value": 2}, "dir": ROOT + "aida_s1/", "placeholder": true},
	{"id": "aida_s2", "c": "aida", "n": "균열 너머의 옷", "d": "기억을 끝까지 따라간 끝에서 꺼내 온 옷.", "unlock": {"kind": "level", "value": 12}, "dir": ROOT + "aida_s2/", "placeholder": true},
	{"id": "luce_base", "c": "luce", "n": "기본", "d": "수습 사제 로브와 헝겊 신.", "unlock": {"kind": "default", "value": 0}, "dir": ROOT + "luce_base/", "placeholder": true, "partial": true,
		# own standing art (st_base, st_cl) and walk (rows 35-37, sheet_5); the other sprites are the original's
		"rows": [35, 36, 37], "anims": {"walk": [35, WALK_LUCE]}, "bob": {"walk": []}, "stride": {"walk": STRIDE_LUCE}, "done": ["walk"]},
	{"id": "luce_s1", "c": "luce", "n": "성가대 수습복", "d": "성가대 수습 시절의 흰 옷. 이야기가 이어지면 받을 수 있다.", "unlock": {"kind": "story", "value": "luce_choir"}, "dir": ROOT + "luce_s1/", "placeholder": true},
	{"id": "luce_s2", "c": "luce", "n": "여름 휴가 차림", "d": "밀짚모자와 가벼운 원피스. 길드가 마을의 자랑이 된 기념.", "unlock": {"kind": "fame", "value": 3}, "dir": ROOT + "luce_s2/", "placeholder": true},
]

## the chance a boss chest of each grade (0 커먼 .. 4 레전더리) holds a costume token
const DROP_CHANCE := [0.0, 0.03, 0.06, 0.10, 0.15]

## The pictures a skin can bring. base: the 기본 file ({c} = member, {i} = sheet number, {p} = BUST / DOLL name);
## file: the name in the skin folder (.png or .webp); n: how many (the sheets); need: without it the skin is "준비 중".
## "sil" keys pair with their picture: a skin that brings the picture but not its silhouette draws without one.
## "alt": the faces of one standing picture (blink, smile, surprise) — a skin with its own st_base but not this face shows its
## st_base instead, so a blink never flashes another costume.
const ASSETS := {
	"sheet": {"base": "res://assets/chars/{c}/{c}_{i}.png", "file": "sheet_{i}", "n": 5, "need": true},
	"st_base": {"base": "res://assets/ui/st/{c}_base.webp", "file": "st_base", "need": true},
	"face": {"base": "res://assets/ui/faces/{c}.png", "file": "face", "need": true},
	"st_cl": {"base": "res://assets/ui/st/{c}_cl.webp", "file": "st_cl", "alt": "st_base"},
	"st_smile": {"base": "res://assets/ui/st/{c}_smile.webp", "file": "st_smile", "alt": "st_base"},
	"st_sup": {"base": "res://assets/ui/st/{c}_sup.webp", "file": "st_sup", "alt": "st_base"},
	"st_gear": {"base": "res://assets/ui/st/{c}_gear.webp", "file": "st_gear"},
	"st_skill": {"base": "res://assets/ui/st/{c}_skill.webp", "file": "st_skill"},
	"st_skill_sil": {"base": "res://assets/ui/st/{c}_skill_sil.webp", "file": "st_skill_sil", "pair": "st_skill"},
	"st_rec": {"base": "res://assets/ui/st/{c}_rec.webp", "file": "st_rec"},
	"st_rec_sil": {"base": "res://assets/ui/st/{c}_rec_sil.webp", "file": "st_rec_sil", "pair": "st_rec"},
	"st_full": {"base": "", "file": "st_full"},                                  # 기록's full-body shot (the original art has none: its talking faces)
	"st_full_sil": {"base": "", "file": "st_full_sil", "pair": "st_full"},
	"bust": {"base": "res://assets/fame/{p}.png", "file": "bust"},
	"ult_art": {"base": "res://assets/ult/ult_art_{c}.png", "file": "ult_art"},
	"doll": {"base": "res://assets/hall/{p}.png", "file": "doll"},
}
const BUST := {"estelle": "por_est", "aida": "por_aida", "luce": "por_luce"}
const DOLL := {"estelle": "dollP", "aida": "dollG", "luce": "dollC"}
const EXT := [".png", ".webp"]

const KIND_N := {"default": "기본", "fame": "명성 보상", "drop": "보스 상자", "level": "레벨", "shop": "상점", "story": "이야기"}
const CHEST_N := ["커먼", "레어", "에픽", "유니크", "레전더리"]


static func get_skin(id: String) -> Dictionary:
	for s in SKINS:
		if s["id"] == id: return s
	return {}

static func of(c: String) -> Array:
	return SKINS.filter(func(s): return s["c"] == c)

static func kind(id: String) -> String:
	var s := get_skin(id)
	return String(s["unlock"]["kind"]) if not s.is_empty() else ""

static func is_base(id: String) -> bool:
	return BASE.values().has(id)

## how to get it, one line ("길드 명성 2등급 「동네 소문」 보상")
static func how(id: String, ranks: Array = []) -> String:
	var s := get_skin(id)
	if s.is_empty(): return ""
	var u: Dictionary = s["unlock"]
	var v = u["value"]
	match String(u["kind"]):
		"default": return "처음부터 갖고 있다"
		"fame":
			var rn: String = ranks[int(v) - 1]["n"] if int(v) - 1 < ranks.size() else ""
			return "길드 명성 %d등급%s 보상" % [int(v), (" 「%s」" % rn) if rn != "" else ""]
		"drop": return "보스 상자 · %s 이상에서 낮은 확률" % CHEST_N[clampi(int(v), 0, 4)]
		"level": return "Lv %d · 메모리얼 해방" % int(v) if int(v) >= 12 else "Lv %d 달성" % int(v)
		"shop": return "옷장에서 실링 %d" % int(v)
		"story": return "이야기 진행 보상 (이야기 준비 중)"
	return ""

## the fame grade rewards in data: the costume names a grade grants
static func fame_rewards(grade: int) -> Array:
	var L: Array = []
	for s in SKINS:
		if s["unlock"]["kind"] == "fame" and int(s["unlock"]["value"]) == grade: L.append(s)
	return L
