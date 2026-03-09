extends SceneTree

## pack_fonts.gd
##
## Font packing tool that creates a versioned PCK file containing font assets.
##
## Features:
## - Scans public/assets/fonts/ for font files (.ttf, .otf, .woff, .woff2)
## - Packs them into a PCK with hash-based versioning
## - Updates fonts_manifest.json with PCK info
## - Cleans up old PCK files
##
## Usage:
##   godot --headless --script tools/pack_fonts.gd
##
## Output:
##   - dist/fonts_temp.pck (temporary file, needs rename by shell)
##   - public/assets/fonts/fonts_manifest.json (updated with target pck_file name)
##
## Note: The rename from fonts_temp.pck to fonts_<hash>.pck is done by the
## calling shell script (build.sh) because DirAccess.rename() has issues
## on Windows in headless mode.

const FONTS_SOURCE_DIR = "res://public/assets/fonts/"
const MANIFEST_PATH = "res://public/assets/fonts/fonts_manifest.json"
const OUTPUT_DIR = "res://dist/"
const PCK_INTERNAL_PREFIX = "res://fonts/"


func _init():
	# Run immediately when script loads
	call_deferred("_run")


func _run():
	print("[PackFonts] Starting font packing...")
	
	# 1. Scan font files
	var font_files = _scan_font_files()
	if font_files.is_empty():
		push_error("[PackFonts] No font files found in %s" % FONTS_SOURCE_DIR)
		quit(1)
		return
	
	print("[PackFonts] Found %d font files" % font_files.size())
	
	# 2. Ensure output directory exists
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	
	# 3. Pack into temporary PCK
	var temp_pck_path = OUTPUT_DIR + "fonts_temp.pck"
	var packer = PCKPacker.new()
	var err = packer.pck_start(temp_pck_path)
	if err != OK:
		push_error("[PackFonts] Failed to start PCK: %s" % error_string(err))
		quit(1)
		return
	
	var fonts_config = []
	for file_name in font_files:
		var source_path = FONTS_SOURCE_DIR + file_name
		var internal_path = PCK_INTERNAL_PREFIX + file_name
		
		err = packer.add_file(internal_path, source_path)
		if err != OK:
			push_error("[PackFonts] Failed to add file %s: %s" % [file_name, error_string(err)])
			continue
		
		# Generate font config entry
		var font_key = _generate_font_key(file_name)
		fonts_config.append({
			"key": font_key,
			"path": internal_path,
			"description": ""
		})
		
		print("[PackFonts] Added: %s -> %s (key: %s)" % [source_path, internal_path, font_key])
	
	err = packer.flush()
	if err != OK:
		push_error("[PackFonts] Failed to flush PCK: %s" % error_string(err))
		quit(1)
		return
	
	# 4. Calculate hash
	var hash_value = _calculate_file_hash(temp_pck_path)
	var short_hash = hash_value.substr(0, 6)
	
	# 5. Determine final PCK name
	var final_pck_name = "fonts_%s.pck" % short_hash
	var final_pck_path = OUTPUT_DIR + final_pck_name
	
	# 6. Cleanup old PCK files (delete works fine, only rename has issues)
	_cleanup_old_pck_files(final_pck_name)
	
	# 7. Update manifest (before rename, so shell can read target filename)
	_update_manifest(final_pck_name, short_hash, fonts_config)
	
	# 7. Output info for shell script to do the rename
	# (DirAccess.rename() has issues on Windows in headless mode)
	print("[PackFonts] TempPCK: dist/fonts_temp.pck")
	print("[PackFonts] TargetPCK: dist/%s" % final_pck_name)
	print("[PackFonts] Done! Shell script should rename fonts_temp.pck -> %s" % final_pck_name)
	quit(0)


## Scan for font files in source directory
func _scan_font_files() -> Array:
	var files = []
	var dir = DirAccess.open(FONTS_SOURCE_DIR)
	if dir == null:
		return files
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var ext = file_name.get_extension().to_lower()
			if ext in ["ttf", "otf", "woff", "woff2"]:
				files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return files


## Generate font key from filename
## Examples:
##   DingTalkJinBuTi-Regular.ttf -> ding_talk_jin_bu_ti_regular
##   PressStart2P-Regular.ttf -> press_start_2p_regular
func _generate_font_key(file_name: String) -> String:
	return file_name.get_basename().to_snake_case()


## Calculate MD5 hash of file
func _calculate_file_hash(file_path: String) -> String:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	
	while not file.eof_reached():
		var chunk = file.get_buffer(1024 * 1024)
		if chunk.size() > 0:
			ctx.update(chunk)
	
	file.close()
	return ctx.finish().hex_encode()


## Remove old fonts_*.pck files
func _cleanup_old_pck_files(new_pck_name: String) -> void:
	var dir = DirAccess.open(OUTPUT_DIR)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.begins_with("fonts_") and file_name.ends_with(".pck"):
			# Don't remove fonts_temp.pck (we need it for renaming) or the new PCK
			if file_name != new_pck_name and file_name != "fonts_temp.pck":
				dir.remove(file_name)
				print("[PackFonts] Removed old PCK: %s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


## Update fonts_manifest.json
func _update_manifest(pck_file: String, hash_value: String, fonts: Array) -> void:
	# Read existing manifest to preserve default_font
	var default_font = ""
	if FileAccess.file_exists(MANIFEST_PATH):
		var read_file = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		if read_file:
			var json = JSON.new()
			if json.parse(read_file.get_as_text()) == OK:
				var data = json.data
				if data is Dictionary and data.has("default_font"):
					default_font = data.default_font
			read_file.close()
	
	# If no default font set, use the first one
	if default_font.is_empty() and not fonts.is_empty():
		default_font = fonts[0].key
	
	# Build manifest
	var manifest = {
		"pck_file": pck_file,
		"hash": hash_value,
		"default_font": default_font,
		"fonts": fonts
	}
	
	# Write manifest
	var write_file = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if write_file:
		write_file.store_string(JSON.stringify(manifest, "  "))
		write_file.close()
		print("[PackFonts] Updated manifest: %s" % MANIFEST_PATH)
