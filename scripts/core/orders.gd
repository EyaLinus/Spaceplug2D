extends RefCounted
## Market & Orders (phone app): order raws and additives from anywhere, pay cost + delivery fee up front, goods
## arrive after a delivery time in the hub stash or in an estate you own. Walk-in markets stay cheaper (no markup,
## no fee). Rules in content.json "orders"; state on Game: `orders` (open), `estate_stock` (estate id -> item -> qty),
## `orders_unseen` (deliveries since the phone app was last opened, runtime only). Pure functions on a Game.
##
## order = {id, item, qty, dest ("stash" or estate id), due (Game.total_time), cost, fee, express}


static func rules(g) -> Dictionary:
	return g.data.get("orders", {})


## Everything that can be ordered: raws first, then additives. [{item, name, kind}]
static func catalog(g) -> Array:
	var r: Array = []
	for k in g.data.raws:
		r.append({"item": k, "name": g.data.raws[k].name, "kind": "raw"})
	for k in g.data.additives:
		r.append({"item": k, "name": g.data.additives[k].name, "kind": "additive"})
	return r


## Phone unit price: the cheapest walk-in price anywhere plus the markup. -1 for unknown items.
static func unit_price(g, item: String) -> int:
	var best := -1
	for loc in g.data.locations:
		var p: int = g.buy_price(item, loc)
		if p >= 0 and (best < 0 or p < best):
			best = p
	if best < 0:
		return -1
	return maxi(best + 1, int(ceil(best * (1.0 + float(rules(g).markup)))))


## Where goods can be sent: the hub stash and every estate you own. [{id, name}]
static func destinations(g) -> Array:
	var r: Array = [{"id": "stash", "name": "Hub stash"}]
	for e in g.estates:
		r.append({"id": e, "name": g.data.estates[e].name})
	return r


static func dest_name(g, dest: String) -> String:
	if dest == "stash":
		return "Hub stash"
	return str(g.data.estates.get(dest, {}).get("name", "Hub stash"))


static func quote(g, item: String, qty: int, dest: String, express: bool) -> Dictionary:
	var rl := rules(g)
	var unit := unit_price(g, item)
	if unit < 0:
		return {"ok": false, "msg": "Not on the market."}
	if qty <= 0:
		return {"ok": false, "msg": "Nothing to order."}
	if qty > int(rl.max_qty):
		return {"ok": false, "msg": "At most %d per order." % int(rl.max_qty)}
	if dest != "stash" and not g.estates.has(dest):
		return {"ok": false, "msg": "You don't own that estate."}
	var cost := unit * qty
	var fee := maxi(int(rl.fee_min), int(ceil(cost * float(rl.fee_pct))))
	var secs := float(rl.seconds.standard)
	if express:
		fee = int(ceil(fee * float(rl.express_fee_mult)))
		secs = float(rl.seconds.express)
	if dest != "stash" and g.loc_system(g.data.estates[dest].location) != g.loc_system(str(g.data.start.location)):
		secs += float(rl.far_seconds)
	return {"ok": true, "msg": "", "unit": unit, "cost": cost, "fee": fee, "total": cost + fee, "seconds": secs}


static func place(g, item: String, qty: int, dest: String, express: bool) -> Dictionary:
	if g.state != "playing":
		return {"ok": false, "msg": "Game over."}
	var q := quote(g, item, qty, dest, express)
	if not q.ok:
		return q
	if g.orders.size() >= int(rules(g).max_open):
		return {"ok": false, "msg": "Too many open orders (%d)." % int(rules(g).max_open)}
	if q.total > g.credits:
		return {"ok": false, "msg": "Not enough credits."}
	g.credits -= q.total
	g.order_seq += 1
	g.orders.append({
		"id": g.order_seq, "item": item, "qty": qty, "dest": dest, "due": g.total_time + q.seconds,
		"cost": q.cost, "fee": q.fee, "express": express,
	})
	g._emit("ordered", {"item": item, "qty": qty, "dest": dest, "total": q.total})
	return {"ok": true, "msg": "Ordered %d %s for %d cr (fee %d), arrives in %ds." % [qty, g.item_name(item), q.total, q.fee, int(q.seconds)]}


## Cancel an order in transit: the goods are refunded (cancel_refund), the fee is lost.
static func cancel(g, id: int) -> Dictionary:
	for i in g.orders.size():
		if int(g.orders[i].id) == id:
			var o: Dictionary = g.orders[i]
			var back := int(round(int(o.cost) * float(rules(g).cancel_refund)))
			g.credits += back
			g.orders.remove_at(i)
			g._emit("order_cancelled", {"id": id})
			return {"ok": true, "msg": "Order cancelled, %d cr refunded." % back}
	return {"ok": false, "msg": "No such order."}


## Called from Game.tick: hands over everything that is due.
static func tick(g) -> void:
	if g.orders.is_empty():
		return
	var rest: Array = []
	for o in g.orders:
		if float(o.due) > g.total_time:
			rest.append(o)
			continue
		var dest := str(o.dest)
		var bag: Dictionary = g.stash
		if dest != "stash" and g.estates.has(dest):
			if not g.estate_stock.has(dest):
				g.estate_stock[dest] = {}
			bag = g.estate_stock[dest]
		else:
			dest = "stash"
		g._add(bag, str(o.item), int(o.qty))
		g.orders_unseen += 1
		g._emit("order_delivered", {"item": o.item, "qty": int(o.qty), "dest": dest})
	g.orders = rest


## Moves the stock waiting in an estate into the hub stash so collect_stash() can load it (you must stand inside).
static func unload_estate(g, estate_id: String) -> void:
	var bag: Dictionary = g.estate_stock.get(estate_id, {})
	for k in bag.keys():
		g._add(g.stash, k, int(bag[k]))
	g.estate_stock.erase(estate_id)


static func from_save(g, d: Dictionary) -> void:
	g.orders = []
	for o in d.get("orders", []):
		var item := str(o.get("item", ""))
		if g.data.raws.has(item) or g.data.additives.has(item):
			g.orders.append({
				"id": int(o.id), "item": item, "qty": int(o.qty), "dest": str(o.dest), "due": float(o.due),
				"cost": int(o.cost), "fee": int(o.fee), "express": bool(o.get("express", false)),
			})
	g.order_seq = int(d.get("order_seq", 0))
	for o in g.orders:
		g.order_seq = maxi(g.order_seq, int(o.id))
	g.estate_stock = {}
	var es: Dictionary = d.get("estate_stock", {})
	for e in es:
		if g.estates.has(e):
			g.estate_stock[e] = g._int_dict(es[e])
