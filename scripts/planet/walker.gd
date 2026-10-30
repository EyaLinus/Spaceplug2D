extends CharacterBody2D
## Player on foot: 8-direction top-down walking with collision. Drawn procedurally (body, head, swinging legs).

const SPEED := 170.0
const RADIUS := 9.0

var frozen := false  ## true while a panel is open or the game is paused
var facing := Vector2.DOWN
var _step := 0.0
var _moving := false


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	shape.position = Vector2(0, 4)  # feet, so the head can overlap walls a bit like in RPG-Maker games
	add_child(shape)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	if frozen:
		_moving = false
		velocity = Vector2.ZERO
		queue_redraw()
		return
	walk(delta, Input.get_vector("move_left", "move_right", "move_up", "move_down"))


## One movement step; split out so the UI smoke test can walk without key input.
func walk(delta: float, dir: Vector2) -> void:
	_moving = dir.length() > 0.1
	if _moving:
		facing = dir.normalized()
		_step += delta * 11.0
	velocity = dir.limit_length(1.0) * SPEED
	move_and_slide()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, 12), 9.0, Color(0, 0, 0, 0.3))
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
