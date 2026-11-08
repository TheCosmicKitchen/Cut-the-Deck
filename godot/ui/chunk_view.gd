## One chunk of card text, drawn as part of a physical card:
##   printed  words printed on the card, with faint dotted cut-guides
##   slip     a chunk glued on from elsewhere: a rough hand-cut paper slip
##   hole     an empty slot: the chunk was cut out and the backdrop shows through
## Marker overlays: muted (scribbled out), redacted (black bar), enemy edit (red pen).
class_name ChunkView
extends Control

signal pressed(view: ChunkView)

const CUT := preload("res://shaders/cut.gdshader")
const MARKER := preload("res://shaders/marker.gdshader")
const M := 8.0
const PAD := Vector2(7, 3)

## Ink colours for printed text, by chunk type.
const INK := {
	"verb": Color("#d62f52"), "amount": Color("#2f66d8"), "repeat": Color("#8b45d6"),
	"target": Color("#1f9a5a"), "condition": Color("#c77a00"), "trigger": Color("#2a8aa2"),
}

var slot := "verb"
var chunk = null
var text := ""
var font_size := 20
var max_w := 220.0
var clickable := false
var fits := false
var telegraph := false
var slip_style := "rough"   # "rough" (glued slip) or "label" (taped label)
var hole_col := Color("#f9b8d6")
var ci := 0
var uid := ""
var look := "printed"
var _mat: ShaderMaterial
var _holder: Control
var _label: Label


func setup(p_slot: String, p_chunk, p_text: String, opts := {}) -> ChunkView:
	slot = p_slot
	chunk = p_chunk
	text = p_text
	font_size = opts.get("font_size", 20)
	max_w = opts.get("max_w", 220.0)
	clickable = opts.get("clickable", false)
	fits = opts.get("fits", false)
	telegraph = opts.get("telegraph", false)
	slip_style = opts.get("slip_style", "rough")
	hole_col = opts.get("hole_col", hole_col)
	ci = opts.get("ci", 0)
	uid = opts.get("uid", "")
	if chunk == null:
		look = "hole"
	elif chunk.get("pasted", false) or opts.get("force_slip", false):
		look = "slip"
	mouse_filter = MOUSE_FILTER_STOP if clickable else MOUSE_FILTER_IGNORE
	if clickable:
		mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_build()
	return self


func _build() -> void:
	var kind := "chunk"
	var fs := font_size
	var shown := text
	if look == "hole":
		shown = slot.to_upper()
		kind = "body_bold"
		fs = int(font_size * 0.66)
	elif slot == "trigger":
		shown = text.to_upper()
		fs = int(font_size * 0.78)
	var f := Look.font(kind)
	var lines := []
	var cur := ""
	for word in shown.split(" "):
		var trial: String = word if cur == "" else cur + " " + word
		if cur != "" and f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + PAD.x * 2 + M * 2 > max_w:
			lines.append(cur)
			cur = word
		else:
			cur = trial
	lines.append(cur)
	var tw := 0.0
	for l in lines:
		tw = max(tw, f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var line_h := f.get_height(fs) - 3.0
	var extra_x := 2.0 if look == "slip" else 0.0
	var body := Vector2(ceil(tw) + PAD.x * 2 + extra_x, ceil(line_h * lines.size()) + PAD.y * 2)
	if look == "hole":
		body.y = max(body.y, f.get_height(int(font_size)) + PAD.y * 2 - 3)
		body.x = max(body.x, 52.0)
	var sz := body + Vector2(M, M) * 2.0
	custom_minimum_size = sz
	size = sz

	_holder = Control.new()
	_holder.mouse_filter = MOUSE_FILTER_IGNORE
	_holder.size = sz
	_holder.pivot_offset = sz * 0.5
	var sd := float(hash(uid + text + str(ci)) % 1000)
	if look == "slip":
		_holder.rotation_degrees = (fmod(sd * 7.31, 2.0) - 1.0) * 3.2
	add_child(_holder)

	var bg := ColorRect.new()
	bg.size = sz
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = CUT
	_mat.set_shader_parameter("rect_size", sz)
	_mat.set_shader_parameter("margin", M)
	_mat.set_shader_parameter("seed", fmod(sd, 97.0))
	_mat.set_shader_parameter("tint", INK[slot])
	_mat.set_shader_parameter("hole_col", hole_col)
	_mat.set_shader_parameter("mode", {"printed": 0, "slip": 1, "hole": 2}[look])
	_mat.set_shader_parameter("tape", look == "slip" and slip_style == "label")
	_mat.set_shader_parameter("glue", slip_style == "rough")
	if look == "slip":
		_set_source(sd)
	bg.material = _mat
	_holder.add_child(bg)

	var col: Color = INK[slot]
	if look == "hole":
		col = Color(1, 1, 1, 0.75)
	_label = Look.label("\n".join(lines), kind, fs, col)
	_label.add_theme_constant_override("line_spacing", -3)
	_label.position = Vector2(M + PAD.x + extra_x, M + PAD.y - 2)
	_label.size = Vector2(tw + 2, line_h * lines.size())
	if look == "hole":
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.position = Vector2(M, M)
		_label.size = body
	_holder.add_child(_label)

	if chunk != null:
		var marks := []
		if chunk.get("redacted", false):
			marks.append(0)
		elif chunk.get("muted", false):
			marks.append(1)
		if chunk.get("enemyEdit", false):
			marks.append(2)
		for m in marks:
			var mr := ColorRect.new()
			mr.size = sz
			mr.mouse_filter = MOUSE_FILTER_IGNORE
			var mm := ShaderMaterial.new()
			mm.shader = MARKER
			mm.set_shader_parameter("rect_size", sz)
			mm.set_shader_parameter("margin", M)
			mm.set_shader_parameter("mode", m)
			mm.set_shader_parameter("seed", fmod(sd, 31.0))
			mr.material = mm
			_holder.add_child(mr)
		if chunk.get("muted", false) and not chunk.get("redacted", false):
			_label.modulate = Color(1, 1, 1, 0.5)
	refresh()


## Slips show the paper of the card they were cut from (chunk.from = that card's id).
func _set_source(sd: float) -> void:
	var from: String = chunk.get("from", "")
	var db: Dictionary = Game.db if Game and not Game.db.is_empty() else {}
	var def = RunState.card_def(db, from) if from != "" and not db.is_empty() else null
	if def == null:
		_mat.set_shader_parameter("has_src", false)
		return
	var verb := "ui"
	for cl in def.clauses:
		if cl.has("verb") and not cl.has("trigger"):
			verb = cl.verb
			break
	if verb == "ui" and not def.clauses.is_empty() and def.clauses[0].has("verb"):
		verb = def.clauses[0].verb
	var t: Array = Look.THEME.get(verb, Look.THEME.ui)
	_mat.set_shader_parameter("has_src", true)
	_mat.set_shader_parameter("src1", t[0])
	_mat.set_shader_parameter("src2", t[1])
	_mat.set_shader_parameter("src3", t[2])
	_mat.set_shader_parameter("sliver", int(sd) % 4)


func refresh() -> void:
	_mat.set_shader_parameter("telegraph", telegraph)
	_mat.set_shader_parameter("fits", fits)


func set_hint(on: bool) -> void:
	_mat.set_shader_parameter("hover", 1.0 if on else 0.0)


func _gui_input(event: InputEvent) -> void:
	if clickable and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()


func _notification(what: int) -> void:
	if not clickable or _mat == null:
		return
	if what == NOTIFICATION_MOUSE_ENTER:
		create_tween().tween_method(func(v): _mat.set_shader_parameter("hover", v), 0.0, 1.0, 0.12)
	elif what == NOTIFICATION_MOUSE_EXIT:
		create_tween().tween_method(func(v): _mat.set_shader_parameter("hover", v), 1.0, 0.0, 0.12)
