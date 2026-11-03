extends CanvasLayer
## Combat readout while flying: hull, shield, dodge energy and missiles bottom-left, key hints, a red flash when hit.
## Owned by the world (it follows `world.active`); reads the core combat state, never writes it.

const UI = preload("res://scripts/ui/ui_theme.gd")
const SpaceCombat = preload("res://scripts/core/spacecombat.gd")

var layer_ref: Node2D  ## combat_layer.gd (hit flash)
var _hull: ProgressBar
var _shield: ProgressBar
var _boost: ProgressBar
var _missiles: Label
var _hint: Label
var _flash: ColorRect
var _shield_row: Control
var _missile_row: Control


func setup(combat_layer: Node2D) -> void:
	layer_ref = combat_layer


func _ready() -> void:
	layer = 1
	_flash = ColorRect.new()
	_flash.color = Color(1, 0.1, 0.05, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 12
	box.offset_bottom = -40
	box.offset_top = -150
	add_child(box)
	_hull = _add_row(box, "Hull", Color("#ff6b5f"))
	_shield = _add_row(box, "Shield", Color("#6ac4ff"))
	_shield_row = _shield.get_parent()
	_boost = _add_row(box, "Boost", UI.GOLD)
	_missiles = UI.label("", 15, UI.MUTED)
	box.add_child(_missiles)
	_hint = UI.label("", 14, UI.MUTED)
	box.add_child(_hint)


func _add_row(parent: Control, text: String, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UI.label(text, 15, UI.TEXT)
	l.custom_minimum_size.x = 54
	row.add_child(l)
	var b := UI.bar(color)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(170, 14)
	row.add_child(b)
	parent.add_child(row)
	return b


func _process(_delta: float) -> void:
	var g = GameState.game
	if g == null or not visible:
		return
	_hull.max_value = SpaceCombat.max_hull(g)
	_hull.value = g.combat.hull
	var ms := SpaceCombat.max_shield(g)
	_shield_row.visible = ms > 0.0
	_shield.max_value = maxf(ms, 1.0)
	_shield.value = g.combat.shield
	_boost.max_value = float(g.data.space_combat.boost.max)
	_boost.value = g.combat.boost
	var sec := SpaceCombat.secondary(g)
	_missiles.visible = sec != ""
	match sec:
		"missile":
			_missiles.text = "Missiles %d / %d" % [int(g.combat.missiles), SpaceCombat.missile_cap(g)]
		"flak":
			_missiles.text = "Flak battery · %d dmg x%d" % [int(SpaceCombat.flak_damage(g)), int(g.data.space_combat.flak.pellets)]
		"ion":
			_missiles.text = "Ion emitter · stuns"
	if SpaceCombat.secondaries(g).size() > 1:
		_missiles.text += "   [%s] switch" % Settings.key_label("ship_cycle")
	_hint.text = "%s fire   %s %s   %s dodge boost" % [Settings.key_label("ship_fire"), Settings.key_label("ship_missile"), sec if sec != "" else "secondary", Settings.key_label("ship_boost")]
	_flash.color.a = 0.28 * (layer_ref.hit_flash if layer_ref != null else 0.0)
