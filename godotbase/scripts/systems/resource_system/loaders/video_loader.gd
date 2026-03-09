class_name VideoLoader extends AssetLoader

## VideoLoader
##
## Loader for video resources (OGV/Theora).
## Godot 4's VideoStreamTheora only supports loading from file path,
## so remote downloads are written to a temp file in user://video_cache/ first.
##
## Returns: VideoStreamTheora

## Video cache directory
const VIDEO_CACHE_DIR: String = "user://video_cache/"

## Path to the temp file written for this resource (empty if none)
var _temp_file_path: String = ""


func _init(res_config: ResourceConfig) -> void:
	super._init(res_config)


## Parse downloaded OGV data: write to temp file, return VideoStreamTheora
func _parse_data(data: PackedByteArray, _headers: PackedStringArray) -> Variant:
	if data.is_empty():
		_log_error("[VideoLoader] Empty data for: %s" % config.key)
		return null

	# 1. Ensure cache directory exists
	DirAccess.make_dir_recursive_absolute(VIDEO_CACHE_DIR)

	# 2. Write to temp file
	var file_path: String = VIDEO_CACHE_DIR + config.key + ".ogv"
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		_log_error("[VideoLoader] Cannot write to: %s (error: %s)" % [file_path, str(FileAccess.get_open_error())])
		return null

	file.store_buffer(data)
	file.close()
	_temp_file_path = file_path

	_log_info("[VideoLoader] Written OGV to: %s (%d bytes)" % [file_path, data.size()])

	# 3. Create VideoStreamTheora with file path
	var stream: VideoStreamTheora = VideoStreamTheora.new()
	stream.file = file_path
	return stream


## Override: Full cleanup — delete temp file + HTTP cleanup
func cleanup() -> void:
	if not _temp_file_path.is_empty() and FileAccess.file_exists(_temp_file_path):
		DirAccess.remove_absolute(_temp_file_path)
		_log_info("[VideoLoader] Deleted temp file: %s" % _temp_file_path)
		_temp_file_path = ""
	super.cleanup()
