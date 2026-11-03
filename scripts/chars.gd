extends RefCounted
## The party members: sheets, animation tables, stats. Carried over 1:1 from the web prototype
## (A_EST, A_SH = Aida, A_LU = Luce, VIRT, CHAR_SCALE, STATS, ROWFIX_SH).
## row = sheet row (sheet = row / 7, row % 7 inside it); each cell is 448x352. Row -1 = composite (see VIRT).

const CELL_W := 448
const CELL_H := 352
const ROWS_PER_SHEET := 7

const NAME := {"estelle": "에스텔", "aida": "아이다", "luce": "루체", "kenin": "케닌"}
const LATIN := {"estelle": "ESTELLE", "aida": "AYDA", "luce": "LUCE", "kenin": "KENIN"}
const COLOR := {"estelle": Color("#ff4d9a"), "aida": Color("#9a5cff"), "luce": Color("#ffc94d"), "kenin": Color("#9cc14a")}
const SCALE := {"estelle": 1.3, "aida": 1.25, "luce": 1.2, "kenin": 0.88}     # kenin: head size matched (his head and body are big in the cell)
const STATS := {"estelle": {"hp": 70.0, "atk": 1.0, "as": 0.95}, "aida": {"hp": 50.0, "atk": 1.2, "as": 1.1}, "luce": {"hp": 40.0, "atk": 0.9, "as": 1.0}, "kenin": {"hp": 45.0, "atk": 1.0, "as": 1.0}}   # kenin: PLACEHOLDER numbers
## Aida's sheet rows were drawn at slightly different sizes: scale each row to match her idle pose
const ROWFIX_AIDA := {8: 1 / 1.04, 9: 1 / 1.12, 14: 1 / 1.1, 15: 1 / 1.08, 16: 1 / 1.08, 17: 1 / 1.05, 18: 1 / 1.03, 19: 1 / 1.03, 20: 1 / 1.07}
## CHARS[c].bob: the body bobs with the stride (world px per frame of run / walk)
const BOB := {"estelle": {"run": [0, 2, -3, -1, 0, 2, -3, -1], "walk": [0, 2, -3, -1, 0, 2, -3, -1]},
	"aida": {"run": [0, 3, -4, -1, 0, 3, -4, -1], "walk": [0, 3, -4, -1, 0, 3, -4, -1]},
	"luce": {"run": [0, 3, -4, -1, 0, 3, -4, -1], "walk": [0, 3, -4, -1, 0, 3, -4, -1]},
	"kenin": {"run": [0, 0, 0, 0, 0, 0, 0, 0], "walk": [0, 0, 0, 0, 0, 0, 0, 0]}}         # Sprite Flow frames carry their own bounce
## drawFrame's idle breathing: the top of the head in the source cell (legs stay, the torso stretches by whole pixels)
const BREATH_TOP := {"estelle": 162, "aida": 155, "luce": 147, "kenin": 154}
## PAL[CHAR].ghost: the afterimage tint (colour, how much of it over the sprite)
const GHOST := {"estelle": [Color8(255, 170, 220), 0.75], "aida": [Color8(255, 170, 220), 0.75], "luce": [Color8(255, 225, 140), 0.8], "kenin": [Color8(200, 230, 150), 0.75]}
## guard key = each member's skill; Estelle has the only shield
const SKILL := {"estelle": "방패", "aida": "균열", "luce": "치유", "kenin": "점착 폭탄"}
## who can answer which moment (QTE): Estelle covers a hit ally, Aida a finisher/parry, Luce someone in danger or a parry,
## Kenin a finisher or a parry with covering fire (he answers from the bench: no swap, kenin.gd assist)
const QTE_WHO := {"hit": ["estelle"], "low": ["luce"], "finisher": ["aida", "kenin"], "backstab": ["aida"], "parry": ["aida", "luce", "kenin"]}
const QTE_LBL := {"estelle": "수호", "aida": "기습", "luce": "구원", "kenin": "원호"}
## members whose QTE is answered from the bench without swapping in
const QTE_STAY := ["kenin"]

const COMMON := {
	"charge": [-1, [110, 1000000000]], "acharge": [-1, [110, 1000000000]], "gcharge": [-1, [1000000000]], "cthrust": [-1, [45, 60, 220, 170]],
	"kcharge": [-1, [70, 70, 90, 1000000000]], "kfire": [-1, [40, 60, 300, 200]],     # Kenin's detonator (charged attack)
	"airdash": [-1, [40, 55, 60, 60, 60, 90]], "backstep": [-1, [60, 110, 120]], "swap_in": [-1, [55, 55, 55, 55, 60, 70]],
	"teeter": [28, [150, 140, 150, 190]], "teeterL": [-1, [300, 300, 340, 300]],
}

const A_EST := {
	"idle": [0, [180, 180, 180, 180]], "run": [2, [90, 80, 80, 90, 90, 80, 80, 90]], "walk": [2, [150, 150, 150, 150, 150, 150, 150, 150]],
	"start": [3, [35, 45, 45, 40]], "stop": [4, [110, 180, 150, 190]], "turn": [5, [55, 75, 55, 55]],
	"jump": [6, [80, 70, 110, 160, 110, 120, 90, 120]], "runjump": [7, [80, 100, 130, 100, 110, 80]],
	"attack1": [8, [80, 130, 50, 110, 90]], "attack2": [9, [60, 70, 40, 80, 70]], "attack3": [10, [80, 260, 50, 240, 140]],
	"kneel": [11, [320, 300, 300, 320]], "kneel_attack": [12, [80, 120, 80, 50, 160, 100]], "attack_high": [13, [80, 120, 50, 80, 180]],
	"guard": [14, [120, 200, 160, 200]], "parry": [15, [180, 35, 200, 150]],
	"air_combo": [16, [70, 50, 110, 60, 50, 120, 80, 50, 200]], "dive": [17, [70, 80, 120, 160, 110, 120]],
	"double_jump": [18, [70, 60, 60, 60, 70, 110]], "hurt": [19, [80, 140]], "death": [20, [150, 170, 170, 400]],
	"dash": [21, [35, 45, 55, 55, 60, 80]], "air_guard": [23, [120, 200, 160, 200]], "air_parry": [24, [180, 35, 200, 150]],
	"tag_in": [26, [70, 70, 60, 150, 120, 160]], "tag_out": [27, [150, 150, 150, 170]],
	"vow": [22, [1000000000, 1000000000, 1000000000]],                       # ult 수호의 맹세: the oath pose (posed frame by frame)
}
const A_AIDA := {
	"idle": [0, [180, 180, 180, 180]], "run": [1, [80, 75, 80, 75, 80, 75, 80, 75]], "walk": [1, [145, 140, 145, 140, 145, 140, 145, 140]],
	"start": [2, [45, 55, 55, 55]], "stop": [3, [70, 100, 80, 100]], "turn": [4, [55, 75, 55, 55]],
	"jump": [5, [80, 70, 110, 160, 110, 120, 90, 120]], "runjump": [6, [80, 100, 130, 100, 110, 80]],
	"attack1": [7, [80, 130, 50, 110, 90]], "attack2": [8, [60, 70, 40, 80, 70]], "attack3": [9, [80, 260, 50, 240, 140]],
	"kneel": [10, [320, 300, 300, 320]], "kneel_attack": [11, [80, 120, 80, 50, 160, 100]], "attack_high": [12, [80, 120, 50, 80, 180]],
	"air_combo": [13, [70, 50, 110, 60, 50, 120, 80, 50, 200]], "dive": [14, [70, 80, 120, 160, 110, 120]],
	"double_jump": [15, [70, 60, 60, 60, 70, 110]], "hurt": [16, [80, 140]], "death": [17, [150, 170, 170, 400]],
	"dig_in": [18, [60, 55, 55, 60]], "dig_out": [-1, [60, 60, 80, 100]], "tp_in": [-1, [50, 60, 70, 90]],
	"mark": [20, [300, 300]], "amark": [-1, [300, 300]], "rturn": [-1, [60, 80, 60, 90]],
	"dash": [29, [35, 45, 55, 55, 60, 80]], "tag_in": [25, [70, 70, 60, 150, 120, 160]], "tag_out": [26, [150, 150, 150, 170]],
	# ult 땅 밑의 문: the reaching-hand rift poses (drawn only, posed frame by frame)
	"umark": [-1, [150, 150]], "ucast": [21, [150, 150, 150, 150]], "ulunge": [22, [1000000000, 1000000000, 1000000000, 1000000000]], "ufin": [23, [1000000000, 1000000000, 1000000000, 1000000000]],
}
const A_LUCE := {
	"idle": [0, [180, 180, 180, 180]], "run": [1, [80, 75, 80, 75, 80, 75, 80, 75]], "walk": [1, [145, 140, 145, 140, 145, 140, 145, 140]],
	"start": [2, [45, 55, 55, 55]], "stop": [3, [70, 100, 80, 100]], "turn": [4, [55, 75, 55, 55]],
	"jump": [5, [80, 70, 110, 160, 110, 120, 90, 120]], "runjump": [6, [80, 100, 130, 100, 110, 80]],
	"attack1": [7, [80, 130, 50, 110, 90]], "attack2": [8, [60, 70, 40, 80, 70]], "attack3": [9, [80, 260, 50, 240, 140]],
	"kneel": [10, [320, 300, 300, 320]], "kneel_attack": [11, [80, 120, 80, 50, 160, 100]], "attack_high": [12, [80, 120, 50, 80, 180]],
	"air_combo": [13, [70, 50, 110, 60, 50, 120, 80, 50, 200]], "dive": [14, [70, 80, 120, 160, 110, 120]],
	"double_jump": [15, [70, 60, 60, 60, 70, 110]], "hurt": [16, [80, 140]], "death": [17, [150, 170, 170, 400]],
	"heal": [21, [200, 200, 240, 220]], "lgather": [23, [110, 420, 420]], "lfinisher": [24, [70, 90, 220, 170, 200]], "lpunch": [22, [1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000]],
	"dash": [29, [35, 45, 55, 55, 60, 80]], "tag_in": [26, [70, 70, 60, 150, 120, 160]], "tag_out": [27, [150, 150, 150, 170]],
}
## 케닌 클로: Sprite Flow Pro motions, trimmed and packed by tools/sprite_flow/ (trim.py, pack_kenin.py) (rows 0-23, sheets kenin_0..3).
## Every shot's firing frame is the table's hit frame (KATK); the roll is the dash (9 frames, wall bounce in player.gd).
const A_KENIN := {
	"idle": [0, [300, 300, 300, 300, 300, 300, 300, 300]], "run": [1, [55, 55, 55, 55, 55, 55, 55, 55]], "walk": [1, [95, 95, 95, 95, 95, 95, 95, 95]],
	"start": [2, [45, 55, 55, 55]], "stop": [3, [80, 100, 110, 130]], "turn": [4, [55, 75, 55, 55]],
	"jump": [5, [80, 70, 110, 160, 110, 120, 90, 120]], "runjump": [6, [80, 100, 130, 100, 110, 80, 90, 100]],
	"attack1": [7, [60, 60, 70, 90, 80, 90]], "attack2": [8, [50, 60, 60, 90, 80, 90]], "attack3": [9, [70, 80, 140, 120, 110, 110, 120]],
	"kneel": [10, [320, 300, 300, 320]], "kneel_attack": [11, [60, 60, 60, 90, 90, 110, 120]], "attack_high": [12, [60, 60, 70, 100, 90, 100]],
	"air_combo": [13, [50, 50, 90, 50, 50, 90, 50, 50, 140]], "dive": [14, [70, 80, 120, 160, 110, 120, 110, 120]],
	"double_jump": [15, [45, 45, 45, 45, 45, 45, 50, 60, 70]], "hurt": [16, [70, 110, 110, 110]], "death": [17, [150, 170, 170, 400]],
	"bomb": [18, [60, 60, 60, 70, 70, 60, 60, 90, 110]],                     # 점착 폭탄: the bomb leaves the hand on frame 6
	"detonate": [19, [1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000]],   # ult 연쇄 기폭 (posed)
	"headshot": [20, [50, 50, 60, 70, 90, 60, 80, 90, 100]],                 # QTE 원호 (drawn by kenin.gd, never played by the player)
	"tag_out": [21, [150, 150, 150, 170, 170]], "teeter": [22, [150, 140, 150, 190, 150, 140]],
	"dash": [23, [40, 45, 45, 45, 45, 45, 45, 70, 90]],                     # the roll: tuck, five spins, uncurl
}
## Kenin's shots: the frame the pistol fires, damage, knockback (kenin.gd fires them; no swing boxes)
const KATK := {
	"attack1": {"fire": [3], "dmg": 1.0, "kb": 3}, "attack2": {"fire": [3], "dmg": 1.0, "kb": 3},
	"attack3": {"fire": [2], "dmg": 2.2, "kb": 9, "heavy": true}, "kneel_attack": {"fire": [3], "dmg": 1.2, "kb": 3},
	"attack_high": {"fire": [3], "dmg": 1.4, "kb": 3, "up": true}, "air_combo": {"fire": [2, 5, 8], "dmg": 0.9, "kb": 2},
	"dive": {"fire": [1], "dmg": 1.4, "kb": 2, "down": true},
}
const TABLE := {"estelle": A_EST, "aida": A_AIDA, "luce": A_LUCE, "kenin": A_KENIN}

## composite moves made of frames from other rows
const VIRT := {
	"charge": [["attack3", 0], ["attack3", 1]], "acharge": [["attack1", 0], ["attack1", 1]],
	"gcharge": [["guard", 1]],                                                          # guard held, attack charging
	"cthrust": [["attack3", 2], ["attack3", 3], ["attack3", 3], ["attack3", 4]],
	"backstep": [["hurt", 0], ["hurt", 0], ["stop", 1]],
	"swap_in": [["run", 1], ["run", 2], ["run", 3], ["run", 5], ["run", 6], ["run", 7]],
	"amark": [["jump", 3], ["jump", 4]], "rturn": [["turn", 0], ["turn", 1], ["turn", 2], ["turn", 3]],
	"tp_in": [["attack1", 2], ["attack1", 3], ["attack1", 4], ["attack1", 4]],          # heavy rift: swings a gate open
	"tp_in_q": [["dash", 0], ["dash", 1], ["dash", 2], ["dash", 2]],                    # quick rift (blink)
	"tp_in_air": [["air_combo", 0], ["air_combo", 1], ["air_combo", 2], ["air_combo", 2]],
	"dig_out": [["run", 2], ["run", 3], ["stop", 0], ["stop", 1]],
	"dig_out_q": [["dash", 3], ["dash", 4], ["dash", 5], ["dash", 5]],
	"dig_out_air": [["dash", 3], ["jump", 4], ["jump", 4], ["jump", 5]],
	"umark": [["mark", 0], ["mark", 1]],
	"lgather": [["kneel", 0], ["kneel", 1]], "heal": [["idle", 0], ["idle", 1]],
	"teeterL": [["teeter", 0], ["teeter", 1], ["teeter", 2], ["teeter", 1]],
	"kcharge": [["detonate", 3], ["detonate", 4], ["detonate", 5], ["detonate", 6]],  # box out, set down, grips the plunger
	"kfire": [["detonate", 6], ["detonate", 7], ["detonate", 8], ["detonate", 8]],    # slams it: chain_detonate on frame 2
}

## attack hit data (relative to the feet, facing right; before character scale)
const ATK := {
	"attack1": {"hit": [2, 3], "box": [10, -120, 120, 110], "dmg": 1, "kb": 4, "arc": [10, -75, 80, -100, 30]},
	"attack2": {"hit": [2, 3], "box": [10, -150, 120, 130], "dmg": 1, "kb": 4, "arc": [4, -62, 100, 205, -12, 0.4]},    # 2nd hit: a flat, wide horizontal sweep (sy 0.4), not the 1st flipped
	"attack3": {"hit": [2, 3], "box": [20, -85, 150, 60], "dmg": 2, "kb": 10, "heavy": true, "stop": 90, "shake": 7, "streak": true},
	"cthrust": {"hit": [0, 1], "box": [10, -95, 230, 80], "dmg": 3, "kb": 16, "heavy": true, "stop": 130, "shake": 11, "streak": true},
	"attack_high": {"hit": [2, 3], "box": [-70, -230, 150, 130], "dmg": 2, "kb": 3, "arc": [-3, -95, 66, 10, -190]},
	"kneel_attack": {"hit": [3, 4], "box": [-30, -30, 140, 70], "dmg": 2, "kb": 3, "arc": [5, -14, 60, 170, 10]},
	"air1": {"hit": [1, 2], "box": [10, -110, 110, 70], "dmg": 1, "kb": 3, "streak": true},
	"air2": {"hit": [4, 5], "box": [-20, -170, 120, 130], "dmg": 1, "kb": 3, "arc": [0, -70, 70, 60, -110]},
	"air3": {"hit": [7, 8], "box": [0, -120, 140, 150], "dmg": 2, "kb": 8, "heavy": true, "stop": 85, "shake": 6, "arc": [-7, -75, 80, -120, 70]},
	"dive": {"hit": [2, 2], "box": [-25, -20, 60, 60], "dmg": 2, "kb": 3},
}


## `ov`: a costume's own animations ({anim: [row, [ms...]]}, skin_data.gd "anims"), looked up first
static func entry(c: String, anim: String, ov: Dictionary = {}) -> Variant:
	if ov.has(anim): return ov[anim]
	var T: Dictionary = TABLE[c]
	if T.has(anim): return T[anim]
	if COMMON.has(anim): return COMMON[anim]
	return null

## Which (row, frame) to draw. `variant` picks the rift flavour for tp_in / dig_out ("", "_q", "_air").
## A row holds 9 frames; an animation with more (a costume's own) runs on into the next rows.
static func resolve(c: String, anim: String, f: int, variant := "", ov: Dictionary = {}) -> Array:
	if anim == "airdash":
		var de: Array = entry(c, "dash", ov)
		return [de[0], [1, 2, 2, 3, 3, 3][mini(5, f)]]
	var e = entry(c, anim, ov)
	if e != null and int(e[0]) >= 0:
		return [int(e[0]) + f / 9, f % 9]
	var key := anim + variant if VIRT.has(anim + variant) else anim
	if VIRT.has(key):
		var vl: Array = VIRT[key]
		var m: Array = vl[mini(f, vl.size() - 1)]
		var e2 = entry(c, m[0], ov)
		if e2 != null and int(e2[0]) >= 0:
			return [int(e2[0]) + int(m[1]) / 9, int(m[1]) % 9]
	return [0, 0]
