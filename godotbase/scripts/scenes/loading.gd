extends Node

## Loading Scene
##
## 加载场景，样式与 Phaser 版本一致：
## - 黑色背景
## - Loading 文字动画（上方）
## - 小人动画跟随进度条移动
## - 进度条（NinePatch 样式）
## - 百分比文字
## - Logo（底部）
##
## 支持两种模式：
## - global: 首次启动时加载全局资源（fonts.pck 等）
## - level: 关卡切换时加载关卡资源
##
## Structure:
## - UILayer (Control): All loading UI elements
## - GameLayer (Node): Reserved for future use


const MODE_GLOBAL: String = "global"
const MODE_LEVEL: String = "level"


## 当前加载模式
var _mode: String = MODE_GLOBAL

## 目标场景路径
var _target_scene: String = "res://scenes/main.tscn"

## 预加载资源 key 列表（来自 scene data）
var _preload_keys: Array = []

## 系统引用
var _log: LogSystem = null
var _resource_system: ResourceSystem = null
var _event_system: EventSystem = null
var _scene_system: SceneSystem = null
var _font_system: FontSystem = null

## UI 节点引用
@onready var _background: ColorRect = $UILayer/Background
@onready var _loading_text: TextureRect = $UILayer/LoadingText
@onready var _move_character: TextureRect = $UILayer/MoveCharacter
@onready var _logo: TextureRect = $UILayer/Logo
@onready var _progress_bar_outside: NinePatchRect = $UILayer/ProgressBarOutside
@onready var _progress_bar_inside: NinePatchRect = $UILayer/ProgressBarInside
@onready var _progress_text: Label = $UILayer/ProgressText
@onready var _status_label: Label = $UILayer/StatusLabel
@onready var _iris_mask: ColorRect = $UILayer/IrisMask

## 是否已完成 UI 设置
var _ui_ready: bool = false

## 进度条参数（基于 Phaser 版本）
var _bar_width: float = 400.0  # 进度条宽度
var _bar_start_x: float = 0.0  # 进度条起始 X
var _inside_padding: float = 13.0  # 边框厚度
var _max_inside_width: float = 0.0  # 内部最大宽度

## Sprite Sheet 动画参数
var _loading_text_spritesheet: Texture2D = null
var _loading_text_frame: int = 0
var _loading_text_frame_count: int = 48
var _loading_text_frame_size: Vector2 = Vector2(1920, 400)
var _loading_text_cols: int = 6
var _loading_text_frames: Array[AtlasTexture] = []

var _move_spritesheet: Texture2D = null
var _move_frame: int = 0
var _move_frame_count: int = 96
var _move_frame_size: Vector2 = Vector2(80, 60)
var _move_cols: int = 12
var _move_frames: Array[AtlasTexture] = []

var _loading_text_timer: float = 0.0
var _loading_text_fps: float = 12.5

var _move_timer: float = 0.0
var _move_fps: float = 25.0

## 圆形遮罩过渡
var _mask_center: Vector2 = Vector2.ZERO
var _mask_radius: float = 0.0
var _mask_max_radius: float = 0.0
var _is_transitioning: bool = false
var _mask_shader_applied: bool = false


func _ready() -> void:
	_log = EnvironmentRuntime.get_system("LogSystem") as LogSystem
	_resource_system = EnvironmentRuntime.get_system("ResourceSystem") as ResourceSystem
	_event_system = EnvironmentRuntime.get_system("EventSystem") as EventSystem
	_scene_system = EnvironmentRuntime.get_system("SceneSystem") as SceneSystem
	_font_system = EnvironmentRuntime.get_system("FontSystem") as FontSystem
	
	var data: Dictionary = _scene_system.get_scene_data(scene_file_path)
	_mode = data.get("loading_mode", MODE_GLOBAL)
	_target_scene = data.get("target_scene", "res://scenes/main.tscn")
	_preload_keys = data.get("preload", [])
	
	_log.info("[Loading] Mode: %s, Target: %s, Preload: %d keys" % [_mode, _target_scene, _preload_keys.size()])
	
	_hide_all_ui()
	
	if _resource_system.is_loading_pck_loaded():
		_on_loading_pck_ready()
	else:
		_event_system.register(LoadingPckLoadedEvent, _on_loading_pck_loaded_event)


func _exit_tree() -> void:
	if _event_system:
		_event_system.unregister(LoadingPckLoadedEvent, _on_loading_pck_loaded_event)
		_event_system.unregister(FontLoadedEvent, _on_font_loaded_event)
		_event_system.unregister(FontLoadFailedEvent, _on_font_load_failed_event)


func _process(delta: float) -> void:
	if not _ui_ready:
		return
	
	# Loading text 动画
	if not _loading_text_frames.is_empty():
		_loading_text_timer += delta
		var text_frame_duration: float = 1.0 / _loading_text_fps
		if _loading_text_timer >= text_frame_duration:
			_loading_text_timer -= text_frame_duration
			_loading_text_frame = (_loading_text_frame + 1) % _loading_text_frame_count
			_loading_text.texture = _loading_text_frames[_loading_text_frame]
	
	# Move character 动画
	if not _move_frames.is_empty():
		_move_timer += delta
		var move_frame_duration: float = 1.0 / _move_fps
		if _move_timer >= move_frame_duration:
			_move_timer -= move_frame_duration
			_move_frame = (_move_frame + 1) % _move_frame_count
			_move_character.texture = _move_frames[_move_frame]


func _generate_spritesheet_frames(spritesheet: Texture2D, frame_count: int, frame_size: Vector2, cols: int) -> Array[AtlasTexture]:
	var frames: Array[AtlasTexture] = []
	for i: int in range(frame_count):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = spritesheet
		var col: int = i % cols
		var row: int = i / cols
		atlas.region = Rect2(float(col) * frame_size.x, float(row) * frame_size.y, frame_size.x, frame_size.y)
		frames.append(atlas)
	return frames


func _hide_all_ui() -> void:
	_loading_text.visible = false
	_move_character.visible = false
	_logo.visible = false
	_progress_bar_outside.visible = false
	_progress_bar_inside.visible = false
	_progress_text.visible = false
	_status_label.visible = false


func _on_loading_pck_loaded_event(event: LoadingPckLoadedEvent) -> void:
	_event_system.unregister(LoadingPckLoadedEvent, _on_loading_pck_loaded_event)
	
	if not event.success:
		_log.error("[Loading] loading.pck failed to load")
		return
	
	_on_loading_pck_ready()


func _on_loading_pck_ready() -> void:
	_log.info("[Loading] loading.pck ready")
	
	_calculate_layout()
	_setup_ui()
	
	var web_bridge: WebBridgeSystem = EnvironmentRuntime.get_system("WebBridgeSystem") as WebBridgeSystem
	if web_bridge:
		web_bridge.close_html_overlay()
	
	_start_loading()


func _calculate_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center_x: float = viewport_size.x / 2
	var center_y: float = viewport_size.y / 2
	
	_bar_width = clamp(viewport_size.x * 0.5, 320.0, 800.0)
	_bar_start_x = center_x - _bar_width / 2
	_max_inside_width = _bar_width - _inside_padding * 2
	
	_progress_bar_outside.position = Vector2(_bar_start_x, center_y - 29)
	_progress_bar_outside.size = Vector2(_bar_width, 58)
	
	_progress_bar_inside.position = Vector2(_bar_start_x + _inside_padding, center_y - 16)
	_progress_bar_inside.size = Vector2(32, 32)
	
	var loading_text_width: float = min(_bar_width * 1.05, 800)
	_loading_text.position = Vector2(center_x - loading_text_width / 2, center_y - 200)
	_loading_text.size = Vector2(loading_text_width, 100)
	
	_move_character.size = Vector2(50, 50)
	_move_character.position = Vector2(_bar_start_x + _inside_padding - _move_character.size.x / 2, center_y - 80)
	
	_progress_text.position = Vector2(center_x - 100, center_y + 40)
	_progress_text.size = Vector2(200, 50)
	
	var logo_width: float = min(_bar_width * 0.3, 160)
	_logo.position = Vector2(center_x - logo_width / 2, viewport_size.y - 150)
	_logo.size = Vector2(logo_width, 100)


func _setup_ui() -> void:
	var logo_tex: ImageTexture = _load_image("res://loading/combo_logo.png")
	var outside_tex: ImageTexture = _load_image("res://loading/progressbar_outside.png")
	var inside_tex: ImageTexture = _load_image("res://loading/progressbar_inside.png")
	
	_loading_text_spritesheet = _load_image("res://loading/loading_text_spritesheet.webp")
	_move_spritesheet = _load_image("res://loading/move_animated_spritesheet.webp")
	
	if logo_tex:
		_logo.texture = logo_tex
		_logo.visible = true
		_logo.modulate.a = 0.8
	
	if outside_tex:
		_progress_bar_outside.texture = outside_tex
		_progress_bar_outside.visible = true
	
	if inside_tex:
		_progress_bar_inside.texture = inside_tex
		_progress_bar_inside.visible = true
	
	if _loading_text_spritesheet:
		_loading_text_frames = _generate_spritesheet_frames(_loading_text_spritesheet, _loading_text_frame_count, _loading_text_frame_size, _loading_text_cols)
		if not _loading_text_frames.is_empty():
			_loading_text.texture = _loading_text_frames[0]
			_loading_text.visible = true
	
	if _move_spritesheet:
		_move_frames = _generate_spritesheet_frames(_move_spritesheet, _move_frame_count, _move_frame_size, _move_cols)
		if not _move_frames.is_empty():
			_move_character.texture = _move_frames[0]
			_move_character.visible = true
	
	var font: FontFile = _load_font("res://loading/PressStart2P-Regular.ttf")
	if font:
		_progress_text.add_theme_font_override("font", font)
	
	_progress_text.visible = true
	_progress_text.text = "0%"
	
	_ui_ready = true


func _load_image(image_path: String) -> ImageTexture:
	var file: FileAccess = FileAccess.open(image_path, FileAccess.READ)
	if file == null:
		_log.warn("[Loading] Image not found: %s" % image_path)
		return null
	
	var data: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	
	var image: Image = Image.new()
	var err: Error
	
	if image_path.ends_with(".webp"):
		err = image.load_webp_from_buffer(data)
	elif image_path.ends_with(".png"):
		err = image.load_png_from_buffer(data)
	elif image_path.ends_with(".jpg") or image_path.ends_with(".jpeg"):
		err = image.load_jpg_from_buffer(data)
	else:
		_log.warn("[Loading] Unsupported image format: %s" % image_path)
		return null
	
	if err != OK:
		_log.warn("[Loading] Failed to load image: %s (error: %d)" % [image_path, err])
		return null
	
	return ImageTexture.create_from_image(image)


func _load_font(font_path: String) -> FontFile:
	var file: FileAccess = FileAccess.open(font_path, FileAccess.READ)
	if file == null:
		_log.warn("[Loading] Font not found: %s" % font_path)
		return null
	
	var data: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	
	var font_file: FontFile = FontFile.new()
	font_file.data = data
	return font_file


func _start_loading() -> void:
	match _mode:
		MODE_GLOBAL:
			_load_global_resources()
		MODE_LEVEL:
			_load_level_resources()


## 预加载资源的通用方法
##
## 批量加载资源，不管成功失败都推进进度条，失败时 log 错误但不阻塞。
##
## @param keys 要加载的资源 key 列表（对应 game_config.json 中的 key）
## @param on_complete 全部完成后的回调，接收 results: Dictionary（包含 succeeded 和 failed）
## @param progress_start 进度条起始值 (0.0 ~ 1.0)
## @param progress_end 进度条结束值 (0.0 ~ 1.0)
func _preload_resources(keys: Array, on_complete: Callable, progress_start: float = 0.0, progress_end: float = 1.0) -> void:
	if keys.is_empty():
		_update_progress(progress_end)
		if on_complete.is_valid():
			on_complete.call({"succeeded": {}, "failed": {}})
		return
	
	var on_load_complete: Callable = func(results: Dictionary) -> void:
		# 失败的资源只 log 错误，不阻塞流程
		var failed: Dictionary = results["failed"]
		for key: String in failed.keys():
			_log.error("[Loading] Preload failed: %s - %s" % [key, failed[key]])
		if on_complete.is_valid():
			on_complete.call(results)
	
	var on_load_progress: Callable = func(progress: float) -> void:
		_update_progress(progress_start + progress * (progress_end - progress_start))
	
	_resource_system.load_resources(keys, on_load_complete, on_load_progress)


func _load_global_resources() -> void:
	_update_progress(0.1)
	
	if _font_system.is_pck_loaded():
		_on_fonts_loaded()
	else:
		_event_system.register(FontLoadedEvent, _on_font_loaded_event)
		_event_system.register(FontLoadFailedEvent, _on_font_load_failed_event)


func _on_font_loaded_event(_event: FontLoadedEvent) -> void:
	if _font_system.is_pck_loaded():
		_event_system.unregister(FontLoadedEvent, _on_font_loaded_event)
		_event_system.unregister(FontLoadFailedEvent, _on_font_load_failed_event)
		_on_fonts_loaded()


func _on_font_load_failed_event(_event: FontLoadFailedEvent) -> void:
	_log.warn("[Loading] Font load failed, continuing anyway")
	_event_system.unregister(FontLoadedEvent, _on_font_loaded_event)
	_event_system.unregister(FontLoadFailedEvent, _on_font_load_failed_event)
	_on_fonts_loaded()


func _on_fonts_loaded() -> void:
	_log.info("[Loading] Fonts loaded")
	
	# 加载 preload 列表中的资源
	if _preload_keys.is_empty():
		_update_progress(0.95)
		_on_loading_complete()
	else:
		# fonts 占 0.1 ~ 0.3，preload 资源占 0.3 ~ 0.95
		_preload_resources(_preload_keys, func(_results: Dictionary) -> void: _on_loading_complete(), 0.3, 0.95)


func _load_level_resources() -> void:
	if _preload_keys.is_empty():
		_update_progress(0.95)
		_on_loading_complete()
	else:
		# level 模式：preload 资源占 0.1 ~ 0.95
		_preload_resources(_preload_keys, func(_results: Dictionary) -> void: _on_loading_complete(), 0.1, 0.95)


func _update_progress(progress: float) -> void:
	if not _ui_ready:
		return
	
	progress = clamp(progress, 0.0, 1.0)
	
	var new_width: float = max(32, _max_inside_width * progress)
	_progress_bar_inside.size.x = new_width
	
	var move_x: float = _bar_start_x + _inside_padding + (_max_inside_width * progress) - _move_character.size.x / 2
	_move_character.position.x = move_x
	
	_progress_text.text = "%d%%" % int(progress * 100)


func _on_loading_complete() -> void:
	_log.info("[Loading] Complete")
	
	if _target_scene.is_empty():
		_log.info("[Loading] No target scene, staying")
		return
	
	_log.info("[Loading] Loading target: %s" % _target_scene)
	_scene_system.load_scene(_target_scene, {}, _on_target_scene_loaded, SceneSystem.LoadMode.ADDITIVE)


func _on_target_scene_loaded() -> void:
	_log.info("[Loading] Target loaded, starting transition")
	_update_progress(1.0)
	_start_circle_mask_transition()


## 圆形遮罩过渡效果（iris-out）
func _start_circle_mask_transition() -> void:
	if _is_transitioning or not _ui_ready:
		return
	_is_transitioning = true
	
	if _mask_max_radius == 0.0:
		_mask_center = _move_character.position + _move_character.size / 2
		
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var corners: Array[Vector2] = [
			Vector2(0, 0),
			Vector2(viewport_size.x, 0),
			Vector2(0, viewport_size.y),
			viewport_size
		]
		for corner: Vector2 in corners:
			var dist: float = _mask_center.distance_to(corner)
			_mask_max_radius = max(_mask_max_radius, dist)
		_mask_max_radius += 50.0
	
	_mask_radius = _mask_max_radius
	_apply_mask_shader()
	
	var character_radius: float = 60.0
	var tween: Tween = create_tween()
	tween.tween_method(_update_mask_radius, _mask_max_radius, character_radius, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(0.15)
	tween.tween_method(_update_mask_radius, character_radius, 0.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(_on_transition_complete)


func _on_transition_complete() -> void:
	_log.info("[Loading] Transition complete")
	
	var web_bridge: WebBridgeSystem = EnvironmentRuntime.get_system("WebBridgeSystem") as WebBridgeSystem
	if web_bridge:
		web_bridge.send_message_to_parent("loadingComplete")
	
	_scene_system.unload_scene(scene_file_path)


func _apply_mask_shader() -> void:
	if not _mask_shader_applied:
		_mask_shader_applied = true
		
		var shader: Shader = Shader.new()
		shader.code = """
shader_type canvas_item;

uniform vec2 center;
uniform float radius;
uniform vec2 screen_size;

void fragment() {
	vec2 pixel_pos = UV * screen_size;
	float dist = distance(pixel_pos, center);
	if (dist < radius) {
		COLOR.a = 0.0;
	}
}
"""
		
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = shader
		_iris_mask.material = material
	
	_iris_mask.visible = true
	if _iris_mask.material:
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var mat: ShaderMaterial = _iris_mask.material as ShaderMaterial
		mat.set_shader_parameter("center", _mask_center)
		mat.set_shader_parameter("radius", _mask_radius)
		mat.set_shader_parameter("screen_size", viewport_size)


func _update_mask_radius(radius: float) -> void:
	_mask_radius = radius
	if _iris_mask and _iris_mask.material:
		var mat: ShaderMaterial = _iris_mask.material as ShaderMaterial
		mat.set_shader_parameter("radius", radius)
