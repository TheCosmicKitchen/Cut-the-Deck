## One act: a fixed list of nodes from rules.run. Port of engine/run.js.
## The run owns the deck, Ink, clipboard and HP; each fight works on a copy of the deck.
class_name RunState


static func enemy_defs(db: Dictionary, keys: Array) -> Array:
	var out := []
	for key in keys:
		var d: Dictionary = db.enemies.enemies[key].duplicate(true)
		d.key = key
		out.append(d)
	return out


static func card_def(db: Dictionary, id: String) -> Variant:
	for c in db.cards.cards:
		if c.id == id:
			return c
	return null


static func new_card_uid(run: Dictionary) -> String:
	var uid := "c%d" % run.nextUid
	run.nextUid += 1
	return uid


static func new_run(db: Dictionary, seed: int = -1, sandbox := false) -> Dictionary:
	if seed < 0:
		seed = int(Time.get_unix_time_from_system() * 1000.0) % 2147483647
	var run := {
		"seed": seed,
		"hp": db.rules.player.hp,
		"maxHp": db.rules.player.hp,
		"deck": [],
		"ink": db.rules.ink.start,
		"clipboard": [],
		"freeUses": {},
		"node": 0,
		"phase": "map",
		"combat": null,
		"reward": null,
		"sandbox": sandbox,
		"nextUid": 1,
	}
	for entry in db.cards.starterDeck:
		for k in entry.copies:
			run.deck.append(Grammar.make_card(card_def(db, entry.card), new_card_uid(run)))
	return run


static func current_node(db: Dictionary, run: Dictionary) -> Variant:
	return db.rules.run[run.node] if run.node < db.rules.run.size() else null


static func enter_node(db: Dictionary, run: Dictionary) -> void:
	var node = current_node(db, run)
	if not node:
		return
	if node.type == "workshop":
		run.ink += db.rules.ink.workshopBonus
		run.phase = "workshop"
		return
	var seed: int = run.seed
	run.seed += 1
	run.combat = Combat.start(db, run.deck, enemy_defs(db, node.enemies), seed, {"hp": run.hp, "maxHp": run.maxHp})
	run.phase = "combat"


## Call once the fight's phase is "won" or "lost".
static func finish_combat(db: Dictionary, run: Dictionary) -> void:
	var s: Dictionary = run.combat
	var node: Dictionary = current_node(db, run)
	run.hp = s.player.hp
	if s.phase == "lost":
		run.phase = "defeat"
		return
	if node.type == "boss":
		run.phase = "victory"
		return
	var gained: int = db.rules.ink.perElite if node.type == "elite" else db.rules.ink.perFight
	run.ink += gained
	var drops := []
	for key in node.enemies:
		var d: Dictionary = db.enemies.enemies[key].get("drops", {})
		var tools: Dictionary = d.get("tools", {})
		for tool in tools:
			run.freeUses[tool] = run.freeUses.get(tool, 0) + tools[tool]
			drops.append("a free %s" % tool)
		if d.has("chunk"):
			if run.clipboard.size() < db.rules.clipboardSize:
				run.clipboard.append(Grammar.strip_chunk(d.chunk))
				drops.append("a %s chunk" % d.chunk.type)
			else:
				drops.append("a %s chunk (lost: clipboard full)" % d.chunk.type)
	var pool := []
	for c in db.cards.cards:
		if c.pool == "reward":
			pool.append(c)
	var rs := {"seed": run.seed}
	run.seed += 1
	var choices := []
	for c in Rng.shuffle(rs, pool).slice(0, db.rules.rewardChoices):
		choices.append(c.id)
	run.reward = {"ink": gained, "drops": drops, "choices": choices}
	run.phase = "reward"


static func take_reward(db: Dictionary, run: Dictionary, card_id) -> void:
	if card_id:
		run.deck.append(Grammar.make_card(card_def(db, card_id), new_card_uid(run)))
	run.reward = null
	run.combat = null
	run.phase = "workshop"


static func leave_workshop(db: Dictionary, run: Dictionary) -> void:
	run.node += 1
	run.phase = "victory" if run.node >= db.rules.run.size() else "map"


static func add_card_to_deck(db: Dictionary, run: Dictionary, card: Dictionary) -> Dictionary:
	var c := Grammar.clone_card(card)
	c.uid = new_card_uid(run)
	run.deck.append(c)
	return c
