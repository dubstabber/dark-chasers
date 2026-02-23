extends Node

## Tests for Phase 5: HUD/UI robustness
## Verifies that HUD uses explicit references instead of parent-chain traversal

func _ready():
	print("=== HUD ROBUSTNESS TESTS ===")
	
	test_hud_no_parent_chain_traversal()
	test_hud_explicit_container_references()
	test_hud_ownership_explicit()
	test_hud_uses_provider_contract()
	test_hud_player_signal_binding_delegation()
	test_hud_log_label_scene_reference_decoupled()
	test_hud_provider_connection_flow()
	test_hud_update_flow_callbacks()
	test_hud_binding_controller_provider_wiring()
	
	print("=== ALL HUD ROBUSTNESS TESTS COMPLETED ===")
	get_tree().quit()


func test_hud_no_parent_chain_traversal():
	print("\n--- Testing HUD has no parent-chain traversal ---")
	
	var script = load("res://scenes/hud.gd") as GDScript
	assert(script != null, "HUD script should load")
	
	var source = script.source_code
	
	# Verify no get_parent().get_parent() chains in _set_player_ui_visible
	assert("get_parent().get_parent()" not in source, "HUD should not use get_parent().get_parent() chains")
	assert("get_parent().get_parent().get_parent()" not in source, "HUD should not use deep parent chains")
	
	print("✓ HUD has no parent-chain traversal")


func test_hud_explicit_container_references():
	print("\n--- Testing HUD has explicit container references ---")
	
	var script = load("res://scenes/hud.gd") as GDScript
	var source = script.source_code
	
	# Verify explicit @onready references exist
	assert("bottom_left_container" in source, "HUD should have bottom_left_container reference")
	assert("bottom_right_container" in source, "HUD should have bottom_right_container reference")
	assert("$BottomLeft" in source or "%BottomLeft" in source, "HUD should reference BottomLeft explicitly")
	assert("$BottomRight" in source or "%BottomRight" in source, "HUD should reference BottomRight explicitly")
	
	print("✓ HUD has explicit container references")


func test_hud_ownership_explicit():
	print("\n--- Testing HUD ownership is explicit ---")
	
	var script = load("res://scenes/hud.gd") as GDScript
	var source = script.source_code
	
	# Verify _get_hud_owner uses _connected_provider instead of scene-tree discovery
	assert("return _connected_provider" in source, "_get_hud_owner should return _connected_provider")
	
	# Verify no scene-tree discovery in _get_hud_owner
	var get_hud_owner_start = source.find("func _get_hud_owner")
	var get_hud_owner_end = source.find("\nfunc ", get_hud_owner_start + 1)
	if get_hud_owner_end == -1:
		get_hud_owner_end = source.length()
	var get_hud_owner_body = source.substr(get_hud_owner_start, get_hud_owner_end - get_hud_owner_start)
	
	assert("get_parent()" not in get_hud_owner_body, "_get_hud_owner should not traverse scene tree")
	assert("get_children()" not in get_hud_owner_body, "_get_hud_owner should not iterate children")
	
	print("✓ HUD ownership is explicit via _connected_provider")


func test_hud_uses_provider_contract():
	print("\n--- Testing HUD uses provider contract ---")

	var script = load("res://scenes/hud.gd") as GDScript
	var source = script.source_code

	assert("HudDataProvider.get_health_component" in source, "HUD should resolve health via HudDataProvider")
	assert("HudDataProvider.get_armor_component" in source, "HUD should resolve armor via HudDataProvider")
	assert("HudDataProvider.get_current_weapon" in source, "HUD should resolve weapon via HudDataProvider")
	assert("connect_to_player(provider: Node)" in source, "HUD connect_to_player should accept a provider Node")

	print("✓ HUD uses HudDataProvider contract")


func test_hud_player_signal_binding_delegation():
	print("\n--- Testing HUD delegates player signal wiring ---")
	
	var script = load("res://scenes/hud.gd") as GDScript
	var source = script.source_code
	
	assert("HudPlayerBindingController.new()" in source, "HUD should instantiate HudPlayerBindingController via class_name")
	assert("HudPlayerBindingControllerScript" not in source, "HUD should not rely on script-path preload alias for binding controller")
	assert("_player_binding_controller.connect_player_signals" in source, "HUD should delegate connect_to_player signal wiring")
	assert("_player_binding_controller.disconnect_player_signals" in source, "HUD should delegate disconnect_from_player signal wiring")
	
	print("✓ HUD delegates player signal wiring to HudPlayerBindingController")


func test_hud_log_label_scene_reference_decoupled():
	print("\n--- Testing HUD log label scene reference is decoupled ---")

	var hud_script = load("res://scenes/hud.gd") as GDScript
	var source = hud_script.source_code

	assert("@export var log_label_scene: PackedScene" in source, "HUD should expose log_label_scene as an exported PackedScene")
	assert("preload(\"res://scenes/ui/log_label.tscn\")" not in source, "HUD should not hardcode log_label.tscn preload in script")
	assert("if not log_label_scene:" in source, "HUD should guard missing log_label_scene assignment")

	var hud_scene_source := FileAccess.get_file_as_string("res://scenes/hud.tscn")
	assert("log_label_scene = ExtResource" in hud_scene_source, "HUD scene should assign exported log_label_scene")
	assert("res://scenes/ui/log_label.tscn" in hud_scene_source, "HUD scene should reference log_label scene resource")

	print("✓ HUD log label scene is configured via exported scene reference")


func test_hud_provider_connection_flow():
	print("\n--- Testing HUD provider connect/disconnect flow ---")

	var script = load("res://scenes/hud.gd") as GDScript
	var source = script.source_code

	assert("if _connected_provider == provider" in source, "HUD should skip duplicate provider rebind")
	assert("_connected_provider = provider" in source, "HUD should store connected provider")
	assert("_reserve_ammo_callback = Callable(self, \"_on_player_reserve_ammo_changed\").bind(provider)" in source, "HUD should bind reserve ammo callback to provider")
	assert("_player_binding_controller.connect_player_signals(" in source, "HUD should connect via binding controller")
	assert("_player_binding_controller.disconnect_player_signals(" in source, "HUD should disconnect via binding controller")
	assert("_connected_provider = null" in source, "HUD should clear provider on disconnect")

	print("✓ HUD provider connect/disconnect flow is explicit")


func test_hud_update_flow_callbacks():
	print("\n--- Testing HUD update callback flow (health/armor/ammo) ---")

	var script = load("res://scenes/hud.gd") as GDScript
	var source = script.source_code

	var health_body = _get_function_body(source, "func _on_player_health_changed")
	assert("update_health_display(current_health, max_health)" in health_body, "Health callback should update HUD health display")

	var armor_body = _get_function_body(source, "func _on_player_armor_changed")
	assert("update_armor_display(current_armor, max_armor)" in armor_body, "Armor callback should update HUD armor display")

	var ammo_body = _get_function_body(source, "func _on_player_ammo_changed")
	assert("update_ammo_display(current_ammo, max_ammo)" in ammo_body, "Weapon ammo callback should update HUD ammo display")

	var reserve_body = _get_function_body(source, "func _on_player_reserve_ammo_changed")
	assert("weapon.ammo_type == ammo_type" in reserve_body, "Reserve callback should filter by ammo type")
	assert("update_ammo_display(current_amount, max_amount)" in reserve_body, "Reserve callback should update HUD ammo display")

	var initialize_body = _get_function_body(source, "func _initialize_ammo_from_provider")
	assert("HudDataProvider.get_current_weapon(provider)" in initialize_body, "HUD should initialize ammo using provider weapon")
	assert("update_ammo_display(weapon.get_current_ammo(), weapon.get_max_ammo_amount())" in initialize_body, "HUD should initialize ammo display from weapon values")

	print("✓ HUD callbacks drive health/armor/ammo update flow")


func test_hud_binding_controller_provider_wiring():
	print("\n--- Testing HUD binding controller provider wiring ---")

	var script = load("res://scenes/components/player/hud_player_binding_controller.gd") as GDScript
	var source = script.source_code

	assert("HudDataProvider.get_health_component(provider)" in source, "Binding controller should resolve health via provider contract")
	assert("HudDataProvider.get_armor_component(provider)" in source, "Binding controller should resolve armor via provider contract")
	assert("HudDataProvider.get_weapon_manager(provider)" in source, "Binding controller should resolve weapon manager via provider contract")
	assert("HudDataProvider.get_ammo_component(provider)" in source, "Binding controller should resolve ammo via provider contract")
	assert("health_component.health_changed.connect(health_changed_callback)" in source, "Binding controller should wire health signal")
	assert("armor_component.armor_changed.connect(armor_changed_callback)" in source, "Binding controller should wire armor signal")
	assert("weapon_manager.weapon_ammo_changed.connect(weapon_ammo_changed_callback)" in source, "Binding controller should wire weapon ammo signal")
	assert("weapon_manager.weapon_switched.connect(weapon_switched_callback)" in source, "Binding controller should wire weapon switched signal")
	assert("ammo_component.ammo_changed.connect(reserve_ammo_changed_callback)" in source, "Binding controller should wire reserve ammo signal")
	assert("damage_effects_component.color_rect = null" in source, "Binding controller should clear damage overlay on disconnect")

	print("✓ HUD binding controller uses provider contract for wiring")


func _get_function_body(source: String, function_signature_prefix: String) -> String:
	var start := source.find(function_signature_prefix)
	assert(start != -1, "Expected function not found: %s" % function_signature_prefix)
	var end := source.find("\nfunc ", start + 1)
	if end == -1:
		end = source.length()
	return source.substr(start, end - start)
