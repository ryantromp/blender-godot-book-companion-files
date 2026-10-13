class_name PlotLook
extends Node3D
## Draws a SoilPlot: a dark patch once it is tilled, a darker one while it is wet,
## and the model of the crop at its current stage.

@export var soil: SoilPlot

@onready var tilled: MeshInstance3D = $Tilled
@onready var wet: MeshInstance3D = $Wet
@onready var crop_anchor: Node3D = $Crop


func _ready() -> void:
	soil.changed.connect(_update)
	_update()


func _update() -> void:
	tilled.visible = soil.state != SoilPlot.State.EMPTY
	wet.visible = soil.state == SoilPlot.State.WATERED
	for old: Node in crop_anchor.get_children():
		old.free()
	if soil.crop != null:
		crop_anchor.add_child(soil.crop.stage_scenes[soil.stage].instantiate())
