extends Node

const EnemyScene := preload("res://scenes/enemies/enemy.tscn")
const TeleportScene := preload("res://scenes/objects/teleport.tscn")
const TransitionArrivalMarkerScript := preload("res://scenes/components/transition/transition_arrival_marker.gd")

var _failed := false


class MockRoomBody extends CharacterBody3D:
	var current_room: String = ""


class MockTransitions extends Node3D:
	var map_transitions := {"RoomA": {"DoorAB": "RoomB"}}
	var enemy_exceptions: Array = []

	func get_map_transitions() -> Dictionary:
		return map_transitions

	func get_enemy_exceptions() -> Array:
		return enemy_exceptions


class MockEnemyContext extends Node:
	var transition_graph := {"RoomA": {"DoorAB": "RoomB"}}
	var transitions_node: Node3D = null

	func get_transition_graph() -> Dictionary:
		return transition_graph

	func get_transitions_node() -> Node3D:
		return transitions_node


func _ready() -> void:
	print("=".repeat(60))
	print("TRANSITION ARRIVAL ROTATION TESTS")
	print("=".repeat(60))

	await _test_level_transition_matches_marker_yaw()
	await _test_manual_transit_keep_current_preserves_yaw()
	await _test_enemy_transition_matches_marker_yaw()
	await _test_invalid_config_and_missing_marker_degrade_safely()

	if _failed:
		push_error("Transition arrival rotation tests failed")
		get_tree().quit(1)
		return

	print("All transition arrival rotation tests passed")
	get_tree().quit(0)


func _test_level_transition_matches_marker_yaw() -> void:
	var space := _create_test_space()
	var level := Level.new()
	level.transitions = MockTransitions.new()

	var body := MockRoomBody.new()
	space.add_child(body)
	body.current_room = "RoomA"
	body.global_rotation = Vector3(0.0, -0.4, 0.0)

	var marker := TransitionArrivalMarkerScript.new()
	space.add_child(marker)
	marker.arrival_rotation_mode = TransitionArrival.RotationMode.MATCH_MARKER_YAW
	marker.global_position = Vector3(4.0, 0.0, -2.0)
	marker.global_rotation = Vector3(0.2, 1.2, -0.1)

	level.handle_transition(body, "DoorAB", marker)

	_assert_true(body.global_position.is_equal_approx(marker.global_position), "Level transition should use marker position")
	_assert_float_eq(body.global_rotation.y, marker.global_rotation.y, "Level transition should copy marker yaw")
	_assert_float_eq(body.global_rotation.x, 0.0, "Level yaw-only mode should preserve pitch")
	_assert_true(body.current_room == "RoomB", "Level transition should update current_room")

	space.queue_free()
	await get_tree().process_frame


func _test_manual_transit_keep_current_preserves_yaw() -> void:
	var space := _create_test_space()
	var component := InteractionComponent.new()
	var player := CharacterBody3D.new()
	space.add_child(player)
	var interaction_ray := RayCast3D.new()
	player.add_child(interaction_ray)
	interaction_ray.enabled = true
	interaction_ray.target_position = Vector3(0.0, 0.0, -4.0)
	interaction_ray.collision_mask = 1
	player.global_rotation = Vector3(0.0, 0.75, 0.0)
	component.player = player
	component.interaction_raycast = interaction_ray
	space.add_child(component)
	var forward := -player.global_basis.z
	var target_position := player.global_position + forward * 2.0

	var blocker := StaticBody3D.new()
	space.add_child(blocker)
	blocker.global_position = target_position
	blocker.collision_layer = 1
	var blocker_shape := CollisionShape3D.new()
	blocker.add_child(blocker_shape)
	blocker_shape.shape = BoxShape3D.new()

	await get_tree().process_frame
	await get_tree().physics_frame
	interaction_ray.force_raycast_update()

	_assert_true(not component.try_interact(), "Manual transit should not trigger when raycast does not hit a manual_transition node")
	_assert_true(player.global_position.is_equal_approx(Vector3.ZERO), "Manual transit should not move player without a manual_transition hit")
	_assert_true(not component.has_pending_transit(), "Manual transit should not arm from unrelated raycast hits")

	blocker.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame

	var transition_body := StaticBody3D.new()
	space.add_child(transition_body)
	transition_body.add_to_group("manual_transition")
	transition_body.global_position = target_position
	transition_body.collision_layer = 1
	var transition_shape := CollisionShape3D.new()
	transition_body.add_child(transition_shape)
	transition_shape.shape = BoxShape3D.new()

	var marker := TransitionArrivalMarkerScript.new()
	transition_body.add_child(marker)
	marker.arrival_rotation_mode = TransitionArrival.RotationMode.KEEP_CURRENT
	marker.position = Vector3(-3.0, 0.0, 6.0)
	marker.global_rotation = Vector3(0.0, 2.4, 0.0)

	await get_tree().process_frame
	await get_tree().physics_frame
	interaction_ray.force_raycast_update()

	_assert_true(component.try_interact(), "Manual transit should trigger when raycast hits a manual_transition node")

	_assert_true(player.global_position.is_equal_approx(marker.global_position), "Manual transit should still use marker position")
	_assert_float_eq(player.global_rotation.y, 0.75, "KEEP_CURRENT should preserve player yaw")
	_assert_true(not component.has_pending_transit(), "Manual transit should clear pending transit")

	space.queue_free()
	await get_tree().process_frame


func _test_enemy_transition_matches_marker_yaw() -> void:
	var space := _create_test_space()
	var enemy := EnemyScene.instantiate()
	space.add_child(enemy)
	await get_tree().process_frame

	enemy.current_room = "RoomA"
	enemy.global_rotation = Vector3(0.0, -0.6, 0.0)
	enemy.velocity = Vector3(3.0, 0.0, 1.0)

	var transitions := Node3D.new()
	space.add_child(transitions)
	var transition_node := Area3D.new()
	transition_node.name = "DoorAB"
	transitions.add_child(transition_node)

	var marker := TransitionArrivalMarkerScript.new()
	transition_node.add_child(marker)
	marker.arrival_rotation_mode = TransitionArrival.RotationMode.MATCH_MARKER_YAW
	marker.add_to_group("spawn_point")
	marker.global_position = Vector3(8.0, 0.0, -5.0)
	marker.global_rotation = Vector3(0.35, 0.9, -0.4)

	var component := enemy.get_node("EnemyTransitionComponent") as EnemyTransitionComponent
	var enemy_context := MockEnemyContext.new()
	enemy_context.transitions_node = transitions
	component._enemy_context = enemy_context
	component._execute_transition(transition_node)

	_assert_true(enemy.global_position.is_equal_approx(marker.global_position), "Enemy transition should use marker position")
	_assert_float_eq(enemy.global_rotation.y, marker.global_rotation.y, "Enemy transition should copy marker yaw")
	_assert_true(enemy.current_room == "RoomB", "Enemy transition should update current_room")
	_assert_true(enemy.velocity.is_zero_approx(), "Enemy transition should reset velocity after teleport")

	space.queue_free()
	await get_tree().process_frame


func _test_invalid_config_and_missing_marker_degrade_safely() -> void:
	var space := _create_test_space()
	var body := CharacterBody3D.new()
	space.add_child(body)
	body.global_rotation = Vector3(0.0, 0.55, 0.0)

	var invalid_marker := TransitionArrivalMarkerScript.new()
	space.add_child(invalid_marker)
	invalid_marker.arrival_rotation_mode = 99
	invalid_marker.global_position = Vector3(1.0, 0.0, 2.0)
	invalid_marker.global_rotation = Vector3(0.0, 2.8, 0.0)

	var applied := TransitionArrival.apply(body, invalid_marker)
	_assert_true(applied, "Invalid rotation mode should fall back safely")
	_assert_true(body.global_position.is_equal_approx(invalid_marker.global_position), "Invalid config should still use marker position")
	_assert_float_eq(body.global_rotation.y, 0.55, "Invalid config should keep current yaw")
	_assert_true(not TransitionArrival.apply(body, null), "Missing marker should fail safely without moving")

	var teleport := TeleportScene.instantiate()
	space.add_child(teleport)
	var traveler := CharacterBody3D.new()
	space.add_child(traveler)
	traveler.global_position = Vector3(7.0, 0.0, 7.0)
	teleport._on_body_entered(traveler)
	_assert_true(traveler.global_position.is_equal_approx(Vector3(7.0, 0.0, 7.0)), "Teleport without marker should not move the body")

	var level := Level.new()
	var player_spawners := Node3D.new()
	space.add_child(player_spawners)
	level.player_spawners = player_spawners
	level._initial_spawn_id = &"SpawnA"

	var spawn_marker := TransitionArrivalMarkerScript.new()
	player_spawners.add_child(spawn_marker)
	spawn_marker.name = "SpawnA"
	spawn_marker.arrival_rotation_mode = 99
	spawn_marker.global_position = Vector3(-4.0, 0.0, 1.0)

	var player := CharacterBody3D.new()
	space.add_child(player)
	player.global_rotation = Vector3(0.0, -1.1, 0.0)
	level.respawn(player)

	_assert_true(player.global_position.is_equal_approx(spawn_marker.global_position), "Respawn should still use spawn marker position")
	_assert_float_eq(player.global_rotation.y, -1.1, "Respawn should preserve yaw when config is invalid")

	space.queue_free()
	await get_tree().process_frame


func _create_test_space() -> Node3D:
	var space := Node3D.new()
	add_child(space)
	return space


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)


func _assert_float_eq(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	_assert_true(is_equal_approx(actual, expected) or absf(actual - expected) <= tolerance, "%s (expected %.4f, got %.4f)" % [message, expected, actual])