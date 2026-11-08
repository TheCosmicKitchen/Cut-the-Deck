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

	var rows := [["rough", "Glued slips", "rough hand-cut paper,\\nwet glue shine"], ["label", "Taped labels", "cut paper held\\nwith a strip of tape"]]
	var captions := ["Untouched card:\nprinted text, cut guides,\n'if' arrow", "Strike after its\nTarget was cut out", "Strike with 'to ALL enemies'\n(from Reckless Swing) and\n'When drawn' (from Second Wind)", "Reckless Swing: target\ncut, drawback muted", "Jab Defend: a 9 from Bulwark,\n'if' from Opening Gambit,\ntypo, black-out, enemy edit"]
	for r in rows.size():
		var y := 70 + r * 500
		var head := Look.label(rows[r][1], "title", 34, Look.INK)
		head.position = Vector2(40, y + 20)
		root.add_child(head)
		var sub := Look.label(rows[r][2].replace("\\n", "\n"), "body", 20, Look.INK2)
		sub.position = Vector2(42, y + 70)
		root.add_child(sub)
		var cards := _cards(db)
		for i in cards.size():
			var c: Dictionary = cards[i]
			var o: Dictionary = c.opts.duplicate()
			o.slip_style = rows[r][0]
			var cv := CardView.new().setup(db, c.card, "hand", o)
			cv.position = Vector2(300 + i * 318, y)
			root.add_child(cv)
			var cap := Look.label(captions[i], "body", 17, Look.INK2)
			cap.position = Vector2(300 + i * 318, y + 372)
			root.add_child(cap)

	for i in 10:
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
