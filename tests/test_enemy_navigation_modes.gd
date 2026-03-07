extends Node

const EnemyScene := preload("res://scenes/enemies/enemy.tscn")
const FuwattyScene := preload("res://scenes/enemies/fuwatty.tscn")

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


class MockNavigationComponent extends EnemyNavigationComponent:
	var mock_finished := true
	var mock_next_path_position := Vector3.ZERO
	var mock_horizontal_direction := Vector3.ZERO
	var mock_distance_to_target := 0.0
	var use_base_horizontal_direction := false
	var stack_next_path_on_owner := false
	var stacked_next_path_offset := Vector3.ZERO

	func get_navigation_mode_id() -> StringName:
		return &"mock"

	func _on_target_set(_pos: Vector3) -> void:
		pass

	func get_next_path_position() -> Vector3:
		if stack_next_path_on_owner and _owner_enemy:
			return _owner_enemy.global_position + stacked_next_path_offset
		return mock_next_path_position

	func get_horizontal_direction() -> Vector3:
		if use_base_horizontal_direction:
			return super.get_horizontal_direction()
		return mock_horizontal_direction

	func is_target_reached() -> bool:
		return mock_finished

	func distance_to_target() -> float:
		return mock_distance_to_target

	func is_navigation_finished() -> bool:
		return mock_finished


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
	await _test_finished_navigation_does_not_direct_chase_cross_room_target()
	await _test_finished_navigation_same_room_keeps_flat_ground_direct_fallback()
	await _test_finished_navigation_same_room_repaths_instead_of_direct_shoving_uphill()
	await _test_active_navigation_vertical_stall_recovers_with_nav_target_direction()
	await _test_active_navigation_vertical_stall_preserves_transition_waypoint_direction()
	await _test_active_navigation_flat_zero_direction_does_not_force_recovery()
	await _test_post_transition_uphill_chase_stays_mobile_on_real_terrain()
	await _test_active_vertical_offset_uphill_chase_stays_mobile_on_real_terrain()
	await _test_flat_ground_chase_physics_remains_stable()
	await _test_post_transition_refreshes_navigation_target_in_both_modes()
	await _test_post_transition_resets_stale_chase_motion_in_godot_mode()
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


func _test_finished_navigation_does_not_direct_chase_cross_room_target() -> void:
	print("\n--- finished navigation stays transition-aware for cross-room chase ---")
	await _assert_finished_navigation_holds_transition_routing(Enemy.NavigationMode.GODOT)
	await _assert_finished_navigation_holds_transition_routing(Enemy.NavigationMode.DOOM)
	print("✓ finished-navigation transition awareness")


func _test_finished_navigation_same_room_keeps_flat_ground_direct_fallback() -> void:
	print("\n--- finished navigation keeps flat-ground direct fallback ---")
	await _assert_same_room_finished_navigation_fallback(Vector3(4.0, 0.0, 0.0), true)
	print("✓ flat-ground finished-navigation fallback")


func _test_finished_navigation_same_room_repaths_instead_of_direct_shoving_uphill() -> void:
	print("\n--- finished navigation repaths instead of direct shoving on uphill chase ---")
	await _assert_same_room_finished_navigation_fallback(Vector3(4.0, 1.2, 0.0), false)
	print("✓ uphill finished-navigation repath")


func _test_active_navigation_vertical_stall_recovers_with_nav_target_direction() -> void:
	print("\n--- active uphill stall recovers using nav target direction ---")
	await _assert_active_navigation_vertical_stall_recovery(
		"RoomA",
		Vector3(4.0, 1.2, 0.0),
		Vector3(4.0, 1.2, 0.0),
		Vector3(0.0, 1.2, 0.0),
		Vector3.RIGHT,
		true
	)
	print("✓ active uphill stall recovery")


func _test_active_navigation_vertical_stall_preserves_transition_waypoint_direction() -> void:
	print("\n--- active uphill stall keeps following the nav waypoint during room transitions ---")
	await _assert_active_navigation_vertical_stall_recovery(
		"RoomB",
		Vector3(20.0, 0.0, 0.0),
		Vector3(0.0, 1.2, 5.0),
		Vector3(0.0, 1.2, 0.0),
		Vector3.BACK,
		true
	)
	print("✓ active uphill stall stays path-aware")


func _test_active_navigation_flat_zero_direction_does_not_force_recovery() -> void:
	print("\n--- flat zero-direction chase does not trigger uphill stall recovery ---")
	await _assert_active_navigation_vertical_stall_recovery(
		"RoomA",
		Vector3(4.0, 0.0, 0.0),
		Vector3(4.0, 0.0, 0.0),
		Vector3.ZERO,
		Vector3.ZERO,
		false
	)
	print("✓ flat zero-direction guard")


func _test_post_transition_uphill_chase_stays_mobile_on_real_terrain() -> void:
	print("\n--- post-transition uphill chase stays mobile on real terrain ---")
	await _assert_fuwatty_chase_physics_stays_mobile(true, true)
	print("✓ post-transition uphill chase mobility")


func _test_active_vertical_offset_uphill_chase_stays_mobile_on_real_terrain() -> void:
	print("\n--- active vertical-offset uphill chase stays mobile on real terrain ---")
	await _assert_fuwatty_chase_physics_stays_mobile(true, false)
	print("✓ active uphill chase mobility")


func _test_flat_ground_chase_physics_remains_stable() -> void:
	print("\n--- flat-ground chase physics remains stable ---")
	await _assert_fuwatty_chase_physics_stays_mobile(false, false)
	print("✓ flat-ground chase stability")


func _test_post_transition_refreshes_navigation_target_in_both_modes() -> void:
	print("\n--- post-transition path refresh stays compatible in both modes ---")
	await _assert_post_transition_refresh(Enemy.NavigationMode.GODOT)
	await _assert_post_transition_refresh(Enemy.NavigationMode.DOOM)
	print("✓ post-transition path refresh compatibility")


func _test_post_transition_resets_stale_chase_motion_in_godot_mode() -> void:
	print("\n--- post-transition reset clears stale Godot chase motion state ---")
	await _assert_post_transition_resets_stale_motion_state()
	print("✓ post-transition stale-motion reset")


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


func _assert_finished_navigation_holds_transition_routing(mode: Enemy.NavigationMode) -> void:
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
	var runtime_coordinator := enemy.get_node("EnemyRuntimeCoordinator") as EnemyRuntimeCoordinator
	var transition_node := transitions.get_node("DoorAB") as Node3D

	_assert(transition_component.pending_transition_name == "DoorAB", "Mode %s should start from a pending transition before the finished-navigation regression check" % _mode_name(mode))
	_assert(not transition_component.is_target_in_same_room(), "Mode %s should recognize that the chased target is still in another room" % _mode_name(mode))

	enemy.global_position = transition_node.global_position
	enemy.velocity = Vector3.ZERO
	enemy.direction = Vector3.ZERO
	runtime_coordinator._process_chase_movement(0.1)

	_assert(Vector2(enemy.velocity.x, enemy.velocity.z).length() <= 0.001, "Mode %s should not direct-shove toward an out-of-room target when local navigation is already finished at a pending transition" % _mode_name(mode))
	_assert(enemy.direction.length() <= 0.001, "Mode %s should keep direction neutral until the pending transition is actually handled" % _mode_name(mode))

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


func _assert_post_transition_resets_stale_motion_state() -> void:
	var transitions := _create_transitions_node()
	add_child(transitions)
	Services.enemy_context.set_transitions_node(transitions)

	var enemy := EnemyScene.instantiate() as Enemy
	enemy.navigation_mode = Enemy.NavigationMode.GODOT
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
	var motor_component := enemy.get_node("EnemyMotorComponent") as EnemyMotorComponent
	var nav_agent := enemy.get_node("NavigationAgent3D") as NavigationAgent3D

	enemy.velocity = Vector3(-4.0, -1.5, 2.0)
	enemy.direction = Vector3(-0.8, 0.0, 0.2).normalized()
	motor_component.direction = Vector3(-0.8, 0.0, 0.2).normalized()
	motor_component.jump_speed = 6.0
	nav_agent.velocity = Vector3(-3.0, 0.0, 1.0)
	nav_agent.set_velocity_forced(Vector3(-3.0, 0.0, 1.0))

	_assert(transition_component.handle_target_reached(), "Godot mode should execute a room transition before testing stale-motion reset")
	_assert(enemy.current_room == "RoomB", "Godot mode should complete the room transition before validating stale-motion cleanup")
	_assert(enemy.velocity.is_equal_approx(Vector3.ZERO), "Godot post-transition reset should clear carried velocity so chase does not inherit stale pre-transition motion")
	_assert(enemy.direction.is_equal_approx(Vector3.ZERO), "Godot post-transition reset should clear carried chase direction so the next uphill steer comes from refreshed navigation")
	_assert(motor_component.direction.is_equal_approx(Vector3.ZERO), "Godot post-transition reset should clear the motor direction cache")
	_assert(is_equal_approx(motor_component.jump_speed, 0.0), "Godot post-transition reset should clear jump-speed carryover before renewed chase movement")
	_assert(nav_agent.velocity.is_equal_approx(Vector3.ZERO), "Godot post-transition reset should clear NavigationAgent3D avoidance velocity after teleport")
	_assert(enemy._nav_component.target_position.is_equal_approx(target.global_position), "Godot post-transition reset should still retarget chase navigation to the player immediately")
	_assert(not enemy.find_path_timer.is_stopped(), "Godot post-transition reset should preserve the delayed repath safety refresh")

	Services.enemy_context.set_transitions_node(null)
	target.free()
	enemy.free()
	transitions.free()
	await get_tree().process_frame


func _assert_same_room_finished_navigation_fallback(target_offset: Vector3, expect_direct_fallback: bool) -> void:
	var enemy := EnemyScene.instantiate() as Enemy
	enemy.current_room = "RoomA"
	add_child(enemy)

	var target := MockTarget.new()
	target.current_room = "RoomA"
	target.position = target_offset
	add_child(target)

	await get_tree().process_frame

	enemy.current_target = target
	enemy.global_position = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	enemy.direction = Vector3.ZERO
	enemy.find_path_timer.stop()
	enemy.find_path_timer.wait_time = 0.8

	var runtime_coordinator := enemy.get_node("EnemyRuntimeCoordinator") as EnemyRuntimeCoordinator
	var mock_nav := MockNavigationComponent.new()
	mock_nav.mock_finished = true
	runtime_coordinator._nav_component = mock_nav

	runtime_coordinator._process_chase_movement(0.1)

	var horizontal_speed := Vector2(enemy.velocity.x, enemy.velocity.z).length()
	if expect_direct_fallback:
		_assert(horizontal_speed > 0.1, "Flat same-room finished navigation should still allow direct fallback movement")
		_assert(enemy.direction.length() > 0.1, "Flat same-room finished navigation should still keep a chase direction")
		_assert(enemy.find_path_timer.is_stopped(), "Flat same-room finished navigation should not force a short repath")
	else:
		_assert(horizontal_speed <= 0.001, "Vertical same-room finished navigation should not direct-shove horizontally into uphill geometry")
		_assert(enemy.direction.length() <= 0.001, "Vertical same-room finished navigation should leave direction neutral until repath refreshes")
		_assert(not enemy.find_path_timer.is_stopped(), "Vertical same-room finished navigation should schedule a short repath refresh")
		_assert(is_equal_approx(enemy.find_path_timer.wait_time, 0.1), "Vertical same-room finished navigation should shorten repath delay to the fast safety refresh")

	mock_nav.free()
	target.free()
	enemy.free()
	await get_tree().process_frame


func _assert_active_navigation_vertical_stall_recovery(
	target_room: String,
	target_position: Vector3,
	nav_target_position: Vector3,
	next_path_position: Vector3,
	expected_direction: Vector3,
	expect_recovery: bool
) -> void:
	var enemy := EnemyScene.instantiate() as Enemy
	enemy.current_room = "RoomA"
	add_child(enemy)

	var target := MockTarget.new()
	target.current_room = target_room
	target.position = target_position
	add_child(target)

	await get_tree().process_frame

	enemy.current_target = target
	enemy.global_position = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	enemy.direction = Vector3.ZERO
	enemy.find_path_timer.stop()
	enemy.find_path_timer.wait_time = 0.8

	var runtime_coordinator := enemy.get_node("EnemyRuntimeCoordinator") as EnemyRuntimeCoordinator
	var mock_nav := MockNavigationComponent.new()
	mock_nav.mock_finished = false
	mock_nav.mock_next_path_position = next_path_position
	mock_nav.use_base_horizontal_direction = true
	mock_nav.mock_distance_to_target = 6.0
	mock_nav.target_position = nav_target_position
	mock_nav._owner_enemy = enemy
	runtime_coordinator._nav_component = mock_nav

	runtime_coordinator._process_chase_movement(0.1)

	var horizontal_velocity := Vector3(enemy.velocity.x, 0.0, enemy.velocity.z)
	if expect_recovery:
		_assert(horizontal_velocity.length() > 0.1, "Active uphill stall should recover into horizontal movement instead of slow-crawling in place")
		_assert(horizontal_velocity.normalized().dot(expected_direction.normalized()) > 0.9, "Active uphill stall should follow the current navigation target direction, preserving room-transition routing")
		_assert(enemy.direction.normalized().dot(expected_direction.normalized()) > 0.9, "Active uphill stall should update the chase direction cache to the recovered horizontal steer")
		_assert(not enemy.find_path_timer.is_stopped(), "Active uphill stall should schedule a short repath refresh after recovering direction")
		_assert(is_equal_approx(enemy.find_path_timer.wait_time, 0.1), "Active uphill stall should shorten the repath timer to the fast safety refresh")
	else:
		_assert(horizontal_velocity.length() <= 0.001, "Flat zero-direction chase should stay neutral when no vertical stall is present")
		_assert(enemy.direction.length() <= 0.001, "Flat zero-direction chase should not invent a chase direction without an uphill stall")
		_assert(enemy.find_path_timer.is_stopped(), "Flat zero-direction chase should not force a repath when there is no uphill stall")

	mock_nav.free()
	target.free()
	enemy.free()
	await get_tree().process_frame


func _assert_fuwatty_chase_physics_stays_mobile(use_ramp: bool, use_transition: bool) -> void:
	var environment := _create_fuwatty_physics_environment(use_ramp)
	add_child(environment["root"])
	Services.enemy_context.set_transitions_node(null)

	var transitions: Node3D = null
	if use_transition:
		transitions = _create_terrain_transitions_node(environment["spawn_position"])
		add_child(transitions)
		Services.enemy_context.set_transitions_node(transitions)

	var enemy := FuwattyScene.instantiate() as Enemy
	enemy.navigation_mode = Enemy.NavigationMode.GODOT
	enemy.current_room = "RoomA" if use_transition else "RoomB"
	enemy.position = Vector3(-2.0, 0.05, -3.0) if use_transition else environment["spawn_position"]
	add_child(enemy)

	var target := MockTarget.new()
	target.current_room = "RoomB"
	target.position = environment["target_position"]
	add_child(target)

	await _wait_physics_frames(5)

	if use_transition:
		enemy.current_target = target
		enemy.makepath()
		var transition_component := enemy.get_node("EnemyTransitionComponent") as EnemyTransitionComponent
		_assert(transition_component.pending_transition_name == "DoorAB", "Post-transition terrain regression should keep room-transition routing intact before the hop")
		_assert(transition_component.handle_target_reached(), "Post-transition terrain regression should execute the room hop before the uphill chase check")
		_assert(enemy.current_room == "RoomB", "Post-transition terrain regression should land Fuwatty in the destination room")
	else:
		enemy.current_target = target

	var mock_nav := _install_mock_vertical_stall_navigation(enemy, target.global_position, use_ramp)
	enemy.find_path_timer.stop()
	enemy.find_path_timer.wait_time = 0.8
	enemy.velocity = Vector3.ZERO
	enemy.direction = Vector3.ZERO
	await _wait_physics_frames(1)

	var start_position := enemy.global_position
	var max_horizontal_speed := 0.0
	var max_height := start_position.y
	var min_height := start_position.y
	var saw_vertical_fallback := false
	for _i in 90:
		await get_tree().physics_frame
		max_horizontal_speed = maxf(max_horizontal_speed, Vector2(enemy.velocity.x, enemy.velocity.z).length())
		max_height = maxf(max_height, enemy.global_position.y)
		min_height = minf(min_height, enemy.global_position.y)
		saw_vertical_fallback = saw_vertical_fallback or mock_nav.is_vertical_horizontal_direction_fallback_active()

	var planar_delta := Vector3(enemy.global_position.x - start_position.x, 0.0, enemy.global_position.z - start_position.z)
	_assert(planar_delta.length() > 1.5, "Fuwatty chase should keep making horizontal progress instead of degrading into a slow crawl")
	_assert(planar_delta.normalized().dot(Vector3.BACK) > 0.7, "Fuwatty chase should keep following the current waypoint or target direction on terrain")
	_assert(max_horizontal_speed > 1.0, "Fuwatty chase should keep a meaningful horizontal speed on terrain")

	if use_ramp:
		_assert(max_height > start_position.y + 0.2, "Fuwatty uphill chase should keep climbing instead of getting stuck at the base of the slope")
		_assert(saw_vertical_fallback, "Uphill terrain regression should exercise the vertical-offset navigation fallback")
	else:
		_assert(max_height - min_height < 0.3, "Flat-ground chase should remain on level terrain")
		_assert(not saw_vertical_fallback, "Flat-ground chase should not trigger the uphill-only fallback")

	Services.enemy_context.set_transitions_node(null)
	if transitions:
		transitions.free()
	mock_nav.free()
	target.free()
	enemy.free()
	environment["root"].free()
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


func _create_fuwatty_physics_environment(use_ramp: bool) -> Dictionary:
	var root := Node3D.new()
	root.name = "FuwattyPhysicsEnvironment"
	root.add_child(_create_static_box_body("BaseFloor", Vector3(0.0, -0.5, 3.5), Vector3(14.0, 1.0, 18.0)))
	var spawn_position := Vector3(0.0, 0.05, 0.2)
	var target_position := Vector3(0.0, 0.05, 6.0)
	if use_ramp:
		root.add_child(_create_static_box_body("Ramp", Vector3(0.0, 0.34, 3.3), Vector3(4.0, 0.4, 4.0), Vector3(-15.0, 0.0, 0.0)))
		root.add_child(_create_static_box_body("TopPlatform", Vector3(0.0, 0.5, 7.2), Vector3(4.0, 1.0, 3.0)))
		target_position = Vector3(0.0, 0.55, 8.0)
	return {
		"root": root,
		"spawn_position": spawn_position,
		"target_position": target_position,
	}


func _create_terrain_transitions_node(spawn_position: Vector3) -> Node3D:
	var transitions := MockTransitions.new()
	transitions.name = "TerrainTransitions"

	var door := Node3D.new()
	door.name = "DoorAB"
	door.position = Vector3(-1.0, 0.0, -1.0)

	var spawn := Marker3D.new()
	spawn.name = "SpawnPoint"
	spawn.position = spawn_position
	spawn.add_to_group("spawn_point")
	door.add_child(spawn)

	transitions.add_child(door)
	return transitions


func _create_static_box_body(body_name: String, position: Vector3, size: Vector3, rotation_degrees := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = position
	body.rotation_degrees = rotation_degrees

	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision_shape.shape = shape
	body.add_child(collision_shape)
	return body


func _install_mock_vertical_stall_navigation(enemy: Enemy, target_position: Vector3, use_vertical_stall: bool) -> MockNavigationComponent:
	var runtime_coordinator := enemy.get_node("EnemyRuntimeCoordinator") as EnemyRuntimeCoordinator
	var transition_component := enemy.get_node("EnemyTransitionComponent") as EnemyTransitionComponent
	var mock_nav := MockNavigationComponent.new()
	mock_nav.mock_finished = false
	mock_nav.use_base_horizontal_direction = true
	mock_nav.target_position = target_position
	mock_nav._owner_enemy = enemy
	if use_vertical_stall:
		mock_nav.stack_next_path_on_owner = true
		mock_nav.stacked_next_path_offset = Vector3(0.0, 1.2, 0.0)
	else:
		mock_nav.mock_next_path_position = target_position
	enemy._nav_component = mock_nav
	runtime_coordinator._nav_component = mock_nav
	transition_component._nav_component = mock_nav
	return mock_nav


func _wait_physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


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