extends "res://scripts/ui/menu/overlay.gd"
## Title screen: Continue (latest save), New game, Load game, Settings, Quit. main.gd connects the signals.

signal continue_pressed
signal new_game_pressed
signal load_pressed
signal settings_pressed
signal quit_pressed

var continue_btn: Button
var load_btn: Button
var _continue_info: Label


func _init() -> void:
	super(520)
	title("SPACEPLUG", 54)
	var s := UI.label("Cook. Mix. Smuggle. Pay the Consortium.", 18, UI.MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	continue_btn = UI.button("Continue", func(): continue_pressed.emit())
	box.add_child(continue_btn)
	_continue_info = UI.label("", 13, UI.MUTED)
	_continue_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_continue_info)
	box.add_child(UI.button("New game", func(): new_game_pressed.emit()))
	load_btn = UI.button("Load game", func(): load_pressed.emit())
	box.add_child(load_btn)
	box.add_child(UI.button("Settings", func(): settings_pressed.emit()))
	box.add_child(UI.button("Quit", func(): quit_pressed.emit()))
	var help := UI.label("You start on Mireth with a debt to the Ouroboros Consortium.\nBuy Cannabis Buds and additives, cook product in your lab, sell to contacts across the sector.\nEvery deal raises heat. Heat brings patrols – stay out of their scan circles while carrying product.", 14, UI.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	var ver := UI.label("v%s" % ProjectSettings.get_setting("application/config/version", "dev"), 12, UI.MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(ver)


func open() -> void:
	var latest := GameState.latest_slot()
	continue_btn.disabled = latest == 0
	load_btn.disabled = latest == 0
	_continue_info.visible = latest != 0
	if latest != 0:
		_continue_info.text = "Slot %d · %s" % [latest, _short(latest)]
	super()


func _short(i: int) -> String:
	var info := GameState.slot_info(i)
	if info.has("broken"):
		return "unreadable"
	return "Day %d · %s" % [info.day, info.location]
