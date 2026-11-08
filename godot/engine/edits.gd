## Workshop editing tools. Port of engine/edits.js.
## Each takes the run state and returns { ok: true, note? } or { ok: false, error }.
## Validation happens before any Ink is spent.
class_name Edits


static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}


static func _ok(note := "") -> Dictionary:
	var r := {"ok": true}
	if note != "":
		r.note = note
	return r


static func find_card(run: Dictionary, uid: String) -> Variant:
	for c in run.deck:
		if c.uid == uid:
			return c
	return null


static func tool_cost(db: Dictionary, run: Dictionary, tool: String) -> Dictionary:
	if run.get("sandbox", false):
		return {"ink": 0, "free": false}
	if run.freeUses.get(tool, 0) > 0:
		return {"ink": 0, "free": true}
	return {"ink": db.rules.workshopTools[tool].ink, "free": false}


static func _can_pay(db: Dictionary, run: Dictionary, tool: String) -> bool:
	return tool_cost(db, run, tool).ink <= run.ink


static func _pay(db: Dictionary, run: Dictionary, tool: String) -> void:
	var c := tool_cost(db, run, tool)
	if c.free:
		run.freeUses[tool] -= 1
	run.ink -= c.ink


static func _need_ink(db: Dictionary, run: Dictionary, tool: String) -> Dictionary:
	return _fail("%s needs %d Ink. You have %d." % [tool.capitalize(), tool_cost(db, run, tool).ink, run.ink])


static func _article(word: String) -> String:
	return "an" if "aeiou".contains(word.substr(0, 1).to_lower()) else "a"


static func _tidy(card: Dictionary) -> void:
	var kept := []
	for c in card.clauses:
		for s in Grammar.SLOTS:
			if c[s]:
				kept.append(c)
				break
	card.clauses = kept


static func cut(db: Dictionary, run: Dictionary, uid: String, ci: int, slot: String) -> Dictionary:
	var card = find_card(run, uid)
	var ch = card.clauses[ci][slot] if card and ci < card.clauses.size() else null
	if not ch:
		return _fail("There is no chunk there to cut.")
	if run.clipboard.size() >= db.rules.clipboardSize:
		return _fail("Your clipboard is full. Drop a chunk first.")
	if not _can_pay(db, run, "scissors"):
		return _need_ink(db, run, "scissors")
	_pay(db, run, "scissors")
	card.clauses[ci][slot] = null
	# the card shows a hole where it was
	if not card.clauses[ci].has("holes"):
		card.clauses[ci].holes = []
	card.clauses[ci].holes.append(slot)
	run.clipboard.append(Grammar.strip_chunk(ch))
	_tidy(card)
	return _ok()


## Paste clipboard[clip_idx] into a slot. ci == clauses.size() starts a new clause.
static func glue(db: Dictionary, run: Dictionary, uid: String, ci: int, slot: String, clip_idx: int) -> Dictionary:
	var card = find_card(run, uid)
	var ch = run.clipboard[clip_idx] if clip_idx >= 0 and clip_idx < run.clipboard.size() else null
	if not card or not ch:
		return _fail("Pick a chunk from your clipboard first.")
	if ch.type != slot:
		return _fail("%s %s chunk only fits %s %s slot." % [_article(ch.type).capitalize(), ch.type.capitalize(), _article(ch.type), ch.type.capitalize()])
	var is_new: bool = ci == card.clauses.size()
	if is_new and card.clauses.size() >= db.rules.maxClauses:
		return _fail("A card holds at most %d clauses." % db.rules.maxClauses)
	if not is_new and ci >= card.clauses.size():
		return _fail("That clause does not exist.")
	if not _can_pay(db, run, "glue"):
		return _need_ink(db, run, "glue")
	_pay(db, run, "glue")
	if is_new:
		card.clauses.append(Grammar.empty_clause())
	var old = card.clauses[ci][slot]
	ch.pasted = true  # shown as a slip glued onto the card
	card.clauses[ci][slot] = ch
	if card.clauses[ci].has("holes"):
		card.clauses[ci].holes.erase(slot)
	run.clipboard.remove_at(clip_idx)
	if old:
		run.clipboard.append(Grammar.strip_chunk(old))
	return _ok()


static func _chunk_at(run: Dictionary, uid: String, ci: int, slot: String) -> Variant:
	var card = find_card(run, uid)
	if not card or ci >= card.clauses.size():
		return null
	return card.clauses[ci][slot]


static func mute(db: Dictionary, run: Dictionary, uid: String, ci: int, slot: String) -> Dictionary:
	var ch = _chunk_at(run, uid, ci, slot)
	if not ch:
		return _fail("There is no chunk there to mute.")
	if not _can_pay(db, run, "mute"):
		return _need_ink(db, run, "mute")
	_pay(db, run, "mute")
	ch.muted = not ch.get("muted", false)
	ch.erase("redacted")
	return _ok()


static func invert(db: Dictionary, run: Dictionary, uid: String, ci: int, slot: String) -> Dictionary:
	var card = find_card(run, uid)
	if not _chunk_at(run, uid, ci, slot):
		return _fail("There is no chunk there to invert.")
	if not _can_pay(db, run, "invert"):
		return _need_ink(db, run, "invert")
	_pay(db, run, "invert")
	Grammar.invert_chunk(db, card.clauses[ci], slot)
	return _ok()


static func merged_name(a: String, b: String) -> String:
	var first := a.split(" ")[0]
	var bw := b.split(" ")
	var last := bw[bw.size() - 1]
	return a if first == last else "%s %s" % [first, last]


static func merge(db: Dictionary, run: Dictionary, uid_a: String, uid_b: String) -> Dictionary:
	var a = find_card(run, uid_a)
	var b = find_card(run, uid_b)
	if not a or not b or a == b:
		return _fail("Pick two different cards to merge.")
	var n: int = a.clauses.size() + b.clauses.size()
	if n > db.rules.maxClauses:
		return _fail("Together they have %d clauses; a card holds at most %d." % [n, db.rules.maxClauses])
	if not _can_pay(db, run, "merge"):
		return _need_ink(db, run, "merge")
	_pay(db, run, "merge")
	a.clauses.append_array(b.clauses)
	a.name = merged_name(a.name, b.name)
	run.deck.erase(b)
	return _ok()


static func shred(db: Dictionary, run: Dictionary, uid: String) -> Dictionary:
	var card = find_card(run, uid)
	if not card:
		return _fail("Pick a card to shred.")
	if run.deck.size() <= 1:
		return _fail("You need at least one card in your deck.")
	_pay(db, run, "shred")
	var lost := 0
	for clause in card.clauses:
		for slot in Grammar.SLOTS:
			if not clause[slot]:
				continue
			if run.clipboard.size() < db.rules.clipboardSize:
				run.clipboard.append(Grammar.strip_chunk(clause[slot]))
			else:
				lost += 1
	run.deck.erase(card)
	if lost:
		return _ok("%d chunk%s didn't fit on the clipboard and were lost." % [lost, "s" if lost > 1 else ""])
	return _ok()


static func drop_clip(run: Dictionary, idx: int) -> Dictionary:
	run.clipboard.remove_at(idx)
	return _ok()


## Apply a tool to a throwaway copy, for the live cost preview. Returns the edited card or null.
static func preview(db: Dictionary, run: Dictionary, tool: String, args: Array) -> Variant:
	var copy: Dictionary = run.duplicate(true)
	copy.sandbox = true
	var res: Dictionary
	match tool:
		"scissors":
			res = cut(db, copy, args[0], args[1], args[2])
		"glue":
			res = glue(db, copy, args[0], args[1], args[2], args[3])
		"mute":
			res = mute(db, copy, args[0], args[1], args[2])
		"invert":
			res = invert(db, copy, args[0], args[1], args[2])
		_:
			return null
	return find_card(copy, args[0]) if res.ok else null
