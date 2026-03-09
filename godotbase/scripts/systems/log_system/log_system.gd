class_name LogSystem extends System

## LogSystem
## 
## Unified logging system that wraps Godot's print/warning/error functions.
## Provides consistent logging interface with 4 levels and custom handler support.
## 
## Features:
## - 4 log levels: debug, info, warn, error
## - Log level filtering (can disable debug logs in production)
## - Custom handler support for advanced logging (remote, file, etc.)
## - Web platform integration (can send to JavaScript console/parent window)
##
## Usage:
## ```
## var logger = get_system("LogSystem")
## 
## logger.debug("[Player] Health: %d" % health)
## logger.info("[Game] Level loaded: %s" % level_name)
## logger.warn("[Audio] Missing sound: %s" % sound_id)
## logger.error("[Save] Failed to load save file")
## 
## # Disable debug logs in production
## logger.set_min_level(LogSystem.LogLevel.INFO)
## ```

# ========================================
# Types
# ========================================

## Log level enum
enum LogLevel {
	DEBUG,   ## Debug information (detailed, may be hidden in production)
	INFO,    ## Normal informational messages
	WARN,    ## Warning messages
	ERROR    ## Error messages
}


# ========================================
# Private Variables
# ========================================

## Custom log handler (optional)
## Signature: func(level: String, message: String, args: Array) -> void
var _custom_handler: Callable = Callable()

## Minimum log level to output (filters out lower priority logs)
var _min_level: LogLevel = LogLevel.DEBUG


# ========================================
# Lifecycle
# ========================================

func _on_init() -> void:
	print("[LogSystem] Initialized")

func _on_shutdown() -> void:
	_custom_handler = Callable()
	print("[LogSystem] Shutdown")


# ========================================
# Public API
# ========================================

## Log debug message
## Debug messages are typically hidden in production builds
## 
## @param message Message string (supports format strings)
## @param args Optional format arguments
func debug(message: String, args: Array = []) -> void:
	_log(LogLevel.DEBUG, message, args)

## Log info message
## 
## @param message Message string (supports format strings)
## @param args Optional format arguments
func info(message: String, args: Array = []) -> void:
	_log(LogLevel.INFO, message, args)

## Log normal message (alias for info)
## 
## @param message Message string (supports format strings)
## @param args Optional format arguments
func log(message: String, args: Array = []) -> void:
	_log(LogLevel.INFO, message, args)

## Log warning message
## 
## @param message Message string (supports format strings)
## @param args Optional format arguments
func warn(message: String, args: Array = []) -> void:
	_log(LogLevel.WARN, message, args)

## Log error message
## 
## @param message Message string (supports format strings)
## @param args Optional format arguments
func error(message: String, args: Array = []) -> void:
	_log(LogLevel.ERROR, message, args)

## Set custom log handler
## 
## Handler signature: func(level: String, message: String, args: Array) -> void
## Level will be one of: "debug", "info", "warn", "error"
## 
## IMPORTANT: Setting a custom handler will COMPLETELY REPLACE the default console output.
## If you want to keep console output, you must call print/push_warning/push_error in your handler.
## 
## Example with console output preserved:
## ```
## func my_handler(level: String, message: String, args: Array):
##     # Custom processing (e.g., send to remote server)
##     send_to_server(level, message)
##     
##     # Keep console output
##     match level:
##         "debug": print("[DEBUG] %s" % message)
##         "info": print(message)
##         "warn": push_warning(message)
##         "error": push_error(message)
## ```
## 
## @param handler Callable handler function
func set_handler(handler: Callable) -> void:
	if not handler.is_valid():
		push_error("[LogSystem] Cannot set invalid handler")
		return
	
	_custom_handler = handler
	print("[LogSystem] Custom handler set")

## Clear custom log handler (revert to default behavior)
func clear_handler() -> void:
	_custom_handler = Callable()
	print("[LogSystem] Custom handler cleared")

## Set minimum log level
## 
## Logs below this level will be filtered out.
## Use this to disable debug logs in production builds.
## 
## @param level Minimum LogLevel to output
func set_min_level(level: LogLevel) -> void:
	_min_level = level
	print("[LogSystem] Minimum log level set to: %s" % _level_to_string(level))

## Get current minimum log level
## 
## @return Current minimum LogLevel
func get_min_level() -> LogLevel:
	return _min_level


# ========================================
# Private Methods
# ========================================

## Internal log implementation
func _log(level: LogLevel, message: String, args: Array) -> void:
	# Filter by minimum level
	if level < _min_level:
		return
	
	# Format message if args provided
	var formatted_message: String = message
	if not args.is_empty():
		formatted_message = message % args
	
	# If custom handler is set, it takes full control (replaces default output)
	if _custom_handler.is_valid():
		var level_str: String = _level_to_string(level)
		_custom_handler.call(level_str, formatted_message, args)
		return
	
	# No custom handler: use default output
	# Web platform: use JavaScript console methods directly for correct styling
	if OS.has_feature("web"):
		_log_to_web_console(level, formatted_message)
		return
	
	# Non-web platform: use Godot's print functions
	var prefix: String = "[%s] " % _level_to_string(level).to_upper()
	var prefixed_message: String = prefix + formatted_message
	
	match level:
		LogLevel.DEBUG, LogLevel.INFO:
			print(prefixed_message)
		
		LogLevel.WARN:
			push_warning(prefixed_message)
		
		LogLevel.ERROR:
			push_error(prefixed_message)

## Log to web console using JavaScript
func _log_to_web_console(level: LogLevel, message: String) -> void:
	var js_level: String = _level_to_string(level)
	
	# Add level prefix to all logs
	var prefix: String = "[%s] " % _level_to_string(level).to_upper()
	var display_message: String = prefix + message
	
	var escaped_msg: String = JSON.stringify(display_message)
	if escaped_msg.is_empty():
		# Fallback to non-web logging if JSON.stringify fails
		push_error("[LogSystem] Failed to stringify message for web console: %s" % message)
		return
	
	# Use appropriate console method for correct styling
	var code: String = "console.%s(%s);" % [js_level, escaped_msg]
	JavaScriptBridge.eval(code, true)

## Convert LogLevel enum to string
func _level_to_string(level: LogLevel) -> String:
	match level:
		LogLevel.DEBUG:
			return "debug"
		LogLevel.INFO:
			return "info"
		LogLevel.WARN:
			return "warn"
		LogLevel.ERROR:
			return "error"
		_:
			push_warning("[LogSystem] Unknown log level: %d, defaulting to 'info'" % level)
			return "info"
