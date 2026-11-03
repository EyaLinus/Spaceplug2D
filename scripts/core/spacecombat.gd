extends RefCounted
## Space combat rules, headless: hull + shield, damage, boost (dodge) energy, missiles, pirate pressure, defeat,
## repairs at the mechanic. Static helpers over a Game; the state lives in `Game.combat` (hull, shield, missiles,
## kills are saved, boost/idle are runtime only). Numbers: content.json -> "space_combat" and the upgrades laser, missile,
## shield, hull (each upgrade level is one module the E3 layered ship art draws). The world scripts (combat_layer.gd,
## pirate.gd) own the geometry and call back into these rules.

const Mixing = preload("res://scripts/core/mixing.gd")
const Cartels = preload("res://scripts/core/cartels.gd")


static func cfg(g) -> Dictionary:
	return g.data.space_combat


static func fresh(g) -> Dictionary:
	return {"hull": max_hull(g), "shield": max_shield(g), "missiles": missile_cap(g), "kills": 0, "boost": float(cfg(g).boost.max), "idle": 0.0, "secondary": "missile"}


## Full hull, shield, ammo and boost (new game).
static func reset(g) -> void:
	g.combat = fresh(g)


# ---------------------------------------------------------------- stats from modules

## The hull class the player flies (content.json "ship_classes"); multiplies hold, armour, shield, speed and lasers.
static func ship_class(g) -> Dictionary:
	return g.data.get("ship_classes", {}).get(g.ship_class, {})


static func class_mult(g, stat: String) -> float:
	return float(ship_class(g).get(stat, 1.0))


static func max_hull(g) -> float:
	return float(g.data.upgrades.hull.levels[g.upgrades.hull]) * class_mult(g, "hull")


static func max_shield(g) -> float:
	return float(g.data.upgrades.shield.levels[g.upgrades.shield]) * class_mult(g, "shield")


static func laser_damage(g) -> float:
	return float(g.data.upgrades.laser.levels[g.upgrades.laser]) * class_mult(g, "laser")


## Damage per flak pellet (0 = no battery).
static func flak_damage(g) -> float:
	return float(g.data.upgrades.get("flak", {}).get("levels", [0])[int(g.upgrades.get("flak", 0))])


## Damage of an ion bolt (0 = no emitter). Ion bolts also stun and hit gunships and bases harder.
static func ion_damage(g) -> float:
	return float(g.data.upgrades.get("ion", {}).get("levels", [0])[int(g.upgrades.get("ion", 0))])


## Secondary weapons you own, in cycle order: missile pods, flak battery, ion emitter.
static func secondaries(g) -> Array:
	var r: Array = []
	if missile_cap(g) > 0:
		r.append("missile")
	if flak_damage(g) > 0.0:
		r.append("flak")
	if ion_damage(g) > 0.0:
		r.append("ion")
	return r


## The selected secondary weapon ("" without any). Falls back to the first one you own.
static func secondary(g) -> String:
	var own := secondaries(g)
	if own.is_empty():
		return ""
	var cur := str(g.combat.get("secondary", ""))
	return cur if own.has(cur) else str(own[0])


## Selects the next secondary weapon; returns it.
static func cycle_secondary(g) -> String:
	var own := secondaries(g)
	if own.is_empty():
		return ""
	var i := own.find(secondary(g))
	g.combat.secondary = own[(i + 1) % own.size()]
	return g.combat.secondary


static func missile_cap(g) -> int:
	return int(g.data.upgrades.missile.levels[g.upgrades.missile])


static func has_missiles(g) -> bool:
	return missile_cap(g) > 0


static func hull_ratio(g) -> float:
	return clampf(float(g.combat.hull) / max_hull(g), 0.0, 1.0)


static func shield_ratio(g) -> float:
	var m := max_shield(g)
	return clampf(float(g.combat.shield) / m, 0.0, 1.0) if m > 0.0 else 0.0


# ---------------------------------------------------------------- per-frame rules

## Shield and boost energy recover while flying; the shield waits `shield.delay` seconds after the last hit.
static func tick(g, dt: float) -> void:
	if g.location != "":
		return
	var c: Dictionary = g.combat
	c.idle = float(c.idle) + dt
	var b: Dictionary = cfg(g).boost
	c.boost = minf(float(b.max), float(c.boost) + float(b.regen) * dt)
	if float(c.idle) >= float(cfg(g).shield.delay):
		c.shield = minf(max_shield(g), float(c.shield) + float(cfg(g).shield.regen) * dt)


## Docking recharges the shield and the boost for free (hull repairs and missiles cost credits).
static func on_dock(g) -> void:
	g.combat.shield = max_shield(g)
	g.combat.boost = float(cfg(g).boost.max)
	g.combat.idle = 0.0


## A newly bought module raises the matching stat: the extra capacity arrives filled (missiles stay empty = restock).
static func after_upgrade(g, key: String, old_level: int) -> void:
	var lv: Array = g.data.upgrades[key].levels
	var gain: float = float(lv[g.upgrades[key]]) - float(lv[old_level])
	match key:
		"hull":
			g.combat.hull = minf(max_hull(g), float(g.combat.hull) + gain)
		"shield":
			g.combat.shield = minf(max_shield(g), float(g.combat.shield) + gain)
		"missile":
			g.combat.missiles = mini(missile_cap(g), int(g.combat.missiles) + int(gain))


# ---------------------------------------------------------------- damage

## Applies `amount` of damage: shield first, then hull. Returns {"shield": absorbed, "hull": taken, "destroyed": bool}.
## Does not call defeat(): the world decides when the wreck is resolved.
static func damage(g, amount: float) -> Dictionary:
	var c: Dictionary = g.combat
	var on_shield := minf(float(c.shield), amount)
	c.shield = float(c.shield) - on_shield
	var on_hull := amount - on_shield
	c.hull = maxf(0.0, float(c.hull) - on_hull)
	c.idle = 0.0
	var res := {"shield": on_shield, "hull": on_hull, "destroyed": float(c.hull) <= 0.0}
	g.event.emit("ship_hit", res)
	return res


## Spends the boost energy for a dodge. False while docked or without enough energy.
static func try_boost(g) -> bool:
	var b: Dictionary = cfg(g).boost
	if g.location != "" or float(g.combat.boost) < float(b.cost):
		return false
	g.combat.boost = float(g.combat.boost) - float(b.cost)
	return true


## Uses one missile. False without a launcher or ammo.
static func take_missile(g) -> bool:
	if int(g.combat.missiles) <= 0:
		return false
	g.combat.missiles = int(g.combat.missiles) - 1
	return true


# ---------------------------------------------------------------- pirates

## Credits for a downed pirate (random within the bounty range). Counts the kill.
static func collect_bounty(g, rng: RandomNumberGenerator) -> int:
	var r: Array = cfg(g).pirate.bounty
	var amount := rng.randi_range(int(r[0]), int(r[1]))
	g.credits += amount
	g.combat.kills = int(g.combat.kills) + 1
	g._emit("pirate_down", {"bounty": amount})
	return amount


## Rules of an enemy kind: "pirate" (the lone raider) or one of space_combat.enemies (fighter, gunship, interceptor).
static func enemy_cfg(g, kind: String) -> Dictionary:
	if kind == "pirate":
		return cfg(g).pirate
	return cfg(g).get("enemies", {}).get(kind, cfg(g).pirate)


## An enemy ship went down: bounty, kill count, cartel ground (cartel ships), loot roll. Emits "pirate_down" for every
## enemy (quests count it) plus the kind and cartel. Returns {bounty, loot: [{item, qty}]}.
static func enemy_down(g, kind: String, cartel: String, rng: RandomNumberGenerator) -> Dictionary:
	var r: Array = enemy_cfg(g, kind).get("bounty", [0, 0])
	var amount := rng.randi_range(int(r[0]), int(r[1]))
	g.credits += amount
	g.combat.kills = int(g.combat.kills) + 1
	if cartel != "":
		Cartels.on_kill(g, cartel)
	if kind == "interceptor":  # shooting down the Authority is a crime
		g.add_heat(float(g.data.get("interdiction", {}).get("authority_kill_heat", 0.0)))
	var loot := roll_loot(g, kind, rng)
	g._emit("pirate_down", {"bounty": amount, "kind": kind, "cartel": cartel})
	return {"bounty": amount, "loot": loot}


## What a wreck drops: [{item, qty}] with item = a raw, an additive, a product key, "credits" or "missiles".
static func roll_loot(g, kind: String, rng: RandomNumberGenerator) -> Array:
	var t: Dictionary = cfg(g).get("loot", {}).get(kind, {})
	var out: Array = []
	if t.is_empty() or rng.randf() >= float(t.get("chance", 0.0)):
		return out
	var c: Array = t.get("credits", [0, 0])
	var cr := rng.randi_range(int(c[0]), int(c[1]))
	if cr > 0:
		out.append({"item": "credits", "qty": cr})
	if rng.randf() < float(t.get("missiles", 0.0)):
		out.append({"item": "missiles", "qty": rng.randi_range(1, 2)})
	var items: Dictionary = t.get("items", {})
	if not items.is_empty():
		var keys: Array = items.keys()
		var k: String = keys[rng.randi() % keys.size()]
		var n := rng.randi_range(1, maxi(1, int(items[k])))
		if k == "product":
			var bases: Array = g.data.bases.keys()
			var b: String = bases[rng.randi() % bases.size()]
			k = Mixing.key(b, [g.data.bases[b].innate])
		out.append({"item": k, "qty": n})
	return out


## Picks up one floating loot crate: credits, missiles (up to the pods' capacity) and cargo (up to the free hold).
## Returns {ok, msg, taken: [{item, qty}]}; ok = false only when nothing fit.
static func collect_loot(g, loot: Array) -> Dictionary:
	var taken: Array = []
	var parts: Array = []
	for l in loot:
		var item: String = l.item
		var n := int(l.qty)
		if item == "credits":
			g.credits += n
			taken.append(l)
			parts.append("+%d cr" % n)
		elif item == "missiles":
			var m := mini(n, missile_cap(g) - int(g.combat.missiles))
			if m > 0:
				g.combat.missiles = int(g.combat.missiles) + m
				taken.append({"item": item, "qty": m})
				parts.append("+%d missile%s" % [m, "" if m == 1 else "s"])
		else:
			var m := mini(n, g.cargo_free())
			if m > 0:
				g._add(g.cargo, item, m)
				taken.append({"item": item, "qty": m})
				parts.append("+%d %s" % [m, g.item_name(item)])
	if taken.is_empty():
		return {"ok": false, "msg": "Loot crate: no room in the hold.", "taken": []}
	g._emit("loot", {"taken": taken})
	return {"ok": true, "msg": "Loot: " + ", ".join(PackedStringArray(parts)), "taken": taken}


## Chance that the next arrival in the current system is a cartel wing of `id` instead of a lone raider.
static func wing_chance(g, id: String) -> float:
	var w: Dictionary = cfg(g).get("wings", {})
	if id == "" or Cartels.weakened(g, id):
		return 0.0
	var c := Cartels.hostility(g, id) / 100.0 * float(w.get("chance_hostility", 0.0)) + Cartels.system_share(g, g.system, id) * float(w.get("chance_share", 0.0))
	return clampf(c, 0.0, float(w.get("max_chance", 0.75)))


## Ships of a cartel wing: the gang's wing, a gunship once it is angry enough, one extra fighter when at war.
static func wing_units(g, id: String) -> Array:
	var w: Dictionary = cfg(g).get("wings", {})
	var units: Array = []
	var base: Dictionary = Cartels.gang(g, id).get("wing", {"fighter": 2})
	for k in base:
		for i in int(base[k]):
			units.append(str(k))
	var h := Cartels.hostility(g, id)
	if h >= float(w.get("gunship_hostility", 999.0)) and not units.has("gunship"):
		units.append("gunship")
	if h >= float(w.get("extra_fighter_hostility", 999.0)):
		units.append("fighter")
	return units


## What arrives next in the current system: {"cartel": "", "units": ["pirate"]} or a cartel wing.
static func pick_spawn(g, rng: RandomNumberGenerator) -> Dictionary:
	for p in Cartels.present(g, g.system):
		if rng.randf() < wing_chance(g, p.id):
			return {"cartel": p.id, "units": wing_units(g, p.id)}
	return {"cartel": "", "units": ["pirate"]}


# ---------------------------------------------------------------- cartel bases (raids)

## The cartel that runs a base location ("" if `loc` is no cartel base).
static func base_cartel(g, loc: String) -> String:
	return str(g.data.locations.get(loc, {}).get("cartel", ""))


## A base fights while its cartel is not rebuilding after a raid.
static func base_active(g, loc: String) -> bool:
	var c := base_cartel(g, loc)
	return c != "" and not Cartels.weakened(g, c)


## The base of `cartel` was destroyed: reward credits, a big influence swing (Cartels.on_raid), loot.
## Returns {credits, loot}.
static func raid_base(g, loc: String, rng: RandomNumberGenerator) -> Dictionary:
	var c := base_cartel(g, loc)
	if c == "" or Cartels.weakened(g, c):
		return {"credits": 0, "loot": []}
	var r: Array = cfg(g).get("bases", {}).get("reward", [0, 0])
	var amount := rng.randi_range(int(r[0]), int(r[1]))
	g.credits += amount
	Cartels.on_raid(g, c)
	var loot := roll_loot(g, "base", rng)
	g._emit("base_raided", {"loc": loc, "cartel": c, "credits": amount})
	return {"credits": amount, "loot": loot}


## How hard pirates press in the current system: lawless systems and a hold full of product attract more.
static func pressure(g) -> float:
	var s: Dictionary = cfg(g).spawn
	var units := 0
	for k in g.cargo:
		if Mixing.is_product(k):
			units += int(g.cargo[k])
	var hauler := minf(1.0, float(units) / float(s.cargo_units))
	return float(s.system_mult.get(g.system, 1.0)) * (1.0 + float(s.cargo_pressure) * hauler) * Cartels.pressure_mult(g, g.system)


## Seconds between pirate arrivals (while in deep space) and how many may be alive at once.
static func spawn_interval(g) -> float:
	return float(cfg(g).spawn.interval) / pressure(g)


static func max_pirates(g) -> int:
	return clampi(int(roundf(float(cfg(g).spawn.max) * minf(pressure(g), 1.5))), 1, int(cfg(g).spawn.max) + 2)


## Pirates only hunt in deep space: farther than `safe_radius` from every location (distance to the nearest edge).
static func is_deep_space(g, nearest_location_dist: float) -> bool:
	return nearest_location_dist > float(cfg(g).spawn.safe_radius)


# ---------------------------------------------------------------- defeat and the mechanic

## The wreck is looted: part of the hold is gone, a fine for the tow, hull comes back partly repaired.
static func defeat(g) -> Dictionary:
	var d: Dictionary = cfg(g).defeat
	var lost := 0
	for k in g.cargo.keys():
		var n := int(g.cargo[k])
		var take := int(ceil(float(n) * float(d.cargo_lost)))
		g.cargo[k] = n - take
		lost += take
		if int(g.cargo[k]) <= 0:
			g.cargo.erase(k)
	var fine := mini(g.credits, maxi(int(d.fine_min), int(g.credits * float(d.fine_ratio))))
	g.credits -= fine
	g.combat.hull = max_hull(g) * float(d.respawn_hull)
	g.combat.shield = 0.0
	g.combat.idle = 0.0
	g.combat.boost = float(cfg(g).boost.max)
	g._emit("ship_destroyed", {"lost": lost, "fine": fine})
	return {"ok": false, "msg": "Your ship was shot to pieces. Pirates looted %d units, the tow cost %d cr." % [lost, fine], "lost": lost, "fine": fine}


static func repair_cost(g) -> int:
	return int(ceil((max_hull(g) - float(g.combat.hull)) * float(cfg(g).repair_per_hull)))


static func repair(g) -> Dictionary:
	if not g.loc_data().get("shipyard", false):
		return g._fail("No mechanic here.")
	var cost := repair_cost(g)
	if cost <= 0:
		return g._fail("The hull is in perfect shape.")
	if cost > g.credits:
		return g._fail("Not enough credits (%d cr)." % cost)
	g.credits -= cost
	g.combat.hull = max_hull(g)
	g.event.emit("repaired", {"cost": cost})
	return g._ok("Hull repaired for %d cr." % cost)


static func restock_cost(g) -> int:
	return maxi(0, missile_cap(g) - int(g.combat.missiles)) * int(cfg(g).missile.price)


static func restock(g) -> Dictionary:
	if not g.loc_data().get("shipyard", false):
		return g._fail("No mechanic here.")
	if not has_missiles(g):
		return g._fail("No missile pods installed.")
	var cost := restock_cost(g)
	if cost <= 0:
		return g._fail("Missile pods are full.")
	if cost > g.credits:
		return g._fail("Not enough credits (%d cr)." % cost)
	g.credits -= cost
	g.combat.missiles = missile_cap(g)
	g.event.emit("restocked", {"cost": cost})
	return g._ok("Restocked missiles for %d cr." % cost)


# ---------------------------------------------------------------- save / balance helpers

static func to_save(g) -> Dictionary:
	var c: Dictionary = g.combat
	return {"hull": snappedf(float(c.hull), 0.1), "shield": snappedf(float(c.shield), 0.1), "missiles": int(c.missiles), "kills": int(c.kills), "secondary": str(c.get("secondary", "missile"))}


## Old saves have no "space": the ship starts undamaged.
static func from_save(g, d: Dictionary) -> void:
	reset(g)
	var s: Dictionary = d.get("space", {})
	if s.is_empty():
		return
	g.combat.hull = clampf(float(s.get("hull", max_hull(g))), 1.0, max_hull(g))
	g.combat.shield = clampf(float(s.get("shield", max_shield(g))), 0.0, max_shield(g))
	g.combat.missiles = clampi(int(s.get("missiles", missile_cap(g))), 0, missile_cap(g))
	g.combat.kills = maxi(0, int(s.get("kills", 0)))
	g.combat.secondary = str(s.get("secondary", "missile"))


## Seconds to shoot down one pirate with lasers at `hit_rate` (share of shots that land).
static func seconds_to_kill(g, hit_rate: float) -> float:
	var shots: float = ceil(float(cfg(g).pirate.hull) / laser_damage(g))
	return shots * float(cfg(g).laser.cooldown) / maxf(hit_rate, 0.01)


## Seconds the ship survives `n` pirates firing at it, each landing `hit_rate` of its shots.
static func seconds_to_die(g, n: int, hit_rate: float) -> float:
	var p: Dictionary = cfg(g).pirate
	var dps := float(p.damage) / float(p.fire_cooldown) * hit_rate * n
	return (max_hull(g) + max_shield(g)) / dps
