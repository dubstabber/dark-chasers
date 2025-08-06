extends Node

# Simple test script to verify AmmoConfig functionality
# Run this in the Godot editor to test the ammo configuration system
# Note: AmmoManager has been replaced with component-based ammo system

func _ready():
	print("=== Testing AmmoConfig System ===")
	print("Note: AmmoManager has been replaced with component-based ammo system.")
	print("This test now verifies AmmoConfig functionality.")

	# Test 1: Basic ammo config operations
	print("\n1. Testing basic ammo config operations:")
	var config = AmmoConfig.get_instance()
	var pistol_config = config.get_ammo_config("pistol_ammo")
	print("Pistol ammo config: ", pistol_config)

	# Test 2: All ammo types
	print("\n2. All registered ammo types:")
	var all_configs = config.get_default_ammo_configs()
	for ammo_type in all_configs:
		var ammo_config = all_configs[ammo_type]
		print("  %s: max=%d, default=%d" % [ammo_type, ammo_config.max, ammo_config.default])

	# Test 3: Register new ammo type
	print("\n3. Testing ammo type registration:")
	config.register_ammo_type("test_ammo", 50, 10)
	var test_config = config.get_ammo_config("test_ammo")
	print("Test ammo config: ", test_config)

	# Test 4: Check ammo type existence
	print("\n4. Testing ammo type existence:")
	print("Has pistol_ammo: ", config.has_ammo_type("pistol_ammo"))
	print("Has nonexistent_ammo: ", config.has_ammo_type("nonexistent_ammo"))

	print("\n=== Test Complete ===")
	print("For component-based ammo testing, see test_component_ammo_system.gd")

	# Clean up
	queue_free()
