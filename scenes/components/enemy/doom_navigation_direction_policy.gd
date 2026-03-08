class_name DoomNavigationDirectionPolicy
extends RefCounted

const DIR_EAST := 0
const DIR_NORTHEAST := 1
const DIR_NORTH := 2
const DIR_NORTHWEST := 3
const DIR_WEST := 4
const DIR_SOUTHWEST := 5
const DIR_SOUTH := 6
const DIR_SOUTHEAST := 7
const DIR_NODIR := 8

const OPPOSITE_DIRS := [DIR_WEST, DIR_SOUTHWEST, DIR_SOUTH, DIR_SOUTHEAST, DIR_EAST, DIR_NORTHEAST, DIR_NORTH, DIR_NORTHWEST, DIR_NODIR]


func get_opposite_dir(move_dir: int) -> int:
	if move_dir < 0 or move_dir >= OPPOSITE_DIRS.size():
		return DIR_NODIR
	return OPPOSITE_DIRS[move_dir]


func get_x_dir(delta_x: float, axis_epsilon: float) -> int:
	if delta_x > axis_epsilon:
		return DIR_EAST
	if delta_x < -axis_epsilon:
		return DIR_WEST
	return DIR_NODIR


func get_z_dir(delta_z: float, axis_epsilon: float) -> int:
	if delta_z < -axis_epsilon:
		return DIR_NORTH
	if delta_z > axis_epsilon:
		return DIR_SOUTH
	return DIR_NODIR


func compose_diagonal(dir_x: int, dir_z: int) -> int:
	match [dir_x, dir_z]:
		[DIR_EAST, DIR_NORTH]:
			return DIR_NORTHEAST
		[DIR_EAST, DIR_SOUTH]:
			return DIR_SOUTHEAST
		[DIR_WEST, DIR_NORTH]:
			return DIR_NORTHWEST
		[DIR_WEST, DIR_SOUTH]:
			return DIR_SOUTHWEST
		_:
			return DIR_NODIR


func is_target_aligned_dir(candidate: int, diag_dir: int, dir_x: int, dir_z: int) -> bool:
	return candidate == diag_dir or candidate == dir_x or candidate == dir_z


func build_search_order(dir_x: int, dir_z: int, rethink_count: int, rng: RandomNumberGenerator, base_search_order: Array) -> Array:
	var preferred_dirs: Array[int] = []
	if dir_x != DIR_NODIR and dir_z == DIR_NODIR:
		preferred_dirs = [DIR_NORTH, DIR_SOUTH]
	elif dir_z != DIR_NODIR and dir_x == DIR_NODIR:
		preferred_dirs = [DIR_EAST, DIR_WEST]

	if preferred_dirs.size() > 1:
		if rethink_count % 2 == 1:
			preferred_dirs.reverse()
		if rng != null and rng.randf() < 0.5:
			preferred_dirs.reverse()

	var search_order := base_search_order.duplicate()
	for preferred_dir in preferred_dirs:
		search_order.erase(preferred_dir)
	if rethink_count % 2 == 1:
		search_order.reverse()
	search_order = apply_seeded_fallback_jitter(search_order, rng)
	return preferred_dirs + search_order


func apply_seeded_fallback_jitter(search_order: Array, rng: RandomNumberGenerator) -> Array:
	if search_order.size() <= 1 or rng == null:
		return search_order
	var rotated_order := search_order.duplicate()
	var rotation := rng.randi_range(0, rotated_order.size() - 1)
	if rotation > 0:
		rotated_order = rotated_order.slice(rotation) + rotated_order.slice(0, rotation)
	if rotated_order.size() > 2 and rng.randf() < 0.5:
		var swap_index := rng.randi_range(1, rotated_order.size() - 1)
		var tmp = rotated_order[0]
		rotated_order[0] = rotated_order[swap_index]
		rotated_order[swap_index] = tmp
	return rotated_order
