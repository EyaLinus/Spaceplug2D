extends RefCounted
## Grid pathfinding on planet surfaces (no autoload dependencies, so unit tests can use it headless).

## Walkable tile grid of a surface: building rects are solid, diagonal steps only around free corners.
static func build(surface_cfg: Dictionary) -> AStarGrid2D:
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, int(surface_cfg.size[0]), int(surface_cfg.size[1]))
	g.cell_size = Vector2.ONE * float(surface_cfg.get("tile", 32))
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.update()
	for b in surface_cfg.buildings:
		for y in range(int(b.rect[1]), int(b.rect[1]) + int(b.rect[3])):
			for x in range(int(b.rect[0]), int(b.rect[0]) + int(b.rect[2])):
				g.set_point_solid(Vector2i(x, y))
	return g


## Waypoints (tile centres, then the exact target) from `from` to `to` around buildings. Falls back to a straight
## line if either end sits on a solid cell (e.g. squeezed against a wall).
static func path_between(g: AStarGrid2D, tile_px: float, from: Vector2, to: Vector2) -> Array:
	var a := Vector2i((from / tile_px).floor())
	var b := Vector2i((to / tile_px).floor())
	if not g.region.has_point(a) or not g.region.has_point(b) or g.is_point_solid(a) or g.is_point_solid(b):
		return [to]
	var r: Array = []
	var ids := g.get_id_path(a, b)
	for i in range(1, ids.size() - 1):
		r.append((Vector2(ids[i]) + Vector2(0.5, 0.5)) * tile_px)
	r.append(to)
	return r
