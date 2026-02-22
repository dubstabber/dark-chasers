class_name EnemyPathTimingController
extends RefCounted


func compute_wait_time(distance_to_target: float, has_waypoints: bool) -> float:
	if has_waypoints or distance_to_target < 20.0:
		return 0.1
	if distance_to_target < 35.0:
		return 0.3
	if distance_to_target < 50.0:
		return 0.5
	return 0.8
