extends RefCounted
## Workers & HR (B3). Hired staff live in Game.workers ([{id, loyalty, estate, hired_day}]); the people you can hire are
## data (content.json "workers" -> candidates). A worker is assigned to one owned estate:
##  - lab_hand: cooks the estate's auto recipe at the placed stations. Skill drives the station scores
##    (-> yield, grade, heat through Production.outcome) and the cooking time. Takes inputs from the bench; with no
##    stocker in the estate he fetches them from storage himself and is slower (unstocked_time_mult).
##  - stocker: every haul trip moves finished product from the output tray to storage and tops the bench up with what
##    the recipe needs from storage. Skill = units per trip and trip time.
## Estate state (saved with the estate): storage, bench, out (item -> qty), recipe {base, additives, qty}, job.
## Wages are charged each new day; unpaid wages cost loyalty and at 0 loyalty the worker quits.

const Mixing = preload("res://scripts/core/mixing.gd")
const Production = preload("res://scripts/core/production.gd")


static func cfg(g) -> Dictionary:
	return g.data.get("workers", {})


## Fills in the worker fields of an estate dict (old saves and fresh estates).
static func ensure(e: Dictionary) -> void:
	for k in ["storage", "bench", "out", "recipe", "job"]:
		if not e.has(k):
			e[k] = {}
	if not e.has("haul_t"):
		e["haul_t"] = 0.0


static func candidate(g, id: String) -> Dictionary:
	for c in cfg(g).get("candidates", []):
		if c.id == id:
			return c
	return {}


static func find(g, id: String) -> int:
	return find_in(g.workers, id)


static func find_in(list: Array, id: String) -> int:
	for i in list.size():
		if list[i].id == id:
			return i
	return -1


static func hired(g, id: String) -> bool:
	return find(g, id) >= 0


## Candidates that are not on the payroll.
static func available(g) -> Array:
	return cfg(g).get("candidates", []).filter(func(c): return not hired(g, c.id))


static func wage_total(g) -> int:
	var n := 0
	for w in g.workers:
		n += int(candidate(g, w.id).wage)
	return n


static func hire_cost(g, id: String) -> int:
	return int(candidate(g, id).get("wage", 0)) * int(cfg(g).hire_days)


## Worker (state dict) of `role` assigned to the estate, {} if none.
static func at(g, estate_id: String, role: String) -> Dictionary:
	for w in g.workers:
		if w.estate == estate_id and candidate(g, w.id).role == role:
			return w
	return {}


static func hire(g, id: String) -> Dictionary:
	var c := candidate(g, id)
	if c.is_empty() or hired(g, id):
		return g._fail("Not available.")
	if g.workers.size() >= int(cfg(g).max_staff):
		return g._fail("You can't carry more than %d people on the payroll." % int(cfg(g).max_staff))
	var cost := hire_cost(g, id)
	if g.credits < cost:
		return g._fail("Signing %s costs %d cr." % [c.name, cost])
	g.credits -= cost
	g.workers.append({"id": id, "loyalty": float(c.loyalty), "estate": "", "hired_day": g.day})
	g._emit("worker_hired", {"worker": id})
	return g._ok("%s joined the crew (%d cr signing fee)." % [c.name, cost])


static func fire(g, id: String) -> Dictionary:
	var i := find(g, id)
	if i < 0:
		return g._fail("Not on the payroll.")
	g.workers.remove_at(i)
	g._emit("worker_left", {"worker": id, "reason": "fired"})
	return g._ok("%s is gone." % candidate(g, id).name)


## estate_id "" = unassign. One lab hand and one stocker per estate.
static func assign(g, id: String, estate_id: String) -> Dictionary:
	var i := find(g, id)
	if i < 0:
		return g._fail("Not on the payroll.")
	if estate_id != "":
		if not g.estates.has(estate_id):
			return g._fail("You don't own that.")
		var role: String = candidate(g, id).role
		var cur := at(g, estate_id, role)
		if not cur.is_empty() and cur.id != id:
			return g._fail("%s already has a %s." % [g.data.estates[estate_id].name, str(cfg(g).roles[role].name).to_lower()])
	g.workers[i].estate = estate_id
	g._emit("worker_assigned", {"worker": id, "estate": estate_id})
	if estate_id == "":
		return g._ok("%s is off duty." % candidate(g, id).name)
	return g._ok("%s works at %s." % [candidate(g, id).name, g.data.estates[estate_id].name])


## base "" = auto cooking off.
static func set_recipe(g, estate_id: String, base: String, additives: Array, qty: int) -> Dictionary:
	if not g.estates.has(estate_id):
		return g._fail("You don't own that.")
	if base == "":
		g.estates[estate_id].recipe = {}
		g._emit("worker_recipe", {"estate": estate_id})
		return g._ok("Auto cooking off.")
	if not g.data.bases.has(base):
		return g._fail("Unknown product.")
	qty = clampi(qty, 1, g.lab_capacity())
	g.estates[estate_id].recipe = {"base": base, "additives": additives.duplicate(), "qty": qty}
	g._emit("worker_recipe", {"estate": estate_id})
	return g._ok("Auto recipe: %d %s." % [qty, g.data.bases[base].name])


## Moves items from the cargo hold into the estate storage; you have to stand inside.
static func deposit(g, estate_id: String, item: String, qty: int) -> Dictionary:
	if g.inside_estate != estate_id or not g.estates.has(estate_id):
		return g._fail("Go inside the estate first.")
	qty = mini(qty, int(g.cargo.get(item, 0)))
	if qty <= 0:
		return g._fail("Nothing to store.")
	g._add(g.cargo, item, -qty)
	g._add(g.estates[estate_id].storage, item, qty)
	g._emit("storage_changed", {"estate": estate_id})
	return g._ok("Stored %d %s." % [qty, g.item_name(item)])


## Takes finished products (output tray, then storage) into the cargo hold; you have to stand inside.
static func take_products(g, estate_id: String) -> Dictionary:
	if g.inside_estate != estate_id or not g.estates.has(estate_id):
		return g._fail("Go inside the estate first.")
	var e: Dictionary = g.estates[estate_id]
	var moved := 0
	for src in [e.out, e.storage]:
		for k in src.keys():
			if not Mixing.is_product(k):
				continue
			var n := mini(int(src[k]), g.cargo_free())
			if n <= 0:
				continue
			g._add(g.cargo, k, n)
			g._add(src, k, -n)
			moved += n
	if moved == 0:
		return g._fail("Nothing to take, or your hold is full.")
	g._emit("storage_changed", {"estate": estate_id})
	return g._ok("Loaded %d units." % moved)


## Why the estate's lab hand is idle ("" = can run).
static func blocker(g, estate_id: String) -> String:
	var e: Dictionary = g.estates[estate_id]
	if at(g, estate_id, "lab_hand").is_empty():
		return "No lab hand assigned."
	if e.recipe.is_empty():
		return "No recipe set."
	var have: Array = []
	for b in e.buildings:
		have.append(b.id)
	for st in Production.stations_for(g.data, e.recipe.base, e.recipe.additives):
		if not st in have:
			return "Missing station: %s." % g.data.stations[st].name
	return ""


static func tick(g, dt: float) -> void:
	if g.workers.is_empty():
		return
	for id in g.estates:
		var e: Dictionary = g.estates[id]
		ensure(e)
		var hand := at(g, id, "lab_hand")
		var stocker := at(g, id, "stocker")
		if not hand.is_empty():
			_tick_cook(g, id, e, hand, not stocker.is_empty(), dt)
		if not stocker.is_empty():
			var c := candidate(g, stocker.id)
			e.haul_t = float(e.haul_t) + dt
			var trip := float(cfg(g).haul_seconds) / (0.5 + float(c.skill))
			while e.haul_t >= trip:
				e.haul_t -= trip
				_haul(g, e, c)
		else:
			e.haul_t = 0.0


static func _tick_cook(g, id: String, e: Dictionary, hand: Dictionary, stocked: bool, dt: float) -> void:
	if not e.job.is_empty():
		e.job.remaining = float(e.job.remaining) - dt
		if e.job.remaining <= 0.0:
			g._add(e.out, e.job.product, int(e.job.qty))
			g.stats.batches += 1
			g.stats["worker_batches"] = int(g.stats.get("worker_batches", 0)) + 1
			g._emit("worker_batch", {"estate": id, "product": e.job.product, "qty": e.job.qty})
			e.job = {}
		return
	if blocker(g, id) != "":
		return
	var r: Dictionary = e.recipe
	var qty := mini(int(r.qty), g.lab_capacity())
	var need: Dictionary = g.batch_needs(r.base, r.additives, qty)
	var src: Dictionary = e.bench if stocked else e.storage
	for k in need:
		if int(src.get(k, 0)) < need[k]:
			return
	for k in need:
		g._add(src, k, -need[k])
	var skill := float(candidate(g, hand.id).skill)
	var noise := float(cfg(g).score_noise)
	var scores := {}
	for st in Production.stations_for(g.data, r.base, r.additives):
		scores[st] = clampf(skill + g.rng.randf_range(-noise, noise), 0.0, 1.0)
	var res := Production.outcome(g.data, scores)
	var product := Mixing.key(r.base, Mixing.traits_for(g.data, r.base, r.additives), res.grade)
	var t: float = g.batch_seconds(qty) * (float(cfg(g).time_base) - float(cfg(g).time_skill) * skill)
	if not stocked:
		t *= float(cfg(g).unstocked_time_mult)
	e.job = {"product": product, "qty": Production.output_qty(qty, res.yield_mult), "remaining": t, "total": t}
	g.add_heat(float(g.data.heat.per_lab_unit) * qty * g.heat_mult(r.base) * res.heat_mult)


static func _trip_cap(g, c: Dictionary) -> int:
	return int(cfg(g).haul_units_base) + int(round(float(cfg(g).haul_units_skill) * float(c.skill)))


## One trip: output tray -> storage, then storage -> bench (what the recipe still lacks).
static func _haul(g, e: Dictionary, c: Dictionary) -> void:
	var cap := _trip_cap(g, c)
	for k in e.out.keys():
		var n := mini(int(e.out[k]), cap)
		g._add(e.storage, k, n)
		g._add(e.out, k, -n)
		cap -= n
		if cap <= 0:
			break
	if e.recipe.is_empty():
		return
	var need: Dictionary = g.batch_needs(e.recipe.base, e.recipe.additives, mini(int(e.recipe.qty), g.lab_capacity()))
	cap = _trip_cap(g, c)
	for k in need:
		var n := mini(mini(int(need[k]) - int(e.bench.get(k, 0)), int(e.storage.get(k, 0))), cap)
		if n > 0:
			g._add(e.bench, k, n)
			g._add(e.storage, k, -n)
			cap -= n
		if cap <= 0:
			break


## Called from Game._new_day: pays everybody; the unpaid lose loyalty and may quit.
static func new_day(g) -> void:
	var c := cfg(g)
	var paid := 0
	for w in g.workers.duplicate():
		var wage := int(candidate(g, w.id).wage)
		if g.credits >= wage:
			g.credits -= wage
			paid += wage
			w.loyalty = minf(1.0, float(w.loyalty) + float(c.paid_loyalty_gain))
		else:
			w.loyalty = float(w.loyalty) - float(c.unpaid_loyalty_loss)
			g._emit("wage_missed", {"worker": w.id})
			if w.loyalty <= 0.0:
				g.workers.erase(w)
				g._emit("worker_left", {"worker": w.id, "reason": "quit"})
	if paid > 0:
		g.stats["wages"] = int(g.stats.get("wages", 0)) + paid
		g._emit("wages_paid", {"amount": paid})


static func to_save(workers: Array) -> Array:
	return workers.duplicate(true)


static func from_save(g, src: Array) -> Array:
	var r: Array = []
	for w in src:
		var wid := str(w.get("id", ""))
		if candidate(g, wid).is_empty() or find_in(r, wid) >= 0:
			continue
		var est := str(w.get("estate", ""))
		r.append({"id": wid, "loyalty": clampf(float(w.get("loyalty", 0.5)), 0.0, 1.0), "estate": est if g.estates.has(est) else "", "hired_day": int(w.get("hired_day", 1))})
	return r


static func _int_items(src: Dictionary) -> Dictionary:
	var r := {}
	for k in src:
		if int(src[k]) > 0:
			r[k] = int(src[k])
	return r


## Restores the worker fields of one estate from a save (missing in old saves = empty).
static func load_estate(src: Dictionary, e: Dictionary) -> void:
	ensure(e)
	for k in ["storage", "bench", "out"]:
		e[k] = _int_items(src.get(k, {}))
	var rc: Dictionary = src.get("recipe", {})
	e.recipe = {} if rc.is_empty() else {"base": str(rc.get("base", "")), "additives": Array(rc.get("additives", [])), "qty": int(rc.get("qty", 1))}
	var j: Dictionary = src.get("job", {})
	e.job = {} if j.is_empty() else {"product": str(j.product), "qty": int(j.qty), "remaining": float(j.remaining), "total": float(j.total)}
	e.haul_t = float(src.get("haul_t", 0.0))
