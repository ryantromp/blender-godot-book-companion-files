extends Node

func _ready() -> void:
	$Cow.add_to_group("thirsty")
	var count: int = get_tree().get_node_count_in_group("thirsty")
	print(count, " animals are thirsty")
	for animal: Node in get_tree().get_nodes_in_group("thirsty"):
		print("watering ", animal.name)
	get_tree().quit()
