class_name SceneSystem extends System

## SceneSystem
##
## 场景管理系统，支持：
## - 异步加载场景（先加载完再显示）
## - Single 模式：加载完成后回调中卸载所有其他场景
## - Additive 模式：只加载，不自动卸载
## - 场景参数传递
##
## 不使用 Godot 的 change_scene API，而是自己管理节点的添加/删除。
##
## 重要：新场景默认被添加到场景树最底层（index 0），会被已有场景遮挡。
## 调用者需要自己管理层级（如隐藏当前场景、或调用 move_child 调整顺序）。
##
## Usage:
## ```
## var scene_sys = EnvironmentRuntime.get_system("SceneSystem")
##
## # Single 模式（默认）：加载完成后自动卸载其他场景
## scene_sys.load_scene("res://scenes/game.tscn", {
##     "level": 1
## }, func():
##     print("Game scene loaded, others unloaded")
## )
##
## # Additive 模式：只加载，不自动卸载
## # 注意：新场景在底层，需要在回调中隐藏当前场景或调整层级
## scene_sys.load_scene("res://scenes/loading.tscn", {}, func():
##     self.visible = false  # 隐藏当前场景，让新场景可见
## , SceneSystem.LoadMode.ADDITIVE)
##
## # 手动卸载
## scene_sys.unload_scene("res://scenes/hud.tscn")
##
## # 获取场景参数
## var data = scene_sys.get_scene_data("res://scenes/game.tscn")
## ```


## 场景加载模式
enum LoadMode {
	SINGLE,    ## 加载完成后卸载所有其他场景
	ADDITIVE   ## 只加载，不自动卸载。新场景在底层，需自己管理层级
}


## 活跃场景信息
class SceneInfo extends RefCounted:
	var path: String = ""
	var instance: Node = null
	var data: Dictionary = {}


## 活跃场景列表（path -> SceneInfo）
var _active_scenes: Dictionary = {}

## 正在加载的场景（path -> {mode, data, on_complete}）
var _loading_scenes: Dictionary = {}


func _on_init() -> void:
	log_debug("[SceneSystem] Initialized")


func _on_shutdown() -> void:
	# 卸载所有场景
	for path: String in _active_scenes.keys():
		_remove_scene_node(path)
	_active_scenes.clear()
	_loading_scenes.clear()
	log_debug("[SceneSystem] Shutdown")


func _on_process(_delta: float) -> void:
	# 检查所有正在加载的场景状态
	if _loading_scenes.is_empty():
		return
	
	# 收集已完成的场景（不能在遍历中修改字典）
	var completed_paths: Array[Dictionary] = []
	
	for scene_path: String in _loading_scenes.keys():
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(scene_path)
		
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				# 还在加载，继续等待
				pass
			
			ResourceLoader.THREAD_LOAD_LOADED:
				# 加载完成
				completed_paths.append({"path": scene_path, "success": true})
			
			ResourceLoader.THREAD_LOAD_FAILED:
				# 加载失败
				log_error("[SceneSystem] Failed to load scene: %s" % scene_path)
				completed_paths.append({"path": scene_path, "success": false})
			
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				# 无效资源
				log_error("[SceneSystem] Invalid scene resource: %s" % scene_path)
				completed_paths.append({"path": scene_path, "success": false})
	
	# 处理已完成的加载
	for item: Dictionary in completed_paths:
		var path: String = item["path"]
		var success: bool = item["success"]
		if success:
			_on_scene_loaded(path)
		else:
			_on_scene_load_failed(path)


# ========================================
# 公开 API
# ========================================

## 加载场景
##
## 新场景默认被添加到场景树最底层，会被已有场景遮挡。
## ADDITIVE 模式下，调用者需在 on_complete 回调中管理层级（如隐藏当前场景）。
##
## @param scene_path 场景路径（res://...）
## @param data 传递给场景的参数
## @param on_complete 加载完成回调
## @param mode 加载模式（SINGLE 或 ADDITIVE）
func load_scene(
	scene_path: String,
	data: Dictionary = {},
	on_complete: Callable = Callable(),
	mode: int = LoadMode.SINGLE
) -> void:
	# 检查是否已经在加载
	if _loading_scenes.has(scene_path):
		log_warn("[SceneSystem] Scene already loading: %s" % scene_path)
		return
	
	# 检查是否已经加载
	if _active_scenes.has(scene_path):
		log_warn("[SceneSystem] Scene already active: %s" % scene_path)
		if on_complete.is_valid():
			on_complete.call()
		return
	
	log_debug("[SceneSystem] Loading scene: %s (mode: %s)" % [scene_path, "SINGLE" if mode == LoadMode.SINGLE else "ADDITIVE"])
	
	# 记录加载状态
	_loading_scenes[scene_path] = {
		"mode": mode,
		"data": data,
		"on_complete": on_complete
	}
	
	# 开始异步加载，_on_process 会检查加载状态
	ResourceLoader.load_threaded_request(scene_path)


## 卸载场景
##
## @param scene_path 场景路径
## @param on_complete 卸载完成回调（异步调用，与 load_scene 行为一致）
func unload_scene(scene_path: String, on_complete: Callable = Callable()) -> void:
	if not _active_scenes.has(scene_path):
		log_warn("[SceneSystem] Scene not active: %s" % scene_path)
		if on_complete.is_valid():
			on_complete.call_deferred()
		return
	
	log_debug("[SceneSystem] Unloading scene: %s" % scene_path)
	
	_remove_scene_node(scene_path)
	_active_scenes.erase(scene_path)
	
	if on_complete.is_valid():
		on_complete.call_deferred()


## 卸载所有场景（除了指定的场景）
##
## @param except_path 保留的场景路径（可选）
func unload_all_scenes(except_path: String = "") -> void:
	var paths_to_unload: Array[String] = []
	
	for path: String in _active_scenes.keys():
		if path != except_path:
			paths_to_unload.append(path)
	
	for path: String in paths_to_unload:
		unload_scene(path)


## 获取场景参数
##
## @param scene_path 场景路径
## @returns 场景参数字典
func get_scene_data(scene_path: String) -> Dictionary:
	if _active_scenes.has(scene_path):
		var info: SceneInfo = _active_scenes[scene_path]
		return info.data
	return {}


## 检查场景是否活跃
##
## @param scene_path 场景路径
## @returns 是否活跃
func is_scene_active(scene_path: String) -> bool:
	return _active_scenes.has(scene_path)


## 获取所有活跃场景路径
##
## @returns 场景路径数组
func get_active_scene_paths() -> Array:
	return _active_scenes.keys()


## 获取场景实例
##
## @param scene_path 场景路径
## @returns 场景节点实例
func get_scene_instance(scene_path: String) -> Node:
	if _active_scenes.has(scene_path):
		var info: SceneInfo = _active_scenes[scene_path]
		return info.instance
	return null


# ========================================
# 内部方法
# ========================================

## 场景加载失败处理（只记录错误，不调用回调）
func _on_scene_load_failed(scene_path: String) -> void:
	if not _loading_scenes.has(scene_path):
		return
	
	_loading_scenes.erase(scene_path)
	# 失败时只 log_error，不调用 on_complete


## 场景加载完成处理
func _on_scene_loaded(scene_path: String) -> void:
	var load_info: Dictionary = _loading_scenes[scene_path]
	_loading_scenes.erase(scene_path)
	
	# 获取加载的资源
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if packed_scene == null:
		log_error("[SceneSystem] Failed to get loaded scene: %s" % scene_path)
		return
	
	# 实例化场景
	var instance: Node = packed_scene.instantiate()
	if instance == null:
		log_error("[SceneSystem] Failed to instantiate scene: %s" % scene_path)
		return
	
	# 添加到场景树
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		log_error("[SceneSystem] Failed to get SceneTree")
		instance.queue_free()
		return
	
	# 记录活跃场景（必须在 add_child 之前，_ready() 中需要 get_scene_data）
	var info: SceneInfo = SceneInfo.new()
	info.path = scene_path
	info.instance = instance
	info.data = load_info["data"]
	_active_scenes[scene_path] = info
	
	# 添加到场景树最底层（index 0），新场景被已有场景遮挡
	# 调用者需要在 on_complete 回调中自己管理层级（如隐藏当前场景）
	# SINGLE 模式：后续 unload_all_scenes 移除其他场景，新场景自然可见
	# ADDITIVE 模式：调用者需隐藏当前场景或调用 move_child 调整层级
	tree.root.add_child(instance)
	tree.root.move_child(instance, 0)
	
	log_debug("[SceneSystem] Scene loaded and added: %s" % scene_path)
	
	# Single 模式：卸载所有其他场景
	if load_info["mode"] == LoadMode.SINGLE:
		unload_all_scenes(scene_path)
	
	# 调用完成回调
	var on_complete: Callable = load_info["on_complete"]
	if on_complete.is_valid():
		on_complete.call()


## 移除场景节点
func _remove_scene_node(scene_path: String) -> void:
	if not _active_scenes.has(scene_path):
		return
	
	var info: SceneInfo = _active_scenes[scene_path]
	if info.instance != null and is_instance_valid(info.instance):
		info.instance.queue_free()
	
	log_debug("[SceneSystem] Scene removed: %s" % scene_path)
