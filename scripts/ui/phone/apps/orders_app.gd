extends "res://scripts/ui/phone/phone_app.gd"
## Market & Orders: order raws and additives from anywhere. Pick a destination (hub stash or an owned estate) and
## standard or express delivery, set the amount per item and order. Open orders show a countdown and can be
## cancelled. Rules and numbers live in scripts/core/orders.gd and content.json "orders".

const Orders = preload("res://scripts/core/orders.gd")

var _dest := "stash"
var _express := false
var _qty := {}  ## item -> amount selected
var _notice := ""


func _init() -> void:
	id = "orders"
	title = "Orders"
	icon = "app_orders"
	tint = Color("#f2b84b")


func badge(g) -> int:
	return g.orders_unseen


func home(g, _phone) -> Control:
	g.orders_unseen = 0
	if not g.estates.has(_dest) and _dest != "stash":
		_dest = "stash"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(_options(g))
	if _notice != "":
		var n := UI.label(_notice, 13, UI.WARN)
		n.name = "OrdersNotice"
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(n)
	if not g.orders.is_empty():
		v.add_child(UI.label("IN TRANSIT", 13, UI.MUTED))
		for o in g.orders:
			v.add_child(_order_row(g, o))
	v.add_child(UI.label("SHOP", 13, UI.MUTED))
	for e in Orders.catalog(g):
		v.add_child(_shop_row(g, e))
	var tip := UI.label("Walk-in markets are cheaper but you have to be there.", 12, UI.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)
	return v


func _options(g) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_child(UI.label("Deliver to", 14, UI.MUTED))
	var ob := OptionButton.new()
	ob.name = "OrdersDest"
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sel := 0
	var dests := Orders.destinations(g)
	for i in dests.size():
		ob.add_item(dests[i].name, i)
		ob.set_item_metadata(i, dests[i].id)
		if dests[i].id == _dest:
			sel = i
	ob.select(sel)
	ob.item_selected.connect(func(i):
		_dest = str(ob.get_item_metadata(i))
		_notice = ""
		_refresh_soon())
	row.add_child(ob)
	box.add_child(row)
	var speed := HBoxContainer.new()
	speed.add_theme_constant_override("separation", 6)
	var rl := Orders.rules(g)
	var std := UI.button("Standard %ds" % int(rl.seconds.standard), func():
		_express = false
		_refresh_soon(), 0)
	std.name = "OrdersStandard"
	std.toggle_mode = true
	std.button_pressed = not _express
	var expb := UI.button("Express %ds (fee x%s)" % [int(rl.seconds.express), str(rl.express_fee_mult)], func():
		_express = true
		_refresh_soon(), 0)
	expb.name = "OrdersExpress"
	expb.toggle_mode = true
	expb.button_pressed = _express
	speed.add_child(std)
	speed.add_child(expb)
	box.add_child(speed)
	return box


func _shop_row(g, e: Dictionary) -> Control:
	var item: String = e.item
	var n: int = clampi(int(_qty.get(item, 5)), 1, int(Orders.rules(g).max_qty))
	_qty[item] = n
	var q := Orders.quote(g, item, n, _dest, _express)
	var panel := PanelContainer.new()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	var top := HBoxContainer.new()
	var name_l := UI.label(e.name, 15)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	top.add_child(UI.label("%d cr each" % Orders.unit_price(g, item), 13, UI.GOLD))
	col.add_child(top)
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 4)
	var minus := UI.button("-", func():
		_qty[item] = maxi(1, int(_qty[item]) - (5 if Input.is_key_pressed(KEY_SHIFT) else 1))
		_refresh_soon(), 32)
	minus.name = "OrderMinus_" + item
	bot.add_child(minus)
	var cnt := UI.label(str(n), 15)
	cnt.custom_minimum_size.x = 30
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bot.add_child(cnt)
	var plus := UI.button("+", func():
		_qty[item] = mini(int(Orders.rules(g).max_qty), int(_qty[item]) + (5 if Input.is_key_pressed(KEY_SHIFT) else 1))
		_refresh_soon(), 32)
	plus.name = "OrderPlus_" + item
	bot.add_child(plus)
	var tot := UI.label(("%d cr (fee %d)" % [q.total, q.fee]) if q.ok else str(q.msg), 13, UI.MUTED)
	tot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bot.add_child(tot)
	var buy := UI.button("Order", func():
		var r := Orders.place(g, item, int(_qty[item]), _dest, _express)
		_notice = str(r.msg)
		AudioManager.play("buy" if r.ok else "error")
		_refresh_soon(), 64)
	buy.name = "Order_" + item
	buy.disabled = not q.ok or int(q.total) > g.credits
	bot.add_child(buy)
	col.add_child(bot)
	return panel


func _order_row(g, o: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "Transit_%d" % int(o.id)
	row.add_theme_constant_override("separation", 6)
	var left := maxi(0, int(ceil(float(o.due) - g.total_time)))
	var l := UI.label("%d x %s -> %s%s" % [int(o.qty), g.item_name(o.item), Orders.dest_name(g, o.dest), " (express)" if o.express else ""], 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	row.add_child(UI.label("%ds" % left, 13, UI.ACCENT))
	var c := UI.button("Cancel", func():
		_notice = str(Orders.cancel(g, int(o.id)).msg)
		_refresh_soon(), 0)
	c.name = "OrderCancel_%d" % int(o.id)
	row.add_child(c)
	return row


## Screens rebuild after a game event; most clicks change only local state, so ask the phone to redraw.
func _refresh_soon() -> void:
	EventBus.game_event.emit("orders_ui", {})
