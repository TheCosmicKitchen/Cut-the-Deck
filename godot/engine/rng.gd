## Seeded RNG (mulberry32), bit-for-bit identical to engine/rng.js.
## The seed lives in plain state ({ "seed": int }) so runs replay exactly.
class_name Rng

const M32 := 0xFFFFFFFF


static func _imul(a: int, b: int) -> int:
	return (a * b) & M32


static func rand(s: Dictionary) -> float:
	var t: int = (int(s.seed) + 0x6D2B79F5) & M32
	s.seed = t
	t = _imul(t ^ (t >> 15), t | 1)
	t = t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & M32)
	return float((t ^ (t >> 14)) & M32) / 4294967296.0


static func rand_int(s: Dictionary, n: int) -> int:
	return int(floor(rand(s) * n))


static func pick(s: Dictionary, arr: Array) -> Variant:
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
