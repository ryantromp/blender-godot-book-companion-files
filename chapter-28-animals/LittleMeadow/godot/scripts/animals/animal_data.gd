class_name AnimalData
extends Resource
## One kind of farm animal, as data: what it eats, what it makes, how far it roams and how fast it walks.
## The Animal script reads these values, so a new animal needs a new file and no new code.

@export var id: StringName = &""
@export var display_name: String = ""
@export var feed_item: ItemData
@export var product: ItemData
@export var product_mesh: Mesh
@export var product_offset: Vector3 = Vector3.ZERO
@export_range(1, 5) var days_to_produce: int = 1
@export var wander_radius: float = 3.0
@export var speed: float = 0.6
@export var clip_speed: float = 0.6
@export var idle_seconds: Vector2 = Vector2(2.0, 6.0)
@export var eat_seconds: Vector2 = Vector2(2.0, 4.0)
@export_range(0.0, 1.0) var eat_chance: float = 0.4
@export var eat_clip: StringName = &""
@export var cheer_clip: StringName = &""
