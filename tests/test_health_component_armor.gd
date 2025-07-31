extends Node

## Armor integration and edge case tests for the HealthComponent system
## Tests overheal functionality, multiple death calls, armor integration, and utility methods

# Signal tracking helper class
class SignalTracker:
	var signals_received = {}
	var last_signal_args = {}
	
	func track_signal(signal_name: String, args: Array = []):
		if not signals_received.has(signal_name):
			signals_received[signal_name] = 0
		signals_received[signal_name] += 1
		last_signal_args[signal_name] = args
	
	func was_signal_emitted(signal_name: String) -> bool:
		return signals_received.has(signal_name) and signals_received[signal_name] > 0
	
	func get_signal_count(signal_name: String) -> int:
		return signals_received.get(signal_name, 0)
	
	func get_last_args(signal_name: String) -> Array:
		return last_signal_args.get(signal_name, [])
	
	func reset():
		signals_received.clear()
		last_signal_args.clear()

var signal_tracker: SignalTracker

func _ready():
	print("=== HEALTH COMPONENT ARMOR & EDGE CASE TESTS ===")
	signal_tracker = SignalTracker.new()
	
	# Edge Cases Tests
	test_zero_and_negative_damage()
	test_zero_and_negative_healing()
	test_overheal_functionality()
	test_multiple_death_calls()
	
	# Armor Integration Tests
	test_armor_integration_basic()
	test_armor_integration_no_armor()
	test_armor_integration_full_absorption()
	test_armor_integration_doom_green()
	test_armor_integration_doom_blue()
	
	# Utility Methods Tests
	test_utility_methods()
	test_convenience_methods()
	
	print("=== ALL ARMOR & EDGE CASE TESTS COMPLETED ===")

func test_zero_and_negative_damage():
	print("\n--- Testing Zero and Negative Damage ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 100
	
	# Test zero damage
	var result = health_comp.take_damage(0)
	assert(result == false, "Zero damage should return false")
	assert(health_comp.current_health == 100, "Health should not change with zero damage")
	
	# Test negative damage
	result = health_comp.take_damage(-10)
	assert(result == false, "Negative damage should return false")
	assert(health_comp.current_health == 100, "Health should not change with negative damage")
	print("✓ Zero and negative damage handling works")
	
	health_comp.queue_free()

func test_zero_and_negative_healing():
	print("\n--- Testing Zero and Negative Healing ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 50
	
	# Test zero healing
	var result = health_comp.heal(0)
	assert(result == false, "Zero healing should return false")
	assert(health_comp.current_health == 50, "Health should not change with zero healing")
	
	# Test negative healing
	result = health_comp.heal(-10)
	assert(result == false, "Negative healing should return false")
	assert(health_comp.current_health == 50, "Health should not change with negative healing")
	print("✓ Zero and negative healing handling works")
	
	health_comp.queue_free()

func test_overheal_functionality():
	print("\n--- Testing Overheal Functionality ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.max_health = 100
	health_comp.current_health = 100
	health_comp.can_overheal = true
	health_comp.overheal_limit = 150
	
	# Test overhealing
	var result = health_comp.heal(30)
	assert(result == true, "Overhealing should be allowed when can_overheal is true")
	assert(health_comp.current_health == 130, "Health should exceed max_health with overheal")
	
	# Test overheal limit
	result = health_comp.heal(50)
	assert(result == true, "Should be able to heal up to overheal limit")
	assert(health_comp.current_health == 150, "Health should be clamped to overheal_limit")
	
	# Test healing beyond overheal limit
	result = health_comp.heal(10)
	assert(result == false, "Should not be able to heal beyond overheal limit")
	assert(health_comp.current_health == 150, "Health should remain at overheal limit")
	
	# Test is_at_full_health with overheal
	assert(health_comp.is_at_full_health() == true, "Should be considered at full health when overhealed")
	print("✓ Overheal functionality works correctly")
	
	health_comp.queue_free()

func test_multiple_death_calls():
	print("\n--- Testing Multiple Death Calls ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 1
	
	# Connect signals to track multiple emissions
	signal_tracker.reset()
	health_comp.died.connect(func(): signal_tracker.track_signal("died"))
	health_comp.health_depleted.connect(func(): signal_tracker.track_signal("health_depleted"))
	
	# First death
	health_comp.take_damage(1)
	assert(health_comp.is_dead == true, "Should be dead after first lethal damage")
	assert(signal_tracker.get_signal_count("died") == 1, "died signal should be emitted once")
	
	# Attempt second death
	health_comp.take_damage(10)
	assert(signal_tracker.get_signal_count("died") == 1, "died signal should not be emitted again")
	
	# Call kill method on already dead entity
	health_comp.kill()
	assert(signal_tracker.get_signal_count("died") == 1, "died signal should still only be emitted once")
	
	# Call _handle_death directly
	health_comp._handle_death()
	assert(signal_tracker.get_signal_count("died") == 1, "died signal should still only be emitted once")
	print("✓ Multiple death calls handled correctly")
	
	health_comp.queue_free()

func test_armor_integration_basic():
	print("\n--- Testing Basic Armor Integration ---")
	
	# Create a parent node to hold both components
	var parent_node = Node.new()
	add_child(parent_node)
	
	# Create health and armor components
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	var armor_comp = preload("res://scenes/components/armor/armor_component.gd").new()
	
	parent_node.add_child(health_comp)
	parent_node.add_child(armor_comp)
	
	# Set up components
	health_comp.current_health = 100
	armor_comp.current_armor = 50
	armor_comp.damage_reduction_type = 2 # ABSORPTION type
	
	# Test damage with armor
	var result = health_comp.take_damage(30)
	assert(result == true, "Damage should be applied")
	assert(health_comp.current_health == 100, "Health should not change with full absorption")
	assert(armor_comp.current_armor == 20, "Armor should absorb the damage")
	print("✓ Basic armor integration works")
	
	parent_node.queue_free()

func test_armor_integration_no_armor():
	print("\n--- Testing Armor Integration with No Armor ---")
	
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 100
	
	# Test damage without armor component
	var result = health_comp.take_damage(25)
	assert(result == true, "Damage should be applied")
	assert(health_comp.current_health == 75, "Full damage should be applied without armor")
	print("✓ No armor integration works correctly")
	
	health_comp.queue_free()

func test_armor_integration_full_absorption():
	print("\n--- Testing Armor Integration with Full Absorption ---")
	
	# Create a parent node to hold both components
	var parent_node = Node.new()
	add_child(parent_node)
	
	# Create health and armor components
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	var armor_comp = preload("res://scenes/components/armor/armor_component.gd").new()
	
	parent_node.add_child(health_comp)
	parent_node.add_child(armor_comp)
	
	# Set up components for full absorption
	health_comp.current_health = 100
	armor_comp.current_armor = 100
	armor_comp.damage_reduction_type = 2 # ABSORPTION type
	
	# Test damage that should be fully absorbed
	var result = health_comp.take_damage(50)
	assert(result == true, "Damage should be processed")
	assert(health_comp.current_health == 100, "Health should remain unchanged")
	assert(armor_comp.current_armor == 50, "Armor should absorb all damage")
	
	# Test damage that exceeds armor
	result = health_comp.take_damage(75)
	assert(result == true, "Damage should be processed")
	assert(health_comp.current_health == 75, "Health should take remaining damage")
	assert(armor_comp.current_armor == 0, "Armor should be depleted")
	print("✓ Full absorption armor integration works")
	
	parent_node.queue_free()

func test_armor_integration_doom_green():
	print("\n--- Testing Armor Integration with DOOM Green ---")
	
	# Create a parent node to hold both components
	var parent_node = Node.new()
	add_child(parent_node)
	
	# Create health and armor components
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	var armor_comp = preload("res://scenes/components/armor/armor_component.gd").new()
	
	parent_node.add_child(health_comp)
	parent_node.add_child(armor_comp)
	
	# Set up components for DOOM Green armor
	health_comp.current_health = 100
	armor_comp.current_armor = 50
	armor_comp.damage_reduction_type = 0 # DOOM_GREEN type
	
	# Test DOOM Green mechanics (1/3 absorbed, 2/3 to health)
	var result = health_comp.take_damage(30)
	assert(result == true, "Damage should be processed")
	
	# Expected: 20 damage to health (2/3 of 30), 5 armor lost (1/3 of 30, divided by 2)
	var expected_health = 100 - int(30 * 2.0 / 3.0) # 80
	var expected_armor = 50 - int((30 / 3.0) / 2.0) # 45
	
	assert(health_comp.current_health == expected_health, "Health should take 2/3 of damage")
	assert(armor_comp.current_armor == expected_armor, "Armor should lose correct amount")
	print("✓ DOOM Green armor integration works")
	
	parent_node.queue_free()

func test_armor_integration_doom_blue():
	print("\n--- Testing Armor Integration with DOOM Blue ---")

	# Create a parent node to hold both components
	var parent_node = Node.new()
	add_child(parent_node)

	# Create health and armor components
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	var armor_comp = preload("res://scenes/components/armor/armor_component.gd").new()

	parent_node.add_child(health_comp)
	parent_node.add_child(armor_comp)

	# Set up components for DOOM Blue armor
	health_comp.current_health = 100
	armor_comp.current_armor = 50
	armor_comp.damage_reduction_type = 1 # DOOM_BLUE type

	# Test DOOM Blue mechanics (1/2 absorbed, 1/2 to health)
	var result = health_comp.take_damage(40)
	assert(result == true, "Damage should be processed")

	# Expected: 20 damage to health (1/2 of 40), 10 armor lost (1/2 of 40, divided by 2)
	var expected_health = 100 - int(40 / 2.0) # 80
	var expected_armor = 50 - int((40 / 2.0) / 2.0) # 40

	assert(health_comp.current_health == expected_health, "Health should take 1/2 of damage")
	assert(armor_comp.current_armor == expected_armor, "Armor should lose correct amount")
	print("✓ DOOM Blue armor integration works")

	parent_node.queue_free()

func test_utility_methods():
	print("\n--- Testing Utility Methods ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.max_health = 100
	health_comp.current_health = 75

	# Test get_health_percentage
	var percentage = health_comp.get_health_percentage()
	assert(abs(percentage - 0.75) < 0.001, "Health percentage should be 0.75")

	# Test is_at_full_health
	assert(health_comp.is_at_full_health() == false, "Should not be at full health")
	health_comp.current_health = 100
	assert(health_comp.is_at_full_health() == true, "Should be at full health")

	# Test is_alive
	assert(health_comp.is_alive() == true, "Should be alive with health > 0")
	health_comp.current_health = 0
	health_comp.is_dead = true
	assert(health_comp.is_alive() == false, "Should not be alive when dead")

	# Test with overheal
	health_comp.is_dead = false
	health_comp.can_overheal = true
	health_comp.current_health = 120
	assert(health_comp.is_at_full_health() == true, "Should be at full health when overhealed")

	percentage = health_comp.get_health_percentage()
	assert(abs(percentage - 1.2) < 0.001, "Health percentage should be 1.2 with overheal")
	print("✓ Utility methods work correctly")

	health_comp.queue_free()

func test_convenience_methods():
	print("\n--- Testing Convenience Methods ---")

	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)
	health_comp.current_health = 100
	health_comp.max_health = 100

	# Test damage() method (alias for take_damage)
	var result = health_comp.damage(25)
	assert(result == true, "damage() should work like take_damage()")
	assert(health_comp.current_health == 75, "Health should be reduced")

	# Test restore_health() method (alias for heal)
	result = health_comp.restore_health(10)
	assert(result == true, "restore_health() should work like heal()")
	assert(health_comp.current_health == 85, "Health should be restored")

	# Test get_health() method
	var current = health_comp.get_health()
	assert(current == 85, "get_health() should return current health")

	# Test get_max_health() method
	var max_health = health_comp.get_max_health()
	assert(max_health == 100, "get_max_health() should return max health")
	print("✓ Convenience methods work correctly")

	health_comp.queue_free()
