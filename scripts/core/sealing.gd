extends RefCounted
## Sealing Bench (P4): a production building that re-wraps finished product into a packaging tier (Sealed / Shielded,
## data.packaging.tiers) over game time. Its own input (Loose product from the hold) and output (packed units
## waiting on the bench) inventory, per estate. The pack tier is part of the product key ("weed:glow@2#2", see
## Mixing.key), so packed units stack separately in the hold and keep their grade and traits.
## Each tier has a wrap cost per unit and a duration (content.json "sealing.offers"). The bench holds `capacity`
## units per bench; an estate's benches share the load. Unlike the Packaging Table minigame station (which sets
## the tier of a fresh batch), this works on product you already have.
## State: Game.sealing (saved) = estate id -> [{"product": loose key, "qty": int, "tier": int, "left": secs, "total": secs}].
## Static helpers over a Game, no autoloads (unit tests run without them).

const Mixing = preload("res://scripts/core/mixing.gd")

const BENCH := "seal_bench"


static func cfg(g) -> Dictionary:
	return g.data.get("sealing", {})


static func benches(g, estate: String) -> int:
	var n := 0
	for b in g.estates.get(estate, {}).get("buildings", []):
		if b.id == BENCH:
			n += 1
	return n


static func capacity(g, estate: String) -> int:
	return benches(g, estate) * int(cfg(g).get("capacity", 30))


static func batches(g, estate: String) -> Array:
	return g.sealing.get(estate, [])


static func loaded(g, estate: String) -> int:
	var n := 0
	for b in batches(g, estate):
		n += int(b.qty)
	return n


## The offer for a tier ({tier, seconds, cost}) or {} when the bench does not wrap that tier.
static func offer(g, tier: int) -> Dictionary:
	var tier_count: int = g.data.get("packaging", {}).get("tiers", []).size()
	if tier <= 0 or tier >= tier_count:
		return {}
	for o in cfg(g).get("offers", []):
		if int(o.tier) == tier:
			return o
	return {}


static func offers(g) -> Array:
	var r: Array = []
	for o in cfg(g).get("offers", []):
		if not offer(g, int(o.tier)).is_empty():
			r.append(o)
	return r


## True for a finished product that is still Loose.
static func can_seal(product: String) -> bool:
	return Mixing.is_product(product) and int(Mixing.parse_key(product).pack) == 0


static func result_key(product: String, tier: int) -> String:
	var p := Mixing.parse_key(product)
	return Mixing.key(p.base, p.traits, int(p.grade), tier)


## Loose products in the hold: [{product, qty}].
static func candidates(g) -> Array:
	var r: Array = []
	for k in g.cargo:
		if can_seal(k) and int(g.cargo[k]) > 0:
			r.append({"product": k, "qty": int(g.cargo[k])})
	return r


static func wrap_cost(g, tier: int, qty: int) -> int:
	return int(offer(g, tier).get("cost", 0)) * qty


static func load_bench(g, estate: String, product: String, qty: int, tier: int) -> Dictionary:
	if not g.estates.has(estate) or benches(g, estate) == 0:
		return g._fail("No sealing bench here.")
	var o := offer(g, tier)
	if o.is_empty():
		return g._fail("The bench can't wrap that.")
	if not can_seal(product):
		return g._fail("That is already packed.")
	qty = mini(qty, int(g.cargo.get(product, 0)))
	if qty <= 0:
		return g._fail("You don't have that in your hold.")
	var room := capacity(g, estate) - loaded(g, estate)
	if room <= 0:
		return g._fail("The bench is full.")
	qty = mini(qty, room)
	var unit := int(o.cost)
	if unit > 0:
		qty = mini(qty, floori(float(g.credits) / float(unit)))
	if qty <= 0:
		return g._fail("You can't pay for the wrap.")
	g.credits -= unit * qty
	g._add(g.cargo, product, -qty)
	if not g.sealing.has(estate):
		g.sealing[estate] = []
	var secs := float(o.seconds)
	g.sealing[estate].append({"product": product, "qty": qty, "tier": tier, "left": secs, "total": secs})
	g._emit("sealing_loaded", {"estate": estate, "product": product, "qty": qty, "tier": tier})
	return g._ok("%d %s on the bench (%d cr wrap)." % [qty, g.item_name(product), unit * qty])


static func tick(g, dt: float) -> void:
	for e in g.sealing:
		for b in g.sealing[e]:
			b.left = maxf(0.0, float(b.left) - dt)


static func ready(g, estate: String) -> int:
	var n := 0
	for b in batches(g, estate):
		if float(b.left) <= 0.0:
			n += int(b.qty)
	return n


## Takes every finished pack into the hold; what does not fit stays on the bench.
static func collect(g, estate: String) -> Dictionary:
	if not g.estates.has(estate):
		return g._fail("Not your place.")
	var moved := 0
	var keep: Array = []
	for b in batches(g, estate):
		if float(b.left) > 0.0:
			keep.append(b)
			continue
		var n := mini(int(b.qty), g.cargo_free())
		if n <= 0:
			keep.append(b)
			continue
		g._add(g.cargo, result_key(b.product, int(b.tier)), n)
		moved += n
		if n < int(b.qty):
			b.qty = int(b.qty) - n
			keep.append(b)
	if moved == 0:
		return g._fail("Nothing is packed yet." if ready(g, estate) == 0 else "Cargo hold is full.")
	g.sealing[estate] = keep
	if keep.is_empty():
		g.sealing.erase(estate)
	g._emit("sealing_collected", {"estate": estate, "qty": moved})
	return g._ok("Took %d packed units off the bench." % moved)


## Taking the last bench down is blocked while it still holds something.
static func can_remove(g, estate: String) -> bool:
	return benches(g, estate) > 1 or batches(g, estate).is_empty()


static func to_save(g) -> Dictionary:
	return g.sealing.duplicate(true)


static func from_save(g, d: Dictionary) -> void:
	g.sealing = {}
	for e in d:
		if not g.estates.has(e) or not d[e] is Array:
			continue
		var list: Array = []
		for b in d[e]:
			if not b is Dictionary:
				continue
			var product := str(b.get("product", ""))
			var tier := int(b.get("tier", 0))
			if not can_seal(product) or not g.data.bases.has(str(Mixing.parse_key(product).base)) or offer(g, tier).is_empty():
				continue
			var total := maxf(float(b.get("total", offer(g, tier).seconds)), 1.0)
			list.append({"product": product, "qty": maxi(int(b.get("qty", 1)), 1), "tier": tier,
				"left": clampf(float(b.get("left", 0.0)), 0.0, total), "total": total})
		if not list.is_empty():
			g.sealing[e] = list
