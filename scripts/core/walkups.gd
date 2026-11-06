extends RefCounted
## Customers on foot (P2): while you are on a planet's surface, people who want what you carry walk up to you.
## A walk-up is a short-lived request: a customer of this planet (known, or a stranger with a lower chance) who likes a
## drug you hold, the amount they would take and the price per unit (your asking price for the product, see products.gd).
## On the card you accept (the sale runs through Game.sell, so budget, cooldown, demand, heat, cartel and quest events all
## apply), haggle once for a higher price (chance as in deals.gd counter_chance) or turn them away.
## State: Game.walkups {active: {contact: walkup}, cool: {contact: total_time}, clock} (not saved: they are momentary).
## Rolls use their own seeded generator so they never disturb Game.rng. Numbers: content.json "walkups".
##
## walkup: {contact, base, product, qty, price (per unit), expires_at (total_time), haggled}

const Mixing = preload("res://scripts/core/mixing.gd")
const People = preload("res://scripts/core/people.gd")
const Deals = preload("res://scripts/core/deals.gd")
const Products = preload("res://scripts/core/products.gd")


static func rules(g) -> Dictionary:
	return g.data.get("walkups", {})


static func st(g) -> Dictionary:
	if not g.walkups.has("active"):
		g.walkups = {"active": {}, "cool": {}, "clock": 0.0}
	return g.walkups


static func active(g) -> Dictionary:
	return st(g).active


static func find(g, cid: String) -> Dictionary:
	return active(g).get(cid, {})


static func count(g) -> int:
	return active(g).size()


## What the customer holds out: the product of yours they would buy, the amount and the price per unit.
## {} when you carry nothing they want, the price is too steep for them or they cannot spend anything today.
static func offer_for(g, cid: String) -> Dictionary:
	var c: Dictionary = g.contact(cid)
	if c.is_empty() or g.location == "":
		return {}
	var prefers: Array = c.get("prefers", [])
	var best := ""
	var best_price := 0
	var best_liked := false
	for k in g.cargo:
		if int(g.cargo[k]) <= 0 or not Mixing.is_product(k):
			continue
		var p := Mixing.parse_key(k)
		if not (p.base in prefers) or not g.demand.get(g.location, {}).has(p.base):
			continue
		var unit: int = g.unit_price(k, cid)
		if unit <= 0:
			continue
		var liked: bool = (p.traits as Array).has(c.get("likes", ""))
		# they ask for what they like first, otherwise for the cheapest thing you carry (not your best stock)
		if best == "" or (liked and not best_liked) or (liked == best_liked and unit < best_price):
			best = k
			best_price = unit
			best_liked = liked
	if best == "":
		return {}
	var qty := mini(mini(People.max_units(g, cid), People.budget_left(g, cid) / best_price), int(g.cargo[best]))
	if qty <= 0:
		return {}
	return {"contact": cid, "base": Mixing.parse_key(best).base, "product": best, "qty": qty, "price": best_price, "haggled": false,
		"expires_at": g.total_time + float(rules(g).get("linger_seconds", 60.0))}


## Whether `cid` may walk up to you right now (ignoring the dice).
static func eligible(g, cid: String) -> bool:
	var s := st(g)
	if s.active.has(cid) or g.total_time < float(s.cool.get(cid, 0.0)) or not g.contact_ready(cid):
		return false
	if not Deals.open_for(g, cid).is_empty() or People.budget_left(g, cid) <= 0:
		return false
	return not offer_for(g, cid).is_empty()


## Chance per roll that an eligible customer comes over: hooked and friendly customers come more, strangers less.
static func chance(g, cid: String) -> float:
	var r := rules(g)
	var s: Dictionary = People.state(g, cid)
	var p := float(r.get("chance", 0.3)) * (0.4 + float(s.addiction) + maxf(float(s.affinity), 0.0))
	return clampf(p * (1.0 if s.known else float(r.get("stranger_mult", 0.5))), 0.0, 0.95)


# ---------------------------------------------------------------- simulation

## Called from Game.tick: on a planet surface every `interval` seconds a customer may walk up; the lingering ones leave.
static func tick(g, dt: float) -> void:
	var r := rules(g)
	if r.is_empty():
		return
	var s := st(g)
	for cid in s.active.keys():
		var w: Dictionary = s.active[cid]
		if g.location == "" or g.contact(cid).get("location", "") != g.location:
			_leave(g, cid, "gone", 0.0)
		elif g.total_time >= float(w.expires_at):
			_leave(g, cid, "bored", float(r.get("cooldown", 240.0)) * 0.5)
		elif int(g.cargo.get(w.product, 0)) <= 0:
			_leave(g, cid, "empty", 0.0)
	if g.location == "" or g.inside_estate != "":
		return
	s.clock = float(s.clock) + dt
	var interval := float(r.get("interval", 12.0))
	while s.clock >= interval:
		s.clock -= interval
		_roll(g)


static func _roll(g) -> void:
	var s := st(g)
	var r := rules(g)
	if s.active.size() >= int(r.get("max_active", 2)):
		return
	var here: Array = g.contacts_at()
	if here.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("walkup:%d:%d" % [g.day, int(g.total_time * 10.0)])
	var start := rng.randi() % here.size()  # start somewhere in the list so the first names don't always win
	for i in here.size():
		var cid: String = here[(start + i) % here.size()].id
		if eligible(g, cid) and rng.randf() < chance(g, cid):
			var w := offer_for(g, cid)
			s.active[cid] = w
			g._emit("walkup_new", {"contact": cid, "product": w.product, "qty": w.qty, "price": w.price})
			if s.active.size() >= int(r.get("max_active", 2)):
				return


static func _leave(g, cid: String, why: String, cool: float) -> void:
	var s := st(g)
	s.active.erase(cid)
	if cool > 0.0:
		s.cool[cid] = g.total_time + cool
	g._emit("walkup_left", {"contact": cid, "why": why})


# ---------------------------------------------------------------- your answers

## One line for the speech bubble above the customer's head.
static func bubble(g, w: Dictionary) -> String:
	return "%d × %s?  %d cr" % [int(w.qty), Mixing.display_name(g.data, str(w.product)), int(w.price)]


## Highest per-unit price this customer still pays for the walk-up's product.
static func ceiling(g, w: Dictionary) -> int:
	return Products.ceiling(g, str(w.product), str(w.contact), g.location)


## What the whole walk-up pays: every unit sold lowers local demand a little (as in Game.sell), plus the haggled part.
static func total(g, w: Dictionary) -> int:
	var key := str(w.product)
	var base: String = Mixing.parse_key(key).base
	var d: Dictionary = g.demand.get(g.location, {})
	if not d.has(base):
		return 0
	var first: int = g.unit_price(key, str(w.contact))
	var saved := float(d[base])
	var sum := 0
	for i in int(w.qty):
		sum += g.unit_price(key, str(w.contact))
		d[base] = maxf(float(d[base]) - float(g.data.market.saturation_per_unit), float(g.data.market.min_demand))
	d[base] = saved
	return sum + maxi(int(w.price) - first, 0) * int(w.qty)


## Sells the walk-up's goods through Game.sell (all the usual rules and events), plus whatever you haggled on top.
static func accept(g, cid: String) -> Dictionary:
	var w := find(g, cid)
	if w.is_empty():
		return g._fail("They walked off.")
	var qty := mini(int(w.qty), int(g.cargo.get(w.product, 0)))
	var unit: int = g.unit_price(str(w.product), cid)
	var before: int = g.credits
	var res: Dictionary = g.sell(str(w.product), qty, cid)
	_leave(g, cid, "sold" if res.ok else "refused", float(rules(g).get("cooldown", 240.0)) if res.ok else 0.0)
	if not res.ok:
		return res
	var extra := maxi(int(w.price) - unit, 0) * qty  # the haggled part on top of the normal sale
	if extra > 0:
		g.credits += extra
		g.stats.earned += extra
		People.state(g, cid).spent = int(People.state(g, cid).spent) + extra
	var got: int = g.credits - before
	g._emit("walkup_sold", {"contact": cid, "product": w.product, "qty": qty, "credits": got})
	return g._ok("Sold %d × %s to %s for %d cr." % [qty, g.item_name(str(w.product)), g.contact(cid).name, got])


## Asks for `raise` more per unit (0.1 = +10 %). One try; a refusal keeps the price and annoys them.
static func haggle(g, cid: String, raise: float) -> Dictionary:
	var w := find(g, cid)
	if w.is_empty():
		return g._fail("They walked off.")
	if w.haggled:
		return g._fail("You already haggled.")
	w.haggled = true
	var asked := int(round(float(w.price) * (1.0 + raise)))
	var cname: String = g.contact(cid).name
	if asked <= ceiling(g, w) and g.rng.randf() < Deals.counter_chance(g, cid, raise):
		w.price = asked
		return g._ok("%s agrees to %d cr each." % [cname, asked])
	var s: Dictionary = People.state(g, cid)
	s.affinity = clampf(float(s.affinity) + float(rules(g).get("affinity_haggle_fail", 0.0)), -1.0, 1.0)
	return g._fail("%s won't pay %d cr." % [cname, asked])


## Turns the customer away: a small dent in how they feel about you, and they stay away for a while.
static func decline(g, cid: String) -> Dictionary:
	if find(g, cid).is_empty():
		return g._fail("They walked off.")
	var s: Dictionary = People.state(g, cid)
	s.affinity = clampf(float(s.affinity) + float(rules(g).get("affinity_decline", 0.0)), -1.0, 1.0)
	_leave(g, cid, "declined", float(rules(g).get("cooldown", 240.0)))
	return g._ok("%s shrugs and walks off." % g.contact(cid).name)
