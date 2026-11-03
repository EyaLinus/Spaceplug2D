extends RefCounted
## Deal-O-Matic: customers you know text you requests (drug, amount, price per unit). You accept, counter (a higher
## price; acceptance depends on affinity and addiction) or decline. An accepted deal has to be handed over in person
## (talk to the customer on their planet) before the meet window runs out; no-shows cost affinity.
## State on Game.offers (saved). Numbers in content.json "deals". Pure functions on a Game, no scene deps.
##
## offer: {id, contact, base, qty, price (per unit), state, expires_at (total_time), place, countered, msgs: [{me, text}],
##   meet_at (total_time of the appointment), countered_qty, countered_time}
## An agreed deal is an appointment: be at the customer's planet around `meet_at` (shown on the in-game clock). Handing
## over up to `ontime_hours` after it is fine, later (up to `late_hours`) costs affinity and part of the price, and
## after that the deal expires as a no-show (expires_at = meet_at + late_hours). Early is always fine.
## state: new (waiting for your answer) | accepted (meet them) | dropped (goods wait in a dead drop, deaddrops.gd) | done | declined | expired | stolen

const People = preload("res://scripts/core/people.gd")
const Mixing = preload("res://scripts/core/mixing.gd")
const Products = preload("res://scripts/core/products.gd")

const OPEN := ["new", "accepted"]


static func rules(g) -> Dictionary:
	return g.data.get("deals", {})


static func find(g, offer_id: int) -> Dictionary:
	for o in g.offers:
		if int(o.id) == offer_id:
			return o
	return {}


static func open_for(g, cid: String) -> Dictionary:
	for o in g.offers:
		if o.contact == cid and o.state in OPEN:
			return o
	return {}


static func count_state(g, st: String) -> int:
	var n := 0
	for o in g.offers:
		if o.state == st:
			n += 1
	return n


## Accepted deals with people at `loc` (what the surface marks and the Deals panel offers to hand over).
static func agreed_at(g, loc: String) -> Array:
	var r: Array = []
	for o in g.offers:
		if o.state == "accepted" and g.contact(o.contact).get("location", "") == loc:
			r.append(o)
	return r


## Real seconds per in-game hour.
static func hour_seconds(g) -> float:
	return g.day_seconds() / 24.0


## Clock hour (0..24) at `t` (a total_time value).
static func hour_at(g, t: float) -> float:
	return fposmod(People.hour(g) + (t - g.total_time) / hour_seconds(g), 24.0)


## "14:30" for a total_time value, prefixed "tomorrow " when it falls after the end of today.
static func when_text(g, t: float) -> String:
	var h := hour_at(g, t)
	var s := "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]
	return ("tomorrow " + s) if t >= day_end(g) else s


## total_time at which the current day ends.
static func day_end(g) -> float:
	return g.total_time + (g.day_seconds() - g.day_time)


## Agreed appointments that fall on the rest of today, soonest first (the phone's calendar strip).
static func today(g) -> Array:
	var r: Array = []
	for o in g.offers:
		if o.state == "accepted" and float(o.get("meet_at", 0.0)) < day_end(g):
			r.append(o)
	r.sort_custom(func(a, b): return float(a.meet_at) < float(b.meet_at))
	return r


## total_time of the last moment that still counts as on time.
static func late_seconds(g, o: Dictionary) -> float:
	return float(o.get("meet_at", 0.0)) + float(rules(g).get("ontime_hours", 1.0)) * hour_seconds(g)


## "early" / "ontime" / "late" for handing over right now.
static func timing(g, o: Dictionary) -> String:
	var m := float(o.get("meet_at", 0.0))
	if g.total_time < m:
		return "early"
	return "ontime" if g.total_time <= late_seconds(g, o) else "late"


## Price per unit you get if you hand over now (late deliveries are discounted).
static func pay_price(g, o: Dictionary) -> int:
	if timing(g, o) != "late":
		return int(o.price)
	return maxi(int(round(float(o.price) * (1.0 - float(rules(g).get("late_discount", 0.0))))), 1)


## Fills in the appointment fields on an offer loaded from an old save.
static func migrate(g, o: Dictionary) -> void:
	if not o.has("meet_at"):
		o["meet_at"] = g.total_time if o.get("state", "") == "accepted" \
			else g.total_time + float(rules(g).get("min_lead_hours", 2.0)) * hour_seconds(g)
	o["countered_qty"] = bool(o.get("countered_qty", false))
	o["countered_time"] = bool(o.get("countered_time", false))


## Where the customer is at `t` (spot on their planet), "" when the schedule has no entry.
static func place_at(g, cid: String, t: float) -> String:
	return str(People.whereabouts(g.contact(cid), hour_at(g, t)).get("place", ""))


## Price per unit a customer offers for a plain Standard unit of `base`, plus the texting premium.
## With an asking price on that product (H1) the customer starts from it when it is within what they would pay, and
## otherwise names the most they will pay.
static func offer_price(g, cid: String, base: String) -> int:
	var c: Dictionary = g.contact(cid)
	var key := Mixing.key(base, [g.data.bases[base].innate])
	var p: int = g.sell_price(key, cid, c.location)
	var offer := maxi(int(round(p * (1.0 + float(rules(g).get("premium", 0.0))))), 1)
	var ask: int = Products.asking(g, key)
	if ask < 0:
		return offer
	var cap := maxi(int(floor(offer * (1.0 + Products.tolerance(g, cid)))), 1)
	return mini(ask, cap)


# ---------------------------------------------------------------- simulation

## Called from Game.tick: every `interval` seconds each known customer without an open deal may text you.
static func tick(g, dt: float) -> void:
	var r := rules(g)
	if r.is_empty():
		return
	g.offer_clock += dt
	for o in g.offers:
		if o.state in OPEN and g.total_time >= float(o.expires_at):
			_expire(g, o)
	var interval := float(r.get("interval", 45.0))
	while g.offer_clock >= interval:
		g.offer_clock -= interval
		_roll_requests(g)
	_trim(g)


static func _roll_requests(g) -> void:
	var r := rules(g)
	var open := 0
	for o in g.offers:
		if o.state in OPEN:
			open += 1
	for c in g.data.contacts:
		if open >= int(r.get("max_open", 3)):
			return
		var s: Dictionary = People.state(g, c.id)
		if not s.known or not open_for(g, c.id).is_empty() or People.budget_left(g, c.id) <= 0:
			continue
		var chance := float(r.get("chance", 0.3)) * (0.5 + float(s.addiction))
		if g.rng.randf() < chance:
			if not request(g, c.id).is_empty():
				open += 1


## Creates a request from `cid` (also used by tests and the smoke run). Returns the offer or {} if they can't buy.
static func request(g, cid: String) -> Dictionary:
	var c: Dictionary = g.contact(cid)
	var prefers: Array = c.get("prefers", [])
	if c.is_empty() or prefers.is_empty():
		return {}
	var base: String = prefers[g.rng.randi() % prefers.size()]
	var price := offer_price(g, cid, base)
	var qty := mini(People.max_units(g, cid), People.budget_left(g, cid) / price)
	if qty <= 0:
		return {}
	qty = g.rng.randi_range(maxi(1, qty / 2), qty)
	var lead: Array = rules(g).get("lead_hours", [6, 14])
	var meet_at: float = g.total_time + g.rng.randf_range(float(lead[0]), float(lead[1])) * hour_seconds(g)
	g.next_offer_id += 1
	var o := {
		"id": g.next_offer_id, "contact": cid, "base": base, "qty": qty, "price": price, "state": "new",
		"expires_at": g.total_time + float(rules(g).get("answer_seconds", 90.0)), "countered": false,
		"countered_qty": false, "countered_time": false, "meet_at": meet_at,
		"place": place_at(g, cid, meet_at), "msgs": [],
	}
	_say(o, false, _request_text(g, o))
	g.offers.append(o)
	g._emit("offer_new", {"offer": o.id, "contact": cid})
	return o


static func _expire(g, o: Dictionary) -> void:
	var was: String = o.state
	o.state = "expired"
	if was == "accepted":
		_affinity(g, o.contact, float(rules(g).get("affinity_noshow", 0.0)))
		_say(o, false, "You never showed. Don't waste my time.")
	else:
		_say(o, false, "Forget it, found someone else.")
	g._emit("offer_expired", {"offer": o.id, "contact": o.contact, "was": was})


## Keeps the open deals plus the newest `history` closed ones.
static func _trim(g) -> void:
	var keep := int(rules(g).get("history", 12))
	var closed := 0
	for i in range(g.offers.size() - 1, -1, -1):
		if not (g.offers[i].state in OPEN) and g.offers[i].state != "dropped":  # "dropped" = waiting at a dead drop
			closed += 1
			if closed > keep:
				g.offers.remove_at(i)


# ---------------------------------------------------------------- your answers

static func accept(g, offer_id: int) -> Dictionary:
	var o := find(g, offer_id)
	if o.is_empty() or o.state != "new":
		return g._fail("That request is gone.")
	_agree(g, o)
	_say(o, true, "Deal. %d × %s for %d cr each, %s." % [o.qty, g.data.bases[o.base].name, o.price, when_text(g, float(o.meet_at))])
	_say(o, false, _meet_text(g, o))
	g._emit("offer_accepted", {"offer": o.id, "contact": o.contact})
	return g._ok("Deal agreed. Meet %s on %s at %s." % [g.contact(o.contact).name, g.loc_data(g.contact(o.contact).location).get("name", ""), when_text(g, float(o.meet_at))])


## Ask for `raise` more per unit (0.1 = +10 %). One counter per request; a refusal keeps the old price and annoys them.
static func counter(g, offer_id: int, raise: float) -> Dictionary:
	var o := find(g, offer_id)
	if o.is_empty() or o.state != "new":
		return g._fail("That request is gone.")
	if o.countered:
		return g._fail("You already haggled.")
	o.countered = true
	var asked := int(round(float(o.price) * (1.0 + raise)))
	_say(o, true, "Make it %d cr each." % asked)
	if g.rng.randf() < counter_chance(g, o.contact, raise):
		o.price = asked
		_agree(g, o)
		_say(o, false, "Fine, %d it is. %s" % [asked, _meet_text(g, o)])
		g._emit("offer_accepted", {"offer": o.id, "contact": o.contact, "countered": true})
		return g._ok("%s agreed to %d cr each." % [g.contact(o.contact).name, asked])
	_affinity(g, o.contact, float(rules(g).get("affinity_counter_fail", 0.0)))
	_say(o, false, "No way. %d each, take it or leave it." % o.price)
	g._emit("offer_countered", {"offer": o.id, "contact": o.contact})
	return g._fail("%s won't go higher." % g.contact(o.contact).name)


## Ask for another amount. Fewer units always works; more is capped by what they can use and afford. The deal stays
## open (answer it afterwards); one amount counter per request.
static func counter_qty(g, offer_id: int, qty: int) -> Dictionary:
	var o := find(g, offer_id)
	if o.is_empty() or o.state != "new":
		return g._fail("That request is gone.")
	if o.countered_qty:
		return g._fail("You already changed the amount.")
	qty = maxi(qty, 1)
	o.countered_qty = true
	_say(o, true, "Can we say %d?" % qty)
	if qty <= int(o.qty) or qty <= qty_cap(g, o.contact, int(o.price)):
		o.qty = qty
		_say(o, false, "%d works." % qty)
		return g._ok("%s agreed to %d units." % [g.contact(o.contact).name, qty])
	_affinity(g, o.contact, float(rules(g).get("affinity_counter_fail", 0.0)))
	_say(o, false, "I can't take that many. %d, no more." % int(o.qty))
	return g._fail("%s can't take %d." % [g.contact(o.contact).name, qty])


## Most units a customer takes at `price` (their usual amount with a margin, bounded by their budget left today).
static func qty_cap(g, cid: String, price: int) -> int:
	var by_use := int(floor(People.max_units(g, cid) * float(rules(g).get("qty_cap", 1.5))))
	return maxi(mini(by_use, People.budget_left(g, cid) / maxi(price, 1)), 1)


## Ask to meet `hours` later. Accepted when within their patience (more patient when they like you, less when hooked).
static func counter_time(g, offer_id: int, hours: float) -> Dictionary:
	var o := find(g, offer_id)
	if o.is_empty() or o.state != "new":
		return g._fail("That request is gone.")
	if o.countered_time:
		return g._fail("You already moved the time.")
	o.countered_time = true
	var asked: float = float(o.meet_at) + hours * hour_seconds(g)
	_say(o, true, "Can we meet %d hours later, around %s?" % [int(hours), when_text(g, asked)])
	if hours <= patience_hours(g, o.contact):
		o.meet_at = asked
		o.place = place_at(g, o.contact, asked)
		_say(o, false, "OK, %s." % when_text(g, asked))
		return g._ok("%s moved the meet to %s." % [g.contact(o.contact).name, when_text(g, asked)])
	_affinity(g, o.contact, float(rules(g).get("affinity_counter_fail", 0.0)))
	_say(o, false, "I can't wait that long. %s or never." % when_text(g, float(o.meet_at)))
	return g._fail("%s won't wait." % g.contact(o.contact).name)


## How many hours later than proposed a customer still agrees to.
static func patience_hours(g, cid: String) -> float:
	var r := rules(g)
	var s: Dictionary = People.state(g, cid)
	return maxf(float(r.get("time_base", 3.0)) + float(r.get("time_affinity", 3.0)) * float(s.affinity) \
		- float(r.get("time_addiction", 3.0)) * float(s.addiction), 0.5)


## Chance that a customer accepts a counter of `raise`: loyal and hooked customers pay more.
static func counter_chance(g, cid: String, raise: float) -> float:
	var r := rules(g)
	var s: Dictionary = People.state(g, cid)
	var p := float(r.get("accept_base", 0.8)) - raise * float(r.get("accept_per_raise", 2.6))
	p += float(s.affinity) * float(r.get("accept_affinity", 0.4)) + float(s.addiction) * float(r.get("accept_addiction", 0.4))
	return clampf(p, 0.05, 0.95)


static func decline(g, offer_id: int) -> Dictionary:
	var o := find(g, offer_id)
	if o.is_empty() or not (o.state in OPEN):
		return g._fail("That request is gone.")
	var was: String = o.state
	o.state = "declined"
	_say(o, true, "Can't do it, sorry." if was == "new" else "Deal's off.")
	_affinity(g, o.contact, float(rules(g).get("affinity_decline" if was == "new" else "affinity_noshow", 0.0)))
	g._emit("offer_declined", {"offer": o.id, "contact": o.contact})
	return g._ok("Declined.")


## Products in cargo that satisfy the deal (right drug, enough units).
static func matching_products(g, o: Dictionary) -> Array:
	var r: Array = []
	for k in g.cargo:
		if Mixing.is_product(k) and Mixing.parse_key(k).base == o.base and int(g.cargo[k]) >= int(o.qty):
			r.append(k)
	return r


## Hands over an accepted deal in person: needs you docked where the customer lives and the units in cargo.
static func fulfill(g, offer_id: int, product_key: String) -> Dictionary:
	var o := find(g, offer_id)
	if o.is_empty() or o.state != "accepted":
		return g._fail("No agreed deal.")
	var c: Dictionary = g.contact(o.contact)
	if g.location != c.location:
		return g._fail("Meet %s on %s." % [c.name, g.loc_data(c.location).get("name", "")])
	if not product_key in matching_products(g, o):
		return g._fail("You need %d × %s." % [o.qty, g.data.bases[o.base].name])
	var p := Mixing.parse_key(product_key)
	var when := timing(g, o)
	var total := pay_price(g, o) * int(o.qty)
	g._add(g.cargo, product_key, -int(o.qty))
	g.credits += total
	g.stats.earned += total
	g.stats.units_sold += int(o.qty)
	if g.demand.get(g.location, {}).has(p.base):
		var d: Dictionary = g.demand[g.location]
		d[p.base] = maxf(float(d[p.base]) - float(g.data.market.saturation_per_unit) * int(o.qty), float(g.data.market.min_demand))
	People.record_deal(g, o.contact, product_key, int(o.qty), total, p)
	g.contact_ready_at[o.contact] = g.total_time + float(g.data.market.contact_cooldown)
	g.add_heat(float(g.loc_data().heat_per_unit) * int(o.qty) * g.heat_mult(p.base) * float(rules(g).get("heat_mult", 1.0)))
	o.state = "done"
	if when == "late":
		_affinity(g, o.contact, float(rules(g).get("late_affinity", 0.0)))
		_say(o, false, "You're late. I'm knocking something off. Text me when you've got more.")
	else:
		_say(o, false, "Pleasure. Text me when you've got more.")
	g._emit("sold", {"product": product_key, "qty": o.qty, "credits": total, "contact": o.contact, "offer": o.id})
	return g._ok("Handed over %d %s for %d cr%s." % [o.qty, g.item_name(product_key), total, " (late: -%d%%)" % int(float(rules(g).get("late_discount", 0.0)) * 100.0) if when == "late" else ""])


# ---------------------------------------------------------------- helpers

static func _agree(g, o: Dictionary) -> void:
	o.state = "accepted"
	var hs := hour_seconds(g)
	o.meet_at = maxf(float(o.get("meet_at", 0.0)), g.total_time + float(rules(g).get("min_lead_hours", 2.0)) * hs)
	o.place = place_at(g, o.contact, float(o.meet_at))
	o.expires_at = float(o.meet_at) + float(rules(g).get("late_hours", 4.0)) * hs


static func _affinity(g, cid: String, delta: float) -> void:
	var s: Dictionary = People.state(g, cid)
	s.affinity = clampf(float(s.affinity) + delta, -1.0, 1.0)


static func _say(o: Dictionary, me: bool, text: String) -> void:
	(o.msgs as Array).append({"me": me, "text": text})


static func _request_text(g, o: Dictionary) -> String:
	var drug: String = g.data.bases[o.base].name
	var lines := [
		"Hey, need %d %s. %d cr each?",
		"You got %d %s? I'll pay %d a unit.",
		"Running low. %d %s, %d cr each.",
	]
	return (lines[int(o.id) % lines.size()] % [o.qty, drug, o.price]) + " Say %s?" % when_text(g, float(o.meet_at))


static func _meet_text(g, o: Dictionary) -> String:
	var c: Dictionary = g.contact(o.contact)
	var where: String = g.loc_data(c.location).get("name", "")
	var at := when_text(g, float(o.meet_at))
	if str(o.place) != "":
		return "Find me on %s at %s, around the %s. Don't keep me waiting." % [where, at, str(o.place).to_lower()]
	return "Find me on %s at %s. Don't keep me waiting." % [where, at]
