extends SceneTree

## pack_assets.gd
##
## Generic asset packing tool that creates versioned PCK files for different asset types.
##
## Features:
## - Auto-scans public/assets/ for directories containing manifest.json
## - Reads manifest.json to determine internal path prefix and file extensions
## - Packs assets into PCK with hash-based versioning
## - Generates dist/pck_index.json with all PCK info
## - Cleans up old PCK files
##
## manifest.json format:
##   {
##     "extensions": ["png", "webp", "ttf"],   # File extensions to scan and pack
##     "internal_prefix": "res://loading/",     # Internal path prefix in PCK
##     "pack_imported": false                   # (Optional, default: true)
##                                              # true:  pack original + .import + compiled resource (.ctex/.fontdata)
##                                              # false: pack original file only (for raw FileAccess loading)
##   }
##
## Usage:
##   godot --headless --script tools/pack_assets.gd -- --type=all
##   godot --headless --script tools/pack_assets.gd -- --type=fonts
##   godot --headless --script tools/pack_assets.gd -- --type=loading
##
## Output:
##   - dist/<type>_<hash>.pck for each asset type
##   - dist/loading_pck.json for HTML to pre-cache loading.pck
##   - public/pck_infos/<type>.json for each system to read PCK info

const ASSETS_ROOT: String = "res://public/assets/"
const OUTPUT_DIR: String = "res://dist/"
const PCK_INFOS_DIR: String = "res://public/pck_infos/"
const LOADING_PCK_INDEX_PATH: String = "res://dist/loading_pck.json"
const RENAME_MAP_PATH: String = "res://dist/rename_map.txt"
const EXPORT_PRESETS_PATH: String = "res://export_presets.cfg"
const EXPORT_PRESETS_SANDBOX_PATH: String = "res://export_presets_sandbox.cfg"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[PackAssets] Starting asset packing...")
	
	# Parse command line arguments
	var target_type: String = _parse_args()
	print("[PackAssets] Target type: %s" % target_type)
	
	# Discover all asset directories with manifest.json
	var asset_dirs: Dictionary = _discover_asset_dirs()
	if asset_dirs.is_empty():
		push_error("[PackAssets] No asset directories found with manifest.json")
		quit(1)
		return
	
	print("[PackAssets] Found %d asset directories: %s" % [asset_dirs.size(), asset_dirs.keys()])
	
	# Ensure output directories exist
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PCK_INFOS_DIR))
	
	# Track rename mappings: temp_file -> final_file
	var rename_map: Array[String] = []
	
	# Track loading.pck info for HTML (only loading.pck needs special handling)
	var loading_pck_info: Dictionary = {}
	
	# Process each asset directory
	for dir_name: String in asset_dirs:
		if target_type != "all" and dir_name != target_type:
			continue
		
		var manifest: Dictionary = asset_dirs[dir_name]
		var result: Dictionary = _pack_asset_dir(dir_name, manifest)
		if not result.is_empty():
			# Add to rename map: "type_temp.pck final_name.pck"
			rename_map.append("%s_temp.pck %s" % [dir_name, result["file"]])
			
			# Save loading.pck info for HTML
			if dir_name == "loading":
				loading_pck_info = result
	
	# Save loading_pck.json (for HTML only)
	_save_loading_pck_index(loading_pck_info)
	
	# Save rename_map.txt for shell script
	_save_rename_map(rename_map)
	
	# Update export_presets.cfg exclude_filter (only when packing all)
	if target_type == "all":
		_update_export_presets_exclude_filter(asset_dirs)
	
	print("[PackAssets] Done!")
	quit(0)


## Parse command line arguments for --type=xxx
func _parse_args() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--type="):
			return arg.substr(7)
	return "all"


## Discover all asset directories containing manifest.json
func _discover_asset_dirs() -> Dictionary:
	var result: Dictionary = {}
	var dir: DirAccess = DirAccess.open(ASSETS_ROOT)
	if dir == null:
		return result
	
	dir.list_dir_begin()
	var dir_name: String = dir.get_next()
	while dir_name != "":
		if dir.current_is_dir() and not dir_name.begins_with("."):
			var manifest_path: String = ASSETS_ROOT + dir_name + "/manifest.json"
			if FileAccess.file_exists(manifest_path):
				var manifest: Dictionary = _load_manifest(manifest_path)
				if not manifest.is_empty():
					result[dir_name] = manifest
					print("[PackAssets] Found: %s" % dir_name)
		dir_name = dir.get_next()
	dir.list_dir_end()
	
	return result


## Load manifest.json from path
func _load_manifest(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	
	var json: JSON = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		push_error("[PackAssets] Invalid JSON in %s: %s" % [path, json.get_error_message()])
		return {}
	
	if not json.data is Dictionary:
		push_error("[PackAssets] manifest.json must be a Dictionary: %s" % path)
		return {}
	
	return json.data




## Pack a single asset directory
func _pack_asset_dir(dir_name: String, manifest: Dictionary) -> Dictionary:
	var source_dir: String = ASSETS_ROOT + dir_name + "/"
	var internal_prefix: String = manifest.get("internal_prefix", "res://%s/" % dir_name)
	var extensions: Array = manifest.get("extensions", [])
	
	if extensions.is_empty():
		push_error("[PackAssets] No extensions defined for %s" % dir_name)
		return {}
	
	# Scan for files
	var files: Array[String] = _scan_files(source_dir, extensions)
	if files.is_empty():
		print("[PackAssets] No files found for %s, skipping" % dir_name)
		return {}
	
	print("[PackAssets] Packing %s: %d files" % [dir_name, files.size()])
	
	# Create temporary PCK
	var temp_pck_path: String = OUTPUT_DIR + dir_name + "_temp.pck"
	var packer: PCKPacker = PCKPacker.new()
	var err: Error = packer.pck_start(temp_pck_path)
	if err != OK:
		push_error("[PackAssets] Failed to start PCK for %s: %s" % [dir_name, error_string(err)])
		return {}
	
	# Build items list for fonts (or similar types that need item enumeration)
	var items: Array[Dictionary] = []
	
	var pack_imported: bool = manifest.get("pack_imported", true)
	
	for file_name: String in files:
		var source_path: String = source_dir + file_name
		var internal_path: String = internal_prefix + file_name
		
		# Add original file
		err = packer.add_file(internal_path, source_path)
		if err != OK:
			push_error("[PackAssets] Failed to add file %s: %s" % [file_name, error_string(err)])
			continue
		
		print("[PackAssets]   Added: %s -> %s" % [file_name, internal_path])
		
		# Add .import file and compiled resource only when pack_imported is true
		if pack_imported:
			var import_source_path: String = source_path + ".import"
			var import_internal_path: String = internal_path + ".import"
			if FileAccess.file_exists(import_source_path):
				err = packer.add_file(import_internal_path, import_source_path)
				if err == OK:
					print("[PackAssets]   Added: %s.import" % file_name)
					
					# Parse .import file to find compiled resource (.ctex, etc.)
					var compiled_path: String = _get_compiled_resource_path(import_source_path)
					if not compiled_path.is_empty():
						var compiled_source: String = ProjectSettings.globalize_path(compiled_path)
						if FileAccess.file_exists(compiled_source):
							err = packer.add_file(compiled_path, compiled_source)
							if err == OK:
								print("[PackAssets]   Added: %s (compiled)" % compiled_path.get_file())
							else:
								push_warning("[PackAssets] Failed to add compiled resource: %s" % compiled_path)
						else:
							push_warning("[PackAssets] Compiled resource not found: %s" % compiled_path)
		
		# Generate item entry
		var item_key: String = _generate_key(file_name)
		items.append({
			"key": item_key,
			"path": internal_path
		})
	
	err = packer.flush()
	if err != OK:
		push_error("[PackAssets] Failed to flush PCK for %s: %s" % [dir_name, error_string(err)])
		return {}
	
	# Calculate hash
	var hash_value: String = _calculate_file_hash(temp_pck_path)
	var short_hash: String = hash_value.substr(0, 6)
	
	# Determine final PCK name
	var final_pck_name: String = "%s_%s.pck" % [dir_name, short_hash]
	var final_pck_path: String = OUTPUT_DIR + final_pck_name
	
	# Cleanup old PCK files for this type (except temp files, shell will handle those)
	_cleanup_old_pck_files(dir_name, final_pck_name)
	
	# Output info for shell script to do the rename
	# (DirAccess.rename() has issues on Windows in headless mode)
	print("[PackAssets] TempPCK: dist/%s_temp.pck" % dir_name)
	print("[PackAssets] TargetPCK: dist/%s" % final_pck_name)
	
	# Generate pck_info to public/pck_infos/<type>.json (FontSystem etc.)
	# This file will be packed into main PCK during export
	_generate_pck_info(dir_name, manifest, final_pck_name, short_hash, items)
	
	# Build result for pck_index.json (simpler, just file and hash)
	var result: Dictionary = {
		"file": final_pck_name,
		"hash": short_hash
	}
	
	return result


## Scan for files with given extensions
func _scan_files(source_dir: String, extensions: Array) -> Array[String]:
	var files: Array[String] = []
	var dir: DirAccess = DirAccess.open(source_dir)
	if dir == null:
		return files
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var ext: String = file_name.get_extension().to_lower()
			if ext in extensions:
				files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return files


## Generate key from filename
func _generate_key(file_name: String) -> String:
	return file_name.get_basename().to_snake_case()


## Parse .import file and return the compiled resource path
## The .import file contains: path="res://.godot/imported/xxx.ctex"
func _get_compiled_resource_path(import_file_path: String) -> String:
	var file: FileAccess = FileAccess.open(import_file_path, FileAccess.READ)
	if file == null:
		return ""
	
	var content: String = file.get_as_text()
	file.close()
	
	# Find path="..." line in [remap] section
	var regex: RegEx = RegEx.new()
	regex.compile("path=\"([^\"]+)\"")
	var result: RegExMatch = regex.search(content)
	if result:
		return result.get_string(1)
	
	return ""


## Calculate MD5 hash of file
func _calculate_file_hash(file_path: String) -> String:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	
	while not file.eof_reached():
		var chunk: PackedByteArray = file.get_buffer(1024 * 1024)
		if chunk.size() > 0:
			ctx.update(chunk)
	
	file.close()
	return ctx.finish().hex_encode()


## Remove old PCK files for a type
func _cleanup_old_pck_files(type_name: String, new_pck_name: String) -> void:
	var dir: DirAccess = DirAccess.open(OUTPUT_DIR)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.begins_with(type_name + "_") and file_name.ends_with(".pck"):
			if file_name != new_pck_name and not file_name.ends_with("_temp.pck"):
				dir.remove(file_name)
				print("[PackAssets] Removed old: %s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


## Generate pck_info to public/pck_infos/<type>.json
## This file will be packed into main PCK during export
## Format matches what FontSystem/LoadingSystem expects
func _generate_pck_info(dir_name: String, manifest: Dictionary, pck_file: String, hash_value: String, files: Array[Dictionary]) -> void:
	# Output to public/pck_infos/<type>.json (e.g., fonts.json, loading.json)
	var pck_info_path: String = PCK_INFOS_DIR + dir_name + ".json"
	
	# Build pck_info with runtime data
	var pck_info: Dictionary = {
		"pck_file": pck_file,
		"hash": hash_value
	}
	
	# Map "default" to "default_font" for FontSystem compatibility
	if manifest.has("default"):
		pck_info["default_font"] = manifest["default"]
	
	# Use "fonts" key for font files, generic "files" for others
	# FontSystem expects "fonts" array with {key, path} objects
	if dir_name == "fonts":
		pck_info["fonts"] = files
	else:
		pck_info["files"] = files
	
	# Write pck_info json
	var file: FileAccess = FileAccess.open(pck_info_path, FileAccess.WRITE)
	if file == null:
		push_error("[PackAssets] Failed to write pck_info: %s" % pck_info_path)
		return
	
	file.store_string(JSON.stringify(pck_info, "  "))
	file.close()
	print("[PackAssets] Generated: %s" % pck_info_path)


## Save loading_pck.json (for HTML to pre-cache loading.pck)
func _save_loading_pck_index(loading_info: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(LOADING_PCK_INDEX_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[PackAssets] Failed to write loading_pck.json")
		return
	
	file.store_string(JSON.stringify(loading_info, "  "))
	file.close()
	print("[PackAssets] Updated: loading_pck.json")


## Save rename_map.txt for shell script to process
## Format: each line is "temp_file final_file"
func _save_rename_map(rename_map: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(RENAME_MAP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[PackAssets] Failed to write rename_map.txt")
		return
	
	for line: String in rename_map:
		file.store_line(line)
	file.close()
	print("[PackAssets] Updated: rename_map.txt (%d entries)" % rename_map.size())


## Update exclude_filter in export_presets.cfg files
## This ensures asset files are not duplicated in main PCK
func _update_export_presets_exclude_filter(asset_dirs: Dictionary) -> void:
	# Build exclude patterns from discovered asset directories
	# Exclude entire folder if it has manifest.json
	var excludes: Array[String] = ["dist/*"]
	
	for dir_name: String in asset_dirs:
		excludes.append("public/assets/%s/*" % dir_name)
	
	var exclude_filter: String = ", ".join(PackedStringArray(excludes))
	
	# Update both cfg files
	_update_cfg_exclude_filter(EXPORT_PRESETS_PATH, exclude_filter)
	_update_cfg_exclude_filter(EXPORT_PRESETS_SANDBOX_PATH, exclude_filter)


## Update exclude_filter line in a single cfg file
func _update_cfg_exclude_filter(cfg_path: String, exclude_filter: String) -> void:
	var file: FileAccess = FileAccess.open(cfg_path, FileAccess.READ)
	if file == null:
		print("[PackAssets] Cannot open %s (may not exist)" % cfg_path)
		return
	
	var content: String = file.get_as_text()
	file.close()
	
	# Replace exclude_filter line using regex
	var regex: RegEx = RegEx.new()
	regex.compile("exclude_filter=\"[^\"]*\"")
	
	var new_line: String = "exclude_filter=\"%s\"" % exclude_filter
	var new_content: String = regex.sub(content, new_line, true)
	
	if new_content == content:
		# No change needed or pattern not found
		print("[PackAssets] No exclude_filter change needed in %s" % cfg_path)
		return
	
	# Write back
	file = FileAccess.open(cfg_path, FileAccess.WRITE)
	if file == null:
		push_error("[PackAssets] Cannot write %s" % cfg_path)
		return
	
	file.store_string(new_content)
	file.close()
	print("[PackAssets] Updated exclude_filter in %s" % cfg_path)
