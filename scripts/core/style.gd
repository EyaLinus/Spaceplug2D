extends RefCounted
## K2 customization: your look (hair, skin, jacket, pants), your ship's paint and decal, and decor for your estates.
## Catalogue in content.json "style"; state in Game.style (saved):
##   {"hair", "skin", "jacket", "pants", "paint", "decal": equipped id, "owned": ["cat:id"], "decor": [ids shown]}
## Owned decor shows in every estate you own while it is switched on. Purely cosmetic, so nothing else reads it.
## No autoload references (unit tests run without autoloads).

const WEAR := ["hair", "skin", "jacket", "pants"]
const SHIP := ["paint", "decal"]
const SLOTS := ["hair", "skin", "jacket", "pants", "paint", "decal"]

## Palette colours of the player sprite / ship hull that each category recolours, in ramp order
## (art_profile.yaml names: hair_dark, hair / skin, skin_dark / gold, gold_dark, gold_light / blue_dark).
const PLAYER_SRC := {
	"hair": ["#2a1d18", "#5a3a28"],
	"skin": ["#c99b78", "#8d5a3e"],
	"jacket": ["#ffd166", "#9a6a12", "#ffeab0"],
	"pants": ["#1a2a55"],
}
const HULL_SRC := ["#ffd166", "#9a6a12", "#ffeab0"]


static func catalogue(data: Dictionary, cat: String) -> Dictionary:
	return data.get("style", {}).get(cat, {})


static func init_state(data: Dictionary) -> Dictionary:
	var s := {"owned": [], "decor": []}
	for cat in SLOTS + ["decor"]:
		var items := catalogue(data, cat)
		for id in items:
			if int(items[id].get("cost", 0)) <= 0:
				s.owned.append("%s:%s" % [cat, id])
		if cat != "decor":
			s[cat] = items.keys()[0] if not items.is_empty() else ""
	return s


static func owns(g, cat: String, id: String) -> bool:
	return (g.style.get("owned", []) as Array).has("%s:%s" % [cat, id])


## Buy an item (and put it on / switch it on right away).
static func buy(g, cat: String, id: String) -> Dictionary:
	var items := catalogue(g.data, cat)
	if not items.has(id):
		return {"ok": false, "msg": "That isn't sold here."}
	if owns(g, cat, id):
		return equip(g, cat, id)
	var cost := int(items[id].get("cost", 0))
	if g.credits < cost:
		return {"ok": false, "msg": "%s costs %d cr." % [items[id].name, cost]}
	g.credits -= cost
	g.style.owned.append("%s:%s" % [cat, id])
	var r := equip(g, cat, id)
	r.msg = "Bought %s for %d cr." % [items[id].name, cost]
	return r


## Put on an owned item; for decor this toggles it on or off.
static func equip(g, cat: String, id: String) -> Dictionary:
	if not owns(g, cat, id):
		return {"ok": false, "msg": "You don't own that yet."}
	var name := str(catalogue(g.data, cat)[id].name)
	if cat == "decor":
		var shown: Array = g.style.decor
		if shown.has(id):
			shown.erase(id)
		else:
			shown.append(id)
		g._emit("style_changed", {"cat": cat, "id": id})
		return {"ok": true, "msg": ("%s now in your estates." if shown.has(id) else "%s packed away.") % name}
	g.style[cat] = id
	g._emit("style_changed", {"cat": cat, "id": id})
	return {"ok": true, "msg": "%s on." % name}


## {source Color: target Color} that turns the stock player sprite into your look.
static func player_swaps(data: Dictionary, style: Dictionary) -> Dictionary:
	var out := {}
	for cat in WEAR:
		var item: Dictionary = catalogue(data, cat).get(str(style.get(cat, "")), {})
		var ramp: Array = item.get("ramp", [])
		var src: Array = PLAYER_SRC[cat]
		for i in mini(src.size(), ramp.size()):
			if src[i] != ramp[i]:
				out[Color(src[i])] = Color(ramp[i])
	return out


## {source Color: target Color} for the ship hull paint.
static func hull_swaps(data: Dictionary, style: Dictionary) -> Dictionary:
	var out := {}
	var ramp: Array = catalogue(data, "paint").get(str(style.get("paint", "")), {}).get("ramp", [])
	for i in mini(HULL_SRC.size(), ramp.size()):
		if HULL_SRC[i] != ramp[i]:
			out[Color(HULL_SRC[i])] = Color(ramp[i])
	return out


## Decor props for an estate interior: [[decor id, x, y]] in estate cells (+0.5 = cell centre), filling free cells
## along the back wall's opposite side first: bottom row right to left (skipping the door and the stash corner),
## then the right column bottom-up. Stops when it runs out of free cells.
static func decor_spots(data: Dictionary, estate_id: String, buildings: Array, shown: Array) -> Array:
	var e: Dictionary = data.estates[estate_id]
	var w := int(e.size[0])
	var h := int(e.size[1])
	var taken := {}
	for b in buildings:
		var sz: Array = data.buildables[b.id].size
		for dx in int(sz[0]):
			for dy in int(sz[1]) + 1:  # keep the cell in front of a station free (you work there)
				taken[Vector2i(int(b.x) + dx, int(b.y) + dy)] = true
	taken[Vector2i(w / 2, h - 1)] = true  # door
	taken[Vector2i(0, h - 1)] = true  # stash crate
	var cells: Array = []
	for x in range(w - 1, -1, -1):
		cells.append(Vector2i(x, h - 1))
	for y in range(h - 2, 0, -1):
		cells.append(Vector2i(w - 1, y))
	var out: Array = []
	var i := 0
	for id in shown:
		while i < cells.size() and taken.has(cells[i]):
			i += 1
		if i >= cells.size():
			break
		out.append([str(id), cells[i].x + 0.5, cells[i].y + 0.5])
		i += 1
	return out


static func to_save(g) -> Dictionary:
	return g.style.duplicate(true)


static func from_save(g, d: Dictionary) -> void:
	g.style = init_state(g.data)
	for o in d.get("owned", []):
		var parts := str(o).split(":")
		if parts.size() == 2 and catalogue(g.data, parts[0]).has(parts[1]) and not g.style.owned.has(str(o)):
			g.style.owned.append(str(o))
	for cat in SLOTS:
		var id := str(d.get(cat, ""))
		if owns(g, cat, id):
			g.style[cat] = id
	for id in d.get("decor", []):
		if owns(g, "decor", str(id)) and not g.style.decor.has(str(id)):
			g.style.decor.append(str(id))
