extends Node

## Tests for Phase 5: HUD/UI robustness
## Verifies that HUD uses explicit references instead of parent-chain traversal

func _ready():
	print("=== HUD ROBUSTNESS TESTS ===")
	
	test_hud_no_parent_chain_traversal()
	test_hud_explicit_container_references()
	test_hud_ownership_explicit()
	
	print("=== ALL HUD ROBUSTNESS TESTS COMPLETED ===")


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
	
	# Verify _get_hud_owner uses _connected_player instead of scene-tree discovery
	assert("return _connected_player" in source, "_get_hud_owner should return _connected_player")
	
	# Verify no scene-tree discovery in _get_hud_owner
	var get_hud_owner_start = source.find("func _get_hud_owner")
	var get_hud_owner_end = source.find("\nfunc ", get_hud_owner_start + 1)
	if get_hud_owner_end == -1:
		get_hud_owner_end = source.length()
	var get_hud_owner_body = source.substr(get_hud_owner_start, get_hud_owner_end - get_hud_owner_start)
	
	assert("get_parent()" not in get_hud_owner_body, "_get_hud_owner should not traverse scene tree")
	assert("get_children()" not in get_hud_owner_body, "_get_hud_owner should not iterate children")
	
	print("✓ HUD ownership is explicit via _connected_player")
