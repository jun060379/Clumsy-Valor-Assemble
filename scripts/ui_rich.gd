extends RefCounted
## 키워드 강조 (owner 2026-11-04): in a skill / node text every shared status and effect name is drawn bold, in its
## colour and underlined; tapping it opens a small card that says what it does (the way the gacha games do it).
##   draw(ci, font, pos, text, width, size, col, a, on_key) → height; on_key(term, rect) for each keyword drawn
##   height(font, text, width, size)  ·  GLOSS: term → [colour, description]
## The words are found by name (longest first), so a text needs no markup: "취약" in any skill text lights up.

const ST := preload("res://scripts/status.gd")

## the shared statuses (numbers from status.gd), the members' own resources, and the boss gauge
static func gloss() -> Dictionary:
	var K: Dictionary = ST.K
	return {
		"취약": [K.vuln.col, "받는 피해가 늘어난다(+%d%% 고정), %d초. 교대 일격이 확정 치명타가 된다. 다시 걸면 시간만 갱신, 단계는 오르지 않는다." % [roundi(K.vuln.mul * 100.0), roundi(K.vuln.t / 1000.0)]],
		"경직": [K.stagger.col, "게이지가 가득 차면 %.1f초 동안 행동이 끊기고 무방비가 된다. 끝나면 %d초 동안 다시 걸리지 않는다. 보스 · 정예는 그로기 게이지로 받는다." % [K.stagger.t / 1000.0, roundi(K.stagger.imm / 1000.0)]],
		"띄움": [K.air.col, "적을 공중에 띄운다. 공중에서 맞을 때마다 조금 더 떠 있다(%d타까지). 보스 · 정예는 그로기 게이지로 받는다." % int(K.air.hits)],
		"둔화": [K.slow.col, "게이지가 가득 차면 %d초 동안 이동이 느려지고 공격 뒤 빈틈이 길어진다. 공격이 날아오는 타이밍은 그대로, 패링 판정은 넓어진다." % roundi(K.slow.t / 1000.0)],
		"연소": [K.burn.col, "게이지가 가득 차면 %d초 동안 %.1f초마다 피해. 주변의 타지 않는 적에게 번진다(남은 시간만큼). 교대 일격이 남은 피해를 한 번에 터뜨린다." % [roundi(K.burn.t / 1000.0), K.burn.tick / 1000.0]],
		"출혈": [K.bleed.col, "맞을 때마다 추가 피해(%.1f초 간격), %d초 또는 %d회. 교대 일격이 지속 시간을 처음으로 되돌린다." % [K.bleed.gap / 1000.0, roundi(K.bleed.t / 1000.0), int(K.bleed.n)]],
		"보호막": [Color("#9fd0ff"), "받는 피해를 먼저 흡수한다. 여러 번 받으면 더해져 최대 체력의 %d%%까지 쌓인다. 교대하면 남은 양이 들어오는 동료에게 넘어간다." % roundi(ST.SHIELD_CAP * 100.0)],
		"강화": [Color("#ffb347"), "공격력이 늘어난다. 교대하면 남은 시간이 들어오는 동료에게 넘어간다. 다시 받으면 센 쪽만 남는다."],
		"재생": [Color("#8fe08a"), "시간에 따라 체력이 회복된다. 대기 중인 동료도 같이 회복된다."],
		"그로기": [Color("#ffd34d"), "보스 · 정예 전용. 경직 · 띄움이 게이지로 쌓이고, 가득 차면 %d초 동안 쓰러지며 받는 피해 +%d%%." % [roundi(ST.GROGGY.t / 1000.0), roundi(ST.GROGGY.mul * 100.0)]],
		"표식": [Color("#e0a050"), "케닌 고유 자원. 총알 · 폭탄 · 원호가 적에게 새긴다. 적 하나에 아이콘 하나와 개수로 보인다. 차징 공격(기폭)이나 궁극기로 가까운 것부터 터뜨린다."],
		"징표": [Color("#b48cff"), "아이다 고유 자원. 궁극기 '땅 밑의 문'이 새기고, 마지막 폭발에서 징표 하나마다 피해가 들어간다."],
	}

static var _keys: Array = []

## 계수 → 최종값 (owner 2026-11-04): a skill text's {c.key} shows the number it deals / heals with the member's stats
## now; tapping it opens the breakdown. The provider (ui_char_mem.gd) sets arena so the stats can be read.
static var arena = null
const HEALS := ["luce.heal", "luce.bless_heal", "luce.save_heal"]
const BAL := preload("res://scripts/balance.gd")
const CH := preload("res://scripts/chars.gd")

## [final value, coefficient %, 공격력, 회복량 %] for "c.key"
static func value_of(ck: String) -> Array:
	var parts := ck.split(".")
	var c := parts[0]
	var pc: int = BAL.pct(c, parts[1])
	var R = arena.get("runes") if arena != null else null
	var ak: float = 10.0 * float(CH.STATS.get(c, {"atk": 1.0})["atk"]) * (R.atk_k(c) if R != null else 1.0)
	var hk := 0.0
	if HEALS.has(ck) and R != null: hk = float(R.gear_tot(c)["heal"])
	var v := pc / 100.0 * ak * (1.0 + hk / 100.0)
	return [v, pc, ak, hk]

static func value_text(ck: String) -> String:
	var v: float = value_of(ck)[0]
	return str(roundi(v)) if v >= 10.0 else ("%.1f" % v)

static func _sorted_keys() -> Array:
	if _keys.is_empty():
		_keys = gloss().keys()
		_keys.sort_custom(func(a, b): return String(a).length() > String(b).length())
	return _keys

## [[text, term or ""]], keywords found longest first
static func segs(text: String) -> Array:
	var keys := _sorted_keys()
	var out: Array = []
	var buf := ""
	var i := 0
	while i < text.length():
		# a coefficient token {c.key} → its final value, tappable (term "#c.key")
		if text[i] == "{":
			var j := text.find("}", i)
			if j > i and text.substr(i + 1, j - i - 1).find(".") > 0:
				var ck := text.substr(i + 1, j - i - 1)
				if buf.ends_with("×"):
					# a multiplier (폭탄 피해 ×100%), not a share of 공격력: it stays a percentage
					buf += "%d%%" % BAL.pct(ck.split(".")[0], ck.split(".")[1])
					i = j + 1
					continue
				if buf != "": out.append([buf, ""])
				buf = ""
				out.append([value_text(ck), "#" + ck])
				i = j + 1
				continue
		var hit := ""
		for k in keys:
			if text.substr(i, String(k).length()) == k:
				hit = k
				break
		if hit != "":
			if buf != "": out.append([buf, ""])
			buf = ""
			out.append([hit, hit])
			i += hit.length()
		else:
			buf += text[i]
			i += 1
	if buf != "": out.append([buf, ""])
	return out

## words (split at spaces, a keyword stays whole inside its word), "\n" kept as its own entry
static func _words(sg: Array) -> Array:
	var W: Array = []
	var cur: Array = []
	for s in sg:
		if String(s[1]) != "":
			cur.append(s)
			continue
		var piece := ""
		for ch in String(s[0]):
			if ch == " " or ch == "\n":
				if piece != "": cur.append([piece, ""])
				piece = ""
				if not cur.is_empty(): W.append(cur)
				cur = []
				if ch == "\n": W.append("\n")
			else:
				piece += ch
		if piece != "": cur.append([piece, ""])
	if not cur.is_empty(): W.append(cur)
	return W

static func _w(font: Font, s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## lines of runs [x, text, term]; a word too long for a line is broken by letters
static func layout(font: Font, text: String, width: float, size: int) -> Array:
	var lines: Array = [[]]
	var x := 0.0
	var sp := _w(font, " ", size)
	for w in _words(segs(text)):
		if w is String:
			lines.append([])
			x = 0.0
			continue
		var ww := 0.0
		for pc in w: ww += _w(font, pc[0], size)
		if x > 0.0 and x + ww > width:
			lines.append([])
			x = 0.0
		for pc in w:
			var s: String = pc[0]
			var pw := _w(font, s, size)
			if pw > width - x and String(pc[1]) == "" and x + pw > width:
				for ch in s:
					var cw := _w(font, ch, size)
					if x + cw > width and x > 0.0:
						lines.append([])
						x = 0.0
					lines[-1].append([x, ch, ""])
					x += cw
				continue
			lines[-1].append([x, s, pc[1]])
			x += pw
		x += sp
	return lines

static func height(font: Font, text: String, width: float, size: int) -> float:
	return layout(font, text, width, size).size() * font.get_height(size)

## the text at pos (its top-left); keywords bold (drawn twice), coloured and underlined. On a light card the colour
## is darkened to read. on_key(term, Rect2) is called for every keyword drawn (its tap area, in the canvas's space).
static func draw(ci: CanvasItem, font: Font, pos: Vector2, text: String, width: float, size: int, col: Color, a: float, on_key := Callable(), light := true) -> float:
	var G := gloss()
	var L := layout(font, text, width, size)
	var lh := font.get_height(size)
	var asc := font.get_ascent(size)
	for li in L.size():
		var y := pos.y + li * lh + asc
		for r in L[li]:
			var p := Vector2(pos.x + float(r[0]), y)
			var s: String = r[1]
			var term: String = r[2]
			if term == "":
				ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, a))
				continue
			var kc: Color = Color("#5aa0ff") if term.begins_with("#") else G[term][0]
			if light: kc = kc.darkened(0.35)
			var w := _w(font, s, size)
			ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(kc, a))
			ci.draw_string(font, p + Vector2(0.6, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(kc, a))
			ci.draw_line(p + Vector2(0, 2.5), p + Vector2(w + 0.6, 2.5), Color(kc, a * 0.8), 1.2)
			if on_key.is_valid(): on_key.call(term, Rect2(p.x - 2.0, y - asc - 2.0, w + 4.0, lh + 4.0))
	return L.size() * lh

## the explanation card: the term in its colour over a dark slanted card, the description under it; at (screen) p,
## kept inside vs. Returns the card's rect.
static func draw_tip(ci: CanvasItem, title_font: Font, font: Font, term: String, p: Vector2, vs: Vector2, a: float) -> Rect2:
	var G := gloss()
	if term.begins_with("#"):
		# a value's breakdown: 계수 × 공격력 (× 회복량) = 최종
		var ck := term.substr(1)
		var V := value_of(ck)
		var heal := HEALS.has(ck)
		var title := ("회복 " if heal else "피해 ") + value_text(ck)
		var desc := "계수 %d%% × 공격력 %s" % [V[1], ("%.1f" % V[2])]
		if heal: desc += " × 회복량 +%d%%" % roundi(V[3])
		desc += " = %s\n공격력 = 10 × 기본 공격 × 레벨 성장 × 장비. 실제 피해는 여기에 속성 · 룬 · 노드 · 치명 · 적의 상태가 더해진다." % value_text(ck)
		if heal: desc = desc.replace("실제 피해는 여기에 속성 · 룬 · 노드 · 치명 · 적의 상태가 더해진다.", "회복량은 장비 · 노드로 오른다.")
		G = {title: [Color("#5aa0ff"), desc]}
		term = title
	if not G.has(term): return Rect2()
	var w := minf(300.0, vs.x - 24.0)
	var tw := w - 28.0
	var dh := height(font, String(G[term][1]), tw, 13)
	var h := 16.0 + 24.0 + 8.0 + dh + 16.0
	var r := Rect2(clampf(p.x - w * 0.5, 12.0, vs.x - 12.0 - w), p.y + 18.0, w, h)
	if r.end.y > vs.y - 10.0: r.position.y = maxf(10.0, p.y - 18.0 - h)
	var kc: Color = G[term][0]
	var pts := PackedVector2Array([r.position + Vector2(6, 0), Vector2(r.end.x, r.position.y), r.end - Vector2(6, 0), Vector2(r.position.x, r.end.y)])
	ci.draw_colored_polygon(pts, Color(0.06, 0.05, 0.09, 0.96 * a))
	ci.draw_rect(Rect2(r.position + Vector2(6, 0), Vector2(r.size.x - 6.0, 3.0)), Color(kc, a))
	ci.draw_string(title_font, r.position + Vector2(16, 16.0 + title_font.get_ascent(18)), term, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(kc, a))
	draw(ci, font, r.position + Vector2(16, 16.0 + 24.0 + 6.0), String(G[term][1]), tw, 13, Color(0.92, 0.92, 0.95), a, Callable(), false)
	return r
