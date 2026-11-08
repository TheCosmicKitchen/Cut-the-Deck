## Card illustrations: small cut-paper collage scenes, one per card, starring Pip,
## the tangerine paper cat. Every shape is a piece of paper with a rough-cut edge
## and a soft shadow. Scenes are drawn once at 2x and cached as textures.
##
## A card shows card.art if set (so art can be swapped), else its base card's scene.
class_name Illo
extends RefCounted

const DESIGN := Vector2(212, 112)   # scenes are authored in this space
const DESIGN_P := Vector2(120, 178) # full-card portrait scenes ("p_" names)
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
## full-card portrait scenes for each publication's cards
const PUB_FULL := ["p_wrecking", "p_hero", "p_inkwell", "p_zine", "p_flatpack", "p_almanac"]

## each publication has its own cast; these scenes are drawn for it
const PUB_SCENES := {
	"reckless_swing": "wrecking", "jab": "hero_jab", "blood_price": "blood_price",
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
	canvas.portrait = scene.begins_with("p_")
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
	var portrait := false
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
		var k: float = size.x / DESIGN_P.x if portrait else size.y / DESIGN.y
		var off := Vector2.ZERO if portrait else Vector2((size.x - DESIGN.x * k) * 0.5, 0.0)
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
		if portrait:
			return
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
		if portrait:
			return
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
		if portrait:
			return
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

	# ---------- shaded figures ----------

	## A shaded body part, lit from the upper left: a dark base with a lit shape
	## inset toward the light. Each style prints the two layers its own way.
	func part(pts: PackedVector2Array, col: Color, inset := 1.3) -> void:
		if pts.size() < 3:
			return
		if style == "paper":
			paper(pts, col)
			return
		if style == "line":
			draw_colored_polygon(pts, Color.WHITE)
			var loop := pts.duplicate()
			loop.append(pts[0])
			draw_polyline(loop, Color("#1a1a1a"), 0.75, true)
			return
		var dark: Color
		var lit: Color
		var off := Vector2(-0.9, -0.9) * inset
		match style:
			"ink":
				dark = col.darkened(0.38)
				lit = col
			"photo":
				dark = tone(col.darkened(0.45))
				lit = tone(col.lightened(0.12))
			"silhouette":
				# rim light from the moon on the right; the rest falls into shadow
				dark = Color("#ffb04a") if col != PULP_RED else Color("#ff6a4a")
				lit = Color("#1a0620") if col != PULP_RED else PULP_RED.darkened(0.25)
				off = Vector2(-1.3, 0.3) * inset
			"xerox":
				dark = Color(0.07, 0.07, 0.07)
				lit = tone(col) if col.get_luminance() >= 0.6 else Color(0.07, 0.07, 0.07)
			"woodcut":
				dark = WOOD_INK
				lit = WOOD_PAPER if col.get_luminance() >= 0.45 else WOOD_INK
		if style == "woodcut" and col.get_luminance() >= 0.45:
			# engraved: paper, with the shadow side cut in fine parallel lines
			draw_colored_polygon(pts, WOOD_PAPER)
			hatch(pts, 1.5, 0.8)
			dark = Color(0, 0, 0, 0)
		else:
			draw_colored_polygon(pts, dark)
		var inner := Geometry2D.offset_polygon(pts, -inset * 0.9, Geometry2D.JOIN_ROUND)
		if not inner.is_empty():
			var best: PackedVector2Array = inner[0]
			for q in inner:
				if q.size() > best.size():
					best = q
			var moved := PackedVector2Array()
			for v in best:
				moved.append(v + off)
			var clipped := Geometry2D.intersect_polygons(moved, pts)
			for c in clipped:
				draw_colored_polygon(c, lit)
				if style == "woodcut" and col.get_luminance() >= 0.45 and col.get_luminance() < 0.75:
					hatch(c, 2.6, -0.7)
		if style in ["ink", "woodcut", "xerox"]:
			var loop2 := pts.duplicate()
			loop2.append(pts[0])
			draw_polyline(loop2, line_col(), {"ink": 1.3, "woodcut": 0.9, "xerox": 0.8}[style], true)

	## parallel engraving lines clipped to a polygon
	func hatch(poly: PackedVector2Array, spacing: float, ang: float, w := 0.5) -> void:
		var r := Rect2(poly[0], Vector2.ZERO)
		for v in poly:
			r = r.expand(v)
		var c := r.get_center()
		var diag := r.size.length() * 0.5 + 2.0
		var d := Vector2(cos(ang), sin(ang))
		var n := d.orthogonal()
		var t := -diag
		while t < diag:
			var a := c + n * t - d * diag
			var b := c + n * t + d * diag
			for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly):
				draw_polyline(seg, WOOD_INK, w, true)
			t += spacing

	func text(p: Vector2, t: String, fname: String, size: int, col: Color, rot := 0.0, outline := 0, ocol := Color.BLACK) -> void:
		var f := Pub.font(fname)
		draw_set_transform_matrix(_base * Transform2D(rot, p))
		if outline > 0:
			draw_string_outline(f, Vector2.ZERO, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, ocol)
		draw_string(f, Vector2.ZERO, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		pop()

	## a limb through joints, with a width at each joint
	func limb(js: Array, ws: Array) -> PackedVector2Array:
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var n := js.size()
		for i in n:
			var p: Vector2 = js[i]
			var d: Vector2 = (js[mini(i + 1, n - 1)] - js[maxi(i - 1, 0)]).normalized()
			var w: float = ws[i] * 0.5
			left.append(p + d.orthogonal() * w)
			right.append(p - d.orthogonal() * w)
		# round the ends
		var end_c: Vector2 = js[n - 1]
		var end_d: Vector2 = (js[n - 1] - js[n - 2]).normalized()
		left.append(end_c + end_d * ws[n - 1] * 0.45)
		right.reverse()
		left.append_array(right)
		var st_c: Vector2 = js[0]
		var st_d: Vector2 = (js[0] - js[1]).normalized()
		left.append(st_c + st_d * ws[0] * 0.4)
		return left

	## A figure from joint positions (feet near the origin, ~74 units tall, facing right).
	## j: head, sh (front shoulder), sh_b, el, el_b, ha, ha_b, hip, hip_b, kn, kn_b, ft, ft_b
	## look: skin, top, legs, boots, build (shoulder width), hair, extras
	func figure(j: Dictionary, look: Dictionary) -> void:
		var skin: Color = look.get("skin", SKIN)
		var top: Color = look.get("top", RED)
		var legs: Color = look.get("legs", DENIM)
		var boots: Color = look.get("boots", INK)
		var arm_col: Color = look.get("sleeves", top)
		var hand_col: Color = look.get("gloves", skin)
		var thick: float = look.get("thick", 1.0)
		var back := func(c: Color) -> Color: return c.darkened(0.2)
		if look.has("cape"):
			var c0: Vector2 = j.sh_b
			part(PackedVector2Array([j.sh_b + Vector2(-1, -2), j.sh + Vector2(1, -2), j.hip + Vector2(-8, 10), j.hip_b + Vector2(-28, 16), j.hip_b + Vector2(-22, 2)]), look.cape)
		# back arm and leg
		part(limb([j.sh_b, j.el_b, j.ha_b], [7.0 * thick, 5.6 * thick, 4.6 * thick]), back.call(arm_col))
		part(circ(j.ha_b, 3.4 * thick), back.call(hand_col))
		part(limb([j.hip_b, j.kn_b, j.ft_b + Vector2(0, -3)], [9.5 * thick, 6.8 * thick, 5.0 * thick]), back.call(legs))
		part(PackedVector2Array([j.ft_b + Vector2(-4, -6), j.ft_b + Vector2(3, -6), j.ft_b + Vector2(8, 0), j.ft_b + Vector2(-4, 0)]), back.call(boots))
		if look.has("skirt"):
			part(PackedVector2Array([j.hip_b + Vector2(-6, -4), j.hip + Vector2(6, -4), j.hip + Vector2(12, 22), j.hip_b + Vector2(-14, 22)]), look.skirt)
		# torso: shoulders, waist, hips
		var sw: float = look.get("build", 11.0)
		var mid: Vector2 = (j.sh + j.sh_b) * 0.5
		var hipm: Vector2 = (j.hip + j.hip_b) * 0.5
		var waist := mid.lerp(hipm, 0.68)
		var ax := (mid - hipm).normalized().orthogonal()
		part(PackedVector2Array([j.sh_b + ax * 2.0, mid + ax * sw * 0.2 + (mid - hipm).normalized() * 2.0, j.sh - ax * 2.0,
			waist - ax * sw * 0.55, hipm - ax * 7.0, hipm + ax * 7.0, waist + ax * sw * 0.55]), top)
		if look.has("stripes"):
			for i in 3:
				var y := mid.lerp(waist, 0.25 + i * 0.25)
				draw_line(y + ax * sw * 0.7, y - ax * sw * 0.7, tone(look.stripes), 1.6, true)
		if look.has("emblem"):
			paper(star(mid.lerp(waist, 0.35), 4.5, 5, 0.45), look.emblem, false, 0.1)
		if look.has("overalls"):
			part(PackedVector2Array([mid.lerp(waist, 0.4) + ax * 5.0, mid.lerp(waist, 0.4) - ax * 5.0, hipm - ax * 7.5, hipm + ax * 7.5]), look.overalls)
		# front leg
		if not look.has("skirt"):
			part(limb([j.hip, j.kn, j.ft + Vector2(0, -3)], [10.0 * thick, 7.0 * thick, 5.2 * thick]), legs)
		else:
			part(limb([j.hip, j.kn, j.ft + Vector2(0, -3)], [6.0, 5.0, 3.8]), skin)
		part(PackedVector2Array([j.ft + Vector2(-4, -6), j.ft + Vector2(3, -6), j.ft + Vector2(9, 0), j.ft + Vector2(-4, 0)]), boots)
		if look.has("skirt"):
			part(PackedVector2Array([hipm + ax * 9.0 + Vector2(0, -3), hipm - ax * 9.0 + Vector2(0, -3), j.hip + Vector2(14, 20), j.hip_b + Vector2(-12, 22)]), look.skirt)
		# neck and head
		var head: Vector2 = j.head
		part(limb([mid + (mid - hipm).normalized() * 1.0, head + Vector2(0, 6)], [5.0, 4.6]), skin)
		var hr: float = look.get("head", 7.2)
		var face := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			var r := hr
			# a jaw: the face juts a little forward and down
			if a > 0.2 and a < 1.6:
				r += 1.6 * sin((a - 0.2) / 1.4 * PI)
			face.append(head + Vector2(cos(a) * r * 0.92, sin(a) * r))
		part(face, skin, 1.0)
		match look.get("hair", "short"):
			"short":
				part(PackedVector2Array([head + Vector2(-hr, 1), head + Vector2(-hr + 1, -hr * 0.8), head + Vector2(0, -hr - 1.5), head + Vector2(hr * 0.8, -hr * 0.6), head + Vector2(2, -hr * 0.4), head + Vector2(-2, 0)]), look.get("hair_col", INK), 0.8)
			"long":
				part(PackedVector2Array([head + Vector2(-hr - 2, 14), head + Vector2(-hr - 2, -2), head + Vector2(0, -hr - 2), head + Vector2(hr, -hr * 0.4), head + Vector2(1, -hr * 0.5), head + Vector2(-3, 4), head + Vector2(-4, 16)]), look.get("hair_col", INK), 0.8)
			"mohawk":
				for i in 6:
					part(tri(head + Vector2(-6 + i * 2.4, -hr + 2), head + Vector2(-9 + i * 3.2, -hr - 12 + abs(i - 2.5) * 1.5), head + Vector2(-3 + i * 2.4, -hr + 1)), look.get("hair_col", INK), 0.5)
		match look.get("hat", ""):
			"helmet":
				part(PackedVector2Array([head + Vector2(-hr - 1, 1), head + Vector2(-hr, -hr * 0.7), head + Vector2(0, -hr - 2), head + Vector2(hr, -hr * 0.6), head + Vector2(hr + 6, -1), head + Vector2(hr - 1, 0)]), look.get("hat_col", INK), 1.0)
			"beanie":
				part(PackedVector2Array([head + Vector2(-hr - 1, -1), head + Vector2(-hr + 1, -hr), head + Vector2(2, -hr - 3), head + Vector2(hr, -hr * 0.4), head + Vector2(hr, -1)]), look.get("hat_col", INK), 0.8)
			"straw":
				part(ell(head + Vector2(0, -hr * 0.6), hr * 2.0, 2.6), MUSTARD, 0.6)
				part(ell(head + Vector2(0, -hr * 0.95), hr * 0.95, hr * 0.6), MUSTARD, 0.6)
		if look.has("mask"):
			part(PackedVector2Array([head + Vector2(-hr + 2, -3), head + Vector2(hr + 1, -4), head + Vector2(hr + 1, 0), head + Vector2(-hr + 2, 1)]), look.mask, 0.4)
		# face: eye, brow, mouth
		var ex := head + Vector2(hr * 0.42, -1.5)
		match look.get("face", "grit"):
			"scream":
				draw_circle(ex, 1.3, Color.WHITE if style != "silhouette" else Color("#ffe27a"), true, -1.0, true)
				part(ell(head + Vector2(hr * 0.5, 4), 1.7, 2.6), Color(0.15, 0.02, 0.05), 0.3)
			"dazed":
				ink(ex + Vector2(-1.2, -1.2), ex + Vector2(1.2, 1.2), 0.9)
				ink(ex + Vector2(1.2, -1.2), ex + Vector2(-1.2, 1.2), 0.9)
			_:
				dot(ex, 0.9)
				ink(ex + Vector2(-2.2, -2.0), ex + Vector2(1.8, -1.4), 1.0)
				ink(head + Vector2(hr * 0.35, 4.2), head + Vector2(hr * 0.85, 3.6), 0.8)
		# front arm
		part(limb([j.sh, j.el, j.ha], [7.4 * thick, 6.0 * thick, 4.8 * thick]), arm_col)
		part(circ(j.ha, look.get("fist", 3.6) * thick), hand_col, 0.8)

	# ---------- furniture, for the flat-pack manual ----------

	## an isometric box (a board or a cabinet) at base point o: w along x-axis, d along depth, h up
	func iso_box(o: Vector2, w: float, d: float, h: float, shade := true) -> void:
		var X := Vector2(0.87, 0.5)
		var Z := Vector2(-0.87, 0.5)
		var U := Vector2(0, -1)
		var a := o
		var b := o + X * w
		var c := o + X * w + Z * d
		var e := o + Z * d
		var top := [a + U * h, b + U * h, c + U * h, e + U * h]
		var line := Color("#1a1a1a")
		# visible faces: top, front-left (along Z at x=w? ) — draw the three faces facing the viewer
		var f_top := PackedVector2Array(top)
		var f_right := PackedVector2Array([b, c, c + U * h, b + U * h])
		var f_left := PackedVector2Array([e, c, c + U * h, e + U * h])
		draw_colored_polygon(f_right, Color("#e9eef4") if shade else Color.WHITE)
		draw_colored_polygon(f_left, Color.WHITE)
		draw_colored_polygon(f_top, Color("#f6f8fb"))
		for f in [f_right, f_left, f_top]:
			var loop: PackedVector2Array = f.duplicate()
			loop.append(f[0])
			draw_polyline(loop, line, 0.8, true)

	func dowel(p: Vector2, ang := -PI * 0.5, len := 7.0) -> void:
		var d := Vector2(cos(ang), sin(ang))
		draw_line(p, p + d * len, Color("#1a1a1a"), 2.6, true)
		draw_line(p, p + d * len, Color.WHITE, 1.2, true)

	func screw(p: Vector2) -> void:
		draw_circle(p, 2.0, Color.WHITE, true, -1.0, true)
		draw_circle(p, 2.0, Color("#1a1a1a"), false, 0.7, true)
		draw_line(p + Vector2(-1.2, 0), p + Vector2(1.2, 0), Color("#1a1a1a"), 0.6)
		draw_line(p + Vector2(0, 2), p + Vector2(0, 9), Color("#1a1a1a"), 0.9)
		for i in 3:
			draw_line(p + Vector2(-1, 4 + i * 2), p + Vector2(1, 5 + i * 2), Color("#1a1a1a"), 0.5)

	func callout(p: Vector2, text: String) -> void:
		draw_string(Pub.font("hd/nunito-800"), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#1a1a1a"))

	func move_arrow(a: Vector2, b: Vector2) -> void:
		draw_line(a, b, Color("#1a1a1a"), 0.8, true)
		var d := (b - a).normalized()
		draw_colored_polygon(PackedVector2Array([b, b - d * 4.0 + d.orthogonal() * 2.0, b - d * 4.0 - d.orthogonal() * 2.0]), Color("#1a1a1a"))

	func _flatpack(lo: float, hi: float) -> void:
		# Defend: a bookcase in exploded view; the top shelf drops onto its dowels
		# and the back panel slides in from the side
		var X := Vector2(0.87, 0.5)
		var U := Vector2(0, -1)
		var o := Vector2(64, 60)
		var W := 46.0
		iso_box(o, 3, 14, 52)                       # far side
		iso_box(o, W, 14, 3)                        # bottom
		iso_box(o + U * 24.0, W, 14, 2.5)           # middle shelf
		iso_box(o + X * (W - 3.0), 3, 14, 52)       # near side
		# the top, lifted, with dowels waiting below it
		var top := o + U * 70.0
		iso_box(top, W, 14, 3)
		for t in [0.15, 0.85]:
			dowel(o + X * (W * t) + U * 54.0, -PI * 0.5, 6.0)
		move_arrow(top + X * (W * 0.5) + Vector2(-6, 10), top + X * (W * 0.5) + Vector2(-6, 18))
		# back panel, sliding in from the right
		var bp := PackedVector2Array([Vector2(150, 12), Vector2(190, 35), Vector2(190, 87), Vector2(150, 64)])
		draw_colored_polygon(bp, Color("#f2f5f9"))
		var loop := bp.duplicate()
		loop.append(bp[0])
		draw_polyline(loop, Color("#1a1a1a"), 0.8, true)
		move_arrow(Vector2(146, 46), Vector2(124, 46))
		callout(Vector2(166, 54), "B")
		callout(Vector2(56, 40), "A")
		# parts callouts
		draw_circle(Vector2(24, 30), 12, Color("#1a1a1a"), false, 0.6, true)
		screw(Vector2(21, 22))
		callout(Vector2(26, 37), "8×")
		draw_circle(Vector2(24, 70), 12, Color("#1a1a1a"), false, 0.6, true)
		dowel(Vector2(20, 76), -PI * 0.5, 9.0)
		callout(Vector2(26, 77), "4×")
		draw_line(Vector2(lo, 92), Vector2(hi, 92), Color("#1a1a1a"), 0.5)

	func _slugger(lo: float, hi: float) -> void:
		# the sports page: a batter connects, catcher crouched behind, the stands beyond
		for row in 4:
			for i in 30:
				var x := lo + i * 9.0 + (row % 2) * 4.5
				dot(Vector2(x, 14 + row * 9), 2.6, Color(0.82, 0.82, 0.82))
				paper(rect(Vector2(x, 20 + row * 9), 6, 5), Color(0.78, 0.78, 0.78).lightened(((i * 7 + row) % 5) * 0.04), false, 0.1)
		draw_rect(Rect2(Vector2(lo, 50), Vector2(hi - lo, 4)), tone(Color(0.3, 0.3, 0.3)))
		ground(lo, hi, Color(0.55, 0.55, 0.55))
		# catcher, crouched
		figure({"head": Vector2(34, 60), "sh": Vector2(38, 70), "sh_b": Vector2(30, 70), "el": Vector2(46, 76), "el_b": Vector2(24, 78),
			"ha": Vector2(52, 72), "ha_b": Vector2(28, 84), "hip": Vector2(34, 82), "hip_b": Vector2(28, 82), "kn": Vector2(44, 84), "kn_b": Vector2(20, 86),
			"ft": Vector2(38, 92), "ft_b": Vector2(24, 92)}, {"top": Color(0.4, 0.4, 0.42), "legs": Color(0.4, 0.4, 0.42), "hat": "helmet", "hair": "", "head": 6.2, "fist": 5.0})
		# the batter, follow-through
		figure({"head": Vector2(104, 26), "sh": Vector2(106, 38), "sh_b": Vector2(96, 38), "el": Vector2(116, 34), "el_b": Vector2(108, 30),
			"ha": Vector2(118, 26), "ha_b": Vector2(114, 25), "hip": Vector2(102, 62), "hip_b": Vector2(96, 62), "kn": Vector2(114, 76), "kn_b": Vector2(88, 76),
			"ft": Vector2(120, 92), "ft_b": Vector2(82, 92)}, {"top": Color(0.88, 0.88, 0.9), "legs": Color(0.88, 0.88, 0.9), "stripes": Color(0.35, 0.35, 0.4),
			"hat": "helmet", "hat_col": Color(0.15, 0.15, 0.18), "hair": "", "boots": INK, "build": 13.0})
		part(limb([Vector2(116, 26), Vector2(98, 14), Vector2(80, 6)], [3.0, 4.2, 5.4]), Color(0.25, 0.25, 0.25))
		for i in 3:
			draw_arc(Vector2(110, 32), 26.0 + i * 5.0, PI * 0.85, PI * 1.45, 12, Color(1, 1, 1, 0.4), 1.2, true)
		part(circ(Vector2(176, 22), 3.4), Color(0.95, 0.95, 0.95), 0.6)
		for i in 4:
			draw_line(Vector2(158 - i * 5, 30 + i * 2), Vector2(168 - i * 5, 26 + i * 2), Color(1, 1, 1, 0.5), 1.0, true)

	func _wrecking(lo: float, hi: float) -> void:
		# front page: a wrecking ball swings wide into the wrong building
		# the building, windows in rows, a corner smashed open
		part(PackedVector2Array([Vector2(118, 14), Vector2(204, 14), Vector2(204, 92), Vector2(118, 92)]), Color(0.62, 0.6, 0.58), 1.5)
		for row in 6:
			for col in 6:
				var wp := Vector2(126 + col * 13, 20 + row * 12)
				if wp.x < 140 and wp.y > 30 and wp.y < 70:
					continue
				draw_rect(Rect2(wp, Vector2(7, 7)), tone(Color(0.22, 0.22, 0.25)))
		part(PackedVector2Array([Vector2(118, 30), Vector2(142, 34), Vector2(146, 52), Vector2(138, 74), Vector2(118, 70)]), Color(0.12, 0.12, 0.14), 1.0)
		# flying bricks and dust
		_rng.seed = 41
		for i in 12:
			var bp := Vector2(_rng.randf_range(96, 132), _rng.randf_range(22, 74))
			part(rect(bp, 5, 3, _rng.randf_range(-1, 1)), Color(0.5, 0.48, 0.46), 0.6)
		for d in [[Vector2(122, 70), 14.0], [Vector2(104, 78), 12.0], [Vector2(136, 82), 11.0], [Vector2(114, 86), 10.0]]:
			draw_circle(d[0], d[1], Color(0.86, 0.86, 0.86, 0.85), true, -1.0, true)
		# the crane: lattice tower and boom
		var tw := [Vector2(14, 92), Vector2(14, 12)]
		draw_line(Vector2(10, 92), Vector2(10, 14), tone(Color(0.25, 0.25, 0.25)), 1.4, true)
		draw_line(Vector2(20, 92), Vector2(20, 14), tone(Color(0.25, 0.25, 0.25)), 1.4, true)
		for i in 10:
			var y := 92.0 - i * 8.0
			draw_line(Vector2(10, y), Vector2(20, y - 8), tone(Color(0.3, 0.3, 0.3)), 0.8, true)
		var tip := Vector2(98, 4)
		draw_line(Vector2(14, 16), tip, tone(Color(0.25, 0.25, 0.25)), 2.2, true)
		draw_line(Vector2(14, 22), tip + Vector2(0, 3), tone(Color(0.3, 0.3, 0.3)), 0.8, true)
		# cable and ball, mid-swing
		var ball := Vector2(110, 48)
		draw_line(tip, ball, tone(Color(0.15, 0.15, 0.15)), 1.0, true)
		part(circ(ball, 11), Color(0.2, 0.2, 0.22), 2.0)
		for i in 3:
			draw_arc(tip, tip.distance_to(ball) + 2.0, 1.1 + i * 0.06, 1.5, 10, Color(1, 1, 1, 0.35), 1.0, true)
		# onlookers behind the police tape
		for i in 16:
			var x := lo + 6.0 + i * 8.5
			part(ell(Vector2(x, 82), 3.2, 3.6), Color(0.3, 0.3, 0.3), 0.6)
			part(PackedVector2Array([Vector2(x - 4.5, 92), Vector2(x - 3.5, 86), Vector2(x + 3.5, 86), Vector2(x + 4.5, 92)]), Color(0.18 + (i % 3) * 0.12, 0.18, 0.2), 0.6)
		for i in 30:
			var x := lo + i * 8.0
			draw_line(Vector2(x, 80), Vector2(x + 4, 80), tone(Color(0.15, 0.15, 0.15)), 1.6)
			draw_line(Vector2(x + 4, 80), Vector2(x + 8, 80), tone(Color(0.9, 0.9, 0.9)), 1.6)

	func _panel(r: Rect2, col: Color) -> void:
		draw_rect(r, col)

	func _hero_jab(lo: float, hi: float) -> void:
		# a three-panel strip: the wind-up, the hit, the aftermath
		var p1 := Rect2(2, 3, 66, 106)
		var p2 := Rect2(72, 3, 70, 106)
		var p3 := Rect2(146, 3, 64, 106)
		_panel(p1, Color("#8fd0ff"))
		_panel(p2, Color("#ffe14d"))
		_panel(p3, Color("#d7b8ff"))
		# 1: the hero, fist pulled back
		figure({"head": Vector2(30, 36), "sh": Vector2(34, 48), "sh_b": Vector2(22, 48), "el": Vector2(46, 56), "el_b": Vector2(12, 58),
			"ha": Vector2(52, 50), "ha_b": Vector2(8, 46), "hip": Vector2(32, 78), "hip_b": Vector2(24, 78), "kn": Vector2(38, 94), "kn_b": Vector2(18, 94),
			"ft": Vector2(40, 112), "ft_b": Vector2(14, 112)}, {"top": Color("#2f6fe4"), "legs": Color("#2f6fe4"), "cape": RED, "emblem": MUSTARD, "mask": INK,
			"gloves": RED, "boots": RED, "build": 17.0, "thick": 1.2, "fist": 4.6})
		# speech balloon
		var bal := ell(Vector2(35, 15), 30, 10)
		draw_colored_polygon(PackedVector2Array([Vector2(28, 22), Vector2(30, 30), Vector2(36, 23)]), Color.WHITE)
		draw_polyline(PackedVector2Array([Vector2(28, 23), Vector2(30, 30), Vector2(36, 24)]), INK, 1.0, true)
		draw_colored_polygon(bal, Color.WHITE)
		draw_polyline(bal + PackedVector2Array([bal[0]]), INK, 1.0, true)
		text(Vector2(13, 18.5), "TAKE THAT!", "bangers", 9, INK)
		# 2: the hit
		var f := Vector2(108, 56)
		var p2poly := PackedVector2Array([p2.position, Vector2(p2.end.x, p2.position.y), p2.end, Vector2(p2.position.x, p2.end.y)])
		for i in 20:
			var a0 := i * TAU / 20.0
			var wedge := PackedVector2Array([f, f + Vector2(cos(a0), sin(a0)) * 90.0, f + Vector2(cos(a0 + 0.16), sin(a0 + 0.16)) * 90.0])
			for q in Geometry2D.intersect_polygons(wedge, p2poly):
				draw_colored_polygon(q, Color("#ff8a2e"))
		paper(star(f, 26, 12, 0.55), WHITE, false, 0.2)
		paper(star(f, 26, 12, 0.55), Color(0, 0, 0, 0), false)
		draw_polyline(star(f, 26, 12, 0.55) + PackedVector2Array([star(f, 26, 12, 0.55)[0]]), INK, 1.2, true)
		part(ell(Vector2(88, 66), 10, 8), RED, 1.2)
		part(rect(Vector2(76, 70), 10, 9), Color("#2f6fe4"), 1.0)
		for i in 3:
			draw_line(Vector2(74, 56 + i * 6), Vector2(78 - 6, 56 + i * 6), INK, 1.2, true)
		text(Vector2(80, 44), "KRAKK!", "bangers", 19, Color("#ffe14d"), -0.25, 4, INK)
		# 3: the goon, sat down hard, seeing stars
		figure({"head": Vector2(178, 64), "sh": Vector2(182, 74), "sh_b": Vector2(172, 74), "el": Vector2(192, 86), "el_b": Vector2(162, 86),
			"ha": Vector2(196, 96), "ha_b": Vector2(158, 96), "hip": Vector2(176, 96), "hip_b": Vector2(170, 96), "kn": Vector2(192, 92), "kn_b": Vector2(160, 94),
			"ft": Vector2(204, 106), "ft_b": Vector2(152, 106)}, {"top": Color("#f4f4f4"), "stripes": INK, "legs": Color("#6b4a2e"), "hair": "short", "face": "dazed", "build": 12.0})
		for i in 4:
			var a := i * TAU / 4.0
			paper(star(Vector2(178, 50) + Vector2(cos(a) * 14.0, sin(a) * 4.0), 3.4, 5, 0.45), MUSTARD, false, 0.1)
		part(PackedVector2Array([Vector2(194, 22), Vector2(200, 14), Vector2(208, 18), Vector2(204, 26)]), INK, 0.6)
		# gutters and panel borders, drawn last so nothing spills
		for g in [Rect2(-60, 0, 62, 112), Rect2(68, 0, 4, 112), Rect2(142, 0, 4, 112), Rect2(210, 0, 60, 112), Rect2(-60, -10, 340, 13), Rect2(-60, 109, 340, 10)]:
			draw_rect(g, Color.WHITE)
		for r in [p1, p2, p3]:
			draw_rect(r, INK, false, 1.6)

	func _blood_price(lo: float, hi: float) -> void:
		# THE INK THAT CRAWLED: tentacles of ink pour from a giant inkwell
		var w := Vector2(160, 92)
		part(PackedVector2Array([w + Vector2(-30, 0), w + Vector2(-34, -30), w + Vector2(-18, -40), w + Vector2(-12, -54), w + Vector2(12, -54), w + Vector2(18, -40), w + Vector2(34, -30), w + Vector2(30, 0)]), INK, 2.0)
		part(rect(w + Vector2(0, -58), 30, 8), INK, 1.0)
		# label on the bottle, glowing in the moonlight
		part(rect(w + Vector2(0, -20), 34, 15), Color("#e8d29a"), 0.8)
		text(w + Vector2(-12, -16), "INK", "anton", 11, Color("#2a0a18"))
		# tentacles rising and reaching
		var tents := [
			[w + Vector2(-6, -60), w + Vector2(-20, -84), w + Vector2(-50, -92), w + Vector2(-80, -76), w + Vector2(-92, -60)],
			[w + Vector2(6, -60), w + Vector2(14, -86), w + Vector2(36, -100), w + Vector2(44, -84)],
			[w + Vector2(-30, -10), w + Vector2(-56, -20), w + Vector2(-76, -8), w + Vector2(-86, 0)],
		]
		for t in tents:
			var ws := []
			for i in t.size():
				ws.append(lerpf(15.0, 3.0, float(i) / (t.size() - 1)))
			part(limb(t, ws), INK, 2.0)
			for i in range(1, t.size() - 1):
				dot(t[i] + Vector2(0, 2), 1.0)
		# the heroine on the rocks, arm up against it
		part(PackedVector2Array([Vector2(lo - 4, 96), Vector2(20, 86), Vector2(70, 88), Vector2(96, 96), Vector2(96, 120), Vector2(lo - 4, 120)]), INK, 1.5)
		figure({"head": Vector2(46, 30), "sh": Vector2(50, 40), "sh_b": Vector2(40, 40), "el": Vector2(60, 30), "el_b": Vector2(30, 48),
			"ha": Vector2(58, 20), "ha_b": Vector2(22, 52), "hip": Vector2(44, 62), "hip_b": Vector2(38, 62), "kn": Vector2(48, 76), "kn_b": Vector2(32, 76),
			"ft": Vector2(54, 88), "ft_b": Vector2(26, 88)}, {"top": PULP_RED, "skirt": PULP_RED, "legs": SKIN, "hair": "long", "hair_col": Color("#3a1a0a"),
			"face": "scream", "build": 9.0, "thick": 0.85, "sleeves": SKIN})

	func _punk(lo: float, hi: float) -> void:
		# a cut-and-paste page: typed lines, a photocopied photo taped in, marker scrawl
		for i in 12:
			var y := 8.0 + i * 8.0
			for k in 8:
				var x := lo + 4.0 + k * 30.0 + (i * 13 % 9)
				draw_line(Vector2(x, y), Vector2(x + 20 + (k * 7 + i) % 8, y), Color(0.07, 0.07, 0.07, 0.25), 1.4)
		# the riso pink block, off-register behind the photo
		draw_colored_polygon(_rough(PackedVector2Array([Vector2(104, 8), Vector2(196, 14), Vector2(192, 98), Vector2(100, 92)]), 1.0), RISO)
		# the photo: a black-and-white snap of a punk mid-leap, white border
		draw_set_transform_matrix(_base * Transform2D(0.07, Vector2(144, 52)))
		var ph := Rect2(-38, -42, 76, 84)
		draw_rect(ph.grow(3), Color(0.96, 0.955, 0.945))
		draw_rect(ph, Color(0.96, 0.955, 0.945))
		draw_rect(ph.grow(3), Color(0.07, 0.07, 0.07), false, 0.6)
		pop()
		push(Vector2(144, 52), 1.0, false, 0.07)
		figure({"head": Vector2(0, -26), "sh": Vector2(4, -16), "sh_b": Vector2(-6, -16), "el": Vector2(10, -30), "el_b": Vector2(-12, -30),
			"ha": Vector2(6, -40), "ha_b": Vector2(-6, -40), "hip": Vector2(0, 8), "hip_b": Vector2(-6, 8), "kn": Vector2(16, 14), "kn_b": Vector2(-18, 22),
			"ft": Vector2(22, 30), "ft_b": Vector2(-28, 32)}, {"top": INK, "sleeves": INK, "legs": Color(0.9, 0.9, 0.9), "hair": "mohawk", "boots": INK, "build": 12.0, "thick": 0.95})
		part(limb([Vector2(2, -40), Vector2(-20, -46)], [2.6, 2.6]), INK, 0.4)
		part(PackedVector2Array([Vector2(-20, -46), Vector2(-30, -52), Vector2(-38, -46), Vector2(-34, -38), Vector2(-38, -30), Vector2(-28, -28), Vector2(-22, -36)]), WHITE, 1.0)
		pop()
		# tape on two corners
		for t in [[Vector2(112, 12), 0.6], [Vector2(178, 92), 0.5]]:
			draw_set_transform_matrix(_base * Transform2D(t[1], t[0]))
			draw_rect(Rect2(-10, -4, 20, 8), Color(0.85, 0.85, 0.8, 0.55))
			pop()
		# the scrawl
		text(Vector2(6, 46), "ALL", "marker", 24, Color(0.07, 0.07, 0.07), -0.18)
		text(Vector2(14, 74), "IN!!", "marker", 26, Color(0.07, 0.07, 0.07), -0.12)
		draw_polyline(PackedVector2Array([Vector2(10, 84), Vector2(40, 80), Vector2(70, 78), Vector2(84, 80)]), Color(0.07, 0.07, 0.07), 1.6, true)
		draw_polyline(PackedVector2Array([Vector2(70, 26), Vector2(84, 30), Vector2(98, 40)]), Color(0.07, 0.07, 0.07), 1.2, true)
		draw_colored_polygon(PackedVector2Array([Vector2(98, 40), Vector2(92, 40), Vector2(97, 34)]), Color(0.07, 0.07, 0.07))
		# a safety pin and a doodled star
		draw_line(Vector2(64, 96), Vector2(90, 90), Color(0.07, 0.07, 0.07), 1.0, true)
		draw_line(Vector2(64, 99), Vector2(90, 93), Color(0.07, 0.07, 0.07), 1.0, true)
		draw_arc(Vector2(63, 97.5), 2.0, PI * 0.5, PI * 1.5, 6, Color(0.07, 0.07, 0.07), 1.0, true)
		draw_circle(Vector2(91, 91.5), 2.2, Color(0.07, 0.07, 0.07), false, 1.0, true)
		draw_polyline(star(Vector2(58, 14), 7, 5, 0.42) + PackedVector2Array([star(Vector2(58, 14), 7, 5, 0.42)[0]]), Color(0.07, 0.07, 0.07), 1.0, true)

	func _farmer_wind(lo: float, hi: float) -> void:
		# an almanac roundel: a woodcut of the wind and a farmer, beside the month's table
		var c := Vector2(54, 56)
		var R := 50.0
		hatch(PackedVector2Array([Vector2(0, 66), Vector2(110, 66), Vector2(110, 110), Vector2(0, 110)]), 2.2, 0.0, 0.35)
		part(ell(Vector2(40, 100), 60, 30), Color("#d8c49a"), 1.4)
		part(ell(Vector2(96, 104), 50, 26), Color("#cbb68a"), 1.4)
		# wind face
		var w := Vector2(20, 30)
		for b in [[Vector2(-4, -6), 10.0], [Vector2(6, -10), 9.0], [Vector2(-8, 6), 9.0], [Vector2(3, 9), 8.0], [Vector2(0, 0), 12.0]]:
			part(circ(w + b[0], b[1]), WHITE, 1.4)
		part(circ(w + Vector2(7, 0), 8.0), WHITE, 1.2)
		dot(w + Vector2(5, -3), 1.1, INK)
		part(ell(w + Vector2(13, 2), 2.6, 2.0), INK, 0.4)
		for i in 4:
			draw_line(w + Vector2(17, -2 + i * 3), w + Vector2(48 + i * 7, -6 + i * 5), WOOD_INK, 0.7, true)
		# the farmer leans into it
		push(Vector2(-26, 8), 0.82)
		figure({"head": Vector2(104, 34), "sh": Vector2(102, 46), "sh_b": Vector2(112, 46), "el": Vector2(94, 36), "el_b": Vector2(120, 58),
			"ha": Vector2(100, 26), "ha_b": Vector2(122, 68), "hip": Vector2(108, 70), "hip_b": Vector2(114, 70), "kn": Vector2(100, 84), "kn_b": Vector2(120, 84),
			"ft": Vector2(94, 98), "ft_b": Vector2(126, 98)}, {"top": Color("#e9e2cf"), "overalls": DENIM, "legs": DENIM, "hat": "straw", "hair": "",
			"boots": Color("#3a2414"), "build": 12.0})
		pop()
		card_piece(Vector2(76, 24), -0.5, true, pal[0])
		card_piece(Vector2(92, 46), 0.6, false, pal[0])
		# mask everything outside the roundel, then its double ring and ornaments
		draw_arc(c, R + 40.0, 0, TAU, 72, WOOD_PAPER, 80.0, true)
		draw_arc(c, R, 0, TAU, 72, WOOD_INK, 1.6, true)
		draw_arc(c, R + 3.0, 0, TAU, 72, WOOD_INK, 0.7, true)
		for i in 8:
			var a := i * TAU / 8.0
			var p := c + Vector2(cos(a), sin(a)) * (R + 1.5)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -2.5), p + Vector2(2.5, 0), p + Vector2(0, 2.5), p + Vector2(-2.5, 0)]), WOOD_INK)
		# the month's table
		var tx := 116.0
		text(Vector2(tx, 16), "NOVEMBER", "fell-sc", 11, WOOD_INK)
		draw_line(Vector2(tx, 20), Vector2(206, 20), WOOD_INK, 0.8)
		draw_line(Vector2(tx, 22), Vector2(206, 22), WOOD_INK, 0.4)
		var rows := [["Moon", "waxing"], ["Wind", "brisk, W."], ["Sky", "fair, cold"], ["Sow", "winter oats"], ["Mind", "loose cards"]]
		for i in rows.size():
			var y := 34.0 + i * 13.0
			text(Vector2(tx, y), rows[i][0], "fell-i", 9, WOOD_INK)
			for k in 8:
				draw_circle(Vector2(tx + 26 + k * 3.0, y - 2), 0.4, WOOD_INK)
			text(Vector2(tx + 52, y), rows[i][1], "fell", 9, WOOD_INK)
		# a little moon
		draw_circle(Vector2(196, 96), 7, WOOD_PAPER, true, -1.0, true)
		draw_arc(Vector2(196, 96), 7, 0, TAU, 24, WOOD_INK, 0.8, true)
		hatch(circ(Vector2(199, 96), 6.4), 1.2, 0.6, 0.45)

	# ---------- full-card portrait scenes (120 x 178; text sits on the lower part) ----------

	func _p_wrecking(lo: float, hi: float) -> void:
		# the street below, where the text will sit
		draw_rect(Rect2(Vector2(0, 132), Vector2(120, 50)), tone(Color(0.32, 0.32, 0.34)))
		# a tall building, corner smashed open
		part(PackedVector2Array([Vector2(66, 30), Vector2(124, 30), Vector2(124, 134), Vector2(66, 134)]), Color(0.62, 0.6, 0.58), 1.5)
		for row in 9:
			for col in 4:
				var wp := Vector2(72 + col * 12, 36 + row * 11)
				if wp.x < 86 and wp.y > 46 and wp.y < 96:
					continue
				draw_rect(Rect2(wp, Vector2(6, 6)), tone(Color(0.2, 0.2, 0.24)))
		part(PackedVector2Array([Vector2(66, 46), Vector2(86, 52), Vector2(92, 72), Vector2(84, 96), Vector2(66, 92)]), Color(0.1, 0.1, 0.12), 1.0)
		_rng.seed = 41
		for i in 14:
			var bp := Vector2(_rng.randf_range(40, 80), _rng.randf_range(40, 100))
			part(rect(bp, 5, 3, _rng.randf_range(-1, 1)), Color(0.5, 0.48, 0.46), 0.6)
		for d in [[Vector2(70, 98), 12.0], [Vector2(54, 106), 10.0], [Vector2(84, 110), 10.0], [Vector2(62, 116), 9.0]]:
			draw_circle(d[0], d[1], Color(0.86, 0.86, 0.86, 0.85), true, -1.0, true)
		# the crane
		draw_line(Vector2(6, 178), Vector2(6, 22), tone(Color(0.25, 0.25, 0.25)), 1.4, true)
		draw_line(Vector2(15, 178), Vector2(15, 22), tone(Color(0.25, 0.25, 0.25)), 1.4, true)
		for i in 20:
			var y := 178.0 - i * 8.0
			draw_line(Vector2(6, y), Vector2(15, y - 8), tone(Color(0.3, 0.3, 0.3)), 0.8, true)
		var tip := Vector2(76, 10)
		draw_line(Vector2(10, 24), tip, tone(Color(0.22, 0.22, 0.22)), 2.2, true)
		draw_line(Vector2(10, 30), tip + Vector2(0, 3), tone(Color(0.3, 0.3, 0.3)), 0.8, true)
		var ball := Vector2(56, 66)
		draw_line(tip, ball, tone(Color(0.15, 0.15, 0.15)), 1.0, true)
		part(circ(ball, 11), Color(0.2, 0.2, 0.22), 2.0)
		for i in 3:
			draw_arc(tip, tip.distance_to(ball) + 2.0, 1.75 + i * 0.07, 2.2, 10, Color(1, 1, 1, 0.35), 1.0, true)
		# onlookers and police tape
		for i in 16:
			var x := 4.0 + i * 8.0
			part(ell(Vector2(x, 124), 3.2, 3.6), Color(0.28, 0.28, 0.28), 0.6)
			part(PackedVector2Array([Vector2(x - 4.5, 136), Vector2(x - 3.5, 128), Vector2(x + 3.5, 128), Vector2(x + 4.5, 136)]), Color(0.18 + (i % 3) * 0.12, 0.18, 0.2), 0.6)
		for i in 16:
			var x := i * 8.0
			draw_line(Vector2(x, 121), Vector2(x + 4, 121), tone(Color(0.12, 0.12, 0.12)), 1.6)
			draw_line(Vector2(x + 4, 121), Vector2(x + 8, 121), tone(Color(0.9, 0.9, 0.9)), 1.6)

	func _p_hero(lo: float, hi: float) -> void:
		# a splash panel (under the logo) and a quiet night panel for the text
		var A := Rect2(2, 2, 116, 108)
		var B := Rect2(2, 114, 116, 62)
		var apoly := PackedVector2Array([A.position, Vector2(A.end.x, A.position.y), A.end, Vector2(A.position.x, A.end.y)])
		draw_rect(A, Color("#ffe14d"))
		var f := Vector2(82, 62)
		for i in 22:
			var a0 := i * TAU / 22.0
			var wedge := PackedVector2Array([f, f + Vector2(cos(a0), sin(a0)) * 140.0, f + Vector2(cos(a0 + 0.15), sin(a0 + 0.15)) * 140.0])
			for q in Geometry2D.intersect_polygons(wedge, apoly):
				draw_colored_polygon(q, Color("#ff8a2e"))
		# goon, knocked back
		figure({"head": Vector2(104, 52), "sh": Vector2(100, 60), "sh_b": Vector2(108, 62), "el": Vector2(94, 52), "el_b": Vector2(114, 54),
			"ha": Vector2(92, 44), "ha_b": Vector2(118, 46), "hip": Vector2(106, 82), "hip_b": Vector2(112, 80), "kn": Vector2(98, 94), "kn_b": Vector2(118, 94),
			"ft": Vector2(94, 108), "ft_b": Vector2(122, 106)}, {"top": Color("#f4f4f4"), "stripes": INK, "legs": Color("#6b4a2e"), "hat": "beanie", "hat_col": INK,
			"hair": "", "face": "dazed", "build": 12.0, "thick": 0.95})
		paper(star(f, 14, 10, 0.5), WHITE, false, 0.2)
		paper(star(f, 7, 10, 0.5), MUSTARD, false, 0.1)
		# hero, lunging in
		figure({"head": Vector2(34, 46), "sh": Vector2(40, 56), "sh_b": Vector2(28, 56), "el": Vector2(56, 60), "el_b": Vector2(18, 66),
			"ha": Vector2(74, 62), "ha_b": Vector2(22, 74), "hip": Vector2(34, 82), "hip_b": Vector2(26, 82), "kn": Vector2(48, 94), "kn_b": Vector2(16, 98),
			"ft": Vector2(56, 110), "ft_b": Vector2(6, 110)}, {"top": Color("#2f6fe4"), "legs": Color("#2f6fe4"), "cape": RED, "emblem": MUSTARD, "mask": INK,
			"gloves": RED, "boots": RED, "build": 16.0, "thick": 1.15, "fist": 4.6})
		text(Vector2(52, 98), "KRAKK!", "bangers", 17, Color("#ffe14d"), -0.18, 4, INK)
		# panel B: the city at night
		draw_rect(B, Color("#24357e"))
		for i in 9:
			var bx := B.position.x + i * 13.0
			var bh := 16.0 + ((i * 37) % 23)
			draw_rect(Rect2(bx, B.position.y + 22 - (bh - 16), 12, 60), Color("#121c4a"))
			for wy in 3:
				draw_rect(Rect2(bx + 3, B.position.y + 26 - (bh - 16) + wy * 8, 2, 3), Color("#ffe14d"))
				draw_rect(Rect2(bx + 7, B.position.y + 30 - (bh - 16) + wy * 8, 2, 3), Color("#ffe14d"))
		draw_circle(Vector2(100, B.position.y + 12), 7, Color("#fff6c0"), true, -1.0, true)
		# gutters and borders
		for g in [Rect2(-10, -10, 140, 12), Rect2(-10, 110, 140, 4), Rect2(-10, 176, 140, 10), Rect2(-10, -10, 12, 200), Rect2(118, -10, 12, 200)]:
			draw_rect(g, Color.WHITE)
		draw_rect(A, INK, false, 1.4)
		draw_rect(B, INK, false, 1.4)

	func _p_inkwell(lo: float, hi: float) -> void:
		var moon := Vector2(76, 46)
		for i in 5:
			draw_circle(moon, 28.0 + i * 7.0, Color(1.0, 0.75, 0.3, 0.08), true, -1.0, true)
		draw_circle(moon, 24, Color("#ffe6a0"), true, -1.0, true)
		draw_circle(moon + Vector2(7, -5), 5, Color(0.9, 0.7, 0.4, 0.5), true, -1.0, true)
		# the inkwell, huge, at the bottom right
		var w := Vector2(86, 150)
		part(PackedVector2Array([w + Vector2(-34, 0), w + Vector2(-38, -30), w + Vector2(-22, -48), w + Vector2(-14, -64), w + Vector2(14, -64), w + Vector2(22, -48), w + Vector2(38, -30), w + Vector2(34, 0)]), INK, 1.2)
		part(rect(w + Vector2(0, -22), 36, 16), Color("#e8d29a"), 0.6)
		text(w + Vector2(-11, -17), "INK", "anton", 11, Color("#ffd36a"))
		part(rect(w + Vector2(0, -68), 34, 9), INK, 1.0)
		# tentacles of ink, rising and reaching
		var tents := [
			[w + Vector2(-8, -70), w + Vector2(-26, -86), w + Vector2(-34, -108), w + Vector2(-22, -126), w + Vector2(-6, -124)],
			[w + Vector2(8, -70), w + Vector2(22, -92), w + Vector2(26, -118), w + Vector2(16, -136)],
			[w + Vector2(-32, -20), w + Vector2(-50, -34), w + Vector2(-54, -54), w + Vector2(-46, -64)],
		]
		for t in tents:
			var ws := []
			for i in t.size():
				ws.append(lerpf(13.0, 2.5, float(i) / (t.size() - 1)))
			part(limb(t, ws), INK, 1.1)
			for i in range(1, t.size() - 1):
				dot(t[i] + Vector2(1, 2), 1.0)
		# rocks and the heroine
		part(PackedVector2Array([Vector2(-4, 132), Vector2(16, 120), Vector2(40, 124), Vector2(52, 140), Vector2(52, 182), Vector2(-4, 182)]), INK, 1.5)
		figure({"head": Vector2(24, 66), "sh": Vector2(28, 76), "sh_b": Vector2(18, 76), "el": Vector2(36, 66), "el_b": Vector2(10, 84),
			"ha": Vector2(34, 56), "ha_b": Vector2(4, 88), "hip": Vector2(22, 98), "hip_b": Vector2(16, 98), "kn": Vector2(26, 110), "kn_b": Vector2(12, 110),
			"ft": Vector2(30, 122), "ft_b": Vector2(8, 122)}, {"top": PULP_RED, "skirt": PULP_RED, "legs": SKIN, "hair": "long", "hair_col": Color("#3a1a0a"),
			"face": "scream", "build": 9.0, "thick": 0.8, "sleeves": SKIN, "head": 6.4})

	func _p_zine(lo: float, hi: float) -> void:
		for i in 22:
			var y := 6.0 + i * 8.0
			for k in 4:
				var x := 4.0 + k * 30.0 + (i * 13 % 9)
				draw_line(Vector2(x, y), Vector2(x + 18 + (k * 7 + i) % 8, y), Color(0.07, 0.07, 0.07, 0.22), 1.3)
		draw_colored_polygon(_rough(PackedVector2Array([Vector2(48, 30), Vector2(116, 34), Vector2(114, 104), Vector2(50, 100)]), 1.0), RISO)
		# the taped-in photo
		draw_set_transform_matrix(_base * Transform2D(0.08, Vector2(82, 66)))
		var ph := Rect2(-28, -34, 56, 66)
		draw_rect(ph.grow(3), Color(0.96, 0.955, 0.945))
		draw_rect(ph.grow(3), Color(0.07, 0.07, 0.07), false, 0.6)
		pop()
		push(Vector2(82, 66), 0.78, false, 0.08)
		figure({"head": Vector2(0, -26), "sh": Vector2(4, -16), "sh_b": Vector2(-6, -16), "el": Vector2(10, -30), "el_b": Vector2(-12, -30),
			"ha": Vector2(6, -40), "ha_b": Vector2(-6, -40), "hip": Vector2(0, 8), "hip_b": Vector2(-6, 8), "kn": Vector2(16, 14), "kn_b": Vector2(-18, 22),
			"ft": Vector2(22, 30), "ft_b": Vector2(-28, 32)}, {"top": INK, "sleeves": INK, "legs": Color(0.9, 0.9, 0.9), "hair": "mohawk", "boots": INK, "build": 12.0, "thick": 0.95})
		part(limb([Vector2(2, -40), Vector2(-20, -46)], [2.6, 2.6]), INK, 0.4)
		part(PackedVector2Array([Vector2(-20, -46), Vector2(-30, -52), Vector2(-38, -46), Vector2(-34, -38), Vector2(-38, -30), Vector2(-28, -28), Vector2(-22, -36)]), WHITE, 1.0)
		pop()
		for t in [[Vector2(60, 34), 0.6], [Vector2(104, 98), 0.5]]:
			draw_set_transform_matrix(_base * Transform2D(t[1], t[0]))
			draw_rect(Rect2(-9, -3.5, 18, 7), Color(0.85, 0.85, 0.8, 0.55))
			pop()
		text(Vector2(4, 58), "ALL", "marker", 17, Color(0.07, 0.07, 0.07), -0.2)
		text(Vector2(6, 80), "IN!!", "marker", 18, Color(0.07, 0.07, 0.07), -0.14)
		draw_polyline(PackedVector2Array([Vector2(6, 88), Vector2(26, 85), Vector2(46, 86)]), Color(0.07, 0.07, 0.07), 1.4, true)
		draw_polyline(star(Vector2(20, 34), 6, 5, 0.42) + PackedVector2Array([star(Vector2(20, 34), 6, 5, 0.42)[0]]), Color(0.07, 0.07, 0.07), 1.0, true)
		draw_line(Vector2(30, 106), Vector2(52, 101), Color(0.07, 0.07, 0.07), 1.0, true)
		draw_line(Vector2(30, 109), Vector2(52, 104), Color(0.07, 0.07, 0.07), 1.0, true)
		draw_circle(Vector2(53, 102.5), 2.0, Color(0.07, 0.07, 0.07), false, 1.0, true)

	func _p_flatpack(lo: float, hi: float) -> void:
		var X := Vector2(0.87, 0.5)
		var U := Vector2(0, -1)
		var o := Vector2(14, 82)
		var W := 36.0
		iso_box(o, 3, 12, 44)
		iso_box(o, W, 12, 3)
		iso_box(o + U * 20.0, W, 12, 2.5)
		iso_box(o + X * (W - 3.0), 3, 12, 44)
		var top := o + U * 58.0
		iso_box(top, W, 12, 3)
		for t in [0.15, 0.85]:
			dowel(o + X * (W * t) + U * 46.0, -PI * 0.5, 5.0)
		move_arrow(top + X * (W * 0.5) + Vector2(-5, 8), top + X * (W * 0.5) + Vector2(-5, 15))
		var bp := PackedVector2Array([Vector2(74, 40), Vector2(96, 53), Vector2(96, 94), Vector2(74, 81)])
		draw_colored_polygon(bp, Color("#f2f5f9"))
		var loop := bp.duplicate()
		loop.append(bp[0])
		draw_polyline(loop, Color("#1a1a1a"), 0.7, true)
		move_arrow(Vector2(72, 66), Vector2(60, 66))
		callout(Vector2(83, 72), "B")
		callout(Vector2(6, 58), "A")
		draw_circle(Vector2(108, 48), 9, Color("#1a1a1a"), false, 0.6, true)
		screw(Vector2(106, 41))
		callout(Vector2(103, 64), "8×")
		draw_circle(Vector2(108, 84), 9, Color("#1a1a1a"), false, 0.6, true)
		dowel(Vector2(105, 89), -PI * 0.5, 8.0)
		callout(Vector2(103, 100), "4×")
		draw_line(Vector2(0, 92), Vector2(120, 92), Color("#1a1a1a"), 0.4)

	func _p_almanac(lo: float, hi: float) -> void:
		var c := Vector2(60, 72)
		var R := 40.0
		part(ell(Vector2(50, 116), 60, 30), Color("#d8c49a"), 1.4)
		part(ell(Vector2(100, 120), 50, 26), Color("#cbb68a"), 1.4)
		var w := Vector2(34, 58)
		for b in [[Vector2(-4, -6), 9.0], [Vector2(6, -9), 8.0], [Vector2(-7, 6), 8.0], [Vector2(3, 8), 7.0], [Vector2(0, 0), 10.0]]:
			part(circ(w + b[0], b[1]), WHITE, 1.3)
		part(circ(w + Vector2(6, 0), 7.0), WHITE, 1.1)
		dot(w + Vector2(4, -3), 1.0, INK)
		part(ell(w + Vector2(11, 2), 2.3, 1.8), INK, 0.4)
		for i in 4:
			draw_line(w + Vector2(14, -2 + i * 3), w + Vector2(38 + i * 6, -5 + i * 4), WOOD_INK, 0.6, true)
		push(Vector2(6, 40), 0.6)
		figure({"head": Vector2(104, 34), "sh": Vector2(102, 46), "sh_b": Vector2(112, 46), "el": Vector2(94, 36), "el_b": Vector2(120, 58),
			"ha": Vector2(100, 26), "ha_b": Vector2(122, 68), "hip": Vector2(108, 70), "hip_b": Vector2(114, 70), "kn": Vector2(100, 84), "kn_b": Vector2(120, 84),
			"ft": Vector2(94, 98), "ft_b": Vector2(126, 98)}, {"top": Color("#e9e2cf"), "overalls": DENIM, "legs": DENIM, "hat": "straw", "hair": "",
			"boots": Color("#3a2414"), "build": 12.0})
		pop()
		card_piece(Vector2(78, 50), -0.5, true, pal[0])
		card_piece(Vector2(84, 76), 0.6, false, pal[0])
		# outside the roundel: plain paper with a light engraving, then the rings
		draw_arc(c, R + 60.0, 0, TAU, 72, WOOD_PAPER, 120.0, true)
		draw_arc(c, R, 0, TAU, 72, WOOD_INK, 1.4, true)
		draw_arc(c, R + 3.0, 0, TAU, 72, WOOD_INK, 0.6, true)
		for i in 8:
			var a := i * TAU / 8.0
			var p := c + Vector2(cos(a), sin(a)) * (R + 1.5)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -2.2), p + Vector2(2.2, 0), p + Vector2(0, 2.2), p + Vector2(-2.2, 0)]), WOOD_INK)
		# wheat sheaves in the lower corners, under the text panel
		for sx in [12.0, 108.0]:
			for k in 7:
				var a := -PI * 0.5 + (k - 3) * 0.16
				var b := Vector2(sx, 176) + Vector2(cos(a), sin(a)) * 40.0
				draw_line(Vector2(sx, 176), b, WOOD_INK, 0.7, true)
				part(ell(b, 1.6, 4.0, a + PI * 0.5), Color("#d8c49a"), 0.5)

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
