extends RefCounted
## Deal-O-Matic: customers you know text you requests (drug, amount, price per unit). You accept, counter (a higher
## price; acceptance depends on affinity and addiction) or decline. An accepted deal has to be handed over in person
## (talk to the customer on their planet) before the meet window runs out; no-shows cost affinity.
## State on Game.offers (saved). Numbers in content.json "deals". Pure functions on a Game, no scene deps.
##
## H2 appointments: every request names a product (a recipe from your Products book when you have one they like,
## else the plain drug), amount, price (your asking price when they accept it, else their offer + texting premium) and a
## meeting time on the clock (meet_at, total_time) at the place their schedule puts them then. You can hand over from
## `early_hours` before the meeting until `window_hours` after it; later than `grace_hours` costs affinity, after the
## window the deal is missed. Before you agree you can haggle once each on price, amount and time.
##
## offer: {id, contact, base, product ("" = any of the drug), qty, price (per unit), state, expires_at (total_time),
##         meet_at (total_time, 0 = no appointment, old saves), place, countered, haggled: [qty|time], msgs: [{me, text}]}
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


## Price per unit a customer offers: your asking price for the product when they accept it, else their own offer
## for a Standard unit plus the texting premium.
static func offer_price(g, cid: String, base: String, product: String = "") -> int:
	var c: Dictionary = g.contact(cid)
	var key := product if product != "" else Mixing.key(base, [g.data.bases[base].innate])
	var p: int = g.sell_price(key, cid, c.location)
	var premium := maxi(int(round(p * (1.0 + float(rules(g).get("premium", 0.0))))), 1)
	var ask := Products.asking(g, key)
	if ask > 0 and ask <= Products.ceiling(g, key, cid, c.location):
		return maxi(ask, 1)
	return mini(premium, Products.ceiling(g, key, cid, c.location)) if ask > 0 else premium


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
		elif o.state == "accepted" and float(o.get("meet_at", 0.0)) > 0.0 and not o.get("reminded", false) \
				and g.total_time >= float(o.meet_at) - float(rules(g).get("remind_hours", 1)) * seconds_per_hour(g):
			o.reminded = true
			g._emit("meet_soon", {"offer": o.id, "contact": o.contact})
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
	var product := _pick_product(g, c, base)
	var price := offer_price(g, cid, base, product)
	var qty := mini(People.max_units(g, cid), People.budget_left(g, cid) / price)
	if qty <= 0:
		return {}
	qty = g.rng.randi_range(maxi(1, qty / 2), qty)
	var r := rules(g)
	var ahead: int = g.rng.randi_range(int(r.get("lead_hours_min", 4)), int(r.get("lead_hours_max", 10)))
	var meet_at: float = hour_start(g, ahead)
	var place: Dictionary = People.whereabouts(c, clock_at(g, meet_at))
	g.next_offer_id += 1
	var o := {
		"id": g.next_offer_id, "contact": cid, "base": base, "product": product, "qty": qty, "price": price, "state": "new",
		"expires_at": g.total_time + float(r.get("answer_seconds", 90.0)), "meet_at": meet_at, "countered": false,
		"haggled": [], "place": place.get("place", ""), "msgs": [],
	}
	_say(o, false, _request_text(g, o))
	g.offers.append(o)
	g._emit("offer_new", {"offer": o.id, "contact": cid})
	return o


## A product the customer asks for by name: one from your recipe book of `base` (the one with their liked trait first,
## else a random one); "" = any product of the drug.
static func _pick_product(g, c: Dictionary, base: String) -> String:
	var list: Array = Products.list(g, base)
	if list.is_empty() or g.rng.randf() < float(rules(g).get("any_product_chance", 0.3)):
		return ""
	for rk in list:
		if (Mixing.parse_key(rk).traits as Array).has(c.get("likes", "")):
			return rk
	return list[g.rng.randi() % list.size()]


# ---------------------------------------------------------------- clock

static func seconds_per_hour(g) -> float:
	return g.day_seconds() / 24.0


## Hour of the day (0..24) at the absolute time `t` (total_time).
static func clock_at(g, t: float) -> float:
	return fposmod(People.hour(g) + (t - g.total_time) / seconds_per_hour(g), 24.0)


## total_time of the start of the full hour `hours` from now.
static func hour_start(g, hours: int) -> float:
	var now := People.hour(g)
	return g.total_time + (floor(now) + hours - now) * seconds_per_hour(g)


static func clock_text(g, t: float) -> String:
	var h := clock_at(g, t)
	var hh := int(floor(h))
	var mm := int(floor((h - hh) * 60.0))
	var day_off := int(floor((People.hour(g) + (t - g.total_time) / seconds_per_hour(g)) / 24.0))
	return "%02d:%02d%s" % [hh, mm, " tomorrow" if day_off >= 1 else ""]


static func window(g, o: Dictionary) -> Dictionary:
	var r := rules(g)
	var at := float(o.get("meet_at", 0.0))
	var sph := seconds_per_hour(g)
	return {
		"open": at - float(r.get("early_hours", 2)) * sph, "at": at,
		"late": at + float(r.get("grace_hours", 1)) * sph, "close": at + float(r.get("window_hours", 3)) * sph,
	}


## "early" (too soon to meet), "open", "late" (still meets, costs affinity) for an accepted deal with a meeting time.
static func meet_phase(g, o: Dictionary) -> String:
	if float(o.get("meet_at", 0.0)) <= 0.0:
		return "open"
	var w := window(g, o)
	if g.total_time < float(w.open):
		return "early"
	return "late" if g.total_time > float(w.late) else "open"


## Accepted deals sorted by meeting time (the phone's calendar strip).
static func agenda(g) -> Array:
	var r: Array = []
	for o in g.offers:
		if o.state == "accepted":
			r.append(o)
	r.sort_custom(func(a, b): return float(a.get("meet_at", 0.0)) < float(b.get("meet_at", 0.0)))
	return r


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
	_say(o, true, "Deal. %d × %s for %d cr each." % [o.qty, want_name(g, o), o.price])
	_say(o, false, _meet_text(g, o))
	g._emit("offer_accepted", {"offer": o.id, "contact": o.contact})
	return g._ok("Deal agreed. Meet %s on %s." % [g.contact(o.contact).name, g.loc_data(g.contact(o.contact).location).get("name", "")])


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


## Haggle on the amount: `factor` < 1 asks to sell fewer (always fine, a little disappointing), > 1 asks them to take more
## (chance like a price raise of the same size, capped by their budget and deal size).
static func counter_qty(g, offer_id: int, factor: float) -> Dictionary:
	var o := find(g, offer_id)
	if o.is_empty() or o.state != "new":
		return g._fail("That request is gone.")
	if (o.get("haggled", []) as Array).has("qty"):
		return g._fail("You already haggled on the amount.")
	_haggled(o, "qty")
	var cap := mini(People.max_units(g, o.contact) + int(rules(g).get("qty_stretch", 2)), People.budget_left(g, o.contact) / maxi(int(o.price), 1))
	var want := clampi(int(round(float(o.qty) * factor)), 1, maxi(cap, 1))
	if want == int(o.qty):
		return g._fail("That's all they can take." if factor > 1.0 else "They want at least one.")
	_say(o, true, "How about %d instead?" % want)
	if factor < 1.0 or g.rng.randf() < counter_chance(g, o.contact, factor - 1.0):
		o.qty = want
		_say(o, false, "Fine, %d then." % want)
		g._emit("offer_countered", {"offer": o.id, "contact": o.contact, "ok": true})
		return g._ok("%s takes %d." % [g.contact(o.contact).name, want])
	_affinity(g, o.contact, float(rules(g).get("affinity_counter_fail", 0.0)) * 0.5)
	_say(o, false, "I said %d. Can't use more." % int(o.qty))
	g._emit("offer_countered", {"offer": o.id, "contact": o.contact, "ok": false})
	return g._fail("%s sticks to %d." % [g.contact(o.contact).name, int(o.qty)])


## Haggle on the time: move the meeting `hours` later (or earlier, negative). Busy people may say no.
static func counter_time(g, offer_id: int, hours: int) -> Dictionary:
	var o := find(g, offer_id)
	if o.is_empty() or o.state != "new":
		return g._fail("That request is gone.")
	if (o.get("haggled", []) as Array).has("time"):
		return g._fail("You already moved the time once.")
	var at := float(o.get("meet_at", 0.0)) + hours * seconds_per_hour(g)
	if at < g.total_time + float(rules(g).get("lead_hours_min", 4)) * 0.5 * seconds_per_hour(g):
		return g._fail("That's too soon.")
	_haggled(o, "time")
	_say(o, true, "Can we make it %s?" % clock_text(g, at))
	var p := float(rules(g).get("time_accept", 0.75)) + float(People.state(g, o.contact).affinity) * 0.3 - absf(hours) * 0.03
	if g.rng.randf() < clampf(p, 0.1, 0.95):
		o.meet_at = at
		var c: Dictionary = g.contact(o.contact)
		o.place = People.whereabouts(c, clock_at(g, at)).get("place", o.place)
		_say(o, false, "%s works." % clock_text(g, at))
		g._emit("offer_countered", {"offer": o.id, "contact": o.contact, "ok": true})
		return g._ok("Moved to %s." % clock_text(g, at))
	_say(o, false, "No, %s or nothing." % clock_text(g, float(o.meet_at)))
	g._emit("offer_countered", {"offer": o.id, "contact": o.contact, "ok": false})
	return g._fail("%s can't move it." % g.contact(o.contact).name)


static func _haggled(o: Dictionary, what: String) -> void:
	if not o.has("haggled"):
		o["haggled"] = []
	(o.haggled as Array).append(what)


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
		if Mixing.is_product(k) and Mixing.parse_key(k).base == o.base and int(g.cargo[k]) >= int(o.qty) \
				and (str(o.get("product", "")) == "" or Products.recipe_key(k) == str(o.product)):
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
		return g._fail("You need %d × %s." % [o.qty, want_name(g, o)])
	var phase := meet_phase(g, o)
	if phase == "early":
		return g._fail("Too early. %s meets you at %s." % [c.name, clock_text(g, float(o.meet_at))])
	var p := Mixing.parse_key(product_key)
	var total := int(o.price) * int(o.qty)
	g._add(g.cargo, product_key, -int(o.qty))
	g.credits += total
	g.stats.earned += total
	g.stats.units_sold += int(o.qty)
	if g.demand.get(g.location, {}).has(p.base):
		var d: Dictionary = g.demand[g.location]
		d[p.base] = maxf(float(d[p.base]) - float(g.data.market.saturation_per_unit) * int(o.qty), float(g.data.market.min_demand))
	People.record_deal(g, o.contact, product_key, int(o.qty), total, p)
	g.contact_ready_at[o.contact] = g.total_time + float(g.data.market.contact_cooldown)
	g.add_heat(float(g.loc_data().heat_per_unit) * int(o.qty) * g.sale_heat_mult(p.base) * float(rules(g).get("heat_mult", 1.0)))
	o.state = "done"
	if phase == "late":
		_affinity(g, o.contact, float(rules(g).get("affinity_late", 0.0)))
		_say(o, false, "You're late. Don't make it a habit.")
	else:
		_affinity(g, o.contact, float(rules(g).get("affinity_on_time", 0.0)))
		_say(o, false, "Right on time. Pleasure doing business.")
	g._emit("sold", {"product": product_key, "qty": o.qty, "credits": total, "contact": o.contact, "offer": o.id})
	return g._ok("Handed over %d %s for %d cr." % [o.qty, g.item_name(product_key), total])


# ---------------------------------------------------------------- helpers

static func _agree(g, o: Dictionary) -> void:
	o.state = "accepted"
	if float(o.get("meet_at", 0.0)) > 0.0:
		o.expires_at = float(window(g, o).close)
	else:
		o.expires_at = g.total_time + float(rules(g).get("meet_seconds", 150.0))


static func _affinity(g, cid: String, delta: float) -> void:
	var s: Dictionary = People.state(g, cid)
	s.affinity = clampf(float(s.affinity) + delta, -1.0, 1.0)


static func _say(o: Dictionary, me: bool, text: String) -> void:
	(o.msgs as Array).append({"me": me, "text": text})


## "Weed [Glow, Sweet]" for a named product, else the drug name.
static func want_name(g, o: Dictionary) -> String:
	if str(o.get("product", "")) != "":
		return Mixing.display_name(g.data, str(o.product))
	return g.data.bases[o.base].name


static func _request_text(g, o: Dictionary) -> String:
	var drug := want_name(g, o)
	var when := clock_text(g, float(o.get("meet_at", 0.0))) if float(o.get("meet_at", 0.0)) > 0.0 else "today"
	var lines := [
		"Hey, need %d %s. %d cr each? Meet at %s.",
		"You got %d %s? I'll pay %d a unit. %s works for me.",
		"Running low. %d %s, %d cr each, around %s.",
	]
	return lines[int(o.id) % lines.size()] % [o.qty, drug, o.price, when]


static func _meet_text(g, o: Dictionary) -> String:
	var c: Dictionary = g.contact(o.contact)
	var where: String = g.loc_data(c.location).get("name", "")
	var spot := (", by the %s" % str(o.place).to_lower()) if str(o.place) != "" else ""
	if float(o.get("meet_at", 0.0)) <= 0.0:
		return "Find me on %s%s. Don't keep me waiting." % [where, spot]
	var when := clock_text(g, float(o.meet_at))
	return "See you at %s on %s%s. Don't be late." % [when, where, spot]
