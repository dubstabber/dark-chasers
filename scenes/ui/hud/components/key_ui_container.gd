extends HBoxContainer

# Dictionary mapping key types to their textures
var key_textures := {
	"ruby": Preloads.RUBY_KEY_IMAGE,
	"weird": Preloads.WEIRD_KEY_IMAGE,
	"brown": Preloads.BROWN_KEY_IMAGE,
	"gold": Preloads.GOLD_KEY_IMAGE,
	"emerald": Preloads.EMERALD_KEY_IMAGE,
	"silver": Preloads.SILVER_KEY_IMAGE
}

# Size for key icons in the UI
const KEY_ICON_SIZE := Vector2(18, 18)
const KEY_SPACING := 4
const COLUMN_SPACING := 8
const MAX_KEYS_PER_COLUMN := 3


func update_keys_ui(collected_keys: Array) -> void:
	# Clear existing key displays
	for node in get_children():
		remove_child(node)
		node.queue_free()

	# Return early if no keys to display
	if collected_keys.is_empty():
		return

	# collected_keys array: index 0 = oldest, last index = newest
	var total_keys = collected_keys.size()

	# Special distribution logic based on examples:
	# 2 keys (A, B): Column 1 = [A, B]
	# 3 keys (A, B, C): Column 1 = [A at bottom, B, C at top]
	# 4 keys (A, B, C, D): Column 1 = [A], Column 2 = [B, C, D] with B at bottom and D at top
	# 5 keys (A, B, C, D, E): Column 1 = [A at bottom, B at top], Column 2 = [E at top, D, C at bottom]

	if total_keys <= 3:
		# Single column for 1-3 keys
		var column_container = _create_key_column()
		var column = column_container.get_child(0) as VBoxContainer
		add_child(column_container)

		# Reverse keys so newest is at top, oldest at bottom
		var column_keys = collected_keys.duplicate()
		column_keys.reverse()

		for key_type in column_keys:
			if key_type in key_textures:
				var key_texture_rect = _create_key_texture_rect(key_type)
				column.add_child(key_texture_rect)

	elif total_keys == 4:
		# Special case: First column gets only oldest key, second column gets remaining 3
		# Column 1: [A]
		var first_column_container = _create_key_column()
		var first_column = first_column_container.get_child(0) as VBoxContainer
		add_child(first_column_container)

		var oldest_key = collected_keys[0]
		if oldest_key in key_textures:
			var key_texture_rect = _create_key_texture_rect(oldest_key)
			first_column.add_child(key_texture_rect)

		# Column 2: [B, C, D] with B at bottom and D at top
		var second_column_container = _create_key_column()
		var second_column = second_column_container.get_child(0) as VBoxContainer
		add_child(second_column_container)

		var remaining_keys = collected_keys.slice(1) # [B, C, D]
		remaining_keys.reverse() # [D, C, B] - newest to oldest

		for key_type in remaining_keys:
			if key_type in key_textures:
				var key_texture_rect = _create_key_texture_rect(key_type)
				second_column.add_child(key_texture_rect)

	else:
		# For 5+ keys: First column gets first 2 keys, remaining keys distributed in subsequent columns
		# Column 1: [A at bottom, B at top]
		var first_column_container = _create_key_column()
		var first_column = first_column_container.get_child(0) as VBoxContainer
		add_child(first_column_container)

		var first_two_keys = collected_keys.slice(0, 2) # [A, B]
		first_two_keys.reverse() # [B, A] - newest to oldest

		for key_type in first_two_keys:
			if key_type in key_textures:
				var key_texture_rect = _create_key_texture_rect(key_type)
				first_column.add_child(key_texture_rect)

		# Remaining keys distributed in subsequent columns
		var remaining_keys = collected_keys.slice(2) # All keys from index 2 onwards
		var remaining_count = remaining_keys.size()
		var additional_columns = ceili(float(remaining_count) / float(MAX_KEYS_PER_COLUMN))

		for column_index in range(additional_columns):
			var column_container = _create_key_column()
			var column = column_container.get_child(0) as VBoxContainer
			add_child(column_container)

			var start_key_index = column_index * MAX_KEYS_PER_COLUMN
			var end_key_index = min(start_key_index + MAX_KEYS_PER_COLUMN, remaining_count)

			var column_keys = remaining_keys.slice(start_key_index, end_key_index)
			column_keys.reverse() # Newest to oldest

			for key_type in column_keys:
				if key_type in key_textures:
					var key_texture_rect = _create_key_texture_rect(key_type)
					column.add_child(key_texture_rect)


func _create_key_column() -> MarginContainer:
	"""Create a new VBoxContainer column for keys wrapped in a MarginContainer"""
	var column = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_BEGIN # Top alignment for all columns

	# Add margin container for column spacing
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_right", COLUMN_SPACING)
	margin_container.add_child(column)

	return margin_container


func _create_key_texture_rect(key_type: String) -> MarginContainer:
	"""Create a TextureRect for a specific key type wrapped in a MarginContainer"""
	var key_texture_rect = TextureRect.new()
	key_texture_rect.texture = key_textures[key_type]
	key_texture_rect.custom_minimum_size = KEY_ICON_SIZE
	key_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	key_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Add visual styling
	key_texture_rect.modulate = Color.WHITE

	# Add margin container for vertical spacing between keys
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_bottom", KEY_SPACING)
	margin_container.add_child(key_texture_rect)

	return margin_container


func get_collected_keys_from_level() -> Array:
	"""Get collected keys from the current level/map"""
	var level = get_tree().get_first_node_in_group("level")
	if level and "keys_collected" in level:
		return level.keys_collected
	return []


func refresh_display() -> void:
	"""Refresh the key display by getting keys from the current level"""
	var collected_keys = get_collected_keys_from_level()
	update_keys_ui(collected_keys)
