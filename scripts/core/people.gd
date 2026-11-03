extends RefCounted
## Named customers: static profile in data/content.json ("contacts": preferred drugs, liked trait, daily budget,
## schedule, starting addiction/affinity) plus per-run state on Game.people (id -> {addiction, affinity, spent,
## known, history}). Rules for numbers live in content.json "people". Pure functions on a Game, no scene deps.
##
## addiction 0..1: rises with every unit bought (stronger drugs faster), decays a little each day;
##   raises how many units and how many credits a person spends.
## affinity -1..1: rises with deals (more with their liked trait, preferred drug, good grades), drops with Shoddy
##   product; scales the price they pay.


static func initial_state(c: Dictionary) -> Dictionary:
	return {
		"addiction": float(c.get("addiction", 0.0)), "affinity": float(c.get("affinity", 0.0)),
		"spent": 0, "known": bool(c.get("known", true)), "history": [],
	}


static func init_all(data: Dictionary) -> Dictionary:
	var r := {}
	for c in data.contacts:
		r[c.id] = initial_state(c)
	return r


## Saved state merged over fresh defaults, so people added in a newer build appear in old saves.
static func from_save(data: Dictionary, saved: Dictionary) -> Dictionary:
	var r := init_all(data)
	for id in saved:
		if not r.has(id):
			continue
		var s: Dictionary = saved[id]
		r[id].addiction = clampf(float(s.get("addiction", r[id].addiction)), 0.0, 1.0)
		r[id].affinity = clampf(float(s.get("affinity", r[id].affinity)), -1.0, 1.0)
		r[id].spent = int(s.get("spent", 0))
		r[id].known = bool(s.get("known", r[id].known))
		r[id].history = (s.get("history", []) as Array).duplicate(true)
	return r


static func state(g, id: String) -> Dictionary:
	if not g.people.has(id):
		var c: Dictionary = g.contact(id)
		g.people[id] = initial_state(c)
	return g.people[id]


static func rules(g) -> Dictionary:
	return g.data.get("people", {})


# ---------------------------------------------------------------- derived numbers

## Credits this person can spend per day: base budget, more the more hooked they are.
static func daily_budget(g, id: String) -> int:
	var c: Dictionary = g.contact(id)
	var bonus := float(rules(g).get("addiction_budget_bonus", 0.0))
	return int(round(float(c.get("budget", 999999)) * (1.0 + bonus * float(state(g, id).addiction))))


static func budget_left(g, id: String) -> int:
	return maxi(daily_budget(g, id) - int(state(g, id).spent), 0)


## Units per deal: their usual amount plus up to `addiction_units_bonus` when fully hooked.
static func max_units(g, id: String) -> int:
	var c: Dictionary = g.contact(id)
	var bonus := float(rules(g).get("addiction_units_bonus", 0.0))
	return int(c.get("max_units", 1)) + int(floor(bonus * float(state(g, id).addiction)))


## Multiplier on the contact's price from affinity and their preferred drugs.
static func price_mult(g, id: String, base: String) -> float:
	var c: Dictionary = g.contact(id)
	var r := rules(g)
	var m := 1.0 + float(r.get("affinity_price_bonus", 0.0)) * float(state(g, id).affinity)
	if base in c.get("prefers", []):
		m *= 1.0 + float(r.get("preferred_bonus", 0.0))
	return m


## How many units of `product_key` the person takes right now (deal size and remaining budget), 0 if none.
static func units_wanted(g, id: String, product_key: String) -> int:
	var price: int = g.unit_price(product_key, id)
	if price <= 0:
		return 0
	return mini(max_units(g, id), budget_left(g, id) / price)


## Hour of the in-game day (0..24) from the day clock.
## A day starts at time.day_start_hour (06:00), so a new game begins in the morning.
static func hour(g) -> float:
	var start := float(g.data.get("time", {}).get("day_start_hour", 0.0))
	return fposmod(start + 24.0 * g.day_time / g.day_seconds(), 24.0)


## Where on its surface a person stands at `at_hour`: the surface's spot for the current schedule place (tile units),
## nudged by `slot` (the person's index on the surface) so people sharing a place stand side by side.
## [] when the surface has no spot for it.
static func spot(c: Dictionary, spots: Dictionary, at_hour: float, slot := 0) -> Array:
	var e := whereabouts(c, at_hour)
	if e.is_empty() or not spots.has(e.place):
		return []
	var p: Array = spots[e.place]
	var nudge := (float(posmod(slot, 4)) - 1.5) * 0.8
	var row := (float(posmod(slot / 4, 3)) - 1.0) * 0.45  # a crowd stands in rows, not on top of each other
	return [float(p[0]) + nudge, float(p[1]) + row]


## Day/night colour for `at_hour` from time.daylight keys [[hour, "#rrggbb"], ...], blended and wrapping at midnight.
static func daylight(data: Dictionary, at_hour: float) -> Color:
	var keys: Array = data.get("time", {}).get("daylight", [])
	if keys.is_empty():
		return Color.WHITE
	var prev_h := float(keys[-1][0]) - 24.0
	var prev_c := Color(keys[-1][1])
	var next_h := float(keys[0][0]) + 24.0
	var next_c := Color(keys[0][1])
	for k in keys:
		if float(k[0]) <= at_hour:
			prev_h = float(k[0])
			prev_c = Color(k[1])
		else:
			next_h = float(k[0])
			next_c = Color(k[1])
			break
	var span := next_h - prev_h
	return prev_c.lerp(next_c, 0.0 if span <= 0.0 else clampf((at_hour - prev_h) / span, 0.0, 1.0))


## The schedule entry for `at_hour` ({from, to, place}); entries may wrap past midnight (from 22 to 6).
static func whereabouts(c: Dictionary, at_hour: float) -> Dictionary:
	for e in c.get("schedule", []):
		var f := float(e.from)
		var t := float(e.to)
		if (f <= t and at_hour >= f and at_hour < t) or (f > t and (at_hour >= f or at_hour < t)):
			return e
	return {}


static func mood(affinity: float) -> String:
	if affinity >= 0.6:
		return "Loyal"
	if affinity >= 0.25:
		return "Friendly"
	if affinity > -0.25:
		return "Neutral"
	if affinity > -0.6:
		return "Wary"
	return "Hostile"


static func addiction_label(addiction: float) -> String:
	if addiction >= 0.75:
		return "Hooked"
	if addiction >= 0.45:
		return "Dependent"
	if addiction >= 0.2:
		return "Regular"
	return "Casual"


# ---------------------------------------------------------------- changes

static func meet(g, id: String) -> bool:
	var s := state(g, id)
	if s.known:
		return false
	s.known = true
	return true


## Applies a finished sale: spending, addiction, affinity and a history line.
static func record_deal(g, id: String, product_key: String, qty: int, credits: int, parts: Dictionary) -> void:
	var c: Dictionary = g.contact(id)
	var r := rules(g)
	var s := state(g, id)
	s.known = true
	s.spent = int(s.spent) + credits
	var addict := float(r.get("addictiveness", {}).get(parts.base, 0.0)) * qty
	s.addiction = clampf(float(s.addiction) + addict, 0.0, 1.0)
	var aff := float(r.get("affinity_per_deal", 0.0))
	if (parts.traits as Array).has(c.get("likes", "")):
		aff += float(r.get("affinity_liked_trait", 0.0))
	if parts.base in c.get("prefers", []):
		aff += float(r.get("affinity_preferred", 0.0))
	var by_grade: Array = r.get("affinity_grade", [])
	if int(parts.grade) < by_grade.size():
		aff += float(by_grade[int(parts.grade)])
	s.affinity = clampf(float(s.affinity) + aff, -1.0, 1.0)
	var h: Array = s.history
	h.push_front({"day": g.day, "product": product_key, "qty": qty, "credits": credits})
	while h.size() > int(r.get("history_len", 8)):
		h.pop_back()


static func new_day(g) -> void:
	var decay := float(rules(g).get("addiction_decay_per_day", 0.0))
	for id in g.people:
		var s: Dictionary = g.people[id]
		s.spent = 0
		s.addiction = maxf(float(s.addiction) - decay, 0.0)


# ---------------------------------------------------------------- officials (corrupt Authority staff, see corruption.gd)
## Officials are named people too: static profile in content.json "officials" (role, location, recruit cost, retainer),
## per-run state in g.corruption.officials (known, hired, loyalty, favours, passes). Rules live in corruption.gd.

static func official(g, id: String) -> Dictionary:
	for o in g.data.get("officials", []):
		if o.id == id:
			return o
	return {}


static func official_state(g, id: String) -> Dictionary:
	var all: Dictionary = g.corruption.officials
	if not all.has(id):
		all[id] = {"known": false, "hired": false, "loyalty": 0.0, "favours": 0, "passes": 0}
	return all[id]


## Official profiles standing in the given star system.
static func officials_in(g, sys: String) -> Array:
	var r: Array = []
	for o in g.data.get("officials", []):
		if g.loc_system(o.location) == sys:
			r.append(o)
	return r
