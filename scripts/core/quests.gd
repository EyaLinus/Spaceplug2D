extends RefCounted
## Quest core (Q1): data-driven quests that advance on game events. Pure functions on a Game, no scene deps.
##
## Quests live in content.json "quests" (array, in display order). Each quest:
##   {id, title, desc, tutorial (bool), requires [quest ids that must be done first], reward {credits},
##    steps [{kind, text, <condition fields>, qty, waypoint}]}
## A step ends when the matching game event arrives (Game._emit calls on_event). Step kinds and their condition fields:
##   buy      item (raw/additive id, optional), qty        <- "bought"
##   cook     base (optional), qty = batches               <- "lab_started"
##   sell     base (optional), qty = units                 <- "sold"
##   dock     loc                                          <- "docked"
##   deliver  item (optional), qty                         <- "order_delivered"
##   talk     contact (optional)                           <- "met" (first conversation with a named person)
##   estate   estate (optional)                            <- "estate_bought"
##   jump     to (system, optional)                        <- "jumped"
## dock, estate and jump steps also finish at once when their condition already holds (you are docked there, you own
## an estate, you are in that system), so a quest never waits for something that is already true.
## `waypoint` (location id) is where the HUD arrow points; "" = no arrow.
##
## Game.quests: quest id -> {state: "active" | "done", step: int, progress: int}. Quests without an entry have not started.
## Game.quest_tracked: the quest the HUD tracks ("" = the first active one). Game.quests_unseen: news since the Quests app
## was last opened (runtime only). Events: quest_started, quest_step, quest_done.

const Mixing = preload("res://scripts/core/mixing.gd")
const Galaxy = preload("res://scripts/core/galaxy.gd")

const KINDS := ["buy", "cook", "sell", "dock", "deliver", "talk", "estate", "jump"]
const EVENT_OF := {"buy": "bought", "cook": "lab_started", "sell": "sold", "dock": "docked", "deliver": "order_delivered",
	"talk": "met", "estate": "estate_bought", "jump": "jumped"}


static func list(g) -> Array:
	return g.data.get("quests", [])


static func find(g, id: String) -> Dictionary:
	for q in list(g):
		if str(q.id) == id:
			return q
	return {}


static func state(g, id: String) -> Dictionary:
	return g.quests.get(id, {})


static func is_active(g, id: String) -> bool:
	return str(state(g, id).get("state", "")) == "active"


static func is_done(g, id: String) -> bool:
	return str(state(g, id).get("state", "")) == "done"


## Quests in content order that are running / finished.
static func active(g) -> Array:
	var r: Array = []
	for q in list(g):
		if is_active(g, str(q.id)):
			r.append(q)
	return r


static func done(g) -> Array:
	var r: Array = []
	for q in list(g):
		if is_done(g, str(q.id)):
			r.append(q)
	return r


static func step_def(g, id: String) -> Dictionary:
	var q := find(g, id)
	var s := state(g, id)
	if q.is_empty() or s.is_empty() or str(s.state) != "active":
		return {}
	var steps: Array = q.steps
	var i := int(s.step)
	return steps[i] if i < steps.size() else {}


## Units / actions needed for the current step.
static func need(step: Dictionary) -> int:
	return maxi(int(step.get("qty", 1)), 1)


## "2/5" style progress text for the current step, "" for single-action steps.
static func progress_text(g, id: String) -> String:
	var st := step_def(g, id)
	if st.is_empty() or need(st) <= 1:
		return ""
	return "%d/%d" % [int(state(g, id).progress), need(st)]


## Quest the HUD tracks: the pinned one while it runs, else the first active quest. "" = none.
static func tracked(g) -> String:
	if is_active(g, g.quest_tracked):
		return g.quest_tracked
	var a := active(g)
	return str(a[0].id) if not a.is_empty() else ""


static func track(g, id: String) -> Dictionary:
	if not is_active(g, id):
		return {"ok": false, "msg": "That quest is not active."}
	g.quest_tracked = id
	return {"ok": true, "msg": "Tracking %s." % str(find(g, id).title)}


# ---------------------------------------------------------------- lifecycle

## New game: nothing started yet, then everything without prerequisites begins (silently).
static func init(g) -> void:
	g.quests = {}
	g.quest_tracked = ""
	g.quests_unseen = 0
	_start_available(g, false)


static func _start_available(g, announce: bool) -> void:
	for q in list(g):
		var id := str(q.id)
		if g.quests.has(id):
			continue
		var ok := true
		for r in q.get("requires", []):
			if not is_done(g, str(r)):
				ok = false
		if not ok:
			continue
		g.quests[id] = {"state": "active", "step": 0, "progress": 0}
		if announce:
			g.quests_unseen += 1
			g._emit("quest_started", {"quest": id})
		_settle(g, id)


## Called by Game._emit for every event.
static func on_event(g, kind: String, payload: Dictionary) -> void:
	if g.quests.is_empty():
		return
	for q in active(g):
		var id := str(q.id)
		var st := step_def(g, id)
		if st.is_empty() or EVENT_OF.get(str(st.kind), "") != kind or not matches(g, st, payload):
			continue
		var s: Dictionary = g.quests[id]
		s.progress = int(s.progress) + amount(st, payload)
		if int(s.progress) >= need(st):
			_advance(g, id)
		else:
			g.quests_unseen += 1


## True when the event satisfies the step's condition fields.
static func matches(_g, st: Dictionary, p: Dictionary) -> bool:
	match str(st.kind):
		"buy":
			return not st.has("item") or str(p.get("item", "")) == str(st.item)
		"cook":
			return not st.has("base") or Mixing.parse_key(str(p.get("product", ""))).base == str(st.base)
		"sell":
			return not st.has("base") or Mixing.parse_key(str(p.get("product", ""))).base == str(st.base)
		"dock":
			return str(p.get("location", "")) == str(st.get("loc", ""))
		"deliver":
			return not st.has("item") or str(p.get("item", "")) == str(st.item)
		"talk":
			return not st.has("contact") or str(p.get("contact", "")) == str(st.contact)
		"estate":
			return not st.has("estate") or str(p.get("estate", "")) == str(st.estate)
		"jump":
			return not st.has("to") or str(p.get("to", "")) == str(st.to)
	return false


## How much one event counts toward the step.
static func amount(st: Dictionary, p: Dictionary) -> int:
	if str(st.kind) in ["buy", "sell", "deliver"]:
		return maxi(int(p.get("qty", 1)), 0)
	return 1


## A step whose condition already holds finishes at once (see the header).
static func _already(g, st: Dictionary) -> bool:
	match str(st.kind):
		"dock":
			return g.location == str(st.get("loc", ""))
		"estate":
			if st.has("estate"):
				return g.estate_owned(str(st.estate))
			for e in g.estates:
				if not g.data.estates[e].get("ship", false) and not g.data.estates[e].get("starter", false):
					return true
			return false
		"jump":
			return st.has("to") and g.system == str(st.to)
	return false


static func _settle(g, id: String) -> void:
	var st := step_def(g, id)
	if not st.is_empty() and _already(g, st):
		_advance(g, id)


static func _advance(g, id: String) -> void:
	var s: Dictionary = g.quests[id]
	var q := find(g, id)
	var steps: Array = q.steps
	s.step = int(s.step) + 1
	s.progress = 0
	g.quests_unseen += 1
	if int(s.step) < steps.size():
		g._emit("quest_step", {"quest": id, "step": int(s.step)})
		_settle(g, id)
		return
	s.state = "done"
	var reward: Dictionary = q.get("reward", {})
	var credits := int(reward.get("credits", 0))
	g.credits += credits
	g._emit("quest_done", {"quest": id, "credits": credits})
	_start_available(g, true)


## Finishes every quest flagged "tutorial" without rewards (old saves from before the quest system).
static func skip_tutorial(g) -> void:
	for q in list(g):
		if q.get("tutorial", false):
			g.quests[str(q.id)] = {"state": "done", "step": (q.steps as Array).size(), "progress": 0}
	_start_available(g, false)


# ---------------------------------------------------------------- waypoint

## Location id the HUD arrow points at for the tracked quest. When it lies in another system the arrow points at the jump
## gate on the way. "" = no waypoint (none set, or you are docked there).
static func waypoint(g) -> String:
	var id := tracked(g)
	if id == "":
		return ""
	var wp := str(step_def(g, id).get("waypoint", ""))
	if wp == "" or not g.data.locations.has(wp) or g.location == wp:
		return ""
	var there: String = g.loc_system(wp)
	if there == g.system:
		return wp
	var route := Galaxy.route(g, g.system, there)
	if route.size() < 2:
		return ""
	var gates := Galaxy.gates(g, g.system, str(route[1]))
	return str(gates[0]) if not gates.is_empty() else ""


# ---------------------------------------------------------------- save / load

static func to_save(g) -> Dictionary:
	return {"states": g.quests.duplicate(true), "tracked": g.quest_tracked}


## Old saves (no "quests" key) skip the tutorial: they are past it.
static func from_save(g, d: Dictionary) -> void:
	if not d.has("quests"):
		skip_tutorial(g)
		return
	var src: Dictionary = d.quests if typeof(d.quests) == TYPE_DICTIONARY else {}
	var states: Dictionary = src.get("states", {}) if typeof(src.get("states", {})) == TYPE_DICTIONARY else {}
	g.quests = {}
	for q in list(g):
		var id := str(q.id)
		var e = states.get(id)
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var steps: Array = q.steps
		var st := str(e.get("state", "active"))
		if st == "done":
			g.quests[id] = {"state": "done", "step": steps.size(), "progress": 0}
		else:
			g.quests[id] = {"state": "active", "step": clampi(int(e.get("step", 0)), 0, steps.size() - 1), "progress": maxi(int(e.get("progress", 0)), 0)}
	g.quest_tracked = str(src.get("tracked", ""))
	_start_available(g, false)
