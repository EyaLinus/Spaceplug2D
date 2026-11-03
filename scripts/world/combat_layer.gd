extends Node2D
## Space combat in the world: pirates, laser bolts, homing missiles, explosions, shield ring and dodge trail.
## Geometry and timing only; every damage/ammo/bounty rule is in scripts/core/spacecombat.gd.
## World calls step() once per physics frame while the ship is flying.

const SpaceCombat = preload("res://scripts/core/spacecombat.gd")
const PirateScript = preload("res://scripts/world/pirate.gd")
const Interdiction = preload("res://scripts/core/interdiction.gd")

const SHIP_RADIUS := 16.0

var world: Node2D
var ship: Node2D
var pirates: Array = []
var bolts: Array = []  ## {pos, vel, life, dmg, mine, missile, target}
var fx: Array = []  ## {pos, vel, life, max, color, size}
var rng := RandomNumberGenerator.new()
var shake := 0.0  ## camera shake strength (world reads it)
var hit_flash := 0.0  ## red screen flash, read by the combat HUD
var _laser_cd := 0.0
var _missile_cd := 0.0
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
		if Input.is_action_just_pressed("ship_missile"):
			fire_missile(g)
	_spawn(delta, g)
	for p in pirates.duplicate():
		var aim: float = p.step(delta, ship.position, ship.velocity)
		if aim != INF:
			_add_bolt(p.position + Vector2.from_angle(aim) * 22.0, Vector2.from_angle(aim) * float(cc.pirate.bolt_speed),
				float(cc.pirate.bolt_range) / float(cc.pirate.bolt_speed), float(cc.pirate.damage), false)
			AudioManager.play("laser")
		if p.position.distance_to(ship.position) > float(cc.spawn.despawn_dist):
			pirates.erase(p)
			p.queue_free()
			if p.has_meta("interdictor"):
				Interdiction.ship_down(g, false)
	_step_bolts(delta, g)
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
	AudioManager.play("boost")
	return true


## Pirates within `r` of `p` take splash damage (missile blast); returns the number hit.
func _blast(g, p: Vector2, dmg: float, r: float) -> void:
	_burst(p, 14, Color(1.0, 0.7, 0.3), 160.0, 0.55)
	for t in pirates.duplicate():
		if t.position.distance_to(p) <= r + t.radius:
			_damage_pirate(g, t, dmg)


func _damage_pirate(g, p: Node2D, dmg: float) -> void:
	if p.hit(dmg):
		pirates.erase(p)
		_burst(p.position, 22, Color(1.0, 0.55, 0.25), 220.0, 0.8)
		AudioManager.play("boom")
		if p.get_meta("interdictor", "") == "authority":
			g.combat.kills = int(g.combat.kills) + 1
			EventBus.toast.emit("Authority cutter down.", true)
		else:
			var bounty := SpaceCombat.collect_bounty(g, rng)
			EventBus.toast.emit("Pirate down: +%d cr bounty." % bounty, true)
		var was_interdictor: bool = p.has_meta("interdictor")
		p.queue_free()
		if was_interdictor:
			Interdiction.ship_down(g, true)
	else:
		_burst(p.position, 4, Color(1.0, 0.9, 0.6), 90.0, 0.25)


# ---------------------------------------------------------------- pirates

func _spawn(delta: float, g) -> void:
	if not SpaceCombat.is_deep_space(g, world.nearest_location_distance()):
		return
	_spawn_clock += delta
	if _spawn_clock < SpaceCombat.spawn_interval(g) or pirates.size() >= SpaceCombat.max_pirates(g):
		return
	_spawn_clock = 0.0
	spawn_pirate(g)
	EventBus.toast.emit("Pirates on your tail!", false)


## Brings one raider in from beyond the screen (also used by the smoke test with `at`).
func spawn_pirate(g, at = null) -> Node2D:
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
	p.setup(g.data.space_combat.pirate, pos, _seed)
	add_child(p)
	pirates.append(p)
	return p


## The ships of a jump interdiction (D3) close in around the gate; `kind` is "pirates" or "authority" (tougher hulls,
## no bounty). The core counts them down (Interdiction.ship_down) and ends the encounter.
func spawn_interdictors(g, kind: String, n: int) -> void:
	var ic: Dictionary = g.data.interdiction.fight
	var s: Dictionary = g.data.space_combat.pirate.duplicate()
	s.hull = float(s.hull) * Interdiction.hull_mult(g, kind)
	var lim: float = world.SECTOR_HALF - 300.0
	for i in n:
		var ang := (TAU * float(i) / float(maxi(n, 1))) + rng.randf() * 0.8
		var pos: Vector2 = (ship.position + Vector2.from_angle(ang) * rng.randf_range(float(ic.spawn_min), float(ic.spawn_max))).clamp(Vector2(-lim, -lim), Vector2(lim, lim))
		var p := PirateScript.new()
		_seed += 1
		p.setup(s, pos, _seed)
		p.set_meta("interdictor", kind)
		add_child(p)
		pirates.append(p)


# ---------------------------------------------------------------- bolts, hits

func _add_bolt(pos: Vector2, vel: Vector2, life: float, dmg: float, mine: bool) -> Dictionary:
	var b := {"pos": pos, "vel": vel, "life": life, "dmg": dmg, "mine": mine, "missile": false, "target": null}
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
			var struck := false
			for p in pirates.duplicate():
				if b.pos.distance_to(p.position) < p.radius + 5.0:
					struck = true
					if not b.missile:
						_damage_pirate(g, p, float(b.dmg))
					break
			if struck or (dead and b.missile):
				if b.missile:
					_blast(g, b.pos, float(b.dmg), float(cc.missile.blast))
				dead = true
		elif b.pos.distance_to(ship.position) < SHIP_RADIUS + 4.0:
			if ship.invulnerable():
				_ring = 1.0  # dodged: the bolt passes through the boosting ship
			else:
				hurt_player(g, float(b.dmg))
				dead = true
		if dead:
			bolts.erase(b)


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
	if float(res.hull) > 0.0:
		hit_flash = 1.0
		AudioManager.play("hit")
	else:
		_ring = 1.0
	_burst(ship.position, 6, Color(0.6, 0.9, 1.0) if float(res.hull) <= 0.0 else Color(1.0, 0.5, 0.3), 140.0, 0.35)
	if res.destroyed:
		_wreck(g)


func _wreck(g) -> void:
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
			draw_line(b.pos - dir * 10.0, b.pos + dir * 6.0, Color(0.95, 0.95, 1.0), 4.0)
			draw_circle(b.pos + dir * 6.0, 3.0, Color(1.0, 0.4, 0.3))
		elif b.mine:
			draw_line(b.pos - dir * 12.0, b.pos + dir * 8.0, Color(0.4, 1.0, 0.9), 3.0)
			draw_line(b.pos - dir * 12.0, b.pos + dir * 8.0, Color(0.9, 1.0, 1.0), 1.0)
		else:
			draw_line(b.pos - dir * 10.0, b.pos + dir * 8.0, Color(1.0, 0.35, 0.3), 3.0)
			draw_line(b.pos - dir * 10.0, b.pos + dir * 8.0, Color(1.0, 0.85, 0.7), 1.0)
	for f in fx:
		var c: Color = f.color
		c.a *= clampf(f.life / f.max, 0.0, 1.0)
		draw_circle(f.pos, f.size, c)
	var g = GameState.game
	if g != null and ship != null and SpaceCombat.max_shield(g) > 0.0:
		var ratio := SpaceCombat.shield_ratio(g)
		if ratio > 0.0 or _ring > 0.0:
			var a := 0.12 + 0.5 * _ring + 0.15 * ratio
			draw_arc(ship.position, 30.0, 0.0, TAU, 40, Color(0.5, 0.85, 1.0, clampf(a, 0.0, 0.9)), 2.0 + 2.0 * _ring)
