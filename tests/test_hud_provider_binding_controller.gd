extends Node


func _ready() -> void:
	print("=== HUD PROVIDER BINDING CONTROLLER CONTRACT TESTS ===")
	test_binding_controller_uses_provider_adapter()
	test_binding_controller_signal_wiring_contract()
	print("=== HUD PROVIDER BINDING CONTROLLER CONTRACT TESTS COMPLETED ===")
	get_tree().quit()


func test_binding_controller_uses_provider_adapter() -> void:
	print("\n--- Testing provider adapter usage ---")

	var script = load("res://scenes/components/player/hud_player_binding_controller.gd") as GDScript
	assert(script != null, "HUD binding controller script should load")

	var source = script.source_code
	assert("const HudDataProvider = preload(\"res://scenes/interfaces/hud_data_provider.gd\")" in source, "Binding controller should preload HudDataProvider")
	assert("HudDataProvider.get_health_component(provider)" in source, "Binding controller should resolve health via provider")
	assert("HudDataProvider.get_armor_component(provider)" in source, "Binding controller should resolve armor via provider")
	assert("HudDataProvider.get_weapon_manager(provider)" in source, "Binding controller should resolve weapon manager via provider")
	assert("HudDataProvider.get_ammo_component(provider)" in source, "Binding controller should resolve ammo via provider")
	assert("HudDataProvider.get_damage_effects_component(provider)" in source, "Binding controller should resolve damage effects via provider")

	print("✓ Binding controller uses provider adapter")


func test_binding_controller_signal_wiring_contract() -> void:
	print("\n--- Testing signal wiring contract ---")

	var script = load("res://scenes/components/player/hud_player_binding_controller.gd") as GDScript
	var source = script.source_code

	assert("health_component.health_changed.connect(health_changed_callback)" in source, "Should connect health_changed signal")
	assert("armor_component.armor_changed.connect(armor_changed_callback)" in source, "Should connect armor_changed signal")
	assert("weapon_manager.weapon_ammo_changed.connect(weapon_ammo_changed_callback)" in source, "Should connect weapon_ammo_changed signal")
	assert("weapon_manager.weapon_switched.connect(weapon_switched_callback)" in source, "Should connect weapon_switched signal")
	assert("ammo_component.ammo_changed.connect(reserve_ammo_changed_callback)" in source, "Should connect reserve ammo signal")
	assert("damage_effects_component.color_rect = damage_overlay" in source, "Should bind damage overlay on connect")
	assert("damage_effects_component.color_rect = null" in source, "Should clear damage overlay on disconnect")

	print("✓ Signal wiring contract is present")
