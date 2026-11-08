## One chunk of card text as a glossy candy pill. Long chunks wrap to more lines.
class_name ChunkView
extends Control

signal pressed(view: ChunkView)

const PILL := preload("res://shaders/pill.gdshader")
const M := 6.0       # room around the pill for shadow and rings
const PAD := Vector2(10, 4)

var slot := "verb"
var chunk = null
var text := ""
var font_size := 19
var max_w := 220.0
var clickable := false
var fits := false
var telegraph := false
var ci := 0
var uid := ""
var _mat: ShaderMaterial
var _label: Label


func setup(p_slot: String, p_chunk, p_text: String, opts := {}) -> ChunkView:
	slot = p_slot
	chunk = p_chunk
	text = p_text
	font_size = opts.get("font_size", 19)
	max_w = opts.get("max_w", 220.0)
	clickable = opts.get("clickable", false)
	fits = opts.get("fits", false)
	telegraph = opts.get("telegraph", false)
	ci = opts.get("ci", 0)
	uid = opts.get("uid", "")
	mouse_filter = MOUSE_FILTER_STOP if clickable else MOUSE_FILTER_IGNORE
	if clickable:
		mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_build()
	return self


func _build() -> void:
	var kind := "chunk"
	var fs := font_size
	var shown := text
	if chunk == null:
		shown = slot.to_upper()
		kind = "body_bold"
		fs = int(font_size * 0.72)
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
	var line_h := f.get_height(fs) - 2.0
	var body := Vector2(ceil(tw) + PAD.x * 2, ceil(line_h * lines.size()) + PAD.y * 2)
	var sz := body + Vector2(M, M) * 2.0 + Vector2(0, 2)
	custom_minimum_size = sz
	size = sz

	var bg := ColorRect.new()
	bg.size = sz
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = PILL
	_mat.set_shader_parameter("rect_size", sz)
	_mat.set_shader_parameter("margin", M)
	var cols: Array = Look.CHUNK[slot]
	_mat.set_shader_parameter("col", cols[0])
	_mat.set_shader_parameter("line", cols[1] if chunk != null else Look.INK2)
	_mat.set_shader_parameter("seed", float(hash(uid + text) % 100))
	bg.material = _mat
	add_child(bg)

	_label = Look.label("\n".join(lines), kind, fs, Look.CHUNK_TEXT.get(slot, Look.WHITE))
	_label.add_theme_constant_override("line_spacing", -2)
	_label.position = Vector2(M + PAD.x, M + PAD.y - 1)
	_label.size = Vector2(tw + 2, line_h * lines.size())
	add_child(_label)
	refresh()


func refresh() -> void:
	var is_empty: bool = chunk == null
	var muted: bool = not is_empty and chunk.get("muted", false)
	var redacted: bool = not is_empty and chunk.get("redacted", false)
	_mat.set_shader_parameter("empty", is_empty)
	_mat.set_shader_parameter("muted", muted)
	_mat.set_shader_parameter("redacted", redacted)
	_mat.set_shader_parameter("enemy_edit", not is_empty and chunk.get("enemyEdit", false))
	_mat.set_shader_parameter("telegraph", telegraph)
	_mat.set_shader_parameter("fits", fits)
	var c: Color = Look.CHUNK_TEXT.get(slot, Look.WHITE)
	if is_empty:
		c = Look.INK2
	elif muted:
		c = Color("#9a94ae")
	if redacted:
		c = Color(0, 0, 0, 0)
	_label.add_theme_color_override("font_color", c)
	var outline: bool = not is_empty and not muted and not Look.CHUNK_TEXT.has(slot)
	_label.add_theme_constant_override("outline_size", 3 if outline else 0)
	_label.add_theme_color_override("font_outline_color", Color(Look.CHUNK[slot][1], 0.55))


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
