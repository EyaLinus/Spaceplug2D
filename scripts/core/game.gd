extends RefCounted
## Headless game simulation: economy, lab, heat, debt and progression.
## No Node/scene dependencies, so tests and balance sims run without a window.
## UI and world scripts read the public fields and call the action methods; every action returns
## {"ok": bool, "msg": String} and emits `event(kind, payload)` so the EventBus can relay it.

signal event(kind: String, payload: Dictionary)

const Mixing = preload("res://scripts/core/mixing.gd")
const Production = preload("res://scripts/core/production.gd")
const SAVE_VERSION := 1

var data: Dictionary
var rng := RandomNumberGenerator.new()

var credits: int = 0
var debt: int = 0
var debt_due_day: int = 10
var day: int = 1
var day_time: float = 0.0
var total_time: float = 0.0
var heat: float = 0.0
var location: String = ""  ## location id while docked, "" while flying
var cargo: Dictionary = {}  ## item key -> qty (raw ids, additive ids, product keys)
var stash: Dictionary = {}  ## finished lab output waiting at the hub
var lab_queue: Array = []  ## [{product, qty, remaining, total}]
var demand: Dictionary = {}  ## location -> base -> multiplier
var contact_ready_at: Dictionary = {}  ## contact id -> total_time when they buy again
var upgrades: Dictionary = {"cargo": 0, "engine": 0, "stealth": 0, "lab": 0}
var state: String = "playing"  ## playing | won | lost
var stats: Dictionary = {"earned": 0, "units_sold": 0, "busts": 0, "batches": 0}
var estates: Dictionary = {}  ## owned estate id -> {"buildings": [{"id": station id, "x": int, "y": int}]}


func new_game(content: Dictionary, seed_value: int = 1) -> void:
	data = content
	rng.seed = seed_value
	var s: Dictionary = data.start
	credits = int(s.credits)
	debt = int(s.debt)
	debt_due_day = int(s.debt_due_day)
	day = 1
	day_time = 0.0
	total_time = 0.0
	heat = 0.0
	location = s.location
	cargo = s.get("cargo", {}).duplicate()
	stash = {}
	lab_queue = []
	contact_ready_at = {}
	upgrades = {"cargo": 0, "engine": 0, "stealth": 0, "lab": 0}
	state = "playing"
	stats = {"earned": 0, "units_sold": 0, "busts": 0, "batches": 0}
	estates = {}
	demand = {}
	for loc in data.locations:
		demand[loc] = {}
		for b in data.locations[loc].demand:
			demand[loc][b] = float(data.locations[loc].demand[b])


# ---------------------------------------------------------------- queries

func loc_data(loc: String = location) -> Dictionary:
	return data.locations.get(loc, {})


func cargo_used() -> int:
	var n := 0
	for k in cargo:
		n += int(cargo[k])
	return n


func cargo_capacity() -> int:
	return int(data.upgrades.cargo.levels[upgrades.cargo])


func cargo_free() -> int:
	return cargo_capacity() - cargo_used()


func lab_capacity() -> int:
	return int(data.upgrades.lab.levels[upgrades.lab])


func engine_mult() -> float:
	return float(data.upgrades.engine.levels[upgrades.engine])


func stealth() -> float:
	return float(data.upgrades.stealth.levels[upgrades.stealth])


func scan_radius() -> float:
	return float(data.heat.scan_radius) * (1.0 - stealth())


func patrol_count() -> int:
	var h: Dictionary = data.heat
	return mini(int(h.patrol_base) + int(heat / float(h.patrol_per_heat)), int(h.patrol_max))


## Reach Authority officers walking a planet surface. security: the surface's police factor (0 = lawless).
func police_on_foot(security: float) -> int:
	var p: Dictionary = data.police
	var n := int(floor((float(p.base) + heat / float(p.per_heat)) * security))
	return clampi(n, 0, int(p.max))


func has_contraband() -> bool:
	for k in cargo:
		if Mixing.is_product(k) and int(cargo[k]) > 0:
			return true
	return false


func item_name(item_key: String) -> String:
	if Mixing.is_product(item_key):
		return Mixing.display_name(data, item_key)
	if data.raws.has(item_key):
		return data.raws[item_key].name
	if data.additives.has(item_key):
		return data.additives[item_key].name
	return item_key


func contacts_at(loc: String = location) -> Array:
	var r: Array = []
	for c in data.contacts:
		if c.location == loc:
			r.append(c)
	return r


func contact(id: String) -> Dictionary:
	for c in data.contacts:
		if c.id == id:
			return c
	return {}


func contact_ready(id: String) -> bool:
	return total_time >= float(contact_ready_at.get(id, 0.0))


## Price per unit for selling `product_key` here, to a contact (id) or the fence ("").
func sell_price(product_key: String, contact_id: String = "", loc: String = location) -> int:
	var p := Mixing.parse_key(product_key)
	var v := Mixing.value(data, product_key) * float(demand.get(loc, {}).get(p.base, 0.0))
	if contact_id == "":
		return int(round(v * float(data.market.fence_ratio)))
	var c := contact(contact_id)
	v *= float(c.get("budget_mult", 1.0))
	if p.traits.has(c.get("likes", "")):
		v *= 1.0 + float(data.market.liked_trait_bonus)
	return int(round(v))


## Stronger drugs draw more attention: heat from cooking and selling scales with the product tier.
func heat_mult(base: String) -> float:
	return float(data.bases.get(base, {}).get("heat_mult", 1.0))


func upgrade_cost(key: String) -> int:
	var costs: Array = data.upgrades[key].costs
	var lvl: int = upgrades[key]
	return -1 if lvl >= costs.size() else int(costs[lvl])


func batch_seconds(qty: int) -> float:
	var l: Dictionary = data.lab
	var speed: float = 1.0 + float(l.speed_per_level) * upgrades.lab
	return (float(l.base_seconds) + float(l.seconds_per_unit) * qty) / speed


func day_seconds() -> float:
	return float(data.time.day_seconds)


# ---------------------------------------------------------------- simulation

func tick(dt: float) -> void:
	if state != "playing":
		return
	total_time += dt
	day_time += dt
	var decay := float(data.heat.decay_per_second) * dt
	if location != "":
		decay *= float(data.heat.decay_docked_factor)
	_set_heat(heat - decay)
	_tick_lab(dt)
	_tick_demand(dt)
	while day_time >= day_seconds():
		day_time -= day_seconds()
		_new_day()


func _tick_lab(dt: float) -> void:
	if lab_queue.is_empty():
		return
	var job: Dictionary = lab_queue[0]
	job.remaining -= dt
	if job.remaining <= 0.0:
		lab_queue.pop_front()
		_add(stash, job.product, job.qty)
		stats.batches += 1
		_emit("lab_done", {"product": job.product, "qty": job.qty})


func _tick_demand(dt: float) -> void:
	var rec := float(data.market.recovery_per_second) * dt
	for loc in demand:
		for b in demand[loc]:
			var target := float(data.locations[loc].demand[b])
			var cur: float = demand[loc][b]
			demand[loc][b] = minf(cur + rec, target) if cur < target else maxf(cur - rec, target)


func _new_day() -> void:
	day += 1
	# market rumour: one demand shifts noticeably each day
	var locs: Array = []
	for loc in demand:
		if not demand[loc].is_empty():
			locs.append(loc)
	if not locs.is_empty():
		var loc: String = locs[rng.randi() % locs.size()]
		var bases: Array = demand[loc].keys()
		var b: String = bases[rng.randi() % bases.size()]
		var m := float(data.market.max_demand)
		demand[loc][b] = clampf(demand[loc][b] + rng.randf_range(-0.15, 0.25), float(data.market.min_demand), m)
		_emit("rumour", {"location": loc, "base": b, "demand": demand[loc][b]})
	_emit("new_day", {"day": day})
	if debt > 0 and day > debt_due_day:
		state = "lost"
		_emit("game_over", {"won": false})


func _set_heat(v: float) -> void:
	var old := heat
	heat = clampf(v, 0.0, float(data.heat.max))
	if int(old / 25.0) != int(heat / 25.0):
		_emit("heat_level", {"heat": heat})


func add_heat(v: float) -> void:
	_set_heat(heat + v)


# ---------------------------------------------------------------- actions

func dock(loc: String) -> Dictionary:
	var ld := loc_data(loc)
	if ld.is_empty() or not ld.get("dockable", true):
		return _fail("Cannot dock there.")
	location = loc
	_emit("docked", {"location": loc})
	return _ok("Docked at %s." % ld.name)


func undock() -> Dictionary:
	if location == "":
		return _fail("Not docked.")
	var loc := location
	location = ""
	_emit("undocked", {"location": loc})
	return _ok("Undocked.")


func buy(item: String, qty: int) -> Dictionary:
	if location == "":
		return _fail("Dock first.")
	var price := buy_price(item)
	if price < 0:
		return _fail("Not sold here.")
	if qty <= 0:
		return _fail("Nothing to buy.")
	if qty > cargo_free():
		return _fail("Not enough cargo space.")
	if price * qty > credits:
		return _fail("Not enough credits.")
	credits -= price * qty
	_add(cargo, item, qty)
	_emit("bought", {"item": item, "qty": qty, "cost": price * qty})
	return _ok("Bought %d %s for %d cr." % [qty, item_name(item), price * qty])


## Unit price of a raw or additive at the current location, -1 when not on offer.
func buy_price(item: String, loc: String = location) -> int:
	var ld := loc_data(loc)
	if ld.is_empty():
		return -1
	if ld.sells_raw.has(item):
		return int(ld.sells_raw[item])
	if ld.get("sells_additives", false) and data.additives.has(item):
		return int(data.additives[item].price)
	return -1


## Validates a batch without changing anything (the lab UI runs this before the station minigames start).
func check_batch(base: String, additives: Array, qty: int) -> Dictionary:
	if not loc_data().get("lab", false):
		return _fail("No lab here.")
	if not data.bases.has(base):
		return _fail("Unknown product.")
	if qty <= 0 or qty > lab_capacity():
		return _fail("Rig holds %d units per batch." % lab_capacity())
	if lab_queue.size() >= 3:
		return _fail("Lab queue is full.")
	var need := batch_needs(base, additives, qty)
	for k in need:
		if int(cargo.get(k, 0)) < need[k]:
			return _fail("Missing %s (need %d)." % [item_name(k), need[k]])
	return _ok("Ready.")


func batch_needs(base: String, additives: Array, qty: int) -> Dictionary:
	var need := {data.bases[base].raw: qty}
	for a in additives:
		need[a] = int(need.get(a, 0)) + qty
	return need


## scores: station id -> 0..1 from the station minigames (see Production). Empty = quick batch, Standard grade.
func start_batch(base: String, additives: Array, qty: int, scores: Dictionary = {}) -> Dictionary:
	var chk := check_batch(base, additives, qty)
	if not chk.ok:
		return chk
	var need := batch_needs(base, additives, qty)
	for k in need:
		_add(cargo, k, -need[k])
	var res := Production.outcome(data, scores)
	var out_qty := Production.output_qty(qty, res.yield_mult)
	var product := Mixing.key(base, Mixing.traits_for(data, base, additives), res.grade)
	var t := batch_seconds(qty)
	lab_queue.append({"product": product, "qty": out_qty, "remaining": t, "total": t})
	add_heat(float(data.heat.per_lab_unit) * qty * heat_mult(base) * res.heat_mult)
	_emit("lab_started", {"product": product, "qty": out_qty, "grade": res.grade})
	var extra := ""
	if out_qty != qty:
		extra = " (%+d from prep work)" % (out_qty - qty)
	return _ok("Cooking %d %s%s." % [out_qty, item_name(product), extra])


func collect_stash() -> Dictionary:
	if not loc_data().get("lab", false):
		return _fail("Your stash is at the hub.")
	if stash.is_empty():
		return _fail("Stash is empty.")
	var moved := 0
	for k in stash.keys():
		var n := mini(int(stash[k]), cargo_free())
		if n <= 0:
			break
		_add(cargo, k, n)
		_add(stash, k, -n)
		moved += n
	if moved == 0:
		return _fail("Cargo hold is full.")
	_emit("collected", {"qty": moved})
	return _ok("Loaded %d units." % moved)


func sell(product_key: String, qty: int, contact_id: String = "") -> Dictionary:
	if location == "":
		return _fail("Dock first.")
	if not Mixing.is_product(product_key) or int(cargo.get(product_key, 0)) < qty or qty <= 0:
		return _fail("You don't have that.")
	var p := Mixing.parse_key(product_key)
	if not demand.get(location, {}).has(p.base):
		return _fail("Nobody here buys %s." % data.bases[p.base].name)
	if contact_id == "":
		if not loc_data().get("fence", false):
			return _fail("No fence here.")
	else:
		var c := contact(contact_id)
		if c.is_empty() or c.location != location:
			return _fail("Contact isn't here.")
		if not contact_ready(contact_id):
			return _fail("%s isn't buying yet." % c.name)
		if qty > int(c.max_units):
			return _fail("%s takes at most %d." % [c.name, c.max_units])
	var total := 0
	for i in qty:
		total += sell_price(product_key, contact_id)
		demand[location][p.base] = maxf(demand[location][p.base] - float(data.market.saturation_per_unit), float(data.market.min_demand))
	_add(cargo, product_key, -qty)
	credits += total
	stats.earned += total
	stats.units_sold += qty
	if contact_id != "":
		contact_ready_at[contact_id] = total_time + float(data.market.contact_cooldown)
	add_heat(float(loc_data().heat_per_unit) * qty * heat_mult(p.base))
	_emit("sold", {"product": product_key, "qty": qty, "credits": total, "contact": contact_id})
	return _ok("Sold %d for %d cr." % [qty, total])


func buy_upgrade(key: String) -> Dictionary:
	if not loc_data().get("shipyard", false):
		return _fail("No shipyard here.")
	var cost := upgrade_cost(key)
	if cost < 0:
		return _fail("Already maxed.")
	if cost > credits:
		return _fail("Not enough credits.")
	credits -= cost
	upgrades[key] += 1
	_emit("upgraded", {"key": key, "level": upgrades[key]})
	return _ok("%s upgraded to Mk %d." % [data.upgrades[key].name, upgrades[key] + 1])


func pay_debt(amount: int) -> Dictionary:
	if not loc_data().get("office", false):
		return _fail("The Consortium office is on Mireth.")
	amount = mini(mini(amount, debt), credits)
	if amount <= 0:
		return _fail("Nothing to pay.")
	credits -= amount
	debt -= amount
	_emit("debt_paid", {"amount": amount, "debt": debt})
	if debt == 0 and state == "playing":
		state = "won"
		_emit("game_over", {"won": true})
	return _ok("Paid %d cr. Debt left: %d cr." % [amount, debt])


func bribe_cost(heat_amount: float) -> int:
	return int(ceil(minf(heat_amount, heat) * float(data.heat.bribe_credits_per_heat)))


func bribe(heat_amount: float) -> Dictionary:
	if not loc_data().get("office", false):
		return _fail("Only the Mireth fixer takes bribes.")
	var cost := bribe_cost(heat_amount)
	if cost <= 0:
		return _fail("No heat to clear.")
	if cost > credits:
		return _fail("Not enough credits.")
	credits -= cost
	_set_heat(heat - minf(heat_amount, heat))
	_emit("bribed", {"cost": cost})
	return _ok("Paid %d cr. Heat cooled down." % cost)


## Caught by a patrol scan: products are confiscated, a fine is paid and heat drops.
func bust() -> Dictionary:
	var lost := 0
	for k in cargo.keys():
		if Mixing.is_product(k):
			lost += int(cargo[k])
			cargo.erase(k)
	var h: Dictionary = data.heat
	var fine := mini(credits, maxi(int(h.bust_fine_min), int(credits * float(h.bust_fine_ratio))))
	credits -= fine
	stats.busts += 1
	_set_heat(heat - float(h.bust_heat_drop))
	_emit("busted", {"lost": lost, "fine": fine})
	return _ok("Busted! Lost %d units and paid %d cr." % [lost, fine])


# ---------------------------------------------------------------- estates

func estate_owned(id: String) -> bool:
	return estates.has(id)


func buy_estate(id: String) -> Dictionary:
	if not data.estates.has(id):
		return _fail("Unknown property.")
	var e: Dictionary = data.estates[id]
	if estates.has(id):
		return _fail("You already own %s." % e.name)
	if location != e.location:
		return _fail("You have to be on %s to sign for it." % data.locations[e.location].name)
	if credits < int(e.price):
		return _fail("%s costs %d cr." % [e.name, int(e.price)])
	credits -= int(e.price)
	estates[id] = {"buildings": []}
	_emit("estate_bought", {"estate": id})
	return _ok("You own %s now. Go inside and set up production." % e.name)


## The door cell (bottom middle) stays free so you can always get in and out.
func estate_door(id: String) -> Vector2i:
	var size: Array = data.estates[id].size
	return Vector2i(int(size[0]) / 2, int(size[1]) - 1)


func building_rect(b: Dictionary) -> Rect2i:
	var size: Array = data.buildables[b.id].size
	return Rect2i(int(b.x), int(b.y), int(size[0]), int(size[1]))


func can_place(estate_id: String, station: String, x: int, y: int) -> bool:
	if not estates.has(estate_id) or not data.buildables.has(station):
		return false
	var size: Array = data.estates[estate_id].size
	var r := building_rect({"id": station, "x": x, "y": y})
	if not Rect2i(0, 0, int(size[0]), int(size[1])).encloses(r) or r.has_point(estate_door(estate_id)):
		return false
	for b in estates[estate_id].buildings:
		if building_rect(b).intersects(r):
			return false
	return true


func place_building(estate_id: String, station: String, x: int, y: int) -> Dictionary:
	if not estates.has(estate_id):
		return _fail("You don't own that.")
	if not data.buildables.has(station):
		return _fail("Can't build that.")
	if not can_place(estate_id, station, x, y):
		return _fail("No room there.")
	var cost := int(data.buildables[station].cost)
	if credits < cost:
		return _fail("%s costs %d cr." % [data.stations[station].name, cost])
	credits -= cost
	estates[estate_id].buildings.append({"id": station, "x": x, "y": y})
	_emit("building_placed", {"estate": estate_id, "station": station})
	return _ok("%s set up." % data.stations[station].name)


func remove_building(estate_id: String, index: int) -> Dictionary:
	if not estates.has(estate_id) or index < 0 or index >= estates[estate_id].buildings.size():
		return _fail("Nothing to remove.")
	var b: Dictionary = estates[estate_id].buildings[index]
	var refund := int(round(int(data.buildables[b.id].cost) * float(data.estate_refund)))
	estates[estate_id].buildings.remove_at(index)
	credits += refund
	_emit("building_removed", {"estate": estate_id, "station": b.id})
	return _ok("%s taken down, sold the parts for %d cr." % [data.stations[b.id].name, refund])


# ---------------------------------------------------------------- save / load

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "credits": credits, "debt": debt, "debt_due_day": debt_due_day,
		"day": day, "day_time": snappedf(day_time, 0.01), "total_time": snappedf(total_time, 0.01),
		"heat": snappedf(heat, 0.01), "location": location, "cargo": cargo.duplicate(), "stash": stash.duplicate(),
		"lab_queue": lab_queue.duplicate(true), "demand": demand.duplicate(true),
		"contact_ready_at": contact_ready_at.duplicate(), "upgrades": upgrades.duplicate(),
		"state": state, "stats": stats.duplicate(), "rng_state": str(rng.state), "estates": estates.duplicate(true),
	}


func from_dict(content: Dictionary, d: Dictionary) -> void:
	new_game(content)
	credits = int(d.get("credits", credits))
	debt = int(d.get("debt", debt))
	debt_due_day = int(d.get("debt_due_day", debt_due_day))
	day = int(d.get("day", 1))
	day_time = float(d.get("day_time", 0.0))
	total_time = float(d.get("total_time", 0.0))
	heat = float(d.get("heat", 0.0))
	location = str(d.get("location", ""))
	cargo = _int_dict(_migrate_keys(d.get("cargo", {})))
	stash = _int_dict(_migrate_keys(d.get("stash", {})))
	lab_queue = []
	for j in d.get("lab_queue", []):
		lab_queue.append({"product": _migrate_key(j.product), "qty": int(j.qty), "remaining": float(j.remaining), "total": float(j.total)})
	for loc in d.get("demand", {}):
		if demand.has(loc):
			for b in d.demand[loc]:
				var nb: String = RENAMED.get(b, b)
				if demand[loc].has(nb):
					demand[loc][nb] = float(d.demand[loc][b])
	contact_ready_at = d.get("contact_ready_at", {}).duplicate()
	for k in upgrades:
		upgrades[k] = int(d.get("upgrades", {}).get(k, 0))
	state = str(d.get("state", "playing"))
	for k in stats:
		stats[k] = int(d.get("stats", {}).get(k, 0))
	for e in d.get("estates", {}):
		if data.estates.has(e):
			var list: Array = []
			for b in d.estates[e].get("buildings", []):
				list.append({"id": str(b.id), "x": int(b.x), "y": int(b.y)})
			estates[e] = {"buildings": list}
	if d.has("rng_state"):
		rng.state = int(d.rng_state)


## v0.1.0 used invented names; map them to the v0.1.1 drug ladder so old saves keep their cargo.
const RENAMED := {"sporegel": "cannabis", "cryoshard": "coca_leaf", "driftglow": "weed", "shardlight": "cocaine"}


static func _migrate_key(k: String) -> String:
	var parts := k.split(":")
	parts[0] = RENAMED.get(parts[0], parts[0])
	return ":".join(parts)


static func _migrate_keys(src: Dictionary) -> Dictionary:
	var r := {}
	for k in src:
		r[_migrate_key(k)] = src[k]
	return r


static func _int_dict(src: Dictionary) -> Dictionary:
	var r := {}
	for k in src:
		if int(src[k]) > 0:
			r[k] = int(src[k])
	return r


# ---------------------------------------------------------------- helpers

static func _add(dict: Dictionary, k: String, n: int) -> void:
	var v := int(dict.get(k, 0)) + n
	if v <= 0:
		dict.erase(k)
	else:
		dict[k] = v


func _emit(kind: String, payload: Dictionary) -> void:
	event.emit(kind, payload)


func _ok(msg: String) -> Dictionary:
	return {"ok": true, "msg": msg}


func _fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}
