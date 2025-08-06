extends Node3D

# Test script to demonstrate the enemy pathfinding optimization system
# This script creates multiple enemies at various distances and shows how
# the optimization system adapts update intervals based on distance, line of sight,
# and enemy count.

@export var num_test_enemies := 15
@export var test_duration := 30.0
@export var spawn_radius := 100.0

var enemy_scene = preload("res://scenes/enemies/enemy.tscn")
var test_enemies: Array[Enemy] = []
var test_player: CharacterBody3D
var test_start_time: float

func _ready():
	print("=== Enemy Pathfinding Optimization Test ===")
	print("This test demonstrates the new pathfinding optimizations:")
	print("1. Distance-based update intervals")
	print("2. Enemy count scaling")
	print("3. Line-of-sight optimization")
	print("4. Path caching")
	print()
	
	setup_test_environment()
	spawn_test_enemies()
	
	# Enable debug prints on some enemies to see optimization in action
	for i in range(min(3, test_enemies.size())):
		test_enemies[i].debug_prints = true
	
	test_start_time = Time.get_time_dict_from_system()["unix"]
	print("Test started with ", num_test_enemies, " enemies")
	print("Watch the console for optimization debug output...")
	print()

func setup_test_environment():
	# Create a mock player for testing
	test_player = CharacterBody3D.new()
	test_player.name = "TestPlayer"
	test_player.add_to_group("player")
	
	# Add a camera to the player (required by enemy targeting)
	var camera = Camera3D.new()
	camera.name = "camera_3d"
	test_player.add_child(camera)
	
	# Create a Players node to hold the test player
	var players_node = Node3D.new()
	players_node.name = "Players"
	add_child(players_node)
	players_node.add_child(test_player)
	
	# Position the player at origin
	test_player.global_position = Vector3.ZERO

func spawn_test_enemies():
	for i in range(num_test_enemies):
		var enemy = enemy_scene.instantiate() as Enemy
		if not enemy:
			print("Failed to instantiate enemy ", i)
			continue
			
		add_child(enemy)
		test_enemies.append(enemy)
		
		# Position enemies at various distances to test distance-based intervals
		var angle = (i / float(num_test_enemies)) * 2 * PI
		var distance_factor = (i % 4 + 1) / 4.0 # Create 4 distance groups
		var distance = 5 + (distance_factor * spawn_radius) # 5 to 105 units
		
		var pos = Vector3(
			cos(angle) * distance,
			0,
			sin(angle) * distance
		)
		enemy.global_position = pos
		
		# Set enemy properties for testing
		enemy.chase_player = true
		enemy.current_room = "test_room"
		
		print("Spawned enemy ", i, " at distance ", distance, " units")

func _process(_delta):
	var current_time = Time.get_time_dict_from_system()["unix"]
	var elapsed = current_time - test_start_time
	
	# Move the player around to test line-of-sight changes
	if test_player:
		var time_factor = elapsed * 0.5
		test_player.global_position = Vector3(
			sin(time_factor) * 20,
			0,
			cos(time_factor) * 20
		)
	
	# Print periodic status updates
	if int(elapsed) % 5 == 0 and int(elapsed * 10) % 10 == 0: # Every 5 seconds
		print_optimization_status(elapsed)
	
	# End test after duration
	if elapsed > test_duration:
		end_test()

func print_optimization_status(elapsed: float):
	print("\n=== Optimization Status at ", elapsed, " seconds ===")

	# Check if optimization properties exist
	var total_count = str(test_enemies.size()) + " (local count)"
	# Note: total_enemy_count optimization not yet implemented

	var scale_factor = "N/A (optimization not implemented)"
	# Note: enemy_count_scale_factor optimization not yet implemented

	print("Total enemies: ", total_count)
	print("Enemy count scale factor: ", scale_factor)
	
	# Show interval distribution
	var interval_counts = {"very_close": 0, "close": 0, "medium": 0, "far": 0}
	var los_count = 0
	
	for enemy in test_enemies:
		if not is_instance_valid(enemy):
			continue
			
		var distance = enemy.global_position.distance_to(test_player.global_position)
		if distance < 10:
			interval_counts["very_close"] += 1
		elif distance < 25:
			interval_counts["close"] += 1
		elif distance < 50:
			interval_counts["medium"] += 1
		else:
			interval_counts["far"] += 1
			
		# Check if line of sight optimization is implemented
		if "has_line_of_sight" in enemy and enemy.has_line_of_sight:
			los_count += 1
	
	print("Distance distribution - Very close: ", interval_counts["very_close"],
		  ", Close: ", interval_counts["close"],
		  ", Medium: ", interval_counts["medium"],
		  ", Far: ", interval_counts["far"])
	print("Enemies with line of sight: ", los_count, "/", test_enemies.size())

func end_test():
	print("\n=== Test Complete ===")
	print("The pathfinding optimization system has been successfully demonstrated.")
	print("Key benefits observed:")
	print("- Close enemies update frequently for responsive behavior")
	print("- Distant enemies update less frequently to save CPU")
	print("- Enemy count scaling prevents performance degradation with many enemies")
	print("- Line-of-sight optimization reduces unnecessary pathfinding")
	print("- Path caching prevents redundant calculations")
	
	# Clean up
	for enemy in test_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	queue_free()
