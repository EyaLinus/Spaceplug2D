extends "res://scripts/ui/minigames/station_minigame.gd"
## Packaging Table: a heat sealer sweeps back and forth; press when it is over the bag's seal strip.
## One press per bag (3–6 bags). Score = average seal accuracy. Tight seals lower the batch's heat.

var bags := 4
var sealed: Array = []  ## accuracy per bag
var x := 0.0
var dir := 1.0
var speed := 1.0
var zone := 0.5
var zone_half := 0.07


func _begin() -> void:
	bags = clampi(int(ctx.get("qty", 4)), 3, 6)
	duration = 2.2 * bags
	speed = 0.95 + 0.2 * tier()
	_next_zone()


func _next_zone() -> void:
	zone = rng.randf_range(0.15, 0.85)


func _tick(dt: float) -> void:
	x += dir * speed * dt
	if x > 1.0:
		x = 2.0 - x
		dir = -1.0
	elif x < 0.0:
		x = -x
		dir = 1.0


func _primary(pressed: bool, _pos: Vector2) -> void:
	if not pressed:
		return
	sealed.append(band_score(x, zone, zone_half * 0.35, zone_half * 1.5))
	sfx("seal")
	if sealed.size() >= bags:
		finish(_avg())
	else:
		_next_zone()


func _avg() -> float:
	var s := 0.0
	for a in sealed:
		s += float(a)
	return s / bags


func _timeout_score() -> float:
	return _avg()


func status_text() -> String:
	return "Bags sealed: %d/%d" % [sealed.size(), bags]


func bot_input(_dt: float) -> void:
	if absf(x - zone) < 0.015:
		press(true)
		press(false)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, AREA), Color("#161e24"))
	var bar := Rect2(80, 150, AREA.x - 160, 70)
	draw_rect(bar, Color("#2a3440"))
	var zx := bar.position.x + bar.size.x * zone
	var zw := bar.size.x * zone_half
	draw_rect(Rect2(bar.position.x + bar.size.x * (zone - 0.15), bar.position.y + 8, bar.size.x * 0.3, bar.size.y - 16), Color("#c8d6e0", 0.35))
	draw_rect(Rect2(zx - zw, bar.position.y, zw * 2.0, bar.size.y), Color(GOOD, 0.45))
	var sx := bar.position.x + bar.size.x * x
	draw_rect(Rect2(sx - 4, bar.position.y - 30, 8, bar.size.y + 60), GOLD)
	draw_rect(Rect2(sx - 22, bar.position.y - 44, 44, 16), Color("#5a5f7a"))
	for i in bags:
		var c: Color = MUTED
		if i < sealed.size():
			c = GOOD if float(sealed[i]) > 0.75 else (GOLD if float(sealed[i]) > 0.35 else BAD)
		if i < sealed.size():
			draw_rect(Rect2(80 + i * 52, 250, 40, 34), c)
		else:
			draw_rect(Rect2(80 + i * 52, 250, 40, 34), c, false, 2.0)
	text(Vector2(20, 28), "Seal the bags", 18, GOOD)
	text(Vector2(20, AREA.y - 30), status_text(), 15, MUTED)
	timer_bar()
