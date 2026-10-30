extends "res://scripts/ui/minigames/station_minigame.gd"
## Extractor: hold to heat the solvent column, let go to cool. Unlike the Cook Stove the green band moves: it follows
## an extraction profile (warm-up, first fraction, hotter second fraction, cool-down) drawn on a chart recorder, so you
## have to anticipate the next step. Score = share of the run spent on the profile; boiling over costs double.
## Affects purity.

const BOIL := 0.93

var temp := 0.2
var vel := 0.0
var half := 0.09
var keys: Array = []  ## [[t 0..1, center], ...] the extraction profile
var in_band := 0.0
var boil := 0.0
var trace: PackedVector2Array = PackedVector2Array()  ## (elapsed, temp) samples for the chart
var _draft := 0.0
var _sample := 0.0


func _begin() -> void:
	duration = 10.0
	half = 0.09 - 0.01 * (tier() - 1)
	keys = [[0.0, 0.32], [0.3, rng.randf_range(0.48, 0.58)], [0.62, rng.randf_range(0.7, 0.8)], [1.0, rng.randf_range(0.45, 0.55)]]


## Band center at run time t (seconds).
func center_at(t: float) -> float:
	var f := clampf(t / duration, 0.0, 1.0)
	for i in range(1, keys.size()):
		if f <= float(keys[i][0]):
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var u := (f - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			return lerpf(float(a[1]), float(b[1]), smoothstep(0.0, 1.0, u))
	return float(keys[-1][1])


func _tick(dt: float) -> void:
	_draft = lerpf(_draft, rng.randf_range(-0.6, 0.6), dt * 2.0)
	vel += ((0.9 if holding else -0.7) + _draft * 0.4) * dt
	vel *= pow(0.25, dt)
	temp = clampf(temp + vel * dt, 0.0, 1.0)
	if absf(temp - center_at(elapsed)) <= half:
		in_band += dt
	if temp > BOIL:
		boil += dt
	_sample -= dt
	if _sample <= 0.0:
		_sample = 0.05
		trace.append(Vector2(elapsed, temp))


func _timeout_score() -> float:
	return in_band / duration * 1.12 - boil / duration * 2.0


func status_text() -> String:
	var c := center_at(elapsed)
	var state := "BOILING OVER!" if temp > BOIL else ("on profile" if absf(temp - c) <= half else ("too cold" if temp < c else "too hot"))
	return "On profile: %d%% · %s" % [int(in_band / maxf(elapsed, 0.01) * 100.0), state]


func bot_input(_dt: float) -> void:
	var want := temp + vel * 0.5 < center_at(elapsed + 0.4)
	if want != holding:
		press(want)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, AREA), Color("#141a1e"))
	# column: boiler at the bottom, glass tube, condenser coil, drip into the collection flask
	var col := Rect2(120, 60, 46, 190)
	draw_rect(Rect2(90, 250, 106, 36), Color("#5a5f7a"))
	draw_rect(Rect2(98, 258, 90, 20), Color("#3d2b4f").lerp(Color("#ff9a4d"), temp))
	draw_rect(col, Color("#26323a"))
	var fill := col.size.y * clampf(temp, 0.0, 1.0)
	draw_rect(Rect2(col.position.x + 6, col.end.y - fill, col.size.x - 12, fill), Color("#4fe3c1", 0.25).lerp(Color("#ffd166", 0.5), temp))
	for i in int(temp * 7.0):
		var by := col.end.y - fmod(i * 29.0 + elapsed * 70.0, fill + 1.0)
		draw_circle(Vector2(col.position.x + 14 + (i % 3) * 9, by), 3.0, Color(1, 1, 1, 0.45))
	draw_rect(col, Color("#9aa0ad"), false, 2.0)
	for i in 5:
		draw_arc(Vector2(200, 80 + i * 14), 10.0, -PI / 2, PI / 2, 8, Color("#7fb8d0"), 3.0)
	draw_line(Vector2(166, 74), Vector2(200, 70), Color("#9aa0ad"), 3.0)
	draw_rect(Rect2(186, 170, 40, 60), Color("#26323a"))
	var good := in_band / maxf(duration, 0.01)
	draw_rect(Rect2(190, 226 - 52 * good, 32, 52 * good), Color("#e8c547"))
	draw_rect(Rect2(186, 170, 40, 60), Color("#9aa0ad"), false, 2.0)
	if absf(temp - center_at(elapsed)) <= half and fmod(elapsed, 0.4) < 0.2:
		draw_circle(Vector2(206, 150), 3.0, Color("#e8c547"))
	if holding:
		for i in 4:
			var fx := 104.0 + i * 26.0
			draw_colored_polygon(PackedVector2Array([Vector2(fx - 8, 300), Vector2(fx, 288 - sin(elapsed * 20.0 + i) * 6.0), Vector2(fx + 8, 300)]), Color("#ff9a4d"))
	# chart recorder: the profile band over the whole run, the trace so far, a cursor at "now"
	var ch := Rect2(300, 50, 490, 240)
	draw_rect(ch, DARK)
	var to_px := func(t: float, v: float) -> Vector2: return Vector2(ch.position.x + ch.size.x * t / duration, ch.end.y - ch.size.y * v)
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in 41:
		var t := duration * i / 40.0
		var c := center_at(t)
		top.append(to_px.call(t, c + half))
		bottom.append(to_px.call(t, c - half))
	bottom.reverse()
	draw_colored_polygon(top + bottom, Color(GOOD, 0.3))
	draw_rect(Rect2(ch.position, Vector2(ch.size.x, ch.size.y * (1.0 - BOIL))), Color(BAD, 0.35))
	var pts := PackedVector2Array()
	for s in trace:
		pts.append(to_px.call(s.x, s.y))
	if pts.size() >= 2:
		draw_polyline(pts, GOLD, 2.0)
	var now: Vector2 = to_px.call(elapsed, temp)
	draw_line(Vector2(now.x, ch.position.y), Vector2(now.x, ch.end.y), Color(1, 1, 1, 0.25), 1.0)
	draw_circle(now, 5.0, GOLD)
	draw_rect(ch, Color("#3a3f66"), false, 2.0)
	text(Vector2(20, 28), "Ride the extraction profile", 18, GOOD)
	text(Vector2(ch.end.x - 70, ch.position.y - 8), "%d°" % int(40 + temp * 140), 18, GOLD)
	text(Vector2(20, AREA.y - 30), status_text(), 15, MUTED)
	timer_bar()
