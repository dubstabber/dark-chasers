extends Level

const GE = preload("res://scenes/resources/game_event_types.gd")
const SequenceDataScript = preload("res://scenes/resources/sequence_data.gd")

@onready var global_music: AudioStreamPlayer = $GlobalMusic


func _ready():
	super._ready()
	_subscribe_to_domain_events()
	spawn_player()
	#open_all_doors()


func _exit_tree():
	super._exit_tree()
	_unsubscribe_from_domain_events()


func _subscribe_to_domain_events() -> void:
	# Subscribe directly to domain-specific event types (Phase E: Event-ID-only)
	# This replaces the legacy string dispatch tables (EVENT_MAPs)
	# Key events
	GameEventBus.subscribe(GE.KEY_SPAWN_AO_ONI_LIBRARY, _on_key_spawn_ao_oni_library)
	GameEventBus.subscribe(GE.KEY_AO_ONI_TRIES_BARS, _on_key_ao_oni_tries_bars)
	GameEventBus.subscribe(GE.KEY_TELEPORT_TO_VOID, _on_key_teleport_to_void)
	GameEventBus.subscribe(GE.KEY_SPAWN_WHITE_FACE, _on_key_spawn_white_face)

	# Button events
	GameEventBus.subscribe(GE.BUTTON_CHECK_TV, _on_button_check_tv)
	GameEventBus.subscribe(GE.BUTTON_CHECK_MAP, _on_button_check_map)
	GameEventBus.subscribe(GE.BUTTON_CHECK_MAP_2, _on_button_check_map_2)
	GameEventBus.subscribe(GE.BUTTON_PLAY_PIANO, _on_button_play_piano)
	GameEventBus.subscribe(GE.BUTTON_SHOW_MOVING_BARS, _on_button_show_moving_bars)
	GameEventBus.subscribe(GE.BUTTON_SHOW_SECRET_DOOR, _on_button_show_secret_door)
	GameEventBus.subscribe(GE.BUTTON_SHOW_OPEN_EXIT, _on_button_show_open_exit)

	# Area events
	GameEventBus.subscribe(GE.AREA_ENTERED_MANSION_TEXT, _on_area_entered_mansion_text)
	GameEventBus.subscribe(GE.AREA_MONSTER_CRAWLS_LIBRARY, _on_area_monster_crawls_library)
	GameEventBus.subscribe(GE.AREA_PIANO_ALARM, _on_area_piano_alarm)
	GameEventBus.subscribe(GE.AREA_OPEN_AO_ONI_WIDE_DOOR, _on_area_open_ao_oni_wide_door)
	GameEventBus.subscribe(GE.AREA_SPAWN_ILOPULU, _on_area_spawn_ilopulu)
	GameEventBus.subscribe(GE.AREA_OPEN_AO_MIKA_WARDROBE, _on_area_open_ao_mika_wardrobe)
	GameEventBus.subscribe(GE.AREA_UNDERGROUND_SECRET_INFO, _on_area_underground_secret_info)
	GameEventBus.subscribe(GE.AREA_CHANGE_TO_NEXT_MAP, _on_area_change_to_next_map)
	GameEventBus.subscribe(GE.AREA_KILL_PLAYER, _on_area_kill_player)


func _unsubscribe_from_domain_events() -> void:
	# Key events
	GameEventBus.unsubscribe(GE.KEY_SPAWN_AO_ONI_LIBRARY, _on_key_spawn_ao_oni_library)
	GameEventBus.unsubscribe(GE.KEY_AO_ONI_TRIES_BARS, _on_key_ao_oni_tries_bars)
	GameEventBus.unsubscribe(GE.KEY_TELEPORT_TO_VOID, _on_key_teleport_to_void)
	GameEventBus.unsubscribe(GE.KEY_SPAWN_WHITE_FACE, _on_key_spawn_white_face)

	# Button events
	GameEventBus.unsubscribe(GE.BUTTON_CHECK_TV, _on_button_check_tv)
	GameEventBus.unsubscribe(GE.BUTTON_CHECK_MAP, _on_button_check_map)
	GameEventBus.unsubscribe(GE.BUTTON_CHECK_MAP_2, _on_button_check_map_2)
	GameEventBus.unsubscribe(GE.BUTTON_PLAY_PIANO, _on_button_play_piano)
	GameEventBus.unsubscribe(GE.BUTTON_SHOW_MOVING_BARS, _on_button_show_moving_bars)
	GameEventBus.unsubscribe(GE.BUTTON_SHOW_SECRET_DOOR, _on_button_show_secret_door)
	GameEventBus.unsubscribe(GE.BUTTON_SHOW_OPEN_EXIT, _on_button_show_open_exit)

	# Area events
	GameEventBus.unsubscribe(GE.AREA_ENTERED_MANSION_TEXT, _on_area_entered_mansion_text)
	GameEventBus.unsubscribe(GE.AREA_MONSTER_CRAWLS_LIBRARY, _on_area_monster_crawls_library)
	GameEventBus.unsubscribe(GE.AREA_PIANO_ALARM, _on_area_piano_alarm)
	GameEventBus.unsubscribe(GE.AREA_OPEN_AO_ONI_WIDE_DOOR, _on_area_open_ao_oni_wide_door)
	GameEventBus.unsubscribe(GE.AREA_SPAWN_ILOPULU, _on_area_spawn_ilopulu)
	GameEventBus.unsubscribe(GE.AREA_OPEN_AO_MIKA_WARDROBE, _on_area_open_ao_mika_wardrobe)
	GameEventBus.unsubscribe(GE.AREA_UNDERGROUND_SECRET_INFO, _on_area_underground_secret_info)
	GameEventBus.unsubscribe(GE.AREA_CHANGE_TO_NEXT_MAP, _on_area_change_to_next_map)
	GameEventBus.unsubscribe(GE.AREA_KILL_PLAYER, _on_area_kill_player)


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
	if body.is_in_group("player") and body.movement_component:
		body.movement_component.set_climbing(true)


func _on_ladder_body_exited(body):
	if body.is_in_group("player") and body.movement_component:
		body.movement_component.set_climbing(false)


func _door_locked(text, triggering_player):
	if triggering_player:
		# Show event text only to the specific player who triggered the interaction
		hud.show_event_text_for_player(triggering_player, text, false, 3.0)
	# If no triggering player is specified (e.g., enemy interaction), don't show any message


# === DOMAIN-SPECIFIC EVENT HANDLERS ===
# Each handler receives a GameEvent and extracts the body from payload.
# This replaces the legacy _dispatch_*_event methods with string dispatch.

# --- Key Event Handlers ---

func _on_key_spawn_ao_oni_library(event: RefCounted) -> void:
	var body = event.get_body()
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
	aooni.connect("tree_exited", _on_monster_disappeared)
	aooni.connect("tree_exited", global_music.stop)


var _bars_aooni: CharacterBody3D = null

func _on_key_ao_oni_tries_bars(_event: RefCounted) -> void:
	var seq = SequenceDataScript.create(&"ao_oni_tries_bars")
	seq.custom(_spawn_bars_aooni)
	seq.block_players()
	seq.camera_cut($NavigationRegion3D/Cameras/BarsCamera2)
	seq.wait(3.0)
	seq.custom(_play_bar_shake)
	seq.wait(0.6)
	seq.custom(_play_bar_shake)
	seq.wait(0.25)
	seq.custom(_play_bar_shake)
	seq.wait(0.25)
	seq.custom(_play_bar_shake)
	seq.wait(0.5)
	seq.custom(_play_bar_shake)
	seq.wait(2.5)
	seq.custom(_bars_aooni_give_up)
	SequenceDirector.play_sequence(seq)


func _spawn_bars_aooni() -> void:
	_bars_aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
	enemies.add_child(_bars_aooni)
	_bars_aooni.global_position = $NavigationRegion3D/EventSpawners/AoOniBars.global_position
	_bars_aooni.current_room = "SecondFloor"
	_bars_aooni.add_disappear_zone($NavigationRegion3D/DisappearZones/BarsAoOniRunAway)
	_bars_aooni.waypoints.push_back($NavigationRegion3D/EventSpawners/AoOniBarsBreak.position)
	_bars_aooni.waypoints.push_back($NavigationRegion3D/EventSpawners/AoOniBarsBreak2.position)
	_bars_aooni.connect("tree_exited", _on_ao_oni_gave_up)
	_bars_aooni.makepath()


func _play_bar_shake() -> void:
	if is_instance_valid(_bars_aooni):
		Utils.play_sound(Preloads.BAR_SHAKE_SOUND, _bars_aooni)


func _bars_aooni_give_up() -> void:
	if is_instance_valid(_bars_aooni):
		_bars_aooni.waypoints.push_back($NavigationRegion3D/EventSpawners/AoOniBarsGiveup.position)


func _on_key_teleport_to_void(event: RefCounted) -> void:
	var body = event.get_body()
	body.position = $NavigationRegion3D/PrankSpawners/VoidSpawn.position


func _on_key_spawn_white_face(event: RefCounted) -> void:
	var body = event.get_body()
	var whiteface = Preloads.WHITEFACE_SCENE.instantiate()
	enemies.add_child(whiteface)
	whiteface.global_position = $NavigationRegion3D/EventSpawners/WhiteFaceSpawn.global_position
	whiteface.current_room = "BigHall"
	whiteface.current_target = body
	whiteface.makepath()


# --- Button Event Handlers ---

func _on_button_check_tv(_event: RefCounted) -> void:
	hud.show_event_text("[color=#6c6c6c]You:[/color] The television doesn't appear to turn on. It's probably broken.", false, 3.0)


func _on_button_check_map(_event: RefCounted) -> void:
	hud.show_event_text("[color=#6c6c6c]You:[/color] The resort map of the Mansion. Nuff said...", false, 3.0)


func _on_button_check_map_2(_event: RefCounted) -> void:
	hud.show_event_text("[color=#6c6c6c]You:[/color] This map says that there's a hidden passage nearby.", false, 3.0)


func _on_button_play_piano(event: RefCounted) -> void:
	var body = event.get_body()
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
	aooni.connect("tree_exited", _on_monster_disappeared)
	aooni.connect("tree_exited", global_music.stop)


func _on_button_show_moving_bars(_event: RefCounted) -> void:
	var seq = SequenceDataScript.create(&"show_moving_bars")
	seq.block_players()
	seq.play_music(Preloads.EVENT_SOUND)
	seq.wait(3.4)
	seq.camera_restore()
	seq.unblock_players()
	seq.show_text("[color=#6c6c6c]You:[/color] I should head to the 1st floor and check that out...", 3.0)
	SequenceDirector.play_sequence(seq)


func _on_button_show_secret_door(_event: RefCounted) -> void:
	var seq = SequenceDataScript.create(&"show_secret_door")
	seq.block_players()
	seq.wait(1.0)
	seq.camera_restore()
	seq.unblock_players()
	seq.show_text("[color=#6c6c6c]You:[/color] Hmm... I wonder where that passage leads to?", 3.0)
	SequenceDirector.play_sequence(seq)


func _on_button_show_open_exit(_event: RefCounted) -> void:
	var seq = SequenceDataScript.create(&"show_open_exit")
	seq.block_players()
	seq.play_music(Preloads.EVENT_SOUND)
	seq.wait(3.4)
	seq.camera_restore()
	seq.unblock_players()
	seq.show_text("[color=#6c6c6c]You:[/color] I activated the switch. I better get out of here quickly!", 3.0)
	SequenceDirector.play_sequence(seq)


# --- Area Event Handlers ---

func _on_area_entered_mansion_text(_event: RefCounted) -> void:
	hud.show_event_text("You enter carefully into the mansion.", false, 3.0)


func _on_area_monster_crawls_library(_event: RefCounted) -> void:
	var seq = SequenceDataScript.create(&"monster_crawls_library")
	seq.block_players()
	seq.custom(_spawn_crawling_aooni)
	seq.wait(4.5)
	seq.camera_restore()
	seq.unblock_players()
	seq.show_text("[color=#6c6c6c]You:[/color] What the eff was that!?", 3.0)
	seq.play_music(Preloads.CREEP_AMB_SOUND, -5.0)
	SequenceDirector.play_sequence(seq)


func _spawn_crawling_aooni() -> void:
	var aooni = Preloads.AOONI_SCENE.instantiate() as CharacterBody3D
	enemies.add_child(aooni)
	aooni.global_position = $NavigationRegion3D/EventSpawners/AoOniCrawler.global_position
	aooni.current_room = "FirstFloor"
	aooni.add_disappear_zone($NavigationRegion3D/DisappearZones/CrawlingAoOniArea)
	aooni.waypoints.push_back($NavigationRegion3D/EventSpawners/AoOniCrawler2.position)
	aooni.waypoints.push_back($NavigationRegion3D/EventSpawners/AoOniCrawlerEnd.position)
	aooni.makepath()


func _on_area_piano_alarm(_event: RefCounted) -> void:
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
		aooni.connect("tree_exited", _on_monster_disappeared)
		aooni.connect("tree_exited", global_music.stop)


func _on_area_open_ao_oni_wide_door(_event: RefCounted) -> void:
	var wide_door = $Doors/AoWideDoor4
	wide_door.open()
	global_music.stream = Preloads.AOSEE_SOUND
	global_music.volume_db = -5
	global_music.play()
	hud.show_event_text("THE AO ONI! RUN!", false, 3.0)
	var ao_oni = get_node_or_null("NavigationRegion3D/Enemies/Ao oni")
	if ao_oni:
		ao_oni.connect("tree_exited", _on_monster_disappeared)
		ao_oni.connect("tree_exited", global_music.stop)


func _on_area_spawn_ilopulu(event: RefCounted) -> void:
	var body = event.get_body()
	var seq = SequenceDataScript.create(&"spawn_ilopulu")
	seq.play_music(Preloads.EVENT_SOUND)
	seq.wait(1.0)
	seq.custom(_spawn_ilopulu.bind(body))
	SequenceDirector.play_sequence(seq)


func _spawn_ilopulu(target: Node) -> void:
	var ilopulu = Preloads.ILOPULU_SCENE.instantiate()
	enemies.add_child(ilopulu)
	ilopulu.global_position = $NavigationRegion3D/EventSpawners/IlopuluSpawn.global_position
	ilopulu.current_room = "BigHall"
	ilopulu.current_target = target
	ilopulu.makepath()
	ilopulu.add_disappear_zone($NavigationRegion3D/DisappearZones/ExitBigHallway)


func _on_area_open_ao_mika_wardrobe(_event: RefCounted) -> void:
	var wardrobe_door = $Doors/AoWardrobeDoor4
	wardrobe_door.open()
	global_music.stream = Preloads.AOSEE_SOUND
	global_music.volume_db = -5
	global_music.play()
	hud.show_event_text("[color=#6c6c6c]You:[/color] WHAT THE?!?", false, 3.0)
	var aomika = get_node_or_null("NavigationRegion3D/Enemies/Ao mika")
	if aomika:
		aomika.connect("tree_exited", _on_aomika_disappeared)
		aomika.connect("tree_exited", global_music.stop)


func _on_area_underground_secret_info(_event: RefCounted) -> void:
	hud.show_event_text("You need to find the switch, to open a hidden passage.", false, 3.0)


func _on_area_change_to_next_map(_event: RefCounted) -> void:
	print("change to next map")


func _on_area_kill_player(event: RefCounted) -> void:
	var body = event.get_body()
	if body is Mortal:
		body.kill()


# --- Custom Event Handlers (called directly from signal connections) ---

func _on_monster_disappeared() -> void:
	var random_texts := [
		"[color=#6c6c6c]You:[/color] I think he dissapeared..",
		"[color=#6c6c6c]You:[/color] I have the feeling it's gone...",
		"[color=#6c6c6c]You:[/color] Phew, that was close...",
		"[color=#6c6c6c]You:[/color] I think he's away.",
		"[color=#6c6c6c]You:[/color] I think that thing is gone...",
	]
	hud.show_event_text(random_texts.pick_random(), false, 3.0)


func _on_ao_oni_gave_up() -> void:
	for player in players.get_children():
		CameraManager.set_active_camera(player.camera_3d)
		player.blocked_movement = false


func _on_aomika_disappeared() -> void:
	hud.show_event_text("[color=#6c6c6c]You:[/color] Whatever that THING was... it's gone...", false, 3.0)


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
