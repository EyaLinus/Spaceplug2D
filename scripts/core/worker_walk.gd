extends RefCounted
## Presentation helper for hired workers (P5): what a worker looks like they are doing and where in the estate they
## should stand. Read-only on the Game, never changes the simulation. Cells are estate cells (the room without its wall
## ring), x/y are cell centres as floats, so the surface adds the wall offset when it turns them into pixels.
## No autoload references (unit tests run without autoloads).

const Workers = preload("res://scripts/core/workers.gd")
const Production = preload("res://scripts/core/production.gd")
const Style = preload("res://scripts/core/style.gd")

const IDLE := "idle"
const COOK := "cook"    ## lab hand at the station while a batch runs (or waiting there for the stocker to fill the bench)
const FETCH := "fetch"  ## lab hand with nothing on the bench and no stocker: walks to storage for inputs
const HAUL := "haul"    ## stocker with something to carry: pendulum between storage and the station


## One of IDLE / COOK / FETCH / HAUL for the worker's current job state in his estate.
static func activity(g, worker_id: String) -> String:
	var wi := Workers.find(g, worker_id)
	if wi < 0:
		return IDLE
	var est: String = g.workers[wi].estate
	if est == "" or not g.estates.has(est):
		return IDLE
	var e: Dictionary = g.estates[est]
	Workers.ensure(e)
	var role: String = Workers.candidate(g, worker_id).role
	if role == "lab_hand":
		if not e.job.is_empty():
			return COOK
		if Workers.blocker(g, est) != "":
			return IDLE
		return COOK if not Workers.at(g, est, "stocker").is_empty() else FETCH
	if role == "stocker":
		return HAUL if _has_haul_work(g, e) else IDLE
	return IDLE


static func _has_haul_work(g, e: Dictionary) -> bool:
	for k in e.out:
		if int(e.out[k]) > 0:
			return true
	if e.recipe.is_empty():
		return false
	var need: Dictionary = g.batch_needs(e.recipe.base, e.recipe.additives, mini(int(e.recipe.qty), g.lab_capacity()))
	for k in need:
		if int(e.bench.get(k, 0)) < int(need[k]) and int(e.storage.get(k, 0)) > 0:
			return true
	return false


## Cell in front of the estate's storage crate (bottom-left corner of the room).
static func storage_cell(data: Dictionary, estate_id: String) -> Vector2:
	return Vector2(1.5, float(data.estates[estate_id].size[1]) - 1.5)


## Cell in front of the station the crew works at: the first station the auto recipe needs that is placed, else the
## first placed station. Vector2(-1, -1) when the estate has no station at all.
static func station_cell(data: Dictionary, estate_id: String, buildings: Array, recipe: Dictionary) -> Vector2:
	if buildings.is_empty():
		return Vector2(-1, -1)
	var pick: Dictionary = buildings[0]
	if not recipe.is_empty():
		var want := Production.stations_for(data, recipe.base, recipe.additives)
		for b in buildings:
			if b.id in want:
				pick = b
				break
	var size: Array = data.buildables[pick.id].size
	var room: Array = data.estates[estate_id].size
	var x := float(pick.x) + float(size[0]) / 2.0
	var y := minf(float(pick.y) + float(size[1]) + 0.5, float(room[1]) - 0.5)
	return Vector2(x, y)


## Where each role waits when there is nothing to do: either side of the door, one row above it.
static func idle_cell(data: Dictionary, estate_id: String, role: String) -> Vector2:
	var room: Array = data.estates[estate_id].size
	var w := float(room[0])
	var dx := -1.5 if role == "lab_hand" else 1.5
	return Vector2(clampf(floorf(w / 2.0) + 0.5 + dx, 0.5, w - 0.5), float(room[1]) - 1.5)


## Estate cell the worker should be walking to / standing at right now.
static func target_cell(g, worker_id: String) -> Vector2:
	var wi := Workers.find(g, worker_id)
	if wi < 0:
		return Vector2(-1, -1)
	var est: String = g.workers[wi].estate
	if est == "" or not g.estates.has(est):
		return Vector2(-1, -1)
	var e: Dictionary = g.estates[est]
	var role: String = Workers.candidate(g, worker_id).role
	var idle := idle_cell(g.data, est, role)
	var st := station_cell(g.data, est, e.buildings, e.recipe)
	var store := storage_cell(g.data, est)
	match activity(g, worker_id):
		COOK:
			return st if st.x >= 0.0 else idle
		FETCH:
			return store
		HAUL:
			if st.x < 0.0:
				return store
			var trip := float(Workers.cfg(g).haul_seconds) / (0.5 + float(Workers.candidate(g, worker_id).skill))
			return store if float(e.get("haul_t", 0.0)) < trip * 0.5 else st
	return idle


## Palette swaps for the worker's walker sprite: a stable outfit per worker id picked from the K2 style catalogue.
static func look_swaps(data: Dictionary, worker_id: String) -> Dictionary:
	var out := {}
	var h: int = absi(hash(worker_id))
	for cat in Style.WEAR:
		var items := Style.catalogue(data, cat)
		if items.is_empty():
			continue
		var keys: Array = items.keys()
		var ramp: Array = items[keys[(h / (1 + Style.WEAR.find(cat) * 7)) % keys.size()]].get("ramp", [])
		var src: Array = Style.PLAYER_SRC[cat]
		for i in mini(src.size(), ramp.size()):
			if src[i] != ramp[i]:
				out[Color(src[i])] = Color(ramp[i])
	return out
