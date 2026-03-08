class_name EnemyPathTimingController
extends RefCounted

const MIN_WAIT_TIME := 0.05
const CLOSE_REPATH_DELAY := 0.1
const MID_REPATH_DELAY := 0.3
const LONG_REPATH_DELAY := 0.5
const FAR_REPATH_DELAY := 0.8
const REPATH_STAGGER_RATIO := 0.18
const FINISHED_NAVIGATION_REPATH_DELAY := 0.1
const FINISHED_REPATH_STAGGER_MAX := 0.06


func compute_wait_time(distance_to_target: float, has_waypoints: bool) -> float:
	return _compute_base_wait_time(distance_to_target, has_waypoints)


func compute_staggered_wait_time(distance_to_target: float, has_waypoints: bool, stagger_factor: float = 0.5) -> float:
	var base_wait := _compute_base_wait_time(distance_to_target, has_waypoints)
	return maxf(MIN_WAIT_TIME, base_wait + _compute_wait_stagger(base_wait, stagger_factor))


func compute_finished_navigation_repath_delay(stagger_factor: float = 0.5) -> float:
	return maxf(
		MIN_WAIT_TIME,
		FINISHED_NAVIGATION_REPATH_DELAY + lerpf(-FINISHED_REPATH_STAGGER_MAX, FINISHED_REPATH_STAGGER_MAX, _clamp_stagger_factor(stagger_factor))
	)


func compute_stagger_factor(instance_seed: int) -> float:
	var hashed: int = abs(hash(str(instance_seed)))
	return float(hashed % 1000) / 999.0


func _compute_base_wait_time(distance_to_target: float, has_waypoints: bool) -> float:
	if has_waypoints or distance_to_target < 20.0:
		return CLOSE_REPATH_DELAY
	if distance_to_target < 35.0:
		return MID_REPATH_DELAY
	if distance_to_target < 50.0:
		return LONG_REPATH_DELAY
	return FAR_REPATH_DELAY


func _compute_wait_stagger(base_wait: float, stagger_factor: float) -> float:
	return lerpf(-base_wait * REPATH_STAGGER_RATIO, base_wait * REPATH_STAGGER_RATIO, _clamp_stagger_factor(stagger_factor))


func _clamp_stagger_factor(stagger_factor: float) -> float:
	return clampf(stagger_factor, 0.0, 1.0)
