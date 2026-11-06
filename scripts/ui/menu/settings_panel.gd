extends "res://scripts/ui/menu/overlay.gd"
## Settings screen: Audio (Master/Music/SFX), Display (window mode, resolution, vsync) and Controls (rebind the
## primary key of each action; Esc cancels a rebind). Every change applies at once; leaving the screen saves to disk.

var tabs: TabContainer
var _key_buttons: Dictionary = {}  ## action -> Button
var _waiting := ""  ## action waiting for a key press, "" if none
var _note: Label
var _res: OptionButton


func _init() -> void:
	super(640)
	_build()
	back.connect(_on_back)
	Settings.language_changed.connect(_rebuild, CONNECT_DEFERRED)


## Language switch: build the whole screen again in the new language, on the same tab.
func _rebuild() -> void:
	var tab := tabs.current_tab if tabs != null else 0
	clear_box()
	_key_buttons = {}
	_build()
	tabs.current_tab = clampi(tab, 0, tabs.get_tab_count() - 1)
	_refresh_keys()
	if visible:
		focus_first()


func _build() -> void:
	title(Loc.t("settings.title", "Settings"))
	tabs = TabContainer.new()
	tabs.custom_minimum_size.y = 380
	box.add_child(tabs)
	tabs.add_child(_audio_tab())
	tabs.add_child(_display_tab())
	tabs.add_child(_controls_tab())
	box.add_child(UI.button(Loc.t("settings.back", "Back"), func(): back.emit()))


func open() -> void:
	_waiting = ""
	_refresh_keys()
	_note.text = ""
	super()


func _on_back() -> void:
	_waiting = ""
	Settings.save_settings()


func _audio_tab() -> Control:
	var v := _tab_box(Loc.t("settings.tab.audio", "Audio"))
	for bus in Settings.BUSES:
		var row := HBoxContainer.new()
		var l := UI.label(Loc.t("settings.bus." + bus, bus))
		l.custom_minimum_size.x = 190
		row.add_child(l)
		var s := HSlider.new()
		s.name = bus
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = Settings.volumes[bus]
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var pct := UI.label("%d%%" % roundi(s.value * 100), 17, UI.MUTED)
		pct.custom_minimum_size.x = 60
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		s.value_changed.connect(func(x: float):
			Settings.set_volume(bus, x)
			pct.text = "%d%%" % roundi(x * 100))
		s.drag_ended.connect(func(_c: bool): AudioManager.play("click"))
		row.add_child(s)
		row.add_child(pct)
		v.add_child(row)
	return v.get_parent()


func _display_tab() -> Control:
	var v := _tab_box(Loc.t("settings.tab.display", "Display"))
	var mode := OptionButton.new()
	for mi in Settings.WINDOW_MODES.size():
		mode.add_item(Loc.t("settings.window_mode.%d" % mi, Settings.WINDOW_MODES[mi]))
	mode.select(Settings.window_mode)
	mode.tooltip_text = Loc.t("settings.window.tip", "Play in a window or fullscreen.")
	v.add_child(_row(Loc.t("settings.window", "Window"), mode))
	_res = OptionButton.new()
	for r in Settings.RESOLUTIONS:
		_res.add_item("%d × %d" % [r.x, r.y])
	_res.select(Settings.resolution)
	_res.tooltip_text = Loc.t("settings.window_size.tip", "Window size in windowed mode. The game scales to any size.")
	_res.disabled = Settings.window_mode == 1
	_res.item_selected.connect(func(i: int): Settings.set_resolution(i))
	v.add_child(_row(Loc.t("settings.window_size", "Window size"), _res))
	mode.item_selected.connect(func(i: int):
		Settings.set_window_mode(i)
		_res.disabled = i == 1)
	var vs := CheckButton.new()
	vs.button_pressed = Settings.vsync
	vs.tooltip_text = Loc.t("settings.vsync.tip", "Sync frames to the monitor: no tearing, slightly more input delay.")
	vs.toggled.connect(func(on: bool): Settings.set_vsync(on))
	v.add_child(_row(Loc.t("settings.vsync", "VSync"), vs))
	var tut := CheckButton.new()
	tut.name = "TutorialToggle"
	tut.button_pressed = Settings.tutorial
	tut.tooltip_text = Loc.t("settings.tutorial.tip", "New games start with Okka's tutorial quests. Off = straight to the main quest.")
	tut.toggled.connect(func(on: bool): Settings.set_tutorial(on))
	v.add_child(_row(Loc.t("settings.tutorial", "Tutorial (new games)"), tut))
	var us := OptionButton.new()
	us.name = "UiScale"
	var scale_names := ["Normal", "Large (110%)", "Larger (125%)"]
	for si in scale_names.size():
		us.add_item(Loc.t("settings.ui_scale.%d" % si, scale_names[si]))
	us.select(Settings.ui_scale)
	us.tooltip_text = Loc.t("settings.ui_scale.tip", "Makes all text, the HUD, the phone and every panel bigger.")
	us.item_selected.connect(func(i: int): Settings.set_ui_scale(i))
	v.add_child(_row(Loc.t("settings.ui_scale", "Text & UI size"), us))
	var sh := HSlider.new()
	sh.name = "ShakeSlider"
	sh.min_value = 0.0
	sh.max_value = 1.0
	sh.step = 0.25
	sh.value = Settings.screen_shake
	sh.custom_minimum_size.x = 200
	sh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.tooltip_text = Loc.t("settings.shake.tip", "How hard the camera shakes on hits, explosions and busts. Left = off.")
	sh.value_changed.connect(func(x: float): Settings.set_screen_shake(x))
	v.add_child(_row(Loc.t("settings.shake", "Screen shake"), sh))
	var dn := CheckButton.new()
	dn.name = "DamageNumbers"
	dn.button_pressed = Settings.damage_numbers
	dn.tooltip_text = Loc.t("settings.damage_numbers.tip", "Show floating damage numbers over ships, officers and you.")
	dn.toggled.connect(func(on: bool): Settings.set_damage_numbers(on))
	v.add_child(_row(Loc.t("settings.damage_numbers", "Damage numbers"), dn))
	var lang := OptionButton.new()
	lang.name = "Language"
	for li in Settings.LANGUAGES.size():
		lang.add_item(Settings.LANGUAGES[li][1])
		if Settings.LANGUAGES[li][0] == Settings.language:
			lang.select(li)
	lang.tooltip_text = Loc.t("settings.language.tip", "Language of the menus. Other screens are translated step by step.")
	lang.item_selected.connect(func(i: int): Settings.set_language(Settings.LANGUAGES[i][0]))
	v.add_child(_row(Loc.t("settings.language", "Language"), lang))
	var hint := UI.label(Loc.t("settings.display_hint", "The game scales to any window size; the size only matters in windowed mode."), 14, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	return v.get_parent()


func _controls_tab() -> Control:
	var v := _tab_box(Loc.t("settings.tab.controls", "Controls"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	var group := ""
	for b in Settings.BINDABLE:
		if b.group != group:
			group = b.group
			grid.add_child(UI.label(Loc.t("settings.group." + group, group), 15, UI.GOLD))
			grid.add_child(Control.new())
		var l := UI.label(_label_of(b.action), 16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		var action: String = b.action
		var btn := UI.button("", func(): _start_rebind(action), 150)
		btn.name = action
		btn.tooltip_text = Loc.t("settings.key.tip", "Click, then press the new key for \"%s\". Esc cancels.") % _label_of(action)
		_key_buttons[action] = btn
		grid.add_child(btn)
	v.add_child(grid)
	_note = UI.label("", 14, UI.MUTED)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_note)
	v.add_child(UI.button(Loc.t("settings.reset", "Reset to defaults"), func():
		Settings.reset_bindings()
		_refresh_keys()
		_note.text = Loc.t("settings.reset_done", "Default keys restored.")))
	return v.get_parent()


## Tab page: a scroll container (the tab) holding a VBox (returned).
func _tab_box(name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)
	return v


func _row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UI.label(text)
	l.custom_minimum_size.x = 190
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _refresh_keys() -> void:
	for action in _key_buttons:
		_key_buttons[action].text = Loc.t("settings.press_key", "Press a key…") if action == _waiting else Settings.key_label(action)


func _start_rebind(action: String) -> void:
	_waiting = action
	_note.text = Loc.t("settings.press_key_note", "Press the new key for \"%s\". Esc cancels.") % _label_of(action)
	_refresh_keys()


func _input(event: InputEvent) -> void:
	if _waiting == "" or not is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()
	var action := _waiting
	_waiting = ""
	var code: int = event.physical_keycode
	if code == KEY_ESCAPE and action != "ui_menu":
		_note.text = Loc.t("settings.cancelled", "Cancelled.")
	else:
		var swapped := Settings.rebind(action, code)
		_note.text = "%s → %s" % [_label_of(action), Settings.key_label(action)]
		if swapped != "":
			_note.text += Loc.t("settings.swapped", "   (swapped with %s, now %s)") % [_label_of(swapped), Settings.key_label(swapped)]
	_refresh_keys()
	_key_buttons[action].grab_focus()


func _label_of(action: String) -> String:
	for b in Settings.BINDABLE:
		if b.action == action:
			return Loc.t("key." + action, b.label)
	return action
