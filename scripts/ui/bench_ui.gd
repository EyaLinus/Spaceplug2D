extends Control
## Station overlay on foot (G2): pressing [E] at a production station inside an estate opens this instead of a
## lab menu. What it shows depends on the tray (core: scripts/core/bench.gd):
##   start – prep station, no tray: pick the raw and how many units go on the tray
##   mix   – Mixing Station while additives can still go in: ingredient shelf with a live result preview
##   play  – the tray's next station: its minigame runs right away, the score goes into the batch
##   wait  – any other station: where the tray has to go next
## A strip along the bottom shows the tray's whole line (done / next / open). Esc closes; a running minigame
## counts nothing when it is closed early, the station just stays next.

const UI = preload("res://scripts/ui/ui_theme.gd")
const Art = preload("res://scripts/core/art.gd")
const Bench = preload("res://scripts/core/bench.gd")
const Mixing = preload("res://scripts/core/mixing.gd")
const Production = preload("res://scripts/core/production.gd")
const Registry = preload("res://scripts/ui/minigames/registry.gd")
const Runner = preload("res://scripts/ui/minigames/minigame_runner.gd")

signal take_down_requested(index: int)

var autoplay := false  ## tests: minigame bots play, results continue on their own
var station_id := ""
var building_index := -1
var mode := ""
var current: Control  ## running minigame
var last_result: Dictionary = {}
var _base := ""
var _qty := 5
var _adds: Array = []
var _wait := 0.0
var _panel: PanelContainer
var _body: VBoxContainer
var _title: Label
var _sub: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(880, 0)
	center.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = UI.label("", 24, UI.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	head.add_child(UI.button("Close [Esc]", close))
	_sub = UI.label("", 15, UI.MUTED)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.custom_minimum_size.x = 860
	v.add_child(_sub)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	v.add_child(_body)
	visible = false


func is_open() -> bool:
	return visible


## Opens the overlay for building `index` (a station) of the estate the player stands in.
func open_station(id: String, index: int) -> void:
	var g = GameState.game
	station_id = id
	building_index = index
	last_result = {}
	var st: Dictionary = g.data.stations[id]
	_title.text = st.name
	_sub.text = "%s  ·  improves %s" % [st.get("hint", ""), st.affects]
	var m: Dictionary = Bench.use_mode(g, id)
	mode = m.mode
	if mode == "start":
		var bases: Array = _startable(g)
		if _base == "" or not _base in bases:
			_base = bases[0] if not bases.is_empty() else ""
	if mode == "mix":
		_adds = []
	visible = true
	if mode == "play":
		_play()
	else:
		_rebuild()


func close() -> void:
	_clear_minigame()
	visible = false
	mode = ""


func _startable(g) -> Array:
	return Bench.bases_starting_at(g.data, station_id)


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	var g = GameState.game
	match mode:
		"start": _build_start(g)
		"mix": _build_mix(g)
		"wait": _build_wait(g)
		"result": _build_result(g)
	_body.add_child(_line_strip(g))
	_body.add_child(_footer(g))


# ---------------------------------------------------------------- start: pick raw + amount

func _build_start(g) -> void:
	_body.add_child(UI.heading("Start a batch"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_body.add_child(row)
	for b in _startable(g):
		var raw: String = g.data.bases[b].raw
		var have := int(g.cargo.get(raw, 0))
		var card := Button.new()
		card.name = "Base_" + b
		card.theme_type_variation = "CardButton"
		card.toggle_mode = true
		card.button_pressed = b == _base
		card.custom_minimum_size = Vector2(196, 74)
		card.icon = Art.icon_for(raw)
		card.text = "T%d %s\n%s ×%d" % [int(g.data.bases[b].get("tier", 1)), g.data.bases[b].name, g.item_name(raw), have]
		card.tooltip_text = "%s from %s. Base value %d cr per unit. Heat ×%.1f." % [g.data.bases[b].name, g.item_name(raw),
			int(Mixing.value(g.data, Mixing.key(b, [g.data.bases[b].innate]))), float(g.data.bases[b].get("heat_mult", 1.0))]
		card.disabled = have <= 0
		card.pressed.connect(func():
			_base = b
			_rebuild())
		row.add_child(card)
	if _base == "":
		_body.add_child(UI.label("No raws for this station in your hold. Buy them at a market or order them by phone.", 16, UI.WARN))
		return
	var raw: String = g.data.bases[_base].raw
	var cap := mini(g.lab_capacity(), int(g.cargo.get(raw, 0)))
	_qty = clampi(_qty, 1, maxi(cap, 1))
	var q := HBoxContainer.new()
	q.add_theme_constant_override("separation", 8)
	_body.add_child(q)
	q.add_child(UI.label("Units on the tray:", 17))
	q.add_child(_step_btn("−", -1, cap))
	var ql := UI.label("%d" % _qty, 22, UI.GOLD)
	ql.name = "Qty"
	ql.custom_minimum_size.x = 40
	ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.add_child(ql)
	q.add_child(_step_btn("+", 1, cap))
	q.add_child(_step_btn("Max", 99, cap))
	q.add_child(UI.label("Rig Mk %d holds %d per batch" % [g.upgrades.lab + 1, g.lab_capacity()], 14, UI.MUTED))
	var go := UI.accent_button("Start & work the %s [E]" % g.data.stations[station_id].name, _confirm, 0)
	go.name = "StartBatch"
	go.disabled = cap <= 0
	_body.add_child(go)


func _step_btn(text: String, d: int, cap: int) -> Button:
	var b := UI.button(text, func():
		_qty = clampi(_qty + d, 1, maxi(cap, 1)) if d != 99 else maxi(cap, 1)
		_rebuild(), 44)
	return b


# ---------------------------------------------------------------- mix: additive shelf

func _build_mix(g) -> void:
	var t: Dictionary = Bench.tray(g)
	_body.add_child(UI.heading("Ingredient shelf · tray: %d %s" % [t.qty, g.data.bases[t.base].name]))
	_body.add_child(UI.label("Pick up to %d additives in the order you pour them. Each needs %d units in your hold." % [Bench.MAX_ADDITIVES, t.qty], 15, UI.MUTED))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	for a in g.data.additives:
		var have := int(g.cargo.get(a, 0))
		var card := Button.new()
		card.name = "Add_" + a
		card.theme_type_variation = "CardButton"
		card.custom_minimum_size = Vector2(206, 64)
		card.icon = Art.icon_for(a)
		var pos := _adds.find(a)
		card.text = "%s%s\nhave %d" % ["%d. " % (pos + 1) if pos >= 0 else "", g.item_name(a), have]
		card.tooltip_text = UI.item_tip(g, a)
		card.toggle_mode = true
		card.button_pressed = pos >= 0
		card.disabled = pos < 0 and (have < int(t.qty) or _adds.size() >= Bench.MAX_ADDITIVES)
		card.pressed.connect(func():
			if a in _adds:
				_adds.erase(a)
			else:
				_adds.append(a)
			_rebuild())
		grid.add_child(card)
	var pv: Dictionary = Bench.preview(g, t.base, _adds)
	var res := RichTextLabel.new()
	res.name = "Preview"
	res.bbcode_enabled = true
	res.fit_content = true
	res.scroll_active = false
	var chips: Array = []
	for tr in pv.traits:
		chips.append("[color=%s]%s[/color]" % [g.data.traits[tr].color, g.data.traits[tr].name])
	res.text = "Result: [b]%s[/b]  %s   ·  about [color=#ffd166]%d cr[/color] per unit (Standard)" % [
		g.data.bases[t.base].name, ", ".join(PackedStringArray(chips)), pv.value]
	_body.add_child(UI.card(res, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_body.add_child(row)
	var go := UI.accent_button("Pour the mix [E]", _confirm)
	go.name = "MixGo"
	go.disabled = _adds.is_empty()
	row.add_child(go)
	var skip := UI.button("No additives", func():
		GameState.act(Bench.mix(g, []))
		close())
	skip.name = "MixSkip"
	row.add_child(skip)


# ---------------------------------------------------------------- wait / result

func _build_wait(g) -> void:
	var m: Dictionary = Bench.use_mode(g, station_id)
	_body.add_child(UI.label(m.msg, 18, UI.TEXT))


func _build_result(g) -> void:
	_body.add_child(UI.heading(last_result.get("title", "")))
	var l := UI.label(last_result.get("text", ""), 17, UI.TEXT)
	l.name = "ResultText"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 840
	_body.add_child(l)
	var b := UI.accent_button("Continue [E]", close)
	b.name = "Continue"
	_body.add_child(b)


## Station chips of the tray's line: ✓ done, ▶ next, · open.
func _line_strip(g) -> Control:
	var h := HBoxContainer.new()
	h.name = "LineStrip"
	h.add_theme_constant_override("separation", 6)
	var t: Dictionary = Bench.tray(g)
	if t.is_empty():
		h.add_child(UI.label("No tray on the go. Batches start at the Trim Table (weed) or the Precursor Scale.", 14, UI.MUTED))
		return h
	h.add_child(UI.label("Tray %d × %s:" % [t.qty, g.data.bases[t.base].name], 15, UI.GOLD))
	var nxt: String = Bench.next_station(g, t)
	var line: Array = Bench.line(g, t)
	if Bench.can_mix(g, t) and not Bench.MIX in line:
		line = Production.stations_for(g.data, t.base, ["_"])
	for st in line:
		var mark := "✓ " if st in t.done else ("▶ " if st == nxt else "· ")
		var col: Color = UI.ACCENT if st in t.done else (UI.GOLD if st == nxt else UI.MUTED)
		if st == Bench.MIX and not t.mixed:
			mark = "± "
		h.add_child(UI.label(mark + g.data.stations[st].name, 14, col))
	return h


func _footer(g) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	if not Bench.tray(g).is_empty():
		var scrap := UI.button("Scrap tray", func():
			GameState.act(Bench.abandon(g))
			_rebuild())
		scrap.name = "Scrap"
		scrap.tooltip_text = "Throw the batch away. Raws and additives go to your stash."
		h.add_child(scrap)
	var est: Dictionary = g.estates.get(g.inside_estate, {})
	if building_index >= 0 and building_index < est.get("buildings", []).size() and not est.buildings[building_index].get("fixed", false):
		var refund := int(round(int(g.data.buildables[station_id].cost) * float(g.data.estate_refund)))
		var td := UI.button("Take down (+%d cr)" % refund, func():
			close()
			take_down_requested.emit(building_index))
		td.name = "TakeDown"
		h.add_child(td)
	return h


# ---------------------------------------------------------------- confirm + minigame

func _confirm() -> void:
	var g = GameState.game
	if mode == "start":
		if GameState.act(Bench.begin(g, station_id, _base, _qty)).ok:
			_play()
	elif mode == "mix":
		if GameState.act(Bench.mix(g, _adds)).ok:
			_play()
	elif mode == "result":
		close()


func _play() -> void:
	var g = GameState.game
	var t: Dictionary = Bench.tray(g)
	if t.is_empty() or Bench.next_station(g, t) != station_id:
		mode = "wait"
		_rebuild()
		return
	mode = "play"
	for c in _body.get_children():
		c.queue_free()
	var st: Dictionary = g.data.stations[station_id]
	_title.text = "%s · %d × %s" % [st.name, t.qty, g.data.bases[t.base].name]
	_sub.text = st.get("hint", "")
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(840, 340)
	_body.add_child(holder)
	current = Registry.MINIGAMES[st.minigame].new()
	current.setup({"base": t.base, "tier": int(g.data.bases[t.base].get("tier", 1)), "additives": t.additives,
		"qty": t.qty, "data": g.data, "seed": randi()})
	current.finished.connect(_on_finished)
	holder.add_child(current)
	_body.add_child(UI.label("Esc stops without a score: the station stays next on the tray.", 14, UI.MUTED))


func _on_finished(score: float) -> void:
	var g = GameState.game
	var st: Dictionary = g.data.stations[station_id]
	var r: Dictionary = GameState.act(Bench.record(g, station_id, score))
	AudioManager.play("buy" if score >= 0.7 else ("click" if score >= 0.35 else "error"))
	var text := "%s: %d%%  →  %s." % [st.name, int(score * 100.0), Runner.effect_text(station_id, score)]
	var title := "Station done"
	if r.ok and Bench.tray(g).is_empty():
		title = "Batch in the cooker"
		text += "\n" + str(r.msg) + " Pick it up from the stash crate when it is done."
	elif r.ok:
		text += "\nNext: %s." % g.data.stations[Bench.next_station(g, Bench.tray(g))].name
	else:
		text += "\n" + str(r.msg)
	last_result = {"title": title, "text": text, "score": score, "ok": r.ok}
	_wait = 0.9


func _clear_minigame() -> void:
	if current != null:
		current.queue_free()
		current = null


func _process(dt: float) -> void:
	if not visible:
		return
	if _wait > 0.0:
		_wait -= dt
		if _wait <= 0.0:
			_clear_minigame()
			mode = "result"
			_title.text = GameState.data.stations[station_id].name
			_rebuild()
		return
	if current != null and autoplay:
		current.bot_input(dt)
	elif autoplay and mode == "result":
		close()


func _input(ev: InputEvent) -> void:
	if not visible or not ev is InputEventKey or ev.echo:
		return
	get_viewport().set_input_as_handled()
	if ev.keycode == KEY_ESCAPE:
		if ev.pressed:
			close()
	elif current != null and _wait <= 0.0:
		current.key(ev.keycode, ev.pressed)
	elif ev.pressed and ev.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER]:
		if mode in ["start", "mix", "result"]:
			_confirm()
		elif mode == "wait":
			close()
