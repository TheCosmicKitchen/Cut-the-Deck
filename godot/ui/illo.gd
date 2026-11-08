## Card illustrations: small cut-paper collage scenes, one per card, starring Pip,
## the tangerine paper cat. Every shape is a piece of paper with a rough-cut edge
## and a soft shadow. Scenes are drawn once at 2x and cached as textures.
##
## A card shows card.art if set (so art can be swapped), else its base card's scene.
class_name Illo
extends RefCounted

const DESIGN := Vector2(212, 112)   # scenes are authored in this space
const GROUND := 92.0

const INK := Color("#2a1d55")
const CAT := Color("#ff9f4a")
const CAT_D := Color("#e0702a")
const CREAM := Color("#fff4e4")
const BLUSH := Color("#ff8fa8")
const SCARF := Color("#26aeb0")
const KRAFT := Color("#d9ae7e")
const KRAFT_D := Color("#b5845a")
const BURLAP := Color("#ecd3a0")
const RED := Color("#e8485e")
const MUSTARD := Color("#f6b733")
const LEAF := Color("#5cbf6a")
const LEAF_D := Color("#3f9a52")
const STONE := Color("#9aa0b8")
const WHITE := Color("#fffdf8")
const WOOD_INK := Color("#2e1a0e")
const WOOD_PAPER := Color("#f0e2c0")
const RISO := Color("#ff4f9a")
const PULP_RED := Color("#d01828")
const SKIN := Color("#f2c29b")
const DENIM := Color("#3b5c9a")

## which scene each card uses; anything missing falls back on its verb
const SCENES := {
	"strike": "strike", "defend": "defend", "jab": "jab", "reckless_swing": "reckless",
	"second_wind": "second_wind", "cheap_shot": "cheap_shot", "bulwark": "bulwark",
	"opening": "opening", "blood_price": "blood_price",
}
## each publication has its own cast; these scenes are drawn for it
const PUB_SCENES := {
	"reckless_swing": "slugger", "jab": "hero_jab", "blood_price": "blood_price",
	"all_in": "punk", "defend": "flatpack", "second_wind": "farmer_wind",
	"bulwark": "flatpack", "flurry": "hero_jab", "strike": "slugger", "exploit": "blood_price",
}
const BY_VERB := {"deal": "strike", "block": "defend", "draw": "second_wind", "discard": "second_wind",
	"lose_block": "bulwark", "strength": "opening"}

static var _cache := {}


static func scene_for(card: Dictionary, verb: String) -> String:
	if card.has("art"):
		return card.art
	return SCENES.get(card.get("base", ""), BY_VERB.get(verb, "strike"))


## A texture of the scene at this size. Returns null the first time; `done` is called
## with the texture once it has been drawn.
## style: how the scene is printed: "paper" (cut paper), "photo" (grey press photo),
## "ink" (comic inks), "silhouette" (pulp painting), "xerox" (photocopy), "line"
## (flat-pack line drawing), "woodcut" (almanac engraving).
static func texture(tree: SceneTree, scene: String, pal: Array, sz: Vector2, done: Callable, style := "paper") -> void:
	var key := "%s|%s|%s|%dx%d" % [scene, style, pal[0].to_html(), sz.x, sz.y]
	if _cache.has(key):
		done.call(_cache[key])
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(sz * 2.0)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas := Canvas.new()
	canvas.scene = scene
	canvas.style = style
	canvas.pal = pal
	canvas.size = sz * 2.0
	vp.add_child(canvas)
	tree.root.add_child.call_deferred(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	vp.queue_free()
	done.call(tex)


class Canvas extends Control:
	var scene := "strike"
	var style := "paper"
	var pal: Array
	var _base := Transform2D()
	var _rng := RandomNumberGenerator.new()
	var _n := 0

	# ---------- paper toolkit ----------

	func _seed() -> void:
		_n += 1
		_rng.seed = hash(scene) + _n * 7919

	## Subdivide the outline and nudge each point a little: a hand-cut edge.
	func _rough(pts: PackedVector2Array, amt := 0.6, step := 4.0) -> PackedVector2Array:
		_seed()
		var out := PackedVector2Array()
		var n := pts.size()
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			var k := maxi(1, int(a.distance_to(b) / step))
			var nrm := (b - a).orthogonal().normalized()
			for j in k:
				var p := a.lerp(b, float(j) / k)
				if j > 0:
					p += nrm * _rng.randf_range(-amt, amt)
				out.append(p)
		return out

	## One piece of paper: a soft shadow under it, then the piece.
	func paper(pts: PackedVector2Array, col: Color, shadow := true, amt := 0.6) -> void:
		if pts.size() < 3:
			return
		var rough_amt: float = {"paper": amt, "photo": amt * 0.5, "ink": 0.15, "line": 0.0, "woodcut": 0.7, "xerox": 1.0, "silhouette": 0.4}.get(style, amt)
		var r := _rough(pts, rough_amt) if rough_amt > 0.0 else pts
		if shadow and style in ["paper", "photo"]:
			var sh := PackedVector2Array()
			for p in r:
				sh.append(p + Vector2(1.3, 1.8))
			draw_colored_polygon(sh, Color(INK, 0.22 if style == "paper" else 0.3))
		draw_colored_polygon(r, tone(col))
		var ow: float = {"ink": 1.6, "line": 0.75, "woodcut": 1.1, "xerox": 0.9}.get(style, 0.0)
		if ow > 0.0:
			var loop := r.duplicate()
			loop.append(r[0])
			draw_polyline(loop, line_col(), ow, true)

	const GLOW := [MUSTARD, PULP_RED]

	## A colour as this style prints it.
	func tone(col: Color) -> Color:
		var l := col.get_luminance()
		match style:
			"photo":
				var g := clampf((l - 0.5) * 1.25 + 0.55, 0.05, 0.97)
				return Color(g, g, g, col.a)
			"silhouette":
				if col == MUSTARD:
					return Color("#ffd36a")
				if col == PULP_RED:
					return col
				return Color("#16061f").lerp(Color("#3a0a2a"), clampf(l - 0.4, 0.0, 0.6))
			"woodcut":
				return Color(WOOD_INK, col.a) if l < 0.6 else Color(WOOD_PAPER, col.a)
			"xerox":
				return Color(0.07, 0.07, 0.07, col.a) if l < 0.6 else Color(0.96, 0.955, 0.945, col.a)
			"line":
				return Color(1, 1, 1, col.a) if l > 0.15 else Color("#1a1a1a")
			"ink":
				return Color(col.r, col.g, col.b, col.a).lightened(0.05)
		return col

	func line_col() -> Color:
		match style:
			"woodcut":
				return WOOD_INK
			"line":
				return Color("#1a1a1a")
		return Color(0.04, 0.04, 0.05)

	func circ(c: Vector2, r: float) -> PackedVector2Array:
		return ell(c, r, r)

	func ell(c: Vector2, rx: float, ry: float, rot := 0.0) -> PackedVector2Array:
		var n := clampi(int(maxf(rx, ry) * 1.8), 10, 48)
		var pts := PackedVector2Array()
		for i in n:
			var a := TAU * i / n
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
		return pts

	func rect(c: Vector2, w: float, h: float, rot := 0.0) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for v in [Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)]:
			pts.append(c + (v * 0.5).rotated(rot))
		return pts

	func tri(a: Vector2, b: Vector2, c: Vector2) -> PackedVector2Array:
		return PackedVector2Array([a, b, c])

	## A thick line along a path; taper 0..1 thins the far end (1 = to a point).
	func stroke(path: Array, w: float, taper := 0.0, taper_start := 0.0) -> PackedVector2Array:
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var n := path.size()
		for i in n:
			var p: Vector2 = path[i]
			var d: Vector2 = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
			var t := float(i) / (n - 1)
			var ww := w * 0.5 * (1.0 - taper * t) * (1.0 - taper_start * (1.0 - t))
			left.append(p + d.orthogonal() * ww)
			right.append(p - d.orthogonal() * ww)
		right.reverse()
		left.append_array(right)
		return left

	func arc_path(c: Vector2, r: float, a0: float, a1: float, n := 16) -> Array:
		var out := []
		for i in n + 1:
			var a := lerpf(a0, a1, float(i) / n)
			out.append(c + Vector2(cos(a), sin(a)) * r)
		return out

	## a crescent swoosh: an arc band that swells in the middle
	func swoosh(c: Vector2, r: float, a0: float, a1: float, w: float) -> PackedVector2Array:
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var n := 20
		for i in n + 1:
			var t := float(i) / n
			var a := lerpf(a0, a1, t)
			var d := Vector2(cos(a), sin(a))
			outer.append(c + d * (r + w * 0.5 * sin(PI * t)))
			inner.append(c + d * (r - w * 0.5 * sin(PI * t)))
		inner.reverse()
		outer.append_array(inner)
		return outer

	func star(c: Vector2, r: float, points := 8, inner := 0.5, rot := 0.0) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in points * 2:
			var rr := r if i % 2 == 0 else r * inner
			var a := rot + PI * i / points - PI * 0.5
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		return pts

	func ink(a: Vector2, b: Vector2, w := 1.4, alpha := 1.0) -> void:
		var c := Color(INK, alpha) if style in ["paper", "ink"] else Color(line_col(), alpha)
		if style == "silhouette":
			c = Color("#ffd36a", alpha)
		draw_line(a, b, c, w, true)

	func dot(c: Vector2, r: float, col := INK) -> void:
		if style == "silhouette":
			# in the dark only eyes glow
			if col == INK:
				draw_circle(c, r * 1.6, Color(1.0, 0.85, 0.3, 0.35), true, -1.0, true)
				draw_circle(c, r, Color("#ffe27a"), true, -1.0, true)
			return
		var t := col if style == "paper" else (line_col() if col.get_luminance() < 0.5 else tone(col))
		draw_circle(c, r, t, true, -1.0, true)

	## draw in a local frame: origin at pos, scaled, mirrored when flip
	func push(pos: Vector2, s := 1.0, flip := false, rot := 0.0) -> void:
		draw_set_transform_matrix(_base * Transform2D(rot, Vector2(-s if flip else s, s), 0.0, pos))

	func pop() -> void:
		draw_set_transform_matrix(_base)

	# ---------- the cast ----------

	## Pip, feet at the origin, facing right, ~50 units tall. Paws are returned
	## (local) so a scene can put things in them.
	## pose: "stand" | "swing" | "crouch" | "push" | "peek"
	func pip(pose := "stand", paw_a := Vector2(14, -18), paw_b := Vector2(-4, -16), opts := {}) -> void:
		var crouch := 6.0 if pose in ["crouch", "peek"] else 0.0
		# tail
		paper(stroke([Vector2(-9, -6), Vector2(-17, -10), Vector2(-21, -19), Vector2(-18, -28), Vector2(-13, -30)], 5.5, 0.55), CAT_D)
		# legs
		paper(ell(Vector2(-5, -2.5), 4.5, 3.2), CAT_D)
		paper(ell(Vector2(6, -2.5), 4.5, 3.2), CAT_D)
		# body
		paper(ell(Vector2(0, -13 + crouch * 0.4), 11.0, 12.0 - crouch * 0.3), CAT)
		paper(ell(Vector2(3, -11 + crouch * 0.4), 5.5, 7.0), CREAM, false)
		# back arm
		paper(stroke([Vector2(-2, -18 + crouch), paw_b], 5.0), CAT_D)
		paper(circ(paw_b, 3.2), CAT_D)
		# head
		var hy := -32.0 + crouch
		paper(tri(Vector2(-8, hy - 5), Vector2(-9, hy - 17), Vector2(1, hy - 9)), CAT)
		paper(tri(Vector2(4, hy - 9), Vector2(12, hy - 17), Vector2(12, hy - 4)), CAT)
		paper(tri(Vector2(-6.5, hy - 7), Vector2(-7.5, hy - 13), Vector2(-2, hy - 9)), BLUSH, false)
		paper(tri(Vector2(6, hy - 9), Vector2(10.5, hy - 13.5), Vector2(10.5, hy - 7)), BLUSH, false)
		paper(ell(Vector2(2, hy), 12.0, 10.5), CAT)
		# stripes
		paper(tri(Vector2(-1, hy - 10.5), Vector2(1, hy - 5), Vector2(3, hy - 10.5)), CAT_D, false, 0.3)
		paper(tri(Vector2(-6, hy - 8.5), Vector2(-3, hy - 4.5), Vector2(-3, hy - 9.5)), CAT_D, false, 0.3)
		# muzzle and face
		paper(ell(Vector2(7.5, hy + 3.5), 5.5, 4.0), CREAM, false, 0.3)
		var eyes: String = opts.get("eyes", "open")
		if eyes == "dizzy":
			for ex in [3.5, 10.5]:
				ink(Vector2(ex - 1.8, hy - 2.8), Vector2(ex + 1.8, hy + 0.8), 1.3)
				ink(Vector2(ex + 1.8, hy - 2.8), Vector2(ex - 1.8, hy + 0.8), 1.3)
		elif eyes == "squint":
			for ex in [3.5, 10.5]:
				draw_polyline(PackedVector2Array([Vector2(ex - 2, hy - 2), Vector2(ex, hy - 0.2), Vector2(ex + 2, hy - 2)]), INK, 1.4, true)
		else:
			dot(Vector2(3.5, hy - 1), 1.7)
			dot(Vector2(10.5, hy - 1), 1.7)
			dot(Vector2(4.0, hy - 1.7), 0.55, WHITE)
			dot(Vector2(11.0, hy - 1.7), 0.55, WHITE)
		dot(Vector2(8, hy + 2.2), 1.1, Color("#c2456a"))
		dot(Vector2(-1.5, hy + 3), 2.0, Color(BLUSH, 0.8))
		# scarf, its end flying behind
		paper(stroke([Vector2(-8, hy + 10), Vector2(-15, hy + 8), Vector2(-21, hy + 11)], 4.0, 0.2), SCARF)
		paper(stroke([Vector2(-8, hy + 10), Vector2(0, hy + 11.5), Vector2(10, hy + 10)], 4.8), SCARF)
		# front arm
		paper(stroke([Vector2(4, -18 + crouch), paw_a], 5.0), CAT)
		paper(circ(paw_a, 3.4), CAT)

	## a burlap training dummy on a post, base at the origin
	func dummy(hit := false, s := 1.0, lean := 0.0) -> void:
		paper(rect(Vector2(0, -8), 3.5, 18), KRAFT_D)
		paper(rect(Vector2(0, -1), 14, 3.5), KRAFT_D)
		var top := Vector2(lean * 10.0, -24)
		paper(ell(top + Vector2(0, -2), 10.5, 12.5, lean * 0.3), BURLAP)
		paper(circ(top + Vector2(0, -2), 5.5), RED, false)
		paper(circ(top + Vector2(0, -2), 2.5), WHITE, false)
		paper(rect(top + Vector2(-9, -6), 7, 3, -0.4 + lean), BURLAP)
		paper(rect(top + Vector2(9, -6), 7, 3, 0.4 + lean), BURLAP)
		var head := top + Vector2(lean * 4.0, -21)
		paper(circ(head, 7.5), BURLAP)
		for ex in [-2.8, 2.8]:
			ink(head + Vector2(ex - 1.3, -1.8), head + Vector2(ex + 1.3, 0.8), 1.1)
			ink(head + Vector2(ex + 1.3, -1.8), head + Vector2(ex - 1.3, 0.8), 1.1)
		# stitches
		for i in 4:
			var y := top.y - 12.0 + i * 6.0
			ink(top + Vector2(-1, y - top.y), top + Vector2(1, y - top.y + 2.5), 0.9, 0.6)
		if hit:
			paper(star(top + Vector2(-9, -4), 9.0, 8, 0.45), MUSTARD)
			paper(star(top + Vector2(-9, -4), 4.5, 8, 0.5), WHITE, false)

	func card_piece(c: Vector2, rot: float, back: bool, col: Color) -> void:
		paper(rect(c, 12, 16, rot), WHITE)
		if back:
			paper(rect(c, 9, 13, rot), col, false, 0.3)
			paper(rect(c, 4, 4, rot + PI * 0.25), WHITE, false, 0.2)
		else:
			paper(circ(c + Vector2(0, 0).rotated(rot), 2.6), RED, false, 0.2)
			dot(c + Vector2(-3.5, -5.5).rotated(rot), 0.9, RED)

	func arrow(c: Vector2, rot: float, len := 22.0) -> void:
		var d := Vector2(cos(rot), sin(rot))
		var tail := c - d * len * 0.5
		var tip := c + d * len * 0.5
		paper(stroke([tail, tip], 2.2), KRAFT_D)
		paper(tri(tip + d * 6.0, tip + d.orthogonal() * 3.6, tip - d.orthogonal() * 3.6), STONE)
		paper(tri(tail, tail - d * 5.0 + d.orthogonal() * 4.0, tail + d * 2.0), RED, false)
		paper(tri(tail, tail - d * 5.0 - d.orthogonal() * 4.0, tail + d * 2.0), RED, false)

	# ---------- scenes ----------

	func _draw() -> void:
		var k: float = size.y / DESIGN.y
		var off := Vector2((size.x - DESIGN.x * k) * 0.5, 0.0)
		_base = Transform2D(0.0, Vector2(k, k), 0.0, off)
		var lo := -off.x / k
		var hi := (size.x - off.x) / k
		call("_bg_" + style, lo, hi)
		call("_" + scene, lo, hi)
		draw_set_transform_matrix(Transform2D())
		if style == "xerox":
			# toner specks and a copier streak
			_rng.seed = hash(scene) + 99
			for i in 260:
				draw_circle(Vector2(_rng.randf() * size.x, _rng.randf() * size.y), _rng.randf_range(0.4, 1.3), Color(0, 0, 0, 0.7), true, -1.0, true)
			draw_rect(Rect2(size.x * 0.83, 0, 6, size.y), Color(0, 0, 0, 0.12))
		if style != "paper":
			return
		# a soft inner shadow so the window feels sunk into the card
		for i in 6:
			var a := 0.16 * (1.0 - i / 6.0)
			draw_rect(Rect2(0, i * 2, size.x, 2), Color(INK, a))
			draw_rect(Rect2(i * 2, 0, 2, size.y), Color(INK, a * 0.7))

	func _hills() -> void:
		var hill_col: Color = pal[1].lerp(pal[2], 0.35)
		paper(ell(Vector2(40, 98), 70, 34), hill_col, false, 1.0)
		paper(ell(Vector2(190, 102), 80, 30), hill_col.lerp(pal[1], 0.5), false, 1.0)

	func _bg_paper(lo: float, hi: float) -> void:
		draw_rect(Rect2(Vector2.ZERO, size), pal[2])
		pop()
		_hills()

	func _bg_photo(lo: float, hi: float) -> void:
		for i in 16:
			var g := 0.78 + i * 0.012
			draw_rect(Rect2(0, size.y * i / 16.0, size.x, size.y / 16.0 + 1), Color(g, g, g))
		pop()
		_hills()

	func _bg_ink(lo: float, hi: float) -> void:
		# a comic panel sky: flat colour with a burst of speed lines
		draw_rect(Rect2(Vector2.ZERO, size), Color("#ffe14d"))
		pop()
		var focus := Vector2(150, 46)
		for i in 28:
			var a0 := i * TAU / 28.0
			var a1 := a0 + TAU / 56.0
			draw_colored_polygon(PackedVector2Array([focus, focus + Vector2(cos(a0), sin(a0)) * 400.0, focus + Vector2(cos(a1), sin(a1)) * 400.0]), Color("#ff9a2e") if i % 2 == 0 else Color("#ffd02e"))
		draw_circle(focus, 26, Color("#fff6c0"), true, -1.0, true)

	func _bg_line(lo: float, hi: float) -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
		pop()

	func _bg_xerox(lo: float, hi: float) -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.96, 0.955, 0.945))
		pop()
		# collage: a black torn block, a riso pink block behind the action
		paper(PackedVector2Array([Vector2(lo - 4, 8), Vector2(70, 2), Vector2(84, 64), Vector2(lo - 4, 72)]), Color(0.07, 0.07, 0.07), false, 1.2)
		draw_colored_polygon(_rough(PackedVector2Array([Vector2(96, 10), Vector2(204, 16), Vector2(198, 84), Vector2(100, 80)]), 1.0), RISO)
		for i in 5:
			draw_line(Vector2(104, 22 + i * 12), Vector2(190, 26 + i * 12), Color(1, 1, 1, 0.35), 1.2)

	func _bg_woodcut(lo: float, hi: float) -> void:
		draw_rect(Rect2(Vector2.ZERO, size), WOOD_PAPER)
		pop()
		# engraved sky: fine horizontal lines that thin out toward the horizon
		for i in 30:
			var y := 2.0 + i * 2.6
			var w := lerpf(0.9, 0.15, i / 30.0)
			draw_line(Vector2(lo, y), Vector2(hi, y), Color(WOOD_INK, 0.7), w)
		_hills()

	func _bg_silhouette(lo: float, hi: float) -> void:
		# a lurid painted sky with a huge glowing moon
		for i in 24:
			var t := i / 23.0
			var c := Color("#2a0838").lerp(Color("#c4202e"), smoothstep(0.1, 0.75, t)).lerp(Color("#ff8a2a"), smoothstep(0.7, 1.0, t))
			draw_rect(Rect2(0, size.y * i / 24.0, size.x, size.y / 24.0 + 1), c)
		pop()
		var moon := Vector2(150, 40)
		for i in 5:
			draw_circle(moon, 34.0 + i * 7.0, Color(1.0, 0.75, 0.3, 0.08), true, -1.0, true)
		draw_circle(moon, 30, Color("#ffe6a0"), true, -1.0, true)
		draw_circle(moon + Vector2(8, -6), 6, Color(0.9, 0.7, 0.4, 0.5), true, -1.0, true)
		draw_circle(moon + Vector2(-10, 9), 4, Color(0.9, 0.7, 0.4, 0.5), true, -1.0, true)
		# black hills and a dead tree
		draw_colored_polygon(_rough(PackedVector2Array([Vector2(lo - 4, 80), Vector2(60, 70), Vector2(120, 84), Vector2(hi + 4, 74), Vector2(hi + 4, 120), Vector2(lo - 4, 120)]), 1.0), Color("#12040e"))
		var tr := [Vector2(196, 92), Vector2(194, 60), Vector2(186, 44), Vector2(178, 40)]
		draw_colored_polygon(stroke(tr, 4.0, 0.7), Color("#12040e"))
		draw_colored_polygon(stroke([Vector2(194, 66), Vector2(204, 52), Vector2(210, 50)], 2.5, 0.8), Color("#12040e"))

	func ground(lo: float, hi: float, col: Color, y := GROUND) -> void:
		if style == "line":
			draw_line(Vector2(lo, y), Vector2(hi, y), Color("#1a1a1a"), 0.8, true)
			return
		if style == "silhouette":
			return
		paper(PackedVector2Array([Vector2(lo - 4, y + 1), Vector2(hi + 4, y - 1), Vector2(hi + 4, 120), Vector2(lo - 4, 120)]), col, true, 1.1)

	func sun(c: Vector2, r: float) -> void:
		if style in ["line", "silhouette", "xerox"]:
			return
		if style == "woodcut":
			# the almanac's sun has a face and rays
			for i in 16:
				var a := i * TAU / 16.0
				var d := Vector2(cos(a), sin(a))
				draw_colored_polygon(PackedVector2Array([c + d * (r + 1) + d.orthogonal() * 2.2, c + d * (r + (7.0 if i % 2 == 0 else 4.0)), c + d * (r + 1) - d.orthogonal() * 2.2]), WOOD_INK)
			paper(circ(c, r), WOOD_PAPER, false)
			dot(c + Vector2(-3.5, -2), 1.1, INK)
			dot(c + Vector2(3.5, -2), 1.1, INK)
			draw_arc(c + Vector2(0, 1), 4.5, 0.3, PI - 0.3, 8, WOOD_INK, 0.9, true)
			return
		paper(circ(c, r), MUSTARD.lerp(WHITE, 0.45), false)

	func _strike(lo: float, hi: float) -> void:
		sun(Vector2(178, 24), 13)
		ground(lo, hi, pal[3])
		push(Vector2(164, GROUND))
		dummy(true, 1.0, -0.15)
		pop()
		# the slash: a white crescent from Pip's sword to the dummy
		paper(swoosh(Vector2(104, 92), 58, -2.25, -0.55, 11.0), WHITE)
		push(Vector2(62, GROUND), 1.1)
		pip("swing", Vector2(17, -26), Vector2(-6, -15))
		# cardboard sword swung down and forward
		var grip := Vector2(17, -26)
		var d := Vector2(cos(-0.35), sin(-0.35))
		paper(stroke([grip - d * 5.0, grip + d * 4.0], 3.4), INK)
		paper(rect(grip + d * 5.0, 3.0, 12.0, -0.35), RED)
		paper(PackedVector2Array([grip + d * 6.0 + d.orthogonal() * 3.2, grip + d * 38.0 + d.orthogonal() * 3.2, grip + d * 44.0, grip + d * 38.0 - d.orthogonal() * 3.2, grip + d * 6.0 - d.orthogonal() * 3.2]), KRAFT)
		ink(grip + d * 8.0, grip + d * 38.0, 0.9, 0.35)
		pop()

	func _defend(lo: float, hi: float) -> void:
		sun(Vector2(30, 22), 11)
		ground(lo, hi, pal[3])
		# arrows coming in from the right, one bouncing off
		arrow(Vector2(186, 46), PI + 0.08)
		arrow(Vector2(176, 70), PI - 0.05)
		arrow(Vector2(150, 18), -0.9 + PI)
		push(Vector2(74, GROUND))
		pip("crouch", Vector2(16, -20), Vector2(12, -26))
		pop()
		# a giant sewing button for a shield
		var c := Vector2(128, 62)
		paper(circ(c, 27), pal[0])
		paper(circ(c, 21), pal[0].darkened(0.12), false, 0.4)
		paper(circ(c + Vector2(-3, -3), 21), pal[0].lightened(0.08), false, 0.4)
		for h in [Vector2(-6, -6), Vector2(6, -6), Vector2(-6, 6), Vector2(6, 6)]:
			dot(c + h, 3.6, pal[0].darkened(0.45))
		draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), WHITE, 2.4, true)
		draw_line(c + Vector2(6, -6), c + Vector2(-6, 6), WHITE, 2.4, true)
		paper(swoosh(c, 26, -2.6, -1.4, 3.5), Color(WHITE, 0.7), false)
		paper(star(Vector2(150, 38), 6, 6, 0.45), MUSTARD)

	func _jab(lo: float, hi: float) -> void:
		ground(lo, hi, pal[3])
		# a punching bag on a rope, knocked back
		var top := Vector2(158, -2)
		var rot := -0.28
		var bag_c := top + Vector2(0, 50).rotated(rot)
		ink(top, top + Vector2(0, 18).rotated(rot), 1.6)
		paper(rect(bag_c, 28, 58, rot), RED)
		paper(rect(bag_c + Vector2(0, -14).rotated(rot), 28, 5, rot), RED.darkened(0.2), false, 0.3)
		paper(rect(bag_c + Vector2(0, 14).rotated(rot), 28, 5, rot), RED.darkened(0.2), false, 0.3)
		paper(star(bag_c + Vector2(-17, -4), 8, 8, 0.45), MUSTARD)
		paper(star(bag_c + Vector2(-14, 12), 5.5, 8, 0.45), WHITE)
		push(Vector2(76, GROUND), 1.1)
		pip("swing", Vector2(24, -24), Vector2(15, -15), {"eyes": "squint"})
		# boxing gloves, quick quick
		for g in [[Vector2(15, -15), 0.8], [Vector2(24, -24), 1.0]]:
			paper(ell(g[0] + Vector2(3, 0), 6.5 * g[1], 5.5 * g[1]), RED)
			paper(rect(g[0] + Vector2(-3.5, 0), 3, 8 * g[1]), WHITE)
		for i in 3:
			ink(Vector2(-8 - i * 3, -30 + i * 6), Vector2(2 - i * 3, -30 + i * 6), 1.3, 0.55)
		pop()

	func _reckless(lo: float, hi: float) -> void:
		sun(Vector2(186, 20), 10)
		ground(lo, hi, pal[3])
		for i in 3:
			push(Vector2(132 + i * 27, GROUND), 0.72)
			dummy(true, 1.0, -0.25 + i * 0.1)
			pop()
		# the mallet's full-circle swoosh
		paper(swoosh(Vector2(64, 60), 34, -3.6, 0.6, 9.0), WHITE)
		push(Vector2(60, GROUND), 1.05)
		pip("swing", Vector2(20, -30), Vector2(14, -24), {"eyes": "dizzy"})
		# the mallet, too big to control
		var grip := Vector2(20, -30)
		var d := Vector2(cos(-1.15), sin(-1.15))
		paper(stroke([grip - d * 4.0, grip + d * 26.0], 3.6), KRAFT_D)
		var head := grip + d * 30.0
		paper(rect(head, 28, 15, -1.15 + PI * 0.5), KRAFT)
		paper(rect(head + d.orthogonal() * 11.0, 4, 16, -1.15 + PI * 0.5), KRAFT_D, false)
		paper(rect(head - d.orthogonal() * 11.0, 4, 16, -1.15 + PI * 0.5), KRAFT_D, false)
		# and it got Pip too: a bump and circling stars
		paper(ell(Vector2(-2, -46), 4.5, 3.5), CAT_D)
		for i in 3:
			var a := -PI * 0.5 + i * TAU / 3.0 + 0.4
			paper(star(Vector2(2, -50) + Vector2(cos(a) * 13.0, sin(a) * 4.0), 3.6, 5, 0.45), MUSTARD)
		pop()

	func _second_wind(lo: float, hi: float) -> void:
		ground(lo, hi, pal[3])
		if style == "woodcut":
			# a puff-cheeked wind face in a cloud, blowing the cards about
			var w := Vector2(22, 24)
			for b in [[Vector2(-4, -6), 11.0], [Vector2(8, -10), 10.0], [Vector2(-8, 8), 10.0], [Vector2(4, 10), 9.0], [Vector2(0, 0), 13.0]]:
				paper(circ(w + b[0], b[1]), WHITE, false)
			paper(circ(w + Vector2(8, 0), 9.0), WHITE, false)
			dot(w + Vector2(6, -4), 1.2, INK)
			paper(ell(w + Vector2(15, 2), 3.0, 2.2), INK, false)
			for i in 4:
				draw_line(w + Vector2(20, -2 + i * 3), w + Vector2(48 + i * 6, -6 + i * 5), WOOD_INK, 0.8, true)
		# gusts
		for g in [[Vector2(100, 34), 1.0], [Vector2(140, 64), 0.8], [Vector2(60, 22), 0.7]]:
			var c: Vector2 = g[0]
			var s: float = g[1]
			paper(stroke([c + Vector2(-34, 0) * s, c + Vector2(-10, -3) * s, c + Vector2(12, 2) * s, c + Vector2(20, -6) * s, c + Vector2(16, -13) * s, c + Vector2(9, -9) * s], 4.5 * s, 0.8), WHITE, false)
		# cards: two arriving, two blowing away
		card_piece(Vector2(38, 30), -0.5, true, pal[0])
		card_piece(Vector2(22, 54), 0.35, true, pal[0])
		card_piece(Vector2(178, 28), 0.6, false, pal[0])
		card_piece(Vector2(196, 56), -0.3, false, pal[0])
		push(Vector2(98, GROUND), 1.1)
		pip("stand", Vector2(15, -24), Vector2(-8, -20), {"eyes": "squint"})
		# a pinwheel
		var hub := Vector2(18, -40)
		paper(stroke([Vector2(15, -24), hub], 1.8), KRAFT_D)
		var cols := [RED, MUSTARD, pal[0], LEAF]
		for i in 4:
			var a := i * PI * 0.5 + 0.3
			var d := Vector2(cos(a), sin(a))
			paper(tri(hub, hub + d * 10.0, hub + d.rotated(PI * 0.5) * 5.0 + d * 5.0), cols[i])
		dot(hub, 1.6, WHITE)
		pop()

	## A person, feet at the origin, ~56 units tall, facing right.
	## spec: skin, top, legs, hands [front, back], feet [front, back], plus extras.
	func person(spec: Dictionary) -> void:
		var skin: Color = spec.get("skin", SKIN)
		var top: Color = spec.get("top", RED)
		var legs: Color = spec.get("legs", DENIM)
		var hip := Vector2(0, -24)
		var sh := Vector2(1, -42)
		var hands: Array = spec.get("hands", [Vector2(14, -30), Vector2(-10, -26)])
		var feet: Array = spec.get("feet", [Vector2(7, 0), Vector2(-7, 0)])
		var lean: float = spec.get("lean", 0.0)
		sh += Vector2(lean, 0)
		var head := sh + Vector2(lean * 0.4, -9)
		# back limbs
		paper(stroke([hip + Vector2(-2, 0), (hip + feet[1]) * 0.5 + Vector2(-2, 1), feet[1]], 5.0), legs.darkened(0.15))
		paper(stroke([sh + Vector2(-3, 1), (sh + hands[1]) * 0.5 + Vector2(-1, 3), hands[1]], 4.0), top.darkened(0.15))
		paper(circ(hands[1], 2.6), skin.darkened(0.1))
		if spec.has("cape"):
			paper(PackedVector2Array([sh + Vector2(-5, 0), sh + Vector2(5, 0), Vector2(-14, -8), Vector2(-26, -2)]), spec.cape)
		if spec.has("dress"):
			paper(PackedVector2Array([sh + Vector2(-6, 2), sh + Vector2(6, 2), Vector2(12, -4), Vector2(-14, -2)]), spec.dress)
		# torso
		paper(PackedVector2Array([sh + Vector2(-7, 0), sh + Vector2(7, 0), hip + Vector2(6, 0), hip + Vector2(-6, 0)]), top)
		if spec.has("stripes"):
			for i in 3:
				var y := sh.y + 5.0 + i * 5.0
				paper(rect(Vector2((sh.x + hip.x) * 0.5, y), 13, 1.8), spec.stripes, false, 0.2)
		if spec.has("emblem"):
			paper(star(sh + Vector2(0, 8), 4.0, 5, 0.45), spec.emblem, false, 0.2)
		# front leg
		paper(stroke([hip + Vector2(2, 0), (hip + feet[0]) * 0.5 + Vector2(2, 1), feet[0]], 5.0), legs)
		paper(ell(feet[0] + Vector2(2, 0), 4.0, 2.2), spec.get("shoes", INK))
		paper(ell(feet[1] + Vector2(2, 0), 4.0, 2.2), spec.get("shoes", INK))
		# head
		paper(circ(head, 7.0), skin)
		match spec.get("hair", "short"):
			"short":
				paper(PackedVector2Array([head + Vector2(-7, -1), head + Vector2(-5, -7), head + Vector2(3, -8), head + Vector2(7, -3), head + Vector2(1, -4)]), spec.get("hair_col", INK))
			"mohawk":
				for i in 5:
					paper(tri(head + Vector2(-6 + i * 3, -5), head + Vector2(-8 + i * 3.5, -16 + abs(i - 2) * 2.0), head + Vector2(-3 + i * 3, -6)), spec.get("hair_col", RISO))
			"long":
				paper(PackedVector2Array([head + Vector2(-8, 8), head + Vector2(-8, -4), head + Vector2(0, -9), head + Vector2(7, -4), head + Vector2(2, -3), head + Vector2(-3, 10)]), spec.get("hair_col", INK))
			"bald":
				pass
		match spec.get("hat", ""):
			"cap":
				paper(PackedVector2Array([head + Vector2(-7, -2), head + Vector2(-5, -8), head + Vector2(5, -8), head + Vector2(7, -2)]), spec.get("hat_col", RED))
				paper(rect(head + Vector2(9, -2.5), 8, 2.2), spec.get("hat_col", RED))
			"straw":
				paper(ell(head + Vector2(0, -4), 14, 3.0), MUSTARD)
				paper(ell(head + Vector2(0, -7), 7, 5.0), MUSTARD)
		if spec.has("mask"):
			paper(rect(head + Vector2(2, -1), 13, 4), spec.mask, false, 0.2)
		var face: String = spec.get("face", "")
		if face == "scream":
			paper(ell(head + Vector2(3, 3), 1.8, 2.8), INK, false, 0.1)
		dot(head + Vector2(3.5, -1), 0.9)
		# front arm
		paper(stroke([sh + Vector2(2, 1), (sh + hands[0]) * 0.5 + Vector2(1, 3), hands[0]], 4.2), top)
		paper(circ(hands[0], spec.get("fist", 2.8)), spec.get("glove", skin))

	func _slugger(lo: float, hi: float) -> void:
		# the sports page: a batter connects, the stands behind
		for row in 4:
			for i in 30:
				var x := lo + i * 9.0 + (row % 2) * 4.5
				dot(Vector2(x, 20 + row * 9), 2.6, Color(0.82, 0.82, 0.82))
				paper(rect(Vector2(x, 26 + row * 9), 6, 5), Color(0.78, 0.78, 0.78).lightened(((i * 7 + row) % 5) * 0.04), false, 0.1)
		paper(PackedVector2Array([Vector2(lo - 4, 58), Vector2(hi + 4, 58), Vector2(hi + 4, 64), Vector2(lo - 4, 64)]), Color(0.35, 0.35, 0.35), false, 0.1)
		ground(lo, hi, Color(0.62, 0.62, 0.62))
		push(Vector2(92, GROUND), 1.05)
		person({"top": Color(0.18, 0.18, 0.2), "legs": Color(0.3, 0.3, 0.32), "stripes": Color(0.55, 0.55, 0.55), "hat": "cap", "hat_col": INK, "hair": "bald",
			"hands": [Vector2(16, -38), Vector2(12, -36)], "feet": [Vector2(14, 0), Vector2(-10, 0)], "lean": 4.0})
		# the bat, mid-swing, with a blur behind
		paper(stroke([Vector2(14, -37), Vector2(30, -50), Vector2(44, -60)], 4.0, 0.0, 0.4), INK)
		for i in 3:
			draw_arc(Vector2(10, -34), 26.0 + i * 5.0, -2.4, -1.1, 12, Color(1, 1, 1, 0.35), 1.2, true)
		pop()
		# the ball, leaving
		paper(circ(Vector2(178, 30), 4.2), INK, false)
		for i in 4:
			draw_line(Vector2(158 - i * 5, 38 + i * 2), Vector2(168 - i * 5, 34 + i * 2), Color(1, 1, 1, 0.5), 1.0, true)

	func _hero_jab(lo: float, hi: float) -> void:
		ground(lo, hi, Color("#5aa0e8"))
		# a goon knocked flying
		push(Vector2(160, GROUND - 6), 1.0, false, 0.5)
		person({"top": Color("#f2f2f2"), "stripes": INK, "legs": Color("#6b4a2e"), "hair": "bald", "hat": "cap", "hat_col": INK,
			"hands": [Vector2(-6, -52), Vector2(10, -50)], "feet": [Vector2(10, -4), Vector2(-8, 2)]})
		pop()
		paper(star(Vector2(130, 48), 12, 10, 0.5), WHITE)
		paper(star(Vector2(130, 48), 6, 10, 0.5), MUSTARD, false)
		# the hero, fist forward
		push(Vector2(74, GROUND), 1.15)
		person({"top": Color("#2f6fe4"), "legs": Color("#2f6fe4"), "cape": RED, "emblem": MUSTARD, "mask": INK, "glove": RED, "shoes": RED,
			"hands": [Vector2(36, -38), Vector2(-12, -30)], "feet": [Vector2(14, 0), Vector2(-12, 0)], "lean": 5.0, "fist": 4.2})
		pop()

	func _blood_price(lo: float, hi: float) -> void:
		# a towering hooded figure, eyes glowing, reaches for its price
		var c := Vector2(150, 96)
		paper(PackedVector2Array([c + Vector2(-34, 0), c + Vector2(-20, -60), c + Vector2(-8, -86), c + Vector2(8, -88), c + Vector2(22, -60), c + Vector2(40, 0)]), INK)
		paper(ell(c + Vector2(0, -74), 12, 14), INK)
		dot(c + Vector2(-5, -74), 2.0)
		dot(c + Vector2(5, -74), 2.0)
		paper(stroke([c + Vector2(-16, -52), c + Vector2(-38, -44), c + Vector2(-52, -46)], 5.0, 0.3), INK)
		for f in 4:
			paper(stroke([c + Vector2(-52, -46), c + Vector2(-60 - f * 1.5, -50 + f * 2.5)], 1.6, 0.6), INK)
		# the heroine recoils, hand at her throat
		push(Vector2(60, GROUND + 2), 1.2, true)
		person({"top": PULP_RED, "dress": PULP_RED, "legs": INK, "hair": "long", "face": "scream",
			"hands": [Vector2(4, -46), Vector2(16, -30)], "feet": [Vector2(4, 0), Vector2(-8, 0)], "lean": -4.0})
		pop()

	func _punk(lo: float, hi: float) -> void:
		ground(lo, hi, Color(0.07, 0.07, 0.07))
		# a punk mid-leap, guitar raised to smash
		push(Vector2(132, GROUND - 14), 1.15)
		person({"top": INK, "legs": Color(0.2, 0.2, 0.2), "hair": "mohawk", "hair_col": INK,
			"hands": [Vector2(10, -56), Vector2(4, -58)], "feet": [Vector2(12, -2), Vector2(-14, -10)], "lean": -3.0})
		paper(stroke([Vector2(8, -56), Vector2(-6, -76)], 2.6), INK)
		paper(PackedVector2Array([Vector2(-6, -76), Vector2(-18, -86), Vector2(-24, -80), Vector2(-16, -70), Vector2(-20, -62), Vector2(-10, -64)]), WHITE)
		pop()
		# scrawled X's and stars
		for x in [[Vector2(36, 30), 9.0], [Vector2(64, 60), 6.0], [Vector2(186, 36), 7.0]]:
			draw_line(x[0] - Vector2(x[1], x[1]), x[0] + Vector2(x[1], x[1]), Color.BLACK if x[0].x < 90 else Color.WHITE, 2.4, true)
			draw_line(x[0] + Vector2(-x[1], x[1]), x[0] + Vector2(x[1], -x[1]), Color.BLACK if x[0].x < 90 else Color.WHITE, 2.4, true)

	func _flatpack(lo: float, hi: float) -> void:
		ground(lo, hi, WHITE)
		# the flat-pack man holds up a shelf board; arrows bounce off it
		push(Vector2(84, GROUND), 1.1)
		person({"top": WHITE, "legs": WHITE, "skin": WHITE, "hair": "bald", "shoes": WHITE,
			"hands": [Vector2(16, -40), Vector2(14, -28)], "feet": [Vector2(6, 0), Vector2(-8, 0)]})
		pop()
		paper(PackedVector2Array([Vector2(104, 22), Vector2(118, 18), Vector2(122, 90), Vector2(108, 92)]), WHITE)
		for y in [30.0, 50.0, 70.0]:
			draw_circle(Vector2(113, y), 1.5, Color("#1a1a1a"), false, 0.7, true)
		arrow(Vector2(170, 40), PI + 0.06)
		arrow(Vector2(162, 66), PI - 0.08)
		arrow(Vector2(140, 14), -0.8 + PI)
		# the Allen key on the floor, and a "2×" callout
		draw_polyline(PackedVector2Array([Vector2(36, 90), Vector2(36, 84), Vector2(54, 82)]), Color("#1a1a1a"), 1.6, true)
		draw_circle(Vector2(190, 82), 9, Color("#1a1a1a"), false, 0.8, true)
		draw_string(Pub.font("hd/nunito-800"), Vector2(183, 86), "2×", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#1a1a1a"))

	func _farmer_wind(lo: float, hi: float) -> void:
		ground(lo, hi, pal[3])
		# wind face in a cloud
		var w := Vector2(22, 24)
		for b in [[Vector2(-4, -6), 11.0], [Vector2(8, -10), 10.0], [Vector2(-8, 8), 10.0], [Vector2(4, 10), 9.0], [Vector2(0, 0), 13.0]]:
			paper(circ(w + b[0], b[1]), WHITE, false)
		paper(circ(w + Vector2(8, 0), 9.0), WHITE, false)
		dot(w + Vector2(6, -4), 1.2, INK)
		paper(ell(w + Vector2(15, 2), 3.0, 2.2), INK, false)
		for i in 4:
			draw_line(w + Vector2(20, -2 + i * 3), w + Vector2(60 + i * 8, -6 + i * 5), line_col(), 0.8, true)
		# a weathervane rooster
		paper(stroke([Vector2(186, 92), Vector2(186, 40)], 1.6), INK)
		paper(PackedVector2Array([Vector2(178, 36), Vector2(184, 28), Vector2(192, 30), Vector2(196, 36), Vector2(188, 40)]), INK)
		# the farmer, holding his hat on; cards blow past
		push(Vector2(120, GROUND), 1.1, true)
		person({"top": Color("#7a5a3a"), "legs": DENIM, "hat": "straw", "hair": "bald",
			"hands": [Vector2(2, -60), Vector2(-14, -30)], "feet": [Vector2(6, 0), Vector2(-8, 0)], "lean": 4.0})
		pop()
		card_piece(Vector2(80, 36), -0.5, true, pal[0])
		card_piece(Vector2(160, 30), 0.6, false, pal[0])
		card_piece(Vector2(150, 62), -0.3, true, pal[0])

	func _cheap_shot(lo: float, hi: float) -> void:
		sun(Vector2(110, 18), 10)
		ground(lo, hi, pal[3])
		push(Vector2(176, GROUND), 0.95, true)
		dummy(false)
		pop()
		# three pebbles on a dotted arc, one already hitting
		var arc := arc_path(Vector2(128, 96), 60, -2.6, -1.05, 14)
		for i in range(1, arc.size(), 2):
			dot(arc[i], 0.9, Color(INK, 0.4))
		for p in [arc[5], arc[9], arc[13]]:
			paper(circ(p, 2.6), STONE)
		paper(star(Vector2(166, 62), 7, 8, 0.45), MUSTARD)
		push(Vector2(64, GROUND), 1.05)
		pip("peek", Vector2(14, -42), Vector2(6, -40), {"eyes": "squint"})
		# slingshot
		var y := Vector2(14, -42)
		paper(stroke([y + Vector2(0, 8), y], 2.6), KRAFT_D)
		paper(stroke([y, y + Vector2(-4, -8)], 2.2), KRAFT_D)
		paper(stroke([y, y + Vector2(5, -8)], 2.2), KRAFT_D)
		ink(y + Vector2(-4, -8), Vector2(2, -38), 0.9)
		ink(y + Vector2(5, -8), Vector2(2, -38), 0.9)
		pop()
		# Pip hides behind a bush
		for b in [[Vector2(48, 86), 12.0], [Vector2(66, 80), 14.0], [Vector2(86, 86), 11.0], [Vector2(70, 92), 13.0]]:
			paper(circ(b[0], b[1]), LEAF)
		for b in [[Vector2(58, 80), 2.0], [Vector2(78, 77), 2.0], [Vector2(70, 88), 1.6]]:
			dot(b[0], b[1], LEAF_D)

	func _bulwark(lo: float, hi: float) -> void:
		ground(lo, hi, pal[3])
		push(Vector2(108, GROUND - 26), 1.0)
		pip("peek", Vector2(10, -16), Vector2(-6, -16))
		pop()
		# a wall of playing cards laid like bricks
		for row in 3:
			var y := GROUND - 8.0 - row * 13.0
			var x0 := 70.0 + (8.0 if row % 2 == 1 else 0.0)
			for i in 6 - row % 2:
				var c := Vector2(x0 + i * 16.0, y)
				paper(rect(c, 16, 13), WHITE)
				paper(rect(c, 12.5, 9.5), pal[0], false, 0.3)
				paper(rect(c, 4, 4, PI * 0.25), WHITE, false, 0.2)
		# Pip's paws over the top of the wall
		paper(circ(Vector2(104, 52), 3.4), CAT)
		paper(circ(Vector2(122, 52), 3.4), CAT)
		# at the end of the turn a few cards slip off
		card_piece(Vector2(172, 36), 0.7, true, pal[0])
		card_piece(Vector2(186, 60), 1.3, true, pal[0])
		for i in 3:
			ink(Vector2(162 + i * 5, 22 - i * 2), Vector2(164 + i * 5, 28 - i * 2), 1.1, 0.5)

	func _opening(lo: float, hi: float) -> void:
		# a checkerboard floor
		ground(lo, hi, CREAM, GROUND - 4)
		for i in 16:
			var x := -12.0 + i * 16.0
			if i % 2 == 0:
				paper(PackedVector2Array([Vector2(x, GROUND - 4), Vector2(x + 16, GROUND - 4), Vector2(x + 18, 120), Vector2(x + 2, 120)]), pal[1].darkened(0.08), false, 0.4)
		# the pawn, nudged one square forward
		var c := Vector2(136, GROUND - 4)
		paper(ell(c + Vector2(0, -3), 17, 5), KRAFT_D)
		paper(PackedVector2Array([c + Vector2(-12, -4), c + Vector2(12, -4), c + Vector2(6, -30), c + Vector2(-6, -30)]), KRAFT)
		paper(ell(c + Vector2(0, -30), 10, 3.4), KRAFT_D)
		paper(circ(c + Vector2(0, -42), 9.5), KRAFT)
		paper(swoosh(c + Vector2(0, -42), 7, -2.6, -1.2, 2.4), Color(WHITE, 0.7), false)
		for i in 3:
			ink(Vector2(108 - i * 6, 66 + i * 7), Vector2(100 - i * 6, 66 + i * 7), 1.3, 0.5)
		push(Vector2(96, GROUND - 4), 1.0)
		pip("push", Vector2(22, -24), Vector2(20, -16))
		pop()
		paper(star(Vector2(166, 30), 6, 4, 0.35), MUSTARD)
		paper(star(Vector2(178, 46), 4, 4, 0.35), WHITE)
		paper(star(Vector2(60, 26), 4, 4, 0.35), MUSTARD)
