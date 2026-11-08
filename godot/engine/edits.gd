# Workshop editing tools. Port of engine/edits.js. Each takes the run state and
# returns { ok: true, note? } or { ok: false, error }. Validation happens before any Ink is spent.

const G := preload("res://godot/engine/grammar.gd")


static func fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}


static func find_card(run: Dictionary, uid: String):
	for c in run["deck"]:
		if c["uid"] == uid:
			return c
	return null


static func _chunk_at(run: Dictionary, uid: String, ci: int, slot: String):
	var card = find_card(run, uid)
	if card == null or ci < 0 or ci >= card["clauses"].size():
		return null
	return card["clauses"][ci].get(slot)


static func tool_cost(db: Dictionary, run: Dictionary, tool: String) -> Dictionary:
	if run.get("sandbox", false):
		return {"ink": 0, "free": false}
	if run["freeUses"].get(tool, 0) > 0:
		return {"ink": 0, "free": true}
	return {"ink": db["rules"]["workshopTools"][tool]["ink"], "free": false}


static func _can_pay(db: Dictionary, run: Dictionary, tool: String) -> bool:
	return tool_cost(db, run, tool)["ink"] <= run["ink"]


static func _pay(db: Dictionary, run: Dictionary, tool: String) -> void:
	var c := tool_cost(db, run, tool)
	if c["free"]:
		run["freeUses"][tool] -= 1
	run["ink"] -= c["ink"]


static func _need_ink(db: Dictionary, run: Dictionary, tool: String) -> Dictionary:
	return fail("%s needs %d Ink. You have %d." % [tool.capitalize(), tool_cost(db, run, tool)["ink"], run["ink"]])


static func _article(word: String) -> String:
	return "an" if "aeiou".contains(word.substr(0, 1).to_lower()) else "a"


static func _tidy(card: Dictionary) -> void:
	var kept := []
	for c in card["clauses"]:
		for s in G.SLOTS:
			if c[s] != null:
				kept.append(c)
				break
	card["clauses"] = kept


static func cut(db: Dictionary, run: Dictionary, uid: String, ci: int, slot: String) -> Dictionary:
	var ch = _chunk_at(run, uid, ci, slot)
	if ch == null:
		return fail("There is no chunk there to cut.")
	if run["clipboard"].size() >= db["rules"]["clipboardSize"]:
		return fail("Your clipboard is full. Drop a chunk first.")
	if not _can_pay(db, run, "scissors"):
		return _need_ink(db, run, "scissors")
	_pay(db, run, "scissors")
	var card = find_card(run, uid)
	card["clauses"][ci][slot] = null
	run["clipboard"].append(G.strip_chunk(ch))
	_tidy(card)
	return {"ok": true}


# Paste clipboard[clip_idx] into a slot. ci == clauses.size() starts a new clause.
static func glue(db: Dictionary, run: Dictionary, uid: String, ci: int, slot: String, clip_idx: int) -> Dictionary:
	var card = find_card(run, uid)
	if card == null or clip_idx < 0 or clip_idx >= run["clipboard"].size():
		return fail("Pick a chunk from your clipboard first.")
	var ch: Dictionary = run["clipboard"][clip_idx]
	var t: String = ch["type"]
	if t != slot:
		return fail("%s %s chunk only fits %s %s slot." % [_article(t).capitalize(), t.capitalize(), _article(t), t.capitalize()])
	var is_new: bool = ci == card["clauses"].size()
	if is_new and card["clauses"].size() >= db["rules"]["maxClauses"]:
		return fail("A card holds at most %d clauses." % db["rules"]["maxClauses"])
	if not is_new and (ci < 0 or ci > card["clauses"].size()):
		return fail("That clause does not exist.")
	if not _can_pay(db, run, "glue"):
		return _need_ink(db, run, "glue")
	_pay(db, run, "glue")
	if is_new:
		card["clauses"].append(G.empty_clause())
	var old = card["clauses"][ci][slot]
	card["clauses"][ci][slot] = ch
	run["clipboard"].remove_at(clip_idx)
	if old != null:
		run["clipboard"].append(G.strip_chunk(old))
	return {"ok": true}


static func mute(db: Dictionary, run: Dictionary, uid: String, ci: int, slot: String) -> Dictionary:
	var ch = _chunk_at(run, uid, ci, slot)
	if ch == null:
		return fail("There is no chunk there to mute.")
	if not _can_pay(db, run, "mute"):
		return _need_ink(db, run, "mute")
	_pay(db, run, "mute")
	ch["muted"] = not ch.get("muted", false)
	ch.erase("redacted")
	return {"ok": true}


static func invert(db: Dictionary, run: Dictionary, uid: String, ci: int, slot: String) -> Dictionary:
	if _chunk_at(run, uid, ci, slot) == null:
		return fail("There is no chunk there to invert.")
	if not _can_pay(db, run, "invert"):
		return _need_ink(db, run, "invert")
	_pay(db, run, "invert")
	G.invert_chunk(db, find_card(run, uid)["clauses"][ci], slot)
	return {"ok": true}


static func merged_name(a: String, b: String) -> String:
	var first: String = a.split(" ")[0]
	var parts := b.split(" ")
	var last: String = parts[parts.size() - 1]
	return a if first == last else "%s %s" % [first, last]


static func merge(db: Dictionary, run: Dictionary, uid_a: String, uid_b: String) -> Dictionary:
	var a = find_card(run, uid_a)
	var b = find_card(run, uid_b)
	if a == null or b == null or uid_a == uid_b:
		return fail("Pick two different cards to merge.")
	var total: int = a["clauses"].size() + b["clauses"].size()
	if total > db["rules"]["maxClauses"]:
		return fail("Together they have %d clauses; a card holds at most %d." % [total, db["rules"]["maxClauses"]])
	if not _can_pay(db, run, "merge"):
		return _need_ink(db, run, "merge")
	_pay(db, run, "merge")
	a["clauses"].append_array(b["clauses"])
	a["name"] = merged_name(a["name"], b["name"])
	run["deck"].erase(b)
	return {"ok": true}


static func shred(db: Dictionary, run: Dictionary, uid: String) -> Dictionary:
	var card = find_card(run, uid)
	if card == null:
		return fail("Pick a card to shred.")
	if run["deck"].size() <= 1:
		return fail("You need at least one card in your deck.")
	_pay(db, run, "shred")
	var lost := 0
	for clause in card["clauses"]:
		for slot in G.SLOTS:
			if clause[slot] == null:
				continue
			if run["clipboard"].size() < db["rules"]["clipboardSize"]:
				run["clipboard"].append(G.strip_chunk(clause[slot]))
			else:
				lost += 1
	run["deck"].erase(card)
	var res := {"ok": true}
	if lost:
		res["note"] = "%d chunk%s didn't fit on the clipboard and were lost." % [lost, "s" if lost > 1 else ""]
	return res


static func drop_clip(run: Dictionary, idx: int) -> Dictionary:
	run["clipboard"].remove_at(idx)
	return {"ok": true}


# Apply a chunk tool to a throwaway copy, for the live cost preview. Returns the edited card or null.
static func preview(db: Dictionary, run: Dictionary, tool: String, uid: String, ci: int, slot: String, clip_idx := -1):
	var copy: Dictionary = run.duplicate(true)
	copy["sandbox"] = true
	var res: Dictionary
	match tool:
		"scissors":
			res = cut(db, copy, uid, ci, slot)
		"glue":
			res = glue(db, copy, uid, ci, slot, clip_idx)
		"mute":
			res = mute(db, copy, uid, ci, slot)
		"invert":
			res = invert(db, copy, uid, ci, slot)
		_:
			return null
	return find_card(copy, uid) if res["ok"] else null
