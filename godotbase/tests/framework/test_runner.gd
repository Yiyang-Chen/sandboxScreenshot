class_name TestRunner
extends SceneTree

## Base class for agent-authored automated test scripts.
##
## Subclass this and override _run_test() to write your test logic.
## Use take_screenshot(), wait_frames(), wait_for_event(), load_test_scene(), test_log() inside _run_test().
##
## Usage:
##   # In your test script (e.g. tests/test_my_scene.gd):
##   extends TestRunner
##
##   func _run_test() -> void:
##       var scene: Node = load_test_scene("res://scenes/main.tscn")
##       await wait_frames(10)
##       await take_screenshot("initial")
##       finish()
##
##   # Run via shell:
##   bash tests/framework/run_test.sh test_my_scene.gd

var _screenshot_dir: String = ""
var _viewport_width: int = 1280
var _viewport_height: int = 720
var _screenshot_count: int = 0
var _started: bool = false
var _log_file: FileAccess = null


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		match args[i]:
			"--screenshot-dir":
				if i + 1 < args.size():
					_screenshot_dir = args[i + 1]
			"--width":
				if i + 1 < args.size():
					_viewport_width = int(args[i + 1])
			"--height":
				if i + 1 < args.size():
					_viewport_height = int(args[i + 1])

	if _screenshot_dir.is_empty():
		push_error("[TestRunner] --screenshot-dir is required")
		quit(1)
		return

	if not DirAccess.dir_exists_absolute(_screenshot_dir):
		var err: Error = DirAccess.make_dir_recursive_absolute(_screenshot_dir)
		if err != OK:
			push_error("[TestRunner] Failed to create screenshot dir: %s (error %d)" % [_screenshot_dir, err])
			quit(1)
			return

	var log_path: String = _screenshot_dir.path_join("test.log")
	_log_file = FileAccess.open(log_path, FileAccess.WRITE)
	if _log_file == null:
		push_warning("[TestRunner] Could not create test.log at %s" % log_path)

	print("[TestRunner] screenshot_dir=%s  size=%dx%d" % [_screenshot_dir, _viewport_width, _viewport_height])


func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	root.content_scale_size = Vector2i(_viewport_width, _viewport_height)
	_run_test.call_deferred()
	return false


## Override this method in your test script with your test logic.
func _run_test() -> void:
	push_warning("[TestRunner] _run_test() not overridden — nothing to do")
	quit(0)


## Load a scene and add it to the root viewport. Returns the instantiated node.
func load_test_scene(scene_path: String) -> Node:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("[TestRunner] Failed to load scene: %s" % scene_path)
		quit(1)
		return null

	var node: Node = packed.instantiate()
	root.add_child(node)
	print("[TestRunner] Loaded scene: %s" % scene_path)
	return node


## Wait for a number of rendered frames.
func wait_frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame


## Wait for a game event (via EventSystem) instead of guessing frame counts.
## Returns the event instance, or null if timed out.
## Requires EnvironmentRuntime autoload to be active (always true when a scene is loaded).
##
## Example:
##   var event: GameEvent = await wait_for_event(LoadingPckLoadedEvent)
##   if event != null:
##       test_log("PCK loaded, success=%s" % str(event.success))
func wait_for_event(event_type: Script, timeout_frames: int = 600) -> GameEvent:
	var env_runtime: Node = root.get_node_or_null("EnvironmentRuntime")
	if env_runtime == null:
		push_warning("[TestRunner] EnvironmentRuntime not available — cannot wait for event")
		return null

	if not env_runtime.has_method("get_system"):
		push_warning("[TestRunner] EnvironmentRuntime has no get_system() method")
		return null

	@warning_ignore("unsafe_method_access")
	var system: System = env_runtime.get_system("EventSystem")
	if not system is EventSystem:
		push_warning("[TestRunner] EventSystem not available — cannot wait for event")
		return null

	@warning_ignore("unsafe_cast")
	var event_system: EventSystem = system as EventSystem

	var result: Array = []
	var handler: Callable = func(e: GameEvent) -> void: result.append(e)
	event_system.once(event_type, handler)

	for _i: int in range(timeout_frames):
		if result.size() > 0:
			return result[0]
		await process_frame

	event_system.unregister(event_type, handler)
	push_warning("[TestRunner] wait_for_event timed out after %d frames" % timeout_frames)
	return null


## Capture the current viewport and save it as a PNG.
## The file is saved to {screenshot_dir}/{label}.png.
## This is a coroutine — callers must use: await take_screenshot("label")
func take_screenshot(label: String) -> void:
	_screenshot_count += 1
	var filename: String = "%s.png" % label
	var full_path: String = _screenshot_dir.path_join(filename)

	await process_frame

	var img: Image = root.get_texture().get_image()
	if img == null or img.is_empty():
		push_error("[TestRunner] Failed to capture viewport for '%s'" % label)
		return

	var err: Error = img.save_png(full_path)
	if err != OK:
		push_error("[TestRunner] Failed to save screenshot to %s (error %d)" % [full_path, err])
		return

	print("[TestRunner] Screenshot saved: %s (%dx%d)" % [full_path, img.get_width(), img.get_height()])


## Write a message to both the terminal and the test.log file.
func test_log(message: String) -> void:
	var line: String = "[Test] %s" % message
	print(line)
	if _log_file != null:
		_log_file.store_line(line)
		_log_file.flush()


## Call this when your test is done.
func finish(exit_code: int = 0) -> void:
	print("[TestRunner] Test finished (%d screenshots taken)" % _screenshot_count)
	if _log_file != null:
		_log_file.close()
		_log_file = null
	quit(exit_code)
