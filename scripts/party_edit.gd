extends Node
## The world's way into the party screen (prototype openParty, rewired to openParty2): the fountain, the hall's living
## room and the dungeon select's faces call show_it(), which opens the menu's PARTY page (ui_party.gd, #pt2) as the
## top bar's 파티 does. The old v1 card panel is gone. `open` is true while that page is up (sortie.holds / covers).

var arena
var sortie

var open: bool:
	get:
		return _menu() != null and _menu().page == "party"
	set(v):
		if not v and open:
			_menu().page = ""

func _menu():
	if arena == null or arena.get("ui_root") == null: return null
	return arena.ui_root.menu

func show_it() -> void:
	var m = _menu()
	if m == null: return
	m.open_page("party")

func close() -> void:
	if open: _menu().close_page()

## the v1 card's buttons on the new page (on member c): out → 빼기 (empties the slot), in → into the first empty slot,
## ctl → 리더로, info → 정보
func press(c: String, act: String) -> void:
	var m = _menu()
	if m == null: return
	var pg = m.ext["party"]
	var P = arena.player
	var i: int = P.party.find(c)
	match act:
		"out":
			if i >= 0: pg.empty_slot(i)
		"in":
			if i < 0 and P.party.size() < 3: pg.assign(P.party.size(), c)
		"ctl":
			if i < 0 and P.party.size() < 3: pg.assign(P.party.size(), c)
			if P.party.has(c): pg._swap(c)
		"info":
			if i >= 0:
				pg.slot = i
				pg.press("info")
