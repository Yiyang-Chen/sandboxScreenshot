class_name IDGenerator extends RefCounted

## Incremental ID Generator
## Each instance maintains independent counter for generating sequential IDs

var prefix: String
var _counter: int = 0

func _init(id_prefix: String = "id") -> void:
	prefix = id_prefix

## Generate next ID with format: {prefix}_{counter}
func next() -> String:
	var id: String = "%s_%d" % [prefix, _counter]
	_counter += 1
	return id

## Reset counter to 0
func reset() -> void:
	_counter = 0

## Get current counter value
func get_count() -> int:
	return _counter

## Set starting counter value
func set_start(start_value: int) -> void:
	_counter = start_value
