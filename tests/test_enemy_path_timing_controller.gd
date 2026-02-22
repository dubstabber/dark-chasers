extends SceneTree

const EnemyPathTimingControllerScript = preload("res://scenes/components/enemy/enemy_path_timing_controller.gd")

var _failed := false


func _init() -> void:
	print("=== ENEMY PATH TIMING CONTROLLER TESTS ===")
	_test_timing_thresholds()
	_test_waypoint_priority()
	_test_enemy_delegates_timing_policy()
	print("=== ENEMY PATH TIMING CONTROLLER TESTS COMPLETED ===")
	quit(1 if _failed else 0)


func _test_timing_thresholds() -> void:
	print("\n--- Testing timing thresholds ---")
	var controller = EnemyPathTimingControllerScript.new()
	_assert(is_equal_approx(controller.compute_wait_time(10.0, false), 0.1), "<20 should map to 0.1s")
	_assert(is_equal_approx(controller.compute_wait_time(25.0, false), 0.3), "20-35 should map to 0.3s")
	_assert(is_equal_approx(controller.compute_wait_time(45.0, false), 0.5), "35-50 should map to 0.5s")
	_assert(is_equal_approx(controller.compute_wait_time(70.0, false), 0.8), ">=50 should map to 0.8s")
	print("✓ thresholds are correct")


func _test_waypoint_priority() -> void:
	print("\n--- Testing waypoint priority ---")
	var controller = EnemyPathTimingControllerScript.new()
	_assert(is_equal_approx(controller.compute_wait_time(90.0, true), 0.1), "waypoints should force 0.1s regardless of distance")
	print("✓ waypoint priority is correct")


func _test_enemy_delegates_timing_policy() -> void:
	print("\n--- Testing Enemy delegates timing policy ---")
	var source: String = FileAccess.get_file_as_string("res://scenes/enemies/enemy.gd")
	_assert("_path_timing_controller.compute_wait_time" in source, "enemy.gd should delegate wait-time policy to EnemyPathTimingController")
	print("✓ enemy delegates timing policy")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)
