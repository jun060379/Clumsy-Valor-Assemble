extends RefCounted
## Guild hall layout shared by the hall level and Eilin (she walks the floors even when you are elsewhere).
## Ported from hall.js: HFL / FLN / HSNAPW+HMOVED / HDOORS0 / eportal / archX.

const G := 430.0
const RH := 480.0             # room height: the ceiling is at G - RH
const HBAY := 140.0           # one wall bay
const LANDY := 189.0          # stair landing height (G - 241)
const SR := [226.0, 583.0]    # stair ramp, x from the stair's left edge
const HSNAPW := {"door": 120.0, "door1": 84.0, "door2": 84.0, "door3": 100.0, "arch": 96.0, "board": 98.0}
const FLN := ["1층", "2층", "3층", "다락"]
## where you come in on each floor (F7/F8 and the town door)
const SPAWN := [[1800.0, G, -1], [1300.0, G, 1], [1150.0, G, 1], [175.0, G, 1]]

static var _fl: Array = []
static var moved: Array = []


## props: [key, x, base ("G" floor | "L" landing), dy, flags]  flags: w = against the wall (plain bay behind), f = in front of people,
## m = mirrored, r = on the floor strip (drawn after the floor)
static func floors() -> Array:
	if _fl.size() > 0:
		return _fl
	_fl = [
		{"n": "1층", "W": 3540.0, "curtains": [0.0, 1000.0], "rooms": [[40.0, 1000.0], [1000.0, 2320.0, 1022.0], [2320.0, 3500.0]], "walls": [1000.0, 2320.0], "stair": 1007.0, "props": [
			["fire", 110.0, "G", 0.0, "w"], ["sofa", 430.0, "G", 0.0, ""], ["armS", 600.0, "G", 0.0, "m"], ["candela", 682.0, "G", 0.0, ""], ["clock", 770.0, "G", 0.0, "w"], ["sconce", 880.0, "G", -150.0, "w"],
			["rug", 40.0, "G", 16.0, "r"], ["catbed", 150.0, "G", 12.0, "r"],
			["arch", 1027.0, "L", 0.0, "w"], ["sgU", 1562.0, "G", -36.0, "f"], ["coat", 1612.0, "G", 0.0, ""], ["door", 1700.0, "G", 0.0, "w"], ["banner", 1755.0, "G", -264.0, ""], ["sconce", 1600.0, "G", -160.0, ""], ["plant", 1868.0, "G", 0.0, ""], ["counter", 1900.0, "G", 0.0, ""], ["sconce", 2240.0, "G", -160.0, ""], ["ivy", 2196.0, "G", 0.0, ""],
			["board", 2420.0, "G", -104.0, "w"], ["tboard", 2622.0, "G", -300.0, ""], ["chF", 2756.0, "G", 0.0, ""], ["chS", 2632.0, "G", 0.0, ""], ["table", 2690.0, "G", 0.0, ""], ["chS", 2830.0, "G", 0.0, "m"], ["pot", 2716.0, "G", -58.0, ""], ["bread", 2790.0, "G", -58.0, ""], ["candle", 2760.0, "G", -58.0, ""],
			["barrel", 3000.0, "G", 0.0, ""], ["barrel", 3046.0, "G", 0.0, ""], ["pots", 2984.0, "G", -128.0, "w"], ["hearth", 3170.0, "G", 0.0, "w"], ["kettle", 3292.0, "G", -130.0, ""], ["stool", 3290.0, "G", 0.0, ""], ["herbs", 3372.0, "G", -168.0, ""], ["herbs", 3452.0, "G", -176.0, ""], ["candela", 3400.0, "G", 0.0, ""]]},
		{"n": "2층", "W": 3540.0, "curtains": [0.0, 1000.0], "rooms": [[40.0, 1000.0], [1000.0, 2320.0, 1052.0], [2320.0, 3500.0]], "walls": [1000.0, 2320.0], "stair": 1600.0, "well": [1150.0, 1450.0], "props": [
			["shelf", 70.0, "G", 0.0, "w"], ["shelf", 190.0, "G", 0.0, "w"], ["shelf", 310.0, "G", 0.0, "w"], ["libladder", 436.0, "G", 0.0, ""], ["desk", 560.0, "G", 0.0, ""], ["clutter", 566.0, "G", -52.0, ""], ["candle", 574.0, "G", -56.0, ""], ["chB", 590.0, "G", 0.0, ""], ["ivy", 2330.0, "G", 0.0, ""], ["candela", 740.0, "G", 0.0, ""], ["sconce", 880.0, "G", -160.0, "w"],
			["sconce", 1060.0, "G", -160.0, ""], ["arch", 1620.0, "L", 0.0, "w"], ["sgD", 1280.0, "G", -176.0, ""], ["sgU", 2155.0, "G", -36.0, "f"],
			["door1", 2400.0, "G", 0.0, "w"], ["door1", 2680.0, "G", 0.0, "w"], ["door2", 2960.0, "G", 0.0, "w"], ["door1", 3240.0, "G", 0.0, "w"], ["sconce", 2560.0, "G", -160.0, ""], ["sconce", 2840.0, "G", -160.0, ""], ["sconce", 3120.0, "G", -160.0, ""]]},
		{"n": "3층", "W": 1400.0, "rooms": [[40.0, 1360.0]], "walls": [930.0], "well": [1000.0, 1300.0], "props": [
			["ladder", 90.0, "G", 0.0, "w"], ["door1", 200.0, "G", 0.0, "w"], ["door2", 340.0, "G", 0.0, "w"], ["door2", 480.0, "G", 0.0, "w"], ["door2", 620.0, "G", 0.0, "w"], ["door1", 760.0, "G", 0.0, "w"], ["sconce", 300.0, "G", -160.0, ""], ["sconce", 580.0, "G", -160.0, ""], ["sconce", 880.0, "G", -160.0, ""], ["plant", 848.0, "G", 0.0, ""], ["sgD", 1130.0, "G", -176.0, ""]]},
		{"n": "다락", "W": 1000.0, "rooms": [[40.0, 960.0]], "gable": true, "well": [110.0, 240.0], "props": [
			["door3", 438.0, "G", 0.0, "w"], ["sgD", 256.0, "G", -110.0, ""], ["candle", 560.0, "G", 0.0, ""], ["ladder", 148.0, "G", 150.0, ""]]}]
	# doors, arches and notice boards sit between the timber posts: each is centred on the nearest bay
	moved = []
	for fl in _fl.size():
		var F: Dictionary = _fl[fl]
		if F.get("gable", false): continue
		for p in F["props"]:
			if not HSNAPW.has(p[0]): continue
			var w: float = HSNAPW[p[0]]
			var c: float = p[1] + w / 2.0
			var R = null
			for r in F["rooms"]:
				if c >= r[0] and c < r[1]:
					R = r
					break
			if R == null: continue
			var g: float = R[0] if R.size() < 3 else R[2]
			var m := g + HBAY / 2.0 + 8.0
			var k := floorf((c - m) / HBAY + 0.5)
			var nc := m + k * HBAY
			if nc < R[0] + w / 2.0: nc += HBAY
			if nc > R[1] - w / 2.0: nc -= HBAY
			var d := floorf(nc - c + 0.5)
			if d != 0.0:
				p[1] += d
				moved.append({"fl": fl, "c": c, "d": d})
	return _fl


static func prop_y(p: Array) -> float:
	return (LANDY if p[2] == "L" else G) + p[3]


static func arch_x(fl: int) -> float:
	for p in floors()[fl]["props"]:
		if p[0] == "arch": return p[1] + 48.0
	return 0.0


## interaction points: act = what the attack key does there
static func doors() -> Array:
	floors()
	var L := [
		{"fl": 0, "x": 1760.0, "r": 56.0, "y": G, "name": "길드 마을로", "k": "나가기", "act": "town"},
		{"fl": 0, "x": 2020.0, "r": 110.0, "y": G, "name": "접수대", "k": "대화", "act": "counter"},
		{"fl": 0, "x": 2492.0, "r": 80.0, "y": G, "name": "의뢰 게시판", "k": "보기", "act": "board"},
		{"fl": 0, "x": 500.0, "r": 140.0, "y": G, "name": "리빙 룸 · 파티 편성", "k": "편성", "act": "party"},
		{"fl": 0, "x": 1082.0, "r": 60.0, "y": LANDY, "name": "↑ 2층으로", "k": "계단", "act": "go", "to": [1, 1300.0, G]},
		{"fl": 1, "x": 1300.0, "r": 120.0, "y": G, "name": "↓ 1층으로", "k": "계단", "act": "go", "to": [0, 1110.0, LANDY]},
		{"fl": 1, "x": 590.0, "r": 160.0, "y": G, "name": "도서관 · 기록", "k": "기록", "act": "library"},
		{"fl": 1, "x": 1675.0, "r": 60.0, "y": LANDY, "name": "↑ 3층으로", "k": "계단", "act": "go", "to": [2, 1150.0, G]},
		{"fl": 1, "x": 3002.0, "r": 44.0, "y": G, "name": "옷장", "k": "옷장", "act": "wardrobe"},
		{"fl": 2, "x": 1150.0, "r": 120.0, "y": G, "name": "↓ 2층으로", "k": "계단", "act": "go", "to": [1, 1700.0, LANDY]},
		{"fl": 2, "x": 382.0, "r": 40.0, "y": G, "name": "317 · 루체의 방", "k": "방", "act": "room", "c": "luce"},
		{"fl": 2, "x": 522.0, "r": 40.0, "y": G, "name": "322 · 에스텔의 방", "k": "방", "act": "room", "c": "estelle"},
		{"fl": 2, "x": 662.0, "r": 40.0, "y": G, "name": "328 · 아이다의 방", "k": "방", "act": "room", "c": "aida"},
		{"fl": 2, "x": 118.0, "r": 50.0, "y": G, "name": "↑ 다락으로", "k": "사다리", "act": "go", "to": [3, 175.0, G]},
		{"fl": 3, "x": 175.0, "r": 70.0, "y": G, "name": "↓ 3층으로", "k": "사다리", "act": "go", "to": [2, 140.0, G]},
		{"fl": 3, "x": 500.0, "r": 60.0, "y": G, "name": "MASTER ROOM", "k": "문", "act": "locked"}]
	for d in L:
		for m in moved:
			if m["fl"] == d["fl"] and absf(d["x"] - m["c"]) < 90.0:
				d["x"] += m["d"]
				break
	return L
