extends RefCounted
## Galaxy Map + Jump Drive (phone app "Map"). Pure functions on a Game plus one runtime field, `Game.jump_plan`.
##
## Lanes are the jump gates (locations with "jump_to") between the systems of content.json "systems". The map shows
## a heat overlay (patrol pressure per system, sale heat per location), price comparison (cheapest raws / best
## demand per location) and plans routes over the lanes. The jump drive jumps from anywhere in flight (the gate
## stays the instant, free-flying way): you plan a route, the drive charges for `jump.charge_seconds` (engine
## upgrades shorten it), then each hop pays the gate toll and takes the usual travel time. Charging is cancelled by
## docking, a bust, a manual gate jump or the player; a ready drive waits for main.gd to engage it (hyperspace VFX).
##
## jump_plan = {} (idle) or {route: [system ids, route[0] = current system], to, charge, need, ready, busts}

const Mixing = preload("res://scripts/core/mixing.gd")
const Cartels = preload("res://scripts/core/cartels.gd")


static func rules(g) -> Dictionary:
	return g.data.get("jump", {})


# ---------------------------------------------------------------- lanes and routes

## Jump gates in a system that lead to `to_sys`, or all gates of the system when `to_sys` is "". Location ids.
static func gates(g, from_sys: String, to_sys := "") -> Array:
	var r: Array = []
	for l in g.locations_in(from_sys):
		var ld: Dictionary = g.data.locations[l]
		if ld.has("jump_to") and (to_sys == "" or str(ld.jump_to) == to_sys):
			r.append(l)
	return r


## Systems one jump away.
static func neighbours(g, sys: String) -> Array:
	var r: Array = []
	for gate in gates(g, sys):
		var to := str(g.data.locations[gate].jump_to)
		if not r.has(to) and g.data.systems.has(to):
			r.append(to)
	return r


## Every lane once: [{a, b}] (gates come in two-way pairs; a one-way gate still counts).
static func lanes(g) -> Array:
	var r: Array = []
	var seen := {}
	for s in g.data.systems:
		for n in neighbours(g, s):
			var k := "%s|%s" % ([s, n] if str(s) < str(n) else [n, s])
			if not seen.has(k):
				seen[k] = true
				r.append({"a": str(s), "b": str(n)})
	return r


## Shortest route over the lanes (breadth first) including both ends; [] when there is none.
static func route(g, from: String, to: String) -> Array:
	if not g.data.systems.has(from) or not g.data.systems.has(to):
		return []
	if from == to:
		return [from]
	var prev := {from: ""}
	var queue: Array = [from]
	while not queue.is_empty():
		var s: String = queue.pop_front()
		for n in neighbours(g, s):
			if prev.has(n):
				continue
			prev[n] = s
			if n == to:
				var path: Array = [to]
				var cur := s
				while cur != "":
					path.push_front(cur)
					cur = prev[cur]
				return path
			queue.append(n)
	return []


## Seconds the drive charges before a hop: engine upgrades cut it.
static func charge_seconds(g) -> float:
	var j := rules(g)
	var cut := float(j.get("charge_engine_cut", 0.0)) * float(g.upgrades.engine)
	return maxf(float(j.get("min_charge", 1.0)), float(j.get("charge_seconds", 5.0)) * (1.0 - cut))


## What a trip from the current system to `to` costs: {ok, msg, route, hops, fee, travel, charge, total_seconds}.
static func plan(g, to: String) -> Dictionary:
	var rt := route(g, g.system, to)
	if rt.size() < 2:
		return {"ok": false, "msg": "You are already there." if to == g.system else "No lane leads there.", "route": rt,
			"hops": 0, "fee": 0, "travel": 0.0, "charge": 0.0, "total_seconds": 0.0}
	var hops := rt.size() - 1
	var fee := hops * int(rules(g).get("fee", 0))
	var travel := hops * float(rules(g).get("seconds", 0.0))
	var charge := hops * charge_seconds(g)
	return {"ok": true, "msg": "", "route": rt, "hops": hops, "fee": fee, "travel": travel, "charge": charge, "total_seconds": travel + charge}


# ---------------------------------------------------------------- heat overlay

## Heat the patrols of `sys` react to. One global heat today; scaled by how thinly the system is patrolled.
## (F1 "Heat II" replaces this with a per-system value.)
static func system_heat(g, sys: String) -> float:
	return g.heat * float(g.system_data(sys).get("patrol_mult", 1.0))


## 0..1 for colouring the map.
static func heat_level(g, sys: String) -> float:
	return clampf(system_heat(g, sys) / float(g.data.heat.max), 0.0, 1.0)


## Patrol ships that would fly in `sys` at the current heat (same formula as Game.patrol_count).
static func patrols_in(g, sys: String) -> int:
	var h: Dictionary = g.data.heat
	var n := int(h.patrol_base) + int(g.heat / float(h.patrol_per_heat))
	n = int(n * float(g.system_data(sys).get("patrol_mult", 1.0)))
	return clampi(n, 0, int(h.patrol_max))


## Heat per sold unit and walking police density for a location: {sale_heat, security}; security -1 = no surface.
static func location_risk(g, loc: String) -> Dictionary:
	var sec: float = float(g.data.surfaces[loc].get("security", 1.0)) if g.data.get("surfaces", {}).has(loc) else -1.0
	return {"sale_heat": float(g.data.locations[loc].get("heat_per_unit", 0.0)), "security": sec}


# ---------------------------------------------------------------- price comparison

## What raws and additives cost where: [{item, name, kind, offers: [{loc, system, price}] cheapest first}].
static func buy_table(g) -> Array:
	var r: Array = []
	var items: Array = []
	for k in g.data.raws:
		items.append([k, g.data.raws[k].name, "raw"])
	for k in g.data.additives:
		items.append([k, g.data.additives[k].name, "additive"])
	for it in items:
		var offers: Array = []
		for loc in g.data.locations:
			var p: int = g.buy_price(it[0], loc)
			if p >= 0:
				offers.append({"loc": loc, "system": g.loc_system(loc), "price": p})
		offers.sort_custom(func(a, b): return a.price < b.price)
		if not offers.is_empty():
			r.append({"item": it[0], "name": it[1], "kind": it[2], "offers": offers})
	return r


## What a plain (no additives) product of each drug fetches per unit where, with today's saturated demand:
## [{base, name, offers: [{loc, system, price, fence}]} best first]. Contact premiums and the fence cut are not included.
static func sell_table(g) -> Array:
	var r: Array = []
	for b in g.data.bases:
		var base: Dictionary = g.data.bases[b]
		var v := Mixing.value(g.data, Mixing.key(b, [base.innate]))
		var offers: Array = []
		for loc in g.data.locations:
			var d: float = float(g.demand.get(loc, {}).get(b, 0.0))
			if d > 0.0:
				offers.append({"loc": loc, "system": g.loc_system(loc), "price": int(round(v * d * Cartels.sell_mult(g, loc))), "fence": bool(g.data.locations[loc].get("fence", false))})
		offers.sort_custom(func(a, c): return a.price > c.price)
		r.append({"base": b, "name": base.name, "offers": offers})
	return r


# ---------------------------------------------------------------- jump drive

static func charging(g) -> bool:
	return not g.jump_plan.is_empty() and not g.jump_plan.get("ready", false)


static func ready(g) -> bool:
	return bool(g.jump_plan.get("ready", false))


## 0..1 charge progress of the current plan.
static func progress(g) -> float:
	if g.jump_plan.is_empty():
		return 0.0
	return clampf(float(g.jump_plan.charge) / maxf(0.01, float(g.jump_plan.need)), 0.0, 1.0)


## Plans the route to `to` and starts charging the drive (flight only).
static func start(g, to: String) -> Dictionary:
	if g.state != "playing":
		return g._fail("The game is over.")
	if g.location != "":
		return g._fail("Undock first: the drive needs open space.")
	var pl := plan(g, to)
	if not pl.ok:
		return g._fail(pl.msg)
	if g.credits < int(pl.fee):
		return g._fail("The trip costs %d cr in gate tolls." % int(pl.fee))
	_begin(g, pl.route, to)
	return g._ok("Jump drive charging for %s." % g.system_data(to).get("name", to))


static func _begin(g, rt: Array, to: String) -> void:
	g.jump_plan = {"route": rt.duplicate(), "to": to, "charge": 0.0, "need": charge_seconds(g), "ready": false, "busts": int(g.stats.busts)}
	g._emit("jump_charging", {"to": to})


static func cancel(g, why := "Jump drive disengaged.") -> void:
	if g.jump_plan.is_empty():
		return
	g.jump_plan = {}
	g._emit("jump_cancelled", {"why": why})


## Advances the charge (called from Game.tick). Docking, a bust or leaving the planned system cancel it.
static func tick(g, dt: float) -> void:
	var p: Dictionary = g.jump_plan
	if p.is_empty() or p.ready:
		return
	if g.location != "" or g.state != "playing":
		cancel(g, "Docking cancelled the jump.")
	elif int(g.stats.busts) != int(p.busts):
		cancel(g, "The scan interrupted the jump drive.")
	elif str(p.route[0]) != g.system:
		cancel(g, "Course changed.")
	else:
		var before := float(p.charge)
		p.charge = before + dt
		if int(before * 4.0) != int(float(p.charge) * 4.0):
			g._emit("jump_charge", {"progress": progress(g)})  # lets an open phone screen redraw its bar
		if float(p.charge) >= float(p.need):
			p.charge = p.need
			p.ready = true
			g._emit("jump_ready", {"to": p.to})


## Fires a fully charged drive: pays the toll for the next hop and jumps. Returns Game.jump's result plus
## "gate" (the gate used, for the world to place the ship) and "more" (a further hop is already charging).
static func engage(g) -> Dictionary:
	if not ready(g):
		return g._fail("The drive is not charged.")
	var rt: Array = g.jump_plan.route.duplicate()
	var to: String = g.jump_plan.to
	var gate_list := gates(g, str(rt[0]), str(rt[1]))
	g.jump_plan = {}
	if gate_list.is_empty():
		return g._fail("No gate on that lane.")
	var r: Dictionary = g.jump(gate_list[0])
	r["gate"] = gate_list[0]
	r["more"] = false
	if r.ok:
		rt.pop_front()
		if rt.size() > 1 and g.credits >= int(rules(g).get("fee", 0)):
			_begin(g, rt, to)
			r["more"] = true
	return r
