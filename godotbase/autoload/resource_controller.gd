extends Node

## ResourceController (Autoload Singleton)
##
## Provides Node capabilities (HTTPRequest) to ResourceSystem.
## Must be loaded AFTER EnvironmentRuntime in autoload order.
##
## This autoload ensures ResourceSystem can make HTTP requests
## as soon as any scene starts, without requiring scenes to
## manually add ResourceController nodes.

var _resource_system: ResourceSystem = null


func _ready() -> void:
	_setup_resource_system()


func _setup_resource_system() -> void:
	# Get ResourceSystem from environment
	# Use get_node() instead of class name to avoid compile-time dependency
	var env_runtime: Node = get_node_or_null("/root/EnvironmentRuntime")
	if env_runtime == null:
		push_error("[ResourceController] EnvironmentRuntime not found")
		return
	
	# Cast to correct type for method access
	if env_runtime.has_method("get_system"):
		@warning_ignore("unsafe_method_access")
		var system: System = env_runtime.get_system("ResourceSystem")
		if system is ResourceSystem:
			_resource_system = system as ResourceSystem
	
	if _resource_system == null:
		push_error("[ResourceController] ResourceSystem not found")
		return
	
	# Inject this Node as provider for HTTPRequest
	_resource_system.set_node(self)
	print("[ResourceController] Injected Node to ResourceSystem (autoload)")


## Get the ResourceSystem instance
func get_resource_system() -> ResourceSystem:
	return _resource_system
