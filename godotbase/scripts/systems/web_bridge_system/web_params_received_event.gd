class_name WebParamsReceivedEvent extends GameEvent

## Event triggered when new parameters are received from JavaScript
## 
## This event is triggered by WebBridgeSystem when parent window sends parameters
## via postMessage with type 'toGodot'.
## 
## Usage:
## ```
## func _on_params_received(event: WebParamsReceivedEvent):
##     print("Received %d new parameters" % event.new_params.size())
##     for key in event.new_params:
##         print("  %s = %s" % [key, event.new_params[key]])
## ```

## Newly received parameters from JavaScript (key: String, value: String)
var new_params: Dictionary

## Constructor
## @param params Dictionary of newly received parameters
func _init(params: Dictionary) -> void:
	new_params = params
