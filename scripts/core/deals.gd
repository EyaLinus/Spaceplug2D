extends RefCounted
## Deal-O-Matic: named customers (people.gd) text you requests; you accept, counter or decline, then close the deal
## on foot at the agreed spot inside the time window. State lives on Game.deals (saved):
##   {offers: [offer], hour: int (last processed game hour), quiet: {contact id: hour until which they stay silent}}
## offer = {id, contact, loc, base, qty, price (credits per unit), spot (spot id), opens_at, expires_at (total_time
##   seconds), status, countered, tpl (text template index), created}
## status: open (waiting for your answer) | accepted (deliver in the window) | done | declined | expired (never answered)
##   | missed (accepted but not delivered) | walked (a greedy counter made them leave)
## Numbers and texts live in content.json "deals". Pure functions on a Game, no scene deps (the Game is passed in).

const Mixing = preload("res://scripts/core/mixing.gd")
const People = preload("res://scripts/core/people.gd")

const ACTIVE := ["open", "accepted"]


static func initial_state() -> Dictionary:
	return {"offers": [], "hour": 0, "quiet": {}}


static func from_save(saved: Dictionary) -> Dictionary:
	var r := initial_state()
	r.hour = int(saved.get("hour", 0))
	for k in saved.get("quiet", {}):
		r.quiet[str(k)] = int(saved.quiet[k])
	for o in saved.get("offers", []):
		r.offers.append({
			"id": int(o.id), "contact": str(o.contact), "loc": str(o.loc), "base": str(o.base), "qty": int(o.qty),
			"price": int(o.price), "spot": str(o.spot), "opens_at": float(o.opens_at), "expires_at": float(o.expires_at),
			"status": str(o.status), "countered": bool(o.get("countered", false)), "tpl": int(o.get("tpl", 0)),
			"created": float(o.get("created", 0.0)),
		})
	return r


static func rules(g) -> Dictionary:
	return g.data.get("deals", {})


# ---------------------------------------------------------------- queries

static func find(g, id: int) -> Dictionary:
	for o in g.deals.offers:
		if o.id == id:
			return o
	return {}


## The open or accepted offer of a contact ({} if none).
static func active(g, cid: String) -> Dictionary:
	for o in g.deals.offers:
		if o.contact == cid and o.status in ACTIVE:
			return o
	return {}


static func with_status(g, statuses: Array) -> Array:
	return g.deals.offers.filter(func(o): return o.status in statuses)


static func hour_seconds(g) -> float:
	return g.day_seconds() / 24.0


## Clock hour (0..24) at the game time `t` (total_time seconds).
static func clock_hour(g, t: float) -> float:
	var ds: float = g.day_seconds()
	return fposmod(g.day_time + (t - g.total_time), ds) / ds * 24.0


static func clock_text(g, t: float) -> String:
	var h := clock_hour(g, t)
	return "%02d:%02d" % [int(h), int((h - floorf(h)) * 60.0)]


static func spot_of(g, o: Dictionary) -> Dictionary:
	for s in rules(g).spots.get(o.loc, []):
		if s.id == o.spot:
			return s
	return {}


static func spot_name(g, o: Dictionary) -> String:
	return str(spot_of(g, o).get("name", "the meeting point"))


static func in_window(g, o: Dictionary) -> bool:
	return g.total_time >= float(o.opens_at) and g.total_time <= float(o.expires_at)


## Standard-grade product key the offer is priced against.
static func base_key(g, base: String) -> String:
	return Mixing.key(base, Mixing.traits_for(g.data, base, []))


## Stacks of cargo of the offer's drug, lowest grade first.
static func stacks(g, base: String) -> Array:
	var r: Array = []
	for k in g.cargo:
		if Mixing.is_product(k) and Mixing.parse_key(k).base == base:
			r.append(k)
	r.sort_custom(func(a, b):
		var ga: int = Mixing.parse_key(a).grade
		var gb: int = Mixing.parse_key(b).grade
		return ga < gb or (ga == gb and a < b))
	return r


static func units_held(g, base: String) -> int:
	var n := 0
	for k in stacks(g, base):
		n += int(g.cargo[k])
	return n


static func message(g, o: Dictionary) -> String:
	var texts: Array = rules(g).texts
	var t: String = texts[int(o.tpl) % texts.size()]
	return t.format({
		"name": g.contact(o.contact).get("name", "?"), "qty": o.qty, "drug": g.data.bases[o.base].name,
		"price": o.price, "spot": spot_name(g, o),
	})


# ---------------------------------------------------------------- requests

static func _next_id(g) -> int:
	var m := 0
	for o in g.deals.offers:
		m = maxi(m, int(o.id))
	return m + 1


## Chance per game hour that this person texts. Hooked, friendly customers ask far more often.
static func request_chance(g, cid: String) -> float:
	var r := rules(g)
	var s := People.state(g, cid)
	var addict := float(r.addiction_floor) + float(r.addiction_weight) * float(s.addiction)
	return clampf(float(r.request_chance_per_hour) * addict * (1.0 + float(r.affinity_weight) * float(s.affinity)), 0.0, 1.0)


## Builds a request from `cid` right now (not stored): drug, amount, price, spot and time window.
## {} if the person has nothing sensible to ask (no budget left, planet has no spots or demand).
static func roll_request(g, cid: String, rng: RandomNumberGenerator) -> Dictionary:
	var r := rules(g)
	var c: Dictionary = g.contact(cid)
	var loc: String = c.location
	var spots: Array = r.spots.get(loc, [])
	if c.is_empty() or spots.is_empty():
		return {}
	var wanted: Array = (c.get("prefers", []) as Array).filter(func(b): return g.demand.get(loc, {}).has(b))
	var any: Array = g.demand.get(loc, {}).keys()
	if any.is_empty():
		return {}
	var base: String = wanted[rng.randi() % wanted.size()] if not wanted.is_empty() else any[rng.randi() % any.size()]
	if rng.randf() < float(r.other_drug_chance):
		base = any[rng.randi() % any.size()]
	var spread: Array = r.price_spread
	var price := maxi(int(round(g.sell_price(base_key(g, base), cid, loc) * rng.randf_range(float(spread[0]), float(spread[1])))), 1)
	var cap := mini(People.max_units(g, cid), People.budget_left(g, cid) / price)
	if cap < 1:
		return {}
	var qty := rng.randi_range(maxi(1, cap / 2), cap)
	var lead: Array = r.lead_hours
	var win: Array = r.window_hours
	var opens: float = g.total_time + rng.randf_range(float(lead[0]), float(lead[1])) * hour_seconds(g)
	var taken := {}
	for o in with_status(g, ACTIVE):
		if o.loc == loc:
			taken[o.spot] = true
	var free := spots.filter(func(s): return not taken.has(s.id))
	var pool: Array = free if not free.is_empty() else spots
	return {
		"id": _next_id(g), "contact": cid, "loc": loc, "base": base, "qty": qty, "price": price,
		"spot": pool[rng.randi() % pool.size()].id, "opens_at": opens,
		"expires_at": opens + rng.randf_range(float(win[0]), float(win[1])) * hour_seconds(g),
		"status": "open", "countered": false, "tpl": rng.randi() % (r.texts as Array).size(), "created": g.total_time,
	}


static func hour_index(g) -> int:
	return int(floor(g.total_time / hour_seconds(g)))


## Called by Game.tick: once per elapsed game hour, expire old offers and let customers text.
static func tick(g) -> void:
	var st: Dictionary = g.deals
	var now := hour_index(g)
	if now - int(st.hour) > 72:
		st.hour = now - 72
	while int(st.hour) < now:
		st.hour = int(st.hour) + 1
		_hour(g, int(st.hour))


static func _hour(g, hour: int) -> void:
	var r := rules(g)
	_expire(g)
	var open_count := with_status(g, ACTIVE).size()
	for c in g.data.contacts:
		if open_count >= int(r.max_open):
			break
		var cid: String = c.id
		if not People.state(g, cid).known or not active(g, cid).is_empty():
			continue
		if int(g.deals.quiet.get(cid, 0)) > hour:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s:%d" % [cid, hour])
		if rng.randf() >= request_chance(g, cid):
			continue
		var o := roll_request(g, cid, rng)
		if o.is_empty():
			continue
		g.deals.offers.append(o)
		open_count += 1
		g.event.emit("deal_request", {"offer": o.id, "contact": cid})
		g.event.emit("deal_changed", {"offer": o.id})
	_prune(g)


static func _expire(g) -> void:
	var r := rules(g)
	for o in g.deals.offers:
		if o.status in ACTIVE and g.total_time > float(o.expires_at):
			if o.status == "open":
				o.status = "expired"
			else:
				o.status = "missed"
				_affinity(g, o.contact, float(r.miss_affinity))
			g.event.emit("deal_changed", {"offer": o.id})


static func _prune(g) -> void:
	var keep := int(rules(g).keep_finished)
	var finished := 0
	for i in range(g.deals.offers.size() - 1, -1, -1):
		if not g.deals.offers[i].status in ACTIVE:
			finished += 1
			if finished > keep:
				g.deals.offers.remove_at(i)


static func _affinity(g, cid: String, delta: float) -> void:
	var s := People.state(g, cid)
	s.affinity = clampf(float(s.affinity) + delta, -1.0, 1.0)


# ---------------------------------------------------------------- answers

static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}


static func _changed(g, o: Dictionary) -> void:
	g.event.emit("deal_changed", {"offer": o.id})


static func accept(g, id: int) -> Dictionary:
	var o := find(g, id)
	if o.is_empty() or o.status != "open":
		return _fail("That request is no longer open.")
	if g.total_time > float(o.expires_at):
		_expire(g)
		return _fail("Too late, they found someone else.")
	o.status = "accepted"
	_changed(g, o)
	return {"ok": true, "msg": "Deal on: %d × %s for %s at %s." % [o.qty, g.data.bases[o.base].name, g.contact(o.contact).name, spot_name(g, o)]}


static func decline(g, id: int) -> Dictionary:
	var o := find(g, id)
	if o.is_empty() or o.status != "open":
		return _fail("That request is no longer open.")
	o.status = "declined"
	g.deals.quiet[o.contact] = hour_index(g) + int(rules(g).decline_quiet_hours)
	_changed(g, o)
	return {"ok": true, "msg": "Declined. %s will ask again later." % g.contact(o.contact).name}


## Chance that `step` (index into haggle.steps) works on this customer: shrinks with the ask, grows with affinity and
## addiction (hooked people pay more to get their fix).
static func counter_chance(g, o: Dictionary, step: int) -> float:
	var h: Dictionary = rules(g).haggle
	var s := People.state(g, o.contact)
	var ask := float(h.steps[step])
	var p := float(h.base_chance) - ask * float(h.step_penalty) + float(s.affinity) * float(h.affinity_weight) + float(s.addiction) * float(h.addiction_weight)
	return clampf(p, float(h.min), float(h.max))


static func counter_price(g, o: Dictionary, step: int) -> int:
	return int(round(int(o.price) * (1.0 + float(rules(g).haggle.steps[step]))))


## True if the customer's daily budget can pay the countered price for the whole amount.
static func can_afford(g, o: Dictionary, step: int) -> bool:
	return counter_price(g, o, step) * int(o.qty) <= People.budget_left(g, o.contact)


## Haggles once per offer. `roll` (0..1) is drawn from a stable hash unless given (tests). Success accepts at the higher
## price; failure keeps the old price and annoys; a failed greedy ask (roll above chance + walk_margin) ends the offer.
static func counter(g, id: int, step: int, roll := -1.0) -> Dictionary:
	var o := find(g, id)
	var h: Dictionary = rules(g).haggle
	if o.is_empty() or o.status != "open":
		return _fail("That request is no longer open.")
	if o.countered:
		return _fail("They won't haggle twice.")
	if step < 0 or step >= (h.steps as Array).size():
		return _fail("Bad counter.")
	if not can_afford(g, o, step):
		return _fail("%s can't pay that much today." % g.contact(o.contact).name)
	var name: String = g.contact(o.contact).name
	var chance := counter_chance(g, o, step)
	if roll < 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("counter:%d:%d:%d" % [o.id, step, g.day])
		roll = rng.randf()
	o.countered = true
	if roll < chance:
		o.price = counter_price(g, o, step)
		o.status = "accepted"
		_changed(g, o)
		return {"ok": true, "msg": "%s agrees to %d cr each." % [name, o.price]}
	_affinity(g, o.contact, float(rules(g).counter_fail_affinity))
	if roll > chance + float(h.walk_margin):
		o.status = "walked"
		_affinity(g, o.contact, float(rules(g).walk_affinity))
		_changed(g, o)
		return _fail("%s laughs and walks away." % name)
	_changed(g, o)
	return _fail("%s won't go higher. Take it or leave it." % name)


# ---------------------------------------------------------------- closing the deal

## Hand the goods over. The UI only offers this at the spot on foot; the core checks planet, window and goods.
## Uses the lowest grades first; the agreed price is flat per unit, the grade moves affinity (people.gd).
static func hand_over(g, id: int) -> Dictionary:
	var o := find(g, id)
	if o.is_empty() or o.status != "accepted":
		return _fail("No deal to close.")
	if g.location != o.loc:
		return _fail("The meeting is on %s." % g.data.locations[o.loc].name)
	if g.total_time < float(o.opens_at):
		return _fail("Too early. %s shows up at %s." % [g.contact(o.contact).name, clock_text(g, o.opens_at)])
	if g.total_time > float(o.expires_at):
		_expire(g)
		return _fail("Too late, they left.")
	var have := units_held(g, o.base)
	if have < int(o.qty):
		return _fail("You need %d × %s, you carry %d." % [o.qty, g.data.bases[o.base].name, have])
	var left: int = o.qty
	for k in stacks(g, o.base):
		if left <= 0:
			break
		var n := mini(int(g.cargo[k]), left)
		if n >= int(g.cargo[k]):
			g.cargo.erase(k)
		else:
			g.cargo[k] = int(g.cargo[k]) - n
		left -= n
		People.record_deal(g, o.contact, k, n, int(o.price) * n, Mixing.parse_key(k))
	var total: int = int(o.price) * int(o.qty)
	var market: Dictionary = g.data.market
	if g.demand.get(o.loc, {}).has(o.base):
		for i in int(o.qty):
			g.demand[o.loc][o.base] = maxf(g.demand[o.loc][o.base] - float(market.saturation_per_unit), float(market.min_demand))
	g.credits += total
	g.stats.earned += total
	g.stats.units_sold += int(o.qty)
	g.contact_ready_at[o.contact] = g.total_time + float(market.contact_cooldown)
	g.add_heat(float(g.loc_data(o.loc).heat_per_unit) * int(o.qty) * g.heat_mult(o.base) * float(rules(g).heat_mult))
	_affinity(g, o.contact, float(rules(g).done_affinity))
	o.status = "done"
	g.event.emit("sold", {"product": base_key(g, o.base), "qty": o.qty, "credits": total, "contact": o.contact})
	_changed(g, o)
	return {"ok": true, "msg": "Deal closed with %s: %d cr." % [g.contact(o.contact).name, total]}


## Interactables for accepted offers on this planet (surface.gd appends them): the meeting spot on the map.
static func spots_here(g, loc: String, tile: float) -> Array:
	var r: Array = []
	if g == null:
		return r
	for o in with_status(g, ["accepted"]):
		if o.loc != loc:
			continue
		var sp := spot_of(g, o)
		if sp.is_empty():
			continue
		var pos := Vector2(sp.pos[0], sp.pos[1]) * tile
		r.append({
			"pos": pos, "stand": pos + Vector2(0, 22), "range": 44.0, "deal": true,
			"label": "Hand over %d × %s to %s" % [o.qty, g.data.bases[o.base].name, g.contact(o.contact).name],
			"action": "deal_handover", "payload": {"id": "deal_%d" % o.id, "title": g.contact(o.contact).name, "offer": o.id},
		})
	return r
