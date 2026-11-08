# Card text grammar: clauses of typed chunks in fixed slots. Port of engine/grammar.js.
# A chunk is { type, id, muted?, neg?, redacted?, enemyEdit? }.
# A clause is { trigger, verb, amount, repeat, target, condition }, each a chunk or null.
# An Amount id is an int 0-9 or the String "X".

const SLOTS := ["trigger", "verb", "amount", "repeat", "target", "condition"]
const REQUIRED := ["verb", "amount"]


static func is_x(id) -> bool:
	return typeof(id) == TYPE_STRING


static func empty_clause() -> Dictionary:
	var c := {}
	for slot in SLOTS:
		c[slot] = null
	return c


# cards.json shorthand -> clause
static func parse_clause(short: Dictionary) -> Dictionary:
	var c := empty_clause()
	for slot in short:
		if not SLOTS.has(slot):
			continue
		var v = short[slot]
		if slot == "condition" and v is String and v.begins_with("!"):
			c["condition"] = {"type": "condition", "id": v.substr(1), "neg": true}
		else:
			c[slot] = {"type": slot, "id": v}
	for slot in short.get("muted", []):
		if c.get(slot) != null:
			c[slot]["muted"] = true
	return c


# clause -> cards.json shorthand (muted flags kept so exports round-trip)
static func clause_shorthand(clause: Dictionary) -> Dictionary:
	var out := {}
	for slot in SLOTS:
		var ch = clause[slot]
		if ch == null:
			continue
		out[slot] = ("!" + ch["id"]) if (slot == "condition" and ch.get("neg", false)) else ch["id"]
		if ch.get("muted", false):
			if not out.has("muted"):
				out["muted"] = []
			out["muted"].append(slot)
	return out


static func make_card(def: Dictionary, uid: String) -> Dictionary:
	var clauses := []
	for short in def["clauses"]:
		clauses.append(parse_clause(short))
	return {"uid": uid, "base": def["id"], "name": def["name"], "clauses": clauses}


static func clone_card(card: Dictionary) -> Dictionary:
	return card.duplicate(true)


static func strip_chunk(ch: Dictionary) -> Dictionary:
	var out := {"type": ch["type"], "id": ch["id"]}
	if ch.get("neg", false):
		out["neg"] = true
	return out


static func live(ch):
	if ch != null and not ch.get("muted", false):
		return ch
	return null


static func trigger_of(clause: Dictionary) -> String:
	var t = live(clause["trigger"])
	return t["id"] if t != null else "played"


# What a clause does right now, or null if inert (Verb or Amount missing or muted).
static func effective(db: Dictionary, clause: Dictionary):
	var verb = live(clause["verb"])
	var amount = live(clause["amount"])
	if verb == null or amount == null:
		return null
	var vdef: Dictionary = db["chunks"]["verb"][verb["id"]]
	var rep = live(clause["repeat"])
	var tgt = live(clause["target"])
	var cond = live(clause["condition"])
	return {
		"verb": verb["id"],
		"amount": amount["id"],
		"hits": db["chunks"]["repeat"][rep["id"]]["hits"] if rep != null else 1,
		"target": tgt["id"] if tgt != null else vdef["defaultTarget"],
		"condition": {"id": cond["id"], "neg": cond.get("neg", false)} if cond != null else null,
		"trigger": trigger_of(clause),
	}


static func is_broken(card: Dictionary) -> bool:
	if card["clauses"].is_empty():
		return true
	for c in card["clauses"]:
		for s in REQUIRED:
			if c[s] == null:
				return true
	return false


static func is_playable(card: Dictionary) -> bool:
	if is_broken(card):
		return false
	for c in card["clauses"]:
		if trigger_of(c) == "played":
			return true
	return false


static func is_drawback(db: Dictionary, eff: Dictionary) -> bool:
	var side: String = db["chunks"]["target"][eff["target"]]["side"]
	var harm: bool = db["chunks"]["verb"][eff["verb"]]["polarity"] == "harm"
	return harm == (side == "self")


static func clause_weight(db: Dictionary, eff: Dictionary) -> float:
	var v: Dictionary = db["chunks"]["verb"][eff["verb"]]
	var amt: float = 0.0 if is_x(eff["amount"]) else float(eff["amount"])
	var w: float = v["weight"] + v["amountScale"] * amt * eff["hits"] + db["chunks"]["target"][eff["target"]]["weight"]
	if eff["condition"] != null:
		w += db["chunks"]["condition"][eff["condition"]["id"]]["weight"]
	w += db["chunks"]["trigger"][eff["trigger"]]["weight"]
	if is_drawback(db, eff):
		w = absf(w) * db["rules"]["cost"]["drawbackFactor"]
	return w


# { cost, x } — x is true when an X amount spends all remaining energy. null for Broken cards.
static func card_cost(db: Dictionary, card: Dictionary):
	if is_broken(card):
		return null
	var total := 0.0
	var x := false
	for clause in card["clauses"]:
		var eff = effective(db, clause)
		if eff == null:
			continue
		total += clause_weight(db, eff)
		if is_x(eff["amount"]) and eff["trigger"] == "played":
			x = true
	return {"cost": maxi(0, int(round(total + 1e-9))), "x": x}


static func chunk_label(db: Dictionary, ch: Dictionary) -> String:
	var C: Dictionary = db["chunks"]
	match ch["type"]:
		"verb":
			return C["verb"][ch["id"]]["label"]
		"amount":
			return str(ch["id"])
		"repeat":
			return C["repeat"][ch["id"]]["label"]
		"target":
			return "to " + C["target"][ch["id"]]["label"]
		"condition":
			return C["condition"][ch["id"]]["unless" if ch.get("neg", false) else "if"]
		"trigger":
			var lbl: String = C["trigger"][ch["id"]]["label"]
			return (lbl if lbl != "" else "When played") + ":"
	return "?"


# Display order of a clause. Empty slots appear only when show_empty is set
# (the editor), except required ones, which always show so Broken cards read as broken.
static func clause_tokens(db: Dictionary, clause: Dictionary, show_empty := false) -> Array:
	var out := []
	for slot in SLOTS:
		var ch = clause[slot]
		if ch != null:
			out.append({"slot": slot, "chunk": ch, "text": chunk_label(db, ch)})
		elif show_empty or REQUIRED.has(slot):
			out.append({"slot": slot, "chunk": null, "text": slot})
	return out


static func card_text(db: Dictionary, card: Dictionary) -> String:
	var parts := []
	for c in card["clauses"]:
		var words := []
		for t in clause_tokens(db, c):
			words.append(t["text"] if t["chunk"] != null else "[%s]" % t["text"])
		parts.append(" ".join(PackedStringArray(words)))
	return ". ".join(PackedStringArray(parts))


static func clamp_amount(db: Dictionary, n: int) -> int:
	var a: Dictionary = db["chunks"]["amount"]
	return clampi(n, a["min"], a["max"])


static func shift_amount(db: Dictionary, ch: Dictionary, delta: int) -> void:
	if ch["type"] == "amount" and not is_x(ch["id"]):
		ch["id"] = clamp_amount(db, ch["id"] + delta)


# Flip one chunk to its opposite, in place. Inverting a Verb keeps who it hits:
# if the Target slot is empty, the old verb's default target is written into it.
static func invert_chunk(db: Dictionary, clause: Dictionary, slot: String) -> bool:
	var ch = clause[slot]
	if ch == null:
		return false
	var C: Dictionary = db["chunks"]
	match slot:
		"verb":
			var old_def: String = C["verb"][ch["id"]]["defaultTarget"]
			var next: String = C["verb"][ch["id"]]["invert"]
			if live(clause["target"]) == null and C["verb"][next]["defaultTarget"] != old_def:
				clause["target"] = {"type": "target", "id": old_def}
			ch["id"] = next
		"amount":
			if is_x(ch["id"]):
				ch["id"] = C["amount"]["xInvertsTo"]
			else:
				ch["id"] = clamp_amount(db, C["amount"]["invertPivot"] - ch["id"])
		"condition":
			ch["neg"] = not ch.get("neg", false)
		_:
			ch["id"] = C[slot][ch["id"]]["invert"]
	return true
