extends Node

## Test script for the armor system
## This script can be run to verify that the armor system works correctly

func _ready():
	print("=== ARMOR SYSTEM TEST ===")
	test_armor_component()
	test_doom_green_armor()
	test_doom_blue_armor()
	test_absorption_type()
	test_armor_depletion()
	test_overshield()
	test_integration_with_health()
	print("=== ALL TESTS COMPLETED ===")

func test_armor_component():
	print("\n--- Testing ArmorComponent Basic Functionality ---")
	
	# Create an ArmorComponent
	var armor_comp = preload("res://scenes/components/armor/armor_component.gd").new()
	add_child(armor_comp)
	
	# Test initial values
	assert(armor_comp.current_armor == 0, "Initial armor should be 0")
	assert(armor_comp.max_armor == 100, "Max armor should be 100")
	print("✓ Initial values correct")
	
	# Test adding armor
	var added = armor_comp.add_armor(50)
	assert(added == true, "Should be able to add armor")
	assert(armor_comp.current_armor == 50, "Current armor should be 50")
	print("✓ Adding armor works")
	
	# Test armor at maximum
	armor_comp.add_armor(100) # Try to add more than max
	assert(armor_comp.current_armor == 100, "Armor should be capped at max")
	print("✓ Armor capping works")
	
	armor_comp.queue_free()

func test_doom_green_armor():
	print("\n--- Testing DOOM Green Armor ---")

	# Create components
	var armor_comp = preload("res://scenes/components/armor/armor_component.gd").new()
	add_child(armor_comp)

	# Set up armor for DOOM_GREEN type
	armor_comp.max_armor = 100
	armor_comp.current_armor = 50
	armor_comp.damage_reduction_type = 0 # DOOM_GREEN

	# Test DOOM green armor mechanics with 30 damage
	var initial_armor = armor_comp.current_armor
	var remaining_damage = armor_comp.process_damage(30)

	# Expected: 1/3 absorbed (10), 2/3 to health (20), armor loses 5 points
	var expected_health_damage = int(30 * 2.0 / 3.0) # 20
	var expected_armor_loss = int((30 / 3.0) / 2.0) # 5

	print("30 damage: Health damage = ", remaining_damage, " (expected ~", expected_health_damage, ")")
	print("Armor lost: ", initial_armor - armor_comp.current_armor, " (expected ~", expected_armor_loss, ")")

	assert(remaining_damage == expected_health_damage, "Health should take 2/3 of damage")
	assert(initial_armor - armor_comp.current_armor == expected_armor_loss, "Armor should lose correct amount")
	print("✓ DOOM Green armor mechanics work correctly")

	# Test no armor
	armor_comp.current_armor = 0
	remaining_damage = armor_comp.process_damage(25)
	assert(remaining_damage == 25, "All damage should pass through with no armor")
	print("✓ No armor damage passthrough works")

	armor_comp.queue_free()

func test_doom_blue_armor():
	print("\n--- Testing DOOM Blue Armor ---")

	# Create components
	var armor_comp = preload("res://scenes/components/armor/armor_component.gd").new()
	add_child(armor_comp)

	# Set up armor for DOOM_BLUE type
	armor_comp.max_armor = 100
	armor_comp.current_armor = 50
	armor_comp.damage_reduction_type = 1 # DOOM_BLUE

	# Test DOOM blue armor mechanics with 40 damage
	var initial_armor = armor_comp.current_armor
	var remaining_damage = armor_comp.process_damage(40)

	# Expected: 1/2 absorbed (20), 1/2 to health (20), armor loses 10 points
	var expected_health_damage = int(40 / 2.0) # 20
	var expected_armor_loss = int((40 / 2.0) / 2.0) # 10

	print("40 damage: Health damage = ", remaining_damage, " (expected ", expected_health_damage, ")")
	print("Armor lost: ", initial_armor - armor_comp.current_armor, " (expected ", expected_armor_loss, ")")

	assert(remaining_damage == expected_health_damage, "Health should take 1/2 of damage")
	assert(initial_armor - armor_comp.current_armor == expected_armor_loss, "Armor should lose correct amount")
	print("✓ DOOM Blue armor mechanics work correctly")

	armor_comp.queue_free()

func test_armor_depletion():
	print("\n--- Testing Armor Depletion ---")

	var armor_comp = preload("res://scenes/components/armor/armor_component.gd").new()
	add_child(armor_comp)

	# Use a class variable to track signal emission
	var signal_tracker = SignalTracker.new()
	armor_comp.armor_depleted.connect(signal_tracker.on_signal_emitted)

	# Set up armor for ABSORPTION type to test depletion
	armor_comp.max_armor = 100
	armor_comp.current_armor = 25
	armor_comp.damage_reduction_type = 2 # ABSORPTION type

	# Deplete armor completely
	armor_comp.process_damage(30)

	assert(armor_comp.current_armor == 0, "Armor should be depleted")
	assert(armor_comp.is_broken == true, "Armor should be marked as broken")
	assert(signal_tracker.signal_received == true, "Depletion signal should be emitted")
	print("✓ Armor depletion works")

	armor_comp.queue_free()

# Helper class to track signal emission
class SignalTracker:
	var signal_received = false

	func on_signal_emitted():
		signal_received = true

func test_overshield():
	print("\n--- Testing Overshield ---")
	
	var armor_comp = preload("res://scenes/components/armor/armor_component.gd").new()
	add_child(armor_comp)
	
	# Enable overshield
	armor_comp.can_overshield = true
	armor_comp.overshield_limit = 150
	armor_comp.current_armor = 100
	
	# Test overshield
	var added = armor_comp.add_armor(30)
	assert(added == true, "Should be able to add overshield")
	assert(armor_comp.current_armor == 130, "Should have overshield")
	print("✓ Overshield works")
	
	# Test overshield limit
	armor_comp.add_armor(50)
	assert(armor_comp.current_armor == 150, "Should be capped at overshield limit")
	print("✓ Overshield limit works")
	
	armor_comp.queue_free()

func test_absorption_type():
	print("\n--- Testing ABSORPTION Type (Classic Shield) ---")

	var armor_comp = preload("res://scenes/components/armor/armor_component.gd").new()
	add_child(armor_comp)

	# Set up armor for ABSORPTION type
	armor_comp.max_armor = 100
	armor_comp.current_armor = 50
	armor_comp.damage_reduction_type = 2 # ABSORPTION

	# Test full absorption
	var remaining_damage = armor_comp.process_damage(30)
	assert(remaining_damage == 0, "30 damage should be fully absorbed")
	assert(armor_comp.current_armor == 20, "Armor should be reduced to 20")
	print("✓ Full absorption works")

	# Test partial absorption
	remaining_damage = armor_comp.process_damage(30)
	assert(remaining_damage == 10, "Only 20 armor left, 10 damage should pass through")
	assert(armor_comp.current_armor == 0, "Armor should be depleted")
	print("✓ Partial absorption works")

	armor_comp.queue_free()

func test_integration_with_health():
	print("\n--- Testing Integration with HealthComponent ---")

	# This would require a more complex setup with a player node
	# For now, we'll just verify the basic integration points exist
	var health_comp = preload("res://scenes/components/health/health_component.gd").new()
	add_child(health_comp)

	# Verify the _get_armor_component method exists
	assert(health_comp.has_method("_get_armor_component"), "HealthComponent should have _get_armor_component method")
	print("✓ Integration methods exist")

	health_comp.queue_free()

# Helper function to run manual tests in-game
func run_manual_test():
	print("\n=== MANUAL TEST INSTRUCTIONS ===")
	print("1. Start the game and find the player")
	print("2. Pick up a shield item to add 50 armor (DOOM Green type)")
	print("3. Check that the HUD shows armor value")
	print("4. Take 30 damage from an enemy or weapon")
	print("5. Expected result: 20 health damage, 5 armor lost")
	print("6. DOOM Green Armor: 1/3 damage absorbed, 2/3 to health")
	print("7. Armor degrades at 1:2 ratio (1 armor lost per 2 absorbed)")
	print("8. Continue taking damage until armor is depleted")
	print("9. Verify that subsequent damage affects health directly")
	print("=================================")
