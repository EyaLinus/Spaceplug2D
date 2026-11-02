extends Control
## Jump-drive visuals on top of the game: while the drive charges, star streaks stretch out of the screen centre and a
## charge bar fills; when the jump fires, a hyperspace tunnel with a loading card ("Jumping to ...") covers the
## screen and fades out onto the new system. Pure presentation: main.gd feeds `charge` and calls play_jump().

const UI = preload("res://scripts/ui/ui_theme.gd")

const STREAKS := 110

var charge := 0.0  ## 0..1 drive charge (0 = not charging)
var burst := 0.0  ## 0..1 jump tunnel intensity (1 = fully covered)
var loading := 0.0  ## 0..1 cosmetic loading bar of the transition card
var card := ""
var _dirs: Array = []  ## [angle, speed, phase, hue]
var _time := 0.0
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for i in STREAKS:
		_dirs.append([r.randf() * TAU, r.randf_range(0.5, 1.4), r.randf(), r.randf()])
	visible = false


## True while anything is drawn.
func active() -> bool:
	return charge > 0.0 or burst > 0.0


## The jump just happened: cover the screen, show the loading card, fade onto the new system.
func play_jump(dest_name: String, hold := 0.55, fade := 1.0) -> void:
	card = "HYPERSPACE\n%s" % dest_name
	if _tween != null:
		_tween.kill()
	burst = 1.0
	loading = 0.0
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "loading", 1.0, hold)
	_tween.tween_property(self, "burst", 0.0, fade).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): card = "")


func _process(delta: float) -> void:
	var on := active()
	if visible != on:
		visible = on
	if on:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var size_v := get_viewport_rect().size
	var c := size_v / 2.0
	var power := maxf(charge * charge * 0.45, burst)
	if power <= 0.0:
		return
	if burst > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size_v), Color(0.02, 0.04, 0.14, minf(1.0, burst * 1.15)))
	elif charge > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size_v), Color(0.1, 0.4, 0.6, 0.18 * charge))
	var reach := size_v.length() * 0.6
	for d in _dirs:
		var t := fposmod(_time * d[1] * (0.35 + power * 2.2) + d[2], 1.0)
		var r0 := reach * t * t
		var r1 := r0 + reach * (0.02 + 0.5 * power) * (0.3 + t)
		var dir := Vector2.from_angle(d[0])
		var col := Color(0.7, 0.95, 1.0).lerp(Color(0.8, 0.6, 1.0), d[3])
		col.a = clampf(t * (0.35 + power), 0.0, 1.0)
		draw_line(c + dir * r0, c + dir * r1, col, 1.0 + 2.0 * power * t)
	if burst > 0.0:
		for i in 8:  # soft glow around the vanishing point
			draw_circle(c, (40.0 + 300.0 * burst) * (1.0 - i * 0.11), Color(0.6, 0.85, 1.0, 0.045 * burst))
	if card != "" and burst > 0.25:
		var font := get_theme_default_font()
		var lines := card.split("\n")
		var a := minf(1.0, burst * 1.6)
		draw_string(font, Vector2(0, c.y - 70), lines[0], HORIZONTAL_ALIGNMENT_CENTER, size_v.x, 26, Color(UI.MUTED, a))
		draw_string(font, Vector2(0, c.y - 24), lines[1], HORIZONTAL_ALIGNMENT_CENTER, size_v.x, 44, Color(UI.ACCENT, a))
		var bw := 360.0
		var bx := c.x - bw / 2.0
		draw_rect(Rect2(bx, c.y + 20, bw, 8), Color(1, 1, 1, 0.15 * a))
		draw_rect(Rect2(bx, c.y + 20, bw * loading, 8), Color(UI.ACCENT, a))
	elif charge > 0.0 and burst <= 0.0:
		var font := get_theme_default_font()
		var bw := 300.0
		var by := size_v.y - 120.0
		draw_string(font, Vector2(0, by - 10), "JUMP DRIVE  %d%%" % int(charge * 100.0), HORIZONTAL_ALIGNMENT_CENTER, size_v.x, 18, UI.ACCENT)
		draw_rect(Rect2(c.x - bw / 2.0, by, bw, 8), Color(1, 1, 1, 0.15))
		draw_rect(Rect2(c.x - bw / 2.0, by, bw * charge, 8), UI.ACCENT)
