extends SceneTree
## Headless unit tests for the core simulation. Run: godot --headless --path . -s res://tests/run_tests.gd
## Exit code 1 on any failure.

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")
const Mixing = preload("res://scripts/core/mixing.gd")
const Production = preload("res://scripts/core/production.gd")
const People = preload("res://scripts/core/people.gd")
const Orders = preload("res://scripts/core/orders.gd")
const ArtReg = preload("res://scripts/core/art.gd")

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
		"test_estates",
		"test_orders",
		"test_orders_save",
		"test_mixing_rules",
		"test_buy_and_cargo_limit",
		"test_lab_batch",
		"test_production_stations",
		"test_production_outcome",
		"test_quality_grade_keys",
		"test_station_minigames",
		"test_sell_contact_and_fence",
		"test_people_profiles",
		"test_people_deals",
		"test_people_save",
		"test_market_saturation_recovers",
		"test_heat_and_patrols",
		"test_galaxy_and_jump",
		"test_bust",
		"test_upgrades",
		"test_bribe",
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
		check(not ld.get("lab", false) or "lab" in reachable, "%s lab reachable" % loc)
		check(not ld.get("shipyard", false) or "shipyard" in reachable, "%s shipyard reachable" % loc)
		check(not ld.get("office", false) or "office" in reachable, "%s office reachable" % loc)
		check(not ld.get("fence", false) or "fence" in reachable, "%s fence reachable" % loc)
		check(ld.get("fence", false) or not "fence" in reachable, "%s has no fence door without a fence" % loc)
		check(s.has("pad"), "%s has a launch pad" % loc)
		check(s.has("security"), "%s sets its police security" % loc)
		for e in data.estates:
			if data.estates[e].location == loc:
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


func test_estates() -> void:
	for e in data.estates:
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


func test_orders() -> void:
	var rules: Dictionary = data.orders
	for k in ["markup", "fee_pct", "fee_min", "express_fee_mult", "seconds", "far_seconds", "max_qty", "max_open", "cancel_refund"]:
		check(rules.has(k), "orders rule %s exists" % k)
	check(float(rules.seconds.express) < float(rules.seconds.standard), "express is faster")
	var g := new_game()
	g.credits = 5000
	var cat: Array = Orders.catalog(g)
	check(cat.size() == data.raws.size() + data.additives.size(), "catalog lists every raw and additive")
	for e in cat:
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
	check(Orders.destinations(g).size() == 2, "stash plus the owned estate")
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


func test_orders_save() -> void:
	var g := new_game()
	g.credits = 5000
	Orders.place(g, "cannabis", 6, "stash", false)
	g.estates["cannery_annex"] = {"buildings": []}
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


func test_bribe() -> void:
	var g := new_game()
	g.add_heat(20)
	var cost := g.bribe_cost(20)
	check(g.bribe(20).ok and g.heat == 0.0 and g.credits == 400 - cost, "bribe clears heat")
	g.undock()
	g.add_heat(10)
	check(not g.bribe(10).ok, "bribe only at hub office")


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
