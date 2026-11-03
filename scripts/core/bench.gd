extends RefCounted
## Hands-on production on foot (G2, phase 3): a batch is a tray that you carry from station to station inside an
## estate. Start it at the prep station of the drug's line (raws leave the hold), optionally add additives at the
## Mixing Station, play every station's minigame in line order; after the last station the batch goes into the
## cook queue with the minigame scores (Production.outcome decides yield, grade, heat).
## One tray per estate, saved in Game.bench (estate id -> tray). Static helpers over a Game, no autoloads.
##
## tray = {"base", "qty", "additives": [], "done": [station ids in order], "scores": {station: 0..1}, "mixed": bool}

const Production = preload("res://scripts/core/production.gd")
const Mixing = preload("res://scripts/core/mixing.gd")

const MIX := "mixing_station"
const MAX_ADDITIVES := 3


static func tray(g, estate: String = "") -> Dictionary:
	var e := estate if estate != "" else str(g.inside_estate)
	return g.bench.get(e, {})


## Station ids of the tray's line, in order. The Mixing Station is only in it once additives were chosen; until
## the tray moves past it, it is an optional stop (see use_mode).
static func line(g, t: Dictionary) -> Array:
	return Production.stations_for(g.data, t.base, t.additives)


## The station the tray has to visit next, "" when the line is done.
static func next_station(g, t: Dictionary) -> String:
	for st in line(g, t):
		if not st in t.done:
			return st
	return ""


## True while additives can still go in: not mixed yet, every station before the Mixing Station done, none after.
static func can_mix(g, t: Dictionary) -> bool:
	if t.is_empty() or t.mixed or _after_mix_done(g, t):
		return false
	var nxt := next_station(g, t)
	var order: Array = g.data.station_order
	return nxt == "" or order.find(nxt) > order.find(MIX)


## Prep stations that can start a tray of `base` (the first station of its line).
static func starter_for(data: Dictionary, base: String) -> String:
	var l: Array = Production.stations_for(data, base, [])
	return l[0] if not l.is_empty() else ""


## Bases whose line starts at `station`.
static func bases_starting_at(data: Dictionary, station: String) -> Array:
	var r: Array = []
	for b in data.bases:
		if starter_for(data, b) == station:
			r.append(b)
	return r


## What happens when the player uses `station` in the estate they stand in:
## {"mode": "start"|"mix"|"play"|"wait", "msg": why not / hint}
## An automation machine (C2) behaves like its station and adds "auto": true: the UI runs it with Machines.run
## instead of a minigame.
static func use_mode(g, station: String) -> Dictionary:
	var machines: Dictionary = g.data.get("machines", {})
	if not machines.has(station):
		return _use_mode(g, station)
	var m := _use_mode(g, str(machines[station].station))
	m["auto"] = true
	return m


static func _use_mode(g, station: String) -> Dictionary:
	var t := tray(g)
	if t.is_empty():
		if bases_starting_at(g.data, station).is_empty():
			return {"mode": "wait", "msg": "Start a batch at a Trim Table or Precursor Scale first."}
		return {"mode": "start", "msg": ""}
	var nxt := next_station(g, t)
	if station == MIX and can_mix(g, t):
		return {"mode": "mix", "msg": ""}
	if station == nxt:
		return {"mode": "play", "msg": ""}
	if nxt == "":
		return {"mode": "wait", "msg": "This batch is done."}
	return {"mode": "wait", "msg": "Your tray of %d %s goes to the %s next." % [t.qty, g.data.bases[t.base].name, g.data.stations[nxt].name]}


## Starts a tray at `station`: checks the line, takes the raws out of the hold.
static func begin(g, station: String, base: String, qty: int) -> Dictionary:
	if not g.estates.has(g.inside_estate):
		return g._fail("Production happens inside your estates.")
	if not tray(g).is_empty():
		return g._fail("Finish the batch on your tray first.")
	if not g.data.bases.has(base) or starter_for(g.data, base) != station:
		return g._fail("That batch does not start here.")
	var chk: Dictionary = g.check_batch(base, [], qty)
	if not chk.ok:
		return chk
	var raw: String = g.data.bases[base].raw
	g._add(g.cargo, raw, -qty)
	g.bench[g.inside_estate] = {"base": base, "qty": qty, "additives": [], "done": [], "scores": {}, "mixed": false}
	g._emit("tray_started", {"base": base, "qty": qty})
	return g._ok("Tray: %d %s on the %s." % [qty, g.item_name(raw), g.data.stations[station].name])


## Puts additives (in order, max 3) into the tray at the Mixing Station; [] = skip mixing.
static func mix(g, additives: Array) -> Dictionary:
	var t := tray(g)
	if not can_mix(g, t):
		return g._fail("Nothing to mix right now.")
	if additives.size() > MAX_ADDITIVES:
		return g._fail("At most %d additives." % MAX_ADDITIVES)
	var need := {}
	for a in additives:
		if not g.data.additives.has(a):
			return g._fail("Unknown additive.")
		need[a] = int(need.get(a, 0)) + int(t.qty)
	for a in need:
		if int(g.cargo.get(a, 0)) < need[a]:
			return g._fail("Missing %s (need %d)." % [g.item_name(a), need[a]])
	if additives.is_empty() and not g.missing_stations(t.base, []).is_empty():
		return g._fail("Set up first: %s." % g.data.stations[g.missing_stations(t.base, [])[0]].name)
	if not additives.is_empty() and not g.missing_stations(t.base, additives).is_empty():
		return g._fail("Set up first: %s." % g.data.stations[g.missing_stations(t.base, additives)[0]].name)
	for a in need:
		g._add(g.cargo, a, -need[a])
	t.additives = additives.duplicate()
	t.mixed = true
	g._emit("tray_mixed", {"base": t.base, "additives": additives.size()})
	if additives.is_empty():
		return g._ok("No additives this time.")
	return g._ok("Mixed in %s." % ", ".join(PackedStringArray(additives.map(func(a): return g.item_name(a)))))


## Records the minigame score of `station` for the tray; after the last station the batch is queued.
static func record(g, station: String, score: float) -> Dictionary:
	var t := tray(g)
	if t.is_empty() or next_station(g, t) != station:
		return g._fail("Wrong station.")
	if g.data.station_order.find(station) > g.data.station_order.find(MIX):
		t.mixed = true  # walked past the Mixing Station: no additives in this batch
	t.done.append(station)
	t.scores[station] = clampf(score, 0.0, 1.0)
	g._emit("tray_step", {"station": station, "base": t.base, "score": t.scores[station]})
	if next_station(g, t) != "":
		return g._ok("%s done. Next: %s." % [g.data.stations[station].name, g.data.stations[next_station(g, t)].name])
	return finish(g)


static func finish(g) -> Dictionary:
	var t := tray(g)
	var r: Dictionary = g.queue_batch(t.base, t.additives, int(t.qty), t.scores)
	if r.ok:
		g.bench.erase(g.inside_estate)
	return r


## Drops the tray: raws and additives go to the stash so nothing is lost.
static func abandon(g) -> Dictionary:
	var t := tray(g)
	if t.is_empty():
		return g._fail("No tray.")
	g._add(g.stash, g.data.bases[t.base].raw, int(t.qty))
	for a in t.additives:
		g._add(g.stash, a, int(t.qty))
	g.bench.erase(g.inside_estate)
	return g._ok("Batch scrapped, ingredients put in the stash.")


## Result preview for a tray with `additives`: {product, traits, value}.
static func preview(g, base: String, additives: Array) -> Dictionary:
	var traits: Array = Mixing.traits_for(g.data, base, additives)
	var key := Mixing.key(base, traits)
	return {"product": key, "traits": traits, "value": int(Mixing.value(g.data, key))}


static func to_save(g) -> Dictionary:
	return g.bench.duplicate(true)


static func from_save(g, d: Dictionary) -> void:
	g.bench = {}
	var src: Dictionary = d.get("bench", {})
	for e in src:
		var t: Dictionary = src[e]
		if not g.estates.has(e) or not g.data.bases.has(str(t.get("base", ""))):
			continue
		var adds: Array = []
		for a in t.get("additives", []):
			if g.data.additives.has(a):
				adds.append(str(a))
		var scores := {}
		var sc: Dictionary = t.get("scores", {})
		for s in sc:
			scores[str(s)] = float(sc[s])
		g.bench[e] = {"base": str(t.base), "qty": int(t.get("qty", 1)), "additives": adds,
			"done": Array(t.get("done", [])).map(func(x): return str(x)), "scores": scores, "mixed": bool(t.get("mixed", false))}


## True once a station that comes after the Mixing Station in the global order is done.
static func _after_mix_done(g, t: Dictionary) -> bool:
	var order: Array = g.data.station_order
	var mi := order.find(MIX)
	for st in t.done:
		if order.find(st) > mi:
			return true
	return false
