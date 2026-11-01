extends SceneTree
## Headless check of the counter swap and QTE tag-in: godot --headless -s tests/test_swap.gd

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var P = arena.player
	var m = arena.spawn("goblin", P.position.x + 120.0, 0.0)
	m.spawn_t = 0.0
	m.aw = true
	m.dir = -1
	m.st = "atk"
	m.set_a("atk")
	m.hit_at = 450.0
	m.atk_clock = 300.0
	m.flared = true
	P.party_input()
	print("after counter swap: who=", P.who, " anim=", P.anim, " mob st=", m.st, " hurt_t=", m.hurt_t, " tag_mul=", P.tag_mul)
	var hp0: float = m.hp
	for i in 40:
		P.step(16.0)
		for mm in arena.mobs: mm.step(16.0)
	print("tag strike landed: mob hp ", hp0, " -> ", m.hp, " anim=", P.anim)
	# QTE: Estelle gets hit -> nobody but Estelle answers 'hit'; make Aida current and get hit -> Estelle offered
	P.qte_offer("finisher")
	print("qte who after finisher (current ", P.who, "): ", P.qte["who"], " t=", P.qte["t"])
	P.party_input()
	print("after QTE swap: who=", P.who, " anim=", P.anim, " qte t=", P.qte["t"])
	# flying target: air tag
	var e = arena.spawn("eye", P.position.x + 200.0, 0.0)
	e.spawn_t = 0.0
	P.swap_cd = 0.0
	P.qte_offer("parry")
	P.party_input()
	print("air tag vs eye: who=", P.who, " anim=", P.anim, " air_tag=", P.air_tag, " y=", P.position.y, " ground=", arena.ground_y)
	print("process start")
	for i in 30:
		arena._process(0.016)
	print("process done")
	arena.big_word("PARRY", Color.WHITE, 800.0, Vector2(0, -100))
	arena.big_word("극한 회피!", Color.WHITE, 800.0, Vector2(0, -100))
	for i in 5:
		arena._process(0.016)
		pass
	print("draw ok")
	quit()
