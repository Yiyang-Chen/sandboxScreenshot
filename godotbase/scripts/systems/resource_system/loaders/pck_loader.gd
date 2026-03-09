class_name PckLoader extends AssetLoader

## PckLoader
##
## Loader for PCK resource packs.
## Supports dynamic downloading and loading of .pck files.
##
## Main use cases:
## - Font packs (fonts_<hash>.pck)
## - Audio packs
## - Texture packs
##
## Platform behavior:
## - Desktop: Directly load from res:// using load_resource_pack()
## - Web: Download via HTTP → write to user://pck/ → load_resource_pack()

## PCK cache directory (Web platform)
const PCK_CACHE_DIR: String = "user://pck/"

## Track loaded PCKs (static, shared across instances)
## Key: config.key (not file path, for consistency across local/remote)
static var _loaded_pcks: Dictionary = {}  # config.key -> result


func _init(res_config: ResourceConfig) -> void:
	super._init(res_config)


## Override: Custom loading logic
## - Desktop: Prefer local_path (no HTTP needed)
## - Web: Use remote_url
func _do_load(resource_system: ResourceSystem) -> void:
	# Desktop platform: prefer local loading
	if not OS.has_feature("web") and not config.local_path.is_empty():
		_load_from_local(resource_system)
	elif not config.remote_url.is_empty():
		_load_from_remote(resource_system)
	elif not config.local_path.is_empty():
		_load_from_local(resource_system)
	else:
		_on_error("No valid path for PCK: " + config.key)


## Override: Local loading (directly call load_resource_pack)
func _load_from_local(_resource_system: ResourceSystem) -> void:
	var pck_path: String = config.local_path
	var key: String = config.key
	
	# Check if already loaded (by key, not path)
	if _loaded_pcks.has(key):
		_log_info("[PckLoader] Already loaded: %s" % key)
		_on_loaded(_loaded_pcks[key])
		return
	
	# Direct load
	var success: bool = ProjectSettings.load_resource_pack(pck_path)
	if not success:
		_on_error("Failed to load local PCK: %s" % pck_path)
		return
	
	var result: Dictionary = {
		"key": key,
		"loaded": true,
		"pck_path": pck_path,
		"size": 0  # Local load doesn't know size
	}
	
	_loaded_pcks[key] = result
	_log_info("[PckLoader] Local PCK loaded: %s" % pck_path)
	_on_loaded(result)


## Parse PCK data (Web platform: called after HTTP download)
func _parse_data(data: PackedByteArray, _headers: PackedStringArray) -> Variant:
	var key: String = config.key
	
	if data.is_empty():
		return null
	
	# 1. Check if already loaded (by key)
	if _loaded_pcks.has(key):
		_log_info("[PckLoader] Already loaded: %s" % key)
		return _loaded_pcks[key]
	
	# 2. Ensure cache directory exists
	DirAccess.make_dir_recursive_absolute(PCK_CACHE_DIR)
	
	# 3. Write to cache file
	var pck_path: String = PCK_CACHE_DIR + key + ".pck"
	
	var file: FileAccess = FileAccess.open(pck_path, FileAccess.WRITE)
	if file == null:
		_log_error("[PckLoader] Cannot write to: %s" % pck_path)
		return null
	
	file.store_buffer(data)
	file.close()
	
	_log_info("[PckLoader] Written PCK to: %s (%d bytes)" % [pck_path, data.size()])
	
	# 4. Load PCK into virtual file system
	var success: bool = ProjectSettings.load_resource_pack(pck_path)
	if not success:
		_log_error("[PckLoader] Failed to load resource pack: %s" % pck_path)
		return null
	
	# 5. Record and return result
	var result: Dictionary = {
		"key": key,
		"loaded": true,
		"pck_path": pck_path,
		"size": data.size()
	}
	
	_loaded_pcks[key] = result
	_log_info("[PckLoader] Resource pack loaded successfully: %s" % key)
	return result
