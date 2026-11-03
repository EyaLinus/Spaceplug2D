extends RefCounted
## Ground combat rules, headless. State lives on Game (hp, weapons, weapon, ammo, cooldown, reload_left, since_hit);
## everything here is a static function over a Game plus pure geometry for bullets, so tests need no scene.
## Numbers: content.json -> "combat". The surface only moves bullets and officers and calls these.

const Mixing = preload("res://scripts/core/mixing.gd")
const PLAYER_BULLET := "player"
const OFFICER_BULLET := "officer"


static func cfg(data: Dictionary) -> Dictionary:
	return data.get("combat", {})


static func weapon(data: Dictionary, id: String) -> Dictionary:
	return cfg(data).get("weapons", {}).get(id, {})


static func weapon_ids(data: Dictionary) -> Array:
	return cfg(data).get("weapons", {}).keys()


# ---------------------------------------------------------------- player state (on Game)

static func max_hp(g) -> float:
	return float(cfg(g.data).get("player", {}).get("hp", 100))


## Fresh state for a new game: full health, start weapons with full magazines, first one equipped.
static func init(g) -> void:
	g.hp = max_hp(g)
	g.weapons = cfg(g.data).get("start_weapons", ["pistol"]).duplicate()
	g.weapon = g.weapons[0] if not g.weapons.is_empty() else ""
	g.ammo = {}
	for id in g.weapons:
		g.ammo[id] = int(weapon(g.data, id).get("mag", 0))
	g.cooldown = 0.0
	g.reload_left = 0.0
	g.since_hit = 999.0


static func to_save(g) -> Dictionary:
	return {"hp": snappedf(g.hp, 0.01), "weapons": g.weapons.duplicate(), "weapon": g.weapon, "ammo": g.ammo.duplicate()}


## Old saves have no "combat" key: they keep the fresh state from init(). Unknown weapons are dropped.
static func from_save(g, d: Dictionary) -> void:
	init(g)
	var c: Dictionary = d.get("combat", {})
	if c.is_empty():
		return
	g.hp = clampf(float(c.get("hp", g.hp)), 1.0, max_hp(g))
	var owned: Array = []
	for id in c.get("weapons", []):
		if not weapon(g.data, str(id)).is_empty() and not owned.has(str(id)):
			owned.append(str(id))
	if not owned.is_empty():
		g.weapons = owned
	g.weapon = str(c.get("weapon", g.weapons[0]))
	if not g.weapons.has(g.weapon):
		g.weapon = g.weapons[0]
	g.ammo = {}
	for id in g.weapons:
		var mag := int(weapon(g.data, id).get("mag", 0))
		g.ammo[id] = clampi(int(c.get("ammo", {}).get(id, mag)), 0, mag)


static func owns(g, id: String) -> bool:
	return g.weapons.has(id)


static func tick(g, dt: float) -> void:
	g.cooldown = maxf(0.0, g.cooldown - dt)
	g.since_hit += dt
	if g.reload_left > 0.0:
		g.reload_left = maxf(0.0, g.reload_left - dt)
		if g.reload_left == 0.0:
			g.ammo[g.weapon] = int(weapon(g.data, g.weapon).mag)
			g._emit("reloaded", {"weapon": g.weapon})
	var p: Dictionary = cfg(g.data).get("player", {})
	if g.hp < max_hp(g) and g.since_hit >= float(p.get("regen_delay", 6.0)):
		g.hp = minf(max_hp(g), g.hp + float(p.get("regen_per_second", 4.0)) * dt)


static func buy_weapon(g, id: String) -> Dictionary:
	var w := weapon(g.data, id)
	if w.is_empty():
		return g._fail("Unknown weapon.")
	if owns(g, id):
		return g._fail("You already own the %s." % w.name)
	var price := int(w.price)
	if g.credits < price:
		return g._fail("The %s costs %d cr." % [w.name, price])
	g.credits -= price
	g.weapons.append(id)
	g.ammo[id] = int(w.mag)
	g._emit("weapon_bought", {"weapon": id, "price": price})
	return g._ok("Bought the %s for %d cr." % [w.name, price])


static func select(g, id: String) -> Dictionary:
	if not owns(g, id):
		return g._fail("You do not own that weapon.")
	if id != g.weapon:
		g.weapon = id
		g.reload_left = 0.0  # swapping cancels a reload
		g.cooldown = minf(g.cooldown, 0.2) + 0.2
	return g._ok("%s ready." % weapon(g.data, id).name)


## Cycle to the next/previous owned weapon (mouse wheel).
static func cycle(g, step: int) -> void:
	var i: int = g.weapons.find(g.weapon)
	select(g, g.weapons[posmod(i + step, g.weapons.size())])


static func start_reload(g) -> Dictionary:
	var w := weapon(g.data, g.weapon)
	if g.reload_left > 0.0:
		return g._fail("Already reloading.")
	if int(g.ammo.get(g.weapon, 0)) >= int(w.mag):
		return g._fail("Magazine is full.")
	g.reload_left = float(w.reload)
	return g._ok("Reloading.")


## Pulls the trigger. Returns {"ok", "bullets": [..]}; empty magazine starts a reload by itself.
static func fire(g, origin: Vector2, aim: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var w := weapon(g.data, g.weapon)
	if w.is_empty() or g.reload_left > 0.0 or g.cooldown > 0.0 or aim.length() < 0.001:
		return {"ok": false, "bullets": []}
	if int(g.ammo.get(g.weapon, 0)) <= 0:
		start_reload(g)
		return {"ok": false, "bullets": []}
	g.ammo[g.weapon] = int(g.ammo[g.weapon]) - 1
	g.cooldown = float(w.interval)
	var bullets: Array = []
	for i in int(w.pellets):
		var dir := aim.normalized().rotated(deg_to_rad(rng.randf_range(-1.0, 1.0) * float(w.spread_deg) * 0.5))
		bullets.append(make_bullet(origin, dir, float(w.bullet_speed), float(w.damage), float(w.range), PLAYER_BULLET))
	if int(g.ammo[g.weapon]) <= 0:
		start_reload(g)
	g._emit("shot", {"weapon": g.weapon})
	return {"ok": true, "bullets": bullets}


## Gunfire is loud: heat grows with the weapon's noise, but only when somebody could hear it (an officer in earshot).
static func noise_heat(g, officer_distances: Array) -> float:
	var near := float(cfg(g.data).get("officer", {}).get("witness_range", 340))
	for d in officer_distances:
		if float(d) <= near:
			return float(weapon(g.data, g.weapon).get("noise_heat", 0.0))
	return 0.0


# ---------------------------------------------------------------- damage

## Returns true when this hit knocked the player out (hp 0): the caller then calls knock_out().
static func damage_player(g, amount: float) -> bool:
	g.hp = maxf(0.0, g.hp - amount)
	g.since_hit = 0.0
	g._emit("player_hit", {"hp": g.hp})
	return g.hp <= 0.0


## Down but not dead: product is confiscated, a fine is paid, heat cools and the player wakes up half healthy.
static func knock_out(g) -> Dictionary:
	var lost := 0
	for k in g.cargo.keys():
		if Mixing.is_product(k):
			lost += int(g.cargo[k])
			g.cargo.erase(k)
	var p: Dictionary = cfg(g.data).player
	var fine := mini(g.credits, maxi(int(p.ko_fine_min), int(g.credits * float(p.ko_fine_ratio))))
	g.credits -= fine
	g.stats.knockouts += 1
	g._set_heat(g.heat - float(p.ko_heat_drop))
	g.hp = max_hp(g) * float(p.ko_hp_ratio)
	g.since_hit = 0.0
	g.reload_left = 0.0
	g._emit("knocked_out", {"lost": lost, "fine": fine})
	return g._ok("Knocked out! Lost %d units and paid %d cr to get patched up." % [lost, fine])


## Officer killed by the player: bounty-style heat.
static func officer_killed(g) -> void:
	g.stats.kills += 1
	g.add_heat(float(cfg(g.data).officer.kill_heat))
	g._emit("officer_killed", {})


static func officer_hit(g) -> void:
	g.add_heat(float(cfg(g.data).officer.hit_heat))


## Officers draw their weapons at high heat (or once shot at); the surface checks this per officer.
static func officers_armed(g) -> bool:
	return g.heat >= float(cfg(g.data).officer.draw_heat)


## Bullet an armed officer fires at `target` (with the officer's inaccuracy).
static func officer_bullet(g, from: Vector2, target: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var o: Dictionary = cfg(g.data).officer
	var dir := (target - from).normalized().rotated(deg_to_rad(rng.randf_range(-1.0, 1.0) * float(o.spread_deg) * 0.5))
	return make_bullet(from, dir, float(o.bullet_speed), float(o.damage), float(o.range) * 1.2, OFFICER_BULLET)


# ---------------------------------------------------------------- cover and bullets

## Cover pieces of a planet as tile rects [x, y, w, h] (+ kind string at [4]); [] for places without any.
static func cover_tiles(data: Dictionary, loc_id: String) -> Array:
	return cfg(data).get("cover", {}).get(loc_id, [])


static func cover_rects(tiles: Array, tile: float) -> Array:
	var r: Array = []
	for c in tiles:
		r.append(Rect2(float(c[0]) * tile, float(c[1]) * tile, float(c[2]) * tile, float(c[3]) * tile))
	return r


static func make_bullet(pos: Vector2, dir: Vector2, speed: float, damage: float, reach: float, owner: String) -> Dictionary:
	return {"pos": pos, "vel": dir.normalized() * speed, "damage": damage, "left": reach, "owner": owner}


## Smallest t in [0,1] where segment a->b enters rect r (0 if a is inside), INF if it never does.
static func segment_rect_t(a: Vector2, b: Vector2, r: Rect2) -> float:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for axis in 2:
		var lo: float = r.position[axis]
		var hi: float = r.end[axis]
		if absf(d[axis]) < 0.00001:
			if a[axis] < lo or a[axis] > hi:
				return INF
		else:
			var ta := (lo - a[axis]) / d[axis]
			var tb := (hi - a[axis]) / d[axis]
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
			if t0 > t1:
				return INF
	return t0


## Smallest t in [0,1] where segment a->b touches the circle (0 if a is inside), INF if it misses.
static func segment_circle_t(a: Vector2, b: Vector2, c: Vector2, radius: float) -> float:
	var d := b - a
	var f := a - c
	var qa := d.dot(d)
	if f.dot(f) <= radius * radius:
		return 0.0
	if qa < 0.00001:
		return INF
	var qb := 2.0 * f.dot(d)
	var disc := qb * qb - 4.0 * qa * (f.dot(f) - radius * radius)
	if disc < 0.0:
		return INF
	var t := (-qb - sqrt(disc)) / (2.0 * qa)
	return t if t >= 0.0 and t <= 1.0 else INF


## True if nothing in `rects` stands between a and b (used for officers' line of fire).
static func line_clear(a: Vector2, b: Vector2, rects: Array) -> bool:
	for r in rects:
		if segment_rect_t(a, b, r) != INF:
			return false
	return true


## Moves bullet `b` (in place) by dt. blockers = rects that stop it (buildings, cover); targets = [{pos, r}].
## Returns {"hit": "" | "wall" | "target" | "range", "idx": target index, "pos": end position}.
static func step_bullet(b: Dictionary, dt: float, blockers: Array, targets: Array) -> Dictionary:
	var a: Vector2 = b.pos
	var move: Vector2 = b.vel * dt
	var reach := minf(move.length(), float(b.left))
	var end := a + (move.normalized() * reach if move.length() > 0.0 else Vector2.ZERO)
	var best := INF
	var kind := ""
	var idx := -1
	for r in blockers:
		var t := segment_rect_t(a, end, r)
		if t < best:
			best = t
			kind = "wall"
	for i in targets.size():
		var t := segment_circle_t(a, end, targets[i].pos, float(targets[i].r))
		if t < best:
			best = t
			kind = "target"
			idx = i
	if kind != "":
		b.pos = a.lerp(end, best)
		return {"hit": kind, "idx": idx, "pos": b.pos}
	b.pos = end
	b.left = float(b.left) - reach
	if float(b.left) <= 0.01:
		return {"hit": "range", "idx": -1, "pos": end}
	return {"hit": "", "idx": -1, "pos": end}
