extends "res://scripts/ui/phone/phone_app.gd"
## Quests: the quest log. Active quests with their story text and steps (done ✓, current ▸, later ones hidden),
## a Track button for the HUD tracker, the tutorial skip and the list of finished quests. Rules: scripts/core/quests.gd.

const Quests = preload("res://scripts/core/quests.gd")

var _seen := {}  ## quest id -> step index the player has looked at (runtime): the badge counts news


func _init() -> void:
	id = "quests"
	title = "Quests"
	icon = "app_quests"
	tint = Color("#ffd166")


func badge(g) -> int:
	var n := 0
	for qid in g.quests.active:
		if int(_seen.get(qid, -1)) != Quests.step_index(g, qid):
			n += 1
	return n


func home(g, phone) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	if (g.quests.active as Array).is_empty():
		var none := UI.label("No open quests right now.", 14, UI.MUTED)
		none.name = "NoQuests"
		v.add_child(none)
	for qid in g.quests.active:
		_seen[qid] = Quests.step_index(g, qid)
		v.add_child(_quest_card(g, phone, qid))
	if Quests.in_tutorial(g):
		var skip := UI.button("Skip tutorial", func():
			Quests.skip_tutorial(g)
			phone.refresh())
		skip.name = "SkipTutorial"
		skip.tooltip_text = "Ends Okka's tutorial quests without their rewards."
		v.add_child(skip)
	var done: Array = g.quests.done
	if not done.is_empty():
		v.add_child(UI.label("COMPLETED", 12, UI.MUTED))
		for qid in done:
			var q: Dictionary = Quests.defs(g).get(qid, {})
			v.add_child(UI.label("✓ %s" % q.get("title", qid), 14, UI.MUTED))
	return v


func _quest_card(g, phone, qid: String) -> Control:
	var q: Dictionary = Quests.defs(g)[qid]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.name = "Quest_" + qid
	var head := HBoxContainer.new()
	var tag := "TUTORIAL" if q.get("tutorial", false) else ("MAIN" if q.get("main", false) else "SIDE")
	var t := UI.label("%s · %s" % [tag, q.get("title", qid)], 15, UI.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(t)
	if Quests.tracked(g) == qid:
		head.add_child(UI.label("◉ tracked", 12, UI.ACCENT))
	else:
		var tb := UI.button("Track", func():
			Quests.track(g, qid)
			phone.refresh(), 70)
		tb.name = "Track_" + qid
		head.add_child(tb)
	v.add_child(head)
	if q.has("giver"):
		v.add_child(UI.label(str(q.giver), 12, UI.ACCENT))
	var intro := UI.label(str(q.get("intro", "")), 13, UI.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(intro)
	var cur := Quests.step_index(g, qid)
	var steps := Quests.steps(g, qid)
	for i in steps.size():
		if i > cur:
			v.add_child(UI.label("○ …", 13, UI.MUTED))
			break
		var s: Dictionary = steps[i]
		var line := ""
		if i < cur:
			line = "✓ " + str(s.text)
		else:
			var prog := Quests.progress_text(g, qid)
			line = "▸ " + str(s.text) + ("  (%s)" % prog if prog != "" else "")
		var l := UI.label(line, 14, UI.MUTED if i < cur else UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		if i == cur and s.has("hint"):
			var h := UI.label(str(s.hint), 12, UI.MUTED)
			h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(h)
	var rw: Dictionary = q.get("reward", {})
	var parts: Array = []
	if rw.has("credits"):
		parts.append("%d cr" % int(rw.credits))
	for item in rw.get("items", {}):
		parts.append("%d × %s" % [int(rw.items[item]), g.item_name(item)])
	for cid in rw.get("meet", []):
		parts.append("contact: %s" % g.contact(cid).get("name", cid))
	if rw.has("days"):
		parts.append("+%d days on the debt" % int(rw.days))
	if not parts.is_empty():
		v.add_child(UI.label("Reward: " + ", ".join(PackedStringArray(parts)), 13, UI.GOLD))
	return UI.card(v)
