extends RefCounted
## P3 hiding spots, headless. Standing still in a hiding spot (dumpster, crate stack, alcove) for `settle_seconds`
## hides you: officers no longer see you (no frisk, no new chase), and after `lose_seconds` hidden every officer that was
## chasing or aiming at you gives up. An officer that walks within `notice_range` finds you (spot is burned for
## `found_cooldown`). Moving, shooting or being shot reveals you. Spots: surfaces.json -> "hide" ([x, y, w, h, kind] tiles).
## Numbers: data/hiding.json. State is a small runtime dict owned by the surface (not saved): see `fresh()`.

const PATH := "res://data/hiding.json"
static var _rules: Dictionary = {}


static func rules() -> Dictionary:
	if _rules.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var j = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				_rules = j
	return _rules


static func fresh() -> Dictionary:
	return {"t": 0.0, "hidden": false, "hid_t": 0.0, "cd": 0.0}


## Spots of a planet as pixel rects (same order as the data, kind at `kinds`).
static func spot_rects(surface: Dictionary, tile: float) -> Array:
	var out: Array = []
	for s in surface.get("hide", []):
		out.append(Rect2(float(s[0]) * tile, float(s[1]) * tile, float(s[2]) * tile, float(s[3]) * tile))
	return out


## Index of the spot that contains `pos` (feet), -1 if none.
static func spot_at(rects: Array, pos: Vector2) -> int:
	for i in rects.size():
		if rects[i].has_point(pos):
			return i
	return -1


## Advances the hiding state by dt. `in_spot`: player stands in a spot; `speed`: current walking speed in px/s;
## `nearest`: distance to the closest officer (INF if none). Returns events: {"hid", "found", "lost"} (bool each).
## "lost" fires once per hide, when the officers should stand down.
static func step(h: Dictionary, dt: float, in_spot: bool, speed: float, nearest: float) -> Dictionary:
	var r := rules()
	var ev := {"hid": false, "found": false, "lost": false}
	h.cd = maxf(0.0, float(h.cd) - dt)
	var still: bool = speed <= float(r.get("still_speed", 18))
	if h.hidden:
		if not in_spot or not still:
			reveal(h)
			return ev
		if nearest <= float(r.get("notice_range", 46)):
			reveal(h)
			h.cd = float(r.get("found_cooldown", 4.0))
			ev.found = true
			return ev
		var before: float = h.hid_t
		h.hid_t = before + dt
		if before < float(r.get("lose_seconds", 2.0)) and h.hid_t >= float(r.get("lose_seconds", 2.0)):
			ev.lost = true
		return ev
	if in_spot and still and h.cd <= 0.0:
		h.t = float(h.t) + dt
		if h.t >= float(r.get("settle_seconds", 0.8)):
			h.hidden = true
			h.hid_t = 0.0
			h.t = 0.0
			ev.hid = true
	else:
		h.t = 0.0
	return ev


## Breaks cover (moved, fired, got hit).
static func reveal(h: Dictionary) -> void:
	h.hidden = false
	h.t = 0.0
	h.hid_t = 0.0


## Can an officer at `from` see `target`? Same as the open-street rule, except a hidden player is invisible.
static func visible_to_officer(h: Dictionary, seen_in_open: bool) -> bool:
	return seen_in_open and not h.hidden
