extends SceneTree
## Headless unit tests for the core simulation. Run: godot --headless --path . -s res://tests/run_tests.gd
## Exit code 1 on any failure.

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")
const Mixing = preload("res://scripts/core/mixing.gd")

var data: Dictionary
var failures := 0
var checks := 0


func _init() -> void:
	data = Data.load_all()
	for t in [
		"test_data_references",
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
