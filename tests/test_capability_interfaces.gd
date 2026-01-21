extends Node

## Tests for Mortal and Aimable capability interfaces

func _ready():
	print("=== CAPABILITY INTERFACES TESTS ===")
	
	test_mortal_interface_check()
	test_mortal_is_dead()
	test_mortal_is_alive()
	test_aimable_interface_check()
	test_aimable_get_aim_point()
	test_aimable_fallback_behavior()
	
	print("=== ALL CAPABILITY INTERFACES TESTS COMPLETED ===")


# Mock classes for testing
class MockMortalEntity extends Node:
	var _is_dead := false
	
	func is_dead() -> bool:
		return _is_dead
	
	func is_alive() -> bool:
		return not _is_dead


class MockAimableEntity extends Node3D:
	var aim_point := Vector3(0, 2, 0)
	
	func get_aim_point() -> Vector3:
		return aim_point


class MockLegacyEntity extends Node3D:
	# Has camera_3d property but no get_aim_point method
	var camera_3d: Node3D


func test_mortal_interface_check():
	print("\n--- Testing Mortal.check() ---")
	
	var mortal_entity = MockMortalEntity.new()
	add_child(mortal_entity)
	
	var non_mortal_entity = Node.new()
	add_child(non_mortal_entity)
	
	assert(Mortal.check(mortal_entity) == true, "Mortal entity should pass check")
	assert(Mortal.check(non_mortal_entity) == false, "Non-mortal entity should fail check")
	assert(Mortal.check(null) == false, "Null should fail check")
	print("✓ Mortal.check() works correctly")
	
	mortal_entity.queue_free()
	non_mortal_entity.queue_free()


func test_mortal_is_dead():
	print("\n--- Testing Mortal.is_dead() ---")
	
	var entity = MockMortalEntity.new()
	add_child(entity)
	
	entity._is_dead = false
	assert(Mortal.is_dead(entity) == false, "Living entity should not be dead")
	
	entity._is_dead = true
	assert(Mortal.is_dead(entity) == true, "Dead entity should be dead")
	
	# Null should return true (safe default)
	assert(Mortal.is_dead(null) == true, "Null entity should return true (dead)")
	print("✓ Mortal.is_dead() works correctly")
	
	entity.queue_free()


func test_mortal_is_alive():
	print("\n--- Testing Mortal.is_alive() ---")
	
	var entity = MockMortalEntity.new()
	add_child(entity)
	
	entity._is_dead = false
	assert(Mortal.is_alive(entity) == true, "Living entity should be alive")
	
	entity._is_dead = true
	assert(Mortal.is_alive(entity) == false, "Dead entity should not be alive")
	
	# Null should return false (safe default)
	assert(Mortal.is_alive(null) == false, "Null entity should return false (not alive)")
	print("✓ Mortal.is_alive() works correctly")
	
	entity.queue_free()


func test_aimable_interface_check():
	print("\n--- Testing Aimable.check() ---")
	
	var aimable_entity = MockAimableEntity.new()
	add_child(aimable_entity)
	
	var non_aimable_entity = Node3D.new()
	add_child(non_aimable_entity)
	
	assert(Aimable.check(aimable_entity) == true, "Aimable entity should pass check")
	assert(Aimable.check(non_aimable_entity) == false, "Non-aimable entity should fail check")
	assert(Aimable.check(null) == false, "Null should fail check")
	print("✓ Aimable.check() works correctly")
	
	aimable_entity.queue_free()
	non_aimable_entity.queue_free()


func test_aimable_get_aim_point():
	print("\n--- Testing Aimable.get_aim_point() ---")
	
	var entity = MockAimableEntity.new()
	entity.aim_point = Vector3(10, 20, 30)
	add_child(entity)
	
	var result = Aimable.get_aim_point(entity)
	assert(result == Vector3(10, 20, 30), "Should return entity's aim point")
	print("✓ Aimable.get_aim_point() works correctly")
	
	entity.queue_free()


func test_aimable_fallback_behavior():
	print("\n--- Testing Aimable Fallback Behavior ---")
	
	# Test with legacy entity (has camera_3d but no get_aim_point)
	var legacy_entity = MockLegacyEntity.new()
	var mock_camera = Node3D.new()
	mock_camera.global_position = Vector3(5, 10, 15)
	legacy_entity.camera_3d = mock_camera
	add_child(legacy_entity)
	add_child(mock_camera)
	
	var result = Aimable.get_aim_point(legacy_entity)
	assert(result == Vector3(5, 10, 15), "Should fallback to camera_3d position")
	print("✓ Aimable fallback to camera_3d works")
	
	# Test with plain Node3D (should fallback to global_position + offset)
	var plain_entity = Node3D.new()
	plain_entity.global_position = Vector3(0, 0, 0)
	add_child(plain_entity)
	
	result = Aimable.get_aim_point(plain_entity)
	assert(result == Vector3(0, 1.6, 0), "Should fallback to global_position + head offset")
	print("✓ Aimable fallback to global_position + offset works")
	
	# Test with null
	result = Aimable.get_aim_point(null)
	assert(result == Vector3.ZERO, "Null should return Vector3.ZERO")
	print("✓ Aimable null handling works")
	
	legacy_entity.queue_free()
	mock_camera.queue_free()
	plain_entity.queue_free()
