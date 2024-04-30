class_name Level extends Node3D

@onready var hud = $HUD
@onready var transitions = get_node_or_null("%Transitions")
@onready var player_spawners = get_node_or_null("%PlayerSpawners")
@onready var players = get_node_or_null("%Players")
@onready var enemies = get_node_or_null("%Enemies")
@onready var global_music = get_node_or_null("%GlobalMusic")
@onready var global_sound = get_node_or_null("%GlobalSound")


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	

func _physics_process(_delta):
	if Input.is_action_just_pressed("menu"):
		get_tree().quit()
	if Input.is_action_just_pressed("toggle-window-mode"):
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
