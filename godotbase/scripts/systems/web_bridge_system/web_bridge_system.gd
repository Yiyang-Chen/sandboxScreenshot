class_name WebBridgeSystem extends System

## WebBridgeSystem
## 
## Manages all JavaScript Bridge communication for web platform.
## Encapsulates URL parameters, postMessage handling, and messaging.
## 
## Features:
## - Parse and access URL parameters
## - Receive messages from JavaScript via postMessage (callback-based, event-driven)
## - Send messages to parent window via postMessage
## - Non-web platform fallback (returns null/empty)
## - Event-based notification (WebParamsReceivedEvent)
## - Supports cross-origin iframe communication
##
## Usage:
## ```
## var web_bridge = get_system("WebBridgeSystem")
## 
## # URL parameters
## var level = web_bridge.get_url_parameter("level", "1")
## var debug = web_bridge.get_url_parameter_bool("debug", false)
## 
## # JavaScript messages (received via postMessage)
## var all_params = web_bridge.get_all_params()
## var player_name = web_bridge.get_param("player_name", "Guest")
## 
## # Listen to new parameters (event-based)
## var event_sys = get_system("EventSystem")
## event_sys.register(WebParamsReceivedEvent, _on_params_received)
## 
## # Send message to parent window
## web_bridge.send_message_to_parent("loadingComplete")
## web_bridge.send_message_to_parent("gameEvent", {"score": 100})
## ```
##
## Parent window sends messages via:
## ```javascript
## iframe.contentWindow.postMessage({
##     type: 'toGodot',
##     key: 'player_name',
##     value: 'Alice'
## }, '*');
##
## // Or batch params:
## iframe.contentWindow.postMessage({
##     type: 'toGodot',
##     params: { key1: 'value1', key2: 'value2' }
## }, '*');
## ```

# ========================================
# Private Variables
# ========================================

## Whether running on web platform
var _is_web: bool = false

## Parsed URL parameters (key: string, value: string)
## Prefix "URL_" is removed, e.g., ?level=5 → {"level": "5"}
var _url_params: Dictionary = {}

## Received parameters from JavaScript
## Updated via callback when postMessage is received
var _received_params: Dictionary = {}

## Whether JavaScript interface is set up
var _js_interface_ready: bool = false

## JavaScript callback 引用（必须保持引用防止 GC 回收）
var _js_callback: JavaScriptObject


# ========================================
# Public Read-Only Properties
# ========================================

## Get all URL parameters (read-only copy)
var url_params: Dictionary:
	get:
		return _url_params.duplicate()

## Get all received JavaScript parameters (read-only copy)
var received_params: Dictionary:
	get:
		return _received_params.duplicate()

## Check if running on web platform
var is_web: bool:
	get:
		return _is_web


# ========================================
# Lifecycle
# ========================================

func _on_init() -> void:
	_is_web = OS.has_feature("web")
	
	if _is_web:
		log_info("[WebBridgeSystem] Running on web platform")
		_setup_javascript_interface()
		_parse_url_parameters()
	else:
		log_info("[WebBridgeSystem] Not on web platform - limited functionality")

func _on_shutdown() -> void:
	_url_params.clear()
	_received_params.clear()
	_js_interface_ready = false
	log_info("[WebBridgeSystem] Shutdown")


# ========================================
# URL Parameters API
# ========================================

## Get URL parameter as string
## 
## @param name Parameter name (without "URL_" prefix)
## @param default_value Default value if not found
## @returns Parameter value or default
func get_url_parameter(name: String, default_value: String = "") -> String:
	if _url_params.has(name):
		return _url_params[name]
	return default_value

## Get URL parameter as integer
## 
## @param name Parameter name
## @param default_value Default value if not found or invalid
## @returns Integer value or default
func get_url_parameter_int(name: String, default_value: int = 0) -> int:
	if not _url_params.has(name):
		return default_value
	
	var value: String = _url_params[name]
	if value.is_valid_int():
		return value.to_int()
	
	log_warn("[WebBridgeSystem] URL parameter '%s' is not a valid integer: %s" % [name, value])
	return default_value

## Get URL parameter as float
## 
## @param name Parameter name
## @param default_value Default value if not found or invalid
## @returns Float value or default
func get_url_parameter_float(name: String, default_value: float = 0.0) -> float:
	if not _url_params.has(name):
		return default_value
	
	var value: String = _url_params[name]
	if value.is_valid_float():
		return value.to_float()
	
	log_warn("[WebBridgeSystem] URL parameter '%s' is not a valid float: %s" % [name, value])
	return default_value

## Get URL parameter as boolean
## 
## Accepts: "true", "1", "yes" → true
##          "false", "0", "no" → false
## 
## @param name Parameter name
## @param default_value Default value if not found or invalid
## @returns Boolean value or default
func get_url_parameter_bool(name: String, default_value: bool = false) -> bool:
	if not _url_params.has(name):
		return default_value
	
	@warning_ignore("unsafe_cast")
	var value: String = (_url_params[name] as String).to_lower()
	if value in ["true", "1", "yes"]:
		return true
	elif value in ["false", "0", "no"]:
		return false
	
	log_warn("[WebBridgeSystem] URL parameter '%s' is not a valid boolean: %s" % [name, value])
	return default_value

## Check if URL parameter exists
## 
## @param name Parameter name
## @returns true if parameter exists
func has_url_parameter(name: String) -> bool:
	return _url_params.has(name)

## Get all URL parameters
## 
## @returns Dictionary copy of all URL parameters
func get_all_url_parameters() -> Dictionary:
	return _url_params.duplicate()


# ========================================
# JavaScript Parameters API
# ========================================

## Get JavaScript parameter (received via postMessage)
## 
## @param name Parameter name
## @param default_value Default value if not found
## @returns Parameter value or default
func get_param(name: String, default_value: String = "") -> String:
	if _received_params.has(name):
		return _received_params[name]
	return default_value

## Check if JavaScript parameter exists
## 
## @param name Parameter name
## @returns true if parameter exists
func has_param(name: String) -> bool:
	return _received_params.has(name)

## Get all JavaScript parameters
## 
## @returns Dictionary copy of all received parameters
func get_all_params() -> Dictionary:
	return _received_params.duplicate()

## Clear all JavaScript parameters
func clear_params() -> void:
	_received_params.clear()


# ========================================
# Messaging API
# ========================================

## Send a message to parent window (via postMessage)
##
## @param type Message type string (e.g. "loadingComplete")
## @param data Optional data dictionary to include in the message
func send_message_to_parent(type: String, data: Dictionary = {}) -> void:
	if not _is_web:
		log_info("[WebBridgeSystem] Not on web, skipping send_message_to_parent: %s" % type)
		return
	
	var msg: Dictionary = {"type": type}
	if not data.is_empty():
		msg["data"] = data
	
	var json_str: String = JSON.stringify(msg)
	if json_str.is_empty():
		log_error("[WebBridgeSystem] Failed to stringify message: %s" % type)
		return
	
	var code: String = "window.parent.postMessage(%s, '*');" % json_str
	JavaScriptBridge.eval(code, true)
	log_debug("[WebBridgeSystem] Sent message to parent: %s" % type)


## Close HTML loading overlay and notify parent window
## Calls hideLoadingOverlay and sendInitMessageToParent on parent window
func close_html_overlay() -> void:
	if not _is_web:
		log_info("[WebBridgeSystem] Not on web, skipping close_html_overlay")
		return
	
	JavaScriptBridge.eval("window.hideLoadingOverlay && window.hideLoadingOverlay();")
	log_info("[WebBridgeSystem] Closed HTML overlay")


# ========================================
# Private: JavaScript Setup
# ========================================

## Setup JavaScript interface using callback-based postMessage handling
func _setup_javascript_interface() -> void:
	log_info("[WebBridgeSystem] Setting up JavaScript interface...")
	
	# 创建 Godot 回调（必须保存引用，否则会被 GC 回收导致 callback 失效）
	_js_callback = JavaScriptBridge.create_callback(_on_message_received)
	
	# 注入回调到 window
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	window.set("_godotReceiveMessage", _js_callback)
	
	# 处理启动前缓存的消息
	_process_queued_messages()
	
	_js_interface_ready = true
	log_info("[WebBridgeSystem] JavaScript interface ready")

## Parse URL parameters from browser address bar
func _parse_url_parameters() -> void:
	log_info("[WebBridgeSystem] Parsing URL parameters...")
	
	# Extract URL parameters directly as JSON
	var code: String = """
		(function() {
			var params = {};
			var searchParams = new URLSearchParams(window.location.search);
			searchParams.forEach(function(value, key) {
				params[key] = value;
				console.log('URL param:', key, '=', value);
			});
			return JSON.stringify(params);
		})();
	"""
	
	var json_str: Variant = JavaScriptBridge.eval(code, true)
	
	if json_str == null or not json_str is String or json_str == "null":
		log_info("[WebBridgeSystem] No URL parameters found")
		return
	
	var json: JSON = JSON.new()
	@warning_ignore("unsafe_cast")
	var error: Error = json.parse(json_str as String)
	
	if error != OK or json.data == null:
		log_error("[WebBridgeSystem] Failed to parse URL parameters JSON: error code %d" % error)
		return
	
	if not json.data is Dictionary:
		log_error("[WebBridgeSystem] URL parameters are not a dictionary: %s" % typeof(json.data))
		return
	
	_url_params = json.data
	
	for key: String in _url_params:
		log_info("[WebBridgeSystem] ✓ Stored URL param: %s = %s" % [key, _url_params[key]])
	
	log_info("[WebBridgeSystem] URL parameters parsed: %d parameters" % _url_params.size())

# ========================================
# Private: PostMessage Handling
# ========================================

## 处理 HTML 端在 Godot 启动前缓存的消息
func _process_queued_messages() -> void:
	var code: String = """
		(function() {
			if (window._godotMessageQueue && window._godotMessageQueue.length > 0) {
				var queued = window._godotMessageQueue.slice();
				window._godotMessageQueue = [];
				console.log('[Bridge] Processing', queued.length, 'queued messages');
				return JSON.stringify(queued);
			}
			return null;
		})();
	"""
	
	var json_str: Variant = JavaScriptBridge.eval(code, true)
	if json_str == null or not json_str is String or json_str == "null":
		log_info("[WebBridgeSystem] No queued messages to process")
		return
	
	var json: JSON = JSON.new()
	@warning_ignore("unsafe_cast")
	var error: Error = json.parse(json_str as String)
	if error != OK or json.data == null:
		log_error("[WebBridgeSystem] Failed to parse queued messages")
		return
	
	if not json.data is Array:
		log_error("[WebBridgeSystem] Queued messages is not an array")
		return
	
	@warning_ignore("unsafe_cast")
	var data_array: Array = json.data as Array
	log_info("[WebBridgeSystem] Processing %d queued messages" % data_array.size())
	
	# 处理每条缓存的消息
	for msg: Variant in data_array:
		if msg is Dictionary:
			@warning_ignore("unsafe_cast")
			_process_single_message(msg as Dictionary)


## 处理单条消息（供 callback 和队列处理共用）
func _process_single_message(data: Dictionary) -> void:
	var new_params: Dictionary = {}
	
	# 支持单个 key-value
	if data.has("key") and data.has("value"):
		var key: String = str(data["key"])
		var value: String = str(data["value"]) if data["value"] != null else ""
		_received_params[key] = value
		new_params[key] = value
	
	# 支持批量 params
	if data.has("params") and data["params"] is Dictionary:
		for key: String in data["params"]:
			var value: String = str(data["params"][key])
			_received_params[key] = value
			new_params[key] = value
	
	# 触发事件
	if not new_params.is_empty():
		_trigger_params_received_event(new_params)


## JavaScript callback 入口
func _on_message_received(args: Array) -> void:
	if args.is_empty():
		return
	
	var json_str: Variant = args[0]
	if not json_str is String:
		log_error("[WebBridgeSystem] Invalid callback argument type")
		return
	
	var json: JSON = JSON.new()
	@warning_ignore("unsafe_cast")
	var error: Error = json.parse(json_str as String)
	if error != OK or json.data == null:
		log_error("[WebBridgeSystem] Failed to parse message JSON")
		return
	
	if not json.data is Dictionary:
		log_error("[WebBridgeSystem] Message is not a dictionary")
		return
	
	@warning_ignore("unsafe_cast")
	_process_single_message(json.data as Dictionary)


# ========================================
# Private: Event Handling
# ========================================

## Trigger WebParamsReceivedEvent when new parameters are received
func _trigger_params_received_event(new_params: Dictionary) -> void:
	var event_sys: EventSystem = get_system("EventSystem") as EventSystem
	if event_sys == null:
		return
	
	var event: WebParamsReceivedEvent = WebParamsReceivedEvent.new(new_params)
	event_sys.trigger(event)
