extends RefCounted
## Courier drones (P5). You buy drones and tie each one to an owned estate with a route:
##  - to_port: every trip carries finished product (output tray first, then shelf) from the estate to the hub stash,
##    where collect_stash() loads it at the spaceport;
##  - to_estate: every trip carries what the estate's auto recipe still lacks (bench + shelf) from the hub stash to the
##    estate shelf (raws and additives you ordered "to the stash", or dropped there).
## A trip takes `trip_seconds` (+ `far_seconds` when the estate is in another system); a drone only flies when there is
## something to carry. Each trip can be shot down (more likely with heat): the cargo and the drone are gone.
## Upkeep is charged each new day; a drone you cannot pay stays grounded until the next day it can be paid.
## State: Game.drones [{id, estate, route, t, grounded}] (saved), Game.drone_seq. Numbers: content.json "drones".

const Mixing = preload("res://scripts/core/mixing.gd")

const ROUTES := ["to_port", "to_estate"]


static func cfg(g) -> Dictionary:
	return g.data.get("drones", {})


static func route_name(route: String) -> String:
	return "Estate to port" if route == "to_port" else "Port to estate"


static func find(g, id: int) -> Dictionary:
	for d in g.drones:
		if int(d.id) == id:
			return d
	return {}


static func at_estate(g, estate_id: String) -> Array:
	return g.drones.filter(func(d): return d.estate == estate_id)


## Estates a drone can serve: owned and fixed in place (the ship's bay moves).
static func eligible(g, estate_id: String) -> bool:
	return g.estates.has(estate_id) and g.data.estates.has(estate_id) and not g.data.estates[estate_id].get("ship", false)


static func trip_seconds(g, estate_id: String) -> float:
	var s := float(cfg(g).get("trip_seconds", 45.0))
	if g.loc_system(g.data.estates[estate_id].location) != g.loc_system(str(g.data.start.location)):
		s += float(cfg(g).get("far_seconds", 45.0))
	return s


static func loss_chance(g) -> float:
	return clampf(float(cfg(g).get("loss_base", 0.01)) + float(cfg(g).get("loss_per_heat", 0.0008)) * g.heat, 0.0, 0.9)


static func upkeep_total(g) -> int:
	return g.drones.size() * int(cfg(g).get("upkeep", 15))


static func buy(g, estate_id: String, route: String) -> Dictionary:
	var c := cfg(g)
	if not eligible(g, estate_id):
		return g._fail("Drones only serve estates you own on solid ground.")
	if not route in ROUTES:
		return g._fail("Unknown route.")
	if g.drones.size() >= int(c.get("max_total", 4)):
		return g._fail("You can run at most %d drones." % int(c.get("max_total", 4)))
	if at_estate(g, estate_id).size() >= int(c.get("max_per_estate", 2)):
		return g._fail("%s has no room for more drone pads." % g.data.estates[estate_id].name)
	if g.credits < int(c.price):
		return g._fail("A drone costs %d cr." % int(c.price))
	g.credits -= int(c.price)
	g.drone_seq += 1
	g.drones.append({"id": g.drone_seq, "estate": estate_id, "route": route, "t": 0.0, "grounded": false})
	g._emit("drone_bought", {"estate": estate_id, "route": route})
	return g._ok("Drone #%d flies %s at %s (%d cr)." % [g.drone_seq, route_name(route).to_lower(), g.data.estates[estate_id].name, int(c.price)])


static func set_route(g, id: int, route: String) -> Dictionary:
	var d := find(g, id)
	if d.is_empty() or not route in ROUTES:
		return g._fail("No such drone.")
	d.route = route
	d.t = 0.0
	g._emit("drone_route", {"drone": id, "route": route})
	return g._ok("Drone #%d now flies %s." % [id, route_name(route).to_lower()])


static func scrap(g, id: int) -> Dictionary:
	var d := find(g, id)
	if d.is_empty():
		return g._fail("No such drone.")
	var back := int(round(int(cfg(g).price) * float(cfg(g).get("scrap_refund", 0.4))))
	g.credits += back
	g.drones.erase(d)
	g._emit("drone_scrapped", {"drone": id})
	return g._ok("Drone #%d scrapped for %d cr." % [id, back])


## What a drone would carry on its next trip: item -> qty (empty = nothing to do).
static func load_plan(g, d: Dictionary) -> Dictionary:
	var e: Dictionary = g.estates.get(str(d.estate), {})
	var cap := int(cfg(g).get("capacity", 12))
	var plan := {}
	if e.is_empty():
		return plan
	if d.route == "to_port":
		for src in [e.get("out", {}), e.get("storage", {})]:
			for k in src:
				if cap <= 0:
					break
				if not Mixing.is_product(k) or int(src[k]) <= 0:
					continue
				var n := mini(int(src[k]), cap)
				if n > 0:
					plan[k] = int(plan.get(k, 0)) + n
					cap -= n
	else:
		var r: Dictionary = e.get("recipe", {})
		if r.is_empty():
			return plan
		var need: Dictionary = g.batch_needs(r.base, r.additives, mini(int(r.qty), g.lab_capacity()))
		for k in need:
			var have := int(e.bench.get(k, 0)) + int(e.storage.get(k, 0))
			var n := mini(mini(int(need[k]) - have, int(g.stash.get(k, 0))), cap)
			if n > 0:
				plan[k] = n
				cap -= n
	return plan


## "" while flying or ready, else why the drone sits idle.
static func status(g, d: Dictionary) -> String:
	if d.grounded:
		return "Grounded: upkeep unpaid."
	if load_plan(g, d).is_empty():
		if d.route == "to_port":
			return "Waiting for finished product."
		var e: Dictionary = g.estates.get(str(d.estate), {})
		return "No auto recipe set." if e.get("recipe", {}).is_empty() else "Waiting for supplies in the stash."
	return ""


static func tick(g, dt: float) -> void:
	if g.drones.is_empty():
		return
	for d in g.drones.duplicate():
		if d.grounded or not g.estates.has(d.estate) or g.estate_locked(d.estate):
			continue
		var trip := trip_seconds(g, d.estate)
		d.t = minf(float(d.t) + dt, trip)
		if float(d.t) < trip:
			continue
		var plan := load_plan(g, d)
		if plan.is_empty():
			continue  # parked at the pad, ready to leave the moment there is cargo
		d.t = 0.0
		_fly(g, d, plan)


static func _fly(g, d: Dictionary, plan: Dictionary) -> void:
	var e: Dictionary = g.estates[d.estate]
	var qty := 0
	for k in plan:
		qty += int(plan[k])
		if d.route == "to_port":
			var from_out := mini(int(e.out.get(k, 0)), int(plan[k]))
			g._add(e.out, k, -from_out)
			g._add(e.storage, k, -(int(plan[k]) - from_out))
		else:
			g._add(g.stash, k, -int(plan[k]))
	if g.rng.randf() < loss_chance(g):
		g.drones.erase(d)
		g.stats["drones_lost"] = int(g.stats.get("drones_lost", 0)) + 1
		g._emit("drone_lost", {"drone": d.id, "estate": d.estate, "qty": qty})
		return
	for k in plan:
		g._add(g.stash if d.route == "to_port" else e.storage, k, int(plan[k]))
	g.stats["drone_trips"] = int(g.stats.get("drone_trips", 0)) + 1
	g.stats["drone_units"] = int(g.stats.get("drone_units", 0)) + qty
	g._emit("drone_delivered", {"drone": d.id, "estate": d.estate, "route": d.route, "qty": qty})


## Called from Game._new_day: upkeep. A drone you cannot pay is grounded until a day it can be paid.
static func new_day(g) -> void:
	var up := int(cfg(g).get("upkeep", 15))
	var paid := 0
	for d in g.drones:
		if g.credits >= up:
			g.credits -= up
			paid += up
			d.grounded = false
		else:
			if not d.grounded:
				g._emit("drone_grounded", {"drone": d.id})
			d.grounded = true
	if paid > 0:
		g.stats["drone_upkeep"] = int(g.stats.get("drone_upkeep", 0)) + paid


static func to_save(g) -> Array:
	return g.drones.duplicate(true)


static func from_save(g, list: Array) -> void:
	g.drones = []
	g.drone_seq = 0
	for x in list:
		var est := str(x.get("estate", ""))
		var route := str(x.get("route", ""))
		if not eligible(g, est) or not route in ROUTES:
			continue
		g.drones.append({"id": int(x.get("id", 0)), "estate": est, "route": route, "t": float(x.get("t", 0.0)), "grounded": bool(x.get("grounded", false))})
		g.drone_seq = maxi(g.drone_seq, int(x.get("id", 0)))
