@tool
extends EditorScript

## Validation script for DirectionalSprite3D directional modes
## Run this script in the editor to validate the direction calculations

func _run():
	print("=== DirectionalSprite3D Direction Mode Validation ===")
	
	# Test direction calculations for different modes
	_test_three_directions()
	_test_four_directions()
	_test_eight_directions()
	
	print("=== Validation Complete ===")

func _test_three_directions():
	print("\n--- Testing THREE_DIRECTIONS mode ---")
	var directions = ["front", "side", "back"]
	print("Expected directions: ", directions)
	
	# Test various camera angles
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.THREE_DIRECTIONS, Vector3(0, 0, -1), "front")
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.THREE_DIRECTIONS, Vector3(0, 0, 1), "back")
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.THREE_DIRECTIONS, Vector3(1, 0, 0), "side")
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.THREE_DIRECTIONS, Vector3(-1, 0, 0), "side")

func _test_four_directions():
	print("\n--- Testing FOUR_DIRECTIONS mode ---")
	var directions = ["front", "left", "right", "back"]
	print("Expected directions: ", directions)
	
	# Test various camera angles
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.FOUR_DIRECTIONS, Vector3(0, 0, -1), "front")
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.FOUR_DIRECTIONS, Vector3(0, 0, 1), "back")
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.FOUR_DIRECTIONS, Vector3(1, 0, 0), "right")
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.FOUR_DIRECTIONS, Vector3(-1, 0, 0), "left")

func _test_eight_directions():
	print("\n--- Testing EIGHT_DIRECTIONS mode ---")
	var directions = ["front", "left", "right", "back", "front_left", "front_right", "back_left", "back_right"]
	print("Expected directions: ", directions)
	
	# Test 8 cardinal and diagonal directions
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.EIGHT_DIRECTIONS, Vector3(0, 0, -1), "front")
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.EIGHT_DIRECTIONS, Vector3(-0.707, 0, -0.707), "front_left")
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.EIGHT_DIRECTIONS, Vector3(-1, 0, 0), "left")
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.EIGHT_DIRECTIONS, Vector3(-0.707, 0, 0.707), "back_left")
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.EIGHT_DIRECTIONS, Vector3(0, 0, 1), "back")
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.EIGHT_DIRECTIONS, Vector3(0.707, 0, 0.707), "back_right")
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.EIGHT_DIRECTIONS, Vector3(1, 0, 0), "right")
	_test_direction_calculation(DirectionalSprite3D.DirectionMode.EIGHT_DIRECTIONS, Vector3(0.707, 0, -0.707), "front_right")

func _test_direction_calculation(mode: DirectionalSprite3D.DirectionMode, camera_direction: Vector3, expected: String):
	# Create a mock DirectionalSprite3D for testing
	var sprite = DirectionalSprite3D.new()
	sprite.direction_mode = mode
	
	# Create mock camera and target
	var camera = Camera3D.new()
	var target = Node3D.new()
	
	# Position camera relative to target
	target.global_position = Vector3.ZERO
	camera.global_position = camera_direction * 5.0  # 5 units away
	
	# Calculate direction
	var result = sprite._calculate_camera_direction(camera, target)
	
	# Print result
	var status = "✓" if result == expected else "✗"
	print("%s Camera at %s -> Expected: %s, Got: %s" % [status, camera_direction, expected, result])
	
	# Clean up
	sprite.queue_free()
	camera.queue_free()
	target.queue_free()
