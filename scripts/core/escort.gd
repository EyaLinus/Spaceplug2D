extends RefCounted
## Escort missions (E4 leftover): you guard an NPC freighter along a route of locations while cartel wings raid it.
## Rules over a Game; contracts and numbers in content.json "escort". Headless: the world (escort_layer.gd) supplies
## the geometry as two numbers per frame (are you near, how much hostile weight is on top of the freighter).
##
## Flow: accept at the contract's start location (Escort app of the Com-Phone) -> status "waiting" -> undock there
## -> status "enroute". The route is a list of locations; a hop inside one system is a "fly" leg that fills while you
## stay near the freighter, a hop between systems is a "jump" leg: the freighter waits at the gate until you jump
## (jumping without her, or flying off for `abandon_seconds`, or being wrecked, fails the job). Raids come on a
## timer; raiders near the freighter hurt her at `raider_dps` per threat point. Reaching the last location pays
## the reward (+ a bonus for hull left); the freighter dying pays nothing and may cost a fine.
##
## State on the Game (`g.escort`, saved): {active: {} or {id, status, leg, progress, hull, away, near, raid_clock,
## raids, pending}, done: [id], failed: n, earned: n}. Events: escort_accepted, escort_launched, escort_leg,
## escort_raid, escort_hit, escort_done {id, reward}, escort_failed {id, reason, fine}.

const SpaceCombat = preload("res://scripts/core/spacecombat.gd")
const Cartels = preload("res://scripts/core/cartels.gd")


static func cfg(g) -> Dictionary:
	return g.data.get("escort", {})


static func rules(g) -> Dictionary:
	return cfg(g).get("rules", {})


static func defs(g) -> Dictionary:
	return cfg(g).get("contracts", {})


static func def(g, id: String) -> Dictionary:
	return defs(g).get(id, {})


static func init_state() -> Dictionary:
	return {"active": {}, "done": [], "failed": 0, "earned": 0}


static func active(g) -> Dictionary:
	return g.escort.get("active", {})


static func is_active(g) -> bool:
	return not active(g).is_empty()


## True while the freighter is flying with you (undocked, not yet there).
static func enroute(g) -> bool:
	return is_active(g) and str(active(g).status) == "enroute"


static func is_done(g, id: String) -> bool:
	return (g.escort.done as Array).has(id)


# ---------------------------------------------------------------- route

static func route(g, id: String) -> Array:
	return def(g, id).get("route", [])


static func legs(g, id: String) -> int:
	return maxi(0, route(g, id).size() - 1)


## "fly" (both ends in one system) or "jump" (the next waypoint is in another system).
static func leg_kind(g, id: String, leg: int) -> String:
	var r := route(g, id)
	if leg < 0 or leg + 1 >= r.size():
		return ""
	return "fly" if g.loc_system(str(r[leg])) == g.loc_system(str(r[leg + 1])) else "jump"


## Location id the freighter flies from / to on the current leg ("" without a job).
static func leg_from(g) -> String:
	var a := active(g)
	return str(route(g, str(a.id))[int(a.leg)]) if not a.is_empty() else ""


static func leg_to(g) -> String:
	var a := active(g)
	return str(route(g, str(a.id))[int(a.leg) + 1]) if not a.is_empty() else ""


## Star system the freighter is in right now.
static func freighter_system(g) -> String:
	return g.loc_system(leg_from(g)) if is_active(g) else ""


static func current_kind(g) -> String:
	var a := active(g)
	return leg_kind(g, str(a.id), int(a.leg)) if not a.is_empty() else ""


static func leg_seconds(g, id: String) -> float:
	return float(def(g, id).get("leg_seconds", rules(g).get("leg_seconds", 40.0)))


static func min_day(g, id: String) -> int:
	return int(def(g, id).get("min_day", rules(g).get("min_day", 1)))


# ---------------------------------------------------------------- offers

## Contracts you can take right now at the location you are docked at.
static func available(g) -> Array:
	var out: Array = []
	if g.location == "" or is_active(g):
		return out
	for id in defs(g):
		if str(route(g, id)[0]) == g.location and g.day >= min_day(g, id) and not is_done(g, id):
			out.append(id)
	return out


## Open contracts that start somewhere else (or are not ready yet).
static func elsewhere(g) -> Array:
	var out: Array = []
	for id in defs(g):
		if not is_done(g, id) and not available(g).has(id):
			out.append(id)
	return out


static func accept(g, id: String) -> Dictionary:
	if not defs(g).has(id):
		return g._fail("No such job.")
	if is_active(g):
		return g._fail("You are already escorting someone.")
	if is_done(g, id):
		return g._fail("Already delivered.")
	if g.location == "" or str(route(g, id)[0]) != g.location:
		return g._fail("Take this job at %s." % g.data.locations[route(g, id)[0]].name)
	if g.day < min_day(g, id):
		return g._fail("The client is not ready yet.")
	var d := def(g, id)
	g.escort.active = {"id": id, "status": "waiting", "leg": 0, "progress": 0.0, "hull": float(d.hull), "away": 0.0, "near": true,
		"raid_clock": 0.0, "raids": 0, "pending": false}
	g._emit("escort_accepted", {"id": id})
	return g._ok("%s will launch when you undock." % d.freighter)


## Gives the job up. Free before launch, a failure (and the fine) once she is under way.
static func cancel(g) -> Dictionary:
	if not is_active(g):
		return g._fail("No escort job.")
	if str(active(g).status) == "waiting":
		g.escort.active = {}
		return g._ok("Job cancelled.")
	fail(g, "cancelled")
	return g._ok("You abandoned the freighter.")


# ---------------------------------------------------------------- events from the core

static func on_event(g, kind: String, p: Dictionary) -> void:
	if not is_active(g) or kind.begins_with("escort_"):
		return
	var a := active(g)
	match kind:
		"undocked":
			if str(a.status) == "waiting" and str(p.get("location", "")) == str(route(g, str(a.id))[0]):
				a.status = "enroute"
				g._emit("escort_launched", {"id": a.id})
		"jumped":
			if str(a.status) != "enroute":
				return
			if current_kind(g) == "jump" and bool(a.near) and str(p.get("to", "")) == g.loc_system(leg_to(g)):
				_next_leg(g)
			else:
				fail(g, "left")
		"ship_destroyed":
			if str(a.status) == "enroute":
				fail(g, "wrecked")


# ---------------------------------------------------------------- per-frame rules

## Seconds of play. `near` = the player is within `near_radius` of the freighter, `threat` = hostile weight on top of
## her (see threat_of). Does nothing while docked or before launch.
static func tick(g, dt: float, near: bool, threat: float) -> void:
	if not enroute(g) or g.location != "":
		return
	var a := active(g)
	a.near = near
	var r := rules(g)
	if not near:
		a.away = float(a.away) + dt
		if float(a.away) >= float(r.get("abandon_seconds", 25.0)):
			fail(g, "abandoned")
			return
	else:
		a.away = 0.0
	if threat > 0.0:
		var dmg := threat * float(r.get("raider_dps", 5.0)) * dt
		a.hull = maxf(0.0, float(a.hull) - dmg)
		g._emit("escort_hit", {"hull": a.hull, "damage": dmg})
		if float(a.hull) <= 0.0:
			fail(g, "destroyed")
			return
	if current_kind(g) == "fly" and near and threat <= 0.0:
		a.progress = float(a.progress) + dt / leg_seconds(g, str(a.id))
	# raids come on a timer while you are with her (also while she waits at a gate)
	if near and int(a.raids) < int(def(g, str(a.id)).get("max_raids", 0)) and not bool(a.pending):
		a.raid_clock = float(a.raid_clock) + dt
		var due := float(r.get("first_raid", 12.0)) if int(a.raids) == 0 else float(r.get("raid_interval", 30.0))
		if float(a.raid_clock) >= due:
			a.pending = true
	if float(a.progress) >= 1.0 and current_kind(g) == "fly":
		_next_leg(g)


static func _next_leg(g) -> void:
	var a := active(g)
	a.leg = int(a.leg) + 1
	a.progress = 0.0
	if int(a.leg) >= legs(g, str(a.id)):
		complete(g)
	else:
		g._emit("escort_leg", {"id": a.id, "leg": a.leg})


## Hostile weight of the ships on top of the freighter: `kinds` is the list of enemy kinds in raid range.
static func threat_of(g, kinds: Array) -> float:
	var t := 0.0
	var w: Dictionary = rules(g).get("threat", {})
	for k in kinds:
		t += float(w.get(str(k), 1.0))
	return t


## A raid is due: returns {cartel, units} once and clears the flag, else {}. The cartel is the contract's raider of
## the freighter's system (falls back to the cartel with most ground there); the wing is capped.
static func take_raid(g) -> Dictionary:
	var a := active(g)
	if a.is_empty() or not bool(a.pending):
		return {}
	a.pending = false
	a.raid_clock = 0.0
	a.raids = int(a.raids) + 1
	var sys := freighter_system(g)
	var cartel := str(def(g, str(a.id)).get("raiders", {}).get(sys, ""))
	if cartel == "" or Cartels.weakened(g, cartel):
		cartel = ""
		for p in Cartels.present(g, sys):
			if not Cartels.weakened(g, p.id):
				cartel = str(p.id)
				break
	var units: Array = SpaceCombat.wing_units(g, cartel) if cartel != "" else ["pirate", "pirate"]
	units = units.slice(0, int(rules(g).get("wing_cap", 4)))
	var raid := {"cartel": cartel, "units": units}
	g._emit("escort_raid", raid.duplicate())
	return raid


# ---------------------------------------------------------------- end of the job

static func hull_ratio(g) -> float:
	var a := active(g)
	return clampf(float(a.hull) / float(def(g, str(a.id)).hull), 0.0, 1.0) if not a.is_empty() else 0.0


static func complete(g) -> Dictionary:
	var a := active(g)
	var id := str(a.id)
	var d := def(g, id)
	var ratio := hull_ratio(g)
	var reward := int(d.reward) + int(round(float(d.reward) * float(rules(g).get("hull_bonus", 0.0)) * ratio))
	g.credits += reward
	g.escort.earned = int(g.escort.earned) + reward
	(g.escort.done as Array).append(id)
	g.escort.active = {}
	g._emit("escort_done", {"id": id, "reward": reward, "hull": ratio})
	return {"ok": true, "reward": reward}


## The job ends badly. reason: destroyed | abandoned | left | wrecked | cancelled. Returns the fine paid.
static func fail(g, reason: String) -> int:
	var a := active(g)
	if a.is_empty():
		return 0
	var id := str(a.id)
	var fine := mini(g.credits, int(def(g, id).get("fail_fine", 0)))
	g.credits -= fine
	g.escort.failed = int(g.escort.failed) + 1
	g.escort.active = {}
	g._emit("escort_failed", {"id": id, "reason": reason, "fine": fine})
	return fine


static func fail_text(reason: String) -> String:
	match reason:
		"destroyed":
			return "The freighter was shot to pieces. The client wants a word."
		"abandoned":
			return "You left the freighter on her own too long. She turned back."
		"left":
			return "You jumped without your charge. The deal is off."
		"wrecked":
			return "Your ship went down. The freighter ran for home."
	return "Escort job failed."


# ---------------------------------------------------------------- HUD / UI text

## One-line status for the HUD, "" without a job.
static func hint(g) -> String:
	var a := active(g)
	if a.is_empty():
		return ""
	var d := def(g, str(a.id))
	if str(a.status) == "waiting":
		return "Escort: %s waits - undock at %s to launch." % [d.freighter, g.data.locations[route(g, str(a.id))[0]].name]
	var to: String = str(g.data.locations[leg_to(g)].name)
	var what := ("jump through to %s" % to) if current_kind(g) == "jump" else ("-> %s %d%%" % [to, int(float(a.progress) * 100.0)])
	var s := "Escort: %s %s, hull %d%%" % [d.freighter, what, int(hull_ratio(g) * 100.0)]
	if not bool(a.near):
		s += " - STAY CLOSE (%ds)" % maxi(0, int(ceil(float(rules(g).get("abandon_seconds", 25.0)) - float(a.away))))
	return s


# ---------------------------------------------------------------- save / load

static func to_save(g) -> Dictionary:
	var a := active(g)
	var out := {"done": (g.escort.done as Array).duplicate(), "failed": int(g.escort.failed), "earned": int(g.escort.earned), "active": {}}
	if not a.is_empty():
		out.active = {"id": a.id, "status": a.status, "leg": int(a.leg), "progress": snappedf(float(a.progress), 0.001), "hull": snappedf(float(a.hull), 0.1),
			"raid_clock": snappedf(float(a.raid_clock), 0.1), "raids": int(a.raids)}
	return out


## Old saves have no escort block: no job, nothing delivered. Unknown contracts are dropped.
static func from_save(g, d: Dictionary) -> void:
	g.escort = init_state()
	for id in d.get("done", []):
		if defs(g).has(str(id)) and not is_done(g, str(id)):
			g.escort.done.append(str(id))
	g.escort.failed = maxi(0, int(d.get("failed", 0)))
	g.escort.earned = maxi(0, int(d.get("earned", 0)))
	var a: Dictionary = d.get("active", {})
	var id := str(a.get("id", ""))
	if a.is_empty() or not defs(g).has(id):
		return
	var leg := clampi(int(a.get("leg", 0)), 0, maxi(0, legs(g, id) - 1))
	var status := str(a.get("status", "waiting"))
	g.escort.active = {"id": id, "status": status if status in ["waiting", "enroute"] else "waiting", "leg": leg,
		"progress": clampf(float(a.get("progress", 0.0)), 0.0, 0.999), "hull": clampf(float(a.get("hull", def(g, id).hull)), 1.0, float(def(g, id).hull)),
		"away": 0.0, "near": true, "raid_clock": maxf(0.0, float(a.get("raid_clock", 0.0))), "raids": maxi(0, int(a.get("raids", 0))), "pending": false}
