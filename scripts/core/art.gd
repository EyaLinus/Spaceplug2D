extends RefCounted
## Central registry for drawn art: PNGs in res://assets/gfx, built from assets/src by tools/art/build_art.py.
## Every lookup returns null / "" when a file is missing, so callers keep their procedural drawing as fallback.
## Textures are pre-scaled 2x pixel art: draw them 1:1 on a node with texture_filter = nearest.

const ROOT := "res://assets/gfx/"
const CHAR := 32  ## one character frame (px)
const TILE := 32  ## one tile in a tile strip (px)
const WALK := [0, 1, 0, 2]  ## sheet columns for a walk cycle: idle, step A, idle, step B

## Surface id -> tile set (tiles/<set>_ground|road|plaza.png). Unknown surfaces keep procedural ground.
const TILESETS := {"mireth": "mireth", "cinder": "cinder", "bazaar": "bazaar"}

## NPC looks and their coat colour; an NPC gets the look whose coat is closest to its data colour.
const NPC_LOOKS := {
	"npc_teal": Color("#4fe3c1"), "npc_red": Color("#ff6b5f"), "npc_purple": Color("#6a3a8a"),
	"npc_rust": Color("#c27447"), "npc_green": Color("#5f9a5e"), "npc_slate": Color("#8a8b9c"),
	"npc_sky": Color("#5fb6c9"), "npc_pink": Color("#ff9ad5"),
}

static var _cache := {}


## Texture at assets/gfx/<rel> (e.g. "props/crate.png"), or null.
static func tex(rel: String) -> Texture2D:
	if _cache.has(rel):
		return _cache[rel]
	var path := ROOT + rel
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[rel] = t
	return t


static func character(look: String) -> Texture2D:
	return tex("chars/%s.png" % look) if look != "" else null


static func look_for_color(c: Color) -> String:
	var best := ""
	var best_d := INF
	for look in NPC_LOOKS:
		var k: Color = NPC_LOOKS[look]
		var d := Vector3(c.r - k.r, c.g - k.g, c.b - k.b).length_squared()
		if d < best_d:
			best_d = d
			best = look
	return best


## Draws one character frame with its feet at `feet`. Facing picks the row (down/up/side, left = mirrored side).
## Returns false (and draws nothing) if the sheet is missing.
static func draw_character(ci: CanvasItem, look: String, facing: Vector2, step: int, feet := Vector2(0, 12)) -> bool:
	var t := character(look)
	if t == null:
		return false
	var row := 0
	var flip := false
	if absf(facing.x) > absf(facing.y) + 0.05:
		row = 2
		flip = facing.x < 0.0
	elif facing.y < 0.0:
		row = 1
	var col: int = WALK[posmod(step, WALK.size())]
	var src := Rect2(col * CHAR, row * CHAR, CHAR, CHAR)
	var dst := Rect2(feet.x - CHAR / 2.0, feet.y - CHAR + 2.0, CHAR, CHAR)
	if flip:
		ci.draw_set_transform(Vector2(feet.x * 2.0, 0), 0.0, Vector2(-1, 1))
	ci.draw_texture_rect_region(t, dst, src)
	if flip:
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


## Draws a texture centred horizontally on `p` with its bottom edge at p.y + bottom.
static func draw_prop(ci: CanvasItem, rel: String, p: Vector2, bottom := 0.0) -> bool:
	var t := tex(rel)
	if t == null:
		return false
	var s := t.get_size()
	ci.draw_texture(t, Vector2(roundf(p.x - s.x / 2.0), roundf(p.y + bottom - s.y)))
	return true


## Fills `r` with variant tiles from a strip (tiles/<set>_<kind>.png), picked by a stable hash per cell.
static func fill_tiles(ci: CanvasItem, strip_rel: String, r: Rect2, seed_val: int) -> bool:
	var t := tex(strip_rel)
	if t == null:
		return false
	var n := int(t.get_width() / TILE)
	var y := r.position.y
	while y < r.end.y:
		var x := r.position.x
		while x < r.end.x:
			var v := posmod(hash(Vector3i(int(x), int(y), seed_val)), n)
			var w := minf(TILE, r.end.x - x)
			var h := minf(TILE, r.end.y - y)
			ci.draw_texture_rect_region(t, Rect2(x, y, w, h), Rect2(v * TILE, 0, w, h))
			x += TILE
		y += TILE
	return true


## Icon for an item key: raw, additive or product ("weed:overclock@premium" -> icons/weed.png), or upgrade/hud name.
static func icon_for(key: String) -> Texture2D:
	return tex("icons/%s.png" % key.split("@")[0].split(":")[0])


## Puts the icon for `key` in front of `ctrl` (32 px = the icon's native 2x size). Returns `ctrl` alone without art.
static func with_icon(key: String, ctrl: Control) -> Control:
	var t := icon_for(key)
	if t == null:
		return ctrl
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var r := TextureRect.new()
	r.texture = t
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2(32, 32)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(r)
	ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ctrl)
	return h
