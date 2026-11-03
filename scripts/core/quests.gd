extends RefCounted
## Quests: data-driven missions with ordered steps (data/quests.json, merged into content as `quests`).
## A step completes either on a game event ("on" + optional "match" filter, counted up to "need", summing a payload
## field with "sum") or when a state check holds ("check"). Steps can carry a waypoint ("target"), start effects
## ("on_start": force a customer text, hand out items) and a retry rule (an expired deal sends you back a step).
## Finishing a quest pays its reward and starts the quests listed in "next". The tutorial is the chain of quests
## flagged "tutorial"; it can be skipped. Pure static functions over a Game, no scene dependencies.
##
## State on the Game (`g.quests`, saved): {active: [qid], done: [qid], step: {qid: int}, count: {qid: float},
## tracked: qid}.

const People = preload("res://scripts/core/people.gd")
const Deals = preload("res://scripts/core/deals.gd")
const Bench = preload("res://scripts/core/bench.gd")
const Galaxy = preload("res://scripts/core/galaxy.gd")


static func defs(g) -> Dictionary:
	return g.data.get("quests", {})


static func empty_state() -> Dictionary:
	return {"active": [], "done": [], "step": {}, "count": {}, "tracked": ""}


## Starts the opening quests of a new run (those flagged "start").
static func begin(g) -> void:
	for qid in defs(g):
		if defs(g)[qid].get("start", false):
			start(g, qid)


static func is_active(g, qid: String) -> bool:
	return (g.quests.active as Array).has(qid)


static func is_done(g, qid: String) -> bool:
	return (g.quests.done as Array).has(qid)


static func start(g, qid: String) -> bool:
	if not defs(g).has(qid) or is_active(g, qid) or is_done(g, qid):
		return false
	g.quests.active.append(qid)
	g.quests.step[qid] = 0
	g.quests.count[qid] = 0.0
	if str(g.quests.tracked) == "" or not is_active(g, str(g.quests.tracked)):
		g.quests.tracked = qid
	g._emit("quest_started", {"quest": qid})
	_enter_step(g, qid)
	return true


static func step_index(g, qid: String) -> int:
	return int(g.quests.step.get(qid, 0))


static func steps(g, qid: String) -> Array:
	return defs(g).get(qid, {}).get("steps", [])


## The step the quest is on, {} if it is not active.
static func current(g, qid: String) -> Dictionary:
	if not is_active(g, qid):
		return {}
	var s := steps(g, qid)
	var i := step_index(g, qid)
	return s[i] if i < s.size() else {}


static func count(g, qid: String) -> float:
	return float(g.quests.count.get(qid, 0.0))


## The quest shown in the HUD tracker: the one the player picked, else the first active one ("" = none).
static func tracked(g) -> String:
	var t := str(g.quests.get("tracked", ""))
	if is_active(g, t):
		return t
	return str(g.quests.active[0]) if not (g.quests.active as Array).is_empty() else ""


static func track(g, qid: String) -> void:
	if is_active(g, qid):
		g.quests.tracked = qid
		g._emit("quest_tracked", {"quest": qid})


## "3/5" for counted steps, "" for one-off steps.
static func progress_text(g, qid: String) -> String:
	var s := current(g, qid)
	var need := int(s.get("need", 1))
	if need <= 1 or not s.has("on"):
		return ""
	return "%d/%d" % [mini(int(count(g, qid)), need), need]


## Waypoint of the tracked quest's step: {loc, building | estate | station | contact | stash | app}, {} = none.
static func target(g) -> Dictionary:
	var qid := tracked(g)
	return current(g, qid).get("target", {}) if qid != "" else {}


# ---------------------------------------------------------------- progress

## Called by Game._emit for every core event (and UI notes through Game.note).
static func on_event(g, kind: String, p: Dictionary) -> void:
	if kind.begins_with("quest_") or g.quests.get("active", []).is_empty():
		return
	for qid in (g.quests.active as Array).duplicate():
		if not is_active(g, qid):
			continue
		var s := current(g, qid)
		if s.is_empty():
			continue
		if kind in s.get("retry_on", []) and _matches(s.get("retry_match", {}), p):
			_retry(g, qid, s)
			continue
		if s.has("on") and str(s.on) == kind and _matches(s.get("match", {}), p) and _min_ok(s.get("min", {}), p):
			g.quests.count[qid] = count(g, qid) + (float(p.get(str(s.sum), 0)) if s.has("sum") else 1.0)
			if count(g, qid) >= float(s.get("need", 1)):
				_advance(g, qid)
				continue
		if s.has("check") and check(g, s.check):
			_advance(g, qid)


## Re-evaluates state-based steps (used after loading and by the tracker; events normally cover it).
static func refresh(g) -> void:
	for qid in (g.quests.active as Array).duplicate():
		var s := current(g, qid)
		if s.has("check") and check(g, s.check):
			_advance(g, qid)


## Payload filter: every key must match. "*" = present and not empty, an Array = any of, "base" also matches the
## base of a "product" key ("weed:glow@2" -> "weed").
static func _matches(m: Dictionary, p: Dictionary) -> bool:
	for k in m:
		var have = p.get(k, null)
		if k == "base" and have == null and p.has("product"):
			have = str(p.product).split(":")[0]
		var want = m[k]
		if typeof(want) == TYPE_STRING and want == "*":
			if have == null or str(have) == "":
				return false
		elif typeof(want) == TYPE_ARRAY:
			if have == null or not (want as Array).has(str(have)):
				return false
		elif have == null or str(have) != str(want):
			return false
	return true


static func _min_ok(m: Dictionary, p: Dictionary) -> bool:
	for k in m:
		var v = p.get(k, 0)
		if typeof(v) == TYPE_ARRAY:
			v = (v as Array).size()
		if float(v) < float(m[k]):
			return false
	return true


## State checks: {"type": cargo|credits|debt_max|estates|recipes|dealers|system|location|inside, ...}.
static func check(g, c: Dictionary) -> bool:
	match str(c.get("type", "")):
		"cargo":
			return int(g.cargo.get(str(c.item), 0)) >= int(c.get("min", 1))
		"credits":
			return g.credits >= int(c.get("min", 0))
		"debt_max":
			return g.debt <= int(c.get("max", 0))
		"estates":
			return g.estates.size() - 1 >= int(c.get("min", 1))  # the ship bay does not count
		"recipes":
			return g.recipes.size() >= int(c.get("min", 1))
		"dealers":
			return g.dealers.size() >= int(c.get("min", 1))
		"system":
			return g.system == str(c.id)
		"location":
			return g.location == str(c.id)
		"inside":
			return g.inside_estate == str(c.id)
	return false


static func _enter_step(g, qid: String) -> void:
	var s := current(g, qid)
	if s.is_empty():
		_complete(g, qid)
		return
	_effects(g, s.get("on_start", {}))
	if s.has("check") and check(g, s.check):
		_advance(g, qid)


static func _advance(g, qid: String) -> void:
	var i := step_index(g, qid)
	g._emit("quest_step", {"quest": qid, "step": i})
	g.quests.step[qid] = i + 1
	g.quests.count[qid] = 0.0
	if i + 1 >= steps(g, qid).size():
		_complete(g, qid)
	else:
		_enter_step(g, qid)


static func _retry(g, qid: String, s: Dictionary) -> void:
	g.quests.step[qid] = clampi(int(s.get("retry_to", step_index(g, qid))), 0, steps(g, qid).size() - 1)
	g.quests.count[qid] = 0.0
	g._emit("quest_retry", {"quest": qid, "text": str(s.get("retry_text", ""))})
	_enter_step(g, qid)


static func _complete(g, qid: String, pay := true) -> void:
	g.quests.active.erase(qid)
	if not is_done(g, qid):
		g.quests.done.append(qid)
	g.quests.step.erase(qid)
	g.quests.count.erase(qid)
	var q: Dictionary = defs(g).get(qid, {})
	var reward: Dictionary = q.get("reward", {}) if pay else {}
	_effects(g, reward)
	g._emit("quest_done", {"quest": qid, "reward": reward, "paid": pay})
	for n in q.get("next", []):
		start(g, str(n))
	if str(g.quests.tracked) == qid:
		g.quests.tracked = tracked(g)


## Rewards and step effects: credits, items (to cargo, overflow to the stash), contacts met, a customer text,
## additives for the batch on the tray, extra days on the debt.
static func _effects(g, e: Dictionary) -> void:
	if e.has("credits"):
		g.credits += int(e.credits)
	for item in e.get("items", {}):
		var n := int(e.items[item])
		var fit := mini(n, maxi(g.cargo_free(), 0))
		g._add(g.cargo, item, fit)
		g._add(g.stash, item, n - fit)
	for cid in e.get("meet", []):
		g.meet(str(cid))
	if e.has("offer"):
		var cid := str(e.offer)
		if Deals.open_for(g, cid).is_empty():
			People.state(g, cid).known = true
			Deals.request(g, cid)
	if e.has("tray_additive"):
		var est: String = g.inside_estate if g.inside_estate != "" else "cannery_rig"
		var t: Dictionary = Bench.tray(g, est)
		var need := int(t.get("qty", e.get("tray_fallback", 0)))
		var have := int(g.cargo.get(str(e.tray_additive), 0))
		if need > have:
			g._add(g.cargo, str(e.tray_additive), need - have)
	if e.has("days"):
		g.debt_due_day += int(e.days)


# ---------------------------------------------------------------- tutorial

static func in_tutorial(g) -> bool:
	for qid in g.quests.active:
		if defs(g).get(qid, {}).get("tutorial", false):
			return true
	return false


## Marks every tutorial quest done without rewards and starts what follows the tutorial.
static func skip_tutorial(g) -> void:
	var after: Array = []
	for qid in defs(g):
		var q: Dictionary = defs(g)[qid]
		if not q.get("tutorial", false):
			continue
		for n in q.get("next", []):
			if not defs(g).get(n, {}).get("tutorial", false):
				after.append(n)
		if not is_done(g, qid):
			g.quests.active.erase(qid)
			g.quests.step.erase(qid)
			g.quests.count.erase(qid)
			g.quests.done.append(qid)
	g._emit("quest_skipped", {})
	for n in after:
		start(g, str(n))
	g.quests.tracked = tracked(g)


# ---------------------------------------------------------------- save

static func to_save(g) -> Dictionary:
	return g.quests.duplicate(true)


## Saves from before the quest system: the tutorial counts as done (the player knows the loop already).
static func from_save(g, d: Dictionary, has_key: bool) -> void:
	g.quests = empty_state()
	if not has_key:
		for qid in defs(g):
			if defs(g)[qid].get("tutorial", false):
				g.quests.done.append(qid)
		return
	for qid in d.get("done", []):
		if defs(g).has(str(qid)) and not is_done(g, str(qid)):
			g.quests.done.append(str(qid))
	for qid in d.get("active", []):
		var id := str(qid)
		if not defs(g).has(id) or is_done(g, id) or is_active(g, id):
			continue
		g.quests.active.append(id)
		g.quests.step[id] = clampi(int(d.get("step", {}).get(id, 0)), 0, maxi(steps(g, id).size() - 1, 0))
		g.quests.count[id] = float(d.get("count", {}).get(id, 0.0))
	g.quests.tracked = str(d.get("tracked", ""))
	g.quests.tracked = tracked(g)


# ---------------------------------------------------------------- waypoints

## Where to fly for target `t` while in space: the location itself in this system, else the gate on the way there.
static func space_goal(g, t: Dictionary) -> String:
	var loc := str(t.get("loc", ""))
	if loc == "" or not g.data.locations.has(loc):
		return ""
	var sys: String = g.loc_system(loc)
	if sys == g.system:
		return loc
	var rt: Array = Galaxy.route(g, g.system, sys)
	if rt.size() < 2:
		return ""
	var gs: Array = Galaxy.gates(g, g.system, str(rt[1]))
	return str(gs[0]) if not gs.is_empty() else ""
