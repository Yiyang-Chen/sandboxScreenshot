class_name EventSystem extends System

## EventSystem
## 
## Provides decoupled event communication mechanism for game logic.
## Uses class-based strong typing for better AI agent development and error checking.
##
## Features:
## - Type-safe event handlers using Script types (not strings)
## - One-time event listeners
## - Automatic cleanup on shutdown (uses Godot Signals for automatic lifecycle)
## - Class type as event identifier (full IDE support and link checking)
## - Automatic handler cleanup when objects are destroyed (via CONNECT_REFERENCE_COUNTED)
##
## Usage:
## ```
## # Get system
## var event_sys = get_system("EventSystem")
## 
## # Register handler (pass class type, not string)
## event_sys.register(PlayerJumpEvent, _on_player_jump)
## 
## # Trigger event
## var event = PlayerJumpEvent.new(player, -500)
## event_sys.trigger(event)
## 
## # One-time handler
## event_sys.once(PlayerDiedEvent, _on_player_died)
## 
## # Unregister
## event_sys.unregister(PlayerJumpEvent, _on_player_jump)
## 
## # Deferred trigger (executes at end of frame)
## event_sys.trigger_deferred(event)
## ```

# ========================================
# Internal Signal Holder Class
# ========================================

## Internal class that holds a Signal for each event type
## This allows us to use Godot's native Signal system while maintaining type-safe API
class EventSignalHolder extends RefCounted:
	## Signal emitted when this event type is triggered
	signal triggered(event: GameEvent)
	
	## Event type name for debugging
	var type_name: String
	
	func _init(name: String) -> void:
		type_name = name

# ========================================
# Private Variables
# ========================================

## Event signal holders registry
## Key: event_type_name (String, class name extracted from Script)
## Value: EventSignalHolder instance
var _signal_holders: Dictionary = {}

## Helper: Get event type name from Script or GameEvent instance
## Uses the same logic for both register() and trigger() to ensure consistency
## @param event_or_type Either a GameEvent instance or a Script (class type)
## @returns String event type name
func _get_event_type_name(event_or_type: Variant) -> String:
	if event_or_type == null:
		log_error("[EventSystem] Cannot get type name from null")
		return ""
	
	var script_to_check: Script = null
	
	# If it's a GameEvent instance, get its script
	if event_or_type is GameEvent:
		@warning_ignore("unsafe_cast")
		var game_event: GameEvent = event_or_type as GameEvent
		script_to_check = game_event.get_script()
	# If it's a Script (class type), use it directly
	elif event_or_type is Script:
		@warning_ignore("unsafe_cast")
		script_to_check = event_or_type as Script
	else:
		log_error("[EventSystem] Invalid type: expected GameEvent instance or Script (class type)")
		return ""
	
	# Validate script
	if script_to_check == null:
		log_error("[EventSystem] Script is null")
		return ""
	
	# Use GameEvent's static method to get type name
	var type_name: String = GameEvent.get_type_name_from_script(script_to_check)
	
	# Check if we got a valid type name
	if type_name.is_empty():
		log_error("[EventSystem] Event class has no class_name declaration! All events MUST use 'class_name YourEvent extends GameEvent'")
		return ""
	
	return type_name


# ========================================
# Private Helpers
# ========================================

## Get or create signal holder for event type
func _get_or_create_holder(type_name: String) -> EventSignalHolder:
	if not _signal_holders.has(type_name):
		_signal_holders[type_name] = EventSignalHolder.new(type_name)
		log_info("[EventSystem] Created signal holder for %s" % type_name)
	return _signal_holders[type_name]

## Validate handler signature
## Checks that handler accepts exactly one parameter (the GameEvent)
## 
## @param handler Callable to validate
## @param type_name Event type name for error messages
## @returns true if handler signature is valid
func _validate_handler_signature(handler: Callable, type_name: String) -> bool:
	# Get argument count if possible
	# Note: GDScript has limited reflection, we can only check argument count
	var arg_count: int = handler.get_argument_count()
	
	# -1 means we can't determine argument count (built-in methods or native class methods)
	# In this case, skip validation and trust the developer
	if arg_count == -1:
		log_debug("[EventSystem] Cannot validate handler signature for %s (built-in or native method)" % type_name)
		return true
	
	# Handler should accept exactly 1 argument (the GameEvent)
	if arg_count != 1:
		log_error("[EventSystem] Handler for %s must accept exactly 1 parameter (GameEvent), got %d parameters" % [type_name, arg_count])
		return false
	
	return true

# ========================================
# Lifecycle
# ========================================

func _on_init() -> void:
	log_info("[EventSystem] Initialized (Signal-based)")

func _on_shutdown() -> void:
	log_info("[EventSystem] Shutting down, clearing %d event types" % _signal_holders.size())
	_signal_holders.clear()


# ========================================
# Public API
# ========================================

## Register event handler
## 
## @param event_type Event class type (Script), e.g., PlayerJumpEvent
## @param handler Callable that accepts one GameEvent parameter and returns void
func register(event_type: Script, handler: Callable) -> void:
	var type_name: String = _get_event_type_name(event_type)
	if type_name.is_empty():
		return
	
	if not handler.is_valid():
		log_error("[EventSystem] Cannot register invalid handler for %s" % type_name)
		return
	
	# Validate handler signature
	if not _validate_handler_signature(handler, type_name):
		return
	
	var holder: EventSignalHolder = _get_or_create_holder(type_name)
	
	# Check if already connected
	if holder.triggered.is_connected(handler):
		log_warn("[EventSystem] Handler already registered for %s" % type_name)
		return
	
	# Connect using Signal with automatic lifecycle management
	holder.triggered.connect(handler, CONNECT_REFERENCE_COUNTED)
	
	log_info("[EventSystem] Registered handler for %s" % type_name)

## Unregister event handler
## 
## @param event_type Event class type (Script)
## @param handler Handler to remove (must be same reference)
func unregister(event_type: Script, handler: Callable) -> void:
	var type_name: String = _get_event_type_name(event_type)
	if type_name.is_empty():
		return
	
	if not _signal_holders.has(type_name):
		log_debug("[EventSystem] No handlers registered for %s" % type_name)
		return
	
	var holder: EventSignalHolder = _signal_holders[type_name]
	
	if holder.triggered.is_connected(handler):
		holder.triggered.disconnect(handler)
		log_info("[EventSystem] Unregistered handler for %s" % type_name)
		
		# Clean up empty holders
		if holder.triggered.get_connections().is_empty():
			_signal_holders.erase(type_name)
			log_info("[EventSystem] Removed empty holder for %s" % type_name)
	else:
		log_warn("[EventSystem] Handler not found for %s" % type_name)

## Register one-time event handler (auto-removes after first trigger)
## 
## Uses Godot's CONNECT_ONE_SHOT flag for automatic cleanup after first trigger.
## 
## @param event_type Event class type (Script)
## @param handler Callable that accepts one GameEvent parameter and returns void
func once(event_type: Script, handler: Callable) -> void:
	var type_name: String = _get_event_type_name(event_type)
	if type_name.is_empty():
		return
	
	if not handler.is_valid():
		log_error("[EventSystem] Cannot register invalid handler for %s" % type_name)
		return
	
	# Validate handler signature
	if not _validate_handler_signature(handler, type_name):
		return
	
	var holder: EventSignalHolder = _get_or_create_holder(type_name)
	
	# Check if already connected
	if holder.triggered.is_connected(handler):
		log_warn("[EventSystem] Handler already registered for %s" % type_name)
		return
	
	# Use Godot's built-in one-shot connection
	# Automatically disconnects after first emission
	holder.triggered.connect(handler, CONNECT_REFERENCE_COUNTED | CONNECT_ONE_SHOT)
	
	log_info("[EventSystem] Registered one-time handler for %s" % type_name)

## Trigger event
## 
## Calls all registered handlers for the event type immediately.
## Handlers marked as "once" will be automatically removed after execution.
## 
## @param event GameEvent instance
func trigger(event: GameEvent) -> void:
	if event == null:
		log_error("[EventSystem] Cannot trigger null event")
		return
	
	var event_type: String = _get_event_type_name(event)
	if event_type.is_empty():
		log_error("[EventSystem] Event has empty type")
		return
	
	if not _signal_holders.has(event_type):
		# Not an error - events can be triggered without handlers
		log_debug("[EventSystem] Triggered %s (no handlers registered)" % event_type)
		return
	
	var holder: EventSignalHolder = _signal_holders[event_type]
	var handler_count: int = holder.triggered.get_connections().size()
	
	log_debug("[EventSystem] Triggering %s (%d handlers)" % [event_type, handler_count])
	
	# Emit signal - all connected handlers will be called
	holder.triggered.emit(event)

## Trigger event deferred (executes at end of current frame)
## 
## Useful for events that should not execute immediately to avoid
## modifying collections during iteration or breaking control flow.
## 
## @param event GameEvent instance
func trigger_deferred(event: GameEvent) -> void:
	if event == null:
		log_error("[EventSystem] Cannot trigger null event (deferred)")
		return
	
	var event_type: String = _get_event_type_name(event)
	if event_type.is_empty():
		log_error("[EventSystem] Event has empty type (deferred)")
		return
	
	# Use call_deferred to delay emission to end of frame
	call_deferred("_trigger_deferred_internal", event_type, event)

## Internal method for deferred triggering
func _trigger_deferred_internal(event_type: String, event: GameEvent) -> void:
	if not _signal_holders.has(event_type):
		return
	
	var holder: EventSignalHolder = _signal_holders[event_type]
	holder.triggered.emit(event)

## Check if event type has any registered handlers
## 
## @param event_type Event class type (Script)
## @returns true if at least one handler is registered
func has_handlers(event_type: Script) -> bool:
	var type_name: String = _get_event_type_name(event_type)
	if type_name.is_empty():
		return false
	
	if not _signal_holders.has(type_name):
		return false
	
	var holder: EventSignalHolder = _signal_holders[type_name]
	return not holder.triggered.get_connections().is_empty()

## Get count of handlers for event type
## 
## @param event_type Event class type (Script)
## @returns Number of registered handlers
func get_handler_count(event_type: Script) -> int:
	var type_name: String = _get_event_type_name(event_type)
	if type_name.is_empty():
		return 0
	
	if not _signal_holders.has(type_name):
		return 0
	
	var holder: EventSignalHolder = _signal_holders[type_name]
	return holder.triggered.get_connections().size()

## Get all registered event types
## 
## @returns Array of event type names (String)
func get_registered_event_types() -> Array[String]:
	var result: Array[String] = []
	result.assign(_signal_holders.keys())
	return result

## Clear all handlers for specific event type
## 
## @param event_type Event class type (Script)
func clear_event_type(event_type: Script) -> void:
	var type_name: String = _get_event_type_name(event_type)
	if type_name.is_empty():
		return
	
	if _signal_holders.has(type_name):
		var holder: EventSignalHolder = _signal_holders[type_name]
		var connections: Array = holder.triggered.get_connections()
		var count: int = connections.size()
		
		# Disconnect all handlers
		for connection: Variant in connections:
			if connection is Dictionary:
				var conn_dict: Dictionary = connection
				var callable: Callable = conn_dict["callable"]
				if holder.triggered.is_connected(callable):
					holder.triggered.disconnect(callable)
		
		_signal_holders.erase(type_name)
		log_info("[EventSystem] Cleared %d handlers for %s" % [count, type_name])
	else:
		log_warn("[EventSystem] No handlers to clear for %s" % type_name)

## Clear all handlers for all events
func clear_all() -> void:
	var total: int = 0
	for holder: EventSignalHolder in _signal_holders.values():
		total += holder.triggered.get_connections().size()
	
	_signal_holders.clear()
	log_info("[EventSystem] Cleared all handlers (total: %d)" % total)
