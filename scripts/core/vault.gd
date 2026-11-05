extends RefCounted
## Hidden crate in your estates (P4 storage). Product you deposit leaves the hold, so a patrol bust or a knock-out
## cannot confiscate it. Headless; numbers in content.json "vault". State: g.vault = {"tier": int, "items": {key: qty}}.
## Deposit and withdraw only while standing inside an estate. Capacity grows with upgrade tiers.

const Mixing = preload("res://scripts/core/mixing.gd")


static func cfg(g) -> Dictionary:
	return g.data.vault


static func fresh() -> Dictionary:
	return {"tier": 0, "items": {}}


static func max_tier(g) -> int:
	return cfg(g).upgrade_costs.size()


static func capacity(g) -> int:
	return int(cfg(g).base_cap) + int(g.vault.tier) * int(cfg(g).cap_per_tier)


static func used(g) -> int:
	var n := 0
	for k in g.vault.items:
		n += int(g.vault.items[k])
	return n


static func free_space(g) -> int:
	return maxi(0, capacity(g) - used(g))


static func upgrade_cost(g) -> int:
	if int(g.vault.tier) >= max_tier(g):
		return -1
	return int(cfg(g).upgrade_costs[int(g.vault.tier)])


static func upgrade(g) -> Dictionary:
	var cost := upgrade_cost(g)
	if cost < 0:
		return g._fail("The crate is fully upgraded.")
	if g.credits < cost:
		return g._fail("Need %d cr for a bigger crate." % cost)
	g.credits -= cost
	g.vault.tier = int(g.vault.tier) + 1
	return g._ok("Crate upgraded: room for %d units." % capacity(g))


## Hold -> crate. Only product (the stuff a bust takes); raws are not worth hiding.
static func deposit(g, key: String, qty: int) -> Dictionary:
	if g.inside_estate == "":
		return g._fail("The crate is in your estate.")
	if qty <= 0 or not Mixing.is_product(key) or int(g.cargo.get(key, 0)) < qty:
		return g._fail("You don't carry that.")
	var n := mini(qty, free_space(g))
	if n <= 0:
		return g._fail("The crate is full.")
	g._add(g.cargo, key, -n)
	g._add(g.vault.items, key, n)
	return g._ok("Hid %d × %s in the crate." % [n, g.item_name(key)])


## Crate -> hold, as far as the hold has room.
static func withdraw(g, key: String, qty: int) -> Dictionary:
	if g.inside_estate == "":
		return g._fail("The crate is in your estate.")
	if qty <= 0 or int(g.vault.items.get(key, 0)) < qty:
		return g._fail("Not in the crate.")
	var n := mini(qty, g.cargo_free())
	if n <= 0:
		return g._fail("Cargo hold is full.")
	g._add(g.vault.items, key, -n)
	g._add(g.cargo, key, n)
	return g._ok("Took %d × %s from the crate." % [n, g.item_name(key)])


static func to_save(g) -> Dictionary:
	return {"tier": int(g.vault.tier), "items": g.vault.items.duplicate()}


static func from_save(g, d: Dictionary) -> void:
	g.vault = fresh()
	g.vault.tier = clampi(int(d.get("tier", 0)), 0, max_tier(g))
	var items: Dictionary = d.get("items", {})
	for k in items:
		var key: String = g._migrate_key(str(k))
		if Mixing.is_product(key) and int(items[k]) > 0:
			g.vault.items[key] = int(items[k])
