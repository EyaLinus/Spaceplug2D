extends "res://scripts/ui/phone/phone_app.gd"
## Deal-O-Matic: requests from named customers as message threads. Open requests can be accepted, countered (haggling
## chance depends on affinity and addiction) or declined; accepted deals list where and when to meet and what to bring.
## Rules live in scripts/core/deals.gd; the hand-over itself happens on foot at the spot (surface.gd + main.gd).

const Art = preload("res://scripts/core/art.gd")
const Deals = preload("res://scripts/core/deals.gd")
const Contacts = preload("res://scripts/ui/phone/apps/contacts_app.gd")


func _init() -> void:
	id = "deals"
	title = "Deal-O-Matic"
	icon = "app_deals"
	tint = Color("#ffd166")


func badge(g) -> int:
	return Deals.with_status(g, ["open"]).size()


func home(g, phone) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_section(g, phone, v, "REQUESTS", ["open"])
	_section(g, phone, v, "TO DELIVER", ["accepted"])
	_section(g, phone, v, "RECENT", ["done", "missed", "expired", "declined", "walked"], 6)
	if g.deals.offers.is_empty():
		var l := UI.label("No messages yet. Customers you have met text you when they want product; hooked ones more often. The fence still buys anything at the spaceport.", 14, UI.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	return v


func _section(g, phone, v: VBoxContainer, head: String, statuses: Array, limit := 99) -> void:
	var rows: Array = Deals.with_status(g, statuses)
	if rows.is_empty():
		return
	rows.reverse()
	v.add_child(UI.label(head, 13, UI.MUTED))
	for o in rows.slice(0, limit):
		v.add_child(_row(g, phone, o))


func _row(g, phone, o: Dictionary) -> Control:
	var c: Dictionary = g.contact(o.contact)
	var b := Button.new()
	b.name = "Deal_%d" % o.id
	b.custom_minimum_size = Vector2(0, 58)
	var oid: int = o.id
	b.pressed.connect(func():
		AudioManager.play("click")
		phone.push(c.name, func(gg): return detail(gg, oid)))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	b.add_child(h)
	h.add_child(Contacts.Portrait.make(c.get("look", ""), 1.5))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UI.label(c.name, 16))
	col.add_child(UI.label("%d × %s · %d cr each" % [o.qty, g.data.bases[o.base].name, o.price], 13, _status_color(o.status)))
	h.add_child(col)
	h.add_child(UI.label(_status_text(g, o), 13, _status_color(o.status)))
	for ch in col.get_children():
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func _status_text(g, o: Dictionary) -> String:
	match o.status:
		"open":
			return "answer by %s" % Deals.clock_text(g, o.expires_at)
		"accepted":
			return "%s-%s" % [Deals.clock_text(g, o.opens_at), Deals.clock_text(g, o.expires_at)]
		"done":
			return "done"
		"missed":
			return "missed"
		"expired":
			return "expired"
		"declined":
			return "declined"
		"walked":
			return "walked off"
	return o.status


static func _status_color(status: String) -> Color:
	match status:
		"open":
			return UI.GOLD
		"accepted", "done":
			return UI.ACCENT
		"missed", "walked":
			return UI.WARN
	return UI.MUTED


## One conversation: the message, the terms and the buttons that fit the status.
func detail(g, oid: int) -> Control:
	var o := Deals.find(g, oid)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	if o.is_empty():
		v.add_child(UI.label("Message deleted.", 15, UI.MUTED))
		return v
	var c: Dictionary = g.contact(o.contact)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(Contacts.Portrait.make(c.get("look", ""), 3.0))
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(UI.label(c.get("job", ""), 14, UI.MUTED))
	who.add_child(UI.label(g.data.locations[o.loc].name, 14))
	who.add_child(UI.label(_status_text(g, o).capitalize() if o.status != "open" else "Waiting for your answer", 14, _status_color(o.status)))
	top.add_child(who)
	v.add_child(top)
	var msg := UI.label("\"%s\"" % Deals.message(g, o), 15)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	v.add_child(_pair("Product", g.data.bases[o.base].name))
	v.add_child(_pair("Amount", "%d units" % o.qty))
	v.add_child(_pair("Price", "%d cr each · %d cr total" % [o.price, o.price * o.qty]))
	v.add_child(_pair("Where", "%s · %s" % [Deals.spot_name(g, o), g.data.locations[o.loc].name]))
	v.add_child(_pair("When", "%s - %s" % [Deals.clock_text(g, o.opens_at), Deals.clock_text(g, o.expires_at)]))
	var have := Deals.units_held(g, o.base)
	v.add_child(_pair("You carry", "%d × %s" % [have, g.data.bases[o.base].name]))
	if o.status == "open":
		v.add_child(UI.label("COUNTER", 13, UI.MUTED))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var steps: Array = g.data.deals.haggle.steps
		for i in steps.size():
			var chance := Deals.counter_chance(g, o, i)
			var cb := UI.button("%d cr (%d%%)" % [Deals.counter_price(g, o, i), int(round(chance * 100.0))], func(): GameState.act(Deals.counter(g, oid, i)), 100)
			cb.name = "Counter_%d" % i
			cb.disabled = o.countered or not Deals.can_afford(g, o, i)
			row.add_child(cb)
		v.add_child(row)
		if o.countered:
			v.add_child(UI.label("They won't haggle again.", 13, UI.MUTED))
		var acts := HBoxContainer.new()
		acts.add_theme_constant_override("separation", 6)
		var ab := UI.button("Accept", func(): GameState.act(Deals.accept(g, oid)), 120)
		ab.name = "Accept"
		acts.add_child(ab)
		var db := UI.button("Decline", func(): GameState.act(Deals.decline(g, oid)), 120)
		db.name = "Decline"
		acts.add_child(db)
		v.add_child(acts)
	elif o.status == "accepted":
		var l := UI.label("Bring the goods to %s on %s inside the window and press the interact key at the marker." % [Deals.spot_name(g, o), g.data.locations[o.loc].name], 14, UI.ACCENT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		if have < int(o.qty):
			v.add_child(UI.label("Not enough %s yet: cook or load more." % g.data.bases[o.base].name, 14, UI.WARN))
	return v


func _pair(k: String, val: String) -> Control:
	var h := HBoxContainer.new()
	var kl := UI.label(k, 14, UI.MUTED)
	kl.custom_minimum_size.x = 100
	h.add_child(kl)
	var vl := UI.label(val, 14)
	vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(vl)
	return h
