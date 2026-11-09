extends CanvasLayer
## On-foot combat overlay in screen space: health bar, weapon and magazine, crosshair at the mouse, reload bar,
## hurt vignette and the weapon wheel (hold the wheel key). It only reads the surface and the core Game.

const Combat = preload("res://scripts/core/combat.gd")
const Art = preload("res://scripts/core/art.gd")

var surface: Node2D
var _canvas: Control


func _ready() -> void:
	layer = 5
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


func _process(_delta: float) -> void:
	_canvas.queue_redraw()


## Screen position of wheel sector `i` of `n` (sector 0 at the top, clockwise), relative to the wheel centre.
static func sector_dir(i: int, n: int) -> Vector2:
	return Vector2.UP.rotated(TAU * float(i) / float(maxi(n, 1)))


## Sector the mouse offset `d` points at; -1 inside the dead zone.
static func sector_at(d: Vector2, n: int, dead: float = 36.0) -> int:
	if d.length() < dead or n <= 0:
		return -1
	var a := fposmod(Vector2.UP.angle_to(d), TAU)
	return int(round(a / (TAU / float(n)))) % n


func _draw_hud() -> void:
	var g = GameState.game
	if g == null or surface == null or GameState.paused:
		return
	var font := ThemeDB.fallback_font
	var vp := _canvas.size
	var w := Combat.weapon(g.data, g.weapon)
	# hurt vignette
	var hurt: float = surface.hurt
	if hurt > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.8, 0.05, 0.05, minf(0.35, hurt * 0.5)))
	# health and weapon (above the controls help line)
	var base := Vector2(14, vp.y - 82)
	var frac: float = clampf(g.hp / Combat.max_hp(g), 0.0, 1.0)
	_canvas.draw_rect(Rect2(base, Vector2(180, 14)), Color(0, 0, 0, 0.6))
	_canvas.draw_rect(Rect2(base, Vector2(180.0 * frac, 14)), Color("#ff6b5f").lerp(Color("#4fe3c1"), frac))
	_canvas.draw_rect(Rect2(base, Vector2(180, 14)), Color(1, 1, 1, 0.35), false, 1.0)
	_canvas.draw_string(font, base + Vector2(6, 12), "HP %d" % ceili(g.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	if not w.is_empty():
		var txt: String = "%s  %d/%d" % [w.name, int(g.ammo.get(g.weapon, 0)), int(w.mag)]
		if g.reload_left > 0.0:
			txt += "  reloading"
		var wi0: Texture2D = Art.icon_for("wpn_" + str(g.weapon))
		if wi0 != null:
			_canvas.draw_texture(wi0, base + Vector2(0, 17))
		_canvas.draw_string(font, base + Vector2(36 if wi0 != null else 0, 32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffd166"))
	# crosshair
	if surface.use_mouse and not surface.player.frozen and not surface.wheel_open:
		var m := get_viewport().get_mouse_position()
		var col: Color = Color(1, 1, 1, 0.85) if g.reload_left <= 0.0 and g.cooldown <= 0.0 else Color(1, 1, 1, 0.4)
		_canvas.draw_arc(m, 9.0, 0, TAU, 20, col, 1.5)
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			_canvas.draw_line(m + dir * 4.0, m + dir * 14.0, col, 1.5)
		if g.reload_left > 0.0 and not w.is_empty():
			var p: float = 1.0 - g.reload_left / float(w.reload)
			_canvas.draw_arc(m, 17.0, -PI / 2.0, -PI / 2.0 + TAU * p, 24, Color("#ffd166"), 3.0)
	if surface.wheel_open:
		_draw_wheel(g, font, vp)


func _draw_wheel(g, font: Font, vp: Vector2) -> void:
	var ids: Array = Combat.weapon_ids(g.data)
	var c := vp / 2.0
	_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.35))
	_canvas.draw_circle(c, 150.0, Color(0.05, 0.07, 0.1, 0.75))
	_canvas.draw_arc(c, 150.0, 0, TAU, 48, Color(1, 1, 1, 0.3), 2.0)
	for i in ids.size():
		var id: String = ids[i]
		var w := Combat.weapon(g.data, id)
		var p: Vector2 = c + sector_dir(i, ids.size()) * 95.0
		var owned := Combat.owns(g, id)
		var sel: bool = i == surface.wheel_sel
		var box := Rect2(p - Vector2(58, 30), Vector2(116, 60))
		_canvas.draw_rect(box, Color(0.31, 0.89, 0.76, 0.35) if sel else Color(1, 1, 1, 0.08))
		_canvas.draw_rect(box, Color("#4fe3c1") if id == g.weapon else Color(1, 1, 1, 0.35), false, 2.0 if id == g.weapon else 1.0)
		var wi: Texture2D = Art.icon_for("wpn_" + id)
		if wi != null:
			_canvas.draw_texture(wi, box.position + Vector2(box.size.x - 36, 14), Color.WHITE if owned else Color(1, 1, 1, 0.45))
		_canvas.draw_string(font, box.position + Vector2(8, 20), "%d  %s" % [i + 1, w.name], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE if owned else Color(1, 1, 1, 0.5))
		var sub: String = "%d/%d" % [int(g.ammo.get(id, 0)), int(w.mag)] if owned else "buy %d cr" % int(w.price)
		var afford: bool = owned or g.credits >= int(w.price)
		_canvas.draw_string(font, box.position + Vector2(8, 42), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffd166") if afford else Color("#ff6b5f"))
	_canvas.draw_string(font, c + Vector2(-60, 4), "release to pick", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))
