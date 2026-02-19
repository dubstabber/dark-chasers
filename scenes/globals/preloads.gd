class_name Preloads
extends Node

## Preloads autoload - compatibility adapter over Resource-based catalogs.
## New code should use KeyIconLibrary and VfxCatalog directly when possible.

# Catalogs (lazy-loaded)
var _key_icons: KeyIconLibrary
var _vfx_catalog: VfxCatalog
var _particle_catalog: ParticleCatalog
var _button_images: ButtonImageLibrary
var _sfx_catalog: SfxCatalog
var _scene_catalog: SceneCatalog


func get_key_icons() -> KeyIconLibrary:
	if not _key_icons:
		_key_icons = load("res://scenes/resources/key_icon_library.tres")
	return _key_icons


func get_vfx_catalog() -> VfxCatalog:
	if not _vfx_catalog:
		_vfx_catalog = load("res://scenes/resources/vfx_catalog.tres")
	return _vfx_catalog


func get_particle_catalog() -> ParticleCatalog:
	if not _particle_catalog:
		_particle_catalog = load("res://scenes/resources/particle_catalog.tres")
	return _particle_catalog


func get_button_images() -> ButtonImageLibrary:
	if not _button_images:
		_button_images = load("res://scenes/resources/button_image_library.tres")
	return _button_images


func get_sfx_catalog() -> SfxCatalog:
	if not _sfx_catalog:
		_sfx_catalog = load("res://scenes/resources/sfx_catalog.tres")
	return _sfx_catalog


func get_scene_catalog() -> SceneCatalog:
	if not _scene_catalog:
		_scene_catalog = load("res://scenes/resources/scene_catalog.tres")
	return _scene_catalog


func get_key_texture(key_type: String) -> Texture2D:
	return get_key_icons().get_texture(key_type)
