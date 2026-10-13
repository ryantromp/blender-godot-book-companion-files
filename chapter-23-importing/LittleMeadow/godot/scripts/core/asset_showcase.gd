extends Node3D
## Chapter 23 test aid: every imported asset, grouped in bays along the X axis.
## Left and Right move the camera from bay to bay. Home goes back to the overview.

const LOOPING_CLIP_SUFFIXES: PackedStringArray = ["_idle", "_spin", "_drive"]

var bays: Array[Node3D] = []
var current_bay: int = -1

@onready var camera: Camera3D = $Camera3D
@onready var overview: Transform3D = camera.global_transform


func _ready() -> void:
	for node in get_tree().get_nodes_in_group("bay"):
		bays.append(node)
	_play_looping_clips()
	print("AssetShowcase ready: %d bays" % bays.size())


func _play_looping_clips() -> void:
	for player: AnimationPlayer in find_children("*", "AnimationPlayer", true, false):
		for clip in player.get_animation_list():
			for suffix in LOOPING_CLIP_SUFFIXES:
				if clip.ends_with(suffix):
					player.play(clip)


func focus_bay(index: int) -> void:
	current_bay = index
	var bay: Node3D = bays[index]
	var box := AABB(bay.get_node("Label").global_position, Vector3.ZERO)
	for item: Node3D in bay.get_children():
		box = box.expand(item.global_position)
	var span: float = maxf(box.size.x, box.size.z) + 5.0
	var center: Vector3 = box.get_center()
	camera.global_position = center + Vector3(0.0, span * 0.45, span * 0.8)
	camera.look_at(center + Vector3(0.0, 0.5, 0.0))


func show_overview() -> void:
	current_bay = -1
	camera.global_transform = overview


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		focus_bay((current_bay + 1) % bays.size())
	elif event.is_action_pressed("ui_left"):
		focus_bay((current_bay - 1 + bays.size()) % bays.size())
	elif event.is_action_pressed("ui_home"):
		show_overview()
