class_name VfxCatalog
extends Resource

## Resource-based catalog for VFX scenes and particle textures.
## Decouples VFX spawning from hardcoded res:// paths.

@export_group("Scenes")
@export var scrap_scene: PackedScene
@export var red_blood_particle: PackedScene
@export var blue_blood_particle: PackedScene
@export var blood_splat_decal: PackedScene

@export_group("Scrap Textures")
@export var small_wood_images: Array[Texture2D]
@export var big_wood_images: Array[Texture2D]
@export var white_scrap_images: Array[Texture2D]
@export var pot_scrap_images: Array[Texture2D]
@export var circle_ground_scrap_image: Texture2D
@export var small_ground_scrap_image: Texture2D
@export var grass_scrap_images: Array[Texture2D]
@export var paper_scrap_images: Array[Texture2D]
@export var glass_scrap_images: Array[Texture2D]

@export_group("Decal Textures")
@export var doom_decal_images: Array[Texture2D]


func get_scrap_textures(scrap_type: String) -> Array[Texture2D]:
	match scrap_type:
		"small wood scrap": return small_wood_images
		"big wood scrap": return big_wood_images
		"white scrap": return white_scrap_images
		"pot scrap": return pot_scrap_images
		"grass scrap": return grass_scrap_images
		"paper scrap": return paper_scrap_images
		"glass scrap": return glass_scrap_images
		_: return []


func get_single_scrap_texture(scrap_type: String) -> Texture2D:
	match scrap_type:
		"circle ground scrap": return circle_ground_scrap_image
		"small ground scrap": return small_ground_scrap_image
		_: return null
