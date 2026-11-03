extends RefCounted
## K2 customization: player look (hair, jacket), ship paint and decals, estate decoration props.
## Pure cosmetics, no gameplay effect. Options live in content.json "customize"; each slot's first entry is the free
## default. State on Game: `look` {slot: id} for the four slots, `look_owned` ["slot:id"] (paid-for options, the free
## ones are implicit) and `estates[id].decor` [{id, x, y}]. Old saves lack all of it and start with the defaults.
## No autoload references, so tests can run it headless.

const SLOTS := ["hair", "jacket", "paint", "decal"]
const SLOT_NAMES := {"hair": "Hair", "jacket": "Jacket", "paint": "Ship paint", "decal": "Hull decal"}


static func defaults(data: Dictionary) -> Dictionary:
	var r := {}
	for s in SLOTS:
		r[s] = str(data.customize[s][0].id)
	return r


static func options(data: Dictionary, slot: String) -> Array:
	return data.customize.get(slot, [])


static func option(data: Dictionary, slot: String, id: String) -> Dictionary:
	for o in options(data, slot):
		if str(o.id) == id:
			return o
	return {}


static func owned(g, slot: String, id: String) -> bool:
	var o := option(g.data, slot, id)
	return not o.is_empty() and (int(o.cost) <= 0 or g.look_owned.has("%s:%s" % [slot, id]))


## Colour of the equipped option for hair/jacket/paint; transparent where there is none (factory paint).
static func color(g, slot: String) -> Color:
	var c := str(option(g.data, slot, str(g.look.get(slot, ""))).get("color", ""))
	return Color(c) if c != "" else Color(0, 0, 0, 0)


static func decal(g) -> String:
	return str(g.look.get("decal", "none"))


## True once hair or jacket differ from the factory look (the walker then draws the coloured body instead of the sprite).
static func custom_body(g) -> bool:
	var d := defaults(g.data)
	return g.look.hair != d.hair or g.look.jacket != d.jacket


## Pays for (once) and equips an option. Needs a dock: the paint shop and the mirror are on the ground.
static func equip(g, slot: String, id: String) -> Dictionary:
	if not SLOTS.has(slot):
		return g._fail("No such slot.")
	var o := option(g.data, slot, id)
	if o.is_empty():
		return g._fail("No such option.")
	if g.location == "":
		return g._fail("Dock first: the paint shop and the mirror are on the ground.")
	if str(g.look[slot]) == id:
		return g._fail("Already equipped.")
	if not owned(g, slot, id):
		if g.credits < int(o.cost):
			return g._fail("Not enough credits.")
		g.credits -= int(o.cost)
		g.look_owned.append("%s:%s" % [slot, id])
	g.look[slot] = id
	g._emit("customized", {"slot": slot, "id": id})
	return g._ok("%s: %s." % [SLOT_NAMES[slot], o.name])


# ---------------------------------------------------------------- estate decor

static func decor_list(g, estate_id: String) -> Array:
	return g.estates.get(estate_id, {}).get("decor", [])


static func can_place_decor(g, estate_id: String, id: String, x: int, y: int) -> bool:
	if not g.estates.has(estate_id) or not g.estate_reachable(estate_id) or not g.data.customize.decor.has(id):
		return false
	var size: Array = g.data.estates[estate_id].size
	if x < 0 or y < 0 or x >= int(size[0]) or y >= int(size[1]):
		return false
	if Vector2i(x, y) == g.estate_door(estate_id) or Vector2i(x, y) == Vector2i(0, int(size[1]) - 1):  # door, stash crate
		return false
	for b in g.estates[estate_id].buildings:
		var bs: Array = g.data.buildables[b.id].size
		if Rect2i(int(b.x), int(b.y), int(bs[0]), int(bs[1])).has_point(Vector2i(x, y)):
			return false
	for d in decor_list(g, estate_id):
		if int(d.x) == x and int(d.y) == y:
			return false
	return true


## First free cell, scanning from the back wall (far from the door) row by row; (-1, -1) if the room is full.
static func free_cell(g, estate_id: String, id: String) -> Vector2i:
	var size: Array = g.data.estates[estate_id].size
	for y in int(size[1]):
		for x in int(size[0]):
			if can_place_decor(g, estate_id, id, x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


static func place_decor(g, estate_id: String, id: String, x: int, y: int) -> Dictionary:
	if not g.estates.has(estate_id):
		return g._fail("You do not own that place.")
	if not g.estate_reachable(estate_id):
		return g._fail("Dock the ship first.")
	if not g.data.customize.decor.has(id):
		return g._fail("No such prop.")
	if decor_list(g, estate_id).size() >= int(g.data.customize.decor_max):
		return g._fail("Too cluttered: %d props at most." % int(g.data.customize.decor_max))
	if not can_place_decor(g, estate_id, id, x, y):
		return g._fail("That spot is taken.")
	var def: Dictionary = g.data.customize.decor[id]
	if g.credits < int(def.cost):
		return g._fail("Not enough credits.")
	g.credits -= int(def.cost)
	if not g.estates[estate_id].has("decor"):
		g.estates[estate_id].decor = []
	g.estates[estate_id].decor.append({"id": id, "x": x, "y": y})
	g._emit("decor_placed", {"estate": estate_id, "prop": id})
	return g._ok("%s placed." % def.name)


static func remove_decor(g, estate_id: String, index: int) -> Dictionary:
	var list := decor_list(g, estate_id)
	if not g.estates.has(estate_id) or not g.estate_reachable(estate_id) or index < 0 or index >= list.size():
		return g._fail("Nothing to remove.")
	var def: Dictionary = g.data.customize.decor[list[index].id]
	var refund := int(round(int(def.cost) * float(g.data.estate_refund)))
	g.credits += refund
	g.estates[estate_id].decor.remove_at(index)
	g._emit("decor_removed", {"estate": estate_id})
	return g._ok("%s removed, +%d cr." % [def.name, refund])


# ---------------------------------------------------------------- save

static func to_save(g) -> Dictionary:
	return {"look": g.look.duplicate(), "owned": g.look_owned.duplicate()}


## `estates_saved` is the raw "estates" dict of the save: decor lives inside each estate's record.
static func from_save(g, d: Dictionary, estates_saved: Dictionary) -> void:
	g.look = defaults(g.data)
	g.look_owned = []
	var saved: Dictionary = d.get("look", {})
	for s in SLOTS:
		if not option(g.data, s, str(saved.get(s, ""))).is_empty():
			g.look[s] = str(saved[s])
	for k in d.get("owned", []):
		var parts := str(k).split(":")
		if parts.size() == 2 and SLOTS.has(parts[0]) and not option(g.data, parts[0], parts[1]).is_empty() and not g.look_owned.has(str(k)):
			g.look_owned.append(str(k))
	for s in SLOTS:  # an equipped option that was never recorded as bought counts as owned
		if not owned(g, s, str(g.look[s])):
			g.look_owned.append("%s:%s" % [s, g.look[s]])
	for e in estates_saved:
		if not g.estates.has(e):
			continue
		var list: Array = []
		for p in estates_saved[e].get("decor", []):
			if g.data.customize.decor.has(str(p.get("id", ""))) and list.size() < int(g.data.customize.decor_max):
				list.append({"id": str(p.id), "x": int(p.x), "y": int(p.y)})
		if not list.is_empty():
			g.estates[e].decor = list
