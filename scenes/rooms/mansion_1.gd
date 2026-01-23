extends Level

const GE = preload("res://scenes/resources/game_event_types.gd")

# Mapping from legacy string event names to typed event IDs
const KEY_EVENT_MAP := {
	"spawn ao oni in library": GE.KEY_SPAWN_AO_ONI_LIBRARY,
	"ao oni tries to break bars": GE.KEY_AO_ONI_TRIES_BARS,
	"teleport to void": GE.KEY_TELEPORT_TO_VOID,
	"spawn white face": GE.KEY_SPAWN_WHITE_FACE,
}

const BUTTON_EVENT_MAP := {
	"check tv": GE.BUTTON_CHECK_TV,
	"check map": GE.BUTTON_CHECK_MAP,
	"check map 2": GE.BUTTON_CHECK_MAP_2,
	"play piano": GE.BUTTON_PLAY_PIANO,
	"show moving bars": GE.BUTTON_SHOW_MOVING_BARS,
	"show secret door": GE.BUTTON_SHOW_SECRET_DOOR,
	"show open exit": GE.BUTTON_SHOW_OPEN_EXIT,
}

const AREA_EVENT_MAP := {
	"entered the mansion text": GE.AREA_ENTERED_MANSION_TEXT,
	"monster crawls in library": GE.AREA_MONSTER_CRAWLS_LIBRARY,
	"piano alarm": GE.AREA_PIANO_ALARM,
	"open ao oni behind wide door": GE.AREA_OPEN_AO_ONI_WIDE_DOOR,
	"spawn ilopulu": GE.AREA_SPAWN_ILOPULU,
	"open ao mika wardrobe": GE.AREA_OPEN_AO_MIKA_WARDROBE,
	"underground secret info": GE.AREA_UNDERGROUND_SECRET_INFO,
	"change to next map": GE.AREA_CHANGE_TO_NEXT_MAP,
	"kill player": GE.AREA_KILL_PLAYER,
}

const CUSTOM_EVENT_MAP := {
	"monster disappeared": GE.CUSTOM_MONSTER_DISAPPEARED,
	"ao oni gave up": GE.CUSTOM_AO_ONI_GAVE_UP,
	"aomika disappeared": GE.CUSTOM_AOMIKA_DISAPPEARED,
}

@onready var global_music: AudioStreamPlayer = $GlobalMusic


func _ready():
	super._ready()
	spawn_player()
	#open_all_doors()


func spawn_player():
	var player = Preloads.PLAYER_SCENE.instantiate() as Player
	players.add_child(player)
	# player.blocked_movement = true
	setup_player(player) # Centralized HUD connection via Level base class
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
	"""Handle mansion-specific key events via typed event ID lookup"""
	var event_id: StringName = KEY_EVENT_MAP.get(event, &"")
	if event_id == &"":
		if event != "":
			push_warning("mansion_1: unknown key event: '%s'" % event)
		return
	
	_dispatch_key_event(event_id, body)


func _handle_button_event(body, event):
	"""Handle mansion-specific button events via typed event ID lookup"""
	var event_id: StringName = BUTTON_EVENT_MAP.get(event, &"")
	if event_id == &"":
		if event != "":
			push_warning("mansion_1: unknown button event: '%s'" % event)
		return
	
	_dispatch_button_event(event_id, body)


func _handle_area_event(body: CharacterBody3D, event):
	"""Handle mansion-specific area events via typed event ID lookup"""
	if event.strip_edges().is_empty(): return
	
	var event_id: StringName = AREA_EVENT_MAP.get(event, &"")
	if event_id == &"":
		push_warning("mansion_1: unknown area event: '%s'" % event)
		return
	
	_dispatch_area_event(event_id, body)


func _on_custom_event(event):
	"""Handle mansion-specific custom events via typed event ID lookup"""
	var event_id: StringName = CUSTOM_EVENT_MAP.get(event, &"")
	if event_id == &"":
		if event != "":
			push_warning("mansion_1: unknown custom event: '%s'" % event)
		return
	
	_dispatch_custom_event(event_id)


func _door_locked(text, triggering_player):
	if triggering_player:
		# Show event text only to the specific player who triggered the interaction
		hud.show_event_text_for_player(triggering_player, text, false, 3.0)
	# If no triggering player is specified (e.g., enemy interaction), don't show any message


# === EVENT ID DISPATCH HANDLERS ===

func _dispatch_key_event(event_id: StringName, body) -> void:
	if event_id == GE.KEY_SPAWN_AO_ONI_LIBRARY:
		var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
		enemies.add_child(aooni)
		aooni.global_position = $NavigationRegion3D/EventSpawners/FirstAoOniChase.global_position
		aooni.current_room = "FirstFloor"
		aooni.current_target = body
		aooni.makepath()
		aooni.add_disappear_zone($NavigationRegion3D/DisappearZones/LibraryExitArea)
		global_music.stream = Preloads.AOSEE_SOUND
		global_music.volume_db = -5
		global_music.play()
		hud.show_event_text("THE AO ONI! RUN!", false, 3.0)
		aooni.connect("tree_exited", _dispatch_custom_event.bind(GE.CUSTOM_MONSTER_DISAPPEARED))
		aooni.connect("tree_exited", global_music.stop)
	elif event_id == GE.KEY_AO_ONI_TRIES_BARS:
		var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
		enemies.add_child(aooni)
		aooni.global_position = $NavigationRegion3D/EventSpawners/AoOniBars.global_position
		aooni.current_room = "SecondFloor"
		aooni.add_disappear_zone($NavigationRegion3D/DisappearZones/BarsAoOniRunAway)
		aooni.waypoints.push_back($NavigationRegion3D/EventSpawners/AoOniBarsBreak.position)
		aooni.waypoints.push_back($NavigationRegion3D/EventSpawners/AoOniBarsBreak2.position)
		aooni.connect("tree_exited", _dispatch_custom_event.bind(GE.CUSTOM_AO_ONI_GAVE_UP))
		for player in players.get_children():
			player.blocked_movement = true
		aooni.makepath()
		CameraManager.set_active_camera($NavigationRegion3D/Cameras/BarsCamera2)
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
	elif event_id == GE.KEY_TELEPORT_TO_VOID:
		body.position = $NavigationRegion3D/PrankSpawners/VoidSpawn.position
	elif event_id == GE.KEY_SPAWN_WHITE_FACE:
		var whiteface = Preloads.WHITEFACE_SCENE.instantiate()
		enemies.add_child(whiteface)
		whiteface.global_position = $NavigationRegion3D/EventSpawners/WhiteFaceSpawn.global_position
		whiteface.current_room = "BigHall"
		whiteface.current_target = body
		whiteface.makepath()


func _dispatch_button_event(event_id: StringName, body) -> void:
	if event_id == GE.BUTTON_CHECK_TV:
		hud.show_event_text("[color=#6c6c6c]You:[/color] The television doesn't appear to turn on. It's probably broken.", false, 3.0)
	elif event_id == GE.BUTTON_CHECK_MAP:
		hud.show_event_text("[color=#6c6c6c]You:[/color] The resort map of the Mansion. Nuff said...", false, 3.0)
	elif event_id == GE.BUTTON_CHECK_MAP_2:
		hud.show_event_text("[color=#6c6c6c]You:[/color] This map says that there's a hidden passage nearby.", false, 3.0)
	elif event_id == GE.BUTTON_PLAY_PIANO:
		var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
		enemies.add_child(aooni)
		aooni.global_position = $NavigationRegion3D/EventSpawners/AoOniPiano.global_position
		aooni.current_room = "PianoRoom"
		aooni.current_target = body
		aooni.makepath()
		aooni.add_disappear_zone($NavigationRegion3D/DisappearZones/PianoExitArea)
		hud.show_event_text("[color=#6c6c6c]You:[/color] It's that monster! RUN!!!", false, 3.0)
		global_music.stream = Preloads.AOSEE_SOUND
		global_music.volume_db = -5
		global_music.play()
		aooni.connect("tree_exited", _dispatch_custom_event.bind(GE.CUSTOM_MONSTER_DISAPPEARED))
		aooni.connect("tree_exited", global_music.stop)
	elif event_id == GE.BUTTON_SHOW_MOVING_BARS:
		for player in players.get_children():
			player.blocked_movement = true
		global_music.stream = Preloads.EVENT_SOUND
		global_music.play()
		await get_tree().create_timer(3.4).timeout
		for player in players.get_children():
			CameraManager.set_active_camera(player.camera_3d)
			player.blocked_movement = false
		hud.show_event_text("[color=#6c6c6c]You:[/color] I should head to the 1st floor and check that out...", false, 3.0)
	elif event_id == GE.BUTTON_SHOW_SECRET_DOOR:
		for player in players.get_children():
			player.blocked_movement = true
		await get_tree().create_timer(1.0).timeout
		for player in players.get_children():
			CameraManager.set_active_camera(player.camera_3d)
			player.blocked_movement = false
		hud.show_event_text("[color=#6c6c6c]You:[/color] Hmm... I wonder where that passage leads to?", false, 3.0)
	elif event_id == GE.BUTTON_SHOW_OPEN_EXIT:
		for player in players.get_children():
			player.blocked_movement = true
		global_music.stream = Preloads.EVENT_SOUND
		global_music.play()
		await get_tree().create_timer(3.4).timeout
		for player in players.get_children():
			CameraManager.set_active_camera(player.camera_3d)
			player.blocked_movement = false
		hud.show_event_text("[color=#6c6c6c]You:[/color] I activated the switch. I better get out of here quickly!", false, 3.0)


func _dispatch_area_event(event_id: StringName, body) -> void:
	if event_id == GE.AREA_ENTERED_MANSION_TEXT:
		hud.show_event_text("You enter carefully into the mansion.", false, 3.0)
	elif event_id == GE.AREA_MONSTER_CRAWLS_LIBRARY:
		for player in players.get_children():
			player.blocked_movement = true
		var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
		enemies.add_child(aooni)
		aooni.global_position = $NavigationRegion3D/EventSpawners/AoOniCrawler.global_position
		aooni.current_room = "FirstFloor"
		aooni.add_disappear_zone($NavigationRegion3D/DisappearZones/CrawlingAoOniArea)
		aooni.waypoints.push_back($NavigationRegion3D/EventSpawners/AoOniCrawler2.position)
		aooni.waypoints.push_back($NavigationRegion3D/EventSpawners/AoOniCrawlerEnd.position)
		aooni.makepath()
		await get_tree().create_timer(4.5).timeout
		for player in players.get_children():
			CameraManager.set_active_camera(player.camera_3d)
			player.blocked_movement = false
		hud.show_event_text("[color=#6c6c6c]You:[/color] What the eff was that!?", false, 3.0)
		global_music.stream = Preloads.CREEP_AMB_SOUND
		global_music.volume_db = -5
		global_music.play()
	elif event_id == GE.AREA_PIANO_ALARM:
		if not $NavigationRegion3D/Buttons/PianoButton.is_pressed:
			var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
			enemies.add_child(aooni)
			aooni.global_position = $NavigationRegion3D/EventSpawners/AoOniPiano.global_position
			aooni.current_room = "PianoRoom"
			aooni.add_disappear_zone($NavigationRegion3D/DisappearZones/PianoExitArea)
			$NavigationRegion3D/Buttons/PianoButton.is_pressed = true
			hud.show_event_text("You: It's that monster! RUN!!!", false, 3.0)
			global_music.stream = Preloads.AOSEE_SOUND
			global_music.volume_db = -5
			global_music.play()
			aooni.connect("tree_exited", _dispatch_custom_event.bind(GE.CUSTOM_MONSTER_DISAPPEARED))
			aooni.connect("tree_exited", global_music.stop)
	elif event_id == GE.AREA_OPEN_AO_ONI_WIDE_DOOR:
		var wide_door = $Doors/AoWideDoor4
		wide_door.open()
		global_music.stream = Preloads.AOSEE_SOUND
		global_music.volume_db = -5
		global_music.play()
		hud.show_event_text("THE AO ONI! RUN!", false, 3.0)
		var ao_oni = get_node_or_null("NavigationRegion3D/Enemies/Ao oni")
		if ao_oni:
			ao_oni.connect("tree_exited", _dispatch_custom_event.bind(GE.CUSTOM_MONSTER_DISAPPEARED))
			ao_oni.connect("tree_exited", global_music.stop)
	elif event_id == GE.AREA_SPAWN_ILOPULU:
		global_music.stream = Preloads.EVENT_SOUND
		global_music.play()
		await get_tree().create_timer(1.0).timeout
		var ilopulu = Preloads.ILOPULU_SCENE.instantiate()
		enemies.add_child(ilopulu)
		ilopulu.global_position = $NavigationRegion3D/EventSpawners/IlopuluSpawn.global_position
		ilopulu.current_room = "BigHall"
		ilopulu.current_target = body
		ilopulu.makepath()
		ilopulu.add_disappear_zone($NavigationRegion3D/DisappearZones/ExitBigHallway)
	elif event_id == GE.AREA_OPEN_AO_MIKA_WARDROBE:
		var wardrobe_door = $Doors/AoWardrobeDoor4
		wardrobe_door.open()
		global_music.stream = Preloads.AOSEE_SOUND
		global_music.volume_db = -5
		global_music.play()
		hud.show_event_text("[color=#6c6c6c]You:[/color] WHAT THE?!?", false, 3.0)
		var aomika = get_node_or_null("NavigationRegion3D/Enemies/Ao mika")
		if aomika:
			aomika.connect("tree_exited", _dispatch_custom_event.bind(GE.CUSTOM_AOMIKA_DISAPPEARED))
			aomika.connect("tree_exited", global_music.stop)
	elif event_id == GE.AREA_UNDERGROUND_SECRET_INFO:
		hud.show_event_text("You need to find the switch, to open a hidden passage.", false, 3.0)
	elif event_id == GE.AREA_CHANGE_TO_NEXT_MAP:
		print("change to next map")
	elif event_id == GE.AREA_KILL_PLAYER:
		if body is Mortal:
			body.kill()


func _dispatch_custom_event(event_id: StringName) -> void:
	if event_id == GE.CUSTOM_MONSTER_DISAPPEARED:
		var random_texts := [
			"[color=#6c6c6c]You:[/color] I think he dissapeared..",
			"[color=#6c6c6c]You:[/color] I have the feeling it's gone...",
			"[color=#6c6c6c]You:[/color] Phew, that was close...",
			"[color=#6c6c6c]You:[/color] I think he's away.",
			"[color=#6c6c6c]You:[/color] I think that thing is gone...",
		]
		hud.show_event_text(random_texts.pick_random(), false, 3.0)
	elif event_id == GE.CUSTOM_AO_ONI_GAVE_UP:
		for player in players.get_children():
			CameraManager.set_active_camera(player.camera_3d)
			player.blocked_movement = false
	elif event_id == GE.CUSTOM_AOMIKA_DISAPPEARED:
		hud.show_event_text("[color=#6c6c6c]You:[/color] Whatever that THING was... it's gone...", false, 3.0)


# === TYPED EVENT HANDLERS (GameEventBus) ===
# These receive typed events and dispatch to legacy handlers for backward compatibility.
# Future refactoring will move logic directly here and use SequenceDirector for timed sequences.

func _on_button_event(event: RefCounted) -> void:
	# Call parent to handle camera/door effects from payload
	super._on_button_event(event)


func _on_area_event(event: RefCounted) -> void:
	# Call parent to handle camera/door effects from payload
	super._on_area_event(event)


func _on_key_event(event: RefCounted) -> void:
	# Call parent to handle key collection (adds to keys_collected array and updates HUD)
	# Parent's _key_body_entered will then call _handle_key_event for mansion-specific logic
	super._on_key_event(event)


# For testing purposes
func open_all_doors():
	keys_collected = ['ruby', 'weird', 'brown', 'gold', 'emerald', 'silver']
	# Update the key display when keys are added programmatically
	refresh_key_display()
	# Use explicit $Doors node reference instead of group discovery
	var doors_node = get_node_or_null("Doors")
	if doors_node:
		for door in doors_node.get_children():
			if door is Openable:
				door.open()
