extends Node

## Database of static-image enemy definitions.
## Uses typed EnemyDefinition resources for editor tooling and validation.

var ENEMIES: Array[EnemyDefinition] = []

var _definitions_by_name: Dictionary = {}


func _ready() -> void:
	_load_definitions()


func _load_definitions() -> void:
	ENEMIES = [
		preload("res://scenes/resources/enemies/swag_hacker.tres"),
		preload("res://scenes/resources/enemies/botanicula_onion.tres"),
		preload("res://scenes/resources/enemies/giga_chad.tres"),
		preload("res://scenes/resources/enemies/obunga.tres"),
		preload("res://scenes/resources/enemies/angry_german_kid.tres"),
	]
	
	# Build lookup table
	for def in ENEMIES:
		_definitions_by_name[def.enemy_name] = def


func get_by_name(enemy_name: String) -> EnemyDefinition:
	return _definitions_by_name.get(enemy_name)


func get_random() -> EnemyDefinition:
	return ENEMIES.pick_random()
