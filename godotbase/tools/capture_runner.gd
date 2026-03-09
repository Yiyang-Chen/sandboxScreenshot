extends SceneTree

## Headless screenshot capture runner (works with --headless and Xvfb).
##
## Usage:
##   godot --headless --path /project -s tools/capture_runner.gd \
##     -- --scene res://scenes/main.tscn --out /path/frame.png --frames 5
##
##   # With Xvfb (for full GL rendering):
##   xvfb-run -a -s "-screen 0 1280x720x24" \
##     godot --path /project --rendering-driver opengl3 \
##     -s tools/capture_runner.gd \
##     -- --scene res://scenes/main.tscn --out /path/frame.png --frames 5

var _out_path: String = ""
var _warmup_frames: int = 5
var _target_scene: String = "res://scenes/main.tscn"
var _width: int = 1280
var _height: int = 720


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		match args[i]:
			"--out":
				if i + 1 < args.size():
					_out_path = args[i + 1]
			"--frames":
				if i + 1 < args.size():
					_warmup_frames = int(args[i + 1])
			"--scene":
				if i + 1 < args.size():
					_target_scene = args[i + 1]
			"--width":
				if i + 1 < args.size():
					_width = int(args[i + 1])
			"--height":
				if i + 1 < args.size():
					_height = int(args[i + 1])

	if _out_path.is_empty():
		push_error("[CaptureRunner] --out path is required")
		quit(1)
		return

	print("[CaptureRunner] scene=%s  out=%s  warmup=%d  size=%dx%d" % [
		_target_scene, _out_path, _warmup_frames, _width, _height
	])


func _process(_delta: float) -> bool:
	var scene_res: PackedScene = load(_target_scene) as PackedScene
	if scene_res == null:
		push_error("[CaptureRunner] Failed to load scene: %s" % _target_scene)
		quit(1)
		return true

	var scene_node: Node = scene_res.instantiate()
	root.add_child(scene_node)

	root.content_scale_size = Vector2i(_width, _height)

	_do_capture.call_deferred()
	return false


func _do_capture() -> void:
	for _i: int in range(_warmup_frames):
		await process_frame

	var img: Image = root.get_texture().get_image()
	if img == null or img.is_empty():
		push_error("[CaptureRunner] Failed to capture viewport image")
		quit(1)
		return

	var err: Error = img.save_png(_out_path)
	if err != OK:
		push_error("[CaptureRunner] Failed to save PNG to %s (error %d)" % [_out_path, err])
		quit(1)
		return

	print("[CaptureRunner] Saved screenshot: %s (%dx%d)" % [_out_path, img.get_width(), img.get_height()])
	quit(0)
