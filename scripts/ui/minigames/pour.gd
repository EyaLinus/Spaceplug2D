extends "res://scripts/ui/minigames/station_minigame.gd"
## Mixing Station: pour each additive into the beaker. Holding pours faster the longer you hold;
## releasing ends that pour and its level is scored against the green band. Overflowing scores zero. Affects quality.

const BEAKER := Rect2(330, 60, 160, 220)

var pours: Array = []  ## [{name, color, center, half, level, score}]
var current := 0
var rate := 0.0
var _gap := 0.0  ## short pause between two pours


func _begin() -> void:
	var adds: Array = ctx.get("additives", [])
	duration = 7.0 * maxi(adds.size(), 1)
	for a in adds:
		var ad: Dictionary = ctx.data.additives[a]
		var trait_color: String = ctx.data.traits[ad.adds].color
		pours.append({"name": ad.name, "color": Color(trait_color), "center": rng.randf_range(0.45, 0.8),
			"half": 0.06 - 0.008 * (tier() - 1), "level": 0.0, "score": 0.0})
	if pours.is_empty():
		pours.append({"name": "Water", "color": Color("#7fb2ff"), "center": 0.6, "half": 0.06, "level": 0.0, "score": 0.0})


func _primary(pressed: bool, _pos: Vector2) -> void:
	if not pressed and _gap <= 0.0 and pours[current].level > 0.02:
		_end_pour()


func _tick(dt: float) -> void:
	if _gap > 0.0:
		_gap -= dt
		return
	var p: Dictionary = pours[current]
	if holding:
		rate = minf(rate + dt * 0.9, 0.75)
		p.level += (0.12 + rate) * dt
		if p.level >= 1.0:
			p.level = 1.0
			sfx("error")
			_end_pour()
	else:
		rate = 0.0


func _end_pour() -> void:
	var p: Dictionary = pours[current]
	p.score = 0.0 if p.level >= 1.0 else band_score(p.level, p.center, p.half, 0.22)
	sfx("click")
	holding = false
	rate = 0.0
	if current + 1 >= pours.size():
		finish(_avg())
	else:
		current += 1
		_gap = 0.5


func _avg() -> float:
	var s := 0.0
	for p in pours:
		s += float(p.score)
	return s / pours.size()


func _timeout_score() -> float:
	var p: Dictionary = pours[current]
	p.score = band_score(p.level, p.center, p.half, 0.22) * 0.8 if p.level > 0.02 else 0.0
	return _avg()


func status_text() -> String:
	var done_scores: Array = []
	for i in current:
		done_scores.append("%d%%" % int(float(pours[i].score) * 100.0))
	return "Pour %d/%d: %s · %s" % [current + 1, pours.size(), pours[current].name, ("done: " + ", ".join(PackedStringArray(done_scores))) if current > 0 else "hold to pour, release in the band"]


func bot_input(_dt: float) -> void:
	if _gap > 0.0:
		return
	var p: Dictionary = pours[current]
	if p.level + (0.12 + rate) * 0.03 < p.center:
		if not holding:
			press(true)
	elif holding:
		press(false)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, AREA), Color("#161a2e"))
	var p: Dictionary = pours[current]
	var b := BEAKER
	var lvl_y := func(l: float) -> float: return b.end.y - b.size.y * l
	var band_top: float = lvl_y.call(p.center + p.half)
	var band_bot: float = lvl_y.call(p.center - p.half)
	draw_rect(Rect2(b.position.x - 30, band_top, b.size.x + 60, band_bot - band_top), Color(GOOD, 0.25))
	var ly: float = lvl_y.call(float(p.level))
	draw_rect(Rect2(b.position.x, ly, b.size.x, b.end.y - ly), Color(p.color, 0.85))
	draw_rect(b, Color("#a0d8ff"), false, 3.0)
	if holding and _gap <= 0.0:
		draw_line(Vector2(b.get_center().x + 40, 20), Vector2(b.get_center().x + 40, ly), Color(p.color, 0.9), 4.0 + rate * 8.0)
	draw_rect(Rect2(b.get_center().x + 20, 0, 60, 26), p.color)
	text(Vector2(20, 28), "Pour %s" % p.name, 18, GOOD)
	for i in pours.size():
		var col: Color = GOOD if i < current else (GOLD if i == current else MUTED)
		text(Vector2(560, 80 + i * 26), "%d. %s" % [i + 1, pours[i].name], 16, col)
	text(Vector2(20, AREA.y - 30), status_text(), 15, MUTED)
	timer_bar()
