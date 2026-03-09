extends TestRunner

## Example test script demonstrating the TestRunner API.
## Run with: ./run_test.sh tests/example_test.gd

func _run_test() -> void:
	var scene: Node = await load_test_scene("res://scenes/main.tscn")
	await wait_frames(10)
	take_screenshot("main_scene")

	finish()
