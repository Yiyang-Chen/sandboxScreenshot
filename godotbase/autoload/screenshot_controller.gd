extends Node

## ScreenshotController (Autoload)
##
## Listens for toGodot screenshot requests (postMessage from parent), captures
## the game viewport, and sends the image as base64 to the parent via postMessage.
##
## Parent sends request via postMessage, e.g.:
##   iframe.contentWindow.postMessage({ type: 'toGodot', key: 'takeScreenshot', value: '1' }, '*');
##   or: { type: 'toGodot', params: { takeScreenshot: '1', source: 'optionalId' } }
##
## Controller replies with postMessage to parent (source echoed back):
##   { type: 'adventureGameScreenshot', data: { image: '<base64 PNG>', source: '<source>' } }
##
## Only active on web platform; no-op on other platforms.

# ========================================
# Private Variables
# ========================================

var _event_system: EventSystem = null
var _web_bridge: WebBridgeSystem = null
var _log: LogSystem = null


# ========================================
# Lifecycle
# ========================================

func _ready() -> void:
	if not OS.has_feature("web"):
		return
	
	var env: GameEnvironment = EnvironmentRuntime.get_default()
	if env == null:
		push_warning("[ScreenshotController] No default environment, screenshot disabled")
		return
	
	_log = env.get_system("LogSystem") as LogSystem
	_event_system = env.get_system("EventSystem") as EventSystem
	_web_bridge = env.get_system("WebBridgeSystem") as WebBridgeSystem
	
	if _event_system == null:
		_log_warn("EventSystem not found")
		return
	if _web_bridge == null:
		_log_warn("WebBridgeSystem not found")
		return
	
	_event_system.register(WebParamsReceivedEvent, _on_web_params_received)
	_log_info("Listening for toGodot takeScreenshot")


func _exit_tree() -> void:
	if _event_system != null:
		_event_system.unregister(WebParamsReceivedEvent, _on_web_params_received)
		_event_system = null
	_web_bridge = null
	_log = null


# ========================================
# Event Handler
# ========================================

func _on_web_params_received(event: WebParamsReceivedEvent) -> void:
	if not event.new_params.has("takeScreenshot"):
		return
	
	var source: String = event.new_params.get("source", "")
	_capture_and_send(source)


# ========================================
# Capture and Send
# ========================================

func _capture_and_send(source: String) -> void:
	if not OS.has_feature("web") or _web_bridge == null:
		return
	
	var viewport: Viewport = get_viewport()
	if viewport == null:
		_log_warn("No viewport")
		return
	
	var vp_texture: ViewportTexture = viewport.get_texture()
	if vp_texture == null:
		_log_warn("No viewport texture")
		return
	
	var image: Image = vp_texture.get_image()
	if image == null or image.is_empty():
		_log_warn("Failed to get viewport image")
		return
	
	var png_buffer: PackedByteArray = image.save_png_to_buffer()
	if png_buffer.is_empty():
		_log_warn("Failed to encode PNG")
		return
	
	var base64_str: String = Marshalls.raw_to_base64(png_buffer)
	var data: Dictionary = {"image": base64_str}
	if not source.is_empty():
		data["source"] = source
	_web_bridge.send_message_to_parent("adventureGameScreenshot", data)
	_log_info("Sent screenshot to parent (%d bytes base64)" % base64_str.length())


# ========================================
# Logging Helpers
# ========================================

func _log_info(message: String) -> void:
	var msg := "[ScreenshotController] %s" % message
	if _log != null:
		_log.info(msg)
	else:
		print(msg)


func _log_warn(message: String) -> void:
	var msg := "[ScreenshotController] %s" % message
	if _log != null:
		_log.warn(msg)
	else:
		push_warning(msg)
