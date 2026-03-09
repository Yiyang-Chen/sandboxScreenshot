class_name AtlasLoader extends AssetLoader

## AtlasLoader
##
## Loader for ATLAS resources (sprite atlas with animations).
##
## URL format:
##   Base: {base_url}?asset_type=ASSET_TYPE_ATLAS&asset_id={id}
##   Appends &key=RESOURCE_TYPE_IMAGE, &key=RESOURCE_TYPE_ATLAS_JSON, etc.
##
## Loads 3 sub-resources in parallel:
##   - IMAGE: The sprite sheet image
##   - ATLAS_JSON: TexturePacker format frame definitions
##   - ANIMATION_JSON: Animation name to frame mapping
##
## Assembles into SpriteFrames for use with AnimatedSprite2D.
##
## Returns: SpriteFrames ready to use


# Sub-resource keys
const SUB_RESOURCE_KEYS: Dictionary = {
	"image": "RESOURCE_TYPE_IMAGE",
	"atlas_json": "RESOURCE_TYPE_ATLAS_JSON",
	"animation_json": "RESOURCE_TYPE_ANIMATION_JSON"
}


func _do_load(resource_system: ResourceSystem) -> void:
	if config.remote_url.is_empty():
		_on_error("AtlasLoader requires remote_url")
		return
	
	_load_sub_resources(resource_system)


func _load_sub_resources(resource_system: ResourceSystem) -> void:
	var sub_keys: Array[String] = []
	var base_key: String = config.key
	var base_url: String = config.remote_url
	
	# Ensure base URL has proper separator for appending key parameter
	var separator: String = "&" if "?" in base_url else "?"
	
	# Register IMAGE sub-resource
	var img_config: ResourceConfig = ResourceConfig.new()
	img_config.key = base_key + "_image"
	img_config.type = ResourceTypes.Type.IMAGE
	img_config.remote_url = base_url + separator + "key=" + SUB_RESOURCE_KEYS["image"]
	resource_system.register_resource(img_config)
	sub_keys.append(img_config.key)
	
	# Register ATLAS_JSON sub-resource
	var atlas_config: ResourceConfig = ResourceConfig.new()
	atlas_config.key = base_key + "_atlas_json"
	atlas_config.type = ResourceTypes.Type.JSON
	atlas_config.remote_url = base_url + separator + "key=" + SUB_RESOURCE_KEYS["atlas_json"]
	resource_system.register_resource(atlas_config)
	sub_keys.append(atlas_config.key)
	
	# Register ANIMATION_JSON sub-resource
	var anim_config: ResourceConfig = ResourceConfig.new()
	anim_config.key = base_key + "_animation_json"
	anim_config.type = ResourceTypes.Type.JSON
	anim_config.remote_url = base_url + separator + "key=" + SUB_RESOURCE_KEYS["animation_json"]
	resource_system.register_resource(anim_config)
	sub_keys.append(anim_config.key)
	
	# Load all sub-resources in parallel
	resource_system.load_resources(sub_keys, _on_sub_resources_loaded.bind(base_key))


func _on_sub_resources_loaded(results: Dictionary, base_key: String) -> void:
	var succeeded: Dictionary = results["succeeded"]
	var failed: Dictionary = results["failed"]
	
	# Check for failures
	if not failed.is_empty():
		var failed_keys: Array = failed.keys()
		_on_error("Failed to load sub-resources: %s" % str(failed_keys))
		return
	
	# Get loaded resources
	var image: ImageTexture = succeeded.get(base_key + "_image")
	var atlas_json: Dictionary = succeeded.get(base_key + "_atlas_json", {})
	var animation_json: Dictionary = succeeded.get(base_key + "_animation_json", {})
	
	if image == null:
		_on_error("Missing image for atlas")
		return
	
	# Assemble SpriteFrames
	var sprite_frames: SpriteFrames = _assemble_sprite_frames(image, atlas_json, animation_json)
	if sprite_frames == null:
		_on_error("Failed to assemble SpriteFrames")
		return
	
	_on_loaded(sprite_frames)


## Assemble SpriteFrames from loaded resources
func _assemble_sprite_frames(
	image: ImageTexture,
	atlas_json: Dictionary,
	animation_json: Dictionary
) -> SpriteFrames:
	# Build frame lookup: filename -> frame rect
	var frame_lookup: Dictionary = _build_frame_lookup(atlas_json)
	if frame_lookup.is_empty():
		_log_error("[AtlasLoader] No frames found in atlas_json")
		return null
	
	var sprite_frames: SpriteFrames = SpriteFrames.new()
	
	# Remove default animation if exists
	if sprite_frames.has_animation("default"):
		sprite_frames.remove_animation("default")
	
	# Get animations from animation_json
	var animations: Array = animation_json.get("animations", [])
	if animations.is_empty():
		# Fallback: create one animation with all frames
		sprite_frames.add_animation("default")
		for frame_name: String in frame_lookup:
			var region: Rect2 = frame_lookup[frame_name]
			var atlas_texture: AtlasTexture = _create_atlas_texture(image, region)
			sprite_frames.add_frame("default", atlas_texture)
	else:
		# Create animations from animation_json
		for anim: Variant in animations:
			if not anim is Dictionary:
				continue
			var anim_dict: Dictionary = anim
			var anim_name: String = anim_dict.get("name", "unnamed")
			var frame_names: Array = anim_dict.get("frames", [])
			
			sprite_frames.add_animation(anim_name)
			sprite_frames.set_animation_loop(anim_name, true)
			sprite_frames.set_animation_speed(anim_name, 10.0)  # Default FPS
			
			for frame_name: Variant in frame_names:
				var frame_name_str: String = str(frame_name)
				if frame_lookup.has(frame_name_str):
					var region: Rect2 = frame_lookup[frame_name_str]
					var atlas_texture: AtlasTexture = _create_atlas_texture(image, region)
					sprite_frames.add_frame(anim_name, atlas_texture)
				else:
					_log_warn("[AtlasLoader] Frame not found: %s" % frame_name_str)
	
	return sprite_frames


## Build lookup dictionary: frame filename -> Rect2 region
func _build_frame_lookup(atlas_json: Dictionary) -> Dictionary:
	var lookup: Dictionary = {}
	
	# TexturePacker format
	var textures: Array = atlas_json.get("textures", [])
	for texture: Variant in textures:
		if not texture is Dictionary:
			continue
		var texture_dict: Dictionary = texture
		var frames: Array = texture_dict.get("frames", [])
		for frame: Variant in frames:
			if not frame is Dictionary:
				continue
			var frame_dict: Dictionary = frame
			var filename: String = frame_dict.get("filename", "")
			if filename.is_empty():
				continue
			
			var rect_data: Dictionary = frame_dict.get("frame", {})
			var x: float = _to_float(rect_data.get("x", 0))
			var y: float = _to_float(rect_data.get("y", 0))
			var w: float = _to_float(rect_data.get("w", 0))
			var h: float = _to_float(rect_data.get("h", 0))
			var rect: Rect2 = Rect2(x, y, w, h)
			lookup[filename] = rect
	
	return lookup


## Create AtlasTexture from base image and region
func _create_atlas_texture(base_image: ImageTexture, region: Rect2) -> AtlasTexture:
	var atlas_texture: AtlasTexture = AtlasTexture.new()
	atlas_texture.atlas = base_image
	atlas_texture.region = region
	return atlas_texture


## Helper to convert Variant to float
func _to_float(value: Variant) -> float:
	if value is float:
		@warning_ignore("unsafe_cast")
		return value as float
	if value is int:
		@warning_ignore("unsafe_cast")
		var int_val: int = value as int
		return float(int_val)
	return 0.0


## Not used for AtlasLoader (we override _do_load)
func _parse_data(_data: PackedByteArray, _headers: PackedStringArray) -> Variant:
	return null
