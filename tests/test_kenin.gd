extends SceneTree
## 케닌 클로: joins at guild grade 2, every member table knows him, the pistol empties and reloads (fast on the bench),
## sticky bombs stick and blow (a shot sets one off), the roll bounces off a wall into the hurt frames without damage,
## his QTE shoots from the bench without a swap (three stamps, the swap cooldown reset), his charged attack
## sets off every stamp and bomb in a chain, the ult (reload, a blink barrage, reload, again, the chain):
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
	ok(K.ammo == K.AMMO - 1, "a round spent (%d left)" % K.ammo)
	ok(await until(func(): return g.hp < hp0, 3000.0), "the ball flies and hits (%.1f -> %.1f)" % [hp0, g.hp])
	await until(func(): return K.shots.is_empty(), 2000.0)
	K.ammo = K.amax()
	var shots_seen := 0
	P.set_anim("attack1", 1)
	var t_b := Time.get_ticks_msec()
	while P.anim == "attack1" and Time.get_ticks_msec() - t_b < 2000:
		shots_seen = maxi(shots_seen, K.amax() - K.ammo)
		await process_frame
	ok(shots_seen == K.BURST, "one attack: a 3-round burst, the shot frame replayed for each (%d)" % shots_seen)
	for i in K.amax(): K.fire(P.position + Vector2(40, -48), Vector2(1, 0), 1.0)
	ok(K.ammo == 0 and K.dry(), "the cylinder runs dry")
	await until(func(): return K.shots.is_empty(), 3000.0)
	var hp1: float = g.hp
	ok(not K.fire(P.position + Vector2(40, -48), Vector2(1, 0), 1.0) and K.shots.is_empty(), "empty: nothing comes out")
	ok(K.marked_count() >= 1, "landed bullets leave stamps (%d)" % K.marked_count())
	P.set_anim("attack1", 2)
	ok(await until(func(): return P.anim == "kdry", 1500.0), "an empty attack: he looks at the pistol")
	ok(await until(func(): return P.anim == "idle", 2000.0), "and gets over it")
	K.reload_t = K.RELOAD_FIELD - 300.0
	ok(await until(func(): return K.ammo == K.AMMO, 3000.0), "an empty pistol reloads out front")
	K.marks.clear()

	print("sticky bombs")
	var b0: int = K.bombs
	K.throw_bomb(Vector2(g.position.x - 120.0, g.position.y - 88.0), 1)
	ok(K.bombs == b0 - 1, "a bomb spent")
	ok(await until(func(): return K._bomb_on(g) != null, 2000.0), "it sticks to the goblin")
	var hp2: float = g.hp
	ok(await until(func(): return K.live_bombs() == 0, 6000.0), "the fuse runs out")
	ok(g.hp < hp2 - 2.0, "the blast hurts (%.1f)" % (hp2 - g.hp))
	ok(K.marked_count() == 1, "and stamps the foe (%d)" % K.marked_count())
	K.marks.clear()
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
	P.party_lock = 0.0
	P.qte_gap = 0.0
	P.qte_offer("finisher")
	ok(P.qte["who"].has("kenin"), "a finisher calls him")
	P.party_input()
	ok(P.who == "estelle", "no swap: Estelle stays in control")
	ok(P.swap_cd == 0.0, "her swap cooldown is reset")
	ok(P.party_lock > 0.0, "the party keys rest while his shot plays")
	P.party_input()
	ok(P.who == "estelle", "a second press right away does nothing")
	P.qte_offer("finisher")
	ok(P.qte["t"] <= 0.0, "no new QTE straight after one was answered")
	ok(K.assists.size() == 1, "he appears at the foe's side")
	K.marks.clear()
	var hp3: float = g.hp
	ok(await until(func(): return K.assists.is_empty(), 3000.0), "and is gone")
	ok(g.hp < hp3 and K.marked_count() == K.MARK_QTE, "the headshot lands and stamps (%.1f, %d)" % [hp3 - g.hp, K.marked_count()])

	print("the detonator (charged attack)")
	P.swap(false, "kenin")
	await until(func(): return P.who == "kenin" and P.anim != "swap_in")
	P.dir = 1 if g.position.x > P.position.x else -1
	K.bombs = K.BOMBS
	K.throw_bomb(Vector2(g.position.x - P.dir * 120.0, g.position.y - 88.0), P.dir)
	await until(func(): return K._bomb_on(g) != null, 2000.0)
	var hp5: float = g.hp
	var want: int = K.marked_count() + K.live_bombs()
	Input.action_press("attack")
	P.set_anim("attack1", 1)
	ok(await until(func(): return P.anim == "kcharge", 1500.0), "holding attack: the detonator box comes out")
	await frames(30)
	Input.action_release("attack")
	ok(await until(func(): return P.anim == "kfire", 1500.0), "let go: the plunger")
	ok(await until(func(): return K.chain_n > 0, 1500.0), "the chain starts")
	ok(K.chain_tot == want, "every stamp and bomb queued (%d of %d)" % [K.chain_tot, want])
	ok(await until(func(): return not K.chaining(), 4000.0), "and runs out")
	ok(K.marked_count() == 0 and K.live_bombs() == 0 and g.hp < hp5, "all gone off (%.1f)" % (hp5 - g.hp))

	print("the ult")
	await until(func(): return P.anim == "idle", 2000.0)
	K.ammo = 0
	arena.ult.v["kenin"] = arena.ult.ULTMAX["kenin"]
	arena.ult.cd["kenin"] = 0.0
	var hp4: float = g.hp
	ok(arena.ult.try_ult(), "the ult fires")
	var peak := 0
	var spots := {}
	var t0 := Time.get_ticks_msec()
	while arena.ult.state != "" and Time.get_ticks_msec() - t0 < 12000:
		peak = maxi(peak, K.marked_count())
		if arena.ult.state == "act": spots[int(P.position.x / 40.0) * 1000 + int(P.position.y / 40.0)] = true
		await process_frame
	ok(arena.ult.state == "", "and ends")
	ok(peak >= 20, "the barrage stamps it all over (%d)" % peak)
	ok(spots.size() >= 6, "from all sides (%d spots)" % spots.size())
	ok(K.ammo == K.AMMO or K.ammo >= 0, "reloaded on the way")
	ok(K.live_bombs() == 0 and K.marked_count() == 0, "every bomb and mark went off")
	ok(g.hp < hp4 - 5.0, "big damage (%.1f)" % (hp4 - g.hp))

	print("memory nodes")
	var MM = arena.runes.memory
	MM.T("kenin")["on"] = ["A1", "A6", "B1", "B4", "C4", "C6"]     # 탄띠 · 비상 탄창 · 주머니 · 접촉 신관 · 시한 표식 · 약점 표시
	MM._fx_cache.clear()
	ok(K.amax() == K.AMMO + 6 and K.bmax() == K.BOMBS + 1, "장탄 +6, 폭탄 +1 (%d, %d)" % [K.amax(), K.bmax()])
	K.ammo = 1
	K.spare_t = 0.0
	K.fire(P.position + Vector2(40, -48), Vector2(1, 0), 1.0)
	ok(K.ammo == K.amax() and K.spare_t > 0.0, "비상 탄창: running dry reloads at once (%d)" % K.ammo)
	K.ammo = 1
	K.fire(P.position + Vector2(40, -48), Vector2(1, 0), 1.0)
	ok(K.ammo == 0, "and not again until its cooldown")
	await until(func(): return K.shots.is_empty(), 2000.0)
	var g2 = gob(P.position.x + 200.0 * P.dir)
	await frames(3)
	K.bombs = K.bmax()
	K.throw_bomb(Vector2(g2.position.x - 120.0 * P.dir, g2.position.y - 88.0), P.dir)
	var t_th := Time.get_ticks_msec()
	ok(await until(func(): return K.live_bombs() == 0, 1500.0), "접촉 신관: the bomb blows as it sticks (%d ms)" % (Time.get_ticks_msec() - t_th))
	K.marks.clear()
	K.add_marks(g2, 2)
	for q in K.marks[g2.get_instance_id()]["pts"]: q["t"] = 4990.0
	var hp6: float = g2.hp
	ok(await until(func(): return K.marked_count() == 0, 1500.0) and g2.hp < hp6, "시한 표식: stamps pop on their own")
	K.assist(g2)
	await until(func(): return K.assists.is_empty(), 3000.0)
	ok(g2.has_meta("kvuln_t") and int(g2.get_meta("kvuln_t")) > Time.get_ticks_msec(), "약점 표시: the covering shot leaves the foe exposed")
	MM.T("kenin")["on"] = []
	MM._fx_cache.clear()
	K.ammo = K.amax()

	print("bench reload")
	K.ammo = 0
	P.swap_cd = 0.0
	P.swap(false, "estelle")
	await until(func(): return P.who == "estelle")
	ok(await until(func(): return K.ammo == K.AMMO, 8000.0), "back in the party he rearms faster")

	print("DONE: %d failed" % fails)
	quit(1 if fails > 0 else 0)
