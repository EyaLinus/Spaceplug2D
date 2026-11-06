extends RefCounted
## D4 interiors: key buildings on a planet (data/interiors.json, keyed "<planet>:<building id>") are entered as a small
## room instead of opening their panel at the door. Inside, a counter (and a clerk behind it) opens the same panel the
## door used to, and the exit door puts the player back on the exact spot outside. Pure functions over data, no autoloads,
## so tests build the room layouts headless; surface.gd draws them like estate rooms and main.gd does the switching.

const WALL := 1


static func key(loc: String, building_id: String) -> String:
	return "%s:%s" % [loc, building_id]


## True if the building `building_id` of planet `loc` has an interior.
static func has(data: Dictionary, loc: String, building_id: String) -> bool:
	return data.get("interiors", {}).has(key(loc, building_id))


## The outer building (surfaces.json) an interior belongs to, {} if there is none.
static func outer_building(data: Dictionary, loc: String, building_id: String) -> Dictionary:
	for b in data.get("surfaces", {}).get(loc, {}).get("buildings", []):
		if b.id == building_id:
			return b
	return {}


## Surface config for the room. The counter keeps the outer building's id and action, so quest waypoints and the
## panel logic work unchanged; the clerk behind it is the same counter again; "interior" marks it for surface.gd.
static func build_cfg(data: Dictionary, loc: String, building_id: String) -> Dictionary:
	var it: Dictionary = data.interiors[key(loc, building_id)]
	var outer := outer_building(data, loc, building_id)
	var w := int(it.size[0])
	var h := int(it.size[1])
	var door_x := w / 2  # interior column of the exit gap
	var cw := int(it.counter.width)
	var cx := (w - cw) / 2 + WALL
	var action: String = outer.get("action", "")
	var label: String = str(outer.get("label", outer.get("name", it.name)))
	var cfg := {
		"name": it.name, "size": [w + 2 * WALL, h + 2 * WALL], "tile": 32,
		"ground": it.ground, "ground_alt": it.get("ground_alt", it.ground), "road": it.ground, "road_line": it.ground,
		"roads": [], "plazas": [], "walkers": 0, "security": 0.0, "cover": [], "npcs": [],
		"props": it.get("props", []).duplicate(), "grass": false, "zoom": 2.0,
		"interior": key(loc, building_id), "outer": building_id,
		"spawn": [door_x + WALL + 0.5, h + 0.3],
		"exits": [{"id": "exit", "pos": [door_x + WALL + 0.5, h + 0.75], "label": "Leave %s" % it.name, "action": "exit_interior"}],
		"buildings": [],
	}
	var wall := {"wall": it.wall, "roof": it.wall, "style": "wall"}
	var ring := [
		[0, 0, w + 2, 1], [0, h + 1, door_x + WALL, 1], [door_x + WALL + 1, h + 1, w - door_x, 1],
		[0, 1, 1, h], [w + 1, 1, 1, h],
	]
	for i in ring.size():
		var r: Dictionary = wall.duplicate()
		r.id = "wall%d" % i
		r.name = "Wall"
		r.rect = ring[i]
		cfg.buildings.append(r)
	var counter_y := WALL + 1
	cfg.buildings.append({
		"id": building_id, "name": it.clerk.name, "rect": [cx, counter_y, cw, 1], "door": [cx + cw / 2.0, counter_y + 1], "side": "bottom",
		"wall": it.counter.color, "roof": it.counter.color, "style": "wall", "action": action, "label": label,
	})
	cfg.npcs.append({
		"id": building_id + "_clerk", "name": it.clerk.name, "pos": [cx + cw / 2.0, counter_y - 0.5], "action": action,
		"color": it.clerk.color, "label": label, "contact": "",
	})
	return cfg


## Pixel position (feet) in front of the outer building's door; where the player stands if no better spot is known.
static func door_stand(data: Dictionary, loc: String, building_id: String) -> Vector2:
	var b := outer_building(data, loc, building_id)
	var tile := float(data.surfaces[loc].get("tile", 32))
	var out := Vector2.DOWN if b.get("side", "bottom") == "bottom" else Vector2.UP
	return Vector2(b.door[0], b.door[1]) * tile + out * tile * 0.6


## Where the player reappears outside: the exact spot they entered from, or the door if that spot is gone/unusable
## (outside the map or inside a building).
static func return_spot(data: Dictionary, loc: String, building_id: String, saved) -> Vector2:
	if typeof(saved) != TYPE_VECTOR2:
		return door_stand(data, loc, building_id)
	var s: Dictionary = data.surfaces[loc]
	var tile := float(s.get("tile", 32))
	var p: Vector2 = saved
	if not Rect2(Vector2.ZERO, Vector2(s.size[0], s.size[1]) * tile).has_point(p):
		return door_stand(data, loc, building_id)
	for b in s.buildings:
		if Rect2(Vector2(b.rect[0], b.rect[1]) * tile, Vector2(b.rect[2], b.rect[3]) * tile).has_point(p):
			return door_stand(data, loc, building_id)
	return p
