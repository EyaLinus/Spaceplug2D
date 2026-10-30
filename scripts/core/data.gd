extends RefCounted
## Loads static game content (data/content.json) plus the planet surface layouts (data/surfaces.json,
## merged in as `surfaces`, keyed by location id). No scene dependencies.

const CONTENT_PATH := "res://data/content.json"
const SURFACES_PATH := "res://data/surfaces.json"


static func load_all(path: String = CONTENT_PATH) -> Dictionary:
	var parsed := _load_json(path)
	if parsed.is_empty():
		return {}
	if not parsed.has("surfaces"):
		parsed["surfaces"] = _load_json(SURFACES_PATH) if FileAccess.file_exists(SURFACES_PATH) else {}
	return parsed


static func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Data: cannot open %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Data: %s is not a JSON object" % path)
		return {}
	return parsed
