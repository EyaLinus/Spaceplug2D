extends "res://scripts/ui/minigames/station_minigame.gd"
## Precursor Scale: weigh out the precursor. Each scoop adds a random 4–9 g, a pinch removes 1 g, Enter confirms.
## The display needle wobbles for a moment after every scoop. Score falls with the error to the target. Affects yield.

var target := 50.0
var weight := 0.0
var wobble := 0.0
var last_scoop := 0.0


func _begin() -> void:
	duration = 12.0
	target = float(rng.randi_range(36, 64))


func _primary(pressed: bool, _pos: Vector2) -> void:
	if not pressed:
		return
	last_scoop = rng.randf_range(4.0, 9.0)
	weight += last_scoop
	wobble = 1.0
	sfx("click")


func _secondary() -> void:
	weight = maxf(weight - 1.0, 0.0)
	wobble = maxf(wobble, 0.3)
	sfx("snip")


func _confirm() -> void:
	finish(_score())


func _score() -> float:
	var tol := 0.07 + 0.012 * (tier() - 1)  # higher tiers punish errors harder
	return clampf(1.0 - absf(weight - target) * tol, 0.0, 1.0)


func _timeout_score() -> float:
	return _score() * 0.8


func _tick(dt: float) -> void:
	wobble = maxf(wobble - dt * 1.6, 0.0)


func reading() -> float:
	return weight + wobble * 6.0 * sin(elapsed * 22.0)


func status_text() -> String:
	return "Target %d g · reading %.1f g · last scoop %.1f g · Enter to confirm" % [int(target), maxf(reading(), 0.0), last_scoop]


func bot_input(_dt: float) -> void:
	if weight < target - 0.5:
		press(true)
		press(false)
	elif weight > target + 0.5:
		_secondary()
	else:
		_confirm()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, AREA), Color("#1a1826"))
	var c := Vector2(410, 190)
	draw_rect(Rect2(c + Vector2(-150, 40), Vector2(300, 28)), Color("#3a3f66"))
	draw_rect(Rect2(c + Vector2(-110, 24), Vector2(220, 16)), Color("#596094"))
	var pile := clampf(weight / 80.0, 0.0, 1.4)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-90 * pile - 10, 24), c + Vector2(0, 24 - 70 * pile - 2), c + Vector2(90 * pile + 10, 24)]), Color("#f1efe6"))
	var dial := Vector2(410, 110)
	draw_arc(dial, 80.0, PI, TAU, 40, Color("#596094"), 6.0)
	var ang := func(w: float) -> float: return PI + clampf(w / 80.0, 0.0, 1.0) * PI
	var ta: float = ang.call(target)
	draw_line(dial + Vector2.from_angle(ta) * 64.0, dial + Vector2.from_angle(ta) * 92.0, GOOD, 4.0)
	var ra: float = ang.call(reading())
	draw_line(dial, dial + Vector2.from_angle(ra) * 76.0, GOLD, 3.0)
	draw_circle(dial, 6.0, GOLD)
	text(Vector2(20, 28), "Weigh out %d g" % int(target), 18, GOOD)
	text(Vector2(560, 90), "%.1f g" % maxf(reading(), 0.0), 34, GOLD)
	text(Vector2(20, AREA.y - 30), status_text(), 15, MUTED)
	timer_bar()
