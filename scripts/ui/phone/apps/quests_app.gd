extends "res://scripts/ui/phone/phone_app.gd"
## Quests: the quest log. Active quests with their story text and steps (done ✓, current ▸, later ones hidden),
## a Track button for the HUD tracker, the tutorial skip and the list of finished quests. Rules: scripts/core/quests.gd.

const Quests = preload("res://scripts/core/quests.gd")
const Escort = preload("res://scripts/core/escort.gd")

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
	_add_escort(g, phone, v)
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


## Freight escort jobs (E4): the running job with a cancel button, or the jobs on offer where you are docked.
func _add_escort(g, phone, v: VBoxContainer) -> void:
	if Escort.active(g):
		v.add_child(_escort_card(g, phone))
		return
	if g.location == "":
		return
	var offers := Escort.offers_at(g, g.location)
	if offers.is_empty():
		return
	v.add_child(UI.label("FREIGHT ESCORT · JOBS HERE", 12, UI.MUTED))
	for o in offers:
		v.add_child(_offer_card(g, phone, o))


func _offer_card(g, phone, o: Dictionary) -> Control:
	var c := VBoxContainer.new()
	c.name = "Escort_" + str(o.id)
	c.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	var t := UI.label("%s → %s" % [o.name, o.to_name], 15, UI.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(t)
	var label := "Accept"
	var tip := "Take the job: undock, then fly the freighter to %s. Raiders and cartel wings will go for it." % o.to_name
	var off := false
	if o.locked:
		label = "Locked"
		tip = "Not available yet."
		off = true
	elif int(o.cooldown) > 0:
		label = "%dd" % int(o.cooldown)
		tip = "No new cargo for %d more days." % int(o.cooldown)
		off = true
	var b := UI.button(label, func():
		GameState.act(Escort.accept(g, str(o.id)))
		phone.refresh(), 80)
	b.name = "EscortAccept_" + str(o.id)
	b.tooltip_text = tip
	b.disabled = off
	head.add_child(b)
	c.add_child(head)
	var d := UI.label(str(o.desc), 13, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(d)
	c.add_child(UI.label("Pays %d cr, up to +%d for an intact hull · %d raider waves" % [o.reward, o.bonus, o.waves], 13, UI.GOLD))
	return UI.card(c)


func _escort_card(g, phone) -> Control:
	var m: Dictionary = Escort.mission(g)
	var c := VBoxContainer.new()
	c.name = "EscortActive"
	c.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	var t := UI.label("ESCORT · %s" % m.get("name", ""), 15, UI.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var cancel := UI.button("Cut loose", func():
		GameState.act(Escort.abandon(g))
		phone.refresh(), 90)
	cancel.name = "EscortCancel"
	cancel.tooltip_text = "Abandon the job. No pay, no penalty; you can take it again."
	head.add_child(cancel)
	c.add_child(head)
	var dest: String = g.data.locations[m.to].name
	var line := UI.label("Bring the freighter to %s. Hull %d%%, %d waves to come." % [dest, int(round(Escort.hull_ratio(g) * 100.0)), Escort.waves_left(g)], 14)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(line)
	var h := UI.label("Stay within reach: it waits when you fall behind, and it only follows through a gate if you jump while it is close.", 12, UI.MUTED)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(h)
	c.add_child(UI.label("Pays %d cr, up to +%d for an intact hull" % [int(m.reward), int(m.get("bonus", 0))], 13, UI.GOLD))
	return UI.card(c)
