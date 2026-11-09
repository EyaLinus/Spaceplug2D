extends RefCounted
## Automation machines (C2) in the estate Build tab: a "Machines" section under the Stations grid, built here so
## station_ui.gd only has to call `section`. Cards are named "Build_<machine id>" like the station cards and use the
## same place request (placing, kits, refunds are the normal building rules).

const UI = preload("res://scripts/ui/ui_theme.gd")
const Art = preload("res://scripts/core/art.gd")
const Machines = preload("res://scripts/core/machines.gd")


## One-line summary of what a machine does, for cards and the take-down overlay.
static func summary(g, id: String) -> String:
	var m: Dictionary = Machines.defs(g.data)[id]
	return "Runs the %s step for you: %d%% score, %d cr per unit." % [g.data.stations[m.station].name, int(round(float(m.score) * 100.0)), int(m.run_cost)]


## Build-menu section; `place` is called with the machine id when a card is pressed.
static func section(g, place: Callable) -> Control:
	var v := VBoxContainer.new()
	v.name = "MachinesSection"
	v.add_theme_constant_override("separation", 8)
	v.add_child(UI.heading("Machines"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for k in Machines.defs(g.data):
		grid.add_child(_card(g, k, place))
	v.add_child(grid)
	v.add_child(UI.label("Machines run one production step on their own, no minigame and no worker: use them at the estate like a table. They score below a good hand (never Premium), cost credits per unit each run and stand in for the table in recipe checks. Lab hands use them too.", 14, UI.MUTED))
	return v


static func card_text(g, id: String) -> String:
	var bd: Dictionary = g.data.buildables[id]
	var kit_n := int(g.kits.get(id, 0))
	return "%s\n%s · %d×%d · automatic" % [g.data.stations[id].name, ("kit ×%d" % kit_n) if kit_n > 0 else "%d cr" % int(bd.cost), int(bd.size[0]), int(bd.size[1])]


static func _card(g, id: String, place: Callable) -> Button:
	var bd: Dictionary = g.data.buildables[id]
	var kit_n := int(g.kits.get(id, 0))
	var card := Button.new()
	card.name = "Build_" + id
	card.theme_type_variation = "CardButton"
	card.custom_minimum_size = Vector2(270, 74)
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	Art.station_card_icon(card, id)
	card.text = card_text(g, id)
	card.tooltip_text = "%s\n%s Takes the place of a %s." % [g.data.stations[id].get("hint", ""), summary(g, id),
		g.data.stations[Machines.station_of(g.data, id)].name]
	card.disabled = g.credits < int(bd.cost) and kit_n <= 0
	card.pressed.connect(func():
		AudioManager.play("click")
		place.call(id))
	return card
