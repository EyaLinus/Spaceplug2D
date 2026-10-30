extends Node
## Root of the game: builds the world, HUD and menus, and switches between flight, docked, on-foot (planet surface),
## paused and menu states. Docking at a location with an entry in data/surfaces.json lands on its surface instead of
## opening the docked menu; each surface is its own instance, created on landing and freed on take-off.

const UI = preload("res://scripts/ui/ui_theme.gd")
const WorldScript = preload("res://scripts/world/world.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const StationScript = preload("res://scripts/ui/station_ui.gd")
const SurfaceScript = preload("res://scripts/planet/surface.gd")
const MainMenuScript = preload("res://scripts/ui/menu/main_menu.gd")
const PauseMenuScript = preload("res://scripts/ui/menu/pause_menu.gd")
const SlotPanelScript = preload("res://scripts/ui/menu/slot_panel.gd")
const SettingsPanelScript = preload("res://scripts/ui/menu/settings_panel.gd")

## Which station tab a surface interaction opens.
const SURFACE_TABS := {"market": "Market", "lab": "Lab", "shipyard": "Shipyard", "office": "Office", "deal": "Deals", "fence": "Deals"}

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
var surface: Node2D  ## current planet surface instance, null in space
var hud: Control
var station: Control
var menu: Control
var pause_menu: Control
var slot_panel: Control  ## save slot list (new / load / save), opened from the main or pause menu
var settings_panel: Control
var end_screen: Control
var _ui_layer: CanvasLayer
var _end_label: Label


func _ready() -> void:
	_register_input()
	SurfaceScript.register_input()
	Settings.apply_input()
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
	station.close_requested.connect(station.close)
	menu = _build_main_menu()
	root.add_child(menu)
	pause_menu = _build_pause_menu()
	root.add_child(pause_menu)
	end_screen = _build_end_screen()
	root.add_child(end_screen)
	slot_panel = SlotPanelScript.new()
	slot_panel.chosen.connect(_on_slot_chosen)
	slot_panel.back.connect(_close_submenu.bind(slot_panel))
	root.add_child(slot_panel)
	settings_panel = SettingsPanelScript.new()
	settings_panel.back.connect(_close_submenu.bind(settings_panel))
	root.add_child(settings_panel)
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
	if GameState.game == null or menu.visible or end_screen.visible or slot_panel.visible or settings_panel.visible:
		return
	if event.is_action_pressed("ui_menu"):
		if surface != null and station.visible and not GameState.paused:
			station.close()
		else:
			toggle_pause()
	elif surface != null:
		if event.is_action_pressed("interact") and not GameState.paused:
			if station.visible:
				station.close()
			else:
				surface.interact()
	elif event.is_action_pressed("ship_dock") and not GameState.paused:
		if station.visible:
			undock()
		elif world.nearby != "":
			dock(world.nearby)


# ---------------------------------------------------------------- state changes

## Starts a run in `slot` (0 = keep the current slot) and writes it there right away, so the slot shows as used.
func start_new_game(seed_value: int = 0, slot: int = 0) -> void:
	if slot != 0:
		GameState.slot = slot
	GameState.new_game(seed_value)
	GameState.save_game()
	_enter_game()
	EventBus.toast.emit("You owe the Ouroboros Consortium %d cr. Cook, sell, pay up." % GameState.game.debt, true)


func continue_game() -> void:
	load_slot(GameState.latest_slot())


func load_slot(i: int) -> void:
	if i != 0 and GameState.load_game(i):
		_enter_game()
	else:
		EventBus.toast.emit("Could not load slot %d." % i, false)


func _process(_delta: float) -> void:
	if surface != null:
		surface.player.frozen = GameState.paused or station.visible or end_screen.visible


func _enter_game() -> void:
	_leave_surface()
	menu.close()
	end_screen.visible = false
	pause_menu.close()
	slot_panel.close()
	settings_panel.close()
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
	if GameState.data.get("surfaces", {}).has(loc):
		_land(loc)
	else:
		station.open()


## Loads the planet surface instance for `loc` and hands the camera to the player on foot.
func _land(loc: String) -> void:
	_leave_surface()
	surface = SurfaceScript.new()
	surface.setup(loc, GameState.data.surfaces[loc])
	surface.interacted.connect(_on_surface_action)
	add_child(surface)
	move_child(surface, world.get_index() + 1)
	world.visible = false
	hud.surface = surface
	surface.place_player_at("pad")
	EventBus.toast.emit("Landed on %s. Walk to a building or person and press E." % GameState.data.locations[loc].name, true)


func _leave_surface() -> void:
	if surface == null:
		return
	station.close()
	surface.queue_free()
	remove_child(surface)
	surface = null
	hud.surface = null
	world.visible = true
	world.camera.make_current()


func _on_surface_action(action: String, p: Dictionary) -> void:
	if action == "takeoff":
		undock()
		return
	if not SURFACE_TABS.has(action):
		return
	station.open({"tabs": [SURFACE_TABS[action]], "title": p.title, "contact": p.get("contact", ""), "fence_only": action == "fence"})


func undock() -> void:
	var g = GameState.game
	if g == null or g.location == "":
		return
	var loc: String = g.location
	g.undock()
	_leave_surface()
	station.close()
	world.place_ship_at(loc)
	world.active = true
	GameState.save_game()


func toggle_pause() -> void:
	GameState.paused = not GameState.paused
	if GameState.paused:
		pause_menu.open()
	else:
		pause_menu.close()
		slot_panel.close()
		settings_panel.close()


func show_main_menu() -> void:
	GameState.paused = true
	world.active = false
	_leave_surface()
	station.close()
	hud.visible = false
	pause_menu.close()
	slot_panel.close()
	settings_panel.close()
	end_screen.visible = false
	menu.open()
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

func _notification(what: int) -> void:
	# closing the window mid-run keeps the progress (main menu and end screen states are already saved)
	if what == NOTIFICATION_WM_CLOSE_REQUEST and GameState.game != null and hud.visible and not end_screen.visible:
		GameState.save_game()


func _build_main_menu() -> Control:
	var m := MainMenuScript.new()
	m.continue_pressed.connect(continue_game)
	m.new_game_pressed.connect(_open_submenu.bind("new"))
	m.load_pressed.connect(_open_submenu.bind("load"))
	m.settings_pressed.connect(_open_submenu.bind("settings"))
	m.quit_pressed.connect(func(): get_tree().quit())
	return m


func _build_pause_menu() -> Control:
	var p := PauseMenuScript.new()
	p.resume_pressed.connect(toggle_pause)
	p.save_pressed.connect(_open_submenu.bind("save"))
	p.load_pressed.connect(_open_submenu.bind("load"))
	p.settings_pressed.connect(_open_submenu.bind("settings"))
	p.main_menu_pressed.connect(func():
		GameState.save_game()
		show_main_menu())
	p.quit_pressed.connect(func():
		GameState.save_game()
		get_tree().quit())
	return p


## Opens the slot list ("new", "load", "save") or the settings over the main or pause menu.
func _open_submenu(which: String) -> void:
	if which == "settings":
		settings_panel.open()
	else:
		slot_panel.open_mode(which)


func _close_submenu(panel: Control) -> void:
	panel.close()
	(pause_menu if pause_menu.visible else menu).focus_first()


func _on_slot_chosen(mode: String, i: int) -> void:
	match mode:
		"new":
			start_new_game(0, i)
		"load":
			load_slot(i)
		"save":
			GameState.slot = i
			var ok := GameState.save_game()
			EventBus.toast.emit("Saved to slot %d." % i if ok else "Save failed.", ok)
			_close_submenu(slot_panel)


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
