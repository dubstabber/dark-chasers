extends Node3D

var hud
var keys_collected: Array

@onready var transitions = $NavigationRegion3D/MansionAooni6_0_0Map01/Transitions
@onready var player_spawners = $NavigationRegion3D/MansionAooni6_0_0Map01/PlayerSpawners
@onready var players = $NavigationRegion3D/MansionAooni6_0_0Map01/Players
@onready var enemies = $NavigationRegion3D/MansionAooni6_0_0Map01/Enemies
@onready var playing_sounds = $NavigationRegion3D/MansionAooni6_0_0Map01/PlayingSounds
@onready var global_music = $NavigationRegion3D/MansionAooni6_0_0Map01/PlayingSounds/GlobalMusic
@onready var global_sound = $NavigationRegion3D/MansionAooni6_0_0Map01/PlayingSounds/GlobalSound


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	var doors = get_tree().get_nodes_in_group("door")
	for door in doors:
		if "door_locked" in door: door.connect("door_locked", _door_locked)
	var keys = get_tree().get_nodes_in_group("key")
	for key in keys:
		key.connect("key_collected", _key_body_entered)
	var buttons = get_tree().get_nodes_in_group("button")
	for button in buttons:
		button.connect("button_pressed", _handle_button_event)
	var area_events = get_tree().get_nodes_in_group("area_event")
	for area_event in area_events:
		area_event.connect("event_triggered", _handle_area_event)
	var destroyables = get_tree().get_nodes_in_group("destroyable")
	for destroyable in destroyables:
		if destroyable.name == 'BlinkWall':
			destroyable.connect("tree_exited", Utils.play_sound.bind(Preloads.WALLCUT_SOUND, self, destroyable.position, -15))
	
	
	spawn_player()
	#open_all_doors()

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
	var player = Preloads.PLAYER_SCENE.instantiate() as Player
	players.add_child(player)
	player.blocked_movement = true
	hud = Preloads.HUD_SCENE.instantiate()
	add_child(hud)
	player.hud = hud
	hud.show_black_screen()
	player.ambient_music.stream = Preloads.D_RUNNING_SOUND
	player.ambient_music.play()
	#respawn(player)
	test_respawn(player)
	hud.show_event_text("We heard a rumor about a mansion on the outskirts of town.")
	await get_tree().create_timer(6.0).timeout
	hud.show_event_text("They say there is a monster that lives there_")
	await get_tree().create_timer(4.5).timeout
	hud.hide_event_text()
	player.blocked_movement = false
	hud.fade_black_screen()


func respawn(p):
	p.position = player_spawners.get_children().pick_random().global_position
	p.current_room = "FirstFloor"
	p.rotate_y(3.15)
	Utils.play_sound(Preloads.SPAWN_SOUND, p)


func test_respawn(p):
	p.position = $NavigationRegion3D/MansionAooni6_0_0Map01/TestSpawn.position
	p.current_room = "FirstFloor"
	Utils.play_sound(Preloads.SPAWN_SOUND, p)


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


func _key_body_entered(body, key_type, event, message_text):
	hud.add_log(message_text)
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
			global_music.stream = Preloads.AOSEE_SOUND
			global_music.volume_db = -5
			global_music.play()
			hud.show_event_text("THE AO ONI! RUN!", false, 3.0)
			aooni.connect("tree_exited", _on_custom_event.bind("monster disappeared"))
			aooni.connect("tree_exited", global_music.stop)
		"ao oni tries to break bars":
			var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
			enemies.add_child(aooni)
			aooni.position = $NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners/AoOniBars.position
			aooni.add_disappear_zone($NavigationRegion3D/MansionAooni6_0_0Map01/DisappearZones/BarsAoOniRunAway)
			aooni.waypoints.push_back($NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners/AoOniBarsBreak.position)
			aooni.connect("tree_exited", _on_custom_event.bind("ao oni gave up"))
			for player in players.get_children():
				player.blocked_movement = true
			aooni.makepath()
			$NavigationRegion3D/MansionAooni6_0_0Map01/Cameras/BarsCamera2.set_current(true)
			await get_tree().create_timer(3.0).timeout
			Utils.play_sound(Preloads.BAR_SHAKE_SOUND, aooni)
			await get_tree().create_timer(0.6).timeout
			Utils.play_sound(Preloads.BAR_SHAKE_SOUND, aooni)
			await get_tree().create_timer(0.25).timeout
			Utils.play_sound(Preloads.BAR_SHAKE_SOUND, aooni)
			await get_tree().create_timer(0.25).timeout
			Utils.play_sound(Preloads.BAR_SHAKE_SOUND, aooni)
			await get_tree().create_timer(0.5).timeout
			Utils.play_sound(Preloads.BAR_SHAKE_SOUND, aooni)
			await get_tree().create_timer(2.5).timeout
			aooni.waypoints.push_back($NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners/AoOniBarsGiveup.position)
		"teleport to void":
			body.position = $NavigationRegion3D/MansionAooni6_0_0Map01/PrankSpawners/VoidSpawn.position
		"spawn white face":
			var whiteface = Preloads.WHITEFACE_SCENE.instantiate()
			enemies.add_child(whiteface)
			whiteface.current_room = "BigHall"
			whiteface.position = $NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners/WhiteFaceSpawn.position
			whiteface.current_target = body
		"": pass
		_:
			prints("unknown event: '",event,"'")


func _handle_button_event(body, event):
	match event:
		"check tv":
			hud.show_event_text("You: The television doesn't appear to turn on. It's probably broken.", false, 3.0)
		"check map":
			hud.show_event_text("You: The resort map of the Mansion. Nuff said...", false, 3.0)
		"play piano":
			var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
			enemies.add_child(aooni)
			aooni.position = $NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners/AoOniPiano.position
			aooni.current_room = "PianoRoom"
			aooni.current_target = body
			aooni.add_disappear_zone($NavigationRegion3D/MansionAooni6_0_0Map01/DisappearZones/PianoExitArea)
			hud.show_event_text("You: It's that monster! RUN!!!", false, 3.0)
			global_music.stream = Preloads.AOSEE_SOUND
			global_music.volume_db = -5
			global_music.play()
			aooni.connect("tree_exited", _on_custom_event.bind("monster disappeared"))
			aooni.connect("tree_exited", global_music.stop)
		"show moving bars":
			for player in players.get_children():
				player.blocked_movement = true
			global_sound.stream = Preloads.EVENT_SOUND
			global_sound.play()
			await get_tree().create_timer(3.4).timeout
			for player in players.get_children():
				player.camera_3d.set_current(true)
				player.blocked_movement = false
			hud.show_event_text("You: I should head to the 1st floor and check that out...", false, 3.0)
		"show secret door":
			for player in players.get_children():
				player.blocked_movement = true
			await get_tree().create_timer(1.0).timeout
			for player in players.get_children():
				player.camera_3d.set_current(true)
				player.blocked_movement = false
			hud.show_event_text("You: Hmm... I wonder where that passage leads to?", false, 3.0)
		"check map 2":
			hud.show_event_text("You: This map says that there's a hidden passage nearby.", false, 3.0)
		"show open exit":
			for player in players.get_children():
				player.blocked_movement = true
			global_sound.stream = Preloads.EVENT_SOUND
			global_sound.play()
			await get_tree().create_timer(3.4).timeout
			for player in players.get_children():
				player.camera_3d.set_current(true)
				player.blocked_movement = false
			hud.show_event_text("You: I activated the switch. I better get out of here quickly!", false, 3.0)
		"": pass
		_:
			prints("unknown event: '",event,"'")


func _handle_area_event(body: CharacterBody3D, event):
	match event:
		"entered the mansion text":
			hud.show_event_text("You enter carefully into the mansion.", false, 3.0)
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
			hud.show_event_text("You: What the eff was that!?", false, 3.0)
			global_music.stream = Preloads.CREEP_AMB_SOUND
			global_music.volume_db = -5
			global_music.play()
		"piano alarm":
			if not $NavigationRegion3D/MansionAooni6_0_0Map01/Buttons/PianoButton.is_pressed:
				var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
				enemies.add_child(aooni)
				aooni.position = $NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners/AoOniPiano.position
				aooni.current_room = "PianoRoom"
				aooni.add_disappear_zone($NavigationRegion3D/MansionAooni6_0_0Map01/DisappearZones/PianoExitArea)
				$NavigationRegion3D/MansionAooni6_0_0Map01/Buttons/PianoButton.is_pressed = true
				hud.show_event_text("You: It's that monster! RUN!!!", false, 3.0)
				global_music.stream = Preloads.AOSEE_SOUND
				global_music.volume_db = -5
				global_music.play()
				aooni.connect("tree_exited", _on_custom_event.bind("monster disappeared"))
				aooni.connect("tree_exited", global_music.stop)
		"open ao oni behind wide door":
			global_music.stream = Preloads.AOSEE_SOUND
			global_music.volume_db = -5
			global_music.play()
			hud.show_event_text("THE AO ONI! RUN!", false, 3.0)
			$"NavigationRegion3D/MansionAooni6_0_0Map01/Enemies/Ao oni".connect("tree_exited", _on_custom_event.bind("monster disappeared"))
			$"NavigationRegion3D/MansionAooni6_0_0Map01/Enemies/Ao oni".connect("tree_exited", global_music.stop)
		"spawn ilopulu":
			global_sound.stream = Preloads.EVENT_SOUND
			global_sound.play()
			await get_tree().create_timer(1.0).timeout
			var ilopulu = Preloads.ILOPULU_SCENE.instantiate()
			enemies.add_child(ilopulu)
			ilopulu.position = $NavigationRegion3D/MansionAooni6_0_0Map01/EventSpawners/IlopuluSpawn.position
			ilopulu.current_room = "BigHall"
			ilopulu.current_target = body
			ilopulu.add_disappear_zone($NavigationRegion3D/MansionAooni6_0_0Map01/DisappearZones/ExitBigHallway)
		"invisible abyss":
			body.collision_mask = 10
			await get_tree().create_timer(0.8).timeout
			body.collision_mask = 14
		"open ao mika wardrobe":
			global_music.stream = Preloads.AOSEE_SOUND
			global_music.volume_db = -5
			global_music.play()
			hud.show_event_text("You: WHAT THE?!?", false, 3.0)
			$"NavigationRegion3D/MansionAooni6_0_0Map01/Enemies/Ao mika".connect("tree_exited", _on_custom_event.bind("aomika disappeared"))
			$"NavigationRegion3D/MansionAooni6_0_0Map01/Enemies/Ao mika".connect("tree_exited", global_music.stop)
		"underground secret info":
			hud.show_event_text("You need to find the switch, to open a hidden passage.", false, 3.0)
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
		"monster disappeared":
			var random_text_idx = randi_range(0,4)
			match random_text_idx:
				0:
					hud.show_event_text("You: I think he dissapeared..", false, 3.0)
				1:
					hud.show_event_text("You: I have the feeling it's gone...", false, 3.0)
				2:
					hud.show_event_text("You: Phew, that was close...", false, 3.0)
				3:
					hud.show_event_text("You: I think he's away.", false, 3.0)
				4:
					hud.show_event_text("You: I think that thing is gone...", false, 3.0)
		"ao oni gave up":
			for player in players.get_children():
				player.camera_3d.set_current(true)
				player.blocked_movement = false
		"aomika disappeared":
			hud.show_event_text("You: Whatever that THING was... it's gone...", false, 3.0)
		"": pass
		_:
			prints("unknown event: '",event,"'")


func _door_locked(text):
	hud.show_event_text(text, false, 3.0)


# For testing purposes
func open_all_doors():
	keys_collected = ['ruby', 'weird', 'brown', 'gold', 'emerald', 'silver']
	var doors = get_tree().get_nodes_in_group("door")
	for door in doors:
		door.open()

