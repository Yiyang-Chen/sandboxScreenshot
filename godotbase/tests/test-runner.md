# Test Runner - Headless Screenshot Testing

Automated testing framework for capturing screenshots of Godot scenes in a headless environment. Agents write GDScript test files that extend `TestRunner`, call `take_screenshot()` at any point, and screenshots are automatically saved to a timestamped folder.

## Quick Start

1. Create a test script in `godotbase/tests/` that extends `TestRunner`
2. Run it with `./godotbase/tests/framework/run_test.sh your_test.gd`
3. Results appear in `godotbase/tests/test_results/{YYYYMMDD_HHMMSS}/`

## Writing a Test Script

Create a `.gd` file under `godotbase/tests/` that extends `TestRunner` and overrides `_run_test()`:

```gdscript
extends TestRunner

func _run_test() -> void:
    test_log("Loading main scene")
    var scene: Node = load_test_scene("res://scenes/main.tscn")
    await wait_frames(10)
    await take_screenshot("initial_state")

    var button: Button = scene.get_node("UI/StartButton") as Button
    button.pressed.emit()
    test_log("Clicked start button")
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

### test_log(message: String) -> void

Writes a message to both the terminal and `test.log` in the screenshot folder. Use this instead of `print()` to keep a clean, persistent log of test actions.

```gdscript
test_log("Button clicked, waiting for animation")
```

### finish(exit_code: int = 0) -> void

Ends the test. Always call this at the end of `_run_test()`. Pass a non-zero exit code to indicate test failure.

```gdscript
finish()       # success
finish(1)      # failure
```

## Running Tests

```bash
./godotbase/tests/framework/run_test.sh your_test.gd
```

Optional arguments (passed after the script path):

| Argument | Default | Description |
|----------|---------|-------------|
| `--width` | `1280` | Viewport width in pixels |
| `--height` | `720` | Viewport height in pixels |

Example with custom resolution:

```bash
./godotbase/tests/framework/run_test.sh your_test.gd --width 1920 --height 1080
```

## Output

All output is saved to a timestamped folder under `godotbase/tests/test_results/`:

```
godotbase/tests/test_results/
└── 20260309_143022/
    ├── initial_state.png
    ├── after_start.png
    ├── test.log              # Agent log messages (from test_log() calls)
    └── output.log            # Full Godot stdout/stderr
```

- `test.log` — Only messages written via `test_log()`. Clean and readable.
- `output.log` — Complete Godot output including engine warnings. Useful for debugging.

## File Structure

```
godotbase/tests/
├── test-runner.md              # This doc
├── framework/                  # Core framework (do not modify)
│   ├── test_runner.gd          # TestRunner base class
│   ├── run_test.sh             # Shell entry point
│   └── example_test.gd         # Example test
│
├── test_results/               # Output folder (auto-created, gitignored)
│   └── 20260309_143022/
│       ├── *.png
│       ├── test.log
│       └── output.log
│
├── test_my_scene.gd            # Your test scripts go here
└── ...
```

## Important Notes

- Test scripts replace the main scene loop, but project autoloads (EnvironmentRuntime, EventSystem, etc.) still load. You can access game systems if needed, but test logic should primarily focus on loading scenes and taking screenshots.
- Scene paths use Godot's `res://` format (e.g., `res://scenes/main.tscn`).
- Always call `finish()` at the end of `_run_test()` to properly exit.
- Use `await` before `wait_frames()` and `take_screenshot()` since they are coroutines.
- `load_test_scene()` is synchronous — do NOT use `await` with it.
- The `take_screenshot()` label must be a valid filename (no slashes or special characters).

## Example

See `godotbase/tests/framework/example_test.gd` for a minimal working example.
