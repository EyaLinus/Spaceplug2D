extends "res://scripts/ui/phone/phone_app.gd"
## DeadDrop: request anonymous drop points on planets, stations and outposts. Docked at a drop you can leave an agreed
## Deal-O-Matic deal there (the customer collects and pays later, little heat, small theft risk) or send goods to your
## hub stash by courier. Rules and numbers live in scripts/core/deaddrops.gd and content.json "deaddrops".

const Deaddrops = preload("res://scripts/core/deaddrops.gd")
const Deals = preload("res://scripts/core/deals.gd")

var _notice := ""


func _init() -> void:
	id = "deaddrop"
	title = "DeadDrop"
	icon = "app_deaddrop"
	tint = Color("#8f7be0")


func badge(g) -> int:
	return g.drops_unseen


func home(g, _phone) -> Control:
	g.drops_unseen = 0
	var rl := Deaddrops.rules(g)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var intro := UI.label("Anonymous drop points. Leave a deal's goods there instead of meeting in person: %d%% of the heat, but %d%% of pickups get stolen." % [int(round(float(rl.heat_mult) * 100.0)), int(round(Deaddrops.theft_chance(g, "deal") * 100.0))], 13, UI.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(intro)
	if _notice != "":
		var n := UI.label(_notice, 13, UI.WARN)
		n.name = "DropNotice"
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(n)
	v.add_child(UI.label("YOUR DROPS (%d/%d)" % [g.drops.size(), int(rl.max_open)], 13, UI.MUTED))
	if g.drops.is_empty():
		v.add_child(UI.label("None yet. Request one below.", 14, UI.MUTED))
	for d in g.drops:
		v.add_child(_drop_card(g, d))
	v.add_child(UI.label("REQUEST A DROP (%d cr)" % Deaddrops.request_fee(g, ""), 13, UI.MUTED))
	for loc in g.data.locations:
		if Deaddrops.eligible(g, loc) and Deaddrops.at(g, loc).is_empty():
			v.add_child(_request_row(g, loc))
	return v


func _request_row(g, loc: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := UI.label("%s (%s)" % [g.loc_data(loc).name, g.loc_system(loc).capitalize()], 14)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var b := UI.button("Request", func():
		var r := Deaddrops.request(g, loc)
		_notice = "" if r.ok else str(r.msg)
		AudioManager.play("buy" if r.ok else "error")
		_refresh_soon(), 80)
	b.name = "DropRequest_" + loc
	b.disabled = g.drops.size() >= int(Deaddrops.rules(g).max_open) or Deaddrops.request_fee(g, loc) > g.credits
	row.add_child(b)
	return row


func _drop_card(g, d: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Drop_%d" % int(d.id)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)
	var top := HBoxContainer.new()
	var nm := UI.label(g.loc_data(d.loc).name, 15)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	var free := Deaddrops.is_free(d)
	var left := maxi(0, int(ceil(float(d.expires_at if free else d.job.due) - g.total_time)))
	top.add_child(UI.label(("idle, closes in %ds" % left) if free else _job_text(g, d, left), 13, UI.MUTED if free else UI.ACCENT))
	col.add_child(top)
	var spot := UI.label("Hidden in %s." % d.spot, 13, UI.MUTED)
	spot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(spot)
	if free and g.location == d.loc:
		var opts := Deaddrops.deal_options(g, d)
		for o in opts:
			var have: Array = Deals.matching_products(g, o)
			var c: Dictionary = g.contact(o.contact)
			var b := UI.button("Leave %d × %s for %s" % [o.qty, g.data.bases[o.base].name, c.name.get_slice(" ", 0)], func():
				_notice = str(Deaddrops.assign_deal(g, int(d.id), int(o.id), have[0]).msg)
				_refresh_soon(), 0)
			_fit(b)
			b.name = "DropDeal_%d" % int(o.id)
			b.disabled = have.is_empty()
			col.add_child(b)
		if opts.is_empty():
			col.add_child(UI.label("No agreed deal with someone who lives here.", 12, UI.MUTED))
		var cargo_keys: Array = g.cargo.keys()
		cargo_keys.sort()
		for k in cargo_keys:
			var qty := int(g.cargo[k])
			var fee := Deaddrops.courier_fee(g, qty)
			var cb := UI.button("Courier %d × %s, %d cr" % [qty, g.item_name(k), fee], func():
				_notice = str(Deaddrops.send_courier(g, int(d.id), k, qty).msg)
				_refresh_soon(), 0)
			_fit(cb)
			cb.name = "DropCourier_%d_%s" % [int(d.id), k]
			cb.disabled = fee > g.credits
			col.add_child(cb)
	elif free:
		col.add_child(UI.label("Dock on %s to use it." % g.loc_data(d.loc).name, 12, UI.MUTED))
	if free:
		var rel := UI.button("Abandon", func():
			_notice = str(Deaddrops.release(g, int(d.id)).msg)
			_refresh_soon(), 0)
		rel.name = "DropRelease_%d" % int(d.id)
		col.add_child(rel)
	return panel


## Long labels shrink to the phone width instead of widening the screen.
func _fit(b: Button) -> void:
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size.x = 10


func _job_text(g, d: Dictionary, left: int) -> String:
	var j: Dictionary = d.job
	if j.kind == "deal":
		return "%s collects in %ds" % [g.contact(Deals.find(g, int(j.offer)).get("contact", "")).get("name", "Customer"), left]
	return "courier, %ds" % left


func _refresh_soon() -> void:
	EventBus.game_event.emit("drops_ui", {})
