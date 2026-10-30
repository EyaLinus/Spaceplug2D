extends Node
## Owns the running core Game, relays its events onto the EventBus and handles save files.

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")
const SAVE_PATH := "user://savegame.json"

var data: Dictionary = {}
var game: Game
var save_path: String = SAVE_PATH
var paused := true  ## world and simulation stop while menus are open


func _ready() -> void:
	data = Data.load_all()


func new_game(seed_value: int = 0) -> void:
	_attach(Game.new())
	game.new_game(data, seed_value if seed_value != 0 else int(Time.get_unix_time_from_system()))
	EventBus.new_game_started.emit()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> bool:
	if game == null:
		return false
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("GameState: cannot write %s" % save_path)
		return false
	f.store_string(JSON.stringify(game.to_dict(), "\t"))
	return true


func load_game() -> bool:
	if not has_save():
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
