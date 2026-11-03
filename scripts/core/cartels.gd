extends RefCounted
## Enemy cartels and sector influence (I1). Three rival cartels (content.json "cartels": home location, colour, boss,
## starting presence) and, for every trading location (one with demand), an influence share split between you, each
## cartel and "none" (nobody in particular). Shares always add up to 1.
## State: Game.influence {location: {"you", "none", cartel id: share}} (saved).
##
## Your share moves with what you do there: sales (yours and your dealers'), dead drops that arrive or get stolen,
## raiders shot down (Black Comets lose ground in the system), a wreck or a knock-out (you lose ground). Every day
## your lead above `neutral` bleeds back to the strongest local rival, and a cartel never drops below `home_floor`
## in its home district.
## Effects: high share = better sell prices, cheaper raws and fewer pirates; share below `tier_low` = your dealers get
## robbed and drops are stolen more often. At the start every location sits at `neutral`, so nothing changes until
## you play. Rules and numbers: content.json "cartels".

const YOU := "you"
const NONE := "none"


static func cfg(g) -> Dictionary:
	return g.data.get("cartels", {})


static func list(g) -> Array:
	return cfg(g).get("list", [])


static func find(g, id: String) -> Dictionary:
	for c in list(g):
		if c.id == id:
			return c
	return {}


static func color(g, who: String) -> Color:
	if who == YOU:
		return Color("#4fe3c1")
	if who == NONE:
		return Color("#5a6080")
	return Color(str(find(g, who).get("color", "#ffffff")))


static func who_name(g, who: String) -> String:
	if who == YOU:
		return "You"
	if who == NONE:
		return "Nobody"
	if find(g, who).is_empty():
		return "A cartel crew"
	return str(find(g, who).get("short", who))


## Locations with influence: everywhere people buy drugs.
static func tracked(g) -> Array:
	var r: Array = []
	for loc in g.data.locations:
		if not g.data.locations[loc].get("demand", {}).is_empty():
			r.append(loc)
	return r


static func holders(g) -> Array:
	var r: Array = [YOU, NONE]
	for c in list(g):
		r.append(c.id)
	return r


## Fresh state: you at `neutral` everywhere, the cartels at their presence, the rest nobody's.
static func init_state(g) -> Dictionary:
	var out := {}
	for loc in tracked(g):
		var row := {YOU: float(cfg(g).get("neutral", 0.15))}
		var used: float = row[YOU]
		for c in list(g):
			var v := float(c.get("presence", {}).get(loc, 0.0))
			row[c.id] = v
			used += v
		row[NONE] = maxf(0.0, 1.0 - used)
		out[loc] = row
	return out  # built to add up to 1; not normalised so the neutral share stays exact


static func _normalise(g, row: Dictionary) -> void:
	var sum := 0.0
	for k in holders(g):
		row[k] = maxf(0.0, float(row.get(k, 0.0)))
		sum += float(row[k])
	if sum <= 0.0:
		row[NONE] = 1.0
		return
	for k in holders(g):
		row[k] = float(row[k]) / sum


# ---------------------------------------------------------------- queries

static func share(g, loc: String, who: String = YOU) -> float:
	return float(g.influence.get(loc, {}).get(who, 0.0))


## The cartel with the biggest share at `loc` ("" when no cartel has any).
static func top_rival(g, loc: String) -> String:
	var best := ""
	var bv := 0.0
	for c in list(g):
		var v := share(g, loc, c.id)
		if v > bv:
			best = c.id
			bv = v
	return best


## Who holds the most at `loc`: you, a cartel id, or NONE.
static func leader(g, loc: String) -> String:
	var best := NONE
	var bv := -1.0
	for k in holders(g):
		var v := share(g, loc, k)
		if v > bv + 0.0001:
			best = k
			bv = v
	return best


## "high" (respected), "mid" or "low" (they know you are weak here).
static func tier(g, loc: String) -> String:
	if not g.influence.has(loc):
		return "mid"
	var v := share(g, loc)
	if v >= float(cfg(g).get("tier_high", 0.4)):
		return "high"
	if v < float(cfg(g).get("tier_low", 0.08)):
		return "low"
	return "mid"


## Average share of yours over the locations of a system.
static func system_share(g, sys: String, who: String = YOU) -> float:
	var n := 0
	var sum := 0.0
	for loc in tracked(g):
		if g.loc_system(loc) == sys:
			n += 1
			sum += share(g, loc, who)
	return sum / n if n > 0 else float(cfg(g).get("neutral", 0.15))


## The cartel with the biggest average share in a system ("" = none worth naming).
static func system_leader(g, sys: String) -> String:
	var best := ""
	var bv := 0.0
	for c in list(g):
		var v := system_share(g, sys, c.id)
		if v > bv:
			best = c.id
			bv = v
	return best


# ---------------------------------------------------------------- effects

## Sell price factor at `loc` (1.0 at the neutral share).
static func sell_mult(g, loc: String) -> float:
	if not g.influence.has(loc):
		return 1.0
	return 1.0 + float(cfg(g).get("sell_gain", 0.0)) * (share(g, loc) - float(cfg(g).get("neutral", 0.15)))


## Raw / additive price factor at `loc`.
static func buy_mult(g, loc: String) -> float:
	if not g.influence.has(loc):
		return 1.0
	return 1.0 - float(cfg(g).get("buy_gain", 0.0)) * (share(g, loc) - float(cfg(g).get("neutral", 0.15)))


## Pirate pressure factor for a system: below 1 where you are strong, above 1 where you are weak.
static func pirate_mult(g, sys: String) -> float:
	var c := cfg(g)
	var dev := float(c.get("neutral", 0.15)) - system_share(g, sys)
	if absf(dev) < 0.00001:
		return 1.0  # float noise from averaging must not move the old balance
	var m := 1.0 + float(c.get("pirate_gain", 0.0)) * dev
	return clampf(m, float(c.get("pirate_min", 0.6)), float(c.get("pirate_max", 1.5)))


## Extra chance that a dead drop at `loc` is cleaned out.
static func theft_bonus(g, loc: String) -> float:
	return float(cfg(g).get("rob_theft_bonus", 0.0)) if tier(g, loc) == "low" else 0.0


# ---------------------------------------------------------------- movement

## Moves up to `amt` of the share at `loc` from `from` to `to`. Returns what actually moved.
static func move(g, loc: String, from: String, to: String, amt: float) -> float:
	if not g.influence.has(loc) or from == to or amt <= 0.0:
		return 0.0
	var row: Dictionary = g.influence[loc]
	var floor_v := 0.0
	var cd := find(g, from)
	if not cd.is_empty() and str(cd.home) == loc:
		floor_v = float(cfg(g).get("home_floor", 0.0))
	var n := minf(amt, maxf(0.0, float(row.get(from, 0.0)) - floor_v))
	if n <= 0.0:
		return 0.0
	var before := tier(g, loc)
	row[from] = float(row[from]) - n
	row[to] = float(row.get(to, 0.0)) + n
	var after := tier(g, loc)
	if before != after:
		g._emit("influence_tier", {"loc": loc, "tier": after, "was": before, "share": share(g, loc)})
	return n


## You gain `amt` at `loc`, taken from the others in proportion to their share.
static func gain(g, loc: String, amt: float) -> void:
	if not g.influence.has(loc) or amt <= 0.0:
		return
	var row: Dictionary = g.influence[loc]
	var pool := 0.0
	for k in holders(g):
		if k != YOU:
			pool += float(row[k])
	if pool <= 0.0:
		return
	amt = minf(amt, pool)
	for k in holders(g):
		if k != YOU:
			move(g, loc, k, YOU, amt * float(row[k]) / pool)  # a home floor may refuse part of a cut


## You lose `amt` at `loc` to `to` (default: the strongest rival there, else nobody).
static func lose(g, loc: String, amt: float, to: String = "") -> void:
	if to == "":
		to = top_rival(g, loc)
		if to == "":
			to = NONE
	move(g, loc, YOU, to, amt)


# ---------------------------------------------------------------- events and the daily tick

static func on_event(g, kind: String, payload: Dictionary) -> void:
	if g.influence.is_empty():
		return
	var c := cfg(g)
	match kind:
		"sold":
			gain(g, g.location, int(payload.get("qty", 0)) * float(c.get("sale_per_unit", 0.0)))
		"dealer_sold":
			for d in g.dealers:
				if d.id == str(payload.get("dealer", "")):
					gain(g, str(d.loc), int(payload.get("qty", 0)) * float(c.get("dealer_sale_per_unit", 0.0)))
		"drop_pickup", "drop_stolen":
			var loc := ""
			for d in g.drops:
				if int(d.id) == int(payload.get("drop", -1)):
					loc = str(d.loc)
			if kind == "drop_pickup":
				gain(g, loc, float(c.get("drop_gain", 0.0)))
			else:
				lose(g, loc, float(c.get("drop_loss", 0.0)))
		"pirate_down":
			var pc := str(c.get("pirate_cartel", ""))
			for loc in tracked(g):
				if g.loc_system(loc) == g.system:
					move(g, loc, pc, YOU, float(c.get("raider_kill", 0.0)))
		"ship_destroyed":
			var pc2 := str(c.get("pirate_cartel", ""))
			for loc in tracked(g):
				if g.loc_system(loc) == g.system:
					lose(g, loc, float(c.get("wreck_loss", 0.0)), pc2)
		"knocked_out":
			lose(g, g.location, float(c.get("knockout_loss", 0.0)))


## Once per game day: your lead bleeds back, weak spots invite robberies.
static func new_day(g) -> void:
	if g.influence.is_empty():
		return
	var c := cfg(g)
	for loc in tracked(g):
		var over := share(g, loc) - float(c.get("neutral", 0.15))
		if over > 0.0:
			lose(g, loc, minf(over, float(c.get("decay_per_day", 0.0))))
	for d in g.dealers:
		var loc2 := str(d.loc)
		if loc2 == "" or float(d.get("jail", 0.0)) > 0.0 or tier(g, loc2) != "low":
			continue
		if g.rng.randf() >= float(c.get("rob_chance", 0.0)):
			continue
		var cash := int(int(d.cash) * float(c.get("rob_cash", 0.5)))
		var lost := 0
		for k in d.stock.keys():
			var take := int(ceil(int(d.stock[k]) * float(c.get("rob_stock", 0.5))))
			g._add(d.stock, k, -take)
			lost += take
		d.cash = int(d.cash) - cash
		if cash > 0 or lost > 0:
			g._emit("robbed", {"dealer": d.id, "loc": loc2, "cartel": top_rival(g, loc2), "credits": cash, "units": lost})


# ---------------------------------------------------------------- save / load

static func to_save(g) -> Dictionary:
	var out := {}
	for loc in g.influence:
		var row := {}
		for k in g.influence[loc]:
			row[k] = snappedf(float(g.influence[loc][k]), 0.0001)
		out[loc] = row
	return out


## Old saves have no "influence": everything starts fresh. Unknown locations / cartels are dropped, rows re-normalised.
static func from_save(g, d) -> void:
	g.influence = init_state(g)
	if not d is Dictionary:
		return
	for loc in d:
		if not g.influence.has(loc) or not d[loc] is Dictionary:
			continue
		var row: Dictionary = g.influence[loc]
		for k in holders(g):
			if d[loc].has(k):
				row[k] = float(d[loc][k])
		_normalise(g, row)
