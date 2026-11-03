extends Control
## Interdiction card (D3): shown when a jump is pulled out of hyperspace by a cartel wing or the Authority.
## Four ways out (pay, dump, flee, fight) with their cost or chance; the rules are in scripts/core/interdiction.gd.
## main.gd opens it on "interdicted", pauses the game while it is up and spawns the fight when one starts.

const UI = preload("res://scripts/ui/ui_theme.gd")
const Interdiction = preload("res://scripts/core/interdiction.gd")
const Cartels = preload("res://scripts/core/cartels.gd")

signal resolved(result: Dictionary)

var _box: VBoxContainer
var _msg: Label


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.05, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.name = "InterdictPanel"
	panel.theme_type_variation = "Card"
	panel.custom_minimum_size = Vector2(520, 0)
	centre.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	panel.add_child(_box)


## Builds the card for the pending encounter of `g` and shows it.
func open(g) -> void:
	if not Interdiction.pending(g):
		return
	for c in _box.get_children():
		c.queue_free()
	var enc: Dictionary = g.interdiction
	var auth: bool = enc.kind == "authority"
	var colour := UI.WARN if auth else Color(str(Cartels.gang(g, enc.cartel).get("color", "#ff6b5f")))
	_box.add_child(UI.label("INTERDICTED", 24, colour))
	var who: String
	var line: String
	if auth:
		who = "Reach Authority interceptors"
		line = "\"Cut your drive and prepare for inspection. We know what you're hauling.\""
	else:
		var gd: Dictionary = Cartels.gang(g, enc.cartel)
		who = "%s wing" % gd.get("name", "Cartel")
		line = "\"%s says this lane has a toll. Pay up or get scrapped.\"" % gd.get("boss", "The boss")
	var units: Array = enc.units
	var counts := {}
	for u in units:
		counts[u] = int(counts.get(u, 0)) + 1
	var parts: Array = []
	for u in counts:
		parts.append("%d %s%s" % [counts[u], u, "" if int(counts[u]) == 1 else "s"])
	_box.add_child(UI.label("%s: %s" % [who, ", ".join(PackedStringArray(parts))], 16))
	var l := UI.label(line, 15, UI.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)
	_box.add_child(HSeparator.new())
	var cost := Interdiction.pay_cost(g, enc)
	var opts := [
		["pay", ("Bribe · %d cr" if auth else "Pay the toll · %d cr") % cost, "Lowers your heat." if auth else "They let you through.", g.credits >= cost],
		["dump", "Dump the product", Interdiction.dump_text(g, enc), Interdiction.product_units(g) > 0],
		["flee", "Run for it · %d%%" % int(round(Interdiction.flee_chance(g) * 100.0)), "Engine modules and a fast hull help. Failing costs hull and starts the fight.", true],
		["fight", "Fight", "Shooting Authority ships raises your heat." if auth else "Every kill costs them ground here.", true],
	]
	for o in opts:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var b := UI.accent_button(o[1], _choose.bind(o[0])) if o[0] == "fight" else UI.button(o[1], _choose.bind(o[0]))
		b.name = "Interdict_" + o[0]
		b.custom_minimum_size = Vector2(210, 0)
		b.disabled = not o[3]
		row.add_child(b)
		var t := UI.label(o[2], 13, UI.MUTED)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		_box.add_child(row)
	_msg = UI.label("", 14, UI.WARN)
	_box.add_child(_msg)
	visible = true
	AudioManager.play("alarm")
	var first := _box.find_child("Interdict_fight", true, false)
	if first != null:
		(first as Button).grab_focus.call_deferred()


func _choose(choice: String) -> void:
	var g = GameState.game
	var r: Dictionary = Interdiction.resolve(g, choice)
	if not r.ok:
		_msg.text = str(r.msg)
		return
	visible = false
	resolved.emit(r)
