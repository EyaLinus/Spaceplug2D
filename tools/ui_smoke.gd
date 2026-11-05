extends SceneTree

const People = preload("res://scripts/core/people.gd")
## UI smoke test: boots the real main scene headless, lands on Mireth and walks the planet surface (collision,
## every door and person, take-off), plays the core loop through the UI layer
## (buy, cook, hand-made batch through every station minigame, sell, upgrade, bribe, pay), flies between locations, triggers a patrol bust,
## pauses, saves/loads and reaches both end screens. Any GDScript error shows up as "SCRIPT ERROR" (CI greps for it).
## godot --headless --path . -s res://tools/ui_smoke.gd

const Workers = preload("res://scripts/core/workers.gd")
const Bench = preload("res://scripts/core/bench.gd")
const Drying = preload("res://scripts/core/drying.gd")
const Galaxy = preload("res://scripts/core/galaxy.gd")
const Combat = preload("res://scripts/core/combat.gd")
const SpaceCombat = preload("res://scripts/core/spacecombat.gd")
const Cartels = preload("res://scripts/core/cartels.gd")
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
	g.data.interdiction.min_day = 9999  # no random interdictions on the scripted jumps (the card is tested on its own)
	var sf = m.surface
	_assert(sf != null and not m.station.visible and not m.world.visible, "starts on foot on the Mireth surface")
	_assert(m.get_viewport().get_camera_2d() == sf.camera, "surface camera is current")
	step("landed on surface")

	# K1 feedback: credit pops next to the HUD, stacked toasts, camera shake on foot, floating text over the player
	var bus = root.get_node("EventBus")
	await frames(2)
	g.credits += 50
	await frames(2)
	_assert(m.hud.fx.pops.any(func(p): return p.text == "+50 cr"), "credit change pops next to the HUD")
	bus.toast.emit("Smoke toast", true)
	bus.toast.emit("Smoke toast", true)
	await frames(1)
	var tb = m.hud._toasts
	var last = tb.get_child(tb.get_child_count() - 1)
	_assert(int(last.get_meta("count", 1)) == 2, "the same toast twice stacks into one card ×2")
	bus.shake.emit(6.0)
	await frames(1)
	_assert(sf.shake > 0.0, "EventBus.shake shakes the surface camera")
	m.hud.fx.over_player("+1 test", Color.WHITE)
	_assert(sf.get_children().any(func(c): return c.get_script() == load("res://scripts/world/float_text.gd")), "floating text over the player")
	step("feedback layer")

	# K2 Style app: buy a jacket by tapping its tile, the walker is recoloured, decor shows up in the estate layout
	var plain_sheet = sf.player.sheet
	g.credits += 500
	m.toggle_phone()
	m.phone.open_app("style")
	await frames(2)
	var jtile = m.phone.find_child("Style_jacket_teal", true, false)
	_assert(jtile != null and not jtile.disabled, "Style app lists the teal jacket")
	jtile.pressed.emit()
	await frames(2)
	_assert(g.style.jacket == "teal", "tapping the tile buys and wears the jacket")
	_assert(sf.player.sheet != null and sf.player.sheet != plain_sheet, "the walker is recoloured")
	m.phone.find_child("Style_decor_plant", true, false).pressed.emit()
	await frames(1)
	_assert(g.style.decor.has("plant"), "decor bought from the app")
	m.phone.close()
	g.credits -= 500 - int(g.data.style.jacket.teal.cost) - int(g.data.style.decor.plant.cost)
	step("style app")

	# K3: contacts filter, stepper detection, quick-save/-load, UI scale
	m.toggle_phone()
	m.phone.open_app("contacts")
	await frames(2)
	var app = m.phone.app_by_id("contacts")
	m.phone.find_child("Filter_hooked", true, false).pressed.emit()
	await frames(2)
	_assert(app.filter == "hooked", "contacts filter switches")
	var listed: int = m.phone.find_children("Contact_*", "", true, false).size()
	var hooked := 0
	for c in g.data.contacts:
		if g.people.get(c.id, {}).get("known", false) and app.passes(g, c):
			hooked += 1
	_assert(listed == hooked, "filter shows only matching contacts (%d)" % listed)
	m.phone.find_child("Filter_all", true, false).pressed.emit()
	await frames(2)
	m.phone.close()
	var UIT = load("res://scripts/ui/ui_theme.gd")
	_assert(UIT.is_stepper("+") and UIT.is_stepper("−") and UIT.is_stepper("-5") and UIT.is_stepper("+10") and not UIT.is_stepper("+5 heat") and not UIT.is_stepper("Buy"), "stepper buttons are recognised")
	var qs_credits: int = g.credits
	m.quick_save()
	g.credits += 777
	m.quick_load()
	await frames(3)
	g = gs.game
	sf = m.surface
	_assert(g.credits == qs_credits and sf != null, "quick-load restores the quick-save")
	var settings = root.get_node("Settings")
	settings.set_ui_scale(2)
	await frames(1)
	_assert(is_equal_approx(m._ui_root.scale.x, 1.25) and m._ui_root.size.x * 1.25 > 1270.0, "UI scale fills the screen at 125%")
	settings.set_ui_scale(0)
	await frames(1)
	step("qol: filter, quick-save, ui scale")

	# quests: the tutorial starts with a tracker, a message from Okka, a waypoint and the Quests app
	var Quests = load("res://scripts/core/quests.gd")
	await frames(2)
	_assert(Quests.tracked(g) == "tut_cook", "tutorial quest running")
	_assert(m.hud.find_child("QuestTracker", true, false).visible, "quest tracker shown")
	_assert(m.hud.find_child("QuestCard", true, false).visible, "Okka's intro card shown")
	var qp = m.hud.quest_point()
	_assert(qp != null and qp.distance_to(sf.interactable("market").pos) < 1.0, "waypoint on the market door")
	await key(KEY_TAB)
	m.phone.open_app("quests")
	await frames(2)
	_assert(m.phone.find_child("Quest_tut_cook", true, false) != null, "quest log lists the tutorial")
	_assert(m.phone.find_child("SkipTutorial", true, false) != null, "tutorial can be skipped")
	await key(KEY_TAB)
	step("quest tracker, waypoint, quest log")

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

	# D4: canals are walls, districts show above the minimap, M zooms the minimap, Shift sprints
	sf.player.position = sf._px([23.5, 36.5])  # north end of the canal bridge
	await pframes(2)
	_assert(m.hud._district.text.begins_with("CANNERY ROW"), "district label (got %s)" % m.hud._district.text)
	var bank := Vector2(10.5 * sf.tile, 37.2 * sf.tile)
	sf.player.position = bank
	for i in 30:
		sf.player.walk(1.0 / 60.0, Vector2.DOWN)
		await physics_frame
	_assert(sf.player.position.y < 38.0 * sf.tile, "the canal blocks walking (y=%.0f)" % sf.player.position.y)
	sf.player.position = sf._px([23.5, 36.5])
	for i in 60:
		sf.player.walk(1.0 / 60.0, Vector2.DOWN)
		await physics_frame
	_assert(sf.player.position.y > 41.0 * sf.tile, "the bridge crosses the canal (y=%.0f)" % sf.player.position.y)
	await pframes(1)
	_assert(m.hud._district.text.begins_with("CANAL DOCKS"), "district changes on the docks (got %s)" % m.hud._district.text)
	var z0: int = m.hud.map_zoom
	await key(KEY_M)
	_assert(m.hud.map_zoom == z0 + 1 and m.hud._district.text.ends_with("×2"), "M zooms the minimap (%d)" % m.hud.map_zoom)
	m.hud.map_zoom = 0
	sf.player.sprinting = true
	sf.player.walk(1.0 / 60.0, Vector2.RIGHT)
	_assert(sf.player.velocity.length() > sf.player.SPEED * 1.3, "sprint is faster than walking")
	sf.player.sprinting = false
	step("districts, canal, minimap zoom, sprint")

	# every door and person opens exactly its own panel
	var expect := {"spaceport": "Shipyard", "market": "Market", "office": "Office",
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

	# B4: the townsfolk are named customers; unknown ones show their job, talking makes them a contact
	var g0 = gs.game
	var local_ids: Array = sf.npcs.keys().filter(func(k): return k.begins_with("mireth_local_"))
	_assert(local_ids.size() == int(gs.data.locals.count.mireth), "all Mireth townsfolk walk the surface (%d)" % local_ids.size())
	_assert(sf.cfg.npcs.all(func(n): return str(n.get("contact", "")) != "" or n.action == "shipyard"), "no anonymous people left")
	var lid: String = local_ids[0]
	var lc: Dictionary = g0.contact(lid)
	sf.place_player_at(lid)
	await pframes(2)
	_assert(sf.npcs[lid].display_name == "" and sf.npcs[lid].subtitle == lc.job, "stranger shows the job (got '%s'/'%s')" % [sf.npcs[lid].display_name, sf.npcs[lid].subtitle])
	_assert(sf.focus.get("payload", {}).get("id", "") == lid and "wants" in m.hud._prompt.text, "prompt says what they want (%s)" % m.hud._prompt.text)
	_assert(sf.interact(), "talk to %s" % lid)
	await frames(2)
	_assert(m.station.visible and m.station.tab_names() == ["Deals"], "a local opens Deals")
	_assert(People.state(g0, lid).known, "talking makes them a contact")
	m.station.close_requested.emit()
	await pframes(2)
	_assert(sf.npcs[lid].display_name == lc.name, "met local shows the name")
	step("named townsfolk")

	# market shop screen: item cards fill a basket, one checkout buys it all
	sf.place_player_at("market")
	await physics_frame
	await physics_frame
	sf.interact()
	await frames(2)
	var have_c := int(g.cargo.get("cannabis", 0))
	m.station.find_child("Item_cannabis", true, false).pressed.emit()
	await frames(1)
	m.station.find_child("Item_cannabis", true, false).pressed.emit()
	await frames(1)
	m.station.find_child("Item_nanoflux", true, false).pressed.emit()
	await frames(1)
	_assert(m.station._basket.get("cannabis", 0) == 2 and m.station._basket.get("nanoflux", 0) == 1, "basket %s" % [m.station._basket])
	var cr_before: int = g.credits
	m.station.find_child("Checkout", true, false).pressed.emit()
	await frames(2)
	_assert(int(g.cargo.get("cannabis", 0)) == have_c + 2 and g.credits < cr_before and m.station._basket.is_empty(), "checkout buys the basket")
	m.station.close_requested.emit()
	await frames(1)
	# shipyard cards: one button per upgrade
	sf.place_player_at("rusk")
	await physics_frame
	await physics_frame
	sf.interact()
	await frames(2)
	_assert(m.station.find_child("Up_cargo", true, false) != null and m.station.find_child("Up_laser", true, false) != null, "upgrade cards")
	_assert(m.station.find_child("Up_flak", true, false) != null and m.station.find_child("Up_ion", true, false) != null, "flak and ion cards")
	_assert(m.station.find_child("Hull_hauler", true, false) != null and m.station.find_child("Hull_courier", true, false) == null, "hull cards (not for the one you fly)")
	m.station.close_requested.emit()
	await frames(1)
	step("market basket + shipyard cards")

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

	# Fixers app: heat per system, wanted level, recruit the local inspector
	await key(KEY_TAB)
	var ftile: Button = m.phone.find_child("App_fixers", true, false)
	_assert(ftile != null, "fixers app tile")
	ftile.pressed.emit()
	await frames(2)
	_assert(m.phone.current_title() == "Fixers" and m.phone.find_child("Wanted", true, false) != null, "fixers app shows the wanted level")
	var frow: Button = m.phone.find_child("Official_vell", true, false)
	_assert(frow != null and m.phone.find_child("Official_roe", true, false) == null, "only met officials listed")
	frow.pressed.emit()
	await frames(2)
	g.credits = 5000
	g.add_heat(30)
	var rbtn: Button = m.phone.find_child("Recruit_vell", true, false)
	_assert(rbtn != null and not rbtn.disabled, "recruit button on the inspector profile")
	rbtn.pressed.emit()
	await frames(2)
	_assert(g.corruption.officials.vell.hired, "inspector recruited from the phone")
	var fix: Button = m.phone.find_child("Fix10_vell", true, false)
	_assert(fix != null, "favour buttons after recruiting")
	var heat_before: float = g.heat
	fix.pressed.emit()
	await frames(2)
	_assert(g.heat < heat_before, "inspector clears heat from the phone")
	g.tick(0.1)
	await frames(2)
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	_assert(not m.phone.visible, "phone closes again")
	step("com-phone fixers")
	# HR app: hire through the phone, assign, set the auto recipe, a day passes and wages are paid
	var hr_saved: Dictionary = g.to_dict()
	g.credits += 5000
	g.buy_estate("cannery_annex")
	_assert(g.estate_owned("cannery_annex"), "annex bought for the HR test")
	g.place_building("cannery_annex", "trim_table", 0, 0)
	g.place_building("cannery_annex", "cook_stove", 2, 0)
	g.place_building("cannery_annex", "pack_table", 4, 0)
	g.place_building("cannery_annex", "extractor", 6, 0)
	m.toggle_phone()
	await frames(2)
	m.phone.open_app("hr")
	await frames(2)
	_assert(m.phone.current_title() == "HR" and m.phone.find_child("Hire_pia", true, false) != null, "HR app lists candidates")
	m.phone.find_child("Hire_pia", true, false).pressed.emit()
	await frames(2)
	var hr_credits_before: int = g.credits
	m.phone.find_child("HireBtn", true, false).pressed.emit()
	await frames(2)
	_assert(Workers.hired(g, "pia") and g.credits < hr_credits_before, "hire button hires and charges")
	m.phone.find_child("Assign_pia_cannery_annex", true, false).pressed.emit()
	await frames(2)
	_assert(g.workers[0].estate == "cannery_annex", "assign button assigns")
	await key(KEY_ESCAPE)
	m.phone.find_child("EstateRow_cannery_annex", true, false).pressed.emit()
	await frames(2)
	var opt: OptionButton = m.phone.find_child("Recipe_cannery_annex", true, false)
	opt.select(1)
	opt.item_selected.emit(1)
	await frames(2)
	_assert(g.estates.cannery_annex.recipe.base == g.data.bases.keys()[0], "recipe picker sets the auto recipe")
	g.cargo["cannabis"] = 5
	g.inside_estate = "cannery_annex"
	g._emit("storage_changed", {})  # the screen rebuilds and enables the buttons
	await frames(2)
	m.phone.find_child("StoreRaws", true, false).pressed.emit()
	await frames(2)
	_assert(g.cargo.is_empty() and not g.estates.cannery_annex.job.is_empty(), "stock button moves raws to storage and the lab hand starts cooking")
	g.tick(60.0)
	await frames(2)
	_assert(g.stats.worker_batches >= 1, "the lab hand cooked a batch")
	m.phone.find_child("TakeProducts", true, false).pressed.emit()
	await frames(2)
	_assert(g.has_contraband(), "take button loads the products")
	g.inside_estate = ""
	var c1: int = g.credits
	var w1: int = int(g.stats.get("wages", 0))
	g.tick(g.day_seconds())
	await frames(2)
	_assert(g.credits < c1 and int(g.stats.wages) - w1 == Workers.wage_total(g), "wages are charged on a new day")  # other daily costs (retainers) may apply too
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	_assert(not m.phone.visible, "phone closed again")
	g.from_dict(g.data, hr_saved)  # later steps expect the annex to be unowned
	step("hr app")
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
	_assert(m.phone.find_child("MeetTime", true, false) != null, "thread shows the meeting time")
	m.phone.home()
	await frames(2)
	var meet_btn: Button = m.phone.find_child("Meet_%d" % int(offer.id), true, false)
	_assert(meet_btn != null, "calendar strip lists the meeting")
	meet_btn.pressed.emit()
	await frames(2)
	_assert(m.phone.find_child("Cancel", true, false) != null, "calendar opens the conversation")
	await key(KEY_TAB)
	_assert(not m.phone.visible, "Tab closes the phone")
	await frames(2)
	_assert(sf.npcs.okka.marker, "okka carries the deal marker")
	g.total_time = float(offer.meet_at)  # skip to the meeting
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

	# Products app: the recipe book lists a discovered product; price it up and back to market
	var Products = load("res://scripts/core/products.gd")
	Products.discover(g, "weed", [], 1, 3)
	var prk: String = Deals.Mixing.key("weed", [g.data.bases.weed.innate])
	await key(KEY_TAB)
	var ptile: Button = m.phone.find_child("App_products", true, false)
	_assert(ptile != null, "products app tile")
	ptile.pressed.emit()
	await frames(2)
	var prow: Button = m.phone.find_child("Product_" + prk.replace(":", "_").replace("+", "_"), true, false)
	_assert(prow != null, "product listed in the recipe book")
	prow.pressed.emit()
	await frames(2)
	m.phone.find_child("Suggested", true, false).pressed.emit()
	await frames(2)
	m.phone.find_child("Up5", true, false).pressed.emit()
	await frames(2)
	_assert(Products.has_price(g, prk) and Products.price(g, prk) == Products.suggested(g, prk) + 5, "asking price set from the phone")
	_assert(m.phone.find_child("Buyer_okka", true, false) != null, "buyers listed with their limits")
	m.phone.find_child("Market", true, false).pressed.emit()
	await frames(2)
	_assert(not Products.has_price(g, prk), "back to market price")
	await key(KEY_TAB)
	step("products app")

	# Dealers: hire one in the HR app, give them a district and stock, they sell, collect the cash in person
	var Dealers = load("res://scripts/core/dealers.gd")
	g.credits = maxi(g.credits, 2000)
	await key(KEY_TAB)
	m.phone.open_app("hr")
	await frames(2)
	var drow: Button = m.phone.find_child("DHire_nyx", true, false)
	_assert(drow != null, "dealer listed for hire")
	drow.pressed.emit()
	await frames(2)
	m.phone.find_child("DealerHire", true, false).pressed.emit()
	await frames(2)
	_assert(not Dealers.find(g, "nyx").is_empty(), "dealer hired from the phone")
	var home_loc: String = g.location
	var dist: Button = m.phone.find_child("District_nyx_" + home_loc, true, false)
	_assert(dist != null, "district buttons")
	dist.pressed.emit()
	await frames(2)
	g.cargo["weed:glow"] = int(g.cargo.get("weed:glow", 0)) + 10
	m.phone.refresh()
	await frames(2)
	var give: Button = m.phone.find_child("GiveAll_nyx", true, false)
	_assert(give != null, "give buttons while docked in the district")
	give.pressed.emit()
	await frames(2)
	var nyx: Dictionary = Dealers.find(g, "nyx")
	_assert(Dealers.units(nyx) > 0, "dealer stocked")
	nyx.cash = 120
	m.phone.refresh()
	await frames(2)
	var c_before: int = g.credits
	m.phone.find_child("Collect_nyx", true, false).pressed.emit()
	await frames(2)
	_assert(g.credits == c_before + 120, "cash collected from the phone")
	await key(KEY_TAB)
	step("dealers")

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
	_assert(sf.interactable("okka").pos.distance_to(sf.npcs.okka.position) < 3.0, "okka's interaction point follows her")  # updated once per frame, she may be one step ahead
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
	var dearned: int = int(g.stats.earned)
	ddeal.pressed.emit()
	await frames(2)
	_assert(doffer.state == "dropped", "goods left in the drop")
	g.tick(40.0)
	await frames(2)
	_assert(doffer.state == "done" and int(g.stats.earned) - dearned == int(doffer.price) * int(doffer.qty), "customer collected and paid")  # credits also move with retainers
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
	_assert(m.bench.visible and m.bench.mode == "wait" and not m.station.visible, "a station without a tray explains where batches start (mode %s)" % m.bench.mode)
	_assert(m.bench.find_child("TakeDown", true, false) != null, "placed stations can be taken down from their overlay")
	_assert(g.inside_estate == "cannery_annex" and g.lab_here(), "the estate counts as a lab")
	m.bench.close()
	# drying table: build it, hang weed on the rack, wait out the cure, take it off one grade higher
	_assert(gs.act(g.place_building("cannery_annex", "drying_table", 5, 0)).ok, "drying table placed")
	m.enter_estate("cannery_annex", es.player.position)
	await frames(2)
	es = m.surface
	var dry_idx := -1
	for bi in g.estates.cannery_annex.buildings.size():
		if g.estates.cannery_annex.buildings[bi].id == "drying_table":
			dry_idx = bi
	es.place_player_at("b%d" % dry_idx)
	await physics_frame
	await physics_frame
	g.cargo["weed:glow"] = 10
	_assert(es.interact(), "use the drying table")
	await frames(2)
	_assert(m.bench.visible and m.bench.mode == "dry" and m.bench.find_child("DryLoad", true, false) != null, "drying table opens the rack panel")
	m.bench.find_child("DryLoad", true, false).pressed.emit()
	await frames(2)
	_assert(g.cargo.get("weed:glow", 0) == 0 and Drying.loaded(g, "cannery_annex") == 10, "load button hangs the weed on the rack")
	_assert(m.bench.find_child("DryCollect", true, false).disabled, "wet product can't be collected")
	for db in g.drying.cannery_annex:
		db.left = 0.0  # fast-forward the cure without moving the world clock
	m.bench.open_station("drying_table", dry_idx)
	await frames(2)
	m.bench.find_child("DryCollect", true, false).pressed.emit()
	await frames(2)
	_assert(g.cargo.get("weed:glow@2", 0) == 8, "cured weed is Premium and 20%% lighter (%s)" % [g.cargo])
	g.cargo.erase("weed:glow@2")
	m.bench.close()
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
	gs.act(g.start_batch("weed", ["nanoflux"], 5))
	await frames(2)
	g.tick(30.0)
	gs.act(g.collect_stash())
	await frames(2)
	_assert(g.has_contraband(), "cooked product")
	step("quick batch (core, used by workers and the bot)")

	# hand-made batch on foot: the Old Cannery is a starter estate; carry the tray from station to station
	sf.place_player_at("cannery")
	await physics_frame
	await physics_frame
	_assert(sf.interact(), "cannery door")
	await frames(2)
	var cs = m.surface
	_assert(cs.cfg.get("estate", "") == "cannery_rig" and g.inside_estate == "cannery_rig", "inside the cannery rig")
	gs.act(g.buy("cannabis", 5))
	gs.act(g.buy("nanoflux", 5))
	var bench = m.bench
	bench.autoplay = true
	Engine.time_scale = 6.0
	var line := {"trim_table": "b0", "extractor": "b2", "mixing_station": "b3", "cook_stove": "b4", "pack_table": "b6"}
	var seen: Array = []
	for st in line:
		cs.place_player_at(line[st])
		await physics_frame
		await physics_frame
		_assert(cs.interact(), "use the %s" % st)
		await frames(2)
		_assert(bench.visible and bench.station_id == st, "%s overlay open" % st)
		if bench.mode == "start":
			_assert(bench.find_child("Base_weed", true, false) != null, "weed card on the trim table")
			bench._qty = 5
			bench.find_child("StartBatch", true, false).pressed.emit()
		elif bench.mode == "mix":
			bench.find_child("Add_nanoflux", true, false).pressed.emit()
			await frames(1)
			_assert("Overclock" in bench.find_child("Preview", true, false).text, "mix preview shows the new trait")
			bench.find_child("MixGo", true, false).pressed.emit()
		await frames(1)
		_assert(bench.current != null, "%s minigame runs" % st)
		seen.append(st)
		for i in 3000:
			await process_frame
			if not bench.visible:
				break
		_assert(not bench.visible, "%s done and closed" % st)
	Engine.time_scale = 1.0
	_assert(seen == line.keys(), "every station minigame ran: %s" % [seen])
	_assert(Bench.tray(g).is_empty() and g.lab_queue.size() == 1 and g.lab_queue[0].product.begins_with("weed:overclock+radiant"), "hand batch queued: %s" % [g.lab_queue])
	step("hand batch on foot -> %s" % [g.lab_queue[0]])
	# Esc during a minigame records nothing: the station stays next; scrapping returns the raws to the stash
	bench.autoplay = false
	gs.act(g.buy("cannabis", 2))
	cs.place_player_at("b0")
	await physics_frame
	await physics_frame
	cs.interact()
	await frames(2)
	bench._qty = 2
	bench.find_child("StartBatch", true, false).pressed.emit()
	await frames(2)
	await key(KEY_ESCAPE)
	_assert(not bench.visible and Bench.next_station(g, Bench.tray(g)) == "trim_table", "Esc stops, trim table stays next")
	cs.place_player_at("b4")
	await physics_frame
	await physics_frame
	cs.interact()
	await frames(2)
	_assert(bench.mode == "wait", "the stove waits for the tray")
	bench.find_child("Scrap", true, false).pressed.emit()
	await frames(2)
	_assert(Bench.tray(g).is_empty() and int(g.stash.get("cannabis", 0)) >= 2, "scrapped tray, raws in the stash")
	bench.close()
	# stash crate: cook queue + loading the stash into the hold
	g.tick(60.0)
	cs.place_player_at("stash")
	await physics_frame
	await physics_frame
	_assert(cs.interact(), "stash crate")
	await frames(2)
	_assert(m.station.visible and m.station.tab_names() == ["Stash"], "stash crate opens the stash")
	m.station.find_child("LoadStash", true, false).pressed.emit()
	await frames(2)
	_assert(g.cargo.keys().any(func(k): return k.begins_with("weed:overclock+radiant")), "product loaded into the hold")
	m.station.close()
	cs.place_player_at("exit")
	await physics_frame
	await physics_frame
	cs.interact()
	await frames(2)
	sf = m.surface
	_assert(g.inside_estate == "" and sf.loc_id == "mireth", "out of the cannery")
	step("minigame stop, scrap, stash crate")

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
	# K3 autopilot: a waypoint ahead-right, the ship turns to it, thrusts, and switches off on arrival
	var ship = m.world.ship
	var goal: Vector2 = ship.position + Vector2(900, -300)
	var old_provider: Callable = ship.goal_provider
	ship.goal_provider = func(): return goal
	ship.set_autopilot(true)
	_assert(ship.autopilot, "autopilot engages with a waypoint")
	var ap_start: float = ship.position.distance_to(goal)
	for i in 600:
		if not ship.autopilot:
			break
		var ap: Dictionary = ship.autopilot_step(1.0 / 60.0)
		ship.rotation += float(ap.turn) * float(ship.cfg.turn_speed) / 60.0
		ship.steer(1.0 / 60.0, ap.thrust, ap.brake)
	_assert(not ship.autopilot and ship.position.distance_to(goal) < ap_start * 0.5, "autopilot flew to the waypoint and switched off")
	ship.goal_provider = old_provider
	ship.velocity = Vector2.ZERO
	step("autopilot")
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
	await _space_combat_2(m, g)
	step("space combat II: wings, flak, ion, loot, cartel base")
	await _interdiction(m, g)
	step("interdiction card")

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
	# influence overlay and the cartel screen
	m.phone.find_child("MapMode_influence", true, false).pressed.emit()
	await frames(3)
	_assert(m.phone.find_child("MapInfluenceBar", true, false) != null and m.phone.find_child("Share_varrow", true, false) != null, "influence overlay shows the system share and per-location bars")
	m.phone.find_child("MapCartels", true, false).pressed.emit()
	await frames(3)
	_assert(m.phone.current_title() == "Cartels" and m.phone.find_child("Cartel_comets", true, false) != null and m.phone.find_child("Cartel_veil", true, false) != null, "cartel screen lists the cartels")
	m.phone.back()
	await frames(3)
	m.phone.find_child("MapMode_heat", true, false).pressed.emit()
	await frames(3)
	step("map influence overlay and cartels")
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


## E4: cartel wings, flak, ion stun, loot crates, a cartel base raid.
func _space_combat_2(m, g) -> void:
	var w = m.world
	var cb = w.combat
	w.clear_patrols()
	g.heat = 0.0
	g.combat.hull = SpaceCombat.max_hull(g)
	for pos in [Vector2(-3000, 3000), Vector2(3000, 3000), Vector2(3000, -3000), Vector2.ZERO]:
		w.ship.position = pos
		if w.nearest_location_distance() > 1200.0:
			break
	w.ship.rotation = 0.0
	w.ship.stop()
	# a wing of tinted cartel ships
	var ships: Array = cb.spawn_wing(g, "comets", ["fighter", "fighter", "gunship"], w.ship.position + Vector2(0, -900))
	_assert(ships.size() == 3 and ships[2].kind == "gunship" and ships[0].cartel == "comets" and cb.pirates.size() == 3, "cartel wing spawns")
	cb.clear()
	# flak shreds a fighter up close
	g.upgrades.flak = 2
	g.upgrades.ion = 1
	g.upgrades.missile = 1
	g.combat.secondary = "flak"
	var f = cb.spawn_enemy(g, "fighter", "comets", w.ship.position + Vector2(0, -150))
	var kills: int = g.combat.kills
	var host := Cartels.hostility(g, "comets")
	for i in 120:
		f.position = w.ship.position + Vector2(0, -150)
		f.velocity = Vector2.ZERO
		cb._missile_cd = 0.0
		cb.fire_flak(g)
		await physics_frame
		if g.combat.kills > kills:
			break
	_assert(g.combat.kills == kills + 1 and Cartels.hostility(g, "comets") > host and int(Cartels.state(g, "comets").kills) >= 1, "flak downs a cartel fighter and angers the cartel")
	# ion stuns a gunship
	cb._missile_cd = 0.0
	var gs = cb.spawn_enemy(g, "gunship", "tide", w.ship.position + Vector2(0, -350))
	_assert(cb.fire_ion(g), "ion bolt fired")
	for i in 60:
		gs.position = w.ship.position + Vector2(0, -350)
		await physics_frame
		if gs.stun > 0.0:
			break
	_assert(gs.stun > 0.0 and gs.hull < float(g.data.space_combat.enemies.gunship.hull), "ion stuns and damages the gunship")
	cb.clear()
	# loot crate: fly over it
	g.cargo.erase("pseudo")
	var cr: int = g.credits
	cb.drop_loot(w.ship.position + Vector2(0, -10), [{"item": "credits", "qty": 77}, {"item": "pseudo", "qty": 2}])
	await frames(3)
	_assert(cb.loot.is_empty() and g.credits == cr + 77 and int(g.cargo.get("pseudo", 0)) == 2, "loot crate picked up")
	# the HUD shows the secondary weapon
	g.combat.secondary = "ion"
	await frames(2)
	_assert(w.combat_hud._missiles.text.contains("Ion") and w.combat_hud._missiles.text.contains("switch"), "HUD shows the selected secondary")
	# raid the Comet Nest: turrets wake up, defenders launch, the base dies to concentrated fire
	var nest: Node2D = w.locations["comet_nest"]
	w.ship.position = nest.position + Vector2(0, 600)
	w.ship.rotation = 0.0
	w.ship.stop()
	await frames(3)
	var bs: Dictionary = cb.bases.get("comet_nest", {})
	_assert(not bs.is_empty() and bs.awake and cb.pirates.size() >= 1, "base wakes up and launches defenders")
	cr = g.credits
	g.combat.hull = 9999.0
	cb.damage_base(g, "comet_nest", float(bs.hull) - 1.0)
	_assert(cb.bases.has("comet_nest"), "base survives until the last hit")
	for e in cb.pirates:
		e.queue_free()
	cb.pirates.clear()
	cb._add_bolt(nest.position + Vector2(0, 40), Vector2.ZERO, 0.5, 10.0, true)
	await physics_frame
	await physics_frame
	_assert(not cb.bases.has("comet_nest") and Cartels.weakened(g, "comets") and g.credits > cr, "laser hit finishes the base: raid paid, cartel weakened")
	_assert(not cb.loot.is_empty(), "the base drops loot")
	cb.clear()
	g.combat.hull = SpaceCombat.max_hull(g)
	g.upgrades.flak = 0
	g.upgrades.ion = 0
	g.upgrades.missile = 0
	g.combat.secondary = "missile"
	Cartels.state(g, "comets").weakened = 0
	w.place_ship_at("mireth")
	await frames(2)


## D3: an interdiction card pauses the flight; paying closes it, fighting spawns the wing ahead of the ship.
func _interdiction(m, g) -> void:
	var w = m.world
	g.cargo["weed:glow"] = 6
	g.credits = 5000
	Interdiction.begin(g, {"kind": "cartel", "cartel": "comets", "units": ["fighter", "fighter"]})
	await frames(3)
	_assert(m.interdict.visible and root.get_node("GameState").paused, "interdiction card up, game paused")
	for c in ["pay", "dump", "flee", "fight"]:
		_assert(m.interdict.find_child("Interdict_" + c, true, false) != null, "card offers " + c)
	m.toggle_pause()
	_assert(not m.pause_menu.visible, "no pause menu over the card")
	var cr: int = g.credits
	m.interdict.find_child("Interdict_pay", true, false).pressed.emit()
	await frames(2)
	_assert(not m.interdict.visible and not root.get_node("GameState").paused and g.credits < cr and not Interdiction.pending(g), "toll paid, flight resumes")
	w.combat.clear()
	Interdiction.begin(g, {"kind": "authority", "cartel": "", "units": ["interceptor", "interceptor"]})
	await frames(3)
	_assert(m.interdict.visible, "Authority card up")
	m.interdict.find_child("Interdict_fight", true, false).pressed.emit()
	await frames(2)
	_assert(not m.interdict.visible and w.combat.pirates.size() == 2 and w.combat.pirates[0].kind == "interceptor", "fight spawns the interceptors")
	w.combat.clear()
	g.cargo.erase("weed:glow")
	g.heat = 0.0

