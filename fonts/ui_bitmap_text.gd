extends HBoxContainer

@export var ui_bitmap_font_catalog: BitmapFontCatalog

var _font_catalog: BitmapFontCatalog

var font_scale := 0.4


func _ready() -> void:
	_font_catalog = ui_bitmap_font_catalog


func set_font_catalog(catalog: BitmapFontCatalog) -> void:
	_font_catalog = catalog


func set_value_with_aooni_font(value: int) -> void:
	for node in get_children():
		remove_child(node)
		node.queue_free()
	
	# Hide value display when the value represents **infinite** (sentinel -1)
	if value < 0:
		return

	if not _font_catalog:
		_font_catalog = ui_bitmap_font_catalog
	if not _font_catalog:
		return

	var value_text := str(value)
	
	for digit: String in value_text:
		var texture := _font_catalog.get_texture(digit)
		if not texture:
			continue
		var digit_texture = TextureRect.new()
		digit_texture.texture = texture
		digit_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		digit_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(digit_texture)
