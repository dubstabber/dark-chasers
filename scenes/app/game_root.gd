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
	var catalog: SceneCatalog = null
	if Services:
		catalog = Services.get_scene_catalog()

	# Inspector wiring on GameRoot should always win.
	var selected_default := default_game_scene
	var selected_main_menu := main_menu_scene

	# Catalog provides fallback defaults when inspector exports are not set.
	if catalog:
		if selected_default == null:
			selected_default = catalog.get_map_scene(&"mansion_1")
		if selected_main_menu == null:
			selected_main_menu = catalog.get_main_menu_scene()

	if skip_main_menu_for_dev:
		return selected_default
	if selected_main_menu:
		return selected_main_menu
	if selected_default:
		push_warning("GameRoot: main_menu_scene is not set. Falling back to default_game_scene.")
		return selected_default
	return null


func _load_scene_into_level_host(scene: PackedScene) -> void:
	if not level_host:
		push_warning("GameRoot: LevelHost is missing; cannot load startup scene.")
		return

	for child in level_host.get_children():
		level_host.remove_child(child)
		child.queue_free()

	var scene_instance := scene.instantiate()
	level_host.add_child(scene_instance)


func _register_level_host_with_level_manager() -> void:
	if not (Services and Services.level_manager):
		push_warning("GameRoot: Services.level_manager is unavailable; startup will use direct LevelHost loading.")
		return
	var lm := Services.level_manager as LevelManager
	if lm == null:
		push_warning("GameRoot: Services.level_manager is not a LevelManager")
		return
	lm.register_level_host(level_host)


func _request_startup_transition(scene: PackedScene) -> Error:
	if not (Services and Services.level_manager):
		return ERR_UNAVAILABLE
	var lm := Services.level_manager as LevelManager
	if lm == null:
		return ERR_UNAVAILABLE

	if scene.resource_path == "":
		push_warning("GameRoot: Startup scene has no resource_path. Falling back to direct instantiation.")
		return ERR_UNAVAILABLE
	return lm.request_level_transition_scene(scene, {
		"startup": true
	})
