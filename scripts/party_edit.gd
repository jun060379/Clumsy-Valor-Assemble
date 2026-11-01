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

## the v1 card's buttons on the new page: out / in → 빼기 · 넣기, ctl → 리더로, info → 정보 (on member c)
func press(c: String, act: String) -> void:
	var m = _menu()
	if m == null: return
	var pg = m.ext["party"]
	pg.sel = c
	var a: String = {"out": "in", "in": "in", "ctl": "lead", "info": "info"}.get(act, "")
	var inP: bool = arena.player.party.has(c)
	if a == "" or (act == "out" and not inP) or (act == "in" and inP): return
	pg.press(a)
