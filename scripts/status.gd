extends RefCounted
## 공용 상태 (기획서 「전투 시스템: 파티 유형과 상태」, owner 2026-11-04). Numbers are PLACEHOLDER.
## A unique resource (Kenin's marks, Aida's sigils) stays with its member; these are the shared ones that tie members
## together. Nobody but Kenin applies any yet: the members are reworked onto them next.
##
## Foe side (meta "st" on the foe: mob, dummy, ghost):
##   vuln 취약 (instant)   — takes more damage; refresh only, never stages (it multiplies)
##   stagger 경직 (gauge)  — 1.5 s defenceless, then ~2 s immune
##   air 띄움 (instant)    — up in the air, hits keep it up to a limit (fliers: a short stagger instead)
##   slow 둔화 (gauge)     — moves slower and rests longer after an attack; the attack's timing never changes, the
##                           parry window widens; filled again while slowed → 빙결 (1 s frozen, no knockback)
##   burn 화상 (gauge)     — damage over time + spreads to a foe nearby (never extends one already burning)
##   bleed 출혈 (instant)  — extra damage on every hit taken (at most every 0.1 s), 8 s or 15 hits
## Stages: the same member again only refreshes; another member's same status raises its stage (max 3 = the party).
## Bosses and elites: 경직 · 띄움 · 빙결 go into a groggy gauge (full → 3 s down, more damage taken); every trigger
## of a gauge status raises its next need by 50%.
## Different statuses all coexist; none cancels another.
##
## Ally side (P.ally on the player, who stays the same object across swaps — so a swap hands them on):
##   shield 보호막 — absorbs, adds up to 30% of max HP · buff 강화 — attack up · regen 재생 — heals, the bench too
## Swap reaction (tag_react): a QTE tag-in hits it strong, a plain swap-in weak (half).

const CH := preload("res://scripts/chars.gd")

const K := {
	"vuln": {"name": "취약", "col": Color("#ff5a3a"), "t": 8000.0, "mul": 0.20},
	"stagger": {"name": "경직", "col": Color("#ffe14d"), "t": 1500.0, "imm": 2000.0},
	"air": {"name": "띄움", "col": Color("#bfe9ff"), "vy": -0.75, "g": 0.0032, "hits": 6, "bump": -0.28},
	"slow": {"name": "둔화", "col": Color("#8fdcff"), "t": 5000.0, "ms": [0.7, 0.6, 0.5], "rec": 380.0, "freeze": 1000.0, "imm": 2000.0},
	"burn": {"name": "화상", "col": Color("#ff7a45"), "t": 6000.0, "tick": 500.0, "dps": 0.15, "spread": 1500.0, "radius": 170.0},
	"bleed": {"name": "출혈", "col": Color("#e0304a"), "t": 8000.0, "n": 15, "per": 0.12, "gap": 100.0},
}
const ORDER := ["vuln", "stagger", "air", "slow", "burn", "bleed"]
const STAGE_K := [1.0, 1.5, 2.0]          # stage 1 · 2 · 3
const GAUGE := 100.0
const TOL := 0.5                          # boss / elite: each trigger raises the next need by 50%
const GROGGY := {"need": 300.0, "t": 3000.0, "mul": 0.30, "air": 60.0, "freeze": 80.0}
const SHIELD_CAP := 0.30
const SHOW := 3                           # icons over a foe; more → "+n"

static var _in := false                   # a status's own damage never sets off another hit reaction

# ---------- foe side ----------
static func of(e) -> Dictionary:
	if not e.has_meta("st"): e.set_meta("st", {})
	return e.get_meta("st")

static func has(e, k: String) -> bool:
	if not e.has_meta("st"): return false
	var d = e.get_meta("st").get(k)
	if d == null: return false
	if k == "slow": return float(d.get("t", 0.0)) > 0.0 or float(d.get("fz", 0.0)) > 0.0
	return float(d.get("t", 0.0)) > 0.0

static func big(e) -> bool:
	var M = e.get("M")
	return (M is Dictionary and M.has("boss")) or bool(e.get("elite") == true and e.get("kind") != "ghost")

static func flier(e) -> bool:
	var M = e.get("M")
	return M is Dictionary and M.has("fly")

## 공격력 of member c (the status screen's number: 10 × atk × gear)
static func atk_of(arena, c: String) -> float:
	var R = arena.get("runes")
	return 10.0 * float(CH.STATS.get(c, {"atk": 1.0})["atk"]) * (R.atk_k(c) if R != null else 1.0)

static func _src(arena, src: String) -> String:
	return src if src != "" else String(arena.player.who)

## apply: gauge statuses take gauge points (100 fills a plain foe), vuln takes its strength (0.25 = +25%),
## the instant ones ignore amt
static func add(arena, e, k: String, amt := -1.0, src := "") -> void:
	if e == null or not is_instance_valid(e) or not e.alive(): return
	src = _src(arena, src)
	var S := of(e)
	var d: Dictionary = S.get(k, {})
	S[k] = d
	match k:
		"vuln":
			d["t"] = K.vuln.t
			d["k"] = maxf(float(d.get("k", 0.0)) if float(d.get("t", 0.0)) > 0.0 else 0.0, amt if amt >= 0.0 else K.vuln.mul)
		"stagger", "slow", "burn":
			if k == "stagger" and big(e):
				groggy(arena, e, amt if amt >= 0.0 else GAUGE)
				return
			var need := GAUGE * (1.0 + TOL * float(d.get("n", 0))) if big(e) else GAUGE
			d["g"] = float(d.get("g", 0.0)) + (amt if amt >= 0.0 else GAUGE)
			if d["g"] >= need:
				d["g"] = 0.0
				if big(e): d["n"] = int(d.get("n", 0)) + 1
				_trigger(arena, e, k, d, src)
		"air":
			if big(e):
				groggy(arena, e, GROGGY.air)
				return
			if flier(e):
				add(arena, e, "stagger", GAUGE, src)
				return
			if float(d.get("t", 0.0)) <= 0.0:
				d["y0"] = e.position.y
				d["hits"] = 0
			d["t"] = 1.0
			d["vy"] = K.air.vy
		"bleed":
			_stage(d, src)
			d["t"] = K.bleed.t
			d["n"] = K.bleed.n
			d["a"] = maxf(float(d.get("a", 0.0)), atk_of(arena, src))
			d["last"] = -99999
	_cue(arena, e, k)

## a gauge filled
static func _trigger(arena, e, k: String, d: Dictionary, src: String) -> void:
	match k:
		"stagger":
			if float(d.get("imm", 0.0)) > 0.0 or float(d.get("t", 0.0)) > 0.0: return
			d["t"] = K.stagger.t
			_lock(e)
		"slow":
			if float(d.get("t", 0.0)) > 0.0 and src_in(d, src):
				# filled again while slowed: 빙결 (the bosses take it as groggy)
				if big(e): groggy(arena, e, GROGGY.freeze)
				elif float(d.get("imm", 0.0)) <= 0.0 and float(d.get("fz", 0.0)) <= 0.0:
					d["fz"] = K.slow.freeze
					_lock(e)
					arena.text(e.position + Vector2(0, -150), "빙결", K.slow.col)
				d["t"] = K.slow.t
				return
			_stage(d, src)
			d["t"] = K.slow.t
		"burn":
			_stage(d, src)
			d["t"] = K.burn.t
			d["a"] = maxf(float(d.get("a", 0.0)) if float(d.get("t", 0.0)) > 0.0 else 0.0, atk_of(arena, src))
			d["acc"] = 0.0
			d["sp"] = 0.0
	_cue(arena, e, k)

static func src_in(d: Dictionary, src: String) -> bool:
	return Array(d.get("src", [])).has(src)

## the same member refreshes, another raises the stage (max 3); a status that ran out starts over at 1
static func _stage(d: Dictionary, src: String) -> void:
	if float(d.get("t", 0.0)) <= 0.0:
		d["src"] = [src]
		d["stage"] = 1
	elif not src_in(d, src):
		d["src"].append(src)
		d["stage"] = mini(3, int(d.get("stage", 1)) + 1)

static func stage_k(d: Dictionary) -> float:
	return STAGE_K[clampi(int(d.get("stage", 1)) - 1, 0, 2)]

## a lock stops a swing mid-way (the foe was hit out of it)
static func _lock(e) -> void:
	if e.get("st") == "atk":
		e.st = "hurt"
		if e.get("flared") != null: e.flared = false
		if e.has_method("set_a"): e.set_a("hurt")

static func groggy(arena, e, amt: float) -> void:
	var S := of(e)
	var d: Dictionary = S.get("groggy", {"g": 0.0, "t": 0.0})
	S["groggy"] = d
	if float(d["t"]) > 0.0: return
	d["g"] = float(d["g"]) + amt
	if d["g"] >= GROGGY.need:
		d["g"] = 0.0
		d["t"] = GROGGY.t
		_lock(e)
		arena.text(e.position + Vector2(0, -210), "그로기!", Color("#ffd34d"))
		arena.shake(10, 1)
		arena.sfx("heavy", 0.9)

static func _cue(arena, e, k: String) -> void:
	if k == "air": return
	var d: Dictionary = of(e).get(k, {})
	if k in ["stagger", "slow", "burn"] and float(d.get("t", 0.0)) <= 0.0: return      # only gauge filling, no cue
	var st := int(d.get("stage", 1))
	arena.text(e.position + Vector2(0, -170), K[k].name + ("" if st <= 1 else " %d단계" % st), K[k].col)

## tick; true while the foe is locked (경직 · 빙결 · 띄움 · 그로기): no AI that frame
static func step(arena, e, dt: float) -> bool:
	if not e.has_meta("st"): return false
	var S: Dictionary = e.get_meta("st")
	var lock := false
	for k in S:
		var d: Dictionary = S[k]
		if d.has("imm") and float(d["imm"]) > 0.0: d["imm"] = float(d["imm"]) - dt
		match k:
			"vuln":
				d["t"] = float(d.get("t", 0.0)) - dt
			"stagger":
				if float(d.get("t", 0.0)) > 0.0:
					d["t"] = float(d["t"]) - dt
					lock = true
					if d["t"] <= 0.0: d["imm"] = K.stagger.imm * float(d.get("immk", 1.0))
			"slow":
				if float(d.get("fz", 0.0)) > 0.0:
					d["fz"] = float(d["fz"]) - dt
					lock = true
					if d["fz"] <= 0.0: d["imm"] = K.slow.imm
				if float(d.get("t", 0.0)) > 0.0: d["t"] = float(d["t"]) - dt
			"air":
				if float(d.get("t", 0.0)) > 0.0:
					lock = true
					d["vy"] = float(d["vy"]) + K.air.g * dt
					e.position.y += float(d["vy"]) * dt
					if e.position.y >= float(d["y0"]) and float(d["vy"]) > 0.0:
						e.position.y = float(d["y0"])
						d["t"] = 0.0
						arena.dust(e.position, 0, false)
			"burn":
				if float(d.get("t", 0.0)) > 0.0:
					d["t"] = float(d["t"]) - dt
					d["acc"] = float(d.get("acc", 0.0)) + dt
					d["sp"] = float(d.get("sp", 0.0)) + dt
					if d["acc"] >= K.burn.tick:
						d["acc"] = float(d["acc"]) - K.burn.tick
						deal(arena, e, float(d["a"]) * K.burn.dps * stage_k(d) * K.burn.tick / 1000.0, K.burn.col)
					if d["sp"] >= K.burn.spread:
						d["sp"] = 0.0
						_spread(arena, e, d)
			"bleed":
				if float(d.get("t", 0.0)) > 0.0: d["t"] = float(d["t"]) - dt
			"groggy":
				if float(d.get("t", 0.0)) > 0.0:
					d["t"] = float(d["t"]) - dt
					lock = true
	return lock

## 화상 spreads to the nearest foe not burning; it carries the time left, never more
static func _spread(arena, e, d: Dictionary) -> void:
	var best = null
	var bd: float = K.burn.radius
	for o in arena.foes():
		if o == e or has(o, "burn"): continue
		var dd: float = o.position.distance_to(e.position)
		if dd < bd:
			bd = dd
			best = o
	if best == null: return
	var S := of(best)
	S["burn"] = {"t": float(d["t"]), "stage": int(d.get("stage", 1)), "src": Array(d.get("src", [])).duplicate(), "a": float(d["a"]), "acc": 0.0, "sp": 0.0}
	arena.text(best.position + Vector2(0, -170), "화상 번짐", K.burn.col)

## a status's own damage (no knockback, no element, no hit reaction); a foe it finishes dies the usual way
static func deal(arena, e, v: float, col: Color) -> void:
	if v <= 0.0 or not e.alive(): return
	var n := maxi(1, roundi(v))
	arena.text(e.position + Vector2(randf_range(-14, 14), -100), "-%d" % n, col)
	_in = true
	if e.hp - n <= 0.0:
		e.hp = 0.5
		e.hit(0.0001, 0.0)
	else:
		e.hp -= n
	_in = false

## 무방비: held by 경직 · 빙결 · 띄움 · 그로기
static func exposed(e) -> bool:
	if e == null or not e.has_meta("st"): return false
	var S: Dictionary = e.get_meta("st")
	if has(e, "stagger") or has(e, "air"): return true
	if S.has("slow") and float(S["slow"].get("fz", 0.0)) > 0.0: return true
	return S.has("groggy") and float(S["groggy"].get("t", 0.0)) > 0.0

static func groggy_on(e) -> bool:
	if e == null or not e.has_meta("st"): return false
	var g = e.get_meta("st").get("groggy")
	return g != null and float(g.get("t", 0.0)) > 0.0

## the foe's damage taken multiplier: 취약 + 그로기
static func dmg_mul(e) -> float:
	if not e.has_meta("st"): return 1.0
	var S: Dictionary = e.get_meta("st")
	var m := 1.0
	if has(e, "vuln"): m += float(S["vuln"].get("k", K.vuln.mul))
	if S.has("groggy") and float(S["groggy"].get("t", 0.0)) > 0.0: m += GROGGY.mul
	return m

## after a hit landed: 출혈's extra damage, 띄움 kept up
static func on_hit(arena, e) -> void:
	if _in or not e.has_meta("st") or not e.alive(): return
	var S: Dictionary = e.get_meta("st")
	if has(e, "bleed"):
		var d: Dictionary = S["bleed"]
		var now := Time.get_ticks_msec()
		if int(d["n"]) > 0 and now - int(d["last"]) >= int(K.bleed.gap):
			d["n"] = int(d["n"]) - 1
			d["last"] = now
			if d["n"] <= 0: d["t"] = 0.0
			deal(arena, e, float(d["a"]) * K.bleed.per * stage_k(d), K.bleed.col)
	if has(e, "air"):
		var a: Dictionary = S["air"]
		a["hits"] = int(a.get("hits", 0)) + 1
		if int(a["hits"]) <= int(K.air.hits): a["vy"] = minf(float(a["vy"]), K.air.bump)

## knockback is off while frozen
static func no_kb(e) -> bool:
	if not e.has_meta("st"): return false
	var d = e.get_meta("st").get("slow")
	return d != null and float(d.get("fz", 0.0)) > 0.0

## 둔화: movement speed and the rest after a swing (the swing's own timing never changes)
static func speed_mul(e) -> float:
	if not has(e, "slow"): return 1.0
	var d: Dictionary = e.get_meta("st")["slow"]
	return K.slow.ms[clampi(int(d.get("stage", 1)) - 1, 0, 2)]

static func recovery(e) -> float:
	if not has(e, "slow"): return 0.0
	return K.slow.rec * stage_k(e.get_meta("st")["slow"])

## 둔화: the parry window is a frame longer against a slowed foe
static func parry_extra(e) -> int:
	return 1 if has(e, "slow") else 0

## the swap-in blow on a foe: x1.5 on 취약 (확정 치명), before the hit
static func tag_mul(e) -> float:
	return 1.5 if has(e, "vuln") else 1.0

## … and what the blow sets off after it landed: strong = a QTE tag-in, weak = a plain swap-in (half)
static func tag_react(arena, e, strong: bool) -> void:
	if e == null or not is_instance_valid(e) or not e.alive() or not e.has_meta("st"): return
	var S: Dictionary = e.get_meta("st")
	var w := 1.0 if strong else 0.5
	var any := false
	if has(e, "stagger"):
		S["stagger"]["t"] = float(S["stagger"]["t"]) + 800.0 * w
		any = true
	if S.has("slow") and float(S["slow"].get("fz", 0.0)) > 0.0:
		var d: Dictionary = S["slow"]
		deal(arena, e, atk_of(arena, String(arena.player.who)) * 0.8 * stage_k(d) * w, K.slow.col)
		d["fz"] = 0.0
		d["imm"] = K.slow.imm
		if strong: d["t"] = 0.0
		arena.text(e.position + Vector2(0, -190), "얼음 깨기!", K.slow.col)
		any = true
	if has(e, "burn"):
		var b: Dictionary = S["burn"]
		var left: float = float(b["a"]) * K.burn.dps * stage_k(b) * float(b["t"]) / 1000.0
		deal(arena, e, left * w, K.burn.col)
		if strong: b["t"] = 0.0
		any = true
	if has(e, "bleed"):
		S["bleed"]["t"] = K.bleed.t
		any = true
	if any: arena.sfx("heavy", 0.6)

## icons for the head: [[key, colour, label, gauge ratio 0..1 or -1]]
static func icons(e) -> Array:
	var out: Array = []
	if not e.has_meta("st"): return out
	var S: Dictionary = e.get_meta("st")
	for k in ORDER:
		if not S.has(k): continue
		var d: Dictionary = S[k]
		var lab := ""
		if k == "bleed": lab = str(int(d.get("n", 0)))
		elif int(d.get("stage", 1)) > 1: lab = str(int(d["stage"]))
		if has(e, k): out.append([k, K[k].col, lab, -1.0])
		elif float(d.get("g", 0.0)) > 0.0: out.append([k, Color(K[k].col, 0.45), "", float(d["g"]) / GAUGE])
	if S.has("groggy"):
		var gd: Dictionary = S["groggy"]
		if float(gd.get("t", 0.0)) > 0.0: out.push_front(["groggy", Color("#ffd34d"), "", -1.0])
		elif float(gd.get("g", 0.0)) > 0.0: out.append(["groggy", Color("#ffd34d", 0.45), "", float(gd["g"]) / GROGGY.need])
	return out

## the head row (on the foe's own canvas): up to 3 dots (the status's first letter, a stage / count beside it),
## the fullest gauge as a ring, "+n" for the rest. PLACEHOLDER art: plain shapes until the status icons exist.
static func draw(ci: CanvasItem, e, y: float) -> void:
	var L := icons(e)
	if L.is_empty(): return
	var f: Font = ThemeDB.fallback_font
	var n := mini(SHOW, L.size())
	var x0 := -float(n - 1) * 9.0
	var ring := -1
	var rv := 0.0
	for i in L.size():
		if float(L[i][3]) > rv:
			rv = float(L[i][3])
			ring = i
	for i in n:
		var it: Array = L[i]
		var p := Vector2(x0 + i * 18.0, y)
		var c: Color = it[1]
		ci.draw_circle(p, 8.0, Color(0.06, 0.04, 0.08, 0.85))
		ci.draw_circle(p, 6.5, c)
		var nm: String = String(K[it[0]].name if K.has(it[0]) else "그로기").substr(0, 1)
		ci.draw_string(f, p + Vector2(-5.5, 4.5), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.05, 0.03, 0.06))
		if String(it[2]) != "":
			ci.draw_string_outline(f, p + Vector2(4, 9), String(it[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0.05, 0.03, 0.06))
			ci.draw_string(f, p + Vector2(4, 9), String(it[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		if i == ring:
			ci.draw_arc(p, 9.5, -PI / 2.0, -PI / 2.0 + TAU * clampf(rv, 0.0, 1.0), 24, Color(c, 1.0), 2.0, true)
	if L.size() > SHOW:
		ci.draw_string_outline(f, Vector2(x0 + n * 18.0 - 4.0, y + 4.0), "+%d" % (L.size() - SHOW), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.05, 0.03, 0.06))
		ci.draw_string(f, Vector2(x0 + n * 18.0 - 4.0, y + 4.0), "+%d" % (L.size() - SHOW), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

# ---------- ally side ----------
static func ally(P) -> Dictionary:
	if not P.has_meta("ally"): P.set_meta("ally", {"shield": 0.0, "buff": {"t": 0.0, "k": 0.0}, "regen": {"t": 0.0, "r": 0.0}})
	return P.get_meta("ally")

## 보호막 adds up (to 30% of max HP), 강화 · 재생 refresh and keep the stronger
static func ally_add(P, k: String, amt: float, t := 0.0) -> void:
	var A := ally(P)
	match k:
		"shield":
			A["shield"] = minf(float(A["shield"]) + amt, float(P.MAX_HP) * SHIELD_CAP)
		"buff":
			var b: Dictionary = A["buff"]
			b["k"] = maxf(float(b["k"]) if float(b["t"]) > 0.0 else 0.0, amt)
			b["t"] = maxf(float(b["t"]), t)
		"regen":
			var r: Dictionary = A["regen"]
			r["r"] = maxf(float(r["r"]) if float(r["t"]) > 0.0 else 0.0, amt)
			r["t"] = maxf(float(r["t"]), t)

## 재생 heals the one in control and the bench alike (HP per second)
static func ally_step(P, dt: float) -> void:
	if not P.has_meta("ally"): return
	var A: Dictionary = P.get_meta("ally")
	var b: Dictionary = A["buff"]
	if float(b["t"]) > 0.0: b["t"] = float(b["t"]) - dt
	var r: Dictionary = A["regen"]
	if float(r["t"]) > 0.0:
		r["t"] = float(r["t"]) - dt
		var h: float = float(r["r"]) * dt / 1000.0
		if P.hp > 0.0: P.hp = minf(P.MAX_HP, P.hp + h)
		for c in P.party:
			if c != P.who and P.hpm.has(c) and P.hpm[c] > 0.0: P.hpm[c] = minf(P._mhp(c), P.hpm[c] + h)

static func atk_k(P) -> float:
	if not P.has_meta("ally"): return 1.0
	var b: Dictionary = P.get_meta("ally")["buff"]
	return 1.0 + (float(b["k"]) if float(b["t"]) > 0.0 else 0.0)

## 보호막 takes the blow first; returns what is left for HP
static func absorb(P, v: float) -> float:
	if not P.has_meta("ally"): return v
	var A: Dictionary = P.get_meta("ally")
	var s := float(A["shield"])
	if s <= 0.0: return v
	var take := minf(s, v)
	A["shield"] = s - take
	return v - take
