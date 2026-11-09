extends RefCounted
## Automation machines (C2): Auto-Trimmer, Drip Mixer, Packing Machine. Estate buildings that run one station step of
## the production line on their own: no minigame, a fixed score below what a good hand reaches (content.json
## "machines": station, score, run_cost per unit), paid in credits each run. A machine counts as its station when an
## estate is checked for a recipe (Game.missing_stations_in), the player uses it on foot through the same tray as the
## tables (Bench), and lab hands run a machine-only step with the machine's score (Workers).
## Machines are also "stations" and "buildables" in the data (flag "machine"), so placing, kits, refunds and saving
## need nothing special; they are just not part of Production's station_order. Pure functions on a Game.

const Bench = preload("res://scripts/core/bench.gd")


static func defs(data: Dictionary) -> Dictionary:
	return data.get("machines", {})


static func is_machine(data: Dictionary, id: String) -> bool:
	return defs(data).has(id)


## The line station a building id stands for: a machine's station, any other id itself.
static func station_of(data: Dictionary, id: String) -> String:
	return str(defs(data)[id].station) if is_machine(data, id) else id


## Station ids a building provides to an estate: itself, plus the station a machine automates.
static func provides(data: Dictionary, id: String) -> Array:
	return [id, station_of(data, id)] if is_machine(data, id) else [id]


static func score(data: Dictionary, id: String) -> float:
	return float(defs(data)[id].score) if is_machine(data, id) else 0.0


## Credits one run costs for a tray of `qty` units.
static func cost_for(data: Dictionary, id: String, qty: int) -> int:
	return int(ceil(float(defs(data)[id].run_cost) * qty)) if is_machine(data, id) else 0


## Index of the first machine `id` in the estate's buildings, -1 when there is none.
static func find(g, estate: String, id: String) -> int:
	var list: Array = g.estates.get(estate, {}).get("buildings", [])
	for i in list.size():
		if list[i].id == id:
			return i
	return -1


## Runs the machine `id` in the estate the player stands in. With no tray and a `base`, it starts one first (only
## machines of a prep station can: the Auto-Trimmer for weed). Otherwise the tray's next step has to be this machine's
## station. Mixing: pick the additives with Bench.mix first. Takes cost_for(...) credits, then records the machine's
## score like a minigame result (the last step queues the batch).
static func run(g, id: String, base: String = "", qty: int = 0) -> Dictionary:
	if not is_machine(g.data, id):
		return g._fail("That is not a machine.")
	if not g.estates.has(g.inside_estate):
		return g._fail("Machines run inside your estates.")
	var idx := find(g, g.inside_estate, id)
	if idx < 0:
		return g._fail("No %s here." % g.data.stations[id].name)
	var station := station_of(g.data, id)
	var t := Bench.tray(g)
	var units := qty
	if t.is_empty():
		if base == "":
			return g._fail("No tray on the go. Start a batch first.")
		if units <= 0:
			return g._fail("Nothing to run.")
	else:
		units = int(t.qty)
		if Bench.next_station(g, t) != station:
			if station == Bench.MIX and Bench.can_mix(g, t):
				return g._fail("Choose the additives first (or skip them).")
			return g._fail("Your tray does not need the %s right now." % g.data.stations[station].name)
	var cost := cost_for(g.data, id, units)
	if g.credits < cost:
		return g._fail("Running the %s costs %d cr." % [g.data.stations[id].name, cost])
	if t.is_empty():
		var b: Dictionary = Bench.begin(g, station, base, units)
		if not b.ok:
			return b
	var sc := score(g.data, id)
	var r: Dictionary = Bench.record(g, station, sc)
	if not r.ok:
		return r
	g.credits -= cost
	g.stats.machine_runs = int(g.stats.get("machine_runs", 0)) + 1
	var bld: Dictionary = g.estates[g.inside_estate].buildings[idx]
	bld.runs = int(bld.get("runs", 0)) + 1
	g._emit("machine_run", {"estate": g.inside_estate, "machine": id, "station": station, "qty": units, "score": sc, "cost": cost})
	return g._ok("%s ran for %d cr (%d%%). %s" % [g.data.stations[id].name, cost, int(sc * 100.0), r.msg])


## Score a lab hand's batch gets at `station` when the estate (its `buildings`) only has a machine for it:
## the machine's score. -1.0 when a hand-operated station exists (the worker's skill counts) or nothing covers it.
static func worker_score(data: Dictionary, buildings: Array, station: String, _skill: float) -> float:
	var m := _machine_only(data, buildings, station)
	return score(data, m) if m != "" else -1.0


## Credits a lab hand pays for the machine-only steps of `line` with `qty` units.
static func worker_cost(data: Dictionary, buildings: Array, line: Array, qty: int) -> int:
	var c := 0
	for st in line:
		var m := _machine_only(data, buildings, st)
		if m != "":
			c += cost_for(data, m, qty)
	return c


## Time factor for a lab hand's batch: every machine-only step of `line` cuts the cook time by the machine's "speed"
## (content.json "machines"), so a machine trades grade (fixed score) and a per-unit fee for throughput. 1.0 = no machine.
static func worker_time_mult(data: Dictionary, buildings: Array, line: Array) -> float:
	var f := 1.0
	for st in line:
		var m := _machine_only(data, buildings, st)
		if m != "":
			f *= 1.0 - clampf(float(defs(data)[m].get("speed", 0.0)), 0.0, 0.9)
	return f


## Counts a lab hand's machine runs (stats and per-machine counters) after they were paid.
static func worker_ran(g, buildings: Array, line: Array) -> void:
	for st in line:
		var m := _machine_only(g.data, buildings, st)
		if m == "":
			continue
		for b in buildings:
			if b.id == m:
				b.runs = int(b.get("runs", 0)) + 1
				break
		g.stats.machine_runs = int(g.stats.get("machine_runs", 0)) + 1


## Id of the machine that covers `station` when no hand-operated station of it stands in the estate, else "".
static func _machine_only(data: Dictionary, buildings: Array, station: String) -> String:
	var found := ""
	for b in buildings:
		if b.id == station:
			return ""
		if found == "" and is_machine(data, b.id) and station_of(data, b.id) == station:
			found = b.id
	return found
