extends Node

# Test script to verify the component-based ammo system
# This can be run in the editor to test the new architecture

func _ready():
	print("=== Testing Component-Based Ammo System ===")
	
	# Test 1: Create ammo component
	print("\n1. Creating PlayerAmmoComponent:")
	var ammo_component = preload("res://components/player_ammo_component.gd").new()
	add_child(ammo_component)
	
	# Wait a frame for _ready to be called
	await get_tree().process_frame
	
	# Test 2: Basic ammo operations
	print("\n2. Testing basic ammo operations:")
	print("Initial pistol ammo: ", ammo_component.get_ammo("pistol_ammo"))
	print("Max pistol ammo: ", ammo_component.get_max_ammo("pistol_ammo"))
	
	# Test 3: Add ammo
	print("\n3. Testing add ammo:")
	var added = ammo_component.add_ammo("pistol_ammo", 50)
	print("Added 50 pistol ammo: ", added)
	print("Current pistol ammo: ", ammo_component.get_ammo("pistol_ammo"))
	
	# Test 4: Consume ammo
	print("\n4. Testing consume ammo:")
	var consumed = ammo_component.consume_ammo("pistol_ammo", 10)
	print("Consumed 10 pistol ammo: ", consumed)
	print("Current pistol ammo: ", ammo_component.get_ammo("pistol_ammo"))
	
	# Test 5: Check ammo availability
	print("\n5. Testing ammo availability:")
	print("Has 5 pistol ammo: ", ammo_component.has_ammo("pistol_ammo", 5))
	print("Has 1000 pistol ammo: ", ammo_component.has_ammo("pistol_ammo", 1000))
	
	# Test 6: Ammo percentage
	print("\n6. Testing ammo percentage:")
	print("Pistol ammo percentage: ", ammo_component.get_ammo_percentage("pistol_ammo"))
	
	# Test 7: All ammo types
	print("\n7. All registered ammo types:")
	for ammo_type in ammo_component.get_all_ammo_types():
		print("  %s: %d/%d" % [ammo_type, ammo_component.get_ammo(ammo_type), ammo_component.get_max_ammo(ammo_type)])
	
	# Test 8: AmmoConfig
	print("\n8. Testing AmmoConfig:")
	var config = AmmoConfig.get_instance()
	print("Available ammo types: ", config.get_all_ammo_types())
	print("Pistol ammo config: ", config.get_ammo_config("pistol_ammo"))
	
	print("\n=== Component Test Complete ===")
	
	# Clean up
	queue_free()
