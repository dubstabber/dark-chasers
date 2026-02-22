class_name EnemyDb
extends Node

## Database of static-image enemy definitions.
## Uses typed EnemyDefinition resources for editor tooling and validation.

const ENEMY_DEFINITIONS_DIR := "res://scenes/resources/enemies"

var ENEMIES: Array[EnemyDefinition] = []

var _definitions_by_name: Dictionary = {}


func _ready() -> void:
	_load_definitions()


func _load_definitions() -> void:
	ENEMIES.clear()
	_definitions_by_name.clear()

	var dir := DirAccess.open(ENEMY_DEFINITIONS_DIR)
	if not dir:
		push_warning("EnemyDb: Could not open %s" % ENEMY_DEFINITIONS_DIR)
		return

	var definition_paths: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			definition_paths.append(ENEMY_DEFINITIONS_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

	definition_paths.sort()
	for path in definition_paths:
		var definition = load(path)
		if definition is EnemyDefinition:
			ENEMIES.append(definition)
			_definitions_by_name[definition.enemy_name] = definition
		else:
			push_warning("EnemyDb: Skipping non-EnemyDefinition resource: %s" % path)


func get_by_name(enemy_name: String) -> EnemyDefinition:
	return _definitions_by_name.get(enemy_name)


func get_random() -> EnemyDefinition:
	if ENEMIES.is_empty():
		return null
	return ENEMIES.pick_random()
