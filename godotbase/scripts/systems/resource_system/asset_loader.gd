class_name AssetLoader extends RefCounted

## AssetLoader
##
## Base class for resource loaders.
## Manages loading state, stores loaded resource, handles HTTP requests.
##
## Subclasses MUST override:
## - _parse_data(): Convert raw bytes to resource
##
## Subclasses MAY override:
## - _do_load(): Custom loading logic (e.g., two-stage loading)
##
## Usage:
## ```
## # Create custom loader
## class_name MyLoader extends AssetLoader
##
## func _parse_data(data: PackedByteArray, headers: PackedStringArray):
##     # Parse and return resource
##     return my_parse(data)
## ```

## Load state enum
enum LoadState {
	PENDING,   ## Not started
	LOADING,   ## In progress
	LOADED,    ## Completed successfully
	ERROR      ## Failed
}

# ===== Signals =====
signal load_completed(resource: Variant)
signal load_failed(error: String)
signal load_progress(progress: float)

# ===== Data =====
var config: ResourceConfig = null  ## Resource configuration
var state: LoadState = LoadState.PENDING
var progress: float = 0.0
var loaded_resource: Variant = null     ## Stored resource (persistent)
var error_message: String = ""

# ===== Cache Busting =====
var _cached_url: String = ""            ## Cached URL with timestamp

# ===== HTTP Request =====
var _http_request: HTTPRequest = null   ## HTTP request node

# ===== Fallback Control =====
var _tried_remote: bool = false         ## Whether remote was attempted

# ===== ResourceSystem Reference =====
var _resource_system: ResourceSystem = null    ## ResourceSystem reference


## Constructor
func _init(res_config: ResourceConfig) -> void:
	config = res_config


## Start loading (requires ResourceSystem reference)
func load(resource_system: ResourceSystem) -> void:
	_resource_system = resource_system
	
	# Already loaded: emit signal immediately
	if state == LoadState.LOADED:
		load_completed.emit(loaded_resource)
		return
	
	# Already loading: skip
	if state == LoadState.LOADING:
		return
	
	state = LoadState.LOADING
	progress = 0.0
	
	# Call subclass implementation
	_do_load(resource_system)


## Override this method for custom loading logic (e.g., two-stage loading)
## Default implementation handles remote/local loading with fallback
func _do_load(resource_system: ResourceSystem) -> void:
	# Remote priority
	if not config.remote_url.is_empty():
		_load_from_remote(resource_system)
	elif not config.local_path.is_empty():
		_load_from_local(resource_system)
	else:
		_on_error("No valid path for resource: " + config.key)


## MUST override: Parse raw bytes into resource
## @param data Raw bytes from HTTP response or file
## @param headers HTTP response headers (empty for local files)
## @return Parsed resource or null on failure
func _parse_data(_data: PackedByteArray, _headers: PackedStringArray) -> Variant:
	_log_error("AssetLoader._parse_data() must be overridden by subclass")
	return null


## Get current load state
func get_state() -> LoadState:
	return state


## Get loading progress (0.0 to 1.0)
func get_progress() -> float:
	return progress


## Get loaded resource (returns null if not loaded)
func get_resource() -> Variant:
	return loaded_resource if state == LoadState.LOADED else null


## Get ResourceSystem reference (for subclasses)
func get_resource_system() -> ResourceSystem:
	return _resource_system


## Get logger from ResourceSystem (for subclasses)
func _get_logger() -> LogSystem:
	if _resource_system:
		return _resource_system.get_system("LogSystem") as LogSystem
	return null


## Log debug message (uses LogSystem if available, fallback to print)
func _log_debug(message: String) -> void:
	var logger: LogSystem = _get_logger()
	if logger:
		logger.debug(message)
	else:
		print("[DEBUG] %s" % message)


## Log info message (uses LogSystem if available, fallback to print)
func _log_info(message: String) -> void:
	var logger: LogSystem = _get_logger()
	if logger:
		logger.info(message)
	else:
		print("[INFO] %s" % message)


## Log warning message (uses LogSystem if available, fallback to push_warning)
func _log_warn(message: String) -> void:
	var logger: LogSystem = _get_logger()
	if logger:
		logger.warn(message)
	else:
		push_warning(message)


## Log error message (uses LogSystem if available, fallback to push_error)
func _log_error(message: String) -> void:
	var logger: LogSystem = _get_logger()
	if logger:
		logger.error(message)
	else:
		push_error(message)


## Cleanup HTTP resources (but keep loaded_resource)
func cleanup_http() -> void:
	if _http_request:
		_http_request.queue_free()
		_http_request = null


## Full cleanup: HTTP + subclass-specific resources (temp files, etc.)
## Called when resource is unloaded or system shuts down.
## Subclasses should override this to add their own cleanup logic.
func cleanup() -> void:
	cleanup_http()


# ===== Protected Methods (for subclasses) =====

## Mark loading as complete with resource
func _on_loaded(resource: Variant) -> void:
	if resource == null:
		_on_error("Loaded resource is null: " + config.key)
		return
	
	loaded_resource = resource
	state = LoadState.LOADED
	progress = 1.0
	load_completed.emit(resource)


## Mark loading as failed with error
func _on_error(error: String) -> void:
	state = LoadState.ERROR
	error_message = error
	_log_error("[AssetLoader] Error: %s" % error)
	load_failed.emit(error)


## Update progress (0.0 to 1.0)
func _update_progress(new_progress: float) -> void:
	progress = new_progress
	load_progress.emit(progress)


# ===== Local Loading =====

func _load_from_local(resource_system: ResourceSystem) -> void:
	var path: String = config.local_path
	
	# 1. Check Godot cache
	if ResourceLoader.has_cached(path):
		var resource: Variant = ResourceLoader.load(path)
		_on_loaded(resource)
		return
	
	# 2. Start async loading
	var err: Error = ResourceLoader.load_threaded_request(path)
	if err != OK:
		_on_error("Failed to start loading: " + path)
		return
	
	# 3. Register for polling by ResourceSystem
	resource_system._register_pending_local_load(config.key, path, self)


## Check local resource load status (called by ResourceSystem._on_process)
## Returns true if loading completed (success or failure)
func check_local_load_status(path: String) -> bool:
	var progress_array: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path, progress_array)
	
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progress_array.size() > 0:
				var prog: float = progress_array[0]
				_update_progress(prog)
			return false
		
		ResourceLoader.THREAD_LOAD_LOADED:
			var resource: Variant = ResourceLoader.load_threaded_get(path)
			_on_loaded(resource)
			return true
		
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_on_error("Local load failed: " + path)
			return true
	
	return false


# ===== Remote Loading =====

func _load_from_remote(resource_system: ResourceSystem) -> void:
	_tried_remote = true
	
	# 1. Generate cache busting URL (only once, unless skip_cache_busting is set)
	if _cached_url.is_empty():
		if config.skip_cache_busting:
			_cached_url = config.remote_url
		else:
			_cached_url = CacheBusting.add_cache_buster(config.remote_url)
	
	# 2. Create HTTPRequest
	_http_request = resource_system.create_http_request()
	if _http_request == null:
		_fallback_to_local(resource_system, "Cannot create HTTPRequest")
		return
	
	# 3. Connect signal
	_http_request.request_completed.connect(_on_http_completed.bind(resource_system))
	
	# 4. Make request
	var err: Error = _http_request.request(_cached_url)
	if err != OK:
		_fallback_to_local(resource_system, "HTTP request failed: " + str(err))


func _on_http_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	resource_system: ResourceSystem
) -> void:
	# 1. Check request result
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var error: String = "HTTP failed: result=%d, code=%d" % [result, response_code]
		_fallback_to_local(resource_system, error)
		return
	
	# 2. Parse resource (subclass implementation)
	var resource: Variant = _parse_data(body, headers)
	if resource == null:
		_fallback_to_local(resource_system, "Failed to parse resource data")
		return
	
	# 3. Success
	_on_loaded(resource)


func _fallback_to_local(resource_system: ResourceSystem, reason: String) -> void:
	if not config.local_path.is_empty():
		_log_warn("[AssetLoader] Remote failed (%s), fallback to local: %s" % [reason, config.key])
		_load_from_local(resource_system)
	else:
		_on_error("Remote failed and no local fallback: " + reason)


# ===== Utility: Content-Type Extraction =====

## Extract Content-Type from HTTP headers
func _get_content_type(headers: PackedStringArray) -> String:
	for header: String in headers:
		var lower: String = header.to_lower()
		if lower.begins_with("content-type:"):
			var parts: PackedStringArray = header.split(":")
			if parts.size() >= 2:
				return parts[1].strip_edges().split(";")[0]
	return ""
