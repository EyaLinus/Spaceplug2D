extends RefCounted
## B4 "everyone is someone": the people who walk around each planet are generated named customers. Rules and name
## pools in content.json "locals"; each becomes a normal contact (data.contacts, flag `local`) with a drug preference,
## liked trait, budget and a day schedule over the planet's spots. Generation is seeded per planet, so every run and
## every save sees the same people. Unknown until you talk to them or someone refers you. No scene deps.

const LOOKS := ["npc_teal", "npc_red", "npc_purple", "npc_rust", "npc_green", "npc_slate", "npc_sky", "npc_pink"]


## Appends the generated locals to data.contacts (once). Called by Data.load_all.
static func add_to(data: Dictionary) -> void:
	if data.get("locals", {}).is_empty() or data.get("_locals_added", false):
		return
	data["_locals_added"] = true
	var all: Array = data.contacts
	all.append_array(generate(data))


static func generate(data: Dictionary) -> Array:
	var rl: Dictionary = data.locals
	var taken := {}
	for c in data.get("contacts", []):
		if not c.get("local", false):  # story contacts keep their names
			taken[c.name] = true
	var out: Array = []
	for loc in rl.get("count", {}):
		var spots: Array = data.get("surfaces", {}).get(loc, {}).get("spots", {}).keys()
		if spots.size() < 3:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("locals:" + loc)
		var demand: Dictionary = data.locations[loc].get("demand", {})
		var weights := {}  ## cheap drugs are the most common habit; the planet's demand tilts it
		for base in demand:
			weights[base] = float(rl.get("prefer_weights", {}).get(base, 1.0)) * float(demand[base])
		for i in int(rl.count[loc]):
			var name := _unique_name(rl, loc, rng, taken)
			var prefers: Array = [_pick(rng, weights, "weed")]
			if rng.randf() < 0.3:
				var second := _pick(rng, weights, prefers[0])
				if not prefers.has(second):
					prefers.append(second)
			var budget := rng.randi_range(int(rl.budget[0]), int(rl.budget[1]))
			out.append({
				"id": "%s_local_%d" % [loc, i + 1], "name": name, "location": loc, "local": true,
				"likes": data.traits.keys()[rng.randi() % data.traits.size()],
				"max_units": rng.randi_range(int(rl.max_units[0]), int(rl.max_units[1])),
				"budget_mult": snappedf(rng.randf_range(float(rl.budget_mult[0]), float(rl.budget_mult[1])), 0.01),
				"look": LOOKS[rng.randi() % LOOKS.size()],
				"job": rl.jobs[loc][rng.randi() % rl.jobs[loc].size()],
				"bio": rl.moods[rng.randi() % rl.moods.size()],
				"prefers": prefers, "budget": int(round(budget / 10.0)) * 10,
				"addiction": snappedf(rng.randf_range(float(rl.addiction[0]), float(rl.addiction[1])), 0.01),
				"affinity": snappedf(rng.randf_range(float(rl.affinity[0]), float(rl.affinity[1])), 0.01),
				"known": false, "schedule": schedule(rng, spots),
			})
	return out


## A day in four parts over distinct spots: home at night, then three places; the hours shift per person so someone
## is always on the way somewhere.
static func schedule(rng: RandomNumberGenerator, spots: Array) -> Array:
	var pool := spots.duplicate()
	var picks: Array = []
	for k in 4:
		var j := rng.randi() % pool.size()
		picks.append(pool[j])
		if pool.size() > 1:
			pool.remove_at(j)
	var wake := rng.randi_range(5, 8)
	var sleep := rng.randi_range(20, 23)
	var a := rng.randi_range(wake + 3, wake + 5)
	var b := rng.randi_range(a + 3, mini(a + 6, sleep - 2))
	return [
		{"from": sleep, "to": wake, "place": picks[0]},
		{"from": wake, "to": a, "place": picks[1]},
		{"from": a, "to": b, "place": picks[2]},
		{"from": b, "to": sleep, "place": picks[3]},
	]


## Surface npc entries (same shape as surfaces.json "npcs") for the locals of `loc`.
static func npcs_for(data: Dictionary, loc: String) -> Array:
	var r: Array = []
	for c in data.get("contacts", []):
		if c.get("local", false) and c.location == loc:
			var spot: Array = data.surfaces[loc].spots[c.schedule[0].place]
			r.append({"id": c.id, "name": c.name, "pos": spot, "action": "deal", "contact": c.id, "local": true,
				"color": "#%s" % Color.from_hsv(float(hash(c.id) % 360) / 360.0, 0.35, 0.85).to_html(false)})
	return r


static func _unique_name(rl: Dictionary, loc: String, rng: RandomNumberGenerator, taken: Dictionary) -> String:
	var firsts: Array = rl.first[loc]
	var lasts: Array = rl.last[loc]
	for tries in 50:
		var n := "%s %s" % [firsts[rng.randi() % firsts.size()], lasts[rng.randi() % lasts.size()]]
		if not taken.has(n):
			taken[n] = true
			return n
	return "%s %d" % [firsts[0], taken.size()]


static func _pick(rng: RandomNumberGenerator, weights: Dictionary, fallback: String) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var x := rng.randf() * total
	for k in weights:
		x -= float(weights[k])
		if x <= 0.0:
			return k
	return fallback
