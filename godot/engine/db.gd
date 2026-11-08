# Loads the four JSON files into one Dictionary: { cards, chunks, enemies, rules }.
# Godot's JSON parser returns every number as a float; whole numbers are turned
# back into ints so amounts, HP and log text behave exactly as in the JS build.

const FILES := ["cards", "chunks", "enemies", "rules"]


static func load_db(dir := "res://data") -> Dictionary:
	var db := {}
	for name in FILES:
		var path := "%s/%s.json" % [dir, name]
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			push_error("Cut the Deck: could not open %s" % path)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed == null:
			push_error("Cut the Deck: %s is not valid JSON" % path)
			return {}
		db[name] = _ints(parsed)
	return db


static func _ints(v):
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _ints(v[k])
		return out
	if v is Array:
		var out := []
		for x in v:
			out.append(_ints(x))
		return out
	if v is float and is_finite(v) and v == floor(v):
		return int(v)
	return v
