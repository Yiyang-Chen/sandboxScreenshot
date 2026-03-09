class_name ResourceNodeReadyEvent extends GameEvent

## ResourceNodeReadyEvent
##
## Event triggered when ResourceSystem receives a Node provider.
## This enables HTTP requests on web platform.
##
## Usage:
## ```
## func _on_init():
##     var event_sys = get_system("EventSystem")
##     event_sys.register(ResourceNodeReadyEvent, _on_node_ready)
##
## func _on_node_ready(event: ResourceNodeReadyEvent):
##     # Now safe to make HTTP requests via ResourceSystem
##     print("ResourceSystem Node ready")
## ```

## The Node that was injected
var node: Node = null



