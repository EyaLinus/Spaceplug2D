extends RefCounted
## Escort missions (E4 leftover), headless. You take a freight job at a location, undock and fly the NPC freighter
## to its destination (possibly through a jump gate) while enemy waves (SpaceCombat.pick_spawn: lone raiders or cartel
## wings) go for it. Arrival pays `reward` + `bonus` scaled by the hull it still has; if it dies the job fails.
## Data: content.json "escort" (freighter stats, wave rules, missions). The freighter's kinematics live here (positions
## come from the location data), the world only draws it and routes enemy bolts into `damage`.
##
## State `g.escort` (saved): {job: {} or {mission, sys, pos: [x, y], hull, at_gate}, last: {mission: day finished},
## done: n}. Runtime only inside the job: near, waiting, clock, spawned. Events (also seen by quests): escort_started,
## escort_done {mission, credits, hull_ratio}, escort_failed {mission, why}.

const Galaxy = preload("res://scripts/core/galaxy.gd")
const SpaceCombat = preload("res://scripts/core/spacecombat.gd")


static func cfg(g) -> Dictionary:
	return g.data.get("escort", {})


static func fcfg(g) -> Dictionary:
	return cfg(g).get("freighter", {})


static func missions(g) -> Dictionary:
	return cfg(g).get("missions", {})


static func empty_state() -> Dictionary:
	return {"job": {}, "last": {}, "done": 0}


static func active(g) -> bool:
	return not (g.escort.get("job", {}) as Dictionary).is_empty()


static func job(g) -> Dictionary:
	return g.escort.get("job", {})


static func mission(g) -> Dictionary:
	return missions(g).get(str(job(g).get("mission", "")), {})


static func max_hull(g) -> float:
	return float(fcfg(g).get("hull", 300))


static func hull_ratio(g) -> float:
	return clampf(float(job(g).get("hull", 0.0)) / max_hull(g), 0.0, 1.0) if active(g) else 0.0


static func loc_pos(g, loc: String) -> Vector2:
	var p: Array = g.data.locations.get(loc, {}).get("pos", [0, 0])
	return Vector2(float(p[0]), float(p[1]))


static func loc_radius(g, loc: String) -> float:
	return float(g.data.locations.get(loc, {}).get("radius", 60))


## Where the freighter is right now (only meaningful while a job is active).
static func pos(g) -> Vector2:
	var p: Array = job(g).get("pos", [0, 0])
	return Vector2(float(p[0]), float(p[1]))


## Location the freighter is flying to right now: the destination in its system, else the gate on the way there.
static func goal(g) -> String:
	if not active(g):
		return ""
	var dest := str(mission(g).get("to", ""))
	var dsys: String = g.loc_system(dest)
	var sys := str(job(g).sys)
	if sys == dsys:
		return dest
	var rt: Array = Galaxy.route(g, sys, dsys)
	if rt.size() < 2:
		return ""
	var gs: Array = Galaxy.gates(g, sys, str(rt[1]))
	return str(gs[0]) if not gs.is_empty() else ""


# ---------------------------------------------------------------- offers

## Days before `mid` can be taken again (0 = available).
static func cooldown_left(g, mid: String) -> int:
	if not g.escort.last.has(mid):
		return 0
	return maxi(0, int(g.escort.last[mid]) + int(cfg(g).get("cooldown_days", 0)) - g.day)


static func reward(g, mid: String, ratio := 1.0) -> int:
	var m: Dictionary = missions(g).get(mid, {})
	return int(m.get("reward", 0)) + int(round(float(m.get("bonus", 0)) * clampf(ratio, 0.0, 1.0)))


## Jobs on offer at `loc`: [{id, name, desc, to, to_name, reward, bonus, waves, cooldown, locked}]; `locked` = not yet
## available (min_day). Empty while another escort runs is NOT applied here: the UI shows them disabled.
static func offers_at(g, loc: String) -> Array:
	var out: Array = []
	for mid in missions(g):
		var m: Dictionary = missions(g)[mid]
		if str(m.from) != loc:
			continue
		out.append({"id": mid, "name": str(m.name), "desc": str(m.get("desc", "")), "to": str(m.to), "to_name": str(g.data.locations[m.to].name),
			"reward": int(m.reward), "bonus": int(m.get("bonus", 0)), "waves": int(m.get("waves", 1)),
			"cooldown": cooldown_left(g, mid), "locked": g.day < int(m.get("min_day", 1))})
	return out


## Takes the job at the location you are docked at. The freighter waits next to it; undock to start.
static func accept(g, mid: String) -> Dictionary:
	var m: Dictionary = missions(g).get(mid, {})
	if m.is_empty():
		return g._fail("No such job.")
	if active(g):
		return g._fail("You are already escorting a freighter.")
	if g.location != str(m.from):
		return g._fail("Take this job at %s." % g.data.locations[m.from].name)
	if g.day < int(m.get("min_day", 1)):
		return g._fail("Not available before day %d." % int(m.min_day))
	if cooldown_left(g, mid) > 0:
		return g._fail("No new cargo yet (%d days)." % cooldown_left(g, mid))
	var start: Vector2 = loc_pos(g, str(m.from)) + Vector2(90, loc_radius(g, str(m.from)) + 90)
	g.escort.job = {"mission": mid, "sys": g.loc_system(str(m.from)), "pos": [start.x, start.y], "hull": max_hull(g), "at_gate": false,
		"near": true, "waiting": false, "clock": 0.0, "spawned": 0}
	g._emit("escort_started", {"mission": mid})
	return g._ok("%s: undock and fly the freighter to %s." % [m.name, g.data.locations[m.to].name])


static func abandon(g) -> Dictionary:
	if not active(g):
		return g._fail("No escort running.")
	fail(g, "abandoned")
	return g._ok("You cut the freighter loose.")


## Ends the job without pay. `why`: destroyed | abandoned | left_behind.
static func fail(g, why: String) -> void:
	if not active(g):
		return
	var mid := str(job(g).mission)
	g.escort.job = {}
	g._emit("escort_failed", {"mission": mid, "why": why})


static func fail_text(g, mid: String, why: String) -> String:
	var n := str(missions(g).get(mid, {}).get("name", "Escort"))
	match why:
		"destroyed":
			return "%s failed: the freighter was destroyed." % n
		"left_behind":
			return "%s failed: you jumped without the freighter." % n
	return "%s cancelled." % n


# ---------------------------------------------------------------- flight

## Moves the freighter one step along its route. It follows only while you are within `leash` (it waits for you and
## resumes inside leash × resume). No-op while docked or when the job is in another system. Returns {state}:
## moving | waiting | at_gate | arrived (pay was handled) | idle.
static func step(g, dt: float, ship_pos: Vector2) -> Dictionary:
	if not active(g) or g.location != "" or g.system != str(job(g).sys):
		return {"state": "idle"}
	var j: Dictionary = job(g)
	var f: Dictionary = fcfg(g)
	var here := pos(g)
	var d_ship := here.distance_to(ship_pos)
	j.near = d_ship <= float(f.jump_follow)
	var gl := goal(g)
	if gl == "":
		return {"state": "idle"}
	var gp := loc_pos(g, gl)
	if here.distance_to(gp) <= loc_radius(g, gl) + float(f.arrive):
		if gl == str(mission(g).to):
			arrive(g)
			return {"state": "arrived"}
		j.at_gate = true
		return {"state": "at_gate"}
	j.at_gate = false
	if d_ship > float(f.leash):
		j.waiting = true
	elif d_ship < float(f.leash) * float(f.resume):
		j.waiting = false
	if j.waiting:
		return {"state": "waiting"}
	var next := here.move_toward(gp, float(f.speed) * dt)
	j.pos = [next.x, next.y]
	return {"state": "moving"}


## The freighter made it: pay reward + bonus × hull left.
static func arrive(g) -> Dictionary:
	if not active(g):
		return {}
	var mid := str(job(g).mission)
	var ratio := hull_ratio(g)
	var pay := reward(g, mid, ratio)
	g.credits += pay
	g.stats.earned += pay
	g.escort.last[mid] = g.day
	g.escort.done = int(g.escort.done) + 1
	g.escort.job = {}
	g._emit("escort_done", {"mission": mid, "credits": pay, "hull_ratio": ratio})
	return {"credits": pay, "hull_ratio": ratio, "mission": mid}


## Called by Game.jump: the freighter follows through the gate if it is close, else the job fails.
static func on_jump(g, from_sys: String, to_sys: String, arrive_loc: String) -> void:
	if not active(g) or str(job(g).sys) != from_sys:
		return
	if not bool(job(g).get("near", false)):
		fail(g, "left_behind")
		return
	var start := loc_pos(g, arrive_loc) + Vector2(90, loc_radius(g, arrive_loc) + 90) if g.data.locations.has(arrive_loc) else Vector2.ZERO
	var j: Dictionary = job(g)
	j.sys = to_sys
	j.pos = [start.x, start.y]
	j.at_gate = false
	j.waiting = false
	j.near = true


# ---------------------------------------------------------------- enemies

## Damage from an enemy bolt. Returns {hull, destroyed}; the job fails at zero hull.
static func damage(g, amount: float) -> Dictionary:
	if not active(g):
		return {"hull": 0.0, "destroyed": false}
	var j: Dictionary = job(g)
	j.hull = maxf(0.0, float(j.hull) - amount)
	var res := {"hull": float(j.hull), "destroyed": float(j.hull) <= 0.0}
	g.event.emit("escort_hit", res)
	if res.destroyed:
		fail(g, "destroyed")
	return res


## Attackers prefer the freighter when it is in range and you are not right on top of them.
static func prefers_freighter(g, enemy_pos: Vector2, ship_pos: Vector2) -> bool:
	if not active(g) or g.location != "" or g.system != str(job(g).sys):
		return false
	var w: Dictionary = cfg(g).get("waves", {})
	return enemy_pos.distance_to(pos(g)) <= float(w.get("target_range", 1500)) and enemy_pos.distance_to(ship_pos) > float(w.get("provoke", 380))


## Wave clock: after `first`, then every `interval` seconds a new group arrives (SpaceCombat.pick_spawn), up to the
## mission's wave count, while you are near the freighter and fewer than max_enemies are alive.
## Returns {} or {cartel, units}.
static func tick_wave(g, dt: float, alive: int, rng: RandomNumberGenerator) -> Dictionary:
	if not active(g) or g.system != str(job(g).sys):
		return {}
	var j: Dictionary = job(g)
	if int(j.spawned) >= int(mission(g).get("waves", 1)) or not bool(j.get("near", false)) or bool(j.get("waiting", false)):
		return {}
	var w: Dictionary = cfg(g).get("waves", {})
	j.clock = float(j.clock) + dt
	var need := float(w.get("first", 10.0)) if int(j.spawned) == 0 else float(w.get("interval", 15.0))
	if float(j.clock) < need or alive >= int(w.get("max_enemies", 4)):
		return {}
	j.clock = 0.0
	j.spawned = int(j.spawned) + 1
	return SpaceCombat.pick_spawn(g, rng)


## Waves still to come (HUD).
static func waves_left(g) -> int:
	return maxi(0, int(mission(g).get("waves", 0)) - int(job(g).get("spawned", 0))) if active(g) else 0


# ---------------------------------------------------------------- save

static func to_save(g) -> Dictionary:
	var j: Dictionary = job(g)
	var out := {"last": g.escort.last.duplicate(), "done": int(g.escort.done), "job": {}}
	if not j.is_empty():
		out.job = {"mission": j.mission, "sys": j.sys, "pos": [snappedf(float(j.pos[0]), 0.1), snappedf(float(j.pos[1]), 0.1)],
			"hull": snappedf(float(j.hull), 0.1), "at_gate": bool(j.at_gate), "spawned": int(j.spawned)}
	return out


## Old saves have no "escort": no job, no cooldowns. A job whose mission or system no longer fits the save is dropped.
static func from_save(g, d: Dictionary) -> void:
	g.escort = empty_state()
	for mid in d.get("last", {}):
		if missions(g).has(str(mid)):
			g.escort.last[str(mid)] = int(d.last[mid])
	g.escort.done = maxi(0, int(d.get("done", 0)))
	var j: Dictionary = d.get("job", {})
	if j.is_empty() or not missions(g).has(str(j.get("mission", ""))) or not g.data.systems.has(str(j.get("sys", ""))):
		return
	if g.location != "" and g.loc_system(g.location) != str(j.sys):
		return
	if g.location == "" and g.system != str(j.sys):
		return
	var p: Array = j.get("pos", [0, 0])
	g.escort.job = {"mission": str(j.mission), "sys": str(j.sys), "pos": [float(p[0]), float(p[1])],
		"hull": clampf(float(j.get("hull", max_hull(g))), 1.0, max_hull(g)), "at_gate": bool(j.get("at_gate", false)),
		"near": true, "waiting": false, "clock": 0.0, "spawned": clampi(int(j.get("spawned", 0)), 0, int(missions(g)[str(j.mission)].get("waves", 1)))}
