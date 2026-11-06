extends RefCounted
## Price board: what you have seen things cost where. Per location and per good (raw/additive buy price, plain-batch
## sell value per product) at most one observation per game day, capped to the last N days (content.json "price_board").
## State in Game.price_board (saved): {loc: {"buy:<item>" | "sell:<base>": [[day, price], ...]}}, oldest first.
## Purely informational: nothing here touches the economy or the RNG. No autoload references (unit tests run headless).

const Mixing = preload("res://scripts/core/mixing.gd")
const SPARK := "▁▂▃▄▅▆▇█"


static func cfg(data: Dictionary) -> Dictionary:
	var c: Dictionary = data.get("price_board", {})
	return {"history_days": maxi(1, int(c.get("history_days", 14))), "spark_days": maxi(2, int(c.get("spark_days", 8))),
		"flat_pct": float(c.get("flat_pct", 0.02))}


static func key_buy(item: String) -> String:
	return "buy:" + item


static func key_sell(base: String) -> String:
	return "sell:" + base


## Notes today's prices at `loc` (every good it trades). Returns the number of new entries; 0 if already noted today.
static func observe(g, loc: String) -> int:
	var ld: Dictionary = g.loc_data(loc)
	if ld.is_empty():
		return 0
	var cap: int = cfg(g.data).history_days
	var n := 0
	var at: Dictionary = g.price_board.get(loc, {})
	var items: Array = g.data.raws.keys() + g.data.additives.keys()
	for it in items:
		var p: int = g.buy_price(it, loc)
		if p >= 0 and _push(at, key_buy(it), g.day, p, cap):
			n += 1
	for b in g.data.bases:
		var d: float = float(g.demand.get(loc, {}).get(b, 0.0))
		if d > 0.0:
			var v := Mixing.value(g.data, Mixing.key(b, [g.data.bases[b].innate]))
			if _push(at, key_sell(b), g.day, int(round(v * d)), cap):
				n += 1
	if not at.is_empty():
		g.price_board[loc] = at
	return n


static func _push(at: Dictionary, key: String, day: int, price: int, cap: int) -> bool:
	var h: Array = at.get(key, [])
	if not h.is_empty() and int(h[h.size() - 1][0]) >= day:
		return false
	h.append([day, price])
	while h.size() > cap:
		h.pop_front()
	at[key] = h
	return true


## History [[day, price], ...] (oldest first) of a good at a location; [] when never seen.
static func history(g, loc: String, key: String) -> Array:
	return g.price_board.get(loc, {}).get(key, [])


## -1 falling, 0 steady / unknown, 1 rising: newest vs the observation before it, beyond cfg.flat_pct.
static func trend(g, loc: String, key: String) -> int:
	var h := history(g, loc, key)
	if h.size() < 2:
		return 0
	var a := float(h[h.size() - 2][1])
	var b := float(h[h.size() - 1][1])
	if absf(b - a) <= maxf(a, 1.0) * cfg(g.data).flat_pct:
		return 0
	return 1 if b > a else -1


static func arrow(t: int) -> String:
	return "▲" if t > 0 else ("▼" if t < 0 else "▬")


## Block-character sparkline of the last `n` observations (empty string below 2 points).
static func sparkline(h: Array, n: int) -> String:
	if h.size() < 2:
		return ""
	var tail: Array = h.slice(maxi(0, h.size() - n))
	var lo := INF
	var hi := -INF
	for e in tail:
		lo = minf(lo, float(e[1]))
		hi = maxf(hi, float(e[1]))
	var s := ""
	for e in tail:
		var i := 3 if hi <= lo else int(round((float(e[1]) - lo) / (hi - lo) * 7.0))
		s += SPARK[clampi(i, 0, 7)]
	return s


## Last `n` observations as "day 4: 120 cr" lines for a tooltip.
static func lines(h: Array, n: int) -> String:
	var out: Array = []
	for e in h.slice(maxi(0, h.size() - n)):
		out.append("day %d: %d cr" % [int(e[0]), int(e[1])])
	return "\n".join(out)


static func to_save(g) -> Dictionary:
	return g.price_board.duplicate(true)


## Tolerates anything: unknown locations or goods, non-array histories, junk entries are dropped; entries are sorted
## by day, de-duplicated per day and capped.
static func from_save(g, d) -> void:
	g.price_board = {}
	if not d is Dictionary:
		return
	var cap: int = cfg(g.data).history_days
	for loc in d:
		if not g.data.locations.has(loc) or not d[loc] is Dictionary:
			continue
		var at := {}
		for key in d[loc]:
			var ks := str(key).split(":")
			if ks.size() != 2 or not (ks[0] == "buy" or ks[0] == "sell") or not d[loc][key] is Array:
				continue
			if (ks[0] == "buy" and not (g.data.raws.has(ks[1]) or g.data.additives.has(ks[1]))) or (ks[0] == "sell" and not g.data.bases.has(ks[1])):
				continue
			var h: Array = []
			for e in d[loc][key]:
				if e is Array and e.size() == 2 and (e[0] is int or e[0] is float) and (e[1] is int or e[1] is float):
					h.append([int(e[0]), int(e[1])])
			h.sort_custom(func(a, b): return a[0] < b[0])
			var clean: Array = []
			for e in h:
				if clean.is_empty() or clean[clean.size() - 1][0] != e[0]:
					clean.append(e)
			while clean.size() > cap:
				clean.pop_front()
			if not clean.is_empty():
				at[str(key)] = clean
		if not at.is_empty():
			g.price_board[str(loc)] = at
