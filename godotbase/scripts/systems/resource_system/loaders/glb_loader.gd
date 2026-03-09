class_name GLBLoader extends AssetLoader

## GLBLoader
##
## Loader for GLB/GLTF 3D model resources.
## Downloads GLB file from remote URL and parses it into a PackedScene.
##
## Returns: PackedScene containing the 3D model hierarchy
##
## Usage:
## ```
## resource_sys.load_resource("model_key",
##     func(packed_scene):
##         var instance = packed_scene.instantiate()
##         add_child(instance)
##         
##         # For animated models
##         var anim_player = instance.find_child("AnimationPlayer", true, false)
##         if anim_player:
##             anim_player.play("idle")
## )
## ```


func _parse_data(data: PackedByteArray, _headers: PackedStringArray) -> Variant:
	# GLTFDocument requires a file path, so we write to a temp file
	# Use ticks_usec + random to avoid filename collision in parallel loads
	var temp_path: String = OS.get_user_data_dir() + "/temp_glb_" + str(Time.get_ticks_usec()) + "_" + str(randi()) + ".glb"
	
	# Write GLB data to temp file
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		_log_error("[GLBLoader] Failed to create temp file: %s" % temp_path)
		return null
	
	file.store_buffer(data)
	file.close()
	
	# Parse GLB using Godot's GLTF importer
	var gltf: GLTFDocument = GLTFDocument.new()
	var gltf_state: GLTFState = GLTFState.new()
	var error: Error = gltf.append_from_file(temp_path, gltf_state)
	
	# Cleanup temp file immediately after parsing (no longer needed)
	_cleanup_temp_file(temp_path)
	
	if error != OK:
		_log_error("[GLBLoader] Failed to parse GLB: error=%d" % error)
		return null
	
	# Generate scene from GLTF state
	var scene: Node = gltf.generate_scene(gltf_state)
	if scene == null:
		_log_error("[GLBLoader] Failed to generate scene from GLB")
		return null
	
	# Pack into PackedScene for easy instantiation and caching
	var packed_scene: PackedScene = PackedScene.new()
	var pack_error: Error = packed_scene.pack(scene)
	
	# Free the temporary scene node immediately (not in scene tree, so use free() not queue_free())
	scene.free()
	
	if pack_error != OK:
		_log_error("[GLBLoader] Failed to pack scene: error=%d" % pack_error)
		return null
	
	return packed_scene


## Cleanup temporary file safely
func _cleanup_temp_file(path: String) -> void:
	if FileAccess.file_exists(path):
		var err: Error = DirAccess.remove_absolute(path)
		if err != OK:
			_log_warn("[GLBLoader] Failed to cleanup temp file: %s, error=%d" % [path, err])
