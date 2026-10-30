extends "res://scripts/ui/phone/phone_app.gd"
## Contacts & Customers: every named person you have met, grouped by location, with mood (affinity), addiction,
## today's budget, what they like and their recent deals. People you have not met yet only show up as a hint.

const Art = preload("res://scripts/core/art.gd")
const Mixing = preload("res://scripts/core/mixing.gd")
const People = preload("res://scripts/core/people.gd")

var _seen := {}  ## ids already shown in the list; newly met people make the badge count up


func _init() -> void:
	id = "contacts"
	title = "Contacts"
	icon = "app_contacts"
	tint = Color("#4fe3c1")


func badge(g) -> int:
	var n := 0
	for c in g.data.contacts:
		if g.people.get(c.id, {}).get("known", false) and not _seen.has(c.id):
			n += 1
	return n


func home(g, phone) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var unknown: Dictionary = {}  ## location -> count
	for loc in g.data.locations:
		var rows: Array = []
		for c in g.data.contacts:
			if c.location != loc:
				continue
			if g.people.get(c.id, {}).get("known", false):
				rows.append(c)
				_seen[c.id] = true
			else:
				unknown[loc] = int(unknown.get(loc, 0)) + 1
		if rows.is_empty():
			continue
		v.add_child(UI.label(g.data.locations[loc].name.to_upper(), 13, UI.MUTED))
		for c in rows:
			v.add_child(_row(g, phone, c))
	if v.get_child_count() == 0:
		v.add_child(UI.label("No contacts yet.", 15, UI.MUTED))
	for loc in unknown:
		var hint := UI.label("%d more on %s you haven't met. Talk to people there." % [unknown[loc], g.data.locations[loc].name], 13, UI.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(hint)
	return v


func _row(g, phone, c: Dictionary) -> Control:
	var s: Dictionary = g.people[c.id]
	var b := Button.new()
	b.name = "Contact_" + c.id
	b.custom_minimum_size = Vector2(0, 58)
	b.pressed.connect(func():
		AudioManager.play("click")
		phone.push(c.name, func(gg): return detail(gg, c.id)))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	b.add_child(h)
	h.add_child(Portrait.make(c.get("look", ""), 1.5))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UI.label(c.name, 16))
	var line := "%s · %s" % [People.mood(s.affinity), People.addiction_label(s.addiction)]
	col.add_child(UI.label(line, 13, _mood_color(s.affinity)))
	h.add_child(col)
	var ready: bool = g.contact_ready(c.id) and People.budget_left(g, c.id) > 0
	h.add_child(UI.label("●" if ready else "○", 16, UI.ACCENT if ready else UI.MUTED))
	for ch in col.get_children():
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Profile screen of one person.
func detail(g, cid: String) -> Control:
	var c: Dictionary = g.contact(cid)
	var s: Dictionary = g.people[cid]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(Portrait.make(c.get("look", ""), 3.0))
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(UI.label(c.get("job", ""), 14, UI.MUTED))
	who.add_child(UI.label(g.data.locations[c.location].name, 14))
	var now := People.whereabouts(c, People.hour(g))
	if not now.is_empty():
		who.add_child(UI.label("Now: %s" % now.place, 14, UI.ACCENT))
	top.add_child(who)
	v.add_child(top)
	var bio := UI.label(c.get("bio", ""), 14)
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(bio)
	v.add_child(_meter("Affinity", "%s (%+d)" % [People.mood(s.affinity), int(round(s.affinity * 100.0))], (s.affinity + 1.0) / 2.0, _mood_color(s.affinity)))
	v.add_child(_meter("Addiction", "%s (%d%%)" % [People.addiction_label(s.addiction), int(round(s.addiction * 100.0))], s.addiction, UI.WARN))
	var budget := People.daily_budget(g, cid)
	v.add_child(_meter("Budget today", "%d / %d cr" % [People.budget_left(g, cid), budget], float(People.budget_left(g, cid)) / maxf(budget, 1.0), UI.GOLD))
	var prefers := HBoxContainer.new()
	prefers.add_theme_constant_override("separation", 4)
	prefers.add_child(UI.label("Prefers", 14, UI.MUTED))
	for b in c.get("prefers", []):
		prefers.add_child(Art.with_icon(b, UI.label(g.data.bases[b].name, 14)))
	v.add_child(prefers)
	v.add_child(_pair("Loves", g.data.traits[c.likes].name if g.data.traits.has(c.likes) else "-"))
	v.add_child(_pair("Deal size", "up to %d units" % People.max_units(g, cid)))
	var wait: float = float(g.contact_ready_at.get(cid, 0.0)) - g.total_time
	v.add_child(_pair("Status", "Ready to buy" if wait <= 0.0 else "Busy, back in %ds" % int(ceil(wait))))
	v.add_child(UI.label("SCHEDULE", 13, UI.MUTED))
	for e in c.get("schedule", []):
		var cur: bool = not now.is_empty() and e == now
		v.add_child(UI.label("%02d:00–%02d:00  %s" % [int(e.from), int(e.to) % 24, e.place], 14, UI.ACCENT if cur else UI.TEXT))
	v.add_child(UI.label("HISTORY", 13, UI.MUTED))
	if (s.history as Array).is_empty():
		v.add_child(UI.label("No deals yet.", 14, UI.MUTED))
	for h in s.history:
		var l := UI.label("Day %d · %d × %s · %d cr" % [h.day, h.qty, g.item_name(h.product), h.credits], 13)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(Art.with_icon(h.product, l))
	return v


func _pair(k: String, val: String) -> Control:
	var h := HBoxContainer.new()
	var kl := UI.label(k, 14, UI.MUTED)
	kl.custom_minimum_size.x = 110
	h.add_child(kl)
	h.add_child(UI.label(val, 14))
	return h


func _meter(k: String, val: String, ratio: float, color: Color) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.add_child(_pair(k, val))
	var bar := UI.bar(color)
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = clampf(ratio, 0.0, 1.0)
	bar.custom_minimum_size = Vector2(0, 8)
	col.add_child(bar)
	return col


static func _mood_color(affinity: float) -> Color:
	if affinity >= 0.25:
		return UI.ACCENT
	if affinity <= -0.25:
		return UI.WARN
	return UI.TEXT


## The person's character sprite (front-facing idle frame), scaled up for the phone.
class Portrait extends Control:
	const ArtReg = preload("res://scripts/core/art.gd")
	var look := ""
	var zoom := 1.0

	static func make(look_id: String, z: float) -> Control:
		var p := Portrait.new()
		p.look = look_id
		p.zoom = z
		p.custom_minimum_size = Vector2(32, 32) * z
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return p

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#1a1f3d"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(zoom, zoom))
		ArtReg.draw_character(self, look, Vector2.DOWN, 0, Vector2(16, 30))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
