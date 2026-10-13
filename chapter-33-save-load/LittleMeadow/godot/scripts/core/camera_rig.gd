class_name CameraRig
extends Node3D

@export var target: Node3D = null
@export_range(-80.0, -20.0, 1.0) var pitch_degrees: float = -50.0
@export var zoom_min: float = 6.0
@export var zoom_max: float = 30.0
@export var zoom_factor: float = 0.85
@export var turn_speed: float = 90.0
@export var drag_degrees_per_pixel: float = 0.3
@export var smoothing: float = 8.0
@export var bounds: float = 24.0

var wanted_yaw: float = 0.0
var wanted_distance: float = 22.0
var yaw: float = 0.0
var distance: float = 22.0

@onready var pivot: Node3D = $Pivot
@onready var camera: Camera3D = $Pivot/Camera3D


func _ready() -> void:
	pivot.rotation_degrees.x = pitch_degrees
	wanted_distance = clampf(camera.position.z, zoom_min, zoom_max)
	wanted_yaw = rotation_degrees.y
	Events.game_loaded.connect(snap.unbind(1))
	snap()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cam_zoom_in", false, true):
		wanted_distance = clampf(wanted_distance * zoom_factor, zoom_min, zoom_max)
	elif event.is_action_pressed("cam_zoom_out", false, true):
		wanted_distance = clampf(wanted_distance / zoom_factor, zoom_min, zoom_max)
	elif event is InputEventMouseMotion and Input.is_action_pressed("cam_rotate_drag"):
		wanted_yaw -= (event as InputEventMouseMotion).relative.x * drag_degrees_per_pixel


func _process(delta: float) -> void:
	wanted_yaw += Input.get_axis("cam_rotate_right", "cam_rotate_left") * turn_speed * delta
	var blend: float = 1.0 - exp(-smoothing * delta)
	yaw = lerpf(yaw, wanted_yaw, blend)
	distance = lerpf(distance, wanted_distance, blend)
	if target != null:
		global_position = global_position.lerp(target.global_position, blend)
	_apply()


func snap() -> void:
	yaw = wanted_yaw
	distance = wanted_distance
	if target != null:
		global_position = target.global_position
	_apply()


func _apply() -> void:
	rotation_degrees.y = yaw
	camera.position.z = distance
	global_position.x = clampf(global_position.x, -bounds, bounds)
	global_position.z = clampf(global_position.z, -bounds, bounds)
