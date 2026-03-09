class_name GameEnvironment extends RefCounted

## GameEnvironment Base Class
## 
## Manages lifecycle of all Systems, responsibilities include:
## 1. Register Systems
## 2. Auto-initialize all Systems
## 3. Provide System access interface
## 4. Unified shutdown management
## 5. Multi-instance support via static registry

# ========================================
# Static: Global Environment Registry
# ========================================

## All Environment instances (key: id, value: GameEnvironment)
static var _instances: Dictionary = {}

## ID generator for auto-generated environment IDs
static var _id_generator: IDGenerator = IDGenerator.new("env")


# ========================================
# Instance Variables
# ========================================

## Unique identifier for this Environment
var environment_id: String

## All registered Systems (key: class_name, value: System instance)
var _systems: Dictionary = {}

## Whether already initialized
var initialized: bool = false


# ========================================
# Constructor
# ========================================

func _init(id: String = "") -> void:
	# Auto-generate ID if not provided
	if id.is_empty():
		id = _id_generator.next()
	
	environment_id = id
	
	# Register to global instances
	if _instances.has(id):
		push_warning("[GameEnvironment] Environment with id '%s' already exists, will be replaced" % id)
	_instances[id] = self
	
	print("[GameEnvironment] Created environment: %s" % id)


# ========================================
# Static Methods: Global Access
# ========================================

## Get Environment by ID
static func get_environment(id: String) -> GameEnvironment:
	return _instances.get(id)

## Check if Environment exists
static func has_environment(id: String) -> bool:
	return _instances.has(id)

## Get all Environment instances
static func get_all_environments() -> Array[GameEnvironment]:
	var result: Array[GameEnvironment] = []
	for env: GameEnvironment in _instances.values():
		result.append(env)
	return result

## Get all Environment IDs
static func get_all_ids() -> Array[String]:
	var result: Array[String] = []
	for key: String in _instances.keys():
		result.append(key)
	return result


# ========================================
# Lifecycle Management
# ========================================

## Initialize Environment
## 1. Call _on_init() to let subclass register Systems
## 2. Auto-initialize all uninitialized Systems
func init() -> void:
	if initialized:
		push_warning("[GameEnvironment] %s already initialized" % environment_id)
		return
	
	print("[GameEnvironment] %s initializing..." % environment_id)
	
	# Let subclass register systems
	_on_init()
	
	# Auto-initialize all systems
	var systems: Array[System] = get_all_systems()
	print("[GameEnvironment] Found %d systems to initialize" % systems.size())
	
	for system: System in systems:
		if not system.initialized:
			system.init()
	
	initialized = true
	print("[GameEnvironment] %s initialized successfully" % environment_id)

## Shutdown Environment
## 1. Call _pre_shutdown() hook
## 2. Auto-shutdown all initialized Systems (except manual_shutdown ones)
## 3. Call _post_shutdown() hook
## 4. Clear container
## 5. Remove from global registry
func shutdown() -> void:
	if not initialized:
		return
	
	print("[GameEnvironment] %s shutting down..." % environment_id)
	
	# Pre-shutdown hook
	_pre_shutdown()
	
	# Shutdown all systems in reverse order (except manual_shutdown ones)
	# Later registered systems may depend on earlier ones, so shut down in reverse
	var systems: Array[System] = get_all_systems()
	systems.reverse()
	for system: System in systems:
		if system.initialized and not system.manual_shutdown:
			system.shutdown()
	
	# Post-shutdown hook
	_post_shutdown()
	
	# Clear systems
	_systems.clear()
	initialized = false
	
	# Remove from global registry
	_instances.erase(environment_id)
	
	print("[GameEnvironment] %s shutdown complete" % environment_id)


# ========================================
# System Management
# ========================================

## Register a System
## 1. Set System's Environment reference
## 2. Register System to dictionary
## 3. If Environment already initialized, initialize the System immediately
func register_system(system: System) -> void:
	# Get type name from script's class_name or script path
	var script_resource: Resource = system.get_script()
	if script_resource == null:
		push_error("[GameEnvironment] Cannot determine type name for system")
		return
	
	@warning_ignore("unsafe_cast")
	var script: GDScript = script_resource as GDScript
	var type_name: String = ""
	
	if script:
		# Try to get class_name first
		type_name = script.get_global_name()
		
		# Fallback to script filename if no class_name
		if type_name.is_empty():
			var script_path: String = script.resource_path
			type_name = script_path.get_file().get_basename()
	
	if type_name.is_empty():
		push_error("[GameEnvironment] Cannot determine type name for system")
		return
	
	# Set Environment reference
	system.set_environment(self)
	
	# Register to dictionary (use class name as key)
	if _systems.has(type_name):
		push_warning("[GameEnvironment] System %s already registered, will be replaced" % type_name)
	_systems[type_name] = system
	
	# If Environment already initialized, initialize the System immediately
	if initialized and not system.initialized:
		system.init()

## Get System by type name
## 
## @param type_name System's class name (e.g., "PlayerSystem")
## @returns System instance, or null if not found
func get_system(type_name: String) -> System:
	return _systems.get(type_name)

## Check if System is registered
func has_system(type_name: String) -> bool:
	return _systems.has(type_name)

## Get all registered Systems
func get_all_systems() -> Array[System]:
	var result: Array[System] = []
	for system: System in _systems.values():
		result.append(system)
	return result


# ========================================
# Subclass Hooks
# ========================================

## Subclass implementation: register all Systems
## Call register_system() here to register each System
func _on_init() -> void:
	pass

## Subclass can override: cleanup work before shutdown
func _pre_shutdown() -> void:
	pass

## Subclass can override: cleanup work after shutdown
func _post_shutdown() -> void:
	pass
