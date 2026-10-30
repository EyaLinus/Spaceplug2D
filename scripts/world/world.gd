extends Node2D
## The sector: starfield, locations, player ship, patrols and camera.
## Owns the spatial rules (dock range, patrol scans) and turns them into core actions via GameState.

const ShipScript = preload("res://scripts/world/ship.gd")
const LocationScript = preload("res://scripts/world/location_body.gd")
const PatrolScript = preload("res://scripts/world/patrol.gd")

const SECTOR_HALF := 4200.0

var ship: Node2D
var camera: Camera2D
var locations: Dictionary = {}  ## id -> location node
var patrols: Array = []
var nearby: String = ""  ## dockable location in range, "" if none
var scan := 0.0  ## 0..1, busted at 1
var active := false  ## false while docked / in menus
var _stars: Array = []
var _patrol_seed := 1


func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 1234
	for i in 2600:
		var tint := Color(1, 1, 1).lerp(Color(0.6, 0.8, 1.0) if r.randf() < 0.5 else Color(1.0, 0.85, 0.6), r.randf() * 0.6)
		tint.a = r.randf_range(0.25, 0.9)
		_stars.append([Vector2(r.randf_range(-SECTOR_HALF, SECTOR_HALF), r.randf_range(-SECTOR_HALF, SECTOR_HALF)), r.randf_range(0.6, 2.2), tint])
	var data: Dictionary = GameState.data
	for id in data.locations:
		var n := LocationScript.new()
		n.setup(id, data.locations[id])
		add_child(n)
		locations[id] = n
	ship = ShipScript.new()
	ship.setup(data.ship)
	add_child(ship)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	ship.add_child(camera)


## Puts the ship next to the location the game says it is at (new game / load / undock).
func place_ship_at(loc_id: String) -> void:
	var n: Node2D = locations.get(loc_id)
	if n == null:
		return
	ship.position = n.position + Vector2(0, n.radius + 70.0)
	ship.rotation = PI  # nose away from the planet
	ship.stop()
	camera.reset_smoothing()


func clear_patrols() -> void:
	for p in patrols:
		p.queue_free()
	patrols.clear()
	scan = 0.0


func _physics_process(delta: float) -> void:
	var g = GameState.game
	if g == null:
		return
	ship.frozen = not active or GameState.paused
	ship.engine_mult = g.engine_mult()
	if GameState.paused:
		return
	_clamp_to_sector()
	_sync_patrols(g)
	if not active:
		return
	_update_nearby()
	_update_scan(g, delta)


func _clamp_to_sector() -> void:
	var lim := SECTOR_HALF - 200.0
	if absf(ship.position.x) > lim or absf(ship.position.y) > lim:
		ship.position = ship.position.clamp(Vector2(-lim, -lim), Vector2(lim, lim))
		ship.velocity *= -0.3


func _update_nearby() -> void:
	nearby = ""
	var range := float(GameState.data.ship.dock_range)
	for id in locations:
		var n: Node2D = locations[id]
		var can: bool = bool(n.info.get("dockable", true)) and ship.position.distance_to(n.position) < n.radius + range
		n.highlight = can
		if can:
			nearby = id


func _sync_patrols(g) -> void:
	var want: int = g.patrol_count()
	var home: Vector2 = locations["beacon"].position
	while patrols.size() < want:
		var p := PatrolScript.new()
		_patrol_seed += 1
		p.setup(GameState.data.patrol, home, _patrol_seed)
		add_child(p)
		patrols.append(p)
	while patrols.size() > want:
		patrols.pop_back().queue_free()
	var chase: bool = g.heat >= float(GameState.data.heat.chase_heat) and active
	var radius: float = g.scan_radius()
	for p in patrols:
		p.scan_radius = radius
		p.step(get_physics_process_delta_time(), ship.position, chase and p.position.distance_to(ship.position) < 1600.0)


func _update_scan(g, delta: float) -> void:
	var in_range := false
	var radius: float = g.scan_radius()
	for p in patrols:
		if p.position.distance_to(ship.position) < radius:
			in_range = true
			break
	var old := scan
	if in_range and g.has_contraband():
		scan += delta / float(GameState.data.heat.scan_seconds)
		if int(old * 4.0) != int(scan * 4.0):
			AudioManager.play("alarm")
	else:
		scan = maxf(0.0, scan - delta * 0.5)
	if scan >= 1.0:
		scan = 0.0
		GameState.act(g.bust())
		# shove the ship away so the next scan does not start immediately
		ship.velocity = (ship.position - locations["beacon"].position).normalized() * 300.0
	if old != scan:
		EventBus.scan_progress.emit(scan)


func _draw() -> void:
	for s in _stars:
		draw_circle(s[0], s[1], s[2])
	# faint nebulae for depth
	draw_circle(Vector2(-1800, -1600), 900.0, Color(0.35, 0.15, 0.5, 0.06))
	draw_circle(Vector2(2200, 1200), 1100.0, Color(0.1, 0.35, 0.4, 0.05))
	draw_rect(Rect2(-SECTOR_HALF, -SECTOR_HALF, SECTOR_HALF * 2, SECTOR_HALF * 2), Color(0.3, 0.6, 1.0, 0.25), false, 4.0)
