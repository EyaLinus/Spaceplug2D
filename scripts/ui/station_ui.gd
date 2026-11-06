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
const Products = preload("res://scripts/core/products.gd")
const Bench = preload("res://scripts/core/bench.gd")
const Vault = preload("res://scripts/core/vault.gd")
const ShipPreview = preload("res://scripts/ui/ship_preview.gd")
const OfficialsApp = preload("res://scripts/ui/phone/apps/officials_app.gd")
const SpaceCombat = preload("res://scripts/core/spacecombat.gd")
const Style = preload("res://scripts/core/style.gd")
const Grow = preload("res://scripts/core/grow.gd")
const Galaxy = preload("res://scripts/core/galaxy.gd")
const Raids = preload("res://scripts/core/raids.gd")
const MachinesUI = preload("res://scripts/ui/machines_ui.gd")

var tabs: TabContainer
var _title: Label
var _desc: Label
var _dirty := false
var _basket: Dictionary = {}  ## market shopping basket: item -> units (cleared when the panel opens)
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
	_basket.clear()
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
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	left.add_child(UI.heading("For sale"))
	left.add_child(UI.label("Click adds 1 to the basket, Shift+click 5. Hover for what it is good for.", 14, UI.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)
	var items: Array = []
	for r in g.data.raws:
		items.append(r)
	for a in g.data.additives:
		items.append(a)
	var compare := {}  ## K3: item -> offers elsewhere (cheapest first) for the price-compare tooltip
	for row in Galaxy.buy_table(g):
		compare[str(row.get("item", ""))] = row.offers
	for item in items:
		var price: int = g.buy_price(item)
		if price < 0:
			continue
		var card := Button.new()
		card.name = "Item_" + item
		card.theme_type_variation = "CardButton"
		card.custom_minimum_size = Vector2(250, 62)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.icon = Art.icon_for(item)
		card.text = "%s\n%d cr  ·  have %d" % [g.item_name(item), price, int(g.cargo.get(item, 0))]
		card.tooltip_text = UI.item_tip(g, item) + _compare_tip(g, price, compare.get(item, []))
		card.pressed.connect(func():
			AudioManager.play("click")
			_basket_add(g, item, 5 if Input.is_key_pressed(KEY_SHIFT) else 1))
		grid.add_child(card)
	if grid.get_child_count() == 0:
		left.add_child(UI.label("Nothing for sale here.", 17, UI.MUTED))
	left.add_child(UI.heading("Your hold %d/%d" % [g.cargo_used(), g.cargo_capacity()], 16))
	left.add_child(_hold_chips(g))
	h.add_child(_basket_panel(g))
	return h


## Adds up to `n` of `item` to the shopping basket, as far as credits and hold space allow.
func _basket_add(g, item: String, n: int) -> void:
	var total := _basket_total(g)
	var units := 0
	for k in _basket:
		units += int(_basket[k])
	var price: int = g.buy_price(item)
	var can := mini(n, mini(g.cargo_free() - units, (g.credits - total) / maxi(price, 1)))
	if can <= 0:
		AudioManager.play("error")
		EventBus.toast.emit("No room in the hold." if g.cargo_free() - units <= 0 else "Not enough credits.", false)
		return
	_basket[item] = int(_basket.get(item, 0)) + can
	refresh()


func _basket_total(g) -> int:
	var t := 0
	for k in _basket:
		t += int(_basket[k]) * maxi(g.buy_price(k), 0)
	return t


func _basket_panel(g) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size.x = 300
	v.add_child(UI.heading("Basket"))
	var units := 0
	if _basket.is_empty():
		v.add_child(UI.label("Empty. Click the goods on the left.", 15, UI.MUTED))
	for k in _basket.keys():
		units += int(_basket[k])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var l := Art.with_icon(k, UI.label("%d × %s" % [_basket[k], g.item_name(k)], 15))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UI.label("%d cr" % (int(_basket[k]) * g.buy_price(k)), 15, UI.GOLD))
		row.add_child(UI.button("−", func():
			_basket[k] = int(_basket[k]) - 1
			if int(_basket[k]) <= 0:
				_basket.erase(k)
			refresh(), 34))
		row.add_child(UI.button("+", func(): _basket_add(g, k, 1), 34))
		v.add_child(row)
	v.add_child(HSeparator.new())
	var total := _basket_total(g)
	v.add_child(UI.label("Total  %d cr" % total, 19, UI.GOLD))
	v.add_child(UI.label("Credits after: %d cr" % (g.credits - total), 14, UI.MUTED))
	v.add_child(UI.label("Hold after: %d / %d" % [g.cargo_used() + units, g.cargo_capacity()], 14, UI.MUTED))
	var buy := UI.accent_button("Buy  (%d cr)" % total, func(): _checkout(g))
	buy.name = "Checkout"
	buy.disabled = _basket.is_empty() or total > g.credits or units > g.cargo_free()
	v.add_child(buy)
	var clear := UI.button("Clear basket", func():
		_basket.clear()
		refresh())
	clear.disabled = _basket.is_empty()
	v.add_child(clear)
	return UI.card(v, true)


func _checkout(g) -> void:
	var bought := 0
	for k in _basket.keys():
		var r: Dictionary = g.buy(k, int(_basket[k]))
		if not r.ok:
			GameState.act(r)
			break
		bought += int(_basket[k])
		_basket.erase(k)
	if bought > 0:
		AudioManager.play("buy")
		EventBus.toast.emit("Bought %d units." % bought, true)
	refresh()


## Small icon chips of everything in the hold (products in red: they are what the police look for).
func _hold_chips(g) -> Control:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	if g.cargo.is_empty():
		f.add_child(UI.label("Empty.", 15, UI.MUTED))
	for k in g.cargo:
		var c := UI.card(Art.with_icon(k, UI.label("%d %s" % [g.cargo[k], g.item_name(k)], 14, UI.WARN if Mixing.is_product(k) else UI.TEXT)))
		c.tooltip_text = UI.item_tip(g, k)
		f.add_child(c)
	return f


# ---------------------------------------------------------------- lab

## Stash crate inside an estate (G2): the cook queue, the stash and loading it into the hold. Production itself
## happens at the stations (bench_ui.gd), there is no lab menu any more.
func _build_stash(g) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var t: Dictionary = Bench.tray(g)
	if not t.is_empty():
		var nxt: String = Bench.next_station(g, t)
		var tray_l := UI.label("On your tray: %d × %s, next stop %s." % [t.qty, g.data.bases[t.base].name,
			g.data.stations[nxt].name if nxt != "" else "done"], 16, UI.GOLD)
		v.add_child(Art.with_icon("st_" + nxt, tray_l) if nxt != "" else tray_l)
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
	var raid_line: String = Raids.status_text(g, g.inside_estate)
	if raid_line != "":
		v.add_child(UI.label(raid_line, 14, UI.WARN))
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
	_build_vault(g, v)
	return v


## Hidden crate (vault.gd): product in here survives a bust or a knock-out.
func _build_vault(g, v: VBoxContainer) -> void:
	v.add_child(UI.heading("Hidden crate"))
	var info := UI.label("%d/%d units, safe from busts and knock-outs." % [Vault.used(g), Vault.capacity(g)], 15, UI.MUTED)
	info.name = "VaultInfo"
	v.add_child(info)
	for k in g.cargo.keys():
		if not Mixing.is_product(k):
			continue
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(Art.with_icon(k, UI.label("%d × %s" % [g.cargo[k], g.item_name(k)], 15)))
		var key: String = k
		var b := UI.button("Hide all", func(): GameState.act(Vault.deposit(g, key, int(g.cargo.get(key, 0)))), 110)
		b.tooltip_text = "Move this product from the hold into the hidden crate."
		h.add_child(b)
		v.add_child(h)
	for k in g.vault.items.keys():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(Art.with_icon(k, UI.label("%d × %s (crate)" % [g.vault.items[k], g.item_name(k)], 15, UI.GOLD)))
		var key: String = k
		var b := UI.button("Take all", func(): GameState.act(Vault.withdraw(g, key, int(g.vault.items.get(key, 0)))), 110)
		b.tooltip_text = "Move this product from the crate back into the hold, as far as it fits."
		h.add_child(b)
		v.add_child(h)
	var cost := Vault.upgrade_cost(g)
	if cost >= 0:
		var up := UI.button("Bigger crate (%d cr)" % cost, func(): GameState.act(Vault.upgrade(g)), 220)
		up.name = "VaultUpgrade"
		up.disabled = g.credits < cost
		up.tooltip_text = "Add %d units of hidden room." % int(g.data.vault.cap_per_tier)
		v.add_child(up)


func _add_agreed_deal(g, box: VBoxContainer, c: Dictionary) -> void:
	var o: Dictionary = Deals.open_for(g, c.id)
	if o.is_empty() or o.state != "accepted":
		return
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var when := (" · meet %s" % Deals.clock_text(g, float(o.meet_at))) if float(o.get("meet_at", 0.0)) > 0.0 else ""
	h.add_child(UI.label("Agreed: %d × %s for %d cr each%s" % [o.qty, Deals.want_name(g, o), o.price, when], 16, UI.GOLD))
	if Deals.meet_phase(g, o) == "early":
		h.add_child(UI.label("(too early)", 15, UI.MUTED))
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
		box.add_child(UI.label(head, 17, UI.GOLD if ready else UI.MUTED))
		if c.id != "":
			_add_agreed_deal(g, box, c)
		for k in products:
			var p := Mixing.parse_key(k)
			if not g.demand.get(g.location, {}).has(p.base):
				continue
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			var price: int = g.unit_price(k, c.id)
			h.add_child(Art.with_icon(k, UI.label("%d × %s" % [g.cargo[k], g.item_name(k)], 16)))
			var pl := UI.label("%d cr/unit" % price if price > 0 else "won't pay %d" % Products.asking(g, k), 16, UI.GOLD if price > 0 else UI.WARN)
			if c.id != "":
				pl.tooltip_text = "Your price: %s · they offer %d, pay up to %d" % ["market" if Products.asking(g, k) < 0 else "%d cr" % Products.asking(g, k), g.sell_price(k, c.id), Products.ceiling(g, k, c.id)]
			h.add_child(pl)
			var n: int = mini(int(g.cargo[k]), int(c.max_units) if c.id == "" else People.units_wanted(g, c.id, k))
			var b := UI.accent_button("Sell %d" % n if n > 0 else "Too pricey", func(): GameState.act(g.sell(k, n, c.id)), 110)
			b.tooltip_text = "%d × %d cr = %d cr" % [n, price, n * price]
			b.disabled = not ready or n <= 0
			h.add_child(b)
			box.add_child(h)
		v.add_child(UI.card(box))
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
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for k in g.data.buildables:
		var bd: Dictionary = g.data.buildables[k]
		var st: Dictionary = g.data.stations[k]
		if st.get("machine", false):
			continue  # shown in the Machines section below (machines_ui.gd)
		var kit_n := int(g.kits.get(k, 0))
		var card := Button.new()
		card.name = "Build_" + k
		card.theme_type_variation = "CardButton"
		card.custom_minimum_size = Vector2(270, 74)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.icon = Art.tex("stations/%s.png" % k)
		card.add_theme_constant_override("icon_max_width", 64)
		card.text = "%s\n%s · %d×%d · %s" % [st.name, ("kit ×%d" % kit_n) if kit_n > 0 else "%d cr" % int(bd.cost),
			int(bd.size[0]), int(bd.size[1]), st.affects]
		card.tooltip_text = "%s\nImproves %s. %s" % [st.get("hint", ""), st.affects,
			"Lines: " + ", ".join(PackedStringArray(st.get("bases", g.data.bases.keys()).map(func(b): return g.data.bases[b].name)))]
		card.disabled = g.credits < int(bd.cost) and kit_n <= 0
		card.pressed.connect(func():
			AudioManager.play("click")
			place_requested.emit(k))
		grid.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UI.heading("Stations"))
	v.add_child(grid)
	var est: String = _filter.get("estate", "")
	if g.estates.has(est):
		v.add_child(_build_grow_trays(g, est))
	v.add_child(MachinesUI.section(g, func(k): place_requested.emit(k)))
	v.add_child(UI.label("Pick a station, then walk to a free spot: it goes on the cells in front of you. Station kits ordered in the phone's Orders app are placed for free.", 14, UI.MUTED))
	return v


## Grow trays of the estate: build one, plant a raw from the hold, water it on growing days, harvest into the stash.
func _build_grow_trays(g, est: String) -> Control:
	var v := VBoxContainer.new()
	v.name = "GrowTrays"
	v.add_theme_constant_override("separation", 6)
	v.add_child(UI.heading("Grow trays"))
	var list: Array = Grow.trays(g, est)
	for i in list.size():
		var t: Dictionary = list[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		if t.raw == "":
			row.add_child(UI.label("Tray %d: empty" % (i + 1), 15, UI.MUTED))
			for raw in Grow.crops(g):
				var need := int(Grow.cfg(g).get("seed_qty", 1))
				var pb := UI.button("Plant " + g.data.raws[raw].name, func(): GameState.act(Grow.plant(g, est, i, raw)))
				pb.name = "GrowPlant_%d_%s" % [i, raw]
				pb.tooltip_text = "Takes %d %s from your hold. Grows in %d days." % [need, g.data.raws[raw].name, int(Grow.crops(g)[raw].days)]
				pb.disabled = int(g.cargo.get(raw, 0)) < need
				row.add_child(pb)
		else:
			var ripe: bool = Grow.is_ripe(g, t)
			row.add_child(UI.label("Tray %d: %s, %s" % [i + 1, g.data.raws[t.raw].name,
				("ripe, %d units (%s)" % [Grow.expected_yield(g, t), Grow.grade(Grow.quality(g, t))]) if ripe else "%d day(s) to go" % Grow.days_left(g, t)], 15))
			if ripe:
				var hb := UI.button("Harvest", func(): GameState.act(Grow.harvest(g, est, i)))
				hb.name = "GrowHarvest_%d" % i
				hb.tooltip_text = "Moves the crop into your stash; collect it at the lab."
				row.add_child(hb)
			else:
				var wb := UI.button("Water", func(): GameState.act(Grow.water(g, est, i)))
				wb.name = "GrowWater_%d" % i
				wb.tooltip_text = "Once a day. Quality is the share of growth days you watered; it scales the yield."
				wb.disabled = (t.watered as Array).has(g.day)
				row.add_child(wb)
		v.add_child(row)
	var add := UI.button("Build grow tray (%d cr)" % int(Grow.cfg(g).get("tray_cost", 0)), func(): GameState.act(Grow.build_tray(g, est)))
	add.name = "GrowBuild"
	add.tooltip_text = "Adds a tray (max %d per estate). Plant raws, water daily, harvest into the stash." % Grow.max_trays(g)
	add.disabled = list.size() >= Grow.max_trays(g) or g.credits < int(Grow.cfg(g).get("tray_cost", 0))
	v.add_child(add)
	return v


# ---------------------------------------------------------------- shipyard / office

func _build_shipyard(g) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for k in g.data.upgrades:
		var u: Dictionary = g.data.upgrades[k]
		var lvl: int = g.upgrades[k]
		var cost: int = g.upgrade_cost(k)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.custom_minimum_size.x = 270
		v.add_child(Art.with_icon("up_" + k, UI.label("%s  Mk %d" % [u.name, lvl + 1], 16, UI.GOLD)))
		var now := _upgrade_value(k, u.levels[lvl])
		if cost < 0:
			v.add_child(UI.label("%s · fully upgraded" % now, 14, UI.MUTED))
		else:
			v.add_child(UI.label("%s  →  %s" % [now, _upgrade_value(k, u.levels[lvl + 1])], 14, UI.ACCENT))
			var b := UI.accent_button("Upgrade · %d cr" % cost, func(): GameState.act(g.buy_upgrade(k)))
			b.name = "Up_" + k
			b.disabled = cost > g.credits
			v.add_child(b)
		var card := UI.card(v)
		card.tooltip_text = UPGRADE_TIPS.get(k, "")
		grid.add_child(card)
	var right := VBoxContainer.new()  # the tab itself scrolls
	right.add_theme_constant_override("separation", 10)
	right.add_child(grid)
	right.add_child(_build_rig_tiers(g))
	right.add_child(_build_hulls(g))
	right.add_child(_build_mechanic(g))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var lv := VBoxContainer.new()
	lv.add_child(UI.heading("Your ship", 16))
	var prev := ShipPreview.new(g.upgrades)
	prev.paint = Style.hull_swaps(g.data, g.style)
	prev.decal = str(g.style.get("decal", ""))
	prev.tooltip_text = "Your ship with every module you bought. Paint and decals: Style app on the Com-Phone."
	lv.add_child(prev)
	lv.add_child(UI.label("Credits %d cr" % g.credits, 15, UI.GOLD))
	h.add_child(lv)
	h.add_child(right)
	return h


const UPGRADE_TIPS := {
	"cargo": "More hold slots: carry bigger hauls per trip.",
	"engine": "More thrust: outrun patrols and pirates, shorter jump drive charge.",
	"stealth": "Smaller patrol scan radius in space.",
	"laser": "Damage per laser bolt in space combat [J].",
	"missile": "Homing missile pods [K]; restock at the mechanic.",
	"flak": "Secondary weapon: a cone of flak pellets, shreds fighter swarms up close. No ammo. Switch with [Q].",
	"ion": "Secondary weapon: an ion bolt that stuns ships around the hit and hits gunships and bases twice as hard. Switch with [Q].",
	"shield": "Regenerating shield that soaks hits before the hull.",
	"hull": "More hull points before the ship is crippled.",
}


## Hull classes: buy a new ship or switch to one you own. Modules move over.
func _build_hulls(g) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(UI.heading("Hulls", 16))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for id in g.data.get("ship_classes", {}):
		var sc: Dictionary = g.data.ship_classes[id]
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 2)
		c.custom_minimum_size.x = 270
		var flying: bool = g.ship_class == id
		c.add_child(UI.label(str(sc.name) + ("  · flying" if flying else ""), 16, UI.ACCENT if flying else UI.GOLD))
		var stats: Array = []
		for k in [["cargo", "hold"], ["hull", "armour"], ["shield", "shield"], ["speed", "speed"], ["laser", "lasers"]]:
			var m := float(sc.get(k[0], 1.0))
			if not is_equal_approx(m, 1.0):
				stats.append("%s %s%d%%" % [k[1], "+" if m > 1.0 else "", int(round((m - 1.0) * 100.0))])
		c.add_child(UI.label(", ".join(PackedStringArray(stats)) if not stats.is_empty() else "baseline", 13, UI.MUTED))
		if not flying:
			var owned: bool = g.hulls.has(id)
			var b := UI.accent_button("Switch (owned)" if owned else "Buy · %d cr" % int(sc.price), func(): GameState.act(g.buy_ship(id)))
			b.name = "Hull_" + id
			b.disabled = not owned and int(sc.price) > g.credits
			c.add_child(b)
		var card := UI.card(c)
		card.tooltip_text = str(sc.get("desc", ""))
		grid.add_child(card)
	v.add_child(grid)
	return v


## Mechanic: hull repairs and missile restocks (the weapon, shield and armour modules are in the grid above).
func _build_mechanic(g) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(UI.heading("Mechanic", 16))
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


## Building tiers: the old global Hydro Rig upgrade, now rebuilt per estate you own on this planet (and the ship bay).
func _build_rig_tiers(g) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var t: Dictionary = g.data.estate_tiers
	for id in g.estates:
		var e: Dictionary = g.data.estates[id]
		if not e.get("ship", false) and e.get("location", "") != g.location:
			continue
		var tier: int = g.estate_tier(id)
		var cost: int = g.estate_tier_cost(id)
		var col := VBoxContainer.new()
		col.add_child(UI.label("%s  ·  %s" % [e.name, t.names[tier]], 16, UI.GOLD))
		if cost < 0:
			col.add_child(UI.label("%d units/batch · best line" % int(t.capacity[tier]), 14, UI.MUTED))
		else:
			col.add_child(UI.label("%d  →  %d units/batch, faster cooking" % [int(t.capacity[tier]), int(t.capacity[tier + 1])], 14, UI.ACCENT))
			var b := UI.accent_button("Rebuild as %s · %d cr" % [t.names[tier + 1], cost], func(): GameState.act(g.buy_estate_tier(id)))
			b.name = "Tier_" + id
			b.disabled = cost > g.credits
			b.tooltip_text = "Bigger batches and faster cooking in this estate only."
			col.add_child(b)
		var card := UI.card(col)
		card.tooltip_text = "Production line of this estate: more units per batch and faster cooking."
		v.add_child(card)
	return v


static func _upgrade_value(key: String, v) -> String:
	match key:
		"cargo": return "%d slots" % int(v)
		"engine": return "%d%% thrust" % int(float(v) * 100.0)
		"stealth": return "-%d%% scan range" % int(float(v) * 100.0)
		"laser": return "%d damage/shot" % int(v)
		"missile": return "no pods" if int(v) == 0 else "%d missiles" % int(v)
		"flak": return "no battery" if int(v) == 0 else "%d dmg/pellet" % int(v)
		"ion": return "no emitter" if int(v) == 0 else "%d ion dmg" % int(v)
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


## K3: "Here 12 cr · cheapest Drift Bazaar 9 cr (Halvane)" under a market card's tooltip.
func _compare_tip(g, here: int, offers: Array) -> String:
	var lines: Array = []
	for o in offers.slice(0, 3):
		if str(o.loc) == g.location:
			continue
		var d: int = int(o.price) - here
		lines.append("  %s (%s): %d cr  %s" % [g.data.locations[o.loc].name, g.data.systems[o.system].name, int(o.price),
			"same" if d == 0 else ("%+d" % d)])
	if lines.is_empty():
		return "\nOnly sold here."
	return "\nElsewhere:\n" + "\n".join(PackedStringArray(lines))
