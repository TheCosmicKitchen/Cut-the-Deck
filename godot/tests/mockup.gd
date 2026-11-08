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
	var captions := ["Untouched card:\nprinted text, cut guides,\n'if' arrow", "Strike after its\nTarget was cut out", "Strike with 'to ALL\nenemies' glued in", "Reckless Swing: target\ncut, drawback muted", "Jab Defend: glued\n'unless', typo, black-out,\nenemy about to edit"]
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
		_card(db, "reckless_swing", "r"), _card(db, "jab", "j"), _card(db, "defend", "d")],
		"ink": 99, "clipboard": [], "freeUses": {}, "sandbox": true}
	Edits.cut(db, run, "r", 0, "target")                       # clipboard: to ALL enemies
	Edits.glue(db, run, "s2", 0, "target", 0)                  # glued in; old target to clipboard
	Edits.cut(db, run, "s1", 0, "target")                      # hole on Strike
	Edits.mute(db, run, "r", 1, "verb")
	run.clipboard.append({"type": "condition", "id": "has_block", "neg": true})
	Edits.glue(db, run, "j", 0, "condition", run.clipboard.size() - 1)
	Edits.merge(db, run, "j", "d")
	var j: Dictionary = Edits.find_card(run, "j")
	j.clauses[0].amount.id = 4
	j.clauses[0].amount.enemyEdit = true
	j.clauses[0].repeat.muted = true
	j.clauses[0].repeat.redacted = true
	return [
		{"card": Edits.find_card(run, "c"), "opts": {}},
		{"card": Edits.find_card(run, "s1"), "opts": {}},
		{"card": Edits.find_card(run, "s2"), "opts": {}},
		{"card": Edits.find_card(run, "r"), "opts": {}},
		{"card": j, "opts": {"tele": [{"enemy": 0, "ci": 1, "slot": "verb"}], "enemy_names": {0: "Inverter"}}},
	]
