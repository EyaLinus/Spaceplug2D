extends RefCounted
## Grow trays (P4): a production building as a core entity. An estate you own can hold a few trays; plant a raw
## (seeds leave the hold), water it on the days it grows, harvest it into the stash once ripe.
## Growth is counted in game days (Game.day). Care = watered days / growth days (0..1) is the quality; the harvest
## yield scales between content.json grow.min_yield_factor (never watered) and 1.0 (watered every day).
## State in Game.grow (saved): estate id -> {"trays": [{"raw": "" (empty) or raw id, "start_day": int,
## "watered": [days]}]}. No autoload references (unit tests run without autoloads).


const Workers = preload("res://scripts/core/workers.gd")

## Stash raws that were not grown (no entry in Game.grow_q) count as this quality.
const UNGRADED_Q := 0.5


static func cfg(g) -> Dictionary:
	return g.data.get("grow", {})


static func crops(g) -> Dictionary:
	return cfg(g).get("crops", {})


static func trays(g, estate: String) -> Array:
	return g.grow.get(estate, {}).get("trays", [])


static func max_trays(g) -> int:
	return int(cfg(g).get("max_trays", 4))


## Buys one more empty tray for an estate you own.
static func build_tray(g, estate: String) -> Dictionary:
	if not g.estates.has(estate):
		return _res(false, "You don't own that.")
	if not g.estate_reachable(estate):
		return _res(false, "You can only fit out the cargo bay while docked.")
	if trays(g, estate).size() >= max_trays(g):
		return _res(false, "No room for more than %d grow trays." % max_trays(g))
	var cost := int(cfg(g).get("tray_cost", 0))
	if g.credits < cost:
		return _res(false, "A grow tray costs %d cr." % cost)
	g.credits -= cost
	if not g.grow.has(estate):
		g.grow[estate] = {"trays": []}
	g.grow[estate].trays.append({"raw": "", "start_day": 0, "watered": []})
	g._emit("grow_changed", {"estate": estate})
	return _res(true, "Grow tray set up.")


static func _tray(g, estate: String, i: int) -> Dictionary:
	var t := trays(g, estate)
	return t[i] if i >= 0 and i < t.size() else {}


## Plants `raw` in an empty tray; the seed stock comes out of the cargo hold.
static func plant(g, estate: String, i: int, raw: String) -> Dictionary:
	var t := _tray(g, estate, i)
	if t.is_empty():
		return _res(false, "No such tray.")
	if t.raw != "":
		return _res(false, "This tray is already growing.")
	if not crops(g).has(raw):
		return _res(false, "That can't be grown.")
	var need := int(cfg(g).get("seed_qty", 1))
	if int(g.cargo.get(raw, 0)) < need:
		return _res(false, "Needs %d %s in your hold." % [need, g.data.raws[raw].name])
	g._add(g.cargo, raw, -need)
	t.raw = raw
	t.start_day = g.day
	t.watered = []
	g._emit("grow_changed", {"estate": estate})
	return _res(true, "%s planted." % g.data.raws[raw].name)


## Waters a growing tray; once per game day counts.
static func water(g, estate: String, i: int) -> Dictionary:
	var t := _tray(g, estate, i)
	if t.is_empty() or t.raw == "":
		return _res(false, "Nothing is growing there.")
	if is_ripe(g, t):
		return _res(false, "Already ripe, harvest it.")
	if (t.watered as Array).has(g.day):
		return _res(false, "Watered already today.")
	t.watered.append(g.day)
	g._emit("grow_changed", {"estate": estate})
	return _res(true, "Watered.")


static func days_left(g, t: Dictionary) -> int:
	if t.raw == "":
		return 0
	return maxi(0, int(crops(g)[t.raw].days) - (g.day - int(t.start_day)))


static func is_ripe(g, t: Dictionary) -> bool:
	return t.raw != "" and days_left(g, t) <= 0


## Quality 0..1 = share of the growth days that were watered.
static func quality(g, t: Dictionary) -> float:
	if t.raw == "":
		return 0.0
	return clampf(float((t.watered as Array).size()) / float(crops(g)[t.raw].days), 0.0, 1.0)


static func grade(q: float) -> String:
	return "prime" if q >= 0.85 else ("good" if q >= 0.5 else "poor")


## Grade of the grown raw pile in the stash ("" if nothing grown is left there).
static func stash_grade(g, raw: String) -> String:
	if not g.grow_q.has(raw) or int(g.stash.get(raw, 0)) <= 0:
		return ""
	return grade(float(g.grow_q[raw]))


## What the estate room draws: one entry per tray, progress 0..1 (1 = ripe), grade of the care so far.
static func visuals(g, estate: String) -> Array:
	var out: Array = []
	for t in trays(g, estate):
		var d := {"raw": t.raw, "progress": 0.0, "ripe": false, "grade": ""}
		if t.raw != "":
			var days := float(crops(g)[t.raw].days)
			d.progress = clampf((days - days_left(g, t)) / days, 0.0, 1.0)
			d.ripe = is_ripe(g, t)
			d.grade = grade(quality(g, t))
		out.append(d)
	return out


static func expected_yield(g, t: Dictionary) -> int:
	if t.raw == "":
		return 0
	var lo := float(cfg(g).get("min_yield_factor", 0.5))
	return maxi(1, int(round(float(crops(g)[t.raw]["yield"]) * lerpf(lo, 1.0, quality(g, t)))))


## Harvests a ripe tray into the stash (collect it at the lab like finished product).
static func harvest(g, estate: String, i: int) -> Dictionary:
	var t := _tray(g, estate, i)
	if t.is_empty() or t.raw == "":
		return _res(false, "Nothing is growing there.")
	if not is_ripe(g, t):
		return _res(false, "Not ripe yet: %d day(s) to go." % days_left(g, t))
	var q := quality(g, t)
	var n := expected_yield(g, t)
	var raw: String = t.raw
	var old_n := int(g.stash.get(raw, 0))
	var old_q := float(g.grow_q.get(raw, UNGRADED_Q))
	g.grow_q[raw] = (old_q * old_n + q * n) / float(old_n + n)  # quality of the stash pile = weighted mean
	g._add(g.stash, raw, n)
	t.raw = ""
	t.start_day = 0
	t.watered = []
	g._emit("grow_harvested", {"estate": estate, "raw": raw, "qty": n, "grade": grade(q)})
	return _res(true, "Harvested %d %s (%s)." % [n, g.data.raws[raw].name, grade(q)])


## Botanist (worker role "botanist", P5): every dawn, in the estate he is assigned to (unless it is locked for rent),
## harvests ripe trays into the estate storage shelf (where the lab hand / stocker pick raws up), replants empty trays
## from that shelf (the same crop, or the auto recipe's raw / the most stocked growable raw for a fresh tray), and waters every growing tray. Skill sets how often he forgets a tray
## (miss chance = (1 - skill) x grow.botanist_miss; deterministic per estate/tray/day, the game RNG is untouched).
## Raws harvested into storage are ungraded (grow_q only tracks the hub stash pile). Returns trays watered.
static func tend(g) -> int:
	var watered := 0
	for estate in g.grow:
		if not g.estates.has(estate) or g.estate_locked(estate):
			continue
		var b := Workers.at(g, estate, "botanist")
		if b.is_empty():
			continue
		var e: Dictionary = g.estates[estate]
		Workers.ensure(e)
		var skill := float(Workers.candidate(g, b.id).get("skill", 0.5))
		var miss := (1.0 - skill) * float(cfg(g).get("botanist_miss", 0.4))
		var list := trays(g, estate)
		for i in list.size():
			var t: Dictionary = list[i]
			var last := ""
			if is_ripe(g, t):
				last = t.raw
				var n := expected_yield(g, t)
				g._add(e.storage, last, n)
				t.raw = ""
				t.start_day = 0
				t.watered = []
				g._emit("grow_harvested", {"estate": estate, "raw": last, "qty": n, "grade": "", "worker": b.id})
			if t.raw == "":
				var crop := last if last != "" else _pick_crop(g, e)
				var need := int(cfg(g).get("seed_qty", 1))
				if crop != "" and int(e.storage.get(crop, 0)) >= need:
					g._add(e.storage, crop, -need)
					t.raw = crop
					t.start_day = g.day
					t.watered = []
			if t.raw != "" and not is_ripe(g, t) and not (t.watered as Array).has(g.day):
				var roll := float(hash("%s|%d|%d" % [estate, i, g.day]) % 1000) / 1000.0
				if roll >= miss:
					t.watered.append(g.day)
					watered += 1
		g._emit("grow_changed", {"estate": estate})
	return watered


## Crop a botanist plants in an empty tray: the raw of the estate's auto recipe if it grows, else the growable raw
## the storage shelf holds most of ("" = nothing to plant).
static func _pick_crop(g, e: Dictionary) -> String:
	var r: Dictionary = e.get("recipe", {})
	if not r.is_empty() and g.data.bases.has(r.base):
		var raw: String = g.data.bases[r.base].raw
		if crops(g).has(raw) and int(e.storage.get(raw, 0)) >= int(cfg(g).get("seed_qty", 1)):
			return raw
	var best := ""
	for raw in crops(g):
		if int(e.storage.get(raw, 0)) > int(e.storage.get(best, 0)):
			best = raw
	return best


static func to_save(g) -> Dictionary:
	return g.grow.duplicate(true)


static func quality_to_save(g) -> Dictionary:
	return g.grow_q.duplicate()


## Old saves have no "grow": nobody owns a tray. Unknown estates and crops are dropped.
static func from_save(g, d: Dictionary) -> void:
	g.grow = {}
	g.grow_q = {}
	var gq: Dictionary = d.get("grow_q", {})
	for raw in gq:
		if crops(g).has(raw):
			g.grow_q[raw] = clampf(float(gq[raw]), 0.0, 1.0)
	var src: Dictionary = d.get("grow", {})
	for e in src:
		if not g.estates.has(e):
			continue
		var list: Array = []
		for t in src[e].get("trays", []):
			var raw := str(t.get("raw", ""))
			if raw != "" and not crops(g).has(raw):
				raw = ""
			var w: Array = []
			for day in t.get("watered", []):
				w.append(int(day))
			list.append({"raw": raw, "start_day": int(t.get("start_day", 0)), "watered": w if raw != "" else []})
			if list.size() >= max_trays(g):
				break
		g.grow[e] = {"trays": list}


static func _res(ok: bool, msg: String) -> Dictionary:
	return {"ok": ok, "msg": msg}
