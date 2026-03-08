extends SceneTree

const BASE_SEARCH_ORDER := [0, 4, 2, 6, 1, 3, 5, 7]

var _failed := false


func _init() -> void:
	print("=== DOOM NAVIGATION DIRECTION POLICY TESTS ===")
	_test_axis_direction_resolution()
	_test_diagonal_resolution()
	_test_search_order_prefers_perpendicular_dirs_for_axis_chase()
	_test_seeded_jitter_is_reproducible()
	print("=== DOOM NAVIGATION DIRECTION POLICY TESTS COMPLETED ===")
	quit(1 if _failed else 0)


func _test_axis_direction_resolution() -> void:
	var policy: DoomNavigationDirectionPolicy = DoomNavigationDirectionPolicy.new()
	_assert(policy.get_x_dir(1.0, 0.15) == policy.DIR_EAST, "Positive X delta should resolve east")
	_assert(policy.get_x_dir(-1.0, 0.15) == policy.DIR_WEST, "Negative X delta should resolve west")
	_assert(policy.get_z_dir(-1.0, 0.15) == policy.DIR_NORTH, "Negative Z delta should resolve north")
	_assert(policy.get_z_dir(1.0, 0.15) == policy.DIR_SOUTH, "Positive Z delta should resolve south")
	print("✓ axis direction resolution")


func _test_diagonal_resolution() -> void:
	var policy: DoomNavigationDirectionPolicy = DoomNavigationDirectionPolicy.new()
	_assert(policy.compose_diagonal(policy.DIR_EAST, policy.DIR_NORTH) == policy.DIR_NORTHEAST, "East + north should compose northeast")
	_assert(policy.compose_diagonal(policy.DIR_WEST, policy.DIR_SOUTH) == policy.DIR_SOUTHWEST, "West + south should compose southwest")
	_assert(policy.compose_diagonal(policy.DIR_EAST, policy.DIR_NODIR) == policy.DIR_NODIR, "Incomplete axis pair should stay NODIR")
	print("✓ diagonal composition")


func _test_search_order_prefers_perpendicular_dirs_for_axis_chase() -> void:
	var policy: DoomNavigationDirectionPolicy = DoomNavigationDirectionPolicy.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var order: Array = policy.build_search_order(policy.DIR_EAST, policy.DIR_NODIR, 0, rng, BASE_SEARCH_ORDER)
	_assert(order[0] == policy.DIR_NORTH or order[0] == policy.DIR_SOUTH, "Pure X chase should prefer a perpendicular fallback first")
	_assert(order[1] == policy.DIR_NORTH or order[1] == policy.DIR_SOUTH, "Pure X chase should keep both perpendicular fallbacks at the front")
	_assert(order[0] != order[1], "Preferred fallback directions should remain distinct")
	print("✓ search order perpendicular preference")


func _test_seeded_jitter_is_reproducible() -> void:
	var policy: DoomNavigationDirectionPolicy = DoomNavigationDirectionPolicy.new()
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 41
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 41
	var source_order: Array = BASE_SEARCH_ORDER.duplicate()
	var order_a: Array = policy.apply_seeded_fallback_jitter(source_order.duplicate(), rng_a)
	var order_b: Array = policy.apply_seeded_fallback_jitter(source_order.duplicate(), rng_b)
	_assert(order_a == order_b, "Equal seeds should reproduce the same jittered order")
	var sorted_source: Array = source_order.duplicate()
	var sorted_jittered: Array = order_a.duplicate()
	sorted_source.sort()
	sorted_jittered.sort()
	_assert(sorted_source == sorted_jittered, "Seeded jitter should preserve the candidate directions")
	print("✓ seeded jitter reproducibility")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)
