class_name EffectsHub
extends Node
## Starts an effect for what happens on the farm: dust, splash and sparkle.

@export var farmer: Farmer

var _was_running: bool = false
var _ripe: Dictionary = {}


func _ready() -> void:
	farmer.arrived.connect(_on_arrived)
	Events.interaction_finished.connect(_on_interaction_finished)
	Events.product_collected.connect(_on_product_collected)
	for plot: SoilPlot in get_tree().get_nodes_in_group(&"soil_plots"):
		plot.changed.connect(_on_plot_changed.bind(plot))


func _physics_process(_delta: float) -> void:
	var running: bool = farmer.speed > farmer.run_threshold
	if running and not _was_running:
		Fx.spawn(self, &"dust", farmer.global_position)
	_was_running = running


func _on_arrived(position: Vector3) -> void:
	Fx.spawn(self, &"dust", position)


func _on_interaction_finished(interactable: Interactable, _farmer: Farmer) -> void:
	if interactable is SoilPlot and (interactable as SoilPlot).state == SoilPlot.State.WATERED:
		Fx.spawn(self, &"splash", interactable.global_position + Vector3.UP * 0.1)


func _on_plot_changed(plot: SoilPlot) -> void:
	var ripe: bool = plot.state == SoilPlot.State.RIPE
	if ripe and not _ripe.get(plot, false):
		Fx.spawn(self, &"sparkle", plot.global_position + Vector3.UP * 0.4)
	_ripe[plot] = ripe


func _on_product_collected(_item: ItemData, animal: Animal) -> void:
	Fx.spawn(self, &"sparkle", animal.global_position + Vector3.UP * 0.5)
