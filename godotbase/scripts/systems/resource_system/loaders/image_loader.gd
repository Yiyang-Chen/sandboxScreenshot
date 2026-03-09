class_name ImageLoader extends AssetLoader

## ImageLoader
##
## Loader for image resources (PNG, JPEG, WebP).
## Uses magic bytes (file header) to detect actual format first.
## This avoids error logs when server returns wrong Content-Type.


func _parse_data(data: PackedByteArray, headers: PackedStringArray) -> Variant:
	if data.size() < 4:
		return null
	
	# 1. Detect format from magic bytes (most reliable, avoids error logs)
	var format: String = _detect_format_from_magic_bytes(data)
	if not format.is_empty():
		var resource: ImageTexture = _parse_by_format(format, data)
		if resource != null:
			return resource
	
	# 2. Fallback: try Content-Type
	var content_type: String = _get_content_type(headers)
	if not content_type.is_empty():
		var resource: ImageTexture = _parse_by_content_type(content_type, data)
		if resource != null:
			return resource
	
	# 3. Last resort: try all formats
	var img: ImageTexture = _load_png_from_buffer(data)
	if img:
		return img
	
	img = _load_jpg_from_buffer(data)
	if img:
		return img
	
	return _load_webp_from_buffer(data)


## Parse data based on Content-Type header
func _parse_by_content_type(content_type: String, data: PackedByteArray) -> ImageTexture:
	match content_type.to_lower():
		"image/png", "image/x-png":
			return _load_png_from_buffer(data)
		"image/jpeg", "image/jpg":
			return _load_jpg_from_buffer(data)
		"image/webp":
			return _load_webp_from_buffer(data)
		_:
			return null


## Detect image format from file header magic bytes
func _detect_format_from_magic_bytes(data: PackedByteArray) -> String:
	# Check JPEG: starts with 0xFF 0xD8 0xFF
	if data.size() >= 3:
		if data[0] == 0xFF and data[1] == 0xD8 and data[2] == 0xFF:
			return "jpeg"
	
	# Check PNG: starts with 0x89 0x50 0x4E 0x47 (0x89 P N G)
	if data.size() >= 4:
		if data[0] == 0x89 and data[1] == 0x50 and data[2] == 0x4E and data[3] == 0x47:
			return "png"
	
	# Check WebP: RIFF....WEBP (bytes 0-3 = RIFF, bytes 8-11 = WEBP)
	if data.size() >= 12:
		var is_riff: bool = data[0] == 0x52 and data[1] == 0x49 and data[2] == 0x46 and data[3] == 0x46
		var is_webp: bool = data[8] == 0x57 and data[9] == 0x45 and data[10] == 0x42 and data[11] == 0x50
		if is_riff and is_webp:
			return "webp"
	
	return ""


## Parse data using the specified format
func _parse_by_format(format: String, data: PackedByteArray) -> ImageTexture:
	match format:
		"png":
			return _load_png_from_buffer(data)
		"jpeg":
			return _load_jpg_from_buffer(data)
		"webp":
			return _load_webp_from_buffer(data)
		_:
			return null


func _load_png_from_buffer(data: PackedByteArray) -> ImageTexture:
	var image: Image = Image.new()
	var error: Error = image.load_png_from_buffer(data)
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)


func _load_jpg_from_buffer(data: PackedByteArray) -> ImageTexture:
	var image: Image = Image.new()
	var error: Error = image.load_jpg_from_buffer(data)
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)


func _load_webp_from_buffer(data: PackedByteArray) -> ImageTexture:
	var image: Image = Image.new()
	var error: Error = image.load_webp_from_buffer(data)
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)
