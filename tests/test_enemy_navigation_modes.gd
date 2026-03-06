extends Node

const EnemyScene := preload("res://scenes/enemies/enemy.tscn")

var _failed := false


class MockTarget extends CharacterBody3D:
	var current_room: String = ""
	var _dead := false

	func is_dead() -> bool:
		return _dead

	func is_alive() -> bool:
		return not _dead


class MockTransitions extends Node3D:
	var map_transitions := {
		"RoomA": {"DoorAB": "RoomB"},
		"RoomB": {"DoorBA": "RoomA"},
	}
	var enemy_exceptions: Array = []

	func get_map_transitions() -> Dictionary:
		return map_transitions

	func get_enemy_exceptions() -> Array:
		return enemy_exceptions


func _ready() -> void:
	print("=".repeat(60))
	print("ENEMY NAVIGATION MODE TESTS")
	print("=".repeat(60))

	await _test_default_navigation_mode_selects_godot_component()
	await _test_doom_mode_disables_inactive_godot_navigation_agent()
	await _test_runtime_navigation_mode_swap_godot_to_doom()
	await _test_runtime_navigation_mode_swap_doom_to_godot()
	await _test_runtime_navigation_mode_swap_preserves_unsupported_fallbacks()
	await _test_missing_selected_navigation_component_falls_back_to_godot()
	await _test_doom_mode_ignores_vertical_navigation_callbacks()
	await _test_vertical_support_boundaries_fall_back_to_godot()
	await _test_room_transition_pathing_stays_compatible_in_both_modes()
	await _test_post_transition_refreshes_navigation_target_in_both_modes()
	await _test_multi_hop_room_transition_pathing_stays_compatible_in_both_modes()
	await _test_doom_mode_keeps_forward_chase_for_openable_doors_only()
	await _test_doom_mode_looks_ahead_for_non_openable_doors_beyond_probe_distance()

	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _test_default_navigation_mode_selects_godot_component() -> void:
	print("\n--- default mode selects Godot navigation ---")
	var enemy := EnemyScene.instantiate() as Enemy
	add_child(enemy)
	await get_tree().process_frame

	var godot_nav := enemy.get_node("GodotNavigationComponent") as GodotNavigationComponent
	var doom_nav := enemy.get_node("DoomNavigationComponent") as EnemyNavigationComponent
	var nav_agent := enemy.get_node("NavigationAgent3D") as NavigationAgent3D

	_assert(enemy.navigation_mode == Enemy.NavigationMode.GODOT, "Enemy should default to Godot navigation mode")
	_assert(enemy._nav_component == godot_nav, "Default active navigation component should be GodotNavigationComponent")
	_assert(godot_nav.is_navigation_active(), "Godot navigation should be active by default")
	_assert(nav_agent.process_mode != Node.PROCESS_MODE_DISABLED, "Default Godot mode should keep the NavigationAgent3D enabled")
	_assert(not doom_nav.is_navigation_active(), "Doom navigation scaffold should start inactive by default")
	print("✓ default mode selection")

	enemy.free()
	await get_tree().process_frame


func _test_doom_mode_disables_inactive_godot_navigation_agent() -> void:
	print("\n--- doom mode disables inactive Godot NavigationAgent3D ---")
	var enemy := EnemyScene.instantiate() as Enemy
	enemy.navigation_mode = Enemy.NavigationMode.DOOM
	add_child(enemy)
	await get_tree().process_frame

	var godot_nav := enemy.get_node("GodotNavigationComponent") as GodotNavigationComponent
	var doom_nav := enemy.get_node("DoomNavigationComponent") as EnemyNavigationComponent
	var nav_agent := enemy.get_node("NavigationAgent3D") as NavigationAgent3D

	_assert(enemy._nav_component == doom_nav, "Supported Doom mode should activate Doom navigation")
	_assert(not godot_nav.is_navigation_active(), "Godot navigation component should be inactive while Doom mode is active")
	_assert(nav_agent.process_mode == Node.PROCESS_MODE_DISABLED, "Doom mode should explicitly disable the inactive Godot NavigationAgent3D")
	print("✓ Doom mode disables inactive Godot NavigationAgent3D")

	enemy.free()
	await get_tree().process_frame


func _test_runtime_navigation_mode_swap_godot_to_doom() -> void:
	print("\n--- runtime swap from Godot to Doom keeps navigation state valid ---")
	await _assert_runtime_navigation_mode_swap(
		Enemy.NavigationMode.GODOT,
		Enemy.NavigationMode.DOOM,
		&"doom"
	)
	print("✓ runtime swap Godot -> Doom")


func _test_runtime_navigation_mode_swap_doom_to_godot() -> void:
	print("\n--- runtime swap from Doom to Godot keeps navigation state valid ---")
	await _assert_runtime_navigation_mode_swap(
		Enemy.NavigationMode.DOOM,
		Enemy.NavigationMode.GODOT,
		&"godot"
	)
	print("✓ runtime swap Doom -> Godot")


func _test_runtime_navigation_mode_swap_preserves_unsupported_fallbacks() -> void:
	print("\n--- runtime swap preserves unsupported Doom fallback behavior ---")
	await _assert_runtime_navigation_mode_swap(
		Enemy.NavigationMode.GODOT,
		Enemy.NavigationMode.DOOM,
		&"godot",
		true,
		false
	)
	await _assert_runtime_navigation_mode_swap(
		Enemy.NavigationMode.GODOT,
		Enemy.NavigationMode.DOOM,
		&"godot",
		false,
		true
	)
	print("✓ runtime swap fallback behavior")


func _test_missing_selected_navigation_component_falls_back_to_godot() -> void:
	print("\n--- missing selected component falls back safely ---")
	var enemy := EnemyScene.instantiate() as Enemy
	enemy.navigation_mode = Enemy.NavigationMode.DOOM
	var doom_nav := enemy.get_node("DoomNavigationComponent")
	doom_nav.get_parent().remove_child(doom_nav)
	doom_nav.free()

	add_child(enemy)
	await get_tree().process_frame

	var godot_nav := enemy.get_node("GodotNavigationComponent") as GodotNavigationComponent
	var nav_agent := enemy.get_node("NavigationAgent3D") as NavigationAgent3D
	_assert(enemy._nav_component == godot_nav, "Enemy should fall back to Godot navigation when the requested mode is unavailable")
	_assert(godot_nav.is_navigation_active(), "Fallback Godot navigation should be active")
	_assert(nav_agent.process_mode != Node.PROCESS_MODE_DISABLED, "Fallback Godot navigation should keep the NavigationAgent3D enabled")
	print("✓ fallback selection")

	enemy.free()
	await get_tree().process_frame


func _test_doom_mode_ignores_vertical_navigation_callbacks() -> void:
	print("\n--- doom mode ignores vertical navigation callbacks ---")
	var enemy := EnemyScene.instantiate() as Enemy
	enemy.navigation_mode = Enemy.NavigationMode.DOOM
	add_child(enemy)
	await get_tree().process_frame

	enemy._motor_component.jump_speed = 5.0
	enemy.velocity = Vector3.ZERO

	var jump_link := Node.new()
	jump_link.add_to_group("jump-up")
	enemy._on_navigation_link_reached({"owner": jump_link})
	enemy._on_navigation_waypoint_reached({})

	_assert(enemy._nav_component.get_navigation_mode_id() == &"doom", "Doom mode should activate DoomNavigationComponent")
	_assert(is_equal_approx(enemy._motor_component.jump_speed, 5.0), "Doom mode should ignore jump-up and jump-down navigation callbacks")
	_assert(is_equal_approx(enemy.velocity.y, 0.0), "Doom mode should not apply jump velocity from navigation callbacks")
	print("✓ Doom mode ignores vertical callbacks")

	jump_link.free()
	enemy.free()
	await get_tree().process_frame


func _test_vertical_support_boundaries_fall_back_to_godot() -> void:
	print("\n--- vertical/flying support boundaries fall back to Godot ---")
	await _assert_doom_request_falls_back_to_godot(true, false)
	await _assert_doom_request_falls_back_to_godot(false, true)
	print("✓ vertical/flying boundary fallback")


func _test_room_transition_pathing_stays_compatible_in_both_modes() -> void:
	print("\n--- room transition pathing stays compatible in both modes ---")
	await _assert_transition_mode(Enemy.NavigationMode.GODOT)
	await _assert_transition_mode(Enemy.NavigationMode.DOOM)
	print("✓ transition pathing compatibility")


func _test_post_transition_refreshes_navigation_target_in_both_modes() -> void:
	print("\n--- post-transition path refresh stays compatible in both modes ---")
	await _assert_post_transition_refresh(Enemy.NavigationMode.GODOT)
	await _assert_post_transition_refresh(Enemy.NavigationMode.DOOM)
	print("✓ post-transition path refresh compatibility")


func _test_multi_hop_room_transition_pathing_stays_compatible_in_both_modes() -> void:
	print("\n--- multi-hop room transition pathing stays compatible in both modes ---")
	await _assert_multi_hop_transition_pathing(Enemy.NavigationMode.GODOT)
	await _assert_multi_hop_transition_pathing(Enemy.NavigationMode.DOOM)
	print("✓ multi-hop transition pathing compatibility")


func _test_doom_mode_keeps_forward_chase_for_openable_doors_only() -> void:
	print("\n--- doom mode keeps forward chase only for openable doors ---")
	await _assert_doom_door_blocking_policy(true)
	await _assert_doom_door_blocking_policy(false)
	print("✓ Doom door blocking policy compatibility")


func _test_doom_mode_looks_ahead_for_non_openable_doors_beyond_probe_distance() -> void:
	print("\n--- doom mode door lookahead reaches past probe distance ---")
	await _assert_doom_door_blocking_policy(true, 1.0)
	await _assert_doom_door_blocking_policy(false, 1.0)
	print("✓ Doom door lookahead compatibility")


func _assert_doom_request_falls_back_to_godot(flying: bool, vertical_required: bool) -> void:
	var enemy := EnemyScene.instantiate() as Enemy
	enemy.navigation_mode = Enemy.NavigationMode.DOOM
	enemy.is_flying = flying
	enemy.requires_vertical_navigation = vertical_required
	add_child(enemy)
	await get_tree().process_frame

	var godot_nav := enemy.get_node("GodotNavigationComponent") as GodotNavigationComponent
	var doom_nav := enemy.get_node("DoomNavigationComponent") as EnemyNavigationComponent
	var nav_agent := enemy.get_node("NavigationAgent3D") as NavigationAgent3D
	var label := "flying" if flying else "vertical"

	_assert(enemy.navigation_mode == Enemy.NavigationMode.DOOM, "%s boundary should preserve Doom as the requested navigation mode" % label)
	_assert(enemy._nav_component == godot_nav, "%s boundary should activate Godot navigation as the supported runtime mode" % label)
	_assert(godot_nav.is_navigation_active(), "%s boundary should keep Godot navigation active" % label)
	_assert(nav_agent.process_mode != Node.PROCESS_MODE_DISABLED, "%s boundary should keep the Godot NavigationAgent3D enabled" % label)
	_assert(not doom_nav.is_navigation_active(), "%s boundary should disable Doom navigation when unsupported" % label)

	if vertical_required:
		enemy._motor_component.jump_speed = 0.0
		enemy.velocity = Vector3.ZERO
		var jump_link := Node.new()
		jump_link.add_to_group("jump-up")
		enemy._on_navigation_link_reached({"owner": jump_link})
		_assert(enemy.velocity.y > 0.0, "Vertical-navigation fallback should preserve Godot jump-up handling")
		_assert(enemy._motor_component.jump_speed > 0.0, "Vertical-navigation fallback should preserve Godot jump-speed bookkeeping")
		jump_link.free()

	enemy.free()
	await get_tree().process_frame


func _assert_runtime_navigation_mode_swap(
	initial_mode: Enemy.NavigationMode,
	requested_mode_after_swap: Enemy.NavigationMode,
	expected_runtime_mode_id: StringName,
	flying := false,
	vertical_required := false
) -> void:
	var transitions := _create_transitions_node()
	add_child(transitions)
	Services.enemy_context.set_transitions_node(transitions)

	var enemy := EnemyScene.instantiate() as Enemy
	enemy.navigation_mode = initial_mode
	enemy.current_room = "RoomA"
	enemy.is_flying = flying
	enemy.requires_vertical_navigation = vertical_required
	add_child(enemy)

	var target := MockTarget.new()
	target.current_room = "RoomB"
	target.position = Vector3(20.0, 0.0, 2.0)
	add_child(target)

	await get_tree().process_frame

	enemy.current_target = target
	enemy.makepath()

	var transition_component := enemy.get_node("EnemyTransitionComponent") as EnemyTransitionComponent
	var runtime_coordinator := enemy.get_node("EnemyRuntimeCoordinator") as EnemyRuntimeCoordinator
	var godot_nav := enemy.get_node("GodotNavigationComponent") as GodotNavigationComponent
	var doom_nav := enemy.get_node("DoomNavigationComponent") as DoomNavigationComponent
	var nav_agent := enemy.get_node("NavigationAgent3D") as NavigationAgent3D
	var transition_node := transitions.get_node("DoorAB") as Node3D

	_assert(transition_component.pending_transition_name == "DoorAB", "Runtime swap should start from a pending room transition")

	enemy.navigation_mode = requested_mode_after_swap
	await get_tree().process_frame

	var active_nav := enemy._nav_component
	var inactive_nav: EnemyNavigationComponent = godot_nav
	if active_nav == godot_nav:
		inactive_nav = doom_nav
	var swap_label := "%s -> %s" % [_mode_name(initial_mode), _mode_name(requested_mode_after_swap)]

	_assert(enemy.navigation_mode == requested_mode_after_swap, "Runtime swap %s should preserve the requested Enemy.navigation_mode" % swap_label)
	_assert(active_nav.get_navigation_mode_id() == expected_runtime_mode_id, "Runtime swap %s should activate the expected runtime navigation component" % swap_label)
	_assert(runtime_coordinator._nav_component == active_nav, "Runtime swap %s should rebind the runtime coordinator to the active navigation component" % swap_label)
	_assert(transition_component._nav_component == active_nav, "Runtime swap %s should rebind the transition component to the active navigation component" % swap_label)
	_assert(transition_component.pending_transition_name == "DoorAB", "Runtime swap %s should preserve pending transition routing" % swap_label)
	_assert(active_nav.target_position.is_equal_approx(transition_node.global_position), "Runtime swap %s should refresh the active navigation target to the pending transition node" % swap_label)
	_assert(nav_agent.process_mode == (Node.PROCESS_MODE_DISABLED if expected_runtime_mode_id == &"doom" else Node.PROCESS_MODE_INHERIT), "Runtime swap %s should keep the Godot NavigationAgent3D in the expected enabled state" % swap_label)

	inactive_nav.target_reached.emit()
	_assert(enemy.current_room == "RoomA", "Runtime swap %s should ignore target_reached signals from the inactive navigation component" % swap_label)
	_assert(transition_component.pending_transition_name == "DoorAB", "Runtime swap %s should keep transition state untouched when the inactive component emits" % swap_label)

	active_nav.target_reached.emit()
	_assert(enemy.current_room == "RoomB", "Runtime swap %s should keep active-component target_reached handling working after the swap" % swap_label)
	_assert(transition_component.pending_transition_name == "", "Runtime swap %s should clear pending transition state after the active component completes the hop" % swap_label)
	_assert(active_nav.target_position.is_equal_approx(target.global_position), "Runtime swap %s should retarget the active navigation component to the chased target after the handled transition" % swap_label)
	_assert(not enemy.find_path_timer.is_stopped(), "Runtime swap %s should keep the delayed repath scheduled after the handled transition" % swap_label)

	Services.enemy_context.set_transitions_node(null)
	target.free()
	enemy.free()
	transitions.free()
	await get_tree().process_frame


func _assert_transition_mode(mode: Enemy.NavigationMode) -> void:
	var transitions := _create_transitions_node()
	add_child(transitions)
	Services.enemy_context.set_transitions_node(transitions)

	var enemy := EnemyScene.instantiate() as Enemy
	enemy.navigation_mode = mode
	enemy.current_room = "RoomA"
	add_child(enemy)

	var target := MockTarget.new()
	target.current_room = "RoomB"
	target.position = Vector3(20.0, 0.0, 2.0)
	add_child(target)

	await get_tree().process_frame

	enemy.current_target = target
	enemy.makepath()

	var transition_component := enemy.get_node("EnemyTransitionComponent") as EnemyTransitionComponent
	var transition_node := transitions.get_node("DoorAB") as Node3D
	var spawn_marker := transition_node.get_node("SpawnPoint") as Marker3D

	_assert(transition_component.pending_transition_name == "DoorAB", "Mode %s should keep room-transition BFS routing" % _mode_name(mode))
	_assert(enemy._nav_component.target_position.is_equal_approx(transition_node.global_position), "Mode %s should target the transition node position" % _mode_name(mode))
	_assert(transition_component.handle_target_reached(), "Mode %s should still execute room transitions" % _mode_name(mode))
	_assert(enemy.current_room == "RoomB", "Mode %s should update the enemy room after a handled transition" % _mode_name(mode))
	_assert(enemy.global_position.is_equal_approx(spawn_marker.global_position), "Mode %s should move the enemy to the transition spawn marker" % _mode_name(mode))

	Services.enemy_context.set_transitions_node(null)
	target.free()
	enemy.free()
	transitions.free()
	await get_tree().process_frame


func _assert_post_transition_refresh(mode: Enemy.NavigationMode) -> void:
	var transitions := _create_transitions_node()
	add_child(transitions)
	Services.enemy_context.set_transitions_node(transitions)

	var enemy := EnemyScene.instantiate() as Enemy
	enemy.navigation_mode = mode
	enemy.current_room = "RoomA"
	add_child(enemy)

	var target := MockTarget.new()
	target.current_room = "RoomB"
	target.position = Vector3(20.0, 0.0, 2.0)
	add_child(target)

	await get_tree().process_frame

	enemy.current_target = target
	enemy.makepath()

	var transition_component := enemy.get_node("EnemyTransitionComponent") as EnemyTransitionComponent
	_assert(transition_component.handle_target_reached(), "Mode %s should execute a room transition before testing post-transition refresh" % _mode_name(mode))
	_assert(enemy.current_room == "RoomB", "Mode %s should land in the destination room before refreshing navigation" % _mode_name(mode))
	_assert(transition_component.pending_transition_name == "", "Mode %s should clear pending transition state after landing in the destination room" % _mode_name(mode))
	_assert(enemy._nav_component.target_position.is_equal_approx(target.global_position), "Mode %s should immediately retarget local navigation to the chased target after the room transition" % _mode_name(mode))
	_assert(not enemy.find_path_timer.is_stopped(), "Mode %s should still schedule the short delayed repath after an immediate post-transition refresh" % _mode_name(mode))

	Services.enemy_context.set_transitions_node(null)
	target.free()
	enemy.free()
	transitions.free()
	await get_tree().process_frame


func _assert_multi_hop_transition_pathing(mode: Enemy.NavigationMode) -> void:
	var transitions := _create_multi_hop_transitions_node()
	add_child(transitions)
	Services.enemy_context.set_transitions_node(transitions)

	var enemy := EnemyScene.instantiate() as Enemy
	enemy.navigation_mode = mode
	enemy.current_room = "RoomA"
	add_child(enemy)

	var target := MockTarget.new()
	target.current_room = "RoomC"
	target.position = Vector3(24.0, 0.0, 4.0)
	add_child(target)

	await get_tree().process_frame

	enemy.current_target = target
	enemy.makepath()

	var transition_component := enemy.get_node("EnemyTransitionComponent") as EnemyTransitionComponent
	var transition_ab := transitions.get_node("DoorAB") as Node3D
	var transition_bc := transitions.get_node("DoorBC") as Node3D
	var spawn_ab := transition_ab.get_node("SpawnPoint") as Marker3D
	var spawn_bc := transition_bc.get_node("SpawnPoint") as Marker3D

	_assert(transition_component.pending_transition_name == "DoorAB", "Mode %s should route to the first hop transition when the target is two rooms away" % _mode_name(mode))
	_assert(enemy._nav_component.target_position.is_equal_approx(transition_ab.global_position), "Mode %s should target the first transition node before the initial hop" % _mode_name(mode))
	_assert(transition_component.handle_target_reached(), "Mode %s should execute the first hop of a multi-hop room transition" % _mode_name(mode))
	_assert(enemy.current_room == "RoomB", "Mode %s should land in the intermediate room after the first hop" % _mode_name(mode))
	_assert(enemy.global_position.is_equal_approx(spawn_ab.global_position), "Mode %s should move the enemy to the first hop spawn marker" % _mode_name(mode))
	_assert(transition_component.pending_transition_name == "DoorBC", "Mode %s should immediately queue the second hop after entering the intermediate room" % _mode_name(mode))
	_assert(enemy._nav_component.target_position.is_equal_approx(transition_bc.global_position), "Mode %s should retarget local navigation to the second hop transition after the first teleport" % _mode_name(mode))

	_assert(transition_component.handle_target_reached(), "Mode %s should execute the second hop of a multi-hop room transition" % _mode_name(mode))
	_assert(enemy.current_room == "RoomC", "Mode %s should land in the final room after the second hop" % _mode_name(mode))
	_assert(enemy.global_position.is_equal_approx(spawn_bc.global_position), "Mode %s should move the enemy to the second hop spawn marker" % _mode_name(mode))
	_assert(transition_component.pending_transition_name == "", "Mode %s should clear pending transition state after the final hop reaches the target room" % _mode_name(mode))
	_assert(enemy._nav_component.target_position.is_equal_approx(target.global_position), "Mode %s should retarget local navigation to the chased target after the final hop" % _mode_name(mode))
	_assert(not enemy.find_path_timer.is_stopped(), "Mode %s should keep the delayed repath scheduled after completing consecutive room transitions" % _mode_name(mode))

	Services.enemy_context.set_transitions_node(null)
	target.free()
	enemy.free()
	transitions.free()
	await get_tree().process_frame


func _assert_doom_door_blocking_policy(front_allowed: bool, door_distance: float = 0.72) -> void:
	var harness := Node3D.new()
	harness.name = "DoorHarnessAllowed" if front_allowed else "DoorHarnessBlocked"
	add_child(harness)

	var enemy := EnemyScene.instantiate() as Enemy
	enemy.navigation_mode = Enemy.NavigationMode.DOOM
	enemy.position = Vector3.ZERO
	harness.add_child(enemy)
	var collision_shape := enemy.get_node("CollisionShape3D") as CollisionShape3D
	var shape := SphereShape3D.new()
	shape.radius = 0.2
	collision_shape.shape = shape

	var target := MockTarget.new()
	target.position = Vector3(0.0, 0.0, -6.0)
	harness.add_child(target)

	var corridor_left := _create_wall(Vector3(-0.48, 0.0, -0.35), Vector3(0.12, 0.6, 0.9))
	var corridor_right := _create_wall(Vector3(0.48, 0.0, -0.35), Vector3(0.12, 0.6, 0.9))
	harness.add_child(corridor_left)
	harness.add_child(corridor_right)

	var door := load("res://scenes/objects/ao_door2.tscn").instantiate() as Door
	door.position = Vector3(-0.64, 0.0, -door_distance)
	door.allow_front = front_allowed
	door.allow_back = front_allowed
	door.allow_left = false
	door.allow_right = false
	harness.add_child(door)

	await get_tree().process_frame
	await get_tree().physics_frame
	var interaction_ray := enemy.get_node("Interaction") as RayCast3D
	interaction_ray.force_raycast_update()
	var door_opener := enemy.get_node("EnemyDoorOpenerComponent") as EnemyDoorOpenerComponent
	var ray_collider := interaction_ray.get_collider() as Node
	_assert(ray_collider != null, "Doom door test should place a real door directly in front of the interaction ray")
	_assert(door_opener.can_open_door_for_collision(ray_collider, interaction_ray.get_collision_point()) == front_allowed,
		"Door opener collision query should match whether the directly-ahead door is openable")

	enemy.current_target = target
	enemy.makepath()

	var doom_nav := enemy.get_node("DoomNavigationComponent") as DoomNavigationComponent
	var forward_dir := doom_nav.get_horizontal_direction()
	var forward_dot := forward_dir.dot(Vector3.FORWARD)
	var lookahead_label := "within door lookahead range" if door_distance > doom_nav.movement_probe_distance else "within probe range"

	if front_allowed:
		_assert(forward_dot > 0.9, "Doom mode should keep pressing toward an openable front door instead of immediately rerouting (%s)" % lookahead_label)
	else:
		_assert(forward_dot < 0.25, "Doom mode should still treat a non-openable front door as blocked (%s)" % lookahead_label)

	harness.free()
	await get_tree().process_frame


func _create_transitions_node() -> Node3D:
	var transitions := MockTransitions.new()
	transitions.name = "Transitions"

	var door := Node3D.new()
	door.name = "DoorAB"
	door.position = Vector3(3.0, 0.0, 7.0)

	var spawn := Marker3D.new()
	spawn.name = "SpawnPoint"
	spawn.position = Vector3(1.0, 0.0, -2.0)
	spawn.add_to_group("spawn_point")
	door.add_child(spawn)

	transitions.add_child(door)
	return transitions


func _create_multi_hop_transitions_node() -> Node3D:
	var transitions := MockTransitions.new()
	transitions.name = "Transitions"
	transitions.map_transitions = {
		"RoomA": {"DoorAB": "RoomB"},
		"RoomB": {"DoorBC": "RoomC"},
		"RoomC": {}
	}

	var door_ab := Node3D.new()
	door_ab.name = "DoorAB"
	door_ab.position = Vector3(3.0, 0.0, 7.0)
	var spawn_ab := Marker3D.new()
	spawn_ab.name = "SpawnPoint"
	spawn_ab.position = Vector3(1.0, 0.0, -2.0)
	spawn_ab.add_to_group("spawn_point")
	door_ab.add_child(spawn_ab)
	transitions.add_child(door_ab)

	var door_bc := Node3D.new()
	door_bc.name = "DoorBC"
	door_bc.position = Vector3(14.0, 0.0, 11.0)
	var spawn_bc := Marker3D.new()
	spawn_bc.name = "SpawnPoint"
	spawn_bc.position = Vector3(-1.5, 0.0, -3.0)
	spawn_bc.add_to_group("spawn_point")
	door_bc.add_child(spawn_bc)
	transitions.add_child(door_bc)

	return transitions


func _create_wall(position: Vector3, half_extents: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.position = position

	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = half_extents * 2.0
	collision_shape.shape = shape
	body.add_child(collision_shape)
	return body


func _mode_name(mode: Enemy.NavigationMode) -> String:
	return "DOOM" if mode == Enemy.NavigationMode.DOOM else "GODOT"


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)