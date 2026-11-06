extends RefCounted
## Running away raises heat (ROADMAP P3). Pure rule over a Game, no scene deps; numbers in content.json "heat":
##   flee_chase_per_second  heat per second while sprinting in the sight of an officer who is chasing you
##   flee_carry_per_second  heat per second while sprinting in the sight of any officer with product aboard
##   flee_heat_cap          the flee rule never pushes heat above this (a bust or a sale still can)
## Out of sight, or walking, it adds nothing. The surface only reports what it sees (`tick`).


## Adds heat for `dt` seconds of sprinting. Returns the heat added (0 when the rule does not apply).
static func tick(g, dt: float, sprinting: bool, seen: bool, chasing: bool) -> float:
	if not sprinting or not seen or dt <= 0.0:
		return 0.0
	var h: Dictionary = g.data.heat
	var rate := 0.0
	if chasing:
		rate = float(h.get("flee_chase_per_second", 0.0))
	elif g.has_contraband():
		rate = float(h.get("flee_carry_per_second", 0.0))
	var room := maxf(0.0, float(h.get("flee_heat_cap", h.max)) - g.heat)
	var add := minf(rate * dt, room)
	if add > 0.0:
		g.add_heat(add)
	return add
