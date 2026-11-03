extends "res://scripts/ui/phone/phone_app.gd"
## Products: your recipe book. Every product you have cooked once, grouped by drug, with its recipe (base + additives
## in order), traits, best grade, which of your estates can make it and your asking price. Drugs you never cooked show
## as "???". Rules live in scripts/core/products.gd; this is only the view.

const Art = preload("res://scripts/core/art.gd")
const Mixing = preload("res://scripts/core/mixing.gd")
const People = preload("res://scripts/core/people.gd")
const Products = preload("res://scripts/core/products.gd")

var seen := 0  ## recipes the player has looked at (runtime): the badge shows new discoveries


func _init() -> void:
	id = "products"
	title = "Products"
	icon = "app_products"
	tint = Color("#ff6b5f")


func badge(g) -> int:
	return maxi(g.recipes.size() - seen, 0)


static func node_id(rk: String) -> String:
	return rk.replace(":", "_").replace("+", "_")


func home(g, phone) -> Control:
	seen = g.recipes.size()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var intro := UI.label("Everything you've cooked. Set an asking price per product, or leave it on Market and buyers pay what they offer.", 13, UI.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(intro)
	for base in g.data.bases:
		var list: Array = Products.list(g, base)
		v.add_child(Art.with_icon(base, UI.label(str(g.data.bases[base].name).to_upper(), 13, UI.GOLD if not list.is_empty() else UI.MUTED)))
		if list.is_empty():
			var l := UI.label("???  · cook %s once to unlock" % g.data.bases[base].name, 13, UI.MUTED)
			l.name = "Unknown_" + base
			v.add_child(l)
		for rk in list:
			v.add_child(_row(g, phone, rk))
	return v


func _row(g, phone, rk: String) -> Control:
	var b := Button.new()
	b.name = "Product_" + node_id(rk)
	b.custom_minimum_size = Vector2(0, 50)
	b.tooltip_text = UI.item_tip(g, rk)
	b.pressed.connect(func():
		AudioManager.play("click")
		phone.push(g.data.bases[g.recipes[rk].base].name, func(gg): return detail(gg, phone, rk)))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.offset_right = -6
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 6)
	b.add_child(h)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UI.label(_traits_text(g, rk), 14))
	col.add_child(UI.label(_recipe_text(g, rk), 12, UI.MUTED))
	h.add_child(col)
	var priced := Products.has_price(g, rk)
	h.add_child(UI.label("%d cr" % Products.price(g, rk) if priced else "Market", 15, UI.GOLD if priced else UI.ACCENT))
	for ch in h.get_children():
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in col.get_children():
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(col.get_child(1) as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	(col.get_child(1) as Label).custom_minimum_size.x = 10
	return b


## One product: recipe steps, traits, estates that can make it, the price editor and who buys at that price.
func detail(g, _phone, rk: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var r: Dictionary = g.recipes.get(rk, {})
	if r.is_empty():
		v.add_child(UI.label("Unknown product.", 14, UI.MUTED))
		return v
	v.add_child(Art.with_icon(rk, UI.label(Mixing.display_name(g.data, rk), 15, UI.GOLD)))
	v.add_child(UI.label("RECIPE", 12, UI.MUTED))
	var steps := VBoxContainer.new()
	steps.add_theme_constant_override("separation", 2)
	var base_name: String = g.data.bases[r.base].name
	steps.add_child(Art.with_icon(g.data.bases[r.base].raw, UI.label("1. %s base (%s)" % [base_name, g.item_name(g.data.bases[r.base].raw)], 14)))
	if (r.additives as Array).is_empty() and (Mixing.parse_key(rk).traits as Array).size() > 1:
		steps.add_child(UI.label("Recipe unknown: cook it again to note the mix order.", 13, UI.WARN))
	var n := 2
	for a in r.additives:
		steps.add_child(Art.with_icon(a, UI.label("%d. + %s" % [n, g.data.additives[a].name], 14)))
		n += 1
	v.add_child(UI.card(steps, true))
	v.add_child(UI.label("TRAITS", 12, UI.MUTED))
	for t in Mixing.parse_key(rk).traits:
		var td: Dictionary = g.data.traits[t]
		v.add_child(UI.label("%s  %+d%% value" % [td.name, int(round(float(td.value) * 100.0))], 14, UI.ACCENT if float(td.value) >= 0.0 else UI.WARN))
	var best: Dictionary = Mixing.grade_info(g.data, int(r.best))
	v.add_child(UI.label("Made %d units since day %d · best grade %s" % [int(r.made), int(r.day), best.name], 13, UI.MUTED))
	var makers: Array = Products.makers(g, rk)
	var where: Array = []
	for eid in makers:
		where.append(g.data.estates[eid].name)
	var wl := UI.label("Can cook at: %s" % (", ".join(PackedStringArray(where)) if not where.is_empty() else "no estate has all stations yet"), 13, UI.TEXT if not where.is_empty() else UI.WARN)
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(wl)
	v.add_child(UI.label("ASKING PRICE (per Standard unit)", 12, UI.MUTED))
	v.add_child(_price_editor(g, rk))
	v.add_child(UI.label("BUYERS YOU KNOW", 12, UI.MUTED))
	var any := false
	for c in g.data.contacts:
		if not People.state(g, c.id).known or not g.demand.get(c.location, {}).has(r.base):
			continue
		any = true
		v.add_child(_buyer_line(g, rk, c))
	if not any:
		v.add_child(UI.label("Nobody you know buys %s yet." % base_name, 13, UI.MUTED))
	return v


func _price_editor(g, rk: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var priced := Products.has_price(g, rk)
	var cur := Products.price(g, rk)
	var big := UI.label("%d cr" % cur if priced else "Market (worth ~%d cr)" % Products.suggested(g, rk), 20, UI.GOLD if priced else UI.ACCENT)
	big.name = "Price"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(big)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	var steps: Array = Products.rules(g).get("price_steps", [1, 5, 25])
	var all: Array = []
	for i in range(steps.size() - 1, -1, -1):
		all.append(-int(steps[i]))
	for s in steps:
		all.append(int(s))
	for d in all:
		var b := UI.button("%+d" % d, func(): GameState.act(Products.set_price(g, rk, Products.price(g, rk) + d)), 44)
		b.name = ("Down%d" % -d) if d < 0 else ("Up%d" % d)
		b.tooltip_text = "Asking price %+d cr" % d
		row.add_child(b)
	col.add_child(row)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 6)
	var sug := UI.button("Worth (%d)" % Products.suggested(g, rk), func(): GameState.act(Products.set_price(g, rk, Products.suggested(g, rk))), 110)
	sug.name = "Suggested"
	sug.tooltip_text = "Value of a Standard unit at normal demand"
	row2.add_child(sug)
	var mk := UI.button("Market", func(): GameState.act(Products.clear_price(g, rk)), 90)
	mk.name = "Market"
	mk.disabled = not priced
	mk.tooltip_text = "Let every buyer pay what they offer"
	row2.add_child(mk)
	col.add_child(row2)
	var grades: Array = g.data.get("quality", {}).get("grades", [])
	if priced and not grades.is_empty():
		var parts: Array = []
		for i in grades.size():
			parts.append("%s %d" % [grades[i].name, Products.asking(g, rk + ("" if i == Mixing.STANDARD else "@%d" % i))])
		var gl := UI.label(" · ".join(PackedStringArray(parts)), 12, UI.MUTED)
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(gl)
	return UI.card(col, true)


func _buyer_line(g, rk: String, c: Dictionary) -> Control:
	var offer: int = g.sell_price(rk, c.id, c.location)
	var top := Products.ceiling(g, rk, c.id, c.location)
	var ask := Products.asking(g, rk)
	var ok := ask < 0 or ask <= top
	var txt := "%s (%s): offers %d, pays up to %d" % [c.name, g.loc_data(c.location).get("name", ""), offer, top]
	var l := UI.label(("✓ " if ok else "✗ ") + txt, 13, UI.ACCENT if ok else UI.WARN)
	l.name = "Buyer_" + str(c.id)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.tooltip_text = "Their offer moves with local demand, affinity and their taste; hooked and loyal customers tolerate more."
	return l


static func _traits_text(g, rk: String) -> String:
	var names: Array = []
	for t in Mixing.parse_key(rk).traits:
		names.append(g.data.traits[t].name)
	return ", ".join(PackedStringArray(names))


static func _recipe_text(g, rk: String) -> String:
	var r: Dictionary = g.recipes[rk]
	if (r.additives as Array).is_empty():
		return "plain" if (Mixing.parse_key(rk).traits as Array).size() <= 1 else "recipe unknown"
	var names: Array = []
	for a in r.additives:
		names.append(g.data.additives[a].name)
	return "+ " + " + ".join(PackedStringArray(names))
