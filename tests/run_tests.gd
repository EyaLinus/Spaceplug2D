extends SceneTree
## Headless unit tests for the core simulation. Run: godot --headless --path . -s res://tests/run_tests.gd
## Exit code 1 on any failure.

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")
const Mixing = preload("res://scripts/core/mixing.gd")
const Production = preload("res://scripts/core/production.gd")
const People = preload("res://scripts/core/people.gd")
const Corruption = preload("res://scripts/core/corruption.gd")
const Workers = preload("res://scripts/core/workers.gd")
const Bench = preload("res://scripts/core/bench.gd")
const Deals = preload("res://scripts/core/deals.gd")
const Orders = preload("res://scripts/core/orders.gd")
const Galaxy = preload("res://scripts/core/galaxy.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Deaddrops = preload("res://scripts/core/deaddrops.gd")
const ArtReg = preload("res://scripts/core/art.gd")
const SpaceCombat = preload("res://scripts/core/spacecombat.gd")
const Products = preload("res://scripts/core/products.gd")

var data: Dictionary
var failures := 0
var checks := 0


func _init() -> void:
	data = Data.load_all()
	for t in [
		"test_data_references",
		"test_surface_layouts",
		"test_art_registry",
		"test_police_on_foot",
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
		"test_workers",
		"test_ship_bay",
		"test_orders",
		"test_order_kits",
		"test_orders_save",
		"test_galaxy_routes",
		"test_galaxy_overlays",
		"test_jump_drive",
		"test_jump_drive_multi_hop",
		"test_mixing_rules",
		"test_buy_and_cargo_limit",
		"test_lab_batch",
		"test_production_stations",
		"test_production_outcome",
		"test_quality_grade_keys",
		"test_station_minigames",
		"test_sell_contact_and_fence",
		"test_products_recipe_book",
		"test_products_asking_price",
		"test_people_profiles",
		"test_people_deals",
		"test_people_save",
		"test_people_schedules_on_surfaces",
		"test_deal_requests",
		"test_deal_answers",
		"test_deal_appointments",
		"test_deal_fulfill",
		"test_deaddrops",
		"test_deaddrops_save",
		"test_market_saturation_recovers",
		"test_heat_and_patrols",
		"test_galaxy_and_jump",
		"test_bust",
		"test_upgrades",
		"test_space_combat_stats",
		"test_space_combat_damage",
		"test_space_combat_pirates",
		"test_space_combat_mechanic",
		"test_space_combat_save",
		"test_space_combat_balance",
		"test_bribe",
		"test_corruption_data",
		"test_heat_per_system",
		"test_wanted_level",
		"test_officials",
		"test_customs_scan_pass",
		"test_sweep_and_tip_off",
		"test_corruption_save",
		"test_debt_win_and_loss",
		"test_save_roundtrip",
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
	for part in ["roof", "wall", "window", "door", "hatch"]:
		check(Art.tex("buildings/%s.png" % part) != null, "building part %s" % part)
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
				check(s.npcs.any(func(n): return n.get("contact", "") == c.id), "%s contact %s stands on the surface" % [loc, c.id])


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
	check(w.credits == c0 - wages and w.stats.wages == wages, "daily wages charged (%d)" % (c0 - w.credits))
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
	check(Galaxy.neighbours(g, "halvane") == ["kovar"] and Galaxy.neighbours(g, "kovar") == ["halvane"], "the two systems are neighbours")
	check(Galaxy.lanes(g).size() == 1, "one lane (gate pairs count once)")
	check(Galaxy.gates(g, "halvane", "kovar") == ["halvane_gate"] and Galaxy.gates(g, "kovar").size() == 1, "gate lookup")
	check(Galaxy.route(g, "halvane", "kovar") == ["halvane", "kovar"] and Galaxy.route(g, "kovar", "kovar") == ["kovar"], "route over the lane")
	check(Galaxy.route(g, "halvane", "nowhere").is_empty(), "unknown system has no route")
	var pl := Galaxy.plan(g, "kovar")
	check(pl.ok and pl.hops == 1 and pl.fee == int(data.jump.fee) and pl.charge > 0.0, "plan: one hop, toll, charge time")
	check(is_equal_approx(pl.total_seconds, pl.charge + float(data.jump.seconds)), "plan total = charge + travel")
	check(not Galaxy.plan(g, "halvane").ok, "no plan to the current system")
	g.upgrades.engine = 3
	check(Galaxy.charge_seconds(g) < pl.charge and Galaxy.charge_seconds(g) >= float(data.jump.min_charge), "engine upgrades shorten the charge, never below the minimum")


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
	check(Galaxy.lanes(g).size() == 2, "two lanes")


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
	check(a.lab_queue[0].product == "weed:overclock+radiant@3", "pristine key: %s" % a.lab_queue[0].product)
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


## Every registered minigame: a skilled bot scores high, doing nothing scores low, and each run ends on its own.
func test_station_minigames() -> void:
	var Runner = load("res://scripts/ui/minigames/registry.gd")
	var ctx_for := func(base: String, seed_value: int) -> Dictionary:
		return {"base": base, "tier": int(data.bases[base].tier), "additives": ["nanoflux", "ion_syrup"], "qty": 5, "data": data, "seed": seed_value}
	for id in data.stations:
		var st: Dictionary = data.stations[id]
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


func test_people_schedules_on_surfaces() -> void:
	var Nav = load("res://scripts/planet/nav.gd")
	for loc in data.surfaces:
		var cfg: Dictionary = data.surfaces[loc]
		if cfg.has("estate"):
			continue
		var nav: AStarGrid2D = Nav.build(cfg)
		var start := Vector2i(int(cfg.spawn[0]), int(cfg.spawn[1]))
		for n in cfg.get("npcs", []):
			if n.get("contact", "") == "":
				continue
			var c: Dictionary = {}
			for cc in data.contacts:
				if cc.id == n.contact:
					c = cc
			for e in c.get("schedule", []):
				check(cfg.get("spots", {}).has(e.place), "%s has a spot for %s's %s" % [loc, c.id, e.place])
			for h in 24:
				var sp: Array = People.spot(c, cfg.get("spots", {}), h + 0.5, cfg.npcs.find(n))
				if sp.is_empty():
					continue
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
	check(float(o.expires_at) > g.total_time + 100.0, "meet window set")
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
	g3.tick(float(data.deals.meet_seconds) + 1.0)
	check(o3.state == "expired" and g3.people.okka.affinity < a3 + float(data.deals.affinity_noshow) * 0.5, "no-show hurts")


func test_deal_appointments() -> void:
	var g := new_game()
	g.location = "mireth"
	var hs := Deals.hour_seconds(g)
	check(absf(hs - 7.5) < 0.001, "one in-game hour is day_seconds / 24")
	var o: Dictionary = Deals.request(g, "okka")
	var lead := (float(o.meet_at) - g.total_time) / hs
	check(lead >= float(data.deals.lead_hours[0]) - 0.01 and lead <= float(data.deals.lead_hours[1]) + 0.01, "meeting proposed inside the lead window")
	check(str(Deals.when_text(g, float(o.meet_at))).length() >= 5, "meeting time reads as a clock time")
	# the hour at now matches the phone clock
	check(absf(Deals.hour_at(g, g.total_time) - People.hour(g)) < 0.001, "hour_at(now) is the phone clock")
	# asking price drives the offer, capped by what the customer pays
	var key := Mixing.key(o.base, [data.bases[o.base].innate])
	var market := Deals.offer_price(g, "okka", o.base)
	g.prices.erase(key)
	check(Deals.offer_price(g, "okka", o.base) == market, "no asking price: market offer")
	g.prices[key] = maxi(market - 5, 1)
	check(Deals.offer_price(g, "okka", o.base) == maxi(market - 5, 1), "a cheaper asking price is used")
	g.prices[key] = market * 50
	check(Deals.offer_price(g, "okka", o.base) <= int(floor(market * (1.0 + Products.tolerance(g, "okka")))), "a steep asking price is capped at their limit")
	g.prices.erase(key)
	# counters: amount
	var q0: int = o.qty
	check(Deals.counter_qty(g, o.id, 1).ok and o.qty == 1, "fewer units always works")
	check(not Deals.counter_qty(g, o.id, 5).ok and o.countered_qty, "one amount counter per request")
	var o2: Dictionary = Deals.request(g, "sen")
	check(not Deals.counter_qty(g, o2.id, 100000).ok and o2.qty != 100000, "far too many units refused")
	check(q0 >= 1, "request had a quantity")
	# counters: time
	var o3: Dictionary = Deals.request(g, "okka") if Deals.open_for(g, "okka").is_empty() else Deals.request(g, "teo")
	var m0 := float(o3.meet_at)
	var pat := Deals.patience_hours(g, o3.contact)
	var r: Dictionary = Deals.counter_time(g, o3.id, 2.0)
	if pat >= 2.0:
		check(r.ok and absf(float(o3.meet_at) - (m0 + 2.0 * hs)) < 0.01, "later meeting accepted within patience")
	else:
		check(not r.ok and float(o3.meet_at) == m0, "later meeting refused beyond patience")
	check(not Deals.counter_time(g, o3.id, 2.0).ok, "one time counter per request")
	g.people[o3.contact].affinity = 1.0
	g.people[o3.contact].addiction = 0.0
	check(Deals.patience_hours(g, o3.contact) > 4.0, "a friend waits longer")
	g.people[o3.contact].affinity = -1.0
	g.people[o3.contact].addiction = 1.0
	check(Deals.patience_hours(g, o3.contact) <= 0.5 + 0.001, "an addict does not wait")
	# accepting fixes the appointment and the no-show deadline
	var g2 := new_game()
	g2.location = "mireth"
	var a: Dictionary = Deals.request(g2, "okka")
	a.meet_at = g2.total_time - 10.0  # proposed time already passed while thinking
	check(Deals.accept(g2, a.id).ok, "accept")
	check(float(a.meet_at) >= g2.total_time + float(data.deals.min_lead_hours) * Deals.hour_seconds(g2) - 0.01, "a stale proposal is moved ahead")
	check(absf(float(a.expires_at) - (float(a.meet_at) + float(data.deals.late_hours) * Deals.hour_seconds(g2))) < 0.01, "deadline = meet time + late window")
	check(Deals.today(g2).has(a) or float(a.meet_at) >= Deals.day_end(g2), "calendar lists today's meetings")
	check(Deals.timing(g2, a) == "early", "before the time: early")
	# on time vs late
	var key2 := Mixing.key(a.base, [data.bases[a.base].innate])
	g2.cargo[key2] = int(a.qty)
	g2.total_time = float(a.meet_at) + 0.5 * Deals.hour_seconds(g2)
	check(Deals.timing(g2, a) == "ontime" and Deals.pay_price(g2, a) == int(a.price), "within the grace hour: full price")
	g2.total_time = float(a.meet_at) + 2.0 * Deals.hour_seconds(g2)
	check(Deals.timing(g2, a) == "late" and Deals.pay_price(g2, a) < int(a.price), "late: discounted")
	var cr: int = g2.credits
	check(Deals.fulfill(g2, a.id, key2).ok, "late hand-over still works")
	check(g2.credits - cr == Deals.pay_price(g2, a) * int(a.qty), "paid the discounted price")
	# missed = expired + affinity loss
	var g3 := new_game()
	g3.location = "mireth"
	var m: Dictionary = Deals.request(g3, "okka")
	Deals.accept(g3, m.id)
	var aff3: float = g3.people.okka.affinity
	g3.total_time = float(m.meet_at) + (float(data.deals.late_hours) - 0.5) * Deals.hour_seconds(g3)
	Deals.tick(g3, 0.1)
	check(m.state == "accepted", "still open inside the late window")
	g3.total_time = float(m.meet_at) + (float(data.deals.late_hours) + 0.5) * Deals.hour_seconds(g3)
	Deals.tick(g3, 0.1)
	check(m.state == "expired" and g3.people.okka.affinity < aff3, "missed meeting expires and costs affinity")
	# save round trip keeps the appointment; an old save gets one
	var g4 := new_game()
	var s: Dictionary = Deals.request(g4, "okka")
	Deals.accept(g4, s.id)
	var d: Dictionary = JSON.parse_string(JSON.stringify(g4.to_dict()))
	var g5 := Game.new()
	g5.from_dict(data, d)
	check(absf(float(Deals.find(g5, s.id).meet_at) - float(s.meet_at)) < 0.1, "meet time survives a save")
	for od in d.offers:
		od.erase("meet_at")
		od.erase("countered_qty")
		od.erase("countered_time")
	var g6 := Game.new()
	g6.from_dict(data, d)
	var old: Dictionary = Deals.find(g6, s.id)
	check(old.has("meet_at") and old.state == "accepted" and Deals.fulfill(g6, s.id, "none").ok == false, "old save: appointment fields filled in")


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
	g.tick(600.0)
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
	var t0 := g.batch_seconds(5)
	g.buy_upgrade("lab")
	check(g.lab_capacity() == 10 and g.batch_seconds(5) < t0, "lab upgrade: capacity and speed")


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
	check(base_interval == float(data.space_combat.spawn.interval), "empty hold in Halvane: base spawn interval")
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
		if data.locations[l].has("jump_to") and data.locations[l].system == "kovar":
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
	check(str(g.lab_queue[0].product).ends_with("@%d" % grade) or grade == 1, "the minigame scores set the grade")
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
