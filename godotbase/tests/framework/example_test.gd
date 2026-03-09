extends TestRunner

## Example test script demonstrating the TestRunner API.
## Run with: ./godotbase/tests/framework/run_test.sh framework/example_test.gd

func _run_test() -> void:
	var scene: Node = load_test_scene("res://scenes/main.tscn")
	await wait_frames(10)
	await take_screenshot("main_scene")

	finish()
