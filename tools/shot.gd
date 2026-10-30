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
	g.add_heat(55)
	m.undock()
	for i in 90:
		m.world.ship.steer(1.0 / 60.0, true, false)
		await physics_frame
	await _save(out, "flight")
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
	quit()
