extends SceneTree

var _failed := false


func _init() -> void:
	print("=== GOD OBJECT EXTRACTION TESTS ===")
	_test_enemy_path_timing_extraction()
	_test_enemy_navigation_host_extraction()
	_test_hud_player_binding_extraction()
	_test_hud_event_text_extraction()
	_test_player_movement_slide_extraction()
	_test_weapon_animation_state_extraction()
	_test_directional_sprite_property_extraction()
	print("=== GOD OBJECT EXTRACTION TESTS COMPLETED ===")
	quit(1 if _failed else 0)


func _test_enemy_path_timing_extraction() -> void:
	print("\n--- Testing Enemy path timing extraction ---")
	_assert(FileAccess.file_exists("res://scenes/components/enemy/enemy_path_timing_controller.gd"), "EnemyPathTimingController script should exist")
	var enemy_source: String = FileAccess.get_file_as_string("res://scenes/enemies/enemy.gd")
	_assert("_runtime_coordinator.setup(" in enemy_source and "_path_timing_controller," in enemy_source, "Enemy should pass path timing policy into runtime coordination")
	print("✓ Enemy delegates path timing policy")


func _test_hud_player_binding_extraction() -> void:
	print("\n--- Testing HUD player binding extraction ---")
	_assert(FileAccess.file_exists("res://scenes/components/player/hud_player_binding_controller.gd"), "HudPlayerBindingController script should exist")
	_assert(FileAccess.file_exists("res://scenes/hud.gd"), "HUD script file should exist")
	var hud_source: String = FileAccess.get_file_as_string("res://scenes/hud.gd")
	_assert("_player_binding_controller.connect_player_signals" in hud_source, "HUD should delegate connect_to_player signal wiring")
	_assert("_player_binding_controller.disconnect_player_signals" in hud_source, "HUD should delegate disconnect_from_player signal wiring")
	print("✓ HUD delegates player signal wiring")


func _test_enemy_navigation_host_extraction() -> void:
	print("\n--- Testing Enemy navigation host extraction ---")
	_assert(FileAccess.file_exists("res://scenes/components/enemy/enemy_navigation_host_controller.gd"), "EnemyNavigationHostController script should exist")
	var enemy_source: String = FileAccess.get_file_as_string("res://scenes/enemies/enemy.gd")
	_assert("_navigation_host_controller.refresh_navigation_component" in enemy_source, "Enemy should delegate navigation host orchestration")
	print("✓ Enemy delegates navigation host orchestration")


func _test_hud_event_text_extraction() -> void:
	print("\n--- Testing HUD event text extraction ---")
	_assert(FileAccess.file_exists("res://scenes/components/player/hud_event_text_controller.gd"), "HudEventTextController script should exist")
	var hud_source: String = FileAccess.get_file_as_string("res://scenes/hud.gd")
	_assert("_event_text_controller.show_text" in hud_source, "HUD should delegate event text show behavior")
	_assert("_event_text_controller.hide_text" in hud_source, "HUD should delegate event text hide behavior")
	print("✓ HUD delegates event text behavior")


func _test_player_movement_slide_extraction() -> void:
	print("\n--- Testing PlayerMovement slide extraction ---")
	_assert(FileAccess.file_exists("res://scenes/components/movement/player_slide_controller.gd"), "PlayerSlideController script should exist")
	_assert(FileAccess.file_exists("res://scenes/components/movement/player_movement_component.gd"), "PlayerMovementComponent script file should exist")
	var movement_source: String = FileAccess.get_file_as_string("res://scenes/components/movement/player_movement_component.gd")
	_assert("_slide_controller.start_slide" in movement_source, "PlayerMovementComponent should delegate slide start")
	_assert("_slide_controller.update" in movement_source, "PlayerMovementComponent should delegate slide updates")
	_assert("_slide_controller.get_slide_timer" in movement_source, "PlayerMovementComponent should read slide timer from PlayerSlideController")
	print("✓ PlayerMovementComponent delegates slide state")


func _test_weapon_animation_state_extraction() -> void:
	print("\n--- Testing WeaponManager animation state extraction ---")
	_assert(FileAccess.file_exists("res://scenes/systems/weapon_manager/weapon_animation_state_controller.gd"), "WeaponAnimationStateController script should exist")
	var weapon_manager_source: String = FileAccess.get_file_as_string("res://scenes/systems/weapon_manager/weapon_manager.gd")
	_assert("_animation_state_controller.on_animation_started" in weapon_manager_source, "WeaponManager should delegate animation-start tracking")
	_assert("_animation_state_controller.on_animation_finished" in weapon_manager_source, "WeaponManager should delegate animation-finish tracking")
	print("✓ WeaponManager delegates animation state tracking")


func _test_directional_sprite_property_extraction() -> void:
	print("\n--- Testing DirectionalSprite property extraction ---")
	_assert(FileAccess.file_exists("res://scenes/components/directional_sprite_3d/directional_sprite_property_controller.gd"), "DirectionalSpritePropertyController script should exist")
	var sprite_source: String = FileAccess.get_file_as_string("res://scenes/components/directional_sprite_3d/directional_sprite_3d.gd")
	_assert("_property_controller.get_dynamic_property" in sprite_source, "DirectionalSprite3D should delegate dynamic property reads")
	_assert("_property_controller.set_dynamic_property" in sprite_source, "DirectionalSprite3D should delegate dynamic property writes")
	_assert("_property_controller.build_property_list" in sprite_source, "DirectionalSprite3D should delegate property list generation")
	print("✓ DirectionalSprite3D delegates dynamic property schema")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)
