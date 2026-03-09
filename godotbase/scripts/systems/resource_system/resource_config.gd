class_name ResourceConfig extends RefCounted

## ResourceConfig
##
## Resource configuration data structure.
## Represents a single resource with its loading paths and type.

## Resource ID (from game_config.json)
var id: int = 0

## Resource key (unique identifier)
var key: String = ""

## Resource type (uses ResourceTypes enum)
var type: int = 0

## Remote URL (priority: used first if available)
var remote_url: String = ""

## Local path (fallback: used if remote fails or is empty)
var local_path: String = ""

## Skip cache busting (for versioned filenames like fonts_abc123.pck)
var skip_cache_busting: bool = false


## Get resource path (remote URL takes priority)
func get_path() -> String:
	if not remote_url.is_empty():
		return remote_url
	if not local_path.is_empty():
		return local_path
	return ""


## Check if this config has a remote URL
func has_remote() -> bool:
	return not remote_url.is_empty()


## Check if this config has a local path
func has_local() -> bool:
	return not local_path.is_empty()


## Check if this config is valid (has at least one path)
func is_valid() -> bool:
	return has_remote() or has_local()

