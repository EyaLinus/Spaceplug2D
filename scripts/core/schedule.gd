extends RefCounted
## Headless rules for living planet surfaces: the hour of the day, which place an NPC should be at, the day/night
## tint, idle chatter line picking and tile-grid path finding between places. Pure functions, no scene nodes, so it is
## unit-tested without a display. Positions are in tile units; the presentation layer multiplies by the tile size.

const DEFAULT_START_HOUR := 6.0  ## game day 0.0 s is 06:00


## Hour of day 0..24 for a position inside the day (day_time of 0 = start_hour).
static func hour_of(day_time: float, day_seconds: float, start_hour: float = DEFAULT_START_HOUR) -> float:
	return fposmod(start_hour + day_time / maxf(day_seconds, 0.001) * 24.0, 24.0)


static func clock_text(hour: float) -> String:
	var h := int(floor(hour)) % 24
	var m := int(floor((hour - floor(hour)) * 60.0))
	return "%02d:%02d" % [h, m]


## Schedule = [{"from": hour, "at": place}] sorted by hour. The entry with the greatest `from` <= hour is active;
## before the first entry the last one is still active (the previous night), so there are never gaps.
static func place_at(schedule: Array, hour: float) -> String:
	if schedule.is_empty():
		return ""
	var active: Dictionary = schedule[schedule.size() - 1]
	for e in schedule:
		if float(e.from) <= hour:
			active = e
		else:
			break
	return String(active.at)


## Returns "" if the schedule is well formed, otherwise a description of the first problem.
static func validate_schedule(schedule: Array, places: Dictionary) -> String:
	if schedule.is_empty():
		return "empty schedule"
	var last := -1.0
	for e in schedule:
		if not (e is Dictionary) or not e.has("from") or not e.has("at"):
			return "entry needs from and at"
		var f := float(e.from)
		if f < 0.0 or f >= 24.0:
			return "hour %s out of range" % f
		if f <= last:
			return "hours must ascend (%s after %s)" % [f, last]
		last = f
		if not places.has(e.at):
			return "unknown place %s" % e.at
	return ""


## Day/night tint. keys = [[hour, "#rrggbb"], ...] sorted by hour; interpolated linearly and wrapping at midnight.
static func tint_at(keys: Array, hour: float) -> Color:
	if keys.is_empty():
		return Color.WHITE
	var prev_h := float(keys[keys.size() - 1][0]) - 24.0
	var prev_c := Color(keys[keys.size() - 1][1])
	var next_h := float(keys[0][0])
	var next_c := Color(keys[0][1])
	for k in keys:
		if float(k[0]) <= hour:
			prev_h = float(k[0])
			prev_c = Color(k[1])
		else:
			next_h = float(k[0])
			next_c = Color(k[1])
			break
	if next_h <= prev_h:  # past the last key: blend towards the first key of the next day
		next_h += 24.0
	var span := next_h - prev_h
	var t := 0.0 if span <= 0.0 else clampf((hour - prev_h) / span, 0.0, 1.0)
	return prev_c.lerp(next_c, t)


## Brightness 0..1 of a tint (for tests and lighting decisions).
static func brightness(c: Color) -> float:
	return (c.r + c.g + c.b) / 3.0


## Chatter lines an NPC may say at `place`, plus its "any" pool.
static func chatter_pool(chatter: Dictionary, place: String) -> Array:
	var pool: Array = []
	pool.append_array(chatter.get(place, []))
	pool.append_array(chatter.get("any", []))
	return pool


## Index of the next line: random, but never the same line twice in a row when there is a choice.
static func pick_line(count: int, roll: int, last: int) -> int:
	if count <= 0:
		return -1
	if count == 1:
		return 0
	var i := absi(roll) % (count - 1)
	return i + 1 if (last >= 0 and i >= last) else i


# ---------------------------------------------------------------- path finding

## Cells a person cannot stand on: buildings, the ship on the pad, fountains, trees, stalls and crates.
static func blocked_cells(cfg: Dictionary) -> Array:
	var out: Array = []
	for b in cfg.get("buildings", []):
		for y in range(int(b.rect[1]), int(b.rect[1]) + int(b.rect[3])):
			for x in range(int(b.rect[0]), int(b.rect[0]) + int(b.rect[2])):
				out.append(Vector2i(x, y))
	if cfg.has("pad"):
		out.append_array(_cells_in_circle(Vector2(cfg.pad.pos[0], cfg.pad.pos[1]), 1.9))
	for r in cfg.get("plazas", []):
		out.append_array(_cells_in_circle(Vector2(r[0] + r[2] / 2.0, r[1] + r[3] / 2.0), 1.5))
	for p in cfg.get("props", []):
		if p[0] in ["tree", "stall", "crate"]:
			out.append(Vector2i(int(floor(float(p[1]))), int(floor(float(p[2])))))
	return out


static func _cells_in_circle(c: Vector2, r: float) -> Array:
	var out: Array = []
	for y in range(int(floor(c.y - r)), int(ceil(c.y + r)) + 1):
		for x in range(int(floor(c.x - r)), int(ceil(c.x + r)) + 1):
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r + 0.5:
				out.append(Vector2i(x, y))
	return out


static func make_nav(cfg: Dictionary) -> AStarGrid2D:
	var nav := AStarGrid2D.new()
	nav.region = Rect2i(0, 0, int(cfg.size[0]), int(cfg.size[1]))
	nav.cell_size = Vector2.ONE
	nav.offset = Vector2(0.5, 0.5)  # path points are cell centres
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES  # diagonals never cut a building corner
	nav.update()
	for c in blocked_cells(cfg):
		if nav.region.has_point(c):
			nav.set_point_solid(c, true)
	return nav


## Waypoints (tile units) from `from` to `to`; ends exactly on `to`. Empty if either end is blocked or unreachable.
static func find_path(nav: AStarGrid2D, from: Vector2, to: Vector2) -> Array:
	var a := Vector2i(int(floor(from.x)), int(floor(from.y)))
	var b := Vector2i(int(floor(to.x)), int(floor(to.y)))
	if not nav.region.has_point(a) or not nav.region.has_point(b) or nav.is_point_solid(b):
		return []
	if nav.is_point_solid(a):  # nudged against a wall: start from a free neighbour
		var found := false
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			if nav.region.has_point(a + d) and not nav.is_point_solid(a + d):
				a += d
				found = true
				break
		if not found:
			return []
	var pts := nav.get_point_path(a, b)
	if pts.is_empty():
		return []
	var out: Array = []
	for i in range(1, pts.size()):  # skip the cell we already stand in
		out.append(pts[i])
	if out.is_empty() or (out[out.size() - 1] as Vector2) != to:
		out.append(to)
	return out
