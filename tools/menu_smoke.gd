extends SceneTree
## Menu smoke test: drives the main menu, save slots, pause menu and settings through the real main scene, with real
## key events for Esc and rebinding. Also checks settings persistence and the move of the old single save into slot 1.
## godot --headless --path . -s res://tools/menu_smoke.gd   (prints MENU DONE; CI greps for SCRIPT ERROR)

var steps := 0
var gs: Node
var st: Node


func _init() -> void:
	create_timer(60.0).timeout.connect(func():
		printerr("MENU FAIL: timeout")
		quit(1))
	_run()


func step(name: String) -> void:
	steps += 1
	print("MENU %s" % name)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
	await process_frame


func press(b: Button) -> void:
	_assert(b != null and b.is_visible_in_tree() and not b.disabled, "button %s pressable" % (b.text if b else "null"))
	b.pressed.emit()
	await frames(2)


func _run() -> void:
	await process_frame
	gs = root.get_node("GameState")
	st = root.get_node("Settings")
	gs.save_prefix = "user://menu_smoke_"
	st.config_path = "user://menu_smoke_settings.cfg"
	_cleanup()
	root.get_node("AudioManager").set_enabled(false)

	# old single save file moves into slot 1
	var legacy := "user://menu_smoke_legacy.json"
	var f := FileAccess.open(legacy, FileAccess.WRITE)
	f.store_string(JSON.stringify({"credits": 1234, "day": 3, "location": "mireth"}))
	f.close()
	gs._migrate_legacy_save(legacy)
	_assert(gs.slot_exists(1) and not FileAccess.file_exists(legacy), "legacy save moved to slot 1")
	_assert(gs.slot_info(1).day == 3 and gs.slot_info(1).credits == 1234, "slot info read (%s)" % gs.slot_info(1))
	gs.delete_slot(1)
	_assert(not gs.has_save(), "slot deleted")
	step("legacy save migration")

	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await frames(3)
	_assert(m.menu.visible and m.menu.continue_btn.disabled and m.menu.load_btn.disabled, "fresh main menu, nothing to continue")

	# New game -> pick slot 2
	await press(_btn(m.menu, "New game"))
	_assert(m.slot_panel.visible and m.slot_panel.mode == "new", "slot picker for a new game")
	await key(KEY_ESCAPE)
	_assert(not m.slot_panel.visible and m.menu.visible, "Esc closes the slot picker")
	await press(_btn(m.menu, "New game"))
	await press(_slot_btn(m, 2, "Act"))
	_assert(gs.game != null and gs.slot == 2 and gs.slot_exists(2), "new run written to slot 2")
	_assert(not m.menu.visible and not m.slot_panel.visible and m.hud.visible and not gs.paused, "in game")
	step("new game in slot 2")

	# Esc pauses, Esc resumes
	await key(KEY_ESCAPE)
	_assert(gs.paused and m.pause_menu.visible, "Esc opens the pause menu")
	await key(KEY_ESCAPE)
	_assert(not gs.paused and not m.pause_menu.visible, "Esc resumes")
	await key(KEY_ESCAPE)
	await press(_btn(m.pause_menu, "Settings"))
	_assert(m.settings_panel.visible, "settings open from pause")
	await key(KEY_ESCAPE)
	_assert(not m.settings_panel.visible and m.pause_menu.visible and gs.paused, "Esc leaves settings back to pause")
	step("pause menu")

	# Save to slot 3 (empty, no confirm), then slot 2 is the current slot (no confirm either)
	gs.game.credits = 777
	await press(_btn(m.pause_menu, "Save game"))
	await press(_slot_btn(m, 3, "Act"))
	_assert(gs.slot == 3 and gs.slot_info(3).credits == 777 and not m.slot_panel.visible, "saved to slot 3")
	# overwriting another used slot asks once
	await press(_btn(m.pause_menu, "Save game"))
	var b2 := _slot_btn(m, 2, "Act")
	await press(b2)
	_assert(b2.text == "Overwrite?" and m.slot_panel.visible, "overwrite needs a second press")
	await press(b2)
	_assert(gs.slot == 2 and gs.slot_info(2).credits == 777, "overwrote slot 2")
	step("save slots")

	# main menu: continue loads the latest slot, load picks any slot, delete asks once
	await press(_btn(m.pause_menu, "Save & main menu"))
	_assert(m.menu.visible and not m.menu.continue_btn.disabled, "back at the main menu with a save")
	gs.game.credits = 5
	await press(m.menu.continue_btn)
	_assert(gs.game.credits == 777 and m.hud.visible, "continue loads the latest save")
	await key(KEY_ESCAPE)
	await press(_btn(m.pause_menu, "Save & main menu"))
	await press(m.menu.load_btn)
	_assert(m.slot_panel.mode == "load" and _slot_btn(m, 1, "Act").disabled, "empty slot cannot be loaded")
	var del := _slot_btn(m, 3, "Delete")
	await press(del)
	_assert(gs.slot_exists(3), "delete needs a second press")
	await press(del)
	_assert(not gs.slot_exists(3), "slot 3 deleted")
	await press(_slot_btn(m, 2, "Act"))
	_assert(gs.slot == 2 and m.hud.visible and not gs.paused, "loaded slot 2")
	step("continue, load, delete")

	# settings: volume, rebind with a real key press, swap inside a group, persistence, reset
	await key(KEY_ESCAPE)
	await press(_btn(m.pause_menu, "Settings"))
	var sp = m.settings_panel
	var slider: HSlider = sp.find_child("Music", true, false)
	slider.value = 0.25
	var bus := AudioServer.get_bus_index("Music")
	_assert(bus != -1 and absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.25)) < 0.1, "music volume applied")
	slider.value = 0.0
	_assert(AudioServer.is_bus_mute(bus), "zero volume mutes")
	sp.tabs.current_tab = 2
	await frames(1)
	await press(sp.find_child("ship_thrust", true, false))
	await key(KEY_I)
	_assert(st.primary_key("ship_thrust") == KEY_I, "thrust rebound to I")
	_assert(_has_key("ship_thrust", KEY_UP), "arrow key kept as secondary")
	await press(sp.find_child("ship_reverse", true, false))
	await key(KEY_I)
	_assert(st.primary_key("ship_reverse") == KEY_I and st.primary_key("ship_thrust") == KEY_S, "same-group conflict swaps keys")
	await press(sp.find_child("interact", true, false))
	await key(KEY_ESCAPE)
	_assert(st.primary_key("interact") == KEY_E and sp.visible, "Esc cancels a rebind without leaving settings")
	await key(KEY_ESCAPE)
	_assert(not sp.visible and FileAccess.file_exists(st.config_path), "leaving settings saves them")
	st.reset_bindings()
	_assert(st.primary_key("ship_thrust") == KEY_W, "reset restores W")
	st.load_settings()
	st.apply_input()
	_assert(st.primary_key("ship_thrust") == KEY_S and st.primary_key("ship_reverse") == KEY_I, "bindings reload from disk")
	_assert(st.volumes.Music == 0.0, "volume reloads from disk")
	st.reset_bindings()
	st.set_volume("Music", 0.6)
	await key(KEY_ESCAPE)
	step("settings")

	_cleanup()
	print("MENU DONE %d steps" % steps)
	quit(0)


func _btn(panel: Control, text: String) -> Button:
	for b in panel.find_children("*", "Button", true, false):
		if b.text == text:
			return b
	return null


## Button "Act" or "Delete" in row `slot` of the slot list.
func _slot_btn(m, slot: int, which: String) -> Button:
	var row: Node = m.slot_panel._rows.get_child(slot - 1)
	return row.get_node_or_null(which)


func _has_key(action: String, code: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and e.physical_keycode == code:
			return true
	return false


func _cleanup() -> void:
	for i in range(1, gs.SLOTS + 1):
		gs.delete_slot(i)
	if FileAccess.file_exists(st.config_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(st.config_path))


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		printerr("MENU FAIL: " + msg)
		quit(1)
