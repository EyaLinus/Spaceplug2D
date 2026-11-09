extends SceneTree
## Long-run soak test of the combined mid-game systems on the headless Game: after the debt, owns every estate
## with full lines, crews, drones and dealers, then flies between random ports for N game days while every core
## system ticks (workers, drones, upkeep, raids, cartels, interdiction, deals, dealers, orders ...).
## Fails on broken invariants (negative stock, NaN/out-of-range heat, dangling worker/drone estates) and on an
## unstable save round trip. Watch the output for SCRIPT ERROR too.
## godot --headless --path . -s res://tools/soak.gd -- [--days 30] [--seeds 3]

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")
const Production = preload("res://scripts/core/production.gd")
const Workers = preload("res://scripts/core/workers.gd")
const Drones = preload("res://scripts/core/drones.gd")
const Dealers = preload("res://scripts/core/dealers.gd")
const Mixing = preload("res://scripts/core/mixing.gd")
const EstateUpkeep = preload("res://scripts/core/estate_upkeep.gd")

var fails := 0


func _init() -> void:
	var days := 30
	var seeds := 3
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--days":
			days = int(args[i + 1])
		elif args[i] == "--seeds":
			seeds = int(args[i + 1])
	var data := Data.load_all()
	for s in seeds:
		_run(data, 500 + s, days)
	print("SOAK DONE %d failures" % fails)
	quit()


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("SOAK FAIL ", what)


func _run(data: Dictionary, seed_value: int, days: int) -> void:
	var g := Game.new()
	g.new_game(data, seed_value)
	g.debt = 0
	g.credits = 60000
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var events := {}
	g.event.connect(func(k, _p): events[k] = int(events.get(k, 0)) + 1)
	var additive: String = data.additives.keys()[0]
	var bases: Array = data.bases.keys()
	var lab_hands: Array = []
	var stockers: Array = []
	for c in data.workers.candidates:
		(lab_hands if c.role == "lab_hand" else stockers).append(c.id)
	var n := 0
	for id in data.estates:
		var e: Dictionary = data.estates[id]
		if e.get("ship", false) or e.get("starter", false):
			continue
		g.location = e.location
		_check(g.buy_estate(id).ok, "buy %s" % id)
		var base: String = bases[n % bases.size()]
		var x := 0
		for st in Production.stations_for(data, base, [additive]):
			g.estates[id].buildings.append({"id": st, "x": x, "y": 0})
			x += 3
		if n < lab_hands.size():
			Workers.hire(g, lab_hands[n])
			Workers.assign(g, lab_hands[n], id)
		if n < stockers.size():
			Workers.hire(g, stockers[n])
			Workers.assign(g, stockers[n], id)
		Workers.set_recipe(g, id, base, [additive], 99)
		Drones.buy(g, id, "to_port")
		n += 1
	g.location = str(data.start.location)
	for d in Dealers.available(g):
		Dealers.hire(g, d.id)
	var ports: Array = []
	for l in data.locations:
		if not data.locations[l].get("raid_base", false) and not str(l).ends_with("_gate"):
			ports.append(l)
	var start_day := g.day
	var guard := 0
	while g.day < start_day + days and guard < 20000:
		guard += 1
		if g.state != "playing":
			g.state = "playing"  # keep going after a loss/win screen; we are testing systems, not the end
		# restock every estate a little (a stand-in for drones / orders to the estate)
		for id in g.estates:
			if g.estates[id].has("storage") and not g.estates[id].get("recipe", {}).is_empty():
				var r: Dictionary = g.estates[id].recipe
				for k in g.batch_needs(r.base, r.additives, 10):
					if int(g.estates[id].storage.get(k, 0)) < 20:
						g.estates[id].storage[k] = int(g.estates[id].storage.get(k, 0)) + 10
		var to: String = ports[rng.randi() % ports.size()]
		g.undock()
		g.tick(rng.randf_range(10.0, 40.0))
		g.dock(to)
		g.tick(5.0)
		g.collect_stash()
		if g.loc_data().get("fence", false):
			for k in g.cargo.keys():
				if Mixing.is_product(k):
					g.sell(k, int(g.cargo[k]))
		if g.credits < 2000:
			g.credits += 5000  # stay solvent: upkeep / wages failure paths are covered by unit tests
		if g.heat > 70.0:
			g.heat = 30.0
		_invariants(g)
	var json := JSON.stringify(g.to_dict())
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(json))
	var json2 := JSON.stringify(h.to_dict())
	_check(json2 == json, "seed %d save round trip stable" % seed_value)
	if json2 != json:
		_diff(JSON.parse_string(json), JSON.parse_string(json2), "")
	print("SOAK seed=%d day=%d estates=%d workers=%d drones=%d credits=%d batches=%d worker_batches=%d upkeep_paid=%d drones_lost=%d earned=%d events=%s" % [
		seed_value, g.day, g.estates.size(), g.workers.size(), g.drones.size(), g.credits, g.stats.batches,
		int(g.stats.get("worker_batches", 0)), int(g.stats.get("upkeep_paid", 0)), int(g.stats.get("drones_lost", 0)), g.stats.earned, _top(events)])


func _top(events: Dictionary) -> String:
	var keys := events.keys()
	keys.sort_custom(func(a, b): return events[a] > events[b])
	var parts: Array = []
	for k in keys.slice(0, 12):
		parts.append("%s:%d" % [k, events[k]])
	return ",".join(parts)


func _invariants(g) -> void:
	_check(not is_nan(g.heat) and g.heat >= 0.0 and g.heat <= float(g.data.heat.max), "heat in range (%s)" % g.heat)
	for k in g.cargo:
		_check(int(g.cargo[k]) > 0, "cargo %s positive" % k)
	for k in g.stash:
		_check(int(g.stash[k]) >= 0, "stash %s non-negative" % k)
	for id in g.estates:
		var e: Dictionary = g.estates[id]
		for bag in ["storage", "bench", "out"]:
			for k in e.get(bag, {}):
				_check(int(e[bag][k]) >= 0, "%s %s %s non-negative" % [id, bag, k])
	for w in g.workers:
		_check(w.estate == "" or g.estates.has(w.estate), "worker %s estate exists" % w.id)
	for d in g.drones:
		_check(g.estates.has(d.estate), "drone %d estate exists" % d.id)


func _diff(a, b, path: String) -> void:
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		for k in a:
			if not b.has(k):
				print("  save diff: %s/%s missing after load" % [path, k])
			else:
				_diff(a[k], b[k], path + "/" + str(k))
		for k in b:
			if not a.has(k):
				print("  save diff: %s/%s added after load" % [path, k])
	elif typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY and a.size() == b.size():
		for i in a.size():
			_diff(a[i], b[i], path + "/" + str(i))
	elif JSON.stringify(a) != JSON.stringify(b):
		print("  save diff: %s %s -> %s" % [path, JSON.stringify(a).left(120), JSON.stringify(b).left(120)])
