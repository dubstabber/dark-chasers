extends Node

## Tests for Phase 3 weapon system refactoring
## Tests WeaponHitExecutor and WeaponManager public fire methods

func _ready():
	print("=== WEAPON SYSTEM REFACTOR TESTS ===")
	
	test_weapon_fire_controller_creation()
	test_weapon_ui_event_controller_creation()
	test_weapon_equip_controller_creation()
	test_weapon_hit_executor_creation()
	test_weapon_hit_executor_enemy_vfx_policy()
	test_weapon_resource_is_pure_config()
	test_weapon_manager_fire_methods_exist()
	test_weapon_manager_delegates_to_controllers()
	test_weapon_manager_uses_movement_intent_for_bobbing()
	test_weapon_manager_owns_ammo_wiring()
	test_player_no_ammo_wiring()
	
	print("=== ALL WEAPON SYSTEM REFACTOR TESTS COMPLETED ===")
	get_tree().quit()


func test_weapon_fire_controller_creation():
	print("\n--- Testing WeaponFireController Creation ---")
	
	var script = load("res://scenes/systems/weapon_manager/weapon_fire_controller.gd") as GDScript
	assert(script != null, "WeaponFireController script should load")
	var controller = script.new()
	assert(controller != null, "WeaponFireController should be instantiable")
	assert(controller.has_method("try_fire"), "WeaponFireController should have try_fire")
	assert(controller.has_method("try_auto_fire"), "WeaponFireController should have try_auto_fire")
	assert(controller.has_method("consume_and_execute_hit"), "WeaponFireController should have consume_and_execute_hit")
	print("✓ WeaponFireController created successfully")


func test_weapon_ui_event_controller_creation():
	print("\n--- Testing WeaponUiEventController Creation ---")
	
	var script = load("res://scenes/systems/weapon_manager/weapon_ui_event_controller.gd") as GDScript
	assert(script != null, "WeaponUiEventController script should load")
	var controller = script.new()
	assert(controller != null, "WeaponUiEventController should be instantiable")
	assert(controller.has_method("connect_weapon_signals"), "WeaponUiEventController should have connect_weapon_signals")
	assert(controller.has_method("disconnect_weapon_signals"), "WeaponUiEventController should have disconnect_weapon_signals")
	assert(controller.has_method("emit_weapon_equipped"), "WeaponUiEventController should have emit_weapon_equipped")
	print("✓ WeaponUiEventController created successfully")


func test_weapon_hit_executor_creation():
	print("\n--- Testing WeaponHitExecutor Creation ---")
	
	var executor = WeaponHitExecutor.new()
	assert(executor != null, "WeaponHitExecutor should be instantiable")
	
	# Test that setup method exists
	assert(executor.has_method("setup"), "Executor should have setup method")
	assert(executor.has_method("execute_hit"), "Executor should have execute_hit method")
	print("✓ WeaponHitExecutor created successfully")


func test_weapon_hit_executor_enemy_vfx_policy():
	print("\n--- Testing WeaponHitExecutor enemy-hit VFX policy ---")
	
	var script = load("res://scenes/systems/weapon_manager/weapon_hit_executor.gd") as GDScript
	var source = script.source_code
	
	assert("var is_enemy_hit := _is_enemy_hit(collider)" in source, "Hit executor should classify enemy hits")
	assert("if not is_enemy_hit:" in source, "Hit particles should be skipped for enemy hits")
	assert("func _is_enemy_hit(collider: Node) -> bool:" in source, "Hit executor should expose enemy-hit helper")
	print("✓ WeaponHitExecutor suppresses weapon impact VFX on enemies")


func test_weapon_equip_controller_creation():
	print("\n--- Testing WeaponEquipController Creation ---")

	var script = load("res://scenes/systems/weapon_manager/weapon_equip_controller.gd") as GDScript
	assert(script != null, "WeaponEquipController script should load")
	var controller = script.new()
	assert(controller != null, "WeaponEquipController should be instantiable")
	assert(controller.has_method("setup"), "WeaponEquipController should have setup")
	assert(controller.has_method("switch_weapon"), "WeaponEquipController should have switch_weapon")
	assert(controller.has_method("equip_selected_slot"), "WeaponEquipController should have equip_selected_slot")
	print("✓ WeaponEquipController created successfully")


func test_weapon_resource_is_pure_config():
	print("\n--- Testing WeaponResource is Pure Config ---")
	
	var weapon = WeaponResource.new()
	
	# Verify WeaponResource no longer has hit() method (moved to executor)
	assert(not weapon.has_method("hit"), "WeaponResource should not have hit() method (moved to executor)")
	
	# Verify config properties exist
	assert("shoot_type" in weapon, "WeaponResource should have shoot_type property")
	assert("damage" in weapon, "WeaponResource should have damage property")
	assert("hit_particle" in weapon, "WeaponResource should have hit_particle property")
	assert("ammo_type" in weapon, "WeaponResource should have ammo_type property")
	print("✓ WeaponResource is pure config (no scene-tree mutation methods)")


func test_weapon_manager_fire_methods_exist():
	print("\n--- Testing WeaponManager Public Fire Methods ---")
	
	# We can't instantiate WeaponManager without a scene, but we can verify the class exists
	# and check method existence via script inspection
	var script = load("res://scenes/systems/weapon_manager/weapon_manager.gd") as GDScript
	assert(script != null, "WeaponManager script should load")
	
	# Check that the script source contains the new public methods
	var source = script.source_code
	assert("func try_fire()" in source, "WeaponManager should have try_fire method")
	assert("func try_auto_fire()" in source, "WeaponManager should have try_auto_fire method")
	assert("func start_auto_hitting()" in source, "WeaponManager should have start_auto_hitting method")
	assert("func stop_auto_hitting()" in source, "WeaponManager should have stop_auto_hitting method")
	
	# Verify input polling is removed
	assert("Input.is_action_just_pressed" not in source, "WeaponManager should not poll Input directly")
	assert("_unhandled_input" not in source, "WeaponManager should not have _unhandled_input")
	print("✓ WeaponManager has public fire methods and no input polling")


func test_weapon_manager_delegates_to_controllers():
	print("\n--- Testing WeaponManager delegates to extracted controllers ---")
	
	var script = load("res://scenes/systems/weapon_manager/weapon_manager.gd") as GDScript
	var source = script.source_code
	
	assert("_fire_controller.try_fire" in source, "WeaponManager should delegate single-fire logic to WeaponFireController")
	assert("_fire_controller.try_auto_fire" in source, "WeaponManager should delegate auto-fire logic to WeaponFireController")
	assert("_fire_controller.consume_and_execute_hit" in source, "WeaponManager should delegate hit execution to WeaponFireController")
	assert("_equip_controller.switch_weapon" in source, "WeaponManager should delegate switch flow to WeaponEquipController")
	assert("_equip_controller.equip_selected_slot" in source, "WeaponManager should delegate equip flow to WeaponEquipController")
	assert("WeaponAnimationStateController.new()" in source, "WeaponManager should instantiate WeaponAnimationStateController via class_name")
	assert("WeaponAnimationStateControllerScript" not in source, "WeaponManager should not rely on a script-path preload alias for animation state controller")
	assert("_equip_controller.setup" in source, "WeaponManager should configure WeaponEquipController dependencies")
	assert("_ui_event_controller.forward_ammo_change" in source, "WeaponManager should delegate ammo UI forwarding to WeaponUiEventController")
	
	print("✓ WeaponManager delegates firing and equip boundaries to controllers")


func test_weapon_manager_uses_movement_intent_for_bobbing():
	print("\n--- Testing WeaponManager uses movement intent for bobbing ---")
	
	var script = load("res://scenes/systems/weapon_manager/weapon_manager.gd") as GDScript
	var source = script.source_code
	
	assert("var bob_velocity := _get_weapon_bob_velocity()" in source, "WeaponManager should derive a dedicated bob velocity")
	assert("player.movement_component" in source, "WeaponManager should consult PlayerMovementComponent for bob intent when available")
	assert("player.movement_component.get_direction()" in source, "WeaponManager should use movement direction for weapon bob intent")
	assert("player.movement_component.get_current_speed()" in source, "WeaponManager should use movement speed for weapon bob intent")
	assert("_bob_controller.update_speed(bob_velocity, delta)" in source, "WeaponManager should feed bob velocity into WeaponBobController")
	
	print("✓ WeaponManager uses movement intent for bobbing")


func test_weapon_manager_owns_ammo_wiring():
	print("\n--- Testing WeaponManager owns ammo wiring ---")
	
	var script = load("res://scenes/systems/weapon_manager/weapon_manager.gd") as GDScript
	var source = script.source_code
	
	# WeaponManager must delegate ammo wiring/retry ownership through the ammo controller
	assert("_ammo_controller.initialize_slot_wiring" in source, "WeaponManager should initialize ammo wiring via WeaponAmmoController")
	assert("_ammo_controller.ensure_weapon_wired" in source, "WeaponManager should delegate late ammo wiring to WeaponAmmoController")
	assert("func _setup_weapon_ammo_components" not in source, "WeaponManager should not own ammo wiring helper methods after A.2")
	
	# WeaponAmmoController should own retry and player ammo resolution semantics
	var ammo_script = load("res://scenes/systems/weapon_manager/weapon_ammo_controller.gd") as GDScript
	var ammo_source = ammo_script.source_code
	assert("func _get_player_ammo_component" in ammo_source, "WeaponAmmoController should resolve PlayerAmmoComponent")
	assert("func initialize_slot_wiring" in ammo_source, "WeaponAmmoController should own bulk ammo wiring initialization")
	assert("func ensure_weapon_wired" in ammo_source, "WeaponAmmoController should own late weapon wiring retry path")

	print("✓ WeaponAmmoController owns ammo wiring and retry semantics")


func test_player_no_ammo_wiring():
	print("\n--- Testing Player has no ammo wiring ---")
	
	var script = load("res://scenes/player/player.gd") as GDScript
	var source = script.source_code
	
	# Player must NOT have _setup_weapon_ammo_components (moved out of WeaponManager ownership)
	assert("func _setup_weapon_ammo_components" not in source, "Player should NOT have _setup_weapon_ammo_components (WeaponManager owns this)")
	
	print("✓ Player has no ammo wiring (WeaponManager owns it)")


func test_weapon_input_component_exists():
	print("\n--- Testing WeaponInputComponent ---")
	
	var script = load("res://scenes/components/input/weapon_input_component.gd") as GDScript
	assert(script != null, "WeaponInputComponent script should load")
	
	var source = script.source_code
	assert("weapon_manager.try_fire()" in source, "WeaponInputComponent should call try_fire")
	assert("weapon_manager.start_auto_hitting()" in source, "WeaponInputComponent should call start_auto_hitting")
	assert("weapon_manager.stop_auto_hitting()" in source, "WeaponInputComponent should call stop_auto_hitting")
	print("✓ WeaponInputComponent handles weapon input correctly")
