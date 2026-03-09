class_name FontLoadedEvent extends GameEvent

## FontLoadedEvent
##
## Event triggered when a font is successfully loaded from PCK.
##
## Usage:
## ```
## func _ready():
##     var event_sys = env.get_system("EventSystem")
##     event_sys.register(FontLoadedEvent, _on_font_loaded)
##
## func _on_font_loaded(event: FontLoadedEvent):
##     print("Font loaded: ", event.font_key)
##     if event.font_key == "press_start_2p":
##         $PixelLabel.add_theme_font_override("font", event.font)
## ```

## Font configuration key (from manifest)
var font_key: String = ""

## The loaded FontFile object
var font: FontFile = null

