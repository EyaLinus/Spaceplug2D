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


## K1: hover help for buttons whose label starts with one of these words (checked in order, case-sensitive).
## A call site that sets `tooltip_text` itself always wins; `untipped()` lists buttons that still have none.
const BUTTON_TIPS := [
	["◀ Back", "Back to the previous screen."], ["● Home", "Back to the phone's home screen."],
	["✕ Close", "Put the phone away."], ["Close", "Close this screen."], ["Back", "Back to the previous screen."],
	["Leave", "Walk away from this counter."], ["Resume", "Back to the game."],
	["Settings", "Volume, window, screen shake, text size and key bindings."],
	["Save game", "Save into one of the three slots."], ["Load game", "Pick a save slot to continue."],
	["New game", "Start a fresh run in a save slot."], ["New run", "Start over from day 1."],
	["Continue", "Carry on."], ["Quit", "Close the game."], ["Main menu", "Back to the title screen."],
	["Save & ", "Save first, then leave."], ["Keep playing", "Stay in this run."],
	["Reset to defaults", "Restore every key binding."], ["Delete", "Delete this save."],
	["Accept", "Take the deal as offered."], ["Decline", "Turn the offer down. They will remember."],
	["Fewer", "Counter with a smaller amount."], ["More", "Counter with a larger amount."],
	["Earlier", "Counter with an earlier meeting time."], ["Later", "Counter with a later meeting time."],
	["+", "Add more (hold to repeat)."], ["-", "Take some away (hold to repeat)."], ["−", "Take some away (hold to repeat)."],
	["Max", "As many as fit."], ["All", "Everything you have."],
	["Buy", "Pay and take it."], ["Sell", "Sell to this buyer at the price shown."],
	["Clear basket", "Empty the basket without buying."], ["Upgrade", "Install the next level of this module."],
	["Switch", "Move into this hull; your cargo comes along if it fits."],
	["Repair hull", "Patch the hull back to full."], ["Restock missiles", "Refill the missile pods."],
	["Hire", "Take them on. Wages are paid every morning."], ["Fire", "Let them go."], ["Let go", "Let them go."],
	["Recruit", "Pay to add this contact to your network."], ["Track", "Show this quest in the HUD and on the map."],
	["Skip tutorial", "Jump straight to the main quest."], ["Request", "Ask for a new drop point here."],
	["Abandon", "Give up this drop point."], ["Courier", "Send a courier with these goods."],
	["Leave ", "Leave these goods in the drop for the buyer."], ["Order", "Order these goods for delivery."],
	["Express", "Faster delivery for a higher fee."], ["Standard", "Normal delivery time and price."],
	["Cancel", "Call it off."], ["Call it off", "Cancel this meeting. The contact will be unhappy."],
	["Collect", "Take the cash your dealer has made."], ["Take stock back", "Take the dealer's unsold stock back."],
	["Stock raws", "Move raws from your hold to the workers' shelf."],
	["Take products", "Move finished products from the estate into your hold."],
	["Load stash", "Load every finished product from the stash into your hold."],
	["Pour the mix", "Pour the chosen additives into the tray (Mixing Station minigame)."],
	["No additives", "Skip mixing and cook the plain base."], ["Scrap tray", "Throw this tray away."],
	["Start & work", "Start a new tray here and play the station's minigame."],
	["Skip the rest", "Remaining stations count as Standard quality."],
	["Pay", "Pay this amount."], ["Clear heat", "Bribe your heat down."], ["Clear wanted", "Make the Authority forget you."],
	["Divert sweep", "Pay to steer patrols away for a while."], ["-10 heat", "Pay to lose 10 heat."],
	["Take down", "Rob this courier for the cash shown."], ["Hand over", "Give them what they asked for."],
	["Go inside", "Enter the building."], ["Undock", "Take off and fly."], ["Charge jump drive", "Spool up the jump drive (hold still)."],
	["Cancel jump", "Stop charging the jump drive."], ["Price comparison", "Compare prices at every market you know."],
	["Market", "Set your asking price to what the market pays."], ["Worth", "Set your asking price to the product's worth."],
	["Cartels", "Who runs which street, how angry they are."],
	["Ask +", "Ask for more per unit. One try: if they refuse, they are annoyed."], ["Walk away", "Turn the customer down."],
]


## Hover help for a button label (see BUTTON_TIPS); "" when there is none.
static func tip_for(text: String) -> String:
	var t := text.strip_edges()
	for pair in BUTTON_TIPS:
		if t.begins_with(pair[0]):
			return pair[1]
	return ""


## Visible buttons under `root` that have no hover help (used by the UI smoke test).
static func untipped(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is CanvasItem and not (c as CanvasItem).visible:
			continue
		if c is BaseButton and (c as Control).tooltip_text == "":
			out.append((c as Button).text if c is Button and (c as Button).text != "" else str(c.get_path()).get_file())
		out.append_array(untipped(c))
	return out


static func button(text: String, cb: Callable, min_w := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip_for(text)
	b.custom_minimum_size.x = min_w
	b.pressed.connect(func():
		AudioManager.play("click")
		cb.call())
	if is_stepper(text):
		hold_to_repeat(b, cb)
	return b


## K3: "+", "−", "-5", "+10" … quantity/price steppers repeat while held.
static func is_stepper(text: String) -> bool:
	var t := text.strip_edges()
	if t.is_empty() or not "+-−".contains(t[0]) or t.length() > 4:
		return false
	var rest := t.substr(1).trim_suffix("%")
	return rest.is_empty() or rest.is_valid_int()


static var _repeat_id := 0  ## bumps on every press/release; a running repeat loop stops when it changes

## Holding the button calls `cb` again after REPEAT_DELAY, then every REPEAT_STEP, until the mouse is released.
## The loop runs on the tree, not on the button, so it survives the screen being rebuilt by the callback.
const REPEAT_DELAY := 0.4
const REPEAT_STEP := 0.07

static func hold_to_repeat(b: BaseButton, cb: Callable) -> void:
	b.button_down.connect(func():
		_repeat_id += 1
		var mine := _repeat_id
		var tree := b.get_tree()
		await tree.create_timer(REPEAT_DELAY).timeout
		while mine == _repeat_id and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			AudioManager.play("click")
			cb.call()
			await tree.create_timer(REPEAT_STEP).timeout)
	b.button_up.connect(func(): _repeat_id += 1)


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
