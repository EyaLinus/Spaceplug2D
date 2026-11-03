extends RefCounted
## Enemy cartels and sector influence (I1). Pure rules over a Game; numbers in content.json "cartels".
##
## Every trade location (one with demand) has influence shares: "you", one per cartel, and the rest is unclaimed
## street. Shares move with what happens there: your sales and your dealers' sales take ground, shot-down cartel
## ships and raided cartel bases (E4) take ground in their system, and every new day each cartel pushes back where it
## lives. Holding a location pays (better prices, fewer raiders in that system); losing it costs (robbed dealers).
## Taking ground from a cartel makes it hostile; hostility drives its fighter wings and interdictions (E4, D3).
##
## State: Game.cartels = {"influence": {loc: {actor: share}}, "gangs": {id: {hostility, weakened, kills, raids}},
## "owner": {loc: actor or ""}} (saved). Events: influence, turf_changed, dealer_robbed.

const YOU := "you"


static func rules(g) -> Dictionary:
	return g.data.get("cartels", {})


static func gangs(g) -> Dictionary:
	return rules(g).get("gangs", {})


static func gang(g, id: String) -> Dictionary:
	return gangs(g).get(id, {})


static func state(g, id: String) -> Dictionary:
	return g.cartels.gangs.get(id, {})


## Fresh state for a new game.
static func init_state(data: Dictionary) -> Dictionary:
	var cfg: Dictionary = data.get("cartels", {})
	var inf := {}
	for loc in data.locations:
		if (data.locations[loc].get("demand", {}) as Dictionary).is_empty():
			continue
		var row := {YOU: 0.0}
		for c in cfg.get("gangs", {}):
			row[c] = 0.0
		for a in cfg.get("start", {}).get(loc, {}):
			if row.has(a):
				row[a] = float(cfg.start[loc][a])
		inf[loc] = row
	var gs := {}
	for c in cfg.get("gangs", {}):
		gs[c] = {"hostility": float(cfg.gangs[c].get("hostility", 0.0)), "weakened": 0, "kills": 0, "raids": 0}
	var st := {"influence": inf, "gangs": gs, "owner": {}}
	for loc in inf:
		st.owner[loc] = _controller(inf[loc], float(cfg.get("control", 0.5)))
	return st


# ---------------------------------------------------------------- queries

## Trade locations (with influence) of a system, or all of them when `sys` is "".
static func places(g, sys := "") -> Array:
	var r: Array = []
	for loc in g.cartels.influence:
		if sys == "" or g.loc_system(loc) == sys:
			r.append(loc)
	return r


static func share(g, loc: String, actor: String = YOU) -> float:
	return float(g.cartels.influence.get(loc, {}).get(actor, 0.0))


## Unclaimed share of a location (nobody organised sells there).
static func free_share(g, loc: String) -> float:
	var t := 0.0
	for a in g.cartels.influence.get(loc, {}):
		t += float(g.cartels.influence[loc][a])
	return maxf(0.0, 1.0 - t)


## The strongest cartel at a location: {id, share}; id "" when no cartel is there.
static func top_cartel(g, loc: String) -> Dictionary:
	var best := ""
	var bs := 0.0
	for c in gangs(g):
		var s := share(g, loc, c)
		if s > bs:
			best = c
			bs = s
	return {"id": best, "share": bs}


## Who controls the location: an actor holding at least the "control" share, "" = contested.
static func owner(g, loc: String) -> String:
	return str(g.cartels.owner.get(loc, ""))


static func _controller(row: Dictionary, need: float) -> String:
	for a in row:
		if float(row[a]) >= need:
			return a
	return ""


## Average share of an actor over the trade locations of a system (0 when it has none).
static func system_share(g, sys: String, actor: String = YOU) -> float:
	var ps := places(g, sys)
	if ps.is_empty():
		return 0.0
	var t := 0.0
	for loc in ps:
		t += share(g, loc, actor)
	return t / ps.size()


## Cartels with ground in a system, strongest first: [{id, share}].
static func present(g, sys: String) -> Array:
	var r: Array = []
	for c in gangs(g):
		var s := system_share(g, sys, c)
		if s > 0.0 or str(gang(g, c).get("home", "")) == sys:
			r.append({"id": c, "share": s})
	r.sort_custom(func(a, b): return a.share > b.share)
	return r


## Price multiplier for selling at `loc`: your share against the strongest cartel's.
static func price_mult(g, loc: String) -> float:
	if not g.cartels.influence.has(loc):
		return 1.0
	var sw := float(rules(g).get("price_swing", 0.0))
	return 1.0 + clampf(share(g, loc) - float(top_cartel(g, loc).share), -1.0, 1.0) * sw


## Raider pressure multiplier for a system: high where you hold the streets, low... the other way round.
static func pressure_mult(g, sys: String) -> float:
	var r := rules(g)
	return lerpf(float(r.get("pressure_max", 1.0)), float(r.get("pressure_min", 1.0)), clampf(system_share(g, sys), 0.0, 1.0))


static func hostility(g, id: String) -> float:
	return float(state(g, id).get("hostility", 0.0))


## Hostility 0..100 as a word for the UI.
static func mood(g, id: String) -> String:
	var h := hostility(g, id)
	if h >= 75.0:
		return "at war"
	if h >= 50.0:
		return "hunting you"
	if h >= 25.0:
		return "hostile"
	if h >= 10.0:
		return "wary"
	return "ignoring you"


## True while a raided cartel is rebuilding (no pushing, no wings).
static func weakened(g, id: String) -> bool:
	return int(state(g, id).get("weakened", 0)) >= g.day


## Turf status of a location for the UI: {owner, label, colour}.
static func turf_label(g, loc: String) -> String:
	var o := owner(g, loc)
	if o == YOU:
		return "Your turf"
	if o != "":
		return "%s turf" % gang(g, o).get("name", o)
	return "Contested"


# ---------------------------------------------------------------- moving shares

## Moves `amount` of share at `loc` to `actor`, taken from everybody else (unclaimed street first, then the others in
## proportion to their share). Returns {actor_or_free: share taken}. Updates hostility and the turf owner.
static func gain(g, loc: String, actor: String, amount: float) -> Dictionary:
	var row: Dictionary = g.cartels.influence.get(loc, {})
	if row.is_empty() or amount <= 0.0 or not row.has(actor):
		return {}
	amount = minf(amount, 1.0 - float(row[actor]))
	var taken := {}
	var free := free_share(g, loc)
	var from_free := minf(free, amount * 0.5) if free > 0.0 else 0.0
	if from_free > 0.0:
		taken["free"] = from_free
	var rest := amount - from_free
	var others := 0.0
	for a in row:
		if a != actor:
			others += float(row[a])
	if rest > 0.0 and others <= 0.0:
		from_free = minf(free, amount)
		taken["free"] = from_free
		rest = 0.0
	if rest > 0.0:
		var k := minf(1.0, rest / others)
		for a in row:
			if a == actor:
				continue
			var t := float(row[a]) * k
			if t > 0.0:
				row[a] = float(row[a]) - t
				taken[a] = t
	var got := 0.0
	for a in taken:
		got += float(taken[a])
	row[actor] = clampf(float(row[actor]) + got, 0.0, 1.0)
	if actor == YOU:
		for a in taken:
			if gangs(g).has(a):
				_add_hostility(g, a, float(taken[a]) * float(rules(g).get("hostility_per_share", 0.0)))
	g._emit("influence", {"loc": loc, "actor": actor, "amount": got})
	_update_owner(g, loc)
	return taken


## Spreads a gain over every trade location of a system (a kill or a raid there).
static func gain_system(g, sys: String, actor: String, amount: float) -> void:
	for loc in places(g, sys):
		gain(g, loc, actor, amount)


static func _add_hostility(g, id: String, v: float) -> void:
	var s: Dictionary = state(g, id)
	if s.is_empty():
		return
	s.hostility = clampf(float(s.hostility) + v, 0.0, 100.0)


static func _update_owner(g, loc: String) -> void:
	var was := owner(g, loc)
	var now := _controller(g.cartels.influence[loc], float(rules(g).get("control", 0.5)))
	if now == was:
		return
	g.cartels.owner[loc] = now
	g._emit("turf_changed", {"loc": loc, "by": now, "was": was})


# ---------------------------------------------------------------- hooks from the game

## Reacts to game events (called from Game._emit): sales take ground.
static func on_event(g, kind: String, p: Dictionary) -> void:
	if g.cartels.is_empty():
		return
	match kind:
		"sold":
			if g.location != "":
				gain(g, g.location, YOU, float(rules(g).get("sale_per_unit", 0.0)) * int(p.get("qty", 0)))
		"dealer_sold":
			for d in g.dealers:
				if d.id == p.get("dealer", "") and str(d.loc) != "":
					gain(g, d.loc, YOU, float(rules(g).get("dealer_sale_per_unit", 0.0)) * int(p.get("qty", 0)))


## A cartel ship of `id` went down in the current system: ground, hostility and the kill count.
static func on_kill(g, id: String) -> void:
	var s := state(g, id)
	if s.is_empty():
		return
	s.kills = int(s.kills) + 1
	_add_hostility(g, id, float(rules(g).get("hostility_per_kill", 0.0)))
	for loc in places(g, g.system):
		var t := share(g, loc, id)
		if t > 0.0:
			_take_from(g, loc, id, minf(t, float(rules(g).get("kill", 0.0))))


## Moves up to `amount` from cartel `id` to you at `loc` (a direct hit on that cartel).
static func _take_from(g, loc: String, id: String, amount: float) -> void:
	var row: Dictionary = g.cartels.influence[loc]
	var t := minf(float(row.get(id, 0.0)), amount)
	if t <= 0.0:
		return
	row[id] = float(row[id]) - t
	row[YOU] = minf(1.0, float(row[YOU]) + t)
	g._emit("influence", {"loc": loc, "actor": YOU, "amount": t})
	_update_owner(g, loc)


## A cartel base was destroyed (E4): big swing in its system, the cartel rebuilds for a few days.
static func on_raid(g, id: String) -> void:
	var s := state(g, id)
	if s.is_empty():
		return
	s.raids = int(s.raids) + 1
	s.weakened = g.day + int(rules(g).get("weakened_days", 3))
	_add_hostility(g, id, float(rules(g).get("hostility_per_raid", 0.0)))
	var sys: String = g.loc_system(str(gang(g, id).get("base", ""))) if g.data.locations.has(str(gang(g, id).get("base", ""))) else ""
	if sys == "":
		sys = str(gang(g, id).get("home", g.system))
	for loc in places(g, sys):
		_take_from(g, loc, id, float(rules(g).get("raid", 0.0)))


## Daily turn: cartels push back, your unattended ground erodes a little, hostility cools, dealers on cartel turf
## get robbed.
static func new_day(g) -> void:
	if g.cartels.is_empty():
		return
	var r := rules(g)
	var cap := float(r.get("push_cap", 1.0))
	for c in gangs(g):
		var s := state(g, c)
		s.hostility = maxf(0.0, float(s.hostility) - float(r.get("hostility_decay", 0.0)))
		if weakened(g, c):
			continue
		var home := str(gang(g, c).get("home", ""))
		for loc in places(g):
			var cur := share(g, loc, c)
			var push := float(r.get("push_home", 0.0)) if g.loc_system(loc) == home else (float(r.get("push_away", 0.0)) if cur > 0.0 else 0.0)
			if push > 0.0 and cur < cap:
				gain(g, loc, c, minf(push, cap - cur))
	var decay := float(r.get("you_decay", 0.0))
	for loc in places(g):
		var row: Dictionary = g.cartels.influence[loc]
		if float(row[YOU]) > 0.0 and decay > 0.0 and not _has_dealer(g, loc):
			row[YOU] = maxf(0.0, float(row[YOU]) - decay)
			_update_owner(g, loc)
	_rob_dealers(g)


static func _has_dealer(g, loc: String) -> bool:
	for d in g.dealers:
		if str(d.loc) == loc and float(d.get("jail", 0.0)) <= 0.0:
			return true
	return false


## Chance per day that the dealer at `loc` is robbed: only on cartel turf, scaled by how far ahead the cartel is.
static func rob_chance(g, loc: String) -> float:
	var r := rules(g)
	var top := top_cartel(g, loc)
	var you := share(g, loc)
	if top.id == "" or float(top.share) < float(r.get("turf", 0.35)) or you >= float(top.share):
		return 0.0
	return clampf(float(r.get("rob_chance", 0.0)) * (float(top.share) - you), 0.0, 1.0)


static func _rob_dealers(g) -> void:
	var r := rules(g)
	for d in g.dealers:
		if str(d.loc) == "" or float(d.get("jail", 0.0)) > 0.0:
			continue
		var chance := rob_chance(g, d.loc)
		if chance <= 0.0 or g.rng.randf() >= chance:
			continue
		var cash := int(round(int(d.cash) * float(r.get("rob_cash", 0.5))))
		d.cash = int(d.cash) - cash
		var units := 0
		for k in d.stock.keys():
			var n := int(ceil(int(d.stock[k]) * float(r.get("rob_stock", 0.3))))
			if n > 0:
				g._add(d.stock, k, -n)
				units += n
		g._emit("dealer_robbed", {"dealer": d.id, "loc": d.loc, "cartel": top_cartel(g, d.loc).id, "credits": cash, "units": units})


# ---------------------------------------------------------------- save

static func to_save(g) -> Dictionary:
	var inf := {}
	for loc in g.cartels.influence:
		inf[loc] = {}
		for a in g.cartels.influence[loc]:
			inf[loc][a] = snappedf(float(g.cartels.influence[loc][a]), 0.0001)
	return {"influence": inf, "gangs": g.cartels.gangs.duplicate(true)}


## Old saves have no cartels: they start from the content defaults.
static func from_save(g, d: Dictionary) -> void:
	g.cartels = init_state(g.data)
	for loc in d.get("influence", {}):
		if not g.cartels.influence.has(loc):
			continue
		var row: Dictionary = g.cartels.influence[loc]
		var total := 0.0
		for a in d.influence[loc]:
			if row.has(a):
				row[a] = clampf(float(d.influence[loc][a]), 0.0, 1.0)
				total += float(row[a])
		if total > 1.0:
			for a in row:
				row[a] = float(row[a]) / total
	for c in d.get("gangs", {}):
		if g.cartels.gangs.has(c):
			var s: Dictionary = g.cartels.gangs[c]
			var o: Dictionary = d.gangs[c]
			s.hostility = clampf(float(o.get("hostility", s.hostility)), 0.0, 100.0)
			s.weakened = int(o.get("weakened", 0))
			s.kills = int(o.get("kills", 0))
			s.raids = int(o.get("raids", 0))
	for loc in g.cartels.influence:
		g.cartels.owner[loc] = _controller(g.cartels.influence[loc], float(rules(g).get("control", 0.5)))
