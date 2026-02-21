@tool
class_name BitmapFontCatalog
extends Resource

const BitmapFontGlyphScript = preload("res://scenes/resources/bitmap_font_glyph.gd")

## Resource-based catalog for Ao Oni bitmap font glyph textures.
## Strictly inspector-assigned glyph textures.
## Add entries in the inspector: key = letter/sign, texture = image.

@export_group("Manual Mapping")
@export var glyphs: Array[BitmapFontGlyphScript] = []


func get_texture(character: String) -> Texture2D:
	if character.is_empty():
		return null

	var key := character.left(1)
	for glyph in glyphs:
		if glyph == null:
			continue
		if glyph.key == key:
			return glyph.texture

	return null
