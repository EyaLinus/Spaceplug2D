extends Control
## The Com-Phone: a handheld overlay that works in flight and on foot (toggle with the "phone" action, default Tab).
## Shows a home screen with one tile per app from registry.gd; an app's screens stack up (push / back), Esc or the
## Back button steps back one level and closes the phone from the home screen. Time keeps running while it is open;
## main.gd freezes the ship / player meanwhile.

const UI = preload("res://scripts/ui/ui_theme.gd")
const Art = preload("res://scripts/core/art.gd")
const People = preload("res://scripts/core/people.gd")
const Registry = preload("res://scripts/ui/phone/registry.gd")

const SIZE := Vector2(420, 640)
const BEZEL := Color("#070913")
const SCREEN := Color("#0f1430")

var apps: Array = []
var _stack: Array = []  ## [{title, build: Callable(g) -> Control}], empty = home screen
var _clock: Label
var _credits: Label
var _title: Label
var _screen: VBoxContainer
var _back_btn: Button
var _dirty := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	apps = Registry.create_all()
	var device := PanelContainer.new()
	device.add_theme_stylebox_override("panel", _box(BEZEL, UI.ACCENT.darkened(0.55), 3, 30, 16))
	device.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	device.offset_left = -SIZE.x - 40
	device.offset_right = -40
	device.offset_top = -SIZE.y / 2.0
	device.offset_bottom = SIZE.y / 2.0
	add_child(device)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	device.add_child(v)
	# status bar
	var bar := HBoxContainer.new()
	_clock = UI.label("", 14, UI.MUTED)
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_clock)
	_credits = UI.label("", 14, UI.GOLD)
	bar.add_child(_credits)
	v.add_child(bar)
	# screen
	var screen := PanelContainer.new()
	screen.add_theme_stylebox_override("panel", _box(SCREEN, Color("#262b4d"), 1, 14, 12))
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(screen)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	screen.add_child(sv)
	_title = UI.label("", 20, UI.ACCENT)
	sv.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(scroll)
	_screen = VBoxContainer.new()
	_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen.add_theme_constant_override("separation", 6)
	scroll.add_child(_screen)
	# hardware buttons
	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_theme_constant_override("separation", 12)
	_back_btn = UI.button("◀ Back", back, 110)
	keys.add_child(_back_btn)
	keys.add_child(UI.button("● Home", home, 110))
	keys.add_child(UI.button("✕ Close", close, 110))
	v.add_child(keys)
	EventBus.game_event.connect(func(_k, _p): _dirty = true)
	visible = false


func open() -> void:
	visible = true
	home()
	AudioManager.play("click")


func close() -> void:
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func home() -> void:
	_stack.clear()
	refresh()


## Opens an app by id (or the app object) on its first screen.
func open_app(app_or_id) -> void:
	var app = app_or_id
	if app_or_id is String:
		app = app_by_id(app_or_id)
	if app == null:
		return
	_stack = [{"title": app.title, "build": func(g): return app.home(g, self)}]
	refresh()


## Pushes a deeper screen; build is Callable(g) -> Control and is called again on every refresh.
func push(title: String, build: Callable) -> void:
	_stack.append({"title": title, "build": build})
	refresh()


## One level up; from the home screen it closes the phone.
func back() -> void:
	if _stack.is_empty():
		close()
	else:
		_stack.pop_back()
		refresh()


func app_by_id(app_id: String):
	for a in apps:
		if a.id == app_id:
			return a
	return null


## Title of the visible screen ("" on the home screen); used by the smoke tests.
func current_title() -> String:
	return "" if _stack.is_empty() else str(_stack[-1].title)


func _process(_delta: float) -> void:
	if not visible:
		return
	var g = GameState.game
	if g == null:
		return
	var h := People.hour(g)
	_clock.text = "Day %d  %02d:%02d" % [g.day, int(h), int(fmod(h, 1.0) * 60.0)]
	_credits.text = "%d cr" % g.credits
	if _dirty:
		refresh()


func refresh() -> void:
	_dirty = false
	var g = GameState.game
	for c in _screen.get_children():
		_screen.remove_child(c)
		c.queue_free()
	if g == null:
		return
	_back_btn.visible = not _stack.is_empty()
	if _stack.is_empty():
		_title.text = "COM-PHONE"
		_screen.add_child(_home_grid(g))
	else:
		var top: Dictionary = _stack[-1]
		_title.text = top.title
		var content: Control = top.build.call(g)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_screen.add_child(content)


func _home_grid(g) -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for app in apps:
		grid.add_child(_app_tile(g, app))
	return grid


func _app_tile(g, app) -> Control:
	var b := Button.new()
	b.name = "App_" + app.id
	b.custom_minimum_size = Vector2(108, 108)
	b.add_theme_stylebox_override("normal", _box(app.tint.darkened(0.7), app.tint.darkened(0.35), 2, 16, 6))
	b.add_theme_stylebox_override("hover", _box(app.tint.darkened(0.55), app.tint, 2, 16, 6))
	b.add_theme_stylebox_override("pressed", _box(app.tint.darkened(0.4), app.tint, 2, 16, 6))
	b.pressed.connect(func():
		AudioManager.play("click")
		open_app(app))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var t := Art.icon_for(app.icon) if app.icon != "" else null
	if t != null:
		var r := TextureRect.new()
		r.texture = t
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.custom_minimum_size = Vector2(64, 64)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(r)
	else:
		var l := UI.label(app.title.left(1), 36, app.tint)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var name_l := UI.label(app.title, 13)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_l)
	var n: int = app.badge(g)
	if n > 0:
		var badge := UI.label(str(n), 13, UI.BG)
		var bp := PanelContainer.new()
		bp.add_theme_stylebox_override("panel", _box(UI.WARN, UI.WARN, 0, 9, 2))
		bp.add_child(badge)
		bp.position = Vector2(80, 4)
		bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bp)
	return b


static func _box(bg: Color, border: Color, bw: int, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s
