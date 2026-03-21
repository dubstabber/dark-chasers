class_name DirectionalSpritePropertyController
extends RefCounted


func get_dynamic_property(property: StringName, idle_sprites: Dictionary, movement_sprites: Dictionary, shooting_sprites: Dictionary, idle_uses_animation, idle_suffix: String, movement_suffix: String, shooting_suffix: String):
	var prop_name := str(property)
	var idle_uses_animation_value := _normalize_idle_uses_animation(idle_uses_animation)
	if prop_name.ends_with(idle_suffix):
		return _get_idle_property_value(idle_sprites.get(prop_name.replace(idle_suffix, "")), idle_uses_animation_value)
	if prop_name.ends_with(movement_suffix):
		var movement_direction := prop_name.replace(movement_suffix, "")
		if not movement_sprites.has(movement_direction):
			movement_sprites[movement_direction] = []
		return _sanitize_texture_slot_array(movement_sprites[movement_direction])
	if prop_name.ends_with(shooting_suffix):
		var shooting_direction := prop_name.replace(shooting_suffix, "")
		if not shooting_sprites.has(shooting_direction):
			shooting_sprites[shooting_direction] = []
		return _sanitize_texture_slot_array(shooting_sprites[shooting_direction])
	return null


func set_dynamic_property(property: StringName, value, valid_directions: Array, idle_sprites: Dictionary, movement_sprites: Dictionary, shooting_sprites: Dictionary, idle_uses_animation, idle_suffix: String, movement_suffix: String, shooting_suffix: String) -> bool:
	var prop_name := str(property)
	var idle_uses_animation_value := _normalize_idle_uses_animation(idle_uses_animation)
	if prop_name.ends_with(idle_suffix):
		var idle_direction := prop_name.replace(idle_suffix, "")
		if idle_direction in valid_directions:
			idle_sprites[idle_direction] = _sanitize_sprite_property_value(value, idle_uses_animation_value)
			return true
	if prop_name.ends_with(movement_suffix):
		var movement_direction := prop_name.replace(movement_suffix, "")
		if movement_direction in valid_directions:
			movement_sprites[movement_direction] = _sanitize_sprite_property_value(value, true)
			return true
	if prop_name.ends_with(shooting_suffix):
		var shooting_direction := prop_name.replace(shooting_suffix, "")
		if shooting_direction in valid_directions:
			shooting_sprites[shooting_direction] = _sanitize_sprite_property_value(value, true)
			return true
	return false


func build_property_list(directions: Array, has_moving_state: bool, has_shooting_state: bool, idle_uses_animation, idle_suffix: String, movement_suffix: String, shooting_suffix: String) -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	var idle_uses_animation_value := _normalize_idle_uses_animation(idle_uses_animation)
	var idle_property_type := TYPE_ARRAY if idle_uses_animation_value else TYPE_OBJECT
	var idle_hint_string := "%d/%d:Texture2D" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE] if idle_uses_animation_value else "Texture2D"
	_add_sprite_group_properties(properties, "Idle sprites", directions, idle_suffix, idle_property_type, idle_hint_string)
	if has_moving_state:
		_add_sprite_group_properties(properties, "Movement sprites", directions, movement_suffix, TYPE_ARRAY, "%d/%d:Texture2D" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE])
	if has_shooting_state:
		_add_sprite_group_properties(properties, "Shooting sprites", directions, shooting_suffix, TYPE_ARRAY, "%d/%d:Texture2D" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE])
	return properties


func _get_idle_property_value(value, idle_uses_animation: bool):
	if idle_uses_animation:
		if value is Array:
			return _sanitize_texture_slot_array(value)
		if value is Texture2D:
			return [value]
		return []
	if value is Array:
		var textures := _sanitize_texture_array(value)
		return textures[0] if not textures.is_empty() else null
	return value if value is Texture2D else null


func _sanitize_sprite_property_value(value, preserve_array_slots: bool = false):
	if value is Array:
		return _sanitize_texture_slot_array(value) if preserve_array_slots else _sanitize_texture_array(value)
	if value is Texture2D:
		return value
	return null


func _sanitize_texture_array(value: Array) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for sprite in value:
		if sprite is Texture2D:
			textures.append(sprite)
	return textures


func _sanitize_texture_slot_array(value: Array) -> Array:
	var textures: Array = []
	for sprite in value:
		if sprite == null or sprite is Texture2D:
			textures.append(sprite)
	return textures


func _normalize_idle_uses_animation(value) -> bool:
	return value if value is bool else false


func _add_sprite_group_properties(properties: Array[Dictionary], group_name: String, directions: Array, suffix: String, property_type: int, hint_string: String) -> void:
	properties.append({
		"name": group_name,
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP,
	})
	var hint_type = PROPERTY_HINT_RESOURCE_TYPE if property_type == TYPE_OBJECT else PROPERTY_HINT_ARRAY_TYPE
	for direction in directions:
		properties.append({
			"name": direction + suffix,
			"type": property_type,
			"hint": hint_type,
			"hint_string": hint_string,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
