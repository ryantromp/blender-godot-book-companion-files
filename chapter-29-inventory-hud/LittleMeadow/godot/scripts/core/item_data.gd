class_name ItemData
extends Resource
## One kind of thing the farmer can own: a seed, a carrot, an egg. It is data only.
## Until real icons arrive (Chapter 34) the bag draws `color` and `short_name` instead.

@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D
@export_range(1, 999) var stack_size: int = 99
@export var color: Color = Color("8A8F98")
@export var short_name: String = ""
