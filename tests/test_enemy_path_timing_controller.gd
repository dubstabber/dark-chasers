extends SceneTree

var _failed := false


func _init() -> void:
	print("=== ENEMY PATH TIMING CONTROLLER TESTS ===")
	_test_timing_thresholds()
	_test_waypoint_priority()
	_test_stagger_helpers()
	_test_enemy_delegates_timing_policy()
	print("=== ENEMY PATH TIMING CONTROLLER TESTS COMPLETED ===")
	quit(1 if _failed else 0)


func _test_timing_thresholds() -> void:
	print("\n--- Testing timing thresholds ---")
	var controller = EnemyPathTimingController.new()
	_assert(is_equal_approx(controller.compute_wait_time(10.0, false), 0.1), "<20 should map to 0.1s")
	_assert(is_equal_approx(controller.compute_wait_time(25.0, false), 0.3), "20-35 should map to 0.3s")
	_assert(is_equal_approx(controller.compute_wait_time(45.0, false), 0.5), "35-50 should map to 0.5s")
	_assert(is_equal_approx(controller.compute_wait_time(70.0, false), 0.8), ">=50 should map to 0.8s")
	print("✓ thresholds are correct")


func _test_waypoint_priority() -> void:
	print("\n--- Testing waypoint priority ---")
	var controller = EnemyPathTimingController.new()
	_assert(is_equal_approx(controller.compute_wait_time(90.0, true), 0.1), "waypoints should force 0.1s regardless of distance")
	print("✓ waypoint priority is correct")


func _test_stagger_helpers() -> void:
	print("\n--- Testing stagger helpers ---")
	var controller = EnemyPathTimingController.new()
	var staggered_wait: float = controller.compute_staggered_wait_time(45.0, false, 1.0)
	_assert(staggered_wait > 0.5, "staggered wait time should expand above the base tier when needed")
	_assert(controller.compute_finished_navigation_repath_delay(0.0) >= 0.05, "finished-navigation repath delay should stay clamped positive")
	var stagger_factor: float = controller.compute_stagger_factor(12345)
	_assert(stagger_factor >= 0.0 and stagger_factor <= 1.0, "stagger factor should be normalized")
	print("✓ stagger helpers are correct")


func _test_enemy_delegates_timing_policy() -> void:
	print("\n--- Testing Enemy delegates timing policy ---")
	var source: String = FileAccess.get_file_as_string("res://scenes/enemies/enemy.gd")
	var runtime_source: String = FileAccess.get_file_as_string("res://scenes/components/enemy/enemy_runtime_coordinator.gd")
	_assert("_runtime_coordinator.on_find_path_timer_timeout" in source, "enemy.gd should delegate path-timer orchestration to EnemyRuntimeCoordinator")
	_assert("_path_timing_controller.compute_staggered_wait_time" in runtime_source, "EnemyRuntimeCoordinator should delegate wait-time policy to EnemyPathTimingController")
	_assert("compute_finished_navigation_repath_delay" in runtime_source, "EnemyRuntimeCoordinator should delegate finished-navigation repath timing to EnemyPathTimingController")
	print("✓ enemy delegates timing policy")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)
