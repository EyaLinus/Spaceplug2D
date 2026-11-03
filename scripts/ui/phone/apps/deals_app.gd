extends "res://scripts/ui/phone/phone_app.gd"
## Deal-O-Matic: customer requests as chat threads. Answer a new request with Accept, a counter offer (+10 % / +25 %)
## or Decline; an accepted deal shows where to meet and how long you have. Handing over happens in person.

const Art = preload("res://scripts/core/art.gd")
const Deals = preload("res://scripts/core/deals.gd")
const ContactsApp = preload("res://scripts/ui/phone/apps/contacts_app.gd")

const RAISES := [0.1, 0.25]
const STATE_LABEL := {"new": "New request", "accepted": "Meet them", "dropped": "At the drop", "stolen": "Stolen", "done": "Done", "declined": "Declined", "expired": "Expired"}


func _init() -> void:
	id = "deals"
	title = "Deal-O-Matic"
	icon = "app_deals"
	tint = Color("#ffd166")


func badge(g) -> int:
	return Deals.count_state(g, "new")


func home(g, phone) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if g.offers.is_empty():
		var l := UI.label("No messages yet. Customers you've met text you when they want something.", 14, UI.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var list: Array = g.offers.duplicate()
	list.sort_custom(func(a, b): return _rank(a) < _rank(b) or (_rank(a) == _rank(b) and int(a.id) > int(b.id)))
	for o in list:
		v.add_child(_row(g, phone, o))
	return v


static func _rank(o: Dictionary) -> int:
	return {"new": 0, "accepted": 1}.get(o.state, 2)


func _row(g, phone, o: Dictionary) -> Control:
	var c: Dictionary = g.contact(o.contact)
	var b := Button.new()
	b.name = "Offer_%d" % int(o.id)
	b.custom_minimum_size = Vector2(0, 58)
	b.pressed.connect(func():
		AudioManager.play("click")
		phone.push(c.name, func(gg): return thread(gg, int(o.id))))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	b.add_child(h)
	h.add_child(ContactsApp.Portrait.make(c.get("look", ""), 1.5))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var open: bool = o.state in Deals.OPEN
	col.add_child(UI.label("%s · %s" % [c.name, STATE_LABEL.get(o.state, o.state)], 15, _state_color(o.state)))
	var last: String = o.msgs[-1].text if not (o.msgs as Array).is_empty() else ""
	var prev := UI.label(last, 13, UI.TEXT if open else UI.MUTED)
	prev.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	prev.custom_minimum_size.x = 10
	prev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(prev)
	for ch in col.get_children():
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)
	return b


## One conversation with its answer buttons.
func thread(g, offer_id: int) -> Control:
	var o: Dictionary = Deals.find(g, offer_id)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if o.is_empty():
		v.add_child(UI.label("This conversation was deleted.", 14, UI.MUTED))
		return v
	var c: Dictionary = g.contact(o.contact)
	v.add_child(Art.with_icon(o.base, UI.label("%d × %s · %d cr each · %d cr total" % [o.qty, g.data.bases[o.base].name, o.price, int(o.price) * int(o.qty)], 14, UI.GOLD)))
	for m in o.msgs:
		v.add_child(_bubble(m.text, m.me))
	var left := int(ceil(float(o.expires_at) - g.total_time))
	match o.state:
		"new":
			v.add_child(UI.label("Answer within %ds" % left, 13, UI.MUTED))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var acc := UI.button("Accept", func(): GameState.act(Deals.accept(g, offer_id)), 90)
			acc.name = "Accept"
			row.add_child(acc)
			if not o.countered:
				for r in RAISES:
					var cb := UI.button("+%d%%" % int(r * 100.0), func(): GameState.act(Deals.counter(g, offer_id, r)), 64)
					cb.name = "Counter%d" % int(r * 100.0)
					cb.tooltip_text = "Ask for %d cr each (%d%% chance)" % [int(round(o.price * (1.0 + r))), int(Deals.counter_chance(g, o.contact, r) * 100.0)]
					row.add_child(cb)
			var dec := UI.button("Decline", func(): GameState.act(Deals.decline(g, offer_id)), 80)
			dec.name = "Decline"
			row.add_child(dec)
			v.add_child(row)
			if not o.countered:
				v.add_child(UI.label("Haggle odds: +10%% → %d%%, +25%% → %d%%" % [int(Deals.counter_chance(g, o.contact, 0.1) * 100.0), int(Deals.counter_chance(g, o.contact, 0.25) * 100.0)], 13, UI.MUTED))
		"accepted":
			var where: String = g.loc_data(c.location).get("name", "")
			var info := UI.label("Meet %s on %s within %ds and hand over %d × %s." % [c.name, where, left, o.qty, g.data.bases[o.base].name], 14, UI.ACCENT)
			info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(info)
			var have: Array = Deals.matching_products(g, o)
			v.add_child(UI.label("In your hold: %s" % ("ready" if not have.is_empty() else "not enough %s" % g.data.bases[o.base].name), 13, UI.ACCENT if not have.is_empty() else UI.WARN))
			var cancel := UI.button("Call it off", func(): GameState.act(Deals.decline(g, offer_id)), 120)
			cancel.name = "Cancel"
			v.add_child(cancel)
	return v


func _bubble(text: String, me: bool) -> Control:
	var wrap := HBoxContainer.new()
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2e2440") if me else Color("#1a2a2a")
	sb.border_color = UI.ACCENT.darkened(0.4) if me else Color("#5a5b6a")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(7)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size.x = 250
	var l := UI.label(text, 14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	if me:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.add_child(spacer)
	wrap.add_child(p)
	return wrap


static func _state_color(st: String) -> Color:
	match st:
		"new":
			return UI.GOLD
		"accepted":
			return UI.ACCENT
	return UI.MUTED
