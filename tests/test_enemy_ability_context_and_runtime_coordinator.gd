extends SceneTree

var _failed := false


func _init() -> void:
	print("=== ENEMY ABILITY CONTEXT + RUNTIME COORDINATOR TESTS ===")
	_test_ability_context_uses_runtime_visibility()
	_test_ai_component_exposes_runtime_visibility_check()
	_test_enemy_delegates_path_orchestration_to_runtime_coordinator()
	print("=== ENEMY ABILITY CONTEXT + RUNTIME COORDINATOR TESTS COMPLETED ===")
	quit(1 if _failed else 0)


func _test_ability_context_uses_runtime_visibility() -> void:
	print("\n--- Testing EnemyAbilityContext visibility semantics ---")
	var source := FileAccess.get_file_as_string("res://scenes/components/enemy/enemy_ability_context.gd")
	_assert("ctx.is_target_visible = ai_component.is_target_visible()" in source, "EnemyAbilityContext should use runtime target visibility")
	_assert("ctx.is_target_visible = ai_component.check_line_of_sight" not in source, "EnemyAbilityContext should not use LOS config as visibility")
	print("✓ EnemyAbilityContext uses runtime visibility")


func _test_ai_component_exposes_runtime_visibility_check() -> void:
	print("\n--- Testing EnemyAIComponent runtime visibility method ---")
	var source := FileAccess.get_file_as_string("res://scenes/components/enemy/enemy_ai_component.gd")
	_assert("func is_target_visible() -> bool:" in source, "EnemyAIComponent should expose is_target_visible()")
	_assert("intersect_ray" in source, "EnemyAIComponent visibility should be raycast-based when LOS is enabled")
	print("✓ EnemyAIComponent exposes runtime visibility check")


func _test_enemy_delegates_path_orchestration_to_runtime_coordinator() -> void:
	print("\n--- Testing Enemy runtime/path delegation ---")
	var enemy_source := FileAccess.get_file_as_string("res://scenes/enemies/enemy.gd")
	var runtime_source := FileAccess.get_file_as_string("res://scenes/components/enemy/enemy_runtime_coordinator.gd")
	_assert("_runtime_coordinator.process_physics(delta)" in enemy_source, "Enemy should delegate per-frame orchestration to runtime coordinator")
	_assert("_runtime_coordinator.on_find_path_timer_timeout()" in enemy_source, "Enemy should delegate path timer callbacks to runtime coordinator")
	_assert("func _process_chase_movement" in runtime_source, "Runtime coordinator should own chase movement orchestration")
	_assert("func _process_wandering_movement" in runtime_source, "Runtime coordinator should own wandering movement orchestration")
	_assert("_enemy.makepath()" in runtime_source, "Runtime coordinator should trigger path refreshes")
	print("✓ Enemy path orchestration delegates to runtime coordinator")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)
