extends RefCounted
## Night curfew on planet surfaces (P3). Between `start` and `end` (clock hours) the Authority puts extra officers on
## the street and they see further. A bribe buys a short pass: during it the curfew bonus is off. Numbers: content.json
## -> "curfew". Runtime only: `g.curfew_pass_until` (total_time) is not saved.

const People = preload("res://scripts/core/people.gd")
const Deals = preload("res://scripts/core/deals.gd")


static func rules(g) -> Dictionary:
	return g.data.get("curfew", {})


## True while the clock is inside the curfew window (wraps midnight).
static func active(g) -> bool:
	var r := rules(g)
	if r.is_empty():
		return false
	var h := People.hour(g)
	var a := float(r.get("start", 22.0))
	var b := float(r.get("end", 5.0))
	return (h >= a or h < b) if a > b else (h >= a and h < b)


## A bribe pass is running.
static func passed(g) -> bool:
	return g.total_time < float(g.get("curfew_pass_until"))


## Curfew bonus applies right now (curfew hours, no pass).
static func enforced(g) -> bool:
	return active(g) and not passed(g)


## Extra officers on a surface with police factor `security` (lawless planets get none).
static func extra_officers(g, security: float) -> int:
	if security <= 0.0 or not enforced(g):
		return 0
	return int(rules(g).get("extra_officers", 0))


static func vision_mult(g) -> float:
	return float(rules(g).get("vision_mult", 1.0)) if enforced(g) else 1.0


static func bribe_cost(g) -> int:
	var r := rules(g)
	return int(float(r.get("bribe_base", 0)) + float(r.get("bribe_per_heat", 0)) * g.heat)


## Pay an officer for a pass; also cools heat a little.
static func bribe(g) -> Dictionary:
	if not enforced(g):
		return g._fail("No curfew to buy your way out of.")
	var cost := bribe_cost(g)
	if cost > g.credits:
		return g._fail("Not enough credits.")
	g.credits -= cost
	g.curfew_pass_until = g.total_time + float(rules(g).get("pass_hours", 3.0)) * Deals.seconds_per_hour(g)
	g.heat = maxf(0.0, g.heat - float(rules(g).get("bribe_heat_cut", 0.0)))
	g._emit("curfew_bribe", {"cost": cost})
	return g._ok("Paid %d cr. The patrol looks the other way for a while." % cost)
