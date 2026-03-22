extends Node

@export var room1reflectionprobe: ReflectionProbe


func _ready() -> void:
	Services.event_bus.subscribe(GameEventTypes.BUTTON_CHECK_BACKDOOR, _on_button_check_backdoor)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_CHECK_FIRST_PAINTING, _on_button_check_first_painting)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_LIGHT_SWITCH_BROKEN, _on_button_light_switch_broken)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_SHOW_FIRST_MOVING_BARS, _on_button_show_first_moving_bars)


func _exit_tree() -> void:
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_CHECK_BACKDOOR, _on_button_check_backdoor)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_CHECK_FIRST_PAINTING, _on_button_check_first_painting)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_LIGHT_SWITCH_BROKEN, _on_button_light_switch_broken)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_SHOW_FIRST_MOVING_BARS, _on_button_show_first_moving_bars)
	

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
