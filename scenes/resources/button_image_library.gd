@tool
class_name ButtonImageLibrary
extends Resource

## Resource-based catalog for button textures.
## Maps button types to their pressed/unpressed states.

@export var buttons: Array[ButtonImageEntry] = []

var _buttons_by_type: Dictionary[StringName, ButtonImageEntry] = {}
var _cache_valid := false


func _init() -> void:
	changed.connect(_invalidate_cache)


func _invalidate_cache() -> void:
	_cache_valid = false


func _ensure_cache() -> void:
	if _cache_valid:
		return

	_buttons_by_type.clear()
	for entry in buttons:
		if entry == null:
			continue
		if entry.button_type == &"":
			continue
		if _buttons_by_type.has(entry.button_type):
			push_warning("ButtonImageLibrary: Duplicate button_type '%s'" % String(entry.button_type))
		_buttons_by_type[entry.button_type] = entry

	_cache_valid = true


func get_texture(button_type: String, is_pressed: bool) -> Texture2D:
	_ensure_cache()
	var entry: ButtonImageEntry = _buttons_by_type.get(StringName(button_type))
	if entry:
		return entry.down if is_pressed else entry.up

	push_warning("ButtonImageLibrary: Unknown button type '%s'" % button_type)
	var fallback: ButtonImageEntry = _buttons_by_type.get(&"circle")
	if not fallback and not _buttons_by_type.is_empty():
		fallback = _buttons_by_type.values()[0]
	return (fallback.down if is_pressed else fallback.up) if fallback else null
