extends Node2D
## Pirate raider: closes in on the player, circles at its preferred distance and shoots forward bolts with some spread.
## Pure movement + fire timing; damage, bounty and bolts are handled by combat_layer.gd with the core rules.

const Art = preload("res://scripts/core/art.gd")

var cfg: Dictionary = {}
var hull := 0.0
var velocity := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var radius := 18.0
var flash := 0.0  ## hit flash timer
var _fire_cd := 1.0
var _strafe := 1.0
var _strafe_t := 2.0


func setup(pirate_cfg: Dictionary, pos: Vector2, seed_value: int) -> void:
	cfg = pirate_cfg
	hull = float(cfg.hull)
	radius = float(cfg.radius)
	position = pos
	rng.seed = seed_value
	_fire_cd = rng.randf_range(0.8, float(cfg.fire_cooldown))
	_strafe = 1.0 if rng.randf() < 0.5 else -1.0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## One step towards `player`. Returns the aim angle (radians, the direction a bolt flies) when it fires, else INF.
func step(delta: float, player: Vector2, player_vel: Vector2) -> float:
	flash = maxf(0.0, flash - delta)
	var to := player - position
	var dist := to.length()
	var orbit := float(cfg.orbit)
	var dir := to.normalized() if dist > 0.01 else Vector2.UP
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = rng.randf_range(1.5, 3.5)
		_strafe = -_strafe
	var want := Vector2.ZERO
	if dist < float(cfg.detect):
		var radial := clampf((dist - orbit) / 120.0, -1.0, 1.0)
		want = dir * radial + dir.orthogonal() * _strafe * 0.8
		want = want.normalized() * float(cfg.speed)
	velocity = velocity.lerp(want, clampf(1.6 * delta, 0.0, 1.0))
	position += velocity * delta
	# face the player (lead the shot a little)
	var lead := player + player_vel * clampf(dist / float(cfg.bolt_speed), 0.0, 1.0) * 0.5
	var aim := (lead - position).angle()
	var face := aim + PI / 2.0
	rotation = rotate_toward(rotation, face, float(cfg.turn) * delta)
	_fire_cd -= delta
	if _fire_cd <= 0.0 and dist < float(cfg.bolt_range) * 0.85 and absf(angle_difference(rotation, face)) < 0.25:
		_fire_cd = float(cfg.fire_cooldown) * rng.randf_range(0.85, 1.2)
		return rotation - PI / 2.0 + deg_to_rad(rng.randf_range(-1.0, 1.0) * float(cfg.spread_degrees))
	return INF


func hit(amount: float) -> bool:
	hull -= amount
	flash = 0.12
	return hull <= 0.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := Art.tex("ships/pirate.png")
	var tint := Color(1, 1, 1) if flash <= 0.0 else Color(2.5, 2.5, 2.5)
	if t != null:
		draw_texture(t, -t.get_size() / 2.0, tint)
	else:
		var body := PackedVector2Array([Vector2(0, -18), Vector2(11, 6), Vector2(16, 14), Vector2(0, 8), Vector2(-16, 14), Vector2(-11, 6)])
		draw_colored_polygon(body, Color("#b0382c") * tint)
		draw_polyline(body + PackedVector2Array([body[0]]), Color("#3a0e0a"), 2.0)
		draw_circle(Vector2(0, 0), 3.5, Color("#ffd166") * tint)
	if hull < float(cfg.hull):
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
		draw_rect(Rect2(-14, -radius - 12, 28, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-14, -radius - 12, 28.0 * clampf(hull / float(cfg.hull), 0.0, 1.0), 3), Color("#ff6b5f"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
