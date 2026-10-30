extends SceneTree
## Screenshot tool (needs a display, e.g. xvfb-run): boots the game and saves PNGs of the planet surface, panels and flight.
## xvfb-run -s "-screen 0 1280x720x24" godot --path . -s res://tools/shot.gd -- --out /tmp/shots

func _init() -> void:
	_run()


func _save(out: String, name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT %s" % name)


func _run() -> void:
	var out := "user://shots"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var gs = root.get_node("GameState")
	gs.save_prefix = "user://shot_save_"
	root.get_node("AudioManager").set_enabled(false)
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	for i in 5:
		await process_frame
	await _save(out, "menu")
	m.start_new_game(3)
	var g = gs.game
	var sf = m.surface
	for i in 20:
		await physics_frame
	await _save(out, "surface_pad")
	sf.place_player_at("okka")
	for i in 40:
		await physics_frame
	await _save(out, "surface_plaza")
	g.credits += 3000
	g.buy_upgrade("engine")
	g.buy_upgrade("cargo")
	g.buy_upgrade("cargo")
	sf.place_player_at("rusk")
	for i in 5:
		await physics_frame
	sf.interact()
	await _save(out, "shipyard")
	m.station.close()
	sf.place_player_at("market")
	for i in 5:
		await physics_frame
	sf.interact()
	await _save(out, "market")
	m.station.close()
	g.buy("cannabis", 5)
	g.buy("nanoflux", 5)
	g.buy("ion_syrup", 5)
	sf.place_player_at("cannery")
	for i in 30:
		await physics_frame
	await _save(out, "surface_cannery")
	sf.interact()
	m.station._lab_adds = ["nanoflux", "ion_syrup", ""]
	m.station.refresh()
	await _save(out, "lab")
	# one shot per station minigame, mid-play
	var runner = m.station.runner
	runner.autoplay = true
	runner.start("weed", ["nanoflux", "ion_syrup"], 5)
	var shot: Array = []
	for i in 4000:
		await process_frame
		if runner.current != null and runner.current.elapsed > 1.2 and not runner.plan[runner.index] in shot:
			shot.append(runner.plan[runner.index])
			await _save(out, "station_" + runner.plan[runner.index])
		if not runner.result.is_empty():
			await _save(out, "station_summary")
			break
	runner.abort()
	g.buy("cannabis", 5)
	runner.autoplay = false
	g.cargo["pseudo"] = 5
	g.cargo["nanoflux"] = int(g.cargo.get("nanoflux", 0)) + 5
	runner.start("meth", ["nanoflux"], 5)
	for i in 40:
		await process_frame
	await _save(out, "station_precursor_scale")
	runner.autoplay = true
	for i in 4000:
		await process_frame
		if runner.current != null and runner.plan[runner.index] == "refiner" and runner.current.elapsed > 3.0:
			await _save(out, "station_refiner")
			break
	runner.autoplay = false
	runner.abort()
	g.cargo.erase("pseudo")
	g.start_batch("weed", ["nanoflux"], 5)
	g.tick(30)
	g.collect_stash()
	m.station.close()
	sf.place_player_at("okka")
	for i in 5:
		await physics_frame
	sf.interact()
	await _save(out, "deals")
	m.station.close()
	var k: String = g.cargo.keys().filter(func(x): return x.contains(":"))[0]
	g.sell(k, 2, "okka")
	# estate interior with every lab station placed
	g.credits = 99999
	g.buy_estate("cannery_annex")
	for st in [["cook_stove", 0, 0], ["refiner", 2, 0], ["extractor", 4, 0], ["mixing_station", 6, 0], ["precursor_scale", 8, 0],
			["trim_table", 4, 2], ["pack_table", 6, 2]]:
		g.place_building("cannery_annex", st[0], st[1], st[2])
	m.enter_estate("cannery_annex")
	for i in 10:
		await physics_frame
	await _save(out, "estate")
	m.leave_estate()
	for i in 5:
		await physics_frame
	m.toggle_phone()
	await _save(out, "phone_home")
	m.phone.open_app("contacts")
	await _save(out, "phone_contacts")
	m.phone.push(g.contact("okka").name, func(gg): return m.phone.app_by_id("contacts").detail(gg, "okka"))
	await _save(out, "phone_profile")
	# HR app: crew list, a worker profile and an estate that is cooking
	const WorkersCore = preload("res://scripts/core/workers.gd")
	for wid in ["pia", "reva"]:
		WorkersCore.hire(g, wid)
		WorkersCore.assign(g, wid, "cannery_annex")
	WorkersCore.hire(g, "dax")
	WorkersCore.set_recipe(g, "cannery_annex", "weed", [], 5)
	g.inside_estate = "cannery_annex"
	g.cargo["cannabis"] = 10
	WorkersCore.deposit(g, "cannery_annex", "cannabis", 10)
	g.inside_estate = ""
	g.tick(14.0)
	m.phone.open_app("hr")
	await _save(out, "phone_hr")
	m.phone.push("Pia Vance", func(gg): return m.phone.app_by_id("hr").detail(gg, "pia"))
	await _save(out, "phone_hr_worker")
	m.phone.open_app("hr")
	m.phone.push("Cannery Annex", func(gg): return m.phone.app_by_id("hr").estate(gg, m.phone, "cannery_annex"))
	await _save(out, "phone_hr_estate")
	m.phone.close()
	g.add_heat(55)
	m.undock()
	for i in 90:
		m.world.ship.steer(1.0 / 60.0, true, false)
		await physics_frame
	await _save(out, "flight")
	# fully upgraded ship: every module visible, in flight and in the shipyard preview
	var before: Dictionary = g.upgrades.duplicate()
	for up_key in g.upgrades:
		g.upgrades[up_key] = g.data.upgrades[up_key].levels.size() - 1
	Input.action_press("ship_thrust")
	for i in 30:
		await physics_frame
	await _save(out, "flight_upgraded")
	Input.action_release("ship_thrust")
	g.upgrades = before
	for loc in m.world.locations:
		m.world.ship.position = m.world.locations[loc].position + Vector2(0, m.world.locations[loc].radius + 120)
		m.world.ship.stop()
		for c in m.world.ship.get_children():
			if c is Camera2D:
				c.reset_smoothing()
		for i in 10:
			await physics_frame
		await _save(out, "space_%s" % loc)
	for loc in ["cinder", "bazaar"]:
		m.world.ship.position = m.world.locations[loc].position + Vector2(0, m.world.locations[loc].radius + 20)
		await physics_frame
		await physics_frame
		m.dock(loc)
		for i in 30:
			await physics_frame
		await _save(out, "surface_%s" % loc)
		m.undock()
		for i in 5:
			await physics_frame
	# second system: jump through the gate, then the new planets from orbit and on foot
	m.dock("halvane_gate")
	for i in 20:
		await physics_frame
	for loc in m.world.locations:
		m.world.ship.position = m.world.locations[loc].position + Vector2(0, m.world.locations[loc].radius + 120)
		m.world.ship.stop()
		m.world.camera.reset_smoothing()
		for i in 10:
			await physics_frame
		await _save(out, "space_%s" % loc)
	for loc in ["varrow", "glacis"]:
		m.dock(loc)
		for i in 30:
			await physics_frame
		await _save(out, "surface_%s" % loc)
		m.surface.place_player_at(m.surface.cfg.npcs[0].id)
		for i in 30:
			await physics_frame
		await _save(out, "surface_%s_town" % loc)
		m.undock()
		for i in 5:
			await physics_frame
	quit()
