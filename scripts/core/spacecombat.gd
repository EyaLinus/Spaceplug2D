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
	return {"hull": max_hull(g), "shield": max_shield(g), "missiles": missile_cap(g), "kills": 0, "boost": float(cfg(g).boost.max), "idle": 0.0}


## Full hull, shield, ammo and boost (new game).
static func reset(g) -> void:
	g.combat = fresh(g)


# ---------------------------------------------------------------- stats from modules

static func max_hull(g) -> float:
	return float(g.data.upgrades.hull.levels[g.upgrades.hull])


static func max_shield(g) -> float:
	return float(g.data.upgrades.shield.levels[g.upgrades.shield])


static func laser_damage(g) -> float:
	return float(g.data.upgrades.laser.levels[g.upgrades.laser])


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
	return {"hull": snappedf(float(c.hull), 0.1), "shield": snappedf(float(c.shield), 0.1), "missiles": int(c.missiles), "kills": int(c.kills)}


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


## Seconds to shoot down one pirate with lasers at `hit_rate` (share of shots that land).
static func seconds_to_kill(g, hit_rate: float) -> float:
	var shots: float = ceil(float(cfg(g).pirate.hull) / laser_damage(g))
	return shots * float(cfg(g).laser.cooldown) / maxf(hit_rate, 0.01)


## Seconds the ship survives `n` pirates firing at it, each landing `hit_rate` of its shots.
static func seconds_to_die(g, n: int, hit_rate: float) -> float:
	var p: Dictionary = cfg(g).pirate
	var dps := float(p.damage) / float(p.fire_cooldown) * hit_rate * n
	return (max_hull(g) + max_shield(g)) / dps
