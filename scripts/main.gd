extends Node
## Root of the game: builds the world, HUD and menus, and switches between flight, docked, on-foot (planet surface),
## paused and menu states. Docking at a location with an entry in data/surfaces.json lands on its surface instead of
## opening the docked menu; each surface is its own instance, created on landing and freed on take-off.

const UI = preload("res://scripts/ui/ui_theme.gd")
const WorldScript = preload("res://scripts/world/world.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const StationScript = preload("res://scripts/ui/station_ui.gd")
const BenchScript = preload("res://scripts/ui/bench_ui.gd")
const SurfaceScript = preload("res://scripts/planet/surface.gd")
const EstateLayout = preload("res://scripts/planet/estate_layout.gd")
const MainMenuScript = preload("res://scripts/ui/menu/main_menu.gd")
const PauseMenuScript = preload("res://scripts/ui/menu/pause_menu.gd")
const SlotPanelScript = preload("res://scripts/ui/menu/slot_panel.gd")
const SettingsPanelScript = preload("res://scripts/ui/menu/settings_panel.gd")
const PhoneScript = preload("res://scripts/ui/phone/phone.gd")
const HyperspaceScript = preload("res://scripts/ui/hyperspace.gd")
const InterdictCardScript = preload("res://scripts/ui/interdict_card.gd")
const Interdiction = preload("res://scripts/core/interdiction.gd")
const Escort = preload("res://scripts/core/escort.gd")
const Galaxy = preload("res://scripts/core/galaxy.gd")
const Deals = preload("res://scripts/core/deals.gd")
const Dealers = preload("res://scripts/core/dealers.gd")
const Quests = preload("res://scripts/core/quests.gd")

## Which station tab a surface interaction opens.
const SURFACE_TABS := {"market": "Market", "shipyard": "Shipyard", "office": "Office", "deal": "Deals", "fence": "Deals"}

const ACTIONS := {
	"ship_thrust": [KEY_W, KEY_UP],
	"ship_reverse": [KEY_S, KEY_DOWN],
	"ship_brake": [KEY_SPACE],
	"ship_left": [KEY_A, KEY_LEFT],
	"ship_right": [KEY_D, KEY_RIGHT],
	"ship_dock": [KEY_E],
	"ship_fire": [KEY_J],
	"ship_missile": [KEY_K],
	"ship_cycle": [KEY_Q],
	"ship_boost": [KEY_SHIFT],
	"ui_menu": [KEY_ESCAPE, KEY_P],
	"phone": [KEY_TAB],
	"quick_save": [KEY_F5],
	"quick_load": [KEY_F9],
	"ship_autopilot": [KEY_T],
}

var world: Node2D
var surface: Node2D  ## current planet surface instance, null in space
var hud: Control
var station: Control
var bench: Control  ## station overlay on foot: start a tray, mix, play the station minigame (G2)
var hyper: Control  ## jump-drive charge streaks and the hyperspace transition
var interdict: Control  ## interdiction card after a jump (D3)
var phone: Control  ## Com-Phone overlay (scripts/ui/phone), usable in flight and on foot
var menu: Control
var pause_menu: Control
var slot_panel: Control  ## save slot list (new / load / save), opened from the main or pause menu
var settings_panel: Control
var end_screen: Control
var _ui_layer: CanvasLayer
var _ui_root: Control  ## every overlay lives under it; K3 scales it for the "Text & UI size" setting
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
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel-art UI frames
	_ui_layer.add_child(root)
	_ui_root = root
	_apply_ui_scale()
	Settings.changed.connect(_apply_ui_scale)
	get_viewport().size_changed.connect(_apply_ui_scale)
	hud = HudScript.new()
	hud.world = world
	world.ship.goal_provider = hud.quest_point
	root.add_child(hud)
	station = StationScript.new()
	root.add_child(station)
	station.close_requested.connect(station.close)
	bench = BenchScript.new()
	root.add_child(bench)
	bench.take_down_requested.connect(func(i: int):
		if surface != null and surface.cfg.has("estate") and GameState.act(GameState.game.remove_building(surface.cfg.estate, i)).ok:
			enter_estate(surface.cfg.estate, surface.player.position))
	phone = PhoneScript.new()
	root.add_child(phone)
	hyper = HyperspaceScript.new()
	root.add_child(hyper)
	interdict = InterdictCardScript.new()
	root.add_child(interdict)
	interdict.resolved.connect(_on_interdiction_resolved)
	station.estate_enter_requested.connect(func(eid: String): enter_estate(eid))
	station.place_requested.connect(func(st: String):
		station.close()
		if surface != null:
			surface.placing = st)
	station.estate_changed.connect(func():
		if surface != null and surface.cfg.has("estate"):
			enter_estate(surface.cfg.estate, surface.player.position))
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


## K3: scale the whole UI (HUD, panels, phone) by Settings.ui_scale while it still covers exactly the screen.
func _apply_ui_scale() -> void:
	var s: float = Settings.UI_SCALES[Settings.ui_scale]
	var vp := get_viewport().get_visible_rect().size
	_ui_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_ui_root.position = Vector2.ZERO
	_ui_root.scale = Vector2(s, s)
	_ui_root.size = vp / s


func _register_input() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func _in_game() -> bool:
	return GameState.game != null and not (menu.visible or end_screen.visible or slot_panel.visible or settings_panel.visible)


## The phone key is read here, before the GUI, so Tab never ends up as focus navigation.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("phone") and _in_game() and not GameState.paused:
		toggle_phone()
		get_viewport().set_input_as_handled()


func toggle_phone() -> void:
	if not phone.visible:
		station.close()
		bench.close()
		if surface != null:
			surface.placing = ""
	phone.toggle()


func _unhandled_input(event: InputEvent) -> void:
	if not _in_game():
		return
	if event.is_action_pressed("quick_save") and not GameState.paused:
		quick_save()
		return
	if event.is_action_pressed("quick_load"):
		quick_load()
		return
	if phone.visible and event.is_action_pressed("ui_menu") and not GameState.paused:
		phone.back()
		return
	if phone.visible and not event.is_action_pressed("ui_menu"):
		return
	if event.is_action_pressed("ui_menu"):
		if surface != null and surface.placing != "" and not GameState.paused:
			surface.placing = ""
		elif surface != null and station.visible and not GameState.paused:
			station.close()
		else:
			toggle_pause()
	elif surface != null:
		if event.is_action_pressed("interact") and not GameState.paused:
			if station.visible:
				station.close()
			else:
				surface.interact()
		elif event.is_action_pressed("build_menu") and not GameState.paused and surface.cfg.has("estate") and not station.visible:
			open_build_menu()
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


## K3: F5 writes the run to its slot, F9 reloads that slot (both rebindable).
func quick_save() -> void:
	if GameState.game == null or GameState.game.state != "playing":
		return
	if GameState.save_game():
		EventBus.toast.emit("Quick-saved to slot %d." % GameState.slot, true)
	else:
		EventBus.toast.emit("Could not save.", false)


func quick_load() -> void:
	if interdict.visible:
		return
	if not GameState.slot_exists(GameState.slot):
		EventBus.toast.emit("Nothing saved in slot %d yet." % GameState.slot, false)
		return
	if GameState.paused:
		toggle_pause()
	phone.close()
	station.close()
	bench.close()
	load_slot(GameState.slot)
	EventBus.toast.emit("Quick-loaded slot %d." % GameState.slot, true)


func continue_game() -> void:
	load_slot(GameState.latest_slot())


func load_slot(i: int) -> void:
	if i != 0 and GameState.load_game(i):
		_enter_game()
	else:
		EventBus.toast.emit("Could not load slot %d." % i, false)


func _process(_delta: float) -> void:
	if surface != null:
		surface.player.frozen = GameState.paused or station.visible or bench.visible or end_screen.visible or phone.visible
	world.input_blocked = phone.visible
	var gm = GameState.game
	hyper.charge = Galaxy.progress(gm) if gm != null and Galaxy.charging(gm) else 0.0


func _enter_game() -> void:
	_leave_surface()
	menu.close()
	end_screen.visible = false
	interdict.visible = false
	pause_menu.close()
	slot_panel.close()
	settings_panel.close()
	phone.close()
	hud.visible = true
	world.clear_patrols()
	var g = GameState.game
	world.place_ship_at(_resume_spot(g))
	GameState.paused = false
	AudioManager.set_ambient(true)
	if g.location != "":
		dock(g.location)
	else:
		world.active = true


## Where the ship reappears on load: the docked location, else the arrival side of the saved system.
func _resume_spot(g) -> String:
	if g.location != "":
		return g.location
	if g.loc_system(g.data.start.location) == g.system:
		return g.data.start.location
	for l in g.locations_in(g.system):
		if g.data.locations[l].has("jump_to"):
			return l
	return g.patrol_home(g.system)


func dock(loc: String) -> void:
	var g = GameState.game
	if GameState.data.locations.get(loc, {}).has("jump_to"):
		jump(loc)
		return
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


## Jumps through a gate: toll + travel time in the core, then the arrival (see _arrive).
func jump(gate: String) -> void:
	var g = GameState.game
	var r: Dictionary = GameState.act(g.jump(gate))
	if r.ok:
		_arrive(gate)


## The charged jump drive fires: the core pays the next hop's toll and jumps through the gate on that lane.
func _engage_drive() -> void:
	var r: Dictionary = GameState.act(Galaxy.engage(GameState.game))
	if r.ok:
		_arrive(r.gate)


## Builds the next system around the ship at the arrival gate and plays the hyperspace transition.
func _arrive(gate: String) -> void:
	var g = GameState.game
	var arrive: String = GameState.data.locations[gate].get("arrive", "")
	world.show_system(g.system)
	world.place_ship_at(arrive if world.locations.has(arrive) else g.patrol_home(g.system))
	world.ship.velocity = Vector2.DOWN * 220.0
	hyper.play_jump(str(g.system_data().get("name", g.system)))
	GameState.save_game()


## A jump was intercepted: freeze the flight and put the choice in front of the player.
func _show_interdiction() -> void:
	var g = GameState.game
	if g == null or not Interdiction.pending(g):
		return
	phone.close()
	world.ship.stop()
	GameState.paused = true
	interdict.open(g)


func _on_interdiction_resolved(r: Dictionary) -> void:
	GameState.paused = false
	EventBus.toast.emit(str(r.msg), not r.fight)
	if r.fight:
		var g = GameState.game
		var ahead: Vector2 = world.ship.position + Vector2.UP.rotated(world.ship.rotation) * 520.0
		world.combat.spawn_wing(g, str(r.cartel), r.units, ahead)
		world.combat.shake = 6.0
	GameState.save_game()


## Loads the planet surface instance for `loc` and hands the camera to the player on foot.
func _land(loc: String, announce := true) -> void:
	_leave_surface()
	surface = SurfaceScript.new()
	surface.setup(loc, _with_ship_ramp(GameState.data.surfaces[loc]))
	surface.interacted.connect(_on_surface_action)
	add_child(surface)
	move_child(surface, world.get_index() + 1)
	world.visible = false
	hud.surface = surface
	surface.place_player_at("pad")
	GameState.game.note("landed", {"location": loc})
	if announce:
		EventBus.toast.emit("Landed on %s. Walk to a building or person and press E." % GameState.data.locations[loc].name, true)


## The planet layout plus a ramp beside the landing pad that leads into the ship's cargo bay.
func _with_ship_ramp(cfg: Dictionary) -> Dictionary:
	var c: Dictionary = cfg.duplicate()
	if c.has("pad"):
		var pp: Array = c.pad.pos
		var exits: Array = c.get("exits", []).duplicate()
		exits.append({"id": "ship_bay", "pos": [float(pp[0]) + 2.4, float(pp[1])], "label": "Cargo bay (your ship)", "action": "enter_ship_bay"})
		c.exits = exits
	return c


func enter_ship_bay() -> void:
	var g = GameState.game
	if GameState.act(g.enter_ship_bay()).ok:
		enter_estate(g.SHIP_BAY)


func _leave_surface() -> void:
	if GameState.game != null:
		GameState.game.inside_estate = ""
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
	var g = GameState.game
	match action:
		"takeoff":
			undock()
			return
		"estate":
			var eid: String = GameState.data.surfaces[g.location].buildings.filter(func(b): return b.id == p.id)[0].estate
			if g.estate_owned(eid):
				enter_estate(eid)
			else:
				station.open({"tabs": ["Estate"], "title": GameState.data.estates[eid].name, "estate": eid})
			return
		"exit_estate":
			leave_estate()
			return
		"stash":
			station.open({"tabs": ["Stash"], "title": "Stash crate", "estate": surface.cfg.estate})
			return
		"enter_ship_bay":
			enter_ship_bay()
			return
		"station":
			var bd: Dictionary = surface.cfg.buildings.filter(func(b): return b.id == p.id)[0]
			bench.open_station(bd.station, bd.index)
			return
		"place":
			if GameState.act(g.place_building(surface.cfg.estate, p.station, p.x, p.y)).ok:
				enter_estate(surface.cfg.estate, surface.player.position)
			return
	if not SURFACE_TABS.has(action):
		return
	if p.get("contact", "") != "":
		GameState.game.meet(p.contact)
	station.open({"tabs": [SURFACE_TABS[action]], "title": p.title, "contact": p.get("contact", ""), "fence_only": action == "fence"})


## Instances the inside of an owned estate (on the current planet) and puts the player at the door, or at `at`
## when the room is rebuilt after placing/removing a station.
func enter_estate(eid: String, at = null) -> void:
	var g = GameState.game
	station.close()
	_leave_surface()
	surface = SurfaceScript.new()
	surface.setup("estate:" + eid, EstateLayout.build_cfg(GameState.data, eid, g.estates[eid].buildings, g.style.get("decor", [])))
	g.inside_estate = eid
	g.note("entered_estate", {"estate": eid})
	surface.can_place = func(st: String, x: int, y: int) -> bool: return g.can_place(eid, st, x, y)
	surface.interacted.connect(_on_surface_action)
	add_child(surface)
	move_child(surface, world.get_index() + 1)
	world.visible = false
	hud.surface = surface
	if at != null:
		surface.player.position = at
	else:
		surface.place_player_at("exit")
		EventBus.toast.emit("%s. [%s] build menu." % [GameState.data.estates[eid].name, Settings.key_label("build_menu")], true)


## Back out onto the planet, in front of the estate's door.
func leave_estate() -> void:
	var eid: String = surface.cfg.estate
	var loc: String = GameState.game.location
	if eid == GameState.game.SHIP_BAY and not GameState.data.get("surfaces", {}).has(loc):
		_leave_surface()  # stations without a surface: back to the docked menu
		station.open()
		return
	_land(loc, false)
	for b in GameState.data.surfaces[loc].buildings:
		if b.get("estate", "") == eid:
			surface.place_player_at(b.id)


func open_build_menu() -> void:
	station.open({"tabs": ["Build"], "title": "Build – %s" % GameState.data.estates[surface.cfg.estate].name, "estate": surface.cfg.estate})


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
	if interdict.visible:
		return
	GameState.paused = not GameState.paused
	if GameState.paused:
		pause_menu.open()
	else:
		pause_menu.close()
		slot_panel.close()
		settings_panel.close()


func show_main_menu() -> void:
	GameState.paused = true
	phone.close()
	world.active = false
	_leave_surface()
	station.close()
	hud.visible = false
	pause_menu.close()
	slot_panel.close()
	settings_panel.close()
	end_screen.visible = false
	interdict.visible = false
	menu.open()
	AudioManager.set_ambient(false)


func _on_game_event(kind: String, p: Dictionary) -> void:
	if kind == "game_over":
		GameState.paused = true
		world.active = false
		station.close()
		phone.close()
		var g = GameState.game
		if p.won:
			var left: int = (g.quests.active as Array).filter(func(q): return Quests.defs(g).get(q, {}).get("main", false)).size()
			_end_label.text = "DEBT CLEARED · CHAPTER 1 COMPLETE\n\nThe Consortium closes your account. Day %d, %d cr earned, %d units moved, busted %d×.\n%s" % [g.day, g.stats.earned, g.stats.units_sold, g.stats.busts,
				"Your main quest goes on: check the Quests app." if left > 0 else "The cartel war is over for now. Chapter 3 arrives in a later build."]
		else:
			_end_label.text = "THE CONSORTIUM CAME TO COLLECT\n\nYou still owed %d cr on day %d.\nEarned %d cr, moved %d units, busted %d×." % [g.debt, g.day, g.stats.earned, g.stats.units_sold, g.stats.busts]
		end_screen.visible = true
		GameState.save_game()
	elif kind == "offer_new":
		var o: Dictionary = Deals.find(GameState.game, p.offer)
		EventBus.toast.emit("%s wants %d %s at %s. [%s] Deal-O-Matic" % [GameState.game.contact(p.contact).name, o.qty, GameState.data.bases[o.base].name, Deals.clock_text(GameState.game, float(o.get("meet_at", 0.0))), Settings.key_label("phone")], true)
	elif kind == "meet_soon":
		var mo: Dictionary = Deals.find(GameState.game, p.offer)
		EventBus.toast.emit("Meeting with %s at %s on %s." % [GameState.game.contact(p.contact).name, Deals.clock_text(GameState.game, float(mo.meet_at)), GameState.game.loc_data(GameState.game.contact(p.contact).location).get("name", "")], true)
	elif kind == "offer_expired" and p.was == "accepted":
		EventBus.toast.emit("You missed the meet with %s." % GameState.game.contact(p.contact).name, false)
	elif kind == "drop_pickup":
		EventBus.toast.emit(("Drop cleared: %s paid %d cr." % [GameState.game.contact(p.contact).name, p.credits]) if p.kind == "deal" else "Courier delivered %d × %s to your stash." % [p.qty, GameState.game.item_name(p.item)], true)
	elif kind == "drop_stolen":
		EventBus.toast.emit("A drop was cleaned out: %d units stolen." % p.qty, false)
	elif kind == "product_discovered":
		EventBus.toast.emit("New product: %s. Price it in the Products app [%s]." % [GameState.game.item_name(p.product), Settings.key_label("phone")], true)
	elif kind == "dealer_busted":
		EventBus.toast.emit("%s got busted on %s: %d units and %d cr gone." % [Dealers.candidate(GameState.game, p.dealer).name, GameState.game.loc_data(p.loc).get("name", ""), p.units, p.credits], false)
	elif kind == "dealer_cash_full":
		EventBus.toast.emit("%s is holding max cash. Pick it up." % Dealers.candidate(GameState.game, p.dealer).name, true)
	elif kind == "dealer_free":
		EventBus.toast.emit("%s is out of jail." % Dealers.candidate(GameState.game, p.dealer).name, true)
	elif kind == "met":
		EventBus.toast.emit("New contact: %s. Open the Com-Phone [%s]." % [GameState.game.contact(p.contact).name, Settings.key_label("phone")], true)
	elif kind == "referral":
		EventBus.toast.emit(str(p.text), true)
	elif kind == "notice":
		EventBus.toast.emit(p.text, p.good)
	elif kind == "turf_changed":
		var gm = GameState.game
		var where: String = gm.loc_data(p.loc).get("name", p.loc)
		if p.by == "you":
			EventBus.toast.emit("%s is your turf now: better prices, fewer raiders." % where, true)
		elif p.was == "you":
			EventBus.toast.emit("You lost your grip on %s." % where, false)
		elif p.by != "":
			EventBus.toast.emit("The %s took over %s." % [gm.data.cartels.gangs[p.by].name, where], false)
	elif kind == "dealer_robbed":
		var gm = GameState.game
		EventBus.toast.emit("%s robbed %s on %s: %d cr and %d units gone." % [gm.data.cartels.gangs.get(p.cartel, {}).get("name", "A cartel"), Dealers.candidate(gm, p.dealer).name, gm.loc_data(p.loc).get("name", ""), p.credits, p.units], false)
	elif kind == "interdicted":
		_show_interdiction.call_deferred()  # after _arrive has built the new system
	elif kind == "jump_ready":
		_engage_drive.call_deferred()  # not inside Game.tick: the jump ticks the game itself
	elif kind == "jump_cancelled":
		EventBus.toast.emit(str(p.why), false)
	elif kind == "busted":
		EventBus.toast.emit("BUSTED: lost %d units, fined %d cr." % [p.lost, p.fine], false)
	elif kind == "escort_done":
		EventBus.toast.emit("Freighter delivered: +%d cr%s." % [p.credits, " (intact hull bonus)" if float(p.hull_ratio) >= 0.99 else ""], true)
	elif kind == "escort_failed":
		EventBus.toast.emit(Escort.fail_text(GameState.game, str(p.mission), str(p.why)), false)
	elif kind == "quest_started":
		EventBus.toast.emit("New quest: %s" % Quests.defs(GameState.game).get(p.quest, {}).get("title", p.quest), true)
	elif kind == "quest_step":
		var qs: Array = Quests.steps(GameState.game, p.quest)
		if int(p.step) < qs.size() - 1:
			EventBus.toast.emit("✓ %s" % qs[int(p.step)].get("text", ""), true)
	elif kind == "quest_done":
		var rw: Dictionary = p.get("reward", {})
		EventBus.toast.emit("Quest complete: %s%s" % [Quests.defs(GameState.game).get(p.quest, {}).get("title", p.quest), "  +%d cr" % int(rw.credits) if rw.has("credits") else ""], true)
	elif kind == "quest_retry" and str(p.get("text", "")) != "":
		EventBus.toast.emit(str(p.text), false)


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
	v.add_child(UI.button("Keep playing", func():
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
