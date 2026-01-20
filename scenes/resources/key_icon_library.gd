class_name KeyIconLibrary
extends Resource

## Resource-based catalog for key icon textures.
## Decouples key display logic from hardcoded res:// paths.

@export var ruby: Texture2D
@export var weird: Texture2D
@export var brown: Texture2D
@export var gold: Texture2D
@export var emerald: Texture2D
@export var silver: Texture2D


func get_texture(key_type: String) -> Texture2D:
	match key_type:
		"ruby": return ruby
		"weird": return weird
		"brown": return brown
		"gold": return gold
		"emerald": return emerald
		"silver": return silver
		_: return silver


func get_all_textures() -> Dictionary:
	return {
		"ruby": ruby,
		"weird": weird,
		"brown": brown,
		"gold": gold,
		"emerald": emerald,
		"silver": silver
	}
