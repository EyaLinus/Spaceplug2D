extends Control
## "Interdicted!" panel (D3): shown over the frozen flight view when pirates or Authority cutters pull the ship out
## of a jump. One button per choice (Fight / Pay / Dump cargo / Flee), keys 1-4. Presentation only: it reads
## Interdiction.options(game) and emits `chosen(id)`; main.gd resolves the choice in the core.

const UI = preload("res://scripts/ui/ui_theme.gd")
const Interdiction = preload("res://scripts/core/interdiction.gd")

signal chosen(id: String)

const IDS := ["fight", "pay", "dump", "flee"]

var _title: Label
var _body: Label
var _buttons: Dictionary = {}  ## option id -> Button
var _hints: Dictionary = {}  ## option id -> Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_title = UI.label("", 26, UI.WARN)
	_title.name = "InterTitle"
	box.add_child(_title)
	_body = UI.label("", 17)
	_body.name = "InterBody"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_body)
	for id in IDS:
		var row := VBoxContainer.new()
		var b: Button = UI.button("", func(): chosen.emit(id), 0)
		b.name = "Inter_" + id
		row.add_child(b)
		var h := UI.label("", 14, UI.MUTED)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(h)
		box.add_child(row)
		_buttons[id] = b
		_hints[id] = h


## Fills the panel from the pending encounter of `g` and shows it.
func open(g) -> void:
	var e: Dictionary = g.interdiction
	if e.is_empty():
		close()
		return
	_title.text = "INTERDICTED - %s" % Interdiction.kind_name(e.kind).to_upper()
	var dest: String = str(g.system_data(e.to).get("name", e.to))
	if e.kind == "authority":
		_body.text = "Reach Authority cutters drop out of the lane on your way to %s and demand a customs inspection. Heat %d, %d cr on hand." % [dest, int(g.heat), g.credits]
	else:
		_body.text = "%d raider%s cut your jump to %s short and demand a toll. You have %d cr and %d unit%s in the hold." % [e.ships, "" if e.ships == 1 else "s", dest, g.credits, Interdiction.cargo_units(g), "" if Interdiction.cargo_units(g) == 1 else "s"]
	for o in Interdiction.options(g):
		var b: Button = _buttons[o.id]
		b.text = "[%d] %s" % [IDS.find(o.id) + 1, o.label]
		b.disabled = not o.enabled
		_hints[o.id].text = o.hint
	visible = true


func close() -> void:
	visible = false


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var i: int = int(event.physical_keycode) - KEY_1
	if i >= 0 and i < IDS.size() and not _buttons[IDS[i]].disabled:
		chosen.emit(IDS[i])
		get_viewport().set_input_as_handled()
