extends "res://scripts/ui/menu/overlay.gd"
## Save slot list. Modes: "new" (pick a slot for a new run), "load", "save". Writing over or deleting a used slot
## asks once more on the same button ("Overwrite?" / "Delete?") instead of opening another dialog.

signal chosen(mode: String, slot: int)

var mode := "load"
var _title: Label
var _rows: VBoxContainer


func _init() -> void:
	super(620)
	_title = title("Load game")
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	box.add_child(_rows)
	box.add_child(UI.button("Back", func(): back.emit()))


func open_mode(m: String) -> void:
	mode = m
	_title.text = {"new": "New game: choose a slot", "load": "Load game", "save": "Save game"}[m]
	refresh()
	open()


func refresh() -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	for i in range(1, GameState.SLOTS + 1):
		_rows.add_child(_row(i))


func _row(i: int) -> Control:
	var info := GameState.slot_info(i)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var current := mode == "save" and i == GameState.slot and GameState.game != null
	var name := UI.label("Slot %d%s" % [i, " •" if current else ""], 18, UI.ACCENT if current else UI.TEXT)
	name.custom_minimum_size.x = 90
	row.add_child(name)
	var desc := UI.label(describe(info), 14, UI.MUTED)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(desc)
	var used := not info.is_empty()
	var verb: String = {"new": "Start", "load": "Load", "save": "Save"}[mode]
	var act := UI.button(verb, func(): pass, 110)
	act.name = "Act"
	act.disabled = mode == "load" and (not used or info.has("broken"))
	# the real handler needs the button itself (for the confirm text), so it is connected after creation
	var needs_confirm := used and mode != "load" and not current
	act.pressed.connect(func():
		if needs_confirm and act.text != "Overwrite?":
			act.text = "Overwrite?"
			return
		chosen.emit(mode, i))
	row.add_child(act)
	if used:
		var del := UI.button("Delete", func(): pass, 90)
		del.name = "Delete"
		del.pressed.connect(func():
			if del.text != "Delete?":
				del.text = "Delete?"
				return
			GameState.delete_slot(i)
			refresh()
			focus_first())
		row.add_child(del)
	else:
		var gap := Control.new()  # keeps the action buttons in one column
		gap.custom_minimum_size.x = 90
		row.add_child(gap)
	return row


static func describe(info: Dictionary) -> String:
	if info.is_empty():
		return "Empty"
	if info.has("broken"):
		return "Unreadable save file"
	var when := Time.get_datetime_string_from_unix_time(int(info.saved_at) + _utc_offset(), true)
	var state := ""
	if info.state == "won":
		state = "  · debt cleared"
	elif info.state == "lost":
		state = "  · run lost"
	return "Day %d · %s cr · %s%s\nSaved %s" % [info.day, _thousands(info.credits), info.location, state, when.substr(0, 16)]


static func _utc_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
