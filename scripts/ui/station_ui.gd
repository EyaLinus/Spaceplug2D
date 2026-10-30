extends Control
## Docked menu. Tabs depend on what the location offers: Market, Lab, Deals, Shipyard, Office.
## On a planet surface it opens filtered to one building or person (see open()), and its button closes the panel
## instead of undocking.
## Rebuilds its content from the core Game state after every game event, so it never caches stale numbers.

const UI = preload("res://scripts/ui/ui_theme.gd")
const Mixing = preload("res://scripts/core/mixing.gd")
const Art = preload("res://scripts/core/art.gd")
const Production = preload("res://scripts/core/production.gd")
const RunnerScript = preload("res://scripts/ui/minigames/minigame_runner.gd")

var tabs: TabContainer
var _title: Label
var _desc: Label
var _lab_base := "weed"
var _lab_adds: Array = ["", "", ""]
var _lab_qty := 5
var _dirty := false
var _filter: Dictionary = {}  ## {} = full docked menu; else {tabs: [names], title, contact}
var _leave_btn: Button
var runner: Control  ## station minigames overlay for hand-made batches

signal close_requested  ## "Leave" pressed while filtered (on a planet surface)
signal estate_enter_requested(estate_id: String)  ## "Go inside" on an estate you own
signal place_requested(station_id: String)  ## build menu: start placing this station
signal estate_changed  ## a building was removed; the estate interior has to be rebuilt


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(900, 540)
	panel.offset_left = -450
	panel.offset_right = 450
	panel.offset_top = -270
	panel.offset_bottom = 270
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = UI.label("", 26, UI.ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_leave_btn = UI.button("Undock [E]", func():
		if _filter.is_empty():
			EventBus.undock_requested.emit()
		else:
			close_requested.emit(), 140)
	head.add_child(_leave_btn)
	_desc = UI.label("", 15, UI.MUTED)
	v.add_child(_desc)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	runner = RunnerScript.new()
	add_child(runner)
	runner.closed.connect(func(): refresh())
	EventBus.game_event.connect(func(_k, _p): _dirty = true)
	visible = false


## filter: {} for the full docked menu, or {"tabs": ["Market"], "title": "Night Market", "contact": "okka"};
## "fence_only": true limits Deals to the fence.
func open(filter: Dictionary = {}) -> void:
	_filter = filter
	_leave_btn.text = "Undock [E]" if filter.is_empty() else "Leave [E]"
	visible = true
	_lab_qty = mini(_lab_qty, GameState.game.lab_capacity())
	refresh(true)


func close() -> void:
	runner.abort()
	visible = false


func _process(_delta: float) -> void:
	if visible and _dirty:
		refresh()


## Rebuilds all tabs. keep_tab=false resets to the first tab.
func refresh(reset_tab := false) -> void:
	_dirty = false
	var g = GameState.game
	if g == null or g.location == "":
		return
	var ld: Dictionary = g.loc_data()
	_title.text = _filter.get("title", ld.name)
	_desc.text = ld.get("desc", "") if _filter.is_empty() else "%s – %s" % [ld.name, ld.get("desc", "")]
	var current := 0 if reset_tab else tabs.current_tab
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	if _wants("Market"):
		_add_tab("Market", _build_market(g))
	if g.lab_here() and _wants("Lab"):
		_add_tab("Lab", _build_lab(g))
	if _wants("Deals"):
		_add_tab("Deals", _build_deals(g))
	if ld.get("shipyard", false) and _wants("Shipyard"):
		_add_tab("Shipyard", _build_shipyard(g))
	if ld.get("office", false) and _wants("Office"):
		_add_tab("Office", _build_office(g))
	# estate panels only exist as filtered panels (a door, the build menu, a placed station)
	if _filter.has("estate"):
		if _wants("Estate"):
			_add_tab("Estate", _build_estate(g))
		if _wants("Build"):
			_add_tab("Build", _build_build_menu(g))
		if _wants("Station"):
			_add_tab("Station", _build_station(g))
	tabs.current_tab = clampi(current, 0, tabs.get_tab_count() - 1)


func _wants(tab: String) -> bool:
	return _filter.is_empty() or tab in _filter.get("tabs", [])


func tab_names() -> Array:
	var r: Array = []
	for c in tabs.get_children():
		r.append(String(c.name))
	return r


func _add_tab(name: String, content: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	tabs.add_child(scroll)


func _grid(cols: int) -> GridContainer:
	var gr := GridContainer.new()
	gr.columns = cols
	gr.add_theme_constant_override("h_separation", 14)
	gr.add_theme_constant_override("v_separation", 6)
	return gr


# ---------------------------------------------------------------- market

func _build_market(g) -> Control:
	var v := VBoxContainer.new()
	v.add_child(UI.label("Cargo %d/%d · %d cr" % [g.cargo_used(), g.cargo_capacity(), g.credits], 16, UI.MUTED))
	var gr := _grid(6)
	for h in ["Item", "Price", "Owned", "", "", ""]:
		gr.add_child(UI.label(h, 15, UI.MUTED))
	var items: Array = []
	for r in g.data.raws:
		items.append(r)
	for a in g.data.additives:
		items.append(a)
	var any := false
	for item in items:
		var price: int = g.buy_price(item)
		if price < 0:
			continue
		any = true
		gr.add_child(Art.with_icon(item, UI.label(g.item_name(item))))
		gr.add_child(UI.label("%d cr" % price, 17, UI.GOLD))
		gr.add_child(UI.label(str(g.cargo.get(item, 0))))
		gr.add_child(UI.button("+1", func(): GameState.act(g.buy(item, 1)), 50))
		gr.add_child(UI.button("+5", func(): GameState.act(g.buy(item, mini(5, g.cargo_free()))), 50))
		gr.add_child(UI.button("Max", func():
			var n: int = mini(g.cargo_free(), g.credits / price)
			GameState.act(g.buy(item, n)), 60))
	v.add_child(gr if any else UI.label("Nothing for sale here.", 17, UI.MUTED))
	v.add_child(HSeparator.new())
	v.add_child(UI.label("Your hold", 18, UI.ACCENT))
	if g.cargo.is_empty():
		v.add_child(UI.label("Empty.", 16, UI.MUTED))
	for k in g.cargo:
		v.add_child(Art.with_icon(k, UI.label("%d × %s" % [g.cargo[k], g.item_name(k)], 16, UI.WARN if Mixing.is_product(k) else UI.TEXT)))
	return v


# ---------------------------------------------------------------- lab

func _build_lab(g) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UI.label("Hydro Rig Mk %d · %d units per batch · each unit needs 1 raw + 1 of every additive" % [g.upgrades.lab + 1, g.lab_capacity()], 15, UI.MUTED))
	var missing: Array = g.missing_stations(_lab_base, _chosen_additives())
	if not missing.is_empty():
		var names: Array = []
		for st in missing:
			names.append(g.data.stations[st].name)
		v.add_child(UI.label("This estate still needs: %s (build menu)." % ", ".join(PackedStringArray(names)), 15, UI.WARN))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var base_opt := OptionButton.new()
	var bases: Array = g.data.bases.keys()
	for b in bases:
		base_opt.add_item("T%d %s (from %s)" % [int(g.data.bases[b].get("tier", 1)), g.data.bases[b].name, g.data.raws[g.data.bases[b].raw].name])
	base_opt.selected = bases.find(_lab_base)
	base_opt.item_selected.connect(func(i: int):
		_lab_base = bases[i]
		refresh())
	row.add_child(base_opt)
	var adds: Array = [""] + g.data.additives.keys()
	for slot in 3:
		var o := OptionButton.new()
		for a in adds:
			o.add_item("— none —" if a == "" else "+ " + g.data.additives[a].name)
		o.selected = adds.find(_lab_adds[slot])
		o.item_selected.connect(func(i: int):
			_lab_adds[slot] = adds[i]
			refresh())
		row.add_child(o)
	var additives := _chosen_additives()
	var traits: Array = Mixing.traits_for(g.data, _lab_base, additives)
	var product := Mixing.key(_lab_base, traits)
	var preview := RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.fit_content = true
	preview.scroll_active = false
	var parts: Array = []
	for t in traits:
		parts.append("[color=%s]%s[/color]" % [g.data.traits[t].color, g.data.traits[t].name])
	preview.text = "Result: [b]%s[/b]  %s   ·  base value [color=#ffd166]%d cr[/color]/unit" % [
		g.data.bases[_lab_base].name, ", ".join(PackedStringArray(parts)), int(Mixing.value(g.data, product))]
	v.add_child(preview)
	var q := HBoxContainer.new()
	q.add_theme_constant_override("separation", 10)
	v.add_child(q)
	q.add_child(UI.label("Units:"))
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = g.lab_capacity()
	spin.value = clampi(_lab_qty, 1, g.lab_capacity())
	spin.value_changed.connect(func(x: float): _lab_qty = int(x))
	q.add_child(spin)
	var need: Array = ["%d %s (have %d)" % [_lab_qty, g.item_name(g.data.bases[_lab_base].raw), g.cargo.get(g.data.bases[_lab_base].raw, 0)]]
	for a in additives:
		need.append("%d %s (have %d)" % [_lab_qty, g.item_name(a), g.cargo.get(a, 0)])
	q.add_child(UI.label("Needs: " + ", ".join(PackedStringArray(need)), 15, UI.MUTED))
	var st_names: Array = []
	for id in Production.stations_for(g.data, _lab_base, additives):
		st_names.append(g.data.stations[id].name)
	var st_label := UI.label("Stations: " + " → ".join(PackedStringArray(st_names)) + ". By hand you set yield, quality grade and heat; a quick batch is always Standard.", 15, UI.MUTED)
	st_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st_label.custom_minimum_size.x = 400
	v.add_child(st_label)
	var b_row := HBoxContainer.new()
	b_row.add_theme_constant_override("separation", 10)
	v.add_child(b_row)
	b_row.add_child(UI.button("Cook by hand", func():
		var r: Dictionary = runner.start(_lab_base, additives, _lab_qty)
		if not r.ok:
			GameState.act(r), 160))
	b_row.add_child(UI.button("Quick batch (Standard)", func(): GameState.act(g.start_batch(_lab_base, additives, _lab_qty)), 220))
	v.add_child(HSeparator.new())
	v.add_child(UI.label("Queue", 18, UI.ACCENT))
	if g.lab_queue.is_empty():
		v.add_child(UI.label("Idle.", 16, UI.MUTED))
	for job in g.lab_queue:
		var h := HBoxContainer.new()
		h.add_child(UI.label("%d × %s" % [job.qty, g.item_name(job.product)], 16))
		var b := UI.bar(UI.ACCENT)
		b.value = (1.0 - job.remaining / job.total) * 100.0
		h.add_child(b)
		v.add_child(h)
	v.add_child(UI.label("Stash", 18, UI.ACCENT))
	if g.stash.is_empty():
		v.add_child(UI.label("Empty.", 16, UI.MUTED))
	for k in g.stash:
		v.add_child(UI.label("%d × %s" % [g.stash[k], g.item_name(k)], 16))
	v.add_child(UI.button("Load stash into cargo", func(): GameState.act(g.collect_stash()), 220))
	return v


func _chosen_additives() -> Array:
	var r: Array = []
	for a in _lab_adds:
		if a != "":
			r.append(a)
	return r


# ---------------------------------------------------------------- deals

func _build_deals(g) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var products: Array = []
	for k in g.cargo:
		if Mixing.is_product(k):
			products.append(k)
	v.add_child(UI.label("Selling here adds %.1f heat per unit, times the drug's strength (Weed ×1 … Fentanyl ×%.1f)." % [float(g.loc_data().heat_per_unit), g.heat_mult("fentanyl")], 15, UI.MUTED))
	if products.is_empty():
		v.add_child(UI.label("You carry no product. Cook some at the Mireth lab.", 16, UI.MUTED))
	var buyers: Array = []
	var only: String = _filter.get("contact", "")
	var fence_only: bool = _filter.get("fence_only", false)
	for c in g.contacts_at():
		if not fence_only and (only == "" or c.id == only):
			buyers.append(c)
	if g.loc_data().get("fence", false) and only == "":
		buyers.append({"id": "", "name": "The Fence", "likes": "", "max_units": 999})
	if buyers.is_empty():
		v.add_child(UI.label("Nobody here deals.", 16, UI.MUTED))
	for c in buyers:
		var box := VBoxContainer.new()
		var head := "%s" % c.name
		if c.likes != "":
			head += "  · loves %s · takes up to %d" % [g.data.traits[c.likes].name, c.max_units]
		else:
			head += "  · buys anything at %d%% value" % int(float(g.data.market.fence_ratio) * 100.0)
		var ready: bool = c.id == "" or g.contact_ready(c.id)
		if not ready:
			head += "  · back in %ds" % int(float(g.contact_ready_at[c.id]) - g.total_time)
		box.add_child(UI.label(head, 17, UI.ACCENT if ready else UI.MUTED))
		for k in products:
			var p := Mixing.parse_key(k)
			if not g.demand.get(g.location, {}).has(p.base):
				continue
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			var price: int = g.sell_price(k, c.id)
			h.add_child(Art.with_icon(k, UI.label("%d × %s" % [g.cargo[k], g.item_name(k)], 16)))
			h.add_child(UI.label("%d cr/unit" % price, 16, UI.GOLD))
			var n: int = mini(int(g.cargo[k]), int(c.max_units))
			var b := UI.button("Sell %d" % n, func(): GameState.act(g.sell(k, n, c.id)), 90)
			b.disabled = not ready
			h.add_child(b)
			box.add_child(h)
		v.add_child(box)
		v.add_child(HSeparator.new())
	var dem: Array = []
	for b in g.demand.get(g.location, {}):
		dem.append("%s %d%%" % [g.data.bases[b].name, int(g.demand[g.location][b] * 100.0)])
	v.add_child(UI.label("Local demand: " + ", ".join(PackedStringArray(dem)), 15, UI.MUTED))
	return v


# ---------------------------------------------------------------- estates

func _build_estate(g) -> Control:
	var id: String = _filter.estate
	var e: Dictionary = g.data.estates[id]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.label(e.desc, 16))
	v.add_child(UI.label("Floor space %d × %d cells. Place production stations inside, hire workers later." % [int(e.size[0]), int(e.size[1])], 15, UI.MUTED))
	if g.estate_owned(id):
		v.add_child(UI.label("Yours. %d station(s) set up." % g.estates[id].buildings.size(), 17, UI.ACCENT))
		v.add_child(UI.button("Go inside", func(): estate_enter_requested.emit(id), 160))
	else:
		v.add_child(UI.label("For sale: %d cr" % int(e.price), 19, UI.GOLD))
		var b := UI.button("Buy for %d cr" % int(e.price), func():
			if GameState.act(g.buy_estate(id)).ok:
				estate_enter_requested.emit(id), 200)
		b.disabled = g.credits < int(e.price)
		v.add_child(b)
	return v


func _build_build_menu(g) -> Control:
	var gr := _grid(4)
	for h in ["Station", "Cost", "Size", ""]:
		gr.add_child(UI.label(h, 15, UI.MUTED))
	for k in g.data.buildables:
		var bd: Dictionary = g.data.buildables[k]
		var st: Dictionary = g.data.stations[k]
		var name_l := UI.label(st.name, 17)
		name_l.tooltip_text = st.get("hint", "")
		gr.add_child(name_l)
		gr.add_child(UI.label("%d cr" % int(bd.cost), 16, UI.GOLD))
		gr.add_child(UI.label("%d × %d · %s" % [int(bd.size[0]), int(bd.size[1]), st.affects], 15, UI.MUTED))
		var b := UI.button("Place", func(): place_requested.emit(k), 80)
		b.disabled = g.credits < int(bd.cost)
		gr.add_child(b)
	var v := VBoxContainer.new()
	v.add_child(gr)
	v.add_child(UI.label("Pick a station, then walk to a free spot: it goes on the cells in front of you. Cooking with your own stations comes next.", 14, UI.MUTED))
	return v


func _build_station(g) -> Control:
	var id: String = _filter.estate
	var i: int = _filter.index
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	if i >= g.estates[id].buildings.size():
		return v
	var b: Dictionary = g.estates[id].buildings[i]
	var st: Dictionary = g.data.stations[b.id]
	v.add_child(UI.label("%s · improves %s" % [st.name, st.affects], 17, UI.ACCENT))
	v.add_child(UI.label(st.get("hint", ""), 15, UI.MUTED))
	var refund := int(round(int(g.data.buildables[b.id].cost) * float(g.data.estate_refund)))
	v.add_child(UI.button("Take down (+%d cr)" % refund, func():
		if GameState.act(g.remove_building(id, i)).ok:
			estate_changed.emit(), 200))
	return v


# ---------------------------------------------------------------- shipyard / office

func _build_shipyard(g) -> Control:
	var gr := _grid(4)
	for k in g.data.upgrades:
		var u: Dictionary = g.data.upgrades[k]
		var lvl: int = g.upgrades[k]
		gr.add_child(Art.with_icon("up_" + k, UI.label("%s Mk %d" % [u.name, lvl + 1], 17)))
		gr.add_child(UI.label(_upgrade_value(k, u.levels[lvl]), 16, UI.MUTED))
		var cost: int = g.upgrade_cost(k)
		if cost < 0:
			gr.add_child(UI.label("max", 16, UI.MUTED))
			gr.add_child(Control.new())
		else:
			gr.add_child(UI.label("→ %s for %d cr" % [_upgrade_value(k, u.levels[lvl + 1]), cost], 16, UI.GOLD))
			var b := UI.button("Buy", func(): GameState.act(g.buy_upgrade(k)), 70)
			b.disabled = cost > g.credits
			gr.add_child(b)
	return gr


static func _upgrade_value(key: String, v) -> String:
	match key:
		"cargo": return "%d slots" % int(v)
		"engine": return "%d%% thrust" % int(float(v) * 100.0)
		"stealth": return "-%d%% scan range" % int(float(v) * 100.0)
		"lab": return "%d units/batch" % int(v)
	return str(v)


func _build_office(g) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.label("Ouroboros Consortium – debt office", 19, UI.ACCENT))
	v.add_child(UI.label("You owe %d cr. Due by the end of day %d (today is day %d)." % [g.debt, g.debt_due_day, g.day], 16))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	for amt in [250, 1000]:
		h.add_child(UI.button("Pay %d" % amt, func(): GameState.act(g.pay_debt(amt)), 110))
	h.add_child(UI.button("Pay all I can", func(): GameState.act(g.pay_debt(g.credits)), 140))
	v.add_child(h)
	v.add_child(HSeparator.new())
	v.add_child(UI.label("The Fixer – makes your file disappear", 19, UI.ACCENT))
	v.add_child(UI.label("Heat %d. %d cr per heat point." % [int(g.heat), int(g.data.heat.bribe_credits_per_heat)], 16))
	var h2 := HBoxContainer.new()
	h2.add_theme_constant_override("separation", 10)
	h2.add_child(UI.button("-10 heat (%d cr)" % g.bribe_cost(10), func(): GameState.act(g.bribe(10)), 170))
	h2.add_child(UI.button("Clear all (%d cr)" % g.bribe_cost(g.heat), func(): GameState.act(g.bribe(g.heat)), 170))
	v.add_child(h2)
	v.add_child(HSeparator.new())
	v.add_child(UI.label("Run stats: earned %d cr · sold %d units · %d batches · busted %d×" % [g.stats.earned, g.stats.units_sold, g.stats.batches, g.stats.busts], 15, UI.MUTED))
	return v
