class_name ItemData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D
@export_range(1, 999) var stack_size: int = 99
@export var color: Color = Color("8A8F98")
@export var short_name: String = ""
@export_range(0, 9999) var buy_price: int = 0
@export_range(0, 9999) var sell_price: int = 0
