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

var db: Dictionary
var card: Dictionary
var pub := Pub.NEWS
var _content: VBoxContainer
var _deco: Control


func setup(p_db: Dictionary, p_card: Dictionary) -> PubCard:
	db = p_db
	card = p_card
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

	_deco = Control.new()
	_deco.mouse_filter = MOUSE_FILTER_IGNORE
	_deco.size = SZ
	_deco.draw.connect(_draw_deco)
	add_child(_deco)

	_picture()
	call("_head_%d" % pub)

	_content = VBoxContainer.new()
	_content.mouse_filter = MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", 0)
	_content.position = Vector2(_text_x(), TEXT_Y + (10.0 if pub == Pub.COMIC else 0.0))
	_content.size = Vector2(SZ.x - _text_x() - (24.0 if pub == Pub.COMIC else 14.0), 0)
	add_child(_content)
	for i in card.clauses.size():
		_content.add_child(_clause(card.clauses[i], i))
	_fit.call_deferred()


func _text_x() -> float:
	return {Pub.MANUAL: 40.0, Pub.COMIC: 24.0}.get(pub, 14.0)


func cost_text() -> String:
	var cost = Grammar.card_cost(db, card)
	if cost == null or not Grammar.is_playable(card):
		return "–"
	return str(cost.cost) + ("+X" if cost.x else "")


# ---------- picture ----------

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
	Illo.texture(Engine.get_main_loop(), Illo.scene_for(card, verb), Look.THEME.get(verb, Look.THEME.ui), box.size,
		func(tex): if is_instance_valid(pic): pic.texture = tex)
	if pub == Pub.ZINE:
		box.rotation = deg_to_rad(-1.2)


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
	var cap := Pub.label("Pip, pictured yesterday afternoon.", "playfair-400i", 10, Color(Pub.INK, 0.75))
	cap.position = Vector2(16, ART_Y + ART_H + 1)
	add_child(cap)


func _head_1() -> void:  # comics
	var t := _name_label("bangers", 30, Pub.INK, true, SZ.x - 100)
	t.position = Vector2(26, 26)
	t.rotation = deg_to_rad(-3)
	add_child(t)
	var c := Pub.label(cost_text(), "bangers", 30, Color.WHITE)
	c.add_theme_constant_override("outline_size", 7)
	c.add_theme_color_override("font_outline_color", Pub.INK)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.position = Vector2(SZ.x - 72, 14)
	c.size = Vector2(52, 52)
	add_child(c)
	var issue := Pub.label("No. 1  ·  10¢", "bangers", 12, Pub.INK)
	issue.position = Vector2(30, 10)
	add_child(issue)


func _head_2() -> void:  # pulp horror
	var t := _name_label("creepster", 31, Pub.ACID, false, SZ.x - 84)
	t.add_theme_constant_override("outline_size", 6)
	t.add_theme_color_override("font_outline_color", Color("#1b0420"))
	t.position = Vector2(18, 22)
	add_child(t)
	var tag := Pub.label("a tale too terrible to tell", "playfair-400i", 11, Color("#f4d9a8"))
	tag.position = Vector2(20, 58)
	add_child(tag)
	var c := Pub.label(cost_text(), "playfair-900", 22, Color("#2a0a18"))
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.position = Vector2(SZ.x - 60, 14)
	c.size = Vector2(42, 42)
	add_child(c)


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


func _head_4() -> void:  # instruction manual
	var t := _name_label("oswald-600", 24, Pub.NAVY, true, SZ.x - 100)
	t.position = Vector2(18, 26)
	add_child(t)
	var model := Pub.label("MODEL %s-%02d" % [card.name.substr(0, 2).to_upper(), int(_seed()) % 90 + 10], "oswald-400", 10, Color(Pub.NAVY, 0.8))
	model.position = Vector2(19, 58)
	add_child(model)
	var c := Pub.label(cost_text(), "oswald-600", 26, Pub.NAVY)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.position = Vector2(SZ.x - 66, 14)
	c.size = Vector2(48, 36)
	add_child(c)
	var ec := Pub.label("ENERGY", "oswald-400", 8, Color(Pub.NAVY, 0.8))
	ec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ec.position = Vector2(SZ.x - 66, 48)
	ec.size = Vector2(48, 12)
	add_child(ec)
	var bar := Pub.label("ASSEMBLY INSTRUCTIONS", "oswald-600", 9, Color.WHITE)
	bar.position = Vector2(20, 4)
	add_child(bar)


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

func _draw_deco() -> void:
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
			var sb := StyleBoxFlat.new()
			sb.draw_center = false
			sb.border_color = Pub.INK
			sb.set_border_width_all(4)
			sb.set_corner_radius_all(6)
			sb.anti_aliasing = true
			c.draw_style_box(sb, Rect2(Vector2(4, 4), SZ - Vector2(8, 8)))
			# title caption box
			var cap := PackedVector2Array([Vector2(16, 20), Vector2(SZ.x - 86, 14), Vector2(SZ.x - 82, 64), Vector2(18, 68)])
			c.draw_colored_polygon(cap, Color("#ffe14d"))
			c.draw_polyline(cap + PackedVector2Array([cap[0]]), Pub.INK, 2.5, true)
			# cost starburst
			var burst := PackedVector2Array()
			var cc := Vector2(SZ.x - 46, 40)
			for i in 24:
				var r := 30.0 if i % 2 == 0 else 19.0
				var a := i * PI / 12.0
				burst.append(cc + Vector2(cos(a), sin(a)) * r)
			c.draw_colored_polygon(burst, Color("#ff4a3d"))
			c.draw_polyline(burst + PackedVector2Array([burst[0]]), Pub.INK, 2.0, true)
			# picture panel border and the speech balloon for the text
			c.draw_rect(art.grow(1), Pub.INK, false, 3.0)
			var bal := StyleBoxFlat.new()
			bal.bg_color = Color.WHITE
			bal.border_color = Pub.INK
			bal.set_border_width_all(3)
			bal.set_corner_radius_all(26)
			bal.anti_aliasing = true
			var br := Rect2(10, TEXT_Y - 6, SZ.x - 20, SZ.y - TEXT_Y - 6)
			c.draw_style_box(bal, br)
			var tail := PackedVector2Array([Vector2(60, br.position.y + 2), Vector2(72, ART_Y + ART_H - 18), Vector2(84, br.position.y + 2)])
			c.draw_colored_polygon(tail, Color.WHITE)
			c.draw_polyline(PackedVector2Array([tail[0], tail[1], tail[2]]), Pub.INK, 3.0, true)
		Pub.PULP:
			# the lurid cover band behind title and picture
			var cov := Rect2(8, 8, SZ.x - 16, ART_Y + ART_H + 6)
			var top := Color("#2b0a3d")
			var bot := Color("#7a1030")
			for i in 20:
				var r := Rect2(cov.position.x, cov.position.y + cov.size.y * i / 20.0, cov.size.x, cov.size.y / 20.0 + 1)
				c.draw_rect(r, top.lerp(bot, i / 19.0))
			# cracks in the cover
			for k in 3:
				var x := 30.0 + k * 90.0
				c.draw_polyline(PackedVector2Array([Vector2(x, 8), Vector2(x + 4, 18), Vector2(x - 2, 28), Vector2(x + 3, 40)]), Color(1, 0.9, 0.8, 0.25), 1.0, true)
			c.draw_circle(Vector2(SZ.x - 39, 35), 22, Color("#ffd23c"), true, -1.0, true)
			c.draw_circle(Vector2(SZ.x - 39, 35), 22, Color("#2a0a18"), false, 2.0, true)
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
			c.draw_rect(Rect2(14, 2, SZ.x - 28, 16), Pub.NAVY)
			c.draw_rect(Rect2(SZ.x - 68, 18, 52, 46), Pub.NAVY, false, 2.0)
			c.draw_rect(art, Color(Pub.NAVY, 0.6), false, 1.2)
			# fig. label
			c.draw_string(Pub.font("oswald-400"), Vector2(20, ART_Y + ART_H - 6), "FIG. 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pub.NAVY)
			# warning triangle at the foot
			var w := Vector2(SZ.x - 30, SZ.y - 26)
			var tri := PackedVector2Array([w + Vector2(0, -10), w + Vector2(10, 7), w + Vector2(-10, 7)])
			c.draw_colored_polygon(tri, Color("#ffd23c"))
			c.draw_polyline(tri + PackedVector2Array([tri[0]]), Pub.NAVY, 1.5, true)
			c.draw_string(Pub.font("oswald-600"), w + Vector2(-2.5, 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pub.NAVY)
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
			{"max_w": mw - (30.0 if clause.condition and slot != "condition" else 0.0), "uid": card.uid + str(ci)})
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
		arrow.col = Pub.ink(pub, "condition")
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
			badge.draw_circle(Vector2(-12, 21), 10, Pub.NAVY, true, -1.0, true)
			badge.draw_string(Pub.font("oswald-600"), Vector2(-16, 26.5), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE))
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
	var room := SZ.y - TEXT_Y - (48.0 if pub == Pub.NEWS else 16.0)
	var h: float = _content.get_combined_minimum_size().y
	if h > room:
		var k := room / h
		_content.scale = Vector2(k, k)
		_content.size.x = (SZ.x - _text_x() - 14) / k
