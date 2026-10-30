extends "res://scripts/ui/minigames/station_minigame.gd"
## Cook Stove: hold to fire the burner, let go to cool. The temperature has inertia and random drafts.
## Score = share of the cook spent inside the green band; scorching (top of the gauge) costs extra. Affects quality.

var temp := 0.3
var vel := 0.0
var center := 0.6
var half := 0.1
var in_band := 0.0
var scorch := 0.0
var _draft := 0.0


func _begin() -> void:
	duration = 8.0
	half = 0.11 - 0.015 * (tier() - 1)
	center = rng.randf_range(0.5, 0.7)


func _tick(dt: float) -> void:
	_draft = lerpf(_draft, rng.randf_range(-0.6, 0.6), dt * 2.0)
	vel += ((0.9 if holding else -0.7) + _draft * 0.5) * dt
	vel *= pow(0.25, dt)
	temp = clampf(temp + vel * dt, 0.0, 1.0)
	if absf(temp - center) <= half:
		in_band += dt
	if temp > 0.95:
		scorch += dt


func _timeout_score() -> float:
	return in_band / duration * 1.1 - scorch / duration


func status_text() -> String:
	return "In the band: %d%% · %s" % [int(in_band / maxf(elapsed, 0.01) * 100.0), "SCORCHING!" if temp > 0.95 else ("in the zone" if absf(temp - center) <= half else ("too cold" if temp < center else "too hot"))]


func bot_input(_dt: float) -> void:
	var want := temp + vel * 0.5 < center
	if want != holding:
		press(want)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, AREA), Color("#1e1418"))
	var g := Rect2(600, 40, 40, 250)
	draw_rect(g, DARK)
	var gy := func(t: float) -> float: return g.end.y - g.size.y * t
	draw_rect(Rect2(g.position.x, gy.call(center + half), g.size.x, g.size.y * half * 2.0), Color(GOOD, 0.45))
	draw_rect(Rect2(g.position.x, g.position.y, g.size.x, g.size.y * 0.05), Color(BAD, 0.6))
	var ty: float = gy.call(temp)
	draw_rect(Rect2(g.position.x - 8, ty - 3, g.size.x + 16, 6), GOLD)
	var pot := Rect2(270, 120, 200, 110)
	draw_rect(pot, Color("#5a5f7a"))
	draw_rect(Rect2(pot.position + Vector2(10, 10), Vector2(pot.size.x - 20, 30)), Color("#3d2b4f").lerp(Color("#ff9a4d"), temp))
	for i in int(temp * 8.0):
		var bx := pot.position.x + 20 + fmod(i * 37.0 + elapsed * 40.0, pot.size.x - 40)
		draw_circle(Vector2(bx, pot.position.y + 18 + sin(elapsed * 6.0 + i) * 6.0), 4.0, Color(1, 1, 1, 0.5))
	if holding:
		for i in 5:
			var fx := pot.position.x + 30 + i * 35
			draw_colored_polygon(PackedVector2Array([Vector2(fx - 10, 262), Vector2(fx, 236 - sin(elapsed * 20.0 + i) * 8.0), Vector2(fx + 10, 262)]), Color("#ff9a4d"))
	draw_rect(Rect2(250, 262, 240, 14), Color("#3a3f66"))
	text(Vector2(20, 28), "Keep the cook in the green", 18, GOOD)
	text(Vector2(660, ty + 6), "%d°" % int(60 + temp * 180), 18, GOLD)
	text(Vector2(20, AREA.y - 30), status_text(), 15, MUTED)
	timer_bar()
