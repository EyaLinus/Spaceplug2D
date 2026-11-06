extends Node2D
## The current star system: starfield, its locations, player ship, patrols and camera.
## Only one system is built at a time; show_system() swaps it after a jump or a load.
## Owns the spatial rules (dock range, patrol scans) and turns them into core actions via GameState.

const ShipScript = preload("res://scripts/world/ship.gd")
const LocationScript = preload("res://scripts/world/location_body.gd")
const PatrolScript = preload("res://scripts/world/patrol.gd")
const CombatLayerScript = preload("res://scripts/world/combat_layer.gd")
const CombatHudScript = preload("res://scripts/ui/combat_hud.gd")
const SpaceCombat = preload("res://scripts/core/spacecombat.gd")
const Style = preload("res://scripts/core/style.gd")
const Escort = preload("res://scripts/core/escort.gd")
const FreighterScript = preload("res://scripts/world/freighter.gd")
const PatrolFeel = preload("res://scripts/core/patrolfeel.gd")

const SECTOR_HALF := 4200.0

var ship: Node2D
var camera: Camera2D
var combat: Node2D  ## pirates, bolts, missiles (combat_layer.gd)
var combat_hud: CanvasLayer  ## hull / shield / boost / missile bars, visible while flying
var system: String = ""  ## star system currently built
var locations: Dictionary = {}  ## id -> location node (current system only)
var patrols: Array = []
var freighter: Node2D  ## the escort mission's freighter while one is flying in this system, else null
var nearby: String = ""  ## dockable location in range, "" if none
var scan := 0.0  ## 0..1, busted at 1
var active := false  ## false while docked / in menus
var shake := 0.0  ## K1: extra camera shake from EventBus.shake (busts, interdictions), decays fast
var input_blocked := false  ## the ship holds position (no steering) while the phone is open
var _stars: Array = []
var _nebulae: Array = []  ## [pos, radius, colour]
var _patrol_seed := 1
var fields: Array = []  ## asteroid fields of this system (patrolfeel.gd): smaller scan range, break pursuit
var _rocks: Array = []  ## [pos, radius, tint] drawn inside the fields
var _warn := {}  ## patrolfeel.gd warn_tick state
var _hunted := false  ## a patrol was chasing last frame (to announce a lost lock once)


func _ready() -> void:
	var data: Dictionary = GameState.data
	ship = ShipScript.new()
	ship.setup(data.ship)
	add_child(ship)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	ship.add_child(camera)
	combat = CombatLayerScript.new()
	combat.setup(self, ship)
	add_child(combat)
	combat_hud = CombatHudScript.new()
	combat_hud.setup(combat)
	add_child(combat_hud)
	EventBus.shake.connect(func(st: float): if active: shake = maxf(shake, st))
	var first: String = data.systems.keys()[0] if data.has("systems") else ""
	show_system(first)


## Builds the starfield and locations of `sys` (no-op if it is already shown). Patrols are dropped.
func show_system(sys: String) -> void:
	if sys == system and not locations.is_empty():
		return
	system = sys
	clear_patrols()
	_drop_freighter()
	for id in locations:
		locations[id].queue_free()
	locations.clear()
	var data: Dictionary = GameState.data
	var info: Dictionary = data.get("systems", {}).get(sys, {})
	var r := RandomNumberGenerator.new()
	r.seed = hash(sys) if sys != "" else 1234
	var star := Color(info.get("star", "#ffd9a0"))
	_stars.clear()
	for i in 2600:
		var tint := Color(1, 1, 1).lerp(Color(0.6, 0.8, 1.0) if r.randf() < 0.5 else star, r.randf() * 0.6)
		tint.a = r.randf_range(0.25, 0.9)
		_stars.append([Vector2(r.randf_range(-SECTOR_HALF, SECTOR_HALF), r.randf_range(-SECTOR_HALF, SECTOR_HALF)), r.randf_range(0.6, 2.2), tint])
	_nebulae.clear()
	for c in info.get("nebula", ["#5a2680", "#1a5a66"]):
		_nebulae.append([Vector2(r.randf_range(-2400, 2400), r.randf_range(-2000, 2000)), r.randf_range(800, 1200), Color(c, 0.05)])
	for id in data.locations:
		var ld: Dictionary = data.locations[id]
		if str(ld.get("system", sys)) != sys:
			continue
		var n := LocationScript.new()
		n.setup(id, ld)
		add_child(n)
		move_child(n, 0)
		locations[id] = n
	fields = PatrolFeel.fields(data, sys)
	_rocks.clear()
	for f in fields:
		for i in int(float(f.radius) / 6.0):
			var a := r.randf() * TAU
			var d := sqrt(r.randf()) * float(f.radius)
			_rocks.append([f.pos + Vector2.from_angle(a) * d, r.randf_range(4.0, 16.0), Color(0.45, 0.4, 0.36).lerp(Color(0.7, 0.6, 0.5), r.randf()) * Color(1, 1, 1, 0.8)])
	queue_redraw()


## Puts the ship next to the location the game says it is at (new game / load / undock).
func place_ship_at(loc_id: String) -> void:
	if GameState.game != null:
		show_system(GameState.game.loc_system(loc_id))
	var n: Node2D = locations.get(loc_id)
	if n == null:
		return
	ship.position = n.position + Vector2(0, n.radius + 70.0)
	ship.rotation = PI  # nose away from the planet
	ship.stop()
	camera.reset_smoothing()


func clear_patrols() -> void:
	if combat != null:
		combat.clear()
	for p in patrols:
		p.queue_free()
	patrols.clear()
	scan = 0.0


func _physics_process(delta: float) -> void:
	var g = GameState.game
	if g == null:
		return
	ship.frozen = not active or GameState.paused or input_blocked
	ship.engine_mult = g.engine_mult()
	ship.modules = g.upgrades
	ship.paint = Style.hull_swaps(g.data, g.style)
	ship.decal = str(g.style.get("decal", ""))
	ship.hull_cfg = SpaceCombat.ship_class(g)
	if GameState.paused:
		return
	combat_hud.visible = active and not GameState.paused
	_clamp_to_sector()
	_sync_patrols(g)
	if not active:
		combat.clear()
		_drop_freighter()
		return
	_sync_escort(g, delta)
	_update_nearby()
	_update_scan(g, delta)
	combat.step(delta, g)
	shake = maxf(0.0, shake - delta * 18.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * maxf(combat.shake, shake) * Settings.screen_shake


## Escort mission: moves the core freighter and mirrors it as a node while it is flying in this system.
func _sync_escort(g, delta: float) -> void:
	if not Escort.active(g) or g.location != "" or g.system != str(Escort.job(g).sys) or g.system != system:
		_drop_freighter()
		return
	Escort.step(g, delta, ship.position)
	if not Escort.active(g):  # it just arrived
		_drop_freighter()
		return
	if freighter == null:
		freighter = FreighterScript.new()
		add_child(freighter)
	freighter.sync(g)


func _drop_freighter() -> void:
	if freighter != null:
		freighter.queue_free()
		freighter = null


## Distance from the ship to the edge of the nearest location (INF if the system has none).
func nearest_location_distance() -> float:
	var best := INF
	for id in locations:
		var n: Node2D = locations[id]
		best = minf(best, ship.position.distance_to(n.position) - n.radius)
	return best


## The wreck is towed back to the system's patrol base (the core already applied the loot and fine).
func respawn_after_wreck() -> void:
	clear_patrols()
	place_ship_at(GameState.game.patrol_home(system))
	ship.position += Vector2(0, 120)


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
		var can: bool = (bool(n.info.get("dockable", true)) or n.info.has("jump_to")) and ship.position.distance_to(n.position) < n.radius + range
		n.highlight = can
		if can:
			nearby = id


func _sync_patrols(g) -> void:
	var want: int = g.patrol_count()
	var home: Vector2 = _patrol_home(g)
	while patrols.size() < want:
		var p := PatrolScript.new()
		_patrol_seed += 1
		p.setup(GameState.data.patrol, home, _patrol_seed)
		add_child(p)
		patrols.append(p)
	while patrols.size() > want:
		patrols.pop_back().queue_free()
	var chase: bool = g.heat >= float(GameState.data.heat.chase_heat) and active
	var radius: float = PatrolFeel.scan_radius_at(GameState.data, g.scan_radius(), fields, ship.position)
	var lost: bool = PatrolFeel.breaks_pursuit(GameState.data, fields, ship.position)
	var hunting := false
	for p in patrols:
		p.scan_radius = radius
		var near: bool = p.position.distance_to(ship.position) < 1600.0
		p.step(get_physics_process_delta_time(), ship.position, chase and near and not lost)
		hunting = hunting or p.chasing
	if _hunted and not hunting and chase and lost:
		AudioManager.play("sell")
		EventBus.game_event.emit("pursuit_lost", {})
	_hunted = hunting


func _patrol_home(g) -> Vector2:
	var n: Node2D = locations.get(g.patrol_home(system))
	return n.position if n != null else Vector2.ZERO


func _update_scan(g, delta: float) -> void:
	var in_range := false
	var radius: float = PatrolFeel.scan_radius_at(GameState.data, g.scan_radius(), fields, ship.position)
	var nearest := INF
	for p in patrols:
		var d: float = p.position.distance_to(ship.position)
		nearest = minf(nearest, d)
		if d < radius:
			in_range = true
	# warning before the scan range: only worth it while there is something to find
	var lvl: int = PatrolFeel.warn_level(GameState.data, nearest, radius) if g.has_contraband() else PatrolFeel.CLEAR
	if PatrolFeel.warn_tick(GameState.data, _warn, lvl, delta):
		EventBus.game_event.emit("patrol_warning", {"distance": nearest, "radius": radius})
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
		ship.velocity = (ship.position - _patrol_home(g)).normalized() * 300.0
	if old != scan:
		EventBus.scan_progress.emit(scan)


func _draw() -> void:
	for s in _stars:
		draw_circle(s[0], s[1], s[2])
	for f in fields:
		draw_circle(f.pos, f.radius, Color(0.5, 0.42, 0.34, 0.06))
		draw_arc(f.pos, f.radius, 0, TAU, 64, Color(0.7, 0.6, 0.45, 0.2), 2.0)
	for rk in _rocks:
		draw_circle(rk[0], rk[1], rk[2])
	# faint nebulae for depth, tinted per system
	for nb in _nebulae:
		draw_circle(nb[0], nb[1], nb[2])
	draw_rect(Rect2(-SECTOR_HALF, -SECTOR_HALF, SECTOR_HALF * 2, SECTOR_HALF * 2), Color(0.3, 0.6, 1.0, 0.25), false, 4.0)
