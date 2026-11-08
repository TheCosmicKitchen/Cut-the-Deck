## A card printed as one of the six publications. Header, cost, picture and text
## all follow the publication; chunks pasted in from other cards keep their own.
class_name PubCard
extends Control

const PAPER := preload("res://shaders/pub_paper.gdshader")
const PHOTO := preload("res://shaders/pub_photo.gdshader")
const SZ := Vector2(272, 404)
const ART_Y := 78.0
const ART_H := 112.0
const TEXT_Y := 208.0
const TEXT_Y_FULL := 238.0

var db: Dictionary
var card: Dictionary
var pub := Pub.NEWS
var _content: VBoxContainer
var _deco: Control


var opts := {}
var full := true   # art fills the card and the text sits over it


## opts.collage: [[scene, pub], ...] makes the picture a collage of torn strips
## from several publications' pictures.
func setup(p_db: Dictionary, p_card: Dictionary, p_opts := {}) -> PubCard:
	db = p_db
	card = p_card
	opts = p_opts
	full = opts.get("full_art", true)
	pub = Pub.of_card(card)
	size = SZ
	custom_minimum_size = SZ
	mouse_filter = MOUSE_FILTER_IGNORE
	_build()
	return self


func _seed() -> float:
	return float(abs(hash(card.get("uid", "") + card.name)) % 113)


func main_verb() -> String:
	for cl in card.clauses:
		if cl.verb and Grammar.trigger_of(cl) == "played":
			return cl.verb.id
	for cl in card.clauses:
		if cl.verb:
			return cl.verb.id
	return "ui"


func _build() -> void:
	var m := 14.0
	var sheet := ColorRect.new()
	sheet.mouse_filter = MOUSE_FILTER_IGNORE
	sheet.position = Vector2(-m, -m)
	sheet.size = SZ + Vector2(2 * m, 2 * m)
	var mat := ShaderMaterial.new()
	mat.shader = PAPER
	mat.set_shader_parameter("rect_size", sheet.size)
	mat.set_shader_parameter("margin", m)
	mat.set_shader_parameter("pub", pub)
	mat.set_shader_parameter("mode", 0)
	mat.set_shader_parameter("seed", _seed())
	sheet.material = mat
	add_child(sheet)

	if full:
		_picture_full()
	_deco = Control.new()
	_deco.mouse_filter = MOUSE_FILTER_IGNORE
	_deco.size = SZ
	_deco.draw.connect(_draw_deco)
	add_child(_deco)
	if not full:
		_picture()
	call("_head_%d" % pub)

	_content = VBoxContainer.new()
	_content.mouse_filter = MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", 0)
	_content.position = Vector2(_text_x(), (TEXT_Y_FULL + {Pub.COMIC: 14.0, Pub.ALMANAC: 6.0}.get(pub, 0.0)) if full else TEXT_Y + (12.0 if pub == Pub.COMIC else 0.0))
	_content.size = Vector2(SZ.x - _text_x() - (18.0 if pub == Pub.COMIC else 14.0), 0)
	add_child(_content)
	for i in card.clauses.size():
		_content.add_child(_clause(card.clauses[i], i))
	_fit.call_deferred()


func _text_x() -> float:
	return {Pub.MANUAL: 40.0, Pub.COMIC: 18.0}.get(pub, 14.0)


func cost_text() -> String:
	var cost = Grammar.card_cost(db, card)
	if cost == null or not Grammar.is_playable(card):
		return "–"
	return str(cost.cost) + ("+X" if cost.x else "")


# ---------- picture ----------

func _picture_full() -> void:
	var box := Control.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.position = Vector2(6, 6)
	box.size = SZ - Vector2(12, 12)
	box.clip_contents = true
	add_child(box)
	var pic := TextureRect.new()
	pic.mouse_filter = MOUSE_FILTER_IGNORE
	pic.size = box.size
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	var pm := ShaderMaterial.new()
	pm.shader = PHOTO
	pm.set_shader_parameter("pub", pub)
	pm.set_shader_parameter("rect_size", box.size)
	pm.set_shader_parameter("accent", Pub.RISO)
	pic.material = pm
	box.add_child(pic)
	var art_style: String = ["photo", "ink", "silhouette", "xerox", "line", "woodcut"][pub]
	Illo.texture(Engine.get_main_loop(), Illo.PUB_FULL[pub], Look.THEME.get(main_verb(), Look.THEME.ui), box.size,
		func(tex): if is_instance_valid(pic): pic.texture = tex, art_style)


func _picture() -> void:
	var box := Control.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.position = Vector2(16, ART_Y)
	box.size = Vector2(SZ.x - 32, ART_H)
	box.clip_contents = true
	add_child(box)
	var pic := TextureRect.new()
	pic.mouse_filter = MOUSE_FILTER_IGNORE
	pic.size = box.size
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	var pm := ShaderMaterial.new()
	pm.shader = PHOTO
	pm.set_shader_parameter("pub", pub)
	pm.set_shader_parameter("rect_size", box.size)
	pm.set_shader_parameter("accent", Pub.RISO)
	pic.material = pm
	box.add_child(pic)
	var verb := main_verb()
	if opts.has("collage"):
		pic.queue_free()
		_collage(box, opts.collage)
		return
	var art_style: String = ["photo", "ink", "silhouette", "xerox", "line", "woodcut"][pub]
	var scene: String = card.get("art", Illo.PUB_SCENES.get(card.get("base", ""), Illo.scene_for(card, verb)))
	Illo.texture(Engine.get_main_loop(), scene, Look.THEME.get(verb, Look.THEME.ui), box.size,
		func(tex): if is_instance_valid(pic): pic.texture = tex, art_style)
	if pub == Pub.ZINE:
		box.rotation = deg_to_rad(-1.2)
	if pub == Pub.PULP:
		box.position = Vector2(6, ART_Y - 6)
		box.size = Vector2(SZ.x - 12, ART_H + 16)
		pic.size = box.size
		pm.set_shader_parameter("rect_size", box.size)


## Torn vertical strips, each from a different publication's picture.
func _collage(box: Control, parts: Array) -> void:
	var n := parts.size()
	var w := box.size.x / n
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cuts := [-6.0]
	for i in range(1, n):
		cuts.append(w * i + rng.randf_range(-6, 6))
	cuts.append(box.size.x + 6)
	for i in n:
		var scene: String = parts[i][0]
		var p: int = parts[i][1]
		var poly := Polygon2D.new()
		var pts := PackedVector2Array()
		var steps := 10
		# left edge down, right edge up, both torn and slanted
		for k in steps + 1:
			var y := -4.0 + (box.size.y + 8) * k / steps
			pts.append(Vector2(cuts[i] + rng.randf_range(-2.0, 2.0) + (y - box.size.y * 0.5) * 0.06, y))
		for k in range(steps, -1, -1):
			var y := -4.0 + (box.size.y + 8) * k / steps
			pts.append(Vector2(cuts[i + 1] + rng.randf_range(-2.0, 2.0) + (y - box.size.y * 0.5) * 0.06, y))
		var shadow := Polygon2D.new()
		shadow.polygon = pts
		shadow.color = Color(0, 0, 0, 0.35)
		shadow.position = Vector2(2, 2)
		box.add_child(shadow)
		poly.polygon = pts
		var uv := PackedVector2Array()
		for q in pts:
			uv.append(q * 2.0)
		poly.uv = uv
		var pm := ShaderMaterial.new()
		pm.shader = PHOTO
		pm.set_shader_parameter("pub", p)
		pm.set_shader_parameter("rect_size", box.size)
		pm.set_shader_parameter("accent", Pub.RISO)
		poly.material = pm
		box.add_child(poly)
		var st: String = ["photo", "ink", "silhouette", "xerox", "line", "woodcut"][p]
		Illo.texture(Engine.get_main_loop(), scene, Look.THEME.deal, box.size,
			func(tex): if is_instance_valid(poly): poly.texture = tex, st)


# ---------- headers ----------

func _name_label(fname: String, size: int, col: Color, upper := false, maxw := 0.0) -> Label:
	var t: String = card.name.to_upper() if upper else card.name
	var f := Pub.font(fname)
	var w := maxw if maxw > 0.0 else SZ.x - 40.0
	while size > 12 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w:
		size -= 1
	return Pub.label(t, fname, size, col)


func _head_0() -> void:  # newspaper
	var mast := Pub.label("The Daily Cut", "fraktur", 21, Pub.INK)
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mast.position = Vector2(14, 6)
	mast.size = Vector2(SZ.x - 28, 26)
	add_child(mast)
	var date := Pub.label("VOL. I  ·  LATE EDITION", "oswald-400", 9, Color(Pub.INK, 0.8))
	date.position = Vector2(18, 34)
	add_child(date)
	var price := Pub.label("PRICE %s¢" % cost_text(), "oswald-600", 10, Pub.INK)
	price.position = Vector2(SZ.x - 18 - 64, 34)
	price.size = Vector2(64, 14)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(price)
	var head := _name_label("playfair-900", 25, Pub.INK, true, SZ.x - 32)
	head.position = Vector2(16, 47)
	add_child(head)
	if not full:
		var cap := Pub.label("Onlookers gather as the swing goes wide.", "playfair-400i", 10, Color(Pub.INK, 0.75))
		cap.position = Vector2(16, ART_Y + ART_H + 1)
		add_child(cap)
	var credit := Pub.label("DAILY CUT WIRE PHOTO", "oswald-400", 7, Color(Pub.INK, 0.6) if not full else Color(1, 1, 1, 0.8))
	credit.position = Vector2(SZ.x - 13, ART_Y + 6)
	credit.rotation = PI * 0.5
	add_child(credit)
	var by := Pub.label("By a Staff Reporter", "oswald-400", 8, Color(Pub.INK, 0.7) if not full else Color(1, 1, 1, 0.75))
	by.position = Vector2(SZ.x - 30 - 90, SZ.y - 48)
	by.size = Vector2(90, 10)
	by.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(by)
	var cont := Pub.label("Continued on A4 ▸", "playfair-400i", 9, Color(Pub.INK, 0.7) if not full else Color(1, 1, 1, 0.75))
	cont.position = Vector2(SZ.x - 30 - 110, SZ.y - 26)
	cont.size = Vector2(110, 12)
	cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(cont)


func _head_1() -> void:  # comics: a cover logo, issue box, panels
	var t: String = card.name.to_upper()
	var fs := 42
	while fs > 18 and Pub.font("bangers").get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > SZ.x - 110:
		fs -= 1
	var logo := Pub.extruded(t, "bangers", fs, Color("#ffe14d"), Color("#e3262f"), Pub.INK, 4, 6)
	logo.position = Vector2(20, 14)
	logo.rotation = deg_to_rad(-4)
	add_child(logo)
	var c := Pub.label(cost_text(), "bangers", 32, Pub.INK)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.position = Vector2(SZ.x - 66, 18)
	c.size = Vector2(46, 34)
	add_child(c)
	var ec := Pub.label("ENERGY", "bangers", 11, Pub.INK)
	ec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ec.position = Vector2(SZ.x - 66, 50)
	ec.size = Vector2(46, 12)
	add_child(ec)
	var issue := Pub.label("No.1", "bangers", 12, Color.WHITE)
	issue.position = Vector2(SZ.x - 59, 6)
	add_child(issue)
	if false:
		var sfx := Pub.extruded("POW!", "bangers", 26, Color("#ffe14d"), Color("#e3262f"), Pub.INK, 2, 5)
		sfx.position = Vector2(SZ.x - 92, ART_Y + 6)
		sfx.rotation = deg_to_rad(12)
		add_child(sfx)


func _head_2() -> void:  # pulp horror: a painted magazine cover
	var strip := Pub.label("W E I R D   P A P E R   T A L E S", "anton", 12, Color("#fff1c9"))
	strip.position = Vector2(20, 13)
	add_child(strip)
	var t: String = card.name.to_upper()
	var fs := 40
	while fs > 18 and Pub.font("anton").get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > SZ.x - 40:
		fs -= 1
	var title := Pub.extruded(t, "anton", fs, Color("#ffd23c"), Color("#8a1010"), Color("#12020a"), 5, 5)
	title.position = Vector2(18, 30)
	title.rotation = deg_to_rad(-3.5)
	add_child(title)
	var c := Pub.label(cost_text() + "¢", "anton", 20, Color("#2a0a18"))
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.position = Vector2(SZ.x - 58, 6)
	c.size = Vector2(44, 44)
	c.rotation = deg_to_rad(8)
	c.pivot_offset = c.size * 0.5
	add_child(c)
	var author := Pub.label("by H. P. Scrivener", "playfair-400i", 11, Color("#ffe6a0"))
	author.position = Vector2(22, ART_Y - 6)
	add_child(author)
	var blurb := Pub.label("COMPLETE NOVEL INSIDE!", "anton", 12, Color("#12020a"))
	blurb.position = Vector2(SZ.x - 168, SZ.y - 30)
	blurb.rotation = deg_to_rad(-2)
	add_child(blurb)


func _head_3() -> void:  # zine: a ransom-note title, each letter cut from somewhere else
	var fonts := ["playfair-900", "bangers", "special-elite", "oswald-600", "marker", "fell", "creepster"]
	var x := 20.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(card.name)
	var cols := [[Color.WHITE, Pub.INK], [Pub.INK, Color.WHITE], [Pub.RISO, Color.WHITE], [Color("#f4e04d"), Pub.INK], [Color.WHITE, Pub.RISO]]
	for ch in card.name:
		if ch == " ":
			x += 8
			continue
		var fn: String = fonts[rng.randi() % fonts.size()]
		var cc: Array = cols[rng.randi() % cols.size()]
		var fs := rng.randi_range(19, 25)
		var l := Pub.label(ch.to_upper() if rng.randf() < 0.6 else ch, fn, fs, cc[1])
		var w := Pub.font(fn).get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bit := ColorRect.new()
		bit.mouse_filter = MOUSE_FILTER_IGNORE
		bit.color = cc[0]
		bit.size = Vector2(w + 6, Pub.font(fn).get_height(fs) + 2)
		bit.position = Vector2(x, 26 + rng.randf_range(-4, 4))
		bit.rotation = deg_to_rad(rng.randf_range(-7, 7))
		add_child(bit)
		l.position = Vector2(3, 0)
		bit.add_child(l)
		x += w + 7
		if x > SZ.x - 90:
			break
	var ct := cost_text()
	var c := Pub.label(ct, "marker", 30 if ct.length() == 1 else 19, Pub.RISO)
	c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.position = Vector2(SZ.x - 62, 16)
	c.size = Vector2(44, 44)
	add_child(c)
	var issue := Pub.label("issue #1 · photocopied · free", "special-elite", 10, Color(Pub.INK, 0.7))
	issue.position = Vector2(22, 60)
	add_child(issue)


func _head_4() -> void:  # instruction manual: flat-pack, nearly wordless
	var t := Pub.label(flatpack_name(card.name), "hd/nunito-800", 30, Color("#111111"))
	var fs := 30
	while fs > 16 and Pub.font("hd/nunito-800").get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > SZ.x - 100:
		fs -= 1
	t.add_theme_font_size_override("font_size", fs)
	t.position = Vector2(18, 14)
	add_child(t)
	var c := Pub.label("%s×" % cost_text(), "hd/nunito-800", 20, Color("#111111"))
	c.position = Vector2(SZ.x - 52, 50)
	add_child(c)
	var pn := Pub.label("AA-%d-%d" % [int(_seed()) * 37 % 9000 + 1000, int(_seed()) % 9 + 1], "hd/nunito-600", 9, Color("#555555"))
	pn.position = Vector2(19, 52)
	add_child(pn)


## IKEA-style product names: upper case, with a ring or dots on a vowel.
static func flatpack_name(n: String) -> String:
	var t := n.to_upper().replace(" ", "")
	for pair in [["A", "Å"], ["O", "Ö"], ["U", "Ü"], ["E", "Ä"]]:
		var i := t.find(pair[0])
		if i > 0:
			return t.substr(0, i) + pair[1] + t.substr(i + 1)
	return t


func _head_5() -> void:  # almanac
	var top := Pub.label("OLD PIP'S ALMANACK  ·  MDCCCXII", "fell-sc", 11, Color(Pub.BROWN, 0.85))
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.position = Vector2(14, 14)
	top.size = Vector2(SZ.x - 28, 14)
	add_child(top)
	var t := _name_label("fell", 27, Pub.BROWN, false, SZ.x - 90)
	t.position = Vector2(22, 32)
	add_child(t)
	var c := Pub.label(cost_text(), "fell", 22, Pub.BROWN)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.position = Vector2(SZ.x - 62, 30)
	c.size = Vector2(36, 36)
	add_child(c)


# ---------- drawn decoration ----------

## Full-art cards: what sits over the picture so the text stays readable.
func _draw_full() -> void:
	var c := _deco
	match pub:
		Pub.NEWS:
			c.draw_rect(Rect2(0, 0, SZ.x, 80), Color(0.925, 0.902, 0.835))
			c.draw_line(Vector2(16, 32), Vector2(SZ.x - 16, 32), Pub.INK, 1.5)
			c.draw_line(Vector2(16, 35), Vector2(SZ.x - 16, 35), Pub.INK, 0.8)
			c.draw_line(Vector2(16, 47), Vector2(SZ.x - 16, 47), Pub.INK, 0.8)
			c.draw_line(Vector2(0, 80), Vector2(SZ.x, 80), Pub.INK, 1.2)
			for i in 30:
				var y := 196.0 + i * 7.0
				c.draw_rect(Rect2(6, y, SZ.x - 12, 7), Color(0.05, 0.05, 0.06, clampf(i / 14.0, 0.0, 1.0) * 0.82))
		Pub.COMIC:
			c.draw_rect(Rect2(6, 6, SZ.x - 12, 64), Color("#2f6fe4"))
			for y in range(10, 68, 6):
				for x in range(10 + (y / 6 % 2) * 3, int(SZ.x) - 8, 6):
					c.draw_circle(Vector2(x, y), 1.3, Color("#1f4fb4"))
			c.draw_line(Vector2(6, 70), Vector2(SZ.x - 6, 70), Pub.INK, 3.0)
			c.draw_rect(Rect2(SZ.x - 68, 6, 50, 60), Color.WHITE)
			c.draw_rect(Rect2(SZ.x - 68, 6, 50, 14), Color("#e3262f"))
			c.draw_rect(Rect2(SZ.x - 68, 6, 50, 60), Pub.INK, false, 2.5)
			var sb := StyleBoxFlat.new()
			sb.draw_center = false
			sb.border_color = Pub.INK
			sb.set_border_width_all(4)
			sb.set_corner_radius_all(3)
			sb.anti_aliasing = true
			c.draw_style_box(sb, Rect2(Vector2(4, 4), SZ - Vector2(8, 8)))
		Pub.PULP:
			for i in 26:
				var y := 210.0 + i * 7.0
				c.draw_rect(Rect2(6, y, SZ.x - 12, 7), Color(0.08, 0.0, 0.06, clampf(i / 12.0, 0.0, 1.0) * 0.55))
			c.draw_rect(Rect2(12, 10, SZ.x - 76, 20), Color("#c4161c"))
			c.draw_circle(Vector2(SZ.x - 36, 28), 22, Color("#ffd23c"), true, -1.0, true)
			c.draw_circle(Vector2(SZ.x - 36, 28), 22, Color("#12020a"), false, 2.0, true)
			var rib := PackedVector2Array([Vector2(SZ.x - 176, SZ.y - 34), Vector2(SZ.x - 14, SZ.y - 40), Vector2(SZ.x - 12, SZ.y - 16), Vector2(SZ.x - 174, SZ.y - 12)])
			c.draw_colored_polygon(rib, Color("#ffd23c"))
		Pub.ZINE:
			for y in [60.0, SZ.y - 60.0]:
				c.draw_line(Vector2(8, y - 9), Vector2(8, y + 9), Color("#8a8f99"), 2.5, true)
			var pts := PackedVector2Array()
			for i in 26:
				var a := i * TAU / 24.0 - 0.4
				var r := 24.0 + sin(i * 1.7) * 1.5 + i * 0.12
				pts.append(Vector2(SZ.x - 40, 38) + Vector2(cos(a) * r, sin(a) * r * 0.86))
			c.draw_colored_polygon(pts, Color(0.96, 0.955, 0.945))
			c.draw_polyline(pts, Pub.RISO, 2.5, true)
		Pub.MANUAL:
			var hk := Vector2(SZ.x - 62, 30)
			c.draw_polyline(PackedVector2Array([hk + Vector2(0, 20), hk, hk + Vector2(34, -6)]), Color("#111111"), 3.0, true)
			c.draw_line(Vector2(16, 70), Vector2(SZ.x - 16, 70), Color("#111111"), 1.0)
			var px := 18.0
			for i in card.clauses.size():
				var r := Rect2(px, SZ.y - 34, 46, 22)
				c.draw_rect(r, Color.WHITE)
				c.draw_rect(r, Color("#111111"), false, 1.0)
				c.draw_circle(r.position + Vector2(12, 11), 5, Color("#111111"), false, 1.2, true)
				c.draw_line(r.position + Vector2(9, 11), r.position + Vector2(15, 11), Color("#111111"), 1.2)
				c.draw_string(Pub.font("hd/nunito-800"), r.position + Vector2(22, 16), "1×", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#111111"))
				px += 52
		Pub.ALMANAC:
			var paper := Color(0.94, 0.87, 0.71)
			# title banner and the text panel, both on the almanac's paper
			c.draw_rect(Rect2(14, 10, SZ.x - 28, 64), paper)
			c.draw_rect(Rect2(14, 10, SZ.x - 28, 64), Pub.BROWN, false, 1.2)
			c.draw_rect(Rect2(17, 13, SZ.x - 34, 58), Color(Pub.BROWN, 0.6), false, 0.6)
			var tp := Rect2(14, 228, SZ.x - 28, SZ.y - 242)
			c.draw_rect(tp, paper)
			c.draw_rect(tp, Pub.BROWN, false, 1.2)
			c.draw_rect(tp.grow(-3), Color(Pub.BROWN, 0.6), false, 0.6)
			c.draw_rect(Rect2(8, 8, SZ.x - 16, SZ.y - 16), Color(Pub.BROWN, 0.8), false, 1.6)
			for p in [Vector2(8, 8), Vector2(SZ.x - 8, 8), Vector2(8, SZ.y - 8), Vector2(SZ.x - 8, SZ.y - 8)]:
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), Pub.BROWN)
			var mc := Vector2(SZ.x - 44, 48)
			c.draw_circle(mc, 17, Color("#f6ecd2"), true, -1.0, true)
			c.draw_circle(mc + Vector2(7, 0), 15, Color(Pub.BROWN, 0.18), true, -1.0, true)
			c.draw_circle(mc, 17, Pub.BROWN, false, 1.2, true)


func _draw_deco() -> void:
	if full:
		_draw_full()
		return
	var c := _deco
	var art := Rect2(16, ART_Y, SZ.x - 32, ART_H)
	match pub:
		Pub.NEWS:
			c.draw_line(Vector2(16, 32), Vector2(SZ.x - 16, 32), Pub.INK, 1.5)
			c.draw_line(Vector2(16, 35), Vector2(SZ.x - 16, 35), Pub.INK, 0.8)
			c.draw_line(Vector2(16, 47), Vector2(SZ.x - 16, 47), Pub.INK, 0.8)
			c.draw_rect(art, Pub.INK, false, 1.0)
			c.draw_line(Vector2(16, TEXT_Y - 4), Vector2(SZ.x - 16, TEXT_Y - 4), Color(Pub.INK, 0.5), 0.8)
			# filler columns of tiny grey "text" at the foot
			for col in 3:
				var x0 := 16.0 + col * ((SZ.x - 32) / 3.0)
				for i in 4:
					c.draw_line(Vector2(x0 + 2, SZ.y - 40 + i * 6), Vector2(x0 + (SZ.x - 32) / 3.0 - 6 - (8 if i == 3 else 0), SZ.y - 40 + i * 6), Color(Pub.INK, 0.15), 2.0)
		Pub.COMIC:
			# cover band behind the logo, with darker dots
			c.draw_rect(Rect2(6, 6, SZ.x - 12, 64), Color("#2f6fe4"))
			for y in range(10, 68, 6):
				for x in range(10 + (y / 6 % 2) * 3, int(SZ.x) - 8, 6):
					c.draw_circle(Vector2(x, y), 1.3, Color("#1f4fb4"))
			# issue box
			c.draw_rect(Rect2(SZ.x - 68, 6, 50, 60), Color.WHITE)
			c.draw_rect(Rect2(SZ.x - 68, 6, 50, 14), Color("#e3262f"))
			c.draw_rect(Rect2(SZ.x - 68, 6, 50, 60), Pub.INK, false, 2.5)
			# panels with gutters
			c.draw_rect(art.grow(2), Pub.INK, false, 3.5)
			var tp := Rect2(12, TEXT_Y - 4, SZ.x - 24, SZ.y - TEXT_Y - 6)
			c.draw_rect(tp, Color.WHITE)
			c.draw_rect(tp, Pub.INK, false, 3.5)
			# a narration caption in the panel corner
			c.draw_rect(Rect2(tp.position + Vector2(-2, -2), Vector2(96, 18)), Color("#ffe14d"))
			c.draw_rect(Rect2(tp.position + Vector2(-2, -2), Vector2(96, 18)), Pub.INK, false, 2.0)
			c.draw_string(Pub.font("comic-neue-700"), tp.position + Vector2(4, 11), "MEANWHILE...", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pub.INK)
			# the page's outer ink border
			var sb := StyleBoxFlat.new()
			sb.draw_center = false
			sb.border_color = Pub.INK
			sb.set_border_width_all(4)
			sb.set_corner_radius_all(3)
			sb.anti_aliasing = true
			c.draw_style_box(sb, Rect2(Vector2(4, 4), SZ - Vector2(8, 8)))
		Pub.PULP:
			c.draw_rect(Rect2(12, 10, SZ.x - 76, 20), Color("#c4161c"))
			c.draw_circle(Vector2(SZ.x - 36, 28), 22, Color("#ffd23c"), true, -1.0, true)
			c.draw_circle(Vector2(SZ.x - 36, 28), 22, Color("#12020a"), false, 2.0, true)
			var rib := PackedVector2Array([Vector2(SZ.x - 176, SZ.y - 34), Vector2(SZ.x - 14, SZ.y - 40), Vector2(SZ.x - 12, SZ.y - 16), Vector2(SZ.x - 174, SZ.y - 12)])
			c.draw_colored_polygon(rib, Color("#ffd23c"))
		Pub.ZINE:
			# staples down the left
			for y in [60.0, SZ.y - 60.0]:
				c.draw_line(Vector2(8, y - 9), Vector2(8, y + 9), Color("#8a8f99"), 2.5, true)
			# hand-drawn circle round the cost
			var pts := PackedVector2Array()
			for i in 26:
				var a := i * TAU / 24.0 - 0.4
				var r := 24.0 + sin(i * 1.7) * 1.5 + i * 0.12
				pts.append(Vector2(SZ.x - 40, 38) + Vector2(cos(a) * r, sin(a) * r * 0.86))
			c.draw_polyline(pts, Pub.RISO, 2.5, true)
			# a strip of tape holding the photo
			var tp := Transform2D(0.25, Vector2(SZ.x * 0.5, ART_Y - 2))
			var tq := PackedVector2Array()
			for v in [Vector2(-26, -7), Vector2(26, -7), Vector2(26, 7), Vector2(-26, 7)]:
				tq.append(tp * v)
			c.draw_colored_polygon(tq, Color(1, 1, 0.92, 0.6))
		Pub.MANUAL:
			# the hex key that comes in every box, beside the energy count
			var hk := Vector2(SZ.x - 62, 30)
			c.draw_polyline(PackedVector2Array([hk + Vector2(0, 20), hk, hk + Vector2(34, -6)]), Color("#111111"), 3.0, true)
			c.draw_line(Vector2(16, 70), Vector2(SZ.x - 16, 70), Color("#111111"), 1.0)
			# a little worried assembler in the corner of the picture
			var g := Vector2(SZ.x - 34, ART_Y + ART_H - 8)
			c.draw_circle(g + Vector2(0, -30), 5, Color.WHITE, true, -1.0, true)
			c.draw_circle(g + Vector2(0, -30), 5, Color("#111111"), false, 1.4, true)
			c.draw_line(g + Vector2(0, -25), g + Vector2(0, -10), Color("#111111"), 1.4, true)
			c.draw_line(g + Vector2(0, -10), g + Vector2(-5, 0), Color("#111111"), 1.4, true)
			c.draw_line(g + Vector2(0, -10), g + Vector2(5, 0), Color("#111111"), 1.4, true)
			c.draw_line(g + Vector2(0, -21), g + Vector2(-7, -15), Color("#111111"), 1.4, true)
			c.draw_line(g + Vector2(0, -21), g + Vector2(7, -26), Color("#111111"), 1.4, true)
			c.draw_string(Pub.font("hd/nunito-800"), g + Vector2(8, -34), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#111111"))
			# parts strip at the foot: one box per clause, "1×" each
			var px := 18.0
			for i in card.clauses.size():
				var r := Rect2(px, SZ.y - 34, 46, 22)
				c.draw_rect(r, Color("#111111"), false, 1.0)
				c.draw_circle(r.position + Vector2(12, 11), 5, Color("#111111"), false, 1.2, true)
				c.draw_line(r.position + Vector2(9, 11), r.position + Vector2(15, 11), Color("#111111"), 1.2)
				c.draw_string(Pub.font("hd/nunito-800"), r.position + Vector2(22, 16), "1×", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#111111"))
				px += 52
		Pub.ALMANAC:
			c.draw_rect(Rect2(10, 10, SZ.x - 20, SZ.y - 20), Color(Pub.BROWN, 0.8), false, 1.6)
			c.draw_rect(Rect2(14, 14, SZ.x - 28, SZ.y - 28), Color(Pub.BROWN, 0.6), false, 0.8)
			for p in [Vector2(10, 10), Vector2(SZ.x - 10, 10), Vector2(10, SZ.y - 10), Vector2(SZ.x - 10, SZ.y - 10)]:
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), Pub.BROWN)
			c.draw_rect(art.grow(3), Color(Pub.BROWN, 0.8), false, 1.0)
			c.draw_rect(art.grow(1), Color(Pub.BROWN, 0.9), false, 1.4)
			# moon phase behind the cost
			var mc := Vector2(SZ.x - 44, 48)
			c.draw_circle(mc, 17, Color("#f6ecd2"), true, -1.0, true)
			c.draw_circle(mc + Vector2(7, 0), 15, Color(Pub.BROWN, 0.18), true, -1.0, true)
			c.draw_circle(mc, 17, Pub.BROWN, false, 1.2, true)


# ---------- text ----------

func _clause(clause: Dictionary, ci: int) -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", -8)
	var holes: Array = clause.get("holes", [])
	var lead := []
	var cond := []
	var rest := []
	var mw: float = _content.size.x + 10
	for slot in Grammar.SLOTS:
		var ch = clause[slot]
		var show: bool = ch != null or Grammar.REQUIRED.has(slot) or holes.has(slot)
		if not show:
			continue
		var text: String = Grammar.chunk_label(db, ch).trim_suffix(":") if ch else _hole_text(slot, card)
		var src := Pub.of_chunk(ch, card) if ch else pub
		var cv := PubChunk.new().setup(slot, ch, text, src, pub,
			{"light": full and pub == Pub.NEWS, "max_w": mw - (30.0 if clause.condition and slot != "condition" else 0.0), "uid": card.uid + str(ci)})
		if slot == "trigger":
			lead.append(cv)
		elif slot == "condition" and (ch != null or holes.has(slot)):
			cond.append(cv)
		else:
			rest.append(cv)
	if not lead.is_empty():
		box.add_child(_flow(lead))
	if cond.is_empty():
		box.add_child(_flow(rest))
	else:
		box.add_child(_flow(cond))
		var row := HBoxContainer.new()
		row.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", -4)
		var arrow := IndentArrow.new()
		arrow.col = Color("#f6f1e4") if (full and pub == Pub.NEWS) else Pub.ink(pub, "condition")
		arrow.custom_minimum_size = Vector2(30, 34)
		row.add_child(arrow)
		var f := _flow(rest)
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(f)
		box.add_child(row)
	if pub == Pub.MANUAL:
		# a numbered step badge beside each clause
		var wrap := HBoxContainer.new()
		wrap.mouse_filter = MOUSE_FILTER_IGNORE
		wrap.add_theme_constant_override("separation", 2)
		var badge := Control.new()
		badge.custom_minimum_size = Vector2(0, 0)
		badge.mouse_filter = MOUSE_FILTER_IGNORE
		var n := ci + 1
		badge.draw.connect(func():
			badge.draw_string(Pub.font("hd/nunito-800"), Vector2(-26, 32), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#111111")))
		wrap.add_child(badge)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.add_child(box)
		return wrap
	return box


func _hole_text(slot: String, c: Dictionary) -> String:
	# a hole is about as wide as a typical word for that slot
	return {"verb": "Deal", "amount": "9", "repeat": "twice", "target": "to an enemy", "condition": "if this is your first card", "trigger": "When drawn"}.get(slot, slot)


func _flow(items: Array) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.mouse_filter = MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", -8)
	flow.add_theme_constant_override("v_separation", -9)
	for it in items:
		flow.add_child(it)
	return flow


func _fit() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_content):
		return
	var foot: float = {Pub.NEWS: 48.0, Pub.PULP: 44.0, Pub.COMIC: 28.0, Pub.MANUAL: 40.0, Pub.ALMANAC: 22.0}.get(pub, 16.0)
	var room: float = SZ.y - (TEXT_Y_FULL if full else TEXT_Y) - foot
	var h: float = _content.get_combined_minimum_size().y
	if h > room:
		var k: float = room / h
		_content.scale = Vector2(k, k)
		_content.size.x = (SZ.x - _text_x() - 14) / k
