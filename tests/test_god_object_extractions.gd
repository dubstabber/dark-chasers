extends SceneTree

var _failed := false


func _init() -> void:
	print("=== GOD OBJECT EXTRACTION TESTS ===")
	_test_enemy_path_timing_extraction()
	_test_hud_player_binding_extraction()
	_test_player_movement_slide_extraction()
	print("=== GOD OBJECT EXTRACTION TESTS COMPLETED ===")
	quit(1 if _failed else 0)


func _test_enemy_path_timing_extraction() -> void:
	print("\n--- Testing Enemy path timing extraction ---")
	var controller_script = load("res://scenes/components/enemy/enemy_path_timing_controller.gd") as GDScript
	_assert(controller_script != null, "EnemyPathTimingController script should load")
	var enemy_source: String = FileAccess.get_file_as_string("res://scenes/enemies/enemy.gd")
	_assert("_path_timing_controller.compute_wait_time" in enemy_source, "Enemy should delegate timer wait policy")
	print("✓ Enemy delegates path timing policy")


func _test_hud_player_binding_extraction() -> void:
	print("\n--- Testing HUD player binding extraction ---")
	var controller_script = load("res://scenes/components/player/hud_player_binding_controller.gd") as GDScript
	_assert(controller_script != null, "HudPlayerBindingController script should load")
	_assert(FileAccess.file_exists("res://scenes/hud.gd"), "HUD script file should exist")
	var hud_source: String = FileAccess.get_file_as_string("res://scenes/hud.gd")
	_assert("_player_binding_controller.connect_player_signals" in hud_source, "HUD should delegate connect_to_player signal wiring")
	_assert("_player_binding_controller.disconnect_player_signals" in hud_source, "HUD should delegate disconnect_from_player signal wiring")
	print("✓ HUD delegates player signal wiring")


func _test_player_movement_slide_extraction() -> void:
	print("\n--- Testing PlayerMovement slide extraction ---")
	var controller_script = load("res://scenes/components/movement/player_slide_controller.gd") as GDScript
	_assert(controller_script != null, "PlayerSlideController script should load")
	_assert(FileAccess.file_exists("res://scenes/components/movement/player_movement_component.gd"), "PlayerMovementComponent script file should exist")
	var movement_source: String = FileAccess.get_file_as_string("res://scenes/components/movement/player_movement_component.gd")
	_assert("_slide_controller.start_slide" in movement_source, "PlayerMovementComponent should delegate slide start")
	_assert("_slide_controller.update" in movement_source, "PlayerMovementComponent should delegate slide updates")
	_assert("_slide_controller.get_slide_timer" in movement_source, "PlayerMovementComponent should read slide timer from PlayerSlideController")
	print("✓ PlayerMovementComponent delegates slide state")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)
