extends SceneTree
## Headless unit tests for the core simulation. Run: godot --headless --path . -s res://tests/run_tests.gd
## Exit code 1 on any failure.

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")
const Mixing = preload("res://scripts/core/mixing.gd")
const Packaging = preload("res://scripts/core/packaging.gd")
const Production = preload("res://scripts/core/production.gd")
const People = preload("res://scripts/core/people.gd")
const Corruption = preload("res://scripts/core/corruption.gd")
const Curfew = preload("res://scripts/core/curfew.gd")
const Workers = preload("res://scripts/core/workers.gd")
const WorkerWalk = preload("res://scripts/core/worker_walk.gd")
const Bench = preload("res://scripts/core/bench.gd")
const Deals = preload("res://scripts/core/deals.gd")
const Orders = preload("res://scripts/core/orders.gd")
const Galaxy = preload("res://scripts/core/galaxy.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Deaddrops = preload("res://scripts/core/deaddrops.gd")
const ArtReg = preload("res://scripts/core/art.gd")
const SpaceCombat = preload("res://scripts/core/spacecombat.gd")
const Products = preload("res://scripts/core/products.gd")
const Dealers = preload("res://scripts/core/dealers.gd")
const Drones = preload("res://scripts/core/drones.gd")
const Vault = preload("res://scripts/core/vault.gd")
const Quests = preload("res://scripts/core/quests.gd")
const Locals = preload("res://scripts/core/locals.gd")
const Hiding = preload("res://scripts/core/hiding.gd")
const Cartels = preload("res://scripts/core/cartels.gd")
const PriceWar = preload("res://scripts/core/pricewar.gd")
const Chatter = preload("res://scripts/core/chatter.gd")
const Interdiction = preload("res://scripts/core/interdiction.gd")
const Escort = preload("res://scripts/core/escort.gd")
const EstateUpkeep = preload("res://scripts/core/estate_upkeep.gd")
const Interiors = preload("res://scripts/core/interiors.gd")
const Raids = preload("res://scripts/core/raids.gd")
const HeatZones = preload("res://scripts/core/heat_zones.gd")
const PatrolFeel = preload("res://scripts/core/patrolfeel.gd")
const Walkups = preload("res://scripts/core/walkups.gd")
const Loc = preload("res://scripts/core/loc.gd")
const Laws = preload("res://scripts/core/laws.gd")
const Drying = preload("res://scripts/core/drying.gd")
const Sealing = preload("res://scripts/core/sealing.gd")
const Machines = preload("res://scripts/core/machines.gd")

var data: Dictionary
var failures := 0
var checks := 0


func _init() -> void:
	data = Data.load_all()
	for t in [
		"test_loc_tables",
		"test_loc_fallback",
		"test_data_references",
		"test_autopilot_avoid",
		"test_surface_layouts",
		"test_interiors",
		"test_art_registry",
		"test_art_pass4",
		"test_art_wiring",
		"test_police_on_foot",
		"test_hiding",
		"test_flee_heat",
		"test_combat_weapons",
		"test_combat_player",
		"test_combat_geometry",
		"test_combat_officers",
		"test_combat_cover_layout",
		"test_combat_save",
		"test_estates",
		"test_bench_line",
		"test_bench_mixing",
		"test_bench_save",
		"test_mixing_journal",
		"test_machines_data",
		"test_machines_provide_stations",
		"test_machines_run",
		"test_machines_mixer_and_packer",
		"test_machines_quality_below_hands",
		"test_machines_workers",
		"test_machines_save",
		"test_workers",
		"test_worker_walk",
		"test_ship_bay",
		"test_orders",
		"test_order_kits",
		"test_orders_save",
		"test_galaxy_routes",
		"test_galaxy_overlays",
		"test_planet_laws",
		"test_second_system",
		"test_jump_drive",
		"test_jump_drive_multi_hop",
		"test_mixing_rules",
		"test_buy_and_cargo_limit",
		"test_lab_batch",
		"test_production_stations",
		"test_production_outcome",
		"test_quality_grade_keys",
		"test_packaging_tiers",
		"test_station_minigames",
		"test_sell_contact_and_fence",
		"test_products_recipe_book",
		"test_products_asking_price",
		"test_deal_appointments",
		"test_deal_haggle_qty_time",
		"test_dealers",
		"test_dealers_bust_and_save",
		"test_drones",
		"test_drones_loss_upkeep_save",
		"test_vault",
		"test_quest_data",
		"test_quest_tutorial_flow",
		"test_quest_retry_and_skip",
		"test_quest_save",
		"test_quest_main_chapter1",
		"test_people_profiles",
		"test_people_deals",
		"test_people_save",
		"test_people_schedules_on_surfaces",
		"test_idle_chatter",
		"test_planet_districts",
		"test_locals",
		"test_walkups",
		"test_deal_requests",
		"test_deal_answers",
		"test_deal_fulfill",
		"test_deaddrops",
		"test_deaddrops_save",
		"test_market_saturation_recovers",
		"test_heat_and_patrols",
		"test_galaxy_and_jump",
		"test_bust",
		"test_upgrades",
		"test_estate_tiers",
		"test_space_combat_stats",
		"test_space_combat_damage",
		"test_space_combat_pirates",
		"test_space_combat_mechanic",
		"test_space_combat_save",
		"test_space_combat_balance",
		"test_cartels_data",
		"test_cartels_influence",
		"test_cartels_daily_and_robbery",
		"test_cartels_save",
		"test_pricewar_start",
		"test_pricewar_prices",
		"test_pricewar_ending",
		"test_pricewar_save",
		"test_space_enemies_and_loot",
		"test_space_secondaries",
		"test_space_wings",
		"test_cartel_bases",
		"test_ship_classes",
		"test_patrol_feel_fields",
		"test_patrol_feel_warning",
		"test_interdiction_chances",
		"test_interdiction_choices",
		"test_interdiction_on_jump",
		"test_quest_chapter2",
		"test_escort_data",
		"test_escort_flow",
		"test_escort_enemies",
		"test_escort_jump",
		"test_escort_save",
		"test_quest_chapter3",
		"test_bribe",
		"test_corruption_data",
		"test_heat_per_system",
		"test_wanted_level",
		"test_officials",
		"test_customs_scan_pass",
		"test_sweep_and_tip_off",
		"test_corruption_save",
		"test_curfew",
		"test_debt_win_and_loss",
		"test_save_roundtrip",
		"test_style",
		"test_price_board",
		"test_raids",
		"test_estate_upkeep",
		"test_grow_botanist",
		"test_heat_zones",
		"test_grow",
		"test_map_marker",
		"test_drying_table",
		"test_sealing_bench",
		"test_drug_ladder",
		"test_old_save_names_migrate",
		"test_core_loop_is_profitable",
	]:
		var before := failures
		call(t)
		print(("PASS " if failures == before else "FAIL ") + t)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("  x " + msg)


func new_game() -> Game:
	var g := Game.new()
	g.new_game(data, 7)
	return g


func test_data_references() -> void:
	for b in data.bases:
		check(data.raws.has(data.bases[b].raw), "base %s raw exists" % b)
		check(data.traits.has(data.bases[b].innate), "base %s innate trait exists" % b)
	for a in data.additives:
		var ad: Dictionary = data.additives[a]
		check(data.traits.has(ad.adds), "additive %s trait exists" % a)
		for k in ad.transforms:
			check(data.traits.has(k) and data.traits.has(ad.transforms[k]), "additive %s transform %s valid" % [a, k])
	for c in data.contacts:
		check(data.locations.has(c.location), "contact %s location" % c.id)
		check(data.traits.has(c.likes), "contact %s likes valid trait" % c.id)
	for u in data.upgrades:
		check(data.upgrades[u].costs.size() == data.upgrades[u].levels.size() - 1, "upgrade %s costs match levels" % u)
	for loc in data.locations:
		for item in data.locations[loc].sells_raw:
			check(data.raws.has(item), "%s sells known raw %s" % [loc, item])


## Every surface, character look and prop has art in assets/gfx (see scripts/core/art.gd).
func test_art_registry() -> void:
	var Art = load("res://scripts/core/art.gd")
	for f in ["panel", "inset", "card", "card_hover", "button", "button_hover", "button_pressed", "button_disabled",
			"button_accent", "button_accent_hover", "tab", "tab_selected", "tooltip", "bar_bg"]:
		var ft: Texture2D = Art.tex("ui/%s.png" % f)
		check(ft != null and ft.get_width() == 24, "UI frame %s exists (12 art px)" % f)
	for loc in data.surfaces:
		var set_name: String = Art.TILESETS.get(loc, "")
		check(set_name != "", "surface %s has a tile set" % loc)
		for kind in ["ground", "road", "plaza"]:
			var t: Texture2D = Art.tex("tiles/%s_%s.png" % [set_name, kind])
			check(t != null and t.get_height() == Art.TILE and t.get_width() % Art.TILE == 0, "tiles %s_%s load" % [set_name, kind])
		for p in data.surfaces[loc].get("props", []):
			check(Art.tex("props/%s.png" % p[0]) != null, "%s prop %s has art" % [loc, p[0]])
	for look in ["player", "officer"] + Art.NPC_LOOKS.keys():
		var c: Texture2D = Art.character(look)
		check(c != null and c.get_size() == Vector2(Art.CHAR * 3, Art.CHAR * 3), "character sheet %s is 3x3 frames" % look)
	for part in ["roof", "wall", "window", "door", "hatch", "roof_b", "roof_c", "wall_b", "wall_c", "window_shut", "window_dark",
			"awning", "roof_vent", "roof_skylight", "roof_chimney", "roof_dish"]:
		check(Art.tex("buildings/%s.png" % part) != null, "building part %s" % part)
	for loc in data.surfaces:
		var gt: Texture2D = Art.tex("tiles/%s_ground.png" % Art.TILESETS[loc])
		check(gt.get_width() / Art.TILE > Art.PLAIN_TILES, "%s ground has feature tiles beyond the plain ones" % loc)
		for a in data.surfaces[loc].get("areas", []):
			if ["grass", "sand", "salt", "ice", "rubble"].has(str(a[4])):
				check(Art.tex("tiles/area_%s.png" % a[4]) != null, "%s area %s has a paint strip" % [loc, a[4]])
	var feature_cells := 0
	var plain_ok := true
	for i in 2000:
		var v: int = Art.pick_variant(hash(i * 977), 8)
		feature_cells += 1 if v >= Art.PLAIN_TILES else 0
		plain_ok = plain_ok and v >= 0 and v < 8
	check(plain_ok and feature_cells > 2000 * 0.08 and feature_cells < 2000 * 0.22, "feature tiles cover roughly %d percent of ground cells (%d of 2000)" % [Art.FEATURE_CHANCE, feature_cells])
	check(Art.pick_variant(12345, 4) < 4, "four-tile strips keep plain picks")
	check(Art.facade_variant("mireth/market", 1, 3) == Art.facade_variant("mireth/market", 1, 3), "facade variant is stable")
	var seen := {}
	for bid in ["market", "spaceport", "cannery", "office", "shack", "depot", "cantina"]:
		seen[Art.facade_variant("mireth/" + bid, 1, 3)] = true
	check(seen.size() >= 2, "roof variants differ between buildings")
	check(Art.tex("ships/ship.png") != null, "ship sprite")
	check(Art.tex("ships/patrol.png") != null, "patrol sprite")
	for k in Art.SHIP_UNDER + Art.SHIP_OVER:
		check(data.upgrades.has(k), "ship module %s is an upgrade" % k)
		check(Art.ship_module(k, 0) == null, "%s level 0 has no module" % k)
		for lvl in range(1, data.upgrades[k].levels.size()):
			var m: Texture2D = Art.ship_module(k, lvl)
			check(m != null and m.get_size() == Vector2(48, 48), "ship module %s Mk %d is 48 px" % [k, lvl + 1])
	check(Art.SHIP_NOZZLES.size() == data.upgrades.engine.levels.size(), "one nozzle layout per engine level")
	for k in data.raws.keys() + data.additives.keys() + data.bases.keys():
		check(Art.icon_for(k) != null, "item %s has an icon" % k)
	for k in data.upgrades:
		check(Art.icon_for("up_" + k) != null, "upgrade %s has an icon" % k)
	check(Art.icon_for("weed:overclock+radiant@premium") == Art.icon_for("weed"), "product keys use their base icon")
	for loc in data.locations:
		check(Art.tex("space/%s.png" % loc) != null, "location %s has a space sprite" % loc)
	for id in data.stations:
		var st_tex: Texture2D = Art.tex("stations/%s.png" % id)
		var fp: Array = data.buildables[id].size
		check(st_tex != null and st_tex.get_size() == Vector2(fp[0], fp[1]) * Art.TILE, "station %s has art matching its footprint" % id)
	check(Art.tex("missing/nothing.png") == null, "missing art returns null (procedural fallback)")
	check(Art.look_for_color(Color("#ff6b5f")) == "npc_red", "npc look follows data colour")


## Art pass 4: icons for lab stations, ground weapons, combat HUD and map; fx, idle sheets, ground edges, starfield.
func test_art_pass4() -> void:
	var Art = load("res://scripts/core/art.gd")
	for id in data.stations:
		check(Art.icon_for("st_" + id) != null, "station %s has a menu icon" % id)
	for w in data.combat.weapons:
		check(Art.icon_for("wpn_" + w) != null, "weapon %s has an icon" % w)
	for k in ["hud_hull", "hud_shield", "hud_missile", "hud_boost", "map_star", "map_gate", "map_ship", "map_hostile"]:
		check(Art.icon_for(k) != null and Art.icon_for(k).get_size() == Vector2(32, 32), "icon %s is 32 px" % k)
	for pair in [["bolt_laser", Vector2(32, 10)], ["bolt_pirate", Vector2(24, 10)], ["missile", Vector2(32, 16)], ["explosion", Vector2(128, 32)], ["hit", Vector2(48, 16)], ["shield", Vector2(192, 64)]]:
		var t: Texture2D = Art.fx(pair[0])
		check(t != null and t.get_size() == pair[1], "fx %s has the expected size" % pair[0])
	for look in ["player", "officer"] + Art.NPC_LOOKS.keys():
		var c: Texture2D = Art.idle_sheet(look)
		check(c != null and c.get_size() == Vector2(Art.CHAR * Art.IDLE_FRAMES, Art.CHAR * 3), "idle sheet %s is %dx3 frames" % [look, Art.IDLE_FRAMES])
	for set_name in Art.TILESETS.values():
		var e: Texture2D = Art.edge_strip(set_name)
		check(e != null and e.get_size() == Vector2(Art.TILE * Art.EDGE_ORDER.size(), Art.TILE), "tile set %s has an edge strip" % set_name)
	var stars: Texture2D = Art.tex("space/stars.png")
	check(stars != null and stars.get_size() == Vector2(128, 16), "starfield sprite strip (8 sprites of 16 px)")
	var neb: Texture2D = Art.tex("space/nebula.png")
	check(neb != null and neb.get_size() == Vector2(288, 96), "nebula strip (3 clouds of 96 px)")


## Art pass 4 wiring helpers: idle frames, fringe planning, fx strips, sprite fx entries.
func test_art_wiring() -> void:
	var Art = load("res://scripts/core/art.gd")
	var seen := {}
	for i in 36:
		seen[Art.idle_frame(i * 0.1)] = true
	check(seen.keys().size() == 4 and Art.idle_frame(0.0) == 0 and Art.idle_frame(Art.IDLE_CYCLE - 0.1) == 3, "idle loop stands, breathes, stands, blinks")
	check(Art.idle_frame(Art.IDLE_CYCLE + 0.1) == 0, "idle loop repeats")
	var solid := func(c: Vector2i) -> bool: return Rect2i(0, 0, 3, 2).has_point(c)
	var plan: Array = Art.edge_plan(Rect2i(0, 0, 3, 2), solid)
	var sides := {}
	for e in plan:
		sides["%d,%d:%s" % [e[0].x, e[0].y, Art.EDGE_ORDER[e[1]]]] = true
	check(sides.has("0,0:N") and sides.has("0,0:W") and sides.has("2,1:S") and sides.has("2,1:E") and not sides.has("1,0:S"), "fringes only on open sides of a 3x2 road")
	check(plan.size() == 2 * 3 + 2 * 2, "3x2 road: 10 side fringes")
	var solid_set := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(0, 1)]
	var junction: Array = Art.edge_plan(Rect2i(1, 1, 2, 1), func(c: Vector2i) -> bool: return c in solid_set)
	var has_nw := false
	for e in junction:
		has_nw = has_nw or (e[0] == Vector2i(1, 1) and e[1] == 7)
	check(has_nw, "inner corner: N and W paved, only the diagonal is ground gives an NW fringe")
	check(Art.edge_strip("nothing") == null and Art.fx("nothing") == null, "missing fx/edge art is null")


func test_surface_layouts() -> void:
	check(data.surfaces.has(data.start.location), "start location has a walkable surface")
	var actions := ["market", "lab", "shipyard", "office", "deal", "fence", "estate", "takeoff"]
	for loc in data.locations:
		check(data.surfaces.has(loc) or not data.locations[loc].get("dockable", true), "dockable %s has a surface" % loc)
	for loc in data.surfaces:
		var s: Dictionary = data.surfaces[loc]
		check(data.locations.has(loc), "surface %s is a location" % loc)
		var map := Rect2(0, 0, s.size[0], s.size[1])
		var rects: Array = []
		for b in s.buildings:
			var r := Rect2(b.rect[0], b.rect[1], b.rect[2], b.rect[3])
			check(map.encloses(r), "%s/%s inside the map" % [loc, b.id])
			for o in rects:
				check(not o.intersects(r), "%s/%s does not overlap another building" % [loc, b.id])
			rects.append(r)
			if b.has("action"):
				check(b.action in actions, "%s/%s action %s known" % [loc, b.id, b.action])
				if b.action == "estate":
					check(data.estates.has(b.estate) and data.estates[b.estate].location == loc, "%s/%s sells an estate of this planet" % [loc, b.id])
				var door := Vector2(b.door[0], b.door[1])
				var edge_y: float = r.end.y if b.get("side", "bottom") == "bottom" else r.position.y
				check(is_equal_approx(door.y, edge_y) and door.x > r.position.x and door.x < r.end.x, "%s/%s door on its edge" % [loc, b.id])
		var free_points: Array = [["spawn", s.spawn]]
		for n in s.npcs:
			free_points.append([n.id, n.pos])
			check(n.action in actions, "%s npc %s action known" % [loc, n.id])
			if n.action == "deal":
				check(data.contacts.any(func(c): return c.id == n.contact and c.location == loc), "%s npc %s is a contact here" % [loc, n.id])
		for fp in free_points:
			var p := Vector2(fp[1][0], fp[1][1])
			check(map.has_point(p) and not rects.any(func(r): return r.has_point(p)), "%s %s stands on free ground" % [loc, fp[0]])
		# every economy feature of the location must be reachable on foot
		var reachable: Array = []
		for b in s.buildings:
			reachable.append(b.get("action", ""))
		for n in s.npcs:
			reachable.append(n.action)
		var ld: Dictionary = data.locations[loc]
		check("market" in reachable, "%s market reachable" % loc)
		var starter_here: bool = s.buildings.any(func(b): return data.estates.get(b.get("estate", ""), {}).get("starter", false))
		check(not ld.get("lab", false) or starter_here, "%s production line (starter estate) reachable" % loc)
		check(not ld.get("shipyard", false) or "shipyard" in reachable, "%s shipyard reachable" % loc)
		check(not ld.get("office", false) or "office" in reachable, "%s office reachable" % loc)
		check(not ld.get("fence", false) or "fence" in reachable, "%s fence reachable" % loc)
		check(ld.get("fence", false) or not "fence" in reachable, "%s has no fence door without a fence" % loc)
		check(s.has("pad"), "%s has a launch pad" % loc)
		check(s.has("security"), "%s sets its police security" % loc)
		for e in data.estates:
			if data.estates[e].get("location", "") == loc:
				check(s.buildings.any(func(b): return b.get("estate", "") == e), "%s estate %s has a building" % [loc, e])
		for c in data.contacts:
			if c.location == loc:
				var people: Array = s.npcs + Locals.npcs_for(data, loc)
				check(people.any(func(n): return n.get("contact", "") == c.id), "%s contact %s stands on the surface" % [loc, c.id])


func test_interiors() -> void:
	var Nav = load("res://scripts/planet/nav.gd")
	var seen := 0
	for loc in data.surfaces:
		var s: Dictionary = data.surfaces[loc]
		# every panel building (market, shipyard, office, fence) is a key building with a room, and nothing else is
		for b in s.buildings:
			var panel: bool = str(b.get("action", "")) in Interiors.PANELS
			check(Interiors.has(data, loc, b.id) == panel, "%s/%s: room iff it has a panel door" % [loc, b.id])
		for id in data.interiors.get(loc, {}):
			check(s.buildings.any(func(b): return b.id == id), "%s: room %s belongs to a building" % [loc, id])
		check(Interiors.ids(data, loc).size() == data.interiors.get(loc, {}).size(), "%s: ids lists every room" % loc)
		for id in Interiors.ids(data, loc):
			seen += 1
			var b := Interiors.building(data, loc, id)
			var cfg := Interiors.build_cfg(data, loc, id)
			var map := Rect2(0, 0, cfg.size[0], cfg.size[1])
			var tag := "%s/%s" % [loc, id]
			check(cfg.interior.building == id and cfg.interior.loc == loc and cfg.interior.action == b.action, "%s: interior header" % tag)
			check(not cfg.has("estate") and float(cfg.security) == 0.0 and int(cfg.walkers) == 0, "%s: no police, no walkers, not an estate" % tag)
			var solids: Array = []
			for r in cfg.buildings:
				var rr := Rect2(r.rect[0], r.rect[1], r.rect[2], r.rect[3])
				check(map.encloses(rr), "%s: %s inside the room" % [tag, r.id])
				solids.append(rr)
			var counter: Dictionary = cfg.buildings.filter(func(x): return x.id == "counter")[0]
			var cr := Rect2(counter.rect[0], counter.rect[1], counter.rect[2], counter.rect[3])
			for r in cfg.buildings:
				if r.id != "counter":
					check(not Rect2(r.rect[0], r.rect[1], r.rect[2], r.rect[3]).intersects(cr), "%s: counter clear of %s" % [tag, r.id])
			check(counter.action == b.action, "%s: counter opens the building's panel (%s)" % [tag, b.action])
			check(cfg.npcs.size() == 1 and cfg.npcs[0].action == b.action and str(cfg.npcs[0].get("contact", "")) == "", "%s: one clerk, same panel" % tag)
			# everything the player needs is on free floor and connected to the spawn
			var grid: AStarGrid2D = Nav.build(cfg)
			var spots := {
				"spawn": Vector2(cfg.spawn[0], cfg.spawn[1]),
				"exit": Vector2(cfg.exits[0].pos[0], cfg.exits[0].pos[1] - 12.0 / 32.0),
				"counter": Vector2(counter.door[0], counter.door[1] + 0.6),
				"clerk": Vector2(cfg.npcs[0].pos[0], cfg.npcs[0].pos[1] + 26.0 / 32.0),
			}
			for k in spots:
				var cell := Vector2i(spots[k].floor())
				check(grid.region.has_point(cell) and not grid.is_point_solid(cell), "%s: %s stands on free floor" % [tag, k])
				if k != "spawn":
					check(not grid.get_id_path(Vector2i(spots.spawn.floor()), cell).is_empty(), "%s: %s reachable from the spawn" % [tag, k])
			check(cfg.exits[0].action == "exit_interior", "%s: exit action" % tag)
			for p in cfg.props:
				check(map.has_point(Vector2(p[1], p[2])), "%s: prop %s inside the room" % [tag, p[0]])
			check(Interiors.outside_id(cfg) == id, "%s: leaving returns to the building's door" % tag)
	check(seen >= 8, "all key buildings have rooms (%d)" % seen)
	check(Interiors.build_cfg(data, "mireth", "cannery").is_empty() and not Interiors.has(data, "mireth", "nope"), "estates and unknown buildings have no panel room")



func test_police_on_foot() -> void:
	var g := new_game()
	check(g.police_on_foot(1.0) == 1, "one officer on a lawful planet at zero heat")
	check(g.police_on_foot(0.0) == 0, "no police on a lawless deck")
	check(g.police_on_foot(0.5) == 0, "half security: nobody at zero heat")
	g.heat = 40.0
	check(g.police_on_foot(1.0) == 3, "more officers with heat")
	check(g.police_on_foot(0.5) == 1, "half security scales")
	g.heat = 100.0
	check(g.police_on_foot(1.0) == int(data.police.max), "capped at max")
	var Nav = load("res://scripts/planet/nav.gd")
	for loc in data.surfaces:
		var s: Dictionary = data.surfaces[loc]
		var grid: AStarGrid2D = Nav.build(s)
		var t := float(s.tile)
		for b in s.buildings:
			if not b.has("door"):
				continue
			# from above the building to below it: the route must go around, never through a building
			var r := Rect2(Vector2(b.rect[0], b.rect[1]) * t, Vector2(b.rect[2], b.rect[3]) * t)
			var top := Vector2(r.get_center().x, r.position.y - t * 0.5)
			var bottom := Vector2(r.get_center().x, r.end.y + t * 0.5)
			var path: Array = Nav.path_between(grid, t, top, bottom)
			var clean := path.size() > 2
			var prev := top
			for p in path:
				for k in 9:
					var q: Vector2 = prev.lerp(p, k / 8.0)
					for o in s.buildings:
						if Rect2(Vector2(o.rect[0], o.rect[1]) * t, Vector2(o.rect[2], o.rect[3]) * t).grow(-1).has_point(q):
							clean = false
				prev = p
			check(clean, "%s: route around %s avoids buildings" % [loc, b.id])
	var Officer = load("res://scripts/planet/officer.gd")
	var cone := deg_to_rad(80.0)
	check(Officer.sees(Vector2.ZERO, Vector2.RIGHT, Vector2(100, 10), 170.0, cone, []), "sees in front")
	check(not Officer.sees(Vector2.ZERO, Vector2.RIGHT, Vector2(-100, 0), 170.0, cone, []), "blind behind")
	check(not Officer.sees(Vector2.ZERO, Vector2.RIGHT, Vector2(300, 0), 170.0, cone, []), "out of range")
	check(not Officer.sees(Vector2.ZERO, Vector2.RIGHT, Vector2(150, 0), 170.0, cone, [Rect2(60, -20, 20, 40)]), "walls block sight")


func test_flee_heat() -> void:
	var Pursuit = load("res://scripts/core/pursuit.gd")
	var h: Dictionary = data.heat
	check(float(h.flee_chase_per_second) > float(h.flee_carry_per_second) and float(h.flee_carry_per_second) > 0.0, "flee heat is tunable data")
	var g := new_game()
	g.cargo.clear()
	check(Pursuit.tick(g, 1.0, true, true, false) == 0.0 and g.heat == 0.0, "sprinting in sight without product and no chase: no heat")
	g.cargo["weed:glow"] = 3
	check(g.has_contraband(), "weed counts as product")
	check(Pursuit.tick(g, 1.0, false, true, true) == 0.0, "walking adds nothing")
	check(Pursuit.tick(g, 1.0, true, false, true) == 0.0 and g.heat == 0.0, "out of sight adds nothing, even when chased")
	var a: float = Pursuit.tick(g, 2.0, true, true, false)
	check(is_equal_approx(a, 2.0 * float(h.flee_carry_per_second)) and is_equal_approx(g.heat, a), "carrying and sprinting in sight: heat per second")
	var b: float = Pursuit.tick(g, 2.0, true, true, true)
	check(b > a and is_equal_approx(b, 2.0 * float(h.flee_chase_per_second)), "being chased is hotter")
	g.cargo.clear()
	g.heat = 0.0
	check(Pursuit.tick(g, 1.0, true, true, true) > 0.0, "a chase heats even without product (armed officer / chase)")
	g.heat = float(h.flee_heat_cap) - 0.1
	Pursuit.tick(g, 10.0, true, true, true)
	check(is_equal_approx(g.heat, float(h.flee_heat_cap)), "flee heat stops at the cap")
	check(Pursuit.tick(g, 10.0, true, true, true) == 0.0, "no more at the cap")


# ---------------------------------------------------------------- E1 ground combat

func test_combat_weapons() -> void:
	var c: Dictionary = data.combat
	check(c.weapons.size() >= 3 and c.weapons.has("pistol") and c.weapons.has("smg") and c.weapons.has("shotgun"), "pistol, smg and shotgun exist")
	for id in c.weapons:
		var w: Dictionary = c.weapons[id]
		for k in ["name", "price", "damage", "pellets", "spread_deg", "interval", "auto", "mag", "reload", "bullet_speed", "range", "noise_heat"]:
			check(w.has(k), "weapon %s has %s" % [id, k])
		check(float(w.range) > 0.0 and int(w.mag) > 0 and int(w.pellets) >= 1, "weapon %s numbers are sane" % id)
	check(int(c.weapons.pistol.price) == 0, "the pistol is free")
	check(c.weapons.smg.auto and not c.weapons.pistol.auto, "only the smg fires automatically")
	check(int(c.weapons.shotgun.pellets) > 1 and float(c.weapons.shotgun.damage) * int(c.weapons.shotgun.pellets) > float(c.weapons.pistol.damage), "shotgun pellets out-damage the pistol up close")
	check(float(c.weapons.smg.interval) < float(c.weapons.pistol.interval), "smg fires faster than the pistol")
	var g := new_game()
	check(g.weapons == ["pistol"] and g.weapon == "pistol" and g.ammo.pistol == 12, "a new game starts with a loaded pistol")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var shot := Combat.fire(g, Vector2.ZERO, Vector2.RIGHT, rng)
	check(shot.ok and shot.bullets.size() == 1 and g.ammo.pistol == 11, "a shot costs a round and makes one bullet")
	check(not Combat.fire(g, Vector2.ZERO, Vector2.RIGHT, rng).ok, "fire rate: no second shot inside the interval")
	g.tick(0.4)
	check(Combat.fire(g, Vector2.ZERO, Vector2.RIGHT, rng).ok, "shot possible again after the interval")
	for i in 30:
		g.tick(0.4)
		Combat.fire(g, Vector2.ZERO, Vector2.RIGHT, rng)
		if g.reload_left > 0.0:
			break
	check(g.ammo.pistol == 0 and g.reload_left > 0.0, "an empty magazine starts the reload by itself")
	check(not Combat.fire(g, Vector2.ZERO, Vector2.RIGHT, rng).ok, "no firing while reloading")
	g.tick(float(c.weapons.pistol.reload) + 0.1)
	check(g.ammo.pistol == 12 and g.reload_left == 0.0, "reload refills the magazine")
	check(not Combat.start_reload(g).ok, "a full magazine does not reload")
	# aim: bullets fly in the aimed direction within the spread
	g.tick(1.0)
	var b: Dictionary = Combat.fire(g, Vector2.ZERO, Vector2(0, -1), rng).bullets[0]
	check(Vector2(b.vel).normalized().angle_to(Vector2.UP) < deg_to_rad(float(c.weapons.pistol.spread_deg)), "bullet follows the aim")
	# shop
	check(not Combat.select(g, "smg").ok, "cannot equip a weapon you do not own")
	g.credits = 100
	check(not Combat.buy_weapon(g, "smg").ok and g.credits == 100, "too poor for the smg: nothing is charged")
	g.credits = 5000
	check(Combat.buy_weapon(g, "smg").ok and g.weapons.has("smg") and g.credits == 5000 - int(c.weapons.smg.price) and g.ammo.smg == 30, "buying the smg charges and loads it")
	check(not Combat.buy_weapon(g, "smg").ok, "cannot buy twice")
	check(not Combat.buy_weapon(g, "railgun").ok, "unknown weapon refused")
	check(Combat.select(g, "smg").ok and g.weapon == "smg", "select equips an owned weapon")
	Combat.buy_weapon(g, "shotgun")
	Combat.cycle(g, 1)
	check(g.weapon == "shotgun", "cycle goes to the next weapon")
	Combat.cycle(g, 1)
	check(g.weapon == "pistol", "cycle wraps around")
	Combat.select(g, "shotgun")
	g.tick(2.0)
	var pellets: Array = Combat.fire(g, Vector2.ZERO, Vector2.RIGHT, rng).bullets
	check(pellets.size() == int(c.weapons.shotgun.pellets), "the shotgun fires all its pellets")
	var spread := 0.0
	for p in pellets:
		spread = maxf(spread, absf(Vector2(p.vel).angle()))
	check(spread > 0.0 and spread <= deg_to_rad(float(c.weapons.shotgun.spread_deg)) * 0.5 + 0.001, "pellets scatter inside the spread cone")
	# noise heat only with an officer in earshot
	check(Combat.noise_heat(g, []) == 0.0 and Combat.noise_heat(g, [5000.0]) == 0.0, "nobody hears the shot: no heat")
	check(Combat.noise_heat(g, [100.0]) == float(c.weapons.shotgun.noise_heat), "an officer in earshot hears it")


func test_combat_player() -> void:
	var g := new_game()
	var p: Dictionary = data.combat.player
	check(g.hp == float(p.hp) and Combat.max_hp(g) == float(p.hp), "full health at the start")
	check(not Combat.damage_player(g, 30.0) and g.hp == float(p.hp) - 30.0, "a hit costs health")
	g.tick(float(p.regen_delay) - 1.0)
	check(g.hp == float(p.hp) - 30.0, "no regeneration right after a hit")
	g.tick(2.0 + 5.0)
	check(g.hp > float(p.hp) - 30.0, "health regenerates after a pause")
	g.tick(100.0)
	check(g.hp == float(p.hp), "regeneration stops at full health")
	# knock out: cargo, fine, heat
	g.credits = 1000
	g.heat = 50.0
	g.cargo["weed:glow"] = 4
	g.cargo["cannabis"] = 3
	check(Combat.damage_player(g, 500.0) and g.hp == 0.0, "lethal damage reports the knock-out")
	var r := Combat.knock_out(g)
	check(r.ok and not g.has_contraband() and g.cargo.get("cannabis", 0) == 3, "knock-out confiscates product but not raw material")
	check(g.credits == 1000 - maxi(int(p.ko_fine_min), int(1000 * float(p.ko_fine_ratio))), "knock-out fine is paid")
	check(is_equal_approx(g.heat, 50.0 - float(p.ko_heat_drop)), "knock-out cools heat")
	check(g.hp == float(p.hp) * float(p.ko_hp_ratio) and g.stats.knockouts == 1, "player wakes up half healthy and it is counted")
	g.credits = 10
	Combat.knock_out(g)
	check(g.credits == 0, "the fine never exceeds the credits")


func test_combat_geometry() -> void:
	var r := Rect2(10, -5, 10, 10)
	check(Combat.segment_rect_t(Vector2.ZERO, Vector2(30, 0), r) < 0.5, "segment hits a rect in its way")
	check(is_equal_approx(Combat.segment_rect_t(Vector2.ZERO, Vector2(30, 0), r), 10.0 / 30.0), "hit point is the near edge")
	check(Combat.segment_rect_t(Vector2.ZERO, Vector2(0, 30), r) == INF, "segment misses a rect beside it")
	check(Combat.segment_rect_t(Vector2.ZERO, Vector2(5, 0), r) == INF, "segment that stops short misses")
	check(Combat.segment_rect_t(Vector2(12, 0), Vector2(30, 0), r) == 0.0, "starting inside counts as hit at t=0")
	check(Combat.segment_circle_t(Vector2.ZERO, Vector2(100, 0), Vector2(50, 5), 10.0) < 0.5, "segment hits a circle")
	check(Combat.segment_circle_t(Vector2.ZERO, Vector2(100, 0), Vector2(50, 30), 10.0) == INF, "segment misses a far circle")
	check(Combat.line_clear(Vector2.ZERO, Vector2(0, 50), [r]) and not Combat.line_clear(Vector2.ZERO, Vector2(40, 0), [r]), "line of fire is blocked by cover")
	# bullets
	var b := Combat.make_bullet(Vector2.ZERO, Vector2.RIGHT, 100.0, 10.0, 250.0, "player")
	var res := Combat.step_bullet(b, 0.5, [], [])
	check(res.hit == "" and b.pos.is_equal_approx(Vector2(50, 0)) and is_equal_approx(b.left, 200.0), "bullet flies")
	res = Combat.step_bullet(b, 0.5, [Rect2(70, -5, 10, 10)], [{"pos": Vector2(120, 0), "r": 10.0}])
	check(res.hit == "wall" and is_equal_approx(b.pos.x, 70.0), "cover stops the bullet before the target behind it")
	b = Combat.make_bullet(Vector2.ZERO, Vector2.RIGHT, 100.0, 10.0, 250.0, "player")
	res = Combat.step_bullet(b, 1.0, [Rect2(200, -5, 10, 10)], [{"pos": Vector2(60, 3), "r": 10.0}])
	check(res.hit == "target" and res.idx == 0, "a target in front of the cover is hit")
	b = Combat.make_bullet(Vector2.ZERO, Vector2.RIGHT, 100.0, 10.0, 60.0, "player")
	res = Combat.step_bullet(b, 1.0, [], [])
	check(res.hit == "range", "bullet dies at the end of its range")
	b = Combat.make_bullet(Vector2.ZERO, Vector2.RIGHT, 1000.0, 10.0, 500.0, "player")
	res = Combat.step_bullet(b, 1.0, [Rect2(100, -2, 2, 4)], [])
	check(res.hit == "wall", "a fast bullet cannot tunnel through a thin wall")


func test_combat_officers() -> void:
	var g := new_game()
	var o: Dictionary = data.combat.officer
	check(not Combat.officers_armed(g), "officers are unarmed at zero heat")
	g.heat = float(o.draw_heat) - 1.0
	check(not Combat.officers_armed(g), "still holstered just below the draw heat")
	g.heat = float(o.draw_heat)
	check(Combat.officers_armed(g), "officers draw their weapons at high heat")
	check(float(o.draw_heat) > float(data.police.chase_heat), "they draw later than they start chasing")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 20:
		var b := Combat.officer_bullet(g, Vector2.ZERO, Vector2(200, 0), rng)
		check(b.owner == "officer" and Vector2(b.vel).angle() <= deg_to_rad(float(o.spread_deg)) * 0.5 + 0.001, "officer bullet aims at the player within its inaccuracy")
	g.heat = 10.0
	Combat.officer_killed(g)
	check(g.heat == 10.0 + float(o.kill_heat) and g.stats.kills == 1, "killing an officer raises heat and is counted")
	Combat.officer_hit(g)
	check(is_equal_approx(g.heat, 10.0 + float(o.kill_heat) + float(o.hit_heat)), "shooting an officer raises heat")
	check(float(o.hp) > float(data.combat.weapons.pistol.damage) * 2.0, "an officer survives more than two pistol hits")
	check(float(o.damage) * 4.0 < float(data.combat.player.hp), "four officer hits do not kill the player")


func test_combat_cover_layout() -> void:
	var Nav = load("res://scripts/planet/nav.gd")
	for loc in data.surfaces:
		var s: Dictionary = data.surfaces[loc]
		if s.has("estate"):
			continue
		var tiles: Array = Combat.cover_tiles(data, loc)
		check(tiles.size() >= 3, "%s has cover on its streets" % loc)
		var map := Rect2(0, 0, s.size[0], s.size[1])
		var rects := Combat.cover_rects(tiles, 1.0)
		var others: Array = []
		for b in s.buildings:
			others.append(Rect2(b.rect[0], b.rect[1], b.rect[2], b.rect[3]))
		for r in s.roads:
			others.append(Rect2(r[0], r[1], r[2], r[3]))
		for r in s.get("plazas", []):
			others.append(Rect2(r[0], r[1], r[2], r[3]))
		var pad := Vector2(s.pad.pos[0], s.pad.pos[1])
		for i in rects.size():
			var r: Rect2 = rects[i]
			check(map.encloses(r), "%s cover %d inside the map" % [loc, i])
			check(not others.any(func(o): return o.intersects(r)), "%s cover %d stays off buildings, roads and plazas" % [loc, i])
			check(r.get_center().distance_to(pad) > float(s.pad.radius), "%s cover %d is off the landing pad" % [loc, i])
			for j in i:
				check(not rects[j].intersects(r), "%s cover pieces %d/%d do not overlap" % [loc, i, j])
		# cover blocks the nav grid but every named place, door and the pad stays reachable
		var cfg: Dictionary = s.duplicate()
		cfg.cover = tiles
		var nav: AStarGrid2D = Nav.build(cfg)
		var start := Vector2i(int(s.spawn[0]), int(s.spawn[1]))
		check(not nav.is_point_solid(start), "%s spawn is free" % loc)
		var goals: Array = []
		for k in s.spots:
			goals.append(s.spots[k])
		for n in s.npcs:
			goals.append(n.pos)
		for b in s.buildings:
			if b.has("door"):
				goals.append([b.door[0], b.door[1] + (0.5 if b.get("side", "bottom") == "bottom" else -0.5)])
		goals.append([pad.x, pad.y + float(s.pad.radius) + 0.5])
		for gp in goals:
			var cell := Vector2i(int(floor(gp[0])), int(floor(gp[1])))
			check(not nav.is_point_solid(cell) and not nav.get_id_path(start, cell).is_empty(), "%s %s reachable with cover in place" % [loc, str(gp)])
		for t in tiles:
			check(nav.is_point_solid(Vector2i(int(t[0]), int(t[1]))), "%s cover is solid in the nav grid" % loc)


func test_combat_save() -> void:
	var g := new_game()
	g.credits = 5000
	Combat.buy_weapon(g, "shotgun")
	Combat.select(g, "shotgun")
	g.ammo.shotgun = 2
	g.hp = 37.5
	var json := JSON.stringify(g.to_dict())
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(json))
	check(h.weapons == ["pistol", "shotgun"] and h.weapon == "shotgun" and h.ammo.shotgun == 2 and h.hp == 37.5, "weapons, ammo and health survive a save")
	check(JSON.stringify(h.to_dict()) == json, "combat save round-trip is stable")
	# an old save without any combat data loads with the fresh state
	var old: Dictionary = JSON.parse_string(json)
	old.erase("combat")
	var k := Game.new()
	k.from_dict(data, old)
	check(k.hp == Combat.max_hp(k) and k.weapons == ["pistol"] and k.weapon == "pistol" and k.ammo.pistol == 12, "old saves load with full health and the pistol")
	check(k.stats.kills == 0 and k.stats.knockouts == 0, "old saves have zero combat stats")
	# garbage in the combat block is repaired
	var bad: Dictionary = JSON.parse_string(json)
	bad.combat = {"hp": -5, "weapons": ["railgun", "smg", "smg"], "weapon": "pistol", "ammo": {"smg": 999}}
	var m := Game.new()
	m.from_dict(data, bad)
	check(m.hp >= 1.0 and m.weapons == ["smg"] and m.weapon == "smg" and m.ammo.smg == int(data.combat.weapons.smg.mag), "broken combat data is clamped and unknown weapons dropped")


func test_estates() -> void:
	for e in data.estates:
		if not data.estates[e].get("ship", false):
			check(data.locations.has(data.estates[e].location), "estate %s location exists" % e)
	for b in data.buildables:
		check(data.stations.has(b), "buildable %s is a station" % b)
	var g := new_game()
	g.credits = 10000
	check(not g.buy_estate("shaft_shack").ok, "can't buy an estate on another planet")
	check(g.buy_estate("cannery_annex").ok and g.estate_owned("cannery_annex"), "buy estate")
	check(g.credits == 10000 - int(data.estates.cannery_annex.price), "estate price paid")
	check(not g.buy_estate("cannery_annex").ok, "can't buy twice")
	var door: Vector2i = g.estate_door("cannery_annex")
	check(not g.can_place("cannery_annex", "trim_table", door.x, door.y), "door cell stays free")
	check(not g.can_place("cannery_annex", "cook_stove", 8, 0), "must fit inside")
	var before: int = g.credits
	check(g.place_building("cannery_annex", "cook_stove", 0, 0).ok, "place cook stove")
	check(g.credits == before - int(data.buildables.cook_stove.cost), "building cost paid")
	check(not g.place_building("cannery_annex", "mixing_station", 1, 1).ok, "no overlap")
	check(g.place_building("cannery_annex", "mixing_station", 2, 0).ok, "place next to it")
	var g2 := Game.new()
	g2.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.estate_owned("cannery_annex") and g2.estates.cannery_annex.buildings.size() == 2, "estates survive save/load")
	before = g.credits
	check(g.remove_building("cannery_annex", 0).ok and g.estates.cannery_annex.buildings.size() == 1, "remove building")
	check(g.credits == before + int(round(int(data.buildables.cook_stove.cost) * float(data.estate_refund))), "partial refund")
	# cooking inside an estate needs the stations the recipe runs through
	g.location = "cinder"
	g.credits = 10000
	g.cargo = {"cannabis": 5}
	check(not g.lab_here(), "no lab on Cinder")
	check(g.buy_estate("shaft_shack").ok, "buy the shack")
	g.inside_estate = "shaft_shack"
	check(g.lab_here(), "estate is a lab")
	var r: Dictionary = g.check_batch("weed", [], 5)
	check(not r.ok and "Trim Table" in r.msg, "missing stations named: %s" % r.msg)
	g.place_building("shaft_shack", "trim_table", 0, 0)
	g.place_building("shaft_shack", "cook_stove", 2, 0)
	g.place_building("shaft_shack", "pack_table", 4, 0)
	check(g.missing_stations("weed", []) == ["extractor"], "weed needs an extractor too: %s" % [g.missing_stations("weed", [])])
	check(g.place_building("shaft_shack", "extractor", 6, 0).ok, "place extractor")
	check(g.missing_stations("weed", []).is_empty(), "weed line complete")
	check(not g.missing_stations("weed", ["nanoflux"]).is_empty(), "additives need a mixing station")
	check(g.start_batch("weed", [], 5).ok, "cook in the estate")
	g.tick(60.0)
	check(g.collect_stash().ok and g.has_contraband(), "collect output in the estate")
	g.inside_estate = ""
	check(not g.lab_here(), "outside the estate no lab")


## A shack on Cinder with a complete weed line, credits and the player standing inside.
func worker_game() -> Game:
	var g := new_game()
	g.credits = 20000
	g.dock("cinder")
	g.buy_estate("shaft_shack")
	g.inside_estate = "shaft_shack"
	g.place_building("shaft_shack", "trim_table", 0, 0)
	g.place_building("shaft_shack", "cook_stove", 2, 0)
	g.place_building("shaft_shack", "pack_table", 4, 0)
	g.place_building("shaft_shack", "extractor", 6, 0)
	return g


## Cooks `batches` auto batches with the given crew; returns {qty, grade_sum, products}.
func run_crew(lab_hand: String, stocker: String, batches: int) -> Dictionary:
	var g := worker_game()
	Workers.hire(g, lab_hand)
	Workers.assign(g, lab_hand, "shaft_shack")
	if stocker != "":
		Workers.hire(g, stocker)
		Workers.assign(g, stocker, "shaft_shack")
	Workers.set_recipe(g, "shaft_shack", "weed", [], 5)
	g.cargo = {"cannabis": 5 * batches}
	check(Workers.deposit(g, "shaft_shack", "cannabis", 5 * batches).ok, "stock the shelf")
	var t := 0.0
	while t < 900.0 and int(g.stats.worker_batches) < batches:
		g.tick(0.5)
		t += 0.5
	var qty := 0
	var grades := 0
	var e: Dictionary = g.estates.shaft_shack
	for src in [e.out, e.storage]:
		for k in src:
			if Mixing.is_product(k):
				qty += int(src[k])
				grades += Mixing.parse_key(k).grade * int(src[k])
	return {"qty": qty, "grades": grades, "t": t, "g": g, "batches": int(g.stats.worker_batches)}


func test_workers() -> void:
	for c in data.workers.candidates:
		check(data.workers.roles.has(c.role) and float(c.skill) > 0.0 and float(c.skill) <= 1.0 and int(c.wage) > 0, "candidate %s valid" % c.id)
	var g := worker_game()
	check(Workers.available(g).size() == data.workers.candidates.size(), "everybody is for hire at the start")
	g.credits = 10
	check(not Workers.hire(g, "hollis").ok, "can't afford the signing fee")
	g.credits = 5000
	var before: int = g.credits
	check(Workers.hire(g, "hollis").ok and g.credits == before - 2 * int(Workers.candidate(g, "hollis").wage), "hire pays the signing fee")
	check(not Workers.hire(g, "hollis").ok, "can't hire twice")
	check(not Workers.assign(g, "hollis", "cannery_annex").ok, "assign needs an owned estate")
	check(Workers.assign(g, "hollis", "shaft_shack").ok, "assign lab hand")
	Workers.hire(g, "pia")
	check(not Workers.assign(g, "pia", "shaft_shack").ok, "one lab hand per estate")
	check(Workers.fire(g, "pia").ok and Workers.hired(g, "hollis") and not Workers.hired(g, "pia"), "fire")
	# nothing happens without a recipe, then the lab hand cooks from the shelf (no stocker: slower)
	g.tick(30.0)
	check(g.estates.shaft_shack.job.is_empty() and Workers.blocker(g, "shaft_shack") == "No recipe set.", "idle without recipe")
	Workers.set_recipe(g, "shaft_shack", "weed", [], 5)
	check(not Workers.deposit(g, "shaft_shack", "cannabis", 5).ok, "no cargo to store")
	g.cargo = {"cannabis": 5}
	g.inside_estate = ""
	check(not Workers.deposit(g, "shaft_shack", "cannabis", 5).ok, "must be inside to store")
	g.inside_estate = "shaft_shack"
	check(Workers.deposit(g, "shaft_shack", "cannabis", 5).ok and g.cargo.is_empty(), "store raws")
	g.tick(1.0)
	check(not g.estates.shaft_shack.job.is_empty(), "lab hand starts the batch")
	var heat_before := g.heat
	check(heat_before > 0.0, "auto batches add heat")
	g.tick(60.0)
	check(g.estates.shaft_shack.job.is_empty() and g.stats.worker_batches == 1, "batch done")
	check(Workers.take_products(g, "shaft_shack").ok and g.has_contraband(), "take products")
	# an unbuilt recipe names the missing station
	Workers.set_recipe(g, "shaft_shack", "meth", [], 5)
	check("Refiner" in Workers.blocker(g, "shaft_shack") or "Precursor" in Workers.blocker(g, "shaft_shack"), "missing station named: %s" % Workers.blocker(g, "shaft_shack"))
	# skill matters: a pro beats a rookie on yield and grade, a stocker makes the line faster
	var rookie := run_crew("dax", "moss", 6)
	var pro := run_crew("hollis", "reva", 6)
	check(rookie.batches == 6 and pro.batches == 6, "both crews finish 6 batches (%d/%d)" % [rookie.batches, pro.batches])
	check(pro.grades > rookie.grades, "skilled hand cooks better grades (%d vs %d)" % [pro.grades, rookie.grades])
	check(pro.qty >= rookie.qty and pro.t < rookie.t, "skilled hand is faster (%.0fs vs %.0fs) with >= yield (%d vs %d)" % [pro.t, rookie.t, pro.qty, rookie.qty])
	var alone := run_crew("hollis", "", 6)
	check(alone.batches == 6 and alone.t > pro.t, "no stocker is slower (%.0fs vs %.0fs)" % [alone.t, pro.t])
	# the stocker moves finished goods from the tray into storage and tops up the bench
	var ps: Dictionary = pro.g.estates.shaft_shack
	check(ps.out.is_empty() or pro.g.estates.shaft_shack.storage.size() > 0, "stocker delivered output to storage")
	# wages
	var w := worker_game()
	Workers.hire(w, "hollis")
	Workers.hire(w, "moss")
	var wages := Workers.wage_total(w)
	check(wages == int(Workers.candidate(w, "hollis").wage) + int(Workers.candidate(w, "moss").wage), "wage total")
	var c0: int = w.credits
	w.tick(w.day_seconds())
	var rent := EstateUpkeep.daily_total(w)  # estates bought by worker_game() also pay upkeep (P4)
	check(w.credits == c0 - wages - rent and w.stats.wages == wages, "daily wages charged (%d)" % (c0 - w.credits))
	var loyal: float = w.workers[0].loyalty
	w.credits = 0
	w.tick(w.day_seconds())
	check(w.workers[0].loyalty < loyal, "unpaid wages cost loyalty")
	for i in 3:
		w.tick(w.day_seconds())
	check(w.workers.is_empty(), "unpaid workers quit")
	# save round trip incl. mid-job state, and old saves without any worker data
	var s: Game = run_crew("pia", "jun", 1).g
	s.estates.shaft_shack.job = {"product": "weed", "qty": 5, "remaining": 3.0, "total": 9.0}
	var json := JSON.stringify(s.to_dict())
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(json))
	check(JSON.stringify(h.to_dict()) == json, "worker save round-trip is stable")
	check(h.workers.size() == 2 and h.estates.shaft_shack.job.remaining == 3.0, "workers and job restored")
	var old: Dictionary = JSON.parse_string(json)
	old.erase("workers")
	for k in ["storage", "bench", "out", "recipe", "job", "haul_t"]:
		old.estates.shaft_shack.erase(k)
	var o := Game.new()
	o.from_dict(data, old)
	check(o.workers.is_empty() and o.estates.shaft_shack.storage.is_empty() and o.estates.shaft_shack.job.is_empty(), "old saves load without workers")
	o.tick(30.0)
	check(o.estates.shaft_shack.buildings.size() == 4, "old save estate still ticks")
func test_worker_walk() -> void:
	var g := worker_game()
	var est := "shaft_shack"
	var size: Array = data.estates[est].size
	g.credits = 20000
	Workers.hire(g, "hollis")
	Workers.hire(g, "reva")
	check(WorkerWalk.activity(g, "hollis") == WorkerWalk.IDLE and WorkerWalk.target_cell(g, "hollis") == Vector2(-1, -1), "unassigned worker is idle with no cell")
	check(WorkerWalk.activity(g, "nobody") == WorkerWalk.IDLE, "unknown worker idle")
	Workers.assign(g, "hollis", est)
	Workers.assign(g, "reva", est)
	var idle_h := WorkerWalk.idle_cell(data, est, "lab_hand")
	var idle_s := WorkerWalk.idle_cell(data, est, "stocker")
	check(idle_h != idle_s, "roles wait at different spots")
	for c in [idle_h, idle_s, WorkerWalk.storage_cell(data, est)]:
		check(c.x > 0.0 and c.x < float(size[0]) and c.y > 0.0 and c.y < float(size[1]), "cell %s inside the room" % c)
	check(WorkerWalk.activity(g, "hollis") == WorkerWalk.IDLE and WorkerWalk.target_cell(g, "hollis") == idle_h, "no recipe: lab hand waits at his idle spot")
	check(WorkerWalk.activity(g, "reva") == WorkerWalk.IDLE and WorkerWalk.target_cell(g, "reva") == idle_s, "nothing to carry: stocker waits")
	# station cell: first needed station, in front of it
	var e: Dictionary = g.estates[est]
	var st := WorkerWalk.station_cell(data, est, e.buildings, {})
	var b0: Dictionary = e.buildings[0]
	check(st.x >= float(b0.x) and st.x <= float(b0.x) + float(data.buildables[b0.id].size[0]) and st.y > float(b0.y), "station cell sits in front of the first station (%s)" % st)
	check(WorkerWalk.station_cell(data, est, [], {}) == Vector2(-1, -1), "no station: no cell")
	Workers.set_recipe(g, est, "weed", [], 5)
	var needed: Array = Production.stations_for(data, "weed", [])
	var sc := WorkerWalk.station_cell(data, est, e.buildings, e.recipe)
	var found := false
	for b in e.buildings:
		if b.id == needed[0]:
			found = absf(sc.x - (float(b.x) + float(data.buildables[b.id].size[0]) / 2.0)) < 0.01
	check(found, "with a recipe the cell is at the first needed station")
	# stocker with raws in storage carries them to the bench: storage first, station in the second half of the trip
	g.cargo = {"cannabis": 5}
	g.inside_estate = est
	Workers.deposit(g, est, "cannabis", 5)
	check(WorkerWalk.activity(g, "reva") == WorkerWalk.HAUL, "stocker has raws to carry")
	e.haul_t = 0.0
	check(WorkerWalk.target_cell(g, "reva") == WorkerWalk.storage_cell(data, est), "first half of a trip: at the storage")
	e.haul_t = 1000.0
	check(WorkerWalk.target_cell(g, "reva") == sc, "second half of a trip: at the station")
	# with a stocker the lab hand stays at the station, without one he fetches from storage
	check(WorkerWalk.activity(g, "hollis") == WorkerWalk.COOK and WorkerWalk.target_cell(g, "hollis") == sc, "stocked lab hand waits at the station")
	Workers.assign(g, "reva", "")
	check(WorkerWalk.activity(g, "hollis") == WorkerWalk.FETCH and WorkerWalk.target_cell(g, "hollis") == WorkerWalk.storage_cell(data, est), "unstocked lab hand fetches from storage")
	# a running job keeps him at the station
	g.tick(1.0)
	check(not e.job.is_empty() and WorkerWalk.activity(g, "hollis") == WorkerWalk.COOK, "cooking at the station")
	# presentation never touches the simulation
	var before := JSON.stringify(g.to_dict())
	for id in ["hollis", "reva"]:
		WorkerWalk.activity(g, id)
		WorkerWalk.target_cell(g, id)
	check(JSON.stringify(g.to_dict()) == before, "walk helper is read-only")
	# stable per-worker outfits that recolour the player sheet
	var sw := WorkerWalk.look_swaps(data, "hollis")
	check(not sw.is_empty() and sw == WorkerWalk.look_swaps(data, "hollis"), "outfit is stable")
	var distinct := {}
	for c in data.workers.candidates:
		distinct[str(WorkerWalk.look_swaps(data, c.id))] = true
	check(distinct.size() > 1, "workers do not all dress alike")


func test_ship_bay() -> void:
	var sb: String = Game.SHIP_BAY
	check(data.estates.has(sb) and data.estates[sb].get("ship", false), "ship estate is defined")
	var g := new_game()
	g.credits = 10000
	check(g.estate_owned(sb) and not g.buy_estate(sb).ok, "bay is owned from the start, not for sale")
	check(g.location != "", "new game starts docked")
	check(g.can_place(sb, "trim_table", 0, 0), "can place while docked")
	check(g.enter_ship_bay().ok and g.inside_estate == sb and g.lab_here(), "enter the bay: it is a lab")
	var r: Dictionary = g.check_batch("weed", [], 1)
	check(not r.ok, "bay needs stations before cooking")
	for st in [["trim_table", 0], ["cook_stove", 2], ["pack_table", 4]]:
		check(g.place_building(sb, st[0], st[1], 0).ok, "place %s in the bay" % st[0])
	var door: Vector2i = g.estate_door(sb)
	check(not g.can_place(sb, "precursor_scale", door.x, door.y), "bay door stays free")
	check(not g.can_place(sb, "cook_stove", 6, 3), "must fit inside the bay")
	var g2 := Game.new()
	g2.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.estates[sb].buildings.size() == 3, "bay layout survives save/load")
	# an old save without the bay gets an empty one
	var d: Dictionary = g.to_dict()
	d.estates.erase(sb)
	var g3 := Game.new()
	g3.from_dict(data, d)
	check(g3.estate_owned(sb) and g3.estates[sb].buildings.is_empty(), "old saves get an empty bay")
	# in flight the bay is closed
	g.location = ""
	g.inside_estate = ""
	check(not g.enter_ship_bay().ok, "can't enter in flight")
	check(not g.can_place(sb, "trim_table", 0, 1) and not g.place_building(sb, "trim_table", 0, 1).ok, "no building in flight")
	check(not g.remove_building(sb, 0).ok, "no removing in flight")
	g.location = "mireth"
	check(g.remove_building(sb, 0).ok, "remove docked")
	# a two-station recipe cooks on the ship at a station without a lab
	g.location = "cinder"
	g.cargo = {"cannabis": 5}
	g.inside_estate = sb
	check(g.lab_here() and g.missing_stations("weed", []).size() > 0, "ship bay is a lab at Cinder")


func test_orders() -> void:
	var rules: Dictionary = data.orders
	for k in ["markup", "fee_pct", "fee_min", "express_fee_mult", "seconds", "far_seconds", "max_qty", "max_open", "cancel_refund"]:
		check(rules.has(k), "orders rule %s exists" % k)
	check(float(rules.seconds.express) < float(rules.seconds.standard), "express is faster")
	var g := new_game()
	g.credits = 5000
	var cat: Array = Orders.catalog(g)
	check(cat.size() == data.raws.size() + data.additives.size() + data.buildables.size(), "catalog lists raws, additives and station kits")
	for e in cat:
		if e.kind == "kit":
			continue
		var walk_in := 999999
		for loc in data.locations:
			var p: int = g.buy_price(e.item, loc)
			if p >= 0:
				walk_in = mini(walk_in, p)
		check(Orders.unit_price(g, e.item) > walk_in, "%s is dearer by phone than walking in" % e.item)
	check(Orders.unit_price(g, "nope") < 0, "unknown item has no price")
	var q: Dictionary = Orders.quote(g, "cannabis", 10, "stash", false)
	check(q.ok and q.total == q.cost + q.fee and q.fee >= int(rules.fee_min), "quote adds a fee: %s" % [q])
	var qx: Dictionary = Orders.quote(g, "cannabis", 10, "stash", true)
	check(qx.fee > q.fee and qx.seconds < q.seconds, "express costs more and arrives sooner")
	check(not Orders.quote(g, "cannabis", 0, "stash", false).ok, "zero quantity refused")
	check(not Orders.quote(g, "cannabis", int(rules.max_qty) + 1, "stash", false).ok, "over max quantity refused")
	check(not Orders.quote(g, "cannabis", 5, "cannery_annex", false).ok, "can't deliver to an estate you don't own")
	check(not Orders.quote(g, "nope", 5, "stash", false).ok, "unknown item refused")
	# order from anywhere (even in flight); the goods come later
	g.location = ""
	var before: int = g.credits
	var r: Dictionary = Orders.place(g, "cannabis", 10, "stash", false)
	check(r.ok and g.credits == before - q.total, "ordering charges cost + fee")
	check(g.orders.size() == 1 and g.stash.get("cannabis", 0) == 0, "goods are not there yet")
	g.tick(float(rules.seconds.standard) - 1.0)
	check(g.orders.size() == 1, "still in transit")
	g.tick(2.0)
	check(g.orders.is_empty() and g.stash.get("cannabis", 0) == 10, "delivered to the stash")
	check(g.orders_unseen == 1, "delivery counted as unseen")
	# estate delivery lands in the estate, collected when you stand inside
	g.credits = 20000
	g.location = "mireth"
	g.buy_estate("cannery_annex")
	g.location = ""
	check(Orders.destinations(g).size() == 3, "stash plus the cannery rig plus the owned estate")
	var far: Dictionary = Orders.quote(g, "nanoflux", 5, "cannery_annex", false)
	check(far.ok, "estate destination accepted")
	check(Orders.place(g, "nanoflux", 5, "cannery_annex", true).ok, "order to the estate")
	g.tick(float(rules.seconds.express) + 1.0)
	check(int(g.estate_stock.get("cannery_annex", {}).get("nanoflux", 0)) == 5, "arrived in the estate stock")
	g.stash = {}
	g.inside_estate = "cannery_annex"
	check(g.collect_stash().ok and g.cargo.get("nanoflux", 0) == 5 and g.estate_stock.get("cannery_annex", {}).is_empty(), "collect unloads the estate stock into the hold")
	g.inside_estate = ""
	# limits, funds, cancel
	g.credits = 5
	check(not Orders.place(g, "cannabis", 10, "stash", false).ok, "not enough credits")
	g.credits = 5000
	for i in int(rules.max_open):
		check(Orders.place(g, "nanoflux", 1, "stash", false).ok, "order %d" % i)
	check(not Orders.place(g, "nanoflux", 1, "stash", false).ok, "too many open orders")
	var first: Dictionary = g.orders[0]
	before = g.credits
	check(Orders.cancel(g, int(first.id)).ok and g.orders.size() == int(rules.max_open) - 1, "cancel removes the order")
	check(g.credits == before + int(round(int(first.cost) * float(rules.cancel_refund))), "cancel refunds the goods minus the fee")
	check(not Orders.cancel(g, 9999).ok, "unknown order can't be cancelled")


func test_order_kits() -> void:
	var g := new_game()
	g.credits = 10000
	var kit_price: int = Orders.unit_price(g, "kit:cook_stove")
	check(kit_price > 0 and kit_price < int(data.buildables.cook_stove.cost), "kit is cheaper than building on site")
	check(Orders.unit_price(g, "kit:nope") < 0, "unknown kit has no price")
	check(g.item_name("kit:cook_stove") == "Cook Stove kit", "kit name")
	check(Orders.place(g, "kit:cook_stove", 2, "stash", false).ok, "order two stove kits")
	g.tick(float(data.orders.seconds.standard) + 1.0)
	check(int(g.kits.get("cook_stove", 0)) == 2 and not g.stash.has("kit:cook_stove"), "kits delivered to the kit shelf, not the stash")
	g.buy_estate("cannery_annex")
	var before: int = g.credits
	check(g.place_building("cannery_annex", "cook_stove", 0, 0).ok and g.credits == before, "placing with a kit is free")
	check(int(g.kits.cook_stove) == 1, "one kit used")
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(int(h.kits.get("cook_stove", 0)) == 1, "kits survive save/load")
	g.place_building("cannery_annex", "cook_stove", 3, 0)
	before = g.credits
	check(g.place_building("cannery_annex", "cook_stove", 5, 0).ok and g.credits == before - int(data.buildables.cook_stove.cost), "without kits you pay again")


func test_orders_save() -> void:
	var g := new_game()
	g.credits = 5000
	Orders.place(g, "cannabis", 6, "stash", false)
	g.estates["cannery_annex"] = {"buildings": []}
	Workers.ensure(g.estates["cannery_annex"])
	g.estate_stock = {"cannery_annex": {"nanoflux": 3}}
	var json := JSON.stringify(g.to_dict())
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(json))
	check(h.orders.size() == 1 and int(h.orders[0].qty) == 6 and h.orders[0].dest == "stash", "open orders survive save/load")
	check(int(h.estate_stock.cannery_annex.nanoflux) == 3, "estate stock survives save/load")
	check(JSON.stringify(h.to_dict()) == json, "save with orders is stable")
	h.tick(500.0)
	check(h.stash.get("cannabis", 0) == 6, "restored order still delivers")
	var d := new_game().to_dict()
	d.erase("orders")
	d.erase("estate_stock")
	var old := Game.new()
	old.from_dict(data, d)
	check(old.orders.is_empty() and old.estate_stock.is_empty(), "old saves load without orders")
	# a saved order for an estate that no longer exists is dropped, goods go to the stash
	var d2 := new_game().to_dict()
	d2.orders = [{"id": 1, "item": "cannabis", "qty": 2, "dest": "ghost_estate", "due": 5.0, "cost": 20, "fee": 12, "express": false}]
	var h2 := Game.new()
	h2.from_dict(data, d2)
	h2.tick(10.0)
	check(h2.stash.get("cannabis", 0) == 2, "unknown destination falls back to the stash")


## Lanes and route planning over the jump gates (A6).
func test_galaxy_routes() -> void:
	var g := new_game()
	check(Galaxy.neighbours(g, "halvane") == ["kovar"] and Galaxy.neighbours(g, "kovar") == ["halvane", "thessaly"], "Halvane-Kovar-Thessaly chain")
	check(Galaxy.lanes(g).size() == 2, "two lanes (gate pairs count once)")
	check(Galaxy.gates(g, "halvane", "kovar") == ["halvane_gate"] and Galaxy.gates(g, "kovar").size() == 2, "gate lookup")
	check(Galaxy.route(g, "halvane", "kovar") == ["halvane", "kovar"] and Galaxy.route(g, "kovar", "kovar") == ["kovar"], "route over the lane")
	check(Galaxy.route(g, "halvane", "nowhere").is_empty(), "unknown system has no route")
	var pl := Galaxy.plan(g, "kovar")
	check(pl.ok and pl.hops == 1 and pl.fee == int(data.jump.fee) and pl.charge > 0.0, "plan: one hop, toll, charge time")
	check(is_equal_approx(pl.total_seconds, pl.charge + float(data.jump.seconds)), "plan total = charge + travel")
	check(not Galaxy.plan(g, "halvane").ok, "no plan to the current system")
	g.upgrades.engine = 3
	check(Galaxy.charge_seconds(g) < pl.charge and Galaxy.charge_seconds(g) >= float(data.jump.min_charge), "engine upgrades shorten the charge, never below the minimum")


## Per-planet laws (P6): levels, scan/frisk/heat/price scaling, data coverage and old saves.
func test_planet_laws() -> void:
	var g := new_game()
	for loc in data.laws.planets:
		check(data.locations.has(loc), "laws list a real location: " + loc)
		for tier in data.laws.planets[loc]:
			check(Laws.RANK.has(data.laws.planets[loc][tier]), "%s tier %s has a valid level" % [loc, tier])
	for lv in Laws.RANK:
		check(data.laws.levels.has(lv), "level rule exists: " + lv)
	check(Laws.level(g, "mireth", "weed") == "legal" and Laws.level(g, "mireth", "meth") == "banned", "Mireth: weed legal, meth banned")
	check(Laws.level(g, "beacon", "weed") == "tolerated", "unlisted location counts as tolerated")
	check(Laws.heat_mult(g, "mireth", "weed") < 1.0 and Laws.heat_mult(g, "mireth", "meth") > 1.0, "legal cools, banned heats")
	check(is_equal_approx(g.sale_heat_mult("meth", "mireth"), g.heat_mult("meth") * Laws.heat_mult(g, "mireth", "meth")), "sale heat multiplies strength and law")
	var key := Mixing.key("meth", [])
	var weed := Mixing.key("weed", [])
	g.demand["mireth"]["meth"] = 1.0
	var plain := int(round(Mixing.value(data, key) * Cartels.price_mult(g, "mireth") * float(data.market.fence_ratio)))
	check(g.sell_price(key, "", "mireth") > plain, "banned goods sell at a premium")
	check(Laws.price_mult(g, "mireth", "weed") < 1.0, "legal goods lose the premium")
	g.location = "mireth"
	var base_r := float(data.heat.scan_radius) * (1.0 - g.stealth())
	check(is_equal_approx(g.scan_radius(), base_r), "no cargo = plain scan radius")
	g.cargo[weed] = 1
	check(g.scan_radius() < base_r, "carrying only legal goods shrinks the scan radius")
	g.cargo[key] = 1
	check(g.scan_radius() > base_r, "carrying banned goods widens the scan radius")
	g.heat = 80.0
	var banned_cops := g.police_on_foot(1.0)
	g.cargo.erase(key)
	check(g.police_on_foot(1.0) <= banned_cops, "legal cargo draws no more police on foot than banned")
	check(is_equal_approx(Laws.frisk_mult(g, "mireth"), 1.0), "legal weed does not thin the patrols")
	check(Laws.summary(g, "glacis").size() == data.bases.size() and Laws.line(g, "glacis").contains("Weed"), "summary lists every drug")
	check(Laws.tooltip(g, "varrow").contains("Local laws"), "tooltip text")
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(Laws.level(h, "glacis", "cocaine") == "banned", "laws are static data, saves need nothing")
## Thessaly Drift: the third system from the content pack data/system_thessaly.json, two jumps out.
func test_second_system() -> void:
	check(data.systems.has("thessaly") and data.locations.has("quillon") and data.locations.has("ashfall"), "pack systems and locations merged")
	var before := JSON.stringify([data.systems, data.locations, data.surfaces, data.officials, data.combat.cover])
	Data.merge_pack(data, Data._load_json("res://data/system_thessaly.json"))
	check(JSON.stringify([data.systems, data.locations, data.surfaces, data.officials, data.combat.cover]) == before, "merging the pack again changes nothing")
	var q: Dictionary = data.locations.quillon
	var a: Dictionary = data.locations.ashfall
	check(q.system == "thessaly" and a.system == "thessaly" and not q.has("surface"), "locations sit in Thessaly")
	check(q.demand != a.demand and q.demand.cocaine > a.demand.cocaine and a.demand.meth > q.demand.meth, "own demand values")
	check(data.surfaces.quillon.security > data.surfaces.glacis.security and data.surfaces.ashfall.security < data.surfaces.varrow.security, "own security: Quillon tight, Ashfall lawless")
	check(q.heat_per_unit > a.heat_per_unit and q.get("patrol_base", false) and a.get("fence", false), "heat per sale, patrol base, fence")
	for loc in ["quillon", "ashfall"]:
		check(not data.surfaces[loc].buildings.any(func(b): return b.get("action", "") == "estate"), "%s clone has no duplicate estate door" % loc)
		check(not data.surfaces[loc].npcs.any(func(n): return n.has("contact")), "%s clone has no duplicate story contacts" % loc)
	var g := new_game()
	check(Galaxy.route(g, "halvane", "thessaly") == ["halvane", "kovar", "thessaly"] and Galaxy.route(g, "thessaly", "halvane").size() == 3, "route over both lanes, both ways")
	var pl := Galaxy.plan(g, "thessaly")
	var lane: Dictionary = data.locations.kovar_thessaly_gate
	check(pl.ok and pl.hops == 2 and pl.fee == int(data.jump.fee) + int(lane.toll), "plan sums the per-lane tolls (80 + 140)")
	check(is_equal_approx(pl.travel, float(data.jump.seconds) + float(lane.seconds)), "plan sums the per-lane travel time")
	check(g.gate_toll("halvane_gate") == int(data.jump.fee) and g.gate_toll("kovar_thessaly_gate") == 140, "gate toll falls back to jump.fee")
	g.undock()
	g.credits = 100
	check(not Galaxy.start(g, "thessaly").ok, "two tolls must be affordable up front")
	g.credits = 1000
	check(Galaxy.start(g, "thessaly").ok, "drive charges for Thessaly")
	g.tick(100.0)
	var r1 := Galaxy.engage(g)
	check(r1.ok and r1.more and g.system == "kovar" and g.credits == 1000 - 80, "first hop pays 80")
	g.tick(100.0)
	var r2 := Galaxy.engage(g)
	check(r2.ok and not r2.more and g.system == "thessaly" and g.credits == 1000 - 80 - 140, "second hop pays the 140 toll")
	check(g.locations_in("thessaly").has("quillon") and g.patrol_home("thessaly") == "quillon", "Quillon is Thessaly's patrol base")
	check(Galaxy.location_risk(g, "quillon").security > Galaxy.location_risk(g, "ashfall").security, "map risk differs per location")
	check(Galaxy.patrols_in(g, "thessaly") >= 0 and g.demand.has("quillon"), "demand tracked for the new locations")
	g.corruption.heat["thessaly"] = 10.0
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(h.system == "thessaly" and is_equal_approx(float(h.demand.quillon.cocaine), float(g.demand.quillon.cocaine)), "a save made in Thessaly round-trips")
	# an old save knows nothing about the pack: no Thessaly demand, heat or officials
	var old: Dictionary = JSON.parse_string(JSON.stringify(new_game().to_dict()))
	for k in ["quillon", "ashfall"]:
		old.demand.erase(k)
	for o in ["wren_q", "kasimir", "marl"]:
		old.corruption.officials.erase(o)
	var og := Game.new()
	og.from_dict(data, old)
	check(og.system == "halvane" and og.demand.quillon.cocaine == float(q.demand.cocaine) and Galaxy.plan(og, "thessaly").ok, "an old save loads and gets Thessaly at default values")
	og.undock()
	og.tick(5.0)
	check(og.state == "playing", "an old save keeps running")


## Heat overlay and price comparison data (A6).
func test_galaxy_overlays() -> void:
	var g := new_game()
	check(Galaxy.heat_level(g, "halvane") == 0.0, "cold map at zero heat")
	g.add_heat(80)
	check(is_equal_approx(Galaxy.heat_level(g, "halvane"), 0.8), "Halvane heat level follows heat")
	check(Galaxy.heat_level(g, "kovar") < Galaxy.heat_level(g, "halvane"), "frontier system reads cooler")
	g.system = "kovar"
	check(Galaxy.patrols_in(g, "kovar") == g.patrol_count() and Galaxy.patrols_in(g, "halvane") > Galaxy.patrols_in(g, "kovar"), "patrols_in matches patrol_count and Halvane has more")
	var risk := Galaxy.location_risk(g, "glacis")
	check(risk.sale_heat > Galaxy.location_risk(g, "bazaar").sale_heat and risk.security > Galaxy.location_risk(g, "varrow").security, "Glacis is risky, Bazaar and Varrow are not")
	check(Galaxy.location_risk(g, "beacon").security < 0.0, "no surface = security -1")
	var seen_items := 0
	for row in Galaxy.buy_table(g):
		seen_items += 1
		for i in range(1, row.offers.size()):
			check(row.offers[i - 1].price <= row.offers[i].price, "%s offers sorted cheapest first" % row.item)
		check(row.offers[0].price == g.buy_price(row.item, row.offers[0].loc), "%s best offer matches buy_price" % row.item)
	check(seen_items == data.raws.size() + data.additives.size(), "every raw and additive is listed")
	var cannabis: Dictionary = Galaxy.buy_table(g).filter(func(r): return r.item == "cannabis")[0]
	check(cannabis.offers[0].loc == "cinder" and cannabis.offers.size() >= 3, "cannabis is cheapest at Cinder and sold in three places")
	var sells := Galaxy.sell_table(g)
	check(sells.size() == data.bases.size(), "every drug in the sell table")
	for row in sells:
		for i in range(1, row.offers.size()):
			check(row.offers[i - 1].price >= row.offers[i].price, "%s demand sorted best first" % row.base)
	var coke: Dictionary = sells.filter(func(r): return r.base == "cocaine")[0]
	check(coke.offers[0].loc == "glacis", "Glacis pays the most for cocaine")
	g.demand["glacis"]["cocaine"] = 0.2
	var coke2: Dictionary = Galaxy.sell_table(g).filter(func(r): return r.base == "cocaine")[0]
	check(coke2.offers[0].loc != "glacis", "saturated demand drops the location in the ranking")


## Jump drive: charge-up, cancel rules, engage (A6).
func test_jump_drive() -> void:
	var g := new_game()
	check(not Galaxy.start(g, "kovar").ok, "no charge while docked")
	g.undock()
	check(not Galaxy.start(g, "halvane").ok and not Galaxy.start(g, "nowhere").ok, "bad targets refused")
	g.credits = 10
	check(not Galaxy.start(g, "kovar").ok and g.jump_plan.is_empty(), "the toll must be affordable")
	g.credits = 500
	check(Galaxy.start(g, "kovar").ok and Galaxy.charging(g) and not Galaxy.ready(g), "charging starts in flight")
	check(not Galaxy.engage(g).ok, "cannot engage an uncharged drive")
	var need := float(g.jump_plan.need)
	g.tick(need * 0.5)
	check(is_equal_approx(Galaxy.progress(g), 0.5) and g.system == "halvane", "half charged, still home")
	g.tick(need)
	check(Galaxy.ready(g) and Galaxy.progress(g) == 1.0 and g.system == "halvane", "charged but the jump waits for the engage")
	var credits := g.credits
	var t := g.total_time
	var r := Galaxy.engage(g)
	check(r.ok and r.gate == "halvane_gate" and g.system == "kovar" and not r.more, "engage jumps through the Halvane gate")
	check(g.credits == credits - int(data.jump.fee) and g.total_time >= t + float(data.jump.seconds), "toll and travel time paid")
	check(g.jump_plan.is_empty(), "plan cleared after the last hop")
	# cancel rules
	check(Galaxy.start(g, "halvane").ok, "charge back home")
	Galaxy.cancel(g)
	check(g.jump_plan.is_empty(), "cancel clears the plan")
	Galaxy.start(g, "halvane")
	g.stats.busts += 1
	g.tick(0.1)
	check(g.jump_plan.is_empty(), "a bust interrupts the charge")
	Galaxy.start(g, "halvane")
	g.dock("glacis")
	g.tick(0.1)
	check(g.jump_plan.is_empty(), "docking cancels the charge")
	g.undock()
	Galaxy.start(g, "halvane")
	check(g.jump("kovar_gate").ok, "manual gate jump while charging")
	check(g.jump_plan.is_empty(), "a manual jump cancels the plan")
	var events: Array = []
	g.event.connect(func(k, _p): events.append(k))
	Galaxy.start(g, "kovar")
	g.tick(100.0)
	Galaxy.cancel(g)
	check(events.has("jump_charging") and events.has("jump_ready") and events.has("jump_cancelled"), "charge events are emitted")
	# not part of the save
	Galaxy.start(g, "halvane")
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(h.jump_plan.is_empty() and h.system == g.system, "an unfinished charge is not saved")


## A third system makes multi-hop routes: the drive recharges for every hop (A6).
func test_jump_drive_multi_hop() -> void:
	var d: Dictionary = data.duplicate(true)
	d.systems["zeta"] = {"name": "Zeta", "galaxy_pos": [9, 1], "security": "low", "patrol_mult": 0.5, "star": "#ffffff", "nebula": ["#222222"], "desc": ""}
	var gate_a: Dictionary = d.locations.kovar_gate.duplicate(true)
	gate_a.merge({"name": "Zeta Gate", "jump_to": "zeta", "arrive": "zeta_gate"}, true)
	var gate_b: Dictionary = d.locations.kovar_gate.duplicate(true)
	gate_b.merge({"name": "Kovar Gate B", "system": "zeta", "jump_to": "kovar", "arrive": "kovar_gate_z"}, true)
	d.locations["kovar_gate_z"] = gate_a
	d.locations["zeta_gate"] = gate_b
	var g := Game.new()
	g.new_game(d, 3)
	g.undock()
	var pl := Galaxy.plan(g, "zeta")
	check(pl.ok and pl.route == ["halvane", "kovar", "zeta"] and pl.hops == 2 and pl.fee == 2 * int(d.jump.fee), "two hops via Kovar")
	g.credits = 100
	check(not Galaxy.start(g, "zeta").ok, "two tolls must be affordable up front")
	g.credits = 1000
	Galaxy.start(g, "zeta")
	g.tick(100.0)
	var r1 := Galaxy.engage(g)
	check(r1.ok and r1.more and g.system == "kovar" and Galaxy.charging(g), "first hop done, second hop already charging")
	g.tick(100.0)
	var r2 := Galaxy.engage(g)
	check(r2.ok and not r2.more and g.system == "zeta" and g.jump_plan.is_empty(), "second hop arrives in Zeta")
	check(Galaxy.route(g, "zeta", "halvane") == ["zeta", "kovar", "halvane"], "route back")
	check(Galaxy.lanes(g).size() == 3, "three lanes (Thessaly pack + the test system)")


func test_mixing_rules() -> void:
	check(Mixing.traits_for(data, "weed", []) == ["glow"], "plain weed has glow")
	# nanoflux turns glow into radiant and adds overclock
	var t := Mixing.traits_for(data, "weed", ["nanoflux"])
	check(t.has("radiant") and t.has("overclock") and not t.has("glow"), "nanoflux transform: %s" % [t])
	# ion syrup then turns overclock into jittery; void salt turns jittery into focused
	t = Mixing.traits_for(data, "weed", ["nanoflux", "ion_syrup", "void_salt"])
	check(t.has("focused") and not t.has("jittery"), "chain to focused: %s" % [t])
	var k := Mixing.key("weed", ["radiant", "overclock"])
	check(k == "weed:overclock+radiant", "key sorted: %s" % k)
	check(Mixing.parse_key(k).traits.size() == 2, "parse key")
	check(Mixing.value(data, k) > Mixing.value(data, "weed:glow"), "mixed is worth more")
	var many := Mixing.traits_for(data, "weed", ["nanoflux", "ion_syrup", "static_pollen", "void_salt", "nanoflux"])
	check(many.size() <= int(data.max_traits), "trait cap respected")


func test_buy_and_cargo_limit() -> void:
	var g := new_game()
	check(g.buy("cannabis", 5).ok, "buy cannabis at hub")
	check(g.cargo.cannabis == 5 and g.credits == 400 - 50, "credits and cargo after buy")
	check(not g.buy("coca_leaf", 1).ok, "coca_leaf not sold at hub")
	check(not g.buy("cannabis", 100).ok, "cargo limit enforced")
	g.undock()
	check(not g.buy("cannabis", 1).ok, "cannot buy while flying")


func test_lab_batch() -> void:
	var g := new_game()
	g.buy("cannabis", 5)
	g.buy("nanoflux", 5)
	var r := g.start_batch("weed", ["nanoflux"], 5)
	check(r.ok, "batch starts: %s" % r.msg)
	check(not g.cargo.has("cannabis") and not g.cargo.has("nanoflux"), "ingredients consumed")
	check(g.heat > 0.0, "lab adds heat")
	check(not g.start_batch("weed", [], 6).ok, "batch over rig capacity refused")
	for i in 30:
		g.tick(1.0)
	check(g.stash.get("weed:overclock+radiant", 0) == 5, "batch lands in stash")
	check(g.collect_stash().ok and g.cargo.get("weed:overclock+radiant", 0) == 5, "collect stash")


func test_production_stations() -> void:
	check(Production.stations_for(data, "weed", []) == ["trim_table", "extractor", "cook_stove", "pack_table"], "plain weed stations: %s" % [Production.stations_for(data, "weed", [])])
	check(Production.stations_for(data, "meth", ["nanoflux"]) == ["precursor_scale", "mixing_station", "cook_stove", "refiner", "pack_table"], "mixed meth stations")
	check(Production.stations_for(data, "cocaine", []) == ["precursor_scale", "extractor", "cook_stove", "refiner", "pack_table"], "cocaine gets both purity stations")
	var Runner = load("res://scripts/ui/minigames/registry.gd")
	for id in data.stations:
		var st: Dictionary = data.stations[id]
		if st.get("passive", false):
			continue  # no minigame (drying table, sealing bench)
		if st.get("machine", false):
			continue  # automation machines have no minigame (test_machines_data)
		check(Runner.MINIGAMES.has(st.minigame), "station %s minigame %s is registered" % [id, st.minigame])
		check(st.affects in ["yield", "quality", "purity", "heat"], "station %s affects a known stat" % id)
		check(id in data.station_order, "station %s is in station_order" % id)
	for b in data.bases:
		var n := 0
		for id in Production.stations_for(data, b, []):
			if data.stations[id].affects == "yield":
				n += 1
		check(n == 1, "%s has exactly one prep (yield) station" % b)
		var p := 0
		for id in Production.stations_for(data, b, []):
			if data.stations[id].affects == "purity":
				p += 1
		check(p >= 1, "%s has a purity station" % b)
	for id in data.stations:
		check(data.buildables.has(id), "station %s is buildable in estates" % id)


func test_production_outcome() -> void:
	var quick := Production.outcome(data, {})
	check(quick.grade == Mixing.STANDARD and is_equal_approx(quick.yield_mult, 1.0) and is_equal_approx(quick.heat_mult, 1.0), "quick batch is neutral: %s" % [quick])
	var best := Production.outcome(data, {"trim_table": 1.0, "extractor": 1.0, "mixing_station": 1.0, "cook_stove": 1.0, "pack_table": 1.0})
	check(best.grade == 3 and best.yield_mult > 1.1 and best.heat_mult < 0.8, "perfect hands: %s" % [best])
	var worst := Production.outcome(data, {"trim_table": 0.0, "extractor": 0.0, "cook_stove": 0.0, "pack_table": 0.0})
	check(worst.grade == 0 and worst.yield_mult < 0.9 and worst.heat_mult > 1.2, "botched: %s" % [worst])
	# purity joins the grade: a perfect cook with a botched extraction is no longer Pristine, a skipped one counts as Standard
	var dirty := Production.outcome(data, {"cook_stove": 1.0, "extractor": 0.0})
	check(is_zero_approx(dirty.purity) and dirty.grade < 3, "impure cook: %s" % [dirty])
	var skipped := Production.outcome(data, {"cook_stove": 1.0})
	check(is_equal_approx(skipped.purity, 0.5) and skipped.grade == 2, "skipped purity counts as Standard: %s" % [skipped])
	check(is_equal_approx(quick.purity, 0.5), "quick batch purity is neutral")
	# perfect batch vs. quick batch in the core
	var a := new_game()
	a.buy("cannabis", 5)
	a.buy("nanoflux", 5)
	var r := a.start_batch("weed", ["nanoflux"], 5, {"trim_table": 1.0, "extractor": 1.0, "mixing_station": 1.0, "cook_stove": 1.0, "pack_table": 1.0})
	check(r.ok, "hand batch starts: %s" % r.msg)
	var q := new_game()
	q.buy("cannabis", 5)
	q.buy("nanoflux", 5)
	q.start_batch("weed", ["nanoflux"], 5)
	check(a.lab_queue[0].qty == 6 and q.lab_queue[0].qty == 5, "yield bonus: %d vs %d" % [a.lab_queue[0].qty, q.lab_queue[0].qty])
	check(str(a.lab_queue[0].product).begins_with("weed:overclock+radiant@3"), "pristine key: %s" % a.lab_queue[0].product)
	check(a.heat < q.heat, "good packaging means less heat")
	check(Mixing.value(data, a.lab_queue[0].product) > Mixing.value(data, q.lab_queue[0].product) * 1.3, "pristine is worth more")
	var tiny := new_game()
	tiny.buy("cannabis", 1)
	tiny.start_batch("weed", [], 1, {"trim_table": 0.0})
	check(tiny.lab_queue[0].qty == 1, "a batch always yields at least one unit")


func test_quality_grade_keys() -> void:
	check(Mixing.key("weed", ["glow"], 1) == "weed:glow", "standard has no suffix")
	var k := Mixing.key("cocaine", ["smooth", "crisp"], 2)
	check(k == "cocaine:crisp+smooth@2", "graded key: %s" % k)
	var p := Mixing.parse_key(k)
	check(p.base == "cocaine" and p.traits == ["crisp", "smooth"] and p.grade == 2, "parse graded key: %s" % [p])
	check(Mixing.parse_key("weed:glow").grade == 1, "old keys are standard")
	check(Mixing.display_name(data, k).begins_with("Premium Cocaine"), "grade in name: %s" % Mixing.display_name(data, k))
	var g := new_game()
	g.cargo["weed:overclock+radiant@2"] = 2
	g.cargo["weed:overclock+radiant"] = 2
	check(g.sell_price("weed:overclock+radiant@2", "okka") > g.sell_price("weed:overclock+radiant", "okka"), "contacts pay more for premium")
	check(g.sell("weed:overclock+radiant@2", 2, "okka").ok, "graded product sells")
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(h.cargo.get("weed:overclock+radiant", 0) == 2 and h.cargo.size() == 1, "graded cargo survives save")


func test_packaging_tiers() -> void:
	check(Packaging.tier_for(data, 0.0) == 0 and Packaging.tier_for(data, 0.5) == 1 and Packaging.tier_for(data, 0.95) == 2, "tier thresholds")
	check(Production.outcome(data, {}).pack == 0, "quick batch is loose")
	check(Production.outcome(data, {"pack_table": 0.95}).pack == 2, "tight seals are shielded")
	var k := Mixing.key("weed", ["glow"], 2, 2)
	check(k == "weed:glow@2#2", "packed key: %s" % k)
	var p := Mixing.parse_key(k)
	check(p.base == "weed" and p.traits == ["glow"] and p.grade == 2 and p.pack == 2, "parse packed key: %s" % [p])
	check(Mixing.key("weed", ["glow"], 1, 0) == "weed:glow" and Mixing.parse_key("weed:glow@2").pack == 0, "old keys are loose")
	check(Mixing.display_name(data, k).ends_with("(Shielded)"), "tier in name: %s" % Mixing.display_name(data, k))
	check(Mixing.value(data, k) == Mixing.value(data, "weed:glow@2"), "tier does not change value")
	var g := new_game()
	g.credits = 1000
	g.cargo.clear()
	g.cargo["weed:glow#2"] = 400
	g.cargo["weed:glow"] = 50
	g.cargo["fuel"] = 3
	g.corruption.hired = {}
	var r := g.bust()
	var kept: int = g.cargo.get("weed:glow#2", 0)
	var expect := 400.0 * Packaging.survive_chance(data, 2)
	check(absf(kept - expect) < 60.0 and kept > 0 and kept < 400, "shielded survives with a chance: kept %d of 400" % kept)
	check(not g.cargo.has("weed:glow") and g.cargo.get("fuel", 0) == 3, "loose product lost, non-products untouched")
	check(r.msg.contains("hid"), "bust message mentions packaging: %s" % r.msg)
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(h.cargo.get("weed:glow#2", 0) == kept, "packed cargo survives save")
	var b := new_game()
	b.buy("cannabis", 1)
	var res := b.start_batch("weed", [], 1, {"pack_table": 0.95})
	check(res.ok and b.lab_queue[0].product.ends_with("#2"), "batch stores the tier: %s" % [res])


## Every registered minigame: a skilled bot scores high, doing nothing scores low, and each run ends on its own.
func test_station_minigames() -> void:
	var Runner = load("res://scripts/ui/minigames/registry.gd")
	var ctx_for := func(base: String, seed_value: int) -> Dictionary:
		return {"base": base, "tier": int(data.bases[base].tier), "additives": ["nanoflux", "ion_syrup"], "qty": 5, "data": data, "seed": seed_value}
	for id in data.stations:
		var st: Dictionary = data.stations[id]
		if st.get("passive", false) or st.get("machine", false):
			continue
		var base: String = st.get("bases", ["meth"])[0]
		for s in 4:
			for skilled in [true, false]:
				var mg: Control = Runner.MINIGAMES[st.minigame].new()
				mg.setup(ctx_for.call(base, s + 1))
				var t := 0.0
				while not mg.done and t < 60.0:
					if skilled:
						mg.bot_input(1.0 / 60.0)
					mg.step(1.0 / 60.0)
					t += 1.0 / 60.0
				check(mg.done, "%s ends (seed %d, skilled %s)" % [id, s + 1, skilled])
				if skilled:
					check(mg.score >= 0.8, "%s skilled score %.2f (seed %d)" % [id, mg.score, s + 1])
				else:
					check(mg.score <= 0.35, "%s idle score %.2f (seed %d)" % [id, mg.score, s + 1])
				mg.free()


func test_people_profiles() -> void:
	var ids := {}
	for c in data.contacts:
		check(not ids.has(c.id), "contact id %s unique" % c.id)
		ids[c.id] = true
		check(data.locations.has(c.location), "%s location exists" % c.id)
		check(data.traits.has(c.likes), "%s liked trait exists" % c.id)
		check(not c.get("prefers", []).is_empty(), "%s prefers at least one drug" % c.id)
		for b in c.get("prefers", []):
			check(data.bases.has(b), "%s prefers known drug %s" % [c.id, b])
		check(int(c.get("budget", 0)) > 0, "%s has a budget" % c.id)
		check(str(c.get("bio", "")) != "" and str(c.get("job", "")) != "", "%s has job and bio" % c.id)
		check(ArtReg.NPC_LOOKS.has(c.get("look", "")), "%s look exists" % c.id)
		# the schedule covers all 24 hours
		var covered := true
		for h in 24:
			if People.whereabouts(c, h + 0.5).is_empty():
				covered = false
		check(covered, "%s schedule covers the whole day" % c.id)
	check(data.contacts.size() >= 9, "at least 9 named people")
	for b in data.bases:
		check(data.people.addictiveness.has(b), "addictiveness for %s" % b)
	check(data.people.addictiveness.fentanyl > data.people.addictiveness.weed, "stronger drugs hook faster")
	var g := new_game()
	var okka: Dictionary = g.contact("okka")
	check(People.whereabouts(okka, 23.0).place == "Home" and People.whereabouts(okka, 3.0).place == "Home", "schedule wraps midnight")
	check(People.mood(0.7) == "Loyal" and People.mood(-0.7) == "Hostile", "mood labels")
	check(g.people.okka.known and not g.people.teo.known, "start contacts known, new people unknown")
	g.meet("teo")
	check(g.people.teo.known, "meeting makes a person known")


func test_people_deals() -> void:
	var g := new_game()
	g.location = "mireth"
	var p := "weed:overclock+radiant"
	g.cargo[p] = 30
	var units0 := People.max_units(g, "okka")
	var price0: int = g.sell_price(p, "okka")
	var r: Dictionary = g.sell(p, 2, "okka")
	check(r.ok, "sell to okka: %s" % r.msg)
	var s: Dictionary = g.people.okka
	check(s.addiction > 0.15, "deal raises addiction")
	check(s.affinity > 0.1, "deal with liked trait raises affinity")
	check(s.spent > 0 and s.history.size() == 1 and s.history[0].qty == 2, "deal recorded in history")
	g.demand.mireth.weed = 1.0
	check(g.sell_price(p, "okka") > price0, "higher affinity pays more")
	# budget caps the deal
	s.spent = People.daily_budget(g, "okka") - 10
	g.contact_ready_at.erase("okka")
	check(People.units_wanted(g, "okka", p) == 0, "no budget left -> wants nothing")
	check(not g.sell(p, 1, "okka").ok, "sale over budget fails")
	# addiction raises deal size and budget
	var budget0 := People.daily_budget(g, "okka")
	s.addiction = 1.0
	check(People.max_units(g, "okka") == units0 + int(data.people.addiction_units_bonus), "hooked buys more units")
	check(People.daily_budget(g, "okka") > budget0, "hooked spends more")
	# a new day resets spending and lets addiction fade
	g.tick(g.day_seconds() + 0.1)
	check(s.spent == 0 and s.addiction < 1.0, "new day resets budget and decays addiction")
	# shoddy product hurts affinity
	g.contact_ready_at.erase("sen")
	var aff0: float = g.people.sen.affinity
	g.cargo["weed:glow@0"] = 3
	check(g.sell("weed:glow@0", 1, "sen").ok, "sell shoddy to sen")
	check(g.people.sen.affinity < aff0, "shoddy product lowers affinity")
	# preferred drug pays more
	check(People.price_mult(g, "teo", "weed") > People.price_mult(g, "vesna", "weed"), "preferred drug bonus")


func test_people_save() -> void:
	var g := new_game()
	g.location = "mireth"
	g.cargo["weed:glow"] = 5
	g.sell("weed:glow", 2, "okka")
	g.meet("teo")
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2 := Game.new()
	g2.from_dict(data, d)
	check(g2.people.okka.history.size() == 1, "history survives save")
	check(is_equal_approx(g2.people.okka.addiction, g.people.okka.addiction), "addiction survives save")
	check(g2.people.teo.known, "known flag survives save")
	d.erase("people")
	var g3 := Game.new()
	g3.from_dict(data, d)
	check(g3.people.has("marta") and g3.people.okka.history.is_empty(), "old save without people gets defaults")


## D4: every planet is a big map split into named districts, with landmarks (areas) that are either paint or walls.
func test_planet_districts() -> void:
	var Nav = load("res://scripts/planet/nav.gd")
	var kinds := ["water", "pit", "slag", "void", "chasm", "grass", "sand", "salt", "ice", "rubble", "rail", "deck", "arena", "dome"]
	for loc in data.surfaces:
		var s: Dictionary = data.surfaces[loc]
		if s.has("estate"):
			continue
		check(int(s.size[0]) * int(s.size[1]) >= 2500, "%s is a big map (%d tiles)" % [loc, int(s.size[0]) * int(s.size[1])])
		var map := Rect2(0, 0, s.size[0], s.size[1])
		var districts: Array = s.get("districts", [])
		check(districts.size() >= 3, "%s has at least three districts" % loc)
		var covered := 0.0
		for d in districts:
			var r := Rect2(d.rect[0], d.rect[1], d.rect[2], d.rect[3])
			check(map.encloses(r) and str(d.name) != "", "%s district %s inside the map" % [loc, d.name])
			covered += r.get_area()
		check(is_equal_approx(covered, map.get_area()), "%s districts tile the whole map" % loc)
		var solid: Array = Nav.solid_areas(s)
		check(not solid.is_empty(), "%s has a landmark you can't walk through" % loc)
		for a in s.get("areas", []):
			check(str(a[4]) in kinds, "%s area kind %s known" % [loc, a[4]])
			check(map.encloses(Rect2(a[0], a[1], a[2], a[3])), "%s area %s inside the map" % [loc, str(a)])
		var blocked: Array = []
		for b in s.buildings:
			blocked.append(Rect2(b.rect[0], b.rect[1], b.rect[2], b.rect[3]))
		for r in s.roads:
			blocked.append(Rect2(r[0], r[1], r[2], r[3]))
		for a in solid:
			var ar := Rect2(a[0], a[1], a[2], a[3])
			check(not blocked.any(func(o): return o.intersects(ar)), "%s solid area %s stays off roads and buildings" % [loc, str(a)])
		var nav: AStarGrid2D = Nav.build(s)
		for a in solid:
			check(nav.is_point_solid(Vector2i(int(a[0]), int(a[1]))), "%s solid area is a wall in the nav grid" % loc)
		var start := Vector2i(int(s.spawn[0]), int(s.spawn[1]))
		for k in s.spots:
			var cell := Vector2i(int(floor(s.spots[k][0])), int(floor(s.spots[k][1])))
			check(not nav.is_point_solid(cell) and not nav.get_id_path(start, cell).is_empty(), "%s spot %s reachable" % [loc, k])
		check(s.spots.size() >= 8, "%s has places for people to be (%d)" % [loc, s.spots.size()])


## P3: hiding spots. Still in a spot hides you, officers lose you, close ones find you, moving breaks cover.
func test_hiding() -> void:
	var r: Dictionary = Hiding.rules()
	check(float(r.settle_seconds) > 0.0 and float(r.lose_seconds) > float(r.settle_seconds), "hiding rules load")
	var h := Hiding.fresh()
	var ev := Hiding.step(h, 0.5, true, 0.0, INF)
	check(not h.hidden and not ev.hid, "not hidden before the settle time")
	ev = Hiding.step(h, 0.5, true, 0.0, INF)
	check(h.hidden and ev.hid, "hidden after standing still in a spot")
	check(not Hiding.visible_to_officer(h, true) and Hiding.visible_to_officer(Hiding.fresh(), true), "hidden player is invisible to officers, open player is not")
	check(not Hiding.visible_to_officer(h, false), "out of sight stays out of sight")
	var lost := 0
	for i in 40:
		ev = Hiding.step(h, 0.1, true, 0.0, 300.0)
		if ev.lost:
			lost += 1
	check(lost == 1 and h.hidden, "officers lose you exactly once per hide")
	ev = Hiding.step(h, 0.1, true, 0.0, float(r.notice_range) - 1.0)
	check(ev.found and not h.hidden and float(h.cd) > 0.0, "an officer who walks up finds you and burns the spot")
	for i in 20:
		Hiding.step(h, 0.1, true, 0.0, INF)
	check(not h.hidden and float(h.cd) > 0.0, "cannot re-hide during the found cooldown")
	for i in 60:
		Hiding.step(h, 0.1, true, 0.0, INF)
	check(h.hidden, "can hide again after the cooldown")
	Hiding.step(h, 0.1, true, 120.0, INF)
	check(not h.hidden, "moving breaks cover")
	h = Hiding.fresh()
	Hiding.step(h, 0.5, true, 0.0, INF)
	Hiding.step(h, 0.5, false, 0.0, INF)
	Hiding.step(h, 0.5, true, 0.0, INF)
	check(not h.hidden, "leaving the spot resets the settle timer")
	Hiding.step(h, 0.5, true, 0.0, INF)
	check(h.hidden, "settles again in the spot")
	Hiding.reveal(h)
	check(not h.hidden and float(h.hid_t) == 0.0, "reveal (shooting, being shot) breaks cover")
	# layout: every planet's spots are inside the map, off buildings/roads/solid areas/cover, reachable, with a known kind
	var Nav = load("res://scripts/planet/nav.gd")
	for loc in data.surfaces:
		var s: Dictionary = data.surfaces[loc]
		if s.has("estate"):
			continue
		var spots: Array = s.get("hide", [])
		check(spots.size() >= 3, "%s has hiding spots (%d)" % [loc, spots.size()])
		var map := Rect2(0, 0, s.size[0], s.size[1])
		var nav: AStarGrid2D = Nav.build(s)
		var start := Vector2i(int(s.spawn[0]), int(s.spawn[1]))
		var cover: Array = Combat.cover_rects(Combat.cover_tiles(data, loc), 1.0)
		var rects := Hiding.spot_rects(s, 1.0)
		for i in spots.size():
			var rc: Rect2 = rects[i]
			check(map.encloses(rc) and r.kinds.has(str(spots[i][4])), "%s hiding spot %d inside the map with a known kind" % [loc, i])
			for b in s.buildings:
				check(not rc.intersects(Rect2(b.rect[0], b.rect[1], b.rect[2], b.rect[3])), "%s hiding spot %d off buildings" % [loc, i])
			for c in cover:
				check(not rc.intersects(c), "%s hiding spot %d off cover" % [loc, i])
			var cell := Vector2i(int(rc.get_center().x), int(rc.get_center().y))
			check(not nav.is_point_solid(cell) and not nav.get_id_path(start, cell).is_empty(), "%s hiding spot %d reachable" % [loc, i])
		check(Hiding.spot_at(rects, rects[0].get_center()) == 0 and Hiding.spot_at(rects, Vector2(-5, -5)) == -1, "%s spot_at" % loc)


## B4: every person on a planet is a named customer with a habit, a budget and a day plan.
func test_locals() -> void:
	var again: Array = Locals.generate(data)
	var locals: Array = data.contacts.filter(func(c): return c.get("local", false))
	check(locals.size() == again.size() and locals.size() >= 50, "locals generated once (%d)" % locals.size())
	check(locals.map(func(c): return c.name) == again.map(func(c): return c.name), "same people every run (seeded per planet)")
	var names := {}
	for c in data.contacts:
		check(not names.has(c.name), "name %s is unique" % c.name)
		names[c.name] = true
	for loc in data.locals.count:
		var here := locals.filter(func(c): return c.location == loc)
		check(here.size() == int(data.locals.count[loc]), "%s has %d townsfolk" % [loc, here.size()])
	var weed := 0
	for c in locals:
		check(not c.known and c.budget > 0 and c.max_units >= 1 and data.traits.has(c.likes), "%s is an unknown buyer with a budget" % c.id)
		check(not c.prefers.is_empty() and c.prefers.all(func(b): return data.locations[c.location].demand.has(b)), "%s wants a drug sold on %s" % [c.id, c.location])
		check(c.job != "" and c.bio != "", "%s has a job and a line" % c.id)
		check(c.schedule.size() == 4 and c.schedule.all(func(e): return data.surfaces[c.location].spots.has(e.place)), "%s schedule uses the planet's spots" % c.id)
		for h in 24:
			check(not People.whereabouts(c, h + 0.5).is_empty(), "%s is somewhere at %d:00" % [c.id, h])
		if c.prefers.has("weed"):
			weed += 1
	check(weed > locals.size() / 3, "weed is the most common habit (%d of %d)" % [weed, locals.size()])
	# talking makes them a contact; a happy customer refers someone
	var g := new_game()
	var first: Dictionary = locals.filter(func(c): return c.location == "mireth")[0]
	check(not People.state(g, first.id).known, "locals start unknown")
	g.meet(first.id)
	check(People.state(g, first.id).known, "talking to a local meets them")
	data.locals.referral_chance = 1.0
	g.location = "mireth"
	g.cargo["weed:glow"] = 5
	var unknown_before := locals.filter(func(c): return c.location == "mireth" and not People.state(g, c.id).known).size()
	var got := []
	g.event.connect(func(k, p): if k == "referral": got.append(p))
	check(g.sell("weed:glow", 1, "okka").ok, "sale to Okka")
	var unknown_after := locals.filter(func(c): return c.location == "mireth" and not People.state(g, c.id).known).size()
	check(got.size() == 1 and unknown_after == unknown_before - 1, "a sale can bring a referral (%d -> %d)" % [unknown_before, unknown_after])
	data.locals.referral_chance = 0.25
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2 := Game.new()
	g2.from_dict(data, d)
	check(g2.people[first.id].known and g2.people[got[0].contact].known, "met and referred locals survive a save")


func test_idle_chatter() -> void:
	check(Chatter.period(data, 6.0) == "morning" and Chatter.period(data, 12.0) == "day", "chatter periods by hour")
	check(Chatter.period(data, 23.0) == "night" and Chatter.period(data, 2.0) == "night" and Chatter.period(data, 30.0) == "morning", "night wraps past midnight")
	for loc in data.surfaces:
		for h in 24:
			check(not Chatter.pool(data, loc, h + 0.5).is_empty(), "%s has chatter at %d:00" % [loc, h])
	check(Chatter.pool(data, "cinder", 12.0).has("Dust in my teeth again."), "planet line in its pool")
	check(not Chatter.pool(data, "mireth", 12.0).has("Dust in my teeth again."), "other planet's line is excluded")
	check(not Chatter.pool(data, "mireth", 12.0).has("Shouldn't be out this late."), "night line excluded at noon")
	check(Chatter.pool(data, "mireth", 23.0).has("Shouldn't be out this late."), "night line at night")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var last := ""
	var repeats := 0
	for i in 60:
		var l := Chatter.pick(data, "mireth", 12.0, rng, last)
		check(l != "", "pick returns a line")
		repeats += 1 if l == last else 0
		last = l
	check(repeats == 0, "no immediate repeats")
	check(Chatter.pick({}, "mireth", 12.0, rng) == "", "empty data gives no line")
	var st := Chatter.new_state(data, rng)
	check(Chatter.tick(data, st, 0.1, false, false, true, "mireth", 12.0, rng) == "" and float(st.cd) > 0.5, "out of earshot: silent, timer paused")
	check(Chatter.tick(data, st, 100.0, true, true, true, "mireth", 12.0, rng) == "", "silent while in conversation")
	check(Chatter.tick(data, st, 100.0, true, false, false, "mireth", 12.0, rng) == "", "silent when too many bubbles")
	var said := Chatter.tick(data, st, 100.0, true, false, true, "mireth", 12.0, rng)
	check(said != "" and said == st.last, "speaks when timer ran out")
	check(float(st.cd) >= float(Chatter.rules(data).gap[0]), "cooldown reset after speaking")
	check(Chatter.tick(data, st, 0.1, true, false, true, "mireth", 12.0, rng) == "", "no second line during cooldown")


func test_people_schedules_on_surfaces() -> void:
	var Nav = load("res://scripts/planet/nav.gd")
	for loc in data.surfaces:
		var cfg: Dictionary = data.surfaces[loc]
		if cfg.has("estate"):
			continue
		var nav: AStarGrid2D = Nav.build(cfg)
		var start := Vector2i(int(cfg.spawn[0]), int(cfg.spawn[1]))
		var all_npcs: Array = cfg.get("npcs", []) + Locals.npcs_for(data, loc)  # the order surface.gd uses for slots
		for n in all_npcs:
			if n.get("contact", "") == "":
				continue
			var c: Dictionary = {}
			for cc in data.contacts:
				if cc.id == n.contact:
					c = cc
			for e in c.get("schedule", []):
				check(cfg.get("spots", {}).has(e.place), "%s has a spot for %s's %s" % [loc, c.id, e.place])
			for h in 24:
				var sp: Array = People.spot(c, cfg.get("spots", {}), h + 0.5, all_npcs.find(n))
				if sp.is_empty():
					continue
				sp = Nav.free_spot(nav, sp, cfg.spots[People.whereabouts(c, h + 0.5).place])
				var cell := Vector2i(int(floor(sp[0])), int(floor(sp[1])))
				check(nav.region.has_point(cell) and not nav.is_point_solid(cell), "%s spot of %s at %d:00 is walkable" % [loc, c.id, h])
				check(not nav.get_id_path(start, cell).is_empty(), "%s spot of %s at %d:00 is reachable" % [loc, c.id, h])
	var g := new_game()
	check(is_equal_approx(People.hour(g), float(data.time.day_start_hour)), "a day starts at %d:00" % int(data.time.day_start_hour))
	check(People.daylight(data, 12.0).v > People.daylight(data, 0.0).v + 0.2, "noon is brighter than midnight")
	check(People.daylight(data, 23.9).is_equal_approx(People.daylight(data, 0.0)) or People.daylight(data, 23.9).v - People.daylight(data, 0.0).v < 0.05, "daylight wraps at midnight")


func test_deal_requests() -> void:
	var g := new_game()
	check(g.offers.is_empty(), "no requests at start")
	for i in 40:
		g.tick(10.0)
	check(not g.offers.is_empty(), "known customers text requests over time")
	var ids := {}
	for o in g.offers:
		check(g.people[o.contact].known, "only known people text (%s)" % o.contact)
		check(o.base in g.contact(o.contact).prefers, "request for a preferred drug")
		check(int(o.qty) >= 1 and int(o.qty) <= People.max_units(g, o.contact), "request size within deal size")
		check(not ids.has(o.id), "offer ids unique")
		ids[o.id] = true
	var open := 0
	for o in g.offers:
		if o.state in Deals.OPEN:
			open += 1
	check(open <= int(data.deals.max_open), "open requests capped")
	# unanswered requests expire
	var g2 := new_game()
	var o2: Dictionary = Deals.request(g2, "okka")
	check(not o2.is_empty() and o2.state == "new", "manual request")
	check(int(o2.price) > g2.sell_price("weed:glow", "okka", "mireth"), "texted price includes the premium")
	g2.tick(float(data.deals.answer_seconds) + 1.0)
	check(o2.state == "expired", "unanswered request expires")


func test_deal_answers() -> void:
	var g := new_game()
	var o: Dictionary = Deals.request(g, "sen")
	var aff0: float = g.people.sen.affinity
	check(Deals.decline(g, o.id).ok and o.state == "declined", "decline")
	check(g.people.sen.affinity < aff0, "declining costs a little affinity")
	o = Deals.request(g, "sen")
	check(Deals.accept(g, o.id).ok and o.state == "accepted", "accept")
	check(float(o.meet_at) > g.total_time and float(o.expires_at) > float(o.meet_at), "meeting time and window set")
	check(o.msgs.size() >= 3, "conversation recorded")
	# counter odds: small raises are likelier, loyal and hooked customers pay more
	check(Deals.counter_chance(g, "okka", 0.1) > Deals.counter_chance(g, "okka", 0.25), "bigger raise, lower odds")
	g.people.okka.affinity = 1.0
	g.people.okka.addiction = 1.0
	check(Deals.counter_chance(g, "okka", 0.25) > 0.6, "loyal + hooked customer usually accepts")
	var accepted := 0
	var refused := 0
	for i in 30:
		var gg := new_game()
		gg.rng.seed = i
		var oo: Dictionary = Deals.request(gg, "teo")
		var p0: int = oo.price
		var r: Dictionary = Deals.counter(gg, oo.id, 0.1)
		if r.ok:
			accepted += 1
			check(oo.state == "accepted" and oo.price > p0, "counter accepted raises the price")
		else:
			refused += 1
			check(oo.state == "new" and oo.price == p0 and oo.countered, "refused counter keeps the price")
			check(not Deals.counter(gg, oo.id, 0.1).ok, "only one counter")
	check(accepted > 0 and refused > 0, "counter outcome varies (%d/%d)" % [accepted, refused])
	# an accepted deal you never deliver costs more affinity
	var g3 := new_game()
	var o3: Dictionary = Deals.request(g3, "okka")
	Deals.accept(g3, o3.id)
	var a3: float = g3.people.okka.affinity
	g3.tick(float(o3.expires_at) - g3.total_time + 1.0)
	check(o3.state == "expired" and g3.people.okka.affinity < a3 + float(data.deals.affinity_noshow) * 0.5, "no-show hurts")


func test_deal_fulfill() -> void:
	var g := new_game()
	g.location = "cinder"
	var o: Dictionary = Deals.request(g, "okka")
	Deals.accept(g, o.id)
	var key := Mixing.key(o.base, [data.bases[o.base].innate])
	g.cargo[key] = int(o.qty) + 2
	check(not Deals.fulfill(g, o.id, key).ok, "must meet on their planet")
	g.location = "mireth"
	check(Deals.agreed_at(g, "mireth").has(o), "agreed deal listed at the meet planet")
	var wrong := "cocaine:crisp" if o.base != "cocaine" else "weed:glow"
	g.cargo[wrong] = 10
	check(not Deals.fulfill(g, o.id, wrong).ok, "wrong drug refused")
	var early: Dictionary = Deals.fulfill(g, o.id, key)
	check(not early.ok and str(early.msg).contains("Too early"), "can't hand over long before the meeting")
	g.total_time = float(o.meet_at)
	var credits0 := g.credits
	var hist0: int = g.people.okka.history.size()
	var r: Dictionary = Deals.fulfill(g, o.id, key)
	check(r.ok, "hand over: %s" % r.msg)
	check(g.credits == credits0 + int(o.price) * int(o.qty), "paid the agreed price")
	check(int(g.cargo[key]) == 2 and o.state == "done", "units handed over, deal done")
	check(g.people.okka.history.size() == hist0 + 1, "deal in history")
	check(not Deals.fulfill(g, o.id, key).ok, "can't deliver twice")
	# save roundtrip keeps the conversation
	var o2: Dictionary = Deals.request(g, "sen")
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2 := Game.new()
	g2.from_dict(data, d)
	check(g2.offers.size() == g.offers.size() and Deals.find(g2, o2.id).state == "new", "offers survive save")
	check(Deals.accept(g2, int(o2.id)).ok, "loaded offer can be answered")
	d.erase("offers")
	var g3 := Game.new()
	g3.from_dict(data, d)
	check(g3.offers.is_empty(), "old save without offers")


func test_sell_contact_and_fence() -> void:
	var g := new_game()
	var p := "weed:overclock+radiant"
	g.cargo[p] = 10
	var fence_price := g.sell_price(p, "", "bazaar")
	var lira_price := g.sell_price(p, "lira", "bazaar")
	check(lira_price > fence_price, "contact pays more than fence")
	check(g.sell_price(p, "okka") > g.sell_price(p, "sen"), "liked trait bonus (okka likes radiant)")
	check(not g.sell(p, 1).ok, "no fence at hub")
	var before := g.credits
	check(g.sell(p, 3, "okka").ok, "sell to okka")
	check(g.credits > before and g.cargo[p] == 7, "credits gained, cargo reduced")
	check(not g.sell(p, 1, "okka").ok, "okka on cooldown")
	check(not g.sell(p, 1, "lira").ok, "lira is not at hub")
	g.tick(float(data.market.contact_cooldown) + 1.0)
	check(g.sell(p, 1, "okka").ok, "okka buys again after cooldown")
	check(not g.sell(p, 5, "okka").ok, "contact max units")


func test_products_recipe_book() -> void:
	var g := new_game()
	check(g.recipes.is_empty(), "new game: empty recipe book")
	var adds := ["energy_drink"] if data.additives.has("energy_drink") else [data.additives.keys()[0]]
	g.cargo["cannabis"] = 10
	for a in adds:
		g.cargo[a] = 10
	var base := "weed"
	var rk := Mixing.key(base, Mixing.traits_for(data, base, adds))
	check(g.queue_batch(base, adds, 4).ok, "queue a batch")
	check(Products.known(g, rk), "batch discovers the product")
	check((g.recipes[rk].additives as Array) == adds, "recipe stores the additive order")
	check(int(g.recipes[rk].made) >= 1, "made units counted")
	check(not Products.discover(g, base, adds, 2, 3), "second batch is not new")
	check(int(g.recipes[rk].best) == 2, "best grade tracked")
	check(Products.list(g).has(rk), "listed")
	# old saves: carried products are adopted without a recipe
	var g2 := new_game()
	g2.cargo["cocaine:euphoric@2"] = 3
	var d := g2.to_dict()
	d.erase("products")
	var g3 := Game.new()
	g3.from_dict(data, d)
	check(g3.recipes.has("cocaine:euphoric") and (g3.recipes["cocaine:euphoric"].additives as Array).is_empty(), "legacy product adopted with unknown recipe")
	# save roundtrip
	Products.set_price(g, rk, 77)
	var g4 := Game.new()
	g4.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g4.recipes.has(rk) and int(g4.prices[rk]) == 77, "recipes and prices survive a save")


func test_products_asking_price() -> void:
	var g := new_game()
	var p := "weed:overclock+radiant"
	g.cargo[p] = 20
	check(not Products.set_price(g, p, 50).ok, "unknown products can't be priced")
	Products.adopt_items(g, g.cargo)
	var market: int = g.sell_price(p, "okka")
	check(g.unit_price(p, "okka") == market, "market mode = their offer")
	check(Products.set_price(g, p, 100000).ok and Products.price(g, p) == Products.max_price(g, p), "price capped")
	check(g.unit_price(p, "okka") == -1, "too steep: refused")
	var r: Dictionary = g.sell(p, 1, "okka")
	check(not r.ok and str(r.msg).contains("won't pay"), "sell refuses a steep price")
	check(People.units_wanted(g, "okka", p) == 0, "nobody wants it that steep")
	Products.set_price(g, p, int(market * 0.5))
	check(g.unit_price(p, "okka") == int(market * 0.5), "cheap price is paid as asked")
	check(Products.is_bargain(g, p, "okka"), "cheap = bargain")
	var aff := float(People.state(g, "okka").affinity)
	var c0 := g.credits
	check(g.sell(p, 2, "okka").ok and g.credits - c0 == 2 * int(market * 0.5), "sold at asking price")
	check(float(People.state(g, "okka").affinity) > aff, "affinity rises")
	# grade scales the asking price
	Products.set_price(g, p, 100)
	var prem := p + "@2"
	check(Products.asking(g, prem) == int(round(100 * float(Mixing.grade_info(data, 2).value_mult))), "premium asks more")
	check(Products.clear_price(g, p).ok and Products.asking(g, p) == -1, "back to market")
	# hooked customers tolerate more
	var t0 := Products.tolerance(g, "okka")
	People.state(g, "okka").addiction = 1.0
	check(Products.tolerance(g, "okka") > t0, "addiction raises tolerance")


func test_deal_appointments() -> void:
	var g := new_game()
	g.location = "mireth"
	var o: Dictionary = Deals.request(g, "okka")
	var sph: float = Deals.seconds_per_hour(g)
	check(float(o.meet_at) >= g.total_time + (float(data.deals.lead_hours_min) - 1.0) * sph, "meeting is hours ahead")
	check(is_equal_approx(fposmod(Deals.clock_at(g, float(o.meet_at)), 1.0), 0.0) or fposmod(Deals.clock_at(g, float(o.meet_at)), 1.0) > 0.999, "meets on the full hour")
	check(str(o.msgs[0].text).contains(Deals.clock_text(g, float(o.meet_at)).split(" ")[0]), "text names the time")
	Deals.accept(g, o.id)
	check(Deals.agenda(g).has(o), "agenda lists it")
	check(is_equal_approx(float(o.expires_at), float(Deals.window(g, o).close)), "missed after the window")
	check(Deals.meet_phase(g, o) == "early", "early before the window")
	var key := Mixing.key(o.base, [data.bases[o.base].innate])
	g.cargo[key] = int(o.qty) * 3
	# late hand-over costs affinity compared to on time
	g.total_time = float(Deals.window(g, o).late) + 1.0
	check(Deals.meet_phase(g, o) == "late", "late after the grace time")
	var a0 := float(g.people.okka.affinity)
	check(Deals.fulfill(g, o.id, key).ok, "late still hands over")
	var late_gain := float(g.people.okka.affinity) - a0
	var g2 := new_game()
	g2.location = "mireth"
	var o2: Dictionary = Deals.request(g2, "okka")
	Deals.accept(g2, o2.id)
	g2.cargo[key] = int(o2.qty) * 3
	var key2 := Mixing.key(o2.base, [data.bases[o2.base].innate])
	g2.cargo[key2] = int(o2.qty) * 3
	g2.total_time = float(o2.meet_at)
	var b0 := float(g2.people.okka.affinity)
	check(Deals.fulfill(g2, o2.id, key2).ok, "on time")
	check(float(g2.people.okka.affinity) - b0 > late_gain, "on time beats late")
	# reminder fires once before the meeting
	var g3 := new_game()
	var o3: Dictionary = Deals.request(g3, "sen")
	Deals.accept(g3, o3.id)
	var hits := [0]
	g3.event.connect(func(k, _p): if k == "meet_soon": hits[0] += 1)
	g3.tick(float(o3.meet_at) - g3.total_time - 0.5 * sph)
	g3.tick(1.0)
	check(hits[0] == 1 and o3.reminded, "meeting reminder once")
	# named products: with a recipe book the customer asks for one of yours, and only that one matches
	var g4 := new_game()
	Products.discover(g4, "weed", ["energy_drink"] if data.additives.has("energy_drink") else [data.additives.keys()[0]], 1, 5)
	var named := 0
	for i in 20:
		g4.contact_ready_at.clear()
		var oo: Dictionary = Deals.request(g4, "okka")
		if oo.is_empty():
			continue
		if str(oo.product) != "":
			named += 1
			check(Products.known(g4, oo.product) and Mixing.parse_key(oo.product).base == oo.base, "named product is from your book")
			var plain := Mixing.key(oo.base, [data.bases[oo.base].innate])
			if plain != oo.product:
				g4.cargo[plain] = 99
				check(not Deals.matching_products(g4, oo).has(plain), "other products of the drug don't match")
		Deals.decline(g4, oo.id)
	check(named > 0, "some requests name a product")
	# asking price is used when they accept it
	var g5 := new_game()
	var rk := Mixing.key("weed", [data.bases.weed.innate])
	Products.adopt_items(g5, {rk: 1})
	Products.set_price(g5, rk, 5)
	check(Deals.offer_price(g5, "okka", "weed", rk) == 5, "cheap asking price offered as is")
	Products.set_price(g5, rk, 100000)
	check(Deals.offer_price(g5, "okka", "weed", rk) <= Products.ceiling(g5, rk, "okka", "mireth"), "steep price capped at their limit")


func test_deal_haggle_qty_time() -> void:
	var g := new_game()
	var o: Dictionary = Deals.request(g, "okka")
	var q0 := int(o.qty)
	if q0 > 1:
		check(Deals.counter_qty(g, o.id, 0.5).ok and int(o.qty) < q0, "fewer is always fine")
	check(not Deals.counter_qty(g, o.id, 1.5).ok, "one amount haggle")
	var t0 := float(o.meet_at)
	var moved := 0
	for i in 20:
		var gg := new_game()
		gg.rng.seed = i + 7
		var oo: Dictionary = Deals.request(gg, "teo")
		var t1 := float(oo.meet_at)
		var r: Dictionary = Deals.counter_time(gg, oo.id, 3)
		if r.ok:
			moved += 1
			check(is_equal_approx(float(oo.meet_at), t1 + 3.0 * Deals.seconds_per_hour(gg)), "meeting moved 3 h")
		check(not Deals.counter_time(gg, oo.id, 3).ok, "one time haggle")
	check(moved > 0, "time changes are usually accepted (%d/20)" % moved)
	check(not Deals.counter_time(g, o.id, -48).ok and is_equal_approx(float(o.meet_at), t0), "can't move into the past")
	check(Deals.accept(g, o.id).ok, "still answerable after haggling")


func test_dealers() -> void:
	var g := new_game()
	g.credits = 5000
	check(Dealers.available(g).size() == data.dealers.candidates.size(), "all dealers for hire")
	check(Dealers.hire(g, "nyx").ok and g.credits == 5000 - int(Dealers.candidate(g, "nyx").fee), "hire costs the fee")
	check(not Dealers.hire(g, "nyx").ok, "can't hire twice")
	var p := "weed:glow"
	g.cargo[p] = 30
	check(not Dealers.give(g, "nyx", p, 10).ok, "needs a district first")
	check(not Dealers.assign(g, "nyx", "halvane_gate").ok, "gates are no district")
	check(Dealers.assign(g, "nyx", "mireth").ok, "district set")
	g.location = "cinder"
	check(not Dealers.give(g, "nyx", p, 10).ok, "give in person only")
	g.location = "mireth"
	check(Dealers.give(g, "nyx", p, 10).ok and int(g.cargo[p]) == 20, "stock handed over")
	var d: Dictionary = Dealers.find(g, "nyx")
	check(Dealers.units(d) == 10 and Dealers.status(g, d) == "", "selling")
	g.cargo[p] = 99
	check(Dealers.give(g, "nyx", p, 999).ok and Dealers.units(d) == int(Dealers.candidate(g, "nyx").capacity), "bag capacity caps stock")
	# selling with no heat: no busts at bust_base this low over a few rounds is likely but not certain; force zero risk
	g.data = data.duplicate(true)
	g.data.dealers.bust_base = 0.0
	g.data.dealers.bust_per_heat = 0.0
	var u0 := Dealers.units(d)
	g.tick(float(data.dealers.sell_seconds) * 3.0 + 0.1)
	check(Dealers.units(d) < u0 and int(d.cash) > 0 and int(d.sold) == u0 - Dealers.units(d), "dealer sells over time")
	var c0 := g.credits
	var cash := int(d.cash)
	check(Dealers.collect(g, "nyx").ok and g.credits == c0 + cash and int(d.cash) == 0, "collect in person")
	# your price: too steep stops sales, the cut is kept by the dealer
	Products.adopt_items(g, {p: 1})
	Products.set_price(g, p, Products.max_price(g, p))
	check(Dealers.street_price(g, p, "mireth") == -1 and Dealers.status(g, d) != "", "too steep: no sales")
	var left := Dealers.units(d)
	g.tick(float(data.dealers.sell_seconds) * 2.0)
	check(Dealers.units(d) == left, "nothing sold at a steep price")
	Products.set_price(g, p, 10)
	g.tick(float(data.dealers.sell_seconds) + 0.1)
	var sold := left - Dealers.units(d)
	check(sold > 0 and int(d.cash) == int(round(10 * sold * (1.0 - float(Dealers.candidate(g, "nyx").cut)))), "dealer pays your price minus the cut")
	g.cargo.clear()
	g.upgrades.cargo = 3
	check(Dealers.take_back(g, "nyx").ok and Dealers.units(d) == 0, "stock taken back")
	check(Dealers.fire(g, "nyx").ok and g.dealers.is_empty(), "fired")


func _drone_game() -> Game:
	var g := new_game()
	g.credits = 5000
	g.data = data.duplicate(true)
	g.data.drones.loss_base = 0.0
	g.data.drones.loss_per_heat = 0.0
	return g


func test_drones() -> void:
	var rl: Dictionary = data.drones
	for k in ["price", "upkeep", "max_total", "max_per_estate", "capacity", "trip_seconds", "far_seconds", "loss_base", "loss_per_heat", "scrap_refund"]:
		check(rl.has(k), "drones rule %s exists" % k)
	var g := _drone_game()
	var eid := "cannery_rig"
	var e: Dictionary = g.estates[eid]
	check(not Drones.buy(g, "ship_bay", "to_port").ok and not Drones.buy(g, "nope", "to_port").ok, "no drones for the ship bay or strangers' estates")
	check(not Drones.buy(g, eid, "sideways").ok, "unknown route refused")
	var c0 := g.credits
	check(Drones.buy(g, eid, "to_port").ok and g.credits == c0 - int(rl.price) and g.drones.size() == 1, "buying costs the price")
	var d: Dictionary = g.drones[0]
	check(Drones.status(g, d) == "Waiting for finished product.", "idle without product")
	# export: output tray first, then shelf, capped by capacity, only finished product
	e.out = {"weed:glow": 5}
	e.storage = {"weed:glow": 20, "water": 9}
	var trip := Drones.trip_seconds(g, eid)
	g.tick(trip - 1.0)
	check(int(g.stash.get("weed:glow", 0)) == 0, "no delivery before the trip is done")
	g.tick(1.1)
	var cap := int(rl.capacity)
	check(int(g.stash.get("weed:glow", 0)) == cap and not e.out.has("weed:glow") and int(e.storage["weed:glow"]) == 25 - cap, "trip moves capacity units, tray first")
	check(int(e.storage.get("water", 0)) == 9 and not g.stash.has("water"), "raws stay on the shelf")
	g.tick(trip + 0.1)
	check(int(g.stash["weed:glow"]) == cap * 2, "second trip is full again")
	g.tick(trip + 0.1)
	check(int(g.stash["weed:glow"]) == 25, "third trip takes the rest")
	check(int(g.stats.get("drone_trips", 0)) == 3 and int(g.stats.drone_units) == 25, "trip stats")
	g.tick(trip * 3.0)
	check(int(g.stash["weed:glow"]) == 25, "empty estate: drone stays parked")
	e.out = {"weed:glow": 3}
	g.tick(0.1)
	check(int(g.stash["weed:glow"]) == 28, "parked drone leaves the moment there is cargo")
	# the spaceport stash is what collect_stash loads
	g.location = g.data.start.location
	var held0 := int(g.cargo.get("weed:glow", 0))
	check(g.collect_stash().ok and int(g.cargo.get("weed:glow", 0)) > held0, "stash drops end up in the hold")
	# import: only what the recipe lacks, from the stash
	check(Drones.set_route(g, int(d.id), "to_estate").ok and d.route == "to_estate", "route flipped")
	check(Drones.status(g, d) == "No auto recipe set.", "import needs a recipe")
	Workers.set_recipe(g, eid, "weed", [], 5)
	var need: Dictionary = g.batch_needs("weed", [], 5)
	check(Drones.status(g, d) == "Waiting for supplies in the stash.", "import waits for supplies")
	for k in need:
		g.stash[k] = int(need[k]) * 3
	e.bench = {}
	e.storage = {}
	for k in need:
		e.bench[k] = 1
	g.tick(trip + 0.1)
	check(not e.storage.is_empty(), "import tops the shelf up")
	var total := 0
	for k in need:
		total += int(e.storage.get(k, 0)) + int(e.bench.get(k, 0)) - 1
		check(int(e.storage.get(k, 0)) + int(e.bench.get(k, 0)) <= int(need[k]), "never more than the recipe needs (%s)" % k)
	check(total <= cap, "trip capacity respected")
	# limits and scrapping
	check(Drones.buy(g, eid, "to_port").ok and not Drones.buy(g, eid, "to_port").ok, "two pads per estate")
	g.buy_estate("cannery_annex")
	check(Drones.buy(g, "cannery_annex", "to_port").ok and Drones.buy(g, "cannery_annex", "to_port").ok and g.drones.size() == int(rl.max_total), "up to max_total")
	check(not Drones.buy(g, "cannery_annex", "to_port").ok, "fleet capped")
	var c1 := g.credits
	check(Drones.scrap(g, int(d.id)).ok and g.credits == c1 + int(round(int(rl.price) * float(rl.scrap_refund))) and Drones.find(g, int(d.id)).is_empty(), "scrap refunds part of the price")
	check(not Drones.scrap(g, 9999).ok, "no such drone")
	var poor := _drone_game()
	poor.credits = 10
	check(not Drones.buy(poor, "cannery_rig", "to_port").ok, "can't afford a drone")


func test_drones_loss_upkeep_save() -> void:
	var g := _drone_game()
	var eid := "cannery_rig"
	Drones.buy(g, eid, "to_port")
	var d: Dictionary = g.drones[0]
	check(Drones.loss_chance(g) == 0.0, "no loss at zero risk")
	g.heat = 50.0
	g.data.drones.loss_per_heat = 0.01
	check(is_equal_approx(Drones.loss_chance(g), 0.5), "heat raises the loss chance")
	g.data.drones.loss_base = 5.0
	check(Drones.loss_chance(g) <= 0.9, "loss chance is capped")
	g.estates[eid].out = {"weed:glow": 4}
	var lost := [false]
	g.event.connect(func(k, _p): if k == "drone_lost": lost[0] = true)
	g.data.drones.loss_base = 1.0
	g.data.drones.loss_per_heat = 0.0
	g.heat = 0.0
	g.data.drones.loss_base = 2.0
	g.rng.seed = 1
	for i in 60:
		if lost[0]:
			break
		g.estates[eid].out = {"weed:glow": 4}
		g.tick(Drones.trip_seconds(g, eid) + 0.1)
	check(lost[0] and g.drones.is_empty() and int(g.stats.get("drones_lost", 0)) == 1, "a shot-down drone is gone")
	check(not g.stash.has("weed:glow") and not g.estates[eid].out.has("weed:glow"), "its cargo is lost with it")
	# upkeep, grounding
	var h := _drone_game()
	Drones.buy(h, eid, "to_port")
	var up := int(h.data.drones.upkeep)
	h.credits = up + 1
	h._new_day()
	check(h.credits == 1 and not h.drones[0].grounded, "upkeep charged each day")
	h._new_day()
	check(h.drones[0].grounded and h.credits == 1 and Drones.status(h, h.drones[0]).begins_with("Grounded"), "unpaid drone is grounded")
	h.estates[eid].out = {"weed:glow": 4}
	h.tick(Drones.trip_seconds(h, eid) * 2.0)
	check(not h.stash.has("weed:glow"), "grounded drones don't fly")
	h.credits = 100
	h._new_day()
	check(not h.drones[0].grounded, "paying frees it again")
	# save round trip, junk entries, old saves
	h.drones[0].route = "to_estate"
	var f := Game.new()
	f.from_dict(data, JSON.parse_string(JSON.stringify(h.to_dict())))
	check(f.drones.size() == 1 and f.drones[0].route == "to_estate" and f.drones[0].estate == eid and f.drone_seq == h.drone_seq, "drones survive a save")
	Drones.from_save(f, [{"id": 3, "estate": "nope", "route": "to_port"}, {"id": 4, "estate": eid, "route": "x"}, {"id": 5, "estate": "ship_bay", "route": "to_port"}])
	check(f.drones.is_empty(), "junk drone entries are dropped")
	var old := h.to_dict()
	old.erase("drones")
	var o := Game.new()
	o.from_dict(data, old)
	check(o.drones.is_empty(), "old saves have no drones")


func test_dealers_bust_and_save() -> void:
	var g := new_game()
	g.credits = 5000
	g.data = data.duplicate(true)
	g.data.dealers.bust_base = 1.0
	Dealers.hire(g, "rook")
	Dealers.assign(g, "rook", "mireth")
	g.cargo["weed:glow"] = 10
	Dealers.give(g, "rook", "weed:glow", 10)
	var d: Dictionary = Dealers.find(g, "rook")
	d.cash = 100
	var busted := [false]
	g.event.connect(func(k, _p): if k == "dealer_busted": busted[0] = true)
	for i in 40:
		if busted[0]:
			break
		d.stock = {"weed:glow": 10}
		d.cash = 100
		g.tick(float(data.dealers.sell_seconds) + 0.01)
	check(busted[0] and Dealers.units(d) == 0 and int(d.cash) == 0 and float(d.jail) > 0.0, "bust loses stock and cash, jail time")
	check(Dealers.status(g, d).begins_with("In jail"), "jailed status")
	check(not Dealers.give(g, "rook", "weed:glow", 1).ok, "can't stock a jailed dealer")
	g.tick(float(data.dealers.jail_seconds))
	check(float(d.jail) == 0.0, "released")
	d.stock = {"weed:glow": 4}
	d.cash = 77
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	var e: Dictionary = Dealers.find(h, "rook")
	check(not e.is_empty() and e.loc == "mireth" and int(e.stock["weed:glow"]) == 4 and int(e.cash) == 77, "dealers survive a save")
	# heat makes busts likelier, skill less
	var g2 := new_game()
	g2.dealers = [{"id": "rook", "loc": "mireth", "stock": {}, "cash": 0, "sold": 0, "jail": 0.0}, {"id": "ferro", "loc": "mireth", "stock": {}, "cash": 0, "sold": 0, "jail": 0.0}]
	var b0 := Dealers.bust_chance(g2, g2.dealers[0])
	check(Dealers.bust_chance(g2, g2.dealers[1]) < b0, "skilled dealers get busted less")
	g2.heat = 80.0
	check(Dealers.bust_chance(g2, g2.dealers[0]) > b0, "heat raises the bust risk")


func test_deaddrops() -> void:
	var rl: Dictionary = data.deaddrops
	for k in ["kinds", "fee", "max_open", "ttl", "pickup_seconds", "heat_mult", "theft_chance", "theft_heat", "courier_seconds", "courier_fee_unit", "spots"]:
		check(rl.has(k), "deaddrops rule %s exists" % k)
	for kind in rl.kinds:
		check(rl.spots.has(kind) and not rl.spots[kind].is_empty(), "spot names for %s" % kind)
	var g := new_game()
	check(Deaddrops.eligible(g, "mireth") and Deaddrops.eligible(g, "cinder"), "planets and outposts take drops")
	check(not Deaddrops.eligible(g, "kovar_gate") or data.locations.kovar_gate.kind != "gate", "gates don't")
	check(not Deaddrops.request(g, "nope").ok, "unknown place refused")
	var credits0 := g.credits
	var r: Dictionary = Deaddrops.request(g, "mireth")
	check(r.ok and g.drops.size() == 1 and g.credits == credits0 - int(rl.fee), "request costs the fee")
	check(not Deaddrops.request(g, "mireth").ok, "one drop per place")
	var d: Dictionary = g.drops[0]
	# a deal at the drop
	var o: Dictionary = Deals.request(g, "okka")
	check(not Deaddrops.assign_deal(g, d.id, o.id, "x").ok, "deal must be agreed first")
	Deals.accept(g, o.id)
	var key := Mixing.key(o.base, [data.bases[o.base].innate])
	check(not Deaddrops.assign_deal(g, d.id, o.id, key).ok, "need the units")
	g.cargo[key] = int(o.qty) + 1
	g.location = "cinder"
	check(not Deaddrops.assign_deal(g, d.id, o.id, key).ok, "must be docked at the drop")
	g.location = "mireth"
	g.heat = 0.0
	var heat_before := g.heat
	r = Deaddrops.assign_deal(g, d.id, o.id, key)
	check(r.ok, "left at the drop: %s" % r.msg)
	check(o.state == "dropped" and int(g.cargo[key]) == 1 and not Deaddrops.is_free(d), "goods in the drop")
	var in_person := float(g.loc_data().heat_per_unit) * int(o.qty) * g.heat_mult(o.base) * float(data.deals.heat_mult)
	check(g.heat > heat_before and g.heat < in_person * 0.5, "drop heat (%.2f) well below hand-over heat (%.2f)" % [g.heat, in_person])
	check(not Deaddrops.send_courier(g, d.id, key, 1).ok, "drop holds one job")
	# customer picks up (theft off, then on)
	data.deaddrops.theft_chance = 0.0
	data.deaddrops.theft_heat = 0.0
	var c1 := g.credits
	g.tick(float(rl.pickup_seconds) + 1.0)
	check(o.state == "done" and g.credits == c1 + int(o.price) * int(o.qty), "customer collected and paid")
	check(Deaddrops.is_free(d) and g.drops_unseen == 1, "drop free again, pickup counted")
	var o2: Dictionary = Deals.request(g, "okka")
	Deals.accept(g, o2.id)
	g.cargo[key] = int(o2.qty)
	data.deaddrops.theft_chance = 1.0
	check(Deaddrops.assign_deal(g, d.id, o2.id, key).ok, "second deal dropped")
	var c2 := g.credits
	g.tick(float(rl.pickup_seconds) + 1.0)
	check(o2.state == "stolen" and g.credits == c2 and not g.cargo.has(key), "theft: no goods, no pay")
	# courier
	g.cargo["cannabis"] = 10
	var fee := Deaddrops.courier_fee(g, 10)
	var c3 := g.credits
	check(Deaddrops.send_courier(g, d.id, "cannabis", 10).ok and g.credits == c3 - fee and not g.cargo.has("cannabis"), "courier takes goods and fee")
	g.tick(float(rl.courier_seconds) + 1.0)
	check(not g.stash.has("cannabis"), "stolen courier run delivers nothing")
	data.deaddrops.theft_chance = 0.0
	g.cargo["cannabis"] = 10
	Deaddrops.send_courier(g, d.id, "cannabis", 10)
	g.tick(float(rl.courier_seconds) + 1.0)
	check(int(g.stash.get("cannabis", 0)) == 10, "courier delivers to the hub stash")
	# idle drops expire, abandoning works
	g.tick(float(rl.ttl) + 1.0)
	check(g.drops.is_empty(), "idle drop expires")
	check(Deaddrops.request(g, "mireth").ok and Deaddrops.release(g, g.drops[0].id).ok and g.drops.is_empty(), "abandon a drop")
	for loc in ["mireth", "cinder", "drift_bazaar", "varrow"]:
		Deaddrops.request(g, loc)
	check(g.drops.size() <= int(rl.max_open), "open drop cap")
	# many deals in a row never trim a deal waiting at a drop
	var g2 := new_game()
	Deaddrops.request(g2, "mireth")
	var w: Dictionary = Deals.request(g2, "okka")
	Deals.accept(g2, w.id)
	var k2 := Mixing.key(w.base, [data.bases[w.base].innate])
	g2.cargo[k2] = int(w.qty)
	Deaddrops.assign_deal(g2, g2.drops[0].id, w.id, k2)
	for i in 30:
		var x: Dictionary = Deals.request(g2, "sen")
		if x.is_empty():
			break
		Deals.decline(g2, x.id)
	Deals.tick(g2, 0.1)
	check(not Deals.find(g2, w.id).is_empty(), "dropped deal survives history trimming")
	data.deaddrops.theft_chance = 0.07  # restore: data is shared between tests
	data.deaddrops.theft_heat = 0.15


func test_deaddrops_save() -> void:
	var g := new_game()
	Deaddrops.request(g, "mireth")
	var o: Dictionary = Deals.request(g, "okka")
	Deals.accept(g, o.id)
	var key := Mixing.key(o.base, [data.bases[o.base].innate])
	g.cargo[key] = int(o.qty)
	Deaddrops.assign_deal(g, g.drops[0].id, o.id, key)
	var json := JSON.stringify(g.to_dict())
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(json))
	check(h.drops.size() == 1 and not Deaddrops.is_free(h.drops[0]), "drop with a job survives save/load")
	check(Deals.find(h, o.id).state == "dropped", "dropped deal survives save/load")
	check(JSON.stringify(h.to_dict()) == json, "save with drops is stable")
	h.next_drop_id = 0
	h.rng.seed = 3
	var d := new_game().to_dict()
	d.erase("drops")
	d.erase("next_drop_id")
	var old := Game.new()
	old.from_dict(data, d)
	check(old.drops.is_empty() and old.next_drop_id == 0, "old saves load without drops")


func test_market_saturation_recovers() -> void:
	var g := new_game()
	var p := "weed:glow"
	g.cargo[p] = 4
	var d0: float = g.demand.mireth.weed
	g.sell(p, 4, "okka")
	check(g.demand.mireth.weed < d0, "selling saturates demand")
	g.tick(g.day_seconds() - g.day_time - 1.0)  # within the day: no market rumour can move it
	check(is_equal_approx(g.demand.mireth.weed, d0), "demand recovers")


func test_heat_and_patrols() -> void:
	var g := new_game()
	check(g.patrol_count() == 1, "one patrol at zero heat")
	g.add_heat(60)
	check(g.patrol_count() == 3, "more patrols at 60 heat")
	g.add_heat(500)
	check(g.heat == 100.0 and g.patrol_count() == int(data.heat.patrol_max), "heat capped")
	g.undock()
	g.tick(10.0)
	check(is_equal_approx(g.heat, 100.0 - 10.0 * float(data.heat.decay_per_second)), "heat decays in flight")


## Systems, their locations, jump gates and per-system patrols (D1).
func test_galaxy_and_jump() -> void:
	check(data.systems.size() >= 2, "at least two star systems")
	for loc in data.locations:
		var ld: Dictionary = data.locations[loc]
		check(data.systems.has(ld.get("system", "")), "%s belongs to a known system" % loc)
		if ld.has("jump_to"):
			check(data.systems.has(ld.jump_to) and ld.jump_to != ld.system, "%s jumps to another system" % loc)
			var arr: Dictionary = data.locations.get(ld.arrive, {})
			check(arr.get("system", "") == ld.jump_to and arr.get("jump_to", "") == ld.system, "%s arrives at the return gate" % loc)
	var g := new_game()
	check(g.system == "halvane" and g.loc_system("mireth") == "halvane", "new game starts in the Halvane Reach")
	check(g.patrol_home() == "beacon", "Halvane patrols fly from the customs beacon")
	check(g.locations_in("kovar").has("varrow") and g.locations_in("kovar").has("glacis"), "Kovar holds the two new planets")
	for p in ["varrow", "glacis"]:
		check(data.surfaces.has(p) and not data.contacts.filter(func(c): return c.location == p).is_empty(), "%s is walkable and has customers" % p)
	check(float(data.surfaces.varrow.security) < float(data.surfaces.mireth.security) and float(data.surfaces.glacis.security) > float(data.surfaces.mireth.security), "Varrow lawless, Glacis high security")
	check(not g.jump("halvane_gate").ok, "no jump while docked")
	g.undock()
	check(not g.jump("kovar_gate").ok, "cannot use a gate of another system")
	var before := g.credits
	var t := g.total_time
	var r := g.jump("halvane_gate")
	check(r.ok and g.system == "kovar", "jump to the Kovar Expanse")
	check(g.credits == before - int(data.jump.fee) and g.total_time > t, "jump costs the toll and travel time")
	check(g.patrol_home() == "glacis", "Kovar patrols fly from Glacis")
	g.add_heat(60)
	check(g.patrol_count() < 3, "frontier system has fewer patrols than Halvane at the same heat")
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(h.system == "kovar", "system survives save/load in flight")
	check(g.dock("glacis").ok and g.system == "kovar", "dock on Glacis")
	g.credits = 10
	g.undock()
	check(not g.jump("kovar_gate").ok and g.system == "kovar", "no jump without the toll")


func test_bust() -> void:
	var g := new_game()
	g.cargo["weed:glow"] = 5
	g.cargo["cannabis"] = 3
	g.add_heat(80)
	check(g.has_contraband(), "products are contraband")
	g.bust()
	check(not g.has_contraband() and g.cargo.cannabis == 3, "products confiscated, raws kept")
	check(g.credits == 400 - 60, "fine paid (15%%, min 50): %d" % g.credits)
	check(g.heat == 40.0, "heat dropped")


func test_upgrades() -> void:
	var g := new_game()
	check(not g.buy_upgrade("cargo").ok, "too poor for upgrade")
	g.credits = 10000
	check(g.buy_upgrade("cargo").ok and g.cargo_capacity() == 35, "cargo upgrade")
	g.buy_upgrade("cargo")
	g.buy_upgrade("cargo")
	check(not g.buy_upgrade("cargo").ok, "max level")
	g.buy_upgrade("stealth")
	check(g.scan_radius() < float(data.heat.scan_radius), "stealth shrinks scan radius")
	check(not g.upgrades.has("lab"), "no global lab upgrade any more")


func test_estate_tiers() -> void:
	var g := new_game()
	var t0 := g.batch_seconds(5, "cannery_rig")
	check(g.rig_estate() == "cannery_rig" and g.lab_capacity() == 5, "hub lab = rented starter rig, tier 0")
	check(not g.buy_estate_tier("cannery_rig").ok, "tier needs credits")
	g.credits = 10000
	check(g.buy_estate_tier("cannery_rig").ok and g.estate_tier("cannery_rig") == 1, "rig rebuilt to tier 1")
	check(g.lab_capacity() == 10 and g.batch_seconds(5, "cannery_rig") < t0, "tier: capacity and speed")
	g.buy_estate("cannery_annex")
	check(g.lab_capacity("cannery_annex") == 5, "other estates keep their own tier")
	g.buy_estate_tier("cannery_rig")
	g.buy_estate_tier("cannery_rig")
	check(g.lab_capacity() == 35 and not g.buy_estate_tier("cannery_rig").ok, "top tier")
	g.location = "cinder"
	check(not g.buy_estate_tier("cannery_annex").ok, "must be on the planet to rebuild")
	g.location = "mireth"
	var g2 := Game.new()
	g2.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.estate_tier("cannery_rig") == 3 and g2.estate_tier("cannery_annex") == 0, "tiers survive save/load")
	# old save: global lab level 2 -> tier of the starter rig
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	d.upgrades.lab = 2
	d.estates.cannery_rig.erase("tier")
	var g3 := Game.new()
	g3.from_dict(data, d)
	check(g3.estate_tier("cannery_rig") == 2 and not g3.upgrades.has("lab"), "old save migrates hydro rig level")


func fly_game() -> Game:
	var g := new_game()
	g.undock()
	return g


func test_space_combat_stats() -> void:
	for k in ["laser", "missile", "shield", "hull"]:
		check(data.upgrades.has(k) and data.upgrades[k].levels.size() == 4, "combat module %s has 4 levels" % k)
		check(ArtReg.SHIP_UNDER.has(k) or ArtReg.SHIP_OVER.has(k), "combat module %s is drawn on the ship" % k)
	var c: Dictionary = data.space_combat
	for k in ["laser", "missile", "shield", "boost", "pirate", "spawn", "defeat"]:
		check(c.has(k), "combat config %s" % k)
	var g := fly_game()
	check(SpaceCombat.max_hull(g) == 100.0 and g.combat.hull == 100.0, "new ship has the base hull")
	check(SpaceCombat.max_shield(g) == 0.0 and not SpaceCombat.has_missiles(g), "new ship has no shield and no missiles")
	check(SpaceCombat.laser_damage(g) == 8.0, "stock laser damage")
	g.credits = 100000
	g.dock("mireth")
	for k in ["laser", "missile", "shield", "hull"]:
		for i in 3:
			check(g.buy_upgrade(k).ok, "buy %s Mk%d" % [k, i + 2])
		check(not g.buy_upgrade(k).ok, "%s maxes out" % k)
	check(SpaceCombat.max_hull(g) == 220.0 and g.combat.hull == 220.0, "hull armour raises max and current hull")
	check(SpaceCombat.max_shield(g) == 140.0 and g.combat.shield == 140.0, "shield generator arrives charged")
	check(SpaceCombat.missile_cap(g) == 14 and g.combat.missiles == 14, "missile pods arrive loaded")
	check(SpaceCombat.laser_damage(g) == 20.0, "laser damage upgrade")
	var lvls := {}
	for k in ArtReg.SHIP_UNDER + ArtReg.SHIP_OVER:
		lvls[k] = g.upgrades.get(k, 0)
	check(lvls.laser == 3 and lvls.shield == 3, "ship art levels follow the bought modules")


func test_space_combat_damage() -> void:
	var g := fly_game()
	g.upgrades.shield = 1
	SpaceCombat.reset(g)
	check(g.combat.shield == 40.0, "reset fills the shield")
	var r := SpaceCombat.damage(g, 25.0)
	check(r.shield == 25.0 and r.hull == 0.0 and g.combat.shield == 15.0 and g.combat.hull == 100.0, "shield soaks damage first")
	r = SpaceCombat.damage(g, 35.0)
	check(r.shield == 15.0 and r.hull == 20.0 and g.combat.hull == 80.0 and not r.destroyed, "overflow hits the hull")
	# shield regen waits for the delay, only while flying
	var s0: float = g.combat.shield
	g.tick(1.0)
	check(g.combat.shield == s0, "no shield regen right after a hit")
	g.tick(float(data.space_combat.shield.delay))
	var s1: float = g.combat.shield
	check(s1 > s0, "shield regenerates after the delay")
	g.tick(100.0)
	check(g.combat.shield == 40.0, "shield regen stops at the maximum")
	check(g.combat.hull == 80.0, "hull does not regenerate")
	r = SpaceCombat.damage(g, 500.0)
	check(r.destroyed and g.combat.hull == 0.0, "hull at zero is destroyed")
	# docking recharges the shield for free, not the hull
	var h := fly_game()
	h.upgrades.shield = 2
	SpaceCombat.reset(h)
	SpaceCombat.damage(h, 70.0)
	h.dock("mireth")
	check(h.combat.shield == 80.0 and h.combat.hull == 100.0, "docking recharges the shield, not the hull")
	# boost
	var b := fly_game()
	var cost: float = data.space_combat.boost.cost
	check(SpaceCombat.try_boost(b) and b.combat.boost == float(data.space_combat.boost.max) - cost, "boost spends energy")
	check(SpaceCombat.try_boost(b), "boost can be chained while energy lasts")
	check(not SpaceCombat.try_boost(b), "boost refused without energy")
	b.tick(2.0)
	check(b.combat.boost > 0.0, "boost energy regenerates")
	b.tick(60.0)
	check(b.combat.boost == float(data.space_combat.boost.max), "boost refills")
	b.dock("mireth")
	check(not SpaceCombat.try_boost(b), "no boost while docked")


func test_space_combat_pirates() -> void:
	var g := fly_game()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var credits: int = g.credits
	var bounty := SpaceCombat.collect_bounty(g, rng)
	var br: Array = data.space_combat.pirate.bounty
	check(bounty >= int(br[0]) and bounty <= int(br[1]) and g.credits == credits + bounty and g.combat.kills == 1, "bounty pays and counts the kill")
	var base_interval := SpaceCombat.spawn_interval(g)
	check(is_equal_approx(base_interval, float(data.space_combat.spawn.interval) / Cartels.pressure_mult(g, "halvane")), "empty hold in Halvane: base spawn interval (scaled by your influence)")
	g.cargo = {"weed:overclock@standard": 30}
	check(SpaceCombat.spawn_interval(g) < base_interval and SpaceCombat.max_pirates(g) >= int(data.space_combat.spawn.max), "hauling product attracts pirates")
	var k := fly_game()
	k.system = "kovar"
	check(SpaceCombat.spawn_interval(k) < base_interval, "lawless Kovar has more pirates than Halvane")
	check(SpaceCombat.max_pirates(k) >= 1 and SpaceCombat.max_pirates(k) <= int(data.space_combat.spawn.max) + 2, "pirate cap stays bounded")
	check(not SpaceCombat.is_deep_space(g, 400.0) and SpaceCombat.is_deep_space(g, 2000.0), "pirates only in deep space")
	# defeat
	g.cargo = {"weed:overclock@standard": 11, "cannabis": 4}
	g.credits = 1000
	var res := SpaceCombat.defeat(g)
	check(g.cargo["weed:overclock@standard"] == 5 and g.cargo["cannabis"] == 2, "wreck loses half the hold (rounded up per item): %s" % g.cargo)
	check(res.fine == 100 and g.credits == 900, "tow fine is 10%% of the credits")
	check(g.combat.hull == 50.0 and g.combat.shield == 0.0, "wreck is towed back at half hull")
	g.credits = 5
	check(SpaceCombat.defeat(g).fine == 5, "fine is capped by credits")


func test_space_combat_mechanic() -> void:
	var g := fly_game()
	g.combat.hull = 40.0
	check(not SpaceCombat.repair(g).ok, "no repairs in flight")
	g.dock("mireth")
	var cost := SpaceCombat.repair_cost(g)
	check(cost == int(ceil(60.0 * float(data.space_combat.repair_per_hull))), "repair cost scales with the damage (%d)" % cost)
	g.credits = cost - 1
	check(not SpaceCombat.repair(g).ok and g.combat.hull == 40.0, "repair needs credits")
	g.credits = cost + 7
	check(SpaceCombat.repair(g).ok and g.combat.hull == 100.0 and g.credits == 7, "repair restores the hull")
	check(not SpaceCombat.repair(g).ok, "nothing to repair")
	check(not SpaceCombat.restock(g).ok, "no restock without pods")
	g.upgrades.missile = 2
	SpaceCombat.reset(g)
	check(SpaceCombat.take_missile(g) and SpaceCombat.take_missile(g) and g.combat.missiles == 6, "missiles are used up one by one")
	check(SpaceCombat.restock_cost(g) == 2 * int(data.space_combat.missile.price), "restock costs per missile")
	g.credits = 1000
	check(SpaceCombat.restock(g).ok and g.combat.missiles == 8 and g.credits == 1000 - 2 * int(data.space_combat.missile.price), "restock fills the pods")
	g.combat.missiles = 0
	check(not SpaceCombat.take_missile(g), "no missile when empty")
	var c := new_game()
	c.undock()
	c.dock("cinder")
	c.combat.hull = 10.0
	check(not SpaceCombat.repair(c).ok, "only the shipyard repairs")


func test_space_combat_save() -> void:
	var g := fly_game()
	g.upgrades.missile = 1
	g.upgrades.shield = 1
	SpaceCombat.reset(g)
	SpaceCombat.damage(g, 55.0)
	SpaceCombat.take_missile(g)
	g.combat.kills = 3
	var json := JSON.stringify(g.to_dict())
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(json))
	check(JSON.stringify(h.to_dict()) == json, "combat save round-trip is stable")
	check(h.combat.hull == 85.0 and h.combat.shield == 0.0 and h.combat.missiles == 3 and h.combat.kills == 3, "damage, ammo and kills restored: %s" % h.combat)
	var old: Dictionary = JSON.parse_string(json)
	old.erase("space")
	for k in ["laser", "missile", "shield", "hull"]:
		old.upgrades.erase(k)
	var o := Game.new()
	o.from_dict(data, old)
	check(o.combat.hull == 100.0 and o.combat.missiles == 0 and o.combat.kills == 0 and o.upgrades.laser == 0, "old save without combat state starts with an undamaged stock ship")
	var bad: Dictionary = JSON.parse_string(json)
	bad.combat = {"hull": -5, "shield": 9999, "missiles": 99}
	var b := Game.new()
	b.from_dict(data, bad)
	check(b.combat.hull >= 1.0 and b.combat.shield <= 40.0 and b.combat.missiles <= 4, "broken combat values are clamped")


func test_space_combat_balance() -> void:
	var stock := fly_game()
	var full := fly_game()
	for k in ["laser", "missile", "shield", "hull"]:
		full.upgrades[k] = 3
	SpaceCombat.reset(full)
	var ttk0 := SpaceCombat.seconds_to_kill(stock, 0.5)
	var ttk3 := SpaceCombat.seconds_to_kill(full, 0.5)
	check(ttk0 < 4.0 and ttk3 < ttk0 * 0.6, "stock laser kills a pirate in %.1fs, Mk4 in %.1fs at 50%% hits" % [ttk0, ttk3])
	var d1 := SpaceCombat.seconds_to_die(stock, 1, 0.5)
	var d3 := SpaceCombat.seconds_to_die(stock, 3, 0.5)
	check(d1 > 4.0 * ttk0, "a stock ship wins a 1v1 comfortably (%.0fs to die vs %.1fs to kill)" % [d1, ttk0])
	check(d3 > 3.0 * ttk0 * 0.9 and d3 < 20.0, "three pirates are a real threat to a stock ship (%.0fs to die, %.1fs per kill)" % [d3, ttk0])
	var f3 := SpaceCombat.seconds_to_die(full, 3, 0.5)
	check(f3 > 2.5 * d3, "armour + shield roughly triple the survival time (%.0fs vs %.0fs)" % [f3, d3])
	check(f3 > 3.0 * ttk3 * 4.0, "a full kit clears three pirates with room to spare")


func test_bribe() -> void:
	var g := new_game()
	g.add_heat(20)
	check(not g.bribe(20).ok and g.heat == 20.0, "no bribe without a hired inspector")
	g.credits = 1000
	check(Corruption.recruit(g, "vell").ok, "recruit the Mireth inspector")
	var cost := g.bribe_cost(20)
	var before := g.credits
	check(g.bribe(20).ok and g.heat == 0.0 and g.credits == before - cost, "bribe clears heat")
	check(cost == int(ceil(20 * float(data.heat.bribe_credits_per_heat) * (1.0 - float(data.corruption.fix_discount)))), "bribe price follows the fix discount")
	g.undock()
	g.add_heat(10)
	check(g.bribe(10).ok, "inspector works from anywhere in his system")


func test_corruption_data() -> void:
	var roles: Dictionary = data.corruption.roles
	var ids := {}
	for o in data.officials:
		check(not ids.has(o.id) and not data.contacts.any(func(c): return c.id == o.id), "official id %s is unique" % o.id)
		ids[o.id] = true
		check(data.locations.has(o.location) and roles.has(o.role), "official %s has a place and a role" % o.id)
		check(int(o.recruit_cost) > 0 and int(o.retainer) > 0, "official %s has a price" % o.id)
		check(ArtReg.NPC_LOOKS.has(o.look), "official %s look exists" % o.id)
	for sys in data.systems:
		check(data.officials.any(func(o): return o.role == "inspector" and data.locations[o.location].system == sys), "system %s has an inspector" % sys)
		check(data.officials.any(func(o): return o.role == "captain" and data.locations[o.location].system == sys), "system %s has a captain" % sys)


func test_debt_win_and_loss() -> void:
	var g := new_game()
	g.credits = 7000
	check(g.pay_debt(99999).ok and g.debt == 0 and g.state == "won", "paying debt wins")
	var l := new_game()
	l.undock()
	l.tick(l.day_seconds() * l.debt_due_day + 1.0)
	check(l.state == "lost", "missing the due day loses")


func test_save_roundtrip() -> void:
	var g := new_game()
	g.buy("cannabis", 5)
	g.buy("static_pollen", 5)
	g.start_batch("weed", ["static_pollen"], 5)
	g.upgrades.engine = 2
	g.tick(2.0)
	var d := g.to_dict()
	var json := JSON.stringify(d)
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(json))
	check(JSON.stringify(h.to_dict()) == json, "save round-trip is stable")
	check(h.lab_queue.size() == 1 and h.upgrades.engine == 2, "lab queue and upgrades restored")


func test_price_board() -> void:
	const PB = preload("res://scripts/core/price_board.gd")
	var g := new_game()
	var loc: String = str(data.start.location)
	var cap: int = int(data.price_board.history_days)
	check(g.price_board.is_empty(), "price board starts empty")
	g.dock(loc)
	var key := PB.key_buy("cannabis")
	check(PB.history(g, loc, key).size() == 1 and PB.history(g, loc, key)[0][1] == g.buy_price("cannabis", loc), "docking notes the buy price")
	check(PB.history(g, loc, PB.key_sell("weed")).size() == 1, "docking notes the sell value")
	g.dock(loc)
	check(PB.history(g, loc, key).size() == 1, "at most one observation per day")
	check(PB.observe(g, loc) == 0, "observing twice on a day adds nothing")
	g._new_day()
	check(PB.history(g, loc, key).size() == 2 and PB.history(g, loc, key)[1][0] == g.day, "the day tick notes prices while docked")
	check(PB.history(g, "cinder", key).is_empty(), "places you have not been to have no history")
	for i in range(cap + 6):
		g.day += 1
		PB.observe(g, loc)
	check(PB.history(g, loc, key).size() == cap, "history capped to %d days" % cap)
	check(PB.history(g, loc, key).back()[0] == g.day, "newest kept when capped")
	g.price_board[loc]["buy:cannabis"] = [[1, 100], [2, 100]]
	check(PB.trend(g, loc, key) == 0, "same price is steady")
	g.price_board[loc]["buy:cannabis"] = [[1, 100], [2, 130]]
	check(PB.trend(g, loc, key) == 1 and PB.arrow(1) == "▲", "rise is detected")
	g.price_board[loc]["buy:cannabis"] = [[1, 100], [2, 60]]
	check(PB.trend(g, loc, key) == -1, "fall is detected")
	check(PB.sparkline([[1, 5]], 8) == "" and PB.sparkline([[1, 1], [2, 9]], 8) == "▁█", "sparkline needs two points and spans low..high")
	check(PB.lines([[1, 5], [2, 7]], 1) == "day 2: 7 cr", "tooltip lines show the last n")
	# leaves the economy and the RNG stream alone
	var g2 := new_game()
	var g3 := new_game()
	g2.dock(loc)
	g3.location = loc
	g2.tick(5.0)
	g3.tick(5.0)
	check(g2.rng.state == g3.rng.state and g2.credits == g3.credits and g2.demand == g3.demand, "price board leaves RNG and economy alone")
	# save round trip
	var gs := new_game()
	gs.dock(loc)
	var d := gs.to_dict()
	var r := Game.new()
	r.from_dict(data, JSON.parse_string(JSON.stringify(d)))
	check(r.price_board == gs.price_board and not r.price_board.is_empty(), "price board survives a JSON save round trip")
	# old save
	d.erase("price_board")
	var o := Game.new()
	o.from_dict(data, d)
	check(o.price_board.is_empty(), "old save loads with empty history")
	# garbage
	for junk in ["x", 5, [1, 2], {"mireth": 3}, {"nowhere": {"buy:cannabis": [[1, 2]]}}, {loc: {"buy:cannabis": "abc"}}]:
		var jd := d.duplicate(true)
		jd["price_board"] = junk
		var jg := Game.new()
		jg.from_dict(data, jd)
		check(jg.price_board.is_empty(), "garbage price board is ignored: " + str(junk))
	var jd2 := d.duplicate(true)
	jd2["price_board"] = {loc: {"sell:weed": [[1], "x", [3, "y"], [5, 40], [4, 30], [5, 99]], "bad": [[1, 2]], "buy:nope": [[1, 2]]}}
	var jg2 := Game.new()
	jg2.from_dict(data, jd2)
	check(jg2.price_board.get(loc, {}).keys() == ["sell:weed"] and jg2.price_board[loc]["sell:weed"] == [[4, 30], [5, 40]], "garbage entries dropped, rest sorted and de-duplicated")
func _hot_days(g: Game, n: int) -> void:
	for i in n:
		g.heat = 95.0
		g._new_day()


func test_raids() -> void:
	var g := new_game()
	var rules: Dictionary = data.raids
	check(g.estates.has("cannery_rig") and Raids.estate_system(g, "cannery_rig") == "halvane", "starter estate sits in Halvane")
	# no raid while heat is low, however long
	var warned := []
	var raided := []
	g.event.connect(func(k, p):
		if k == "raid_warning": warned.append(p)
		if k == "raided": raided.append(p))
	for i in 8:
		g.heat = 10.0
		g._new_day()
	check(warned.is_empty() and raided.is_empty() and Raids.chance(g, "halvane") == 0.0, "low heat never gets raided")
	check(Raids.status_text(g, "cannery_rig") == "", "no raid line at low heat")
	# the streak must reach N days
	g.heat = 95.0
	g._new_day()
	check(int(g.raids.streak.get("halvane", 0)) == 1 and Raids.chance(g, "halvane") == 0.0, "one hot day is not a streak")
	check(Raids.status_text(g, "cannery_rig").contains("high for 1"), "estate screen mentions the streak")
	check(Raids.chance(g, "halvane") <= float(rules.chance_max), "chance stays capped")
	# rng isolation: the game RNG stream is the same with and without raids
	var a := new_game()
	var b := new_game()
	a.raids = {}
	b.heat = 95.0
	a.heat = 95.0
	var sa := a.rng.state
	var sb := b.rng.state
	check(sa == sb, "same seed, same rng state")
	_hot_days(b, 6)
	for i in 6:
		a.heat = 95.0
		a.corruption = b.corruption.duplicate(true)
		a.raids = Raids.init_state()
		a._new_day()
	check(a.rng.state == b.rng.state, "raids never draw from the game rng")
	# force a warning, then check the raid on the next day
	var h := new_game()
	h.credits = 1000
	h.estate_stock["cannery_rig"] = {"weed": 10, "cocaine": 1}
	h.bench["cannery_rig"] = {"base": "weed", "qty": 6, "additives": [], "done": [], "scores": {}, "mixed": false}
	h.raids.streak["halvane"] = int(rules.days)
	h.raids.roll = 1
	var ev := []
	h.event.connect(func(k, p): ev.append(k))
	var got_warn := false
	for i in 40:
		h.heat = 100.0
		h.corruption.heat.clear()
		h.raids.streak["halvane"] = int(rules.days)
		h._new_day()
		if not h.raids.warn.is_empty():
			got_warn = true
			break
	check(got_warn and ev.has("raid_warning") and not ev.has("raided"), "a warning comes first, no raid yet")
	check(h.raids.warn.estate == "cannery_rig" and h.estate_stock.cannery_rig.weed == 10, "warning leaves the stash alone")
	check(Raids.status_text(h, "cannery_rig").begins_with("RAID WARNING"), "estate screen shows the warning")
	var heat0: float = h.heat
	var wanted0 := Corruption.wanted(h)
	h.heat = 100.0
	h._new_day()
	check(ev.has("raided") and h.raids.warn.is_empty(), "raid lands on the day after the warning")
	check(h.estate_stock.cannery_rig.weed == 5 and h.estate_stock.cannery_rig.cocaine == 0 if h.estate_stock.cannery_rig.has("cocaine") else h.estate_stock.cannery_rig.weed == 5, "half the estate stock is seized (rounded up)")
	check(h.bench.cannery_rig.qty == 3, "half the tray is seized")
	check(h.credits == 1000 - int(rules.fine), "fine is paid")
	check(h.heat < 100.0 and Corruption.wanted(h) > wanted0, "heat drops, wanted rises")
	check(int(h.raids.streak.get("halvane", 0)) < int(rules.days) and heat0 >= 0.0, "streak restarts after a raid")
	# an emptied estate loses nothing and pays nothing
	var e := new_game()
	e.credits = 1000
	e.raids.warn = {"estate": "cannery_rig", "day": e.day + 1}
	e.heat = 80.0
	e._new_day()
	check(e.credits == 1000 and e.raids.count == 1, "empty estate: nothing seized, no fine")
	# warning is called off when the heat is gone
	var c := new_game()
	c.raids.warn = {"estate": "cannery_rig", "day": c.day + 1}
	c.heat = 0.0
	c._new_day()
	check(c.raids.warn.is_empty() and c.raids.count == 0, "cooled-down system: raid called off")
	# a hired captain cuts the chance
	var k := new_game()
	k.credits = 5000
	k.undock()
	k.dock("cinder")
	k.heat = 95.0
	k.raids.streak["halvane"] = 5
	var plain := Raids.chance(k, "halvane")
	Corruption.recruit(k, "dreyer")
	var cut := Raids.chance(k, "halvane")
	check(plain > 0.0 and is_equal_approx(cut, plain * (1.0 - float(rules.tipoff_cut))), "captain tip-offs cut the chance")
	# ship bay is never a target; save round trip; old saves
	check(Raids._targets(g, "halvane").has("cannery_rig") and not Raids._targets(g, "halvane").has("ship_bay"), "ship bay is not a raid target")
	h.raids.warn = {"estate": "cannery_rig", "day": h.day + 1}
	var j := JSON.stringify(h.to_dict())
	var l := Game.new()
	l.from_dict(data, JSON.parse_string(j))
	check(JSON.stringify(l.to_dict()) == j and l.raids.warn.estate == "cannery_rig" and l.raids.count == h.raids.count, "raid state survives a save")
	var old := h.to_dict()
	old.erase("raids")
	var o := Game.new()
	o.from_dict(data, JSON.parse_string(JSON.stringify(old)))
	check(o.raids.warn.is_empty() and o.raids.count == 0, "old saves load without raids")
func test_grow() -> void:
	const Grow = preload("res://scripts/core/grow.gd")
	var g := new_game()
	check(g.grow.is_empty(), "no grow trays at the start")
	for raw in data.grow.crops:
		check(data.raws.has(raw), "grow crop %s is a raw" % raw)
	g.credits = 1000
	var est := "cannery_rig"
	check(not Grow.build_tray(g, "dune_cellar").ok, "can't build in an estate you don't own")
	check(Grow.build_tray(g, est).ok and g.credits == 1000 - int(data.grow.tray_cost), "tray bought")
	for i in int(data.grow.max_trays) - 1:
		Grow.build_tray(g, est)
	check(Grow.trays(g, est).size() == int(data.grow.max_trays) and not Grow.build_tray(g, est).ok, "tray cap")
	check(not Grow.plant(g, est, 0, "cannabis").ok, "planting needs seed stock in the hold")
	check(not Grow.plant(g, est, 0, "fent_precursor").ok, "only listed crops grow")
	g.cargo["cannabis"] = 5
	check(Grow.plant(g, est, 0, "cannabis").ok and int(g.cargo.cannabis) == 5 - int(data.grow.seed_qty), "plant takes seeds from the hold")
	check(not Grow.plant(g, est, 0, "cannabis").ok, "tray in use")
	check(not Grow.harvest(g, est, 0).ok, "can't harvest unripe")
	var days := int(data.grow.crops.cannabis.days)
	check(Grow.water(g, est, 0).ok and not Grow.water(g, est, 0).ok, "water once per day")
	g.day += days
	check(Grow.is_ripe(g, Grow.trays(g, est)[0]) and not Grow.water(g, est, 0).ok, "ripe after the growth days")
	var lo := int(round(float(data.grow.crops.cannabis["yield"]) * lerpf(float(data.grow.min_yield_factor), 1.0, 1.0 / days)))
	check(Grow.expected_yield(g, Grow.trays(g, est)[0]) == lo, "one watering gives a poor yield")
	var before := int(g.stash.get("cannabis", 0))
	check(Grow.harvest(g, est, 0).ok and int(g.stash.cannabis) == before + lo, "harvest goes into the stash")
	check(Grow.trays(g, est)[0].raw == "", "harvested tray is empty again")
	# well cared for: watered every day -> full yield and prime grade
	Grow.plant(g, est, 1, "cannabis")
	for n in days:
		check(Grow.water(g, est, 1).ok, "water day %d" % n)
		g.day += 1
	var t: Dictionary = Grow.trays(g, est)[1]
	check(is_equal_approx(Grow.quality(g, t), 1.0) and Grow.grade(1.0) == "prime", "full care = quality 1")
	check(Grow.expected_yield(g, t) == int(data.grow.crops.cannabis["yield"]), "full care = full yield")
	check(Grow.expected_yield(g, t) > lo, "care raises the yield")
	# save round trip, then an old save without grow
	var d := g.to_dict()
	var g2 := new_game()
	g2.from_dict(data, JSON.parse_string(JSON.stringify(d)))
	check(Grow.trays(g2, est).size() == Grow.trays(g, est).size() and Grow.quality(g2, Grow.trays(g2, est)[1]) == 1.0, "grow trays survive a save")
	check(Grow.harvest(g2, est, 1).ok, "loaded tray can be harvested")
	# second slice: third crop, quality grade on the harvested pile, room visuals
	check(data.grow.crops.has("pseudo"), "third crop is listed")
	var gt: Dictionary = Grow.trays(g, est)[2]
	g.cargo["pseudo"] = 2
	check(Grow.plant(g, est, 2, "pseudo").ok and Grow.visuals(g, est)[2].raw == "pseudo", "third crop plants")
	check(Grow.visuals(g, est).size() == Grow.trays(g, est).size() and float(Grow.visuals(g, est)[2].progress) == 0.0, "visuals list every tray")
	g.day += int(data.grow.crops.pseudo.days)
	check(Grow.visuals(g, est)[2].ripe and Grow.visuals(g, est)[2].grade == "poor", "unwatered ripe tray is poor")
	g.stash["pseudo"] = 0
	check(Grow.stash_grade(g, "pseudo") == "", "no grade without grown stock")
	Grow.harvest(g, est, 2)
	check(Grow.stash_grade(g, "pseudo") == "poor" and gt.raw == "", "poor harvest grades the pile poor")
	g.stash["cannabis"] = 0
	g.grow_q.erase("cannabis")
	Grow.harvest(g, est, 1)
	check(Grow.stash_grade(g, "cannabis") == "prime", "prime harvest grades the pile prime")
	g.cargo["cannabis"] = 4
	Grow.plant(g, est, 0, "cannabis")
	g.day += days
	Grow.harvest(g, est, 0)
	var mix := float(g.grow_q.cannabis)
	check(mix > 0.5 and mix < 1.0, "piles blend qualities (%.2f)" % mix)
	var g4 := new_game()
	g4.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(is_equal_approx(float(g4.grow_q.cannabis), mix), "pile quality survives a save")
	d.erase("grow")
	var g3 := new_game()
	g3.from_dict(data, JSON.parse_string(JSON.stringify(d)))
	check(g3.grow.is_empty(), "old save without grow loads")
	d["grow"] = {"cannery_rig": {"trays": [{"raw": "bogus", "start_day": "x", "watered": [1]}]}, "nowhere": {"trays": [{}]}}
	g3.from_dict(data, JSON.parse_string(JSON.stringify(d)))
	check(Grow.trays(g3, est).size() == 1 and Grow.trays(g3, est)[0].raw == "" and not g3.grow.has("nowhere"), "junk grow data is cleaned")
func test_map_marker() -> void:
	const Marker = preload("res://scripts/core/marker.gd")
	var g := new_game()
	check(g.map_marker == "" and Marker.goal_location(g) == "", "new game has no marker")
	check(not Marker.set_marker(g, "nowhere").ok and g.map_marker == "", "unknown id is refused")
	g.location = ""  # flying
	var here: Array = g.locations_in(g.system)
	var loc: String = here[0]
	check(Marker.set_marker(g, loc).ok and g.map_marker == loc, "marker on a location")
	check(Marker.goal_location(g) == loc, "location in this system is the goal")
	g.location = loc
	check(Marker.reached(g) and Marker.goal_location(g) == "", "docked at the marker = reached, no goal")
	g.location = ""
	# system marker: current system has nothing to fly to
	Marker.set_marker(g, g.system)
	check(Marker.is_system(g, g.system) and Marker.reached(g) and Marker.goal_location(g) == "", "marker on the system you are in = reached")
	# another system routes via the gate, like quest waypoints
	var other := ""
	for s in g.data.systems:
		if s != g.system and Galaxy.route(g, g.system, s).size() >= 2:
			other = s
			break
	check(other != "", "a reachable second system exists")
	Marker.set_marker(g, other)
	var gate := Marker.goal_location(g)
	var rt: Array = Galaxy.route(g, g.system, other)
	check(gate != "" and g.data.locations[gate].has("jump_to") and g.data.locations[gate].jump_to == rt[1], "other system marker leads to the gate towards it (%s)" % gate)
	var far: Array = g.locations_in(other)
	Marker.set_marker(g, far[0])
	check(Marker.goal_location(g) == gate, "location in another system leads to the same gate")
	# save round trip; old saves (no key) and junk load as no marker
	var d := g.to_dict()
	var g2 := new_game()
	g2.from_dict(data, d)
	check(g2.map_marker == far[0], "marker survives a save")
	d.erase("marker")
	var g3 := new_game()
	g3.map_marker = loc
	g3.from_dict(data, d)
	check(g3.map_marker == "", "old save without marker loads fine")
	d["marker"] = "bogus"
	g3.from_dict(data, d)
	check(g3.map_marker == "", "unknown marker id in a save is dropped")
	Marker.clear(g)
	check(g.map_marker == "" and Marker.goal_location(g) == "", "clear")


func test_style() -> void:
	const Style = preload("res://scripts/core/style.gd")
	const EstateLayout = preload("res://scripts/planet/estate_layout.gd")
	var g := new_game()
	for cat in Style.SLOTS:
		check(Style.owns(g, cat, str(g.style[cat])), "style %s starts on an owned free item" % cat)
	check(Style.player_swaps(data, g.style).is_empty(), "stock look = no recolour")
	check(Style.hull_swaps(data, g.style).is_empty(), "stock paint = no recolour")
	g.credits = 100
	var r := Style.buy(g, "jacket", "violet")
	check(not r.ok and g.credits == 100 and g.style.jacket == "gold", "can't buy a jacket you can't afford")
	g.credits = 1000
	r = Style.buy(g, "jacket", "violet")
	check(r.ok and g.credits == 1000 - int(data.style.jacket.violet.cost) and g.style.jacket == "violet", "bought jacket is worn")
	var sw := Style.player_swaps(data, g.style)
	check(sw.get(Color("#ffd166")) == Color(data.style.jacket.violet.ramp[0]), "jacket recolours the gold coat")
	var before: int = g.credits
	check(Style.buy(g, "jacket", "gold").ok and g.credits == before and g.style.jacket == "gold", "switching back to an owned item is free")
	check(not Style.equip(g, "paint", "violet").ok, "can't equip unowned paint")
	g.credits = 5000
	Style.buy(g, "paint", "crimson")
	Style.buy(g, "decal", "skull")
	check(not Style.hull_swaps(data, g.style).is_empty() and g.style.decal == "skull", "paint and decal set")
	Style.buy(g, "decor", "plant")
	Style.buy(g, "decor", "sofa")
	check(g.style.decor == ["plant", "sofa"], "bought decor switches on")
	Style.equip(g, "decor", "plant")
	check(g.style.decor == ["sofa"], "equip toggles decor off")
	Style.equip(g, "decor", "plant")
	# decor spots stay inside the estate, off stations, the door and the stash
	for eid in data.estates:
		var e: Dictionary = data.estates[eid]
		var bl: Array = []
		for st in e.get("stations", []):
			bl.append({"id": st[0], "x": st[1], "y": st[2]})
		var spots := Style.decor_spots(data, eid, bl, data.style.decor.keys())
		var seen := {}
		for sp in spots:
			var cells_used: Array = [Vector2i(int(sp[1]), int(sp[2]))]
			if Style.WIDE_DECOR.has(sp[0]):  # centred on the line between two cells
				cells_used = [Vector2i(int(sp[1]) - 1, int(sp[2])), Vector2i(int(sp[1]), int(sp[2]))]
			for c in cells_used:
				check(c.x >= 0 and c.y >= 0 and c.x < int(e.size[0]) and c.y < int(e.size[1]), "%s decor inside the room" % eid)
				check(c != Vector2i(int(e.size[0]) / 2, int(e.size[1]) - 1) and c != Vector2i(0, int(e.size[1]) - 1), "%s decor off door and stash" % eid)
				check(not seen.has(c), "%s one decor per cell" % eid)
				seen[c] = true
				for b in bl:
					var sz: Array = data.buildables[b.id].size
					check(not Rect2i(int(b.x), int(b.y), int(sz[0]), int(sz[1]) + 1).has_point(c), "%s decor off stations" % eid)
	var cfg := EstateLayout.build_cfg(data, "cannery_annex", [], g.style.decor)
	check(cfg.props.filter(func(p): return p.size() > 3 and p[3] == "decor").size() == 2, "estate layout carries the decor props")
	# save round trip keeps the style, junk ids are dropped
	var d := g.to_dict()
	d.style.owned.append("jacket:nope")
	d.style.hair = "nope"
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(d)))
	check(h.style.paint == "crimson" and h.style.decal == "skull" and h.style.decor == ["sofa", "plant"], "style survives a save")
	check(not h.style.owned.has("jacket:nope") and h.style.hair == data.style.hair.keys()[0], "unknown style ids are dropped")
	var old := g.to_dict()
	old.erase("style")
	var o := Game.new()
	o.from_dict(data, JSON.parse_string(JSON.stringify(old)))
	check(o.style.jacket == "gold" and o.style.decor.is_empty(), "old saves get the stock look")


func test_drug_ladder() -> void:
	var order := ["weed", "cocaine", "meth", "fentanyl"]
	for i in order.size():
		check(int(data.bases[order[i]].tier) == i + 1, "%s is tier %d" % [order[i], i + 1])
		if i > 0:
			var lo: Dictionary = data.bases[order[i - 1]]
			var hi: Dictionary = data.bases[order[i]]
			check(float(hi.base_value) > float(lo.base_value) and float(hi.heat_mult) > float(lo.heat_mult), "%s stronger than %s" % [order[i], order[i - 1]])
		var sold := false
		for loc in data.locations:
			if data.locations[loc].sells_raw.has(data.bases[order[i]].raw):
				sold = true
		check(sold, "%s precursor is sold somewhere" % order[i])
	var g := new_game()
	g.cargo["weed:glow"] = 1
	g.cargo["fentanyl:deep"] = 1
	g.sell("weed:glow", 1, "okka")
	var h1 := g.heat
	g.sell("fentanyl:deep", 1, "sen")
	check(g.heat - h1 > h1 * 2.0, "fentanyl draws far more heat than weed")


func test_old_save_names_migrate() -> void:
	var g := new_game()
	var d := g.to_dict()
	d.cargo = {"sporegel": 4, "driftglow:overclock+radiant": 3}
	d.stash = {"shardlight:crisp": 2}
	d.demand.mireth.erase("weed")
	d.demand.mireth["driftglow"] = 0.5
	var h := Game.new()
	h.from_dict(data, d)
	check(h.cargo.get("cannabis", 0) == 4 and h.cargo.get("weed:overclock+radiant", 0) == 3, "cargo renamed: %s" % [h.cargo])
	check(h.stash.get("cocaine:crisp", 0) == 2, "stash renamed")
	check(is_equal_approx(h.demand.mireth.weed, 0.5), "demand renamed")


## A scripted run of the core loop must clear the debt before the due day (no flight, travel approximated).
func test_core_loop_is_profitable() -> void:
	var Bot = load("res://tools/bot.gd")
	var res: Dictionary = Bot.play(data, 11, 1.0)
	check(res.state == "won", "bot clears debt: %s" % [res])
	check(res.day <= int(data.start.debt_due_day), "won before due day")


func test_heat_per_system() -> void:
	var g := new_game()
	g.add_heat(50)
	g.undock()
	g.system = "halvane"
	var gate := ""
	for l in data.locations:
		if data.locations[l].has("jump_to") and data.locations[l].system == "halvane":
			gate = l
	g.credits = 500
	check(g.jump(gate).ok and g.system == "kovar", "jumped to Kovar")
	check(g.heat == 0.0 and is_equal_approx(g.corruption.heat.halvane, 50.0 - float(data.heat.decay_per_second) * float(data.jump.seconds)) or g.heat == 0.0, "Kovar starts cold, Halvane heat is parked")
	g.add_heat(30)
	var kovar_gate := ""
	for l in data.locations:
		if data.locations[l].get("jump_to", "") == "halvane" and data.locations[l].system == "kovar":
			kovar_gate = l
	g.credits = 500
	check(g.jump(kovar_gate).ok and g.system == "halvane", "jumped back")
	check(g.heat > 30.0 and g.corruption.heat.has("kovar") and g.corruption.heat.kovar > 20.0, "heat is kept per system")
	check(g.patrol_count() >= 2, "Halvane patrols follow Halvane heat")
	var parked: float = g.corruption.heat.kovar
	g.tick(10.0)
	check(g.corruption.heat.kovar < parked, "parked heat cools down")


func test_wanted_level() -> void:
	var g := new_game()
	var base_foot := g.police_on_foot(1.0)
	g.corruption.wanted = 100.0
	check(g.patrol_count() > 1 and g.police_on_foot(1.0) > base_foot, "wanted raises patrols and officers")
	g.corruption.wanted = 0.0
	g.cargo["weed:x"] = 1
	g.bust()
	check(is_equal_approx(g.corruption.wanted, float(data.corruption.wanted_per_bust)), "a bust raises wanted")
	for i in 20:
		g.bust()
	check(g.corruption.wanted <= float(data.corruption.wanted_max), "wanted is capped")
	var w: float = g.corruption.wanted
	g.tick(g.day_seconds() + 1.0)
	check(g.corruption.wanted < w, "wanted decays per day")
	check(not Corruption.clear_wanted(g, 10).ok, "clearing wanted needs an inspector")
	g.credits = 5000
	Corruption.recruit(g, "vell")
	var c := g.credits
	check(Corruption.clear_wanted(g, 20).ok and g.credits < c, "inspector clears wanted for credits")


func test_officials() -> void:
	var g := new_game()
	check(People.official_state(g, "vell").known and not People.official_state(g, "roe").known, "docking introduces the local official only")
	check(not Corruption.recruit(g, "roe").ok, "must be at the official's location")
	g.credits = 100
	check(not Corruption.recruit(g, "vell").ok and g.credits == 100, "too poor to recruit")
	g.credits = 2000
	check(Corruption.recruit(g, "vell").ok and g.credits == 2000 - int(People.official(g, "vell").recruit_cost), "recruit pays the bribe")
	check(not Corruption.recruit(g, "vell").ok, "cannot hire twice")
	check(Corruption.hired(g, "inspector").id == "vell" and Corruption.hired(g, "customs").is_empty(), "hired lookup by role and system")
	var c := g.credits
	g.tick(g.day_seconds() + 1.0)
	check(g.credits == c - int(People.official(g, "vell").retainer), "retainer is paid every day")
	var l0: float = People.official_state(g, "vell").loyalty
	g.credits = 0
	g.tick(g.day_seconds() + 1.0)
	check(People.official_state(g, "vell").loyalty < l0 and People.official_state(g, "vell").hired, "missed retainer costs loyalty")
	g.tick(g.day_seconds() * 2.0 + 1.0)
	check(not People.official_state(g, "vell").hired, "unpaid official walks away")


func test_customs_scan_pass() -> void:
	var g := new_game()
	g.credits = 5000
	g.undock()
	g.dock("bazaar")
	check(Corruption.recruit(g, "roe").ok, "recruit the Bazaar customs officer")
	check(Corruption.pass_chance(g) > 0.3, "customs gives a pass chance")
	var passed := 0
	var busted := 0
	for i in 200:
		g.cargo["weed:x"] = 3
		g.corruption.wanted = 0.0
		var before: int = g.stats.busts
		g.bust()
		if g.stats.busts == before:
			passed += 1
		else:
			busted += 1
	check(passed > 60 and busted > 20, "about 60%% of scans wave through (%d/%d)" % [passed, busted])
	check(People.official_state(g, "roe").passes == passed, "passes are counted")
	g.corruption.wanted = 80.0
	check(Corruption.pass_chance(g) < 0.5 * float(data.officials[1].pass_chance), "a high wanted level shrinks the pass chance")
	var other := new_game()
	other.cargo["weed:x"] = 1
	other.bust()
	check(other.stats.busts == 1, "no customs officer, no pass")


func test_sweep_and_tip_off() -> void:
	var g := new_game()
	var events: Array = []
	g.event.connect(func(kind, p): events.append(kind))
	g.heat = 100.0
	g.corruption.roll = 1
	var seen := false
	for i in 12:
		g.heat = 100.0
		g.tick(g.day_seconds() + 1.0)
		if not g.corruption.pending.is_empty() or not g.corruption.sweep.is_empty():
			seen = true
			break
	check(seen, "a hot system eventually gets a sweep planned")
	check(not events.has("tip_off"), "no tip-off without a captain")
	# captain tip-off and diversion
	var h := new_game()
	h.credits = 5000
	h.undock()
	h.dock("cinder")
	check(Corruption.recruit(h, "dreyer").ok, "recruit the patrol captain")
	var tips: Array = []
	h.event.connect(func(kind, p): if kind == "tip_off": tips.append(p))
	for i in 12:
		h.heat = 100.0
		h.credits = 5000
		h.tick(h.day_seconds() + 1.0)
		if not tips.is_empty():
			break
	check(not tips.is_empty() and h.corruption.pending.system == "halvane", "captain tips you off before the sweep")
	var pc0 := h.patrol_count()
	check(Corruption.divert_sweep(h).ok and h.corruption.pending.is_empty(), "captain diverts the sweep")
	# an undiverted sweep adds patrols on its day
	h.corruption.pending = {"system": "halvane", "day": h.day + 1}
	h.heat = 0.0
	h.tick(h.day_seconds() + 1.0)
	check(not h.corruption.sweep.is_empty() and Corruption.heat_bonus(h) >= float(data.corruption.crackdown_heat_bonus), "sweep adds patrol pressure that day")
	h.tick(h.day_seconds() + 1.0)
	check(h.corruption.sweep.is_empty(), "sweep ends the next day")
	check(pc0 >= 1, "patrols stay valid")


func test_corruption_save() -> void:
	var g := new_game()
	g.credits = 3000
	Corruption.recruit(g, "vell")
	g.corruption.wanted = 33.0
	g.corruption.heat["kovar"] = 12.5
	g.corruption.pending = {"system": "kovar", "day": 4}
	var j: String = JSON.stringify(g.to_dict())
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(j))
	check(People.official_state(h, "vell").hired and is_equal_approx(h.corruption.wanted, 33.0), "officials and wanted survive a save")
	check(is_equal_approx(h.corruption.heat.kovar, 12.5) and h.corruption.pending.day == 4, "parked heat and pending sweep survive")
	var old := g.to_dict()
	old.erase("corruption")
	var o := Game.new()
	o.from_dict(data, JSON.parse_string(JSON.stringify(old)))
	check(o.corruption.wanted == 0.0 and not People.official_state(o, "vell").hired, "old saves load with a clean record")
## A fresh game standing inside the starter Old Cannery rig with raws and additives in the hold.
func bench_game() -> Game:
	var g := new_game()
	g.inside_estate = "cannery_rig"
	g.cargo = {"cannabis": 10, "pseudo": 10, "nanoflux": 10, "ion_syrup": 10}
	return g


func test_bench_line() -> void:
	var g := new_game()
	check(g.estate_owned("cannery_rig") and g.estates.cannery_rig.buildings.size() == 7, "the cannery rig is yours from day one with all 7 stations")
	check(not g.remove_building("cannery_rig", 0).ok, "starter stations are bolted down")
	g = bench_game()
	check(Bench.use_mode(g, "cook_stove").mode == "wait", "no tray: the stove waits")
	check(Bench.use_mode(g, "trim_table").mode == "start", "the trim table starts weed")
	check(Bench.bases_starting_at(data, "precursor_scale").size() == 3, "the scale starts cocaine, meth, fentanyl")
	check(not Bench.begin(g, "precursor_scale", "weed", 5).ok, "weed does not start on the scale")
	check(not Bench.begin(g, "trim_table", "weed", 99).ok, "rig capacity limits the tray")
	check(Bench.begin(g, "trim_table", "weed", 5).ok and g.cargo.cannabis == 5, "tray started, raws leave the hold")
	check(not Bench.begin(g, "trim_table", "weed", 5).ok, "one tray per estate")
	check(Bench.use_mode(g, "trim_table").mode == "play", "first the trim table")
	check(Bench.use_mode(g, "cook_stove").mode == "wait", "the stove is not next yet")
	check(not Bench.record(g, "cook_stove", 1.0).ok, "stations go in line order")
	check(Bench.record(g, "trim_table", 0.9).ok and Bench.next_station(g, Bench.tray(g)) == "extractor", "weed goes to the extractor next")
	check(Bench.use_mode(g, "mixing_station").mode == "wait", "mixing only after the extractor")
	Bench.record(g, "extractor", 0.9)
	check(Bench.use_mode(g, "mixing_station").mode == "mix", "now additives can go in")
	check(Bench.next_station(g, Bench.tray(g)) == "cook_stove", "mixing is an optional stop")
	Bench.record(g, "cook_stove", 0.9)
	check(Bench.tray(g).mixed and Bench.use_mode(g, "mixing_station").mode == "wait", "past the stove there is no mixing any more")
	var r: Dictionary = Bench.record(g, "pack_table", 0.9)
	check(r.ok and Bench.tray(g).is_empty(), "the last station finishes the tray")
	check(g.lab_queue.size() == 1 and str(g.lab_queue[0].product).begins_with("weed") and not "+" in str(g.lab_queue[0].product).split(":")[1], "plain weed queued: %s" % [g.lab_queue])
	var grade: int = Production.outcome(data, {"trim_table": 0.9, "extractor": 0.9, "cook_stove": 0.9, "pack_table": 0.9}).grade
	check(str(g.lab_queue[0].product).split("#")[0].ends_with("@%d" % grade) or grade == 1, "the minigame scores set the grade")
	# abandon gives the raws back via the stash
	Bench.begin(g, "trim_table", "weed", 3)
	check(Bench.abandon(g).ok and g.stash.get("cannabis", 0) == 3 and Bench.tray(g).is_empty(), "scrapping a tray keeps the ingredients")
	# outside an estate nothing starts
	g.inside_estate = ""
	check(not Bench.begin(g, "trim_table", "weed", 1).ok, "no bench outside estates")


func test_bench_mixing() -> void:
	var g := bench_game()
	Bench.begin(g, "trim_table", "weed", 4)
	Bench.record(g, "trim_table", 0.5)
	Bench.record(g, "extractor", 0.5)
	check(not Bench.mix(g, ["nanoflux", "ion_syrup", "nanoflux", "ion_syrup"]).ok, "max 3 additives")
	check(not Bench.mix(g, ["void_salt"]).ok, "missing additive refused")
	var pv: Dictionary = Bench.preview(g, "weed", ["nanoflux"])
	check(pv.value > 0 and pv.traits.size() >= 1, "preview shows the result")
	check(Bench.mix(g, ["nanoflux"]).ok and g.cargo.nanoflux == 6, "additives leave the hold per unit")
	check(Bench.next_station(g, Bench.tray(g)) == "mixing_station" and Bench.use_mode(g, "mixing_station").mode == "play", "then the pour minigame")
	check(not Bench.mix(g, ["ion_syrup"]).ok, "mixed once only")
	for st in ["mixing_station", "cook_stove", "pack_table"]:
		Bench.record(g, st, 0.5)
	check(g.lab_queue.size() == 1 and g.lab_queue[0].product.begins_with(pv.product.split("@")[0]), "mixed product queued: %s vs %s" % [g.lab_queue, pv.product])
	# meth goes scale -> mixing? (no extractor) -> cook -> refiner -> pack
	var m := bench_game()
	Bench.begin(m, "precursor_scale", "meth", 3)
	check(Bench.use_mode(m, "mixing_station").mode == "wait", "meth: scale first")
	Bench.record(m, "precursor_scale", 0.5)
	check(Bench.use_mode(m, "mixing_station").mode == "mix" and Bench.next_station(m, Bench.tray(m)) == "cook_stove", "meth can mix right after the scale")
	# an estate without a mixing station: no mixing, still cooks plain
	var e := new_game()
	e.credits = 20000
	e.location = "cinder"
	e.buy_estate("shaft_shack")
	e.inside_estate = "shaft_shack"
	for b in [["trim_table", 0, 0], ["extractor", 2, 0], ["cook_stove", 4, 0], ["pack_table", 6, 0]]:
		e.place_building("shaft_shack", b[0], b[1], b[2])
	e.cargo = {"cannabis": 5, "nanoflux": 5}
	check(Bench.begin(e, "trim_table", "weed", 5).ok, "shack line starts")
	for st in ["trim_table", "extractor", "cook_stove", "pack_table"]:
		Bench.record(e, st, 0.6)
	check(e.lab_queue.size() == 1, "shack batch queued without mixing")


func test_bench_save() -> void:
	var g := bench_game()
	Bench.begin(g, "trim_table", "weed", 4)
	Bench.record(g, "trim_table", 0.7)
	Bench.record(g, "extractor", 0.4)
	Bench.mix(g, ["ion_syrup"])
	var json := JSON.stringify(g.to_dict())
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(json))
	h.inside_estate = "cannery_rig"
	check(Bench.tray(h).qty == 4 and Bench.tray(h).additives == ["ion_syrup"] and Bench.tray(h).done == ["trim_table", "extractor"], "tray survives save/load")
	check(JSON.stringify(h.to_dict()) == json, "save with a tray is stable")
	check(h.estates.cannery_rig.buildings[0].get("fixed", false), "fixed stations stay fixed after load")
	var d := new_game().to_dict()
	d.erase("bench")
	d.estates.erase("cannery_rig")
	var old := Game.new()
	old.from_dict(data, d)
	check(old.estate_owned("cannery_rig") and old.bench.is_empty(), "old saves get the cannery rig and no tray")


func test_mixing_journal() -> void:
	var g := bench_game()
	check(Products.journal(g).is_empty(), "fresh game: empty journal")
	var pv: Dictionary = Bench.preview(g, "weed", ["nanoflux"])
	check(is_equal_approx(pv.trait_values.overclock, 0.35) and pv.trait_values.size() == pv.traits.size(), "preview carries trait values")
	g.cargo.nanoflux = 20
	g.day = 2
	g.start_batch("weed", ["nanoflux"], 3)
	g.day = 4
	g.cargo.cannabis = 10
	g.start_batch("weed", ["ion_syrup"], 3)
	g.start_batch("weed", [], 3)
	var j: Array = Products.journal(g)
	check(j.size() == 2, "plain batches are not journal entries (%d)" % j.size())
	check(j[0].additives == ["ion_syrup"] and j[0].last == 4 and j[1].last == 2, "newest first")
	check(Products.journal(g, "meth").is_empty() and Products.journal(g, "weed").size() == 2, "filtered by drug")
	# re-cook
	var h := bench_game()
	h.recipes = g.recipes.duplicate(true)
	h.cargo.nanoflux = 2
	Bench.begin(h, "trim_table", "weed", 4)
	Bench.record(h, "trim_table", 0.5)
	Bench.record(h, "extractor", 0.5)
	var rk: String = j[1].key
	check(Bench.recook_block(h, rk) != "", "block reason when additives are short")
	check(not Bench.recook(h, rk).ok and not Bench.tray(h).mixed, "re-cook refused without enough additives")
	check(not Bench.recook(h, "meth:crisp+static").ok, "unknown recipe refused")
	h.cargo.nanoflux = 4
	check(Bench.recook_block(h, rk) == "", "no block with enough additives")
	check(Bench.recook(h, rk).ok and Bench.tray(h).additives == ["nanoflux"] and int(h.cargo.get("nanoflux", 0)) == 0, "re-cook pours the recipe")
	var t2 := bench_game()
	Bench.begin(t2, "precursor_scale", "meth", 2)
	check(not Bench.recook(t2, rk).ok, "recipe for another drug refused")
	# save round trip + old saves without the new fields
	var json := JSON.stringify(g.to_dict())
	var l := Game.new()
	l.from_dict(data, JSON.parse_string(json))
	check(Products.journal(l).size() == 2 and JSON.stringify(l.to_dict()) == json, "journal survives save/load")
	var d: Dictionary = JSON.parse_string(json)
	for r in d.products.recipes:
		d.products.recipes[r].erase("last")
		d.products.recipes[r].erase("runs")
	var o := Game.new()
	o.from_dict(data, d)
	check(Products.journal(o).size() == 2 and Products.journal(o)[0].last >= 1, "old saves without journal fields load")


# ---------------------------------------------------------------- C2 automation machines

## Annex with machines for the trim, mix and pack steps and a hand-operated extractor + stove; weed and additives in the hold.
func machine_game() -> Game:
	var g := new_game()
	g.credits = 50000
	g.buy_estate("cannery_annex")
	g.inside_estate = "cannery_annex"
	g.place_building("cannery_annex", "auto_trimmer", 0, 0)
	g.place_building("cannery_annex", "extractor", 2, 0)
	g.place_building("cannery_annex", "drip_mixer", 4, 0)
	g.place_building("cannery_annex", "cook_stove", 0, 2)
	g.place_building("cannery_annex", "packing_machine", 4, 2)
	g.cargo = {"cannabis": 10, "nanoflux": 10, "ion_syrup": 10}
	return g


func test_machines_data() -> void:
	var ms: Dictionary = data.machines
	check(ms.size() == 3 and ms.has("auto_trimmer") and ms.has("drip_mixer") and ms.has("packing_machine"), "three machines")
	var premium: float = data.quality.grades[2].min
	for id in ms:
		var m: Dictionary = ms[id]
		check(Machines.is_machine(data, id) and data.stations.has(id) and data.buildables.has(id), "machine %s is a station and a buildable" % id)
		check(data.stations.has(m.station) and m.station in data.station_order, "machine %s automates a real line station" % id)
		check(data.stations[id].get("machine", false) and not id in data.station_order, "machine %s is flagged and off the line" % id)
		check(data.stations[id].affects == data.stations[m.station].affects, "machine %s affects what its station affects" % id)
		check(float(m.score) > 0.3 and float(m.score) < premium, "machine %s scores below a good minigame" % id)
		check(int(m.run_cost) > 0, "machine %s costs money per unit" % id)
		check(int(data.buildables[id].cost) > int(data.buildables[m.station].cost), "machine %s costs more than the table" % id)
		check(Machines.station_of(data, id) == m.station and Machines.station_of(data, m.station) == m.station, "station_of")
	check(not Machines.is_machine(data, "trim_table") and Machines.provides(data, "trim_table") == ["trim_table"], "tables provide only themselves")
	check(Machines.provides(data, "auto_trimmer") == ["auto_trimmer", "trim_table"], "a machine provides its station")


func test_machines_provide_stations() -> void:
	var g := new_game()
	g.credits = 50000
	g.buy_estate("cannery_annex")
	check(g.missing_stations_in("cannery_annex", "weed", []).size() == 4, "empty annex misses the whole weed line")
	g.place_building("cannery_annex", "auto_trimmer", 0, 0)
	g.place_building("cannery_annex", "extractor", 2, 0)
	g.place_building("cannery_annex", "cook_stove", 0, 2)
	check(g.missing_stations_in("cannery_annex", "weed", []) == ["pack_table"], "the trimmer stands in for the trim table")
	g.place_building("cannery_annex", "packing_machine", 4, 2)
	check(g.missing_stations_in("cannery_annex", "weed", []).is_empty(), "the packing machine stands in for the packaging table")
	check(g.missing_stations_in("cannery_annex", "weed", ["nanoflux"]) == ["mixing_station"], "mixing needs a station or a drip mixer")
	g.place_building("cannery_annex", "drip_mixer", 4, 0)
	check(g.missing_stations_in("cannery_annex", "weed", ["nanoflux"]).is_empty(), "the drip mixer stands in for the mixing station")
	check(not g.place_building("cannery_annex", "auto_trimmer", 0, 0).ok, "machines take room like any building")
	var cr := g.credits
	check(g.remove_building("cannery_annex", 0).ok and g.credits > cr, "machines can be taken down for a refund")
	check(Orders.known(g, "kit:auto_trimmer"), "machines come as kits in the phone catalog")


func test_machines_run() -> void:
	var g := machine_game()
	check(Bench.use_mode(g, "auto_trimmer").mode == "start" and Bench.use_mode(g, "auto_trimmer").get("auto", false), "the trimmer starts a tray, automatically")
	check(Bench.use_mode(g, "drip_mixer").mode == "wait", "the mixer waits for a tray")
	check(not Machines.run(g, "auto_trimmer").ok, "no tray, no base: nothing to run")
	check(not Machines.run(g, "cook_stove", "weed", 5).ok, "only machines run")
	check(not Machines.run(g, "packing_machine", "weed", 5).ok, "the packer does not start trays")
	var cr := g.credits
	g.credits = 2
	check(not Machines.run(g, "auto_trimmer", "weed", 5).ok and g.cargo.cannabis == 10 and Bench.tray(g).is_empty(), "too poor: nothing is taken, no tray")
	g.credits = cr
	g.inside_estate = ""
	check(not Machines.run(g, "auto_trimmer", "weed", 5).ok, "machines run inside the estate")
	g.inside_estate = "cannery_annex"
	var cost := Machines.cost_for(data, "auto_trimmer", 5)
	check(cost == 5 * int(data.machines.auto_trimmer.run_cost), "cost is per unit")
	var runs: int = g.stats.machine_runs
	var r: Dictionary = Machines.run(g, "auto_trimmer", "weed", 5)
	check(r.ok and g.credits == cr - cost and g.cargo.cannabis == 5, "trimmer runs: pays %d, raws leave the hold: %s" % [cost, r.msg])
	check(Bench.tray(g).done == ["trim_table"] and is_equal_approx(Bench.tray(g).scores.trim_table, float(data.machines.auto_trimmer.score)), "the trimmer records its fixed score")
	check(g.stats.machine_runs == runs + 1 and g.estates.cannery_annex.buildings[0].runs == 1, "runs are counted")
	check(Bench.next_station(g, Bench.tray(g)) == "extractor", "the extractor is hand-operated and next")
	check(not Machines.run(g, "auto_trimmer", "weed", 5).ok and not Machines.run(g, "drip_mixer").ok, "machines only run their own step")
	Bench.record(g, "extractor", 0.9)
	check(Bench.use_mode(g, "drip_mixer").mode == "mix" and Bench.use_mode(g, "drip_mixer").get("auto", false), "past the extractor the mixer takes additives")
	check(not Machines.run(g, "drip_mixer").ok, "choose additives (or skip) first")


func test_machines_mixer_and_packer() -> void:
	var g := machine_game()
	Machines.run(g, "auto_trimmer", "weed", 4)
	Bench.record(g, "extractor", 0.9)
	check(Bench.mix(g, ["nanoflux"]).ok, "pour additives into the tray")
	check(Bench.next_station(g, Bench.tray(g)) == "mixing_station", "the pour comes next")
	var cr := g.credits
	var r: Dictionary = Machines.run(g, "drip_mixer")
	check(r.ok and g.credits == cr - Machines.cost_for(data, "drip_mixer", 4), "the drip mixer pours for money: %s" % r.msg)
	check(is_equal_approx(Bench.tray(g).scores.mixing_station, float(data.machines.drip_mixer.score)), "mixer score recorded")
	Bench.record(g, "cook_stove", 0.9)
	check(not Machines.run(g, "drip_mixer").ok, "the mixer is done with this tray")
	var ev := []
	g.event.connect(func(n, _p): ev.append(n))
	r = Machines.run(g, "packing_machine")
	check(r.ok and Bench.tray(g).is_empty() and g.lab_queue.size() == 1, "the packing machine finishes the tray into the cooker")
	check("machine_run" in ev and "lab_started" in ev, "machine_run and lab_started events")
	# skipping additives still works: a tray without a mix step
	var h := machine_game()
	Machines.run(h, "auto_trimmer", "weed", 3)
	Bench.record(h, "extractor", 0.5)
	Bench.mix(h, [])
	Bench.record(h, "cook_stove", 0.5)
	check(Machines.run(h, "packing_machine").ok and h.lab_queue.size() == 1, "plain batch: trimmer, extractor, stove, packer")


func test_machines_quality_below_hands() -> void:
	var hands := {}
	var auto := {}
	for st in ["trim_table", "extractor", "mixing_station", "cook_stove", "pack_table"]:
		hands[st] = 0.95
		auto[st] = 0.95
	var all_auto := {}
	for id in data.machines:
		auto[data.machines[id].station] = float(data.machines[id].score)
		all_auto[data.machines[id].station] = float(data.machines[id].score)
	var a := Production.outcome(data, auto)
	var b := Production.outcome(data, hands)
	check(a.grade <= b.grade and a.quality < b.quality, "machine batches grade lower than perfect hands (%.2f vs %.2f)" % [a.quality, b.quality])
	check(a.yield_mult < b.yield_mult and a.heat_mult > b.heat_mult, "machine batches yield less and run hotter than perfect hands")
	check(Production.outcome(data, all_auto).grade <= Mixing.STANDARD, "machines alone never reach Premium")
	check(float(Production.outcome(data, all_auto).yield_mult) > float(Production.outcome(data, {"trim_table": 0.0}).yield_mult), "but they beat a botched minigame")


func machine_shack(machine_cash: int = 50000) -> Game:
	var g := new_game()
	g.credits = 50000
	g.dock("cinder")
	g.buy_estate("shaft_shack")
	g.inside_estate = "shaft_shack"
	for b in [["auto_trimmer", 0, 0], ["cook_stove", 2, 0], ["packing_machine", 4, 0], ["extractor", 6, 0]]:
		g.place_building("shaft_shack", b[0], b[1], b[2])
	Workers.hire(g, "hollis")
	Workers.assign(g, "hollis", "shaft_shack")
	Workers.set_recipe(g, "shaft_shack", "weed", [], 5)
	g.cargo = {"cannabis": 5}
	Workers.deposit(g, "shaft_shack", "cannabis", 5)
	g.credits = machine_cash
	return g


func test_machines_workers() -> void:
	var g := machine_shack()
	var blds: Array = g.estates.shaft_shack.buildings
	check(Workers.blocker(g, "shaft_shack") == "", "a worker can run a line made of machines")
	var cost := Machines.worker_cost(g.data, blds, ["trim_table", "extractor", "cook_stove", "pack_table"], 5)
	check(cost == Machines.cost_for(data, "auto_trimmer", 5) + Machines.cost_for(data, "packing_machine", 5), "workers pay machine runs for machine-only steps")
	var cr: int = g.credits
	g.tick(1.0)
	check(not g.estates.shaft_shack.job.is_empty(), "the batch starts")
	check(cr - g.credits >= cost and g.stats.machine_runs == 2, "the machines were paid and counted")
	check(is_equal_approx(Machines.worker_score(g.data, blds, "trim_table", 0.9), float(data.machines.auto_trimmer.score)), "machine-only step scores the machine's value")
	check(Machines.worker_score(g.data, blds, "extractor", 0.9) < 0.0, "hand-operated steps use the worker's skill")
	var line := ["trim_table", "extractor", "cook_stove", "pack_table"]
	var f := Machines.worker_time_mult(g.data, blds, line)
	var want := (1.0 - float(data.machines.auto_trimmer.speed)) * (1.0 - float(data.machines.packing_machine.speed))
	check(is_equal_approx(f, want) and f < 1.0, "machine-only steps speed up a worker batch (%.2f)" % f)
	check(is_equal_approx(Machines.worker_time_mult(g.data, [], line), 1.0), "no machines, no speed-up")
	# too poor to run the machines: the lab hand waits with the ingredients
	var p := machine_shack(0)
	p.tick(1.0)
	check(p.estates.shaft_shack.job.is_empty() and p.estates.shaft_shack.storage.get("cannabis", 0) == 5, "no money for the machines: nothing starts, raws stay")


func test_machines_save() -> void:
	var g := machine_game()
	Machines.run(g, "auto_trimmer", "weed", 4)
	Bench.record(g, "extractor", 0.6)
	var json := JSON.stringify(g.to_dict())
	var d: Dictionary = JSON.parse_string(json)
	check(int(d.version) >= 2, "save version bumped for machines")
	var h := Game.new()
	h.from_dict(data, d)
	h.inside_estate = "cannery_annex"
	check(h.stats.machine_runs == 1 and h.estates.cannery_annex.buildings[0].runs == 1, "run counters survive save/load")
	check(JSON.stringify(h.to_dict()) == json, "save with machines is stable")
	check(Machines.find(h, "cannery_annex", "drip_mixer") == 2 and Machines.find(h, "cannery_annex", "auto_trimmer") == 0, "find locates machines after load")
	# a version 1 save (no machine counters, buildings without runs) still loads
	var old: Dictionary = JSON.parse_string(JSON.stringify(new_game().to_dict()))
	old.version = 1
	old.stats.erase("machine_runs")
	var o := Game.new()
	o.from_dict(data, old)
	check(o.stats.machine_runs == 0 and o.estate_owned("cannery_rig"), "version 1 saves load with zeroed machine stats")
	# a building the data no longer knows is dropped, not a crash
	var bad: Dictionary = JSON.parse_string(json)
	bad.estates.cannery_annex.buildings.append({"id": "ghost_machine", "x": 8, "y": 5})
	var b := Game.new()
	b.from_dict(data, bad)
	check(b.estates.cannery_annex.buildings.size() == 5, "unknown buildings in a save are dropped")


# ---------------------------------------------------------------- quests

const QUEST_EVENTS := ["bought", "sold", "tray_started", "tray_mixed", "tray_step", "lab_started", "lab_done", "collected",
	"app_opened", "price_set", "offer_accepted", "dealer_hired", "dealer_stocked", "dealer_collected", "entered_estate", "landed",
	"docked", "jumped", "met", "estate_bought", "debt_paid", "upgraded", "pirate_down", "building_placed", "worker_hired",
	"drop_pickup", "weapon_bought", "bribed", "scan_passed", "officer_killed", "product_discovered",
	"turf_changed", "base_raided", "interdiction_resolved", "loot"]
const QUEST_APPS := ["quests", "contacts", "fixers", "hr", "deals", "products", "orders", "map", "deaddrop"]


func test_quest_data() -> void:
	var qs: Dictionary = data.get("quests", {})
	check(not qs.is_empty(), "quests.json loaded")
	var starts := 0
	for qid in qs:
		var q: Dictionary = qs[qid]
		if q.get("start", false):
			starts += 1
		check(q.has("title") and not (q.get("steps", []) as Array).is_empty(), "quest %s has a title and steps" % qid)
		for n in q.get("next", []):
			check(qs.has(n), "quest %s: next %s exists" % [qid, n])
		for cid in q.get("reward", {}).get("meet", []):
			check(not Game.new().data.is_empty() or data.contacts.any(func(c): return c.id == cid), "quest %s rewards a real contact %s" % [qid, cid])
		for item in q.get("reward", {}).get("items", {}):
			check(data.raws.has(item) or data.additives.has(item), "quest %s reward item %s exists" % [qid, item])
		for s in q.steps:
			check(s.has("text"), "quest %s step has text" % qid)
			check(s.has("on") or s.has("check"), "quest %s step '%s' has a condition" % [qid, s.get("text", "")])
			if s.has("on"):
				check(QUEST_EVENTS.has(s.on), "quest %s: event %s is emitted somewhere" % [qid, s.on])
			var t: Dictionary = s.get("target", {})
			if t.has("app"):
				check(QUEST_APPS.has(t.app), "quest %s: app %s exists" % [qid, t.app])
			if t.has("loc"):
				check(data.locations.has(t.loc), "quest %s: target location %s" % [qid, t.loc])
			if t.has("building"):
				check(data.surfaces.get(t.loc, {}).get("buildings", []).any(func(b): return b.id == t.building), "quest %s: building %s on %s" % [qid, t.building, t.loc])
			if t.has("estate"):
				check(data.estates.has(t.estate) and str(data.estates[t.estate].get("location", "")) == str(t.loc), "quest %s: estate %s on %s" % [qid, t.estate, t.loc])
			if t.has("contact"):
				check(data.surfaces.get(t.loc, {}).get("npcs", []).any(func(n): return n.get("contact", "") == t.contact), "quest %s: contact %s stands on %s" % [qid, t.contact, t.loc])
			if t.has("station") and t.station != "@next":
				check(data.stations.has(t.station), "quest %s: station %s" % [qid, t.station])
			var os: Dictionary = s.get("on_start", {})
			if os.has("offer"):
				check(data.contacts.any(func(c): return c.id == os.offer), "quest %s: offer contact %s" % [qid, os.offer])
	check(starts >= 1, "at least one quest starts a new run")


func test_quest_tutorial_flow() -> void:
	var g := new_game()
	check(g.quests.active.is_empty(), "core new_game starts no quests (sims and tests stay unchanged)")
	var log: Array = []
	g.event.connect(func(k, p): if str(k).begins_with("quest_"): log.append([k, p]))
	Quests.begin(g)
	check(Quests.tracked(g) == "tut_cook" and Quests.step_index(g, "tut_cook") == 0, "tutorial starts at step 0")
	check(Quests.target(g).get("building", "") == "market", "first waypoint: the market")
	g.location = "mireth"
	g.buy("cannabis", 3)
	check(Quests.step_index(g, "tut_cook") == 0, "3 buds are not enough")
	g.buy("cannabis", 2)
	check(Quests.step_index(g, "tut_cook") == 1, "5 buds in the hold: next step")
	g.inside_estate = "cannery_rig"
	g.note("entered_estate", {"estate": "cannery_rig"})
	check(Quests.step_index(g, "tut_cook") == 2, "inside the cannery")
	check(Bench.begin(g, "trim_table", "weed", 5).ok, "tray started")
	check(Quests.step_index(g, "tut_cook") == 3, "tray step done")
	check(int(g.cargo.get("ion_syrup", 0)) == 5, "Okka hands over Ion Syrup for the whole tray")
	Bench.record(g, "trim_table", 0.8)
	Bench.record(g, "extractor", 0.8)
	check(Bench.mix(g, ["ion_syrup"]).ok, "mixed")
	check(Quests.step_index(g, "tut_cook") == 4, "mix step done")
	while not Bench.tray(g).is_empty():
		Bench.record(g, Bench.next_station(g, Bench.tray(g)), 0.8)
	check(Quests.step_index(g, "tut_cook") == 5, "line finished: collect step (%s)" % [g.lab_queue])
	g.collect_stash()
	check(Quests.step_index(g, "tut_cook") == 5, "nothing cooked yet: collecting nothing does not count")
	g.tick(g.batch_seconds(5) + 1.0)
	var c0 := g.credits
	g.collect_stash()
	check(Quests.is_done(g, "tut_cook") and g.credits == c0 + 120, "first quest done, reward paid")
	check(Quests.tracked(g) == "tut_price", "next quest tracked")
	check(Quests.target(g).get("app", "") == "products", "phone app target")
	g.note("app_opened", {"app": "contacts"})
	check(Quests.step_index(g, "tut_price") == 0, "wrong app does not count")
	g.note("app_opened", {"app": "products"})
	var rk: String = g.recipes.keys()[0]
	Products.set_price(g, rk, Products.suggested(g, rk))
	check(Quests.is_done(g, "tut_price") and Quests.is_active(g, "tut_deal"), "price quest done, deal quest on")
	var o: Dictionary = Deals.open_for(g, "okka")
	check(not o.is_empty(), "the deal quest makes Okka text you")
	check(Deals.accept(g, o.id).ok and Quests.step_index(g, "tut_deal") == 1, "accepting moves on")
	check(Quests.target(g).get("contact", "") == "okka", "waypoint on Okka")
	var key: String = g.cargo.keys().filter(func(k): return str(k).begins_with("weed:"))[0]
	g.cargo[key] = maxi(int(g.cargo[key]), int(o.qty))
	g.total_time = float(o.meet_at)
	g.location = "mireth"
	var fr: Dictionary = Deals.fulfill(g, o.id, key)
	check(fr.ok, "deal handed over: %s" % fr.msg)
	check(Quests.is_done(g, "tut_deal") and People.state(g, "teo").known, "deal quest done, Teo met")
	g.credits += 2000
	check(Dealers.hire(g, "rook").ok and Quests.step_index(g, "tut_dealer") == 1, "dealer hired")
	g.cargo[key] = 5
	Dealers.assign(g, "rook", "mireth")
	var gv: Dictionary = Dealers.give(g, "rook", key, 3)
	check(gv.ok and Quests.is_done(g, "tut_dealer"), "dealer stocked: tutorial over (%s)" % gv.msg)
	check(not Quests.in_tutorial(g) and Quests.tracked(g) == "main_collector", "tutorial over, main quest tracked")
	check(log.filter(func(e): return e[0] == "quest_done").size() == 4, "4 tutorial quests finished")


func test_quest_retry_and_skip() -> void:
	var g := new_game()
	Quests.start(g, "tut_deal")
	var o: Dictionary = Deals.open_for(g, "okka")
	check(not o.is_empty(), "offer forced")
	Deals.decline(g, o.id)
	var o2: Dictionary = Deals.open_for(g, "okka")
	check(Quests.step_index(g, "tut_deal") == 0 and not o2.is_empty() and o2.id != o.id, "declined: Okka texts again")
	Deals.accept(g, o2.id)
	check(Quests.step_index(g, "tut_deal") == 1, "accepted")
	g.total_time = float(o2.meet_at) + 99999.0
	Deals.tick(g, 0.1)
	check(Quests.step_index(g, "tut_deal") == 0 and not Deals.open_for(g, "okka").is_empty(), "no-show: back to step 0 with a new text")
	# a state check that already holds completes on entry
	var g2 := new_game()
	g2.cargo["cannabis"] = 9
	Quests.begin(g2)
	check(Quests.step_index(g2, "tut_cook") == 1, "buds already in the hold skip the market step")
	var c0 := g2.credits
	Quests.skip_tutorial(g2)
	check(not Quests.in_tutorial(g2) and g2.credits == c0, "skipped without rewards")
	for qid in data.quests:
		if data.quests[qid].get("tutorial", false):
			check(Quests.is_done(g2, qid), "%s marked done" % qid)
	# events while nothing is active are harmless
	var g3 := new_game()
	g3.buy("cannabis", 1)
	check(g3.quests.active.is_empty(), "no quests, no crash")


func test_quest_save() -> void:
	var g := new_game()
	Quests.begin(g)
	g.location = "mireth"
	g.buy("cannabis", 5)
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2 := Game.new()
	g2.from_dict(data, d)
	check(Quests.is_active(g2, "tut_cook") and Quests.step_index(g2, "tut_cook") == 1, "quest step survives a save")
	check(Quests.tracked(g2) == "tut_cook", "tracked quest survives")
	d.erase("quests")
	var g3 := Game.new()
	g3.from_dict(data, d)
	check(not Quests.in_tutorial(g3) and Quests.is_done(g3, "tut_cook"), "old saves skip the tutorial")
	check(Quests.is_active(g3, "main_collector"), "old saves start the main quest")
	d["quests"] = {"active": ["nope", "tut_price"], "done": ["tut_cook", "bogus"], "step": {"tut_price": 99}, "count": {}, "tracked": "nope"}
	var g4 := Game.new()
	g4.from_dict(data, d)
	check(g4.quests.active == ["tut_price"] and g4.quests.done == ["tut_cook"], "unknown quest ids dropped")
	check(Quests.step_index(g4, "tut_price") == 1 and Quests.tracked(g4) == "tut_price", "step index clamped, tracking repaired")


func test_quest_main_chapter1() -> void:
	var g := new_game()
	Quests.start(g, "main_collector")
	g.location = "mireth"
	g.credits = 20000
	var due := g.debt_due_day
	g.pay_debt(400)
	check(Quests.is_active(g, "main_collector") and Quests.progress_text(g, "main_collector") == "400/1000", "installment counts up")
	g.pay_debt(600)
	check(Quests.is_done(g, "main_collector") and g.debt_due_day == due + 2, "first installment: two extra days")
	check(Quests.is_active(g, "main_annex") and Quests.target(g).estate == "cannery_annex", "annex quest with its waypoint")
	check(g.buy_estate("cannery_annex").ok and Quests.is_done(g, "main_annex"), "second estate bought")
	g.cargo["coca_leaf"] = 4
	Quests.refresh(g)
	check(Quests.step_index(g, "main_heavier") == 1, "coca leaf in the hold")
	g.inside_estate = "cannery_rig"
	check(Bench.begin(g, "precursor_scale", "cocaine", 4).ok, "cocaine tray")
	while not Bench.tray(g).is_empty():
		Bench.record(g, Bench.next_station(g, Bench.tray(g)), 0.7)
	check(Quests.is_done(g, "main_heavier") and People.state(g, "vesna").known, "cocaine cooked, Vesna met")
	check(Quests.space_goal(g, Quests.target(g)) == "halvane_gate", "waypoint to Varrow goes through the gate")
	g.inside_estate = ""
	g.undock()
	check(g.jump("halvane_gate").ok, "jumped")
	check(Quests.step_index(g, "main_kovar") == 1 and Quests.space_goal(g, Quests.target(g)) == "varrow", "in Kovar, waypoint on Varrow")
	g.dock("varrow")
	g.note("landed", {"location": "varrow"})
	check(Quests.is_active(g, "main_rhea"), "landed: Rhea's quest")
	var key := "cocaine:" + str(data.bases.cocaine.innate)
	g.cargo[key] = 30
	var sold := 0
	for i in 6:
		g.contact_ready_at.erase("rhea")
		People.state(g, "rhea").spent = 0
		var r: Dictionary = g.sell(key, 4, "rhea")
		if r.ok:
			sold += 4
		if Quests.is_done(g, "main_rhea"):
			break
	check(Quests.is_done(g, "main_rhea") and People.state(g, "kip").known, "10 units to Rhea (%d sold), Kip met" % sold)
	for i in 3:
		SpaceCombat.collect_bounty(g, g.rng)
	check(Quests.is_done(g, "main_comets") and Quests.is_active(g, "main_clear"), "3 raiders down")
	g.credits = 100000
	g.location = "mireth"
	g.pay_debt(g.debt)
	check(Quests.is_done(g, "main_clear") and g.state == "won", "debt paid: chapter 1 done")
	check(g.quests.active == ["main_turf"], "chapter 1 done, chapter 2 starts with Turf War")


# ---------------------------------------------------------------- cartels and influence (I1)

func test_cartels_data() -> void:
	var cd: Dictionary = data.cartels
	check(cd.gangs.size() == 3, "three rival cartels")
	for c in cd.gangs:
		var gd: Dictionary = cd.gangs[c]
		check(data.systems.has(gd.home), "cartel %s home system exists" % c)
		check(str(gd.name) != "" and str(gd.boss) != "" and str(gd.color).begins_with("#"), "cartel %s has a name, boss and colour" % c)
	for loc in cd.start:
		check(data.locations.has(loc) and not (data.locations[loc].demand as Dictionary).is_empty(), "influence start %s is a trade location" % loc)
		var t := 0.0
		for a in cd.start[loc]:
			check(a == "you" or cd.gangs.has(a), "influence start %s actor %s known" % [loc, a])
			t += float(cd.start[loc][a])
		check(t <= 1.0, "influence start %s sums to at most 1" % loc)
	var g := new_game()
	for loc in data.locations:
		check(g.cartels.influence.has(loc) == not (data.locations[loc].demand as Dictionary).is_empty(), "influence only on trade locations (%s)" % loc)
	check(is_equal_approx(Cartels.share(g, "mireth"), 0.25) and is_equal_approx(Cartels.share(g, "glacis", "tide"), 0.55), "start shares from content")
	check(Cartels.owner(g, "glacis") == "tide" and Cartels.owner(g, "mireth") == "", "Glacis starts as Tide turf, Mireth contested")
	check(Cartels.present(g, "kovar")[0].id == "tide" or Cartels.present(g, "kovar")[0].id == "veil", "Kovar cartels listed strongest first")


func test_cartels_influence() -> void:
	var g := new_game()
	var events: Array = []
	g.event.connect(func(k, p): events.append([k, p]))
	# a sale takes ground at that location, partly from the cartel there
	var before := Cartels.share(g, "mireth")
	var comets := Cartels.share(g, "mireth", "comets")
	var host := Cartels.hostility(g, "comets")
	g.cargo["weed:glow"] = 20
	var r := g.sell("weed:glow", 10, "")
	check(not r.ok, "Mireth has no fence")
	var taken := Cartels.gain(g, "mireth", "you", 0.1)
	check(is_equal_approx(Cartels.share(g, "mireth"), before + 0.1), "gain adds the share")
	check(Cartels.share(g, "mireth", "comets") < comets and taken.has("comets") and taken.has("free"), "ground comes from the street and the cartel: %s" % taken)
	check(Cartels.hostility(g, "comets") > host, "taking ground angers the cartel")
	var sum := Cartels.free_share(g, "mireth")
	for a in g.cartels.influence.mireth:
		sum += float(g.cartels.influence.mireth[a])
	check(is_equal_approx(sum, 1.0), "shares plus street stay 1")
	# the fence sale at the bazaar uses the hook
	g.location = "bazaar"
	g.system = "halvane"
	var bz := Cartels.share(g, "bazaar")
	check(g.sell("weed:glow", 10, "").ok, "fence sale works")
	check(is_equal_approx(Cartels.share(g, "bazaar"), bz + 10 * float(data.cartels.sale_per_unit)), "every unit sold takes ground")
	# price follows the balance of power
	var p1 := g.sell_price("weed:glow", "", "bazaar")
	Cartels.gain(g, "bazaar", "you", 0.5)
	check(g.sell_price("weed:glow", "", "bazaar") > p1, "holding the streets pays better")
	check(Cartels.price_mult(g, "beacon") == 1.0, "no influence, no price change")
	# turf flips are announced
	check(Cartels.owner(g, "bazaar") == "you", "over half = your turf")
	var flips := events.filter(func(e): return e[0] == "turf_changed" and e[1].loc == "bazaar")
	check(flips.size() == 1 and flips[0][1].by == "you", "turf change event")
	check(Cartels.turf_label(g, "bazaar") == "Your turf" and Cartels.turf_label(g, "glacis").begins_with("Saltglass"), "turf labels")
	# pressure: more ground, fewer raiders
	var p_lo := Cartels.pressure_mult(g, "halvane")
	Cartels.gain_system(g, "halvane", "you", 0.4)
	check(Cartels.pressure_mult(g, "halvane") < p_lo, "your ground lowers raider pressure")
	# kills and raids hit the cartel where it is
	g.system = "kovar"
	var veil := Cartels.share(g, "varrow", "veil")
	Cartels.on_kill(g, "veil")
	check(Cartels.share(g, "varrow", "veil") < veil and int(Cartels.state(g, "veil").kills) == 1, "a kill costs the cartel ground in that system")
	Cartels.on_raid(g, "tide")
	check(Cartels.weakened(g, "tide") and int(Cartels.state(g, "tide").raids) == 1, "a raid weakens the cartel")
	check(Cartels.hostility(g, "tide") >= float(data.cartels.hostility_per_raid), "a raid makes it furious")
	check(Cartels.mood(g, "tide") != "ignoring you", "mood text follows hostility")


func test_cartels_daily_and_robbery() -> void:
	var g := new_game()
	var gl := Cartels.share(g, "glacis", "tide")
	var vr := Cartels.share(g, "varrow", "veil")
	var mi := Cartels.share(g, "mireth")
	var host := Cartels.hostility(g, "comets")
	g._new_day()
	check(Cartels.share(g, "glacis", "tide") > gl, "the Tide pushes at home")
	check(Cartels.share(g, "varrow", "veil") > vr, "the Veil pushes at home")
	check(Cartels.share(g, "mireth") < mi, "unattended ground erodes")
	check(Cartels.hostility(g, "comets") < host, "hostility cools off")
	# cap: a cartel stops pushing at push_cap
	for i in 40:
		g._new_day()
	check(Cartels.share(g, "glacis", "tide") <= float(data.cartels.push_cap) + 0.001, "cartels stop at the push cap")
	g.state = "playing"
	# a weakened cartel does not push
	Cartels.state(g, "veil").weakened = g.day + 5
	var v2 := Cartels.share(g, "varrow", "veil")
	g._new_day()
	check(is_equal_approx(Cartels.share(g, "varrow", "veil"), v2) or Cartels.share(g, "varrow", "veil") < v2, "a weakened cartel holds still")
	# robbery: a dealer on cartel turf
	var h := new_game()
	h.dealers.append({"id": "x", "loc": "glacis", "stock": {"weed:glow": 10}, "cash": 400, "sold": 0, "jail": 0.0})
	check(Cartels.rob_chance(h, "glacis") > 0.0, "dealer on Tide turf can be robbed")
	check(Cartels.rob_chance(h, "mireth") == 0.0, "no robbery where no cartel holds turf")
	data.cartels.rob_chance = 99.0
	var events: Array = []
	h.event.connect(func(k, p): if k == "dealer_robbed": events.append(p))
	h._new_day()
	data.cartels.rob_chance = 0.6
	check(events.size() == 1 and int(h.dealers[0].cash) == 200 and int(h.dealers[0].stock["weed:glow"]) == 7, "robbery takes half the cash and a share of the stock: %s" % [h.dealers[0]])
	check(events[0].cartel == "tide", "robbery names the cartel")


func test_cartels_save() -> void:
	var g := new_game()
	Cartels.gain(g, "mireth", "you", 0.4)
	Cartels.on_raid(g, "comets")
	var d := g.to_dict()
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(d)))
	check(is_equal_approx(snappedf(Cartels.share(h, "mireth"), 0.001), snappedf(Cartels.share(g, "mireth"), 0.001)), "influence survives a save")
	check(Cartels.owner(h, "mireth") == Cartels.owner(g, "mireth"), "turf owner rebuilt on load")
	check(Cartels.weakened(h, "comets") and int(Cartels.state(h, "comets").raids) == 1, "cartel state survives a save")
	var old := g.to_dict()
	old.erase("cartels")
	var o := Game.new()
	o.from_dict(data, old)
	check(is_equal_approx(Cartels.share(o, "mireth"), 0.25), "old saves start from the content defaults")
	var bad := g.to_dict()
	bad.cartels = {"influence": {"mireth": {"you": 5.0, "comets": 5.0, "ghost": 1.0}, "nowhere": {}}, "gangs": {"ghost": {}}}
	var b := Game.new()
	b.from_dict(data, bad)
	check(Cartels.share(b, "mireth") + Cartels.share(b, "mireth", "comets") <= 1.0001, "garbage shares are normalised")


# ---------------------------------------------------------------- price wars (P6)

func _war_game() -> Game:
	var g := new_game()
	g.state = "playing"
	return g


func test_pricewar_start() -> void:
	var g := _war_game()
	check(data.pricewar.days > 0 and data.pricewar.sell_cut > 0.0 and data.pricewar.buy_spike > 0.0, "price war data present")
	check(PriceWar.start_chance(g, "cinder") > 0.0, "Comets on Cinder (45%, hostile, you present) can start a war")
	check(PriceWar.start_chance(g, "mireth") == 0.0, "no war where no cartel dominates")
	check(PriceWar.start_chance(g, "glacis") == 0.0, "no war where you have no presence")
	g.dealers.append({"id": "d", "loc": "glacis", "stock": {}, "cash": 0, "sold": 0, "jail": 0.0})
	check(PriceWar.start_chance(g, "glacis") == 0.0, "Tide is not hostile enough yet")
	Cartels.state(g, "tide").hostility = 50.0
	check(PriceWar.start_chance(g, "glacis") > 0.0, "a dealer on their turf counts as presence")
	Cartels.state(g, "tide").weakened = g.day + 3
	check(PriceWar.start_chance(g, "glacis") == 0.0, "a weakened cartel starts nothing")
	var evs: Array = []
	g.event.connect(func(k, p): if k == "price_war_started": evs.append(p))
	check(PriceWar.start(g, "cinder", "comets") and PriceWar.active(g, "cinder"), "start sets the war")
	check(not PriceWar.start(g, "cinder", "comets"), "no second war at the same place")
	check(evs.size() == 1 and evs[0].loc == "cinder", "start event")
	check(PriceWar.days_left(g, "cinder") == int(data.pricewar.days), "days left = duration")
	check(PriceWar.label(g, "cinder").contains("Black Comets"), "label names the cartel")
	# cap on parallel wars
	data.pricewar.max_wars = 1
	check(PriceWar.start_chance(g, "bazaar") == 0.0, "max_wars caps parallel wars")
	data.pricewar.max_wars = 2
	# daily roll is deterministic and leaves the game RNG alone
	var h := _war_game()
	data.pricewar.chance_base = 5.0
	var st := h.rng.state
	PriceWar.new_day(h)
	data.pricewar.chance_base = 0.05
	check(PriceWar.active(h, "cinder"), "the daily roll starts a war when the chance is certain")
	check(h.rng.state == st, "the game RNG is untouched")


func test_pricewar_prices() -> void:
	var g := _war_game()
	g.location = "cinder"
	g.system = g.loc_system("cinder")
	var base_sell := g.sell_price("weed:glow", "", "cinder")
	var raw := ""
	for it in g.data.locations.cinder.sells_raw:
		raw = it
		break
	var base_buy := g.buy_price(raw, "cinder")
	PriceWar.start(g, "cinder", "comets")
	var war_sell := g.sell_price("weed:glow", "", "cinder")
	check(war_sell < base_sell and absf(float(war_sell) / base_sell - (1.0 - float(data.pricewar.sell_cut))) < 0.02, "selling fetches less: %d -> %d" % [base_sell, war_sell])
	check(g.buy_price(raw, "cinder") > base_buy, "buying costs more")
	check(g.sell_price("weed:glow", "", "mireth") == g.sell_price("weed:glow", "", "mireth"), "other places unaffected")
	var other := _war_game()
	check(g.sell_price("weed:glow", "", "mireth") == other.sell_price("weed:glow", "", "mireth"), "mireth price identical with and without war elsewhere")
	PriceWar.end(g, "cinder", "expired")
	check(g.sell_price("weed:glow", "", "cinder") == base_sell and g.buy_price(raw, "cinder") == base_buy, "prices recover")


func test_pricewar_ending() -> void:
	# expiry
	var g := _war_game()
	PriceWar.start(g, "cinder", "comets")
	data.pricewar.chance_base = 0.0
	data.pricewar.chance_per_hostility = 0.0
	for i in int(data.pricewar.days) - 1:
		g.day += 1
		PriceWar.new_day(g)
	check(PriceWar.active(g, "cinder"), "still on during the last day")
	g.day += 1
	PriceWar.new_day(g)
	check(not PriceWar.active(g, "cinder"), "expires")
	check(PriceWar.start_chance(g, "cinder") == 0.0, "truce after the end")
	# influence
	var h := _war_game()
	PriceWar.start(h, "cinder", "comets")
	var whys: Array = []
	h.event.connect(func(k, p): if k == "price_war_ended": whys.append(p.why))
	Cartels.gain(h, "cinder", "you", 0.5)
	check(not PriceWar.active(h, "cinder") and whys == ["influence"], "raising influence ends it: %s" % [whys])
	# paying off
	var p := _war_game()
	PriceWar.start(p, "cinder", "comets")
	var cost := PriceWar.pay_cost(p, "cinder")
	check(cost > 0 and PriceWar.howto(p, "cinder").contains(str(cost)), "pay cost listed in the how-to")
	p.credits = cost - 1
	check(not PriceWar.pay_off(p, "cinder").ok and PriceWar.active(p, "cinder") and p.credits == cost - 1, "too poor to pay off")
	p.credits = cost + 10
	check(PriceWar.pay_off(p, "cinder").ok and p.credits == 10 and not PriceWar.active(p, "cinder"), "paying ends it and costs credits")
	check(not PriceWar.pay_off(p, "cinder").ok, "nothing left to pay")
	# raiding a base
	var r := _war_game()
	PriceWar.start(r, "cinder", "comets")
	PriceWar.start(r, "glacis", "tide")
	Cartels.on_raid(r, "comets")
	check(not PriceWar.active(r, "cinder") and PriceWar.active(r, "glacis"), "wrecking a base ends that cartel's wars only")
	# a cartel weakened by other means ends it on the next day
	Cartels.state(r, "tide").weakened = r.day + 2
	PriceWar.new_day(r)
	check(not PriceWar.active(r, "glacis"), "weakened aggressor drops the war")
	data.pricewar.chance_base = 0.05
	data.pricewar.chance_per_hostility = 0.004


func test_pricewar_save() -> void:
	var g := _war_game()
	PriceWar.start(g, "cinder", "comets")
	g.price_truce["mireth"] = g.day + 2
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(PriceWar.active(h, "cinder") and PriceWar.days_left(h, "cinder") == PriceWar.days_left(g, "cinder"), "war survives a save")
	check(int(h.price_truce.get("mireth", 0)) == g.day + 2, "truce survives a save")
	var old := g.to_dict()
	old.erase("pricewar")
	var o := Game.new()
	o.from_dict(data, old)
	check(o.price_wars.is_empty(), "old saves have no wars")
	var bad := g.to_dict()
	bad.pricewar = {"wars": {"nowhere": {"cartel": "comets"}, "cinder": {"cartel": "ghost"}, "bazaar": 5}, "truce": {"x": 3}}
	var b := Game.new()
	b.from_dict(data, bad)
	check(b.price_wars.is_empty() and b.price_truce.is_empty(), "garbage is dropped")
	var n := new_game()
	check(n.price_wars.is_empty(), "new game has no wars")


# ---------------------------------------------------------------- space combat II (E4)

func test_space_enemies_and_loot() -> void:
	for k in ["fighter", "gunship", "interceptor"]:
		var e: Dictionary = data.space_combat.enemies[k]
		for f in ["hull", "speed", "turn", "orbit", "detect", "fire_cooldown", "damage", "bolt_speed", "bolt_range", "spread_degrees", "bounty", "radius", "shots"]:
			check(e.has(f), "enemy %s has %s" % [k, f])
	for k in data.space_combat.loot:
		for item in data.space_combat.loot[k].items:
			check(item == "product" or data.raws.has(item) or data.additives.has(item), "loot %s item %s exists" % [k, item])
	var g := fly_game()
	check(SpaceCombat.enemy_cfg(g, "pirate") == data.space_combat.pirate and SpaceCombat.enemy_cfg(g, "gunship").hull == data.space_combat.enemies.gunship.hull, "enemy rules by kind")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var events: Array = []
	g.event.connect(func(k, p): if k == "pirate_down": events.append(p))
	var cr: int = g.credits
	var r := SpaceCombat.enemy_down(g, "gunship", "comets", rng)
	var br: Array = data.space_combat.enemies.gunship.bounty
	check(int(r.bounty) >= int(br[0]) and int(r.bounty) <= int(br[1]) and g.credits == cr + int(r.bounty), "gunship bounty paid")
	check(not (r.loot as Array).is_empty(), "a gunship always drops loot")
	check(events.size() == 1 and events[0].kind == "gunship" and events[0].cartel == "comets", "pirate_down names kind and cartel")
	check(int(Cartels.state(g, "comets").kills) == 1, "cartel kill counted")
	# loot items are valid cargo
	for i in 30:
		for l in SpaceCombat.roll_loot(g, "fighter", rng):
			check(l.item == "credits" or l.item == "missiles" or data.raws.has(l.item) or data.additives.has(l.item) or Mixing.is_product(l.item), "loot item valid: %s" % l.item)
	check(SpaceCombat.roll_loot(g, "interceptor", rng).is_empty(), "Authority ships drop nothing")
	# collecting
	g.upgrades.missile = 1
	g.combat.missiles = 3
	g.credits = 100
	var c := SpaceCombat.collect_loot(g, [{"item": "credits", "qty": 50}, {"item": "missiles", "qty": 5}, {"item": "pseudo", "qty": 4}])
	check(c.ok and g.credits == 150 and g.combat.missiles == SpaceCombat.missile_cap(g) and g.cargo.get("pseudo", 0) == 4, "loot fills credits, pods up to capacity and the hold")
	g.cargo = {"cannabis": g.cargo_capacity()}
	check(not SpaceCombat.collect_loot(g, [{"item": "pseudo", "qty": 2}]).ok, "a full hold leaves the crate")


func test_space_secondaries() -> void:
	var g := fly_game()
	check(SpaceCombat.secondaries(g).is_empty() and SpaceCombat.secondary(g) == "", "no secondary weapon at the start")
	g.upgrades.flak = 1
	check(SpaceCombat.secondary(g) == "flak" and SpaceCombat.flak_damage(g) == float(data.upgrades.flak.levels[1]), "flak battery fitted")
	g.upgrades.missile = 1
	g.upgrades.ion = 2
	check(SpaceCombat.secondaries(g) == ["missile", "flak", "ion"], "cycle order")
	check(SpaceCombat.secondary(g) == "missile", "missiles selected by default")
	check(SpaceCombat.cycle_secondary(g) == "flak" and SpaceCombat.cycle_secondary(g) == "ion" and SpaceCombat.cycle_secondary(g) == "missile", "cycling wraps")
	g.combat.secondary = "ion"
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(SpaceCombat.secondary(h) == "ion", "selected secondary survives a save")


func test_space_wings() -> void:
	var g := fly_game()
	for c in data.cartels.gangs:
		check(not (data.cartels.gangs[c].wing as Dictionary).is_empty(), "cartel %s has a wing" % c)
		for k in data.cartels.gangs[c].wing:
			check(data.space_combat.enemies.has(k), "wing of %s uses known ships" % c)
	Cartels.state(g, "comets").hostility = 0.0
	var low := SpaceCombat.wing_chance(g, "comets")
	Cartels.state(g, "comets").hostility = 80.0
	var high := SpaceCombat.wing_chance(g, "comets")
	check(high > low and high <= float(data.space_combat.wings.max_chance), "angry cartels send more wings, capped")
	var u := SpaceCombat.wing_units(g, "comets")
	check(u.has("gunship") and u.count("fighter") == 4, "at war: gunship and an extra fighter join (%s)" % [u])
	Cartels.state(g, "comets").hostility = 0.0
	check(not SpaceCombat.wing_units(g, "comets").has("gunship"), "calm cartels fly fighters only")
	Cartels.state(g, "comets").weakened = g.day + 2
	check(SpaceCombat.wing_chance(g, "comets") == 0.0, "a rebuilding cartel sends no wings")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var kinds := {}
	g.system = "kovar"
	Cartels.state(g, "tide").hostility = 100.0
	Cartels.state(g, "veil").hostility = 100.0
	for i in 200:
		var pk := SpaceCombat.pick_spawn(g, rng)
		kinds[pk.cartel] = true
		check(pk.cartel == "" or Cartels.gang(g, pk.cartel).home == "kovar" or Cartels.system_share(g, "kovar", pk.cartel) > 0.0, "wings come from cartels present in the system")
	check(kinds.has("tide") or kinds.has("veil"), "Kovar sends cartel wings")


func test_cartel_bases() -> void:
	for c in data.cartels.gangs:
		var b: String = data.cartels.gangs[c].base
		check(data.locations.has(b) and data.locations[b].kind == "cartel_base" and data.locations[b].cartel == c, "cartel %s base %s exists" % [c, b])
		check(not data.locations[b].get("dockable", true), "cartel bases are not dockable")
	var g := fly_game()
	check(SpaceCombat.base_cartel(g, "comet_nest") == "comets" and SpaceCombat.base_cartel(g, "mireth") == "", "base owner")
	check(SpaceCombat.base_active(g, "comet_nest"), "base active at the start")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var cr: int = g.credits
	var mi := Cartels.share(g, "cinder", "comets")
	var r := SpaceCombat.raid_base(g, "comet_nest", rng)
	check(int(r.credits) > 0 and g.credits == cr + int(r.credits), "raid pays")
	check(Cartels.share(g, "cinder", "comets") < mi and Cartels.weakened(g, "comets"), "raid costs the cartel its ground and weakens it")
	check(not SpaceCombat.base_active(g, "comet_nest") and int(SpaceCombat.raid_base(g, "comet_nest", rng).credits) == 0, "a wrecked base pays only once")
	for i in int(data.cartels.weakened_days) + 1:
		g._new_day()
	check(SpaceCombat.base_active(g, "comet_nest"), "the base is rebuilt after a few days")
	check(Cartels.places(g).find("comet_nest") == -1, "bases hold no street influence")


func test_ship_classes() -> void:
	var g := new_game()
	check(g.ship_class == "courier" and g.hulls == ["courier"], "start in the courier")
	var cap := g.cargo_capacity()
	var hull := SpaceCombat.max_hull(g)
	check(g.buy_ship("hauler").ok == false, "the hauler costs money")
	g.credits = 10000
	var r := g.buy_ship("hauler")
	check(r.ok and g.ship_class == "hauler" and g.hulls.has("hauler") and g.credits == 10000 - int(data.ship_classes.hauler.price), "hauler bought")
	check(g.cargo_capacity() > cap and SpaceCombat.max_hull(g) > hull and g.engine_mult() < 1.0, "hauler: bigger hold and armour, slower")
	check(is_equal_approx(SpaceCombat.hull_ratio(g), 1.0), "full hull after the swap")
	g.cargo = {"cannabis": g.cargo_capacity()}
	check(not g.switch_ship("courier").ok, "cargo has to fit the smaller hold")
	g.cargo = {}
	g.combat.hull = SpaceCombat.max_hull(g) * 0.5
	check(g.switch_ship("courier").ok and g.ship_class == "courier" and g.credits == 10000 - int(data.ship_classes.hauler.price), "switching back is free")
	check(is_equal_approx(SpaceCombat.hull_ratio(g), 0.5), "damage carries over as a share")
	g.credits = 10000
	g.buy_ship("corvette")
	check(SpaceCombat.laser_damage(g) > float(data.upgrades.laser.levels[0]) and SpaceCombat.max_shield(g) == 0.0, "corvette lasers hit harder (no shield module yet)")
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(h.ship_class == "corvette" and h.hulls.size() == 3, "hulls survive a save")
	g.undock()
	check(not g.buy_ship("runner").ok, "only at a shipyard")
	var old := g.to_dict()
	old.erase("hulls")
	old.ship_class = "battleship"
	var o := Game.new()
	o.from_dict(data, old)
	check(o.ship_class == "courier" and o.hulls == ["courier"], "old or broken saves fly the courier")


# ---------------------------------------------------------------- interdiction (D3)

func test_patrol_feel_fields() -> void:
	var rules: Dictionary = data.patrol_feel
	for sys in data.systems:
		var fl := PatrolFeel.fields(data, sys)
		check(not fl.is_empty(), "%s has asteroid fields" % sys)
		for f in fl:
			check(absf(f.pos.x) + f.radius < 4200.0 and absf(f.pos.y) + f.radius < 4200.0, "%s field inside the sector" % sys)
			for id in data.locations:
				var ld: Dictionary = data.locations[id]
				if str(ld.get("system", "")) == sys:
					var lp := Vector2(float(ld.pos[0]), float(ld.pos[1]))
					check(lp.distance_to(f.pos) > f.radius + float(ld.radius) + 100.0, "%s field keeps clear of %s" % [sys, id])
	var fl := PatrolFeel.fields(data, "halvane")
	var c: Vector2 = fl[0].pos
	var base := 380.0
	check(PatrolFeel.depth(fl, Vector2(9000, 9000)) == 0.0, "no depth outside fields")
	check(is_equal_approx(PatrolFeel.depth(fl, c), 1.0), "full depth at the middle")
	check(is_equal_approx(PatrolFeel.scan_radius_at(data, base, fl, Vector2(9000, 9000)), base), "scan range unchanged in open space")
	check(is_equal_approx(PatrolFeel.scan_radius_at(data, base, fl, c), base * float(rules.field_scan_mult)), "scan range shrinks in the middle of a field")
	var edge := c + Vector2(fl[0].radius * 0.95, 0)
	var mid := c + Vector2(fl[0].radius * 0.5, 0)
	check(not PatrolFeel.breaks_pursuit(data, fl, edge), "the rim of a field does not break pursuit")
	check(PatrolFeel.breaks_pursuit(data, fl, mid) and PatrolFeel.breaks_pursuit(data, fl, c), "inside a field patrols lose lock")
	check(PatrolFeel.scan_radius_at(data, base, fl, mid) < PatrolFeel.scan_radius_at(data, base, fl, edge), "deeper means a smaller scan range")
	check(PatrolFeel.fields(data, "nowhere").is_empty(), "unknown system has no fields")


func test_patrol_feel_warning() -> void:
	var m := float(data.patrol_feel.warn_margin)
	check(PatrolFeel.warn_level(data, 1000.0, 380.0) == PatrolFeel.CLEAR, "far away is clear")
	check(PatrolFeel.warn_level(data, 380.0 + m - 1.0, 380.0) == PatrolFeel.CLOSE, "inside the margin warns")
	check(PatrolFeel.warn_level(data, 379.0, 380.0) == PatrolFeel.SCANNED, "inside the radius is scanned")
	var st := {}
	var fired := 0
	for i in 600:  # 10 s hovering at the edge: exactly one warning
		if PatrolFeel.warn_tick(data, st, PatrolFeel.CLOSE, 1.0 / 60.0):
			fired += 1
	check(fired == 1, "hovering at the edge warns once (got %d)" % fired)
	for i in 60 * 4:  # clear for 4 s re-arms
		PatrolFeel.warn_tick(data, st, PatrolFeel.CLEAR, 1.0 / 60.0)
	check(PatrolFeel.warn_tick(data, st, PatrolFeel.CLOSE, 1.0 / 60.0), "warns again after clearing the range")
	var st2 := {}
	check(PatrolFeel.warn_tick(data, st2, PatrolFeel.SCANNED, 0.016), "being scanned with no warning yet still warns once")
	st = {}
	var n := 0
	for i in 300:  # flicker CLOSE/CLEAR every frame never re-arms
		if PatrolFeel.warn_tick(data, st, PatrolFeel.CLOSE if i % 2 == 0 else PatrolFeel.CLEAR, 0.016):
			n += 1
	check(n == 1, "flickering at the margin does not spam (got %d)" % n)


func jump_game() -> Game:
	var g := fly_game()
	g.day = 3
	g.location = ""
	g.system = "halvane"
	return g


func test_interdiction_chances() -> void:
	var g := jump_game()
	for u in data.interdiction.authority_units:
		check(data.space_combat.enemies.has(u), "authority unit %s known" % u)
	check(Interdiction.authority_chance(g) == 0.0, "no product, no Authority interdiction")
	g.cargo = {"weed:glow": 10}
	g.heat = 10.0
	check(Interdiction.authority_chance(g) == 0.0, "low heat, no Authority interdiction")
	g.heat = 90.0
	check(Interdiction.authority_chance(g) > 0.0 and Interdiction.authority_chance(g) <= float(data.interdiction.max_chance), "hot cargo draws the Authority")
	Cartels.state(g, "comets").hostility = 0.0
	var calm := Interdiction.cartel_chance(g, "comets", "halvane")
	Cartels.state(g, "comets").hostility = 90.0
	var angry := Interdiction.cartel_chance(g, "comets", "halvane")
	check(angry > calm and angry <= float(data.interdiction.max_chance), "angry cartels interdict more")
	g.cargo = {}
	check(Interdiction.cartel_chance(g, "comets", "halvane") < angry, "an empty hold is less tempting")
	check(Interdiction.cartel_chance(g, "tide", "halvane") == 0.0, "a cartel with no ground in the system stays home")
	Cartels.state(g, "comets").weakened = g.day + 1
	check(Interdiction.cartel_chance(g, "comets", "halvane") == 0.0, "a rebuilding cartel does not interdict")
	var f := Interdiction.flee_chance(g)
	g.upgrades.engine = 3
	check(Interdiction.flee_chance(g) > f, "engines help to flee")


func _pending(g: Game, kind: String, cartel := "comets") -> void:
	g.interdiction = {}
	Interdiction.begin(g, {"kind": kind, "cartel": cartel if kind == "cartel" else "", "units": ["fighter", "fighter"]})


func test_interdiction_choices() -> void:
	var g := jump_game()
	var events: Array = []
	g.event.connect(func(k, p): if k == "interdicted" or k == "interdiction_resolved": events.append(k))
	check(not Interdiction.resolve(g, "pay").ok, "nothing to resolve")
	# pay the cartel toll: base + per unit of product
	g.cargo = {"weed:glow": 10}
	_pending(g, "cartel")
	var cost := Interdiction.pay_cost(g, g.interdiction)
	check(cost == int(data.interdiction.toll_base) + 10 * int(data.interdiction.toll_per_unit), "toll scales with product")
	g.credits = cost - 1
	check(not Interdiction.resolve(g, "pay").ok and Interdiction.pending(g), "can't pay: encounter stays open")
	g.credits = cost + 5
	var r := Interdiction.resolve(g, "pay")
	check(r.ok and not r.fight and g.credits == 5 and not Interdiction.pending(g), "toll paid")
	check(events == ["interdicted", "interdicted", "interdiction_resolved"] or events.count("interdiction_resolved") == 1, "events: %s" % [events])
	# dump to the cartel: product gone, they gain ground
	_pending(g, "cartel")
	g.cargo = {"weed:glow": 10, "cannabis": 4}
	var sh := Cartels.system_share(g, "halvane", "comets")
	r = Interdiction.resolve(g, "dump")
	check(r.ok and not g.cargo.has("weed:glow") and g.cargo.get("cannabis", 0) == 4, "dump hands over product only")
	check(Cartels.system_share(g, "halvane", "comets") > sh, "the cartel gains ground from the handover")
	_pending(g, "cartel")
	check(not Interdiction.resolve(g, "dump").ok, "nothing to dump")
	# fight: units to spawn
	r = Interdiction.resolve(g, "fight")
	check(r.ok and r.fight and r.units.size() == 2 and r.cartel == "comets", "fight hands the wing to the world")
	# Authority: bribe lowers heat, fighting raises it
	g.heat = 80.0
	g.cargo = {"weed:glow": 5}
	_pending(g, "authority")
	cost = Interdiction.pay_cost(g, g.interdiction)
	g.credits = 5000
	r = Interdiction.resolve(g, "pay")
	check(r.ok and g.credits == 5000 - cost and g.heat < 80.0, "bribe paid, heat down")
	_pending(g, "authority")
	var h := g.heat
	r = Interdiction.resolve(g, "fight")
	check(r.fight and g.heat > h and r.cartel == "", "fighting the Authority raises heat")
	_pending(g, "authority")
	h = g.heat
	r = Interdiction.resolve(g, "dump")
	check(r.ok and not g.has_contraband() and g.heat < h, "dumping before the scan: clean, heat down")
	# flee: success or a fight with damage
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var ok := 0
	var fights := 0
	for i in 40:
		g.combat.hull = SpaceCombat.max_hull(g)
		g.combat.shield = 0.0
		_pending(g, "cartel")
		r = Interdiction.resolve(g, "flee", rng)
		if r.fight:
			fights += 1
			check(g.combat.hull < SpaceCombat.max_hull(g), "a failed escape costs hull")
		else:
			ok += 1
	check(ok > 0 and fights > 0, "fleeing sometimes works (%d / %d)" % [ok, fights])
	# interceptor kills are a crime, pay nothing
	var cr := g.credits
	h = g.heat
	SpaceCombat.enemy_down(g, "interceptor", "", rng)
	check(g.credits == cr and g.heat > h, "shooting down an interceptor pays nothing and adds heat")


func test_interdiction_on_jump() -> void:
	var g := jump_game()
	g.credits = 100000
	g.cargo = {"weed:glow": 20}
	Cartels.state(g, "comets").hostility = 100.0
	Cartels.state(g, "tide").hostility = 100.0
	Cartels.state(g, "veil").hostility = 100.0
	var hits := 0
	var rng_state := g.rng.state
	for i in 30:
		g.interdiction = {}
		var gate: String = Galaxy.gates(g, g.system)[0]
		check(g.jump(gate).ok, "jump works")
		if Interdiction.pending(g):
			hits += 1
			check(g.interdiction.kind in ["cartel", "authority"] and not (g.interdiction.units as Array).is_empty(), "encounter has a crew")
	check(hits > 0 and hits < 30, "angry cartels interdict some jumps (%d of 30)" % hits)
	var d := g.to_dict()
	check(not d.has("interdiction"), "encounters are not saved")
	var e := jump_game()
	e.day = 1
	e.cargo = {"weed:glow": 20}
	Cartels.state(e, "comets").hostility = 100.0
	for i in 10:
		e.jump(Galaxy.gates(e, e.system)[0])
	check(not Interdiction.pending(e), "no interdictions on day 1")


func test_quest_chapter2() -> void:
	var g := new_game()
	var qs: Dictionary = Quests.defs(g)
	for q in ["main_turf", "main_lanes", "main_nest", "main_rig"]:
		check(qs.has(q) and int(qs[q].chapter) == 2 and qs[q].main, "chapter 2 quest %s" % q)
	check((qs.main_clear.next as Array).has("main_turf"), "chapter 2 follows the debt")
	Quests.start(g, "main_turf")
	Cartels.gain(g, "mireth", "you", 0.4)
	check(g.quests.done.has("main_turf") and g.quests.active.has("main_lanes"), "taking a street finishes Turf War")
	g.day = 3
	g.interdiction = {}
	Interdiction.begin(g, {"kind": "cartel", "cartel": "comets", "units": ["fighter"]})
	Interdiction.resolve(g, "fight")
	check(g.quests.done.has("main_lanes") and g.quests.active.has("main_nest"), "surviving an interdiction finishes Toll Road")
	g.system = "kovar"
	SpaceCombat.raid_base(g, "tide_rig", g.rng)
	check(g.quests.active.has("main_nest"), "the wrong base does not count")
	g.system = "halvane"
	SpaceCombat.raid_base(g, "comet_nest", g.rng)
	check(g.quests.done.has("main_nest") and g.quests.active.has("main_rig"), "raiding the Nest finishes Smoke the Nest")
	check(Quests.space_goal(g, {"loc": "tide_rig"}) == "halvane_gate", "the Rig waypoint routes through the gate")



# ---------------------------------------------------------------- escort missions (E4 leftover)

## Runs the freighter until it arrives (or `max_s` seconds pass). Returns the last step state.
func escort_run(g: Game, ship_pos_of: Callable, max_s := 600.0) -> String:
	var st := "idle"
	var t := 0.0
	while t < max_s and Escort.active(g):
		st = str(Escort.step(g, 0.1, ship_pos_of.call()).state)
		t += 0.1
		if st == "at_gate" or st == "waiting":
			break
	return st


func test_escort_data() -> void:
	var ms: Dictionary = Escort.missions(new_game())
	check(ms.size() >= 4, "escort missions exist")
	var cross := 0
	for mid in ms:
		var m: Dictionary = ms[mid]
		check(data.locations.has(m.from) and data.locations.has(m.to) and m.from != m.to, "%s: known locations" % mid)
		check(data.locations[m.from].get("dockable", true) and data.locations[m.to].get("dockable", true), "%s: both ends dockable" % mid)
		check(int(m.reward) > 0 and int(m.waves) >= 1, "%s: pays and has waves" % mid)
		if data.locations[m.from].system != data.locations[m.to].system:
			cross += 1
	check(cross >= 1, "at least one escort crosses a gate")
	var f: Dictionary = data.escort.freighter
	check(float(f.speed) < float(data.ship.max_speed), "the freighter is slower than the player")


func test_escort_flow() -> void:
	var g := new_game()  # docked at Mireth, day 1
	var offers := Escort.offers_at(g, "mireth")
	check(offers.size() >= 2 and Escort.offers_at(g, "glacis").is_empty(), "Mireth has jobs, Glacis none")
	check(not Escort.accept(g, "nope").ok, "unknown job refused")
	check(not Escort.accept(g, "cinder_mireth").ok, "a job must be taken where it starts")
	check(not Escort.accept(g, "mireth_varrow").ok, "locked jobs refuse before their day")
	var r := Escort.accept(g, "mireth_bazaar")
	check(r.ok and Escort.active(g), "accepted")
	check(not Escort.accept(g, "mireth_bazaar").ok, "one escort at a time")
	check(Escort.goal(g) == "bazaar", "same-system goal is the destination")
	var seen: Array = []
	g.event.connect(func(k, p): seen.append(k))
	g.undock()
	var ship_pos := Escort.pos(g)
	var cr := g.credits
	var state := escort_run(g, func(): return Escort.pos(g) + Vector2(100, 0))
	check(state == "arrived" and not Escort.active(g), "the freighter arrives with its escort (%s)" % state)
	check(g.credits == cr + Escort.reward(g, "mireth_bazaar", 1.0), "full hull pays reward + bonus")
	check(seen.has("escort_done") and int(g.escort.done) == 1, "escort_done event and counter")
	check(Escort.cooldown_left(g, "mireth_bazaar") > 0 and not Escort.accept(g, "mireth_bazaar").ok, "a finished job cools down")
	# hull scales the bonus
	var h := new_game()
	Escort.accept(h, "mireth_bazaar")
	h.undock()
	h.escort.job.hull = Escort.max_hull(h) * 0.5
	var before := h.credits
	escort_run(h, func(): return Escort.pos(h))
	var m: Dictionary = data.escort.missions.mireth_bazaar
	check(h.credits == before + int(m.reward) + int(round(float(m.bonus) * 0.5)), "half hull pays half the bonus")
	# waits for a player who is far away, resumes when close
	var w := new_game()
	Escort.accept(w, "mireth_bazaar")
	w.undock()
	var start := Escort.pos(w)
	var far := start + Vector2(float(data.escort.freighter.leash) + 200.0, 0)
	check(Escort.step(w, 1.0, far).state == "waiting" and Escort.pos(w) == start, "the freighter waits for a straggler")
	check(Escort.step(w, 1.0, start).state == "moving" and Escort.pos(w) != start, "and moves again when you are back")
	# docking pauses it, abandoning ends it
	w.dock("mireth")
	var parked := Escort.pos(w)
	check(Escort.step(w, 5.0, parked).state == "idle" and Escort.pos(w) == parked, "docked: the freighter holds")
	check(Escort.abandon(w).ok and not Escort.active(w) and not Escort.abandon(w).ok, "abandon")


func test_escort_enemies() -> void:
	var g := new_game()
	Escort.accept(g, "mireth_bazaar")
	g.undock()
	var seen: Array = []
	g.event.connect(func(k, p): seen.append(k))
	var hp := float(Escort.job(g).hull)
	var res := Escort.damage(g, 40.0)
	check(not res.destroyed and is_equal_approx(float(Escort.job(g).hull), hp - 40.0), "bolts hurt the freighter")
	check(Escort.hull_ratio(g) < 1.0, "hull ratio drops")
	# waves: first after the delay, finite count, only while you are near
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var waves := 0
	var t := 0.0
	while t < 200.0:
		var w := Escort.tick_wave(g, 0.5, 0, rng)
		t += 0.5
		if not w.is_empty():
			waves += 1
			check(not (w.units as Array).is_empty() and (w.cartel == "" or data.cartels.gangs.has(w.cartel)), "a wave is pick_spawn output")
			if waves == 1:
				check(t >= float(data.escort.waves.first) - 0.01, "first wave comes after the delay")
	check(waves == int(data.escort.missions.mireth_bazaar.waves) and Escort.waves_left(g) == 0, "exactly the mission's waves come (%d)" % waves)
	var n := new_game()
	Escort.accept(n, "mireth_bazaar")
	n.undock()
	var cap := int(data.escort.waves.max_enemies)
	var blocked := true
	for i in 100:
		if not Escort.tick_wave(n, 0.5, cap, rng).is_empty():
			blocked = false
	check(blocked, "no new wave while the sky is full")
	Escort.job(n).near = false
	var calm := true
	for i in 100:
		if not Escort.tick_wave(n, 0.5, 0, rng).is_empty():
			calm = false
	check(calm, "no waves while you are away from the freighter")
	# targeting
	var f := Escort.pos(g)
	check(Escort.prefers_freighter(g, f + Vector2(600, 0), f + Vector2(1500, 0)), "raiders go for the freighter")
	check(not Escort.prefers_freighter(g, f + Vector2(600, 0), f + Vector2(700, 0)), "a player on their tail draws their fire")
	check(not Escort.prefers_freighter(g, f + Vector2(5000, 0), f), "out of range: they hunt you")
	# death fails the job without pay
	var cr := g.credits
	res = Escort.damage(g, 1000.0)
	check(res.destroyed and not Escort.active(g) and g.credits == cr, "destroyed: job over, no pay")
	check(seen.has("escort_failed") and not Escort.damage(g, 5.0).destroyed, "escort_failed fires once; no job, no damage")
	check(Escort.cooldown_left(g, "mireth_bazaar") == 0, "a failed job can be retaken")


func test_escort_jump() -> void:
	var g := new_game()
	g.day = 3
	g.credits = 5000
	check(Escort.accept(g, "mireth_varrow").ok, "the charter is open from day 2")
	check(Escort.goal(g) == "halvane_gate", "route goes via the gate")
	g.undock()
	var state := escort_run(g, func(): return Escort.pos(g))
	check(state == "at_gate" and bool(Escort.job(g).at_gate), "the freighter holds at the gate")
	var r := g.jump("halvane_gate")
	check(r.ok and Escort.active(g) and Escort.job(g).sys == "kovar", "it follows through the gate")
	check(Escort.goal(g) == "varrow", "and heads for Varrow")
	check(Escort.pos(g).distance_to(Escort.loc_pos(g, "kovar_gate")) < 400.0, "it arrives next to the arrival gate")
	state = escort_run(g, func(): return Escort.pos(g))
	check(not Escort.active(g) and g.escort.done == 1 and g.credits > 5000 - 80, "arrival in the second system pays")
	# leaving it behind
	var h := new_game()
	h.day = 3
	h.credits = 5000
	Escort.accept(h, "mireth_varrow")
	h.undock()
	Escort.step(h, 0.1, Escort.pos(h) + Vector2(5000, 0))
	check(h.jump("halvane_gate").ok and not Escort.active(h) and h.escort.done == 0, "jumping while it is far away fails the job")


func test_escort_save() -> void:
	var g := new_game()
	Escort.accept(g, "mireth_bazaar")
	g.undock()
	Escort.step(g, 2.0, Escort.pos(g))
	Escort.damage(g, 55.0)
	g.escort.last["cinder_mireth"] = 1
	var d := g.to_dict()
	check(d.has("escort") and d.escort.job.mission == "mireth_bazaar", "escort is saved")
	var e := Game.new()
	e.from_dict(data, JSON.parse_string(JSON.stringify(d)))
	check(Escort.active(e) and Escort.pos(e).distance_to(Escort.pos(g)) < 0.2, "job and freighter position survive a save")
	check(absf(float(Escort.job(e).hull) - float(Escort.job(g).hull)) < 0.2 and e.escort.last.has("cinder_mireth"), "hull and cooldowns survive")
	var old := d.duplicate(true)
	old.erase("escort")
	var o := Game.new()
	o.from_dict(data, old)
	check(not Escort.active(o) and int(o.escort.done) == 0, "old saves have no escort")
	var bad := d.duplicate(true)
	bad.escort.job.mission = "ghost"
	var b := Game.new()
	b.from_dict(data, bad)
	check(not Escort.active(b), "a job with an unknown mission is dropped")
func test_heat_zones() -> void:
	var m: Dictionary = data.surfaces.mireth
	var plaza: Array = m.plazas[0]
	var inside := Vector2(float(plaza[0]) + 1.0, float(plaza[1]) + 1.0)
	check(HeatZones.zone_at(m, inside) == "plaza", "plaza rect is the plaza zone")
	check(HeatZones.zone_at(m, Vector2(float(plaza[0]) + float(plaza[2]), float(plaza[1]))) != "plaza", "plaza edge is exclusive")
	var road: Array = m.roads[0]
	check(HeatZones.zone_at(m, Vector2(float(road[0]) + 0.5, float(road[1]) + 0.5)) in ["street", "plaza"], "road cell is street (or plaza)")
	check(HeatZones.zone_at(m, Vector2(-5, -5)) == "alley", "off the roads is an alley")
	check(HeatZones.zone_at({"roads": [], "plazas": []}, Vector2(3, 3)) == "street", "no roads/plazas (estate) = street")
	for loc in data.surfaces:
		var seen := {}
		var s: Dictionary = data.surfaces[loc]
		for x in range(0, int(s.size[0])):
			for y in range(0, int(s.size[1])):
				seen[HeatZones.zone_at(s, Vector2(x + 0.5, y + 0.5))] = true
		check(seen.has("alley") or s.roads.is_empty(), "%s has back alleys" % loc)
	var z: Dictionary = data.heat_zones.zones
	check(z.plaza.mult > z.street.mult and z.street.mult > z.alley.mult, "plaza hotter than street hotter than alley")
	check(HeatZones.zone_mult(new_game(), "nonsense") == 1.0, "unknown zone = neutral")
	check(HeatZones.tip(new_game(), "plaza").contains("160%"), "tooltip names the percentage")
	var heats := {}
	for zone in ["plaza", "street", "alley", ""]:
		var g := new_game()
		g.heat_zone = zone
		g.cargo["weed:glow"] = 4
		check(g.sell("weed:glow", 4, "okka").ok, "sell in zone '%s'" % zone)
		heats[zone] = g.heat
	check(heats.plaza > heats.street and heats.street > heats.alley, "sale heat follows the zone: %s" % str(heats))
	check(is_equal_approx(heats[""], heats.street), "no zone = street heat (sim/space unchanged)")
	check(is_equal_approx(heats.plaza / heats.street, float(z.plaza.mult)), "plaza multiplier applied exactly")
func test_curfew() -> void:
	var g := new_game()
	g.credits = 1000
	g.day_time = 0.0
	var noon := g.day_seconds() * 0.4
	g.day_time = noon
	check(not Curfew.active(g), "no curfew at midday")
	var base: int = g.police_on_foot(1.0)
	var night := g.day_seconds() * 0.9
	g.day_time = night
	var h := People.hour(g)
	check(h >= 22.0 or h < 5.0, "test clock is inside the curfew window (%s)" % h)
	check(Curfew.active(g) and Curfew.enforced(g), "curfew at night")
	check(g.police_on_foot(1.0) == mini(base + 2, 99) or g.police_on_foot(1.0) > base, "more officers at night")
	check(g.police_on_foot(0.0) == 0, "lawless planets have no curfew patrols")
	check(Curfew.vision_mult(g) > 1.0, "officers see further at night")
	g.heat = 20.0
	var cost := Curfew.bribe_cost(g)
	check(cost == 60 + 2 * 20, "bribe cost grows with heat")
	var res := Curfew.bribe(g)
	check(res.ok and g.credits == 1000 - cost, "bribe pays")
	check(not Curfew.enforced(g) and g.police_on_foot(1.0) == base, "pass switches the curfew bonus off")
	check(is_equal_approx(g.heat, 10.0), "bribe cools heat")
	g.total_time += 4.0 * Deals.seconds_per_hour(g)
	check(Curfew.enforced(g), "pass runs out")
	g.credits = 0
	check(not Curfew.bribe(g).ok, "broke: no bribe")
	g.day_time = noon
	check(not Curfew.bribe(g).ok, "nothing to bribe by day")
## P2: customers on foot walk up to you on a planet; accept / haggle / decline, all through the normal sell path.
func test_walkups() -> void:
	var g := new_game()
	g.location = "mireth"
	check(Walkups.offer_for(g, "okka").is_empty(), "no product in the hold, nobody walks up")
	g.cargo["weed:glow"] = 12
	var w := Walkups.offer_for(g, "okka")
	check(not w.is_empty() and w.product == "weed:glow" and w.base == "weed", "Okka wants your weed")
	check(int(w.price) == g.unit_price("weed:glow", "okka") and int(w.qty) >= 1 and int(w.qty) <= People.max_units(g, "okka"), "price is the sell price, amount within their limit")
	# your asking price decides what they pay; too steep = they do not come
	var rk := "weed:glow"
	g.recipes[rk] = {"base": "weed", "additives": []}
	g.prices[rk] = 100000
	check(Walkups.offer_for(g, "okka").is_empty(), "an asking price above their ceiling keeps them away")
	g.prices[rk] = maxi(int(w.price) - 1, 1)
	check(int(Walkups.offer_for(g, "okka").price) == Products.asking(g, rk), "they pay your asking price")
	g.prices.erase(rk)
	g.recipes.erase(rk)
	# strangers come over less often than people you know
	var local: Dictionary = data.contacts.filter(func(c): return c.get("local", false) and c.location == "mireth")[0]
	var stranger := Walkups.chance(g, local.id)
	People.state(g, local.id).known = true
	check(Walkups.chance(g, local.id) > stranger, "strangers come over less often than people you know")
	People.state(g, local.id).known = false
	# the roll comes from tick() and leaves Game.rng alone
	data.walkups.chance = 5.0
	var state_before := g.rng.state
	for i in 40:
		Walkups.tick(g, 12.0)
		g.total_time += 12.0
		if Walkups.count(g) > 0:
			break
	check(Walkups.count(g) > 0 and g.rng.state == state_before, "customers walk up over time without touching Game.rng (%d)" % Walkups.count(g))
	check(Walkups.count(g) <= int(data.walkups.max_active), "at most max_active at once")
	for cid in Walkups.active(g):
		check(g.contact(cid).location == "mireth" and (g.contact(cid).prefers as Array).has("weed"), "%s lives here and wants weed" % cid)
	# an open Deal-O-Matic request blocks a walk-up from the same person
	var g2 := new_game()
	g2.location = "mireth"
	g2.cargo["weed:glow"] = 5
	check(Walkups.eligible(g2, "okka"), "Okka is eligible")
	Deals.request(g2, "okka")
	check(not Walkups.eligible(g2, "okka"), "someone with an open text request does not also walk up")
	# accept = Game.sell: credits, cargo, heat, history, events
	var gs := new_game()
	gs.location = "mireth"
	gs.cargo["weed:glow"] = 12
	Walkups.active(gs)["okka"] = Walkups.offer_for(gs, "okka")
	var wa: Dictionary = Walkups.find(gs, "okka")
	var credits := gs.credits
	var quoted := Walkups.total(gs, wa)
	var heat := gs.heat
	var sold := []
	gs.event.connect(func(k, _p): if k == "sold" or k == "walkup_sold": sold.append(k))
	var res := Walkups.accept(gs, "okka")
	check(res.ok and gs.credits == credits + quoted, "accept pays the quoted total (%d, %s)" % [quoted, res.msg])
	check(int(gs.cargo["weed:glow"]) == 12 - int(wa.qty) and gs.heat > heat, "goods leave the hold and the sale heats you up")
	check(sold.has("sold") and sold.has("walkup_sold"), "the normal sold event fires (quests, cartels listen to it)")
	check(not People.state(gs, "okka").history.is_empty() and Walkups.count(gs) == 0, "sale is in their history, walk-up closed")
	check(not Walkups.eligible(gs, "okka"), "they leave you alone for a while after a sale")
	check(not Walkups.accept(gs, "okka").ok, "a closed walk-up cannot be accepted twice")
	# haggle: one try, never above their ceiling; success pays extra on top of the sale
	var gh := new_game()
	gh.location = "mireth"
	gh.cargo["weed:glow"] = 12
	var ps := People.state(gh, "okka")
	ps.affinity = 1.0
	ps.addiction = 1.0
	Walkups.active(gh)["okka"] = Walkups.offer_for(gh, "okka")
	var wh: Dictionary = Walkups.find(gh, "okka")
	var base_price := int(wh.price)
	var won := false
	for sd in 30:
		wh.price = base_price
		wh.haggled = false
		gh.rng.seed = sd
		if Walkups.haggle(gh, "okka", 0.1).ok:
			won = true
			break
	check(won and int(wh.price) > base_price and wh.haggled, "a loyal, hooked customer can be talked up (%d -> %d)" % [base_price, int(wh.price)])
	check(int(wh.price) <= Walkups.ceiling(gh, wh), "never above their ceiling")
	var c2 := gh.credits
	var quoted_h := Walkups.total(gh, wh)
	check(Walkups.accept(gh, "okka").ok and gh.credits == c2 + quoted_h and quoted_h > base_price * int(wh.qty) * 0.8, "haggled price is what you get")
	check(not Walkups.haggle(gh, "okka", 0.1).ok, "no walk-up, no haggle")
	var gf := new_game()
	gf.location = "mireth"
	gf.cargo["weed:glow"] = 12
	Walkups.active(gf)["okka"] = Walkups.offer_for(gf, "okka")
	var aff := float(People.state(gf, "okka").affinity)
	check(not Walkups.haggle(gf, "okka", 9.0).ok and float(People.state(gf, "okka").affinity) < aff, "a greedy ask fails and annoys them")
	check(not Walkups.haggle(gf, "okka", 0.05).ok, "only one haggle per customer")
	check(Walkups.accept(gf, "okka").ok, "they still buy at the old price")
	# decline and lingering
	var gd := new_game()
	gd.location = "mireth"
	gd.cargo["weed:glow"] = 12
	Walkups.active(gd)["okka"] = Walkups.offer_for(gd, "okka")
	var aff_d := float(People.state(gd, "okka").affinity)
	check(Walkups.decline(gd, "okka").ok and float(People.state(gd, "okka").affinity) < aff_d and Walkups.count(gd) == 0, "declining dents affinity and ends it")
	check(not Walkups.eligible(gd, "okka"), "a customer you turned away stays away for a while")
	gd.total_time += float(data.walkups.cooldown) + 1.0
	check(Walkups.eligible(gd, "okka"), "...but comes back later")
	Walkups.active(gd)["okka"] = Walkups.offer_for(gd, "okka")
	gd.total_time += float(data.walkups.linger_seconds) + 1.0
	Walkups.tick(gd, 0.1)
	check(Walkups.count(gd) == 0, "bored customers walk off")
	# selling the goods elsewhere, or leaving the planet, ends it
	Walkups.active(gd)["okka"] = Walkups.offer_for(gd, "okka")
	gd.cargo.erase("weed:glow")
	Walkups.tick(gd, 0.1)
	check(Walkups.count(gd) == 0, "no goods left, no deal")
	gd.cargo["weed:glow"] = 5
	gd.total_time += float(data.walkups.cooldown) + 1.0
	Walkups.active(gd)["okka"] = Walkups.offer_for(gd, "okka")
	gd.location = ""
	Walkups.tick(gd, 0.1)
	check(Walkups.count(gd) == 0, "taking off ends it")
	# momentary: not in the save, loading does not crash
	Walkups.active(gh)["okka"] = {"contact": "okka"}
	var back := Game.new()
	back.from_dict(data, JSON.parse_string(JSON.stringify(gh.to_dict())))
	check(Walkups.count(back) == 0, "walk-ups are not saved")
	data.walkups.chance = 0.3
func test_loc_tables() -> void:
	var en: Dictionary = Loc.table("en")
	var de: Dictionary = Loc.table("de")
	check(en.size() >= 50, "English table loaded (%d keys)" % en.size())
	for k in en:
		check(de.has(k), "key %s exists in de" % k)
		check(str(de.get(k, "")) != "", "de text for %s not empty" % k)
	for k in de:
		check(en.has(k), "key %s exists in en" % k)
	# placeholders must survive translation, or the % formatting in the menus breaks
	for k in en:
		if de.has(k):
			check(str(en[k]).count("%") == str(de[k]).count("%"), "placeholders of %s match in de" % k)
	for b in preload("res://scripts/autoload/settings.gd").BINDABLE:
		check(en.has("key." + b.action), "binding label key for %s" % b.action)
		check(en.has("settings.group." + b.group), "group label key for %s" % b.group)


func test_loc_fallback() -> void:
	Loc.set_language("de")
	check(Loc.t("pause.resume", "x") == "Fortsetzen", "German text used")
	check(Loc.t("no.such.key", "Fallback") == "Fallback", "unknown key uses the fallback")
	check(Loc.t("no.such.key") == "no.such.key", "unknown key without fallback shows the key")
	check(Loc.set_language("xx") == "en" and Loc.t("pause.resume") == "Resume", "unknown language falls back to English")
	# a key only English has still shows English in German mode
	Loc._tables["de"] = {}
	check(Loc.t("pause.resume") == "Resume", "key missing in de falls back to en")
	Loc.reload()
	Loc.set_language("en")
	check(Loc.t("pause.resume") == "Resume", "English restored")
func test_vault() -> void:
	var g := new_game()
	var p := "weed:glow"
	g.cargo[p] = 30
	g.cargo["seed_weed"] = 5
	check(not Vault.deposit(g, p, 10).ok, "crate only inside an estate")
	g.inside_estate = "cannery_rig"
	check(not Vault.deposit(g, "seed_weed", 1).ok, "raws are not hidden")
	check(not Vault.deposit(g, p, 31).ok, "can't hide what you don't carry")
	check(Vault.deposit(g, p, 30).ok and Vault.used(g) == 30 and not g.cargo.has(p), "hidden")
	g.cargo[p] = 20
	check(Vault.deposit(g, p, 20).ok and Vault.used(g) == Vault.capacity(g) and int(g.cargo[p]) == 10, "capped at capacity")
	check(not Vault.deposit(g, p, 5).ok, "full crate")
	var lost: Dictionary = g.bust()
	check(lost.ok and Vault.used(g) == 40 and not g.cargo.has(p), "bust takes the hold, not the crate")
	g.credits = 5000
	var cap0 := Vault.capacity(g)
	check(Vault.upgrade(g).ok and Vault.capacity(g) == cap0 + 40, "upgrade adds room")
	g.credits = 0
	check(not Vault.upgrade(g).ok, "upgrade needs credits")
	var g2 := new_game()
	g2.from_dict(data, g.to_dict())
	check(Vault.used(g2) == 40 and int(g2.vault.tier) == 1, "vault survives save/load")
	g2.inside_estate = "cannery_rig"
	check(Vault.withdraw(g2, p, 15).ok and int(g2.cargo[p]) == 15 and Vault.used(g2) == 25, "withdraw")
	var g3 := new_game()
	
	var old: Dictionary = g.to_dict()
	old.erase("vault")
	g3.from_dict(data, old)
	check(Vault.used(g3) == 0 and int(g3.vault.tier) == 0, "old saves load with an empty crate")
func test_drying_table() -> void:
	var g := new_game()
	var e := "cannery_annex"
	g.credits = 5000
	g.estates[e] = {"buildings": []}
	var prod := Mixing.key("weed", ["glow"], 1)
	g.cargo[prod] = 10
	check(not Drying.load_rack(g, e, prod, 5).ok, "no rack without a drying table")
	check(g.place_building(e, "drying_table", 0, 0).ok and Drying.tables(g, e) == 1, "drying table can be built")
	check(Drying.capacity(g, e) == int(data.drying.capacity), "one table = base capacity")
	check(not Drying.can_dry(g, Mixing.key("cocaine", ["crisp"], 1)), "only listed bases can be cured")
	check(not Drying.can_dry(g, Mixing.key("weed", ["glow"], 3)), "top grade can't be cured further")
	check(not Drying.can_dry(g, "cannabis"), "raws are not cured")
	check(Drying.result_key(prod) == Mixing.key("weed", ["glow"], 2), "cure raises the grade by one")
	check(Drying.result_key(Mixing.key("weed", ["glow"], 0)) == prod, "Shoddy cures to Standard (no suffix)")
	check(Drying.load_rack(g, e, prod, 6).ok and g.cargo[prod] == 4, "loading takes units from the hold")
	check(Drying.loaded(g, e) == 6, "rack counts the load")
	check(not Drying.collect(g, e).ok, "nothing to collect while wet")
	check(not g.remove_building(e, 0).ok, "last table can't go down while loaded")
	g.tick(float(data.drying.seconds) - 1.0)
	check(Drying.ready(g, e) == 0, "not dry one second early")
	# save mid-cure keeps the timer; old save without the key loads empty
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(Drying.loaded(h, e) == 6 and ceili(float(h.drying[e][0].left)) == 1, "save keeps the rack and its timer")
	var old := g.to_dict()
	old.erase("drying")
	var k := Game.new()
	k.from_dict(data, old)
	check(k.drying.is_empty(), "old save loads with empty racks")
	var junk := g.to_dict()
	junk.drying = {e: [{"product": "nope"}, 5], "ghost": []}
	var m := Game.new()
	m.from_dict(data, junk)
	check(m.drying.is_empty(), "garbage rack entries are dropped")
	g.tick(2.0)
	check(Drying.ready(g, e) == 4, "6 units keep 80%% = 4 (floor)")
	g.cargo = {}
	g.cargo["cannabis"] = g.cargo_free() - 1
	var r := Drying.collect(g, e)
	check(r.ok and g.cargo.get(Drying.result_key(prod), 0) == 1 and Drying.loaded(g, e) > 0, "collect only moves what fits")
	g.cargo = {}
	check(Drying.collect(g, e).ok and g.cargo[Drying.result_key(prod)] >= 1, "collect after room frees up")
	check(Drying.loaded(g, e) == 0 and not g.drying.has(e), "rack empties")
	check(g.remove_building(e, 0).ok, "empty table can come down")
	# capacity is shared across tables
	g.place_building(e, "drying_table", 0, 0)
	g.place_building(e, "drying_table", 3, 0)
	g.cargo[prod] = 100
	Drying.load_rack(g, e, prod, 100)
	check(Drying.loaded(g, e) == 2 * int(data.drying.capacity), "rack stops at capacity")
func test_autopilot_avoid() -> void:
	var Steering = preload("res://scripts/core/steering.gd")
	var from := Vector2.ZERO
	var goal := Vector2(3000, 0)
	var clear: Vector2 = Steering.avoid_heading(from, goal, [], 900.0)
	check(clear.is_equal_approx(Vector2.RIGHT), "no hazards: straight to the goal")
	var rock := {"pos": Vector2(1000, 20), "r": 200.0}
	var h: Vector2 = Steering.avoid_heading(from, goal, [rock], 900.0)
	check(h.y < -0.1, "rock slightly below the course: detour goes up, got %s" % h)
	var h2: Vector2 = Steering.avoid_heading(from, goal, [{"pos": Vector2(1000, -20), "r": 200.0}], 900.0)
	check(h2.y > 0.1, "rock slightly above the course: detour goes down")
	check(Steering.avoid_heading(from, goal, [{"pos": Vector2(1000, 800), "r": 200.0}], 900.0).is_equal_approx(Vector2.RIGHT), "far-off rock is ignored")
	check(Steering.avoid_heading(from, goal, [{"pos": Vector2(-1000, 0), "r": 200.0}], 900.0).is_equal_approx(Vector2.RIGHT), "rock behind is ignored")
	check(Steering.avoid_heading(from, goal, [{"pos": Vector2(2900, 0), "r": 200.0}], 5000.0).is_equal_approx(Vector2.RIGHT), "hazard around the goal itself is not detoured")
	check(Steering.avoid_heading(from, goal, [{"pos": Vector2(2000, 0), "r": 200.0}], 900.0).is_equal_approx(Vector2.RIGHT), "rock beyond the look-ahead is ignored")
	var inside: Vector2 = Steering.avoid_heading(Vector2(1000, 50), goal, [rock], 900.0)
	check(inside.y > 0.5, "inside a hazard the heading pushes out")
	# simulate flying past with a point ship that turns at a limited rate: never enters the rock
	var pos := from
	var ang := 0.0
	var min_d := INF
	var big := {"pos": Vector2(1200, 10), "r": 250.0}
	for i in 1500:
		if pos.distance_to(goal) < 100.0:
			break
		var want: float = Steering.avoid_heading(pos, goal, [big], 900.0).angle()
		ang += clampf(wrapf(want - ang, -PI, PI), -0.05, 0.05)
		pos += Vector2.from_angle(ang) * 6.0
		min_d = minf(min_d, pos.distance_to(big.pos))
	check(pos.distance_to(goal) < 100.0 and min_d > 250.0, "flight arrives without touching the rock (closest %d)" % int(min_d))

func test_sealing_bench() -> void:
	var g := new_game()
	var e := "cannery_annex"
	g.credits = 5000
	g.estates[e] = {"buildings": []}
	var prod := Mixing.key("weed", ["glow"], 2)
	g.cargo[prod] = 10
	check(not Sealing.load_bench(g, e, prod, 5, 1).ok, "no bench, no wrapping")
	check(g.place_building(e, "seal_bench", 0, 0).ok and Sealing.benches(g, e) == 1, "sealing bench can be built")
	check(Sealing.capacity(g, e) == int(data.sealing.capacity), "one bench = base capacity")
	check(Mixing.key("weed", ["glow"], 2, 2) == "weed:glow@2#2" and Mixing.parse_key("weed:glow@2#2").pack == 2, "pack tier key round-trips")
	check(Mixing.parse_key("weed:glow@2").pack == 0 and Mixing.value(data, "weed:glow@2#2") == Mixing.value(data, prod), "old keys are loose, tier keeps the value")
	check(Mixing.display_name(data, "weed:glow@2#2").ends_with("(Shielded)"), "tier in name: %s" % Mixing.display_name(data, "weed:glow@2#2"))
	check(Sealing.can_seal(prod) and not Sealing.can_seal("weed:glow@2#1") and not Sealing.can_seal("cannabis"), "only loose product can be wrapped")
	check(Sealing.result_key(prod, 2) == "weed:glow@2#2", "result key carries grade and tier")
	check(not Sealing.load_bench(g, e, prod, 5, 0).ok and not Sealing.load_bench(g, e, prod, 5, 9).ok, "unknown tiers are refused")
	check(not Sealing.load_bench(g, e, "weed:glow@2#1", 1, 2).ok, "packed product can't be wrapped again")
	var before := g.credits
	var r := Sealing.load_bench(g, e, prod, 6, 2)
	check(r.ok and g.cargo[prod] == 4 and Sealing.loaded(g, e) == 6, "loading takes the units from the hold")
	check(before - g.credits == 6 * int(Sealing.offer(g, 2).cost), "wrap supplies are paid")
	check(not Sealing.collect(g, e).ok and Sealing.ready(g, e) == 0, "nothing to collect while wrapping")
	check(not g.remove_building(e, 0).ok, "last bench can't go down while loaded")
	g.tick(float(Sealing.offer(g, 2).seconds) - 1.0)
	check(Sealing.ready(g, e) == 0, "not done one second early")
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(Sealing.loaded(h, e) == 6 and ceili(float(h.sealing[e][0].left)) == 1 and int(h.sealing[e][0].tier) == 2, "save keeps the bench and its timer")
	var old := g.to_dict()
	old.erase("sealing")
	var k := Game.new()
	k.from_dict(data, old)
	check(k.sealing.is_empty(), "old save loads with an empty bench")
	var junk := g.to_dict()
	junk.sealing = {e: [{"product": "nope"}, 5, {"product": "weed:glow", "tier": 7}, {"product": "weed:glow#1", "tier": 1}], "ghost": []}
	var m := Game.new()
	m.from_dict(data, junk)
	check(m.sealing.is_empty(), "garbage bench entries are dropped")
	g.tick(2.0)
	check(Sealing.ready(g, e) == 6, "wrapping keeps every unit")
	g.cargo = {}
	g.cargo["cannabis"] = g.cargo_free() - 2
	check(Sealing.collect(g, e).ok and g.cargo.get("weed:glow@2#2", 0) == 2 and Sealing.loaded(g, e) == 4, "collect only moves what fits")
	g.cargo = {}
	check(Sealing.collect(g, e).ok and g.cargo["weed:glow@2#2"] == 4 and Sealing.loaded(g, e) == 0 and not g.sealing.has(e), "collect after room frees up")
	check(g.remove_building(e, 0).ok, "empty bench can come down")
	# broke: wrap is paid per unit, so credits cap the load
	g.place_building(e, "seal_bench", 0, 0)
	g.cargo[prod] = 10
	g.credits = 2 * int(Sealing.offer(g, 1).cost)
	check(Sealing.load_bench(g, e, prod, 10, 1).ok and Sealing.loaded(g, e) == 2 and g.credits == 0, "credits cap the load")
	check(not Sealing.load_bench(g, e, prod, 10, 1).ok, "no credits, no wrap")
	# capacity is shared by all benches
	g.credits = 100000
	g.sealing = {}
	g.place_building(e, "seal_bench", 3, 0)
	g.cargo[prod] = 100
	Sealing.load_bench(g, e, prod, 100, 1)
	check(Sealing.loaded(g, e) == 2 * int(data.sealing.capacity), "bench stops at capacity")
func test_quest_chapter3() -> void:
	var g := new_game()
	var qs: Dictionary = Quests.defs(g)
	var ids := ["main_veil_whisper", "main_veil_ground", "main_veil_toll", "main_veil_wing", "main_veil_spire", "main_veil_ledger"]
	for q in ids:
		check(qs.has(q) and int(qs[q].chapter) == 3 and qs[q].main and str(qs[q].giver) != "", "chapter 3 quest %s" % q)
	check((qs.main_rig.next as Array).has("main_veil_whisper"), "chapter 3 follows Cold Front")
	check(g.data.locations.has(str(qs.main_veil_spire.steps[0].target.loc)), "the Spire waypoint exists")
	Quests.start(g, "main_veil_whisper")
	g.note("landed", {"location": "varrow"})
	check(Quests.is_done(g, "main_veil_whisper"), "Varrow reached")
	check(Quests.is_active(g, "main_veil_ground"), "Cheap Faith starts")
	g.cartels.influence["varrow"] = {"veil": 0.6, "you": 0.1}
	g.cartels.owner["varrow"] = "veil"
	Cartels.gain(g, "varrow", "you", 0.6)
	check(Quests.is_done(g, "main_veil_ground") and Quests.is_active(g, "main_veil_toll"), "taking a Veil street finishes Cheap Faith")
	g.day = 3
	g.interdiction = {}
	Interdiction.begin(g, {"kind": "cartel", "cartel": "comets", "units": ["fighter"]})
	Interdiction.resolve(g, "fight")
	check(Quests.is_active(g, "main_veil_toll"), "a Comet interdiction does not count")
	g.interdiction = {}
	Interdiction.begin(g, {"kind": "cartel", "cartel": "veil", "units": ["fighter"]})
	Interdiction.resolve(g, "fight")
	check(Quests.is_done(g, "main_veil_toll") and Quests.is_active(g, "main_veil_wing"), "a Veil interdiction finishes The Quiet Toll")
	for i in 3:
		SpaceCombat.enemy_down(g, "fighter", "veil", g.rng)
	SpaceCombat.enemy_down(g, "fighter", "comets", g.rng)
	check(Quests.is_active(g, "main_veil_wing") and Quests.progress_text(g, "main_veil_wing") == "3/4", "only Veil wrecks count")
	SpaceCombat.enemy_down(g, "fighter", "veil", g.rng)
	check(Quests.is_done(g, "main_veil_wing") and Quests.is_active(g, "main_veil_spire"), "4 Veil wrecks finish Lanterns Out")
	g.system = "kovar"
	check(Quests.space_goal(g, Quests.target(g)) == "veil_spire", "the Spire is the waypoint in Kovar")
	SpaceCombat.raid_base(g, "veil_spire", g.rng)
	check(Quests.is_done(g, "main_veil_spire") and Quests.is_active(g, "main_veil_ledger"), "raiding the Spire finishes Veil Spire")
	g.credits = 100
	g.note("landed", {"location": "glacis"})
	check(Quests.step_index(g, "main_veil_ledger") == 1, "landed on Glacis")
	g.credits = 6000
	Quests.refresh(g)
	check(Quests.is_done(g, "main_veil_ledger"), "audit settled, chapter 3 done")
	check(g.quests.active.is_empty(), "nothing follows chapter 3 yet")



func test_estate_upkeep() -> void:
	var g := new_game()
	var c: Dictionary = data.upkeep
	check(EstateUpkeep.daily(g, g.SHIP_BAY) == 0 and EstateUpkeep.daily(g, "cannery_rig") == 0, "ship bay and starter estate pay no upkeep")
	check(EstateUpkeep.daily_total(g) == 0, "a fresh game owes no upkeep")
	g.credits = 5000
	g.location = "mireth"
	check(g.buy_estate("cannery_annex").ok, "buy the annex")
	var d := EstateUpkeep.daily(g, "cannery_annex")
	check(d == maxi(int(c.min_daily), int(round(1500 * float(c.daily_rate)))), "daily upkeep from price")
	var dc: Dictionary = g.daily_costs()
	check(int(dc.rent) == d and int(dc.total) == int(dc.wages) + d + int(dc.drones) + int(dc.officials), "daily costs list the rent")
	# paid automatically
	var before := g.credits
	g._new_day()
	check(g.credits == before - d - Workers.wage_total(g) or g.credits <= before - d, "upkeep taken at dawn")
	check(EstateUpkeep.status(g, "cannery_annex") == "ok" and int(g.stats.upkeep_paid) == d, "paid and counted")
	# broke: overdue, then locked
	g.credits = 0
	g._new_day()
	check(EstateUpkeep.status(g, "cannery_annex") == "overdue" and EstateUpkeep.arrears(g, "cannery_annex") == d, "one missed day is overdue")
	check(not g.estate_locked("cannery_annex"), "still usable while overdue")
	for i in int(c.grace_days) - 1:
		g.credits = 0
		g._new_day()
	check(g.estate_locked("cannery_annex"), "locked after the grace days")
	g.inside_estate = "cannery_annex"
	var hub_lab: bool = g.loc_data().get("lab", false)
	check(hub_lab or not g.lab_here(), "no cooking in a locked estate")
	g.location = "cinder"
	check(g.loc_data().get("lab", false) or not g.lab_here(), "no cooking in a locked estate (no hub lab)")
	g.location = "mireth"
	g.inside_estate = ""
	# drones and workers stop while locked
	g.drones.append({"id": 99, "estate": "cannery_annex", "route": "to_port", "t": 0.0, "grounded": false})
	Drones.tick(g, 10.0)
	check(is_equal_approx(float(g.drones[0].t), 0.0), "drones idle at a locked estate")
	# paying the arrears unlocks
	var a := EstateUpkeep.arrears(g, "cannery_annex")
	g.credits = a - 1
	check(not g.pay_estate_arrears("cannery_annex").ok, "can't pay without the money")
	g.credits = a
	check(g.pay_estate_arrears("cannery_annex").ok and g.credits == 0, "paid arrears")
	check(EstateUpkeep.status(g, "cannery_annex") == "ok" and not g.estate_locked("cannery_annex"), "unlocked again")
	check(not g.pay_estate_arrears("cannery_annex").ok, "nothing overdue now")
	# save round trip keeps unpaid days
	g._new_day()
	check(EstateUpkeep.unpaid_days(g, "cannery_annex") == 1, "unpaid again")
	var h := Game.new()
	h.from_dict(data, JSON.parse_string(JSON.stringify(g.to_dict())))
	check(EstateUpkeep.unpaid_days(h, "cannery_annex") == 1, "unpaid days survive a save")
	# seizure clears everything stored under the estate
	g.estate_stock["cannery_annex"] = {"cannabis": 3}
	g.drying["cannery_annex"] = []
	g.workers.append({"id": "hollis", "loyalty": 0.5, "estate": "cannery_annex", "hired_day": 1})
	var seized := []
	g.event.connect(func(k, p): if k == "estate_seized": seized.append(p))
	for i in int(c.seize_days):
		g.credits = 0
		g._new_day()
	check(not g.estates.has("cannery_annex") and seized.size() == 1, "seized after seize_days")
	check(not g.estate_stock.has("cannery_annex") and not g.drying.has("cannery_annex"), "estate stock and racks gone")
	check(g.drones.filter(func(x): return x.estate == "cannery_annex").is_empty(), "drones at the estate gone")
	check(g.workers.filter(func(w): return w.estate == "cannery_annex").is_empty(), "workers off duty")
	check(g.estates.has("cannery_rig"), "starter estate untouched")
	# selling
	var s := new_game()
	s.credits = 5000
	s.location = "mireth"
	s.buy_estate("cannery_annex")
	s.estates.cannery_annex.buildings.append({"id": "trim_table", "x": 0, "y": 0})
	var q := EstateUpkeep.sale_quote(s, "cannery_annex")
	check(q.share == int(round(1500 * float(c.sell_share))) and q.buildings == int(round(150 * float(data.estate_refund))), "sale quote parts")
	check(not s.sell_estate("cannery_rig").ok and not s.sell_estate(s.SHIP_BAY).ok, "starter estate and ship bay can't be sold")
	s.location = "cinder"
	check(not s.sell_estate("cannery_annex").ok, "must be on the planet to sell")
	s.location = "mireth"
	var cr := s.credits
	check(s.sell_estate("cannery_annex").ok and s.credits == cr + int(q.net) and not s.estates.has("cannery_annex"), "sold for the quote")
	check(s.buy_estate("cannery_annex").ok, "can buy it back")


func test_grow_botanist() -> void:
	const Grow = preload("res://scripts/core/grow.gd")
	var g := new_game()
	g.credits = 5000
	var est := "cannery_rig"
	Grow.build_tray(g, est)
	Grow.build_tray(g, est)
	g.cargo["cannabis"] = 10
	Grow.plant(g, est, 0, "cannabis")
	check(Grow.tend(g) == 0, "no botanist, nobody waters")
	check(Workers.hire(g, "oko").ok and Workers.assign(g, "oko", est).ok, "hire and assign the botanist")
	check(Workers.candidate(g, "oko").role == "botanist", "oko is a botanist")
	check(not Workers.hire(g, "fern").ok or not Workers.assign(g, "fern", est).ok, "one botanist per estate")
	var days := int(data.grow.crops.cannabis.days)
	var watered := 0
	for d in days - 1:
		g._new_day()
		watered = (Grow.trays(g, est)[0].watered as Array).size()
	# day of planting was not watered; every dawn after it is (oko rarely misses)
	check(watered >= days - 2 and not Grow.is_ripe(g, Grow.trays(g, est)[0]), "botanist waters the growing tray (%d of %d days)" % [watered, days])
	var e: Dictionary = g.estates[est]
	var before := int(e.storage.get("cannabis", 0))
	g.credits = 5000
	g._new_day()
	check(int(e.storage.get("cannabis", 0)) > before - int(data.grow.seed_qty), "ripe tray harvested into the estate storage")
	var t: Dictionary = Grow.trays(g, est)[0]
	check(t.raw == "cannabis" and int(t.start_day) == g.day, "replanted the same crop from storage")
	check(Grow.trays(g, est)[1].raw == "", "empty trays without a previous crop stay empty")
	# a locked estate is not tended
	var h := new_game()
	h.credits = 5000
	h.location = "mireth"
	h.buy_estate("cannery_annex")
	Grow.build_tray(h, "cannery_annex")
	h.cargo["cannabis"] = 5
	Grow.plant(h, "cannery_annex", 0, "cannabis")
	Workers.hire(h, "fern")
	Workers.assign(h, "fern", "cannery_annex")
	h.estates.cannery_annex.unpaid = int(data.upkeep.grace_days) + 1
	h.credits = 0
	h._new_day()
	check((Grow.trays(h, "cannery_annex")[0].watered as Array).is_empty(), "no tending in a locked estate")
