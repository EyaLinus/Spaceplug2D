extends RefCounted
## Per-planet laws (content.json "laws"): each location rates every drug tier as legal / tolerated / banned.
## The level scales patrol scan radius, on-foot frisk density, heat gained on sales and the price (black-market
## premium for banned goods). Stateless, so old saves need nothing. No scene dependencies. Numbers are eyeballed.

const Mixing = preload("res://scripts/core/mixing.gd")
const RANK := {"legal": 0, "tolerated": 1, "banned": 2}


static func cfg(g) -> Dictionary:
	return g.data.get("laws", {})


## "legal" | "tolerated" | "banned" for a drug base at a location (unlisted = tolerated).
static func level(g, loc: String, base: String) -> String:
	var tier := str(int(g.data.bases.get(base, {}).get("tier", 1)))
	var lv := str(cfg(g).get("planets", {}).get(loc, {}).get(tier, "tolerated"))
	return lv if RANK.has(lv) else "tolerated"


static func rule(g, lv: String) -> Dictionary:
	return cfg(g).get("levels", {}).get(lv, {})


static func _mult(g, lv: String, key: String) -> float:
	return float(rule(g, lv).get(key, 1.0))


static func heat_mult(g, loc: String, base: String) -> float:
	return _mult(g, level(g, loc, base), "heat_mult")


static func price_mult(g, loc: String, base: String) -> float:
	return _mult(g, level(g, loc, base), "price_mult")


## The strictest level among the products in cargo at `loc`; "" when carrying none.
static func worst_cargo_level(g, loc: String) -> String:
	var worst := ""
	for k in g.cargo:
		if int(g.cargo[k]) <= 0 or not Mixing.is_product(k):
			continue
		var lv := level(g, loc, Mixing.parse_key(k).base)
		if worst == "" or RANK[lv] > RANK[worst]:
			worst = lv
	return worst


## Scan radius factor in space: the laws of the planet you last docked at against what you carry.
static func scan_mult(g) -> float:
	var w := worst_cargo_level(g, g.location)
	return 1.0 if w == "" else _mult(g, w, "scan_mult")


## Walking police density factor on a surface, by the cargo you carry. Never below 1: legal goods do not thin the
## patrols out (the surface would drop officers every time the cargo changes), banned goods add some.
static func frisk_mult(g, loc: String) -> float:
	var w := worst_cargo_level(g, loc)
	return 1.0 if w == "" else maxf(1.0, _mult(g, w, "frisk_mult"))


## [{base, name, level, label}] for every drug at a location, weakest tier first.
static func summary(g, loc: String) -> Array:
	var out: Array = []
	var bases: Array = g.data.bases.keys()
	bases.sort_custom(func(a, b): return int(g.data.bases[a].tier) < int(g.data.bases[b].tier))
	for b in bases:
		var lv := level(g, loc, b)
		out.append({"base": b, "name": g.data.bases[b].name, "level": lv, "label": str(rule(g, lv).get("name", lv))})
	return out


static func line(g, loc: String) -> String:
	var parts: Array = []
	for r in summary(g, loc):
		parts.append("%s %s" % [r.name, str(r.label).to_lower()])
	return ", ".join(PackedStringArray(parts))


static func tooltip(g, loc: String) -> String:
	return "Local laws: %s.\nLegal goods draw half the heat and scans; banned goods draw +40%% heat, stricter scans and frisks, but sell at a +20%% black-market premium." % line(g, loc)
