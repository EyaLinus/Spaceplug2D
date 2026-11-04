extends RefCounted
## D4 building interiors. A key building on a planet surface (a door with a panel action: market, shipyard, office,
## fence) has a small room of its own, defined in data/interiors.json[location][building id]. This turns that
## definition into a surface config that surface.gd instances like a planet or an estate: a walled room, a counter
## that opens the building's own panel, a clerk who opens the same panel, and an exit.
## Inner tile (x, y) sits at map tile (x + 1, y + 1) because of the wall ring. No autoload references, so tests can
## build rooms headless.

const WALL := 1
const PANELS := ["market", "shipyard", "office", "fence"]  ## building actions that get a room
const COUNTER_W := 4
const COUNTER_Y := 2  ## inner row of the counter


## The room definition for a building, {} if it has none.
static func def(data: Dictionary, loc: String, building_id: String) -> Dictionary:
	return data.get("interiors", {}).get(loc, {}).get(building_id, {})


## The surface building with this id (only buildings with a room), {} if none.
static func building(data: Dictionary, loc: String, building_id: String) -> Dictionary:
	if def(data, loc, building_id).is_empty():
		return {}
	for b in data.get("surfaces", {}).get(loc, {}).get("buildings", []):
		if b.id == building_id:
			return b
	return {}


static func has(data: Dictionary, loc: String, building_id: String) -> bool:
	return not building(data, loc, building_id).is_empty()


## Ids of the buildings on a planet that have a room.
static func ids(data: Dictionary, loc: String) -> Array:
	var out: Array = []
	for b in data.get("surfaces", {}).get(loc, {}).get("buildings", []):
		if has(data, loc, b.id):
			out.append(b.id)
	return out


## Column of the exit gap and the counter's left column (inner tiles).
static func door_x(size: Array) -> int:
	return int(size[0]) / 2


static func counter_x(size: Array) -> int:
	return door_x(size) - COUNTER_W / 2


static func build_cfg(data: Dictionary, loc: String, building_id: String) -> Dictionary:
	var b := building(data, loc, building_id)
	var d := def(data, loc, building_id)
	if b.is_empty():
		return {}
	var w := int(d.size[0])
	var h := int(d.size[1])
	var dx := door_x(d.size)
	var cx := counter_x(d.size)
	var clerk_x := float(cx + COUNTER_W + WALL) + 0.8  ## beside the counter, reachable from the floor in front
	var label: String = b.get("label", b.name)
	var cfg := {
		"name": b.name, "size": [w + 2 * WALL, h + 2 * WALL], "tile": 32,
		"ground": d.floor, "ground_alt": d.get("floor_alt", d.floor), "road": d.floor, "road_line": d.floor,
		"roads": [], "plazas": [], "walkers": 0, "security": 0.0, "npcs": [], "zoom": 2.0, "grass": false,
		"spawn": [dx + WALL + 0.5, h + WALL - 0.7],
		"interior": {"loc": loc, "building": building_id, "action": b.action},
		"exits": [{"id": "exit", "pos": [dx + WALL + 0.5, h + WALL - 0.25], "label": "Leave %s" % b.name, "action": "exit_interior"}],
		"buildings": [],
	}
	var wall := {"wall": "#2a2622", "roof": "#2a2622", "style": "wall"}
	var ring := [
		[0, 0, w + 2, 1], [0, h + 1, dx + WALL, 1], [dx + WALL + 1, h + 1, w - dx, 1],
		[0, 1, 1, h], [w + 1, 1, 1, h],
	]
	for i in ring.size():
		var r: Dictionary = wall.duplicate()
		r.id = "wall%d" % i
		r.name = "Wall"
		r.rect = ring[i]
		cfg.buildings.append(r)
	cfg.buildings.append({
		"id": "counter", "name": b.name, "style": "counter", "wall": d.get("counter", "#6b4a2e"), "roof": d.get("counter", "#6b4a2e"),
		"rect": [cx + WALL, COUNTER_Y + WALL, COUNTER_W, 1],
		"door": [cx + WALL + COUNTER_W / 2.0, COUNTER_Y + WALL + 1], "side": "bottom",
		"action": b.action, "label": label,
	})
	cfg.npcs.append({
		"id": "clerk", "name": d.clerk.name, "pos": [clerk_x, COUNTER_Y + WALL + 0.6], "action": b.action,
		"color": d.clerk.get("color", "#ffd166"), "label": "%s – %s" % [d.clerk.name, label],
	})
	var props: Array = []
	for p in d.get("props", []):
		props.append([p[0], float(p[1]) + WALL, float(p[2]) + WALL])
	cfg.props = props
	return cfg


## Where the player stands after leaving: in front of the building's door on the planet (the surface interactable id).
static func outside_id(cfg: Dictionary) -> String:
	return str(cfg.get("interior", {}).get("building", ""))
