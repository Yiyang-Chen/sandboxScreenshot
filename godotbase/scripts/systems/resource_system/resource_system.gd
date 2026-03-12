class_name ResourceSystem extends System

## ResourceSystem
##
## Core resource loading system that manages game_config.json and resource loading.
##
## Features:
## - Loads and parses game_config.json
## - Manages resource configurations
## - Handles remote and local resource loading
## - Memory caching via persistent AssetLoaders
## - Concurrent loading control
## - Callback-based async loading
## - Custom Loader class registration
##
## Resource type annotations (for generate_resource_types.py):
## Format: @resource NAME:CONFIG_NAME:VALUE
## VALUE must be unique and stable (do not change existing values)
## @resource ATLAS:RESOURCE_TYPE_ATLAS:0
## @resource AUDIO:RESOURCE_TYPE_AUDIO:1
## @resource IMAGE:RESOURCE_TYPE_IMAGE:2
## @resource JSON:RESOURCE_TYPE_JSON:3
## @resource PCK:RESOURCE_TYPE_PCK:4
## @resource SCENE:RESOURCE_TYPE_SCENE:5
## @resource GLB:RESOURCE_TYPE_GLB:6
## @resource VIDEO:RESOURCE_TYPE_VIDEO:7
##
## Usage:
## ```
## # Add ResourceController node to your scene - it auto-calls set_node() in _ready().
## # IMPORTANT: Do not load remote resources before ResourceController._ready() is called.
## var resource_sys = env.get_system("ResourceSystem")
## resource_sys.initialize("res://public/game_config.json")
##
## # Register custom loader for a type
## resource_sys.register_loader(ResourceTypes.Type.ATLAS, AtlasLoader)
##
## # Load single resource
## resource_sys.load_resource("player_texture",
##     func(texture): player.texture = texture,
##     func(error): print("Error: " + error)
## )
##
## # Batch load
## resource_sys.load_resources(["tex1", "tex2", "audio1"],
##     func(results):
##         var succeeded = results["succeeded"]
##         var failed = results["failed"]
## )
## ```

# ===== Configuration =====
var _game_config: Dictionary = {}           ## Raw config
var _resource_configs: Dictionary = {}      ## key -> ResourceConfig

# ===== Resource Container (unique) =====
var _asset_loaders: Dictionary = {}         ## key -> AssetLoader (state + resource)

# ===== Callback Queue (for multiple requests to same resource) =====
var _pending_callbacks: Dictionary = {}     ## key -> Array[{on_complete, on_error}]

# ===== Concurrency Control =====
var max_concurrent_loads: int = 6           ## Maximum concurrent loads
var _active_loads: int = 0                  ## Current active load count
var _loading_queue: Array[Dictionary] = []  ## Wait queue: {key, on_complete, on_error}

# ===== Local Load Status Check =====
var _pending_local_loads: Dictionary = {}   ## key -> {path, loader}

# ===== Loader Class Registry =====
var _loader_classes: Dictionary = {}        ## type: int -> GDScript (class that extends AssetLoader)

# ===== Loading PCK Management (Web only) =====
## loading.pck 加载状态
enum LoadingPckStatus {
	PENDING,    ## 等待中
	LOADING,    ## 加载中
	LOADED,     ## 加载完成
	FAILED      ## 加载失败
}

var _loading_pck_file: String = ""          ## loading.pck filename from JS (e.g., "loading_abc123.pck")
var _loading_pck_status: int = LoadingPckStatus.PENDING
var _web_base_url_cache: String = ""        ## Cached web base URL (avoid repeated JS calls)


# ===== Lifecycle =====
func _on_init() -> void:
	# Register default loaders for basic types
	_register_default_loaders()
	print("[ResourceSystem] Initialized")


func _register_default_loaders() -> void:
	"""Register built-in loaders for basic resource types"""
	register_loader(ResourceTypes.Type.IMAGE, ImageLoader)
	register_loader(ResourceTypes.Type.AUDIO, AudioLoader)
	register_loader(ResourceTypes.Type.JSON, JsonLoader)
	register_loader(ResourceTypes.Type.ATLAS, AtlasLoader)
	register_loader(ResourceTypes.Type.PCK, PckLoader)
	register_loader(ResourceTypes.Type.GLB, GLBLoader)
	register_loader(ResourceTypes.Type.VIDEO, VideoLoader)


func _on_process(_delta: float) -> void:
	"""Check all pending local resource load status"""
	if _pending_local_loads.is_empty():
		return
	
	var completed_keys: Array[String] = []
	
	for key: String in _pending_local_loads:
		var data: Dictionary = _pending_local_loads[key]
		var loader: AssetLoader = data["loader"]
		var path: String = data["path"]
		
		# Check load status
		if loader.check_local_load_status(path):
			completed_keys.append(key)
	
	# Remove completed ones
	for key: String in completed_keys:
		_pending_local_loads.erase(key)


func _on_shutdown() -> void:
	"""Cleanup all resources"""
	# Full cleanup all loaders (HTTP + temp files, etc.)
	for loader: AssetLoader in _asset_loaders.values():
		loader.cleanup()
	
	_asset_loaders.clear()
	_resource_configs.clear()
	_pending_callbacks.clear()
	_loading_queue.clear()
	_pending_local_loads.clear()
	_loader_classes.clear()
	
	# Clear cache busting timestamps to prevent memory leak
	CacheBusting.reset_timestamps()
	
	print("[ResourceSystem] Shutdown complete")


# ===== Node Provider Override =====

## Override set_node to emit ResourceNodeReadyEvent
## This allows other systems (like FontSystem) to know when HTTP is available
## On Web: also registers JS callback for pck_index
func set_node(node: Node) -> void:
	super.set_node(node)
	
	# Emit event via EventSystem
	var event_sys: EventSystem = get_system("EventSystem") as EventSystem
	if event_sys:
		var event: ResourceNodeReadyEvent = ResourceNodeReadyEvent.new()
		event.node = node
		event_sys.trigger(event)
		log_info("[ResourceSystem] Node provider set, event emitted")
	
	# 开始加载 loading.pck
	if OS.has_feature("web"):
		_start_loading_pck()
	else:
		_start_loading_pck_local()


# ===== Initialization =====

## Initialize system with config file
## @param config_path Path to game_config.json
func initialize(config_path: String) -> void:
	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		log_error("[ResourceSystem] Failed to open config: %s" % config_path)
		return
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_text)
	if error != OK:
		log_error("[ResourceSystem] Failed to parse JSON: %s" % json.get_error_message())
		return
	
	if json.data is Dictionary:
		var config_dict: Dictionary = json.data
		_parse_config(config_dict)
	log_info("[ResourceSystem] Loaded %d resources from config" % _resource_configs.size())


# ===== Register Pending Local Load (called by AssetLoader) =====

## Register a local load for status polling
func _register_pending_local_load(key: String, path: String, loader: AssetLoader) -> void:
	_pending_local_loads[key] = {
		"path": path,
		"loader": loader
	}


# ===== Programmatic Resource Registration =====

## Register resource config (does not load immediately)
##
## Uses:
## - Pre-register configs, load later by key
## - Called during game_config.json parsing
##
## @param config ResourceConfig to register
func register_resource(config: ResourceConfig) -> void:
	if _resource_configs.has(config.key):
		log_warn("[ResourceSystem] Resource '%s' already registered, will be replaced" % config.key)
	
	_resource_configs[config.key] = config
	log_debug("[ResourceSystem] Registered: %s (type: %d)" % [config.key, config.type])


# ===== Loader Registration =====

## Register a custom Loader class for a resource type
##
## Loaders are classes that extend AssetLoader.
## They can override _do_load() and _parse_data() for custom behavior.
##
## @param type ResourceTypes.Type enum value
## @param loader_class GDScript class that extends AssetLoader
##
## Example:
## ```
## # In your system initialization
## func _on_init():
##     var resource_sys = get_system("ResourceSystem")
##     resource_sys.register_loader(ResourceTypes.Type.ATLAS, AtlasLoader)
##
## # AtlasLoader.gd
## class_name AtlasLoader extends AssetLoader
##
## func _do_load(resource_system) -> void:
##     # Custom two-stage loading logic
##     # 1. Load metadata
##     # 2. Load sub-resources
##     # 3. Assemble and call _on_loaded()
## ```
func register_loader(type: int, loader_class: GDScript) -> void:
	if loader_class == null:
		log_error("[ResourceSystem] Cannot register null loader for type %d" % type)
		return
	
	_loader_classes[type] = loader_class
	log_debug("[ResourceSystem] Registered loader for type: %d" % type)


## Get registered loader class for a type
func get_loader_class(type: int) -> GDScript:
	return _loader_classes.get(type, null)


## Check if a loader is registered for a type
func has_loader(type: int) -> bool:
	return _loader_classes.has(type)


# ===== Core Loading API =====

## Load registered resource
##
## Behavior:
## - Already loaded → immediately calls on_complete(resource)
## - Loading → joins callback queue, called when done
## - Not loaded → starts loading, calls when done
## - Previous failure → auto retries (failed loaders are removed)
##
## @param key Resource key (must be registered via register_resource)
## @param on_complete Completion callback: func(resource)
## @param on_error Error callback: func(error: String)
func load_resource(
	key: String,
	on_complete: Callable,
	on_error: Callable = Callable()
) -> void:
	# 1. Check if already loaded (directly from AssetLoader)
	if _asset_loaders.has(key):
		var loader: AssetLoader = _asset_loaders[key]
		
		# Already loaded → return immediately
		if loader.state == AssetLoader.LoadState.LOADED:
			if on_complete.is_valid():
				on_complete.call(loader.loaded_resource)
			return
		
		# Currently loading → join callback queue
		if loader.state == AssetLoader.LoadState.LOADING:
			_add_pending_callback(key, on_complete, on_error)
			return
	
	# 2. Check concurrency limit
	if _active_loads >= max_concurrent_loads:
		# Join wait queue
		_loading_queue.append({
			"key": key,
			"on_complete": on_complete,
			"on_error": on_error
		})
		log_debug("[ResourceSystem] Resource '%s' queued (active: %d)" % [key, _active_loads])
		return
	
	# 3. Start loading
	_start_load(key, on_complete, on_error)


## Dynamic resource loading (auto-register)
##
## For loading resources not in game_config.json.
## Automatically calls register_resource() then loads.
##
## @param config ResourceConfig object
## @param on_complete Completion callback: func(resource)
## @param on_error Error callback: func(error: String)
##
## Example:
## ```
## var config = ResourceConfig.new()
## config.key = "custom_font"
## config.type = ResourceTypes.Type.FONT
## config.remote_url = "https://..."
## config.local_path = "res://fonts/..."
##
## resource_system.load_dynamic_resource(config,
##     func(data): handle_loaded(data),
##     func(error): handle_error(error)
## )
## ```
func load_dynamic_resource(
	config: ResourceConfig,
	on_complete: Callable,
	on_error: Callable = Callable()
) -> void:
	# Auto-register
	register_resource(config)
	
	# Then load
	load_resource(config.key, on_complete, on_error)


## Batch load resources
##
## Automatically handles concurrency control.
## Callback includes both succeeded and failed resources.
##
## @param keys Array of resource keys
## @param on_complete Completion callback: func(results: {succeeded: Dict, failed: Dict})
## @param on_progress Progress callback: func(progress: float)
func load_resources(
	keys: Array,
	on_complete: Callable = Callable(),
	on_progress: Callable = Callable()
) -> void:
	var total: int = keys.size()
	if total == 0:
		if on_complete.is_valid():
			on_complete.call({"succeeded": {}, "failed": {}})
		return
	
	var loaded: Array[int] = [0]  # Use array for reference in lambda
	var results_succeeded: Dictionary = {}
	var results_failed: Dictionary = {}
	
	for key: Variant in keys:
		var key_str: String = str(key)
		var complete_callback: Callable = func(resource: Variant) -> void:
			loaded[0] += 1
			results_succeeded[key_str] = resource
			
			# Update progress
			if on_progress.is_valid():
				on_progress.call(float(loaded[0]) / total)
			
			# All complete
			if loaded[0] == total and on_complete.is_valid():
				var result: Dictionary = {"succeeded": results_succeeded, "failed": results_failed}
				on_complete.call(result)
		
		var error_callback: Callable = func(error: String) -> void:
			loaded[0] += 1
			results_failed[key_str] = error
			
			# Update progress
			if on_progress.is_valid():
				on_progress.call(float(loaded[0]) / total)
			
			# All complete
			if loaded[0] == total and on_complete.is_valid():
				var result: Dictionary = {"succeeded": results_succeeded, "failed": results_failed}
				on_complete.call(result)
		
		load_resource(key_str, complete_callback, error_callback)


# ===== Optional API (debug/UI) =====

## Get load state (for debug/loading UI)
##
## Returns: AssetLoader.LoadState enum
## - PENDING = 0
## - LOADING = 1
## - LOADED = 2
## - ERROR = 3
## - Returns -1 if resource doesn't exist
func get_load_state(key: String) -> int:
	var loader: AssetLoader = _asset_loaders.get(key)
	if loader:
		return loader.state
	return -1


## Check if resource config exists
func has_resource(key: String) -> bool:
	return _resource_configs.has(key)


## Get resource config
func get_resource_config(key: String) -> ResourceConfig:
	return _resource_configs.get(key)


## Get all registered resource keys
func get_registered_keys() -> Array:
	return _resource_configs.keys()


## Unload a specific resource from cache
##
## Removes the resource from memory. Next load_resource() call will reload it.
## Does nothing if resource is not loaded or doesn't exist.
##
## @param key Resource key to unload
func unload_resource(key: String) -> void:
	if _asset_loaders.has(key):
		var loader: AssetLoader = _asset_loaders[key]
		loader.cleanup()
		_asset_loaders.erase(key)
		log_debug("[ResourceSystem] Unloaded resource: %s" % key)


## Clear all loaded resources from cache
##
## Removes all resources from memory. Configs are preserved.
## Useful for scene transitions or memory cleanup.
func clear_all_resources() -> void:
	for loader: AssetLoader in _asset_loaders.values():
		loader.cleanup()
	_asset_loaders.clear()
	log_info("[ResourceSystem] Cleared all loaded resources")


# ===== HTTPRequest Management (called by AssetLoader) =====

## Create HTTPRequest node for AssetLoader
##
## Uses get_node() to get injected Node provider
func create_http_request() -> HTTPRequest:
	var node: Node = get_node()
	if node == null:
		log_error("[ResourceSystem] Cannot create HTTPRequest: no node provider")
		return null
	
	var http: HTTPRequest = HTTPRequest.new()
	node.add_child(http)
	return http


# ===== Private Methods =====

func _start_load(key: String, on_complete: Callable, on_error: Callable) -> void:
	"""Actually start loading (no concurrency check)"""
	# Get config
	var config: ResourceConfig = _resource_configs.get(key)
	if not config:
		if on_error.is_valid():
			on_error.call("Resource config not found: " + key)
		return
	
	# Create loader (must have registered loader class for the type)
	var loader: AssetLoader
	var loader_class: GDScript = _loader_classes.get(config.type)
	if loader_class != null:
		loader = loader_class.new(config)
	else:
		# No loader registered for this type
		var error_msg: String = "No loader registered for resource type %d (key: %s)" % [config.type, key]
		log_error("[ResourceSystem] %s" % error_msg)
		if on_error.is_valid():
			on_error.call(error_msg)
		return
	
	_asset_loaders[key] = loader  # Persistent storage
	
	# Initialize callback queue (including current callback)
	_pending_callbacks[key] = [{
		"on_complete": on_complete,
		"on_error": on_error
	}]
	
	# Connect signals (internal communication)
	loader.load_completed.connect(func(resource: Variant) -> void:
		_on_load_completed(key, resource)
	)
	
	loader.load_failed.connect(func(error: String) -> void:
		_on_load_failed(key, error)
	)
	
	# Increment active count
	_active_loads += 1
	
	# Start loading
	loader.load(self)


func _add_pending_callback(key: String, on_complete: Callable, on_error: Callable) -> void:
	"""Add callback to queue"""
	if not _pending_callbacks.has(key):
		_pending_callbacks[key] = []
	var callbacks: Array = _pending_callbacks[key]
	callbacks.append({
		"on_complete": on_complete,
		"on_error": on_error
	})
	log_debug("[ResourceSystem] Callback queued for '%s' (already loading)" % key)


func _on_load_completed(key: String, resource: Variant) -> void:
	"""Load completed callback"""
	# Resource already stored in loader.loaded_resource
	
	# Call all waiting callbacks
	if _pending_callbacks.has(key):
		for callback_data: Dictionary in _pending_callbacks[key]:
			var cb: Callable = callback_data["on_complete"]
			if cb.is_valid():
				cb.call(resource)
		_pending_callbacks.erase(key)
	
	# Only cleanup HTTP, not AssetLoader (persistent)
	var loader: AssetLoader = _asset_loaders.get(key)
	if loader:
		loader.cleanup_http()
	
	# Decrease active count, process queue
	_active_loads -= 1
	_process_loading_queue()


func _on_load_failed(key: String, error: String) -> void:
	"""Load failed callback"""
	# Call all waiting callbacks
	if _pending_callbacks.has(key):
		for callback_data: Dictionary in _pending_callbacks[key]:
			var cb: Callable = callback_data["on_error"]
			if cb.is_valid():
				cb.call(error)
		_pending_callbacks.erase(key)
	
	# Full cleanup failed loader (HTTP + temp files, etc.)
	var loader: AssetLoader = _asset_loaders.get(key)
	if loader:
		loader.cleanup()
	_asset_loaders.erase(key)  # Failed loaders not kept
	
	# Decrease active count, process queue
	_active_loads -= 1
	_process_loading_queue()


func _process_loading_queue() -> void:
	"""Process waiting queue"""
	while _active_loads < max_concurrent_loads and not _loading_queue.is_empty():
		var item: Dictionary = _loading_queue.pop_front()
		var key: String = item["key"]
		var on_complete: Callable = item["on_complete"]
		var on_error: Callable = item["on_error"]
		load_resource(key, on_complete, on_error)


func _parse_config(config: Dictionary) -> void:
	_game_config = config
	
	# Parse assets
	var assets: Array = config.get("assets", [])
	for asset: Variant in assets:
		if not asset is Dictionary:
			continue
		var asset_dict: Dictionary = asset
		var asset_id: Variant = asset_dict.get("id", 0)
		var resources: Array = asset_dict.get("resources", [])
		for resource: Variant in resources:
			if not resource is Dictionary:
				continue
			var resource_dict: Dictionary = resource
			var res_config: ResourceConfig = ResourceConfig.new()
			res_config.id = asset_id
			
			# Remote resource
			if resource_dict.has("remote"):
				var remote: Dictionary = resource_dict["remote"]
				res_config.key = remote.get("key", "")
				var remote_type: String = remote.get("resource_type", "")
				res_config.type = ResourceTypes.from_config_name(remote_type)
				res_config.remote_url = remote.get("url", "")
			
			# Local resource
			if resource_dict.has("local"):
				var local: Dictionary = resource_dict["local"]
				if res_config.key.is_empty():
					res_config.key = local.get("key", "")
				if local.has("resource_type"):
					var local_type: String = local.get("resource_type", "")
					res_config.type = ResourceTypes.from_config_name(local_type)
				res_config.local_path = "res://public/" + local.get("public_path", "")
			
			# Validate and register
			if res_config.key.is_empty():
				log_warn("[ResourceSystem] Skipping resource with empty key in asset %s" % str(asset_id))
				continue
			if not res_config.is_valid():
				log_warn("[ResourceSystem] Skipping invalid resource '%s' (no path)" % res_config.key)
				continue
			register_resource(res_config)
	
	# Parse scenes
	var scenes: Array = config.get("scenes", [])
	for scene: Variant in scenes:
		if not scene is Dictionary:
			continue
		var scene_dict: Dictionary = scene
		var scene_key: String = scene_dict.get("key", "")
		var resources: Array = scene_dict.get("resources", [])
		for resource: Variant in resources:
			if not resource is Dictionary:
				continue
			var resource_dict: Dictionary = resource
			var res_config: ResourceConfig = ResourceConfig.new()
			res_config.id = scene_dict.get("key", 0)
			
			if resource_dict.has("local"):
				var local: Dictionary = resource_dict["local"]
				res_config.key = local.get("key", "")
				var local_type: String = local.get("resource_type", "")
				res_config.type = ResourceTypes.from_config_name(local_type)
				res_config.local_path = "res://public/" + local.get("public_path", "")
			
			# Validate and register
			if res_config.key.is_empty():
				log_warn("[ResourceSystem] Skipping resource with empty key in scene '%s'" % scene_key)
				continue
			if not res_config.is_valid():
				log_warn("[ResourceSystem] Skipping invalid resource '%s' (no path)" % res_config.key)
				continue
			register_resource(res_config)


# ========================================
# Loading PCK Management
# ========================================

## 非 Web 平台：从本地 dist/loading_pck.json 读取文件名并加载 PCK。
## 如果 loading_pck.json 不存在或无文件名，视为无需加载，直接标记完成。
## NOTE: 其他平台（移动端等）可能需要不同的加载方式，届时在此扩展。
func _start_loading_pck_local() -> void:
	_loading_pck_status = LoadingPckStatus.LOADING

	var index_path: String = "res://dist/loading_pck.json"
	var file: FileAccess = FileAccess.open(index_path, FileAccess.READ)
	if file == null:
		log_info("[ResourceSystem] dist/loading_pck.json not found, skipping loading.pck")
		_loading_pck_status = LoadingPckStatus.LOADED
		_emit_loading_pck_loaded()
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(json_text) != OK:
		log_warn("[ResourceSystem] Failed to parse loading_pck.json")
		_loading_pck_status = LoadingPckStatus.LOADED
		_emit_loading_pck_loaded()
		return

	var data: Dictionary = json.data if json.data is Dictionary else {}
	var pck_file: String = data.get("file", "")

	if pck_file.is_empty():
		log_info("[ResourceSystem] No loading.pck file in loading_pck.json, skipping")
		_loading_pck_status = LoadingPckStatus.LOADED
		_emit_loading_pck_loaded()
		return

	_loading_pck_file = pck_file
	log_info("[ResourceSystem] Loading local PCK: %s" % pck_file)

	var config: ResourceConfig = ResourceConfig.new()
	config.key = "loading_pck"
	config.type = ResourceTypes.Type.PCK
	config.skip_cache_busting = true
	config.local_path = "res://dist/" + pck_file

	load_dynamic_resource(config, _on_loading_pck_loaded, _on_loading_pck_failed)


## Web 平台：从 JS 获取文件名并通过 HTTP 加载 PCK
func _start_loading_pck() -> void:
	_loading_pck_status = LoadingPckStatus.LOADING
	
	# 从 JS 获取 loading.pck 文件名
	# HTML 已经预热了 loading.pck 到浏览器缓存，这里只需获取文件名
	var loading_file: Variant = JavaScriptBridge.eval("window.loadingPckFile || ''")
	
	if loading_file == null:
		log_info("[ResourceSystem] window.loadingPckFile not available")
		_loading_pck_status = LoadingPckStatus.LOADED
		_emit_loading_pck_loaded()
		return
	
	_loading_pck_file = str(loading_file)
	
	if _loading_pck_file.is_empty():
		log_info("[ResourceSystem] No loading.pck defined, skipping")
		_loading_pck_status = LoadingPckStatus.LOADED
		_emit_loading_pck_loaded()
		return
	
	log_info("[ResourceSystem] loading.pck file: %s" % _loading_pck_file)
	
	# 加载 loading.pck（浏览器缓存命中）
	var config: ResourceConfig = ResourceConfig.new()
	config.key = "loading_pck"
	config.type = ResourceTypes.Type.PCK
	config.skip_cache_busting = true  # 文件名已带 hash
	config.remote_url = _get_web_base_url() + _loading_pck_file
	
	log_info("[ResourceSystem] Loading PCK from cache: %s" % config.remote_url)
	load_dynamic_resource(config, _on_loading_pck_loaded, _on_loading_pck_failed)


## loading.pck 加载成功回调
func _on_loading_pck_loaded(_result: Variant) -> void:
	log_info("[ResourceSystem] loading.pck loaded successfully")
	_loading_pck_status = LoadingPckStatus.LOADED
	_emit_loading_pck_loaded()


## loading.pck 加载失败回调
func _on_loading_pck_failed(error: String) -> void:
	log_error("[ResourceSystem] Failed to load loading.pck: %s" % str(error))
	_loading_pck_status = LoadingPckStatus.FAILED
	_emit_loading_pck_loaded()


## 触发 LoadingPckLoadedEvent
func _emit_loading_pck_loaded() -> void:
	var event_sys: EventSystem = get_system("EventSystem") as EventSystem
	if event_sys:
		var event: LoadingPckLoadedEvent = LoadingPckLoadedEvent.new()
		event.success = (_loading_pck_status == LoadingPckStatus.LOADED)
		event_sys.trigger(event)
		log_info("[ResourceSystem] LoadingPckLoadedEvent triggered (success=%s)" % str(event.success))


## 检查 loading.pck 是否加载完成
func is_loading_pck_loaded() -> bool:
	return _loading_pck_status == LoadingPckStatus.LOADED


## 获取 loading.pck 加载状态
func get_loading_pck_status() -> int:
	return _loading_pck_status


## 获取 Web 平台的 base URL
func _get_web_base_url() -> String:
	# Return cached value if available
	if not _web_base_url_cache.is_empty():
		return _web_base_url_cache
	
	var js_code: String = """
		(function() {
			var url = window.location.href;
			var lastSlash = url.lastIndexOf('/');
			return url.substring(0, lastSlash + 1);
		})()
	"""
	var result: Variant = JavaScriptBridge.eval(js_code)
	if result == null:
		log_error("[ResourceSystem] Failed to get web base URL")
		return ""
	
	_web_base_url_cache = str(result)
	return _web_base_url_cache
