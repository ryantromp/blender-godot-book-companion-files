class_name Market
extends RefCounted

const DROP: float = 0.05
const FLOOR: float = 0.5
const RECOVERY: int = 4
const MAX_SOLD: int = 20

var world_seed: int = 2026
var day: int = 1
var sold: Dictionary[StringName, int] = {}


func wobble(item: ItemData) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:%d:%s" % [world_seed, day, item.id]).hash()
	return 1.0 + 0.05 * rng.randi_range(-2, 2)


func demand(item: ItemData, extra: int = 0) -> float:
	return maxf(FLOOR, 1.0 - DROP * (sold.get(item.id, 0) + extra))


func price_of(item: ItemData, extra: int = 0) -> int:
	if item.sell_price <= 0:
		return 0
	return maxi(1, roundi(item.sell_price * wobble(item) * demand(item, extra)))


func quote(item: ItemData, amount: int) -> int:
	var total: int = 0
	for unit: int in amount:
		total += price_of(item, unit)
	return total


func record(item: ItemData, amount: int) -> void:
	sold[item.id] = mini(sold.get(item.id, 0) + amount, MAX_SOLD)


func new_day(new_number: int) -> void:
	day = new_number
	for id: StringName in sold.keys():
		sold[id] -= RECOVERY
		if sold[id] <= 0:
			sold.erase(id)
