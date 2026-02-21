@tool
class_name BitmapFontGlyph
extends Resource

## Single bitmap-font glyph mapping entry.
## key: one visible character/sign used by BitmapText.
## texture: image that should be shown for that character.

@export var key: String = "":
	set(value):
		key = value.left(1)

@export var texture: Texture2D
