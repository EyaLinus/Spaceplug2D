extends Node
## Owns the running core Game, relays its events onto the EventBus and handles the save slots.
## Each slot is one JSON file (`save_prefix` + slot number + ".json"); `slot` is the one the running game saves to.

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")
const SLOTS := 3
const LEGACY_SAVE := "user://savegame.json"  ## single save file before v0.1.3, moved into slot 1

var data: Dictionary = {}
var game: Game
var save_prefix := "user://save_"
var slot := 1
var save_path: String:
	get:
		return slot_path(slot)
var paused := true  ## world and simulation stop while menus are open


func _ready() -> void:
	data = Data.load_all()
	_migrate_legacy_save()


func slot_path(i: int) -> String:
	return "%s%d.json" % [save_prefix, i]


func slot_exists(i: int) -> bool:
	return FileAccess.file_exists(slot_path(i))


## Summary for the slot list: {} when empty, else day, credits, debt, location name, state and saved_at (unix time).
func slot_info(i: int) -> Dictionary:
	if not slot_exists(i):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(slot_path(i)))
	if typeof(d) != TYPE_DICTIONARY:
		return {"broken": true, "saved_at": FileAccess.get_modified_time(slot_path(i))}
	var loc := str(d.get("location", ""))
	return {
		"day": int(d.get("day", 1)), "credits": int(d.get("credits", 0)), "debt": int(d.get("debt", 0)),
		"location": data.get("locations", {}).get(loc, {}).get("name", "In flight") if loc != "" else "In flight",
		"state": str(d.get("state", "playing")), "saved_at": FileAccess.get_modified_time(slot_path(i)),
	}


## Most recently written slot, 0 if there is none.
func latest_slot() -> int:
	var best := 0
	var best_t := -1
	for i in range(1, SLOTS + 1):
		if slot_exists(i):
			var t := FileAccess.get_modified_time(slot_path(i))
			if t > best_t:
				best = i
				best_t = t
	return best


func delete_slot(i: int) -> void:
	if slot_exists(i):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(i)))


func _migrate_legacy_save(legacy := LEGACY_SAVE) -> void:
	if FileAccess.file_exists(legacy) and not slot_exists(1):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(legacy), ProjectSettings.globalize_path(slot_path(1)))


func new_game(seed_value: int = 0) -> void:
	_attach(Game.new())
	game.new_game(data, seed_value if seed_value != 0 else int(Time.get_unix_time_from_system()))
	EventBus.new_game_started.emit()


func has_save() -> bool:
	return latest_slot() != 0


func save_game() -> bool:
	if game == null:
		return false
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("GameState: cannot write %s" % save_path)
		return false
	f.store_string(JSON.stringify(game.to_dict(), "\t"))
	return true


## Loads slot `i` (default: the current slot) and makes it the current slot.
func load_game(i: int = 0) -> bool:
	if i != 0:
		slot = i
	if not slot_exists(slot):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	_attach(Game.new())
	game.from_dict(data, parsed)
	EventBus.game_loaded.emit()
	return true


func _process(delta: float) -> void:
	if game != null and not paused:
		game.tick(delta)


## Runs a core action and shows its message as a toast.
func act(result: Dictionary) -> Dictionary:
	EventBus.toast.emit(result.msg, result.ok)
	return result


func _attach(g: Game) -> void:
	if game != null and game.event.is_connected(_on_game_event):
		game.event.disconnect(_on_game_event)
	game = g
	game.event.connect(_on_game_event)


func _on_game_event(kind: String, payload: Dictionary) -> void:
	EventBus.game_event.emit(kind, payload)
