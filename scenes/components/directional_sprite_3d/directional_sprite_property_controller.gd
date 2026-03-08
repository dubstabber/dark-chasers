class_name DirectionalSpritePropertyController
extends RefCounted


func get_dynamic_property(property: StringName, idle_sprites: Dictionary, movement_sprites: Dictionary, shooting_sprites: Dictionary, idle_suffix: String, movement_suffix: String, shooting_suffix: String):
	var prop_name := str(property)
	if prop_name.ends_with(idle_suffix):
		return idle_sprites.get(prop_name.replace(idle_suffix, ""))
	if prop_name.ends_with(movement_suffix):
		var movement_direction := prop_name.replace(movement_suffix, "")
		if not movement_sprites.has(movement_direction):
			movement_sprites[movement_direction] = []
		return movement_sprites[movement_direction]
	if prop_name.ends_with(shooting_suffix):
		var shooting_direction := prop_name.replace(shooting_suffix, "")
		if not shooting_sprites.has(shooting_direction):
			shooting_sprites[shooting_direction] = []
		return shooting_sprites[shooting_direction]
	return null


func set_dynamic_property(property: StringName, value, valid_directions: Array, idle_sprites: Dictionary, movement_sprites: Dictionary, shooting_sprites: Dictionary, idle_suffix: String, movement_suffix: String, shooting_suffix: String) -> bool:
	var prop_name := str(property)
	if prop_name.ends_with(idle_suffix):
		var idle_direction := prop_name.replace(idle_suffix, "")
		if idle_direction in valid_directions:
			idle_sprites[idle_direction] = value
			return true
	if prop_name.ends_with(movement_suffix):
		var movement_direction := prop_name.replace(movement_suffix, "")
		if movement_direction in valid_directions:
			movement_sprites[movement_direction] = value
			return true
	if prop_name.ends_with(shooting_suffix):
		var shooting_direction := prop_name.replace(shooting_suffix, "")
		if shooting_direction in valid_directions:
			shooting_sprites[shooting_direction] = value
			return true
	return false


func build_property_list(directions: Array, has_moving_state: bool, has_shooting_state: bool, idle_suffix: String, movement_suffix: String, shooting_suffix: String) -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	_add_sprite_group_properties(properties, "Idle sprites", directions, idle_suffix, TYPE_OBJECT, "Texture2D")
	if has_moving_state:
		_add_sprite_group_properties(properties, "Movement sprites", directions, movement_suffix, TYPE_ARRAY, "%d/%d:Texture2D" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE])
	if has_shooting_state:
		_add_sprite_group_properties(properties, "Shooting sprites", directions, shooting_suffix, TYPE_ARRAY, "%d/%d:Texture2D" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE])
	return properties


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
