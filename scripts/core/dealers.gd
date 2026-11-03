extends RefCounted
## Dealers & couriers (A5, HR app part 2). Both are ordinary hired workers (workers.gd: wage, loyalty, hire/fire,
## `assign` to an estate, one of each role per estate); this module is what they do. Rules in content.json "dealers".
##  - dealer: every trip (sell_seconds / (0.5 + skill)) takes finished product from the estate's shelf/tray to one of your
##    KNOWN customers in the same system who prefers it and is ready to buy, at that customer's price. The dealer keeps a
##    cut of the sale (cut_base + cut_skill * skill: the better ones cost more). Risk per trip: bust chance
##    (bust_base + heat share * bust_heat - skill * bust_skill, clamped) -> the goods of the trip are lost, heat rises, and
##    the dealer is lost for good (lose_dealer) or loses loyalty.
##  - courier: runs a route per estate (set_route): "to_hub" (product -> hub stash), "from_hub" (product + the raws the
##    estate recipe needs <- hub stash), "to_estate" (product -> another estate's shelf). A trip carries up to
##    courier_cap_base + courier_cap_skill * skill units. A bust on the road is the same as for dealers, rarer.
##    Any courier on the payroll also makes A4 dead-drop courier runs cheaper and safer (drop_fee_mult / drop_theft_mult).
## State on Game.dealers (saved, old saves load empty): {routes: {estate: {dir, target}}, timers, last: {estate: text},
## stats: {sales, units, gross, cut, trips, busts, lost_units}}. Pure functions on a Game, no scene deps.

const Mixing = preload("res://scripts/core/mixing.gd")
const People = preload("res://scripts/core/people.gd")
const Workers = preload("res://scripts/core/workers.gd")

const DIRS := ["to_hub", "from_hub", "to_estate"]
const STAT_KEYS := ["sales", "units", "gross", "cut", "trips", "busts", "lost_units"]


static func rules(g) -> Dictionary:
	return g.data.get("dealers", {})


static func fresh() -> Dictionary:
	var s := {}
	for k in STAT_KEYS:
		s[k] = 0
	return {"routes": {}, "timers": {}, "last": {}, "stats": s}


# ---------------------------------------------------------------- numbers

static func skill(g, wid: String) -> float:
	return float(Workers.candidate(g, wid).get("skill", 0.0))


static func cut(g, wid: String) -> float:
	return float(rules(g).cut_base) + float(rules(g).cut_skill) * skill(g, wid)


static func dealer_cap(g, wid: String) -> int:
	return int(rules(g).cap_base) + int(round(float(rules(g).cap_skill) * skill(g, wid)))


static func courier_cap(g, wid: String) -> int:
	return int(rules(g).courier_cap_base) + int(round(float(rules(g).courier_cap_skill) * skill(g, wid)))


## Chance that one trip ends in a bust. `mult` scales the raw chance (couriers are rarer targets).
static func bust_chance(g, wid: String, mult := 1.0) -> float:
	var r := rules(g)
	var p := float(r.bust_base) + float(g.heat) / float(g.data.heat.max) * float(r.bust_heat) - float(r.bust_skill) * skill(g, wid)
	return clampf(p * mult, float(r.get("bust_min", 0.0)), float(r.bust_max))


## Best courier on the payroll (skill), -1 if none.
static func best_courier(g) -> float:
	var best := -1.0
	for w in g.workers:
		var c := Workers.candidate(g, w.id)
		if c.role == "courier":
			best = maxf(best, float(c.skill))
	return best


## Multiplier for the fee of a dead-drop courier run (1.0 without a courier on the payroll).
static func drop_fee_mult(g) -> float:
	var s := best_courier(g)
	return 1.0 if s < 0.0 else clampf(1.0 - float(rules(g).drop_fee_discount) * s, 0.1, 1.0)


## Multiplier for the theft chance of a dead-drop courier run.
static func drop_theft_mult(g) -> float:
	var s := best_courier(g)
	return 1.0 if s < 0.0 else clampf(1.0 - float(rules(g).drop_theft_cut) * s, 0.1, 1.0)


# ---------------------------------------------------------------- routes

static func route(g, estate_id: String) -> Dictionary:
	return g.dealers.routes.get(estate_id, {})


## dir "off" clears the route. "to_estate" needs another owned estate as target.
static func set_route(g, estate_id: String, dir: String, target: String) -> Dictionary:
	if not g.estates.has(estate_id):
		return g._fail("You don't own that.")
	if dir == "off":
		g.dealers.routes.erase(estate_id)
		g._emit("courier_route", {"estate": estate_id})
		return g._ok("Courier route cleared.")
	if not dir in DIRS:
		return g._fail("Unknown route.")
	if dir == "to_estate" and (target == estate_id or not g.estates.has(target)):
		return g._fail("Pick another estate of yours as the target.")
	g.dealers.routes[estate_id] = {"dir": dir, "target": target if dir == "to_estate" else ""}
	g._emit("courier_route", {"estate": estate_id})
	return g._ok("Courier route set.")


static func route_text(g, estate_id: String) -> String:
	var r := route(g, estate_id)
	match str(r.get("dir", "")):
		"to_hub":
			return "Estate -> hub stash"
		"from_hub":
			return "Hub stash -> estate"
		"to_estate":
			return "-> %s" % g.data.estates[r.target].name
	return "No route"


# ---------------------------------------------------------------- simulation

static func tick(g, dt: float) -> void:
	if g.workers.is_empty():
		return
	for eid in g.estates.keys():
		var e: Dictionary = g.estates[eid]
		Workers.ensure(e)
		var dealer := Workers.at(g, eid, "dealer")
		if not dealer.is_empty():
			_run(g, "d_" + eid, dt, float(rules(g).sell_seconds) / (0.5 + skill(g, dealer.id)), func(): return _dealer_trip(g, eid, e, dealer))
		else:
			g.dealers.timers.erase("d_" + eid)
		var courier := Workers.at(g, eid, "courier")
		if not courier.is_empty() and g.dealers.routes.has(eid):
			_run(g, "c_" + eid, dt, float(rules(g).courier_seconds) / (0.5 + skill(g, courier.id)), func(): return _courier_trip(g, eid, e, courier))
		else:
			g.dealers.timers.erase("c_" + eid)


## Advances a trip timer; `trip` returns false when there was nothing to do (idle time is not banked).
static func _run(g, key: String, dt: float, every: float, trip: Callable) -> void:
	var t := float(g.dealers.timers.get(key, 0.0)) + dt
	var guard := 0
	while t >= every and guard < 50:
		guard += 1
		t -= every
		if not trip.call():
			t = 0.0
			break
	g.dealers.timers[key] = t


static func _products(e: Dictionary) -> Array:
	var r: Array = []
	for src in [e.storage, e.out]:
		for k in src:
			if Mixing.is_product(k) and int(src[k]) > 0:
				r.append(k)
	return r


static func _stock(e: Dictionary, key: String) -> int:
	return int(e.storage.get(key, 0)) + int(e.out.get(key, 0))


## Takes up to n of `key` out of the shelf (tray first); returns what was taken.
static func _take(g, e: Dictionary, key: String, n: int) -> int:
	var got := 0
	for src in [e.out, e.storage]:
		var m := mini(n - got, int(src.get(key, 0)))
		if m > 0:
			g._add(src, key, -m)
			got += m
	return got


static func _system_of(g, eid: String) -> String:
	var loc: String = str(g.data.estates[eid].get("location", ""))
	return str(g.data.locations[loc].system) if g.data.locations.has(loc) else g.system


## Best (key, contact) pair for a sale: highest price among known, ready customers in the system who prefer the product.
static func pick_sale(g, eid: String, e: Dictionary) -> Dictionary:
	var sys := _system_of(g, eid)
	var best := {}
	var best_price := 0
	for key in _products(e):
		var p := Mixing.parse_key(key)
		for c in g.data.contacts:
			if not p.base in c.get("prefers", []) or not g.data.locations.has(c.location) or str(g.data.locations[c.location].system) != sys:
				continue
			if not bool(People.state(g, c.id).known) or not g.contact_ready(c.id):
				continue
			var price: int = g.sell_price(key, c.id, c.location)
			if price > best_price:
				best_price = price
				best = {"key": key, "contact": c.id, "price": price}
	return best


static func _dealer_trip(g, eid: String, e: Dictionary, w: Dictionary) -> bool:
	var pick := pick_sale(g, eid, e)
	if pick.is_empty():
		return false
	var c: Dictionary = g.contact(pick.contact)
	var p := Mixing.parse_key(pick.key)
	var qty := mini(mini(_stock(e, pick.key), dealer_cap(g, w.id)), int(c.get("max_units", 1)))
	if qty <= 0:
		return false
	var who := str(Workers.candidate(g, w.id).name)
	var st: Dictionary = g.dealers.stats
	_take(g, e, pick.key, qty)
	if g.rng.randf() < bust_chance(g, w.id):
		_bust(g, eid, w, qty, g.heat_mult(p.base), "%s was picked up on the way to %s with %d × %s." % [who, c.name, qty, g.item_name(pick.key)])
		return true
	var gross: int = int(pick.price) * qty
	var share := int(round(gross * cut(g, w.id)))
	g.credits += gross - share
	g.stats.earned += gross - share
	g.stats.units_sold += qty
	st.sales += 1
	st.units += qty
	st.gross += gross
	st.cut += share
	var dm: Dictionary = g.demand.get(c.location, {})
	if dm.has(p.base):
		dm[p.base] = maxf(float(dm[p.base]) - float(g.data.market.saturation_per_unit) * qty, float(g.data.market.min_demand))
	People.record_deal(g, c.id, pick.key, qty, gross, p)
	g.contact_ready_at[c.id] = g.total_time + float(g.data.market.contact_cooldown)
	g.add_heat(float(g.data.locations[c.location].heat_per_unit) * qty * g.heat_mult(p.base) * float(rules(g).heat_mult))
	g.dealers.last[eid] = "%s sold %d × %s to %s: %d cr (his cut %d)." % [who, qty, g.item_name(pick.key), c.name, gross - share, share]
	g._emit("dealer_sale", {"estate": eid, "worker": w.id, "contact": c.id, "qty": qty, "credits": gross - share, "cut": share})
	return true


## Shared bust outcome: heat, loss stats, and the worker is lost for good or loses loyalty.
static func _bust(g, eid: String, w: Dictionary, qty: int, hm: float, text: String) -> void:
	var st: Dictionary = g.dealers.stats
	st.busts += 1
	st.lost_units += qty
	g.add_heat(float(rules(g).bust_heat_units) * qty * hm)
	g.dealers.last[eid] = text
	var gone: bool = g.rng.randf() < float(rules(g).lose_dealer)
	if not gone:
		w.loyalty = float(w.loyalty) - float(rules(g).bust_loyalty)
		gone = float(w.loyalty) <= 0.0
	g._emit("dealer_bust", {"estate": eid, "worker": w.id, "qty": qty, "lost": gone})
	if gone:
		g.workers.erase(w)
		g.dealers.last[eid] += " They are gone."
		g._emit("worker_left", {"worker": w.id, "reason": "busted"})


static func _courier_trip(g, eid: String, e: Dictionary, w: Dictionary) -> bool:
	var r := route(g, eid)
	var cap := courier_cap(g, w.id)
	var who := str(Workers.candidate(g, w.id).name)
	var moves: Array = []  # [item, qty, is_product]
	var dest: Dictionary = g.stash
	match str(r.dir):
		"to_hub":
			moves = _gather(e, cap)
		"to_estate":
			if not g.estates.has(str(r.target)):
				return false
			dest = g.estates[r.target].storage
			moves = _gather(e, cap)
		"from_hub":
			dest = e.storage
			moves = _from_hub(g, e, cap)
	if moves.is_empty():
		return false
	var units := 0
	var hm := 1.0
	for m in moves:
		units += int(m[1])
		if m[2]:
			hm = maxf(hm, g.heat_mult(Mixing.parse_key(m[0]).base))
	if r.dir == "from_hub":
		for m in moves:
			g._add(g.stash, m[0], -int(m[1]))
	else:
		for m in moves:
			_take(g, e, m[0], int(m[1]))
	if g.rng.randf() < bust_chance(g, w.id, float(rules(g).courier_bust_mult)):
		_bust(g, eid, w, units, hm, "%s was stopped with %d units. The load is gone." % [who, units])
		return true
	for m in moves:
		g._add(dest, m[0], int(m[1]))
	g.dealers.stats.trips += 1
	g.dealers.last[eid] = "%s moved %d units (%s)." % [who, units, route_text(g, eid).to_lower()]
	g._emit("courier_trip", {"estate": eid, "worker": w.id, "units": units})
	return true


## Products on the shelf and tray, up to cap units: [[key, qty, true], ...].
static func _gather(e: Dictionary, cap: int) -> Array:
	var r: Array = []
	for k in _products(e):
		if cap <= 0:
			break
		var n := mini(_stock(e, k), cap)
		r.append([k, n, true])
		cap -= n
	return r


## From the hub stash: products first (for the dealer), then the raws the estate recipe still lacks.
static func _from_hub(g, e: Dictionary, cap: int) -> Array:
	var r: Array = []
	for k in g.stash.keys():
		if cap <= 0:
			break
		if Mixing.is_product(k) and int(g.stash[k]) > 0:
			var n := mini(int(g.stash[k]), cap)
			r.append([k, n, true])
			cap -= n
	if not e.recipe.is_empty() and cap > 0:
		var need: Dictionary = g.batch_needs(e.recipe.base, e.recipe.additives, mini(int(e.recipe.qty), g.lab_capacity()))
		for k in need:
			var lack: int = int(need[k]) - int(e.storage.get(k, 0)) - int(e.bench.get(k, 0))
			var n := mini(mini(lack, int(g.stash.get(k, 0))), cap)
			if n > 0:
				r.append([k, n, false])
				cap -= n
	return r


# ---------------------------------------------------------------- save / load

static func to_save(g) -> Dictionary:
	var d: Dictionary = g.dealers.duplicate(true)
	for k in d.timers:
		d.timers[k] = snappedf(float(d.timers[k]), 0.01)
	return d


static func from_save(g, d: Dictionary) -> void:
	g.dealers = fresh()
	var src: Dictionary = d.get("dealers", {})
	for eid in src.get("routes", {}):
		var r: Dictionary = src.routes[eid]
		var dir := str(r.get("dir", ""))
		var target := str(r.get("target", ""))
		if not g.estates.has(eid) or not dir in DIRS:
			continue
		if dir == "to_estate" and (target == eid or not g.estates.has(target)):
			continue
		g.dealers.routes[eid] = {"dir": dir, "target": target if dir == "to_estate" else ""}
	for k in src.get("timers", {}):
		g.dealers.timers[str(k)] = float(src.timers[k])
	for k in src.get("last", {}):
		g.dealers.last[str(k)] = str(src.last[k])
	for k in STAT_KEYS:
		g.dealers.stats[k] = int(src.get("stats", {}).get(k, 0))
