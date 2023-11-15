extends Node3D

var player_spawners: Array
var playerScene := preload("res://scenes/player.tscn")


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	player_spawners = get_tree().get_nodes_in_group('player_spawn')
	respawn()

func respawn():
	var player = playerScene.instantiate() as CharacterBody3D
	add_child(player)
	player.position = player_spawners[0].global_position

func _process(_delta):
	if Input.is_action_just_pressed("menu"):
		get_tree().quit()
	if Input.is_action_just_pressed('toggle-window-mode'):
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
