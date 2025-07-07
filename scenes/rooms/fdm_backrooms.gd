extends Level

enum GAME_MODE {
	NONE,
	STANDARD
}

var min_respawn_time := 1 * 10
var max_respawn_time := 1 * 30
var enemy_spawners: Array
var current_spawner := 0
var current_game_mode: int

@onready var delay_between_spawners = $Timers/DelayBetweenSpawners
@onready var spawn_barriers = $Map/FDG46_039


func _ready():
	super._ready()
	
	current_game_mode = GAME_MODE.STANDARD
	spawn_player()
	enemy_spawners = get_tree().get_nodes_in_group("enemy_spawn")
	if enemy_spawners.size() > 0 and current_game_mode == GAME_MODE.STANDARD:
		spawn_enemy(0)


func spawn_player():
	var player = Preloads.PLAYER_SCENE.instantiate() as Player
	players.add_child(player)
	player.hud = hud
	respawn(player)


func respawn(p):
	p.position = player_spawners.get_children().pick_random().global_position


func spawn_enemy(index):
	var enemy = Preloads.IMAGE_ENEMY_SCENE.instantiate()
	enemies.add_child(enemy)
	enemy.position = enemy_spawners[index].position
	enemy.is_wandering = true
	var spawner_timer = Timer.new()
	enemy_spawners[index].add_child(spawner_timer)
	spawner_timer.connect("timeout", respawn_enemy.bind(index, spawner_timer))
	spawner_timer.wait_time = randf_range(min_respawn_time,max_respawn_time)
	spawner_timer.one_shot = true
	spawner_timer.start()
	current_spawner += 1
	delay_between_spawners.start()

func respawn_enemy(index, spawner_timer):
	var enemy = Preloads.IMAGE_ENEMY_SCENE.instantiate()
	enemies.add_child(enemy)
	enemy.position = enemy_spawners[index].position
	spawner_timer.wait_time = randf_range(min_respawn_time,max_respawn_time)
	spawner_timer.start()


func _on_delay_between_spawners_timeout():
	if current_spawner != enemy_spawners.size():
		spawn_enemy(current_spawner)


func _on_disable_barriers_timeout() -> void:
	spawn_barriers.hide()
	spawn_barriers.get_child(0).collision_layer = 0
	
