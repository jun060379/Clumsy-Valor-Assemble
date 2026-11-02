extends SceneTree
## Korean text coverage: godot --headless --path . -s tests/test_fonts.gd
## Every font the game draws with (ui_kit.gd / fame_skin.gd getters, arena's font_*, the codex serif) must have, with its
## fallbacks, every character of every string literal in the scripts, every modern Hangul syllable (U+AC00-D7A3), the jamo
## and the symbols built at run time (★%d, ·, ≫, Ⓧ, ♪, arrows, digits). The web build has no system fonts to fall back on,
## so a miss here is a tofu box on a phone.

const UI := preload("res://scripts/ui_kit.gd")
const S := preload("res://scripts/fame_skin.gd")
const RARE := "똠쀍햏뷁펲닭읊쌰뙇꺠뾰햙듦슭"
## drawn by hand, never through a font (ui_char_mem.gd's padlock cuts it off the line first)
const HAND := "🔒"
const RUNTIME := "0123456789+-−×%./:()[]★☆·…—–≫Ⓧ♪←→↑↓▶◀▲▼◆◇●○■□✓✉☠⚠「」《》"

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

## the string literals of a GDScript source ("...", '...', """...""", with \n \t \uXXXX escapes), comments skipped
static func literals(src: String) -> PackedStringArray:
	var out := PackedStringArray()
	var i := 0
	var n := src.length()
	while i < n:
		var c := src[i]
		if c == "#":
			var j := src.find("\n", i)
			i = n if j < 0 else j
			continue
		if c == "\"" or c == "'":
			if src.substr(i, 3) == c + c + c:
				var e := src.find(c + c + c, i + 3)
				if e < 0: break
				out.append(src.substr(i + 3, e - i - 3))
				i = e + 3
				continue
			var j := i + 1
			var buf := ""
			while j < n and src[j] != c and src[j] != "\n":
				if src[j] == "\\" and j + 1 < n:
					var x := src[j + 1]
					if x == "u":
						buf += String.chr(src.substr(j + 2, 4).hex_to_int())
						j += 6
						continue
					if x == "U":
						buf += String.chr(src.substr(j + 2, 6).hex_to_int())
						j += 8
						continue
					buf += {"n": "\n", "t": "\t", "r": "\r"}.get(x, x)
					j += 2
					continue
				buf += src[j]
				j += 1
			out.append(buf)
			i = j + 1
			continue
		i += 1
	return out

static func gd_files(dir: String, acc: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null: return
	for f in d.get_files():
		if f.ends_with(".gd"): acc.append(dir.path_join(f))
	for sub in d.get_directories():
		gd_files(dir.path_join(sub), acc)

## every character the scripts can put on screen: code point -> one file that has it
static func shown_chars() -> Dictionary:
	var files: Array = []
	gd_files("res://scripts", files)
	gd_files("res://assets", files)
	var out := {}
	for p in files:
		for s in literals(FileAccess.get_file_as_string(p)):
			for k in s.length():
				var cp := s.unicode_at(k)
				if cp < 32 or HAND.contains(s[k]): continue
				if not out.has(cp): out[cp] = p.get_file()
	for k in RUNTIME.length(): out[RUNTIME.unicode_at(k)] = "runtime"
	for k in RARE.length(): out[RARE.unicode_at(k)] = "rare"
	for cp in range(32, 127): out[cp] = "ascii"
	return out

static func missing(f: Font, cps: Array) -> String:
	var m := ""
	for cp in cps:
		if not f.has_char(cp): m += String.chr(cp)
	return m

static func span(a: int, b: int) -> Array:
	var r: Array = []
	for cp in range(a, b + 1): r.append(cp)
	return r

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame

	var shown := shown_chars()
	var cps: Array = shown.keys()
	cps.sort()
	var hangul := 0
	for cp in cps: if cp >= 0xAC00 and cp <= 0xD7A3: hangul += 1
	check(cps.size() > 500 and hangul > 600, "collected %d characters (%d syllables) from the scripts" % [cps.size(), hangul])
	check(literals("a = \"한글\\n\" # \"주석\"\nb = '★'").size() == 2, "the literal scanner skips comments")

	var fonts := {
		"UI.bhs": UI.bhs(), "UI.noto": UI.noto(), "UI.noto_k": UI.noto_k(), "UI.anton": UI.anton(),
		"UI.anton(italic, 2)": UI.anton(true, 2), "UI.spaced(noto_k)": UI.spaced(UI.noto_k(), 3),
		"UI.spaced(anton)": UI.spaced(UI.anton(), 1), "UI.spaced(anton(italic, 2))": UI.spaced(UI.anton(true, 2), 3),
		"UI.spaced(codex SERIF)": UI.spaced(load("res://scripts/ui_codex.gd").SERIF, 2),
		"UI.serif": UI.serif(), "UI.serif_b (codex)": UI.serif_b(),
		"S.bhs": S.bhs(), "S.noto": S.noto(), "S.noto_k": S.noto_k(), "S.serif": S.serif(), "S.anton(italic)": S.anton(true), "S.spaced(bhs)": S.spaced(S.bhs(), 4),
		"arena.font_bold": arena.font_bold, "arena.font_black": arena.font_black, "arena.font_anton": arena.font_anton,
		"arena.anton_italic": arena.anton_italic(),
		"codex SERIF": load("res://scripts/ui_codex.gd").SERIF,
	}
	var files := UI.all_fonts()
	for k in files: fonts["file " + k] = files[k]

	var syll := span(0xAC00, 0xD7A3)
	var jamo := span(0x1100, 0x11FF) + span(0x3131, 0x318E)
	for k in fonts:
		var f: Font = fonts[k]
		var m := missing(f, cps)
		var where := ""
		for j in mini(m.length(), 12): where += " %s(%s)" % [m[j], shown[m.unicode_at(j)]]
		check(m == "", "%s: every shown character%s" % [k, "" if m == "" else " — lacks %d:%s" % [m.length(), where]])
		var ms := missing(f, syll)
		check(ms == "", "%s: all 11,172 syllables%s" % [k, "" if ms == "" else " — lacks %d (%s…)" % [ms.length(), ms.left(10)]])
		var mj := missing(f, jamo)
		check(mj == "", "%s: Hangul Jamo + Compatibility Jamo%s" % [k, "" if mj == "" else " — lacks %d" % mj.length()])

	# no copies of the font files: a duplicated FontFile shares the original's glyph cache, and the two writing into it
	# garble the Hangul (bits of other syllables over the letters: fame_skin.gd's copies of Noto Bold / Black did that)
	var originals: Array = files.values()
	for k in fonts:
		var b: Font = fonts[k]
		while b is FontVariation and b.base_font != null: b = b.base_font
		check(originals.has(b), "%s is drawn from the shared %s, not a copy" % [k, b.resource_path.get_file() if b.resource_path != "" else "(copy)"])

	# the Noto files carry every syllable themselves (the serifs keep their look; nothing falls through to another face)
	for k in ["NotoSansKR-Bold", "NotoSansKR-Black", "NotoSerifKR-Black", "NotoSerifKR-Bold"]:
		var own: FontFile = files[k].duplicate()
		own.fallbacks = []
		check(missing(own, syll) == "" and missing(own, span(0x1100, 0x11FF)) == "", "%s alone has every syllable and jamo" % k)

	# every font file in assets/fonts is one ui_kit knows (a new file has to join the chains, and this test)
	var known := ["DejaVuSans-sym.ttf"]
	for k in files: known.append(files[k].resource_path.get_file())
	for f in DirAccess.get_files_at("res://assets/fonts"):
		if f.get_extension() in ["ttf", "otf", "woff", "woff2"]:
			check(known.has(f), "%s is wired into ui_kit.gd" % f)

	# no system fallback: the desktop builds show what a phone shows
	for f in DirAccess.get_files_at("res://assets/fonts"):
		if f.ends_with(".import"):
			var cf := ConfigFile.new()
			cf.load("res://assets/fonts/" + f)
			check(cf.get_value("params", "allow_system_fallback", true) == false, "%s: allow_system_fallback off" % f.get_basename())

	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
