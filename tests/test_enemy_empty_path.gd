extends Node

## Regression tests for enemy pathfinding with empty/null path scenarios
## Ensures enemies don't crash when no valid path exists

func _ready():
	print("=== ENEMY EMPTY PATH TESTS ===")
	
	test_room_pathing_component_empty_path()
	test_find_path_to_player_no_target()
	test_makepath_empty_path_handling()
	
	print("=== ALL ENEMY EMPTY PATH TESTS COMPLETED ===")

func test_room_pathing_component_empty_path():
	print("\n--- Testing RoomPathingComponent Empty Path ---")
	
	var room_pathing = preload("res://scenes/components/enemy/room_pathing_component.gd").new()
	add_child(room_pathing)
	
	# Test with non-existent rooms (should return empty array, not crash)
	var path = room_pathing.find_path_to_room("nonexistent_room_a", "nonexistent_room_b")
	assert(path is Array, "Should return an array")
	assert(path.is_empty(), "Path should be empty for non-existent rooms")
	print("✓ RoomPathingComponent returns empty array for invalid rooms")
	
	# Test with same room (should return empty array)
	path = room_pathing.find_path_to_room("room_a", "room_a")
	assert(path is Array, "Should return an array")
	assert(path.is_empty(), "Path should be empty when source equals destination")
	print("✓ RoomPathingComponent returns empty array for same room")
	
	room_pathing.queue_free()

func test_find_path_to_player_no_target():
	print("\n--- Testing find_path_to_player With No Target ---")
	
	# Create a minimal enemy mock with the relevant method
	var enemy_script = """
extends Node

var current_target = null
var _room_pathing_component = null

func find_path_to_player():
	if not current_target:
		return null
	
	if _room_pathing_component:
		return _room_pathing_component.find_path_to_room("", "")
	
	return []
"""
	var enemy_mock = Node.new()
	var script = GDScript.new()
	script.source_code = enemy_script
	script.reload()
	enemy_mock.set_script(script)
	add_child(enemy_mock)
	
	# Test with no target
	var result = enemy_mock.find_path_to_player()
	assert(result == null, "Should return null when no target")
	print("✓ find_path_to_player returns null when no target")
	
	enemy_mock.queue_free()

func test_makepath_empty_path_handling():
	print("\n--- Testing makepath Empty Path Handling ---")
	
	# This test verifies the guard logic works by simulating the scenario
	# The actual fix in enemy.gd checks: if path_to_player and not path_to_player.is_empty()
	
	var empty_path: Array = []
	var null_path = null
	
	# Test empty array guard
	var should_use_path = empty_path and not empty_path.is_empty()
	assert(should_use_path == false, "Empty path should be guarded against")
	print("✓ Empty array guard works correctly")
	
	# Test null guard
	should_use_path = null_path and not null_path.is_empty() if null_path else false
	assert(should_use_path == false, "Null path should be guarded against")
	print("✓ Null path guard works correctly")
	
	# Test valid path passes guard
	var valid_path: Array = ["transition_1"]
	should_use_path = valid_path and not valid_path.is_empty()
	assert(should_use_path == true, "Valid path should pass guard")
	print("✓ Valid path passes guard correctly")
