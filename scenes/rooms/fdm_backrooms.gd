extends Level

const EnemySpawnerControllerScript = preload("res://scenes/components/enemy/enemy_spawner_controller.gd")

enum GAME_MODE {
	NONE,
	STANDARD
}

var current_game_mode: int
var _spawner_controller: EnemySpawnerController = null

@onready var spawn_barriers = $Map/FDG46_039
@onready var enemy_spawners_container = get_node_or_null("%EnemySpawners")


func _ready():
	super._ready()
	
	current_game_mode = GAME_MODE.STANDARD
	spawn_player()
	_setup_spawner_controller()


func spawn_player():
	var player = Services.preloads.PLAYER_SCENE.instantiate() as Player
	players.add_child(player)
	setup_player(player)
	respawn(player)


func respawn(p):
	p.position = player_spawners.get_children().pick_random().global_position


func _setup_spawner_controller() -> void:
	if current_game_mode != GAME_MODE.STANDARD:
		return
	if not enemy_spawners_container or enemy_spawners_container.get_child_count() == 0:
		return
	
	_spawner_controller = EnemySpawnerControllerScript.new()
	_spawner_controller.enemy_scene = Services.preloads.IMAGE_ENEMY_SCENE
	_spawner_controller.min_respawn_time = 10.0
	_spawner_controller.max_respawn_time = 30.0
	_spawner_controller.delay_between_spawners = 1.0
	_spawner_controller.is_wandering = true
	_spawner_controller.auto_start = true
	add_child(_spawner_controller)
	_spawner_controller.initialize(enemy_spawners_container, enemies)


func _on_disable_barriers_timeout() -> void:
	spawn_barriers.hide()
	spawn_barriers.get_child(0).collision_layer = 0
