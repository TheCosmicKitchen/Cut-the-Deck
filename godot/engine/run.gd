# One act: a fixed list of nodes from rules.run. Port of engine/run.js.
# The run owns the deck, Ink, clipboard and HP; each fight works on a copy of the deck.

const G := preload("res://godot/engine/grammar.gd")
const Combat := preload("res://godot/engine/combat.gd")
const Rng := preload("res://godot/engine/rng.gd")


static func enemy_defs(db: Dictionary, keys: Array) -> Array:
	var out := []
	for key in keys:
		var d: Dictionary = db["enemies"]["enemies"][key].duplicate(true)
		d["key"] = key
		out.append(d)
	return out


static func card_def(db: Dictionary, id: String):
	for c in db["cards"]["cards"]:
		if c["id"] == id:
			return c
	return null


static func new_card_uid(run: Dictionary) -> String:
	var uid := "c%d" % run["nextUid"]
	run["nextUid"] += 1
	return uid


static func new_run(db: Dictionary, rng_seed := -1, sandbox := false) -> Dictionary:
	if rng_seed < 0:
		rng_seed = int(Time.get_unix_time_from_system() * 1000.0) % 2147483647
	var run := {
		"seed": rng_seed,
		"hp": db["rules"]["player"]["hp"],
		"maxHp": db["rules"]["player"]["hp"],
		"deck": [],
		"ink": db["rules"]["ink"]["start"],
		"clipboard": [],
		"freeUses": {},
		"node": 0,
		"phase": "map",
		"combat": null,
		"reward": null,
		"sandbox": sandbox,
		"nextUid": 1,
	}
	for entry in db["cards"]["starterDeck"]:
		for k in entry["copies"]:
			run["deck"].append(G.make_card(card_def(db, entry["card"]), new_card_uid(run)))
	return run


static func _next_seed(run: Dictionary) -> int:
	var s: int = run["seed"]
	run["seed"] += 1
	return s


static func current_node(db: Dictionary, run: Dictionary):
	var nodes: Array = db["rules"]["run"]
	return nodes[run["node"]] if run["node"] < nodes.size() else null


static func enter_node(db: Dictionary, run: Dictionary) -> void:
	var node = current_node(db, run)
	if node == null:
		return
	if node["type"] == "workshop":
		run["ink"] += db["rules"]["ink"]["workshopBonus"]
		run["phase"] = "workshop"
		return
	run["combat"] = Combat.start_combat(db, run["deck"], enemy_defs(db, node["enemies"]), _next_seed(run), {"hp": run["hp"], "maxHp": run["maxHp"]})
	run["phase"] = "combat"


# Call once the fight's phase is "won" or "lost".
static func finish_combat(db: Dictionary, run: Dictionary) -> void:
	var s: Dictionary = run["combat"]
	var node: Dictionary = current_node(db, run)
	run["hp"] = s["player"]["hp"]
	if s["phase"] == "lost":
		run["phase"] = "defeat"
		return
	if node["type"] == "boss":
		run["phase"] = "victory"
		return
	var gained: int = db["rules"]["ink"]["perElite"] if node["type"] == "elite" else db["rules"]["ink"]["perFight"]
	run["ink"] += gained
	var drops := []
	for key in node["enemies"]:
		var d: Dictionary = db["enemies"]["enemies"][key].get("drops", {})
		var tools: Dictionary = d.get("tools", {})
		for tool in tools:
			run["freeUses"][tool] = run["freeUses"].get(tool, 0) + tools[tool]
			drops.append("a free %s" % tool)
		if d.has("chunk"):
			if run["clipboard"].size() < db["rules"]["clipboardSize"]:
				run["clipboard"].append(G.strip_chunk(d["chunk"]))
				drops.append("a %s chunk" % d["chunk"]["type"])
			else:
				drops.append("a %s chunk (lost: clipboard full)" % d["chunk"]["type"])
	var pool := []
	for c in db["cards"]["cards"]:
		if c["pool"] == "reward":
			pool.append(c)
	var rs := {"seed": _next_seed(run)}
	var choices := []
	for c in Rng.shuffle(rs, pool).slice(0, db["rules"]["rewardChoices"]):
		choices.append(c["id"])
	run["reward"] = {"ink": gained, "drops": drops, "choices": choices}
	run["phase"] = "reward"


static func take_reward(db: Dictionary, run: Dictionary, card_id: String) -> void:
	if card_id != "":
		run["deck"].append(G.make_card(card_def(db, card_id), new_card_uid(run)))
	run["reward"] = null
	run["combat"] = null
	run["phase"] = "workshop"


static func leave_workshop(db: Dictionary, run: Dictionary) -> void:
	run["node"] += 1
	run["phase"] = "victory" if run["node"] >= db["rules"]["run"].size() else "map"


static func add_card_to_deck(run: Dictionary, card: Dictionary) -> Dictionary:
	var c := G.clone_card(card)
	c["uid"] = new_card_uid(run)
	run["deck"].append(c)
	return c
