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
	gs.save_path = "user://shot_save.json"
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
	var ds: float = g.day_seconds()
	for hh in [[7.0, "surface_dawn"], [13.0, "surface_noon"], [19.0, "surface_dusk"], [23.5, "surface_night"]]:
		g.day_time = ds * (float(hh[0]) - 6.0) / 24.0
		await physics_frame
		await physics_frame
		sf.snap_npcs()
		sf.place_player_at("okka")
		sf.talk(sf.npcs.okka, sf.cfg.npcs[1])
		await _save(out, hh[1])
	g.day_time = 0.0
	await physics_frame
	await physics_frame
	sf.snap_npcs()
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
	quit()
