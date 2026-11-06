extends SceneTree
## Boss bot (owner 2026-11-06): for every boss kind, a bot that only uses the player's controls (Input actions, the
## same ones a person presses) fights it headless, from the boss room's door, with the default party.
## Prints one line per boss:  BOSS <kind> cleared=<true|false> time=<s> hp_lost=<n>/<max> party_down=<bool>
## and FAILS: <n> (n = bosses not cleared) so tools/runtests.sh / tools/test.sh count it.
## godot --headless --fixed-fps 60 --path . -s tests/bot_boss.gd [-- LIMIT_S]
const MB := preload("res://scripts/mob.gd")
var arena
var limit_s := 240.0

func frames(k: int) -> void:
	for i in k: await process_frame

func press(a: String) -> void:
	Input.action_press(a)

func release_all() -> void:
	for a in ["left", "right", "up", "down", "jump", "attack", "guard", "dash", "ult", "swap"]:
		if InputMap.has_action(a): Input.action_release(a)

func goto_boss(D) -> bool:
	for k in D.rooms:
		if D.rooms[k]["type"] == "boss":
			D.from = "L"
			D.cur = k
			D.enter()
			return true
	return false

func team_hp(P) -> float:
	var s: float = P.hp
	for c in P.party:
		if c != P.who and P.hpm.has(c): s += float(P.hpm[c])
	return s

func team_max(P) -> float:
	var s := 0.0
	for c in P.party: s += float(P._mhp(c))
	return s

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: limit_s = float(args[0])
	var kinds := []
	for k in MB.DEF.keys():
		if MB.DEF[k].has("boss"): kinds.append(k)
	if kinds.is_empty(): kinds = ["boss"]
	var fails := 0
	for kind in kinds:
		var r = await fight(kind)
		print("BOSS %s cleared=%s time=%.1f hp_lost=%d/%d party_down=%s" % [kind, str(r["ok"]), r["t"], int(r["lost"]), int(r["max"]), str(r["down"])])
		if not r["ok"]: fails += 1
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)

func fight(kind: String) -> Dictionary:
	if arena != null:
		arena.queue_free()
		await frames(2)
	seed(7)
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.cfg.aim = "off"
	arena.enter_dungeon()
	await frames(30)
	var D = arena.level
	goto_boss(D)
	await frames(10)
	var boss = null
	for m in arena.mobs:
		if m.kind == kind: boss = m
	if boss == null:
		# a boss kind that has no room of its own yet: summon it into the boss room
		boss = arena.spawn(kind, arena.player.position.x + 500.0, 0.0, -1.0, null, false, 4)
	var P = arena.player
	var hp0 := team_hp(P)
	var mx := team_max(P)
	var t := 0.0
	var f := 0
	while t < limit_s:
		await process_frame
		f += 1
		t += 1.0 / 60.0
		release_all()
		if boss == null or not is_instance_valid(boss) or boss.is_dead(): break
		if P.party_down: break
		var dx: float = boss.position.x - P.position.x
		var side := "right" if dx > 0.0 else "left"
		# the glint: guard into it (a parry); after a parry, keep swinging
		if boss.st == "atk" and boss.flared and absf(dx) < 260.0:
			if f % 2 == 0: press("guard")
			continue
		if absf(dx) > 120.0:
			press(side)
			if absf(dx) > 380.0 and f % 40 == 0: press("dash")
		else:
			if (dx > 0.0) != (P.dir > 0): press(side)
			if f % 8 < 2: press("attack")
			if f % 300 == 150: press("ult")
	release_all()
	var lost := hp0 - team_hp(P)
	var ok: bool = boss != null and is_instance_valid(boss) and boss.is_dead()
	return {"ok": ok, "t": t, "lost": maxf(0.0, lost), "max": mx, "down": P.party_down}
