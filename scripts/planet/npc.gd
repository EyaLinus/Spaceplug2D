extends Node2D
## A person on a planet surface. Named people walk their schedule and show their name (unknown townsfolk show
## their job up close instead); officers patrol the road network the surface hands them. Sprite from the art registry
## (look picked from `color` unless set), procedural body as fallback.

const Art = preload("res://scripts/core/art.gd")

var display_name := ""
var subtitle := ""  ## grey line shown when there is no name (an unmet local's job, up close)
var color := Color("#8fb3ff")
var speed := 55.0
var path: Array = []  ## Vector2 waypoints still to walk
var pick_next: Callable  ## returns a new path when this one is done (walkers only)
var look := ""  ## character sheet name in assets/gfx/chars; "" = closest npc_* look to `color`
var hold := false  ## named people stop walking while the player stands next to them
var marker := false  ## gold "$" above the head: you have an agreed deal with this person
var bubble := ""  ## speech bubble text: a customer on foot asking for product (walkups.gd)
var sheet: Texture2D  ## recoloured sheet (hired workers); null = the plain look sheet
var heading := Vector2.DOWN  ## last walking direction, picks the sprite row
var chat := ""  ## idle chatter line shown above the head (chatter.gd)
var chat_t := 0.0  ## seconds the chatter bubble stays
var _step := 0.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	chat_t = maxf(0.0, chat_t - delta)
	if path.is_empty() and pick_next.is_valid():
		path = pick_next.call(position)
	if not path.is_empty() and not hold:
		var target: Vector2 = path[0]
		var to := target - position
		if to.length() < 3.0:
			path.pop_front()
		else:
			position += to.normalized() * minf(speed * delta, to.length())
			heading = to.normalized()
			_step += delta * 9.0
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, 12), 8.0, Color(0, 0, 0, 0.28))
	var moving := not path.is_empty() and not hold
	if look == "":  # people without a profile look match their data colour
		look = Art.look_for_color(color)
	if Art.draw_character(self, look, heading, int(_step * 4.0 / TAU) if moving else 0, Vector2(0, 12), sheet):
		_draw_name()
		return
	var swing := sin(_step) * 3.5 if moving else 0.0
	var leg := color.darkened(0.6)
	draw_line(Vector2(-3, 4), Vector2(-3 + swing * 0.3, 12), leg, 3.0)
	draw_line(Vector2(3, 4), Vector2(3 - swing * 0.3, 12), leg, 3.0)
	draw_rect(Rect2(-6, -6, 12, 11), color)
	draw_rect(Rect2(-6, -6, 12, 11), color.darkened(0.5), false, 1.5)
	var idle := sin(_t * 2.0) * 0.8 if not moving else 0.0
	draw_circle(Vector2(0, -11 + idle), 5.5, Color("#c99b78"))
	_draw_name()


## Shows a speech bubble for `secs` seconds.
func say(text: String, secs: float) -> void:
	if bubble != "":
		return  # a customer on foot already shows a deal bubble
	chat = text
	chat_t = secs


func _draw_bubble() -> void:
	if bubble != "" or chat == "" or chat_t <= 0.0:
		return
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(chat, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var a := minf(1.0, chat_t * 3.0)  # fades out
	var r := Rect2(-w / 2.0 - 5, -58, w + 10, 17)
	draw_rect(r, Color(0.96, 0.96, 0.98, 0.92 * a))
	draw_rect(r, Color(0.2, 0.2, 0.28, a), false, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -41), Vector2(3, -41), Vector2(0, -36)]), Color(0.96, 0.96, 0.98, 0.92 * a))
	draw_string(f, Vector2(-w / 2.0, -45), chat, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.1, 0.1, 0.16, a))


func _draw_name() -> void:
	if bubble != "":
		var bf := ThemeDB.fallback_font
		var bw := bf.get_string_size(bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0
		var by := -64.0 + sin(_t * 3.0) * 1.5
		draw_rect(Rect2(-bw / 2.0, by, bw, 20), Color(0.08, 0.1, 0.14, 0.92))
		draw_rect(Rect2(-bw / 2.0, by, bw, 20), Color("#ffd166"), false, 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(-4, by + 20), Vector2(4, by + 20), Vector2(0, by + 27)]), Color("#ffd166"))
		draw_string(bf, Vector2(-bw / 2.0 + 7.0, by + 14.5), bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ffe9b0"))
	_draw_bubble()
	if marker:
		var f := ThemeDB.fallback_font
		var bob := sin(_t * 4.0) * 2.0
		draw_string(f, Vector2(-5, -38 + bob), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0, 0, 0, 0.6))
		draw_string(f, Vector2(-6, -39 + bob), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ffd166"))
	if display_name == "" and subtitle != "":
		var sf := ThemeDB.fallback_font
		var sw := sf.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(sf, Vector2(-sw / 2.0 + 1, -21), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.6))
		draw_string(sf, Vector2(-sw / 2.0, -22), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.85, 0.8))
	if display_name != "":
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2(-w / 2.0 + 1, -21), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(-w / 2.0, -22), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color.lightened(0.4))
