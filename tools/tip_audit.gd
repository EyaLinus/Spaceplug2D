extends SceneTree
## K1 tooltip audit: boots the game, opens the main screens (shops, estate stations, every phone app, menus) and lists
## visible buttons without hover help. Prints "TIPS MISSING <screen>: ..." per screen and "TIPS DONE <n>" at the end;
## exits 1 when any button lacks a tooltip, so CI keeps new screens honest.
## godot --headless --path . -s res://tools/tip_audit.gd

const Deals = preload("res://scripts/core/deals.gd")
const Walkups = preload("res://scripts/core/walkups.gd")

var UI  # loaded at runtime: ui_theme.gd uses autoloads, which a SceneTree script cannot see at compile time

var missing := 0


func _init() -> void:
	create_timer(90.0).timeout.connect(func():
		printerr("TIPS FAIL: timeout")
		quit(1))
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _audit(screen: String, node: Node) -> void:
	await _frames(2)
	var list: Array = UI.untipped(node)
	print("TIPS screen %s: %d buttons" % [screen, _count(node)])
	if not list.is_empty():
		missing += list.size()
		print("TIPS MISSING %s: %s" % [screen, ", ".join(PackedStringArray(list.map(func(x): return '"%s"' % x)))])


func _run() -> void:
	await process_frame
	UI = load("res://scripts/ui/ui_theme.gd")
	var gs = root.get_node("GameState")
	gs.save_prefix = "user://tips_save_"
	root.get_node("AudioManager").set_enabled(false)
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await _frames(3)
	await _audit("main menu", m.menu)
	m.start_new_game(5)
	var g = gs.game
	g.data.interdiction.min_day = 9999
	g.credits += 5000
	await _frames(3)
	var sf = m.surface
	for spot in ["market", "rusk"]:
		sf.place_player_at(spot)
		for i in 4:
			await physics_frame
		sf.interact()
		if spot == "market":  # D4: the door leads into the room; the counter opens the panel
			var room = m.surface
			room.place_player_at("counter")
			for i in 4:
				await physics_frame
			room.interact()
		await _audit("station " + spot, m.station)
		m.station.close()
		if spot == "market":
			m.surface.place_player_at("exit")
			for i in 4:
				await physics_frame
			m.surface.interact()
			sf = m.surface
	g.buy("cannabis", 5)
	g.buy("nanoflux", 5)
	sf.place_player_at("cannery")
	for i in 4:
		await physics_frame
	sf.interact()
	for i in 6:
		await physics_frame
	var cs = m.surface
	cs.place_player_at("b0")
	for i in 4:
		await physics_frame
	cs.interact()
	await _audit("bench start", m.bench)
	m.bench.close() if m.bench.has_method("close") else null
	m.open_build_menu()
	await _audit("build menu", m.station)
	m.station.close()
	m.leave_estate()
	await _frames(3)
	Deals.request(g, "okka")
	g.cargo["weed:glow"] = 6
	Walkups.active(g)["okka"] = Walkups.offer_for(g, "okka")
	m.walkup.open("okka")
	await _audit("customer on foot", m.walkup)
	m.walkup.close()
	Walkups.decline(g, "okka")
	g.cargo.erase("weed:glow")
	m.toggle_phone()
	await _audit("phone home", m.phone)
	for app in m.phone.apps:
		m.phone.open_app(app)
		await _audit("app " + str(app.id), m.phone)
	var o: Dictionary = Deals.request(g, "sen")
	if not o.is_empty():
		m.phone.open_app("deals")
		m.phone.push("deal", func(gg): return m.phone.app_by_id("deals").thread(gg, int(o.id)))
		await _audit("deal thread", m.phone)
	m.phone.open_app("contacts")
	m.phone.push("okka", func(gg): return m.phone.app_by_id("contacts").detail(gg, "okka"))
	await _audit("contact detail", m.phone)
	m.phone.close()
	m.toggle_pause()
	await _audit("pause", m.pause_menu)
	m.settings_panel.open()
	for t in m.settings_panel.tabs.get_tab_count():
		m.settings_panel.tabs.current_tab = t
		await _audit("settings tab %d" % t, m.settings_panel)
	print("TIPS DONE %d" % missing)
	quit(1 if missing > 0 else 0)


func _count(n: Node) -> int:
	var c := 0
	for ch in n.get_children():
		if ch is CanvasItem and not (ch as CanvasItem).visible:
			continue
		if ch is BaseButton:
			c += 1
		c += _count(ch)
	return c
