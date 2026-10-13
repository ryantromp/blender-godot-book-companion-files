class_name Interactable
extends Area3D
## Anything the farmer can walk up to and use. The Area3D sits on collision layer 2 (interactable)
## and looks at nothing (mask 0). The mouse ray finds it, the InteractionController does the rest.
## Subclasses override can_interact() and interact().

signal hovered
signal unhovered
signal interacted(farmer: Farmer)

@export var prompt_text: String = "Use"
@export var interact_range: float = 1.5
@export var action_name: String = ""
@export var prompt_height: float = 1.6

var is_hovered: bool = false

var _overlay: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _time: float = 0.0


func _ready() -> void:
	if collision_layer != 2 or collision_mask != 0:
		push_warning("%s: an Interactable belongs on layer 2 with mask 0." % name)
	for node: Node in get_parent().find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_overlay.albedo_color = Color("F2C94C", 0.10)
	interacted.connect(_on_interacted)
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	_overlay.albedo_color.a = 0.10 + 0.04 * sin(_time * 6.0)


## Virtual: return false to refuse the use (a full can, a pump that is busy).
func can_interact(_farmer: Farmer) -> bool:
	return true


## Virtual: do the thing, then emit `interacted`. The base class only emits the signal.
func interact(farmer: Farmer) -> void:
	interacted.emit(farmer)


## Where the farmer should walk to: a point on the line from here to `from`, inside the object.
## The navigation map moves it to the nearest walkable point.
func approach_point(from: Vector3) -> Vector3:
	var away := Vector3(from.x - global_position.x, 0.0, from.z - global_position.z)
	return global_position + away.normalized() * interact_range * 0.5


func set_hovered(value: bool) -> void:
	if value == is_hovered:
		return
	is_hovered = value
	var material: Material = _overlay if value else null
	for mesh: MeshInstance3D in _meshes:
		mesh.material_overlay = material
	set_process(value)
	_time = 0.0
	if value:
		hovered.emit()
	else:
		unhovered.emit()


func _on_interacted(farmer: Farmer) -> void:
	Events.interaction_finished.emit(self, farmer)
