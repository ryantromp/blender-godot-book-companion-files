class_name ProductPickup
extends Interactable
## An egg or a pail of milk lying on the ground. Using it hands the item to the bus and removes it.

var item: ItemData
var animal: Animal

var _busy: bool = false


func setup(product: ItemData, shape: Mesh, from: Animal) -> void:
	item = product
	animal = from
	prompt_text = "Collect %s" % product.display_name.to_lower()
	var body := get_parent().get_node("Mesh") as MeshInstance3D
	body.mesh = shape
	body.position.y = shape.get_aabb().size.y * 0.5


func can_interact(farmer: Farmer) -> bool:
	if farmer.tools.current != &"hand":
		Events.hint_shown.emit("Use your hands (4).")
		return false
	return not _busy


func interact(farmer: Farmer) -> void:
	_busy = true
	await farmer.animation.wait_for_action()
	Events.product_collected.emit(item, animal)
	super(farmer)
	get_parent().queue_free()
