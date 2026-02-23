extends SceneTree

var _failed := false


func _init() -> void:
	print("=== ENEMY PATHFINDING DELAY REGRESSION TESTS ===")
	_test_path_timing_thresholds()
	_test_runtime_target_reacquisition_policy()
	_test_enemy_delegates_path_timeout_orchestration()
	print("=== ENEMY PATHFINDING DELAY REGRESSION TESTS COMPLETED ===")
	quit(1 if _failed else 0)


func _test_path_timing_thresholds() -> void:
	print("\n--- Testing path timing thresholds ---")
	var controller = EnemyPathTimingController.new()
	_assert(is_equal_approx(controller.compute_wait_time(10.0, false), 0.1), "<20 units should map to 0.1s")
	_assert(is_equal_approx(controller.compute_wait_time(25.0, false), 0.3), "20-35 units should map to 0.3s")
	_assert(is_equal_approx(controller.compute_wait_time(45.0, false), 0.5), "35-50 units should map to 0.5s")
	_assert(is_equal_approx(controller.compute_wait_time(70.0, false), 0.8), ">=50 units should map to 0.8s")
	_assert(is_equal_approx(controller.compute_wait_time(90.0, true), 0.1), "Waypoint pathing should force 0.1s")
	print("✓ Path timing thresholds are correct")


func _test_runtime_target_reacquisition_policy() -> void:
	print("\n--- Testing runtime coordinator target-loss responsiveness ---")
	var runtime_source := FileAccess.get_file_as_string("res://scenes/components/enemy/enemy_runtime_coordinator.gd")
	_assert("func on_target_died() -> void:" in runtime_source, "Runtime coordinator should expose on_target_died hook")
	_assert("_find_path_timer.wait_time = 0.1" in runtime_source, "Runtime coordinator should reset timer to 0.1s on target death")
	_assert("if _enemy.current_target and Mortal.is_dead(_enemy.current_target):" in runtime_source, "Runtime coordinator should detect dead target during chase")
	print("✓ Runtime coordinator target-loss policy remains responsive")


func _test_enemy_delegates_path_timeout_orchestration() -> void:
	print("\n--- Testing Enemy delegates path timeout orchestration ---")
	var enemy_source := FileAccess.get_file_as_string("res://scenes/enemies/enemy.gd")
	var timeout_body := _get_function_body(enemy_source, "func _on_find_path_timer_timeout")
	_assert("_runtime_coordinator.on_find_path_timer_timeout()" in timeout_body, "Enemy should delegate find-path timer timeout to runtime coordinator")
	_assert("_path_timing_controller.compute_wait_time" not in timeout_body, "Enemy should not own timing policy directly")
	_assert("makepath()" not in timeout_body, "Enemy timer timeout should not call makepath directly")
	print("✓ Enemy delegates path timeout orchestration to runtime coordinator")


func _get_function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	_assert(start != -1, "Expected function not found: %s" % signature)
	var end := source.find("\nfunc ", start + 1)
	if end == -1:
		end = source.length()
	return source.substr(start, end - start)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)
