extends Node

class TestEnemy extends CharacterBody3D:
	var current_target: Node3D = null
	var speed: float = 7.0
	var is_flying: bool = false

var _failed := false
const FUWATTY_DASH_ABILITY_SCRIPT := "res://scenes/components/enemy/fuwatty_dash_ability.gd"


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("=== FUWATTY DASH ABILITY PHASE 1/2 TESTS ===")
	_test_resource_defaults_load()
	_test_distance_window_gating()
	_test_out_of_range_movement_does_not_backlog_steps()
	_test_single_activation_consumes_step_progress()
	_test_failed_precheck_does_not_consume_steps()
	_test_distance_cadence_activation()
	_test_chase_loss_resets_step_progress()
	_test_direction_locks_at_dash_start()
	_test_direction_does_not_change_after_dash_starts()
	_test_obstacle_blocks_dash_start()
	_test_dash_travels_fixed_distance_when_clear()
	print("=== FUWATTY DASH ABILITY PHASE 1/2 TESTS COMPLETED ===")
	get_tree().quit(1 if _failed else 0)


func _test_resource_defaults_load() -> void:
	print("\n--- Loading default FuwattyDashAbility resource ---")
	var ability = load("res://scenes/resources/enemy_abilities/fuwatty_dash_ability.tres")
	_assert(ability != null, "Fuwatty dash ability resource should load")
	_assert(ability.step_interval == 8.0, "step_interval default should be 8.0")
	_assert(ability.pre_dash_halt_seconds == 1.0, "pre_dash_halt_seconds default should be 1.0")
	_assert(ability.dash_tiles == 6.0, "dash_tiles default should be 6.0")
	_assert(ability.tile_size_meters == 1.0, "tile_size_meters default should be 1.0")
	_assert(ability.min_dash_target_distance_m == 0.0, "min_dash_target_distance_m default should be 0.0")
	_assert(ability.max_dash_target_distance_m == 12.0, "max_dash_target_distance_m default should be 12.0")
	print("✓ Default dash ability resource values loaded")


func _test_distance_window_gating() -> void:
	print("\n--- Testing dash distance window gating ---")
	var ability = load(FUWATTY_DASH_ABILITY_SCRIPT).new()
	ability.min_dash_target_distance_m = 2.0
	ability.max_dash_target_distance_m = 10.0

	var too_close := _build_context(Vector3.ZERO, true, Vector3(1.0, 0, 0), 1.0)
	var in_range_a := _build_context(Vector3.ZERO, true, Vector3(4.0, 0, 0), 4.0)
	var in_range_b := _build_context(Vector3(8.0, 0, 0), true, Vector3(14.0, 0, 0), 6.0)
	var too_far := _build_context(Vector3(8.0, 0, 0), true, Vector3(21.0, 0, 0), 13.0)

	_assert(not ability.can_activate(too_close), "Should not accumulate/activate when target is too close")
	_assert(not ability.can_activate(in_range_a), "Should not activate before cadence distance while in range")
	_assert(ability.can_activate(in_range_b), "Should activate once cadence is met and target is in range")
	_assert(not ability.can_activate(too_far), "Should not activate when target is too far")
	print("✓ Dash distance window gating works")


func _test_out_of_range_movement_does_not_backlog_steps() -> void:
	print("\n--- Testing out-of-range movement does not backlog dash steps ---")
	var ability = load(FUWATTY_DASH_ABILITY_SCRIPT).new()
	ability.max_dash_target_distance_m = 10.0

	var far_a := _build_context(Vector3(0.0, 0, 0), true, Vector3(30.0, 0, 0), 30.0)
	var far_b := _build_context(Vector3(20.0, 0, 0), true, Vector3(50.0, 0, 0), 30.0)
	var in_range_a := _build_context(Vector3(21.0, 0, 0), true, Vector3(27.0, 0, 0), 6.0)
	var in_range_b := _build_context(Vector3(29.0, 0, 0), true, Vector3(35.0, 0, 0), 6.0)

	_assert(not ability.can_activate(far_a), "Should not activate while target is out of range")
	_assert(not ability.can_activate(far_b), "Should not activate while target remains out of range")
	_assert(not ability.can_activate(in_range_a), "Entering range should not instantly trigger from stale movement")
	_assert(ability.can_activate(in_range_b), "Should activate after enough in-range movement")
	print("✓ Out-of-range movement does not backlog dash steps")


func _test_single_activation_consumes_step_progress() -> void:
	print("\n--- Testing one activation consumes queued step progress ---")
	var ability = load(FUWATTY_DASH_ABILITY_SCRIPT).new()
	ability.max_dash_target_distance_m = 20.0
	ability.require_clear_dash_path = false
	ability.pre_dash_halt_seconds = 0.0
	ability.dash_tiles = 0.0

	var ctx_a := _build_context(Vector3(0.0, 0, 0), true, Vector3(6.0, 0, 0), 6.0)
	var ctx_b := _build_context(Vector3(40.0, 0, 0), true, Vector3(46.0, 0, 0), 6.0)
	_assert(not ability.can_activate(ctx_a), "Should not activate on first sample")
	_assert(ability.can_activate(ctx_b), "Large movement sample should allow exactly one activation")

	var harness := Node3D.new()
	add_child(harness)
	var enemy := _spawn_test_enemy(harness, Vector3(40, 0, 0))
	var target := _spawn_target(harness, Vector3(46, 0, 0))
	enemy.current_target = target

	ability.activate(enemy)
	ability.process(enemy, 0.01)
	var finished_status = ability.process(enemy, 0.01)
	ability.deactivate(enemy)

	_assert(finished_status == EnemyAbility.AbilityStatus.COMPLETED, "Dash should complete in this short zero-distance setup")
	var ctx_same := _build_context(Vector3(40.0, 0, 0), true, Vector3(46.0, 0, 0), 6.0)
	_assert(not ability.can_activate(ctx_same), "Ability should not immediately re-activate without new movement")
	print("✓ One activation consumes queued step progress")

	harness.free()


func _test_failed_precheck_does_not_consume_steps() -> void:
	print("\n--- Testing failed precheck does not consume step progress ---")
	var ability = load(FUWATTY_DASH_ABILITY_SCRIPT).new()
	ability.pre_dash_halt_seconds = 0.0
	ability.require_clear_dash_path = false
	ability.max_dash_target_distance_m = 40.0

	var ctx_a := _build_context(Vector3(0.0, 0, 0), true, Vector3(8.0, 0, 0), 8.0)
	var ctx_b := _build_context(Vector3(8.0, 0, 0), true, Vector3(16.0, 0, 0), 8.0)
	_assert(not ability.can_activate(ctx_a), "Should not activate on first sample")
	_assert(ability.can_activate(ctx_b), "Should be ready to dash after reaching cadence")

	var harness := Node3D.new()
	add_child(harness)
	var enemy := _spawn_test_enemy(harness, Vector3(8, 0, 0))
	var target := _spawn_target(harness, Vector3(16, 0, 0))
	enemy.current_target = target

	ability.max_dash_target_distance_m = 4.0
	ability.activate(enemy)
	var blocked_status = ability.process(enemy, 0.016)
	_assert(blocked_status == EnemyAbility.AbilityStatus.COMPLETED, "Blocked precheck should cancel this activation")

	ability.max_dash_target_distance_m = 40.0
	var ctx_same := _build_context(Vector3(8.0, 0, 0), true, Vector3(16.0, 0, 0), 8.0)
	_assert(ability.can_activate(ctx_same), "Failed precheck must not consume accumulated cadence")

	ability.activate(enemy)
	var clear_status = ability.process(enemy, 0.016)
	_assert(clear_status == EnemyAbility.AbilityStatus.RUNNING, "Dash should start immediately once path clears")
	print("✓ Failed precheck keeps step progress for next valid dash")

	harness.free()


func _test_distance_cadence_activation() -> void:
	print("\n--- Testing 8-step distance cadence activation ---")
	var ability = load(FUWATTY_DASH_ABILITY_SCRIPT).new()
	var ctx_1 := _build_context(Vector3(0, 0, 0), true)
	var ctx_2 := _build_context(Vector3(3, 0, 0), true)
	var ctx_3 := _build_context(Vector3(8, 0, 0), true)

	_assert(not ability.can_activate(ctx_1), "Should not activate on first sample")
	_assert(not ability.can_activate(ctx_2), "Should not activate before reaching required step distance")
	_assert(ability.can_activate(ctx_3), "Should activate once accumulated distance reaches 8 tiles")
	print("✓ Distance cadence activation works")


func _test_chase_loss_resets_step_progress() -> void:
	print("\n--- Testing chase-loss reset behavior ---")
	var ability = load(FUWATTY_DASH_ABILITY_SCRIPT).new()
	var chase_a := _build_context(Vector3(0, 0, 0), true)
	var chase_b := _build_context(Vector3(7.9, 0, 0), true)
	var lost := _build_context(Vector3(7.9, 0, 0), false)
	var reacquired := _build_context(Vector3(8.0, 0, 0), true)

	_assert(not ability.can_activate(chase_a), "Should not activate on first chase sample")
	_assert(not ability.can_activate(chase_b), "Should still be below cadence threshold")
	_assert(not ability.can_activate(lost), "Should not activate when chase is lost")
	_assert(not ability.can_activate(reacquired), "Step progress should reset after chase interruption")
	print("✓ Chase-loss reset works")


func _test_direction_locks_at_dash_start() -> void:
	print("\n--- Testing direction lock timing (dash-start snapshot) ---")
	var ability = load(FUWATTY_DASH_ABILITY_SCRIPT).new()
	ability.pre_dash_halt_seconds = 1.0
	ability.require_clear_dash_path = false

	var harness := Node3D.new()
	add_child(harness)

	var enemy := TestEnemy.new()
	harness.add_child(enemy)
	enemy.position = Vector3.ZERO

	var target_a := CharacterBody3D.new()
	harness.add_child(target_a)
	target_a.position = Vector3(10, 0, 0)
	var target_b := CharacterBody3D.new()
	harness.add_child(target_b)
	target_b.position = Vector3(0, 0, 10)

	enemy.current_target = target_a
	ability.activate(enemy)

	enemy.current_target = target_b
	var status = ability.process(enemy, 1.01)
	_assert(status == EnemyAbility.AbilityStatus.RUNNING, "Ability should start dashing after pre-dash halt")
	_assert(ability.get_state_name() == &"dashing", "State should transition to dashing")
	_assert(ability.get_dash_direction().is_equal_approx(Vector3(0, 0, 1)), "Dash direction should snapshot at dash start (new target direction)")
	print("✓ Dash direction snapshots at dash start")

	harness.free()


func _test_obstacle_blocks_dash_start() -> void:
	print("\n--- Testing strict obstacle gating before dash ---")
	var ability = load(FUWATTY_DASH_ABILITY_SCRIPT).new()
	ability.pre_dash_halt_seconds = 0.0
	ability.require_clear_dash_path = true

	var harness := Node3D.new()
	add_child(harness)

	var enemy := _spawn_test_enemy(harness, Vector3.ZERO)
	var target := _spawn_target(harness, Vector3(8, 0, 0))
	_spawn_blocker(harness, Vector3(4, 0, 0), Vector3(1, 2, 2))

	enemy.current_target = target
	ability.activate(enemy)
	_assert(ability.get_state_name() == &"idle_counting", "Ability should not enter pre-dash halt when path is blocked")
	var status = ability.process(enemy, 0.016)

	_assert(status == EnemyAbility.AbilityStatus.COMPLETED, "Dash should not start when obstacle blocks path")
	_assert(ability.get_state_name() == &"idle_counting", "State should return to idle when dash is blocked")
	print("✓ Obstacle gating prevents blocked dash")

	harness.free()


func _test_dash_stops_on_wall_impact() -> void:
	print("\n--- Testing dash stops on wall impact ---")
	var ability = load(FUWATTY_DASH_ABILITY_SCRIPT).new()
	ability.pre_dash_halt_seconds = 0.0
	ability.require_clear_dash_path = false
	ability.stuck_timeout_seconds = 1.0

	var harness := Node3D.new()
	add_child(harness)

	var enemy := _spawn_test_enemy(harness, Vector3.ZERO)
	enemy.is_flying = true
	var target := _spawn_target(harness, Vector3(10, 0, 0))
	_spawn_blocker(harness, Vector3(0.75, 0, 0), Vector3(0.5, 2.0, 3.0))
	enemy.current_target = target

	ability.activate(enemy)
	var start_status = ability.process(enemy, 0.016)
	_assert(start_status == EnemyAbility.AbilityStatus.RUNNING, "Dash sequence should start")

	var status := EnemyAbility.AbilityStatus.RUNNING
	for _i in range(20):
		status = ability.process(enemy, 0.016)
		if status != EnemyAbility.AbilityStatus.RUNNING:
			break

	_assert(status == EnemyAbility.AbilityStatus.COMPLETED, "Dash should complete quickly when blocked by wall")
	_assert(enemy.global_position.x < 1.0, "Enemy should not keep driving deep into wall")
	print("✓ Dash stops on wall impact")

	harness.free()


func _test_dash_travels_fixed_distance_when_clear() -> void:
	print("\n--- Testing fixed-distance dash travel on clear path ---")
	var ability = load(FUWATTY_DASH_ABILITY_SCRIPT).new()
	ability.pre_dash_halt_seconds = 0.0
	ability.require_clear_dash_path = true
	ability.dash_tiles = 6.0
	ability.tile_size_meters = 1.0
	ability.max_dash_target_distance_m = 40.0

	var harness := Node3D.new()
	add_child(harness)

	var enemy := _spawn_test_enemy(harness, Vector3.ZERO)
	var target := _spawn_target(harness, Vector3(30, 0, 0))
	enemy.current_target = target

	ability.activate(enemy)
	var started_status = ability.process(enemy, 0.016)
	_assert(started_status == EnemyAbility.AbilityStatus.RUNNING, "Dash should start on clear path")

	var start_pos := enemy.global_position
	var finished_status := _run_until_complete(ability, enemy, 0.05, 200)
	var traveled := _horizontal_distance(start_pos, enemy.global_position)

	_assert(finished_status == EnemyAbility.AbilityStatus.COMPLETED, "Dash should complete after fixed travel distance")
	_assert(traveled >= 5.5 and traveled <= 6.5, "Dash should travel approximately 6 meters on clear path")
	print("✓ Dash travels fixed distance on clear path")

	harness.free()


func _test_direction_does_not_change_after_dash_starts() -> void:
	print("\n--- Testing no mid-dash steering ---")
	var ability = load(FUWATTY_DASH_ABILITY_SCRIPT).new()
	ability.pre_dash_halt_seconds = 0.0
	ability.require_clear_dash_path = false

	var harness := Node3D.new()
	add_child(harness)

	var enemy := TestEnemy.new()
	harness.add_child(enemy)
	enemy.position = Vector3.ZERO

	var target_a := CharacterBody3D.new()
	harness.add_child(target_a)
	target_a.position = Vector3(1, 0, 0)
	var target_b := CharacterBody3D.new()
	harness.add_child(target_b)
	target_b.position = Vector3(-1, 0, 0)

	enemy.current_target = target_a
	ability.activate(enemy)
	ability.process(enemy, 0.01)
	var initial_dash_dir = ability.get_dash_direction()

	enemy.current_target = target_b
	ability.process(enemy, 0.01)
	_assert(ability.get_dash_direction().is_equal_approx(initial_dash_dir), "Dash direction must remain unchanged once dashing started")
	print("✓ Mid-dash steering is prevented")

	harness.free()


func _build_context(enemy_position: Vector3, has_target: bool, target_position: Vector3 = Vector3(10, 0, 0), distance_to_target: float = 10.0) -> EnemyAbilityContext:
	var ctx := EnemyAbilityContext.new()
	ctx.enemy_position = enemy_position
	ctx.has_target = has_target
	ctx.target_position = target_position if has_target else Vector3.ZERO
	ctx.distance_to_target = distance_to_target if has_target else INF
	ctx.is_target_visible = has_target
	ctx.enemy_health_percent = 1.0
	ctx.time_since_last_ability = INF
	return ctx


func _spawn_test_enemy(parent: Node3D, at_position: Vector3) -> TestEnemy:
	var enemy := TestEnemy.new()
	parent.add_child(enemy)
	enemy.position = at_position
	enemy.collision_layer = 1
	enemy.collision_mask = 1

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.2
	shape.shape = capsule
	enemy.add_child(shape)

	return enemy


func _spawn_target(parent: Node3D, at_position: Vector3) -> CharacterBody3D:
	var target := CharacterBody3D.new()
	parent.add_child(target)
	target.position = at_position
	target.collision_layer = 1
	target.collision_mask = 1

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.0
	shape.shape = capsule
	target.add_child(shape)
	return target


func _spawn_blocker(parent: Node3D, at_position: Vector3, size: Vector3) -> StaticBody3D:
	var blocker := StaticBody3D.new()
	parent.add_child(blocker)
	blocker.position = at_position
	blocker.collision_layer = 1
	blocker.collision_mask = 1

	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	blocker.add_child(collider)

	return blocker


func _run_until_complete(ability, enemy: CharacterBody3D, delta: float, max_steps: int) -> int:
	for _i in range(max_steps):
		var status = ability.process(enemy, delta)
		if status != EnemyAbility.AbilityStatus.RUNNING:
			return status
	return EnemyAbility.AbilityStatus.RUNNING


func _horizontal_distance(from_pos: Vector3, to_pos: Vector3) -> float:
	var delta := to_pos - from_pos
	delta.y = 0.0
	return delta.length()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)
