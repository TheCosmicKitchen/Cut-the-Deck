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

## which scene each card uses; anything missing falls back on its verb
const SCENES := {
	"strike": "strike", "defend": "defend", "jab": "jab", "reckless_swing": "reckless",
	"second_wind": "second_wind", "cheap_shot": "cheap_shot", "bulwark": "bulwark",
	"opening": "opening",
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
static func texture(tree: SceneTree, scene: String, pal: Array, sz: Vector2, done: Callable) -> void:
	var key := "%s|%s|%dx%d" % [scene, pal[0].to_html(), sz.x, sz.y]
	if _cache.has(key):
		done.call(_cache[key])
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(sz * 2.0)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas := Canvas.new()
	canvas.scene = scene
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
		var r := _rough(pts, amt)
		if shadow:
			var sh := PackedVector2Array()
			for p in r:
				sh.append(p + Vector2(1.3, 1.8))
			draw_colored_polygon(sh, Color(INK, 0.22))
		draw_colored_polygon(r, col)

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
		draw_line(a, b, Color(INK, alpha), w, true)

	func dot(c: Vector2, r: float, col := INK) -> void:
		draw_circle(c, r, col, true, -1.0, true)

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
		# sky and far hills, full width
		draw_rect(Rect2(Vector2.ZERO, size), pal[2])
		pop()
		var hill_col: Color = pal[1].lerp(pal[2], 0.35)
		paper(ell(Vector2(40, 98), 70, 34), hill_col, false, 1.0)
		paper(ell(Vector2(190, 102), 80, 30), hill_col.lerp(pal[1], 0.5), false, 1.0)
		call("_" + scene, lo, hi)
		# a soft inner shadow so the window feels sunk into the card
		draw_set_transform_matrix(Transform2D())
		for i in 6:
			var a := 0.16 * (1.0 - i / 6.0)
			draw_rect(Rect2(0, i * 2, size.x, 2), Color(INK, a))
			draw_rect(Rect2(i * 2, 0, 2, size.y), Color(INK, a * 0.7))

	func ground(lo: float, hi: float, col: Color, y := GROUND) -> void:
		paper(PackedVector2Array([Vector2(lo - 4, y + 1), Vector2(hi + 4, y - 1), Vector2(hi + 4, 120), Vector2(lo - 4, 120)]), col, true, 1.1)

	func sun(c: Vector2, r: float) -> void:
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
