extends SceneTree
## recovery cancel (owner 2026-11-05): a ground attack's windup stays committed (skill / jump presses are not taken),
## and once its strike is out the rest of the swing cuts into the skill (guard key) or a jump
## godot --headless --path . -s tests/test_cancel.gd

var arena
var fails := 0

func ok(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func frames(n: int) -> void:
	for i in n: await process_frame

func until(cond: Callable, ms := 3000.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await process_frame
		if Time.get_ticks_msec() - t0 > ms: return false
	return true

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_test.json"))
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(3)
	var P = arena.player
	arena.enter_dungeon()
	await frames(20)
	for m in arena.mobs: m.hp = 0.0
	P.party = ["estelle", "aida", "luce", "kenin"]
	for c in P.party: P.hpm[c] = 100.0
	await frames(3)

	for who in ["estelle", "aida", "luce", "kenin"]:
		print(who)
		P.switch_char(who)
		await until(func(): return P.on and P.anim == "idle")
		P.tp_cd = 0.0
		P.heal_cd = 0.0
		P.start_attack()
		await frames(1)
		ok(P.anim == "attack1" and not P.rec_cancel_ok(), "windup: no cancel yet")
		P.buf["jump"] = P.BUF
		await frames(1)
		ok(P.anim == "attack1" and P.on, "jump pressed in the windup: the swing goes on")
		P.take("jump")
		ok(await until(func(): return P.anim == "attack1" and P.rec_cancel_ok(), 1500.0), "the strike goes out: recovery open")
		P.buf["jump"] = P.BUF
		await frames(2)
		ok(not P.on and P.anim in ["jump", "runjump", "double_jump"], "jump cuts the recovery (anim %s)" % P.anim)
		await until(func(): return P.on and P.anim == "idle")
		P.start_attack()
		await until(func(): return P.anim == "attack1" and P.rec_cancel_ok(), 1500.0)
		var before: String = P.anim
		P.buf["guard"] = P.BUF
		await frames(2)
		ok(P.anim != before or P.buf["guard"] <= 0.0, "skill key cuts the recovery (anim %s)" % P.anim)
		await until(func(): return P.on and P.anim == "idle", 4000.0)

	print("DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
