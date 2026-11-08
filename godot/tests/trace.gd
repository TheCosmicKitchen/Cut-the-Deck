## Prints the same deterministic trace as tools/trace.mjs, using the GDScript engine.
## godot --headless --path godot --script res://tests/trace.gd -- out.txt
extends SceneTree

var db: Dictionary
var out := PackedStringArray()


func p(s: String) -> void:
	out.append(s)


func cost_str(card: Dictionary) -> String:
	var c = Grammar.card_cost(db, card)
	return ("%d%s" % [c.cost, "+X" if c.x else ""]) if c else "broken"


func res_str(r: Dictionary) -> String:
	if r.ok:
		return "ok" + ((" " + r.note) if r.has("note") else "")
	return r.error


func workshop(run: Dictionary, step: int) -> void:
	var deck: Array = run.deck
	var first: Dictionary = deck[0]
	var results := []
	if step % 2 == 0:
		var slot = null
		if not first.clauses.is_empty():
			for s in Grammar.SLOTS:
				if first.clauses[0][s] and s != "verb":
					slot = s
					break
		if slot:
			results.append(Edits.cut(db, run, first.uid, 0, slot))
		var clip: int = run.clipboard.size() - 1
		var tgt = null
		for c in deck:
			if c.uid != first.uid and not c.clauses.is_empty() and clip >= 0:
				tgt = c
				break
		if tgt and clip >= 0:
			results.append(Edits.glue(db, run, tgt.uid, 0, run.clipboard[clip].type, clip))
	else:
		var last: Dictionary = deck[deck.size() - 1]
		if not last.clauses.is_empty() and last.clauses[0].verb:
			results.append(Edits.invert(db, run, last.uid, 0, "verb"))
		if not last.clauses.is_empty() and last.clauses[0].amount:
			results.append(Edits.mute(db, run, last.uid, 0, "amount"))
		if deck.size() > 3:
			results.append(Edits.merge(db, run, deck[1].uid, deck[2].uid))
		if deck.size() > 8:
			results.append(Edits.shred(db, run, deck[deck.size() - 2].uid))
	for r in results:
		p("  edit: " + res_str(r))


func _init() -> void:
	db = Db.load_all()
	for seed in range(1, 26):
		p("== run %d" % seed)
		var run := RunState.new_run(db, seed * 7919)
		var ws_step := 0
		while run.phase != "victory" and run.phase != "defeat":
			match run.phase:
				"map":
					RunState.enter_node(db, run)
				"combat":
					var s: Dictionary = run.combat
					var guard := 0
					var act := 0
					while s.phase == "player" and guard < 80:
						guard += 1
						for i in s.enemies.size():
							if not s.enemies[i].dead:
								p("  intent %s: %s" % [s.enemies[i].name, Combat.intent_text(db, s, i)])
						act += 1
						if act % 4 == 0 and not s.hand.is_empty():
							var uid: String = s.hand[s.hand.size() - 1]
							if not s.cards[uid].clauses.is_empty():
								var cl: Dictionary = s.cards[uid].clauses[0]
								var slot := ""
								for x in Grammar.SLOTS:
									if cl[x]:
										slot = x
										break
								var r := Combat.combat_edit(db, s, "invert" if act % 8 == 0 else "mute", uid, 0, slot)
								p("  cedit: " + ("ok" if r.ok else r.error))
						var alive := Combat.alive(s)
						var target: int = alive[act % alive.size()]
						var pl = null
						for u in s.hand:
							if Combat.play_info(db, s, u).can:
								pl = u
								break
						if pl:
							Combat.play_card(db, s, pl, target)
						else:
							Combat.end_turn(db, s)
					for l in s.log:
						p("  [%d] %s" % [l.turn, l.msg])
					RunState.finish_combat(db, run)
					var clip := []
					for c in run.clipboard:
						clip.append("%s:%s%s" % [c.type, str(c.id), "!" if c.get("neg", false) else ""])
					p("  after fight: phase=%s hp=%d ink=%d free=%s clip=%s" % [run.phase, run.hp, run.ink, JSON.stringify(run.freeUses, "", false), ",".join(clip)])
				"reward":
					p("  reward: %s drops=%s" % [",".join(run.reward.choices), "; ".join(run.reward.drops)])
					RunState.take_reward(db, run, run.reward.choices[seed % 3])
				"workshop":
					workshop(run, ws_step)
					ws_step += 1
					for c in run.deck:
						p("  deck %s %s %s: %s" % [c.uid, cost_str(c), c.name, Grammar.card_text(db, c)])
					RunState.leave_workshop(db, run)
		p("  end: %s node=%d hp=%d ink=%d" % [run.phase, run.node, run.hp, run.ink])
	var f := Fuzz.run(db, 120, 6, 99)
	p("fuzz ok=%s turns=%d plays=%.4f draws=%.4f res=%.4f net=%d" % [str(f.ok).to_lower(), f.turnsPlayed, f.maxRatio.plays, f.maxRatio.draws, f.maxRatio.resolutions, f.safetyNet])
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if not args.is_empty() else "user://trace.txt"
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_string("\n".join(out) + "\n")
	fa.close()
	quit()
