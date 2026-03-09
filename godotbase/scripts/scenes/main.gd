extends Node

## Main Scene - Game Entry Point
## 
## ⚠️ WARNING: REMOVE PLACEHOLDER UI BEFORE ADDING YOUR GAME! ⚠️
## The UILayer contains placeholder UI (PLACEHOLDER_DELETE_BEFORE_USE_*) 
## that will block your game view. Delete these nodes before starting development.
## 
## Loaded after loading.tscn completes. All global resources are ready.
## 
## Structure:
## - UILayer (Control): Put all UI elements here (HUD, menus, etc.)
## - GameLayer (Node): Put game content here (Node2D/Node3D scenes, entities, etc.)
##   For 2D games: add Node2D children to GameLayer
##   For 3D games: add Node3D children to GameLayer


func _ready() -> void:
	var log: LogSystem = EnvironmentRuntime.get_system("LogSystem") as LogSystem
	log.debug("[Main] Ready")
