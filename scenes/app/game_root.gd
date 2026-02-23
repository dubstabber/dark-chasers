class_name GameRoot
extends Node

## Persistent application root.
## Owns app-level scene flow and hosts active levels.
## Ownership contract: LevelManager is the only system that may replace
## children of LevelHost during cross-level transitions.

@export var skip_main_menu_for_dev: bool = true
@export var default_game_scene: PackedScene
@export var main_menu_scene: PackedScene

@onready var level_host: Node = $LevelHost


func _ready() -> void:
	var startup_scene := _select_startup_scene()
	if not startup_scene:
		push_warning("GameRoot: No startup scene configured. Assign default_game_scene (and optionally main_menu_scene).")
		return
	_load_scene_into_level_host(startup_scene)


func _select_startup_scene() -> PackedScene:
	if skip_main_menu_for_dev:
		return default_game_scene

	if main_menu_scene:
		return main_menu_scene

	if default_game_scene:
		push_warning("GameRoot: main_menu_scene is not set. Falling back to default_game_scene.")
		return default_game_scene

	return null


func _load_scene_into_level_host(scene: PackedScene) -> void:
	if not level_host:
		push_warning("GameRoot: LevelHost is missing; cannot load startup scene.")
		return

	for child in level_host.get_children():
		child.queue_free()

	var scene_instance := scene.instantiate()
	level_host.add_child(scene_instance)
