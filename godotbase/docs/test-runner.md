# Test Runner - Headless Screenshot Testing

Automated testing framework for capturing screenshots of Godot scenes in a headless environment. Agents write GDScript test files that extend `TestRunner`, call `take_screenshot()` at any point, and screenshots are automatically saved to a timestamped folder.

## Quick Start

1. Create a test script in `godotbase/tests/` that extends `TestRunner`
2. Run it with `./run_test.sh tests/your_test.gd`
3. Screenshots appear in `screenshot/{YYYYMMDD_HHMMSS}/`

## Writing a Test Script

Create a `.gd` file under `godotbase/tests/` that extends `TestRunner` and overrides `_run_test()`:

```gdscript
extends TestRunner

func _run_test() -> void:
    var scene: Node = load_test_scene("res://scenes/main.tscn")
    await wait_frames(10)
    await take_screenshot("initial_state")

    var button: Button = scene.get_node("UI/StartButton") as Button
    button.pressed.emit()
    await wait_frames(5)
    await take_screenshot("after_start")

    finish()
```

## TestRunner API

### load_test_scene(scene_path: String) -> Node

Loads a PackedScene and adds it to the root viewport. Returns the instantiated node.

```gdscript
var scene: Node = load_test_scene("res://scenes/main.tscn")
```

### wait_frames(count: int) -> void

Waits for the specified number of rendered frames. Use this to let animations play, physics settle, or UI update before taking a screenshot.

```gdscript
await wait_frames(10)
```

### take_screenshot(label: String) -> void

Captures the current viewport and saves it as `{screenshot_dir}/{label}.png`. The label becomes the filename.

```gdscript
await take_screenshot("my_screenshot")
```

### finish(exit_code: int = 0) -> void

Ends the test. Always call this at the end of `_run_test()`. Pass a non-zero exit code to indicate test failure.

```gdscript
finish()       # success
finish(1)      # failure
```

## Running Tests

```bash
./run_test.sh tests/your_test.gd
```

Optional arguments (passed after the script path):

| Argument | Default | Description |
|----------|---------|-------------|
| `--width` | `1280` | Viewport width in pixels |
| `--height` | `720` | Viewport height in pixels |

Example with custom resolution:

```bash
./run_test.sh tests/your_test.gd --width 1920 --height 1080
```

## Output

Screenshots are saved to a timestamped folder under `screenshot/` at the project root:

```
screenshot/
└── 20260309_143022/
    ├── initial_state.png
    └── after_start.png
```

The shell script prints the screenshot folder path on completion.

## Important Notes

- Test scripts replace the main scene loop, but project autoloads (EnvironmentRuntime, EventSystem, etc.) still load. You can access game systems if needed, but test logic should primarily focus on loading scenes and taking screenshots.
- Scene paths use Godot's `res://` format (e.g., `res://scenes/main.tscn`).
- Always call `finish()` at the end of `_run_test()` to properly exit.
- Use `await` before `wait_frames()` and `take_screenshot()` since they are coroutines.
- `load_test_scene()` is synchronous — do NOT use `await` with it.
- The `take_screenshot()` label must be a valid filename (no slashes or special characters).

## Example

See `godotbase/tests/example_test.gd` for a minimal working example.
