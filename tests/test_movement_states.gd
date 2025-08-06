extends Node

## Test script to verify DirectionalSprite3D movement state recognition
## This test verifies that all valid movement states are properly recognized

func _ready():
	print("=== DirectionalSprite3D Movement States Test ===")

	# Create a test DirectionalSprite3D instance
	var sprite_3d = DirectionalSprite3D.new()

	# Create a mock target node with moving_state property
	var mock_target = Node.new()
	mock_target.set_script(preload("res://tests/mock_entity_with_states.gd"))

	# Add the mock target as a child so DirectionalSprite3D can find it
	add_child(mock_target)
	add_child(sprite_3d)
	sprite_3d.target_node_path = sprite_3d.get_path_to(mock_target)
	
	# Force the sprite to detect the target and its properties
	sprite_3d._get_target_node()
	
	print("\n--- Testing Movement State Recognition ---")
	
	# Test 1: "idle" state should return 0
	mock_target.moving_state = "idle"
	var idle_state = sprite_3d._get_current_sprite_state(mock_target)
	_assert_state("idle", idle_state, 0)
	
	# Test 2: "run" state should return 1
	mock_target.moving_state = "run"
	var run_state = sprite_3d._get_current_sprite_state(mock_target)
	_assert_state("run", run_state, 1)
	
	# Test 3: "moving" state should return 1
	mock_target.moving_state = "moving"
	var moving_state = sprite_3d._get_current_sprite_state(mock_target)
	_assert_state("moving", moving_state, 1)
	
	# Test 4: "move" state should return 1 (this was the fix)
	mock_target.moving_state = "move"
	var move_state = sprite_3d._get_current_sprite_state(mock_target)
	_assert_state("move", move_state, 1)
	
	# Test 5: Unknown state should return 0 (idle fallback)
	mock_target.moving_state = "unknown"
	var unknown_state = sprite_3d._get_current_sprite_state(mock_target)
	_assert_state("unknown", unknown_state, 0)
	
	print("\n=== Test Complete ===")
	
	# Clean up
	remove_child(sprite_3d)
	remove_child(mock_target)
	sprite_3d.queue_free()
	mock_target.queue_free()


func _assert_state(state_name: String, actual: int, expected: int):
	if actual == expected:
		print("✅ PASS: '%s' state correctly returns %d" % [state_name, expected])
	else:
		print("❌ FAIL: '%s' state returned %d, expected %d" % [state_name, actual, expected])
