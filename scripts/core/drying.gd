extends RefCounted
## Drying Table (P4): a production building that cures finished product over game time. A load of units goes on the
## rack, takes `seconds` of game time, then comes off one quality grade higher but lighter (`weight_keep` of the
## units survive). Only the bases in `bases` can be cured (weed) and only below `max_grade`. Racks hold `capacity`
## units per table; the estate's racks are shared by all its tables.
## State: Game.drying (saved) = estate id -> [{"product": key, "qty": int, "left": secs, "total": secs}].
## Numbers: content.json "drying". Static helpers over a Game, no autoloads (unit tests run without them).

const Mixing = preload("res://scripts/core/mixing.gd")

const TABLE := "drying_table"


static func cfg(g) -> Dictionary:
	return g.data.get("drying", {})


static func tables(g, estate: String) -> int:
	var n := 0
	for b in g.estates.get(estate, {}).get("buildings", []):
		if b.id == TABLE:
			n += 1
	return n


static func capacity(g, estate: String) -> int:
	return tables(g, estate) * int(cfg(g).get("capacity", 20))


static func batches(g, estate: String) -> Array:
	return g.drying.get(estate, [])


static func loaded(g, estate: String) -> int:
	var n := 0
	for b in batches(g, estate):
		n += int(b.qty)
	return n


## True when this product can go on the rack: a cure-able base that is below the top grade.
static func can_dry(g, product: String) -> bool:
	if not Mixing.is_product(product):
		return false
	var p := Mixing.parse_key(product)
	return p.base in cfg(g).get("bases", []) and int(p.grade) < int(cfg(g).get("max_grade", 3))


## Product key the batch turns into, and how many units survive.
static func result_key(product: String) -> String:
	var p := Mixing.parse_key(product)
	return Mixing.key(p.base, p.traits, int(p.grade) + 1)


static func result_qty(g, qty: int) -> int:
	return maxi(1, int(floor(float(qty) * float(cfg(g).get("weight_keep", 0.8)))))


## Cure-able products in the hold: [{product, qty}].
static func candidates(g) -> Array:
	var r: Array = []
	for k in g.cargo:
		if can_dry(g, k) and int(g.cargo[k]) > 0:
			r.append({"product": k, "qty": int(g.cargo[k])})
	return r


static func load_rack(g, estate: String, product: String, qty: int) -> Dictionary:
	if not g.estates.has(estate) or tables(g, estate) == 0:
		return g._fail("No drying table here.")
	if not can_dry(g, product):
		return g._fail("That can't be cured any further.")
	qty = mini(qty, int(g.cargo.get(product, 0)))
	if qty <= 0:
		return g._fail("You don't have that in your hold.")
	var room := capacity(g, estate) - loaded(g, estate)
	if room <= 0:
		return g._fail("The racks are full.")
	qty = mini(qty, room)
	g._add(g.cargo, product, -qty)
	if not g.drying.has(estate):
		g.drying[estate] = []
	var secs := float(cfg(g).get("seconds", 120))
	g.drying[estate].append({"product": product, "qty": qty, "left": secs, "total": secs})
	g._emit("drying_loaded", {"estate": estate, "product": product, "qty": qty})
	return g._ok("%d %s on the rack." % [qty, g.item_name(product)])


static func tick(g, dt: float) -> void:
	for e in g.drying:
		for b in g.drying[e]:
			b.left = maxf(0.0, float(b.left) - dt)


static func ready(g, estate: String) -> int:
	var n := 0
	for b in batches(g, estate):
		if float(b.left) <= 0.0:
			n += result_qty(g, int(b.qty))
	return n


## Takes every finished batch off the rack into the hold; what does not fit stays on the rack.
static func collect(g, estate: String) -> Dictionary:
	if not g.estates.has(estate):
		return g._fail("Not your place.")
	var moved := 0
	var keep: Array = []
	for b in batches(g, estate):
		if float(b.left) > 0.0:
			keep.append(b)
			continue
		var out := result_qty(g, int(b.qty))
		var n := mini(out, g.cargo_free())
		if n <= 0:
			keep.append(b)
			continue
		g._add(g.cargo, result_key(b.product), n)
		moved += n
		if n < out:
			b.qty = maxi(1, int(ceil(float(b.qty) * float(out - n) / float(out))))
			keep.append(b)
	if moved == 0:
		return g._fail("Nothing is dry yet." if ready(g, estate) == 0 else "Cargo hold is full.")
	g.drying[estate] = keep
	if keep.is_empty():
		g.drying.erase(estate)
	g._emit("drying_collected", {"estate": estate, "qty": moved})
	return g._ok("Took %d cured units off the rack." % moved)


## Taking the last table down is blocked while the rack still holds something.
static func can_remove(g, estate: String) -> bool:
	return tables(g, estate) > 1 or batches(g, estate).is_empty()


static func to_save(g) -> Dictionary:
	return g.drying.duplicate(true)


static func from_save(g, d: Dictionary) -> void:
	g.drying = {}
	for e in d:
		if not g.estates.has(e) or not d[e] is Array:
			continue
		var list: Array = []
		for b in d[e]:
			if not b is Dictionary or not can_dry(g, str(b.get("product", ""))):
				continue
			var total := maxf(float(b.get("total", cfg(g).get("seconds", 120))), 1.0)
			list.append({"product": str(b.product), "qty": maxi(int(b.get("qty", 1)), 1),
				"left": clampf(float(b.get("left", 0.0)), 0.0, total), "total": total})
		if not list.is_empty():
			g.drying[e] = list
