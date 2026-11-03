extends Control
## In-flight HUD: money, debt, day clock, heat, cargo, lab status, dock prompt, scan warning, toasts, minimap.
## On a planet surface the prompt, minimap and controls help switch to the on-foot versions.

const UI = preload("res://scripts/ui/ui_theme.gd")
const Art = preload("res://scripts/core/art.gd")
const Quests = preload("res://scripts/core/quests.gd")
const Bench = preload("res://scripts/core/bench.gd")
const FxScript = preload("res://scripts/ui/fx.gd")

const MAX_TOASTS := 5
const TOAST_SECONDS := 4.0

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
## On foot the minimap can zoom in around the player (map_zoom key cycles): 1 = whole planet, 2 and 4 = closer.
const MAP_ZOOMS := [1.0, 2.0, 4.0]
const MINIMAP_AREAS := {"water": Color("#2f6f8a"), "pit": Color("#0a0806"), "slag": Color("#c0502f"), "void": Color("#05060c"),
	"chasm": Color("#1a120c"), "grass": Color("#3f6a3a"), "ice": Color("#bfe6f5", 0.6), "dome": Color("#8fd1e8", 0.15),
	"arena": Color("#c27447", 0.5), "salt": Color("#ece8dc", 0.4)}
var map_zoom := 0  ## index into MAP_ZOOMS
var _district: Label  ## name of the district you stand in, above the minimap
var _district_name := ""
var _district_t := 0.0  ## seconds the "you entered" highlight still shows
var _nav: Control  ## edge arrows pointing at off-screen locations
var _quest_box: PanelContainer  ## tracker of the followed quest (top left)
var _quest_title: Label
var _quest_step: Label
var _quest_hint: Label
var _card: PanelContainer  ## quest message from the quest giver (intro / outro), fades after a while
var _card_from: Label
var _card_text: Label
var _card_queue: Array = []  ## [[from, text]] waiting to be shown
var _card_left := 0.0
var fx: Control  ## K1 feedback layer (floating numbers, flashes)


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
		c.mouse_filter = Control.MOUSE_FILTER_PASS  # labels ignore the mouse by default; the tooltips need hover
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
	_toasts.offset_left = -400
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

	_build_quest_ui()

	fx = FxScript.new()
	fx.name = "Fx"
	fx.hud = self

	_minimap = Control.new()
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_minimap.offset_left = -200
	_minimap.offset_top = -200
	_minimap.offset_right = -12
	_minimap.offset_bottom = -12
	_minimap.draw.connect(_draw_minimap)
	_minimap.clip_contents = true  # zoomed-in surface maps draw past the frame
	add_child(_minimap)
	_district = UI.label("", 15, UI.MUTED)
	_district.name = "District"
	_district.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_district.offset_left = -200
	_district.offset_right = -12
	_district.offset_top = -226
	_district.offset_bottom = -202
	_district.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_district.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_district)

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
	add_child(fx)  # last: flashes and numbers draw over everything else in the HUD
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
	_day.text = "Day %d · %s" % [g.day, g.system_data().get("name", "")]
	_day_bar.value = g.day_time / g.day_seconds() * 100.0
	_heat.value = g.heat
	_heat_label.text = "Heat %d · %d patrol%s" % [int(g.heat), g.patrol_count(), "" if g.patrol_count() == 1 else "s"]
	_cargo.text = "Cargo %d/%d%s" % [g.cargo_used(), g.cargo_capacity(), "  ⚠" if g.has_contraband() else ""]
	_update_tips(g)
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
		var nl: Dictionary = g.data.locations[world.nearby]
		if nl.has("jump_to"):
			_prompt.text = "[%s] Jump to %s (%d cr toll)" % [Settings.key_label("ship_dock"), g.system_data(nl.jump_to).get("name", nl.jump_to), int(g.data.jump.fee)]
		else:
			_prompt.text = "[%s] Dock at %s" % [Settings.key_label("ship_dock"), nl.name]
	else:
		_prompt.text = ""
	_update_district(_delta)
	_minimap.queue_redraw()
	_nav.queue_redraw()
	_update_quest_ui(g, _delta)


## District label above the minimap; it lights up for a few seconds when you walk into a new one.
func _update_district(delta: float) -> void:
	var d := ""
	if surface != null and surface.player != null and surface.has_method("district_at"):
		d = surface.district_at(surface.player.position)
	if d != _district_name:
		_district_name = d
		_district_t = 3.0 if d != "" else 0.0
	_district_t = maxf(0.0, _district_t - delta)
	_district.visible = d != ""
	var zoom_hint := "" if map_zoom == 0 else "  ×%d" % int(MAP_ZOOMS[map_zoom])
	_district.text = d.to_upper() + zoom_hint
	_district.add_theme_color_override("font_color", UI.GOLD if _district_t > 0.0 else UI.MUTED)


func _unhandled_input(event: InputEvent) -> void:
	if surface != null and event.is_action_pressed("map_zoom"):
		cycle_map_zoom()
		get_viewport().set_input_as_handled()


func cycle_map_zoom() -> void:
	map_zoom = (map_zoom + 1) % MAP_ZOOMS.size()


## HUD widgets the feedback layer pops numbers from.
func credits_label() -> Control:
	return _credits


func heat_label() -> Control:
	return _heat_label


## Hover help for the top bar; refreshed every frame so the numbers in it stay true.
func _update_tips(g) -> void:
	_credits.tooltip_text = "Cash on hand. Buy raws and upgrades with it, pay the Consortium before the due day."
	_debt.tooltip_text = ("You owe the Ouroboros Consortium %d cr. Pay at any bank terminal before day %d or it is game over." % [g.debt, g.debt_due_day]) if g.debt > 0 else "Your debt is paid. Everything you make now is yours."
	var mins := int(g.day_time / g.day_seconds() * 24.0 * 60.0)
	_day.tooltip_text = "Day %d, %02d:%02d in %s. Contacts keep their meeting times on this clock." % [g.day, mins / 60, mins % 60, g.system_data().get("name", "")]
	_day_bar.tooltip_text = _day.tooltip_text
	var tip_heat := "Heat %d/100. Selling, fighting and being seen with product raise it; it cools over time. More heat = more patrols; from %d they hunt you." % [int(g.heat), int(g.data.heat.chase_heat)]
	_heat_label.tooltip_text = tip_heat
	_heat.tooltip_text = tip_heat
	_cargo.tooltip_text = "Hold: %d of %d slots used.%s" % [g.cargo_used(), g.cargo_capacity(), " ⚠ You carry contraband: scans and frisks can bust you." if g.has_contraband() else ""]
	_lab.tooltip_text = "Your estates' production. Finished batches wait in the stash crate of the estate."


## Notification card on the right. The same text twice in a row stacks into one card with a counter.
func show_toast(text: String, good: bool = true) -> void:
	if _toasts.get_child_count() > 0:
		var last := _toasts.get_child(_toasts.get_child_count() - 1)
		if last.get_meta("text", "") == text and not last.is_queued_for_deletion():
			var n: int = int(last.get_meta("count", 1)) + 1
			last.set_meta("count", n)
			(last.get_meta("counter") as Label).text = "×%d" % n
			(last.get_meta("counter") as Label).visible = true
			_fade_toast(last)
			return
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_meta("text", text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var stripe := ColorRect.new()
	stripe.color = UI.ACCENT if good else UI.WARN
	stripe.custom_minimum_size = Vector2(4, 0)
	row.add_child(stripe)
	var l := UI.label(text, 15, UI.TEXT if good else UI.WARN)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var counter := UI.label("", 15, UI.GOLD)
	counter.visible = false
	row.add_child(counter)
	card.set_meta("counter", counter)
	_toasts.add_child(card)
	while _toasts.get_child_count() > MAX_TOASTS:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	if good:
		AudioManager.play("toast")
	_fade_toast(card)


func _fade_toast(card: Control) -> void:
	card.modulate.a = 1.0
	if card.has_meta("tween"):
		var old: Tween = card.get_meta("tween")
		if old.is_valid():
			old.kill()
	var tw := card.create_tween()
	tw.tween_interval(TOAST_SECONDS)
	tw.tween_property(card, "modulate:a", 0.0, 0.8)
	tw.tween_callback(card.queue_free)
	card.set_meta("tween", tw)


func _on_game_event(kind: String, p: Dictionary) -> void:
	var g = GameState.game
	match kind:
		"lab_done":
			show_toast("Lab: %d × %s ready in your stash." % [p.qty, g.item_name(p.product)])
		"order_delivered":
			show_toast("Delivery: %d × %s arrived (%s)." % [p.qty, g.item_name(p.item), "stash" if p.dest == "stash" else g.data.estates[p.dest].name])
		"new_day":
			show_toast("Day %d begins. %d days until the Consortium collects." % [p.day, maxi(0, g.debt_due_day - p.day + 1)] if g.debt > 0 else "Day %d begins." % p.day)
		"rumour":
			var up: bool = p.demand >= 1.0
			show_toast("Rumour: %s demand %s at %s." % [g.data.bases[p.base].name, "hot" if up else "cooling", g.data.locations[p.location].name])
		"heat_level":
			if p.heat >= float(g.data.heat.chase_heat):
				show_toast("Heat %d: patrols will hunt you." % int(p.heat), false)
		"quest_started":
			var q: Dictionary = Quests.defs(g).get(p.quest, {})
			show_card(str(q.get("giver", "")), str(q.get("intro", "")))
		"quest_done":
			var qd: Dictionary = Quests.defs(g).get(p.quest, {})
			if qd.has("outro"):
				show_card(str(qd.get("giver", "")), str(qd.outro))


func _draw_minimap() -> void:
	if world == null or GameState.game == null:
		return
	if surface != null:
		_draw_surface_map()
		return
	var size := _minimap.size
	_minimap.draw_rect(Rect2(Vector2.ZERO, size), Color(UI.INK, 0.88))
	_minimap.draw_rect(Rect2(Vector2.ZERO, size), Color(UI.BRASS, 0.9), false, 2.0)
	var scale: float = size.x / (world.SECTOR_HALF * 2.0)
	var to_map := func(p: Vector2) -> Vector2: return (p + Vector2(world.SECTOR_HALF, world.SECTOR_HALF)) * scale
	for id in world.locations:
		var n = world.locations[id]
		_minimap.draw_circle(to_map.call(n.position), maxf(3.0, n.radius * scale), Color(n.info.color))
	for p in world.patrols:
		_minimap.draw_circle(to_map.call(p.position), 2.5, Color(0.4, 0.6, 1.0))
	_minimap.draw_circle(to_map.call(world.ship.position), 3.5, UI.GOLD)
	var qp = quest_point()
	if qp != null:
		_minimap.draw_arc(to_map.call(qp), 6.0, 0, TAU, 16, UI.GOLD, 2.0)


func _draw_nav() -> void:
	_draw_quest_marker()
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
	var scale: float = minf(size.x / surface.map_size.x, size.y / surface.map_size.y) * float(MAP_ZOOMS[map_zoom])
	var map_px: Vector2 = surface.map_size
	var off: Vector2 = (size - map_px * scale) / 2.0
	if map_zoom > 0:  # zoomed in: follow the player, but keep the map edge in view instead of empty space
		var half := size / 2.0 / scale
		var c: Vector2 = surface.player.position.clamp(half, map_px - half) if map_px.x > half.x * 2.0 and map_px.y > half.y * 2.0 else map_px / 2.0
		off = size / 2.0 - c * scale
	var cfg: Dictionary = surface.cfg
	var t: float = surface.tile * scale
	_minimap.draw_rect(Rect2(off, surface.map_size * scale), Color(cfg.get("ground", "#2b4538")))
	for a in cfg.get("areas", []):
		var ac = MINIMAP_AREAS.get(str(a[4]))
		if ac != null:
			_minimap.draw_rect(Rect2(off + Vector2(a[0], a[1]) * t, Vector2(a[2], a[3]) * t), ac)
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
	var qp = quest_point()
	if qp != null:
		_minimap.draw_arc(off + (qp as Vector2) * scale, 6.0, 0, TAU, 16, UI.GOLD, 2.0)
	_minimap.draw_rect(Rect2(Vector2.ZERO, size), Color(UI.BRASS, 0.9), false, 2.0)


## Control hints follow the player's key bindings (Settings).
func _refresh_help() -> void:
	var k := func(a: String) -> String: return Settings.key_label(a)
	_flight_help.text = "%s thrust   %s reverse   %s/%s turn   %s brake   %s dock   %s phone   %s menu" % [k.call("ship_thrust"),
		k.call("ship_reverse"), k.call("ship_left"), k.call("ship_right"), k.call("ship_brake"), k.call("ship_dock"), k.call("phone"), k.call("ui_menu")]
	_foot_help.text = "%s%s%s%s/arrows walk   %s sprint   %s use / talk   mouse aim + fire   %s weapons   %s reload   %s map zoom   %s phone   %s menu" % [k.call("move_up"),
		k.call("move_left"), k.call("move_down"), k.call("move_right"), k.call("sprint"), k.call("interact"), k.call("weapon_wheel"), k.call("reload"), k.call("map_zoom"), k.call("phone"), k.call("ui_menu")]


# ---------------------------------------------------------------- quests

func _build_quest_ui() -> void:
	_quest_box = PanelContainer.new()
	_quest_box.name = "QuestTracker"
	_quest_box.theme_type_variation = "Card"
	_quest_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_quest_box.offset_left = 12
	_quest_box.offset_top = 64
	_quest_box.custom_minimum_size = Vector2(320, 0)
	_quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_quest_box.add_child(v)
	_quest_title = UI.label("", 14, UI.GOLD)
	_quest_step = UI.label("", 16)
	_quest_hint = UI.label("", 13, UI.MUTED)
	for l in [_quest_title, _quest_step, _quest_hint]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 300
		v.add_child(l)
	_quest_box.visible = false
	add_child(_quest_box)

	_card = PanelContainer.new()
	_card.name = "QuestCard"
	_card.theme_type_variation = "Card"
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.offset_left = -270
	_card.offset_right = 270
	_card.offset_top = -120
	_card.offset_bottom = -120
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.tooltip_text = "Click to dismiss"
	_card.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_card_left = 0.0)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	_card.add_child(cv)
	_card_from = UI.label("", 14, UI.ACCENT)
	cv.add_child(_card_from)
	_card_text = UI.label("", 17)
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size.x = 520
	cv.add_child(_card_text)
	_card.visible = false
	add_child(_card)


## Shows a message from a quest character; queued while another one is on screen.
func show_card(from: String, text: String) -> void:
	if text == "":
		return
	_card_queue.append([from, text])


func _update_quest_ui(g, delta: float) -> void:
	var qid := Quests.tracked(g)
	_quest_box.visible = qid != ""
	if qid != "":
		var q: Dictionary = Quests.defs(g)[qid]
		var s: Dictionary = Quests.current(g, qid)
		var tag := "TUTORIAL" if q.get("tutorial", false) else (("MAIN QUEST · CH.%d" % int(q.get("chapter", 1))) if q.get("main", false) else "QUEST")
		_quest_title.text = "%s · %s" % [tag, q.get("title", qid)]
		var prog := Quests.progress_text(g, qid)
		_quest_step.text = "▸ " + str(s.get("text", "")) + ("  (%s)" % prog if prog != "" else "")
		var hint := str(s.get("hint", ""))
		if s.get("target", {}).has("app"):
			hint = ("[%s] Com-Phone. " % Settings.key_label("phone")) + hint
		_quest_hint.text = hint
	if _card_left > 0.0:
		_card_left -= delta
		_card.modulate.a = clampf(_card_left / 0.6, 0.0, 1.0)
		if _card_left <= 0.0:
			_card.visible = false
	elif not _card_queue.is_empty():
		var m: Array = _card_queue.pop_front()
		_card_from.text = str(m[0]).to_upper() if m[0] != "" else "MESSAGE"
		_card_text.text = str(m[1])
		_card.visible = true
		_card.modulate.a = 1.0
		_card_left = clampf(4.0 + str(m[1]).length() / 22.0, 6.0, 14.0)


## World position the tracked quest points at right now, or null (no target, target is a phone app, docked menu).
func quest_point():
	var g = GameState.game
	if g == null:
		return null
	var t: Dictionary = Quests.target(g)
	if t.is_empty() or t.has("app"):
		return null
	if surface != null:
		return _surface_point(g, t)
	if world == null or not world.active:
		return null
	var goal := Quests.space_goal(g, t)
	if goal == "" or not world.locations.has(goal):
		return null
	return world.locations[goal].position


func _surface_point(g, t: Dictionary):
	var cfg: Dictionary = surface.cfg
	if cfg.has("estate"):
		var here := str(cfg.estate)
		if str(t.get("estate", "")) != here:
			return _interactable_pos("exit")
		if t.get("stash", false):
			return _interactable_pos("stash")
		var st := str(t.get("station", ""))
		if st == "@next":
			var tray: Dictionary = Bench.tray(g, here)
			st = Bench.next_station(g, tray) if not tray.is_empty() else ""
		for b in cfg.buildings:
			if st != "" and b.get("station", "") == st:
				var r: Array = b.rect
				return (Vector2(r[0], r[1]) + Vector2(r[2], r[3]) / 2.0) * surface.tile
		return null
	if str(t.get("loc", "")) != g.location:
		return _interactable_pos("pad")
	if t.has("contact"):
		for n in cfg.get("npcs", []):
			if n.get("contact", "") == t.contact and surface.npcs.has(n.id):
				return surface.npcs[n.id].position
		return null
	if t.has("estate"):
		for b in cfg.buildings:
			if b.get("estate", "") == t.estate:
				return _interactable_pos(b.id)
	if t.has("building"):
		return _interactable_pos(str(t.building))
	return null


func _interactable_pos(id: String):
	var it: Dictionary = surface.interactable(id)
	return it.pos if not it.is_empty() else null


## Gold diamond over the quest target, or an edge arrow when it is off screen.
func _draw_quest_marker() -> void:
	var wp = quest_point()
	if wp == null:
		return
	var view := _nav.size
	var p: Vector2 = get_viewport().get_canvas_transform() * (wp as Vector2)
	var bob := sin(Time.get_ticks_msec() / 220.0) * 4.0
	var col := UI.GOLD
	var margin := 48.0
	if Rect2(Vector2(margin, margin), view - Vector2(margin, margin) * 2.0).has_point(p):
		var c := p + Vector2(0, -34 + bob)
		_nav.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(8, 0), c + Vector2(0, 10), c + Vector2(-8, 0)]), col)
		_nav.draw_polyline(PackedVector2Array([c + Vector2(0, -10), c + Vector2(8, 0), c + Vector2(0, 10), c + Vector2(-8, 0), c + Vector2(0, -10)]), Color(0, 0, 0, 0.6), 1.5)
		return
	var dir := (p - view / 2.0).normalized()
	var half := view / 2.0 - Vector2(margin, margin)
	var t := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var e := view / 2.0 + dir * t
	var tip := e + dir * (18.0 + bob)
	_nav.draw_colored_polygon(PackedVector2Array([tip, e + dir.orthogonal() * 11.0, e - dir.orthogonal() * 11.0]), col)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size("QUEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	_nav.draw_string(font, e - dir * 20.0 - Vector2(w / 2.0, -5.0), "QUEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
