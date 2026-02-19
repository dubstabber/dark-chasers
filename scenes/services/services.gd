extends Node


## Single entry-point for all game services.
## Replaces individual autoloads with a centralized service registry.
##
## Access pattern: Services.event_bus, Services.camera_manager, etc.
##
## Ownership boundaries (who may call what):
##   enemy_db        — read by: enemies, level scripts
##   utils           — read by: any gameplay code (audio helper)
##   preloads        — read by: any gameplay code (deprecated → use typed catalogs)
##   enemy_context   — read by: enemy components | written by: Level
##   world_context   — read by: HUD, gameplay systems | written by: Level
##   camera_manager  — read by: player input, level scripts, button/area events
##   audio_pool      — read by: Utils (internal delegation)
##   vfx_pool        — read by: weapon hit executor, VFX spawners
##   event_bus       — read/write by: emitters + subscribers (Level, interactables, sequences)
##   sequence_director — read by: level scripts (play sequences)
##   input_router    — standalone (app-level input); no external callers expected

var enemy_db: EnemyDb
var utils: Utils
var preloads: Preloads
var enemy_context: EnemyContext
var world_context: WorldContext
var camera_manager: CameraManager
var audio_pool: AudioPoolService
var vfx_pool: VfxPoolService
var event_bus: GameEventBus
var sequence_director: SequenceDirector
var input_router: InputRouter
var ammo_config: AmmoConfig


func _enter_tree() -> void:
	enemy_db = _add_service("EnemyDb", preload("res://scenes/globals/enemy_db.gd"))
	utils = _add_service("Utils", preload("res://scenes/globals/utils.gd"))
	preloads = _add_service("Preloads", preload("res://scenes/globals/preloads.gd"))
	enemy_context = _add_service("EnemyContext", preload("res://scenes/services/enemy_context.gd"))
	world_context = _add_service("WorldContext", preload("res://scenes/services/world_context.gd"))
	camera_manager = _add_service("CameraManager", preload("res://scenes/services/camera_manager.gd"))
	audio_pool = _add_service("AudioPoolService", preload("res://scenes/services/audio_pool_service.gd"))
	vfx_pool = _add_service("VfxPoolService", preload("res://scenes/services/vfx_pool_service.gd"))
	event_bus = _add_service("GameEventBus", preload("res://scenes/services/game_event_bus.gd"))
	sequence_director = _add_service("SequenceDirector", preload("res://scenes/services/sequence_director.gd"))
	input_router = _add_service("InputRouter", preload("res://scenes/services/input_router.gd"))
	ammo_config = _add_service("AmmoConfig", preload("res://scenes/systems/ammo_system/ammo_config.gd"))


func _add_service(service_name: String, script: GDScript) -> Node:
	var node := Node.new()
	node.name = service_name
	node.set_script(script)
	add_child(node)
	return node
