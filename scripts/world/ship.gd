extends Node2D
## Player ship: inertial top-down flight (rotate + thrust + brake). Hull sprite from the art registry
## (procedural fallback), engine flame procedural.

const Art = preload("res://scripts/core/art.gd")

var velocity := Vector2.ZERO
var thrusting := false
var frozen := false  ## true while docked or paused
var engine_mult := 1.0
var cfg: Dictionary = {}

var _flame := 0.0


func setup(ship_cfg: Dictionary) -> void:
	cfg = ship_cfg
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _physics_process(delta: float) -> void:
	if frozen or cfg.is_empty():
		thrusting = false
		AudioManager.set_thrust(0.0)
		queue_redraw()
		return
	var turn := Input.get_axis("ship_left", "ship_right")
	rotation += turn * float(cfg.turn_speed) * delta
	thrusting = Input.is_action_pressed("ship_thrust")
	var reversing := Input.is_action_pressed("ship_reverse")
	steer(delta, thrusting, Input.is_action_pressed("ship_brake"), reversing)
	AudioManager.set_thrust(1.0 if thrusting else (0.5 if reversing else 0.0))
	_flame = lerpf(_flame, 1.0 if thrusting else 0.0, 12.0 * delta)
	queue_redraw()


## Integrates one step; split out so the UI smoke test can fly without key input.
func steer(delta: float, thrust: bool, brake: bool, reverse := false) -> void:
	var forward := Vector2.UP.rotated(rotation)
	if thrust:
		velocity += forward * float(cfg.thrust) * engine_mult * delta
	if reverse:
		velocity -= forward * float(cfg.thrust) * float(cfg.get("reverse_ratio", 0.5)) * engine_mult * delta
	if brake:
		velocity = velocity.lerp(Vector2.ZERO, clampf(float(cfg.brake) * delta, 0.0, 1.0))
	velocity *= 1.0 - float(cfg.drag) * 0.1 * delta
	var max_speed := float(cfg.max_speed) * engine_mult
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	position += velocity * delta


func stop() -> void:
	velocity = Vector2.ZERO


func _draw() -> void:
	if _flame > 0.05:
		var f := 18.0 + 14.0 * _flame + randf() * 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(-6, 12), Vector2(6, 12), Vector2(0, 12 + f)]), Color(1.0, 0.6, 0.2, 0.85))
		draw_colored_polygon(PackedVector2Array([Vector2(-3, 12), Vector2(3, 12), Vector2(0, 12 + f * 0.6)]), Color(1.0, 0.95, 0.6, 0.9))
	var t := Art.tex("ships/ship.png")
	if t != null:
		draw_texture(t, -t.get_size() / 2.0)
		return
	var hull := PackedVector2Array([Vector2(0, -20), Vector2(13, 14), Vector2(0, 8), Vector2(-13, 14)])
	draw_colored_polygon(hull, Color("#ffd166"))
	draw_polyline(hull + PackedVector2Array([hull[0]]), Color("#7a4e00"), 2.0)
	draw_circle(Vector2(0, -4), 4.0, Color("#2b5f8a"))
