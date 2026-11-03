extends "res://scripts/ui/phone/phone_app.gd"
## HR: hire lab hands and stockers (wage per day, skill, loyalty), assign them to your estates, set the auto recipe and
## look after the estate storage. All rules live in scripts/core/workers.gd; this is only the view.

const Workers = preload("res://scripts/core/workers.gd")
const Mixing = preload("res://scripts/core/mixing.gd")


func _init() -> void:
	id = "hr"
	title = "HR"
	icon = "app_hr"
	tint = Color("#ffd166")


## Badge = people about to quit.
func badge(g) -> int:
	var n := 0
	for w in g.workers:
		if float(w.loyalty) < 0.25:
			n += 1
	return n


func home(g, phone) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var c: Dictionary = Workers.cfg(g)
	v.add_child(UI.label("Crew %d/%d · wages %d cr/day" % [g.workers.size(), int(c.max_staff), Workers.wage_total(g)], 15, UI.GOLD))
	v.add_child(UI.label("CREW", 13, UI.MUTED))
	if g.workers.is_empty():
		v.add_child(UI.label("Nobody on the payroll.", 14, UI.MUTED))
	for w in g.workers:
		v.add_child(_worker_row(g, phone, Workers.candidate(g, w.id), w, "Crew_"))
	v.add_child(UI.label("ESTATES", 13, UI.MUTED))
	if g.estates.is_empty():
		v.add_child(UI.label("You own no estate. Workers need one to work in.", 14, UI.MUTED))
	for eid in g.estates:
		var b := UI.button("%s · %s" % [g.data.estates[eid].name, _estate_state(g, eid)], func(): phone.push(g.data.estates[eid].name, func(gg): return estate(gg, phone, eid)))
		b.name = "EstateRow_" + eid
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
	v.add_child(UI.label("FOR HIRE", 13, UI.MUTED))
	var open: Array = Workers.available(g)
	if open.is_empty():
		v.add_child(UI.label("Nobody left to hire.", 14, UI.MUTED))
	for cand in open:
		v.add_child(_worker_row(g, phone, cand, {}, "Hire_"))
	return v


func _estate_state(g, eid: String) -> String:
	if not g.estates[eid].job.is_empty():
		return "cooking"
	return "idle" if Workers.blocker(g, eid) != "" else "ready"


func _worker_row(g, phone, cand: Dictionary, w: Dictionary, prefix: String) -> Control:
	var b := Button.new()
	b.name = prefix + cand.id
	b.custom_minimum_size = Vector2(0, 54)
	b.pressed.connect(func():
		AudioManager.play("click")
		phone.push(cand.name, func(gg): return detail(gg, cand.id)))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.add_child(UI.label(cand.name, 16))
	var sub := "%s · skill %d%%" % [Workers.cfg(g).roles[cand.role].name, int(round(float(cand.skill) * 100.0))]
	if not w.is_empty():
		sub += " · " + (str(g.data.estates[w.estate].name) if w.estate != "" else "off duty")
	col.add_child(UI.label(sub, 13, UI.MUTED))
	h.add_child(col)
	h.add_child(UI.label("%d cr/day" % int(cand.wage), 14, UI.GOLD))
	b.add_child(h)
	for ch in col.get_children() + h.get_children():
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Profile of one candidate or hired worker: stats, hire/fire, assignment.
func detail(g, wid: String) -> Control:
	var cand: Dictionary = Workers.candidate(g, wid)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if cand.is_empty():
		v.add_child(UI.label("Gone.", 15, UI.MUTED))
		return v
	var role: Dictionary = Workers.cfg(g).roles[cand.role]
	v.add_child(UI.label(role.name, 14, UI.MUTED))
	v.add_child(_wrap(cand.get("bio", ""), 14))
	v.add_child(_wrap(role.desc, 13, UI.MUTED))
	v.add_child(_meter("Skill", "%d%%" % int(round(float(cand.skill) * 100.0)), float(cand.skill), UI.ACCENT))
	v.add_child(_pair("Wage", "%d cr/day" % int(cand.wage)))
	var i := Workers.find(g, wid)
	if i < 0:
		v.add_child(_meter("Loyalty", "%d%%" % int(round(float(cand.loyalty) * 100.0)), float(cand.loyalty), UI.GOLD))
		var cost := Workers.hire_cost(g, wid)
		var hb := UI.button("Hire (%d cr signing fee)" % cost, func(): Workers.hire(g, wid))
		hb.name = "HireBtn"
		hb.disabled = g.credits < cost or g.workers.size() >= int(Workers.cfg(g).max_staff)
		v.add_child(hb)
		return v
	var w: Dictionary = g.workers[i]
	v.add_child(_meter("Loyalty", "%d%%" % int(round(float(w.loyalty) * 100.0)), float(w.loyalty), UI.WARN if float(w.loyalty) < 0.3 else UI.GOLD))
	v.add_child(UI.label("ASSIGNMENT", 13, UI.MUTED))
	if g.estates.is_empty():
		v.add_child(UI.label("Buy an estate first.", 14, UI.MUTED))
	for eid in g.estates:
		var here: bool = w.estate == eid
		var ab := UI.button("%s%s" % [g.data.estates[eid].name, "  ✓ working here" if here else ""], func(): Workers.assign(g, wid, "" if here else eid))
		ab.name = "Assign_%s_%s" % [wid, eid]
		ab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(ab)
	var fb := UI.button("Fire", func(): Workers.fire(g, wid))
	fb.name = "Fire_" + wid
	v.add_child(fb)
	return v


## One estate: crew, auto recipe, job, storage.
func estate(g, _phone, eid: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if not g.estates.has(eid):
		return v
	var e: Dictionary = g.estates[eid]
	for role in ["lab_hand", "stocker"]:
		var w := Workers.at(g, eid, role)
		var txt: String = Workers.candidate(g, w.id).name if not w.is_empty() else "nobody"
		v.add_child(_pair(str(Workers.cfg(g).roles[role].name), txt))
	v.add_child(UI.label("AUTO RECIPE", 13, UI.MUTED))
	var opt := OptionButton.new()
	opt.name = "Recipe_" + eid
	opt.add_item("Off")
	var cur := 0
	var bases: Array = g.data.bases.keys()
	for k in bases.size():
		opt.add_item(g.data.bases[bases[k]].name)
		if not e.recipe.is_empty() and e.recipe.base == bases[k]:
			cur = k + 1
	opt.select(cur)
	opt.item_selected.connect(func(idx: int):
		var q: int = int(e.recipe.get("qty", g.lab_capacity()))
		Workers.set_recipe(g, eid, "" if idx == 0 else bases[idx - 1], [], q))
	v.add_child(opt)
	if not e.recipe.is_empty():
		var qrow := HBoxContainer.new()
		var ql := UI.label("Batch %d units  " % int(e.recipe.qty), 14)
		ql.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qrow.add_child(ql)
		var minus := UI.button("-", func(): Workers.set_recipe(g, eid, e.recipe.base, e.recipe.additives, int(e.recipe.qty) - 1), 36)
		minus.name = "QtyMinus_" + eid
		var plus := UI.button("+", func(): Workers.set_recipe(g, eid, e.recipe.base, e.recipe.additives, int(e.recipe.qty) + 1), 36)
		plus.name = "QtyPlus_" + eid
		qrow.add_child(minus)
		qrow.add_child(plus)
		v.add_child(qrow)
	var why := Workers.blocker(g, eid)
	if not e.job.is_empty():
		var bar := UI.bar(UI.ACCENT)
		bar.max_value = float(e.job.total)
		bar.value = float(e.job.total) - float(e.job.remaining)
		v.add_child(UI.label("Cooking %d × %s" % [int(e.job.qty), g.item_name(e.job.product)], 14, UI.ACCENT))
		v.add_child(bar)
	elif why != "":
		v.add_child(_wrap(why, 14, UI.MUTED))
	else:
		v.add_child(_wrap("Waiting for ingredients on the %s." % ("bench" if not Workers.at(g, eid, "stocker").is_empty() else "storage shelf"), 14, UI.MUTED))
	v.add_child(UI.label("STORAGE", 13, UI.MUTED))
	_items(g, v, "Shelf", e.storage)
	_items(g, v, "Bench", e.bench)
	_items(g, v, "Output tray", e.out)
	var inside: bool = g.inside_estate == eid
	var sb := UI.button("Stock raws from cargo", func():
		for k in g.cargo.keys():
			if not Mixing.is_product(k):
				Workers.deposit(g, eid, k, int(g.cargo[k])))
	sb.name = "StoreRaws"
	sb.disabled = not inside
	v.add_child(sb)
	var tb := UI.button("Take products to cargo", func(): Workers.take_products(g, eid))
	tb.name = "TakeProducts"
	tb.disabled = not inside
	v.add_child(tb)
	if not inside:
		v.add_child(UI.label("Stand inside the estate to move goods.", 13, UI.MUTED))
	return v


func _items(g, v: VBoxContainer, label: String, items: Dictionary) -> void:
	var parts: Array = []
	for k in items:
		parts.append("%d %s" % [int(items[k]), g.item_name(k)])
	v.add_child(_wrap("%s: %s" % [label, ", ".join(PackedStringArray(parts)) if not parts.is_empty() else "empty"], 14))


func _wrap(text: String, size: int, color := UI.TEXT) -> Label:
	var l := UI.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


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
