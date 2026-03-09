class_name System extends RefCounted

## System Base Class
## 
## Base class for all game systems, provides:
## 1. Configuration mechanism - supports configuration parameters
## 2. Lifecycle management - automatic init and shutdown
## 3. Environment access - can get other Systems

## Whether already initialized
var initialized: bool = false

## Whether manual shutdown is required (if true, Environment won't automatically shutdown this System)
var manual_shutdown: bool = false

## Environment reference (private)
var _environment: GameEnvironment = null

## Node provider reference (for systems that need Node capabilities like HTTPRequest)
var _node_provider: Node = null


# ========================================
# Environment Related Interface
# ========================================

## Get Environment this belongs to
func get_environment() -> GameEnvironment:
	if _environment == null:
		push_error("[System] %s environment is not set" % _get_class_name())
		return null
	return _environment

## Set Environment (called by Environment)
func set_environment(environment: GameEnvironment) -> void:
	_environment = environment

## Convenient method to get other Systems
## Subclass can use get_system("OtherSystem") to get other System
func get_system(type_name: String) -> System:
	return get_environment().get_system(type_name)


## Set Node provider (for systems that need Node capabilities like HTTPRequest)
## 
## Usage:
## ```
## var resource_sys = env.get_system("ResourceSystem")
## resource_sys.set_node(self)  # Inject Node for HTTP requests
## ```
func set_node(node: Node) -> void:
	_node_provider = node


## Get the injected Node provider
## Returns null if no node has been injected
func get_node() -> Node:
	if _node_provider != null and not is_instance_valid(_node_provider):
		# Clear stale provider reference (e.g., scene freed)
		_node_provider = null
		push_warning("[System] Node provider no longer valid; cleared reference")
	return _node_provider


# ========================================
# Logging Helpers
# ========================================

## Log message (uses LogSystem if available, falls back to print)
## 
## NOTE: LogSystem itself should NOT use these methods (would cause circular dependency)
## @param message Message string
func log_info(message: String) -> void:
	var logger: LogSystem = get_system("LogSystem") as LogSystem
	if logger != null:
		logger.info(message)
	else:
		print(message)

## Log debug message (uses LogSystem if available, falls back to print with [DEBUG] prefix)
## 
## NOTE: LogSystem itself should NOT use these methods (would cause circular dependency)
## @param message Message string
func log_debug(message: String) -> void:
	var logger: LogSystem = get_system("LogSystem") as LogSystem
	if logger != null:
		logger.debug(message)
	else:
		print("[DEBUG] %s" % message)

## Log warning (uses LogSystem if available, falls back to push_warning)
## 
## NOTE: LogSystem itself should NOT use these methods (would cause circular dependency)
## @param message Warning message
func log_warn(message: String) -> void:
	var logger: LogSystem = get_system("LogSystem") as LogSystem
	if logger != null:
		logger.warn(message)
	else:
		push_warning(message)

## Log error (uses LogSystem if available, falls back to push_error)
## 
## NOTE: LogSystem itself should NOT use these methods (would cause circular dependency)
## @param message Error message
func log_error(message: String) -> void:
	var logger: LogSystem = get_system("LogSystem") as LogSystem
	if logger != null:
		logger.error(message)
	else:
		push_error(message)


# ========================================
# Lifecycle Management
# ========================================

## Initialize System
## Automatically called by Environment, do not call manually
func init() -> void:
	if initialized:
		push_warning("[System] %s already initialized" % _get_class_name())
		return
	
	_on_init()
	initialized = true
	print("[System] %s initialized" % _get_class_name())

## Shutdown System
## Automatically called by Environment, do not call manually
func shutdown() -> void:
	if not initialized:
		return
	
	_on_shutdown()
	initialized = false
	_environment = null
	print("[System] %s shutdown" % _get_class_name())


## Get the class_name of this system (not the base class)
func _get_class_name() -> String:
	var script_resource: Resource = get_script()
	if script_resource:
		@warning_ignore("unsafe_cast")
		var script: GDScript = script_resource as GDScript
		var global_name: String = script.get_global_name()
		if not global_name.is_empty():
			return global_name
	return get_class()  # fallback


# ========================================
# Methods that subclasses need to implement
# ========================================

## Subclass implementation: initialization logic
func _on_init() -> void:
	pass

## Subclass implementation: shutdown/cleanup logic
func _on_shutdown() -> void:
	pass

## Subclass implementation: per-frame update logic (optional)
## Called every frame by EnvironmentRuntime if system is initialized
## @param delta Time elapsed since last frame
func _on_process(_delta: float) -> void:
	pass
