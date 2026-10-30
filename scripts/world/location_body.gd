extends Node2D
## A dockable place in the sector (planet, asteroid outpost, station, beacon). Pixel-art body from the art
## registry (space/<id>.png, procedural fallback); glow, rings, labels stay procedural.

const Art = preload("res://scripts/core/art.gd")

var id: String = ""
var info: Dictionary = {}
var radius := 80.0
var highlight := false
var _spin := 0.0


func setup(loc_id: String, loc: Dictionary) -> void:
	id = loc_id
	info = loc
	radius = float(loc.radius)
	position = Vector2(loc.pos[0], loc.pos[1])
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_spin += delta * 0.2
	queue_redraw()


func _draw() -> void:
	var c := Color(info.get("color", "#888888"))
	var body := Art.tex("space/%s.png" % id)
	if body != null:
		_draw_art(body, c)
	else:
		_draw_fallback(c)
	if highlight:
		draw_arc(Vector2.ZERO, radius + 30.0, 0, TAU, 64, Color(1, 1, 1, 0.6), 2.0)
	var font := ThemeDB.fallback_font
	var label: String = info.get("name", id)
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, Vector2(-w / 2.0, radius + 34.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.85))


func _draw_art(body: Texture2D, c: Color) -> void:
	var half := body.get_size() / 2.0
	match info.get("kind", "planet"):
		"planet":
			draw_circle(Vector2.ZERO, radius * 1.18, Color(c, 0.12))
			draw_texture(body, -half)
			draw_arc(Vector2.ZERO, radius * 1.5, -0.4, PI - 0.4, 48, Color(0.5, 1.0, 0.85, 0.5), 3.0)
		"station":
			draw_set_transform(Vector2.ZERO, _spin, Vector2.ONE)
			draw_texture(body, -half)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"asteroid":
			draw_texture(body, -half)
			draw_rect(Rect2(-12, -half.y + 2, 24, 14), Color("#cfa36b"))  # the outpost hut
			draw_rect(Rect2(-12, -half.y + 2, 24, 14), Color("#14121c"), false, 2.0)
		"beacon":
			var pulse := fmod(_spin * 5.0, 1.0)
			draw_circle(Vector2.ZERO, radius, Color(c, 0.12))
			draw_arc(Vector2.ZERO, radius * (1.0 + pulse * 2.0), 0, TAU, 40, Color(c, 1.0 - pulse), 2.0)
			draw_texture_rect(body, Rect2(-half * 2.0, half * 4.0), false)  # small buoy, shown 2x
		_:
			draw_texture(body, -half)


func _draw_fallback(c: Color) -> void:
	match info.get("kind", "planet"):
		"planet":
			draw_circle(Vector2.ZERO, radius * 1.18, Color(c, 0.12))
			draw_circle(Vector2.ZERO, radius, c)
			draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.7, c.lightened(0.12))
			for i in 5:
				var a := _spin + i * 1.3
				draw_circle(Vector2(cos(a), sin(a * 0.7)) * radius * 0.55, radius * 0.12, c.darkened(0.25))
			draw_arc(Vector2.ZERO, radius * 1.5, -0.4, PI - 0.4, 48, Color(0.5, 1.0, 0.85, 0.5), 3.0)
		"asteroid":
			var pts := PackedVector2Array()
			for i in 11:
				var a := TAU * i / 11.0 + _spin * 0.3
				pts.append(Vector2(cos(a), sin(a)) * radius * (0.75 + 0.25 * sin(i * 2.7)))
			draw_colored_polygon(pts, c)
			draw_circle(Vector2(radius * 0.2, -radius * 0.1), radius * 0.18, c.darkened(0.3))
			draw_rect(Rect2(-12, -radius - 18, 24, 18), Color("#cfa36b"))
		"station":
			draw_set_transform(Vector2.ZERO, _spin, Vector2.ONE)
			draw_arc(Vector2.ZERO, radius, 0, TAU, 40, c, 10.0)
			for i in 4:
				var d := Vector2.RIGHT.rotated(i * PI / 2.0)
				draw_line(d * 14.0, d * radius, c.lightened(0.2), 5.0)
			draw_circle(Vector2.ZERO, 18.0, c.lightened(0.3))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"beacon":
			draw_circle(Vector2.ZERO, radius, Color(c, 0.25))
			draw_circle(Vector2.ZERO, radius * 0.4, c)
			var pulse := fmod(_spin * 5.0, 1.0)
			draw_arc(Vector2.ZERO, radius * (1.0 + pulse * 2.0), 0, TAU, 40, Color(c, 1.0 - pulse), 2.0)
