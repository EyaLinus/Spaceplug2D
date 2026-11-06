extends Control
## Deal card for a customer on foot (P2): product, amount and price per unit from your asking price, with Accept, Ask +x %
## (one haggle) and Walk away. Rules in scripts/core/walkups.gd; the sale itself is Game.sell. main.gd opens it when you
## talk to a customer who walked up to you; Esc or Walk away closes it.

const UI = preload("res://scripts/ui/ui_theme.gd")
const Walkups = preload("res://scripts/core/walkups.gd")
const People = preload("res://scripts/core/people.gd")
const Mixing = preload("res://scripts/core/mixing.gd")

signal closed

var contact := ""
var _box: VBoxContainer
var _msg: Label
var _msg_text := ""


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.name = "WalkupPanel"
	panel.theme_type_variation = "Card"
	panel.custom_minimum_size = Vector2(420, 0)
	centre.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	panel.add_child(_box)


func open(cid: String) -> void:
	contact = cid
	_msg_text = ""
	_build()
	visible = true


func close() -> void:
	if visible:
		visible = false
		closed.emit()



func _build() -> void:
	var g = GameState.game
	for c in _box.get_children():
		c.queue_free()
	var w := Walkups.find(g, contact)
	var c: Dictionary = g.contact(contact)
	if w.is_empty():
		_box.add_child(UI.label("They walked off.", 16, UI.MUTED))
		_box.add_child(_close_button("Close"))
		return
	var known: bool = People.state(g, contact).known
	_box.add_child(UI.heading(c.name if known else str(c.get("job", "Customer")), 20))
	var quote := UI.label("\"Got any %s? I'll take %d.\"" % [g.item_name(str(w.product)), int(w.qty)], 15, UI.MUTED)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(quote)
	_box.add_child(HSeparator.new())
	var total := Walkups.total(g, w)
	_box.add_child(UI.label("%d × %s" % [int(w.qty), g.item_name(str(w.product))], 17))
	_box.add_child(UI.label("%d cr each · about %d cr total" % [int(w.price), total], 17, UI.GOLD))
	var ask: int = Walkups.ceiling(g, w)
	_box.add_child(UI.label("Mood: %s · %s" % [People.mood(float(People.state(g, contact).affinity)), People.addiction_label(float(People.state(g, contact).addiction))], 13, UI.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var acc := UI.accent_button("Accept · %d cr" % total, _accept)
	acc.name = "Walkup_accept"
	row.add_child(acc)
	if not w.haggled:
		for r in g.data.walkups.get("haggle", [0.1]):
			var hb := UI.button("Ask +%d%%" % int(round(float(r) * 100.0)), _haggle.bind(float(r)))
			hb.name = "Walkup_haggle_%d" % int(round(float(r) * 100.0))
			row.add_child(hb)
	var no := UI.button("Walk away", _decline)
	no.name = "Walkup_decline"
	row.add_child(no)
	_box.add_child(row)
	if not w.haggled:
		_box.add_child(UI.label("They would go up to about %d cr each." % ask if ask > int(w.price) else "They will not pay more than this.", 12, UI.MUTED))
	_msg = UI.label(_msg_text, 14, UI.WARN)
	_box.add_child(_msg)
	acc.grab_focus.call_deferred()


func _close_button(text: String) -> Button:
	var b := UI.button(text, close)
	b.name = "Walkup_close"
	return b


func _accept() -> void:
	var r: Dictionary = Walkups.accept(GameState.game, contact)
	EventBus.toast.emit(str(r.msg), bool(r.ok))
	close()


func _haggle(raise: float) -> void:
	var r: Dictionary = Walkups.haggle(GameState.game, contact, raise)
	_msg_text = str(r.msg)
	_build()


func _decline() -> void:
	EventBus.toast.emit(str(Walkups.decline(GameState.game, contact).msg), true)
	close()
