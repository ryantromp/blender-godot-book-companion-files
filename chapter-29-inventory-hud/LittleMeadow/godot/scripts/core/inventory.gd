extends Node
## What the farmer owns: 24 slots, each an ItemStack. The harvest and the animals' products
## arrive here by themselves, because this script listens to the bus.

const SLOT_COUNT: int = 24
const ITEM_FOLDER: String = "res://resources/items/"
const START_ITEMS: Dictionary = {
	&"seed_carrot": 8, &"seed_wheat": 6, &"seed_pumpkin": 4,
	&"hay": 6, &"grain": 6, &"dog_biscuit": 4,
}

var slots: Array[ItemStack] = []


func _ready() -> void:
	for index: int in SLOT_COUNT:
		slots.append(ItemStack.new())
	Events.crop_harvested.connect(_on_crop_harvested)
	Events.product_collected.connect(_on_product_collected)
	give_starting_items()


## Puts `amount` of `item` into the bag. Returns how many did not fit (0 when all of them did).
func add(item: ItemData, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var left: int = amount
	for stack: ItemStack in slots:
		if stack.holds(item) and stack.count < item.stack_size:
			left -= _put(stack, item, left)
	for stack: ItemStack in slots:
		if left > 0 and stack.is_empty():
			left -= _put(stack, item, left)
	if left < amount:
		Events.item_added.emit(item, amount - left)
		Events.inventory_changed.emit()
	return left


## Takes `amount` of `item` out of the bag and returns true, or returns false and changes nothing
## when there are fewer than that.
func remove(item: ItemData, amount: int = 1) -> bool:
	if amount <= 0 or count_of(item) < amount:
		return false
	var left: int = amount
	for index: int in range(slots.size() - 1, -1, -1):
		var stack: ItemStack = slots[index]
		if left > 0 and stack.holds(item):
			var taken: int = mini(stack.count, left)
			stack.count -= taken
			left -= taken
			if stack.count == 0:
				stack.item = null
	Events.item_removed.emit(item, amount)
	Events.inventory_changed.emit()
	return true


func count_of(item: ItemData) -> int:
	var total: int = 0
	for stack: ItemStack in slots:
		if stack.holds(item):
			total += stack.count
	return total


## True when `amount` more of `item` would fit.
func can_add(item: ItemData, amount: int = 1) -> bool:
	var room: int = 0
	for stack: ItemStack in slots:
		if stack.is_empty():
			room += item.stack_size
		elif stack.holds(item):
			room += item.stack_size - stack.count
	return room >= amount


func used_slots() -> int:
	var used: int = 0
	for stack: ItemStack in slots:
		if not stack.is_empty():
			used += 1
	return used


func clear() -> void:
	for stack: ItemStack in slots:
		stack.item = null
		stack.count = 0
	Events.inventory_changed.emit()


func give_starting_items() -> void:
	for id: StringName in START_ITEMS:
		add(load(ITEM_FOLDER + String(id) + ".tres") as ItemData, int(START_ITEMS[id]))


func _put(stack: ItemStack, item: ItemData, wanted: int) -> int:
	var moved: int = mini(wanted, item.stack_size - stack.count)
	stack.item = item
	stack.count += moved
	return moved


func _on_crop_harvested(crop: CropData, _plot: SoilPlot) -> void:
	add(crop.harvest_item)


func _on_product_collected(item: ItemData, _animal: Animal) -> void:
	add(item)
