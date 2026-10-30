extends Node
## Root of the game: builds the world, HUD and menus, and switches between flight, docked, paused and menu states.

const UI = preload("res://scripts/ui/ui_theme.gd")
const WorldScript = preload("res://scripts/world/world.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const StationScript = preload("res://scripts/ui/station_ui.gd")

const ACTIONS := {
	"ship_thrust": [KEY_W, KEY_UP],
	"ship_reverse": [KEY_S, KEY_DOWN],
	"ship_brake": [KEY_SPACE],
	"ship_left": [KEY_A, KEY_LEFT],
	"ship_right": [KEY_D, KEY_RIGHT],
	"ship_dock": [KEY_E],
	"ui_menu": [KEY_ESCAPE, KEY_P],
}

var world: Node2D
var hud: Control
var station: Control
var menu: Control
var pause_menu: Control
var end_screen: Control
var _ui_layer: CanvasLayer
var _end_label: Label


func _ready() -> void:
	_register_input()
	world = WorldScript.new()
	add_child(world)
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.build()
	_ui_layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud = HudScript.new()
	hud.world = world
	root.add_child(hud)
	station = StationScript.new()
	root.add_child(station)
	menu = _build_main_menu()
	root.add_child(menu)
	pause_menu = _build_pause_menu()
	root.add_child(pause_menu)
	end_screen = _build_end_screen()
	root.add_child(end_screen)
	EventBus.undock_requested.connect(undock)
	EventBus.game_event.connect(_on_game_event)
	show_main_menu()


func _register_input() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.game == null or menu.visible or end_screen.visible:
		return
	if event.is_action_pressed("ui_menu"):
		toggle_pause()
	elif event.is_action_pressed("ship_dock") and not GameState.paused:
		if station.visible:
			undock()
		elif world.nearby != "":
			dock(world.nearby)


# ---------------------------------------------------------------- state changes

func start_new_game(seed_value: int = 0) -> void:
	GameState.new_game(seed_value)
	_enter_game()
	EventBus.toast.emit("You owe the Ouroboros Consortium %d cr. Cook, sell, pay up." % GameState.game.debt, true)


func continue_game() -> void:
	if GameState.load_game():
		_enter_game()


func _enter_game() -> void:
	menu.visible = false
	end_screen.visible = false
	pause_menu.visible = false
	hud.visible = true
	world.clear_patrols()
	var g = GameState.game
	var loc: String = g.location if g.location != "" else g.data.start.location
	world.place_ship_at(loc)
	GameState.paused = false
	AudioManager.set_ambient(true)
	if g.location != "":
		dock(g.location)
	else:
		world.active = true


func dock(loc: String) -> void:
	var g = GameState.game
	if g.location != loc:
		var r: Dictionary = g.dock(loc)
		if not r.ok:
			GameState.act(r)
			return
	world.active = false
	world.ship.stop()
	EventBus.scan_progress.emit(0.0)
	world.scan = 0.0
	station.open()


func undock() -> void:
	var g = GameState.game
	if g == null or g.location == "":
		return
	var loc: String = g.location
	g.undock()
	station.close()
	world.place_ship_at(loc)
	world.active = true
	GameState.save_game()


func toggle_pause() -> void:
	GameState.paused = not GameState.paused
	pause_menu.visible = GameState.paused


func show_main_menu() -> void:
	GameState.paused = true
	world.active = false
	station.close()
	hud.visible = false
	pause_menu.visible = false
	end_screen.visible = false
	menu.visible = true
	_continue_btn.disabled = not GameState.has_save()
	AudioManager.set_ambient(false)


func _on_game_event(kind: String, p: Dictionary) -> void:
	if kind == "game_over":
		GameState.paused = true
		world.active = false
		station.close()
		var g = GameState.game
		if p.won:
			_end_label.text = "DEBT CLEARED\n\nThe Consortium tips its hat. Day %d, %d cr earned, %d units moved, busted %d×.\nThe Reach is yours to grow (more systems coming in the next builds)." % [g.day, g.stats.earned, g.stats.units_sold, g.stats.busts]
		else:
			_end_label.text = "THE CONSORTIUM CAME TO COLLECT\n\nYou still owed %d cr on day %d.\nEarned %d cr, moved %d units, busted %d×." % [g.debt, g.day, g.stats.earned, g.stats.units_sold, g.stats.busts]
		end_screen.visible = true
		GameState.save_game()
	elif kind == "busted":
		EventBus.toast.emit("BUSTED: lost %d units, fined %d cr." % [p.lost, p.fine], false)


# ---------------------------------------------------------------- menus

var _continue_btn: Button


func _centered_panel(width: int) -> Array:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.04, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	return [c, v]


func _build_main_menu() -> Control:
	var pv := _centered_panel(520)
	var v: VBoxContainer = pv[1]
	var t := UI.label("SPACEPLUG", 54, UI.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UI.label("Cook. Mix. Smuggle. Pay the Consortium.", 18, UI.MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	v.add_child(UI.button("New run", func(): start_new_game()))
	_continue_btn = UI.button("Continue", continue_game)
	v.add_child(_continue_btn)
	v.add_child(UI.button("Sound: on/off", func(): AudioManager.set_enabled(not AudioManager.enabled)))
	v.add_child(UI.button("Quit", func(): get_tree().quit()))
	var help := UI.label("You start on Mireth with a debt to the Ouroboros Consortium.\nBuy Cannabis Buds and additives, cook product in your lab, sell to contacts across the sector.\nEvery deal raises heat. Heat brings patrols – stay out of their scan circles while carrying product.", 14, UI.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(help)
	var ver := UI.label("v%s" % ProjectSettings.get_setting("application/config/version", "dev"), 12, UI.MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(ver)
	return pv[0]


func _build_pause_menu() -> Control:
	var pv := _centered_panel(360)
	var v: VBoxContainer = pv[1]
	var t := UI.label("Paused", 30, UI.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UI.button("Resume", toggle_pause))
	v.add_child(UI.button("Save", func(): EventBus.toast.emit("Game saved." if GameState.save_game() else "Save failed.", true)))
	v.add_child(UI.button("Sound: on/off", func(): AudioManager.set_enabled(not AudioManager.enabled)))
	v.add_child(UI.button("Save & main menu", func():
		GameState.save_game()
		show_main_menu()))
	pv[0].visible = false
	return pv[0]


func _build_end_screen() -> Control:
	var pv := _centered_panel(620)
	var v: VBoxContainer = pv[1]
	_end_label = UI.label("", 20)
	_end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_label)
	v.add_child(UI.button("Keep flying (sandbox)", func():
		end_screen.visible = false
		if GameState.game.state == "won":
			GameState.game.state = "playing"
			GameState.paused = false
			_enter_game()
		else:
			show_main_menu()))
	v.add_child(UI.button("New run", func(): start_new_game()))
	v.add_child(UI.button("Main menu", show_main_menu))
	pv[0].visible = false
	return pv[0]
