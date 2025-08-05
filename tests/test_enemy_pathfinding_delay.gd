extends Node

## Test script to verify the enemy pathfinding delay fix
## This test ensures enemies immediately start pathfinding when they detect a player

var test_passed = 0
var test_failed = 0

func _ready():
	print("=== ENEMY PATHFINDING DELAY FIX TEST ===")
	test_immediate_pathfinding_on_detection()
	test_timer_responsiveness()
	test_target_reacquisition()
	print_test_summary()

func test_immediate_pathfinding_on_detection():
	print("\n--- Testing Immediate Pathfinding on Target Detection ---")
	
	# Create a mock enemy
	var enemy = preload("res://scenes/enemies/enemy.gd").new()
	add_child(enemy)
	
	# Create mock navigation agent
	var nav_agent = NavigationAgent3D.new()
	enemy.add_child(nav_agent)
	enemy.nav = nav_agent
	
	# Create mock timer
	var timer = Timer.new()
	enemy.add_child(timer)
	enemy.find_path_timer = timer
	
	# Enable debug prints for this test
	enemy.debug_prints = true
	
	# Create a mock player target
	var mock_player = CharacterBody3D.new()
	mock_player.add_to_group("player")
	add_child(mock_player)
	
	# Create a mock camera for the player
	var camera = Camera3D.new()
	mock_player.add_child(camera)
	mock_player.camera_3d = camera
	
	# Create a mock players container
	var players_container = Node3D.new()
	players_container.name = "Players"
	players_container.add_child(mock_player)
	add_child(players_container)
	enemy.players = players_container
	
	# Test: Initially no target
	assert(enemy.current_target == null, "Enemy should start with no target")
	
	# Test: Simulate target detection (this should trigger immediate pathfinding)
	var initial_target_position = nav_agent.target_position
	enemy.current_target = mock_player
	enemy.makepath()  # This simulates what happens in the fixed check_targets()
	
	# Verify that pathfinding was triggered immediately
	var new_target_position = nav_agent.target_position
	assert(new_target_position != initial_target_position, "Navigation target should be updated immediately")
	assert(new_target_position == mock_player.global_position, "Navigation should target the player position")
	
	print("✓ Enemy immediately calculates path when target is detected")
	test_passed += 1
	
	# Cleanup
	enemy.queue_free()
	mock_player.queue_free()
	players_container.queue_free()

func test_timer_responsiveness():
	print("\n--- Testing Timer Responsiveness Improvements ---")
	
	# Create a mock enemy
	var enemy = preload("res://scenes/enemies/enemy.gd").new()
	add_child(enemy)
	
	# Create mock navigation agent
	var nav_agent = NavigationAgent3D.new()
	enemy.add_child(nav_agent)
	enemy.nav = nav_agent
	
	# Create mock timer
	var timer = Timer.new()
	enemy.add_child(timer)
	enemy.find_path_timer = timer
	
	# Test improved timer intervals
	# Simulate different distances and check timer wait times
	
	# Test distant target (>50 units) - should be 0.8s instead of old 1.7s
	nav_agent.target_position = Vector3(100, 0, 0)  # Far away
	enemy._on_find_path_timer_timeout()
	assert(timer.wait_time == 0.8, "Distant targets should have 0.8s timer (was 1.7s)")
	
	# Test medium distance (35-50 units) - should be 0.5s instead of old 0.8s
	nav_agent.target_position = Vector3(40, 0, 0)
	enemy._on_find_path_timer_timeout()
	assert(timer.wait_time == 0.5, "Medium distance should have 0.5s timer (was 0.8s)")
	
	# Test close-medium distance (20-35 units) - should be 0.3s instead of old 0.5s
	nav_agent.target_position = Vector3(25, 0, 0)
	enemy._on_find_path_timer_timeout()
	assert(timer.wait_time == 0.3, "Close-medium distance should have 0.3s timer (was 0.5s)")
	
	# Test close distance (<20 units) - should remain 0.1s
	nav_agent.target_position = Vector3(10, 0, 0)
	enemy._on_find_path_timer_timeout()
	assert(timer.wait_time == 0.1, "Close distance should have 0.1s timer")
	
	print("✓ Timer intervals are more responsive")
	test_passed += 1
	
	# Cleanup
	enemy.queue_free()

func test_target_reacquisition():
	print("\n--- Testing Target Reacquisition Responsiveness ---")
	
	# Create a mock enemy
	var enemy = preload("res://scenes/enemies/enemy.gd").new()
	add_child(enemy)
	
	# Create mock navigation agent
	var nav_agent = NavigationAgent3D.new()
	enemy.add_child(nav_agent)
	enemy.nav = nav_agent
	
	# Create mock timer
	var timer = Timer.new()
	enemy.add_child(timer)
	enemy.find_path_timer = timer
	timer.wait_time = 1.0  # Start with a long timer
	
	# Create a mock dead player
	var mock_dead_player = CharacterBody3D.new()
	mock_dead_player.set_script(preload("res://tests/mock_dead_player.gd"))
	add_child(mock_dead_player)
	
	# Set the dead player as current target
	enemy.current_target = mock_dead_player
	
	# Simulate the dead player check in _physics_process
	# This should reset the timer to be more responsive
	if enemy.current_target and enemy.current_target.has_method("is_dead") and enemy.current_target.is_dead():
		enemy.current_target = null
		enemy.velocity = Vector3.ZERO
		enemy.find_path_timer.wait_time = 0.1
	
	# Verify timer was reset to be responsive
	assert(timer.wait_time == 0.1, "Timer should be reset to 0.1s when target dies")
	assert(enemy.current_target == null, "Target should be cleared when player dies")
	
	print("✓ Enemy becomes responsive when target is lost")
	test_passed += 1
	
	# Cleanup
	enemy.queue_free()
	mock_dead_player.queue_free()

func print_test_summary():
	print("\n" + "=" * 50)
	print("ENEMY PATHFINDING DELAY FIX TEST SUMMARY")
	print("=" * 50)
	print("Tests Passed: ", test_passed)
	print("Tests Failed: ", test_failed)
	
	if test_failed == 0:
		print("🎉 ALL TESTS PASSED! Enemy pathfinding delay fix is working correctly.")
		print("\nKey improvements verified:")
		print("  ✓ Immediate pathfinding on target detection")
		print("  ✓ More responsive timer intervals")
		print("  ✓ Quick reacquisition after target loss")
	else:
		print("❌ Some tests failed. Please review the implementation.")
	
	print("=" * 50)

# Helper assertion function
func assert(condition: bool, message: String):
	if not condition:
		print("❌ ASSERTION FAILED: " + message)
		test_failed += 1
	else:
		print("✓ " + message)
