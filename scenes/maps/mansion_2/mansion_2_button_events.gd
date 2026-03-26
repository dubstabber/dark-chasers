extends Node

@export var squatto1: Enemy
@export var hidden_wall_static_body: StaticBody3D
@export var hidden_aooni_enemy: Enemy
@export var creature_disappear_marker1: Marker3D
@export var creature_disappear_zone1: Area3D
@export var near_tv_camera: Camera3D
@export var basement_camera_1: Camera3D
@export var basement_camera_2: Camera3D

var _player_killed_by_enemy := false
var _last_killing_enemy: Node = null


func _ready() -> void:
	Services.event_bus.subscribe(GameEventTypes.BUTTON_CHECK_BACKDOOR, _on_button_check_backdoor)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_CHECK_FIRST_PAINTING, _on_button_check_first_painting)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_LIGHT_SWITCH_BROKEN, _on_button_light_switch_broken)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_SHOW_FIRST_MOVING_BARS, _on_button_show_first_moving_bars)
	Services.event_bus.subscribe(GameEventTypes.CUSTOM_MANSION_2_MOVING_WALL_DOOR_CHAIN_TRIGGERED, _on_moving_wall_door_chain_triggered)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_CHECK_SECOND_PAINTING, _on_button_check_second_painting)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_CHECK_TV_2, _on_button_check_tv_2)
	Services.event_bus.subscribe(&"enemy_killed_player", _on_enemy_killed_player)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_BROKEN_NO_EFFECT, _on_button_broken_no_effect)
	Services.event_bus.subscribe(GameEventTypes.BUTTON_SHOW_MOVING_BARS_2, _on_button_show_moving_bars_2)
	


func _exit_tree() -> void:
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_CHECK_BACKDOOR, _on_button_check_backdoor)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_CHECK_FIRST_PAINTING, _on_button_check_first_painting)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_LIGHT_SWITCH_BROKEN, _on_button_light_switch_broken)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_SHOW_FIRST_MOVING_BARS, _on_button_show_first_moving_bars)
	Services.event_bus.unsubscribe(GameEventTypes.CUSTOM_MANSION_2_MOVING_WALL_DOOR_CHAIN_TRIGGERED, _on_moving_wall_door_chain_triggered)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_CHECK_TV_2, _on_button_check_tv_2)
	Services.event_bus.unsubscribe(&"enemy_killed_player", _on_enemy_killed_player)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_BROKEN_NO_EFFECT, _on_button_broken_no_effect)
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_SHOW_MOVING_BARS_2, _on_button_show_moving_bars_2)


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


func _on_button_check_backdoor(_event: GameEvent) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] Darn it, the door is locked.", false, 3.0)


func _on_button_check_first_painting(_event: GameEvent) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] That is unfortunate.", false, 3.0)


func _on_button_light_switch_broken(_event: GameEvent) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] The light switch isn't functioning.", false, 3.0)


func _on_button_show_first_moving_bars(_event: GameEvent) -> void:
	var seq = SequenceData.create(&"show_first_moving_bars")
	seq.block_players()
	seq.play_music(Services.get_sfx_catalog().get_sound(&"event_trigger"))
	seq.wait(4.0)
	seq.camera_restore()
	seq.unblock_players()
	Services.sequence_director.play_sequence(seq)


func _on_moving_wall_door_chain_triggered(_event: GameEvent) -> void:
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


func _on_button_check_tv_2(_event: GameEvent) -> void:
	if hidden_wall_static_body:
		hidden_wall_static_body.collision_layer = 64 # Set to wall for player that cannot pass through
	var hud := _hud()
	if hud:
		hud.show_event_text("Huh!?", false, 3.0)

	var seq := SequenceData.create(&"check_tv_2")
	seq.block_players()
	if near_tv_camera:
		seq.camera_cut(near_tv_camera)
	seq.wait(1.5)
	seq.custom(func():
		if hidden_aooni_enemy and is_instance_valid(hidden_aooni_enemy):
				hidden_aooni_enemy.start_chasing_players(true)
		return null)
	seq.wait(4.0)
	seq.camera_restore()
	seq.unblock_players()
	Services.sequence_director.play_sequence(seq)

	if hidden_aooni_enemy:
		if creature_disappear_zone1:
			hidden_aooni_enemy.add_disappear_zone(creature_disappear_zone1)
		hidden_aooni_enemy.waypoints.push_back(creature_disappear_marker1.global_position)
		hidden_aooni_enemy.tree_exited.connect(_on_hidden_aooni_enemy_disappear.bind(hud))


func _on_enemy_killed_player(event: GameEvent) -> void:
	_player_killed_by_enemy = true
	_last_killing_enemy = event.payload.get("enemy")

	var enemy_node: Enemy = event.payload.get("enemy")
	enemy_node.waypoints.clear()
	enemy_node.current_target = null
	enemy_node.velocity = Vector3.ZERO

		


func _on_hidden_aooni_enemy_disappear(hud: Node) -> void:
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] The creature disappeared!", false, 3.0)


func was_player_killed_by_enemy() -> bool:
	return _player_killed_by_enemy


func get_last_killing_enemy() -> Node:
	return _last_killing_enemy


func _on_button_broken_no_effect(_event: GameEvent) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] This switch is defect, and doesn't appear to do anything.", false, 3.0)


func _on_button_show_moving_bars_2(_event: GameEvent) -> void:
	var seq := SequenceData.create(&"show_moving_bars_2")
	seq.block_players()
	if basement_camera_1:
		seq.camera_cut(basement_camera_1)
	seq.play_music(Services.get_sfx_catalog().get_sound(&"event_trigger_2"))
	seq.wait(1.5)
	seq.camera_restore()
	seq.unblock_players()
	Services.sequence_director.play_sequence(seq)

