## Style mockup for the cut-and-paste look. Every edited card is made with the
## real Workshop tools, so holes and pasted slips come from the engine.
## godot --path godot res://tests/mockup.tscn -- out.png
extends Node


func _ready() -> void:
	var db := Db.load_all()
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var root := Control.new()
	root.size = Vector2(1920, 1080)
	vp.add_child(root)
	var bg := ColorRect.new()
	bg.size = root.size
	var bm := ShaderMaterial.new()
	bm.shader = load("res://shaders/bg.gdshader")
	bm.set_shader_parameter("rect_size", root.size)
	bg.material = bm
	root.add_child(bg)

	var head := Look.label("Cut-paper scenes, one per card, starring Pip", "title", 30, Look.INK)
	head.position = Vector2(60, 14)
	root.add_child(head)
	var ids := ["strike", "defend", "jab", "reckless_swing", "second_wind", "cheap_shot", "bulwark", "opening"]
	for i in ids.size():
		var card := Grammar.make_card(RunState.card_def(db, ids[i]), "m%d" % i)
		var cv := CardView.new().setup(db, card, "hand", {})
		cv.position = Vector2(150 + (i % 4) * 430, 66 + (i / 4) * 500)
		root.add_child(cv)

	for i in 20:
		await get_tree().process_frame
	vp.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()


func _card(db: Dictionary, id: String, uid: String) -> Dictionary:
	return Grammar.make_card(RunState.card_def(db, id), uid)


func _cards(db: Dictionary) -> Array:
	var run := {"deck": [_card(db, "cheap_shot", "c"), _card(db, "strike", "s1"), _card(db, "strike", "s2"),
		_card(db, "reckless_swing", "r"), _card(db, "jab", "j"), _card(db, "defend", "d"),
		_card(db, "second_wind", "w"), _card(db, "bulwark", "b"), _card(db, "opening", "o")],
		"ink": 99, "clipboard": [], "freeUses": {}, "sandbox": true}
	var clip := func(): return run.clipboard.size() - 1
	# Strike 2: "to ALL enemies" cut from Reckless Swing, "When drawn" from Second Wind
	Edits.cut(db, run, "r", 0, "target")
	Edits.glue(db, run, "s2", 0, "target", clip.call())
	Edits.cut(db, run, "w", 0, "trigger")
	Edits.glue(db, run, "s2", 0, "trigger", clip.call())
	# Strike 1: its target cut out, leaving a hole
	Edits.cut(db, run, "s1", 0, "target")
	Edits.mute(db, run, "r", 1, "verb")
	# Jab: amount 9 from Bulwark (a Block card), "if this is your first card" from Opening Gambit
	Edits.cut(db, run, "b", 0, "amount")
	Edits.glue(db, run, "j", 0, "amount", clip.call())
	Edits.cut(db, run, "o", 0, "condition")
	Edits.glue(db, run, "j", 0, "condition", clip.call())
	Edits.merge(db, run, "j", "d")
	var j: Dictionary = Edits.find_card(run, "j")
	j.clauses[0].repeat.muted = true
	j.clauses[0].repeat.redacted = true
	j.clauses[1].amount.enemyEdit = true
	j.clauses[1].amount.id = 4
	return [
		{"card": Edits.find_card(run, "c"), "opts": {}},
		{"card": Edits.find_card(run, "s1"), "opts": {}},
		{"card": Edits.find_card(run, "s2"), "opts": {}},
		{"card": Edits.find_card(run, "r"), "opts": {}},
		{"card": j, "opts": {"tele": [{"enemy": 0, "ci": 1, "slot": "verb"}], "enemy_names": {0: "Inverter"}}},
	]


## Strike, edited one step at a time with the real tools. Each entry is a snapshot.
static func sequence(db: Dictionary) -> Array:
	var mk := func(id, uid): return Grammar.make_card(RunState.card_def(db, id), uid)
	var run := {"deck": [mk.call("strike", "s"), mk.call("reckless_swing", "r"), mk.call("flurry", "f"),
		mk.call("bulwark", "b"), mk.call("exploit", "e"), mk.call("defend", "d")],
		"ink": 99, "clipboard": [], "freeUses": {}, "sandbox": true}
	var last := func(): return run.clipboard.size() - 1
	var out := []
	var snap := func(cap): out.append({"card": Edits.find_card(run, "s").duplicate(true), "caption": cap})
	snap.call("Strike as printed")
	Edits.cut(db, run, "s", 0, "target")
	Edits.cut(db, run, "r", 0, "target")
	Edits.glue(db, run, "s", 0, "target", last.call())
	snap.call("+ 'to ALL enemies'\n(Reckless Swing)")
	Edits.cut(db, run, "f", 0, "repeat")
	Edits.glue(db, run, "s", 0, "repeat", last.call())
	snap.call("+ 'three times'\n(Flurry)")
	Edits.cut(db, run, "b", 0, "amount")
	Edits.glue(db, run, "s", 0, "amount", last.call())
	snap.call("6 swapped for a 9\n(Bulwark)")
	Edits.cut(db, run, "e", 0, "condition")
	Edits.glue(db, run, "s", 0, "condition", last.call())
	snap.call("+ 'if an enemy is Weak'\n(Exploit)")
	Edits.merge(db, run, "s", "d")
	snap.call("merged with Defend")
	return out
