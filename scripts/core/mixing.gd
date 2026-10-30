extends RefCounted
## Product recipes: a base product plus an ordered list of additives yields a set of traits.
## Each additive first transforms traits already present (per its "transforms" table), then adds its own trait.
## Products are identified by a stable key "base:traitA+traitB" (traits sorted) so equal products stack in cargo.
## A quality grade other than Standard (index 1 in data.quality.grades) is appended as "@<grade>",
## e.g. "weed:overclock+radiant@2" is Premium; keys without a suffix are Standard (pre-0.1.3 saves stay valid).

const STANDARD := 1


static func traits_for(data: Dictionary, base: String, additives: Array) -> Array:
	var traits: Array = [data.bases[base].innate]
	var max_traits: int = int(data.get("max_traits", 4))
	for a in additives:
		var add: Dictionary = data.additives[a]
		var tf: Dictionary = add.get("transforms", {})
		for i in traits.size():
			if tf.has(traits[i]):
				traits[i] = tf[traits[i]]
		# a transform can produce a duplicate; keep traits unique
		var unique: Array = []
		for t in traits:
			if not unique.has(t):
				unique.append(t)
		traits = unique
		if not traits.has(add.adds) and traits.size() < max_traits:
			traits.append(add.adds)
	return traits


static func key(base: String, traits: Array, grade: int = STANDARD) -> String:
	var sorted := traits.duplicate()
	sorted.sort()
	var k := base + ":" + "+".join(PackedStringArray(sorted))
	return k if grade == STANDARD else "%s@%d" % [k, grade]


static func parse_key(product_key: String) -> Dictionary:
	var grade := STANDARD
	var at := product_key.find("@")
	if at >= 0:
		grade = int(product_key.substr(at + 1))
		product_key = product_key.substr(0, at)
	var parts := product_key.split(":")
	var traits: Array = []
	if parts.size() > 1 and parts[1] != "":
		for t in parts[1].split("+"):
			traits.append(t)
	return {"base": parts[0], "traits": traits, "grade": grade}


static func grade_info(data: Dictionary, grade: int) -> Dictionary:
	var grades: Array = data.get("quality", {}).get("grades", [])
	if grades.is_empty():
		return {"name": "Standard", "value_mult": 1.0}
	return grades[clampi(grade, 0, grades.size() - 1)]


static func is_product(item_key: String) -> bool:
	return item_key.contains(":")


static func value(data: Dictionary, product_key: String) -> float:
	var p := parse_key(product_key)
	var mult := 1.0
	for t in p.traits:
		mult += float(data.traits[t].value)
	return float(data.bases[p.base].base_value) * max(mult, 0.2) * float(grade_info(data, p.grade).value_mult)


static func display_name(data: Dictionary, product_key: String) -> String:
	var p := parse_key(product_key)
	var names: Array = []
	for t in p.traits:
		names.append(data.traits[t].name)
	var prefix: String = "" if p.grade == STANDARD else grade_info(data, p.grade).name + " "
	return "%s%s [%s]" % [prefix, data.bases[p.base].name, ", ".join(PackedStringArray(names))]
