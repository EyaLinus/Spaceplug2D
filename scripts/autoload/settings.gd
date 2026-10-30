extends Node
## Player settings: audio volumes (Master/Music/SFX buses), window mode, resolution, vsync and key bindings.
## Persisted in user://settings.cfg. Key rebinding changes the *primary* key of an action (its first key event);
## secondary keys such as the arrow keys stay. Binding a key that another action of the same group already uses swaps
## the two keys, so a group never ends up with one key on two actions.

signal changed  ## any setting changed (HUD refreshes its key hints)

const BUSES := ["Master", "Music", "SFX"]
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const WINDOW_MODES := ["Windowed", "Fullscreen"]

## Rebindable actions in the order the settings screen lists them. The actions themselves are registered by main.gd
## and surface.gd; `apply_input()` must run after that.
const BINDABLE := [
	{"action": "ship_thrust", "label": "Thrust", "group": "Flight"},
	{"action": "ship_reverse", "label": "Reverse", "group": "Flight"},
	{"action": "ship_left", "label": "Turn left", "group": "Flight"},
	{"action": "ship_right", "label": "Turn right", "group": "Flight"},
	{"action": "ship_brake", "label": "Brake", "group": "Flight"},
	{"action": "ship_dock", "label": "Dock / undock", "group": "Flight"},
	{"action": "move_up", "label": "Walk up", "group": "On foot"},
	{"action": "move_down", "label": "Walk down", "group": "On foot"},
	{"action": "move_left", "label": "Walk left", "group": "On foot"},
	{"action": "move_right", "label": "Walk right", "group": "On foot"},
	{"action": "interact", "label": "Use / talk", "group": "On foot"},
	{"action": "build_menu", "label": "Build menu (estate)", "group": "On foot"},
	{"action": "ui_menu", "label": "Pause menu", "group": "General"},
	{"action": "phone", "label": "Com-Phone", "group": "General"},
]

var config_path := "user://settings.cfg"
var volumes := {"Master": 0.8, "Music": 0.6, "SFX": 0.8}  ## linear 0..1
var window_mode := 0  ## index into WINDOW_MODES
var resolution := 0  ## index into RESOLUTIONS (windowed only)
var vsync := true
var bindings: Dictionary = {}  ## action -> physical keycode overriding the default primary key
var _defaults: Dictionary = {}  ## action -> default primary physical keycode, captured on first apply_input()


func _ready() -> void:
	_ensure_buses()
	load_settings()
	apply_audio()
	apply_display()


# ---------------------------------------------------------------- persistence

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(config_path) != OK:
		return
	for bus in BUSES:
		volumes[bus] = clampf(float(cf.get_value("audio", bus, volumes[bus])), 0.0, 1.0)
	window_mode = clampi(int(cf.get_value("display", "window_mode", window_mode)), 0, WINDOW_MODES.size() - 1)
	resolution = clampi(int(cf.get_value("display", "resolution", resolution)), 0, RESOLUTIONS.size() - 1)
	vsync = bool(cf.get_value("display", "vsync", vsync))
	bindings = {}
	if cf.has_section("keys"):
		for action in cf.get_section_keys("keys"):
			bindings[action] = int(cf.get_value("keys", action))


func save_settings() -> bool:
	var cf := ConfigFile.new()
	for bus in BUSES:
		cf.set_value("audio", bus, volumes[bus])
	cf.set_value("display", "window_mode", window_mode)
	cf.set_value("display", "resolution", resolution)
	cf.set_value("display", "vsync", vsync)
	for action in bindings:
		cf.set_value("keys", action, bindings[action])
	return cf.save(config_path) == OK


# ---------------------------------------------------------------- audio

func _ensure_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")


func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	apply_audio()
	changed.emit()


func apply_audio() -> void:
	for bus in BUSES:
		var i := AudioServer.get_bus_index(bus)
		if i == -1:
			continue
		var v: float = volumes[bus]
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


# ---------------------------------------------------------------- display

func set_window_mode(i: int) -> void:
	window_mode = clampi(i, 0, WINDOW_MODES.size() - 1)
	apply_display()
	changed.emit()


func set_resolution(i: int) -> void:
	resolution = clampi(i, 0, RESOLUTIONS.size() - 1)
	apply_display()
	changed.emit()


func set_vsync(on: bool) -> void:
	vsync = on
	apply_display()
	changed.emit()


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if window_mode == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var size: Vector2i = RESOLUTIONS[resolution]
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x > 0:
		size = size.clamp(Vector2i(640, 360), usable.size)
	DisplayServer.window_set_size(size)
	if usable.size.x > 0:
		DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


# ---------------------------------------------------------------- key bindings

## Captures the default keys (first call only) and applies the saved overrides. Call after all actions exist.
func apply_input() -> void:
	if _defaults.is_empty():
		for b in BINDABLE:
			_defaults[b.action] = primary_key(b.action)
	for action in bindings:
		if _defaults.has(action):
			_set_primary(action, bindings[action])


func primary_key(action: String) -> int:
	if not InputMap.has_action(action):
		return 0
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev.physical_keycode
	return 0


func key_label(action: String) -> String:
	var code := primary_key(action)
	return "—" if code == 0 else OS.get_keycode_string(code)


func group_of(action: String) -> String:
	for b in BINDABLE:
		if b.action == action:
			return b.group
	return ""


## Makes `keycode` the primary key of `action`. Returns the action whose key was swapped away, or "".
func rebind(action: String, keycode: int) -> String:
	if not _defaults.has(action) or keycode == 0:
		return ""
	var old := primary_key(action)
	if old == keycode:
		return ""
	var swapped := ""
	for b in BINDABLE:
		if b.action != action and b.group == group_of(action) and primary_key(b.action) == keycode:
			swapped = b.action
			_set_primary(swapped, old)
			_remember(swapped)
			break
	_set_primary(action, keycode)
	_remember(action)
	changed.emit()
	return swapped


func reset_bindings() -> void:
	for action in _defaults:
		_set_primary(action, _defaults[action])
	bindings = {}
	changed.emit()


func _remember(action: String) -> void:
	var code := primary_key(action)
	if code == _defaults.get(action, 0):
		bindings.erase(action)
	else:
		bindings[action] = code


## Replaces the action's first key event (keeps any other events), or adds one if it has none.
func _set_primary(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	var events := InputMap.action_get_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode as Key
	var replaced := false
	var out: Array[InputEvent] = []
	for e in events:
		if not replaced and e is InputEventKey:
			out.append(ev)
			replaced = true
		elif e is InputEventKey and e.physical_keycode == keycode:
			continue  # drop a secondary duplicate of the new key
		else:
			out.append(e)
	if not replaced:
		out.push_front(ev)
	InputMap.action_erase_events(action)
	for e in out:
		InputMap.action_add_event(action, e)
