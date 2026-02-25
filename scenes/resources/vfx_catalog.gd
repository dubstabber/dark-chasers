@tool
class_name VfxCatalog
extends Resource

## Resource-based catalog for VFX PackedScene effects.
## For scrap textures and sounds, use ParticleCatalog instead.

@export var scenes: Array[VfxEntry] = []

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
	for entry in scenes:
		if entry == null:
			continue
		if entry.id == &"":
			continue
		if _scenes_by_id.has(entry.id):
			push_warning("VfxCatalog: Duplicate scene id '%s'" % String(entry.id))
		_scenes_by_id[entry.id] = entry.scene

	_cache_valid = true


func get_scene(id: StringName) -> PackedScene:
	_ensure_cache()
	return _scenes_by_id[id] if _scenes_by_id.has(id) else null


func get_scrap_scene() -> PackedScene:
	return get_scene(&"scrap")
