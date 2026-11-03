extends SceneTree
## 케닌 클로: joins at guild grade 2, every member table knows him, the pistol empties and reloads (fast on the bench),
## sticky bombs stick and blow (a shot sets one off), the roll bounces off a wall into the hurt frames without damage,
## his QTE shoots from the bench without a swap (a mark, the swap cooldown reset), the ult detonates bombs and marks:
## godot --headless --path . -s tests/test_kenin.gd

const CH := preload("res://scripts/chars.gd")

var arena
var fails := 0

func ok(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func frames(n: int) -> void:
	for i in n: await process_frame

func until(cond: Callable, ms := 8000.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await process_frame
		if Time.get_ticks_msec() - t0 > ms / Engine.time_scale + 2000: return false
	return true

func gob(x: float, hp := 999.0):
	var m = arena.spawn("goblin", x, 0.0)
	m.hp = hp
	m.max_hp = maxf(m.max_hp, hp)
	m.cd = 99999.0
	m.M = m.M.duplicate()
	m.M["ms"] = 0.0
	return m

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_test.json"))
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(3)
	var P = arena.player
	var K = arena.kenin
	var F = arena.fame

	print("tables and recruitment")
	for t in [CH.NAME, CH.SCALE, CH.STATS, CH.COLOR, CH.TABLE, arena.SPK, arena.ult.ULTMAX, arena.runes.CLS]:
		ok(t.has("kenin"), "a member table knows kenin (%d keys)" % t.size())
	ok(arena.runes.CLS["kenin"] == "도적", "class 도적")
	ok(not F.recruited("kenin"), "not in the guild on a fresh game")
	F.join()
	F.r = 2              # (rank_up() itself plays the rank cut, which holds the world)
	F.join_kenin()
	ok(F.recruited("kenin"), "joins with guild grade 2 (placeholder)")
	ok(P.roster().has("kenin"), "in the roster")
	arena.toggle_member("kenin")
	ok(P.party.has("kenin"), "taken along")

	print("the pistol")
	arena.enter_dungeon()
	await frames(20)
	arena.clear_room()
	P.position.x = 500.0
	P.dir = 1
	P.swap_cd = 0.0
	P.swap(false, "kenin")
	await until(func(): return P.who == "kenin" and P.anim != "swap_in")
	ok(P.who == "kenin", "in control")
	var g = gob(P.position.x + 260.0)
	await frames(5)
	var hp0: float = g.hp
	K.fire(P.position + Vector2(40, -48), Vector2(1, 0), 1.0)
	ok(K.ammo == K.AMMO - 1, "a shot spends a round (%d left)" % K.ammo)
	ok(await until(func(): return g.hp < hp0, 3000.0), "the ball flies and hits (%.1f -> %.1f)" % [hp0, g.hp])
	for i in K.AMMO: K.fire(P.position + Vector2(40, -48), Vector2(1, 0), 1.0)
	ok(K.ammo == 0 and K.dry(), "the cylinder runs dry")
	await until(func(): return K.shots.is_empty(), 3000.0)
	var hp1: float = g.hp
	K.fire(P.position + Vector2(40, -48), Vector2(1, 0), 1.0)
	await until(func(): return K.shots.is_empty(), 3000.0)
	ok(g.hp < hp1 and hp1 - g.hp < (hp0 - hp1) / 4.0, "a dry shot is weak (%.1f)" % (hp1 - g.hp))
	ok(await until(func(): return K.ammo == K.AMMO, 6000.0), "an empty pistol reloads out front")

	print("sticky bombs")
	var b0: int = K.bombs
	K.throw_bomb(Vector2(g.position.x - 120.0, g.position.y - 88.0), 1)
	ok(K.bombs == b0 - 1, "a bomb spent")
	ok(await until(func(): return K._bomb_on(g) != null, 2000.0), "it sticks to the goblin")
	var hp2: float = g.hp
	ok(await until(func(): return K.live_bombs() == 0, 6000.0), "the fuse runs out")
	ok(g.hp < hp2 - 2.0, "the blast hurts (%.1f)" % (hp2 - g.hp))
	K.throw_bomb(Vector2(g.position.x - 120.0, g.position.y - 88.0), 1)
	await until(func(): return K._bomb_on(g) != null, 2000.0)
	K.ammo = K.AMMO
	K.fire(P.position + Vector2(40, -48), Vector2(1, 0), 1.0)
	ok(await until(func(): return K.live_bombs() == 0, 1500.0), "a shot sets the stuck bomb off at once")

	print("the roll")
	var wx: float = arena.world_w - 30.0
	for so in arena.solids:
		if so.x > P.position.x + 60.0 and so.x < wx: wx = so.x - 12.0
	g.position.x = 80.0
	P.position.x = wx - 200.0
	P.dir = 1
	P.charges = 2
	P.dash_cd = 0.0
	var php: float = P.hp
	await frames(3)
	P.set_anim("dash")
	var saw_bounce := await until(func(): return P.anim == "hurt", 3000.0)
	ok(saw_bounce, "rolling into the wall turns into the hurt frames")
	ok(P.hp == php, "no damage from the bounce")
	ok(P.bounce_t > 0.0 or P.anim != "hurt", "bounced back")

	print("QTE from the bench")
	g.position.x = P.position.x - 180.0
	P.swap_cd = 0.0
	P.swap(false, "estelle")
	await until(func(): return P.who == "estelle" and P.anim != "swap_in")
	P.swap_cd = 1500.0
	P.qte["cd"] = 0.0
	P.qte_offer("finisher")
	ok(P.qte["who"].has("kenin"), "a finisher calls him")
	P.party_input()
	ok(P.who == "estelle", "no swap: Estelle stays in control")
	ok(P.swap_cd == 0.0, "her swap cooldown is reset")
	ok(K.assists.size() == 1, "he appears at the foe's side")
	var hp3: float = g.hp
	ok(await until(func(): return K.assists.is_empty(), 3000.0), "and is gone")
	ok(g.hp < hp3 and K.marked_count() == 1, "the headshot lands and marks (%.1f, %d)" % [hp3 - g.hp, K.marked_count()])

	print("the ult")
	P.swap(false, "kenin")
	await until(func(): return P.who == "kenin" and P.anim != "swap_in")
	K.bombs = K.BOMBS
	K.throw_bomb(Vector2(g.position.x - 120.0, g.position.y - 88.0), 1)
	await until(func(): return K._bomb_on(g) != null, 2000.0)
	arena.ult.v["kenin"] = arena.ult.ULTMAX["kenin"]
	arena.ult.cd["kenin"] = 0.0
	var hp4: float = g.hp
	ok(arena.ult.try_ult(), "the ult fires")
	ok(await until(func(): return arena.ult.state == "", 9000.0), "and ends")
	ok(K.live_bombs() == 0 and K.marked_count() == 0, "every bomb and mark went off")
	ok(g.hp < hp4 - 5.0, "big damage (%.1f)" % (hp4 - g.hp))

	print("bench reload")
	K.ammo = 0
	P.swap_cd = 0.0
	P.swap(false, "estelle")
	await until(func(): return P.who == "estelle")
	ok(await until(func(): return K.ammo == K.AMMO, 4000.0), "back in the party he rearms fast")

	print("DONE: %d failed" % fails)
	quit(1 if fails > 0 else 0)
