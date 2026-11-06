extends Node2D
## The NPC freighter of an escort mission. A pure view of Escort's job state (position, hull): it is drawn as a squat
## procedural hauler with engine glow and a hull bar, and turns towards where it is flying. The rules and movement are
## in scripts/core/escort.gd.

const Escort = preload("res://scripts/core/escort.gd")

var radius := 30.0
var ratio := 1.0
var state := "moving"  ## moving | waiting | at_gate (engine glow and the label follow it)
var flash := 0.0
var _last := Vector2.ZERO
var _face := 0.0


func _ready() -> void:
	z_index = 4


## Copies position and hull from the core job.
func sync(g) -> void:
	var p := Escort.pos(g)
	if _last != Vector2.ZERO and p.distance_squared_to(_last) > 0.04:
		_face = (p - _last).angle() + PI / 2.0
	_last = p
	position = p
	rotation = lerp_angle(rotation, _face, 0.15)
	radius = float(Escort.fcfg(g).get("radius", 30))
	ratio = Escort.hull_ratio(g)
	var j: Dictionary = Escort.job(g)
	state = "at_gate" if bool(j.get("at_gate", false)) else ("waiting" if bool(j.get("waiting", false)) else "moving")


func hit() -> void:
	flash = 0.15


func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	queue_redraw()


func _draw() -> void:
	var col := Color(1, 1, 1) if flash <= 0.0 else Color(2.2, 2.2, 2.2)
	var hull := Color("#b9a27a") * col
	var dark := Color("#4a3f2c") * col
	var body := PackedVector2Array([Vector2(0, -34), Vector2(14, -20), Vector2(18, 22), Vector2(10, 32), Vector2(-10, 32), Vector2(-18, 22), Vector2(-14, -20)])
	draw_colored_polygon(body, hull)
	draw_polyline(body + PackedVector2Array([body[0]]), dark, 2.0)
	for i in 3:  # cargo pods
		draw_rect(Rect2(-11, -10 + i * 14, 22, 10), dark)
		draw_rect(Rect2(-9, -8 + i * 14, 18, 6), Color("#7a6a4a") * col)
	draw_circle(Vector2(0, -22), 4.0, Color("#7fd3ff") * col)
	if state == "moving":
		var f := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 70.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-8, 32), Vector2(8, 32), Vector2(0, 32 + 24 * f)]), Color(0.5, 0.8, 1.0, 0.8))
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	var w := 56.0
	draw_rect(Rect2(-w / 2.0, -radius - 22, w, 5), Color(0, 0, 0, 0.65))
	var c := Color("#6fe39a") if ratio > 0.5 else (Color("#ffd166") if ratio > 0.25 else Color("#ff6b5f"))
	draw_rect(Rect2(-w / 2.0, -radius - 22, w * ratio, 5), c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
