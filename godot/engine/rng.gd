# Seeded RNG (mulberry32), bit-identical to engine/rng.js.
# GDScript ints are 64-bit, so every step is masked back to 32 bits and the
# 32x32 multiply is split so it can never overflow int64.
# State is a Dictionary with a "seed" key, so runs replay exactly.

const MASK := 0xFFFFFFFF


static func _imul(a: int, b: int) -> int:
	a &= MASK
	b &= MASK
	var lo := (a & 0xFFFF) * b
	var hi := (((a >> 16) * b) & 0xFFFF) << 16
	return (lo + hi) & MASK


static func rand(s: Dictionary) -> float:
	s["seed"] = (int(s["seed"]) + 0x6d2b79f5) & MASK
	var t: int = s["seed"]
	t = _imul(t ^ (t >> 15), t | 1)
	t ^= (t + _imul(t ^ (t >> 7), t | 61)) & MASK
	return float((t ^ (t >> 14)) & MASK) / 4294967296.0


static func rand_int(s: Dictionary, n: int) -> int:
	return int(floor(rand(s) * n))


# Returns null for an empty array without consuming a roll (same as JS).
static func pick(s: Dictionary, arr: Array):
	if arr.is_empty():
		return null
	return arr[rand_int(s, arr.size())]


static func shuffle(s: Dictionary, arr: Array) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rand_int(s, i + 1)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a
