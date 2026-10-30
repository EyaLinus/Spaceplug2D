extends Control
## Base class for the hands-on station minigames (trim, measure, pour, heat, pack).
## A minigame gets a context from MinigameRunner via setup(), runs its own logic in step(dt), draws itself in _draw()
## and emits `finished(score)` once with a score 0..1. Input comes in through press()/key(): the runner forwards keys,
## mouse buttons arrive via _gui_input. bot_input(dt) plays like a skilled player so tests can drive every minigame.
## New station: subclass this, implement the hooks below, register it in registry.gd and data/content.json.

signal finished(score: float)

const AREA := Vector2(820, 330)
const FG := Color("#e6e9ff")
const MUTED := Color("#8a90b8")
const GOOD := Color("#4fe3c1")
const BAD := Color("#ff6b5f")
const GOLD := Color("#ffd166")
const DARK := Color("#0a0d1c")

var ctx: Dictionary = {}  ## {base, tier, additives, qty, data, seed}
var rng := RandomNumberGenerator.new()
var done := false
var score := 0.0
var holding := false
var duration := 10.0
var time_left := 10.0
var elapsed := 0.0


func setup(c: Dictionary) -> void:
	ctx = c
	rng.seed = int(c.get("seed", 1))
	custom_minimum_size = AREA
	size = AREA
	mouse_filter = Control.MOUSE_FILTER_STOP
	time_left = duration
	_begin()
	time_left = duration


func tier() -> int:
	return int(ctx.get("tier", 1))


# ---------------------------------------------------------------- hooks for subclasses

func _begin() -> void:
	pass


func _tick(_dt: float) -> void:
	pass


## Primary action (Space / left mouse). pos is local, or Vector2(-1, -1) when it came from the keyboard.
func _primary(_pressed: bool, _pos: Vector2) -> void:
	pass


## Secondary action (Backspace / right mouse).
func _secondary() -> void:
	pass


## Enter: confirm (only some minigames use it).
func _confirm() -> void:
	pass


## Score if the timer runs out right now.
func _timeout_score() -> float:
	return 0.0


## One line under the minigame (progress, current reading).
func status_text() -> String:
	return ""


func bot_input(_dt: float) -> void:
	pass


# ---------------------------------------------------------------- driving

func step(dt: float) -> void:
	if done:
		return
	elapsed += dt
	time_left -= dt
	_tick(dt)
	if not done and time_left <= 0.0:
		finish(_timeout_score())


func finish(s: float) -> void:
	if done:
		return
	done = true
	holding = false
	score = clampf(s, 0.0, 1.0)
	finished.emit(score)


func press(pressed: bool, pos: Vector2 = Vector2(-1, -1)) -> void:
	if done:
		return
	holding = pressed
	_primary(pressed, pos)


## Keys forwarded by the runner. Returns true when the key belongs to the minigame.
func key(keycode: int, pressed: bool) -> bool:
	match keycode:
		KEY_SPACE:
			press(pressed)
		KEY_BACKSPACE:
			if pressed and not done:
				_secondary()
		KEY_ENTER, KEY_KP_ENTER:
			if pressed and not done:
				_confirm()
		_:
			return false
	return true


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			press(ev.pressed, ev.position)
			accept_event()
		elif ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed and not done:
			_secondary()
			accept_event()


func _process(dt: float) -> void:
	step(dt)
	queue_redraw()


# ---------------------------------------------------------------- drawing helpers

func text(pos: Vector2, s: String, font_size := 16, color := FG, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, align, width, font_size, color)


func timer_bar() -> void:
	var r := Rect2(20, AREA.y - 18, AREA.x - 40, 8)
	draw_rect(r, DARK)
	var f := clampf(time_left / duration, 0.0, 1.0)
	draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), GOLD if f > 0.25 else BAD)


static func band_score(value: float, center: float, half_width: float, falloff: float) -> float:
	var d := absf(value - center)
	if d <= half_width:
		return 1.0 - 0.15 * d / half_width
	return clampf(0.85 - (d - half_width) / falloff, 0.0, 0.85)


## Sound effect that also works outside the scene tree (unit tests drive minigames without autoloads).
func sfx(sound: String) -> void:
	var am := get_node_or_null("/root/AudioManager") if is_inside_tree() else null
	if am != null:
		am.play(sound)
