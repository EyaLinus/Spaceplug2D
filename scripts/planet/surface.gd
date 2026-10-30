extends Node2D
## One planet surface instance, built from data/surfaces.json: ground, roads, buildings with doors, the launch pad,
## NPCs and ambient walkers, plus the on-foot player and its camera. Created when the ship lands and freed on take-off.
## It only finds out what the player is standing next to; main.gd turns `interacted` into panels and core actions.

signal interacted(action: String, payload: Dictionary)

const WalkerScript = preload("res://scripts/planet/walker.gd")
const NpcScript = preload("res://scripts/planet/npc.gd")
const OfficerScript = preload("res://scripts/planet/officer.gd")

const INPUT := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E, KEY_ENTER],
}

var loc_id := ""
var cfg: Dictionary = {}
var tile := 32.0
var map_size := Vector2.ZERO  ## pixels
var player: CharacterBody2D
var camera: Camera2D
var interactables: Array = []  ## [{pos, stand, range, label, action, payload}]; stand = free spot in reach
var focus: Dictionary = {}  ## interactable in reach, {} if none
var npcs: Dictionary = {}  ## npc id -> node
var walkers: Array = []
var officers: Array = []
var suspicion := 0.0  ## 0..1 while an officer watches you carry product; 1 = busted
var _blockers: Array = []  ## building rects, block movement and sight
var _overlay: Node2D  ## redrawn every frame (focus ring); the ground below is drawn once
var _rng := RandomNumberGenerator.new()


static func register_input() -> void:
	for action in INPUT:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in INPUT[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func setup(id: String, surface_cfg: Dictionary) -> void:
	loc_id = id
	cfg = surface_cfg
	tile = float(cfg.get("tile", 32))
	map_size = Vector2(cfg.size[0], cfg.size[1]) * tile


func _ready() -> void:
	register_input()
	y_sort_enabled = true  # people walk in front of / behind each other by their y
	_rng.seed = hash(loc_id)
	_build_collision()
	_build_interactables()
	for n in cfg.get("npcs", []):
		var npc := NpcScript.new()
		npc.display_name = n.name
		npc.color = Color(n.get("color", "#8fb3ff"))
		npc.position = _px(n.pos)
		add_child(npc)
		npcs[n.id] = npc
	for i in int(cfg.get("walkers", 0)):
		var w := NpcScript.new()
		w.color = Color.from_hsv(_rng.randf(), 0.35, 0.75)
		w.speed = _rng.randf_range(40.0, 70.0)
		w.position = _random_road_point()
		w.pick_next = _walker_path
		add_child(w)
		walkers.append(w)
	player = WalkerScript.new()
	player.position = _px(cfg.spawn)
	add_child(player)
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_size.x)
	camera.limit_bottom = int(map_size.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.zoom = Vector2(1.5, 1.5)  # closer, RPG-like framing; the map is bigger than one screen on purpose
	player.add_child(camera)
	camera.make_current()
	_overlay = Node2D.new()
	_overlay.z_index = 1
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func _px(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[1])) * tile


func _rect(r: Array) -> Rect2:
	return Rect2(Vector2(r[0], r[1]) * tile, Vector2(r[2], r[3]) * tile)


# ---------------------------------------------------------------- building the level

func _build_collision() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	var solid: Array = []
	for b in cfg.buildings:
		solid.append(_rect(b.rect))
		_blockers.append(_rect(b.rect))
	var t := tile
	solid.append(Rect2(-t, -t, map_size.x + 2 * t, t))
	solid.append(Rect2(-t, map_size.y, map_size.x + 2 * t, t))
	solid.append(Rect2(-t, 0, t, map_size.y))
	solid.append(Rect2(map_size.x, 0, t, map_size.y))
	for r in solid:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		body.add_child(shape)
	if cfg.has("pad"):
		var ship := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = tile * 1.4
		ship.shape = circle
		ship.position = _px(cfg.pad.pos)
		body.add_child(ship)


func _build_interactables() -> void:
	for b in cfg.buildings:
		if not b.has("action"):
			continue
		var out := Vector2.DOWN if b.get("side", "bottom") == "bottom" else Vector2.UP
		var door := _px(b.door) + out * tile * 0.6
		interactables.append({"pos": door, "stand": door, "range": 40.0, "label": b.get("label", b.name),
			"action": b.action, "payload": {"id": b.id, "title": b.name}})
	for n in cfg.get("npcs", []):
		var label: String = n.get("label", "Talk to %s" % n.name)
		interactables.append({"pos": _px(n.pos), "stand": _px(n.pos) + Vector2(0, 26), "range": 44.0, "label": label, "action": n.action,
			"payload": {"id": n.id, "title": n.name, "contact": n.get("contact", "")}})
	if cfg.has("pad"):
		interactables.append({"pos": _px(cfg.pad.pos), "stand": _px(cfg.pad.pos) + Vector2(0, tile * 1.4 + 18),
			"range": float(cfg.pad.radius) * tile * 0.75, "label": cfg.pad.label,
			"action": "takeoff", "payload": {"id": "pad", "title": cfg.pad.label}})


## Ambient walkers stay on the first two roads (main street + cross street) and turn at their crossing.
func _random_road_point() -> Vector2:
	var r := _rect(cfg.roads[_rng.randi() % mini(2, cfg.roads.size())]).grow(-tile * 0.6)
	return Vector2(_rng.randf_range(r.position.x, r.end.x), _rng.randf_range(r.position.y, r.end.y))


func _walker_path(from: Vector2) -> Array:
	var target := _random_road_point()
	if cfg.roads.size() < 2:
		return [target]
	var a := _rect(cfg.roads[0])
	var b := _rect(cfg.roads[1])
	var same := (a.has_point(from) and a.has_point(target)) or (b.has_point(from) and b.has_point(target))
	if same:
		return [target]
	return [a.intersection(b).get_center(), target]


# ---------------------------------------------------------------- per frame

func _physics_process(delta: float) -> void:
	focus = {}
	_update_police(delta)
	if player.frozen:
		_overlay.queue_redraw()
		return
	var best := INF
	for it in interactables:
		var d: float = player.position.distance_to(it.pos)
		if d < float(it.range) and d < best:
			best = d
			focus = it
	_overlay.queue_redraw()


## Keeps the number of officers in line with heat, lets them watch the player and busts on a full frisk.
## Only runs while the player can move: panels (shops, deals) are indoors and safe.
func _update_police(delta: float) -> void:
	var g = GameState.game
	if g == null or GameState.paused:
		return
	var pc: Dictionary = GameState.data.police
	var want: int = g.police_on_foot(float(cfg.get("security", 1.0)))
	while officers.size() < want:
		var o := OfficerScript.new()
		o.vision = float(pc.vision)
		o.cone = deg_to_rad(float(pc.cone_degrees))
		o.speed = float(pc.speed)
		o.position = _random_road_point()
		o.pick_next = _walker_path
		add_child(o)
		officers.append(o)
	while officers.size() > want:
		officers.pop_back().queue_free()
	if player.frozen:
		return
	var watched := false
	var carrying: bool = g.has_contraband()
	for o in officers:
		var seen: bool = OfficerScript.sees(o.position, o.facing, player.position, o.vision, o.cone, _blockers)
		if seen and carrying:
			watched = true
		if o.chasing:
			if not carrying or o.position.distance_to(player.position) > float(pc.give_up_range):
				o.chasing = false
				o.speed = float(pc.speed)
				o.path = []
			else:
				o.path = [player.position]
				o.facing = (player.position - o.position).normalized()
		elif seen and carrying and g.heat >= float(pc.chase_heat):
			o.chasing = true
			o.speed = float(pc.chase_speed)
			EventBus.toast.emit("An officer spotted you. Lose them!", false)
	var old := suspicion
	if watched:
		suspicion += delta / float(pc.frisk_seconds)
		if int(old * 4.0) != int(suspicion * 4.0):
			AudioManager.play("alarm")
	else:
		suspicion = maxf(0.0, suspicion - delta * 0.5)
	if suspicion >= 1.0:
		suspicion = 0.0
		GameState.act(g.bust())
		for o in officers:
			o.chasing = false
			o.speed = float(pc.speed)
			o.path = []
	for o in officers:
		o.alert = suspicion
	if old != suspicion:
		EventBus.scan_progress.emit(suspicion)


## Text for the HUD prompt, "" when nothing is in reach.
func prompt() -> String:
	return "" if focus.is_empty() else "[E] %s" % focus.label


## Uses whatever the player stands next to. Returns false if nothing is in reach.
func interact() -> bool:
	if focus.is_empty():
		return false
	interacted.emit(focus.action, focus.payload)
	return true


## Moves the player next to an interactable (by payload id); used on landing and by tests.
func place_player_at(id: String) -> void:
	for it in interactables:
		if it.payload.id == id:
			player.position = it.stand
			camera.reset_smoothing()
			return


func interactable(id: String) -> Dictionary:
	for it in interactables:
		if it.payload.id == id:
			return it
	return {}


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var g1 := Color(cfg.get("ground", "#2b4538"))
	var g2 := Color(cfg.get("ground_alt", "#2f4b3d"))
	draw_rect(Rect2(Vector2.ZERO, map_size), g1)
	var n := RandomNumberGenerator.new()
	n.seed = hash(loc_id) + 7
	for y in int(cfg.size[1]):
		for x in int(cfg.size[0]):
			if (x + y) % 2 == 0:
				draw_rect(Rect2(x * tile, y * tile, tile, tile), g2)
			if n.randf() < 0.18:
				var p := Vector2(x + n.randf(), y + n.randf()) * tile
				draw_line(p, p + Vector2(n.randf_range(-2, 2), -5), g1.lightened(0.18), 1.5)
	var road := Color(cfg.get("road", "#45464f"))
	var line := Color(cfg.get("road_line", "#6b6c78"))
	for r in cfg.roads:
		var rr := _rect(r)
		draw_rect(rr.grow(3), road.darkened(0.25))
		draw_rect(rr, road)
	for r in cfg.roads:
		var rr := _rect(r)
		var horizontal := rr.size.x > rr.size.y
		var c := rr.get_center()
		var length := rr.size.x if horizontal else rr.size.y
		if length < tile * 6:
			continue
		var i := 0.0
		while i < length:
			var a := (Vector2(rr.position.x + i, c.y) if horizontal else Vector2(c.x, rr.position.y + i))
			var b := a + (Vector2(14, 0) if horizontal else Vector2(0, 14))
			draw_line(a, b, line, 2.0)
			i += 32.0
	for r in cfg.get("plazas", []):
		var pr := _rect(r)
		draw_rect(pr, Color("#5a5b63"))
		for y in int(r[3]):
			for x in int(r[2]):
				draw_rect(Rect2(pr.position + Vector2(x, y) * tile, Vector2(tile, tile)), Color("#6a6b74"), false, 1.0)
		draw_circle(pr.get_center(), tile * 1.3, Color("#3e7a8c"))
		draw_circle(pr.get_center(), tile * 1.0, Color("#5fb6c9"))
		draw_arc(pr.get_center(), tile * 1.3, 0, TAU, 32, Color("#8a8b94"), 4.0)
	if cfg.has("pad"):
		_draw_pad()
	for b in cfg.buildings:
		_draw_building(b)
	for p in cfg.get("props", []):
		_draw_prop(p[0], Vector2(float(p[1]), float(p[2])) * tile)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(tile * 0.5, map_size.y - tile * 0.4), cfg.get("name", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.35))


func _draw_pad() -> void:
	var c := _px(cfg.pad.pos)
	var r := float(cfg.pad.radius) * tile
	draw_circle(c, r, Color("#3c3f4a"))
	draw_arc(c, r, 0, TAU, 48, Color("#ffd166"), 3.0)
	draw_arc(c, r * 0.7, 0, TAU, 48, Color(1, 0.82, 0.4, 0.4), 2.0)
	for i in 8:
		var d := Vector2.RIGHT.rotated(i * TAU / 8.0)
		draw_circle(c + d * (r - 8), 3.0, Color("#4fe3c1"))
	# the parked ship, same silhouette as in flight but bigger
	var s := 2.6
	var hull := PackedVector2Array([Vector2(0, -20) * s + c, Vector2(13, 14) * s + c, Vector2(0, 8) * s + c, Vector2(-13, 14) * s + c])
	draw_colored_polygon(hull, Color("#ffd166"))
	draw_polyline(hull + PackedVector2Array([hull[0]]), Color("#7a4e00"), 3.0)
	draw_circle(c + Vector2(0, -4) * s, 4.0 * s, Color("#2b5f8a"))


func _draw_building(b: Dictionary) -> void:
	var r := _rect(b.rect)
	var wall := Color(b.get("wall", "#666666"))
	var roof := Color(b.get("roof", "#444444"))
	draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.3))
	# roof covers the top part, front wall shows at the bottom (classic top-down RPG perspective)
	var wall_h := minf(tile * 1.6, r.size.y * 0.4)
	var roof_r := Rect2(r.position, Vector2(r.size.x, r.size.y - wall_h))
	var wall_r := Rect2(Vector2(r.position.x, r.end.y - wall_h), Vector2(r.size.x, wall_h))
	draw_rect(wall_r, wall)
	draw_rect(roof_r, roof)
	for i in int(roof_r.size.y / 10.0):
		var y := roof_r.position.y + 6 + i * 10.0
		draw_line(Vector2(roof_r.position.x + 2, y), Vector2(roof_r.end.x - 2, y), roof.darkened(0.15), 1.0)
	draw_rect(roof_r, roof.lightened(0.15), false, 2.0)
	# windows along the front wall
	var wx := r.position.x + tile * 0.5
	while wx < r.end.x - tile * 0.8:
		draw_rect(Rect2(wx, wall_r.position.y + wall_h * 0.25, tile * 0.45, wall_h * 0.4), Color("#ffe8a3").darkened(0.15))
		wx += tile * 1.2
	draw_rect(r, wall.darkened(0.45), false, 2.0)
	if b.has("door"):
		var d := _px(b.door)
		var top: bool = b.get("side", "bottom") == "top"
		# top-side doors sit in the roof edge: draw a small porch so they read as entrances
		var door_r := Rect2(d.x - tile * 0.5, d.y - tile * 0.9, tile, tile * 0.9) if not top else Rect2(d.x - tile * 0.5, d.y, tile, tile * 0.6)
		if top:
			draw_rect(door_r.grow(4), wall.darkened(0.2))
		draw_rect(door_r, Color("#1f1a16"))
		draw_rect(door_r, Color("#ffd166"), false, 1.5)
	if b.has("sign"):
		var font := ThemeDB.fallback_font
		var text: String = b.sign
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var sp := Vector2(r.get_center().x - w / 2.0, roof_r.get_center().y + 6)
		draw_rect(Rect2(sp + Vector2(-8, -16), Vector2(w + 16, 22)), Color(0, 0, 0, 0.55))
		draw_string(font, sp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#4fe3c1"))


func _draw_prop(kind: String, p: Vector2) -> void:
	match kind:
		"tree":
			draw_circle(p + Vector2(4, 10), 14.0, Color(0, 0, 0, 0.25))
			draw_rect(Rect2(p + Vector2(-3, 0), Vector2(6, 12)), Color("#5a3d28"))
			draw_circle(p + Vector2(0, -6), 15.0, Color("#2f6b4a"))
			draw_circle(p + Vector2(-4, -10), 9.0, Color("#3f8a5e"))
		"lamp":
			draw_circle(p, 26.0, Color(1.0, 0.85, 0.5, 0.07))
			draw_line(p + Vector2(0, 10), p + Vector2(0, -14), Color("#2a2a30"), 3.0)
			draw_circle(p + Vector2(0, -15), 4.0, Color("#ffe8a3"))
		"crate":
			draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), Color("#8a6a3e"))
			draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), Color("#4e3a1e"), false, 2.0)
			draw_line(p - Vector2(9, 9), p + Vector2(9, 9), Color("#4e3a1e"), 1.5)
		"rock":
			draw_circle(p + Vector2(3, 6), 13.0, Color(0, 0, 0, 0.25))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-13, 6), p + Vector2(-8, -8), p + Vector2(4, -11),
				p + Vector2(13, -2), p + Vector2(10, 8)]), Color("#6b5446"))
			draw_line(p + Vector2(-8, -8), p + Vector2(0, 0), Color("#4e3c32"), 2.0)
		"barrel":
			draw_rect(Rect2(p - Vector2(7, 10), Vector2(14, 20)), Color("#8a3a2e"))
			draw_rect(Rect2(p - Vector2(7, 4), Vector2(14, 2)), Color("#3a2a24"))
			draw_rect(Rect2(p + Vector2(-7, 3), Vector2(14, 2)), Color("#3a2a24"))
			draw_circle(p - Vector2(0, 10), 7.0, Color("#a04a3a"))
		"vent":
			draw_rect(Rect2(p - Vector2(14, 14), Vector2(28, 28)), Color("#1e1b26"))
			for i in 5:
				draw_line(p + Vector2(-12, -10 + i * 5), p + Vector2(12, -10 + i * 5), Color("#4a4458"), 2.0)
			draw_rect(Rect2(p - Vector2(14, 14), Vector2(28, 28)), Color("#5a5468"), false, 1.5)
		"stall":
			draw_rect(Rect2(p - Vector2(22, 8), Vector2(44, 18)), Color("#6b4a2e"))
			for i in 4:
				draw_rect(Rect2(p + Vector2(-22 + i * 11, -18), Vector2(11, 10)), Color("#c84a3a") if i % 2 == 0 else Color("#f0e0c0"))
			draw_circle(p + Vector2(-10, 0), 4.0, Color("#7fffd4"))
			draw_circle(p + Vector2(4, 1), 4.0, Color("#ff9ad5"))


func _draw_overlay() -> void:
	if focus.is_empty():
		return
	var p: Vector2 = focus.pos
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	_overlay.draw_arc(p, 20.0 + pulse * 4.0, 0, TAU, 32, Color(0.31, 0.89, 0.76, 0.5 + pulse * 0.4), 2.0)
