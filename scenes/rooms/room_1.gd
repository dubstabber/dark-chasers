extends Node3D

var player_spawners: Array
var playerScene := preload("res://scenes/player.tscn")
var hudScene := preload("res://scenes/hud.tscn")


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	player_spawners = get_tree().get_nodes_in_group("player_spawn")
	var player = playerScene.instantiate() as CharacterBody3D
	add_child(player)
	var hud = hudScene.instantiate()
	add_child(hud)
	player.connect("mode_changed", hud._on_player_mode_changed)
	respawn(player)


func respawn(player):
	player.position = player_spawners[0].global_position


func _process(_delta):
	if Input.is_action_just_pressed("menu"):
		get_tree().quit()
	if Input.is_action_just_pressed("toggle-window-mode"):
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
