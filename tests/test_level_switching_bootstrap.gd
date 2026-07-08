extends Node

var _failed := false


class MockHUD extends CanvasLayer:
	func connect_to_player(_provider: Node) -> void:
		pass

	func add_log(_message: String) -> void:
		pass

	func update_keys_display(_keys: Array) -> void:
		pass

	func show_event_text_for_player(_player: CharacterBody3D, _text: String, _faded: bool = true, _text_time: float = 0.0) -> void:
		pass


func _ready() -> void:
	print("=== LEVEL SWITCHING BOOTSTRAP TESTS ===")
	_test_startup_scene_selection_uses_scene_catalog()
	_test_teleport_resolves_destination_via_scene_catalog()
	_test_transition_context_sanitization_strips_objects()
	_test_mansion_spawn_uses_level_base_flow()
	await _test_level_auto_spawns_player_once()
	await _test_spawn_handoff_uses_spawn_id_once()
	await _test_unique_test_spawn_overrides_spawn_id()
	await _test_non_unique_test_spawn_uses_normal_selection()
	await _test_mansion_next_map_transitions_to_mansion_2()
	print("=== LEVEL SWITCHING BOOTSTRAP TESTS COMPLETED ===")
	get_tree().quit(1 if _failed else 0)


func _test_startup_scene_selection_uses_scene_catalog() -> void:
	print("\n--- Testing startup scene selection ---")
	var catalog: SceneCatalog = Services.get_scene_catalog()
	_assert(catalog != null, "Services.get_scene_catalog() should return a catalog")
	var mansion_1 := catalog.get_map_scene(&"mansion_1")
	_assert(mansion_1 != null, "SceneCatalog should contain map id 'mansion_1'")
	var room_1 := catalog.get_map_scene(&"room_1")
	_assert(room_1 != null, "SceneCatalog should contain map id 'room_1'")

	var game_root := GameRoot.new()
	game_root.skip_main_menu_for_dev = true
	game_root.default_game_scene = room_1
	_assert(game_root._select_startup_scene() == room_1, "Skip-menu startup should prefer GameRoot.default_game_scene when assigned")

	game_root.default_game_scene = null
	_assert(game_root._select_startup_scene() == mansion_1, "Skip-menu startup should select mansion_1 from catalog")

	game_root.skip_main_menu_for_dev = false
	game_root.main_menu_scene = room_1
	_assert(game_root._select_startup_scene() == room_1, "Non-skip startup should prefer GameRoot.main_menu_scene when assigned")

	game_root.main_menu_scene = null
	var main_menu := catalog.get_main_menu_scene()
	if main_menu:
		_assert(game_root._select_startup_scene() == main_menu, "Non-skip startup should select main_menu when configured")
	else:
		_assert(game_root._select_startup_scene() == mansion_1, "Non-skip startup should fall back to mansion_1 when no menu scene is set")
	print("✓ Startup scene selection uses SceneCatalog")


func _test_teleport_resolves_destination_via_scene_catalog() -> void:
	print("\n--- Testing teleport catalog destination resolution ---")
	var catalog: SceneCatalog = Services.get_scene_catalog()
	_assert(catalog != null, "Services.get_scene_catalog() should return a catalog")
	var fdm_backrooms := catalog.get_map_scene(&"fdm_backrooms")
	_assert(fdm_backrooms != null, "SceneCatalog should contain map id 'fdm_backrooms'")

	var tp_scene := load("res://scenes/objects/teleport.tscn") as PackedScene
	_assert(tp_scene != null, "Teleport scene should load")
	var tp := tp_scene.instantiate() as Area3D
	_assert(tp != null, "Teleport scene should instantiate")
	tp.set("destination_catalog_key", &"fdm_backrooms_scene")
	var resolved := tp.call("_resolve_destination_scene") as PackedScene
	_assert(resolved == fdm_backrooms, "Teleport should resolve destination from SceneCatalog using destination_catalog_key")
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


func _test_mansion_spawn_uses_level_base_flow() -> void:
	print("\n--- Testing mansion spawn uses Level base flow ---")
	var source := FileAccess.get_file_as_string("res://scenes/maps/mansion_1/mansion_1.gd")
	_assert("var player: Player = super.spawn_player()" in source, "Mansion spawn should delegate player creation/respawn to Level.spawn_player")
	_assert("super.respawn(player)" in source, "Mansion respawn should delegate marker placement to Level.respawn")
	_assert("const USE_TEST_SPAWN := false" in source, "Mansion should keep test spawn support disabled by default")
	_assert("func test_respawn(player: CharacterBody3D) -> void:" in source, "Mansion should keep the quick-test test_respawn helper")
	_assert("if USE_TEST_SPAWN:" in source, "Mansion spawn should keep a dedicated quick-test branch")
	_assert("player.blocked_movement = false" in source, "Mansion quick-test spawn should allow immediate movement")
	_assert("await hud.hide_event_text()" in source, "Mansion intro should await caption hide before fading the black screen")
	_assert("Services.get_scene_catalog().get_player_scene().instantiate()" not in source, "Mansion spawn should not manually instantiate the player anymore")
	print("✓ Mansion spawn delegates to the current Level architecture")


func _test_level_auto_spawns_player_once() -> void:
	print("\n--- Testing Level default auto-spawn ---")
	var level := _create_minimal_level()
	var marker := Marker3D.new()
	marker.name = "Start"
	marker.position = Vector3(3, 1, -5)
	level.get_node("PlayerSpawners").add_child(marker)

	add_child(level)

	var players_node := level.players as Node3D
	_assert(players_node != null, "Minimal Level should resolve %Players")
	_assert(players_node.get_child_count() == 1, "Level._ready should auto-spawn exactly one player")
	var player := players_node.get_child(0) as Player
	_assert(player != null, "Auto-spawned child should be a Player")
	_assert(player.global_position == marker.global_position, "Auto-spawned player should be placed at a PlayerSpawners Marker3D")

	var respawned_player := level.spawn_player()
	_assert(respawned_player == player, "Calling spawn_player again should reuse the existing player")
	_assert(players_node.get_child_count() == 1, "Repeated spawn_player should not duplicate players")
	print("✓ Level auto-spawns one player and keeps spawn_player idempotent")

	level.queue_free()
	await get_tree().process_frame


func _test_spawn_handoff_uses_spawn_id_once() -> void:
	print("\n--- Testing spawn handoff ---")
	var lm := Services.level_manager as LevelManager
	_assert(lm != null, "Services.level_manager should be a LevelManager")

	# Create a minimal Level with a PlayerSpawners container and a named marker.
	var level := Level.new()
	level.auto_spawn_player = false
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
	level.add_child(player)
	await get_tree().process_frame
	var marker_a_position := marker_a.global_position
	var marker_b_position := marker_b.global_position
	level.respawn(player)
	_assert(player.global_position == marker_a_position, "Player should respawn at SpawnA marker when spawn_id is provided")

	# Ensure spawn_id is used only once.
	spawners.remove_child(marker_a)
	marker_a.queue_free()
	await get_tree().process_frame
	level.respawn(player)
	_assert(player.global_position == marker_b_position, "Second respawn should use fallback spawner once spawn_id is consumed")
	print("✓ Spawn handoff resolves spawn_id and falls back after first use")

	level.queue_free()
	await get_tree().process_frame


func _test_unique_test_spawn_overrides_spawn_id() -> void:
	print("\n--- Testing unique TestSpawn priority ---")
	var level := Level.new()
	level.auto_spawn_player = false
	var hud := MockHUD.new()
	hud.name = "HUD"
	level.add_child(hud)

	var spawners := Node3D.new()
	spawners.name = "PlayerSpawners"
	level.add_child(spawners)

	var spawn_a := Marker3D.new()
	spawn_a.name = "SpawnA"
	spawn_a.position = Vector3(9, 2, 3)
	spawners.add_child(spawn_a)

	var test_spawn := Marker3D.new()
	test_spawn.name = "TestSpawn"
	test_spawn.unique_name_in_owner = true
	test_spawn.position = Vector3(-12, 4, 6)
	spawners.add_child(test_spawn)

	add_child(level)
	await get_tree().process_frame
	level.player_spawners = spawners

	level._initial_spawn_id = &"SpawnA"
	var player := CharacterBody3D.new()
	level.add_child(player)
	await get_tree().process_frame
	level.respawn(player)

	_assert(player.global_position == test_spawn.global_position, "Unique TestSpawn should override transition spawn_id")
	_assert(level._initial_spawn_consumed, "Unique TestSpawn should consume the initial spawn attempt")
	print("✓ Unique TestSpawn is the only active default spawner")

	level.queue_free()
	await get_tree().process_frame


func _test_non_unique_test_spawn_uses_normal_selection() -> void:
	print("\n--- Testing non-unique TestSpawn fallback ---")
	var level := Level.new()
	level.auto_spawn_player = false
	var hud := MockHUD.new()
	hud.name = "HUD"
	level.add_child(hud)

	var spawners := Node3D.new()
	spawners.name = "PlayerSpawners"
	level.add_child(spawners)

	var spawn_a := Marker3D.new()
	spawn_a.name = "SpawnA"
	spawn_a.position = Vector3(2, 0, 8)
	spawners.add_child(spawn_a)

	var test_spawn := Marker3D.new()
	test_spawn.name = "TestSpawn"
	test_spawn.position = Vector3(-7, 0, -3)
	spawners.add_child(test_spawn)

	add_child(level)
	await get_tree().process_frame
	level.player_spawners = spawners

	level._initial_spawn_id = &"SpawnA"
	var player := CharacterBody3D.new()
	level.add_child(player)
	await get_tree().process_frame
	level.respawn(player)

	_assert(player.global_position == spawn_a.global_position, "Non-unique TestSpawn should not override spawn_id selection")
	print("✓ Non-unique TestSpawn remains a normal marker")

	level.queue_free()
	await get_tree().process_frame


func _test_mansion_next_map_transitions_to_mansion_2() -> void:
	print("\n--- Testing mansion next-map transition to mansion_2 ---")
	var lm := Services.level_manager as LevelManager
	_assert(lm != null, "Services.level_manager should be a LevelManager")

	var host := Node.new()
	add_child(host)
	lm.register_level_host(host)

	var script := load("res://scenes/maps/mansion_1/mansion_1_events/mansion_1_area_events.gd")
	var events_node: Node = script.new()
	# The event arg is unused in the handler.
	events_node._on_area_change_to_next_map(GameEvent.new(GameEventTypes.AREA_CHANGE_TO_NEXT_MAP))
	await get_tree().process_frame

	var req: Dictionary = lm.get_last_transition_request()
	_assert(req.get("scene_path") == "res://scenes/maps/mansion_2/mansion_2.tscn", "Next-map handler should request mansion_2 transition")
	_assert(host.get_child_count() == 1, "LevelHost should contain exactly one active level")

	var active_level := host.get_child(0)
	_assert(active_level is Node, "Active level should be a Node")
	_assert((active_level as Node).scene_file_path == "res://scenes/maps/mansion_2/mansion_2.tscn", "LevelHost child should be mansion_2 scene")
	print("✓ Mansion next-map event triggers transition to mansion_2")
	host.queue_free()
	await get_tree().process_frame


func _create_minimal_level() -> Level:
	var level := Level.new()

	var hud := MockHUD.new()
	hud.name = "HUD"
	level.add_child(hud)

	var spawners := Node3D.new()
	spawners.name = "PlayerSpawners"
	spawners.unique_name_in_owner = true
	level.add_child(spawners)

	var players := Node3D.new()
	players.name = "Players"
	players.unique_name_in_owner = true
	level.add_child(players)

	return level


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)
