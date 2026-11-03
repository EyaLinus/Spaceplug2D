extends RefCounted
## Builds the shared UI theme in code and small widget helpers.
## Look (G1, phase 3): pixel-art nine-patch frames from assets/gfx/ui (built by tools/art/build_art.py → build_ui),
## palette from art_profile.yaml: dusk purple panels with brass rims, gold primary buttons, teal accents.
## When a frame PNG is missing (e.g. unit tests without import) the flat StyleBox fallback keeps the same colours.

const Art = preload("res://scripts/core/art.gd")

const BG := Color("#14121c")  ## ink
const PANEL := Color("#1e1b2e")  ## night
const CARD := Color("#2b2840")  ## shadow
const ACCENT := Color("#4fe3c1")  ## teal
const WARN := Color("#ff6b5f")
const GOLD := Color("#ffd166")
const TEXT := Color("#eef0ff")
const MUTED := Color("#8a8b9c")  ## slate_light
const BRASS := Color("#9a6a12")  ## gold_dark
const INK := Color("#14121c")

const FRAME_MARGIN := 8  ## nine-patch border in game px (4 art px × 2)

## Grade colours (Shoddy, Standard, Premium, Pristine) for item cards and product names.
const GRADE_COLORS := [Color("#8a8b9c"), Color("#eef0ff"), Color("#5fb6c9"), Color("#ffd166")]


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	var panel := frame("panel", PANEL, BRASS, 12, 10)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PopupMenu", frame("panel", PANEL, BRASS, 8, 6))
	t.set_stylebox("panel", "PopupPanel", panel)
	t.set_stylebox("panel", "TooltipPanel", frame("tooltip", INK, BRASS, 10, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 15)
	for type in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		_buttons(t, type)
	# primary call-to-action buttons: `b.theme_type_variation = "AccentButton"`
	t.set_type_variation("AccentButton", "Button")
	t.set_stylebox("normal", "AccentButton", frame("button_accent", BRASS, GOLD, 12, 6))
	t.set_stylebox("hover", "AccentButton", frame("button_accent_hover", GOLD, Color("#4e3a1e"), 12, 6))
	t.set_stylebox("pressed", "AccentButton", frame("button_pressed", Color("#1e6e66"), ACCENT, 12, 6))
	t.set_stylebox("focus", "AccentButton", _box(Color(0, 0, 0, 0), GOLD, 1, 0))
	t.set_color("font_color", "AccentButton", INK)
	t.set_color("font_hover_color", "AccentButton", INK)
	t.set_color("font_pressed_color", "AccentButton", TEXT)
	t.set_color("font_focus_color", "AccentButton", INK)
	# clickable item cards (shop, phone lists): `b.theme_type_variation = "CardButton"`
	t.set_type_variation("CardButton", "Button")
	t.set_stylebox("normal", "CardButton", frame("card", CARD, Color("#3a3a4a"), 10, 6))
	t.set_stylebox("hover", "CardButton", frame("card_hover", CARD, BRASS, 10, 6))
	t.set_stylebox("pressed", "CardButton", frame("button_pressed", Color("#1e6e66"), ACCENT, 10, 6))
	t.set_stylebox("disabled", "CardButton", frame("button_disabled", PANEL, CARD, 10, 6))
	t.set_stylebox("focus", "CardButton", _box(Color(0, 0, 0, 0), GOLD, 1, 0))
	# static cards / insets: `PanelContainer.theme_type_variation = "Card"` / "Inset"
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", frame("card", CARD, Color("#3a3a4a"), 10, 6))
	t.set_type_variation("Inset", "PanelContainer")
	t.set_stylebox("panel", "Inset", frame("inset", INK, CARD, 10, 6))
	t.set_color("font_color", "Label", TEXT)
	var inset := frame("inset", INK, CARD, 8, 4)
	for type in ["LineEdit", "SpinBox", "TextEdit"]:
		t.set_stylebox("normal", type, inset)
		t.set_stylebox("focus", type, frame("inset", INK, BRASS, 8, 4))
	t.set_stylebox("panel", "TabContainer", frame("inset", INK, CARD, 10, 8))
	t.set_stylebox("tab_selected", "TabContainer", frame("tab_selected", CARD, BRASS, 12, 5))
	t.set_stylebox("tab_unselected", "TabContainer", frame("tab", INK, CARD, 12, 5))
	t.set_stylebox("tab_hovered", "TabContainer", frame("card_hover", CARD, BRASS, 12, 5))
	t.set_color("font_selected_color", "TabContainer", GOLD)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_stylebox("background", "ProgressBar", frame("bar_bg", INK, CARD, 4, 0))
	t.set_stylebox("fill", "ProgressBar", _box(ACCENT, ACCENT, 0, 0))
	t.set_stylebox("separator", "HSeparator", _line(CARD))
	t.set_constant("separation", "HSeparator", 8)
	t.set_stylebox("scroll", "VScrollBar", _box(INK, INK, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", _box(Color("#5a5b6a"), Color("#5a5b6a"), 0, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", _box(BRASS, BRASS, 0, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", _box(GOLD, GOLD, 0, 0))
	return t


static func _buttons(t: Theme, type: String) -> void:
	t.set_stylebox("normal", type, frame("button", Color("#2e2440"), Color("#6a3a8a"), 12, 6))
	t.set_stylebox("hover", type, frame("button_hover", Color("#6a3a8a"), BRASS, 12, 6))
	t.set_stylebox("pressed", type, frame("button_pressed", Color("#1e6e66"), ACCENT, 12, 6))
	t.set_stylebox("disabled", type, frame("button_disabled", PANEL, CARD, 12, 6))
	t.set_stylebox("focus", type, _box(Color(0, 0, 0, 0), GOLD, 1, 0))
	t.set_color("font_color", type, TEXT)
	t.set_color("font_hover_color", type, GOLD)
	t.set_color("font_pressed_color", type, TEXT)
	t.set_color("font_focus_color", type, TEXT)
	t.set_color("font_disabled_color", type, MUTED.darkened(0.35))


## Nine-patch StyleBox from assets/gfx/ui/<name>.png, or a flat box in the same colours when the PNG is missing.
static func frame(name: String, fill: Color, border: Color, pad_x := 10, pad_y := 6) -> StyleBox:
	var tex: Texture2D = Art.tex("ui/%s.png" % name)
	if tex == null:
		var f := _box(fill, border, 2, 0)
		f.content_margin_left = pad_x + 2
		f.content_margin_right = pad_x + 2
		f.content_margin_top = pad_y + 2
		f.content_margin_bottom = pad_y + 2
		return f
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = FRAME_MARGIN
	s.texture_margin_right = FRAME_MARGIN
	s.texture_margin_top = FRAME_MARGIN
	s.texture_margin_bottom = FRAME_MARGIN
	s.content_margin_left = pad_x + 2
	s.content_margin_right = pad_x + 2
	s.content_margin_top = pad_y + 2
	s.content_margin_bottom = pad_y + 2
	return s


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


static func _line(c: Color) -> StyleBoxLine:
	var s := StyleBoxLine.new()
	s.color = c
	s.thickness = 2
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


## A gold primary-action button (buy, confirm, start).
static func accent_button(text: String, cb: Callable, min_w := 0) -> Button:
	var b := button(text, cb, min_w)
	b.theme_type_variation = "AccentButton"
	return b


static func bar(color: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(160, 14)
	p.add_theme_stylebox_override("fill", _box(color, color, 0, 0))
	return p


## A framed card (PanelContainer, "Card" style) holding `content`; set tooltip_text on it for hover help.
static func card(content: Control, inset := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Inset" if inset else "Card"
	p.add_child(content)
	return p


## Section heading: gold caps text with a short brass rule under it.
static func heading(text: String, size := 18) -> Label:
	return label(text.to_upper(), size, GOLD)


## Tooltip text for an item key: what a raw is for, what an additive does to a mix, what a product is worth.
static func item_tip(g, key: String) -> String:
	var d: Dictionary = g.data
	if d.raws.has(key):
		var uses: Array = []
		for b in d.bases:
			if d.bases[b].raw == key:
				uses.append("%s (T%d)" % [d.bases[b].name, int(d.bases[b].get("tier", 1))])
		return "%s – raw for %s. Start a batch at the prep station of your estate." % [g.item_name(key), ", ".join(PackedStringArray(uses))]
	if d.additives.has(key):
		var ad: Dictionary = d.additives[key]
		var parts: Array = []
		if ad.has("adds"):
			parts.append("adds %s" % d.traits[ad.adds].name)
		if ad.has("transforms"):
			for k in ad.transforms:
				parts.append("turns %s into %s" % [d.traits[k].name, d.traits[ad.transforms[k]].name])
		return "%s – additive for the Mixing Station: %s." % [ad.name, ", ".join(PackedStringArray(parts))]
	return g.item_name(key)
