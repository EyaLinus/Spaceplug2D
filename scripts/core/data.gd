extends RefCounted
## Loads static game content (data/content.json). No scene dependencies.

const CONTENT_PATH := "res://data/content.json"


static func load_all(path: String = CONTENT_PATH) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Data: cannot open %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Data: %s is not a JSON object" % path)
		return {}
	return parsed
