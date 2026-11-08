## The ↳ arrow under a condition: it drops from the condition line and points
## into the effect the condition controls.
class_name IndentArrow
extends Control

var col := Color("#c77a00")


func _draw() -> void:
	var x := 12.0
	var top := -2.0
	var mid := size.y * 0.5 + 1.0
	var tip := size.x - 3.0
	var w := 3.0
	draw_line(Vector2(x, top), Vector2(x, mid - 6.0), col, w, true)
	draw_arc(Vector2(x + 6.0, mid - 6.0), 6.0, PI, PI * 0.5, 8, col, w, true)
	draw_line(Vector2(x + 6.0, mid), Vector2(tip - 1.0, mid), col, w, true)
	draw_colored_polygon(PackedVector2Array([Vector2(tip + 2.0, mid), Vector2(tip - 6.0, mid - 6.0), Vector2(tip - 6.0, mid + 6.0)]), col)
