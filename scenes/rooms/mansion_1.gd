extends Node3D

var keys_collected: Array

@onready var transitions = $NavigationRegion3D/MansionAooni6_0_0Map01/Transitions
@onready var player_spawners = $NavigationRegion3D/MansionAooni6_0_0Map01/PlayerSpawners
@onready var event_spawners = $NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners
@onready var prank_spawners = $NavigationRegion3D/MansionAooni6_0_0Map01/PrankSpawners
@onready var players = $NavigationRegion3D/MansionAooni6_0_0Map01/Players
@onready var enemies = $NavigationRegion3D/MansionAooni6_0_0Map01/Enemies


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var keys = get_tree().get_nodes_in_group("key")
	for key in keys:
		key.connect("key_collected", _key_body_entered)
	var buttons = get_tree().get_nodes_in_group("button")
	for button in buttons:
		button.connect("button_pressed", _handle_button_event)
	var area_events = get_tree().get_nodes_in_group("area_event")
	for area_event in area_events:
		area_event.connect("event_triggered", _handle_area_event)
	
	spawn_player()
	keys_collected = ['ruby', 'weird', 'brown', 'gold', 'emerald', 'silver']

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


func spawn_player():
	var player = Preloads.PLAYER_SCENE.instantiate() as CharacterBody3D
	players.add_child(player)
	var hud = Preloads.HUD_SCENE.instantiate()
	player.add_child(hud)
	player.connect("mode_changed", hud._on_player_mode_changed)
	respawn(player)


func respawn(p):
	p.position = player_spawners.get_children().pick_random().global_position
	p.current_room = "FirstFloor"
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
		"spawn ao oni in library":
			print('spawn ao oni in library')
		"ao oni tries to break bars":
			print('ao oni tries to break bars')
		"teleport to void":
			for spawner in prank_spawners.get_children():
				if spawner.name == 'VoidSpawn':
					body.position = spawner.position
		"teleport to white face":
			for spawner in prank_spawners.get_children():
				if spawner.name == 'SmallRoomSpawn':
					body.position = spawner.position


func _handle_button_event(_body, event):
	match event:
		"show moving bars":
			for player in players.get_children():
				player.blocked_movement = true
				await get_tree().create_timer(3.0).timeout
				player.camera_3d.set_current(true)
				player.blocked_movement = false
		"show open exit":
			for player in players.get_children():
				player.blocked_movement = true
				await get_tree().create_timer(3.0).timeout
				player.camera_3d.set_current(true)
				player.blocked_movement = false


func _handle_area_event(event):
	match event:
		"monster crawls in library":
			var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
			enemies.add_child(aooni)
			for spawner in event_spawners.get_children():
					if spawner.name == 'AoOniCrawler':
						aooni.position = spawner.position
						aooni.current_room = "FirstFloor"
					if spawner.name == 'AoOniCrawlerEnd':
						
						pass
			for player in players.get_children():
				player.blocked_movement = true
				await get_tree().create_timer(4.5).timeout
				player.camera_3d.set_current(true)
				player.blocked_movement = false

