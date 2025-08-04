extends Level


@onready var global_music: AudioStreamPlayer = $GlobalMusic


func _ready():
	super._ready()
	#var destroyables = get_tree().get_nodes_in_group("destroyable")
	#for destroyable in destroyables:
		#if destroyable.name == 'BlinkWall':
			#destroyable.connect("tree_exited", Utils.play_sound.bind(Preloads.WALLCUT_SOUND, self, destroyable.position, -15))
			
	spawn_player()
	# open_all_doors()


func spawn_player():
	var player = Preloads.PLAYER_SCENE.instantiate() as Player
	players.add_child(player)
	# player.blocked_movement = true
	player.hud = hud
	#hud.show_black_screen()
	
	#respawn(player)
	test_respawn(player)
	player.debug_camera = %DebugCamera3D
	#hud.show_event_text("We heard a rumor about a mansion on the outskirts of town.")
	#await get_tree().create_timer(6.0).timeout
	#hud.show_event_text("They say there is a monster that lives there_")
	#await get_tree().create_timer(4.5).timeout
	#hud.hide_event_text()
	#player.blocked_movement = false
	#hud.fade_black_screen()


func respawn(p):
	p.position = player_spawners.get_children().pick_random().global_position
	p.current_room = "FirstFloor"
	p.rotate_y(3.15)
	Utils.play_sound(Preloads.SPAWN_SOUND, p)


func test_respawn(p):
	p.position = $NavigationRegion3D/TestSpawn.position
	p.current_room = "FirstFloor"
	Utils.play_sound(Preloads.SPAWN_SOUND, p)


func _on_ladder_body_entered(body):
	if body.is_in_group("player"):
		body.is_climbing = true


func _on_ladder_body_exited(body):
	if body.is_in_group("player"):
		body.is_climbing = false


func _handle_key_event(body, _key_type, event, _message_text):
	"""Handle mansion-specific key events"""
	match event:
		"spawn ao oni in library":
			var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
			enemies.add_child(aooni)
			aooni.current_room = "FirstFloor"
			aooni.position = $NavigationRegion3D/EventSpawners/FirstAoOniChase.position
			aooni.current_target = body
			aooni.add_disappear_zone($NavigationRegion3D/DisappearZones/LibraryExitArea)
			global_music.stream = Preloads.AOSEE_SOUND
			global_music.volume_db = -5
			global_music.play()
			hud.show_event_text("THE AO ONI! RUN!", false, 3.0)
			aooni.connect("tree_exited", _on_custom_event.bind("monster disappeared"))
			aooni.connect("tree_exited", global_music.stop)
		"ao oni tries to break bars":
			var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
			enemies.add_child(aooni)
			aooni.position = $NavigationRegion3D/EventSpawners/AoOniBars.position
			aooni.add_disappear_zone($NavigationRegion3D/DisappearZones/BarsAoOniRunAway)
			aooni.waypoints.push_back($NavigationRegion3D/EventSpawners/AoOniBarsBreak.position)
			aooni.waypoints.push_back($NavigationRegion3D/EventSpawners/AoOniBarsBreak2.position)
			aooni.connect("tree_exited", _on_custom_event.bind("ao oni gave up"))
			for player in players.get_children():
				player.blocked_movement = true
			aooni.makepath()
			$NavigationRegion3D/Cameras/BarsCamera2.set_current(true)
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
			aooni.waypoints.push_back($NavigationRegion3D/EventSpawners/AoOniBarsGiveup.position)
		"teleport to void":
			body.position = $NavigationRegion3D/PrankSpawners/VoidSpawn.position
		"spawn white face":
			var whiteface = Preloads.WHITEFACE_SCENE.instantiate()
			enemies.add_child(whiteface)
			whiteface.current_room = "BigHall"
			whiteface.position = $NavigationRegion3D/EventSpawners/WhiteFaceSpawn.position
			# $NavigationRegion3D/WorldEnvironment.queue_free()
			whiteface.current_target = body
		"": pass
		_:
			prints("unknown event: '", event, "'")


func _handle_button_event(body, event):
	match event:
		"check tv":
			hud.show_event_text("You: The television doesn't appear to turn on. It's probably broken.", false, 3.0)
		"check map":
			hud.show_event_text("You: The resort map of the Mansion. Nuff said...", false, 3.0)
		"play piano":
			var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
			enemies.add_child(aooni)
			aooni.position = $NavigationRegion3D/EventSpawners/AoOniPiano.position
			aooni.current_room = "PianoRoom"
			aooni.current_target = body
			aooni.add_disappear_zone($NavigationRegion3D/DisappearZones/PianoExitArea)
			hud.show_event_text("You: It's that monster! RUN!!!", false, 3.0)
			global_music.stream = Preloads.AOSEE_SOUND
			global_music.volume_db = -5
			global_music.play()
			aooni.connect("tree_exited", _on_custom_event.bind("monster disappeared"))
			aooni.connect("tree_exited", global_music.stop)
		"show moving bars":
			for player in players.get_children():
				player.blocked_movement = true
			global_music.stream = Preloads.EVENT_SOUND
			global_music.play()
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
			global_music.stream = Preloads.EVENT_SOUND
			global_music.play()
			await get_tree().create_timer(3.4).timeout
			for player in players.get_children():
				player.camera_3d.set_current(true)
				player.blocked_movement = false
			hud.show_event_text("You: I activated the switch. I better get out of here quickly!", false, 3.0)
		"": pass
		_:
			prints("unknown event: '", event, "'")


func _handle_area_event(body: CharacterBody3D, event):
	if event.strip_edges().is_empty(): return
	match event:
		"entered the mansion text":
			hud.show_event_text("You enter carefully into the mansion.", false, 3.0)
		"monster crawls in library":
			for player in players.get_children():
				player.blocked_movement = true
			var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
			enemies.add_child(aooni)
			aooni.add_disappear_zone($NavigationRegion3D/DisappearZones/CrawlingAoOniArea)
			aooni.position = $NavigationRegion3D/EventSpawners/AoOniCrawler.position
			aooni.waypoints.push_back($NavigationRegion3D/EventSpawners/AoOniCrawler2.position)
			aooni.waypoints.push_back($NavigationRegion3D/EventSpawners/AoOniCrawlerEnd.position)
			await get_tree().create_timer(4.5).timeout
			for player in players.get_children():
				player.camera_3d.set_current(true)
				player.blocked_movement = false
			hud.show_event_text("You: What the eff was that!?", false, 3.0)
			global_music.stream = Preloads.CREEP_AMB_SOUND
			global_music.volume_db = -5
			global_music.play()
		"piano alarm":
			if not $NavigationRegion3D/Buttons/PianoButton.is_pressed:
				var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
				enemies.add_child(aooni)
				aooni.position = $NavigationRegion3D/EventSpawners/AoOniPiano.position
				aooni.current_room = "PianoRoom"
				aooni.add_disappear_zone($NavigationRegion3D/DisappearZones/PianoExitArea)
				$NavigationRegion3D/Buttons/PianoButton.is_pressed = true
				hud.show_event_text("You: It's that monster! RUN!!!", false, 3.0)
				global_music.stream = Preloads.AOSEE_SOUND
				global_music.volume_db = -5
				global_music.play()
				aooni.connect("tree_exited", _on_custom_event.bind("monster disappeared"))
				aooni.connect("tree_exited", global_music.stop)
		"open ao oni behind wide door":
			# TODO: open wide door
			var wide_door = $Doors/AoWideDoor4
			wide_door.open()
			global_music.stream = Preloads.AOSEE_SOUND
			global_music.volume_db = -5
			global_music.play()
			hud.show_event_text("THE AO ONI! RUN!", false, 3.0)
			var ao_oni = get_node_or_null("NavigationRegion3D/Enemies/Ao oni")
			if ao_oni:
				ao_oni.connect("tree_exited", _on_custom_event.bind("monster disappeared"))
				ao_oni.connect("tree_exited", global_music.stop)
		"spawn ilopulu":
			global_music.stream = Preloads.EVENT_SOUND
			global_music.play()
			await get_tree().create_timer(1.0).timeout
			var ilopulu = Preloads.ILOPULU_SCENE.instantiate()
			enemies.add_child(ilopulu)
			ilopulu.position = $NavigationRegion3D/EventSpawners/IlopuluSpawn.position
			ilopulu.current_room = "BigHall"
			ilopulu.current_target = body
			ilopulu.add_disappear_zone($NavigationRegion3D/DisappearZones/ExitBigHallway)
		"open ao mika wardrobe":
			var wardrobe_door = $Doors/AoWardrobeDoor4
			wardrobe_door.open()
			global_music.stream = Preloads.AOSEE_SOUND
			global_music.volume_db = -5
			global_music.play()
			hud.show_event_text("You: WHAT THE?!?", false, 3.0)
			var aomika = get_node_or_null("NavigationRegion3D/Enemies/Ao mika")
			if aomika:
				aomika.connect("tree_exited", _on_custom_event.bind("aomika disappeared"))
				aomika.connect("tree_exited", global_music.stop)
		"underground secret info":
			hud.show_event_text("You need to find the switch, to open a hidden passage.", false, 3.0)
		"change to next map":
			print("change to next map")
		"kill player":
			if "kill" in body:
				body.kill()
		_:
			prints("unknown event: '", event, "'")


func _on_custom_event(event):
	match event:
		"monster disappeared":
			var random_text_idx = randi_range(0, 4)
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
			prints("unknown event: '", event, "'")


func _door_locked(text):
	hud.show_event_text(text, false, 3.0)


# For testing purposes
func open_all_doors():
	keys_collected = ['ruby', 'weird', 'brown', 'gold', 'emerald', 'silver']
	# Update the key display when keys are added programmatically
	refresh_key_display()
	var doors = get_tree().get_nodes_in_group("door")
	for door in doors:
		door.open()
