class_name Farmer
extends CharacterBody3D
## The player's character. A left click sets a goal on the ground, the NavigationAgent3D finds
## a way to it and the farmer walks along that way. Hold Shift to run, press Escape to stop.

signal target_set(position: Vector3)
signal arrived(position: Vector3)

const RAY_LENGTH: float = 200.0
const RAY_MASK: int = 1 | 8 # layer 1 (ground) and layer 4 (obstacle)

@export var walk_speed: float = 1.4
@export var run_speed: float = 3.2
@export var run_threshold: float = 2.2
@export var acceleration: float = 10.0
@export var turn_rate: float = 12.0

var speed: float = 0.0
var walking: bool = false

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var marker: ClickMarker = $ClickMarker


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("click_move"):
		var hit: Variant = pick_ground((event as InputEventMouseButton).position)
		if hit != null:
			walk_to(hit as Vector3)
	elif event.is_action_pressed("ui_cancel"):
		stop()


func pick_ground(screen_position: Vector2) -> Variant:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var from: Vector3 = camera.project_ray_origin(screen_position)
	var to: Vector3 = from + camera.project_ray_normal(screen_position) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, RAY_MASK)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("position")


func walk_to(point: Vector3) -> void:
	var goal: Vector3 = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), point)
	goal.y -= agent.path_height_offset
	agent.target_position = goal
	walking = true
	marker.show_at(goal)
	target_set.emit(goal)


func stop() -> void:
	walking = false
	velocity.x = 0.0
	velocity.z = 0.0


func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	if walking:
		if agent.is_navigation_finished():
			stop()
			arrived.emit(global_position)
		else:
			direction = global_position.direction_to(agent.get_next_path_position())
			direction.y = 0.0
			direction = direction.normalized()
	var top_speed: float = run_speed if Input.is_action_pressed("move_run") else walk_speed
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * top_speed, acceleration * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	speed = Vector2(velocity.x, velocity.z).length()
	if direction != Vector3.ZERO:
		var yaw: float = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-turn_rate * delta))
