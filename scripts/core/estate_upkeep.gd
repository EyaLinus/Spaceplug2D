extends RefCounted
## Estate upkeep and selling (P4). Pure rules on top of Game.estates, no scene dependencies.
## Every bought estate costs `daily(id)` credits at each new day (content.json "upkeep": daily_rate of the price, at
## least min_daily). The ship's bay and starter estates (the rented Old Cannery) are exempt. If the money is there,
## the owed amount (today plus any arrears) is paid automatically. If not, the estate gets one more unpaid day
## (estates[id].unpaid, saved; old saves have none = 0):
##   unpaid >= grace_days -> LOCKED: no entry, no cooking, workers and drones stop until you pay the arrears;
##   unpaid >= seize_days -> SEIZED: the landlord takes the estate, stations, shelf, racks and trays included.
## Selling (on that planet) returns sell_share of the price plus the station refund (data.estate_refund) plus the
## scrap value of its drones, minus the arrears. Both clean up every estate-keyed state through release().

const Drones := preload("res://scripts/core/drones.gd")


static func cfg(g) -> Dictionary:
	return g.data.get("upkeep", {})


## True for estates that pay upkeep (bought ones; not the ship bay, not starter estates).
static func applies(g, id: String) -> bool:
	if cfg(g).is_empty() or not g.estates.has(id) or not g.data.estates.has(id):
		return false
	var e: Dictionary = g.data.estates[id]
	return not e.get("ship", false) and not e.get("starter", false)


## Daily upkeep in credits (0 where it does not apply).
static func daily(g, id: String) -> int:
	if not applies(g, id):
		return 0
	var c := cfg(g)
	return maxi(int(c.min_daily), int(round(float(g.data.estates[id].get("price", 0)) * float(c.daily_rate))))


## Sum of the daily upkeep of all estates you own.
static func daily_total(g) -> int:
	var n := 0
	for id in g.estates:
		n += daily(g, id)
	return n


static func unpaid_days(g, id: String) -> int:
	return int(g.estates.get(id, {}).get("unpaid", 0))


## Amount needed to clear the arrears.
static func arrears(g, id: String) -> int:
	return daily(g, id) * unpaid_days(g, id)


## "ok" | "overdue" (unpaid days, still usable) | "locked" (no entry, no cooking, staff idle).
static func status(g, id: String) -> String:
	var n := unpaid_days(g, id)
	if n <= 0 or not applies(g, id):
		return "ok"
	return "locked" if n >= int(cfg(g).grace_days) else "overdue"


static func locked(g, id: String) -> bool:
	return status(g, id) == "locked"


## Days until the estate is seized if nothing gets paid (-1 while nothing is overdue).
static func days_to_seizure(g, id: String) -> int:
	if status(g, id) == "ok":
		return -1
	return int(cfg(g).seize_days) - unpaid_days(g, id)


## One line for the estate panel ("" for exempt estates).
static func status_text(g, id: String) -> String:
	if not applies(g, id):
		return ""
	match status(g, id):
		"locked":
			return "LOCKED by the landlord: %d cr overdue, seized in %d day(s)." % [arrears(g, id), days_to_seizure(g, id)]
		"overdue":
			return "Upkeep overdue: %d cr. Locked in %d day(s) if unpaid." % [arrears(g, id), int(cfg(g).grace_days) - unpaid_days(g, id)]
	return "Upkeep %d cr a day, paid automatically at dawn." % daily(g, id)


## Called once per new day by Game.
static func new_day(g) -> void:
	if cfg(g).is_empty():
		return
	for id in g.estates.keys():
		if not applies(g, id):
			continue
		var d := daily(g, id)
		var owed: int = d * (unpaid_days(g, id) + 1)
		if g.credits >= owed:
			g.credits -= owed
			g.estates[id].erase("unpaid")
			g.stats["upkeep_paid"] = int(g.stats.get("upkeep_paid", 0)) + owed
			g._emit("upkeep_paid", {"estate": id, "amount": owed})
			continue
		g.estates[id]["unpaid"] = unpaid_days(g, id) + 1
		var name: String = g.data.estates[id].name
		if unpaid_days(g, id) >= int(cfg(g).seize_days):
			seize(g, id)
			_notice(g, "%s was seized by the landlord for unpaid upkeep." % name)
		elif locked(g, id):
			g._emit("upkeep_locked", {"estate": id, "owed": arrears(g, id)})
			_notice(g, "%s is locked: pay %d cr in arrears within %d day(s) or lose it." % [name, arrears(g, id), days_to_seizure(g, id)])
		else:
			g._emit("upkeep_missed", {"estate": id, "days": unpaid_days(g, id)})
			_notice(g, "Couldn't pay the upkeep of %s (%d cr overdue)." % [name, arrears(g, id)])


static func _notice(g, text: String) -> void:
	g._emit("notice", {"text": text, "good": false})


## Late in the day (warn_at share of the day, content.json upkeep.warn_at) warns once if the credits will not cover
## what dawn charges (Game.daily_costs: wages, rent, drones, retainers).
static func evening_check(g) -> void:
	if cfg(g).is_empty() or g.costs_warned_day == g.day:
		return
	if g.day_time < g.day_seconds() * float(cfg(g).get("warn_at", 0.8)):
		return
	g.costs_warned_day = g.day
	var due: int = int(g.daily_costs().total)
	if due > 0 and g.credits < due:
		g._emit("costs_short", {"due": due, "credits": g.credits})
		_notice(g, "Dawn will cost %d cr (wages, rent, drones, officials) and you have %d. Sell something or rent goes unpaid." % [due, g.credits])


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
	g.estates[id].erase("unpaid")
	g.stats["upkeep_paid"] = int(g.stats.get("upkeep_paid", 0)) + a
	g._emit("upkeep_paid", {"estate": id, "amount": a})
	return g._ok("Paid %d cr in arrears for %s." % [a, g.data.estates[id].name])


static func seize(g, id: String) -> void:
	if not g.estates.has(id):
		return
	release(g, id)
	g._emit("estate_seized", {"estate": id})


## Drops the estate and everything stored under its id: shelf/job (inside the estate dict), delivered stock, bench
## tray, drying racks, sealing benches, grow trays and drones; workers go off duty (still on the payroll).
static func release(g, id: String) -> void:
	g.estates.erase(id)
	for d in [g.estate_stock, g.bench, g.drying, g.sealing, g.grow]:
		d.erase(id)
	g.drones = g.drones.filter(func(x): return str(x.estate) != id)
	for w in g.workers:
		if str(w.get("estate", "")) == id:
			w.estate = ""
	if g.inside_estate == id:
		g.inside_estate = ""


## What selling would pay out right now: {share, buildings, drones, arrears, net}.
static func sale_quote(g, id: String) -> Dictionary:
	if not applies(g, id):
		return {"share": 0, "buildings": 0, "drones": 0, "arrears": 0, "net": 0}
	var share := int(round(float(g.data.estates[id].get("price", 0)) * float(cfg(g).get("sell_share", 0.0))))
	var parts := 0
	for b in g.estates[id].buildings:
		parts += int(round(int(g.data.buildables[b.id].cost) * float(g.data.estate_refund)))
	var dr := 0
	var dc: Dictionary = g.data.get("drones", {})
	for d in Drones.at_estate(g, id):
		dr += int(round(int(dc.get("price", 0)) * float(dc.get("scrap_refund", 0.4))))
	var a := arrears(g, id)
	return {"share": share, "buildings": parts, "drones": dr, "arrears": a, "net": maxi(0, share + parts + dr - a)}


static func sell(g, id: String) -> Dictionary:
	if not g.estates.has(id):
		return g._fail("You do not own that property.")
	if not applies(g, id):
		return g._fail("You can't sell that one.")
	var e: Dictionary = g.data.estates[id]
	if g.location != e.location:
		return g._fail("You have to be on %s to hand over the keys." % g.data.locations[e.location].name)
	var q := sale_quote(g, id)
	g.credits += int(q.net)
	release(g, id)
	g._emit("estate_sold", {"estate": id, "net": q.net})
	return g._ok("Sold %s for %d cr (%d property, %d stations, %d drones, -%d arrears)." % [e.name, q.net, q.share, q.buildings, q.drones, q.arrears])
