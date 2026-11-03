extends "res://scripts/ui/phone/phone_app.gd"
## Fixers: heat per system, your wanted level and the corrupt officials you can recruit (core: corruption.gd).
## Officials appear once you have docked where they work; recruiting needs you to be there in person, favours
## (clear heat / wanted, divert a sweep) work from anywhere in the official's system.

const People = preload("res://scripts/core/people.gd")
const Corruption = preload("res://scripts/core/corruption.gd")
const ContactsApp = preload("res://scripts/ui/phone/apps/contacts_app.gd")

var _seen := {}


func _init() -> void:
	id = "fixers"
	title = "Fixers"
	icon = ""
	tint = Color("#ff9ad5")


func badge(g) -> int:
	var n := 0
	for o in g.data.officials:
		if People.official_state(g, o.id).known and not _seen.has(o.id):
			n += 1
	return n


func home(g, phone) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(status_block(g))
	var any := false
	for sys in g.data.systems:
		var rows: Array = []
		for o in People.officials_in(g, sys):
			if People.official_state(g, o.id).known:
				rows.append(o)
				_seen[o.id] = true
		if rows.is_empty():
			continue
		any = true
		v.add_child(UI.label(g.data.systems[sys].name.to_upper(), 13, UI.MUTED))
		for o in rows:
			v.add_child(_row(g, phone, o))
	if not any:
		v.add_child(UI.label("No officials on file. Dock at a station and ask around.", 14, UI.MUTED))
	return v


## Heat of every system with a reading, plus the wanted stars.
static func status_block(g) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.name = "Status"
	var stars := Corruption.wanted_stars(g)
	var w := UI.label("Wanted  %s%s  (%d)" % ["★".repeat(stars), "☆".repeat(5 - stars), int(Corruption.wanted(g))], 16, UI.WARN if stars >= 3 else UI.TEXT)
	w.name = "Wanted"
	v.add_child(w)
	for sys in g.data.systems:
		var h := Corruption.system_heat(g, sys)
		var here: bool = sys == g.system
		if not here and h < 1.0:
			continue
		v.add_child(UI.label("Heat %s: %d%s" % [g.data.systems[sys].name, int(h), "  (here)" if here else ""], 14, UI.WARN if h >= 60.0 else UI.MUTED))
	var sw: Dictionary = g.corruption.sweep
	if not sw.is_empty() and int(sw.day) == g.day:
		v.add_child(UI.label("Authority sweep in %s today." % g.data.systems[sw.system].name, 14, UI.WARN))
	var pend: Dictionary = g.corruption.pending
	if not pend.is_empty() and not Corruption.hired(g, "captain", pend.system).is_empty():
		v.add_child(UI.label("Tip-off: sweep in %s tomorrow." % g.data.systems[pend.system].name, 14, UI.GOLD))
	return v


func _row(g, phone, o: Dictionary) -> Control:
	var s := People.official_state(g, o.id)
	var b := Button.new()
	b.name = "Official_" + o.id
	b.custom_minimum_size = Vector2(0, 58)
	b.pressed.connect(func():
		AudioManager.play("click")
		phone.push(o.name, func(gg): return detail(gg, o.id)))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	b.add_child(h)
	h.add_child(ContactsApp.Portrait.make(o.get("look", ""), 1.5))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UI.label(o.name, 16))
	var line: String = g.data.corruption.roles[o.role].name
	if s.hired:
		line += " · " + Corruption.loyalty_label(s.loyalty)
	col.add_child(UI.label(line, 13, UI.ACCENT if s.hired else UI.MUTED))
	h.add_child(col)
	h.add_child(UI.label("●" if s.hired else "○", 16, UI.ACCENT if s.hired else UI.MUTED))
	for ch in col.get_children():
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func detail(g, oid: String) -> Control:
	var o := People.official(g, oid)
	var s := People.official_state(g, oid)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(ContactsApp.Portrait.make(o.get("look", ""), 3.0))
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(UI.label(o.job, 14, UI.MUTED))
	who.add_child(UI.label(g.data.locations[o.location].name, 14))
	who.add_child(UI.label(g.data.corruption.roles[o.role].name, 14, UI.ACCENT))
	top.add_child(who)
	v.add_child(top)
	var bio := UI.label(o.bio, 14)
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(bio)
	var perk := UI.label(g.data.corruption.roles[o.role].perk, 14, UI.GOLD)
	perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(perk)
	v.add_child(_pair("Price", "%d cr, then %d cr/day" % [int(o.recruit_cost), int(o.retainer)]))
	if s.hired:
		v.add_child(_pair("Loyalty", "%s (%d%%)" % [Corruption.loyalty_label(s.loyalty), int(round(s.loyalty * 100.0))]))
		v.add_child(_pair("Favours", str(s.favours)))
		if o.role == "customs":
			v.add_child(_pair("Scans passed", str(s.passes)))
			if g.loc_system(o.location) == g.system:
				v.add_child(_pair("Pass chance", "%d%%" % int(round(Corruption.pass_chance(g) * 100.0))))
	v.add_child(actions(g, oid))
	return v


## Buttons for one official: recruit, or the favours of their role.
static func actions(g, oid: String) -> Control:
	var o := People.official(g, oid)
	var s := People.official_state(g, oid)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if not s.hired:
		var b := UI.button("Recruit (%d cr)" % int(o.recruit_cost), func(): GameState.act(Corruption.recruit(g, oid)))
		b.name = "Recruit_" + oid
		b.disabled = g.location != o.location
		v.add_child(b)
		if g.location != o.location:
			v.add_child(UI.label("Go to %s to make the offer." % g.data.locations[o.location].name, 13, UI.MUTED))
		return v
	if g.loc_system(o.location) != g.system:
		v.add_child(UI.label("%s only helps in %s." % [o.name, g.data.systems[g.loc_system(o.location)].name], 13, UI.MUTED))
		return v
	match o.role:
		"inspector":
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			var b1 := UI.button("-10 heat (%d cr)" % g.bribe_cost(10), func(): GameState.act(g.bribe(10)))
			b1.name = "Fix10_" + oid
			var b2 := UI.button("Clear heat (%d cr)" % g.bribe_cost(g.heat), func(): GameState.act(g.bribe(g.heat)))
			b2.name = "FixAll_" + oid
			h.add_child(b1)
			h.add_child(b2)
			v.add_child(h)
			var b3 := UI.button("Clear wanted (%d cr)" % Corruption.wanted_cost(g, Corruption.wanted(g)), func(): GameState.act(Corruption.clear_wanted(g, Corruption.wanted(g))))
			b3.name = "Wanted_" + oid
			v.add_child(b3)
		"captain":
			var b := UI.button("Divert sweep (%d cr)" % Corruption.divert_cost(g), func(): GameState.act(Corruption.divert_sweep(g)))
			b.name = "Divert_" + oid
			b.disabled = g.corruption.pending.is_empty()
			v.add_child(b)
		"customs":
			v.add_child(UI.label("Nothing to do: the scanner looks away on its own.", 13, UI.MUTED))
	return v


func _pair(k: String, val: String) -> Control:
	var h := HBoxContainer.new()
	var kl := UI.label(k, 14, UI.MUTED)
	kl.custom_minimum_size.x = 110
	h.add_child(kl)
	h.add_child(UI.label(val, 14))
	return h
