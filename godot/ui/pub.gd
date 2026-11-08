## The six publications: every card is printed as one of them, and every chunk
## remembers which one it was printed in. Cutting and pasting mixes them.
##
## Ring (neighbours are allies, across is opposite):
##   Newspaper - Comics - Pulp - Zine - Manual - Almanac - (Newspaper)
class_name Pub

enum { NEWS, COMIC, PULP, ZINE, MANUAL, ALMANAC }

const NAMES := ["Newspaper", "Comics", "Pulp Horror", "Zine", "Instruction Manual", "Almanac"]

## which publication each card is printed in
const OF_CARD := {
	"strike": NEWS, "reckless_swing": NEWS, "fortress": NEWS,
	"jab": COMIC, "flurry": COMIC, "shield_bash": COMIC,
	"blood_price": PULP, "hex": PULP, "exploit": PULP, "cheap_shot": PULP,
	"all_in": ZINE, "overcharge": ZINE, "surge": ZINE,
	"defend": MANUAL, "bulwark": MANUAL,
	"second_wind": ALMANAC, "kind_word": ALMANAC, "opening": ALMANAC,
}

## how a slip is stuck onto a card of this publication
const ATTACH := ["glue", "tape", "stitch", "staple", "bolt", "corners"]

const INK := Color("#1d1a17")
const NAVY := Color("#1f2f52")
const BROWN := Color("#4a2c16")
const RISO := Color("#ff4f9a")
const ACID := Color("#d9f24a")

static var _fonts := {}


static func of_card(card_or_id) -> int:
	var id: String = card_or_id if card_or_id is String else card_or_id.get("base", "")
	return OF_CARD.get(id, NEWS)


## The publication a chunk was printed in: its source card's, else the card it's on.
static func of_chunk(ch, on_card: Dictionary) -> int:
	if ch is Dictionary and ch.has("from"):
		return of_card(ch.from)
	return of_card(on_card)


static func font(name: String) -> Font:
	if _fonts.has(name):
		return _fonts[name]
	var f: Font
	if name.begins_with("hd/"):
		f = load("res://fonts/%s.woff2" % name)
	else:
		f = load("res://fonts/pub/%s.woff2" % name)
	_fonts[name] = f
	return f


## Text style for chunk words printed in this publication: [font, size, upper]
static func body(pub: int) -> Array:
	match pub:
		NEWS: return ["playfair-700", 18, false]
		COMIC: return ["comic-neue-700", 19, true]
		PULP: return ["cormorant-700", 21, false]
		ZINE: return ["special-elite", 17, false]
		MANUAL: return ["hd/nunito-800", 16, false]
	return ["fell", 20, false]


## Ink for a chunk type, as this publication would print it.
static func ink(pub: int, slot: String) -> Color:
	var c: Color = ChunkView.INK.get(slot, INK)
	match pub:
		NEWS:
			return INK
		ZINE:
			return Color("#141414")
		PULP:
			return c.darkened(0.35)
		ALMANAC:
			return c.lerp(BROWN, 0.45)
		MANUAL:
			return c.darkened(0.1)
	return c


static func label(text: String, fname: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(fname))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
