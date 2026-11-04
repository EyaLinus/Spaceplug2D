extends RefCounted
## Planet heat zones (P3): where you stand when you deal decides how much heat the sale makes. The open plaza is
## watched and hot, side streets are normal, the back alleys off the roads are quiet. Pure functions, no scene deps.
## Numbers in content.json "heat_zones"; the surface keeps `Game.heat_zone` (runtime, not saved) up to date and
## Game.sell / Deals.fulfill multiply their heat by `mult(g)`.

const DEFAULT := "street"


static func rules(g) -> Dictionary:
	return g.data.get("heat_zones", {})


## Zone id at `cell` (tile units) of a surface config: "plaza" inside a plaza rect, "street" on a road, "alley" anywhere
## else. A surface without roads or plazas (an estate interior) has no zones and is always "street".
static func zone_at(cfg: Dictionary, cell: Vector2) -> String:
	var plazas: Array = cfg.get("plazas", [])
	var roads: Array = cfg.get("roads", [])
	if plazas.is_empty() and roads.is_empty():
		return DEFAULT
	for r in plazas:
		if _in(r, cell):
			return "plaza"
	for r in roads:
		if _in(r, cell):
			return "street"
	return "alley"


static func _in(r: Array, c: Vector2) -> bool:
	return c.x >= float(r[0]) and c.x < float(r[0]) + float(r[2]) and c.y >= float(r[1]) and c.y < float(r[1]) + float(r[3])


## Heat multiplier of a zone (1.0 for unknown ids).
static func zone_mult(g, zone: String) -> float:
	return float(rules(g).get("zones", {}).get(zone, {}).get("mult", 1.0))


## Multiplier for a sale made right now.
static func mult(g) -> float:
	return zone_mult(g, g.heat_zone)


static func label(g, zone: String) -> String:
	return str(rules(g).get("zones", {}).get(zone, {}).get("name", ""))


static func tip(g, zone: String) -> String:
	var z: Dictionary = rules(g).get("zones", {}).get(zone, {})
	if z.is_empty():
		return ""
	return "%s: sales here make %d%% of the normal heat. %s" % [z.name, int(round(float(z.mult) * 100.0)), z.get("blurb", "")]
