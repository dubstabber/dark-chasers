@tool
class_name KeyIconLibrary
extends Resource

## Resource-based catalog for key icon textures.
## Decouples key display logic from hardcoded res:// paths.

@export var keys: Array[KeyIconEntry] = []

var _keys_by_type: Dictionary[StringName, KeyIconEntry] = {}
var _cache_valid := false


func _init() -> void:
	changed.connect(_invalidate_cache)


func _invalidate_cache() -> void:
	_cache_valid = false


func _ensure_cache() -> void:
	if _cache_valid:
		return

	_keys_by_type.clear()
	for entry in keys:
		if entry == null:
			continue
		if entry.key_type == &"":
			continue
		if _keys_by_type.has(entry.key_type):
			push_warning("KeyIconLibrary: Duplicate key_type '%s'" % String(entry.key_type))
		_keys_by_type[entry.key_type] = entry

	_cache_valid = true


func get_texture(key_type: String) -> Texture2D:
	_ensure_cache()
	var entry: KeyIconEntry = _keys_by_type.get(StringName(key_type))
	if entry and entry.texture:
		return entry.texture

	# Legacy behavior: unknown key types fall back to the silver key (when present).
	var fallback: KeyIconEntry = _keys_by_type.get(&"silver")
	return fallback.texture if fallback else null


func get_all_textures() -> Dictionary:
	_ensure_cache()
	var out: Dictionary = {}
	for key in _keys_by_type.keys():
		var entry: KeyIconEntry = _keys_by_type[key]
		out[String(key)] = entry.texture
	return out


func get_pickup_message(key_type: String) -> String:
	_ensure_cache()
	var entry: KeyIconEntry = _keys_by_type.get(StringName(key_type))
	if entry and not entry.pickup_message.is_empty():
		return entry.pickup_message
	return "Picked up a key."
