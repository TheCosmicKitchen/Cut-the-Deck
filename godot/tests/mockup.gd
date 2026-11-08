## Style mockup: title box, five cards, a dialog box. Saves a 1920x1080 PNG.
## godot --path godot res://tests/mockup.tscn -- out.png
extends Node


func _ready() -> void:
	var db := Db.load_all()
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_2d = Viewport.MSAA_DISABLED
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

	var title := Look.candy(Vector2(640, 104), "ui", Vector2(12, 12), 16.0, 20.0)
	title.position = Vector2(640, 26)
	root.add_child(title)
	var tl := Look.label("Cut the Deck", "title", 60, Look.INK)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.size = Vector2(640, 104)
	tl.position = Vector2(0, -3)
	title.add_child(tl)

	var cards := _cards(db)
	for i in cards.size():
		var c: Dictionary = cards[i]
		var cv := CardView.new().setup(db, c.card, "hand", c.opts)
		cv.position = Vector2(150 + i * 334, 190)
		root.add_child(cv)
		if i == 1:
			cv.set_selected(true)

	var dlg := Look.candy(Vector2(1640, 300), "ui", Vector2(14, 14), 20.0, 22.0)
	dlg.position = Vector2(140, 720)
	root.add_child(dlg)
	var txt := Look.label("Cut chunks off your cards and glue them onto others! A card without a Verb can't be played, so glue one back in. Watch out: enemies edit your cards too!", "body_bold", 36, Look.INK)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.position = Vector2(64, 50)
	txt.size = Vector2(1500, 200)
	dlg.add_child(txt)
	var star := TextureRect.new()
	star.texture = Px.sprite("star")
	star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	star.stretch_mode = TextureRect.STRETCH_SCALE
	star.size = Vector2(36, 36)
	star.position = Vector2(1640 - 74, 300 - 70)
	dlg.add_child(star)

	for i in 10:
		await get_tree().process_frame
	vp.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()


func _card(db: Dictionary, id: String, uid: String) -> Dictionary:
	return Grammar.make_card(RunState.card_def(db, id), uid)


func _cards(db: Dictionary) -> Array:
	var run := {"deck": [_card(db, "jab", "m5"), _card(db, "defend", "m6")], "ink": 99, "clipboard": [], "freeUses": {}, "sandbox": true}
	Edits.merge(db, run, "m5", "m6")
	var ed: Dictionary = run.deck[0]
	ed.clauses[0].amount.id = 4
	ed.clauses[0].amount.enemyEdit = true
	ed.clauses.append(Grammar.parse_clause({"verb": "deal", "amount": 6, "target": "self"}))
	ed.clauses[2].verb.muted = true
	ed.clauses[0].repeat.muted = true
	ed.clauses[0].repeat.redacted = true
	return [
		{"card": _card(db, "strike", "a"), "opts": {}},
		{"card": _card(db, "reckless_swing", "b"), "opts": {}},
		{"card": _card(db, "cheap_shot", "c"), "opts": {}},
		{"card": _card(db, "second_wind", "d"), "opts": {}},
		{"card": ed, "opts": {"tele": [{"enemy": 0, "ci": 1, "slot": "verb"}], "enemy_names": {0: "Inverter"}}},
	]
