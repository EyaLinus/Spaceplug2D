extends RefCounted
## Interdiction (D3): a jump can be pulled out of hyperspace by a cartel wing or the Reach Authority.
## Rules over a Game; numbers in content.json "interdiction".
##
## Game.jump() rolls on arrival (`roll`) with its own lane RNG, so the game RNG and every other system stay
## untouched. A hit parks the encounter in `Game.interdiction` (runtime only) and emits "interdicted"; the UI shows
## a card and the player picks one way out (`resolve`):
##   pay   - cartel toll (base + per unit of product aboard) or an Authority bribe (heat drops)
##   dump  - jettison the product (cartel: they gain ground here; Authority: contraband gone, heat drops)
##   flee  - chance from engine level and hull class speed; failing costs hull and turns into a fight
##   fight - the wing (or interceptors) is spawned by the world around the ship; fighting the Authority adds heat
## Cartels interdict where they are present and hostile; the Authority only when you carry contraband with heat.

const Mixing = preload("res://scripts/core/mixing.gd")
const Cartels = preload("res://scripts/core/cartels.gd")
const SpaceCombat = preload("res://scripts/core/spacecombat.gd")

const CHOICES := ["pay", "dump", "flee", "fight"]


static func rules(g) -> Dictionary:
	return g.data.get("interdiction", {})


static func pending(g) -> bool:
	return not g.interdiction.is_empty()


## Units of product aboard (what cartels want and tolls scale with).
static func product_units(g) -> int:
	var n := 0
	for k in g.cargo:
		if Mixing.is_product(k):
			n += int(g.cargo[k])
	return n


## Chance that cartel `id` interdicts a jump into `sys`.
static func cartel_chance(g, id: String, sys: String) -> float:
	var r := rules(g)
	if Cartels.weakened(g, id):
		return 0.0
	var home := str(Cartels.gang(g, id).get("home", "")) == sys
	if not home and Cartels.system_share(g, sys, id) <= 0.0:
		return 0.0
	var c := float(r.get("cartel_base", 0.0)) + Cartels.hostility(g, id) / 100.0 * float(r.get("cartel_hostility", 0.0))
	if product_units(g) > 0:
		c += float(r.get("cargo_bonus", 0.0))
	return clampf(c, 0.0, float(r.get("max_chance", 0.5)))


## Chance that the Authority interdicts: only with contraband aboard and heat in the arrival system.
static func authority_chance(g) -> float:
	var r := rules(g)
	if not g.has_contraband() or g.heat < float(g.data.heat.chase_heat):
		return 0.0
	var c: float = float(r.get("authority_base", 0.0)) + g.heat / float(g.data.heat.max) * float(r.get("authority_heat", 0.0))
	return clampf(c, 0.0, float(r.get("max_chance", 0.5)))


## Rolls an interdiction for a jump that just arrived in `sys`. Sets Game.interdiction and emits "interdicted" on a
## hit. Returns the encounter ({} = clean jump).
static func roll(g, sys: String) -> Dictionary:
	if rules(g).is_empty() or g.day < int(rules(g).get("min_day", 1)) or pending(g):
		return {}
	var rng: RandomNumberGenerator = g.lane_rng
	if rng.randf() < authority_chance(g):
		return begin(g, {"kind": "authority", "cartel": "", "units": rules(g).get("authority_units", ["interceptor"]).duplicate()})
	for p in Cartels.present(g, sys):
		if rng.randf() < cartel_chance(g, p.id, sys):
			return begin(g, {"kind": "cartel", "cartel": p.id, "units": SpaceCombat.wing_units(g, p.id)})
	return {}


## Starts an encounter (also used by tests and the smoke test).
static func begin(g, enc: Dictionary) -> Dictionary:
	enc.system = g.system
	enc.cost = pay_cost(g, enc)
	enc.flee = flee_chance(g)
	g.interdiction = enc
	g._emit("interdicted", enc.duplicate())
	return enc


## Credits the way out by paying costs: a cartel toll or an Authority bribe.
static func pay_cost(g, enc: Dictionary) -> int:
	var r := rules(g)
	if enc.get("kind", "") == "authority":
		return int(r.get("bribe_base", 0)) + int(g.heat * float(g.data.heat.bribe_credits_per_heat))
	return int(r.get("toll_base", 0)) + product_units(g) * int(r.get("toll_per_unit", 0))


## Chance to outrun the interdictors: base + engine modules + the hull class's speed.
static func flee_chance(g) -> float:
	var r := rules(g)
	var c := float(r.get("flee_base", 0.0)) + float(g.upgrades.engine) * float(r.get("flee_engine", 0.0))
	c += (SpaceCombat.class_mult(g, "speed") - 1.0) * float(r.get("flee_speed", 0.0)) * 4.0
	return clampf(c, 0.05, 0.95)


## Text of what dumping costs, for the card.
static func dump_text(g, enc: Dictionary) -> String:
	if enc.get("kind", "") == "authority":
		return "Jettison all product (%d units) before the scan." % product_units(g)
	return "Hand over your product (%d units)." % product_units(g)


## Resolves the pending encounter with one of CHOICES. Returns {ok, msg, fight, units, cartel, kind}; ok = false
## only when the choice is impossible (not enough credits, nothing to dump) and the encounter stays open.
static func resolve(g, choice: String, rng: RandomNumberGenerator = null) -> Dictionary:
	if not pending(g):
		return g._fail("Nobody is holding you.")
	if rng == null:
		rng = g.lane_rng
	var enc: Dictionary = g.interdiction
	var r := rules(g)
	var auth: bool = enc.kind == "authority"
	var who: String = "the Authority" if auth else str(Cartels.gang(g, enc.cartel).get("name", "the cartel"))
	var res := {"ok": true, "msg": "", "fight": false, "units": enc.units, "cartel": enc.cartel, "kind": enc.kind, "choice": choice}
	match choice:
		"pay":
			var cost := pay_cost(g, enc)
			if g.credits < cost:
				return g._fail("You can't cover %d cr." % cost)
			g.credits -= cost
			if auth:
				g.add_heat(-float(r.get("bribe_heat_drop", 0.0)))
				res.msg = "The officer pockets %d cr and waves you through." % cost
			else:
				res.msg = "You paid the %s %d cr. They let you pass." % [who, cost]
		"dump":
			if auth:
				var n := product_units(g)
				if n <= 0:
					return g._fail("You have nothing to dump.")
				for k in g.cargo.keys():
					if Mixing.is_product(k):
						g.cargo.erase(k)
				g.add_heat(-float(r.get("dump_heat_drop", 0.0)))
				res.msg = "You vented %d units into space before the scan. Clean." % n
			else:
				var n := product_units(g)
				if n <= 0:
					return g._fail("You carry no product.")
				for k in g.cargo.keys():
					if Mixing.is_product(k):
						g.cargo.erase(k)
				Cartels.gain_system(g, g.system, str(enc.cartel), float(r.get("dump_influence", 0.0)))
				res.msg = "The %s take %d units of your product and fly off laughing." % [who, n]
		"flee":
			if rng.randf() < flee_chance(g):
				res.msg = "You burn hard and slip away from %s." % who
			else:
				SpaceCombat.damage(g, float(r.get("flee_fail_damage", 0.0)))
				res.fight = true
				res.msg = "They cut you off and open fire!"
				if auth:
					g.add_heat(float(r.get("fight_heat", 0.0)))
		"fight":
			res.fight = true
			res.msg = "Weapons hot. %s incoming!" % who.capitalize()
			if auth:
				g.add_heat(float(r.get("fight_heat", 0.0)))
		_:
			return g._fail("Unknown choice.")
	g.interdiction = {}
	g._emit("interdiction_resolved", {"choice": choice, "kind": enc.kind, "cartel": enc.cartel, "fight": res.fight})
	return res
