extends SceneTree
## The counter while Eilin is away (eilin.gd desk_note, fame.gd eil_work away, hall.gd note_rect): her folded note sits on
## the counter only while she is off the desk, the counter's key reads it (the feed line) and opens the desk menu she
## would open, without her in person; with her at the desk nothing changes.
## godot --headless -s tests/test_eilin_desk.gd
var bad := 0

func ok(c: bool, what: String) -> void:
	if not c:
		bad += 1
		print("FAIL ", what)
	else:
		print("ok ", what)

## pick a choice by label as the dialog offers it
func choose(arena, label: String) -> bool:
	var D = arena.dlg
	if not D.active: return false
	for k in D.choices.size():
		if String(D.choices[k][0]).begins_with(label):
			D.i = D.lines.size() - 1
			D._pick(k)
			return true
	return false

func labels(arena) -> Array:
	return arena.dlg.choices.map(func(c): return String(c[0]))

## stand at the counter with the clock at h; she snaps to where her plan puts her
func at_counter(arena, h: float) -> void:
	arena.tod_h = h
	arena.go_hall(0, Vector2(2020.0, arena.ground_y), 1)
	arena.eil.snap()
	for i in 10: arena._process(0.016)

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var E = arena.eil
	var F = arena.fame
	var H = arena.level
	arena.tod_auto = false
	# ---- the normal path: 09:00, she is at the desk ----
	at_counter(arena, 9.0)
	H = arena.level
	ok(E.at_desk() and H.note_rect() == null, "09:00: she is at the desk, no note on the counter")
	ok(H.near_door != null and H.near_door["act"] == "counter" and H.near_door["k"] == "대화", "the counter prompt reads 대화")
	arena.try_interact()
	ok(arena.dlg.active and arena.dlg.who == "eilin" and arena.dlg.por == E.POR and arena.dlg.nm == "에일린", "the counter key talks to her (her portrait, her greeting)")
	var present: Array = labels(arena)
	ok(present.size() == 4 and present[0].begins_with("의뢰 완료 보고") and present[1].begins_with("길드 수첩") and present[2] == "모험 수첩" and present[3] == "그만 가볼게요", "her desk menu: 보고 · 길드 수첩 · 모험 수첩 · 그만 (%s)" % [present])
	ok(F.fx._feed_hidden(), "the feed hides under her talk box as before")
	ok(not F.fx.feed.any(func(n): return String(n["s"]) == E.NOTE_LINE), "no note line in the feed while she is there")
	choose(arena, "그만")
	ok(not arena.dlg.active and E.talk_t == 0.0, "그만 가볼게요 closes it and lets her go")
	# ---- 23:30: asleep upstairs (her plan puts her in her room) ----
	at_counter(arena, 23.5)
	H = arena.level
	ok(E.spot == "room" and E.map == "room" and not E.at_desk(), "23:30: she is in her room")
	var nr = H.note_rect()
	ok(nr is Rect2 and (nr as Rect2).position.x > 1900.0 and (nr as Rect2).end.x < 2112.0 and (nr as Rect2).end.y <= arena.ground_y - H.HH("counter") + 16.0 + 0.5, "her note lies on the counter top (%s)" % [nr])
	ok(H.near_door != null and H.near_door["act"] == "counter" and H.near_door["k"] == "쪽지", "the counter prompt reads 쪽지 (the same spot, r %d)" % int(H.near_door["r"]))
	arena.try_interact()
	ok(arena.dlg.active and arena.dlg.who == E.NOTE_WHO and arena.dlg.por == null and arena.dlg.nm != "에일린", "the counter key opens the desk without her: no portrait, not her name (%s / %s)" % [arena.dlg.nm, arena.dlg.role])
	ok(arena.dlg.lines == [E.desk_away()] and E.desk_away() == "주무시는 시간이에요.", "the talk box says where she is")
	var away: Array = labels(arena)
	var hers: Array = present.filter(func(l): return l.contains("대화"))
	ok(hers.is_empty() and away == present.filter(func(l): return not l.contains("대화")), "the same desk menu, less anything that is hers in person (%s)" % [away])
	ok(F.eil_only(["잡담한다", null, "talk"]) and not F.eil_only(["그만 가볼게요", null, "leave"]) and not arena.dlg.choices.any(func(c): return F.eil_only(c)), "a chat entry (icon talk) would be hers in person; the desk has none, so nothing is hidden")
	ok(not F.fx.feed.is_empty() and String(F.fx.feed[F.fx.feed.size() - 1]["s"]) == E.NOTE_LINE and String(F.fx.feed[F.fx.feed.size() - 1]["tag"]) == "접수대", "the note's line went to the feed first")
	ok(not F.fx._feed_hidden(), "the feed stays up under the desk menu (the note's line is readable)")
	ok(E.talk_t == 0.0 and E.spot == "room", "she is not held by it (asleep upstairs)")
	choose(arena, "그만")
	ok(not arena.dlg.active, "그만 가볼게요 closes the note menu")
	# the entries work without her: the guild book opens from the note menu
	arena.try_interact()
	choose(arena, "길드 수첩")
	ok(arena.ui_root.menu.page == "gbk", "길드 수첩 opens from the note menu (page %s)" % arena.ui_root.menu.page)
	arena.ui_root.menu.page = ""
	arena.dlg.active = false
	# ---- 12:30, at lunch; 19:00, in town: away as well ----
	for spec in [[12.5, "table", "점심 식사 중이에요. 식당 쪽에 계세요."], [19.0, "town", "퇴근하셨어요. 마을 어딘가에 계실 거예요."]]:
		at_counter(arena, spec[0])
		H = arena.level
		arena.try_interact()
		ok(E.spot == spec[1] and H.note_rect() != null and arena.dlg.active and arena.dlg.who == E.NOTE_WHO and arena.dlg.lines == [spec[2]] and labels(arena) == away, "%.1fh (%s): the note and the same menu" % [spec[0], spec[1]])
		choose(arena, "그만")
	# ---- the report is hers to stamp only in person: the entry still works from the note ----
	at_counter(arena, 23.5)
	arena.try_interact()
	choose(arena, "의뢰 완료 보고")
	ok(arena.dlg.active and arena.dlg.who == "eilin" and arena.dlg.lines[0] == "지금 보고하실 의뢰는 없네요.", "의뢰 완료 보고 runs from the note menu (nothing to report yet)")
	ok(E.a != "stamp", "no stamp without her at the desk")
	arena.dlg.active = false
	# ---- back at the desk: the note is gone and she answers again ----
	at_counter(arena, 14.0)
	H = arena.level
	arena.try_interact()
	ok(E.at_desk() and H.note_rect() == null and arena.dlg.who == "eilin" and labels(arena) == present, "14:00: she is back, the note is gone, her menu as before")
	choose(arena, "그만")
	print("eilin desk checks done, bad=", bad)
	quit()
