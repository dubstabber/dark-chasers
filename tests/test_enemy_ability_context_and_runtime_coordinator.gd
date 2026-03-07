extends SceneTree

var _failed := false


func _init() -> void:
	print("=== ENEMY ABILITY CONTEXT + RUNTIME COORDINATOR TESTS ===")
	_test_ability_context_uses_runtime_visibility()
	_test_ai_component_exposes_runtime_visibility_check()
	_test_enemy_brain_and_ability_stack_remain_navigation_agent_agnostic()
	_test_runtime_coordinator_uses_navigation_abstraction_not_godot_agent_api()
	_test_enemy_delegates_path_orchestration_to_runtime_coordinator()
	print("=== ENEMY ABILITY CONTEXT + RUNTIME COORDINATOR TESTS COMPLETED ===")
	quit(1 if _failed else 0)


func _test_ability_context_uses_runtime_visibility() -> void:
	print("\n--- Testing EnemyAbilityContext visibility semantics ---")
	var source := FileAccess.get_file_as_string("res://scenes/components/enemy/enemy_ability_context.gd")
	_assert("ctx.enemy_body = enemy" in source, "EnemyAbilityContext should retain the enemy body for pre-activation commit checks")
	_assert("ctx.is_target_visible = ai_component.is_target_visible()" in source, "EnemyAbilityContext should use runtime target visibility")
	_assert("ctx.is_target_visible = ai_component.check_line_of_sight" not in source, "EnemyAbilityContext should not use LOS config as visibility")
	print("✓ EnemyAbilityContext uses runtime visibility")


func _test_ai_component_exposes_runtime_visibility_check() -> void:
	print("\n--- Testing EnemyAIComponent runtime visibility method ---")
	var source := FileAccess.get_file_as_string("res://scenes/components/enemy/enemy_ai_component.gd")
	_assert("func is_target_visible() -> bool:" in source, "EnemyAIComponent should expose is_target_visible()")
	_assert("intersect_ray" in source, "EnemyAIComponent visibility should be raycast-based when LOS is enabled")
	print("✓ EnemyAIComponent exposes runtime visibility check")


func _test_enemy_brain_and_ability_stack_remain_navigation_agent_agnostic() -> void:
	print("\n--- Testing ability stack remains navigation-agent agnostic ---")
	var brain_source := FileAccess.get_file_as_string("res://scenes/components/enemy/enemy_brain.gd")
	var ability_context_source := FileAccess.get_file_as_string("res://scenes/components/enemy/enemy_ability_context.gd")
	var dash_source := FileAccess.get_file_as_string("res://scenes/components/enemy/fuwatty_dash_ability.gd")
	_assert("NavigationAgent3D" not in brain_source, "EnemyBrain should not depend on NavigationAgent3D")
	_assert("navigation_agent" not in dash_source, "FuwattyDashAbility should not depend on a Godot navigation agent")
	_assert("NavigationAgent3D" not in ability_context_source, "EnemyAbilityContext should not depend on NavigationAgent3D")
	_assert("ctx.target_position = ai_component.get_target_position()" in ability_context_source, "EnemyAbilityContext should source target data from EnemyAIComponent")
	_assert("enemy.get(\"current_target\")" in dash_source, "FuwattyDashAbility should operate on the chased target directly")
	print("✓ Ability stack remains navigation-agent agnostic")


func _test_runtime_coordinator_uses_navigation_abstraction_not_godot_agent_api() -> void:
	print("\n--- Testing runtime coordinator navigation abstraction usage ---")
	var runtime_source := FileAccess.get_file_as_string("res://scenes/components/enemy/enemy_runtime_coordinator.gd")
	_assert("NavigationAgent3D" not in runtime_source, "Runtime coordinator should not reference NavigationAgent3D directly")
	_assert("navigation_agent" not in runtime_source, "Runtime coordinator should not reach into Godot navigation-agent internals")
	_assert("_nav_component.distance_to_target()" in runtime_source, "Runtime coordinator path timing should use the navigation abstraction")
	_assert("_nav_component.is_navigation_finished()" in runtime_source, "Runtime coordinator chase fallback should use the navigation abstraction")
	_assert("_nav_component.get_horizontal_direction()" in runtime_source, "Runtime coordinator movement should come from the active navigation component")
	print("✓ Runtime coordinator stays on the navigation abstraction")


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
