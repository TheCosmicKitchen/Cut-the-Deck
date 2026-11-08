## One chunk of card text in the paper world.
##   printed  words printed on this card, in this card's publication style
##   slip     cut from another publication: its own paper and type, stuck on the
##            way this card's publication sticks things (glue, tape, thread...)
##   hole     cut out: the desk shows through
class_name PubChunk
extends Control

const PAPER := preload("res://shaders/pub_paper.gdshader")
const CUT := preload("res://shaders/cut.gdshader")
const M := 7.0
const PAD := Vector2(6, 2)

var slot := "verb"
var chunk = null
var text := ""
var src := Pub.NEWS       # publication the words were printed in
var dest := Pub.NEWS      # publication of the card it sits on
var look := "printed"
var max_w := 220.0
var seed := 0.0
var _body: Control


func setup(p_slot: String, p_chunk, p_text: String, p_src: int, p_dest: int, opts := {}) -> PubChunk:
	slot = p_slot
	chunk = p_chunk
	text = p_text
	src = p_src
	dest = p_dest
	max_w = opts.get("max_w", 220.0)
	seed = float(abs(hash("%s%s%s" % [p_text, p_slot, opts.get("uid", "")])) % 997)
	if chunk == null:
		look = "hole"
	elif chunk.get("pasted", false):
		look = "slip"
	mouse_filter = MOUSE_FILTER_IGNORE
	_build()
	return self


func _style() -> Array:
	return Pub.body(src)


func _build() -> void:
	var st := _style()
	var fname: String = st[0]
	var fs: int = st[1]
	var shown := text.to_upper() if st[2] else text
	if src == Pub.MANUAL and slot == "repeat":
		# the manual counts things: twice is ×2
		shown = {"once": "×1", "twice": "×2", "thrice": "×3"}.get(chunk.id if chunk else "", shown)
	if look == "hole":
		# the hole is sized like the word that was there, in this card's own type
		st = Pub.body(dest)
		fname = st[0]
		fs = st[1]
		shown = text
	var f := Pub.font(fname)
	var tw: float = minf(f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, max_w - 2 * M - 2 * PAD.x)
	var lines := 1
	if f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > tw + 0.5:
		lines = 2
	var th: float = f.get_height(fs) * lines
	var inner := Vector2(ceil(tw) + 2 * PAD.x, ceil(th) + 2 * PAD.y)
	var sz := inner + Vector2(2 * M, 2 * M)
	size = sz
	custom_minimum_size = sz

	_body = Control.new()
	_body.mouse_filter = MOUSE_FILTER_IGNORE
	_body.size = sz
	_body.pivot_offset = sz * 0.5
	add_child(_body)

	if look == "slip":
		var bg := ColorRect.new()
		bg.mouse_filter = MOUSE_FILTER_IGNORE
		bg.size = sz
		var m := ShaderMaterial.new()
		m.shader = PAPER
		m.set_shader_parameter("rect_size", sz)
		m.set_shader_parameter("margin", M - 1.0)
		m.set_shader_parameter("pub", src)
		m.set_shader_parameter("mode", 1)
		m.set_shader_parameter("seed", seed)
		m.set_shader_parameter("glue", dest == Pub.NEWS)
		bg.material = m
		_body.add_child(bg)
		_body.rotation = deg_to_rad(((int(seed) % 7) - 3) * 0.9)
	elif look == "hole":
		var hole := ColorRect.new()
		hole.mouse_filter = MOUSE_FILTER_IGNORE
		hole.size = sz
		var m := ShaderMaterial.new()
		m.shader = CUT
		m.set_shader_parameter("rect_size", sz)
		m.set_shader_parameter("margin", M - 1.0)
		m.set_shader_parameter("mode", 2)
		m.set_shader_parameter("seed", seed)
		m.set_shader_parameter("hole_col", Color("#5a3820"))
		hole.material = m
		_body.add_child(hole)
		return

	var deco := Control.new()
	deco.mouse_filter = MOUSE_FILTER_IGNORE
	deco.size = sz
	deco.draw.connect(_draw_under.bind(deco, inner))
	_body.add_child(deco)

	if src == Pub.PULP:
		# lurid cover lettering: a hard drop shadow under an inked outline
		var sh := Pub.label(shown, fname, fs, Color("#12020a"))
		sh.add_theme_constant_override("outline_size", 5)
		sh.add_theme_color_override("font_outline_color", Color("#12020a"))
		sh.position = Vector2(M + PAD.x + 2, M + PAD.y + 1)
		_body.add_child(sh)
	var l := Pub.label(shown, fname, fs, Pub.ink(src, slot))
	if src == Pub.PULP:
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", Color("#3a0814"))
	l.position = Vector2(M + PAD.x, M + PAD.y - 1)
	l.size = Vector2(tw + 1, th)
	if lines > 1:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if src == Pub.COMIC:
		l.add_theme_constant_override("outline_size", 0)
	_body.add_child(l)

	if look == "slip":
		var top := Control.new()
		top.mouse_filter = MOUSE_FILTER_IGNORE
		top.size = sz
		top.draw.connect(_draw_attach.bind(top))
		_body.add_child(top)


## How each publication marks the type of a printed word.
func _draw_under(c: Control, inner: Vector2) -> void:
	var r := Rect2(Vector2(M, M), inner)
	var col: Color = ChunkView.INK.get(slot, Pub.INK)
	match src:
		Pub.NEWS:
			# a thin coloured rule under the word
			c.draw_line(Vector2(r.position.x + 4, r.end.y - 2), Vector2(r.end.x - 4, r.end.y - 2), col, 2.0, true)
		Pub.ZINE:
			# a marker highlight, a bit sloppy
			var hl := Color(col.lightened(0.35), 0.45)
			c.draw_colored_polygon(PackedVector2Array([r.position + Vector2(1, 6), Vector2(r.end.x, r.position.y + 4),
				r.end + Vector2(2, -3), Vector2(r.position.x - 1, r.end.y - 1)]), hl)
		Pub.MANUAL:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(col, 0.07)
			sb.border_color = Color(col, 0.75)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(3)
			sb.anti_aliasing = true
			c.draw_style_box(sb, r.grow(-1))
		Pub.ALMANAC:
			for x in range(int(r.position.x) + 4, int(r.end.x) - 3, 4):
				c.draw_circle(Vector2(x, r.end.y - 2), 0.8, Color(col, 0.7))
		Pub.PULP:
			c.draw_line(Vector2(r.position.x + 3, r.end.y - 3), Vector2(r.end.x - 3, r.end.y - 4), Color(col, 0.5), 1.4, true)
		Pub.COMIC:
			# a narration caption box: pastel fill by type, hard ink border
			var sb2 := StyleBoxFlat.new()
			sb2.bg_color = col.lightened(0.62)
			sb2.border_color = Pub.INK
			sb2.set_border_width_all(2)
			sb2.set_corner_radius_all(2)
			sb2.shadow_color = Pub.INK
			sb2.shadow_size = 0
			sb2.shadow_offset = Vector2(2, 2)
			sb2.anti_aliasing = true
			c.draw_rect(Rect2(r.position + Vector2(3, 3), r.size - Vector2(2, 2)), Pub.INK)
			c.draw_style_box(sb2, Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)))


## How the destination card's publication sticks a slip on.
func _draw_attach(c: Control) -> void:
	var sz := c.size
	var y0 := M
	var y1 := sz.y - M
	match dest:
		Pub.COMIC:
			# clear tape across the left end
			var t := Transform2D(-0.5, Vector2(M + 4, sz.y * 0.5))
			var pts := PackedVector2Array()
			for v in [Vector2(-6, -sz.y * 0.55), Vector2(6, -sz.y * 0.55), Vector2(6, sz.y * 0.55), Vector2(-6, sz.y * 0.55)]:
				pts.append(t * v)
			c.draw_colored_polygon(pts, Color(1, 1, 0.95, 0.5))
		Pub.PULP:
			# stitched on with red thread
			for x in [M + 3.0, sz.x - M - 3.0]:
				for i in 2:
					var yy := y0 + 4.0 + i * (y1 - y0 - 8.0)
					c.draw_line(Vector2(x - 3, yy - 3), Vector2(x + 3, yy + 3), Color("#a3122a"), 1.6, true)
					c.draw_line(Vector2(x + 3, yy - 3), Vector2(x - 3, yy + 3), Color("#a3122a"), 1.6, true)
		Pub.ZINE:
			for x in [M + 5.0, sz.x - M - 5.0]:
				c.draw_line(Vector2(x, y0 - 2), Vector2(x, y1 + 2), Color("#8a8f99"), 2.2, true)
				c.draw_line(Vector2(x, y0 - 2), Vector2(x, y1 + 2), Color(1, 1, 1, 0.5), 0.8, true)
		Pub.MANUAL:
			for x in [M + 5.0, sz.x - M - 5.0]:
				var p := Vector2(x, sz.y * 0.5)
				c.draw_circle(p, 3.6, Color("#7d8696"), true, -1.0, true)
				c.draw_circle(p, 3.6, Color("#3c4352"), false, 1.0, true)
				c.draw_line(p + Vector2(-2, -2), p + Vector2(2, 2), Color("#2c3240"), 1.0, true)
				c.draw_line(p + Vector2(2, -2), p + Vector2(-2, 2), Color("#2c3240"), 1.0, true)
		Pub.ALMANAC:
			# black photo corners
			var k := 7.0
			var ink := Color("#2b1e14")
			c.draw_colored_polygon(PackedVector2Array([Vector2(M - 2, y0 - 2), Vector2(M - 2 + k, y0 - 2), Vector2(M - 2, y0 - 2 + k)]), ink)
			c.draw_colored_polygon(PackedVector2Array([Vector2(sz.x - M + 2, y1 + 2), Vector2(sz.x - M + 2 - k, y1 + 2), Vector2(sz.x - M + 2, y1 + 2 - k)]), ink)
			c.draw_colored_polygon(PackedVector2Array([Vector2(sz.x - M + 2, y0 - 2), Vector2(sz.x - M + 2 - k, y0 - 2), Vector2(sz.x - M + 2, y0 - 2 + k)]), ink)
			c.draw_colored_polygon(PackedVector2Array([Vector2(M - 2, y1 + 2), Vector2(M - 2 + k, y1 + 2), Vector2(M - 2, y1 + 2 - k)]), ink)
