extends RefCounted
## DeadDrop Logistics (phone app): request an anonymous drop point on a planet, station or outpost for a fee. While you
## are docked there you can leave goods in it for one job at a time:
##   - a Deal-O-Matic deal (deals.gd, state "accepted"): the customer collects the goods later and pays then. Much less heat
##     than a hand-over in person (rules.heat_mult), but the pickup can be stolen (no goods, no payment);
##   - a courier run: a courier carries the goods to your hub stash for a per-unit fee (same theft risk).
## An idle drop expires after rules.ttl seconds. Rules in content.json "deaddrops"; state on Game: `drops` (saved),
## `next_drop_id`, `drops_unseen` (finished jobs since the app was opened, runtime only). Pure functions on a Game.
##
## drop = {id, loc, spot, expires_at (total_time), job: {} or {kind: "deal"|"courier", key, qty, due, offer?, pay?, fee?}}

const Deals = preload("res://scripts/core/deals.gd")
const Mixing = preload("res://scripts/core/mixing.gd")
const People = preload("res://scripts/core/people.gd")


static func rules(g) -> Dictionary:
	return g.data.get("deaddrops", {})


static func find(g, drop_id: int) -> Dictionary:
	for d in g.drops:
		if int(d.id) == drop_id:
			return d
	return {}


static func at(g, loc: String) -> Dictionary:
	for d in g.drops:
		if d.loc == loc:
			return d
	return {}


## Locations a drop can be requested on (planets, stations, outposts).
static func eligible(g, loc: String) -> bool:
	var ld: Dictionary = g.loc_data(loc)
	return not ld.is_empty() and ld.get("dockable", true) and str(ld.get("kind", "")) in rules(g).get("kinds", [])


static func request_fee(g, loc: String) -> int:
	return int(rules(g).get("fee", 0))


static func request(g, loc: String) -> Dictionary:
	if g.state != "playing":
		return g._fail("Game over.")
	if not eligible(g, loc):
		return g._fail("No one will set up a drop there.")
	if not at(g, loc).is_empty():
		return g._fail("You already have a drop there.")
	if g.drops.size() >= int(rules(g).get("max_open", 3)):
		return g._fail("Too many open drops (%d)." % int(rules(g).get("max_open", 3)))
	var fee := request_fee(g, loc)
	if fee > g.credits:
		return g._fail("Not enough credits.")
	g.credits -= fee
	var spots: Array = rules(g).get("spots", {}).get(str(g.loc_data(loc).kind), ["a loose panel"])
	g.next_drop_id += 1
	var d := {
		"id": g.next_drop_id, "loc": loc, "spot": str(spots[g.rng.randi() % spots.size()]),
		"expires_at": g.total_time + float(rules(g).get("ttl", 600.0)), "job": {},
	}
	g.drops.append(d)
	g._emit("drop_opened", {"drop": d.id, "loc": loc})
	return g._ok("Drop ready on %s: %s." % [g.loc_data(loc).name, d.spot])


## Gives a drop up. Only while it holds no goods.
static func release(g, drop_id: int) -> Dictionary:
	var d := find(g, drop_id)
	if d.is_empty():
		return g._fail("No such drop.")
	if not d.job.is_empty():
		return g._fail("Goods are still in it.")
	g.drops.erase(d)
	g._emit("drop_closed", {"drop": drop_id, "why": "released"})
	return g._ok("Drop abandoned.")


static func is_free(d: Dictionary) -> bool:
	return (d.job as Dictionary).is_empty()


## Agreed deals that can be settled at this drop: the customer lives where the drop is.
static func deal_options(g, d: Dictionary) -> Array:
	var r: Array = []
	for o in g.offers:
		if o.state == "accepted" and g.contact(o.contact).get("location", "") == d.loc:
			r.append(o)
	return r


## Heat for leaving the goods of a deal here instead of handing them over in person.
static func deal_heat(g, o: Dictionary) -> float:
	return float(g.loc_data().heat_per_unit) * int(o.qty) * g.sale_heat_mult(o.base) \
		* float(Deals.rules(g).get("heat_mult", 1.0)) * float(rules(g).get("heat_mult", 1.0))


static func theft_chance(g, kind: String) -> float:
	var r := rules(g)
	var p := float(r.get("theft_chance", 0.0)) + float(g.heat) / float(g.data.heat.max) * float(r.get("theft_heat", 0.0))
	if kind == "courier":
		p += float(r.get("courier_extra_theft", 0.0))
	return clampf(p, 0.0, 0.9)


static func _check_here(g, d: Dictionary) -> Dictionary:
	if g.state != "playing":
		return g._fail("Game over.")
	if d.is_empty():
		return g._fail("No such drop.")
	if g.location != d.loc:
		return g._fail("Be docked on %s to use this drop." % g.loc_data(d.loc).name)
	if not is_free(d):
		return g._fail("The drop is already in use.")
	return {}


## Leave the goods of an accepted deal in the drop; the customer picks them up after rules.pickup_seconds.
static func assign_deal(g, drop_id: int, offer_id: int, product_key: String) -> Dictionary:
	var d := find(g, drop_id)
	var bad := _check_here(g, d)
	if not bad.is_empty():
		return bad
	var o := Deals.find(g, offer_id)
	if o.is_empty() or o.state != "accepted":
		return g._fail("No agreed deal.")
	if g.contact(o.contact).location != d.loc:
		return g._fail("%s doesn't collect on %s." % [g.contact(o.contact).name, g.loc_data(d.loc).name])
	if not product_key in Deals.matching_products(g, o):
		return g._fail("You need %d × %s." % [o.qty, g.data.bases[o.base].name])
	g._add(g.cargo, product_key, -int(o.qty))
	g.add_heat(deal_heat(g, o))
	o.state = "dropped"
	o.drop = d.id
	d.job = {"kind": "deal", "offer": o.id, "key": product_key, "qty": int(o.qty), "due": g.total_time + float(rules(g).get("pickup_seconds", 25.0))}
	Deals._say(o, false, "Got it. I'll swing by the drop.")
	g._emit("drop_loaded", {"drop": d.id, "kind": "deal"})
	return g._ok("%d × %s left at the drop. %s collects shortly." % [o.qty, g.item_name(product_key), g.contact(o.contact).name])


static func courier_fee(g, qty: int) -> int:
	return maxi(int(rules(g).get("courier_fee_min", 0)), int(rules(g).get("courier_fee_unit", 0)) * qty)


## Courier run: the goods travel from this drop to your hub stash.
static func send_courier(g, drop_id: int, item: String, qty: int) -> Dictionary:
	var d := find(g, drop_id)
	var bad := _check_here(g, d)
	if not bad.is_empty():
		return bad
	if qty <= 0 or int(g.cargo.get(item, 0)) < qty:
		return g._fail("You don't carry that much.")
	var fee := courier_fee(g, qty)
	if fee > g.credits:
		return g._fail("Not enough credits for the courier.")
	g.credits -= fee
	g._add(g.cargo, item, -qty)
	d.job = {"kind": "courier", "key": item, "qty": qty, "fee": fee, "due": g.total_time + float(rules(g).get("courier_seconds", 40.0))}
	g._emit("drop_loaded", {"drop": d.id, "kind": "courier"})
	return g._ok("Courier took %d × %s (fee %d). It arrives at your hub stash soon." % [qty, g.item_name(item), fee])


# ---------------------------------------------------------------- simulation

## Called from Game.tick: finishes due jobs and lets idle drops expire.
static func tick(g) -> void:
	if g.drops.is_empty():
		return
	for i in range(g.drops.size() - 1, -1, -1):
		var d: Dictionary = g.drops[i]
		if not is_free(d):
			if g.total_time >= float(d.job.due):
				_finish(g, d)
		elif g.total_time >= float(d.expires_at):
			g.drops.remove_at(i)
			g._emit("drop_closed", {"drop": d.id, "why": "expired"})


static func _finish(g, d: Dictionary) -> void:
	var j: Dictionary = d.job
	d.job = {}
	d.expires_at = g.total_time + float(rules(g).get("ttl", 600.0))
	g.drops_unseen += 1
	var stolen: bool = g.rng.randf() < theft_chance(g, str(j.kind))
	if j.kind == "deal":
		var o := Deals.find(g, int(j.offer))
		if o.is_empty():
			return
		if stolen:
			o.state = "stolen"
			Deals._say(o, false, "Nothing in the drop. Someone got there first?")
			g._emit("drop_stolen", {"drop": d.id, "kind": "deal", "offer": o.id, "qty": j.qty})
			return
		var p := Mixing.parse_key(str(j.key))
		var total := int(o.price) * int(o.qty)
		g.credits += total
		g.stats.earned += total
		g.stats.units_sold += int(o.qty)
		if g.demand.get(d.loc, {}).has(p.base):
			var dm: Dictionary = g.demand[d.loc]
			dm[p.base] = maxf(float(dm[p.base]) - float(g.data.market.saturation_per_unit) * int(o.qty), float(g.data.market.min_demand))
		People.record_deal(g, o.contact, str(j.key), int(o.qty), total, p)
		g.contact_ready_at[o.contact] = g.total_time + float(g.data.market.contact_cooldown)
		o.state = "done"
		Deals._say(o, false, "Picked up. Pleasure doing business.")
		g._emit("drop_pickup", {"drop": d.id, "kind": "deal", "offer": o.id, "credits": total, "contact": o.contact})
	else:
		if stolen:
			g._emit("drop_stolen", {"drop": d.id, "kind": "courier", "qty": j.qty})
			return
		g._add(g.stash, str(j.key), int(j.qty))
		g._emit("drop_pickup", {"drop": d.id, "kind": "courier", "item": j.key, "qty": j.qty})


static func from_save(g, d: Dictionary) -> void:
	g.drops = []
	for x in d.get("drops", []):
		if not g.data.locations.has(str(x.get("loc", ""))):
			continue
		var job := {}
		var sj: Dictionary = x.get("job", {})
		if not sj.is_empty():
			job = sj.duplicate(true)
			job.qty = int(sj.qty)
			job.due = float(sj.due)
		g.drops.append({"id": int(x.id), "loc": str(x.loc), "spot": str(x.get("spot", "")), "expires_at": float(x.expires_at), "job": job})
	g.next_drop_id = int(d.get("next_drop_id", 0))
	for x in g.drops:
		g.next_drop_id = maxi(g.next_drop_id, int(x.id))
