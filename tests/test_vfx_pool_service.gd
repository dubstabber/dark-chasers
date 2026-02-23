extends Node


class TestPoolableVfx:
	extends Node3D

	var borrowed_count: int = 0
	var returned_count: int = 0

	func on_borrowed() -> void:
		borrowed_count += 1

	func on_returned() -> void:
		returned_count += 1


func _ready() -> void:
	print("=== VFX POOL SERVICE TESTS ===")
	test_pool_lifecycle_hooks_and_in_use_state()
	print("=== VFX POOL SERVICE TESTS COMPLETED ===")
	get_tree().quit()


func test_pool_lifecycle_hooks_and_in_use_state() -> void:
	var service: VfxPoolService = VfxPoolService.new()
	service.default_pool_size = 1

	var packed_scene := _make_poolable_scene()
	var instance = service.get_instance(packed_scene)

	assert(instance != null, "Should borrow an instance from the pool")
	assert(instance.get_meta("_pool_in_use", false), "Borrowed instance should be marked in use")
	assert(instance.visible, "Borrowed instance should be visible")
	assert(instance.borrowed_count == 1, "Borrowing should call on_borrowed once")
	assert(instance.is_processing(), "Borrowed instance should have processing enabled")

	service.release_instance(instance)

	assert(not instance.get_meta("_pool_in_use", true), "Released instance should not be marked in use")
	assert(not instance.visible, "Released instance should be hidden")
	assert(instance.returned_count == 2, "Released instance should run on_returned after initial pool reset")
	assert(not instance.is_processing(), "Released instance should have processing disabled")

	var stats: Dictionary = service.get_pool_stats()
	assert(stats.has(""), "Pool stats should include pooled scene path key")
	assert(stats[""]["available"] == 1, "Released instance should be available in pool")

	service.free()
	print("✓ VFX pool lifecycle hooks and in-use tracking work correctly")


func _make_poolable_scene() -> PackedScene:
	var scene_root := TestPoolableVfx.new()
	var scene := PackedScene.new()
	var packed_ok := scene.pack(scene_root)
	assert(packed_ok == OK, "Should be able to pack test poolable scene")
	scene_root.free()
	return scene
