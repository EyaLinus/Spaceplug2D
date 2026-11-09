extends Node2D
## Space combat in the world: pirates, cartel wings (fighters, gunships), cartel bases with turrets, laser bolts,
## secondary weapons (homing missiles, flak, ion), loot crates, explosions, shield ring and dodge trail.
## Geometry and timing only; every damage/ammo/bounty/loot rule is in scripts/core/spacecombat.gd.
## World calls step() once per physics frame while the ship is flying.

const FloatText = preload("res://scripts/world/float_text.gd")
const SpaceCombat = preload("res://scripts/core/spacecombat.gd")
const PirateScript = preload("res://scripts/world/pirate.gd")
const Cartels = preload("res://scripts/core/cartels.gd")
const Art = preload("res://scripts/core/art.gd")
const Escort = preload("res://scripts/core/escort.gd")

const SHIP_RADIUS := 16.0

var world: Node2D
var ship: Node2D
var pirates: Array = []
var bolts: Array = []  ## {pos, vel, life, dmg, mine, missile, target, kind (laser|missile|flak|ion|enemy)}
var loot: Array = []  ## floating crates {pos, vel, items, life, full}
var bases: Dictionary = {}  ## cartel base location id -> {hull, max, awake, cd: [turret cooldowns], sent}
var fx: Array = []  ## {pos, vel, life, max, color, size}
var rng := RandomNumberGenerator.new()
var shake := 0.0  ## camera shake strength (world reads it)
var hit_flash := 0.0  ## red screen flash, read by the combat HUD
var _laser_cd := 0.0
var _missile_cd := 0.0  ## secondary weapon cooldown (missile, flak or ion)
var _spawn_clock := 0.0
var _seed := 100
var _ring := 0.0  ## shield ring flash after a hit absorbed by the shield
var _trail: Array = []  ## recent ship positions while boosting


func _ready() -> void:
	z_index = 5
	rng.seed = 4242


func setup(w: Node2D, s: Node2D) -> void:
	world = w
	ship = s


func clear() -> void:
	for p in pirates:
		p.queue_free()
	pirates.clear()
	bolts.clear()
	fx.clear()
	loot.clear()
	bases.clear()
	_trail.clear()
	_spawn_clock = 0.0
	queue_redraw()


## Seconds-based update. `g` is the core Game; the ship must be flying (world.active).
func step(delta: float, g) -> void:
	var cc: Dictionary = g.data.space_combat
	_laser_cd = maxf(0.0, _laser_cd - delta)
	_missile_cd = maxf(0.0, _missile_cd - delta)
	shake = maxf(0.0, shake - delta * 14.0)
	hit_flash = maxf(0.0, hit_flash - delta * 3.0)
	_ring = maxf(0.0, _ring - delta * 3.0)
	if not ship.frozen:
		if Input.is_action_pressed("ship_fire"):
			fire_laser(g)
		if Input.is_action_pressed("ship_missile"):
			fire_secondary(g)
		if Input.is_action_just_pressed("ship_cycle"):
			var w := SpaceCombat.cycle_secondary(g)
			if w != "":
				EventBus.toast.emit("Secondary weapon: %s" % g.data.upgrades[w].name, true)
	_spawn(delta, g)
	for p in pirates.duplicate():
		var tgt: Vector2 = ship.position
		var tvel: Vector2 = ship.velocity
		if world.freighter != null and Escort.prefers_freighter(g, p.position, ship.position):
			tgt = world.freighter.position  # escort mission: raiders go for the freighter first
			tvel = Vector2.ZERO
		var aim: float = p.step(delta, tgt, tvel)
		if aim != INF:
			var ec: Dictionary = p.cfg
			var shots := int(ec.get("shots", 1))
			var fan := deg_to_rad(float(ec.get("fan_degrees", 0.0)))
			for i in shots:
				var a: float = aim + (0.0 if shots == 1 else fan * (float(i) / float(shots - 1) - 0.5))
				_add_bolt(p.position + Vector2.from_angle(a) * (p.radius + 4.0), Vector2.from_angle(a) * float(ec.bolt_speed),
					float(ec.bolt_range) / float(ec.bolt_speed), float(ec.damage), false)
			AudioManager.play("laser")
		if p.position.distance_to(ship.position) > float(cc.spawn.despawn_dist):
			pirates.erase(p)
			p.queue_free()
	_step_bases(delta, g)
	_step_bolts(delta, g)
	_step_loot(delta, g)
	_step_fx(delta)
	if ship.boosting():
		_trail.append(ship.position)
		if _trail.size() > 8:
			_trail.pop_front()
	elif not _trail.is_empty():
		_trail.pop_front()
	queue_redraw()


# ---------------------------------------------------------------- player weapons

func fire_laser(g) -> bool:
	if _laser_cd > 0.0 or ship.frozen:
		return false
	var cc: Dictionary = g.data.space_combat
	_laser_cd = float(cc.laser.cooldown)
	var dir := Vector2.UP.rotated(ship.rotation)
	var lvl: int = g.upgrades.laser
	var offsets: Array = [0.0] if lvl < 2 else [-10.0, 10.0]
	for o in offsets:
		var origin: Vector2 = ship.position + dir * 20.0 + dir.orthogonal() * float(o)
		_add_bolt(origin, dir * float(cc.laser.speed) + ship.velocity * 0.3, float(cc.laser.range) / float(cc.laser.speed),
			SpaceCombat.laser_damage(g), true)
	AudioManager.play("laser")
	return true


func fire_missile(g) -> bool:
	if _missile_cd > 0.0 or ship.frozen or not SpaceCombat.has_missiles(g):
		return false
	if not SpaceCombat.take_missile(g):
		EventBus.toast.emit("Out of missiles. Restock at the mechanic.", false)
		return false
	var cc: Dictionary = g.data.space_combat
	_missile_cd = float(cc.missile.cooldown)
	var dir := Vector2.UP.rotated(ship.rotation)
	var b := _add_bolt(ship.position + dir * 20.0, dir * float(cc.missile.speed) + ship.velocity * 0.5,
		float(cc.missile.range) / float(cc.missile.speed), float(cc.missile.damage), true)
	b.missile = true
	b.kind = "missile"
	AudioManager.play("boost")
	return true


## Fires the selected secondary weapon (missile pods, flak battery or ion emitter).
func fire_secondary(g) -> bool:
	match SpaceCombat.secondary(g):
		"missile":
			return fire_missile(g) if Input.is_action_just_pressed("ship_missile") or not Input.is_action_pressed("ship_missile") else false
		"flak":
			return fire_flak(g)
		"ion":
			return fire_ion(g)
	return false


## Flak: a short-range cone of pellets, good against fighter swarms. No ammo.
func fire_flak(g) -> bool:
	if _missile_cd > 0.0 or ship.frozen or SpaceCombat.flak_damage(g) <= 0.0:
		return false
	var fc: Dictionary = g.data.space_combat.flak
	_missile_cd = float(fc.cooldown)
	var dir := Vector2.UP.rotated(ship.rotation)
	var n := int(fc.pellets)
	var spread := deg_to_rad(float(fc.spread_degrees))
	for i in n:
		var a := dir.angle() + spread * (float(i) / float(maxi(1, n - 1)) - 0.5) + rng.randf_range(-0.03, 0.03)
		var b := _add_bolt(ship.position + dir * 20.0, Vector2.from_angle(a) * float(fc.speed) * rng.randf_range(0.9, 1.1) + ship.velocity * 0.3,
			float(fc.range) / float(fc.speed), SpaceCombat.flak_damage(g), true)
		b.kind = "flak"
	shake = maxf(shake, 2.0)
	AudioManager.play("flak")
	return true


## Ion: a slow bolt that stuns what it hits (and ships around it) and hits gunships and bases harder.
func fire_ion(g) -> bool:
	if _missile_cd > 0.0 or ship.frozen or SpaceCombat.ion_damage(g) <= 0.0:
		return false
	var ic: Dictionary = g.data.space_combat.ion
	_missile_cd = float(ic.cooldown)
	var dir := Vector2.UP.rotated(ship.rotation)
	var b := _add_bolt(ship.position + dir * 20.0, dir * float(ic.speed) + ship.velocity * 0.3, float(ic.range) / float(ic.speed), SpaceCombat.ion_damage(g), true)
	b.kind = "ion"
	AudioManager.play("ion")
	return true


## Pirates within `r` of `p` take splash damage (missile blast).
func _blast(g, p: Vector2, dmg: float, r: float) -> void:
	_sprite_fx("explosion", p, 0.55, Art.EXPLOSION_FRAMES, r / 44.0)
	_burst(p, 14, Color(1.0, 0.7, 0.3), 160.0, 0.55)
	for t in pirates.duplicate():
		if t.position.distance_to(p) <= r + t.radius:
			_damage_pirate(g, t, dmg)
	_blast_bases(g, p, dmg, r)


## Ion burst: stuns every ship within `r`; the one struck takes the damage (heavy ships more).
func _ion_hit(g, p: Vector2, struck: Node2D, dmg: float) -> void:
	var ic: Dictionary = g.data.space_combat.ion
	_burst(p, 16, Color(0.5, 0.85, 1.0), 150.0, 0.5)
	for t in pirates.duplicate():
		if t.position.distance_to(p) <= float(ic.blast) + t.radius:
			t.stun = float(ic.stun)
	if struck != null:
		_damage_pirate(g, struck, dmg * (float(ic.heavy_mult) if struck.heavy() else 1.0))
	else:
		_blast_bases(g, p, dmg * float(ic.heavy_mult), 4.0)


func _damage_pirate(g, p: Node2D, dmg: float) -> void:
	if not pirates.has(p):
		return
	if Settings.damage_numbers:
		var f: Node2D = FloatText.new().setup("%d" % int(round(dmg)), Color("#ffd166"), 15)
		f.position = p.position + Vector2(0, -22)
		add_child(f)
	if p.hit(dmg):
		pirates.erase(p)
		var r := SpaceCombat.enemy_down(g, p.kind, p.cartel, rng)
		_sprite_fx("explosion", p.position, 0.75, Art.EXPLOSION_FRAMES, 1.7 if p.kind == "gunship" else 1.2)
		_burst(p.position, 30 if p.kind == "gunship" else 22, Color(1.0, 0.55, 0.25), 260.0 if p.kind == "gunship" else 220.0, 0.8)
		shake = maxf(shake, 5.0 if p.kind == "gunship" else 2.0)
		AudioManager.play("boom")
		var who: String = "Pirate" if p.kind == "pirate" else ("%s %s" % [Cartels.gang(g, p.cartel).get("name", ""), p.kind] if p.cartel != "" else str(p.cfg.get("name", p.kind)))
		EventBus.toast.emit("%s down%s" % [who, (": +%d cr bounty." % int(r.bounty)) if int(r.bounty) > 0 else "."], true)
		if not (r.loot as Array).is_empty():
			drop_loot(p.position, r.loot)
		p.queue_free()
	else:
		_sprite_fx("hit", p.position, 0.2, 3, 1.0)
		_burst(p.position, 4, Color(1.0, 0.9, 0.6), 90.0, 0.25)


# ---------------------------------------------------------------- loot

## A crate drifts where a ship blew up; fly over it to pick it up.
func drop_loot(pos: Vector2, items: Array) -> void:
	loot.append({"pos": pos, "vel": Vector2.from_angle(rng.randf() * TAU) * 30.0, "items": items, "life": float(GameState.data.space_combat.get("loot_life", 25.0)), "full": false})


func _step_loot(delta: float, g) -> void:
	var reach := float(g.data.space_combat.get("loot_pickup", 46.0))
	for l in loot.duplicate():
		l.life -= delta
		l.pos += l.vel * delta
		l.vel *= 1.0 - minf(1.0, 0.6 * delta)
		if l.pos.distance_to(ship.position) < reach:
			var r := SpaceCombat.collect_loot(g, l.items)
			if r.ok:
				loot.erase(l)
				_burst(l.pos, 10, Color(1.0, 0.85, 0.4), 120.0, 0.4)
				AudioManager.play("coin")
				EventBus.toast.emit(r.msg, true)
				continue
			elif not l.full:
				l.full = true
				EventBus.toast.emit(r.msg, false)
		if l.life <= 0.0:
			loot.erase(l)


# ---------------------------------------------------------------- cartel bases

## Wakes up active cartel bases near the ship: turrets fire, defenders launch once.
func _step_bases(delta: float, g) -> void:
	var bc: Dictionary = g.data.space_combat.get("bases", {})
	if bc.is_empty():
		return
	for id in world.locations:
		var n: Node2D = world.locations[id]
		if str(n.info.get("kind", "")) != "cartel_base":
			continue
		if not SpaceCombat.base_active(g, id):
			bases.erase(id)
			if rng.randf() < 0.3:  # the wreck smoulders
				fx.append({"pos": n.position + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40)), "vel": Vector2(0, -20), "life": 1.6, "max": 1.6, "color": Color(0.35, 0.35, 0.4, 0.5), "size": rng.randf_range(4.0, 9.0)})
			continue
		var d := ship.position.distance_to(n.position)
		var b: Dictionary = base_state(id)
		if d > float(bc.aggro):
			b.awake = false
			continue
		if not b.awake:
			b.awake = true
			EventBus.toast.emit("%s turrets are tracking you!" % n.info.get("name", "The base"), false)
		if not b.sent:
			b.sent = true
			var units: Array = SpaceCombat.wing_units(g, str(n.info.cartel))
			spawn_wing(g, str(n.info.cartel), units.slice(0, int(bc.defenders)), n.position + (ship.position - n.position).normalized() * 140.0)
		var cds: Array = b.cd
		for i in cds.size():
			cds[i] = float(cds[i]) - delta
			if float(cds[i]) > 0.0 or d > float(bc.turret_range):
				continue
			cds[i] = float(bc.turret_cooldown) * rng.randf_range(0.8, 1.25)
			var tp: Vector2 = turret_pos(n, i)
			var aim: float = (ship.position + ship.velocity * 0.3 - tp).angle() + rng.randf_range(-0.06, 0.06)
			_add_bolt(tp, Vector2.from_angle(aim) * float(bc.bolt_speed), float(bc.turret_range) / float(bc.bolt_speed), float(bc.turret_damage), false)
			AudioManager.play("laser")


## Runtime state of a cartel base (hull resets when you leave the system).
func base_state(id: String) -> Dictionary:
	if not bases.has(id):
		var bc: Dictionary = GameState.data.space_combat.bases
		var cds: Array = []
		for i in int(bc.turrets):
			cds.append(rng.randf_range(0.5, float(bc.turret_cooldown)))
		bases[id] = {"hull": float(bc.hull), "max": float(bc.hull), "awake": false, "cd": cds, "sent": false}
	return bases[id]


func turret_pos(n: Node2D, i: int) -> Vector2:
	return n.position + Vector2.from_angle(i * PI / 2.0 + PI / 4.0) * float(n.radius) * 0.72


## The cartel base location under `p` (within its radius), "" if none.
func _base_at(g, p: Vector2, pad := 0.0) -> String:
	for id in world.locations:
		var n: Node2D = world.locations[id]
		if str(n.info.get("kind", "")) == "cartel_base" and SpaceCombat.base_active(g, id) and p.distance_to(n.position) < float(n.radius) + pad:
			return id
	return ""


func _blast_bases(g, p: Vector2, dmg: float, r: float) -> void:
	var id := _base_at(g, p, r)
	if id != "":
		damage_base(g, id, dmg)


## Damages a cartel base; at zero hull it blows up and the core pays the raid.
func damage_base(g, id: String, dmg: float) -> void:
	var b := base_state(id)
	b.hull = float(b.hull) - dmg
	var n: Node2D = world.locations[id]
	if Settings.damage_numbers:
		var f: Node2D = FloatText.new().setup("%d" % int(round(dmg)), Color("#ffd166"), 17)
		f.position = n.position + Vector2(rng.randf_range(-30.0, 30.0), -float(n.radius) * 0.7)
		add_child(f)
	if float(b.hull) > 0.0:
		_burst(n.position + Vector2.from_angle(rng.randf() * TAU) * float(n.radius) * 0.6, 3, Color(1.0, 0.8, 0.5), 80.0, 0.3)
		return
	var r := SpaceCombat.raid_base(g, id, rng)
	bases.erase(id)
	for i in 4:
		_burst(n.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 50.0), 24, Color(1.0, 0.55, 0.25), 320.0, 1.1)
	shake = 10.0
	AudioManager.play("boom")
	EventBus.toast.emit("%s destroyed: +%d cr. The %s lose their grip on this system." % [n.info.get("name", id), int(r.credits), Cartels.gang(g, str(n.info.cartel)).get("name", "cartel")], true)
	if not (r.loot as Array).is_empty():
		drop_loot(n.position + Vector2(0, float(n.radius) + 30.0), r.loot)


# ---------------------------------------------------------------- pirates

func _spawn(delta: float, g) -> void:
	if Escort.active(g):
		_spawn_escort(delta, g)
		return
	if not SpaceCombat.is_deep_space(g, world.nearest_location_distance()):
		return
	_spawn_clock += delta
	if _spawn_clock < SpaceCombat.spawn_interval(g) or pirates.size() >= SpaceCombat.max_pirates(g):
		return
	_spawn_clock = 0.0
	var pick := SpaceCombat.pick_spawn(g, rng)
	if pick.cartel == "":
		spawn_pirate(g)
		EventBus.toast.emit("Pirates on your tail!", false)
	else:
		spawn_wing(g, pick.cartel, pick.units)
		EventBus.toast.emit("%s wing incoming: %d ships!" % [Cartels.gang(g, pick.cartel).get("name", "Cartel"), (pick.units as Array).size()], false)


## Escort mission waves: the core clock decides when, a lone raider or a cartel wing arrives around the freighter.
func _spawn_escort(delta: float, g) -> void:
	if world.freighter == null:
		return
	var pick := Escort.tick_wave(g, delta, pirates.size(), rng)
	if pick.is_empty():
		return
	var w: Dictionary = g.data.escort.waves
	var at: Vector2 = world.freighter.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(float(w.spawn_min), float(w.spawn_max))
	if pick.cartel == "":
		spawn_enemy(g, "pirate", "", at)
		EventBus.toast.emit("Raiders closing on the freighter!", false)
	else:
		spawn_wing(g, pick.cartel, pick.units, at)
		EventBus.toast.emit("%s wing is after the freighter: %d ships!" % [Cartels.gang(g, pick.cartel).get("name", "Cartel"), (pick.units as Array).size()], false)


## Brings one raider in from beyond the screen (also used by the smoke test with `at`).
func spawn_pirate(g, at = null) -> Node2D:
	return spawn_enemy(g, "pirate", "", at)


## Brings a group of ships in together, spread around `at` (default: a point beyond the screen). Returns the ships.
func spawn_wing(g, cartel: String, units: Array, at = null) -> Array:
	var s: Dictionary = g.data.space_combat.spawn
	var centre: Vector2 = at if at != null else ship.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(float(s.min_dist), float(s.max_dist))
	var out: Array = []
	for i in units.size():
		var off := Vector2.from_angle(TAU * i / maxf(1.0, units.size())) * (0.0 if units.size() == 1 else 70.0)
		out.append(spawn_enemy(g, str(units[i]), cartel, centre + off))
	return out


## One enemy ship of `kind` (pirate, fighter, gunship, interceptor), tinted in the cartel colour.
func spawn_enemy(g, kind: String, cartel := "", at = null) -> Node2D:
	var s: Dictionary = g.data.space_combat.spawn
	var pos: Vector2
	if at != null:
		pos = at
	else:
		pos = ship.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(float(s.min_dist), float(s.max_dist))
	var lim: float = world.SECTOR_HALF - 300.0
	pos = pos.clamp(Vector2(-lim, -lim), Vector2(lim, lim))
	var p := PirateScript.new()
	_seed += 1
	var col := Color(str(Cartels.gang(g, cartel).get("color", "#ffffff"))) if cartel != "" else Color(1, 1, 1)
	p.setup(SpaceCombat.enemy_cfg(g, kind), pos, _seed, kind, cartel, col)
	add_child(p)
	pirates.append(p)
	return p


# ---------------------------------------------------------------- bolts, hits

func _add_bolt(pos: Vector2, vel: Vector2, life: float, dmg: float, mine: bool) -> Dictionary:
	var b := {"pos": pos, "vel": vel, "life": life, "dmg": dmg, "mine": mine, "missile": false, "target": null, "kind": "laser" if mine else "enemy"}
	bolts.append(b)
	return b


func _step_bolts(delta: float, g) -> void:
	var cc: Dictionary = g.data.space_combat
	for b in bolts.duplicate():
		b.life -= delta
		if b.missile:
			_home(b, delta, float(cc.missile.turn), float(cc.missile.speed))
		b.pos += b.vel * delta
		var dead: bool = b.life <= 0.0
		if b.mine:
			var struck: Node2D = null
			for p in pirates:
				if b.pos.distance_to(p.position) < p.radius + 5.0:
					struck = p
					break
			var base_hit := "" if struck != null else _base_at(g, b.pos)
			if struck != null or base_hit != "" or (dead and (b.missile or b.kind == "ion")):
				if b.missile:
					_blast(g, b.pos, float(b.dmg), float(cc.missile.blast))
				elif b.kind == "ion":
					_ion_hit(g, b.pos, struck, float(b.dmg))
				elif struck != null:
					_damage_pirate(g, struck, float(b.dmg))
				else:
					damage_base(g, base_hit, float(b.dmg))
				dead = true
		elif b.pos.distance_to(ship.position) < SHIP_RADIUS + 4.0:
			if ship.invulnerable():
				_ring = 1.0  # dodged: the bolt passes through the boosting ship
			else:
				hurt_player(g, float(b.dmg))
				dead = true
		elif _hit_freighter(g, b):
			dead = true
		if dead:
			bolts.erase(b)


## An enemy bolt reaching the escort freighter hurts it; at zero hull the core fails the job.
func _hit_freighter(g, b: Dictionary) -> bool:
	var f: Node2D = world.freighter
	if f == null or not Escort.active(g) or b.pos.distance_to(f.position) >= f.radius + 4.0:
		return false
	var res := Escort.damage(g, float(b.dmg))
	f.hit()
	_burst(b.pos, 4, Color(1.0, 0.6, 0.3), 110.0, 0.3)
	if Settings.damage_numbers:
		var t: Node2D = FloatText.new().setup("-%d" % int(round(float(b.dmg))), Color("#ff6b5f"), 14)
		t.position = f.position + Vector2(0, -f.radius - 30.0)
		add_child(t)
	if res.destroyed:
		for i in 3:
			_burst(f.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 30.0), 24, Color(1.0, 0.55, 0.25), 300.0, 1.0)
		shake = maxf(shake, 8.0)
		AudioManager.play("boom")
	return true


func _home(b: Dictionary, delta: float, turn: float, speed: float) -> void:
	var t = b.target
	if t == null or not is_instance_valid(t) or not pirates.has(t):
		t = null
		var best := 700.0
		for p in pirates:
			var d: float = p.position.distance_to(b.pos)
			var off: float = absf(angle_difference(b.vel.angle(), (p.position - b.pos).angle()))
			if d < best and off < 1.6:
				best = d
				t = p
		b.target = t
	if t != null:
		var want: float = (t.position - b.pos).angle()
		var cur: float = b.vel.angle()
		b.vel = Vector2.from_angle(rotate_toward(cur, want, turn * delta)) * speed
	if rng.randf() < 0.7:
		fx.append({"pos": b.pos, "vel": Vector2.ZERO, "life": 0.3, "max": 0.3, "color": Color(1.0, 0.8, 0.5, 0.7), "size": 2.0})


## Damage to the player from a pirate bolt (or the smoke test). Resolves the wreck when the hull is gone.
func hurt_player(g, amount: float) -> void:
	var res := SpaceCombat.damage(g, amount)
	shake = maxf(shake, 6.0 if float(res.hull) > 0.0 else 3.0)
	if Settings.damage_numbers:
		var f: Node2D = FloatText.new().setup("-%d" % int(round(amount)), Color("#ff6b5f") if float(res.hull) > 0.0 else Color("#7fd3ff"), 15)
		f.position = ship.position + Vector2(0, -26)
		add_child(f)
	if float(res.hull) > 0.0:
		hit_flash = 1.0
		AudioManager.play("hit")
	else:
		_ring = 1.0
	if float(res.hull) > 0.0:
		_sprite_fx("hit", ship.position + Vector2.from_angle(rng.randf() * TAU) * 10.0, 0.2, 3, 1.3)
	_burst(ship.position, 6, Color(0.6, 0.9, 1.0) if float(res.hull) <= 0.0 else Color(1.0, 0.5, 0.3), 140.0, 0.35)
	if res.destroyed:
		_wreck(g)


func _wreck(g) -> void:
	_sprite_fx("explosion", ship.position, 1.0, Art.EXPLOSION_FRAMES, 2.2)
	_burst(ship.position, 30, Color(1.0, 0.6, 0.2), 300.0, 1.0)
	var r := SpaceCombat.defeat(g)
	AudioManager.play("bust")
	EventBus.toast.emit(r.msg, false)
	var keep_fx := fx.duplicate()
	clear()
	fx = keep_fx
	world.respawn_after_wreck()


# ---------------------------------------------------------------- effects

func _burst(pos: Vector2, n: int, color: Color, speed: float, life: float) -> void:
	for i in n:
		var v := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.2, 1.0) * speed
		fx.append({"pos": pos, "vel": v, "life": life * rng.randf_range(0.5, 1.0), "max": life, "color": color, "size": rng.randf_range(1.5, 4.0)})


## One-shot sprite effect from a fx strip (art pass 4): plays `frames` frames over `life` seconds. Nothing without the art.
func _sprite_fx(sprite: String, pos: Vector2, life: float, frames: int, scale: float) -> void:
	if Art.fx(sprite) != null:
		fx.append({"pos": pos, "vel": Vector2.ZERO, "life": life, "max": life, "sprite": sprite, "frames": frames, "scale": scale})


func _step_fx(delta: float) -> void:
	for f in fx.duplicate():
		f.life -= delta
		f.pos += f.vel * delta
		f.vel *= 1.0 - minf(1.0, 2.0 * delta)
		if f.life <= 0.0:
			fx.erase(f)


func _draw() -> void:
	for i in _trail.size():
		var a := float(i + 1) / float(_trail.size()) * 0.35
		draw_circle(_trail[i], 12.0, Color(0.7, 0.95, 1.0, a))
	for b in bolts:
		var dir: Vector2 = b.vel.normalized()
		if b.missile:
			if Art.draw_fx(self, "missile", b.pos - dir * 4.0, dir.angle(), 0, 1, 0.75):
				continue
			draw_line(b.pos - dir * 10.0, b.pos + dir * 6.0, Color(0.95, 0.95, 1.0), 4.0)
			draw_circle(b.pos + dir * 6.0, 3.0, Color(1.0, 0.4, 0.3))
		elif b.kind == "ion":
			draw_circle(b.pos, 6.0, Color(0.4, 0.75, 1.0, 0.5))
			draw_circle(b.pos, 3.0, Color(0.85, 0.95, 1.0))
		elif b.kind == "flak":
			draw_circle(b.pos, 2.5, Color(1.0, 0.8, 0.4))
		elif b.mine:
			if Art.draw_fx(self, "bolt_laser", b.pos - dir * 2.0, dir.angle(), 0, 1, 0.8):
				continue
			draw_line(b.pos - dir * 12.0, b.pos + dir * 8.0, Color(0.4, 1.0, 0.9), 3.0)
			draw_line(b.pos - dir * 12.0, b.pos + dir * 8.0, Color(0.9, 1.0, 1.0), 1.0)
		else:
			if Art.draw_fx(self, "bolt_pirate", b.pos - dir * 1.0, dir.angle(), 0, 1, 0.8):
				continue
			draw_line(b.pos - dir * 10.0, b.pos + dir * 8.0, Color(1.0, 0.35, 0.3), 3.0)
			draw_line(b.pos - dir * 10.0, b.pos + dir * 8.0, Color(1.0, 0.85, 0.7), 1.0)
	var crate := Art.tex("space/loot.png")
	for l in loot:
		var bob := sin(Time.get_ticks_msec() / 200.0 + l.pos.x) * 3.0
		var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		if float(l.life) > 5.0 or blink > 0.3:
			if crate != null:
				draw_texture(crate, l.pos + Vector2(0, bob) - crate.get_size() / 2.0)
			else:
				draw_rect(Rect2(l.pos + Vector2(-8, -8 + bob), Vector2(16, 16)), Color("#ffd166"))
			draw_arc(l.pos + Vector2(0, bob), 20.0, 0.0, TAU, 20, Color(1.0, 0.85, 0.4, 0.25 + 0.3 * blink), 1.5)
	for id in bases:
		var b: Dictionary = bases[id]
		var n: Node2D = world.locations.get(id)
		if n == null or not b.awake:
			continue
		var w := 120.0
		var top: Vector2 = n.position + Vector2(-w / 2.0, -float(n.radius) - 22.0)
		draw_rect(Rect2(top, Vector2(w, 6)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * clampf(float(b.hull) / float(b.max), 0.0, 1.0), 6)), Color(str(n.info.get("color", "#ff6b5f"))))
		for i in (b.cd as Array).size():
			draw_circle(turret_pos(n, i), 5.0, Color(1.0, 0.3, 0.25, 0.35 + 0.35 * sin(Time.get_ticks_msec() / 150.0 + i)))
	for f in fx:
		if f.has("sprite"):
			var k := 1.0 - clampf(float(f.life) / float(f.max), 0.0, 0.999)
			Art.draw_fx(self, f.sprite, f.pos, 0.0, int(k * int(f.frames)), int(f.frames), float(f.scale))
			continue
		var c: Color = f.color
		c.a *= clampf(f.life / f.max, 0.0, 1.0)
		draw_circle(f.pos, f.size, c)
	var g = GameState.game
	if g != null and ship != null and SpaceCombat.max_shield(g) > 0.0:
		var ratio := SpaceCombat.shield_ratio(g)
		if ratio > 0.0 or _ring > 0.0:
			var a := 0.12 + 0.5 * _ring + 0.15 * ratio
			var spin := int(Time.get_ticks_msec() / 160) % 3
			if Art.draw_fx(self, "shield", ship.position, 0.0, spin, 3, 1.0, Color(1, 1, 1, clampf(a + 0.15, 0.0, 1.0))):
				return
			draw_arc(ship.position, 30.0, 0.0, TAU, 40, Color(0.5, 0.85, 1.0, clampf(a, 0.0, 0.9)), 2.0 + 2.0 * _ring)
