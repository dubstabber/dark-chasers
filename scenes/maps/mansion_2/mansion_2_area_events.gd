extends Node


@export var hidden_narrow_door: Door
@export var small_basement_aomika_spawn: Marker3D
@export var small_basement_aomika_disappear_zone: Area3D

@export var quick_aooni_behind_door: Enemy

@export var takuro_wall: StaticBody3D
@export var mika_wall: StaticBody3D
@export var hidden_basement_wall: StaticBody3D

@export var ao_takeshi_enemy: Enemy
@export var ao_mika_enemy: Enemy
@export var ao_oni_in_basement: Enemy

@export var fast_ao_oni_wall: StaticBody3D

@export var zelda_talks_zone: Area3D
@export var open_secret_door_zone: Area3D
@export var secret_door: Door
@export var open_underground_door_zone: Area3D
@export var underground_door1: Door
@export var underground_door2: Door
@export var underground_door3: Door

@export var underground_secret_radio: Area3D
@export var close_big_wall_zone: Area3D

@export var release_takuro_basement_wall_zone: Area3D
@export var takuro_basement_wall: Door

@export var big_wall: Door

@export var takuro_released_zone: Area3D
@export var takuro_released_enemy: Enemy

@export var indicators: Array[ProceduralOverlayIndicator] = []

const WALLS_FOR_PLAYER_LAYER_BIT := 7

var _ao_double_music: AudioStreamPlayer = null
var _ao_takeshi_gone := false
var _ao_mika_gone := false
var _ao_double_disappearance_handled := false
var _zelda_talks_zone_triggered := false
var _open_secret_door_zone_triggered := false
var _open_underground_door_zone_triggered := false
var _underground_secret_radio_triggered := false
var _close_big_wall_zone_triggered := false
var _release_takuro_basement_wall_zone_triggered := false
var _takuro_released_zone_triggered := false


func _ready() -> void:
	Services.event_bus.subscribe(GameEventTypes.AREA_SECRET_AOONI_PRANK, _on_area_aooni_prank)
	Services.event_bus.subscribe(GameEventTypes.AREA_SMALL_BASMENT_AOMIKA_APPEAR, _on_area_small_basement_aomika_appear)
	if quick_aooni_behind_door:
		quick_aooni_behind_door.tree_exited.connect(_on_quick_aooni_behind_door_disappeared)
	Services.event_bus.subscribe(GameEventTypes.AREA_DOUBLE_AO_ONI_CHASE, _on_area_double_ao_oni_chase)
	Services.event_bus.subscribe(GameEventTypes.AREA_AO_ONI_ATE_LADDER, _on_area_ao_oni_ate_ladder)
	Services.event_bus.subscribe(GameEventTypes.AREA_BASEMENT_HINT, _on_area_basement_hint)
	Services.event_bus.subscribe(GameEventTypes.AREA_BASEMENT_AOONI_CHASE, _on_area_basement_aooni_chase)
	Services.event_bus.subscribe(GameEventTypes.AREA_SECRET_MESSAGE, _on_area_secret_message)
	Services.event_bus.subscribe(GameEventTypes.AREA_RELEASE_FAST_AO_ONI, _on_area_release_fast_ao_oni)
	if zelda_talks_zone:
		zelda_talks_zone.body_entered.connect(_on_zelda_talks_zone_body_entered)
	if open_secret_door_zone:
		open_secret_door_zone.body_entered.connect(_on_open_secret_door_zone_body_entered)
	if open_underground_door_zone:
		open_underground_door_zone.body_entered.connect(_on_open_underground_door_zone_body_entered)
	if underground_secret_radio:
		underground_secret_radio.body_entered.connect(_on_underground_secret_radio_body_entered)
	if close_big_wall_zone:
		close_big_wall_zone.body_entered.connect(_on_close_big_wall_zone_body_entered)
	if release_takuro_basement_wall_zone:
		release_takuro_basement_wall_zone.body_entered.connect(_on_release_takuro_basement_wall_zone_body_entered)
	if takuro_released_zone:
		takuro_released_zone.body_entered.connect(_on_takuro_released_zone_body_entered)


func _exit_tree() -> void:
	Services.event_bus.unsubscribe(GameEventTypes.AREA_SECRET_AOONI_PRANK, _on_area_aooni_prank)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_SMALL_BASMENT_AOMIKA_APPEAR, _on_area_small_basement_aomika_appear)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_DOUBLE_AO_ONI_CHASE, _on_area_double_ao_oni_chase)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_AO_ONI_ATE_LADDER, _on_area_ao_oni_ate_ladder)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_BASEMENT_HINT, _on_area_basement_hint)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_BASEMENT_AOONI_CHASE, _on_area_basement_aooni_chase)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_SECRET_MESSAGE, _on_area_secret_message)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_RELEASE_FAST_AO_ONI, _on_area_release_fast_ao_oni)
	if zelda_talks_zone:
		zelda_talks_zone.body_entered.disconnect(_on_zelda_talks_zone_body_entered)
	if open_secret_door_zone:
		open_secret_door_zone.body_entered.disconnect(_on_open_secret_door_zone_body_entered)
	if open_underground_door_zone:
		open_underground_door_zone.body_entered.disconnect(_on_open_underground_door_zone_body_entered)
	if underground_secret_radio:
		underground_secret_radio.body_entered.disconnect(_on_underground_secret_radio_body_entered)
	if close_big_wall_zone:
		close_big_wall_zone.body_entered.disconnect(_on_close_big_wall_zone_body_entered)
	if release_takuro_basement_wall_zone:
		release_takuro_basement_wall_zone.body_entered.disconnect(_on_release_takuro_basement_wall_zone_body_entered)
	if takuro_released_zone:
		takuro_released_zone.body_entered.disconnect(_on_takuro_released_zone_body_entered)


func _hud() -> Node:
	if not Services.world_context:
		return null
	return Services.world_context.get_hud()

func _level() -> Level:
	if not Services.world_context:
		return null
	var level := Services.world_context.get_level_node()
	if level and level is Level:
		return level as Level
	return null


func _music() -> AudioStreamPlayer:
	if not Services.world_context:
		return null
	return Services.world_context.get_global_music_player()


func _enemies() -> Node:
	if not Services.world_context:
		return null
	return Services.world_context.get_enemies_node()


func _on_area_aooni_prank(_event: GameEvent) -> void:
	if hidden_narrow_door:
		hidden_narrow_door.open()
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#a600cf]Ao oni:[/color] Hello.", false, 3.0)


func _on_area_small_basement_aomika_appear(_event: GameEvent) -> void:
	var level := _level()
	if not level:
		return

	var enemies := _enemies()
	if not enemies:
		return

	var aomika = Services.get_scene_catalog().get_enemy_scene(&"aomika").instantiate() as CharacterBody3D
	enemies.add_child(aomika)

	if small_basement_aomika_spawn:
		aomika.global_position = small_basement_aomika_spawn.global_position
		aomika.current_room = "SmallBasement"
		aomika.makepath()

	if small_basement_aomika_disappear_zone:
		aomika.add_disappear_zone(small_basement_aomika_disappear_zone)

	var music := _music()
	if music:
		music.stream = Services.get_sfx_catalog().get_sound(&"ao_see")
		music.volume_db = -5
		music.play()
		aomika.tree_exited.connect(music.stop)

	var hud := _hud()
	if hud:
		hud.show_event_text("The Ao Oni! Run!!!", false, 3.0)

	aomika.tree_exited.connect(_on_aomika_disappeared)


func _on_aomika_disappeared() -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] I think it disappeared...", false, 3.0)


func _on_quick_aooni_behind_door_disappeared() -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] I think it disappeared...", false, 3.0)


func _on_area_double_ao_oni_chase(_event: GameEvent) -> void:
	_set_wall_for_player_only(takuro_wall)
	_set_wall_for_player_only(mika_wall)
	var hud := _hud()
	if hud:
		hud.show_event_text("The Ao oni! Run!", false, 3.0)
	var music := _music()
	if music:
		music.stream = Services.get_sfx_catalog().get_sound(&"ao_see")
		music.volume_db = -5
		music.play()
		# Track disappear state using flags so timing/order doesn't prevent the "both" condition.
		_ao_double_music = music
		_ao_double_disappearance_handled = false
		_ao_takeshi_gone = not is_instance_valid(ao_takeshi_enemy)
		_ao_mika_gone = not is_instance_valid(ao_mika_enemy)

		if is_instance_valid(ao_takeshi_enemy):
			ao_takeshi_enemy.tree_exited.connect(_on_ao_takeshi_tree_exited)
		if is_instance_valid(ao_mika_enemy):
			ao_mika_enemy.tree_exited.connect(_on_ao_mika_tree_exited)

		# Handles the edge case where one/both enemies already disappeared before the chase event.
		_on_both_ao_oni_disappeared(music)


func _on_ao_takeshi_tree_exited() -> void:
	_ao_takeshi_gone = true
	_on_both_ao_oni_disappeared(_ao_double_music)


func _on_ao_mika_tree_exited() -> void:
	_ao_mika_gone = true
	_on_both_ao_oni_disappeared(_ao_double_music)



func _set_wall_for_player_only(wall: StaticBody3D) -> void:
	if not wall:
		return
	wall.collision_layer = 0
	wall.set_collision_layer_value(WALLS_FOR_PLAYER_LAYER_BIT, true)


func _on_both_ao_oni_disappeared(music: AudioStreamPlayer) -> void:
	if _ao_double_disappearance_handled:
		return
	if music and is_instance_valid(music) and _ao_takeshi_gone and _ao_mika_gone:
		_ao_double_disappearance_handled = true
		music.stop()
		for indicator in indicators:
			if is_instance_valid(indicator):
				indicator.queue_free()
		var hud := _hud()
		if hud:
			hud.show_event_text("[color=#6c6c6c]You:[/color] They both disappeared!", false, 3.0)
		indicators.clear()


func _on_area_ao_oni_ate_ladder(_event: GameEvent) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] Ao Oni ate the ladder... There must be another way out!", false, 5.0)


func _on_area_basement_hint(_event: GameEvent) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("Hint: There's a switch in this room.", false, 3.0)


func _on_area_basement_aooni_chase(_event: GameEvent) -> void:
	if hidden_basement_wall:
		hidden_basement_wall.collision_layer = 0
		hidden_basement_wall.set_collision_layer_value(WALLS_FOR_PLAYER_LAYER_BIT, true)
	var music := _music()
	if music:
		music.stream = Services.get_sfx_catalog().get_sound(&"ao_see")
		music.volume_db = -5
		music.play()
		if ao_oni_in_basement:
			ao_oni_in_basement.tree_exited.connect(music.stop)
			ao_oni_in_basement.tree_exited.connect(_on_ao_oni_in_basement_disappeared)


func _on_ao_oni_in_basement_disappeared() -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] He's gone now!", false, 3.0)


func _on_area_secret_message(_event: GameEvent) -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#a600cf]???:[/color] Walk forward in the dark.", false, 3.0)


func _on_area_release_fast_ao_oni(_event: GameEvent) -> void:
	if fast_ao_oni_wall:
		fast_ao_oni_wall.collision_layer = 0
		fast_ao_oni_wall.set_collision_layer_value(WALLS_FOR_PLAYER_LAYER_BIT, true)


func _on_zelda_talks_zone_body_entered(body: Player) -> void:
	if not body:
		return
	if _zelda_talks_zone_triggered:
		return
	_zelda_talks_zone_triggered = true
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#08f300]Elegy of Emptiness:[/color] Come closer... don't be afraid!", false, 3.0)


func _on_open_secret_door_zone_body_entered(body: Player) -> void:
	if not body:
		return
	if _open_secret_door_zone_triggered:
		return
	_open_secret_door_zone_triggered = true
	secret_door.open()


func _on_open_underground_door_zone_body_entered(body: Player) -> void:
	if not body:
		return
	if _open_underground_door_zone_triggered:
		return
	_open_underground_door_zone_triggered = true
	underground_door1.open()
	underground_door2.open()
	underground_door3.open()


func _on_underground_secret_radio_body_entered(body: Player) -> void:
	if not body:
		return
	if _underground_secret_radio_triggered:
		return
	_underground_secret_radio_triggered = true
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] A radio!?", false, 3.0)


func _on_close_big_wall_zone_body_entered(body: Player) -> void:
	if not body:
		return
	if _close_big_wall_zone_triggered:
		return
	_close_big_wall_zone_triggered = true
	if big_wall:
		big_wall.open()


func _on_release_takuro_basement_wall_zone_body_entered(body: Player) -> void:
	if not body:
		return
	if _release_takuro_basement_wall_zone_triggered:
		return
	_release_takuro_basement_wall_zone_triggered = true
	if takuro_basement_wall:
		takuro_basement_wall.open()


func _on_takuro_released_zone_body_entered(body: Player) -> void:
	if not body:
		return
	if _takuro_released_zone_triggered:
		return
	_takuro_released_zone_triggered = true
	var hud := _hud()
	if hud:
		hud.show_event_text("The Ao Oni! Run!", false, 3.0)
	var music := _music()
	if music:
		music.stream = Services.get_sfx_catalog().get_sound(&"ao_see")
		music.volume_db = -5
		music.play()
	if takuro_released_enemy:
		takuro_released_enemy.current_target = body
		takuro_released_enemy.makepath()