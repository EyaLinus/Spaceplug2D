extends Node2D
## A person on a planet surface. Static NPCs (contacts, mechanic) stand still and show their name;
## ambient walkers stroll along the road network the surface hands them. Drawn procedurally.

var display_name := ""
var color := Color("#8fb3ff")
var speed := 55.0
var path: Array = []  ## Vector2 waypoints still to walk
var pick_next: Callable  ## returns a new path when this one is done (walkers only)
var _step := 0.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if path.is_empty() and pick_next.is_valid():
		path = pick_next.call(position)
	if not path.is_empty():
		var target: Vector2 = path[0]
		var to := target - position
		if to.length() < 3.0:
			path.pop_front()
		else:
			position += to.normalized() * minf(speed * delta, to.length())
			_step += delta * 9.0
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, 12), 8.0, Color(0, 0, 0, 0.28))
	var moving := not path.is_empty()
	var swing := sin(_step) * 3.5 if moving else 0.0
	var leg := color.darkened(0.6)
	draw_line(Vector2(-3, 4), Vector2(-3 + swing * 0.3, 12), leg, 3.0)
	draw_line(Vector2(3, 4), Vector2(3 - swing * 0.3, 12), leg, 3.0)
	draw_rect(Rect2(-6, -6, 12, 11), color)
	draw_rect(Rect2(-6, -6, 12, 11), color.darkened(0.5), false, 1.5)
	var idle := sin(_t * 2.0) * 0.8 if not moving else 0.0
	draw_circle(Vector2(0, -11 + idle), 5.5, Color("#c99b78"))
	if display_name != "":
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2(-w / 2.0 + 1, -21), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(-w / 2.0, -22), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color.lightened(0.4))
