extends Control
## Docked menu. Tabs depend on what the location offers: Market, Lab, Deals, Shipyard, Office.
## On a planet surface it opens filtered to one building or person (see open()), and its button closes the panel
## instead of undocking.
## Rebuilds its content from the core Game state after every game event, so it never caches stale numbers.

const UI = preload("res://scripts/ui/ui_theme.gd")
const Mixing = preload("res://scripts/core/mixing.gd")
const Art = preload("res://scripts/core/art.gd")
const Production = preload("res://scripts/core/production.gd")
const People = preload("res://scripts/core/people.gd")
const Deals = preload("res://scripts/core/deals.gd")
const Bench = preload("res://scripts/core/bench.gd")
const ShipPreview = preload("res://scripts/ui/ship_preview.gd")
const OfficialsApp = preload("res://scripts/ui/phone/apps/officials_app.gd")
const SpaceCombat = preload("res://scripts/core/spacecombat.gd")

var tabs: TabContainer
var _title: Label
var _desc: Label
var _dirty := false
var _filter: Dictionary = {}  ## {} = full docked menu; else {tabs: [names], title, contact}
var _leave_btn: Button

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
	_title = UI.label("", 26, UI.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_leave_btn = UI.button("Undock", func():
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
	EventBus.game_event.connect(func(_k, _p): _dirty = true)
	visible = false


## filter: {} for the full docked menu, or {"tabs": ["Market"], "title": "Night Market", "contact": "okka"};
## "fence_only": true limits Deals to the fence.
func open(filter: Dictionary = {}) -> void:
	_filter = filter
	# undock goes through ship_dock, leaving a surface counter through interact (see main.gd)
	_leave_btn.text = "Undock [%s]" % Settings.key_label("ship_dock") if filter.is_empty() else "Leave [%s]" % Settings.key_label("interact")
	visible = true
	refresh(true)


func close() -> void:
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
	if _wants("Deals"):
		_add_tab("Deals", _build_deals(g))
	if ld.get("shipyard", false) and _wants("Shipyard"):
		_add_tab("Shipyard", _build_shipyard(g))
	if ld.get("office", false) and _wants("Office"):
		_add_tab("Office", _build_office(g))
	# stations without a surface: the ship's cargo bay is entered from here
	if _filter.is_empty():
		_add_tab("Cargo Bay", _build_estate(g))
	# estate panels only exist as filtered panels (a door, the build menu, a placed station)
	if _filter.has("estate"):
		if _wants("Estate"):
			_add_tab("Estate", _build_estate(g))
		if _wants("Build"):
			_add_tab("Build", _build_build_menu(g))
		if _wants("Stash"):
			_add_tab("Stash", _build_stash(g))
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

## Stash crate inside an estate (G2): the cook queue, the stash and loading it into the hold. Production itself
## happens at the stations (bench_ui.gd), there is no lab menu any more.
func _build_stash(g) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var t: Dictionary = Bench.tray(g)
	if not t.is_empty():
		var nxt: String = Bench.next_station(g, t)
		v.add_child(UI.label("On your tray: %d × %s, next stop %s." % [t.qty, g.data.bases[t.base].name,
			g.data.stations[nxt].name if nxt != "" else "done"], 16, UI.GOLD))
	v.add_child(UI.heading("Cooking"))
	if g.lab_queue.is_empty():
		v.add_child(UI.label("Nothing in the cooker. Start a batch at the Trim Table or the Precursor Scale.", 15, UI.MUTED))
	for job in g.lab_queue:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(Art.with_icon(job.product, UI.label("%d × %s" % [job.qty, g.item_name(job.product)], 16)))
		var b := UI.bar(UI.ACCENT)
		b.value = (1.0 - job.remaining / job.total) * 100.0
		b.tooltip_text = "%d s left" % int(ceil(job.remaining))
		h.add_child(b)
		v.add_child(h)
	v.add_child(UI.heading("Stash"))
	if g.stash.is_empty():
		v.add_child(UI.label("Empty.", 15, UI.MUTED))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for k in g.stash:
		var c := UI.card(Art.with_icon(k, UI.label("%d × %s" % [g.stash[k], g.item_name(k)], 16, UI.WARN if Mixing.is_product(k) else UI.TEXT)))
		c.custom_minimum_size.x = 250
		c.tooltip_text = "Product: worth about %d cr per unit at Standard demand." % int(Mixing.value(g.data, k)) if Mixing.is_product(k) else g.item_name(k)
		grid.add_child(c)
	var load := UI.accent_button("Load stash into the hold", func(): GameState.act(g.collect_stash()), 260)
	load.name = "LoadStash"
	load.disabled = g.stash.is_empty() and g.estate_stock.get(g.inside_estate, {}).is_empty()
	v.add_child(load)
	v.add_child(UI.label("Hold %d/%d" % [g.cargo_used(), g.cargo_capacity()], 14, UI.MUTED))
	return v


func _add_agreed_deal(g, box: VBoxContainer, c: Dictionary) -> void:
	var o: Dictionary = Deals.open_for(g, c.id)
	if o.is_empty() or o.state != "accepted":
		return
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(UI.label("Agreed: %d × %s for %d cr each" % [o.qty, g.data.bases[o.base].name, o.price], 16, UI.GOLD))
	var have: Array = Deals.matching_products(g, o)
	if have.is_empty():
		h.add_child(UI.label("(you don't carry enough)", 15, UI.WARN))
	for k in have:
		var b := UI.button("Hand over %s" % g.item_name(k), func(): GameState.act(Deals.fulfill(g, int(o.id), k)), 120)
		b.name = "HandOver"
		h.add_child(b)
	box.add_child(h)


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
			head += "  · loves %s · takes up to %d · %d cr left today" % [g.data.traits[c.likes].name, People.max_units(g, c.id), People.budget_left(g, c.id)]
		else:
			head += "  · buys anything at %d%% value" % int(float(g.data.market.fence_ratio) * 100.0)
		var ready: bool = c.id == "" or g.contact_ready(c.id)
		if not ready:
			head += "  · back in %ds" % int(float(g.contact_ready_at[c.id]) - g.total_time)
		box.add_child(UI.label(head, 17, UI.ACCENT if ready else UI.MUTED))
		if c.id != "":
			_add_agreed_deal(g, box, c)
		for k in products:
			var p := Mixing.parse_key(k)
			if not g.demand.get(g.location, {}).has(p.base):
				continue
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			var price: int = g.sell_price(k, c.id)
			h.add_child(Art.with_icon(k, UI.label("%d × %s" % [g.cargo[k], g.item_name(k)], 16)))
			h.add_child(UI.label("%d cr/unit" % price, 16, UI.GOLD))
			var n: int = mini(int(g.cargo[k]), int(c.max_units) if c.id == "" else People.units_wanted(g, c.id, k))
			var b := UI.button("Sell %d" % n if n > 0 else "Too pricey", func(): GameState.act(g.sell(k, n, c.id)), 90)
			b.disabled = not ready or n <= 0
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
	var id: String = _filter.get("estate", g.SHIP_BAY)
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
		var kit_n := int(g.kits.get(k, 0))
		gr.add_child(UI.label(("Kit ×%d" % kit_n) if kit_n > 0 else "%d cr" % int(bd.cost), 16, UI.ACCENT if kit_n > 0 else UI.GOLD))
		gr.add_child(UI.label("%d × %d · %s" % [int(bd.size[0]), int(bd.size[1]), st.affects], 15, UI.MUTED))
		var b := UI.button("Place", func(): place_requested.emit(k), 80)
		b.disabled = g.credits < int(bd.cost) and kit_n <= 0
		gr.add_child(b)
	var v := VBoxContainer.new()
	v.add_child(gr)
	v.add_child(UI.label("Pick a station, then walk to a free spot: it goes on the cells in front of you. Station kits ordered in the phone's Orders app are placed for free.", 14, UI.MUTED))
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
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	h.add_child(ShipPreview.new(g.upgrades))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.add_child(gr)
	right.add_child(HSeparator.new())
	right.add_child(_build_mechanic(g))
	h.add_child(right)
	return h


## Mechanic: hull repairs and missile restocks (the weapon, shield and armour modules are in the grid above).
func _build_mechanic(g) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(UI.label("Mechanic", 19, UI.ACCENT))
	v.add_child(UI.label("Hull %d / %d · shield %d · missiles %d / %d · pirates downed %d" % [int(g.combat.hull), int(SpaceCombat.max_hull(g)),
		int(SpaceCombat.max_shield(g)), int(g.combat.missiles), SpaceCombat.missile_cap(g), int(g.combat.kills)], 15, UI.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var rep := UI.button("Repair hull (%d cr)" % SpaceCombat.repair_cost(g), func(): GameState.act(SpaceCombat.repair(g)), 190)
	rep.disabled = SpaceCombat.repair_cost(g) <= 0 or SpaceCombat.repair_cost(g) > g.credits
	row.add_child(rep)
	var res := UI.button("Restock missiles (%d cr)" % SpaceCombat.restock_cost(g), func(): GameState.act(SpaceCombat.restock(g)), 220)
	res.disabled = not SpaceCombat.has_missiles(g) or SpaceCombat.restock_cost(g) <= 0 or SpaceCombat.restock_cost(g) > g.credits
	row.add_child(res)
	v.add_child(row)
	return v


static func _upgrade_value(key: String, v) -> String:
	match key:
		"cargo": return "%d slots" % int(v)
		"engine": return "%d%% thrust" % int(float(v) * 100.0)
		"stealth": return "-%d%% scan range" % int(float(v) * 100.0)
		"lab": return "%d units/batch" % int(v)
		"laser": return "%d damage/shot" % int(v)
		"missile": return "no pods" if int(v) == 0 else "%d missiles" % int(v)
		"shield": return "no shield" if int(v) == 0 else "%d shield" % int(v)
		"hull": return "%d hull" % int(v)
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
	_add_fixers(v, g)
	v.add_child(HSeparator.new())
	v.add_child(UI.label("Run stats: earned %d cr · sold %d units · %d batches · busted %d×" % [g.stats.earned, g.stats.units_sold, g.stats.batches, g.stats.busts], 15, UI.MUTED))
	return v


## Office replacement for the old fixer: heat and wanted status plus the officials of this system (recruit / favours).
## The same list lives in the Fixers app on the phone.
func _add_fixers(v: VBoxContainer, g) -> void:
	v.add_child(UI.label("Officials – everyone has a price", 19, UI.ACCENT))
	v.add_child(OfficialsApp.status_block(g))
	for o in People.officials_in(g, g.system):
		if not People.official_state(g, o.id).known:
			continue
		v.add_child(UI.label("%s · %s" % [o.name, g.data.corruption.roles[o.role].name], 15))
		v.add_child(OfficialsApp.actions(g, o.id))
