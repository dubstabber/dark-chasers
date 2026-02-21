extends Control

var _font_catalog

@export var font_scale := 0.4
var special_character_offsets: Dictionary

# Predefined color names for BBCode-like tags
var color_names := {
	"red": Color.RED,
	"green": Color.GREEN,
	"blue": Color.BLUE,
	"yellow": Color.YELLOW,
	"white": Color.WHITE,
	"black": Color.BLACK,
	"orange": Color.ORANGE,
	"purple": Color.PURPLE,
	"cyan": Color.CYAN,
	"pink": Color.HOT_PINK,
	"gray": Color.GRAY,
	"grey": Color.GRAY,
}


func _ready():
	_font_catalog = Services.get_bitmap_font_catalog()
	set_font_scale(font_scale)


func set_font_scale(sc: float):
	font_scale = sc
	special_character_offsets = {
		'.': 30 * font_scale,
		',': 25 * font_scale,
		'_': 33 * font_scale,
		':': 5 * font_scale,
	}


## Parses BBCode-like text and returns an array of segments.
## Each segment is a Dictionary with "text" and "color" keys.
## Supports: [color=name]text[/color] or [color=#RRGGBB]text[/color]
func _parse_bbcode(text: String) -> Array:
	var segments := []
	var regex := RegEx.new()
	# Match [color=value]content[/color] patterns
	regex.compile("\\[color=([^\\]]+)\\]([^\\[]*?)\\[/color\\]")
	
	var last_end := 0
	for result in regex.search_all(text):
		# Add text before this tag as default color
		if result.get_start() > last_end:
			var before_text := text.substr(last_end, result.get_start() - last_end)
			if before_text.length() > 0:
				segments.append({"text": before_text, "color": Color.WHITE})
		
		# Parse the color value
		var color_value := result.get_string(1).strip_edges().to_lower()
		var parsed_color := Color.WHITE
		
		if color_value.begins_with("#"):
			# Hex color
			parsed_color = Color.from_string(color_value, Color.WHITE)
		elif color_names.has(color_value):
			# Named color
			parsed_color = color_names[color_value]
		
		# Add the colored segment
		var content := result.get_string(2)
		if content.length() > 0:
			segments.append({"text": content, "color": parsed_color})
		
		last_end = result.get_end()
	
	# Add remaining text after last tag
	if last_end < text.length():
		var remaining := text.substr(last_end)
		if remaining.length() > 0:
			segments.append({"text": remaining, "color": Color.WHITE})
	
	# If no tags were found, return the whole text as white
	if segments.is_empty():
		segments.append({"text": text, "color": Color.WHITE})
	
	return segments


func set_text_with_aooni_font(new_text: String) -> void:
	for node in get_children():
		remove_child(node)
		node.queue_free()
	if not new_text:
		return
	
	var character_spacing = 25 * font_scale
	var character_size = 5
	var current_x = 0
	var y_offset = 0
	
	# Parse BBCode-like tags
	var segments := _parse_bbcode(new_text)
	
	for segment in segments:
		var segment_text: String = segment["text"]
		var segment_color: Color = segment["color"]
		
		for character in segment_text:
			var image_path: Texture2D = _font_catalog.get_texture(character) if _font_catalog else null
			if image_path:
				var character_sprite = TextureRect.new()
				character_sprite.texture = image_path
				character_sprite.scale = Vector2(font_scale, font_scale / 2.0)
				character_sprite.modulate = segment_color
				
				if character in special_character_offsets:
					y_offset = special_character_offsets[character]
				else:
					y_offset = 0
				character_sprite.position.x = current_x
				character_sprite.position.y = y_offset
				
				add_child(character_sprite)
				current_x += character_sprite.texture.get_width() * font_scale
			else:
				current_x += character_spacing
	
	custom_minimum_size = Vector2(current_x, character_size)
