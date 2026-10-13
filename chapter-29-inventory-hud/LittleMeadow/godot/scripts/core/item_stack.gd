class_name ItemStack
extends RefCounted
## One slot of the bag: a kind of item and how many of it are stacked there.

var item: ItemData
var count: int = 0


func is_empty() -> bool:
	return item == null or count <= 0


func holds(other: ItemData) -> bool:
	return item != null and other != null and item.id == other.id
