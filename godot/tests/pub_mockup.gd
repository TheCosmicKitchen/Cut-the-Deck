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

	var names := ["Newspaper", "Comics", "Pulp Horror", "Zine", "Instruction Manual", "Almanac"]
	var plain := six(db)
	var cut := swapped(db)
	var notes := ["+ 'to an enemy', 'Draw'", "+ 'to ALL', 'three times', a 2", "+ 'Deal', a 5",
		"+ 'twice', a 2", "+ a 4, a 3, 'When drawn'", "+ 'At end of turn', an X;\none trigger cut out"]
	for i in 6:
		_place(root, db, plain[i], Vector2(84 + i * 300, 40), names[i])
		_place(root, db, cut[i], Vector2(84 + i * 300, 560), notes[i])

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


## One card of each publication.
static func six(db: Dictionary) -> Array:
	var run := _run(db)
	return run.deck


static func _run(db: Dictionary) -> Dictionary:
	var mk := func(id, uid): return Grammar.make_card(RunState.card_def(db, id), uid)
	var deck := [mk.call("reckless_swing", "R"), mk.call("jab", "J"), mk.call("blood_price", "B"),
		mk.call("all_in", "A"), mk.call("defend", "D"), mk.call("second_wind", "W")]
	# mock: a manual card that repeats and has a second step, to show ×2 and steps
	deck[4].clauses[0].repeat = {"type": "repeat", "id": "twice"}
	deck[4].clauses.append(Grammar.parse_clause({"trigger": "end_turn", "verb": "lose_block", "amount": 2}))
	return {"deck": deck, "ink": 99, "clipboard": [], "freeUses": {}, "sandbox": true}


## The same six, with words swapped between them using the real tools.
static func swapped(db: Dictionary) -> Array:
	var run := _run(db)
	var swap := func(u1: String, c1: int, s1: String, u2: String, c2: int, s2: String):
		Edits.cut(db, run, u1, c1, s1)
		Edits.cut(db, run, u2, c2, s2)
		var r1: Dictionary = Edits.glue(db, run, u2, c2, s2, 0)
		var r2: Dictionary = Edits.glue(db, run, u1, c1, s1, 0)
		if not r1.ok or not r2.ok:
			push_error("swap %s/%s: %s %s" % [u1, u2, r1.get("error", ""), r2.get("error", "")])
		run.clipboard.clear()
	swap.call("R", 0, "target", "J", 0, "target")
	swap.call("J", 0, "repeat", "A", 0, "repeat")
	swap.call("B", 0, "verb", "R", 1, "verb")
	swap.call("D", 0, "amount", "B", 1, "amount")
	swap.call("W", 0, "trigger", "D", 1, "trigger")
	swap.call("A", 0, "amount", "W", 0, "amount")
	swap.call("J", 0, "amount", "D", 1, "amount")
	# and one trigger simply cut out, leaving a hole
	Edits.cut(db, run, "W", 1, "trigger")
	run.clipboard.clear()
	return run.deck


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
