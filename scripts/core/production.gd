extends RefCounted
## Production stations: which hands-on station steps a batch goes through and how the minigame scores
## (0..1 per station) turn into yield, quality grade and heat. Stations are data (data/content.json "stations",
## "station_order"), so an estate building can reuse any of them by id.
## A score that is missing (quick batch, skipped step) counts as data.quality.quick_score = Standard everything.
## Purity (extractor, refiner) is its own stat and joins the quality grade: grade quality =
## lerp(quality stations, purity stations, data.quality.purity_weight).


## Ordered station ids a batch of `base` with `additives` passes through.
static func stations_for(data: Dictionary, base: String, additives: Array) -> Array:
	var r: Array = []
	for id in data.get("station_order", []):
		var st: Dictionary = data.stations[id]
		if st.has("bases") and not base in st.bases:
			continue
		if st.get("needs_additives", false) and additives.is_empty():
			continue
		r.append(id)
	return r


## scores: station id -> 0..1. Returns {yield_mult, heat_mult, purity, quality, grade}.
static func outcome(data: Dictionary, scores: Dictionary) -> Dictionary:
	var q: Dictionary = data.quality
	var neutral := float(q.quick_score)
	var by_stat := {"yield": [], "quality": [], "purity": [], "heat": []}
	for id in scores:
		if data.stations.has(id):
			by_stat[data.stations[id].affects].append(clampf(float(scores[id]), 0.0, 1.0))
	var y := _avg(by_stat.yield, neutral)
	var h := _avg(by_stat.heat, neutral)
	var purity := _avg(by_stat.purity, neutral)
	var quality := lerpf(_avg(by_stat.quality, neutral), purity, float(q.get("purity_weight", 0.0)))
	return {
		"yield_mult": lerpf(float(q.yield_min), float(q.yield_max), y),
		"heat_mult": lerpf(float(q.heat_max), float(q.heat_min), h),
		"purity": purity,
		"quality": quality,
		"grade": grade_for(data, quality),
	}


static func grade_for(data: Dictionary, quality: float) -> int:
	var g := 0
	var grades: Array = data.quality.grades
	for i in grades.size():
		if quality >= float(grades[i].min):
			g = i
	return g


static func output_qty(qty: int, yield_mult: float) -> int:
	return maxi(1, int(round(qty * yield_mult)))


static func _avg(a: Array, fallback: float) -> float:
	if a.is_empty():
		return fallback
	var s := 0.0
	for x in a:
		s += x
	return s / a.size()
