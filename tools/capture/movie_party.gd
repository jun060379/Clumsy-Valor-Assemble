extends SceneTree
## 편성 in motion, for Movie Maker: the slots deal in, the pointer wanders over them, a tap, the desk, files dealt,
## hover, lift, send, the stamp, back.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 900x500 --path . --fixed-fps 30 --write-movie OUT.avi -s tools/capture/movie_party.gd
var arena

func frames(n: int) -> void:
	for i in n: await process_frame

func glide(pg, a: Vector2, b: Vector2, n: int) -> void:
	for i in n:
		pg.hover = a.lerp(b, float(i + 1) / n)
		await process_frame

func _initialize() -> void:
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.fame.rec = ["estelle", "aida", "luce", "kenin"]
	arena.fame.r = 2
	var P = arena.player
	P.party = ["estelle", "luce"]
	var M = arena.ui_root.menu
	M.open_page("party")
	var pg = M.ext["party"]
	pg.hover = Vector2(450, 250)
	await frames(40)
	await glide(pg, Vector2(450, 250), Vector2(200, 260), 20)
	await frames(10)
	await glide(pg, Vector2(200, 260), Vector2(480, 260), 20)
	await frames(6)
	pg.pops["slab1"] = pg.t
	pg.pick(1)
	await frames(24)
	await glide(pg, Vector2(480, 260), Vector2(760, 260), 20)
	await frames(10)
	pg.pick(2)
	await frames(50)
	await glide(pg, Vector2(760, 260), Vector2(520, 160), 18)
	await frames(10)
	await glide(pg, Vector2(520, 160), Vector2(720, 330), 18)
	await frames(8)
	pg.file_tap("kenin")
	await frames(30)
	await glide(pg, Vector2(720, 330), Vector2(290, 440), 16)
	await frames(26)
	pg.send()
	await frames(60)
	await glide(pg, Vector2(290, 440), Vector2(700, 250), 20)
	await frames(40)
	print("CAP done")
	quit()
