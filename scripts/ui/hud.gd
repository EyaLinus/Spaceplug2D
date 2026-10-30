extends Control
## In-flight HUD: money, debt, day clock, heat, cargo, lab status, dock prompt, scan warning, toasts, minimap.
## On a planet surface the prompt, minimap and controls help switch to the on-foot versions.

const UI = preload("res://scripts/ui/ui_theme.gd")
const Art = preload("res://scripts/core/art.gd")

var world: Node2D
var surface: Node2D  ## set by main while on foot, null in space
var _flight_help: Label
var _foot_help: Label
var _credits: Label
var _debt: Label
var _day: Label
var _day_bar: ProgressBar
var _heat: ProgressBar
var _heat_label: Label
var _cargo: Label
var _lab: Label
var _prompt: Label
var _scan_box: VBoxContainer
var _scan_bar: ProgressBar
var _scan_label: Label
var _toasts: VBoxContainer
var _minimap: Control
var _nav: Control  ## edge arrows pointing at off-screen locations


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 8
	add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	top.add_child(row)
	_credits = UI.label("", 19, UI.GOLD)
	_debt = UI.label("", 17, UI.WARN)
	_day = UI.label("", 17)
	_day_bar = UI.bar(UI.MUTED)
	_day_bar.custom_minimum_size.x = 90
	_heat_label = UI.label("Heat", 17)
	_heat = UI.bar(UI.WARN)
	_heat.max_value = 100
	_cargo = UI.label("", 17)
	_lab = UI.label("", 17, UI.ACCENT)
	var icons := {_credits: "hud_credits", _day: "hud_day", _heat_label: "hud_heat", _cargo: "up_cargo"}
	for c in [_credits, _debt, _day, _day_bar, _heat_label, _heat, _cargo, _lab]:
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(Art.with_icon(icons[c], c) if icons.has(c) else c)

	_prompt = UI.label("", 22, UI.ACCENT)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.offset_top = -90
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	add_child(_prompt)

	_scan_box = VBoxContainer.new()
	_scan_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_scan_box.offset_top = 80
	_scan_box.offset_left = -170
	_scan_box.offset_right = 170
	_scan_label = UI.label("! AUTHORITY SCAN – GET OUT OF RANGE !", 18, UI.WARN)
	_scan_box.add_child(_scan_label)
	_scan_bar = UI.bar(UI.WARN)
	_scan_bar.max_value = 1.0
	_scan_bar.custom_minimum_size = Vector2(340, 18)
	_scan_box.add_child(_scan_bar)
	_scan_box.visible = false
	add_child(_scan_box)

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_toasts.offset_top = 110
	_toasts.offset_left = -420
	_toasts.offset_right = -12
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	_nav = Control.new()
	_nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_nav)
	_nav.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_nav.draw.connect(_draw_nav)
	move_child(_nav, 0)

	_minimap = Control.new()
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_minimap.offset_left = -200
	_minimap.offset_top = -200
	_minimap.offset_right = -12
	_minimap.offset_bottom = -12
	_minimap.draw.connect(_draw_minimap)
	add_child(_minimap)

	var help := UI.label("", 14, UI.MUTED)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 12
	help.offset_top = -30
	add_child(help)
	_flight_help = help
	_foot_help = UI.label("", 14, UI.MUTED)
	_foot_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_foot_help.offset_left = 12
	_foot_help.offset_top = -30
	_foot_help.visible = false
	add_child(_foot_help)
	_refresh_help()
	Settings.changed.connect(_refresh_help)

	EventBus.toast.connect(show_toast)
	EventBus.scan_progress.connect(func(r: float):
		_scan_box.visible = r > 0.0
		_scan_bar.value = r)
	EventBus.game_event.connect(_on_game_event)


func _process(_delta: float) -> void:
	var g = GameState.game
	if g == null:
		return
	_credits.text = "%d cr" % g.credits
	_debt.text = "Debt %d cr · due day %d" % [g.debt, g.debt_due_day] if g.debt > 0 else "Debt cleared"
	_day.text = "Day %d" % g.day
	_day_bar.value = g.day_time / g.day_seconds() * 100.0
	_heat.value = g.heat
	_heat_label.text = "Heat %d · %d patrol%s" % [int(g.heat), g.patrol_count(), "" if g.patrol_count() == 1 else "s"]
	_cargo.text = "Cargo %d/%d%s" % [g.cargo_used(), g.cargo_capacity(), "  ⚠" if g.has_contraband() else ""]
	if g.lab_queue.is_empty():
		var stashed := 0
		for k in g.stash:
			stashed += int(g.stash[k])
		_lab.text = "Lab idle" + (" · %d ready" % stashed if stashed > 0 else "")
	else:
		var job: Dictionary = g.lab_queue[0]
		_lab.text = "Lab %d%% (%d queued)" % [int((1.0 - job.remaining / job.total) * 100.0), g.lab_queue.size()]
	_scan_label.text = "! OFFICER FRISKING YOU – GET OUT OF SIGHT !" if surface != null else "! AUTHORITY SCAN – GET OUT OF RANGE !"
	_flight_help.visible = surface == null
	_foot_help.visible = surface != null
	if surface != null:
		_prompt.text = surface.prompt()
	elif world != null and world.active and world.nearby != "":
		_prompt.text = "[%s] Dock at %s" % [Settings.key_label("ship_dock"), g.data.locations[world.nearby].name]
	else:
		_prompt.text = ""
	_minimap.queue_redraw()
	_nav.queue_redraw()


func show_toast(text: String, good: bool = true) -> void:
	var l := UI.label(text, 16, UI.TEXT if good else UI.WARN)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toasts.add_child(l)
	while _toasts.get_child_count() > 6:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


func _on_game_event(kind: String, p: Dictionary) -> void:
	var g = GameState.game
	match kind:
		"lab_done":
			show_toast("Lab: %d × %s ready in your stash." % [p.qty, g.item_name(p.product)])
		"new_day":
			show_toast("Day %d begins. %d days until the Consortium collects." % [p.day, maxi(0, g.debt_due_day - p.day + 1)] if g.debt > 0 else "Day %d begins." % p.day)
		"rumour":
			var up: bool = p.demand >= 1.0
			show_toast("Rumour: %s demand %s at %s." % [g.data.bases[p.base].name, "hot" if up else "cooling", g.data.locations[p.location].name])
		"heat_level":
			if p.heat >= float(g.data.heat.chase_heat):
				show_toast("Heat %d: patrols will hunt you." % int(p.heat), false)


func _draw_minimap() -> void:
	if world == null or GameState.game == null:
		return
	if surface != null:
		_draw_surface_map()
		return
	var size := _minimap.size
	_minimap.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.15, 0.85))
	_minimap.draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.4, 0.8, 0.6), false, 1.5)
	var scale: float = size.x / (world.SECTOR_HALF * 2.0)
	var to_map := func(p: Vector2) -> Vector2: return (p + Vector2(world.SECTOR_HALF, world.SECTOR_HALF)) * scale
	for id in world.locations:
		var n = world.locations[id]
		_minimap.draw_circle(to_map.call(n.position), maxf(3.0, n.radius * scale), Color(n.info.color))
	for p in world.patrols:
		_minimap.draw_circle(to_map.call(p.position), 2.5, Color(0.4, 0.6, 1.0))
	_minimap.draw_circle(to_map.call(world.ship.position), 3.5, UI.GOLD)


func _draw_nav() -> void:
	if world == null or not world.active:
		return
	var view := _nav.size
	var centre: Vector2 = world.camera.get_screen_center_position()
	var font := ThemeDB.fallback_font
	for id in world.locations:
		var n = world.locations[id]
		var rel: Vector2 = n.position - centre
		if absf(rel.x) < view.x / 2.0 and absf(rel.y) < view.y / 2.0:
			continue
		var dir := rel.normalized()
		# project onto the screen rectangle, inset by a margin
		var half := view / 2.0 - Vector2(60, 60)
		var t := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
		var p := view / 2.0 + dir * t
		var c := Color(n.info.color).lightened(0.3)
		var tip := p + dir * 14.0
		_nav.draw_colored_polygon(PackedVector2Array([tip, p + dir.orthogonal() * 8.0, p - dir.orthogonal() * 8.0]), c)
		var text := "%s %dk" % [n.info.name, int(rel.length() / 1000.0 + 0.5)]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_nav.draw_string(font, p - dir * 22.0 - Vector2(w / 2.0, -5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)


func _draw_surface_map() -> void:
	var size := _minimap.size
	_minimap.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.07, 0.85))
	var scale: float = minf(size.x / surface.map_size.x, size.y / surface.map_size.y)
	var map_px: Vector2 = surface.map_size
	var off: Vector2 = (size - map_px * scale) / 2.0
	var cfg: Dictionary = surface.cfg
	var t: float = surface.tile * scale
	_minimap.draw_rect(Rect2(off, surface.map_size * scale), Color(cfg.get("ground", "#2b4538")))
	for r in cfg.roads:
		_minimap.draw_rect(Rect2(off + Vector2(r[0], r[1]) * t, Vector2(r[2], r[3]) * t), Color(cfg.get("road", "#45464f")).lightened(0.2))
	for b in cfg.buildings:
		var r: Array = b.rect
		_minimap.draw_rect(Rect2(off + Vector2(r[0], r[1]) * t, Vector2(r[2], r[3]) * t), Color(b.get("roof", "#444444")).lightened(0.1))
	for it in surface.interactables:
		_minimap.draw_circle(off + it.pos * scale, 2.5, UI.ACCENT)
	for o in surface.officers:
		_minimap.draw_circle(off + o.position * scale, 2.5, Color(0.4, 0.6, 1.0))
	_minimap.draw_circle(off + surface.player.position * scale, 3.5, UI.GOLD)
	_minimap.draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.8, 0.6, 0.6), false, 1.5)


## Control hints follow the player's key bindings (Settings).
func _refresh_help() -> void:
	var k := func(a: String) -> String: return Settings.key_label(a)
	_flight_help.text = "%s thrust   %s reverse   %s/%s turn   %s brake   %s dock   %s phone   %s menu" % [k.call("ship_thrust"),
		k.call("ship_reverse"), k.call("ship_left"), k.call("ship_right"), k.call("ship_brake"), k.call("ship_dock"), k.call("phone"), k.call("ui_menu")]
	_foot_help.text = "%s%s%s%s/arrows walk   %s use / talk   %s phone   %s close / menu   launch pad = take off" % [k.call("move_up"),
		k.call("move_left"), k.call("move_down"), k.call("move_right"), k.call("interact"), k.call("phone"), k.call("ui_menu")]
