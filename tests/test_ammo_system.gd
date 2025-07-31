extends Node

# Simple test script to verify AmmoManager functionality
# Run this in the Godot editor to test the centralized ammo system

func _ready():
	print("=== Testing Centralized Ammo System ===")
	
	# Test 1: Basic ammo operations
	print("\n1. Testing basic ammo operations:")
	print("Initial pistol ammo: ", AmmoManager.get_ammo("pistol_ammo"))
	print("Max pistol ammo: ", AmmoManager.get_max_ammo("pistol_ammo"))
	
	# Test 2: Add ammo
	print("\n2. Testing add ammo:")
	var added = AmmoManager.add_ammo("pistol_ammo", 50)
	print("Added 50 pistol ammo: ", added)
	print("Current pistol ammo: ", AmmoManager.get_ammo("pistol_ammo"))
	
	# Test 3: Consume ammo
	print("\n3. Testing consume ammo:")
	var consumed = AmmoManager.consume_ammo("pistol_ammo", 10)
	print("Consumed 10 pistol ammo: ", consumed)
	print("Current pistol ammo: ", AmmoManager.get_ammo("pistol_ammo"))
	
	# Test 4: Check ammo availability
	print("\n4. Testing ammo availability:")
	print("Has 5 pistol ammo: ", AmmoManager.has_ammo("pistol_ammo", 5))
	print("Has 1000 pistol ammo: ", AmmoManager.has_ammo("pistol_ammo", 1000))
	
	# Test 5: Ammo percentage
	print("\n5. Testing ammo percentage:")
	print("Pistol ammo percentage: ", AmmoManager.get_ammo_percentage("pistol_ammo"))
	
	# Test 6: All ammo types
	print("\n6. All registered ammo types:")
	for ammo_type in AmmoManager.get_all_ammo_types():
		print("  %s: %d/%d" % [ammo_type, AmmoManager.get_ammo(ammo_type), AmmoManager.get_max_ammo(ammo_type)])
	
	print("\n=== Test Complete ===")
	
	# Clean up
	queue_free()
