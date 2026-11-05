extends RefCounted
## K3 hand-placed map marker: one location or star system the player flags in the Map app. The autopilot and the HUD
## waypoint arrow fall back to it when no quest waypoint is active (quest waypoints keep priority). Another system's
## marker routes to the jump gate towards it, like quest waypoints do.
## State: Game.map_marker = "" or a location id or a system id (saved; old saves have none).
## No autoload references (unit tests run without autoloads).

const Galaxy = preload("res://scripts/core/galaxy.gd")


static func valid(g, id: String) -> bool:
	return g.data.locations.has(id) or g.data.systems.has(id)


static func is_system(g, id: String) -> bool:
	return g.data.systems.has(id) and not g.data.locations.has(id)


static func set_marker(g, id: String) -> Dictionary:
	if not valid(g, id):
		return {"ok": false, "msg": "Nothing to mark there."}
	g.map_marker = id
	return {"ok": true, "msg": "Marker set: %s." % label(g, id)}


static func clear(g) -> void:
	g.map_marker = ""


static func label(g, id: String) -> String:
	if g.data.locations.has(id):
		return str(g.data.locations[id].name)
	if g.data.systems.has(id):
		return str(g.data.systems[id].name)
	return ""


## The marker has been reached: you are docked there, or (system marker) flying in that system.
static func reached(g) -> bool:
	var m: String = g.map_marker
	if m == "":
		return false
	if is_system(g, m):
		return g.system == m
	return g.location == m


## Location id in the current system the marker points at right now (the marker itself, or the gate towards its
## system), or "" when there is nothing to fly to (no marker, reached, unknown, no route).
static func goal_location(g) -> String:
	var m: String = g.map_marker
	if m == "" or not valid(g, m) or reached(g):
		return ""
	var sys: String = m if is_system(g, m) else g.loc_system(m)
	if sys == g.system:
		return "" if is_system(g, m) else m
	var rt: Array = Galaxy.route(g, g.system, sys)
	if rt.size() < 2:
		return ""
	var gs: Array = Galaxy.gates(g, g.system, str(rt[1]))
	return str(gs[0]) if not gs.is_empty() else ""


static func to_save(g) -> String:
	return g.map_marker


static func from_save(g, v) -> void:
	var id := str(v) if v != null else ""
	g.map_marker = id if valid(g, id) else ""
