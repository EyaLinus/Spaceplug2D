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
	title("Settings")
	tabs = TabContainer.new()
	tabs.custom_minimum_size.y = 380
	box.add_child(tabs)
	tabs.add_child(_audio_tab())
	tabs.add_child(_display_tab())
	tabs.add_child(_controls_tab())
	box.add_child(UI.button("Back", func(): back.emit()))
	back.connect(_on_back)


func open() -> void:
	_waiting = ""
	_refresh_keys()
	_note.text = ""
	super()


func _on_back() -> void:
	_waiting = ""
	Settings.save_settings()


func _audio_tab() -> Control:
	var v := _tab_box("Audio")
	for bus in Settings.BUSES:
		var row := HBoxContainer.new()
		var l := UI.label({"Master": "Master", "Music": "Music / ambience", "SFX": "Effects"}[bus])
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
	var v := _tab_box("Display")
	var mode := OptionButton.new()
	for m in Settings.WINDOW_MODES:
		mode.add_item(m)
	mode.select(Settings.window_mode)
	v.add_child(_row("Window", mode))
	_res = OptionButton.new()
	for r in Settings.RESOLUTIONS:
		_res.add_item("%d × %d" % [r.x, r.y])
	_res.select(Settings.resolution)
	_res.disabled = Settings.window_mode == 1
	_res.item_selected.connect(func(i: int): Settings.set_resolution(i))
	v.add_child(_row("Window size", _res))
	mode.item_selected.connect(func(i: int):
		Settings.set_window_mode(i)
		_res.disabled = i == 1)
	var vs := CheckButton.new()
	vs.button_pressed = Settings.vsync
	vs.toggled.connect(func(on: bool): Settings.set_vsync(on))
	v.add_child(_row("VSync", vs))
	var hint := UI.label("The game scales to any window size; the size only matters in windowed mode.", 14, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	return v.get_parent()


func _controls_tab() -> Control:
	var v := _tab_box("Controls")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	var group := ""
	for b in Settings.BINDABLE:
		if b.group != group:
			group = b.group
			grid.add_child(UI.label(group, 15, UI.GOLD))
			grid.add_child(Control.new())
		var l := UI.label(b.label, 16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		var action: String = b.action
		var btn := UI.button("", func(): _start_rebind(action), 150)
		btn.name = action
		_key_buttons[action] = btn
		grid.add_child(btn)
	v.add_child(grid)
	_note = UI.label("", 14, UI.MUTED)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_note)
	v.add_child(UI.button("Reset to defaults", func():
		Settings.reset_bindings()
		_refresh_keys()
		_note.text = "Default keys restored."))
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
		_key_buttons[action].text = "Press a key…" if action == _waiting else Settings.key_label(action)


func _start_rebind(action: String) -> void:
	_waiting = action
	_note.text = "Press the new key for \"%s\". Esc cancels." % _label_of(action)
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
		_note.text = "Cancelled."
	else:
		var swapped := Settings.rebind(action, code)
		_note.text = "%s → %s" % [_label_of(action), Settings.key_label(action)]
		if swapped != "":
			_note.text += "   (swapped with %s, now %s)" % [_label_of(swapped), Settings.key_label(swapped)]
	_refresh_keys()
	_key_buttons[action].grab_focus()


func _label_of(action: String) -> String:
	for b in Settings.BINDABLE:
		if b.action == action:
			return b.label
	return action
