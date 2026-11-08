## Combat rules. Port of engine/combat.js. State is plain data; every function
## mutates it and appends to s.log.
##
## Loop invariants (engine rules, not settings):
##   1. Spent: a card is played at most once per turn.
##   2. No mid-turn reshuffle: drawing from an empty pile does nothing.
##   3. Triggers fire once: each clause fires at most once per turn.
##   4. No card creation: no verb adds cards.
## Safety net: a turn aborts after rules.safetyNetResolutions clause resolutions.
##
## Front ends can watch s.events: every damage, block, heal, status and edit is
## also pushed there as a small Dictionary so the UI can animate it. The engine
## never reads it back.
class_name Combat

const P := "p"


static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}


static func start(db: Dictionary, deck: Array, enemy_defs: Array, seed: int, opts := {}) -> Dictionary:
	var cards := {}
	for c in deck:
		cards[c.uid] = Grammar.clone_card(c)
	var enemies := []
	for i in enemy_defs.size():
		var d: Dictionary = enemy_defs[i]
		var same := 0
		var before := 0
		for j in enemy_defs.size():
			if enemy_defs[j].key == d.key:
				same += 1
				if j < i:
					before += 1
		var name: String = d.name + ((" " + "AB"[before]) if same > 1 else "")
		enemies.append({
			"key": d.key, "name": name, "role": d.role, "hp": d.hp, "maxHp": d.hp, "block": 0,
			"weak": 0, "strength": 0, "step": 0, "pattern": d.pattern, "intent": null, "dead": false,
		})
	var hp: int = opts.get("hp", db.rules.player.hp)
	var s := {
		"seed": seed,
		"turn": 0,
		"phase": "player",
		"player": {"hp": hp, "maxHp": opts.get("maxHp", db.rules.player.hp), "block": 0, "energy": 0, "weak": 0, "strength": 0},
		"enemies": enemies,
		"cards": cards,
		"draw": [],
		"hand": [],
		"discard": [],
		"spent": {},
		"fired": {},
		"stats": {"plays": 0, "draws": 0, "resolutions": 0},
		"target": 0,
		"copied": null,
		"aborted": false,
		"log": [],
		"events": [],
	}
	s.draw = Rng.shuffle(s, cards.keys())
	var names := []
	for e in enemies:
		names.append(e.name)
	s.log.append({"turn": 1, "msg": "Fight begins: %s." % ", ".join(names)})
	start_player_turn(db, s)
	return s


static func _log(s: Dictionary, msg: String) -> void:
	s.log.append({"turn": s.turn, "msg": msg})
	if s.log.size() > 200:
		s.log.pop_front()


static func _ev(s: Dictionary, e: Dictionary) -> void:
	s.events.append(e)


static func alive(s: Dictionary) -> Array:
	var out := []
	for i in s.enemies.size():
		if not s.enemies[i].dead:
			out.append(i)
	return out


static func actor(s: Dictionary, ref) -> Dictionary:
	return s.player if is_player(ref) else s.enemies[ref]


static func is_player(ref) -> bool:
	return ref is String and ref == P


static func _who(s: Dictionary, ref) -> String:
	return "you" if is_player(ref) else s.enemies[ref].name


static func _sfx(ref) -> String:
	return "" if is_player(ref) else "s"


static func start_player_turn(db: Dictionary, s: Dictionary) -> void:
	s.turn += 1
	s.spent = {}
	s.fired = {}
	s.stats = {"plays": 0, "draws": 0, "resolutions": 0}
	s.aborted = false
	s.player.block = 0
	s.player.energy = db.rules.player.energyPerTurn
	var n: int = db.rules.player.handSize
	if s.draw.size() < n and not s.discard.is_empty():
		s.draw = s.draw + Rng.shuffle(s, s.discard)
		s.discard = []
		_log(s, "Discard pile shuffled into your draw pile.")
		_ev(s, {"type": "reshuffle"})
	_draw_cards(db, s, n)
	for i in alive(s):
		_choose_intent(db, s, i)
	if not alive(s).has(s.target):
		var a := alive(s)
		s.target = a[0] if not a.is_empty() else 0
	_ev(s, {"type": "turn", "turn": s.turn})


static func _draw_cards(db: Dictionary, s: Dictionary, n: int) -> void:
	for k in n:
		if s.draw.is_empty():
			_log(s, "Draw pile is empty.")
			return
		var uid: String = s.draw.pop_front()
		s.hand.append(uid)
		s.stats.draws += 1
		_ev(s, {"type": "draw", "uid": uid})
		_fire_trigger(db, s, uid, "drawn")
		if s.phase != "player":
			return


static func _fire_trigger(db: Dictionary, s: Dictionary, uid: String, trigger: String, ctx := {}) -> void:
	var card: Dictionary = s.cards[uid]
	for ci in card.clauses.size():
		if s.phase != "player" or s.aborted:
			return
		var eff = Grammar.effective(db, card.clauses[ci])
		if not eff or eff.trigger != trigger:
			continue
		var key := "%s:%d" % [uid, ci]
		if s.fired.get(key, false):
			continue
		s.fired[key] = true
		_resolve(db, s, eff, {"src": P, "uid": uid, "targetIdx": s.target, "first": ctx.get("first", false), "x": ctx.get("x", 0), "name": card.name})


static func _condition_holds(s: Dictionary, eff: Dictionary, ctx: Dictionary) -> bool:
	if not eff.condition:
		return true
	var v: bool
	var id: String = eff.condition.id
	if is_player(ctx.src):
		if id == "has_block":
			v = s.player.block > 0
		elif id == "enemy_weak":
			var ti: int = ctx.targetIdx
			v = ti < s.enemies.size() and s.enemies[ti].weak > 0
		else:
			v = ctx.first
	else:
		if id == "has_block":
			v = s.enemies[ctx.src].block > 0
		elif id == "enemy_weak":
			v = s.player.weak > 0
		else:
			v = true
	return (not v) if eff.condition.neg else v


static func _targets_for(db: Dictionary, s: Dictionary, eff: Dictionary, ctx: Dictionary) -> Array:
	var side: String = db.chunks.target[eff.target].side
	if not is_player(ctx.src):
		return [ctx.src] if side == "self" else [P]
	if side == "self":
		return [P]
	var live := alive(s)
	if live.is_empty():
		return []
	if eff.target == "all":
		return live
	if eff.target == "random":
		return [Rng.pick(s, live)]
	return [ctx.targetIdx if live.has(ctx.targetIdx) else live[0]]


static func _resolve(db: Dictionary, s: Dictionary, eff: Dictionary, ctx: Dictionary) -> void:
	s.stats.resolutions += 1
	if s.stats.resolutions > db.rules.safetyNetResolutions:
		s.aborted = true
		_log(s, "SAFETY NET: turn aborted after %d resolutions. Last card: %s. This is an engine bug." % [db.rules.safetyNetResolutions, ctx.name])
		return
	if not _condition_holds(s, eff, ctx):
		_log(s, "%s: condition not met." % ctx.name)
		_ev(s, {"type": "fizzle", "uid": ctx.get("uid", "")})
		return
	var cap: int = db.rules.status.amountCap
	var amt: int = mini(cap, ctx.x if Grammar.is_x(eff.amount) else eff.amount)
	for h in eff.hits:
		var targets := _targets_for(db, s, eff, ctx)
		for t in targets:
			_apply_verb(db, s, eff.verb, ctx, t, amt)
		if s.phase != "player" and s.phase != "enemy":
			return


static func _apply_verb(db: Dictionary, s: Dictionary, verb: String, ctx: Dictionary, t, amt: int) -> void:
	var tgt := actor(s, t)
	if tgt.get("dead", false):
		return
	var src = ctx.src
	match verb:
		"deal":
			_deal_damage(db, s, src, t, amt)
		"heal":
			var before: int = tgt.hp
			tgt.hp = mini(tgt.maxHp, tgt.hp + amt)
			_log(s, "%s: %s heal%s %d." % [ctx.name, _who(s, t), _sfx(t), tgt.hp - before])
			_ev(s, {"type": "heal", "who": t, "amount": tgt.hp - before})
		"block":
			tgt.block += amt
			_log(s, "%s: %s gain%s %d Block." % [ctx.name, _who(s, t), _sfx(t), amt])
			_ev(s, {"type": "block", "who": t, "amount": amt})
		"lose_block":
			tgt.block = maxi(0, tgt.block - amt)
			_log(s, "%s: %s lose%s %d Block." % [ctx.name, _who(s, t), _sfx(t), amt])
			_ev(s, {"type": "lose_block", "who": t, "amount": amt})
		"draw":
			if is_player(t):
				_draw_cards(db, s, amt)
		"discard":
			if is_player(t):
				_discard_random(s, amt, ctx.get("uid", ""))
		"energy":
			if is_player(t):
				s.player.energy += amt
				_log(s, "%s: +%d energy." % [ctx.name, amt])
				_ev(s, {"type": "energy", "amount": amt})
		"lose_energy":
			if is_player(t):
				s.player.energy = maxi(0, s.player.energy - amt)
				_log(s, "%s: −%d energy." % [ctx.name, amt])
				_ev(s, {"type": "energy", "amount": -amt})
		"weak":
			tgt.weak += amt
			_log(s, "%s: %s gain%s %d Weak." % [ctx.name, _who(s, t), _sfx(t), amt])
			_ev(s, {"type": "status", "who": t, "status": "weak", "amount": amt})
		"strength":
			tgt.strength += amt
			_log(s, "%s: %s gain%s %d Strength." % [ctx.name, _who(s, t), _sfx(t), amt])
			_ev(s, {"type": "status", "who": t, "status": "strength", "amount": amt})


static func _deal_damage(db: Dictionary, s: Dictionary, src, t, base: int) -> void:
	var a := actor(s, src)
	var d := actor(s, t)
	var amt: int = base + a.strength
	if a.weak > 0:
		amt = int(floor(amt * db.rules.status.weakDamageMultiplier))
	amt = maxi(0, mini(db.rules.status.amountCap, amt))
	var absorbed: int = mini(d.block, amt)
	d.block -= absorbed
	var dmg: int = amt - absorbed
	d.hp -= dmg
	_log(s, "%s hit%s %s for %d%s." % [_who(s, src), _sfx(src), _who(s, t), dmg, (" (%d blocked)" % absorbed) if absorbed else ""])
	_ev(s, {"type": "hit", "src": src, "who": t, "amount": dmg, "blocked": absorbed})
	if d.hp <= 0:
		d.hp = 0
		if is_player(t):
			s.phase = "lost"
			_log(s, "You were defeated.")
			_ev(s, {"type": "lost"})
		else:
			d.dead = true
			_log(s, "%s is defeated." % d.name)
			_ev(s, {"type": "death", "who": t})
			if alive(s).is_empty():
				s.phase = "won"
				_log(s, "Victory!")
				_ev(s, {"type": "won"})
			elif s.target == t:
				s.target = alive(s)[0]


static func _discard_random(s: Dictionary, n: int, except_uid: String) -> void:
	for k in n:
		var pool := []
		for u in s.hand:
			if u != except_uid:
				pool.append(u)
		if pool.is_empty():
			return
		var uid: String = pool[Rng.rand_int(s, pool.size())]
		s.hand.erase(uid)
		s.discard.append(uid)
		_log(s, "Discarded %s." % s.cards[uid].name)
		_ev(s, {"type": "discard", "uid": uid})


static func play_info(db: Dictionary, s: Dictionary, uid: String) -> Dictionary:
	var card: Dictionary = s.cards[uid]
	var c = Grammar.card_cost(db, card)
	if s.phase != "player":
		return {"can": false, "why": "Not your turn."}
	if not s.hand.has(uid):
		return {"can": false, "why": "That card is not in your hand."}
	if s.spent.get(uid, false):
		return {"can": false, "why": "Spent: already played this turn."}
	if Grammar.is_broken(card):
		return {"can": false, "why": "Broken: it is missing a Verb or Amount."}
	if not Grammar.is_playable(card):
		return {"can": false, "why": "Nothing on this card triggers when played."}
	if s.aborted:
		return {"can": false, "why": "Turn aborted by the safety net. End your turn."}
	if c.cost > s.player.energy:
		return {"can": false, "why": "Costs %d energy; you have %d." % [c.cost, s.player.energy]}
	return {"can": true, "cost": c.cost, "x": c.x}


static func play_card(db: Dictionary, s: Dictionary, uid: String, target_idx := -1) -> Dictionary:
	if target_idx < 0:
		target_idx = s.target
	var info := play_info(db, s, uid)
	if not info.can:
		return _fail(info.why)
	if alive(s).has(target_idx):
		s.target = target_idx
	var x := 0
	s.player.energy -= info.cost
	if info.x:
		x = s.player.energy
		s.player.energy = 0
	s.spent[uid] = true
	s.hand.erase(uid)
	s.discard.append(uid)
	var first: bool = s.stats.plays == 0
	s.stats.plays += 1
	_log(s, "You play %s%s." % [s.cards[uid].name, (" (X = %d)" % x) if info.x else ""])
	_ev(s, {"type": "play", "uid": uid})
	_fire_trigger(db, s, uid, "played", {"first": first, "x": x})
	return {"ok": true}


## Mid-fight quick edits: one tap, no clipboard, applied at once, gone after the fight.
static func combat_edit(db: Dictionary, s: Dictionary, tool: String, uid: String, ci: int, slot: String) -> Dictionary:
	var rule = db.rules.combatEdits.tools.get(tool)
	if not rule:
		return _fail("%s can only be used at a Workshop." % tool)
	if s.phase != "player":
		return _fail("Not your turn.")
	if not s.hand.has(uid):
		return _fail("You can only edit cards in your hand.")
	var card: Dictionary = s.cards[uid]
	var clause = card.clauses[ci] if ci < card.clauses.size() else null
	var ch = clause[slot] if clause else null
	if not ch:
		return _fail("There is no chunk there.")
	if s.player.energy < rule.energy:
		return _fail("That edit costs %d energy; you have %d." % [rule.energy, s.player.energy])
	s.player.energy -= rule.energy
	if tool == "mute":
		ch.muted = not ch.get("muted", false)
		ch.erase("redacted")
	else:
		Grammar.invert_chunk(db, clause, slot)
	var verb := ("mute" if ch.muted else "unmute") if tool == "mute" else "invert"
	_log(s, "You %s a chunk on %s." % [verb, card.name])
	_ev(s, {"type": "edit", "uid": uid, "ci": ci, "slot": slot, "tool": tool})
	return {"ok": true}


static func end_turn(db: Dictionary, s: Dictionary) -> Dictionary:
	if s.phase != "player":
		return _fail("Not your turn.")
	for uid in s.hand.duplicate():
		_fire_trigger(db, s, uid, "end_turn")
		if s.phase != "player":
			return {"ok": true}
	s.discard.append_array(s.hand)
	s.hand = []
	s.player.weak = maxi(0, s.player.weak - 1)
	s.phase = "enemy"
	_ev(s, {"type": "enemy_phase"})
	for i in alive(s):
		s.enemies[i].block = 0
		_enemy_act(db, s, i)
		if s.phase != "enemy":
			return {"ok": true}
	for e in s.enemies:
		e.weak = maxi(0, e.weak - 1)
	s.phase = "player"
	start_player_turn(db, s)
	return {"ok": true}


# ---- enemies ----

static func _hand_chunks(s: Dictionary, filter: Callable) -> Array:
	var out := []
	for uid in s.hand:
		var clauses: Array = s.cards[uid].clauses
		for ci in clauses.size():
			for slot in Grammar.SLOTS:
				var ch = clauses[ci][slot]
				if ch and filter.call(ch, slot):
					out.append({"uid": uid, "ci": ci, "slot": slot})
	return out


static func _choose_intent(db: Dictionary, s: Dictionary, i: int) -> void:
	var e: Dictionary = s.enemies[i]
	var intent: Dictionary = e.pattern[e.step % e.pattern.size()].duplicate(true)
	e.step += 1
	var edit: String = intent.get("edit", "")
	match edit:
		"blackout":
			intent.at = Rng.pick(s, _hand_chunks(s, func(ch, _slot): return not ch.get("muted", false)))
		"invert_verb":
			intent.at = Rng.pick(s, _hand_chunks(s, func(_ch, slot): return slot == "verb"))
		"typo":
			intent.at = Rng.pick(s, _hand_chunks(s, func(ch, slot): return slot == "amount" and not Grammar.is_x(ch.id)))
			intent.delta = 1 if Rng.rand_int(s, 2) else -1
		"copy":
			var best = null
			for uid in s.cards:
				var c = Grammar.card_cost(db, s.cards[uid])
				if c and (best == null or c.cost > best.cost):
					best = {"uid": uid, "cost": c.cost}
			intent.at = {"uid": best.uid} if best else null
	if edit != "" and edit != "censor" and intent.get("at") == null:
		intent.fizzle = true
	e.intent = intent


static func intent_text(db: Dictionary, s: Dictionary, i: int) -> String:
	var e: Dictionary = s.enemies[i]
	var it = e.intent
	if not it:
		return ""
	var parts := []
	if it.has("attack"):
		var a: int = it.attack + e.strength
		if e.weak > 0:
			a = int(floor(a * db.rules.status.weakDamageMultiplier))
		parts.append("Attack %d%s" % [a, (" ×%d" % it.hits) if it.get("hits", 1) > 1 else ""])
	if it.get("block", 0):
		parts.append("Block %d" % it.block)
	if it.get("strength", 0):
		parts.append("+%d Strength" % it.strength)
	if it.get("weak", 0):
		parts.append("Weak %d on you" % it.weak)
	if it.has("edit"):
		parts.append("Edit: nothing to target" if it.get("fizzle", false) else edit_text(s, it))
	return " · ".join(parts)


static func edit_text(s: Dictionary, it: Dictionary) -> String:
	var name: String = s.cards[it.at.uid].name if it.get("at") else ""
	match it.edit:
		"blackout":
			return "Black out a chunk on %s" % name
		"invert_verb":
			return "Invert the Verb on %s" % name
		"typo":
			return "%s to an Amount on %s" % ["+1" if it.delta > 0 else "−1", name]
		"censor":
			return "Mute every Amount above 5 in your deck"
		"copy":
			return "Copy %s and play it at you" % name
	return ""


static func _enemy_act(db: Dictionary, s: Dictionary, i: int) -> void:
	var e: Dictionary = s.enemies[i]
	var it = e.intent
	if not it:
		return
	_ev(s, {"type": "enemy_turn", "who": i})
	if it.has("attack"):
		for h in it.get("hits", 1):
			_deal_damage(db, s, i, P, it.attack)
			if s.phase == "lost":
				return
	if it.get("block", 0):
		e.block += it.block
		_log(s, "%s gains %d Block." % [e.name, it.block])
		_ev(s, {"type": "block", "who": i, "amount": it.block})
	if it.get("strength", 0):
		e.strength += it.strength
		_log(s, "%s gains %d Strength." % [e.name, it.strength])
		_ev(s, {"type": "status", "who": i, "status": "strength", "amount": it.strength})
	if it.get("weak", 0):
		s.player.weak += it.weak
		_log(s, "%s makes you Weak %d." % [e.name, it.weak])
		_ev(s, {"type": "status", "who": P, "status": "weak", "amount": it.weak})
	if it.has("edit") and not it.get("fizzle", false):
		_apply_enemy_edit(db, s, i, it)


static func _apply_enemy_edit(db: Dictionary, s: Dictionary, i: int, it: Dictionary) -> void:
	var e: Dictionary = s.enemies[i]
	var at = it.get("at")
	var clause = null
	if at and at.has("ci") and s.cards.has(at.uid):
		clause = s.cards[at.uid].clauses[at.ci] if at.ci < s.cards[at.uid].clauses.size() else null
	match it.edit:
		"blackout":
			var ch = clause[at.slot] if clause else null
			if ch and not ch.get("muted", false):
				ch.muted = true
				ch.redacted = true
				_log(s, "%s blacks out a chunk on %s." % [e.name, s.cards[at.uid].name])
				_ev(s, {"type": "enemy_edit", "edit": "blackout", "who": i, "uid": at.uid})
		"invert_verb":
			if clause and clause.verb:
				Grammar.invert_chunk(db, clause, "verb")
				clause.verb.enemyEdit = true
				_log(s, "%s inverts the Verb on %s." % [e.name, s.cards[at.uid].name])
				_ev(s, {"type": "enemy_edit", "edit": "invert_verb", "who": i, "uid": at.uid})
		"typo":
			var ch = clause.amount if clause else null
			if ch and not Grammar.is_x(ch.id):
				Grammar.shift_amount(db, ch, it.delta)
				ch.enemyEdit = true
				_log(s, "%s changes an Amount on %s to %s." % [e.name, s.cards[at.uid].name, str(ch.id)])
				_ev(s, {"type": "enemy_edit", "edit": "typo", "who": i, "uid": at.uid})
		"censor":
			var n := 0
			for card in s.cards.values():
				for cl in card.clauses:
					var ch = cl.amount
					if ch and not Grammar.is_x(ch.id) and ch.id > 5 and not ch.get("muted", false):
						ch.muted = true
						ch.redacted = true
						n += 1
			_log(s, "%s censors %d Amount%s in your deck." % [e.name, n, "" if n == 1 else "s"])
			_ev(s, {"type": "enemy_edit", "edit": "censor", "who": i})
		"copy":
			var card: Dictionary = s.cards[at.uid]
			s.copied = Grammar.clone_card(card)
			_log(s, "%s copies %s and plays it at you." % [e.name, card.name])
			_ev(s, {"type": "enemy_edit", "edit": "copy", "who": i, "uid": at.uid})
			for cl in card.clauses:
				var eff = Grammar.effective(db, cl)
				if eff:
					_resolve(db, s, eff, {"src": i, "name": "%s (%s)" % [e.name, card.name], "x": 3})
				if s.phase == "lost":
					return


## Telegraphed enemy edits on this card, so the UI can mark the chunk.
static func telegraphs_on(s: Dictionary, uid: String) -> Array:
	var out := []
	for i in s.enemies.size():
		var e: Dictionary = s.enemies[i]
		var it = e.intent
		if e.dead or not it or it.get("fizzle", false):
			continue
		var at = it.get("at")
		if at and at.uid == uid:
			var slot = at.get("slot", "verb" if it.edit == "invert_verb" else null)
			out.append({"enemy": i, "edit": it.edit, "ci": at.get("ci", -1), "slot": slot})
	return out
