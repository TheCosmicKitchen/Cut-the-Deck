# Cut the Deck — main scene. The whole UI is built in code from run state and
# rebuilt after every action, so the engine stays the single source of truth.
#
# Combat: click a card to play it, click an enemy to target it.
#         Mute / Invert quick edits cost 1 energy: pick the tool, then a chunk.
#         Keys: 1-9 play the Nth card in hand, E ends the turn, Esc clears a tool.
# Workshop: pick a tool, then a chunk (scissors, glue, mute, invert) or a card (merge, shred).

extends Control

const DB := preload("res://godot/engine/db.gd")
const G := preload("res://godot/engine/grammar.gd")
const Combat := preload("res://godot/engine/combat.gd")
const Edits := preload("res://godot/engine/edits.gd")
const Run := preload("res://godot/engine/run.gd")

# Palette (light theme of the web build).
const MAT := Color("d9e3dc")
const MAT_LINE := Color(30 / 255.0, 70 / 255.0, 55 / 255.0, 0.09)
const MAT_MAJOR := Color(30 / 255.0, 70 / 255.0, 55 / 255.0, 0.18)
const SURFACE := Color("eef3ef")
const EDGE := Color("b9c9be")
const FG := Color("14231d")
const FG_2 := Color("4b5f56")
const PAPER := Color("fbfaf5")
const PAPER_FG := Color("1b1d1a")
const PAPER_2 := Color("6b6b62")
const PAPER_EDGE := Color("d7d3c5")
const ACCENT := Color("e0a21a")
const ACCENT_FG := Color("1a1405")
const GOOD := Color("2f7d3c")
const BAD := Color("b8352a")
const TYPE_COL := {
	"verb": "#c2412d", "amount": "#2754b5", "repeat": "#7a3cb0",
	"target": "#2f7d3c", "condition": "#9a6100", "trigger": "#436670",
}
const TELE_BG := "#f6d9d4"
const FITS_BG := "#f6e3b5"

const WS_TOOLS := ["scissors", "glue", "mute", "invert", "merge", "shred"]
const CHUNK_TOOLS := ["scissors", "glue", "mute", "invert"]
const TOOL_HINT := {
	"scissors": "Scissors: click a chunk to cut it onto your clipboard.",
	"mute": "Mute: click a chunk to mute or unmute it. A muted Verb or Amount makes its clause inert.",
	"invert": "Invert: click a chunk to flip it (Deal ↔ Heal, 3 ↔ 7, if ↔ unless, an enemy ↔ yourself…).",
	"shred": "Shred: click a card to destroy it. Its chunks go to your clipboard and you get Ink back.",
}

var db: Dictionary
var run: Dictionary

var quick_tool := ""        # combat quick edit: "", "mute" or "invert"
var ws_tool := "scissors"   # selected workshop tool
var clip_sel := -1          # selected clipboard index for glue
var merge_a := ""           # first card picked for merge

var _font_display: SystemFont
var _font_mono: SystemFont
var _body: VBoxContainer
var _track: HBoxContainer
var _status: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_id := 0
var _render_queued := false


# ---------------------------------------------------------------- lifecycle

func _ready() -> void:
	db = DB.load_db()
	_build_theme()
	_build_shell()
	resized.connect(queue_redraw)
	if db.is_empty():
		_body.add_child(_label("Could not load the card data in res://data. See the Output panel.", 16, BAD))
		return
	_new_run()


func _new_run() -> void:
	run = Run.new_run(db)
	quick_tool = ""
	ws_tool = "scissors"
	clip_sel = -1
	merge_a = ""
	_refresh()


func _draw() -> void:
	# A self-healing cutting mat: minor grid every 24px, major every 120px.
	draw_rect(Rect2(Vector2.ZERO, size), MAT)
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), MAT_MAJOR if int(x) % 120 == 0 else MAT_LINE, 1.0)
		x += 24.0
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), MAT_MAJOR if int(y) % 120 == 0 else MAT_LINE, 1.0)
		y += 24.0


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		quick_tool = ""
		clip_sel = -1
		merge_a = ""
		_refresh()
		return
	if run.is_empty() or run["phase"] != "combat":
		return
	var s: Dictionary = run["combat"]
	if s["phase"] != "player":
		return
	if key.keycode == KEY_E:
		_end_turn()
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var idx: int = key.keycode - KEY_1
		if idx < s["hand"].size():
			_play(s["hand"][idx])


# ---------------------------------------------------------------- theme & shell

func _sb(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 8, pad := 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


func _sys_font(names: Array, weight := 400, italic := false) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.font_italic = italic
	return f


func _build_theme() -> void:
	var body_names := ["Atkinson Hyperlegible", "Inter", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"]
	var body := _sys_font(body_names)
	var bold := _sys_font(body_names, 700)
	var italic := _sys_font(body_names, 400, true)
	_font_mono = _sys_font(["JetBrains Mono", "Cascadia Mono", "Consolas", "Menlo", "DejaVu Sans Mono", "monospace"], 600)
	_font_display = _sys_font(["Anybody", "Arial Narrow", "Roboto Condensed", "Segoe UI", "Arial", "sans-serif"], 800)

	var t := Theme.new()
	t.default_font = body
	t.default_font_size = 15
	t.set_font("normal_font", "RichTextLabel", body)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_font("italics_font", "RichTextLabel", italic)
	t.set_font("bold_italics_font", "RichTextLabel", _sys_font(body_names, 700, true))
	t.set_font("mono_font", "RichTextLabel", _font_mono)
	t.set_color("default_color", "RichTextLabel", FG)
	t.set_color("font_color", "Label", FG)

	t.set_stylebox("normal", "Button", _sb(SURFACE, EDGE, 1, 8, 8))
	t.set_stylebox("hover", "Button", _sb(SURFACE, FG_2, 1, 8, 8))
	t.set_stylebox("pressed", "Button", _sb(ACCENT, ACCENT, 1, 8, 8))
	t.set_stylebox("hover_pressed", "Button", _sb(ACCENT, FG_2, 1, 8, 8))
	t.set_stylebox("disabled", "Button", _sb(SURFACE.darkened(0.03), EDGE, 1, 8, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", FG)
	t.set_color("font_hover_color", "Button", FG)
	t.set_color("font_pressed_color", "Button", ACCENT_FG)
	t.set_color("font_hover_pressed_color", "Button", ACCENT_FG)
	t.set_color("font_focus_color", "Button", FG)
	t.set_color("font_disabled_color", "Button", Color(FG_2, 0.6))
	t.set_font("font", "Button", bold)

	t.set_stylebox("panel", "PanelContainer", _sb(SURFACE, EDGE, 1, 10, 14))
	t.set_stylebox("background", "ProgressBar", _sb(MAT, EDGE, 1, 4, 0))
	t.set_stylebox("fill", "ProgressBar", _sb(BAD, Color(0, 0, 0, 0), 0, 4, 0))
	theme = t


func _build_shell() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	col.add_child(top)
	var mark := HBoxContainer.new()
	mark.add_theme_constant_override("separation", 2)
	mark.add_child(_label("Cut", 24, FG, _font_display))
	var slash := _label("/", 26, ACCENT, _font_display)
	slash.rotation_degrees = -3.0
	mark.add_child(slash)
	mark.add_child(_label("the Deck", 24, FG, _font_display))
	top.add_child(mark)
	_track = HBoxContainer.new()
	_track.add_theme_constant_override("separation", 4)
	_track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_track)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_status = _label("", 14, FG, _font_mono)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_status)
	top.add_child(_button("New run", _new_run))

	var rule := ColorRect.new()
	rule.color = EDGE
	rule.custom_minimum_size = Vector2(0, 1)
	col.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	scroll.add_child(_body)

	var toast_wrap := CenterContainer.new()
	toast_wrap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast_wrap.offset_top = -72
	toast_wrap.offset_bottom = -18
	toast_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_wrap)
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", _sb(FG, FG, 0, 8, 12))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_toast_label = _label("", 15, MAT)
	_toast.add_child(_toast_label)
	toast_wrap.add_child(_toast)


# ---------------------------------------------------------------- small widgets

func _label(text: String, font_size := 15, color := FG, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	return l


func _wrap_label(text: String, font_size := 15, color := FG_2) -> Label:
	var l := _label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _h2(text: String) -> Label:
	return _label(text, 21, FG, _font_display)


func _h3(text: String) -> Label:
	return _label(text.to_upper(), 12, FG_2, _font_display)


func _button(text: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	if primary:
		b.add_theme_stylebox_override("normal", _sb(ACCENT, ACCENT, 1, 8, 8))
		b.add_theme_stylebox_override("hover", _sb(ACCENT.lightened(0.1), ACCENT, 1, 8, 8))
		b.add_theme_color_override("font_color", ACCENT_FG)
		b.add_theme_color_override("font_hover_color", ACCENT_FG)
	return b


func _panel(child: Control, border := EDGE, bw := 1) -> PanelContainer:
	var p := PanelContainer.new()
	if border != EDGE or bw != 1:
		p.add_theme_stylebox_override("panel", _sb(SURFACE, border, bw, 10, 14))
	p.add_child(child)
	return p


func _vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _flow(sep := 12) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f


func _bar(value: int, max_value: int, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max(1, max_value)
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 10)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("fill", _sb(color, Color(0, 0, 0, 0), 0, 4, 0))
	return b


func _toast_msg(msg: String) -> void:
	_toast_id += 1
	_toast_label.text = msg
	_toast.visible = true
	get_tree().create_timer(2.6).timeout.connect(_hide_toast.bind(_toast_id))


func _hide_toast(id: int) -> void:
	if id == _toast_id:
		_toast.visible = false


func _after(res: Dictionary) -> void:
	if not res.get("ok", false):
		_toast_msg(res.get("error", "That didn't work."))
	elif res.has("note"):
		_toast_msg(res["note"])
	_refresh()


func _refresh() -> void:
	# Rebuild on the next idle frame so a widget never frees itself mid-signal.
	if _render_queued:
		return
	_render_queued = true
	call_deferred("_render")


# ---------------------------------------------------------------- cards

static func _hex(c: Color) -> String:
	return "#" + c.to_html(false)


func _chunk_bb(ch: Dictionary, slot: String, text: String) -> String:
	if ch.get("redacted", false):
		var ink := _hex(PAPER_FG)
		return "[bgcolor=%s][color=%s]%s[/color][/bgcolor]" % [ink, ink, "█".repeat(maxi(3, text.length()))]
	var t := text.replace("[", "[lb]")
	match slot:
		"amount":
			t = "[code]%s[/code]" % t
		"condition":
			t = "[i]%s[/i]" % t
		"trigger":
			t = "[font_size=12][b]%s[/b][/font_size]" % t.to_upper()
		_:
			t = "[b]%s[/b]" % t
	if ch.get("muted", false):
		return "[color=%s][s]%s[/s][/color]" % [_hex(PAPER_2), t]
	t = "[color=%s]%s[/color]" % [TYPE_COL[slot], t]
	if ch.get("enemyEdit", false):
		t = "[u]%s[/u]" % t
	return t


# o: tele (Array), chunks (bool: chunks clickable), show_empty (bool), glue_type (String)
func _card_bb(card: Dictionary, o: Dictionary) -> String:
	var tele: Array = o.get("tele", [])
	var clickable: bool = o.get("chunks", false)
	var glue_type: String = o.get("glue_type", "")
	var lines := []
	for ci in card["clauses"].size():
		var clause: Dictionary = card["clauses"][ci]
		var words := []
		for tok in G.clause_tokens(db, clause, o.get("show_empty", false)):
			var slot: String = tok["slot"]
			var meta := "%s|%d|%s" % [card["uid"], ci, slot]
			var piece: String
			var can_click := clickable and (glue_type == "" or glue_type == slot)
			if tok["chunk"] == null:
				if not o.get("show_empty", false) and not G.REQUIRED.has(slot):
					continue
				var col: String = TYPE_COL["verb"] if G.REQUIRED.has(slot) else _hex(PAPER_2)
				piece = "[font_size=11][color=%s]‹%s›[/color][/font_size]" % [col, slot.to_upper()]
				can_click = clickable and glue_type == slot
			else:
				piece = _chunk_bb(tok["chunk"], slot, tok["text"])
				for tl in tele:
					if tl["ci"] == ci and tl["slot"] == slot:
						piece = "[bgcolor=%s]%s[/bgcolor]" % [TELE_BG, piece]
			if glue_type != "" and glue_type == slot:
				piece = "[bgcolor=%s]%s[/bgcolor]" % [FITS_BG, piece]
			if can_click:
				piece = "[url=%s]%s[/url]" % [meta, piece]
			words.append(piece)
		lines.append(" ".join(PackedStringArray(words)) + ".")
	if glue_type != "" and o.get("show_empty", false) and card["clauses"].size() < db["rules"]["maxClauses"]:
		lines.append("[url=%s|%d|new][color=%s][font_size=12]+ new clause[/font_size][/color][/url]" % [card["uid"], card["clauses"].size(), _hex(PAPER_2)])
	if lines.is_empty():
		lines.append("[color=%s][i]blank card[/i][/color]" % _hex(PAPER_2))
	return "\n".join(PackedStringArray(lines))


# o: width, selected, dim, click (String action or ""), why (tooltip),
#    plus the _card_bb keys (tele, chunks, show_empty, glue_type)
func _card(card: Dictionary, o := {}) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(o.get("width", 176), o.get("min_h", 150))
	var selected: bool = o.get("selected", false)
	var sb := _sb(PAPER, ACCENT if selected else PAPER_EDGE, 3 if selected else 1, 9, 11)
	sb.shadow_color = Color(0.08, 0.16, 0.12, 0.28)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	p.add_theme_stylebox_override("panel", sb)
	if o.get("dim", false):
		p.modulate = Color(1, 1, 1, 0.55)
	if o.get("why", "") != "":
		p.tooltip_text = o["why"]

	var v := _vbox(8)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(v)

	var head := _hbox(8)
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(head)
	var cost = G.card_cost(db, card)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(28, 28)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	var badge_text := "–"
	if cost == null:
		badge.add_theme_stylebox_override("panel", _sb(PAPER, PAPER_2, 2, 14, 0))
	else:
		badge.add_theme_stylebox_override("panel", _sb(PAPER_FG if not o.get("dim", false) else PAPER_2, Color(0, 0, 0, 0), 0, 14, 0))
		badge_text = str(cost["cost"])
		if cost["x"]:
			badge_text = "X" if cost["cost"] == 0 else "%d+X" % cost["cost"]
	var bl := _label(badge_text, 14 if badge_text.length() < 3 else 10, PAPER if cost != null else PAPER_2, _font_mono)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(bl)
	head.add_child(badge)
	var title_l := _label(card["name"], 16, PAPER_FG, _font_display)
	title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_l)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.meta_underlined = false
	# Only catch clicks when chunks are the targets; otherwise the whole card is the button.
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS if o.get("chunks", false) else Control.MOUSE_FILTER_IGNORE
	rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtl.add_theme_color_override("default_color", PAPER_FG)
	rtl.add_theme_font_size_override("normal_font_size", 14)
	rtl.add_theme_font_size_override("bold_font_size", 14)
	rtl.add_theme_font_size_override("italics_font_size", 14)
	rtl.add_theme_font_size_override("mono_font_size", 14)
	rtl.add_theme_constant_override("line_separation", 4)
	rtl.text = _card_bb(card, o)
	rtl.meta_clicked.connect(_on_chunk_meta)
	v.add_child(rtl)

	var tags := []
	if G.is_broken(card):
		tags.append(["Broken", BAD])
	elif not G.is_playable(card):
		tags.append(["No play trigger", PAPER_2])
	if not o.get("tele", []).is_empty():
		tags.append(["Targeted", BAD])
	var edited := false
	for c in card["clauses"]:
		for slot in G.SLOTS:
			if c[slot] != null and (c[slot].get("muted", false) or c[slot].get("enemyEdit", false)):
				edited = true
	if edited:
		tags.append(["Edited", PAPER_2])
	if not tags.is_empty():
		var foot := _hbox(6)
		foot.mouse_filter = Control.MOUSE_FILTER_PASS
		for tg in tags:
			foot.add_child(_label(String(tg[0]).to_upper(), 10, tg[1], _font_mono))
		v.add_child(foot)

	var action: String = o.get("click", "")
	if action != "":
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.gui_input.connect(_on_card_input.bind(card["uid"], action))
	return p


func _on_card_input(event: InputEvent, uid: String, action: String) -> void:
	if not _is_left_click(event):
		return
	match action:
		"play":
			_play(uid)
		"take":
			Run.take_reward(db, run, uid)
			_refresh()
		"ws":
			_ws_card(uid)


func _on_chunk_meta(meta) -> void:
	var parts := String(meta).split("|")
	if parts.size() != 3:
		return
	var uid := parts[0]
	var ci := int(parts[1])
	var slot := parts[2]
	if run["phase"] == "combat" and quick_tool != "":
		var tool := quick_tool
		quick_tool = ""
		_after(Combat.combat_edit(db, run["combat"], tool, uid, ci, slot))
	elif run["phase"] == "workshop":
		_ws_chunk(uid, ci, slot)


# ---------------------------------------------------------------- render

func _render() -> void:
	_render_queued = false
	if run.is_empty():
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_render_top()
	match run["phase"]:
		"map":
			_render_map()
		"combat":
			_render_combat()
		"reward":
			_render_reward()
		"workshop":
			_render_workshop()
		_:
			_render_end()


func _render_top() -> void:
	for c in _track.get_children():
		_track.remove_child(c)
		c.queue_free()
	var nodes: Array = db["rules"]["run"]
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		var done: bool = i < run["node"] or run["phase"] == "victory"
		var now: bool = i == run["node"] and not (run["phase"] in ["victory", "defeat"])
		var bg := ACCENT if now else (EDGE if done else MAT)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _sb(bg, ACCENT if now else EDGE, 1, 12, 4))
		var short: String = {"fight": "Fight", "workshop": "Shop", "elite": "Elite", "boss": "Boss"}.get(n["type"], n["type"])
		p.add_child(_label("%d %s" % [i + 1, short], 12, ACCENT_FG if now else FG_2, _font_mono))
		p.tooltip_text = _node_title(n)
		_track.add_child(p)
	var hp: int = run["hp"]
	if run["phase"] == "combat":
		hp = run["combat"]["player"]["hp"]
	_status.text = "HP %d/%d   Ink %d   Deck %d   Seed %d" % [hp, run["maxHp"], run["ink"], run["deck"].size(), run["seed"]]


func _node_title(n: Dictionary) -> String:
	if n["type"] == "workshop":
		return "Workshop"
	var names := []
	for key in n["enemies"]:
		names.append(db["enemies"]["enemies"][key]["name"])
	return "%s: %s" % [String(n["type"]).capitalize(), ", ".join(PackedStringArray(names))]


func _render_map() -> void:
	var node: Dictionary = Run.current_node(db, run)
	var v := _vbox(10)
	v.add_child(_h3("Node %d of %d" % [run["node"] + 1, db["rules"]["run"].size()]))
	v.add_child(_h2(_node_title(node)))
	if node["type"] == "workshop":
		v.add_child(_wrap_label("Spend Ink to cut, glue, mute and invert your cards. You get +%d Ink on arrival." % db["rules"]["ink"]["workshopBonus"]))
	else:
		var foes := _flow(10)
		for key in node["enemies"]:
			var e: Dictionary = db["enemies"]["enemies"][key]
			var info := _vbox(2)
			info.add_child(_label(e["name"], 16, FG, _font_display))
			info.add_child(_label("%s · %d HP" % [e["role"], e["hp"]], 13, FG_2))
			foes.add_child(_panel(info))
		v.add_child(foes)
	var row := _hbox()
	row.add_child(_button("Enter  →", _enter, true))
	v.add_child(row)
	_body.add_child(_panel(v))

	_body.add_child(_h3("Your deck"))
	var deck := _flow()
	for card in run["deck"]:
		deck.add_child(_card(card, {"width": 168, "min_h": 120}))
	_body.add_child(deck)


func _render_combat() -> void:
	var s: Dictionary = run["combat"]
	var cols := _hbox(16)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(cols)
	var left := _vbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)

	if s["phase"] == "won" or s["phase"] == "lost":
		var res := _vbox(8)
		res.alignment = BoxContainer.ALIGNMENT_CENTER
		var won: bool = s["phase"] == "won"
		var title := _label("Victory" if won else "Defeated", 34, GOOD if won else BAD, _font_display)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		res.add_child(title)
		var b := _button("Collect rewards  →" if won else "Continue", _finish_fight, true)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		res.add_child(b)
		left.add_child(_panel(res, ACCENT, 2))

	# enemies
	var foes := _flow(12)
	for i in s["enemies"].size():
		foes.add_child(_foe(s, i))
	left.add_child(foes)

	# you
	var me := _hbox(16)
	var stats := _vbox(4)
	stats.custom_minimum_size = Vector2(220, 0)
	var pl: Dictionary = s["player"]
	stats.add_child(_label("You", 17, FG, _font_display))
	stats.add_child(_bar(pl["hp"], pl["maxHp"], GOOD))
	stats.add_child(_label(_nums(pl), 12, FG_2, _font_mono))
	me.add_child(stats)
	var per: int = db["rules"]["player"]["energyPerTurn"]
	var pips := "●".repeat(mini(pl["energy"], 12)) + "○".repeat(maxi(0, per - pl["energy"]))
	var energy := _label("%s  %d" % [pips, pl["energy"]], 20, ACCENT, _font_mono)
	energy.tooltip_text = "Energy"
	energy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	me.add_child(energy)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	me.add_child(sp)
	var my_turn: bool = s["phase"] == "player"
	for tool in ["mute", "invert"]:
		var tb := Button.new()
		tb.toggle_mode = true
		tb.button_pressed = quick_tool == tool
		tb.text = "%s · %d⚡" % [tool.capitalize(), db["rules"]["combatEdits"]["tools"][tool]["energy"]]
		tb.tooltip_text = "Quick edit: pick this, then a chunk on a card in your hand. Lasts until the fight ends."
		tb.disabled = not my_turn
		tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tb.pressed.connect(_toggle_quick.bind(tool))
		me.add_child(tb)
	var end := _button("End turn  (E)", _end_turn, true)
	end.disabled = not my_turn
	end.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	me.add_child(end)
	left.add_child(_panel(me))

	var hint := "Click a card to play it · click an enemy to target it · keys 1–9 play, E ends the turn."
	if quick_tool != "":
		hint = "%s: click a chunk on a card in your hand. Esc cancels." % quick_tool.capitalize()
	if s.get("aborted", false):
		hint = "The safety net aborted this turn. End your turn."
	left.add_child(_wrap_label(hint, 13))

	var hand := _flow(12)
	for uid in s["hand"]:
		var info := Combat.play_info(db, s, uid)
		var o := {
			"tele": Combat.telegraphs_on(s, uid),
			"dim": not info["can"] and quick_tool == "",
			"why": info.get("why", ""),
			"click": "play" if quick_tool == "" else "",
			"chunks": quick_tool != "",
		}
		hand.add_child(_card(s["cards"][uid], o))
	if s["hand"].is_empty():
		hand.add_child(_wrap_label("Your hand is empty.", 14))
	left.add_child(hand)
	left.add_child(_label("Draw pile %d · Discard %d · Turn %d" % [s["draw"].size(), s["discard"].size(), s["turn"]], 12, FG_2, _font_mono))

	# log
	var logp := _vbox(6)
	logp.custom_minimum_size = Vector2(290, 420)
	logp.add_child(_h3("Log"))
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.scroll_following = true
	rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtl.add_theme_color_override("default_color", FG_2)
	rtl.add_theme_font_size_override("normal_font_size", 13)
	rtl.add_theme_font_size_override("bold_font_size", 13)
	var out := []
	var last_turn := -1
	var entries: Array = s["log"]
	for k in range(maxi(0, entries.size() - 120), entries.size()):
		var l: Dictionary = entries[k]
		if l["turn"] != last_turn:
			last_turn = l["turn"]
			out.append("[color=%s][b]Turn %d[/b][/color]" % [_hex(FG), last_turn])
		out.append(String(l["msg"]).replace("[", "[lb]"))
	rtl.text = "\n".join(PackedStringArray(out))
	logp.add_child(rtl)
	var lp := _panel(logp)
	lp.size_flags_vertical = Control.SIZE_FILL
	cols.add_child(lp)


func _nums(a: Dictionary) -> String:
	var parts := ["HP %d/%d" % [a["hp"], a["maxHp"]]]
	if a["block"]:
		parts.append("Block %d" % a["block"])
	if a["weak"]:
		parts.append("Weak %d" % a["weak"])
	if a["strength"]:
		parts.append("Str %d" % a["strength"])
	return "  ".join(PackedStringArray(parts))


func _foe(s: Dictionary, i: int) -> PanelContainer:
	var e: Dictionary = s["enemies"][i]
	var targeted: bool = s["target"] == i and not e["dead"] and s["phase"] == "player"
	var v := _vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	var top := _hbox(8)
	top.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_child(_label(e["name"], 17, FG, _font_display))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_child(sp)
	top.add_child(_label(String(e["role"]).to_upper(), 11, FG_2, _font_display))
	v.add_child(top)
	v.add_child(_bar(e["hp"], e["maxHp"], BAD))
	v.add_child(_label(_nums(e), 12, FG_2, _font_mono))
	if not e["dead"]:
		var it = e["intent"]
		var is_edit: bool = it != null and it.has("edit")
		var il := _wrap_label(Combat.intent_text(db, s, i), 13, BAD if is_edit else FG)
		var ip := PanelContainer.new()
		ip.add_theme_stylebox_override("panel", _sb(MAT, BAD if is_edit else EDGE, 1, 6, 7))
		ip.mouse_filter = Control.MOUSE_FILTER_PASS
		ip.add_child(il)
		v.add_child(ip)
	var p := _panel(v, ACCENT if targeted else EDGE, 3 if targeted else 1)
	p.custom_minimum_size = Vector2(250, 0)
	if e["dead"]:
		p.modulate = Color(1, 1, 1, 0.4)
	else:
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.gui_input.connect(_on_foe_input.bind(i))
	return p


func _on_foe_input(event: InputEvent, i: int) -> void:
	if _is_left_click(event):
		var s: Dictionary = run["combat"]
		if not s["enemies"][i]["dead"]:
			s["target"] = i
			_refresh()


func _render_reward() -> void:
	var r: Dictionary = run["reward"]
	var v := _vbox(8)
	v.add_child(_h2("Fight won"))
	var line := "+%d Ink." % r["ink"]
	if not r["drops"].is_empty():
		line += "  Drops: %s." % ", ".join(PackedStringArray(r["drops"]))
	v.add_child(_wrap_label(line, 15, FG))
	v.add_child(_wrap_label("Pick a card to add to your deck, or skip.", 14))
	_body.add_child(_panel(v))
	var choices := _flow(14)
	for id in r["choices"]:
		var card := G.make_card(Run.card_def(db, id), id)
		choices.add_child(_card(card, {"click": "take", "width": 200}))
	_body.add_child(choices)
	var row := _hbox()
	row.add_child(_button("Skip", _skip_reward))
	_body.add_child(row)


func _render_workshop() -> void:
	var top := _vbox(6)
	var head := _hbox(12)
	head.add_child(_h2("Workshop"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(_label("Ink %d" % run["ink"], 18, ACCENT_FG, _font_mono))
	head.add_child(_button("Leave workshop  →", _leave_workshop, true))
	top.add_child(head)
	top.add_child(_wrap_label("Edits here are permanent. Pick a tool, then a chunk or a card.", 14))
	_body.add_child(_panel(top, ACCENT, 1))

	var tools := _hbox(8)
	for tool in WS_TOOLS:
		var tc := Edits.tool_cost(db, run, tool)
		var cost_txt: String = "free ×%d" % run["freeUses"][tool] if tc["free"] else ("+%d ink" % -tc["ink"] if tc["ink"] < 0 else "%d ink" % tc["ink"])
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = ws_tool == tool
		b.text = "%s · %s" % [tool.capitalize(), cost_txt]
		b.pressed.connect(_pick_ws_tool.bind(tool))
		tools.add_child(b)
	_body.add_child(tools)

	var hint: String = TOOL_HINT.get(ws_tool, "")
	if ws_tool == "glue":
		hint = "Glue: pick a chunk on your clipboard, then click a highlighted slot." if clip_sel < 0 else "Glue: click a highlighted %s slot, or + new clause." % run["clipboard"][clip_sel]["type"].capitalize()
	elif ws_tool == "merge":
		hint = "Merge: pick the first card." if merge_a == "" else "Merge: pick the card to fold into %s." % Edits.find_card(run, merge_a)["name"]
	_body.add_child(_wrap_label(hint, 14, FG))

	# clipboard
	var clip := _vbox(6)
	clip.add_child(_h3("Clipboard  %d/%d" % [run["clipboard"].size(), db["rules"]["clipboardSize"]]))
	var chips := _flow(6)
	for k in run["clipboard"].size():
		var ch: Dictionary = run["clipboard"][k]
		var chip := _hbox(0)
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = clip_sel == k
		b.text = G.chunk_label(db, ch)
		b.add_theme_color_override("font_color", Color(TYPE_COL[ch["type"]]))
		b.tooltip_text = "%s chunk" % String(ch["type"]).capitalize()
		b.pressed.connect(_pick_clip.bind(k))
		chip.add_child(b)
		var x := Button.new()
		x.text = "×"
		x.tooltip_text = "Drop this chunk"
		x.flat = true
		x.pressed.connect(_drop_clip.bind(k))
		chip.add_child(x)
		chips.add_child(chip)
	if run["clipboard"].is_empty():
		chips.add_child(_label("Empty. Cut or shred to fill it.", 13, FG_2))
	clip.add_child(chips)
	_body.add_child(_panel(clip))

	# deck
	_body.add_child(_h3("Your deck"))
	var glue_type := ""
	if ws_tool == "glue" and clip_sel >= 0:
		glue_type = run["clipboard"][clip_sel]["type"]
	var deck := _flow(12)
	for card in run["deck"]:
		var card_tool := ws_tool in ["merge", "shred"]
		deck.add_child(_card(card, {
			"chunks": ws_tool in CHUNK_TOOLS,
			"show_empty": ws_tool == "glue",
			"glue_type": glue_type,
			"click": "ws" if card_tool else "",
			"selected": card["uid"] == merge_a,
			"width": 176,
		}))
	_body.add_child(deck)


func _render_end() -> void:
	var won: bool = run["phase"] == "victory"
	var v := _vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := _label("You cut through the act." if won else "Defeated.", 34, GOOD if won else BAD, _font_display)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var nodes: Array = db["rules"]["run"]
	var info := _label("Reached node %d of %d with %d cards and %d Ink." % [mini(run["node"] + 1, nodes.size()), nodes.size(), run["deck"].size(), run["ink"]], 15, FG_2)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var b := _button("New run", _new_run, true)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	_body.add_child(_panel(v))


# ---------------------------------------------------------------- actions

func _enter() -> void:
	Run.enter_node(db, run)
	quick_tool = ""
	_refresh()


func _play(uid: String) -> void:
	_after(Combat.play_card(db, run["combat"], uid))


func _end_turn() -> void:
	quick_tool = ""
	_after(Combat.end_turn(db, run["combat"]))


func _toggle_quick(tool: String) -> void:
	quick_tool = "" if quick_tool == tool else tool
	_refresh()


func _finish_fight() -> void:
	Run.finish_combat(db, run)
	clip_sel = -1
	merge_a = ""
	_refresh()


func _leave_workshop() -> void:
	Run.leave_workshop(db, run)
	clip_sel = -1
	merge_a = ""
	_refresh()


func _pick_ws_tool(tool: String) -> void:
	ws_tool = tool
	merge_a = ""
	if tool != "glue":
		clip_sel = -1
	_refresh()


func _pick_clip(k: int) -> void:
	clip_sel = -1 if clip_sel == k else k
	ws_tool = "glue"
	merge_a = ""
	_refresh()


func _ws_chunk(uid: String, ci: int, slot: String) -> void:
	var res: Dictionary
	match ws_tool:
		"scissors":
			res = Edits.cut(db, run, uid, ci, slot)
		"mute":
			res = Edits.mute(db, run, uid, ci, slot)
		"invert":
			res = Edits.invert(db, run, uid, ci, slot)
		"glue":
			if clip_sel < 0:
				_toast_msg("Pick a chunk on your clipboard first.")
				return
			if slot == "new":
				slot = run["clipboard"][clip_sel]["type"]
			res = Edits.glue(db, run, uid, ci, slot, clip_sel)
			if res["ok"]:
				clip_sel = -1
		_:
			return
	_after(res)


func _is_left_click(event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	return mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed


func _skip_reward() -> void:
	Run.take_reward(db, run, "")
	_refresh()


func _drop_clip(k: int) -> void:
	if clip_sel == k:
		clip_sel = -1
	elif clip_sel > k:
		clip_sel -= 1
	Edits.drop_clip(run, k)
	_refresh()


func _ws_card(uid: String) -> void:
	match ws_tool:
		"merge":
			if merge_a == "":
				merge_a = uid
				_refresh()
			elif merge_a == uid:
				merge_a = ""
				_refresh()
			else:
				var a := merge_a
				merge_a = ""
				_after(Edits.merge(db, run, a, uid))
		"shred":
			_after(Edits.shred(db, run, uid))
