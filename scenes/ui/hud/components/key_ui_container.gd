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
	var total_keys := collected_keys.size()

	# Determine how many keys should go into the first (left-most) column.
	# The goal is to keep columns balanced while ensuring that each column
	# contains at most MAX_KEYS_PER_COLUMN keys.
	var first_col_size: int = total_keys % MAX_KEYS_PER_COLUMN
	if first_col_size == 0:
		first_col_size = min(total_keys, MAX_KEYS_PER_COLUMN) # Handles 1-3, 3, 6, 9 … keys

	var start_idx: int = 0
	while start_idx < total_keys:
		var column_capacity: int = first_col_size if start_idx == 0 else MAX_KEYS_PER_COLUMN
		var end_idx: int = min(start_idx + column_capacity, total_keys)

		var column_keys := collected_keys.slice(start_idx, end_idx)
		_create_and_populate_column(column_keys)

		start_idx = end_idx


func _create_and_populate_column(keys: Array) -> void:
	"""Create a column and populate it with the given keys (newest at top, oldest at bottom)"""
	var column_container = _create_key_column()
	var column = column_container.get_child(0) as VBoxContainer
	add_child(column_container)

	# Reverse keys so newest is at top, oldest at bottom
	var column_keys = keys.duplicate()
	column_keys.reverse()

	for key_type in column_keys:
		if key_type in key_textures:
			var key_texture_rect = _create_key_texture_rect(key_type)
			column.add_child(key_texture_rect)


func _distribute_remaining_keys(remaining_keys: Array) -> void:
	"""Distribute remaining keys across subsequent columns (3 keys max per column)"""
	var remaining_count = remaining_keys.size()
	var additional_columns = ceili(float(remaining_count) / float(MAX_KEYS_PER_COLUMN))

	for column_index in range(additional_columns):
		var start_key_index = column_index * MAX_KEYS_PER_COLUMN
		var end_key_index = min(start_key_index + MAX_KEYS_PER_COLUMN, remaining_count)

		var column_keys = remaining_keys.slice(start_key_index, end_key_index)
		_create_and_populate_column(column_keys)


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
