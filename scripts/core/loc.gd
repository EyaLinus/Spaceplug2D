extends RefCounted
## Localisation foundation: string tables in data/loc/<lang>.json (flat key -> text), looked up with `Loc.t(key, fallback)`.
## Headless (no nodes). A missing key falls back to the English table, then to `fallback`, then to the key itself,
## so screens that are not converted yet (or keys added later) never show nothing. `Settings.language` sets `language`.
## Texts with placeholders keep them in the table: `Loc.t("menu.slot_info", "Slot %d · %s") % [1, "Mireth"]`.

const LANG_DIR := "res://data/loc/"
const DEFAULT := "en"
const LANGUAGES := ["en", "de"]

static var language := DEFAULT
static var _tables := {}  ## lang -> Dictionary, loaded on first use


## Translated text for `key` in the current language (English, then `fallback`, then the key if nothing is known).
static func t(key: String, fallback := "") -> String:
	var cur: Dictionary = table(language)
	if cur.has(key):
		return str(cur[key])
	var en: Dictionary = table(DEFAULT)
	if en.has(key):
		return str(en[key])
	return fallback if fallback != "" else key


static func has_key(key: String, lang := "") -> bool:
	return table(lang if lang != "" else language).has(key)


## Switches language; unknown codes fall back to English. Returns the language actually set.
static func set_language(lang: String) -> String:
	language = lang if lang in LANGUAGES else DEFAULT
	return language


static func table(lang: String) -> Dictionary:
	if not _tables.has(lang):
		_tables[lang] = _load(lang)
	return _tables[lang]


## Forget cached tables (tests that swap files).
static func reload() -> void:
	_tables = {}


static func _load(lang: String) -> Dictionary:
	var path := LANG_DIR + lang + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
