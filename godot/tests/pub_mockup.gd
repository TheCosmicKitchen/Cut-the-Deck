## Paper-world mockup: one card per publication, then cards cut up and
## rearranged with the real Workshop tools so pasted words keep their source style.
## godot --path godot res://tests/pub_mockup.tscn -- out.png
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
	bm.shader = load("res://shaders/desk.gdshader")
	bm.set_shader_parameter("rect_size", root.size)
	bg.material = bm
	root.add_child(bg)

	var mk := func(id, uid): return Grammar.make_card(RunState.card_def(db, id), uid)
	var row1 := [["reckless_swing", "Newspaper"], ["jab", "Comics"], ["blood_price", "Pulp Horror"],
		["all_in", "Zine"], ["bulwark", "Instruction Manual"], ["second_wind", "Almanac"]]
	for i in row1.size():
		var c: Dictionary = mk.call(row1[i][0], "p%d" % i)
		if c.base == "blood_price":
			c.art = "cheap_shot"
		_place(root, db, c, Vector2(84 + i * 300, 52), row1[i][1])

	var cut := remix(db)
	var caps := ["Jab: a 9 and 'to ALL enemies'\nfrom the paper, 'three times' from a zine",
		"Reckless Swing: lost its target; a Block\nfrom the manual, 'When drawn' from the almanac",
		"Second Wind: trigger cut out; 'At end\nof turn' from the manual, a 4 from pulp",
		"All In: repeat cut out; an 'if' and a\n'Draw' cut from pulp horror"]
	for i in cut.size():
		_place(root, db, cut[i], Vector2(234 + i * 380, 566), caps[i])

	for i in 30:
		await get_tree().process_frame
	vp.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()


func _place(root: Control, db: Dictionary, card: Dictionary, pos: Vector2, cap: String) -> void:
	var pc := PubCard.new().setup(db, card)
	pc.position = pos
	pc.rotation = deg_to_rad(((abs(hash(card.uid)) % 5) - 2) * 0.6)
	root.add_child(pc)
	var l := Look.label(cap, "body", 15, Color("#fbe9d0"))
	l.position = pos + Vector2(0, 414)
	root.add_child(l)


## The four cut-up cards, edited with the real tools.
static func remix(db: Dictionary) -> Array:
	var mk := func(id, uid): return Grammar.make_card(RunState.card_def(db, id), uid)
	var run := {"deck": [mk.call("reckless_swing", "r"), mk.call("jab", "j"), mk.call("blood_price", "bp"),
		mk.call("all_in", "a"), mk.call("bulwark", "b"), mk.call("second_wind", "w"), mk.call("exploit", "e")],
		"ink": 99, "clipboard": [], "freeUses": {}, "sandbox": true}
	var ok := func(r: Dictionary, what: String):
		if not r.ok:
			push_error("%s: %s" % [what, r.error])
	# move a chunk from one card's slot to another's; keep only `keep` on the clipboard
	var move := func(from_uid: String, fci: int, to_uid: String, tci: int, slot: String):
		ok.call(Edits.cut(db, run, from_uid, fci, slot), "cut %s %s" % [from_uid, slot])
		ok.call(Edits.glue(db, run, to_uid, tci, slot, run.clipboard.size() - 1), "glue %s %s" % [to_uid, slot])
	var tidy := func():
		var kept := []
		for c in run.clipboard:
			if c.type == "amount" and c.get("from", "") == "jab":
				kept.append(c)
		run.clipboard = kept
	move.call("r", 0, "j", 0, "amount")     # Jab's 3 goes to the clipboard
	tidy.call()
	move.call("a", 0, "j", 0, "repeat")
	tidy.call()
	move.call("r", 0, "j", 0, "target")
	tidy.call()
	# Jab's old 3 into Reckless Swing's empty amount
	ok.call(Edits.glue(db, run, "r", 0, "amount", 0), "glue 3")
	tidy.call()
	move.call("b", 0, "r", 1, "verb")
	tidy.call()
	move.call("w", 0, "r", 1, "trigger")
	tidy.call()
	move.call("b", 1, "w", 1, "trigger")
	tidy.call()
	move.call("bp", 1, "w", 1, "amount")
	tidy.call()
	move.call("e", 0, "a", 0, "condition")
	tidy.call()
	move.call("bp", 0, "a", 1, "verb")
	return [Edits.find_card(run, "j"), Edits.find_card(run, "r"), Edits.find_card(run, "w"), Edits.find_card(run, "a")]
