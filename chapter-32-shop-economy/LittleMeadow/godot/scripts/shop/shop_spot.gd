class_name ShopSpot
extends Interactable


func interact(farmer: Farmer) -> void:
	Events.shop_requested.emit()
	super(farmer)
