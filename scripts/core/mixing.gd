extends RefCounted
## Product recipes: a base product plus an ordered list of additives yields a set of traits.
## Each additive first transforms traits already present (per its "transforms" table), then adds its own trait.
## Products are identified by a stable key "base:traitA+traitB" (traits sorted) so equal products stack in cargo.


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


static func key(base: String, traits: Array) -> String:
	var sorted := traits.duplicate()
	sorted.sort()
	return base + ":" + "+".join(PackedStringArray(sorted))


static func parse_key(product_key: String) -> Dictionary:
	var parts := product_key.split(":")
	var traits: Array = []
	if parts.size() > 1 and parts[1] != "":
		for t in parts[1].split("+"):
			traits.append(t)
	return {"base": parts[0], "traits": traits}


static func is_product(item_key: String) -> bool:
	return item_key.contains(":")


static func value(data: Dictionary, product_key: String) -> float:
	var p := parse_key(product_key)
	var mult := 1.0
	for t in p.traits:
		mult += float(data.traits[t].value)
	return float(data.bases[p.base].base_value) * max(mult, 0.2)


static func display_name(data: Dictionary, product_key: String) -> String:
	var p := parse_key(product_key)
	var names: Array = []
	for t in p.traits:
		names.append(data.traits[t].name)
	return "%s [%s]" % [data.bases[p.base].name, ", ".join(PackedStringArray(names))]
