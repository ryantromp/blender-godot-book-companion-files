class_name AudioHooks
extends Node

const DAWN_HOUR: int = 5
const TOOL_SOUNDS: Dictionary = {&"hoe": &"hoe", &"seeds": &"seed", &"can": &"water"}


func _ready() -> void:
	var play: Callable = AudioBus.play
	Events.build_removed.connect(play.bind(&"crunch").unbind(2))
	Events.build_denied.connect(play.bind(&"denied").unbind(2))
	Events.trade_denied.connect(play.bind(&"denied").unbind(1))
	Events.save_failed.connect(play.bind(&"denied").unbind(1))
	Events.item_bought.connect(play.bind(&"buy").unbind(3))
	Events.item_sold.connect(play.bind(&"sell").unbind(3))
	Events.plan_unlocked.connect(play.bind(&"unlock").unbind(1))
	Events.shop_opened.connect(play.bind(&"ui_open"))
	Events.shop_closed.connect(play.bind(&"ui_close"))
	Events.game_saved.connect(play.bind(&"save").unbind(1))
	Events.game_loaded.connect(play.bind(&"load").unbind(1))
	Events.tool_changed.connect(play.bind(&"ui_tick").unbind(2))
	Events.build_placed.connect(_on_build_placed)
	Events.build_mode_changed.connect(_on_build_mode_changed)
	Events.money_moved.connect(_on_money_moved)
	Events.hour_changed.connect(_on_hour_changed)
	Events.crop_harvested.connect(_on_crop_harvested)
	Events.product_collected.connect(_on_product_collected)
	Events.animal_fed.connect(_on_animal_fed)
	Events.interaction_finished.connect(_on_interaction_finished)


func _on_build_placed(_item: BuildItemData, node: Node3D) -> void:
	AudioBus.play(&"hammer", node.global_position)


func _on_build_mode_changed(active: bool) -> void:
	AudioBus.play(&"ui_open" if active else &"ui_close")


func _on_money_moved(amount: int, _reason: String) -> void:
	if amount > 0:
		AudioBus.play(&"coin")


func _on_hour_changed(hour: int) -> void:
	if hour == DAWN_HOUR:
		AudioBus.play(&"chime")


func _on_crop_harvested(_crop: CropData, plot: SoilPlot) -> void:
	AudioBus.play(&"harvest", plot.global_position)


func _on_product_collected(_item: ItemData, animal: Animal) -> void:
	AudioBus.play(&"pickup", animal.global_position)


func _on_animal_fed(animal: Animal) -> void:
	AudioBus.play(&"feed", animal.global_position)


func _on_interaction_finished(interactable: Interactable, farmer: Farmer) -> void:
	if interactable is SoilPlot:
		var sound: StringName = TOOL_SOUNDS.get(farmer.tools.current, &"")
		if sound != &"":
			AudioBus.play(sound, interactable.global_position)
	elif interactable is WaterPump:
		AudioBus.play(&"water", interactable.global_position)
