extends Node

@export var piano_spawn: NodePath = NodePath("NavigationRegion3D/EventSpawners/AoOniPiano")
@export var piano_disappear_zone: NodePath = NodePath("NavigationRegion3D/DisappearZones/PianoExitArea")


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
	Services.event_bus.subscribe(GameEventTypes.BUTTON_CHECK_TV, _on_button_check_tv)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_CHECK_MAP, _on_button_check_map)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_CHECK_MAP_2, _on_button_check_map_2)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_PLAY_PIANO, _on_button_play_piano)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_SHOW_MOVING_BARS, _on_button_show_moving_bars)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_SHOW_SECRET_DOOR, _on_button_show_secret_door)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_SHOW_OPEN_EXIT, _on_button_show_open_exit)


func _exit_tree() -> void:
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_CHECK_TV, _on_button_check_tv)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_CHECK_MAP, _on_button_check_map)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_CHECK_MAP_2, _on_button_check_map_2)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_PLAY_PIANO, _on_button_play_piano)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_SHOW_MOVING_BARS, _on_button_show_moving_bars)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_SHOW_SECRET_DOOR, _on_button_show_secret_door)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_SHOW_OPEN_EXIT, _on_button_show_open_exit)


func _on_button_check_tv(_event: RefCounted) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] The television doesn't appear to turn on. It's probably broken.", false, 3.0)


func _on_button_check_map(_event: RefCounted) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] The resort map of the Mansion. Nuff said...", false, 3.0)


func _on_button_check_map_2(_event: RefCounted) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] This map says that there's a hidden passage nearby.", false, 3.0)


func _on_button_play_piano(event: RefCounted) -> void:
	var level := _level()
	var enemies := _enemies()
	if not (level and enemies):
		return

	var body = event.get_body()
	var aooni = Services.get_scene_catalog().get_enemy_scene(&"aooni").instantiate() as CharacterBody3D
	enemies.add_child(aooni)

	var spawn_node = level.get_node_or_null(piano_spawn)
	if spawn_node:
		aooni.global_position = spawn_node.global_position
		aooni.current_room = "PianoRoom"
		aooni.current_target = body
		aooni.makepath()

	var disappear_zone = level.get_node_or_null(piano_disappear_zone)
	if disappear_zone:
		aooni.add_disappear_zone(disappear_zone)

	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] It's that monster! RUN!!!", false, 3.0)

	var music := _music()
	if music:
		music.stream = Services.get_sfx_catalog().ao_see
		music.volume_db = -5
		music.play()
		aooni.tree_exited.connect(music.stop)

	aooni.tree_exited.connect(_on_monster_disappeared)


func _on_button_show_moving_bars(_event: RefCounted) -> void:
	var seq = SequenceData.create(&"show_moving_bars")
	seq.block_players()
	seq.play_music(Services.get_sfx_catalog().event_trigger)
	seq.wait(3.4)
	seq.camera_restore()
	seq.unblock_players()
	seq.show_text("[color=#6c6c6c]You:[/color] I should head to the 1st floor and check that out...", 3.0)
	Services.sequence_director.play_sequence(seq)


func _on_button_show_secret_door(_event: RefCounted) -> void:
	var seq = SequenceData.create(&"show_secret_door")
	seq.block_players()
	seq.wait(1.0)
	seq.camera_restore()
	seq.unblock_players()
	seq.show_text("[color=#6c6c6c]You:[/color] Hmm... I wonder where that passage leads to?", 3.0)
	Services.sequence_director.play_sequence(seq)


func _on_button_show_open_exit(_event: RefCounted) -> void:
	var seq = SequenceData.create(&"show_open_exit")
	seq.block_players()
	seq.play_music(Services.get_sfx_catalog().event_trigger)
	seq.wait(3.4)
	seq.camera_restore()
	seq.unblock_players()
	seq.show_text("[color=#6c6c6c]You:[/color] I activated the switch. I better get out of here quickly!", 3.0)
	Services.sequence_director.play_sequence(seq)


func _on_monster_disappeared() -> void:
	_show_monster_disappeared_text()
