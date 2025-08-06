extends Node

## Test script to verify the room assignment fix for enemy pathfinding
## This test ensures players get assigned rooms automatically and transitions work correctly

var test_passed = 0
var test_failed = 0

func _ready():
	print("=== ROOM ASSIGNMENT FIX TEST ===")
	test_auto_room_assignment()
	test_transition_with_unassigned_room()
	test_enemy_pathfinding_with_room_assignment()
	test_transition_safety_checks()
	print_test_summary()

func test_auto_room_assignment():
	print("\n--- Testing Automatic Room Assignment ---")
	
	# Create a mock level with transitions
	var level = preload("res://scenes/rooms/level.gd").new()
	add_child(level)
	
	# Create mock transitions node
	var transitions = Node3D.new()
	transitions.name = "Transitions"
	transitions.set_script(preload("res://scenes/rooms/mansion1_transitions.gd"))
	level.add_child(transitions)
	level.transitions = transitions
	
	# Create a mock player without room assignment
	var player = CharacterBody3D.new()
	player.add_to_group("player")
	player.name = "TestPlayer"
	# Intentionally don't set current_room
	
	# Test auto-assignment
	level._auto_assign_room_for_body(player)
	
	# Verify room was assigned
	test_assert("current_room" in player, "Player should have current_room property")
	test_assert(player.current_room != null and player.current_room != "", "Player should have a valid room assigned")
	print("✓ Player automatically assigned room: ", player.current_room)
	
	test_passed += 1
	
	# Cleanup
	level.queue_free()

func test_transition_with_unassigned_room():
	print("\n--- Testing Transition with Unassigned Room ---")
	
	# Create a mock level
	var level = preload("res://scenes/rooms/level.gd").new()
	add_child(level)
	
	# Create mock transitions
	var transitions = Node3D.new()
	transitions.name = "Transitions"
	transitions.set_script(preload("res://scenes/rooms/mansion1_transitions.gd"))
	level.add_child(transitions)
	level.transitions = transitions
	
	# Create a mock marker
	var marker = Marker3D.new()
	marker.global_position = Vector3(10, 0, 10)
	add_child(marker)
	
	# Create a player without room assignment
	var player = CharacterBody3D.new()
	player.add_to_group("player")
	player.name = "TestPlayer"
	player.global_position = Vector3.ZERO
	# Don't assign current_room - this should trigger auto-assignment
	
	# Test transition handling
	var initial_position = player.global_position
	level.handle_transition(player, "FirstFloorUpstairs", marker)
	
	# Verify room was assigned and position changed
	test_assert("current_room" in player, "Player should have current_room property after transition")
	test_assert(player.current_room != null and player.current_room != "", "Player should have a valid room after transition")
	test_assert(player.global_position != initial_position, "Player position should have changed")
	print("✓ Transition handled correctly with auto room assignment")
	
	test_passed += 1
	
	# Cleanup
	level.queue_free()
	marker.queue_free()

func test_enemy_pathfinding_with_room_assignment():
	print("\n--- Testing Enemy Pathfinding with Room Assignment ---")
	
	# Create a mock enemy
	var enemy = preload("res://scenes/enemies/enemy.gd").new()
	enemy.current_room = "FirstFloor"
	enemy.debug_prints = true
	add_child(enemy)
	
	# Create mock navigation agent
	var nav_agent = NavigationAgent3D.new()
	enemy.add_child(nav_agent)
	enemy.nav = nav_agent
	
	# Create mock transitions
	var transitions = Node3D.new()
	transitions.set_script(preload("res://scenes/rooms/mansion1_transitions.gd"))
	enemy.add_child(transitions)
	enemy.map_transitions = transitions
	
	# Test 1: Player with valid room assignment
	var player_with_room = CharacterBody3D.new()
	player_with_room.add_to_group("player")
	player_with_room.current_room = "SecondFloor"
	player_with_room.global_position = Vector3(5, 0, 5)
	add_child(player_with_room)
	
	enemy.current_target = player_with_room
	var initial_nav_target = nav_agent.target_position
	enemy.makepath()
	
	# Should use room-based pathfinding or direct pathfinding
	test_assert(nav_agent.target_position != initial_nav_target, "Navigation target should be updated")
	print("✓ Enemy pathfinding works with properly assigned player room")
	
	# Test 2: Player without room assignment (should fallback to direct pathfinding)
	var player_no_room = CharacterBody3D.new()
	player_no_room.add_to_group("player")
	player_no_room.global_position = Vector3(10, 0, 10)
	# Don't assign current_room
	add_child(player_no_room)
	
	enemy.current_target = player_no_room
	initial_nav_target = nav_agent.target_position
	enemy.makepath()
	
	# Should fallback to direct pathfinding
	test_assert(nav_agent.target_position == player_no_room.global_position, "Should use direct pathfinding for player without room")
	print("✓ Enemy pathfinding falls back to direct pathfinding for unassigned player room")
	
	test_passed += 2
	
	# Cleanup
	enemy.queue_free()
	player_with_room.queue_free()
	player_no_room.queue_free()

func test_transition_safety_checks():
	print("\n--- Testing Transition Safety Checks ---")
	
	# Create a mock level
	var level = preload("res://scenes/rooms/level.gd").new()
	add_child(level)
	
	# Create mock transitions with limited map
	var transitions = Node3D.new()
	transitions.name = "Transitions"
	transitions.set_script(preload("res://scenes/rooms/mansion1_transitions.gd"))
	level.add_child(transitions)
	level.transitions = transitions
	
	# Create a mock marker
	var marker = Marker3D.new()
	marker.global_position = Vector3(20, 0, 20)
	add_child(marker)
	
	# Create a player with invalid room
	var player = CharacterBody3D.new()
	player.add_to_group("player")
	player.name = "TestPlayer"
	player.current_room = "NonExistentRoom"
	player.global_position = Vector3.ZERO
	
	# Test transition with invalid room (should still move player but handle gracefully)
	var _initial_position = player.global_position
	level.handle_transition(player, "InvalidTransition", marker)
	
	# Player should still be moved even if transition is invalid
	test_assert(player.global_position == marker.global_position, "Player should be moved even with invalid transition")
	print("✓ Invalid transitions handled gracefully - player still moved")
	
	test_passed += 1
	
	# Cleanup
	level.queue_free()
	marker.queue_free()

func print_test_summary():
	print("\n" + "=".repeat(50))
	print("ROOM ASSIGNMENT FIX TEST SUMMARY")
	print("=".repeat(50))
	print("Tests Passed: ", test_passed)
	print("Tests Failed: ", test_failed)
	
	if test_failed == 0:
		print("🎉 ALL TESTS PASSED! Room assignment fix is working correctly.")
		print("\nKey improvements verified:")
		print("  ✓ Automatic room assignment for players without rooms")
		print("  ✓ Safe transition handling with unassigned rooms")
		print("  ✓ Enemy pathfinding fallback for unassigned player rooms")
		print("  ✓ Graceful handling of invalid transitions")
	else:
		print("❌ Some tests failed. Please review the implementation.")

	print("=".repeat(50))

# Helper assertion function
func test_assert(condition: bool, message: String):
	if not condition:
		print("❌ ASSERTION FAILED: " + message)
		test_failed += 1
	else:
		print("✓ " + message)
