class_name BuildCatalog
extends Resource

@export var items: Array[BuildItemData] = []


func find(id: StringName) -> BuildItemData:
	for item: BuildItemData in items:
		if item.id == id:
			return item
	return null


func in_category(category: BuildItemData.Category) -> Array[BuildItemData]:
	var found: Array[BuildItemData] = []
	for item: BuildItemData in items:
		if item.category == category and item.unlocked:
			found.append(item)
	return found
