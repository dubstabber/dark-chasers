extends Node

var _failed := false


func _ready() -> void:
	print("=== HELPER SCRIPT CLASS_NAME DECOUPLING TESTS ===")
	_test_refactored_sources_use_class_names()
	_test_refactored_host_scripts_compile_and_instantiate()
	print("=== HELPER SCRIPT CLASS_NAME DECOUPLING TESTS COMPLETED ===")
	get_tree().quit(1 if _failed else 0)


func _test_refactored_sources_use_class_names() -> void:
	print("\n--- Testing refactored source files use class_name helpers ---")
	_assert_source_contains("res://scenes/enemies/enemy.gd", "EnemyNavigationHostController.new()")
	_assert_source_not_contains("res://scenes/enemies/enemy.gd", "EnemyNavigationHostControllerScript")
	_assert_source_contains("res://scenes/components/directional_sprite_3d/directional_sprite_3d.gd", "DirectionalSpritePropertyController.new()")
	_assert_source_not_contains("res://scenes/components/directional_sprite_3d/directional_sprite_3d.gd", "DirectionalSpritePropertyControllerScript")
	_assert_source_contains("res://scenes/components/enemy/doom_navigation_component.gd", "DoomNavigationDirectionPolicy.new()")
	_assert_source_not_contains("res://scenes/components/enemy/doom_navigation_component.gd", "DoomNavigationDirectionPolicyScript")
	_assert_source_contains("res://scenes/components/enemy/fuwatty_dash_ability.gd", "FuwattyDashPolicy.new()")
	_assert_source_not_contains("res://scenes/components/enemy/fuwatty_dash_ability.gd", "FuwattyDashPolicyScript")
	_assert_source_contains("res://scenes/services/services.gd", "EnemySpawnOwnerService.new()")
	_assert_source_not_contains("res://scenes/services/services.gd", "EnemySpawnOwnerServiceScript")
	print("✓ refactored sources use class_name helpers")


func _test_refactored_host_scripts_compile_and_instantiate() -> void:
	print("\n--- Testing refactored host scripts compile and instantiate ---")
	var scripts := [
		load("res://scenes/enemies/enemy.gd") as GDScript,
		load("res://scenes/components/directional_sprite_3d/directional_sprite_3d.gd") as GDScript,
		load("res://scenes/components/enemy/doom_navigation_component.gd") as GDScript,
		load("res://scenes/components/enemy/fuwatty_dash_ability.gd") as GDScript,
		load("res://scenes/hud.gd") as GDScript,
		load("res://scenes/systems/weapon_manager/weapon_manager.gd") as GDScript,
	]
	for script: GDScript in scripts:
		_assert(script != null, "Refactored host script should load")
		var instance: Object = script.new()
		_assert(instance != null, "Refactored host script should instantiate")
		if instance is Node:
			instance.queue_free()
	print("✓ refactored host scripts instantiate successfully")


func _assert_source_contains(path: String, expected: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	_assert(expected in source, "%s should contain '%s'" % [path, expected])


func _assert_source_not_contains(path: String, unexpected: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	_assert(unexpected not in source, "%s should not contain '%s'" % [path, unexpected])


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)