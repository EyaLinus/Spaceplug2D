extends RefCounted
## Estate raids (P4). Pure functions on a Game, numbers in content.json "raids", state in Game.raids (saved).
##
## A system whose heat stays at or above `heat` for `days` consecutive days can get an estate raided at the day
## change. The chance grows with the heat and is cut by a hired patrol captain in that system (F1 tip-off network).
## A raid is announced one day ahead (event "raid_warning" + notice toast): empty the estate stash and the tray
## before the next day change. The raid ("raided") seizes `seize` of the estate stock and the tray, fines you,
## drops the system heat (the Authority got its trophy) and raises the wanted level. Own LCG, so the game RNG and
## the balance sim are untouched. The ship's cargo bay is never raided.

const Corruption = preload("res://scripts/core/corruption.gd")


static func rules(g) -> Dictionary:
	return g.data.get("raids", {})


static func init_state() -> Dictionary:
	return {"streak": {}, "warn": {}, "roll": 4242, "count": 0}


static func from_save(g, d: Dictionary) -> void:
	var r := init_state()
	for s in d.get("streak", {}):
		if g.data.systems.has(s):
			r.streak[s] = maxi(int(d.streak[s]), 0)
	var w: Dictionary = d.get("warn", {})
	if g.estates.has(str(w.get("estate", ""))) and not g.data.estates[w.estate].get("ship", false):
		r.warn = {"estate": str(w.estate), "day": int(w.get("day", g.day + 1))}
	r.roll = int(d.get("roll", r.roll))
	r.count = int(d.get("count", 0))
	g.raids = r


static func to_save(g) -> Dictionary:
	return g.raids.duplicate(true)


## Deterministic 0..1 roll on its own state.
static func _roll(g) -> float:
	var x: int = (int(g.raids.roll) * 1103515245 + 12345) & 0x7fffffff
	g.raids.roll = x
	return float((x >> 8) % 10000) / 10000.0


static func _notice(g, text: String, good: bool = false) -> void:
	g._emit("notice", {"text": text, "good": good})


static func estate_system(g, eid: String) -> String:
	return g.loc_system(str(g.data.estates[eid].get("location", "")))


## Raid chance for one night in `sys` (0 below the streak requirement).
static func chance(g, sys: String) -> float:
	var r := rules(g)
	var h := Corruption.system_heat(g, sys)
	if h < float(r.get("heat", 999)) or int(g.raids.streak.get(sys, 0)) < int(r.get("days", 99)):
		return 0.0
	var c := float(r.get("chance_base", 0.0)) + (h - float(r.heat)) * float(r.get("chance_per_heat", 0.0))
	if not Corruption.hired(g, "captain", sys).is_empty():
		c *= 1.0 - float(r.get("tipoff_cut", 0.0))
	return clampf(c, 0.0, float(r.get("chance_max", 1.0)))


## Warning for this estate ({} when none): {"estate", "day"}.
static func warning_for(g, eid: String) -> Dictionary:
	return g.raids.warn if str(g.raids.warn.get("estate", "")) == eid else {}


## One line for the estate screen, "" when there is nothing to worry about.
static func status_text(g, eid: String) -> String:
	if not g.data.estates.has(eid) or g.data.estates[eid].get("ship", false):
		return ""
	if not warning_for(g, eid).is_empty():
		return "RAID WARNING: the Authority hits this place at the next day change. Empty the stash and the tray."
	var sys := estate_system(g, eid)
	var n := int(g.raids.streak.get(sys, 0))
	if n > 0:
		return "Heat here has been high for %d day(s): a raid is possible after %d." % [n, int(rules(g).get("days", 0))]
	return ""


## Estates in `sys` that a raid can hit.
static func _targets(g, sys: String) -> Array:
	var out: Array = []
	var ids: Array = g.estates.keys()
	ids.sort()
	for eid in ids:
		if g.data.estates.has(eid) and not g.data.estates[eid].get("ship", false) and estate_system(g, eid) == sys:
			out.append(eid)
	return out


# ---------------------------------------------------------------- hook called by Game._new_day

static func new_day(g) -> void:
	var r := rules(g)
	if r.is_empty():
		return
	# yesterday's warning comes due
	var w: Dictionary = g.raids.warn
	if not w.is_empty() and int(w.day) <= g.day:
		g.raids.warn = {}
		var sys := estate_system(g, w.estate)
		if g.estates.has(w.estate) and Corruption.system_heat(g, sys) >= float(r.get("call_off_heat", 0)):
			_raid(g, w.estate)
		else:
			_notice(g, "The raid on %s was called off: things cooled down." % g.data.estates[w.estate].name, true)
	# streaks of hot days per system
	for sys in g.data.systems:
		if Corruption.system_heat(g, sys) >= float(r.get("heat", 999)):
			g.raids.streak[sys] = int(g.raids.streak.get(sys, 0)) + 1
		else:
			g.raids.streak.erase(sys)
	if not g.raids.warn.is_empty():
		return
	for sys in g.data.systems:
		var c := chance(g, sys)
		if c <= 0.0 or _roll(g) >= c:
			continue
		var t := _targets(g, sys)
		if t.is_empty():
			continue
		var eid: String = t[int(_roll(g) * t.size()) % t.size()]
		g.raids.warn = {"estate": eid, "day": g.day + 1}
		var cap := Corruption.hired(g, "captain", sys)
		var who := ("%s: " % cap.name) if not cap.is_empty() else ""
		if not cap.is_empty():
			g._emit("tip_off", {"official": cap.id, "system": sys})
		g._emit("raid_warning", {"estate": eid, "system": sys, "day": g.day + 1})
		_notice(g, "%sThe Authority raids %s tomorrow. Clear out the stash and the tray." % [who, g.data.estates[eid].name])
		return


static func _raid(g, eid: String) -> void:
	var r := rules(g)
	var sys := estate_system(g, eid)
	var lost := 0
	var bag: Dictionary = g.estate_stock.get(eid, {})
	for k in bag.keys():
		var n := mini(int(ceil(float(bag[k]) * float(r.get("seize", 0.5)))), int(bag[k]))
		lost += n
		g._add(bag, k, -n)
	if bag.is_empty():
		g.estate_stock.erase(eid)
	var t: Dictionary = g.bench.get(eid, {})
	if not t.is_empty():
		var n := mini(int(ceil(float(t.qty) * float(r.get("seize", 0.5)))), int(t.qty))
		lost += n
		t.qty = int(t.qty) - n
		if int(t.qty) <= 0:
			g.bench.erase(eid)
	var fine := 0
	if lost > 0:
		fine = mini(int(r.get("fine", 0)), g.credits)
		g.credits -= fine
	# the Authority got its trophy: heat drops, and a haul raises the wanted level
	var drop := float(r.get("heat_drop", 0.0)) if lost > 0 else float(r.get("heat_drop_empty", 0.0))
	if sys == g.system:
		g.add_heat(-drop)
	elif g.corruption.heat.has(sys):
		g.corruption.heat[sys] = maxf(float(g.corruption.heat[sys]) - drop, 0.0)
	if lost > 0:
		g.corruption.wanted = minf(Corruption.wanted(g) + float(r.get("wanted", 0.0)), float(g.data.corruption.wanted_max))
	g.raids.streak.erase(sys)
	g.raids.count = int(g.raids.count) + 1
	g._emit("raided", {"estate": eid, "system": sys, "lost": lost, "fine": fine})
	var ename: String = g.data.estates[eid].name
	if lost > 0:
		_notice(g, "RAID on %s: %d units seized, fined %d cr." % [ename, lost, fine], false)
	else:
		_notice(g, "RAID on %s: the Authority found nothing." % ename, true)
