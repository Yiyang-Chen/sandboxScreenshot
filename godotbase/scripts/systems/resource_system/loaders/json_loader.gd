class_name JsonLoader extends AssetLoader

## JsonLoader
##
## Loader for JSON resources.
## Returns parsed Dictionary or Array.
##
## Note: This is used for all JSON-based resources including:
## - Plain JSON configs
## - Atlas JSON (sprite frame data)
## - Animation JSON
## - Tilemap JSON
##
## The caller (e.g., AtlasLoader) decides how to interpret the JSON data.

func _parse_data(data: PackedByteArray, _headers: PackedStringArray) -> Variant:
	var text: String = data.get_string_from_utf8()
	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		print("[JsonLoader] Parse error: %s at line %d" % [json.get_error_message(), json.get_error_line()])
		return null
	return json.data
