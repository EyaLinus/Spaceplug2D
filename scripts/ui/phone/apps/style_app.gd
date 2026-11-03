extends "res://scripts/ui/phone/phone_app.gd"
## K2 Style: change your look (hair, skin, jacket, pants), your ship's paint and decal, and switch decor on for your
## estates. Owned items switch for free; new ones are bought on the spot. Rules: scripts/core/style.gd.

const Style = preload("res://scripts/core/style.gd")
const Art = preload("res://scripts/core/art.gd")
const ShipPreview = preload("res://scripts/ui/ship_preview.gd")

const SECTIONS := [
	["Look", ["hair", "skin", "jacket", "pants"]],
	["Ship", ["paint", "decal"]],
	["Estate decor", ["decor"]],
]
const CAT_NAMES := {"hair": "Hair", "skin": "Skin", "jacket": "Jacket", "pants": "Trousers", "paint": "Paint", "decal": "Decal", "decor": "Decor"}

var _swatches := {}  ## ramp key -> ImageTexture


func _init() -> void:
	id = "style"
	title = "Style"
	icon = "app_style"
	tint = Color("#ff9ad5")


func home(g, phone) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(_preview(g))
	for sec in SECTIONS:
		v.add_child(UI.heading(sec[0], 14))
		for cat in sec[1]:
			if sec[1].size() > 1:
				v.add_child(UI.label(CAT_NAMES[cat], 13, UI.MUTED))
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 4)
			grid.add_theme_constant_override("v_separation", 4)
			var items: Dictionary = Style.catalogue(g.data, cat)
			for item_id in items:
				grid.add_child(_tile(g, phone, cat, item_id, items[item_id]))
			v.add_child(grid)
	var note := UI.label("Decor shows in every estate you own where there is room along the walls (wide pieces need the bottom row). Paint and decals show in flight, on the pad and at the shipyard.", 12, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	return v


func _preview(g) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	var me := _PlayerPreview.new()
	me.sheet = Art.recolored("chars/player.png", Style.player_swaps(g.data, g.style))
	me.tooltip_text = "You, as the people on the street see you."
	h.add_child(UI.card(me, true))
	var ship := ShipPreview.new(g.upgrades)
	ship.zoom = 2
	ship.custom_minimum_size = Vector2(96, 96)
	ship.paint = Style.hull_swaps(g.data, g.style)
	ship.decal = str(g.style.get("decal", ""))
	ship.tooltip_text = "Your ship with its paint and decal."
	h.add_child(UI.card(ship, true))
	return h


func _tile(g, phone, cat: String, item_id: String, item: Dictionary) -> Control:
	var owned := Style.owns(g, cat, item_id)
	var on: bool = (g.style.decor as Array).has(item_id) if cat == "decor" else str(g.style.get(cat, "")) == item_id
	var cost := int(item.get("cost", 0))
	var b := Button.new()
	b.name = "Style_%s_%s" % [cat, item_id]
	b.theme_type_variation = "CardButton"
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 12)
	b.clip_text = true
	b.text = ("✓ " if on else "") + str(item.name) + ("" if owned else "\n%d cr" % cost)
	b.icon = _icon(cat, item_id, item)
	b.expand_icon = false
	if on:
		b.add_theme_color_override("font_color", UI.GOLD)
	var what := str(item.get("desc", ""))
	if cat == "decor":
		b.tooltip_text = "%s%s\n%s" % [item.name, (" – " + what) if what != "" else "", "Click to pack it away." if on else ("Click to put it in your estates." if owned else "Buy for %d cr; it goes up in your estates." % cost)]
	else:
		b.tooltip_text = "%s %s. %s" % [CAT_NAMES[cat], str(item.name).to_lower(), "You're wearing it." if on and cat in Style.WEAR else ("On your ship." if on else ("Owned: click to switch." if owned else "Buy for %d cr and switch to it." % cost))]
	b.disabled = not owned and g.credits < cost
	b.pressed.connect(func():
		AudioManager.play("click")
		GameState.act(Style.buy(g, cat, item_id))
		phone.refresh())
	return b


func _icon(cat: String, item_id: String, item: Dictionary) -> Texture2D:
	if cat == "decor":
		return Art.tex("props/%s.png" % ("lamp" if item_id == "lamp" else item_id))
	if cat == "decal":
		return null
	var ramp: Array = item.get("ramp", [])
	var key := ",".join(PackedStringArray(ramp))
	if _swatches.has(key):
		return _swatches[key]
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color("#14121c"))
	for i in ramp.size():
		var w := 18 / ramp.size()
		img.fill_rect(Rect2i(1 + i * w, 1, w if i < ramp.size() - 1 else 18 - i * w, 18), Color(ramp[i]))
	var t := ImageTexture.create_from_image(img)
	_swatches[key] = t
	return t


## Your character, standing, drawn 3× with the recoloured sheet.
class _PlayerPreview extends Control:
	const Art = preload("res://scripts/core/art.gd")
	var sheet: Texture2D

	func _init() -> void:
		custom_minimum_size = Vector2(96, 96)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		draw_set_transform(size / 2.0 + Vector2(0, 8), 0.0, Vector2(2.5, 2.5))
		if not Art.draw_character(self, "player", Vector2.DOWN, 0, Vector2(0, 12), sheet):
			draw_circle(Vector2.ZERO, 10.0, Color("#ffd166"))
