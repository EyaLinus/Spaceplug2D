extends RefCounted
## Jump interdiction (D3), headless. A jump through a gate or with the drive can be pulled out of the lane by pirates
## or Reach Authority cutters. The player then picks: fight (E2 space combat in the world), pay, dump cargo or flee.
## Static helpers over a Game; the pending encounter lives in `Game.interdiction` (runtime only, never saved) and the
## cooldown in `Game.interdict_ready_at`. Numbers: content.json -> "interdiction". Geometry (spawning the ships,
## shooting them) is the world's job; it reports back with ship_down().
##
## interdiction = {} (none) or {kind: "pirates"|"authority", gate, via: "gate"|"drive", from, to, ships, killed,
##                              lost, demand, state: "offer"|"fight"}
## Every resolution emits "interdiction_resolved" {how, proceed, kind, gate, via}: proceed = the jump goes through.

const Mixing = preload("res://scripts/core/mixing.gd")
const Galaxy = preload("res://scripts/core/galaxy.gd")
const SpaceCombat = preload("res://scripts/core/spacecombat.gd")

const KINDS := ["pirates", "authority"]


static func cfg(g) -> Dictionary:
	return g.data.get("interdiction", {})


static func active(g) -> bool:
	return not g.interdiction.is_empty()


static func fighting(g) -> bool:
	return g.interdiction.get("state", "") == "fight"


static func kind_name(kind: String) -> String:
	return "Reach Authority cutters" if kind == "authority" else "Pirate raiders"


# ---------------------------------------------------------------- how likely

## The most dangerous security level of the two ends of a lane ("low" beats "medium" beats "high").
static func lane_security(g, from_sys: String, to_sys: String) -> String:
	var order := ["high", "medium", "low"]
	var worst := 0
	for s in [from_sys, to_sys]:
		worst = maxi(worst, maxi(0, order.find(str(g.system_data(s).get("security", "medium")))))
	return order[worst]


static func product_units(g) -> int:
	var n := 0
	for k in g.cargo:
		if Mixing.is_product(k):
			n += int(g.cargo[k])
	return n


static func cargo_units(g) -> int:
	var n := 0
	for k in g.cargo:
		n += int(g.cargo[k])
	return n


## Chance that pirates pull you out of the lane `from_sys` -> `to_sys`: lawless lanes and a hold full of product attract them.
static func pirate_chance(g, from_sys: String, to_sys: String) -> float:
	var c := cfg(g)
	var base := float(c.pirate_chance.get(lane_security(g, from_sys, to_sys), 0.1))
	var haul := minf(1.0, float(product_units(g)) / float(c.cargo_units))
	return clampf(base * (1.0 + float(c.cargo_pressure) * haul), 0.0, float(c.max_chance))


## Chance that Authority cutters interdict a departure from `from_sys`: needs enough heat there; product in the hold
## makes it far likelier than an innocent hold.
static func authority_chance(g, from_sys: String) -> float:
	var a: Dictionary = cfg(g).authority
	var h := Galaxy.system_heat(g, from_sys)
	if h < float(a.min_heat):
		return 0.0
	var p := float(a.base) + float(a.heat_scale) * clampf(h / float(g.data.heat.max), 0.0, 1.0)
	if not g.has_contraband():
		p *= float(a.clean_mult)
	return clampf(p, 0.0, float(cfg(g).max_chance))


## Both chances for the lane the player is about to take (for tests, the Map app and the sim).
static func chances(g, from_sys: String, to_sys: String) -> Dictionary:
	return {"pirates": pirate_chance(g, from_sys, to_sys), "authority": authority_chance(g, from_sys)}


# ---------------------------------------------------------------- the roll

## Rolls for an interception on the jump through `gate` (`via` "gate" = flown in, "drive" = jump drive). Returns the
## encounter (also stored in `g.interdiction`) or {}. Honours the cooldown so a trip does not chain ambushes.
static func check(g, gate: String, via := "gate", rng: RandomNumberGenerator = null) -> Dictionary:
	if cfg(g).is_empty() or active(g) or g.location != "" or g.state != "playing":
		return {}
	if g.total_time < g.interdict_ready_at:
		return {}
	var gd: Dictionary = g.loc_data(gate)
	if not gd.has("jump_to"):
		return {}
	var r: RandomNumberGenerator = rng if rng != null else g.rng
	var from_sys: String = g.system
	var to_sys := str(gd.jump_to)
	var kind := ""
	if r.randf() < authority_chance(g, from_sys):
		kind = "authority"
	elif r.randf() < pirate_chance(g, from_sys, to_sys):
		kind = "pirates"
	if kind == "":
		return {}
	return begin(g, kind, gate, via, r)


## Starts an encounter of `kind` (also used by tests and the smoke test to force one).
static func begin(g, kind: String, gate: String, via := "gate", rng: RandomNumberGenerator = null) -> Dictionary:
	var r: RandomNumberGenerator = rng if rng != null else g.rng
	var c := cfg(g)
	var ships := 1
	var demand := 0
	if kind == "authority":
		var a: Dictionary = c.authority
		ships = clampi(1 + int(g.heat / float(a.ships_per_heat)), 1, int(a.max_ships))
		demand = maxi(int(a.fine_min), int(round(g.heat * float(a.fine_per_heat))))
		if not g.has_contraband():
			demand = int(round(demand * float(a.clean_fine_mult)))
	else:
		var p: Dictionary = c.pirates
		if product_units(g) >= int(c.cargo_units):
			ships += int(p.cargo_ships)
		if r.randf() < float(p.extra_ship_chance):
			ships += 1
		ships = clampi(ships, 1, int(p.max_ships))
		demand = maxi(int(p.toll_min), int(g.credits * float(p.toll_ratio))) + int(p.toll_per_ship) * (ships - 1)
	var to_sys := str(g.loc_data(gate).get("jump_to", ""))
	g.interdiction = {"kind": kind, "gate": gate, "via": via, "from": g.system, "to": to_sys, "ships": ships, "killed": 0,
		"lost": 0, "demand": demand, "state": "offer"}
	g.interdict_ready_at = g.total_time + float(c.cooldown)
	g._emit("interdicted", {"kind": kind, "ships": ships, "demand": demand, "gate": gate})
	return g.interdiction


# ---------------------------------------------------------------- the choices

static func flee_chance(g) -> float:
	var f: Dictionary = cfg(g).flee
	var p := float(f.base) + float(f.per_engine) * float(g.upgrades.engine)
	if float(g.combat.boost) >= float(g.data.space_combat.boost.cost):
		p += float(f.boost_bonus)
	return clampf(p, 0.05, 0.95)


## What the player can pick right now: [{id, label, enabled, hint}] in a fixed order (fight, pay, dump, flee).
static func options(g) -> Array:
	if not active(g) or fighting(g):
		return []
	var e: Dictionary = g.interdiction
	var auth: bool = e.kind == "authority"
	var dump_n := product_units(g) if auth else cargo_units(g)
	return [
		{"id": "fight", "label": "Fight", "enabled": true,
			"hint": "%d hostile%s. Beat them with lasers and missiles; the jump goes ahead once they are down." % [e.ships, "" if e.ships == 1 else "s"]
				+ (" Shooting at the Authority adds heat." if auth else " Downed raiders pay bounty.")},
		{"id": "pay", "label": "Pay %d cr" % e.demand, "enabled": g.credits >= int(e.demand),
			"hint": ("A fine to wave you through." if auth else "A toll for the raiders to let you go.") if g.credits >= int(e.demand) else "You cannot afford %d cr." % e.demand},
		{"id": "dump", "label": "Dump cargo", "enabled": dump_n > 0,
			"hint": ("Jettison %d unit%s of product before the scan." % [dump_n, "" if dump_n == 1 else "s"]) if auth and dump_n > 0 else
				("Jettison the %d unit%s in the hold; the raiders scoop it up." % [dump_n, "" if dump_n == 1 else "s"]) if dump_n > 0 else
				("No product to dump." if auth else "The hold is empty.")},
		{"id": "flee", "label": "Flee", "enabled": true,
			"hint": "%d%% to burn through the gate. A miss costs hull and starts a fight." % int(round(flee_chance(g) * 100.0))},
	]


## Resolves a choice. Returns {ok, msg, fight, proceed}. "fight" and a failed "flee" leave the encounter open in state
## "fight" (the world spawns `ships` hostiles, see combat_layer.spawn_interdictors); everything else closes it.
static func choose(g, id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	if not active(g) or fighting(g):
		return _res(g, false, "Nobody is hailing you.")
	match id:
		"fight":
			return _start_fight(g, "You open fire.")
		"pay":
			return _pay(g)
		"dump":
			return _dump(g)
		"flee":
			return _flee(g, rng if rng != null else g.rng)
	return _res(g, false, "Unknown choice.")


static func _res(g, ok: bool, msg: String, fight := false, proceed := false) -> Dictionary:
	return {"ok": ok, "msg": msg, "fight": fight, "proceed": proceed}


static func _start_fight(g, msg: String) -> Dictionary:
	var e: Dictionary = g.interdiction
	e.state = "fight"
	if e.kind == "authority":
		g.add_heat(float(cfg(g).authority.fight_heat))
	g._emit("interdiction_fight", {"kind": e.kind, "ships": e.ships})
	return _res(g, true, msg, true)


static func _pay(g) -> Dictionary:
	var e: Dictionary = g.interdiction
	if g.credits < int(e.demand):
		return _res(g, false, "You cannot afford %d cr." % e.demand)
	g.credits -= int(e.demand)
	var msg := ("Paid %d cr to the cutters; they wave you through." if e.kind == "authority" else "Paid %d cr; the raiders let you go.") % e.demand
	return _close(g, "pay", true, msg)


static func _dump(g) -> Dictionary:
	var e: Dictionary = g.interdiction
	var auth: bool = e.kind == "authority"
	var dumped := 0
	for k in g.cargo.keys():
		if auth and not Mixing.is_product(k):
			continue
		dumped += int(g.cargo[k])
		g.cargo.erase(k)
	if dumped <= 0:
		return _res(g, false, "No product to dump." if auth else "The hold is empty.")
	e.lost = dumped
	var msg: String
	if auth:
		g.add_heat(float(cfg(g).authority.dump_heat))
		msg = "Dumped %d units of product; the cutters find an empty hold and let you pass." % dumped
	else:
		msg = "Dumped %d units; the raiders scramble for the cargo pods and you slip away." % dumped
	return _close(g, "dump", true, msg)


static func _flee(g, rng: RandomNumberGenerator) -> Dictionary:
	var e: Dictionary = g.interdiction
	var chance := flee_chance(g)
	SpaceCombat.try_boost(g)  # the dash burns the boost energy whether it works or not
	if rng.randf() < chance:
		if e.kind == "authority":
			g.add_heat(float(cfg(g).authority.flee_heat))
		return _close(g, "flee", true, "You burn through the gate and leave them behind.")
	var shots := int(cfg(g).flee.volley_shots)
	var dmg: float = float(e.ships * shots) * float(g.data.space_combat.pirate.damage)
	var room := float(g.combat.shield) + float(g.combat.hull) - 1.0  # a volley hurts but never wrecks the ship
	SpaceCombat.damage(g, clampf(dmg, 0.0, maxf(0.0, room)))
	return _start_fight(g, "They hit you as you run (-%d). The fight is on." % int(dmg))


static func _close(g, how: String, proceed: bool, msg: String) -> Dictionary:
	var e: Dictionary = g.interdiction.duplicate()
	g.interdiction = {}
	g._emit("interdiction_resolved", {"how": how, "proceed": proceed, "kind": e.kind, "gate": e.gate, "via": e.via})
	return _res(g, true, msg, false, proceed)


# ---------------------------------------------------------------- the fight

## The world reports a hostile gone: `destroyed` = shot down, else it drifted out of range. When none is left the
## encounter ends: all shot down -> the jump goes through; otherwise it is called off.
static func ship_down(g, destroyed: bool) -> void:
	if not fighting(g):
		return
	var e: Dictionary = g.interdiction
	e.ships = int(e.ships) - 1
	if destroyed:
		e.killed = int(e.killed) + 1
	else:
		e.lost = int(e.lost) + 1
	if int(e.ships) > 0:
		return
	var won: bool = int(e.lost) == 0 and int(e.killed) > 0
	if won and e.kind == "authority":
		g.add_heat(float(cfg(g).authority.win_heat))
	_close(g, "won" if won else "escaped", won, "")


## Hull and bounty of an interdictor differ from a deep-space raider: Authority cutters are tougher.
static func hull_mult(g, kind: String) -> float:
	var c := cfg(g)
	return float(c.authority.hull_mult) if kind == "authority" else float(c.pirates.hull_mult)


## Calls the encounter off without a jump (docked, wrecked, busted, game over). Cancels a held drive charge.
static func abort(g) -> void:
	if not active(g):
		return
	var e: Dictionary = g.interdiction
	g.interdiction = {}
	if e.via == "drive":
		Galaxy.cancel(g, "The interdiction broke the jump drive charge.")
	g._emit("interdiction_resolved", {"how": "abort", "proceed": false, "kind": e.kind, "gate": e.gate, "via": e.via})


# ---------------------------------------------------------------- balance helpers

## Share of `n` rolls on a lane that end in an interdiction (used by the sim and the tests).
static func simulate(g, gate: String, n: int, seed_value := 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var counts := {"pirates": 0, "authority": 0, "none": 0}
	for i in n:
		g.interdict_ready_at = 0.0
		g.interdiction = {}
		var e := check(g, gate, "gate", rng)
		counts[e.get("kind", "none")] += 1
	g.interdiction = {}
	g.interdict_ready_at = 0.0
	return counts
