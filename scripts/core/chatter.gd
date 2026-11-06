extends RefCounted
## B1 idle chatter: short speech bubbles above people near the player. The line pool lives in data/chatter.json
## (merged into data as `chatter`): lines optionally tagged with a planet (`loc`) and a time-of-day `period`.
## Pure functions plus a tiny per-person state ({cd: seconds until the next line, last: text}); no scene deps.


static func rules(data: Dictionary) -> Dictionary:
	return data.get("chatter", {}).get("rules", {})


## Period id ("morning", "day", ...) containing `at_hour`; periods may wrap past midnight.
static func period(data: Dictionary, at_hour: float) -> String:
	var h := fposmod(at_hour, 24.0)
	for p in data.get("chatter", {}).get("periods", []):
		var f := float(p.from)
		var t := float(p.to)
		if (f <= t and h >= f and h < t) or (f > t and (h >= f or h < t)):
			return str(p.id)
	return ""


## Texts that fit this planet and hour (untagged lines fit everywhere / always).
static func pool(data: Dictionary, loc: String, at_hour: float) -> Array:
	var per := period(data, at_hour)
	var out: Array = []
	for l in data.get("chatter", {}).get("lines", []):
		if str(l.get("loc", loc)) == loc and str(l.get("period", per)) == per:
			out.append(str(l.text))
	return out


## A random line from the pool, not the same as `last` when there is a choice. "" if the pool is empty.
static func pick(data: Dictionary, loc: String, at_hour: float, rng: RandomNumberGenerator, last: String = "") -> String:
	var p := pool(data, loc, at_hour)
	if p.size() > 1:
		p.erase(last)
	return "" if p.is_empty() else str(p[rng.randi() % p.size()])


static func new_state(data: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var g: Array = rules(data).get("first_gap", [1.0, 5.0])
	return {"cd": rng.randf_range(float(g[0]), float(g[1])), "last": ""}


## Advances one person's timer. Returns the line to say now, or "" (cooling down, out of earshot, `busy` = in a
## conversation, or `can_speak` false because the surface already shows enough bubbles).
static func tick(data: Dictionary, st: Dictionary, delta: float, near: bool, busy: bool, can_speak: bool,
		loc: String, at_hour: float, rng: RandomNumberGenerator) -> String:
	if not near or busy:
		return ""
	st.cd = float(st.cd) - delta
	if float(st.cd) > 0.0 or not can_speak:
		return ""
	var g: Array = rules(data).get("gap", [9.0, 22.0])
	st.cd = rng.randf_range(float(g[0]), float(g[1]))
	var line := pick(data, loc, at_hour, rng, str(st.last))
	if line != "":
		st.last = line
	return line
