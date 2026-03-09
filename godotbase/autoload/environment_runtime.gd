extends Node

## EnvironmentRuntime (Autoload Singleton)
## 
## Framework-level runtime that manages all GameEnvironment instances lifecycle.
## This is NOT a game-logic singleton - game systems should be registered as System instances.
## 
## Responsibilities:
## 1. First to load (Autoload priority)
## 2. Auto-creates MainGameEnvironment on startup
## 3. Last to shutdown (on game exit)
## 4. Survives scene transitions
## 5. Provides global access to Environments and Systems

# ========================================
# Preload
# ========================================

# Uses class_name: MainGameEnvironment


# ========================================
# Private Variables
# ========================================

## Default environment ID (first created environment)
var _default_env_id: String = ""


# ========================================
# Lifecycle Callbacks
# ========================================

func _ready() -> void:
	print("[EnvironmentRuntime] Ready - first to load")
	
	# Auto-create default MainGameEnvironment
	var env: MainGameEnvironment = MainGameEnvironment.new("main")
	env.init()
	
	# Set as default
	_default_env_id = env.environment_id
	print("[EnvironmentRuntime] Auto-created default environment: %s" % _default_env_id)

func _process(delta: float) -> void:
	# Update all systems in all environments
	for env: GameEnvironment in get_all_environments():
		if env.initialized:
			for system: System in env.get_all_systems():
				system._on_process(delta)

func _exit_tree() -> void:
	print("[EnvironmentRuntime] Shutting down - last to exit")
	
	# Shutdown all environments before exit
	var all_envs: Array[GameEnvironment] = GameEnvironment.get_all_environments()
	print("[EnvironmentRuntime] Shutting down %d environments" % all_envs.size())
	
	for env: GameEnvironment in all_envs:
		if env.initialized:
			env.shutdown()


# ========================================
# Environment Management
# ========================================

## Create and optionally initialize a new Environment
## 
## @param id Unique identifier for the environment (auto-generated if empty)
## @param auto_init Whether to automatically call init() (default: true)
## @returns Created GameEnvironment instance
func create_environment(id: String = "", auto_init: bool = true) -> GameEnvironment:
	var env: GameEnvironment = GameEnvironment.new(id)
	
	if auto_init:
		env.init()
	
	# Set first environment as default
	if _default_env_id.is_empty():
		_default_env_id = env.environment_id
		print("[EnvironmentRuntime] Set default environment: %s" % _default_env_id)
	
	return env

## Get Environment by ID
## 
## @param id Environment identifier
## @returns GameEnvironment instance or null if not found
func get_environment(id: String) -> GameEnvironment:
	return GameEnvironment.get_environment(id)

## Check if Environment exists
func has_environment(id: String) -> bool:
	return GameEnvironment.has_environment(id)

## Get default Environment (first created one)
func get_default() -> GameEnvironment:
	if _default_env_id.is_empty():
		push_warning("[EnvironmentRuntime] No default environment set")
		return null
	return GameEnvironment.get_environment(_default_env_id)

## Set default Environment
func set_default(id: String) -> void:
	if not GameEnvironment.has_environment(id):
		push_error("[EnvironmentRuntime] Environment '%s' does not exist" % id)
		return
	_default_env_id = id
	print("[EnvironmentRuntime] Default environment changed to: %s" % id)

## Get all Environment instances
func get_all_environments() -> Array[GameEnvironment]:
	return GameEnvironment.get_all_environments()

## Get all Environment IDs
func get_all_ids() -> Array[String]:
	return GameEnvironment.get_all_ids()

## Remove and shutdown an Environment
## 
## @param id Environment identifier
func remove_environment(id: String) -> void:
	var env: GameEnvironment = GameEnvironment.get_environment(id)
	if env == null:
		push_warning("[EnvironmentRuntime] Environment '%s' not found" % id)
		return
	
	# Clear default if removing default environment
	if id == _default_env_id:
		_default_env_id = ""
	
	# Shutdown the environment (will remove itself from registry)
	env.shutdown()


# ========================================
# Convenience Methods
# ========================================

## Get System from default Environment
## Convenient for single-environment games
## 
## @param type_name System class name (e.g., "PlayerSystem")
## @returns System instance or null
func get_system(type_name: String) -> System:
	var env: GameEnvironment = get_default()
	if env == null:
		return null
	return env.get_system(type_name)

## Check if System exists in default Environment
func has_system(type_name: String) -> bool:
	var env: GameEnvironment = get_default()
	if env == null:
		return false
	return env.has_system(type_name)
