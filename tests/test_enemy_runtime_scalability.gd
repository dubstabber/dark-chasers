extends SceneTree

var _failed := false


class MockEnemyContext extends Node:
	signal transitions_changed(transitions_node: Node3D)

	var transition_graph := {
		"RoomA": {"DoorAB": "RoomB"},
		"RoomB": {"DoorBC": "RoomC"},
		"RoomC": {},
	}
	var enemy_exceptions: Array = []

	func get_transition_graph() -> Dictionary:
		return transition_graph

	func get_enemy_exceptions() -> Array:
		return enemy_exceptions


func _init() -> void:
	print("=== ENEMY RUNTIME SCALABILITY TESTS ===")
	await _test_room_pathing_cache_invalidation()
	await _test_spawn_owner_caps_and_telemetry()
	_test_phase2_source_wiring()
	print("=== ENEMY RUNTIME SCALABILITY TESTS COMPLETED ===")
	quit(1 if _failed else 0)


func _test_room_pathing_cache_invalidation() -> void:
	print("\n--- Testing room-path cache invalidation ---")
	var context := MockEnemyContext.new()
	root.add_child(context)

	var room_pathing: RoomPathingComponent = RoomPathingComponent.new()
	room_pathing.set_enemy_context(context)
	root.add_child(room_pathing)

	var initial_path: Array = room_pathing.find_path_to_room("RoomA", "RoomC")
	_assert(initial_path == ["DoorAB", "DoorBC"], "RoomPathingComponent should find the initial BFS path")
	_assert(room_pathing.get_cache_entry_count() == 1, "Room path cache should store computed room pairs")

	context.transition_graph = {
		"RoomA": {"DoorAC": "RoomC"},
		"RoomC": {},
	}
	var transitions_node := Node3D.new()
	context.transitions_changed.emit(transitions_node)
	transitions_node.free()

	_assert(room_pathing.get_cache_entry_count() == 0, "Room path cache should clear when transitions change")
	var updated_path: Array = room_pathing.find_path_to_room("RoomA", "RoomC")
	_assert(updated_path == ["DoorAC"], "RoomPathingComponent should recompute against the updated transition graph")

	room_pathing.queue_free()
	context.queue_free()
	await process_frame
	print("✓ room-path cache invalidation works")


func _test_spawn_owner_caps_and_telemetry() -> void:
	print("\n--- Testing spawn owner caps and telemetry ---")
	var service: EnemySpawnOwnerService = EnemySpawnOwnerService.new()
	root.add_child(service)

	var parent := Node3D.new()
	root.add_child(parent)

	var prototype := Node3D.new()
	var scene := PackedScene.new()
	var packed := scene.pack(prototype)
	_assert(packed == OK, "Test enemy scene should pack successfully")
	prototype.free()

	var first_enemy: Node = service.spawn_enemy(scene, parent, Vector3(2, 0, 3), "", null, &"benchmark_owner", 1, true)
	var blocked_enemy: Node = service.spawn_enemy(scene, parent, Vector3.ZERO, "", null, &"benchmark_owner", 1, true)

	_assert(first_enemy != null, "Spawn owner should allow spawning below the active cap")
	_assert(blocked_enemy == null, "Spawn owner should block spawns once the active cap is reached")

	var owner_stats: Dictionary = service.get_owner_stats(&"benchmark_owner")
	_assert(owner_stats.get("attempted") == 2, "Spawn owner should track attempted spawns")
	_assert(owner_stats.get("spawned") == 1, "Spawn owner should track successful spawns")
	_assert(owner_stats.get("blocked") == 1, "Spawn owner should track blocked spawns")
	_assert(owner_stats.get("active") == 1, "Spawn owner should track active spawned enemies")

	first_enemy.queue_free()
	await process_frame
	await process_frame

	owner_stats = service.get_owner_stats(&"benchmark_owner")
	_assert(owner_stats.get("active") == 0, "Spawn owner should decrement active counts when spawned enemies exit")

	service.queue_free()
	parent.queue_free()
	await process_frame
	print("✓ spawn owner caps and telemetry work")


func _test_phase2_source_wiring() -> void:
	print("\n--- Testing Phase 2 source wiring ---")
	var ai_source := FileAccess.get_file_as_string("res://scenes/components/enemy/enemy_ai_component.gd")
	var timing_source := FileAccess.get_file_as_string("res://scenes/components/enemy/enemy_path_timing_controller.gd")
	var runtime_source := FileAccess.get_file_as_string("res://scenes/components/enemy/enemy_runtime_coordinator.gd")
	var sequence_source := FileAccess.get_file_as_string("res://scenes/services/sequence_director.gd")
	var spawner_source := FileAccess.get_file_as_string("res://scenes/components/enemy/enemy_spawner_controller.gd")
	var backrooms_source := FileAccess.get_file_as_string("res://scenes/maps/fdm_backrooms.gd")

	_assert("visibility_check_interval" in ai_source, "EnemyAIComponent should expose a throttled visibility check interval")
	_assert("_refresh_target_visibility_if_needed" in ai_source, "EnemyAIComponent should cache/refresh LOS checks behind a budget helper")
	_assert("func compute_staggered_wait_time" in timing_source, "EnemyPathTimingController should expose staggered repath timing")
	_assert("func compute_finished_navigation_repath_delay" in timing_source, "EnemyPathTimingController should expose staggered finished-navigation repath timing")
	_assert("_timing_stagger_factor" in runtime_source, "EnemyRuntimeCoordinator should keep a per-enemy timing stagger factor")
	_assert("Services.enemy_spawn_owner.spawn_enemy" in sequence_source, "SequenceDirector should route shared enemy spawns through EnemySpawnOwnerService")
	_assert("Services.enemy_spawn_owner.spawn_enemy" in spawner_source, "EnemySpawnerController should route shared enemy spawns through EnemySpawnOwnerService")
	_assert("max_active_enemies = enemy_spawners_container.get_child_count()" in backrooms_source, "FDM Backrooms should cap active spawned enemies by available spawners")
	print("✓ Phase 2 wiring is present")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)