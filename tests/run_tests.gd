extends SceneTree
## Headless unit tests for the core simulation. Run: godot --headless --path . -s res://tests/run_tests.gd
## Exit code 1 on any failure.

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")
const Mixing = preload("res://scripts/core/mixing.gd")
const Schedule = preload("res://scripts/core/schedule.gd")

var data: Dictionary
var failures := 0
var checks := 0


func _init() -> void:
	data = Data.load_all()
	for t in [
		"test_data_references",
		"test_surface_layouts",
		"test_schedule_rules",
		"test_surface_schedules",
		"test_mixing_rules",
		"test_buy_and_cargo_limit",
		"test_lab_batch",
		"test_sell_contact_and_fence",
		"test_market_saturation_recovers",
		"test_heat_and_patrols",
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


func test_surface_layouts() -> void:
	check(data.surfaces.has(data.start.location), "start location has a walkable surface")
	var actions := ["market", "lab", "shipyard", "office", "deal", "takeoff"]
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
		check(s.has("pad"), "%s has a launch pad" % loc)
		for c in data.contacts:
			if c.location == loc:
				check(s.npcs.any(func(n): return n.get("contact", "") == c.id), "%s contact %s stands on the surface" % [loc, c.id])


func test_schedule_rules() -> void:
	check(is_equal_approx(Schedule.hour_of(0.0, 180.0), 6.0), "day starts at 06:00")
	check(is_equal_approx(Schedule.hour_of(90.0, 180.0), 18.0), "half a day later is 18:00")
	check(Schedule.hour_of(179.9, 180.0) < 6.0 and Schedule.hour_of(179.9, 180.0) > 5.9, "end of the day wraps to just before 06:00")
	check(Schedule.hour_of(135.0, 180.0) < 1.0, "three quarters of the day is around midnight (wrapped)")
	check(Schedule.clock_text(7.5) == "07:30" and Schedule.clock_text(0.0) == "00:00", "clock text")
	var sched := [{"from": 6, "at": "home"}, {"from": 8, "at": "work"}, {"from": 17, "at": "plaza"}, {"from": 21, "at": "home"}]
	check(Schedule.place_at(sched, 6.0) == "home" and Schedule.place_at(sched, 7.99) == "home", "morning at home")
	check(Schedule.place_at(sched, 8.0) == "work" and Schedule.place_at(sched, 16.9) == "work", "daytime at work")
	check(Schedule.place_at(sched, 17.0) == "plaza", "evening at the plaza")
	check(Schedule.place_at(sched, 23.0) == "home" and Schedule.place_at(sched, 2.0) == "home", "night at home, wrapping past midnight")
	check(Schedule.place_at([], 5.0) == "", "empty schedule has no place")
	var places := {"home": 1, "work": 1, "plaza": 1}
	check(Schedule.validate_schedule(sched, places) == "", "good schedule validates")
	check(Schedule.validate_schedule([{"from": 8, "at": "home"}, {"from": 6, "at": "work"}], places) != "", "unsorted schedule rejected")
	check(Schedule.validate_schedule([{"from": 8, "at": "moon"}], places) != "", "unknown place rejected")
	check(Schedule.validate_schedule([{"from": 25, "at": "home"}], places) != "", "hour out of range rejected")
	var keys := [[0, "#000000"], [12, "#ffffff"]]
	check(Schedule.tint_at(keys, 12.0).is_equal_approx(Color.WHITE), "tint hits its key")
	check(is_equal_approx(Schedule.brightness(Schedule.tint_at(keys, 6.0)), 0.5), "tint interpolates between keys")
	check(is_equal_approx(Schedule.brightness(Schedule.tint_at(keys, 18.0)), 0.5), "tint wraps back to the first key after the last")
	check(Schedule.tint_at([], 3.0) == Color.WHITE, "no keys = no tint")
	# chatter
	check(Schedule.pick_line(0, 5, -1) == -1 and Schedule.pick_line(1, 5, 0) == 0, "pick_line edge cases")
	var repeats := false
	for roll in 200:
		for last in 3:
			var i := Schedule.pick_line(3, roll, last)
			if i == last or i < 0 or i > 2:
				repeats = true
	check(not repeats, "pick_line never repeats the last line and stays in range")
	var pool := Schedule.chatter_pool({"home": ["a"], "any": ["b"]}, "home")
	check(pool == ["a", "b"] and Schedule.chatter_pool({"any": ["b"]}, "work") == ["b"], "chatter pool = place lines + any lines")
	# path finding on a tiny map: a wall with one gap
	var cfg := {"size": [8, 5], "buildings": [{"rect": [3, 0, 1, 4]}]}
	var nav := Schedule.make_nav(cfg)
	var path := Schedule.find_path(nav, Vector2(1.5, 1.5), Vector2(6.5, 1.5))
	check(not path.is_empty() and path[path.size() - 1] == Vector2(6.5, 1.5), "path ends exactly on the target")
	var through_wall := path.any(func(p): return Rect2(3, 0, 1, 4).has_point(p))
	check(not through_wall, "path goes around the wall through the gap")
	check(path.any(func(p): return p.y > 4.0), "path actually uses the gap in row 4")
	check(Schedule.find_path(nav, Vector2(1.5, 1.5), Vector2(3.5, 1.5)).is_empty(), "blocked target gives no path")
	check(Schedule.find_path(nav, Vector2(1.5, 1.5), Vector2(1.5, 1.5)).size() == 1, "already there = just the target")


func test_surface_schedules() -> void:
	check(float(data.time.get("day_start_hour", -1)) >= 0.0, "content defines the day start hour")
	for loc in data.surfaces:
		var s: Dictionary = data.surfaces[loc]
		var nav := Schedule.make_nav(s)
		check(s.has("tint") and not s.tint.is_empty(), "%s has day/night tint keys" % loc)
		var last_h := -1.0
		for k in s.get("tint", []):
			check(float(k[0]) > last_h and float(k[0]) < 24.0 and Color(k[1]) != Color(), "%s tint key %s valid" % [loc, k])
			last_h = float(k[0])
		var dark := 1.0
		var bright := 0.0
		for h in 48:
			var b := Schedule.brightness(Schedule.tint_at(s.tint, h / 2.0))
			dark = minf(dark, b)
			bright = maxf(bright, b)
		check(bright > 0.95 and dark < 0.6 and dark > 0.2, "%s: day is bright (%.2f), night is dark but readable (%.2f)" % [loc, bright, dark])
		check(s.get("walker_chatter", []).size() > 0 or int(s.get("walkers", 0)) == 0, "%s walkers have chatter" % loc)
		for n in s.npcs:
			if not n.has("schedule"):
				continue
			check(Schedule.validate_schedule(n.schedule, n.places) == "", "%s/%s schedule valid: %s" % [loc, n.id, Schedule.validate_schedule(n.schedule, n.places)])
			var seen: Dictionary = {}
			for h in 96:
				seen[Schedule.place_at(n.schedule, h / 4.0)] = true
			check(seen.size() >= 3 and seen.has("home") and seen.has("work"), "%s/%s visits home, work and one more place over a day" % [loc, n.id])
			for place in n.places:
				var p := Vector2(n.places[place][0], n.places[place][1])
				check(not nav.is_point_solid(Vector2i(int(floor(p.x)), int(floor(p.y)))), "%s/%s %s spot is free ground" % [loc, n.id, place])
				for other in n.places:
					var path := Schedule.find_path(nav, p, Vector2(n.places[other][0], n.places[other][1]))
					check(not path.is_empty(), "%s/%s can walk %s -> %s" % [loc, n.id, place, other])
			for place in seen:
				check(Schedule.chatter_pool(n.get("chatter", {}), place).size() >= 2, "%s/%s has chatter at %s" % [loc, n.id, place])
				for line in Schedule.chatter_pool(n.get("chatter", {}), place):
					check(String(line).length() <= 34, "%s/%s chatter line fits a bubble: %s" % [loc, n.id, line])


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
