extends RefCounted
## Heat II + corruption (Phase 2 F1). Pure functions on a Game, no scene deps; numbers in content.json "corruption".
##
## Heat is kept per star system: `g.heat` is always the heat of the system the ship is in, the heat of the other
## systems waits in `g.corruption.heat` and swaps in on a jump (so every existing heat rule keeps working).
## On top sits a personal `wanted` level (0..100): busts raise it, it decays per day and adds to the heat that
## patrols and officers on foot react to (`heat_bonus`), in every system.
## Corrupt officials (content.json "officials", profiles via People) are recruited with a bribe and then paid a
## daily retainer. By role:
##   inspector  cooks the file: `bribe` (clear heat) at a discount, `clear_wanted`
##   customs    `scan_pass`: a patrol scan or frisk in their system may find nothing
##   captain    tip-off the day before an Authority sweep (a day of extra patrols when a system runs hot),
##              `divert_sweep` cancels it
## Without a hired inspector there is no way to buy heat down any more (the old office fixer is gone).

const People = preload("res://scripts/core/people.gd")


static func rules(g) -> Dictionary:
	return g.data.get("corruption", {})


static func init_state(_data: Dictionary) -> Dictionary:
	return {"wanted": 0.0, "heat": {}, "officials": {}, "pending": {}, "sweep": {}, "roll": 12345}


## Saved state merged over fresh defaults (old saves have none).
static func from_save(data: Dictionary, saved: Dictionary) -> Dictionary:
	var r := init_state(data)
	r.wanted = clampf(float(saved.get("wanted", 0.0)), 0.0, float(data.get("corruption", {}).get("wanted_max", 100)))
	var known_systems: Dictionary = data.get("systems", {})
	for s in saved.get("heat", {}):
		if known_systems.has(s):
			r.heat[s] = float(saved.heat[s])
	var ids := {}
	for o in data.get("officials", []):
		ids[o.id] = true
	for id in saved.get("officials", {}):
		if ids.has(id):
			var s: Dictionary = saved.officials[id]
			r.officials[id] = {"known": bool(s.get("known", false)), "hired": bool(s.get("hired", false)),
				"loyalty": clampf(float(s.get("loyalty", 0.0)), 0.0, 1.0), "favours": int(s.get("favours", 0)), "passes": int(s.get("passes", 0))}
	for k in ["pending", "sweep"]:
		var p: Dictionary = saved.get(k, {})
		if p.has("system") and known_systems.has(p.system):
			r[k] = {"system": str(p.system), "day": int(p.get("day", 0))}
	r.roll = int(saved.get("roll", r.roll))
	return r


static func to_save(g) -> Dictionary:
	var c: Dictionary = g.corruption.duplicate(true)
	c.wanted = snappedf(float(c.wanted), 0.01)
	return c


# ---------------------------------------------------------------- numbers

static func wanted(g) -> float:
	return float(g.corruption.wanted)


## 0..5 stars for display.
static func wanted_stars(g) -> int:
	return clampi(int(ceil(wanted(g) / 20.0)), 0, 5)


## Extra "heat" patrols and officers react to: the wanted level and an active sweep in the current system.
static func heat_bonus(g) -> float:
	var r := rules(g)
	var b := wanted(g) * float(r.get("wanted_heat_factor", 0.0))
	var sw: Dictionary = g.corruption.sweep
	if not sw.is_empty() and sw.system == g.system and int(sw.day) == g.day:
		b += float(r.get("crackdown_heat_bonus", 0.0))
	return b


static func system_heat(g, sys: String) -> float:
	return g.heat if sys == g.system else float(g.corruption.heat.get(sys, 0.0))


## The hired official of `role` in system `sys`, or {} (best loyalty first).
static func hired(g, role: String, sys: String = "") -> Dictionary:
	if sys == "":
		sys = g.system
	var best := {}
	var best_l := -1.0
	for o in People.officials_in(g, sys):
		var s := People.official_state(g, o.id)
		if o.role == role and s.hired and float(s.loyalty) > best_l:
			best = o
			best_l = float(s.loyalty)
	return best


static func loyalty_label(l: float) -> String:
	if l >= 0.75:
		return "Devoted"
	if l >= 0.45:
		return "Reliable"
	if l >= 0.2:
		return "Nervous"
	return "Wavering"


## Chance one patrol scan / frisk finds nothing, from the hired customs officer of the current system.
static func pass_chance(g) -> float:
	var o := hired(g, "customs")
	if o.is_empty():
		return 0.0
	var r := rules(g)
	var p := float(o.get("pass_chance", 0.5)) * (0.6 + 0.4 * float(People.official_state(g, o.id).loyalty))
	if wanted(g) >= 50.0:
		p *= float(r.get("pass_wanted_penalty", 1.0))
	return minf(p, float(r.get("pass_cap", 0.9)))


static func fix_rate(g) -> float:
	return float(g.data.heat.bribe_credits_per_heat) * (1.0 - float(rules(g).get("fix_discount", 0.0)))


static func bribe_cost(g, heat_amount: float) -> int:
	return int(ceil(minf(heat_amount, g.heat) * fix_rate(g)))


static func wanted_cost(g, amount: float) -> int:
	return int(ceil(minf(amount, wanted(g)) * float(rules(g).get("wanted_clear_credits", 0))))


## Deterministic 0..1 roll that does not touch the game's main RNG (so runs without corruption stay identical).
static func _roll(g) -> float:
	var x: int = (int(g.corruption.roll) * 1103515245 + 12345) & 0x7fffffff
	g.corruption.roll = x
	return float((x >> 8) % 10000) / 10000.0


static func _notice(g, text: String, good: bool = true) -> void:
	g._emit("notice", {"text": text, "good": good})


# ---------------------------------------------------------------- hooks called by Game

static func tick(g, dt: float) -> void:
	var other: Dictionary = g.corruption.heat
	if other.is_empty():
		return
	var decay := float(g.data.heat.decay_per_second) * dt
	for s in other.keys():
		other[s] = maxf(float(other[s]) - decay, 0.0)


## Called by Game.jump right after the system changed: the heat of the old system is parked, the new one swaps in.
static func on_jump(g, from_sys: String, to_sys: String) -> void:
	if from_sys == to_sys:
		return
	g.corruption.heat[from_sys] = g.heat
	g.heat = float(g.corruption.heat.get(to_sys, 0.0))
	g.corruption.heat.erase(to_sys)


## Docking somewhere introduces you to the officials who work there.
static func on_dock(g, loc: String) -> void:
	for o in g.data.get("officials", []):
		if o.location == loc:
			var s := People.official_state(g, o.id)
			if not s.known:
				s.known = true
				g._emit("met_official", {"official": o.id})


static func on_bust(g) -> void:
	g.corruption.wanted = minf(wanted(g) + float(rules(g).get("wanted_per_bust", 0.0)), float(rules(g).get("wanted_max", 100)))


## Rolled at the start of a patrol scan/frisk bust: a hired customs officer may wave the cargo through.
static func scan_pass(g) -> bool:
	var p := pass_chance(g)
	if p <= 0.0 or _roll(g) >= p:
		return false
	var o := hired(g, "customs")
	var s := People.official_state(g, o.id)
	s.passes = int(s.passes) + 1
	g._emit("scan_passed", {"official": o.id})
	_notice(g, "%s waves your cargo through." % o.name)
	return true


static func new_day(g) -> void:
	var r := rules(g)
	# an announced sweep starts today; an old one ends
	var pend: Dictionary = g.corruption.pending
	if not pend.is_empty() and int(pend.day) <= g.day:
		g.corruption.sweep = pend
		g.corruption.pending = {}
		_notice(g, "Authority sweep in %s today: expect extra patrols." % g.data.systems[pend.system].name, false)
	elif not g.corruption.sweep.is_empty() and int(g.corruption.sweep.day) < g.day:
		g.corruption.sweep = {}
	g.corruption.wanted = maxf(wanted(g) - float(r.get("wanted_decay_per_day", 0.0)), 0.0)
	_pay_retainers(g)
	_plan_sweep(g)


static func _pay_retainers(g) -> void:
	for o in g.data.get("officials", []):
		var s := People.official_state(g, o.id)
		if not s.hired:
			continue
		var fee := int(o.retainer)
		if g.credits >= fee:
			g.credits -= fee
			s.loyalty = minf(float(s.loyalty) + float(rules(g).get("loyalty_per_day", 0.0)), 1.0)
		else:
			s.loyalty = float(s.loyalty) + float(rules(g).get("loyalty_unpaid", 0.0))
			if float(s.loyalty) <= 0.0:
				s.hired = false
				s.loyalty = 0.0
				_notice(g, "%s stops taking your calls: the retainer went unpaid." % o.name, false)
			else:
				_notice(g, "%s is annoyed: you missed the retainer (%d cr)." % [o.name, fee], false)


## A system running hot may get a sweep tomorrow. A hired captain there tells you today.
static func _plan_sweep(g) -> void:
	var r := rules(g)
	if not g.corruption.pending.is_empty():
		return
	for sys in g.data.systems:
		if system_heat(g, sys) < float(r.get("crackdown_heat", 999)):
			continue
		if _roll(g) >= float(r.get("crackdown_chance", 0.0)):
			continue
		g.corruption.pending = {"system": sys, "day": g.day + 1}
		var cap := hired(g, "captain", sys)
		if not cap.is_empty():
			g._emit("tip_off", {"official": cap.id, "system": sys})
			_notice(g, "%s: the Authority sweeps %s tomorrow. Lie low or pay me to divert it." % [cap.name, g.data.systems[sys].name])
		return


# ---------------------------------------------------------------- actions

static func recruit(g, id: String) -> Dictionary:
	var o := People.official(g, id)
	if o.is_empty():
		return g._fail("Nobody by that name.")
	var s := People.official_state(g, id)
	if s.hired:
		return g._fail("%s already works for you." % o.name)
	if g.location != o.location:
		return g._fail("Meet %s in person at %s first." % [o.name, g.data.locations[o.location].name])
	var cost := int(o.recruit_cost)
	if cost > g.credits:
		return g._fail("%s wants %d cr to look the other way." % [o.name, cost])
	g.credits -= cost
	s.known = true
	s.hired = true
	s.loyalty = float(rules(g).get("loyalty_start", 0.5))
	g._emit("recruited", {"official": id, "cost": cost})
	return g._ok("%s is on your payroll (%d cr, then %d cr/day)." % [o.name, cost, int(o.retainer)])


## Buys `heat_amount` of heat in the current system off the books (needs a hired inspector there).
static func bribe(g, heat_amount: float) -> Dictionary:
	var o := hired(g, "inspector")
	if o.is_empty():
		return g._fail("You need an inspector on the payroll in this system.")
	var cost := bribe_cost(g, heat_amount)
	if cost <= 0:
		return g._fail("No heat to clear.")
	if cost > g.credits:
		return g._fail("Not enough credits.")
	g.credits -= cost
	g._set_heat(g.heat - minf(heat_amount, g.heat))
	_favour(g, o)
	g._emit("bribed", {"cost": cost})
	return g._ok("Paid %d cr. %s lost some files, heat cooled down." % [cost, o.name])


static func clear_wanted(g, amount: float) -> Dictionary:
	var o := hired(g, "inspector")
	if o.is_empty():
		return g._fail("You need an inspector on the payroll in this system.")
	var cost := wanted_cost(g, amount)
	if cost <= 0:
		return g._fail("You are not wanted.")
	if cost > g.credits:
		return g._fail("Not enough credits.")
	g.credits -= cost
	g.corruption.wanted = wanted(g) - minf(amount, wanted(g))
	_favour(g, o)
	return g._ok("Paid %d cr. %s scrubbed your name from the wanted list." % [cost, o.name])


static func divert_cost(g) -> int:
	return int(rules(g).get("divert_cost", 0))


## A hired captain cancels the announced sweep (only while it is still tomorrow's news).
static func divert_sweep(g) -> Dictionary:
	var pend: Dictionary = g.corruption.pending
	var cap := hired(g, "captain", pend.get("system", g.system))
	if cap.is_empty():
		return g._fail("No captain on the payroll covers that system.")
	if pend.is_empty():
		return g._fail("No sweep announced.")
	var cost := divert_cost(g)
	if cost > g.credits:
		return g._fail("Not enough credits.")
	g.credits -= cost
	g.corruption.pending = {}
	_favour(g, cap)
	return g._ok("Paid %d cr. %s sends the patrols elsewhere." % [cost, cap.name])


static func _favour(g, o: Dictionary) -> void:
	var s := People.official_state(g, o.id)
	s.favours = int(s.favours) + 1
	s.loyalty = minf(float(s.loyalty) + float(rules(g).get("loyalty_per_favour", 0.0)), 1.0)
