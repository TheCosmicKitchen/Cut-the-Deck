## Card text grammar: clauses of typed chunks in fixed slots. Port of engine/grammar.js.
## A chunk is { type, id, muted?, neg?, redacted?, enemyEdit? }.
## A clause is { trigger, verb, amount, repeat, target, condition }, each a chunk or null.
## Amount ids are ints 0-9 or the String "X".
class_name Grammar

const SLOTS := ["trigger", "verb", "amount", "repeat", "target", "condition"]
const REQUIRED := ["verb", "amount"]


static func empty_clause() -> Dictionary:
	var c := {}
	for slot in SLOTS:
		c[slot] = null
	return c


## cards.json shorthand -> clause
static func parse_clause(short: Dictionary) -> Dictionary:
	var c := empty_clause()
	for slot in short:
		if not SLOTS.has(slot):
			continue
		var v = short[slot]
		if slot == "condition" and v is String and v.begins_with("!"):
			c.condition = {"type": "condition", "id": v.substr(1), "neg": true}
		else:
			c[slot] = {"type": slot, "id": v}
	for slot in short.get("muted", []):
		if c[slot]:
			c[slot].muted = true
	return c


## clause -> cards.json shorthand (muted flags kept so exports round-trip)
static func clause_shorthand(clause: Dictionary) -> Dictionary:
	var out := {}
	for slot in SLOTS:
		var ch = clause[slot]
		if not ch:
			continue
		out[slot] = ("!" + ch.id) if (slot == "condition" and ch.get("neg", false)) else ch.id
		if ch.get("muted", false):
			if not out.has("muted"):
				out.muted = []
			out.muted.append(slot)
	return out


static func make_card(def: Dictionary, uid: String) -> Dictionary:
	var clauses := []
	for cl in def.clauses:
		clauses.append(parse_clause(cl))
	return {"uid": uid, "base": def.id, "name": def.name, "clauses": clauses}


static func clone_card(card: Dictionary) -> Dictionary:
	return card.duplicate(true)


## from_card: the card it is being cut from. A slip keeps the card it was first cut
## from, so its paper still shows where it came from.
static func strip_chunk(ch: Dictionary, from_card := "") -> Dictionary:
	var out := {"type": ch.type, "id": ch.id}
	if ch.get("neg", false):
		out.neg = true
	var from: String = ch.get("from", from_card)
	if from != "":
		out.from = from
	return out


static func live(ch) -> Variant:
	if ch and not ch.get("muted", false):
		return ch
	return null


static func trigger_of(clause: Dictionary) -> String:
	var t = live(clause.trigger)
	return t.id if t else "played"


## What a clause does right now, or null if it is inert (Verb or Amount missing or muted).
static func effective(db: Dictionary, clause: Dictionary) -> Variant:
	var verb = live(clause.verb)
	var amount = live(clause.amount)
	if not verb or not amount:
		return null
	var vdef: Dictionary = db.chunks.verb[verb.id]
	var rep = live(clause.repeat)
	var tgt = live(clause.target)
	var cond = live(clause.condition)
	return {
		"verb": verb.id,
		"amount": amount.id,
		"hits": db.chunks.repeat[rep.id].hits if rep else 1,
		"target": tgt.id if tgt else vdef.defaultTarget,
		"condition": {"id": cond.id, "neg": cond.get("neg", false)} if cond else null,
		"trigger": trigger_of(clause),
	}


static func is_broken(card: Dictionary) -> bool:
	if card.clauses.is_empty():
		return true
	for c in card.clauses:
		for s in REQUIRED:
			if not c[s]:
				return true
	return false


static func is_playable(card: Dictionary) -> bool:
	if is_broken(card):
		return false
	for c in card.clauses:
		if trigger_of(c) == "played":
			return true
	return false


static func is_drawback(db: Dictionary, eff: Dictionary) -> bool:
	var side: String = db.chunks.target[eff.target].side
	var harm: bool = db.chunks.verb[eff.verb].polarity == "harm"
	return harm == (side == "self")


static func clause_weight(db: Dictionary, eff: Dictionary) -> float:
	var v: Dictionary = db.chunks.verb[eff.verb]
	var amt = 0 if is_x(eff.amount) else eff.amount
	var w: float = v.weight + v.amountScale * amt * eff.hits + db.chunks.target[eff.target].weight
	if eff.condition:
		w += db.chunks.condition[eff.condition.id].weight
	w += db.chunks.trigger[eff.trigger].weight
	if is_drawback(db, eff):
		w = absf(w) * db.rules.cost.drawbackFactor
	return w


static func is_x(id) -> bool:
	return id is String and id == "X"


## { cost, x } — x is true when an X amount spends all remaining energy. null for Broken cards.
static func card_cost(db: Dictionary, card: Dictionary) -> Variant:
	if is_broken(card):
		return null
	var sum := 0.0
	var x := false
	for clause in card.clauses:
		var eff = effective(db, clause)
		if not eff:
			continue
		sum += clause_weight(db, eff)
		if is_x(eff.amount) and eff.trigger == "played":
			x = true
	# Math.round in JS rounds .5 up; floor(v + 0.5) matches it.
	return {"cost": maxi(0, int(floor(sum + 1e-9 + 0.5))), "x": x}


static func chunk_label(db: Dictionary, ch: Dictionary) -> String:
	match ch.type:
		"verb":
			return db.chunks.verb[ch.id].label
		"amount":
			return str(ch.id)
		"repeat":
			return db.chunks.repeat[ch.id].label
		"target":
			return "to " + db.chunks.target[ch.id].label
		"condition":
			return db.chunks.condition[ch.id]["unless" if ch.get("neg", false) else "if"]
		"trigger":
			var l: String = db.chunks.trigger[ch.id].label
			return (l if l != "" else "When played") + ":"
	return "?"


## Display order of a clause. Empty slots appear only when show_empty is set,
## except required ones, which always show so Broken cards read as broken.
static func clause_tokens(db: Dictionary, clause: Dictionary, show_empty := false) -> Array:
	var out := []
	for slot in SLOTS:
		var ch = clause[slot]
		if ch:
			out.append({"slot": slot, "chunk": ch, "text": chunk_label(db, ch)})
		elif show_empty or REQUIRED.has(slot):
			out.append({"slot": slot, "chunk": null, "text": slot})
	return out


static func card_text(db: Dictionary, card: Dictionary) -> String:
	var parts := []
	for c in card.clauses:
		var toks := []
		for t in clause_tokens(db, c):
			toks.append(t.text if t.chunk else "[%s]" % t.text)
		parts.append(" ".join(toks))
	return ". ".join(parts)


static func clamp_amount(db: Dictionary, n: int) -> int:
	var a: Dictionary = db.chunks.amount
	return maxi(a.min, mini(a.max, n))


static func shift_amount(db: Dictionary, ch: Dictionary, delta: int) -> void:
	if ch.type == "amount" and not is_x(ch.id):
		ch.id = clamp_amount(db, ch.id + delta)


## Flip one chunk to its opposite, in place. Inverting a Verb keeps who it hits:
## if the Target slot is empty, the old verb's default target is written into it.
static func invert_chunk(db: Dictionary, clause: Dictionary, slot: String) -> bool:
	var ch = clause[slot]
	if not ch:
		return false
	var C: Dictionary = db.chunks
	match slot:
		"verb":
			var old_def: String = C.verb[ch.id].defaultTarget
			var next: String = C.verb[ch.id].invert
			if not live(clause.target) and C.verb[next].defaultTarget != old_def:
				clause.target = {"type": "target", "id": old_def}
			ch.id = next
		"amount":
			ch.id = C.amount.xInvertsTo if is_x(ch.id) else clamp_amount(db, C.amount.invertPivot - ch.id)
		"condition":
			ch.neg = not ch.get("neg", false)
		_:
			ch.id = C[slot][ch.id].invert
	return true


## Every id a chunk of this type could take (fuzz test, sandbox pantry).
static func chunk_ids(db: Dictionary, type: String) -> Array:
	if type == "amount":
		var ids := []
		for n in range(db.chunks.amount.min, db.chunks.amount.max + 1):
			ids.append(n)
		ids.append("X")
		return ids
	return db.chunks[type].keys()
