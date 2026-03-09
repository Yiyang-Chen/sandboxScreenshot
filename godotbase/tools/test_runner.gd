class_name TestRunner
extends SceneTree

## Base class for agent-authored automated test scripts.
##
## Subclass this and override _run_test() to write your test logic.
## Use take_screenshot(), wait_frames(), load_test_scene() inside _run_test().
##
## Usage:
##   # In your test script (e.g. tests/test_my_scene.gd):
##   extends TestRunner
##
##   func _run_test() -> void:
##       var scene := await load_test_scene("res://scenes/main.tscn")
##       await wait_frames(10)
##       take_screenshot("initial")
##       finish()
##
##   # Run via shell:
##   ./run_test.sh tests/test_my_scene.gd

var _screenshot_dir: String = ""
var _viewport_width: int = 1280
var _viewport_height: int = 720
var _screenshot_count: int = 0
var _started: bool = false


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


## Capture the current viewport and save it as a PNG.
## The file is saved to {screenshot_dir}/{label}.png.
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


## Call this when your test is done.
func finish(exit_code: int = 0) -> void:
	print("[TestRunner] Test finished (%d screenshots taken)" % _screenshot_count)
	quit(exit_code)
