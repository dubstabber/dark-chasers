extends SceneTree

func _init() -> void:
	print("=== CONTEXT SERVICES TESTS ===")
	test_world_context_nulls_invalid_cached_level()
	test_enemy_context_nulls_invalid_cached_nodes()
	print("=== CONTEXT SERVICES TESTS COMPLETED ===")
	quit(0)


func test_world_context_nulls_invalid_cached_level() -> void:
	var source := _read_source("res://scenes/services/world_context.gd")
	assert("if not is_instance_valid(_level_node):" in source, "WorldContext should validate _level_node before returning it")
	assert("_level_node = null" in source, "WorldContext should clear invalid cached _level_node")
	print("✓ WorldContext source guards against stale level references")


func test_enemy_context_nulls_invalid_cached_nodes() -> void:
	var source := _read_source("res://scenes/services/enemy_context.gd")
	assert("if not is_instance_valid(_players_node):" in source, "EnemyContext should validate _players_node before returning it")
	assert("_players_node = null" in source, "EnemyContext should clear invalid cached _players_node")
	assert("if not is_instance_valid(_transitions_node):" in source, "EnemyContext should validate _transitions_node before returning it")
	assert("_transitions_node = null" in source, "EnemyContext should clear invalid cached _transitions_node")
	print("✓ EnemyContext source guards against stale players/transitions references")


func _read_source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "Should be able to open %s" % path)
	return file.get_as_text()
