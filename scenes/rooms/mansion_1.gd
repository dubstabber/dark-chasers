extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")

var player_spawners: Array
var player
var enemies: Array
var void_spawn: Marker3D
var small_room_spawn: Marker3D
var keys_collected: Array

@onready var transitions = $NavigationRegion3D/MansionAooni6_0_0Map01/Transitions

@onready var bars_camera = $NavigationRegion3D/MansionAooni6_0_0Map01/Cameras/BarsCamera
@onready var exit_camera = $NavigationRegion3D/MansionAooni6_0_0Map01/Cameras/ExitCamera


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var keys = get_tree().get_nodes_in_group("key")
	for key in keys:
		key.connect("key_collected", _key_body_entered)
	var buttons = get_tree().get_nodes_in_group("button")
	for button in buttons:
		button.connect("button_pressed", _handle_button_event)
	player_spawners = get_tree().get_nodes_in_group("player_spawn")
	void_spawn = get_tree().get_first_node_in_group('void_spawn')
	small_room_spawn = get_tree().get_first_node_in_group('small_room_spawn')
	player = PLAYER_SCENE.instantiate() as CharacterBody3D
	add_child(player)
	var hud = HUD_SCENE.instantiate()
	add_child(hud)
	player.connect("mode_changed", hud._on_player_mode_changed)
	player.current_room = "FirstFloor"
	respawn(player)
	enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		enemy.camera = get_viewport().get_camera_3d()
		enemy.targets.append(player)

	for t in transitions.get_children():
		for m in t.get_children():
			if m.is_in_group("spawn_point"):
				t.connect("body_entered", handle_transition.bind(t.name, m))
			if m.is_in_group("manual_spawn_point"):
				t.connect("body_entered", _on_transition_entered.bind(m))
				t.connect("body_exited", _on_transition_exited)


func _physics_process(_delta):
	if Input.is_action_just_pressed("menu"):
		get_tree().quit()
	if Input.is_action_just_pressed("toggle-window-mode"):
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func respawn(p):
	p.position = player_spawners.pick_random().global_position
	p.rotate_y(3.15)


func handle_transition(body, area3dname, marker):
	body.current_room = transitions.map_transitions[body.current_room][area3dname]
	body.position = marker.global_position
	if "find_path_timer" in body:
		body.find_path_timer.wait_time = 0.1
		body.find_path_timer.start()


func _on_transition_entered(body, transitor):
	if body.is_in_group("player") and transitor:
		if "transit_pos" in body:
			body.transit_pos = transitor


func _on_transition_exited(body):
	if body.is_in_group("player"):
		if "transit_pos" in body:
			body.transit_pos = null


func _on_ladder_body_entered(body):
	if body.is_in_group("player"):
		body.is_climbing = true


func _on_ladder_body_exited(body):
	if body.is_in_group("player"):
		body.is_climbing = false


func _key_body_entered(body, key_type, event):
	if key_type and key_type not in keys_collected:
		keys_collected.push_back(key_type)
	match event:
		"spawn ao oni":
			print('spawn ao oni')
		"ao oni tries to break bars":
			print('ao oni tries to break bars')
		"teleport to void":
			body.position = void_spawn.position
		"teleport to white face":
			body.position = small_room_spawn.position


func _handle_button_event(body, event):
	match event:
		"show moving bars":
			body.blocked_movement = true
			bars_camera.set_current(true)
			await get_tree().create_timer(3.0).timeout
			body.camera_3d.set_current(true)
			body.blocked_movement = false
		"show open exit":
			body.blocked_movement = true
			exit_camera.set_current(true)
			await get_tree().create_timer(3.0).timeout
			body.camera_3d.set_current(true)
			body.blocked_movement = false

