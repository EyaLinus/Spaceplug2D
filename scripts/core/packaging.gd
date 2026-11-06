extends RefCounted
## Packaging tiers: the Packaging Table score (0..1) sets how well a batch is wrapped (Loose / Sealed / Shielded,
## data.packaging.tiers). The tier is stored in the product key as "#<tier>" (see Mixing.key); Loose has no suffix, so
## old saves and keys stay valid. In a patrol scan (Game.bust) every unit rolls its tier's `scan_survive` chance
## to stay in the cargo hold.

const LOOSE := 0


static func tiers(data: Dictionary) -> Array:
	return data.get("packaging", {}).get("tiers", [])


## Tier index for a packaging score; a missing score (quick batch, no table) is Loose.
static func tier_for(data: Dictionary, score: float) -> int:
	var t := LOOSE
	var list := tiers(data)
	for i in list.size():
		if score >= float(list[i].min):
			t = i
	return t


static func tier_info(data: Dictionary, tier: int) -> Dictionary:
	var list := tiers(data)
	if list.is_empty():
		return {"name": "Loose", "scan_survive": 0.0}
	return list[clampi(tier, 0, list.size() - 1)]


static func tier_name(data: Dictionary, tier: int) -> String:
	return str(tier_info(data, tier).get("name", "Loose"))


static func survive_chance(data: Dictionary, tier: int) -> float:
	return clampf(float(tier_info(data, tier).get("scan_survive", 0.0)), 0.0, 1.0)


## Rolls every unit of the products in `cargo` against its tier. Removes the lost units from `cargo` and returns
## {lost, kept}. `rng` is any RandomNumberGenerator.
static func scan(data: Dictionary, cargo: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var lost := 0
	var kept := 0
	for k in cargo.keys():
		if not str(k).contains(":"):
			continue
		var tier := int(_tier_of(str(k)))
		var chance := survive_chance(data, tier)
		var n := int(cargo[k])
		var keep := 0
		if chance > 0.0:
			for _i in n:
				if rng.randf() < chance:
					keep += 1
		lost += n - keep
		kept += keep
		if keep > 0:
			cargo[k] = keep
		else:
			cargo.erase(k)
	return {"lost": lost, "kept": kept}


static func _tier_of(product_key: String) -> int:
	var h := product_key.find("#")
	return 0 if h < 0 else int(product_key.substr(h + 1))
