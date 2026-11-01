extends RefCounted
## Estelle's animation table, carried over 1:1 from the web prototype (A_EST + VIRT).
## row = sheet row (sheet = row / 7, row in sheet = row % 7); each cell is 448x352 in the source sheets.
## A row of -1 means a composite move drawn from frames of other rows (see VIRT).

const CELL_W := 448
const CELL_H := 352
const ROWS_PER_SHEET := 7

const A := {
	"idle": [0, [180, 180, 180, 180]],
	"run": [2, [90, 80, 80, 90, 90, 80, 80, 90]],
	"walk": [2, [150, 150, 150, 150, 150, 150, 150, 150]],
	"start": [3, [35, 45, 45, 40]],
	"stop": [4, [110, 180, 150, 190]],
	"turn": [5, [55, 75, 55, 55]],
	"jump": [6, [80, 70, 110, 160, 110, 120, 90, 120]],
	"runjump": [7, [80, 100, 130, 100, 110, 80]],
	"attack1": [8, [80, 130, 50, 110, 90]],
	"attack2": [9, [60, 70, 40, 80, 70]],
	"attack3": [10, [80, 260, 50, 240, 140]],
	"kneel": [11, [320, 300, 300, 320]],
	"kneel_attack": [12, [80, 120, 80, 50, 160, 100]],
	"attack_high": [13, [80, 120, 50, 80, 180]],
	"guard": [14, [120, 200, 160, 200]],
	"parry": [15, [180, 35, 200, 150]],
	"air_combo": [16, [70, 50, 110, 60, 50, 120, 80, 50, 200]],
	"dive": [17, [70, 80, 120, 160, 110, 120]],
	"double_jump": [18, [70, 60, 60, 60, 70, 110]],
	"hurt": [19, [80, 140]],
	"death": [20, [150, 170, 170, 400]],
	"dash": [21, [35, 45, 55, 55, 60, 80]],
	"air_guard": [23, [120, 200, 160, 200]],
	"air_parry": [24, [180, 35, 200, 150]],
	"teeter": [28, [150, 140, 150, 190]],
	# composites
	"charge": [-1, [110, 1000000000]],
	"cthrust": [-1, [45, 60, 220, 170]],
	"airdash": [-1, [40, 55, 60, 60, 60, 90]],
	"backstep": [-1, [60, 110, 120]],
}

const VIRT := {
	"charge": [["attack3", 0], ["attack3", 1]],
	"cthrust": [["attack3", 2], ["attack3", 3], ["attack3", 3], ["attack3", 4]],
	"backstep": [["hurt", 0], ["hurt", 0], ["stop", 1]],
}

## Attack hit data (relative to the feet, facing right; before character scale): active frames, box [x,y,w,h], damage, knockback.
const ATK := {
	"attack1": {"hit": [2, 3], "box": [10, -120, 120, 110], "dmg": 1, "kb": 4, "arc": [10, -75, 80, -100, 30]},
	"attack2": {"hit": [2, 3], "box": [10, -150, 120, 130], "dmg": 1, "kb": 4, "arc": [4, -62, 100, 205, -12]},
	"attack3": {"hit": [2, 3], "box": [20, -85, 150, 60], "dmg": 2, "kb": 10, "heavy": true, "stop": 90, "shake": 7, "streak": true},
	"cthrust": {"hit": [0, 1], "box": [10, -95, 230, 80], "dmg": 3, "kb": 16, "heavy": true, "stop": 130, "shake": 11, "streak": true},
	"attack_high": {"hit": [2, 3], "box": [-70, -230, 150, 130], "dmg": 2, "kb": 3, "arc": [-3, -95, 66, 10, -190]},
	"kneel_attack": {"hit": [3, 4], "box": [-30, -30, 140, 70], "dmg": 2, "kb": 3, "arc": [5, -14, 60, 170, 10]},
	"air1": {"hit": [1, 2], "box": [10, -110, 110, 70], "dmg": 1, "kb": 3, "streak": true},
	"air2": {"hit": [4, 5], "box": [-20, -170, 120, 130], "dmg": 1, "kb": 3, "arc": [0, -70, 70, 60, -110]},
	"air3": {"hit": [7, 8], "box": [0, -120, 140, 150], "dmg": 2, "kb": 8, "heavy": true, "stop": 85, "shake": 6, "arc": [-7, -75, 80, -120, 70]},
	"dive": {"hit": [2, 2], "box": [-25, -20, 60, 60], "dmg": 2, "kb": 3},
}

## Which (row, frame) to actually draw for an animation frame.
static func resolve(anim: String, f: int) -> Array:
	if anim == "airdash":
		return [21, [1, 2, 2, 3, 3, 3][mini(5, f)]]
	if VIRT.has(anim):
		var m: Array = VIRT[anim][mini(f, VIRT[anim].size() - 1)]
		return [A[m[0]][0], m[1]]
	if not A.has(anim) or A[anim][0] < 0:
		return [0, 0]
	return [A[anim][0], f]
