class_name GameEvent extends RefCounted

## GameEvent Base Class
## 
## Base class for all game events used with EventSystem.
## 
## IMPORTANT: All event classes MUST have a class_name declaration!
## This enables type-safe registration and full IDE support.
## 
## Usage:
## 1. Create event class with class_name declaration
## 2. Extend GameEvent
## 3. Add event-specific data as member variables
## 4. Register handlers using the class type (not string)
## 5. Trigger events by creating instances
##
## Example:
## ```
## class_name PlayerJumpEvent extends GameEvent
## 
## var player: Node
## var velocity: float
## 
## func _init(p: Node, vel: float):
##     player = p
##     velocity = vel
## ```
## 
## Then register:
## ```
## event_sys.register(PlayerJumpEvent, _on_player_jump)
## ```

## Get event type name from this event's script
## Used internally by EventSystem to route events
## 
## REQUIRES: Event class MUST have class_name declaration
## @param script The script to get type name from
## @returns Empty string if error, otherwise the class name
static func get_type_name_from_script(script: Script) -> String:
	if script == null:
		return ""
	
	# Get class_name from script - this is the ONLY supported way
	var class_name_val: String = script.get_global_name()
	if not class_name_val.is_empty():
		return class_name_val
	
	# No class_name - return empty string
	return ""
