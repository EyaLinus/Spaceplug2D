extends Node2D
## K1: a number or word that pops up in the world (damage on a ship, "+90 cr" over a buyer), rises and fades.
## Spawn with `FloatText.new().setup(text, colour)` and add it next to the thing it belongs to.

const LIFE := 0.9
var text := ""
var color := Color.WHITE
var font_size := 16
var _t := 0.0
var _drift := Vector2.ZERO


func setup(t: String, c: Color, size := 16) -> Node2D:
	text = t
	color = c
	font_size = size
	z_index = 50
	_drift = Vector2(randf_range(-14.0, 14.0), -46.0)
	return self


func _process(delta: float) -> void:
	_t += delta
	position += _drift * delta
	_drift.y *= 0.96
	modulate.a = clampf(1.6 - _t / LIFE * 1.6, 0.0, 1.0)
	scale = Vector2.ONE * (1.0 + maxf(0.0, 0.25 - _t) * 1.6)  # small punch when it appears
	if _t >= LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(-w / 2.0, 0.0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.05, 0.04, 0.08, 0.9))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
