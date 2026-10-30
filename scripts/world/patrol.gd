extends Node2D
## Reach Authority patrol: wanders near its beacon, chases the player when heat is high.
## Scanning is resolved by the World (it knows distances to all patrols). Hull sprite from the art registry.

const Art = preload("res://scripts/core/art.gd")

var home := Vector2.ZERO
var target := Vector2.ZERO
var velocity := Vector2.ZERO
var chasing := false
var cfg: Dictionary = {}
var rng := RandomNumberGenerator.new()
var scan_radius := 0.0  ## drawn as a faint circle so the player can read the danger zone


func setup(patrol_cfg: Dictionary, home_pos: Vector2, seed_value: int) -> void:
	cfg = patrol_cfg
	home = home_pos
	position = home_pos
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rng.seed = seed_value
	_pick_target()


## player: player ship position; chase: whether this patrol should pursue.
func step(delta: float, player: Vector2, chase: bool) -> void:
	chasing = chase
	var dest := player if chase else target
	var speed := float(cfg.chase_speed if chase else cfg.speed)
	var desired := (dest - position).normalized() * speed
	velocity = velocity.lerp(desired, clampf(2.0 * delta, 0.0, 1.0))
	position += velocity * delta
	if velocity.length() > 1.0:
		rotation = velocity.angle() + PI / 2.0
	if not chase and position.distance_to(target) < 80.0:
		_pick_target()
	queue_redraw()


func _pick_target() -> void:
	var r := float(cfg.get("wander_radius", 2000))
	# wander between the beacon and the middle of the sector, where trade routes cross
	var centre := home.lerp(Vector2.ZERO, rng.randf())
	target = centre + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * r * 0.5


func _draw() -> void:
	if scan_radius > 0.0:
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
		draw_circle(Vector2.ZERO, scan_radius, Color(0.3, 0.5, 1.0, 0.06 if not chasing else 0.1))
		draw_arc(Vector2.ZERO, scan_radius, 0, TAU, 48, Color(0.4, 0.6, 1.0, 0.35), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var t := Art.tex("ships/patrol.png")
	if t != null:
		draw_texture(t, -t.get_size() / 2.0)
	else:
		_draw_hull()
	var blink := 1.0 if fmod(Time.get_ticks_msec() / 250.0, 2.0) < 1.0 else 0.3
	draw_circle(Vector2(-6, 0), 3.0, Color(1, 0.2, 0.2, blink if chasing else 0.4))
	draw_circle(Vector2(6, 0), 3.0, Color(0.3, 0.5, 1, (1.3 - blink) if chasing else 0.4))


func _draw_hull() -> void:
	var body := PackedVector2Array([Vector2(0, -16), Vector2(10, 4), Vector2(16, 14), Vector2(0, 8), Vector2(-16, 14), Vector2(-10, 4)])
	draw_colored_polygon(body, Color("#3a6fd0"))
