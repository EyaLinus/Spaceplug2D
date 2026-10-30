extends SceneTree
## UI smoke test: boots the real main scene headless, lands on Mireth and walks the planet surface (collision,
## every door and person, take-off), plays the core loop through the UI layer
## (buy, cook, sell, upgrade, bribe, pay), flies between locations, triggers a patrol bust,
## pauses, saves/loads and reaches both end screens. Any GDScript error shows up as "SCRIPT ERROR" (CI greps for it).
## godot --headless --path . -s res://tools/ui_smoke.gd

var steps := 0


func _init() -> void:
	# watchdog: a script error aborts the coroutine, so make sure the run always ends
	create_timer(120.0).timeout.connect(func():
		printerr("SMOKE FAIL: timeout")
		quit(1))
	_run()


func step(name: String) -> void:
	steps += 1
	print("SMOKE %s" % name)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.save_path = "user://smoke_save.json"
	root.get_node("AudioManager").set_enabled(false)
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await frames(3)
	step("main menu")

	m.start_new_game(99)
	await frames(3)
	var g = gs.game
	var sf = m.surface
	_assert(sf != null and not m.station.visible and not m.world.visible, "starts on foot on the Mireth surface")
	_assert(m.get_viewport().get_camera_2d() == sf.camera, "surface camera is current")
	step("landed on surface")

	# walking: free movement works, buildings block
	var start: Vector2 = sf.player.position
	for i in 30:
		sf.player.walk(1.0 / 60.0, Vector2.DOWN)
		await physics_frame
	_assert(sf.player.position.y > start.y + 40.0, "player walks")
	var hangar: Rect2 = sf._rect(sf.cfg.buildings[0].rect)
	sf.player.position = Vector2(hangar.get_center().x, hangar.end.y + 30.0)
	for i in 60:
		sf.player.walk(1.0 / 60.0, Vector2.UP)
		await physics_frame
	_assert(sf.player.position.y >= hangar.end.y - 2.0, "building walls block the player (y=%.0f, wall=%.0f)" % [sf.player.position.y, hangar.end.y])
	step("walk and collide")

	# living planet: schedules, day/night tint, chatter bubbles
	var okka_cfg: Dictionary = sf.cfg.npcs.filter(func(n): return n.id == "okka")[0]
	var spot := func(place: String) -> Vector2: return Vector2(okka_cfg.places[place][0], okka_cfg.places[place][1]) * sf.tile
	var ds: float = g.day_seconds()
	_assert(sf.npc_place("okka") == "home" and sf.npcs.okka.position.distance_to(spot.call("home")) < 2.0, "06:00: Okka starts at home")
	_assert(m.hud._day.text.contains("06:"), "HUD shows the clock on foot (%s)" % m.hud._day.text)
	var dawn_tint: Color = sf._tint.color
	g.day_time = ds * (13.0 - 6.0) / 24.0  # 13:00
	await frames(2)
	_assert(sf.npc_place("okka") == "work" and not sf.npcs.okka.path.is_empty(), "13:00: Okka heads to work")
	for i in 600:
		sf.npcs.okka._process(0.1)
	_assert(sf.npcs.okka.position.distance_to(spot.call("work")) < 4.0, "Okka walks to his work spot (%.0f px off)" % sf.npcs.okka.position.distance_to(spot.call("work")))
	var noon_tint: Color = sf._tint.color
	g.day_time = ds * (18.0 - 6.0) / 24.0  # 18:00
	await frames(2)
	_assert(sf.npc_place("okka") == "plaza", "18:00: Okka is at the plaza")
	g.day_time = ds * (24.0 - 6.0 + 1.0) / 24.0  # 01:00
	await frames(2)
	var night_tint: Color = sf._tint.color
	_assert(sf.npc_place("okka") == "home" and sf.npc_place("sen") == "home", "01:00: everyone is at home")
	_assert(noon_tint.get_luminance() > night_tint.get_luminance() + 0.3 and noon_tint.get_luminance() > dawn_tint.get_luminance(), "tint: noon %.2f brighter than dawn %.2f and night %.2f" % [noon_tint.get_luminance(), dawn_tint.get_luminance(), night_tint.get_luminance()])
	step("npc schedules and tint")
	sf.snap_npcs()
	sf.player.position = sf.npcs.okka.position + Vector2(60, 0)
	var line: String = sf.talk(sf.npcs.okka, okka_cfg)
	_assert(line != "" and sf.npcs.okka.bubble == line, "idle chatter bubble appears (%s)" % line)
	var line2: String = sf.talk(sf.npcs.okka, okka_cfg)
	_assert(line2 != line, "chatter does not repeat the same line twice")
	var timed := false
	sf.npcs.okka.chatter_in = 0.0
	sf.npcs.okka.bubble = ""
	await physics_frame
	await physics_frame
	timed = sf.npcs.okka.bubble != ""
	_assert(timed, "nearby people start chatting on their own")
	step("chatter")
	g.day_time = 0.0
	await frames(2)
	sf.snap_npcs()

	# every door and person opens exactly its own panel
	var expect := {"spaceport": "Shipyard", "market": "Market", "cannery": "Lab", "office": "Office",
		"rusk": "Shipyard", "okka": "Deals", "sen": "Deals"}
	for id in expect:
		sf.place_player_at(id)
		await physics_frame
		await physics_frame
		_assert(not sf.focus.is_empty() and sf.focus.payload.id == id, "focus on %s (got %s)" % [id, sf.focus.get("payload", {})])
		_assert(m.hud._prompt.text.begins_with("[E]"), "HUD prompt for %s" % id)
		_assert(sf.interact(), "interact with %s" % id)
		await frames(2)
		_assert(m.station.visible and m.station.tab_names() == [expect[id]], "%s opens %s (got %s)" % [id, expect[id], m.station.tab_names()])
		_assert(sf.player.frozen, "player frozen while a panel is open")
		m.station.close_requested.emit()
		await frames(1)
		_assert(not m.station.visible, "panel closes")
	step("doors and people")

	gs.act(g.buy("cannabis", 5))
	gs.act(g.buy("nanoflux", 5))
	m.station._lab_adds = ["nanoflux", "", ""]
	m.station._lab_qty = 5
	m.station.refresh()
	gs.act(g.start_batch("weed", ["nanoflux"], 5))
	await frames(2)
	g.tick(30.0)
	gs.act(g.collect_stash())
	await frames(2)
	_assert(g.has_contraband(), "cooked product")
	sf.place_player_at("okka")
	await physics_frame
	await physics_frame
	sf.interact()
	await frames(2)
	_assert(m.station.visible and m.station._filter.get("contact", "") == "okka", "deals panel limited to Okka")
	gs.act(g.sell("weed:overclock+radiant", 3, "okka"))
	await frames(2)
	m.station.close()
	step("cook and sell")

	g.credits = 20000
	for u in ["cargo", "engine", "stealth", "lab"]:
		gs.act(g.buy_upgrade(u))
	g.add_heat(30)
	gs.act(g.bribe(10))
	gs.act(g.pay_debt(1000))
	await frames(2)
	step("shipyard and office")

	sf.place_player_at("pad")
	await physics_frame
	await physics_frame
	_assert(sf.interact(), "use the launch pad")
	await frames(2)
	_assert(m.surface == null and m.world.visible and m.world.active and not m.station.visible, "took off and flying")
	_assert(m.get_viewport().get_camera_2d() == m.world.camera, "ship camera is current again")
	_assert(not is_instance_valid(sf) or sf.is_queued_for_deletion(), "surface instance freed")
	for i in 120:
		m.world.ship.steer(1.0 / 60.0, true, false)
		await physics_frame
	var v_fwd: Vector2 = m.world.ship.velocity
	for i in 30:
		m.world.ship.steer(1.0 / 60.0, false, false, true)
	_assert(m.world.ship.velocity.length() < v_fwd.length(), "reverse thrust slows forward motion")
	for i in 60:
		m.world.ship.steer(1.0 / 60.0, false, true)
	_assert(m.world.ship.velocity.length() < 50.0, "brake stops the ship")
	step("flight")

	for loc in ["cinder", "bazaar"]:
		m.world.ship.position = m.world.locations[loc].position + Vector2(0, m.world.locations[loc].radius + 20)
		await physics_frame
		await physics_frame
		_assert(m.world.nearby == loc, "in dock range of %s" % loc)
		m.dock(loc)
		await frames(2)
		for i in m.station.tabs.get_tab_count():
			m.station.tabs.current_tab = i
			await frames(1)
		step("docked %s tabs %s" % [loc, m.station.tab_names()])
		m.undock()
		await frames(1)

	# patrol bust: park a patrol on top of the ship while carrying product
	g.cargo["weed:glow"] = 3
	g.add_heat(60)
	await physics_frame
	await physics_frame
	var p = m.world.patrols[0]
	var busts: int = g.stats.busts
	for i in 240:
		p.position = m.world.ship.position
		await physics_frame
		if g.stats.busts > busts:
			break
	_assert(g.stats.busts > busts, "patrol scan busts the player")
	step("bust")

	m.toggle_pause()
	await frames(2)
	_assert(gs.paused and m.pause_menu.visible, "paused")
	_assert(gs.save_game(), "save")
	m.show_main_menu()
	await frames(2)
	m.continue_game()
	await frames(3)
	_assert(gs.game.stats.busts == busts + 1, "continue loads the save")
	step("pause save load")

	gs.game.credits = 99999
	m.dock("mireth")
	gs.act(gs.game.pay_debt(99999))
	await frames(2)
	_assert(m.end_screen.visible, "win screen")
	step("win screen")
	m.start_new_game(5)
	gs.game.tick(gs.game.day_seconds() * (gs.game.debt_due_day + 1))
	await frames(2)
	_assert(m.end_screen.visible and gs.game.state == "lost", "lose screen")
	step("lose screen")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_save.json"))
	print("SMOKE DONE %d steps" % steps)
	quit(0)


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		printerr("SMOKE FAIL: " + msg)
		quit(1)
