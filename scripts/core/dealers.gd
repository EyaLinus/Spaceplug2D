extends RefCounted
## Dealers (A5). Street dealers you hire in the HR app (one-off signing fee, no wage: they keep a cut of every sale).
## You give a dealer a district (a location with demand) and hand them product in person (docked there); every
## `sell_seconds` they sell a few units to the locals at your asking price (Market = local value × demand). The cash
## piles up with them until you collect it in person; at `max_cash` they stop selling. Each sale can get them busted
## (more likely with system heat, less with skill): stock and cash are lost and they sit out `jail_seconds`.
## State: Game.dealers [{id, loc, stock: {product: qty}, cash, sold, jail}] (saved). Numbers: content.json "dealers".

const Mixing = preload("res://scripts/core/mixing.gd")
const Products = preload("res://scripts/core/products.gd")


static func cfg(g) -> Dictionary:
	return g.data.get("dealers", {})


static func candidate(g, id: String) -> Dictionary:
	for c in cfg(g).get("candidates", []):
		if c.id == id:
			return c
	return {}


static func find(g, id: String) -> Dictionary:
	for d in g.dealers:
		if d.id == id:
			return d
	return {}


static func available(g) -> Array:
	return cfg(g).get("candidates", []).filter(func(c): return find(g, c.id).is_empty())


## Locations a dealer can work: anywhere people buy drugs.
static func districts(g) -> Array:
	var r: Array = []
	for loc in g.data.locations:
		if not g.data.locations[loc].get("demand", {}).is_empty():
			r.append(loc)
	return r


static func units(d: Dictionary) -> int:
	var n := 0
	for k in d.stock:
		n += int(d.stock[k])
	return n


static func hire(g, id: String) -> Dictionary:
	var c := candidate(g, id)
	if c.is_empty() or not find(g, id).is_empty():
		return g._fail("Not available.")
	if g.dealers.size() >= int(cfg(g).get("max_dealers", 3)):
		return g._fail("You can run at most %d dealers." % int(cfg(g).get("max_dealers", 3)))
	if g.credits < int(c.fee):
		return g._fail("%s wants %d cr up front." % [c.name, int(c.fee)])
	g.credits -= int(c.fee)
	g.dealers.append({"id": id, "loc": "", "stock": {}, "cash": 0, "sold": 0, "jail": 0.0})
	g._emit("dealer_hired", {"dealer": id})
	return g._ok("%s deals for you now (%d cr signing fee, %d%% cut)." % [c.name, int(c.fee), int(float(c.cut) * 100.0)])


## Lets a dealer go. Their stock and cash come back only if you stand with them (docked in their district).
static func fire(g, id: String) -> Dictionary:
	var d := find(g, id)
	if d.is_empty():
		return g._fail("Not one of yours.")
	var lost := ""
	if g.location == d.loc and d.loc != "":
		collect(g, id)
		for k in d.stock.keys():
			g._add(g.cargo, k, int(d.stock[k]))
	elif units(d) > 0 or int(d.cash) > 0:
		lost = " They kept %d units and %d cr." % [units(d), int(d.cash)]
	g.dealers.erase(d)
	g._emit("dealer_left", {"dealer": id})
	return g._ok("%s is out.%s" % [candidate(g, id).name, lost])


static func assign(g, id: String, loc: String) -> Dictionary:
	var d := find(g, id)
	if d.is_empty():
		return g._fail("Not one of yours.")
	if not loc in districts(g):
		return g._fail("Nobody buys there.")
	if units(d) > 0 and d.loc != "" and d.loc != loc:
		return g._fail("Collect their stock before moving them.")
	d.loc = loc
	g._emit("dealer_assigned", {"dealer": id, "loc": loc})
	return g._ok("%s works %s now." % [candidate(g, id).name, g.loc_data(loc).get("name", loc)])


## Hands `qty` units of a product from your hold to the dealer (you must be docked in their district).
static func give(g, id: String, product_key: String, qty: int) -> Dictionary:
	var d := find(g, id)
	if d.is_empty():
		return g._fail("Not one of yours.")
	if d.loc == "" or g.location != d.loc:
		return g._fail("Meet %s in their district." % candidate(g, id).name)
	if float(d.jail) > 0.0:
		return g._fail("%s is locked up." % candidate(g, id).name)
	qty = mini(qty, int(g.cargo.get(product_key, 0)))
	var room := int(candidate(g, id).get("capacity", 30)) - units(d)
	qty = mini(qty, room)
	if not Mixing.is_product(product_key) or qty <= 0:
		return g._fail("Their bag is full." if room <= 0 else "You don't carry that.")
	g._add(g.cargo, product_key, -qty)
	g._add(d.stock, product_key, qty)
	g._emit("dealer_stocked", {"dealer": id, "product": product_key, "qty": qty})
	return g._ok("Gave %s %d × %s." % [candidate(g, id).name, qty, g.item_name(product_key)])


## Takes the dealer's stock back into your hold (docked in their district).
static func take_back(g, id: String) -> Dictionary:
	var d := find(g, id)
	if d.is_empty() or d.loc == "" or g.location != d.loc:
		return g._fail("Meet them in their district.")
	var moved := 0
	for k in d.stock.keys():
		var n := mini(int(d.stock[k]), g.cargo_free())
		if n <= 0:
			break
		g._add(g.cargo, k, n)
		g._add(d.stock, k, -n)
		moved += n
	if moved == 0:
		return g._fail("Nothing to take." if units(d) == 0 else "Cargo hold is full.")
	return g._ok("Took back %d units." % moved)


static func collect(g, id: String) -> Dictionary:
	var d := find(g, id)
	if d.is_empty() or d.loc == "" or g.location != d.loc:
		return g._fail("Meet them in their district.")
	var cash := int(d.cash)
	if cash <= 0:
		return g._fail("No cash yet.")
	d.cash = 0
	g.credits += cash
	g.stats.earned += cash
	g._emit("dealer_collected", {"dealer": id, "credits": cash})
	return g._ok("Collected %d cr from %s." % [cash, candidate(g, id).name])


## Price per unit a dealer gets for `product_key` at `loc`: your asking price if the locals accept it, else -1;
## on Market the local value × demand.
static func street_price(g, product_key: String, loc: String) -> int:
	var p := Mixing.parse_key(product_key)
	var dem := float(g.demand.get(loc, {}).get(p.base, 0.0))
	if dem <= 0.0:
		return -1
	var market := int(round(Mixing.value(g.data, product_key) * dem))
	var ask := Products.asking(g, product_key)
	if ask < 0:
		return maxi(market, 1)
	return ask if ask <= int(market * (1.0 + float(cfg(g).get("tolerance", 0.1)))) else -1


## What blocks a dealer right now ("" = selling).
static func status(g, d: Dictionary) -> String:
	if float(d.jail) > 0.0:
		return "In jail (%ds)" % int(ceil(float(d.jail)))
	if d.loc == "":
		return "No district"
	if units(d) == 0:
		return "Out of stock"
	if int(d.cash) >= int(cfg(g).get("max_cash", 2000)):
		return "Holding max cash, collect it"
	for k in d.stock:
		if street_price(g, k, d.loc) > 0:
			return ""
	return "Your prices are too steep here"


static func bust_chance(g, d: Dictionary) -> float:
	var c := candidate(g, d.id)
	var heat: float = g.heat if g.loc_system(d.loc) == g.system else float(g.corruption.get("heat", {}).get(g.loc_system(d.loc), 0.0))
	var p := float(cfg(g).get("bust_base", 0.01)) + heat * float(cfg(g).get("bust_per_heat", 0.0006))
	p *= float(g.data.locations[d.loc].get("heat_per_unit", 1.0)) / 2.0 + 0.5
	return clampf(p * (1.0 - float(c.get("skill", 0.0)) * 0.6), 0.0, 0.5)


static func tick(g, dt: float) -> void:
	if g.dealers.is_empty():
		return
	var every := float(cfg(g).get("sell_seconds", 20.0))
	for d in g.dealers:
		if float(d.jail) > 0.0:
			d.jail = maxf(float(d.jail) - dt, 0.0)
			if float(d.jail) <= 0.0:
				g._emit("dealer_free", {"dealer": d.id})
			continue
		d["clock"] = float(d.get("clock", 0.0)) + dt
		while float(d.clock) >= every:
			d.clock = float(d.clock) - every
			if status(g, d) != "":
				break
			_sell_round(g, d)


static func _sell_round(g, d: Dictionary) -> void:
	var c := candidate(g, d.id)
	var best := ""
	var best_price := -1
	for k in d.stock:
		var pr := street_price(g, k, d.loc)
		if pr > best_price:
			best = k
			best_price = pr
	if best == "" or best_price <= 0:
		return
	var n := mini(int(d.stock[best]), int(cfg(g).get("units_base", 1)) + g.rng.randi_range(0, int(round(float(c.get("skill", 0.0)) * float(cfg(g).get("units_skill", 3))))))
	var p := Mixing.parse_key(best)
	if g.rng.randf() < bust_chance(g, d):
		var lost := units(d)
		var cash := int(d.cash)
		d.stock = {}
		d.cash = 0
		d.jail = float(cfg(g).get("jail_seconds", 180.0))
		g._emit("dealer_busted", {"dealer": d.id, "loc": d.loc, "units": lost, "credits": cash})
		return
	var gross := best_price * n
	var net := int(round(gross * (1.0 - float(c.cut))))
	g._add(d.stock, best, -n)
	d.cash = int(d.cash) + net
	d.sold = int(d.sold) + n
	g.stats.units_sold += n
	var dem: Dictionary = g.demand[d.loc]
	dem[p.base] = maxf(float(dem[p.base]) - float(g.data.market.saturation_per_unit) * n, float(g.data.market.min_demand))
	if g.loc_system(d.loc) == g.system:
		g.add_heat(float(g.loc_data(d.loc).heat_per_unit) * n * g.sale_heat_mult(p.base, d.loc) * float(cfg(g).get("heat_mult", 0.5)))
	g._emit("dealer_sold", {"dealer": d.id, "product": best, "qty": n, "credits": net})
	if int(d.cash) >= int(cfg(g).get("max_cash", 2000)):
		g._emit("dealer_cash_full", {"dealer": d.id})


static func to_save(g) -> Array:
	return g.dealers.duplicate(true)


static func from_save(g, list: Array) -> void:
	g.dealers = []
	for x in list:
		if candidate(g, str(x.get("id", ""))).is_empty():
			continue
		var stock := {}
		for k in x.get("stock", {}):
			if int(x.stock[k]) > 0:
				stock[k] = int(x.stock[k])
		var loc := str(x.get("loc", ""))
		g.dealers.append({"id": str(x.id), "loc": loc if g.data.locations.has(loc) else "", "stock": stock,
			"cash": int(x.get("cash", 0)), "sold": int(x.get("sold", 0)), "jail": float(x.get("jail", 0.0))})
		if x.has("clock"):  # time towards the next street sale; dropping it reset the timer on every load
			g.dealers[-1].clock = float(x.clock)
