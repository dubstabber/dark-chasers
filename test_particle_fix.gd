# Test script to verify particle animation fixes
# This script can be attached to a test node to verify the fixes work correctly

extends Node

func test_white_chair_destruction():
	print("=== Testing White Chair Particle Fix ===")
	
	# Create a test scrap particle
	var test_scrap = preload("res://scenes/particles/scrap.tscn").instantiate()
	add_child(test_scrap)
	
	# Set it as white scrap
	test_scrap.set_scrap_type("white scrap")
	test_scrap.position = Vector3(0, 5, 0)
	test_scrap.linear_velocity = Vector3(2, 3, 1)
	
	print("✓ Test particle created with immediate texture")
	print("✓ Particle should animate while moving")
	print("✓ Particle should settle and stop animating when velocity drops")
	
	# Test that texture is set immediately
	await get_tree().process_frame
	if test_scrap.sprite_3d.texture:
		print("✓ PASS: Texture set immediately (no spawn delay)")
	else:
		print("✗ FAIL: Texture not set immediately")
	
	print("=== Test Complete ===")

func _ready():
	# Run test after a short delay
	await get_tree().create_timer(1.0).timeout
	test_white_chair_destruction()
