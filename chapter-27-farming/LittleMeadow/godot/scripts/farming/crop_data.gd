class_name CropData
extends Resource
## Everything that makes one crop different from another: how fast it grows, how it looks at each
## stage, which seed plants it and which item it gives back. It is data only.

@export var id: StringName = &""
@export var display_name: String = ""
@export_range(1, 5) var days_per_stage: int = 1
@export var stage_scenes: Array[PackedScene] = []
@export var seed_item: ItemData
@export var harvest_item: ItemData
@export var sell_price: int = 10


## The number of the ripe stage: 3 for a crop with four models.
func last_stage() -> int:
	return stage_scenes.size() - 1


## Watered days from a seed to a ripe plant.
func days_to_grow() -> int:
	return last_stage() * days_per_stage
