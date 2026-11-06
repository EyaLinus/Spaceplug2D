extends RefCounted
## Pure steering helpers (no scene access) so flight logic can be unit-tested headless.

const MARGIN := 90.0  ## extra clearance around every hazard


## Unit heading from `from` to `goal` that detours around circular hazards ({pos, r}) lying ahead within `look`.
## Hazards that contain the goal or the ship's own start are not detoured (you are docking there / already inside:
## inside, the heading pushes straight out). Pure, so tests can run it headless.
static func avoid_heading(from: Vector2, goal: Vector2, hazards: Array, look: float, margin := MARGIN) -> Vector2:
	var dir := (goal - from).normalized()
	var best_along := INF
	var best := dir
	for h in hazards:
		var c: Vector2 = h.pos
		var r: float = float(h.r) + margin
		if c.distance_to(goal) < r:
			continue
		var rel := c - from
		if rel.length() < r:
			return (-rel).normalized() if rel.length() > 0.01 else dir
		var along := rel.dot(dir)
		if along <= 0.0 or along > minf(look, from.distance_to(goal)) + r:
			continue
		var lateral := rel.cross(dir)  # sign = which side of the course the centre is on
		if absf(lateral) >= r:
			continue
		if along < best_along:
			best_along = along
			# aim at the tangent-ish point on the clear side of the hazard
			var side := 1.0 if lateral >= 0.0 else -1.0
			var perp := dir.rotated(side * PI / 2.0)
			best = (c + perp * r * 1.1 - from).normalized()
	return best
