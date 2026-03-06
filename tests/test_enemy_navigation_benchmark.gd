extends Node

const RoomScene := preload("res://scenes/maps/room_1.tscn")
const EnemyScene := preload("res://scenes/enemies/enemy.tscn")

const BENCHMARK_ENEMY_COUNT := 32
const SAMPLE_STEPS := 180
const SPAWN_COLUMNS := 8
const SPAWN_SPACING_X := 1.8
const SPAWN_SPACING_Z := 1.6
const BASE_SPAWN := Vector3(3.0, 0.5, 75.0)
const BASE_TARGET := Vector3(24.0, 0.5, 48.0)
const TARGET_SWAY_X := 6.0
const TARGET_SWAY_Z := 4.0

var _failed := false


func _ready() -> void:
	print("=".repeat(60))
	print("ENEMY NAVIGATION BENCHMARK")
	print("=".repeat(60))

	var room := RoomScene.instantiate()
	add_child(room)
	await _flush_tree()
	_clear_room_population(room)
	await _flush_tree()

	var doom_summary := await _run_benchmark(room, Enemy.NavigationMode.DOOM)
	var godot_summary := await _run_benchmark(room, Enemy.NavigationMode.GODOT)

	_assert(doom_summary["non_zero_samples"] > 0, "Doom benchmark should produce non-zero chase samples")
	_assert(godot_summary["non_zero_samples"] > 0, "Godot benchmark should produce non-zero chase samples on a valid navmesh")

	_print_summary(doom_summary)
	_print_summary(godot_summary)

	room.queue_free()
	await _flush_tree()
	await _flush_tree()
	get_tree().quit(1 if _failed else 0)


func _run_benchmark(room: Node, mode: Enemy.NavigationMode) -> Dictionary:
	_clear_room_population(room)
	await _flush_tree()
	var enemies := await _spawn_benchmark_enemies(room, mode)
	var started_at_usec := Time.get_ticks_usec()
	var total_step_distance := 0.0
	var non_zero_samples := 0

	for step in range(SAMPLE_STEPS):
		var target := BASE_TARGET + Vector3(
			sin(step * 0.11) * TARGET_SWAY_X,
			0.0,
			cos(step * 0.07) * TARGET_SWAY_Z
		)
		for enemy in enemies:
			var nav_component := enemy._nav_component as EnemyNavigationComponent
			nav_component.set_target(target)
			var next_pos := nav_component.get_next_path_position()
			var step_distance := enemy.global_position.distance_to(next_pos)
			total_step_distance += step_distance
			if step_distance > 0.001:
				non_zero_samples += 1

	var elapsed_usec := Time.get_ticks_usec() - started_at_usec
	await _cleanup_nodes(enemies)
	return {
		"mode": _mode_name(mode),
		"enemy_count": BENCHMARK_ENEMY_COUNT,
		"sample_steps": SAMPLE_STEPS,
		"elapsed_msec": elapsed_usec / 1000.0,
		"average_usec_per_query": float(elapsed_usec) / float(BENCHMARK_ENEMY_COUNT * SAMPLE_STEPS),
		"average_step_distance": total_step_distance / float(BENCHMARK_ENEMY_COUNT * SAMPLE_STEPS),
		"non_zero_samples": non_zero_samples,
	}


func _spawn_benchmark_enemies(room: Node, mode: Enemy.NavigationMode) -> Array[Enemy]:
	var enemies_root := room.get_node("Enemies")
	var enemies: Array[Enemy] = []
	for index in range(BENCHMARK_ENEMY_COUNT):
		var enemy := EnemyScene.instantiate() as Enemy
		enemy.navigation_mode = mode
		enemies_root.add_child(enemy)
		enemy.global_position = _spawn_position_for_index(index)
		var collision_shape := enemy.get_node("CollisionShape3D") as CollisionShape3D
		var shape := SphereShape3D.new()
		shape.radius = 0.2
		collision_shape.shape = shape
		enemies.append(enemy)
	await _flush_tree()
	return enemies


func _spawn_position_for_index(index: int) -> Vector3:
	var row := floori(float(index) / float(SPAWN_COLUMNS))
	var column := index % SPAWN_COLUMNS
	return BASE_SPAWN + Vector3(column * SPAWN_SPACING_X, 0.0, row * SPAWN_SPACING_Z)


func _clear_room_population(room: Node) -> void:
	for path in ["Players", "Enemies"]:
		var parent := room.get_node_or_null(path)
		if parent == null:
			continue
		for child in parent.get_children():
			child.queue_free()


func _cleanup_nodes(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await _flush_tree()


func _flush_tree() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame


func _print_summary(summary: Dictionary) -> void:
	print("%s mode: %d enemies x %d steps | %.2f ms total | %.2f usec/query | %.3f avg step | %d non-zero samples"
		% [
			summary["mode"],
			summary["enemy_count"],
			summary["sample_steps"],
			summary["elapsed_msec"],
			summary["average_usec_per_query"],
			summary["average_step_distance"],
			summary["non_zero_samples"],
		])


func _mode_name(mode: Enemy.NavigationMode) -> String:
	return "doom" if mode == Enemy.NavigationMode.DOOM else "godot"


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)