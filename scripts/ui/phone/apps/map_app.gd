extends "res://scripts/ui/phone/phone_app.gd"
## Galaxy Map: the star systems with their jump lanes, a heat overlay (patrol pressure) or a price overlay (where the
## cheap raws are), per-system location details, a price comparison screen and route planning for the jump drive.
## Rules and numbers live in scripts/core/galaxy.gd and content.json "jump".

const Galaxy = preload("res://scripts/core/galaxy.gd")
const Cartels = preload("res://scripts/core/cartels.gd")

const CANVAS_H := 170.0
const COLD := Color("#4fe3c1")
const HOT := Color("#ff6b5f")

var _mode := "heat"  ## heat | price | influence
var _sel := ""  ## selected system id, "" = the one you are in
var _tab := "buy"  ## price screen: buy | sell


class MapCanvas extends Control:
	## Lanes and the overlay glow behind the system buttons; positions are anchor ratios shared with the buttons.
	var lanes: Array = []  ## [[Vector2 ratio, Vector2 ratio, bool route]]
	var glows: Array = []  ## [[Vector2 ratio, Color, float radius]]
	var marker := Vector2(-1, -1)  ## ratio of the system you are in
	var pulse := 0.0

	func _process(delta: float) -> void:
		pulse += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0a0e24"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("#262b4d"), false, 1.0)
		for l in lanes:
			draw_line(l[0] * size, l[1] * size, Color("#4fe3c1") if l[2] else Color("#3a4170"), 3.0 if l[2] else 2.0)
		for gl in glows:
			var p: Vector2 = gl[0] * size
			for i in 4:
				draw_circle(p, gl[2] * (1.0 - i * 0.2), Color(gl[1], 0.3))
		if marker.x >= 0.0:
			draw_arc(marker * size, 30.0 + sin(pulse * 3.0) * 2.0, 0.0, TAU, 32, Color("#ffffff", 0.8), 1.5)


func _init() -> void:
	id = "map"
	title = "Map"
	icon = "app_map"
	tint = Color("#8f7bff")


func home(g, phone) -> Control:
	if _sel == "" or not g.data.systems.has(_sel):
		_sel = g.system
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(_mode_row(g))
	v.add_child(_canvas(g))
	var legend := UI.label(_legend(), 12, UI.MUTED)
	legend.name = "MapLegend"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(legend)
	v.add_child(_system_panel(g))
	v.add_child(_drive_panel(g))
	v.add_child(UI.button("Price comparison", func(): phone.push("Prices", func(gg): return _prices(gg)), 0))
	v.get_child(v.get_child_count() - 1).name = "MapPrices"
	return v


# ---------------------------------------------------------------- map

func _legend() -> String:
	match _mode:
		"heat":
			return "Glow = patrol pressure at your heat."
		"influence":
			return "Glow = who runs the system (average share of its locations). Selling, drops and shooting raiders raise your share; high share = better prices and fewer pirates, low share = robberies."
	return "Glow = share of the cheapest raws and additives sold there."


## Holder with the biggest average share in a system: you or a cartel.
func _system_top(g, sys: String) -> String:
	var best := Cartels.NONE
	var bv := 0.0
	for k in Cartels.holders(g):
		if k == Cartels.NONE:
			continue
		var v := Cartels.system_share(g, sys, k)
		if v > bv:
			best = k
			bv = v
	return best


func _mode_row(g) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for m in [["heat", "Heat"], ["price", "Prices"], ["influence", "Influence"]]:
		var b := UI.button(m[1], func():
			_mode = m[0]
			_refresh_soon(), 0)
		b.name = "MapMode_" + m[0]
		b.toggle_mode = true
		b.button_pressed = _mode == m[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return row


func _positions(g) -> Dictionary:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for s in g.data.systems:
		var gp: Array = g.data.systems[s].galaxy_pos
		lo = Vector2(minf(lo.x, gp[0]), minf(lo.y, gp[1]))
		hi = Vector2(maxf(hi.x, gp[0]), maxf(hi.y, gp[1]))
	var span := Vector2(maxf(hi.x - lo.x, 1.0), maxf(hi.y - lo.y, 1.0))
	var r := {}
	for s in g.data.systems:
		var gp: Array = g.data.systems[s].galaxy_pos
		r[s] = Vector2(0.22 + 0.56 * (gp[0] - lo.x) / span.x, 0.2 + 0.6 * (gp[1] - lo.y) / span.y)
	return r


## Share of items whose cheapest offer is in each system (price overlay).
func _deal_share(g) -> Dictionary:
	var share := {}
	var table := Galaxy.buy_table(g)
	for row in table:
		var s: String = row.offers[0].system
		share[s] = float(share.get(s, 0.0)) + 1.0 / table.size()
	return share


func _canvas(g) -> Control:
	var pos := _positions(g)
	var c := MapCanvas.new()
	c.name = "MapCanvas"
	c.custom_minimum_size = Vector2(0, CANVAS_H)
	var route_pairs := {}
	if _sel != g.system:
		var rt := Galaxy.route(g, g.system, _sel)
		for i in range(rt.size() - 1):
			route_pairs["%s|%s" % [rt[i], rt[i + 1]]] = true
			route_pairs["%s|%s" % [rt[i + 1], rt[i]]] = true
	for l in Galaxy.lanes(g):
		c.lanes.append([pos[l.a], pos[l.b], route_pairs.has("%s|%s" % [l.a, l.b])])
	var share := _deal_share(g) if _mode == "price" else {}
	for s in g.data.systems:
		var col: Color
		var rad: float
		if _mode == "heat":
			var lv := Galaxy.heat_level(g, s)
			col = COLD.lerp(HOT, lv)
			rad = 26.0 + 22.0 * lv
		elif _mode == "influence":
			var top := _system_top(g, s)
			col = Cartels.color(g, top)
			rad = 20.0 + 50.0 * Cartels.system_share(g, s, top)
		else:
			var sh := float(share.get(s, 0.0))
			col = UI.GOLD
			rad = 18.0 + 40.0 * sh
		c.glows.append([pos[s], col, rad])
	c.marker = pos[g.system]
	for s in g.data.systems:
		var b := Button.new()
		b.name = "MapSys_" + s
		b.text = str(g.data.systems[s].name)
		b.add_theme_font_size_override("font_size", 12)
		b.toggle_mode = true
		b.button_pressed = s == _sel
		b.set_anchor(SIDE_LEFT, pos[s].x)
		b.set_anchor(SIDE_RIGHT, pos[s].x)
		b.set_anchor(SIDE_TOP, pos[s].y)
		b.set_anchor(SIDE_BOTTOM, pos[s].y)
		b.offset_left = -52.0
		b.offset_right = 52.0
		b.offset_top = -13.0
		b.offset_bottom = 13.0
		b.pressed.connect(func():
			_sel = s
			AudioManager.play("click")
			_refresh_soon())
		c.add_child(b)
	return c


# ---------------------------------------------------------------- selected system

func _system_panel(g) -> Control:
	var sd: Dictionary = g.data.systems[_sel]
	var panel := PanelContainer.new()
	panel.name = "MapSystem"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)
	var top := HBoxContainer.new()
	var nm := UI.label(str(sd.name) + ("  (you are here)" if _sel == g.system else ""), 16, UI.ACCENT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	top.add_child(UI.label("security: %s" % sd.security, 12, UI.MUTED))
	col.add_child(top)
	var desc := UI.label(str(sd.get("desc", "")), 12, UI.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(desc)
	var lv := Galaxy.heat_level(g, _sel)
	var hr := HBoxContainer.new()
	hr.add_child(UI.label("Heat %d" % int(Galaxy.system_heat(g, _sel)), 13, COLD.lerp(HOT, lv)))
	var bar := UI.bar(COLD.lerp(HOT, lv))
	bar.name = "MapHeatBar"
	bar.max_value = 1.0
	bar.value = lv
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(bar)
	hr.add_child(UI.label("%d patrols" % Galaxy.patrols_in(g, _sel), 13, UI.MUTED))
	col.add_child(hr)
	if _mode == "influence":
		col.add_child(_cartel_list(g))
	var best := _best_buys(g)
	for loc in g.locations_in(_sel):
		col.add_child(_location_row(g, loc, best))
	return panel


## Legend of the three cartels: colour, boss and home turf.
func _cartel_list(g) -> Control:
	var v := VBoxContainer.new()
	v.name = "MapCartels"
	v.add_theme_constant_override("separation", 1)
	for c in Cartels.list(g):
		var l := UI.label("%s: %s, %s. Home: %s." % [c.name, c.boss, c.boss_title, g.data.locations[c.home].name], 12, Cartels.color(g, c.id))
		l.name = "MapCartel_" + str(c.id)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	return v


## item -> cheapest location id, for the star marks.
func _best_buys(g) -> Dictionary:
	var r := {}
	for row in Galaxy.buy_table(g):
		r[row.item] = row.offers[0].loc
	return r


func _location_row(g, loc: String, best: Dictionary) -> Control:
	var ld: Dictionary = g.data.locations[loc]
	var risk := Galaxy.location_risk(g, loc)
	var box := VBoxContainer.new()
	box.name = "MapLoc_" + loc
	var line := "%s" % ld.name
	var sub := ""
	if ld.has("jump_to"):
		sub = "Jump gate to %s" % g.data.systems[ld.jump_to].name
	elif not ld.get("dockable", true):
		sub = "Patrol base. Stay clear."
	elif _mode == "influence":
		sub = _influence_text(g, loc)
	elif _mode == "heat":
		sub = "sale heat %s/unit" % str(risk.sale_heat)
		if risk.security >= 0.0:
			sub += ", police x%s" % str(risk.security)
		else:
			sub += ", no walkable surface"
	else:
		var goods: Array = []
		for item in ld.sells_raw:
			goods.append("%s %d%s" % [g.item_name(item), int(ld.sells_raw[item]), "*" if best.get(item, "") == loc else ""])
		if ld.get("sells_additives", false):
			goods.append("additives")
		if ld.get("fence", false):
			goods.append("fence")
		sub = ", ".join(PackedStringArray(goods)) if not goods.is_empty() else "sells nothing"
	box.add_child(UI.label(line, 14))
	var s := UI.label(sub, 12, UI.MUTED)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(s)
	if _mode == "influence" and g.influence.has(loc):
		box.add_child(_influence_bar(g, loc))
	return box


func _influence_text(g, loc: String) -> String:
	if not g.influence.has(loc):
		return "Nobody fights over this place."
	var tier := Cartels.tier(g, loc)
	var parts: Array = []
	for k in Cartels.holders(g):
		var v := Cartels.share(g, loc, k)
		if v >= 0.01 and k != Cartels.NONE:
			parts.append("%s %d%%" % [Cartels.who_name(g, k), int(round(v * 100.0))])
	var note := {"high": "respected: better prices", "low": "weak: robbery risk", "mid": "contested"}[tier]
	return "%s  (%s)" % [", ".join(PackedStringArray(parts)), note]


## Stacked bar of the shares at a location in the holders' colours.
func _influence_bar(g, loc: String) -> Control:
	var bar := HBoxContainer.new()
	bar.name = "MapInf_" + loc
	bar.add_theme_constant_override("separation", 0)
	bar.custom_minimum_size = Vector2(0, 8)
	for k in Cartels.holders(g):
		var v := Cartels.share(g, loc, k)
		if v <= 0.0:
			continue
		var seg := ColorRect.new()
		seg.color = Cartels.color(g, k)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.size_flags_stretch_ratio = v
		seg.custom_minimum_size = Vector2(1, 8)
		seg.tooltip_text = "%s %d%%" % [Cartels.who_name(g, k), int(round(v * 100.0))]
		bar.add_child(seg)
	return bar


# ---------------------------------------------------------------- jump drive

func _drive_panel(g) -> Control:
	var panel := PanelContainer.new()
	panel.name = "MapDrive"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	col.add_child(UI.label("JUMP DRIVE", 13, UI.MUTED))
	if not g.jump_plan.is_empty():
		var to: String = g.jump_plan.to
		var names: Array = []
		for s in g.jump_plan.route:
			names.append(str(g.data.systems[s].name))
		var l := UI.label("Route: " + " > ".join(PackedStringArray(names)), 13)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
		var bar := UI.bar(UI.ACCENT)
		bar.name = "MapCharge"
		bar.max_value = 1.0
		bar.value = Galaxy.progress(g)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(bar)
		col.add_child(UI.label("Charging %d%% for %s" % [int(Galaxy.progress(g) * 100.0), g.data.systems[to].name], 13, UI.ACCENT))
		var cb := UI.button("Cancel jump", func():
			Galaxy.cancel(g)
			_refresh_soon(), 0)
		cb.name = "MapCancel"
		col.add_child(cb)
		return panel
	if _sel == g.system:
		var t := UI.label("Select another system to plan a route.", 13, UI.MUTED)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(t)
		return panel
	var pl := Galaxy.plan(g, _sel)
	if not pl.ok:
		col.add_child(UI.label(str(pl.msg), 13, UI.WARN))
		return panel
	var names: Array = []
	for s in pl.route:
		names.append(str(g.data.systems[s].name))
	var rl := UI.label("Route: " + " > ".join(PackedStringArray(names)), 13)
	rl.name = "MapRoute"
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(rl)
	var cost := UI.label("%d hop%s, tolls %d cr, charge %.0fs + travel %.0fs" % [pl.hops, "" if pl.hops == 1 else "s", pl.fee, pl.charge, pl.travel], 12, UI.MUTED)
	cost.name = "MapCost"
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(cost)
	var go := UI.button("Charge jump drive", func():
		AudioManager.play("click")
		var r: Dictionary = Galaxy.start(g, _sel)
		EventBus.toast.emit(r.msg, r.ok)
		_refresh_soon(), 0)
	go.name = "MapJump"
	if g.location != "":
		go.disabled = true
		col.add_child(UI.label("Undock first: the drive needs open space.", 12, UI.MUTED))
	elif g.credits < int(pl.fee):
		go.disabled = true
		col.add_child(UI.label("Not enough credits for the tolls.", 12, UI.WARN))
	col.add_child(go)
	return panel


# ---------------------------------------------------------------- price comparison

func _prices(g) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	var tabs := HBoxContainer.new()
	for t in [["buy", "Raws and additives"], ["sell", "Product demand"]]:
		var b := UI.button(t[1], func():
			_tab = t[0]
			_refresh_soon(), 0)
		b.name = "MapTab_" + t[0]
		b.toggle_mode = true
		b.button_pressed = _tab == t[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
	v.add_child(tabs)
	var tip := UI.label("Cheapest first. Walk-in prices; the phone shop adds a markup." if _tab == "buy" else "Base value of a plain batch per unit at today's demand, best first. Customers and the fence adjust it.", 12, UI.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)
	var rows: Array = Galaxy.buy_table(g) if _tab == "buy" else Galaxy.sell_table(g)
	for row in rows:
		v.add_child(_price_row(g, row))
	return v


func _price_row(g, row: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Price_" + str(row.get("item", row.get("base", "")))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	panel.add_child(col)
	col.add_child(UI.label(str(row.name), 14))
	for i in row.offers.size():
		var o: Dictionary = row.offers[i]
		var line := HBoxContainer.new()
		var where := UI.label("%s  (%s)" % [g.data.locations[o.loc].name, g.data.systems[o.system].name], 12, UI.TEXT if i == 0 else UI.MUTED)
		where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(where)
		line.add_child(UI.label("%d cr%s" % [o.price, "  best" if i == 0 else ""], 12, UI.GOLD if i == 0 else UI.MUTED))
		col.add_child(line)
	return panel


func _refresh_soon() -> void:
	EventBus.game_event.emit("map_ui", {})
