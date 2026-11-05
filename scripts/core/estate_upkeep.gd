extends RefCounted
## Estate upkeep and selling (P4). Pure rules on top of Game.estates, no scene dependencies.
## Every owned estate costs `daily(id)` credits at each new day (data.upkeep: daily_rate of the price, at least
## min_daily). If the money is there, the owed amount (today plus any arrears) is paid automatically. If not, the
## estate gets one more unpaid day (estates[id].unpaid, saved; old saves have none = 0):
##   unpaid >= grace_days -> LOCKED: you cannot go inside or cook there until you pay the arrears;
##   unpaid >= seize_days -> SEIZED: the landlord takes the estate, buildings included, no refund.
## Selling returns sell_share of the price plus the building refund (data.estate_refund) minus the arrears.
## The stash and cargo are global (hub stash), so nothing is stored inside an estate that could be lost.


static func cfg(g) -> Dictionary:
	return g.data.get("upkeep", {})


## Daily upkeep in credits (0 for unknown or unowned estates, or when the content has no upkeep block).
static func daily(g, id: String) -> int:
	if not g.estates.has(id) or not g.data.estates.has(id) or cfg(g).is_empty():
		return 0
	var c := cfg(g)
	return maxi(int(c.min_daily), int(round(float(g.data.estates[id].price) * float(c.daily_rate))))


static func unpaid_days(g, id: String) -> int:
	return int(g.estates.get(id, {}).get("unpaid", 0))


## Amount needed to clear the arrears (days that went unpaid, not counting today's).
static func arrears(g, id: String) -> int:
	return daily(g, id) * unpaid_days(g, id)


## "ok" | "overdue" (unpaid days, still usable) | "locked" (no entry, no cooking).
static func status(g, id: String) -> String:
	var n := unpaid_days(g, id)
	if n <= 0 or cfg(g).is_empty():
		return "ok"
	return "locked" if n >= int(cfg(g).grace_days) else "overdue"


static func locked(g, id: String) -> bool:
	return status(g, id) == "locked"


## Days until the estate is seized if nothing gets paid (-1 while nothing is overdue).
static func days_to_seizure(g, id: String) -> int:
	if unpaid_days(g, id) <= 0 or cfg(g).is_empty():
		return -1
	return int(cfg(g).seize_days) - unpaid_days(g, id)


## Called once per new day by Game.
static func new_day(g) -> void:
	if cfg(g).is_empty():
		return
	for id in g.estates.keys():
		var d := daily(g, id)
		var owed: int = d * (unpaid_days(g, id) + 1)
		if g.credits >= owed:
			g.credits -= owed
			g.estates[id]["unpaid"] = 0
			g._emit("upkeep_paid", {"estate": id, "amount": owed})
			continue
		g.estates[id]["unpaid"] = unpaid_days(g, id) + 1
		if unpaid_days(g, id) >= int(cfg(g).seize_days):
			seize(g, id)
		elif locked(g, id):
			g._emit("upkeep_locked", {"estate": id, "owed": d * unpaid_days(g, id)})
		else:
			g._emit("upkeep_missed", {"estate": id, "days": unpaid_days(g, id)})


## Pay the arrears by hand (e.g. to unlock). Today's upkeep is still taken at the next new day.
static func pay_arrears(g, id: String) -> Dictionary:
	if not g.estates.has(id):
		return g._fail("You do not own that property.")
	var a := arrears(g, id)
	if a <= 0:
		return g._fail("Nothing overdue.")
	if g.credits < a:
		return g._fail("The arrears are %d cr." % a)
	g.credits -= a
	g.estates[id]["unpaid"] = 0
	g._emit("upkeep_paid", {"estate": id, "amount": a})
	return g._ok("Paid %d cr in arrears for %s." % [a, g.data.estates[id].name])


static func seize(g, id: String) -> void:
	if not g.estates.has(id):
		return
	g.estates.erase(id)
	if g.inside_estate == id:
		g.inside_estate = ""
	g._emit("estate_seized", {"estate": id})


## What selling would pay out right now: {share, buildings, arrears, net}.
static func sale_quote(g, id: String) -> Dictionary:
	if not g.estates.has(id):
		return {"share": 0, "buildings": 0, "arrears": 0, "net": 0}
	var share := int(round(float(g.data.estates[id].price) * float(cfg(g).get("sell_share", 0.0))))
	var parts := 0
	for b in g.estates[id].buildings:
		parts += int(round(int(g.data.buildables[b.id].cost) * float(g.data.estate_refund)))
	var a := arrears(g, id)
	return {"share": share, "buildings": parts, "arrears": a, "net": maxi(0, share + parts - a)}


static func sell(g, id: String) -> Dictionary:
	if not g.estates.has(id):
		return g._fail("You do not own that property.")
	var e: Dictionary = g.data.estates[id]
	if g.location != e.location:
		return g._fail("You have to be on %s to hand over the keys." % g.data.locations[e.location].name)
	var q := sale_quote(g, id)
	g.credits += int(q.net)
	g.estates.erase(id)
	if g.inside_estate == id:
		g.inside_estate = ""
	g._emit("estate_sold", {"estate": id, "net": q.net})
	return g._ok("Sold %s for %d cr (%d for the property, %d for the stations, %d arrears)." % [e.name, q.net, q.share, q.buildings, q.arrears])
