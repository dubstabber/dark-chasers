extends Node3D

enum GAME_MODE {
	NONE,
	STANDARD
}

var min_respawn_time := 1 * 10
var max_respawn_time := 1 * 30
var enemy_spawners: Array
var current_spawner := 0
var current_game_mode: int

@onready var delay_between_spawners = $NavigationRegion3D/Fdmmaps0_31Fdg46/Timers/DelayBetweenSpawners
@onready var player_spawners = $NavigationRegion3D/Fdmmaps0_31Fdg46/PlayerSpawners
@onready var players = $NavigationRegion3D/Fdmmaps0_31Fdg46/Players
@onready var enemies = $NavigationRegion3D/Fdmmaps0_31Fdg46/Enemies


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	current_game_mode = GAME_MODE.STANDARD
	spawn_player()
	enemy_spawners = get_tree().get_nodes_in_group("enemy_spawn")
	if enemy_spawners.size() > 0 and current_game_mode == GAME_MODE.STANDARD:
		spawn_enemy(0)


func _process(_delta):
	if Input.is_action_just_pressed("menu"):
		get_tree().quit()
	if Input.is_action_just_pressed("toggle-window-mode"):
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func spawn_player():
	var player = Preloads.PLAYER_SCENE.instantiate() as CharacterBody3D
	players.add_child(player)
	var hud = Preloads.HUD_SCENE.instantiate()
	player.add_child(hud)
	player.connect("mode_changed", hud._on_player_mode_changed)
	player.ambient_music.stream = Preloads.d_running_sound
	player.ambient_music.play()
	respawn(player)


func respawn(p):
	p.position = player_spawners.get_children().pick_random().global_position


func spawn_enemy(index):
	var enemy = Preloads.IMAGE_ENEMY_SCENE.instantiate()
	enemies.add_child(enemy)
	enemy.position = enemy_spawners[index].position
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
