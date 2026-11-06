extends Control
## K1 player-action feedback layer (child of the HUD, drawn on top, never takes the mouse):
## - credit / heat changes pop up as rising numbers next to the HUD stats, whatever caused them
## - sales, loot and discoveries float over the player (ship in space, walker on foot)
## - full-screen colour flashes and camera shake (EventBus.shake) for busts, wrecks, raids, big moments
## Pure presentation: it only reads GameState and listens to game events.

const UI = preload("res://scripts/ui/ui_theme.gd")
const FloatText = preload("res://scripts/world/float_text.gd")

const POP_LIFE := 1.3
const BIG_SALE := 400  ## sales at least this big get the coin jingle and a gold flash

var hud: Control
var pops: Array = []  ## [{text, color, pos, t}] HUD-space numbers (exposed for the smoke test)
var _credits := -1
var _heat := -1.0
var _heat_acc := 0.0  ## heat creeps up in fractions; pop once a whole point has gathered
var _flash := 0.0
var _flash_color := Color.WHITE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.game_event.connect(_on_game_event)
	EventBus.new_game_started.connect(_reset)
	EventBus.game_loaded.connect(_reset)


func _reset() -> void:
	_credits = -1
	_heat = -1.0
	_heat_acc = 0.0
	pops.clear()


func _process(delta: float) -> void:
	var g = GameState.game
	if g != null and hud != null and hud.visible:
		_watch_stats(g)
	for i in range(pops.size() - 1, -1, -1):
		pops[i].t += delta
		if pops[i].t >= POP_LIFE:
			pops.remove_at(i)
	_flash = maxf(0.0, _flash - delta * 2.2)
	queue_redraw()


func _watch_stats(g) -> void:
	if _credits < 0:
		_credits = int(g.credits)
		_heat = float(g.heat)
		return
	var dc: int = int(g.credits) - _credits
	if dc != 0:
		_credits = int(g.credits)
		pop_stat(hud.credits_label(), ("+%d cr" if dc > 0 else "%d cr") % dc, UI.GOLD if dc > 0 else UI.WARN)
	var dh: float = float(g.heat) - _heat
	_heat = float(g.heat)
	if absf(dh) > 0.0001:
		_heat_acc += dh
		if absf(_heat_acc) >= 1.0:
			var whole := int(_heat_acc)
			_heat_acc -= whole
			pop_stat(hud.heat_label(), ("+%d heat" if whole > 0 else "%d heat") % whole, UI.WARN if whole > 0 else UI.ACCENT)


## A number that rises out of a HUD widget (credits, heat).
func pop_stat(anchor: Control, text: String, c: Color) -> void:
	if anchor == null:
		return
	var r := anchor.get_global_rect()
	var at := r.position - get_global_rect().position + Vector2(r.size.x * 0.5, r.size.y + 16.0)
	# stack pops from the same widget so a burst of sales does not draw on top of itself
	for p in pops:
		if p.pos.distance_to(at) < 4.0 and p.t < 0.5:
			at.y += 18.0
	pops.append({"text": text, "color": c, "pos": at, "t": 0.0})


## Flash the whole screen in `c` (alpha = strength).
func flash(c: Color, strength := 0.35) -> void:
	_flash_color = c
	_flash = maxf(_flash, strength)


## A word or number floating up from the player (ship in space, walker on foot).
func over_player(text: String, c: Color, size := 17) -> void:
	if hud == null:
		return
	var parent: Node2D = null
	var at := Vector2.ZERO
	if hud.surface != null and is_instance_valid(hud.surface) and hud.surface.player != null:
		parent = hud.surface
		at = hud.surface.player.position + Vector2(0, -34)
	elif hud.world != null and hud.world.active:
		parent = hud.world
		at = hud.world.ship.position + Vector2(0, -36)
	if parent == null:
		return
	var f: Node2D = FloatText.new().setup(text, c, size)
	f.position = at
	parent.add_child(f)


func _on_game_event(kind: String, p: Dictionary) -> void:
	var g = GameState.game
	if g == null:
		return
	match kind:
		"sold":
			var cr := int(p.get("credits", 0))
			over_player("+%d cr" % cr, UI.GOLD, 20 if cr >= BIG_SALE else 17)
			if cr >= BIG_SALE:
				AudioManager.play("coin")
				flash(UI.GOLD, 0.12)
		"busted", "knocked_out":
			flash(UI.WARN, 0.5)
			EventBus.shake.emit(12.0)
		"ship_destroyed":
			flash(UI.WARN, 0.55)
			EventBus.shake.emit(14.0)
		"interdicted":
			flash(Color("#7a4fff"), 0.3)
			EventBus.shake.emit(8.0)
		"raided":
			flash(UI.WARN, 0.4)
			EventBus.shake.emit(8.0)
		"base_raided":
			flash(UI.GOLD, 0.3)
		"upgraded", "ship_bought", "estate_bought", "weapon_bought":
			flash(UI.GOLD, 0.15)
			over_player("UPGRADE" if kind == "upgraded" else "NEW!", UI.GOLD, 18)
		"quest_done":
			flash(UI.GOLD, 0.18)
		"product_discovered":
			over_player("NEW PRODUCT", UI.ACCENT, 18)
		"loot":
			over_player("+loot", UI.ACCENT)
		"referral", "recruited":
			over_player("+1 customer" if kind == "referral" else "+1 crew", UI.ACCENT)
		"player_hit":
			EventBus.shake.emit(4.0)
		"tray_step":
			AudioManager.play("cook")
		"lab_done", "worker_batch":
			over_player("BATCH READY", UI.ACCENT)


func _draw() -> void:
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(_flash_color, _flash * 0.6))
	var font := ThemeDB.fallback_font
	for p in pops:
		var k: float = p.t / POP_LIFE
		var pos: Vector2 = p.pos + Vector2(0, -28.0 * k)
		var a := clampf(1.8 - k * 1.8, 0.0, 1.0)
		var fs := 17
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(font, pos - Vector2(w / 2.0, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.05, 0.04, 0.08, a))
		draw_string(font, pos - Vector2(w / 2.0, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(p.color, a))
