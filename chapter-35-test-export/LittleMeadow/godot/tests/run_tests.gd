extends SceneTree
## Runs every test of res://tests, headless, and needs no add-on and no other tool.
##
## From the project folder:
##   godot --headless --path . --script res://tests/run_tests.gd
## Only some tests (the text must be part of "test_ch28.gd::test_name"):
##   godot --headless --path . --script res://tests/run_tests.gd -- --filter=test_ch28
##
## How it works: it loads each res://tests/test_*.gd (sorted by name), makes one object of it, and calls every
## method that starts with test_, passing one helper `t`. A test may `await t.frames(5)`. The optional methods
## before_all(t), before_each(t) and after_each(t) run around them.
## The last output line reads: LM_TESTS passed=N failed=N errors=N
## "errors" counts the "SCRIPT ERROR" lines of the Godot log (a crash inside a script). The exit code is 0 when
## nothing failed and no script error was logged, and 1 otherwise.

const TESTS_DIR := "res://tests"

var passed := 0
var failed := 0
var script_errors := 0
var filter := ""
var _logger := ErrorCounter.new()


## The helper that every test receives as `t`: assertions, waiting, a little scene help, simulated input.
class TestHelper extends RefCounted:
	var tree: SceneTree
	var fails: Array = []
	var checks := 0

	func _init(scene_tree: SceneTree) -> void:
		tree = scene_tree

	func ok(cond: bool, msg := "") -> bool:
		checks += 1
		if not cond:
			fails.append("ok failed. " + msg)
		return cond

	func eq(a: Variant, b: Variant, msg := "") -> bool:
		checks += 1
		if a != b:
			fails.append("expected %s == %s. %s" % [str(a), str(b), msg])
			return false
		return true

	func ne(a: Variant, b: Variant, msg := "") -> bool:
		checks += 1
		if a == b:
			fails.append("expected %s != %s. %s" % [str(a), str(b), msg])
			return false
		return true

	func approx(a: float, b: float, eps := 0.001, msg := "") -> bool:
		checks += 1
		if absf(a - b) > eps:
			fails.append("expected %f ~ %f (eps %f). %s" % [a, b, eps, msg])
			return false
		return true

	func vec_approx(a: Variant, b: Variant, eps := 0.001, msg := "") -> bool:
		checks += 1
		if not (a - b).length() <= eps:
			fails.append("expected %s ~ %s (eps %f). %s" % [str(a), str(b), eps, msg])
			return false
		return true

	func not_null(v: Variant, msg := "") -> bool:
		checks += 1
		if v == null:
			fails.append("expected non-null. " + msg)
			return false
		return true

	func fail(msg: String) -> void:
		checks += 1
		fails.append(msg)

	func frames(n: int = 1) -> void:
		for i in n:
			await tree.process_frame

	func physics_frames(n: int = 1) -> void:
		for i in n:
			await tree.physics_frame

	func secs(s: float) -> void:
		await tree.create_timer(s).timeout

	func add(node: Node) -> Node:
		tree.root.add_child(node)
		return node

	func load_scene(path: String) -> Node:
		var packed := load(path) as PackedScene
		if packed == null:
			fail("cannot load scene " + path)
			return null
		var node := packed.instantiate()
		tree.root.add_child(node)
		return node

	func autoload(autoload_name: String) -> Node:
		return tree.root.get_node_or_null(autoload_name)

	func press_action(action: String, strength := 1.0) -> void:
		Input.action_press(action, strength)

	func release_action(action: String) -> void:
		Input.action_release(action)

	func tap_action(action: String, hold_frames := 2) -> void:
		var down := InputEventAction.new()
		down.action = action
		down.pressed = true
		down.strength = 1.0
		Input.parse_input_event(down)
		await frames(hold_frames)
		var up := InputEventAction.new()
		up.action = action
		up.pressed = false
		Input.parse_input_event(up)
		await frames(1)

	func key(keycode: Key, pressed := true) -> void:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)

	## Positions are in game screen coordinates, the numbers a script sees in event.position. A headless window
	## is only 64 by 64 pixels, so they are converted to window coordinates here and Godot converts them back.
	func _to_window(pos: Vector2) -> Vector2:
		return tree.root.get_final_transform() * pos

	func screen_size() -> Vector2:
		return tree.root.get_visible_rect().size

	func mouse_move(pos: Vector2) -> void:
		var event := InputEventMouseMotion.new()
		event.position = _to_window(pos)
		event.global_position = event.position
		Input.parse_input_event(event)

	func mouse_button(pos: Vector2, button: MouseButton, pressed: bool) -> void:
		var event := InputEventMouseButton.new()
		event.position = _to_window(pos)
		event.global_position = event.position
		event.button_index = button
		event.pressed = pressed
		event.button_mask = (1 << (button - 1)) if pressed else 0
		Input.parse_input_event(event)

	func click(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
		mouse_move(pos)
		mouse_button(pos, button, true)
		await frames(2)
		mouse_button(pos, button, false)
		await frames(1)


## Counts the script errors of the Godot log (the lines that start with "SCRIPT ERROR").
class ErrorCounter extends Logger:
	var count := 0
	var _mutex := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			_mutex.lock()
			count += 1
			_mutex.unlock()


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.substr(9)
	OS.add_logger(_logger)
	# The headless window is 64 by 64 pixels. Scaling the content gives a stable screen of the size set in the
	# project settings, so mouse positions and the layout of the interface behave as in a normal run.
	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	var height := int(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(width, height)
	await process_frame
	var folder := DirAccess.open(TESTS_DIR)
	if folder == null:
		print("LM_TESTS no tests folder ", TESTS_DIR)
		print("LM_TESTS passed=0 failed=1 errors=0")
		quit(1)
		return
	var files: Array = []
	for file_name in folder.get_files():
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			files.append(file_name)
	files.sort()
	for file_name in files:
		await _run_file(TESTS_DIR.path_join(file_name))
	script_errors = _logger.count
	print("LM_TESTS passed=%d failed=%d errors=%d" % [passed, failed, script_errors])
	quit(0 if failed == 0 and script_errors == 0 else 1)


func _run_file(path: String) -> void:
	var script := load(path) as GDScript
	if script == null:
		print("FAIL %s: cannot load or parse" % path)
		failed += 1
		return
	var suite = script.new()
	if suite is Node:
		root.add_child(suite)
	var t := TestHelper.new(self)
	if suite.has_method("before_all"):
		await suite.call("before_all", t)
	for method in suite.get_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue
		if filter != "" and filter not in (path + "::" + method_name):
			continue
		t.fails = []
		t.checks = 0
		if suite.has_method("before_each"):
			await suite.call("before_each", t)
		var started := Time.get_ticks_msec()
		await suite.call(method_name, t)
		if suite.has_method("after_each"):
			await suite.call("after_each", t)
		var label := "%s::%s" % [path.get_file(), method_name]
		if t.fails.is_empty():
			passed += 1
			print("PASS %s (%d checks, %d ms)" % [label, t.checks, Time.get_ticks_msec() - started])
		else:
			failed += 1
			print("FAIL %s: %s" % [label, " | ".join(t.fails)])
	if suite is Node:
		suite.queue_free()
		await process_frame
