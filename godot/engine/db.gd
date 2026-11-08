## Loads the shared content files (data/*.json) into one Dictionary:
## { chunks, cards, enemies, rules }. JSON numbers arrive as floats in Godot,
## so whole numbers are turned back into ints to match the JS engine exactly.
class_name Db


static func load_all(dir: String = "res://data") -> Dictionary:
	var db := {}
	for n in ["chunks", "cards", "enemies", "rules"]:
		var text := FileAccess.get_file_as_string("%s/%s.json" % [dir, n])
		var parsed = JSON.parse_string(text)
		assert(parsed != null, "Could not parse %s.json" % n)
		db[n] = ints(parsed)
	return db


static func ints(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if v == floor(v) and abs(v) < 1e15 else v
		TYPE_ARRAY:
			var out := []
			for x in v:
				out.append(ints(x))
			return out
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[k] = ints(v[k])
			return d
	return v


## Deep copy that keeps the int/float split (JSON round trips would not).
static func clone(v: Variant) -> Variant:
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v
