extends SceneTree
## UI smoke test: boots the real main scene headless, lands on Mireth and walks the planet surface (collision,
## every door and person, take-off), plays the core loop through the UI layer
## (buy, cook, hand-made batch through every station minigame, sell, upgrade, bribe, pay), flies between locations, triggers a patrol bust,
## pauses, saves/loads and reaches both end screens. Any GDScript error shows up as "SCRIPT ERROR" (CI greps for it).
## godot --headless --path . -s res://tools/ui_smoke.gd

const Galaxy = preload("res://scripts/core/galaxy.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Interdiction = preload("res://scripts/core/interdiction.gd")

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


func key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
	await process_frame


func pframes(n: int) -> void:
	for i in n:
		await physics_frame


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.save_prefix = "user://smoke_save_"
	gs.slot = 1
	root.get_node("AudioManager").set_enabled(false)
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await frames(3)
	step("main menu")

	m.start_new_game(99)
	await frames(3)
	var g = gs.game
	g.interdict_ready_at = 1e12  # no random interdictions in the older sections; _interdiction() switches them on
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

	# Com-Phone: Tab opens it on foot, Contacts lists the people met so far, Esc steps back and closes it
	_assert(g.people.okka.known and not g.people.teo.known, "teo not met yet")
	sf.place_player_at("teo")
	await physics_frame
	await physics_frame
	_assert(sf.interact(), "talk to teo")
	await frames(2)
	_assert(g.people.teo.known, "talking to teo adds the contact")
	m.station.close_requested.emit()
	await frames(1)
	await key(KEY_TAB)
	_assert(m.phone.visible and m.phone.current_title() == "", "Tab opens the phone on its home screen")
	_assert(sf.player.frozen, "player frozen while the phone is open")
	var tile: Button = m.phone.find_child("App_contacts", true, false)
	_assert(tile != null, "contacts app tile")
	tile.pressed.emit()
	await frames(2)
	_assert(m.phone.current_title() == "Contacts", "contacts app opens")
	_assert(m.phone.find_child("Contact_teo", true, false) != null and m.phone.find_child("Contact_okka", true, false) != null, "met people listed")
	_assert(m.phone.find_child("Contact_marta", true, false) == null, "unmet people hidden")
	var row: Button = m.phone.find_child("Contact_okka", true, false)
	row.pressed.emit()
	await frames(2)
	_assert(m.phone.current_title() == g.contact("okka").name, "profile opens")
	g.tick(0.1)  # a game event while open rebuilds the screen without errors
	g.add_heat(0.0)
	await frames(2)
	await key(KEY_ESCAPE)
	_assert(m.phone.visible and m.phone.current_title() == "Contacts", "Esc steps back to the list")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	_assert(not m.phone.visible and not gs.paused, "Esc from home closes the phone without pausing")
	step("com-phone contacts")

	# Deal-O-Matic: a text arrives, accept it in the phone, hand it over in person
	var Deals = load("res://scripts/core/deals.gd")
	g.contact_ready_at.erase("okka")
	var offer: Dictionary = Deals.request(g, "okka")
	_assert(not offer.is_empty(), "okka texts a request")
	var deal_key: String = Deals.Mixing.key(offer.base, [g.data.bases[offer.base].innate])
	g.cargo[deal_key] = int(g.cargo.get(deal_key, 0)) + int(offer.qty)
	await key(KEY_TAB)
	var dtile: Button = m.phone.find_child("App_deals", true, false)
	_assert(dtile != null, "deals app tile")
	dtile.pressed.emit()
	await frames(2)
	var orow: Button = m.phone.find_child("Offer_%d" % int(offer.id), true, false)
	_assert(orow != null, "request listed in Deal-O-Matic")
	orow.pressed.emit()
	await frames(2)
	var acc: Button = m.phone.find_child("Accept", true, false)
	_assert(acc != null, "accept button")
	acc.pressed.emit()
	await frames(2)
	_assert(offer.state == "accepted", "request accepted from the phone")
	_assert(m.phone.find_child("Cancel", true, false) != null, "thread shows the agreed deal")
	await key(KEY_TAB)
	_assert(not m.phone.visible, "Tab closes the phone")
	await frames(2)
	_assert(sf.npcs.okka.marker, "okka carries the deal marker")
	sf.place_player_at("okka")
	await physics_frame
	await physics_frame
	_assert(sf.interact(), "talk to okka")
	await frames(2)
	var hand: Button = m.station.find_child("HandOver", true, false)
	_assert(hand != null, "hand-over button in okka's deals panel")
	var deal_credits_before: int = g.credits
	hand.pressed.emit()
	await frames(2)
	_assert(offer.state == "done" and g.credits == deal_credits_before + int(offer.price) * int(offer.qty), "deal handed over and paid")
	m.station.close_requested.emit()
	await frames(2)
	_assert(not sf.npcs.okka.marker, "marker gone after the deal")
	step("deal-o-matic")

	# NPC schedules: when the hour moves Okka to her next place she walks there; the light follows the clock
	var People = load("res://scripts/core/people.gd")
	sf.place_player_at("pad")
	var okka_cfg: Dictionary = g.contact("okka")
	var place0: String = People.whereabouts(okka_cfg, People.hour(g)).place
	var light0: Color = sf._daylight.color
	var guard_h := 0
	while People.whereabouts(okka_cfg, People.hour(g)).place == place0 and guard_h < 48:
		g.tick(g.day_seconds() / 48.0)
		guard_h += 1
	await frames(40)
	var target_px: Vector2 = sf._px(sf._spot_of.okka)
	_assert(People.whereabouts(okka_cfg, People.hour(g)).place != place0, "okka's schedule moves on")
	_assert(not sf.npcs.okka.path.is_empty() or sf.npcs.okka.position.distance_to(target_px) < 4.0, "okka walks to her next place")
	_assert(sf.interactable("okka").pos == sf.npcs.okka.position, "okka's interaction point follows her")
	_assert(sf._daylight.color != light0, "daylight changes with the hour")
	step("npc schedules")

	# Market & Orders: order from the phone, goods arrive after the delivery time, cancel refunds
	var credits_start: int = g.credits
	g.credits = maxi(g.credits, 500)
	await key(KEY_TAB)
	var otile: Button = m.phone.find_child("App_orders", true, false)
	_assert(otile != null, "orders app tile")
	otile.pressed.emit()
	await frames(2)
	_assert(m.phone.current_title() == "Orders", "orders app opens")
	var plus: Button = m.phone.find_child("OrderPlus_cannabis", true, false)
	plus.pressed.emit()
	await frames(2)
	var stash_before: int = int(g.stash.get("cannabis", 0))
	var credits_before: int = g.credits
	var obtn: Button = m.phone.find_child("Order_cannabis", true, false)
	_assert(obtn != null and not obtn.disabled, "order button enabled")
	obtn.pressed.emit()
	await frames(2)
	_assert(g.orders.size() == 1 and g.credits < credits_before, "order placed and paid")
	_assert(m.phone.find_child("Transit_%d" % int(g.orders[0].id), true, false) != null, "order listed in transit")
	g.tick(100.0)
	await frames(2)
	_assert(g.orders.is_empty() and int(g.stash.get("cannabis", 0)) == stash_before + 6, "delivery lands in the stash")
	obtn = m.phone.find_child("Order_nanoflux", true, false)
	obtn.pressed.emit()
	await frames(2)
	_assert(g.orders.size() == 1, "second order placed")
	var cbtn: Button = m.phone.find_child("OrderCancel_%d" % int(g.orders[0].id), true, false)
	cbtn.pressed.emit()
	await frames(2)
	_assert(g.orders.is_empty(), "order cancelled")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	_assert(not m.phone.visible, "phone closes")
	g.credits = credits_start
	g.stash.erase("cannabis")
	step("com-phone orders")

	# DeadDrop: request a drop, leave an agreed deal in it, the customer collects and pays
	var Deals2 = load("res://scripts/core/deals.gd")
	var Mixing2 = load("res://scripts/core/mixing.gd")
	g.data.deaddrops.theft_chance = 0.0
	g.data.deaddrops.theft_heat = 0.0
	g.credits = maxi(g.credits, 500)
	await key(KEY_TAB)
	var ddtile: Button = m.phone.find_child("App_deaddrop", true, false)
	_assert(ddtile != null, "deaddrop app tile")
	ddtile.pressed.emit()
	await frames(2)
	_assert(m.phone.current_title() == "DeadDrop", "deaddrop app opens")
	var dropreq: Button = m.phone.find_child("DropRequest_mireth", true, false)
	_assert(dropreq != null and not dropreq.disabled, "drop request button")
	dropreq.pressed.emit()
	await frames(2)
	_assert(g.drops.size() == 1, "drop requested")
	var doffer: Dictionary = Deals2.request(g, "okka")
	Deals2.accept(g, doffer.id)
	var dkey: String = Mixing2.key(doffer.base, [g.data.bases[doffer.base].innate])
	g.cargo[dkey] = int(doffer.qty)
	await frames(3)
	var ddeal: Button = m.phone.find_child("DropDeal_%d" % int(doffer.id), true, false)
	_assert(ddeal != null and not ddeal.disabled, "drop-off button for the deal")
	var dcredits: int = g.credits
	ddeal.pressed.emit()
	await frames(2)
	_assert(doffer.state == "dropped", "goods left in the drop")
	g.tick(40.0)
	await frames(2)
	_assert(doffer.state == "done" and g.credits >= dcredits + int(doffer.price) * int(doffer.qty), "customer collected and paid")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	_assert(not m.phone.visible, "phone closes after deaddrop")
	g.drops.clear()
	g.credits = credits_start
	step("com-phone deaddrop")

	# police on foot: an officer looking at you while you carry product frisks and busts you
	_assert(sf.officers.size() == g.police_on_foot(1.0) and sf.officers.size() > 0, "officers on Mireth")
	var cop = sf.officers[0]
	cop.pick_next = Callable()
	cop.path = []
	cop.position = sf.player.position + Vector2(70, 0)
	cop.facing = Vector2.LEFT
	g.cargo["weed:glow"] = 2
	var busts_before: int = g.stats.busts
	for i in 240:
		cop.position = sf.player.position + Vector2(70, 0)
		await physics_frame
		if g.stats.busts > busts_before:
			break
	_assert(g.stats.busts > busts_before and not g.has_contraband(), "officer frisk busts the player on foot")
	cop.pick_next = sf._walker_path
	step("police on foot")

	# a chasing officer walks around the hangar instead of through it
	var hang: Rect2 = sf._rect(sf.cfg.buildings[0].rect)
	g.cargo["weed:glow"] = 1
	g.heat = 45.0  # chasing, but below the heat where officers draw their weapons (combat.officer.draw_heat)
	sf.player.position = Vector2(hang.get_center().x, hang.end.y + 24.0)
	cop.position = Vector2(hang.get_center().x, hang.position.y - 20.0)
	cop.chasing = true
	cop.speed = float(gs.data.police.chase_speed)
	cop.path = []
	var inside := false
	var start_d: float = cop.position.distance_to(sf.player.position)
	for i in 300:
		await physics_frame
		if hang.grow(-2).has_point(cop.position):
			inside = true
		if cop.position.distance_to(sf.player.position) < 40.0:
			break
	_assert(not inside, "chasing officer stays out of buildings")
	_assert(cop.position.distance_to(sf.player.position) < start_d * 0.5, "chasing officer closes in around the building")
	g.cargo.erase("weed:glow")
	g.heat = 0.0
	cop.chasing = false
	cop.speed = float(gs.data.police.speed)
	cop.path = []
	step("police pathfinding")

	# ground combat: aim, fire, cover, armed officers, knock-out, weapon wheel
	sf.use_mouse = false
	for o in sf.officers:
		o.pick_next = Callable()
		o.path = []
		o.chasing = false
	_assert(sf.covers.size() >= 3 and sf._bullet_blockers.size() >= sf.covers.size() + sf.cfg.buildings.size(), "Mireth has cover pieces that stop bullets")
	var cop2 = sf.officers[0]
	var hp0: float = cop2.hp
	g.heat = 0.0
	g.credits = 5000
	g.hp = Combat.max_hp(g)
	var cv: Rect2 = sf.covers[0]
	var ctr := cv.get_center()
	var side := Vector2(130, 0) if cv.size.x >= cv.size.y else Vector2(0, 130)
	sf.player.position = ctr - side
	cop2.position = ctr + side
	sf.aim_point = cop2.position
	g.cooldown = 0.0
	_assert(sf.shoot(), "pistol shot leaves the muzzle")
	await pframes(40)
	_assert(cop2.hp == hp0 and sf.bullets.is_empty(), "cover stops the bullet (officer hp %.0f/%.0f)" % [cop2.hp, hp0])
	_assert(not cop2.provoked, "an officer behind cover is not provoked")
	sf.player.position = ctr - side + side.orthogonal().normalized() * 70.0
	cop2.position = ctr + side + side.orthogonal().normalized() * 70.0
	sf.aim_point = cop2.position
	g.cooldown = 0.0
	var ammo0: int = g.ammo.pistol
	_assert(sf.shoot() and g.ammo.pistol == ammo0 - 1, "a shot costs a round")
	await pframes(40)
	_assert(cop2.hp < hp0 and cop2.provoked, "a clear shot hurts the officer and provokes him (hp %.0f)" % cop2.hp)
	_assert(g.heat >= float(gs.data.combat.officer.hit_heat), "shooting an officer raises heat")
	# real mouse button + reload key through the input system
	g.cooldown = 0.0
	g.reload_left = 0.0
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	Input.parse_input_event(mb)
	await pframes(2)
	mb = InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = false
	Input.parse_input_event(mb)
	await pframes(2)
	_assert(g.ammo.pistol <= ammo0 - 2, "left mouse button fires (ammo %d)" % g.ammo.pistol)
	await key(KEY_R)
	_assert(g.reload_left > 0.0, "R starts a reload")
	await pframes(90)
	_assert(g.ammo.pistol == 12 and g.reload_left == 0.0, "reload finishes")
	# armed officer shoots back; knock-out wakes the player at the pad
	g.heat = 70.0
	cop2.hp = cop2.max_hp
	cop2.provoked = false
	sf.player.position = Vector2(14 * 32, 16.5 * 32)
	cop2.position = sf.player.position + Vector2(160, 0)
	cop2.facing = Vector2.LEFT
	cop2.fire_cd = 0.0
	var hp1: float = g.hp
	for i in 240:
		cop2.position = sf.player.position + Vector2(160, 0)
		await physics_frame
		if g.hp < hp1:
			break
	_assert(cop2.armed and g.hp < hp1, "an officer draws and shoots at high heat (hp %.0f)" % g.hp)
	g.cargo["weed:glow"] = 3
	g.hp = 1.0
	var ko0: int = g.stats.knockouts
	var credits0: int = g.credits
	for i in 300:
		cop2.position = sf.player.position + Vector2(160, 0) if g.stats.knockouts == ko0 else Vector2(40 * 32, 5 * 32)
		await physics_frame
		if g.stats.knockouts > ko0:
			break
	_assert(g.stats.knockouts == ko0 + 1 and g.credits < credits0 and not g.has_contraband(), "knocked out: fined, product gone")
	_assert(g.hp == Combat.max_hp(g) * float(gs.data.combat.player.ko_hp_ratio), "wakes up half healthy")
	_assert(sf.player.position.distance_to(sf.interactable("pad").stand) < 1.0, "wakes up at the launch pad")
	# officer kill
	for o in sf.officers:
		o.position = Vector2(40 * 32, 5 * 32)
		o.hold = true
	g.heat = 0.0
	cop2 = sf.officers[0]
	cop2.hp = 5.0
	cop2.provoked = false
	var kills0: int = g.stats.kills
	sf.player.position = Vector2(14 * 32, 16.5 * 32)
	cop2.position = sf.player.position + Vector2(100, 0)
	sf.aim_point = cop2.position
	g.cooldown = 0.0
	sf.shoot()
	await pframes(20)
	_assert(g.stats.kills == kills0 + 1 and not sf.officers.has(cop2), "an officer can be shot down")
	# weapon wheel: buy and equip the smg
	g.credits = 5000
	sf.open_wheel()
	_assert(sf.wheel_open, "weapon wheel opens")
	sf.wheel_sel = 1
	sf.close_wheel(true)
	_assert(not sf.wheel_open and g.weapon == "smg" and g.weapons.has("smg") and g.credits == 5000 - int(gs.data.combat.weapons.smg.price), "wheel buys and equips the smg")
	await key(KEY_1)
	_assert(g.weapon == "pistol", "key 1 equips the pistol")
	g.hp = Combat.max_hp(g)
	g.heat = 0.0
	g.cargo.erase("weed:glow")
	sf.bullets.clear()
	for o in sf.officers:
		o.hold = false
		o.pick_next = sf._walker_path
	sf.use_mouse = true
	step("ground combat")

	# estates: buy the Cannery Annex, go inside, place a station, open it, leave
	g.credits = 99999
	sf.place_player_at("annex")
	await physics_frame
	await physics_frame
	_assert(sf.interact(), "use the annex door")
	await frames(2)
	_assert(m.station.visible and m.station.tab_names() == ["Estate"], "annex door opens the estate panel")
	gs.act(g.buy_estate("cannery_annex"))
	m.station.estate_enter_requested.emit("cannery_annex")
	await frames(2)
	var es = m.surface
	_assert(es != null and es.cfg.get("estate", "") == "cannery_annex" and not m.station.visible, "inside the annex")
	m.open_build_menu()
	await frames(1)
	_assert(m.station.tab_names() == ["Build"], "build menu")
	m.station.place_requested.emit("cook_stove")
	await frames(1)
	_assert(es.placing == "cook_stove" and not m.station.visible, "placing mode")
	es.player.position = Vector2(2 * 32 + 16, 2 * 32 + 10)
	es.player.facing = Vector2.DOWN
	await physics_frame
	_assert(es.can_place.call("cook_stove", es.ghost_cell().x, es.ghost_cell().y), "ghost on free cells (%s)" % [es.ghost_cell()])
	es.interact()
	await frames(2)
	_assert(g.estates.cannery_annex.buildings.size() == 1, "station placed")
	es = m.surface
	_assert(es.cfg.buildings.any(func(b): return b.get("station", "") == "cook_stove"), "room rebuilt with the stove")
	es.place_player_at("b0")
	await physics_frame
	await physics_frame
	_assert(es.interact(), "use the placed stove")
	await frames(2)
	_assert(m.station.tab_names() == ["Lab", "Station"], "placed station opens lab + station (got %s)" % [m.station.tab_names()])
	_assert(g.inside_estate == "cannery_annex" and g.lab_here(), "the estate counts as a lab")
	m.station.close()
	es.place_player_at("exit")
	await physics_frame
	await physics_frame
	_assert(es.interact(), "leave the annex")
	await frames(2)
	sf = m.surface
	_assert(g.inside_estate == "", "left the estate")
	_assert(sf.loc_id == "mireth" and sf.player.position.distance_to(sf.interactable("annex").stand) < 1.0, "back on Mireth at the annex door")
	step("estate buy, build, leave")

	# ship cargo bay: ramp next to the pad, build a station, cook flag, leave back onto the pad
	sf.place_player_at("ship_bay")
	await physics_frame
	await physics_frame
	_assert(sf.interact(), "use the cargo bay ramp")
	await frames(2)
	es = m.surface
	_assert(es != null and es.cfg.get("estate", "") == "ship_bay" and g.inside_estate == "ship_bay", "inside the cargo bay")
	m.station.place_requested.emit("trim_table")
	await frames(1)
	es.player.position = Vector2(2 * 32 + 16, 2 * 32 + 10)
	es.player.facing = Vector2.DOWN
	await physics_frame
	es.interact()
	await frames(2)
	_assert(g.estates.ship_bay.buildings.size() == 1, "station placed in the bay")
	es = m.surface
	es.place_player_at("exit")
	await physics_frame
	await physics_frame
	_assert(es.interact(), "leave the cargo bay")
	await frames(2)
	sf = m.surface
	_assert(g.inside_estate == "" and sf.loc_id == "mireth", "back on Mireth from the bay")
	step("cargo bay enter, build, leave")

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
	step("quick batch")

	# hand-made batch: every station minigame through the real lab panel, played by the minigame bots
	sf.place_player_at("cannery")
	await physics_frame
	await physics_frame
	sf.interact()
	await frames(2)
	gs.act(g.buy("cannabis", 5))
	gs.act(g.buy("nanoflux", 5))
	var runner = m.station.runner
	runner.autoplay = true
	Engine.time_scale = 6.0
	_assert(runner.start("weed", ["nanoflux"], 5).ok, "hand batch starts")
	_assert(runner.plan == ["trim_table", "extractor", "mixing_station", "cook_stove", "pack_table"], "weed stations %s" % [runner.plan])
	var seen: Array = []
	for i in 3000:
		await process_frame
		if runner.current != null and not runner.plan[runner.index] in seen:
			seen.append(runner.plan[runner.index])
		if not runner.visible:
			break
	Engine.time_scale = 1.0
	_assert(seen == runner.plan, "every station minigame ran: %s" % [seen])
	_assert(runner.scores.size() == 5 and not runner.visible, "hand batch finished: %s" % [runner.scores])
	_assert(g.lab_queue.size() == 1 and g.lab_queue[0].product.begins_with("weed:overclock+radiant"), "hand batch queued: %s" % [g.lab_queue])
	_assert(m.station.visible, "lab panel still open after the minigames")
	step("hand batch %s -> %s" % [runner.scores, g.lab_queue[0]])
	# Esc during a minigame skips the rest (neutral scores) and must not close the lab panel
	gs.act(g.buy("cannabis", 2))
	runner.autoplay = false
	_assert(runner.start("weed", [], 2).ok, "second hand batch starts")
	await frames(2)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	m.get_viewport().push_input(esc)
	await frames(2)
	_assert(m.station.visible and runner.visible and not runner.result.is_empty(), "Esc skips to the summary, panel stays")
	_assert(g.lab_queue.size() == 2 and g.lab_queue[1].qty == 2, "skipped batch is standard: %s" % [g.lab_queue])
	m.get_viewport().push_input(esc)
	await frames(2)
	_assert(not runner.visible and m.station.visible, "second Esc closes the summary only")
	g.tick(60.0)
	gs.act(g.collect_stash())
	m.station.close()
	await frames(1)
	step("minigame skip")

	sf.place_player_at("okka")
	await physics_frame
	await physics_frame
	sf.interact()
	await frames(2)
	_assert(m.station.visible and m.station._filter.get("contact", "") == "okka", "deals panel limited to Okka (focus %s, filter %s, okka at %s, player %s)" % [sf.focus.get("payload", {}), m.station._filter, sf.npcs.okka.position, sf.player.position])
	gs.act(g.sell("weed:overclock+radiant", 3, "okka"))
	await frames(2)
	m.station.close()
	step("cook and sell")

	g.credits = 20000
	for u in ["cargo", "engine", "stealth", "lab", "laser", "missile", "shield", "hull"]:
		gs.act(g.buy_upgrade(u))
	_assert(g.upgrades.laser == 1 and g.upgrades.missile == 1 and g.upgrades.shield == 1 and g.upgrades.hull == 1, "weapon and shield modules bought at the mechanic")
	_assert(g.combat.missiles == 4 and g.combat.shield == 40.0 and g.combat.hull == 130.0, "new modules arrive charged")
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

	for loc in ["cinder", "bazaar", "halvane_gate", "varrow", "glacis", "kovar_gate"]:
		if g.data.locations[loc].has("jump_to"):
			await _jump(m, g, loc)
			continue
		m.world.ship.position = m.world.locations[loc].position + Vector2(0, m.world.locations[loc].radius + 20)
		await physics_frame
		await physics_frame
		_assert(m.world.nearby == loc, "in dock range of %s" % loc)
		m.dock(loc)
		await frames(2)
		var ls = m.surface
		_assert(ls != null and ls.loc_id == loc, "landed on %s" % loc)
		var opened: Array = []
		for it in ls.interactables:
			if it.action == "takeoff" or it.action == "enter_ship_bay":
				continue
			ls.place_player_at(it.payload.id)
			await physics_frame
			await physics_frame
			_assert(ls.interact(), "interact with %s/%s" % [loc, it.payload.id])
			await frames(2)
			_assert(m.station.visible and m.station.tab_names().size() == 1, "%s/%s opens one panel" % [loc, it.payload.id])
			if it.action == "fence":
				_assert(m.station._filter.get("fence_only", false), "fence door opens fence-only deals")
			opened.append("%s:%s" % [it.payload.id, m.station.tab_names()[0]])
			m.station.close_requested.emit()
			await frames(1)
		step("walked %s %s" % [loc, opened])
		ls.place_player_at("pad")
		await physics_frame
		await physics_frame
		_assert(ls.interact() and m.surface == null and m.world.active, "took off from %s" % loc)
		await frames(1)

	# Galaxy map app + jump drive: plan a route, charge, jump with the hyperspace transition, cancel, come back
	await _map_and_drive(m, g)

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

	await _space_combat(m, g)
	step("space combat")

	await _interdiction(m, g)
	step("jump interdiction")

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

	for i in range(1, gs.SLOTS + 1):
		gs.delete_slot(i)
	print("SMOKE DONE %d steps" % steps)
	quit(0)


## Com-Phone Map app: overlays, route planning, price comparison and the jump drive charge -> hyperspace -> arrival.
func _map_and_drive(m, g) -> void:
	g.credits = 5000
	g.heat = 50.0
	_assert(g.location == "" and g.system == "halvane" and m.world.active, "flying in Halvane before the map test")
	m.toggle_phone()
	m.phone.open_app("map")
	await frames(3)
	_assert(m.phone.current_title() == "Map", "map app opens")
	for n in ["MapCanvas", "MapSys_halvane", "MapSys_kovar", "MapSystem", "MapDrive", "MapPrices", "MapHeatBar"]:
		_assert(m.phone.find_child(n, true, false) != null, "map shows " + n)
	_assert(m.phone.find_child("MapLoc_mireth", true, false) != null, "selected system lists its locations")
	_assert(m.phone.find_child("MapJump", true, false) == null, "no jump button for the system you are in")
	m.phone.find_child("MapMode_price", true, false).pressed.emit()
	await frames(3)
	_assert(m.phone.find_child("MapHeatBar", true, false) != null, "price overlay keeps the system panel")
	m.phone.find_child("MapMode_heat", true, false).pressed.emit()
	m.phone.find_child("MapSys_kovar", true, false).pressed.emit()
	await frames(3)
	_assert(m.phone.find_child("MapLoc_varrow", true, false) != null and m.phone.find_child("MapLoc_mireth", true, false) == null, "Kovar locations shown")
	_assert(m.phone.find_child("MapRoute", true, false).text.contains("Kovar Expanse"), "route planned to Kovar")
	_assert(m.phone.find_child("MapCost", true, false).text.contains("80 cr"), "tolls shown")
	step("map app overlays and route")
	# price comparison screen
	m.phone.find_child("MapPrices", true, false).pressed.emit()
	await frames(3)
	_assert(m.phone.current_title() == "Prices" and m.phone.find_child("Price_cannabis", true, false) != null, "price comparison lists raws")
	m.phone.find_child("MapTab_sell", true, false).pressed.emit()
	await frames(3)
	_assert(m.phone.find_child("Price_cocaine", true, false) != null, "price comparison lists product demand")
	m.phone.back()
	await frames(3)
	step("map price comparison")
	# charge the drive from the phone
	var credits: int = g.credits
	m.phone.find_child("MapJump", true, false).pressed.emit()
	await frames(3)
	_assert(Galaxy.charging(g) and m.phone.find_child("MapCharge", true, false) != null and m.phone.find_child("MapCancel", true, false) != null, "drive charging, bar and cancel button shown")
	m.phone.find_child("MapCancel", true, false).pressed.emit()
	await frames(3)
	_assert(g.jump_plan.is_empty() and m.phone.find_child("MapJump", true, false) != null, "cancel from the phone")
	m.phone.find_child("MapJump", true, false).pressed.emit()
	await frames(2)
	g.tick(Galaxy.charge_seconds(g) * 0.5)
	await frames(2)
	_assert(m.hyper.charge > 0.3 and m.hyper.visible, "charge streaks shown while charging")
	g.tick(30.0)
	await frames(3)
	_assert(g.system == "kovar" and m.world.system == "kovar" and g.credits == credits - int(g.data.jump.fee), "drive jumped to Kovar and paid the toll")
	_assert(m.hyper.burst > 0.0 and m.hyper.card.contains("Kovar Expanse"), "hyperspace transition plays")
	_assert(g.jump_plan.is_empty() and m.world.active, "plan done, flying")
	step("jump drive to kovar")
	await create_timer(2.0).timeout  # real time: the tween fades over ~1.5 s
	_assert(m.hyper.burst < 0.5 or not m.hyper.visible, "transition fades out")
	# back home; docking would cancel, so just check that and return
	m.phone.find_child("MapSys_halvane", true, false).pressed.emit()
	await frames(3)
	m.phone.find_child("MapJump", true, false).pressed.emit()
	g.tick(30.0)
	await frames(3)
	_assert(g.system == "halvane" and m.world.system == "halvane", "drive jumped home")
	m.phone.close()
	m.hyper.burst = 0.0
	step("jump drive home")


## Flies into a jump gate and checks that the next system is built around the ship.
func _jump(m, g, gate: String) -> void:
	var to: String = g.data.locations[gate].jump_to
	m.world.ship.position = m.world.locations[gate].position + Vector2(0, m.world.locations[gate].radius + 20)
	await physics_frame
	await physics_frame
	_assert(m.world.nearby == gate, "in range of %s" % gate)
	_assert(m.hud._prompt.text.contains("Jump"), "HUD offers the jump")
	var credits: int = g.credits
	m.dock(gate)
	await frames(2)
	_assert(g.system == to and m.world.system == to and g.location == "", "jumped to %s" % to)
	_assert(g.credits < credits, "jump toll paid")
	_assert(m.world.locations.keys().all(func(l): return g.loc_system(l) == to), "only %s locations are shown" % to)
	_assert(m.world.active and m.surface == null, "flying after the jump")
	step("jump to %s" % to)


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		printerr("SMOKE FAIL: " + msg)
		quit(1)


## Pirates in deep space: auto spawn, lasers, missile, bounty, shield and hull damage, the dodge boost, the wreck.
func _space_combat(m, g) -> void:
	var w = m.world
	var cb = w.combat
	_assert(w.ship.modules.laser == g.upgrades.laser and w.ship.modules.shield == 1, "ship art follows the combat modules")
	g.heat = 0.0
	w.clear_patrols()
	for pos in [Vector2(-3000, 3000), Vector2(3000, 3000), Vector2(3000, -3000), Vector2(-3000, -3000), Vector2.ZERO]:
		w.ship.position = pos
		if w.nearest_location_distance() > 1200.0:
			break
	_assert(w.nearest_location_distance() > float(g.data.space_combat.spawn.safe_radius), "test position is deep space")
	w.ship.rotation = 0.0
	w.ship.stop()
	g.combat.hull = g.data.upgrades.hull.levels[g.upgrades.hull]
	# a pirate shows up on its own after the spawn interval, and not near a planet
	cb._spawn_clock = 999.0
	await frames(3)
	_assert(cb.pirates.size() >= 1, "pirate arrives in deep space")
	cb.clear()
	cb._spawn_clock = 0.0
	# lasers: a pirate parked ahead is shot down and pays a bounty
	var credits: int = g.credits
	var kills: int = g.combat.kills
	var p = cb.spawn_pirate(g, w.ship.position + Vector2(0, -260))
	for i in 240:
		p.position = w.ship.position + Vector2(0, -260)
		p.velocity = Vector2.ZERO
		cb.fire_laser(g)
		await physics_frame
		if g.combat.kills > kills:
			break
	_assert(g.combat.kills == kills + 1 and g.credits > credits and cb.pirates.is_empty(), "lasers shoot down a pirate and pay a bounty")
	# missile: homes in on a pirate beside the flight line
	var ammo: int = g.combat.missiles
	p = cb.spawn_pirate(g, w.ship.position + Vector2(160, -420))
	_assert(cb.fire_missile(g) and g.combat.missiles == ammo - 1, "missile launched, one round used")
	for i in 240:
		p.velocity = Vector2.ZERO
		await physics_frame
		if cb.pirates.is_empty():
			break
	_assert(cb.pirates.is_empty() and g.combat.kills == kills + 2, "homing missile destroys the pirate")
	# damage: shield first, then hull, shown on the HUD
	_assert(w.combat_hud.visible, "combat HUD visible in flight")
	var shield: float = g.combat.shield
	cb.hurt_player(g, 10.0)
	_assert(g.combat.shield == shield - 10.0, "pirate bolt hits the shield first")
	cb.hurt_player(g, 40.0)
	_assert(g.combat.shield == 0.0 and g.combat.hull < g.data.upgrades.hull.levels[g.upgrades.hull], "overflow damages the hull")
	# dodge: boosting makes the ship untouchable for a moment, then bolts hurt again
	await frames(30)
	_assert(w.ship.boost() and w.ship.boosting() and w.ship.invulnerable(), "boost starts a dodge")
	var hull: float = g.combat.hull
	var sh: float = g.combat.shield
	cb._add_bolt(w.ship.position, Vector2.ZERO, 1.0, 20.0, false)
	await physics_frame
	await physics_frame
	_assert(g.combat.hull == hull and g.combat.shield == sh, "a bolt passes through the dodging ship")
	cb.bolts.clear()
	for i in 45:
		await physics_frame
	_assert(not w.ship.invulnerable(), "dodge ends")
	cb._add_bolt(w.ship.position, Vector2.ZERO, 1.0, 20.0, false)
	await physics_frame
	await physics_frame
	_assert(g.combat.hull < hull or g.combat.shield < sh, "a bolt hits after the dodge")
	# wreck: half the cargo and a fine, towed back to the patrol base at half hull
	g.cargo["weed:glow"] = 6
	g.credits = 1000
	cb.hurt_player(g, 9999.0)
	await frames(2)
	_assert(g.cargo.get("weed:glow", 0) == 3 and g.credits == 900, "wreck loses half the hold and 10%% credits (%s, %d)" % [g.cargo, g.credits])
	_assert(is_equal_approx(g.combat.hull, g.data.upgrades.hull.levels[g.upgrades.hull] * 0.5) and cb.pirates.is_empty(), "towed back at half hull")
	_assert(w.nearest_location_distance() < 400.0, "wreck respawns next to a location")
	# docking clears the fight; the mechanic repairs
	w.active = false
	cb.spawn_pirate(g, w.ship.position + Vector2(0, -300))
	await frames(2)
	_assert(cb.pirates.is_empty() and not w.combat_hud.visible, "no pirates or combat HUD while docked")
	w.active = true
	await frames(2)



## D3: jumps get interdicted. Forces the roll (chance 1) and plays the choices through the real UI and world.
func _interdiction(m, g) -> void:
	var w = m.world
	var ui = m.interdict_ui
	var cfg: Dictionary = g.data.interdiction
	var saved := cfg.duplicate(true)
	cfg.max_chance = 1.0
	cfg.pirate_chance = {"high": 1.0, "medium": 1.0, "low": 1.0}
	w.clear_patrols()
	g.heat = 0.0
	g.cargo.clear()
	g.credits = 3000
	_assert(g.system == "halvane" and g.location == "" and w.active, "flying in Halvane before the interdiction test")
	_assert(not ui.visible, "no interdiction panel yet")
	# 1) gate jump -> pay
	g.interdict_ready_at = 0.0
	_to_gate(w, "halvane_gate")
	await frames(2)
	var credits: int = g.credits
	m.dock("halvane_gate")
	await frames(3)
	_assert(ui.visible and Interdiction.active(g) and g.system == "halvane" and g.credits == credits, "gate jump is interdicted before the toll is paid")
	_assert(w.ship.frozen and w.input_blocked, "flight freezes under the panel")
	for id in ["fight", "pay", "dump", "flee"]:
		_assert(ui.find_child("Inter_" + id, true, false) != null, "button " + id)
	_assert(ui.find_child("Inter_dump", true, false).disabled, "dump disabled with an empty hold")
	_assert(ui.find_child("InterTitle", true, false).text.contains("PIRATE"), "panel names the pirates")
	var demand: int = g.interdiction.demand
	ui.find_child("Inter_pay", true, false).pressed.emit()
	await frames(4)
	_assert(not ui.visible and g.system == "kovar" and m.world.system == "kovar", "paying lets the jump through")
	_assert(g.credits == credits - demand - int(g.data.jump.fee), "toll and gate fee paid (%d)" % g.credits)
	_assert(not w.input_blocked and w.active, "flight unfrozen after the jump")
	step("interdiction: pay")
	# 2) fight: the ships appear, the gate is jammed, killing them lets the jump go on
	g.interdict_ready_at = 0.0
	_to_gate(w, "kovar_gate")
	await frames(2)
	m.dock("kovar_gate")
	await frames(3)
	_assert(ui.visible and g.system == "kovar", "return jump interdicted")
	var n: int = g.interdiction.ships
	ui.find_child("Inter_fight", true, false).pressed.emit()
	await frames(3)
	_assert(not ui.visible and Interdiction.fighting(g), "fight starts, panel closes")
	var hostile: Array = w.combat.pirates.filter(func(p): return p.has_meta("interdictor"))
	_assert(hostile.size() == n and n >= 1, "%d interdictors spawned" % n)
	_assert(hostile.all(func(p): return p.position.distance_to(w.ship.position) > 500.0), "they arrive from a distance")
	m.dock("kovar_gate")
	await frames(2)
	_assert(g.system == "kovar" and not ui.visible, "the gate is jammed while the fight lasts")
	var kills: int = g.combat.kills
	for p in hostile:
		w.combat._damage_pirate(g, p, 9999.0)
	await frames(4)
	_assert(g.combat.kills == kills + n and not Interdiction.active(g), "all interdictors shot down")
	_assert(g.system == "halvane" and m.world.system == "halvane", "victory: the interrupted jump goes through")
	step("interdiction: fight")
	# 3) the jump drive: the charged drive waits for the answer; keys choose; dump gets rid of the cargo
	g.interdict_ready_at = 0.0
	g.cargo["weed:glow"] = 4
	m.toggle_phone()
	m.phone.open_app("map")
	await frames(3)
	m.phone.find_child("MapSys_kovar", true, false).pressed.emit()
	await frames(3)
	_assert(m.phone.find_child("MapJump", true, false) != null, "map offers the jump")
	m.phone.find_child("MapJump", true, false).pressed.emit()
	await frames(2)
	g.tick(Galaxy.charge_seconds(g) + 1.0)
	await frames(4)
	_assert(ui.visible and Interdiction.active(g) and g.interdiction.via == "drive" and Galaxy.ready(g), "the charged drive is held by the interdiction")
	_assert(g.system == "halvane" and not m.phone.visible, "still home, phone closed")
	_assert(not ui.find_child("Inter_dump", true, false).disabled, "dump is open with cargo")
	await key(KEY_3)
	await frames(4)
	_assert(not ui.visible and g.cargo.get("weed:glow", 0) == 0 and g.system == "kovar", "key 3 dumps the cargo and the drive fires")
	step("interdiction: drive + dump")
	# 4) wreck during a fight ends the encounter; Authority interdiction when hot and loaded
	g.interdict_ready_at = 0.0
	g.heat = 80.0
	g.cargo["weed:glow"] = 3
	cfg.authority.base = 1.0
	_to_gate(w, "kovar_gate")
	await frames(2)
	m.dock("kovar_gate")
	await frames(3)
	_assert(ui.visible and g.interdiction.get("kind", "") == "authority", "Authority interdicts a hot, loaded ship")
	_assert(ui.find_child("InterTitle", true, false).text.contains("AUTHORITY"), "panel names the Authority")
	var heat: float = g.heat
	ui.find_child("Inter_fight", true, false).pressed.emit()
	await frames(3)
	_assert(g.heat > heat and w.combat.pirates.size() == g.interdiction.ships, "fighting the Authority adds heat and spawns cutters")
	w.combat.hurt_player(g, 99999.0)
	await frames(3)
	_assert(not Interdiction.active(g) and w.combat.pirates.is_empty() and not ui.visible, "a wreck ends the encounter")
	# 5) flee: forced both ways through the rng
	g.heat = 0.0
	g.cargo.clear()
	g.system = "kovar"
	w.show_system("kovar")
	g.interdict_ready_at = 0.0
	_to_gate(w, "kovar_gate")
	await frames(2)
	m.dock("kovar_gate")
	await frames(3)
	_assert(ui.visible, "interdicted again after the wreck")
	g.rng.seed = 1
	var fled := false
	for i in 1:
		ui.find_child("Inter_flee", true, false).pressed.emit()
	await frames(4)
	fled = g.system == "halvane"
	_assert(fled or Interdiction.fighting(g), "flee either burns through or starts the fight")
	if Interdiction.fighting(g):
		for p in w.combat.pirates.duplicate():
			w.combat._damage_pirate(g, p, 9999.0)
		await frames(4)
	_assert(g.system == "halvane" and not Interdiction.active(g), "back in Halvane after the encounters")
	# restore the real numbers and disable further random interdictions for the rest of the run
	for k in saved:
		cfg[k] = saved[k]
	g.interdict_ready_at = 1e12
	m.hyper.burst = 0.0
	g.combat.hull = g.data.upgrades.hull.levels[g.upgrades.hull]
	w.clear_patrols()
	w.place_ship_at("halvane_gate")


func _to_gate(w, gate: String) -> void:
	w.ship.position = w.locations[gate].position + Vector2(0, w.locations[gate].radius + 20)
	w.ship.stop()
