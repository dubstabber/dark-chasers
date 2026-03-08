extends Node

const EnemyScene := preload("res://scenes/enemies/enemy.tscn")

var _failed := false


func _ready() -> void:
	print("=".repeat(60))
	print("DOOM LOCAL CHASE TESTS")
	print("=".repeat(60))

	await _test_open_space_prefers_direct_chase_direction()
	await _test_blocked_direct_path_falls_back_without_navigation_agent()
	await _test_blocked_direction_persists_before_rethink()
	await _test_unreachable_fallback_direction_stays_committed()
	await _test_unreachable_fallback_rethinks_are_rare()
	await _test_target_refresh_preserves_wall_follow_commitment()
	await _test_new_target_resets_committed_wall_follow()
	await _test_no_target_returns_zero_direction()
	await _test_fully_blocked_enemy_can_get_stuck()
	await _test_fully_blocked_enemy_pauses_before_retrying()
	await _test_seeded_fallback_jitter_is_reproducible()
	await _test_collision_size_scales_probe_and_reached_thresholds()

	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)


func _test_open_space_prefers_direct_chase_direction() -> void:
	print("\n--- open space direct chase ---")
	var enemy := await _create_doom_enemy(Vector3.ZERO)
	var doom_nav := enemy._nav_component as DoomNavigationComponent

	doom_nav.set_target(Vector3(8.0, 0.0, -8.0))
	var move_direction := doom_nav.get_horizontal_direction()

	_assert(move_direction.x > 0.6, "Open-space Doom chase should move toward positive X when target is east")
	_assert(move_direction.z < -0.6, "Open-space Doom chase should move toward negative Z when target is north")
	_assert(doom_nav._current_move_dir != DoomNavigationComponent.DIR_NODIR, "Open-space Doom chase should choose an active move direction")
	_assert(doom_nav._last_successful_dir == doom_nav._current_move_dir, "Open-space Doom chase should record the successful move direction")
	_assert(doom_nav._move_count > 0, "Open-space Doom chase should keep a move-count budget before reconsidering")
	print("✓ direct chase direction")

	await _cleanup_nodes([enemy])


func _test_blocked_direct_path_falls_back_without_navigation_agent() -> void:
	print("\n--- blocked direct path falls back locally ---")
	var enemy := await _create_doom_enemy(Vector3.ZERO)
	var obstacle := _create_wall(Vector3(0.55, 0.0, 0.0), Vector3(0.15, 0.6, 0.18))
	add_child(obstacle)
	await get_tree().physics_frame

	var doom_nav := enemy._nav_component as DoomNavigationComponent
	doom_nav.set_target(Vector3(8.0, 0.0, 0.0))
	var move_direction := doom_nav.get_horizontal_direction()

	_assert(move_direction.length_squared() > 0.0, "Blocked local chase should still choose a fallback direction when one exists")
	_assert(absf(move_direction.z) > 0.1, "Blocked local chase should step off the direct axis when a wall blocks the target line")
	_assert(doom_nav._current_move_dir != DoomNavigationComponent.DIR_EAST, "Blocked local chase should not keep the blocked direct direction")
	_assert(doom_nav._blocked_retry_count == 0, "Successful fallback should clear blocked retry bookkeeping")
	print("✓ local fallback without NavigationAgent3D")

	await _cleanup_nodes([obstacle, enemy])


func _test_blocked_direction_persists_before_rethink() -> void:
	print("\n--- blocked direction persists before rethink ---")
	var enemy := await _create_doom_enemy(Vector3.ZERO)
	var doom_nav := enemy._nav_component as DoomNavigationComponent
	doom_nav.blocked_rethink_ticks = 3
	doom_nav.move_count_ticks = 8
	doom_nav.set_target(Vector3(8.0, 0.0, 0.0))

	var initial_direction := doom_nav.get_horizontal_direction()
	_assert(initial_direction.x > 0.9 and absf(initial_direction.z) < 0.1, "Doom chase should initially commit to the direct axis before a new obstacle appears")
	var rethink_count_before_block := doom_nav._rethink_count

	var obstacle := _create_wall(Vector3(0.55, 0.0, 0.0), Vector3(0.15, 0.6, 0.18))
	add_child(obstacle)
	await get_tree().physics_frame

	var persisted_dirs: Array[int] = []
	for _i in range(doom_nav.blocked_rethink_ticks):
		var blocked_direction := doom_nav.get_horizontal_direction()
		persisted_dirs.append(doom_nav._current_move_dir)
		_assert(blocked_direction.x > 0.9 and absf(blocked_direction.z) < 0.1, "Blocked Doom chase should keep pressing its chosen direction for a few ticks")

	_assert(_count_unique_values(persisted_dirs) == 1, "Blocked Doom chase should not jitter through multiple directions every query")
	_assert(doom_nav._rethink_count == rethink_count_before_block, "Blocked Doom chase should defer rethinking until its blocked commitment window expires")

	var fallback_direction := doom_nav.get_horizontal_direction()
	_assert(fallback_direction.length_squared() > 0.0, "After the commitment window, Doom chase should still find a fallback if one exists")
	_assert(absf(fallback_direction.z) > 0.1, "After the commitment window, Doom chase should step off the blocked axis")
	_assert(doom_nav._current_move_dir != DoomNavigationComponent.DIR_EAST, "After the commitment window, Doom chase should finally abandon the blocked direct direction")
	print("✓ blocked-direction persistence without rapid jitter")

	await _cleanup_nodes([obstacle, enemy])


func _test_unreachable_fallback_direction_stays_committed() -> void:
	print("\n--- unreachable fallback stays committed ---")
	var enemy := await _create_doom_enemy(Vector3.ZERO)
	var obstacle := _create_wall(Vector3(0.55, 0.0, 0.0), Vector3(0.15, 0.6, 5.0))
	add_child(obstacle)
	await get_tree().physics_frame

	var doom_nav := enemy._nav_component as DoomNavigationComponent
	doom_nav.move_count_ticks = 4
	doom_nav.fallback_move_count_ticks = 24
	doom_nav.fallback_move_count_jitter_ticks = 0
	doom_nav.set_target(Vector3(8.0, 0.0, 0.0))

	var initial_direction := doom_nav.get_horizontal_direction()
	var committed_dir := doom_nav._current_move_dir
	var rethink_count_at_commit := doom_nav._rethink_count
	_assert(absf(initial_direction.z) > 0.1, "Blocked unreachable chase should begin with a sidestep fallback")

	var committed_dirs: Array[int] = [committed_dir]
	for _i in range(20):
		var repeated_direction := doom_nav.get_horizontal_direction()
		committed_dirs.append(doom_nav._current_move_dir)
		enemy.global_position += repeated_direction * 0.05
		_assert(repeated_direction.length_squared() > 0.0, "Committed fallback movement should keep producing a non-zero sidestep while the route stays locally blocked")

	_assert(_count_unique_values(committed_dirs) == 1, "Unreachable fallback should keep the same sidestep direction for a sustained interval")
	_assert(doom_nav._rethink_count == rethink_count_at_commit, "Committed fallback should not trigger rapid full direction reselection while its long move-count budget remains")
	print("✓ unreachable fallback commits for a sustained interval")

	await _cleanup_nodes([obstacle, enemy])


func _test_unreachable_fallback_rethinks_are_rare() -> void:
	print("\n--- unreachable fallback rethinks are rare ---")
	var enemy := await _create_doom_enemy(Vector3.ZERO)
	var obstacle := _create_wall(Vector3(0.55, 0.0, 0.0), Vector3(0.15, 0.6, 5.0))
	add_child(obstacle)
	await get_tree().physics_frame

	var doom_nav := enemy._nav_component as DoomNavigationComponent
	doom_nav.move_count_ticks = 4
	doom_nav.fallback_move_count_ticks = 18
	doom_nav.fallback_move_count_jitter_ticks = 0
	doom_nav.set_target(Vector3(8.0, 0.0, 0.0))

	var directions: Array[int] = []
	for _i in range(54):
		var move_direction := doom_nav.get_horizontal_direction()
		directions.append(doom_nav._current_move_dir)
		enemy.global_position += move_direction * 0.05
		_assert(move_direction.length_squared() > 0.0, "Unreachable fallback should keep moving stubbornly instead of collapsing into zero-motion jitter when a sidestep exists")

	_assert(_count_direction_changes(directions) <= 2, "Unreachable fallback should not thrash through many chase directions before a long fallback commitment expires")
	_assert(doom_nav._rethink_count <= 6, "Long fallback commitment should keep full reselection frequency bounded across a prolonged blocked approach")
	print("✓ unreachable fallback avoids rapid left-right churn")

	await _cleanup_nodes([obstacle, enemy])


func _test_target_refresh_preserves_wall_follow_commitment() -> void:
	print("\n--- target refresh preserves wall-follow commitment ---")
	var enemy := await _create_doom_enemy(Vector3.ZERO)
	var obstacle := _create_wall(Vector3(0.55, 0.0, 0.0), Vector3(0.15, 0.6, 5.0))
	var target := _create_mock_target(Vector3(8.0, 0.0, 0.0))
	add_child(obstacle)
	add_child(target)
	enemy.current_target = target
	await get_tree().physics_frame

	var doom_nav := enemy._nav_component as DoomNavigationComponent
	doom_nav.fallback_move_count_ticks = 12
	doom_nav.fallback_move_count_jitter_ticks = 0
	doom_nav.set_target(target.global_position)

	var initial_direction := doom_nav.get_horizontal_direction()
	var committed_dir := doom_nav._current_move_dir
	var remaining_budget := doom_nav._move_count
	_assert(absf(initial_direction.z) > 0.1, "Blocked target refresh regression should begin with a sidestep fallback")

	for _i in range(5):
		target.global_position += Vector3(0.15, 0.0, 0.05)
		doom_nav.set_target(target.global_position)
		var repeated_direction := doom_nav.get_horizontal_direction()
		remaining_budget -= 1
		enemy.global_position += repeated_direction * 0.05
		_assert(doom_nav._current_move_dir == committed_dir, "Routine target refreshes should keep the same committed wall-follow direction")
		_assert(doom_nav._move_count == remaining_budget, "Routine target refreshes should preserve the fallback move budget instead of restarting it")

	print("✓ routine target refreshes no longer break wall-follow commitment")

	await _cleanup_nodes([target, obstacle, enemy])


func _test_new_target_resets_committed_wall_follow() -> void:
	print("\n--- new target resets committed wall-follow ---")
	var enemy := await _create_doom_enemy(Vector3.ZERO)
	var obstacle := _create_wall(Vector3(0.55, 0.0, 0.0), Vector3(0.15, 0.6, 5.0))
	var target_a := _create_mock_target(Vector3(8.0, 0.0, 0.0))
	var target_b := _create_mock_target(Vector3(-8.0, 0.0, 0.0))
	add_child(obstacle)
	add_child(target_a)
	add_child(target_b)
	enemy.current_target = target_a
	await get_tree().physics_frame

	var doom_nav := enemy._nav_component as DoomNavigationComponent
	doom_nav.fallback_move_count_ticks = 12
	doom_nav.fallback_move_count_jitter_ticks = 0
	doom_nav.set_target(target_a.global_position)
	var fallback_direction := doom_nav.get_horizontal_direction()
	var committed_dir := doom_nav._current_move_dir
	_assert(absf(fallback_direction.z) > 0.1, "First target should force a wall-follow sidestep")

	enemy.current_target = target_b
	doom_nav.set_target(target_b.global_position)
	var retargeted_direction := doom_nav.get_horizontal_direction()
	_assert(retargeted_direction.x < -0.9 and absf(retargeted_direction.z) < 0.1, "Switching to a different target should reset the old sidestep commitment and chase the new target directly when possible")
	_assert(doom_nav._current_move_dir != committed_dir, "A genuine target change should be allowed to discard the previous wall-follow commitment")
	print("✓ genuine retargets still reset Doom chase commitment")

	await _cleanup_nodes([target_b, target_a, obstacle, enemy])


func _test_no_target_returns_zero_direction() -> void:
	print("\n--- no target returns zero direction ---")
	var enemy := await _create_doom_enemy(Vector3(2.0, 0.0, 3.0))
	var doom_nav := enemy._nav_component as DoomNavigationComponent

	var move_direction := doom_nav.get_horizontal_direction()

	_assert(move_direction == Vector3.ZERO, "Doom chase should stay idle until a target position is assigned")
	_assert(doom_nav.distance_to_target() == 0.0, "Doom chase should report zero distance when no target is active")
	print("✓ no-target idle behavior")

	await _cleanup_nodes([enemy])


func _test_fully_blocked_enemy_can_get_stuck() -> void:
	print("\n--- fully blocked enemy can get stuck ---")
	var enemy := await _create_doom_enemy(Vector3.ZERO)
	var walls := _create_surrounding_walls()
	for wall in walls:
		add_child(wall)
	await get_tree().physics_frame

	var doom_nav := enemy._nav_component as DoomNavigationComponent
	doom_nav.set_target(Vector3(6.0, 0.0, 0.0))
	var move_direction := doom_nav.get_horizontal_direction()

	_assert(move_direction == Vector3.ZERO, "Fully blocked Doom chase should be able to get stuck instead of inventing a route")
	_assert(doom_nav._current_move_dir == DoomNavigationComponent.DIR_NODIR, "Fully blocked Doom chase should end up with no move direction")
	_assert(doom_nav._blocked_retry_count > 0, "Fully blocked Doom chase should record blocked-retry state")
	_assert(doom_nav._last_failed_dir != DoomNavigationComponent.DIR_NODIR, "Fully blocked Doom chase should remember the last failed direction attempt")
	print("✓ authentic stuck behavior")

	var cleanup_nodes: Array[Node] = []
	for wall in walls:
		cleanup_nodes.append(wall)
	cleanup_nodes.append(enemy)
	await _cleanup_nodes(cleanup_nodes)


func _test_fully_blocked_enemy_pauses_before_retrying() -> void:
	print("\n--- fully blocked enemy pauses before retrying ---")
	var enemy := await _create_doom_enemy(Vector3.ZERO)
	var walls := _create_surrounding_walls()
	for wall in walls:
		add_child(wall)
	await get_tree().physics_frame

	var doom_nav := enemy._nav_component as DoomNavigationComponent
	doom_nav.stuck_retry_delay_ticks = 3
	doom_nav.set_target(Vector3(6.0, 0.0, 0.0))

	var first_direction := doom_nav.get_horizontal_direction()
	var initial_retry_count := doom_nav._blocked_retry_count
	_assert(first_direction == Vector3.ZERO, "Fully blocked Doom chase should still return zero movement when no route exists")
	_assert(initial_retry_count == 1, "Fully blocked Doom chase should count the initial failed rethink attempt")

	for _i in range(doom_nav.stuck_retry_delay_ticks):
		var paused_direction := doom_nav.get_horizontal_direction()
		_assert(paused_direction == Vector3.ZERO, "Fully blocked Doom chase should remain paused during its stuck retry delay")
		_assert(doom_nav._blocked_retry_count == initial_retry_count, "Stuck retry delay should prevent frantic full rethinks every query")

	var retried_direction := doom_nav.get_horizontal_direction()
	_assert(retried_direction == Vector3.ZERO, "Retrying after the pause should still report stuck when the enemy remains boxed in")
	_assert(doom_nav._blocked_retry_count > initial_retry_count, "Once the stuck retry delay expires, Doom chase should be allowed to retry")
	print("✓ unreachable-target pause reduces tight looping")

	var cleanup_nodes: Array[Node] = []
	for wall in walls:
		cleanup_nodes.append(wall)
	cleanup_nodes.append(enemy)
	await _cleanup_nodes(cleanup_nodes)


func _test_seeded_fallback_jitter_is_reproducible() -> void:
	print("\n--- seeded fallback jitter is reproducible ---")
	var enemy := await _create_doom_enemy(Vector3.ZERO, 0.2, 41)
	var doom_nav := enemy._nav_component as DoomNavigationComponent

	var order_a: Array = []
	for _i in range(3):
		order_a.append(doom_nav._apply_seeded_fallback_jitter(DoomNavigationComponent.SEARCH_ORDER.duplicate()))

	doom_nav.set_fallback_random_seed(41)
	var order_b: Array = []
	for _i in range(3):
		order_b.append(doom_nav._apply_seeded_fallback_jitter(DoomNavigationComponent.SEARCH_ORDER.duplicate()))

	doom_nav.set_fallback_random_seed(84)
	var order_c: Array = []
	for _i in range(3):
		order_c.append(doom_nav._apply_seeded_fallback_jitter(DoomNavigationComponent.SEARCH_ORDER.duplicate()))

	_assert(order_a == order_b, "Resetting the Doom fallback seed should reproduce the same fallback ordering sequence")
	_assert(order_a != order_c, "Different Doom fallback seeds should produce a different fallback ordering sequence")
	print("✓ seeded fallback jitter reproducibility")

	await _cleanup_nodes([enemy])


func _test_collision_size_scales_probe_and_reached_thresholds() -> void:
	print("\n--- collision size scales probe and target threshold ---")
	var small_enemy := await _create_doom_enemy(Vector3.ZERO, 0.1, 11)
	var large_enemy := await _create_doom_enemy(Vector3(2.0, 0.0, 0.0), 0.45, 22)
	var small_nav := small_enemy._nav_component as DoomNavigationComponent
	var large_nav := large_enemy._nav_component as DoomNavigationComponent

	var small_probe := small_nav._get_probe_distance()
	var large_probe := large_nav._get_probe_distance()
	var small_reached_distance := small_nav._get_target_reached_distance()
	var large_reached_distance := large_nav._get_target_reached_distance()

	_assert(small_probe < large_probe, "Larger enemies should probe farther ahead than smaller enemies")
	_assert(small_reached_distance < large_reached_distance, "Larger enemies should use a larger target-reached threshold")

	small_nav.set_target(Vector3(0.0, 0.0, -0.2))
	large_nav.set_target(Vector3(2.0, 0.0, -0.2))
	_assert(not small_nav.is_target_reached(), "Small enemies should still need to advance when slightly outside their scaled threshold")
	_assert(large_nav.is_target_reached(), "Large enemies should treat the same local offset as reached when within their scaled threshold")
	print("✓ collision-size-aware Doom tuning")

	await _cleanup_nodes([small_enemy, large_enemy])


func _create_doom_enemy(start_pos: Vector3, radius: float = 0.2, seed_value: int = 1337) -> Enemy:
	var enemy := EnemyScene.instantiate() as Enemy
	enemy.navigation_mode = Enemy.NavigationMode.DOOM
	add_child(enemy)
	await get_tree().process_frame

	enemy.global_position = start_pos
	var collision_shape := enemy.get_node("CollisionShape3D") as CollisionShape3D
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision_shape.shape = shape

	var doom_nav := enemy._nav_component as DoomNavigationComponent
	doom_nav.movement_probe_distance = 0.75
	doom_nav.move_count_jitter_ticks = 0
	doom_nav.fallback_move_count_jitter_ticks = 0
	doom_nav.set_fallback_random_seed(seed_value)
	return enemy


func _create_surrounding_walls() -> Array[StaticBody3D]:
	return [
		_create_wall(Vector3(0.48, 0.0, 0.0), Vector3(0.12, 0.6, 0.9)),
		_create_wall(Vector3(-0.48, 0.0, 0.0), Vector3(0.12, 0.6, 0.9)),
		_create_wall(Vector3(0.0, 0.0, 0.48), Vector3(0.9, 0.6, 0.12)),
		_create_wall(Vector3(0.0, 0.0, -0.48), Vector3(0.9, 0.6, 0.12)),
	]


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


func _create_mock_target(position: Vector3) -> CharacterBody3D:
	var target := CharacterBody3D.new()
	target.position = position
	return target


func _cleanup_nodes(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await get_tree().process_frame


func _count_unique_values(values: Array) -> int:
	var unique_values := {}
	for value in values:
		unique_values[value] = true
	return unique_values.size()


func _count_direction_changes(values: Array) -> int:
	if values.is_empty():
		return 0
	var last_value = values[0]
	var change_count := 0
	for i in range(1, values.size()):
		if values[i] == last_value:
			continue
		change_count += 1
		last_value = values[i]
	return change_count


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)