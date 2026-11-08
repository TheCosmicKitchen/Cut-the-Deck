## A card: candy-striped rounded frame themed by its main verb, a glossy cost gem,
## the name, an inset art window with the card's picture, chunk pills, footer tags.
## kind: "hand" (248x356), "big" (Workshop editor, grows to fit), "mini" (deck row).
class_name CardView
extends Control

signal pressed(view: CardView)
signal chunk_pressed(view: CardView, chunk: ChunkView)

const GEM := preload("res://shaders/gem.gdshader")
const INSET := preload("res://shaders/inset.gdshader")
const SHADOW := Vector2(7, 8)

var db: Dictionary
var card: Dictionary
var kind := "hand"
var opts := {}
var chunks: Array[ChunkView] = []
var theme_name := "ui"
var _frame: Control
var _frame_mat: ShaderMaterial
var _gem_mat: ShaderMaterial
var _content: VBoxContainer
var _art: Control
var _art_mat: ShaderMaterial
var _art_sprite: TextureRect
var _stars: Array[TextureRect] = []
var _foot: HBoxContainer
var _selected := false
var _scroll := 0.0


func setup(p_db: Dictionary, p_card: Dictionary, p_kind := "hand", p_opts := {}) -> CardView:
	db = p_db
	card = p_card
	kind = p_kind
	opts = p_opts
	_build()
	return self


func card_size() -> Vector2:
	match kind:
		"big":
			return Vector2(opts.get("width", 460), 220)
		"mini":
			return Vector2(opts.get("width", 300), 54)
	return Vector2(248, 356)


func main_verb() -> String:
	for cl in card.clauses:
		var v = Grammar.live(cl.verb)
		if v and Grammar.trigger_of(cl) == "played":
			return v.id
	for cl in card.clauses:
		if cl.verb:
			return cl.verb.id
	return "ui"


## The card's picture. Stored as card.art so it can be swapped; defaults to the main verb's.
func art_name() -> String:
	return card.get("art", Px.verb_sprite(theme_name))


func _build() -> void:
	for c in get_children():
		c.queue_free()
	chunks.clear()
	theme_name = main_verb()
	var sz := card_size()
	var mini := kind == "mini"
	size = sz
	custom_minimum_size = sz
	pivot_offset = sz * 0.5
	mouse_filter = MOUSE_FILTER_STOP if opts.get("clickable", false) else MOUSE_FILTER_PASS
	if opts.get("clickable", false):
		mouse_default_cursor_shape = CURSOR_POINTING_HAND

	var band := 11.0 if not mini else 6.0
	_frame = Look.candy(sz, theme_name, SHADOW if not mini else Vector2(4, 5), band, 16.0 if not mini else 11.0)
	_frame_mat = (_frame.get_meta("rect") as ColorRect).material
	add_child(_frame)

	# cost gem
	var gsz := 58.0 if not mini else 44.0
	var gem := ColorRect.new()
	gem.mouse_filter = MOUSE_FILTER_IGNORE
	gem.size = Vector2(gsz, gsz)
	gem.position = Vector2(-10, -10) if not mini else Vector2(4, (sz.y - gsz) * 0.5 + 1)
	_gem_mat = ShaderMaterial.new()
	_gem_mat.shader = GEM
	_gem_mat.set_shader_parameter("rect_size", gem.size)
	gem.material = _gem_mat
	add_child(gem)
	var cost = Grammar.card_cost(db, card)
	var playable: bool = cost != null and Grammar.is_playable(card)
	_gem_mat.set_shader_parameter("empty", not playable)
	var ctext := "–"
	if playable:
		ctext = str(cost.cost) + ("+X" if cost.x else "")
	var cl := Look.label(ctext, "title", (28 if ctext.length() == 1 else 19) if not mini else (21 if ctext.length() == 1 else 14), Look.WHITE if playable else Look.INK2)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cl.position = gem.position + Vector2(-1, -2)
	cl.size = gem.size
	if playable:
		Look.outlined(cl, Look.INK, 4)
	add_child(cl)

	# name
	var name_x := 54.0 if not mini else gsz + 10.0
	var name_size := 23 if not mini else 17
	var avail := sz.x - name_x - (18.0 if not mini else 12.0)
	var nl := Look.label(card.name, "title", name_size, Look.INK)
	while name_size > 13 and Look.text_w("title", card.name, name_size) > avail:
		name_size -= 1
	nl.add_theme_font_size_override("font_size", name_size)
	nl.position = Vector2(name_x, 14) if not mini else Vector2(name_x, 6)
	nl.size = Vector2(avail, 30)
	nl.clip_text = true
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if not mini else VERTICAL_ALIGNMENT_TOP
	add_child(nl)

	if mini:
		# one line of the card's text under the name
		var line := Look.label(Grammar.card_text(db, card), "body", 12, Look.INK2)
		line.position = Vector2(name_x, 28)
		line.size = Vector2(avail, 18)
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(line)
		return

	if kind == "hand":
		_art = Control.new()
		_art.mouse_filter = MOUSE_FILTER_IGNORE
		_art.clip_contents = true
		add_child(_art)
		var backdrop := ColorRect.new()
		backdrop.mouse_filter = MOUSE_FILTER_IGNORE
		backdrop.set_anchors_preset(PRESET_FULL_RECT)
		_art_mat = ShaderMaterial.new()
		_art_mat.shader = INSET
		var t: Array = Look.THEME.get(theme_name, Look.THEME.ui)
		_art_mat.set_shader_parameter("bg_a", t[2])
		_art_mat.set_shader_parameter("bg_b", t[1])
		_art_mat.set_shader_parameter("shade", t[0].darkened(0.25))
		backdrop.material = _art_mat
		_art.add_child(backdrop)
		_art_sprite = TextureRect.new()
		_art_sprite.texture = Px.sprite(art_name(), t[0])
		_art_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_art_sprite.stretch_mode = TextureRect.STRETCH_SCALE
		_art_sprite.mouse_filter = MOUSE_FILTER_IGNORE
		_art.add_child(_art_sprite)
		for i in 2:
			var st := TextureRect.new()
			st.texture = Px.sprite("star")
			st.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			st.stretch_mode = TextureRect.STRETCH_SCALE
			st.size = Vector2(18, 18)
			st.mouse_filter = MOUSE_FILTER_IGNORE
			_art.add_child(st)
			_stars.append(st)

	_content = VBoxContainer.new()
	_content.mouse_filter = MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", 4)
	_content.position = Vector2(18, 56)
	_content.size = Vector2(sz.x - 36, 0)
	add_child(_content)
	var tele: Array = opts.get("tele", [])
	var show_empty: bool = opts.get("show_empty", false)
	for i in card.clauses.size():
		_content.add_child(_clause(card.clauses[i], i, tele, show_empty))
	if show_empty and card.clauses.size() < db.rules.maxClauses:
		_content.add_child(_clause(Grammar.empty_clause(), card.clauses.size(), [], true))

	var tags := []
	if Grammar.is_broken(card):
		tags.append(["Broken", Look.RED])
	if opts.get("spent", false):
		tags.append(["Spent", Look.INK2])
	for t in tele:
		tags.append([str(opts.get("enemy_names", {}).get(t.enemy, "Enemy")) + " will edit", Look.RED])
	if not tags.is_empty():
		_foot = HBoxContainer.new()
		_foot.add_theme_constant_override("separation", 6)
		_foot.mouse_filter = MOUSE_FILTER_IGNORE
		for t in tags:
			_foot.add_child(_tag(t[0], t[1]))
		add_child(_foot)
	_fit.call_deferred()


## One clause. A trigger sits on its own line above. A condition gets its own line
## too, and an indent arrow leads from it into the part it controls.
func _clause(clause: Dictionary, ci: int, tele: Array, show_empty: bool) -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", -8)
	var holes: Array = clause.get("holes", [])
	var lead: Array[ChunkView] = []
	var cond: Array[ChunkView] = []
	var rest: Array[ChunkView] = []
	var mw := size.x - 36 + 16
	var fs := 20 if kind == "hand" else 23
	for slot in Grammar.SLOTS:
		var ch = clause[slot]
		var show: bool = ch != null or show_empty or Grammar.REQUIRED.has(slot) or holes.has(slot)
		if not show:
			continue
		var text: String = Grammar.chunk_label(db, ch).trim_suffix(":") if ch else slot
		var tl := false
		for t in tele:
			if t.ci == ci and t.slot == slot:
				tl = true
		var cv := ChunkView.new().setup(slot, ch, text, {
			"font_size": fs, "max_w": mw - (30.0 if clause.condition and slot != "condition" else 0.0),
			"clickable": opts.get("chunks_clickable", false), "fits": opts.get("fit_type", "") == slot,
			"telegraph": tl, "ci": ci, "uid": card.uid, "slip_style": opts.get("slip_style", "rough"),
			"hole_col": opts.get("hole_col", Look.PINK)})
		cv.pressed.connect(func(v): chunk_pressed.emit(self, v))
		chunks.append(cv)
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
		arrow.col = ChunkView.INK.condition
		arrow.custom_minimum_size = Vector2(30, 34)
		row.add_child(arrow)
		var f := _flow(rest)
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(f)
		box.add_child(row)
	return box


func _flow(items: Array) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.mouse_filter = MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", -9)
	flow.add_theme_constant_override("v_separation", -10)
	for it in items:
		flow.add_child(it)
	return flow


func _tag(text: String, col: Color) -> Control:
	var l := Look.label(text, "body_bold", 13, col)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.1)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", sb)
	return l


func _fit() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_content):
		return
	var sz := size
	var text_h: float = _content.get_combined_minimum_size().y
	var foot := 40.0 if _foot else 18.0
	if kind == "big":
		var h: float = max(card_size().y, 60.0 + text_h + foot)
		_resize(Vector2(sz.x, h))
		sz = size
		_content.position.y = 58
	else:
		var room: float = sz.y - foot - 62.0
		if text_h > room:
			var k: float = room / text_h
			_content.scale = Vector2(k, k)
			_content.size.x = (sz.x - 36) / k
			text_h = room
		var y: float = sz.y - foot - text_h
		var ah: float = y - 60.0 - 6.0
		if ah < 40.0:
			# no room for a picture: text starts under the name instead
			y = 56.0
		_content.position.y = y
		if _art:
			_art.visible = ah >= 40.0
			_art.position = Vector2(18, 58)
			_art.size = Vector2(sz.x - 36, ah)
			_art_mat.set_shader_parameter("rect_size", _art.size)
			var tex_sz := _art_sprite.texture.get_size()
			var sc: float = clamp(floor((ah - 16.0) / tex_sz.y), 2.0, 6.0)
			_art_sprite.size = tex_sz * sc
			_art_sprite.position = Vector2(floor((_art.size.x - _art_sprite.size.x) * 0.5), floor(ah - 12.0 - _art_sprite.size.y))
			if _stars.size() == 2:
				_stars[0].position = Vector2(12, 10)
				_stars[1].position = Vector2(_art.size.x - 30, floor(ah * 0.45))
	if _foot:
		_foot.position = Vector2(18, sz.y - 34)


func _resize(s: Vector2) -> void:
	size = s
	custom_minimum_size = s
	pivot_offset = s * 0.5
	Look.resize_candy(_frame, s)


func set_selected(on: bool) -> void:
	_selected = on
	_frame_mat.set_shader_parameter("glow", 1.0 if on else 0.0)


func set_dim(v: float) -> void:
	_frame_mat.set_shader_parameter("dim", v)
	modulate = Color(1, 1, 1, 1.0 - v * 0.15)


func pulse_cost() -> void:
	create_tween().tween_method(func(v): _gem_mat.set_shader_parameter("pulse", v), 1.0, 0.0, 0.4)


func _process(delta: float) -> void:
	if _selected:
		_scroll += delta * 22.0
		_frame_mat.set_shader_parameter("scroll", _scroll)


func _gui_input(event: InputEvent) -> void:
	if opts.get("clickable", false) and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()
