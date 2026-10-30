extends Control
## Base for full-screen menu overlays: dimmed background, centered panel, a VBox `box` to fill.
## Esc (pause action or ui_cancel) while visible emits `back` and swallows the key, so the menu below does not react.

signal back

const UI = preload("res://scripts/ui/ui_theme.gd")

var box: VBoxContainer
var panel: PanelContainer


func _init(width := 480) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.04, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size.x = width
	center.add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	visible = false


func open() -> void:
	visible = true
	focus_first()


func close() -> void:
	visible = false


## Gives keyboard focus to the first enabled button, so the menus work without a mouse.
func focus_first() -> void:
	var b := _first_button(self)
	if b != null:
		b.grab_focus.call_deferred()


func title(text: String, size := 30) -> Label:
	var t := UI.label(text, size, UI.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	return t


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back.emit()


func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and c.visible and not c.disabled:
			return c
		var b := _first_button(c)
		if b != null:
			return b
	return null
