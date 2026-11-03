extends "res://scripts/planet/npc.gd"
## Reach Authority officer on a planet surface: walks the roads like a civilian, looks where it walks
## (vision cone) and chases the player when the surface tells it to. The surface decides what seeing means.

var facing := Vector2.DOWN
var vision := 170.0
var cone := deg_to_rad(80.0)
var chasing := false
var alert := 0.0  ## 0..1, drawn as the cone colour (suspicion of the surface)
var hp := 40.0  ## ground combat (combat.gd): shot down at 0
var max_hp := 40.0
var provoked := false  ## the player shot at this officer: draws a weapon whatever the heat
var armed := false  ## weapon drawn (high heat or provoked): shown as a gun in hand
var hostile_t := 0.0  ## seconds this officer still treats the player as a target
var fire_cd := 0.0
var drew := false  ## already announced the drawn weapon
var flash := 0.0  ## hit flash
var _last := Vector2.ZERO


func _ready() -> void:
	color = Color("#3a6fd0")
	look = "officer"
	_last = position


func _process(delta: float) -> void:
	super._process(delta)
	flash = maxf(0.0, flash - delta)
	var moved := position - _last
	if moved.length() > 0.05:
		facing = facing.lerp(moved.normalized(), clampf(10.0 * delta, 0.0, 1.0)).normalized()
	_last = position


## True if `target` is inside the cone in front of `from` and no blocker rect is in between.
static func sees(from: Vector2, look: Vector2, target: Vector2, reach: float, cone_rad: float, blockers: Array) -> bool:
	var to := target - from
	if to.length() > reach:
		return false
	if to.length() > 1.0 and absf(look.angle_to(to)) > cone_rad / 2.0:
		return false
	for i in range(1, 8):
		var p := from + to * (i / 8.0)
		for r in blockers:
			if r.has_point(p):
				return false
	return true


func _draw() -> void:
	var c := Color(0.4, 0.6, 1.0).lerp(Color(1.0, 0.3, 0.25), alert)
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 13:
		pts.append(facing.rotated(-cone / 2.0 + cone * i / 12.0) * vision)
	draw_colored_polygon(pts, Color(c, 0.12 + 0.18 * alert))
	draw_polyline(pts + PackedVector2Array([Vector2.ZERO]), Color(c, 0.35), 1.0)
	heading = facing
	super._draw()
	if Art.character("officer") == null:  # procedural cap and badge only without the sprite
		draw_rect(Rect2(-6, -18, 12, 4), Color("#1a2a55"))
		draw_circle(Vector2(0, -2), 2.0, Color("#ffd166"))
	if armed:
		draw_line(Vector2(0, -2), Vector2(0, -2) + facing * 15.0, Color("#1a1a22"), 3.0)
		draw_line(Vector2(0, -2) + facing * 9.0, Vector2(0, -2) + facing * 15.0, Color("#9aa0ad"), 2.0)
	if flash > 0.0:
		draw_circle(Vector2(0, -2), 11.0, Color(1, 1, 1, flash * 3.0))
	if hp < max_hp:
		draw_rect(Rect2(-10, -32, 20, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-10, -32, 20.0 * hp / max_hp, 3), Color("#ff6b5f"))
	if chasing:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-4, -24), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ff6b5f"))
