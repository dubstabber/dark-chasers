@tool
class_name SfxCatalog
extends Resource

## Resource-based catalog for game sound effects.
## Decouples sound playback from hardcoded res:// paths in Preloads.

@export var sounds: Array[SfxEntry] = []

var _sounds_by_id: Dictionary[StringName, AudioStream] = {}
var _cache_valid := false


func _init() -> void:
	changed.connect(_invalidate_cache)


func _invalidate_cache() -> void:
	_cache_valid = false


func _ensure_cache() -> void:
	if _cache_valid:
		return

	_sounds_by_id.clear()
	for entry in sounds:
		if entry == null:
			continue
		if entry.id == &"":
			continue
		if _sounds_by_id.has(entry.id):
			push_warning("SfxCatalog: Duplicate sound id '%s'" % String(entry.id))
		_sounds_by_id[entry.id] = entry.stream

	_cache_valid = true


func get_sound(id: StringName) -> AudioStream:
	_ensure_cache()
	return _sounds_by_id[id] if _sounds_by_id.has(id) else null
