extends Node

const BitmapFontCatalogScript = preload("res://scenes/resources/bitmap_font_catalog.gd")


## Single entry-point for all game services.
## Replaces individual autoloads with a centralized service registry.
##
## Access pattern: Services.event_bus, Services.camera_manager, etc.
##
## Ownership boundaries (who may call what):
##   enemy_db        — read by: enemies, level scripts
##   utils           — read by: any gameplay code (audio helper)
##   enemy_context   — read by: enemy components | written by: Level
##   world_context   — read by: HUD, gameplay systems | written by: Level
##   camera_manager  — read by: player input, level scripts, button/area events
##   audio_pool      — read by: Utils (internal delegation)
##   vfx_pool        — read by: weapon hit executor, VFX spawners
##   event_bus       — read/write by: emitters + subscribers (Level, interactables, sequences)
##   sequence_director — read by: level scripts (play sequences)
##   input_router    — standalone (app-level input); no external callers expected
##   level_manager   — read by: scene transition initiators (teleports, map events)

var enemy_db: EnemyDb
var utils: Utils
var enemy_context: EnemyContext
var world_context: WorldContext
var camera_manager: CameraManager
var audio_pool: AudioPoolService
var vfx_pool: VfxPoolService
var event_bus: GameEventBus
var sequence_director: SequenceDirector
var input_router: InputRouter
var level_manager: Node
var ammo_config: AmmoConfig

var _key_icons: KeyIconLibrary
var _vfx_catalog: VfxCatalog
var _particle_catalog: ParticleCatalog
var _button_images: ButtonImageLibrary
var _sfx_catalog: SfxCatalog
var _scene_catalog: SceneCatalog
var _bitmap_font_catalog: BitmapFontCatalogScript


func _enter_tree() -> void:
	enemy_db = _add_service("EnemyDb", preload("res://scenes/globals/enemy_db.gd"))
	utils = _add_service("Utils", preload("res://scenes/globals/utils.gd"))
	enemy_context = _add_service("EnemyContext", preload("res://scenes/services/enemy_context.gd"))
	world_context = _add_service("WorldContext", preload("res://scenes/services/world_context.gd"))
	camera_manager = _add_service("CameraManager", preload("res://scenes/services/camera_manager.gd"))
	audio_pool = _add_service("AudioPoolService", preload("res://scenes/services/audio_pool_service.gd"))
	vfx_pool = _add_service("VfxPoolService", preload("res://scenes/services/vfx_pool_service.gd"))
	event_bus = _add_service("GameEventBus", preload("res://scenes/services/game_event_bus.gd"))
	sequence_director = _add_service("SequenceDirector", preload("res://scenes/services/sequence_director.gd"))
	input_router = _add_service("InputRouter", preload("res://scenes/services/input_router.gd"))
	level_manager = _add_service("LevelManager", preload("res://scenes/services/level_manager.gd"))
	ammo_config = _add_service("AmmoConfig", preload("res://scenes/systems/ammo_system/ammo_config.gd"))


func _add_service(service_name: String, script: GDScript) -> Node:
	var service_instance: Variant = script.new()
	assert(service_instance is Node, "Services._add_service('%s') requires a script that extends Node" % service_name)
	var node := service_instance as Node
	node.name = service_name
	add_child(node)
	return node


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


func get_bitmap_font_catalog() -> BitmapFontCatalogScript:
	if not _bitmap_font_catalog:
		_bitmap_font_catalog = load("res://scenes/resources/bitmap_font_catalog.tres")
	return _bitmap_font_catalog
