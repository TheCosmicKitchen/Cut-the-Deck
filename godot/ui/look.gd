## The game's look: pastel palette, rounded fonts, shared materials.
## Pictures stay as crisp pixel sprites (see Px.sprite), framed by smooth UI.
class_name Look

const INK := Color("#2a1d55")
const INK2 := Color("#6a5c99")
const WHITE := Color("#ffffff")
const CREAM := Color("#fff4ea")
const PINK := Color("#f9b8d6")
const PINK_D := Color("#f29ac4")
const MAGENTA := Color("#c22a78")
const PURPLE := Color("#7a62ea")
const LAV := Color("#bdaaf8")
const PEACH := Color("#f8caa8")
const YELLOW := Color("#ffd23c")
const RED := Color("#ec3a5c")
const GREEN := Color("#2fb36c")
const BLUE := Color("#3a7cec")

## Chunk pill colours: [fill, outline]
const CHUNK := {
	"verb": [Color("#ef4a6a"), Color("#a3184a")],
	"amount": [Color("#4a86f2"), Color("#1d3f9e")],
	"repeat": [Color("#a764ea"), Color("#5c2aa0")],
	"target": [Color("#36ba74"), Color("#127042")],
	"condition": [Color("#ffb03a"), Color("#a85c06")],
	"trigger": [Color("#5cc6de"), Color("#1d6e82")],
}
const CHUNK_TEXT := {"condition": Color("#3a2006"), "trigger": Color("#0e3440")}

## Frame stripe themes by main verb: [s1 stripe, s2 stripe, s3 stripe, edge/rule, art shade]
const THEME := {
	"deal": [Color("#ef4a6a"), Color("#ffd0b8"), Color("#fff6ee"), Color("#f8a6b8")],
	"heal": [Color("#36ba74"), Color("#cbf2bd"), Color("#fbfff4"), Color("#9cdcae")],
	"block": [Color("#4a86f2"), Color("#bcdafa"), Color("#f5f9ff"), Color("#9ebcf2")],
	"lose_block": [Color("#7a7ab0"), Color("#d6d6ec"), Color("#fafaff"), Color("#b6b6d6")],
	"draw": [Color("#2ea6c0"), Color("#bdeef4"), Color("#f5ffff"), Color("#8cd4e4")],
	"discard": [Color("#9c7c6c"), Color("#ecdccc"), Color("#fffaf4"), Color("#ccb4a4")],
	"energy": [Color("#f4a422"), Color("#fbeaa4"), Color("#fffcec"), Color("#f4cc74")],
	"lose_energy": [Color("#a48c54"), Color("#ece4c4"), Color("#fffcf4"), Color("#ccbc8c")],
	"weak": [Color("#a764ea"), Color("#e4ccfa"), Color("#fcf8ff"), Color("#ccacf4")],
	"strength": [Color("#ef5c34"), Color("#fbd4bc"), Color("#fff6ee"), Color("#f8ac8c")],
	"ui": [Color("#7a62ea"), Color("#f8caa8"), Color("#fff4ea"), Color("#bdaaf8")],
}

static var _fonts := {}


## "title" Fredoka Bold, "head" Fredoka SemiBold, "chunk" Fredoka Medium,
## "body" Nunito SemiBold, "body_bold" Nunito ExtraBold
static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path: String = {"title": "fredoka-700", "head": "fredoka-600", "chunk": "fredoka-600", "chunk_light": "fredoka-500",
		"body": "nunito-600", "body_bold": "nunito-800"}[kind]
	var f: FontFile = load("res://fonts/hd/%s.woff2" % path)
	_fonts[kind] = f
	return f


static func text_w(kind: String, text: String, size: int) -> float:
	return font(kind).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func label(text: String, kind := "body", size := 18, col := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func outlined(l: Label, col: Color, size := 4) -> Label:
	l.add_theme_constant_override("outline_size", size)
	l.add_theme_color_override("font_outline_color", col)
	return l


const CANDY := preload("res://shaders/candy.gdshader")


static func candy_material(box: Vector2, theme := "ui", shadow := Vector2(8, 8), band := 12.0, radius := 16.0) -> ShaderMaterial:
	var t: Array = THEME.get(theme, THEME.ui)
	var m := ShaderMaterial.new()
	m.shader = CANDY
	m.set_shader_parameter("rect_size", box + shadow)
	m.set_shader_parameter("shadow", shadow)
	m.set_shader_parameter("band", band)
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("period", max(10.0, band * 1.5))
	m.set_shader_parameter("s1", t[0])
	m.set_shader_parameter("s2", t[1])
	m.set_shader_parameter("s3", t[2])
	m.set_shader_parameter("edge", t[0].darkened(0.1))
	m.set_shader_parameter("rule", t[3])
	m.set_shader_parameter("shadow_col", MAGENTA)
	return m


## A candy panel: returns { root, rect, mat }. Put content in root; the box is `box` px.
static func candy(box: Vector2, theme := "ui", shadow := Vector2(8, 8), band := 12.0, radius := 16.0) -> Control:
	var root := Control.new()
	root.size = box
	root.custom_minimum_size = box
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := ColorRect.new()
	r.size = box + shadow
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = candy_material(box, theme, shadow, band, radius)
	root.add_child(r)
	root.set_meta("rect", r)
	return root


static func resize_candy(root: Control, box: Vector2) -> void:
	root.size = box
	root.custom_minimum_size = box
	var r: ColorRect = root.get_meta("rect")
	var sh: Vector2 = r.material.get_shader_parameter("shadow")
	r.size = box + sh
	r.material.set_shader_parameter("rect_size", box + sh)
