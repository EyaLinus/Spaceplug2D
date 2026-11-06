extends "res://scripts/ui/phone/phone_app.gd"
## Escort: freighter jobs. Take one while docked at its start location, then undock and keep the freighter alive until
## she reaches the end of her route. Rules, contracts and numbers: scripts/core/escort.gd, content.json "escort".

const Escort = preload("res://scripts/core/escort.gd")


func _init() -> void:
	id = "escort"
	title = "Escort"
	icon = ""
	tint = Color("#4fe3c1")


func badge(g) -> int:
	return Escort.available(g).size()


func home(g, phone) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	if Escort.is_active(g):
		v.add_child(_active_card(g, phone))
	else:
		var here := Escort.available(g)
		if here.is_empty():
			var none := UI.label("No freighter needs a guard at your current stop.", 14, UI.MUTED)
			none.name = "NoEscort"
			v.add_child(none)
		for id in here:
			v.add_child(_job_card(g, phone, id, true))
	var other := Escort.elsewhere(g).filter(func(i): return not Escort.is_active(g) or str(Escort.active(g).id) != i)
	if not other.is_empty():
		v.add_child(UI.label("ELSEWHERE", 12, UI.MUTED))
		for id in other:
			v.add_child(_job_card(g, phone, id, false))
	if not (g.escort.done as Array).is_empty():
		v.add_child(UI.label("DELIVERED", 12, UI.MUTED))
		for id in g.escort.done:
			v.add_child(UI.label("✓ %s" % Escort.def(g, str(id)).get("title", id), 14, UI.MUTED))
	return v


func _route_text(g, id: String) -> String:
	var names: Array = []
	for loc in Escort.route(g, id):
		names.append(str(g.data.locations[loc].name))
	return " → ".join(PackedStringArray(names))


func _job_card(g, phone, id: String, here: bool) -> Control:
	var d: Dictionary = Escort.def(g, id)
	var v := VBoxContainer.new()
	v.name = "EscortJob_" + id
	v.add_theme_constant_override("separation", 4)
	v.add_child(UI.label("%s" % d.title, 15, UI.GOLD))
	v.add_child(UI.label(str(d.client), 12, UI.ACCENT))
	var desc := UI.label(str(d.desc), 13, UI.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var r := UI.label("Route: " + _route_text(g, id), 13)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(r)
	v.add_child(UI.label("Reward %d cr (+ up to %d%% for hull left)%s" % [int(d.reward), int(float(Escort.rules(g).get("hull_bonus", 0.0)) * 100.0),
		(", fine %d cr if she dies" % int(d.fail_fine)) if int(d.get("fail_fine", 0)) > 0 else ""], 13, UI.GOLD))
	if here:
		var b := UI.accent_button("Take the job", func():
			GameState.act(Escort.accept(g, id))
			phone.refresh())
		b.name = "EscortAccept_" + id
		b.tooltip_text = "Accept, then undock: the freighter launches with you."
		v.add_child(b)
	else:
		var why := "Starts at %s." % g.data.locations[Escort.route(g, id)[0]].name
		if g.day < Escort.min_day(g, id):
			why += " Available from day %d." % Escort.min_day(g, id)
		var l := UI.label(why, 12, UI.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	return UI.card(v)


func _active_card(g, phone) -> Control:
	var a: Dictionary = Escort.active(g)
	var d: Dictionary = Escort.def(g, str(a.id))
	var v := VBoxContainer.new()
	v.name = "EscortActive"
	v.add_theme_constant_override("separation", 4)
	v.add_child(UI.label("ACTIVE · %s" % d.title, 15, UI.GOLD))
	var h := UI.label(Escort.hint(g), 14)
	h.name = "EscortStatus"
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(h)
	var r := UI.label("Route: " + _route_text(g, str(a.id)), 13, UI.MUTED)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(r)
	var cancel := UI.button("Give up" if str(a.status) == "enroute" else "Cancel job", func():
		GameState.act(Escort.cancel(g))
		phone.refresh())
	cancel.name = "EscortCancel"
	cancel.tooltip_text = "Before launch this is free. Once she is under way it counts as a failed job (fine %d cr)." % int(d.get("fail_fine", 0))
	v.add_child(cancel)
	return UI.card(v)
