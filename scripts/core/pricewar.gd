extends RefCounted
## Cartel price wars (P6 first slice). Pure rules over a Game; numbers in content.json "pricewar".
##
## A cartel that dominates a trade location and is hostile enough can start a price war there while you are present
## (some of your own ground or a dealer). For a few days everything you sell at that location fetches less and
## everything you buy there costs more. Ways out: wait it out, raise your influence (own at least `end_you` and
## out-hold the aggressor), pay the cartel off (`pay_off`), or wreck a cartel base (Cartels.on_raid ends every war
## of that cartel and weakens it). After an end the location gets a short truce.
##
## State: Game.price_wars = {loc: {"cartel": id, "ends": day, "started": day}}, Game.price_truce = {loc: day}.
## Both saved; old saves start with none. Events: price_war_started, price_war_ended {loc, cartel, why}.

const Cartels = preload("res://scripts/core/cartels.gd")


static func rules(g) -> Dictionary:
	return g.data.get("pricewar", {})


static func active(g, loc: String) -> bool:
	return g.price_wars.has(loc)


static func war(g, loc: String) -> Dictionary:
	return g.price_wars.get(loc, {})


## Locations at war, sorted by name for stable UI.
static func locations(g) -> Array:
	var r: Array = g.price_wars.keys()
	r.sort()
	return r


## Multiplier on what you get for selling at `loc` (1.0 = no war).
static func sell_mult(g, loc: String) -> float:
	return 1.0 - float(rules(g).get("sell_cut", 0.0)) if active(g, loc) else 1.0


## Multiplier on what you pay for buying at `loc`.
static func buy_mult(g, loc: String) -> float:
	return 1.0 + float(rules(g).get("buy_spike", 0.0)) if active(g, loc) else 1.0


static func days_left(g, loc: String) -> int:
	return maxi(0, int(war(g, loc).get("ends", 0)) - g.day + 1) if active(g, loc) else 0


## Cost to buy the war off: base plus a share per remaining day, cheaper the more ground you hold.
static func pay_cost(g, loc: String) -> int:
	if not active(g, loc):
		return 0
	var r := rules(g)
	var c := float(r.get("pay_base", 0.0)) + float(r.get("pay_per_day", 0.0)) * days_left(g, loc)
	c *= 1.0 - clampf(Cartels.share(g, loc), 0.0, 1.0) * float(r.get("pay_you_discount", 0.0))
	return int(round(c))


## One-line status for the UI / HUD.
static func label(g, loc: String) -> String:
	if not active(g, loc):
		return ""
	var w := war(g, loc)
	var r := rules(g)
	return "Price war (%s): sales -%d%%, buying +%d%%, %d day%s left" % [
		Cartels.gang(g, str(w.cartel)).get("name", w.cartel), int(round(float(r.get("sell_cut", 0.0)) * 100.0)),
		int(round(float(r.get("buy_spike", 0.0)) * 100.0)), days_left(g, loc), "" if days_left(g, loc) == 1 else "s"]


## How to end it, as text for tooltips.
static func howto(g, loc: String) -> String:
	var r := rules(g)
	return "Ends by itself on day %d. Faster: take the streets back (hold %d%% and out-hold %s), pay %d cr, or wreck a cartel base." % [
		int(war(g, loc).get("ends", 0)), int(round(float(r.get("end_you", 0.0)) * 100.0)),
		Cartels.gang(g, str(war(g, loc).get("cartel", ""))).get("name", "them"), pay_cost(g, loc)]


# ---------------------------------------------------------------- starting and ending

## Chance per day that a war starts at `loc` (0 when the conditions are not met).
static func start_chance(g, loc: String) -> float:
	var r := rules(g)
	if r.is_empty() or active(g, loc) or not g.cartels.influence.has(loc):
		return 0.0
	if int(g.price_truce.get(loc, 0)) >= g.day or g.price_wars.size() >= int(r.get("max_wars", 1)):
		return 0.0
	var top := Cartels.top_cartel(g, loc)
	if top.id == "" or float(top.share) < float(r.get("start_share", 1.0)) or Cartels.weakened(g, str(top.id)):
		return 0.0
	var you := Cartels.share(g, loc)
	if you >= float(top.share):
		return 0.0
	if you < float(r.get("min_you", 0.0)) and not Cartels._has_dealer(g, loc):
		return 0.0
	var h := Cartels.hostility(g, str(top.id))
	if h < float(r.get("min_hostility", 0.0)):
		return 0.0
	return clampf(float(r.get("chance_base", 0.0)) + h * float(r.get("chance_per_hostility", 0.0)), 0.0, 1.0)


static func start(g, loc: String, cartel: String) -> bool:
	if active(g, loc) or not g.cartels.influence.has(loc):
		return false
	var r := rules(g)
	g.price_wars[loc] = {"cartel": cartel, "started": g.day, "ends": g.day + int(r.get("days", 4)) - 1}
	g._emit("price_war_started", {"loc": loc, "cartel": cartel})
	return true


## why: "expired", "influence", "paid", "raid", "weakened".
static func end(g, loc: String, why: String) -> void:
	if not active(g, loc):
		return
	var w: Dictionary = g.price_wars[loc]
	g.price_wars.erase(loc)
	g.price_truce[loc] = g.day + int(rules(g).get("truce_days", 0))
	g._emit("price_war_ended", {"loc": loc, "cartel": w.cartel, "why": why})


## Pays the aggressor off. Returns {ok, msg}.
static func pay_off(g, loc: String) -> Dictionary:
	if not active(g, loc):
		return {"ok": false, "msg": "No price war here."}
	var cost := pay_cost(g, loc)
	if g.credits < cost:
		return {"ok": false, "msg": "Not enough credits (%d cr)." % cost}
	var cartel := str(war(g, loc).cartel)
	g.credits -= cost
	end(g, loc, "paid")
	return {"ok": true, "msg": "%s calls off the price war for %d cr." % [Cartels.gang(g, cartel).get("name", cartel), cost]}


## Wars end once you hold enough ground against the aggressor (checked after every influence change and each day).
static func _check_influence(g, loc: String) -> void:
	if not active(g, loc):
		return
	var cartel := str(war(g, loc).cartel)
	if Cartels.share(g, loc) >= float(rules(g).get("end_you", 1.0)) and Cartels.share(g, loc) > Cartels.share(g, loc, cartel):
		end(g, loc, "influence")


static func on_event(g, kind: String, p: Dictionary) -> void:
	if g.price_wars.is_empty():
		return
	if kind == "influence":
		_check_influence(g, str(p.get("loc", "")))
	elif kind == "cartel_raided":
		on_raid(g, str(p.get("cartel", "")))


## A cartel base went down: every war of that cartel ends.
static func on_raid(g, id: String) -> void:
	for loc in g.price_wars.keys():
		if str(g.price_wars[loc].cartel) == id:
			end(g, loc, "raid")


## Daily turn (after Cartels.new_day): expire, re-check, roll new wars.
static func new_day(g) -> void:
	if rules(g).is_empty():
		return
	for loc in g.price_wars.keys():
		var w: Dictionary = g.price_wars[loc]
		if Cartels.weakened(g, str(w.cartel)):
			end(g, loc, "weakened")
		elif g.day > int(w.ends):
			end(g, loc, "expired")
		else:
			_check_influence(g, loc)
	var locs: Array = Cartels.places(g)
	locs.sort()
	for loc in locs:
		var ch := start_chance(g, loc)
		if ch <= 0.0:
			continue
		var rng := RandomNumberGenerator.new()  ## own stream: the game RNG is left alone
		rng.seed = hash("%s:%d" % [loc, g.day])
		if rng.randf() < ch:
			start(g, loc, str(Cartels.top_cartel(g, loc).id))


# ---------------------------------------------------------------- save

static func to_save(g) -> Dictionary:
	return {"wars": g.price_wars.duplicate(true), "truce": g.price_truce.duplicate()}


static func from_save(g, d: Dictionary) -> void:
	g.price_wars = {}
	g.price_truce = {}
	for loc in d.get("wars", {}):
		var w = d.wars[loc]
		if g.cartels.influence.has(loc) and w is Dictionary and Cartels.gangs(g).has(str(w.get("cartel", ""))):
			g.price_wars[loc] = {"cartel": str(w.cartel), "started": int(w.get("started", g.day)), "ends": int(w.get("ends", g.day))}
	for loc in d.get("truce", {}):
		if g.cartels.influence.has(loc):
			g.price_truce[loc] = int(d.truce[loc])
