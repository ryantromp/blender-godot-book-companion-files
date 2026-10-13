class_name FarmerAnimation
extends AnimationTree
## Drives the farmer's AnimationTree. The state machine reads `speed` from the Farmer by itself,
## so this script only sets the pace of the feet and starts the action clips.

const WALK_CLIP_SPEED: float = 1.0 # metres a second that char_farmer_walk covers without foot slide
const RUN_CLIP_SPEED: float = 2.64 # the same for char_farmer_run (Chapter 17 measured it)

@onready var farmer: Farmer = get_parent() as Farmer


func _physics_process(_delta: float) -> void:
	var clip_speed: float = RUN_CLIP_SPEED if farmer.speed > farmer.run_threshold else WALK_CLIP_SPEED
	set("parameters/Pace/scale", farmer.speed / clip_speed if farmer.speed > 0.1 else 1.0)


func current_state() -> StringName:
	var playback: AnimationNodeStateMachinePlayback = get("parameters/Locomotion/playback")
	return playback.get_current_node()


func play_action(action: StringName) -> void:
	set("parameters/ActionPick/transition_request", action)
	set("parameters/Action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func is_acting() -> bool:
	return get("parameters/Action/active")
