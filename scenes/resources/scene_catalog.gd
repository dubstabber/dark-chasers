@tool
class_name SceneCatalog
extends Resource

## Resource-based catalog for core game scenes (player, HUD, enemies).
## Decouples scene instantiation from hardcoded res:// paths in Preloads.

## NOTE: Entries are stored as SceneCatalogEntry resources
## so the catalog can be extended purely via inspector edits without having to
## add new exported vars to this script.

@export_group("Core Scenes")
@export var core_scenes: Array[SceneCatalogEntry] = []

@export_group("Enemy Scenes")
@export var enemy_scenes: Array[SceneCatalogEntry] = []

@export_group("Map Scenes")
@export var map_scenes: Array[SceneCatalogEntry] = []

@export_group("Menu Scenes")
@export var menu_scenes: Array[SceneCatalogEntry] = []

var _scenes_by_id: Dictionary[StringName, PackedScene] = {}
var _cache_valid := false


func _init() -> void:
	changed.connect(_invalidate_cache)


func _invalidate_cache() -> void:
	_cache_valid = false


func _ensure_cache() -> void:
	if _cache_valid:
		return

	_scenes_by_id.clear()
	_add_entries_from_array(core_scenes)
	_add_entries_from_array(enemy_scenes)
	_add_entries_from_array(map_scenes)
	_add_entries_from_array(menu_scenes)

	_cache_valid = true


func _add_entries_from_array(entries: Array[SceneCatalogEntry]) -> void:
	for entry in entries:
		if entry == null:
			continue
		if entry.id == &"":
			continue
		if entry.scene == null:
			continue

		if _scenes_by_id.has(entry.id):
			push_warning("SceneCatalog: Duplicate id '%s'" % String(entry.id))
		_scenes_by_id[entry.id] = entry.scene


func get_scene(scene_id: StringName) -> PackedScene:
	_ensure_cache()
	var value: PackedScene = _scenes_by_id.get(scene_id)
	return value


func get_player_scene() -> PackedScene:
	return get_scene(&"player")


func get_hud_scene() -> PackedScene:
	return get_scene(&"hud")


func get_main_menu_scene() -> PackedScene:
	return get_scene(&"main_menu")


func get_enemy_scene(enemy_id: StringName) -> PackedScene:
	return get_scene(enemy_id)


func get_map_scene(map_id: StringName) -> PackedScene:
	return get_scene(map_id)


## Accepts both new-style ids (e.g. &"mansion_1") and legacy *property* keys
## from the old export-var era (e.g. &"mansion_1_scene").
func resolve_scene_key(key: StringName) -> PackedScene:
	if key == &"":
		return null
	return get_scene(_legacy_key_to_id(key))


func _legacy_key_to_id(key: StringName) -> StringName:
	var s := String(key)
	if s.ends_with("_scene"):
		s = s.trim_suffix("_scene")
	return StringName(s)
