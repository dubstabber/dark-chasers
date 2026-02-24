extends Node

@export var library_camera_spawn: NodePath = NodePath("NavigationRegion3D/EventSpawners/AoOniCrawler")
@export var library_disappear_zone: NodePath = NodePath("NavigationRegion3D/DisappearZones/CrawlingAoOniArea")
@export var library_waypoint_1: NodePath = NodePath("NavigationRegion3D/EventSpawners/AoOniCrawler2")
@export var library_waypoint_2: NodePath = NodePath("NavigationRegion3D/EventSpawners/AoOniCrawlerEnd")

@export var piano_button: NodePath = NodePath("NavigationRegion3D/Buttons/PianoButton")
@export var piano_spawn: NodePath = NodePath("NavigationRegion3D/EventSpawners/AoOniPiano")
@export var piano_disappear_zone: NodePath = NodePath("NavigationRegion3D/DisappearZones/PianoExitArea")

@export var wide_door: NodePath = NodePath("Doors/AoWideDoor4")
@export var ao_oni_enemy: NodePath = NodePath("NavigationRegion3D/Enemies/Ao oni")
@export var ao_oni_disappear_zone: NodePath = NodePath("NavigationRegion3D/DisappearZones/HiddenDoorAoOni")

@export var ilopulu_spawn: NodePath = NodePath("NavigationRegion3D/EventSpawners/IlopuluSpawn")
@export var ilopulu_disappear_zone: NodePath = NodePath("NavigationRegion3D/DisappearZones/ExitBigHallway")

@export var wardrobe_door: NodePath = NodePath("Doors/AoWardrobeDoor4")
@export var ao_mika_enemy: NodePath = NodePath("NavigationRegion3D/Enemies/Ao mika")
@export var ao_mika_disappear_zone: NodePath = NodePath("NavigationRegion3D/DisappearZones/SmallHallway")


func _level() -> Level:
	if not Services.world_context:
		return null
	var level := Services.world_context.get_level_node()
	if level and level is Level:
		return level as Level
	return null


func _hud() -> Node:
	if not Services.world_context:
		return null
	return Services.world_context.get_hud()


func _enemies() -> Node:
	if not Services.world_context:
		return null
	return Services.world_context.get_enemies_node()


func _music() -> AudioStreamPlayer:
	if not Services.world_context:
		return null
	return Services.world_context.get_global_music_player()


func _show_monster_disappeared_text() -> void:
	var hud := _hud()
	if not hud:
		return
	var random_texts := [
		"[color=#6c6c6c]You:[/color] I think he dissapeared..",
		"[color=#6c6c6c]You:[/color] I have the feeling it's gone...",
		"[color=#6c6c6c]You:[/color] Phew, that was close...",
		"[color=#6c6c6c]You:[/color] I think he's away.",
		"[color=#6c6c6c]You:[/color] I think that thing is gone...",
	]
	hud.show_event_text(random_texts.pick_random(), false, 3.0)


func _ready() -> void:
	Services.event_bus.subscribe(GameEventTypes.AREA_ENTERED_MANSION_TEXT, _on_area_entered_mansion_text)
	Services.event_bus.subscribe(GameEventTypes.AREA_MONSTER_CRAWLS_LIBRARY, _on_area_monster_crawls_library)
	Services.event_bus.subscribe(GameEventTypes.AREA_PIANO_ALARM, _on_area_piano_alarm)
	Services.event_bus.subscribe(GameEventTypes.AREA_OPEN_AO_ONI_WIDE_DOOR, _on_area_open_ao_oni_wide_door)
	Services.event_bus.subscribe(GameEventTypes.AREA_SPAWN_ILOPULU, _on_area_spawn_ilopulu)
	Services.event_bus.subscribe(GameEventTypes.AREA_OPEN_AO_MIKA_WARDROBE, _on_area_open_ao_mika_wardrobe)
	Services.event_bus.subscribe(GameEventTypes.AREA_UNDERGROUND_SECRET_INFO, _on_area_underground_secret_info)
	Services.event_bus.subscribe(GameEventTypes.AREA_CHANGE_TO_NEXT_MAP, _on_area_change_to_next_map)
	Services.event_bus.subscribe(GameEventTypes.AREA_KILL_PLAYER, _on_area_kill_player)


func _exit_tree() -> void:
	Services.event_bus.unsubscribe(GameEventTypes.AREA_ENTERED_MANSION_TEXT, _on_area_entered_mansion_text)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_MONSTER_CRAWLS_LIBRARY, _on_area_monster_crawls_library)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_PIANO_ALARM, _on_area_piano_alarm)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_OPEN_AO_ONI_WIDE_DOOR, _on_area_open_ao_oni_wide_door)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_SPAWN_ILOPULU, _on_area_spawn_ilopulu)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_OPEN_AO_MIKA_WARDROBE, _on_area_open_ao_mika_wardrobe)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_UNDERGROUND_SECRET_INFO, _on_area_underground_secret_info)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_CHANGE_TO_NEXT_MAP, _on_area_change_to_next_map)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_KILL_PLAYER, _on_area_kill_player)


func _on_area_entered_mansion_text(_event: RefCounted) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("You enter carefully into the mansion.", false, 3.0)


func _on_area_monster_crawls_library(_event: RefCounted) -> void:
	var seq = SequenceData.create(&"monster_crawls_library")
	seq.block_players()
	seq.custom(_spawn_crawling_aooni)
	seq.wait(4.5)
	seq.camera_restore()
	seq.unblock_players()
	seq.show_text("[color=#6c6c6c]You:[/color] What the eff was that!?", 3.0)
	seq.play_music(Services.get_sfx_catalog().creep_ambience, -5.0)
	Services.sequence_director.play_sequence(seq)


func _spawn_crawling_aooni() -> void:
	var level := _level()
	var enemies := _enemies()
	if not (level and enemies):
		return

	var aooni = Services.get_scene_catalog().get_enemy_scene(&"aooni").instantiate() as CharacterBody3D
	enemies.add_child(aooni)

	var spawn_node = level.get_node_or_null(library_camera_spawn)
	if spawn_node:
		aooni.global_position = spawn_node.global_position
		aooni.current_room = "FirstFloor"

	var disappear_zone = level.get_node_or_null(library_disappear_zone)
	if disappear_zone:
		aooni.add_disappear_zone(disappear_zone)

	var waypoint_1 = level.get_node_or_null(library_waypoint_1)
	if waypoint_1:
		aooni.waypoints.push_back(waypoint_1.position)
	var waypoint_2 = level.get_node_or_null(library_waypoint_2)
	if waypoint_2:
		aooni.waypoints.push_back(waypoint_2.position)

	aooni.makepath()


func _on_area_piano_alarm(_event: RefCounted) -> void:
	var level := _level()
	var enemies := _enemies()
	if not (level and enemies):
		return

	var piano_button_node = level.get_node_or_null(piano_button)
	if piano_button_node and piano_button_node.is_pressed:
		return

	var aooni = Services.get_scene_catalog().get_enemy_scene(&"aooni").instantiate() as CharacterBody3D
	enemies.add_child(aooni)

	var spawn_node = level.get_node_or_null(piano_spawn)
	if spawn_node:
		aooni.global_position = spawn_node.global_position
		aooni.current_room = "PianoRoom"

	var disappear_zone = level.get_node_or_null(piano_disappear_zone)
	if disappear_zone:
		aooni.add_disappear_zone(disappear_zone)

	if piano_button_node:
		piano_button_node.is_pressed = true

	var hud := _hud()
	if hud:
		hud.show_event_text("You: It's that monster! RUN!!!", false, 3.0)

	var music := _music()
	if music:
		music.stream = Services.get_sfx_catalog().ao_see
		music.volume_db = -5
		music.play()
		aooni.tree_exited.connect(music.stop)

	aooni.tree_exited.connect(_on_monster_disappeared)


func _on_area_open_ao_oni_wide_door(_event: RefCounted) -> void:
	var level := _level()
	if not level:
		return

	var wide_door_node = level.get_node_or_null(wide_door)
	if wide_door_node and wide_door_node is Door:
		wide_door_node.open()

	var music := _music()
	if music:
		music.stream = Services.get_sfx_catalog().ao_see
		music.volume_db = -5
		music.play()

	var hud := _hud()
	if hud:
		hud.show_event_text("THE AO ONI! RUN!", false, 3.0)

	var ao_oni = level.get_node_or_null(ao_oni_enemy)
	if ao_oni:
		var disappear_zone = level.get_node_or_null(ao_oni_disappear_zone)
		if disappear_zone:
			ao_oni.add_disappear_zone(disappear_zone)
		ao_oni.tree_exited.connect(_on_monster_disappeared)
		if music:
			ao_oni.tree_exited.connect(music.stop)


func _on_area_spawn_ilopulu(event: RefCounted) -> void:
	var body = event.get_body()
	var seq = SequenceData.create(&"spawn_ilopulu")
	seq.play_music(Services.get_sfx_catalog().event_trigger)
	seq.wait(1.0)
	seq.custom(_spawn_ilopulu.bind(body))
	Services.sequence_director.play_sequence(seq)


func _spawn_ilopulu(target: Node) -> void:
	var level := _level()
	var enemies := _enemies()
	if not (level and enemies):
		return

	var ilopulu = Services.get_scene_catalog().get_enemy_scene(&"ilopulu").instantiate()
	enemies.add_child(ilopulu)

	var spawn_node = level.get_node_or_null(ilopulu_spawn)
	if spawn_node:
		ilopulu.global_position = spawn_node.global_position
		ilopulu.current_room = "BigHall"
		ilopulu.current_target = target
		ilopulu.makepath()

	var disappear_zone = level.get_node_or_null(ilopulu_disappear_zone)
	if disappear_zone:
		ilopulu.add_disappear_zone(disappear_zone)


func _on_area_open_ao_mika_wardrobe(_event: RefCounted) -> void:
	var level := _level()
	if not level:
		return

	var wardrobe_door_node = level.get_node_or_null(wardrobe_door)
	if wardrobe_door_node and wardrobe_door_node is Door:
		wardrobe_door_node.open()

	var music := _music()
	if music:
		music.stream = Services.get_sfx_catalog().ao_see
		music.volume_db = -5
		music.play()

	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] WHAT THE?!?", false, 3.0)

	var aomika = level.get_node_or_null(ao_mika_enemy)
	if aomika:
		var disappear_zone = level.get_node_or_null(ao_mika_disappear_zone)
		if disappear_zone:
			aomika.add_disappear_zone(disappear_zone)
		aomika.tree_exited.connect(_on_aomika_disappeared)
		if music:
			aomika.tree_exited.connect(music.stop)


func _on_area_underground_secret_info(_event: RefCounted) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("You need to find the switch, to open a hidden passage.", false, 3.0)


func _on_area_change_to_next_map(_event: RefCounted) -> void:
	var catalog: SceneCatalog = null
	if Services:
		catalog = Services.get_scene_catalog()
	if not (Services and Services.level_manager):
		push_warning("Mansion1: Services.level_manager not available; cannot transition to next map")
		return
	var lm := Services.level_manager as LevelManager
	if lm == null:
		push_warning("Mansion1: Services.level_manager is not a LevelManager")
		return

	var context := {
		"from_map": "mansion_1",
		"reason": "area_change_to_next_map"
	}

	var room_1_scene := catalog.get_map_scene(&"room_1") if catalog else null
	if room_1_scene:
		lm.request_level_transition_scene(room_1_scene, context)
		return

	# Fallback to raw path (legacy).
	lm.request_level_transition("res://scenes/maps/room_1.tscn", context)


func _on_area_kill_player(event: RefCounted) -> void:
	var body = event.get_body()
	if Mortal.can_kill(body):
		Mortal.kill(body)


func _on_monster_disappeared() -> void:
	_show_monster_disappeared_text()


func _on_aomika_disappeared() -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] Whatever that THING was... it's gone...", false, 3.0)
