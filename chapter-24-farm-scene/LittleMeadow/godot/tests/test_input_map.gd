extends Node
## Chapter 21: the project has exactly the input actions that spec/GODOT_ARCH.md lists.

const ACTIONS: PackedStringArray = [
	"click_move", "build_place", "build_cancel", "build_rotate", "build_toggle",
	"cam_rotate_left", "cam_rotate_right", "cam_rotate_drag", "cam_zoom_in", "cam_zoom_out",
	"tool_1", "tool_2", "tool_3", "tool_4", "tool_5", "tool_6", "tool_next", "tool_prev",
	"inventory_toggle", "pause",
]
const KEYS: Dictionary = {
	"build_rotate": KEY_R, "build_toggle": KEY_B, "cam_rotate_left": KEY_Q, "cam_rotate_right": KEY_E,
	"tool_1": KEY_1, "tool_2": KEY_2, "tool_3": KEY_3, "tool_4": KEY_4, "tool_5": KEY_5, "tool_6": KEY_6,
	"inventory_toggle": KEY_I, "pause": KEY_ESCAPE,
}
const BUTTONS: Dictionary = {
	"click_move": MOUSE_BUTTON_LEFT, "build_place": MOUSE_BUTTON_LEFT, "build_cancel": MOUSE_BUTTON_RIGHT,
	"cam_rotate_drag": MOUSE_BUTTON_MIDDLE, "cam_zoom_in": MOUSE_BUTTON_WHEEL_UP,
	"cam_zoom_out": MOUSE_BUTTON_WHEEL_DOWN, "tool_next": MOUSE_BUTTON_WHEEL_DOWN, "tool_prev": MOUSE_BUTTON_WHEEL_UP,
}


func _key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _button_event(button: MouseButton, shift: bool = false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.shift_pressed = shift
	return event


func test_all_actions_exist(t: Variant) -> void:
	for action: String in ACTIONS:
		t.ok(InputMap.has_action(action), "action %s exists" % action)
	t.eq(ACTIONS.size(), 20, "twenty actions")


func test_keys_match_the_table(t: Variant) -> void:
	for action: String in KEYS:
		t.ok(_key_event(KEYS[action]).is_action(action), "%s answers its key" % action)


func test_mouse_buttons_match_the_table(t: Variant) -> void:
	for action: String in BUTTONS:
		var shift: bool = action == "tool_next" or action == "tool_prev"
		t.ok(_button_event(BUTTONS[action], shift).is_action(action), "%s answers its button" % action)


func test_shift_wheel_is_not_a_zoom(t: Variant) -> void:
	var shifted := _button_event(MOUSE_BUTTON_WHEEL_UP, true)
	t.ok(shifted.is_action("cam_zoom_in"), "a plain match ignores the extra Shift key")
	t.ok(not shifted.is_action("cam_zoom_in", true), "an exact match does not")
	t.ok(shifted.is_action("tool_prev", true), "Shift+wheel up is tool_prev")
	t.ok(not _button_event(MOUSE_BUTTON_WHEEL_UP).is_action("tool_prev"), "plain wheel up is not tool_prev")


func test_layer_names(t: Variant) -> void:
	t.eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_1"), "ground", "layer 1")
	t.eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_2"), "interactable", "layer 2")
	t.eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_3"), "actor", "layer 3")
	t.eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_4"), "obstacle", "layer 4")


func test_window_and_main_scene(t: Variant) -> void:
	t.eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280, "width")
	t.eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 720, "height")
	var main_setting: String = ProjectSettings.get_setting("application/run/main_scene")
	t.eq(ResourceUID.ensure_path(main_setting), "res://scenes/world/farm.tscn", "main scene (stored as a uid), the farm since Chapter 24")
	var main: Node = t.load_scene("res://scenes/main.tscn")
	t.not_null(main, "main.tscn loads")
	for child: String in ["TestCube", "Camera3D", "DirectionalLight3D", "Ground"]:
		t.ok(main.get_node_or_null(child) != null, "Main has %s" % child)
	main.queue_free()
