extends Node2D
## Step 0: pipeline check. Shows the logo and the build stamp so a web build can be confirmed on a phone.

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#0d0b10"))
	var logo := Sprite2D.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(logo)
	var lab := Label.new()
	lab.text = "PORT IN PROGRESS  ·  BUILD " + _stamp()
	lab.add_theme_font_size_override("font_size", 18)
	lab.modulate = Color("#ffd34d")
	add_child(lab)
	get_viewport().size_changed.connect(_layout.bind(logo, lab))
	_layout(logo, lab)

func _layout(logo: Sprite2D, lab: Label) -> void:
	var s := get_viewport_rect().size
	var k := minf(s.y * 0.7, s.x * 0.8) / 1024.0
	logo.scale = Vector2(k, k)
	logo.position = Vector2(s.x / 2, s.y * 0.45)
	lab.position = Vector2(16, s.y - 40)

func _stamp() -> String:
	var f := FileAccess.open("res://build.txt", FileAccess.READ)
	return f.get_as_text().strip_edges() if f else "local"
