extends SceneTree
## Mid-game economy probe: what one staffed estate earns per game day, through the real worker code.
## For every base and staffing level it buys an estate, builds the full line, hires a lab hand + stocker, keeps the
## storage topped up with raws (paid at hub prices) and ticks one game day at a time. Output is valued at the
## bazaar fence price. Prints per-day revenue, inputs, wages, upkeep, machine fees, net, heat added and payback.
## godot --headless --path . -s res://tools/econ_probe.gd -- [--days 5] [--estate shaft_shack] [--tier 0]

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")
const Production = preload("res://scripts/core/production.gd")
const EstateUpkeep = preload("res://scripts/core/estate_upkeep.gd")
const Workers = preload("res://scripts/core/workers.gd")

const STAFF := [["dax", "moss"], ["pia", "jun"], ["hollis", "reva"]]


func _init() -> void:
	var days := 5
	var estate := "shaft_shack"
	var tier := 0
	var machines := false
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--days": days = int(args[i + 1])
			"--estate": estate = args[i + 1]
			"--tier": tier = int(args[i + 1])
			"--machines": machines = true
	var data := Data.load_all()
	print("ECON estate=%s tier=%d days=%d machines=%s (per game day, fence price on the bazaar)" % [estate, tier, days, machines])
	for base in data.bases:
		for staff in STAFF:
			print(_probe(data, base, staff, estate, tier, days, machines))
	quit()


static func _probe(data: Dictionary, base: String, staff: Array, estate: String, tier: int, days: int, machines: bool) -> String:
	var g := Game.new()
	g.new_game(data, 11)
	g.debt = 0
	g.credits = 1000000
	g.estates[estate] = {"buildings": []}
	Workers.ensure(g.estates[estate])
	if tier > 0:
		g.estates[estate].tier = tier
	var additives: Array = [data.additives.keys()[0]]
	var x := 0
	var setup := int(data.estates[estate].get("price", 0))
	for st in Production.stations_for(data, base, additives):
		var id: String = st
		if machines:
			for m in data.get("machines", {}):
				if str(data.machines[m].station) == st:
					id = m
		g.estates[estate].buildings.append({"id": id, "x": x, "y": 0})
		setup += int(data.buildables[id].cost)
		x += 3
	for w in staff:
		g.workers.append({"id": w, "loyalty": 1.0, "estate": estate, "hired_day": 1})
	var qty := g.lab_capacity(estate)
	Workers.set_recipe(g, estate, base, additives, qty)
	var need: Dictionary = g.batch_needs(base, additives, 1)
	var price := {}  # cheapest place to buy each input
	for k in need:
		price[k] = 999999
		for l in data.locations:
			var p := g.buy_price(k, l)
			if p > 0:
				price[k] = mini(int(price[k]), p)
	g.location = "bazaar"  # sells at the bazaar fence; demand saturation and recovery apply (g.tick)
	g.data.interdiction.min_day = 9999
	var c0 := g.credits
	var inputs := 0
	var revenue := 0
	var units := 0
	var heat := 0.0
	var e: Dictionary = g.estates[estate]
	var upkeep0 := int(g.stats.get("upkeep_paid", 0))
	for d in days:
		g.heat = 0.0
		var steps := 48
		for s in steps:
			# keep the storage stocked like a drone/courier would
			for k in need:
				var short := qty * 2 - int(e.storage.get(k, 0))
				if short > 0:
					e.storage[k] = int(e.storage.get(k, 0)) + short
					inputs += short * int(price[k])
			var h0 := g.heat
			g.tick(g.day_seconds() / steps)
			heat += maxf(0.0, g.heat - h0)
			g.heat = 0.0  # keep raids and patrol pressure out of the measurement
			# sell what came out at the fence
			for src in [e.out, e.storage]:
				for k in src.keys():
					if k.contains(":"):
						var n := int(src[k])
						src.erase(k)
						g.cargo[k] = int(g.cargo.get(k, 0)) + n
						var c1 := g.credits
						g.sell(k, n)
						revenue += g.credits - c1
						units += n
						g.cargo.erase(k)
	var wages := int(g.stats.get("wages", 0))
	var upkeep := int(g.stats.get("upkeep_paid", 0)) - upkeep0
	var machine_fees := c0 - g.credits + revenue - wages - upkeep
	var net := float(revenue - inputs - wages - upkeep - machine_fees) / days
	var hire := 0
	for w in staff:
		hire += Workers.hire_cost(g, w)
	return "ECON %-8s %-11s units/day=%5.1f rev=%6d inputs=%5d wages=%4d upkeep=%3d machines=%4d NET/day=%6d heat/day=%5.1f payback_days=%4.1f" % [
		base, "/".join(staff), float(units) / days, revenue / days, inputs / days, wages / days, upkeep / days,
		machine_fees / days, int(net), heat / days, float(setup + hire) / maxf(net, 1.0)]
