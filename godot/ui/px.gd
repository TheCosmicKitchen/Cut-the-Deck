## Hand-authored pixel sprites for card pictures and icons. Drawn with nearest
## filtering inside the smooth UI, so they stay crisp at any scale.
class_name Px


static var _sprites := {}


# ---------- sprites ----------
# Sprites are text grids. Letters map to palette colours; "." is transparent.
# Lower-case letters are fixed colours; "a"/"b" take the sprite's tint (fill/shade).

const SPRITES := {
	"sword": [
		"..........kk",
		".........kwk",
		"........kwak",
		".......kwak.",
		"......kwak..",
		"..k..kwak...",
		"..kkkwak....",
		"...kbak.....",
		"..kyk.k.....",
		".kyk..kk....",
		"kyk.........",
		"kk..........",
	],
	"heart": [
		"............",
		".kkk...kkk..",
		"kawak.kaaak.",
		"kawwakaaaak.",
		"kaaaaaaaaak.",
		"kaaaaaaaaak.",
		".kaaaaaaak..",
		"..kaaaaak...",
		"...kaaak....",
		"....kak.....",
		".....k......",
		"............",
	],
	"shield": [
		"............",
		".kkkkkkkkkk.",
		".kwwaaaaaak.",
		".kwaaaaaaak.",
		".kwaaaaaabk.",
		".kaaaaaaabk.",
		".kaaaaaabbk.",
		"..kaaaaabk..",
		"..kaaaabbk..",
		"...kaabbk...",
		"....kbbk....",
		".....kk.....",
	],
	"cards": [
		"....kkkkkk..",
		"....kwwwwk..",
		"..kkkkkkwk..",
		"..kwwwwkwk..",
		"kkkkkkwkwk..",
		"kwwwwkwkwk..",
		"kwaawkwkkk..",
		"kwaawkwk....",
		"kwwwwkkk....",
		"kwaawk......",
		"kwwwwk......",
		"kkkkkk......",
	],
	"bolt": [
		".......kkk..",
		"......kyyk..",
		".....kyyk...",
		"....kyyk....",
		"...kyyykkk..",
		"..kyyyyyyk..",
		"..kkkyyyk...",
		"....kyyk....",
		"...kyyk.....",
		"..kyyk......",
		"..kyk.......",
		"..kk........",
	],
	"droop": [
		"............",
		"...kkkkkk...",
		"..kaaaaaak..",
		".kawkaawkak.",
		".kakkaakkak.",
		".kaaaaaaaak.",
		".kaakkkkaak.",
		".kakaaaakak.",
		"..kaaaaaak..",
		"...kkkkkk...",
		"....bbb.....",
		"....b.......",
	],
	"flex": [
		"............",
		"......kkk...",
		".....kaaak..",
		"....kawaak..",
		"....kaaabk..",
		"kkk.kaabk...",
		"kaakkaabk...",
		"kaaaaaabk...",
		"kaaaaabk....",
		".kbbbbk.....",
		"..kkkk......",
		"............",
	],
	"scissors": [
		"k.........k.",
		"kk.......kk.",
		".kk.....kk..",
		"..kk...kk...",
		"...kk.kk....",
		"....kkk.....",
		"...kkakk....",
		"..kaak.kak..",
		".kaa.k.k.ak.",
		".ka..k.k..ak",
		".kaaak..kaak",
		"..kkk....kk.",
	],
	"star": [
		"....k....",
		"...kyk...",
		"kkkyyykkk",
		".kyywyyk.",
		"..kyyyk..",
		".kyykyyk.",
		".kyk.kyk.",
		".kk...kk.",
		".........",
	],
	"glue": [
		"....kk......",
		"....kk......",
		"...kwwk.....",
		"..kkkkkk....",
		"..kwaaak....",
		"..kwaaak....",
		"..kaaaak....",
		"..kaaaak....",
		"..kaaabk....",
		"..kaabbk....",
		"..kkkkkk....",
		"............",
	],
	"trash": [
		"....kkkk....",
		"..kkkkkkkk..",
		"..kwwwwwwk..",
		"...kakakak..",
		"...kakakak..",
		"...kakakak..",
		"...kakakak..",
		"...kakakak..",
		"...kkkkkk...",
		"............",
		"............",
		"............",
	],
	"swap": [
		"............",
		".......k....",
		"kkkkkkkak...",
		"kaaaaaaaak..",
		"kkkkkkkak...",
		".......k....",
		"....k.......",
		"...kakkkkkkk",
		"..kaaaaaaaak",
		"...kakkkkkkk",
		"....k.......",
		"............",
	],
	"mute": [
		"k..........k",
		".k........k.",
		"..k......k..",
		"...k....k...",
		"kkkkkkkkkkkk",
		"kaaaaaaaaaak",
		"kkkkkkkkkkkk",
		"...k....k...",
		"..k......k..",
		".k........k.",
		"k..........k",
		"............",
	],
	"merge": [
		"............",
		"kkkkk..kkkkk",
		"kwaak..kaawk",
		"kaaak..kaaak",
		"kaaakkkkaaak",
		"kaaaaaaaaaak",
		"kaaakkkkaaak",
		"kaaak..kaaak",
		"kabbk..kbbak",
		"kkkkk..kkkkk",
		"............",
		"............",
	],
	"pen": [
		"..........kk",
		".........kyk",
		"........kyyk",
		".......kaak.",
		"......kaak..",
		".....kaak...",
		"....kaak....",
		"...kaak.....",
		"..kwak......",
		"..kkk.......",
		".k..........",
		"............",
	],
}

const FIXED := {"k": Color("#241848"), "w": Color("#ffffff"), "y": Color("#f8d838")}


## A sprite as a texture, tinted: "a" = tint, "b" = tint darkened.
static func sprite(name: String, tint := Color("#ec3a5c")) -> ImageTexture:
	var key := "%s:%s" % [name, tint.to_html()]
	if _sprites.has(key):
		return _sprites[key]
	var rows: Array = SPRITES[name]
	var w := 0
	for r in rows:
		w = maxi(w, r.length())
	var img := Image.create(w, rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == "." or ch == " ":
				continue
			var col: Color
			if FIXED.has(ch):
				col = FIXED[ch]
			elif ch == "a":
				col = tint
			elif ch == "b":
				col = tint.darkened(0.3)
			else:
				continue
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_sprites[key] = tex
	return tex


static func sprite_rect(name: String, tint := Color("#ec3a5c"), scale := 1) -> TextureRect:
	var t := TextureRect.new()
	t.texture = sprite(name, tint)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = t.texture.get_size() * scale
	t.size = t.custom_minimum_size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## The icon for a verb.
static func verb_sprite(verb: String) -> String:
	return {"deal": "sword", "heal": "heart", "block": "shield", "lose_block": "shield", "draw": "cards",
		"discard": "trash", "energy": "bolt", "lose_energy": "bolt", "weak": "droop", "strength": "flex"}.get(verb, "star")
