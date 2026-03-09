extends Node

## Index Scene - Scene Container
## 
## Main entry scene. Acts as container for SceneSystem to add/remove scenes.
## Waits for loading.pck, then loads loading.tscn which handles resource loading.


var _resource_system: ResourceSystem = null
var _event_system: EventSystem = null
var _scene_system: SceneSystem = null
var _log: LogSystem = null


func _ready() -> void:
	_log = EnvironmentRuntime.get_system("LogSystem") as LogSystem
	_resource_system = EnvironmentRuntime.get_system("ResourceSystem") as ResourceSystem
	_event_system = EnvironmentRuntime.get_system("EventSystem") as EventSystem
	_scene_system = EnvironmentRuntime.get_system("SceneSystem") as SceneSystem
	
	_log.info("[Index] Started")
	
	if _resource_system.is_loading_pck_loaded():
		_start_loading_scene()
	else:
		_event_system.register(LoadingPckLoadedEvent, _on_loading_pck_loaded)


func _exit_tree() -> void:
	if _event_system:
		_event_system.unregister(LoadingPckLoadedEvent, _on_loading_pck_loaded)


func _on_loading_pck_loaded(event: LoadingPckLoadedEvent) -> void:
	_event_system.unregister(LoadingPckLoadedEvent, _on_loading_pck_loaded)
	
	if not event.success:
		_log.error("[Index] loading.pck failed")
		return
	
	_start_loading_scene()


func _start_loading_scene() -> void:
	_log.info("[Index] Loading scene...")
	_scene_system.load_scene("res://scenes/loading.tscn", {
		"loading_mode": "global",
		"target_scene": "res://scenes/main.tscn",
		"preload": []
	}, func() -> void:
		_log.info("[Index] Loading scene ready")
		queue_free()
	)
