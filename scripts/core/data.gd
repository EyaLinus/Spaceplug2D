extends RefCounted
## Loads static game content (data/content.json) plus the planet surface layouts (data/surfaces.json,
## merged in as `surfaces`, keyed by location id) and the quests (data/quests.json, merged in as `quests`).
## No scene dependencies.

const CONTENT_PATH := "res://data/content.json"
const SURFACES_PATH := "res://data/surfaces.json"
const QUESTS_PATH := "res://data/quests.json"
## Content packs (extra star systems): merged into the loaded content, see merge_pack.
const PACKS := ["res://data/system_thessaly.json"]
const Locals = preload("res://scripts/core/locals.gd")


static func load_all(path: String = CONTENT_PATH) -> Dictionary:
	var parsed := _load_json(path)
	if parsed.is_empty():
		return {}
	if not parsed.has("surfaces"):
		parsed["surfaces"] = _load_json(SURFACES_PATH) if FileAccess.file_exists(SURFACES_PATH) else {}
	if not parsed.has("quests"):
		parsed["quests"] = _load_json(QUESTS_PATH) if FileAccess.file_exists(QUESTS_PATH) else {}
	for pack in PACKS:
		if FileAccess.file_exists(pack):
			merge_pack(parsed, _load_json(pack))
	Locals.add_to(parsed)  # named townsfolk on every planet join the contacts
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


## Adds a pack's systems, locations and surfaces to `data`. Idempotent: ids that already exist are left alone, so a
## second merge (or a content.json that grew the same ids) changes nothing. A location's "surface" entry moves to
## data.surfaces[<location id>]; with "from" it clones that surface first (see data/system_thessaly.json).
static func merge_pack(data: Dictionary, pack: Dictionary) -> void:
	if pack.is_empty():
		return
	for sid in pack.get("systems", {}):
		if not data.systems.has(sid):
			data.systems[sid] = (pack.systems[sid] as Dictionary).duplicate(true)
	for lid in pack.get("locations", {}):
		if data.locations.has(lid):
			continue
		var ld: Dictionary = (pack.locations[lid] as Dictionary).duplicate(true)
		var spec: Dictionary = ld.get("surface", {})
		ld.erase("surface")
		data.locations[lid] = ld
		if not spec.is_empty() and not data.surfaces.has(lid) and data.surfaces.has(str(spec.get("from", ""))):
			data.surfaces[lid] = _clone_surface(data.surfaces[str(spec.from)], spec)
			var cover: Dictionary = data.get("combat", {}).get("cover", {})  ## the clone fights on the same cover layout
			if cover.has(str(spec.from)) and not cover.has(lid):
				cover[lid] = (cover[str(spec.from)] as Array).duplicate(true)
	var ids := {}
	for o in data.get("officials", []):
		ids[o.id] = true
	for o in pack.get("officials", []):
		if not ids.has(o.id):
			data.officials.append((o as Dictionary).duplicate(true))


static func _clone_surface(src: Dictionary, spec: Dictionary) -> Dictionary:
	var s: Dictionary = src.duplicate(true)
	for k in spec:
		if not (k in ["from", "strip_estates", "strip_contacts"]):
			s[k] = spec[k]
	for b in s.get("buildings", []):
		if spec.get("strip_estates", false) and b.get("action", "") == "estate":
			b.erase("action")
			b.erase("estate")
			b.erase("label")
	if spec.get("strip_contacts", false):
		s["npcs"] = (s.get("npcs", []) as Array).filter(func(n): return not n.has("contact"))
	return s
