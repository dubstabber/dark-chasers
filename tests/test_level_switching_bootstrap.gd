extends Node

var _failed := false


func _ready() -> void:
	print("=== LEVEL SWITCHING BOOTSTRAP TESTS ===")
	_test_startup_scene_selection_uses_scene_catalog()
	_test_teleport_resolves_destination_via_scene_catalog()
	_test_transition_context_sanitization_strips_objects()
	await _test_spawn_handoff_uses_spawn_id_once()
	await _test_mansion_next_map_transitions_to_room_1()
	print("=== LEVEL SWITCHING BOOTSTRAP TESTS COMPLETED ===")
	get_tree().quit(1 if _failed else 0)


func _test_startup_scene_selection_uses_scene_catalog() -> void:
	print("\n--- Testing startup scene selection ---")
	var catalog: SceneCatalog = Services.get_scene_catalog()
	_assert(catalog != null, "Services.get_scene_catalog() should return a catalog")
	_assert(catalog.mansion_1_scene != null, "SceneCatalog.mansion_1_scene should be assigned")

	var game_root := GameRoot.new()
	game_root.skip_main_menu_for_dev = true
	_assert(game_root._select_startup_scene() == catalog.mansion_1_scene, "Skip-menu startup should select mansion_1 from catalog")

	game_root.skip_main_menu_for_dev = false
	if catalog.main_menu_scene:
		_assert(game_root._select_startup_scene() == catalog.main_menu_scene, "Non-skip startup should select main_menu_scene when configured")
	else:
		_assert(game_root._select_startup_scene() == catalog.mansion_1_scene, "Non-skip startup should fall back to mansion_1 when no menu scene is set")
	print("✓ Startup scene selection uses SceneCatalog")


func _test_teleport_resolves_destination_via_scene_catalog() -> void:
	print("\n--- Testing teleport catalog destination resolution ---")
	var catalog: SceneCatalog = Services.get_scene_catalog()
	_assert(catalog != null, "Services.get_scene_catalog() should return a catalog")
	_assert(catalog.fdm_backrooms_scene != null, "SceneCatalog.fdm_backrooms_scene should be assigned")

	var tp_scene := load("res://scenes/objects/teleport.tscn") as PackedScene
	_assert(tp_scene != null, "Teleport scene should load")
	var tp := tp_scene.instantiate() as Area3D
	_assert(tp != null, "Teleport scene should instantiate")
	tp.set("destination_catalog_key", &"fdm_backrooms_scene")
	var resolved := tp.call("_resolve_destination_scene") as PackedScene
	_assert(resolved == catalog.fdm_backrooms_scene, "Teleport should resolve destination from SceneCatalog using destination_catalog_key")
	tp.queue_free()
	print("✓ Teleport resolves destination via SceneCatalog")


func _test_transition_context_sanitization_strips_objects() -> void:
	print("\n--- Testing transition context sanitization ---")
	var lm := Services.level_manager as LevelManager
	_assert(lm != null, "Services.level_manager should be a LevelManager")

	var marker_node := Node.new()
	marker_node.name = "sanitization_marker"
	var ctx := {
		"spawn_id": "SpawnA",
		"bad_node": marker_node,
		"nested": {
			"ok": 1,
			"bad": marker_node,
		},
	}

	var sanitized: Dictionary = lm._sanitize_transition_context(ctx)
	_assert(sanitized.get("spawn_id") == "SpawnA", "Sanitized context should preserve primitive values")
	_assert(not sanitized.has("bad_node"), "Sanitized context should drop Object values")
	_assert(sanitized.get("nested", {}).get("ok") == 1, "Sanitized context should keep nested primitive values")
	_assert(not sanitized.get("nested", {}).has("bad"), "Sanitized context should drop nested Object values")
	print("✓ Transition context sanitization strips Objects")


func _test_spawn_handoff_uses_spawn_id_once() -> void:
	print("\n--- Testing spawn handoff ---")
	var lm := Services.level_manager as LevelManager
	_assert(lm != null, "Services.level_manager should be a LevelManager")

	# Create a minimal Level with a PlayerSpawners container and a named marker.
	var level := Level.new()
	# Level has @onready var hud = $HUD, so we must provide a HUD node before it enters the tree.
	var hud := Node.new()
	hud.name = "HUD"
	level.add_child(hud)

	var spawners := Node3D.new()
	spawners.name = "PlayerSpawners"
	spawners.unique_name_in_owner = true
	level.add_child(spawners)

	var marker_a := Marker3D.new()
	marker_a.name = "SpawnA"
	marker_a.position = Vector3(9, 2, 3)
	spawners.add_child(marker_a)

	var marker_b := Marker3D.new()
	marker_b.name = "Fallback"
	marker_b.position = Vector3(-4, 1, 7)
	spawners.add_child(marker_b)

	# Simulate a transition request targeting the current level node (scene_file_path is empty here).
	var prev_req: Dictionary = lm.get_last_transition_request()
	lm._last_transition_request = {
		"scene_path": "",
		"context": {"spawn_id": "SpawnA"},
		"timestamp": 0.0,
	}

	add_child(level)
	await get_tree().process_frame

	# Ensure respawn() uses the runtime-created spawners, not the %PlayerSpawners unique-name lookup.
	level.player_spawners = spawners

	# Level._ready() captures transition context, but call explicitly too (idempotent) to ensure signal.
	level._capture_initial_transition_context()
	lm._last_transition_request = prev_req

	var player := CharacterBody3D.new()
	level.respawn(player)
	_assert(player.position == marker_a.global_position, "Player should respawn at SpawnA marker when spawn_id is provided")

	# Ensure spawn_id is used only once.
	spawners.remove_child(marker_a)
	marker_a.queue_free()
	await get_tree().process_frame
	level.respawn(player)
	_assert(player.position == marker_b.global_position, "Second respawn should use fallback spawner once spawn_id is consumed")
	print("✓ Spawn handoff resolves spawn_id and falls back after first use")

	level.queue_free()


func _test_mansion_next_map_transitions_to_room_1() -> void:
	print("\n--- Testing mansion next-map transition to room_1 ---")
	var lm := Services.level_manager as LevelManager
	_assert(lm != null, "Services.level_manager should be a LevelManager")

	var host := Node.new()
	add_child(host)
	lm.register_level_host(host)

	var script := load("res://scenes/maps/mansion_1/mansion_1_events/mansion_1_area_events.gd")
	var events_node: Node = script.new()
	# The event arg is unused in the handler.
	events_node._on_area_change_to_next_map(RefCounted.new())
	await get_tree().process_frame

	var req: Dictionary = lm.get_last_transition_request()
	_assert(req.get("scene_path") == "res://scenes/maps/room_1.tscn", "Next-map handler should request room_1 transition")
	_assert(host.get_child_count() == 1, "LevelHost should contain exactly one active level")

	var active_level := host.get_child(0)
	_assert(active_level is Node, "Active level should be a Node")
	_assert((active_level as Node).scene_file_path == "res://scenes/maps/room_1.tscn", "LevelHost child should be room_1 scene")
	print("✓ Mansion next-map event triggers transition to room_1")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)
