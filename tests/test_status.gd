extends SceneTree
## 공용 상태 (status.gd): 취약 multiplies damage, a gauge fills and triggers, the same member refreshes and another
## raises the stage, 경직 holds the foe then leaves it immune, 둔화 slows its feet but not its swing and widens the
## parry (no freeze), 화상 ticks and spreads without extending, 출혈 hits back on every blow (0.1 s apart),
## 띄움 lifts and lands, a boss takes the locks as groggy, the swap reactions, 보호막 · 강화 · 재생:
## godot --headless --path . -s tests/test_status.gd

const ST := preload("res://scripts/status.gd")

var arena
var fails := 0

func ok(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func frames(n: int) -> void:
	for i in n: await process_frame

func gob(x: float, hp := 999.0, kind := "goblin"):
	var m = arena.spawn(kind, x, 0.0)
	m.hp = hp
	m.max_hp = maxf(m.max_hp, hp)
	m.cd = 99999.0
	m.spawn_t = 0.0
	m.M = m.M.duplicate()
	m.M["ms"] = 0.0
	return m

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_test.json"))
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(3)
	var P = arena.player
	arena.enter_dungeon()
	await frames(20)
	for m in arena.mobs: m.hp = 0.0
	await frames(2)
	if arena.get("runes") != null: arena.runes.force_roll = 0.999       # no crits
	P.party = ["estelle", "aida", "luce"]
	for c in P.party: P.hpm[c] = 100.0
	var x0: float = P.position.x

	print("취약")
	var a = gob(x0 + 100.0)
	ok(is_equal_approx(ST.dmg_mul(a), 1.0), "no status: x1")
	ST.add(arena, a, "vuln", 0.25, "kenin")
	ok(ST.has(a, "vuln") and is_equal_approx(ST.dmg_mul(a), 1.20), "취약: a fixed +20% whatever amount is passed")
	ST.add(arena, a, "vuln", 0.20, "luce")
	ok(is_equal_approx(ST.dmg_mul(a), 1.20), "another member's 취약: no stage, still +20%")

	print("gauges and stages")
	var b = gob(x0 + 400.0)
	ST.add(arena, b, "burn", 60.0, "estelle")
	ok(not ST.has(b, "burn") and is_equal_approx(float(ST.of(b)["burn"]["g"]), 60.0), "화상 gauge 60/100: not yet")
	ST.add(arena, b, "burn", 50.0, "estelle")
	ok(ST.has(b, "burn") and int(ST.of(b)["burn"]["stage"]) == 1, "gauge full → 화상 stage 1")
	ST.add(arena, b, "burn", 100.0, "estelle")
	ok(int(ST.of(b)["burn"]["stage"]) == 1, "the same member again: refresh only")
	ST.add(arena, b, "burn", 100.0, "aida")
	ok(int(ST.of(b)["burn"]["stage"]) == 2, "another member: stage 2")
	ST.add(arena, b, "burn", 100.0, "luce")
	ST.add(arena, b, "burn", 100.0, "kenin")
	ok(int(ST.of(b)["burn"]["stage"]) == 3, "capped at 3")

	print("화상 ticks and spreads")
	var hp0: float = b.hp
	ST.step(arena, b, 520.0)
	ok(b.hp < hp0, "a tick burns (%.0f → %.0f)" % [hp0, b.hp])
	var c = gob(b.position.x + 40.0)
	ST.step(arena, b, 1500.0)
	ok(ST.has(c, "burn"), "spreads to the one beside it")
	var tb: float = ST.of(b)["burn"]["t"]
	ok(float(ST.of(c)["burn"]["t"]) <= tb + 1.0, "carries the time left, no more")
	ST.of(c)["burn"]["t"] = 100.0
	ST.of(c)["burn"]["sp"] = 1499.0
	ST.of(b)["burn"]["sp"] = 1499.0
	ST.step(arena, b, 2.0)
	ok(float(ST.of(c)["burn"]["t"]) <= 100.0, "never extends one already burning")

	print("경직")
	var d = gob(x0 + 700.0)
	d.st = "atk"
	ST.add(arena, d, "stagger", 100.0)
	ok(ST.has(d, "stagger") and d.st == "hurt", "full gauge → 경직, the swing cut")
	ok(ST.step(arena, d, 16.0), "locked while it lasts")
	ST.step(arena, d, 1600.0)
	ok(not ST.has(d, "stagger") and float(ST.of(d)["stagger"]["imm"]) > 0.0, "then immune for a while")
	ST.add(arena, d, "stagger", 100.0)
	ok(not ST.has(d, "stagger"), "a fill while immune does nothing")

	print("둔화")
	var e = gob(x0 + 900.0)
	ST.add(arena, e, "slow", 100.0, "luce")
	ok(ST.has(e, "slow") and ST.speed_mul(e) < 1.0 and ST.recovery(e) > 0.0, "둔화: slower feet, a longer rest")
	ok(ST.parry_extra(e) == 1 and ST.parry_extra(a) == 0, "the parry window widens against it only")
	ST.add(arena, e, "slow", 100.0, "luce")
	ok(ST.has(e, "slow") and not ST.exposed(e) and int(ST.of(e)["slow"]["stage"]) == 1, "filled again by the same member: still 둔화 (no freeze), refreshed")

	print("출혈")
	var f = gob(x0 + 1100.0)
	ST.add(arena, f, "bleed", -1.0, "kenin")
	var n0: int = ST.of(f)["bleed"]["n"]
	var h1: float = f.hp
	f.hit(0.1, 0.0)
	ok(int(ST.of(f)["bleed"]["n"]) == n0 - 1 and f.hp < h1, "a hit draws the extra damage")
	f.hit(0.1, 0.0)
	ok(int(ST.of(f)["bleed"]["n"]) == n0 - 1, "a second hit within 0.1 s: none")

	print("띄움")
	var g = gob(x0 + 1300.0)
	var gy: float = g.position.y
	ST.add(arena, g, "air")
	ST.step(arena, g, 100.0)
	ok(g.position.y < gy - 20.0, "up in the air")
	for i in 60: ST.step(arena, g, 16.0)
	ok(is_equal_approx(g.position.y, gy) and not ST.has(g, "air"), "lands where it was")

	print("boss: groggy")
	var bs = gob(x0 + 1500.0, 5000.0, "boss")
	ST.add(arena, bs, "stagger", 100.0)
	ok(not ST.has(bs, "stagger") and float(ST.of(bs)["groggy"]["g"]) > 0.0, "경직 goes to the groggy gauge")
	ST.add(arena, bs, "stagger", 250.0)
	ok(float(ST.of(bs)["groggy"]["t"]) > 0.0 and ST.dmg_mul(bs) > 1.2, "full → groggy, more damage taken")
	ST.add(arena, bs, "burn", 100.0, "estelle")
	ST.of(bs)["burn"]["t"] = 0.0
	ST.add(arena, bs, "burn", 100.0, "estelle")
	ok(not ST.has(bs, "burn"), "a boss needs 50% more the second time")

	print("swap reactions")
	var h = gob(x0 + 1800.0)
	ST.add(arena, h, "burn", 100.0, "estelle")
	var h2: float = h.hp
	ST.tag_react(arena, h, false)
	ok(h.hp < h2 and ST.has(h, "burn"), "a plain swap-in: half the burn now, it keeps burning")
	ST.tag_react(arena, h, true)
	ok(not ST.has(h, "burn"), "a QTE tag-in: all of it, and it ends")
	ok(is_equal_approx(ST.tag_mul(a), 1.5), "취약: the tag-in blow is a sure crit (x1.5)")

	print("ally")
	P.switch_char("estelle")
	P.hp = P.MAX_HP
	ST.ally_add(P, "shield", 9999.0)
	ok(is_equal_approx(float(ST.ally(P)["shield"]), P.MAX_HP * 0.3), "보호막 capped at 30% max HP")
	ok(is_equal_approx(ST.absorb(P, 10.0), 0.0), "보호막 takes the blow")
	var k0: float = P.atk_mul()
	ST.ally_add(P, "buff", 0.2, 5000.0)
	ok(is_equal_approx(P.atk_mul(), k0 * 1.2), "강화 +20% attack")
	P.swap(false, "aida")
	await frames(2)
	ok(float(ST.ally(P)["shield"]) > 0.0 and ST.atk_k(P) > 1.0, "a swap hands 보호막 · 강화 on")
	P.hpm["estelle"] = 50.0
	ST.ally_add(P, "regen", 10.0, 3000.0)
	ST.ally_step(P, 1000.0)
	ok(P.hpm["estelle"] > 50.0, "재생 heals the bench too")

	print("DONE: %d failed" % fails)
	quit(1 if fails > 0 else 0)
