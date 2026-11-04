extends RefCounted
## Products app (H1): the recipe book and your asking prices. Pure functions on a Game, no scene deps.
##
## Game.recipes: recipe key (product key without the grade, e.g. "weed:calming+energizing") ->
##   {base, additives (in mixing order, [] = unknown for products that came from an old save), made (units),
##    best (highest grade made), day (first day it was made)}
## Game.prices: recipe key -> asking price per Standard unit. No entry = "Market": buyers pay what they offer, as before.
##   A set price scales with grade (value_mult of data.quality.grades). Buyers pay your price if it is at most their own
##   offer plus a tolerance (affinity and addiction make people pay more), otherwise they refuse. Pricing below their
##   offer is a bargain: small affinity bonus. The fence ignores your prices.
## Numbers in content.json "products".

const Mixing = preload("res://scripts/core/mixing.gd")
const People = preload("res://scripts/core/people.gd")


static func rules(g) -> Dictionary:
	return g.data.get("products", {})


## Product key without the grade suffix.
static func recipe_key(product_key: String) -> String:
	var at := product_key.find("@")
	return product_key if at < 0 else product_key.substr(0, at)


static func known(g, rk: String) -> bool:
	return g.recipes.has(recipe_key(rk))


## Records a batch you (or a worker) started. Returns true for a product made for the first time.
static func discover(g, base: String, additives: Array, grade: int, qty: int) -> bool:
	var rk := Mixing.key(base, Mixing.traits_for(g.data, base, additives))
	var fresh: bool = not g.recipes.has(rk)
	if fresh:
		g.recipes[rk] = {"base": base, "additives": additives.duplicate(), "made": 0, "best": grade, "day": g.day}
	var r: Dictionary = g.recipes[rk]
	if (r.additives as Array).is_empty() and not additives.is_empty():
		r.additives = additives.duplicate()  # a legacy entry learns its recipe
	r.made = int(r.made) + qty
	r.best = maxi(int(r.best), grade)
	r.last = g.day
	r.runs = int(r.get("runs", 0)) + 1
	if fresh:
		g._emit("product_discovered", {"product": rk, "base": base})
	return fresh


## Mixing journal: the recipes with a known additive list, newest first (last day cooked, then most batches).
## `base` filters to one drug ("" = all). Entries are copies: {key, base, additives, made, best, last, runs}.
static func journal(g, base: String = "") -> Array:
	var r: Array = []
	for rk in g.recipes:
		var e: Dictionary = g.recipes[rk]
		if (e.additives as Array).is_empty() or (base != "" and e.base != base):
			continue
		var c: Dictionary = e.duplicate(true)
		c.key = rk
		r.append(c)
	r.sort_custom(func(a, b):
		if a.last != b.last:
			return a.last > b.last
		if a.runs != b.runs:
			return a.runs > b.runs
		return a.key < b.key)
	return r


## Products you carry from before the recipe book existed (old saves) get an entry without a known recipe.
static func adopt_items(g, items: Dictionary) -> void:
	for k in items:
		if not Mixing.is_product(k):
			continue
		var rk := recipe_key(k)
		if not g.recipes.has(rk):
			var p := Mixing.parse_key(k)
			g.recipes[rk] = {"base": p.base, "additives": [], "made": 0, "best": p.grade, "day": g.day}


## Recipe keys sorted by drug tier (data.bases order) and then by value.
static func list(g, base: String = "") -> Array:
	var order: Array = g.data.bases.keys()
	var r: Array = []
	for rk in g.recipes:
		if base == "" or g.recipes[rk].base == base:
			r.append(rk)
	r.sort_custom(func(a, b):
		var ia := order.find(g.recipes[a].base)
		var ib := order.find(g.recipes[b].base)
		if ia != ib:
			return ia < ib
		return Mixing.value(g.data, a) > Mixing.value(g.data, b))
	return r


## What a Standard unit is worth at 100 % demand: the default asking price.
static func suggested(g, rk: String) -> int:
	return maxi(int(round(Mixing.value(g.data, recipe_key(rk)))), 1)


static func has_price(g, rk: String) -> bool:
	return g.prices.has(recipe_key(rk))


## Your asking price per Standard unit (suggested value while on Market).
static func price(g, rk: String) -> int:
	return int(g.prices.get(recipe_key(rk), suggested(g, rk)))


static func max_price(g, rk: String) -> int:
	return int(ceil(suggested(g, rk) * float(rules(g).get("max_price_mult", 4.0))))


static func set_price(g, rk: String, value: int) -> Dictionary:
	rk = recipe_key(rk)
	if not g.recipes.has(rk):
		return g._fail("Make it once before you price it.")
	g.prices[rk] = clampi(value, 1, max_price(g, rk))
	g._emit("price_set", {"product": rk, "price": g.prices[rk]})
	return g._ok("%s: %d cr per unit." % [Mixing.display_name(g.data, rk), g.prices[rk]])


static func clear_price(g, rk: String) -> Dictionary:
	rk = recipe_key(rk)
	g.prices.erase(rk)
	g._emit("price_set", {"product": rk, "price": -1})
	return g._ok("%s sells at market price." % Mixing.display_name(g.data, rk))


## Asking price for this exact product key (grade applied), -1 while the product is on Market.
static func asking(g, product_key: String) -> int:
	var rk := recipe_key(product_key)
	if not g.prices.has(rk):
		return -1
	var grade := int(Mixing.parse_key(product_key).grade)
	return maxi(int(round(float(g.prices[rk]) * float(Mixing.grade_info(g.data, grade).value_mult))), 1)


## How far above their own offer a customer still pays (0.1 = +10 %).
static func tolerance(g, cid: String) -> float:
	var r := rules(g)
	var s: Dictionary = People.state(g, cid)
	var t := float(r.get("tolerance_base", 0.05)) + float(r.get("tolerance_affinity", 0.15)) * float(s.affinity) \
		+ float(r.get("tolerance_addiction", 0.3)) * float(s.addiction)
	return maxf(t, 0.0)


## Highest price per unit this customer accepts for `product_key` right now.
static func ceiling(g, product_key: String, cid: String, loc: String = "") -> int:
	var offer: int = g.sell_price(product_key, cid, loc if loc != "" else g.location)
	return int(floor(offer * (1.0 + tolerance(g, cid))))


## Price per unit a customer pays: their offer on Market, your asking price if they accept it, -1 if it is too steep.
static func unit_price(g, product_key: String, cid: String, loc: String = "") -> int:
	var where: String = loc if loc != "" else g.location
	var ask := asking(g, product_key)
	if cid == "" or ask < 0:
		return g.sell_price(product_key, cid, where)
	return ask if ask <= ceiling(g, product_key, cid, where) else -1


## True when your price is clearly below what they would pay: they like you a little more for it.
static func is_bargain(g, product_key: String, cid: String) -> bool:
	var ask := asking(g, product_key)
	return ask > 0 and ask <= int(g.sell_price(product_key, cid) * float(rules(g).get("bargain_ratio", 0.9)))


## Estates you own whose placed stations can make the recipe (empty additives = only the base line is checked).
static func makers(g, rk: String) -> Array:
	var r: Dictionary = g.recipes.get(recipe_key(rk), {})
	if r.is_empty():
		return []
	var out: Array = []
	for eid in g.estates:
		if g.missing_stations_in(eid, r.base, r.additives).is_empty():
			out.append(eid)
	return out


static func to_save(g) -> Dictionary:
	return {"recipes": g.recipes.duplicate(true), "prices": g.prices.duplicate()}


static func from_save(g, d: Dictionary) -> void:
	g.recipes = {}
	for rk in d.get("recipes", {}):
		var e: Dictionary = d.recipes[rk]
		var base := str(e.get("base", ""))
		if not g.data.bases.has(base):
			continue
		var adds: Array = []
		for a in e.get("additives", []):
			if g.data.additives.has(a):
				adds.append(str(a))
		g.recipes[rk] = {"base": base, "additives": adds, "made": int(e.get("made", 0)), "best": int(e.get("best", 1)), "day": int(e.get("day", 1)),
			"last": int(e.get("last", e.get("day", 1))), "runs": int(e.get("runs", 0))}
	g.prices = {}
	for rk in d.get("prices", {}):
		if g.recipes.has(rk):
			g.prices[rk] = int(d.prices[rk])
	adopt_items(g, g.cargo)
	adopt_items(g, g.stash)
