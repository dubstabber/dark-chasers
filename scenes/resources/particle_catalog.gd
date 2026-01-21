class_name ParticleCatalog
extends Resource

## Catalog of particle/scrap images and related sounds.
## Replaces hardcoded arrays in Preloads for better maintainability and editor tooling.

@export_group("Wood Particles")
@export var small_wood_images: Array[Texture2D] = []
@export var big_wood_images: Array[Texture2D] = []
@export var wood_break_sound: AudioStream

@export_group("Paper Particles")
@export var paper_scrap_images: Array[Texture2D] = []
@export var paper_break_sound: AudioStream

@export_group("Glass Particles")
@export var glass_scrap_images: Array[Texture2D] = []
@export var glass_break_sound: AudioStream

@export_group("Pot Particles")
@export var pot_scrap_images: Array[Texture2D] = []
@export var pot_break_sound: AudioStream

@export_group("White Scrap Particles")
@export var white_scrap_images: Array[Texture2D] = []

@export_group("Ground Particles")
@export var circle_ground_scrap_image: Texture2D
@export var small_ground_scrap_image: Texture2D
@export var grass_scrap_images: Array[Texture2D] = []

@export_group("Decal Images")
@export var doom_decal_images: Array[Texture2D] = []

@export_group("Scenes")
@export var scrap_scene: PackedScene


func get_random_small_wood() -> Texture2D:
	return small_wood_images.pick_random() if not small_wood_images.is_empty() else null


func get_random_big_wood() -> Texture2D:
	return big_wood_images.pick_random() if not big_wood_images.is_empty() else null


func get_random_paper() -> Texture2D:
	return paper_scrap_images.pick_random() if not paper_scrap_images.is_empty() else null


func get_random_glass() -> Texture2D:
	return glass_scrap_images.pick_random() if not glass_scrap_images.is_empty() else null


func get_random_pot() -> Texture2D:
	return pot_scrap_images.pick_random() if not pot_scrap_images.is_empty() else null


func get_random_doom_decal() -> Texture2D:
	return doom_decal_images.pick_random() if not doom_decal_images.is_empty() else null
