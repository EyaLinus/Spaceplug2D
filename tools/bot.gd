extends RefCounted
## Scripted player for balance checks: runs the core loop on the headless Game without flight.
## Travel is approximated as distance / cruise speed; patrol encounters as a per-trip bust chance.
## Used by tests/run_tests.gd (smoke) and tools/sim.gd (metrics).

const Game = preload("res://scripts/core/game.gd")
const Mixing = preload("res://scripts/core/mixing.gd")

const RECIPE := ["nanoflux"]  ## driftglow + nanoflux = Radiant/Overclock, a solid early-game product
const BUST_CHANCE_PER_PATROL := 0.04


static func travel_seconds(g: Game, a: String, b: String) -> float:
	var pa: Array = g.data.locations[a].pos
	var pb: Array = g.data.locations[b].pos
	var dist := Vector2(pa[0], pa[1]).distance_to(Vector2(pb[0], pb[1]))
	return dist / (float(g.data.ship.max_speed) * 0.75 * g.engine_mult()) + 4.0


static func fly(g: Game, to: String, rng: RandomNumberGenerator, log: Array) -> void:
	var from := g.location
	g.undock()
	g.tick(travel_seconds(g, from, to))
	if g.has_contraband():
		var chance := g.patrol_count() * BUST_CHANCE_PER_PATROL * (1.0 - g.stealth())
		if rng.randf() < chance:
			g.bust()
			log.append("day %d bust" % g.day)
	g.dock(to)


static func sell_here(g: Game) -> void:
	for c in g.contacts_at():
		for k in g.cargo.keys():
			if Mixing.is_product(k) and g.contact_ready(c.id):
				g.sell(k, mini(int(g.cargo[k]), int(c.max_units)), c.id)
	if g.loc_data().get("fence", false):
		for k in g.cargo.keys():
			if Mixing.is_product(k):
				g.sell(k, int(g.cargo[k]))


## Plays until the game ends or `max_days` passes. Returns summary metrics.
static func play(data: Dictionary, seed_value: int, speed: float = 1.0, max_days: int = 14) -> Dictionary:
	var g := Game.new()
	g.new_game(data, seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var log: Array = []
	var guard := 0
	while g.state == "playing" and g.day <= max_days and guard < 2000:
		guard += 1
		# --- at the hub: cook, sell locally, upgrade, pay down debt
		var unit_cost := g.buy_price("sporegel") + g.buy_price("nanoflux")
		var qty := mini(g.lab_capacity(), g.cargo_free())
		qty = mini(qty, g.credits / unit_cost)
		if qty > 0:
			g.buy("sporegel", qty)
			g.buy("nanoflux", qty)
			g.start_batch("driftglow", RECIPE, qty)
			g.tick(g.lab_queue[0].remaining + 0.1)
		g.collect_stash()
		sell_here(g)
		if g.heat > 55.0 and g.credits > g.bribe_cost(g.heat - 20.0) + 200:
			g.bribe(g.heat - 20.0)
		for u in ["lab", "cargo", "stealth", "engine"]:
			var c := g.upgrade_cost(u)
			if c > 0 and g.credits > c + 400 and g.debt > 0 and g.day < g.debt_due_day - 3:
				g.buy_upgrade(u)
		if g.credits > 600 and g.debt > 0:
			g.pay_debt(g.credits - 400 if g.day < g.debt_due_day - 1 else g.credits)
		if g.state != "playing":
			break
		# --- run the rest to the bazaar when holding more than local contacts take
		if g.has_contraband():
			fly(g, "bazaar", rng, log)
			sell_here(g)
			fly(g, "mireth", rng, log)
		elif qty == 0:
			g.tick(10.0)  # broke: wait for contacts / nothing to do
	return {
		"state": g.state, "day": g.day, "credits": g.credits, "debt": g.debt, "heat": snappedf(g.heat, 0.1),
		"earned": g.stats.earned, "units": g.stats.units_sold, "busts": g.stats.busts,
		"upgrades": g.upgrades.duplicate(), "log": log,
	}
