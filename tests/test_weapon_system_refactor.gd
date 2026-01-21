extends Node

## Tests for Phase 3 weapon system refactoring
## Tests WeaponHitExecutor and WeaponManager public fire methods

func _ready():
	print("=== WEAPON SYSTEM REFACTOR TESTS ===")
	
	test_weapon_hit_executor_creation()
	test_weapon_resource_is_pure_config()
	test_weapon_manager_fire_methods_exist()
	
	print("=== ALL WEAPON SYSTEM REFACTOR TESTS COMPLETED ===")


func test_weapon_hit_executor_creation():
	print("\n--- Testing WeaponHitExecutor Creation ---")
	
	var executor = WeaponHitExecutor.new()
	assert(executor != null, "WeaponHitExecutor should be instantiable")
	
	# Test that setup method exists
	assert(executor.has_method("setup"), "Executor should have setup method")
	assert(executor.has_method("execute_hit"), "Executor should have execute_hit method")
	print("✓ WeaponHitExecutor created successfully")


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
	var script = load("res://weapon_manager/weapon_manager.gd") as GDScript
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


func test_weapon_input_component_exists():
	print("\n--- Testing WeaponInputComponent ---")
	
	var script = load("res://scenes/components/input/weapon_input_component.gd") as GDScript
	assert(script != null, "WeaponInputComponent script should load")
	
	var source = script.source_code
	assert("weapon_manager.try_fire()" in source, "WeaponInputComponent should call try_fire")
	assert("weapon_manager.start_auto_hitting()" in source, "WeaponInputComponent should call start_auto_hitting")
	assert("weapon_manager.stop_auto_hitting()" in source, "WeaponInputComponent should call stop_auto_hitting")
	print("✓ WeaponInputComponent handles weapon input correctly")
