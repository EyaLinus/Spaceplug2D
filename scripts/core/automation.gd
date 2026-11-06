extends RefCounted
## Automation machines (C2): estate equipment that runs one station step of the tray on its own, without a worker
## and without the player at the table. Data: content.json "automation" -> machines {id: {name, station, cost, score,
## seconds, hint}}. A machine fixes its station's minigame score at `score` (always below a good play, so hand work
## still pays: Premium starts at 0.72), takes `seconds` per step and goes through Bench.record like a played step.
## Installed machines live in the estate dict (`machines` ids, saved) next to the progress of the step in hand
## (`auto_for` station, `auto_t` seconds). Static helpers over a Game, no autoloads.

const Bench = preload("res://scripts/core/bench.gd")


static func cfg(g) -> Dictionary:
	return g.data.get("automation", {})


static func machines(g) -> Dictionary:
	return cfg(g).get("machines", {})


static func ensure(e: Dictionary) -> void:
	if not e.has("machines"):
		e["machines"] = []
	if not e.has("auto_for"):
		e["auto_for"] = ""
	if not e.has("auto_t"):
		e["auto_t"] = 0.0


static func load_estate(src: Dictionary, e: Dictionary) -> void:
	ensure(e)
	e.machines = []
	for m in src.get("machines", []):
		if not str(m) in e.machines:
			e.machines.append(str(m))
	e.auto_for = str(src.get("auto_for", ""))
	e.auto_t = float(src.get("auto_t", 0.0))


## Drops machines the content no longer knows (after loading a save).
static func prune(g) -> void:
	for id in g.estates:
		var keep: Array = []
		for m in g.estates[id].get("machines", []):
			if machines(g).has(m):
				keep.append(m)
		g.estates[id].machines = keep


static func installed(g, estate_id: String, machine: String) -> bool:
	return machine in g.estates.get(estate_id, {}).get("machines", [])


## The installed machine that runs `station` in the estate, "" if none.
static func machine_for(g, estate_id: String, station: String) -> String:
	for m in g.estates.get(estate_id, {}).get("machines", []):
		if machines(g).has(m) and machines(g)[m].station == station:
			return m
	return ""


## Seconds one machine step takes.
static func step_seconds(g, machine: String) -> float:
	return float(machines(g)[machine].seconds)


static func install(g, estate_id: String, machine: String) -> Dictionary:
	if not g.estates.has(estate_id):
		return g._fail("You don't own that.")
	if not g.estate_reachable(estate_id):
		return g._fail("You can only fit out the cargo bay while docked.")
	if not machines(g).has(machine):
		return g._fail("Can't build that.")
	var m: Dictionary = machines(g)[machine]
	if machine_for(g, estate_id, m.station) != "":
		return g._fail("There is already a machine for the %s." % g.data.stations[m.station].name)
	var cost := int(m.cost)
	if g.credits < cost:
		return g._fail("%s costs %d cr." % [m.name, cost])
	g.credits -= cost
	ensure(g.estates[estate_id])
	g.estates[estate_id].machines.append(machine)
	g._emit("machine_installed", {"estate": estate_id, "machine": machine})
	return g._ok("%s installed." % m.name)


static func remove(g, estate_id: String, machine: String) -> Dictionary:
	if not installed(g, estate_id, machine) or not g.estate_reachable(estate_id):
		return g._fail("Nothing to remove.")
	var e: Dictionary = g.estates[estate_id]
	e.machines.erase(machine)
	if e.auto_for == machines(g)[machine].station:
		e.auto_for = ""
		e.auto_t = 0.0
	var refund := int(round(int(machines(g)[machine].cost) * float(cfg(g).get("refund", 0.5))))
	g.credits += refund
	g._emit("machine_removed", {"estate": estate_id, "machine": machine})
	return g._ok("%s taken out, sold the parts for %d cr." % [machines(g)[machine].name, refund])


## Progress 0..1 of the machine step in hand (0 when idle).
static func progress(g, estate_id: String) -> float:
	var e: Dictionary = g.estates.get(estate_id, {})
	var st := str(e.get("auto_for", ""))
	var m := machine_for(g, estate_id, st) if st != "" else ""
	if m == "":
		return 0.0
	return clampf(float(e.auto_t) / step_seconds(g, m), 0.0, 1.0)


static func tick(g, dt: float) -> void:
	for id in g.estates.keys():
		var e: Dictionary = g.estates[id]
		if e.get("machines", []).is_empty():
			continue
		var t: Dictionary = Bench.tray(g, id)
		var nxt := Bench.next_station(g, t) if not t.is_empty() else ""
		var m := machine_for(g, id, nxt) if nxt != "" else ""
		if m == "" or not g.estate_reachable(id):
			e.auto_for = ""
			e.auto_t = 0.0
			continue
		if e.auto_for != nxt:
			e.auto_for = nxt
			e.auto_t = 0.0
		e.auto_t = float(e.auto_t) + dt
		if e.auto_t >= step_seconds(g, m):
			e.auto_for = ""
			e.auto_t = 0.0
			Bench.record(g, nxt, float(machines(g)[m].score), id)
			g.stats["machine_steps"] = int(g.stats.get("machine_steps", 0)) + 1
			g._emit("machine_step", {"estate": id, "machine": m, "station": nxt})
