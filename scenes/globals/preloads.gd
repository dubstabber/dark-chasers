extends Node

## Preloads autoload - compatibility adapter over Resource-based catalogs.
## New code should use KeyIconLibrary and VfxCatalog directly when possible.

# Catalogs (lazy-loaded)
var _key_icons: KeyIconLibrary
var _vfx_catalog: VfxCatalog
var _particle_catalog: ParticleCatalog
var _button_images: ButtonImageLibrary

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")

const IMAGE_ENEMY_SCENE := preload("res://scenes/enemies/image_enemy.tscn")
const AOONI_SCENE := preload("res://scenes/enemies/ao_oni.tscn")
const ILOPULU_SCENE := preload("res://scenes/enemies/ilopulu.tscn")
const WHITEFACE_SCENE := preload("res://scenes/enemies/white_face.tscn")


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


func get_key_texture(key_type: String) -> Texture2D:
	return get_key_icons().get_texture(key_type)

const KEY_COLLECTED_SOUND := preload("res://sounds/sfx/DSKEYPIC.wav")

const KILL_PLAYER_SOUND := preload("res://sounds/sfx/DSSLOP.wav")

const CREEP_AMB_SOUND := preload("res://sounds/music/CREEPAMB.wav")
const AOSEE_SOUND := preload("res://sounds/music/AOSEE.wav")
const D_RUNNING_SOUND := preload("res://sounds/music/D_RUNNIN.ogg")
const BAR_SHAKE_SOUND := preload("res://sounds/sfx/BARSHAKE.ogg")
const SPAWN_SOUND := preload("res://sounds/sfx/DSTELEPT.ogg")
const EVENT_SOUND := preload("res://sounds/sfx/CREVENT.wav")
const WALLCUT_SOUND := preload("res://sounds/sfx/WALLCUT.wav")
# Break sounds and SCRAP_SCENE migrated to ParticleCatalog - use get_particle_catalog()
# Button images migrated to ButtonImageLibrary - use get_button_images()

const WATER_SPLASH_SOUND := preload("res://sounds/sfx/footsteps/water/DSSPLSML.wav")

const AO_RED_BLOOD_PARTICLE := preload("res://scenes/particles/ao_red_blood_particle.tscn")
const AO_BLUE_BLOOD_PARTICLE := preload("res://scenes/particles/ao_blue_blood_particle.tscn")
const BLOOD_SPLAT_DECAL := preload("res://scenes/particles/blood_splat_decal.tscn")
