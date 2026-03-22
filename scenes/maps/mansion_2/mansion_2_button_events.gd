extends Node

@export var squatto1: Enemy


func _ready() -> void:
	Services.event_bus.subscribe(GameEventTypes.BUTTON_CHECK_BACKDOOR, _on_button_check_backdoor)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_CHECK_FIRST_PAINTING, _on_button_check_first_painting)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_LIGHT_SWITCH_BROKEN, _on_button_light_switch_broken)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_SHOW_FIRST_MOVING_BARS, _on_button_show_first_moving_bars)
	Services.event_bus.subscribe(GameEventTypes.CUSTOM_MANSION_2_MOVING_WALL_DOOR_CHAIN_TRIGGERED, _on_moving_wall_door_chain_triggered)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_CHECK_SECOND_PAINTING, _on_button_check_second_painting)


func _exit_tree() -> void:
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_CHECK_BACKDOOR, _on_button_check_backdoor)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_CHECK_FIRST_PAINTING, _on_button_check_first_painting)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_LIGHT_SWITCH_BROKEN, _on_button_light_switch_broken)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_SHOW_FIRST_MOVING_BARS, _on_button_show_first_moving_bars)
	Services.event_bus.unsubscribe(GameEventTypes.CUSTOM_MANSION_2_MOVING_WALL_DOOR_CHAIN_TRIGGERED, _on_moving_wall_door_chain_triggered)
	

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


func _music() -> AudioStreamPlayer:
	if not Services.world_context:
		return null
	return Services.world_context.get_global_music_player()


func _on_button_check_backdoor(_event: RefCounted) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] Darn it, the door is locked.", false, 3.0)


func _on_button_check_first_painting(_event: RefCounted) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] That is unfortunate.", false, 3.0)


func _on_button_light_switch_broken(_event: RefCounted) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] The light switch isn't functioning.", false, 3.0)


func _on_button_show_first_moving_bars(_event: RefCounted) -> void:
	var seq = SequenceData.create(&"show_first_moving_bars")
	seq.block_players()
	seq.play_music(Services.get_sfx_catalog().get_sound(&"event_trigger"))
	seq.wait(4.0)
	seq.camera_restore()
	seq.unblock_players()
	Services.sequence_director.play_sequence(seq)


func _on_moving_wall_door_chain_triggered(_event: RefCounted) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] It's a gigantic monster! RUN!!!", false, 3.0)
	var music := _music()
	if music:
		music.stream = Services.get_sfx_catalog().get_sound(&"ao_see")
		music.volume_db = -5
		music.play()
		squatto1.tree_exited.connect(_on_sqatto1_disappear)
		if squatto1:
			squatto1.tree_exited.connect(music.stop)


func _on_sqatto1_disappear() -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] I think it disappeared...", false, 3.0)


func _on_button_check_second_painting(_event: GameEvent) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] I can't seem to read this unknown language on that paper...", false, 3.0)
