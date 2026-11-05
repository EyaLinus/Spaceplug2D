extends Node2D
## Player ship: inertial top-down flight (rotate + thrust + brake). Hull sprite plus one visible module per bought
## upgrade from the art registry (procedural fallback), engine flames procedural (one per nozzle of the engine level).

const Art = preload("res://scripts/core/art.gd")
const SpaceCombat = preload("res://scripts/core/spacecombat.gd")
const Steering = preload("res://scripts/core/steering.gd")

var velocity := Vector2.ZERO
var thrusting := false
var frozen := false  ## true while docked or paused
var engine_mult := 1.0
var modules: Dictionary = {}  ## upgrade key -> level (Game.upgrades); picks the module sprites and nozzles
var cfg: Dictionary = {}
var paint: Dictionary = {}  ## K2: hull palette swaps from Style.hull_swaps
var decal := ""  ## K2: decal id (content.json style.decal)
var hull_cfg: Dictionary = {}  ## hull class (content.json "ship_classes"): drawn size and paint stripe

var autopilot := false  ## K3: fly to the quest waypoint on its own until you touch the controls or arrive
var goal_provider: Callable  ## returns the waypoint (Vector2) or null; set by main (HUD quest point)
var hazard_provider: Callable  ## returns [{pos: Vector2, r: float}] to steer around (bodies, patrol scan zones); set by main
const AUTOPILOT_ARRIVE := 260.0
const AUTOPILOT_LOOKAHEAD := 900.0
var _flame := 0.0
var _boost_t := 0.0  ## seconds of dodge boost left
var _invuln_t := 0.0  ## seconds of dodge invulnerability left
var _boost_dir := Vector2.ZERO


func setup(ship_cfg: Dictionary) -> void:
	cfg = ship_cfg
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _physics_process(delta: float) -> void:
	_boost_t = maxf(0.0, _boost_t - delta)
	_invuln_t = maxf(0.0, _invuln_t - delta)
	modulate.a = 0.55 + 0.3 * sin(Time.get_ticks_msec() / 25.0) if _invuln_t > 0.0 else 1.0
	if frozen or cfg.is_empty():
		thrusting = false
		AudioManager.set_thrust(0.0)
		queue_redraw()
		return
	var turn := Input.get_axis("ship_left", "ship_right")
	thrusting = Input.is_action_pressed("ship_thrust")
	var reversing := Input.is_action_pressed("ship_reverse")
	var braking := Input.is_action_pressed("ship_brake")
	if InputMap.has_action("ship_autopilot") and Input.is_action_just_pressed("ship_autopilot"):
		set_autopilot(not autopilot)
	if autopilot and (turn != 0.0 or thrusting or reversing or braking):
		set_autopilot(false, "Autopilot off: manual control.")
	if autopilot:
		var ap := autopilot_step(delta)
		turn = ap.turn
		thrusting = ap.thrust
		braking = ap.brake
	rotation += turn * float(cfg.turn_speed) * delta
	if Input.is_action_just_pressed("ship_boost"):
		boost(reversing and not thrusting)
	steer(delta, thrusting, braking, reversing)
	AudioManager.set_thrust(1.0 if thrusting else (0.5 if reversing else 0.0))
	_flame = lerpf(_flame, 1.0 if thrusting else 0.0, 12.0 * delta)
	queue_redraw()


func set_autopilot(on: bool, why := "") -> void:
	if on:
		var goal = goal_provider.call() if goal_provider.is_valid() else null
		if goal == null:
			EventBus.toast.emit("Autopilot: no waypoint. Track a quest with a place to go.", false)
			return
	if on == autopilot:
		return
	autopilot = on
	EventBus.toast.emit("Autopilot on: flying to the waypoint. Any flight key takes over." if on else (why if why != "" else "Autopilot off."), true)


## One autopilot decision towards the waypoint: {turn -1..1, thrust, brake}. Arriving switches it off.
func autopilot_step(_delta: float) -> Dictionary:
	var goal = goal_provider.call() if goal_provider.is_valid() else null
	if goal == null:
		set_autopilot(false, "Autopilot off: the waypoint is gone.")
		return {"turn": 0.0, "thrust": false, "brake": false}
	var to: Vector2 = (goal as Vector2) - position
	var dist := to.length()
	if dist < AUTOPILOT_ARRIVE:
		set_autopilot(false, "Autopilot: arrived.")
		return {"turn": 0.0, "thrust": false, "brake": true}
	var hazards: Array = hazard_provider.call() if hazard_provider.is_valid() else []
	var heading := Steering.avoid_heading(position, goal as Vector2, hazards, AUTOPILOT_LOOKAHEAD + velocity.length() * 0.5)
	var want := heading.angle() + PI / 2.0  # the nose points up (−y)
	var diff := wrapf(want - rotation, -PI, PI)
	var turn := clampf(diff * 3.0, -1.0, 1.0)
	var speed := velocity.length()
	var stop_dist := speed * speed / maxf(1.0, 2.0 * float(cfg.thrust) * engine_mult) + 160.0
	var brake := dist < stop_dist and speed > 120.0
	var thrust := absf(diff) < 0.35 and not brake
	return {"turn": turn, "thrust": thrust, "brake": brake}


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
	if _boost_t > 0.0:
		velocity = _boost_dir * _boost_speed()
	elif velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	position += velocity * delta


## Dodge boost: a short burst along the nose (or backwards) that also makes the ship untouchable for a moment.
## Costs boost energy (core rules); returns false while docked, frozen or out of energy.
func boost(backwards := false) -> bool:
	var g = GameState.game
	if g == null or frozen or _boost_t > 0.0 or not SpaceCombat.try_boost(g):
		return false
	var b: Dictionary = g.data.space_combat.boost
	_boost_t = float(b.seconds)
	_invuln_t = float(b.invuln)
	_boost_dir = Vector2.UP.rotated(rotation) * (-1.0 if backwards else 1.0)
	AudioManager.play("boost")
	return true


func boosting() -> bool:
	return _boost_t > 0.0


func invulnerable() -> bool:
	return _invuln_t > 0.0


func _boost_speed() -> float:
	var g = GameState.game
	return float(g.data.space_combat.boost.speed) * (0.8 + 0.2 * engine_mult) if g != null else 0.0


func stop() -> void:
	_boost_t = 0.0
	_invuln_t = 0.0
	velocity = Vector2.ZERO


func _draw() -> void:
	var sc := float(hull_cfg.get("scale", 1.0))
	if not is_equal_approx(sc, 1.0):
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
	if _flame > 0.05:
		var lvl := int(modules.get("engine", 0))
		# upgraded engines burn hotter: ion-teal core instead of yellow
		var core := Color(1.0, 0.95, 0.6, 0.9).lerp(Color(0.6, 1.0, 0.95, 0.95), lvl / 3.0)
		for n in Art.ship_nozzles(lvl):
			var o: Vector2 = n[0]
			var w: float = 6.0 * float(n[1])
			var f := (18.0 + 14.0 * _flame + randf() * 6.0) * float(n[1])
			draw_colored_polygon(PackedVector2Array([o + Vector2(-w, 0), o + Vector2(w, 0), o + Vector2(0, f)]), Color(1.0, 0.6, 0.2, 0.85))
			draw_colored_polygon(PackedVector2Array([o + Vector2(-w / 2, 0), o + Vector2(w / 2, 0), o + Vector2(0, f * 0.6)]), core)
	if Art.draw_ship(self, modules, Vector2.ZERO, paint, decal):
		var stripe := str(hull_cfg.get("stripe", ""))
		if stripe != "":  # class paint: two wing stripes
			var c := Color(stripe)
			draw_line(Vector2(-14, 6), Vector2(-6, 2), c, 2.0)
			draw_line(Vector2(14, 6), Vector2(6, 2), c, 2.0)
		return
	var hull := PackedVector2Array([Vector2(0, -20), Vector2(13, 14), Vector2(0, 8), Vector2(-13, 14)])
	draw_colored_polygon(hull, Color("#ffd166"))
	draw_polyline(hull + PackedVector2Array([hull[0]]), Color("#7a4e00"), 2.0)
	draw_circle(Vector2(0, -4), 4.0, Color("#2b5f8a"))
