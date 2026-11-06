extends Node2D
## The NPC freighter of an escort job, in the world. Geometry only: it flies between the route's locations as far as
## the core says (Escort.progress), measures "is the player near" and "which raiders sit on top of her" and hands
## both to Escort.tick; raids are spawned from the core's decision. Rules: scripts/core/escort.gd.

const Escort = preload("res://scripts/core/escort.gd")
const Cartels = preload("res://scripts/core/cartels.gd")

var world: Node2D
var ship: Node2D
var combat: Node2D
var radius := 26.0
var hull_ratio := 1.0
var shown := false
var flash := 0.0


func setup(w: Node2D, s: Node2D, c: Node2D) -> void:
	world = w
	ship = s
	combat = c
	z_index = 4
	visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Called once per physics frame while the ship is flying.
func step(delta: float, g) -> void:
	if not Escort.enroute(g):
		_hide()
		return
	var a := Escort.active(g)
	var from_n: Node2D = world.locations.get(Escort.leg_from(g))
	var to_n: Node2D = world.locations.get(Escort.leg_to(g))
	var kind := Escort.current_kind(g)
	var pos := position
	var in_system: bool = from_n != null and Escort.freighter_system(g) == world.system
	if in_system:
		var start: Vector2 = from_n.position + Vector2(0, from_n.radius + 90.0)
		if kind == "fly" and to_n != null:
			var dir: Vector2 = (to_n.position - start).normalized()
			var stop: Vector2 = to_n.position - dir * (to_n.radius + 90.0)
			pos = start.lerp(stop, clampf(float(a.progress), 0.0, 1.0))
			rotation = dir.angle() + PI / 2.0
		else:
			pos = start + Vector2(60, 0)  # hovers by the gate until you jump
		if not shown:
			position = pos
		position = position.lerp(pos, clampf(4.0 * delta, 0.0, 1.0))
	shown = in_system
	visible = in_system
	var near: bool = in_system and position.distance_to(ship.position) < float(Escort.rules(g).get("near_radius", 900.0))
	var kinds: Array = []
	if in_system:
		for p in combat.pirates:
			if p.position.distance_to(position) < float(Escort.rules(g).get("raid_radius", 650.0)):
				kinds.append(p.kind)
	var hull_before := float(a.hull)
	Escort.tick(g, delta, near, Escort.threat_of(g, kinds))
	if not Escort.is_active(g):
		_hide()
		return
	if float(a.hull) < hull_before:
		flash = 0.15
	flash = maxf(0.0, flash - delta)
	hull_ratio = Escort.hull_ratio(g)
	var raid := Escort.take_raid(g)
	if not raid.is_empty():
		combat.spawn_wing(g, str(raid.cartel), raid.units)
		var who: String = str(Cartels.gang(g, str(raid.cartel)).get("name", "Raiders")) if raid.cartel != "" else "Raiders"
		EventBus.toast.emit("%s go for the freighter: %d ships!" % [who, (raid.units as Array).size()], false)
	queue_redraw()


func _hide() -> void:
	shown = false
	visible = false


func _draw() -> void:
	var body := PackedVector2Array([Vector2(0, -34), Vector2(16, -8), Vector2(20, 28), Vector2(-20, 28), Vector2(-16, -8)])
	var col := Color("#c9d2e3").lerp(Color("#ff6b5f"), flash / 0.15 if flash > 0.0 else 0.0)
	draw_colored_polygon(body, col)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, Color("#3b4358"), 2.0)
	draw_rect(Rect2(-8, 4, 16, 12), Color("#4fe3c1", 0.7))
	draw_circle(Vector2(0, 28), 5.0, Color(1.0, 0.8, 0.4, 0.8))
	draw_rect(Rect2(-22, 36, 44, 5), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-22, 36, 44.0 * hull_ratio, 5), Color("#4fe3c1").lerp(Color("#ff6b5f"), 1.0 - hull_ratio))
