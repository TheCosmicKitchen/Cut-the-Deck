## Phase 2 gate: generate random legal cards and decks, play random turns, and
## fail if any turn passes N plays, N draws or 3N clause resolutions. Port of engine/fuzz.js.
class_name Fuzz

const DUMMY := {"key": "dummy", "name": "Dummy", "role": "Test", "hp": 99999,
	"pattern": [{"attack": 1}, {"edit": "invert_verb"}, {"edit": "typo"}, {"edit": "blackout"}]}


static func _random_clause(db: Dictionary, s: Dictionary) -> Dictionary:
	var c := Grammar.empty_clause()
	c.verb = {"type": "verb", "id": Rng.pick(s, Grammar.chunk_ids(db, "verb"))}
	c.amount = {"type": "amount", "id": Rng.pick(s, Grammar.chunk_ids(db, "amount"))}
	for slot in ["trigger", "repeat", "target", "condition"]:
		if Rng.rand(s) < 0.4:
			var ch := {"type": slot, "id": Rng.pick(s, Grammar.chunk_ids(db, slot))}
			ch.neg = slot == "condition" and Rng.rand(s) < 0.5
			c[slot] = ch
	return c


static func random_card(db: Dictionary, s: Dictionary, uid: String) -> Dictionary:
	var n: int = 1 + Rng.rand_int(s, db.rules.maxClauses)
	var clauses := []
	for k in n:
		clauses.append(_random_clause(db, s))
	return {"uid": uid, "base": "fuzz", "name": "Fuzz " + uid, "clauses": clauses}


static func run(db: Dictionary, decks := 300, turns := 8, seed := 1) -> Dictionary:
	var s := {"seed": seed}
	var result := {"decks": decks, "turnsPlayed": 0, "maxRatio": {"plays": 0.0, "draws": 0.0, "resolutions": 0.0}, "failures": [], "safetyNet": 0}
	for d in decks:
		var N: int = 5 + Rng.rand_int(s, 20)
		var deck := []
		for k in N:
			deck.append(random_card(db, s, "f%d_%d" % [d, k]))
		var c := Combat.start(db, deck, [DUMMY], Rng.rand_int(s, 1000000000), {"hp": 99999, "maxHp": 99999})
		for t in turns:
			if c.phase != "player":
				break
			for guard in 200:
				if c.phase != "player":
					break
				if not c.hand.is_empty() and Rng.rand(s) < 0.15:
					var uid: String = Rng.pick(s, c.hand)
					var card: Dictionary = c.cards[uid]
					var ci := Rng.rand_int(s, card.clauses.size())
					var filled := []
					if ci < card.clauses.size():
						for sl in Grammar.SLOTS:
							if card.clauses[ci][sl]:
								filled.append(sl)
					var slot = Rng.pick(s, filled)
					if slot:
						Combat.combat_edit(db, c, "mute" if Rng.rand(s) < 0.5 else "invert", uid, ci, slot)
				var playable := []
				for u in c.hand:
					if Combat.play_info(db, c, u).can:
						playable.append(u)
				if playable.is_empty():
					break
				Combat.play_card(db, c, Rng.pick(s, playable))
			_check(c, N, result, d)
			if c.phase == "player":
				Combat.end_turn(db, c)
			c.events.clear()
			result.turnsPlayed += 1
	result.ok = result.failures.is_empty() and result.safetyNet == 0
	return result


static func _check(c: Dictionary, N: int, result: Dictionary, d: int) -> void:
	var st: Dictionary = c.stats
	var r := {"plays": float(st.plays) / N, "draws": float(st.draws) / N, "resolutions": float(st.resolutions) / (3 * N)}
	for k in r:
		result.maxRatio[k] = maxf(result.maxRatio[k], r[k])
	if c.aborted:
		result.safetyNet += 1
	if r.plays > 1 or r.draws > 1 or r.resolutions > 1:
		if result.failures.size() < 5:
			var f := {"deck": d, "N": N}
			f.merge(st)
			result.failures.append(f)
