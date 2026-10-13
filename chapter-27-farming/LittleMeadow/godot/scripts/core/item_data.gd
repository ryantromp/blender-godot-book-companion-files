class_name ItemData
extends Resource
## One kind of thing the farmer can own: a seed, a carrot, later a tool. It is data only.
## Chapter 29's inventory counts these.

@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D
@export_range(1, 999) var stack_size: int = 99
