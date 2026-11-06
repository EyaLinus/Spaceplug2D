extends RefCounted
## Price board history: what a plain batch of each drug fetched per unit at every location, one point per day.
## State in Game.price_history (saved): {location: {base: [price, ...]}}, oldest first, capped at CAP points.
## Points are the start-of-day prices (demand x base value, no contact premiums). Old saves start their history now.
## No autoload references (unit tests run without autoloads).

const Mixing = preload("res://scripts/core/mixing.gd")
const CAP := 14


static func cap(data: Dictionary) -> int:
	return clampi(int(data.get("market", {}).get("history_days", CAP)), 2, 60)


## Plain-batch price of a drug at a location right now, -1 where nobody buys it.
static func price_now(g, loc: String, base: String) -> int:
	var d: float = float(g.demand.get(loc, {}).get(base, 0.0))
	if d <= 0.0 or not g.data.bases.has(base):
		return -1
	var b: Dictionary = g.data.bases[base]
	return int(round(Mixing.value(g.data, Mixing.key(base, [b.innate])) * d))


## Append today's price for every location/drug that buys; drop the oldest beyond the cap.
static func record(g) -> void:
	var n := cap(g.data)
	for loc in g.demand:
		for base in g.demand[loc]:
			var p := price_now(g, loc, str(base))
			if p < 0:
				continue
			if not g.price_history.has(loc):
				g.price_history[loc] = {}
			var arr: Array = g.price_history[loc].get(base, [])
			arr.append(p)
			while arr.size() > n:
				arr.pop_front()
			g.price_history[loc][base] = arr


## Stored points, oldest first; with_now adds the live price as the last point.
static func series(g, loc: String, base: String, with_now := false) -> Array:
	var arr: Array = (g.price_history.get(loc, {}).get(base, []) as Array).duplicate()
	if with_now:
		var p := price_now(g, loc, base)
		if p >= 0:
			arr.append(p)
	return arr


## Change of the latest point against the one before (0 with fewer than two points).
static func trend(arr: Array) -> int:
	return int(arr[-1]) - int(arr[-2]) if arr.size() >= 2 else 0


## [{loc, series, now, trend, low, high}] best current price first, for one drug.
static func board(g, base: String) -> Array:
	var rows: Array = []
	for loc in g.demand:
		var s := series(g, loc, base, true)
		if s.is_empty():
			continue
		var st := series(g, loc, base)
		rows.append({"loc": loc, "series": s, "now": int(s[-1]), "trend": trend(s), "low": int(s.min()), "high": int(s.max()), "days": st.size()})
	rows.sort_custom(func(a, b): return a.now > b.now)
	return rows


static func to_save(g) -> Dictionary:
	return g.price_history.duplicate(true)


## Junk-tolerant: unknown locations/drugs and non-numbers are dropped, length is capped.
static func from_save(g, d) -> void:
	g.price_history = {}
	if not d is Dictionary:
		return
	var n := cap(g.data)
	for loc in d:
		if not g.demand.has(loc) or not d[loc] is Dictionary:
			continue
		for base in d[loc]:
			if not g.demand[loc].has(base) or not d[loc][base] is Array:
				continue
			var arr: Array = []
			for v in d[loc][base]:
				if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
					arr.append(maxi(0, int(v)))
			arr = arr.slice(maxi(0, arr.size() - n))
			if not arr.is_empty():
				if not g.price_history.has(loc):
					g.price_history[loc] = {}
				g.price_history[loc][base] = arr
