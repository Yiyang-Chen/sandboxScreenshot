class_name FontLoadFailedEvent extends GameEvent

## FontLoadFailedEvent
##
## Event triggered when a font fails to load.
##
## Usage:
## ```
## func _ready():
##     var event_sys = env.get_system("EventSystem")
##     event_sys.register(FontLoadFailedEvent, _on_font_load_failed)
##
## func _on_font_load_failed(event: FontLoadFailedEvent):
##     print("Font load failed: ", event.font_key)
##     print("Error: ", event.error_message)
## ```

## Font configuration key (from manifest)
var font_key: String = ""

## Error description
var error_message: String = ""

