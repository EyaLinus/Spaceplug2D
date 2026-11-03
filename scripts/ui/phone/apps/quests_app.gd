extends "res://scripts/ui/phone/phone_app.gd"
## Quests: what you are working on, step by step, with a button to pin one to the HUD tracker. Finished quests are listed
## below. Rules live in scripts/core/quests.gd; this is only the view.

const Quests = preload("res://scripts/core/quests.gd")


func _init() -> void:
	id = "quests"
	title = "Quests"
	icon = ""
	tint = Color("#ffd166")


func badge(g) -> int:
	return g.quests_unseen


func home(g, phone) -> Control:
	g.quests_unseen = 0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var act: Array = Quests.active(g)
	if act.is_empty():
		var none := UI.label("Nothing to do right now. New jobs show up here.", 14, UI.MUTED)
		none.name = "NoQuests"
		v.add_child(none)
	else:
		v.add_child(UI.label("ACTIVE", 12, UI.MUTED))
	for q in act:
		v.add_child(_active_card(g, phone, q))
	var finished: Array = Quests.done(g)
	if not finished.is_empty():
		v.add_child(UI.label("DONE (%d)" % finished.size(), 12, UI.MUTED))
		for q in finished:
			var l := UI.label("✓ " + str(q.title), 14, UI.MUTED)
			l.name = "Done_" + str(q.id)
			v.add_child(l)
	return v


func _active_card(g, phone, q: Dictionary) -> Control:
	var qid := str(q.id)
	var st: Dictionary = Quests.step_def(g, qid)
	var steps: Array = q.steps
	var col := VBoxContainer.new()
	col.name = "Quest_" + qid
	col.add_theme_constant_override("separation", 3)
	var pinned: bool = Quests.tracked(g) == qid
	col.add_child(UI.label(str(q.title) + ("  ·  tracked" if pinned else ""), 16, UI.GOLD))
	var d := UI.label(str(q.desc), 12, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(d)
	var cur := int(g.quests[qid].step)
	for i in steps.size():
		var prefix := "✓ " if i < cur else ("> " if i == cur else "· ")
		var text: String = prefix + str(steps[i].text)
		if i == cur and Quests.progress_text(g, qid) != "":
			text += "  (%s)" % Quests.progress_text(g, qid)
		var l := UI.label(text, 14, UI.TEXT if i == cur else UI.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	var rw := int(q.get("reward", {}).get("credits", 0))
	if rw > 0:
		col.add_child(UI.label("Reward: %d cr" % rw, 13, UI.ACCENT))
	if not pinned and not st.is_empty():
		var b := Button.new()
		b.text = "Track"
		b.name = "Track_" + qid
		b.custom_minimum_size.x = 90
		b.pressed.connect(func():
			AudioManager.play("click")
			Quests.track(g, qid)
			phone.refresh())
		col.add_child(b)
	return UI.card(col, true)
