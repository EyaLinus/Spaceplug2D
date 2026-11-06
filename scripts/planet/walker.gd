extends CharacterBody2D
## Player on foot: 8-direction top-down walking with collision. Sprite sheet from the art registry,
## procedural body as fallback.

const Art = preload("res://scripts/core/art.gd")
const Style = preload("res://scripts/core/style.gd")
const SPEED := 170.0
const SPRINT := 1.6  ## speed factor while the sprint key is held (planets are big)
const RADIUS := 9.0

var frozen := false  ## true while a panel is open or the game is paused
var facing := Vector2.DOWN
var aim_dir := Vector2.ZERO  ## set while shooting: the sprite looks at the mouse instead of the walking direction
var flash := 0.0  ## hurt flash (seconds)
var sprinting := false
var _step := 0.0
var _moving := false
var idle_sheet: Texture2D  ## the same recolour of the idle sheet
var sheet: Texture2D  ## K2: player sheet recoloured to your look (null = stock art)


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	shape.position = Vector2(0, 4)  # feet, so the head can overlap walls a bit like in RPG-Maker games
	add_child(shape)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	refresh_look()
	EventBus.game_event.connect(func(kind: String, _p: Dictionary): if kind == "style_changed": refresh_look())


func refresh_look() -> void:
	var g = GameState.game
	var swaps: Dictionary = Style.player_swaps(g.data, g.style) if g != null else {}
	sheet = Art.recolored("chars/player.png", swaps) if g != null else null
	idle_sheet = Art.recolored("chars/player_idle.png", swaps) if g != null else null
	queue_redraw()


func _physics_process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	if frozen:
		_moving = false
		velocity = Vector2.ZERO
		queue_redraw()
		return
	sprinting = InputMap.has_action("sprint") and Input.is_action_pressed("sprint")
	walk(delta, Input.get_vector("move_left", "move_right", "move_up", "move_down"))


## One movement step; split out so the UI smoke test can walk without key input.
func walk(delta: float, dir: Vector2) -> void:
	_moving = dir.length() > 0.1
	if _moving:
		facing = dir.normalized()
		_step += delta * (11.0 * (SPRINT if sprinting else 1.0))
	velocity = dir.limit_length(1.0) * SPEED * (SPRINT if sprinting else 1.0)
	move_and_slide()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, 12), 9.0, Color(0, 0, 0, 0.3))
	var look := aim_dir if aim_dir != Vector2.ZERO else facing
	if flash > 0.0:
		draw_circle(Vector2(0, 0), 13.0, Color(1, 0.2, 0.2, minf(0.5, flash * 2.0)))
	if Art.draw_character(self, "player", look, int(_step * 4.0 / TAU) if _moving else 0, Vector2(0, 12), sheet,
			-1.0 if _moving else Time.get_ticks_msec() / 1000.0, idle_sheet):
		return
	var swing := sin(_step) * 4.0 if _moving else 0.0
	var leg := Color("#2a2f45")
	draw_line(Vector2(-3, 4), Vector2(-3 + swing * 0.3, 12 + swing * 0.2), leg, 3.0)
	draw_line(Vector2(3, 4), Vector2(3 - swing * 0.3, 12 - swing * 0.2), leg, 3.0)
	var coat := Color("#ffd166")
	draw_rect(Rect2(-6, -6, 12, 12), coat)
	draw_rect(Rect2(-6, -6, 12, 12), coat.darkened(0.5), false, 1.5)
	var bob := absf(sin(_step)) * 1.5 if _moving else 0.0
	var head := Vector2(0, -11 - bob)
	draw_circle(head, 6.0, Color("#e8b48a"))
	# eyes show the facing direction; hidden when walking away from the camera
	if facing.y > -0.5:
		var off := Vector2(facing.x * 2.5, 1.0)
		draw_circle(head + off + Vector2(-2, 0), 1.1, Color("#1a1a22"))
		draw_circle(head + off + Vector2(2, 0), 1.1, Color("#1a1a22"))
	draw_arc(head, 6.0, PI, TAU, 12, Color("#3b2a20"), 3.0)
