extends RefCounted
## Builds the shared UI theme in code (dark panels, teal accent) and small widget helpers.

const BG := Color("#0d1020")
const PANEL := Color("#151a33")
const ACCENT := Color("#4fe3c1")
const WARN := Color("#ff6b5f")
const GOLD := Color("#ffd166")
const TEXT := Color("#e6e9ff")
const MUTED := Color("#8a90b8")


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	var panel := _box(PANEL, ACCENT.darkened(0.5), 2, 10)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("normal", "Button", _box(Color("#222a52"), Color("#39427a"), 1, 6))
	t.set_stylebox("hover", "Button", _box(Color("#2c3768"), ACCENT.darkened(0.2), 1, 6))
	t.set_stylebox("pressed", "Button", _box(ACCENT.darkened(0.5), ACCENT, 1, 6))
	t.set_stylebox("disabled", "Button", _box(Color("#191d38"), Color("#262b4d"), 1, 6))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), ACCENT, 1, 6))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "TabContainer", _box(PANEL, Color("#262b4d"), 1, 6))
	t.set_stylebox("tab_selected", "TabContainer", _box(Color("#2c3768"), ACCENT, 1, 6))
	t.set_stylebox("tab_unselected", "TabContainer", _box(Color("#1a1f3d"), Color("#262b4d"), 1, 6))
	t.set_stylebox("tab_hovered", "TabContainer", _box(Color("#222a52"), ACCENT.darkened(0.3), 1, 6))
	t.set_stylebox("background", "ProgressBar", _box(Color("#0a0d1c"), Color("#262b4d"), 1, 4))
	t.set_stylebox("fill", "ProgressBar", _box(ACCENT, ACCENT, 0, 4))
	return t


static func _box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func label(text: String, size := 17, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, cb: Callable, min_w := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.x = min_w
	b.pressed.connect(func():
		AudioManager.play("click")
		cb.call())
	return b


static func bar(color: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(160, 14)
	p.add_theme_stylebox_override("fill", _box(color, color, 0, 4))
	return p
