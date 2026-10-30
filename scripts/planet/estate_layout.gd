extends RefCounted
## Turns an owned estate (data/content.json "estates" + the buildings placed in the save) into a surface config
## that surface.gd can instance like a planet: a walled room, the placed production stations as solid machines,
## and the exit door. Estate cell (x, y) sits at map cell (x + 1, y + 1) because of the wall ring.
## No autoload references, so tests can build layouts headless.

const WALL := 1


static func build_cfg(data: Dictionary, estate_id: String, buildings: Array) -> Dictionary:
	var e: Dictionary = data.estates[estate_id]
	var w := int(e.size[0])
	var h := int(e.size[1])
	var door := Vector2i(w / 2, h - 1)
	var cfg := {
		"name": e.name, "size": [w + 2 * WALL, h + 2 * WALL], "tile": 32,
		"ground": "#3a3328", "ground_alt": "#40382c", "road": "#45464f", "road_line": "#6b6c78",
		"roads": [], "plazas": [], "walkers": 0, "security": 0.0, "props": [], "npcs": [],
		"spawn": [door.x + WALL + 0.5, door.y + WALL + 0.3],
		"estate": estate_id, "estate_size": [w, h], "estate_offset": WALL, "zoom": 2.0, "grass": false,
		"exits": [{"id": "exit", "pos": [door.x + WALL + 0.5, door.y + WALL + 0.75], "label": "Leave %s" % e.name, "action": "exit_estate"}],
		"buildings": [],
	}
	var wall := {"wall": "#2a2622", "roof": "#2a2622", "style": "wall"}
	var ring := [
		[0, 0, w + 2, 1], [0, h + 1, door.x + WALL, 1], [door.x + WALL + 1, h + 1, w - door.x, 1],
		[0, 1, 1, h], [w + 1, 1, 1, h],
	]
	for i in ring.size():
		var r: Dictionary = wall.duplicate()
		r.id = "wall%d" % i
		r.name = "Wall"
		r.rect = ring[i]
		cfg.buildings.append(r)
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		var size: Array = data.buildables[b.id].size
		var x := int(b.x) + WALL
		var y := int(b.y) + WALL
		cfg.buildings.append({
			"id": "b%d" % i, "index": i, "station": b.id, "name": data.stations[b.id].name, "style": "machine",
			"rect": [x, y, int(size[0]), int(size[1])], "door": [x + int(size[0]) / 2.0, y + int(size[1])], "side": "bottom",
			"action": "station", "label": data.stations[b.id].name,
		})
	return cfg
