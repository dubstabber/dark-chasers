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
	_register_level_host_with_level_manager()

	var startup_scene := _select_startup_scene()
	if not startup_scene:
		push_warning("GameRoot: No startup scene configured. Assign default_game_scene (and optionally main_menu_scene).")
		return

	if _request_startup_transition(startup_scene) == OK:
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


func _register_level_host_with_level_manager() -> void:
	if not (Services and Services.level_manager):
		push_warning("GameRoot: Services.level_manager is unavailable; startup will use direct LevelHost loading.")
		return

	if not Services.level_manager.has_method("register_level_host"):
		push_warning("GameRoot: Services.level_manager does not support register_level_host.")
		return

	Services.level_manager.register_level_host(level_host)


func _request_startup_transition(scene: PackedScene) -> Error:
	if not (Services and Services.level_manager):
		return ERR_UNAVAILABLE

	if not Services.level_manager.has_method("request_level_transition"):
		return ERR_UNAVAILABLE

	if scene.resource_path == "":
		push_warning("GameRoot: Startup scene has no resource_path. Falling back to direct instantiation.")
		return ERR_UNAVAILABLE

	return Services.level_manager.request_level_transition(scene.resource_path, {
		"startup": true
	})
