extends TestRunner

## Example test script demonstrating the TestRunner API.
## Run with: ./godotbase/tests/framework/run_test.sh framework/example_test.gd

func _run_test() -> void:
	test_log("Loading main scene...")
	var scene: Node = load_test_scene("res://scenes/main.tscn")
	await wait_frames(10)
	test_log("Scene loaded, taking screenshot")
	await take_screenshot("main_scene")

	test_log("Test complete")
	finish()
