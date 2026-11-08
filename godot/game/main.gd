## Root of the game: the cutting mat, a top bar, the current screen and the FX layer.
## Screens are built in code and swapped by route(), which reads Game.run.phase.
class_name Main
extends Control

const MAT := preload("res://shaders/mat.gdshader")

var bg: ColorRect
var bg_mat: ShaderMaterial
var stage: Control
var top: HBoxContainer
var fx: Fx
var screen: Control
var _stats: HBoxContainer


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg_mat = ShaderMaterial.new()
	bg_mat.shader = MAT
	bg.material = bg_mat
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
	stage = Control.new()
	stage.set_anchors_preset(PRESET_FULL_RECT)
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(stage)
	_build_top()
	fx = Fx.new()
	add_child(fx)
	fx.shake_target = stage
	resized.connect(_on_resized)
	_on_resized()
	Game.changed.connect(func(): if screen and screen.has_method("refresh"): screen.refresh())
	var auto: String = OS.get_environment("CTD_AUTOSTART")
	if auto != "":
		return  # a test harness drives the game
	show_title()


func _on_resized() -> void:
	bg_mat.set_shader_parameter("rect_size", size)


func _build_top() -> void:
	top = Kit.hbox(18)
	top.position = Vector2(24, 14)
	top.mouse_filter = MOUSE_FILTER_IGNORE
	var logo := Logo.new()
	logo.font_size = 24
	logo.custom_minimum_size = Vector2(190, 34)
	top.add_child(logo)
	_stats = Kit.hbox(18)
	top.add_child(_stats)
	add_child(top)


func update_top() -> void:
	for c in _stats.get_children():
		c.queue_free()
	var r: Dictionary = Game.run
	top.visible = not r.is_empty() and screen != null and not (screen is TitleScreen)
	if r.is_empty():
		return
	_stats.add_child(_stat("HP", "%d/%d" % [r.hp, r.maxHp], Pal.BAD))
	_stats.add_child(_stat("INK", str(r.ink), Color("#7fa6ff")))
	_stats.add_child(_stat("DECK", str(r.deck.size()), Pal.FG))
	_stats.add_child(_stat("CLIP", "%d/%d" % [r.clipboard.size(), Game.db.rules.clipboardSize], Pal.ACCENT))
	var node: int = mini(r.node + 1, Game.db.rules.run.size())
	_stats.add_child(_stat("NODE", "%d/%d" % [node, Game.db.rules.run.size()], Pal.FG2))


func _stat(k: String, v: String, col: Color) -> Control:
	var h := Kit.hbox(6)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	var kl := Kit.label(k, "mono_bold", 12, Pal.FG2)
	var vl := Kit.label(v, "mono_bold", 17, col)
	h.add_child(kl)
	h.add_child(vl)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	return h


func set_screen(s: Control) -> void:
	var old := screen
	screen = s
	s.set_anchors_preset(PRESET_FULL_RECT)
	s.modulate.a = 0.0
	stage.add_child(s)
	if s.has_method("build"):
		s.build(self)
	update_top()
	var tw := create_tween()
	if old:
		tw.tween_property(old, "modulate:a", 0.0, 0.15)
		tw.tween_callback(old.queue_free)
	s.position.y = 18
	tw.tween_property(s, "modulate:a", 1.0, 0.22)
	tw.parallel().tween_property(s, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func show_title() -> void:
	set_screen(TitleScreen.new())


func start_tutorial(back_to := "title") -> void:
	var w := WorkshopScreen.new()
	w.tutorial = true
	w.tutorial_back = back_to
	set_screen(w)


## Show the screen that matches the run's phase.
func route() -> void:
	Game.save()
	match Game.run.get("phase", ""):
		"map":
			set_screen(MapScreen.new())
		"combat":
			set_screen(CombatScreen.new())
		"reward":
			set_screen(RewardScreen.new())
		"workshop":
			set_screen(WorkshopScreen.new())
		"victory", "defeat":
			set_screen(EndScreen.new())
		_:
			show_title()
