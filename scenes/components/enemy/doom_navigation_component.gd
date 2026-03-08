class_name DoomNavigationComponent
extends EnemyNavigationComponent

const MODE_ID := &"doom"
const TARGET_REACHED_DISTANCE := 0.25
const TARGET_AXIS_EPSILON := 0.15
const MIN_PROBE_DISTANCE := 0.35
const MAX_PROBE_DISTANCE := 0.9
const DEFAULT_MOVE_COUNT := 12
const DEFAULT_MOVE_COUNT_JITTER := 4
const DEFAULT_FALLBACK_MOVE_COUNT := 180
const DEFAULT_FALLBACK_MOVE_COUNT_JITTER := 300
const DEFAULT_BLOCKED_RETHINK_TICKS := 4
const DEFAULT_STUCK_RETRY_DELAY_TICKS := 6
const BASE_COLLISION_RADIUS := 0.2
const MIN_TARGET_REACHED_DISTANCE := 0.12

enum ChaseDir {
	EAST,
	NORTHEAST,
	NORTH,
	NORTHWEST,
	WEST,
	SOUTHWEST,
	SOUTH,
	SOUTHEAST,
	NODIR,
}

const DIR_EAST := ChaseDir.EAST
const DIR_NODIR := ChaseDir.NODIR

const DIR_VECTORS := [
	Vector3.RIGHT,
	Vector3(0.7071068, 0.0, -0.7071068),
	Vector3.FORWARD,
	Vector3(-0.7071068, 0.0, -0.7071068),
	Vector3.LEFT,
	Vector3(-0.7071068, 0.0, 0.7071068),
	Vector3.BACK,
	Vector3(0.7071068, 0.0, 0.7071068),
	Vector3.ZERO,
]

const OPPOSITE_DIRS := [
	ChaseDir.WEST,
	ChaseDir.SOUTHWEST,
	ChaseDir.SOUTH,
	ChaseDir.SOUTHEAST,
	ChaseDir.EAST,
	ChaseDir.NORTHEAST,
	ChaseDir.NORTH,
	ChaseDir.NORTHWEST,
	ChaseDir.NODIR,
]

const SEARCH_ORDER := [
	ChaseDir.EAST,
	ChaseDir.NORTHEAST,
	ChaseDir.NORTH,
	ChaseDir.NORTHWEST,
	ChaseDir.WEST,
	ChaseDir.SOUTHWEST,
	ChaseDir.SOUTH,
	ChaseDir.SOUTHEAST,
]

@export var movement_probe_distance: float = 0.65
@export var obstacle_clearance_margin: float = 0.05
@export var move_count_ticks: int = DEFAULT_MOVE_COUNT
@export var move_count_jitter_ticks: int = DEFAULT_MOVE_COUNT_JITTER
@export var fallback_move_count_ticks: int = DEFAULT_FALLBACK_MOVE_COUNT
@export var fallback_move_count_jitter_ticks: int = DEFAULT_FALLBACK_MOVE_COUNT_JITTER
@export var blocked_rethink_ticks: int = DEFAULT_BLOCKED_RETHINK_TICKS
@export var stuck_retry_delay_ticks: int = DEFAULT_STUCK_RETRY_DELAY_TICKS
@export var fallback_random_seed: int = -1

var _rng := RandomNumberGenerator.new()
var _direction_policy: DoomNavigationDirectionPolicy = DoomNavigationDirectionPolicy.new()
var _has_target := false
var _current_move_dir: ChaseDir = ChaseDir.NODIR
var _last_successful_dir: ChaseDir = ChaseDir.NODIR
var _move_count := 0
var _current_move_is_fallback := false
var _blocked_move_count := 0
var _blocked_retry_count := 0
var _last_failed_dir: ChaseDir = ChaseDir.NODIR
var _rethink_count := 0
var _stuck_retry_delay := 0
var _target_reached_emitted := false
var _tracked_target_node: Node3D = null


func _ready() -> void:
	super._ready()
	if fallback_random_seed >= 0:
		_rng.seed = fallback_random_seed
	else:
		_rng.seed = int(get_instance_id())


func get_navigation_mode_id() -> StringName:
	return MODE_ID


func _on_target_set(_pos: Vector3) -> void:
	var had_target := _has_target
	var target_node := _get_current_target_node()
	var target_changed := target_node != _tracked_target_node
	_has_target = true
	_tracked_target_node = target_node
	if not had_target or target_changed:
		_reset_move_commitment()
	elif not is_target_reached():
		_target_reached_emitted = false


func _on_navigation_active_changed(active: bool) -> void:
	if not active:
		_reset_chase_state()


func get_horizontal_direction() -> Vector3:
	if not _owner_enemy or not is_navigation_active() or not _has_target:
		return Vector3.ZERO

	if is_target_reached():
		_emit_target_reached_once()
		return Vector3.ZERO

	if _stuck_retry_delay > 0:
		_stuck_retry_delay -= 1
		return Vector3.ZERO

	var needs_new_dir := _current_move_dir == ChaseDir.NODIR
	if not needs_new_dir:
		if _is_direction_blocked(_current_move_dir):
			_blocked_move_count += 1
			needs_new_dir = _blocked_move_count > max(0, blocked_rethink_ticks)
		else:
			_blocked_move_count = 0
			needs_new_dir = _move_count <= 0

	if needs_new_dir:
		_choose_new_chase_dir()
	else:
		_move_count = max(0, _move_count - 1)

	if _current_move_dir == ChaseDir.NODIR:
		return Vector3.ZERO

	return _get_dir_vector(_current_move_dir)


func get_next_path_position() -> Vector3:
	if not _owner_enemy:
		return Vector3.ZERO
	var direction := get_horizontal_direction()
	if direction.length_squared() <= 0.000001:
		return _owner_enemy.global_position
	return _owner_enemy.global_position + direction * _get_probe_distance()


func is_target_reached() -> bool:
	return _has_target and distance_to_target() <= _get_target_reached_distance()


func distance_to_target() -> float:
	if not _owner_enemy or not _has_target:
		return 0.0
	return _owner_enemy.global_position.distance_to(target_position)


func set_fallback_random_seed(seed_value: int) -> void:
	fallback_random_seed = seed_value
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.seed = int(get_instance_id())


func _choose_new_chase_dir() -> void:
	if not _owner_enemy:
		_current_move_dir = ChaseDir.NODIR
		_move_count = 0
		_current_move_is_fallback = false
		_blocked_move_count = 0
		return

	var target_reached_distance := _get_target_reached_distance()
	var delta := target_position - _owner_enemy.global_position
	delta.y = 0.0
	if delta.length_squared() <= target_reached_distance * target_reached_distance:
		_current_move_dir = ChaseDir.NODIR
		_move_count = 0
		_current_move_is_fallback = false
		_blocked_move_count = 0
		_emit_target_reached_once()
		return

	var old_dir := _current_move_dir
	var old_dir_is_fallback := _current_move_is_fallback
	var turnaround := _get_opposite_dir(old_dir)
	var dir_x := _get_x_dir(delta.x)
	var dir_z := _get_z_dir(delta.z)
	var diag_dir := ChaseDir.NODIR

	if dir_x != ChaseDir.NODIR and dir_z != ChaseDir.NODIR:
		diag_dir = _compose_diagonal(dir_x, dir_z)
		if diag_dir != turnaround and _try_set_move_dir(diag_dir):
			return

	var primary_dirs: Array[ChaseDir] = [dir_x, dir_z]
	if absf(delta.z) > absf(delta.x):
		primary_dirs = [dir_z, dir_x]
	elif _rethink_count % 2 == 1:
		primary_dirs = [dir_z, dir_x]

	for candidate in primary_dirs:
		if candidate == ChaseDir.NODIR or candidate == turnaround:
			continue
		if _try_set_move_dir(candidate):
			return

	var reuse_fallback_commitment := old_dir_is_fallback or not _is_target_aligned_dir(old_dir, diag_dir, dir_x, dir_z)
	if old_dir != ChaseDir.NODIR and _try_set_move_dir(old_dir, reuse_fallback_commitment):
		return

	var search_order := _build_fallback_search_order(dir_x, dir_z)

	for candidate in search_order:
		if candidate == turnaround:
			continue
		if _try_set_move_dir(candidate, true):
			return

	if turnaround != ChaseDir.NODIR and _try_set_move_dir(turnaround, true):
		return

	_current_move_dir = ChaseDir.NODIR
	_move_count = 0
	_current_move_is_fallback = false
	_blocked_move_count = 0
	_blocked_retry_count += 1
	_stuck_retry_delay = max(0, stuck_retry_delay_ticks)
	_rethink_count += 1


func _build_fallback_search_order(dir_x: ChaseDir = ChaseDir.NODIR, dir_z: ChaseDir = ChaseDir.NODIR) -> Array:
	return _direction_policy.build_search_order(dir_x, dir_z, _rethink_count, _rng, SEARCH_ORDER)


func _apply_seeded_fallback_jitter(search_order: Array) -> Array:
	return _direction_policy.apply_seeded_fallback_jitter(search_order, _rng)


func _try_set_move_dir(candidate: ChaseDir, use_fallback_commitment: bool = false) -> bool:
	if candidate == ChaseDir.NODIR or _is_direction_blocked(candidate):
		_last_failed_dir = candidate
		return false

	_current_move_dir = candidate
	_last_successful_dir = candidate
	_current_move_is_fallback = use_fallback_commitment
	_move_count = _get_new_move_count(use_fallback_commitment)
	_blocked_move_count = 0
	_blocked_retry_count = 0
	_stuck_retry_delay = 0
	_rethink_count += 1
	return true


func _is_direction_blocked(move_dir: ChaseDir) -> bool:
	if not _owner_enemy or move_dir == ChaseDir.NODIR:
		return true

	var direction := _get_dir_vector(move_dir)
	if direction.length_squared() <= 0.000001:
		return true
	if _is_non_openable_door_ahead(direction):
		return true

	var collision := KinematicCollision3D.new()
	var collides := _owner_enemy.test_move(
		_owner_enemy.global_transform,
		direction * _get_probe_distance(),
		collision,
		maxf(0.001, obstacle_clearance_margin),
		false
	)
	if not collides:
		return false

	var collider_node := collision.get_collider() as Node
	if _is_allowed_target_hit(collider_node):
		return false
	if _can_attempt_door_open(collider_node, collision.get_position()):
		return false

	return true


func _is_allowed_target_hit(collider_node: Node) -> bool:
	if collider_node == null or not _owner_enemy:
		return false

	var target := _get_current_target_node()
	if target == null:
		return false

	if collider_node == target:
		return true
	if collider_node.is_in_group("player"):
		return true
	if target.is_ancestor_of(collider_node):
		return true
	return collider_node.is_ancestor_of(target)


func _can_attempt_door_open(collider_node: Node, hit_pos: Vector3) -> bool:
	if collider_node == null or not _owner_enemy:
		return false

	var door_opener := _owner_enemy.get_node_or_null("EnemyDoorOpenerComponent") as EnemyDoorOpenerComponent
	if door_opener == null:
		return false
	return door_opener.can_open_door_for_collision(collider_node, hit_pos)


func _is_non_openable_door_ahead(direction: Vector3) -> bool:
	if not _owner_enemy:
		return false
	var lookahead_distance := _get_door_lookahead_distance()
	if lookahead_distance <= _get_probe_distance():
		return false
	var from := _owner_enemy.global_position + Vector3.UP * 0.5
	var to := from + direction * lookahead_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, _owner_enemy.collision_mask, [_owner_enemy])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := _owner_enemy.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var collider_node := result.get("collider") as Node
	if collider_node == null or not _is_door_collider(collider_node):
		return false
	return not _can_attempt_door_open(collider_node, result.get("position", Vector3.ZERO))


func _is_door_collider(collider_node: Node) -> bool:
	var cursor: Node = collider_node
	while cursor != null:
		if cursor is Door:
			return true
		cursor = cursor.get_parent()
	return false


func _get_door_lookahead_distance() -> float:
	var lookahead_distance := _get_probe_distance()
	var max_lookahead_distance := MAX_PROBE_DISTANCE
	var interaction_ray := _owner_enemy.get_node_or_null("Interaction") as RayCast3D
	if interaction_ray:
		lookahead_distance = maxf(lookahead_distance, interaction_ray.target_position.length())
		max_lookahead_distance = maxf(max_lookahead_distance, interaction_ray.target_position.length())
	return clampf(lookahead_distance, MIN_PROBE_DISTANCE, max_lookahead_distance)


func _get_probe_distance() -> float:
	var base_distance := movement_probe_distance
	if _owner_enemy and _owner_enemy.has_method("get"):
		var owner_speed = _owner_enemy.get("speed")
		if owner_speed is float:
			base_distance = maxf(base_distance, owner_speed / maxf(10.0, float(Engine.physics_ticks_per_second)))
	base_distance = maxf(base_distance, _get_collision_radius() * 2.0)
	return clampf(base_distance, MIN_PROBE_DISTANCE, MAX_PROBE_DISTANCE)


func _get_new_move_count(use_fallback_commitment: bool = false) -> int:
	var base_move_count: int = max(1, fallback_move_count_ticks if use_fallback_commitment else move_count_ticks)
	var jitter: int = max(0, fallback_move_count_jitter_ticks if use_fallback_commitment else move_count_jitter_ticks)
	if jitter <= 0:
		return base_move_count
	return base_move_count + _rng.randi_range(0, jitter)


func _is_target_aligned_dir(candidate: ChaseDir, diag_dir: ChaseDir, dir_x: ChaseDir, dir_z: ChaseDir) -> bool:
	return _direction_policy.is_target_aligned_dir(candidate, diag_dir, dir_x, dir_z)


func _get_target_reached_distance() -> float:
	var scaled_distance := TARGET_REACHED_DISTANCE * (_get_collision_radius() / BASE_COLLISION_RADIUS)
	return clampf(scaled_distance, MIN_TARGET_REACHED_DISTANCE, 1.0)


func _get_collision_radius() -> float:
	if not _owner_enemy:
		return BASE_COLLISION_RADIUS
	var collision_shape := _owner_enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return BASE_COLLISION_RADIUS
	var basis := _owner_enemy.global_transform.basis
	var scale_x := basis.x.length()
	var scale_z := basis.z.length()
	var max_horizontal_scale := maxf(scale_x, scale_z)
	if collision_shape.shape is SphereShape3D:
		return maxf((collision_shape.shape as SphereShape3D).radius * max_horizontal_scale, BASE_COLLISION_RADIUS * 0.5)
	if collision_shape.shape is CapsuleShape3D:
		return maxf((collision_shape.shape as CapsuleShape3D).radius * max_horizontal_scale, BASE_COLLISION_RADIUS * 0.5)
	if collision_shape.shape is CylinderShape3D:
		return maxf((collision_shape.shape as CylinderShape3D).radius * max_horizontal_scale, BASE_COLLISION_RADIUS * 0.5)
	if collision_shape.shape is BoxShape3D:
		var box_shape := collision_shape.shape as BoxShape3D
		var half_width := box_shape.size.x * scale_x * 0.5
		var half_depth := box_shape.size.z * scale_z * 0.5
		return maxf(maxf(half_width, half_depth), BASE_COLLISION_RADIUS * 0.5)
	return BASE_COLLISION_RADIUS


func _get_dir_vector(move_dir: ChaseDir) -> Vector3:
	return DIR_VECTORS[move_dir]


func _get_opposite_dir(move_dir: ChaseDir) -> ChaseDir:
	return _direction_policy.get_opposite_dir(move_dir) as ChaseDir


func _get_x_dir(delta_x: float) -> ChaseDir:
	return _direction_policy.get_x_dir(delta_x, TARGET_AXIS_EPSILON) as ChaseDir


func _get_z_dir(delta_z: float) -> ChaseDir:
	return _direction_policy.get_z_dir(delta_z, TARGET_AXIS_EPSILON) as ChaseDir


func _compose_diagonal(dir_x: ChaseDir, dir_z: ChaseDir) -> ChaseDir:
	return _direction_policy.compose_diagonal(dir_x, dir_z) as ChaseDir


func _emit_target_reached_once() -> void:
	if _target_reached_emitted:
		return
	_target_reached_emitted = true
	target_reached.emit()


func _reset_chase_state() -> void:
	_current_move_dir = ChaseDir.NODIR
	_last_successful_dir = ChaseDir.NODIR
	_last_failed_dir = ChaseDir.NODIR
	_move_count = 0
	_current_move_is_fallback = false
	_blocked_move_count = 0
	_blocked_retry_count = 0
	_rethink_count = 0
	_stuck_retry_delay = 0
	_target_reached_emitted = false
	_tracked_target_node = null


func _reset_move_commitment() -> void:
	_target_reached_emitted = false
	_move_count = 0
	_current_move_is_fallback = false
	_blocked_move_count = 0
	_stuck_retry_delay = 0
	_current_move_dir = ChaseDir.NODIR


func _get_current_target_node() -> Node3D:
	if not _owner_enemy:
		return null
	return _owner_enemy.get("current_target") as Node3D