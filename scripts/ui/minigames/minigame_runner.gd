extends Control
## Runs a batch through its station minigames one after another (Production.stations_for), collects the scores
## and starts the batch with them. Ingredients are only consumed at the end; Esc skips the remaining stations
## (they count as Standard), so cancelling never refunds a bad roll. The lab panel owns one runner; an estate
## building can call start() with its own station list.

const UI = preload("res://scripts/ui/ui_theme.gd")
const Production = preload("res://scripts/core/production.gd")

const Registry = preload("res://scripts/ui/minigames/registry.gd")

signal closed

var autoplay := false  ## tests: let every minigame's bot play
var plan: Array = []
var scores: Dictionary = {}
var index := 0
var current: Control  ## running minigame, null between stations
var result: Dictionary = {}  ## start_batch result once the run is complete
var _batch: Dictionary = {}
var _wait := 0.0
var _title: Label
var _hint: Label
var _status: Label
var _holder: CenterContainer
var _info: Label
var _btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	_title = UI.label("", 22, UI.ACCENT)
	v.add_child(_title)
	_hint = UI.label("", 15, UI.MUTED)
	_hint.custom_minimum_size.x = 820
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_hint)
	_holder = CenterContainer.new()
	_holder.custom_minimum_size = Vector2(820, 330)
	v.add_child(_holder)
	_info = UI.label("", 17, UI.GOLD)
	v.add_child(_info)
	var row := HBoxContainer.new()
	_status = UI.label("", 15, UI.MUTED)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
	_btn = UI.button("Skip the rest [Esc]", _escape, 200)
	row.add_child(_btn)
	v.add_child(row)
	visible = false


func running() -> bool:
	return visible and result.is_empty()


## Validates and starts the minigame chain. Returns the check result ({ok, msg}).
func start(base: String, additives: Array, qty: int) -> Dictionary:
	var g = GameState.game
	var chk: Dictionary = g.check_batch(base, additives, qty)
	if not chk.ok:
		return chk
	_batch = {"base": base, "additives": additives.duplicate(), "qty": qty}
	plan = Production.stations_for(g.data, base, additives)
	scores = {}
	result = {}
	index = -1
	visible = true
	_btn.text = "Skip the rest [Esc]"
	_next()
	return chk


func abort() -> void:
	_clear_current()
	visible = false
	result = {}


func _next() -> void:
	_clear_current()
	index += 1
	if index >= plan.size():
		_complete()
		return
	var g = GameState.game
	var st: Dictionary = g.data.stations[plan[index]]
	_title.text = "Step %d/%d · %s" % [index + 1, plan.size(), st.name]
	_hint.text = st.get("hint", "")
	_info.text = ""
	_status.text = "Esc skips the remaining stations (they count as Standard)."
	current = Registry.MINIGAMES[st.minigame].new()
	current.setup({"base": _batch.base, "tier": int(g.data.bases[_batch.base].get("tier", 1)), "additives": _batch.additives,
		"qty": _batch.qty, "data": g.data, "seed": randi()})
	current.finished.connect(_on_finished.bind(plan[index]))
	_holder.add_child(current)


func _on_finished(score: float, id: String) -> void:
	scores[id] = score
	_info.text = "%s: %d%%  →  %s" % [GameState.data.stations[id].name, int(score * 100.0), effect_text(id, score)]
	AudioManager.play("buy" if score >= 0.7 else ("click" if score >= 0.35 else "error"))
	_wait = 1.0


static func effect_text(id: String, score: float) -> String:
	var d: Dictionary = GameState.data
	var o := Production.outcome(d, {id: score})
	match d.stations[id].affects:
		"yield": return "yield ×%.2f" % o.yield_mult
		"heat": return "heat ×%.2f" % o.heat_mult
		"purity": return "purity %d%%" % int(o.purity * 100.0)
	return "quality %s" % d.quality.grades[o.grade].name


func _complete() -> void:
	var g = GameState.game
	var o := Production.outcome(g.data, scores)
	result = GameState.act(g.start_batch(_batch.base, _batch.additives, _batch.qty, scores))
	_title.text = "Batch done" if result.ok else "Batch failed"
	_hint.text = result.msg
	var grade: Dictionary = g.data.quality.grades[o.grade]
	_info.text = "Grade %s (value ×%.2f) · purity %d%% · yield ×%.2f → %d units · heat ×%.2f" % [grade.name,
		float(grade.value_mult), int(o.purity * 100.0), o.yield_mult, Production.output_qty(_batch.qty, o.yield_mult), o.heat_mult]
	_status.text = "Skipped stations count as Standard." if scores.size() < plan.size() else ""
	_btn.text = "Back to the lab [Esc]"


func _escape() -> void:
	if result.is_empty():
		index = plan.size() - 1
		_next()
	else:
		visible = false
		closed.emit()


func _clear_current() -> void:
	if current != null:
		_holder.remove_child(current)
		current.queue_free()
		current = null


func _process(dt: float) -> void:
	if not visible:
		return
	if _wait > 0.0:
		_wait -= dt
		if _wait <= 0.0:
			_next()
		return
	if current != null:
		if autoplay:
			current.bot_input(dt)
	elif autoplay and not result.is_empty():
		_escape()


func _input(ev: InputEvent) -> void:
	if not visible or not ev is InputEventKey or ev.echo:
		return
	get_viewport().set_input_as_handled()
	if ev.keycode == KEY_ESCAPE:
		if ev.pressed:
			_escape()
	elif current != null and _wait <= 0.0:
		current.key(ev.keycode, ev.pressed)
	elif ev.pressed and ev.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
		if _wait > 0.0:
			_wait = 0.0
			_next()
		elif not result.is_empty():
			_escape()
