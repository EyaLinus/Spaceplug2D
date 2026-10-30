extends "res://scripts/ui/minigames/station_minigame.gd"
## Trim Table: snip the fan leaves off a cannabis bud before the timer runs out. Clicking the bud nicks it.
## Score = share of leaves snipped, minus a penalty per nick. Affects yield.

const C := Vector2(410, 158)
const BUD_R := 46.0
const NICK_PENALTY := 0.12

var leaves: Array = []  ## [{angle, length, alive}]
var nicks := 0
var _bot_wait := 0.0


func _begin() -> void:
	duration = 11.0
	var n := 10
	for i in n:
		leaves.append({"angle": TAU * i / n + rng.randf_range(-0.2, 0.2), "length": rng.randf_range(62.0, 98.0), "alive": true})


func leaf_segment(i: int) -> Array:
	var l: Dictionary = leaves[i]
	var a: float = l.angle + 0.1 * sin(elapsed * 2.2 + i * 1.7)
	var dir := Vector2.from_angle(a)
	return [C + dir * (BUD_R - 4.0), C + dir * (BUD_R + float(l.length))]


func alive_count() -> int:
	var n := 0
	for l in leaves:
		if l.alive:
			n += 1
	return n


func _primary(pressed: bool, pos: Vector2) -> void:
	if not pressed or pos.x < 0:
		return
	for i in leaves.size():
		if not leaves[i].alive:
			continue
		var seg := leaf_segment(i)
		if pos.distance_to(C) > BUD_R - 2.0 and Geometry2D.get_closest_point_to_segment(pos, seg[0], seg[1]).distance_to(pos) < 15.0:
			leaves[i].alive = false
			sfx("snip")
			if alive_count() == 0:
				finish(1.0 - NICK_PENALTY * nicks)
			return
	if pos.distance_to(C) <= BUD_R:
		nicks += 1
		sfx("error")


func _timeout_score() -> float:
	return float(leaves.size() - alive_count()) / leaves.size() * 0.9 - NICK_PENALTY * nicks


func status_text() -> String:
	return "Leaves left: %d/%d · nicks: %d" % [alive_count(), leaves.size(), nicks]


func bot_input(dt: float) -> void:
	_bot_wait -= dt
	if _bot_wait > 0.0:
		return
	_bot_wait = 0.3
	for i in leaves.size():
		if leaves[i].alive:
			var seg := leaf_segment(i)
			press(true, seg[0].lerp(seg[1], 0.7))
			press(false)
			return


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, AREA), Color("#14201a"))
	draw_circle(C, 150.0, Color("#1c2b22"))
	for i in leaves.size():
		var seg := leaf_segment(i)
		if leaves[i].alive:
			var dir: Vector2 = (seg[1] - seg[0]).normalized()
			var side := dir.orthogonal() * 13.0
			var mid: Vector2 = seg[0].lerp(seg[1], 0.45)
			draw_colored_polygon(PackedVector2Array([seg[0], mid + side, seg[1], mid - side]), Color("#3f8f3a"))
			draw_line(seg[0], seg[1], Color("#2c6a2a"), 2.0)
		else:
			draw_circle(seg[0], 4.0, Color("#6b4f2a"))
	draw_circle(C, BUD_R, Color("#7cbf52"))
	for k in 7:
		draw_circle(C + Vector2.from_angle(k * 0.9) * 22.0, 12.0, Color("#93d164"))
	draw_circle(C, 14.0, Color("#c97cd1"))
	text(Vector2(20, 28), "Snip the fan leaves", 18, GOOD)
	text(Vector2(20, AREA.y - 30), status_text(), 15, MUTED)
	timer_bar()
