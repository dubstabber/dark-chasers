extends Node3D

var keys_collected: Array

@onready var transitions = $NavigationRegion3D/MansionAooni6_0_0Map01/Transitions
@onready var player_spawners = $NavigationRegion3D/MansionAooni6_0_0Map01/PlayerSpawners
@onready var players = $NavigationRegion3D/MansionAooni6_0_0Map01/Players
@onready var enemies = $NavigationRegion3D/MansionAooni6_0_0Map01/Enemies
@onready var playing_sounds = $NavigationRegion3D/MansionAooni6_0_0Map01/PlayingSounds
@onready var current_music = $NavigationRegion3D/MansionAooni6_0_0Map01/PlayingSounds/CurrentMusic


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
	#keys_collected = ['ruby', 'weird', 'brown', 'gold', 'emerald', 'silver']

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
	player.ambient_music.stream = Preloads.d_running_sound
	player.ambient_music.play()
	#respawn(player)
	test_respawn(player)


func respawn(p):
	p.position = player_spawners.get_children().pick_random().global_position
	p.current_room = "FirstFloor"
	p.rotate_y(3.15)


func test_respawn(p):
	p.position = $NavigationRegion3D/MansionAooni6_0_0Map01/TestSpawn.position
	p.current_room = "BigHall"


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
			var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
			enemies.add_child(aooni)
			aooni.current_room = "FirstFloor"
			aooni.position = $NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners/FirstAoOniChase.position
			aooni.current_target = body
			aooni.add_disappear_zone($NavigationRegion3D/MansionAooni6_0_0Map01/DisappearZones/LibraryExitArea)
			current_music.stream = Preloads.aosee_sound
			current_music.volume_db = -5
			current_music.play()
			aooni.connect("tree_exited", current_music.stop)
		"ao oni tries to break bars":
			var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
			enemies.add_child(aooni)
			aooni.position = $NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners/AoOniBars.position
			aooni.add_disappear_zone($NavigationRegion3D/MansionAooni6_0_0Map01/DisappearZones/BarsAoOniRunAway)
			aooni.waypoints.push_back($NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners/AoOniBarsBreak.position)
			aooni.connect("tree_exited", _on_custom_event.bind("ao oni gave up"))
			for player in players.get_children():
				player.blocked_movement = true
			$NavigationRegion3D/MansionAooni6_0_0Map01/Cameras/BarsCamera2.set_current(true)
			await get_tree().create_timer(5.0).timeout
			aooni.waypoints.push_back($NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners/AoOniBarsGiveup.position)
		"teleport to void":
			body.position = $NavigationRegion3D/MansionAooni6_0_0Map01/PrankSpawners/VoidSpawn.position
		"teleport to white face":
			body.position = $NavigationRegion3D/MansionAooni6_0_0Map01/PrankSpawners/SmallRoomSpawn.position
		"": pass
		_:
			prints("unknown event: '",event,"'")


func _handle_button_event(body, event):
	match event:
		"play piano":
			var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
			enemies.add_child(aooni)
			aooni.position = $NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners/AoOniPiano.position
			aooni.current_room = "PianoRoom"
			aooni.current_target = body
			aooni.add_disappear_zone($NavigationRegion3D/MansionAooni6_0_0Map01/DisappearZones/PianoExitArea)
			current_music.stream = Preloads.aosee_sound
			current_music.volume_db = -5
			current_music.play()
			aooni.connect("tree_exited", current_music.stop)
		"show moving bars":
			for player in players.get_children():
				player.blocked_movement = true
			await get_tree().create_timer(3.0).timeout
			for player in players.get_children():
				player.camera_3d.set_current(true)
				player.blocked_movement = false
		"show secret door":
			for player in players.get_children():
				player.blocked_movement = true
			await get_tree().create_timer(1.0).timeout
			for player in players.get_children():
				player.camera_3d.set_current(true)
				player.blocked_movement = false
		"show open exit":
			for player in players.get_children():
				player.blocked_movement = true
			await get_tree().create_timer(3.0).timeout
			for player in players.get_children():
				player.camera_3d.set_current(true)
				player.blocked_movement = false
		"": pass
		_:
			prints("unknown event: '",event,"'")


func _handle_area_event(body: CharacterBody3D, event):
	match event:
		"monster crawls in library":
			for player in players.get_children():
				player.blocked_movement = true
			var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
			enemies.add_child(aooni)
			aooni.add_disappear_zone($NavigationRegion3D/MansionAooni6_0_0Map01/DisappearZones/CrawlingAoOniArea)
			aooni.position = $NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners/AoOniCrawler.position
			aooni.waypoints.push_back($NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners/AoOniCrawlerEnd.position)
			await get_tree().create_timer(4.5).timeout
			for player in players.get_children():
				player.camera_3d.set_current(true)
				player.blocked_movement = false
			current_music.stream = Preloads.creep_amb_sound
			current_music.volume_db = -5
			current_music.play()
		"piano alarm":
			if not $NavigationRegion3D/MansionAooni6_0_0Map01/Buttons/PianoButton.is_pressed:
				var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
				enemies.add_child(aooni)
				aooni.position = $NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners/AoOniPiano.position
				aooni.current_room = "PianoRoom"
				aooni.add_disappear_zone($NavigationRegion3D/MansionAooni6_0_0Map01/DisappearZones/PianoExitArea)
				$NavigationRegion3D/MansionAooni6_0_0Map01/Buttons/PianoButton.is_pressed = true
				current_music.stream = Preloads.aosee_sound
				current_music.volume_db = -5
				current_music.play()
				aooni.connect("tree_exited", current_music.stop)
		"spawn ilopulu":
			print("spawn ilopulu")
		"invisible abyss":
			body.collision_mask = 10
			await get_tree().create_timer(0.8).timeout
			body.collision_mask = 14
		"change to next map":
			print("change to next map")
		"kill player":
			if "kill" in body:
				body.kill()
		"": pass
		_:
			prints("unknown event: '",event,"'")


func _on_custom_event(event):
	match event:
		"ao oni gave up":
			for player in players.get_children():
				player.camera_3d.set_current(true)
				player.blocked_movement = false
		"": pass
		_:
			prints("unknown event: '",event,"'")
