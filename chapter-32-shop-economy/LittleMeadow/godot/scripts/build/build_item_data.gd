class_name BuildItemData
extends Resource

enum Category { FENCE, BUILDING, DECOR }

const CATEGORY_NAMES: PackedStringArray = ["Fences", "Buildings", "Decor"]

@export var id: StringName
@export var display_name: String = ""
@export var category: Category = Category.DECOR
@export var scene: PackedScene
@export_range(0, 9999) var cost: int = 5
@export var footprint: Vector2i = Vector2i(1, 1)
@export var rotatable: bool = true
@export var pivot_offset: Vector3 = Vector3.ZERO
@export var line: bool = false
@export var color: Color = Color("8A8F98")
@export var short_name: String = ""
@export var unlocked: bool = true
@export_range(0, 9999) var unlock_price: int = 0


func refund() -> int:
	return floori(cost / 2.0)
