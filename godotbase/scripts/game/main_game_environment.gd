class_name MainGameEnvironment extends GameEnvironment

## MainGameEnvironment
## 
## Main game environment that registers all core systems.
## This is the primary environment for most games using this template.
##
## Registered Systems:
## - WebBridgeSystem: JavaScript bridge, URL parameters, error reporting
## - EventSystem: Decoupled event communication
## - LogSystem: Unified logging interface
## - AudioSystem: Audio playback (BGM and SFX)
##
## Usage:
## ```
## # Create and initialize (typically in main scene)
## var env = EnvironmentRuntime.create_environment("main", false)
## # Environment will auto-init systems
## 
## # Access systems
## var logger = EnvironmentRuntime.get_system("LogSystem")
## var events = EnvironmentRuntime.get_system("EventSystem")
## var web = EnvironmentRuntime.get_system("WebBridgeSystem")
## ```


# ========================================
# Lifecycle
# ========================================

## Default config path for ResourceSystem
const DEFAULT_CONFIG_PATH: String = "res://public/assets/game_config.json"


func _on_init() -> void:
	print("[MainGameEnvironment] Registering core systems...")
	
	# Register systems
	register_system(WebBridgeSystem.new())
	register_system(EventSystem.new())
	register_system(LogSystem.new())
	
	# Register and initialize ResourceSystem
	var resource_sys: ResourceSystem = ResourceSystem.new()
	register_system(resource_sys)
	resource_sys.initialize(DEFAULT_CONFIG_PATH)
	
	# Register FontSystem
	register_system(FontSystem.new())
	
	# Register SceneSystem
	register_system(SceneSystem.new())
	
	# Register AudioSystem
	register_system(AudioSystem.new())
	
	print("[MainGameEnvironment] Core systems registered")
