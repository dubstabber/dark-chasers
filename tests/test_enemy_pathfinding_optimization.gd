extends Node3D

## Archived in task F.2.
## This legacy demo relied on assumptions that no longer match the active
## EnemyRuntimeCoordinator + EnemyPathTimingController architecture.
##
## Active replacements:
## - res://tests/test_enemy_pathfinding_delay.gd
## - res://tests/test_enemy_path_timing_controller.gd
## - res://tests/test_enemy_ability_context_and_runtime_coordinator.gd


func _ready() -> void:
	print("=== ENEMY PATHFINDING OPTIMIZATION DEMO (ARCHIVED) ===")
	print("Use the focused runtime/path timing regression tests listed in this file header.")
	if get_tree():
		get_tree().quit()
