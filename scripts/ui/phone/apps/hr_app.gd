extends "res://scripts/ui/phone/phone_app.gd"
## HR: hire lab hands and stockers and street dealers (dealers.gd) (wage per day, skill, loyalty), assign them to your estates, set the auto recipe and
## look after the estate storage. All rules live in scripts/core/workers.gd; this is only the view.

const Workers = preload("res://scripts/core/workers.gd")
const Mixing = preload("res://scripts/core/mixing.gd")
const Dealers = preload("res://scripts/core/dealers.gd")
const Drones = preload("res://scripts/core/drones.gd")
const Products = preload("res://scripts/core/products.gd")


func _init() -> void:
	id = "hr"
	title = "HR"
	icon = "app_hr"
	tint = Color("#ffd166")


## Badge = people about to quit.
func badge(g) -> int:
	var n := 0
	for w in g.workers:
		if float(w.loyalty) < 0.25:
			n += 1
	return n


func home(g, phone) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var c: Dictionary = Workers.cfg(g)
	v.add_child(UI.label("Crew %d/%d · wages %d cr/day" % [g.workers.size(), int(c.max_staff), Workers.wage_total(g)], 15, UI.GOLD))
	v.add_child(UI.label("CREW", 13, UI.MUTED))
	if g.workers.is_empty():
		v.add_child(UI.label("Nobody on the payroll.", 14, UI.MUTED))
	for w in g.workers:
		v.add_child(_worker_row(g, phone, Workers.candidate(g, w.id), w, "Crew_"))
	v.add_child(UI.label("ESTATES", 13, UI.MUTED))
	if g.estates.is_empty():
		v.add_child(UI.label("You own no estate. Workers need one to work in.", 14, UI.MUTED))
	for eid in g.estates:
		var b := UI.button("%s · %s" % [g.data.estates[eid].name, _estate_state(g, eid)], func(): phone.push(g.data.estates[eid].name, func(gg): return estate(gg, phone, eid)))
		b.tooltip_text = {"cooking": "Your crew is cooking here.", "idle": "Nothing cooking: %s." % Workers.blocker(g, eid), "ready": "Ready to cook. Open to set the recipe and stock it."}[_estate_state(g, eid)]
		b.name = "EstateRow_" + eid
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
	v.add_child(UI.label("DEALERS %d/%d" % [g.dealers.size(), int(Dealers.cfg(g).get("max_dealers", 3))], 13, UI.MUTED))
	if g.dealers.is_empty():
		v.add_child(_wrap("No dealers yet. They sell your product in a district while you're away and keep a cut.", 14, UI.MUTED))
	for d in g.dealers:
		v.add_child(_dealer_row(g, phone, Dealers.candidate(g, d.id), d))
	v.add_child(UI.label("FOR HIRE", 13, UI.MUTED))
	var open: Array = Workers.available(g)
	if open.is_empty():
		v.add_child(UI.label("Nobody left to hire.", 14, UI.MUTED))
	for cand in open:
		v.add_child(_worker_row(g, phone, cand, {}, "Hire_"))
	for cand in Dealers.available(g):
		v.add_child(_dealer_row(g, phone, cand, {}))
	return v


func _dealer_row(g, phone, cand: Dictionary, d: Dictionary) -> Control:
	var b := Button.new()
	b.name = ("Dealer_" if not d.is_empty() else "DHire_") + cand.id
	b.tooltip_text = ("Manage %s: stock, district and cash." if not d.is_empty() else "%s could deal for you. Open to see their cut and hire them.") % cand.name
	b.custom_minimum_size = Vector2(0, 54)
	b.pressed.connect(func():
		AudioManager.play("click")
		phone.push(cand.name, func(gg): return dealer(gg, cand.id)))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.offset_right = -6
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.add_child(UI.label(cand.name, 16))
	var sub := "Dealer · skill %d%% · cut %d%%" % [int(round(float(cand.skill) * 100.0)), int(round(float(cand.cut) * 100.0))]
	var right := "%d cr fee" % int(cand.fee)
	var right_col := UI.GOLD
	if not d.is_empty():
		var st := Dealers.status(g, d)
		sub = "%s · %d units · %s" % [g.loc_data(d.loc).get("name", "no district") if d.loc != "" else "no district", Dealers.units(d), st if st != "" else "selling"]
		right = "%d cr" % int(d.cash)
		right_col = UI.GOLD if int(d.cash) > 0 else UI.MUTED
	var sl := UI.label(sub, 13, UI.MUTED)
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sl.custom_minimum_size.x = 10
	col.add_child(sl)
	h.add_child(col)
	h.add_child(UI.label(right, 14, right_col))
	b.add_child(h)
	for ch in [h, col] + col.get_children() + h.get_children():
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## A dealer: hire, district, stock, cash.
func dealer(g, did: String) -> Control:
	var cand: Dictionary = Dealers.candidate(g, did)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if cand.is_empty():
		return v
	v.add_child(_wrap(cand.get("bio", ""), 14))
	v.add_child(_meter("Skill", "%d%%" % int(round(float(cand.skill) * 100.0)), float(cand.skill), UI.ACCENT))
	v.add_child(_pair("Cut", "%d%% of every sale" % int(round(float(cand.cut) * 100.0))))
	v.add_child(_pair("Bag", "%d units" % int(cand.get("capacity", 30))))
	var d: Dictionary = Dealers.find(g, did)
	if d.is_empty():
		var hb := UI.accent_button("Hire (%d cr up front)" % int(cand.fee), func(): GameState.act(Dealers.hire(g, did)))
		hb.name = "DealerHire"
		hb.disabled = g.credits < int(cand.fee) or g.dealers.size() >= int(Dealers.cfg(g).get("max_dealers", 3))
		v.add_child(hb)
		v.add_child(_wrap("Dealers sell at your asking price from the Products app (Market = local value). Busts take their stock and cash; heat makes busts likelier.", 13, UI.MUTED))
		return v
	var st := Dealers.status(g, d)
	v.add_child(_pair("Status", st if st != "" else "Selling"))
	if d.loc != "":
		v.add_child(_pair("Bust risk", "%.1f%% per sale" % (Dealers.bust_chance(g, d) * 100.0)))
	v.add_child(_pair("Sold", "%d units" % int(d.sold)))
	v.add_child(UI.label("DISTRICT", 13, UI.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for loc in Dealers.districts(g):
		var here: bool = d.loc == loc
		var db := UI.button(("✓ " if here else "") + str(g.loc_data(loc).get("name", loc)), func(): GameState.act(Dealers.assign(g, did, loc)), 100)
		db.name = "District_%s_%s" % [did, loc]
		db.disabled = here
		db.clip_text = true
		db.custom_minimum_size.x = 150
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(db)
	v.add_child(grid)
	var present: bool = d.loc != "" and g.location == d.loc
	v.add_child(UI.label("STOCK", 13, UI.MUTED))
	_items(g, v, "Bag", d.stock)
	var cash_row := HBoxContainer.new()
	cash_row.add_theme_constant_override("separation", 6)
	var cl := UI.label("Cash: %d cr" % int(d.cash), 16, UI.GOLD)
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cash_row.add_child(cl)
	var cb := UI.accent_button("Collect", func(): GameState.act(Dealers.collect(g, did)), 90)
	cb.name = "Collect_" + did
	cb.disabled = not present or int(d.cash) <= 0
	cash_row.add_child(cb)
	v.add_child(cash_row)
	if present:
		v.add_child(UI.label("FROM YOUR HOLD", 13, UI.MUTED))
		var any := false
		for k in g.cargo:
			if not Mixing.is_product(k):
				continue
			any = true
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			var pr := Dealers.street_price(g, k, d.loc)
			var nl := UI.label("%d × %s · %s" % [int(g.cargo[k]), g.item_name(k), ("%d cr" % pr) if pr > 0 else "too steep"], 13, UI.TEXT if pr > 0 else UI.WARN)
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(nl)
			var g5 := UI.button("+5", func(): GameState.act(Dealers.give(g, did, k, 5)), 44)
			g5.name = "Give5_" + did
			row.add_child(g5)
			var ga := UI.button("All", func(): GameState.act(Dealers.give(g, did, k, int(g.cargo.get(k, 0)))), 50)
			ga.name = "GiveAll_" + did
			row.add_child(ga)
			v.add_child(row)
		if not any:
			v.add_child(UI.label("You carry no product.", 13, UI.MUTED))
		var tb := UI.button("Take stock back", func(): GameState.act(Dealers.take_back(g, did)))
		tb.name = "TakeBack_" + did
		tb.disabled = Dealers.units(d) == 0
		v.add_child(tb)
	elif d.loc != "":
		v.add_child(_wrap("Dock on %s to hand over product and collect cash." % g.loc_data(d.loc).get("name", ""), 13, UI.MUTED))
	var fb := UI.button("Let go", func(): GameState.act(Dealers.fire(g, did)))
	fb.name = "DealerFire_" + did
	v.add_child(fb)
	return v


func _estate_state(g, eid: String) -> String:
	if not g.estates[eid].job.is_empty():
		return "cooking"
	return "idle" if Workers.blocker(g, eid) != "" else "ready"


func _worker_row(g, phone, cand: Dictionary, w: Dictionary, prefix: String) -> Control:
	var b := Button.new()
	b.name = prefix + cand.id
	b.tooltip_text = ("Open %s: skill, wage, loyalty and where they work." if w.size() > 0 else "%s is looking for work. Open to see skill and wage.") % cand.name
	b.custom_minimum_size = Vector2(0, 54)
	b.pressed.connect(func():
		AudioManager.play("click")
		phone.push(cand.name, func(gg): return detail(gg, cand.id)))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.add_child(UI.label(cand.name, 16))
	var sub := "%s · skill %d%%" % [Workers.cfg(g).roles[cand.role].name, int(round(float(cand.skill) * 100.0))]
	if not w.is_empty():
		sub += " · " + (str(g.data.estates[w.estate].name) if w.estate != "" else "off duty")
	col.add_child(UI.label(sub, 13, UI.MUTED))
	h.add_child(col)
	h.add_child(UI.label("%d cr/day" % int(cand.wage), 14, UI.GOLD))
	b.add_child(h)
	for ch in col.get_children() + h.get_children():
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Profile of one candidate or hired worker: stats, hire/fire, assignment.
func detail(g, wid: String) -> Control:
	var cand: Dictionary = Workers.candidate(g, wid)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if cand.is_empty():
		v.add_child(UI.label("Gone.", 15, UI.MUTED))
		return v
	var role: Dictionary = Workers.cfg(g).roles[cand.role]
	v.add_child(UI.label(role.name, 14, UI.MUTED))
	v.add_child(_wrap(cand.get("bio", ""), 14))
	v.add_child(_wrap(role.desc, 13, UI.MUTED))
	v.add_child(_meter("Skill", "%d%%" % int(round(float(cand.skill) * 100.0)), float(cand.skill), UI.ACCENT))
	v.add_child(_pair("Wage", "%d cr/day" % int(cand.wage)))
	var i := Workers.find(g, wid)
	if i < 0:
		v.add_child(_meter("Loyalty", "%d%%" % int(round(float(cand.loyalty) * 100.0)), float(cand.loyalty), UI.GOLD))
		var cost := Workers.hire_cost(g, wid)
		var hb := UI.button("Hire (%d cr signing fee)" % cost, func(): Workers.hire(g, wid))
		hb.name = "HireBtn"
		hb.disabled = g.credits < cost or g.workers.size() >= int(Workers.cfg(g).max_staff)
		v.add_child(hb)
		return v
	var w: Dictionary = g.workers[i]
	v.add_child(_meter("Loyalty", "%d%%" % int(round(float(w.loyalty) * 100.0)), float(w.loyalty), UI.WARN if float(w.loyalty) < 0.3 else UI.GOLD))
	v.add_child(UI.label("ASSIGNMENT", 13, UI.MUTED))
	if g.estates.is_empty():
		v.add_child(UI.label("Buy an estate first.", 14, UI.MUTED))
	for eid in g.estates:
		var here: bool = w.estate == eid
		var ab := UI.button("%s%s" % [g.data.estates[eid].name, "  ✓ working here" if here else ""], func(): Workers.assign(g, wid, "" if here else eid))
		ab.name = "Assign_%s_%s" % [wid, eid]
		ab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(ab)
	var fb := UI.button("Fire", func(): Workers.fire(g, wid))
	fb.name = "Fire_" + wid
	v.add_child(fb)
	return v


## One estate: crew, auto recipe, job, storage.
func estate(g, _phone, eid: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if not g.estates.has(eid):
		return v
	var e: Dictionary = g.estates[eid]
	for role in ["lab_hand", "stocker"]:
		var w := Workers.at(g, eid, role)
		var txt: String = Workers.candidate(g, w.id).name if not w.is_empty() else "nobody"
		v.add_child(_pair(str(Workers.cfg(g).roles[role].name), txt))
	v.add_child(UI.label("AUTO RECIPE", 13, UI.MUTED))
	var opt := OptionButton.new()
	opt.name = "Recipe_" + eid
	opt.add_item("Off")
	var cur := 0
	var choices: Array = []  # [base, additives] per menu entry: plain drugs, then mixes from the Products app
	for b in g.data.bases:
		choices.append([b, []])
		opt.add_item(g.data.bases[b].name)
	for rk in Products.list(g):
		var r: Dictionary = g.recipes[rk]
		if (r.additives as Array).is_empty():
			continue
		choices.append([r.base, (r.additives as Array).duplicate()])
		opt.add_item(Mixing.display_name(g.data, rk))
	for k in choices.size():
		if not e.recipe.is_empty() and e.recipe.base == choices[k][0] and Array(e.recipe.get("additives", [])) == choices[k][1]:
			cur = k + 1
	opt.select(cur)
	opt.item_selected.connect(func(idx: int):
		var q: int = int(e.recipe.get("qty", g.lab_capacity()))
		GameState.act(Workers.set_recipe(g, eid, "" if idx == 0 else choices[idx - 1][0], [] if idx == 0 else choices[idx - 1][1], q)))
	v.add_child(opt)
	if not e.recipe.is_empty():
		var qrow := HBoxContainer.new()
		var ql := UI.label("Batch %d units  " % int(e.recipe.qty), 14)
		ql.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qrow.add_child(ql)
		var minus := UI.button("-", func(): Workers.set_recipe(g, eid, e.recipe.base, e.recipe.additives, int(e.recipe.qty) - 1), 36)
		minus.name = "QtyMinus_" + eid
		var plus := UI.button("+", func(): Workers.set_recipe(g, eid, e.recipe.base, e.recipe.additives, int(e.recipe.qty) + 1), 36)
		plus.name = "QtyPlus_" + eid
		qrow.add_child(minus)
		qrow.add_child(plus)
		v.add_child(qrow)
	var why := Workers.blocker(g, eid)
	if not e.job.is_empty():
		var bar := UI.bar(UI.ACCENT)
		bar.max_value = float(e.job.total)
		bar.value = float(e.job.total) - float(e.job.remaining)
		v.add_child(UI.label("Cooking %d × %s" % [int(e.job.qty), g.item_name(e.job.product)], 14, UI.ACCENT))
		v.add_child(bar)
	elif why != "":
		v.add_child(_wrap(why, 14, UI.MUTED))
	else:
		v.add_child(_wrap("Waiting for ingredients on the %s." % ("bench" if not Workers.at(g, eid, "stocker").is_empty() else "storage shelf"), 14, UI.MUTED))
	v.add_child(UI.label("STORAGE", 13, UI.MUTED))
	_items(g, v, "Shelf", e.storage)
	_items(g, v, "Bench", e.bench)
	_items(g, v, "Output tray", e.out)
	var inside: bool = g.inside_estate == eid
	var sb := UI.button("Stock raws from cargo", func():
		for k in g.cargo.keys():
			if not Mixing.is_product(k):
				Workers.deposit(g, eid, k, int(g.cargo[k])))
	sb.name = "StoreRaws"
	sb.disabled = not inside
	v.add_child(sb)
	var tb := UI.button("Take products to cargo", func(): Workers.take_products(g, eid))
	tb.name = "TakeProducts"
	tb.disabled = not inside
	v.add_child(tb)
	if not inside:
		v.add_child(UI.label("Stand inside the estate to move goods.", 13, UI.MUTED))
	_drones(g, v, eid)
	return v


## Courier drones of one estate (rules in drones.gd): buy one per route, flip the route, scrap.
func _drones(g, v: VBoxContainer, eid: String) -> void:
	if not Drones.eligible(g, eid):
		return
	var dc: Dictionary = Drones.cfg(g)
	v.add_child(UI.label("COURIER DRONES %d/%d · %d cr/day each" % [g.drones.size(), int(dc.max_total), int(dc.upkeep)], 13, UI.MUTED))
	for d in Drones.at_estate(g, eid):
		var did: int = int(d.id)
		var st := Drones.status(g, d)
		v.add_child(_wrap("#%d %s · %s" % [did, Drones.route_name(d.route), st if st != "" else "%d s per trip" % int(Drones.trip_seconds(g, eid))], 14))
		var row := HBoxContainer.new()
		var other: String = "to_estate" if d.route == "to_port" else "to_port"
		var fb := UI.button("Fly " + Drones.route_name(other).to_lower(), func(): GameState.act(Drones.set_route(g, did, other)))
		fb.name = "DroneRoute_%d" % did
		fb.tooltip_text = "Switch this drone to the other direction."
		row.add_child(fb)
		var xb := UI.button("Scrap", func(): GameState.act(Drones.scrap(g, did)), 80)
		xb.name = "DroneScrap_%d" % did
		xb.tooltip_text = "Sell the drone for %d%% of its price." % int(round(float(dc.scrap_refund) * 100.0))
		row.add_child(xb)
		v.add_child(row)
	for route in Drones.ROUTES:
		var bb := UI.button("Buy drone: %s (%d cr)" % [Drones.route_name(route).to_lower(), int(dc.price)], func(): GameState.act(Drones.buy(g, eid, route)))
		bb.name = "DroneBuy_%s_%s" % [eid, route]
		bb.disabled = g.credits < int(dc.price) or g.drones.size() >= int(dc.max_total) or Drones.at_estate(g, eid).size() >= int(dc.max_per_estate)
		bb.tooltip_text = ("Carries finished product to your hub stash at the spaceport." if route == "to_port"
			else "Carries what the auto recipe lacks from the hub stash to this estate.") + " Up to %d units per trip." % int(dc.capacity)
		v.add_child(bb)


func _items(g, v: VBoxContainer, label: String, items: Dictionary) -> void:
	var parts: Array = []
	for k in items:
		parts.append("%d %s" % [int(items[k]), g.item_name(k)])
	v.add_child(_wrap("%s: %s" % [label, ", ".join(PackedStringArray(parts)) if not parts.is_empty() else "empty"], 14))


func _wrap(text: String, size: int, color := UI.TEXT) -> Label:
	var l := UI.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _pair(k: String, val: String) -> Control:
	var h := HBoxContainer.new()
	var kl := UI.label(k, 14, UI.MUTED)
	kl.custom_minimum_size.x = 110
	h.add_child(kl)
	h.add_child(UI.label(val, 14))
	return h


func _meter(k: String, val: String, ratio: float, color: Color) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.add_child(_pair(k, val))
	var bar := UI.bar(color)
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = clampf(ratio, 0.0, 1.0)
	bar.custom_minimum_size = Vector2(0, 8)
	col.add_child(bar)
	return col
