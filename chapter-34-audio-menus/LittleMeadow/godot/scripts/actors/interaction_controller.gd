class_name InteractionController
extends Node
## Turns the mouse into hover and use. A ray from the mouse finds the Interactable under the pointer
## and shows its prompt. A click on it sends the farmer there, and the farmer uses it on arrival.

const RAY_LENGTH: float = 200.0
const HOVER_MASK: int = 1 | 2 | 8 # ground, interactable and obstacle: a wall in front hides an Interactable

var hovered: Interactable
var pending: Interactable
var label: Label3D

var _mouse: Vector2 = Vector2(-1.0, -1.0)

@onready var farmer: Farmer = get_parent() as Farmer
@onready var animation: FarmerAnimation = farmer.get_node("AnimationTree") as FarmerAnimation


func _ready() -> void:
	farmer.target_set.connect(_on_target_set)
	farmer.arrived.connect(_on_arrived)
	label = Label3D.new()
	label.top_level = true
	label.visible = false
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.no_depth_test = true
	label.pixel_size = 0.0005
	label.font_size = 64
	label.outline_size = 14
	label.modulate = Color("FFF5CC")
	label.outline_modulate = Color("14191A")
	label.render_priority = 10
	label.outline_render_priority = 9
	add_child(label)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("click_move"):
		var target: Interactable = pick((event as InputEventMouseButton).position)
		if target != null:
			get_viewport().set_input_as_handled()
			_start(target)
	elif event.is_action_pressed("ui_cancel"):
		pending = null


func _physics_process(_delta: float) -> void:
	var found: Interactable = pick(_mouse)
	if found != hovered:
		if is_instance_valid(hovered):
			hovered.set_hovered(false)
		hovered = found
		if hovered != null:
			hovered.set_hovered(true)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW if hovered == null else Input.CURSOR_POINTING_HAND)
	label.visible = hovered != null
	if hovered != null:
		label.text = hovered.prompt_text
		label.global_position = hovered.global_position + Vector3.UP * hovered.prompt_height


## The Interactable under a screen position, or null. A building in front of it hides it.
func pick(screen_position: Vector2) -> Interactable:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return null
	var from: Vector3 = camera.project_ray_origin(screen_position)
	var to: Vector3 = from + camera.project_ray_normal(screen_position) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, HOVER_MASK)
	query.collide_with_areas = true
	var hit: Dictionary = farmer.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as Interactable


func _start(target: Interactable) -> void:
	if _in_range(target):
		pending = null
		farmer.stop()
		_use(target)
	else:
		farmer.walk_to(target.approach_point(farmer.global_position))
		pending = target # after walk_to: walk_to sends target_set, and that clears the old goal


func _in_range(target: Interactable) -> bool:
	var flat := Vector3(target.global_position.x - farmer.global_position.x, 0.0, target.global_position.z - farmer.global_position.z)
	return flat.length() <= target.interact_range


func _use(target: Interactable) -> void:
	if not target.can_interact(farmer):
		return
	var to: Vector3 = target.global_position - farmer.global_position
	farmer.rotation.y = atan2(-to.x, -to.z)
	Events.interaction_started.emit(target, farmer)
	if target.action_name != "":
		animation.play_action(StringName(target.action_name))
	target.interact(farmer)


func _on_target_set(_point: Vector3) -> void:
	pending = null


func _on_arrived(_point: Vector3) -> void:
	var target: Interactable = pending
	pending = null
	if target != null and _in_range(target):
		_use(target)
