extends SceneTree
## Screenshot tool (needs a display, e.g. xvfb-run): boots the game and saves PNGs of the planet surface, panels and flight.
## xvfb-run -s "-screen 0 1280x720x24" godot --path . -s res://tools/shot.gd -- --out /tmp/shots

func _init() -> void:
	_run()


const Bench = preload("res://scripts/core/bench.gd")


## Walks to building `bid` of the estate surface `cs` and presses E there (opens the station overlay).
func _use(cs, bid: String) -> void:
	cs.place_player_at(bid)
	for i in 3:
		await physics_frame
	cs.interact()
	for i in 3:
		await process_frame


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
	m.station._basket = {"cannabis": 4, "nanoflux": 2}
	m.station.refresh()
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
	for i in 10:
		await physics_frame
	var cs = m.surface
	cs.place_player_at("b0")
	for i in 10:
		await physics_frame
	await _save(out, "estate_cannery")
	# production on foot: start overlay, ingredient shelf, one shot per station minigame mid-play
	var bench = m.bench
	await _use(cs, "b0")
	await _save(out, "lab")
	bench.autoplay = true
	bench._confirm()
	var order := {"trim_table": "b0", "extractor": "b2", "mixing_station": "b3", "cook_stove": "b4", "pack_table": "b6"}
	for st in order:
		if st != "trim_table":
			await _use(cs, order[st])
		if bench.mode == "mix":
			bench._adds = ["nanoflux", "ion_syrup"]
			bench._rebuild()
			await _save(out, "bench_mix")
			bench._confirm()
		for i in 4000:
			await process_frame
			if bench.current != null and bench.current.elapsed > 1.2:
				await _save(out, "station_" + st)
				break
		bench.autoplay = st != "pack_table"
		for i in 4000:
			await process_frame
			if bench.mode == "result" or not bench.visible:
				break
		if st == "pack_table":
			await _save(out, "station_summary")
		bench.autoplay = true
		bench.close()
	bench.autoplay = false
	g.cargo["pseudo"] = 5
	await _use(cs, "b1")
	bench._base = "meth"
	bench._rebuild()
	bench._confirm()
	for i in 40:
		await process_frame
	await _save(out, "station_precursor_scale")
	bench.autoplay = true
	for i in 4000:
		await process_frame
		if not bench.visible:
			break
	for st in [["cook_stove", "b4"], ["refiner", "b5"]]:
		await _use(cs, st[1])
		for i in 4000:
			await process_frame
			if st[0] == "refiner" and bench.current != null and bench.current.elapsed > 3.0:
				await _save(out, "station_refiner")
				break
			if not bench.visible:
				break
	bench.autoplay = false
	bench.close()
	Bench.abandon(g)
	cs.place_player_at("stash")
	for i in 5:
		await physics_frame
	cs.interact()
	await _save(out, "stash_crate")
	m.station.close()
	cs.place_player_at("exit")
	for i in 5:
		await physics_frame
	cs.interact()
	for i in 5:
		await physics_frame
	sf = m.surface
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
	m.open_build_menu()
	await _save(out, "build_menu")
	m.station.close()
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
	var Deals = load("res://scripts/core/deals.gd")
	var o1: Dictionary = Deals.request(g, "sen")
	var o2: Dictionary = Deals.request(g, "okka")
	Deals.accept(g, o2.id)
	Deals.request(g, "teo")
	m.phone.open_app("deals")
	await _save(out, "phone_deals")
	m.phone.push("Sen Varo", func(gg): return m.phone.app_by_id("deals").thread(gg, int(o1.id)))
	await _save(out, "phone_deal_thread")
	var Deaddrops = load("res://scripts/core/deaddrops.gd")
	g.credits = maxi(g.credits, 500)
	Deaddrops.request(g, "mireth")
	Deaddrops.request(g, "drift_bazaar")
	var okey: String = load("res://scripts/core/mixing.gd").key(o2.base, [g.data.bases[o2.base].innate])
	g.cargo[okey] = int(o2.qty)
	m.phone.open_app("deaddrop")
	await _save(out, "phone_deaddrop")
	m.phone.close()
	sf = m.surface  # the HR shots above rebuilt the surface
	sf.place_player_at("okka")
	for i in 5:
		await physics_frame
	await _save(out, "deal_marker")
	var day0: float = g.day_time
	g.day_time = g.day_seconds() * 16.0 / 24.0  # 22:00
	for i in 60:
		await physics_frame
	sf.place_player_at("okka")
	for i in 5:
		await physics_frame
	await _save(out, "surface_night")
	g.day_time = day0
	g.add_heat(55)
	m.undock()
	for i in 90:
		m.world.ship.steer(1.0 / 60.0, true, false)
		await physics_frame
	await _save(out, "flight")
	# galaxy map app: heat overlay with a planned route, price overlay, price comparison, charging, hyperspace
	m.toggle_phone()
	m.phone.open_app("map")
	m.phone.find_child("MapSys_kovar", true, false).pressed.emit()
	for i in 4:
		await physics_frame
	await _save(out, "phone_map_heat")
	m.phone.find_child("MapMode_price", true, false).pressed.emit()
	for i in 4:
		await physics_frame
	await _save(out, "phone_map_price")
	m.phone.push("Prices", func(gg): return m.phone.app_by_id("map")._prices(gg))
	for i in 4:
		await physics_frame
	await _save(out, "phone_map_prices")
	m.phone.home()
	m.phone.open_app("map")
	m.phone.find_child("MapMode_heat", true, false).pressed.emit()
	m.phone.find_child("MapJump", true, false).pressed.emit()
	g.tick(g.jump_plan.need * 0.6)
	for i in 6:
		await physics_frame
	await _save(out, "jump_charging")
	m.phone.close()
	g.tick(30.0)
	for i in 4:
		await physics_frame
	await _save(out, "jump_hyperspace")
	await create_timer(2.5).timeout
	await _save(out, "jump_arrived")
	m.phone.close()
	m.hyper.burst = 0.0
	m.dock("kovar_gate")
	await create_timer(2.5).timeout
	# fully upgraded ship: every module visible, in flight and in the shipyard preview
	var before: Dictionary = g.upgrades.duplicate()
	for up_key in g.upgrades:
		g.upgrades[up_key] = g.data.upgrades[up_key].levels.size() - 1
	Input.action_press("ship_thrust")
	for i in 30:
		await physics_frame
	await _save(out, "flight_upgraded")
	Input.action_release("ship_thrust")
	# space combat: pirates around a fully armed ship, bolts and a missile in the air, shield ring flashing
	var w = m.world
	w.clear_patrols()
	w.ship.position = Vector2(-3000, 3000)
	w.ship.rotation = 0.0
	w.ship.stop()
	w.camera.reset_smoothing()
	g.heat = 0.0
	g.combat.shield = 140.0
	g.combat.missiles = 14
	g.combat.hull = 150.0
	for off in [Vector2(-120, -330), Vector2(200, -240), Vector2(0, -520)]:
		var pr = w.combat.spawn_pirate(g, w.ship.position + off)
		pr.velocity = Vector2.ZERO
	for i in 6:
		w.combat.fire_laser(g)
		await physics_frame
		await physics_frame
		await physics_frame
		await physics_frame
		await physics_frame
		await physics_frame
		await physics_frame
		await physics_frame
		await physics_frame
		await physics_frame
	w.combat.fire_missile(g)
	w.combat.hurt_player(g, 20.0)
	for i in 4:
		await physics_frame
	await _save(out, "space_combat")
	w.combat.clear()
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
