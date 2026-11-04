extends RefCounted
## Patrol feel in space: the warning before a patrol's scan range and asteroid fields that break pursuit.
## Pure rules (no nodes), numbers in content.json "patrol_feel". The World feeds in positions every physics frame.
##
## - Warning: `warn_level` says clear / close (inside the warning margin) / scanned. `warn_tick` turns a rising edge into
##   one warning with a cooldown, so hovering at the edge does not spam toasts and sound.
## - Fields: circles per system. Inside one the patrol scan range shrinks (`scan_radius_at`) and, deep enough,
##   patrols lose lock and drop the chase (`breaks_pursuit`).

const CLEAR := 0
const CLOSE := 1
const SCANNED := 2


static func rules(data: Dictionary) -> Dictionary:
	return data.get("patrol_feel", {})


## Asteroid fields of a system as [{pos: Vector2, radius: float}].
static func fields(data: Dictionary, sys: String) -> Array:
	var out: Array = []
	for f in rules(data).get("fields", {}).get(sys, []):
		out.append({"pos": Vector2(float(f[0]), float(f[1])), "radius": float(f[2])})
	return out


## 0 outside every field, up to 1 at the middle of the densest one.
static func depth(fl: Array, p: Vector2) -> float:
	var best := 0.0
	for f in fl:
		best = maxf(best, 1.0 - p.distance_to(f.pos) / float(f.radius))
	return clampf(best, 0.0, 1.0)


## Patrol scan range for a ship at `p`: shrinks towards `field_scan_mult` with depth.
static func scan_radius_at(data: Dictionary, base: float, fl: Array, p: Vector2) -> float:
	var mult := float(rules(data).get("field_scan_mult", 1.0))
	return base * lerpf(1.0, mult, depth(fl, p))


## True when a ship at `p` is deep enough in a field for patrols to lose lock.
static func breaks_pursuit(data: Dictionary, fl: Array, p: Vector2) -> bool:
	return depth(fl, p) >= float(rules(data).get("lock_depth", 1.0))


## dist: ship to the nearest patrol; radius: the scan range that applies.
static func warn_level(data: Dictionary, dist: float, radius: float) -> int:
	if dist < radius:
		return SCANNED
	if dist < radius + float(rules(data).get("warn_margin", 0.0)):
		return CLOSE
	return CLEAR


## Edge trigger. st is a runtime dict {armed, cd, clear_t}; returns true exactly when a warning should fire this tick.
## Fires once while armed (and off cooldown); re-arms after `rearm_seconds` of CLEAR.
static func warn_tick(data: Dictionary, st: Dictionary, level: int, delta: float) -> bool:
	var r := rules(data)
	st["cd"] = maxf(0.0, float(st.get("cd", 0.0)) - delta)
	if level == CLEAR:
		st["clear_t"] = float(st.get("clear_t", 0.0)) + delta
		if st.clear_t >= float(r.get("rearm_seconds", 3.0)):
			st["armed"] = true
		return false
	st["clear_t"] = 0.0
	if bool(st.get("armed", true)) and float(st.cd) <= 0.0:
		st["armed"] = false
		st["cd"] = float(r.get("warn_cooldown", 6.0))
		return true
	return false
