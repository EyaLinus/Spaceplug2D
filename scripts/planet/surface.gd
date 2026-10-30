extends Node2D
## One planet surface instance, built from data/surfaces.json: ground, roads, buildings with doors, the launch pad,
## NPCs and ambient walkers, plus the on-foot player and its camera. Created when the ship lands and freed on take-off.
## It only finds out what the player is standing next to; main.gd turns `interacted` into panels and core actions.

signal interacted(action: String, payload: Dictionary)

const WalkerScript = preload("res://scripts/planet/walker.gd")
const NpcScript = preload("res://scripts/planet/npc.gd")
const OfficerScript = preload("res://scripts/planet/officer.gd")
const Art = preload("res://scripts/core/art.gd")
const Nav = preload("res://scripts/planet/nav.gd")

const INPUT := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E, KEY_ENTER],
	"build_menu": [KEY_B],
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
var nav: AStarGrid2D  ## tile grid with buildings solid; chasing officers path around houses
var _repath := 0.0
var _overlay: Node2D  ## redrawn every frame (focus ring); the ground below is drawn once
var _rng := RandomNumberGenerator.new()
## Estate interiors (cfg has "estate"): while `placing` holds a station id, a ghost of it sits on the cells in front
## of the player and E asks main to place it there. can_place(station, x, y) -> bool is set by main.
var placing := ""
var can_place: Callable


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


func _contact_look(id: String) -> String:
	for c in GameState.data.get("contacts", []):
		if c.id == id:
			return c.get("look", "")
	return ""


func _ready() -> void:
	register_input()
	y_sort_enabled = true  # people walk in front of / behind each other by their y
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art; children inherit it
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # tinted roof/wall pieces are tiled
	_rng.seed = hash(loc_id)
	EventBus.game_event.connect(func(kind: String, _p: Dictionary):
		if kind == "upgraded":
			queue_redraw())  # the parked ship shows its new module
	_build_collision()
	nav = Nav.build(cfg)
	_build_interactables()
	for n in cfg.get("npcs", []):
		var npc := NpcScript.new()
		npc.display_name = n.name
		npc.color = Color(n.get("color", "#8fb3ff"))
		if n.get("contact", "") != "":  # named people wear the look from their profile
			npc.look = _contact_look(n.contact)
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
	var z := float(cfg.get("zoom", 1.5))  # closer, RPG-like framing; planets are bigger than one screen on purpose
	camera.zoom = Vector2(z, z)
	# rooms smaller than the screen: centre them instead of pinning them to the top-left corner
	var view := get_viewport_rect().size / z
	if map_size.x < view.x:
		camera.limit_left = int(map_size.x / 2.0 - view.x / 2.0)
		camera.limit_right = int(map_size.x / 2.0 + view.x / 2.0)
	if map_size.y < view.y:
		camera.limit_top = int(map_size.y / 2.0 - view.y / 2.0)
		camera.limit_bottom = int(map_size.y / 2.0 + view.y / 2.0)
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
	for x in cfg.get("exits", []):
		interactables.append({"pos": _px(x.pos), "stand": _px(x.pos) + Vector2(0, -12), "range": 40.0, "label": x.label,
			"action": x.action, "payload": {"id": x.id, "title": x.label}})
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
	if not a.has_point(from) and not b.has_point(from):
		# off the roads (an officer after a chase): walk back around the buildings
		return Nav.path_between(nav, tile, from, target)
	var same := (a.has_point(from) and a.has_point(target)) or (b.has_point(from) and b.has_point(target))
	if same:
		return [target]
	return [a.intersection(b).get_center(), target]


# ---------------------------------------------------------------- per frame

func _physics_process(delta: float) -> void:
	focus = {}
	_update_police(delta)
	if player.frozen or placing != "":
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
				_repath -= delta
				if _repath <= 0.0 or o.path.is_empty():
					o.path = Nav.path_between(nav, tile, o.position, player.position)
				o.facing = (o.path[0] - o.position).normalized() if not o.path.is_empty() else o.facing
		elif seen and carrying and g.heat >= float(pc.chase_heat):
			o.chasing = true
			o.speed = float(pc.chase_speed)
			EventBus.toast.emit("An officer spotted you. Lose them!", false)
	if _repath <= 0.0:
		_repath = 0.35
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
	if placing != "":
		return "[%s] Place %s   [Esc] cancel" % [Settings.key_label("interact"), GameState.data.stations[placing].name]
	return "" if focus.is_empty() else "[%s] %s" % [Settings.key_label("interact"), focus.label]


## Uses whatever the player stands next to. Returns false if nothing is in reach.
func interact() -> bool:
	if placing != "":
		var c := ghost_cell()
		interacted.emit("place", {"station": placing, "x": c.x, "y": c.y, "id": "place", "title": ""})
		return true
	if focus.is_empty():
		return false
	interacted.emit(focus.action, focus.payload)
	return true


## Moves the player next to an interactable (by payload id); used on landing and by tests.
## Estate cell (top-left) the placement ghost covers: the cells just in front of the player.
func ghost_cell() -> Vector2i:
	var size: Array = GameState.data.buildables[placing].size
	var off := int(cfg.get("estate_offset", 0))
	var f: Vector2 = player.facing
	var step := Vector2i(roundi(f.x), roundi(f.y)) if absf(f.x) > 0.4 or absf(f.y) > 0.4 else Vector2i(0, 1)
	var feet := Vector2i(((player.position + Vector2(0, 4)) / tile).floor()) - Vector2i(off, off)
	var c := feet + step
	if step.x < 0:
		c.x -= int(size[0]) - 1
	if step.y < 0:
		c.y -= int(size[1]) - 1
	if step.x == 0:
		c.x -= (int(size[0]) - 1) / 2
	if step.y == 0:
		c.y -= (int(size[1]) - 1) / 2
	return c


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
	var tiles: String = Art.TILESETS.get(loc_id, "")
	var art := tiles != "" and Art.tex("tiles/%s_ground.png" % tiles) != null
	if art:
		Art.fill_tiles(self, "tiles/%s_ground.png" % tiles, Rect2(Vector2.ZERO, map_size), 1)
	else:
		_draw_ground_fallback()
	var road := Color(cfg.get("road", "#45464f"))
	var line := Color(cfg.get("road_line", "#6b6c78"))
	for r in cfg.roads:
		var rr := _rect(r)
		draw_rect(rr.grow(3), road.darkened(0.25))
		if not (art and Art.fill_tiles(self, "tiles/%s_road.png" % tiles, rr, 2)):
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
		if not (art and Art.fill_tiles(self, "tiles/%s_plaza.png" % tiles, pr, 3)):
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


func _draw_ground_fallback() -> void:
	var g1 := Color(cfg.get("ground", "#2b4538"))
	var g2 := Color(cfg.get("ground_alt", "#2f4b3d"))
	draw_rect(Rect2(Vector2.ZERO, map_size), g1)
	var n := RandomNumberGenerator.new()
	n.seed = hash(loc_id) + 7
	for y in int(cfg.size[1]):
		for x in int(cfg.size[0]):
			if (x + y) % 2 == 0:
				draw_rect(Rect2(x * tile, y * tile, tile, tile), g2)
			if n.randf() < 0.18 and cfg.get("grass", true):
				var p := Vector2(x + n.randf(), y + n.randf()) * tile
				draw_line(p, p + Vector2(n.randf_range(-2, 2), -5), g1.lightened(0.18), 1.5)


func _draw_pad() -> void:
	var c := _px(cfg.pad.pos)
	var r := float(cfg.pad.radius) * tile
	draw_circle(c, r, Color("#3c3f4a"))
	draw_arc(c, r, 0, TAU, 48, Color("#ffd166"), 3.0)
	draw_arc(c, r * 0.7, 0, TAU, 48, Color(1, 0.82, 0.4, 0.4), 2.0)
	for i in 8:
		var d := Vector2.RIGHT.rotated(i * TAU / 8.0)
		draw_circle(c + d * (r - 8), 3.0, Color("#4fe3c1"))
	# the parked ship, same sprite and upgrade modules as in flight but bigger
	draw_set_transform(c, 0.0, Vector2(2.5, 2.5))
	var drawn := Art.draw_ship(self, GameState.game.upgrades if GameState.game != null else {})
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if drawn:
		return
	var s := 2.6
	var hull := PackedVector2Array([Vector2(0, -20) * s + c, Vector2(13, 14) * s + c, Vector2(0, 8) * s + c, Vector2(-13, 14) * s + c])
	draw_colored_polygon(hull, Color("#ffd166"))
	draw_polyline(hull + PackedVector2Array([hull[0]]), Color("#7a4e00"), 3.0)
	draw_circle(c + Vector2(0, -4) * s, 4.0 * s, Color("#2b5f8a"))


func _draw_building(b: Dictionary) -> void:
	var r := _rect(b.rect)
	match b.get("style", ""):
		"wall":
			draw_rect(r, Color(b.wall))
			draw_rect(r, Color(b.wall).lightened(0.15), false, 2.0)
			return
		"machine":
			_draw_machine(b, r)
			return
	var wall := Color(b.get("wall", "#666666"))
	var roof := Color(b.get("roof", "#444444"))
	draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.3))
	# roof covers the top part, front wall shows at the bottom (classic top-down RPG perspective)
	var wall_h := minf(tile * 1.6, r.size.y * 0.4)
	var roof_r := Rect2(r.position, Vector2(r.size.x, r.size.y - wall_h))
	var wall_r := Rect2(Vector2(r.position.x, r.end.y - wall_h), Vector2(r.size.x, wall_h))
	# art: neutral roof/wall pieces tiled and tinted with the building's colours, so any building gets art
	var roof_t := Art.tex("buildings/roof.png")
	var wall_t := Art.tex("buildings/wall.png")
	var win_t := Art.tex("buildings/window.png")
	if roof_t != null and wall_t != null:
		draw_texture_rect(wall_t, wall_r, true, wall.lightened(0.25))
		draw_texture_rect(roof_t, roof_r, true, roof.lightened(0.3))
		draw_rect(Rect2(roof_r.position.x, roof_r.end.y - 4, roof_r.size.x, 4), roof.darkened(0.45))
	else:
		draw_rect(wall_r, wall)
		draw_rect(roof_r, roof)
		for i in int(roof_r.size.y / 10.0):
			var y := roof_r.position.y + 6 + i * 10.0
			draw_line(Vector2(roof_r.position.x + 2, y), Vector2(roof_r.end.x - 2, y), roof.darkened(0.15), 1.0)
		draw_rect(roof_r, roof.lightened(0.15), false, 2.0)
	var door_x := _px(b.door).x if b.has("door") and b.get("side", "bottom") != "top" else -INF
	# windows along the front wall (not over a front door)
	var wx := r.position.x + tile * 0.5
	while wx < r.end.x - tile * 0.8:
		if win_t != null:
			if absf(wx + tile * 0.5 - door_x) > tile * 0.9:
				draw_texture(win_t, Vector2(wx, wall_r.position.y + (wall_h - tile) * 0.5))
		else:
			draw_rect(Rect2(wx, wall_r.position.y + wall_h * 0.25, tile * 0.45, wall_h * 0.4), Color("#ffe8a3").darkened(0.15))
		wx += tile * 1.2
	draw_rect(r, wall.darkened(0.45) if roof_t == null else Color("#14121c"), false, 2.0)
	if b.has("door"):
		var d := _px(b.door)
		var top: bool = b.get("side", "bottom") == "top"
		var door_t := Art.tex("buildings/hatch.png" if top else "buildings/door.png")
		if door_t != null:
			draw_texture(door_t, Vector2(d.x - tile * 0.5, d.y - tile if not top else d.y - tile * 0.15))
	if b.has("door") and Art.tex("buildings/door.png") == null:
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


## Production station inside an estate: a work surface with a few parts that hint at what it does.
func _draw_machine(b: Dictionary, r: Rect2) -> void:
	var inner := r.grow(-4)
	var t := Art.tex("stations/%s.png" % b.get("station", ""))
	if t != null:
		draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.3))
		draw_texture_rect(t, r, false)
		_machine_label(b.name, r)
		return
	draw_rect(Rect2(inner.position + Vector2(4, 6), inner.size), Color(0, 0, 0, 0.3))
	draw_rect(inner, Color("#6b6f7a"))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 6)), Color("#9aa0ad"))
	draw_rect(inner, Color("#2a2d36"), false, 2.0)
	var c := inner.get_center()
	match b.get("station", ""):
		"trim_table":
			draw_circle(c + Vector2(-10, 2), 7.0, Color("#3f8a5e"))
			draw_line(c + Vector2(4, -4), c + Vector2(16, 6), Color("#d0d0d0"), 2.0)
		"precursor_scale":
			draw_rect(Rect2(c - Vector2(9, 4), Vector2(18, 10)), Color("#c9d1d9"))
			draw_circle(c + Vector2(0, -6), 4.0, Color("#ffd166"))
		"mixing_station":
			for i in 3:
				draw_rect(Rect2(c + Vector2(-20 + i * 14, -8), Vector2(8, 16)), [Color("#7fffd4"), Color("#ff9ad5"), Color("#ffd166")][i])
		"cook_stove":
			draw_circle(c + Vector2(-12, -10), 9.0, Color("#2a2a30"))
			draw_circle(c + Vector2(12, 10), 9.0, Color("#2a2a30"))
			draw_circle(c + Vector2(-12, -10), 5.0, Color("#ff6b3a"))
		"extractor":
			draw_rect(Rect2(c + Vector2(-22, -12), Vector2(10, 22)), Color("#7fb8d0"))
			draw_rect(Rect2(c + Vector2(-20, -2), Vector2(6, 10)), Color("#e8c547"))
			draw_line(c + Vector2(-12, -10), c + Vector2(8, -6), Color("#c9d1d9"), 2.0)
			draw_circle(c + Vector2(14, 2), 7.0, Color("#e8c547"))
		"refiner":
			draw_rect(Rect2(c + Vector2(-24, -14), Vector2(12, 18)), Color("#ff6b5f"))
			draw_rect(Rect2(c + Vector2(12, -14), Vector2(12, 18)), Color("#5a7dff"))
			draw_circle(c + Vector2(0, 6), 11.0, Color("#4fe3c1"))
			draw_rect(Rect2(c + Vector2(-14, -24), Vector2(28, 6)), Color("#2a2d36"))
		"pack_table":
			draw_rect(Rect2(c - Vector2(16, 6), Vector2(12, 12)), Color("#c9b88a"))
			draw_rect(Rect2(c + Vector2(4, -6), Vector2(12, 12)), Color("#c9b88a"))
	_machine_label(b.name, r)


## Small name tag on the front face; long names drop words until they fit the machine.
func _machine_label(text: String, r: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var words := text.split(" ")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	while w > r.size.x - 6 and words.size() > 1:
		words.remove_at(words.size() - 1)
		text = " ".join(words)
		w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var p := Vector2(r.get_center().x - w / 2.0, r.end.y - 4)
	draw_rect(Rect2(p + Vector2(-2, -7), Vector2(w + 4, 9)), Color(0, 0, 0, 0.6))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#e6e9ff"))


func _draw_prop(kind: String, p: Vector2) -> void:
	var bottoms := {"tree": 12.0, "lamp": 12.0, "crate": 12.0, "rock": 10.0, "barrel": 12.0, "vent": 16.0, "stall": 12.0}
	if bottoms.has(kind):
		var shadow := {"tree": 14.0, "rock": 13.0, "barrel": 9.0, "crate": 11.0}
		if shadow.has(kind):
			draw_circle(p + Vector2(3, bottoms[kind] - 3.0), shadow[kind], Color(0, 0, 0, 0.25))
		if kind == "lamp":
			draw_circle(p + Vector2(0, -30), 22.0, Color(1.0, 0.85, 0.5, 0.07))
		if Art.draw_prop(self, "props/%s.png" % kind, p, bottoms[kind]):
			return
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
	if placing != "" and GameState.data.buildables.has(placing):
		var c := ghost_cell()
		var size: Array = GameState.data.buildables[placing].size
		var off := int(cfg.get("estate_offset", 0))
		var ok: bool = can_place.is_valid() and can_place.call(placing, c.x, c.y)
		var gr := Rect2(Vector2(c.x + off, c.y + off) * tile, Vector2(size[0], size[1]) * tile)
		var col := Color(0.31, 0.89, 0.76) if ok else Color(1.0, 0.42, 0.37)
		_overlay.draw_rect(gr, Color(col, 0.25))
		_overlay.draw_rect(gr, col, false, 2.0)
	if focus.is_empty():
		return
	var p: Vector2 = focus.pos
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	_overlay.draw_arc(p, 20.0 + pulse * 4.0, 0, TAU, 32, Color(0.31, 0.89, 0.76, 0.5 + pulse * 0.4), 2.0)
