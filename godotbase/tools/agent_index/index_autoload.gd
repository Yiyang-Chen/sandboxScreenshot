extends Node

## Unified Index Autoload
##
## 合并所有 indexing 功能，支持增量模式。
##
## 使用方式：
##   godot --headless -- --index           # 自动检测（有变更则增量，否则跳过）
##   godot --headless -- --index full      # 强制全量
##   godot --headless -- --index incremental  # 强制增量
##
## 生成文件：
##   .agent_index/repo_map.json       - 项目配置
##   .agent_index/scene_map.json      - 场景结构
##   .agent_index/script_symbols.json - 脚本符号
##   .agent_index/index_state.json    - 索引状态

const OUTPUT_DIR: String = ".agent_index"
const EXCLUDED_DIRS: Array[String] = ["addons", "build", "dist", "tests", "tools"]

var _mode: String = "auto"  # auto, full, incremental
var _last_index_time: int = 0
var _changed_gd_files: Array[String] = []
var _changed_tscn_files: Array[String] = []


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	
	# 检查是否是 indexing 模式
	var index_idx: int = -1
	for i: int in args.size():
		if args[i] == "--index":
			index_idx = i
			break
	
	if index_idx == -1:
		queue_free()  # 正常模式，释放自己
		return
	
	# 解析模式参数
	if index_idx + 1 < args.size():
		var mode_arg: String = args[index_idx + 1]
		if mode_arg in ["full", "incremental"]:
			_mode = mode_arg
	
	print("======================================================================")
	print("Godot Project Indexing")
	print("======================================================================")
	
	_run_indexing()
	
	print("======================================================================")
	get_tree().quit()


func _run_indexing() -> void:
	# 确保输出目录存在
	var dir: DirAccess = DirAccess.open("res://")
	if not dir.dir_exists(OUTPUT_DIR):
		dir.make_dir(OUTPUT_DIR)
	
	# 加载上次索引时间
	_load_last_index_time()
	
	# 检测变更文件
	_detect_changed_files()
	
	# 决定实际模式
	var actual_mode: String = _mode
	
	# 如果没有上次索引时间，强制全量（即使指定了 incremental）
	if _last_index_time <= 0:
		actual_mode = "full"
	elif _mode == "auto":
		if _changed_gd_files.is_empty() and _changed_tscn_files.is_empty():
			print("  No changes detected, skipping indexing")
			return
		else:
			actual_mode = "incremental"
	
	print("  Mode: %s" % actual_mode)
	if actual_mode == "incremental":
		print("  Changed files: %d .gd, %d .tscn" % [_changed_gd_files.size(), _changed_tscn_files.size()])
	print("")
	
	# 生成各索引文件
	var success: bool = true
	
	# 1. repo_map.json (总是全量，因为依赖 project.godot)
	print("[1/4] Generating repo_map.json...")
	if not _generate_repo_map():
		success = false
	
	# 2. scene_map.json
	print("[2/4] Generating scene_map.json...")
	if not _generate_scene_map(actual_mode):
		success = false
	
	# 3. script_symbols.json
	print("[3/4] Generating script_symbols.json...")
	if not _generate_script_symbols(actual_mode):
		success = false
	
	# 4. index_state.json
	print("[4/4] Generating index_state.json...")
	if not _generate_index_state(actual_mode):
		success = false
	
	print("")
	if success:
		print("=== Indexing Complete ===")
		print("  [OK] repo_map.json")
		print("  [OK] scene_map.json")
		print("  [OK] script_symbols.json")
		print("  [OK] index_state.json")
	else:
		print("=== Indexing completed with errors ===")


func _load_last_index_time() -> void:
	var state_path: String = "res://" + OUTPUT_DIR + "/index_state.json"
	if not FileAccess.file_exists(state_path):
		return
	
	var file: FileAccess = FileAccess.open(state_path, FileAccess.READ)
	if not file:
		return
	
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		var timestamp_str: String = data.get("generatedAt", "")
		if not timestamp_str.is_empty():
			_last_index_time = int(Time.get_unix_time_from_datetime_string(timestamp_str))
	file.close()


func _detect_changed_files() -> void:
	_changed_gd_files.clear()
	_changed_tscn_files.clear()
	
	if _last_index_time <= 0:
		return  # 没有上次索引时间，全量模式
	
	_scan_for_changes("res://")


func _scan_for_changes(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = path.path_join(file_name)
		
		if dir.current_is_dir():
			if not file_name.begins_with(".") and not file_name in EXCLUDED_DIRS:
				_scan_for_changes(full_path)
		else:
			# 检查文件修改时间
			var mtime: int = FileAccess.get_modified_time(full_path)
			if mtime > _last_index_time:
				if file_name.ends_with(".gd"):
					_changed_gd_files.append(full_path)
				elif file_name.ends_with(".tscn"):
					_changed_tscn_files.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()


# ============================================================================
# repo_map.json - 项目配置（总是全量）
# ============================================================================

func _generate_repo_map() -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load("res://project.godot") != OK:
		print("  [Error] Failed to load project.godot")
		return false
	
	var repo_map: Dictionary = {
		"version": "0.1",
		"generatedAt": Time.get_datetime_string_from_system(true),
		"project": {"engine": "godot", "language": ["gdscript"]},
		"entrypoints": _extract_entrypoints(config),
		"autoloads": _extract_autoloads(config),
		"directories": _get_directory_tags()
	}
	
	return _atomic_write_json(repo_map, OUTPUT_DIR + "/repo_map.json")


func _extract_entrypoints(config: ConfigFile) -> Dictionary:
	var entrypoints: Dictionary = {}
	if config.has_section_key("application", "run/main_scene"):
		entrypoints["main_scene"] = config.get_value("application", "run/main_scene")
	return entrypoints


func _extract_autoloads(config: ConfigFile) -> Array[Dictionary]:
	var autoloads: Array[Dictionary] = []
	if not config.has_section("autoload"):
		return autoloads
	
	for key: String in config.get_section_keys("autoload"):
		var path: String = str(config.get_value("autoload", key))
		if path.begins_with("*"):
			path = path.substr(1)
		autoloads.append({"name": key, "path": path})
	
	return autoloads


func _get_directory_tags() -> Array[Dictionary]:
	var directories: Array[Dictionary] = []
	_scan_repo_index("res://", directories)
	directories.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["path"]) < str(b["path"]))
	return directories


func _scan_repo_index(path: String, directories: Array[Dictionary]) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return
	
	var index_path: String = path.path_join(".repo_index")
	if FileAccess.file_exists(index_path):
		var info: Dictionary = _read_repo_index(path, index_path)
		if not info.is_empty():
			directories.append(info)
	
	dir.list_dir_begin()
	var dir_name: String = dir.get_next()
	while dir_name != "":
		if dir.current_is_dir() and not dir_name.begins_with(".") and not dir_name in EXCLUDED_DIRS:
			_scan_repo_index(path.path_join(dir_name), directories)
		dir_name = dir.get_next()
	dir.list_dir_end()


func _read_repo_index(dir_path: String, index_path: String) -> Dictionary:
	var info: Dictionary = {"path": dir_path, "tag": null, "purpose": null}
	var file: FileAccess = FileAccess.open(index_path, FileAccess.READ)
	if not file:
		return {}
	
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if ":" in line:
			var parts: PackedStringArray = line.split(":", true, 1)
			if parts.size() == 2:
				var key: String = parts[0].strip_edges().to_lower()
				var value: String = parts[1].strip_edges()
				if key == "tag":
					info["tag"] = value
				elif key == "purpose":
					info["purpose"] = value
	file.close()
	
	if info["tag"] and info["purpose"]:
		return info
	return {}


# ============================================================================
# scene_map.json - 场景结构
# ============================================================================

func _generate_scene_map(mode: String) -> bool:
	var scenes: Dictionary = {}
	
	# 增量模式：加载现有数据
	if mode == "incremental":
		scenes = _load_existing_json(OUTPUT_DIR + "/scene_map.json", "scenes")
	
	# 获取要处理的场景
	var scene_files: Array[String] = []
	if mode == "incremental":
		scene_files = _changed_tscn_files.duplicate()
	else:
		scene_files = _find_all_files("res://", ".tscn")
	
	print("  Processing %d scene(s)..." % scene_files.size())
	
	for scene_path: String in scene_files:
		var scene_data: Variant = _parse_scene_file(scene_path)
		if scene_data != null:
			scenes[scene_path] = scene_data
	
	var scene_map: Dictionary = {
		"version": "0.1",
		"generatedAt": Time.get_datetime_string_from_system(true),
		"scenes": scenes
	}
	
	return _atomic_write_json(scene_map, OUTPUT_DIR + "/scene_map.json")


func _parse_scene_file(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	
	var content: String = file.get_as_text()
	file.close()
	
	var ext_resources: Dictionary = _parse_ext_resources(content)
	var nodes: Array[Dictionary] = _parse_nodes(content, ext_resources)
	var external_scenes: Array[String] = _collect_external_scenes(ext_resources)
	
	return {
		"externalScenes": external_scenes,
		"nodes": nodes
	}


func _parse_ext_resources(content: String) -> Dictionary:
	var resources: Dictionary = {}
	var regex: RegEx = RegEx.new()
	regex.compile('\\[ext_resource[^\\]]*type="([^"]*)"[^\\]]*path="([^"]*)"[^\\]]*id="([^"]*)"')
	
	for result: RegExMatch in regex.search_all(content):
		resources[result.get_string(3)] = {
			"type": result.get_string(1),
			"path": result.get_string(2)
		}
	return resources


func _parse_nodes(content: String, ext_resources: Dictionary) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	var lines: PackedStringArray = content.split("\n")
	
	for i: int in lines.size():
		var line: String = lines[i].strip_edges()
		if not line.begins_with("[node"):
			continue
		
		var name_attr: Variant = _extract_attr(line, "name")
		var type_attr: Variant = _extract_attr(line, "type")
		var parent_attr: Variant = _extract_attr(line, "parent")
		
		if name_attr == null or type_attr == null:
			continue
		
		var node_path: String = str(name_attr) if parent_attr == null or str(parent_attr) == "." else str(parent_attr) + "/" + str(name_attr)
		var node_data: Dictionary = {"path": node_path, "type": str(type_attr), "script": null}
		
		# 查找脚本
		var j: int = i + 1
		while j < lines.size():
			var next_line: String = lines[j].strip_edges()
			if next_line.begins_with("["):
				break
			if next_line.begins_with("script = "):
				var ext_id: Variant = _extract_ext_res_id(next_line.substr(9))
				if ext_id and ext_resources.has(ext_id):
					node_data["script"] = ext_resources[ext_id]["path"]
				break
			j += 1
		
		nodes.append(node_data)
	
	return nodes


func _extract_attr(text: String, attr: String) -> Variant:
	var pattern: String = attr + '="'
	var start: int = text.find(pattern)
	if start == -1:
		return null
	start += pattern.length()
	var end: int = text.find('"', start)
	return text.substr(start, end - start) if end != -1 else null


func _extract_ext_res_id(value: String) -> Variant:
	var regex: RegEx = RegEx.new()
	regex.compile('ExtResource\\s*\\(\\s*"([^"]*)"\\s*\\)')
	var result: RegExMatch = regex.search(value)
	return result.get_string(1) if result else null


func _collect_external_scenes(ext_resources: Dictionary) -> Array[String]:
	var scenes: Array[String] = []
	for res: Variant in ext_resources.values():
		if res is Dictionary and res["type"] == "PackedScene":
			scenes.append(res["path"])
	return scenes


# ============================================================================
# script_symbols.json - 脚本符号
# ============================================================================

func _generate_script_symbols(mode: String) -> bool:
	var scripts: Dictionary = {}
	
	# 增量模式：加载现有数据
	if mode == "incremental":
		scripts = _load_existing_json(OUTPUT_DIR + "/script_symbols.json", "scripts")
	
	# 获取要处理的脚本
	var script_files: Array[String] = []
	if mode == "incremental":
		script_files = _changed_gd_files.duplicate()
	else:
		script_files = _find_all_files("res://", ".gd")
	
	print("  Processing %d script(s)..." % script_files.size())
	
	var success_count: int = 0
	var error_count: int = 0
	
	for i: int in script_files.size():
		if i > 0 and i % 10 == 0:
			print("    Progress: %d/%d..." % [i, script_files.size()])
		
		var script_path: String = script_files[i]
		var info: Dictionary = _extract_script_info(script_path)
		if not info.is_empty():
			scripts[script_path] = info
			success_count += 1
		else:
			error_count += 1
	
	print("  Extracted %d scripts (%d errors)" % [success_count, error_count])
	
	var output: Dictionary = {
		"version": "0.1",
		"generatedAt": Time.get_datetime_string_from_system(true),
		"scripts": scripts
	}
	
	return _atomic_write_json(output, OUTPUT_DIR + "/script_symbols.json")


func _extract_script_info(script_path: String) -> Dictionary:
	var info: Dictionary = {
		"class_name": null,
		"extends": null,
		"tool": false,
		"signals": [],
		"exports": [],
		"functions": []
	}
	
	if not FileAccess.file_exists(script_path):
		return {}
	
	var script: Variant = load(script_path)
	if not script or not (script is GDScript):
		return {}
	
	@warning_ignore("unsafe_cast")
	var gdscript: GDScript = script as GDScript
	
	# class_name
	var global_name: StringName = gdscript.get_global_name()
	if not global_name.is_empty():
		info["class_name"] = String(global_name)
	
	# extends
	var base: Script = gdscript.get_base_script()
	if base:
		var base_name: StringName = base.get_global_name()
		if not base_name.is_empty():
			info["extends"] = String(base_name)
		else:
			info["extends"] = base.resource_path
	else:
		# 原生类 - 直接获取基类名称，无需实例化
		var base_type: StringName = gdscript.get_instance_base_type()
		if not base_type.is_empty():
			info["extends"] = String(base_type)
	
	# 方法
	var functions_arr: Array = info["functions"]
	for method: Dictionary in gdscript.get_script_method_list():
		var args: Array[String] = []
		if method.has("args"):
			for arg_variant: Variant in method["args"]:
				if arg_variant is Dictionary:
					var arg_dict: Dictionary = arg_variant
					args.append(arg_dict.get("name", ""))
		functions_arr.append({"name": method["name"], "args": args})
	
	# 信号
	var signals_arr: Array = info["signals"]
	for sig: Dictionary in gdscript.get_script_signal_list():
		if not signals_arr.has(sig["name"]):
			signals_arr.append(sig["name"])
	
	# 导出属性
	var exports_arr: Array = info["exports"]
	for prop: Dictionary in gdscript.get_script_property_list():
		var usage: int = prop["usage"]
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) and (usage & PROPERTY_USAGE_EDITOR):
			exports_arr.append({"name": prop["name"], "type": _type_name(prop.get("type", 0))})
	
	return info


func _type_name(type_id: Variant) -> String:
	var id: int = type_id if type_id is int else 0
	match id:
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_OBJECT: return "Object"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_ARRAY: return "Array"
		_: return "Variant"


# ============================================================================
# index_state.json - 索引状态
# ============================================================================

func _generate_index_state(mode: String) -> bool:
	var timestamp: String = Time.get_datetime_string_from_system(true)
	
	var state: Dictionary = {
		"version": "0.1",
		"generatedAt": timestamp,
		"lastFullIndexAt": timestamp if mode == "full" else _get_last_full_index_time(),
		"lastIncrementalIndexAt": timestamp,
		"mode": mode
	}
	
	return _atomic_write_json(state, OUTPUT_DIR + "/index_state.json")


func _get_last_full_index_time() -> String:
	var existing: Dictionary = _load_existing_json(OUTPUT_DIR + "/index_state.json", "")
	if existing.has("lastFullIndexAt"):
		return existing["lastFullIndexAt"]
	return Time.get_datetime_string_from_system(true)


# ============================================================================
# 工具函数
# ============================================================================

func _find_all_files(path: String, extension: String) -> Array[String]:
	var files: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return files
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = path.path_join(file_name)
		if dir.current_is_dir():
			if not file_name.begins_with(".") and not file_name in EXCLUDED_DIRS:
				for f: String in _find_all_files(full_path, extension):
					files.append(f)
		elif file_name.ends_with(extension):
			files.append(full_path)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return files


func _load_existing_json(path: String, key: String) -> Dictionary:
	var full_path: String = "res://" + path
	if not FileAccess.file_exists(full_path):
		return {}
	
	var file: FileAccess = FileAccess.open(full_path, FileAccess.READ)
	if not file:
		return {}
	
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		file.close()
		return {}
	
	file.close()
	var data: Dictionary = json.data
	
	if key.is_empty():
		return data
	return data.get(key, {}) if data.has(key) else {}


func _atomic_write_json(data: Dictionary, path: String) -> bool:
	var full_path: String = "res://" + path
	var temp_path: String = full_path + ".tmp"
	
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		print("  [Error] Failed to write: %s" % path)
		return false
	
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	
	var dir: DirAccess = DirAccess.open("res://")
	if FileAccess.file_exists(full_path):
		dir.remove(full_path)
	
	if dir.rename(temp_path, full_path) != OK:
		dir.remove(temp_path)
		return false
	
	return true
