extends "res://scripts/ui/minigames/station_minigame.gd"
## Refiner: keep a reaction in equilibrium. The reaction pulls the needle to one side (the pull flips a couple of times
## per run, and it runs away faster the further it is off balance); Space/left click doses acid (needle up), Backspace/right click doses base (needle down). A dose only acts
## after a short delay and the reagent supply is limited, so you have to dose ahead instead of mashing.
## Score = share of the run with the needle in the green band. Affects purity.

const DELAY := 0.5
const PUSH := 0.35  ## push per dose; it decays, so one dose moves the needle ~0.15 in total
const DECAY := 0.1  ## push left after one second

var x := 0.0  ## -1 (too basic) .. +1 (too acidic)
var half := 0.18
var pull := 0.0
var pull_target := 0.0  ## the pull drifts towards this; it flips a couple of times per run
var push := 0.0
var pending: Array = []  ## [[seconds left, +1 acid / -1 base], ...]
const SUPPLY := 14
const RUNAWAY := 0.5  ## the further off balance, the faster the reaction runs away

var acid := SUPPLY
var base := SUPPLY
var in_band := 0.0
var _flips: Array = []
var _wobble := 0.0
var _bot_cd := 0.0


func _begin() -> void:
	duration = 10.0
	half = 0.16 - 0.015 * (tier() - 1)
	pull = rng.randf_range(0.16, 0.24) * (1.0 if rng.randf() < 0.5 else -1.0)
	pull_target = pull
	_flips = [rng.randf_range(2.5, 4.5), rng.randf_range(6.0, 8.0)]


func dose(sign_dir: int) -> void:
	if sign_dir > 0:
		if acid <= 0:
			sfx("error")
			return
		acid -= 1
	else:
		if base <= 0:
			sfx("error")
			return
		base -= 1
	pending.append([DELAY, sign_dir])
	sfx("click")


func _primary(pressed: bool, _pos: Vector2) -> void:
	if pressed:
		dose(1)


func _secondary() -> void:
	dose(-1)


func _tick(dt: float) -> void:
	if not _flips.is_empty() and elapsed >= float(_flips[0]):
		_flips.pop_front()
		pull_target = -signf(pull_target) * rng.randf_range(0.16, 0.24)
	pull = move_toward(pull, pull_target, 0.4 * dt)
	_wobble = lerpf(_wobble, rng.randf_range(-0.3, 0.3), dt * 1.5)
	for p in pending:
		p[0] -= dt
		if p[0] <= 0.0:
			push += PUSH * float(p[1])
	pending = pending.filter(func(p: Array) -> bool: return p[0] > 0.0)
	x = clampf(x + (pull + x * RUNAWAY + _wobble * 0.3 + push) * dt, -1.0, 1.0)
	push *= pow(DECAY, dt)
	if absf(x) <= half:
		in_band += dt


func _timeout_score() -> float:
	return in_band / duration * 1.1


func status_text() -> String:
	var state := "in equilibrium" if absf(x) <= half else ("too acidic" if x > 0.0 else "too basic")
	return "In equilibrium: %d%% · %s · acid %d · base %d" % [int(in_band / maxf(elapsed, 0.01) * 100.0), state, acid, base]


## Needle position `h` seconds ahead with the doses already in flight and no new ones (no random wobble).
func predict(h: float) -> float:
	var px := x
	var pp := push
	var pend: Array = pending.duplicate(true)
	var dt := 1.0 / 30.0
	var t := 0.0
	while t < h:
		for p in pend:
			p[0] -= dt
			if p[0] <= 0.0:
				pp += PUSH * float(p[1])
				p[1] = 0
		px = clampf(px + (pull + px * RUNAWAY + pp) * dt, -1.0, 1.0)
		pp *= pow(DECAY, dt)
		t += dt
	return px


func bot_input(dt: float) -> void:
	_bot_cd -= dt
	if _bot_cd > 0.0:
		return
	var aim := (predict(DELAY + 0.2) + predict(DELAY + 1.0)) / 2.0
	if aim < -half * 0.6:
		dose(1)
		_bot_cd = 0.2
	elif aim > half * 0.6:
		dose(-1)
		_bot_cd = 0.2


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, AREA), Color("#161420"))
	# reaction meter across the top
	var m := Rect2(110, 56, 600, 26)
	draw_rect(m, DARK)
	var mx := func(v: float) -> float: return m.position.x + m.size.x * (v + 1.0) / 2.0
	draw_rect(Rect2(m.position, Vector2(m.size.x * 0.5 - m.size.x * half / 2.0, m.size.y)), Color("#5a7dff", 0.25))
	draw_rect(Rect2(Vector2(mx.call(half), m.position.y), Vector2(m.end.x - mx.call(half), m.size.y)), Color(BAD, 0.25))
	draw_rect(Rect2(Vector2(mx.call(-half), m.position.y), Vector2(m.size.x * half, m.size.y)), Color(GOOD, 0.45))
	var nx: float = mx.call(x)
	draw_rect(Rect2(nx - 3, m.position.y - 8, 6, m.size.y + 16), GOLD)
	var arrow := Vector2(mx.call(clampf(x + pull * 0.6, -1.0, 1.0)), m.end.y + 14)
	draw_line(Vector2(nx, arrow.y), arrow, Color(1, 1, 1, 0.35), 2.0)
	text(Vector2(m.position.x - 90, m.end.y - 6), "BASE", 15, Color("#8fb0ff"))
	text(Vector2(m.end.x + 12, m.end.y - 6), "ACID", 15, BAD)
	# beaker: the liquid colour follows the needle
	var bk := Rect2(340, 130, 140, 150)
	var liquid := GOOD
	if x > 0.0:
		liquid = GOOD.lerp(BAD, clampf(x, 0.0, 1.0))
	else:
		liquid = GOOD.lerp(Color("#5a7dff"), clampf(-x, 0.0, 1.0))
	draw_rect(Rect2(bk.position + Vector2(6, 40), bk.size - Vector2(12, 46)), Color(liquid, 0.7))
	for i in 6:
		var bx := bk.position.x + 20 + fmod(i * 41.0 + elapsed * 25.0, bk.size.x - 40)
		draw_circle(Vector2(bx, bk.position.y + 60 + sin(elapsed * 4.0 + i) * 20.0 + i * 8.0), 3.0, Color(1, 1, 1, 0.35))
	draw_rect(bk, Color("#9aa0ad"), false, 3.0)
	# reagent bottles with what is left, drops in flight
	_bottle(Vector2(170, 150), BAD, "ACID [Space]", acid)
	_bottle(Vector2(560, 150), Color("#5a7dff"), "BASE [Bksp]", base)
	for p in pending:
		var f := 1.0 - float(p[0]) / DELAY
		var from := Vector2(225, 150) if int(p[1]) > 0 else Vector2(595, 150)
		draw_circle(from.lerp(Vector2(410, 165), f), 5.0, BAD if int(p[1]) > 0 else Color("#5a7dff"))
	text(Vector2(20, 28), "Hold the reaction in equilibrium", 18, GOOD)
	text(Vector2(20, AREA.y - 30), status_text(), 15, MUTED)
	timer_bar()


func _bottle(p: Vector2, c: Color, label: String, left: int) -> void:
	draw_rect(Rect2(p + Vector2(18, 0), Vector2(20, 18)), Color("#5a5f7a"))
	var body := Rect2(p + Vector2(0, 18), Vector2(56, 90))
	draw_rect(body, Color("#26323a"))
	var f := clampf(float(left) / SUPPLY, 0.0, 1.0)
	draw_rect(Rect2(body.position.x + 4, body.end.y - 4 - 82 * f, 48, 82 * f), Color(c, 0.75))
	draw_rect(body, Color("#9aa0ad"), false, 2.0)
	text(Vector2(p.x - 20, body.end.y + 22), label, 14, c)
